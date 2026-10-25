import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class ErpSupplierDeferredCommissionsScreen extends StatefulWidget {
  const ErpSupplierDeferredCommissionsScreen({super.key, required this.companyId});
  final String? companyId;
  @override State<ErpSupplierDeferredCommissionsScreen> createState() => _ErpSupplierDeferredCommissionsScreenState();
}

class _ErpSupplierDeferredCommissionsScreenState extends State<ErpSupplierDeferredCommissionsScreen> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String,dynamic>> _rows = [];
  bool _loading = true, _saving = false;
  String? _error, _notice;
  String get _company => (widget.companyId ?? '').trim();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (_company.isEmpty) { setState(() { _loading=false; _error='اختر الشركة أولاً.'; }); return; }
    setState(() { _loading=true; _error=null; _notice=null; });
    try {
      final data=await _db.from('erp_supplier_deferred_commissions').select().eq('company_id',_company).order('entry_date',ascending:false);
      if (!mounted) return;
      setState(() { _rows=(data as List).whereType<Map<String,dynamic>>().map(Map<String,dynamic>.from).toList(); _loading=false; });
    } catch(e) { if(mounted)setState(() { _loading=false; _error='تعذر تحميل مؤجلات وعمولات الموردين. تأكد من تطبيق migration الشاشة. $e'; }); }
  }

  Future<void> _edit([Map<String,dynamic>? row]) async {
    final supplier=TextEditingController(text:(row?['supplier_name']??'').toString());
    final description=TextEditingController(text:(row?['description']??'').toString());
    final base=TextEditingController(text:(row?['base_amount']??'0').toString());
    var defaultPercent='0.025';
    if(row==null){try{final policies=await _db.from('erp_program_policies').select('is_enabled,apply_to_all,policy_value').eq('company_id',_company).eq('policy_key','supplier_bonus_variance').limit(1);if((policies as List).isNotEmpty&&policies.first['is_enabled']==true&&((policies.first['apply_to_all']==true)||true)){final saved=(policies.first['policy_value']??'').toString().replaceAll('%','').trim();if(double.tryParse(saved)!=null)defaultPercent=saved;}}catch(_){}}
    final percent=TextEditingController(text:(row?['variance_percent']??defaultPercent).toString());
    final commission=TextEditingController(text:(row?['commission_amount']??'').toString());
    final notes=TextEditingController(text:(row?['notes']??'').toString());
    var type=(row?['entry_type']??'مؤجل').toString();
    var status=(row?['status']??'معلق').toString();
    var date=(row?['entry_date']??DateTime.now().toIso8601String().substring(0,10)).toString();
    var due=(row?['due_date'])?.toString();
    final formKey=GlobalKey<FormState>();
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(
      title:Text(row==null?'إضافة مؤجل / عمولة مورد':'تعديل مؤجل / عمولة مورد'),
      content:SizedBox(width:540,child:SingleChildScrollView(child:Form(key:formKey,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:supplier,decoration:const InputDecoration(labelText:'اسم المورد *'),validator:(v)=>(v??'').trim().isEmpty?'اسم المورد مطلوب':null),
        DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'نوع الحركة'),items:const ['مؤجل','عمولة','حافز','فروقات وارد'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>ds(()=>type=v??type)),
        TextFormField(controller:description,decoration:const InputDecoration(labelText:'البيان')),
        TextFormField(controller:base,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ الأساسي'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'أدخل مبلغاً صحيحاً':null),
        TextFormField(controller:percent,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'نسبة فروقات / حوافز المورد %'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'أدخل نسبة صحيحة':null),
        TextFormField(controller:commission,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'قيمة العمولة / الفروقات')),
        TextFormField(initialValue:date,decoration:const InputDecoration(labelText:'تاريخ الحركة (YYYY-MM-DD)'),onChanged:(v)=>date=v,validator:(v)=>DateTime.tryParse(v??'')==null?'التاريخ غير صحيح':null),
        TextFormField(initialValue:due??'',decoration:const InputDecoration(labelText:'تاريخ الاستحقاق (اختياري YYYY-MM-DD)'),onChanged:(v)=>due=v.trim().isEmpty?null:v,validator:(v)=>v==null||v.trim().isEmpty||DateTime.tryParse(v.trim())!=null?null:'تاريخ الاستحقاق غير صحيح'),
        DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'الحالة'),items:const ['معلق','مستحق','تمت التسوية','ملغي'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>ds(()=>status=v??status)),
        TextFormField(controller:notes,decoration:const InputDecoration(labelText:'ملاحظات'),maxLines:2),
      ])))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:(){if(formKey.currentState?.validate()??false)Navigator.pop(ctx,true);},child:const Text('حفظ'))],
    )));
    if(result!=true){for(final c in [supplier,description,base,percent,commission,notes]){c.dispose();}return;}
    setState(()=>_saving=true);
    try {
      final b=double.parse(base.text), p=double.parse(percent.text);
      final data=<String,dynamic>{'company_id':_company,'supplier_name':supplier.text.trim(),'entry_type':type,'description':description.text.trim(),'base_amount':b,'variance_percent':p,'commission_amount':double.tryParse(commission.text)??(b*p/100),'entry_date':date,'due_date':due,'status':status,'notes':notes.text.trim(),'updated_at':DateTime.now().toUtc().toIso8601String()};
      if(row==null){data['created_by']=_db.auth.currentUser?.id;await _db.from('erp_supplier_deferred_commissions').insert(data);}else{await _db.from('erp_supplier_deferred_commissions').update(data).eq('id',row['id']).eq('company_id',_company);}
      if(mounted)setState(()=>_notice='تم حفظ الحركة.'); await _load();
    }catch(e){if(mounted)setState(()=>_error='تعذر الحفظ: $e');}
    finally{if(mounted)setState(()=>_saving=false);}
    for(final c in [supplier,description,base,percent,commission,notes]){c.dispose();}
  }

  @override Widget build(BuildContext context){
    final visible=_rows.where((r)=>['supplier_name','description','entry_type','status'].any((k)=>(r[k]??'').toString().toLowerCase().contains(_search.text.toLowerCase()))).toList();
    return Column(children:[
      Container(color:_purple,padding:const EdgeInsets.all(12),child:Row(children:[
        const Icon(Icons.receipt_long_outlined,color:_orange,size:28),const SizedBox(width:8),
        const Expanded(child:Text('مؤجلات وعمولات الموردين',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:20))),
        IconButton(tooltip:'تحديث',onPressed:_loading?null:_load,icon:const Icon(Icons.refresh,color:Colors.white)),
        FilledButton.icon(onPressed:_saving?null:()=>_edit(),icon:const Icon(Icons.add),label:const Text('إضافة')),
      ])),
      if(_error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_error!,style:const TextStyle(color:Colors.red))),
      if(_notice!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_notice!,style:const TextStyle(color:Colors.green))),
      Padding(padding:const EdgeInsets.all(10),child:TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'بحث في الموردين والحركات',border:OutlineInputBorder()))),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):visible.isEmpty?const Center(child:Text('لا توجد حركات مطابقة. اضغط إضافة لتسجيل حركة جديدة.')):ListView(padding:const EdgeInsets.all(8),children:visible.map((r)=>Card(child:ListTile(
        leading:const CircleAvatar(backgroundColor:Color(0xFFF5EFFB),child:Icon(Icons.receipt_long,color:_purple)),
        title:Text((r['supplier_name']??'').toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
        subtitle:Text('${r['entry_type']} • ${r['description']??''}\nالتاريخ: ${r['entry_date']} • الحالة: ${r['status']}\nالمبلغ: ${r['base_amount']} • النسبة: ${r['variance_percent']}% • العمولة: ${r['commission_amount']}'),
        isThreeLine:true,trailing:IconButton(tooltip:'تعديل',onPressed:_saving?null:()=>_edit(r),icon:const Icon(Icons.edit_outlined)),
      ))).toList())),
    ]);
  }
}
