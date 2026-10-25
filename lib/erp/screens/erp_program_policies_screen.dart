import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpProgramPoliciesScreen extends StatefulWidget {
  const ErpProgramPoliciesScreen({super.key, required this.companyId});
  final String? companyId;
  @override State<ErpProgramPoliciesScreen> createState() => _ErpProgramPoliciesScreenState();
}

class _ErpProgramPoliciesScreenState extends State<ErpProgramPoliciesScreen> {
  static const tabs = ['برمجية','محاسبية','مخزنية','بيعية','شرائية','إدارية'];
  static const defaults = <Map<String,dynamic>>[
    {'key':'ui_dimensions','category':'برمجية','ar':'السماح بتعديل مساحة وحدود الأزرار والخانات','en':'Allow changing button and field dimensions'},
    {'key':'ui_reorder','category':'برمجية','ar':'نقل مكان الأزرار وتعديل ترتيب الأعمدة أو الصفوف','en':'Reposition buttons and reorder columns or rows'},
    {'key':'fiscal_year','category':'محاسبية','ar':'فترة السنة المالية','en':'Fiscal year','mandatory':true,'value':'01/01 - 12/31'},
    {'key':'inventory_valuation','category':'محاسبية','ar':'طريقة تقييم المخزون','en':'Inventory valuation method','mandatory':true,'value':'المتوسط المرجح','options':['المتوسط المرجح','الوارد أولاً صادر أولاً (FIFO)','التحديد المحدد']},
    {'key':'inventory_count','category':'محاسبية','ar':'طريقة الجرد','en':'Inventory counting method','mandatory':true,'value':'الجرد المستمر','options':['الجرد المستمر','الجرد الدوري']},
    {'key':'depreciation','category':'محاسبية','ar':'طريقة إهلاك الأصول','en':'Asset depreciation method','mandatory':true,'value':'القسط الثابت','options':['القسط الثابت','القسط المتناقص','وحدات الإنتاج']},
    {'key':'group_duplicate_items','category':'مخزنية','ar':'تجميع الأصناف المتكررة في شاشات المخازن','en':'Group duplicate items in inventory screens'},
    {'key':'zero_adjustment_only','category':'مخزنية','ar':'اشتراط ترحيل التسوية المخزنية بصفر فقط','en':'Require inventory adjustments to post only at zero'},
    {'key':'adjustment_sale_price','category':'مخزنية','ar':'سعر الصنف في التسوية المخزنية هو سعر البيع بدلاً من سعر الشراء','en':'Use sale price in inventory adjustments'},
    {'key':'balance_sale_price','category':'مخزنية','ar':'سعر الصنف في تقارير الأرصدة هو سعر البيع بدلاً من سعر الشراء','en':'Use sale price in balance reports'},
    {'key':'customer_default_rep','category':'بيعية','ar':'إمكانية تغيير المندوب الافتراضي للعميل','en':'Allow changing customer default sales representative'},
    {'key':'customer_default_price_policy','category':'بيعية','ar':'إمكانية تغيير سياسة الأسعار الافتراضية للعميل','en':'Allow changing customer default price policy'},
    {'key':'edit_other_user_document','category':'بيعية','ar':'إمكانية تعديل المستند لغير المستخدم الأصلي','en':'Allow editing documents created by another user'},
    {'key':'customer_shortages_to_invoice','category':'بيعية','ar':'إضافة نواقص العملاء الواردة إلى فاتورة البيع مباشرة','en':'Add customer shortages directly to sales invoice'},
    {'key':'sales_invoice_audit','category':'بيعية','ar':'عمل سجل لكل حركات فاتورة البيع','en':'Log all sales invoice actions'},
    {'key':'skip_quotation','category':'بيعية','ar':'تخطي عرض أسعار في أمر البيع','en':'Skip quotation in sales order','all':true},
    {'key':'skip_sales_order','category':'بيعية','ar':'تخطي أمر البيع في فاتورة البيع','en':'Skip sales order in sales invoice'},
    {'key':'skip_supply_order','category':'شرائية','ar':'تخطي أمر التوريد في أمر الشراء','en':'Skip supply order in purchase order'},
    {'key':'skip_purchase_order','category':'شرائية','ar':'تخطي أمر الشراء في فاتورة الشراء','en':'Skip purchase order in purchase invoice'},
    {'key':'supplier_bonus_variance','category':'شرائية','ar':'تحديد نسبة فروقات وارد حوافز الموردين','en':'Set supplier incentives incoming variance','value':'0.025%'},
    {'key':'national_id_required','category':'إدارية','ar':'شرط تسجيل الرقم القومي عند تسجيل موظف جديد','en':'Require national ID for new employees','all':true},
  ];
  final db = Supabase.instance.client;
  final values = <String,Map<String,dynamic>>{};
  final users = <Map<String,dynamic>>[];
  int tab = 0; bool loading = true, saving = false; String? error, message;
  String get company => (widget.companyId ?? '').trim();
  @override void initState(){super.initState(); for(final p in defaults){values[p['key'] as String]={...p,'enabled':p['mandatory']==true || p['key']=='skip_quotation' || p['key']=='national_id_required','all':p['mandatory']==true || p['all']==true,'user_ids':<String>[]};} _load();}
  Future<void> _load() async {
    if(company.isEmpty){setState(()=>{loading=false,error='اختر الشركة وسجّل الدخول أولاً.'});return;}
    setState(()=>{loading=true,error=null,message=null});
    try {
      var rows=await db.from('erp_program_policies').select().eq('company_id',company);
      if ((rows as List).isEmpty) {
        final initial=values.values.map((p)=><String,dynamic>{'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],'is_enabled':p['mandatory']==true || p['key']=='skip_quotation' || p['key']=='national_id_required','apply_to_all':p['mandatory']==true || p['all']==true,'user_ids':<String>[],'policy_value':p['value']??''}).toList();
        await db.from('erp_program_policies').upsert(initial,onConflict:'company_id,policy_key');
        rows=await db.from('erp_program_policies').select().eq('company_id',company);
      }
      for(final row in (rows as List).whereType<Map<String,dynamic>>()) { final key=(row['policy_key']??'').toString(); if(!values.containsKey(key))continue; final p=values[key]!; p['enabled']=row['is_enabled']==true; p['all']=row['apply_to_all']==true || p['mandatory']==true; p['value']=(row['policy_value']??p['value']??'').toString(); p['user_ids']=List<String>.from((row['user_ids'] as List?)??const []); }
      final us=await db.from('erp_users').select('id,user_code,name_ar').eq('company_id',company);
      if(mounted)setState(()=>{users..clear()..addAll((us as List).whereType<Map<String,dynamic>>().map(Map<String,dynamic>.from)),loading=false});
    } catch(e){if(mounted)setState(()=>{loading=false,error='تعذر تحميل السياسات. طبّق migration سياسات البرنامج أولاً. $e'});}
  }
  Future<void> _save() async {
    setState(()=>{saving=true,error=null,message=null});
    try { final rows=values.values.map((p)=><String,dynamic>{'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],'is_enabled':p['mandatory']==true?true:p['enabled']==true,'apply_to_all':p['mandatory']==true||p['all']==true,'user_ids':p['mandatory']==true||p['all']==true?[]:p['user_ids'],'policy_value':p['value']??''}).toList(); await db.from('erp_program_policies').upsert(rows,onConflict:'company_id,policy_key'); if(mounted)setState(()=>{saving=false,message='تم حفظ سياسات البرنامج.'}); } catch(e){if(mounted)setState(()=>{saving=false,error='تعذر حفظ السياسات: $e'});}
  }
  Future<void> _pickUsers(Map<String,dynamic> p) async {
    final chosen=<String>{...List<String>.from(p['user_ids'] as List)};
    final result=await showDialog<Set<String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(title:const Text('اختيار المستخدمين — F1'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>ds(() { if(chosen.length==users.length){chosen.clear();}else{chosen.addAll(users.map((u)=>(u['id']??'').toString()));} }),child:const Text('تحديد الكل / إلغاء تحديد الكل'))),Flexible(child:ListView(shrinkWrap:true,children:users.map((u){final id=(u['id']??'').toString();final name=(u['name_ar']??u['user_code']??id).toString();return CheckboxListTile(dense:true,value:chosen.contains(id),title:Text(name),onChanged:(v)=>ds(() { if(v==true){chosen.add(id);}else{chosen.remove(id);} }));}).toList()))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,chosen),child:const Text('حفظ'))])));
    if(result!=null&&mounted)setState(()=>{p['user_ids']=result.toList(),p['all']=false});
  }
  int _daysInMonth(int month) => month == 2 ? 29 : ([4,6,9,11].contains(month) ? 30 : 31);

  Widget _fiscalRangeEditor(Map<String,dynamic> p) {
    final parts=(p['value']??'01/01 - 12/31').toString().split('-');
    final start=(parts.isNotEmpty?parts.first:'01/01').trim().split('/');
    final end=(parts.length>1?parts[1]:'12/31').trim().split('/');
    // Preserve the default January 1 through December 31 in MM/DD format.
    var sm=int.tryParse(start.isNotEmpty?start[0]:'01')??1;
    var sd=int.tryParse(start.length>1?start[1]:'01')??1;
    var em=int.tryParse(end.isNotEmpty?end[0]:'12')??12;
    var ed=int.tryParse(end.length>1?end[1]:'31')??31;
    sm=sm.clamp(1,12); em=em.clamp(1,12);
    sd=sd.clamp(1,_daysInMonth(sm)); ed=ed.clamp(1,_daysInMonth(em));
    void update() { p['value']='${sm.toString().padLeft(2,'0')}/${sd.toString().padLeft(2,'0')} - ${em.toString().padLeft(2,'0')}/${ed.toString().padLeft(2,'0')}'; }
    Widget picker(String label,int value,int max,ValueChanged<int?> change) => DropdownButtonFormField<int>(
      value:value, isExpanded:true, decoration:InputDecoration(labelText:label, isDense:true),
      items:List.generate(max,(i)=>DropdownMenuItem(value:i+1,child:Text((i+1).toString().padLeft(2,'0')))),
      onChanged:change,
    );
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Align(alignment:Alignment.centerRight,child:Text('فترة السنة المالية — الشهر / اليوم')),
      Row(children:[
        Expanded(child:picker('من — الشهر',sm,12,(v)=>setState(() { if(v!=null){sm=v;sd=sd.clamp(1,_daysInMonth(sm));update();} }))),
        const SizedBox(width:8),
        Expanded(child:picker('من — اليوم',sd,_daysInMonth(sm),(v)=>setState(() { if(v!=null){sd=v;update();} }))),
        const SizedBox(width:8),
        Expanded(child:picker('إلى — الشهر',em,12,(v)=>setState(() { if(v!=null){em=v;ed=ed.clamp(1,_daysInMonth(em));update();} }))),
        const SizedBox(width:8),
        Expanded(child:picker('إلى — اليوم',ed,_daysInMonth(em),(v)=>setState(() { if(v!=null){ed=v;update();} }))),
      ]),
    ]);
  }

  @override Widget build(BuildContext context){final list=values.values.where((p)=>p['category']==tabs[tab]).toList();return Column(children:[Container(color:const Color(0xFF3E007D),padding:const EdgeInsets.all(12),child:Row(children:[const Icon(Icons.policy_outlined,color:Color(0xFFFFA015),size:28),const SizedBox(width:8),const Expanded(child:Text('سياسات البرنامج',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:20))),TextButton.icon(onPressed:loading?null:_load,icon:const Icon(Icons.refresh,color:Colors.white),label:const Text('تحديث',style:TextStyle(color:Colors.white))),FilledButton.icon(onPressed:saving?null:_save,icon:const Icon(Icons.save),label:Text(saving?'جارٍ الحفظ':'حفظ'))])),if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),if(message!=null)Padding(padding:const EdgeInsets.all(8),child:Text(message!,style:const TextStyle(color:Colors.green))),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(tabs.length,(i)=>Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(label:Text(tabs[i]),selected:tab==i,onSelected:(_)=>setState(()=>tab=i)))))),Expanded(child:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(10),children:list.map((p){final mandatory=p['mandatory']==true;final all=p['all']==true;final options=(p['options'] as List?)?.cast<String>()??const <String>[];return Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[Row(children:[Checkbox(value:mandatory?true:p['enabled']==true,onChanged:mandatory?null:(v)=>setState(()=>p['enabled']=v==true)),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p['ar'].toString(),style:const TextStyle(fontWeight:FontWeight.bold)),Text(p['en'].toString(),style:const TextStyle(color:Colors.black54,fontSize:11))])),if(mandatory)const Chip(label:Text('إلزامي للجميع'))]),if(options.isNotEmpty)DropdownButtonFormField<String>(value:options.contains(p['value'])?p['value'] as String:options.first,isExpanded:true,decoration:const InputDecoration(labelText:'القيمة الافتراضية'),items:options.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>p['value']=v)),if(p['key']=='fiscal_year')_fiscalRangeEditor(p),if(p['key']=='supplier_bonus_variance')TextFormField(key:ValueKey('${p['key']}-${p['value']}'),initialValue:p['value']?.toString()??'',decoration:const InputDecoration(labelText:'نسبة الفروقات %'),keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(v)=>p['value']=v),Row(children:[Checkbox(value:mandatory||all,onChanged:mandatory?null:(v)=>setState(() { p['all']=v==true; if(v==true)p['user_ids']=<String>[]; })),const Expanded(child:Text('تطبق على الكل')),if(!mandatory)Checkbox(value:!all,onChanged:(v)=>setState(() { p['all']=v!=true; if(v==true)p['user_ids']=<String>[]; })),if(!mandatory)const Text('تحديد مستخدمين'),if(!mandatory)IconButton(tooltip:'اختيار المستخدمين F1',onPressed:all?null:()=>_pickUsers(p),icon:const Icon(Icons.person_search)),if(!mandatory&&!all)Text((p['user_ids'] as List).length.toString())])])));}).toList()))]);}
}
