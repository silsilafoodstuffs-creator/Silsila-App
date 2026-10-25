import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class _ImportRow {
  _ImportRow({required this.id, required this.imageUrl, this.bytes, this.name = '', this.kind = 'صنف', this.category = '', this.subcategory = '', this.majorUnit = '', this.innerCount = '', this.minorUnit = '', this.weight = '', this.length = '', this.width = '', this.height = '', this.selected = true});
  final String id;
  String imageUrl, name, kind, category, subcategory, majorUnit, innerCount, minorUnit, weight, length, width, height;
  Uint8List? bytes;
  bool selected;
  Map<String,String> toMap() => {'id':id,'image_file':'images/$id.jpg','image_url':imageUrl,'name_ar':name,'record_type':kind,'category':category,'subcategory':subcategory,'major_unit':majorUnit,'inner_count':innerCount,'minor_unit':minorUnit,'weight':weight,'length':length,'width':width,'height':height};
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
  static const _headers = ['id','image_file','image_url','name_ar','record_type','category','subcategory','major_unit','inner_count','minor_unit','weight','length','width','height'];
  @override void dispose(){_url.dispose();super.dispose();}
  Future<void> _crawl() async {
    final raw = _url.text.trim();
    final uri = Uri.tryParse(raw);
    if(uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) { setState(()=>_status='أدخل رابطًا صحيحًا يبدأ بـ https:// أو http://'); return; }
    setState((){_busy=true;_status='جاري استكشاف الموقع والصفحات الداخلية...';_rows.clear();});
    final origin = '${uri.scheme}://${uri.host}';
    final queue=<Uri>[uri], visited=<String>{}, images=<String>{};
    final found = <String>[];
    try {
      while(queue.isNotEmpty && visited.length<80 && images.length<1500) {
        final page=queue.removeAt(0);
        if(!visited.add(page.toString())) continue;
        try {
          final response=await http.get(page,headers:{'User-Agent':'Mozilla/5.0 SilsilaCatalogImporter/1.0'}).timeout(const Duration(seconds:12));
          if(response.statusCode<200||response.statusCode>=400) continue;
          final html=utf8.decode(response.bodyBytes,allowMalformed:true);
          final imgReg=RegExp(r'''<img\b[^>]*(?:src|data-src|data-lazy-src|srcset)\s*=\s*["']([^"']+)["'][^>]*>''',caseSensitive:false);
          for(final m in imgReg.allMatches(html)) {
            var value=m.group(1)?.split(',').first.trim().split(' ').first ?? '';
            if(value.isEmpty || value.startsWith('data:')) continue;
            final imageUri=page.resolve(value);
            if(imageUri.hasScheme && (imageUri.scheme=='http'||imageUri.scheme=='https') && images.add(imageUri.toString())) found.add(imageUri.toString());
          }
          final linkReg=RegExp(r'''<a\b[^>]*href\s*=\s*["']([^"']+)["']''',caseSensitive:false);
          for(final m in linkReg.allMatches(html)) {
            final href=m.group(1); if(href==null||href.startsWith('#')||href.startsWith('mailto:')||href.startsWith('javascript:')) continue;
            final next=page.resolve(href);
            if(next.host==uri.host && (next.scheme=='http'||next.scheme=='https') && !visited.contains(next.toString()) && queue.length<400) queue.add(next);
          }
        } catch (_) { /* Keep processing other pages when one is blocked. */ }
        if(mounted) setState(()=>_status='صفحات تمت زيارتها: ${visited.length} — صور مكتشفة: ${found.length}');
      }
      for(var i=0;i<found.length;i++){
        final imageUrl=found[i];
        final path=Uri.parse(imageUrl).path.toLowerCase();
        if(RegExp(r'(logo|icon|sprite|favicon|banner|avatar|header|footer)').hasMatch(path)) continue;
        final id='IMG${(i+1).toString().padLeft(5,'0')}';
        _rows.add(_ImportRow(id:id,imageUrl:imageUrl,name:_suggestName(path),selected:true));
      }
      if(mounted)setState(()=>_status='اكتمل الفحص: ${visited.length} صفحة، ${_rows.length} صورة مرشحة. قد تمنع بعض المواقع الوصول الآلي أو تحميل الصور.');
    } finally {if(mounted)setState(()=>_busy=false);}
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
      await FileSaver.instance.saveFile(name:'silsila_items_import',bytes:Uint8List.fromList(zipped),ext:'zip',mimeType:MimeType.zip);
      if(mounted)setState(()=>_status='تم إنشاء ملف ZIP للتنزيل. لم يتم حفظ أي بيانات أو صور في قاعدة البيانات.');
    }catch(e){if(mounted)setState(()=>_status='تعذر إنشاء الملف: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<Uint8List?> _fetchImage(String url) async {try{final r=await http.get(Uri.parse(url)).timeout(const Duration(seconds:15));if(r.statusCode==200&&r.bodyBytes.isNotEmpty)return r.bodyBytes;}catch(_){}return null;}
  String _extension(String url){final p=Uri.tryParse(url)?.path.toLowerCase()??'';for(final e in ['png','webp','gif','avif','jpeg']){if(p.endsWith('.$e'))return e;}return 'jpg';}
  void _preview(_ImportRow row){showDialog<void>(context:context,builder:(ctx)=>Dialog(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[const Expanded(child:Text('معاينة الصورة',style:TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),Flexible(child:InteractiveViewer(child:Image.network(row.imageUrl,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,size:80),fit:BoxFit.contain))),const SizedBox(height:8),Text(row.name)]))));}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Column(children:[
    Container(color:_purple,padding:const EdgeInsets.all(14),child:Row(children:[const Icon(Icons.inventory_2,color:Colors.white,size:28),const SizedBox(width:10),const Expanded(child:Text('استيراد بيانات اصناف',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold))),const Icon(Icons.link,color:Colors.white)])),
    Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Expanded(child:TextField(controller:_url,decoration:const InputDecoration(labelText:'رابط الموقع الأساسي',hintText:'https://example.com',border:OutlineInputBorder(),isDense:true))),const SizedBox(width:8),FilledButton.icon(onPressed:_busy?null:_crawl,icon:const Icon(Icons.travel_explore),label:const Text('استكشاف الموقع'))]),
      const SizedBox(height:8),Row(children:[Expanded(child:Text(_status,style:const TextStyle(fontSize:12))),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_orange,foregroundColor:Colors.black),onPressed:_busy?null:_downloadZip,icon:const Icon(Icons.folder_zip),label:const Text('إنشاء ZIP'))])
    ])),
    Expanded(child:_rows.isEmpty?const Center(child:Text('ستظهر الصور المكتشفة هنا بعد استكشاف الموقع.')):Scrollbar(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(columnSpacing:18,headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),columns:[
      DataColumn(label:Checkbox(value:_selectAll,onChanged:(v)=>setState((){_selectAll=v??false;for(final r in _rows){r.selected=_selectAll;}}))),
      const DataColumn(label:Text('الصورة')),const DataColumn(label:Text('الاسم العربي المقترح')),const DataColumn(label:Text('النوع')),const DataColumn(label:Text('الفئة الرئيسية')),const DataColumn(label:Text('الفئة الفرعية')),const DataColumn(label:Text('الوحدة الكبرى')),const DataColumn(label:Text('العدد الداخلي')),const DataColumn(label:Text('الوحدة الصغرى')),const DataColumn(label:Text('الوزن')),const DataColumn(label:Text('الطول')),const DataColumn(label:Text('العرض')),const DataColumn(label:Text('الارتفاع'))
    ],rows:_rows.map((r)=>DataRow(cells:[
      DataCell(Checkbox(value:r.selected,onChanged:(v)=>setState(()=>r.selected=v??false))),
      DataCell(GestureDetector(onTap:()=>_preview(r),child:SizedBox(width:52,height:48,child:Image.network(r.imageUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image))))),
      DataCell(SizedBox(width:190,child:TextFormField(initialValue:r.name,onChanged:(v)=>r.name=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
      DataCell(DropdownButton<String>(value:r.kind,items:const [DropdownMenuItem(value:'صنف',child:Text('صنف')),DropdownMenuItem(value:'فئة',child:Text('فئة'))],onChanged:(v)=>setState(()=>r.kind=v??'صنف'))),
      DataCell(SizedBox(width:130,child:TextFormField(initialValue:r.category,onChanged:(v)=>r.category=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
      DataCell(SizedBox(width:130,child:TextFormField(initialValue:r.subcategory,onChanged:(v)=>r.subcategory=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
      DataCell(SizedBox(width:110,child:TextFormField(initialValue:r.majorUnit,onChanged:(v)=>r.majorUnit=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
      DataCell(SizedBox(width:85,child:TextFormField(initialValue:r.innerCount,onChanged:(v)=>r.innerCount=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
      DataCell(SizedBox(width:110,child:TextFormField(initialValue:r.minorUnit,onChanged:(v)=>r.minorUnit=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
      DataCell(_field(r.weight,(v)=>r.weight=v)),DataCell(_field(r.length,(v)=>r.length=v)),DataCell(_field(r.width,(v)=>r.width=v)),DataCell(_field(r.height,(v)=>r.height=v))
    ])).toList())))),
  ]));
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
        loaded.add(_ImportRow(id:id,imageUrl:cell(row,2),name:cell(row,3),kind:cell(row,4).isEmpty?'صنف':cell(row,4),category:cell(row,5),subcategory:cell(row,6),majorUnit:cell(row,7),innerCount:cell(row,8),minorUnit:cell(row,9),weight:cell(row,10),length:cell(row,11),width:cell(row,12),height:cell(row,13),bytes:files[imagePath],selected:true));
      }
      setState(() { _rows=loaded; _status='تم فتح ${loaded.length} صفًا. التعديلات محلية ولن تُحفظ في قاعدة البيانات.'; });
    }catch(e){setState(()=>_status='تعذر فتح ZIP: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _exportZip()async{
    setState(()=>_busy=true);
    try{
      final selected=_rows.where((r)=>r.selected).toList(); if(selected.isEmpty) throw Exception('حدد صفًا واحدًا على الأقل للتصدير'); final archive=Archive();final book=Excel.createExcel();final sheet=book['بيانات الأصناف'];const headers=['id','image_file','image_url','name_ar','record_type','category','subcategory','major_unit','inner_count','minor_unit','weight','length','width','height'];sheet.appendRow(headers.map((h)=>TextCellValue(h)).toList());
      for(final r in selected){final imageFile=r.bytes==null?'':'images/${r.id}.${_ext(r.imageUrl)}';final m=r.toMap()..['image_file']=imageFile;sheet.appendRow(headers.map((h)=>TextCellValue(m[h]??'')).toList());if(r.bytes!=null)archive.addFile(ArchiveFile(imageFile,r.bytes!.length,r.bytes!));}
      final x=book.encode()!;archive.addFile(ArchiveFile('items.xlsx',x.length,x));final zipped=ZipEncoder().encode(archive)!;
      await FileSaver.instance.saveFile(name:'silsila_items_edited',bytes:Uint8List.fromList(zipped),ext:'zip',mimeType:MimeType.zip);
      setState(()=>_status='تم تصدير ZIP المعدل دون أي كتابة في قاعدة البيانات.');
    }catch(e){setState(()=>_status='فشل التصدير: $e');}finally{if(mounted)setState(()=>_busy=false);}
  }
  String _ext(String url){final p=Uri.tryParse(url)?.path.toLowerCase()??'';for(final e in ['png','webp','gif','avif','jpeg']){if(p.endsWith('.$e'))return e;}return 'jpg';}
  void _preview(_ImportRow r){showDialog<void>(context:context,builder:(c)=>Dialog(child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[Align(alignment:Alignment.centerRight,child:IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close))),Flexible(child:r.bytes!=null?InteractiveViewer(child:Image.memory(r.bytes!,fit:BoxFit.contain)):Image.network(r.imageUrl,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image))),Text(r.name)]))));}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Column(children:[
    Container(color:_purple,padding:const EdgeInsets.all(14),child:Row(children:[const Icon(Icons.download_for_offline,color:Colors.white,size:28),const SizedBox(width:10),const Expanded(child:Text('تنزيل بيانات أصناف',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold))),OutlinedButton.icon(onPressed:_busy?null:_openZip,icon:const Icon(Icons.folder_open,color:Colors.white),label:const Text('فتح ZIP',style:TextStyle(color:Colors.white)))])),
    Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:Text(_status,style:const TextStyle(fontSize:12))),FilledButton.icon(onPressed:_busy||_rows.isEmpty?null:_exportZip,icon:const Icon(Icons.folder_zip),label:const Text('تصدير ZIP المعدل'))])),
    Expanded(child:_rows.isEmpty?const Center(child:Text('افتح ملف ZIP لعرض البيانات وتعديلها.')):Scrollbar(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(columns:const [DataColumn(label:Checkbox(value:_all,onChanged:(v){setState((){_all=v??false;for(final r in _rows){r.selected=_all;}});})),DataColumn(label:Text('الصورة')),DataColumn(label:Text('الاسم العربي')),DataColumn(label:Text('النوع')),DataColumn(label:Text('الفئة الرئيسية')),DataColumn(label:Text('الفئة الفرعية')),DataColumn(label:Text('الوحدة الكبرى')),DataColumn(label:Text('العدد الداخلي')),DataColumn(label:Text('الوحدة الصغرى')),DataColumn(label:Text('الوزن')),DataColumn(label:Text('الطول')),DataColumn(label:Text('العرض')),DataColumn(label:Text('الارتفاع'))],rows:_rows.map((r)=>DataRow(cells:[DataCell(Checkbox(value:r.selected,onChanged:(v)=>setState(()=>r.selected=v??false))),DataCell(GestureDetector(onTap:()=>_preview(r),child:SizedBox(width:52,height:48,child:r.bytes!=null?Image.memory(r.bytes!,fit:BoxFit.contain):Image.network(r.imageUrl,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image))))),DataCell(SizedBox(width:170,child:TextFormField(initialValue:r.name,onChanged:(v)=>r.name=v,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),DataCell(DropdownButton<String>(value:r.kind,items:const [DropdownMenuItem(value:'صنف',child:Text('صنف')),DropdownMenuItem(value:'فئة',child:Text('فئة'))],onChanged:(v)=>setState(()=>r.kind=v??'صنف'))),DataCell(_field(r.category,(v)=>r.category=v)),DataCell(_field(r.subcategory,(v)=>r.subcategory=v)),DataCell(_field(r.majorUnit,(v)=>r.majorUnit=v)),DataCell(_field(r.innerCount,(v)=>r.innerCount=v)),DataCell(_field(r.minorUnit,(v)=>r.minorUnit=v)),DataCell(_field(r.weight,(v)=>r.weight=v)),DataCell(_field(r.length,(v)=>r.length=v)),DataCell(_field(r.width,(v)=>r.width=v)),DataCell(_field(r.height,(v)=>r.height=v))])).toList()))))
  ]));
  Widget _field(String v,ValueChanged<String> c)=>SizedBox(width:100,child:TextFormField(initialValue:v,onChanged:c,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())));
}
