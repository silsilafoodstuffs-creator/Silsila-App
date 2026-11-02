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
  final increaseCounts=<String,TextEditingController>{};
  final shortageCounts=<String,TextEditingController>{};
  List<Map<String,dynamic>> branches=[],warehouses=[],docs=[],items=[],lines=[],employees=[],expenses=[],units=[];
  String? branchId,baseWarehouseId,warehouseId,docId,targetId;
  String countMode='default',targetType='employee',sourceMode='manual';
  bool loading=false,saving=false,editing=false;
  String? error,message;
  bool get _manualSettlementScreen => widget.title.contains('التسوية');
  bool get _manualCurrentDocument => docs.any((d)=>s(d['id'])==docId&&s(d['source'])=='manual');
  String s(dynamic v)=>(v??'').toString();
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse(s(v))??0;
  String warehouseName(dynamic id){final a=warehouses.where((w)=>s(w['id'])==s(id));return a.isEmpty?s(id):s(a.first['warehouse_code'])+' — '+s(a.first['warehouse_name']);}
  String itemName(dynamic id){final a=items.where((w)=>s(w['id'])==s(id));return a.isEmpty?s(id):s(a.first['item_code'])+' — '+s(a.first['item_name']);}
  String targetName(Map<String,dynamic> r)=>targetType=='employee'?s(r['employee_code'])+' — '+s(r['full_name']):s(r['item_code'])+' — '+s(r['name_ar']);
  @override void initState(){super.initState();load();}
  @override void dispose(){notes.dispose();for(final c in counts.values){c.dispose();}for(final c in increaseCounts.values){c.dispose();}for(final c in shortageCounts.values){c.dispose();}super.dispose();}

  Future<void> load() async {
    if(widget.companyId.isEmpty){setState(()=>error='لا توجد شركة محددة.');return;}
    setState(()=>loading=true);
    try{
      final v=await Future.wait<dynamic>([
        db.from('erp_branches').select('id,branch_code,branch_name,is_active').eq('company_id',widget.companyId).eq('is_active',true).order('branch_code'),
        db.from('erp_warehouses').select('id,warehouse_code,warehouse_name,is_active,branch_id,parent_warehouse_id').eq('company_id',widget.companyId).eq('is_active',true).order('warehouse_code'),
        db.from('erp_stocktakes').select('id,warehouse_id,status,count_mode,valuation_basis,source,created_at,notes').eq('company_id',widget.companyId).order('created_at',ascending:false).limit(100),
        db.from('erp_items').select('id,item_code,item_name').eq('company_id',widget.companyId),
        db.from('erp_item_units').select('id,item_id,unit_name,unit_level,conversion_factor,is_active,is_selectable').eq('company_id',widget.companyId).eq('is_active',true).eq('is_selectable',true),
        db.from('erp_employees').select('id,employee_code,full_name').eq('company_id',widget.companyId).eq('is_active',true).order('employee_code'),
        db.from('erp_stocktake_expense_items').select('id,item_code,name_ar').eq('company_id',widget.companyId).eq('is_active',true).order('item_code'),
      ]);
      if(!mounted)return;
      setState(() { branches=List<Map<String,dynamic>>.from(v[0]); warehouses=List<Map<String,dynamic>>.from(v[1]); docs=List<Map<String,dynamic>>.from(v[2]); items=List<Map<String,dynamic>>.from(v[3]); units=List<Map<String,dynamic>>.from(v[4]); employees=List<Map<String,dynamic>>.from(v[5]); expenses=List<Map<String,dynamic>>.from(v[6]); branchId ??= branches.isEmpty ? null : s(branches.first['id']); final mains=warehouses.where((w)=>s(w['parent_warehouse_id']).isEmpty && (branchId==null || s(w['branch_id'])==branchId)).toList(); baseWarehouseId ??= mains.isEmpty ? null : s(mains.first['id']); warehouseId ??= baseWarehouseId ?? (warehouses.isEmpty ? null : s(warehouses.first['id'])); loading=false; error=null; });
      if(docId!=null)await loadLines(docId!);
    }catch(e){if(mounted)setState(() { loading=false; error='تعذر تحميل بيانات الجرد: '+e.toString(); });}
  }

  Future<void> loadLines(String id) async {
    try{
      final raw=await db.from('erp_stocktake_lines').select('id,item_id,warehouse_id,available_snapshot,reserved_snapshot,physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value').eq('stocktake_id',id).order('created_at');
      for(final c in counts.values){c.dispose();} counts.clear();
      for(final c in increaseCounts.values){c.dispose();} increaseCounts.clear();
      for(final c in shortageCounts.values){c.dispose();} shortageCounts.clear();
      final data=List<Map<String,dynamic>>.from(raw);
      final isManualDoc=docs.any((d)=>s(d['id'])==id&&s(d['source'])=='manual');
      for(final l in data){
        final lineId=s(l['id']);
        final factor=n(l['conversion_factor'])<=0?1:n(l['conversion_factor']);
        final delta=n(l['counted_quantity'])-n(l['physical_snapshot']);
        if(isManualDoc){
          increaseCounts[lineId]=TextEditingController(text:(delta>0?delta/factor:0).toStringAsFixed(3));
          shortageCounts[lineId]=TextEditingController(text:(delta<0?-delta/factor:0).toStringAsFixed(3));
        }else{
          counts[lineId]=TextEditingController(text:(n(l['counted_quantity'])/factor).toStringAsFixed(3));
        }
      }
      if(mounted)setState(()=>lines=data);
    }catch(e){if(mounted)setState(()=>error='تعذر تحميل تفاصيل الجرد: '+e.toString());}
  }

  Future<void> createDoc() async {
    if(_manualSettlementScreen && sourceMode!='manual'){setState(()=>message='مصدر «من جرد المخزون» للمعاينة فقط؛ اختر محضراً سابقاً من القائمة.');return;}
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


  Map<String,dynamic> unitBreakdown(dynamic itemId,double baseQuantity){
    final list=units.where((u)=>s(u['item_id'])==s(itemId)&&u['is_active']==true&&u['is_selectable']==true).toList()
      ..sort((a,b)=>n(b['conversion_factor']).compareTo(n(a['conversion_factor'])));
    final larger=list.where((u)=>n(u['conversion_factor'])>1).toList();
    final base=list.where((u)=>n(u['conversion_factor'])<=1).toList();
    final major=larger.isNotEmpty?larger.first:null;
    final middle=larger.length>1?larger[1]:null;
    final baseUnit=base.isNotEmpty?base.last:(list.isNotEmpty?list.last:null);
    final majorFactor=major==null?1:n(major['conversion_factor']);
    final middleFactor=middle==null?1:n(middle['conversion_factor']);
    final majorQty=major==null?0:(baseQuantity/majorFactor).floorToDouble();
    final afterMajor=major==null?baseQuantity:baseQuantity-majorQty*majorFactor;
    final middleQty=middle==null?0:(afterMajor/middleFactor).floorToDouble();
    final minorQty=middle==null?afterMajor:afterMajor-middleQty*middleFactor;
    return {'majorQty':majorQty,'majorUnit':major==null?'—':s(major['unit_name']),
      'middleQty':middleQty,'middleUnit':middle==null?'—':s(middle['unit_name']),
      'minorQty':minorQty,'minorUnit':baseUnit==null?'—':s(baseUnit['unit_name'])};
  }

  double countedBase(Map<String,dynamic> l){
    final id=s(l['id']);
    final factor=n(l['conversion_factor'])<=0?1:n(l['conversion_factor']);
    if(_manualCurrentDocument){
      final increase=n(increaseCounts[id]?.text);
      final shortage=n(shortageCounts[id]?.text);
      return n(l['physical_snapshot'])+(increase-shortage)*factor;
    }
    return n(counts[id]?.text)*factor;
  }
  double get shortage=>lines.fold<double>(0,(sum,l){final d=countedBase(l)-n(l['physical_snapshot']);return sum+(d<0?d.abs()*n(l['valuation_price']):0);});
  bool get canDeleteManualDraft=>_manualSettlementScreen&&isDraft&&docs.any((d)=>s(d['id'])==docId&&s(d['source'])=='manual');
  bool get canEditDraft {
    if(!isDraft)return false;
    final current=docs.where((d)=>s(d['id'])==docId);
    return !(_manualSettlementScreen&&current.isNotEmpty&&s(current.first['source'])=='stocktake');
  }
  bool get canEditLines {
    if(!canEditDraft||!editing)return false;
    final current=docs.where((d)=>s(d['id'])==docId);
    if(_manualSettlementScreen&&current.isNotEmpty&&s(current.first['source'])=='stocktake')return false;
    return true;
  }

  bool get isDraft {
    final matches=docs.where((d)=>s(d['id'])==docId);
    if(matches.isEmpty||s(matches.first['status'])!='draft')return false;
    return _manualSettlementScreen ? ['manual','stocktake'].contains(s(matches.first['source'])) : s(matches.first['source'])=='stocktake';
  }

  Future<void> saveDraft() async {
    if(!isDraft){setState(()=>error='المحضر ليس مسودة قابلة للتعديل.');return;}
    setState(() { saving=true; error=null; message=null; });
    try{
      if(_manualCurrentDocument&&lines.any((l)=>n(increaseCounts[s(l['id'])]?.text)<0||n(shortageCounts[s(l['id'])]?.text)<0))throw ArgumentError('حقلا الزيادة والعجز لا يقبلان قيمة سالبة.');
      if(_manualCurrentDocument&&lines.any((l)=>n(increaseCounts[s(l['id'])]?.text)>0&&n(shortageCounts[s(l['id'])]?.text)>0))throw ArgumentError('اختر زيادة أو عجزًا للصنف الواحد؛ لا يمكن إدخالهما معًا.');
      final payload=lines.map((l)=>{'line_id':s(l['id']),'counted_quantity':countedBase(l)}).toList();
      if(payload.any((r)=>(r['counted_quantity'] as double)<0))throw ArgumentError('لا يمكن أن يتجاوز عجز التسوية رصيد الصنف الحالي.');
      await db.rpc('erp_save_physical_stocktake_counts',params:{'p_stocktake_id':docId,'p_counts':payload});
      await loadLines(docId!);if(mounted)setState(() {editing=false;message='تم حفظ المسودة دون تغيير الأرصدة المخزنية.';});
    }catch(e){if(mounted)setState(()=>error='تعذر حفظ المسودة: '+e.toString());}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> deleteManualDraft() async {
    final selected=docs.where((d)=>s(d['id'])==docId);
    if(!_manualSettlementScreen||selected.isEmpty||s(selected.first['source'])!='manual'||s(selected.first['status'])!='draft')return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('إلغاء التسوية اليدوية'),
      content:const Text('هل تريد حذف مسودة التسوية اليدوية؟ لا يمكن حذف تسوية مصدرها جرد فعلي.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('نعم، احذف المسودة'))],
    ));
    if(yes!=true)return;
    setState(()=>saving=true);
    try{
      await db.from('erp_stocktakes').delete().eq('id',docId!).eq('company_id',widget.companyId).eq('source','manual').eq('status','draft');
      docId=null;lines=[];for(final c in counts.values){c.dispose();}counts.clear();for(final c in increaseCounts.values){c.dispose();}increaseCounts.clear();for(final c in shortageCounts.values){c.dispose();}shortageCounts.clear();
      await load();
      if(mounted)setState(()=>message='تم إلغاء مسودة التسوية اليدوية.');
    }catch(e){if(mounted)setState(()=>error='تعذر إلغاء المسودة: '+e.toString());}
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


  void editDraft(){if(!canEditDraft)return;setState(() {editing=true;message='تم تفعيل تعديل كميات الجرد. احفظ المسودة قبل الترحيل.';});}
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

  void startNewDocument(){
    for(final controller in counts.values){controller.dispose();}
    counts.clear();
    for(final controller in increaseCounts.values){controller.dispose();}
    increaseCounts.clear();
    for(final controller in shortageCounts.values){controller.dispose();}
    shortageCounts.clear();
    setState(() {
      docId=null; lines=[]; editing=false; countMode='default'; targetId=null; targetType='employee';
      sourceMode=_manualSettlementScreen?'manual':'stocktake';
      message='اختر مصدر المستند والمخزن ثم اضغط إضافة.';
      error=null;
    });
  }

  Future<void> chooseSettlementTarget() async {
    final options=targetType=='employee'?employees:expenses;
    final search=TextEditingController();
    var filtered=List<Map<String,dynamic>>.from(options);
    final selected=await showDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,refresh)=>AlertDialog(
      title:Text(targetType=='employee'?'اختيار الموظف المسؤول عن العجز':'اختيار بند الصرف'),
      content:SizedBox(width:620,height:460,child:Column(children:[
        TextField(controller:search,autofocus:true,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'بحث بالكود أو الاسم',border:OutlineInputBorder()),onChanged:(v)=>refresh(()=>filtered=options.where((r)=>targetName(r).toLowerCase().contains(v.trim().toLowerCase())).toList())),
        const SizedBox(height:10),
        Expanded(child:filtered.isEmpty?const Center(child:Text('لا توجد نتائج مطابقة.')):ListView.separated(itemCount:filtered.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(ctx,i){final row=filtered[i];return ListTile(dense:true,leading:Icon(targetType=='employee'?Icons.badge_outlined:Icons.receipt_long_outlined),title:Text(targetName(row)),onTap:()=>Navigator.pop(dialogContext,s(row['id'])),);}))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء'))],
    )));
    search.dispose();
    if(selected!=null&&mounted)setState(()=>targetId=selected);
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
          ErpQuickTaskButton(label:'إضافة',icon:Icons.add,onPressed:saving||(_manualSettlementScreen&&(sourceMode!='manual'||docId!=null))?null:createDoc),
          ErpQuickTaskButton(label:'حفظ',icon:Icons.save,onPressed:saving||!isDraft?null:saveDraft),
          ErpQuickTaskButton(label:'تعديل',icon:Icons.edit,onPressed:saving||!canEditDraft?null:editDraft),
          ErpQuickTaskButton(label:'حذف',icon:Icons.delete,onPressed:saving||!canDeleteManualDraft?null:deleteManualDraft),
          ErpQuickTaskButton(label:'معاينة',icon:Icons.visibility,onPressed:previewDraft),
          ErpQuickTaskButton(label:'طباعة',icon:Icons.print,onPressed:()=>exportPdf(share:false)),
          ErpQuickTaskButton(label:'Excel',icon:Icons.file_download,onPressed:exportExcel),
          ErpQuickTaskButton(label:'PDF',icon:Icons.picture_as_pdf,onPressed:()=>exportPdf(share:true)),
        ])),
      ]))),
      if(loading||saving)const LinearProgressIndicator(),
      if(error!=null)notice(error!,Colors.red),if(message!=null)notice(message!,Colors.green),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(_manualSettlementScreen?'إنشاء تسوية مخزنية يدوية':'إنشاء محضر جرد جديد',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
        DropdownButtonFormField<String>(value:branchId,isExpanded:true,decoration:const InputDecoration(labelText:'الفرع'),items:branches.map((b)=>DropdownMenuItem(value:s(b['id']),child:Text(s(b['branch_code'])+' — '+s(b['branch_name'])))).toList(),onChanged:(v)=>setState((){branchId=v;final mains=warehouses.where((w)=>s(w['parent_warehouse_id']).isEmpty && (v==null || s(w['branch_id'])==v)).toList();baseWarehouseId=mains.isEmpty?null:s(mains.first['id']);warehouseId=baseWarehouseId;})),
         DropdownButtonFormField<String>(value:baseWarehouseId,isExpanded:true,decoration:const InputDecoration(labelText:'المخزن الرئيسي'),items:warehouses.where((w)=>s(w['parent_warehouse_id']).isEmpty && (branchId==null || s(w['branch_id'])==branchId)).map((w)=>DropdownMenuItem(value:s(w['id']),child:Text(warehouseName(w['id'])))).toList(),onChanged:(v)=>setState(() { baseWarehouseId=v; warehouseId=v; })),
         DropdownButtonFormField<String>(value:warehouseId,isExpanded:true,decoration:const InputDecoration(labelText:'المخزن الفرعي / موقع التخزين'),items:[if(baseWarehouseId!=null)DropdownMenuItem(value:baseWarehouseId,child:Text('المخزن الرئيسي — '+warehouseName(baseWarehouseId))),...warehouses.where((w)=>s(w['parent_warehouse_id'])==s(baseWarehouseId)).map((w)=>DropdownMenuItem(value:s(w['id']),child:Text(warehouseName(w['id']))))],onChanged:(v)=>setState(()=>warehouseId=v)),
        if(_manualSettlementScreen)InputDecorator(decoration:const InputDecoration(labelText:'مصدر التسوية',border:OutlineInputBorder()),child:Text(current==null?'يدوي تلقائي عند إنشاء تسوية جديدة':s(current['source'])=='manual'?'يدوي':'من جرد المخزون')),
        if(!_manualSettlementScreen)Wrap(
          spacing:16,
          runSpacing:6,
          crossAxisAlignment:WrapCrossAlignment.center,
          children:[
            Row(mainAxisSize:MainAxisSize.min,children:[
              Checkbox(
                shape:const CircleBorder(),
                value:countMode=='default',
                onChanged:(v){if(v==true)setState(()=>countMode='default');},
              ),
              const Text('الوحدة الافتراضية للمخزن'),
            ]),
            Row(mainAxisSize:MainAxisSize.min,children:[
              Checkbox(
                shape:const CircleBorder(),
                value:countMode=='detailed',
                onChanged:(v){if(v==true)setState(()=>countMode='detailed');},
              ),
              const Text('الجرد التفصيلي'),
            ]),
          ],
        ),
        TextField(controller:notes,decoration:InputDecoration(labelText:_manualSettlementScreen?'ملاحظات التسوية':'ملاحظات المحضر')),
        const SizedBox(height:8),const Text('المحاضر السابقة',style:TextStyle(fontWeight:FontWeight.w800)),
         DropdownButtonFormField<String>(value:docId,isExpanded:true,decoration:const InputDecoration(labelText:'اختر محضراً'),items:docs.where((d)=>_manualSettlementScreen?['manual','stocktake'].contains(s(d['source'])):s(d['source'])=='stocktake').map((d)=>DropdownMenuItem(value:s(d['id']),child:Text(warehouseName(d['warehouse_id'])+' • '+(s(d['source'])=='manual'?'يدوي':'جرد فعلي')+' • '+s(d['status'])+' • '+s(d['created_at']).split('T').first,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)async{setState(() { docId=v; editing=false; targetId=null; targetType='employee'; final selected=docs.where((d)=>s(d['id'])==v);if(selected.isNotEmpty){countMode=s(selected.first['count_mode']).isEmpty?'detailed':s(selected.first['count_mode']);} });if(v!=null)await loadLines(v);}),
        Align(alignment:AlignmentDirectional.centerStart,child:TextButton.icon(onPressed:startNewDocument,icon:const Icon(Icons.add_circle_outline),label:const Text('مستند جديد'))),
      ]))),
      if(current!=null)...[
        Padding(padding:const EdgeInsets.all(8),child:Text('تفاصيل المحضر • '+warehouseName(current['warehouse_id'])+' • المصدر: '+(s(current['source'])=='manual'?'يدوي':'من جرد المخزون')+' • '+s(current['status']),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17))),
        if(isDraft && shortage>0)Wrap(spacing:8,runSpacing:6,children:[
          SegmentedButton<String>(segments:const [ButtonSegment(value:'employee',label:Text('موظف')),ButtonSegment(value:'expense',label:Text('بند صرف'))],selected:{targetType},onSelectionChanged:(v)=>setState(() { targetType=v.first; targetId=null; })),
          OutlinedButton.icon(onPressed:chooseSettlementTarget,icon:const Icon(Icons.search),label:Text(targetId==null?'اختيار بند/موظف':targetName(targets.firstWhere((r)=>s(r['id'])==targetId,orElse:()=>{'id':targetId,'employee_code':'','full_name':'','item_code':'','name_ar':'—'})))),
          Text('قيمة العجز: '+shortage.toStringAsFixed(2)+' ج.م',style:const TextStyle(fontWeight:FontWeight.w800,color:Colors.red)),
        ]) else if(isDraft) Padding(padding:const EdgeInsets.only(bottom:8),child:Text('لا توجد قيمة عجز حالياً؛ توجيه العجز غير مطلوب. قيمة العجز: '+shortage.toStringAsFixed(2)+' ج.م',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w700))),
        if(isDraft)Align(alignment:AlignmentDirectional.centerStart,child:FilledButton.icon(onPressed:saving?null:postDoc,icon:const Icon(Icons.verified_outlined),label:const Text('ترحيل الجرد وتحديث الأرصدة'))),
        Align(alignment:AlignmentDirectional.centerStart,child:Text(s(current['count_mode'])=='detailed'?'تفصيلي الرصيد — عرض الكميات بالوحدات الكبرى والوسطى والصغرى':'الجرد بالوحدة الافتراضية المحددة للمخزن',style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF3E007D)))),
        Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(columns:[
          const DataColumn(label:Text('م')),const DataColumn(label:Text('كود الصنف')),const DataColumn(label:Text('اسم الصنف')),
          const DataColumn(label:Text('رصيد متاح')),const DataColumn(label:Text('رصيد حجز')),const DataColumn(label:Text('رصيد فعلي')),
          if(s(current['count_mode'])=='detailed')...const [DataColumn(label:Text('كمية كبرى')),DataColumn(label:Text('وحدة كبرى')),DataColumn(label:Text('كمية وسطى')),DataColumn(label:Text('وحدة وسطى')),DataColumn(label:Text('كمية صغرى')),DataColumn(label:Text('وحدة صغرى'))],
          const DataColumn(label:Text('وحدة الجرد')),DataColumn(label:Text(_manualSettlementScreen&&s(current['source'])=='manual'?'فرق التسوية (+ زيادة / - عجز)':'كمية الجرد')),const DataColumn(label:Text('زيادة جرد')),const DataColumn(label:Text('عجز جرد')),DataColumn(label:Text(_manualSettlementScreen?'الرصيد بعد التسوية':'رصيد الجرد')),const DataColumn(label:Text('الفرق')),const DataColumn(label:Text('نوع الفرق')),const DataColumn(label:Text('قيمة الفرق')),

        ],rows:List.generate(lines.length,(i){
          final l=lines[i],f=n(l['conversion_factor'])<=0?1:n(l['conversion_factor']),diff=countedBase(l)-n(l['physical_snapshot']);
          final breakdown=unitBreakdown(l['item_id'],n(l['physical_snapshot']));
          final item=items.where((x)=>s(x['id'])==s(l['item_id']));final it=item.isEmpty?<String,dynamic>{}:item.first;final unit=units.where((x)=>s(x['id'])==s(l['unit_id']));
          return DataRow(cells:[
            DataCell(Text((i+1).toString())),DataCell(Text(s(it['item_code']))),DataCell(Text(s(it['item_name']))),
            DataCell(Text((n(l['available_snapshot'])/f).toStringAsFixed(3))),DataCell(Text((n(l['reserved_snapshot'])/f).toStringAsFixed(3))),
            DataCell(Text((n(l['physical_snapshot'])/f).toStringAsFixed(3))),
            if(s(current['count_mode'])=='detailed')...[
              DataCell(Text(n(breakdown['majorQty']).toStringAsFixed(3))),DataCell(Text(s(breakdown['majorUnit']))),DataCell(Text(n(breakdown['middleQty']).toStringAsFixed(3))),DataCell(Text(s(breakdown['middleUnit']))),DataCell(Text(n(breakdown['minorQty']).toStringAsFixed(3))),DataCell(Text(s(breakdown['minorUnit']))),
            ],
            DataCell(Text(unit.isEmpty?'—':s(unit.first['unit_name']))),
            DataCell(SizedBox(width:125,child:_manualCurrentDocument?Text((diff/f).toStringAsFixed(3)):TextField(controller:counts[s(l['id'])],enabled:canEditLines,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState(()=>error=null),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),hintText:'كمية فعلية')))),
            DataCell(_manualCurrentDocument?SizedBox(width:105,child:TextField(controller:increaseCounts[s(l['id'])],enabled:canEditLines,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState(()=>error=null),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),hintText:'زيادة'))):Text((diff>0?diff/f:0).toStringAsFixed(3))),
            DataCell(_manualCurrentDocument?SizedBox(width:105,child:TextField(controller:shortageCounts[s(l['id'])],enabled:canEditLines,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState(()=>error=null),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),hintText:'عجز'))):Text((diff<0?-diff/f:0).toStringAsFixed(3))),
            DataCell(Text((countedBase(l)/f).toStringAsFixed(3))),
            DataCell(Text((diff/f).toStringAsFixed(3))),
            DataCell(Text(diff<0?'عجز':diff>0?'زيادة':'مطابق',style:TextStyle(fontWeight:FontWeight.w800,color:diff<0?Colors.red:diff>0?Colors.green:Colors.black54))),
            DataCell(Text((diff.abs()*n(l['valuation_price'])).toStringAsFixed(2))),
          ]);
        }))))),
      ]else const Expanded(child:Center(child:Text('اختر محضراً أو أنشئ محضراً جديداً لعرض التفاصيل.'))),
    ]));
  }

  Widget notice(String t,Color c)=>Container(margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:c.withValues(alpha:.09),borderRadius:BorderRadius.circular(9)),child:Text(t,style:TextStyle(color:c)));
}
