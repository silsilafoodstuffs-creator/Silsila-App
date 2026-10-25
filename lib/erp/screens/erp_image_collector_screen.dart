import 'dart:convert';
import 'package:image/image.dart' as img;

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _processTransparentPngInBackground(Uint8List source) {
    final decodedSource = img.decodeImage(source);
    if (decodedSource == null) throw Exception('تعذر فك ترميز الصورة الأصلية.');
    // Limit the working resolution before the flood-fill; huge source images
    // otherwise make a single-row download stall the UI on slower devices.
    const maxDimension = 1800;
    final sourceLongest = decodedSource.width > decodedSource.height ? decodedSource.width : decodedSource.height;
    final sourceImage = sourceLongest > maxDimension
        ? img.copyResize(decodedSource,
            width: decodedSource.width >= decodedSource.height ? maxDimension : null,
            height: decodedSource.height > decodedSource.width ? maxDimension : null,
            interpolation: img.Interpolation.average)
        : decodedSource;
    final decoded = img.Image(width: sourceImage.width, height: sourceImage.height, numChannels: 4);
    img.compositeImage(decoded, sourceImage);
    final int width = decoded.width;
    final int height = decoded.height;
    final visited = Uint8List(width * height);
    final queue = <int>[];
    bool isBackground(int x, int y) {
      final p = decoded.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      final hi = [r, g, b].reduce((a, b) => a > b ? a : b);
      final lo = [r, g, b].reduce((a, b) => a < b ? a : b);
      return r >= 232 && g >= 232 && b >= 232 && hi - lo <= 30;
    }
    void enqueue(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return;
      final int i = y * width + x;
      if (visited[i] != 0 || !isBackground(x, y)) return;
      visited[i] = 1;
      queue.add(i);
    }
    for (var x = 0; x < width; x++) {
      enqueue(x, 0);
      if (height > 1) enqueue(x, height - 1);
    }
    for (var y = 1; y < height - 1; y++) {
      enqueue(0, y);
      if (width > 1) enqueue(width - 1, y);
    }
    for (var head = 0; head < queue.length; head++) {
      final int i = queue[head];
      final int x = (i % width).toInt();
      final int y = (i ~/ width).toInt();
      decoded.setPixelRgba(x, y, 0, 0, 0, 0);
      enqueue(x - 1, y); enqueue(x + 1, y);
      enqueue(x, y - 1); enqueue(x, y + 1);
    }
    // Do not upscale small originals; retain their actual detail and encode
    // directly after background removal to minimize CPU time and memory.
    return Uint8List.fromList(img.encodePng(decoded, level: 6));
  }


class ErpImageCollectorScreen extends StatefulWidget {
  const ErpImageCollectorScreen({super.key});

  @override
  State<ErpImageCollectorScreen> createState() => _ErpImageCollectorScreenState();
}

class _ErpImageCollectorScreenState extends State<ErpImageCollectorScreen> {
  static const _purple = Color(0xFF3E007D);
  static const _orange = Color(0xFFFFA015);
  final _url = TextEditingController();
  final Set<String> _selected = {};
  List<Map<String, dynamic>> _images = [];
  bool _loading = false;
  String? _pageUrl;
  String? _error;
  String _status = '';
  final Set<String> _importedImageKeys = <String>{};
  final Map<String, TextEditingController> _rowControllers = {};
  String? _importedScope;
  String _imageKind = 'product';
  List<Map<String, dynamic>> _categoryOptions = <Map<String, dynamic>>[];
  bool _categoryOptionsLoaded = false;
  int _previouslyImportedCount = 0;
  int _duplicateCount = 0;
  final Set<String> _downloadingUrls = <String>{};
  final Map<String, Future<Uint8List?>> _previewFutures = <String, Future<Uint8List?>>{};
  final Map<String, String> _previewErrors = <String, String>{};
  final ScrollController _imagesScrollController = ScrollController();
  static const int _imagesPageSize = 10;
  int _imagesPage = 0;

  @override
  void initState() {
    super.initState();
    _clearLegacyTestHistory();
  }

