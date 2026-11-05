import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Code values are generated atomically by database triggers; item codes follow the three-level category path.
class ErpCodePolicyPanel extends StatefulWidget {
  const ErpCodePolicyPanel({super.key, required this.companyId});
  final String companyId;
  @override State<ErpCodePolicyPanel> createState() => _ErpCodePolicyPanelState();
}

class _ErpCodePolicyPanelState extends State<ErpCodePolicyPanel> {
  static const _purple = Color(0xFF3E007D);
  static const _types = <Map<String, String>>[
    {'key':'employee','name':'الموظفون','prefix':'Emp','digits':'5'},
    {'key':'user','name':'المستخدمون','prefix':'Usr','digits':'5'},
    {'key':'supplier','name':'الموردون','prefix':'Sup','digits':'5'},
    {'key':'customer','name':'العملاء','prefix':'Cus','digits':'5'},
    {'key':'delegate','name':'المندوبون','prefix':'Del','digits':'5'},
    {'key':'branch','name':'الفروع','prefix':'Brn','digits':'5'},
    {'key':'warehouse','name':'المخازن','prefix':'Whs','digits':'5'},
    {'key':'category','name':'فئات الأصناف','prefix':'Cat','digits':'5'},
    {'key':'department','name':'إدارات الموارد البشرية','prefix':'Dpt','digits':'5'},
    {'key':'job','name':'المسميات الوظيفية','prefix':'Job','digits':'5'},
    {'key':'work_location','name':'مواقع العمل','prefix':'Loc','digits':'5'},
    {'key':'grade','name':'الدرجات الوظيفية','prefix':'Grd','digits':'5'},
    {'key':'payroll_run','name':'مسيرات الرواتب','prefix':'Prl','digits':'5'},
    {'key':'salary_element','name':'عناصر المرتبات','prefix':'Sal','digits':'5'},
    {'key':'unit','name':'وحدات الأصناف','prefix':'Unt','digits':'5'},
    {'key':'payment_method','name':'طرق الدفع','prefix':'Pmt','digits':'5'},
    {'key':'shift','name':'ورديات العمل','prefix':'Shf','digits':'5'},
    {'key':'commission_plan','name':'خطط العمولات','prefix':'Com','digits':'5'},
    {'key':'sales_fulfillment','name':'أذون التجهيز والتسليم','prefix':'Ful','digits':'5'},
    {'key':'user_type','name':'أنواع المستخدمين','prefix':'Typ','digits':'5'},
    {'key':'permission_template','name':'قوالب الصلاحيات','prefix':'Tpl','digits':'5'},
    {'key':'user_classification','name':'تصنيفات المستخدمين','prefix':'Cls','digits':'5'},
    {'key':'journal_entry','name':'القيود اليومية','prefix':'Jrn','digits':'5'},
    {'key':'account','name':'الحسابات المالية','prefix':'Acc','digits':'5'},
    {'key':'cashbox','name':'الخزائن والحسابات البنكية','prefix':'Csh','digits':'5'},
    {'key':'cost_center','name':'مراكز التكلفة','prefix':'Cst','digits':'5'},
    {'key':'price_list','name':'قوائم الأسعار','prefix':'Pli','digits':'5'},
    {'key':'sales_invoice','name':'فواتير البيع','prefix':'Siv','digits':'5'},
    {'key':'sales_order','name':'أوامر البيع','prefix':'Sor','digits':'5'},
    {'key':'sales_delivery','name':'أذون تسليم المبيعات','prefix':'Dlv','digits':'5'},
    {'key':'sales_return','name':'مرتجعات المبيعات','prefix':'Srt','digits':'5'},
    {'key':'quotation','name':'عروض الأسعار','prefix':'Qot','digits':'5'},
    {'key':'purchase_invoice','name':'فواتير الشراء','prefix':'Piv','digits':'5'},
    {'key':'purchase_order','name':'أوامر الشراء','prefix':'Por','digits':'5'},
    {'key':'purchase_receipt','name':'إيصالات استلام المشتريات','prefix':'Prr','digits':'5'},
    {'key':'purchase_return','name':'مرتجعات المشتريات','prefix':'Prt','digits':'5'},
    {'key':'cash_receipt','name':'سندات القبض','prefix':'Rcp','digits':'5'},
    {'key':'cash_payment','name':'سندات الصرف','prefix':'Cpy','digits':'5'},
    {'key':'cash_transfer','name':'سندات التحويل','prefix':'Trf','digits':'5'},
    {'key':'cash_movement','name':'الحركات النقدية','prefix':'Cmv','digits':'5'},
    {'key':'cash_order','name':'أوامر الخزينة','prefix':'Cso','digits':'5'},
    {'key':'checkbook','name':'دفاتر الشيكات','prefix':'Ckb','digits':'5'},
    {'key':'workspace_branch','name':'فروع إدارة النشاط','prefix':'Wbr','digits':'5'},
    {'key':'workspace_cash_movement','name':'حركات نقدية إدارة النشاط','prefix':'Wcm','digits':'5'},
    {'key':'workspace_customer','name':'عملاء إدارة النشاط','prefix':'Wcu','digits':'5'},
    {'key':'workspace_supplier','name':'موردو إدارة النشاط','prefix':'Wsu','digits':'5'},
    {'key':'workspace_department','name':'إدارات إدارة النشاط','prefix':'Wdp','digits':'5'},
    {'key':'workspace_employee','name':'موظفو إدارة النشاط','prefix':'Wem','digits':'5'},
    {'key':'workspace_warehouse','name':'مخازن إدارة النشاط','prefix':'Wwh','digits':'5'},
    {'key':'workspace_purchase','name':'مستندات شراء إدارة النشاط','prefix':'Wpi','digits':'5'},
    {'key':'workspace_purchase_return','name':'مرتجعات شراء إدارة النشاط','prefix':'Wpr','digits':'5'},
    {'key':'workspace_sale','name':'مستندات بيع إدارة النشاط','prefix':'Wsi','digits':'5'},
    {'key':'workspace_sale_return','name':'مرتجعات بيع إدارة النشاط','prefix':'Wsr','digits':'5'},
    {'key':'workspace_transfer','name':'تحويلات إدارة النشاط','prefix':'Wtr','digits':'5'},
    {'key':'workspace_adjustment','name':'تسويات إدارة النشاط','prefix':'Wad','digits':'5'},
  ];

