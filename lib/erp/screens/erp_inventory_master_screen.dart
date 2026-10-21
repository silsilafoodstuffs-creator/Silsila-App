import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _imagePicker = ImagePicker();
  XFile? _pickedItemImage;
  Uint8List? _pickedItemImageBytes;
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
  final _taxRate = TextEditingController(text: '0');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }
  @override
  void dispose() {
    _company.dispose(); _groupCode.dispose(); _groupName.dispose(); _warehouseCode.dispose(); _warehouseName.dispose(); _address.dispose();
    _itemCode.dispose(); _itemName.dispose(); _barcode.dispose(); _unit.dispose();
    _purchasePrice.dispose(); _salePrice.dispose(); _taxRate.dispose(); _reorder.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);
  Uint8List? _decodeBytea(dynamic value) {
    final raw = _s(value);
    final prefixLength = raw.startsWith(r'\\x') ? 3 : raw.startsWith(r'\x') ? 2 : 0;
    if (prefixLength == 0 || raw.length <= prefixLength || (raw.length - prefixLength).isOdd) return null;
    try { return Uint8List.fromList(List<int>.generate((raw.length - prefixLength) ~/ 2, (i) => int.parse(raw.substring(prefixLength + i * 2, prefixLength + 2 + i * 2), radix: 16))); }
    catch (_) { return null; }
  }

  Future<void> _load({bool clearMessage = true}) async {
    if (!mounted) return;
    if (_company.text.trim().isEmpty) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          final memberships = await client.from('erp_company_members')
              .select('company_id')
              .eq('user_id', userId)
              .eq('is_active', true)
              .order('created_at')
              .limit(1);
          if ((memberships as List).isNotEmpty) {
            _company.text = (memberships.first['company_id'] ?? '').toString();
          }
        }
      } catch (_) {
        // The user-facing error below explains the missing company context.
      }
    }
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'لم يتم العثور على شركة نشطة لحسابك. افتح بيانات الشركة أو تحقق من عضوية الشركة.');
      return;
    }
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


  Future<void> _pickItemImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        setState(() => _error = 'حجم الصورة أكبر من 8 ميجابايت.');
        return;
      }
      setState(() {
        _pickedItemImage = file;
        _pickedItemImageBytes = bytes;
        _error = null;
        _message = 'تم اختيار الصورة، وسيتم رفعها وحفظها مع الصنف عند الضغط على حفظ الصنف.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح الصور أو الكاميرا: $e');
    }
  }

  Future<void> _createItem() async {
    final purchase = double.tryParse(_purchasePrice.text.trim()) ?? -1;
    final sale = double.tryParse(_salePrice.text.trim()) ?? -1;
    final reorder = double.tryParse(_reorder.text.trim()) ?? -1;
    final taxRate = double.tryParse(_taxRate.text.trim()) ?? -1;
    setState(() { _saving = true; _error = null; _message = null; });
    try {

      final image = _pickedItemImage;
      final imageBytes = _pickedItemImageBytes;
      final extension = image?.name.contains('.') == true ? image!.name.split('.').last.toLowerCase() : 'jpg';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'jpeg' || 'jpg' => 'image/jpeg',
        _ => '',
      };
      if (imageBytes != null && imageBytes.isNotEmpty && contentType.isEmpty) {
        throw ArgumentError('صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WEBP.');
      }
      await _repo.createItem(companyId: _company.text, code: _itemCode.text, name: _itemName.text,
        barcode: _barcode.text, groupId: _itemGroupId, unit: _unit.text, purchasePrice: purchase,
        salePrice: sale, taxRate: taxRate, reorderLevel: reorder, expiryTracking: _expiry,
        imageBytes: imageBytes, imageMimeType: imageBytes == null ? null : contentType);
      if (!mounted) return;
      _itemCode.clear(); _itemName.clear(); _barcode.clear(); _pickedItemImage = null; _pickedItemImageBytes = null; _purchasePrice.text = '0'; _salePrice.text = '0'; _taxRate.text = '0'; _reorder.text = '0';
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

Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  void _newCurrentRecord() {
    final currentFields = _view == 'warehouses'
        ? [_warehouseCode.text, _warehouseName.text, _address.text]
        : _view == 'groups'
            ? [_groupCode.text, _groupName.text]
            : [_itemCode.text, _itemName.text, _barcode.text,
                _unit.text == 'وحدة' ? '' : _unit.text,
                _purchasePrice.text == '0' ? '' : _purchasePrice.text,
                _salePrice.text == '0' ? '' : _salePrice.text,
                _taxRate.text == '0' ? '' : _taxRate.text,
                _reorder.text == '0' ? '' : _reorder.text];
    final hasSelection = (_view == 'warehouses' && _branchId != null) ||
        (_view == 'groups' && _parentGroupId != null) ||
        (_view == 'items' && (_itemGroupId != null || _pickedItemImage != null));
    if (currentFields.any((value) => value.trim().isNotEmpty) || hasSelection) {
      setState(() => _message = 'تم الاحتفاظ بالبيانات الحالية كما هي. احفظ السجل الحالي أولًا قبل بدء سجل جديد.');
      return;
    }
    setState(() {
      _error = null; _message = 'نموذج إضافة جديد جاهز.';
      if (_view == 'warehouses') { _warehouseCode.clear(); _warehouseName.clear(); _address.clear(); _branchId = null; }
      else if (_view == 'groups') { _groupCode.clear(); _groupName.clear(); _parentGroupId = null; }
      else {
        _itemCode.clear(); _itemName.clear(); _barcode.clear(); _unit.text = 'وحدة';
        _purchasePrice.text = '0'; _salePrice.text = '0'; _taxRate.text = '0'; _reorder.text = '0';
        _itemGroupId = null; _expiry = false; _pickedItemImage = null; _pickedItemImageBytes = null;
      }
    });
  }

  Future<void> _saveCurrentRecord() async {
    if (_view == 'warehouses') { await _createWarehouse(); }
    else if (_view == 'groups') { await _createGroup(); }
    else { await _createItem(); }
  }

  Future<void> _previewMasterData() async {
    final rows = _view == 'warehouses' ? _warehouses : _view == 'groups' ? _groups : _items;
    final label = _view == 'warehouses' ? 'المخازن' : _view == 'groups' ? 'مجموعات الأصناف' : 'الأصناف';
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('معاينة $label'),
      content: SizedBox(width: 740, child: rows.isEmpty ? Text('لا توجد بيانات في $label.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: rows.take(100).map((r) => ListTile(
          dense: true,
          title: Text(_view == 'warehouses' ? '${_s(r['warehouse_code'])} — ${_s(r['warehouse_name'])}' :
            _view == 'groups' ? '${_s(r['group_code'])} — ${_s(r['group_name'])}' : '${_s(r['item_code'])} — ${_s(r['item_name'])}'),
          subtitle: Text(r['is_active'] == true ? 'نشط' : 'موقوف'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => ErpKeyboardActionRegistrar(add: _newCurrentRecord, save: _saveCurrentRecord, child: Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(color: const Color(0xFF3E007D), child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('بيانات المخازن والأصناف', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const Text('تعريف المخازن والأصناف الأساسية قبل تسجيل الحركات.', style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _saving ? null : _newCurrentRecord),
            _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _saving || _loading ? null : _saveCurrentRecord),
            _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewMasterData),
            _quickTask('طباعة', Icons.print_outlined, const Color(0xFF4056A1), _previewMasterData),
            _quickTask('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF137C8B), () => setState(() => _message = 'استيراد Excel غير مفعّل في دليل الأصناف والمخازن بعد.')),
            _quickTask('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFB3261E), _previewMasterData),
          ])),
        ]),
      )),
      const SizedBox(height: 10),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x223E007D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('صورة الصنف', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3E007D))),
                  const SizedBox(height: 8),
                  if (_pickedItemImageBytes != null)
                    Center(child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_pickedItemImageBytes!, height: 150, width: 180, fit: BoxFit.contain),
                    ))
                  else
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.add_photo_alternate_outlined, size: 54, color: Color(0xFF3E007D)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _pickItemImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('استيراد صورة من الجهاز'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _pickItemImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('تصوير بالكاميرا'),
                      ),
                      if (_pickedItemImageBytes != null)
                        TextButton.icon(
                          onPressed: _saving ? null : () => setState(() {
                            _pickedItemImage = null;
                            _pickedItemImageBytes = null;
                            _message = 'تم إلغاء اختيار الصورة.';
                          }),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('إزالة الصورة المختارة'),
                        ),
                    ],
                  ),
                  const Text('الحد الأقصى 8 ميجابايت • JPG / PNG / WEBP', style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            TextField(controller: _unit, decoration: const InputDecoration(labelText: 'وحدة القياس')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _purchasePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر الشراء'))),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: _salePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر البيع'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _taxRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'ضريبة الصنف % (0–100)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _reorder, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد إعادة الطلب'))),
            ]),
            CheckboxListTile(value: _expiry, onChanged: (v) => setState(() => _expiry = v ?? false), title: const Text('تتبع تاريخ الصلاحية'), contentPadding: EdgeInsets.zero),
            FilledButton.icon(onPressed: _saving ? null : _createItem, icon: const Icon(Icons.add), label: const Text('حفظ الصنف')),
          ],
        ))),
        Text('الأصناف المسجلة • ' + _items.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ..._items.map((i) => Card(child: ListTile(
          leading: _decodeBytea(i['image_data']) != null
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_decodeBytea(i['image_data'])!, width: 48, height: 48, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: Color(0xFF3E007D))))
              : const Icon(Icons.inventory_2_outlined, color: Color(0xFF3E007D)),
          title: Text(_s(i['item_code']) + ' — ' + _s(i['item_name'])),
          subtitle: Text(_groupLabel(_s(i['group_id'])) + '\nالوحدة: ' + _s(i['base_unit']) + ' • شراء: ' + _money(i['purchase_price']) + ' • بيع: ' + _money(i['sale_price']) + ' • ضريبة: ' + _money(i['tax_rate']) + '%\nحد الطلب: ' + _s(i['reorder_level']) + (_s(i['barcode']).isEmpty ? '' : ' • باركود: ' + _s(i['barcode']))),
          isThreeLine: true,
          trailing: IconButton(onPressed: _saving ? null : () => _toggle(i, true), icon: Icon(i['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
        ))),
      ],
    ],
  )));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
