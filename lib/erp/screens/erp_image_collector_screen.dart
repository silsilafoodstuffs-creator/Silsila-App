import 'dart:convert';
import 'package:image/image.dart' as img;

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _importedScope;

  @override
  void initState() {
    super.initState();
    _clearLegacyTestHistory();
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
      _selected.clear();
      _pageUrl = null;
      _error = null;
      _status = 'تم مسح سجل السحب السابق. أدخل رابط الصفحة الصحيحة وابدأ السحب من جديد.';
    });
  }

  @override
  void dispose() {
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
        throw Exception(result['error']?.toString() ?? 'تعذر تنفيذ الطلب.');
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
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ فحص الصفحة واستخراج الصور المتاحة...';
      _selected.clear();
      _images = [];
    });
    try {
      final scope = _sourceScope(parsed.toString());
      if (_importedScope != scope) await _loadImportedForScope(scope);
      final result = await _invoke({'action': 'scan', 'url': parsed.toString()});
      final rawImages = (result['images'] as List? ?? const []);
      final candidates = rawImages.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
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
          continue;
        }
        images.add(image);
      }
      if (!mounted) return;
      setState(() {
        _pageUrl = result['page']?.toString() ?? parsed.toString();
        _images = images;
        // Select every newly collected image by default so the collector is
        // ready to save the complete result without requiring a manual step.
        _selected
          ..clear()
          ..addAll(images.map((image) => image['url'].toString()));
        _status = images.isEmpty
            ? (candidates.isEmpty
                ? 'لم يتم العثور على صور ظاهرة في HTML. قد تعتمد الصفحة على JavaScript أو تمنع الوصول.'
                : 'لا توجد صور جديدة: تم إخفاء $previouslyImportedCount صورة محفوظة سابقًا و$duplicateCount تكرارًا من الصفحة.')
            : 'ظهرت ${images.length} صورة جديدة فقط؛ تم إخفاء $previouslyImportedCount صورة سبق حفظها و$duplicateCount تكرارًا داخل الصفحة.';
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
      if (_selected.length == _images.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_images.map((x) => x['url'].toString()));
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
          image['category_name'], image['group_name'], image['category'],
          image['group'], image['subcategory_name'], image['context_name'],
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


  String _extensionForMime(String? rawMime, String url) {
    final mime = (rawMime ?? '').split(';').first.trim().toLowerCase();
    switch (mime) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      case 'image/avif':
        return '.avif';
      case 'image/bmp':
        return '.bmp';
      case 'image/tiff':
        return '.tiff';
    }
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final extension in <String>['.jpeg', '.jpg', '.png', '.webp', '.gif', '.avif', '.bmp', '.tiff']) {
      if (path.endsWith(extension)) return extension;
    }
    return '.png';
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


  /// Remove near-white edge-connected background and export a compressed transparent PNG.
  Uint8List _processTransparentPng(Uint8List source) {
    final sourceImage = img.decodeImage(source);
    if (sourceImage == null) throw Exception('تعذر فك ترميز الصورة الأصلية.');
    final decoded = img.Image.from(sourceImage, numChannels: 4);
    final width = decoded.width, height = decoded.height;
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
      final i = y * width + x;
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
      final i = queue[head], x = i % width, y = i ~/ width;
      decoded.setPixelRgba(x, y, 0, 0, 0, 0);
      enqueue(x - 1, y); enqueue(x + 1, y);
      enqueue(x, y - 1); enqueue(x, y + 1);
    }
    final longest = width > height ? width : height;
    final scale = 4096 / longest;
    final targetWidth = (width * scale).round().clamp(1, 4096);
    final targetHeight = (height * scale).round().clamp(1, 4096);
    final resized = img.copyResize(decoded, width: targetWidth, height: targetHeight,
      interpolation: img.Interpolation.cubic);
    return Uint8List.fromList(img.encodePng(resized, level: 9));
  }

  Uint8List _buildProductDataExcel(List<Map<String, dynamic>> selectedImages) {
      final excel = Excel.createExcel();
      final sheet = excel['بيانات الأصناف'];
      sheet.appendRow([
        TextCellValue('م'),
        TextCellValue('نوع الصورة'),
        TextCellValue('اسم الصنف / الصورة'),
        TextCellValue('الباركود'),
        TextCellValue('الوحدة الرئيسية'),
        TextCellValue('الوحدة الفرعية'),
        TextCellValue('العدد الداخلي'),
        TextCellValue('الوحدات الأخرى'),
        TextCellValue('سعر البيع'),
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
            ? _excelValue(item, ['category_name', 'group_name', 'category', 'title', 'alt', 'name'])
            : kind == 'brand'
                ? _excelValue(item, ['brand_name', 'brand', 'manufacturer', 'title', 'alt', 'name'])
                : _excelValue(item, [
                    'product_full_name', 'product_name', 'name', 'title', 'alt', 'file_name',
                  ]);
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(kind == 'category' ? 'فئة / مجموعة' : kind == 'brand' ? 'ماركة / براند' : 'صنف / منتج'),
          TextCellValue(name),
          TextCellValue(_excelValue(item, ['barcode', 'gtin', 'ean', 'upc'])),
          TextCellValue(_excelValue(item, ['main_unit', 'unit', 'unit_name', 'major_unit'])),
          TextCellValue(_excelValue(item, ['sub_unit', 'minor_unit', 'small_unit'])),
          TextCellValue(_excelValue(item, ['internal_count', 'units_per_pack', 'pack_size', 'quantity_per_unit'])),
          TextCellValue(_excelValue(item, ['other_units', 'units'])),
          TextCellValue(_excelValue(item, ['sale_price', 'price', 'price_value'])),
          TextCellValue(_excelValue(item, ['main_category', 'category_name', 'category'])),
          TextCellValue(_excelValue(item, ['sub_category', 'subcategory', 'group_name'])),
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

  Future<void> _openProductEditor(Map<String, dynamic> image) async {
    final client = Supabase.instance.client;
    final companyId = await _activeCompanyId();
    final groupsRaw = await client.from('erp_item_groups')
        .select('id, parent_id, group_code, group_name, is_active')
        .eq('company_id', companyId).eq('is_active', true).order('group_code').limit(2000);
    final groups = (groupsRaw as List).map((e) => Map<String, dynamic>.from(e)).toList();
    final code = TextEditingController();
    final name = TextEditingController(text: _suggestedImageName(image, _images.indexOf(image)));
    final barcode = TextEditingController(text: _excelValue(image, ['barcode', 'gtin', 'ean', 'upc']));
    final brand = TextEditingController(text: _excelValue(image, ['brand', 'brand_name', 'manufacturer']));
    final majorUnit = TextEditingController(text: _excelValue(image, ['major_unit', 'main_unit', 'unit']).isEmpty ? 'كرتونة' : _excelValue(image, ['major_unit', 'main_unit', 'unit']));
    final minorUnit = TextEditingController(text: _excelValue(image, ['minor_unit', 'sub_unit', 'small_unit']).isEmpty ? 'قطعة' : _excelValue(image, ['minor_unit', 'sub_unit', 'small_unit']));
    final innerCount = TextEditingController(text: _excelValue(image, ['internal_count', 'units_per_pack', 'pack_size']));
    final salePrice = TextEditingController(text: _excelValue(image, ['sale_price', 'price', 'price_value']).isEmpty ? '0' : _excelValue(image, ['sale_price', 'price', 'price_value']));
    final mainCategory = TextEditingController(text: _excelValue(image, ['main_category', 'category_name', 'category']));
    final subCategory = TextEditingController(text: _excelValue(image, ['sub_category', 'subcategory', 'group_name']));
    final thirdCategory = TextEditingController(text: _excelValue(image, ['secondary_category', 'third_category']));
    String? mainId, subId, thirdId, matchedId;
    bool busy = false;
    String? dialogError;
    List<Map<String, dynamic>> children(String? parent) =>
        groups.where((g) => (g['parent_id']?.toString()) == parent).toList();
    Map<String, dynamic>? groupById(String? id) {
      for (final g in groups) { if (g['id'].toString() == id) return g; }
      return null;
    }
    Future<void> lookup(StateSetter setDialog) async {
      if (code.text.trim().isEmpty) { setDialog(() => dialogError = 'اكتب كود الصنف للبحث.'); return; }
      setDialog(() { busy = true; dialogError = null; });
      try {
        final row = await client.from('erp_items').select('id, item_code, item_name, barcode, base_unit, group_id, brand_name, package_description, sale_price')
          .eq('company_id', companyId).eq('item_code', code.text.trim()).maybeSingle();
        if (row == null) {
          setDialog(() { matchedId = null; busy = false; dialogError = 'الكود غير مسجل؛ يمكنك استخدام «صنف جديد بالبيانات الحالية» لإنشاء الصنف.'; });
          return;
        }
        matchedId = row['id'].toString();
        final group = groupById(row['group_id']?.toString());
        final parent = groupById(group?['parent_id']?.toString());
        final grand = groupById(parent?['parent_id']?.toString());
        setDialog(() {
          name.text = (row['item_name'] ?? '').toString();
          barcode.text = (row['barcode'] ?? '').toString();
          brand.text = (row['brand_name'] ?? '').toString();
          minorUnit.text = (row['base_unit'] ?? 'قطعة').toString();
          salePrice.text = (row['sale_price'] ?? 0).toString();
          thirdId = group?['id']?.toString();
          subId = parent?['id']?.toString();
          mainId = grand?['id']?.toString() ?? parent?['id']?.toString() ?? group?['id']?.toString();
          subCategory.text = parent?['group_name']?.toString() ?? '';
          thirdCategory.text = group?['group_name']?.toString() ?? '';
          busy = false;
          dialogError = 'تم العثور على الصنف؛ الحفظ سيحدّث بياناته وصورته.';
        });
      } catch (e) {
        setDialog(() { busy = false; dialogError = 'تعذر البحث عن الصنف: ' + e.toString(); });
      }
    }

    Future<void> save(StateSetter setDialog, {required bool createNew}) async {
      if (name.text.trim().isEmpty) { setDialog(() => dialogError = 'اسم الصنف مطلوب.'); return; }
      final count = double.tryParse(innerCount.text.trim());
      final price = double.tryParse(salePrice.text.trim()) ?? 0;
      if (count == null || count <= 0) { setDialog(() => dialogError = 'العدد الداخلي يجب أن يكون أكبر من صفر.'); return; }
      if (createNew && code.text.trim().isNotEmpty) {
        setDialog(() => dialogError = 'اترك الكود فارغًا لإنشاء كود تلقائي، أو امسحه ثم أعد المحاولة.');
        return;
      }
      setDialog(() { busy = true; dialogError = null; });
      try {
        final selectedGroup = thirdId ?? subId ?? mainId;
        final group = groupById(selectedGroup);
        final prefixRaw = (group?['group_code'] ?? 'ITEM').toString().trim().toUpperCase();
        final prefix = prefixRaw.replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
        String itemCode = code.text.trim();
        if (createNew) {
          final prior = await client.from('erp_items').select('item_code')
              .eq('company_id', companyId).like('item_code', prefix + '-%').limit(2000);
          var max = 0;
          for (final row in (prior as List)) {
            final match = RegExp(r'-(\d+)
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
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ تنزيل الصورة...';
    });
    try {
      final url = image['url'].toString();
      final result = await _invoke({'action': 'download', 'url': url});
      final encoded = result['base64']?.toString();
      if (encoded == null || encoded.isEmpty) throw Exception('لم تصل بيانات الصورة.');
      final sourceBytes = Uint8List.fromList(base64Decode(encoded));
      final bytes = _processTransparentPng(sourceBytes);
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
      await _markImported({_imageKey(url)});
      if (mounted) {
        setState(() {
          _url.clear();
          // Remove the saved image and any unchecked images; retain only other
          // selected images that have not yet been saved.
          _images = _images.where((item) {
            final itemUrl = item['url']?.toString() ?? '';
            return itemUrl != url && _selected.contains(itemUrl);
          }).toList();
          _selected
            ..clear()
            ..addAll(_images.map((item) => item['url'].toString()));
          if (_images.isEmpty) _pageUrl = null;
          _status = 'تم حفظ الصورة. تم مسح الرابط والصور المحفوظة وغير المحددة من الشاشة؛ الصق الرابط التالي أو احفظ الصور المحددة المتبقية.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _images.isNotEmpty && _selected.length == _images.length;
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
                ]),
                const SizedBox(height: 18),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _pasteClipboardUrl,
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      label: const Text('لصق الرابط'),
                      style: OutlinedButton.styleFrom(foregroundColor: _purple, visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () {
                        setState(() { _url.clear(); _error = null; _status = 'تم مسح الرابط.'; });
                      },
                      icon: const Icon(Icons.backspace_outlined, size: 17),
                      label: const Text('مسح الرابط'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                    ),
                    const Spacer(),
                    const Directionality(textDirection: TextDirection.rtl,
                      child: Text('رابط صفحة المنتجات', style: TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _loading ? null : _scan(),
                  decoration: InputDecoration(
                    hintText: 'https://www.example.com/products',
                    prefixIcon: const Icon(Icons.link),
                    filled: true,
                    fillColor: const Color(0xFFF8F5FB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _scan,
                    icon: _loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.travel_explore),
                    label: const Text('تنفيذ وسحب الصور'),
                    style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _images.isEmpty ? null : _selectAll,
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل (${_images.length})'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading || _selected.isEmpty ? null : _saveZip,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: Text('حفظ المحدد png / Excel في ملف Zip (${_selected.length})'),
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
                  Text('المصدر: $_pageUrl', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
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
            const Expanded(child: Text('الصور المستخرجة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            Text('${_images.length} صورة • محدد ${_selected.length}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          const SizedBox(height: 10),
          if (_images.isEmpty)
            SizedBox(
              height: 220,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.image_search_outlined, size: 54, color: _purple.withValues(alpha: .35)),
                const SizedBox(height: 10),
                const Text('ضع رابط صفحة ثم اضغط «تنفيذ وسحب الصور»', style: TextStyle(color: Colors.black54)),
              ])),
            )
          else
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 205,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .76,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final item = _images[index];
                  final imageUrl = item['url'].toString();
                  final selected = _selected.contains(imageUrl);
                  final alt = (item['alt'] ?? '').toString();
                  return InkWell(
                    onTap: () => _toggle(imageUrl, !selected),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: selected ? _purple : const Color(0xFFE7E0EE), width: selected ? 2 : 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(
                          child: Stack(fit: StackFit.expand, children: [
                            Container(color: const Color(0xFFF7F4F9), alignment: Alignment.center,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 42, color: Colors.black26),
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                            Positioned(
                              top: 6, right: 6,
                              child: Container(
                                decoration: BoxDecoration(color: selected ? _purple : Colors.white.withValues(alpha: .95), shape: BoxShape.circle),
                                child: Checkbox(
                                  value: selected,
                                  onChanged: (v) => _toggle(imageUrl, v),
                                  activeColor: _purple,
                                  side: BorderSide(color: selected ? _purple : Colors.black38),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(alt.isEmpty ? 'صورة ${index + 1}' : alt, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: (item['save_as'] ?? 'product').toString(),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'نوع الصورة',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'product', child: Text('صنف / منتج')),
                                DropdownMenuItem(value: 'category', child: Text('فئة / مجموعة')),
                                DropdownMenuItem(value: 'brand', child: Text('ماركة / براند')),
                              ],
                              onChanged: _loading ? null : (value) {
                                if (value == null) return;
                                setState(() {
                                  item['save_as'] = value;
                                  item.remove('file_name');
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            TextFormField(
                              key: ValueKey('filename_${index}_${item['save_as'] ?? 'product'}'),
                              initialValue: _suggestedImageName(item, index),
                              decoration: const InputDecoration(
                                labelText: 'اسم الملف المحفوظ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => item['file_name'] = value,
                            ),
                            const SizedBox(height: 5),
                            OutlinedButton.icon(
                              onPressed: _loading ? null : () async {
                                try { await _openProductEditor(item); }
                                catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', '')); }
                              },
                              icon: const Icon(Icons.inventory_2_outlined, size: 16),
                              label: const Text('بيانات الصنف / حفظ بالداتا', style: TextStyle(fontSize: 10)),
                              style: OutlinedButton.styleFrom(foregroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 30)),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _loading ? null : () => _saveOne(item),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('تنزيل', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
).firstMatch((row['item_code'] ?? '').toString());
            if (match != null) { final n = int.tryParse(match.group(1)!) ?? 0; if (n > max) max = n; }
          }
          itemCode = prefix + '-' + (max + 1).toString().padLeft(3, '0');
        } else if (matchedId == null) {
          throw Exception('ابحث عن كود موجود أولًا، أو اختر إنشاء صنف جديد مع ترك الكود فارغًا.');
        }
        final downloaded = await _invoke({'action': 'download', 'url': image['url'].toString()});
        final raw = base64Decode(downloaded['base64'].toString());
        final png = _processTransparentPng(Uint8List.fromList(raw));
        final values = <String, dynamic>{
          'item_code': itemCode,
          'item_name': name.text.trim(),
          'barcode': barcode.text.trim().isEmpty ? null : barcode.text.trim(),
          'group_id': selectedGroup,
          'base_unit': minorUnit.text.trim().isEmpty ? 'قطعة' : minorUnit.text.trim(),
          'sale_price': price,
          'purchase_price': 0,
          'tax_rate': 0,
          'reorder_level': 0,
          'expiry_tracking': false,
          'brand_name': brand.text.trim().isEmpty ? null : brand.text.trim(),
          'package_description': majorUnit.text.trim() + ' = ' + count.toString() + ' ' + minorUnit.text.trim(),
          'image_data': _byteaHex(png),
          'image_mime_type': 'image/png',
          'image_url': null,
          'source_name': 'جامع صور سلسلة',
          'source_url': image['url'].toString(),
          'is_active': true,
        };
        String savedId;
        if (createNew) {
          final inserted = await client.from('erp_items').insert({...values, 'company_id': companyId}).select('id').single();
          savedId = inserted['id'].toString();
          await client.from('erp_item_units').insert([
            {'company_id': companyId, 'item_id': savedId, 'unit_code': 'MAJOR', 'unit_name': majorUnit.text.trim(), 'conversion_factor': count, 'is_base_unit': false, 'is_active': true, 'barcode': null},
            {'company_id': companyId, 'item_id': savedId, 'unit_code': 'MINOR', 'unit_name': minorUnit.text.trim(), 'conversion_factor': 1, 'is_base_unit': true, 'is_active': true, 'barcode': barcode.text.trim().isEmpty ? null : barcode.text.trim()},
          ]);
        } else {
          await client.from('erp_items').update(values).eq('id', matchedId!).eq('company_id', companyId);
          savedId = matchedId!;
          await client.from('erp_item_units').upsert([
            {'company_id': companyId, 'item_id': savedId, 'unit_code': 'MAJOR', 'unit_name': majorUnit.text.trim(), 'conversion_factor': count, 'is_base_unit': false, 'is_active': true},
            {'company_id': companyId, 'item_id': savedId, 'unit_code': 'MINOR', 'unit_name': minorUnit.text.trim(), 'conversion_factor': 1, 'is_base_unit': true, 'is_active': true, 'barcode': barcode.text.trim().isEmpty ? null : barcode.text.trim()},
          ], onConflict: 'item_id,unit_code');
        }
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            image['file_name'] = name.text.trim();
            image['product_name'] = name.text.trim();
            image['brand'] = brand.text.trim();
            image['main_unit'] = majorUnit.text.trim();
            image['minor_unit'] = minorUnit.text.trim();
            image['internal_count'] = innerCount.text.trim();
            image['sale_price'] = price;
            image['database_item_id'] = savedId;
            image['database_item_code'] = itemCode;
            _status = createNew ? 'تم إنشاء الصنف ' + itemCode + ' وحفظ الصورة PNG في قاعدة البيانات.' : 'تم تحديث الصنف ' + itemCode + ' وحفظ الصورة PNG في قاعدة البيانات.';
          });
        }
      } catch (e) {
        setDialog(() { busy = false; dialogError = 'تعذر حفظ بيانات الصنف: ' + e.toString(); });
      }
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialog) {
          Widget field(String label, TextEditingController controller, {double width = 240, TextInputType type = TextInputType.text, void Function(String)? submitted}) =>
            SizedBox(width: width, child: TextField(controller: controller, keyboardType: type, onSubmitted: submitted,
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)));
          Widget groupDropdown(String label, String? value, List<Map<String, dynamic>> options, ValueChanged<String?> change) =>
            SizedBox(width: 250, child: DropdownButtonFormField<String>(
              value: options.any((g) => g['id'].toString() == value) ? value : null,
              isExpanded: true, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
              items: options.map((g) => DropdownMenuItem<String>(value: g['id'].toString(), child: Text((g['group_code'] ?? '').toString() + ' — ' + (g['group_name'] ?? '').toString(), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: change));
          final roots = children(null);
          return AlertDialog(
            title: const Text('بيانات الصنف والصورة', style: TextStyle(color: _purple, fontWeight: FontWeight.w800)),
            content: SizedBox(width: 760, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(width: 230, child: TextField(controller: code, textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => lookup(setDialog),
                  decoration: InputDecoration(labelText: 'كود الصنف المسجل', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: 'بحث بالكود', onPressed: busy ? null : () => lookup(setDialog), icon: const Icon(Icons.search))))),
                field('اسم الصنف (قابل للتعديل)', name),
                field('الباركود', barcode),
                field('البراند / العلامة التجارية', brand),
                field('الوحدة الكبرى', majorUnit),
                field('الوحدة الصغرى / الأساسية', minorUnit),
                field('العدد الداخلي', innerCount, type: TextInputType.number),
                field('سعر البيع (اختياري)', salePrice, type: const TextInputType.numberWithOptions(decimal: true)),
                groupDropdown('الفئة الرئيسية', mainId, roots, (v) => setDialog(() { mainId = v; subId = null; thirdId = null; })),
                groupDropdown('الفئة الفرعية', subId, children(mainId), (v) => setDialog(() { subId = v; thirdId = null; })),
                groupDropdown('الفئة الثانوية', thirdId, children(subId), (v) => setDialog(() => thirdId = v)),
              ]),
              const SizedBox(height: 8),
              if (dialogError != null) Align(alignment: Alignment.centerRight, child: Text(dialogError!, style: TextStyle(color: dialogError!.startsWith('تم العثور') ? Colors.green : Colors.red, fontSize: 12))),
            ]))),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              OutlinedButton.icon(onPressed: busy ? null : () => save(setDialog, createNew: true), icon: const Icon(Icons.add_box_outlined), label: const Text('صنف جديد بالبيانات الحالية')),
              FilledButton.icon(onPressed: busy || matchedId == null ? null : () => save(setDialog, createNew: false), icon: const Icon(Icons.save_outlined), label: const Text('حفظ بيانات الصنف')),
            ],
          );
        }),
      );
    } finally {
      code.dispose(); name.dispose(); barcode.dispose(); brand.dispose(); majorUnit.dispose();
      minorUnit.dispose(); innerCount.dispose(); salePrice.dispose(); mainCategory.dispose(); subCategory.dispose(); thirdCategory.dispose();
    }
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
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ تنزيل الصورة...';
    });
    try {
      final url = image['url'].toString();
      final result = await _invoke({'action': 'download', 'url': url});
      final encoded = result['base64']?.toString();
      if (encoded == null || encoded.isEmpty) throw Exception('لم تصل بيانات الصورة.');
      final sourceBytes = Uint8List.fromList(base64Decode(encoded));
      final bytes = _processTransparentPng(sourceBytes);
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
      await _markImported({_imageKey(url)});
      if (mounted) {
        setState(() {
          _url.clear();
          // Remove the saved image and any unchecked images; retain only other
          // selected images that have not yet been saved.
          _images = _images.where((item) {
            final itemUrl = item['url']?.toString() ?? '';
            return itemUrl != url && _selected.contains(itemUrl);
          }).toList();
          _selected
            ..clear()
            ..addAll(_images.map((item) => item['url'].toString()));
          if (_images.isEmpty) _pageUrl = null;
          _status = 'تم حفظ الصورة. تم مسح الرابط والصور المحفوظة وغير المحددة من الشاشة؛ الصق الرابط التالي أو احفظ الصور المحددة المتبقية.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _images.isNotEmpty && _selected.length == _images.length;
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
                ]),
                const SizedBox(height: 18),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _pasteClipboardUrl,
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      label: const Text('لصق الرابط'),
                      style: OutlinedButton.styleFrom(foregroundColor: _purple, visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () {
                        setState(() { _url.clear(); _error = null; _status = 'تم مسح الرابط.'; });
                      },
                      icon: const Icon(Icons.backspace_outlined, size: 17),
                      label: const Text('مسح الرابط'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                    ),
                    const Spacer(),
                    const Directionality(textDirection: TextDirection.rtl,
                      child: Text('رابط صفحة المنتجات', style: TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _loading ? null : _scan(),
                  decoration: InputDecoration(
                    hintText: 'https://www.example.com/products',
                    prefixIcon: const Icon(Icons.link),
                    filled: true,
                    fillColor: const Color(0xFFF8F5FB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _scan,
                    icon: _loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.travel_explore),
                    label: const Text('تنفيذ وسحب الصور'),
                    style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _images.isEmpty ? null : _selectAll,
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل (${_images.length})'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading || _selected.isEmpty ? null : _saveZip,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: Text('حفظ المحدد png / Excel في ملف Zip (${_selected.length})'),
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
                  Text('المصدر: $_pageUrl', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
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
            const Expanded(child: Text('الصور المستخرجة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            Text('${_images.length} صورة • محدد ${_selected.length}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          const SizedBox(height: 10),
          if (_images.isEmpty)
            SizedBox(
              height: 220,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.image_search_outlined, size: 54, color: _purple.withValues(alpha: .35)),
                const SizedBox(height: 10),
                const Text('ضع رابط صفحة ثم اضغط «تنفيذ وسحب الصور»', style: TextStyle(color: Colors.black54)),
              ])),
            )
          else
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 205,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .76,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final item = _images[index];
                  final imageUrl = item['url'].toString();
                  final selected = _selected.contains(imageUrl);
                  final alt = (item['alt'] ?? '').toString();
                  return InkWell(
                    onTap: () => _toggle(imageUrl, !selected),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: selected ? _purple : const Color(0xFFE7E0EE), width: selected ? 2 : 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(
                          child: Stack(fit: StackFit.expand, children: [
                            Container(color: const Color(0xFFF7F4F9), alignment: Alignment.center,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 42, color: Colors.black26),
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                            Positioned(
                              top: 6, right: 6,
                              child: Container(
                                decoration: BoxDecoration(color: selected ? _purple : Colors.white.withValues(alpha: .95), shape: BoxShape.circle),
                                child: Checkbox(
                                  value: selected,
                                  onChanged: (v) => _toggle(imageUrl, v),
                                  activeColor: _purple,
                                  side: BorderSide(color: selected ? _purple : Colors.black38),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(alt.isEmpty ? 'صورة ${index + 1}' : alt, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: (item['save_as'] ?? 'product').toString(),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'نوع الصورة',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'product', child: Text('صنف / منتج')),
                                DropdownMenuItem(value: 'category', child: Text('فئة / مجموعة')),
                                DropdownMenuItem(value: 'brand', child: Text('ماركة / براند')),
                              ],
                              onChanged: _loading ? null : (value) {
                                if (value == null) return;
                                setState(() {
                                  item['save_as'] = value;
                                  item.remove('file_name');
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            TextFormField(
                              key: ValueKey('filename_${index}_${item['save_as'] ?? 'product'}'),
                              initialValue: _suggestedImageName(item, index),
                              decoration: const InputDecoration(
                                labelText: 'اسم الملف المحفوظ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => item['file_name'] = value,
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _loading ? null : () => _saveOne(item),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('تنزيل', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
