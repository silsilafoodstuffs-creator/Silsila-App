import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _salaryPurple = Color(0xFF3E007D);
const _salaryOrange = Color(0xFFFFA015);

class ErpSalaryElementsScreen extends StatefulWidget {
  const ErpSalaryElementsScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpSalaryElementsScreen> createState() => _ErpSalaryElementsScreenState();
}

class _ErpSalaryElementsScreenState extends State<ErpSalaryElementsScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = [];
  String _currency = 'EGP';
  bool _loading = false;
  String? _error;
  String? _message;

  String _s(dynamic value) => (value ?? '').toString();
  String _currencyLabel(String code) => const {'EGP':'ج.م','USD':'$','SAR':'ر.س','AED':'د.إ','KWD':'د.ك','EUR':'€','GBP':'£'}[code] ?? code;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final company = (widget.companyId ?? '').trim();
    if (company.isEmpty) { setState(() { _error = 'يجب تحديد الشركة أولًا من بيانات الشركة.'; _rows = []; }); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final results = await Future.wait([
        _db.from('erp_hr_salary_elements').select('*').eq('company_id', company).order('element_code'),
        _db.from('erp_companies').select('base_currency').eq('id', company).maybeSingle(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (results[0] as List).map((e) => Map<String,dynamic>.from(e)).toList();
        _currency = _s((results[1] as Map?)?['base_currency']).isEmpty ? 'EGP' : _s((results[1] as Map)['base_currency']);
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل عناصر المرتبات: $e'; }); }
  }

  Future<void> _edit({Map<String,dynamic>? row}) async {
    final code = TextEditingController(text: _s(row?['element_code']).isEmpty ? 'SAL${(_rows.length + 1).toString().padLeft(3,'0')}' : _s(row?['element_code']));
    final ar = TextEditingController(text: _s(row?['name_ar']));
    final en = TextEditingController(text: _s(row?['name_en']));
    final value = TextEditingController(text: _s(row?['default_value']).isEmpty ? '0.000' : _s(row?['default_value']));
    String type = _s(row?['element_type']).isEmpty ? 'earning' : _s(row?['element_type']);
    String mode = _s(row?['value_mode']).isEmpty ? 'fixed' : _s(row?['value_mode']);
    String nature = _s(row?['nature']).isEmpty ? 'value' : _s(row?['nature']);
    bool show = row?['show_on_payslip'] != false;
    bool active = row?['is_active'] != false;
    String? error;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text(row == null ? 'إضافة عنصر مرتب' : 'تعديل عنصر مرتب'),
      content: SizedBox(width: 720, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 10, runSpacing: 8, children: [
          SizedBox(width: 180, child: TextField(controller: code, decoration: const InputDecoration(labelText: 'كود العنصر *'), textCapitalization: TextCapitalization.characters)),
          SizedBox(width: 230, child: TextField(controller: ar, decoration: const InputDecoration(labelText: 'اسم عنصر عربي *'))),
          SizedBox(width: 230, child: TextField(controller: en, decoration: const InputDecoration(labelText: 'اسم إنجليزي'))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          SizedBox(width: 210, child: DropdownButtonFormField<String>(value:type, decoration:const InputDecoration(labelText:'نوع العنصر'), items:const [DropdownMenuItem(value:'earning',child:Text('استحقاق')),DropdownMenuItem(value:'deduction',child:Text('استقطاع'))], onChanged:(v)=>refresh(()=>type=v??type))),
          SizedBox(width: 210, child: DropdownButtonFormField<String>(value:mode, decoration:const InputDecoration(labelText:'حالة العنصر'), items:const [DropdownMenuItem(value:'fixed',child:Text('ثابت')),DropdownMenuItem(value:'variable',child:Text('متغير'))], onChanged:(v)=>refresh(()=>mode=v??mode))),
          SizedBox(width: 210, child: DropdownButtonFormField<String>(value:nature, decoration:const InputDecoration(labelText:'طبيعة العنصر'), items:const [DropdownMenuItem(value:'value',child:Text('قيمة')),DropdownMenuItem(value:'time',child:Text('وقت')),DropdownMenuItem(value:'days',child:Text('أيام'))], onChanged:(v)=>refresh(()=>nature=v??nature))),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: 240, child: TextField(controller:value, keyboardType:const TextInputType.numberWithOptions(decimal:true), decoration:InputDecoration(labelText:'القيمة (3 أرقام + 3 كسور)', suffixText:nature=='value'?_currencyLabel(_currency):nature=='days'?'يوم':'دقيقة'), onChanged:(v){final parsed=double.tryParse(v);if(parsed!=null&&parsed>999.999)refresh(()=>error='الحد الأقصى للقيمة 999.999');else if(error!=null)refresh(()=>error=null);})),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:show,onChanged:(v)=>refresh(()=>show=v??false),title:const Text('يظهر في شريط القبض'),controlAffinity:ListTileControlAffinity.leading),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>refresh(()=>active=v??false),title:const Text('نشط'),controlAffinity:ListTileControlAffinity.leading),
        if(error!=null) Align(alignment:Alignment.centerRight,child:Text(error!,style:const TextStyle(color:Colors.red))),
      ]))),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:()async{
          final numeric=double.tryParse(value.text.trim());
          if(code.text.trim().isEmpty||!RegExp(r'^[A-Za-z0-9]+$').hasMatch(code.text.trim())||ar.text.trim().isEmpty||numeric==null||numeric<0||numeric>999.999){refresh(()=>error='أدخل كودًا إنجليزيًا/رقميًا واسمًا عربيًا وقيمة صحيحة حتى 999.999.');return;}
          try {
            final payload={'company_id':widget.companyId!.trim(),'element_code':code.text.trim().toUpperCase(),'name_ar':ar.text.trim(),'name_en':en.text.trim(),'element_type':type,'value_mode':mode,'nature':nature,'default_value':numeric.toStringAsFixed(3),'show_on_payslip':show,'is_active':active,'updated_at':DateTime.now().toUtc().toIso8601String()};
            if(row==null) await _db.from('erp_hr_salary_elements').insert(payload);
            else await _db.from('erp_hr_salary_elements').update(payload).eq('id',_s(row['id'])).eq('company_id',widget.companyId!.trim());
            if(ctx.mounted)Navigator.pop(ctx);
            await _load();
            if(mounted)setState(()=>_message='تم حفظ عنصر المرتب.');
          } catch(e){refresh(()=>error='تعذر الحفظ: $e');}
        },child:const Text('حفظ')),
      ],
    )));
    code.dispose(); ar.dispose(); en.dispose(); value.dispose();
  }

  Future<void> _delete(Map<String,dynamic> row) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('تأكيد حذف عنصر المرتب'),content:Text('هل تريد حذف «${_s(row['name_ar'])}»؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('نعم'))]));
    if(yes!=true)return;
    try{await _db.from('erp_hr_salary_elements').delete().eq('id',_s(row['id'])).eq('company_id',widget.companyId!.trim());await _load();}
    catch(e){if(mounted)setState(()=>_error='تعذر الحذف: $e');}
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(color:_salaryPurple,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('عناصر المرتبات',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
      const Text('تعريف عناصر الاستحقاق والاستقطاع وقواعد ظهورها في شريط القبض.',style:TextStyle(color:Colors.white70)),
      const SizedBox(height:8),Wrap(spacing:8,children:[
        FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:_salaryPurple),onPressed:_loading?null:_load,icon:const Icon(Icons.refresh),label:const Text('تحديث')),
        FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_salaryOrange,foregroundColor:_salaryPurple),onPressed:widget.companyId==null?null:()=>_edit(),icon:const Icon(Icons.add),label:const Text('إضافة عنصر')),
      ]),
    ]))),
    if(_loading)const LinearProgressIndicator(),
    if(_error!=null) _notice(_error!,Colors.red),
    if(_message!=null) _notice(_message!,Colors.green),
    Text('العملة الأساسية للشركة: $_currency • ${_rows.length} عنصر',style:const TextStyle(fontWeight:FontWeight.w800)),
    const SizedBox(height:8),
    Expanded(child:_rows.isEmpty&&!_loading?const Center(child:Text('لا توجد عناصر مرتبات مسجلة بعد.')):SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),
      columns:const [DataColumn(label:Text('م')),DataColumn(label:Text('كود العنصر')),DataColumn(label:Text('اسم عنصر عربي')),DataColumn(label:Text('English')),DataColumn(label:Text('النوع')),DataColumn(label:Text('الحالة')),DataColumn(label:Text('الطبيعة')),DataColumn(label:Text('القيمة')),DataColumn(label:Text('في شريط القبض')),DataColumn(label:Text('نشط')),DataColumn(label:Text('إجراءات'))],
      rows:List.generate(_rows.length,(i){final r=_rows[i];final nature=_s(r['nature']);final unit=nature=='value'?_currencyLabel(_currency):nature=='days'?'يوم':'دقيقة';return DataRow(cells:[
        DataCell(Text('${i+1}')),DataCell(Text(_s(r['element_code']))),DataCell(Text(_s(r['name_ar']))),DataCell(Text(_s(r['name_en']))),
        DataCell(Text(_s(r['element_type'])=='earning'?'استحقاق':'استقطاع')),DataCell(Text(_s(r['value_mode'])=='fixed'?'ثابت':'متغير')),
        DataCell(Text(nature=='value'?'قيمة':nature=='days'?'أيام':'وقت')),DataCell(Text('${_s(r['default_value'])} $unit')),
        DataCell(Icon(r['show_on_payslip']==true?Icons.check_circle:Icons.cancel,color:r['show_on_payslip']==true?Colors.green:Colors.grey)),
        DataCell(Icon(r['is_active']==true?Icons.check_circle:Icons.cancel,color:r['is_active']==true?Colors.green:Colors.grey)),
        DataCell(Row(children:[IconButton(tooltip:'تعديل',onPressed:()=>_edit(row:r),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'حذف',onPressed:()=>_delete(r),icon:const Icon(Icons.delete_outline,color:Colors.red))])),
      ]);}),
    )))),
  ]));

  Widget _notice(String text,Color color)=>Container(margin:const EdgeInsets.symmetric(vertical:6),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:color.withValues(alpha:.08),borderRadius:BorderRadius.circular(8)),child:Text(text,style:TextStyle(color:color)));
}

