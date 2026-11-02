import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

class ErpFinancialOperationsScreen extends StatefulWidget {
  const ErpFinancialOperationsScreen({super.key, required this.companyId, required this.initialView});
  final String? companyId;
  final String initialView;
  @override
  State<ErpFinancialOperationsScreen> createState() => _ErpFinancialOperationsScreenState();
}

class _ErpFinancialOperationsScreenState extends State<ErpFinancialOperationsScreen> with TickerProviderStateMixin {
  static const purple = Color(0xFF3E007D);
  SupabaseClient? db;
  late final TabController tabs;
  bool loading = false, saving = false, directMode = true, requireApproval = true, allowCredit = true;
  String? error, message, fromId, toId, bankId, chequeId, assigneeId, salesId;
  String movementType = 'receipt', fromType = 'cashbox', toType = 'customer', orderType = 'payment';
  String partyType = 'supplier', chequeType = 'bank', chequeDirection = 'payment', trackingFilter = 'all';
  final amount = TextEditingController(), description = TextEditingController(), fromName = TextEditingController(), toName = TextEditingController();
  final partyName = TextEditingController(), firstCheck = TextEditingController(), issueDate = TextEditingController(text: _today());
  final dueDate = TextEditingController(text: _today()), chequeAmount = TextEditingController();
  List<Map<String,dynamic>> cashboxes=[], accounts=[], parties=[], users=[], sales=[], movements=[], orders=[], books=[], cheques=[];
  static String _today() { final d=DateTime.now(); return d.year.toString().padLeft(4,'0')+'-'+d.month.toString().padLeft(2,'0')+'-'+d.day.toString().padLeft(2,'0'); }
  String get company => widget.companyId?.trim() ?? '';
  String s(dynamic v) => (v ?? '').toString();
  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse(s(v)) ?? 0;
  String money(dynamic v) => n(v).toStringAsFixed(2);
  List<Map<String,dynamic>> maps(dynamic x) => (x as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();

  int initial() {
    const names=['حركة نقدية','أمر صرف / توريد نقدية','أمر صرف شيكات','حركة صرف / توريد شيكات','تسجيل دفاتر شيكات','متابعة الشيكات','شيكات الائتمان'];
    final i=names.indexOf(widget.initialView); return i<0?0:i;
  }
  @override void initState() {
    super.initState(); try { db=Supabase.instance.client; } catch (_) {}
    tabs=TabController(length:8,vsync:this,initialIndex:initial());
    if(company.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_)=>load());
  }
  @override void dispose() {
    tabs.dispose(); for(final c in [amount,description,fromName,toName,partyName,firstCheck,issueDate,dueDate,chequeAmount]) {c.dispose();} super.dispose();
  }

  Future<void> load() async {
    if(db==null || company.isEmpty) { setState(()=>error='لا توجد شركة مرتبطة بالمستخدم الحالي.'); return; }
    setState(()=>loading=true);
    try {
      final r=await Future.wait([
        db!.from('erp_cashboxes').select('id,cashbox_code,cashbox_name,is_bank_account,checkbook_sheet_count').eq('company_id',company).eq('is_active',true).order('cashbox_name'),
        db!.from('erp_accounts').select('id,account_code,account_name').eq('company_id',company).eq('is_active',true).eq('is_postable',true).limit(2000),
        db!.from('erp_parties').select('id,party_code,party_name,party_kind').eq('company_id',company).eq('is_active',true).limit(2000),
        db!.from('erp_users').select('id,auth_user_id,user_code,name_ar').eq('company_id',company).eq('is_active',true).limit(1000),
        db!.from('erp_sales_documents').select('id,document_number,grand_total').eq('company_id',company).eq('document_type','order').limit(300),
        db!.from('erp_cash_movements').select('*').eq('company_id',company).order('movement_date',ascending:false).limit(300),
        db!.from('erp_cash_orders').select('*').eq('company_id',company).order('order_date',ascending:false).limit(300),
        db!.from('erp_checkbooks').select('*').eq('company_id',company).order('created_at',ascending:false).limit(300),
        db!.from('erp_cheques').select('*').eq('company_id',company).order('check_number').limit(3000),
        db!.from('erp_financial_policies').select().eq('company_id',company).maybeSingle(),
      ]);
      if(!mounted)return;
      final p=r[9] as Map<String,dynamic>?;
      setState(() {
        cashboxes=maps(r[0]); accounts=maps(r[1]); parties=maps(r[2]); users=maps(r[3]); sales=maps(r[4]);
        movements=maps(r[5]); orders=maps(r[6]); books=maps(r[7]); cheques=maps(r[8]);
        directMode=p==null || s(p['cash_issue_mode'])!='sales_order_only';
        requireApproval=p?['require_cash_order_approval']!=false; allowCredit=p?['allow_credit_cheques']!=false;
        loading=false; error=null;
      });
    } catch(e) { if(mounted)setState(() {loading=false;error='تعذر تحميل البيانات: '+e.toString();}); }
  }

