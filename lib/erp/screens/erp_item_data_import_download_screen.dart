import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

Widget _kindCell(_ImportRow row, VoidCallback refresh) => SizedBox(
  width: 150,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Expanded(
        child: InkWell(
          onTap: () { row.kind = 'صنف'; refresh(); },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                shape: const CircleBorder(),
                value: row.kind == 'صنف',
                onChanged: (checked) {
                  if (checked == true) { row.kind = 'صنف'; refresh(); }
                },
                visualDensity: VisualDensity.compact,
              ),
              const Flexible(child: Text('صنف', style: TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ),
      Expanded(
        child: InkWell(
          onTap: () { row.kind = 'فئة'; refresh(); },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                shape: const CircleBorder(),
                value: row.kind == 'فئة',
                onChanged: (checked) {
                  if (checked == true) { row.kind = 'فئة'; refresh(); }
                },
                visualDensity: VisualDensity.compact,
              ),
              const Flexible(child: Text('فئة', style: TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ),
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
      final table = kind == 'فئة' ? 'categories' : 'erp_items';
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
  width: 150,
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    InkWell(onTap: () { row.codeMode = 'جديد'; if (row.code.isEmpty) row.code = row.kind == 'فئة' ? 'CAT00001' : 'ITM00001'; refresh(); },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(shape: const CircleBorder(), value: row.codeMode == 'جديد', visualDensity: VisualDensity.compact, onChanged: (v) { if (v == true) { row.codeMode='جديد'; row.code = row.kind == 'فئة' ? 'CAT00001' : 'ITM00001'; refresh(); } }),
        const Text('جديد', style: TextStyle(fontSize: 11)),
      ])),
    InkWell(onTap: () { row.codeMode='قديم'; refresh(); },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(shape: const CircleBorder(), value: row.codeMode == 'قديم', visualDensity: VisualDensity.compact, onChanged: (v) { if (v == true) { row.codeMode='قديم'; refresh(); } }),
        const Text('قديم', style: TextStyle(fontSize: 11)),
      ])),
  ]),
);

class _ImportRow {
  _ImportRow({required this.id, required this.imageUrl, this.bytes, this.name = '', this.kind = 'صنف', this.codeMode = 'جديد', this.code = '', this.category = '', this.subcategory = '', this.majorUnit = '', this.innerCount = '', this.minorUnit = '', this.weight = '', this.length = '', this.width = '', this.height = '', this.selected = true});
  final String id;
  String imageUrl, name, kind, codeMode, code, category, subcategory, majorUnit, innerCount, minorUnit, weight, length, width, height;
  Uint8List? bytes;
  bool selected;
  Map<String,String> toMap() => {'id':id,'image_file':'images/$id.jpg','image_url':imageUrl,'name_ar':name,'record_type':kind,'code_mode':codeMode,'item_code':code,'category':category,'subcategory':subcategory,'major_unit':majorUnit,'inner_count':innerCount,'minor_unit':minorUnit,'weight':weight,'length':length,'width':width,'height':height};
}