  final _db = Supabase.instance.client;
  final Map<String, TextEditingController> _prefix = {};
  final Map<String, TextEditingController> _digits = {};
  final _itemPrefix = TextEditingController(text: 'itm');
  final Map<String, TextEditingController> _itemSegments = {
    'main': TextEditingController(text: '2'),
    'sub': TextEditingController(text: '2'),
    'secondary': TextEditingController(text: '2'),
    'serial': TextEditingController(text: '2'),
  };
  bool _loading = true, _saving = false;
  String? _error, _message;

  @override void initState() {
    super.initState();
    for (final t in _types) {
      _prefix[t['key']!] = TextEditingController(text: t['prefix']);
      _digits[t['key']!] = TextEditingController(text: t['digits']);
    }
    _load();
  }

  @override void dispose() {
    for (final c in _prefix.values) { c.dispose(); }
    for (final c in _digits.values) { c.dispose(); }
    _itemPrefix.dispose();
    for (final controller in _itemSegments.values) { controller.dispose(); }
    super.dispose();
  }

  String _preview(String key) {
    final p = _prefix[key]!.text.trim();
    final n = int.tryParse(_digits[key]!.text) ?? 5;
    return '$p${(1).toString().padLeft(n.clamp(1, 12).toInt(), '0')}';
  }