class ErpPayslipReportsScreen extends StatefulWidget {
  const ErpPayslipReportsScreen({super.key,required this.companyId,this.initialTab=0});
  final String? companyId;
  final int initialTab;
  @override
  State<ErpPayslipReportsScreen> createState()=>_ErpPayslipReportsScreenState();
}

class _ErpPayslipReportsScreenState extends State<ErpPayslipReportsScreen> with SingleTickerProviderStateMixin {
  final _db=Supabase.instance.client;
  late final TabController _tabs;
  List<Map<String,dynamic>> _runs=[];
  List<Map<String,dynamic>> _employees=[];
  List<Map<String,dynamic>> _lines=[];
  List<Map<String,dynamic>> _elements=[];
  List<Map<String,dynamic>> _departments=[];
  List<Map<String,dynamic>> _locations=[];
  List<Map<String,dynamic>> _branches=[];
  List<Map<String,dynamic>> _jobs=[];
  String? _runId;
  String? _employeeId;
  String? _branchId;
  String? _departmentId;
  String? _locationId;
  String? _jobId;
  String _activeFilter='الكل';
  bool _loading=false;
  String? _error;
  String _currency='EGP';
  String _s(dynamic v)=>(v??'').toString();
  double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(_s(v))??0;
  String _fmt(dynamic v)=>_n(v).toStringAsFixed(3);
  String _unit(String nature)=>nature=='days'?' يوم':nature=='time'?' دقيقة':' ${_currencySymbol()}';
  String _elementValue(Map<String,dynamic> element,dynamic value)=>'${_fmt(value)}${_unit(_s(element['nature']))}';
  String _currencySymbol()=>const {'EGP':'ج.م','USD':'$','SAR':'ر.س','AED':'د.إ','KWD':'د.ك','EUR':'€','GBP':'£'}[_currency]??_currency;

