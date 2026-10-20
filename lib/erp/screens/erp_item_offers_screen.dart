import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/erp_inventory_master_repository.dart';
import '../services/erp_parties_repository.dart';
import '../services/erp_workspace_records_service.dart';

class ErpItemOffersScreen extends StatefulWidget {
  const ErpItemOffersScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpItemOffersScreen> createState() => _ErpItemOffersScreenState();
}

class _ErpItemOffersScreenState extends State<ErpItemOffersScreen> {
  final _records = ErpWorkspaceRecordsService();
  final _inventory = ErpInventoryMasterRepository();
  final _partiesRepo = ErpPartiesRepository();
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _discount = TextEditingController(text: '0');
  DateTime _from = DateTime.now(), _to = DateTime.now().add(const Duration(days: 7));
  String _offerType = 'خصم نسبة';
  String _customerScope = 'كل العملاء';
  String _warehouseScope = 'كل المخازن';
  String? _groupId;
  bool _loading = false, _saving = false;
  String? _error, _message;
  List<Map<String,dynamic>> _items = [], _groups = [], _parties = [], _warehouses = [];
  final Set<String> _selectedCustomers = {}, _selectedWarehouses = {}, _governorates = {}, _centers = {}, _areas = {};
  final List<Map<String,dynamic>> _offerLines = [];
  List<Map<String,dynamic>> get _visibleItems {
    final q = _search.text.trim().toLowerCase();
    return _items.where((i) {
      final matchesQuery = q.isEmpty || ['item_code','barcode','item_name'].any((k) => (i[k] ?? '').toString().toLowerCase().contains(q));
      return matchesQuery && (_groupId == null || (i['group_id'] ?? '').toString() == _groupId);
    }).toList();
  }
  String _s(dynamic v) => (v ?? '').toString();
  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _name.dispose(); _search.dispose(); _qty.dispose(); _discount.dispose(); super.dispose(); }
  Future<void> _load() async {
    final company = widget.companyId;
    if (company == null || company.isEmpty) { setState(() => _error = 'اربط الشاشة بشركة نشطة أولًا.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        _inventory.fetchItems(company), _inventory.fetchGroups(company), _inventory.fetchWarehouses(company), _partiesRepo.fetchParties(company, kind: 'customer'),
        _records.listPage(companyId: company, pageKey: 'عروض الأصناف'),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (values[0] as List).cast<Map<String,dynamic>>();
        _groups = (values[1] as List).cast<Map<String,dynamic>>();
        _warehouses = (values[2] as List).cast<Map<String,dynamic>>();
        _parties = (values[3] as List).cast<Map<String,dynamic>>();
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل بيانات العروض: $e'; }); }
  }
  Future<void> _chooseDate(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: start ? _from : _to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (selected != null) setState(() { if (start) { _from = selected; if (_to.isBefore(_from)) _to = _from; } else { _to = selected; if (_to.isBefore(_from)) _from = _to; } });
  }
  Future<void> _pickMulti({required String title, required List<Map<String,dynamic>> options, required String idKey, required String labelKey, required Set<String> selected}) async {
    final draft = Set<String>.from(selected);
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text(title, textDirection: TextDirection.rtl),
      content: SizedBox(width: 520, height: 420, child: ListView(children: options.map((r) {
        final id = _s(r[idKey]); final label = _s(r[labelKey]);
        return CheckboxListTile(value: draft.contains(id), title: Text(label, textDirection: TextDirection.rtl), onChanged: (v) => refresh(() { v == true ? draft.add(id) : draft.remove(id); }));
      }).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { setState(() { selected..clear()..addAll(draft); }); Navigator.pop(ctx); }, child: const Text('تطبيق الاختيار'))],
    )));
  }
  Future<void> _pickProducts() async {
    final chosen = <String>{};
    final search = TextEditingController();
    String? group = _groupId;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
      final q = search.text.trim().toLowerCase();
      final list = _items.where((i) => (group == null || _s(i['group_id']) == group) && (q.isEmpty || _s(i['item_name']).toLowerCase().contains(q) || _s(i['item_code']).toLowerCase().contains(q) || _s(i['barcode']).toLowerCase().contains(q))).toList();
      return AlertDialog(title: const Text('جلب الأصناف — اختيار متعدد'),
        content: SizedBox(width: 760, height: 560, child: Column(children: [
          Row(children: [Expanded(child: TextField(controller: search, onChanged: (_) => refresh(() {}), decoration: const InputDecoration(labelText: 'بحث بالاسم أو الكود أو الباركود'))), const SizedBox(width: 8), DropdownButton<String?>(value: group, hint: const Text('كل الفئات'), items: [const DropdownMenuItem<String?>(value: null, child: Text('كل الفئات')), ..._groups.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text(_s(g['group_name']))))], onChanged: (v) => refresh(() => group = v))]),
          Align(alignment: Alignment.centerRight, child: Wrap(spacing: 8, children: [TextButton(onPressed: () => refresh(() => chosen.addAll(list.map((e) => _s(e['id'])))), child: const Text('تحديد الظاهر')), TextButton(onPressed: () => refresh(() => chosen.clear()), child: const Text('إلغاء التحديد'))])),
          Expanded(child: ListView(children: list.map((item) => CheckboxListTile(value: chosen.contains(_s(item['id'])), title: Text('${_s(item['item_code'])} — ${_s(item['item_name'])}', textDirection: TextDirection.rtl), subtitle: Text('سعر البيع: ${_s(item['sale_price'])} | الوحدة: ${_s(item['base_unit'])}'), onChanged: (v) => refresh(() { v == true ? chosen.add(_s(item['id'])) : chosen.remove(_s(item['id'])); }))).toList())),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () {
          setState(() {
            for (final id in chosen) {
              if (_offerLines.any((l) => _s(l['item_id']) == id)) continue;
              final item = _items.firstWhere((i) => _s(i['id']) == id);
              _offerLines.add({'item_id':id,'item_code':_s(item['item_code']),'item_name':_s(item['item_name']),'unit':_s(item['base_unit']),'sale_price':item['sale_price'] ?? 0,'offer_qty':1,'remaining_qty':1,'discount':0});
            }
          }); Navigator.pop(ctx);
        }, child: const Text('إضافة الأصناف المحددة'))],
      );
    }));
    search.dispose();
  }
  Future<void> _save() async {
    final company = widget.companyId;
    if (company == null || company.isEmpty) { setState(() => _error = 'لا توجد شركة نشطة.'); return; }
    if (_name.text.trim().isEmpty || _offerLines.isEmpty) { setState(() => _error = 'أدخل اسم العرض واختر صنفًا واحدًا على الأقل.'); return; }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final data = <String,String>{
        'اسم العرض':_name.text.trim(), 'نوع العرض':_offerType, 'من تاريخ':_date(_from), 'إلى تاريخ':_date(_to),
        'نطاق العملاء':_customerScope, 'العملاء المحددون':_selectedCustomers.join(','), 'نطاق المخازن':_warehouseScope,
        'المخازن المحددة':_selectedWarehouses.join(','), 'المحافظات':_governorates.join(','), 'المراكز':_centers.join(','), 'المناطق':_areas.join(','),
        'بنود العرض':_offerLines.map((l) => '${_s(l['item_id'])}~${_s(l['item_code'])}~${_s(l['item_name'])}~${_s(l['offer_qty'])}~${_s(l['remaining_qty'])}~${_s(l['discount'])}').join('|'),
        'حالة العرض':_offerLines.every((l) => (double.tryParse(_s(l['remaining_qty'])) ?? 0) <= 0) ? 'منتهي' : 'نشط'
      };
      await _records.saveRecord(companyId: company, pageKey: 'عروض الأصناف', record: data);
      if (mounted) setState(() { _saving = false; _message = 'تم حفظ إعدادات العرض في قاعدة البيانات. يتم تتبع الكمية المتبقية داخل العرض.'; });
    } catch (e) { if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ العرض: $e'; }); }
  }
  Widget _field(String label, Widget child) => Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 5), child]));
  InputDecoration _dec(String label) => InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10));
  @override Widget build(BuildContext context) {
    return Shortcuts(shortcuts: <LogicalKeySet, Intent>{LogicalKeySet(LogicalKeyboardKey.f1): const ActivateIntent()}, child: Actions(actions: <Type, Action<Intent>>{ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _pickProducts(); return null; })}, child: Directionality(textDirection: TextDirection.rtl, child: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [const Icon(Icons.local_offer, color: Color(0xFF3E007D)), const SizedBox(width: 8), const Expanded(child: Text('عروض الأصناف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('تحديث'))]),
      const SizedBox(height: 8), if (_error != null) _notice(_error!, true), if (_message != null) _notice(_message!, false),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Row(children: [Expanded(child: _field('اسم العرض', TextField(controller: _name, decoration: _dec('مثال: عرض نهاية الأسبوع')))), Expanded(child: _field('نوع العرض', DropdownButtonFormField<String>(value: _offerType, decoration: _dec('نوع العرض'), items: ['خصم نسبة','خصم قيمة','سعر عرض','اشترِ كمية واحصل على كمية','عرض تصفية'].map((e) => DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged:(v)=>setState(()=>_offerType=v??_offerType))))]),
        Row(children: [Expanded(child: _field('بداية العرض', OutlinedButton.icon(onPressed:()=>_chooseDate(true), icon:const Icon(Icons.calendar_month), label:Text(_date(_from)))), Expanded(child: _field('نهاية العرض', OutlinedButton.icon(onPressed:()=>_chooseDate(false), icon:const Icon(Icons.event_busy), label:Text(_date(_to)))))]),
        const Divider(), Align(alignment: Alignment.centerRight, child: Text('نطاق تطبيق العرض', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E007D)))),
        Row(children: [Expanded(child: _field('العملاء', DropdownButtonFormField<String>(value:_customerScope, decoration:_dec('تطبيق على'), items:['كل العملاء','تصنيف عميل','عملاء محددون','حسب المنطقة الجغرافية'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged:(v)=>setState(()=>_customerScope=v??_customerScope))),), Expanded(child: _field('المخازن والفروع', DropdownButtonFormField<String>(value:_warehouseScope, decoration:_dec('تطبيق على'), items:['كل المخازن','مخازن محددة','فروع محددة'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged:(v)=>setState(()=>_warehouseScope=v??_warehouseScope))) )]),
        Wrap(spacing:8, runSpacing:8, children: [
          OutlinedButton.icon(onPressed:()=>_pickMulti(title:'جلب العملاء', options:_parties, idKey:'id', labelKey:'party_name', selected:_selectedCustomers), icon:const Icon(Icons.people_alt), label:Text('جلب العملاء (${_selectedCustomers.length})')),
          OutlinedButton.icon(onPressed:()=>_pickMulti(title:'جلب المخازن', options:_warehouses, idKey:'id', labelKey:'warehouse_name', selected:_selectedWarehouses), icon:const Icon(Icons.warehouse), label:Text('جلب المخازن (${_selectedWarehouses.length})')),
          OutlinedButton.icon(onPressed:()=>_pickMulti(title:'المحافظات', options:_distinctOptions('governorate'), idKey:'id', labelKey:'name', selected:_governorates), icon:const Icon(Icons.map), label:Text('المحافظات (${_governorates.length})')),
          OutlinedButton.icon(onPressed:()=>_pickMulti(title:'المراكز', options:_distinctOptions('center'), idKey:'id', labelKey:'name', selected:_centers), icon:const Icon(Icons.location_city), label:Text('المراكز (${_centers.length})')),
          OutlinedButton.icon(onPressed:()=>_pickMulti(title:'المناطق', options:_distinctOptions('district'), idKey:'id', labelKey:'name', selected:_areas), icon:const Icon(Icons.place), label:Text('المناطق (${_areas.length})')),
        ]),
      ]))),
      Row(children: [Expanded(child: TextField(controller:_search, onChanged:(_)=>setState((){}), decoration:_dec('بحث الأصناف — اضغط F1 لجلب الأصناف'))), const SizedBox(width:8), FilledButton.icon(onPressed:_pickProducts, icon:const Icon(Icons.playlist_add), label:const Text('جلب الأصناف F1'))]),
      const SizedBox(height:8), Row(children: [Expanded(child: DropdownButtonFormField<String?>(value:_groupId, decoration:_dec('تصفية حسب الفئة'), items:[const DropdownMenuItem<String?>(value:null,child:Text('كل الفئات')),..._groups.map((g)=>DropdownMenuItem<String?>(value:_s(g['id']),child:Text(_s(g['group_name']))))], onChanged:(v)=>setState(()=>_groupId=v))), const SizedBox(width:8), TextButton(onPressed:()=>setState(()=>_groupId=null), child:const Text('الكل'))]),
      const SizedBox(height:8), Card(child: SingleChildScrollView(scrollDirection:Axis.horizontal, child: DataTable(columns: const [DataColumn(label:Text('كود')),DataColumn(label:Text('الصنف')),DataColumn(label:Text('الوحدة')),DataColumn(label:Text('سعر البيع')),DataColumn(label:Text('كمية العرض')),DataColumn(label:Text('المتبقي')),DataColumn(label:Text('قيمة/نسبة')),DataColumn(label:Text('حذف'))], rows:_offerLines.map((line) => DataRow(cells:[
        DataCell(Text(_s(line['item_code']))), DataCell(SizedBox(width:180, child:Text(_s(line['item_name'])))), DataCell(Text(_s(line['unit']))), DataCell(Text(_s(line['sale_price']))),
        DataCell(SizedBox(width:85, child:TextFormField(initialValue:_s(line['offer_qty']), keyboardType:TextInputType.number, decoration:_dec('الكمية'), onChanged:(v)=>setState(()=>line['offer_qty']=double.tryParse(v)??0)))),
        DataCell(SizedBox(width:85, child:TextFormField(initialValue:_s(line['remaining_qty']), keyboardType:TextInputType.number, decoration:_dec('المتبقي'), onChanged:(v)=>setState(()=>line['remaining_qty']=double.tryParse(v)??0)))),
        DataCell(SizedBox(width:85, child:TextFormField(initialValue:_s(line['discount']), keyboardType:const TextInputType.numberWithOptions(decimal:true), decoration:_dec('الخصم'), onChanged:(v)=>setState(()=>line['discount']=double.tryParse(v)??0)))),
        DataCell(IconButton(tooltip:'حذف الصنف', onPressed:()=>setState(()=>_offerLines.remove(line)), icon:const Icon(Icons.delete_forever,color:Colors.red))),
      ])).toList())),
      const SizedBox(height:10), Row(children:[Expanded(child:Text('عدد الأصناف: ${_offerLines.length} | الأصناف التي نفدت كميتها تنتهي عروضها عند وصول المتبقي إلى صفر.', style:const TextStyle(fontSize:12))), FilledButton.icon(onPressed:_saving?null:_save, icon:const Icon(Icons.save), label:Text(_saving?'جارٍ الحفظ…':'حفظ العرض'))]),
    ]))));
  }
  List<Map<String,dynamic>> _distinctOptions(String field) {
    final values = _parties.map((p)=>_s(p[field])).where((v)=>v.isNotEmpty).toSet().toList()..sort();
    return values.map((v)=>{'id':v,'name':v}).toList();
  }
  Widget _notice(String text, bool error) => Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:error?Colors.red.shade50:Colors.green.shade50,borderRadius:BorderRadius.circular(8)),child:Text(text,style:TextStyle(color:error?Colors.red.shade900:Colors.green.shade900)));
}
