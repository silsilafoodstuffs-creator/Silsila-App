import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  final _warehouseCode = TextEditingController();
  final _warehouseName = TextEditingController();
  final _warehouseNameEn = TextEditingController();
  final _warehouseLocation = TextEditingController();
  final _warehousePhone = TextEditingController();
  final _warehouseLandline = TextEditingController();
  final _address = TextEditingController();
  final _itemCode = TextEditingController();
  final _itemName = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'وحدة');
  final _middleUnit = TextEditingController();
  final _minorUnit = TextEditingController();
  final _majorInner = TextEditingController(text: '1');
  final _middleInner = TextEditingController(text: '1');
  final _purchasePrice = TextEditingController(text: '0');
  final _salePrice = TextEditingController(text: '0');
  final _taxRate = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '0');
  final _itemSearch = TextEditingController();
  int _itemsOffset = 0;
  bool _itemsHasMore = false;
  bool _itemsLoadingMore = false;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _workspaceItemProposals = [];
  List<Map<String, dynamic>> _sharedWorkspaceStock = [];
  String? _selectedSharedItemId;
  bool _sharedStockLoaded = false;
  bool _isManagementUser = false;
  final Map<String,String> _proposalNameEdits = {};
  final Map<String,String> _proposalUnitEdits = {};
  final Map<String,String?> _proposalCategorySelections = {};
  List<Map<String, dynamic>> _itemUnits = [];
  List<Map<String, dynamic>> _warehouseItemSettings = [];
  final Map<String, Future<Uint8List?>> _itemImageFutures = <String, Future<Uint8List?>>{};
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _geoRows = [];
  String? _branchId;
  String? _parentWarehouseId;
  String? _governorateId, _districtId, _areaId;
  String? _itemCategoryId;
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
    _company.dispose(); _warehouseCode.dispose(); _warehouseName.dispose(); _warehouseNameEn.dispose(); _warehouseLocation.dispose(); _warehousePhone.dispose(); _warehouseLandline.dispose(); _address.dispose();
    _itemCode.dispose(); _itemName.dispose(); _barcode.dispose(); _unit.dispose(); _middleUnit.dispose(); _minorUnit.dispose(); _majorInner.dispose(); _middleInner.dispose(); _itemSearch.dispose();
    _purchasePrice.dispose(); _salePrice.dispose(); _taxRate.dispose(); _reorder.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  bool _isSecondaryCategory(Map<String, dynamic> category) {
    final parentId = _s(category['parent_id']);
    if (parentId.isEmpty) return false;
    final parents = _categories.where((row) => _s(row['id']) == parentId).toList();
    return parents.isNotEmpty && _s(parents.first['parent_id']).isNotEmpty;
  }
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);
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
      setState(() {
        _loading = false;
        _warehouses = [];
        _branches = [];
        _error = 'لم يتم العثور على شركة نشطة لحسابك. افتح بيانات الشركة أو تحقق من عضوية الشركة.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; if (clearMessage) _message = null; });
    try {
      final companyId = _company.text.trim();
      final loadErrors = <String>[];
      var isManagementUser = false;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        try {
          final profile = await Supabase.instance.client.from('profiles').select('role,account_status').eq('id',currentUserId).maybeSingle();
          isManagementUser = profile?['role']=='management' && profile?['account_status']=='active';
        } catch (_) {}
      }
      Future<List<Map<String, dynamic>>> loadPart(
        String label,
        Future<List<Map<String, dynamic>>> Function() action,
      ) async {
        try {
          return await action();
        } catch (e) {
          loadErrors.add('$label: $e');
          return <Map<String, dynamic>>[];
        }
      }
      final values = await Future.wait<List<Map<String, dynamic>>>([
        loadPart('المخازن', () => _repo.fetchWarehouses(companyId)),
        loadPart('الأصناف', () => _repo.fetchItems(companyId, pageSize: 500, search: _itemSearch.text)),
        loadPart('الفروع', () => _repo.fetchBranches(companyId)),
        loadPart('فئات الأصناف', () => _repo.fetchCategories(companyId)),
        loadPart('أصناف مقترحة', () async {
          if (!isManagementUser) return <Map<String,dynamic>>[];
          final rows = await Supabase.instance.client.from('erp_business_workspace_item_proposals')
            .select('id,workspace_id,name_ar,name_en,proposed_category,unit_name,description,status,created_at,review_note,erp_business_workspaces(workspace_name,activity_type)')
            .eq('status','pending').order('created_at',ascending:false);
          return List<Map<String,dynamic>>.from(rows);
        }),
      ]);
      // Optional item-unit settings must never block the primary warehouse/branch
      // directory. Load each auxiliary dataset independently and preserve the
      // successfully fetched warehouse rows if one optional query is unavailable.
      final itemIds = values[1].map((r) => _s(r['id'])).toList();
      final extra = await Future.wait<List<Map<String, dynamic>>>([
        loadPart('وحدات قياس الأصناف', () => _repo.fetchItemUnits(companyId, itemIds)),
        loadPart('إعدادات الأصناف حسب المخزن', () => _repo.fetchItemWarehouseSettings(companyId, itemIds)),
      ]);
      List<Map<String, dynamic>> geoRows = [];
      try {
        final geoResult = await Supabase.instance.client.from('erp_geographic_data')
            .select('id,parent_id,name_ar,level,is_active')
            .eq('company_id', companyId).eq('is_active', true).order('name_ar');
        geoRows = (geoResult as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        // Geography is optional; it must not hide successfully loaded warehouse data.
      }
      if (!mounted) return;
      setState(() {
        _warehouses = values[0]; _items = values[1]; _itemImageFutures.clear(); _itemsOffset = values[1].length; _itemsHasMore = values[1].length == 500; _branches = values[2]; _categories = values[3]; _workspaceItemProposals = values[4]; _isManagementUser = isManagementUser; _itemUnits = extra[0];
        _selectedSharedItemId = _items.any((item)=>_s(item['id'])==_selectedSharedItemId) ? _selectedSharedItemId : (_items.isNotEmpty ? _s(_items.first['id']) : null); if (!isManagementUser && (_view=='proposals'||_view=='shared_stock')) _view='items'; _warehouseItemSettings = extra[1]; _geoRows = geoRows;
        if (!_categories.any((g) => _s(g['id']) == _itemCategoryId && g['is_active'] == true)) _itemCategoryId = null;
        if (!_branches.any((b) => _s(b['id']) == _branchId)) _branchId = null;
        _loading = false;
        _error = loadErrors.isEmpty ? null : 'تم تحميل البيانات المتاحة، وتعذر تحميل بعض الأقسام: ${loadErrors.join(' | ')}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل بيانات المخازن والأصناف: $e'; });
    }
  }

  Future<void> _searchItems() async {
    if (_view != 'items') return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _repo.fetchItems(_company.text.trim(), pageSize: 500, search: _itemSearch.text);
      final ids = rows.map((r) => _s(r['id'])).toList();
      final extra = await Future.wait([
        _repo.fetchItemUnits(_company.text.trim(), ids),
        _repo.fetchItemWarehouseSettings(_company.text.trim(), ids),
      ]);
      if (!mounted) return;
      setState(() { _itemUnits = extra[0]; _warehouseItemSettings = extra[1]; _items = rows; _itemImageFutures.clear(); _itemsOffset = rows.length; _itemsHasMore = rows.length == 500; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر البحث في الأصناف: $e'; });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_itemsLoadingMore || !_itemsHasMore) return;
    setState(() => _itemsLoadingMore = true);
    try {
      final rows = await _repo.fetchItems(_company.text.trim(), offset: _itemsOffset, pageSize: 500, search: _itemSearch.text);
      final ids = rows.map((r) => _s(r['id'])).toList();
      final extra = await Future.wait([
        _repo.fetchItemUnits(_company.text.trim(), ids),
        _repo.fetchItemWarehouseSettings(_company.text.trim(), ids),
      ]);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows); _itemUnits.addAll(extra[0]); _warehouseItemSettings.addAll(extra[1]);
        _itemsOffset += rows.length; _itemsHasMore = rows.length == 500; _itemsLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _itemsLoadingMore = false; _error = 'تعذر تحميل صفحة الأصناف التالية: $e'; });
    }
  }

  Future<void> _createWarehouse() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final generatedWarehouseCode = await _repo.createWarehouse(companyId: _company.text,
        name: _warehouseName.text, branchId: _branchId, address: _address.text,
        nameEn: _warehouseNameEn.text, parentWarehouseId: _parentWarehouseId,
        location: _warehouseLocation.text, phone: _warehousePhone.text, landline: _warehouseLandline.text,
        governorateId: _governorateId, districtId: _districtId, areaId: _areaId);
      if (!mounted) return;
      _warehouseCode.clear(); _warehouseName.clear(); _warehouseNameEn.clear(); _warehouseLocation.clear(); _warehousePhone.clear(); _warehouseLandline.clear(); _address.clear(); _parentWarehouseId = null; _governorateId = null; _districtId = null; _areaId = null;
      setState(() { _saving = false; _message = 'تمت إضافة المخزن بالكود التلقائي: $generatedWarehouseCode'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة المخزن: $e'; });
    }
  }


  Future<void> _deleteWarehouse(Map<String, dynamic> warehouse) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('حذف المخزن'),
      content: Text('حذف المخزن «${_s(warehouse['warehouse_name'])}»؟ إذا كان مرتبطًا بحركات أو يحتوي مخازن فرعية سيرفض النظام الحذف.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No / لا')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Yes / نعم، احذف المخزن')),
      ],
    ));
    if (yes != true) return;
    try {
      await Supabase.instance.client.from('erp_warehouses').delete()
        .eq('id', _s(warehouse['id'])).eq('company_id', _company.text.trim());
      if (mounted) setState(() => _message = 'تم حذف المخزن.');
      await _load(clearMessage: false);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حذف المخزن؛ قد يكون مرتبطًا بحركات أو بمخازن فرعية: $e');
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
    final majorInner = double.tryParse(_majorInner.text.trim()) ?? -1;
    final middleInner = double.tryParse(_middleInner.text.trim()) ?? -1;
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
      final generatedItemCode = await _repo.createItem(companyId: _company.text, name: _itemName.text,
        barcode: _barcode.text, categoryId: _itemCategoryId, unit: _unit.text,
        middleUnit: _middleUnit.text, minorUnit: _minorUnit.text,
        majorInnerQuantity: majorInner, middleInnerQuantity: _middleUnit.text.trim().isEmpty ? null : middleInner,
        purchasePrice: purchase,
        salePrice: sale, taxRate: taxRate, reorderLevel: reorder, expiryTracking: _expiry,
        imageBytes: imageBytes, imageMimeType: imageBytes == null ? null : contentType);
      if (!mounted) return;
      _itemCode.clear(); _itemName.clear(); _barcode.clear(); _middleUnit.clear(); _minorUnit.clear(); _majorInner.text = '1'; _middleInner.text = '1'; _pickedItemImage = null; _pickedItemImageBytes = null; _purchasePrice.text = '0'; _salePrice.text = '0'; _taxRate.text = '0'; _reorder.text = '0';
      setState(() { _saving = false; _message = 'تمت إضافة الصنف بالكود التلقائي: $generatedItemCode'; });
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
      else await _repo.setWarehouseActive(_s(row['id']), row['is_active'] != true);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تحديث الحالة.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تحديث الحالة: $e'; });
    }
  }

  String _categoryLabel(String? id) {
    final rows = _categories.where((g) => _s(g['id']) == id);
    return rows.isEmpty ? 'بدون فئة' : _s(rows.first['category_code']) + ' — ' + _s(rows.first['category_name']);
  }

  String _warehouseParentName(String? id) {
    final rows = _warehouses.where((w) => _s(w['id']) == id);
    return rows.isEmpty ? '' : _s(rows.first['warehouse_name']);
  }

  String _branchName(String? id) {
    final rows = _branches.where((b) => _s(b['id']) == id);
    return rows.isEmpty ? 'بدون فرع محدد' : _s(rows.first['branch_code']) + ' — ' + _s(rows.first['branch_name']);
  }

Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  void _newCurrentRecord() {
    if (_view == 'proposals' || _view == 'shared_stock') {
      setState(() => _message = 'استخدم أدوات التبويب الحالي بدلاً من إضافة سجل جديد.');
      return;
    }
    final currentFields = _view == 'warehouses'
        ? [_warehouseCode.text, _warehouseName.text, _warehouseNameEn.text, _warehouseLocation.text, _warehousePhone.text, _warehouseLandline.text, _address.text]
        : [_itemCode.text, _itemName.text, _barcode.text,
                _unit.text == 'وحدة' ? '' : _unit.text, _middleUnit.text, _minorUnit.text, _majorInner.text, _middleInner.text,
                _purchasePrice.text == '0' ? '' : _purchasePrice.text,
                _salePrice.text == '0' ? '' : _salePrice.text,
                _taxRate.text == '0' ? '' : _taxRate.text,
                _reorder.text == '0' ? '' : _reorder.text];
    final hasSelection = (_view == 'warehouses' && (_branchId != null || _parentWarehouseId != null || _governorateId != null || _districtId != null || _areaId != null)) ||
        (_view == 'items' && (_itemCategoryId != null || _pickedItemImage != null));
    if (currentFields.any((value) => value.trim().isNotEmpty) || hasSelection) {
      setState(() => _message = 'تم الاحتفاظ بالبيانات الحالية كما هي. احفظ السجل الحالي أولًا قبل بدء سجل جديد.');
      return;
    }
    setState(() {
      _error = null; _message = 'نموذج إضافة جديد جاهز.';
      if (_view == 'warehouses') { _warehouseCode.clear(); _warehouseName.clear(); _warehouseNameEn.clear(); _warehouseLocation.clear(); _warehousePhone.clear(); _warehouseLandline.clear(); _address.clear(); _branchId = null; _parentWarehouseId = null; _governorateId = null; _districtId = null; _areaId = null; }
      else {
        _itemCode.clear(); _itemName.clear(); _barcode.clear(); _unit.text = 'وحدة'; _middleUnit.clear(); _minorUnit.clear(); _majorInner.text = '1'; _middleInner.text = '1';
        _purchasePrice.text = '0'; _salePrice.text = '0'; _taxRate.text = '0'; _reorder.text = '0';
        _itemCategoryId = null; _expiry = false; _pickedItemImage = null; _pickedItemImageBytes = null;
      }
    });
  }

  Future<void> _loadSharedWorkspaceStock() async {
    final itemId=_selectedSharedItemId;
    if(!_isManagementUser) { setState(()=>_error='هذا التقرير متاح لمستخدمي إدارة سلسلة المعتمدين فقط.'); return; }
    if(itemId==null||itemId.isEmpty) { setState(()=>_error='لا يوجد صنف نشط لعرض أرصدته.'); return; }
    setState(()=>_loading=true);
    try {
      final rows=await Supabase.instance.client.rpc('erp_get_shared_business_workspace_stock',params:{
        'p_company_id':_company.text.trim(),'p_item_id':itemId,
      });
      if(!mounted)return;
      setState(() {
        _sharedWorkspaceStock=List<Map<String,dynamic>>.from(rows as List);
        _sharedStockLoaded=true;
        _loading=false;
        _error=null;
      });
    } catch(e) {
      if(!mounted)return;
      setState(() { _loading=false; _error='تعذر تحميل الأرصدة المشتركة: $e'; });
    }
  }

  Widget _sharedWorkspaceStockView() {
    final first=_sharedWorkspaceStock.isEmpty?null:_sharedWorkspaceStock.first;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('أرصدة الأنشطة التي سمح أصحابها بمشاركة الرصيد مع سلسلة',style:TextStyle(color:Color(0xFF3E007D),fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      Row(children:[
        Expanded(child:DropdownButtonFormField<String>(
          value:_items.any((item)=>_s(item['id'])==_selectedSharedItemId)?_selectedSharedItemId:null,
          isExpanded:true,decoration:const InputDecoration(labelText:'الصنف المركزي'),
          items:_items.map((item)=>DropdownMenuItem(value:_s(item['id']),child:Text('${_s(item['item_name'])} • ${_s(item['item_code'])}'))).toList(),
          onChanged:(v)=>setState(() {_selectedSharedItemId=v;_sharedStockLoaded=false;_sharedWorkspaceStock=[];}),
        )),
        const SizedBox(width:8),
        FilledButton.icon(onPressed:_loading?null:_loadSharedWorkspaceStock,icon:const Icon(Icons.refresh),label:const Text('عرض الأرصدة')),
      ]),
      if(first!=null) Card(elevation:0,child:Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:18,runSpacing:8,children:[
        Text('رصيد سلسلة: ${first['central_on_hand']}',style:const TextStyle(fontWeight:FontWeight.w800)),
        Text('محجوز: ${first['central_reserved']}'),
        Text('متاح: ${first['central_available']}',style:const TextStyle(color:Color(0xFF3E007D),fontWeight:FontWeight.w900)),
      ]))),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):!_sharedStockLoaded
        ? const Center(child:Text('اختر صنفاً ثم اضغط عرض الأرصدة.'))
        : _sharedWorkspaceStock.isEmpty
          ? const Center(child:Text('لا توجد مخازن مشاركة لهذا الصنف. قد يكون خيار إظهار الرصيد مغلقاً لدى الأنشطة.'))
          : ListView(children:_sharedWorkspaceStock.map((row){
            final qty=double.tryParse(row['shared_quantity'].toString())??0;
            final reorder=double.tryParse(row['reorder_level'].toString())??0;
            final low=qty<reorder;
            final account=row['account_kind']=='customer'?'عميل':row['account_kind']=='supplier'?'مورد':'نشاط';
            return Card(child:ListTile(
              leading:Icon(low?Icons.warning_amber_rounded:Icons.inventory_2_outlined,color:low?Colors.orange:const Color(0xFF3E007D)),
              title:Text('${row['workspace_name']} • $account',style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${row['activity_type']} • ${row['branch_name']} / ${row['warehouse_name']} • حد الطلب: $reorder'),
              trailing:Column(mainAxisSize:MainAxisSize.min,mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(qty.toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF3E007D))),
                if(low) const Text('أقل من الحد',style:TextStyle(color:Colors.deepOrange,fontSize:10)),
              ]),
            ));
          }).toList())),
    ]);
  }

  Future<void> _reviewWorkspaceItemProposal(Map<String,dynamic> proposal,String decision) async {
    final id=_s(proposal['id']);
    final name=_proposalNameEdits[id] ?? _s(proposal['name_ar']);
    final unit=_proposalUnitEdits[id] ?? _s(proposal['unit_name']);
    if(decision=='approve' && name.trim().length<2) {
      setState(()=>_error='اسم الصنف المعتمد يجب أن يتكون من حرفين على الأقل.');
      return;
    }
    setState(()=>_saving=true);
    try {
      await Supabase.instance.client.rpc('erp_review_business_workspace_item_proposal',params:{
        'p_proposal_id':id,'p_decision':decision,'p_company_id':_company.text.trim(),
        'p_category_id':_proposalCategorySelections[id],
        'p_item_code':null,'p_item_name':name.trim(),
        'p_item_name_en':_s(proposal['name_en']),
        'p_unit_name':unit.trim(),'p_note':decision=='approve'?'تم الاعتماد من دليل الأصناف':'تم رفض الاقتراح',
      });
      await _load(clearMessage:false);
      if(!mounted)return;
      setState(()=>_message=decision=='approve'?'تم اعتماد الصنف وإضافته إلى دليل الأصناف المركزي.':'تم رفض اقتراح الصنف.');
    } catch(e) {
      if(!mounted)return;
      setState(()=>_error='تعذرت مراجعة الصنف المقترح: $e');
    } finally {
      if(mounted)setState(()=>_saving=false);
    }
  }

  Widget _workspaceProposalsView() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text('أصناف مقترحة من الأنشطة • ${_workspaceItemProposals.length} طلب قيد المراجعة',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:Color(0xFF3E007D))),
    const SizedBox(height:8),
    Expanded(child:_workspaceItemProposals.isEmpty
      ? const Center(child:Text('لا توجد أصناف مقترحة بانتظار المراجعة.'))
      : ListView(children:_workspaceItemProposals.map((proposal){
        final id=_s(proposal['id']);
        final workspace=proposal['erp_business_workspaces'] is Map?Map<String,dynamic>.from(proposal['erp_business_workspaces']):<String,dynamic>{};
        final matchedCategories=_categories.where((c)=>_s(c['category_name']).toLowerCase()==_s(proposal['proposed_category']).toLowerCase()).toList();
        final categoryValue=_proposalCategorySelections.containsKey(id)?_proposalCategorySelections[id]:(matchedCategories.isEmpty?null:_s(matchedCategories.first['id']));
        return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(_s(workspace['workspace_name']).isEmpty?'نشاط غير محدد':_s(workspace['workspace_name']),style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF3E007D))),
          Text('النشاط: ${_s(workspace['activity_type'])} • تاريخ الطلب: ${_s(proposal['created_at']).split('T').first}',style:const TextStyle(color:Colors.black54,fontSize:12)),
          TextFormField(key:ValueKey('proposal-name-$id'),initialValue:_proposalNameEdits[id]??_s(proposal['name_ar']),decoration:const InputDecoration(labelText:'اسم الصنف بعد المراجعة'),onChanged:(v)=>_proposalNameEdits[id]=v),
          TextFormField(key:ValueKey('proposal-unit-$id'),initialValue:_proposalUnitEdits[id]??_s(proposal['unit_name']),decoration:const InputDecoration(labelText:'وحدة القياس'),onChanged:(v)=>_proposalUnitEdits[id]=v),
          DropdownButtonFormField<String>(
            value:_categories.any((c)=>_s(c['id'])==categoryValue)?categoryValue:null,
            decoration:const InputDecoration(labelText:'الفئة المركزية'),
            items:[const DropdownMenuItem<String>(value:null,child:Text('بدون فئة')), ..._categories.where((c)=>c['is_active']==true).map((c)=>DropdownMenuItem(value:_s(c['id']),child:Text('${_s(c['category_code'])} — ${_s(c['category_name'])}')))],
            onChanged:(v)=>setState(()=>_proposalCategorySelections[id]=v),
          ),
          if(_s(proposal['description']).isNotEmpty)Text(_s(proposal['description']),style:const TextStyle(color:Colors.black54)),
          const SizedBox(height:8),
          Wrap(spacing:8,children:[
            FilledButton.icon(onPressed:_saving?null:()=>_reviewWorkspaceItemProposal(proposal,'approve'),icon:const Icon(Icons.check_circle),label:const Text('اعتماد وإضافة')),
            OutlinedButton.icon(onPressed:_saving?null:()=>_reviewWorkspaceItemProposal(proposal,'reject'),icon:const Icon(Icons.close),label:const Text('رفض')),
          ]),
        ])));
      }).toList())),
  ]);

  Future<void> _saveCurrentRecord() async {
    if (_view == 'proposals' || _view == 'shared_stock') {
      setState(() => _message = 'استخدم أدوات التبويب الحالي بدلاً من الحفظ العام.');
      return;
    }
    if (_view == 'warehouses') { await _createWarehouse(); }
    else if (_view == 'items') { await _createItem(); }
    else { setState(() => _message='لا توجد عملية حفظ عامة في تبويب الأصناف المقترحة.'); }
  }

  Future<void> _exportMasterExcel() async {
    if (_view == 'proposals' || _view == 'shared_stock') { setState(() => _message = 'لا يوجد تصدير عام لهذا التبويب حالياً.'); return; }
    final isWarehouses = _view == 'warehouses';
    List<Map<String, dynamic>> rows = isWarehouses ? _warehouses : <Map<String, dynamic>>[];
    final label = isWarehouses ? 'المخازن' : 'الأصناف';
    if (isWarehouses && rows.isEmpty) {
      setState(() => _message = 'لا توجد بيانات $label مطابقة للتصدير.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      if (!isWarehouses) {
        var offset = 0;
        while (true) {
          final batch = await _repo.fetchItems(_company.text.trim(), offset: offset, pageSize: 500, search: _itemSearch.text);
          rows.addAll(batch);
          offset += batch.length;
          if (batch.length < 500) break;
          if (rows.length >= 50000) throw StateError('تجاوز التصدير 50,000 صنف. استخدم تصديرًا مجزأً لتجنب استهلاك الذاكرة.');
        }
      }
      if (rows.isEmpty) throw StateError('لا توجد سجلات مطابقة للتصدير.');
      if (!isWarehouses) {
        final units = await _repo.fetchItemUnits(
          _company.text.trim(), rows.map((r) => _s(r['id'])).toList(),
        );
        final byItem = <String, Map<int, Map<String, dynamic>>>{};
        for (final unit in units) {
          final level = int.tryParse(_s(unit['unit_level']));
          if (level == null) continue;
          byItem.putIfAbsent(_s(unit['item_id']), () => {})[level] = unit;
        }
        for (final item in rows) {
          final levels = byItem[_s(item['id'])] ?? {};
          final major = levels[1];
          final middle = levels[2];
          final minor = levels[3];
          item['major_unit'] = major?['unit_name'] ?? item['base_unit'];
          item['major_inner_quantity'] = major?['inner_quantity'] ?? '';
          item['middle_unit'] = middle?['is_implicit'] == true ? '' : (middle?['unit_name'] ?? '');
          item['middle_inner_quantity'] = middle?['is_implicit'] == true ? '' : (middle?['inner_quantity'] ?? '');
          item['minor_unit'] = minor?['unit_name'] ?? item['base_unit'];
        }
      }
      final workbook = Excel.createExcel();
      final sheet = workbook[isWarehouses ? 'المخازن' : 'الأصناف'];
      final keys = isWarehouses
        ? <String>['warehouse_code','warehouse_name','warehouse_name_en','branch_name','location','phone','address','is_active']
        : <String>['item_code','item_name','item_name_en','barcode','major_unit','major_inner_quantity','middle_unit','middle_inner_quantity','minor_unit','category_name','purchase_price','sale_price','tax_rate','reorder_level','is_active'];
      final headers = isWarehouses
        ? <String>['كود المخزن','اسم المخزن','الاسم الإنجليزي','الفرع','الموقع','الهاتف','العنوان','الحالة']
        : <String>['كود الصنف','اسم الصنف','الاسم الإنجليزي','الباركود','الوحدة الكبرى','عدد الوسطى داخل الكبرى','الوحدة الوسطى','عدد الصغرى داخل الوسطى','الوحدة الصغرى','فئة الصنف','سعر الشراء','سعر البيع','الضريبة %','حد إعادة الطلب','الحالة'];
      sheet.appendRow(headers.map((value) => TextCellValue(value)).toList());
      for (final row in rows) {
        sheet.appendRow([
          for (final key in keys)
            TextCellValue(key == 'is_active'
              ? (row[key] == true ? 'نشط' : 'موقوف')
              : key == 'category_name'
                  ? _categoryLabel(_s(row['category_id']))
                  : _s(row[key])),
        ]);
      }
      final bytes = workbook.encode();
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'silsila_${isWarehouses ? 'warehouses' : 'items'}_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) setState(() => _message = 'تم تصدير ${rows.length} سجلًا من $label إلى Excel.');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تصدير $label إلى Excel: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<Map<String,dynamic>?> _chooseMasterRecord(String action) async {
    final isWarehouse=_view=='warehouses';
    final rows=isWarehouse?_warehouses:_items;
    if(rows.isEmpty)return null;
    return showDialog<Map<String,dynamic>>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(action=='edit'?'اختر السجل المراد تعديله':isWarehouse?'اختر المخزن المراد حذفه':'اختر الصنف المراد إيقافه'),
        content:SizedBox(
          width:620,
          height:460,
          child:ListView.separated(
            itemCount:rows.length,
            separatorBuilder:(_,__)=>const Divider(height:1),
            itemBuilder:(ctx,index){
              final row=rows[index];
              return ListTile(
                dense:true,
                title:Text(isWarehouse
                  ? _s(row['warehouse_code'])+' — '+_s(row['warehouse_name'])
                  : _s(row['item_code'])+' — '+_s(row['item_name'])),
                subtitle:Text(row['is_active']==true?'نشط':'موقوف'),
                onTap:()=>Navigator.pop(ctx,Map<String,dynamic>.from(row)),
              );
            },
          ),
        ),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء'))],
      ),
    );
  }

  Future<void> _editFirstRecord() async {
    if(_view=='proposals'||_view=='shared_stock'){setState(()=>_message='لا يمكن تعديل سجل أصناف من تبويب التقارير أو المقترحات.');return;}
    final isWarehouse=_view=='warehouses';
    final row=await _chooseMasterRecord('edit');
    if(row==null)return;
    final code=TextEditingController(text:_s(row[isWarehouse?'warehouse_code':'item_code']));
    final name=TextEditingController(text:_s(row[isWarehouse?'warehouse_name':'item_name']));
    final barcode=TextEditingController(text:_s(row['barcode']));
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(isWarehouse?'تعديل بيانات المخزن':'تعديل بيانات الصنف'),
      content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:code,decoration:const InputDecoration(labelText:'الكود')),
        TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم بالعربية')),
        if(!isWarehouse)TextField(controller:barcode,decoration:const InputDecoration(labelText:'الباركود')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ التعديل'))],
    ));
    try{
      if(yes==true&&code.text.trim().isNotEmpty&&name.text.trim().isNotEmpty){
        if(isWarehouse){
          await Supabase.instance.client.from('erp_warehouses').update({'warehouse_code':code.text.trim().toUpperCase(),'warehouse_name':name.text.trim()}).eq('id',row['id']).eq('company_id',_company.text.trim());
        }else{
          await Supabase.instance.client.from('erp_items').update({'item_code':code.text.trim().toUpperCase(),'item_name':name.text.trim(),'barcode':barcode.text.trim()}).eq('id',row['id']).eq('company_id',_company.text.trim());
        }
        await _load(clearMessage:false);
        if(mounted)setState(()=>_message='تم تعديل السجل المحدد.');
      }
    }catch(e){if(mounted)setState(()=>_error='تعذر تعديل السجل: $e');}
    finally{code.dispose();name.dispose();barcode.dispose();}
  }
  Future<void> _deleteFirstRecord() async {
    if(_view=='proposals'||_view=='shared_stock'){setState(()=>_message='لا يمكن حذف سجل من تبويب التقارير أو المقترحات.');return;}
    final selected=await _chooseMasterRecord('delete');
    if(selected==null)return;
    if(_view=='warehouses'){
      await _deleteWarehouse(selected);
      return;
    }
    final item=selected;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('تأكيد إيقاف الصنف'),
      content:Text('إيقاف الصنف «${_s(item['item_name'])}»؟ سيظل محفوظاً إذا كان مرتبطاً بحركات أو مستندات.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('نعم، إيقاف'))],
    ));
    if(yes==true)await _toggle(item,true);
  }


  Future<void> _exportMasterPdf({required bool share}) async {
    if(_view=='proposals'||_view=='shared_stock'){setState(()=>_message='لا يوجد تصدير PDF عام لهذا التبويب حالياً.');return;}
    final isWarehouse=_view=='warehouses';
    final rows=isWarehouse?_warehouses:_items;
    if(rows.isEmpty){setState(()=>_message='لا توجد بيانات للتصدير.');return;}
    try{
      final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      final doc=pw.Document();
      final headers=isWarehouse?const ['م','كود المخزن','اسم المخزن','العنوان','الحالة']:const ['م','كود الصنف','اسم الصنف','الوحدة','سعر الشراء','سعر البيع','الضريبة'];
      final data=rows.asMap().entries.map((e){
        final r=e.value;
        if(isWarehouse)return [e.key+1,_s(r['warehouse_code']),_s(r['warehouse_name']),_s(r['address']),r['is_active']==true?'نشط':'موقوف'];
        return [e.key+1,_s(r['item_code']),_s(r['item_name']),_s(r['base_unit']),_money(r['purchase_price']),_money(r['sale_price']),_money(r['tax_rate'])+'%'];
      }).toList();
      doc.addPage(pw.MultiPage(theme:pw.ThemeData.withFont(base:font,bold:font),build:(_)=>[
        pw.Text(isWarehouse?'بيانات المخازن':'بيانات الأصناف',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:10),
        pw.TableHelper.fromTextArray(headers:headers,data:data),
      ]));
      final bytes=await doc.save();
      if(share){await Printing.sharePdf(bytes:bytes,filename:isWarehouse?'Silsila-Warehouses.pdf':'Silsila-Items.pdf');}
      else{await Printing.layoutPdf(onLayout:(_)=>Future.value(bytes));}
    }catch(e){if(mounted)setState(()=>_error='تعذر إنشاء ملف PDF: $e');}
  }

  Future<void> _previewMasterData() async {
    if(_view=='proposals'||_view=='shared_stock'){setState(()=>_message='استخدم محتوى التبويب الحالي للمعاينة.');return;}
    final rows = _view == 'warehouses' ? _warehouses : _items;
    final label = _view == 'warehouses' ? 'المخازن' : 'الأصناف';
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('معاينة $label'),
      content: SizedBox(width: 740, child: rows.isEmpty ? Text('لا توجد بيانات في $label.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: rows.take(100).map((r) => ListTile(
          dense: true,
          title: Text(_view == 'warehouses' ? '${_s(r['warehouse_code'])} — ${_s(r['warehouse_name'])}' : '${_s(r['item_code'])} — ${_s(r['item_name'])}'),
          subtitle: Text(r['is_active'] == true ? 'نشط' : 'موقوف'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => ErpKeyboardActionRegistrar(add: _newCurrentRecord, save: _saveCurrentRecord, child: Directionality(textDirection: TextDirection.rtl, child: ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Card(color: const Color(0xFF3E007D), child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_view == 'warehouses' ? 'بيانات المخازن' : _view == 'proposals' ? 'مراجعة الأصناف المقترحة' : _view == 'shared_stock' ? 'أرصدة الأنشطة المشتركة' : 'بيانات الأصناف', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const Text('تعريف المخازن والأصناف الأساسية قبل تسجيل الحركات.', style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _saving ? null : _newCurrentRecord),
            _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _saving || _loading ? null : _saveCurrentRecord),
            _quickTask('تعديل', Icons.edit_outlined, const Color(0xFFFFA015), _saving || _loading ? null : _editFirstRecord),
            _quickTask('حذف', Icons.delete_outline, const Color(0xFFB42318), _saving || _loading ? null : _deleteFirstRecord),
            _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewMasterData),
            _quickTask('طباعة', Icons.print_outlined, const Color(0xFF4056A1), () => _exportMasterPdf(share: false)),
            _quickTask('Excel', Icons.file_download_outlined, const Color(0xFF137C8B), _loading ? null : _exportMasterExcel),
            _quickTask('PDF', Icons.picture_as_pdf_outlined, const Color(0xFFB3261E), () => _exportMasterPdf(share: true)),
          ])),
        ]),
      )),
      const SizedBox(height: 10),
      if (_company.text.trim().isNotEmpty)
        const Padding(
          padding: EdgeInsetsDirectional.only(bottom: 8),
          child: Text('يتم عرض بيانات الشركة النشطة المرتبطة بحسابك تلقائيًا.'),
        ),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: [
          const ButtonSegment(value: 'warehouses', label: Text('المخازن'), icon: Icon(Icons.warehouse_outlined)),
          const ButtonSegment(value: 'items', label: Text('الأصناف'), icon: Icon(Icons.inventory_2_outlined)),
          if (_isManagementUser) const ButtonSegment(value: 'proposals', label: Text('أصناف مقترحة'), icon: Icon(Icons.pending_actions_outlined)),
          if (_isManagementUser) const ButtonSegment(value: 'shared_stock', label: Text('أرصدة الأنشطة'), icon: Icon(Icons.share)),
        ],
        selected: {_view}, onSelectionChanged: (v) => setState(() => _view = v.first),
      ),
      const SizedBox(height: 10),
      if (_view == 'proposals') ...[
        SizedBox(height:650,child:_workspaceProposalsView()),
      ] else if (_view == 'shared_stock') ...[
        SizedBox(height:650,child:_sharedWorkspaceStockView()),
      ] else if (_view == 'warehouses') ...[
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_parentWarehouseId == null ? 'إضافة مخزن رئيسي' : 'إضافة مخزن فرعي', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const TextField(enabled: false, decoration: InputDecoration(labelText: 'كود المخزن', hintText: 'يُنشأ تلقائيًا عند الحفظ', prefixIcon: Icon(Icons.auto_awesome))),
            TextField(controller: _warehouseName, decoration: const InputDecoration(labelText: 'اسم المخزن عربي *')),
            TextField(controller: _warehouseNameEn, decoration: const InputDecoration(labelText: 'اسم المخزن إنجليزي')),
            TextField(controller: _warehouseLocation, decoration: const InputDecoration(labelText: 'الموقع / وصف المكان')),
            TextField(controller: _warehousePhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الموبايل')),
            TextField(controller: _warehouseLandline, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'التليفون الأرضي')),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _parentWarehouseId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'المخزن الرئيسي (اتركه فارغًا للمخزن الرئيسي)'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('مخزن رئيسي')), ..._warehouses.where((w) => _s(w['id']) != _parentWarehouseId).map((w) => DropdownMenuItem<String>(value: _s(w['id']), child: Text(_s(w['warehouse_code']) + ' — ' + _s(w['warehouse_name']))))],
              onChanged: (v) => setState(() => _parentWarehouseId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _branchId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الفرع (اختياري)'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('بدون فرع')), ..._branches.map((b) => DropdownMenuItem<String>(value: _s(b['id']), child: Text(_branchName(_s(b['id'])))))],
              onChanged: (v) => setState(() => _branchId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _governorateId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'المحافظة'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('اختر المحافظة')), ..._geoRows.where((g) => g['level'] == 'governorate').map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))],
              onChanged: (v) => setState(() { _governorateId = v; _districtId = null; _areaId = null; }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _districtId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الحي / المركز'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('اختر الحي أو المركز')), ..._geoRows.where((g) => g['level'] == 'district' && _s(g['parent_id']) == (_governorateId ?? '')).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))],
              onChanged: (v) => setState(() { _districtId = v; _areaId = null; }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _areaId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'المنطقة / القرية'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('اختر المنطقة أو القرية')), ..._geoRows.where((g) => g['level'] == 'area' && _s(g['parent_id']) == (_districtId ?? '')).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))],
              onChanged: (v) => setState(() => _areaId = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _createWarehouse, icon: const Icon(Icons.add_business), label: const Text('حفظ المخزن')),
          ],
        ))),
        Text('الفروع المسجلة • ' + _branches.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        if (_branches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('لا توجد فروع نشطة مسجلة لهذه الشركة حتى الآن.'),
          )
        else
          ..._branches.map((b) => Card(
            child: ListTile(
              leading: const Icon(Icons.store_mall_directory_outlined, color: Color(0xFF3E007D)),
              title: Text(_s(b['branch_code']) + ' — ' + _s(b['branch_name'])),
              subtitle: const Text('فرع نشط'),
            ),
          )),
        const SizedBox(height: 12),
        Text('المخازن المسجلة • ' + _warehouses.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        if (_warehouses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('لا توجد مخازن مسجلة لهذه الشركة حتى الآن. يمكنك إضافة مخزن من النموذج أعلاه، أو الضغط على «تحديث» لإعادة التحميل.'),
          )
        else
          ..._warehouses.map((w) => Card(child: ListTile(
          leading: const Icon(Icons.warehouse_outlined, color: Color(0xFF3E007D)),
          title: Text((_s(w['parent_warehouse_id']).isEmpty ? '' : '↳ ') + _s(w['warehouse_code']) + ' — ' + _s(w['warehouse_name'])),
          subtitle: Text(_branchName(_s(w['branch_id'])) + (_s(w['address']).isEmpty ? '' : '\n' + _s(w['address'])) + (_s(w['parent_warehouse_id']).isEmpty ? '' : '\nمخزن فرعي تابع لـ ' + _warehouseParentName(_s(w['parent_warehouse_id'])))),
          isThreeLine: true,
          trailing: Wrap(spacing: 0, children: [
            IconButton(tooltip: 'إضافة مخزن فرعي', onPressed: _saving ? null : () => setState(() { _parentWarehouseId = _s(w['id']); _message = 'سيتم ربط المخزن الجديد بالمخزن: ' + _s(w['warehouse_name']); }), icon: const Icon(Icons.account_tree_outlined, color: Color(0xFF3E007D))),
            IconButton(tooltip: 'حذف المخزن', onPressed: _saving ? null : () => _deleteWarehouse(w), icon: const Icon(Icons.delete_forever, color: Colors.red)),
            IconButton(onPressed: _saving ? null : () => _toggle(w, false), icon: Icon(w['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
          ]),
        ))),
      ] else ...[
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إضافة صنف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const TextField(enabled: false, decoration: InputDecoration(labelText: 'كود الصنف', hintText: 'يُنشأ تلقائيًا بعد الحفظ', prefixIcon: Icon(Icons.auto_awesome))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _itemCategoryId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الفئة الثانوية للصنف *', helperText: 'اختر الفئة الثانوية المرتبطة بفئة رئيسية وفرعية لإكمال الكود التلقائي'),
              items: _categories.where((g) => g['is_active'] == true && _isSecondaryCategory(g)).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['category_code']) + ' — ' + _s(g['category_name']), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _itemCategoryId = v),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x223E007D)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('وحدات قياس الصنف', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E007D))),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, constraints) {
                  final width = (constraints.maxWidth - 32) / 5;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    SizedBox(width: width, child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'الوحدة الكبرى', border: OutlineInputBorder(), isDense: true))),
                    SizedBox(width: width, child: TextField(controller: _majorInner, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'عددها الداخلي', helperText: 'وحدة وسطى/صغرى', border: OutlineInputBorder(), isDense: true))),
                    SizedBox(width: width, child: TextField(controller: _middleUnit, decoration: const InputDecoration(labelText: 'الوحدة الوسطى', border: OutlineInputBorder(), isDense: true))),
                    SizedBox(width: width, child: TextField(controller: _middleInner, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'عددها الداخلي', helperText: 'وحدة صغرى', border: OutlineInputBorder(), isDense: true))),
                    SizedBox(width: width, child: TextField(controller: _minorUnit, decoration: const InputDecoration(labelText: 'الوحدة الصغرى', border: OutlineInputBorder(), isDense: true))),
                  ]);
                }),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _purchasePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => RegExp(r'^\d*\.?\d{0,3}$').hasMatch(newValue.text) ? newValue : oldValue)], decoration: const InputDecoration(labelText: 'سعر الشراء'))),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: _salePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => RegExp(r'^\d*\.?\d{0,3}$').hasMatch(newValue.text) ? newValue : oldValue)], decoration: const InputDecoration(labelText: 'سعر البيع'))),
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
        TextField(controller: _itemSearch, textInputAction: TextInputAction.search, onSubmitted: (_) => _searchItems(), decoration: InputDecoration(labelText: 'بحث باسم الصنف أو الكود أو الباركود', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _searchItems, icon: const Icon(Icons.search)), border: const OutlineInputBorder())),
        const SizedBox(height: 8),
        Text('الأصناف المحمّلة • ' + _items.length.toString() + (_itemsHasMore ? ' • توجد نتائج إضافية' : ''), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        SizedBox(height: 600, child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final i = _items[index];
            final id = _s(i['id']);
            final imageFuture = _itemImageFutures.putIfAbsent(id, () => _repo.fetchItemImage(_company.text.trim(), id));
            return Card(child: ExpansionTile(
              leading: FutureBuilder<Uint8List?>(
                future: imageFuture,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) return const Icon(Icons.inventory_2_outlined, color: Color(0xFF3E007D));
                  return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: Color(0xFF3E007D))));
                },
              ),
              title: Text(_s(i['item_code']) + ' — ' + _s(i['item_name'])),
              subtitle: Text(_categoryLabel(_s(i['category_id'])) + '\nالوحدة: ' + _s(i['base_unit']) + ' • شراء: ' + _money(i['purchase_price']) + ' • بيع: ' + _money(i['sale_price']) + ' • ضريبة: ' + _money(i['tax_rate']) + '%\nحد الطلب: ' + _s(i['reorder_level']) + (_s(i['barcode']).isEmpty ? '' : ' • باركود: ' + _s(i['barcode']))),
              trailing: Wrap(spacing: 0, children: [
                IconButton(tooltip: i['is_active'] == true ? 'إيقاف الصنف' : 'تنشيط الصنف', onPressed: _saving ? null : () => _toggle(i, true), icon: Icon(i['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
              ]),
              children: [_warehouseSettingsPanel(i)],
            ));
          },
        )),
        if (_itemsHasMore || _itemsLoadingMore) Center(child: Padding(padding: const EdgeInsets.all(12), child: OutlinedButton.icon(onPressed: _itemsLoadingMore ? null : _loadMoreItems, icon: _itemsLoadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more), label: Text(_itemsLoadingMore ? 'جارٍ تحميل المزيد...' : 'تحميل 500 صنف إضافي')))),
      ],
    ],
  )));


  List<Map<String, dynamic>> _unitsForItem(String itemId) {
    final candidates = _itemUnits.where((u) =>
      _s(u['item_id']) == itemId && u['is_active'] == true && u['is_selectable'] == true && u['is_implicit'] != true
    ).toList()
      ..sort((a, b) => _n(b['conversion_factor']).compareTo(_n(a['conversion_factor'])));
    final seenNames = <String>{};
    return candidates.where((unit) {
      final name = _s(unit['unit_name']).trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      return name.isNotEmpty && seenNames.add(name);
    }).toList();
  }
  Map<String, dynamic>? _settingsFor(String itemId, String warehouseId) {
    for (final row in _warehouseItemSettings) {
      if (_s(row['item_id']) == itemId && _s(row['warehouse_id']) == warehouseId) return row;
    }
    return null;
  }
  Future<void> _saveWarehouseUnitSetting(String itemId, String warehouseId, Map<String, dynamic> values) async {
    setState(() { _saving = true; _error = null; });
    try {
      await _repo.saveItemWarehouseSettings(
        companyId: _company.text.trim(), itemId: itemId, warehouseId: warehouseId,
        purchaseUnitId: values['purchase_unit_id'] as String?, saleUnitId: values['sale_unit_id'] as String?,
        transferUnitId: values['transfer_unit_id'] as String?, stocktakeUnitId: values['stocktake_unit_id'] as String?, stopPurchase: values['stop_purchase'] == true,
        stopSale: values['stop_sale'] == true, stopTransfer: values['stop_transfer'] == true,
      );
      await _load(clearMessage: false);
      if (mounted) setState(() { _saving = false; _message = 'تم حفظ وحدات الصنف وإيقافاته للمخزن المحدد.'; });
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ إعدادات وحدات المخزن: $e'; });
    }
  }
  Widget _warehouseSettingsPanel(Map<String, dynamic> item) {
    final itemId = _s(item['id']);
    final units = _unitsForItem(itemId);
    if (_warehouses.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مخازن نشطة لتهيئة وحدات الصنف.'));
    if (units.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد وحدات قياس نشطة وقابلة للاختيار لهذا الصنف.'));
    final largest = units.reduce((a,b) => _n(a['conversion_factor']) >= _n(b['conversion_factor']) ? a : b);
    final rows = _warehouses.where((w) => w['is_active'] == true).map((warehouse) {
      final warehouseId = _s(warehouse['id']);
      final existing = _settingsFor(itemId, warehouseId) ?? <String,dynamic>{};
      String unitValue(String key) {
        final selected = _s(existing[key]);
        return units.any((u) => _s(u['id']) == selected) ? selected : _s(largest['id']);
      }
      return <String,dynamic>{
        'warehouse': warehouse,
        'warehouse_id': warehouseId,
        'purchase_unit_id': unitValue('purchase_unit_id'),
        'sale_unit_id': unitValue('sale_unit_id'),
        'transfer_unit_id': unitValue('transfer_unit_id'),
        'stocktake_unit_id': unitValue('stocktake_unit_id'),
        'stop_purchase': existing['stop_purchase'] == true,
        'stop_sale': existing['stop_sale'] == true,
        'stop_transfer': existing['stop_transfer'] == true,
      };
    }).toList();
    return StatefulBuilder(builder: (context, refresh) => Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x223E007D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('وحدات قياس الصنف حسب المخزن • ' + _s(item['item_name']), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E007D))),
        const SizedBox(height: 4),
        const Text('الوحدة الكبرى هي الافتراضية للشراء والبيع والتحويل والجرد، ويمكن تخصيص كل مخزن بصورة مستقلة.'),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFE9DDF5)),
          columns: const [
            DataColumn(label: Text('م')),
            DataColumn(label: Text('كود فرع')),
            DataColumn(label: Text('اسم فرع')),
            DataColumn(label: Text('كود مخزن')),
            DataColumn(label: Text('اسم مخزن')),
            DataColumn(label: Text('وحدة الشراء الافتراضية')),
            DataColumn(label: Text('وحدة البيع الافتراضية')),
            DataColumn(label: Text('وحدة التحويلات')),
            DataColumn(label: Text('وحدة الجرد')),
            DataColumn(label: Text('إيقاف شراء')),
            DataColumn(label: Text('إيقاف بيع')),
            DataColumn(label: Text('إيقاف تحويلات')),
            DataColumn(label: Text('حفظ')),
          ],
          rows: List.generate(rows.length, (index) {
            final row = rows[index];
            final warehouse = row['warehouse'] as Map<String,dynamic>;
            final branch = _branches.where((b) => _s(b['id']) == _s(warehouse['branch_id']));
            final branchRow = branch.isEmpty ? <String,dynamic>{} : branch.first;
            Widget unitPicker(String key) => SizedBox(width: 145, child: DropdownButton<String>(
              value: units.any((u) => _s(u['id']) == _s(row[key])) ? _s(row[key]) : _s(largest['id']),
              isExpanded: true,
              items: units.map((u) => DropdownMenuItem(value: _s(u['id']), child: Text(_s(u['unit_name']) + ' • ' + _s(u['conversion_factor']), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _saving ? null : (v) => refresh(() => row[key] = v ?? _s(largest['id'])),
            ));
            Widget stopPicker(String key) => Checkbox(
              value: row[key] == true,
              shape: const CircleBorder(),
              onChanged: _saving ? null : (v) => refresh(() => row[key] = v == true),
            );
            return DataRow(cells: [
              DataCell(Text((index + 1).toString())),
              DataCell(Text(_s(branchRow['branch_code']))),
              DataCell(Text(_s(branchRow['branch_name']))),
              DataCell(Text(_s(warehouse['warehouse_code']))),
              DataCell(Text(_s(warehouse['warehouse_name']))),
              DataCell(unitPicker('purchase_unit_id')),
              DataCell(unitPicker('sale_unit_id')),
              DataCell(unitPicker('transfer_unit_id')),
              DataCell(unitPicker('stocktake_unit_id')),
              DataCell(stopPicker('stop_purchase')),
              DataCell(stopPicker('stop_sale')),
              DataCell(stopPicker('stop_transfer')),
              DataCell(IconButton(
                tooltip: 'حفظ إعدادات هذا المخزن',
                onPressed: _saving ? null : () => _saveWarehouseUnitSetting(itemId, _s(warehouse['id']), row),
                icon: const Icon(Icons.save_outlined, color: Color(0xFF168447)),
              )),
            ]);
          }),
        )),
      ]),
    ));
  }
  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
