import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _workspacePurple = Color(0xFF3E007D);
const _workspaceOrange = Color(0xFFFFA015);

class ErpBusinessWorkspaceScreen extends StatefulWidget {
  const ErpBusinessWorkspaceScreen({super.key});
  @override
  State<ErpBusinessWorkspaceScreen> createState() => _ErpBusinessWorkspaceScreenState();
}

class _ErpBusinessWorkspaceScreenState extends State<ErpBusinessWorkspaceScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _workspaces = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _area = 'الرئيسية';
  String _accountKind = 'customer';
  int _basicTab = 0;
  final _name = TextEditingController();
  final _activity = TextEditingController();
  final _branchName = TextEditingController();
  final _warehouseName = TextEditingController();
  final _branchCode = TextEditingController();
  final _warehouseCode = TextEditingController();
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _platformItems = [];
  List<Map<String, dynamic>> _itemLinks = [];
  List<Map<String, dynamic>> _openings = [];
  List<Map<String, dynamic>> _proposals = [];
  int _stockTab = 0;
  String? _selectedPlatformItemId;
  String? _selectedStockWarehouseId;
  String? _selectedStockItemLinkId;
  final _itemSearch = TextEditingController();
  final _localItemCode = TextEditingController();
  final _reorderLevel = TextEditingController(text: '0');
  final _openingQuantity = TextEditingController();
  final _openingCost = TextEditingController(text: '0');
  final _proposalName = TextEditingController();
  final _proposalNameEn = TextEditingController();
  final _proposalCategory = TextEditingController();
  final _proposalUnit = TextEditingController(text: 'قطعة');
  final _proposalDescription = TextEditingController();
  final _memberPhone = TextEditingController();
  String _memberRole = 'staff';
  final Map<String, bool> _memberPermissions = {
    'workspace.enter': true, 'members.read': false, 'members.manage': false,
    'master.read': true, 'master.manage': false, 'items.read': true, 'items.propose': false,
    'inventory.read': false, 'inventory.manage': false, 'purchases.read': false,
    'purchases.manage': false, 'sales.read': false, 'sales.manage': false,
    'cash.read': false, 'cash.manage': false, 'hr.read': false, 'hr.manage': false,
    'reports.read': false, 'audit.read': false,
  };

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _name.dispose(); _activity.dispose(); _branchName.dispose();
    _warehouseName.dispose(); _branchCode.dispose(); _warehouseCode.dispose(); _memberPhone.dispose();
    _itemSearch.dispose(); _localItemCode.dispose(); _reorderLevel.dispose(); _openingQuantity.dispose(); _openingCost.dispose();
    _proposalName.dispose(); _proposalNameEn.dispose(); _proposalCategory.dispose(); _proposalUnit.dispose(); _proposalDescription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _db.from('erp_business_workspaces').select()
          .eq('is_active', true).order('created_at');
      if (!mounted) return;
      setState(() {
        _workspaces = List<Map<String, dynamic>>.from(rows);
        if (_selected != null) {
          final matches = _workspaces.where((w) => w['id'] == _selected!['id']);
          _selected = matches.isEmpty ? null : matches.first;
        }
        _selected ??= _workspaces.isNotEmpty ? _workspaces.first : null;
        _loading = false;
      });
      if (_selected != null) await _loadStructure();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل مساحات إدارة النشاط: $e'; });
    }
  }

  Future<void> _loadStructure() async {
    final id = _selected?['id']?.toString();
    if (id == null) return;
    try {
      final result = await Future.wait([
        _db.from('erp_business_workspace_branches').select().eq('workspace_id', id).order('name_ar'),
        _db.from('erp_business_workspace_warehouses').select().eq('workspace_id', id).order('name_ar'),
        _db.from('erp_business_workspace_members').select('id,user_id,member_role,is_active,can_open_workspace,member_display_name,permissions').eq('workspace_id', id).order('created_at'),
        _db.from('erp_business_workspace_item_links').select('id,workspace_id,platform_item_id,is_enabled,local_code,reorder_level,erp_items(item_code,item_name,base_unit)').eq('workspace_id', id).order('created_at'),
        _db.from('erp_business_workspace_stock_openings').select('id,warehouse_id,item_link_id,quantity,unit_cost,opening_date').eq('workspace_id', id).order('created_at'),
        _db.from('erp_business_workspace_item_proposals').select('id,name_ar,name_en,proposed_category,unit_name,status,review_note,created_at').eq('workspace_id', id).order('created_at', ascending: false),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(result[0]);
        _warehouses = List<Map<String, dynamic>>.from(result[1]);
        _members = List<Map<String, dynamic>>.from(result[2]);
        _itemLinks = List<Map<String, dynamic>>.from(result[3]);
        _openings = List<Map<String, dynamic>>.from(result[4]);
        _proposals = List<Map<String, dynamic>>.from(result[5]);
        _selectedStockWarehouseId ??= _warehouses.isNotEmpty ? _warehouses.first['id'].toString() : null;
        _selectedStockItemLinkId ??= _itemLinks.isNotEmpty ? _itemLinks.first['id'].toString() : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل الفروع والمخازن: $e');
    }
  }

  Future<void> _createWorkspace() async {
    final name = _name.text.trim();
    if (name.length < 2) { _message('أدخل اسم النشاط بصورة صحيحة.'); return; }
    setState(() => _saving = true);
    try {
      final user = _db.auth.currentUser;
      if (user == null) throw StateError('يجب تسجيل الدخول أولاً.');
      final workspaceId = await _db.rpc('erp_create_business_workspace', params: {
        'p_workspace_name': name,
        'p_activity_type': _activity.text.trim(),
        'p_account_kind': _accountKind,
      });
      final row = await _db.from('erp_business_workspaces').select()
          .eq('id', workspaceId.toString()).single();
      if (!mounted) return;
      setState(() {
        _workspaces.add(Map<String, dynamic>.from(row));
        _selected = Map<String, dynamic>.from(row);
        _name.clear(); _activity.clear(); _area = 'الرئيسية';
      });
      await _loadStructure();
      _message('تم إنشاء مساحة النشاط المستقلة.');
    } catch (e) { _message('لم يتم إنشاء النشاط: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _loadPlatformItems() async {
    try {
      final rows = await _db.from('erp_items')
          .select('id,item_code,item_name,item_name_en,base_unit,category_id')
          .eq('is_active', true).order('item_name').limit(500);
      if (!mounted) return;
      setState(() {
        _platformItems = List<Map<String, dynamic>>.from(rows);
        if (_selectedPlatformItemId == null && _platformItems.isNotEmpty) {
          _selectedPlatformItemId = _platformItems.first['id'].toString();
        }
      });
    } catch (e) {
      _message('تعذر تحميل دليل أصناف سلسلة: $e');
    }
  }

  Future<void> _addItemLink() async {
    final id = _selected?['id']?.toString();
    final itemId = _selectedPlatformItemId;
    if (id == null || itemId == null) { _message('اختر صنفاً من دليل سلسلة أولاً.'); return; }
    try {
      await _db.from('erp_business_workspace_item_links').insert({
        'workspace_id': id,
        'platform_item_id': itemId,
        'local_code': _localItemCode.text.trim().isEmpty ? null : _localItemCode.text.trim(),
        'reorder_level': double.tryParse(_reorderLevel.text.trim()) ?? 0,
        'is_enabled': true,
      });
      _localItemCode.clear(); _reorderLevel.text = '0';
      await _loadStructure();
      _message('تم تفعيل الصنف داخل هذا النشاط فقط.');
    } catch (e) { _message('تعذر ربط الصنف: $e'); }
  }

  Future<void> _recordOpening() async {
    final id = _selected?['id']?.toString();
    final warehouseId = _selectedStockWarehouseId;
    final itemLinkId = _selectedStockItemLinkId;
    final quantity = double.tryParse(_openingQuantity.text.trim());
    final cost = double.tryParse(_openingCost.text.trim()) ?? 0;
    if (id == null || warehouseId == null || itemLinkId == null || quantity == null || quantity < 0 || cost < 0) {
      _message('اختر المخزن والصنف وأدخل كمية وتكلفة صحيحتين.'); return;
    }
    try {
      await _db.rpc('erp_record_business_workspace_opening', params: {
        'p_workspace_id': id, 'p_warehouse_id': warehouseId,
        'p_item_link_id': itemLinkId, 'p_quantity': quantity,
        'p_unit_cost': cost,
      });
      _openingQuantity.clear(); _openingCost.text = '0';
      await _loadStructure();
      _message('تم تسجيل الرصيد الافتتاحي وترحيله لحركة المخزون.');
    } catch (e) { _message('تعذر تسجيل الرصيد الافتتاحي: $e'); }
  }

  Future<void> _proposeItem() async {
    final id = _selected?['id']?.toString();
    final name = _proposalName.text.trim();
    if (id == null || name.length < 2) { _message('أدخل اسم الصنف المقترح.'); return; }
    try {
      await _db.from('erp_business_workspace_item_proposals').insert({
        'workspace_id': id, 'proposed_by': _db.auth.currentUser!.id,
        'name_ar': name,
        'name_en': _proposalNameEn.text.trim().isEmpty ? null : _proposalNameEn.text.trim(),
        'proposed_category': _proposalCategory.text.trim().isEmpty ? null : _proposalCategory.text.trim(),
        'unit_name': _proposalUnit.text.trim().isEmpty ? 'قطعة' : _proposalUnit.text.trim(),
        'description': _proposalDescription.text.trim().isEmpty ? null : _proposalDescription.text.trim(),
        'payload': <String, dynamic>{'source':'business_workspace'},
        'status': 'pending',
      });
      _proposalName.clear(); _proposalNameEn.clear(); _proposalCategory.clear(); _proposalDescription.clear();
      await _loadStructure();
      _message('تم إرسال الصنف للمراجعة المركزية. لن يظهر في دليل سلسلة قبل اعتماده.');
    } catch (e) { _message('تعذر إرسال الصنف المقترح: $e'); }
  }

  Future<void> _addMember() async {
    final id = _selected?['id']?.toString();
    if (id == null || _memberPhone.text.trim().isEmpty) { _message('أدخل رقم هاتف مستخدم مسجل ونشط في سلسلة.'); return; }
    try {
      await _db.rpc('erp_add_business_workspace_member', params: {
        'p_workspace_id': id, 'p_phone': _memberPhone.text.trim(),
        'p_role': _memberRole, 'p_permissions': _memberPermissions,
      });
      _memberPhone.clear(); await _loadStructure(); _message('تم ربط المستخدم بالنشاط وتطبيق صلاحياته.');
    } catch (e) { _message('تعذر ربط المستخدم: $e'); }
  }

  Future<void> _removeMember(String userId) async {
    final id = _selected?['id']?.toString();
    if (id == null) return;
    try {
      await _db.rpc('erp_remove_business_workspace_member', params: {
        'p_workspace_id': id, 'p_member_user_id': userId,
      });
      await _loadStructure(); _message('تم إلغاء وصول المستخدم إلى النشاط.');
    } catch (e) { _message('تعذر إلغاء الوصول: $e'); }
  }

  Future<void> _addBranch() async {
    final id = _selected?['id']?.toString();
    final name = _branchName.text.trim();
    final code = _branchCode.text.trim();
    if (id == null || name.isEmpty || code.isEmpty) { _message('أدخل كود الفرع واسمه.'); return; }
    try {
      await _db.from('erp_business_workspace_branches').insert({
        'workspace_id': id, 'branch_code': code, 'name_ar': name,
      });
      _branchName.clear(); _branchCode.clear();
      await _loadStructure(); _message('تم حفظ الفرع.');
    } catch (e) { _message('تعذر حفظ الفرع: $e'); }
  }

  Future<void> _addWarehouse() async {
    final id = _selected?['id']?.toString();
    final name = _warehouseName.text.trim();
    final code = _warehouseCode.text.trim();
    if (id == null || _branches.isEmpty || name.isEmpty || code.isEmpty) {
      _message('أضف فرعاً أولاً ثم أدخل كود المخزن واسمه.'); return;
    }
    try {
      await _db.from('erp_business_workspace_warehouses').insert({
        'workspace_id': id, 'branch_id': _branches.first['id'],
        'warehouse_code': code, 'name_ar': name,
      });
      _warehouseName.clear(); _warehouseCode.clear();
      await _loadStructure(); _message('تم حفظ المخزن وربطه بالفرع الأول.');
    } catch (e) { _message('تعذر حفظ المخزن: $e'); }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _createDialog() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إنشاء مساحة نشاط مستقلة'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم النشاط *')),
        const SizedBox(height: 10),
        TextField(controller: _activity, decoration: const InputDecoration(labelText: 'نوع النشاط')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _accountKind, decoration: const InputDecoration(labelText: 'نوع الحساب'), items: const [DropdownMenuItem(value: 'customer', child: Text('عميل')), DropdownMenuItem(value: 'supplier', child: Text('مورد')), DropdownMenuItem(value: 'other', child: Text('نوع آخر'))], onChanged: (v) { if (v != null) _accountKind = v; }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : () async { Navigator.pop(ctx); await _createWorkspace(); }, child: const Text('إنشاء')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Directionality(textDirection: TextDirection.rtl, child: Padding(
      padding: const EdgeInsets.all(16),
      child: _error != null && _workspaces.isEmpty
        ? _emptyState(_error!, showRetry: true)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(),
          const SizedBox(height: 14),
          if (_workspaces.isNotEmpty) _workspacePicker(),
          const SizedBox(height: 14),
          Expanded(child: _selected == null ? _noWorkspace() : _areaView()),
        ]),
    ));
  }

  Widget _header() => Row(children: [
    const Icon(Icons.store_mall_directory_rounded, color: _workspacePurple, size: 30),
    const SizedBox(width: 10),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة نشاطي', style: TextStyle(color: _workspacePurple, fontWeight: FontWeight.w900, fontSize: 22)),
      Text('مساحة تشغيل مستقلة مرتبطة بمنصة سلسلة', style: TextStyle(color: Colors.black54, fontSize: 12)),
    ])),
    FilledButton.icon(onPressed: _createDialog, icon: const Icon(Icons.add), label: const Text('نشاط جديد')),
  ]);

  Widget _workspacePicker() => DropdownButtonFormField<String>(
    value: _selected?['id']?.toString(),
    decoration: const InputDecoration(labelText: 'النشاط الحالي', border: OutlineInputBorder()),
    items: _workspaces.map((w) => DropdownMenuItem(
      value: w['id'].toString(), child: Text(w['workspace_name']?.toString() ?? 'نشاط'),
    )).toList(),
    onChanged: (id) async {
      final matches = _workspaces.where((w) => w['id'].toString() == id);
      final item = matches.isEmpty ? null : matches.first;
      setState(() { _selected = item; _area = 'الرئيسية'; });
      await _loadStructure();
    },
  );

  Widget _noWorkspace() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: _emptyState('لم يتم إنشاء مساحة نشاط لهذا الحساب بعد. أنشئ نشاطك الأول لتبدأ في إضافة الفروع والمخازن وإدارة بياناته بصورة مستقلة.'),
  ));

  Widget _emptyState(String text, {bool showRetry = false}) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.storefront_outlined, size: 54, color: _workspacePurple),
      const SizedBox(height: 12), Text(text, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      if (showRetry) OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))
      else FilledButton.icon(onPressed: _createDialog, icon: const Icon(Icons.add), label: const Text('إنشاء نشاط')),
    ],
  ));

  Widget _areaView() {
    if (_area == 'بياناتي الأساسية') return _basicData();
    final sections = <String, List<(String, IconData, String)>>{
      'حركات نشاطي': [
        ('فاتورة شراء / مرتجع شراء', Icons.shopping_bag_outlined, 'purchases'),
        ('فاتورة بيع / مرتجع بيع', Icons.point_of_sale_outlined, 'sales'),
        ('تحويلات وتسويات مخزنية', Icons.inventory_2_outlined, 'inventory'),
        ('صرف وتوريد نقدية', Icons.payments_outlined, 'cash'),
      ],
      'تقارير نشاطي': [
        ('تقارير البيانات الأساسية', Icons.list_alt, 'master'),
        ('تقارير الحركات', Icons.receipt_long, 'documents'),
        ('تقارير مالية وتحليلات', Icons.query_stats, 'finance'),
        ('خروج من إدارة نشاطي', Icons.logout, 'exit'),
      ],
    };
    if (_area == 'الرئيسية') {
      return ListView(children: [
        _sectionTitle('مساحة العمل', 'بيانات وحركات وتقارير خاصة بهذا النشاط فقط'),
        _tileGrid([
          ('بياناتي الأساسية', Icons.business_outlined, 'تهيئة النشاط والفروع والمخازن والمستخدمين والموظفين'),
          ('حركات نشاطي', Icons.swap_horiz_rounded, 'مشتريات ومبيعات وتحويلات وتسويات ونقدية'),
          ('تقارير نشاطي', Icons.analytics_outlined, 'تقارير تشغيلية ومالية خاصة بالنشاط'),
        ]),
        const SizedBox(height: 16),
        _sectionTitle('ملخص النشاط', 'الأرصدة ستظهر بعد إدخال واعتماد الحركات'),
        _tileGrid([
          ('الفروع', Icons.account_tree_outlined, '${_branches.length} فرع'),
          ('المخازن', Icons.warehouse_outlined, '${_warehouses.length} مخزن'),
          ('حالة الربط', Icons.link, 'ربط اختياري مع سلسلة'),
        ]),
      ]);
    }
    if (sections.containsKey(_area)) {
      return ListView(children: [
        _backHeader(_area),
        _tileGrid(sections[_area]!.map((x) => (x.$1, x.$2, x.$3 == 'exit' ? 'العودة إلى قوائم سلسلة' : 'سيتم فتح شاشة مستقلة مع صلاحيات هذا النشاط')).toList()),
        const SizedBox(height: 12),
        const Text('تم تجهيز نقاط الدخول. ترحيل المستندات وتحديث الأرصدة لن يُفعّل قبل استكمال إجراءات الاعتماد المحاسبي والمخزني.', style: TextStyle(color: Colors.black54, height: 1.6)),
      ]);
    }
    return _backHeader(_area);
  }

  Widget _basicData() => Column(children: [
    _backHeader('بياناتي الأساسية'),
    const SizedBox(height: 8),
    Wrap(spacing: 6, runSpacing: 6, children: [
      _tabButton('بيانات النشاط', 0), _tabButton('مستخدمين نشاطي', 1),
      _tabButton('رصيد مخازني', 2), _tabButton('موظفين نشاطي', 3),
    ]),
    const SizedBox(height: 12),
    Expanded(child: IndexedStack(index: _basicTab, children: [
      _businessDetails(), _membersInfo(), _stockInfo(), _employeesInfo(),
    ])),
  ]);

  Widget _tabButton(String label, int index) => ChoiceChip(
    label: Text(label), selected: _basicTab == index,
    selectedColor: const Color(0xFFF0E7FA),
    onSelected: (_) => setState(() => _basicTab = index),
  );

  Widget _businessDetails() => ListView(children: [
    _sectionTitle('بيانات النشاط وفروعه ومخازنه', 'كل سجل ينتمي لمساحة النشاط الحالية'),
    _tileGrid([
      ('بيانات النشاط', Icons.store, _selected?['workspace_name']?.toString() ?? ''),
      ('فروع نشاطي', Icons.account_tree, '${_branches.length} فرع مسجل'),
      ('مخازن نشاطي', Icons.warehouse, '${_warehouses.length} مخزن مسجل'),
    ]),
    const SizedBox(height: 14),
    _sectionTitle('فروع نشاطي', 'أضف فروعاً مستقلة عن فروع سلسلة'),
    Row(children: [
      Expanded(child: TextField(controller: _branchCode, decoration: const InputDecoration(labelText: 'كود الفرع'))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _branchName, decoration: const InputDecoration(labelText: 'اسم الفرع'))),
      IconButton(onPressed: _addBranch, icon: const Icon(Icons.add_circle, color: _workspacePurple)),
    ]),
    ..._branches.map((b) => ListTile(dense: true, leading: const Icon(Icons.account_tree, color: _workspacePurple), title: Text(b['name_ar'].toString()), subtitle: Text(b['branch_code'].toString()))),
    const Divider(),
    _sectionTitle('مخازن نشاطي', 'يرتبط كل مخزن بفرع داخل النشاط'),
    Row(children: [
      Expanded(child: TextField(controller: _warehouseCode, decoration: const InputDecoration(labelText: 'كود المخزن'))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _warehouseName, decoration: const InputDecoration(labelText: 'اسم المخزن'))),
      IconButton(onPressed: _addWarehouse, icon: const Icon(Icons.add_circle, color: _workspacePurple)),
    ]),
    ..._warehouses.map((w) => ListTile(dense: true, leading: const Icon(Icons.warehouse, color: _workspaceOrange), title: Text(w['name_ar'].toString()), subtitle: Text(w['warehouse_code'].toString()))),
  ]);

  Widget _membersInfo() => ListView(children: [
    _sectionTitle('مستخدمين نشاطي', 'اربط حساباً نشطاً موجوداً بالفعل في سلسلة دون إنشاء حساب مكرر'),
    Row(children: [
      Expanded(child: TextField(controller: _memberPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم هاتف المستخدم المسجل'))),
      const SizedBox(width: 8),
      SizedBox(width: 150, child: DropdownButtonFormField<String>(value: _memberRole,
        decoration: const InputDecoration(labelText: 'الدور'),
        items: const [
          DropdownMenuItem(value: 'staff', child: Text('مستخدم')),
          DropdownMenuItem(value: 'manager', child: Text('مدير')),
          DropdownMenuItem(value: 'accountant', child: Text('محاسب')),
          DropdownMenuItem(value: 'warehouse', child: Text('مسؤول مخزن')),
          DropdownMenuItem(value: 'sales', child: Text('مبيعات')),
          DropdownMenuItem(value: 'viewer', child: Text('عرض فقط')),
          DropdownMenuItem(value: 'admin', child: Text('مدير كامل')),
        ], onChanged: (v) { if (v != null) setState(() => _memberRole = v); })),
      IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add_alt_1, color: _workspacePurple)),
    ]),
    const SizedBox(height: 8),
    const Text('الصلاحيات الممنوحة لهذا المستخدم', style: TextStyle(color: _workspacePurple, fontWeight: FontWeight.w900)),
    ..._memberPermissions.entries.map((entry) => SwitchListTile(
      dense: true, contentPadding: EdgeInsets.zero, title: Text(_permissionLabel(entry.key), style: const TextStyle(fontSize: 12)),
      value: entry.value, onChanged: (v) => setState(() => _memberPermissions[entry.key] = v),
    )),
    const Divider(),
    _sectionTitle('المستخدمون المرتبطون', 'إلغاء الوصول لا يحذف حساب المستخدم من سلسلة'),
    ..._members.map((m) => ListTile(
      dense: true, leading: const Icon(Icons.account_circle_outlined, color: _workspacePurple),
      title: Text((m['member_display_name'] ?? 'مستخدم سلسلة').toString()),
      subtitle: Text('${m['member_role']} • ${m['is_active'] == true ? 'نشط' : 'غير نشط'}'),
      trailing: m['member_role'] == 'owner' ? const Text('المالك') : IconButton(
        tooltip: 'إلغاء الوصول', icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent),
        onPressed: () => _removeMember(m['user_id'].toString()),
      ),
    )),
  ]);

  String _permissionLabel(String key) => const {
    'workspace.enter':'الدخول إلى إدارة النشاط',
    'members.read':'عرض المستخدمين','members.manage':'إدارة المستخدمين',
    'master.read':'عرض الفروع والمخازن','master.manage':'إدارة الفروع والمخازن',
    'items.read':'عرض الأصناف','items.propose':'اقتراح أصناف جديدة',
    'inventory.read':'عرض المخزون','inventory.manage':'إدارة الأرصدة والتحويلات والتسويات',
    'purchases.read':'عرض المشتريات','purchases.manage':'إدارة المشتريات والمرتجعات',
    'sales.read':'عرض المبيعات','sales.manage':'إدارة المبيعات والمرتجعات',
    'cash.read':'عرض النقدية','cash.manage':'إدارة الصرف والتوريد',
    'hr.read':'عرض الموظفين','hr.manage':'إدارة الموظفين',
    'reports.read':'عرض التقارير','audit.read':'عرض سجل العمليات',
  }[key] ?? key;
  Widget _stockInfo() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _sectionTitle('رصيد مخازني', 'اختر الأصناف المعتمدة في سلسلة ثم فعّل ما يحتاجه نشاطك فقط'),
    Wrap(spacing: 6, runSpacing: 6, children: [
      ChoiceChip(label: const Text('اختيار الأصناف'), selected: _stockTab == 0, onSelected: (_) async { setState(() => _stockTab = 0); if (_platformItems.isEmpty) await _loadPlatformItems(); }),
      ChoiceChip(label: const Text('افتتاحي مخازني'), selected: _stockTab == 1, onSelected: (_) => setState(() => _stockTab = 1)),
      ChoiceChip(label: const Text('إضافة صنف جديد'), selected: _stockTab == 2, onSelected: (_) => setState(() => _stockTab = 2)),
    ]),
    const SizedBox(height: 10),
    Expanded(child: IndexedStack(index: _stockTab, children: [
      _itemSelectionTab(), _openingStockTab(), _itemProposalTab(),
    ])),
  ]);

  Widget _itemSelectionTab() => ListView(children: [
    TextField(controller: _itemSearch, decoration: const InputDecoration(labelText: 'بحث في أصناف سلسلة', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(
      value: _platformItems.any((x) => x['id'].toString() == _selectedPlatformItemId) ? _selectedPlatformItemId : null,
      isExpanded: true, decoration: const InputDecoration(labelText: 'الصنف المعتمد في سلسلة'),
      items: _platformItems.where((x) {
        final q = _itemSearch.text.trim().toLowerCase();
        return q.isEmpty || ('${x['item_name']} ${x['item_code']}'.toLowerCase().contains(q));
      }).map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text('${x['item_name']} • ${x['item_code'] ?? ''}'))).toList(),
      onChanged: (v) => setState(() => _selectedPlatformItemId = v),
    ),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _localItemCode, decoration: const InputDecoration(labelText: 'كود محلي اختياري'))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _reorderLevel, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد إعادة الطلب'))),
      IconButton(onPressed: _addItemLink, tooltip: 'تفعيل الصنف في نشاطي', icon: const Icon(Icons.add_circle, color: _workspacePurple)),
    ]),
    const Divider(),
    _sectionTitle('أصناف هذا النشاط', '${_itemLinks.length} صنف مرتبط • لا تتم إضافة صنف جديد إلى سلسلة من هنا'),
    ..._itemLinks.map((x) {
      final item = x['erp_items'] is Map ? Map<String,dynamic>.from(x['erp_items']) : <String,dynamic>{};
      return ListTile(dense: true, leading: const Icon(Icons.inventory_2_outlined, color: _workspacePurple),
        title: Text((item['item_name'] ?? 'صنف').toString()),
        subtitle: Text('${item['item_code'] ?? ''} • ${item['base_unit'] ?? ''} • حد الطلب: ${x['reorder_level']}'),
        trailing: Switch(value: x['is_enabled'] == true, onChanged: (v) async {
          try { await _db.from('erp_business_workspace_item_links').update({'is_enabled':v}).eq('id',x['id'].toString()).eq('workspace_id',_selected!['id'].toString()); await _loadStructure(); }
          catch(e) { _message('تعذر تحديث تفعيل الصنف: $e'); }
        }),
      );
    }),
  ]);

  Widget _openingStockTab() => ListView(children: [
    _sectionTitle('الأرصدة الافتتاحية', 'يسجل الرصيد لكل صنف في كل مخزن، ويُنشئ حركة افتتاحية في دفتر المخزون تلقائياً'),
    DropdownButtonFormField<String>(
      value: _warehouses.any((x) => x['id'].toString() == _selectedStockWarehouseId) ? _selectedStockWarehouseId : null,
      decoration: const InputDecoration(labelText: 'المخزن'),
      items: _warehouses.map((w) => DropdownMenuItem(value: w['id'].toString(), child: Text(w['name_ar'].toString()))).toList(),
      onChanged: (v) => setState(() => _selectedStockWarehouseId = v),
    ),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(
      value: _itemLinks.any((x) => x['id'].toString() == _selectedStockItemLinkId && x['is_enabled'] == true) ? _selectedStockItemLinkId : null,
      decoration: const InputDecoration(labelText: 'الصنف'),
      items: _itemLinks.where((x) => x['is_enabled'] == true).map((x) {
        final item = x['erp_items'] is Map ? Map<String,dynamic>.from(x['erp_items']) : <String,dynamic>{};
        return DropdownMenuItem(value: x['id'].toString(), child: Text((item['item_name'] ?? 'صنف').toString()));
      }).toList(),
      onChanged: (v) => setState(() => _selectedStockItemLinkId = v),
    ),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _openingQuantity, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'الكمية الافتتاحية'))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _openingCost, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'تكلفة الوحدة'))),
      IconButton(onPressed: _recordOpening, tooltip: 'حفظ الرصيد', icon: const Icon(Icons.save, color: _workspacePurple)),
    ]),
    const Divider(),
    _sectionTitle('الأرصدة المسجلة', '${_openings.length} رصيد افتتاحي'),
    ..._openings.map((o) {
      final wh = _warehouses.where((x) => x['id'].toString() == o['warehouse_id'].toString()).firstOrNull;
      final link = _itemLinks.where((x) => x['id'].toString() == o['item_link_id'].toString()).firstOrNull;
      final item = link?['erp_items'] is Map ? Map<String,dynamic>.from(link!['erp_items']) : <String,dynamic>{};
      return ListTile(dense:true, title:Text((item['item_name'] ?? 'صنف').toString()),
        subtitle:Text('${wh?['name_ar'] ?? 'مخزن'} • تكلفة الوحدة: ${o['unit_cost']}'),
        trailing:Text(o['quantity'].toString(),style:const TextStyle(fontWeight:FontWeight.bold,color:_workspacePurple)));
    }),
  ]);

  Widget _itemProposalTab() => ListView(children: [
    _sectionTitle('اقتراح صنف جديد', 'يُحفظ كمسودة لدى سلسلة، ولا يدخل الدليل المركزي إلا بعد مراجعة واعتماد صاحب الصلاحية'),
    TextField(controller: _proposalName, decoration: const InputDecoration(labelText: 'اسم الصنف بالعربية *')),
    TextField(controller: _proposalNameEn, decoration: const InputDecoration(labelText: 'اسم الصنف بالإنجليزية')),
    TextField(controller: _proposalCategory, decoration: const InputDecoration(labelText: 'الفئة المقترحة')),
    TextField(controller: _proposalUnit, decoration: const InputDecoration(labelText: 'وحدة القياس')),
    TextField(controller: _proposalDescription, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف والمواصفات')),
    const SizedBox(height: 8),
    Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _proposeItem, icon: const Icon(Icons.send), label: const Text('إرسال للمراجعة'))),
    const Divider(),
    _sectionTitle('طلبات الأصناف السابقة', '${_proposals.length} طلب'),
    ..._proposals.map((p) => ListTile(dense:true, leading:const Icon(Icons.pending_actions,color:_workspaceOrange),
      title:Text(p['name_ar'].toString()), subtitle:Text('${p['proposed_category'] ?? 'بدون فئة'} • ${p['status']}'),
      trailing:p['status']=='pending'?const Text('قيد المراجعة'):Text(p['status'].toString()),
    )),
  ]);
  Widget _employeesInfo() => _infoPanel('موظفين نشاطي', 'هيكل إدارات وأقسام وموظفون مبسطون خاصون بالنشاط، مع كود موظف ومرتب وجدول عمل وإجازات. لا يتم خلطهم بموظفي سلسلة.');

  Widget _infoPanel(String title, String body) => Card(
    elevation: 0, color: const Color(0xFFF8F5FC),
    child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _workspacePurple, fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 10), Text(body, style: const TextStyle(height: 1.8)),
      const SizedBox(height: 12),
      const Text('هذه الوحدة ضمن خطة التنفيذ، ولم يتم تفعيل عملياتها بعد.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700)),
    ])),
  );

  Widget _backHeader(String title) => Row(children: [
    IconButton(onPressed: () => setState(() => _area = 'الرئيسية'), icon: const Icon(Icons.arrow_forward, color: _workspacePurple)),
    Expanded(child: Text(title, style: const TextStyle(color: _workspacePurple, fontSize: 18, fontWeight: FontWeight.w900))),
  ]);

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _workspacePurple, fontWeight: FontWeight.w900, fontSize: 16)),
      Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
    ]),
  );

  Widget _tileGrid(List<(String, IconData, String)> tiles) => LayoutBuilder(builder: (context, c) {
    final count = c.maxWidth > 1050 ? 3 : c.maxWidth > 650 ? 2 : 1;
    return GridView.count(
      crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: count == 1 ? 4.2 : 2.4,
      children: tiles.map((t) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _area = t.$1 == 'بياناتي الأساسية' || t.$1 == 'حركات نشاطي' || t.$1 == 'تقارير نشاطي' ? t.$1 : t.$1),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8E0F0))),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(14)), child: Icon(t.$2, color: _workspacePurple, size: 25)),
            const SizedBox(width: 12),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w900, color: _workspacePurple)),
              Text(t.$3, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ])),
            const Icon(Icons.chevron_left, color: _workspaceOrange),
          ]),
        ),
      )).toList(),
    );
  });
}
