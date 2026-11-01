import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

class ErpStocktakeScreen extends StatefulWidget {
  const ErpStocktakeScreen({super.key, required this.companyId, this.title = 'الجرد الفعلي للمخازن'});
  final String companyId;
  final String title;
  @override
  State<ErpStocktakeScreen> createState() => _ErpStocktakeScreenState();
}

class _ErpStocktakeScreenState extends State<ErpStocktakeScreen> {
  final db=Supabase.instance.client;
  final notes=TextEditingController();
  final counts=<String,TextEditingController>{};
  List<Map<String,dynamic>> warehouses=[],docs=[],items=[],lines=[],employees=[],expenses=[],units=[];
  String? warehouseId,docId,targetId;
  String countMode='detailed',targetType='employee',sourceMode='manual';
  bool loading=false,saving=false,editing=false;
  String? error,message;
  bool get _manualSettlementScreen => widget.title.contains('التسوية');
  String s(dynamic v)=>(v??'').toString();
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse(s(v))??0;
  String warehouseName(dynamic id){final a=warehouses.where((w)=>s(w['id'])==s(id));return a.isEmpty?s(id):s(a.first['warehouse_code'])+' — '+s(a.first['warehouse_name']);}
  String itemName(dynamic id){final a=items.where((w)=>s(w['id'])==s(id));return a.isEmpty?s(id):s(a.first['item_code'])+' — '+s(a.first['item_name']);}
  String targetName(Map<String,dynamic> r)=>targetType=='employee'?s(r['employee_code'])+' — '+s(r['full_name']):s(r['item_code'])+' — '+s(r['name_ar']);
  @override void initState(){super.initState();load();}
  @override void dispose(){notes.dispose();for(final c in counts.values){c.dispose();}super.dispose();}

  Future<void> load() async {
    if(widget.companyId.isEmpty){setState(()=>error='لا توجد شركة محددة.');return;}
    setState(()=>loading=true);
    try{
      final v=await Future.wait<dynamic>([
        db.from('erp_warehouses').select('id,warehouse_code,warehouse_name,is_active').eq('company_id',widget.companyId).eq('is_active',true).order('warehouse_code'),
        db.from('erp_stocktakes').select('id,warehouse_id,status,count_mode,valuation_basis,source,created_at,notes').eq('company_id',widget.companyId).order('created_at',ascending:false).limit(100),
        db.from('erp_items').select('id,item_code,item_name').eq('company_id',widget.companyId),
        db.from('erp_item_units').select('id,unit_name,conversion_factor').eq('company_id',widget.companyId).eq('is_active',true),
        db.from('erp_employees').select('id,employee_code,full_name').eq('company_id',widget.companyId).eq('is_active',true).order('employee_code'),
        db.from('erp_stocktake_expense_items').select('id,item_code,name_ar').eq('company_id',widget.companyId).eq('is_active',true).order('item_code'),
      ]);
      if(!mounted)return;
      setState(() { warehouses=List<Map<String,dynamic>>.from(v[0]); docs=List<Map<String,dynamic>>.from(v[1]); items=List<Map<String,dynamic>>.from(v[2]); units=List<Map<String,dynamic>>.from(v[3]); employees=List<Map<String,dynamic>>.from(v[4]); expenses=List<Map<String,dynamic>>.from(v[5]); warehouseId ??= warehouses.isEmpty ? null : s(warehouses.first['id']); loading=false; error=null; });
      if(docId!=null)await loadLines(docId!);
    }catch(e){if(mounted)setState(() { loading=false; error='تعذر تحميل بيانات الجرد: '+e.toString(); });}
  }

