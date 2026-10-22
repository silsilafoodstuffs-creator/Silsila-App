import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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

  String _prefsKey(String scope) => 'silsila_image_collector_imported_v1_$scope';

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
    var name = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\\u0600-\\u06FF_-]+'), '_');
    name = name.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (name.length > 70) name = name.substring(0, 70);
    return name.isEmpty ? fallback : name;
  }

  String _suggestedImageName(Map<String, dynamic> image, int index) {
    final kind = (image['save_as'] ?? 'product').toString();
    final candidates = switch (kind) {
      'category' => [
          image['category_name'], image['group_name'], image['category'],
          image['group'], image['title'], image['alt'], image['name'],
        ],
      'brand' => [
          image['brand_name'], image['brand'], image['manufacturer'],
          image['title'], image['alt'], image['name'],
        ],
      _ => [
          image['product_name'], image['title'], image['name'], image['alt'],
        ],
    };
    final suggested = candidates.map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty,
            orElse: () => 'صورة_${(index + 1).toString().padLeft(3, '0')}');
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


  /// Converts an image to PNG and removes a near-uniform background connected
  /// to the image edges. This is a lightweight cut-out, not an AI segmentation model.
  Uint8List _toTransparentPng(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) throw Exception('تعذر قراءة الصورة لتحويلها إلى PNG.');
    final image = img.bakeOrientation(decoded);
    final width = image.width;
    final height = image.height;
    if (width < 2 || height < 2) {
      return Uint8List.fromList(img.encodePng(image));
    }

    final corners = [
      image.getPixel(0, 0),
      image.getPixel(width - 1, 0),
      image.getPixel(0, height - 1),
      image.getPixel(width - 1, height - 1),
    ];
    final bgR = corners.map((p) => p.r.toDouble()).reduce((a, b) => a + b) / corners.length;
    final bgG = corners.map((p) => p.g.toDouble()).reduce((a, b) => a + b) / corners.length;
    final bgB = corners.map((p) => p.b.toDouble()).reduce((a, b) => a + b) / corners.length;
    const thresholdSquared = 65 * 65;
    final pixelCount = width * height;
    final visited = Uint8List(pixelCount);
    final queue = Int32List(pixelCount);
    var head = 0;
    var tail = 0;

    bool resemblesBackground(int x, int y) {
      final p = image.getPixel(x, y);
      final dr = p.r.toDouble() - bgR;
      final dg = p.g.toDouble() - bgG;
      final db = p.b.toDouble() - bgB;
      return dr * dr + dg * dg + db * db <= thresholdSquared;
    }

    void enqueue(int x, int y) {
      final index = y * width + x;
      if (visited[index] != 0 || !resemblesBackground(x, y)) return;
      visited[index] = 1;
      queue[tail++] = index;
    }

    for (var x = 0; x < width; x++) {
      enqueue(x, 0);
      enqueue(x, height - 1);
    }
    for (var y = 1; y < height - 1; y++) {
      enqueue(0, y);
      enqueue(width - 1, y);
    }

    while (head < tail) {
      final index = queue[head++];
      final x = index % width;
      final y = index ~/ width;
      final p = image.getPixel(x, y);
      image.setPixelRgba(x, y, p.r, p.g, p.b, 0);
      if (x > 0) enqueue(x - 1, y);
      if (x + 1 < width) enqueue(x + 1, y);
      if (y > 0) enqueue(x, y - 1);
      if (y + 1 < height) enqueue(x, y + 1);
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<void> _exportProductDataExcel() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'حدد صور الأصناف التي تريد تجهيز بياناتها في Excel أولًا.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ تجهيز ملف Excel لبيانات الأصناف المحددة...';
    });
    try {
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final timestamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}_${now.millisecond.toString().padLeft(3, '0')}';
      final excel = Excel.createExcel();
      final sheet = excel['بيانات الأصناف'];
      final headers = <String>[
        'م', 'الباركود إن وجد', 'اسم الصنف', 'وحدة القياس الكبرى',
        'الوحدة الصغرى', 'العدد الداخلي', 'وحدات أخرى', 'سعر البيع',
        'الفئة الرئيسية / المجموعة الرئيسية',
        'الفئة الفرعية / المجموعة الفرعية',
        'الفئة الثانوية / البراند', 'الوزن إن وجد',
        'تاريخ ووقت تجهيز الملف', 'رابط الصورة المصدر',
      ];
      sheet.appendRow(headers.map((value) => TextCellValue(value)).toList());
      final selectedImages = _images.where((item) => _selected.contains(item['url'].toString())).toList();
      for (var i = 0; i < selectedImages.length; i++) {
        final item = selectedImages[i];
        final productName = (item['product_name'] ?? item['title'] ?? item['name'] ?? item['alt'] ?? '').toString().trim();
        sheet.appendRow(<CellValue?>[
          IntCellValue(i + 1),
          TextCellValue((item['barcode'] ?? '').toString()),
          TextCellValue(productName),
          TextCellValue((item['major_unit'] ?? item['large_unit'] ?? '').toString()),
          TextCellValue((item['minor_unit'] ?? item['small_unit'] ?? '').toString()),
          TextCellValue((item['internal_count'] ?? '').toString()),
          TextCellValue((item['other_units'] ?? '').toString()),
          TextCellValue((item['sale_price'] ?? item['price'] ?? '').toString()),
          TextCellValue((item['main_category'] ?? item['main_group'] ?? item['category'] ?? '').toString()),
          TextCellValue((item['subcategory'] ?? item['sub_category'] ?? item['sub_group'] ?? '').toString()),
          TextCellValue((item['secondary_category'] ?? item['brand'] ?? '').toString()),
          TextCellValue((item['weight'] ?? '').toString()),
          TextCellValue('${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}'),
          TextCellValue(item['url'].toString()),
        ]);
      }
      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) throw Exception('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'silsila_product_data_$timestamp',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
      );
      if (mounted) {
        setState(() => _status = 'تم تجهيز ملف Excel مستقل يضم ${selectedImages.length} صنف. اسم الملف يتضمن تاريخ ووقت الحفظ، ولن يستبدل الملفات السابقة.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
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
      _status = 'جارٍ تنزيل الصور المحددة وتجهيز ملف ZIP...';
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
        final bytes = _toTransparentPng(Uint8List.fromList(base64Decode(encoded)));
        final title = _imageBaseName(image, imageIndex < 0 ? index - 1 : imageIndex);
        final fileName = _uniqueFileName(title, '.png', usedFileNames);
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        savedImageKeys.add(_imageKey(url));
        if (mounted) setState(() => _status = 'تم تجهيز $index من ${_selected.length} صورة...');
      }
      if (archive.isEmpty) throw Exception('لم يمكن تنزيل أي صورة من الاختيارات.');
      final zipped = ZipEncoder().encode(archive);
      if (zipped == null || zipped.isEmpty) throw Exception('تعذر إنشاء ملف ZIP.');
      await FileSaver.instance.saveFile(
        name: 'silsila_images_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(zipped),
        fileExtension: 'zip',
        mimeType: MimeType.zip,
      );
      await _markImported(savedImageKeys);
      if (mounted) setState(() => _status = 'تم حفظ ${archive.files.length} صورة. ستُخفى هذه الصور تلقائيًا عند فحص الموقع نفسه مرة أخرى.');
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
      final bytes = _toTransparentPng(Uint8List.fromList(base64Decode(encoded)));
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
        mimeType: MimeType.png,
      );
      await _markImported({_imageKey(url)});
      if (mounted) setState(() => _status = 'تم حفظ الصورة؛ ستُخفى تلقائيًا عند فحص الموقع نفسه مرة أخرى.');
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
                    Text('استخراج الصور، إزالة الخلفية الموحدة، وحفظها PNG منفردة أو كلها في ZIP', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                ]),
                const SizedBox(height: 18),
                const Text('رابط صفحة المنتجات', style: TextStyle(fontWeight: FontWeight.w700)),
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
                Wrap(spacing: 10, runSpacing: 10, children: [
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
                    label: Text('حفظ المحدد PNG داخل ZIP (${_selected.length})'),
                    style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _selected.isEmpty ? null : _exportProductDataExcel,
                    icon: const Icon(Icons.table_view_outlined),
                    label: Text('تصدير بيانات الأصناف إلى Excel (${_selected.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: const BorderSide(color: _purple),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ]),
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
                  'ملاحظة: بعض المواقع تعرض الصور بواسطة JavaScript أو تمنع الطلبات الآلية؛ في هذه الحالة قد لا تظهر كل الصور. إزالة الخلفية تعمل أفضل مع الخلفيات الموحدة (مثل الأبيض)، وقد تحتاج الصور ذات الخلفيات المعقدة إلى معالجة إضافية. استخدم الصور وفق حقوق الموقع.',
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