  Future<void> _load() async {
    try {
      final row = await _db.from('erp_program_policies').select('policy_value')
        .eq('company_id', widget.companyId).eq('policy_key', 'code_generation_registry').maybeSingle();
      if (row != null && (row['policy_value'] ?? '').toString().isNotEmpty) {
        final data = jsonDecode(row['policy_value'].toString()) as Map<String, dynamic>;
        final configs = Map<String, dynamic>.from(data['types'] as Map? ?? {});
        for (final t in _types) {
          final cfg = Map<String, dynamic>.from(configs[t['key']] as Map? ?? {});
          if (cfg['prefix'] != null) _prefix[t['key']]!.text = cfg['prefix'].toString();
          if (cfg['digits'] != null) _digits[t['key']]!.text = cfg['digits'].toString();
        }
        _itemPrefix.text = (data['item_prefix'] ?? 'itm').toString();
        final segments = Map<String, dynamic>.from(data['item_segments'] as Map? ?? {});
        for (final key in _itemSegments.keys) {
          if (segments[key] != null) _itemSegments[key]!.text = segments[key].toString();
        }
      }
    } catch (e) {
      _error = 'تعذر تحميل إعدادات التكويد: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    for (final t in _types) {
      final key = t['key']!;
      if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(_prefix[key]!.text.trim())) {
        setState(() => _error = 'بادئة ${t['name']} يجب أن تكون 3 حروف إنجليزية بالضبط.');
        return;
      }
      final n = int.tryParse(_digits[key]!.text);
      if (n == null || n < 1 || n > 12) {
        setState(() => _error = 'عدد خانات ${t['name']} يجب أن يكون من 1 إلى 12.');
        return;
      }
    }
    final prefixes = _types.map((t) => _prefix[t['key']!]!.text.trim().toLowerCase()).toList();
    if (prefixes.toSet().length != prefixes.length || prefixes.contains(_itemPrefix.text.trim().toLowerCase())) {
      setState(() => _error = 'يجب أن تكون كل بادئة فريدة، وألا تتكرر مع بادئة الأصناف.');
      return;
    }
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(_itemPrefix.text.trim())) {
      setState(() => _error = 'بادئة الأصناف يجب أن تكون 3 حروف إنجليزية بالضبط.');
      return;
    }
    for (final entry in _itemSegments.entries) {
      final value = int.tryParse(entry.value.text);
      final max = entry.key == 'serial' ? 8 : 4;
      if (value == null || value < 1 || value > max) {
        final label = {'main':'الرئيسية','sub':'الفرعية','secondary':'الثانوية','serial':'التسلسل'}[entry.key];
        setState(() => _error = 'عدد خانات الفئة $label يجب أن يكون من 1 إلى $max.');
        return;
      }
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final types = <String, dynamic>{};
      for (final t in _types) {
        final key = t['key']!;
        types[key] = {'prefix':_prefix[key]!.text.trim(), 'digits':int.parse(_digits[key]!.text)};
      }
      final itemSegments = <String, int>{
        for (final entry in _itemSegments.entries) entry.key:int.parse(entry.value.text),
      };
      final payload = jsonEncode({
        'version':2,
        'types':types,
        'item_prefix':_itemPrefix.text.trim(),
        'item_segments':itemSegments,
      });
      await _db.from('erp_program_policies').upsert({
        'company_id':widget.companyId,
        'policy_key':'code_generation_registry',
        'category':'برمجية',
        'name_ar':'سياسات التكويد المركزي',
        'name_en':'Central code generation policies',
        'is_enabled':true,
        'apply_to_all':true,
        'user_ids':<String>[],
        'policy_value':payload,
      }, onConflict:'company_id,policy_key');
      if (mounted) setState(() { _saving = false; _message = 'تم حفظ إعدادات التكويد المركزي.'; });
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ إعدادات التكويد: $e'; });
    }
  }

  Widget _field(TextEditingController c, {required int max, required bool letters, required VoidCallback changed}) =>
    SizedBox(width: letters ? 76 : 62, child: TextField(
      controller:c, textAlign:TextAlign.center, maxLength:max,
      inputFormatters:[FilteringTextInputFormatter.allow(RegExp(letters ? '[a-zA-Z]' : '[0-9]'))],
      onChanged:(_) => setState(changed),
      decoration:const InputDecoration(counterText:'',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:8),border:OutlineInputBorder()),
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700),
    ));

  Widget _segmentField(String label, TextEditingController controller, int max) => SizedBox(
    width:112,
    child:TextField(
      controller:controller,
      textAlign:TextAlign.center,
      keyboardType:TextInputType.number,
      maxLength:max,
      inputFormatters:[FilteringTextInputFormatter.digitsOnly],
      onChanged:(_) => setState((){}),
      decoration:InputDecoration(
        labelText:label,
        counterText:'',
        isDense:true,
        contentPadding:const EdgeInsets.symmetric(horizontal:6,vertical:9),
        border:const OutlineInputBorder(),
      ),
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800),
    ),
  );

  @override Widget build(BuildContext context) => Directionality(
    textDirection:TextDirection.rtl,
    child: _loading ? const Center(child:CircularProgressIndicator()) : ListView(
      padding:const EdgeInsets.all(8),
      children:[
        Card(elevation:0,color:const Color(0xFFF5EFFB),child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('إعدادات التكويد المركزي',style:TextStyle(color:_purple,fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:4),
          const Text('حدد بادئة كل نوع وعدد الخانات الرقمية. المعاينة تعرض أول كود متوقع، ويبدأ الترقيم من 1.',style:TextStyle(fontSize:11,color:Colors.black54)),
          const SizedBox(height:8),
          Row(children:const[
            SizedBox(width:30,child:Text('م',style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            Expanded(child:Text('الشاشة / نوع التكويد',style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            SizedBox(width:66,child:Text('الخانات',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            SizedBox(width:80,child:Text('3 حروف',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            SizedBox(width:112,child:Text('معاينة أول كود',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
          ]),
        ]))),
        ...List.generate(_types.length,(i){
          final t=_types[i]; final key=t['key']!;
          return Container(margin:const EdgeInsets.symmetric(vertical:2),padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
            decoration:BoxDecoration(color:i.isEven?Colors.white:const Color(0xFFFAF8FC),border:Border.all(color:const Color(0xFFE8E1EF)),borderRadius:BorderRadius.circular(7)),
            child:Row(children:[
              SizedBox(width:30,child:Text('${i+1}',textAlign:TextAlign.center,style:const TextStyle(fontSize:11))),
              Expanded(child:Text(t['name']!,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
              _field(_digits[key]!,max:2,letters:false,changed:(){}),
              const SizedBox(width:5),
              _field(_prefix[key]!,max:3,letters:true,changed:(){}),
              SizedBox(width:112,child:Text(_preview(key),textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:_purple))),
            ]));
        }),
        Card(elevation:0,color:const Color(0xFFFFF4E5),child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('التكويد الخاص بالأصناف',style:TextStyle(fontWeight:FontWeight.w900,color:_purple)),
          const SizedBox(height:5),
          Row(children:[
            const Expanded(child:Text('بادئة الصنف (3 حروف إنجليزية)',style:TextStyle(fontSize:11))),
            _field(_itemPrefix,max:3,letters:true,changed:(){}),
          ]),
          const SizedBox(height:10),
          const Text('تحديد عدد خانات كل مستوى — قابل للتعديل والحفظ',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),
          Wrap(spacing:8,runSpacing:8,children:[
            _segmentField('فئة رئيسية',_itemSegments['main']!,4),
            _segmentField('فئة فرعية',_itemSegments['sub']!,4),
            _segmentField('فئة ثانوية',_itemSegments['secondary']!,4),
            _segmentField('التسلسل',_itemSegments['serial']!,8),
          ]),
          const SizedBox(height:8),
          Text('الصيغة: ${_itemPrefix.text.trim()} + رئيسية (${_itemSegments['main']!.text}) + فرعية (${_itemSegments['sub']!.text}) + ثانوية (${_itemSegments['secondary']!.text}) + تسلسل (${_itemSegments['serial']!.text})',style:const TextStyle(fontSize:11)),
          Text('المعاينة الأولى: ${_itemPrefix.text.trim()}${'1'.padLeft(int.tryParse(_itemSegments['main']!.text)??2,'0')}${'1'.padLeft(int.tryParse(_itemSegments['sub']!.text)??2,'0')}${'1'.padLeft(int.tryParse(_itemSegments['secondary']!.text)??2,'0')}${'1'.padLeft(int.tryParse(_itemSegments['serial']!.text)??2,'0')}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:_purple)),
          const Text('القيم الافتراضية: 2 / 2 / 2 / 2. يمكن تغيير طول أي مستوى دون تثبيت إجمالي عدد الأرقام.',style:TextStyle(fontSize:10,color:Colors.black54)),
        ]))),
        if(_error!=null) Padding(padding:const EdgeInsets.all(6),child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:11))),
        if(_message!=null) Padding(padding:const EdgeInsets.all(6),child:Text(_message!,style:const TextStyle(color:Colors.green,fontSize:11))),
        Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_saving?null:_save,icon:const Icon(Icons.save),label:Text(_saving?'جارٍ الحفظ':'حفظ إعدادات التكويد'))),
      ],
    ),
  );
}
