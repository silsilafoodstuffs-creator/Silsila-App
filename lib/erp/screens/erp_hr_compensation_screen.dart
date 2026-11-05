import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

const _hrCompPurple=Color(0xFF3E007D),_hrCompOrange=Color(0xFFFFA015);

class ErpHrCompensationScreen extends StatefulWidget {
  const ErpHrCompensationScreen({super.key,required this.companyId,required this.mode,this.title});
  final String? companyId; final String mode; final String? title;
  @override State<ErpHrCompensationScreen> createState()=>_ErpHrCompensationScreenState();
}
class _ErpHrCompensationScreenState extends State<ErpHrCompensationScreen>{
  SupabaseClient? get db {try{return Supabase.instance.client;}catch(_){return null;}}
  String get cid=>(widget.companyId??'').trim();
  String get table=>switch(widget.mode){'advances'=>'erp_hr_employee_advances','actions'=>'erp_hr_employee_actions','overtime'=>'erp_hr_overtime_requests',_=>'erp_hr_performance_reviews'};
  String get dateColumn=>switch(widget.mode){'advances'=>'requested_on','actions'=>'action_date','overtime'=>'work_date',_=>'period_start'};
  bool get readOnly=>(widget.title??'').startsWith('كشف')||(widget.title??'').startsWith('تقرير');
  bool get canCreate=>!readOnly&&widget.title!='تسوية سلفة';
  bool loading=false,saving=false;String? error,message;
  List<Map<String,dynamic>> rows=[],employees=[];
  static const _statusLabels={'pending':'قيد المراجعة','approved':'معتمد','rejected':'مرفوض','disbursed':'تم الصرف','settled':'تمت التسوية','paid':'تم الصرف','applied':'تم التطبيق','draft':'مسودة','submitted':'مرسل للاعتماد'};
  String s(dynamic v)=>(v??'').toString();
  String money(dynamic v)=>((v is num)?v:double.tryParse(s(v))??0).toStringAsFixed(2);
  String date(dynamic v){final d=DateTime.tryParse(s(v))??DateTime.now();return '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';}
  String iso(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    if(cid.isEmpty||db==null){setState(()=>error='لا توجد شركة محددة.');return;}
    setState(()=>loading=true);
    try{
      final r=await Future.wait<dynamic>([
        db!.from('erp_employees').select('id,employee_code,full_name,is_active,employment_status').eq('company_id',cid).order('employee_code').limit(2000),
        db!.from(table).select('*').eq('company_id',cid).order(dateColumn,ascending:false).limit(2000),
      ]);
      if(!mounted)return;setState(() { employees=List<Map<String,dynamic>>.from(r[0]); rows=List<Map<String,dynamic>>.from(r[1]); loading=false; error=null; });
    }catch(e){if(mounted)setState(() { loading=false; error='تعذر تحميل السجلات: ${e}'; });}
  }
  Future<void> addRecord()async{
    if(employees.isEmpty){setState(()=>error='أضف الموظفين أولًا.');return;}
    String employee=s(employees.first['id']),actionType='penalty';
    DateTime start=DateTime.now(),end=DateTime.now();
    final amount=TextEditingController(text:'0'),installments=TextEditingController(text:'1'),hours=TextEditingController(text:'1'),rate=TextEditingController(text:'0'),score=TextEditingController(text:'80'),reason=TextEditingController(),notes=TextEditingController(),strengths=TextEditingController(),improvements=TextEditingController(),goals=TextEditingController(),rating=TextEditingController();
    final key=GlobalKey<FormState>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:Text('إضافة ${widget.title??'سجل موارد بشرية'}'),
      content:SizedBox(width:500,child:SingleChildScrollView(child:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:employee,isExpanded:true,decoration:const InputDecoration(labelText:'الموظف'),items:employees.map((e)=>DropdownMenuItem(value:s(e['id']),child:Text('${s(e['employee_code'])} • ${s(e['full_name'])}'))).toList(),onChanged:(v)=>setD(()=>employee=v??employee)),
        if(widget.mode=='advances'||widget.mode=='actions')TextFormField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المبلغ بالجنيه'),validator:(v){final n=double.tryParse(v??'');return n==null||n<0?'أدخل مبلغًا صحيحًا':null;}),
        if(widget.mode=='advances')TextFormField(controller:installments,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'عدد الأقساط'),validator:(v){final n=int.tryParse(v??'');return n==null||n<1?'عدد الأقساط غير صحيح':null;}),
        if(widget.mode=='actions')DropdownButtonFormField<String>(value:actionType,decoration:const InputDecoration(labelText:'نوع الإجراء'),items:const[DropdownMenuItem(value:'penalty',child:Text('جزاء / خصم')),DropdownMenuItem(value:'reward',child:Text('مكافأة'))],onChanged:(v)=>setD(()=>actionType=v??'penalty')),
        if(widget.mode=='overtime')...[
          TextFormField(controller:hours,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'عدد الساعات'),validator:(v){final n=double.tryParse(v??'');return n==null||n<=0?'أدخل عدد ساعات صحيحًا':null;}),
          TextFormField(controller:rate,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر الساعة بالجنيه'),validator:(v){final n=double.tryParse(v??'');return n==null||n<0?'سعر الساعة غير صحيح':null;}),
        ],
        if(widget.mode=='reviews')...[
          TextFormField(controller:score,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'التقييم من 100'),validator:(v){final n=double.tryParse(v??'');return n==null||n<0||n>100?'التقييم من 0 إلى 100':null;}),
          TextFormField(controller:rating,decoration:const InputDecoration(labelText:'التقدير')),
          TextFormField(controller:strengths,decoration:const InputDecoration(labelText:'نقاط القوة'),maxLines:2),
          TextFormField(controller:improvements,decoration:const InputDecoration(labelText:'مجالات التحسين'),maxLines:2),
          TextFormField(controller:goals,decoration:const InputDecoration(labelText:'الأهداف القادمة'),maxLines:2),
        ],
        if(widget.mode!='reviews')TextFormField(controller:reason,decoration:const InputDecoration(labelText:'السبب / المبرر *'),validator:(v)=>(v??'').trim().isEmpty?'هذا الحقل مطلوب':null),
        if(widget.mode=='reviews')...[
          ListTile(title:const Text('بداية فترة التقييم'),subtitle:Text(date(start)),trailing:IconButton(icon:const Icon(Icons.calendar_month,color:_hrCompPurple),onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:start,firstDate:DateTime(2000),lastDate:DateTime.now());if(d!=null)setD(()=>start=d);})),
          ListTile(title:const Text('نهاية فترة التقييم'),subtitle:Text(date(end)),trailing:IconButton(icon:const Icon(Icons.calendar_month,color:_hrCompPurple),onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:end,firstDate:DateTime(2000),lastDate:DateTime.now());if(d!=null)setD(()=>end=d);})),
        ]else ListTile(title:const Text('التاريخ'),subtitle:Text(date(start)),trailing:IconButton(icon:const Icon(Icons.calendar_month,color:_hrCompPurple),onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:start,firstDate:DateTime(2000),lastDate:DateTime.now());if(d!=null)setD(()=>start=d);})),
        TextFormField(controller:notes,decoration:const InputDecoration(labelText:'ملاحظات إضافية'),maxLines:2),
      ])))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(style:FilledButton.styleFrom(backgroundColor:_hrCompPurple),onPressed:(){if(key.currentState?.validate()??false)Navigator.pop(ctx,true);},child:const Text('حفظ'))],
    )));
    if(ok==true&&db!=null){
      setState(()=>saving=true);
      try{
        final data=<String,dynamic>{'company_id':cid,'employee_id':employee,'created_by':db!.auth.currentUser?.id,'notes':notes.text.trim().isEmpty?null:notes.text.trim()};
        if(widget.mode=='advances'){final a=double.parse(amount.text),n=int.parse(installments.text);data.addAll({'requested_on':iso(start),'amount':a,'installments':n,'installment_amount':a/n,'reason':reason.text.trim(),'status':'pending'});}
        if(widget.mode=='actions'){data.addAll({'action_type':actionType,'action_date':iso(start),'amount':double.parse(amount.text),'reason':reason.text.trim(),'status':'pending'});}
        if(widget.mode=='overtime'){final h=double.parse(hours.text),r=double.parse(rate.text);data.addAll({'work_date':iso(start),'hours':h,'hourly_rate':r,'amount':h*r,'reason':reason.text.trim(),'status':'pending'});}
        if(widget.mode=='reviews'){if(end.isBefore(start))throw ArgumentError('نهاية فترة التقييم تسبق بدايتها.');data.addAll({'period_start':iso(start),'period_end':iso(end),'score':double.parse(score.text),'rating':rating.text.trim(),'strengths':strengths.text.trim(),'improvement_areas':improvements.text.trim(),'goals':goals.text.trim(),'status':'submitted'});}
        await db!.from(table).insert(data);
        if(mounted)setState(()=>message='تم حفظ السجل بنجاح.');
        await load();
      }catch(e){if(mounted)setState(()=>error='تعذر الحفظ: ${e}');}
      finally{if(mounted)setState(()=>saving=false);}
    }
    for(final c in [amount,installments,hours,rate,score,reason,notes,strengths,improvements,goals,rating]){c.dispose();}
  }
  Future<void> transition(Map<String,dynamic> row,String next)async{
    if(db==null)return;
    try{
      final data=<String,dynamic>{'status':next,'approved_by':db!.auth.currentUser?.id,'approved_at':DateTime.now().toUtc().toIso8601String()};
      if(widget.mode=='advances'&&next=='disbursed')data['disbursed_at']=DateTime.now().toUtc().toIso8601String();
      if(widget.mode=='advances'&&next=='settled'){data['settled_at']=DateTime.now().toUtc().toIso8601String();data['settled_amount']=row['amount'];}
      await db!.from(table).update(data).eq('id',s(row['id'])).eq('company_id',cid);
      if(mounted)setState(()=>message='تم تحديث حالة السجل.');
      await load();
    }catch(e){if(mounted)setState(()=>error='تعذر تحديث الحالة: ${e}');}
  }
  List<(String,String)> actionsFor(Map<String,dynamic> row){
    if(readOnly)return [];
    final status=s(row['status']);
    if(widget.mode=='advances'){
      if(status=='pending')return [('approve','اعتماد'),('reject','رفض')];
      if(status=='approved')return [('disbursed','تأكيد الصرف')];
      if(status=='disbursed')return [('settled','تسوية كاملة')];
    }
    if(widget.mode=='actions'||widget.mode=='overtime'){
      if(status=='pending')return [('approved','اعتماد'),('rejected','رفض')];
      if(widget.mode=='overtime'&&status=='approved')return [('paid','تم الصرف')];
    }
    if(widget.mode=='reviews'){
      if(status=='submitted')return [('approved','اعتماد'),('rejected','إعادة للمراجعة')];
    }
    return [];
  }
  String titleFor(Map<String,dynamic> row,Map<String,String> employeeNames){
    final name=employeeNames[s(row['employee_id'])]??'موظف غير معروف';
    if(widget.mode=='advances')return name+' • '+money(row['amount'])+' جنيه';
    if(widget.mode=='actions')return name+' • '+(s(row['action_type'])=='reward'?'مكافأة':'جزاء');
    if(widget.mode=='overtime')return name+' • '+s(row['hours'])+' ساعة';
    return name+' • تقييم '+s(row['score'])+'/100';
  }
  @override Widget build(BuildContext context){
    final employeeNames={for(final e in employees)s(e['id']):'${s(e['employee_code'])} • ${s(e['full_name'])}'};
    final pending=rows.where((r)=>s(r['status'])=='pending'||s(r['status'])=='submitted').length;
    return Container(color:const Color(0xFFFAF8FC),padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:_hrCompPurple,borderRadius:BorderRadius.circular(12)),child:Icon(widget.mode=='advances'?Icons.account_balance_wallet:widget.mode=='overtime'?Icons.more_time:widget.mode=='reviews'?Icons.rate_review:Icons.gavel,color:Colors.white)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.title??'شئون الموظفين',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_hrCompPurple)),const Text('إدارة ومراجعة واعتماد معاملات الموظفين',style:TextStyle(fontSize:12,color:Colors.black54))])),IconButton(onPressed:load,icon:const Icon(Icons.refresh,color:_hrCompPurple))]),
      const SizedBox(height:10),Wrap(spacing:6,children:[ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh,onPressed:load),if(canCreate)ErpQuickTaskButton(label:'إضافة',icon:Icons.add,onPressed:addRecord)]),
      if(error!=null||message!=null)Container(margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:error!=null?const Color(0xFFFFEEEE):const Color(0xFFEAF6EC),borderRadius:BorderRadius.circular(8)),child:Text(error??message!,style:TextStyle(color:error!=null?Colors.red.shade800:Colors.green.shade800))),
      if(loading)const LinearProgressIndicator(color:_hrCompOrange),
      const SizedBox(height:10),Row(children:[Expanded(child:Text('إجمالي السجلات: ${rows.length}',style:const TextStyle(color:_hrCompPurple,fontWeight:FontWeight.w800))),Text('بانتظار الإجراء: ${pending}',style:const TextStyle(color:_hrCompOrange,fontWeight:FontWeight.w800))]),
      const SizedBox(height:8),
      ...rows.map((r)=>Card(elevation:0,margin:const EdgeInsets.only(bottom:7),child:ListTile(
        leading:const CircleAvatar(backgroundColor:Color(0xFFF5EFFB),child:Icon(Icons.assignment_outlined,color:_hrCompPurple)),
        title:Text(titleFor(r,employeeNames),style:const TextStyle(fontWeight:FontWeight.w800,color:_hrCompPurple)),
        subtitle:Text('${date(r[dateColumn])} • ${_statusLabels[s(r['status'])]??s(r['status'])}\n${s(r['reason']).isEmpty?s(r['notes']):s(r['reason'])}${widget.mode=='overtime'?' • ${money(r['amount'])} جنيه':''}'),
        isThreeLine:true,
        trailing:actionsFor(r).isEmpty?null:PopupMenuButton<String>(onSelected:(v)=>transition(r,v),itemBuilder:(_)=>actionsFor(r).map((a)=>PopupMenuItem(value:a.$1,child:Text(a.$2))).toList()),
      ))),
      if(saving)const LinearProgressIndicator(color:_hrCompPurple),
    ]));
  }
}
