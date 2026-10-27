import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/erp_inventory_master_repository.dart';
import '../services/erp_parties_repository.dart';

class ErpItemOffersScreen extends StatefulWidget {
  const ErpItemOffersScreen({super.key, required this.companyId, this.initialCampaignType, this.lockCampaignType = false});
  final String? companyId;
  final String? initialCampaignType;
  final bool lockCampaignType;
  @override
  State<ErpItemOffersScreen> createState() => _ErpItemOffersScreenState();
}

class _ErpItemOffersScreenState extends State<ErpItemOffersScreen> {
  final _inventory = ErpInventoryMasterRepository();
  final _partiesRepo = ErpPartiesRepository();
  final _name = TextEditingController();
  final _search = TextEditingController();
  DateTime _from = DateTime.now(), _to = DateTime.now().add(const Duration(days: 30));
  String _campaignType = 'customer_magazine';
  String _discountKind = 'special_price';
  String _customerScope = 'كل العملاء';
  String _warehouseScope = 'كل المخازن';
  String? _categoryId;
  bool _loading = false, _saving = false;
  String? _error, _message;
  List<Map<String,dynamic>> _items = [], _categories = [], _parties = [], _warehouses = [], _branches = [], _campaigns = [];
  final Set<String> _selectedCustomers = {}, _selectedWarehouses = {}, _selectedBranches = {}, _governorates = {}, _districts = {}, _centers = {}, _areas = {}, _customerTypes = {};
  final List<Map<String,dynamic>> _offerLines = [];
  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  @override void initState() { super.initState(); if (widget.initialCampaignType != null && const {'customer_magazine','promotion','slow_moving'}.contains(widget.initialCampaignType)) _campaignType = widget.initialCampaignType!; _load(); }
  @override void dispose() { _name.dispose(); _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    final company = widget.companyId;
    if (company == null || company.isEmpty) { setState(() => _error = 'اربط الشاشة بشركة نشطة أولًا.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        _inventory.fetchItems(company), _inventory.fetchCategories(company), _inventory.fetchWarehouses(company), _inventory.fetchBranches(company),
        _partiesRepo.fetchParties(company, kind: 'customer'),
        _db!.from('erp_sales_campaigns').select('id,title,campaign_type,start_date,end_date,is_active').eq('company_id', company).order('created_at', ascending: false).limit(100),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (values[0] as List).cast<Map<String,dynamic>>();
        _categories = (values[1] as List).cast<Map<String,dynamic>>();
        _warehouses = (values[2] as List).cast<Map<String,dynamic>>();
        _branches = (values[3] as List).cast<Map<String,dynamic>>();
        _parties = (values[4] as List).cast<Map<String,dynamic>>();
        _campaigns = (values[5] as List).map((r) => Map<String,dynamic>.from(r)).toList();
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
      content: SizedBox(width: 520, height: 420, child: options.isEmpty ? const Center(child: Text('لا توجد بيانات متاحة لهذا الاختيار.')) : ListView(children: options.map((r) {
        final id = _s(r[idKey]); final label = _s(r[labelKey]);
        return CheckboxListTile(value: draft.contains(id), title: Text(label, textDirection: TextDirection.rtl), onChanged: (v) => refresh(() { v == true ? draft.add(id) : draft.remove(id); }));
      }).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { setState(() { selected..clear()..addAll(draft); }); Navigator.pop(ctx); }, child: const Text('تطبيق الاختيار'))],
    )));
  }

  List<Map<String,dynamic>> _distinctOptions(String field) {
    final values = _parties.map((p)=>_s(p[field])).where((v)=>v.isNotEmpty).toSet().toList()..sort();
    return values.map((v)=>{'id':v,'name':v}).toList();
  }

  Future<void> _pickProducts() async {
    final chosen = <String>{};
    final search = TextEditingController();
    String? category = _categoryId;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
      final q = search.text.trim().toLowerCase();
      final list = _items.where((i) => (category == null || _s(i['category_id']) == category) && (q.isEmpty || _s(i['item_name']).toLowerCase().contains(q) || _s(i['item_code']).toLowerCase().contains(q) || _s(i['barcode']).toLowerCase().contains(q))).toList();
      return AlertDialog(title: const Text('جلب الأصناف — اختيار متعدد'),
        content: SizedBox(width: 760, height: 560, child: Column(children: [
          Row(children: [Expanded(child: TextField(controller: search, onChanged: (_) => refresh(() {}), decoration: const InputDecoration(labelText: 'بحث بالاسم أو الكود أو الباركود'))), const SizedBox(width: 8), DropdownButton<String?>(value: category, hint: const Text('كل الفئات'), items: [const DropdownMenuItem<String?>(value: null, child: Text('كل الفئات')), ..._categories.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text(_s(g['category_name']))))], onChanged: (v) => refresh(() => category = v))]),
          Align(alignment: Alignment.centerRight, child: Wrap(spacing: 8, children: [TextButton(onPressed: () => refresh(() => chosen.addAll(list.map((e) => _s(e['id'])))), child: const Text('تحديد الظاهر')), TextButton(onPressed: () => refresh(() => chosen.clear()), child: const Text('إلغاء التحديد'))])),
          Expanded(child: ListView(children: list.map((item) => CheckboxListTile(value: chosen.contains(_s(item['id'])), title: Text('${_s(item['item_code'])} — ${_s(item['item_name'])}', textDirection: TextDirection.rtl), subtitle: Text('سعر البيع: ${_s(item['sale_price'])} | الوحدة: ${_s(item['base_unit'])}'), onChanged: (v) => refresh(() { v == true ? chosen.add(_s(item['id'])) : chosen.remove(_s(item['id'])); }))).toList())),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () {
          setState(() {
            for (final id in chosen) {
              if (_offerLines.any((l) => _s(l['item_id']) == id)) continue;
              final item = _items.firstWhere((i) => _s(i['id']) == id);
              _offerLines.add({'item_id':id,'item_code':_s(item['item_code']),'item_name':_s(item['item_name']),'unit':_s(item['base_unit']),'sale_price':_n(item['sale_price']),'offer_price':_n(item['sale_price']),'offer_qty':100.0,'remaining_qty':100.0,'discount':0.0});
            }
          }); Navigator.pop(ctx);
        }, child: const Text('إضافة الأصناف المحددة'))],
      );
    }));
    search.dispose();
  }

  Future<void> _deleteCampaign(Map<String, dynamic> campaign) async {
    final campaignId = _s(campaign['id']);
    if (campaignId.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف العرض'),
        content: Text('سيتم حذف العرض «${_s(campaign['title'])}» وبنوده المرتبطة. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، احذف العرض'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final company = widget.companyId?.trim() ?? '';
    if (company.isEmpty || _db == null) {
      if (mounted) setState(() => _error = 'لا توجد شركة نشطة لحذف العرض.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _db!.from('erp_sales_campaigns')
          .delete().eq('id', campaignId).eq('company_id', company);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم حذف العرض وبنوده التابعة له.'; });
      await _load();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حذف العرض: $e'; });
    }
  }

  Future<void> _save() async {
    final company = widget.companyId?.trim() ?? '';
    final db = _db;
    if (company.isEmpty || db == null) { setState(() => _error = 'لا توجد شركة نشطة أو اتصال بقاعدة البيانات.'); return; }
    if (_name.text.trim().isEmpty || _offerLines.isEmpty) { setState(() => _error = 'أدخل اسم العرض واختر صنفًا واحدًا على الأقل.'); return; }
    if (_customerScope == 'عملاء محددون' && _selectedCustomers.isEmpty) { setState(() => _error = 'اختر عميلًا واحدًا على الأقل أو غيّر النطاق إلى كل العملاء.'); return; }
    if (_warehouseScope == 'مخازن محددة' && _selectedWarehouses.isEmpty) { setState(() => _error = 'اختر مخزنًا واحدًا على الأقل أو غيّر النطاق إلى كل المخازن.'); return; }
    if (_to.isBefore(_from)) { setState(() => _error = 'تاريخ نهاية العرض يجب ألا يسبق بدايته.'); return; }
    for (final line in _offerLines) {
      if (_n(line['offer_qty']) <= 0 || _n(line['remaining_qty']) < 0 || _n(line['remaining_qty']) > _n(line['offer_qty']) || _n(line['offer_price']) < 0) {
        setState(() => _error = 'راجع أسعار وكميات العرض؛ المتبقي لا يتجاوز الكمية الأصلية.'); return;
      }
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final singleCustomer = _selectedCustomers.length == 1 ? _selectedCustomers.first : null;
      final header = await db.from('erp_sales_campaigns').insert({
        'company_id':company, 'campaign_type':_campaignType, 'title':_name.text.trim(),
        'start_date':_date(_from), 'end_date':_date(_to), 'owner_party_id':singleCustomer,
        'owner_label':_selectedCustomers.isEmpty ? 'كل العملاء' : 'عملاء محددون',
        'is_active':true,
        'target_customer_ids':_selectedCustomers.toList(),
        'target_warehouse_ids':_selectedWarehouses.toList(),
        'target_branch_ids':_selectedBranches.toList(),
        'target_governorates':_governorates.toList(), 'target_districts':_districts.toList(),
        'target_areas':_areas.toList(), 'target_centers':_centers.toList(), 'target_customer_types':_customerTypes.toList(),
      }).select('id').single();
      final campaignId = _s(header['id']);
      final rows = _offerLines.map((line) {
        final offerPrice = _n(line['offer_price']);
        final discountValue = _n(line['discount']);
        return <String,dynamic>{
          'company_id':company, 'campaign_id':campaignId, 'item_id':_s(line['item_id']),
          'offer_price':offerPrice, 'min_quantity':1, 'max_quantity':_n(line['offer_qty']),
          'offer_quantity':_n(line['offer_qty']), 'remaining_quantity':_n(line['remaining_qty']),
          'discount_value':discountValue, 'discount_kind':_discountKind,
          'representative_incentive':_campaignType == 'slow_moving' ? 2 : 0,
          'customer_incentive':_campaignType == 'promotion' ? 2 : 0, 'is_active':true,
        };
      }).toList();
      await db.from('erp_sales_campaign_items').insert(rows);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم حفظ العرض وبنوده في قاعدة بيانات العروض، وأصبح متاحًا في جلب العروض داخل فاتورة المبيعات.'; _name.clear(); _offerLines.clear(); });
      await _load();
    } catch (e) { if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ العرض: $e'; }); }
  }

  Widget _field(String label, Widget child) => Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 5), child]));
  InputDecoration _dec(String label) => InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10));
  Widget _notice(String text, bool error) => Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:error?Colors.red.shade50:Colors.green.shade50,borderRadius:BorderRadius.circular(8)),child:Text(text,style:TextStyle(color:error?Colors.red.shade900:Colors.green.shade900)));

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewOffer() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة عرض الأصناف'),
      content: SizedBox(width: 620, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('اسم العرض: ${_name.text.trim().isEmpty ? '—' : _name.text.trim()}'),
        const SizedBox(height: 6),
        Text('نوع العرض: $_campaignType'),
        const SizedBox(height: 6),
        Text('من ${_from.toIso8601String().substring(0, 10)} إلى ${_to.toIso8601String().substring(0, 10)}'),
        const SizedBox(height: 6),
        Text('الأصناف المحددة: ${_offerLines.length}'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _confirmRemoveOfferLine(Map<String, dynamic> line) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الصنف من العرض'),
        content: Text('هل تريد حذف «${_s(line['item_name'])}» من قائمة أصناف العرض؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No / لا')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes / نعم، احذف'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) setState(() => _offerLines.remove(line));
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(save: _save);
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) { _pickProducts(); return null; },
          ),
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(color: const Color(0xFF3E007D), child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Row(children: [
                          Icon(Icons.local_offer, color: Color(0xFFFFA015), size: 26),
                          SizedBox(width: 8),
                          Expanded(child: Text('عروض الأصناف', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
                        ]),
                        const SizedBox(height: 8),
                        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                          _quickTask('تحديث', Icons.refresh, Colors.blue, _load),
                          _quickTask('إضافة / مسح النموذج', Icons.add_circle_outline, const Color(0xFF168447), () {
                            _name.clear(); _search.clear();
                            setState(() { _message = 'نموذج عرض جديد جاهز.'; _error = null; });
                          }),
                          _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _save),
                          _quickTask('اختيار الأصناف', Icons.inventory_2_outlined, const Color(0xFF137C8B), _pickProducts),
                          _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewOffer),
                        ])),
                      ]),
                    )),
                    const SizedBox(height: 8),
                    if (_error != null) _notice(_error!, true),
                    if (_message != null) _notice(_message!, false),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _field('اسم العرض', TextField(
                                    controller: _name,
                                    decoration: _dec('مثال: عرض نهاية الأسبوع'),
                                  )),
                                ),
                                Expanded(
                                  child: _field('نوع العرض في المبيعات', DropdownButtonFormField<String>(
                                    value: _campaignType,
                                    decoration: _dec('نوع العرض'),
                                    items: const [
                                      DropdownMenuItem(value: 'customer_magazine', child: Text('عرض للعملاء')),
                                      DropdownMenuItem(value: 'promotion', child: Text('عرض ترويج')),
                                      DropdownMenuItem(value: 'slow_moving', child: Text('عرض الرواكد')),
                                    ],
                                    onChanged: widget.lockCampaignType ? null : (v) => setState(() => _campaignType = v ?? _campaignType),
                                  )),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _field('طريقة التسعير', DropdownButtonFormField<String>(
                                    value: _discountKind,
                                    decoration: _dec('طريقة التسعير'),
                                    items: const [
                                      DropdownMenuItem(value: 'special_price', child: Text('سعر عرض خاص')),
                                      DropdownMenuItem(value: 'percent', child: Text('خصم نسبة')),
                                      DropdownMenuItem(value: 'amount', child: Text('خصم قيمة')),
                                      DropdownMenuItem(value: 'buy_get', child: Text('اشترِ كمية واحصل على كمية')),
                                      DropdownMenuItem(value: 'clearance', child: Text('تصفية رواكد')),
                                    ],
                                    onChanged: (v) => setState(() {
                                      _discountKind = v ?? _discountKind;
                                      for (final line in _offerLines) {
                                        final base = _n(line['sale_price']);
                                        final discount = _n(line['discount']);
                                        if (_discountKind == 'percent') {
                                          line['offer_price'] = (base - base * discount / 100).clamp(0, double.infinity);
                                        } else if (_discountKind == 'amount') {
                                          line['offer_price'] = (base - discount).clamp(0, double.infinity);
                                        }
                                      }
                                    }),
                                  )),
                                ),
                                Expanded(
                                  child: _field('بداية العرض', OutlinedButton.icon(
                                    onPressed: () => _chooseDate(true),
                                    icon: const Icon(Icons.calendar_month),
                                    label: Text(_date(_from)),
                                  )),
                                ),
                                Expanded(
                                  child: _field('نهاية العرض', OutlinedButton.icon(
                                    onPressed: () => _chooseDate(false),
                                    icon: const Icon(Icons.event_busy),
                                    label: Text(_date(_to)),
                                  )),
                                ),
                              ],
                            ),
                            const Divider(),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text('نطاق تطبيق العرض', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E007D))),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _field('العملاء', DropdownButtonFormField<String>(
                                    value: _customerScope,
                                    decoration: _dec('تطبيق على'),
                                    items: const [
                                      DropdownMenuItem(value: 'كل العملاء', child: Text('كل العملاء')),
                                      DropdownMenuItem(value: 'عملاء محددون', child: Text('عملاء محددون')),
                                    ],
                                    onChanged: (v) => setState(() => _customerScope = v ?? _customerScope),
                                  )),
                                ),
                                Expanded(
                                  child: _field('المخازن والفروع', DropdownButtonFormField<String>(
                                    value: _warehouseScope,
                                    decoration: _dec('تطبيق على'),
                                    items: const [
                                      DropdownMenuItem(value: 'كل المخازن', child: Text('كل المخازن')),
                                      DropdownMenuItem(value: 'مخازن محددة', child: Text('مخازن محددة')),
                                    ],
                                    onChanged: (v) => setState(() => _warehouseScope = v ?? _warehouseScope),
                                  )),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'جلب العملاء', options: _parties, idKey: 'id', labelKey: 'party_name', selected: _selectedCustomers),
                                  icon: const Icon(Icons.people_alt),
                                  label: Text('جلب العملاء (${_selectedCustomers.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'جلب المخازن', options: _warehouses, idKey: 'id', labelKey: 'warehouse_name', selected: _selectedWarehouses),
                                  icon: const Icon(Icons.warehouse),
                                  label: Text('جلب المخازن (${_selectedWarehouses.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'الفروع', options: _branches, idKey: 'id', labelKey: 'branch_name', selected: _selectedBranches),
                                  icon: const Icon(Icons.store),
                                  label: Text('الفروع (${_selectedBranches.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'المحافظات', options: _distinctOptions('governorate'), idKey: 'id', labelKey: 'name', selected: _governorates),
                                  icon: const Icon(Icons.map),
                                  label: Text('المحافظات (${_governorates.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'المراكز', options: _distinctOptions('center'), idKey: 'id', labelKey: 'name', selected: _centers),
                                  icon: const Icon(Icons.location_city),
                                  label: Text('المراكز (${_centers.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'المراكز/الأحياء', options: _distinctOptions('district'), idKey: 'id', labelKey: 'name', selected: _districts),
                                  icon: const Icon(Icons.location_city),
                                  label: Text('المراكز/الأحياء (${_districts.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'المناطق', options: _distinctOptions('area'), idKey: 'id', labelKey: 'name', selected: _areas),
                                  icon: const Icon(Icons.place),
                                  label: Text('المناطق (${_areas.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'تصنيفات العملاء', options: _distinctOptions('customer_type'), idKey: 'id', labelKey: 'name', selected: _customerTypes),
                                  icon: const Icon(Icons.category),
                                  label: Text('تصنيفات العملاء (${_customerTypes.length})'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: _dec('بحث الأصناف — اضغط F1 لجلب الأصناف'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(onPressed: _pickProducts, icon: const Icon(Icons.playlist_add), label: const Text('جلب الأصناف F1')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _categoryId,
                            decoration: _dec('تصفية حسب الفئة'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('كل الفئات')),
                              ..._categories.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text(_s(g['category_name'])))),
                            ],
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => setState(() => _categoryId = null), child: const Text('الكل')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('كود')),
                            DataColumn(label: Text('الصنف')),
                            DataColumn(label: Text('الوحدة')),
                            DataColumn(label: Text('سعر البيع')),
                            DataColumn(label: Text('سعر العرض')),
                            DataColumn(label: Text('كمية العرض')),
                            DataColumn(label: Text('المتبقي')),
                            DataColumn(label: Text('خصم')),
                            DataColumn(label: Text('حذف')),
                          ],
                          rows: _offerLines.map((line) => DataRow(cells: [
                            DataCell(Text(_s(line['item_code']))),
                            DataCell(SizedBox(width: 180, child: Text(_s(line['item_name'])))),
                            DataCell(Text(_s(line['unit']))),
                            DataCell(Text(_n(line['sale_price']).toStringAsFixed(2))),
                            DataCell(SizedBox(
                              width: 90,
                              child: TextFormField(
                                initialValue: _s(line['offer_price']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('السعر'),
                                onChanged: (v) => setState(() => line['offer_price'] = _n(v)),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 85,
                              child: TextFormField(
                                initialValue: _s(line['offer_qty']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('الكمية'),
                                onChanged: (v) => setState(() => line['offer_qty'] = _n(v)),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 85,
                              child: TextFormField(
                                initialValue: _s(line['remaining_qty']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('المتبقي'),
                                onChanged: (v) => setState(() => line['remaining_qty'] = _n(v)),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 75,
                              child: TextFormField(
                                initialValue: _s(line['discount']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('الخصم'),
                                onChanged: (v) => setState(() {
                                  line['discount'] = _n(v);
                                  final base = _n(line['sale_price']);
                                  final discount = _n(v);
                                  if (_discountKind == 'percent') {
                                    line['offer_price'] = (base - base * discount / 100).clamp(0, double.infinity);
                                  } else if (_discountKind == 'amount') {
                                    line['offer_price'] = (base - discount).clamp(0, double.infinity);
                                  }
                                }),
                              ),
                            )),
                            DataCell(IconButton(
                              tooltip: 'حذف الصنف',
                              onPressed: () => _confirmRemoveOfferLine(line),
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                            )),
                          ])).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'عدد الأصناف: ${_offerLines.length} | يتم حفظ العروض في جداول الحملات الفعلية المتصلة بأزرار جلب العروض في فاتورة البيع.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ العرض'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('العروض المسجلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E007D))),
                    if (_campaigns.isEmpty)
                      const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد عروض مسجلة بعد.')),
                    ..._campaigns.map((campaign) => Card(
                      child: ListTile(
                        leading: Icon(
                          _s(campaign['campaign_type']) == 'slow_moving'
                              ? Icons.inventory_2_outlined
                              : _s(campaign['campaign_type']) == 'promotion'
                                  ? Icons.campaign_outlined
                                  : Icons.menu_book_outlined,
                          color: const Color(0xFF3E007D),
                        ),
                        title: Text(_s(campaign['title'])),
                        subtitle: Text('${_s(campaign['start_date'])} ← ${_s(campaign['end_date'])} | ${_s(campaign['campaign_type'])}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_s(campaign['is_active']) == 'true' ? Icons.check_circle : Icons.pause_circle_outline,
                            color: _s(campaign['is_active']) == 'true' ? Colors.green : Colors.grey),
                          IconButton(tooltip: 'حذف العرض', onPressed: _saving ? null : () => _deleteCampaign(campaign),
                            icon: const Icon(Icons.delete_outline, color: Colors.red)),
                        ]),
                      ),
                    )),
                  ],
                ),
        ),
      ),
    );
  }

}
