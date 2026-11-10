import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Code values are generated atomically by database triggers; item codes follow the three-level category path.
class ErpCodePolicyPanel extends StatefulWidget {
  const ErpCodePolicyPanel({super.key, required this.companyId});
  final String companyId;
  @override State<ErpCodePolicyPanel> createState() => ErpCodePolicyPanelState();
}

class ErpCodePolicyPanelState extends State<ErpCodePolicyPanel> {
  static const _purple = Color(0xFF3E007D);
  // Shared geometry for every coding-policy cell; the serial-count cell is the reference.
  static const double _cellHeight = 40;
  static const double _columnSpacing = 2.5;
  static const double _countCellWidth = 62;
  static const double _nameCellWidth = 83; // 124 × 2/3 = 82.67, rounded to 83 px.
  static const _types = <Map<String, String>>[


    {'key':'payroll_run','name':'مسيرات الرواتب','prefix':'Prl','digits':'5'},
    {'key':'warehouse','name':'المخازن','prefix':'Whs','digits':'5'},
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
  final Map<String, bool> _automatic = {};
  final Map<String, bool> _composite = {};
  // Keep persisted generator settings for policy types now edited in the lower policy grid.
  final Map<String, dynamic> _retainedTypeConfigs = {};
  final Map<String, List<TextEditingController>> _fieldNames = {};
  final Map<String, List<TextEditingController>> _fieldCounts = {};
  final _itemPrefix = TextEditingController(text: 'Itm');
  final _geoPrefix = TextEditingController(text: 'Rig');
  // Each geographic level is one independent two-digit segment.
  // The persisted geo_segments map remains cumulative for backward compatibility.
  final Map<String, TextEditingController> _geoSegments = {
    'country': TextEditingController(text: '20'),
    'governorate': TextEditingController(text: '2'),
    'center': TextEditingController(text: '2'),
    'area': TextEditingController(text: '2'),
  };
  final Map<String, TextEditingController> _itemSegments = {
    'main': TextEditingController(text: '2'),
    'sub': TextEditingController(text: '2'),
    'secondary': TextEditingController(text: '2'),
        'serial': TextEditingController(text: '3'),
  };
  bool _itemAutomatic = true, _itemComposite = true;
  bool _loading = true, _saving = false;
  final ScrollController _gridHorizontalController = ScrollController();
  final ScrollController _gridVerticalController = ScrollController();
  String? _error, _message;

  @override void initState() {
    super.initState();
    for (final t in _types) {
      _prefix[t['key']!] = TextEditingController(text: t['prefix']);
      _digits[t['key']!] = TextEditingController(text: t['digits']);
      final key = t['key']!;
      _automatic[key] = true;
      _composite[key] = key == 'customer';
      _fieldNames[key] = List.generate(3, (_) => TextEditingController());
      _fieldCounts[key] = List.generate(3, (_) => TextEditingController());
    }
    _load();
  }

  @override void dispose() {
    for (final c in _prefix.values) { c.dispose(); }
    for (final c in _digits.values) { c.dispose(); }
    for (final list in _fieldNames.values) { for (final c in list) { c.dispose(); } }
    for (final list in _fieldCounts.values) { for (final c in list) { c.dispose(); } }
    _itemPrefix.dispose();
    _geoPrefix.dispose();
    _gridHorizontalController.dispose();
    _gridVerticalController.dispose();
    for (final controller in _geoSegments.values) { controller.dispose(); }
    for (final controller in _itemSegments.values) { controller.dispose(); }
    super.dispose();
  }

  String _preview(String key) {
    final p = _prefix[key]!.text.trim();
    final n = int.tryParse(_digits[key]!.text) ?? 5;
    final serial = 1;
    return '$p${serial.toString().padLeft(n.clamp(1, 12).toInt(), '0')}';
  }

  Future<void> _load({bool propagateError = false}) async {
    try {
      var country = await _db.from('erp_countries').select('country_code')
        .eq('company_id', widget.companyId).eq('name_ar', 'مصر').maybeSingle();
      if (country == null) {
        await _db.from('erp_countries').upsert({
          'company_id': widget.companyId, 'country_code': '20',
          'name_ar': 'مصر', 'name_en': 'Egypt', 'is_active': true,
        }, onConflict: 'company_id,country_code');
        country = await _db.from('erp_countries').select('country_code')
          .eq('company_id', widget.companyId).eq('name_ar', 'مصر').maybeSingle();
      }
      if (country != null) _geoSegments['country']!.text = country['country_code'].toString();
      final policyRows = await _db.from('erp_program_policies').select('policy_code')
        .eq('company_id', widget.companyId).like('policy_code', 'Pol%');
      final usedPolicySerials = (policyRows as List).map((r) => int.tryParse((r['policy_code'] ?? '').toString().replaceFirst(RegExp(r'^Pol'), '')) ?? 0);
      _nextProgramPolicySerial = (usedPolicySerials.fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final row = await _db.from('erp_program_policies').select('policy_value')
        .eq('company_id', widget.companyId).eq('policy_key', 'code_generation_registry').maybeSingle();
      if (row != null && (row['policy_value'] ?? '').toString().isNotEmpty) {
        final data = jsonDecode(row['policy_value'].toString()) as Map<String, dynamic>;
        final configs = Map<String, dynamic>.from(data['types'] as Map? ?? {});
        final visibleTypeKeys = _types.map((t) => t['key']!).toSet();
        _retainedTypeConfigs
          ..clear()
          ..addEntries(configs.entries.where((entry) => !visibleTypeKeys.contains(entry.key)));
        for (final t in _types) {
          final cfg = Map<String, dynamic>.from(configs[t['key']] as Map? ?? {});
          if (cfg['prefix'] != null) _prefix[t['key']]!.text = cfg['prefix'].toString();
          if (cfg['digits'] != null) _digits[t['key']]!.text = cfg['digits'].toString();
          final key = t['key']!;
          _automatic[key] = cfg['automatic'] == null ? true : cfg['automatic'] == true;
          _composite[key] = cfg['composite'] == true;
          final fields = (cfg['fields'] as List?) ?? const [];
          for (var i = 0; i < 3 && i + 1 < fields.length; i++) {
            final field = Map<String, dynamic>.from(fields[i + 1] as Map? ?? {});
            if (field['name'] != null) _fieldNames[key]![i].text = field['name'].toString();
            if (field['digits'] != null) _fieldCounts[key]![i].text = field['digits'].toString();
          }
        }
        _itemPrefix.text = (data['item_prefix'] ?? 'Itm').toString();
        _itemAutomatic = data['item_automatic'] == null ? true : data['item_automatic'] == true;
        _itemComposite = data['item_composite'] == null ? true : data['item_composite'] == true;
        _geoPrefix.text = (data['geo_prefix'] ?? 'Rig').toString();
        // Prefer the new per-level lengths. Older policies stored cumulative
        // lengths (4/6/8), so retain the safe 2/2/2 defaults when upgrading them.
        final geoSegmentLengths = Map<String, dynamic>.from(
          data['geo_segment_lengths'] as Map? ?? {},
        );
        for (final key in const ['governorate', 'center', 'area']) {
          final configured = geoSegmentLengths[key];
          if (configured != null) {
            _geoSegments[key]!.text = configured.toString();
          }
        }
        final segments = Map<String, dynamic>.from(data['item_segments'] as Map? ?? {});
        for (final key in _itemSegments.keys) {
          if (segments[key] != null) _itemSegments[key]!.text = segments[key].toString();
        }
        _itemPrefix.text = 'Itm';
        _itemSegments['main']!.text = '2';
        _itemSegments['sub']!.text = '2';
        _itemSegments['secondary']!.text = '2';
        _itemSegments['serial']!.text = '3';
      }
    } catch (e) {
      _error = 'تعذر تحميل إعدادات التكويد: $e';
      if (propagateError) rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get isSaving => _saving;

  Future<void> reloadFromHeader() => _load(propagateError: true);

  Future<void> saveFromHeader() => _save();

  Future<void> _save() async {
    if (!mounted) return;
    for (final t in _types) {
      final key = t['key']!;
      if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(_prefix[key]!.text.trim())) {
        setState(() => _error = 'بادئة ${t['name']} يجب أن تكون 3 حروف إنجليزية بالضبط.');
        throw StateError(_error!);
      }
      final n = int.tryParse(_digits[key]!.text);
      if (n == null || n < 1 || n > 12) {
        setState(() => _error = 'عدد خانات ${t['name']} يجب أن يكون من 1 إلى 12.');
        throw StateError(_error!);
      }
    }
    final prefixes = _types.map((t) => _prefix[t['key']!]!.text.trim().toLowerCase()).toList();
    if (prefixes.toSet().length != prefixes.length || prefixes.contains(_itemPrefix.text.trim().toLowerCase())) {
      setState(() => _error = 'يجب أن تكون كل بادئة فريدة، وألا تتكرر مع بادئة الأصناف.');
      throw StateError(_error!);
    }
    if (_itemPrefix.text.trim() != 'Itm') {
      setState(() => _error = 'بادئة كود الأصناف ثابتة على Itm.');
      throw StateError(_error!);
    }
    for (final entry in _itemSegments.entries) {
      final value = int.tryParse(entry.value.text);
      final expected = entry.key == 'serial' ? 3 : 2;
      if (value != expected) {
        final label = {'main':'الرئيسية','sub':'الفرعية','secondary':'الثانوية','serial':'تسلسل'}[entry.key];
        setState(() => _error = 'عدد خانات $label يجب أن يكون $expected بالضبط.');
        throw StateError(_error!);
      }
    }
    final countryCode = _geoSegments['country']!.text.trim();
    if (!RegExp(r'^[0-9]{2}$').hasMatch(countryCode)) {
      setState(() => _error = 'يجب تحديد كود الدولة من تبويب بيانات الدول (رقمان).');
      throw StateError(_error!);
    }
    const expectedGeoLengths = {'governorate':2,'center':2,'area':2};
    for (final entry in expectedGeoLengths.entries) {
      final value = int.tryParse(_geoSegments[entry.key]!.text);
      if (value == null || value < 1 || value > 6) {
        final label = {
          'governorate':'المحافظة',
          'center':'المركز/الحي',
          'area':'المنطقة/القرية/التسلسل',
        }[entry.key];
        setState(() => _error = 'عدد خانات $label يجب أن يكون من 1 إلى 6.');
        throw StateError(_error!);
      }
    }
    final inheritedGeoDigits = 2 +
        int.parse(_geoSegments['governorate']!.text) +
        int.parse(_geoSegments['center']!.text) +
        int.parse(_geoSegments['area']!.text);
    if (inheritedGeoDigits != 8) {
      setState(() => _error = 'كود المنطقة الموروث في كود العميل يجب أن يظل 8 أرقام.');
      throw StateError(_error!);
    }
    if (_geoPrefix.text.trim() != 'Rig') {
      setState(() => _error = 'بادئة المنطقة يجب أن تكون 3 حروف إنجليزية مثل Rig.');
      throw StateError(_error!);
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final types = <String, dynamic>{..._retainedTypeConfigs};
      for (final t in _types) {
        final key = t['key']!;
        final fields = <Map<String, dynamic>>[
          {'name':'تسلسل','digits':int.parse(_digits[key]!.text)},
          for (var i = 0; i < 3; i++)
            if (_fieldNames[key]![i].text.trim().isNotEmpty)
              {'name':_fieldNames[key]![i].text.trim(),'digits':int.tryParse(_fieldCounts[key]![i].text) ?? 0},
        ];
        types[key] = {
          'prefix':_prefix[key]!.text.trim(),
          'digits':int.parse(_digits[key]!.text),
          'automatic':_automatic[key] ?? true,
          'composite':_composite[key] ?? false,
          'required':key == 'customer',
          'apply_to_all':key == 'customer' ? true : null,
          'fields':fields,
        };
      }
      types['customer'] = {
        'prefix':'Cus', 'digits':2, 'automatic':true, 'composite':true,
        'required':true, 'apply_to_all':true,
        'inherit_geo_code':true, 'geo_digits':8, 'serial_digits':2,
        'fields':[{'name':'كود المنطقة بدون بادئة Rig','digits':8},{'name':'تسلسل العميل','digits':2}],
      };
      final itemSegments = <String, int>{
        for (final entry in _itemSegments.entries) entry.key:int.parse(entry.value.text),
      };
      final payload = jsonEncode({
        'version':4,
        'layout':{
          'cell_height':_cellHeight.toInt(),
          'column_spacing':_columnSpacing.toInt(),
          'count_cell_width':_countCellWidth.toInt(),
        },
        'types':types,
        'customer_code':{'prefix':'Cus','inherit_geo_code':true,'geo_digits':8,'serial_digits':2},
        'item_prefix':_itemPrefix.text.trim(),
        'item_automatic':_itemAutomatic,
        'item_composite':_itemComposite,
        'item_fields':[
          {'name':'تسلسل الصنف','digits':itemSegments['serial']},
          {'name':'فئة ثانوية','digits':itemSegments['secondary']},
          {'name':'فئة فرعية','digits':itemSegments['sub']},
          {'name':'فئة رئيسية','digits':itemSegments['main']},
        ],
        'category_prefix':'Cat',
        'category_segments':{'main':2,'sub':2,'secondary':2},
        'brand_prefix':'Bra',
        'brand_digits':3,
        'item_segments':itemSegments,
        'geo_prefix':_geoPrefix.text.trim(),
        // Legacy cumulative values are intentionally preserved for existing
        // readers and database triggers: country=2, governorate=4,
        // center=6, area=8 total digits.
        'geo_segments':{
          'country':countryCode,
          'governorate':2 + int.parse(_geoSegments['governorate']!.text),
          'center':2 + int.parse(_geoSegments['governorate']!.text) + int.parse(_geoSegments['center']!.text),
          'area':2 + int.parse(_geoSegments['governorate']!.text) + int.parse(_geoSegments['center']!.text) + int.parse(_geoSegments['area']!.text),
        },
        // Each geographic level contributes its configured number of digits.
        'geo_segment_lengths':{
          'country':2,
          'governorate':int.parse(_geoSegments['governorate']!.text),
          'center':int.parse(_geoSegments['center']!.text),
          'area':int.parse(_geoSegments['area']!.text),
        },
        'geo_cumulative_lengths':{
          'country':2,
          'governorate':2 + int.parse(_geoSegments['governorate']!.text),
          'center':2 + int.parse(_geoSegments['governorate']!.text) + int.parse(_geoSegments['center']!.text),
          'area':2 + int.parse(_geoSegments['governorate']!.text) + int.parse(_geoSegments['center']!.text) + int.parse(_geoSegments['area']!.text),
        },
      });
      await _db.from('erp_program_policies').upsert({
        'company_id':widget.companyId,
        'policy_key':'code_generation_registry',
        'category':'سياسات الأكواد',
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
      rethrow;
    }
  }

  Widget _field(TextEditingController c, {required int max, required bool letters, required VoidCallback changed}) =>
    SizedBox(width:_countCellWidth, height:40, child: TextField(
      controller:c, textAlign:TextAlign.center, maxLength:max,
      inputFormatters:[FilteringTextInputFormatter.allow(RegExp(letters ? '[a-zA-Z]' : '[0-9]'))],
      onChanged:(_) => setState(changed),
      decoration:const InputDecoration(counterText:'',isDense:true,constraints:BoxConstraints(minHeight:40,maxHeight:40),contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:3),border:OutlineInputBorder()),
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700),
    ));

  Widget _nameField(TextEditingController controller, {bool readOnly = false}) => SizedBox(
    width:_nameCellWidth, height:40,
    child:TextField(
      controller:controller, readOnly:readOnly, textAlign:TextAlign.center,
      decoration:const InputDecoration(isDense:true,constraints:BoxConstraints(minHeight:40,maxHeight:40),border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:3)),
      style:const TextStyle(fontSize:11),
    ),
  );

  Widget _firstFieldName() => const SizedBox(
    width:124, height:_cellHeight,
    child:Center(child:Text('تسلسل',textAlign:TextAlign.center,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))),
  );

  Widget _brandPolicyCard() => Card(
    elevation:0,
    color:const Color(0xFFFFF4E5),
    child:Padding(
      padding:const EdgeInsets.all(10),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const Text('سياسة تكويد البراند / الماركة',style:TextStyle(fontWeight:FontWeight.w900,color:_purple)),
          const SizedBox(height:5),
          const Text('بادئة ثابتة Bra تليها 3 أرقام متسلسلة، دون إضافة بادئة جغرافية أو حروف أخرى.',style:TextStyle(fontSize:11)),
          const SizedBox(height:5),
          const Text('المعاينة الأولى: Bra001',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:_purple)),
        ],
      ),
    ),
  );

  Widget _itemPolicyRow() => Container(
    margin:const EdgeInsets.symmetric(vertical:2),
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
    decoration:BoxDecoration(color:const Color(0xFFFFF4E5),border:Border.all(color:const Color(0xFFE8E1EF)),borderRadius:BorderRadius.circular(7)),
    child:SizedBox(width:1420,child:Row(spacing:_columnSpacing,children:[
      SizedBox(width:30,child:Text('${_types.length+3}',textAlign:TextAlign.center,style:const TextStyle(fontSize:11))),
      const SizedBox(width:150,child:Text('الأصناف',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))),
      SizedBox(width:52,child:Checkbox(value:_itemAutomatic,onChanged:(v)=>setState(()=>_itemAutomatic=v ?? true),visualDensity:VisualDensity.compact)),
      
      SizedBox(width:52,child:Checkbox(value:_itemComposite,onChanged:(v)=>setState(()=>_itemComposite=v ?? true),visualDensity:VisualDensity.compact)),
      
      _firstFieldName(),
      
      _field(_itemSegments['serial']!,max:3,letters:false,changed:(){}),
      
      const SizedBox(width:_nameCellWidth,height:_cellHeight,child:Center(child:Text('فئة ثانوية',textAlign:TextAlign.center,style:TextStyle(fontSize:11)))),
      
      _field(_itemSegments['secondary']!,max:2,letters:false,changed:(){}),
      
      const SizedBox(width:_nameCellWidth,height:_cellHeight,child:Center(child:Text('فئة فرعية',textAlign:TextAlign.center,style:TextStyle(fontSize:11)))), 
      
      _field(_itemSegments['sub']!,max:2,letters:false,changed:(){}),
      
      const SizedBox(width:124,height:_cellHeight,child:Center(child:Text('فئة رئيسية',textAlign:TextAlign.center,style:TextStyle(fontSize:11)))),
      
      _field(_itemSegments['main']!,max:2,letters:false,changed:(){}),
      
      SizedBox(width:112,child:Column(mainAxisSize:MainAxisSize.min,children:[
        _field(_itemPrefix,max:3,letters:true,changed:(){}),
        const Text('3 حروف إنجليزية فقط',style:TextStyle(fontSize:8,color:Colors.black54)),
      ])),
      SizedBox(width:112,child:Text(
        '${_itemPrefix.text.trim()}${'1'.padLeft(int.tryParse(_itemSegments['main']!.text)??2,'0')}${'1'.padLeft(int.tryParse(_itemSegments['sub']!.text)??2,'0')}${'1'.padLeft(int.tryParse(_itemSegments['secondary']!.text)??2,'0')}${'1'.padLeft(int.tryParse(_itemSegments['serial']!.text)??2,'0')}',
        textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:_purple))),
    ])),
  );

  Widget _geoPolicyCard() => Container(
    margin:const EdgeInsets.symmetric(vertical:2),
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
    decoration:BoxDecoration(color:const Color(0xFFF5EFFB),border:Border.all(color:const Color(0xFFE8E1EF)),borderRadius:BorderRadius.circular(7)),
    child:SizedBox(width:1420,child:Row(spacing:_columnSpacing,children:[
      SizedBox(width:30,child:Text('${_types.length+1}',textAlign:TextAlign.center,style:const TextStyle(fontSize:11))),
      const SizedBox(width:150,child:Text('التقسيم الجغرافي',style:TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
      const SizedBox(width:52,child:Center(child:Icon(Icons.check_circle,color:_purple,size:18))),
      
      const SizedBox(width:52,child:Center(child:Icon(Icons.check_circle,color:_purple,size:18))),
      
      _firstFieldName(),  const SizedBox(width:_countCellWidth,height:_cellHeight), 
      _geoNameCell('منطقة/قرية'),  _segmentField('عدد',_geoSegments['area']!,2,width:_countCellWidth),
       _geoNameCell('حي/مركز/شياخة'),  _segmentField('عدد',_geoSegments['center']!,2,width:_countCellWidth),
       _geoNameCell('محافظة'),  _segmentField('عدد',_geoSegments['governorate']!,2,width:_countCellWidth),
       _geoNameCell('دولة'),  const SizedBox(width:_countCellWidth,height:_cellHeight,child:Center(child:Text('2',textAlign:TextAlign.center,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700)))),
      
      SizedBox(width:112,child:Text(_geoPrefix.text,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))),
      SizedBox(width:112,child:Text('Rig + ${2 + int.parse(_geoSegments['governorate']!.text) + int.parse(_geoSegments['center']!.text) + int.parse(_geoSegments['area']!.text)} أرقام',textAlign:TextAlign.center,style:TextStyle(fontSize:10))),
    ])),
  );

  Widget _customerPolicyRow() => Container(
    margin:const EdgeInsets.symmetric(vertical:2),
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
    decoration:BoxDecoration(color:const Color(0xFFFFF4E5),border:Border.all(color:const Color(0xFFE8E1EF)),borderRadius:BorderRadius.circular(7)),
    child:SizedBox(width:1420,child:Row(spacing:_columnSpacing,children:[
      SizedBox(width:30,child:Text('${_types.length+2}',textAlign:TextAlign.center,style:const TextStyle(fontSize:11))),
      const SizedBox(width:150,child:Text('تكويد العملاء',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))),
      const SizedBox(width:52,child:Center(child:Icon(Icons.check_circle,color:_purple,size:18))),
      const SizedBox(width:52,child:Center(child:Icon(Icons.check_circle,color:_purple,size:18))),
      const SizedBox(width:_nameCellWidth,height:_cellHeight,child:Center(child:Text('كود المنطقة',style:TextStyle(fontSize:11)))),
      const SizedBox(width:_countCellWidth,height:_cellHeight,child:Center(child:Text('8',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700)))),
      const SizedBox(width:_nameCellWidth,height:_cellHeight,child:Center(child:Text('تسلسل العميل',style:TextStyle(fontSize:11)))),
      const SizedBox(width:_countCellWidth,height:_cellHeight,child:Center(child:Text('2',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700)))),
      const SizedBox(width:124,height:_cellHeight),
      const SizedBox(width:_countCellWidth,height:_cellHeight),
      const SizedBox(width:112,child:Center(child:Text('Cus',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:_purple)))),
      SizedBox(width:112,child:Text('Cus + كود المنطقة (8 أرقام) + 01',textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:_purple))),
    ])),
  );

  Widget _geoNameCell(String name) => SizedBox(width:_nameCellWidth,height:_cellHeight,child:Center(child:Text(name,textAlign:TextAlign.center,style:const TextStyle(fontSize:11))));

  Widget _segmentField(String label, TextEditingController controller, int max, {double width = 112, bool readOnly = false}) => SizedBox(
    width:width,
    height:_cellHeight,
    child:TextField(
      controller:controller,
      readOnly:readOnly,
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
    child: _loading ? const Center(child:CircularProgressIndicator()) : Scrollbar(
      controller:_gridVerticalController,
      thumbVisibility:true,
      scrollbarOrientation:ScrollbarOrientation.left,
      child:Scrollbar(
      controller:_gridHorizontalController,
      thumbVisibility:true,
      scrollbarOrientation:ScrollbarOrientation.bottom,
      child:SingleChildScrollView(
        controller:_gridHorizontalController,
        scrollDirection:Axis.horizontal,
        child:SizedBox(width:1420,child:ListView(
      controller:_gridVerticalController,
      padding:const EdgeInsets.all(8),
      children:[
        Card(elevation:0,color:const Color(0xFFF5EFFB),child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('إعدادات التكويد المركزي',style:TextStyle(color:_purple,fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:4),
          const Text('حدد بادئة كل نوع وعدد الخانات الرقمية. المعاينة تعرض أول كود متوقع، ويبدأ الترقيم من 1.',style:TextStyle(fontSize:11,color:Colors.black54)),
          const SizedBox(height:8),
          const Text('معيار تنسيق الجدول: ارتفاع 40 بكسل، والمسافة بين الأعمدة 2.5 بكسل، وعرض خانات أسماء الخانات 83 بكسل (بدلًا من 124)، وعرض خانة العدد 62 بكسل.',style:TextStyle(fontSize:10,color:Colors.black54)),
          const SizedBox(height:8),
          SizedBox(width:1420,child:Row(spacing:_columnSpacing,children:const[
            SizedBox(width:30,child:Text('م',style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            SizedBox(width:150,child:Text('اسم السياسة',style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            SizedBox(width:52,child:Text('تلقائي',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:52,child:Text('مركب',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_nameCellWidth,child:Text('اسم خانة 1',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_countCellWidth,child:Text('عدد خانة 1',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_nameCellWidth,child:Text('اسم خانة 2',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_countCellWidth,child:Text('عدد خانة 2',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:124,child:Text('اسم خانة 3',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_countCellWidth,child:Text('عدد خانة 3',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:124,child:Text('اسم خانة 4',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_countCellWidth,child:Text('عدد خانة 4',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            SizedBox(width:_nameCellWidth,child:Text('اسم خانة 5',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:_countCellWidth,child:Text('عدد خانة 5',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
            
            SizedBox(width:112,child:Text('بادئة الكود\\n3 حروف إنجليزية فقط',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:9))),
            SizedBox(width:112,child:Text('معاينة أول كود',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10))),
          ])),
        ]))),
        ...List.generate(_types.length,(i){
          final t=_types[i]; final key=t['key']!;
          return Container(margin:const EdgeInsets.symmetric(vertical:2),padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
            decoration:BoxDecoration(color:i.isEven?Colors.white:const Color(0xFFFAF8FC),border:Border.all(color:const Color(0xFFE8E1EF)),borderRadius:BorderRadius.circular(7)),
            child:SizedBox(width:1420,child:Row(spacing:_columnSpacing,children:[
              SizedBox(width:30,child:Text('${i+1}',textAlign:TextAlign.center,style:const TextStyle(fontSize:11))),
              SizedBox(width:150,child:Text(t['name']!,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
              SizedBox(width:52,child:Checkbox(value:_automatic[key] ?? true,onChanged:(v)=>setState(()=>_automatic[key]=v ?? true),visualDensity:VisualDensity.compact)),
              SizedBox(width:52,child:Checkbox(value:_composite[key] ?? false,onChanged:(v)=>setState(()=>_composite[key]=v ?? false),visualDensity:VisualDensity.compact)),
              _firstFieldName(),
              _field(_digits[key]!,max:2,letters:false,changed:(){}),
              ...List<Widget>.generate(6, (index) {
                final slot = index ~/ 2;
                if (index.isEven) return _nameField(_fieldNames[key]![slot]);
                return SizedBox(width:_countCellWidth,height:_cellHeight,child:_field(_fieldCounts[key]![slot],max:2,letters:false,changed:(){}));
              }),
              const SizedBox(width:124,height:_cellHeight),
              const SizedBox(width:_countCellWidth,height:_cellHeight),
              SizedBox(width:112,child:Column(mainAxisSize:MainAxisSize.min,children:[
                _field(_prefix[key]!,max:3,letters:true,changed:(){}),
                const Text('3 حروف إنجليزية فقط',style:TextStyle(fontSize:8,color:Colors.black54)),
              ])),
              SizedBox(width:112,child:Text(_preview(key),textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:_purple))),
            ])));
        }),
        _geoPolicyCard(),
        _customerPolicyRow(),
        _itemPolicyRow(),
        Card(elevation:0,color:const Color(0xFFF5EFFB),child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('تفاصيل سياسة فئات الأصناف Cat',style:TextStyle(fontWeight:FontWeight.w900,color:_purple)),
          const SizedBox(height:6),
          const Text('تسلسل الفئات هرمي وثابت: فئة رئيسية خانتان + فئة فرعية خانتان + فئة ثانوية خانتان. كل مستوى يُرقّم داخل المستوى الأب، ولا تُضاف حروف إلى أي مستوى.',style:TextStyle(fontSize:11)),
          const SizedBox(height:6),
          const Text('المعاينة: Cat + 01 + 01 + 01 = Cat010101',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:_purple)),
        ]))),
        _brandPolicyCard(),
        Card(elevation:0,color:const Color(0xFFFFF4E5),child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('تفاصيل تركيب كود الأصناف',style:TextStyle(fontWeight:FontWeight.w900,color:_purple)),
          const SizedBox(height:5),
          Row(spacing:_columnSpacing,children:[
            const Expanded(child:Text('بادئة الصنف (3 حروف إنجليزية)',style:TextStyle(fontSize:11))),
            _field(_itemPrefix,max:3,letters:true,changed:(){}),
          ]),
          const SizedBox(height:10),
          const Text('أطوال الخانات المعتمدة — ثابتة: 2 + 2 + 2 + 3',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),
          Wrap(spacing:8,runSpacing:8,children:[
            _segmentField('فئة رئيسية',_itemSegments['main']!,2,readOnly:true),
            _segmentField('فئة فرعية',_itemSegments['sub']!,2,readOnly:true),
            _segmentField('فئة ثانوية',_itemSegments['secondary']!,2,readOnly:true),
            _segmentField('تسلسل الصنف',_itemSegments['serial']!,3,readOnly:true),
          ]),
          const SizedBox(height:8),
          Text('الصيغة: ${_itemPrefix.text.trim()} + كود الفئة الثانوية بدون Cat (6 أرقام) + تسلسل الصنف (3 أرقام)',style:const TextStyle(fontSize:11)),
          Text('المعاينة الأولى: ${_itemPrefix.text.trim()}010101001',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:_purple)),
          const Text('كود الصنف = Itm + 6 أرقام الفئة الثانوية + 3 أرقام تسلسل (9 أرقام رقمية بعد البادئة). مستويات Cat ثابتة على 2 + 2 + 2.',style:TextStyle(fontSize:10,color:Colors.black54)),
        ]))),
        if(_error!=null) Padding(padding:const EdgeInsets.all(6),child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:11))),
        if(_message!=null) Padding(padding:const EdgeInsets.all(6),child:Text(_message!,style:const TextStyle(color:Colors.green,fontSize:11))),
        
      ],
        )),
      ),
    ),
    ),
  );
}
