import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'erp_business_workspace_counterparties_panel.dart';

const _workspacePurple = Color(0xFF3E007D);
const _workspaceOrange = Color(0xFFFFA015);

class ErpBusinessWorkspaceScreen extends StatefulWidget {
  final VoidCallback? onExit;
  const ErpBusinessWorkspaceScreen({super.key, this.onExit});
  @override
  State<ErpBusinessWorkspaceScreen> createState() => _ErpBusinessWorkspaceScreenState();
}

class _ErpBusinessWorkspaceScreenState extends State<ErpBusinessWorkspaceScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _workspaces = [];
  List<Map<String, dynamic>> _activityTypes = [];
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
  final _branchNameEn = TextEditingController();
  final _warehouseName = TextEditingController();
  final _warehouseNameEn = TextEditingController();
  final _branchCode = TextEditingController();
  final _warehouseCode = TextEditingController();
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _platformItems = [];
  List<Map<String, dynamic>> _itemLinks = [];
  List<Map<String, dynamic>> _openings = [];
  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _cashMovements = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _employeeLeaves = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _stockMovements = [];
  List<Map<String, dynamic>> _workspaceComparisonRows = [];
  bool _comparisonLoaded = false;
  bool _comparisonLoading = false;
  List<Map<String, dynamic>> _memberLocations = [];
  List<Map<String, dynamic>> _auditRows = [];
  Map<String, dynamic> _workspaceMetrics = {};
  String? _selectedLocationMemberUserId;
  List<Map<String, dynamic>> _draftLines = [];
  String _documentType = 'purchase';
  String? _selectedDocBranchId;
  String? _selectedDocWarehouseId;
  String? _selectedDocItemLinkId;
  final _docCounterparty = TextEditingController();
  final _docNotes = TextEditingController();
  final _docQuantity = TextEditingController(text:'1');
  final _docUnitPrice = TextEditingController(text:'0');
  final _docDiscount = TextEditingController(text:'0');
  final _docTax = TextEditingController(text:'0');
  String _inventoryMode = 'transfer';
  String _adjustDirection = 'increase';
  String? _sourceWarehouseId;
  String? _targetWarehouseId;
  String? _inventoryItemLinkId;
  final _inventoryQuantity = TextEditingController(text:'1');
  final _inventoryUnitCost = TextEditingController(text:'0');
  final _inventoryNotes = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedParentDepartmentId;
  final _departmentCode = TextEditingController();
  final _departmentName = TextEditingController();
  final _employeeName = TextEditingController();
  final _employeeJob = TextEditingController();
  final _employeeSalary = TextEditingController(text: '0');
  final _employeeWorkHours = TextEditingController(text:'08:00 - 17:00');
  final _employeeWeeklyOff = TextEditingController(text:'الجمعة');
  final _employeeAnnualLeave = TextEditingController(text:'21');
  String? _selectedBranchForWarehouse;
  String? _selectedCashBranchId;
  String _cashType = 'receipt';
  String _cashPaymentMethod = 'cash';
  final _cashAmount = TextEditingController();
  final _cashDescription = TextEditingController();
  final _cashCounterparty = TextEditingController();
  final _cashReference = TextEditingController();
  int _stockTab = 0;
  int _memberSubTab = 0;
  int _businessSubTab = 0;
  int _employeeSubTab = 0;
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
  final _policyTaxController = TextEditingController(text: '0');
  String _policyCurrencyCode = 'EGP';
  bool _policyRequireAdjustmentNotes = true;
  bool _policyRequireCashReference = false;
  bool _policyRequireCounterparty = false;
  String _memberRole = 'staff';
  final Map<String, bool> _memberPermissions = {
    'workspace.enter': true, 'members.read': false, 'members.manage': false,
    'master.read': true, 'master.manage': false, 'items.read': true, 'items.propose': false,
    'inventory.read': false, 'inventory.manage': false, 'purchases.read': false,
    'purchases.manage': false, 'sales.read': false, 'sales.manage': false,
    'cash.read': false, 'cash.manage': false, 'hr.read': false, 'hr.manage': false,
    'reports.read': false, 'audit.read': false, 'audit.write': false,
  };

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _policyTaxController.dispose();
    _name.dispose(); _activity.dispose(); _branchName.dispose(); _branchNameEn.dispose(); _warehouseNameEn.dispose();
    _warehouseName.dispose(); _branchCode.dispose(); _warehouseCode.dispose(); _memberPhone.dispose();
    _itemSearch.dispose(); _localItemCode.dispose(); _reorderLevel.dispose(); _openingQuantity.dispose(); _openingCost.dispose();
    _proposalName.dispose(); _proposalNameEn.dispose(); _proposalCategory.dispose(); _proposalUnit.dispose(); _proposalDescription.dispose();
    _cashAmount.dispose(); _cashDescription.dispose(); _cashCounterparty.dispose(); _cashReference.dispose();
    _departmentCode.dispose(); _departmentName.dispose(); _employeeName.dispose(); _employeeJob.dispose(); _employeeSalary.dispose(); _employeeWorkHours.dispose(); _employeeWeeklyOff.dispose(); _employeeAnnualLeave.dispose();
    _docCounterparty.dispose(); _docNotes.dispose(); _docQuantity.dispose(); _docUnitPrice.dispose(); _docDiscount.dispose(); _docTax.dispose();
    _inventoryQuantity.dispose(); _inventoryUnitCost.dispose(); _inventoryNotes.dispose();
    super.dispose();
  }

  void _clearWorkspaceData() {
    _branches = [];
    _warehouses = [];
    _members = [];
    _itemLinks = [];
    _openings = [];
    _proposals = [];
    _cashMovements = [];
    _departments = [];
    _employees = [];
    _employeeLeaves = [];
    _documents = [];
    _stockMovements = [];
    _memberLocations = [];
    _auditRows = [];
    _workspaceMetrics = {};
    _platformItems = [];
    _workspaceComparisonRows = [];
    _comparisonLoaded = false;
    _comparisonLoading = false;
    _selectedLocationMemberUserId = null;
    _selectedDocBranchId = null;
    _selectedDocWarehouseId = null;
    _selectedDocItemLinkId = null;
    _selectedCashBranchId = null;
    _selectedBranchForWarehouse = null;
    _selectedStockWarehouseId = null;
    _selectedStockItemLinkId = null;
    _inventoryItemLinkId = null;
    _sourceWarehouseId = null;
    _targetWarehouseId = null;
    _selectedPlatformItemId = null;
    _draftLines.clear();
    _basicTab = 0;
    _businessSubTab = 0;
    _memberSubTab = 0;
    _stockTab = 0;
  }

  Future<void> _load() async {
    final previousWorkspaceId = _selected?['id']?.toString();
    setState(() { _loading = true; _error = null; });
    try {
      final activityRows = await _safeRows(() => _db.from('activity_types').select('code,name,name_en').eq('is_active',true).order('name'));
      final baseQuery = _db.from('erp_business_workspaces').select().eq('is_active', true);
      final rows = _platformObserver ? await baseQuery.order('created_at') : await baseQuery.or('owner_user_id.eq.$currentUserId,linked_profile_id.eq.$currentUserId').order('created_at');
      if (!mounted) return;
      setState(() {
        _activityTypes = activityRows;
        _workspaces = List<Map<String, dynamic>>.from(rows);
        if (_selected != null) {
          final matches = _workspaces.where((w) => w['id'] == _selected!['id']);
          _selected = matches.isEmpty ? null : matches.first;
        }
        _selected ??= _workspaces.isNotEmpty ? _workspaces.first : null;
        if (previousWorkspaceId != _selected?['id']?.toString()) _clearWorkspaceData();
        _loading = false;
      });
      _syncWorkspacePolicyFromSelection();
      if (_selected != null) await _loadStructure();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل مساحات إدارة النشاط: $e'; });
    }
  }

  Future<List<Map<String, dynamic>>> _safeRows(dynamic Function() request) async {
    try {
      final rows = await request();
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      // A restricted member may not have access to every module table.
      // Keep the other permitted modules available instead of failing the whole workspace.
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadStructure() async {
    final id = _selected?['id']?.toString();
    if (id == null) return;
    try {
      final result = await Future.wait<List<Map<String, dynamic>>>([
        _safeRows(() => _db.from('erp_business_workspace_branches').select().eq('workspace_id', id).order('name_ar')),
        _safeRows(() => _db.from('erp_business_workspace_warehouses').select().eq('workspace_id', id).order('name_ar')),
        _safeRows(() => _db.from('erp_business_workspace_members').select('id,user_id,member_role,is_active,can_open_workspace,member_display_name,permissions').eq('workspace_id', id).order('created_at')),
        _safeRows(() => _db.from('erp_business_workspace_item_links').select('id,workspace_id,platform_item_id,is_enabled,local_code,reorder_level,erp_items(item_code,item_name,base_unit,erp_item_categories(category_name,activity_code))').eq('workspace_id', id).order('created_at')),
        _safeRows(() => _db.from('erp_business_workspace_stock_openings').select('id,warehouse_id,item_link_id,quantity,unit_cost,opening_date').eq('workspace_id', id).order('created_at')),
        _safeRows(() => _db.from('erp_business_workspace_item_proposals').select('id,name_ar,name_en,proposed_category,unit_name,status,review_note,created_at').eq('workspace_id', id).order('created_at', ascending: false)),
        _safeRows(() => _db.from('erp_business_workspace_cash_movements').select('id,movement_no,movement_type,movement_date,amount,description,counterparty_name,payment_method,reference_no').eq('workspace_id', id).order('movement_date', ascending: false).limit(200)),
        _safeRows(() => _db.from('erp_business_workspace_departments').select('id,parent_id,department_code,name_ar,is_active').eq('workspace_id', id).order('name_ar')),
        _safeRows(() => _db.from('erp_business_workspace_employees').select('id,department_id,employee_code,full_name,job_title,monthly_salary,is_active').eq('workspace_id', id).order('full_name')),
        _safeRows(() => _db.from('erp_business_workspace_documents').select('id,document_no,document_type,document_date,counterparty_name,status,total,created_at').eq('workspace_id', id).order('created_at', ascending: false).limit(200)),
        _safeRows(() => _db.from('erp_business_workspace_stock_movements').select('id,warehouse_id,item_link_id,movement_type,quantity_in,quantity_out,unit_cost,movement_date').eq('workspace_id', id).order('movement_date', ascending: false).limit(1000)),
        _safeRows(() => _db.from('erp_business_workspace_member_locations').select('id,user_id,access_scope,branch_id,warehouse_id,is_allowed').eq('workspace_id', id)),
        _safeRows(() => _db.from('erp_business_workspace_audit_log').select('id,actor_user_id,action,entity_type,entity_id,details,created_at').eq('workspace_id', id).order('created_at', ascending:false).limit(200)),
        _safeRows(() => _db.from('erp_business_workspace_employee_leaves').select('id,employee_id,leave_type,start_date,end_date,status,notes,created_by,reviewed_by,reviewed_at').eq('workspace_id', id).order('start_date', ascending:false).limit(300)),
      ]);
      if (!mounted || _selected?['id']?.toString() != id) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(result[0]);
        _selectedCashBranchId = _branches.any((b)=>b['id'].toString()==_selectedCashBranchId) ? _selectedCashBranchId : (_branches.isNotEmpty ? _branches.first['id'].toString() : null);
        _warehouses = List<Map<String, dynamic>>.from(result[1]);
        _members = List<Map<String, dynamic>>.from(result[2]);
        _itemLinks = List<Map<String, dynamic>>.from(result[3]);
        _openings = List<Map<String, dynamic>>.from(result[4]);
        _proposals = List<Map<String, dynamic>>.from(result[5]);
        _cashMovements = List<Map<String, dynamic>>.from(result[6]);
        _departments = List<Map<String, dynamic>>.from(result[7]);
        _employees = List<Map<String, dynamic>>.from(result[8]);
        _documents = List<Map<String, dynamic>>.from(result[9]);
        _stockMovements = List<Map<String, dynamic>>.from(result[10]);
        _memberLocations = List<Map<String, dynamic>>.from(result[11]);
        _auditRows = List<Map<String, dynamic>>.from(result[12]);
        _employeeLeaves = List<Map<String, dynamic>>.from(result[13]);
        final selectableMembers = _members.where((m)=>m['member_role']!='owner').toList();
        _selectedLocationMemberUserId = selectableMembers.any((m)=>m['user_id'].toString()==_selectedLocationMemberUserId) ? _selectedLocationMemberUserId : (selectableMembers.isNotEmpty ? selectableMembers.first['user_id'].toString() : null);
        _selectedDocBranchId = _branches.any((x) => x['id'].toString() == _selectedDocBranchId) ? _selectedDocBranchId : (_branches.isNotEmpty ? _branches.first['id'].toString() : null);
        final documentBranchWarehouses = _warehouses.where((x)=>x['branch_id']?.toString()==_selectedDocBranchId).toList();
        _selectedDocWarehouseId = documentBranchWarehouses.any((x) => x['id'].toString() == _selectedDocWarehouseId)
            ? _selectedDocWarehouseId
            : (documentBranchWarehouses.isNotEmpty ? documentBranchWarehouses.first['id'].toString() : null);
        _selectedDocItemLinkId = _itemLinks.any((x) => x['id'].toString() == _selectedDocItemLinkId && x['is_enabled'] == true) ? _selectedDocItemLinkId : (_itemLinks.where((x) => x['is_enabled'] == true).isNotEmpty ? _itemLinks.firstWhere((x) => x['is_enabled'] == true)['id'].toString() : null);
        _inventoryItemLinkId = _itemLinks.any((x) => x['id'].toString() == _inventoryItemLinkId && x['is_enabled'] == true) ? _inventoryItemLinkId : (_itemLinks.where((x) => x['is_enabled'] == true).isNotEmpty ? _itemLinks.firstWhere((x) => x['is_enabled'] == true)['id'].toString() : null);
        _sourceWarehouseId = _warehouses.any((x) => x['id'].toString() == _sourceWarehouseId) ? _sourceWarehouseId : (_warehouses.isNotEmpty ? _warehouses.first['id'].toString() : null);
        final transferTargets = _warehouses.where((x)=>x['id'].toString()!=_sourceWarehouseId).toList();
        _targetWarehouseId = transferTargets.any((x)=>x['id'].toString()==_targetWarehouseId)
            ? _targetWarehouseId
            : (transferTargets.isNotEmpty?transferTargets.first['id'].toString():null);
        _selectedDepartmentId = _departments.any((x) => x['id'].toString() == _selectedDepartmentId) ? _selectedDepartmentId : (_departments.isNotEmpty ? _departments.first['id'].toString() : null);
        _selectedBranchForWarehouse = _branches.any((x) => x['id'].toString() == _selectedBranchForWarehouse) ? _selectedBranchForWarehouse : (_branches.isNotEmpty ? _branches.first['id'].toString() : null);
        _selectedStockWarehouseId = _warehouses.any((x) => x['id'].toString() == _selectedStockWarehouseId) ? _selectedStockWarehouseId : (_warehouses.isNotEmpty ? _warehouses.first['id'].toString() : null);
        _selectedStockItemLinkId = _itemLinks.any((x) => x['id'].toString() == _selectedStockItemLinkId) ? _selectedStockItemLinkId : (_itemLinks.isNotEmpty ? _itemLinks.first['id'].toString() : null);
      });
      await _loadWorkspaceMetrics(id);
    } catch (e) {
      if (mounted && _selected?['id']?.toString() == id) {
        setState(() => _error = 'تعذر تحميل الفروع والمخازن: $e');
      }
    }
  }

  Future<void> _loadWorkspaceMetrics(String workspaceId) async {
    try {
      final raw = await _db.rpc('erp_get_business_workspace_metrics', params: {'p_workspace_id': workspaceId});
      if (!mounted || _selected?['id']?.toString() != workspaceId) return;
      setState(() => _workspaceMetrics = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
    } catch (_) {
      if (mounted && _selected?['id']?.toString() == workspaceId) setState(() => _workspaceMetrics = {});
    }
  }

  String _metricCount(String key, [String fallback = '0']) {
    final value = _workspaceMetrics[key];
    if (value == null) return fallback;
    if (value is num) return value.toStringAsFixed(0);
    return value.toString();
  }

  String _metricMoney(String key) {
    final value = _workspaceMetrics[key];
    if (value == null) return '—';
    final amount = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (amount == null) return '—';
    return '${amount.toStringAsFixed(2)} $_policyCurrencyCode';
  }

  bool get _isWorkspaceOwner =>
      _selected?['owner_user_id']?.toString() == _db.auth.currentUser?.id;
  bool _canWorkspacePermission(String permission) {
    if (_isWorkspaceOwner) return true;
    final currentUserId = _db.auth.currentUser?.id;
    final matches = _members.where((m) => m['user_id']?.toString() == currentUserId);
    if (matches.isEmpty) return false;
    final member = matches.first;
    if (member['is_active'] != true || member['can_open_workspace'] != true) return false;
    if (member['member_role'] == 'admin') return true;
    final raw = member['permissions'];
    final permissions = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (permissions['*'] == true || permissions[permission] == true) return true;
    if (permission.endsWith('.read')) {
      final manageKey = permission.replaceFirst('.read', '.manage');
      return permissions[manageKey] == true;
    }
    return false;
  }

  bool _canAnyWorkspacePermission(List<String> permissions) =>
      permissions.any(_canWorkspacePermission);

  bool _canOpenWorkspaceArea(String area) {
    switch (area) {
      case 'بياناتي الأساسية':
      case 'بيانات نشاطي':
        return _canWorkspacePermission('master.read');
      case 'مستخدمين نشاطي':
        return _canWorkspacePermission('members.read');
      case 'رصيد مخازني':
        return _canAnyWorkspacePermission(['master.read','items.read','inventory.read','items.propose']);
      case 'موظفين نشاطي':
        return _canWorkspacePermission('hr.read');
      case 'فاتورة شراء / مرتجع شراء':
        return _canWorkspacePermission('purchases.read');
      case 'فاتورة بيع / مرتجع بيع':
        return _canWorkspacePermission('sales.read');
      case 'تحويلات وتسويات مخزنية':
        return _canWorkspacePermission('inventory.read');
      case 'صرف وتوريد نقدية':
        return _canWorkspacePermission('cash.read');
      case 'تقارير البيانات الأساسية':
      case 'تقارير الحركات':
      case 'تقارير مالية وتحليلات':
        return _canWorkspacePermission('reports.read');
      case 'خروج من إدارة نشاطي':
        return true;
      default:
        return true;
    }
  }

  Widget _workspacePermissionDenied(String area) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 42, color: _workspacePurple),
          const SizedBox(height: 10),
          Text('لا توجد صلاحية لفتح $area', style: const TextStyle(fontWeight: FontWeight.w900, color: _workspacePurple)),
          const SizedBox(height: 6),
          const Text('اطلب من مالك النشاط تفعيل صلاحية العرض أو الإدارة المناسبة لحسابك.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => setState(() => _area = 'الرئيسية'), icon: const Icon(Icons.arrow_forward), label: const Text('العودة للرئيسية')),
        ]),
      )),
    ),
  );

  Map<String, dynamic> get _workspacePolicy {
    final settings = _selected?['settings'];
    if (settings is! Map) return <String, dynamic>{};
    final policy = settings['workspace_policy'];
    return policy is Map ? Map<String, dynamic>.from(policy) : <String, dynamic>{};
  }

  void _syncWorkspacePolicyFromSelection() {
    final policy = _workspacePolicy;
    _policyTaxController.text = (policy['default_tax_rate'] ?? 0).toString();
    const currencies = {'EGP', 'USD', 'EUR', 'SAR', 'AED'};
    _policyCurrencyCode = currencies.contains(policy['currency_code'])
        ? policy['currency_code'].toString() : 'EGP';
    _policyRequireAdjustmentNotes = policy['require_adjustment_notes'] != false;
    _policyRequireCashReference = policy['require_cash_reference'] == true;
    _policyRequireCounterparty = policy['require_counterparty_on_documents'] == true;
    _docTax.text = _policyTaxController.text;
  }

  Future<void> _saveWorkspacePolicies() async {
    final workspaceId = _selected?['id']?.toString();
    final taxRate = double.tryParse(_policyTaxController.text.trim());
    if (workspaceId == null || taxRate == null || taxRate < 0 || taxRate > 100) {
      _message('أدخل نسبة ضريبة افتراضية صحيحة من 0 إلى 100.');
      return;
    }
    if (!_isWorkspaceOwner) {
      _message('تعديل سياسات النشاط متاح لمالك النشاط فقط.');
      return;
    }
    try {
      await _db.rpc('erp_set_business_workspace_settings', params: {
        'p_workspace_id': workspaceId,
        'p_settings': <String, dynamic>{
          'default_tax_rate': taxRate,
          'currency_code': _policyCurrencyCode,
          'require_adjustment_notes': _policyRequireAdjustmentNotes,
          'require_cash_reference': _policyRequireCashReference,
          'require_counterparty_on_documents': _policyRequireCounterparty,
        },
      });
      final row = await _db.from('erp_business_workspaces').select()
          .eq('id', workspaceId).single();
      if (!mounted) return;
      setState(() {
        _selected = Map<String, dynamic>.from(row);
        final index = _workspaces.indexWhere((w) => w['id'].toString() == workspaceId);
        if (index >= 0) _workspaces[index] = Map<String, dynamic>.from(row);
      });
      _syncWorkspacePolicyFromSelection();
      _message('تم حفظ سياسات النشاط وتطبيقها على العمليات الجديدة.');
    } catch (e) {
      _message('تعذر حفظ سياسات النشاط: $e');
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

  void _addDocumentLine() {
    final itemId = _selectedDocItemLinkId;
    final qty = double.tryParse(_docQuantity.text.trim());
    final price = double.tryParse(_docUnitPrice.text.trim());
    final discount = double.tryParse(_docDiscount.text.trim()) ?? 0;
    if (itemId == null || qty == null || qty <= 0 || price == null || price < 0 || discount < 0 || discount > qty*price) {
      _message('اختر صنفاً وأدخل كمية وسعراً وخصماً صحيحين.'); return;
    }
    setState(() {
      _draftLines.add({'item_link_id':itemId,'quantity':qty,'unit_price':price,'discount':discount});
      _docQuantity.text='1'; _docUnitPrice.text='0'; _docDiscount.text='0';
    });
  }

  Future<void> _createWorkspaceDocument() async {
    final id = _selected?['id']?.toString();
    final branchId = _selectedDocBranchId;
    final warehouseId = _selectedDocWarehouseId;
    final selectedDocumentWarehouse=_warehouses.where((w)=>w['id'].toString()==warehouseId).toList();
    if (id == null || branchId == null || warehouseId == null || _draftLines.isEmpty ||
        selectedDocumentWarehouse.isEmpty || selectedDocumentWarehouse.first['branch_id']?.toString()!=branchId) {
      _message('اختر فرعاً ومخزناً تابعاً له وأضف صنفاً واحداً على الأقل.'); return;
    }
    final taxRate = double.tryParse(_docTax.text.trim()) ?? 0;
    if (taxRate < 0 || taxRate > 100) { _message('نسبة الضريبة يجب أن تكون من 0 إلى 100.'); return; }
    if (_policyRequireCounterparty && _docCounterparty.text.trim().isEmpty) { _message('سياسة النشاط تشترط إدخال اسم العميل أو المورد.'); return; }
    final taxableSubtotal = _draftLines.fold<double>(0, (sum, line) {
      final quantity = (line['quantity'] as num).toDouble();
      final price = (line['unit_price'] as num).toDouble();
      final discount = (line['discount'] as num).toDouble();
      return sum + quantity * price - discount;
    });
    final tax = taxableSubtotal * taxRate / 100;
    try {
      final now = DateTime.now();
      final prefix = _documentType.toUpperCase();
      final docNo = 'ACT-$prefix-${now.microsecondsSinceEpoch}';
      await _db.rpc('erp_create_business_workspace_document', params: {
        'p_workspace_id':id,'p_branch_id':branchId,'p_warehouse_id':warehouseId,
        'p_document_no':docNo,'p_document_type':_documentType,
        'p_document_date':now.toIso8601String().substring(0,10),
        'p_counterparty_name':_docCounterparty.text.trim(),
        'p_notes':_docNotes.text.trim(),
        'p_lines':_draftLines,
        'p_tax':tax,
      });
      setState(() { _draftLines.clear(); });
      _docCounterparty.clear(); _docNotes.clear(); _docTax.text = _policyTaxController.text.trim().isEmpty ? '0' : _policyTaxController.text.trim();
      await _loadStructure();
      _message('تم إنشاء المستند كمسودة رقم $docNo. لم يتغير المخزون بعد.');
    } catch(e) { _message('تعذر إنشاء المستند: $e'); }
  }

  Future<void> _submitWorkspaceDocument(String documentId) async {
    try {
      await _db.rpc('erp_submit_business_workspace_document',params:{'p_document_id':documentId});
      await _loadStructure();
      _message('تم إرسال المستند للاعتماد. لم يتغير المخزون بعد.');
    } catch(e) { _message('تعذر إرسال المستند للاعتماد: $e'); }
  }

  Future<void> _approveWorkspaceDocument(String documentId) async {
    try {
      await _db.rpc('erp_approve_business_workspace_document',params:{
        'p_document_id':documentId,'p_approval_note':null,
      });
      await _loadStructure();
      _message('تم اعتماد المستند. يمكنك ترحيله الآن.');
    } catch(e) { _message('تعذر اعتماد المستند: $e'); }
  }

  Future<void> _postWorkspaceDocument(String documentId) async {
    try {
      await _db.rpc('erp_post_business_workspace_document',params:{'p_document_id':documentId});
      await _loadStructure();
      _message('تم ترحيل المستند المعتمد إلى حركة مخزون النشاط.');
    } catch(e) { _message('لم يتم ترحيل المستند: $e'); }
  }

  Future<void> _saveInventoryMovement() async {
    final workspaceId = _selected?['id']?.toString();
    final itemId = _inventoryItemLinkId;
    final qty = double.tryParse(_inventoryQuantity.text.trim());
    final cost = double.tryParse(_inventoryUnitCost.text.trim()) ?? 0;
    if(workspaceId==null||itemId==null||qty==null||qty<=0||cost<0||_sourceWarehouseId==null){
      _message('اختر الصنف والمخزن وأدخل كمية صحيحة.'); return;
    }
    if (_inventoryMode == 'adjustment' && _policyRequireAdjustmentNotes && _inventoryNotes.text.trim().isEmpty) { _message('سياسة النشاط تشترط كتابة سبب التسوية.'); return; }
    final now=DateTime.now();
    final docNo='ACT-STK-${now.microsecondsSinceEpoch}';
    try{
      if(_inventoryMode=='transfer'){
        if(_targetWarehouseId==null||_targetWarehouseId==_sourceWarehouseId){_message('اختر مخزناً مستهدفاً مختلفاً.');return;}
        await _db.rpc('erp_transfer_business_workspace_stock',params:{
          'p_workspace_id':workspaceId,'p_source_warehouse_id':_sourceWarehouseId,
          'p_target_warehouse_id':_targetWarehouseId,'p_item_link_id':itemId,
          'p_quantity':qty,'p_document_no':docNo,
          'p_movement_date':now.toIso8601String().substring(0,10),
          'p_notes':_inventoryNotes.text.trim(),
        });
      }else{
        await _db.rpc('erp_adjust_business_workspace_stock',params:{
          'p_workspace_id':workspaceId,'p_warehouse_id':_sourceWarehouseId,
          'p_item_link_id':itemId,'p_direction':_adjustDirection,
          'p_quantity':qty,'p_unit_cost':cost,'p_document_no':docNo,
          'p_movement_date':now.toIso8601String().substring(0,10),
          'p_notes':_inventoryNotes.text.trim(),
        });
      }
      _inventoryQuantity.text='1';_inventoryUnitCost.text='0';_inventoryNotes.clear();
      await _loadStructure();_message('تم ترحيل الحركة المخزنية وتحديث رصيد المخازن.');
    }catch(e){_message('تعذر ترحيل الحركة المخزنية: $e');}
  }

  Future<void> _addDepartment() async {
    final id = _selected?['id']?.toString();
    final code = _departmentCode.text.trim();
    final name = _departmentName.text.trim();
    if (id == null || code.isEmpty || name.isEmpty) { _message('أدخل كود الإدارة واسمها.'); return; }
    try {
      await _db.from('erp_business_workspace_departments').insert({
        'workspace_id':id,'department_code':code,'name_ar':name,'parent_id':_selectedParentDepartmentId,
      });
      _departmentCode.clear(); _departmentName.clear();
      await _loadStructure(); _message('تم إضافة الإدارة / القسم.');
    } catch(e) { _message('تعذر حفظ الإدارة: $e'); }
  }

  Future<void> _addEmployeeLeave() async {
    final workspaceId=_selected?['id']?.toString();
    final activeEmployees=_employees.where((e)=>e['is_active']==true).toList();
    if(workspaceId==null||activeEmployees.isEmpty){_message('أضف موظفاً نشطاً أولاً قبل تسجيل الإجازات.');return;}
    String? employeeId=activeEmployees.first['id'].toString();
    String leaveType='annual';
    DateTime? startDate;
    DateTime? endDate;
    final notes=TextEditingController();
    String fmt(DateTime? value)=>value==null?'اختر التاريخ':'${value.day.toString().padLeft(2,'0')}-${value.month.toString().padLeft(2,'0')}-${value.year}';
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
      title:const Text('تسجيل إجازة موظف'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(
          value:employeeId,
          decoration:const InputDecoration(labelText:'الموظف'),
          items:activeEmployees.map((e)=>DropdownMenuItem(value:e['id'].toString(),child:Text(e['full_name'].toString()))).toList(),
          onChanged:(v)=>setDialogState(()=>employeeId=v),
        ),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(
          value:leaveType,
          decoration:const InputDecoration(labelText:'نوع الإجازة'),
          items:const [
            DropdownMenuItem(value:'annual',child:Text('سنوية')),
            DropdownMenuItem(value:'sick',child:Text('مرضية')),
            DropdownMenuItem(value:'unpaid',child:Text('بدون أجر')),
            DropdownMenuItem(value:'emergency',child:Text('عارضة')),
            DropdownMenuItem(value:'other',child:Text('أخرى')),
          ],
          onChanged:(v){if(v!=null)setDialogState(()=>leaveType=v);},
        ),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:()async{
            final picked=await showDatePicker(context:dialogContext,initialDate:startDate??DateTime.now(),firstDate:DateTime(2000),lastDate:DateTime(2100));
            if(picked!=null)setDialogState(() { startDate=picked; if(endDate!=null&&endDate!.isBefore(picked)) endDate=null; });
          },icon:const Icon(Icons.calendar_today),label:Text('من: ${fmt(startDate)}'))),
          const SizedBox(width:6),
          Expanded(child:OutlinedButton.icon(onPressed:()async{
            final picked=await showDatePicker(context:dialogContext,initialDate:endDate??startDate??DateTime.now(),firstDate:startDate??DateTime(2000),lastDate:DateTime(2100));
            if(picked!=null)setDialogState(()=>endDate=picked);
          },icon:const Icon(Icons.event),label:Text('إلى: ${fmt(endDate)}'))),
        ]),
        TextField(controller:notes,decoration:const InputDecoration(labelText:'ملاحظات (اختياري)'),maxLines:2),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),
        FilledButton.icon(onPressed:employeeId==null||startDate==null||endDate==null||endDate!.isBefore(startDate!)?null:()async{
          try{
            await _db.from('erp_business_workspace_employee_leaves').insert({
              'workspace_id':workspaceId,'employee_id':employeeId,'leave_type':leaveType,
              'start_date':startDate!.toIso8601String().substring(0,10),
              'end_date':endDate!.toIso8601String().substring(0,10),
              'notes':notes.text.trim().isEmpty?null:notes.text.trim(),
              'created_by':_db.auth.currentUser!.id,
            });
            if(!mounted)return;
            Navigator.pop(dialogContext);
            await _loadStructure();
            _message('تم تسجيل طلب الإجازة.');
          }catch(e){_message('تعذر تسجيل الإجازة: $e');}
        },icon:const Icon(Icons.save),label:const Text('حفظ الإجازة')),
      ],
    )));
    notes.dispose();
  }

  Future<void> _reviewEmployeeLeave(String leaveId,String status) async {
    try{
      await _db.from('erp_business_workspace_employee_leaves').update({
        'status':status,'reviewed_by':_db.auth.currentUser!.id,'reviewed_at':DateTime.now().toIso8601String(),
      }).eq('id',leaveId).eq('workspace_id',_selected!['id'].toString());
      await _loadStructure();
      _message(status=='approved'?'تم اعتماد الإجازة.':'تم رفض طلب الإجازة.');
    }catch(e){_message('تعذر تحديث طلب الإجازة: $e');}
  }

  Future<void> _addEmployee() async {
    final id = _selected?['id']?.toString();
    final name = _employeeName.text.trim();
    final salary = double.tryParse(_employeeSalary.text.trim()) ?? 0;
    if (id == null || name.length < 2 || salary < 0) { _message('أدخل اسم الموظف ومرتباً صحيحاً.'); return; }
    try {
      final code = 'EMP-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
      await _db.from('erp_business_workspace_employees').insert({
        'workspace_id':id,'department_id':_selectedDepartmentId,
        'employee_code':code,'full_name':name,
        'job_title':_employeeJob.text.trim().isEmpty?null:_employeeJob.text.trim(),
        'monthly_salary':salary,
        'work_schedule':<String,dynamic>{'type':'standard','hours':_employeeWorkHours.text.trim(),'weekly_off':_employeeWeeklyOff.text.trim()},
        'leave_policy':<String,dynamic>{'annual_days':int.tryParse(_employeeAnnualLeave.text.trim())??21},
      });
      _employeeName.clear(); _employeeJob.clear(); _employeeSalary.text='0';
      await _loadStructure(); _message('تم تسجيل الموظف برقم $code.');
    } catch(e) { _message('تعذر حفظ الموظف: $e'); }
  }

  Future<void> _saveCashMovement() async {
    final id = _selected?['id']?.toString();
    final amount = double.tryParse(_cashAmount.text.trim());
    final description = _cashDescription.text.trim();
    if (id == null || amount == null || amount <= 0 || description.isEmpty) {
      _message('أدخل مبلغاً صحيحاً وبياناً للحركة.'); return;
    }
    if (_policyRequireCashReference && _cashReference.text.trim().isEmpty) { _message('سياسة النشاط تشترط إدخال رقم مرجعي للحركة النقدية.'); return; }
    try {
      final now = DateTime.now();
      final datePart = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
      final movementNo = 'ACT-$datePart-${now.microsecondsSinceEpoch.toString().substring(8)}';
      await _db.from('erp_business_workspace_cash_movements').insert({
        'workspace_id': id,
        'branch_id': _selectedCashBranchId,
        'movement_no': movementNo,
        'movement_type': _cashType,
        'movement_date': now.toIso8601String().substring(0,10),
        'amount': amount,
        'description': description,
        'counterparty_name': _cashCounterparty.text.trim().isEmpty ? null : _cashCounterparty.text.trim(),
        'payment_method': _cashPaymentMethod,
        'reference_no': _cashReference.text.trim().isEmpty ? null : _cashReference.text.trim(),
        'created_by': _db.auth.currentUser!.id,
      });
      _cashAmount.clear(); _cashDescription.clear(); _cashCounterparty.clear(); _cashReference.clear();
      await _loadStructure();
      _message('تم حفظ حركة النقدية.'); 
    } catch (e) { _message('تعذر حفظ حركة النقدية: $e'); }
  }

  Future<void> _loadPlatformItems() async {
    final workspaceId = _selected?['id']?.toString();
    if (workspaceId == null) return;
    try {
      final rows = await _db.rpc('erp_get_business_workspace_catalog_items',params:{
        'p_workspace_id':workspaceId,
      });
      if (!mounted || _selected?['id']?.toString()!=workspaceId) return;
      final catalog = List<Map<String,dynamic>>.from(rows as List);
      setState(() {
        _platformItems = catalog.map((item) => <String,dynamic>{
          ...item,
          'erp_item_categories': item['category_name']==null ? null : {'category_name':item['category_name']},
        }).toList();
        if (!_platformItems.any((x)=>x['id'].toString()==_selectedPlatformItemId)) {
          _selectedPlatformItemId = _platformItems.isEmpty ? null : _platformItems.first['id'].toString();
        }
      });
    } catch (e) {
      if (mounted && _selected?['id']?.toString()==workspaceId) {
        _message('تعذر تحميل دليل أصناف سلسلة وفق صلاحيات النشاط: $e');
      }
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

  Future<void> _loadWorkspaceStockComparison() async {
    final workspaceId=_selected?['id']?.toString();
    if(workspaceId==null)return;
    setState(()=>_comparisonLoading=true);
    try{
      final rows=await _db.rpc('erp_get_workspace_silsila_stock',params:{
        'p_workspace_id':workspaceId,'p_item_link_id':null,
      });
      if(!mounted || _selected?['id']?.toString()!=workspaceId)return;
      setState((){
        _workspaceComparisonRows=List<Map<String,dynamic>>.from(rows as List);
        _comparisonLoaded=true;
        _comparisonLoading=false;
      });
    }catch(e){
      if(!mounted || _selected?['id']?.toString()!=workspaceId)return;
      setState(()=>_comparisonLoading=false);
      _message('تعذر مقارنة المخزون مع سلسلة: $e');
    }
  }

  Widget _workspaceStockComparisonTab() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    _sectionTitle('مقارنة مخزوني مع سلسلة','يعرض رصيد نشاطك مقابل المتاح في مخازن سلسلة بعد خصم الكميات المحجوزة'),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_comparisonLoading?null:_loadWorkspaceStockComparison,icon:const Icon(Icons.refresh),label:const Text('تحديث المقارنة'))),
    const SizedBox(height:8),
    Expanded(child:_comparisonLoading?const Center(child:CircularProgressIndicator()):!_comparisonLoaded
      ? const Center(child:Text('اضغط تحديث المقارنة لعرض أرصدة الأصناف المرتبطة.'))
      : _workspaceComparisonRows.isEmpty
        ? const Center(child:Text('لا توجد أصناف مفعلة مرتبطة بدليل سلسلة في هذا النشاط.'))
        : ListView(children:_workspaceComparisonRows.map((row){
          final own=double.tryParse(row['workspace_quantity'].toString())??0;
          final min=double.tryParse(row['reorder_level'].toString())??0;
          final central=double.tryParse(row['central_available'].toString())??0;
          final shortage=(min-own).clamp(0,double.infinity).toDouble();
          final suggested=shortage<central?shortage:central;
          final needs=shortage>0;
          return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('${row['item_name']} • ${row['item_code']}',style:const TextStyle(fontWeight:FontWeight.w900,color:_workspacePurple)),
            Text('الوحدة: ${row['base_unit']} • حد إعادة الطلب: ${min.toStringAsFixed(2)}',style:const TextStyle(color:Colors.black54,fontSize:12)),
            const SizedBox(height:8),
            Wrap(spacing:16,runSpacing:8,children:[
              Text('رصيد نشاطي: ${own.toStringAsFixed(2)}'),
              Text('متاح في سلسلة: ${central.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.w800)),
              Text('محجوز في سلسلة: ${row['central_reserved']}'),
            ]),
            const Divider(),
            Text(!needs?'رصيد نشاطك أعلى من حد إعادة الطلب':suggested>0?'كمية مقترحة لتغطية النقص: ${suggested.toStringAsFixed(2)}':'يوجد نقص، لكن لا توجد كمية متاحة حالياً في سلسلة',
              style:TextStyle(fontWeight:FontWeight.w800,color:!needs?Colors.green:suggested>0?_workspaceOrange:Colors.redAccent)),
          ])));
        }).toList())),
  ]);

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

  Future<void> _editMember(Map<String,dynamic> member) async {
    final permissions = <String,bool>{};
    final stored = member['permissions'] is Map ? Map<String,dynamic>.from(member['permissions']) : <String,dynamic>{};
    for (final key in _memberPermissions.keys) {
      permissions[key] = stored[key] == true;
    }
    var role = (member['member_role'] ?? 'staff').toString();
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
      title:Text('صلاحيات ${member['member_display_name'] ?? 'المستخدم'}'),
      content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(
          value:role=='owner'?'staff':role,
          decoration:const InputDecoration(labelText:'الدور داخل النشاط'),
          items:const [
            DropdownMenuItem(value:'admin',child:Text('مدير')),
            DropdownMenuItem(value:'manager',child:Text('مدير فرع')),
            DropdownMenuItem(value:'accountant',child:Text('محاسب')),
            DropdownMenuItem(value:'warehouse',child:Text('مسؤول مخزن')),
            DropdownMenuItem(value:'sales',child:Text('مبيعات')),
            DropdownMenuItem(value:'staff',child:Text('مستخدم')),
            DropdownMenuItem(value:'viewer',child:Text('عرض فقط')),
          ],
          onChanged:(v){if(v!=null)setDialogState(()=>role=v);},
        ),
        ...permissions.entries.map((entry)=>SwitchListTile(
          dense:true,contentPadding:EdgeInsets.zero,title:Text(_permissionLabel(entry.key),style:const TextStyle(fontSize:12)),
          value:entry.value,onChanged:(v)=>setDialogState(()=>permissions[entry.key]=v),
        )),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),
        FilledButton(onPressed:() async {
          try {
            await _db.from('erp_business_workspace_members').update({
              'member_role':role,'permissions':permissions,'is_active':true,'can_open_workspace':role=='admin'||permissions['workspace.enter']==true,
            }).eq('workspace_id',_selected!['id'].toString()).eq('user_id',member['user_id'].toString());
            if(dialogContext.mounted) Navigator.pop(dialogContext);
            await _loadStructure(); _message('تم تحديث صلاحيات المستخدم.');
          } catch(e) { _message('تعذر تحديث الصلاحيات: $e'); }
        },child:const Text('حفظ الصلاحيات')),
      ],
    )));
  }

  bool _memberHasBranchAccess(String userId,String branchId) {
    final rows=_memberLocations.where((l)=>l['user_id'].toString()==userId&&l['access_scope']=='branch'&&l['branch_id'].toString()==branchId);
    final warehouseAllowed=_memberLocations.any((l)=>l['user_id'].toString()==userId&&l['access_scope']=='warehouse'&&l['is_allowed']==true&&_warehouses.any((w)=>w['id'].toString()==l['warehouse_id'].toString()&&w['branch_id'].toString()==branchId));
    if(rows.isNotEmpty && rows.first['is_allowed']==true) return true;
    if(rows.isNotEmpty && rows.first['is_allowed']==false && !warehouseAllowed) return false;
    if(warehouseAllowed) return true;
    // Once the owner has configured any location rule for this member,
    // unspecified branches are denied (not implicitly granted).
    return !_memberLocations.any((l)=>l['user_id'].toString()==userId);
  }

  bool _memberHasWarehouseAccess(String userId,Map<String,dynamic> warehouse) {
    final whId=warehouse['id'].toString();
    final rows=_memberLocations.where((l)=>l['user_id'].toString()==userId&&l['access_scope']=='warehouse'&&l['warehouse_id'].toString()==whId);
    if(rows.isNotEmpty) return rows.first['is_allowed']==true;
    final branchRows=_memberLocations.where((l)=>l['user_id'].toString()==userId&&l['access_scope']=='branch'&&l['branch_id'].toString()==warehouse['branch_id'].toString());
    if(branchRows.isNotEmpty && branchRows.first['is_allowed']==false) return false;
    if(branchRows.isNotEmpty && branchRows.first['is_allowed']==true) return true;
    // Any configured location restriction switches this member to
    // explicit allow-list mode; a denied-only rule must never grant all.
    return !_memberLocations.any((l)=>l['user_id'].toString()==userId);
  }

  Future<void> _setMemberLocationAccess(String userId,String scope,String branchId,String? warehouseId,bool allowed) async {
    final workspaceId=_selected?['id']?.toString();
    if(workspaceId==null) return;
    try {
      await _db.rpc('erp_set_business_workspace_location_access',params:{
        'p_workspace_id':workspaceId,'p_user_id':userId,'p_access_scope':scope,
        'p_branch_id':branchId,'p_warehouse_id':warehouseId,'p_is_allowed':allowed,
      });
      if(scope=='branch'&&allowed) {
        final ids=_warehouses.where((w)=>w['branch_id'].toString()==branchId).map((w)=>w['id'].toString()).toList();
        if(ids.isNotEmpty) await _db.from('erp_business_workspace_member_locations').delete().eq('workspace_id',workspaceId).eq('user_id',userId).eq('access_scope','warehouse').inFilter('warehouse_id',ids);
      }
      await _loadStructure();
      _message('تم تحديث نطاق وصول المستخدم.');
    } catch(e) { _message('تعذر تحديث نطاق الوصول: $e'); }
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
        'name_en': _branchNameEn.text.trim().isEmpty ? null : _branchNameEn.text.trim(),
      });
      _branchName.clear(); _branchNameEn.clear(); _branchCode.clear();
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
        'workspace_id': id, 'branch_id': _selectedBranchForWarehouse ?? _branches.first['id'],
        'warehouse_code': code, 'name_ar': name,
        'name_en': _warehouseNameEn.text.trim().isEmpty ? null : _warehouseNameEn.text.trim(),
      });
      _warehouseName.clear(); _warehouseNameEn.clear(); _warehouseCode.clear();
      await _loadStructure(); _message('تم حفظ المخزن وربطه بفرع ${_branchNameForWarehouse(_selectedBranchForWarehouse ?? _branches.first['id'])}.');
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
        if (_activityTypes.isNotEmpty)
          DropdownButtonFormField<String>(
            value:_activityTypes.any((a)=>a['code'].toString()==_activity.text)?_activity.text:null,
            decoration:const InputDecoration(labelText:'نوع النشاط'),
            items:_activityTypes.map((a)=>DropdownMenuItem(value:a['code'].toString(),child:Text((a['name']??a['name_en']??a['code']).toString()))).toList(),
            onChanged:(v){if(v!=null)_activity.text=v;},
          )
        else
          TextField(controller:_activity,decoration:const InputDecoration(labelText:'نوع النشاط')),
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
      setState(() {
        _selected = item;
        _area = 'الرئيسية';
        _clearWorkspaceData();
      });
      _syncWorkspacePolicyFromSelection();
      await _loadStructure();
    },
  );

  Widget _noWorkspace() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: _emptyState('لا يوجد نشاط مرتبط بهذا الحساب حتى الآن. إدارة نشاطي لا تنشئ نشاطاً جديداً؛ يجب ربطها بالنشاط المسجل بالفعل في سلسلة بواسطة الإدارة المختصة.'),
  ));

  Widget _emptyState(String text, {bool showRetry = false}) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.storefront_outlined, size: 54, color: _workspacePurple),
      const SizedBox(height: 12), Text(text, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      if (showRetry) OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))
    ],
  ));

  Widget _areaView() {
    if (!_canOpenWorkspaceArea(_area)) return _workspacePermissionDenied(_area);
    if (_area == 'صرف وتوريد نقدية') return _cashMovementsView();
    if (_area == 'تحويلات وتسويات مخزنية') return _inventoryMovementsView();
    if (_area == 'خروج من إدارة نشاطي') return _exitWorkspaceView();
    if (_area.startsWith('تقارير')) return _reportsView(_area);
    if (_area == 'فاتورة شراء / مرتجع شراء') return _documentsView(purchase:true);
    if (_area == 'فاتورة بيع / مرتجع بيع') return _documentsView(purchase:false);
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
      final basicTiles = <(String,IconData,String)>[
        if (_canOpenWorkspaceArea('بيانات نشاطي')) ('بيانات نشاطي',Icons.storefront_outlined,'بيانات النشاط والفروع والمخازن'),
        if (_canOpenWorkspaceArea('مستخدمين نشاطي')) ('مستخدمين نشاطي',Icons.people_alt_outlined,'المستخدمون والصلاحيات ونطاقات الوصول'),
        if (_canOpenWorkspaceArea('رصيد مخازني')) ('رصيد مخازني',Icons.inventory_2_outlined,'الأصناف والأرصدة الافتتاحية ومقارنة سلسلة'),
        if (_canOpenWorkspaceArea('موظفين نشاطي')) ('موظفين نشاطي',Icons.badge_outlined,'الإدارات والأقسام وموظفو النشاط'),
      ];
      final movementTiles = <(String,IconData,String)>[
        if (_canOpenWorkspaceArea('فاتورة شراء / مرتجع شراء')) ('فاتورة شراء / مرتجع شراء',Icons.shopping_bag_outlined,'المشتريات والمرتجعات'),
        if (_canOpenWorkspaceArea('فاتورة بيع / مرتجع بيع')) ('فاتورة بيع / مرتجع بيع',Icons.point_of_sale_outlined,'المبيعات والمرتجعات'),
        if (_canOpenWorkspaceArea('تحويلات وتسويات مخزنية')) ('تحويلات وتسويات مخزنية',Icons.warehouse_outlined,'التحويلات والتسويات'),
        if (_canOpenWorkspaceArea('صرف وتوريد نقدية')) ('صرف وتوريد نقدية',Icons.payments_outlined,'المقبوضات والمدفوعات'),
      ];
      final reportTiles = <(String,IconData,String)>[
        if (_canWorkspacePermission('reports.read')) ('تقارير البيانات الأساسية',Icons.list_alt,'تقارير الفروع والمخازن والمستخدمين'),
        if (_canWorkspacePermission('reports.read')) ('تقارير الحركات',Icons.receipt_long,'حركة المستندات والمخزون والنقدية'),
        if (_canWorkspacePermission('reports.read')) ('تقارير مالية وتحليلات',Icons.query_stats,'ملخص النتائج المالية'),
        ('خروج من إدارة نشاطي',Icons.logout,'العودة إلى قوائم سلسلة'),
      ];
      return ListView(children: [
        _sectionTitle('مساحة العمل', 'كل إطار يفتح شاشة مستقلة داخل نشاطك، مع احترام صلاحيات المستخدم والفروع والمخازن'),
        if (basicTiles.isNotEmpty) _dashboardSection('بياناتي الأساسية','إعداد وإدارة بيانات النشاط',basicTiles),
        if (movementTiles.isNotEmpty) _dashboardSection('حركات نشاطي','تسجيل ومتابعة حركات النشاط اليومية',movementTiles),
        if (reportTiles.isNotEmpty) _dashboardSection('تقارير نشاطي','متابعة الأداء والبيانات والنتائج',reportTiles),
        if (basicTiles.isEmpty && movementTiles.isEmpty && reportTiles.length==1)
          _workspacePermissionDenied('وحدات إدارة النشاط'),
        const SizedBox(height: 12),
        _sectionTitle('ملخص النشاط', 'الأرصدة والمؤشرات المستخرجة من بيانات هذا النشاط فقط'),
        _tileGrid([
          if (_canWorkspacePermission('master.read')) ('الفروع', Icons.account_tree_outlined, '${_metricCount('branches_count',_branches.length.toString())} فرع'),
          if (_canWorkspacePermission('master.read')) ('المخازن', Icons.warehouse_outlined, '${_metricCount('warehouses_count',_warehouses.length.toString())} مخزن'),
          if (_canWorkspacePermission('master.read')) ('الأصناف', Icons.inventory_2_outlined, '${_metricCount('items_count',_itemLinks.where((x)=>x['is_enabled']==true).length.toString())} صنف مفعل'),
          if (_canAnyWorkspacePermission(['purchases.read','sales.read','reports.read'])) ('مستندات مرحلة', Icons.receipt_long, '${_metricCount('posted_documents_count',_documents.where((x)=>x['status']=='posted').length.toString())} مستند'),
        ]),
        const SizedBox(height:12),
        if (_canAnyWorkspacePermission(['sales.read','purchases.read','cash.read']))
          _sectionTitle('مؤشرات النشاط','ملخص تشغيلي من البيانات المسموح لك بالاطلاع عليها'),
        _tileGrid([
          if (_canWorkspacePermission('sales.read')) ('إجمالي المبيعات', Icons.trending_up, _metricMoney('sales_total')),
          if (_canWorkspacePermission('purchases.read')) ('إجمالي المشتريات', Icons.shopping_cart_outlined, _metricMoney('purchases_total')),
          if (_canWorkspacePermission('cash.read')) ('الوارد النقدي', Icons.south_west, _metricMoney('cash_in_total')),
          if (_canWorkspacePermission('cash.read')) ('الصادر النقدي', Icons.north_east, _metricMoney('cash_out_total')),
        ]),
      ]);
    }
    if (sections.containsKey(_area)) {
      final allowedTiles = sections[_area]!.where((x) => _canOpenWorkspaceArea(x.$1)).toList();
      return ListView(children: [
        _backHeader(_area),
        if (allowedTiles.isEmpty)
          _workspacePermissionDenied(_area)
        else
          _tileGrid(allowedTiles.map((x) => (x.$1, x.$2, x.$3 == 'exit' ? 'العودة إلى قوائم سلسلة' : 'شاشة مستقلة بصلاحيات هذا النشاط')).toList()),
        const SizedBox(height: 12),
        const Text('الشاشات التشغيلية مفعلة داخل مساحة النشاط. المسودات لا تغير الأرصدة حتى اعتماد المستند وترحيله، وتُسجل التحويلات والتسويات في دفتر حركة المخزون.', style: TextStyle(color: Colors.black54, height: 1.6)),
      ]);
    }
    return _backHeader(_area);
  }

  Widget _basicData() {
    final tabs = <(String, int, Widget)>[
      if (_canWorkspacePermission('master.read')) ('بيانات النشاط', 0, _businessDetails()),
      if (_canWorkspacePermission('members.read')) ('مستخدمين نشاطي', 1, _membersInfo()),
      if (_canAnyWorkspacePermission(['items.read','items.propose','inventory.read','master.read'])) ('رصيد مخازني', 2, _stockInfo()),
      if (_canWorkspacePermission('hr.read')) ('موظفين نشاطي', 3, _employeesInfo()),
      if (_canAnyWorkspacePermission(['customers.read','customers.manage','suppliers.read','suppliers.manage'])) ('عملاء وموردو نشاطي', 4, ErpBusinessWorkspaceCounterpartiesPanel(workspaceId:_selected!['id'].toString(),canManageCustomers:_canWorkspacePermission('customers.manage'),canManageSuppliers:_canWorkspacePermission('suppliers.manage'))),
    ];
    if (tabs.isEmpty) return _workspacePermissionDenied('بياناتي الأساسية');
    final visibleIndex = tabs.indexWhere((tab) => tab.$2 == _basicTab);
    final safeIndex = visibleIndex < 0 ? 0 : visibleIndex;
    return Column(children: [
      _backHeader('بياناتي الأساسية'),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: tabs.map((tab) => _tabButton(tab.$1, tab.$2)).toList()),
      const SizedBox(height: 12),
      Expanded(child: IndexedStack(index: safeIndex, children: tabs.map((tab) => tab.$3).toList())),
    ]);
  }

  Widget _tabButton(String label, int index) => ChoiceChip(
    label: Text(label), selected: _basicTab == index,
    selectedColor: const Color(0xFFF0E7FA),
    onSelected: (_) => setState(() => _basicTab = index),
  );

  Widget _inventoryMovementsView() => ListView(children:[
    _backHeader('تحويلات وتسويات مخزنية'),
    _sectionTitle('حركات المخزون','التحويل والتسوية يُرحلان ذرياً إلى دفتر حركة المخزون'),
    Wrap(spacing:6,children:[
      ChoiceChip(label:const Text('تحويل بين مخازني'),selected:_inventoryMode=='transfer',onSelected:(_)=>setState(()=>_inventoryMode='transfer')),
      ChoiceChip(label:const Text('تسوية مخزنية'),selected:_inventoryMode=='adjustment',onSelected:(_)=>setState(()=>_inventoryMode='adjustment')),
    ]),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_warehouses.any((w)=>w['id'].toString()==_sourceWarehouseId)?_sourceWarehouseId:null,
      decoration:InputDecoration(labelText:_inventoryMode=='transfer'?'المخزن المصدر':'المخزن'),
      items:_warehouses.map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState((){
        _sourceWarehouseId=v;
        final targets=_warehouses.where((w)=>w['id'].toString()!=v).toList();
        if(!targets.any((w)=>w['id'].toString()==_targetWarehouseId)){
          _targetWarehouseId=targets.isNotEmpty?targets.first['id'].toString():null;
        }
      }),
    ),
    if(_inventoryMode=='transfer') ...[
      const SizedBox(height:8),
      DropdownButtonFormField<String>(
        value:_warehouses.any((w)=>w['id'].toString()==_targetWarehouseId && w['id'].toString()!=_sourceWarehouseId)?_targetWarehouseId:null,
        decoration:const InputDecoration(labelText:'المخزن المستهدف'),
        items:_warehouses.where((w)=>w['id'].toString()!=_sourceWarehouseId).map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name_ar'].toString()))).toList(),
        onChanged:_warehouses.where((w)=>w['id'].toString()!=_sourceWarehouseId).isEmpty?null:(v)=>setState(()=>_targetWarehouseId=v),
      ),
    ],
    if(_inventoryMode=='adjustment') ...[
      const SizedBox(height:8),
      DropdownButtonFormField<String>(
        value:_adjustDirection,
        decoration:const InputDecoration(labelText:'اتجاه التسوية'),
        items:const[DropdownMenuItem(value:'increase',child:Text('زيادة رصيد')),DropdownMenuItem(value:'decrease',child:Text('عجز / تخفيض رصيد'))],
        onChanged:(v){if(v!=null)setState(()=>_adjustDirection=v);},
      ),
    ],
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_itemLinks.any((x)=>x['id'].toString()==_inventoryItemLinkId&&x['is_enabled']==true)?_inventoryItemLinkId:null,
      decoration:const InputDecoration(labelText:'الصنف'),
      items:_itemLinks.where((x)=>x['is_enabled']==true).map((x){final item=x['erp_items'] is Map?Map<String,dynamic>.from(x['erp_items']):<String,dynamic>{};return DropdownMenuItem(value:x['id'].toString(),child:Text((item['item_name']??'صنف').toString()));}).toList(),
      onChanged:(v)=>setState(()=>_inventoryItemLinkId=v),
    ),
    Row(children:[
      Expanded(child:TextField(controller:_inventoryQuantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية'))),
      if(_inventoryMode=='adjustment'&&_adjustDirection=='increase') ...[
        const SizedBox(width:8),
        Expanded(child:TextField(controller:_inventoryUnitCost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'تكلفة الوحدة'))),
      ],
    ]),
    TextField(controller:_inventoryNotes,decoration:const InputDecoration(labelText:'ملاحظات')),
    if (_canWorkspacePermission('inventory.manage')) ...[
      const SizedBox(height:8),
      if(_inventoryMode=='transfer' && _warehouses.where((w)=>w['id'].toString()!=_sourceWarehouseId).isEmpty)
        const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('أضف مخزناً آخر إلى النشاط حتى تتمكن من إجراء تحويل مخزني.',style:TextStyle(color:Colors.deepOrange))),
      Align(alignment:Alignment.centerLeft,child:FilledButton.icon(
        onPressed:_inventoryMode=='transfer' && _targetWarehouseId==null?null:_saveInventoryMovement,
        icon:const Icon(Icons.check_circle),label:const Text('ترحيل الحركة'))),
    ],
    const Divider(),
    _sectionTitle('آخر الحركات المخزنية','${_stockMovements.length} حركة في دفتر النشاط'),
    ..._stockMovements.take(50).map((m){
      final linkRows=_itemLinks.where((x)=>x['id'].toString()==m['item_link_id'].toString());
      final link=linkRows.isEmpty?null:linkRows.first;
      final item=link?['erp_items'] is Map?Map<String,dynamic>.from(link!['erp_items']):<String,dynamic>{};
      final incoming=(double.tryParse(m['quantity_in'].toString())??0)>0;
      return ListTile(dense:true,leading:Icon(incoming?Icons.south_west:Icons.north_east,color:incoming?Colors.green:Colors.deepOrange),
        title:Text((item['item_name']??'صنف').toString()),
        subtitle:Text('${m['movement_type']} • ${m['movement_date']}'),
        trailing:Text(incoming?'+${m['quantity_in']}':'-${m['quantity_out']}'),
      );
    }),
  ]);

  String _workspaceDocumentStatusLabel(dynamic status) => const {
    'draft':'مسودة',
    'pending':'بانتظار الاعتماد',
    'approved':'معتمد',
    'posted':'مرحّل',
    'cancelled':'ملغي',
  }[status] ?? (status??'').toString();

  String _workspaceDocumentTypeLabel(dynamic type) => const {
    'purchase':'فاتورة شراء',
    'purchase_return':'مرتجع شراء',
    'sale':'فاتورة بيع',
    'sale_return':'مرتجع بيع',
  }[type] ?? (type??'').toString();

  Widget _documentsView({required bool purchase}) => ListView(children: [
    _backHeader(purchase?'فاتورة شراء / مرتجع شراء':'فاتورة بيع / مرتجع بيع'),
    _sectionTitle(purchase?'مشتريات النشاط':'مبيعات النشاط','مسودة ← بانتظار الاعتماد ← معتمد ← مرحّل؛ لا يتغير المخزون قبل الترحيل'),
    Wrap(spacing:6,children:[
      ChoiceChip(label:Text(purchase?'فاتورة شراء':'فاتورة بيع'),selected:_documentType==(purchase?'purchase':'sale'),onSelected:(_){setState(()=>_documentType=purchase?'purchase':'sale');}),
      ChoiceChip(label:Text(purchase?'مرتجع شراء':'مرتجع بيع'),selected:_documentType==(purchase?'purchase_return':'sale_return'),onSelected:(_){setState(()=>_documentType=purchase?'purchase_return':'sale_return');}),
    ]),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_branches.any((x)=>x['id'].toString()==_selectedDocBranchId)?_selectedDocBranchId:null,
      decoration:const InputDecoration(labelText:'الفرع'),
      items:_branches.map((b)=>DropdownMenuItem(value:b['id'].toString(),child:Text(b['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState((){
        _selectedDocBranchId=v;
        final branchWarehouses=_warehouses.where((w)=>w['branch_id']?.toString()==v).toList();
        _selectedDocWarehouseId=branchWarehouses.isNotEmpty?branchWarehouses.first['id'].toString():null;
      }),
    ),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_warehouses.any((x)=>x['id'].toString()==_selectedDocWarehouseId && x['branch_id']?.toString()==_selectedDocBranchId)?_selectedDocWarehouseId:null,
      decoration:const InputDecoration(labelText:'المخزن'),
      items:_warehouses.where((w)=>w['branch_id']?.toString()==_selectedDocBranchId).map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedDocWarehouseId=v),
    ),
    TextField(controller:_docCounterparty,decoration:InputDecoration(labelText:purchase?'اسم المورد':'اسم العميل')),
    const SizedBox(height:8),
    _sectionTitle('بنود المستند','يمكن إضافة أكثر من صنف قبل إنشاء المسودة'),
    DropdownButtonFormField<String>(
      value:_itemLinks.any((x)=>x['id'].toString()==_selectedDocItemLinkId&&x['is_enabled']==true)?_selectedDocItemLinkId:null,
      decoration:const InputDecoration(labelText:'الصنف'),
      items:_itemLinks.where((x)=>x['is_enabled']==true).map((x){
        final item=x['erp_items'] is Map?Map<String,dynamic>.from(x['erp_items']):<String,dynamic>{};
        return DropdownMenuItem(value:x['id'].toString(),child:Text((item['item_name']??'صنف').toString()));
      }).toList(),
      onChanged:(v)=>setState(()=>_selectedDocItemLinkId=v),
    ),
    Row(children:[
      Expanded(child:TextField(controller:_docQuantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الكمية'))),
      const SizedBox(width:6),
      Expanded(child:TextField(controller:_docUnitPrice,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'سعر الوحدة'))),
      const SizedBox(width:6),
      Expanded(child:TextField(controller:_docDiscount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الخصم'))),
      IconButton(onPressed:_addDocumentLine,icon:const Icon(Icons.add_circle,color:_workspacePurple)),
    ]),
    ..._draftLines.asMap().entries.map((entry){
      final line=entry.value;
      final linkRows=_itemLinks.where((x)=>x['id'].toString()==line['item_link_id']);
      final link=linkRows.isEmpty?null:linkRows.first;
      final item=link?['erp_items'] is Map?Map<String,dynamic>.from(link!['erp_items']):<String,dynamic>{};
      return ListTile(dense:true,title:Text((item['item_name']??'صنف').toString()),
        subtitle:Text('الكمية ${line['quantity']} × ${line['unit_price']} • خصم ${line['discount']}'),
        trailing:IconButton(icon:const Icon(Icons.close,color:Colors.redAccent),onPressed:()=>setState(()=>_draftLines.removeAt(entry.key))));
    }),
    TextField(controller:_docTax,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'نسبة الضريبة %')),
    TextField(controller:_docNotes,decoration:const InputDecoration(labelText:'ملاحظات')),
    if (_canWorkspacePermission(purchase ? 'purchases.manage' : 'sales.manage')) ...[
      const SizedBox(height:8),
      Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_createWorkspaceDocument,icon:const Icon(Icons.save),label:const Text('حفظ كمسودة'))),
    ],
    const Divider(),
    _sectionTitle('مستندات النشاط','${_documents.where((d)=>purchase?['purchase','purchase_return'].contains(d['document_type']):['sale','sale_return'].contains(d['document_type'])).length} مستند'),
    ..._documents.where((d)=>purchase?['purchase','purchase_return'].contains(d['document_type']):['sale','sale_return'].contains(d['document_type'])).map((d)=>Card(
      elevation:0,child:ListTile(dense:true,
        title:Text('${d['document_no']} • ${_workspaceDocumentTypeLabel(d['document_type'])}'),
        subtitle:Text('${d['document_date']} • ${d['counterparty_name']??'بدون طرف'} • ${_workspaceDocumentStatusLabel(d['status'])}'),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          Text('${d['total']}',style:const TextStyle(fontWeight:FontWeight.w800,color:_workspacePurple)),
          if (_canWorkspacePermission(purchase ? 'purchases.manage' : 'sales.manage')) ...[
            if(d['status']=='draft') IconButton(tooltip:'إرسال للاعتماد',icon:const Icon(Icons.send_outlined,color:_workspaceOrange),onPressed:()=>_submitWorkspaceDocument(d['id'].toString())),
            if(d['status']=='pending') IconButton(tooltip:'اعتماد المستند',icon:const Icon(Icons.verified_outlined,color:_workspacePurple),onPressed:()=>_approveWorkspaceDocument(d['id'].toString())),
            if(d['status']=='approved') IconButton(tooltip:'ترحيل المخزون',icon:const Icon(Icons.check_circle,color:Colors.green),onPressed:()=>_postWorkspaceDocument(d['id'].toString())),
          ],
        ]),
      ),
    )),
  ]);

  Widget _cashMovementsView() => ListView(children: [
    _backHeader('صرف وتوريد نقدية'),
    _sectionTitle('حركة نقدية مستقلة', 'كل حركة تخص النشاط الحالي ولا تُرحل إلى خزائن سلسلة'),
    if (_canWorkspacePermission('cash.manage')) ...[
    DropdownButtonFormField<String>(
      value: _cashType,
      decoration: const InputDecoration(labelText: 'نوع الحركة'),
      items: const [
        DropdownMenuItem(value:'receipt',child:Text('سند قبض')),
        DropdownMenuItem(value:'payment',child:Text('سند صرف')),
        DropdownMenuItem(value:'deposit',child:Text('توريد نقدية')),
        DropdownMenuItem(value:'expense',child:Text('مصروف')),
        DropdownMenuItem(value:'income',child:Text('إيراد')),
        DropdownMenuItem(value:'transfer_in',child:Text('تحويل وارد')),
        DropdownMenuItem(value:'transfer_out',child:Text('تحويل صادر')),
      ],
      onChanged:(v){if(v!=null)setState(()=>_cashType=v);},
    ),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value: _branches.any((x)=>x['id'].toString()==_selectedCashBranchId)?_selectedCashBranchId:null,
      decoration: const InputDecoration(labelText:'الفرع'),
      items:_branches.map((b)=>DropdownMenuItem(value:b['id'].toString(),child:Text(b['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedCashBranchId=v),
    ),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_cashPaymentMethod,
      decoration:const InputDecoration(labelText:'وسيلة الدفع / التحصيل'),
      items:const [
        DropdownMenuItem(value:'cash',child:Text('نقدي')),
        DropdownMenuItem(value:'bank_transfer',child:Text('تحويل بنكي')),
        DropdownMenuItem(value:'cheque',child:Text('شيك')),
        DropdownMenuItem(value:'wallet',child:Text('محفظة إلكترونية')),
      ],
      onChanged:(v){if(v!=null)setState(()=>_cashPaymentMethod=v);},
    ),
    const SizedBox(height:8),
    Row(children:[
      Expanded(child:TextField(controller:_cashAmount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ'))),
      const SizedBox(width:8),
      Expanded(child:TextField(controller:_cashCounterparty,decoration:const InputDecoration(labelText:'الطرف / المستفيد'))),
    ]),
    TextField(controller:_cashDescription,decoration:const InputDecoration(labelText:'بيان الحركة')),
    TextField(controller:_cashReference,decoration:const InputDecoration(labelText:'رقم مرجعي اختياري')),
    const SizedBox(height:8),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_saveCashMovement,icon:const Icon(Icons.save),label:const Text('حفظ الحركة'))),
    ],
    const Divider(),
    _sectionTitle('سجل الحركات النقدية','${_cashMovements.length} حركة مسجلة'),
    ..._cashMovements.map((m)=>ListTile(dense:true,
      leading:Icon(['receipt','deposit','income','transfer_in'].contains(m['movement_type'])?Icons.south_west:Icons.north_east,color:['receipt','deposit','income','transfer_in'].contains(m['movement_type'])?Colors.green:Colors.deepOrange),
      title:Text(m['description'].toString()),
      subtitle:Text('${m['movement_no']} • ${m['movement_date']} • ${m['counterparty_name'] ?? 'بدون طرف'}'),
      trailing:Text('${m['amount']}',style:const TextStyle(fontWeight:FontWeight.w800,color:_workspacePurple)),
    )),
  ]);

  Widget _businessDetails() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    _sectionTitle('بياناتي الأساسية','بيانات النشاط وفروعه ومخازنه في ثلاثة تبويبات مستقلة'),
    Wrap(spacing:6,runSpacing:6,children:[
      ChoiceChip(label:const Text('بيانات نشاطي'),selected:_businessSubTab==0,onSelected:(_)=>setState(()=>_businessSubTab=0)),
      ChoiceChip(label:Text('فروع نشاطي (${_branches.length})'),selected:_businessSubTab==1,onSelected:(_)=>setState(()=>_businessSubTab=1)),
      ChoiceChip(label:Text('مخازن نشاطي (${_warehouses.length})'),selected:_businessSubTab==2,onSelected:(_)=>setState(()=>_businessSubTab=2)),
    ]),
    const SizedBox(height:8),
    Expanded(child:IndexedStack(index:_businessSubTab,children:[
      _activityOverviewPanel(),_branchesPanel(),_warehousesPanel(),
    ])),
  ]);

  String _activityLabel(dynamic code) {
    final matches=_activityTypes.where((a)=>a['code'].toString()==(code??'').toString());
    if(matches.isEmpty) return (code??'غير محدد').toString();
    final activity=matches.first;
    return (activity['name']??activity['name_en']??activity['code']).toString();
  }

  Widget _activityOverviewPanel() => ListView(children:[
    Card(elevation:0,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.storefront_outlined,size:38,color:_workspacePurple),
      const SizedBox(height:10),
      Text((_selected?['workspace_name']??'نشاطي').toString(),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:20,color:_workspacePurple)),
      const SizedBox(height:6),
      Text('نوع النشاط: ${_activityLabel(_selected?['activity_type'])}'),
      Text('نوع الحساب: ${_selected?['account_kind']??'غير محدد'}'),
      Text('حالة النشاط: ${_selected?['is_active']==true?'نشط':'غير نشط'}'),
      const Divider(),
      _tileGrid([
        ('الفروع',Icons.account_tree,'${_branches.length}'),
        ('المخازن',Icons.warehouse,'${_warehouses.length}'),
        ('المستخدمون',Icons.people,'${_members.length}'),
        ('الأصناف المفعلة',Icons.inventory,'${_itemLinks.where((x)=>x['is_enabled']==true).length}'),
      ]),
    ]))),
    _infoPanel('استقلال البيانات','الفواتير والمخزون والموظفون والنقدية والتقارير محفوظة داخل مساحة هذا النشاط. مشاركة أرصدة المخازن مع سلسلة لا تكشف التكلفة أو البيانات المالية الداخلية.'),
  ]);

  Widget _branchesPanel() => ListView(children:[
    _sectionTitle('فروع نشاطي','أضف فروعاً مستقلة عن فروع سلسلة'),
    if (_canWorkspacePermission('master.manage')) ...[
    Row(children:[
      Expanded(child:TextField(controller:_branchCode,decoration:const InputDecoration(labelText:'كود الفرع'))),
      const SizedBox(width:8),
      Expanded(child:TextField(controller:_branchName,decoration:const InputDecoration(labelText:'اسم الفرع'))),
      IconButton(onPressed:_addBranch,icon:const Icon(Icons.add_circle,color:_workspacePurple)),
    ]),
    TextField(controller:_branchNameEn,decoration:const InputDecoration(labelText:'اسم الفرع بالإنجليزية (اختياري)')),
    ],
    const Divider(),
    ..._branches.map((b)=>ListTile(dense:true,leading:const Icon(Icons.account_tree,color:_workspacePurple),
      title:Text(b['name_ar'].toString()),subtitle:Text('${b['branch_code']} • ${b['name_en']??''}'),
      trailing:_canWorkspacePermission('master.manage') ? Switch(value:b['is_active']==true,onChanged:(v) async {try{await _db.from('erp_business_workspace_branches').update({'is_active':v}).eq('id',b['id'].toString()).eq('workspace_id',_selected!['id'].toString());await _loadStructure();}catch(e){_message('تعذر تحديث الفرع: $e');}}) : const Text('عرض فقط'))),
  ]);

  String _branchNameForWarehouse(dynamic branchId) {
    final matches=_branches.where((b)=>b['id'].toString()==(branchId??'').toString());
    return matches.isEmpty?'فرع غير محدد':matches.first['name_ar'].toString();
  }

  Widget _warehousesPanel() => ListView(children:[
    _sectionTitle('مخازن نشاطي','كل مخزن يتبع فرعاً محدداً، ويمكن التحكم في ظهوره ضمن أرصدة سلسلة'),
    if (_canWorkspacePermission('master.manage')) ...[
    DropdownButtonFormField<String>(
      value:_branches.any((x)=>x['id'].toString()==_selectedBranchForWarehouse)?_selectedBranchForWarehouse:null,
      decoration:const InputDecoration(labelText:'الفرع التابع له المخزن'),
      items:_branches.map((b)=>DropdownMenuItem(value:b['id'].toString(),child:Text(b['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedBranchForWarehouse=v),
    ),
    Row(children:[
      Expanded(child:TextField(controller:_warehouseCode,decoration:const InputDecoration(labelText:'كود المخزن'))),
      const SizedBox(width:8),
      Expanded(child:TextField(controller:_warehouseName,decoration:const InputDecoration(labelText:'اسم المخزن'))),
      IconButton(onPressed:_addWarehouse,icon:const Icon(Icons.add_circle,color:_workspacePurple)),
    ]),
    TextField(controller:_warehouseNameEn,decoration:const InputDecoration(labelText:'اسم المخزن بالإنجليزية (اختياري)')),
    ],
    const Divider(),
    ..._warehouses.map((w)=>ListTile(dense:true,leading:const Icon(Icons.warehouse,color:_workspaceOrange),
      title:Text(w['name_ar'].toString()),
      subtitle:Text('${_branchNameForWarehouse(w['branch_id'])} • ${w['warehouse_code']} • ${w['show_balance_in_silsila']==true?'الرصيد ظاهر في سلسلة':'الرصيد غير ظاهر في سلسلة'}'),
      trailing:_canWorkspacePermission('master.manage')
          ? Column(mainAxisSize:MainAxisSize.min,children:[
              Row(mainAxisSize:MainAxisSize.min,children:[const Text('نشط',style:TextStyle(fontSize:10)),Switch(value:w['is_active']==true,onChanged:(v) async {try{await _db.from('erp_business_workspace_warehouses').update({'is_active':v}).eq('id',w['id'].toString()).eq('workspace_id',_selected!['id'].toString());await _loadStructure();}catch(e){_message('تعذر تحديث حالة المخزن: $e');}})]),
              Row(mainAxisSize:MainAxisSize.min,children:[const Text('إظهار الرصيد',style:TextStyle(fontSize:10)),Switch(value:w['show_balance_in_silsila']==true,onChanged:(v) async {try{await _db.from('erp_business_workspace_warehouses').update({'show_balance_in_silsila':v}).eq('id',w['id'].toString()).eq('workspace_id',_selected!['id'].toString());await _loadStructure();}catch(e){_message('تعذر تحديث سياسة ظهور الرصيد: $e');}})]),
            ])
          : const Text('عرض فقط'))),
  ]);

  Widget _membersInfo() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    _sectionTitle('مستخدمين نشاطي','أربع تبويبات لإدارة العضويات والصلاحيات ونطاقات الوصول والسياسات'),
    Wrap(spacing:6,runSpacing:6,children:[
      ChoiceChip(label:const Text('مستخدميني'),selected:_memberSubTab==0,onSelected:(_)=>setState(()=>_memberSubTab=0)),
      if (_isWorkspaceOwner) ...[
        ChoiceChip(label:const Text('صلاحيات مستخدميني'),selected:_memberSubTab==1,onSelected:(_)=>setState(()=>_memberSubTab=1)),
        ChoiceChip(label:const Text('فروع ومخازن مستخدمين'),selected:_memberSubTab==2,onSelected:(_)=>setState(()=>_memberSubTab=2)),
        ChoiceChip(label:const Text('سياسات نشاطي'),selected:_memberSubTab==3,onSelected:(_)=>setState(()=>_memberSubTab=3)),
      ],
    ]),
    const SizedBox(height:8),
    Expanded(child:IndexedStack(index:_isWorkspaceOwner ? _memberSubTab.clamp(0,3) : 0,children:[
      _memberUsersPanel(),
      if (_isWorkspaceOwner) ...[_memberPermissionsPanel(),_memberLocationsPanel(),_workspacePoliciesPanel()],
    ])),
  ]);

  Widget _memberUsersPanel() => ListView(children:[
    if (_isWorkspaceOwner) ...[
      _sectionTitle('إضافة مستخدم','اربط حساباً نشطاً موجوداً بالفعل في سلسلة دون إنشاء حساب دخول مكرر'),
      TextField(controller:_memberPhone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم هاتف المستخدم المسجل')),
      const SizedBox(height:8),
      Row(children:[
        Expanded(child:DropdownButtonFormField<String>(value:_memberRole,decoration:const InputDecoration(labelText:'الدور'),items:const[
          DropdownMenuItem(value:'staff',child:Text('مستخدم')),
          DropdownMenuItem(value:'manager',child:Text('مدير فرع')),
          DropdownMenuItem(value:'accountant',child:Text('محاسب')),
          DropdownMenuItem(value:'warehouse',child:Text('مسؤول مخزن')),
          DropdownMenuItem(value:'sales',child:Text('مبيعات')),
          DropdownMenuItem(value:'viewer',child:Text('عرض فقط')),
          DropdownMenuItem(value:'admin',child:Text('مدير كامل')),
        ],onChanged:(v){if(v!=null)setState(()=>_memberRole=v);})),
        const SizedBox(width:8),
        FilledButton.icon(onPressed:_addMember,icon:const Icon(Icons.person_add_alt_1),label:const Text('ربط المستخدم')),
      ]),
    ],
    const Divider(),
    _sectionTitle('المستخدمون المرتبطون','تعديل الصلاحيات أو إلغاء الوصول لا يحذف حساب المستخدم من سلسلة'),
    ..._members.map((m)=>ListTile(dense:true,leading:const Icon(Icons.account_circle_outlined,color:_workspacePurple),
      title:Text((m['member_display_name']??'مستخدم سلسلة').toString()),
      subtitle:Text('${m['member_role']} • ${m['is_active']==true?'نشط':'غير نشط'}'),
      trailing:m['member_role']=='owner'
          ? const Text('المالك')
          : _isWorkspaceOwner
              ? Row(mainAxisSize:MainAxisSize.min,children:[
                  IconButton(tooltip:'تعديل الصلاحيات',icon:const Icon(Icons.tune,color:_workspacePurple),onPressed:()=>_editMember(m)),
                  IconButton(tooltip:'إلغاء الوصول',icon:const Icon(Icons.person_remove_alt_1,color:Colors.redAccent),onPressed:()=>_removeMember(m['user_id'].toString())),
                ])
              : const Text('عرض فقط'),
    )),
  ]);

  Widget _memberPermissionsPanel() => ListView(children:[
    _sectionTitle('الصلاحيات الافتراضية للمستخدم الجديد','حدد الصلاحيات قبل إضافته، ويمكن تعديل كل مستخدم لاحقاً من تبويب مستخدميني'),
    ..._memberPermissions.entries.map((entry)=>SwitchListTile(
      dense:true,contentPadding:EdgeInsets.zero,title:Text(_permissionLabel(entry.key),style:const TextStyle(fontSize:12)),
      value:entry.value,onChanged:(v)=>setState(()=>_memberPermissions[entry.key]=v),
    )),
  ]);

  Widget _memberLocationsPanel() => ListView(children:[
    _sectionTitle('فروع ومخازن مستخدميني','يمكن السماح بفرع بالكامل أو السماح بمخازن محددة داخله. عند تحديد نطاقات، تُطبق على البيانات فعلياً عبر RLS.'),
    if(_members.where((m)=>m['member_role']!='owner').isNotEmpty)...[
      DropdownButtonFormField<String>(
        value:_members.any((m)=>m['user_id'].toString()==_selectedLocationMemberUserId&&m['member_role']!='owner')?_selectedLocationMemberUserId:null,
        decoration:const InputDecoration(labelText:'المستخدم الفرعي'),
        items:_members.where((m)=>m['member_role']!='owner').map((m)=>DropdownMenuItem(value:m['user_id'].toString(),child:Text((m['member_display_name']??'مستخدم').toString()))).toList(),
        onChanged:(v)=>setState(()=>_selectedLocationMemberUserId=v),
      ),
      if(_selectedLocationMemberUserId!=null)..._branches.map((b)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text('السماح بالفرع بالكامل: ${b['name_ar']}'),value:_memberHasBranchAccess(_selectedLocationMemberUserId!,b['id'].toString()),onChanged:(v)=>_setMemberLocationAccess(_selectedLocationMemberUserId!,'branch',b['id'].toString(),null,v)),
        Padding(padding:const EdgeInsets.only(right:22),child:Column(children:_warehouses.where((w)=>w['branch_id'].toString()==b['id'].toString()).map((w)=>SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text('مخزن: ${w['name_ar']}'),value:_memberHasWarehouseAccess(_selectedLocationMemberUserId!,w),onChanged:(v)=>_setMemberLocationAccess(_selectedLocationMemberUserId!,'warehouse',b['id'].toString(),w['id'].toString(),v))).toList())),
      ])),
    ]else const Text('أضف مستخدماً فرعياً أولاً لتحديد الفروع والمخازن المتاحة له.'),
  ]);

  Widget _workspacePoliciesPanel() => ListView(children:[
    _sectionTitle('سياسات نشاطي','إعدادات مستقلة لهذا النشاط، تحفظ في قاعدة البيانات وتُفرض على العمليات الجديدة من الخادم'),
    if (!_isWorkspaceOwner)
      const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('يمكنك الاطلاع على السياسات، لكن تعديلها متاح لمالك النشاط فقط.')))
    else ...[
      TextField(
        controller: _policyTaxController,
        keyboardType: const TextInputType.numberWithOptions(decimal:true),
        decoration: const InputDecoration(labelText:'نسبة الضريبة الافتراضية %', helperText:'تُقترح تلقائياً في فواتير النشاط ويمكن تعديلها لكل مستند'),
      ),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(
        value:_policyCurrencyCode,
        decoration:const InputDecoration(labelText:'العملة الافتراضية'),
        items:const [
          DropdownMenuItem(value:'EGP',child:Text('الجنيه المصري EGP')),
          DropdownMenuItem(value:'USD',child:Text('الدولار الأمريكي USD')),
          DropdownMenuItem(value:'EUR',child:Text('اليورو EUR')),
          DropdownMenuItem(value:'SAR',child:Text('الريال السعودي SAR')),
          DropdownMenuItem(value:'AED',child:Text('الدرهم الإماراتي AED')),
        ],
        onChanged:(v){if(v!=null)setState(()=>_policyCurrencyCode=v);},
      ),
      const Divider(),
      SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,
        title:const Text('إلزام سبب التسوية المخزنية'),
        subtitle:const Text('يمنع ترحيل التسوية دون كتابة ملاحظات توضح سببها'),
        value:_policyRequireAdjustmentNotes,
        onChanged:(v)=>setState(()=>_policyRequireAdjustmentNotes=v)),
      SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,
        title:const Text('إلزام الرقم المرجعي للحركات النقدية'),
        subtitle:const Text('يشترط إدخال رقم سند أو مرجع قبل تسجيل الحركة'),
        value:_policyRequireCashReference,
        onChanged:(v)=>setState(()=>_policyRequireCashReference=v)),
      SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,
        title:const Text('إلزام تحديد العميل أو المورد في الفواتير'),
        subtitle:const Text('لا تُحفظ مسودة الفاتورة دون اسم الطرف المقابل'),
        value:_policyRequireCounterparty,
        onChanged:(v)=>setState(()=>_policyRequireCounterparty=v)),
      const SizedBox(height:12),
      Align(alignment:Alignment.centerLeft,child:FilledButton.icon(
        onPressed:_saveWorkspacePolicies,icon:const Icon(Icons.save_outlined),
        label:const Text('حفظ وتطبيق السياسات'))),
    ],
    const SizedBox(height:12),
    _infoPanel('حدود السياسات','هذه السياسات لا تغير إعدادات سلسلة المركزية ولا تؤثر على أنشطة أخرى. وتظل صلاحيات المستخدمين ونطاقات الفروع والمخازن مستقلة عنها.'),
  ]);

  String _permissionLabel(String key) => const {
    'workspace.enter':'الدخول إلى إدارة النشاط',
    'members.read':'عرض المستخدمين','members.manage':'إدارة المستخدمين والصلاحيات',
    'master.read':'عرض الفروع والمخازن','master.manage':'إدارة الفروع والمخازن',
    'items.read':'عرض الأصناف','items.propose':'اقتراح أصناف جديدة',
    'inventory.read':'عرض المخزون','inventory.manage':'إدارة الأرصدة والتحويلات والتسويات',
    'purchases.read':'عرض المشتريات','purchases.manage':'إدارة المشتريات والمرتجعات',
    'sales.read':'عرض المبيعات','sales.manage':'إدارة المبيعات والمرتجعات',
    'cash.read':'عرض النقدية','cash.manage':'إدارة الصرف والتوريد',
    'hr.read':'عرض الموظفين','hr.manage':'إدارة الموظفين',
    'reports.read':'عرض التقارير','audit.read':'عرض سجل العمليات','audit.write':'تسجيل عمليات المراجعة',
  }[key] ?? key;
  Widget _stockInfo() {
    final tabs = <(String,int,Widget)>[
      if (_canWorkspacePermission('master.read')) ('اختيار الأصناف',0,_itemSelectionTab()),
      if (_canWorkspacePermission('inventory.read')) ('افتتاحي مخازني',1,_openingStockTab()),
      if (_canWorkspacePermission('items.propose')) ('إضافة صنف جديد',2,_itemProposalTab()),
      if (_canWorkspacePermission('inventory.read') && _canWorkspacePermission('items.read')) ('مقارنة مع سلسلة',3,_workspaceStockComparisonTab()),
    ];
    if (tabs.isEmpty) return _workspacePermissionDenied('رصيد مخازني');
    final visibleIndex=tabs.indexWhere((tab)=>tab.$2==_stockTab);
    final safeIndex=visibleIndex<0?0:visibleIndex;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('رصيد مخازني', 'اختر الأصناف المعتمدة في سلسلة ثم فعّل ما يحتاجه نشاطك فقط'),
      Wrap(spacing:6,runSpacing:6,children:tabs.map((tab)=>ChoiceChip(
        label:Text(tab.$1),selected:_stockTab==tab.$2,
        onSelected:(_) async {
          setState(()=>_stockTab=tab.$2);
          if(tab.$2==0 && _platformItems.isEmpty) await _loadPlatformItems();
          if(tab.$2==3) await _loadWorkspaceStockComparison();
        },
      )).toList()),
      const SizedBox(height:10),
      Expanded(child:IndexedStack(index:safeIndex,children:tabs.map((tab)=>tab.$3).toList())),
    ]);
  }

  Widget _itemSelectionTab() => ListView(children: [
    TextField(controller: _itemSearch, decoration: const InputDecoration(labelText: 'بحث في أصناف سلسلة', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(
      value: _platformItems.any((x) => x['id'].toString() == _selectedPlatformItemId) ? _selectedPlatformItemId : null,
      isExpanded: true, decoration: const InputDecoration(labelText: 'الصنف المعتمد في سلسلة'),
      items: _platformItems.where((x) {
        final q = _itemSearch.text.trim().toLowerCase();
        return q.isEmpty || ('${x['item_name']} ${x['item_code']}'.toLowerCase().contains(q));
      }).map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text('${x['item_name']} • ${x['item_code'] ?? ''} • ${(x['erp_item_categories'] is Map ? x['erp_item_categories']['category_name'] : '') ?? ''}'))).toList(),
      onChanged: (v) => setState(() => _selectedPlatformItemId = v),
    ),
    const SizedBox(height: 8),
    if (_canWorkspacePermission('master.manage'))
      Row(children: [
        Expanded(child: TextField(controller: _localItemCode, decoration: const InputDecoration(labelText: 'كود محلي اختياري'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _reorderLevel, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد إعادة الطلب'))),
        IconButton(onPressed: _addItemLink, tooltip: 'تفعيل الصنف في نشاطي', icon: const Icon(Icons.add_circle, color: _workspacePurple)),
      ],),
    const Divider(),
    _sectionTitle('أصناف هذا النشاط', '${_itemLinks.length} صنف مرتبط • لا تتم إضافة صنف جديد إلى سلسلة من هنا'),
    ..._itemLinks.map((x) {
      final item = x['erp_items'] is Map ? Map<String,dynamic>.from(x['erp_items']) : <String,dynamic>{};
      return ListTile(dense: true, leading: const Icon(Icons.inventory_2_outlined, color: _workspacePurple),
        title: Text((item['item_name'] ?? 'صنف').toString()),
        subtitle: Text('${item['item_code'] ?? ''} • ${item['base_unit'] ?? ''} • حد الطلب: ${x['reorder_level']}'),
        trailing: _canWorkspacePermission('master.manage')
            ? Switch(value: x['is_enabled'] == true, onChanged: (v) async {
                try { await _db.from('erp_business_workspace_item_links').update({'is_enabled':v}).eq('id',x['id'].toString()).eq('workspace_id',_selected!['id'].toString()); await _loadStructure(); }
                catch(e) { _message('تعذر تحديث تفعيل الصنف: $e'); }
              })
            : const Text('عرض فقط'),
      );
    }),
  ]);

  Widget _openingStockTab() => ListView(children: [
    _sectionTitle('الأرصدة الافتتاحية', 'يسجل الرصيد لكل صنف في كل مخزن، ويُنشئ حركة افتتاحية في دفتر المخزون تلقائياً'),
    if (_canWorkspacePermission('inventory.manage')) ...[
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
    ],
    const Divider(),
    _sectionTitle('الأرصدة المسجلة', '${_openings.length} رصيد افتتاحي'),
    ..._openings.map((o) {
      final whRows = _warehouses.where((x) => x['id'].toString() == o['warehouse_id'].toString());
      final linkRows = _itemLinks.where((x) => x['id'].toString() == o['item_link_id'].toString());
      final wh = whRows.isEmpty ? null : whRows.first;
      final link = linkRows.isEmpty ? null : linkRows.first;
      final item = link?['erp_items'] is Map ? Map<String,dynamic>.from(link!['erp_items']) : <String,dynamic>{};
      return ListTile(dense:true, title:Text((item['item_name'] ?? 'صنف').toString()),
        subtitle:Text('${wh?['name_ar'] ?? 'مخزن'} • تكلفة الوحدة: ${o['unit_cost']}'),
        trailing:Text(o['quantity'].toString(),style:const TextStyle(fontWeight:FontWeight.bold,color:_workspacePurple)));
    }),
  ]);

  Widget _itemProposalTab() => ListView(children: [
    _sectionTitle('اقتراح صنف جديد', 'يُحفظ كمسودة لدى سلسلة، ولا يدخل الدليل المركزي إلا بعد مراجعة واعتماد صاحب الصلاحية'),
    if (_canWorkspacePermission('items.propose')) ...[
    TextField(controller: _proposalName, decoration: const InputDecoration(labelText: 'اسم الصنف بالعربية *')),
    TextField(controller: _proposalNameEn, decoration: const InputDecoration(labelText: 'اسم الصنف بالإنجليزية')),
    TextField(controller: _proposalCategory, decoration: const InputDecoration(labelText: 'الفئة المقترحة')),
    TextField(controller: _proposalUnit, decoration: const InputDecoration(labelText: 'وحدة القياس')),
    TextField(controller: _proposalDescription, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف والمواصفات')),
    const SizedBox(height: 8),
    Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _proposeItem, icon: const Icon(Icons.send), label: const Text('إرسال للمراجعة'))),
    ],
    const Divider(),
    _sectionTitle('طلبات الأصناف السابقة', '${_proposals.length} طلب'),
    ..._proposals.map((p) => ListTile(dense:true, leading:const Icon(Icons.pending_actions,color:_workspaceOrange),
      title:Text(p['name_ar'].toString()), subtitle:Text('${p['proposed_category'] ?? 'بدون فئة'} • ${p['status']}'),
      trailing:p['status']=='pending'?const Text('قيد المراجعة'):Text(p['status'].toString()),
    )),
  ]);
  Widget _employeesInfo() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    _sectionTitle('موظفين نشاطي','إدارة الهيكل الإداري والموظفين في تبويبين مستقلين'),
    Wrap(spacing:6,children:[
      ChoiceChip(label:const Text('إداراتي وأقسامي'),selected:_employeeSubTab==0,onSelected:(_)=>setState(()=>_employeeSubTab=0)),
      ChoiceChip(label:Text('موظفيني (${_employees.length})'),selected:_employeeSubTab==1,onSelected:(_)=>setState(()=>_employeeSubTab=1)),
      if(_canWorkspacePermission('hr.read')) ChoiceChip(label:Text('الإجازات (${_employeeLeaves.length})'),selected:_employeeSubTab==2,onSelected:(_)=>setState(()=>_employeeSubTab=2)),
    ]),
    const SizedBox(height:8),
    Expanded(child:IndexedStack(index:_employeeSubTab.clamp(0,2),children:[
      _departmentsPanel(),_employeeRecordsPanel(),_employeeLeavesPanel(),
    ])),
  ]);

  Widget _departmentsPanel() => ListView(children:[
    _sectionTitle('إداراتي وأقسامي','هيكل إداري مستقل بنظام الشجرة'),
    if (_canWorkspacePermission('hr.manage')) ...[
    DropdownButtonFormField<String>(
      value:_departments.any((d)=>d['id'].toString()==_selectedParentDepartmentId)?_selectedParentDepartmentId:null,
      decoration:const InputDecoration(labelText:'يتبع الإدارة / القسم (اختياري)'),
      items:[const DropdownMenuItem<String>(value:null,child:Text('قسم رئيسي')),..._departments.map((d)=>DropdownMenuItem(value:d['id'].toString(),child:Text(d['name_ar'].toString())))],
      onChanged:(v)=>setState(()=>_selectedParentDepartmentId=v),
    ),
    Row(children:[
      Expanded(child:TextField(controller:_departmentCode,decoration:const InputDecoration(labelText:'كود الإدارة / القسم'))),
      const SizedBox(width:8),
      Expanded(child:TextField(controller:_departmentName,decoration:const InputDecoration(labelText:'اسم الإدارة / القسم'))),
      IconButton(onPressed:_addDepartment,icon:const Icon(Icons.add_circle,color:_workspacePurple)),
    ]),
    ],
    const Divider(),
    ..._departments.map((d)=>ListTile(dense:true,leading:Icon(d['parent_id']==null?Icons.account_tree:Icons.subdirectory_arrow_left,color:_workspacePurple),
      title:Text(d['name_ar'].toString()),subtitle:Text(d['department_code'].toString()))),
  ]);

  Widget _employeeRecordsPanel() => ListView(children:[
    _sectionTitle('موظفيني','بيانات مبسطة مستقلة عن موظفي سلسلة'),
    if (_canWorkspacePermission('hr.manage')) ...[
    DropdownButtonFormField<String>(
      value:_departments.any((d)=>d['id'].toString()==_selectedDepartmentId)?_selectedDepartmentId:null,
      decoration:const InputDecoration(labelText:'الإدارة / القسم'),
      items:_departments.map((d)=>DropdownMenuItem(value:d['id'].toString(),child:Text(d['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedDepartmentId=v),
    ),
    TextField(controller:_employeeName,decoration:const InputDecoration(labelText:'اسم الموظف *')),
    TextField(controller:_employeeJob,decoration:const InputDecoration(labelText:'الوظيفة')),
    TextField(controller:_employeeSalary,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المرتب الشهري')),
    Row(children:[
      Expanded(child:TextField(controller:_employeeWorkHours,decoration:const InputDecoration(labelText:'مواعيد العمل'))),
      const SizedBox(width:8),
      Expanded(child:TextField(controller:_employeeWeeklyOff,decoration:const InputDecoration(labelText:'يوم الإجازة الأسبوعية'))),
    ]),
    TextField(controller:_employeeAnnualLeave,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'أيام الإجازة السنوية')),
    const SizedBox(height:8),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_addEmployee,icon:const Icon(Icons.person_add),label:const Text('إضافة موظف'))),
    ],
    const Divider(),
    _sectionTitle('قوة العمل',' ${_employees.length} موظف مسجل'),
    ..._employees.map((e)=>ListTile(dense:true,leading:const Icon(Icons.badge_outlined,color:_workspaceOrange),
      title:Text(e['full_name'].toString()),
      subtitle:Text('${e['employee_code']} • ${e['job_title'] ?? 'بدون وظيفة'}'),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        Text('${e['monthly_salary']}',style:const TextStyle(color:_workspacePurple,fontWeight:FontWeight.w800)),
        if (_canWorkspacePermission('hr.manage')) Switch(value:e['is_active']==true,onChanged:(v) async {try{await _db.from('erp_business_workspace_employees').update({'is_active':v}).eq('id',e['id'].toString()).eq('workspace_id',_selected!['id'].toString());await _loadStructure();}catch(err){_message('تعذر تحديث حالة الموظف: $err');}}),
      ]),
    )),
  ]);

  Widget _employeeLeavesPanel() => ListView(children:[
    _sectionTitle('إجازات موظفيني','طلبات الإجازة ومددها وحالتها، مستقلة عن سجلات الموارد البشرية المركزية'),
    if(_canWorkspacePermission('hr.manage'))
      Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_addEmployeeLeave,icon:const Icon(Icons.event_available),label:const Text('تسجيل إجازة'))),
    const Divider(),
    if(_employeeLeaves.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('لا توجد إجازات مسجلة لهذا النشاط.')),
    ..._employeeLeaves.map((leave){
      final employee=_employees.where((e)=>e['id'].toString()==leave['employee_id'].toString());
      final name=employee.isEmpty?'موظف':employee.first['full_name'].toString();
      final type=const {'annual':'سنوية','sick':'مرضية','unpaid':'بدون أجر','emergency':'عارضة','other':'أخرى'}[leave['leave_type']]??'أخرى';
      final status=const {'pending':'بانتظار الاعتماد','approved':'معتمدة','rejected':'مرفوضة','cancelled':'ملغاة'}[leave['status']]??leave['status'].toString();
      return Card(elevation:0,child:ListTile(
        leading:const Icon(Icons.event_note,color:_workspacePurple),
        title:Text(name),
        subtitle:Text('$type • ${leave['start_date']} إلى ${leave['end_date']} • $status${(leave['notes']??'').toString().isEmpty?'':'\n${leave['notes']}'}'),
        isThreeLine:(leave['notes']??'').toString().isNotEmpty,
        trailing:leave['status']=='pending'&&_canWorkspacePermission('hr.manage')
          ?Wrap(spacing:0,children:[
            IconButton(tooltip:'اعتماد',onPressed:()=>_reviewEmployeeLeave(leave['id'].toString(),'approved'),icon:const Icon(Icons.check_circle_outline,color:Colors.green)),
            IconButton(tooltip:'رفض',onPressed:()=>_reviewEmployeeLeave(leave['id'].toString(),'rejected'),icon:const Icon(Icons.cancel_outlined,color:Colors.redAccent)),
          ])
          :null,
      ));
    }),
  ]);

  Widget _infoPanel(String title, String body) => Card(
    elevation: 0, color: const Color(0xFFF8F5FC),
    child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _workspacePurple, fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 10), Text(body, style: const TextStyle(height: 1.8)),
      const SizedBox(height: 12),
      const Text('المعلومات المعروضة تخص مساحة النشاط الحالية، وتظل مستقلة عن بيانات سلسلة وباقي الأنشطة.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
    ])),
  );

  Widget _reportsView(String kind) {
    final basic = kind == 'تقارير البيانات الأساسية';
    final finance = kind == 'تقارير مالية وتحليلات';
    final posted = _documents.where((d)=>d['status']=='posted').toList();
    return ListView(children:[
      _backHeader(kind),
      if (basic) ...[
        _sectionTitle('تقرير البيانات الأساسية','أعداد شاملة من قاعدة البيانات وفق صلاحياتك ونطاق الفروع والمخازن'),
        _tileGrid([
          ('الفروع',Icons.account_tree,_metricCount('branches_count',_branches.length.toString())),
          ('المخازن',Icons.warehouse,_metricCount('warehouses_count',_warehouses.length.toString())),
          if (_canWorkspacePermission('members.read')) ('المستخدمون',Icons.people,_metricCount('members_count',_members.length.toString())),
          ('الأصناف المفعلة',Icons.inventory,_metricCount('items_count',_itemLinks.where((x)=>x['is_enabled']==true).length.toString())),
          if (_canWorkspacePermission('hr.read')) ('الإدارات والأقسام',Icons.corporate_fare,_metricCount('departments_count',_departments.length.toString())),
          if (_canWorkspacePermission('hr.read')) ('الموظفون',Icons.badge,_metricCount('employees_count',_employees.length.toString())),
        ]),
      ] else if (finance) ...[
        _sectionTitle('التحليل المالي التشغيلي','إجماليات شاملة من المستندات المرحلة والحركات النقدية؛ لا تمثل قائمة مالية أو إقراراً ضريبياً معتمداً'),
        _tileGrid([
          ('مبيعات مرحلة',Icons.trending_up,_metricMoney('sales_total')),
          ('مشتريات مرحلة',Icons.shopping_cart,_metricMoney('purchases_total')),
          ('مرتجعات البيع',Icons.assignment_return,_metricMoney('sales_returns_total')),
          ('مرتجعات الشراء',Icons.keyboard_return,_metricMoney('purchase_returns_total')),
          ('مقبوضات',Icons.south_west,_metricMoney('cash_in_total')),
          ('مدفوعات',Icons.north_east,_metricMoney('cash_out_total')),
          ('صافي قيمة المخزون المتحركة',Icons.inventory_2,_metricMoney('stock_net_value')),
        ]),
      ] else ...[
        _sectionTitle('تقرير الحركات','إجماليات شاملة من قاعدة البيانات، مع عرض أحدث 20 مستنداً للتفاصيل'),
        _tileGrid([
          ('كل المستندات',Icons.receipt_long,_metricCount('documents_count',_documents.length.toString())),
          ('مستندات مرحلة',Icons.verified,_metricCount('posted_documents_count',posted.length.toString())),
          ('مسودات',Icons.edit_note,_metricCount('draft_documents_count',_documents.where((d)=>d['status']=='draft').length.toString())),
          ('حركات نقدية',Icons.payments,_metricCount('cash_movements_count',_cashMovements.length.toString())),
          ('حركات مخزنية',Icons.inventory_2,_metricCount('stock_movements_count',_stockMovements.length.toString())),
        ]),
        const Divider(),
        ...posted.take(20).map((d)=>ListTile(dense:true,title:Text(d['document_no'].toString()),subtitle:Text('${d['document_type']} • ${d['document_date']}'),trailing:Text('${d['total']}'))),
        if (_canWorkspacePermission('audit.read')) ...[
          const Divider(),
          _sectionTitle('سجل المراجعة','${_auditRows.length} عملية موثقة'),
          ..._auditRows.take(30).map((a)=>ListTile(dense:true,leading:const Icon(Icons.history,color:_workspacePurple),title:Text('${a['action']} • ${a['entity_type']}'),subtitle:Text('${a['created_at']} • ${a['entity_id'] ?? ''}'))),
        ],
      ],
    ]);
  }

  void _exitWorkspace() {
    final callback = widget.onExit;
    if (callback != null) { callback(); } else { Navigator.of(context).maybePop(); }
  }

  Widget _exitWorkspaceView() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth:420),
    child: Card(elevation:0,child:Padding(padding:const EdgeInsets.all(24),child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.logout_rounded,size:48,color:_workspacePurple),
        const SizedBox(height:12),
        const Text('الخروج من إدارة نشاطي',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18,color:_workspacePurple)),
        const SizedBox(height:8),
        const Text('سيتم الرجوع إلى قوائم سلسلة الرئيسية. بيانات النشاط محفوظة ولن يتم حذف أي سجل.',textAlign:TextAlign.center),
        const SizedBox(height:16),
        FilledButton.icon(onPressed:_exitWorkspace,icon:const Icon(Icons.arrow_forward),label:const Text('العودة إلى سلسلة')),
      ],
    ))),
  ));

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

  Widget _dashboardSection(String title, String subtitle, List<(String,IconData,String)> tiles) => Card(
    elevation:0,
    margin:const EdgeInsets.only(bottom:12),
    shape:RoundedRectangleBorder(
      borderRadius:BorderRadius.circular(20),
      side:const BorderSide(color:Color(0xFFE8E0F0)),
    ),
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(title,style:const TextStyle(color:_workspacePurple,fontWeight:FontWeight.w900,fontSize:17)),
        Text(subtitle,style:const TextStyle(color:Colors.black54,fontSize:11)),
        const SizedBox(height:10),
        _tileGrid(tiles),
      ]),
    ),
  );

  Widget _tileGrid(List<(String, IconData, String)> tiles) => LayoutBuilder(builder: (context, c) {
    final count = c.maxWidth > 1100 ? 4 : c.maxWidth > 650 ? 2 : 1;
    return GridView.count(
      crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: count == 1 ? 4.2 : count == 4 ? 1.8 : 2.4,
      children: tiles.map((t) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          switch (t.$1) {
            case 'بيانات نشاطي': _area='بياناتي الأساسية'; _basicTab=0; break;
            case 'مستخدمين نشاطي': _area='بياناتي الأساسية'; _basicTab=1; break;
            case 'رصيد مخازني': _area='بياناتي الأساسية'; _basicTab=2; break;
            case 'موظفين نشاطي': _area='بياناتي الأساسية'; _basicTab=3; break;
            default: _area=t.$1;
          }
          if (t.$1 == 'فاتورة شراء / مرتجع شراء') _documentType = 'purchase';
          if (t.$1 == 'فاتورة بيع / مرتجع بيع') _documentType = 'sale';
        }),
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
