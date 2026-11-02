import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> _cashMovements = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _stockMovements = [];
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
  String? _selectedDepartmentId;
  final _departmentCode = TextEditingController();
  final _departmentName = TextEditingController();
  final _employeeName = TextEditingController();
  final _employeeJob = TextEditingController();
  final _employeeSalary = TextEditingController(text: '0');
  String? _selectedBranchForWarehouse;
  String _cashType = 'receipt';
  final _cashAmount = TextEditingController();
  final _cashDescription = TextEditingController();
  final _cashCounterparty = TextEditingController();
  final _cashReference = TextEditingController();
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
    _cashAmount.dispose(); _cashDescription.dispose(); _cashCounterparty.dispose(); _cashReference.dispose();
    _departmentCode.dispose(); _departmentName.dispose(); _employeeName.dispose(); _employeeJob.dispose(); _employeeSalary.dispose();
    _docCounterparty.dispose(); _docNotes.dispose(); _docQuantity.dispose(); _docUnitPrice.dispose(); _docDiscount.dispose(); _docTax.dispose();
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
        _safeRows(() => _db.from('erp_business_workspace_item_links').select('id,workspace_id,platform_item_id,is_enabled,local_code,reorder_level,erp_items(item_code,item_name,base_unit)').eq('workspace_id', id).order('created_at')),
        _safeRows(() => _db.from('erp_business_workspace_stock_openings').select('id,warehouse_id,item_link_id,quantity,unit_cost,opening_date').eq('workspace_id', id).order('created_at')),
        _safeRows(() => _db.from('erp_business_workspace_item_proposals').select('id,name_ar,name_en,proposed_category,unit_name,status,review_note,created_at').eq('workspace_id', id).order('created_at', ascending: false)),
        _safeRows(() => _db.from('erp_business_workspace_cash_movements').select('id,movement_no,movement_type,movement_date,amount,description,counterparty_name,payment_method,reference_no').eq('workspace_id', id).order('movement_date', ascending: false).limit(200)),
        _safeRows(() => _db.from('erp_business_workspace_departments').select('id,parent_id,department_code,name_ar,is_active').eq('workspace_id', id).order('name_ar')),
        _safeRows(() => _db.from('erp_business_workspace_employees').select('id,department_id,employee_code,full_name,job_title,monthly_salary,is_active').eq('workspace_id', id).order('full_name')),
        _safeRows(() => _db.from('erp_business_workspace_documents').select('id,document_no,document_type,document_date,counterparty_name,status,total,created_at').eq('workspace_id', id).order('created_at', ascending: false).limit(200)),
        _safeRows(() => _db.from('erp_business_workspace_stock_movements').select('id,warehouse_id,item_link_id,movement_type,quantity_in,quantity_out,unit_cost,movement_date').eq('workspace_id', id).order('movement_date', ascending: false).limit(1000)),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(result[0]);
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
        _selectedDocBranchId = _branches.any((x) => x['id'].toString() == _selectedDocBranchId) ? _selectedDocBranchId : (_branches.isNotEmpty ? _branches.first['id'].toString() : null);
        _selectedDocWarehouseId = _warehouses.any((x) => x['id'].toString() == _selectedDocWarehouseId) ? _selectedDocWarehouseId : (_warehouses.isNotEmpty ? _warehouses.first['id'].toString() : null);
        _selectedDocItemLinkId = _itemLinks.any((x) => x['id'].toString() == _selectedDocItemLinkId && x['is_enabled'] == true) ? _selectedDocItemLinkId : (_itemLinks.where((x) => x['is_enabled'] == true).isNotEmpty ? _itemLinks.firstWhere((x) => x['is_enabled'] == true)['id'].toString() : null);
        _selectedDepartmentId = _departments.any((x) => x['id'].toString() == _selectedDepartmentId) ? _selectedDepartmentId : (_departments.isNotEmpty ? _departments.first['id'].toString() : null);
        _selectedBranchForWarehouse = _branches.any((x) => x['id'].toString() == _selectedBranchForWarehouse) ? _selectedBranchForWarehouse : (_branches.isNotEmpty ? _branches.first['id'].toString() : null);
        _selectedStockWarehouseId = _warehouses.any((x) => x['id'].toString() == _selectedStockWarehouseId) ? _selectedStockWarehouseId : (_warehouses.isNotEmpty ? _warehouses.first['id'].toString() : null);
        _selectedStockItemLinkId = _itemLinks.any((x) => x['id'].toString() == _selectedStockItemLinkId) ? _selectedStockItemLinkId : (_itemLinks.isNotEmpty ? _itemLinks.first['id'].toString() : null);
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
    if (id == null || branchId == null || warehouseId == null || _draftLines.isEmpty) {
      _message('اختر الفرع والمخزن وأضف صنفاً واحداً على الأقل.'); return;
    }
    final tax = double.tryParse(_docTax.text.trim()) ?? 0;
    if (tax < 0) { _message('قيمة الضريبة غير صحيحة.'); return; }
    try {
      final now = DateTime.now();
      final prefix = _documentType.toUpperCase();
      final docNo = 'ACT-$prefix-${now.microsecondsSinceEpoch}';
      final docId = await _db.rpc('erp_create_business_workspace_document', params: {
        'p_workspace_id':id,'p_branch_id':branchId,'p_warehouse_id':warehouseId,
        'p_document_no':docNo,'p_document_type':_documentType,
        'p_document_date':now.toIso8601String().substring(0,10),
        'p_counterparty_name':_docCounterparty.text.trim(),
        'p_notes':_docNotes.text.trim(),
        'p_lines':_draftLines,
        'p_tax':tax,
      });
      setState(() { _draftLines.clear(); });
      _docCounterparty.clear(); _docNotes.clear(); _docTax.text='0';
      await _loadStructure();
      _message('تم إنشاء المستند كمسودة رقم $docNo. لم يتغير المخزون بعد.');
    } catch(e) { _message('تعذر إنشاء المستند: $e'); }
  }

  Future<void> _postWorkspaceDocument(String documentId) async {
    try {
      await _db.rpc('erp_post_business_workspace_document',params:{'p_document_id':documentId});
      await _loadStructure();
      _message('تم اعتماد المستند وترحيل حركته إلى مخزون النشاط.');
    } catch(e) { _message('لم يتم ترحيل المستند: $e'); }
  }

  Future<void> _addDepartment() async {
    final id = _selected?['id']?.toString();
    final code = _departmentCode.text.trim();
    final name = _departmentName.text.trim();
    if (id == null || code.isEmpty || name.isEmpty) { _message('أدخل كود الإدارة واسمها.'); return; }
    try {
      await _db.from('erp_business_workspace_departments').insert({
        'workspace_id':id,'department_code':code,'name_ar':name,
      });
      _departmentCode.clear(); _departmentName.clear();
      await _loadStructure(); _message('تم إضافة الإدارة / القسم.');
    } catch(e) { _message('تعذر حفظ الإدارة: $e'); }
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
        'work_schedule':<String,dynamic>{'type':'standard'},
        'leave_policy':<String,dynamic>{},
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
    try {
      final now = DateTime.now();
      final datePart = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
      final movementNo = 'ACT-$datePart-${now.microsecondsSinceEpoch.toString().substring(8)}';
      await _db.from('erp_business_workspace_cash_movements').insert({
        'workspace_id': id,
        'branch_id': _selectedBranchForWarehouse,
        'movement_no': movementNo,
        'movement_type': _cashType,
        'movement_date': now.toIso8601String().substring(0,10),
        'amount': amount,
        'description': description,
        'counterparty_name': _cashCounterparty.text.trim().isEmpty ? null : _cashCounterparty.text.trim(),
        'payment_method': 'cash',
        'reference_no': _cashReference.text.trim().isEmpty ? null : _cashReference.text.trim(),
        'created_by': _db.auth.currentUser!.id,
      });
      _cashAmount.clear(); _cashDescription.clear(); _cashCounterparty.clear(); _cashReference.clear();
      await _loadStructure();
      _message('تم حفظ حركة النقدية.'); 
    } catch (e) { _message('تعذر حفظ حركة النقدية: $e'); }
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
        'workspace_id': id, 'branch_id': _selectedBranchForWarehouse ?? _branches.first['id'],
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
    if (_area == 'صرف وتوريد نقدية') return _cashMovementsView();
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
          ('الأصناف', Icons.inventory_2_outlined, '${_itemLinks.where((x)=>x['is_enabled']==true).length} صنف مفعل'),
          ('مستندات مرحلة', Icons.receipt_long, '${_documents.where((x)=>x['status']=='posted').length} مستند'),
        ]),
        const SizedBox(height:12),
        _sectionTitle('مؤشرات النشاط','ملخص تشغيلي من البيانات المسجلة داخل هذه المساحة'),
        _tileGrid([
          ('إجمالي المبيعات', Icons.trending_up, '${_documentTotal('sale')} جنيه'),
          ('إجمالي المشتريات', Icons.shopping_cart_outlined, '${_documentTotal('purchase')} جنيه'),
          ('الوارد النقدي', Icons.south_west, '${_cashTotal(true)} جنيه'),
          ('الصادر النقدي', Icons.north_east, '${_cashTotal(false)} جنيه'),
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

  Widget _documentsView({required bool purchase}) => ListView(children: [
    _backHeader(purchase?'فاتورة شراء / مرتجع شراء':'فاتورة بيع / مرتجع بيع'),
    _sectionTitle(purchase?'مشتريات النشاط':'مبيعات النشاط','مستندات مستقلة بمسودات واعتماد قبل ترحيل المخزون'),
    Wrap(spacing:6,children:[
      ChoiceChip(label:Text(purchase?'فاتورة شراء':'فاتورة بيع'),selected:_documentType==(purchase?'purchase':'sale'),onSelected:(_){setState(()=>_documentType=purchase?'purchase':'sale');}),
      ChoiceChip(label:Text(purchase?'مرتجع شراء':'مرتجع بيع'),selected:_documentType==(purchase?'purchase_return':'sale_return'),onSelected:(_){setState(()=>_documentType=purchase?'purchase_return':'sale_return');}),
    ]),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_branches.any((x)=>x['id'].toString()==_selectedDocBranchId)?_selectedDocBranchId:null,
      decoration:const InputDecoration(labelText:'الفرع'),
      items:_branches.map((b)=>DropdownMenuItem(value:b['id'].toString(),child:Text(b['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedDocBranchId=v),
    ),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(
      value:_warehouses.any((x)=>x['id'].toString()==_selectedDocWarehouseId)?_selectedDocWarehouseId:null,
      decoration:const InputDecoration(labelText:'المخزن'),
      items:_warehouses.map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name_ar'].toString()))).toList(),
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
    TextField(controller:_docTax,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'ضريبة المستند')),
    TextField(controller:_docNotes,decoration:const InputDecoration(labelText:'ملاحظات')),
    const SizedBox(height:8),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_createWorkspaceDocument,icon:const Icon(Icons.save),label:const Text('حفظ كمسودة'))),
    const Divider(),
    _sectionTitle('مستندات النشاط','${_documents.where((d)=>purchase?['purchase','purchase_return'].contains(d['document_type']):['sale','sale_return'].contains(d['document_type'])).length} مستند'),
    ..._documents.where((d)=>purchase?['purchase','purchase_return'].contains(d['document_type']):['sale','sale_return'].contains(d['document_type'])).map((d)=>Card(
      elevation:0,child:ListTile(dense:true,
        title:Text('${d['document_no']} • ${d['document_type']}'),
        subtitle:Text('${d['document_date']} • ${d['counterparty_name']??'بدون طرف'} • ${d['status']}'),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          Text('${d['total']}',style:const TextStyle(fontWeight:FontWeight.w800,color:_workspacePurple)),
          if(d['status']=='draft') IconButton(tooltip:'اعتماد وترحيل',icon:const Icon(Icons.check_circle,color:Colors.green),onPressed:()=>_postWorkspaceDocument(d['id'].toString())),
        ]),
      ),
    )),
  ]);

  Widget _cashMovementsView() => ListView(children: [
    _backHeader('صرف وتوريد نقدية'),
    _sectionTitle('حركة نقدية مستقلة', 'كل حركة تخص النشاط الحالي ولا تُرحل إلى خزائن سلسلة'),
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
      value: _branches.any((x)=>x['id'].toString()==_selectedBranchForWarehouse)?_selectedBranchForWarehouse:null,
      decoration: const InputDecoration(labelText:'الفرع'),
      items:_branches.map((b)=>DropdownMenuItem(value:b['id'].toString(),child:Text(b['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedBranchForWarehouse=v),
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
    const Divider(),
    _sectionTitle('سجل الحركات النقدية','${_cashMovements.length} حركة مسجلة'),
    ..._cashMovements.map((m)=>ListTile(dense:true,
      leading:Icon(['receipt','deposit','income','transfer_in'].contains(m['movement_type'])?Icons.south_west:Icons.north_east,color:['receipt','deposit','income','transfer_in'].contains(m['movement_type'])?Colors.green:Colors.deepOrange),
      title:Text(m['description'].toString()),
      subtitle:Text('${m['movement_no']} • ${m['movement_date']} • ${m['counterparty_name'] ?? 'بدون طرف'}'),
      trailing:Text('${m['amount']}',style:const TextStyle(fontWeight:FontWeight.w800,color:_workspacePurple)),
    )),
  ]);

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
    DropdownButtonFormField<String>(
      value: _branches.any((x) => x['id'].toString() == _selectedBranchForWarehouse) ? _selectedBranchForWarehouse : null,
      decoration: const InputDecoration(labelText: 'الفرع التابع له المخزن'),
      items: _branches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name_ar'].toString()))).toList(),
      onChanged: (v) => setState(() => _selectedBranchForWarehouse = v),
    ),
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
  Widget _employeesInfo() => ListView(children: [
    _sectionTitle('إداراتي وأقسامي', 'هيكل إداري مستقل بنظام الشجرة'),
    Row(children:[
      Expanded(child:TextField(controller:_departmentCode,decoration:const InputDecoration(labelText:'كود الإدارة / القسم'))),
      const SizedBox(width:8),
      Expanded(child:TextField(controller:_departmentName,decoration:const InputDecoration(labelText:'اسم الإدارة / القسم'))),
      IconButton(onPressed:_addDepartment,icon:const Icon(Icons.add_circle,color:_workspacePurple)),
    ]),
    ..._departments.map((d)=>ListTile(dense:true,leading:Icon(d['parent_id']==null?Icons.account_tree:Icons.subdirectory_arrow_left,color:_workspacePurple),
      title:Text(d['name_ar'].toString()),subtitle:Text(d['department_code'].toString()))),
    const Divider(),
    _sectionTitle('موظفين نشاطي','بيانات مبسطة مستقلة عن موظفي سلسلة'),
    DropdownButtonFormField<String>(
      value:_departments.any((d)=>d['id'].toString()==_selectedDepartmentId)?_selectedDepartmentId:null,
      decoration:const InputDecoration(labelText:'الإدارة / القسم'),
      items:_departments.map((d)=>DropdownMenuItem(value:d['id'].toString(),child:Text(d['name_ar'].toString()))).toList(),
      onChanged:(v)=>setState(()=>_selectedDepartmentId=v),
    ),
    TextField(controller:_employeeName,decoration:const InputDecoration(labelText:'اسم الموظف *')),
    TextField(controller:_employeeJob,decoration:const InputDecoration(labelText:'الوظيفة')),
    TextField(controller:_employeeSalary,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المرتب الشهري')),
    const SizedBox(height:8),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_addEmployee,icon:const Icon(Icons.person_add),label:const Text('إضافة موظف'))),
    const Divider(),
    _sectionTitle('قوة العمل','${_employees.length} موظف مسجل'),
    ..._employees.map((e)=>ListTile(dense:true,leading:const Icon(Icons.badge_outlined,color:_workspaceOrange),
      title:Text(e['full_name'].toString()),
      subtitle:Text('${e['employee_code']} • ${e['job_title'] ?? 'بدون وظيفة'}'),
      trailing:Text('${e['monthly_salary']}',style:const TextStyle(color:_workspacePurple,fontWeight:FontWeight.w800)),
    )),
  ]);

  Widget _infoPanel(String title, String body) => Card(
    elevation: 0, color: const Color(0xFFF8F5FC),
    child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _workspacePurple, fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 10), Text(body, style: const TextStyle(height: 1.8)),
      const SizedBox(height: 12),
      const Text('هذه الوحدة ضمن خطة التنفيذ، ولم يتم تفعيل عملياتها بعد.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700)),
    ])),
  );

  double _documentTotal(String type) => _documents.where((d)=>d['status']=='posted' && d['document_type']==type).fold<double>(0,(sum,d)=>sum+(double.tryParse(d['total'].toString())??0));

  double _cashTotal(bool incoming) {
    final incomingTypes = ['receipt','deposit','income','transfer_in'];
    return _cashMovements.where((m)=>incomingTypes.contains(m['movement_type'])==incoming).fold<double>(0,(sum,m)=>sum+(double.tryParse(m['amount'].toString())??0));
  }

  Widget _reportsView(String kind) {
    final basic = kind == 'تقارير البيانات الأساسية';
    final finance = kind == 'تقارير مالية وتحليلات';
    final posted = _documents.where((d)=>d['status']=='posted').toList();
    final quantity = _stockMovements.fold<double>(0,(sum,m)=>sum+(double.tryParse(m['quantity_in'].toString())??0)-(double.tryParse(m['quantity_out'].toString())??0));
    return ListView(children:[
      _backHeader(kind),
      if (basic) ...[
        _sectionTitle('تقرير البيانات الأساسية','إحصاء السجلات المعرفة في النشاط'),
        _tileGrid([
          ('الفروع',Icons.account_tree,'${_branches.length}'),
          ('المخازن',Icons.warehouse,'${_warehouses.length}'),
          ('المستخدمون',Icons.people,'${_members.length}'),
          ('الأصناف المفعلة',Icons.inventory,'${_itemLinks.where((x)=>x['is_enabled']==true).length}'),
          ('الإدارات والأقسام',Icons.corporate_fare,'${_departments.length}'),
          ('الموظفون',Icons.badge,'${_employees.length}'),
        ]),
      ] else if (finance) ...[
        _sectionTitle('التحليل المالي التشغيلي','المبالغ المستخرجة من المستندات والحركات المسجلة، وليست بديلاً عن قائمة مالية معتمدة'),
        _tileGrid([
          ('مبيعات مرحلة',Icons.trending_up,'${_documentTotal('sale')} جنيه'),
          ('مشتريات مرحلة',Icons.shopping_cart,'${_documentTotal('purchase')} جنيه'),
          ('مرتجعات البيع',Icons.assignment_return,'${_documentTotal('sale_return')} جنيه'),
          ('مرتجعات الشراء',Icons.keyboard_return,'${_documentTotal('purchase_return')} جنيه'),
          ('مقبوضات',Icons.south_west,'${_cashTotal(true)} جنيه'),
          ('مدفوعات',Icons.north_east,'${_cashTotal(false)} جنيه'),
        ]),
      ] else ...[
        _sectionTitle('تقرير الحركات','حالة المستندات والحركات المخزنية والنقدية'),
        _tileGrid([
          ('كل المستندات',Icons.receipt_long,'${_documents.length}'),
          ('مستندات مرحلة',Icons.verified,'${posted.length}'),
          ('مسودات',Icons.edit_note,'${_documents.where((d)=>d['status']=='draft').length}'),
          ('حركات نقدية',Icons.payments,'${_cashMovements.length}'),
          ('حركات مخزنية',Icons.inventory_2,'${_stockMovements.length}'),
          ('صافي كمية الحركة',Icons.scale,'${quantity.toStringAsFixed(2)}'),
        ]),
        const Divider(),
        ...posted.take(20).map((d)=>ListTile(dense:true,title:Text(d['document_no'].toString()),subtitle:Text('${d['document_type']} • ${d['document_date']}'),trailing:Text('${d['total']}'))),
      ],
    ]);
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
        FilledButton.icon(onPressed:()=>widget.onExit?.call() ?? Navigator.of(context).maybePop(),icon:const Icon(Icons.arrow_forward),label:const Text('العودة إلى سلسلة')),
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

  Widget _tileGrid(List<(String, IconData, String)> tiles) => LayoutBuilder(builder: (context, c) {
    final count = c.maxWidth > 1050 ? 3 : c.maxWidth > 650 ? 2 : 1;
    return GridView.count(
      crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: count == 1 ? 4.2 : 2.4,
      children: tiles.map((t) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() { _area = t.$1; if (t.$1 == 'فاتورة شراء / مرتجع شراء') _documentType = 'purchase'; if (t.$1 == 'فاتورة بيع / مرتجع بيع') _documentType = 'sale'; }),
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
