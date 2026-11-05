import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ep=Color(0xFF3E007D),_eb=Color(0xFFFAF8FC);
class ErpEnterpriseModulesScreen extends StatefulWidget{
 const ErpEnterpriseModulesScreen({super.key,required this.module,required this.group,required this.page,required this.companyId});
 final String module,group,page; final String? companyId;
 @override State<ErpEnterpriseModulesScreen> createState()=>_ErpEnterpriseModulesScreenState();
}
class _ErpEnterpriseModulesScreenState extends State<ErpEnterpriseModulesScreen>{
 final _db=Supabase.instance.client; final _search=TextEditingController();
 List<Map<String,dynamic>> rows=[]; bool loading=true; String? error; String status='all';
 String get moduleKey=>widget.module=='أصول ثابتة'?'assets':widget.module=='تصنيع'?'manufacturing':widget.module=='مقاولات'?'contracting':'service_crm';
 bool get report=>widget.group=='تقارير'||widget.page.contains('تقرير')||widget.page.contains('تحليل')||widget.page.contains('مؤشرات');
 List<Map<String,String>> get fields{
  final common=<Map<String,String>>[
   {'key':'record_code','label':'الكود / رقم المستند','required':'1'},{'key':'title','label':'الاسم / الوصف','required':'1'},
   {'key':'status','label':'الحالة','options':'مسودة|نشط|جارٍ التنفيذ|بانتظار إجراء|معتمد|مكتمل|ملغي|مغلق'},
   {'key':'reference_date','label':'التاريخ'},{'key':'due_date','label':'تاريخ الاستحقاق'},{'key':'counterparty','label':'العميل / المورد / الجهة'},
   {'key':'amount','label':'القيمة','type':'number'},{'key':'quantity','label':'الكمية','type':'number'}
  ];
  final extra=moduleKey=='assets'?[
   {'key':'asset_category','label':'فئة الأصل'},{'key':'asset_location','label':'موقع الأصل'},{'key':'serial_number','label':'الرقم المسلسل'},
   {'key':'acquisition_cost','label':'تكلفة الاقتناء','type':'number'},{'key':'residual_value','label':'القيمة التخريدية','type':'number'},
   {'key':'useful_life_months','label':'العمر الإنتاجي بالشهر','type':'number'},{'key':'depreciation_method','label':'طريقة الإهلاك','options':'خط مستقيم|متناقص|وحدات الإنتاج|بدون إهلاك'}
  ]:moduleKey=='manufacturing'?[
   {'key':'product_name','label':'المنتج النهائي'},{'key':'bom_code','label':'كود قائمة المواد'},{'key':'work_center','label':'مركز العمل'},
   {'key':'planned_quantity','label':'الكمية المخططة','type':'number'},{'key':'produced_quantity','label':'الكمية المنتجة','type':'number'},
   {'key':'scrap_quantity','label':'الفاقد','type':'number'},{'key':'production_stage','label':'مرحلة التشغيل'},
   {'key':'quality_result','label':'نتيجة الجودة','options':'لم يفحص|مطابق|مطابق بتحفظ|مرفوض'}
  ]:moduleKey=='contracting'?[
   {'key':'project_name','label':'اسم المشروع'},{'key':'contract_number','label':'رقم العقد'},{'key':'site_location','label':'موقع المشروع'},
   {'key':'boq_item','label':'بند الأعمال / المقايسة'},{'key':'contract_value','label':'قيمة العقد','type':'number'},
   {'key':'completion_percent','label':'نسبة الإنجاز %','type':'number'},{'key':'subcontractor','label':'مقاول الباطن'},{'key':'project_manager','label':'مدير المشروع'}
  ]:[
   {'key':'contact_name','label':'اسم جهة الاتصال'},{'key':'phone','label':'رقم الهاتف'},{'key':'email','label':'البريد الإلكتروني'},
   {'key':'channel','label':'قناة التواصل','options':'هاتف|واتساب|بريد إلكتروني|زيارة|موقع إلكتروني|تطبيق'},
   {'key':'priority','label':'الأولوية','options':'منخفضة|عادية|عالية|عاجلة'},{'key':'team','label':'فريق الخدمة / المسؤول'},
   {'key':'ticket_type','label':'نوع الطلب / الشكوى'},{'key':'resolution','label':'الإجراء / الحل'}
  ];
  return [...common,...extra];
 }
 @override void initState(){super.initState();load();}
 @override void dispose(){_search.dispose();super.dispose();}
 Future<void> load()async{
  final co=(widget.companyId??'').trim();if(co.isEmpty){setState(()=>loading=false);error='يجب تحديد الشركة أولًا.';return;}
  setState(()=>loading=true);
  try{final data=await _db.from('erp_enterprise_module_records').select('*').eq('company_id',co).eq('module_key',moduleKey).eq('page_key',widget.page).order('created_at',ascending:false).limit(1000);if(!mounted)return;rows=List<Map<String,dynamic>>.from(data);}
  catch(e){error='تعذر تحميل السجلات: '+e.toString();}
  if(mounted)setState(()=>loading=false);
 }
 Map<String,dynamic> details(Map<String,dynamic> r)=>r['details'] is Map?Map<String,dynamic>.from(r['details']):<String,dynamic>{};
 double numVal(dynamic v)=>v is num?v:(double.tryParse(v?.toString()??'')??0);
 String statusLabel(dynamic s)=>({'draft':'مسودة','active':'نشط','in_progress':'جارٍ التنفيذ','waiting':'بانتظار إجراء','approved':'معتمد','completed':'مكتمل','cancelled':'ملغي','closed':'مغلق'}[s?.toString()]??s?.toString()??'—');
 List<Map<String,dynamic>> get filtered{final q=_search.text.toLowerCase().trim();return rows.where((r)=>(status=='all'||r['status']==status)&&(q.isEmpty||[r['record_code'],r['title'],r['counterparty']].join(' ').toLowerCase().contains(q))).toList();}
 Future<void> edit({Map<String,dynamic>? row})async{
  final d=row==null?<String,dynamic>{}:details(row);final cs=<String,TextEditingController>{};final opts=<String,String?>{};
  for(final f in fields){final k=f['key']!;final v=['record_code','title','status','reference_date','due_date','counterparty','amount','quantity'].contains(k)?row?[k]:d[k];if(f.containsKey('options'))opts[k]=v?.toString()??f['options']!.split('|').first;else cs[k]=TextEditingController(text:v?.toString()??'');}
  final key=GlobalKey<FormState>();
  final saved=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,sd)=>AlertDialog(
   title:Text((row==null?'إضافة — ':'تعديل — ')+widget.page,textDirection:TextDirection.rtl),
   content:SizedBox(width:600,child:Form(key:key,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:fields.map((f){
    final k=f['key']!;if(f.containsKey('options'))return Padding(padding:const EdgeInsets.only(bottom:10),child:DropdownButtonFormField<String>(value:opts[k],isExpanded:true,decoration:InputDecoration(labelText:f['label'],border:const OutlineInputBorder()),items:f['options']!.split('|').map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>sd(()=>opts[k]=v)));
    return Padding(padding:const EdgeInsets.only(bottom:10),child:TextFormField(controller:cs[k],keyboardType:f['type']=='number'?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:f['label'],border:const OutlineInputBorder()),validator:f['required']=='1'?(v)=>(v??'').trim().isEmpty?'مطلوب':null:null));
   }).toList())))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(style:FilledButton.styleFrom(backgroundColor:_ep),onPressed:()async{
    if(!key.currentState!.validate())return;final payload=<String,dynamic>{'company_id':widget.companyId,'module_key':moduleKey,'group_key':widget.group,'page_key':widget.page};final extra=<String,dynamic>{};
    for(final f in fields){final k=f['key']!;if(f.containsKey('options')){if(opts[k]!=null){if(k=='status')payload[k]=opts[k];else extra[k]=opts[k];}}else{final v=cs[k]!.text.trim();if(v.isEmpty)continue;if(['record_code','title','reference_date','due_date','counterparty'].contains(k))payload[k]=v;else if(['amount','quantity'].contains(k))payload[k]=double.tryParse(v.replaceAll(',','.'))??0;else extra[k]=f['type']=='number'?(double.tryParse(v.replaceAll(',','.'))??0):v;}}
    payload['details']=extra;
    try{if(row==null)await _db.from('erp_enterprise_module_records').insert(payload);else await _db.from('erp_enterprise_module_records').update(payload).eq('id',row['id']).eq('company_id',widget.companyId!);if(ctx.mounted)Navigator.pop(ctx,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحفظ: '+e.toString())));}
   },child:const Text('حفظ'))]
  )));
  for(final c in cs.values){c.dispose();}if(saved==true)await load();
 }
 Future<void> remove(Map<String,dynamic> r)async{final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد الحذف'),content:const Text('هل تريد حذف السجل؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(yes!=true)return;try{await _db.from('erp_enterprise_module_records').delete().eq('id',r['id']).eq('company_id',widget.companyId!);await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
 @override Widget build(BuildContext context){
  final list=filtered;final pending=rows.where((r)=>['draft','waiting','in_progress'].contains(r['status'])).length;final total=rows.fold<double>(0,(s,r)=>s+numVal(r['amount']));
  return Directionality(textDirection:TextDirection.rtl,child:Container(color:_eb,padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Card(elevation:0,child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
    Row(children:[CircleAvatar(backgroundColor:const Color(0xFFF1EAF7),child:Icon(moduleKey=='assets'?Icons.account_balance_outlined:moduleKey=='manufacturing'?Icons.precision_manufacturing_outlined:moduleKey=='contracting'?Icons.construction_outlined:Icons.support_agent_outlined,color:_ep)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.page,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:_ep)),Text(widget.module+' • '+widget.group,style:const TextStyle(fontSize:12,color:Colors.black54))])),if(!report)FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('إضافة'),style:FilledButton.styleFrom(backgroundColor:_ep)),IconButton(onPressed:load,icon:const Icon(Icons.refresh,color:_ep))]),
    const SizedBox(height:12),Row(children:[metric('السجلات',rows.length.toString()),const SizedBox(width:8),metric('قيد المتابعة',pending.toString()),const SizedBox(width:8),metric('إجمالي القيم',total.toStringAsFixed(2))])
   ]))),
   if(report)const Padding(padding:EdgeInsets.only(bottom:8),child:Text('التقرير يعتمد على السجلات الفعلية المسجلة في هذا القسم.',style:TextStyle(color:Colors.black54,fontSize:12))),
   Row(children:[Expanded(child:TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث بالكود أو الاسم أو الجهة',border:OutlineInputBorder(),isDense:true,filled:true,fillColor:Colors.white))),const SizedBox(width:8),SizedBox(width:150,child:DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة',border:OutlineInputBorder(),isDense:true),items:const [DropdownMenuItem(value:'all',child:Text('كل الحالات')),DropdownMenuItem(value:'draft',child:Text('مسودة')),DropdownMenuItem(value:'active',child:Text('نشط')),DropdownMenuItem(value:'in_progress',child:Text('جارٍ التنفيذ')),DropdownMenuItem(value:'waiting',child:Text('بانتظار إجراء')),DropdownMenuItem(value:'approved',child:Text('معتمد')),DropdownMenuItem(value:'completed',child:Text('مكتمل'))],onChanged:(v)=>setState(()=>status=v??'all')))]),
   const SizedBox(height:10),Expanded(child:loading?const Center(child:CircularProgressIndicator(color:_ep)):error!=null?Center(child:Text(error!,style:const TextStyle(color:Colors.red))):list.isEmpty?Center(child:Text(report?'لا توجد بيانات كافية للتقرير.':'لا توجد سجلات في هذا القسم بعد.',style:const TextStyle(color:Colors.black54))):Card(elevation:0,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('الكود')),DataColumn(label:Text('الاسم / الوصف')),DataColumn(label:Text('التاريخ')),DataColumn(label:Text('الجهة')),DataColumn(label:Text('القيمة')),DataColumn(label:Text('الحالة')),DataColumn(label:Text('إجراءات'))],rows:list.map((r)=>DataRow(cells:[DataCell(Text(r['record_code']?.toString()??'—')),DataCell(ConstrainedBox(constraints:const BoxConstraints(maxWidth:220),child:Text(r['title']?.toString()??'—',overflow:TextOverflow.ellipsis))),DataCell(Text(r['reference_date']?.toString()??'—')),DataCell(Text(r['counterparty']?.toString()??'—')),DataCell(Text(numVal(r['amount']).toStringAsFixed(2))),DataCell(Text(statusLabel(r['status']))),DataCell(report?const Text('—'):Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>edit(row:r),icon:const Icon(Icons.edit_outlined,color:_ep)),IconButton(onPressed:()=>remove(r),icon:const Icon(Icons.delete_outline,color:Colors.red))]))])).toList()))))
  ])));
 }
 Widget metric(String label,String value)=>Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF7F2FA),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,color:Colors.black54)),Text(value,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:_ep))])));
}
