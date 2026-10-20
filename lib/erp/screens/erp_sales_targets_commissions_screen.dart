import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _p = Color(0xFF3E007D);
const _o = Color(0xFFFFA015);
const _pink = Color(0xFFFF27C3);

class ErpSalesTargetsCommissionsScreen extends StatefulWidget {
  const ErpSalesTargetsCommissionsScreen({super.key, this.companyId, this.initialTabIndex = 0});
  final String? companyId;
  final int initialTabIndex;
  @override
  State<ErpSalesTargetsCommissionsScreen> createState() => _ErpSalesTargetsCommissionsScreenState();
}

class _ErpSalesTargetsCommissionsScreenState extends State<ErpSalesTargetsCommissionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  SupabaseClient? _db;
  bool _loading = true;
  String? _error;
  final List<Map<String,dynamic>> _customers = [], _reps = [], _goals = [], _plans = [], _tiers = [], _salesDocs = [], _runs = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, initialIndex: widget.initialTabIndex.clamp(0, 3).toInt(), vsync: this);
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }
  @override
  void didUpdateWidget(covariant ErpSalesTargetsCommissionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabs.index = widget.initialTabIndex.clamp(0, 3).toInt();
    }
    if (oldWidget.companyId != widget.companyId) _load();
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (_db == null || (widget.companyId ?? '').isEmpty) { if (mounted) setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final c = widget.companyId!;
      final r = await Future.wait([
        _db!.from('erp_parties').select('id,party_code,party_name,business_classification,district,governorate,is_demo_data').eq('company_id',c).eq('party_kind','customer').order('party_name'),
        _db!.from('erp_sales_representatives').select().eq('company_id',c).order('rep_name'),
        _db!.from('erp_customer_monthly_goals').select().eq('company_id',c).order('goal_month',ascending:false),
        _db!.from('erp_commission_plans').select().eq('company_id',c).order('plan_name'),
      ]);
      if (!mounted) return;
      setState(() {
        _customers..clear()..addAll((r[0] as List).cast<Map<String,dynamic>>());
        _reps..clear()..addAll((r[1] as List).cast<Map<String,dynamic>>());
        _goals..clear()..addAll((r[2] as List).cast<Map<String,dynamic>>());
        _plans..clear()..addAll((r[3] as List).cast<Map<String,dynamic>>());
        _loading = false;
      });
      final ids = _plans.map((x)=>x['id']?.toString()).whereType<String>().toList();
      if (ids.isNotEmpty) {
        final rows = await _db!.from('erp_commission_tiers').select().inFilter('plan_id',ids).order('min_value');
        if (mounted) setState(() { _tiers..clear()..addAll((rows as List).cast<Map<String,dynamic>>()); });
      }
      try {
        final from=_month.toIso8601String().substring(0,10);
        final to=_nextMonth.toIso8601String().substring(0,10);
        final docs=await _db!.from('erp_sales_documents')
            .select('id,customer_id,sales_rep_id,document_type,status,document_date,grand_total,paid_total,is_demo_data')
            .eq('company_id',c).eq('status','posted').eq('is_demo_data',false)
            .gte('document_date',from).lt('document_date',to);
        if(mounted) setState(() {
          _salesDocs..clear()..addAll((docs as List).cast<Map<String,dynamic>>());
        });
      } catch (_) {
        if(mounted) setState(()=>_salesDocs.clear());
      }
      try {
        final runs=await _db!.from('erp_commission_runs').select()
            .eq('company_id',c).order('created_at',ascending:false);
        if(mounted) setState(()=>_runs..clear()..addAll((runs as List).cast<Map<String,dynamic>>()));
      } catch (_) {
        if(mounted) setState(()=>_runs.clear());
      }
    } catch(e) { if(mounted) setState(() { _error='تعذر تحميل البيانات. تحقق من ملف SQL وصلاحيات الشركة.\n'+e.toString(); _loading=false; }); }
  }

  DateTime get _month => DateTime(DateTime.now().year,DateTime.now().month);
  DateTime get _nextMonth => DateTime(_month.year,_month.month+1);
  double _num(Object? value) => double.tryParse(value?.toString() ?? '') ?? 0;
  double _netDocumentValue(Map<String,dynamic> row) {
    final value=_num(row['grand_total']);
    return row['document_type']?.toString()=='return' ? -value : value;
  }
  double _actualSalesForCustomer(String id) => _salesDocs
      .where((d)=>d['customer_id']?.toString()==id)
      .fold<double>(0,(sum,d)=>sum+_netDocumentValue(d));
  List<Map<String,dynamic>> _docsForRep(String id) => _salesDocs
      .where((d)=>d['sales_rep_id']?.toString()==id)
      .toList();
  double _actualSalesForRep(String id) => _docsForRep(id)
      .fold<double>(0,(sum,d)=>sum+_netDocumentValue(d));
  double _commissionEstimate(Map<String,dynamic> rep) {
    final method=rep['commission_plan']?.toString() ?? 'percentage';
    final sales=_actualSalesForRep(rep['id']?.toString() ?? '');
    final docs=_docsForRep(rep['id']?.toString() ?? '');
    final rate=_num(rep['default_commission_rate']);
    if(method=='fixed_per_invoice') {
      return docs.where((d)=>d['document_type']?.toString()!='return').length*rate;
    }
    if(method=='percentage') return sales>0 ? sales*rate/100 : 0;
    final tierPlan=_plans.where((p)=>p['commission_method']=='tiered').toList();
    if(tierPlan.isEmpty || sales<=0) return 0;
    final planId=tierPlan.first['id']?.toString();
    final tiers=_tiers.where((t)=>t['plan_id']?.toString()==planId).toList()
      ..sort((a,b)=>_num(a['min_value']).compareTo(_num(b['min_value'])));
    var total=0.0;
    for(final tier in tiers) {
      final lower=_num(tier['min_value']);
      final rawUpper=tier['max_value'];
      final upper=rawUpper==null ? sales : _num(rawUpper)+0.01;
      final slab=(sales<upper?sales:upper)-lower;
      if(slab>0) total+=slab*_num(tier['rate'])/100;
    }
    return total;
  }
  String get _monthKey => _month.toIso8601String().substring(0,7);
  String money(Object? v) => ((double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2))+' ج.م';
  Map<String,dynamic>? _goal(String id) {
    for(final g in _goals) { if(g['customer_id']?.toString()==id && g['goal_month']?.toString().startsWith(_monthKey)==true) return g; }
    return null;
  }

  Future<void> _editGoal(Map<String,dynamic> customer) async {
    final old=_goal(customer['id'].toString());
    final sales=TextEditingController(text:old?['sales_target']?.toString() ?? '25000');
    final collection=TextEditingController(text:old?['collection_target']?.toString() ?? '20000');
    final orders=TextEditingController(text:old?['target_orders']?.toString() ?? '12');
    final bonus=TextEditingController(text:old?['bonus_rate']?.toString() ?? '0.5');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      title:Text('هدف شهري: '+(customer['party_name']?.toString() ?? 'عميل')),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        _field(sales,'مستهدف المبيعات (ج.م)'),_field(collection,'مستهدف التحصيل (ج.م)'),_field(orders,'عدد الفواتير',integer:true),_field(bonus,'حافز تحقيق الهدف (%)'),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ الهدف'))],
    )));
    if(ok!=true)return;
    if(_db==null || (widget.companyId ?? '').isEmpty){_toast('بيانات العرض فقط؛ اختر الشركة لتمكين الحفظ.');return;}
    try {
      await _db!.from('erp_customer_monthly_goals').upsert({
        'company_id':widget.companyId,'customer_id':customer['id'],'goal_month':_month.toIso8601String().substring(0,10),
        'sales_target':double.parse(sales.text),'collection_target':double.parse(collection.text),'target_orders':int.parse(orders.text),
        'bonus_rate':double.parse(bonus.text),'is_demo_data':false,
      },onConflict:'company_id,customer_id,goal_month');
      await _load(); _toast('تم حفظ الهدف الشهري.');
    } catch(e){_toast('تعذر الحفظ: '+e.toString());}
  }

  Future<void> _editRep(Map<String,dynamic> rep) async {
    final sales=TextEditingController(text:rep['monthly_sales_target']?.toString() ?? '0');
    final collection=TextEditingController(text:rep['monthly_collection_target']?.toString() ?? '0');
    final rate=TextEditingController(text:rep['default_commission_rate']?.toString() ?? '1.25');
    String method=rep['commission_plan']?.toString() ?? 'percentage';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      title:Text('أهداف وعمولة '+(rep['rep_name']?.toString() ?? 'المندوب')),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        _field(sales,'مستهدف المبيعات الشهري'),_field(collection,'مستهدف التحصيل الشهري'),
        DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'طريقة العمولة'),items:const [
          DropdownMenuItem(value:'percentage',child:Text('نسبة من المبيعات')),
          DropdownMenuItem(value:'fixed_per_invoice',child:Text('قيمة لكل فاتورة')),
          DropdownMenuItem(value:'tiered',child:Text('نسب متدرجة')),
        ],onChanged:(v)=>setLocal(()=>method=v ?? 'percentage')),
        _field(rate,method=='fixed_per_invoice'?'قيمة العمولة لكل فاتورة':'نسبة العمولة (%)'),
        const Text('تتطلب العمولة مراجعة واعتمادًا قبل الصرف.',style:TextStyle(fontSize:12,color:Colors.black54)),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
    ))));
    if(ok!=true)return;
    if(_db==null || (widget.companyId ?? '').isEmpty){_toast('بيانات العرض فقط.');return;}
    try{
      await _db!.from('erp_sales_representatives').update({'monthly_sales_target':double.parse(sales.text),'monthly_collection_target':double.parse(collection.text),'commission_plan':method,'default_commission_rate':double.parse(rate.text),'is_demo_data':false}).eq('id',rep['id']).eq('company_id',widget.companyId!);
      await _load();_toast('تم حفظ إعدادات المندوب.');
    }catch(e){_toast('تعذر الحفظ: '+e.toString());}
  }

  Future<void> _createCommissionRun(Map<String,dynamic> rep) async {
    if(_db==null || (widget.companyId??'').isEmpty) {
      _toast('اربط الشركة بقاعدة البيانات لتسجيل مسودة العمولة.');
      return;
    }
    final repId=rep['id']?.toString() ?? '';
    final docs=_docsForRep(repId);
    if(docs.isEmpty) {
      _toast('لا توجد فواتير مبيعات مرحلة وغير تجريبية لهذا المندوب خلال الشهر الحالي.');
      return;
    }
    final method=rep['commission_plan']?.toString() ?? 'percentage';
    final basis=method=='fixed_per_invoice'?'invoice_count':'sales_value';
    Map<String,dynamic>? plan;
    for(final candidate in _plans) {
      if(candidate['commission_method']==method && candidate['calculation_basis']==basis) {
        plan=candidate; break;
      }
    }
    if(plan==null) {
      _toast('لا توجد خطة عمولة فعالة مطابقة للطريقة المحددة لهذا المندوب.');
      return;
    }
    final selectedPlanId=plan['id'];
    final sales=_actualSalesForRep(repId);
    final collections=docs.fold<double>(0,(sum,d)=>sum+(d['document_type']?.toString()=='return'?-_num(d['paid_total']):_num(d['paid_total'])));
    final count=docs.where((d)=>d['document_type']?.toString()!='return').length;
    final estimate=_commissionEstimate(rep);
    final from=_month.toIso8601String().substring(0,10);
    final to=_nextMonth.subtract(const Duration(days:1)).toIso8601String().substring(0,10);
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(
      textDirection:TextDirection.rtl,
      child:AlertDialog(
        title:const Text('إنشاء مسودة عمولة'),
        content:Text('المندوب: '+(rep['rep_name']??'').toString()+
          '\nالفترة: '+from+' إلى '+to+
          '\nالمبيعات الصافية المرحلة: '+money(sales)+
          '\nالتحصيل المسجل على الفواتير: '+money(collections)+
          '\nالفواتير: '+count.toString()+
          '\nالعمولة التقديرية: '+money(estimate)+
          '\n\nسيتم حفظها كمسودة غير معتمدة للمراجعة قبل الصرف.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إنشاء المسودة')),
        ],
      ),
    ));
    if(confirmed!=true)return;
    try {
      final existing=await _db!.from('erp_commission_runs').select('id')
        .eq('company_id',widget.companyId!).eq('representative_id',repId)
        .eq('period_start',from).eq('period_end',to)
        .neq('status','cancelled').limit(1);
      if((existing as List).isNotEmpty) {
        _toast('توجد بالفعل مسودة أو عمولة مسجلة لهذا المندوب والفترة؛ راجع سجل العمولات.');
        return;
      }
      await _db!.from('erp_commission_runs').insert({
        'company_id':widget.companyId,
        'representative_id':repId,
        'plan_id':selectedPlanId,
        'period_start':from,
        'period_end':to,
        'eligible_sales':sales,
        'eligible_collections':collections,
        'eligible_gross_profit':0,
        'eligible_invoice_count':count,
        'calculated_commission':estimate,
        'status':'draft',
        'is_demo_data':false,
        'notes':'مسودة آلية من الفواتير المرحلة وغير التجريبية؛ يلزم تدقيق المرتجعات والتحصيلات ومراجعة الخطة قبل الاعتماد.',
      });
      await _load();
      _toast('تم حفظ مسودة العمولة بنجاح، ولم يتم اعتمادها أو صرفها.');
    } catch(e) {
      _toast('تعذر حفظ المسودة. تحقق من صلاحيات المحاسبة وملف SQL.\n'+e.toString());
    }
  }

  Widget _field(TextEditingController c,String label,{bool integer=false})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,keyboardType:integer?TextInputType.number:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))));
  void _toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  Widget _stat(String title,String value,IconData icon,Color color)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFFE9E2F0))),child:Row(children:[Icon(icon,color:color,size:28),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.black54,fontSize:13)),Text(value,style:TextStyle(color:color,fontSize:22,fontWeight:FontWeight.w900))]))]));

Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

