import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    {'key':'shipping_company','name':'شركات الشحن','prefix':'Shp','digits':'5'},
    {'key':'delegate','name':'المندوبون','prefix':'Del','digits':'5'},
    {'key':'branch','name':'الفروع','prefix':'Brn','digits':'5'},
    {'key':'warehouse','name':'المخازن','prefix':'Whs','digits':'5'},
    {'key':'category','name':'فئات الأصناف','prefix':'Cat','digits':'5'},
    {'key':'account','name':'الحسابات المالية','prefix':'Acc','digits':'5'},
    {'key':'cashbox','name':'الخزائن والحسابات البنكية','prefix':'Csh','digits':'5'},
    {'key':'cost_center','name':'مراكز التكلفة','prefix':'Cst','digits':'5'},
    {'key':'currency','name':'العملات','prefix':'Cur','digits':'5'},
    {'key':'price_list','name':'قوائم الأسعار','prefix':'Prc','digits':'5'},
    {'key':'sales_invoice','name':'فواتير البيع','prefix':'Siv','digits':'5'},
    {'key':'sales_order','name':'أوامر البيع','prefix':'Sor','digits':'5'},
    {'key':'quotation','name':'عروض الأسعار','prefix':'Qot','digits':'5'},
    {'key':'purchase_invoice','name':'فواتير الشراء','prefix':'Piv','digits':'5'},
    {'key':'purchase_order','name':'أوامر الشراء','prefix':'Por','digits':'5'},
    {'key':'cash_receipt','name':'سندات القبض','prefix':'Rcp','digits':'5'},
    {'key':'cash_payment','name':'سندات الصرف','prefix':'Pay','digits':'5'},
    {'key':'journal_entry','name':'القيود اليومية','prefix':'Jrn','digits':'5'},
    {'key':'api_key','name':'مفاتيح API','prefix':'Api','digits':'5'},
    {'key':'activity','name':'الأنشطة','prefix':'Act','digits':'5'},
  ];

  final _db = Supabase.instance.client;
  final Map<String, TextEditingController> _prefix = {};
  final Map<String, TextEditingController> _digits = {};
  final _itemPrefix = TextEditingController(text: 'itm');
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
    super.dispose();
  }

  String _preview(String key) {
    final p = _prefix[key]!.text.trim();
    final n = int.tryParse(_digits[key]!.text) ?? 5;
    return '$p ${List<String>.filled(n.clamp(1, 12).toInt(), '0').join()}';
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
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(_itemPrefix.text.trim())) {
      setState(() => _error = 'بادئة الأصناف يجب أن تكون 3 حروف إنجليزية بالضبط.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final types = <String, dynamic>{};
      for (final t in _types) {
        final key = t['key']!;
        types[key] = {'prefix':_prefix[key]!.text.trim(), 'digits':int.parse(_digits[key]!.text)};
      }
      final payload = jsonEncode({'version':1,'types':types,'item_prefix':_itemPrefix.text.trim()});
      await _db.from('erp_program_policies').upsert({
        'company_id':widget.companyId, 'policy_key':'code_generation_registry',
        'category':'برمجية', 'name_ar':'سياسات التكويد المركزي', 'name_en':'Central code generation policies',
        'is_enabled':true, 'apply_to_all':true, 'user_ids':<String>[], 'policy_value':payload,
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
            SizedBox(width:80,child:Text('3 حروف',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
            SizedBox(width:66,child:Text('الخانات',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),
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
              _field(_prefix[key]!,max:3,letters:true,changed:(){}),
              const SizedBox(width:5),
              _field(_digits[key]!,max:2,letters:false,changed:(){}),
              SizedBox(width:112,child:Text(_preview(key),textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:_purple))),
            ]));
        }),
        Card(elevation:0,color:const Color(0xFFFFF4E5),child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('التكويد الخاص بالأصناف',style:TextStyle(fontWeight:FontWeight.w900,color:_purple)),
          const SizedBox(height:5),
          Row(children:[
            const Expanded(child:Text('بادئة الصنف (3 حروف إنجليزية)',style:TextStyle(fontSize:11))),
            _field(_itemPrefix,max:3,letters:true,changed:(){}),
            const SizedBox(width:8),
            const Expanded(child:Text('عدد الأرقام ثابت: 8 خانات',textAlign:TextAlign.end,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))),
          ]),
          const SizedBox(height:5),
          const Text('الصيغة: itm + رئيسية (2) + فرعية (2) + ثانوية (2) + مسلسل (2)',style:TextStyle(fontSize:11)),
          const Text('مثال أولي: itm01010101 — يتغير رقم كل مستوى حسب ترتيب الفئة داخل المستوى.',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:_purple)),
        ]))),
        if(_error!=null) Padding(padding:const EdgeInsets.all(6),child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:11))),
        if(_message!=null) Padding(padding:const EdgeInsets.all(6),child:Text(_message!,style:const TextStyle(color:Colors.green,fontSize:11))),
        Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_saving?null:_save,icon:const Icon(Icons.save),label:Text(_saving?'جارٍ الحفظ':'حفظ إعدادات التكويد'))),
      ],
    ),
  );
}
