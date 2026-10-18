import 'package:flutter/material.dart';
import '../services/erp_price_lists_repository.dart';

class ErpPriceListsScreen extends StatefulWidget {
  const ErpPriceListsScreen({super.key, this.initialCompanyId, this.initialKind = 'sale'});
  final String? initialCompanyId;
  final String initialKind;
  @override
  State<ErpPriceListsScreen> createState() => _ErpPriceListsScreenState();
}

class _ErpPriceListsScreenState extends State<ErpPriceListsScreen> {
  final _repo = ErpPriceListsRepository();
  final _company = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _itemPrice = TextEditingController(text: '0');
  final _minQty = TextEditingController(text: '1');
  final _discount = TextEditingController(text: '0');
  final _testQuantity = TextEditingController(text: '1');
  List<Map<String, dynamic>> _lists = [];
  List<Map<String, dynamic>> _currencies = [
    {'currency_code':'EGP','currency_name_ar':'جنيه مصري','currency_symbol':'EGP'},
    {'currency_code':'USD','currency_name_ar':'دولار أمريكي','currency_symbol':'USD'},
    {'currency_code':'SAR','currency_name_ar':'ريال سعودي','currency_symbol':'SAR'},
    {'currency_code':'AED','currency_name_ar':'درهم إماراتي','currency_symbol':'AED'},
    {'currency_code':'KWD','currency_name_ar':'دينار كويتي','currency_symbol':'KWD'},
    {'currency_code':'EUR','currency_name_ar':'يورو','currency_symbol':'EUR'},
    {'currency_code':'GBP','currency_name_ar':'جنيه إسترليني','currency_symbol':'GBP'},
  ];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _lines = [];
  String _kind = 'sale';
  String _currencyCode = 'EGP';
  String? _selectedListId;
  String? _selectedItemId;
  String? _selectedPartyId;
  Map<String, dynamic>? _pricePreview;
  bool _previewing = false;
  bool _default = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _kind = widget.initialKind;
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }
  @override
  void dispose() {
    _company.dispose(); _code.dispose(); _name.dispose(); _notes.dispose();
    _itemPrice.dispose(); _minQty.dispose(); _discount.dispose(); _testQuantity.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);
  String _itemLabel(String? id) {
    final rows = _items.where((x) => _s(x['id']) == id);
    return rows.isEmpty ? 'اختر الصنف' : _s(rows.first['item_code']) + ' — ' + _s(rows.first['item_name']);
  }
  String _partyLabel(String? id) {
    final rows = _parties.where((x) => _s(x['id']) == id);
    return rows.isEmpty ? 'اختر الطرف' : _s(rows.first['party_code']) + ' — ' + _s(rows.first['party_name']);
  }

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final values = await Future.wait([
        _repo.fetchLists(_company.text, kind: _kind),
        _repo.fetchItems(_company.text),
        _repo.fetchCurrencies(_company.text),
        _repo.fetchParties(_company.text, _kind == 'sale' ? 'customer' : 'supplier'),
      ]);
      if (!mounted) return;
      final lists = values[0];
      final selected = lists.any((x) => _s(x['id']) == _selectedListId) ? _selectedListId : (lists.isEmpty ? null : _s(lists.first['id']));
      setState(() {
        _lists = lists; _items = values[1]; _parties = values[2];
        if ((values[3] as List<Map<String, dynamic>>).isNotEmpty) _currencies = values[3];
        _selectedListId = selected;
        if (!_items.any((x) => _s(x['id']) == _selectedItemId)) _selectedItemId = _items.isEmpty ? null : _s(_items.first['id']);
        if (!_parties.any((x) => _s(x['id']) == _selectedPartyId)) _selectedPartyId = _parties.isEmpty ? null : _s(_parties.first['id']);
        _loading = false;
      });
      await _loadLines();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل قوائم الأسعار: $e'; });
    }
  }
  Future<void> _loadLines() async {
    final id = _selectedListId;
    if (id == null) { if (mounted) setState(() => _lines = []); return; }
    try {
      final rows = await _repo.fetchLines(_company.text, id);
      if (mounted) setState(() => _lines = rows);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل بنود القائمة: $e');
    }
  }
  Future<void> _createList() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createList(companyId: _company.text, code: _code.text, name: _name.text,
        kind: _kind, isDefault: _default, currency: _currencyCode, notes: _notes.text);
      if (!mounted) return;
      _code.clear(); _name.clear(); _notes.clear(); setState(() { _saving = false; _message = 'تم إنشاء قائمة الأسعار.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إنشاء القائمة: $e'; });
    }
  }
  Future<void> _addLine() async {
    final price = double.tryParse(_itemPrice.text.trim()) ?? -1;
    final qty = double.tryParse(_minQty.text.trim()) ?? -1;
    final discount = double.tryParse(_discount.text.trim()) ?? -1;
    if (_selectedListId == null || _selectedItemId == null) { setState(() => _error = 'اختر القائمة والصنف.'); return; }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.addLine(companyId: _company.text, listId: _selectedListId!, itemId: _selectedItemId!,
        unitPrice: price, minQuantity: qty, discountPercent: discount);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تمت إضافة سعر الصنف.'; });
      await _loadLines();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إضافة السعر: $e'; });
    }
  }
  Future<void> _previewPrice() async {
    final qty = double.tryParse(_testQuantity.text.trim()) ?? 0;
    if (_selectedItemId == null || qty <= 0) {
      setState(() => _error = 'اختر الصنف وأدخل كمية أكبر من صفر لاختبار السعر.');
      return;
    }
    setState(() { _previewing = true; _error = null; _pricePreview = null; });
    try {
      final result = await _repo.resolvePrice(
        companyId: _company.text, itemId: _selectedItemId!, kind: _kind,
        quantity: qty, partyId: _selectedPartyId,
      );
      if (!mounted) return;
      setState(() { _previewing = false; _pricePreview = result; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _previewing = false; _error = 'تعذر حساب السعر الفعلي: $e'; });
    }
  }

  Future<void> _assignParty() async {
    if (_selectedListId == null || _selectedPartyId == null) { setState(() => _error = 'اختر القائمة والعميل/المورد.'); return; }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.assignParty(companyId: _company.text, listId: _selectedListId!, partyId: _selectedPartyId!);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم ربط القائمة بالطرف.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر ربط القائمة بالطرف: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('قوائم الأسعار', style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('قوائم منفصلة للبيع والشراء، مع أسعار حسب الصنف والحد الأدنى وربطها بعميل أو مورد.', style: TextStyle(color: Colors.black54, height: 1.5)),
      const SizedBox(height: 12),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'sale', label: Text('أسعار البيع')), ButtonSegment(value: 'purchase', label: Text('أسعار الشراء'))],
        selected: {_kind}, onSelectionChanged: (v) { setState(() { _kind = v.first; _selectedListId = null; }); _load(); },
      ),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل القوائم')),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      const SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('إنشاء قائمة جديدة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'كود القائمة *')),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم القائمة *')),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
        DropdownButtonFormField<String>(
          value: _currencyCode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'عملة قائمة الأسعار', isDense: true, constraints: BoxConstraints(minHeight: 52)),
          items: _currencies.map((currency) => DropdownMenuItem<String>(
            value: _s(currency['currency_code']),
            child: Text(_s(currency['currency_name_ar']) + ' (' + (_s(currency['currency_symbol']).isEmpty ? _s(currency['currency_code']) : _s(currency['currency_symbol'])) + ')'),
          )).toList(),
          onChanged: (value) { if (value != null) setState(() => _currencyCode = value); },
        ),
        CheckboxListTile(value: _default, onChanged: (v) => setState(() => _default = v ?? false), title: const Text('القائمة الافتراضية لهذا النوع'), contentPadding: EdgeInsets.zero),
        FilledButton.icon(onPressed: _saving ? null : _createList, icon: const Icon(Icons.playlist_add), label: const Text('حفظ القائمة')),
      ]))),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _selectedListId, isExpanded: true,
        decoration: const InputDecoration(labelText: 'القائمة الحالية', border: OutlineInputBorder()),
        items: _lists.map((x) => DropdownMenuItem<String>(value: _s(x['id']), child: Text(_s(x['price_list_code']) + ' — ' + _s(x['price_list_name']), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { setState(() => _selectedListId = v); _loadLines(); },
      ),
      if (_selectedListId != null) ...[
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('إضافة سعر لصنف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          DropdownButtonFormField<String>(
            value: _selectedItemId, isExpanded: true, decoration: const InputDecoration(labelText: 'الصنف'),
            items: _items.map((x) => DropdownMenuItem<String>(value: _s(x['id']), child: Text(_itemLabel(_s(x['id'])), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedItemId = v),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _itemPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر الوحدة'))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _minQty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'أقل كمية'))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'خصم %')),
          FilledButton.icon(onPressed: _saving ? null : _addLine, icon: const Icon(Icons.add), label: const Text('إضافة السعر')),
          const Divider(height: 24),
          const Text('ربط القائمة بطرف', style: TextStyle(fontWeight: FontWeight.w900)),
          DropdownButtonFormField<String>(
            value: _selectedPartyId, isExpanded: true, decoration: InputDecoration(labelText: _kind == 'sale' ? 'العميل' : 'المورد'),
            items: _parties.map((x) => DropdownMenuItem<String>(value: _s(x['id']), child: Text(_partyLabel(_s(x['id'])), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedPartyId = v),
          ),
          FilledButton.icon(onPressed: _saving ? null : _assignParty, icon: const Icon(Icons.link), label: const Text('ربط القائمة بالطرف')),
          const Divider(height: 24),
          const Text('معاينة السعر الفعلي', style: TextStyle(fontWeight: FontWeight.w900)),
          const Text('تحسب المعاينة سعر الطرف أو القائمة الافتراضية أو سعر بطاقة الصنف، دون تعديل أي فاتورة.', style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(controller: _testQuantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية المطلوب تسعيرها')),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _previewing ? null : _previewPrice, icon: const Icon(Icons.calculate_outlined), label: const Text('احسب السعر')),
          if (_previewing) const LinearProgressIndicator(),
          if (_pricePreview != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF0E8FA), borderRadius: BorderRadius.circular(10)),
              child: Text(
                'سعر الوحدة: ' + _money(_pricePreview!['base_unit_price']) +
                ' ج.م\\nالخصم: ' + _s(_pricePreview!['discount_percent']) + '%' +
                '\\nالسعر بعد الخصم: ' + _money(_pricePreview!['net_unit_price']) + ' ج.م' +
                '\\nالمصدر: ' + _s(_pricePreview!['price_source']) +
                (_s(_pricePreview!['price_list_name']).isEmpty ? '' : '\\nالقائمة: ' + _s(_pricePreview!['price_list_name'])),
                style: const TextStyle(height: 1.6, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]))),
      ],
      const SizedBox(height: 10),
      Text('بنود الأسعار • ' + _lines.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ..._lines.map((l) {
        final item = _items.where((x) => _s(x['id']) == _s(l['item_id']));
        final name = item.isEmpty ? _s(l['item_id']) : _s(item.first['item_name']);
        return Card(child: ListTile(
          leading: const Icon(Icons.sell_outlined, color: Color(0xFF3E007D)),
          title: Text(name + ' — ' + _money(l['unit_price']) + ' ج.م'),
          subtitle: Text('أقل كمية: ' + _s(l['min_quantity']) + ' • الخصم: ' + _s(l['discount_percent']) + '%'),
        ));
      }),
      const SizedBox(height: 10),
      Text('القوائم المسجلة • ' + _lists.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ..._lists.map((l) => Card(child: ListTile(
        leading: const Icon(Icons.price_change_outlined, color: Color(0xFF3E007D)),
        title: Text(_s(l['price_list_code']) + ' — ' + _s(l['price_list_name'])),
        subtitle: Text(_s(l['currency_code']) + (_s(l['is_default']) == 'true' ? ' • افتراضية' : '') + (_s(l['is_active']) == 'true' ? '' : ' • غير نشطة')),
        trailing: IconButton(onPressed: _saving ? null : () async {
          await _repo.setListActive(_s(l['id']), l['is_active'] != true);
          await _load();
        }, icon: Icon(l['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
      ))),
    ],
  ));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
