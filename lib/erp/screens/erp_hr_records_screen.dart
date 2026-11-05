import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class _Field {
  const _Field(this.key, this.label, {this.type='text', this.required=false, this.options=const []});
  final String key, label, type;
  final bool required;
  final List<String> options;
}
class _Config {
  const _Config(this.title, this.table, this.fields, this.examples, this.help);
  final String title, table, help;
  final List<_Field> fields;
  final List<Map<String,String>> examples;
}

class ErpHrRecordsScreen extends StatefulWidget {
  const ErpHrRecordsScreen({super.key, required this.page, required this.companyId});
  final String page;
  final String? companyId;
  @override State<ErpHrRecordsScreen> createState() => _ErpHrRecordsScreenState();
}

class _ErpHrRecordsScreenState extends State<ErpHrRecordsScreen> {
  final _db = Supabase.instance.client;
  bool _loading=true;
  String? _error;
  List<Map<String,dynamic>> _rows=[];
  List<Map<String,dynamic>> _employees=[];
  List<Map<String,dynamic>> _jobs=[];
  List<Map<String,dynamic>> _departments=[];
  List<Map<String,dynamic>> _branches=[];

  _Config get _config {
    final p=widget.page;
    if (p.contains('توظيف') || p.contains('مرشحين') || p.contains('مقابلات') || p.contains('عروض العمل') || p.contains('الوظائف الشاغرة')) {
      return _Config(p,'erp_hr_recruitment_candidates',const [
        _Field('candidate_name','اسم المرشح',required:true),_Field('job_id','الوظيفة',type:'job'),
        _Field('phone','رقم الهاتف'),_Field('email','البريد الإلكتروني'),
        _Field('status','مرحلة التوظيف',type:'choice',options:['new','screening','interview','accepted','rejected','withdrawn']),
        _Field('applied_on','تاريخ التقديم',type:'date',required:true),_Field('decision_on','تاريخ القرار',type:'date'),
        _Field('interview_date','موعد المقابلة',type:'date'),
        _Field('interview_result','نتيجة المقابلة',type:'choice',options:['pending','passed','failed','rescheduled']),
        _Field('interview_notes','ملاحظات المقابلة'),
        _Field('offer_salary','قيمة عرض العمل',type:'number'),
        _Field('offer_issued_on','تاريخ إصدار العرض',type:'date'),
        _Field('offer_expires_on','انتهاء العرض',type:'date'),
        _Field('joining_date','تاريخ مباشرة العمل',type:'date'),
        _Field('source','مصدر الترشيح'),_Field('notes','ملاحظات'),
      ],const [
        {'candidate_name':'مرشح توضيحي — أحمد','status':'interview','applied_on':'2026-11-01','source':'ترشيح مباشر'},
        {'candidate_name':'مرشحة توضيحية — منى','status':'screening','applied_on':'2026-11-03','source':'إعلان وظيفة'},
        {'candidate_name':'مرشح توضيحي — محمد','status':'new','applied_on':'2026-11-04','source':'قاعدة المرشحين'},
      ],'مسار التوظيف من استلام الطلب والفرز إلى المقابلة والقبول أو الاعتذار. سجّل كل مرشح وحدث مرحلته من نفس الملف.');
    }
    if (p.contains('حركة التعيينات') || p.contains('حركة الموظفين') || p.contains('نقل') || p.contains('ترقي') || p.contains('مباشرة') || p.contains('فترة الاختبار') || p.contains('إنهاء الخدمة') || p.contains('ترك الخدمة')) {
      return _Config(p,'erp_hr_employee_movements',const [
        _Field('employee_id','الموظف',type:'employee',required:true),
        _Field('movement_type','نوع الحركة',type:'choice',required:true,options:['hire','resignation','termination','retirement','transfer','promotion','suspension','return_to_work']),
        _Field('effective_on','تاريخ السريان',type:'date',required:true),_Field('target_branch_id','الفرع المستهدف',type:'branch'),_Field('target_department_id','الإدارة المستهدفة',type:'department'),_Field('target_job_id','الوظيفة المستهدفة',type:'job'),_Field('reason','سبب الحركة',required:true),
        _Field('rehire_eligible','مسموح بإعادة التعيين',type:'bool'),_Field('notes','ملاحظات'),
      ],const [
        {'movement_type':'hire','effective_on':'2026-11-01','reason':'تعيين توضيحي','rehire_eligible':'نعم'},
        {'movement_type':'transfer','effective_on':'2026-11-03','reason':'نقل توضيحي بين الإدارات','rehire_eligible':'نعم'},
      ],'سجل تاريخي للتعيينات والنقل والترقيات والاستقالة وإنهاء الخدمة مع تاريخ سريان كل حركة.');
    }
    if (p.contains('تقييم') || p.contains('الأداء')) {
      return _Config(p,'erp_hr_performance_reviews',const [
        _Field('employee_id','الموظف',type:'employee',required:true),_Field('period_start','بداية الفترة',type:'date',required:true),
        _Field('period_end','نهاية الفترة',type:'date',required:true),_Field('score','الدرجة من 100',type:'number',required:true),
        _Field('rating','التقدير'),_Field('strengths','نقاط القوة'),_Field('improvement_areas','نقاط التحسين'),
        _Field('goals','الأهداف القادمة'),_Field('status','الحالة',type:'choice',options:['draft','submitted','approved','rejected']),
      ],const [
        {'period_start':'2026-10-01','period_end':'2026-10-31','score':'92','rating':'ممتاز','status':'approved'},
        {'period_start':'2026-10-01','period_end':'2026-10-31','score':'84','rating':'جيد جدًا','status':'submitted'},
      ],'تقييم دوري مرتبط بالموظف والفترة والدرجة والأهداف، مع حالات المسودة والإرسال والاعتماد.');
    }
    if (p.contains('إضافي') || p.contains('ساعات العمل')) {
      return _Config(p,'erp_hr_overtime_requests',const [
        _Field('employee_id','الموظف',type:'employee',required:true),_Field('work_date','التاريخ',type:'date',required:true),
        _Field('hours','عدد الساعات',type:'number',required:true),_Field('hourly_rate','قيمة الساعة',type:'number',required:true),
        _Field('amount','إجمالي المستحق',type:'number'),_Field('reason','السبب',required:true),
        _Field('status','الحالة',type:'choice',options:['pending','approved','rejected','paid']),_Field('notes','ملاحظات'),
      ],const [
        {'work_date':'2026-11-02','hours':'2','hourly_rate':'50','amount':'100','reason':'جرد مخزن — مثال','status':'pending'},
        {'work_date':'2026-11-03','hours':'3','hourly_rate':'50','amount':'150','reason':'تجهيز طلبات — مثال','status':'approved'},
      ],'تسجيل الساعات الإضافية وربطها بالموظف والتاريخ والسعر والاعتماد ثم إدراجها في المستحقات.');
    }
    if (p.contains('سلف')) {
      return _Config(p,'erp_hr_employee_advances',const [
        _Field('employee_id','الموظف',type:'employee',required:true),_Field('advance_number','رقم السلفة'),
        _Field('requested_on','تاريخ الطلب',type:'date',required:true),_Field('amount','قيمة السلفة',type:'number',required:true),
        _Field('installments','عدد الأقساط',type:'number',required:true),_Field('installment_amount','قيمة القسط',type:'number',required:true),
        _Field('reason','السبب',required:true),_Field('status','الحالة',type:'choice',options:['pending','approved','rejected','disbursed','settled']),
        _Field('settled_amount','المبلغ المسدد',type:'number'),_Field('notes','ملاحظات'),
      ],const [
        {'requested_on':'2026-11-01','amount':'3000','installments':'3','installment_amount':'1000','reason':'سلفة توضيحية','status':'pending'},
        {'requested_on':'2026-10-15','amount':'2000','installments':'2','installment_amount':'1000','reason':'سلفة توضيحية','status':'disbursed'},
      ],'متابعة طلب السلفة واعتمادها وصرفها وجدولة الأقساط والتسوية.');
    }
    if (p.contains('عهد')) {
      return _Config(p,'erp_hr_employee_custodies',const [
        _Field('employee_id','الموظف',type:'employee',required:true),
        _Field('item_name','العهدة / الصنف',required:true),
        _Field('category','تصنيف العهدة'),
        _Field('serial_number','الرقم المسلسل'),
        _Field('assigned_on','تاريخ التسليم',type:'date',required:true),
        _Field('expected_return_on','موعد الإرجاع المتوقع',type:'date'),
        _Field('returned_on','تاريخ الإرجاع',type:'date'),
        _Field('status','الحالة',type:'choice',options:['assigned','returned','lost','damaged']),
        _Field('condition_on_issue','الحالة عند التسليم'),
        _Field('condition_on_return','الحالة عند الإرجاع'),
        _Field('notes','ملاحظات'),
      ],const [
        {'item_name':'حاسب محمول — مثال توضيحي','category':'أجهزة','serial_number':'DEMO-001','assigned_on':'2026-11-01','expected_return_on':'2027-11-01','status':'assigned'},
        {'item_name':'هاتف عمل — مثال توضيحي','category':'اتصالات','serial_number':'DEMO-002','assigned_on':'2026-10-15','status':'returned'},
      ],'سجل عهد الموظفين من التسليم والاستلام إلى الإرجاع أو الفقد أو التلف، مع توثيق حالة العهدة.');
    }
    if (p.contains('جزاء') || p.contains('مكاف') || p.contains('عهد')) {
      return _Config(p,'erp_hr_employee_actions',const [
        _Field('employee_id','الموظف',type:'employee',required:true),_Field('action_type','نوع الإجراء',type:'choice',required:true,options:['penalty','reward']),
        _Field('action_date','التاريخ',type:'date',required:true),_Field('amount','القيمة',type:'number',required:true),
        _Field('reason','السبب',required:true),_Field('status','الحالة',type:'choice',options:['pending','approved','rejected','applied']),_Field('notes','ملاحظات'),
      ],const [
        {'action_type':'reward','action_date':'2026-11-02','amount':'500','reason':'أداء متميز — مثال','status':'pending'},
        {'action_type':'penalty','action_date':'2026-11-03','amount':'100','reason':'مخالفة لائحة — مثال','status':'approved'},
      ],'تسجيل الجزاءات والمكافآت مع السبب والقيمة وحالة الاعتماد.');
    }
    if (p.contains('تأمين') || p.contains('رخص') || p.contains('امتثال') || p.contains('مسوغات')) {
      return _Config(p,'erp_hr_employee_compliance',const [
        _Field('employee_id','الموظف',type:'employee',required:true),
        _Field('record_type','نوع السجل',type:'choice',required:true,options:['health_insurance','social_insurance','license']),
        _Field('status','الحالة',type:'choice',required:true,options:['insured','uninsured','in_progress','valid','expired','not_required']),
        _Field('provider','الجهة / مقدم الخدمة'),_Field('reference_number','رقم المرجع'),
        _Field('issued_on','تاريخ الإصدار',type:'date'),_Field('expires_on','تاريخ الانتهاء',type:'date'),_Field('notes','ملاحظات'),
      ],const [
        {'record_type':'social_insurance','status':'insured','provider':'الهيئة القومية للتأمين الاجتماعي','reference_number':'مثال توضيحي'},
        {'record_type':'license','status':'valid','provider':'جهة إصدار الرخصة','reference_number':'LIC-DEMO','expires_on':'2027-06-30'},
      ],'ملف التأمينات والتراخيص والمسوغات مع متابعة الصلاحية وتواريخ الإصدار والانتهاء.');
    }
    if (p.contains('تدريب') || p.contains('شهادات')) {
      return _Config(p,'erp_hr_training_records',const [
        _Field('employee_id','الموظف',type:'employee',required:true),_Field('course_name','اسم البرنامج التدريبي',required:true),
        _Field('provider','جهة التدريب'),_Field('status','الحالة',type:'choice',options:['planned','in_progress','completed','expired','cancelled']),
        _Field('starts_on','تاريخ البداية',type:'date'),_Field('ends_on','تاريخ النهاية',type:'date'),
        _Field('certificate_expires_on','انتهاء الشهادة',type:'date'),_Field('notes','ملاحظات'),
      ],const [
        {'course_name':'سلامة الغذاء — مثال','provider':'مركز تدريب توضيحي','status':'completed','starts_on':'2026-10-10'},
        {'course_name':'مهارات خدمة العملاء — مثال','provider':'تدريب داخلي','status':'planned','starts_on':'2026-11-20'},
      ],'خطة التدريب وسجل التنفيذ والشهادات ومدد صلاحيتها وربطها بملف الموظف.');
    }
    if (p.contains('عقد') || p.contains('عقود') || p.contains('تجديد')) {
      return _Config(p,'erp_hr_employee_contracts',const [
        _Field('employee_id','الموظف',type:'employee',required:true),_Field('contract_number','رقم العقد'),
        _Field('contract_type','نوع التعاقد',type:'choice',options:['بعقد','بدون عقد','شركة عمالة','مؤقت','يومية']),
        _Field('start_date','تاريخ البداية',type:'date',required:true),_Field('end_date','تاريخ النهاية',type:'date'),
        _Field('salary','الأجر المتفق عليه',type:'number'),_Field('status','الحالة',type:'choice',options:['draft','active','expired','terminated']),_Field('notes','ملاحظات'),
      ],const [
        {'contract_number':'CTR-DEMO-001','contract_type':'بعقد','start_date':'2026-01-01','end_date':'2026-12-31','salary':'8000','status':'active'},
        {'contract_number':'CTR-DEMO-002','contract_type':'مؤقت','start_date':'2026-06-01','end_date':'2026-11-30','salary':'6500','status':'active'},
      ],'إدارة العقود وتواريخ سريانها وتجديدها وانتهائها، مع ربط كل عقد بملف الموظف.');
    }
    return _Config(p,'erp_hr_end_of_service_settlements',const [
      _Field('employee_id','الموظف',type:'employee',required:true),_Field('service_start_date','بداية الخدمة',type:'date',required:true),
      _Field('separation_date','تاريخ انتهاء الخدمة',type:'date',required:true),_Field('basic_salary_snapshot','الأجر الأساسي وقت التسوية',type:'number',required:true),
      _Field('accrued_leave_amount','مقابل رصيد الإجازات',type:'number'),_Field('other_entitlements','مستحقات أخرى',type:'number'),
      _Field('outstanding_advances','سلف قائمة',type:'number'),_Field('other_deductions','استقطاعات أخرى',type:'number'),
      _Field('total_entitlements','إجمالي المستحقات',type:'number'),_Field('net_amount','صافي التسوية',type:'number'),
      _Field('reason','سبب انتهاء الخدمة',required:true),_Field('status','الحالة',type:'choice',options:['pending','approved','rejected','paid']),_Field('notes','ملاحظات'),
    ],const [
      {'service_start_date':'2022-01-01','separation_date':'2026-11-01','basic_salary_snapshot':'7000','accrued_leave_amount':'1200','other_entitlements':'500','outstanding_advances':'300','net_amount':'1400','status':'pending'},
    ],'إعداد تسوية نهاية الخدمة وعرض مكوناتها قبل الاعتماد والصرف. راجع القيم قبل اعتمادها.');
  }

