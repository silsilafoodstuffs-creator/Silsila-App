import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

Widget _kindCell(_ImportRow row, VoidCallback refresh) => SizedBox(
  width: 108,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _compactChoice(
        label: 'صنف',
        selected: row.kind == 'صنف',
        onTap: () {
          row.kind = 'صنف';
          if (row.codeMode == 'جديد') {
            row.code = 'ITM${row.id.replaceAll(RegExp(r'\\D'), '').padLeft(5, '0')}';
          }
          refresh();
        },
      ),
      const SizedBox(width: 2),
      _compactChoice(
        label: 'فئة',
        selected: row.kind == 'فئة',
        onTap: () {
          row.kind = 'فئة';
          if (row.codeMode == 'جديد') {
            row.code = 'CAT${row.id.replaceAll(RegExp(r'\\D'), '').padLeft(5, '0')}';
          }
          refresh();
        },
      ),
    ],
  ),
);

Widget _compactChoice({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) => InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(16),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 23,
        height: 30,
        child: Transform.scale(
          scale: 0.76,
          child: Checkbox(
            shape: const CircleBorder(),
            value: selected,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) { if (value == true) onTap(); },
          ),
        ),
      ),
      Text(label, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12)),
    ],
  ),
);

Future<Map<String, String>?> _pickExistingRecord(BuildContext context, String kind) async {
  final db = Supabase.instance.client;
  final query = TextEditingController();
  List<Map<String, dynamic>> records = [];
  var loading = true;
  String? error;
  Future<void> load(StateSetter setDialog) async {
    setDialog(() { loading = true; error = null; });
    try {
      final table = kind == 'فئة' ? 'erp_item_categories' : 'erp_items';
      final response = await db.from(table).select('*').limit(500);
      records = (response as List).whereType<Map<String, dynamic>>().toList();
      if (records.isEmpty) error = 'لا توجد بيانات في قائمة $kind.';
    } catch (e) { error = 'تعذر تحميل قائمة $kind: $e'; }
    setDialog(() => loading = false);
  }
  String valueOf(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }
  return showDialog<Map<String, String>>(context: context, builder: (dialogContext) => StatefulBuilder(
    builder: (dialogContext, setDialog) {
      if (loading && records.isEmpty && error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (dialogContext.mounted) load(setDialog); });
      }
      final filtered = records.where((record) {
        final searchable = '${valueOf(record, ['name_ar','name','title','item_name','category_name'])} ${valueOf(record, ['item_code','code','category_code','id'])}';
        return searchable.toLowerCase().contains(query.text.trim().toLowerCase());
      }).toList();
      return AlertDialog(
        title: Text('بحث F1 في قائمة $kind'),
        content: SizedBox(width: 520, height: 420, child: Column(children: [
          TextField(controller: query, decoration: const InputDecoration(labelText: 'ابحث بالاسم أو الكود', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (_) => setDialog(() {})),
          const SizedBox(height: 8),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
            final record = filtered[i];
            final name = valueOf(record, ['name_ar','name','title','item_name','category_name']);
            final code = valueOf(record, ['item_code','code','category_code','id']);
            return ListTile(title: Text(name.isEmpty ? 'بدون اسم' : name), subtitle: Text(code), onTap: () => Navigator.pop(dialogContext, {'name': name, 'code': code}));
          })),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), TextButton(onPressed: () => load(setDialog), child: const Text('تحديث القائمة'))],
      );
    },
  ));
}

Widget _codeModeCell(_ImportRow row, VoidCallback refresh) => SizedBox(
  width: 108,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _compactChoice(
        label: 'جديد',
        selected: row.codeMode == 'جديد',
        onTap: () {
          row.codeMode = 'جديد';
          if (row.code.isEmpty) {
            row.code = '${row.kind == 'فئة' ? 'CAT' : 'ITM'}${row.id.replaceAll(RegExp(r'\\D'), '').padLeft(5, '0')}';
          }
          refresh();
        },
      ),
      const SizedBox(width: 2),
      _compactChoice(
        label: 'قديم',
        selected: row.codeMode == 'قديم',
        onTap: () { row.codeMode = 'قديم'; refresh(); },
      ),
    ],
  ),
);

class _ImportRow {
  _ImportRow({required this.id, required this.imageUrl, this.bytes, this.name = '', this.kind = 'صنف', this.codeMode = 'جديد', this.code = '', this.category = '', this.subcategory = '', this.thirdCategory = '', this.majorUnit = '', this.innerCount = '', this.minorUnit = '', this.otherUnits = '', this.weight = '', this.length = '', this.width = '', this.height = '', this.brand = '', this.barcode = '', this.salePrice = '', this.description = '', this.sourcePage = '', this.selected = true});
  final String id;
  String imageUrl, name, kind, codeMode, code, category, subcategory, thirdCategory, majorUnit, innerCount, minorUnit, otherUnits, weight, length, width, height, brand, barcode, salePrice, description, sourcePage;
  Uint8List? bytes;
  bool selected;
  Map<String,String> toMap() => {'id':id,'image_file':'images/$id.jpg','image_url':imageUrl,'name_ar':name,'record_type':kind,'code_mode':codeMode,'item_code':code,'category':category,'subcategory':subcategory,'third_category':thirdCategory,'major_unit':majorUnit,'inner_count':innerCount,'minor_unit':minorUnit,'other_units':otherUnits,'weight':weight,'length':length,'width':width,'height':height,'brand':brand,'barcode':barcode,'sale_price':salePrice,'description':description,'source_page':sourcePage};
}

