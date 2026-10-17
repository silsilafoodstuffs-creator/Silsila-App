import 'package:flutter/material.dart';
import '../services/erp_inventory_master_repository.dart';

class ErpInventoryMasterScreen extends StatefulWidget {
  const ErpInventoryMasterScreen({super.key, this.initialCompanyId, this.initialView = 'warehouses'});
  final String? initialCompanyId;
  final String initialView;
  @override
  State<ErpInventoryMasterScreen> createState() => _ErpInventoryMasterScreenState();
}

class _ErpInventoryMasterScreenState extends State<ErpInventoryMasterScreen> {
  final _repo = ErpInventoryMasterRepository();
  final _company = TextEditingController();
  final _groupCode = TextEditingController();
  final _groupName = TextEditingController();
  final _warehouseCode = TextEditingController();
  final _warehouseName = TextEditingController();
  final _address = TextEditingController();
  final _itemCode = TextEditingController();
  final _itemName = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'وحدة');
  final _purchasePrice = TextEditingController(text: '0');
  final _salePrice = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '0');
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  String? _parentGroupId;
  String? _itemGroupId;
  String _view = 'warehouses';
  bool _expiry = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _view = widget.initialView;
  }
  @override
  void dispose() {
    _company.dispose(); _groupCode.dispose(); _groupName.dispose(); _warehouseCode.dispose(); _warehouseName.dispose(); _address.dispose();
    _itemCode.dispose(); _itemName.dispose(); _barcode.dispose(); _unit.dispose();
    _purchasePrice.dispose(); _salePrice.dispose(); _reorder.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);

  Future<void> _load({bool clearMessage = true}) async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; if (clearMessage) _message = null; });
    try {
      final values = await Future.wait([
        _repo.fetchWarehouses(_company.text),
        _repo.fetchItems(_company.text),
        _repo.fetchBranches(_company.text),
        _repo.fetchGroups(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = values[0]; _items = values[1]; _branches = values[2]; _groups = values[3];
        if (!_groups.any((g) => _s(g['id']) == _parentGroupId)) _parentGroupId = null;
        if (!_groups.any((g) => _s(g['id']) == _itemGroupId && g['is_active'] == true)) _itemGroupId = null;
        if (!_branches.any((b) => _s(b['id']) == _branchId)) _branchId = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل بيانات المخازن والأصناف: $e'; });
    }
  }

  Future<void> _createGroup() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createGroup(companyId: _company.text, code: _groupCode.text, name: _groupName.text, parentId: _parentGroupId);
      if (!mounted) return;
      _groupCode.clear(); _groupName.clear();
      setState(() { _saving = false; _message = 'تمت إضافة مجموعة الأصناف.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة مجموعة الأصناف: $e'; });
    }
  }

  Future<void> _createWarehouse() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createWarehouse(companyId: _company.text, code: _warehouseCode.text,
        name: _warehouseName.text, branchId: _branchId, address: _address.text);
      if (!mounted) return;
      _warehouseCode.clear(); _warehouseName.clear(); _address.clear();
      setState(() { _saving = false; _message = 'تمت إضافة المخزن.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة المخزن: $e'; });
    }
  }

  Future<void> _createItem() async {
    final purchase = double.tryParse(_purchasePrice.text.trim()) ?? -1;
    final sale = double.tryParse(_salePrice.text.trim()) ?? -1;
    final reorder = double.tryParse(_reorder.text.trim()) ?? -1;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createItem(companyId: _company.text, code: _itemCode.text, name: _itemName.text,
        barcode: _barcode.text, groupId: _itemGroupId, unit: _unit.text, purchasePrice: purchase,
        salePrice: sale, reorderLevel: reorder, expiryTracking: _expiry);
      if (!mounted) return;
      _itemCode.clear(); _itemName.clear(); _barcode.clear(); _purchasePrice.text = '0'; _salePrice.text = '0'; _reorder.text = '0';
      setState(() { _saving = false; _message = 'تمت إضافة الصنف.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة الصنف: $e'; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool item) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      if (item) await _repo.setItemActive(_s(row['id']), row['is_active'] != true);
      else if (_view == 'groups') await _repo.setGroupActive(_s(row['id']), row['is_active'] != true);
      else await _repo.setWarehouseActive(_s(row['id']), row['is_active'] != true);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تحديث الحالة.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تحديث الحالة: $e'; });
    }
  }

  String _groupLabel(String? id) {
    final rows = _groups.where((g) => _s(g['id']) == id);
    return rows.isEmpty ? 'بدون مجموعة' : _s(rows.first['group_code']) + ' — ' + _s(rows.first['group_name']);
  }

  String _branchName(String? id) {
    final rows = _branches.where((b) => _s(b['id']) == id);
    return rows.isEmpty ? 'بدون فرع محدد' : _s(rows.first['branch_code']) + ' — ' + _s(rows.first['branch_name']);
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('بيانات المخازن والأصناف', style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('تعريف المخازن والأصناف الأساسية قبل تسجيل حركات المخزون والمشتريات والمبيعات.', style: TextStyle(color: Colors.black54, height: 1.5)),
      const SizedBox(height: 12),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل البيانات')),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'warehouses', label: Text('المخازن'), icon: Icon(Icons.warehouse_outlined)),
          ButtonSegment(value: 'items', label: Text('الأصناف'), icon: Icon(Icons.inventory_2_outlined)),
          ButtonSegment(value: 'groups', label: Text('المجموعات'), icon: Icon(Icons.category_outlined)),
        ],
        selected: {_view}, onSelectionChanged: (v) => setState(() => _view = v.first),
      ),
      const SizedBox(height: 10),
      if (_view == 'groups') ...[
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إضافة مجموعة أصناف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            TextField(controller: _groupCode, decoration: const InputDecoration(labelText: 'كود المجموعة *')),
            TextField(controller: _groupName, decoration: const InputDecoration(labelText: 'اسم المجموعة *')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _parentGroupId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'المجموعة الرئيسية (اختياري)'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('بدون مجموعة رئيسية')), ..._groups.where((g) => g['is_active'] == true).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['group_code']) + ' — ' + _s(g['group_name']), overflow: TextOverflow.ellipsis)))],
              onChanged: (v) => setState(() => _parentGroupId = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _createGroup, icon: const Icon(Icons.create_new_folder_outlined), label: const Text('حفظ المجموعة')),
          ],
        ))),
        Text('مجموعات الأصناف • ' + _groups.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ..._groups.map((g) => Card(child: ListTile(
          leading: const Icon(Icons.category_outlined, color: Color(0xFF3E007D)),
          title: Text(_s(g['group_code']) + ' — ' + _s(g['group_name'])),
          subtitle: Text(_s(g['parent_id']).isEmpty ? 'مجموعة رئيسية' : 'مجموعة فرعية'),
          trailing: IconButton(onPressed: _saving ? null : () => _toggle(g, false), icon: Icon(g['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
        ))),
      ] else if (_view == 'warehouses') ...[
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إضافة مخزن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            TextField(controller: _warehouseCode, decoration: const InputDecoration(labelText: 'كود المخزن *')),
            TextField(controller: _warehouseName, decoration: const InputDecoration(labelText: 'اسم المخزن *')),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _branchId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الفرع (اختياري)'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('بدون فرع')), ..._branches.map((b) => DropdownMenuItem<String>(value: _s(b['id']), child: Text(_branchName(_s(b['id'])))))],
              onChanged: (v) => setState(() => _branchId = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _createWarehouse, icon: const Icon(Icons.add_business), label: const Text('حفظ المخزن')),
          ],
        ))),
        Text('المخازن المسجلة • ' + _warehouses.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ..._warehouses.map((w) => Card(child: ListTile(
          leading: const Icon(Icons.warehouse_outlined, color: Color(0xFF3E007D)),
          title: Text(_s(w['warehouse_code']) + ' — ' + _s(w['warehouse_name'])),
          subtitle: Text(_branchName(_s(w['branch_id'])) + (_s(w['address']).isEmpty ? '' : '\n' + _s(w['address']))),
          isThreeLine: true,
          trailing: IconButton(onPressed: _saving ? null : () => _toggle(w, false), icon: Icon(w['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
        ))),
      ] else ...[
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إضافة صنف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            TextField(controller: _itemCode, decoration: const InputDecoration(labelText: 'كود الصنف *')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _itemGroupId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'مجموعة الصنف (اختياري)'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('بدون مجموعة')), ..._groups.where((g) => g['is_active'] == true).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['group_code']) + ' — ' + _s(g['group_name']), overflow: TextOverflow.ellipsis)))],
              onChanged: (v) => setState(() => _itemGroupId = v),
            ),
            TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'اسم الصنف *')),
            TextField(controller: _barcode, decoration: const InputDecoration(labelText: 'الباركود')),
            TextField(controller: _unit, decoration: const InputDecoration(labelText: 'وحدة القياس')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _purchasePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر الشراء'))),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: _salePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر البيع'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _reorder, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد إعادة الطلب')),
            CheckboxListTile(value: _expiry, onChanged: (v) => setState(() => _expiry = v ?? false), title: const Text('تتبع تاريخ الصلاحية'), contentPadding: EdgeInsets.zero),
            FilledButton.icon(onPressed: _saving ? null : _createItem, icon: const Icon(Icons.add), label: const Text('حفظ الصنف')),
          ],
        ))),
        Text('الأصناف المسجلة • ' + _items.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ..._items.map((i) => Card(child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF3E007D)),
          title: Text(_s(i['item_code']) + ' — ' + _s(i['item_name'])),
          subtitle: Text(_groupLabel(_s(i['group_id'])) + '\nالوحدة: ' + _s(i['base_unit']) + ' • شراء: ' + _money(i['purchase_price']) + ' • بيع: ' + _money(i['sale_price']) + '\nحد الطلب: ' + _s(i['reorder_level']) + (_s(i['barcode']).isEmpty ? '' : ' • باركود: ' + _s(i['barcode']))),
          isThreeLine: true,
          trailing: IconButton(onPressed: _saving ? null : () => _toggle(i, true), icon: Icon(i['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
        ))),
      ],
    ],
  ));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