Future<void> _previewSalesTargets() async {
  await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('معاينة الأهداف والعمولات'),
    content: SizedBox(width: 680, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('العملاء: ${_customers.length}'),
      Text('المندوبون: ${_reps.length}'),
      Text('أهداف مسجلة: ${_goals.length}'),
      Text('خطط عمولة: ${_plans.length}'),
      Text('مسودات عمولات: ${_runs.length}'),
      const SizedBox(height: 8),
      const Text('استخدم التبويبات لمراجعة التفاصيل وتعديل الأهداف أو إعدادات العمولة.'),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
  ));
}

  @override
  Widget build(BuildContext context){
    final demo=_db==null || (widget.companyId ?? '').isEmpty;
    return Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_p,Color(0xFF7443A6)]),borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Row(children:[
          Icon(Icons.track_changes_rounded,color:_o,size:30),const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('أهداف العملاء وعمولات المبيعات',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
            SizedBox(height:5),Text('أهداف شهرية • نسب ثابتة ومتدرجة • اعتماد قبل الصرف',style:TextStyle(color:Color(0xFFEFE5F8),fontSize:12)),
          ])),
        ]),
        const SizedBox(height:8),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          _quickTask('تحديث',Icons.refresh,Colors.blue,_loading?null:_load),
          _quickTask('معاينة المؤشرات',Icons.visibility_outlined,const Color(0xFF6841A5),_previewSalesTargets),
        ])),
      ])),
      const SizedBox(height:12),
      if(demo) Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(12)),child:const Text('وضع تجريبي: الأسماء والأهداف والعمولات افتراضية وليست بيانات حقيقية. طبّق ملف SQL واربط الشركة لتمكين الحفظ.',style:TextStyle(color:Color(0xFF795000),fontWeight:FontWeight.w700))),
      if(_error!=null) Padding(padding:const EdgeInsets.all(8),child:Text(_error!,style:const TextStyle(color:Colors.red))),
      const SizedBox(height:12),
      LayoutBuilder(builder:(ctx,c){final n=c.maxWidth>1000?3:c.maxWidth>620?2:1;return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:n,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:n==1?4:2.4,children:[
        _stat('عملاء الدليل',demo?'4':_customers.length.toString(),Icons.storefront,_p),
        _stat('المندوبون',demo?'3':_reps.length.toString(),Icons.badge,_o),
        _stat('أهداف الشهر',demo?'4':_goals.where((g)=>g['goal_month']?.toString().startsWith(_monthKey)==true).length.toString(),Icons.flag,_pink),
      ]);}),
      const SizedBox(height:12),
      Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:TabBar(isScrollable:true,controller:_tabs,labelColor:_p,unselectedLabelColor:Colors.black54,indicatorColor:_o,tabs:const[
        Tab(icon:Icon(Icons.flag),text:'أهداف العملاء'),Tab(icon:Icon(Icons.badge),text:'المندوبون والعمولات'),Tab(icon:Icon(Icons.stacked_bar_chart),text:'خطط العمولة'),Tab(icon:Icon(Icons.fact_check),text:'مسودات العمولات'),
      ])),
      const SizedBox(height:10),
      if(_loading)const Padding(padding:EdgeInsets.all(28),child:Center(child:CircularProgressIndicator()))
      else SizedBox(height:590,child:TabBarView(controller:_tabs,children:[_customersView(demo),_repsView(demo),_plansView(demo),_runsView(demo)])),
    ]));
  }

  Widget _customersView(bool demo){
    final rows=demo?<Map<String,dynamic>>[
      {'id':'d1','party_name':'ماركت النور - تجريبي','business_classification':'سوبر ماركت','district':'مدينة نصر','sales_target':45000,'collection_target':40000,'target_orders':24},
      {'id':'d2','party_name':'بقالة البركة - تجريبي','business_classification':'كشك / بقالة','district':'المرج','sales_target':18000,'collection_target':16000,'target_orders':18},
      {'id':'d3','party_name':'تاجر جملة المستقبل - تجريبي','business_classification':'جملة','district':'العتبة','sales_target':125000,'collection_target':100000,'target_orders':12},
      {'id':'d4','party_name':'مؤسسة توريدات غذائية - تجريبي','business_classification':'مدارس / مؤسسات','district':'الدقي','sales_target':70000,'collection_target':60000,'target_orders':8},
    ]:_customers;
    if(rows.isEmpty)return const Center(child:Text('لا يوجد عملاء. أضفهم من دليل العملاء أولًا.'));
    return ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(ctx,i){
      final c=rows[i];final g=demo?c:(_goal(c['id'].toString())??<String,dynamic>{});
      return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFE9E2F0))),child:Row(children:[
        const Icon(Icons.storefront,color:_p,size:28),const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(c['party_name']?.toString()??'',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
          Text((c['business_classification']?.toString()??'تصنيف غير محدد')+' • '+(c['district']?.toString()??'منطقة غير محددة'),style:const TextStyle(fontSize:12,color:Colors.black54)),
          const SizedBox(height:5),Wrap(spacing:12,runSpacing:4,children:[
            Text('المستهدف: '+money(g['sales_target']),style:const TextStyle(color:_p,fontWeight:FontWeight.w700)),
            Text('المحقق: '+money(demo?0:_actualSalesForCustomer(c['id'].toString())),style:const TextStyle(color:Color(0xFF168A70),fontWeight:FontWeight.w700)),
            Text('تحصيل: '+money(g['collection_target']),style:const TextStyle(color:Color(0xFF168A70),fontWeight:FontWeight.w700)),
            Text('فواتير: '+(g['target_orders']?.toString()??'0')),
          ]),
          if(!demo && _num(g['sales_target'])>0) Padding(padding:const EdgeInsets.only(top:8),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:(_actualSalesForCustomer(c['id'].toString())/_num(g['sales_target'])).clamp(0.0,1.0).toDouble(),minHeight:7,backgroundColor:const Color(0xFFEDE7F4),color:_o))),
        ])),
        IconButton(onPressed:demo?()=>_toast('مثال للعرض فقط.'):()=>_editGoal(c),icon:const Icon(Icons.edit,color:_o),tooltip:'تعديل الهدف'),
      ]));
    });
  }

  Widget _repsView(bool demo){
    final rows=demo?<Map<String,dynamic>>[
      {'id':'r1','rep_name':'أحمد سامح - مندوب تجريبي','rep_code':'DEMO-REP-01','monthly_sales_target':350000,'monthly_collection_target':280000,'commission_plan':'tiered','default_commission_rate':1.5},
      {'id':'r2','rep_name':'محمود عادل - مندوب تجريبي','rep_code':'DEMO-REP-02','monthly_sales_target':275000,'monthly_collection_target':220000,'commission_plan':'percentage','default_commission_rate':1.25},
      {'id':'r3','rep_name':'كريم أشرف - مندوب تجريبي','rep_code':'DEMO-REP-03','monthly_sales_target':220000,'monthly_collection_target':180000,'commission_plan':'fixed_per_invoice','default_commission_rate':35},
    ]:_reps;
    if(rows.isEmpty)return const Center(child:Text('لا يوجد مندوبون في دليل المندوبين.'));
    return ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(ctx,i){
      final r=rows[i];final m=r['commission_plan']?.toString()??'percentage';final rate=double.tryParse(r['default_commission_rate']?.toString()??'')??0;
      return Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFFE9E2F0))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.badge,color:_p,size:28),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['rep_name']?.toString()??'',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),Text((r['rep_code']?.toString()??'')+' • '+(m=='tiered'?'عمولة متدرجة':m=='fixed_per_invoice'?'قيمة لكل فاتورة':'نسبة ثابتة'),style:const TextStyle(color:Colors.black54,fontSize:12))])),IconButton(onPressed:demo?()=>_toast('مثال للعرض فقط.'):()=>_editRep(r),icon:const Icon(Icons.tune,color:_o))]),
        Wrap(spacing:14,runSpacing:6,children:[Text('مستهدف المبيعات: '+money(r['monthly_sales_target'])),Text('المبيعات المرحلة فعليًا: '+money(demo?0:_actualSalesForRep(r['id'].toString()))),Text(m=='fixed_per_invoice'?'عمولة: '+rate.toStringAsFixed(2)+' ج.م/فاتورة':'العمولة: '+rate.toStringAsFixed(2)+'%',style:const TextStyle(color:_p,fontWeight:FontWeight.w900))]),
        if(!demo) Padding(padding:const EdgeInsets.only(top:8),child:Text('تقدير العمولة قبل الاعتماد: '+money(_commissionEstimate(r)),style:const TextStyle(color:Color(0xFF168A70),fontWeight:FontWeight.w800))),
        if(!demo) Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:()=>_createCommissionRun(r),icon:const Icon(Icons.request_quote_rounded),label:const Text('إنشاء مسودة عمولة'))),
      ]));
    });
  }

  String _repNameForRun(Object? id) {
    for(final rep in _reps) { if(rep['id']?.toString()==id?.toString()) return (rep['rep_name']??'مندوب').toString(); }
    return 'مندوب';
  }

  Widget _runsView(bool demo) {
    final rows=demo?<Map<String,dynamic>>[
      {'representative_name':'أحمد سامح - تجريبي','period_start':_month.toIso8601String().substring(0,10),'period_end':_nextMonth.subtract(const Duration(days:1)).toIso8601String().substring(0,10),'eligible_sales':0,'eligible_invoice_count':0,'calculated_commission':0,'status':'draft','notes':'مثال عرض فقط؛ لا توجد عمولة فعلية.'},
    ]:_runs;
    if(rows.isEmpty)return const Center(child:Text('لا توجد مسودات عمولات. أنشئ مسودة من بطاقة المندوب بعد وجود فواتير مرحلة.'));
    return ListView.separated(
      itemCount:rows.length,
      separatorBuilder:(_,__)=>const SizedBox(height:9),
      itemBuilder:(ctx,i){
        final x=rows[i];
        final status=x['status']?.toString()??'draft';
        final label=status=='approved'?'معتمدة':status=='paid'?'مصروفة':status=='reviewed'?'تمت المراجعة':status=='cancelled'?'ملغاة':'مسودة';
        return Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFFE9E2F0))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Icon(Icons.request_quote_rounded,color:_p,size:28),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((x['representative_name']??_repNameForRun(x['representative_id'])).toString(),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
                Text((x['period_start']??'').toString()+' — '+(x['period_end']??'').toString(),style:const TextStyle(color:Colors.black54,fontSize:12)),
              ])),
              Chip(label:Text(label),backgroundColor:status=='approved'||status=='paid'?const Color(0xFFE2F6EA):const Color(0xFFFFF0D9)),
            ]),
            const SizedBox(height:8),
            Wrap(spacing:14,runSpacing:6,children:[
              Text('المبيعات: '+money(x['eligible_sales'])),
              Text('عدد الفواتير: '+(x['eligible_invoice_count']??0).toString()),
              Text('العمولة: '+money(x['calculated_commission']),style:const TextStyle(color:_p,fontWeight:FontWeight.w900)),
            ]),
            if((x['notes']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text(x['notes'].toString(),style:const TextStyle(color:Colors.black54,fontSize:12))),
            const Text('هذه المسودة لا تعني اعتماد الاستحقاق أو صرفه. تتم المراجعة المحاسبية قبل أي اعتماد.',style:TextStyle(color:Color(0xFF795000),fontSize:12,fontWeight:FontWeight.w700)),
          ]),
        );
      },
    );
  }

  Widget _plansView(bool demo){
    final rows=demo?<Map<String,dynamic>>[
      {'plan_name':'عمولة نسبة ثابتة','plan_code':'DEMO-COM-PCT','calculation_basis':'sales_value','commission_method':'percentage','flat_rate':1.25,'fixed_amount':0},
      {'plan_name':'عمولة ثابتة لكل فاتورة','plan_code':'DEMO-COM-FIX','calculation_basis':'invoice_count','commission_method':'fixed_per_invoice','flat_rate':0,'fixed_amount':35},
      {'plan_name':'شرائح عمولة متدرجة','plan_code':'DEMO-COM-TIER','calculation_basis':'sales_value','commission_method':'tiered','flat_rate':0,'fixed_amount':0},
    ]:_plans;
    if(rows.isEmpty)return const Center(child:Text('لا توجد خطط عمولة. طبّق ملف SQL لإنشاء الخطط التجريبية.'));
    return ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(ctx,i){
      final x=rows[i];final m=x['commission_method']?.toString()??'percentage';final id=x['id']?.toString();
      final tiers=_tiers.where((t)=>t['plan_id']?.toString()==id).toList();
      return Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFFE9E2F0))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(x['plan_name']?.toString()??'',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:_p)),
        Text((x['plan_code']?.toString()??'')+' • أساس الحساب: '+(x['calculation_basis']=='collected_value'?'المحصل':x['calculation_basis']=='gross_profit'?'مجمل الربح':x['calculation_basis']=='invoice_count'?'عدد الفواتير':'المبيعات'),style:const TextStyle(color:Colors.black54,fontSize:12)),
        const SizedBox(height:9),
        if(m=='percentage')Text('النسبة: '+(x['flat_rate']?.toString()??'0')+'%',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
        if(m=='fixed_per_invoice')Text('لكل فاتورة: '+money(x['fixed_amount']),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
        if(m=='tiered')...(tiers.isEmpty?<Widget>[const Text('0–99,999 ج.م: 0.75% • 100,000–249,999 ج.م: 1% • 250,000 ج.م فأكثر: 1.5%',style:TextStyle(fontSize:13))]:tiers.map<Widget>((t)=>Text('من '+money(t['min_value'])+' إلى '+(t['max_value']==null?'غير محدود':money(t['max_value']))+' — '+(t['rate']?.toString()??'0')+'%'))),
        const SizedBox(height:8),const Text('يجب مراجعة المرتجعات والتحصيلات والاستحقاق واعتماد العمولة قبل الصرف.',style:TextStyle(color:Colors.black54,fontSize:12)),
      ]));
    });
  }
}