class ErpItemDataImportScreen extends StatefulWidget {
  const ErpItemDataImportScreen({super.key});
  @override State<ErpItemDataImportScreen> createState() => _ErpItemDataImportScreenState();
}
class _ErpItemDataImportScreenState extends State<ErpItemDataImportScreen> {
  final _url = TextEditingController();
  final List<_ImportRow> _rows = [];
  bool _busy = false, _selectAll = true, _crawling = false, _cancelCrawl = false;
  String _status = 'أدخل رابط الموقع لفرز جميع الصفحات والمنتجات والفئات.';
  static const _headers = ['id','image_file','image_url','name_ar','record_type','code_mode','item_code','category','subcategory','third_category','brand','barcode','sale_price','major_unit','inner_count','minor_unit','other_units','weight','length','width','height','description','source_page'];
  static const _headerLabels = ['المعرف','الصورة','رابط الصورة','اسم الصنف / الفئة','نوع السجل','نوع الكود','كود الصنف / الفئة','الفئة الرئيسية','الفئة الفرعية','الفئة الثانوية','البراند / الماركة','الباركود','السعر','الوحدة الكبرى','العدد الداخلي','الوحدة الصغرى','وحدات أخرى','الوزن','الطول','العرض','الارتفاع','الوصف','صفحة المصدر'];
  @override void dispose(){_url.dispose();super.dispose();}
  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value != null && value.isNotEmpty && mounted) {
      setState(() { _url.text = value; _status = 'تم لصق الرابط. اضغط فرز الموقع بالكامل للبدء.'; });
    }
  }
  void _resetExploration() {
    setState(() { _rows.clear(); _selectAll = true; _status = 'تمت إعادة ضبط الاستكشاف. أدخل رابطًا ثم ابدأ الفحص.'; });
  }
  Future<void> _crawl() async {
    final raw = _url.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _status = 'أدخل رابطًا صحيحًا يبدأ بـ https:// أو http://');
      return;
    }
    setState(() {
      _busy = true; _crawling = true; _cancelCrawl = false; _selectAll = true;
      _status = 'بدأ فرز الموقع بالكامل؛ سيتم تتبع صفحات الفئات والمنتجات وروابط المزيد والترقيم.';
      _rows.clear();
    });
    final queue = <String>[uri.toString()];
    final queued = <String>{uri.toString()};
    final visited = <String>{};
    final seenRecords = <String>{};
    var foundProducts = 0, foundCategories = 0, foundImages = 0, pageErrors = 0;
    final siteHosts = <String>{uri.host.toLowerCase()};
    try {
      while (queue.isNotEmpty && visited.length < 4000 && !_cancelCrawl) {
        final next = queue.removeAt(0);
        if (!visited.add(next)) continue;
        try {
          final response = await Supabase.instance.client.functions.invoke(
            'silsila-image-collector',
            body: {'action': 'scan', 'url': next},
          );
          final payload = response.data;
          if (response.status >= 400 || payload is! Map || payload['error'] != null) {
            pageErrors++;
          } else {
            final actualPage = Uri.tryParse(payload['page']?.toString() ?? '');
            if (actualPage != null) siteHosts.add(actualPage.host.toLowerCase());
            final pageProducts = payload['products'];
            final pageImages = payload['images'];
            final pageCategories = payload['categories'];
            final pageLinks = payload['links'];
            final images = pageImages is List ? pageImages.whereType<Map>().toList() : <Map>[];
            final products = pageProducts is List ? pageProducts.whereType<Map>().toList() : <Map>[];
            final categories = pageCategories is List ? pageCategories.whereType<Map>().toList() : <Map>[];
            final links = pageLinks is List ? pageLinks : const [];
            foundImages += images.length;

            String textOf(dynamic value) => value?.toString().trim() ?? '';
            String normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ').trim();
            String imageFor(Map product) {
              final productImages = product['images'];
              if (productImages is List && productImages.isNotEmpty) return textOf(productImages.first);
              final productName = normalize(textOf(product['product_full_name'] ?? product['product_name']));
              for (final image in images) {
                if (normalize(textOf(image['product_name'] ?? image['context_name'])) == productName && productName.isNotEmpty) return textOf(image['url']);
              }
              return '';
            }

            final pageProductImages = <String>{};
            for (final product in products) {
              final name = textOf(product['product_full_name'] ?? product['product_name']);
              final barcode = textOf(product['barcode']);
              final brand = textOf(product['brand']);
              final imageUrl = imageFor(product);
              if (imageUrl.isNotEmpty) pageProductImages.add(imageUrl);
              final identity = barcode.isNotEmpty ? 'barcode:$barcode' : '${normalize(name)}|${normalize(brand)}';
              if (name.isEmpty || !seenRecords.add('product:$identity')) continue;
              foundProducts++;
              _rows.add(_ImportRow(
                id: 'WEB${(_rows.length + 1).toString().padLeft(6, '0')}',
                imageUrl: imageUrl, name: name, kind: 'صنف',
                code: 'ITM${(_rows.length + 1).toString().padLeft(5, '0')}',
                category: textOf(product['main_category']),
                subcategory: textOf(product['subcategory']),
                thirdCategory: textOf(product['third_category']),
                majorUnit: textOf(product['major_unit']),
                innerCount: textOf(product['internal_count']),
                minorUnit: textOf(product['minor_unit']),
                otherUnits: textOf(product['other_units']),
                weight: textOf(product['weight']),
                brand: brand, barcode: barcode,
                salePrice: textOf(product['sale_price']),
                description: textOf(product['description']),
                sourcePage: next,
              ));
            }

            // Fallback for image cards not represented in structured Product data.
            for (final image in images) {
              final name = textOf(image['product_full_name'] ?? image['product_name'] ?? image['context_name'] ?? image['alt']);
              final imageUrl = textOf(image['url']);
              if (imageUrl.isEmpty || name.isEmpty || pageProductImages.contains(imageUrl)) continue;
              final key = 'image:${normalize(name)}|$imageUrl';
              if (!seenRecords.add(key)) continue;
              foundProducts++;
              _rows.add(_ImportRow(
                id: 'WEB${(_rows.length + 1).toString().padLeft(6, '0')}',
                imageUrl: imageUrl, name: name,
                kind: textOf(image['record_type']) == 'فئة' ? 'فئة' : 'صنف',
                code: 'ITM${(_rows.length + 1).toString().padLeft(5, '0')}',
                category: textOf(image['main_category']),
                subcategory: textOf(image['subcategory']),
                thirdCategory: textOf(image['third_category']),
                majorUnit: textOf(image['major_unit']),
                innerCount: textOf(image['internal_count']),
                minorUnit: textOf(image['minor_unit']),
                otherUnits: textOf(image['other_units']),
                weight: textOf(image['weight']),
                brand: textOf(image['brand']),
                barcode: textOf(image['barcode']),
                salePrice: textOf(image['sale_price']),
                description: textOf(image['description']),
                sourcePage: next,
              ));
            }

            for (final category in categories) {
              final name = textOf(category['name']);
              final categoryUrl = textOf(category['url']);
              if (name.isEmpty || categoryUrl.isEmpty || !seenRecords.add('category:$categoryUrl')) continue;
              foundCategories++;
              var categoryImage = '';
              for (final image in images) {
                final imageName = textOf(image['product_name'] ?? image['context_name'] ?? image['alt']).toLowerCase();
                if (imageName.contains(name.toLowerCase()) || name.toLowerCase().contains(imageName)) {
                  categoryImage = textOf(image['url']);
                  if (categoryImage.isNotEmpty) break;
                }
              }
              _rows.add(_ImportRow(
                id: 'CAT${(_rows.length + 1).toString().padLeft(6, '0')}',
                imageUrl: categoryImage, name: name, kind: 'فئة',
                code: 'CAT${(_rows.length + 1).toString().padLeft(5, '0')}',
                sourcePage: categoryUrl,
              ));
            }

            for (final value in links) {
              final link = textOf(value);
              final parsed = Uri.tryParse(link);
              if (parsed == null || !parsed.hasScheme || !['http', 'https'].contains(parsed.scheme) || !siteHosts.contains(parsed.host.toLowerCase())) continue;
              if (queued.add(link) && !visited.contains(link) && queue.length + visited.length < 4000) queue.add(link);
            }
          }
        } catch (_) {
          pageErrors++;
        }
        if (mounted) setState(() {
          _status = 'فرز شامل جارٍ: صفحات مفحوصة ${visited.length} / 4000، أصناف مرشحة $foundProducts، إجمالي السجلات ${_rows.length}، فئات $foundCategories، صور مرشحة $foundImages، أخطاء $pageErrors، متبقي ${queue.length}.';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      if (mounted) setState(() {
        _selectAll = true;
        final summary = _cancelCrawl ? 'تم إيقاف الفحص بناءً على الطلب' : (visited.length >= 4000 ? 'وصل الفحص إلى حد 4000 صفحة في هذه الجولة' : 'اكتمل المرور على الروابط الداخلية التي أمكن اكتشافها');
        _status = '$summary. صفحات مفحوصة ${visited.length}، سجلات ${_rows.length}، فئات $foundCategories، أخطاء $pageErrors. راجع البيانات ثم اضغط «حفظ اكسيل».';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'توقف الفرز: $e');
    } finally {
      if (mounted) setState(() { _busy = false; _crawling = false; });
    }
  }
  String _safeImageBaseName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    final base = cleaned.isEmpty ? 'صنف_بدون_اسم' : cleaned;
    return base.length > 100 ? base.substring(0, 100).trim() : base;
  }

  String _imageExtension(Uint8List bytes) {
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'jpg';
    if (bytes.length >= 6 && String.fromCharCodes(bytes.take(6)) == 'GIF89a') return 'gif';
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d) return 'bmp';
    if (bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return 'webp';
    return 'jpg';
  }

  Future<Uint8List?> _downloadImageBytes(_ImportRow row) async {
    if (row.bytes != null && row.bytes!.isNotEmpty) return row.bytes;
    if (row.imageUrl.trim().isEmpty) return null;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'silsila-image-collector',
        body: {'action': 'download', 'url': row.imageUrl, 'referer': row.sourcePage},
      );
      final payload = response.data;
      if (response.status >= 400 || payload is! Map || payload['base64'] is! String) return null;
      final bytes = Uint8List.fromList(base64Decode(payload['base64'] as String));
      if (bytes.isEmpty) return null;
      row.bytes = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Map<_ImportRow, String> _imageArchiveNames(List<_ImportRow> selected) {
    final usedNames = <String>{};
    final names = <_ImportRow, String>{};
    for (final row in selected) {
      final bytes = row.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final ext = _imageExtension(bytes);
      final base = _safeImageBaseName(row.name);
      var filename = '$base.$ext';
      var suffix = 2;
      while (!usedNames.add(filename.toLowerCase())) {
        filename = base + '_' + suffix.toString() + '.' + ext;
        suffix++;
      }
      names[row] = 'images/$filename';
    }
    return names;
  }

  Uint8List _embedImagesInWorkbook(Uint8List workbookBytes, List<_ImportRow> selected, Map<_ImportRow, String> imagePaths) {
    final archive = ZipDecoder().decodeBytes(workbookBytes);
    ArchiveFile? findFile(String name) {
      for (final file in archive.files) {
        if (file.isFile && file.name == name) return file;
      }
      return null;
    }
    String readText(String name) {
      final file = findFile(name);
      if (file == null) throw Exception('ملف Excel الداخلي غير موجود: $name');
      return utf8.decode(file.content as List<int>);
    }
    void replaceText(String name, String value) {
      final bytes = utf8.encode(value);
      archive.files.removeWhere((file) => file.name == name);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final workbookXml = readText('xl/workbook.xml');
    final sheetTag = RegExp(r'<sheet\b[^>]*\bname="بيانات الأصناف"[^>]*/?>').firstMatch(workbookXml);
    if (sheetTag == null) throw Exception('تعذر تحديد ورقة بيانات الأصناف داخل Excel.');
    final sheetRid = RegExp(r'\br:id="([^"]+)"').firstMatch(sheetTag.group(0)!)?.group(1);
    if (sheetRid == null) throw Exception('تعذر تحديد علاقة ورقة Excel.');
    final workbookRels = readText('xl/_rels/workbook.xml.rels');
    final sheetRelTag = RegExp('<Relationship\\b(?=[^>]*\\bId="$sheetRid")[^>]*/>').firstMatch(workbookRels);
    if (sheetRelTag == null) throw Exception('تعذر تحديد ملف ورقة Excel.');
    final target = RegExp(r'\bTarget="([^"]+)"').firstMatch(sheetRelTag.group(0)!)?.group(1);
    if (target == null) throw Exception('مسار ورقة Excel غير معروف.');
    final sheetPath = target.startsWith('/') ? target.substring(1) : (target.startsWith('xl/') ? target : 'xl/$target');
    var sheetXml = readText(sheetPath);
    final worksheetRelsPath = sheetPath.substring(0, sheetPath.lastIndexOf('/') + 1) +
        '_rels/' + sheetPath.substring(sheetPath.lastIndexOf('/') + 1) + '.rels';
    var worksheetRels = findFile(worksheetRelsPath) == null
        ? '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>'
        : readText(worksheetRelsPath);
    final relationIds = RegExp(r'\bId="rId(\d+)"').allMatches(worksheetRels)
        .map((m) => int.tryParse(m.group(1)!) ?? 0).toList();
    final maxRid = relationIds.isEmpty ? 0 : relationIds.reduce((a, b) => a > b ? a : b);
    final drawingRid = 'rId${maxRid + 1}';
    const drawingPath = 'xl/drawings/drawing1.xml';
    const drawingRelsPath = 'xl/drawings/_rels/drawing1.xml.rels';
    final anchors = <String>[];
    final drawingRelationships = <String>[];
    var imageIndex = 0;
    final usedExtensions = <String>{};
    for (var rowIndex = 0; rowIndex < selected.length; rowIndex++) {
      final row = selected[rowIndex];
      final bytes = row.bytes;
      if (bytes == null || bytes.isEmpty || imagePaths[row] == null) continue;
      imageIndex++;
      final ext = _imageExtension(bytes);
      usedExtensions.add(ext);
      final mediaPath = 'xl/media/image${imageIndex}.$ext';
      archive.addFile(ArchiveFile(mediaPath, bytes.length, bytes));
      drawingRelationships.add('<Relationship Id="rId${imageIndex}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image${imageIndex}.$ext"/>');
      final excelRow = rowIndex + 1;
      const sizeEmu = 723900;
      anchors.add('<xdr:oneCellAnchor><xdr:from><xdr:col>1</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>$excelRow</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="$sizeEmu" cy="$sizeEmu"/><xdr:pic><xdr:nvPicPr><xdr:cNvPr id="$imageIndex" name="Product image $imageIndex"/><xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr><xdr:blipFill><a:blip r:embed="rId$imageIndex"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill><xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$sizeEmu" cy="$sizeEmu"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor>');
    }
    if (imageIndex == 0) return Uint8List.fromList(ZipEncoder().encode(archive)!);

    var contentTypes = readText('[Content_Types].xml');
    if (!RegExp(r'<Override\b[^>]*\bPartName="/xl/drawings/drawing1\.xml"').hasMatch(contentTypes)) {
      contentTypes = contentTypes.replaceFirst('</Types>', '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>');
    }
    for (final ext in usedExtensions) {
      final mime = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'bmp' => 'image/bmp',
        _ => 'image/jpeg',
      };
      if (!RegExp('<Default\\b(?=[^>]*\\bExtension="$ext")[^>]*/>').hasMatch(contentTypes)) {
        contentTypes = contentTypes.replaceFirst('</Types>', '<Default Extension="$ext" ContentType="$mime"/></Types>');
      }
    }
    replaceText('[Content_Types].xml', contentTypes);
    worksheetRels = worksheetRels.replaceFirst('</Relationships>', '<Relationship Id="$drawingRid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>');
    replaceText(worksheetRelsPath, worksheetRels);
    if (!sheetXml.contains('xmlns:r=')) {
      sheetXml = sheetXml.replaceFirst('<worksheet', '<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"');
    }
    sheetXml = sheetXml.replaceFirst('</worksheet>', '<drawing r:id="$drawingRid"/></worksheet>');
    replaceText(sheetPath, sheetXml);
    const drawingXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">';
    replaceText(drawingPath, drawingXml + anchors.join() + '</xdr:wsDr>');
    replaceText(drawingRelsPath, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + drawingRelationships.join() + '</Relationships>');
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) throw Exception('تعذر تضمين الصور داخل ملف Excel.');
    return Uint8List.fromList(zipped);
  }

  Future<Uint8List> _createExcelBytes(List<_ImportRow> selected, {bool includeImages = true}) async {
    var downloaded = 0;
    for (final row in selected) {
      if (includeImages && row.imageUrl.isNotEmpty) {
        await _downloadImageBytes(row);
      }
      downloaded++;
      if (downloaded % 20 == 0 && mounted) {
        final found = selected.where((r) => r.bytes != null && r.bytes!.isNotEmpty).length;
        setState(() => _status = 'تنزيل الصور وتجهيز Excel: $downloaded / ${selected.length}، صور تم تنزيلها $found');
      }
    }
    final imagePaths = _imageArchiveNames(selected);
    final book = Excel.createExcel();
    final sheet = book['بيانات الأصناف'];
    sheet.appendRow(_headerLabels.map((h) => TextCellValue(h)).toList());
    sheet.setColumnWidth(1, 14);
    var done = 0;
    var imageCount = 0;
    for (final row in selected) {
      final data = row.toMap();
      final cells = <CellValue>[];
      for (final header in _headers) {
        if (header == 'image_file') {
          cells.add(TextCellValue(imagePaths[row] ?? ''));
        } else {
          cells.add(TextCellValue(data[header] ?? ''));
        }
      }
      sheet.appendRow(cells);
      sheet.setRowHeight(done + 1, 60);
      final imageBytes = row.bytes;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        try {
          sheet.insertImage(
            imageBytes,
            anchor: CellIndex.indexByString('B${done + 2}'),
            width: 76,
            height: 76,
          );
          imageCount++;
        } catch (_) {
          // Keep the row and its downloadable image even if a format is unsupported.
        }
      }
      done++;
      if (done % 20 == 0 && mounted) {
        setState(() => _status = 'إنشاء ملف Excel: $done / ${selected.length}، صور مضمّنة $imageCount');
      }
    }
    final bytes = book.encode();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel.');
    return _embedImagesInWorkbook(Uint8List.fromList(bytes), selected, imagePaths);
  }

  Future<void> _downloadExcel() async {
    if (_rows.isEmpty) { setState(() => _status = 'لا توجد بيانات لحفظها. ابدأ فرز الموقع أولًا.'); return; }
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) { setState(() => _status = 'حدد صفًا واحدًا على الأقل.'); return; }
    setState(() => _busy = true);
    try {
      final bytes = await _createExcelBytes(selected);
      await FileSaver.instance.saveFile(
        name: 'silsila_full_catalog_${DateTime.now().toIso8601String().substring(0, 10)}',
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      final images = selected.where((r) => r.bytes != null && r.bytes!.isNotEmpty).length;
      if (mounted) setState(() => _status = 'تم تنزيل Excel وفيه الصور الفعلية المضمّنة داخل الشيت. السجلات: ${selected.length}، صور مضمّنة: $images. الصور التي رفض مصدرها التنزيل ستظل بياناتها موجودة دون صورة.');
    } catch (e) {
      if (mounted) setState(() => _status = 'تعذر حفظ Excel: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadImagesZip() async {
    if (_rows.isEmpty) { setState(() => _status = 'لا توجد بيانات لحفظها. ابدأ فرز الموقع أولًا.'); return; }
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) { setState(() => _status = 'حدد صفًا واحدًا على الأقل.'); return; }
    setState(() => _busy = true);
    try {
      final xlsxBytes = await _createExcelBytes(selected);
      final archive = Archive();
      archive.addFile(ArchiveFile('بيانات الأصناف.xlsx', xlsxBytes.length, xlsxBytes));
      final imagePaths = _imageArchiveNames(selected);
      var savedImages = 0;
      for (final row in selected) {
        final path = imagePaths[row];
        final bytes = row.bytes;
        if (path == null || bytes == null || bytes.isEmpty) continue;
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
        savedImages++;
      }
      final zipped = ZipEncoder().encode(archive);
      if (zipped == null) throw Exception('تعذر إنشاء ملف ZIP.');
      await FileSaver.instance.saveFile(
        name: 'silsila_catalog_with_named_images_${DateTime.now().toIso8601String().substring(0, 10)}',
        bytes: Uint8List.fromList(zipped),
        fileExtension: 'zip',
        mimeType: MimeType.zip,
      );
      if (mounted) setState(() => _status = 'تم تنزيل ZIP يحتوي على Excel بصور مضمّنة ومجلد images بأسماء الأصناف الفعلية. السجلات: ${selected.length}، صور منفصلة: $savedImages.');
    } catch (e) {
      if (mounted) setState(() => _status = 'تعذر حفظ ZIP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  void _preview(_ImportRow row){showDialog<void>(context:context,builder:(ctx)=>Dialog(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[const Expanded(child:Text('معاينة الصورة',style:TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),Flexible(child:InteractiveViewer(child:row.imageUrl.isEmpty ? const Icon(Icons.category_outlined,size:80) : Image.network(row.imageUrl,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,size:80),fit:BoxFit.contain))),const SizedBox(height:8),Text(row.name)]))));}
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Container(
            color: _purple,
            padding: const EdgeInsets.all(14),
            child: const Row(children: [
              Icon(Icons.inventory_2, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('استيراد بيانات اصناف', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              Icon(Icons.link, color: Colors.white),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  SizedBox(width: 250, child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(labelText: 'رابط الموقع', hintText: 'https://example.com', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 10)),
                  )),
                  FilledButton.icon(onPressed: _busy ? null : _crawl, icon: const Icon(Icons.travel_explore, size: 18), label: const Text('فرز الموقع بالكامل')),
                  OutlinedButton.icon(onPressed: _busy ? null : _pasteUrl, icon: const Icon(Icons.content_paste, size: 18), label: const Text('لصق الرابط')),
                  OutlinedButton.icon(onPressed: _busy ? null : () => setState(() { _url.clear(); _status = 'تم مسح الرابط.'; }), icon: const Icon(Icons.clear, size: 18), label: const Text('مسح الرابط')),
                  OutlinedButton.icon(onPressed: _busy ? null : _resetExploration, icon: const Icon(Icons.restart_alt, size: 18), label: const Text('إعادة ضبط استكشاف')),
                  FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black), onPressed: _busy || _rows.isEmpty ? null : _downloadExcel, icon: const Icon(Icons.file_download_outlined, size: 18), label: const Text('حفظ اكسيل')),
                  OutlinedButton.icon(onPressed: _busy || _rows.isEmpty ? null : _downloadImagesZip, icon: const Icon(Icons.folder_zip, size: 18), label: const Text('حفظ Excel + صور ZIP')),
                  if (_crawling) OutlinedButton.icon(onPressed: () => setState(() => _cancelCrawl = true), icon: const Icon(Icons.stop_circle_outlined, size: 18), label: const Text('إيقاف الفحص')),
                ],
              ),
              const SizedBox(height: 6),
              Text(_status, style: const TextStyle(fontSize: 12)),
            ]),
          ),
          Expanded(
            child: _rows.isEmpty
              ? const Center(child: Text('ستظهر بيانات الأصناف والفئات والصور بعد بدء الفرز الشامل.'))
               : DataTable2(
                    fixedTopRows: 1,
                    fixedLeftColumns: 4,
                    minWidth: 2350,
                    columnSpacing: 8,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                    columns: [
                      DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('الكل'),
                        Checkbox(
                          shape: const CircleBorder(),
                          value: _selectAll,
                          onChanged: (v) => setState(() {
                            _selectAll = v ?? false;
                            for (final r in _rows) { r.selected = _selectAll; }
                          }),
                        ),
                      ])),
                      const DataColumn(label: Text('م')),
                      DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('الصورة'),
                        Checkbox(
                          shape: const CircleBorder(),
                          visualDensity: VisualDensity.compact,
                          value: _rows.isNotEmpty && _rows.every((r) => r.selected),
                          onChanged: (v) => setState(() {
                            _selectAll = v ?? false;
                            for (final r in _rows) { r.selected = _selectAll; }
                          }),
                        ),
                      ])),
                      DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('النوع'),
                        Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: _rows.isNotEmpty && _rows.every((r) => r.kind == 'صنف'), onChanged: (v) { if (v == true) setState(() { for (final r in _rows) { r.kind = 'صنف'; } }); }),
                        const Text('صنف', style: TextStyle(fontSize: 11)),
                        Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: _rows.isNotEmpty && _rows.every((r) => r.kind == 'فئة'), onChanged: (v) { if (v == true) setState(() { for (final r in _rows) { r.kind = 'فئة'; } }); }),
                        const Text('فئة', style: TextStyle(fontSize: 11)),
                      ])),
                      const DataColumn(label: Text('نوع الكود')),
                      const DataColumn(label: Text('بحث F1')),
                      const DataColumn(label: Text('كود صنف / فئة')),
                      const DataColumn(label: Text('الاسم العربي المقترح')),
                      
                      const DataColumn(label: Text('الفئة الرئيسية')),
                      const DataColumn(label: Text('الفئة الفرعية')),
                      const DataColumn(label: Text('الفئة الثانوية')),
                      const DataColumn(label: Text('البراند / الماركة')),
                      const DataColumn(label: Text('الباركود')),
                      const DataColumn(label: Text('السعر')),
                      const DataColumn(label: Text('الوصف')),
                      const DataColumn(label: Text('صفحة المصدر')),
                      const DataColumn(label: Text('الوحدة الكبرى')),
                      const DataColumn(label: Text('العدد الداخلي')),
                      const DataColumn(label: Text('الوحدة الصغرى')),
                      const DataColumn(label: Text('وحدات أخرى')),
                      const DataColumn(label: Text('الوزن')),
                      const DataColumn(label: Text('الطول')),
                      const DataColumn(label: Text('العرض')),
                      const DataColumn(label: Text('الارتفاع')),
                    ],
                    rows: _rows.map((r) => DataRow(cells: [
                      DataCell(Checkbox(shape: const CircleBorder(), value: r.selected, onChanged: (v) => setState(() => r.selected = v ?? false))),
                      DataCell(Text('${_rows.indexOf(r) + 1}')),
                      DataCell(GestureDetector(onTap: () => _preview(r), child: SizedBox(width: 52, height: 48, child: r.imageUrl.isEmpty ? const Icon(Icons.category_outlined) : Image.network(r.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))))),
                      DataCell(_kindCell(r, () => setState(() {}))),
                    DataCell(_codeModeCell(r, () => setState(() {}))),
                    DataCell(IconButton(tooltip: 'بحث F1 في قائمة الصنف أو الفئة', onPressed: () async {
                      final picked = await _pickExistingRecord(context, r.kind);
                      if (picked != null && mounted) setState(() { r.codeMode = 'قديم'; r.code = picked['code'] ?? ''; if ((picked['name'] ?? '').isNotEmpty) r.name = picked['name']!; });
                    }, icon: const Icon(Icons.search, color: _purple))),
                    DataCell(SizedBox(width: 130, child: TextFormField(initialValue: r.code, onChanged: (v) => r.code = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                    DataCell(SizedBox(width: 190, child: TextFormField(initialValue: r.name, onChanged: (v) => r.name = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 130, child: TextFormField(initialValue: r.category, onChanged: (v) => r.category = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 130, child: TextFormField(initialValue: r.subcategory, onChanged: (v) => r.subcategory = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 130, child: TextFormField(initialValue: r.thirdCategory, onChanged: (v) => r.thirdCategory = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 130, child: TextFormField(initialValue: r.brand, onChanged: (v) => r.brand = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 120, child: TextFormField(initialValue: r.barcode, onChanged: (v) => r.barcode = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 90, child: TextFormField(initialValue: r.salePrice, onChanged: (v) => r.salePrice = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 180, child: TextFormField(initialValue: r.description, onChanged: (v) => r.description = v, maxLines: 1, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 210, child: Tooltip(message: r.sourcePage, child: Text(r.sourcePage, maxLines: 1, overflow: TextOverflow.ellipsis)))),
                      DataCell(SizedBox(width: 110, child: TextFormField(initialValue: r.majorUnit, onChanged: (v) => r.majorUnit = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 85, child: TextFormField(initialValue: r.innerCount, onChanged: (v) => r.innerCount = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 110, child: TextFormField(initialValue: r.minorUnit, onChanged: (v) => r.minorUnit = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 120, child: TextFormField(initialValue: r.otherUnits, onChanged: (v) => r.otherUnits = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(_field(r.weight, (v) => r.weight = v)),
                      DataCell(_field(r.length, (v) => r.length = v)),
                      DataCell(_field(r.width, (v) => r.width = v)),
                      DataCell(_field(r.height, (v) => r.height = v)),
                    ])).toList(),
                  ),
          ),
        ],
      ),
    );
  }
  Widget _field(String value,ValueChanged<String> onChanged)=>SizedBox(width:75,child:TextFormField(initialValue:value,onChanged:onChanged,keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())));
}

class ErpItemDataDownloadScreen extends StatefulWidget {
  const ErpItemDataDownloadScreen({super.key});
  @override State<ErpItemDataDownloadScreen> createState()=>_ErpItemDataDownloadScreenState();
}
class _ErpItemDataDownloadScreenState extends State<ErpItemDataDownloadScreen>{
  List<_ImportRow> _rows=[];String _status='افتح ملف ZIP صادر من شاشة استيراد بيانات اصناف.';bool _busy=false,_all=true;
  Future<void> _openZip() async {
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['zip'],withData:true);
    if(result==null||result.files.single.bytes==null)return;
    setState(()=>_busy=true);
    try{
      final archive=ZipDecoder().decodeBytes(result.files.single.bytes!);final files=<String,Uint8List>{};
      for(final f in archive.files){if(f.isFile&&f.name.startsWith('images/'))files[f.name]=Uint8List.fromList(f.content as List<int>);}
      final workbookFile=archive.files.where((f)=>f.isFile&&f.name=='items.xlsx').firstOrNull;
      if(workbookFile==null)throw Exception('ملف items.xlsx غير موجود داخل ZIP');
      final workbook=Excel.decodeBytes(workbookFile.content as List<int>);final sheet=workbook.tables['بيانات الأصناف'];
      if(sheet==null||sheet.rows.isEmpty)throw Exception('جدول بيانات الأصناف فارغ');
      String cell(List<dynamic> row,int i)=>i<row.length?(row[i]?.value?.toString()??''):'';
      final modernFormat = sheet.rows.first.length > 20;
      final loaded=< _ImportRow >[];
      for(final row in sheet.rows.skip(1)){
        final id=cell(row,0);if(id.isEmpty)continue;final imagePath=cell(row,1);
        loaded.add(_ImportRow(
          id:id,imageUrl:cell(row,2),name:cell(row,3),
          kind:cell(row,4).isEmpty?'صنف':cell(row,4),
          codeMode:cell(row,5).isEmpty?'جديد':cell(row,5),code:cell(row,6),
          category:cell(row,7),subcategory:cell(row,8),
          thirdCategory:modernFormat?cell(row,9):'',
          brand:modernFormat?cell(row,10):'',
          barcode:modernFormat?cell(row,11):'',
          salePrice:modernFormat?cell(row,12):'',
          majorUnit:cell(row,modernFormat?13:9),
          innerCount:cell(row,modernFormat?14:10),
          minorUnit:cell(row,modernFormat?15:11),
          otherUnits:modernFormat?cell(row,16):'',
          weight:cell(row,modernFormat?17:12),
          length:cell(row,modernFormat?18:13),
          width:cell(row,modernFormat?19:14),
          height:cell(row,modernFormat?20:15),
          description:modernFormat?cell(row,21):'',
          sourcePage:modernFormat?cell(row,22):'',
          bytes:files[imagePath],selected:true));
      }
      setState(() { _rows=loaded; _status='تم فتح ${loaded.length} صفًا. التعديلات محلية ولن تُحفظ في قاعدة البيانات.'; });
    }catch(e){setState(()=>_status='تعذر فتح ZIP: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _exportZip()async{
    setState(()=>_busy=true);
    try{
      final selected=_rows.where((r)=>r.selected).toList(); if(selected.isEmpty) throw Exception('حدد صفًا واحدًا على الأقل للتصدير'); final archive=Archive();final book=Excel.createExcel();final sheet=book['بيانات الأصناف'];final headers=_headers;sheet.appendRow(_headerLabels.map((h)=>TextCellValue(h)).toList());
      for(final r in selected){final imageFile=r.bytes==null?'':'images/${r.id}.${_ext(r.imageUrl)}';final m=r.toMap()..['image_file']=imageFile;sheet.appendRow(headers.map((h)=>TextCellValue(m[h]??'')).toList());if(r.bytes!=null)archive.addFile(ArchiveFile(imageFile,r.bytes!.length,r.bytes!));}
      final x=book.encode()!;archive.addFile(ArchiveFile('items.xlsx',x.length,x));final zipped=ZipEncoder().encode(archive)!;
      await FileSaver.instance.saveFile(name:'silsila_items_edited',bytes:Uint8List.fromList(zipped),fileExtension:'zip',mimeType:MimeType.zip);
      setState(()=>_status='تم تصدير ZIP المعدل دون أي كتابة في قاعدة البيانات.');
    }catch(e){setState(()=>_status='فشل التصدير: $e');}finally{if(mounted)setState(()=>_busy=false);}
  }
  String _ext(String url){final p=Uri.tryParse(url)?.path.toLowerCase()??'';for(final e in ['png','webp','gif','avif','jpeg']){if(p.endsWith('.$e'))return e;}return 'jpg';}
  void _preview(_ImportRow r){showDialog<void>(context:context,builder:(c)=>Dialog(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[Align(alignment:Alignment.centerRight,child:IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close))),Flexible(child:r.bytes!=null?InteractiveViewer(child:Image.memory(r.bytes!,fit:BoxFit.contain)):Image.network(r.imageUrl,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image))),Text(r.name)]))));}
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        Container(
          color: _purple,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.download_for_offline, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('تنزيل بيانات أصناف', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            OutlinedButton.icon(onPressed: _busy ? null : _openZip, icon: const Icon(Icons.folder_open, color: Colors.white), label: const Text('فتح ZIP', style: TextStyle(color: Colors.white))),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: Text(_status, style: const TextStyle(fontSize: 12))),
          FilledButton.icon(onPressed: _busy || _rows.isEmpty ? null : _exportZip, icon: const Icon(Icons.folder_zip), label: const Text('تصدير ZIP المعدل')),
        ])),
        Expanded(
          child: _rows.isEmpty
            ? const Center(child: Text('افتح ملف ZIP لعرض البيانات وتعديلها.'))
             : DataTable2(
                  fixedTopRows: 1,
                  fixedLeftColumns: 4,
                  minWidth: 1700,
                  columnSpacing: 8,
                  columns: [
                    DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('الكل'),
                      Checkbox(shape: const CircleBorder(), value: _all, onChanged: (v) {
                        setState(() { _all = v ?? false; for (final r in _rows) { r.selected = _all; } });
                      }),
                    ])),
                    const DataColumn(label: Text('م')),
                    DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('الصورة'),
                      Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact,
                        value: _rows.isNotEmpty && _rows.every((r) => r.selected),
                        onChanged: (v) => setState(() { _all = v ?? false; for (final r in _rows) { r.selected = _all; } })),
                    ])),
                    DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('النوع'),
                      Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact,
                        value: _rows.isNotEmpty && _rows.every((r) => r.kind == 'صنف'),
                        onChanged: (v) { if (v == true) setState(() { for (final r in _rows) { r.kind = 'صنف'; } }); }),
                      const Text('صنف', style: TextStyle(fontSize: 11)),
                      Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact,
                        value: _rows.isNotEmpty && _rows.every((r) => r.kind == 'فئة'),
                        onChanged: (v) { if (v == true) setState(() { for (final r in _rows) { r.kind = 'فئة'; } }); }),
                      const Text('فئة', style: TextStyle(fontSize: 11)),
                    ])),
                    const DataColumn(label: Text('نوع الكود')),
                    const DataColumn(label: Text('بحث F1')),
                    const DataColumn(label: Text('كود صنف / فئة')),
                    const DataColumn(label: Text('اسم الصنف / الفئة')),
                    const DataColumn(label: Text('الفئة الرئيسية')),
                    const DataColumn(label: Text('الفئة الفرعية')),
                    const DataColumn(label: Text('الوحدة الكبرى')),
                    const DataColumn(label: Text('العدد الداخلي')),
                    const DataColumn(label: Text('الوحدة الصغرى')),
                    const DataColumn(label: Text('الوزن')),
                    const DataColumn(label: Text('الطول')),
                    const DataColumn(label: Text('العرض')),
                    const DataColumn(label: Text('الارتفاع')),
                  ],
                  rows: _rows.map((r) => DataRow(cells: [
                    DataCell(Checkbox(shape: const CircleBorder(), value: r.selected, onChanged: (v) => setState(() => r.selected = v ?? false))),
                    DataCell(Text('${_rows.indexOf(r) + 1}')),
                    DataCell(GestureDetector(onTap: () => _preview(r), child: SizedBox(width: 52, height: 48, child: r.bytes != null ? Image.memory(r.bytes!, fit: BoxFit.contain) : (r.imageUrl.isEmpty ? const Icon(Icons.category_outlined) : Image.network(r.imageUrl, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)))))),
                    DataCell(_kindCell(r, () => setState(() {}))),
                    DataCell(_codeModeCell(r, () => setState(() {}))),
                    DataCell(IconButton(tooltip: 'بحث F1 في قائمة الصنف أو الفئة', onPressed: () async {
                      final picked = await _pickExistingRecord(context, r.kind);
                      if (picked != null && mounted) setState(() { r.codeMode = 'قديم'; r.code = picked['code'] ?? ''; if ((picked['name'] ?? '').isNotEmpty) r.name = picked['name']!; });
                    }, icon: const Icon(Icons.search, color: _purple))),
                    DataCell(SizedBox(width: 130, child: TextFormField(initialValue: r.code, onChanged: (v) => r.code = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                    DataCell(SizedBox(width: 190, child: TextFormField(initialValue: r.name, onChanged: (v) => r.name = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                    DataCell(_field(r.category, (v) => r.category = v)),
                    DataCell(_field(r.subcategory, (v) => r.subcategory = v)),
                    DataCell(_field(r.majorUnit, (v) => r.majorUnit = v)),
                    DataCell(_field(r.innerCount, (v) => r.innerCount = v)),
                    DataCell(_field(r.minorUnit, (v) => r.minorUnit = v)),
                    DataCell(_field(r.weight, (v) => r.weight = v)),
                    DataCell(_field(r.length, (v) => r.length = v)),
                    DataCell(_field(r.width, (v) => r.width = v)),
                    DataCell(_field(r.height, (v) => r.height = v)),
                  ])).toList(),
                ),
        ),
      ]),
    );
  }
  Widget _field(String v,ValueChanged<String> c)=>SizedBox(width:100,child:TextFormField(initialValue:v,onChanged:c,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())));
}
