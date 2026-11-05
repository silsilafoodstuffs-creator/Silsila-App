import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

const _hrPurple=Color(0xFF3E007D),_hrOrange=Color(0xFFFFA015);
class ErpHrLifecycleScreen extends StatefulWidget {
  const ErpHrLifecycleScreen({super.key,required this.companyId,this.initialView='recruitment',this.title});
  final String? companyId; final String initialView; final String? title;
  @override State<ErpHrLifecycleScreen> createState()=>_ErpHrLifecycleScreenState();
}
class _ErpHrLifecycleScreenState extends State<ErpHrLifecycleScreen>{
  SupabaseClient? get db {try{return Supabase.instance.client;}catch(_){return null;}}
  String get cid=>(widget.companyId??'').trim();
  bool get movement=>widget.initialView=='movements';
  bool get getInterviews=>widget.initialView=='interviews';
  bool get readOnly=>(widget.title??'').startsWith('تقرير')||(widget.title??'').startsWith('كشف');
  bool loading=false,saving=false; String? error,message;
  List<Map<String,dynamic>> candidates=[],employees=[],jobs=[],departments=[],branches=[],moves=[];
  static const stages={'new':'جديد','screening':'فرز أولي','interview':'مقابلة','accepted':'مقبول','rejected':'مرفوض','withdrawn':'منسحب'};
  static const types={'hire':'تعيين / مباشرة عمل','transfer':'نقل','promotion':'ترقية','suspension':'إيقاف مؤقت','return_to_work':'عودة للعمل','resignation':'استقالة','termination':'إنهاء خدمة','retirement':'إحالة للتقاعد'};
  String s(dynamic v)=>(v??'').toString();
  String date(dynamic v){final d=DateTime.tryParse(s(v))??DateTime.now();return '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';}
  String iso(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    if(cid.isEmpty||db==null){setState(()=>error='لا توجد شركة محددة. افتح بيانات الشركة أولًا.');return;}
    setState(()=>loading=true);
    try{
      final r=await Future.wait<dynamic>([
        db!.from('erp_hr_recruitment_candidates').select('id,job_id,candidate_name,phone,email,status,applied_on,source,notes').eq('company_id',cid).order('applied_on',ascending:false).limit(1000),
        db!.from('erp_employees').select('id,employee_code,full_name,job_title,department_name,is_active,employment_status').eq('company_id',cid).order('employee_code').limit(2000),
        db!.from('erp_hr_jobs').select('id,job_code,name_ar').eq('company_id',cid).eq('is_active',true).order('job_code'),
        db!.from('erp_hr_departments').select('id,department_code,name_ar').eq('company_id',cid).eq('is_active',true).order('department_code'),
        db!.from('erp_branches').select('id,branch_code,branch_name').eq('company_id',cid).eq('is_active',true).order('branch_code'),
        db!.from('erp_hr_employee_movements').select('id,employee_id,movement_type,effective_on,reason,notes,target_branch_id,target_department_id,target_job_id').eq('company_id',cid).order('effective_on',ascending:false).limit(1500),
      ]);
      if(!mounted)return;
      setState(() { candidates=List<Map<String,dynamic>>.from(r[0]); employees=List<Map<String,dynamic>>.from(r[1]); jobs=List<Map<String,dynamic>>.from(r[2]); departments=List<Map<String,dynamic>>.from(r[3]); branches=List<Map<String,dynamic>>.from(r[4]); moves=List<Map<String,dynamic>>.from(r[5]); loading=false; error=null; });
    }catch(e){if(mounted)setState(() { loading=false; error='تعذر تحميل بيانات شئون الموظفين: ${e}'; });}
  }
  Future<void> candidateForm([Map<String,dynamic>? row])async{
    final name=TextEditingController(text:s(row?['candidate_name'])),phone=TextEditingController(text:s(row?['phone'])),email=TextEditingController(text:s(row?['email'])),source=TextEditingController(text:s(row?['source'])),notes=TextEditingController(text:s(row?['notes']));
    String? job=s(row?['job_id']).isEmpty?null:s(row?['job_id']);String stage=s(row?['status']).isEmpty?'new':s(row?['status']);
    DateTime applied=DateTime.tryParse(s(row?['applied_on']))??DateTime.now();final key=GlobalKey<FormState>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:Text(row==null?'إضافة طلب توظيف':'تعديل طلب التوظيف'),content:SizedBox(width:460,child:SingleChildScrollView(child:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'اسم المرشح *'),validator:(v)=>(v??'').trim().isEmpty?'اسم المرشح مطلوب':null),
      TextFormField(controller:phone,decoration:const InputDecoration(labelText:'الهاتف')),TextFormField(controller:email,decoration:const InputDecoration(labelText:'البريد الإلكتروني')),
      DropdownButtonFormField<String>(value:job,isExpanded:true,decoration:const InputDecoration(labelText:'الوظيفة'),items:[const DropdownMenuItem<String>(value:null,child:Text('غير محددة')),...jobs.map((j)=>DropdownMenuItem(value:s(j['id']),child:Text('${s(j['job_code'])} • ${s(j['name_ar'])}')))],onChanged:(v)=>setD(()=>job=v)),
      DropdownButtonFormField<String>(value:stage,isExpanded:true,decoration:const InputDecoration(labelText:'المرحلة'),items:stages.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>stage=v??'new')),
      TextFormField(controller:source,decoration:const InputDecoration(labelText:'مصدر التوظيف')),TextFormField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظات')),
      ListTile(title:const Text('تاريخ التقديم'),subtitle:Text(date(applied)),trailing:IconButton(icon:const Icon(Icons.calendar_month,color:_hrPurple),onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:applied,firstDate:DateTime(2000),lastDate:DateTime.now());if(d!=null)setD(()=>applied=d);})),
    ])))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(style:FilledButton.styleFrom(backgroundColor:_hrPurple),onPressed:(){if(key.currentState?.validate()??false)Navigator.pop(ctx,true);},child:const Text('حفظ'))])));
    if(ok==true&&db!=null){setState(()=>saving=true);try{final data=<String,dynamic>{'candidate_name':name.text.trim(),'phone':phone.text.trim().isEmpty?null:phone.text.trim(),'email':email.text.trim().isEmpty?null:email.text.trim(),'job_id':job,'status':stage,'decision_on':(stage=='accepted'||stage=='rejected')?iso(DateTime.now()):null,'applied_on':iso(applied),'source':source.text.trim().isEmpty?null:source.text.trim(),'notes':notes.text.trim().isEmpty?null:notes.text.trim(),'updated_at':DateTime.now().toUtc().toIso8601String()};if(row==null){data['company_id']=cid;data['created_by']=db!.auth.currentUser?.id;await db!.from('erp_hr_recruitment_candidates').insert(data);}else{await db!.from('erp_hr_recruitment_candidates').update(data).eq('id',s(row['id'])).eq('company_id',cid);}if(mounted)setState(()=>message='تم حفظ طلب التوظيف.');await load();}catch(e){if(mounted)setState(()=>error='تعذر حفظ الطلب: ${e}');}finally{if(mounted)setState(()=>saving=false);}}
    name.dispose();phone.dispose();email.dispose();source.dispose();notes.dispose();
  }
  Future<void> deleteCandidate(Map<String,dynamic> row)async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('تأكيد الحذف'),content:Text('حذف طلب ${s(row['candidate_name'])}؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('حذف'))]));
    if(ok!=true||db==null)return;try{await db!.from('erp_hr_recruitment_candidates').delete().eq('id',s(row['id'])).eq('company_id',cid);setState(()=>message='تم حذف طلب التوظيف.');await load();}catch(e){setState(()=>error='تعذر الحذف: ${e}');}
  }
  Future<void> movementForm()async{
    if(employees.isEmpty){setState(()=>error='لا يوجد موظفون. أضف الموظف أولًا من بيانات الموظفين.');return;}
    String employee=s(employees.first['id']),type='transfer';String? branch,department,job;DateTime effective=DateTime.now();final reason=TextEditingController(),notes=TextEditingController();final key=GlobalKey<FormState>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('تسجيل حركة موظف'),content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(value:employee,isExpanded:true,decoration:const InputDecoration(labelText:'الموظف'),items:employees.map((e)=>DropdownMenuItem(value:s(e['id']),child:Text('${s(e['employee_code'])} • ${s(e['full_name'])}'))).toList(),onChanged:(v)=>setD(()=>employee=v??employee)),
      DropdownButtonFormField<String>(value:type,isExpanded:true,decoration:const InputDecoration(labelText:'نوع الحركة'),items:types.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>type=v??'transfer')),
      ListTile(title:const Text('تاريخ السريان'),subtitle:Text(date(effective)),trailing:IconButton(icon:const Icon(Icons.calendar_month,color:_hrPurple),onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:effective,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setD(()=>effective=d);})),
      if(type=='transfer'||type=='promotion')...[
        DropdownButtonFormField<String>(value:branch,isExpanded:true,decoration:const InputDecoration(labelText:'الفرع الجديد (اختياري)'),items:[const DropdownMenuItem<String>(value:null,child:Text('بدون تغيير')),...branches.map((b)=>DropdownMenuItem(value:s(b['id']),child:Text('${s(b['branch_code'])} • ${s(b['branch_name'])}')))],onChanged:(v)=>setD(()=>branch=v)),
        DropdownButtonFormField<String>(value:department,isExpanded:true,decoration:const InputDecoration(labelText:'الإدارة الجديدة (اختياري)'),items:[const DropdownMenuItem<String>(value:null,child:Text('بدون تغيير')),...departments.map((d)=>DropdownMenuItem(value:s(d['id']),child:Text('${s(d['department_code'])} • ${s(d['name_ar'])}')))],onChanged:(v)=>setD(()=>department=v)),
        DropdownButtonFormField<String>(value:job,isExpanded:true,decoration:const InputDecoration(labelText:'الوظيفة الجديدة (اختياري)'),items:[const DropdownMenuItem<String>(value:null,child:Text('بدون تغيير')),...jobs.map((j)=>DropdownMenuItem(value:s(j['id']),child:Text('${s(j['job_code'])} • ${s(j['name_ar'])}')))],onChanged:(v)=>setD(()=>job=v)),
      ],
      TextFormField(controller:reason,decoration:const InputDecoration(labelText:'سبب الحركة *'),validator:(v)=>(v??'').trim().isEmpty?'سبب الحركة مطلوب':null),TextFormField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظات')),
    ])))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(style:FilledButton.styleFrom(backgroundColor:_hrPurple),onPressed:(){if(key.currentState?.validate()??false)Navigator.pop(ctx,true);},child:const Text('حفظ الحركة'))])));
    if(ok==true&&db!=null){setState(()=>saving=true);try{await db!.from('erp_hr_employee_movements').insert({'company_id':cid,'employee_id':employee,'movement_type':type,'effective_on':iso(effective),'reason':reason.text.trim(),'notes':notes.text.trim().isEmpty?null:notes.text.trim(),'target_branch_id':branch,'target_department_id':department,'target_job_id':job,'created_by':db!.auth.currentUser?.id});if(mounted)setState(()=>message='تم تسجيل الحركة، وتُطبق تغييراتها وفق تاريخ السريان.');await load();}catch(e){if(mounted)setState(()=>error='تعذر تسجيل الحركة: ${e}');}finally{if(mounted)setState(()=>saving=false);}}
    reason.dispose();notes.dispose();
  }
  Widget summary(String label,String value,IconData icon)=>Expanded(child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:_hrPurple.withValues(alpha:.12))),child:Row(children:[Icon(icon,color:_hrOrange),const SizedBox(width:7),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10,color:Colors.black54)),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_hrPurple))]))])));
  @override Widget build(BuildContext context){
    final title=widget.title??(movement?'حركات الموظفين':getInterviews?'مقابلات التوظيف':'طلبات التوظيف');
    final jobNames={for(final j in jobs)s(j['id']):s(j['name_ar'])},employeeNames={for(final e in employees)s(e['id']):'${s(e['employee_code'])} • ${s(e['full_name'])}'},deptNames={for(final d in departments)s(d['id']):s(d['name_ar'])},branchNames={for(final b in branches)s(b['id']):s(b['branch_name'])};
    final list=getInterviews?candidates.where((r)=>s(r['status'])=='interview').toList():candidates;
    return Container(color:const Color(0xFFFAF8FC),padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:_hrPurple,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.groups_2,color:Colors.white)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_hrPurple)),const Text('إدارة دورة حياة الموظف والتوظيف',style:TextStyle(fontSize:12,color:Colors.black54))])),IconButton(onPressed:load,icon:const Icon(Icons.refresh,color:_hrPurple))]),
      const SizedBox(height:10),Wrap(spacing:6,children:[ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh,onPressed:load),ErpQuickTaskButton(label:'إضافة',icon:Icons.add,onPressed:movement?movementForm:()=>candidateForm())]),
      if(error!=null||message!=null)Container(margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:error!=null?const Color(0xFFFFEEEE):const Color(0xFFEAF6EC),borderRadius:BorderRadius.circular(8)),child:Text(error??message!,style:TextStyle(color:error!=null?Colors.red.shade800:Colors.green.shade800))),
      if(loading)const LinearProgressIndicator(color:_hrOrange),
      const SizedBox(height:10),SingleChildScrollView(child:movement?Column(children:[
        Row(children:[summary('إجمالي الحركات','${moves.length}',Icons.swap_horiz),const SizedBox(width:7),summary('نقل وترقيات','${moves.where((m)=>['transfer','promotion'].contains(s(m['movement_type']))).length}',Icons.trending_up),const SizedBox(width:7),summary('إنهاء خدمة','${moves.where((m)=>['resignation','termination','retirement'].contains(s(m['movement_type']))).length}',Icons.person_off)]),
        const SizedBox(height:10),if(moves.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Text('لا توجد حركات مسجلة للموظفين.'))else...moves.map((m)=>Card(elevation:0,child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFF5EFFB),child:Icon(Icons.assignment_turned_in,color:_hrPurple)),title:Text(employeeNames[s(m['employee_id'])]??'موظف غير معروف'),subtitle:Text('${types[s(m['movement_type'])]??s(m['movement_type'])} • ${date(m['effective_on'])}\n${s(m['reason'])}\n${[branchNames[s(m['target_branch_id'])],deptNames[s(m['target_department_id'])],jobNames[s(m['target_job_id'])]].whereType<String>().where((v)=>v.isNotEmpty).join(' • ')}'),isThreeLine:true))),
      ]):Column(children:[
        Row(children:[summary('إجمالي الطلبات','${candidates.length}',Icons.people),const SizedBox(width:7),summary('قيد الفرز','${candidates.where((r)=>s(r['status'])=='screening').length}',Icons.manage_search),const SizedBox(width:7),summary('مقابلات','${candidates.where((r)=>s(r['status'])=='interview').length}',Icons.event),const SizedBox(width:7),summary('مقبولون','${candidates.where((r)=>s(r['status'])=='accepted').length}',Icons.verified)]),
        const SizedBox(height:10),if(list.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Text('لا توجد طلبات في هذه المرحلة.'))else...list.map((r)=>Card(elevation:0,child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFF5EFFB),child:Icon(Icons.person_search,color:_hrPurple)),title:Text(s(r['candidate_name']),style:const TextStyle(fontWeight:FontWeight.w800,color:_hrPurple)),subtitle:Text('${jobNames[s(r['job_id'])]??'وظيفة غير محددة'} • ${s(r['phone'])}\n${stages[s(r['status'])]??s(r['status'])} • ${date(r['applied_on'])}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')candidateForm(r);if(v=='delete')deleteCandidate(r);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'delete',child:Text('حذف'))])))),
      ])),
      if(saving)const LinearProgressIndicator(color:_hrPurple),
    ]));
  }
}
