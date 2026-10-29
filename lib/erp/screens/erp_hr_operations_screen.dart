import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

class ErpHrOperationsScreen extends StatefulWidget {
  const ErpHrOperationsScreen({super.key,this.initialCompanyId});
  final String? initialCompanyId;
  @override State<ErpHrOperationsScreen> createState()=>_ErpHrOperationsScreenState();
}
class _ErpHrOperationsScreenState extends State<ErpHrOperationsScreen> with SingleTickerProviderStateMixin {
  final _db=Supabase.instance.client;
  final _company=TextEditingController();
  late final TabController _tabs;
  List<Map<String,dynamic>> employees=[],locations=[],departments=[],jobs=[],branches=[],attendance=[],devices=[],events=[],payroll=[];
  final Map<String,Map<String,dynamic>> daily={};
  bool loading=false,saving=false,locked=false;
  String? error,message;
  DateTime day=DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day);
  static const purple=Color(0xFF3E007D),orange=Color(0xFFFFA015);
  static const workUnits=['مكتب إداري','مخازن','سيارات'];
  static const fractions=<String,double>{'يوم كامل':1,'3/4 يوم':.75,'1/2 يوم':.5,'1/4 يوم':.25};
  static const absenceTypes=['عطلة أسبوعية','إجازة رسمية','إجازة مرضية','إجازة إصابة عمل','إجازة سنوية','غياب بإذن','غياب بدون إذن'];
  static const penalties=<String,double>{'بدون جزاء':0,'0.25 يوم':.25,'0.5 يوم':.5,'0.75 يوم':.75,'1 يوم':1,'1.25 يوم':1.25,'1.5 يوم':1.5,'1.75 يوم':1.75,'2 يوم':2,'2.25 يوم':2.25,'2.5 يوم':2.5,'2.75 يوم':2.75,'3 يوم':3,'3.25 يوم':3.25,'3.5 يوم':3.5,'3.75 يوم':3.75,'4 يوم':4,'4.25 يوم':4.25,'4.5 يوم':4.5,'4.75 يوم':4.75,'5 يوم':5};
  @override void initState(){super.initState();_company.text=widget.initialCompanyId??'';_tabs=TabController(length:3,vsync:this);if(_company.text.isNotEmpty)WidgetsBinding.instance.addPostFrameCallback((_)=>load());}
  @override void dispose(){_tabs.dispose();_company.dispose();super.dispose();}
  String s(dynamic v)=>(v??'').toString();
  String date(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String weekday(DateTime d)=>const ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'][d.weekday-1];
  Map<String,dynamic>? emp(String id){for(final e in employees){if(s(e['id'])==id)return e;}return null;}
  String empName(dynamic id){final e=emp(s(id));return e==null?s(id):'${s(e['employee_code'])} — ${s(e['full_name'])}';}
  Future<void> load() async {
    if(_company.text.trim().isEmpty){setState(()=>error='أدخل معرّف الشركة أولًا.');return;}
    setState((){loading=true;error=null;message=null;});
    try{
      final c=_company.text.trim(),start=date(DateTime(day.year,day.month,1)),end=date(DateTime(day.year,day.month+1,0));
      final v=await Future.wait([
        _db.from('erp_employees').select('id,employee_code,full_name,full_name_en,job_title,department_name,department_id,job_id,work_location_id,work_unit,administration_id,branch_id,employment_status,is_active,governorate,district,locality').eq('company_id',c).order('employee_code'),
        _db.from('erp_hr_work_locations').select().eq('company_id',c).order('location_code'),
        _db.from('erp_hr_departments').select().eq('company_id',c).order('department_code'),
        _db.from('erp_hr_jobs').select().eq('company_id',c).order('job_code'),
        _db.from('erp_branches').select('id,branch_code,branch_name').eq('company_id',c).order('branch_code'),
        _db.from('erp_attendance_records').select().eq('company_id',c).gte('work_date',start).lte('work_date',end).order('work_date'),
        _db.from('erp_hr_fingerprint_devices').select().eq('company_id',c).order('device_name'),
        _db.from('erp_hr_attendance_events').select().eq('company_id',c).gte('event_at',start).lt('event_at',date(DateTime(day.year,day.month+1,1))).order('event_at',ascending:false).limit(1200),
        _db.from('erp_payroll_runs').select('id,run_code,period_start,period_end,status').eq('company_id',c).order('period_start',ascending:false),
      ]);
      if(!mounted)return;
      setState((){
        employees=List<Map<String,dynamic>>.from(v[0]);locations=List<Map<String,dynamic>>.from(v[1]);departments=List<Map<String,dynamic>>.from(v[2]);jobs=List<Map<String,dynamic>>.from(v[3]);branches=List<Map<String,dynamic>>.from(v[4]);attendance=List<Map<String,dynamic>>.from(v[5]);devices=List<Map<String,dynamic>>.from(v[6]);events=List<Map<String,dynamic>>.from(v[7]);payroll=List<Map<String,dynamic>>.from(v[8]);
        final month='${day.year.toString().padLeft(4,'0')}-${day.month.toString().padLeft(2,'0')}';
        locked=payroll.any((r)=>s(r['period_start']).startsWith(month)&&const ['approved','posted','paid'].contains(s(r['status']).toLowerCase()));
        rebuild();loading=false;
      });
    }catch(e){if(mounted)setState((){loading=false;error='تعذر تحميل البيانات. قد يلزم تطبيق ترحيل حقول الحضور الجديد: $e';});}
  }
  void rebuild(){daily.clear();for(final r in attendance.where((x)=>s(x['work_date'])==date(day))){daily[s(r['employee_id'])]={'employeeId':s(r['employee_id']),'jobId':s(r['job_id']),'present':s(r['attendance_status'])!='absent','absent':s(r['attendance_status'])=='absent','fraction':fractions.entries.firstWhere((x)=>x.value==((r['attendance_fraction'] as num?)?.toDouble()??1),orElse:()=>fractions.entries.first).key,'absenceType':s(r['absence_type']).isEmpty?'غياب بدون إذن':s(r['absence_type']),'penalty':penalties.entries.firstWhere((x)=>x.value==((r['absence_penalty_days'] as num?)?.toDouble()??0),orElse:()=>penalties.entries.first).key};}}
  Widget task(String l,IconData i,Color c,VoidCallback? f)=>ErpQuickTaskButton(label:l,icon:i,onPressed:f,fallbackColor:c);
  Widget notice(String t,Color c)=>Container(margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:c.withValues(alpha:.09),borderRadius:BorderRadius.circular(9)),child:Text(t,style:TextStyle(color:c)));
  Future<void> masterDialog(String kind,{Map<String,dynamic>? row,String? parentId})async{
    final isJob=kind=='job',isLoc=kind=='location';
    final code=TextEditingController(text:s(row?[isJob?'job_code':isLoc?'location_code':'department_code'])),ar=TextEditingController(text:s(row?['name_ar'])),en=TextEditingController(text:s(row?['name_en']));
    var level=s(row?['department_level']).isEmpty?'directorate':s(row?['department_level']);var locType=s(row?['location_type']).isEmpty?'branch':s(row?['location_type']);String? parent=s(row?['parent_id']).isNotEmpty?s(row?['parent_id']):parentId;String? dep=s(row?['department_id']).isNotEmpty?s(row?['department_id']):parentId;String? workLocation=s(row?['work_location_id']).isNotEmpty?s(row?['work_location_id']):null;final parentRows=departments.where((d)=>s(d['id'])==(parent??'')).toList();if(workLocation==null&&!isJob&&!isLoc&&parentRows.isNotEmpty)workLocation=s(parentRows.first['work_location_id']);final centralLocations=locations.where((l)=>s(l['location_type'])=='central').toList();if(workLocation==null&&centralLocations.isNotEmpty)workLocation=s(centralLocations.first['id']);String? err;
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:Text('${row==null?'إضافة':'تعديل'} ${isJob?'وظيفة':isLoc?'موقع عمل':'إدارة / قسم'}'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:code,decoration:const InputDecoration(labelText:'الكود *')),TextField(controller:ar,decoration:const InputDecoration(labelText:'الاسم بالعربية *')),if(!isLoc)TextField(controller:en,decoration:const InputDecoration(labelText:'الاسم بالإنجليزية')),
      if(isLoc)DropdownButtonFormField<String>(value:locType,decoration:const InputDecoration(labelText:'نوع الموقع'),items:const [DropdownMenuItem(value:'central',child:Text('إدارة مركزية')),DropdownMenuItem(value:'branch',child:Text('فرع'))],onChanged:(v)=>refresh(()=>locType=v??locType)),
      if(!isLoc&&!isJob)DropdownButtonFormField<String>(value:level,decoration:const InputDecoration(labelText:'المستوى'),items:const [DropdownMenuItem(value:'directorate',child:Text('إدارة رئيسية')),DropdownMenuItem(value:'department',child:Text('إدارة'))],onChanged:(v)=>refresh(()=>level=v??level)),
      if(!isLoc&&!isJob)DropdownButtonFormField<String>(value:locations.any((l)=>s(l['id'])==workLocation)?workLocation:null,decoration:const InputDecoration(labelText:'موقع العمل *'),items:locations.where((l)=>l['is_active']!=false).map((l)=>DropdownMenuItem<String>(value:s(l['id']),child:Text('${s(l['location_code'])} • ${s(l['name_ar'])}'))).toList(),onChanged:(v)=>refresh(()=>workLocation=v)),
      if(!isLoc&&!isJob&&level!='directorate')DropdownButtonFormField<String>(value:departments.any((d)=>s(d['id'])==parent)?parent:null,decoration:const InputDecoration(labelText:'يتبع الإدارة'),items:departments.where((d)=>s(d['id'])!=s(row?['id'])&&s(d['department_level'])!='section'&&d['is_active']!=false).map((d)=>DropdownMenuItem<String>(value:s(d['id']),child:Text('${s(d['department_code'])} • ${s(d['name_ar'])}'))).toList(),onChanged:(v)=>refresh(()=>parent=v)),
      if(isJob)DropdownButtonFormField<String>(value:departments.any((d)=>s(d['id'])==dep)?dep:null,decoration:const InputDecoration(labelText:'القسم *'),items:departments.where((d)=>d['is_active']!=false&&s(d['department_level'])!='section').map((d)=>DropdownMenuItem<String>(value:s(d['id']),child:Text('${s(d['department_code'])} • ${s(d['name_ar'])}'))).toList(),onChanged:(v)=>refresh(()=>dep=v)),
      if(err!=null)notice(err!,Colors.red),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{
      if(code.text.trim().isEmpty||ar.text.trim().isEmpty||(isJob&&dep==null)||(!isJob&&!isLoc&&workLocation==null)||(!isJob&&!isLoc&&level!='directorate'&&parent==null)){refresh(()=>err='أكمل الكود والاسم والارتباط التنظيمي.');return;}
      try{final c=_company.text.trim();if(isLoc){final x={'company_id':c,'location_code':code.text.trim().toUpperCase(),'name_ar':ar.text.trim(),'location_type':locType,'is_active':true};if(row==null)await _db.from('erp_hr_work_locations').insert(x);else await _db.from('erp_hr_work_locations').update(x).eq('id',s(row['id']));}
      else if(isJob){final x={'company_id':c,'job_code':code.text.trim().toUpperCase(),'name_ar':ar.text.trim(),'name_en':en.text.trim(),'department_id':dep,'is_active':true};if(row==null)await _db.from('erp_hr_jobs').insert(x);else await _db.from('erp_hr_jobs').update(x).eq('id',s(row['id']));}
      else{final x={'company_id':c,'department_code':code.text.trim().toUpperCase(),'name_ar':ar.text.trim(),'name_en':en.text.trim(),'department_level':level,'parent_id':level=='directorate'?null:parent,'work_location_id':workLocation,'is_active':true};if(row==null)await _db.from('erp_hr_departments').insert(x);else await _db.from('erp_hr_departments').update(x).eq('id',s(row['id']));}
      if(ctx.mounted)Navigator.pop(ctx);await load();if(mounted)setState(()=>message='تم حفظ البيانات التنظيمية.');
      }catch(e){refresh(()=>err='تعذر الحفظ: $e');}
    },child:const Text('حفظ'))])));
    code.dispose();ar.dispose();en.dispose();
  }
  Future<void> deleteRow(String kind,Map<String,dynamic> row)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد الحذف'),content:const Text('هل تريد الحذف؟ قد تمنع العلاقات المرتبطة الحذف حفاظًا على البيانات.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('نعم'))]));if(ok!=true)return;try{await _db.from(kind=='job'?'erp_hr_jobs':kind=='location'?'erp_hr_work_locations':'erp_hr_departments').delete().eq('id',s(row['id'])).eq('company_id',_company.text.trim());await load();}catch(e){if(mounted)setState(()=>error='تعذر الحذف: $e');}}
  List<Map<String,dynamic>> employeesForUnit(Map<String,dynamic> location,String unit) =>
      employees.where((e)=>s(e['work_location_id'])==s(location['id'])&&(s(e['work_unit']).isEmpty?'مكتب إداري':s(e['work_unit']))==unit).toList();

  Widget employeeTreeTile(Map<String,dynamic> e,{bool manualMode=false}) {
    final already=daily.containsKey(s(e['id']));
    return ListTile(
      dense:true,
      leading:const Icon(Icons.person_outline,color:purple),
      title:Text('${s(e['employee_code'])} • ${s(e['full_name'])}',style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text('${s(e['job_title'])} • ${s(e['department_name'])}'),
      trailing:manualMode?TextButton.icon(
        onPressed:locked||already?null:()=>setState(()=>addEmployee(e)),
        icon:Icon(already?Icons.check_circle_outline:Icons.person_add_alt_1),
        label:Text(already?'مضاف':'إضافة للحضور'),
      ):null,
    );
  }

  Widget workUnitNode(Map<String,dynamic> location,String unit,{bool manualMode=false}) {
    final people=employeesForUnit(location,unit);
    return Padding(
      padding:const EdgeInsetsDirectional.only(start:8),
      child:ExpansionTile(
        leading:Icon(unit=='مكتب إداري'?Icons.business_outlined:unit=='مخازن'?Icons.warehouse_outlined:Icons.local_shipping_outlined,color:orange),
        title:Text(unit,style:const TextStyle(fontWeight:FontWeight.w800)),
        subtitle:Text('${people.length} موظف'),
        children:people.isEmpty
          ? [const ListTile(dense:true,title:Text('لا يوجد موظفون مسجلون في هذه الوحدة.'))]
          : people.map((e)=>employeeTreeTile(e,manualMode:manualMode)).toList(),
      ),
    );
  }

  Widget centralDepartmentNode(Map<String,dynamic> d,{bool manualMode=false}) {
    final id=s(d['id']);
    final children=departments.where((x)=>s(x['parent_id'])==id&&s(x['department_level'])!='section').toList();
    final sectionIds=departments.where((x)=>s(x['department_level'])=='section'&&s(x['parent_id'])==id).map((x)=>s(x['id'])).toSet();
    final ownJobs=jobs.where((j)=>s(j['department_id'])==id||sectionIds.contains(s(j['department_id']))).toList();
    final people=employees.where((e){
      if(s(e['department_id'])==id)return true;
      if(s(e['administration_id'])==id){
        final dep=departments.where((x)=>s(x['id'])==s(e['department_id']));
        return dep.isEmpty||s(dep.first['department_level'])=='section';
      }
      return false;
    }).toList();
    return Padding(
      padding:const EdgeInsetsDirectional.only(start:10),
      child:ExpansionTile(
        leading:const Icon(Icons.account_tree_outlined,color:orange),
        title:Text('${s(d['department_code'])} • ${s(d['name_ar'])}'),
        children:[
          ...children.map((child)=>centralDepartmentNode(child,manualMode:manualMode)),
          ...ownJobs.map((j)=>ListTile(
            dense:true,
            leading:const Icon(Icons.work_outline,color:purple),
            title:Text('${s(j['job_code'])} • ${s(j['name_ar'])}'),
            subtitle:Text(s(j['name_en'])),
            trailing:manualMode?TextButton.icon(
              onPressed:locked?null:()async{final e=await search(false);if(e!=null)setState(()=>addEmployee(e,jobId:s(j['id'])));},
              icon:const Icon(Icons.person_add_alt_1),label:const Text('اختيار موظف'),
            ):null,
          )),
          ...people.map((e)=>employeeTreeTile(e,manualMode:manualMode)),
        ],
      ),
    );
  }

  Widget workLocationCard(Map<String,dynamic> location,{bool manualMode=false}) {
    final central=s(location['location_type'])=='central';
    final children=central
      ? departments.where((d)=>s(d['parent_id']).isEmpty&&s(d['work_location_id'])==s(location['id'])&&s(d['department_level'])!='section').map((d)=>centralDepartmentNode(d,manualMode:manualMode)).toList()
      : workUnits.map((unit)=>workUnitNode(location,unit,manualMode:manualMode)).toList();
    return Card(child:ExpansionTile(
      leading:Icon(central?Icons.account_balance_outlined:Icons.warehouse_outlined,color:purple),
      title:Text('${s(location['location_code'])} • ${s(location['name_ar'])}'),
      subtitle:Text(central?'الإدارة المركزية • إدارات فقط':'وحدات العمل • مكتب إداري / مخازن / سيارات'),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        IconButton(onPressed:()=>masterDialog('location',row:location),icon:const Icon(Icons.edit_outlined)),
        IconButton(onPressed:()=>deleteRow('location',location),icon:const Icon(Icons.delete_outline,color:Colors.red)),
      ]),
      children:children,
    ));
  }

  Widget workforce() => Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[
      Row(children:[
        Expanded(child:Text('قوة العمل • ${locations.length} موقع • ${jobs.length} وظيفة',style:const TextStyle(fontWeight:FontWeight.w900))),
        FilledButton.icon(onPressed:()=>masterDialog('location'),icon:const Icon(Icons.add),label:const Text('موقع')),
        FilledButton.icon(onPressed:()=>masterDialog('department'),icon:const Icon(Icons.add),label:const Text('إدارة')),
      ]),
      ...locations.map((l)=>workLocationCard(l)),
      const SizedBox(height:8),
      const Text('دليل الوظائف',style:TextStyle(fontWeight:FontWeight.w900)),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        columns:const [DataColumn(label:Text('كود الوظيفة')),DataColumn(label:Text('عربي')),DataColumn(label:Text('English')),DataColumn(label:Text('إجراءات'))],
        rows:jobs.map((j)=>DataRow(cells:[
          DataCell(Text(s(j['job_code']))),DataCell(Text(s(j['name_ar']))),DataCell(Text(s(j['name_en']))),
          DataCell(Row(children:[IconButton(onPressed:()=>masterDialog('job',row:j),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>deleteRow('job',j),icon:const Icon(Icons.delete_outline,color:Colors.red))]))
        ])).toList(),
      )),
    ],
  );

  Future<Map<String,dynamic>?> search(bool job)async{final q=TextEditingController();Map<String,dynamic>? chosen;final source=job?jobs:employees;await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){final term=q.text.toLowerCase().trim();final rows=source.where((x){final fields=job?[x['job_code'],x['name_ar'],x['name_en']]:[x['employee_code'],x['full_name'],x['full_name_en'],x['job_title'],x['department_name'],x['governorate'],x['district'],x['locality'],branches.where((b)=>s(b['id'])==s(x['branch_id'])).map((b)=>s(b['branch_name'])).join()];return term.isEmpty||fields.any((v)=>s(v).toLowerCase().contains(term));}).toList();return AlertDialog(title:Text(job?'بحث الوظائف':'بحث الموظفين'),content:SizedBox(width:650,height:430,child:Column(children:[TextField(controller:q,autofocus:true,decoration:InputDecoration(labelText:job?'ابحث بالكود أو الاسم عربي/إنجليزي':'كود أو اسم أو فرع أو إدارة أو قسم أو موقع',prefixIcon:const Icon(Icons.search)),onChanged:(_)=>refresh((){})),Expanded(child:ListView(children:rows.map((x)=>ListTile(title:Text(job?'${s(x['job_code'])} • ${s(x['name_ar'])}':'${s(x['employee_code'])} • ${s(x['full_name'])}'),subtitle:Text(job?s(x['name_en']):'${s(x['department_name'])} • ${s(x['district'])}'),onTap:(){chosen=x;Navigator.pop(ctx);})).toList()))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]);}));q.dispose();return chosen;}
  void addEmployee(Map<String,dynamic> e,{String? jobId}){final id=s(e['id']);if(!daily.containsKey(id))daily[id]={'employeeId':id,'jobId':jobId??s(e['job_id']),'present':false,'absent':false,'fraction':'يوم كامل','absenceType':'غياب بدون إذن','penalty':'بدون جزاء'};}
  Future<void> yesterday()async{if(locked)return;try{final rows=await _db.from('erp_attendance_records').select().eq('company_id',_company.text.trim()).eq('work_date',date(day.subtract(const Duration(days:1))));setState((){daily.clear();for(final raw in rows){final r=Map<String,dynamic>.from(raw);daily[s(r['employee_id'])]={'employeeId':s(r['employee_id']),'jobId':s(r['job_id']),'present':s(r['attendance_status'])!='absent','absent':s(r['attendance_status'])=='absent','fraction':fractions.entries.firstWhere((x)=>x.value==((r['attendance_fraction'] as num?)?.toDouble()??1),orElse:()=>fractions.entries.first).key,'absenceType':s(r['absence_type']).isEmpty?'غياب بدون إذن':s(r['absence_type']),'penalty':penalties.entries.firstWhere((x)=>x.value==((r['absence_penalty_days'] as num?)?.toDouble()??0),orElse:()=>penalties.entries.first).key};}message='تم استدعاء كشف أمس؛ راجعه ثم احفظ.';});}catch(e){if(mounted)setState(()=>error='تعذر استدعاء أمس: $e');}}
  Future<void> saveAttendance()async{if(locked){setState(()=>error='الشهر مقفل بالرواتب.');return;}setState(()=>saving=true);try{for(final x in daily.values){final e=emp(s(x['employeeId']));if(e==null)continue;final absent=x['absent']==true,present=x['present']==true&&!absent,absence=s(x['absenceType']);final old=attendance.where((r)=>s(r['employee_id'])==s(e['id'])&&s(r['work_date'])==date(day));await _db.from('erp_attendance_records').upsert({'company_id':_company.text.trim(),'employee_id':e['id'],'work_date':date(day),'check_in':present?(old.isEmpty?DateTime(day.year,day.month,day.day,9).toIso8601String():old.first['check_in']):null,'check_out':old.isEmpty?null:old.first['check_out'],'attendance_status':absent?'absent':present?'present':'excused','attendance_fraction':present?(fractions[s(x['fraction'])]??1):0,'absence_type':absent?absence:null,'absence_penalty_days':absent&&absence=='غياب بدون إذن'?(penalties[s(x['penalty'])]??0):0,'attendance_source':'manual','job_id':s(x['jobId']).isEmpty?e['job_id']:x['jobId'],'notes':present?'تسجيل حضور يدوي':absent?'حالة غياب: $absence':'لم يسجل حضور'},onConflict:'employee_id,work_date');}if(mounted)setState(()=>message='تم حفظ ${daily.length} سجلًا ليوم ${date(day)}.');await load();}catch(e){if(mounted)setState(()=>error='تعذر حفظ الحضور: $e');}finally{if(mounted)setState(()=>saving=false);}}
  Future<void> direct(Map<String,dynamic> e)async{if(locked)return;try{await _db.from('erp_attendance_records').upsert({'company_id':_company.text.trim(),'employee_id':e['id'],'work_date':date(day),'check_in':DateTime.now().toIso8601String(),'attendance_status':'present','attendance_fraction':1,'absence_type':null,'absence_penalty_days':0,'attendance_source':'direct','notes':'تسجيل حضور مباشر فقط'},onConflict:'employee_id,work_date');if(mounted)setState(()=>message='تم تسجيل حضور مباشر فقط للموظف ${s(e['full_name'])}.');await load();}catch(e){if(mounted)setState(()=>error='تعذر تسجيل الحضور: $e');}}
  Future<void> changeEmployee(Map<String,dynamic> row,String jobId) async { final picked=await search(false); if(picked==null)return; setState((){daily.remove(s(row['employeeId']));addEmployee(picked,jobId:jobId);}); }
  Widget attendanceRow(Map<String,dynamic> x){final e=emp(s(x['employeeId']));if(e==null)return const SizedBox.shrink();final jid=s(x['jobId']).isEmpty?s(e['job_id']):s(x['jobId']);final found=jobs.where((j)=>s(j['id'])==jid);final j=found.isEmpty?null:found.first;final abs=x['absent']==true;return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[SizedBox(width:95,child:Text(s(j?['job_code']),style:const TextStyle(fontWeight:FontWeight.w900))),Expanded(child:Text(s(j?['name_ar']).isEmpty?s(e['job_title']):s(j?['name_ar']),style:const TextStyle(fontWeight:FontWeight.w800))),IconButton(onPressed:locked?null:()=>setState(()=>daily.remove(s(e['id']))),icon:const Icon(Icons.remove_circle_outline,color:Colors.red))]),Row(children:[SizedBox(width:115,child:GestureDetector(onDoubleTap:locked?null:()=>changeEmployee(x,jid),child:Text(s(e['employee_code']),style:const TextStyle(color:purple,fontWeight:FontWeight.w900)))),Expanded(child:Text(s(e['full_name']))),Checkbox(value:x['present']==true&&!abs,onChanged:locked?null:(v)=>setState((){x['present']=v==true;x['absent']=false;})),const Text('حضور')]),Wrap(spacing:7,runSpacing:5,children:[const Text('نوع الحضور'),SizedBox(width:120,child:DropdownButtonFormField<String>(value:fractions.containsKey(s(x['fraction']))?s(x['fraction']):'يوم كامل',isExpanded:true,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()),items:fractions.keys.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:locked||abs?null:(v)=>setState(()=>x['fraction']=v??'يوم كامل'))),Checkbox(value:abs,onChanged:locked?null:(v)=>setState((){x['absent']=v==true;x['present']=false;if(v!=true)x['penalty']='بدون جزاء';})),const Text('غياب'),SizedBox(width:170,child:DropdownButtonFormField<String>(value:absenceTypes.contains(s(x['absenceType']))?s(x['absenceType']):'غياب بدون إذن',isExpanded:true,decoration:const InputDecoration(labelText:'حالة الغياب',isDense:true,border:OutlineInputBorder()),items:absenceTypes.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:locked||!abs?null:(v)=>setState((){x['absenceType']=v??'غياب بدون إذن';if(v!='غياب بدون إذن')x['penalty']='بدون جزاء';}))),SizedBox(width:140,child:DropdownButtonFormField<String>(value:penalties.containsKey(s(x['penalty']))?s(x['penalty']):'بدون جزاء',isExpanded:true,decoration:const InputDecoration(labelText:'جزاء الغياب',isDense:true,border:OutlineInputBorder()),items:penalties.keys.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:locked||!abs||s(x['absenceType'])!='غياب بدون إذن'?null:(v)=>setState(()=>x['penalty']=v??'بدون جزاء'))),FilledButton.tonal(onPressed:locked?null:()=>direct(e),child:const Text('تسجيل حضور مباشر'))])])));}
  Widget manual(){final days=DateTime(day.year,day.month+1,0).day;return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:Text('الحضور اليدوي • ${date(day)} • ${locked?'مقفل':'مفتوح'}',style:const TextStyle(fontWeight:FontWeight.w900))),OutlinedButton.icon(onPressed:locked?null:yesterday,icon:const Icon(Icons.content_copy),label:const Text('استدعاء موظفين أمس')),FilledButton.icon(onPressed:locked||saving?null:saveAttendance,icon:const Icon(Icons.save),label:const Text('حفظ اليوم'))]),if(locked)notice('مسير الرواتب مقفل؛ الشهر للقراءة فقط.',Colors.red),SizedBox(height:86,child:ListView(scrollDirection:Axis.horizontal,children:List.generate(days,(i){final d=DateTime(day.year,day.month,i+1),selected=d.day==day.day;return Padding(padding:const EdgeInsetsDirectional.only(end:5),child:OutlinedButton(style:OutlinedButton.styleFrom(backgroundColor:selected?purple:null,foregroundColor:selected?Colors.white:null),onPressed:()=>setState((){day=d;rebuild();}),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('${d.day}',style:const TextStyle(fontWeight:FontWeight.w900)),Text(weekday(d),style:const TextStyle(fontSize:10))])));}))),const Text('شجرة قوة العمل — اختر الموظف أمام الوظيفة',style:TextStyle(fontWeight:FontWeight.w900)),...locations.map((l)=>workLocationCard(l,manualMode:true)),Row(children:[Expanded(child:Text('كشف اليوم • ${daily.length} موظف',style:const TextStyle(fontWeight:FontWeight.w900))),TextButton.icon(onPressed:locked?null:()async{final e=await search(false);if(e!=null)setState(()=>addEmployee(e));},icon:const Icon(Icons.person_search),label:const Text('اختيار موظف')),TextButton.icon(onPressed:locked?null:()async{final j=await search(true);if(j==null)return;final e=await search(false);if(e!=null)setState(()=>addEmployee(e,jobId:s(j['id'])));},icon:const Icon(Icons.work_outline),label:const Text('وظيفة + موظف'))]),if(daily.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('اختر يومًا ثم أضف الموظفين أو استدعِ كشف أمس.')),...daily.values.map(attendanceRow)]);}
  Future<void> processFingerprint()async{if(locked){setState(()=>error='الشهر مقفل؛ لن تعدّل المعالجة السجلات.');return;}setState(()=>saving=true);try{final buckets=<String,List<Map<String,dynamic>>>{};for(final e in events.where((x)=>s(x['processing_status'])!='processed'&&s(x['employee_id']).isNotEmpty)){final at=DateTime.tryParse(s(e['event_at']));if(at==null)continue;(buckets['${s(e['employee_id'])}|${date(at)}']??=<Map<String,dynamic>>[]).add(e);}var count=0;for(final entry in buckets.entries){final parts=entry.key.split('|');final person=emp(parts.first);if(person==null)continue;final list=entry.value..sort((a,b)=>s(a['event_at']).compareTo(s(b['event_at'])));await _db.from('erp_attendance_records').upsert({'company_id':_company.text.trim(),'employee_id':person['id'],'work_date':parts.last,'check_in':list.first['event_at'],'check_out':list.length>1?list.last['event_at']:null,'attendance_status':'present','attendance_fraction':1,'absence_type':null,'absence_penalty_days':0,'attendance_source':'fingerprint','notes':'معالجة من جهاز البصمة'},onConflict:'employee_id,work_date');for(final e in list){await _db.from('erp_hr_attendance_events').update({'processing_status':'processed','processing_note':'مطابقة ${s(person['employee_code'])}'}).eq('id',s(e['id']));}count++;}if(mounted)setState(()=>message='تمت معالجة $count مجموعة حضور من البصمة.');await load();}catch(e){if(mounted)setState(()=>error='تعذرت معالجة البصمات: $e');}finally{if(mounted)setState(()=>saving=false);}}
  Future<void> matchEvent(Map<String,dynamic> event)async{final e=await search(false);if(e==null)return;try{await _db.from('erp_hr_attendance_events').update({'employee_id':e['id'],'processing_note':'مطابقة يدوية'}).eq('id',s(event['id']));await load();}catch(err){if(mounted)setState(()=>error='تعذرت المطابقة: $err');}}
  Widget fingerprint(){final pending=events.where((e)=>s(e['processing_status'])!='processed'||s(e['employee_id']).isEmpty).length;return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:Text('حضور جهاز البصمة • ${devices.length} جهاز • ${events.length} حركة',style:const TextStyle(fontWeight:FontWeight.w900))),FilledButton.icon(onPressed:loading?null:load,icon:const Icon(Icons.sync),label:const Text('تحديث')),FilledButton.icon(onPressed:saving||locked?null:processFingerprint,icon:const Icon(Icons.fact_check_outlined),label:const Text('معالجة البصمات'))]),if(locked)notice('الشهر مقفل بالرواتب.',Colors.red),Wrap(spacing:8,children:[Chip(label:Text('الأجهزة: ${devices.length}')),Chip(label:Text('حركات غير معالجة: $pending')),Chip(label:Text('الموظفون: ${employees.length}'))]),const Text('شجرة قوة العمل',style:TextStyle(fontWeight:FontWeight.w900)),...locations.map((l)=>workLocationCard(l)),const SizedBox(height:8),const Text('أجهزة البصمة المسجلة',style:TextStyle(fontWeight:FontWeight.w900)),if(devices.isEmpty)const Text('لا توجد أجهزة مسجلة. أضفها من شاشة أجهزة البصمة وربط الحضور.'),...devices.map((d)=>Card(child:ListTile(leading:const Icon(Icons.fingerprint,color:purple),title:Text(s(d['device_name'])),subtitle:Text('${s(d['manufacturer'])} ${s(d['model'])} • ${s(d['ip_address'])}:${s(d['port'])}\nآخر مزامنة: ${s(d['last_sync_at'])}'),trailing:Chip(label:Text(s(d['status']).isEmpty?'غير معروف':s(d['status'])))))),const SizedBox(height:8),const Text('الحركات الخام — الأحدث أولًا',style:TextStyle(fontWeight:FontWeight.w900)),if(events.isEmpty)const Text('لا توجد حركات بصمة مستوردة للفترة المحددة.'),...events.take(250).map((e)=>Card(child:ListTile(dense:true,leading:Icon(s(e['processing_status'])=='processed'?Icons.check_circle:Icons.schedule,color:s(e['processing_status'])=='processed'?Colors.green:orange),title:Text(emp(s(e['employee_id']))==null?'كود البصمة: ${s(e['employee_code'])}':empName(e['employee_id'])),subtitle:Text('${s(e['event_at'])} • ${s(e['event_type'])} • ${s(e['processing_status'])}'),trailing:emp(s(e['employee_id']))==null?TextButton(onPressed:()=>matchEvent(e),child:const Text('مطابقة')):null)))]);}
  Map<String, dynamic> _exportData() {
    final headers = <String>[];
    final rows = <List<String>>[];
    String status(bool present, bool absent) => absent ? 'غياب' : present ? 'حضور' : 'لم يحدد';
    if (_tabs.index == 0) {
      headers.addAll(['نوع السجل', 'الكود', 'الاسم بالعربية', 'الاسم بالإنجليزية', 'موقع العمل', 'يتبع', 'الحالة']);
      for (final l in locations) {
        rows.add(['موقع عمل', s(l['location_code']), s(l['name_ar']), s(l['name_en']), s(l['name_ar']), '—', l['is_active'] == false ? 'غير نشط' : 'نشط']);
      }
      for (final d in departments) {
        final location = locations.where((x) => s(x['id']) == s(d['work_location_id']));
        final parent = departments.where((x) => s(x['id']) == s(d['parent_id']));
        rows.add(['إدارة / قسم', s(d['department_code']), s(d['name_ar']), s(d['name_en']), location.isEmpty ? '—' : s(location.first['name_ar']), parent.isEmpty ? '—' : s(parent.first['name_ar']), d['is_active'] == false ? 'غير نشط' : 'نشط']);
      }
      for (final j in jobs) {
        final department = departments.where((x) => s(x['id']) == s(j['department_id']));
        rows.add(['وظيفة', s(j['job_code']), s(j['name_ar']), s(j['name_en']), '—', department.isEmpty ? '—' : s(department.first['name_ar']), j['is_active'] == false ? 'غير نشط' : 'نشط']);
      }
    } else if (_tabs.index == 1) {
      headers.addAll(['التاريخ', 'كود الموظف', 'اسم الموظف', 'كود الوظيفة', 'اسم الوظيفة', 'موقع العمل', 'الإدارة / القسم', 'الحالة', 'نوع الحضور', 'حالة الغياب', 'جزاء الغياب']);
      for (final x in daily.values) {
        final e = emp(s(x['employeeId']));
        if (e == null) continue;
        final jobId = s(x['jobId']).isEmpty ? s(e['job_id']) : s(x['jobId']);
        final jobRows = jobs.where((j) => s(j['id']) == jobId);
        final job = jobRows.isEmpty ? <String, dynamic>{} : jobRows.first;
        final locRows = locations.where((l) => s(l['id']) == s(e['work_location_id']));
        rows.add([
          date(day), s(e['employee_code']), s(e['full_name']), s(job['job_code']), s(job['name_ar']).isEmpty ? s(e['job_title']) : s(job['name_ar']),
          locRows.isEmpty ? '—' : s(locRows.first['name_ar']), s(e['department_name']), status(x['present'] == true, x['absent'] == true),
          x['present'] == true ? s(x['fraction']) : '—', x['absent'] == true ? s(x['absenceType']) : '—',
          x['absent'] == true && s(x['absenceType']) == 'غياب بدون إذن' ? s(x['penalty']) : 'بدون جزاء',
        ]);
      }
    } else {
      headers.addAll(['نوع السجل', 'الجهاز / الكود', 'اسم الجهاز / الموظف', 'كود الموظف', 'اسم الموظف', 'التاريخ والوقت', 'نوع الحركة', 'حالة المعالجة', 'ملاحظات']);
      for (final d in devices) {
        rows.add(['جهاز', s(d['device_code']).isEmpty ? s(d['id']) : s(d['device_code']), s(d['device_name']), '', '', s(d['last_sync_at']), s(d['manufacturer']) + ' ' + s(d['model']), s(d['status']), s(d['ip_address']) + ':' + s(d['port'])]);
      }
      for (final e in events) {
        final person = emp(s(e['employee_id']));
        rows.add(['حركة بصمة', s(e['device_id']), person == null ? s(e['employee_code']) : s(person['full_name']), person == null ? s(e['employee_code']) : s(person['employee_code']), person == null ? 'غير مطابق' : s(person['full_name']), s(e['event_at']), s(e['event_type']), s(e['processing_status']), s(e['processing_note'])]);
      }
    }
    final titles = ['قوة العمل', 'الحضور اليدوي', 'حضور جهاز البصمة'];
    return {'title': 'الحضور والانصراف — ${titles[_tabs.index]}', 'sheet': titles[_tabs.index], 'headers': headers, 'rows': rows};
  }

  Future<Uint8List> _attendancePdfBytes() async {
    final data = _exportData();
    final headers = List<String>.from(data['headers'] as List).reversed.toList();
    final rows = (data['rows'] as List).map((r) => List<String>.from(r as List).reversed.toList()).toList();
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
        pw.Text('سلسلة — ${data['title']}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('الشركة: ${_company.text.trim()}    •    تاريخ التقرير: ${date(day)}    •    عدد السجلات: ${rows.length}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        if (rows.isEmpty) pw.Text('لا توجد بيانات للتصدير.', textAlign: pw.TextAlign.right)
        else pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
        ),
      ],
    ));
    return Uint8List.fromList(await pdf.save());
  }

  Future<void> exportExcel() async {
    final data = _exportData();
    final rows = (data['rows'] as List).map((r) => List<String>.from(r as List)).toList();
    if (rows.isEmpty) { setState(() => message = 'لا توجد بيانات في التابة الحالية لتصديرها.'); return; }
    setState(() { loading = true; error = null; message = null; });
    try {
      final workbook = Excel.createExcel();
      final sheet = workbook[data['sheet'] as String];
      sheet.appendRow((data['headers'] as List<String>).map((x) => TextCellValue(x)).toList());
      for (final row in rows) {
        sheet.appendRow(row.map((x) => TextCellValue(x)).toList());
      }
      final encoded = workbook.encode();
      if (encoded == null || encoded.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'silsila_attendance_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(encoded),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) setState(() => message = 'تم تصدير ${rows.length} سجلًا إلى Excel.');
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر تصدير Excel: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> exportPdf() async {
    final data = _exportData();
    final rows = data['rows'] as List;
    if (rows.isEmpty) { setState(() => message = 'لا توجد بيانات في التابة الحالية لتصديرها.'); return; }
    setState(() { loading = true; error = null; message = null; });
    try {
      final bytes = await _attendancePdfBytes();
      await FileSaver.instance.saveFile(
        name: 'silsila_attendance_${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (mounted) setState(() => message = 'تم إنشاء ملف PDF وتنزيله.');
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر إنشاء PDF: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> printReport() async {
    final data = _exportData();
    if ((data['rows'] as List).isEmpty) { setState(() => message = 'لا توجد بيانات للطباعة.'); return; }
    setState(() { loading = true; error = null; message = null; });
    try {
      final bytes = await _attendancePdfBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'silsila_attendance.pdf');
    } catch (e) {
      if (mounted) setState(() => error = 'تعذرت الطباعة: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addForTab() async {
    if(_tabs.index==0){await masterDialog('location');return;}
    if(_tabs.index==1){final e=await search(false);if(e!=null)setState(()=>addEmployee(e));return;}
    if(mounted)setState(()=>message='لإضافة جهاز بصمة جديد افتح «أجهزة البصمة وربط الحضور».');
  }
  Future<void> editJobFromSearch() async { final j=await search(true);if(j!=null)await masterDialog('job',row:j); }
  Future<void> deleteJobFromSearch() async { final j=await search(true);if(j!=null)await deleteRow('job',j); }
  Future<void> preview()async{final rows=_tabs.index==0?jobs:_tabs.index==1?attendance.where((r)=>s(r['work_date'])==date(day)).toList():events;await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('معاينة'),content:SizedBox(width:650,child:rows.isEmpty?const Text('لا توجد بيانات.'):SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:rows.take(100).map((r)=>ListTile(dense:true,title:Text(s(r['name_ar']).isNotEmpty?s(r['name_ar']):s(r['full_name']).isNotEmpty?s(r['full_name']):s(r['employee_code'])),subtitle:Text('${s(r['job_code'])} ${s(r['work_date'])} ${s(r['event_at'])}'))).toList()))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));}
  @override
  Widget build(BuildContext context) {
    final tab = _tabs.index;
    final headerTasks = Row(children: [
      task('تحديث', Icons.refresh, Colors.blue, loading ? null : load),
      task('إضافة', Icons.add_circle_outline, const Color(0xFF168447), saving ? null : () => masterDialog(tab == 0 ? 'location' : 'job')),
      task('حفظ', Icons.save_outlined, const Color(0xFF168447), tab == 1 && !saving && !locked ? saveAttendance : null),
      task('تعديل', Icons.edit_outlined, orange, tab == 0 && jobs.isNotEmpty ? () => masterDialog('job', row: jobs.first) : null),
      task('حذف', Icons.delete_outline, Colors.red, tab == 0 && jobs.isNotEmpty ? () => deleteRow('job', jobs.first) : null),
      task('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), preview),
      task('طباعة', Icons.print_outlined, const Color(0xFF536DFE), loading ? null : printReport),
      task('Excel', Icons.table_view_outlined, const Color(0xFF168447), loading ? null : exportExcel),
      task('PDF', Icons.picture_as_pdf_outlined, Colors.red, loading ? null : exportPdf),
    ]);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: purple,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('الحضور والانصراف', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  const Text('قوة العمل • الحضور اليدوي • حضور جهاز البصمة', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: headerTasks),
                ],
              ),
            ),
          ),
          TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
          if (error != null) notice(error!, Colors.red),
          if (message != null) notice(message!, Colors.green),
          if (loading || saving) const LinearProgressIndicator(),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: purple,
            indicatorColor: orange,
            tabs: const [
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'قوة العمل'),
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'الحضور اليدوي'),
              Tab(icon: Icon(Icons.fingerprint), text: 'حضور جهاز البصمة'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                SingleChildScrollView(child: workforce()),
                SingleChildScrollView(child: manual()),
                SingleChildScrollView(child: fingerprint()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