  @override
  void initState(){super.initState();_tabs=TabController(length:2,vsync:this,initialIndex:widget.initialTab.clamp(0,1).toInt());_load();}
  @override
  void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load()async{
    final c=(widget.companyId??'').trim();
    if(c.isEmpty){setState(()=>_error='لا توجد شركة محددة. افتح بيانات الشركة أولًا.');return;}
    setState(()=>_loading=true);
    try{
      final r=await Future.wait([
        _db.from('erp_payroll_runs').select('*').eq('company_id',c).inFilter('status',['approved','posted']).order('period_start',ascending:false).limit(120),
        _db.from('erp_employees').select('id,employee_code,full_name,full_name_en,base_salary,branch_id,department_id,administration_id,work_location_id,job_id,job_title,department_name,is_active,employment_status,work_unit').eq('company_id',c).order('employee_code'),
        _db.from('erp_hr_salary_elements').select('*').eq('company_id',c).eq('show_on_payslip',true).order('element_type').order('element_code'),
        _db.from('erp_hr_departments').select('id,department_code,name_ar,department_level,parent_id').eq('company_id',c).eq('is_active',true).order('department_code'),
        _db.from('erp_hr_work_locations').select('id,location_code,name_ar').eq('company_id',c).eq('is_active',true).order('location_code'),
        _db.from('erp_branches').select('id,branch_code,branch_name').eq('company_id',c).eq('is_active',true).order('branch_code'),
        _db.from('erp_hr_jobs').select('id,job_code,name_ar').eq('company_id',c).eq('is_active',true).order('job_code'),
        _db.from('erp_companies').select('base_currency').eq('id',c).maybeSingle(),
      ]);
      if(!mounted)return;
      setState((){
        _runs=(r[0] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _employees=(r[1] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _elements=(r[2] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _departments=(r[3] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _locations=(r[4] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _branches=(r[5] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _jobs=(r[6] as List).map((x)=>Map<String,dynamic>.from(x)).toList();
        _currency=_s((r[7] as Map?)?['base_currency']).isEmpty?'EGP':_s((r[7] as Map)['base_currency']);
        if(!_runs.any((x)=>_s(x['id'])==_runId))_runId=_runs.isEmpty?null:_s(_runs.first['id']);
        if(!_employees.any((x)=>_s(x['id'])==_employeeId))_employeeId=_employees.isEmpty?null:_s(_employees.first['id']);
        _loading=false;_error=null;
      });
      await _loadLines();
    }catch(e){if(mounted)setState(()=>_loading=false);if(mounted)setState(()=>_error='تعذر تحميل بيانات أشرطة القبض: $e');}
  }

  Future<void> _loadLines()async{
    if(_runId==null){if(mounted)setState(()=>_lines=[]);return;}
    try{final rows=await _db.from('erp_payroll_lines').select('*').eq('payroll_run_id',_runId!).eq('company_id',widget.companyId!.trim());if(mounted)setState(()=>_lines=rows.map((x)=>Map<String,dynamic>.from(x)).toList());}
    catch(e){if(mounted)setState(()=>_error='تعذر تحميل تفاصيل مسير القبض: $e');}
  }

  Map<String,dynamic>? _employee(String id){final a=_employees.where((e)=>_s(e['id'])==id);return a.isEmpty?null:a.first;}
  Map<String,dynamic>? _lineFor(String id){final a=_lines.where((e)=>_s(e['employee_id'])==id);return a.isEmpty?null:a.first;}
  String _label(List<Map<String,dynamic>> rows,String id,String code,String name){final a=rows.where((x)=>_s(x['id'])==id);return a.isEmpty?'—':'${_s(a.first[code])} • ${_s(a.first[name])}';}
  bool _departmentMatches(Map<String,dynamic> employee) {
    if (_departmentId == null) return true;
    var current = _s(employee['department_id']);
    final seen = <String>{};
    while (current.isNotEmpty && seen.add(current)) {
      if (current == _departmentId) return true;
      final node = _departments.where((d) => _s(d['id']) == current);
      current = node.isEmpty ? '' : _s(node.first['parent_id']);
    }
    return _s(employee['administration_id']) == _departmentId;
  }

  List<Map<String,dynamic>> get _filteredEmployees=>_employees.where((e){
    if(_activeFilter=='نشط'&&e['is_active']!=true)return false;
    if(_activeFilter=='غير نشط'&&e['is_active']==true)return false;
    if(_branchId!=null&&_s(e['branch_id'])!=_branchId)return false;
    if(!_departmentMatches(e))return false;
    if(_locationId!=null&&_s(e['work_location_id'])!=_locationId)return false;
    if(_jobId!=null&&_s(e['job_id'])!=_jobId)return false;
    return _lineFor(_s(e['id']))!=null;
  }).toList();

  @override
  Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(color:_salaryPurple,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('تقارير شريط القبض',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
      const Text('شريط قبض فردي لكل موظف أو كشف مجمع حسب الهيكل التنظيمي.',style:TextStyle(color:Colors.white70)),
      const SizedBox(height:8),Row(children:[Expanded(child:Text('العملة: $_currency',style:const TextStyle(color:Colors.white))),IconButton(onPressed:_loading?null:_load,tooltip:'تحديث',icon:const Icon(Icons.refresh,color:Colors.white))]),
    ]))),
    TabBar(controller:_tabs,labelColor:_salaryPurple,indicatorColor:_salaryOrange,tabs:const [Tab(text:'شريط قبض موظف'),Tab(text:'شريط قبض مجمع')]),
    if(_loading)const LinearProgressIndicator(),
    if(_error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_error!,style:const TextStyle(color:Colors.red))),
    Expanded(child:TabBarView(controller:_tabs,children:[_individual(),_aggregate()])),
  ]));

