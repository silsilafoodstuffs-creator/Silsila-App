import 'package:flutter/material.dart';
import '../services/erp_inventory_repository.dart';

class ErpInventoryScreen extends StatefulWidget {
  const ErpInventoryScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;

  @override
  State<ErpInventoryScreen> createState() => _ErpInventoryScreenState();
}

class _ErpInventoryScreenState extends State<ErpInventoryScreen> {
  final _repo = ErpInventoryRepository();
  final _company = TextEditingController();
  final _quantity = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _batch = TextEditingController();
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _movements = [];
  String? _warehouseId;
  String? _itemId;
  String _type = 'opening';
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _success;

  static const _types = <String, String>{
    'opening': 'رصيد افتتاحي / وارد',
    'purchase_receipt': 'استلام مشتريات',
    'customer_return': 'مرتجع عميل',
    'transfer_in': 'تحويل وارد',
    'sales_issue': 'صرف مبيعات',
    'supplier_return': 'مرتجع مورد',
    'transfer_out': 'تحويل منصرف',
    'waste': 'هالك',
  };

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
  }

  @override
  void dispose() {
    _company.dispose();
    _quantity.dispose();
    _cost.dispose();
    _notes.dispose();
    _batch.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _qty(dynamic v) => _n(v).toStringAsFixed(3).replaceFirst(RegExp(r'\.000$'), '');

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولاً.');
      return;
    }
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final values = await Future.wait([
        _repo.fetchWarehouses(_company.text),
        _repo.fetchItems(_company.text),
        _repo.fetchBalances(_company.text),
        _repo.fetchMovements(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = values[0];
        _items = values[1];
        _balances = values[2];
        _movements = values[3];
        if (!_warehouses.any((r) => _s(r['id']) == _warehouseId)) {
          _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
        }
        if (!_items.any((r) => _s(r['id']) == _itemId)) {
          _itemId = _items.isEmpty ? null : _s(_items.first['id']);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل بيانات المخزون: $e'; });
    }
  }

  Future<void> _save() async {
    final quantity = double.tryParse(_quantity.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    if (_warehouseId == null || _itemId == null) {
      setState(() => _error = 'يلزم تحميل واختيار مخزن وصنف صالحين.');
      return;
    }
    if (quantity == null || quantity <= 0 || cost == null || cost < 0) {
      setState(() => _error = 'أدخل كمية أكبر من صفر وتكلفة صحيحة لا تقل عن صفر.');
      return;
    }
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      await _repo.recordMovement(
        companyId: _company.text,
        warehouseId: _warehouseId!,
        itemId: _itemId!,
        movementType: _type,
        quantity: quantity,
        unitCost: cost,
        notes: _notes.text.trim(),
        batchNumber: _batch.text.trim().isEmpty ? null : _batch.text.trim(),
      );
      if (!mounted) return;
      _quantity.clear();
      _notes.clear();
      setState(() { _saving = false; _success = 'تم تسجيل الحركة المخزنية.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تسجيل الحركة: $e'; });
    }
  }

  String _itemName(String id) {
    final row = _items.where((r) => _s(r['id']) == id);
    if (row.isEmpty) return id;
    return '${_s(row.first['item_code'])} — ${_s(row.first['item_name'])}';
  }

  String _warehouseName(String id) {
    final row = _warehouses.where((r) => _s(r['id']) == id);
    if (row.isEmpty) return id;
    return '${_s(row.first['warehouse_code'])} — ${_s(row.first['warehouse_name'])}';
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _balances.length;
    final negative = _balances.where((r) => _n(r['quantity_on_hand']) < 0).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إدارة المخزون والحركات', style: TextStyle(
            color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('أرصدة محسوبة من دفتر حركات المخزون، مع تسجيل وارد ومنصرف عبر تحقق خادمي يمنع الصرف بما يتجاوز الرصيد.',
            style: TextStyle(color: Colors.black54, height: 1.5)),
          const SizedBox(height: 12),
          TextField(controller: _company, decoration: const InputDecoration(
            labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business))),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh), label: const Text('تحميل الأرصدة والحركات')),
          if (_error != null) _message(_error!, const Color(0xFFB42318)),
          if (_success != null) _message(_success!, const Color(0xFF18794E)),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _stat('بنود أرصدة', '$totalItems', Icons.inventory_2_outlined),
            _stat('حركات حديثة', '${_movements.length}', Icons.swap_vert),
            _stat('أرصدة سالبة', '$negative', Icons.warning_amber_rounded),
          ]),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تسجيل حركة مخزنية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _warehouseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المخزن', border: OutlineInputBorder()),
                items: _warehouses.map((r) => DropdownMenuItem<String>(
                  value: _s(r['id']), child: Text(_warehouseName(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _itemId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                items: _items.map((r) => DropdownMenuItem<String>(
                  value: _s(r['id']), child: Text(_itemName(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _itemId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع الحركة', border: OutlineInputBorder()),
                items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'تكلفة الوحدة', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _batch, decoration: const InputDecoration(labelText: 'رقم التشغيلة (اختياري)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _saving || _loading || _warehouses.isEmpty || _items.isEmpty ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'تسجيل الحركة'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3E007D)),
              ),
              const Text('تنبيه: الحركة تُسجل في دفتر دائم ولا تُحذف؛ صحّح الأخطاء بحركة مقابلة معتمدة.',
                style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
            ],
          ))),
          const SizedBox(height: 12),
          const Text('الأرصدة الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (_balances.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد أرصدة معروضة؛ حمّل البيانات أو سجّل حركة أولًا.')),
          ..._balances.map((r) => Card(child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF3E007D)),
            title: Text(_itemName(_s(r['item_id']))),
            subtitle: Text(_warehouseName(_s(r['warehouse_id']))),
            trailing: Text(_qty(r['quantity_on_hand']), style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _n(r['quantity_on_hand']) < 0 ? Colors.red : const Color(0xFF18794E))),
          ))),
          const SizedBox(height: 12),
          const Text('آخر الحركات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (_movements.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد حركات مخزنية مسجلة.')),
          ..._movements.map((r) {
            final inbound = _n(r['quantity_in']);
            final typeLabel = _types[_s(r['movement_type'])] ?? _s(r['movement_type']);
            return Card(child: ListTile(
              leading: Icon(inbound > 0 ? Icons.south_west : Icons.north_east,
                color: inbound > 0 ? const Color(0xFF18794E) : Colors.deepOrange),
              title: Text(_itemName(_s(r['item_id']))),
              subtitle: Text('$typeLabel • ${_s(r['movement_date']).replaceFirst('T', ' ')}\n${_warehouseName(_s(r['warehouse_id']))}'),
              isThreeLine: true,
              trailing: Text(inbound > 0 ? '+${_qty(inbound)}' : '-${_qty(r['quantity_out'])}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            ));
          }),
        ],
      ),
    );
  }

  Widget _message(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );

  Widget _stat(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF7F5FA), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: const Color(0xFF3E007D)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ]),
    ]),
  );
}