  static const _labels=<String,String>{
    'new':'جديد','screening':'فرز أولي','interview':'مقابلة','accepted':'مقبول','rejected':'مرفوض','withdrawn':'منسحب','passed':'اجتاز المقابلة','failed':'لم يجتز المقابلة','rescheduled':'إعادة جدولة',
    'draft':'مسودة','pending':'قيد المراجعة','approved':'معتمد','applied':'تم التطبيق','paid':'تم الصرف','disbursed':'تم الصرف','settled':'تمت التسوية',
    'submitted':'مرسل للمراجعة','completed':'مكتمل','in_progress':'جارٍ التنفيذ','expired':'منتهي','terminated':'منتهٍ','planned':'مخطط','cancelled':'ملغي',
    'hire':'تعيين','resignation':'استقالة','termination':'إنهاء خدمة','retirement':'تقاعد','transfer':'نقل','promotion':'ترقية','suspension':'إيقاف مؤقت','return_to_work':'عودة للعمل',
    'penalty':'جزاء','reward':'مكافأة','health_insurance':'تأمين صحي','social_insurance':'تأمين اجتماعي','license':'رخصة',
    'insured':'مؤمّن عليه','uninsured':'غير مؤمّن','valid':'ساري','not_required':'غير مطلوب', 'assigned':'بعهدة الموظف','returned':'تم الإرجاع','lost':'مفقود','damaged':'تالف',
  };
  String _label(dynamic v) => _labels[v.toString()] ?? v.toString();
  String _employeeName(dynamic id) {
    final found=_employees.where((e)=>e['id'].toString()==id.toString());
    if(found.isEmpty)return id.toString();
    return (found.first['employee_code'].toString()+' — '+found.first['full_name'].toString());
  }

  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    final company=(widget.companyId??'').trim();
    if(company.isEmpty){setState(()=>_loading=false);_error='افتح بيانات الشركة أولًا لعرض بيانات الموارد البشرية.';return;}
    setState(()=>_loading=true);
    try{
      final c=_config;
      final result=await Future.wait([
        _db.from(c.table).select('*').eq('company_id',company).limit(500),
        _db.from('erp_employee_directory').select('id,employee_code,full_name').eq('company_id',company).order('employee_code').limit(3000),
        _db.from('erp_hr_jobs').select('id,job_code,name_ar').eq('company_id',company).order('job_code').limit(1000),
        _db.from('erp_hr_departments').select('id,department_code,name_ar').eq('company_id',company).eq('is_active',true).order('department_code').limit(1000),
        _db.from('erp_branches').select('id,branch_code,branch_name').eq('company_id',company).eq('is_active',true).order('branch_code').limit(500),
      ]);
      if(!mounted)return;
      setState((){
        _rows=(result[0] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        _employees=(result[1] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        _jobs=(result[2] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        _departments=(result[3] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        _branches=(result[4] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        _loading=false;_error=null;
      });
    }catch(e){if(mounted)setState(()=>_loading=false);_error='تعذر تحميل البيانات: '+e.toString();}
  }

  String _value(_Field f,Map<String,dynamic> row){
    final v=row[f.key];if(v==null)return '—';
    if(f.type=='employee')return _employeeName(v);
    if(f.type=='job'){
      final j=_jobs.where((x)=>x['id'].toString()==v.toString());
      return j.isEmpty?v.toString():(j.first['name_ar']??j.first['job_code']).toString();
    }
    if(f.type=='department'){
      final d=_departments.where((x)=>x['id'].toString()==v.toString());
      return d.isEmpty?v.toString():(d.first['name_ar']??d.first['department_code']).toString();
    }
    if(f.type=='branch'){
      final b=_branches.where((x)=>x['id'].toString()==v.toString());
      return b.isEmpty?v.toString():(b.first['branch_name']??b.first['branch_code']).toString();
    }
    if(f.type=='choice')return _label(v);
    if(f.type=='bool')return v==true?'نعم':'لا';
    return v.toString();
  }

  Future<void> _form({Map<String,dynamic>? row}) async {
    final c=_config;final key=GlobalKey<FormState>();
    final ctrls=<String,TextEditingController>{};final selected=<String,String?>{};final bools=<String,bool>{};
    for(final f in c.fields){
      final old=row?[f.key];
      if(f.type=='choice'||f.type=='employee'||f.type=='job'||f.type=='department'||f.type=='branch'){
        selected[f.key]=old?.toString()??(f.options.isNotEmpty?f.options.first:null);
      }else if(f.type=='bool'){bools[f.key]=old==true;}
      else{
        final today=DateTime.now().toIso8601String().substring(0,10);
        final defaultValue=f.type=='number'?'0':f.type=='date'?today:'';
        ctrls[f.key]=TextEditingController(text:old?.toString()??defaultValue);
      }
    }
    final ok=await showDialog<bool>(context:context,builder:(dc)=>StatefulBuilder(builder:(dc,setD)=>AlertDialog(
      title:Text(row==null?'إضافة — '+c.title:'تعديل — '+c.title,textDirection:TextDirection.rtl),
      content:SizedBox(width:560,child:Form(key:key,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:c.fields.map((f){
        if(f.type=='employee'||f.type=='job'||f.type=='choice'||f.type=='department'||f.type=='branch'){
          final items=f.type=='employee'
            ? _employees.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text(e['employee_code'].toString()+' — '+e['full_name'].toString(),overflow:TextOverflow.ellipsis))).toList()
            : f.type=='job'
              ? _jobs.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text((e['name_ar']??e['job_code']).toString(),overflow:TextOverflow.ellipsis))).toList()
              : f.type=='department'
                ? _departments.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text((e['name_ar']??e['department_code']).toString(),overflow:TextOverflow.ellipsis))).toList()
                : f.type=='branch'
                  ? _branches.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text((e['branch_name']??e['branch_code']).toString(),overflow:TextOverflow.ellipsis))).toList()
                  : f.options.map((v)=>DropdownMenuItem<String>(value:v,child:Text(_label(v)))).toList();
          return Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(
            value:selected[f.key],isExpanded:true,decoration:InputDecoration(labelText:f.label,border:const OutlineInputBorder()),
            items:items,onChanged:(v)=>setD(()=>selected[f.key]=v),
            validator:f.required?(v)=>v==null?'هذا الحقل مطلوب':null:null,
          ));
        }
        if(f.type=='bool')return SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(f.label),value:bools[f.key]??false,onChanged:(v)=>setD(()=>bools[f.key]=v));
        return Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(
          controller:ctrls[f.key],keyboardType:f.type=='number'?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
          maxLines:['notes','reason','strengths','improvement_areas','goals'].contains(f.key)?3:1,
          decoration:InputDecoration(labelText:f.label,border:const OutlineInputBorder(),hintText:f.type=='date'?'YYYY-MM-DD':null),
          validator:(v){
            final value=(v??'').trim();
            if(f.required && value.isEmpty)return 'هذا الحقل مطلوب';
            if(value.isEmpty)return null;
            if(f.type=='date' && DateTime.tryParse(value)==null)return 'اكتب التاريخ بصيغة YYYY-MM-DD';
            if(f.type=='number'){
              final number=num.tryParse(value.replaceAll(',','.'));
              if(number==null)return 'أدخل رقمًا صحيحًا';
              if(number<0)return 'لا يمكن إدخال قيمة سالبة';
              if(f.key=='score' && number>100)return 'الدرجة يجب ألا تتجاوز 100';
              if((f.key=='hours'||f.key=='installments'||(f.key=='amount' && c.table=='erp_hr_employee_advances')) && number<=0)return 'يجب أن تكون القيمة أكبر من صفر';
            }
            return null;
          },
        ));
      }).toList())))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dc,false),child:const Text('إلغاء')),
        FilledButton(style:FilledButton.styleFrom(backgroundColor:_purple),onPressed:()async{
          if(!key.currentState!.validate())return;
          final payload=<String,dynamic>{'company_id':widget.companyId};
          if(c.table=='erp_hr_employee_custodies' && row==null){payload['custody_code']='CST'+DateTime.now().microsecondsSinceEpoch.toString();}
          for(final f in c.fields){
            if(f.type=='choice'||f.type=='employee'||f.type=='job'||f.type=='department'||f.type=='branch'){if(selected[f.key]!=null)payload[f.key]=selected[f.key];}
            else if(f.type=='bool'){payload[f.key]=bools[f.key]??false;}
            else{
              final v=ctrls[f.key]!.text.trim();if(v.isEmpty)continue;
              payload[f.key]=f.type=='number'?(num.tryParse(v.replaceAll(',','.'))??0):v;
            }
          }
          if(c.table=='erp_hr_overtime_requests'&&(payload['amount']==null||payload['amount']==0)){
            payload['amount']=(payload['hours'] as num? ?? 0)*(payload['hourly_rate'] as num? ?? 0);
          }
          if(c.table=='erp_hr_employee_advances'&&(payload['installment_amount']==null||payload['installment_amount']==0)){
            final n=payload['installments'] as num? ?? 0;if(n>0)payload['installment_amount']=(payload['amount'] as num? ?? 0)/n;
          }
          try{
            if(row==null){await _db.from(c.table).insert(payload);}
            else{await _db.from(c.table).update(payload).eq('id',row['id']).eq('company_id',widget.companyId!);}
            if(dc.mounted)Navigator.pop(dc,true);
          }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحفظ: '+e.toString())));}
        },child:const Text('حفظ')),
      ],
    )));
    for(final x in ctrls.values){x.dispose();}
    if(ok==true)await _load();
  }

  Future<void> _delete(Map<String,dynamic> row)async{
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('تأكيد الحذف'),content:const Text('هل تريد حذف هذا السجل؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('حذف'))],
    ));
    if(yes!=true)return;
    try{await _db.from(_config.table).delete().eq('id',row['id']).eq('company_id',widget.companyId!);await _load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحذف: '+e.toString())));}
  }

  @override Widget build(BuildContext context){
    final c=_config;
    final readOnly=widget.page.contains('تقرير') || widget.page.contains('مراحل الاختيار') ||
      widget.page.contains('حركة التعيينات') || widget.page.contains('حركة الموظفين') ||
      widget.page.contains('انتهاء وتجديد') || widget.page.contains('أرصدة') ||
      widget.page.contains('معدل دوران') || widget.page.contains('تكلفة العمالة') ||
      widget.page.contains('تقييمات الأداء') || widget.page.contains('ساعات العمل الإضافية');
    final demo=_rows.isEmpty&&c.examples.isNotEmpty;
    final records=demo?c.examples.map((x)=>Map<String,dynamic>.from(x)).toList():_rows;
    final columns=c.fields.take(5).toList();
    return Directionality(textDirection:TextDirection.rtl,child:Container(
      color:const Color(0xFFFAF8FC),padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Card(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:Color(0xFFE8E1EF))),
          child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const CircleAvatar(backgroundColor:Color(0xFFF2EAF8),child:Icon(Icons.badge_outlined,color:_purple)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(c.title,style:const TextStyle(color:_purple,fontSize:20,fontWeight:FontWeight.w900)),
                Text(c.help,style:const TextStyle(color:Colors.black54,fontSize:12)),
              ])),
              if(!readOnly)FilledButton.icon(onPressed:(_employees.isEmpty && c.fields.any((f)=>f.type=='employee'))?null:()=>_form(),icon:const Icon(Icons.add),label:const Text('إضافة سجل'),style:FilledButton.styleFrom(backgroundColor:_purple)),
              if(readOnly)const Chip(label:Text('عرض التقارير فقط')),
              IconButton(onPressed:_load,tooltip:'تحديث',icon:const Icon(Icons.refresh,color:_purple)),
            ]),
            const SizedBox(height:12),
            Wrap(spacing:8,runSpacing:8,children:[
              _metric('السجلات الفعلية',_rows.length.toString()),
              _metric('الموظفون',_employees.length.toString()),
              _metric('المعروض',_loading?'تحميل':demo?'أمثلة توضيحية':'بيانات النظام'),
            ]),
          ]))),
        if(demo)Container(margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:const Color(0xFFFFF6E7),borderRadius:BorderRadius.circular(12),border:Border.all(color:_orange)),
          child:const Row(children:[Icon(Icons.info_outline,color:Color(0xFF9A5A00)),SizedBox(width:8),Expanded(child:Text('لا توجد سجلات فعلية في هذا القسم بعد. المعروض أمثلة توضيحية فقط ولا يتم حفظها في قاعدة البيانات.',style:TextStyle(color:Color(0xFF7A4B0A),fontWeight:FontWeight.w600)))])),
        if(_error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_error!,style:const TextStyle(color:Colors.red))),
        const SizedBox(height:10),
        Expanded(child:_loading?const Center(child:CircularProgressIndicator(color:_purple)):records.isEmpty
          ?const Center(child:Text('لا توجد سجلات بعد. استخدم «إضافة سجل» لبدء العمل.'))
          :Card(elevation:0,color:Colors.white,child:SingleChildScrollView(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
            columns:[...columns.map((f)=>DataColumn(label:Text(f.label,style:const TextStyle(color:_purple,fontWeight:FontWeight.w800)))),const DataColumn(label:Text('الإجراءات',style:TextStyle(color:_purple,fontWeight:FontWeight.w800)))],
            rows:records.map((r)=>DataRow(cells:[
              ...columns.map((f)=>DataCell(ConstrainedBox(constraints:const BoxConstraints(maxWidth:180),child:Text(demo?_label(r[f.key]??'—'):_value(f,r),overflow:TextOverflow.ellipsis)))),
              DataCell(demo||readOnly?const Text('—'):Row(mainAxisSize:MainAxisSize.min,children:[
                IconButton(tooltip:'تعديل',onPressed:()=>_form(row:r),icon:const Icon(Icons.edit_outlined,color:_purple)),
                IconButton(tooltip:'حذف',onPressed:()=>_delete(r),icon:const Icon(Icons.delete_outline,color:Colors.red)),
              ])),
            ])).toList(),
          ))))),
      ]),
    ));
  }

  Widget _metric(String title,String value)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
    decoration:BoxDecoration(color:const Color(0xFFF7F2FA),borderRadius:BorderRadius.circular(10)),
    child:Text(title+': '+value,style:const TextStyle(color:_purple,fontWeight:FontWeight.w700,fontSize:12)),
  );
}