  Future<void> loadLines(String id) async {
    try{
      final raw=await db.from('erp_stocktake_lines').select('id,item_id,warehouse_id,available_snapshot,reserved_snapshot,physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value').eq('stocktake_id',id).order('created_at');
      for(final c in counts.values){c.dispose();} counts.clear();
      final data=List<Map<String,dynamic>>.from(raw);
      for(final l in data){final f=n(l['conversion_factor'])<=0?1:n(l['conversion_factor']);counts[s(l['id'])]=TextEditingController(text:(n(l['counted_quantity'])/f).toStringAsFixed(3).replaceFirst(RegExp(r'\.000$'),''));}
      if(mounted)setState(()=>lines=data);
    }catch(e){if(mounted)setState(()=>error='تعذر تحميل تفاصيل الجرد: '+e.toString());}
  }

  Future<void> createDoc() async {
    if(warehouseId==null){setState(()=>error='اختر المخزن أولاً.');return;}
    setState(()=>saving=true);
    try{
      final id = _manualSettlementScreen && sourceMode=='manual'
        ? await db.rpc('erp_create_manual_stock_adjustment',params:{'p_company_id':widget.companyId,'p_warehouse_id':warehouseId,'p_notes':notes.text.trim().isEmpty?null:notes.text.trim()})
        : await db.rpc('erp_create_physical_stocktake',params:{'p_company_id':widget.companyId,'p_warehouse_id':warehouseId,'p_count_mode':countMode,'p_valuation_basis':null,'p_notes':notes.text.trim().isEmpty?null:notes.text.trim()});
      docId=id.toString();notes.clear();await load();await loadLines(docId!);if(mounted)setState(()=>editing=true);
      if(mounted)setState(() { saving=false; message=sourceMode=='manual'&&_manualSettlementScreen?'تم إنشاء تسوية يدوية بلقطة رصيد مرجعية.':'تم إنشاء محضر الجرد ولقطة الأرصدة.'; });
    }catch(e){if(mounted)setState(() { saving=false; error='تعذر إنشاء محضر الجرد: '+e.toString(); });}
  }

  double countedBase(Map<String,dynamic> l){final f=n(l['conversion_factor'])<=0?1:n(l['conversion_factor']);return (n(counts[s(l['id'])]?.text)*f);}
  double get shortage=>lines.fold<double>(0,(sum,l){final d=countedBase(l)-n(l['physical_snapshot']);return sum+(d<0?d.abs()*n(l['valuation_price']):0);});
  bool get isDraft=>docs.any((d)=>s(d['id'])==docId&&s(d['status'])=='draft');