  Future<void> run(Future<void> Function() action,String ok) async {
    if(saving)return; setState(() {saving=true;error=null;message=null;});
    try { await action(); if(!mounted)return; setState(() {saving=false;message=ok;}); await load(); }
    catch(e) { if(mounted)setState(() {saving=false;error='تعذر التنفيذ: '+e.toString();}); }
  }
  void resetForm() { amount.clear(); description.clear(); fromName.clear(); toName.clear(); partyName.clear(); chequeAmount.clear(); setState(() {error=null;message='نموذج جديد جاهز.';}); }
  String cashboxName(String id) { final a=cashboxes.where((x)=>s(x['id'])==id); return a.isEmpty?'غير محدد':s(a.first['cashbox_name']); }
  String entityName(Map<String,dynamic> r) => s(r['party_name']).isNotEmpty?s(r['party_name']):s(r['account_name']).isNotEmpty?s(r['account_name']):s(r['cashbox_name']);
  String entityCode(Map<String,dynamic> r) => s(r['party_code']).isNotEmpty?s(r['party_code']):s(r['account_code']).isNotEmpty?s(r['account_code']):s(r['cashbox_code']);
  List<Map<String,dynamic>> options(String type) {
    if(type=='supplier'||type=='customer') return parties.where((p)=>s(p['party_kind']).isEmpty||s(p['party_kind'])==type).toList();
    if(type=='expense') return accounts;
    return cashboxes.where((b)=>type=='bank'?b['is_bank_account']==true:b['is_bank_account']!=true).toList();
  }
  Future<Map<String,dynamic>?> pick(String type) async {
    final list=options(type);
    return showDialog<Map<String,dynamic>>(context:context,builder:(ctx) {
      String q='';
      return StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
        title:Text('اختيار '+type+' • بحث F1'),
        content:SizedBox(width:560,height:420,child:Column(children:[
          TextField(autofocus:true,onChanged:(v)=>setLocal(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث بالاسم أو الكود')),
          Expanded(child:ListView(children:list.where((r)=>(entityName(r)+' '+entityCode(r)).toLowerCase().contains(q.toLowerCase())).map((r)=>ListTile(title:Text(entityName(r)),subtitle:Text(entityCode(r)),onTap:()=>Navigator.pop(ctx,r)).toList())),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء'))],
      ));
    });
  }

  Widget field(TextEditingController c,String label,{bool numeric=false,bool readOnly=false}) => TextField(
    controller:c,readOnly:readOnly,keyboardType:numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
    inputFormatters:numeric?[FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]:null,
    decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true));
  Widget drop(String label,String? value,List<DropdownMenuItem<String>> items,ValueChanged<String?> onChanged) =>
    DropdownButtonFormField<String>(value:value,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),items:items,onChanged:onChanged);
  Widget picker(String label,String type,TextEditingController c,bool isFrom) => Row(children:[
    Expanded(child:field(c,label+' • F1',readOnly:true)),
    IconButton.filledTonal(onPressed:()async{final r=await pick(type);if(r==null)return;setState(() {c.text=entityName(r);if(isFrom)fromId=s(r['id']);else toId=s(r['id']);});},icon:const Icon(Icons.search),tooltip:'بحث F1')
  ]);
  Widget quick() => Card(color:purple,child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(tabNames[tabs.index],style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:19)),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh,onPressed:loading?null:load),
      ErpQuickTaskButton(label:'إضافة',icon:Icons.add_circle_outline,onPressed:resetForm),
      ErpQuickTaskButton(label:'حفظ',icon:Icons.save_outlined,onPressed:saving?null:saveCurrent),
      ErpQuickTaskButton(label:'تعديل',icon:Icons.edit_outlined,onPressed:()=>notify('التعديل متاح للمسودات وبحسب صلاحية المستخدم.')),
      ErpQuickTaskButton(label:'حذف',icon:Icons.delete_outline,onPressed:()=>notify('لا يسمح بحذف أي حركة أو شيك بعد الترحيل أو التسوية.')),
      ErpQuickTaskButton(label:'معاينة',icon:Icons.preview_outlined,onPressed:()=>notify('المعاينة تعرض السجلات الحالية في الجدول.')),
      ErpQuickTaskButton(label:'طباعة',icon:Icons.print_outlined,onPressed:()=>notify('تم تجهيز بيانات المعاينة للطباعة.')),
      ErpQuickTaskButton(label:'Excel',icon:Icons.table_view_outlined,onPressed:()=>notify('تصدير Excel سيستخدم قالب التقارير المعتمد.')),
      ErpQuickTaskButton(label:'PDF',icon:Icons.picture_as_pdf_outlined,onPressed:()=>notify('تصدير PDF سيستخدم قالب التقارير المعتمد.')),
    ]))
  ])));
  void notify(String m){if(mounted)setState(()=>message=m);}
  Future<void> saveCurrent() async { switch(tabs.index){case 0:await saveMovement();break;case 1:await saveOrder();break;case 2:await issueCheque(true);break;case 3:await issueCheque(false);break;case 4:await registerBook();break;case 7:await savePolicy();break;} }

  Future<void> saveMovement() async {
    final v=double.tryParse(amount.text.trim());
    if(v==null||v<=0||fromId==null||toId==null||fromName.text.isEmpty||toName.text.isEmpty){setState(()=>error='اختر جهتي الحركة وأدخل قيمة موجبة.');return;}
    if(movementType=='transfer'&&fromId==toId){setState(()=>error='جهة التحويل يجب أن تختلف عن المصدر.');return;}
    await run(()async{await db!.from('erp_cash_movements').insert({'company_id':company,'movement_type':movementType,'from_type':fromType,'from_id':fromId,'from_name':fromName.text,'to_type':toType,'to_id':toId,'to_name':toName.text,'amount':v,'description':description.text,'created_by':db!.auth.currentUser?.id});amount.clear();description.clear();},'تم حفظ الحركة النقدية.');
  }
  Future<void> saveOrder() async {
    final v=double.tryParse(amount.text.trim());
    if(v==null||v<=0||partyName.text.trim().isEmpty){setState(()=>error='أدخل الجهة والقيمة الموجبة.');return;}
    if(!directMode&&salesId==null){setState(()=>error='السياسة تشترط ربط أمر الصرف بأمر بيع.');return;}
    await run(()async{await db!.from('erp_cash_orders').insert({'company_id':company,'order_type':orderType,'party_type':partyType,'party_name':partyName.text.trim(),'amount':v,'description':description.text,'sales_document_id':salesId,'assigned_to_user_id':assigneeId,'status':requireApproval?'draft':'approved','created_by':db!.auth.currentUser?.id});amount.clear();partyName.clear();description.clear();},'تم حفظ أمر الصرف / التوريد.');
  }
  Future<void> registerBook() async {
    final start=int.tryParse(firstCheck.text.trim());
    if(bankId==null||start==null||start<=0){setState(()=>error='اختر حسابًا بنكيًا وأدخل بداية الدفتر.');return;}
    final b=cashboxes.firstWhere((x)=>s(x['id'])==bankId);
    final count=n(b['checkbook_sheet_count']).toInt();
    if(count<1){setState(()=>error='حدد عدد أوراق دفتر الشيكات في بيانات الحساب البنكي.');return;}
    await run(()async{final row=await db!.from('erp_checkbooks').insert({'company_id':company,'bank_cashbox_id':bankId,'first_check_number':start,'sheet_count':count,'created_by':db!.auth.currentUser?.id}).select('id').single();await db!.rpc('erp_register_checkbook',params:{'p_checkbook_id':row['id']});firstCheck.clear();},'تم تسجيل الدفتر وإنشاء أرقام الشيكات.');
  }
  Future<void> issueCheque(bool order) async {
    final v=double.tryParse(chequeAmount.text.trim()), issue=DateTime.tryParse(issueDate.text), due=DateTime.tryParse(dueDate.text);
    if(v==null||v<=0||partyName.text.trim().isEmpty){setState(()=>error='اختر شيكًا متاحًا أو أدخل رقم شيك ائتمان، مع المستفيد والقيمة الموجبة.');return;}
    if(chequeType=='bank'&&chequeId==null){setState(()=>error='لا يمكن اختيار إلا رقم شيك بنكي متاح غير مستخدم.');return;}
    if(chequeType=='credit'&&(bankId==null||int.tryParse(firstCheck.text.trim())==null)){setState(()=>error='حدد الحساب البنكي ورقم شيك الائتمان.');return;}
    if(issue==null||due==null||due.isBefore(issue)){setState(()=>error='تاريخ الاستحقاق لا يسبق تاريخ الإصدار.');return;}
    if(chequeType=='credit'&&!allowCredit){setState(()=>error='شيكات الائتمان غير مفعلة في السياسات.');return;}
    Map<String,dynamic> ch={};
    if(chequeType=='bank'){ch=cheques.firstWhere((x)=>s(x['id'])==chequeId);} else {ch=await db!.from('erp_cheques').insert({'company_id':company,'bank_cashbox_id':bankId,'check_number':int.parse(firstCheck.text.trim()),'cheque_type':'credit','direction':chequeDirection,'issue_date':issueDate.text,'amount':v,'status':'available','created_by':db!.auth.currentUser?.id}).select().single(); chequeId=s(ch['id']);}
    await run(()async{
      await db!.rpc('erp_issue_cheque',params:{'p_cheque_id':chequeId,'p_cheque_type':chequeType,'p_direction':chequeDirection,'p_issue_date':issueDate.text,'p_due_date':dueDate.text,'p_amount':v,'p_payee_type':partyType,'p_payee_id':null,'p_payee_name':partyName.text.trim(),'p_notes':description.text});
      if(order) await db!.from('erp_cash_orders').insert({'company_id':company,'order_type':chequeDirection,'instrument_type':'cheque','cheque_id':chequeId,'party_type':partyType,'party_name':partyName.text.trim(),'amount':v,'description':'شيك رقم '+s(ch['check_number']),'created_by':db!.auth.currentUser?.id});
      chequeAmount.clear();partyName.clear();description.clear();chequeId=null;
    },order?'تم حفظ أمر الشيك.':'تم حفظ حركة الشيك.');
  }
  Future<void> settle(Map<String,dynamic> c) async {
    final date=TextEditingController(text:_today());String result='paid';String? cashbox;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,local)=>AlertDialog(
      title:Text('متابعة الشيك '+s(c['check_number'])),
      content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:result,decoration:const InputDecoration(labelText:'الحالة'),items:const[
          DropdownMenuItem(value:'paid',child:Text('تم السداد')),DropdownMenuItem(value:'returned',child:Text('ارتداد')),DropdownMenuItem(value:'cashed_from_cashbox',child:Text('صرف من الخزينة'))
        ],onChanged:(v)=>local(()=>result=v??result)),
        const SizedBox(height:8),field(date,'تاريخ السداد / الارتداد'),
        if(result=='cashed_from_cashbox')drop('الخزينة',cashbox,[...cashboxes.where((x)=>x['is_bank_account']!=true).map((x)=>DropdownMenuItem(value:s(x['id']),child:Text(s(x['cashbox_name']))))],(v)=>local(()=>cashbox=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد'))],
    )));
    if(yes==true) await run(()async{await db!.rpc('erp_settle_cheque',params:{'p_cheque_id':c['id'],'p_result':result,'p_settlement_date':date.text,'p_method':result=='cashed_from_cashbox'?'cashbox':'bank','p_cashbox_id':cashbox,'p_reference':null});},'تم تحديث حالة الشيك وتاريخ التسوية.');
    date.dispose();
  }
  Future<void> savePolicy() async {await run(()async{await db!.from('erp_financial_policies').upsert({'company_id':company,'cash_issue_mode':directMode?'direct':'sales_order_only','require_cash_order_approval':requireApproval,'allow_credit_cheques':allowCredit,'updated_by':db!.auth.currentUser?.id},onConflict:'company_id');},'تم حفظ السياسات المحاسبية.');}

  Widget grid(List<String> heads,List<List<String>> rows,{List<Widget>? actions}) {
    if(rows.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(16),child:Center(child:Text('لا توجد بيانات حتى الآن.'))));
    return Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),columnSpacing:22,horizontalMargin:12,
      columns:[...heads.map((x)=>DataColumn(label:Text(x,style:const TextStyle(fontWeight:FontWeight.w900)))),if(actions!=null)const DataColumn(label:Text('إجراء'))],
      rows:List.generate(rows.length,(i)=>DataRow(cells:[...rows[i].map((v)=>DataCell(Text(v))),if(actions!=null)DataCell(actions[i])])),
    )));
  }
  Widget section(String title,int count)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),const Spacer(),Chip(label:Text(count.toString()+' سجل'))]));
  List<DropdownMenuItem<String>> get entityTypes=>const[
    DropdownMenuItem(value:'supplier',child:Text('مورد')),DropdownMenuItem(value:'customer',child:Text('عميل')),DropdownMenuItem(value:'expense',child:Text('بند صرف')),DropdownMenuItem(value:'bank',child:Text('بنك')),DropdownMenuItem(value:'cashbox',child:Text('خزينة'))];
  Widget movementView()=>Column(children:[
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Expanded(child:drop('نوع الحركة',movementType,const[DropdownMenuItem(value:'receipt',child:Text('سند قبض')),DropdownMenuItem(value:'payment',child:Text('سند صرف')),DropdownMenuItem(value:'transfer',child:Text('سند تحويل خزائن'))],(v)=>setState(()=>movementType=v??movementType))),const SizedBox(width:8),Expanded(child:field(amount,'القيمة الموجبة',numeric:true))]),
      const SizedBox(height:8),Row(children:[Expanded(child:drop('جهة الصرف من',fromType,entityTypes,(v)=>setState(() {fromType=v??fromType;fromId=null;fromName.clear();}))),const SizedBox(width:8),Expanded(child:picker('اسم الجهة من',fromType,fromName,true))]),
      const SizedBox(height:8),Row(children:[Expanded(child:drop('وجهة الصرف إلى',toType,entityTypes,(v)=>setState(() {toType=v??toType;toId=null;toName.clear();}))),const SizedBox(width:8),Expanded(child:picker('اسم الجهة إلى',toType,toName,false))]),
      const SizedBox(height:8),field(description,'البيان'),Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:saveMovement,child:const Text('حفظ الحركة'))),
    ]))),
    section('حركة نقدية',movements.length),
    grid(['م','مسلسل الحركة','النوع','من','إلى','القيمة','التاريخ'],movements.map((r)=>[s(r['movement_no']),s(r['movement_number']),s(r['movement_type']),s(r['from_name']),s(r['to_name']),money(r['amount']),s(r['movement_date'])]).toList())
  ]);
  Widget orderView()=>Column(children:[
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Expanded(child:drop('نوع الأمر',orderType,const[DropdownMenuItem(value:'payment',child:Text('أمر صرف نقدية')),DropdownMenuItem(value:'receipt',child:Text('أمر توريد نقدية'))],(v)=>setState(()=>orderType=v??orderType))),const SizedBox(width:8),Expanded(child:drop('نوع الجهة',partyType,const[DropdownMenuItem(value:'supplier',child:Text('مورد')),DropdownMenuItem(value:'customer',child:Text('عميل')),DropdownMenuItem(value:'expense',child:Text('بند صرف')),DropdownMenuItem(value:'bank',child:Text('بنك'))],(v)=>setState(()=>partyType=v??partyType)))]),
      const SizedBox(height:8),field(partyName,'اسم الجهة'),const SizedBox(height:8),field(amount,'القيمة الموجبة',numeric:true),const SizedBox(height:8),field(description,'البيان'),
      const SizedBox(height:8),drop('يظهر لدى المستخدم',assigneeId,[const DropdownMenuItem<String>(value:null,child:Text('كل المستخدمين المصرح لهم')),...users.where((u)=>s(u['auth_user_id']).isNotEmpty).map((u)=>DropdownMenuItem(value:s(u['auth_user_id']),child:Text(s(u['name_ar']))))],(v)=>setState(()=>assigneeId=v)),
      if(!directMode)Padding(padding:const EdgeInsets.only(top:8),child:drop('أمر البيع المرتبط',salesId,[const DropdownMenuItem<String>(value:null,child:Text('اختر أمر بيع')),...sales.map((d)=>DropdownMenuItem(value:s(d['id']),child:Text('أمر '+s(d['document_number'])+' • '+money(d['grand_total']))))],(v)=>setState(()=>salesId=v))),
      Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:saveOrder,child:const Text('حفظ الأمر'))),
    ]))),
    section('أوامر الصرف / التوريد النقدية',orders.where((o)=>s(o['instrument_type'])!='cheque').length),
    grid(['المسلسل','النوع','الجهة','القيمة','الحالة','المستخدم'],orders.where((o)=>s(o['instrument_type'])!='cheque').map((r)=>[s(r['order_number']),s(r['order_type']),s(r['party_name']),money(r['amount']),s(r['status']),users.where((u)=>s(u['auth_user_id'])==s(r['assigned_to_user_id'])).isEmpty?'عام':users.firstWhere((u)=>s(u['auth_user_id'])==s(r['assigned_to_user_id']))['name_ar'].toString()]).toList())
  ]);
  Widget chequeView(bool isOrder)=>Column(children:[
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Expanded(child:drop('نوع الشيك',chequeType,const[DropdownMenuItem(value:'bank',child:Text('شيك بنكي')),DropdownMenuItem(value:'credit',child:Text('شيك ائتمان'))],(v)=>setState(() {chequeType=v??chequeType;chequeId=null;}))),const SizedBox(width:8),Expanded(child:drop('نوع الحركة',chequeDirection,const[DropdownMenuItem(value:'payment',child:Text('صرف / دفع')),DropdownMenuItem(value:'receipt',child:Text('توريد / قبض'))],(v)=>setState(()=>chequeDirection=v??chequeDirection)))]),
      const SizedBox(height:8),
      if(chequeType=='bank')drop('الشيك المتاح غير المستخدم',chequeId,[const DropdownMenuItem<String>(value:null,child:Text('اختر الشيك')),...cheques.where((c)=>s(c['status'])=='available'&&s(c['cheque_type'])=='bank').map((c)=>DropdownMenuItem(value:s(c['id']),child:Text(s(c['check_number'])+' • '+cashboxName(s(c['bank_cashbox_id'])))))],(v)=>setState(()=>chequeId=v))
      else Column(children:[drop('الحساب البنكي',bankId,[const DropdownMenuItem<String>(value:null,child:Text('اختر الحساب البنكي')),...cashboxes.where((b)=>b['is_bank_account']==true).map((b)=>DropdownMenuItem(value:s(b['id']),child:Text(s(b['cashbox_name']))))],(v)=>setState(() {bankId=v;chequeId=null;})),const SizedBox(height:8),field(firstCheck,'رقم شيك الائتمان',numeric:true)]),
      const SizedBox(height:8),Row(children:[Expanded(child:field(issueDate,'تاريخ الإصدار')),const SizedBox(width:8),Expanded(child:field(dueDate,'تاريخ الاستحقاق'))]),
      const SizedBox(height:8),field(partyName,'اسم المستفيد'),const SizedBox(height:8),field(chequeAmount,'قيمة الشيك الموجبة',numeric:true),const SizedBox(height:8),field(description,'البيان'),
      Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:()=>issueCheque(isOrder),child:Text(isOrder?'حفظ أمر الشيك':'حفظ حركة الشيك'))),
    ]))),
    section(isOrder?'أوامر الشيكات':'حركة الشيكات',cheques.length),
    grid(['رقم الشيك','النوع','الاتجاه','الإصدار','الاستحقاق','القيمة','الحالة'],cheques.map((c)=>[s(c['check_number']),s(c['cheque_type']),s(c['direction']),s(c['issue_date']),s(c['due_date']),money(c['amount']),s(c['status'])]).toList())
  ]);
  Widget booksView()=>Column(children:[
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      drop('الحساب البنكي',bankId,[const DropdownMenuItem<String>(value:null,child:Text('اختر الحساب')),...cashboxes.where((b)=>b['is_bank_account']==true).map((b)=>DropdownMenuItem(value:s(b['id']),child:Text(s(b['cashbox_name'])+' • '+s(b['checkbook_sheet_count'])+' ورقة')))],(v)=>setState(()=>bankId=v)),
      const SizedBox(height:8),field(firstCheck,'بداية الدفتر / أول رقم شيك',numeric:true),
      Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:registerBook,child:const Text('حفظ وتسجيل الدفتر'))),
    ]))),
    section('دفاتر الشيكات',books.length),
    grid(['م','مسلسل الدفتر','الحساب البنكي','البداية','عدد الأوراق','الحالة'],books.map((b)=>[s(b['book_no']),s(b['book_number']),cashboxName(s(b['bank_cashbox_id'])),s(b['first_check_number']),s(b['sheet_count']),b['registered']==true?'مسجل':'مسودة']).toList()),
    section('أرقام الشيكات',cheques.length),
    grid(['رقم الشيك','الحساب','النوع','الحالة','المستفيد','القيمة'],cheques.map((c)=>[s(c['check_number']),cashboxName(s(c['bank_cashbox_id'])),s(c['cheque_type']),s(c['status']),s(c['payee_name']),money(c['amount'])]).toList())
  ]);
  Widget trackingView(bool credit)=>Column(children:[
    if(!credit)drop('فلتر الشيكات',trackingFilter,const[DropdownMenuItem(value:'all',child:Text('كل الشيكات البنكية')),DropdownMenuItem(value:'payment',child:Text('شيكات الدفع')),DropdownMenuItem(value:'receipt',child:Text('شيكات القبض'))],(v)=>setState(()=>trackingFilter=v??'all')),
    section(credit?'شيكات الائتمان':'متابعة الشيكات البنكية',cheques.where((c)=>s(c['cheque_type'])==(credit?'credit':'bank')&&(credit||s(c['status'])=='issued'||s(c['status'])=='under_collection')&&(credit||trackingFilter=='all'||s(c['direction'])==trackingFilter)).length),
    grid(['رقم الشيك','الاتجاه','الإصدار','الاستحقاق','القيمة','المستفيد','الحالة','تاريخ التسوية'],cheques.where((c)=>s(c['cheque_type'])==(credit?'credit':'bank')&&(credit||s(c['status'])=='issued'||s(c['status'])=='under_collection')&&(credit||trackingFilter=='all'||s(c['direction'])==trackingFilter)).map((c)=>[s(c['check_number']),s(c['direction']),s(c['issue_date']),s(c['due_date']),money(c['amount']),s(c['payee_name']),s(c['status']),s(c['settlement_date'])]).toList(),actions:credit?null:cheques.where((c)=>s(c['cheque_type'])=='bank'&&(s(c['status'])=='issued'||s(c['status'])=='under_collection')&&(trackingFilter=='all'||s(c['direction'])==trackingFilter)).map((c)=>IconButton(onPressed:()=>settle(c),icon:const Icon(Icons.edit_calendar,color:purple))).toList())
  ]);
  Widget policyView()=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('السياسات المحاسبية',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
    SwitchListTile(value:directMode,onChanged:(v)=>setState(()=>directMode=v),title:const Text('السماح بالصرف المباشر دون أمر بيع'),subtitle:const Text('عند الإيقاف يجب ربط أمر الصرف بأمر بيع وتحديد المستخدم المستلم.')),
    SwitchListTile(value:requireApproval,onChanged:(v)=>setState(()=>requireApproval=v),title:const Text('اشتراط اعتماد أمر الصرف قبل تنفيذه')),
    SwitchListTile(value:allowCredit,onChanged:(v)=>setState(()=>allowCredit=v),title:const Text('السماح بشيكات الائتمان')),
    const Text('تاريخ الإصدار الافتراضي هو تاريخ اليوم. تعديل التواريخ النهائية والشيكات المسواة محكوم بصلاحيات المستخدم ولا يسمح بتعديل شيك تم صرفه أو ارتداده.'),
    Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:savePolicy,child:const Text('حفظ السياسات')))
  ])));
  static const tabNames=['حركة نقدية','أمر صرف / توريد نقدية','أمر صرف شيكات','حركة صرف / توريد شيكات','تسجيل دفاتر شيكات','متابعة الشيكات','شيكات الائتمان','السياسات المحاسبية'];
  Widget tabBody(int i)=>switch(i){0=>movementView(),1=>orderView(),2=>chequeView(true),3=>chequeView(false),4=>booksView(),5=>trackingView(false),6=>trackingView(true),_=>policyView()};
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    quick(),if(loading||saving)const LinearProgressIndicator(),
    if(error!=null)Container(color:Colors.red.shade50,padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),
    if(message!=null)Container(color:Colors.green.shade50,padding:const EdgeInsets.all(8),child:Text(message!,style:const TextStyle(color:Colors.green))),
    Material(color:Colors.white,child:TabBar(controller:tabs,isScrollable:true,labelColor:purple,indicatorColor:const Color(0xFFFFA015),tabs:tabNames.map((x)=>Tab(text:x)).toList())),
    Expanded(child:TabBarView(controller:tabs,children:List.generate(8,(i)=>SingleChildScrollView(padding:const EdgeInsets.all(10),child:tabBody(i))))),
  ]));
}