  Future<void> _loadCategoryOptions() async {
    if (_categoryOptionsLoaded) return;
    try {
      final company = await _activeCompanyId();
      final rows = await Supabase.instance.client.from('erp_item_categories')
          .select('id,parent_id,category_code:category_code,category_name:category_name')
          .eq('company_id', company).eq('is_active', true)
          .order('category_name').limit(3000);
      if (!mounted) return;
      setState(() {
        _categoryOptions = (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
        _categoryOptionsLoaded = true;
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> _categoriesForParent(String? parentId) =>
      _categoryOptions.where((r) => (r['parent_id']?.toString() ?? '') == (parentId ?? '')).toList();

  Widget _categoryChoice(Map<String, dynamic> item, String field, String label,
      List<Map<String, dynamic>> options, {bool enabled = true}) {
    final current = item[field]?.toString();
    final valid = options.any((r) => r['id'].toString() == current);
    return SizedBox(width: 205, child: DropdownButtonFormField<String>(
      value: valid ? current : null, isExpanded: true,
      decoration: InputDecoration(hintText: label, labelText: null,
        isDense: true, border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7)),
      items: options.map((r) => DropdownMenuItem<String>(
        value: r['id'].toString(),
        child: Text('${r['category_code'] ?? ''} - ${r['category_name'] ?? ''}', overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: !enabled || _loading ? null : (value) {
        setState(() {
          item[field] = value;
          if (field == 'category_root_id') {
            item.remove('category_sub_id'); item.remove('category_secondary_id');
          } else if (field == 'category_sub_id') { item.remove('category_secondary_id'); }
          item['category_id'] = item['category_secondary_id']?.toString() ??
              item['category_sub_id']?.toString() ?? item['category_root_id']?.toString();
          final selected = options.where((r) => r['id'].toString() == value);
          final name = selected.isEmpty ? '' : (selected.first['category_name'] ?? '').toString();
          item[field == 'category_root_id' ? 'main_category' :
              field == 'category_sub_id' ? 'sub_category' : 'secondary_category'] = name;
        });
      },
    ));
  }

  Future<void> _openF1Lookup(Map<String, dynamic> item) async {
    if (_loading) return;
    final isCategory = (item['save_as'] ?? 'product') == 'category';
    final company = await _activeCompanyId();
    final rows = isCategory
        ? await Supabase.instance.client.from('erp_item_categories')
            .select('id,category_code:category_code,category_name:category_name').eq('company_id', company)
            .eq('is_active', true).order('category_name').limit(1000)
        : await Supabase.instance.client.from('erp_items')
            .select('id,item_code,item_name').eq('company_id', company)
            .eq('is_active', true).order('item_name').limit(1000);
    if (!mounted) return;
    final records = (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
    final chosen = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) {
      final search = TextEditingController();
      var filtered = List<Map<String, dynamic>>.from(records);
      return StatefulBuilder(builder: (context, setDialogState) {
        void filter(String value) {
          final q = value.trim().toLowerCase();
          setDialogState(() { filtered = records.where((r) {
            final code = (r[isCategory ? 'category_code' : 'item_code'] ?? '').toString().toLowerCase();
            final name = (r[isCategory ? 'category_name' : 'item_name'] ?? '').toString().toLowerCase();
            return q.isEmpty || code.contains(q) || name.contains(q);
          }).toList(); });
        }
        return AlertDialog(
          title: Text(isCategory ? 'F1 - اختيار فئة قديمة' : 'F1 - اختيار صنف قديم'),
          content: SizedBox(width: 620, height: 460, child: Column(children: [
            TextField(controller: search, autofocus: true, onChanged: filter,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
                labelText: 'ابحث بالكود أو الاسم', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Expanded(child: filtered.isEmpty ? const Center(child: Text('لا توجد نتائج مطابقة'))
              : ListView.separated(itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = filtered[i];
                  return ListTile(dense: true,
                    title: Text((r[isCategory ? 'category_name' : 'item_name'] ?? '').toString()),
                    subtitle: Text((r[isCategory ? 'category_code' : 'item_code'] ?? '').toString()),
                    onTap: () => Navigator.pop(dialogContext, r));
                })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء'))],
        );
      });
    });
    if (chosen == null || !mounted) return;
    _rowController(item, 'legacy_code').text =
        (chosen[isCategory ? 'category_code' : 'item_code'] ?? '').toString();
    await _lookupRowCode(item);
  }

  Future<void> _clearLegacyTestHistory() async {
    // v1 was used during exploratory test runs; discard it so old test imports
    // cannot hide images when the user starts a real collection.
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('silsila_image_collector_imported_v1_'),
    ).toList()) {
      await prefs.remove(key);
    }
  }

  Future<void> _resetImportHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بدء سحب جديد من الصفر'),
        content: const Text(
          'سيتم مسح سجل الصور التي سبق تسجيلها في جامع الصور على هذا الجهاز، '
          'وبالتالي ستظهر مرة أخرى عند فحص الصفحات. لن يتم حذف الملفات التي سبق تنزيلها إلى جهازك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('مسح السجل والبدء من جديد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (key) => key.startsWith('silsila_image_collector_imported_'),
    ).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    setState(() {
      _importedImageKeys.clear();
      _importedScope = null;
      _images = [];
      _imagesPage = 0;
      _selected.clear();
      _pageUrl = null;
      _error = null;
      _status = 'تم مسح سجل السحب السابق. أدخل رابط الصفحة الصحيحة وابدأ السحب من جديد.';
    });
  }

  @override
  void dispose() {
    _imagesScrollController.dispose();
    for (final controller in _rowControllers.values) { controller.dispose(); }
    _url.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'silsila-image-collector',
      body: body,
    );
    final data = response.data;
    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      if (response.status >= 400 || result['error'] != null) {
        final message = result['error']?.toString() ?? 'تعذر تنفيذ الطلب.';
        final diagnostic = result['diagnostic'];
        if (diagnostic is Map && diagnostic.isNotEmpty) {
          final details = diagnostic.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join(', ');
          throw Exception('$message (تفاصيل فنية: $details)');
        }
        throw Exception(message);
      }
      return result;
    }
    throw Exception('استجابة غير مفهومة من خدمة جمع الصور.');
  }

  String _sourceScope(String pageUrl) {
    final uri = Uri.parse(pageUrl);
    return uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  }

  String _imageKey(String rawUrl) {
    final uri = Uri.parse(rawUrl);
    const trackingKeys = <String>{
      'fbclid', 'gclid', 'dclid', 'msclkid', 'ref', 'source',
      'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
      'utm_id', 'campaign', 'tracking',
    };
    final kept = <String, List<String>>{};
    final entries = uri.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    for (final entry in entries) {
      if (!trackingKeys.contains(entry.key.toLowerCase())) {
        kept[entry.key] = entry.value.toList()..sort();
      }
    }
    final query = <String, String>{};
    for (final entry in kept.entries) {
      query[entry.key] = entry.value.join(',');
    }
    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      fragment: '',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  String _prefsKey(String scope) => 'silsila_image_collector_imported_v2_$scope';

  Future<void> _loadImportedForScope(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey(scope)) ?? <String>[];
    _importedImageKeys
      ..clear()
      ..addAll(saved);
    _importedScope = scope;
  }

  Future<void> _markImported(Iterable<String> keys) async {
    final scope = _importedScope;
    if (scope == null || keys.isEmpty) return;
    _importedImageKeys.addAll(keys);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(scope), _importedImageKeys.toList()..sort());
  }

  Future<void> _pasteClipboardUrl() async {
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final copiedText = clipboard?.text?.trim() ?? '';
      if (copiedText.isEmpty) {
        if (mounted) setState(() => _status = 'الحافظة فارغة؛ انسخ رابط صفحة المنتجات أولًا.');
        return;
      }
      _url.text = copiedText;
      _url.selection = TextSelection.collapsed(offset: _url.text.length);
      if (mounted) {
        setState(() {
          _error = null;
          _status = 'تم لصق الرابط المنسوخ في خانة رابط صفحة المنتجات.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'تعذر قراءة الرابط من الحافظة. الصق الرابط يدويًا.');
      }
    }
  }

  Future<void> _scan() async {
    final raw = _url.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'اكتب رابط صفحة المنتجات أولًا.');
      return;
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasScheme || !['http', 'https'].contains(parsed.scheme)) {
      setState(() => _error = 'أدخل رابطًا صحيحًا يبدأ بـ https:// أو http://');
      return;
    }
    FocusScope.of(context).unfocus();
    if (_imagesScrollController.hasClients) _imagesScrollController.jumpTo(0);
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ فحص الصفحة واستخراج الصور المتاحة...';
      _selected.clear();
      _images = [];
      _previewFutures.clear();
      _previewErrors.clear();
    });
    try {
      await _loadCategoryOptions();
      final scope = _sourceScope(parsed.toString());
      if (_importedScope != scope) await _loadImportedForScope(scope);
      final result = await _invoke({'action': 'scan', 'url': parsed.toString()});
      final rawImages = (result['images'] as List? ?? const []);
      final candidates = rawImages.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
      for (final image in candidates) { image['save_as'] = _imageKind; }
      final seen = <String>{};
      final images = <Map<String, dynamic>>[];
      var duplicateCount = 0;
      var previouslyImportedCount = 0;
      for (final image in candidates) {
        final rawImageUrl = image['url']?.toString() ?? '';
        if (rawImageUrl.isEmpty) continue;
        final key = _imageKey(rawImageUrl);
        if (!seen.add(key)) {
          duplicateCount++;
          continue;
        }
        if (_importedImageKeys.contains(key)) {
          previouslyImportedCount++;
          image['_previously_imported'] = true;
        } else {
          image['_previously_imported'] = false;
        }
        // Keep prior images visible; mark them and exclude them from the
        // default selection so they are not accidentally imported twice.
        images.add(image);
      }
      if (!mounted) return;
      setState(() {
        _pageUrl = result['page']?.toString() ?? parsed.toString();
        _images = images;
        _imagesPage = 0;
        _previouslyImportedCount = previouslyImportedCount;
        _duplicateCount = duplicateCount;
        // Select every newly collected image by default so the collector is
        // ready to save the complete result without requiring a manual step.
        _selected
          ..clear()
          ..addAll(images.where((image) => image['_previously_imported'] != true)
              .map((image) => image['url'].toString()));
        _status = images.isEmpty
            ? (candidates.isEmpty
                ? 'لم يتم العثور على صور ظاهرة في HTML. قد تعتمد الصفحة على JavaScript أو تمنع الوصول.'
                : 'لا توجد صور جديدة في هذه الصفحة.')
            : 'تم العثور على ${images.length} صورة. تعرض الصفحة حتى $_imagesPageSize صفوف؛ مرّر داخل قائمة الصفوف لعرض الباقي.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String url, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(url);
      } else {
        _selected.remove(url);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final selectable = _images.where((x) => x['_previously_imported'] != true).toList();
      if (selectable.isNotEmpty && _selected.length == selectable.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(selectable.map((x) => x['url'].toString()));
      }
    });
  }

  String _safeName(String value, {String fallback = 'image'}) {
    // Keep Arabic letters and digits in filenames; replace only filesystem-
    // unfriendly punctuation and whitespace with underscores.
    var name = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF_-]+'), '_');
    name = name.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (name.length > 100) name = name.substring(0, 100);
    return name.isEmpty ? fallback : name;
  }

  bool _looksLikeEntityName(String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > 120) return false;
    if (!RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(name)) return false;
    // Reject common technical image names such as -_275_2, IMG_1234 or 275x275.
    if (RegExp(r'^(?:(?:img|image|photo|dsc|pxl|pic)[-_ .]*)?\d+(?:[-_ .]+\d+)*$', caseSensitive: false).hasMatch(name)) return false;
    if (RegExp(r'^[-_ .]+\d+(?:[-_ .]+\d+)*$').hasMatch(name)) return false;
    if (RegExp(r'^(image|product|item|category|view|details|read more|عرض|صورة|منتج)$', caseSensitive: false).hasMatch(name)) return false;
    return true;
  }