class ErpItemDataImportScreen extends StatefulWidget {
  const ErpItemDataImportScreen({super.key});
  @override State<ErpItemDataImportScreen> createState() => _ErpItemDataImportScreenState();
}
class _ErpItemDataImportScreenState extends State<ErpItemDataImportScreen> {
  final _url = TextEditingController();
  final List<_ImportRow> _rows = [];
  bool _busy = false, _selectAll = true;
  String _status = 'أدخل رابط موقع لبدء اكتشاف الصفحات والصور.';
  static const _headers = ['id','image_file','image_url','name_ar','record_type','code_mode','item_code','category','subcategory','major_unit','inner_count','minor_unit','weight','length','width','height'];
  @override void dispose(){_url.dispose();super.dispose();}
  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value != null && value.isNotEmpty && mounted) {
      setState(() { _url.text = value; _status = 'تم لصق الرابط. اضغط استكشاف الموقع للبدء.'; });
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
    setState(() { _busy = true; _status = 'جاري فحص الصفحة واستخراج بيانات الصور من خدمة سلسلة...'; _rows.clear(); });
    try {
      // Use the server-side collector so browser CORS restrictions do not
      // silently leave the screen empty when a shop blocks direct requests.
      final response = await Supabase.instance.client.functions.invoke(
        'silsila-image-collector',
        body: {'action': 'scan', 'url': uri.toString()},
      );
      final payload = response.data;
      if (response.status >= 400 || payload is! Map || payload['error'] != null) {
        final message = payload is Map ? (payload['error']?.toString() ?? 'تعذر استكشاف الموقع.') : 'استجابة غير مفهومة من خدمة الاستكشاف.';
        throw Exception(message);
      }
      final list = payload['images'];
      if (list is! List) throw Exception('لم تُرجع خدمة الاستكشاف قائمة صور صالحة.');
      final seen = <String>{};
      var index = 0;
      for (final entry in list) {
        if (entry is! Map) continue;
        final imageUrl = (entry['url'] ?? '').toString().trim();
        if (imageUrl.isEmpty || !seen.add(imageUrl)) continue;
        final path = Uri.tryParse(imageUrl)?.path.toLowerCase() ?? '';
        final suppliedName = (entry['product_name'] ?? entry['context_name'] ?? entry['alt'] ?? '').toString().trim();
        final name = suppliedName.isNotEmpty ? suppliedName : _suggestName(path);
        index++;
        _rows.add(_ImportRow(
          id: 'IMG${index.toString().padLeft(5, '0')}',
          code: 'ITM${index.toString().padLeft(5, '0')}',
          imageUrl: imageUrl,
          name: name,
          kind: (entry['record_type'] ?? 'صنف').toString() == 'فئة' ? 'فئة' : 'صنف',
          category: (entry['main_category'] ?? '').toString(),
          subcategory: (entry['subcategory'] ?? '').toString(),
          majorUnit: (entry['major_unit'] ?? '').toString(),
          innerCount: (entry['internal_count'] ?? '').toString(),
          minorUnit: (entry['minor_unit'] ?? '').toString(),
          weight: (entry['weight'] ?? '').toString(),
          selected: true,
        ));
      }
      if (mounted) {
        setState(() {
          _selectAll = true;
          _status = _rows.isEmpty
            ? 'تم فحص الصفحة، لكن لم تُكتشف صور أصناف مسماة. جرّب رابط صفحة فئة أو صفحة منتجات مباشرة.'
            : 'تم فحص الصفحة: ${_rows.length} صورة/صنف مرشح. راجع الجدول ثم أنشئ ZIP.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'فشل الاستكشاف: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  String _suggestName(String path) {
    var base=path.split('/').last.split('?').first.replaceAll(RegExp(r'\.(jpg|jpeg|png|webp|gif|avif)$',caseSensitive:false),'');
    base=base.replaceAll(RegExp(r'[-_]+'),' ').replaceAll(RegExp(r'\d{3,}'),' ').trim();
    return base.isEmpty?'اسم يحتاج مراجعة':base;
  }
  Future<void> _downloadZip() async {
    final selected=_rows.where((r)=>r.selected).toList();
    if(selected.isEmpty){setState(()=>_status='حدد صفًا واحدًا على الأقل.');return;}
    setState(()=>_busy=true);
    try{
      final archive=Archive(); final book=Excel.createExcel(); final sheet=book['بيانات الأصناف'];
      sheet.appendRow(_headers.map((e)=>TextCellValue(e)).toList());
      var done=0;
      for(final row in selected){
        row.bytes ??= await _fetchImage(row.imageUrl);
        final ext=_extension(row.imageUrl);
        final fileName='images/${row.id}.$ext';
        final data=row.toMap()..['image_file']=fileName;
        sheet.appendRow(_headers.map((h)=>TextCellValue(data[h]??'')).toList());
        if(row.bytes!=null) archive.addFile(ArchiveFile(fileName,row.bytes!.length,row.bytes!));
        done++; if(mounted)setState(()=>_status='تجهيز ZIP: $done / ${selected.length}');
      }
      final xlsx=book.encode();
      if(xlsx==null)throw Exception('تعذر إنشاء ملف Excel');
      archive.addFile(ArchiveFile('items.xlsx',xlsx.length,xlsx));
      final manifest=utf8.encode(jsonEncode({'format':'silsila-items-zip-v1','created_at':DateTime.now().toIso8601String(),'rows':selected.length,'images_included':selected.where((r)=>r.bytes!=null).length,'columns':_headers}));
      archive.addFile(ArchiveFile('manifest.json',manifest.length,manifest));
      final zipped=ZipEncoder().encode(archive);
      if(zipped==null)throw Exception('تعذر ضغط الملف');
      await FileSaver.instance.saveFile(name:'silsila_items_import',bytes:Uint8List.fromList(zipped),fileExtension:'zip',mimeType:MimeType.zip);
      if(mounted)setState(()=>_status='تم إنشاء ملف ZIP للتنزيل. لم يتم حفظ أي بيانات أو صور في قاعدة البيانات.');
    }catch(e){if(mounted)setState(()=>_status='تعذر إنشاء الملف: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'silsila-image-collector',
        body: {'action': 'download', 'url': url, 'referer': _url.text.trim()},
      );
      final payload = response.data;
      if (response.status >= 400 || payload is! Map || payload['base64'] == null) return null;
      return Uint8List.fromList(base64Decode(payload['base64'].toString()));
    } catch (_) {
      return null;
    }
  }
  String _extension(String url){final p=Uri.tryParse(url)?.path.toLowerCase()??'';for(final e in ['png','webp','gif','avif','jpeg']){if(p.endsWith('.$e'))return e;}return 'jpg';}
  void _preview(_ImportRow row){showDialog<void>(context:context,builder:(ctx)=>Dialog(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[const Expanded(child:Text('معاينة الصورة',style:TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),Flexible(child:InteractiveViewer(child:Image.network(row.imageUrl,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,size:80),fit:BoxFit.contain))),const SizedBox(height:8),Text(row.name)]))));}
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
                  FilledButton.icon(onPressed: _busy ? null : _crawl, icon: const Icon(Icons.travel_explore, size: 18), label: const Text('استكشاف الموقع')),
                  OutlinedButton.icon(onPressed: _busy ? null : _pasteUrl, icon: const Icon(Icons.content_paste, size: 18), label: const Text('لصق الرابط')),
                  OutlinedButton.icon(onPressed: _busy ? null : () => setState(() { _url.clear(); _status = 'تم مسح الرابط.'; }), icon: const Icon(Icons.clear, size: 18), label: const Text('مسح الرابط')),
                  OutlinedButton.icon(onPressed: _busy ? null : _resetExploration, icon: const Icon(Icons.restart_alt, size: 18), label: const Text('إعادة ضبط استكشاف')),
                  FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black), onPressed: _busy || _rows.isEmpty ? null : _downloadZip, icon: const Icon(Icons.folder_zip, size: 18), label: const Text('إنشاء ZIP')),
                ],
              ),
              const SizedBox(height: 6),
              Text(_status, style: const TextStyle(fontSize: 12)),
            ]),
          ),
          Expanded(
            child: _rows.isEmpty
              ? const Center(child: Text('ستظهر الصور المكتشفة هنا بعد استكشاف الموقع.'))
              : Scrollbar(thumbVisibility: true, interactive: true, child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Scrollbar(thumbVisibility: true, interactive: true, child: SingleChildScrollView(child: DataTable(
                    columnSpacing: 18,
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
                      DataCell(GestureDetector(onTap: () => _preview(r), child: SizedBox(width: 52, height: 48, child: Image.network(r.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))))),
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
                      DataCell(SizedBox(width: 110, child: TextFormField(initialValue: r.majorUnit, onChanged: (v) => r.majorUnit = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 85, child: TextFormField(initialValue: r.innerCount, onChanged: (v) => r.innerCount = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(SizedBox(width: 110, child: TextFormField(initialValue: r.minorUnit, onChanged: (v) => r.minorUnit = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                      DataCell(_field(r.weight, (v) => r.weight = v)),
                      DataCell(_field(r.length, (v) => r.length = v)),
                      DataCell(_field(r.width, (v) => r.width = v)),
                      DataCell(_field(r.height, (v) => r.height = v)),
                    ])).toList(),
                  ))),
                )),
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
      final loaded=< _ImportRow >[];
      for(final row in sheet.rows.skip(1)){
        final id=cell(row,0);if(id.isEmpty)continue;final imagePath=cell(row,1);
        loaded.add(_ImportRow(id:id,imageUrl:cell(row,2),name:cell(row,3),kind:cell(row,4).isEmpty?'صنف':cell(row,4),codeMode:cell(row,5).isEmpty?'جديد':cell(row,5),code:cell(row,6),category:cell(row,7),subcategory:cell(row,8),majorUnit:cell(row,9),innerCount:cell(row,10),minorUnit:cell(row,11),weight:cell(row,12),length:cell(row,13),width:cell(row,14),height:cell(row,15),bytes:files[imagePath],selected:true));
      }
      setState(() { _rows=loaded; _status='تم فتح ${loaded.length} صفًا. التعديلات محلية ولن تُحفظ في قاعدة البيانات.'; });
    }catch(e){setState(()=>_status='تعذر فتح ZIP: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _exportZip()async{
    setState(()=>_busy=true);
    try{
      final selected=_rows.where((r)=>r.selected).toList(); if(selected.isEmpty) throw Exception('حدد صفًا واحدًا على الأقل للتصدير'); final archive=Archive();final book=Excel.createExcel();final sheet=book['بيانات الأصناف'];const headers=['id','image_file','image_url','name_ar','record_type','code_mode','item_code','category','subcategory','major_unit','inner_count','minor_unit','weight','length','width','height'];sheet.appendRow(headers.map((h)=>TextCellValue(h)).toList());
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
            : Scrollbar(thumbVisibility: true, interactive: true, child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Scrollbar(thumbVisibility: true, interactive: true, child: SingleChildScrollView(child: DataTable(
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
                      Checkbox(
                        shape: const CircleBorder(),
                        visualDensity: VisualDensity.compact,
                        value: _rows.isNotEmpty && _rows.every((r) => r.selected),
                        onChanged: (v) => setState(() {
                          _all = v ?? false;
                          for (final r in _rows) { r.selected = _all; }
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
                    DataColumn(label: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('النوع'),
                      Checkbox(
                        shape: const CircleBorder(),
                        visualDensity: VisualDensity.compact,
                        value: _rows.isNotEmpty && _rows.every((r) => r.kind == 'صنف'),
                        onChanged: (v) { if (v == true) setState(() { for (final r in _rows) { r.kind = 'صنف'; } }); },
                      ),
                      const Text('صنف', style: TextStyle(fontSize: 11)),
                      Checkbox(
                        shape: const CircleBorder(),
                        visualDensity: VisualDensity.compact,
                        value: _rows.isNotEmpty && _rows.every((r) => r.kind == 'فئة'),
                        onChanged: (v) { if (v == true) setState(() { for (final r in _rows) { r.kind = 'فئة'; } }); },
                      ),
                      const Text('فئة', style: TextStyle(fontSize: 11)),
                    ])),
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
                    DataCell(GestureDetector(onTap: () => _preview(r), child: SizedBox(width: 52, height: 48, child: r.bytes != null ? Image.memory(r.bytes!, fit: BoxFit.contain) : Image.network(r.imageUrl, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))))),
                    DataCell(_kindCell(r, () => setState(() {}))),
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
                ))),
              )),
        ),
      ]),
    );
  }
  Widget _field(String v,ValueChanged<String> c)=>SizedBox(width:100,child:TextFormField(initialValue:v,onChanged:c,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())));
}
