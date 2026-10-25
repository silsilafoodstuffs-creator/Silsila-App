import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpCustomerCreditScreen extends StatefulWidget {
  const ErpCustomerCreditScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpCustomerCreditScreen> createState() => _ErpCustomerCreditScreenState();
}

class _ErpCustomerCreditScreenState extends State<ErpCustomerCreditScreen> {
  static const purple = Color(0xFF3E007D);
  List<Map<String,dynamic>> rows = [];
  String? selectedId;
  String transactionType = 'نقدي';
  final limitController = TextEditingController(text:'0');
  bool loading = false, saving = false;
  String? error, message;
  SupabaseClient? get db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String s(dynamic value) => (value ?? '').toString();
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { limitController.dispose(); super.dispose(); }
  Future<void> _load() async {
    final client=db; final company=widget.companyId;
    if(client==null||company==null||company.isEmpty){setState(()=>error='لا توجد شركة محددة أو جلسة دخول.');return;}
    setState(()=>loading=true);
    try {
      final data=await client.from('erp_parties').select('id,party_code,party_name,transaction_type,credit_limit').eq('company_id',company).eq('party_kind','customer').order('party_code').limit(2000);
      if(!mounted)return;
      setState(() { rows = (data as List).map((e)=>Map<String,dynamic>.from(e)).toList(); loading = false; error = null; });
    } catch(e) { if(mounted)setState(()=>{loading=false,error:'تعذر تحميل ائتمان العملاء: $e'}); }
  }
  void _select(Map<String,dynamic> row) { setState(()=>selectedId=s(row['id'])); transactionType=s(row['transaction_type']).isEmpty?'نقدي':s(row['transaction_type']); limitController.text=s(row['credit_limit']).isEmpty?'0':s(row['credit_limit']); }
  Future<void> _save() async {
    final client=db; final id=selectedId; final company=widget.companyId; final limit=double.tryParse(limitController.text.trim());
    if(client==null||id==null||company==null)return;
    if(limit==null||limit<0){setState(()=>error='أدخل حد ائتمان صحيحًا غير سالب.');return;}
    setState(() { saving = true; error = null; message = null; });
    try {
      await client.from('erp_parties').update({'transaction_type':transactionType,'credit_limit':limit}).eq('id',id).eq('company_id',company).eq('party_kind','customer');
      if(!mounted)return; setState(() { saving = false; message = 'تم حفظ سياسة ائتمان العميل.'; }); await _load();
    } catch(e) { if(mounted)setState(() { saving = false; error = 'تعذر حفظ سياسة الائتمان: $e'; }); }
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:purple,borderRadius:BorderRadius.circular(12)),child:Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('ائتمان العملاء',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),Text('تعديل نوع التعامل وحد الائتمان من هذه الشاشة فقط.',style:TextStyle(color:Colors.white70))])),OutlinedButton.icon(onPressed:loading?null:_load,icon:const Icon(Icons.refresh,color:Colors.white),label:const Text('تحديث',style:TextStyle(color:Colors.white))),const SizedBox(width:8),FilledButton.icon(onPressed:saving||selectedId==null?null:_save,icon:const Icon(Icons.save),label:const Text('حفظ'))])),
    if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),
    if(message!=null)Padding(padding:const EdgeInsets.all(8),child:Text(message!,style:const TextStyle(color:Colors.green))),
    if(loading||saving)const LinearProgressIndicator(),
    Expanded(child:rows.isEmpty?const Center(child:Text('لا توجد بيانات عملاء.')):ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:6),itemBuilder:(ctx,i){final r=rows[i];return Card(color:selectedId==s(r['id'])?const Color(0xFFF5EFFB):Colors.white,child:ListTile(selected:selectedId==s(r['id']),onTap:()=>_select(r),leading:Text('${i+1}'),title:Text('${s(r['party_code'])} — ${s(r['party_name'])}'),subtitle:Text('نوع التعامل: ${s(r['transaction_type']).isEmpty?'نقدي':s(r['transaction_type'])} • حد الائتمان: ${s(r['credit_limit'])}'),trailing:const Icon(Icons.chevron_left)));})),
    if(selectedId!=null)Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:DropdownButtonFormField<String>(value:transactionType,decoration:const InputDecoration(labelText:'نوع التعامل',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'نقدي',child:Text('نقدي')),DropdownMenuItem(value:'آجل',child:Text('آجل')),DropdownMenuItem(value:'بيع مباشر',child:Text('بيع مباشر'))],onChanged:(v)=>setState(()=>transactionType=v??transactionType))),const SizedBox(width:8),Expanded(child:TextField(controller:limitController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'حد الائتمان',border:OutlineInputBorder())))]))),
  ]));
}