  String _suggestedImageName(Map<String, dynamic> image, int index) {
    final kind = (image['save_as'] ?? 'product').toString();
    // Prefer actual catalog metadata and the product-card text around the image.
    final candidates = switch (kind) {
      'category' => [
          image['category_name'], image['category_name'], image['category'],
          image['category'], image['subcategory_name'], image['context_name'],
          image['product_name'], image['title'], image['name'], image['alt'],
        ],
      'brand' => [
          image['brand_name'], image['brand'], image['manufacturer'],
          image['context_name'], image['title'], image['name'], image['alt'],
        ],
      _ => [
          image['product_full_name'], image['product_name'],
          image['product_title'], image['sku_name'], image['item_name'],
          image['context_name'], image['title'], image['name'], image['alt'],
        ],
    };
    var suggested = '';
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (_looksLikeEntityName(value)) {
        suggested = value;
        break;
      }
    }
    if (suggested.isEmpty) {
      suggested = 'صورة_${(index + 1).toString().padLeft(3, '0')}';
    }
    if (kind != 'category' && kind != 'brand') {
      final unit = _excelValue(image, ['main_unit', 'unit', 'unit_name', 'major_unit']);
      final innerCount = _excelValue(image, [
        'internal_count', 'units_per_pack', 'pack_size', 'quantity_per_unit',
      ]);
      if (unit.isNotEmpty && !suggested.toLowerCase().contains(unit.toLowerCase())) {
        suggested = '$suggested $unit';
      }
      if (innerCount.isNotEmpty &&
          !RegExp(r'(^|[^0-9])' + RegExp.escape(innerCount) + r'([^0-9]|$)').hasMatch(suggested)) {
        suggested = '$suggested عدد داخلي $innerCount';
      }
    }
    return _safeName(suggested, fallback: 'صورة_${(index + 1).toString().padLeft(3, '0')}');
  }

  String _imageBaseName(Map<String, dynamic> image, int index) {
    final customName = image['file_name']?.toString().trim() ?? '';
    return _safeName(customName.isNotEmpty ? customName : _suggestedImageName(image, index),
        fallback: 'صورة_${(index + 1).toString().padLeft(3, '0')}');
  }

  String _uniqueFileName(String baseName, String extension, Set<String> usedNames) {
    var candidate = '$baseName$extension';
    var suffix = 2;
    while (!usedNames.add(candidate.toLowerCase())) {
      candidate = '${baseName}_$suffix$extension';
      suffix++;
    }
    return candidate;
  }




  String _excelValue(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }


  Uint8List _processTransparentPng(Uint8List source) => _processTransparentPngInBackground(source);

  Uint8List _buildProductDataExcel(List<Map<String, dynamic>> selectedImages) {
      final excel = Excel.createExcel();
      final sheet = excel['بيانات الأصناف'];
      sheet.appendRow([
        TextCellValue('م'),
        TextCellValue('نوع الصورة'),
        TextCellValue('اسم الصنف / الصورة'),
        TextCellValue('اسم الصنف الإنجليزي'),
        TextCellValue('الباركود'),
        TextCellValue('الوحدة الرئيسية'),
        TextCellValue('الوحدة الفرعية'),
        TextCellValue('العدد الداخلي'),
        TextCellValue('الوحدات الأخرى'),
        TextCellValue('سعر البيع'),
        TextCellValue('مساحة التسعير'),
        TextCellValue('نسبة الضريبة %'),
        TextCellValue('الفئة الرئيسية'),
        TextCellValue('الفئة الفرعية'),
        TextCellValue('الفئة الثانوية'),
        TextCellValue('العلامة التجارية'),
        TextCellValue('الوزن / الحجم'),
        TextCellValue('الرابط الأصلي للصورة'),
        TextCellValue('رابط صفحة المصدر'),
      ]);
      for (var i = 0; i < selectedImages.length; i++) {
        final item = selectedImages[i];
        final kind = (item['save_as'] ?? 'product').toString();
        final name = kind == 'category'
            ? _excelValue(item, ['category_name', 'category_name', 'category', 'title', 'alt', 'name'])
            : kind == 'brand'
                ? _excelValue(item, ['brand_name', 'brand', 'manufacturer', 'title', 'alt', 'name'])
                : _excelValue(item, [
                    'product_full_name', 'product_name', 'name', 'title', 'alt', 'file_name',
                  ]);
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(kind == 'category' ? 'فئة' : kind == 'brand' ? 'ماركة / براند' : 'صنف / منتج'),
          TextCellValue(name),
          TextCellValue(_excelValue(item, ['product_name_en', 'english_name', 'name_en'])),
          TextCellValue(_excelValue(item, ['barcode', 'gtin', 'ean', 'upc'])),
          TextCellValue(_excelValue(item, ['main_unit', 'unit', 'unit_name', 'major_unit'])),
          TextCellValue(_excelValue(item, ['sub_unit', 'minor_unit', 'small_unit'])),
          TextCellValue(_excelValue(item, ['internal_count', 'units_per_pack', 'pack_size', 'quantity_per_unit'])),
          TextCellValue(_excelValue(item, ['other_units', 'units'])),
          TextCellValue(_excelValue(item, ['sale_price', 'price', 'price_value'])),
          TextCellValue(_excelValue(item, ['pricing_area', 'price_area'])),
          TextCellValue(_excelValue(item, ['tax_rate', 'tax_percent', 'vat'])),
          TextCellValue(_excelValue(item, ['main_category', 'category_name', 'category'])),
          TextCellValue(_excelValue(item, ['sub_category', 'subcategory', 'category_name'])),
          TextCellValue(_excelValue(item, ['secondary_category', 'third_category'])),
          TextCellValue(_excelValue(item, ['brand', 'brand_name', 'manufacturer'])),
          TextCellValue(_excelValue(item, ['weight', 'volume', 'net_weight', 'size'])),
          TextCellValue(_excelValue(item, ['url', 'image_url'])),
          TextCellValue(_pageUrl ?? ''),
        ]);
      }
      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('تعذر إنشاء ملف Excel من البيانات المحددة.');
      }
      return Uint8List.fromList(bytes);
  }


  Future<String> _activeCompanyId() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('سجّل الدخول أولًا لاستخدام بيانات الأصناف.');
    final rows = await client.from('erp_company_members')
        .select('company_id').eq('user_id', userId).eq('is_active', true)
        .order('created_at').limit(1);
    if ((rows as List).isEmpty) throw Exception('لا توجد شركة نشطة مرتبطة بحسابك.');
    return rows.first['company_id'].toString();
  }

  String _byteaHex(Uint8List bytes) =>
      '\\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();


  TextEditingController _rowController(Map<String,dynamic> item,String field,{String initial=''}) {
    final key=(item['url']??'').toString()+'::'+field;
    return _rowControllers.putIfAbsent(key,()=>TextEditingController(text:(item[field]?.toString().isNotEmpty??false)?item[field].toString():initial));
  }

  Future<void> _lookupRowCode(Map<String,dynamic> item) async {
    if(_loading)return;
    final code=_rowController(item,'legacy_code').text.trim();
    if(code.isEmpty){setState(()=>_error='اكتب الكود القديم أولًا ثم اضغط بحث.');return;}
    setState(()=>_loading=true);
    try{
      final db=Supabase.instance.client;final company=await _activeCompanyId();
      if((item['save_as']??'product')=='category'){
        final raw=await db.from('erp_item_categories').select('id,parent_id,category_code:category_code,category_name:category_name,category_name_en:category_name_en').eq('company_id',company).eq('category_code',code).maybeSingle();
        if(raw==null)throw Exception('كود الفئة غير موجود في الشركة الحالية.');
        final rows=await db.from('erp_item_categories').select('id,parent_id,category_code:category_code,category_name:category_name,category_name_en:category_name_en').eq('company_id',company).limit(3000);
        final categories=(rows as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        Map<String,dynamic>? byId(dynamic id){for(final g in categories){if(id!=null&&g['id'].toString()==id.toString())return g;}return null;}
        final found=Map<String,dynamic>.from(raw);final parent=byId(found['parent_id']);final grand=byId(parent?['parent_id']);
        final Map<String,dynamic>? root=found['parent_id']==null?found:(parent?['parent_id']==null?parent:grand);
        final Map<String,dynamic>? sub=found['parent_id']==null?null:(parent?['parent_id']==null?found:parent);
        final Map<String,dynamic>? third=sub!=null&&found['id'].toString()!=sub['id'].toString()?found:null;
        item['category_root_id']=root?['id']?.toString();item['category_sub_id']=sub?['id']?.toString();item['category_secondary_id']=third?['id']?.toString();item['category_target_id']=found['id'].toString();
        _rowController(item,'category_main_name').text=(root?['category_name']??'').toString();
        _rowController(item,'category_sub_name').text=(sub?['category_name']??'').toString();
        _rowController(item,'category_secondary_name').text=(third?['category_name']??'').toString();
        _rowController(item,'category_main_name_en').text=(root?['category_name_en']??'').toString();
        _rowController(item,'category_sub_name_en').text=(sub?['category_name_en']??'').toString();
        _rowController(item,'category_secondary_name_en').text=(third?['category_name_en']??'').toString();
        item['category_level']=third!=null?'secondary':sub!=null?'sub':'root';
        item['entity_mode']='old';if(mounted)setState(()=>_status='تم تحميل الفئة القديمة '+code+'؛ راجع الأسماء ثم اضغط تحديث بيانات.');
      }else{
        final raw=await db.from('erp_items').select('id,item_name,item_name_en,base_unit,sale_price,tax_rate,pricing_area,package_description,weight_kg,length_cm,width_cm,height_cm').eq('company_id',company).eq('item_code',code).maybeSingle();
        if(raw==null)throw Exception('كود الصنف غير موجود في الشركة الحالية.');
        item['database_item_id']=raw['id'].toString();
        _rowController(item,'item_name_ar').text=(raw['item_name']??'').toString();_rowController(item,'item_name_en').text=(raw['item_name_en']??'').toString();
        _rowController(item,'minor_unit').text=(raw['base_unit']??'قطعة').toString();_rowController(item,'sale_price').text=(raw['sale_price']??0).toString();
        _rowController(item,'tax_rate').text=(raw['tax_rate']??0).toString();_rowController(item,'pricing_area').text=(raw['pricing_area']??1).toString();_rowController(item,'weight_kg').text=(raw['weight_kg']??0).toString();_rowController(item,'length_cm').text=(raw['length_cm']??0).toString();_rowController(item,'width_cm').text=(raw['width_cm']??0).toString();_rowController(item,'height_cm').text=(raw['height_cm']??0).toString();
        final desc=(raw['package_description']??'').toString().split('=');
        if(desc.length>1){_rowController(item,'major_unit').text=desc.first.trim();final p=desc[1].trim().split(RegExp(r'\s+'));if(p.isNotEmpty)_rowController(item,'internal_count').text=p.first;}
        final units=await db.from('erp_item_units').select('unit_name,conversion_factor,is_base_unit').eq('company_id',company).eq('item_id',raw['id'].toString()).eq('is_active',true);
        for(final u in (units as List).map((e)=>Map<String,dynamic>.from(e))){if(u['is_base_unit']==true)_rowController(item,'minor_unit').text=(u['unit_name']??'قطعة').toString();else if((double.tryParse((u['conversion_factor']??1).toString())??1)>1){_rowController(item,'major_unit').text=(u['unit_name']??'').toString();_rowController(item,'internal_count').text=(u['conversion_factor']??1).toString();}}
        item['entity_mode']='old';if(mounted)setState(()=>_status='تم تحميل الصنف القديم '+code+'؛ راجع البيانات ثم اضغط تحديث بيانات.');
      }
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<Map<String,dynamic>> _ensureRowCategory(SupabaseClient db,String company,List<Map<String,dynamic>> categories,String name,String? parent,String prefix,{String englishName=''}) async{
    final normalized=name.trim().replaceAll(RegExp(r'\s+'),' ').toLowerCase();
    for(final g in categories){if((g['parent_id']?.toString()??'')==(parent??'')&&(g['category_name']??'').toString().trim().replaceAll(RegExp(r'\s+'),' ').toLowerCase()==normalized){if(englishName.trim().isNotEmpty){await db.from('erp_item_categories').update({'category_name_en':englishName.trim()}).eq('id',g['id'].toString()).eq('company_id',company);g['category_name_en']=englishName.trim();}return g;}}
    var max=0;for(final g in categories){final m=RegExp('^'+prefix+r'(\d+)$',caseSensitive:false).firstMatch((g['category_code']??'').toString());if(m!=null){final n=int.tryParse(m.group(1)!)??0;if(n>max)max=n;}}
    final code=prefix+(max+1).toString().padLeft(4,'0');
    final row=await db.from('erp_item_categories').insert({'company_id':company,'parent_id':parent,'category_code':code,'category_name':name.trim(),'category_name_en':englishName.trim(),'is_active':true,'show_in_app':true,'image_url':null}).select('id,parent_id,category_code:category_code,category_name:category_name').single();
    final created=Map<String,dynamic>.from(row);categories.add(created);return created;
  }

  Future<void> _finishSavedRow(Map<String,dynamic> item,String message) async{
    final url=item['url']?.toString()??'';if(url.isNotEmpty)await _markImported({_imageKey(url)});if(!mounted)return;
    setState(() {
      _url.clear();
      _images=_images.where((x)=>x['url']?.toString()!=url&&_selected.contains(x['url']?.toString()??'')).toList();
      _selected..clear()..addAll(_images.map((x)=>x['url'].toString()));
      if(_images.isEmpty)_pageUrl=null;
      _error=null;
      _status=message+' تم مسح الرابط والصورة المحفوظة وغير المحددة، مع إبقاء الصور المحددة غير المحفوظة.';
    });
  }

  Future<void> _saveRowCategory(Map<String,dynamic> item) async{
    if(_loading)return;
    final db=Supabase.instance.client;final company=await _activeCompanyId();final mode=(item['entity_mode']??'new').toString();
    final main=_rowController(item,'category_main_name').text.trim(),subName=_rowController(item,'category_sub_name').text.trim(),thirdName=_rowController(item,'category_secondary_name').text.trim();
    final mainEn=_rowController(item,'category_main_name_en').text.trim(),subEn=_rowController(item,'category_sub_name_en').text.trim(),thirdEn=_rowController(item,'category_secondary_name_en').text.trim();
    final level=(item['category_level']??'root').toString();
    if(main.isEmpty){setState(()=>_error='اسم الفئة الرئيسية مطلوب.');return;}
    if(level!='root'&&subName.isEmpty){setState(()=>_error='اسم الفئة الفرعية مطلوب لهذا المستوى.');return;}
    if(level=='secondary'&&thirdName.isEmpty){setState(()=>_error='اسم الفئة الثانوية مطلوب.');return;}
    if(mode=='old'&&item['category_target_id']==null){setState(()=>_error='ابحث عن الكود القديم أولًا.');return;}
    setState(()=>_loading=true);
    try{
      final raw=await db.from('erp_item_categories').select('id,parent_id,category_code:category_code,category_name:category_name,category_name_en:category_name_en').eq('company_id',company).limit(3000);
      final categories=(raw as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      Map<String,dynamic>? byId(dynamic id){for(final g in categories){if(id!=null&&g['id'].toString()==id.toString())return g;}return null;}
      late Map<String,dynamic> target;
      if(mode=='old'){
        final root=byId(item['category_root_id']),sub=byId(item['category_sub_id']),third=byId(item['category_secondary_id']);
        if(root!=null)await db.from('erp_item_categories').update({'category_name':main,'category_name_en':mainEn}).eq('id',root['id'].toString()).eq('company_id',company);
        if(sub!=null&&subName.isNotEmpty)await db.from('erp_item_categories').update({'category_name':subName,'category_name_en':subEn}).eq('id',sub['id'].toString()).eq('company_id',company);
        if(third!=null&&thirdName.isNotEmpty)await db.from('erp_item_categories').update({'category_name':thirdName,'category_name_en':thirdEn}).eq('id',third['id'].toString()).eq('company_id',company);
        target=byId(item['category_target_id'])!;
      }else{
        final root=await _ensureRowCategory(db,company,categories,main,null,'C',englishName:mainEn);Map<String,dynamic>? sub,third;
        if(level!='root')sub=await _ensureRowCategory(db,company,categories,subName,root['id'].toString(),'S',englishName:subEn);
        if(level=='secondary'){if(sub==null)throw Exception('الفئة الثانوية تتطلب فئة فرعية.');third=await _ensureRowCategory(db,company,categories,thirdName,sub['id'].toString(),'T',englishName:thirdEn);}
        target=third??sub??root;
      }
      final downloaded=await _invoke({'action':'download','url':item['url'].toString(),'referer':_pageUrl ?? _url.text.trim()});final b64=downloaded['base64']?.toString();if(b64==null||b64.isEmpty)throw Exception('لم تصل بيانات الصورة.');
      final png=_processTransparentPng(Uint8List.fromList(base64Decode(b64)));
      await db.from('erp_item_categories').update({'image_data':_byteaHex(png),'image_mime_type':'image/png','image_url':null}).eq('id',target['id'].toString()).eq('company_id',company);
      await _finishSavedRow(item,(mode=='old'?'تم تحديث الفئة ':'تم تكويد الفئة ')+(target['category_code']??'').toString()+' وحفظ صورة PNG في قاعدة البيانات.');
    }catch(e){if(mounted)setState(()=>_error='تعذر حفظ الفئة: '+e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _saveRowProduct(Map<String,dynamic> item) async{
    if(_loading)return;
    final db=Supabase.instance.client;final company=await _activeCompanyId();final mode=(item['entity_mode']??'new').toString();
    final ar=_rowController(item,'item_name_ar',initial:_suggestedImageName(item,_images.indexOf(item))).text.trim();
    final en=_rowController(item,'item_name_en',initial:_excelValue(item,['product_name_en','english_name','name_en'])).text.trim();
    final major=_rowController(item,'major_unit',initial:_excelValue(item,['major_unit','main_unit','unit'])).text.trim(),minor=_rowController(item,'minor_unit',initial:_excelValue(item,['minor_unit','sub_unit','small_unit'])).text.trim();
    final count=double.tryParse(_rowController(item,'internal_count',initial:_excelValue(item,['internal_count','units_per_pack','pack_size','quantity_per_unit'])).text.trim());
    final price=double.tryParse(_rowController(item,'sale_price',initial:_excelValue(item,['sale_price','price','price_value'])).text.trim()),area=double.tryParse(_rowController(item,'pricing_area',initial:_excelValue(item,['pricing_area','price_area'])).text.trim()),tax=double.tryParse(_rowController(item,'tax_rate',initial:_excelValue(item,['tax_rate','tax_percent','vat'])).text.trim());
    if(ar.isEmpty){setState(()=>_error='اسم الصنف العربي مطلوب.');return;}if(major.isEmpty||minor.isEmpty){setState(()=>_error='اختر الوحدة الكبرى والصغرى.');return;}
    if(count==null||count<=0){setState(()=>_error='العدد الداخلي يجب أن يكون أكبر من صفر.');return;}if(price==null||price<0){setState(()=>_error='سعر الصنف غير صحيح.');return;}
    if(area==null||area<0){setState(()=>_error='مساحة التسعير غير صحيحة.');return;}if(tax==null||tax<0||tax>100){setState(()=>_error='نسبة الضريبة يجب أن تكون بين 0 و100.');return;}
    final oldCode=_rowController(item,'legacy_code').text.trim();if(mode=='old'&&(item['database_item_id']==null||oldCode.isEmpty)){setState(()=>_error='ابحث عن كود الصنف القديم أولًا.');return;}
    setState(()=>_loading=true);
    try{
      var code=oldCode;
      if(mode=='new'){final rows=await db.from('erp_items').select('item_code').eq('company_id',company).like('item_code','ITEM-%').limit(5000);var max=0;for(final r in (rows as List)){final m=RegExp(r'-(\d+)$').firstMatch((r['item_code']??'').toString());if(m!=null){final n=int.tryParse(m.group(1)!)??0;if(n>max)max=n;}}code='ITEM-'+(max+1).toString().padLeft(4,'0');}
      final downloaded=await _invoke({'action':'download','url':item['url'].toString(),'referer':_pageUrl ?? _url.text.trim()});final b64=downloaded['base64']?.toString();if(b64==null||b64.isEmpty)throw Exception('لم تصل بيانات الصورة.');
      final png=_processTransparentPng(Uint8List.fromList(base64Decode(b64)));
      final values=<String,dynamic>{'item_name':ar,'item_name_en':en,'base_unit':minor,'sale_price':price,'tax_rate':tax,'pricing_area':area,'package_description':major+' = '+count.toStringAsFixed(3)+' '+minor,'weight_kg':double.tryParse(_rowController(item,'weight_kg').text.trim()) ?? 0,'length_cm':double.tryParse(_rowController(item,'length_cm').text.trim()) ?? 0,'width_cm':double.tryParse(_rowController(item,'width_cm').text.trim()) ?? 0,'height_cm':double.tryParse(_rowController(item,'height_cm').text.trim()) ?? 0,'image_data':_byteaHex(png),'image_mime_type':'image/png','image_url':null,'source_name':'جامع صور سلسلة','source_url':item['url'].toString(),'is_active':true};
      final selectedCategoryId = item['category_secondary_id']?.toString() ?? item['category_sub_id']?.toString() ?? item['category_root_id']?.toString();
      if (selectedCategoryId != null && selectedCategoryId.isNotEmpty) values['category_id'] = selectedCategoryId;
      String id;
      if(mode=='new'){final inserted=await db.from('erp_items').insert({...values,'company_id':company,'item_code':code,'purchase_price':0,'category_id':selectedCategoryId}).select('id').single();id=inserted['id'].toString();}
      else{id=item['database_item_id'].toString();await db.from('erp_items').update(values).eq('id',id).eq('company_id',company);}
      await db.from('erp_item_units').update({'is_base_unit':false}).eq('company_id',company).eq('item_id',id);
      await db.from('erp_item_units').upsert([{'company_id':company,'item_id':id,'unit_code':'MAJOR','unit_name':major,'conversion_factor':count,'is_base_unit':false,'is_active':true},{'company_id':company,'item_id':id,'unit_code':'MINOR','unit_name':minor,'conversion_factor':1,'is_base_unit':true,'is_active':true}],onConflict:'item_id,unit_code');
      await _finishSavedRow(item,(mode=='new'?'تم إنشاء الصنف ':'تم تحديث الصنف ')+code+' وحفظ الصورة والبيانات في قاعدة البيانات.');
    }catch(e){if(mounted)setState(()=>_error='تعذر حفظ الصنف: '+e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _saveZip() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'حدد صورة واحدة على الأقل قبل التنزيل.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ تنزيل الصور المحددة وتجهيز ملف ZIP والصورة وExcel...';
    });
    try {
      final archive = Archive();
      var index = 0;
      final usedFileNames = <String>{};
      final savedImageKeys = <String>{};
      for (final image in _images.where((x) => _selected.contains(x['url'].toString()))) {
        final imageIndex = _images.indexOf(image);
        index++;
        final url = image['url'].toString();
        final downloaded = await _invoke({'action': 'download', 'url': url});
        final encoded = downloaded['base64']?.toString();
        if (encoded == null || encoded.isEmpty) continue;
        final sourceBytes = Uint8List.fromList(base64Decode(encoded));
        final bytes = _processTransparentPng(sourceBytes);
        const extension = '.png';
        final title = _imageBaseName(image, imageIndex < 0 ? index - 1 : imageIndex);
        final fileName = _uniqueFileName(title, extension, usedFileNames);
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        savedImageKeys.add(_imageKey(url));
        if (mounted) setState(() => _status = 'تم تجهيز $index من ${_selected.length} صورة...');
      }
      if (archive.isEmpty) throw Exception('لم يمكن تنزيل أي صورة من الاختيارات.');
      final selectedImages = _images
          .where((item) => _selected.contains(item['url']?.toString() ?? ''))
          .toList();
      final excelBytes = _buildProductDataExcel(selectedImages);
      archive.addFile(ArchiveFile('بيانات_الأصناف.xlsx', excelBytes.length, excelBytes));
      final zipped = ZipEncoder().encode(archive);
      if (zipped == null || zipped.isEmpty) throw Exception('تعذر إنشاء ملف ZIP.');
      await FileSaver.instance.saveFile(
        name: 'silsila_images_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(zipped),
        fileExtension: 'zip',
        mimeType: MimeType.zip,
      );
      await _markImported(savedImageKeys);
      if (mounted) {
        setState(() {
          _url.clear();
          // The ZIP contains every selected image. Remove the entire scan result,
          // including unchecked images, so the next page starts with a clean grid.
          _images = [];
          _selected.clear();
          _pageUrl = null;
          _status = 'تم حفظ الصور وملف Excel داخل ZIP. تم مسح الرابط والصور من الشاشة؛ الصق الرابط التالي وابدأ السحب.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveOne(Map<String, dynamic> image) async {
    // This action is deliberately scoped to one row: download its PNG only.
    // It must not clear the URL, change selection, mark the source as imported,
    // or remove any other image from the current collection.
    if (_loading || image['downloaded_to_device'] == true) return;
    final url = image['url'].toString();
    _downloadingUrls.add(url);
    setState(() {
      _error = null;
      _status = 'جارٍ تجهيز صورة الصف المحدد للتنزيل...';
    });
    try {
      final result = await _invoke({'action': 'download', 'url': url});
      final encoded = result['base64']?.toString();
      if (encoded == null || encoded.isEmpty) throw Exception('لم تصل بيانات الصورة.');
      final sourceBytes = Uint8List.fromList(base64Decode(encoded));
      await Future<void>.delayed(Duration.zero);
      final bytes = await compute(_processTransparentPngInBackground, sourceBytes);
      final imageIndex = _images.indexOf(image);
      final baseName = _imageBaseName(image, imageIndex < 0 ? 0 : imageIndex);
      final matchingIndexes = _images.asMap().entries
          .where((entry) => _imageBaseName(entry.value, entry.key).toLowerCase() == baseName.toLowerCase())
          .map((entry) => entry.key)
          .toList();
      final occurrence = matchingIndexes.indexOf(imageIndex);
      final uniqueBaseName = occurrence > 0 ? '${baseName}_${occurrence + 1}' : baseName;
      await FileSaver.instance.saveFile(
        name: uniqueBaseName,
        bytes: bytes,
        fileExtension: 'png',
      );
      if (mounted) {
        setState(() {
          image['downloaded_to_device'] = true;
          _status = 'تم تنزيل صورة الصف رقم ${imageIndex + 1} إلى الجهاز باسم $uniqueBaseName.png. باقي الصفوف والرابط والتحديد لم تتغير.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _downloadingUrls.remove(url);
      if (mounted) setState(() {});
    }
  }

  Future<Uint8List?> _previewImageBytes(String url) {
    return _previewFutures.putIfAbsent(url, () async {
      try {
        final result = await _invoke({
          'action': 'download',
          'url': url,
          'referer': _pageUrl ?? _url.text.trim(),
        });
        final encoded = result['base64']?.toString() ?? '';
        if (encoded.isEmpty) {
          _previewErrors[url] = 'الخدمة لم تُرجع بيانات صورة.';
          return null;
        }
        final bytes = Uint8List.fromList(base64Decode(encoded));
        if (bytes.length < 16) {
          _previewErrors[url] = 'ملف الصورة فارغ أو غير مكتمل.';
          return null;
        }
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          _previewErrors[url] = 'المصدر لم يُرجع صورة قابلة للفك؛ قد يكون رابطًا منتهيًا أو صفحة خطأ.';
          return null;
        }
        final width = decoded.width;
        final height = decoded.height;
        final shortSide = width < height ? width : height;
        final longSide = width > height ? width : height;
        final aspectRatio = longSide / shortSide;
        // Reject tiny assets and very wide/tall UI strips before showing them
        // as product candidates. Keep ordinary portrait/landscape package shots.
        if (width < 80 || height < 70 || (longSide >= 240 && aspectRatio >= 4.0)) {
          _previewErrors[url] = (aspectRatio >= 4.0 && longSide >= 240)
              ? 'تم استبعاد صورة شريط/أيقونة (${width}×${height}) لأن أبعادها طويلة جدًا وليست صورة صنف.'
              : 'تم تجاهل صورة صغيرة/أيقونة (${width}×${height}) وليست صورة صنف مناسبة.';
          return null;
        }
        // Reject blank tracking/placeholder graphics while keeping normal product
        // shots with white backgrounds. Sample a coarse grid, not every pixel.
        final sampledColors = <int>{};
        var visibleSamples = 0;
        for (var sy = 0; sy < 12; sy++) {
          for (var sx = 0; sx < 12; sx++) {
            final p = decoded.getPixel(
              (sx * (decoded.width - 1) / 11).round(),
              (sy * (decoded.height - 1) / 11).round(),
            );
            if (p.a.toInt() > 12) visibleSamples++;
            sampledColors.add(
              ((p.r.toInt() ~/ 24) << 16) |
              ((p.g.toInt() ~/ 24) << 8) |
              (p.b.toInt() ~/ 24),
            );
          }
        }
        if (visibleSamples < 8 || sampledColors.length < 4) {
          _previewErrors[url] = 'الصورة المستلمة فارغة أو جرافيك ثابت/Placeholder؛ لم تُعرض كصورة صنف.';
          return null;
        }
        return bytes;
      } catch (e) {
        _previewErrors[url] = e.toString().replaceFirst('Exception: ', '');
        return null;
      }
    });
  }

  Widget _imagePreviewTile(String url) {
    return FutureBuilder<Uint8List?>(
      future: _previewImageBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(
            color: const Color(0xFFFFF3F0),
            padding: const EdgeInsets.all(7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined, size: 30, color: Colors.redAccent),
                const SizedBox(height: 5),
                Text(
                  _previewErrors[url] ?? 'تعذر تحميل الصورة الأصلية',
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                ),
              ],
            ),
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFFFF3F0),
            padding: const EdgeInsets.all(7),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, size: 30, color: Colors.redAccent),
                Text('البيانات المستلمة ليست صورة قابلة للعرض', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.redAccent)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showImagePreview(String url) async {
    final bytes = await _previewImageBytes(url);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(width: MediaQuery.of(context).size.width > 960 ? 900 : MediaQuery.of(context).size.width * .92, height: MediaQuery.of(context).size.height * .82,
        child: Stack(children: [
          Positioned.fill(child: InteractiveViewer(minScale: .5, maxScale: 5, child: Center(
            child: bytes == null
                ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64))
                : Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64)))))),
          PositionedDirectional(top: 6, start: 6, child: IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))),
        ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selectableCount = _images.where((x) => x['_previously_imported'] != true).length;
    final allSelected = selectableCount > 0 && _selected.length == selectableCount;
    final pageCount = (_images.length / _imagesPageSize).ceil();
    final int safePage = pageCount == 0 ? 0 : _imagesPage.clamp(0, pageCount - 1).toInt();
    final pageStart = safePage * _imagesPageSize;
    final visibleImages = _images.skip(pageStart).take(_imagesPageSize).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _purple.withValues(alpha: .12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: _purple.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.photo_library_outlined, color: _purple, size: 27),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('جامع صور الأصناف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _purple)),
                    SizedBox(height: 4),
                    Text('استخراج الصور، تفريغ الخلفية الفاتحة، وتجهيز PNG حتى 4K مضغوط', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF8F5FB), borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      const Text('نوع الصور', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Checkbox(shape:const CircleBorder(),value: _imageKind == 'category', activeColor: _purple, visualDensity: VisualDensity.compact,
                          onChanged: _loading ? null : (checked) { if (checked == true) setState(() { _imageKind = 'category'; for (final image in _images) { image['save_as'] = 'category'; image.remove('file_name'); } }); }),
                        const Icon(Icons.category_outlined, color: _purple, size: 20),
                        const SizedBox(width: 3), const Text('فئة', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Checkbox(shape:const CircleBorder(),value: _imageKind == 'product', activeColor: _purple, visualDensity: VisualDensity.compact,
                          onChanged: _loading ? null : (checked) { if (checked == true) setState(() { _imageKind = 'product'; for (final image in _images) { image['save_as'] = 'product'; image.remove('file_name'); } }); }),
                        const Icon(Icons.inventory_2_outlined, color: _purple, size: 20),
                        const SizedBox(width: 3), const Text('صنف', style: TextStyle(fontSize: 12)),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  const SizedBox(width: 175, child: Text('رابط صفحة المنتجات', style: TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 2, child: TextField(controller: _url, keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr, onSubmitted: (_) => _loading ? null : _scan(),
                    decoration: InputDecoration(hintText: 'https://www.example.com/products',
                      prefixIcon: const Icon(Icons.link), isDense: true, filled: true,
                      fillColor: const Color(0xFFF8F5FB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _loading ? null : () { setState(() { _url.clear(); _error = null; _status = 'تم مسح الرابط.'; }); },
                    icon: const Icon(Icons.backspace_outlined, size: 17), label: const Text('مسح الرابط'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact)),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(onPressed: _loading ? null : _pasteClipboardUrl,
                    icon: const Icon(Icons.content_paste_rounded, size: 17), label: const Text('لصق الرابط'),
                    style: OutlinedButton.styleFrom(foregroundColor: _purple, visualDensity: VisualDensity.compact)),
                ]),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _scan,
                    icon: _loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.travel_explore),
                    label: const Text('فحص الصفحة وجمع الصور'),
                    style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _images.isEmpty ? null : _selectAll,
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allSelected ? 'إلغاء تحديد الصور الجديدة' : 'تحديد الصور الجديدة ($selectableCount)'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading || _selected.isEmpty ? null : _saveZip,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: Text('تصدير PNG وExcel مضغوط (${_selected.length})'),
                    style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _resetImportHistory,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('إعادة ضبط سجل السحب'),
                  ),
                  ]),
                ),
                if (_pageUrl != null) ...[
                  const SizedBox(height: 10),
                ],
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_status, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: .07), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'ملاحظة: بعض المواقع تعرض الصور بواسطة JavaScript أو تمنع الطلبات الآلية؛ في هذه الحالة قد لا تظهر كل الصور. تفريغ الخلفية يستهدف الخلفيات الفاتحة المتصلة بحواف الصورة؛ راجع الصور قبل اعتمادها. تكبير الصورة لا يعيد تفاصيل غير موجودة في المصدر. استخدم الصور وفق حقوق الموقع.',
                  style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.5),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            const Text('الصور المستخرجة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(child: Tooltip(message: 'تم تجاهل $_duplicateCount صورة مكررة داخل الصفحة', child: Text('${_images.length} صورة (${_previouslyImportedCount} سبق تسجيلها، ${_images.length - _previouslyImportedCount} جديدة) • ${_selected.length} محددة', style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis))),
            const SizedBox(width: 8),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(color: _purple.withValues(alpha: .06), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _purple.withValues(alpha: .12))),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: const [
                SizedBox(width: 42, child: Text('اختيار', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                SizedBox(width: 38, child: Text('م', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                SizedBox(width: 58, child: Text('الصورة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                SizedBox(width: 8), SizedBox(width: 185, child: Text('اسم الصورة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                SizedBox(width: 8), SizedBox(width: 140, child: Text('نوع الصورة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                SizedBox(width: 8), Text('تنزيل على الجهاز', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10)),
              ])),
            )),
          ]),
          const SizedBox(height: 6),
          if (_images.isNotEmpty) ...[
            Row(children: [
              Text('عرض ${pageStart + 1}–${(pageStart + visibleImages.length)} من ${_images.length} صف', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(tooltip: 'أول صفحة', onPressed: safePage > 0 ? () => setState(() { _imagesPage = 0; if (_imagesScrollController.hasClients) _imagesScrollController.jumpTo(0); }) : null, icon: const Icon(Icons.first_page)),
              IconButton(tooltip: 'الصفحة السابقة', onPressed: safePage > 0 ? () => setState(() { _imagesPage = safePage - 1; if (_imagesScrollController.hasClients) _imagesScrollController.jumpTo(0); }) : null, icon: const Icon(Icons.chevron_left)),
              Text('صفحة ${safePage + 1} من $pageCount', style: const TextStyle(fontSize: 12)),
              IconButton(tooltip: 'الصفحة التالية', onPressed: safePage + 1 < pageCount ? () => setState(() { _imagesPage = safePage + 1; if (_imagesScrollController.hasClients) _imagesScrollController.jumpTo(0); }) : null, icon: const Icon(Icons.chevron_right)),
              IconButton(tooltip: 'آخر صفحة', onPressed: safePage + 1 < pageCount ? () => setState(() { _imagesPage = pageCount - 1; if (_imagesScrollController.hasClients) _imagesScrollController.jumpTo(0); }) : null, icon: const Icon(Icons.last_page)),
            ]),
          ],
          if (_images.isEmpty)
            SizedBox(
              height: 220,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.image_search_outlined, size: 54, color: _purple.withValues(alpha: .35)),
                const SizedBox(height: 10),
                const Text('ضع رابط صفحة ثم اضغط «فحص الصفحة وجمع الصور»', style: TextStyle(color: Colors.black54)),
              ])),
            )
          else
            SizedBox(height: MediaQuery.of(context).size.height * 0.68,
              child: Column(children: [
                Expanded(child: Scrollbar(
                  controller: _imagesScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
              controller: _imagesScrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(visibleImages.length, (localIndex) {
                final index = pageStart + localIndex;
                final item=visibleImages[localIndex]; final url=item['url'].toString(); final selected=_selected.contains(url);
                final kind=(item['save_as']??'product').toString(); final mode=(item['entity_mode']??'new').toString();
                Widget field(String key,String label,{double width=180,String initial='',TextInputType type=TextInputType.text}) {
                  return SizedBox(width:width,child:Focus(
                    onKeyEvent:(node,event){
                      if(key=='legacy_code' && event is KeyDownEvent && event.logicalKey==LogicalKeyboardKey.f1){
                        _openF1Lookup(item); return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child:TextField(controller:_rowController(item,key,initial:initial),keyboardType:type,
                    inputFormatters: (type == TextInputType.number || type == const TextInputType.numberWithOptions(decimal:true)) ? [TextInputFormatter.withFunction((oldValue, newValue) => RegExp(r'^\d*\.?\d{0,3}$').hasMatch(newValue.text) ? newValue : oldValue)] : null,
                    onChanged:(v)=>item[key]=v,decoration:InputDecoration(hintText:label,labelText:null,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:6,vertical:7)))));
                }
                Widget dropdown(String key,String label,String value,List<String> options,{double width=145}) {
                  final choices=options.contains(value)?options:<String>[value,...options];
                  return SizedBox(width:width,child:DropdownButtonFormField<String>(value:choices.firstWhere((v)=>v==value,orElse:()=>choices.first),isExpanded:true,
                    decoration:InputDecoration(hintText:label,labelText:null,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:7,vertical:7)),
                    items:choices.map((v)=>DropdownMenuItem(value:v,child:Text(key=='entity_mode'?(v=='new'?'كود جديد':'كود قديم'):key=='save_as'?(v=='category'?'فئة':'صنف'):key=='major_unit'&&v.isEmpty?'وحدة كبرى':key=='minor_unit'&&v.isEmpty?'وحدة صغرى':v,overflow:TextOverflow.ellipsis))).toList(),
                    onChanged:_loading?null:(v){if(v==null)return;setState((){item[key]=v;if(key=='major_unit'||key=='minor_unit')_rowController(item,key).text=v;if(key=='save_as'){item.remove('entity_mode');item.remove('database_item_id');item.remove('category_target_id');}});}));
                }
                final suggested=_suggestedImageName(item,index);
                var productName='';
                for(final candidate in [item['product_full_name'],item['product_name'],item['product_title'],item['sku_name'],item['item_name'],item['context_name'],item['title'],item['name'],item['alt']]){
                  final value=candidate?.toString().trim()??'';
                  if(_looksLikeEntityName(value)){productName=value;break;}
                }
                final productUnit=_excelValue(item,['main_unit','unit','unit_name','major_unit']);
                if(productName.isNotEmpty&&productUnit.isNotEmpty&&!productName.toLowerCase().contains(productUnit.toLowerCase()))productName=productName+' '+productUnit;
                final productCount=_excelValue(item,['internal_count','units_per_pack','pack_size','quantity_per_unit']);
                if(productName.isNotEmpty&&productCount.isNotEmpty&&!RegExp(r'(^|[^0-9])'+RegExp.escape(productCount)+r'([^0-9]|$)').hasMatch(productName))productName=productName+' عدد داخلي '+productCount;
                Widget modeChoice(String value,String label) => InkWell(
                  onTap:_loading?null:(){setState((){item['entity_mode']=value;if(value=='new'){item.remove('database_item_id');item.remove('legacy_code');}},
                  );},
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    Checkbox(shape:const CircleBorder(),visualDensity:VisualDensity.compact,materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,value:mode==value,activeColor:_purple,onChanged:_loading?null:(v){if(v==true)setState((){item['entity_mode']=value;if(value=='new'){item.remove('database_item_id');item.remove('legacy_code');}});}),
                    Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600)),
                  ]),
                );
                final common=SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                  SizedBox(width:34,child:Checkbox(shape:const CircleBorder(),visualDensity:VisualDensity.compact,materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,value:selected,activeColor:_purple,onChanged:_loading?null:(v)=>_toggle(url,v))),
                  SizedBox(width:30,child:Text((index+1).toString(),textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800))),
                  if(item['_previously_imported']==true) const Padding(padding:EdgeInsets.symmetric(horizontal:4),child:Text('سبق تسجيلها',style:TextStyle(fontSize:10,color:Colors.deepOrange,fontWeight:FontWeight.w700))),
                  const SizedBox(width:5),
                  const SizedBox(width:4),
                  modeChoice('new','كود جديد'),
                  const SizedBox(width:2),
                  modeChoice('old','كود قديم'),
                  const SizedBox(width:4),
                  if(mode=='new') Padding(
                    padding: const EdgeInsets.symmetric(horizontal:3),
                    child: Text(kind=='category'
                      ? 'كود مقترح: يُنشأ تلقائيًا'
                      : 'كود مقترح: يُنشأ تلقائيًا',
                      style: const TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:_purple)),
                  ),
                  const SizedBox(width:2),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => kind == 'category' ? _saveRowCategory(item) : _saveRowProduct(item),
                    icon: Icon(mode == 'old' ? Icons.save_outlined : Icons.add_circle_outline, size: 16),
                    label: Text(mode == 'old' ? 'تحديث بيانات' : 'تكويد جديد'),
                    style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(width:4),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _openF1Lookup(item),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('بحث F1'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]));
                final editor=kind=='category'
                  ? Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                        dropdown('save_as','نوع الصورة',kind,const ['product','category'],width:112),const SizedBox(width:6),
                        dropdown('category_level','مستوى الفئة',(item['category_level']??'root').toString(),const ['root','sub','secondary'],width:135),const SizedBox(width:6),
                        if(mode=='old')... [field('legacy_code','كود الفئة القديم',width:125),const SizedBox(width:5)],
                        field('category_main_name','اسم الفئة الرئيسية عربي',width:170,initial:_excelValue(item,['main_category','category_name','category'])),const SizedBox(width:5),
                        field('category_main_name_en','اسم الفئة الرئيسية إنجليزي',width:170,initial:_excelValue(item,['main_category_en','category_name_en'])),
                      ])),
                      const SizedBox(height:3),
                      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                        field('category_sub_name','اسم الفئة الفرعية عربي',width:170,initial:_excelValue(item,['sub_category','subcategory'])),const SizedBox(width:5),
                        field('category_sub_name_en','اسم الفئة الفرعية إنجليزي',width:170,initial:_excelValue(item,['sub_category_en'])),
                        const SizedBox(width:8),
                      ])),
                      const SizedBox(height:3),
                      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                        field('category_secondary_name','اسم الفئة الثانوية عربي',width:170,initial:_excelValue(item,['secondary_category','third_category'])),const SizedBox(width:5),
                        field('category_secondary_name_en','اسم الفئة الثانوية إنجليزي',width:170,initial:_excelValue(item,['secondary_category_en'])),
                        const SizedBox(width:8),
                      ])),
                    ])
                  : Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                        dropdown('save_as','نوع الصورة',kind,const ['product','category'],width:112),
                        const SizedBox(width:6),
                        field(mode=='old'?'legacy_code':'item_code','كود الصنف',width:125,initial:mode=='old'?'':_excelValue(item,['item_code','sku','product_code'])),const SizedBox(width:6),
                        field('item_name_ar','اسم صنف عربي',width:175,initial:productName),const SizedBox(width:6),
                        field('item_name_en','اسم صنف إنجليزي',width:155,initial:_excelValue(item,['product_name_en','english_name','name_en'])),const SizedBox(width:6),
                      ])),
                      const SizedBox(height:3),
                      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                        dropdown('major_unit','وحدة كبرى',_rowController(item,'major_unit',initial:_excelValue(item,['major_unit','main_unit','unit'])).text,const ['','كرتونة','شدة','باكو','علبة','زجاجة','كيس','كيلو','جرام','لتر','مللي','قطعة','عبوة'],width:108),const SizedBox(width:4),
                        field('internal_count','عدد داخلي',width:100,initial:_excelValue(item,['internal_count','units_per_pack','pack_size','quantity_per_unit']).isEmpty?'1000.000':_excelValue(item,['internal_count','units_per_pack','pack_size','quantity_per_unit']),type:const TextInputType.numberWithOptions(decimal:true)),const SizedBox(width:4),
                        dropdown('minor_unit','وحدة صغرى',_rowController(item,'minor_unit',initial:_excelValue(item,['minor_unit','sub_unit','small_unit'])).text,const ['','قطعة','عبوة','علبة','زجاجة','كيس','جرام','مللي','وحدة'],width:108),const SizedBox(width:6),
                      ])),
                      const SizedBox(height:3),
                      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                        field('weight_kg','وزن الصنف (كجم)',width:130,initial:_excelValue(item,['weight_kg','weight','net_weight']),type:const TextInputType.numberWithOptions(decimal:true)),
                        const SizedBox(width:4),
                        field('length_cm','الطول (سم)',width:112,initial:_excelValue(item,['length_cm','length']),type:const TextInputType.numberWithOptions(decimal:true)),
                        const SizedBox(width:4),
                        field('width_cm','العرض (سم)',width:112,initial:_excelValue(item,['width_cm','width']),type:const TextInputType.numberWithOptions(decimal:true)),
                        const SizedBox(width:4),
                        field('height_cm','الارتفاع (سم)',width:112,initial:_excelValue(item,['height_cm','height']),type:const TextInputType.numberWithOptions(decimal:true)),
                      ])),
                    ]);
                final categoryEditor = kind == 'product'
                    ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                        _categoryChoice(item, 'category_root_id', 'فئة رئيسية', _categoriesForParent(null), enabled: mode == 'new' || item['category_root_id'] != null),
                        const SizedBox(width: 6),
                        _categoryChoice(item, 'category_sub_id', 'فئة فرعية', _categoriesForParent(item['category_root_id']?.toString()), enabled: item['category_root_id'] != null),
                        const SizedBox(width: 6),
                        _categoryChoice(item, 'category_secondary_id', 'فئة ثانوية', _categoriesForParent(item['category_sub_id']?.toString()), enabled: item['category_sub_id'] != null),
                        const SizedBox(width: 8),
                      ]))
                    : const SizedBox.shrink();
                return Container(margin:const EdgeInsets.only(bottom:1),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8),border:Border.all(color:selected?_purple.withValues(alpha:.65):const Color(0xFFE7E0EE),width:selected?1.5:1)),
                  child:Row(textDirection: TextDirection.rtl,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                    SizedBox(
                      width: 150,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(3,2,3,2),
                        child: Column(mainAxisSize:MainAxisSize.min,children:[
                          SizedBox(height:76,child:Material(
                            color: const Color(0xFFF7F4F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color:_purple.withValues(alpha:.22))),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _showImagePreview(url),
                              child: ClipRRect(borderRadius: BorderRadius.circular(10),child:_imagePreviewTile(url)),
                            ),
                          )),
                          const SizedBox(height:3),
                          TextField(controller:_rowController(item,'file_name',initial:suggested),
                            decoration:const InputDecoration(hintText:'اسم الصورة',isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:4)),
                            style:const TextStyle(fontSize:11),onChanged:(v)=>item['file_name']=v),
                          const SizedBox(height:3),
                          SizedBox(width:double.infinity,child:FilledButton.icon(
                            onPressed:_loading || _downloadingUrls.contains(url) || item['downloaded_to_device']==true ? null : () => _saveOne(item),
                            icon:Icon(item['downloaded_to_device']==true?Icons.check_circle_outline_rounded:_downloadingUrls.contains(url)?Icons.hourglass_top_rounded:Icons.download_for_offline_outlined,size:15),
                            label:Text(item['downloaded_to_device']==true?'تم التنزيل':_downloadingUrls.contains(url)?'جارٍ التنزيل':'تنزيل الصورة',style:const TextStyle(fontSize:10)),
                            style:FilledButton.styleFrom(backgroundColor:item['downloaded_to_device']==true?const Color(0xFFE8F5E9):_purple,foregroundColor:item['downloaded_to_device']==true?const Color(0xFF1B5E20):Colors.white,padding:const EdgeInsets.symmetric(horizontal:3,vertical:4),visualDensity:VisualDensity.compact,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9))),
                          )),
                        ]),
                      ),
                    ),
                    const VerticalDivider(width:1),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                      Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:0),child:common),
                      const SizedBox(height:3),
                      Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:0),child:editor),
                      if (kind == 'product') ...[
                        const SizedBox(height:3),
                        Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:0),child:categoryEditor),
                      ],
                    ])),
                  ]));
                }),
              ),
            ))),
              ]),
            ),
        ],
      ),
    );
  }

}