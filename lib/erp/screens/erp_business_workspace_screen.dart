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

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _name.dispose(); _activity.dispose(); _branchName.dispose();
    _warehouseName.dispose(); _branchCode.dispose(); _warehouseCode.dispose();
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
      ]);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(result[0]);
        _warehouses = List<Map<String, dynamic>>.from(result[1]);
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

  Widget _membersInfo() => _infoPanel('مستخدمين نشاطي', 'سيتم ربط المستخدمين الفرعيين بحساباتهم الموجودة بالفعل في سلسلة. إدارة الصلاحيات ستكون على مستوى الشاشة والإجراء، مع تحديد الفروع والمخازن لكل مستخدم. لا يتم إنشاء حساب دخول مكرر.');
  Widget _stockInfo() => _infoPanel('رصيد مخازني', 'دليل الأصناف يقرأ الأصناف المرجعية المعتمدة في سلسلة فقط. تفعيل الصنف داخل النشاط مستقل، والرصيد الافتتاحي والحركات تخص مخازن هذا النشاط. الأصناف المقترحة تظل مسودات حتى اعتمادها مركزياً.');
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
