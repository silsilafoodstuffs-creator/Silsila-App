import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _currencyPurple = Color(0xFF3E007D);
const _currencyOrange = Color(0xFFFFA015);

class ErpCurrenciesScreen extends StatefulWidget {
  const ErpCurrenciesScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpCurrenciesScreen> createState() => _ErpCurrenciesScreenState();
}

class _ErpCurrenciesScreenState extends State<ErpCurrenciesScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  SupabaseClient? _db;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _saving = false, _editing = false;
  String? _error, _editingId;

  @override
  void initState() { super.initState(); try { _db = Supabase.instance.client; } catch (_) {} _load(); }
  @override
  void didUpdateWidget(covariant ErpCurrenciesScreen oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.companyId != widget.companyId) _load(); }
  @override
  void dispose() { _code.dispose(); _name.dispose(); _symbol.dispose(); super.dispose(); }

  Future<void> _load() async {
    final company = (widget.companyId ?? '').trim();
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    if (company.isEmpty || _db == null) { setState(() { _loading = false; _error = 'اختر الشركة أولاً وتأكد من الاتصال بقاعدة البيانات.'; }); return; }
    try {
      final data = await _db!.from('erp_currencies').select('id,currency_code,currency_name_ar,currency_symbol,is_active').eq('company_id', company).order('currency_code');
      if (!mounted) return;
      setState(() { _rows = List<Map<String,dynamic>>.from(data); _loading = false; });
    } catch (e) { if (!mounted) return; setState(() { _loading = false; _error = 'تعذر تحميل العملات. تأكد من تطبيق ملف SQL الخاص بالعملات. $e'; }); }
  }

  void _clear() { _editingId = null; _editing = false; _code.clear(); _name.clear(); _symbol.clear(); }
  void _startNew() { setState(() { _clear(); _editing = true; _error = null; }); }
  void _edit(Map<String,dynamic> row) { setState(() { _editing = true; _editingId = row['id'].toString(); _code.text = (row['currency_code'] ?? '').toString(); _name.text = (row['currency_name_ar'] ?? '').toString(); _symbol.text = (row['currency_symbol'] ?? '').toString(); _error = null; }); }

  Future<void> _save() async {
    if (!_editing) { setState(() => _error = 'اضغط «تعديل» أو «إضافة جديد» أولًا قبل تغيير البيانات.'); return; }
    final company = (widget.companyId ?? '').trim();
    final code = _code.text.trim().toUpperCase(), name = _name.text.trim(), symbol = _symbol.text.trim();
    if (company.isEmpty || _db == null) { setState(() => _error = 'لا توجد شركة محددة أو اتصال بقاعدة البيانات.'); return; }
    if (code.isEmpty || name.isEmpty || symbol.isEmpty) { setState(() => _error = 'أكمل كود العملة واسمها العربي واختصارها الإنجليزي.'); return; }
    if (!RegExp(r'^[A-Z0-9]{2,12}$').hasMatch(code)) { setState(() => _error = 'كود العملة يقبل حروفًا إنجليزية كبيرة وأرقامًا فقط.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final payload = {'currency_code': code, 'currency_name_ar': name, 'currency_symbol': symbol, 'updated_at': DateTime.now().toUtc().toIso8601String()};
      if (_editingId == null) { await _db!.from('erp_currencies').insert({...payload, 'company_id': company}); }
      else { await _db!.from('erp_currencies').update(payload).eq('id', _editingId!).eq('company_id', company); }
      if (!mounted) return;
      setState(() { _saving = false; _clear(); });
      await _load();
    } catch (e) { if (!mounted) return; setState(() { _saving = false; _error = 'تعذر حفظ العملة. قد يكون الكود مستخدمًا بالفعل. $e'; }); }
  }

  Future<void> _toggleActive(Map<String,dynamic> row) async {
    if (!_editing) { setState(() => _error = 'اضغط «تعديل» أولًا قبل تغيير حالة العملة.'); return; }
    final company = (widget.companyId ?? '').trim(), next = row['is_active'] != true;
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(next ? 'تفعيل العملة' : 'إيقاف العملة'),
      content: Text(next ? 'هل تريد تفعيل هذه العملة؟' : 'ستختفي من قوائم الاختيار الجديدة مع الاحتفاظ بالسجلات السابقة. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('تأكيد'))],
    ));
    if (yes != true || _db == null) return;
    try { await _db!.from('erp_currencies').update({'is_active':next}).eq('id',row['id'].toString()).eq('company_id',company); await _load(); }
    catch(e) { if(mounted) setState(()=>_error='تعذر تحديث حالة العملة: $e'); }
  }

  Widget _input(TextEditingController c, String label) => TextField(controller:c, enabled:_editing, style:const TextStyle(fontSize:14), decoration:InputDecoration(labelText:label,isDense:true,constraints:const BoxConstraints(minHeight:52),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10))));
  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewCurrencies() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة دليل العملات'),
      content: SizedBox(width: 620, child: _rows.isEmpty ? const Text('لا توجد عملات مسجلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _rows.map((r) => ListTile(
          dense: true, title: Text('${r['currency_code'] ?? ''} — ${r['currency_name_ar'] ?? ''}'),
          subtitle: Text('الاختصار: ${r['currency_symbol'] ?? ''} • ${r['is_active'] == true ? 'نشطة' : 'موقوفة'}'),
          trailing: IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined), onPressed: () { Navigator.pop(ctx); _edit(r); }),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => ErpKeyboardActionRegistrar(add: _startNew, save: _save, child: Directionality(textDirection:TextDirection.rtl,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(color:_currencyPurple,child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Row(children:[Icon(Icons.currency_exchange_rounded,color:_currencyOrange,size:28),SizedBox(width:10),Expanded(child:Text('دليل العملات',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:Colors.white)))]),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        _quickTask('تحديث',Icons.refresh_rounded,Colors.blue,_loading?null:_load),
        _quickTask(_editing?'حفظ':'إضافة جديد',_editing?Icons.save_outlined:Icons.add_circle_outline,const Color(0xFF168447),_saving?null:(_editing?_save:_startNew)),
        _quickTask('تعديل',Icons.edit_outlined,const Color(0xFFEF9B13),_saving || _editing || _rows.isEmpty?null:()=>_edit(_rows.first)),
        _quickTask('تفعيل/إيقاف',Icons.toggle_on_outlined,const Color(0xFFEF9B13),_editing && _rows.isNotEmpty?()=>_toggleActive(_rows.first):null),
        _quickTask('معاينة',Icons.visibility_outlined,const Color(0xFF6841A5),_previewCurrencies),
        _quickTask('طباعة',Icons.print_outlined,const Color(0xFF4056A1),_previewCurrencies),
        _quickTask('استيراد Excel',Icons.file_upload_outlined,const Color(0xFF137C8B),()=>setState(()=>_error='استيراد العملات من Excel غير مفعّل بعد؛ يمكنك إضافة العملات من النموذج.')),
        _quickTask('طباعة PDF',Icons.picture_as_pdf_outlined,const Color(0xFFB3261E),_previewCurrencies),
      ])),
    ]))),
    const SizedBox(height:16),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Row(children:[Expanded(flex:2,child:_input(_code,'كود')),const SizedBox(width:10),Expanded(flex:3,child:_input(_name,'اسم العملة عربي')),const SizedBox(width:10),Expanded(flex:2,child:_input(_symbol,'مختصر العملة إنجليزي'))]),
      const SizedBox(height:12),Row(children:[FilledButton.icon(onPressed:_saving || !_editing?null:_save,icon:Icon(_editingId==null?Icons.add_rounded:Icons.save_rounded),label:Text(_saving?'جارٍ الحفظ...':_editingId==null?'إضافة عملة':'حفظ التعديل')),const SizedBox(width:8),OutlinedButton.icon(onPressed: () { setState(() { _clear(); _error = null; }); },icon:const Icon(Icons.clear_rounded),label:const Text('تفريغ'))]),
      if(_error!=null) ...[const SizedBox(height:10),Align(alignment:Alignment.centerRight,child:Text(_error!,style:const TextStyle(color:Colors.red)))],
    ]))),
    const SizedBox(height:12),
    Expanded(child:_loading?const Center(child:CircularProgressIndicator()):_rows.isEmpty?Center(child:Text(_error??'لا توجد عملات مسجلة حتى الآن. أضف أول عملة من النموذج أعلاه.',textAlign:TextAlign.center)):SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(headingRowColor:WidgetStateProperty.all(const Color(0xFFF3EFF8)),columns:const[DataColumn(label:Text('م')),DataColumn(label:Text('كود')),DataColumn(label:Text('اسم العملة عربي')),DataColumn(label:Text('مختصر العملة إنجليزي')),DataColumn(label:Text('الحالة')),DataColumn(label:Text('الإجراءات'))],rows:[for(var i=0;i<_rows.length;i++) DataRow(cells:[DataCell(Text('${i+1}')),DataCell(Text((_rows[i]['currency_code']??'').toString())),DataCell(Text((_rows[i]['currency_name_ar']??'').toString())),DataCell(Text((_rows[i]['currency_symbol']??'').toString())),DataCell(Text(_rows[i]['is_active']==true?'نشطة':'موقوفة')),DataCell(Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'تعديل',onPressed:()=>_edit(_rows[i]),icon:const Icon(Icons.edit_outlined,color:_currencyPurple)),IconButton(tooltip:'تفعيل أو إيقاف',onPressed:_editing?()=>_toggleActive(_rows[i]):null,icon:Icon(_rows[i]['is_active']==true?Icons.toggle_on_rounded:Icons.toggle_off_rounded,color:_currencyOrange,size:28))]))])]))),
  ]))));
}
