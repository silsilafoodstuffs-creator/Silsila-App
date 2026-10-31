import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpProgramPoliciesScreen extends StatefulWidget {
  const ErpProgramPoliciesScreen({super.key, required this.companyId});
  final String? companyId;
  @override State<ErpProgramPoliciesScreen> createState() => _ErpProgramPoliciesScreenState();
}

class _ErpProgramPoliciesScreenState extends State<ErpProgramPoliciesScreen> {
  static const tabs = ['الهوية البصرية','برمجية','محاسبية','مخزنية','بيعية','شرائية','إدارية'];
  static const defaults = <Map<String,dynamic>>[
    {'key':'ui_dimensions','category':'برمجية','ar':'السماح بتعديل مساحة وحدود الأزرار والخانات','en':'Allow changing button and field dimensions'},
    {'key':'ui_reorder','category':'برمجية','ar':'نقل مكان الأزرار وتعديل ترتيب الأعمدة أو الصفوف','en':'Reposition buttons and reorder columns or rows'},
    {'key':'fiscal_year','category':'محاسبية','ar':'فترة السنة المالية','en':'Fiscal year','mandatory':true,'value':'01/01 - 12/31'},
    {'key':'inventory_valuation','category':'محاسبية','ar':'طريقة تقييم المخزون','en':'Inventory valuation method','mandatory':true,'value':'المتوسط المرجح','options':['المتوسط المرجح','الوارد أولاً صادر أولاً (FIFO)','التحديد المحدد']},
    {'key':'inventory_count','category':'محاسبية','ar':'طريقة الجرد','en':'Inventory counting method','mandatory':true,'value':'الجرد المستمر','options':['الجرد المستمر','الجرد الدوري']},
    {'key':'depreciation','category':'محاسبية','ar':'طريقة إهلاك الأصول','en':'Asset depreciation method','mandatory':true,'value':'القسط الثابت','options':['القسط الثابت','القسط المتناقص','وحدات الإنتاج']},
    {'key':'group_duplicate_items','category':'مخزنية','ar':'تجميع الأصناف المتكررة في شاشات المخازن','en':'Group duplicate items in inventory screens'},
    {'key':'zero_adjustment_only','category':'مخزنية','ar':'اشتراط ترحيل التسوية المخزنية بصفر فقط','en':'Require inventory adjustments to post only at zero'},
    {'key':'adjustment_sale_price','category':'مخزنية','ar':'سعر الصنف في التسوية المخزنية هو سعر البيع بدلاً من سعر الشراء','en':'Use sale price in inventory adjustments'},
    {'key':'balance_sale_price','category':'مخزنية','ar':'سعر الصنف في تقارير الأرصدة هو سعر البيع بدلاً من سعر الشراء','en':'Use sale price in balance reports'},
    {'key':'customer_default_rep','category':'بيعية','ar':'إمكانية تغيير المندوب الافتراضي للعميل','en':'Allow changing customer default sales representative'},
    {'key':'customer_default_price_policy','category':'بيعية','ar':'إمكانية تغيير سياسة الأسعار الافتراضية للعميل','en':'Allow changing customer default price policy'},
    {'key':'edit_other_user_document','category':'بيعية','ar':'إمكانية تعديل المستند لغير المستخدم الأصلي','en':'Allow editing documents created by another user'},
    {'key':'customer_shortages_to_invoice','category':'بيعية','ar':'إضافة نواقص العملاء الواردة إلى فاتورة البيع مباشرة','en':'Add customer shortages directly to sales invoice'},
    {'key':'sales_invoice_audit','category':'بيعية','ar':'عمل سجل لكل حركات فاتورة البيع','en':'Log all sales invoice actions'},
    {'key':'skip_quotation','category':'بيعية','ar':'تخطي عرض أسعار في أمر البيع','en':'Skip quotation in sales order','all':true},
    {'key':'skip_sales_order','category':'بيعية','ar':'تخطي أمر البيع في فاتورة البيع','en':'Skip sales order in sales invoice'},
    {'key':'skip_supply_order','category':'شرائية','ar':'تخطي أمر التوريد في أمر الشراء','en':'Skip supply order in purchase order'},
    {'key':'skip_purchase_order','category':'شرائية','ar':'تخطي أمر الشراء في فاتورة الشراء','en':'Skip purchase order in purchase invoice'},
    {'key':'supplier_bonus_variance','category':'شرائية','ar':'تحديد نسبة فروقات وارد حوافز الموردين','en':'Set supplier incentives incoming variance','value':'0.025%'},
    {'key':'national_id_required','category':'إدارية','ar':'الرقم القومي الزامي لتسجيل موظف جديد','en':'Require national ID for new employees','all':true},
  ];
  final db = Supabase.instance.client;
  final values = <String,Map<String,dynamic>>{};
  final users = <Map<String,dynamic>>[];
  final GlobalKey<_ErpVisualIdentityPolicyScreenState> _identityKey = GlobalKey<_ErpVisualIdentityPolicyScreenState>();
  int tab = 0; bool loading = true, saving = false; String? error, message;
  String get company => (widget.companyId ?? '').trim();
  @override void initState(){super.initState(); for(final p in defaults){values[p['key'] as String]={...p,'enabled':p['mandatory']==true || p['key']=='skip_quotation' || p['key']=='national_id_required','all':p['mandatory']==true || p['all']==true,'user_ids':<String>[]};} _load();}
  @override void didUpdateWidget(covariant ErpProgramPoliciesScreen oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.companyId!=widget.companyId)_load();}
  Future<void> _load() async {
    if(company.isEmpty){setState(() { loading=false; error='اختر الشركة وسجّل الدخول أولاً.'; });return;}
    setState(() { loading=true; error=null; message=null; });
    try {
      var rows=await db.from('erp_program_policies').select().eq('company_id',company);
      if ((rows as List).isEmpty) {
        final initial=defaults.map((p)=><String,dynamic>{'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],'is_enabled':p['mandatory']==true || p['key']=='skip_quotation' || p['key']=='national_id_required','apply_to_all':p['mandatory']==true || p['all']==true,'user_ids':<String>[],'policy_value':p['value']??''}).toList();
        await db.from('erp_program_policies').upsert(initial,onConflict:'company_id,policy_key');
        rows=await db.from('erp_program_policies').select().eq('company_id',company);
      }
      for(final row in (rows as List).whereType<Map<String,dynamic>>()) { final key=(row['policy_key']??'').toString(); if(!values.containsKey(key))continue; final p=values[key]!; p['enabled']=row['is_enabled']==true; p['all']=row['apply_to_all']==true || p['mandatory']==true; p['value']=(row['policy_value']??p['value']??'').toString(); p['user_ids']=List<String>.from((row['user_ids'] as List?)??const []); }
      final us=await db.from('erp_users').select('id,user_code,name_ar').eq('company_id',company);
      if(mounted)setState(() { users..clear()..addAll((us as List).whereType<Map<String,dynamic>>().map(Map<String,dynamic>.from)); loading=false; });
    } catch(e){if(mounted)setState(() { loading=false; error='تعذر تحميل السياسات. طبّق migration سياسات البرنامج أولاً. $e'; });}
  }
  Future<void> _save() async {
    setState(() { saving=true; error=null; message=null; });
    try { final rows=values.values.map((p)=><String,dynamic>{'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],'is_enabled':p['mandatory']==true?true:p['enabled']==true,'apply_to_all':p['mandatory']==true||p['all']==true,'user_ids':p['mandatory']==true||p['all']==true?[]:p['user_ids'],'policy_value':p['value']??''}).toList(); await db.from('erp_program_policies').upsert(rows,onConflict:'company_id,policy_key'); if(mounted)setState(() { saving=false; message='تم حفظ سياسات البرنامج.'; }); } catch(e){if(mounted)setState(() { saving=false; error='تعذر حفظ السياسات: $e'; });}
  }
  Future<void> _pickUsers(Map<String,dynamic> p) async {
    final chosen=<String>{...List<String>.from(p['user_ids'] as List)};
    final result=await showDialog<Set<String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(title:const Text('اختيار المستخدمين — F1'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>ds(() { if(chosen.length==users.length){chosen.clear();}else{chosen.addAll(users.map((u)=>(u['id']??'').toString()));} }),child:const Text('تحديد الكل / إلغاء تحديد الكل'))),Flexible(child:ListView(shrinkWrap:true,children:users.map((u){final id=(u['id']??'').toString();final name=(u['name_ar']??u['user_code']??id).toString();return CheckboxListTile(dense:true,value:chosen.contains(id),title:Text(name),onChanged:(v)=>ds(() { if(v==true){chosen.add(id);}else{chosen.remove(id);} }));}).toList()))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,chosen),child:const Text('حفظ'))])));
    if(result!=null&&mounted)setState(() { p['user_ids']=result.toList(); p['all']=false; });
  }

  String policySearch = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = policySearch.trim().toLowerCase();
    final list = values.values.where((p) {
      if (tab == 0 || p['category'] != tabs[tab]) return false;
      if (query.isEmpty) return true;
      final ar = (p['ar'] ?? '').toString().toLowerCase();
      final en = (p['en'] ?? '').toString().toLowerCase();
      final key = (p['key'] ?? '').toString().toLowerCase();
      return ar.contains(query) || en.contains(query) || key.contains(query);
    }).toList();

    return Column(children: [
      Container(
        color: const Color(0xFF3E007D),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          const Icon(Icons.policy_outlined, color: Color(0xFFFFA015), size: 23),
          const SizedBox(width: 6),
          const Expanded(child: Text('سياسات البرنامج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
          if (tab == 0) ...[
            SizedBox(height: 30, child: FilledButton.tonalIcon(
              onPressed: loading ? null : () => _identityKey.currentState?._startEditing(),
              icon: const Icon(Icons.edit, size: 15), label: const Text('تعديل', style: TextStyle(fontSize: 11)),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
            )),
            const SizedBox(width: 4),
          ],
          SizedBox(width: 190, height: 30, child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 11),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => policySearch = v),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السياسة...',
              hintStyle: const TextStyle(fontSize: 10),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
              isDense: true,
            ),
          )),
          const SizedBox(width: 3),
          SizedBox(height: 30, child: FilledButton.tonalIcon(
            onPressed: () => setState(() => policySearch = _searchController.text),
            icon: const Icon(Icons.search, size: 15),
            label: const Text('بحث', style: TextStyle(fontSize: 11)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
          )),
          TextButton.icon(onPressed: loading ? null : () { if (tab == 0) { _identityKey.currentState?._load(); } else { _load(); } }, icon: const Icon(Icons.refresh, color: Colors.white, size: 17), label: const Text('تحديث', style: TextStyle(color: Colors.white))),
          FilledButton.icon(onPressed: saving || (tab == 0 && (_identityKey.currentState?._saving ?? false)) ? null : () { if (tab == 0) { _identityKey.currentState?._save(); } else { _save(); } }, icon: const Icon(Icons.save, size: 17), label: Text(saving || (tab == 0 && (_identityKey.currentState?._saving ?? false)) ? 'جارٍ الحفظ' : 'حفظ')),
        ]),
      ),
      if (error != null) Padding(padding: const EdgeInsets.all(4), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 11))),
      if (message != null) Padding(padding: const EdgeInsets.all(4), child: Text(message!, style: const TextStyle(color: Colors.green, fontSize: 11))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(tabs.length, (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: ChoiceChip(label: Text(tabs[i]), selected: tab == i, onSelected: (_) => setState(() => tab = i), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      )))),
      Expanded(
        child: tab == 0
            ? ErpVisualIdentityPolicyScreen(key: _identityKey, companyId: widget.companyId)
            : loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(child: Text(query.isEmpty ? 'لا توجد سياسات في هذه المجموعة.' : 'لا توجد سياسات تطابق البحث.', style: const TextStyle(fontSize: 12)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(5, 1, 5, 3),
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                            elevation: 0, color: const Color(0xFFF5EFFB),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: const [
                                SizedBox(width: 34, child: Text('م', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 82, child: Text('كود السياسة', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 225, child: Text('بيانات السياسة', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 220, child: Text('القيمة / الاختيار', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 50, child: Text('تفعيل', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 58, child: Text('على الكل', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 62, child: Text('مستخدمون', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 112, child: Text('اختيار مستخدمين', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 58, child: Text('عدد المحدد', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              ])),
                            ),
                          ),
                          ...List.generate(list.length, (index) {
                            final p = list[index];
                            final mandatory = p['mandatory'] == true;
                            final all = p['all'] == true;
                            final options = (p['options'] as List?)?.cast<String>() ?? const <String>[];
                            final originalIndex = defaults.indexWhere((item) => item['key'] == p['key']) + 1;
                            final policyCode = 'POL' + originalIndex.toString().padLeft(3, '0');
                            Widget checkColumn(String label, bool value, ValueChanged<bool?>? onChanged, double width) => SizedBox(
                              width: width,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
                                SizedBox(height: 25, child: Checkbox(value: value, onChanged: onChanged, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                              ]),
                            );
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.16)), borderRadius: BorderRadius.circular(6)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  SizedBox(width: 34, child: Text((index + 1).toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 82, child: Text(policyCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 225, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p['ar'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text(p['en'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 9)),
                                    if (mandatory) const Text('إلزامي', style: TextStyle(color: Color(0xFF3E007D), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ])),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 220, child: p['key'] == 'fiscal_year'
                                    ? Row(children: [
                                        Expanded(child: TextFormField(
                                          key: ValueKey('fiscal-from-' + (p['value'] ?? '').toString()),
                                          initialValue: ((p['value'] ?? '01/01 - 12/31').toString().split(' - ').first),
                                          decoration: const InputDecoration(labelText: 'من', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) {
                                            final parts = (p['value'] ?? '01/01 - 12/31').toString().split(' - ');
                                            p['value'] = '${v.trim()} - ${parts.length > 1 ? parts[1] : '12/31'}';
                                          },
                                        )),
                                        const SizedBox(width: 4),
                                        Expanded(child: TextFormField(
                                          key: ValueKey('fiscal-to-' + (p['value'] ?? '').toString()),
                                          initialValue: ((p['value'] ?? '01/01 - 12/31').toString().split(' - ').length > 1 ? (p['value'] ?? '01/01 - 12/31').toString().split(' - ')[1] : '12/31'),
                                          decoration: const InputDecoration(labelText: 'إلى', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) {
                                            final parts = (p['value'] ?? '01/01 - 12/31').toString().split(' - ');
                                            p['value'] = '${parts.first} - ${v.trim()}';
                                          },
                                        )),
                                      ])
                                    : p['key'] == 'supplier_bonus_variance'
                                      ? TextFormField(
                                          key: ValueKey('variance-' + (p['value'] ?? '').toString()),
                                          initialValue: p['value']?.toString() ?? '',
                                          decoration: const InputDecoration(labelText: 'نسبة %', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) => p['value'] = v,
                                        )
                                      : options.isNotEmpty
                                        ? DropdownButtonFormField<String>(
                                            value: options.contains(p['value']) ? p['value'] as String : options.first,
                                            isExpanded: true, isDense: true,
                                            decoration: const InputDecoration(labelText: 'القيمة', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                                            items: options.map((v) => DropdownMenuItem(value: v, child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                                            onChanged: (v) => setState(() => p['value'] = v),
                                          )
                                        : Text((p['value'] ?? '').toString().isEmpty ? '—' : (p['value'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))),
                                  const SizedBox(width: 8),
                                  checkColumn('تفعيل', mandatory || p['enabled'] == true, mandatory ? null : (v) => setState(() => p['enabled'] = v == true), 50),
                                  const SizedBox(width: 8),
                                  checkColumn('على الكل', mandatory || all, mandatory ? null : (v) => setState(() { p['all'] = v == true; if (v == true) p['user_ids'] = <String>[]; }), 58),
                                  const SizedBox(width: 8),
                                  checkColumn('مستخدمون', !all, mandatory ? null : (v) => setState(() { p['all'] = v != true; if (v == true && (p['user_ids'] as List).isEmpty) p['user_ids'] = <String>[]; }), 62),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 112, height: 28, child: OutlinedButton(
                                    onPressed: mandatory || all ? null : () => _pickUsers(p),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    child: const Text('F1 اختيار مستخدمين', maxLines: 1, style: TextStyle(fontSize: 9)),
                                  )),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 58, child: Text(mandatory ? '—' : (p['user_ids'] as List).length.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
                                ])),
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    ]);
  }
}



class ErpVisualIdentityPolicyScreen extends StatefulWidget {
  const ErpVisualIdentityPolicyScreen({super.key, required this.companyId});
  final String? companyId;
  @override State<ErpVisualIdentityPolicyScreen> createState() => _ErpVisualIdentityPolicyScreenState();
}

class _ErpVisualIdentityPolicyScreenState extends State<ErpVisualIdentityPolicyScreen> {
  final _db = Supabase.instance.client;
  final _name = TextEditingController(text: 'سلسلة');
  final _primary = TextEditingController(text: '#3E007D');
  final _secondary = TextEditingController(text: '#FFA015');
  final _accent = TextEditingController(text: '#FF27C3');
  final _background = TextEditingController(text: '#FFFFFF');
  final _logo = TextEditingController();
  final _sizes = List<TextEditingController>.generate(5, (i) => TextEditingController(text: ['24','20','17','15','13'][i]));
  final _colors = List<TextEditingController>.generate(5, (i) => TextEditingController(text: ['#3E007D','#3E007D','#3E007D','#333333','#666666'][i]));
  final _labels = const ['العنوان الرئيسي','العنوان الفرعي الأول','العنوان الفرعي الثاني','العنوان الفرعي الثالث','النص والعناوين الصغيرة'];
  final _fontOptions = const ['Tajawal','Kufam','Romman','Almarai','Noto Sans Arabic','Arial','Roboto'];
  final _fonts = List<String>.filled(5, 'Tajawal');
  final _bold = List<bool>.filled(5, false);
  final _italic = List<bool>.filled(5, false);
  final _underline = List<bool>.filled(5, false);
  String _language = 'ar';
  String? _logoBase64, _logoMime;
  bool _loading = true, _saving = false, _editing = false;
  String? _error, _message;
  String get _company => (widget.companyId ?? '').trim();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _name.dispose(); _primary.dispose(); _secondary.dispose(); _accent.dispose(); _background.dispose(); _logo.dispose(); for (final c in _sizes) { c.dispose(); } for (final c in _colors) { c.dispose(); } super.dispose(); }

  Future<void> _load() async {
    if (_company.isEmpty) { setState(() { _loading = false; _error = 'اختر الشركة أولًا.'; }); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final row = await _db.from('erp_program_settings').select().eq('company_id', _company).maybeSingle();
      if (row != null) {
        _name.text = (row['program_name'] ?? 'سلسلة').toString();
        _language = (row['language_code'] ?? 'ar').toString();
        _primary.text = (row['identity_primary_color'] ?? '#3E007D').toString();
        _secondary.text = (row['identity_secondary_color'] ?? '#FFA015').toString();
        _accent.text = (row['identity_accent_color'] ?? '#FF27C3').toString();
        _background.text = (row['identity_background_color'] ?? '#FFFFFF').toString();
        _logoBase64 = row['logo_base64']?.toString(); _logoMime = row['logo_mime_type']?.toString();
        final styles = row['heading_styles'];
        if (styles is List) {
          for (var i = 0; i < 5 && i < styles.length; i++) {
            if (styles[i] is Map) {
              final s = Map<String,dynamic>.from(styles[i] as Map);
              _sizes[i].text = (s['size'] ?? _sizes[i].text).toString();
              _colors[i].text = (s['color'] ?? _colors[i].text).toString();
              final font = (s['font'] ?? 'Tajawal').toString();
              _fonts[i] = _fontOptions.contains(font) ? font : 'Tajawal';
              _bold[i] = s['bold'] == true; _italic[i] = s['italic'] == true; _underline[i] = s['underline'] == true;
            }
          }
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) { if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل بيانات الهوية البصرية: $e'; }); }
  }

  Future<void> _pickLogo() async {
    if (!_editing) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر قراءة الصورة.');
      if (bytes.length > 1024 * 1024) throw ArgumentError('حجم الشعار يجب ألا يتجاوز 1 ميجابايت.');
      final ext = (file.extension ?? '').toLowerCase();
      final mime = {'png':'image/png','jpg':'image/jpeg','jpeg':'image/jpeg','webp':'image/webp'}[ext];
      if (mime == null) throw ArgumentError('الصيغ المدعومة PNG وJPG وWEBP.');
      setState(() { _logoBase64 = base64Encode(bytes); _logoMime = mime; _message = 'تم اختيار الشعار؛ احفظ التغييرات لتثبيته.'; });
    } catch (e) { if (mounted) setState(() => _error = 'تعذر اختيار الشعار: $e'); }
  }

  void _startEditing() { if (mounted && !_editing) setState(() { _editing = true; _error = null; _message = null; }); }

  Future<void> _save() async {
    if (!_editing) { setState(() => _message = 'اضغط تعديل أولًا.'); return; }
    if (_company.isEmpty) return;
    final colors = [_primary.text,_secondary.text,_accent.text,_background.text,..._colors.map((c) => c.text)];
    if (colors.any((v) => !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(v.trim()))) {
      setState(() => _error = 'أدخل الألوان بصيغة HEX صحيحة مثل #3E007D.'); return;
    }
    for (var i = 0; i < 5; i++) {
      final size = double.tryParse(_sizes[i].text.trim());
      if (size == null || size < 8 || size > 72) { setState(() => _error = 'حجم الخط يجب أن يكون من 8 إلى 72.'); return; }
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final existing = await _db.from('erp_program_settings').select('program_name,language_code').eq('company_id', _company).maybeSingle();
      final styles = List.generate(5, (i) => {'key':'heading_${i+1}','label':_labels[i],'font':_fonts[i],'size':double.parse(_sizes[i].text.trim()),'color':_colors[i].text.trim().toUpperCase(),'bold':_bold[i],'italic':_italic[i],'underline':_underline[i]});
      await _db.from('erp_program_settings').upsert({
        'company_id':_company,
        'program_name':_name.text.trim().isEmpty ? (existing?['program_name'] ?? 'سلسلة') : _name.text.trim(),
        'language_code':_language,
        'logo_base64':_logoBase64,'logo_mime_type':_logoMime,
        'identity_primary_color':_primary.text.trim().toUpperCase(),
        'identity_secondary_color':_secondary.text.trim().toUpperCase(),
        'identity_accent_color':_accent.text.trim().toUpperCase(),
        'identity_background_color':_background.text.trim().toUpperCase(),
        'heading_styles':styles,'updated_at':DateTime.now().toUtc().toIso8601String(),'updated_by':_db.auth.currentUser?.id,
      }, onConflict:'company_id');
      if (mounted) setState(() { _saving = false; _editing = false; _message = 'تم حفظ إعدادات الهوية البصرية.'; });
    } catch (e) { if (mounted) setState(() { _saving = false; _error = 'تعذر الحفظ: $e'; }); }
  }

  Color _colorFromHex(String value) {
    final hex = value.trim().replaceFirst('#', '');
    try {
      final normalized = hex.length == 6 ? 'FF$hex' : hex;
      return Color(int.parse(normalized, radix: 16));
    } catch (_) {
      return const Color(0xFFBDBDBD);
    }
  }

  Future<void> _chooseColor(TextEditingController controller) async {
    if (!_editing) return;
    const swatches = <Color>[
      Color(0xFF3E007D), Color(0xFF5E35B1), Color(0xFF7E57C2), Color(0xFF9575CD),
      Color(0xFFFFA015), Color(0xFFFF8F00), Color(0xFFFF5722), Color(0xFFE53935),
      Color(0xFFFF27C3), Color(0xFFD81B60), Color(0xFF8E24AA), Color(0xFF3949AB),
      Color(0xFF039BE5), Color(0xFF00897B), Color(0xFF43A047), Color(0xFF7CB342),
      Color(0xFF795548), Color(0xFF616161), Color(0xFF333333), Color(0xFF666666),
      Color(0xFF999999), Color(0xFFCCCCCC), Color(0xFFF5EFFB), Color(0xFFFFFFFF),
    ];
    final selected = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختيار اللون'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: swatches.map((color) => InkWell(
              onTap: () => Navigator.pop(ctx, color),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
                child: _colorFromHex(controller.text).toARGB32() == color.toARGB32()
                    ? Icon(Icons.check, size: 17, color: color.computeLuminance() < .45 ? Colors.white : Colors.black87)
                    : null,
              ),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء'))],
      ),
    );
    if (selected != null && mounted) {
      setState(() => controller.text = '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
    }
  }

  Widget _colorField(TextEditingController controller, {double width = 145}) => SizedBox(
    width: width,
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: _editing,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 10),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 3),
        SizedBox(
          width: 28,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'لوحة الألوان',
            onPressed: _editing ? () => _chooseColor(controller) : null,
            icon: const Icon(Icons.palette_outlined, size: 18),
          ),
        ),
        Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: _colorFromHex(controller.text),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
      ],
    ),
  );

  Widget _field(TextEditingController c, {double width = 150, String? hint}) => SizedBox(width: width, child: TextField(controller: c, enabled: _editing, style: const TextStyle(fontSize: 11), decoration: InputDecoration(isDense: true, hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), border: const OutlineInputBorder())));
  Widget _row(int index, String code, String title, Widget value, {Widget extra = const SizedBox(width: 1)}) => Card(
    margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1), elevation: 0,
    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.deepPurple.withValues(alpha: .16)), borderRadius: BorderRadius.circular(6)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        SizedBox(width: 38, child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
        const SizedBox(width: 8), SizedBox(width: 95, child: Text(code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8), SizedBox(width: 230, child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8), SizedBox(width: 150, child: value),
        const SizedBox(width: 8), SizedBox(width: 230, child: extra),
      ]))),
  );

  @override Widget build(BuildContext context) {
    final rows = <Widget>[
      _row(0,'VIS001','اسم البرنامج',_field(_name,width:190,hint:'سلسلة')),
      _row(1,'VIS002','لغة واجهة البرنامج',SizedBox(width:190,child:DropdownButtonFormField<String>(value:_language,isExpanded:true,isDense:true,itemHeight:34,menuMaxHeight:260,decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:5),border:OutlineInputBorder()),items:const[DropdownMenuItem(value:'ar',child:Text('العربية')),DropdownMenuItem(value:'en',child:Text('English'))],onChanged:_editing?(v){if(v!=null)setState(()=>_language=v);}:null))),
      _row(2,'VIS003','شعار البرنامج',Row(children:[if(_logoBase64!=null) const Icon(Icons.image,color:Color(0xFF3E007D)),OutlinedButton(onPressed:_editing?_pickLogo:null,child:const Text('اختيار صورة')),if(_logoBase64!=null)IconButton(onPressed:_editing?()=>setState(()=>_logoBase64=null):null,icon:const Icon(Icons.delete_outline,color:Colors.red))])),
      _row(3,'VIS004','اللون الأساسي',_colorField(_primary)),
      _row(4,'VIS005','اللون الثانوي',_colorField(_secondary)),
      _row(5,'VIS006','لون التمييز',_colorField(_accent)),
      _row(6,'VIS007','لون الخلفية',_colorField(_background)),
    ];
    for (var i=0;i<5;i++) {
      rows.add(_row(7+i,'VIS${(i+8).toString().padLeft(3,'0')}','${_labels[i]} — الخط / الحجم / اللون',
        SizedBox(width:125,child:DropdownButtonFormField<String>(value:_fonts[i],isExpanded:true,isDense:true,itemHeight:34,menuMaxHeight:260,decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:3),border:OutlineInputBorder()),items:_fontOptions.map((f)=>DropdownMenuItem(value:f,child:Text(f,style:const TextStyle(fontSize:10),overflow:TextOverflow.ellipsis))).toList(),onChanged:_editing?(v){if(v!=null)setState(()=>_fonts[i]=v);}:null)),
        extra: Row(children:[SizedBox(width:48,height:36,child:TextField(controller:_sizes[i],enabled:_editing,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,labelText:'حجم',contentPadding:EdgeInsets.symmetric(horizontal:3,vertical:4),border:OutlineInputBorder()),style:const TextStyle(fontSize:10))),const SizedBox(width:4),_colorField(_colors[i],width:155)])));
    }
    return Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:3),child:Row(children:[
        const Expanded(child:Text('سياسات الهوية البصرية',style:TextStyle(fontWeight:FontWeight.bold,fontSize:14,color:Color(0xFF3E007D)))),
      ])),
      if(_error!=null) Padding(padding:const EdgeInsets.all(4),child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:11))),
      if(_message!=null) Padding(padding:const EdgeInsets.all(4),child:Text(_message!,style:const TextStyle(color:Colors.green,fontSize:11))),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.fromLTRB(5,1,5,3),children:[
        Card(elevation:0,color:const Color(0xFFF5EFFB),child:Padding(padding:const EdgeInsets.symmetric(horizontal:5,vertical:4),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:const [
          SizedBox(width:38,child:Text('م',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),SizedBox(width:8),
          SizedBox(width:95,child:Text('كود السياسة',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),SizedBox(width:8),
          SizedBox(width:230,child:Text('بيانات السياسة',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),SizedBox(width:8),
          SizedBox(width:150,child:Text('نوع الخط',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),SizedBox(width:8),
          SizedBox(width:230,child:Text('الحجم / اللون المختار',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
        ])))),
        ...rows,
        const SizedBox(height:10),
        Card(
          elevation:0,
          color:const Color(0xFFF5EFFB),
          shape:RoundedRectangleBorder(
            side:const BorderSide(color:Color(0xFFE2D5F0)),
            borderRadius:BorderRadius.circular(10),
          ),
          child:Padding(
            padding:const EdgeInsets.all(12),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:const [
                Row(children:[
                  Icon(Icons.rule_folder_outlined,color:Color(0xFF3E007D),size:20),
                  SizedBox(width:7),
                  Expanded(child:Text('معيار التخطيط والمسافات الموحد — معتمد لكل شاشات سلسلة',
                    style:TextStyle(fontWeight:FontWeight.w900,fontSize:13,color:Color(0xFF3E007D)))),
                ]),
                SizedBox(height:8),
                Text('1) بين الحقول والأعمدة المرتبطة: 12–16 بكسل، والقيمة الافتراضية 14 بكسل.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('2) بين مجموعات البيانات المستقلة: 24–32 بكسل.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('3) بين الأقسام الرئيسية: 32–40 بكسل.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('4) لا تُستخدم مسافة 50 بكسل بين كل عمودين؛ تُقبل فقط كحد أعلى عند الحاجة للفصل البصري بين مجموعات مستقلة.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('5) الجداول: تقارب مريح دون تزاحم، مع هوامش داخلية واضحة وارتفاع صفوف يسمح بقراءة البيانات.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('6) العربية: ممنوع تقطيع الكلمة أو عرض الحروف رأسيًا؛ يسمح بالتفاف النص بين الكلمات، مع توسيع العمود أو التمرير الأفقي عند الحاجة.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('7) الشاشات الصغيرة: إعادة توزيع العناصر أو استخدام قوائم/بطاقات وتمرير أفقي منظم، دون تصغير النص إلى درجة تضر القراءة.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('8) ارتفاع صفوف الجداول القياسي 48–64 بكسل؛ وتُقبل الصفوف الأقصر فقط في الجداول الرقمية الكثيفة أو المعاينات المحدودة.',
                  style:TextStyle(fontSize:11,height:1.5)),
                Text('9) الاتساق: تُطبق القواعد عبر ثيم البرنامج العام، وتُوثق الاستثناءات فقط عندما تفرض طبيعة البيانات ذلك.',
                  style:TextStyle(fontSize:11,height:1.5)),
              ],
            ),
          ),
        ),
      ])),
    ]);
  }
}