  Widget _runDropdown()=>DropdownButtonFormField<String>(value:_runId,isExpanded:true,decoration:const InputDecoration(labelText:'مسير الرواتب المعتمد',border:OutlineInputBorder()),items:_runs.map((r)=>DropdownMenuItem(value:_s(r['id']),child:Text('${_s(r['run_code'])} • ${_s(r['period_start'])} إلى ${_s(r['period_end'])}'))).toList(),onChanged:(v)async{setState(()=>_runId=v);await _loadLines();});
  Widget _individual()=>ListView(padding:const EdgeInsets.all(10),children:[
    _runDropdown(),const SizedBox(height:8),
    DropdownButtonFormField<String>(value:_employeeId,isExpanded:true,decoration:const InputDecoration(labelText:'الموظف',border:OutlineInputBorder()),items:_employees.map((e)=>DropdownMenuItem(value:_s(e['id']),child:Text('${_s(e['employee_code'])} • ${_s(e['full_name'])}'))).toList(),onChanged:(v)=>setState(()=>_employeeId=v)),
    const SizedBox(height:10),
    if(_employeeId!=null&&_lineFor(_employeeId!)!=null)_payslip(_employee(_employeeId!)!,_lineFor(_employeeId!)!)
    else const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('لا يوجد للموظف شريط قبض في المسير المحدد.'))),
  ]);

  Widget _payslip(Map<String,dynamic> e,Map<String,dynamic> line){
    final values=(line['element_values'] is Map)?Map<String,dynamic>.from(line['element_values'] as Map):<String,dynamic>{};
    final earning=_elements.where((x)=>_s(x['element_type'])=='earning'&&_n(values[_s(x['id'])])!=0).toList();
    final deductions=_elements.where((x)=>_s(x['element_type'])=='deduction'&&_n(values[_s(x['id'])])!=0).toList();
    final base=_n(line['basic_amount']),allow=_n(line['allowances']),comm=_n(line['commissions']),ot=_n(line['overtime_amount']);
    final customDedTotal=deductions.fold<double>(0,(sum,x)=>sum+_n(values[_s(x['id'])]));
    final ded=(_n(line['deductions'])-customDedTotal).clamp(0,double.infinity).toDouble();
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Center(child:Text('سلسلة • شريط قبض موظف',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:_salaryPurple))),
      const Divider(),
      Wrap(spacing:18,runSpacing:8,children:[
        Text('الموظف: ${_s(e['full_name'])}',style:const TextStyle(fontWeight:FontWeight.w800)),
        Text('الكود: ${_s(e['employee_code'])}'),
        Text('القسم: ${_label(_departments,_s(e['department_id']),'department_code','name_ar')}'),
        Text('الوظيفة: ${_label(_jobs,_s(e['job_id']),'job_code','name_ar')}'),
        Text('الموقع: ${_label(_locations,_s(e['work_location_id']),'location_code','name_ar')}'),
        Text('الفترة: ${_selectedRunPeriod()}'),
      ]),
      const SizedBox(height:12),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:_slipSide('الاستحقاقات',Colors.green,[
          ('الراتب الأساسي',_fmt(base)),('بدلات',_fmt(allow)),('عمولات',_fmt(comm)),('إضافي',_fmt(ot)),
          ...earning.map((x)=>(_s(x['name_ar']),_elementValue(x,values[_s(x['id'])]))),
        ])),
        const SizedBox(width:10),
        Expanded(child:_slipSide('الاستقطاعات',Colors.red,[
          ('استقطاعات أساسية',_fmt(ded)),
          ...deductions.map((x)=>(_s(x['name_ar']),_elementValue(x,values[_s(x['id'])]))),
        ])),
      ]),
      const SizedBox(height:12),
      Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF5EFFB),borderRadius:BorderRadius.circular(9)),child:Column(children:[
        Text('صافي المستحق: ${_fmt(line['net_amount'])} ${_currencySymbol()}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:_salaryPurple)),
        const SizedBox(height:4),Text('فقط ${_spell(_n(line['net_amount']))} لا غير',style:const TextStyle(fontWeight:FontWeight.w700)),
      ])),
      const SizedBox(height:22),const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('توقيع الموظف: ........................'),Text('اعتماد الحسابات: ........................')]),
    ])));
  }

  Widget _slipSide(String title,Color color,List<(String,String)> items)=>Container(decoration:BoxDecoration(border:Border.all(color:color.withValues(alpha:.35)),borderRadius:BorderRadius.circular(8)),child:Column(children:[
    Container(width:double.infinity,padding:const EdgeInsets.all(8),color:color.withValues(alpha:.10),child:Text(title,textAlign:TextAlign.center,style:TextStyle(color:color,fontWeight:FontWeight.w900))),
    ...items.map((x)=>Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),child:Row(children:[Expanded(child:Text(x.$1)),Text(x.$2,style:const TextStyle(fontWeight:FontWeight.w800))]))),
  ]));

  String _selectedRunPeriod(){final r=_runs.where((x)=>_s(x['id'])==_runId);return r.isEmpty?'—':'${_s(r.first['period_start'])} إلى ${_s(r.first['period_end'])}';}
  String _spell(double value){final whole=value.floor();final frac=((value-whole)*100).round();if(whole==0&&frac==0)return 'صفر';return '${_arabicInteger(whole)} جنيه${frac>0?' و${_arabicInteger(frac)} قرش':''}';}
  String _arabicInteger(int n){if(n==0)return 'صفر';const ones=['','واحد','اثنان','ثلاثة','أربعة','خمسة','ستة','سبعة','ثمانية','تسعة'];if(n<10)return ones[n];if(n<20)return n==10?'عشرة':'${ones[n-10]} عشر';if(n<100)return '${ones[n%10]} و${['','عشرة','عشرون','ثلاثون','أربعون','خمسون','ستون','سبعون','ثمانون','تسعون'][n~/10]}';if(n<1000)return '${ones[n~/100]} مائة و${_arabicInteger(n%100)}';return n.toString();}

  Widget _aggregate(){
    final employees=_filteredEmployees;
    final earning=_elements.where((x)=>_s(x['element_type'])=='earning').toList();
    final deduction=_elements.where((x)=>_s(x['element_type'])=='deduction').toList();
    return Column(children:[
      _runDropdown(),
      Padding(padding:const EdgeInsets.all(8),child:Wrap(spacing:8,runSpacing:8,children:[
        _filterDropdown('الفرع',_branchId,_branches,'branch_name',(v)=>setState(()=>_branchId=v)),
        _filterDropdown('الإدارة / القسم',_departmentId,_departments,'name_ar',(v)=>setState(()=>_departmentId=v)),
        _filterDropdown('الموقع',_locationId,_locations,'name_ar',(v)=>setState(()=>_locationId=v)),
        _filterDropdown('الوظيفة',_jobId,_jobs,'name_ar',(v)=>setState(()=>_jobId=v)),
        DropdownButton<String>(value:_activeFilter,items:const [DropdownMenuItem(value:'الكل',child:Text('الكل')),DropdownMenuItem(value:'نشط',child:Text('نشط')),DropdownMenuItem(value:'غير نشط',child:Text('غير نشط'))],onChanged:(v)=>setState(()=>_activeFilter=v??'الكل')),
        OutlinedButton.icon(onPressed:()=>setState((){_branchId=null;_departmentId=null;_locationId=null;_jobId=null;_activeFilter='الكل';}),icon:const Icon(Icons.filter_alt_off),label:const Text('مسح الفلاتر')),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Align(alignment:Alignment.centerRight,child:Text('عدد الموظفين: ${employees.length} • ${_selectedRunPeriod()}',style:const TextStyle(fontWeight:FontWeight.w800)))),
      Expanded(child:employees.isEmpty?const Center(child:Text('لا توجد بيانات رواتب تطابق محددات التقرير.')):SingleChildScrollView(scrollDirection:Axis.horizontal,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Row(children:[
          const Text('بيانات الموظف',style:TextStyle(fontWeight:FontWeight.w900,color:_salaryPurple)),
          const SizedBox(width:22),
          Text('الاستحقاقات • ${4+earning.length} عمود',style:const TextStyle(fontWeight:FontWeight.w900,color:Colors.green)),
          const SizedBox(width:22),
          Text('الاستقطاعات • ${1+deduction.length} عمود',style:const TextStyle(fontWeight:FontWeight.w900,color:Colors.red)),
          const SizedBox(width:22),const Text('الصافي والتوقيع',style:TextStyle(fontWeight:FontWeight.w900,color:_salaryPurple)),
        ])),
        SingleChildScrollView(child:DataTable(
        headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),
        columns:[
          const DataColumn(label:Text('م')),const DataColumn(label:Text('كود الموظف')),const DataColumn(label:Text('اسم الموظف')),
          const DataColumn(label:Text('الراتب الأساسي')),const DataColumn(label:Text('بدلات')),const DataColumn(label:Text('عمولات')),const DataColumn(label:Text('إضافي')),
          ...earning.map((x)=>DataColumn(label:Text('${_s(x['name_ar'])} (${_unit(_s(x['nature']))})'))),
          const DataColumn(label:Text('استقطاعات أساسية')),...deduction.map((x)=>DataColumn(label:Text('${_s(x['name_ar'])} (${_unit(_s(x['nature']))})'))),
          const DataColumn(label:Text('الصافي')),const DataColumn(label:Text('التوقيع')),
        ],
        rows:List.generate(employees.length,(i){
          final e=employees[i],line=_lineFor(_s(e['id']))!,values=(line['element_values'] is Map)?Map<String,dynamic>.from(line['element_values'] as Map):<String,dynamic>{};
          final base=_n(line['basic_amount']),allow=_n(line['allowances']),comm=_n(line['commissions']),ot=_n(line['overtime_amount']);
          final earnings=earning.map((x)=>_n(values[_s(x['id'])])).toList();
          final deductions=deduction.map((x)=>_n(values[_s(x['id'])])).toList();
          final ded=(_n(line['deductions'])-deductions.fold<double>(0,(sum,x)=>sum+x)).clamp(0,double.infinity).toDouble();
          final cells=<DataCell>[DataCell(Text('${i+1}')),DataCell(Text(_s(e['employee_code']))),DataCell(Text(_s(e['full_name']))),DataCell(Text(_fmt(base))),DataCell(Text(_fmt(allow))),DataCell(Text(_fmt(comm))),DataCell(Text(_fmt(ot)))];
          cells.addAll(earning.asMap().entries.map((x)=>DataCell(Text(_elementValue(x.value,earnings[x.key])))));
          cells.add(DataCell(Text(_fmt(ded))));
          cells.addAll(deduction.asMap().entries.map((x)=>DataCell(Text(_elementValue(x.value,deductions[x.key])))));
          cells.add(DataCell(Text(_fmt(line['net_amount']),style:const TextStyle(fontWeight:FontWeight.w900,color:_salaryPurple))));
          cells.add(const DataCell(Text('................')));
          return DataRow(cells:cells);
        }),
      ))),
      ]))),
    ]);
  }

  Widget _filterDropdown(String label,String? value,List<Map<String,dynamic>> rows,String name,ValueChanged<String?> change)=>SizedBox(width:190,child:DropdownButtonFormField<String>(value:value,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),items:rows.map((r)=>DropdownMenuItem(value:_s(r['id']),child:Text(_s(r[name]),overflow:TextOverflow.ellipsis))).toList(),onChanged:change));
}
