import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/erp_quick_task_button.dart';

class _CheckbookDraftRow {
  String? bankId;
  final TextEditingController firstCheck = TextEditingController();
  void dispose() => firstCheck.dispose();
}

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
  List<String> chequeEditRoles=['owner','admin','accountant'];
  List<String> chequeDateRoles=['owner','admin','accountant'];
  String? error, message, fromId, toId, bankId, chequeId, assigneeId, salesId, counterAccountId, orderPartyId;
  String movementType = 'receipt', fromType = 'customer', toType = 'cashbox', orderType = 'payment';
  String partyType = 'supplier', chequeType = 'bank', chequeDirection = 'payment', trackingFilter = 'all';
  final amount = TextEditingController(), description = TextEditingController(), fromName = TextEditingController(), toName = TextEditingController();
  final partyName = TextEditingController(), firstCheck = TextEditingController(), issueDate = TextEditingController(text: _todayDisplay());
  final movementDate = TextEditingController(text: _todayDisplay());
  final dueDate = TextEditingController(text: _todayDisplay()), chequeAmount = TextEditingController();
  List<Map<String,dynamic>> cashboxes=[], accounts=[], parties=[], users=[], sales=[], movements=[], orders=[], books=[], cheques=[];
  final List<_CheckbookDraftRow> _bookDrafts = <_CheckbookDraftRow>[_CheckbookDraftRow()];
  static String _todayDisplay(){final d=DateTime.now();return d.day.toString().padLeft(2,'0')+'-'+d.month.toString().padLeft(2,'0')+'-'+d.year.toString().padLeft(4,'0');}
  DateTime? parseDisplayDate(String value){final t=value.trim();final iso=DateTime.tryParse(t);if(iso!=null)return iso;final p=t.split('-');if(p.length!=3)return null;final d=int.tryParse(p[0]),m=int.tryParse(p[1]),y=int.tryParse(p[2]);if(d==null||m==null||y==null)return null;final v=DateTime(y,m,d);return v.year==y&&v.month==m&&v.day==d?v:null;}
  String isoDate(String value)=>parseDisplayDate(value)?.toIso8601String().substring(0,10)??value;
  String displayDate(dynamic value){final d=parseDisplayDate(s(value));return d==null?s(value):d.day.toString().padLeft(2,'0')+'-'+d.month.toString().padLeft(2,'0')+'-'+d.year.toString().padLeft(4,'0');}
  String get company => widget.companyId?.trim() ?? '';
  String s(dynamic v) => (v ?? '').toString();
  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse(s(v)) ?? 0;
  String money(dynamic v) => n(v).toStringAsFixed(2);
  String chequeAmountLabel(Map<String,dynamic> c)=>s(c['status'])=='available'?'غير محدد':money(c['amount']);
  List<Map<String,dynamic>> maps(dynamic x) => (x as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();

  int initial() {
    const names=['حركة نقدية','أمر صرف / توريد نقدية','أمر صرف شيكات','حركة صرف / توريد شيكات','تسجيل دفاتر شيكات','متابعة الشيكات','شيكات الائتمان','السياسات المحاسبية'];
    final i=names.indexOf(widget.initialView); return i<0?0:i;
  }
  @override void initState() {
    super.initState(); try { db=Supabase.instance.client; } catch (_) {}
    tabs=TabController(length:8,vsync:this,initialIndex:initial());
    if(company.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_)=>load());
  }
  @override void dispose() {
    tabs.dispose(); for(final row in _bookDrafts) { row.dispose(); } for(final c in [amount,description,fromName,toName,partyName,firstCheck,issueDate,dueDate,chequeAmount,movementDate]) {c.dispose();} super.dispose();
  }

  Future<List<Map<String,dynamic>>> fetchAllRows(String table,String orderColumn) async {
    final all=<Map<String,dynamic>>[];
    for(var offset=0;;offset+=500){
      final page=await db!.from(table).select('*').eq('company_id',company).order(orderColumn,ascending:false).order('id',ascending:false).range(offset,offset+499);
      all.addAll(maps(page));
      if(page.length<500)break;
    }
    return all;
  }

  Future<void> load() async {
    if(db==null || company.isEmpty) { setState(()=>error='لا توجد شركة مرتبطة بالمستخدم الحالي.'); return; }
    setState(()=>loading=true);
    try {
      final r=await Future.wait<dynamic>(<Future<dynamic>>[
        (() async => await db!.from('erp_cashboxes').select('id,cashbox_code,cashbox_name,is_bank_account,checkbook_sheet_count').eq('company_id',company).eq('is_active',true).order('cashbox_name'))(),
        (() async => await db!.from('erp_accounts').select('id,account_code,account_name').eq('company_id',company).eq('is_active',true).eq('is_postable',true).limit(2000))(),
        (() async => await db!.from('erp_parties').select('id,party_code,party_name,party_kind').eq('company_id',company).eq('is_active',true).limit(2000))(),
        (() async => await db!.from('erp_users').select('id,auth_user_id,user_code,name_ar').eq('company_id',company).eq('is_active',true).limit(1000))(),
        (() async => await db!.from('erp_sales_documents').select('id,document_number,grand_total').eq('company_id',company).eq('document_type','order').limit(300))(),
        (() async => await db!.from('erp_cash_movements').select('*').eq('company_id',company).order('movement_no',ascending:false).limit(300))(),
        (() async => await db!.from('erp_cash_orders').select('*').eq('company_id',company).order('order_no',ascending:false).limit(300))(),
        fetchAllRows('erp_checkbooks','book_no'),
        fetchAllRows('erp_cheques','check_number'),
        (() async => await db!.from('erp_financial_policies').select().eq('company_id',company).maybeSingle())(),
      ]);
      if(!mounted)return;
      final p=r[9] as Map<String,dynamic>?;
      setState(() {
        cashboxes=maps(r[0]); accounts=maps(r[1]); parties=maps(r[2]); users=maps(r[3]); sales=maps(r[4]);
        movements=maps(r[5]); orders=maps(r[6]); books=maps(r[7]); cheques=maps(r[8]);
        directMode=p==null || s(p['cash_issue_mode'])!='sales_order_only';
        requireApproval=p?['require_cash_order_approval']!=false; allowCredit=p?['allow_credit_cheques']!=false;
        chequeEditRoles=p!=null&&p['cheque_edit_roles'] is List?(p['cheque_edit_roles'] as List).map((x)=>x.toString()).toList():['owner','admin','accountant'];
        chequeDateRoles=p!=null&&p['cheque_issue_date_edit_roles'] is List?(p['cheque_issue_date_edit_roles'] as List).map((x)=>x.toString()).toList():['owner','admin','accountant'];
        loading=false; error=null;
      });
    } catch(e) { if(mounted)setState(() {loading=false;error='تعذر تحميل البيانات: '+e.toString();}); }
  }

  Future<void> run(Future<void> Function() action,String ok) async {
    if(saving)return; setState(() {saving=true;error=null;message=null;});
    try { await action(); if(!mounted)return; setState(() {saving=false;message=ok;}); await load(); }
    catch(e) { if(mounted)setState(() {saving=false;error='تعذر التنفيذ: '+e.toString();}); }
  }
  void resetForm() { amount.clear(); description.clear(); fromName.clear(); toName.clear(); partyName.clear(); chequeAmount.clear(); firstCheck.clear(); issueDate.text=_todayDisplay();dueDate.text=_todayDisplay();movementDate.text=_todayDisplay();orderPartyId=null; fromId=null;toId=null;chequeId=null;counterAccountId=null; setState(() {error=null;message='نموذج جديد جاهز.';}); }
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
          Expanded(child:ListView(children:list.where((r)=>(entityName(r)+' '+entityCode(r)).toLowerCase().contains(q.toLowerCase())).map<Widget>((r) { return ListTile(title:Text(entityName(r)),subtitle:Text(entityCode(r)),onTap:()=>Navigator.pop(ctx,r)); }).toList())),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء'))],
      ));
    });
  }

  Widget integerField(TextEditingController c,String label) => TextField(controller:c,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true));
  Widget field(TextEditingController c,String label,{bool numeric=false,bool readOnly=false}) => TextField(
    controller:c,readOnly:readOnly,keyboardType:numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
    inputFormatters:numeric?[FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]:null,
    decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true));
  Widget drop(String label,String? value,List<DropdownMenuItem<String>> items,ValueChanged<String?> onChanged) =>
    DropdownButtonFormField<String>(itemHeight: 40, value:value,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),items:items,onChanged:onChanged);
  Future<void> selectBank() async {final r=await pick('bank');if(r!=null)setState(()=>bankId=s(r['id']));}
  Widget bankPicker(String label)=>Focus(
    onKeyEvent:(node,event){if(event is KeyDownEvent&&event.logicalKey==LogicalKeyboardKey.f1){selectBank();return KeyEventResult.handled;}return KeyEventResult.ignored;},
    child:Row(children:[
      Expanded(child:InputDecorator(decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),child:Text(bankId==null?'اختر الحساب البنكي':cashboxName(bankId!),overflow:TextOverflow.ellipsis))),
      IconButton.filledTonal(onPressed:selectBank,tooltip:'بحث F1',icon:const Icon(Icons.search))
    ]),
  );
  Future<void> selectEndpoint(String type,TextEditingController c,bool isFrom) async {
    final r=await pick(type);if(r==null)return;
    setState(() {c.text=entityName(r);if(isFrom)fromId=s(r['id']);else toId=s(r['id']);});
  }
  Widget picker(String label,String type,TextEditingController c,bool isFrom) => Focus(
    onKeyEvent:(node,event){
      if(event is KeyDownEvent&&event.logicalKey==LogicalKeyboardKey.f1){selectEndpoint(type,c,isFrom);return KeyEventResult.handled;}
      return KeyEventResult.ignored;
    },
    child:Row(children:[
      Expanded(child:field(c,label+' • F1',readOnly:true)),
      IconButton.filledTonal(onPressed:()=>selectEndpoint(type,c,isFrom),icon:const Icon(Icons.search),tooltip:'بحث F1')
    ]),
  );
  String currentSerial(){switch(tabs.index){case 0:return movements.isEmpty?'يُنشأ تلقائيًا عند الحفظ':s(movements.first['movement_number']);case 1:return orders.where((o)=>s(o['instrument_type'])!='cheque').isEmpty?'يُنشأ تلقائيًا عند الحفظ':s(orders.where((o)=>s(o['instrument_type'])!='cheque').first['order_number']);case 2:return orders.where((o)=>s(o['instrument_type'])=='cheque').isEmpty?'يُنشأ تلقائيًا عند الحفظ':s(orders.where((o)=>s(o['instrument_type'])=='cheque').first['order_number']);case 3:return cheques.isEmpty?'يُنشأ تلقائيًا عند الحفظ':s(cheques.first['check_number']);case 4:return books.isEmpty?'يُنشأ تلقائيًا عند الحفظ':s(books.first['book_number']);default:return 'تلقائي وغير قابل للتكرار';}}
  Widget quick() => Card(color:purple,child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(tabNames[tabs.index],style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:19)),
    Text('مسلسل المستند: '+currentSerial(),style:const TextStyle(color:Colors.white70,fontSize:12,fontWeight:FontWeight.w600)),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh,onPressed:loading?null:load),
      ErpQuickTaskButton(label:'إضافة',icon:Icons.add_circle_outline,onPressed:resetForm),
      ErpQuickTaskButton(label:'حفظ',icon:Icons.save_outlined,onPressed:saving?null:saveCurrent),
      ErpQuickTaskButton(label:'تعديل',icon:Icons.edit_outlined,onPressed:editSelected),
      ErpQuickTaskButton(label:'حذف',icon:Icons.delete_outline,onPressed:deleteSelected),
      ErpQuickTaskButton(label:'معاينة',icon:Icons.preview_outlined,onPressed:previewData),
      ErpQuickTaskButton(label:'طباعة',icon:Icons.print_outlined,onPressed:printData),
      ErpQuickTaskButton(label:'Excel',icon:Icons.table_view_outlined,onPressed:exportExcel),
      ErpQuickTaskButton(label:'PDF',icon:Icons.picture_as_pdf_outlined,onPressed:exportPdf),
    ]))
  ])));
  void notify(String m){if(mounted)setState(()=>message=m);}
  Future<void> editSelected() async {
    if(tabs.index==3){
      final editable=cheques.where((c)=>!['paid','returned','cashed_from_cashbox','cancelled'].contains(s(c['status']))).toList();
      if(editable.isEmpty){notify('لا توجد شيكات قابلة للتعديل.');return;}
      final row=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(title:const Text('اختيار شيك للتعديل'),content:SizedBox(width:480,height:330,child:ListView(children:editable.map((x)=>ListTile(title:Text('شيك '+s(x['check_number'])+' • '+s(x['payee_name'])),subtitle:Text(s(x['status'])+' • '+money(x['amount'])),onTap:()=>Navigator.pop(ctx,x))).toList()))));
      if(row!=null)await editCheque(row);return;
    }
    if(tabs.index!=1){notify('التعديل متاح لمسودات أوامر النقدية والشيكات غير المسواة فقط.');return;}
    final drafts=orders.where((o)=>s(o['instrument_type'])!='cheque'&&s(o['status'])=='draft').toList();
    if(drafts.isEmpty){notify('لا توجد أوامر نقدية مسودة للتعديل.');return;}
    final row=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(title:const Text('اختيار أمر للتعديل'),content:SizedBox(width:480,height:330,child:ListView(children:drafts.map((x)=>ListTile(title:Text(s(x['order_number'])+' • '+s(x['party_name'])),subtitle:Text(money(x['amount'])),onTap:()=>Navigator.pop(ctx,x))).toList()))));
    if(row==null)return;
    final value=TextEditingController(text:money(row['amount']));final name=TextEditingController(text:s(row['party_name']));final note=TextEditingController(text:s(row['description']));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('تعديل '+s(row['order_number'])),content:SizedBox(width:450,child:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'الجهة'),const SizedBox(height:8),field(value,'القيمة الموجبة',numeric:true),const SizedBox(height:8),field(note,'البيان')])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));
    if(ok==true){final v=double.tryParse(value.text);if(v==null||v<=0||name.text.trim().isEmpty){notify('أدخل جهة صحيحة وقيمة موجبة.');}else await run(()async{await db!.from('erp_cash_orders').update({'party_name':name.text.trim(),'amount':v,'description':note.text.trim(),'updated_at':DateTime.now().toIso8601String()}).eq('id',s(row['id'])).eq('status','draft');},'تم تعديل أمر الصرف / التوريد.');}
    value.dispose();name.dispose();note.dispose();
  }
  Future<void> deleteSelected() async {
    final drafts=orders.where((o)=>s(o['instrument_type'])!='cheque'&&s(o['status'])=='draft').toList();
    if(tabs.index!=1||drafts.isEmpty){notify('لا يوجد مستند مسودة قابل للإلغاء في الشاشة الحالية. الحركات والشيكات المسواة محفوظة كسجل تدقيقي.');return;}
    final chosen=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('اختيار أمر لإلغائه'),
      content:SizedBox(width:520,height:360,child:ListView(children:drafts.map((o)=>ListTile(title:Text(s(o['order_number'])+' • '+s(o['party_name'])),subtitle:Text(money(o['amount'])+' • '+s(o['order_type'])),onTap:()=>Navigator.pop(ctx,o))).toList())),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
    ));
    if(chosen==null)return;
    final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('تأكيد إلغاء الأمر'),
      content:Text('سيتم إلغاء الأمر '+s(chosen['order_number'])+' مع الاحتفاظ بسجل المراجعة.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد الإلغاء'))],
    ));
    if(confirm==true)await run(()async{await db!.from('erp_cash_orders').update({'status':'cancelled','updated_at':DateTime.now().toIso8601String()}).eq('id',s(chosen['id'])).eq('status','draft');},'تم إلغاء الأمر مع الاحتفاظ بسجل المراجعة.');
  }
  List<String> exportHeaders(){
    switch(tabs.index){
      case 0:return const ['م','مسلسل الحركة','النوع','من نوع','من جهة','إلى نوع','إلى جهة','القيمة','التاريخ','سند الخزينة'];
      case 1:return const ['مسلسل الأمر','النوع','نوع الجهة','الجهة','القيمة','الحالة','المستخدم','أمر البيع'];
      case 2:return const ['مسلسل الأمر','رقم الشيك','نوع الشيك','الجهة','القيمة','الحالة'];
      case 3:case 5:case 6:return const ['رقم الشيك','النوع','الاتجاه','تاريخ الإصدار','الاستحقاق','القيمة','المستفيد','الحالة','تاريخ التسوية'];
      case 4:return const ['مسلسل الدفتر','الحساب البنكي','بداية الدفتر','عدد الأوراق','الحالة'];
      default:return const ['البند','القيمة'];
    }
  }
  List<List<String>> exportRows(){
    switch(tabs.index){
      case 0:return movements.map((r)=>[s(r['movement_no']),s(r['movement_number']),s(r['movement_type']),s(r['from_type']),s(r['from_name']),s(r['to_type']),s(r['to_name']),money(r['amount']),displayDate(r['movement_date']),s(r['cash_voucher_id'])]).toList();
      case 1:return orders.where((o)=>s(o['instrument_type'])!='cheque').map((r)=>[s(r['order_number']),s(r['order_type']),s(r['party_type']),s(r['party_name']),money(r['amount']),s(r['status']),users.where((u)=>s(u['auth_user_id'])==s(r['assigned_to_user_id'])).isEmpty?'عام':s(users.firstWhere((u)=>s(u['auth_user_id'])==s(r['assigned_to_user_id']))['name_ar']),s(r['sales_document_id'])]).toList();
      case 2:return orders.where((o)=>s(o['instrument_type'])=='cheque').map((o)=>[s(o['order_number']),s(cheques.where((c)=>s(c['id'])==s(o['cheque_id'])).isEmpty?'':cheques.firstWhere((c)=>s(c['id'])==s(o['cheque_id']))['check_number']),s(cheques.where((c)=>s(c['id'])==s(o['cheque_id'])).isEmpty?'':cheques.firstWhere((c)=>s(c['id'])==s(o['cheque_id']))['cheque_type']),s(o['party_name']),money(o['amount']),s(o['status'])]).toList();
      case 3:case 5:case 6:return cheques.where((c)=>tabs.index==3||s(c['cheque_type'])==(tabs.index==5?'bank':'credit')).map((c)=>[s(c['check_number']),s(c['cheque_type']),s(c['direction']),displayDate(c['issue_date']),displayDate(c['due_date']),chequeAmountLabel(c),s(c['payee_name']),s(c['status']),displayDate(c['settlement_date'])]).toList();
      case 4:return books.map((b)=>[s(b['book_number']),cashboxName(s(b['bank_cashbox_id'])),s(b['first_check_number']),s(b['sheet_count']),b['registered']==true?'مسجل':'مسودة']).toList();
      default:return [];
    }
  }
  Future<Uint8List> exportPdfBytes() async {
    final headers=exportHeaders().reversed.toList();
    final rows=exportRows().map((r)=>r.reversed.toList()).toList();
    final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final pdf=pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4.landscape,margin:const pw.EdgeInsets.all(20),theme:pw.ThemeData.withFont(base:font,bold:font),build:(_)=>[
      pw.Text('سلسلة — '+tabNames[tabs.index],textAlign:pw.TextAlign.right,style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold)),
      pw.SizedBox(height:5),
      pw.Text('تاريخ التقرير: '+_todayDisplay()+' • عدد السجلات: '+rows.length.toString(),textAlign:pw.TextAlign.right,style:const pw.TextStyle(fontSize:9)),
      pw.SizedBox(height:12),
      if(rows.isEmpty)pw.Text('لا توجد بيانات.',textAlign:pw.TextAlign.right)
      else pw.TableHelper.fromTextArray(headers:headers,data:rows,headerStyle:pw.TextStyle(fontSize:8,fontWeight:pw.FontWeight.bold),cellStyle:const pw.TextStyle(fontSize:8),cellAlignment:pw.Alignment.centerRight,headerAlignment:pw.Alignment.centerRight),
    ]));
    return Uint8List.fromList(await pdf.save());
  }
  Future<void> exportExcel() async {
    final rows=exportRows();if(rows.isEmpty){notify('لا توجد سجلات لتصديرها.');return;}
    setState(() {loading=true;error=null;message=null;});
    try{
      final book=Excel.createExcel();final sheet=book[tabNames[tabs.index].replaceAll('/','-').substring(0,tabNames[tabs.index].replaceAll('/','-').length>31?31:tabNames[tabs.index].replaceAll('/','-').length)];
      sheet.appendRow(exportHeaders().map((x)=>TextCellValue(x)).toList());
      for(final row in rows){sheet.appendRow(row.map((x)=>TextCellValue(x)).toList());}
      final bytes=book.encode();if(bytes==null||bytes.isEmpty)throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(name:'silsila_finance_'+DateTime.now().millisecondsSinceEpoch.toString(),bytes:Uint8List.fromList(bytes),fileExtension:'xlsx',mimeType:MimeType.microsoftExcel);
      if(mounted)setState(()=>message='تم تصدير '+rows.length.toString()+' سجل إلى Excel.');
    }catch(e){if(mounted)setState(()=>error='تعذر تصدير Excel: '+e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> exportPdf() async {
    final rows=exportRows();if(rows.isEmpty){notify('لا توجد سجلات لتصديرها.');return;}
    setState(() {loading=true;error=null;message=null;});
    try{final bytes=await exportPdfBytes();await FileSaver.instance.saveFile(name:'silsila_finance_'+DateTime.now().millisecondsSinceEpoch.toString(),bytes:bytes,fileExtension:'pdf',mimeType:MimeType.pdf);if(mounted)setState(()=>message='تم إنشاء ملف PDF.');}
    catch(e){if(mounted)setState(()=>error='تعذر إنشاء PDF: '+e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> printData() async {
    if(exportRows().isEmpty){notify('لا توجد سجلات للطباعة.');return;}
    setState(() {loading=true;error=null;message=null;});
    try{final bytes=await exportPdfBytes();await Printing.layoutPdf(onLayout:(_)=>Future.value(bytes),name:'silsila_finance.pdf');}
    catch(e){if(mounted)setState(()=>error='تعذرت الطباعة: '+e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> previewData() async {
    final headers=exportHeaders(),rows=exportRows();
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('معاينة '+tabNames[tabs.index]),content:SizedBox(width:850,height:460,child:rows.isEmpty?const Center(child:Text('لا توجد بيانات للمعاينة.')):SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:headers.map((h)=>DataColumn(label:Text(h))).toList(),rows:rows.take(250).map((r)=>DataRow(cells:r.map((v)=>DataCell(Text(v))).toList())).toList()))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));
  }
  Future<void> saveCurrent() async { switch(tabs.index){case 0:await saveMovement();break;case 1:await saveOrder();break;case 2:await issueCheque(true);break;case 3:await issueCheque(false);break;case 4:await registerBook();break;case 7:await savePolicy();break;} }

  Future<void> saveMovement() async {
    final v=double.tryParse(amount.text.trim());
    if(parseDisplayDate(movementDate.text)==null){setState(()=>error='أدخل تاريخ الحركة بصيغة DD-MM-YYYY.');return;}
    if(v==null||v<=0||fromId==null||toId==null||fromName.text.isEmpty||toName.text.isEmpty){setState(()=>error='اختر جهتي الحركة وأدخل قيمة موجبة.');return;}
    if(movementType=='transfer'&&fromId==toId){setState(()=>error='جهة التحويل يجب أن تختلف عن المصدر.');return;}
    if(movementType=='receipt'&&toType!='cashbox'&&toType!='bank'){setState(()=>error='جهة التوريد يجب أن تكون خزينة أو بنك.');return;}
    if(movementType=='payment'&&fromType!='cashbox'&&fromType!='bank'){setState(()=>error='جهة الصرف يجب أن تكون خزينة أو بنك.');return;}
    if(movementType=='transfer'&&((fromType!='cashbox'&&fromType!='bank')||(toType!='cashbox'&&toType!='bank'))){setState(()=>error='التحويل يتم بين الخزائن أو الحسابات البنكية فقط.');return;}
    if(movementType!='transfer'&&counterAccountId==null){setState(()=>error='حدد الحساب المقابل للحركة حتى يتم إنشاء سند الخزينة.');return;}
    await run(()async{await db!.rpc('erp_create_cash_movement',params:{
      'p_company_id':company,'p_movement_type':movementType,'p_from_type':fromType,'p_from_id':fromId,'p_from_name':fromName.text,
      'p_to_type':toType,'p_to_id':toId,'p_to_name':toName.text,'p_amount':v,'p_description':description.text,
      'p_counter_account_id':counterAccountId,'p_movement_date':isoDate(movementDate.text)
    });amount.clear();description.clear();},'تم حفظ الحركة وإنشاء سند خزينة مسودة مرتبط بها. يلزم ترحيل السند لتحديث الأرصدة والقيود.');
  }
  Future<void> postMovement(Map<String,dynamic> row) async {
    final id=s(row['cash_voucher_id']);
    if(id.isEmpty){notify('لا يوجد سند خزينة مرتبط بهذه الحركة.');return;}
    final voucher=await db!.from('erp_cash_vouchers').select('status').eq('id',id).maybeSingle();
    if(voucher==null||s(voucher['status'])!='draft'){notify('سند الخزينة مرحّل بالفعل أو غير متاح للترحيل.');return;}
    await run(()async{await db!.rpc('erp_post_cash_voucher',params:{'p_voucher_id':id});},'تم ترحيل سند الحركة وتحديث القيد المحاسبي.');
  }
  Future<void> approveOrder(Map<String,dynamic> row) async {
    await run(()async{await db!.from('erp_cash_orders').update({'status':'approved','approved_by':db!.auth.currentUser?.id,'approved_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()}).eq('id',s(row['id'])).eq('status','draft');},'تم اعتماد أمر الصرف / التوريد.');
  }
  Future<void> convertOrder(Map<String,dynamic> row) async {
    String? cashbox;String? account;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,local)=>AlertDialog(
      title:Text('تنفيذ الأمر '+s(row['order_number'])),
      content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,children:[
        drop('الخزينة',cashbox,[const DropdownMenuItem<String>(value:null,child:Text('اختر الخزينة')),...cashboxes.where((b)=>b['is_bank_account']!=true).map((b)=>DropdownMenuItem(value:s(b['id']),child:Text(s(b['cashbox_name']))))],(v)=>local(()=>cashbox=v)),
        const SizedBox(height:8),drop('الحساب المقابل',account,[const DropdownMenuItem<String>(value:null,child:Text('اختر الحساب المقابل')),...accounts.map((a)=>DropdownMenuItem(value:s(a['id']),child:Text(s(a['account_code'])+' — '+s(a['account_name']))))],(v)=>local(()=>account=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تنفيذ'))],
    )));
    if(ok!=true)return;
    if(cashbox==null||account==null){notify('حدد الخزينة والحساب المقابل قبل التنفيذ.');return;}
    await run(()async{await db!.rpc('erp_convert_cash_order',params:{'p_order_id':row['id'],'p_cashbox_id':cashbox,'p_counter_account_id':account});},'تم تنفيذ الأمر وإنشاء حركة نقدية وسند خزينة مسودة.');
  }
  Future<void> saveOrder() async {
    final v=double.tryParse(amount.text.trim());
    if(v==null||v<=0||partyName.text.trim().isEmpty||orderPartyId==null){setState(()=>error='اختر الجهة من البحث وأدخل القيمة الموجبة.');return;}
    if(!directMode&&salesId==null){setState(()=>error='السياسة تشترط ربط أمر الصرف بأمر بيع.');return;}
    await run(()async{await db!.from('erp_cash_orders').insert({'company_id':company,'order_type':orderType,'party_type':partyType,'party_name':partyName.text.trim(),'party_id':orderPartyId,'amount':v,'description':description.text,'sales_document_id':salesId,'assigned_to_user_id':assigneeId,'status':requireApproval?'draft':'approved','created_by':db!.auth.currentUser?.id});amount.clear();partyName.clear();description.clear();orderPartyId=null;},'تم حفظ أمر الصرف / التوريد.');
  }
  Future<void> selectBookBank(_CheckbookDraftRow row) async {
    final selected=await pick('bank');
    if(selected!=null && mounted) setState(()=>row.bankId=s(selected['id']));
  }
  Widget bookBankPicker(_CheckbookDraftRow row) => Focus(
    onKeyEvent:(node,event){if(event is KeyDownEvent&&event.logicalKey==LogicalKeyboardKey.f1){selectBookBank(row);return KeyEventResult.handled;}return KeyEventResult.ignored;},
    child:Row(children:[
      Expanded(child:InputDecorator(decoration:const InputDecoration(labelText:'الحساب البنكي',border:OutlineInputBorder(),isDense:true),child:Text(row.bankId==null?'اختر الحساب البنكي':cashboxName(row.bankId!),overflow:TextOverflow.ellipsis))),
      IconButton.filledTonal(onPressed:()=>selectBookBank(row),tooltip:'بحث F1',icon:const Icon(Icons.search)),
    ]),
  );
  void addBookDraftRow(){setState(()=>_bookDrafts.add(_CheckbookDraftRow()));}
  void removeBookDraftRow(int index){if(_bookDrafts.length<=1)return;setState(()=>_bookDrafts.removeAt(index).dispose());}
  Future<void> registerBook() async {
    final valid=<Map<String,dynamic>>[];
    for(var i=0;i<_bookDrafts.length;i++){
      final draft=_bookDrafts[i];
      final startNumber=int.tryParse(draft.firstCheck.text.trim());
      final bank=cashboxes.where((x)=>s(x['id'])==draft.bankId && x['is_bank_account']==true);
      if(bank.isEmpty||startNumber==null||startNumber<=0){setState(()=>error='راجع الحساب البنكي وبداية الدفتر في السطر '+(i+1).toString()+'.');return;}
      final count=n(bank.first['checkbook_sheet_count']).toInt();
      if(count<1){setState(()=>error='حدد عدد أوراق دفتر الشيكات في بيانات الحساب البنكي.');return;}
      valid.add({'bank_id':draft.bankId,'start':startNumber,'count':count});
    }
    for(var i=0;i<valid.length;i++){
      final current=valid[i];
      final currentStart=current['start'] as int;
      final currentEnd=currentStart+(current['count'] as int)-1;
      final bankIdValue=current['bank_id'];
      for(final existing in books.where((b)=>b['registered']==true&&s(b['bank_cashbox_id'])==s(bankIdValue))){
        final existingStart=n(existing['first_check_number']).toInt();
        final existingEnd=existingStart+n(existing['sheet_count']).toInt()-1;
        if(currentStart<=existingEnd&&existingStart<=currentEnd){setState(()=>error='مدى أرقام الدفتر في السطر '+(i+1).toString()+' يتداخل مع دفتر مسجل بالفعل.');return;}
      }
      for(var j=0;j<i;j++){
        final previous=valid[j];
        if(s(previous['bank_id'])!=s(bankIdValue))continue;
        final previousStart=previous['start'] as int;
        final previousEnd=previousStart+(previous['count'] as int)-1;
        if(currentStart<=previousEnd&&previousStart<=currentEnd){setState(()=>error='أرقام الدفاتر الجديدة متداخلة بين السطرين '+(j+1).toString()+' و'+(i+1).toString()+'.');return;}
      }
    }
    await run(()async{
      await db!.rpc('erp_register_checkbooks_batch',params:{
        'p_company_id':company,
        'p_books':valid.map((draft)=>{'bank_cashbox_id':draft['bank_id'],'first_check_number':draft['start']}).toList(),
      });
      for(final draft in _bookDrafts){draft.dispose();}
      _bookDrafts..clear()..add(_CheckbookDraftRow());
    },'تم تسجيل '+valid.length.toString()+' دفتر/دفاتر وإنشاء أرقام الشيكات المتاحة في عملية واحدة.');
  }
  Future<void> issueCheque(bool order) async {
    final v=double.tryParse(chequeAmount.text.trim()), issue=parseDisplayDate(issueDate.text), due=parseDisplayDate(dueDate.text);
    if(v==null||v<=0||partyName.text.trim().isEmpty){setState(()=>error='اختر شيكًا متاحًا أو أدخل رقم شيك ائتمان، مع المستفيد والقيمة الموجبة.');return;}
    if(chequeType=='bank'&&chequeId==null){setState(()=>error='لا يمكن اختيار إلا رقم شيك بنكي متاح غير مستخدم.');return;}
    if(chequeType=='credit'&&(bankId==null||int.tryParse(firstCheck.text.trim())==null)){setState(()=>error='حدد الحساب البنكي ورقم شيك الائتمان.');return;}
    if(issue==null||due==null||due.isBefore(issue)){setState(()=>error='تاريخ الاستحقاق لا يسبق تاريخ الإصدار.');return;}
    if(chequeType=='credit'&&!allowCredit){setState(()=>error='شيكات الائتمان غير مفعلة في السياسات.');return;}
    await run(()async{
      String selectedId=chequeId??'';
      Map<String,dynamic> ch={};
      if(chequeType=='bank'){ch=cheques.firstWhere((x)=>s(x['id'])==selectedId);}
      else {ch=await db!.from('erp_cheques').insert({'company_id':company,'bank_cashbox_id':bankId,'check_number':int.parse(firstCheck.text.trim()),'cheque_type':'credit','direction':chequeDirection,'issue_date':isoDate(issueDate.text),'amount':v,'status':'available','created_by':db!.auth.currentUser?.id}).select().single();selectedId=s(ch['id']);}
      await db!.rpc('erp_issue_cheque',params:{'p_cheque_id':selectedId,'p_cheque_type':chequeType,'p_direction':chequeDirection,'p_issue_date':isoDate(issueDate.text),'p_due_date':isoDate(dueDate.text),'p_amount':v,'p_payee_type':partyType,'p_payee_id':null,'p_payee_name':partyName.text.trim(),'p_notes':description.text});
      if(order){final savedOrder=await db!.from('erp_cash_orders').insert({'company_id':company,'order_type':chequeDirection,'instrument_type':'cheque','cheque_id':selectedId,'party_type':partyType,'party_name':partyName.text.trim(),'amount':v,'description':'شيك رقم '+s(ch['check_number']),'status':'converted','created_by':db!.auth.currentUser?.id}).select('id').single();await db!.from('erp_cheques').update({'order_id':savedOrder['id'],'updated_by':db!.auth.currentUser?.id}).eq('id',selectedId);}
      chequeAmount.clear();partyName.clear();description.clear();chequeId=null;if(chequeType=='credit')firstCheck.clear();
    },order?'تم حفظ أمر الشيك.':'تم حفظ حركة الشيك.');
  }
  Future<void> editCheque(Map<String,dynamic> c) async {
    final issue=TextEditingController(text:displayDate(c['issue_date']));final due=TextEditingController(text:displayDate(c['due_date']));
    final value=TextEditingController(text:money(c['amount']));final payee=TextEditingController(text:s(c['payee_name']));final notes=TextEditingController(text:s(c['notes']));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('تعديل بيانات الشيك '+s(c['check_number'])),
      content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(issue,'تاريخ الإصدار DD-MM-YYYY'),const SizedBox(height:8),field(due,'تاريخ الاستحقاق DD-MM-YYYY'),const SizedBox(height:8),field(value,'القيمة الموجبة',numeric:true),const SizedBox(height:8),field(payee,'اسم المستفيد'),const SizedBox(height:8),field(notes,'ملاحظات'),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ التعديل'))],
    ));
    if(ok==true){final a=double.tryParse(value.text);final d1=parseDisplayDate(issue.text);final d2=parseDisplayDate(due.text);
      if(a==null||a<=0||d1==null||d2==null||d2.isBefore(d1)){notify('راجع قيمة الشيك وتواريخه.');}
      else await run(()async{await db!.rpc('erp_update_cheque_details',params:{'p_cheque_id':c['id'],'p_issue_date':isoDate(issue.text),'p_due_date':isoDate(due.text),'p_amount':a,'p_payee_type':s(c['payee_type']).isEmpty?'supplier':s(c['payee_type']),'p_payee_name':payee.text,'p_notes':notes.text});},'تم تعديل الشيك وفق صلاحيات المستخدم.');
    }
    issue.dispose();due.dispose();value.dispose();payee.dispose();notes.dispose();
  }
  Future<void> cancelCheque(Map<String,dynamic> cheque) async {
    final reason=TextEditingController();
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('إلغاء الشيك رقم '+s(cheque['check_number'])),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('الإلغاء متاح للشيكات غير المستخدمة فقط. سيظل رقم الشيك محفوظًا ولن يعود متاحًا للصرف.'),
        const SizedBox(height:10),TextField(controller:reason,maxLines:2,decoration:const InputDecoration(labelText:'سبب الإلغاء (مطلوب)',border:OutlineInputBorder())),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('تأكيد الإلغاء'))],
    ));
    if(yes==true){
      if(reason.text.trim().isEmpty){notify('اكتب سبب إلغاء الشيك أولًا.');}
      else await run(()async{
        await db!.rpc('erp_cancel_available_cheque',params:{'p_cheque_id':s(cheque['id']),'p_reason':reason.text.trim()});
      },'تم إلغاء الشيك مع حفظ السبب وسجل المراجعة ومنع إعادة استخدام رقمه.');
    }
    reason.dispose();
  }
  Future<void> settle(Map<String,dynamic> c) async {
    final date=TextEditingController(text:_todayDisplay());String result='paid';String? cashbox;String? counterAccount;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,local)=>AlertDialog(
      title:Text('متابعة الشيك '+s(c['check_number'])),
      content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(itemHeight: 40, value:result,decoration:const InputDecoration(labelText:'الحالة'),items:[
          DropdownMenuItem(value:'paid',child:Text(s(c['direction'])=='receipt'?'تم التحصيل':'تم السداد')),DropdownMenuItem(value:'returned',child:Text('ارتداد')),DropdownMenuItem(value:'cashed_from_cashbox',child:Text(s(c['direction'])=='receipt'?'تم التوريد للخزينة':'صرف من الخزينة'))
        ],onChanged:(v)=>local(()=>result=v??result)),
        const SizedBox(height:8),field(date,s(c['direction'])=='receipt'?'تاريخ التحصيل / التوريد / الارتداد DD-MM-YYYY':'تاريخ السداد / الصرف / الارتداد DD-MM-YYYY'),
        if(result!='returned') ...[const SizedBox(height:8),drop('الحساب المقابل للقيد',counterAccount,[const DropdownMenuItem<String>(value:null,child:Text('اختر الحساب المقابل')),...accounts.map((a)=>DropdownMenuItem(value:s(a['id']),child:Text(s(a['account_code'])+' — '+s(a['account_name']))))],(v)=>local(()=>counterAccount=v))],
        if(result=='cashed_from_cashbox')drop('الخزينة',cashbox,[...cashboxes.where((x)=>x['is_bank_account']!=true).map((x)=>DropdownMenuItem(value:s(x['id']),child:Text(s(x['cashbox_name']))))],(v)=>local(()=>cashbox=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد'))],
    )));
    if(yes==true) await run(()async{await db!.rpc('erp_settle_cheque',params:{'p_cheque_id':c['id'],'p_result':result,'p_settlement_date':isoDate(date.text),'p_method':result=='cashed_from_cashbox'?'cashbox':'bank','p_cashbox_id':cashbox,'p_reference':null,'p_counter_account_id':counterAccount});},'تم تحديث حالة الشيك وتاريخ التسوية.');
    date.dispose();
  }
  Future<void> savePolicy() async {await run(()async{await db!.from('erp_financial_policies').upsert({'company_id':company,'cash_issue_mode':directMode?'direct':'sales_order_only','require_cash_order_approval':requireApproval,'allow_credit_cheques':allowCredit,'cheque_edit_roles':chequeEditRoles,'cheque_issue_date_edit_roles':chequeDateRoles,'updated_by':db!.auth.currentUser?.id},onConflict:'company_id');},'تم حفظ السياسات المحاسبية.');}

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
      Row(children:[Expanded(child:drop('نوع الحركة',movementType,const[DropdownMenuItem(value:'receipt',child:Text('سند قبض')),DropdownMenuItem(value:'payment',child:Text('سند صرف')),DropdownMenuItem(value:'transfer',child:Text('سند تحويل خزائن'))],(v)=>setState(() {movementType=v??movementType;if(movementType=='receipt'){fromType='customer';toType='cashbox';}else if(movementType=='payment'){fromType='cashbox';toType='supplier';}else{fromType='cashbox';toType='cashbox';}fromId=null;toId=null;fromName.clear();toName.clear();}))),const SizedBox(width:8),Expanded(child:field(amount,'القيمة الموجبة',numeric:true))]),
      const SizedBox(height:8),Row(children:[Expanded(child:drop('جهة الصرف من',fromType,entityTypes,(v)=>setState(() {fromType=v??fromType;fromId=null;fromName.clear();}))),const SizedBox(width:8),Expanded(child:picker('اسم الجهة من',fromType,fromName,true))]),
      const SizedBox(height:8),Row(children:[Expanded(child:drop('وجهة الصرف إلى',toType,entityTypes,(v)=>setState(() {toType=v??toType;toId=null;toName.clear();}))),const SizedBox(width:8),Expanded(child:picker('اسم الجهة إلى',toType,toName,false))]),
      if(movementType!='transfer') ...[const SizedBox(height:8),drop('الحساب المقابل للقيد',counterAccountId,[const DropdownMenuItem<String>(value:null,child:Text('اختر حسابًا مقابلًا')),...accounts.map((a)=>DropdownMenuItem(value:s(a['id']),child:Text(s(a['account_code'])+' — '+s(a['account_name']))))],(v)=>setState(()=>counterAccountId=v))],
      const SizedBox(height:8),field(movementDate,'تاريخ الحركة DD-MM-YYYY'),const SizedBox(height:8),field(description,'البيان'),Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:saveMovement,child:const Text('حفظ الحركة'))),
    ]))),
    section('حركة نقدية',movements.length),
    grid(['م','مسلسل الحركة','النوع','من','إلى','القيمة','التاريخ'],movements.map((r)=>[s(r['movement_no']),s(r['movement_number']),s(r['movement_type']),s(r['from_name']),s(r['to_name']),money(r['amount']),displayDate(r['movement_date'])]).toList(),actions:movements.map((r)=>IconButton(tooltip:'ترحيل سند الخزينة',onPressed:saving?null:()=>postMovement(r),icon:const Icon(Icons.send_rounded,color:purple))).toList())
  ]);
  Widget orderView()=>Column(children:[
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Expanded(child:drop('نوع الأمر',orderType,const[DropdownMenuItem(value:'payment',child:Text('أمر صرف نقدية')),DropdownMenuItem(value:'receipt',child:Text('أمر توريد نقدية'))],(v)=>setState(()=>orderType=v??orderType))),const SizedBox(width:8),Expanded(child:drop('نوع الجهة',partyType,const[DropdownMenuItem(value:'supplier',child:Text('مورد')),DropdownMenuItem(value:'customer',child:Text('عميل')),DropdownMenuItem(value:'expense',child:Text('بند صرف'))],(v)=>setState(() {partyType=v??partyType;orderPartyId=null;partyName.clear();})))]),
      const SizedBox(height:8),Row(children:[Expanded(child:field(partyName,'اسم الجهة المختارة',readOnly:true)),IconButton.filledTonal(onPressed:()async{final r=await pick(partyType);if(r!=null)setState(() {partyName.text=entityName(r);orderPartyId=s(r['id']);});},icon:const Icon(Icons.search),tooltip:'بحث F1')]),const SizedBox(height:8),field(amount,'القيمة الموجبة',numeric:true),const SizedBox(height:8),field(description,'البيان'),
      const SizedBox(height:8),drop('يظهر لدى المستخدم',assigneeId,[const DropdownMenuItem<String>(value:null,child:Text('كل المستخدمين المصرح لهم')),...users.where((u)=>s(u['auth_user_id']).isNotEmpty).map((u)=>DropdownMenuItem(value:s(u['auth_user_id']),child:Text(s(u['name_ar']))))],(v)=>setState(()=>assigneeId=v)),
      if(!directMode)Padding(padding:const EdgeInsets.only(top:8),child:drop('أمر البيع المرتبط',salesId,[const DropdownMenuItem<String>(value:null,child:Text('اختر أمر بيع')),...sales.map((d)=>DropdownMenuItem(value:s(d['id']),child:Text('أمر '+s(d['document_number'])+' • '+money(d['grand_total']))))],(v)=>setState(()=>salesId=v))),
      Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:saveOrder,child:const Text('حفظ الأمر'))),
    ]))),
    section('أوامر الصرف / التوريد النقدية',orders.where((o)=>s(o['instrument_type'])!='cheque').length),
    grid(['المسلسل','النوع','الجهة','القيمة','الحالة','المستخدم'],orders.where((o)=>s(o['instrument_type'])!='cheque').map((r)=>[s(r['order_number']),s(r['order_type']),s(r['party_name']),money(r['amount']),s(r['status']),users.where((u)=>s(u['auth_user_id'])==s(r['assigned_to_user_id'])).isEmpty?'عام':users.firstWhere((u)=>s(u['auth_user_id'])==s(r['assigned_to_user_id']))['name_ar'].toString()]).toList(),actions:orders.where((o)=>s(o['instrument_type'])!='cheque').map((r)=>s(r['status'])=='draft'?IconButton(tooltip:'اعتماد الأمر',onPressed:saving?null:()=>approveOrder(r),icon:const Icon(Icons.verified_outlined,color:Colors.green)):s(r['status'])=='approved'?IconButton(tooltip:'تنفيذ الأمر',onPressed:saving?null:()=>convertOrder(r),icon:const Icon(Icons.play_circle_outline,color:purple)):const Icon(Icons.check_circle,color:Colors.grey)).toList())
  ]);
  Widget chequeView(bool isOrder)=>Column(children:[
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Expanded(child:drop('نوع الشيك',chequeType,const[DropdownMenuItem(value:'bank',child:Text('شيك بنكي')),DropdownMenuItem(value:'credit',child:Text('شيك ائتمان'))],(v)=>setState(() {chequeType=v??chequeType;chequeId=null;}))),const SizedBox(width:8),Expanded(child:drop('نوع الحركة',chequeDirection,const[DropdownMenuItem(value:'payment',child:Text('صرف / دفع')),DropdownMenuItem(value:'receipt',child:Text('توريد / قبض'))],(v)=>setState(()=>chequeDirection=v??chequeDirection)))]),
      const SizedBox(height:8),
      if(chequeType=='bank')drop('الشيك المتاح غير المستخدم',chequeId,[const DropdownMenuItem<String>(value:null,child:Text('اختر الشيك')),...cheques.where((c)=>s(c['status'])=='available'&&s(c['cheque_type'])=='bank').map((c)=>DropdownMenuItem(value:s(c['id']),child:Text(s(c['check_number'])+' • '+cashboxName(s(c['bank_cashbox_id'])))))],(v)=>setState(()=>chequeId=v))
      else Column(children:[bankPicker('الحساب البنكي / بحث F1'),const SizedBox(height:8),integerField(firstCheck,'رقم شيك الائتمان')]),
      const SizedBox(height:8),Row(children:[Expanded(child:field(issueDate,'تاريخ الإصدار')),const SizedBox(width:8),Expanded(child:field(dueDate,'تاريخ الاستحقاق'))]),
      const SizedBox(height:8),field(partyName,'اسم المستفيد'),const SizedBox(height:8),field(chequeAmount,'قيمة الشيك الموجبة',numeric:true),const SizedBox(height:8),field(description,'البيان'),
      Align(alignment:Alignment.centerLeft,child:FilledButton(onPressed:()=>issueCheque(isOrder),child:Text(isOrder?'حفظ أمر الشيك':'حفظ حركة الشيك'))),
    ]))),
    if(isOrder) ...[
      section('أوامر صرف الشيكات',orders.where((o)=>s(o['instrument_type'])=='cheque').length),
      grid(['مسلسل الأمر','رقم الشيك','النوع','الجهة','القيمة','الحالة'],orders.where((o)=>s(o['instrument_type'])=='cheque').map((o)=>[s(o['order_number']),s(cheques.where((c)=>s(c['id'])==s(o['cheque_id'])).isEmpty?'':cheques.firstWhere((c)=>s(c['id'])==s(o['cheque_id']))['check_number']),s(cheques.where((c)=>s(c['id'])==s(o['cheque_id'])).isEmpty?'':cheques.firstWhere((c)=>s(c['id'])==s(o['cheque_id']))['cheque_type']),s(o['party_name']),money(o['amount']),s(o['status'])]).toList()),
    ] else ...[
      section('حركة الشيكات',cheques.length),
      grid(['رقم الشيك','النوع','الاتجاه','الإصدار','الاستحقاق','القيمة','الحالة'],cheques.map((c)=>[s(c['check_number']),s(c['cheque_type']),s(c['direction']),displayDate(c['issue_date']),displayDate(c['due_date']),chequeAmountLabel(c),s(c['status'])]).toList(),actions:cheques.map((c){
        final settled=['paid','returned','cashed_from_cashbox','cancelled'].contains(s(c['status']));
        return settled?const Icon(Icons.lock,color:Colors.grey):Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(tooltip:'تعديل الشيك',onPressed:saving?null:()=>editCheque(c),icon:const Icon(Icons.edit,color:purple)),
          if(s(c['status'])=='available')IconButton(tooltip:'إلغاء الشيك غير المستخدم',onPressed:saving?null:()=>cancelCheque(c),icon:const Icon(Icons.delete_outline,color:Colors.red)),
        ]);
      }).toList()),
    ]
  ]);
  Widget booksView()=>Column(children:[
    section('ملخص سيريال الشيكات حسب الحساب البنكي',cashboxes.where((b)=>b['is_bank_account']==true).length),
    grid(['الحساب البنكي','عدد الدفاتر','إجمالي الشيكات','المتاح','المستخدم/المصدر','الملغى'],cashboxes.where((b)=>b['is_bank_account']==true).map((b){final id=s(b['id']);final cb=cheques.where((x)=>s(x['bank_cashbox_id'])==id&&s(x['cheque_type'])=='bank').toList();return [s(b['cashbox_name']),books.where((x)=>s(x['bank_cashbox_id'])==id&&x['registered']==true).length.toString(),cb.length.toString(),cb.where((x)=>s(x['status'])=='available').length.toString(),cb.where((x)=>s(x['status'])!='available'&&s(x['status'])!='cancelled').length.toString(),cb.where((x)=>s(x['status'])=='cancelled').length.toString()];}).toList()),
    section('بيانات دفاتر الشيكات الجديدة',_bookDrafts.length),
    Align(alignment:Alignment.centerLeft,child:Wrap(spacing:8,children:[
      OutlinedButton.icon(onPressed:addBookDraftRow,icon:const Icon(Icons.add),label:const Text('إضافة دفتر')),
      FilledButton.icon(onPressed:saving?null:registerBook,icon:const Icon(Icons.save),label:const Text('حفظ وتسجيل الدفاتر')),
    ])),
    Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),
      columns:const [DataColumn(label:Text('م')),DataColumn(label:Text('الحساب البنكي / F1')),DataColumn(label:Text('بداية الدفتر')),DataColumn(label:Text('عدد الأوراق (معاينة)')),DataColumn(label:Text('إجراء'))],
      rows:_bookDrafts.asMap().entries.map((entry){
        final i=entry.key;final draft=entry.value;
        final bank=cashboxes.where((b)=>s(b['id'])==draft.bankId&&b['is_bank_account']==true);
        final count=bank.isEmpty?'—':n(bank.first['checkbook_sheet_count']).toInt().toString();
        return DataRow(cells:[
          DataCell(Text((i+1).toString())),
          DataCell(SizedBox(width:230,child:bookBankPicker(draft))),
          DataCell(SizedBox(width:150,child:integerField(draft.firstCheck,'أول رقم شيك'))),
          DataCell(Text(count)),
          DataCell(IconButton(tooltip:'حذف السطر',onPressed:_bookDrafts.length==1?null:()=>removeBookDraftRow(i),icon:const Icon(Icons.delete_outline,color:Colors.red))),
        ]);
      }).toList(),
    ))),
    section('دفاتر الشيكات المسجلة',books.length),
    grid(['م','مسلسل الدفتر','الحساب البنكي','البداية','عدد الأوراق','الحالة'],books.map((b)=>[s(b['book_no']),s(b['book_number']),cashboxName(s(b['bank_cashbox_id'])),s(b['first_check_number']),s(b['sheet_count']),b['registered']==true?'مسجل':'مسودة']).toList()),
    section('أرقام الشيكات',cheques.length),
    grid(['رقم الشيك','الحساب','النوع','الحالة','المستفيد','القيمة'],cheques.map((c)=>[s(c['check_number']),cashboxName(s(c['bank_cashbox_id'])),s(c['cheque_type']),s(c['status']),s(c['payee_name']),chequeAmountLabel(c)]).toList())
  ]);
  Widget trackingView(bool credit)=>Column(children:[
    if(!credit)drop('فلتر الشيكات',trackingFilter,const[DropdownMenuItem(value:'all',child:Text('كل الشيكات البنكية')),DropdownMenuItem(value:'payment',child:Text('شيكات الدفع')),DropdownMenuItem(value:'receipt',child:Text('شيكات القبض'))],(v)=>setState(()=>trackingFilter=v??'all')),
    section(credit?'شيكات الائتمان':'متابعة الشيكات البنكية',cheques.where((c)=>s(c['cheque_type'])==(credit?'credit':'bank')&&(credit||s(c['status'])=='issued'||s(c['status'])=='under_collection')&&(credit||trackingFilter=='all'||s(c['direction'])==trackingFilter)).length),
    grid(['رقم الشيك','الاتجاه','الإصدار','الاستحقاق','القيمة','المستفيد','الحالة','تاريخ التسوية'],cheques.where((c)=>s(c['cheque_type'])==(credit?'credit':'bank')&&(credit||s(c['status'])=='issued'||s(c['status'])=='under_collection')&&(credit||trackingFilter=='all'||s(c['direction'])==trackingFilter)).map((c)=>[s(c['check_number']),s(c['direction']),displayDate(c['issue_date']),displayDate(c['due_date']),money(c['amount']),s(c['payee_name']),s(c['status']),displayDate(c['settlement_date'])]).toList(),actions:credit?null:cheques.where((c)=>s(c['cheque_type'])=='bank'&&(s(c['status'])=='issued'||s(c['status'])=='under_collection')&&(trackingFilter=='all'||s(c['direction'])==trackingFilter)).map((c)=>IconButton(onPressed:()=>settle(c),icon:const Icon(Icons.edit_calendar,color:purple))).toList())
  ]);
  static const _roleOptions=[('owner','مالك الشركة'),('admin','مدير النظام'),('manager','مدير'),('accountant','محاسب'),('operator','مشغل')];
  Widget policyView()=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('السياسات المحاسبية',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
    SwitchListTile(value:directMode,onChanged:(v)=>setState(()=>directMode=v),title:const Text('السماح بالصرف المباشر دون أمر بيع'),subtitle:const Text('عند الإيقاف يجب ربط أمر الصرف بأمر بيع وتحديد المستخدم المستلم.')),
    SwitchListTile(value:requireApproval,onChanged:(v)=>setState(()=>requireApproval=v),title:const Text('اشتراط اعتماد أمر الصرف قبل تنفيذه')),
    SwitchListTile(value:allowCredit,onChanged:(v)=>setState(()=>allowCredit=v),title:const Text('السماح بشيكات الائتمان')),
    const Divider(),
    const Text('الأدوار المسموح لها بتعديل بيانات الشيك قبل التسوية',style:TextStyle(fontWeight:FontWeight.w800)),
    ..._roleOptions.map((r)=>CheckboxListTile(dense:true,value:chequeEditRoles.contains(r.$1),title:Text(r.$2),onChanged:(v)=>setState(()=>v==true?chequeEditRoles.add(r.$1):chequeEditRoles.remove(r.$1)))),
    const Text('الأدوار المسموح لها بتعديل تاريخ الإصدار',style:TextStyle(fontWeight:FontWeight.w800)),
    ..._roleOptions.map((r)=>CheckboxListTile(dense:true,value:chequeDateRoles.contains(r.$1),title:Text(r.$2),onChanged:(v)=>setState(()=>v==true?chequeDateRoles.add(r.$1):chequeDateRoles.remove(r.$1)))),
    const Text('تاريخ الإصدار الافتراضي هو تاريخ اليوم. لا يسمح بتعديل شيك تم صرفه أو ارتداده أو إلغاؤه.'),
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