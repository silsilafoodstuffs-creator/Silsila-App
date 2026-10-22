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
  final Map<String, TextEditingController> _rowControllers = {};
  String? _importedScope;
  String _imageKind = 'product';

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
    for (final controller in _rowControllers.values) { controller.dispose(); }
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
    final longest = width > height ? width : height;
    final scale = 4096 / longest;
    final targetWidth = (width * scale).round().clamp(1, 4096).toInt();
    final targetHeight = (height * scale).round().clamp(1, 4096).toInt();
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
        final raw=await db.from('erp_item_groups').select('id,parent_id,group_code,group_name,group_name_en').eq('company_id',company).eq('group_code',code).maybeSingle();
        if(raw==null)throw Exception('كود الفئة غير موجود في الشركة الحالية.');
        final rows=await db.from('erp_item_groups').select('id,parent_id,group_code,group_name').eq('company_id',company).limit(3000);
        final groups=(rows as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        Map<String,dynamic>? byId(dynamic id){for(final g in groups){if(id!=null&&g['id'].toString()==id.toString())return g;}return null;}
        final found=Map<String,dynamic>.from(raw);final parent=byId(found['parent_id']);final grand=byId(parent?['parent_id']);
        final Map<String,dynamic>? root=found['parent_id']==null?found:(parent?['parent_id']==null?parent:grand);
        final Map<String,dynamic>? sub=found['parent_id']==null?null:(parent?['parent_id']==null?found:parent);
        final Map<String,dynamic>? third=sub!=null&&found['id'].toString()!=sub['id'].toString()?found:null;
        item['category_root_id']=root?['id']?.toString();item['category_sub_id']=sub?['id']?.toString();item['category_secondary_id']=third?['id']?.toString();item['category_target_id']=found['id'].toString();
        _rowController(item,'category_main_name').text=(root?['group_name']??'').toString();
        _rowController(item,'category_sub_name').text=(sub?['group_name']??'').toString();
        _rowController(item,'category_secondary_name').text=(third?['group_name']??'').toString();
        item['entity_mode']='old';if(mounted)setState(()=>_status='تم تحميل الفئة القديمة '+code+'؛ راجع الأسماء ثم اضغط تحديث بيانات.');
      }else{
        final raw=await db.from('erp_items').select('id,item_name,item_name_en,base_unit,sale_price,tax_rate,pricing_area,package_description').eq('company_id',company).eq('item_code',code).maybeSingle();
        if(raw==null)throw Exception('كود الصنف غير موجود في الشركة الحالية.');
        item['database_item_id']=raw['id'].toString();
        _rowController(item,'item_name_ar').text=(raw['item_name']??'').toString();_rowController(item,'item_name_en').text=(raw['item_name_en']??'').toString();
        _rowController(item,'minor_unit').text=(raw['base_unit']??'قطعة').toString();_rowController(item,'sale_price').text=(raw['sale_price']??0).toString();
        _rowController(item,'tax_rate').text=(raw['tax_rate']??0).toString();_rowController(item,'pricing_area').text=(raw['pricing_area']??1).toString();
        final desc=(raw['package_description']??'').toString().split('=');
        if(desc.length>1){_rowController(item,'major_unit').text=desc.first.trim();final p=desc[1].trim().split(RegExp(r'\s+'));if(p.isNotEmpty)_rowController(item,'internal_count').text=p.first;}
        final units=await db.from('erp_item_units').select('unit_name,conversion_factor,is_base_unit').eq('company_id',company).eq('item_id',raw['id'].toString()).eq('is_active',true);
        for(final u in (units as List).map((e)=>Map<String,dynamic>.from(e))){if(u['is_base_unit']==true)_rowController(item,'minor_unit').text=(u['unit_name']??'قطعة').toString();else if((double.tryParse((u['conversion_factor']??1).toString())??1)>1){_rowController(item,'major_unit').text=(u['unit_name']??'').toString();_rowController(item,'internal_count').text=(u['conversion_factor']??1).toString();}}
        item['entity_mode']='old';if(mounted)setState(()=>_status='تم تحميل الصنف القديم '+code+'؛ راجع البيانات ثم اضغط تحديث بيانات.');
      }
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<Map<String,dynamic>> _ensureRowCategory(SupabaseClient db,String company,List<Map<String,dynamic>> groups,String name,String? parent,String prefix) async{
    final normalized=name.trim().replaceAll(RegExp(r'\s+'),' ').toLowerCase();
    for(final g in groups){if((g['parent_id']?.toString()??'')==(parent??'')&&(g['group_name']??'').toString().trim().replaceAll(RegExp(r'\s+'),' ').toLowerCase()==normalized)return g;}
    var max=0;for(final g in groups){final m=RegExp('^'+prefix+r'(\d+)$',caseSensitive:false).firstMatch((g['group_code']??'').toString());if(m!=null){final n=int.tryParse(m.group(1)!)??0;if(n>max)max=n;}}
    final code=prefix+(max+1).toString().padLeft(4,'0');
    final row=await db.from('erp_item_groups').insert({'company_id':company,'parent_id':parent,'group_code':code,'group_name':name.trim(),'group_name_en':'','is_active':true,'show_in_app':true,'image_url':null}).select('id,parent_id,group_code,group_name').single();
    final created=Map<String,dynamic>.from(row);groups.add(created);return created;
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
    if(main.isEmpty){setState(()=>_error='اسم الفئة الرئيسية مطلوب.');return;}if(thirdName.isNotEmpty&&subName.isEmpty){setState(()=>_error='الفئة الثانوية تتطلب اسم فئة فرعية.');return;}
    if(mode=='old'&&item['category_target_id']==null){setState(()=>_error='ابحث عن الكود القديم أولًا.');return;}
    setState(()=>_loading=true);
    try{
      final raw=await db.from('erp_item_groups').select('id,parent_id,group_code,group_name,group_name_en').eq('company_id',company).limit(3000);
      final groups=(raw as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      Map<String,dynamic>? byId(dynamic id){for(final g in groups){if(id!=null&&g['id'].toString()==id.toString())return g;}return null;}
      late Map<String,dynamic> target;
      if(mode=='old'){
        final root=byId(item['category_root_id']),sub=byId(item['category_sub_id']),third=byId(item['category_secondary_id']);
        if(root!=null)await db.from('erp_item_groups').update({'group_name':main}).eq('id',root['id'].toString()).eq('company_id',company);
        if(sub!=null&&subName.isNotEmpty)await db.from('erp_item_groups').update({'group_name':subName}).eq('id',sub['id'].toString()).eq('company_id',company);
        if(third!=null&&thirdName.isNotEmpty)await db.from('erp_item_groups').update({'group_name':thirdName}).eq('id',third['id'].toString()).eq('company_id',company);
        target=byId(item['category_target_id'])!;
      }else{
        final root=await _ensureRowCategory(db,company,groups,main,null,'C');Map<String,dynamic>? sub,third;
        if(subName.isNotEmpty)sub=await _ensureRowCategory(db,company,groups,subName,root['id'].toString(),'S');
        if(thirdName.isNotEmpty){if(sub==null)throw Exception('الفئة الثانوية تتطلب فئة فرعية.');third=await _ensureRowCategory(db,company,groups,thirdName,sub['id'].toString(),'T');}
        target=third??sub??root;
      }
      final downloaded=await _invoke({'action':'download','url':item['url'].toString()});final b64=downloaded['base64']?.toString();if(b64==null||b64.isEmpty)throw Exception('لم تصل بيانات الصورة.');
      final png=_processTransparentPng(Uint8List.fromList(base64Decode(b64)));
      await db.from('erp_item_groups').update({'image_data':_byteaHex(png),'image_mime_type':'image/png','image_url':null}).eq('id',target['id'].toString()).eq('company_id',company);
      await _finishSavedRow(item,(mode=='old'?'تم تحديث الفئة ':'تم تكويد الفئة ')+(target['group_code']??'').toString()+' وحفظ صورة PNG في قاعدة البيانات.');
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
      final downloaded=await _invoke({'action':'download','url':item['url'].toString()});final b64=downloaded['base64']?.toString();if(b64==null||b64.isEmpty)throw Exception('لم تصل بيانات الصورة.');
      final png=_processTransparentPng(Uint8List.fromList(base64Decode(b64)));
      final values=<String,dynamic>{'item_name':ar,'item_name_en':en,'base_unit':minor,'sale_price':price,'tax_rate':tax,'pricing_area':area,'package_description':major+' = '+count.toString()+' '+minor,'image_data':_byteaHex(png),'image_mime_type':'image/png','image_url':null,'source_name':'جامع صور سلسلة','source_url':item['url'].toString(),'is_active':true};
      String id;
      if(mode=='new'){final inserted=await db.from('erp_items').insert({...values,'company_id':company,'item_code':code,'purchase_price':0,'group_id':item['group_id']}).select('id').single();id=inserted['id'].toString();}
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
                Align(alignment: Alignment.centerRight, child: SizedBox(width: 300, child: DropdownButtonFormField<String>(value: _imageKind, decoration: const InputDecoration(labelText: 'نوع الصور الجاري تجهيزها', border: OutlineInputBorder(), isDense: true), items: const [DropdownMenuItem(value: 'product', child: Text('صور الأصناف والمنتجات')), DropdownMenuItem(value: 'category', child: Text('صور الفئات والمجموعات'))], onChanged: _loading ? null : (value) { if (value == null) return; setState(() { _imageKind = value; for (final image in _images) { image['save_as'] = value; image.remove('file_name'); } }); }))),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _pasteClipboardUrl,
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      label: const Text('لصق الرابط المنسوخ'),
                      style: OutlinedButton.styleFrom(foregroundColor: _purple, visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () {
                        setState(() { _url.clear(); _error = null; _status = 'تم مسح الرابط.'; });
                      },
                      icon: const Icon(Icons.backspace_outlined, size: 17),
                      label: const Text('مسح الخانة'),
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
                    label: const Text('فحص الصفحة وجمع الصور'),
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
            
            ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 18), itemCount: _images.length,
              itemBuilder: (context,index) {
                final item=_images[index]; final url=item['url'].toString(); final selected=_selected.contains(url);
                final kind=(item['save_as']??'product').toString(); final mode=(item['entity_mode']??'new').toString();
                Widget field(String key,String label,{double width=180,String initial='',TextInputType type=TextInputType.text}) {
                  return SizedBox(width:width,child:TextField(controller:_rowController(item,key,initial:initial),keyboardType:type,
                    onChanged:(v)=>item[key]=v,decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:9,vertical:11))));
                }
                Widget dropdown(String key,String label,String value,List<String> options,{double width=145}) {
                  final choices=options.contains(value)?options:<String>[value,...options];
                  return SizedBox(width:width,child:DropdownButtonFormField<String>(value:choices.firstWhere((v)=>v==value,orElse:()=>choices.first),isExpanded:true,
                    decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:9)),
                    items:choices.map((v)=>DropdownMenuItem(value:v,child:Text(key=='entity_mode'?(v=='new'?'كود جديد':'كود قديم'):key=='save_as'?(v=='category'?'فئة':'صنف'):key=='major_unit'&&v.isEmpty?'اختر الوحدة الكبرى':key=='minor_unit'&&v.isEmpty?'اختر الوحدة الصغرى':v,overflow:TextOverflow.ellipsis))).toList(),
                    onChanged:_loading?null:(v){if(v==null)return;setState((){item[key]=v;if(key=='major_unit'||key=='minor_unit')_rowController(item,key).text=v;if(key=='save_as'){item.remove('entity_mode');item.remove('database_item_id');item.remove('category_target_id');}});}));
                }
                final suggested=_suggestedImageName(item,index);
                var productName='';
                for(final candidate in [item['product_full_name'],item['product_name'],item['product_title'],item['sku_name'],item['item_name'],item['context_name'],item['title'],item['name'],item['alt']]){
                  final value=candidate?.toString().trim()??'';
                  if(_looksLikeEntityName(value)){productName=value;break;}
                }
                if(productName.isEmpty)productName=suggested.replaceAll('_',' ');
                final productUnit=_excelValue(item,['main_unit','unit','unit_name','major_unit']);
                if(productUnit.isNotEmpty&&!productName.toLowerCase().contains(productUnit.toLowerCase()))productName=productName+' '+productUnit;
                final productCount=_excelValue(item,['internal_count','units_per_pack','pack_size','quantity_per_unit']);
                if(productCount.isNotEmpty&&!RegExp(r'(^|[^0-9])'+RegExp.escape(productCount)+r'([^0-9]|$)').hasMatch(productName))productName=productName+' عدد داخلي '+productCount;
                final common=SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                  SizedBox(width:42,child:Checkbox(value:selected,activeColor:_purple,onChanged:_loading?null:(v)=>_toggle(url,v))),
                  SizedBox(width:38,child:Text((index+1).toString(),textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800))),
                  Container(width:70,height:66,padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:const Color(0xFFF7F4F9),borderRadius:BorderRadius.circular(8),border:Border.all(color:const Color(0xFFE7E0EE))),
                    child:Image.network(url,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined),loadingBuilder:(c,ch,p)=>p==null?ch:const Center(child:CircularProgressIndicator(strokeWidth:2)))),
                  const SizedBox(width:8),field('file_name','اسم الصورة',width:205,initial:suggested),const SizedBox(width:8),
                  dropdown('save_as','نوع الصورة',kind,const ['product','category'],width:140),const SizedBox(width:8),
                  FilledButton.tonalIcon(onPressed:_loading?null:()=>_saveOne(item),icon:const Icon(Icons.download_rounded,size:18),label:const Text('تنزيل PNG'),style:FilledButton.styleFrom(foregroundColor:_purple)),
                ]));
                final editor=kind=='category'
                  ? SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                      const SizedBox(width:10),dropdown('entity_mode','نوع الكود',mode,const ['new','old'],width:135),const SizedBox(width:8),
                      if(mode=='old')...[field('legacy_code','كود الفئة القديم',width:155),const SizedBox(width:5),OutlinedButton.icon(onPressed:_loading?null:()=>_lookupRowCode(item),icon:const Icon(Icons.search),label:const Text('بحث')),const SizedBox(width:8)],
                      field('category_main_name','اسم فئة رئيسية',width:185,initial:_excelValue(item,['main_category','category_name','category'])),const SizedBox(width:8),
                      field('category_sub_name','اسم فئة فرعية',width:185,initial:_excelValue(item,['sub_category','subcategory','group_name'])),const SizedBox(width:8),
                      field('category_secondary_name','اسم فئة ثانوية',width:185,initial:_excelValue(item,['secondary_category','third_category'])),const SizedBox(width:8),
                      FilledButton.icon(onPressed:_loading?null:()=>_saveRowCategory(item),icon:Icon(mode=='old'?Icons.save_outlined:Icons.add_circle_outline),label:Text(mode=='old'?'تحديث بيانات':'تكويد جديد'),style:FilledButton.styleFrom(backgroundColor:_purple)),const SizedBox(width:10),
                    ]))
                  : SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                      const SizedBox(width:10),dropdown('entity_mode','نوع الكود',mode,const ['new','old'],width:135),const SizedBox(width:8),
                      if(mode=='old')...[field('legacy_code','كود الصنف القديم',width:155),const SizedBox(width:5),OutlinedButton.icon(onPressed:_loading?null:()=>_lookupRowCode(item),icon:const Icon(Icons.search),label:const Text('بحث')),const SizedBox(width:8)],
                      field('item_name_ar','اسم الصنف عربي',width:210,initial:productName),const SizedBox(width:8),
                      field('item_name_en','اسم الصنف إنجليزي',width:190,initial:_excelValue(item,['product_name_en','english_name','name_en'])),const SizedBox(width:8),
                      dropdown('major_unit','الوحدة الكبرى',_rowController(item,'major_unit',initial:_excelValue(item,['major_unit','main_unit','unit'])).text,const ['','كرتونة','شدة','باكو','علبة','زجاجة','كيس','كيلو','جرام','لتر','مللي','قطعة','عبوة'],width:145),const SizedBox(width:8),
                      field('internal_count','عدد داخلي',width:100,initial:_excelValue(item,['internal_count','units_per_pack','pack_size','quantity_per_unit']),type:TextInputType.number),const SizedBox(width:8),
                      dropdown('minor_unit','الوحدة الصغرى',_rowController(item,'minor_unit',initial:_excelValue(item,['minor_unit','sub_unit','small_unit'])).text,const ['','قطعة','عبوة','علبة','زجاجة','كيس','جرام','مللي','وحدة'],width:145),const SizedBox(width:8),
                      field('sale_price','سعر الصنف',width:110,initial:_excelValue(item,['sale_price','price','price_value']),type:const TextInputType.numberWithOptions(decimal:true)),const SizedBox(width:8),
                      field('pricing_area','مساحة تسعير',width:120,initial:_excelValue(item,['pricing_area','price_area']),type:const TextInputType.numberWithOptions(decimal:true)),const SizedBox(width:8),
                      field('tax_rate','نسبة ضريبة %',width:115,initial:_excelValue(item,['tax_rate','tax_percent','vat']),type:const TextInputType.numberWithOptions(decimal:true)),const SizedBox(width:8),
                      FilledButton.icon(onPressed:_loading?null:()=>_saveRowProduct(item),icon:Icon(mode=='old'?Icons.save_outlined:Icons.add_circle_outline),label:Text(mode=='old'?'تحديث بيانات':'تكويد جديد'),style:FilledButton.styleFrom(backgroundColor:_purple)),const SizedBox(width:10),
                    ]));
                return Container(margin:const EdgeInsets.only(bottom:10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:selected?_purple.withValues(alpha:.65):const Color(0xFFE7E0EE),width:selected?1.5:1)),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:8),child:common),const Divider(height:1),Padding(padding:const EdgeInsets.symmetric(vertical:9),child:editor)]));
              },
            ),
        ],
      ),
    );
  }

}