  Future<void> saveDraft() async {
    if(!isDraft){setState(()=>error='المحضر ليس مسودة قابلة للتعديل.');return;}
    setState(() { saving=true; error=null; message=null; });
    try{
      final payload=lines.map((l)=>{'line_id':s(l['id']),'counted_quantity':countedBase(l)}).toList();
      if(payload.any((r)=>(r['counted_quantity'] as double)<0))throw ArgumentError('لا يمكن إدخال كمية سالبة.');
      await db.rpc('erp_save_physical_stocktake_counts',params:{'p_stocktake_id':docId,'p_counts':payload});
      await loadLines(docId!);if(mounted)setState(() {editing=false;message='تم حفظ المسودة دون تغيير الأرصدة المخزنية.';});
    }catch(e){if(mounted)setState(()=>error='تعذر حفظ المسودة: '+e.toString());}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> postDoc() async {
    if(!isDraft)return;
    await saveDraft();if(!mounted||error!=null)return;
    if(shortage>0&&targetId==null){setState(()=>error='توجد قيمة عجز؛ اختر الموظف أو بند الصرف أولاً.');return;}
    setState(()=>saving=true);
    try{
      final result=await db.rpc('erp_post_physical_stocktake',params:{'p_stocktake_id':docId,'p_target_type':shortage>0?targetType:null,'p_target_id':shortage>0?targetId:null});
      if(mounted)setState(()=>message='تم ترحيل الجرد وتسجيل حركات التسوية. '+(shortage>0&&targetType=='employee'?' تم ربط العجز بعنصر المرتب النظامي «عجز جرد». ':' ')+result.toString());
      await load();await loadLines(docId!);
    }catch(e){if(mounted)setState(()=>error='تعذر ترحيل الجرد: '+e.toString());}
    finally{if(mounted)setState(()=>saving=false);}
  }


  void editDraft(){if(!isDraft)return;setState(() {editing=true;message='تم تفعيل تعديل كميات الجرد. احفظ المسودة قبل الترحيل.';});}
  void previewDraft(){
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('معاينة محضر الجرد'),
      content:SizedBox(width:560,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('عدد الأصناف: ${lines.length}'),
        Text('قيمة العجز: ${shortage.toStringAsFixed(2)} ج.م'),
        ...lines.take(80).map((l)=>ListTile(dense:true,title:Text(itemName(l['item_id'])),subtitle:Text('رصيد النظام: ${n(l['physical_snapshot']).toStringAsFixed(3)} • الجرد: ${countedBase(l).toStringAsFixed(3)}'))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
    ));
  }
  Future<void> exportPdf({required bool share}) async {
    if(lines.isEmpty){setState(()=>message='لا توجد بنود لتصديرها.');return;}
    try{
      final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      final doc=pw.Document();
      doc.addPage(pw.MultiPage(theme:pw.ThemeData.withFont(base:font,bold:font),build:(_)=>[
        pw.Text('Silsila • ${widget.title}',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:8),
        pw.TableHelper.fromTextArray(headers:const ['م','كود الصنف','الصنف','رصيد النظام','الجرد','الفرق','القيمة'],data:lines.asMap().entries.map((e){final l=e.value;final item=items.firstWhere((x)=>s(x['id'])==s(l['item_id']),orElse:()=>{});final d=countedBase(l)-n(l['physical_snapshot']);return [e.key+1,s(item['item_code']),s(item['item_name']),n(l['physical_snapshot']).toStringAsFixed(3),countedBase(l).toStringAsFixed(3),d.toStringAsFixed(3),(d.abs()*n(l['valuation_price'])).toStringAsFixed(2)];}).toList()),
      ]));
      final bytes=await doc.save();
      if(share){await Printing.sharePdf(bytes:bytes,filename:'Silsila-Stocktake.pdf');}
      else{await Printing.layoutPdf(onLayout:(_)=>Future.value(bytes));}
    }catch(e){if(mounted)setState(()=>error='تعذر إنشاء PDF: $e');}
  }
  Future<void> exportExcel() async {
    if(lines.isEmpty){setState(()=>message='لا توجد بنود لتصديرها.');return;}
    try{
      final book=excel.Excel.createExcel();final sheet=book['الجرد'];
      sheet.appendRow([excel.TextCellValue('م'),excel.TextCellValue('كود الصنف'),excel.TextCellValue('اسم الصنف'),excel.TextCellValue('رصيد النظام'),excel.TextCellValue('كمية الجرد'),excel.TextCellValue('الفرق'),excel.TextCellValue('قيمة الفرق')]);
      for(var i=0;i<lines.length;i++){final l=lines[i];final item=items.firstWhere((x)=>s(x['id'])==s(l['item_id']),orElse:()=>{});final d=countedBase(l)-n(l['physical_snapshot']);sheet.appendRow([excel.IntCellValue(i+1),excel.TextCellValue(s(item['item_code'])),excel.TextCellValue(s(item['item_name'])),excel.DoubleCellValue(n(l['physical_snapshot'])),excel.DoubleCellValue(countedBase(l)),excel.DoubleCellValue(d),excel.DoubleCellValue(d.abs()*n(l['valuation_price']))]);}
      final bytes=book.encode();if(bytes==null)throw StateError('تعذر تجهيز ملف Excel.');
      await FilePicker.platform.saveFile(dialogTitle:'تصدير محضر الجرد',fileName:'Silsila-Stocktake.xlsx',bytes:Uint8List.fromList(bytes));
    }catch(e){if(mounted)setState(()=>error='تعذر تصدير Excel: $e');}
  }

  @override Widget build(BuildContext context){
    final doc=docs.where((d)=>s(d['id'])==docId);final current=doc.isEmpty?null:doc.first;
    final targets=targetType=='employee'?employees:expenses;
    return Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Card(color:const Color(0xFF3E007D),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(widget.title,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
        const Text('لقطة أرصدة، إدخال الكميات الفعلية، مراجعة الفروقات ثم الترحيل.',style:TextStyle(color:Colors.white70)),
        const SizedBox(height:8),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh,onPressed:loading?null:load),
          ErpQuickTaskButton(label:'إضافة',icon:Icons.add,onPressed:saving?null:createDoc),
          ErpQuickTaskButton(label:'حفظ',icon:Icons.save,onPressed:saving||!isDraft?null:saveDraft),
          ErpQuickTaskButton(label:'تعديل',icon:Icons.edit,onPressed:saving||!isDraft?null:editDraft),
          ErpQuickTaskButton(label:'حذف',icon:Icons.delete,onPressed:null),
          ErpQuickTaskButton(label:'معاينة',icon:Icons.visibility,onPressed:previewDraft),
          ErpQuickTaskButton(label:'طباعة',icon:Icons.print,onPressed:()=>exportPdf(share:false)),
          ErpQuickTaskButton(label:'Excel',icon:Icons.file_download,onPressed:exportExcel),
          ErpQuickTaskButton(label:'PDF',icon:Icons.picture_as_pdf,onPressed:()=>exportPdf(share:true)),
        ])),
      ]))),
      if(loading||saving)const LinearProgressIndicator(),
      if(error!=null)notice(error!,Colors.red),if(message!=null)notice(message!,Colors.green),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('إنشاء محضر جرد جديد',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
        DropdownButtonFormField<String>(value:warehouseId,isExpanded:true,decoration:const InputDecoration(labelText:'المخزن'),items:warehouses.map((w)=>DropdownMenuItem(value:s(w['id']),child:Text(warehouseName(w['id'])))).toList(),onChanged:(v)=>setState(()=>warehouseId=v)),
        if(_manualSettlementScreen)DropdownButtonFormField<String>(value:sourceMode,decoration:const InputDecoration(labelText:'مصدر التسوية (للمعاينة والاختيار فقط)'),items:const [DropdownMenuItem(value:'manual',child:Text('يدوي')),DropdownMenuItem(value:'stocktake',child:Text('من جرد المخزون'))],onChanged:(v)=>setState(()=>sourceMode=v??'manual')),
        if(!_manualSettlementScreen || sourceMode=='stocktake')DropdownButtonFormField<String>(value:countMode,decoration:const InputDecoration(labelText:'وضع الجرد'),items:const [DropdownMenuItem(value:'default',child:Text('الوحدة الافتراضية للمخزن')),DropdownMenuItem(value:'detailed',child:Text('جرد تفصيلي'))],onChanged:(v)=>setState(()=>countMode=v??countMode)),
        TextField(controller:notes,decoration:const InputDecoration(labelText:'ملاحظات المحضر')),
        const SizedBox(height:8),const Text('المحاضر السابقة',style:TextStyle(fontWeight:FontWeight.w800)),
        DropdownButtonFormField<String>(value:docId,isExpanded:true,decoration:const InputDecoration(labelText:'اختر محضراً'),items:docs.map((d)=>DropdownMenuItem(value:s(d['id']),child:Text(warehouseName(d['warehouse_id'])+' • '+s(d['status'])+' • '+s(d['created_at']).split('T').first,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)async{setState(()=>{docId=v;final selected=docs.where((d)=>s(d['id'])==s(v));if(selected.isNotEmpty)sourceMode=s(selected.first['source']).isEmpty?'stocktake':s(selected.first['source']);});if(v!=null)await loadLines(v);}),
      ]))),
      if(current!=null)...[
        Padding(padding:const EdgeInsets.all(8),child:Text('تفاصيل المحضر • '+warehouseName(current['warehouse_id'])+' • '+s(current['status']),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17))),
        if(isDraft && shortage>0)Wrap(spacing:8,runSpacing:6,children:[
          SegmentedButton<String>(segments:const [ButtonSegment(value:'employee',label:Text('موظف')),ButtonSegment(value:'expense',label:Text('بند صرف'))],selected:{targetType},onSelectionChanged:(v)=>setState(() { targetType=v.first; targetId=null; })),
          SizedBox(width:300,child:DropdownButtonFormField<String>(value:targetId,isExpanded:true,decoration:const InputDecoration(labelText:'توجيه قيمة العجز'),items:targets.map((r)=>DropdownMenuItem(value:s(r['id']),child:Text(targetName(r),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>targetId=v))),
          Text('قيمة العجز: '+shortage.toStringAsFixed(2)+' ج.م',style:const TextStyle(fontWeight:FontWeight.w800,color:Colors.red)),
        ]) else if(isDraft) Padding(padding:const EdgeInsets.only(bottom:8),child:Text('لا توجد قيمة عجز حالياً؛ توجيه العجز غير مطلوب. قيمة العجز: '+shortage.toStringAsFixed(2)+' ج.م',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w700))),
        if(isDraft)Align(alignment:AlignmentDirectional.centerStart,child:FilledButton.icon(onPressed:saving?null:postDoc,icon:const Icon(Icons.verified_outlined),label:const Text('ترحيل الجرد وتحديث الأرصدة'))),
        Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(columns:const [
          DataColumn(label:Text('م')),DataColumn(label:Text('كود الصنف')),DataColumn(label:Text('اسم الصنف')),
          DataColumn(label:Text('رصيد متاح')),DataColumn(label:Text('رصيد حجز')),DataColumn(label:Text('رصيد فعلي')),DataColumn(label:Text('وحدة الجرد')),
          DataColumn(label:Text('كمية الجرد')),DataColumn(label:Text('الفرق')),DataColumn(label:Text('نوع الفرق')),DataColumn(label:Text('قيمة الفرق')),
        ],rows:List.generate(lines.length,(i){
          final l=lines[i],f=n(l['conversion_factor'])<=0?1:n(l['conversion_factor']),diff=countedBase(l)-n(l['physical_snapshot']);
          final item=items.where((x)=>s(x['id'])==s(l['item_id']));final it=item.isEmpty?<String,dynamic>{}:item.first;final unit=units.where((x)=>s(x['id'])==s(l['unit_id']));
          return DataRow(cells:[
            DataCell(Text((i+1).toString())),DataCell(Text(s(it['item_code']))),DataCell(Text(s(it['item_name']))),
            DataCell(Text((n(l['available_snapshot'])/f).toStringAsFixed(3))),DataCell(Text((n(l['reserved_snapshot'])/f).toStringAsFixed(3))),
            DataCell(Text((n(l['physical_snapshot'])/f).toStringAsFixed(3))),
            DataCell(Text(unit.isEmpty?'—':s(unit.first['unit_name']))),
            DataCell(SizedBox(width:100,child:TextField(controller:counts[s(l['id'])],enabled:isDraft&&editing,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState((){}),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
            DataCell(Text((diff/f).toStringAsFixed(3))),
            DataCell(Text(diff<0?'عجز':diff>0?'زيادة':'مطابق',style:TextStyle(fontWeight:FontWeight.w800,color:diff<0?Colors.red:diff>0?Colors.green:Colors.black54))),
            DataCell(Text((diff.abs()*n(l['valuation_price'])).toStringAsFixed(2))),
          ]);
        })))),
      ]else const Expanded(child:Center(child:Text('اختر محضراً أو أنشئ محضراً جديداً لعرض التفاصيل.'))),
    ]));
  }

  Widget notice(String t,Color c)=>Container(margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:c.withValues(alpha:.09),borderRadius:BorderRadius.circular(9)),child:Text(t,style:TextStyle(color:c)));
}
