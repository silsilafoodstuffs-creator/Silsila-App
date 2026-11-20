
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_center_toast.dart';

const _brandPurple = Color(0xFF3E007D);
const _brandCanvas = Color(0xFFF7F5FA);
const _brandBorder = Color(0xFFE8E1EF);

class ErpBrandsTab extends StatefulWidget {
  const ErpBrandsTab({super.key, required this.companyId, this.showGroupsOnly = false});
  final String companyId;
  final bool showGroupsOnly;

  @override
  State<ErpBrandsTab> createState() => _ErpBrandsTabState();
}

class _ErpBrandsTabState extends State<ErpBrandsTab> {
  final _search = TextEditingController();
  String _selectedActivityCode = 'all';
  final ScrollController _treeHeaderController = ScrollController();
  final ScrollController _treeRowsController = ScrollController();
  bool _syncingTreeScroll = false;
  final Map<String, TextEditingController> _columnSearch = {
    'code': TextEditingController(), 'activity': TextEditingController(),
    'group': TextEditingController(), 'name': TextEditingController(), 'english': TextEditingController(),
  };
  List<Map<String,dynamic>> _rows = [];
  List<Map<String,dynamic>> _groups = [];
  List<Map<String,dynamic>> _activities = [];
  bool _showGroups = false;
  String? _selectedId;
  bool _loading = false;
  bool _saving = false;
  bool _gridEditing = false;
  String? _gridEditingOnlyId;
  String? _error;
  final Map<String, TextEditingController> _gridNameControllers = <String, TextEditingController>{};
  final Map<String, TextEditingController> _gridEnglishControllers = <String, TextEditingController>{};
  String _viewMode = 'tree';
  final Set<String> _expandedGroups = <String>{};

  SupabaseClient get _db => Supabase.instance.client;
  String _s(dynamic value) => (value ?? '').toString();

  @override
  void initState() {
    super.initState();
    _treeHeaderController.addListener(() => _syncTreeScroll(_treeHeaderController, _treeRowsController));
    _treeRowsController.addListener(() => _syncTreeScroll(_treeRowsController, _treeHeaderController));
    _showGroups = widget.showGroupsOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _syncTreeScroll(ScrollController source, ScrollController target) {
    if (_syncingTreeScroll || !source.hasClients || !target.hasClients) return;
    _syncingTreeScroll = true;
    final offset = source.position.pixels.clamp(target.position.minScrollExtent, target.position.maxScrollExtent).toDouble();
    if ((target.position.pixels - offset).abs() > 0.5) target.jumpTo(offset);
    _syncingTreeScroll = false;
  }

  @override
  void dispose() {
    _treeHeaderController.dispose();
    _treeRowsController.dispose();
    _search.dispose();
    for (final controller in _columnSearch.values) { controller.dispose(); }
    for (final controller in _gridNameControllers.values) { controller.dispose(); }
    for (final controller in _gridEnglishControllers.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (widget.companyId.trim().isEmpty) {
      setState(() => _error = 'لا توجد شركة نشطة لعرض البراندات.');
      return;
    }
    if (showLoading) setState(() { _loading = true; _error = null; });
    else if (mounted) setState(() => _error = null);
    try {
      final rows = await _db.from('erp_brands')
        .select('id,brand_code,brand_name,brand_name_en,brand_group,brand_group_id,display_order,show_in_app,is_active,is_system,logo_data,logo_mime_type,activity_code')
        .eq('company_id', widget.companyId.trim())
        .order('brand_code');
      final groups = await _db.from('erp_brand_groups').select('id,group_code,group_name,group_name_en,activity_code,is_active').eq('company_id', widget.companyId.trim()).order('group_code');
      // The activity directory is auxiliary metadata. A missing or restricted
      // activity_types table must never hide the brands/groups catalog.
      List<Map<String,dynamic>> activities = <Map<String,dynamic>>[];
      try {
        final activityRows = await _db.from('activity_types')
            .select('code,name')
            .eq('is_active', true)
            .order('sort_order')
            .order('code');
        activities = List<Map<String,dynamic>>.from(activityRows);
      } catch (_) {
        activities = const [
          {'code':'01','name':'مواد غذائية'},
          {'code':'02','name':'لوازم بناء'},
          {'code':'03','name':'ملابس واكسسوارات'},
          {'code':'04','name':'أجهزة وإلكترونيات'},
          {'code':'05','name':'سيارات ومعدات'},
          {'code':'06','name':'خدمات شحن ونقل'},
          {'code':'07','name':'أثاث وديكورات'},
        ];
      }
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _groups = List<Map<String,dynamic>>.from(groups);
        _rows = List<Map<String,dynamic>>.from(rows);
        _syncGridNameControllers();
        if (!_rows.any((row) => _s(row['id']) == _selectedId)) {
          _selectedId = _rows.isEmpty ? null : _s(_rows.first['id']);
        }
        _expandedGroups.addAll(_groupNames);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل البراندات/الماركات: $error'; });
    }
  }

  void _syncGridNameControllers() {
    final keep = _rows.map((r) => _s(r['id'])).toSet();
    for (final id in _gridNameControllers.keys.where((id) => !keep.contains(id)).toList()) { _gridNameControllers.remove(id)?.dispose(); }
    for (final id in _gridEnglishControllers.keys.where((id) => !keep.contains(id)).toList()) { _gridEnglishControllers.remove(id)?.dispose(); }
    for (final row in _rows) {
      final id = _s(row['id']);
      final ar = _gridNameControllers.putIfAbsent(id, () => TextEditingController());
      final en = _gridEnglishControllers.putIfAbsent(id, () => TextEditingController());
      if (!_gridEditing) { ar.text = _s(row['brand_name']); en.text = _s(row['brand_name_en']); }
    }
  }

  Future<void> _saveGridNames({String? onlyId}) async {
    if (_saving) return;
    final targetId = onlyId ?? _gridEditingOnlyId;
    final targets = _rows.where((row) {
      final id = _s(row['id']);
      if (row['is_system'] == true || (targetId != null && id != targetId)) return false;
      return _gridNameControllers[id]!.text.trim() != _s(row['brand_name']).trim() ||
          _gridEnglishControllers[id]!.text.trim() != _s(row['brand_name_en']).trim();
    }).toList();
    if (targets.isEmpty) {
      ErpCenterToast.show(context, 'لا توجد أسماء تم تعديلها.');
      return;
    }
    for (final row in targets) {
      if (_gridNameControllers[_s(row['id'])]!.text.trim().isEmpty) {
        ErpCenterToast.show(context, 'اسم البراند بالعربية لا يمكن أن يكون فارغًا.', isError: true);
        return;
      }
    }
    setState(() { _saving = true; _error = null; });
    try {
      final payload = targets.map((row) {
        final id = _s(row['id']);
        return <String,dynamic>{
          'id': id,
          'brand_name': _gridNameControllers[id]!.text.trim(),
          'brand_name_en': _gridEnglishControllers[id]!.text.trim(),
        };
      }).toList();
      await _db.rpc('erp_update_brand_names_batch', params: {
        'p_company_id': widget.companyId.trim(),
        'p_rows': payload,
      });
      if (!mounted) return;
      setState(() { _gridEditing = false; _gridEditingOnlyId = null; });
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, targets.length == 1
          ? 'تم حفظ اسم البراند بنجاح مع الاحتفاظ بكوده وربط أصنافه.'
          : 'تم حفظ أسماء البراندات المحددة دفعة واحدة مع الاحتفاظ بالأكواد والارتباطات.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, _friendlySaveError(error), isError: true);
      await _load(showLoading: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String,dynamic>> get _visibleRows {
    final term = _search.text.trim().toLowerCase();
    return _rows.where((row) {
      final activityCode = _s(row['activity_code']).isEmpty ? '01' : _s(row['activity_code']);
      final groupName = _groupKey(row);
      if (_selectedActivityCode != 'all' && activityCode != _selectedActivityCode) return false;
      if (term.isNotEmpty && ![_s(row['brand_code']), _s(row['brand_name']), _s(row['brand_name_en']), groupName].any((v) => v.toLowerCase().contains(term))) return false;
      final filters = <String, String>{'code': _s(row['brand_code']), 'activity': _activityName(activityCode), 'group': groupName, 'name': _s(row['brand_name'])};
      for (final entry in filters.entries) {
        final value = _columnSearch[entry.key]!.text.trim().toLowerCase();
        if (value.isNotEmpty && !entry.value.toLowerCase().contains(value)) return false;
      }
      return true;
    }).toList();
  }

  String _friendlySaveError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '23505') return 'اسم البراند العربي مستخدم بالفعل. اختر اسمًا مختلفًا.';
      if (code == '22023') return 'راجع أسماء البراندات؛ الاسم العربي مطلوب ولا يمكن تكراره داخل نفس الشركة.';
      if (code == 'P0002') return 'البراند المحدد غير متاح للتعديل أو أنه سجل محمي. لم يتم حفظ أي تغيير.';
      if (code == '23503') return 'تعذر الحفظ: يوجد ارتباط ببيانات أخرى غير متوافقة. لم يتم تغيير كود البراند أو ارتباطات الأصناف.';
      if (code == '42501' || code == 'PGRST301') return 'تعذر الحفظ: صلاحية تعديل البراند غير متاحة لهذا الحساب.';
      if (code == '23514' || code == '23502') return 'البيانات غير مكتملة أو لا تطابق قواعد التحقق. راجع اسم البراند.';
      if (code == 'PGRST116') return 'لم يتم العثور على سجل البراند المطلوب أو لا يمكن الوصول إليه.';
      return 'تعذر حفظ البراند بسبب مشكلة في قاعدة البيانات. لم يتم عرض تفاصيل تقنية أو أكواد للمستخدم.';
    }
    return 'تعذر حفظ البراند. حاول مرة أخرى.';
  }
  Future<void> _edit({Map<String,dynamic>? row}) async {
    if (row?['is_system'] == true) {
      ErpCenterToast.show(context, 'السجل الافتراضي «بدون علامة تجارية» محمي من التعديل.', isError: true);
      return;
    }
    final name = TextEditingController(text: _s(row?['brand_name']));
    var activityCode = _s(row?['activity_code']).isEmpty ? '01' : _s(row?['activity_code']);
    var groupId = _s(row?['brand_group_id']).isEmpty ? null : _s(row?['brand_group_id']);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(row == null ? 'إضافة براند/ماركة' : 'تعديل البراند/الماركة'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم البراند/الماركة بالعربية *'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم البراند.' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: activityCode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوع النشاط المرتبط بالبراند *'),
                    items: _activities.map((activity) => DropdownMenuItem<String>(
                      value: _s(activity['code']),
                      child: Text('${_s(activity['name'])} — ${_s(activity['code'])}'),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() {
                        activityCode = value;
                        if (!_groupsForActivity(value).any((group) => _s(group['id']) == groupId)) groupId = null;
                      });
                    },
                    validator: (value) => value == null || value.isEmpty ? 'اختر نوع النشاط.' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _groupsForActivity(activityCode).any((group) => _s(group['id']) == groupId) ? groupId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'مجموعة البراند'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('بدون مجموعة')),
                      ..._groupsForActivity(activityCode).map((group) => DropdownMenuItem<String?>(
                        value: _s(group['id']),
                        child: Text('${_s(group['group_code'])} — ${_s(group['group_name'])}', overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (value) => setDialogState(() => groupId = value),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () {
                if (formKey.currentState?.validate() == true) Navigator.pop(dialogContext, true);
              }, child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (result != true) {
      name.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String,dynamic>{
        'brand_name': name.text.trim(),
        if (row == null || activityCode != _s(row['activity_code'])) 'activity_code': activityCode,
        'brand_group_id': groupId,
        'brand_group': _groupById(groupId)?['group_name'],
      };
      if (row == null) {
        final inserted = await _db.from('erp_brands')
          .insert({'company_id': widget.companyId.trim(), ...payload})
          .select('id,brand_code,brand_name,brand_name_en,is_active,is_system')
          .single();
        if (mounted) _selectedId = _s(inserted['id']);
      } else {
        await _db.rpc('erp_update_brand_names_batch', params: {
          'p_company_id': widget.companyId.trim(),
          'p_rows': [{
            'id': _s(row['id']),
            'brand_name': name.text.trim(),
            'brand_name_en': _s(row['brand_name_en']),
            'activity_code': activityCode,
          }],
        });
        await _db.from('erp_brands').update({
          'brand_group_id': groupId,
          'brand_group': _groupById(groupId)?['group_name'],
        }).eq('id', _s(row['id'])).eq('company_id', widget.companyId.trim());
      }
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, row == null ? 'تمت إضافة البراند وتوليد كوده.' : 'تم تعديل بيانات البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, _friendlySaveError(error), isError: true);
    } finally {
      name.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Uint8List? _logoBytes(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final hex = raw.startsWith(r'\x') ? raw.substring(2) : raw;
    if (hex.isEmpty || hex.length.isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ));
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadLogo([Map<String,dynamic>? target]) async {
    final row = target ?? _selectedRow();
    if (row == null) {
      ErpCenterToast.show(context, 'اختر براندًا أولًا.', isError: true);
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ErpCenterToast.show(context, 'تعذر قراءة ملف الشعار.', isError: true);
      return;
    }
    if (bytes.length > 256 * 1024) {
      ErpCenterToast.show(context, 'الحد الأقصى لحجم شعار البراند 256 كيلوبايت.', isError: true);
      return;
    }
    final ext = file.extension?.toLowerCase() ?? '';
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => '',
    };
    if (mime.isEmpty) {
      ErpCenterToast.show(context, 'الصيغ المدعومة للشعار JPG وPNG وWEBP وGIF.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final hex = r'\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _db.from('erp_brands').update({
        'logo_data': hex,
        'logo_mime_type': mime,
      }).eq('id', _s(row['id'])).eq('company_id', widget.companyId.trim()).select('id').single();

      // Keep the current Brands tab alive after each upload. Refresh only the
      // affected in-memory row instead of reloading the entire tab/screen.
      if (!mounted) return;
      setState(() {
        final id = _s(row['id']);
        final index = _rows.indexWhere((item) => _s(item['id']) == id);
        if (index >= 0) {
          _rows[index] = {
            ..._rows[index],
            'logo_data': hex,
            'logo_mime_type': mime,
          };
        }
        _selectedId = id;
      });
      ErpCenterToast.show(context, 'تم حفظ شعار البراند بنجاح. يمكنك اختيار براند آخر وتحميل صورته دون مغادرة الشاشة.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حفظ شعار البراند: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  Future<void> _uploadLogoFromCamera(Map<String,dynamic> row) async {
    if (row['is_system'] == true || _saving) return;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = switch (ext) { 'jpg' || 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp', 'gif' => 'image/gif', _ => '' };
      if (bytes.isEmpty || bytes.length > 256 * 1024 || mime.isEmpty) {
        ErpCenterToast.show(context, bytes.length > 256 * 1024 ? 'الحد الأقصى لحجم الشعار 256 كيلوبايت.' : 'صيغة الصورة غير مدعومة أو تعذر قراءتها.', isError: true);
        return;
      }
      setState(() => _saving = true);
      try {
        final hex = r'\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await _db.from('erp_brands').update({'logo_data': hex, 'logo_mime_type': mime})
          .eq('id', _s(row['id'])).eq('company_id', widget.companyId.trim()).select('id').single();
        if (!mounted) return;
        setState(() {
          final i = _rows.indexWhere((item) => _s(item['id']) == _s(row['id']));
          if (i >= 0) _rows[i] = {..._rows[i], 'logo_data': hex, 'logo_mime_type': mime};
        });
        ErpCenterToast.show(context, 'تم حفظ شعار البراند.');
      } finally { if (mounted) setState(() => _saving = false); }
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر التقاط صورة الشعار: $error', isError: true);
    }
  }

  Future<void> _showLogoDialog(Map<String,dynamic> row) async {
    await showDialog<void>(context: context, builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(builder: (context, setDialogState) {
        final i = _rows.indexWhere((item) => _s(item['id']) == _s(row['id']));
        final current = i >= 0 ? _rows[i] : row;
        final hasLogo = _logoBytes(current['logo_data'])?.isNotEmpty == true;
        final locked = current['is_system'] == true;
        return AlertDialog(
          title: Text('شعار ${_s(current['brand_name'])}'),
          content: SizedBox(width: 230, child: Column(mainAxisSize: MainAxisSize.min, children: [
            _logoPreview(current, size: 50),
            const SizedBox(height: 8),
            Text(_s(current['brand_name']), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: _brandPurple)),
          ])),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton.icon(onPressed: locked || _saving ? null : () async { await _uploadLogo(current); if (mounted) setDialogState(() {}); },
              icon: const Icon(Icons.folder_open_outlined), label: const Text('من الجهاز')),
            TextButton.icon(onPressed: locked || _saving ? null : () async { await _uploadLogoFromCamera(current); if (mounted) setDialogState(() {}); },
              icon: const Icon(Icons.photo_camera_outlined), label: const Text('الكاميرا')),
            TextButton.icon(onPressed: locked || !hasLogo || _saving ? null : () async { await _removeLogo(current); if (mounted) setDialogState(() {}); },
              icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('حذف الصورة', style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          ],
        );
      }),
    ));
  }

  Future<void> _bulkImportLogos() async {
    if (widget.companyId.trim().isEmpty || _saving) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: true, withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final files = picked.files.where((file) =>
      file.bytes != null && file.bytes!.isNotEmpty &&
      const {'jpg','jpeg','png','webp','gif'}.contains(file.extension?.toLowerCase())
    ).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (files.isEmpty) {
      if (mounted) ErpCenterToast.show(context, 'لم يتم اختيار صور مدعومة.', isError: true);
      return;
    }
    final oversized = files.where((file) => file.bytes!.length > 256 * 1024).length;
    if (oversized > 0) {
      if (mounted) ErpCenterToast.show(context, 'تم إيقاف الاستيراد: يوجد $oversized ملف يتجاوز 256 كيلوبايت.', isError: true);
      return;
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    setState(() { _saving = true; _error = null; });
    var imported = 0;
    try {
      for (var start = 0; start < files.length; start += 10) {
        final end = (start + 10 < files.length) ? start + 10 : files.length;
        final batch = <Map<String,dynamic>>[];
        for (var index = start; index < end; index++) {
          final file = files[index];
          final sequence = (index + 1).toString().padLeft(3, '0');
          final ext = file.extension!.toLowerCase();
          final mime = switch (ext) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            'gif' => 'image/gif',
            _ => '',
          };
          final bytes = file.bytes!;
          final hex = r'\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          batch.add({
            'company_id': widget.companyId.trim(),
            'brand_name': 'مراجعة شعار $sequence - $stamp',
            'brand_name_en': 'Review Logo $sequence - $stamp',
            'brand_group': 'شعارات مستوردة للمراجعة',
            'logo_data': hex,
            'logo_mime_type': mime,
            'display_order': 2000 + index,
          });
        }
        await _db.from('erp_brands').insert(batch);
        imported += batch.length;
      }
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم استيراد $imported شعارًا كسجلات مستقلة بأكواد تلقائية.');
    } catch (error) {
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم استيراد $imported من أصل ${files.length} صورة قبل حدوث خطأ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(Map<String,dynamic> row) async {
    if (row['is_system'] == true) return;
    try {
      await _db.from('erp_brands').update({'is_active':row['is_active'] != true})
        .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim())
        .select('id').single();
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم تحديث حالة البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر تحديث حالة البراند: $error', isError: true);
    }
  }

  Map<String,dynamic>? _selectedRow() {
    final matches = _rows.where((item) => _s(item['id']) == _selectedId);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _delete() async {
    final row = _selectedRow();
    if (row == null) {
      ErpCenterToast.show(context, 'اختر براندًا أولًا.', isError: true);
      return;
    }
    if (row['is_system'] == true) {
      ErpCenterToast.show(context, 'لا يمكن حذف سجل «بدون علامة تجارية».', isError: true);
      return;
    }
    final deleted = await _db.from('erp_brands').delete()
      .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim())
      .select('id');
    if (deleted.isEmpty) throw StateError('لم يتم حذف البراند المحدد.');
    await _load(showLoading: false);
  }



  String _activityName(String code) {
    for (final activity in _activities) {
      if (_s(activity['code']) == code) return _s(activity['name']);
    }
    return code;
  }

  String? get _defaultGroupId {
    for (final group in _groups) {
      if (_s(group['group_code']) == 'Brg01') return _s(group['id']);
    }
    return null;
  }

  Map<String,dynamic>? _groupById(String? id) {
    for (final group in _groups) { if (_s(group['id']) == (id ?? '')) return group; }
    return null;
  }

  List<Map<String,dynamic>> _groupsForActivity(String code) => _groups.where((g) => _s(g['activity_code']) == code).toList();

  String _groupKey(Map<String,dynamic> row) {
    final id = _s(row['brand_group_id']);
    final matches = _groups.where((g) => _s(g['id']) == id);
    if (matches.isNotEmpty) return _s(matches.first['group_name']);
    final legacy = _s(row['brand_group']).trim();
    return legacy.isEmpty ? 'بدون مجموعة' : legacy;
  }

  Future<void> _addGroup() async {
    final name = TextEditingController();
    var activityCode = _selectedActivityCode == 'all' ? (_activities.isEmpty ? '01' : _s(_activities.first['code'])) : _selectedActivityCode;
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(title: const Text('إضافة مجموعة براندات'),
        content: SizedBox(width: 420, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المجموعة عربي *'),
            validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم المجموعة.' : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: activityCode, isExpanded: true,
            decoration: const InputDecoration(labelText: 'النشاط التابع له المجموعة *'),
            items: _activities.map((activity) => DropdownMenuItem<String>(
              value: _s(activity['code']), child: Text('${_s(activity['name'])} — ${_s(activity['code'])}'),
            )).toList(),
            onChanged: (value) { if (value != null) activityCode = value; },
            validator: (value) => value == null || value.isEmpty ? 'اختر النشاط.' : null,
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (formKey.currentState?.validate() == true) Navigator.pop(ctx, true); }, child: const Text('حفظ')),
        ])));
    if (ok != true) { name.dispose(); return; }
    setState(() => _saving = true);
    try {
      final inserted = await _db.from('erp_brand_groups').insert({
        'company_id': widget.companyId.trim(), 'group_name': name.text.trim(),
        'activity_code': activityCode,
      }).select('id,group_code,group_name,group_name_en,activity_code,is_active,show_in_app').single();
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم إنشاء المجموعة بالكود ${_s(inserted['group_code'])} وربطها بالنشاط المحدد.');
    } catch (e) { if (mounted) ErpCenterToast.show(context, 'تعذر إنشاء المجموعة: $e', isError: true); }
    finally { name.dispose(); if (mounted) setState(() => _saving = false); }
  }

  Future<void> _openGroupBrandPicker(Map<String,dynamic> group) async {
    if (_saving) return;
    final groupId = _s(group['id']);
    final isUngrouped = groupId.isEmpty;
    final selectedIds = <String>{};
    final search = TextEditingController();
    final available = _rows.where((row) => row['is_system'] != true &&
      (isUngrouped ? _s(row['brand_group_id']).isNotEmpty : _s(row['brand_group_id']) != groupId))
      .toList()..sort(_compareBrandCodes);
    final accepted = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (dialogContext) => Directionality(textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (context, setDialogState) {
          final term = search.text.trim().toLowerCase();
          final filtered = available.where((row) => _s(row['brand_code']).toLowerCase().contains(term) ||
            _s(row['brand_name']).toLowerCase().contains(term) ||
            _s(row['brand_name_en']).toLowerCase().contains(term)).toList();
          return AlertDialog(
            title: Text(isUngrouped ? 'إعادة براندات إلى بدون مجموعة' : 'إضافة براندات إلى ${_s(group['group_name'])}'),
            content: SizedBox(width: 900, height: 560, child: Column(children: [
              TextField(controller: search, onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'ابحث بكود البراند أو الاسم العربي',
                  prefixIcon: Icon(Icons.search, color: _brandPurple), isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('البراندات المتاحة: ${filtered.length} • المحدد: ${selectedIds.length}',
                  style: const TextStyle(color: _brandPurple, fontWeight: FontWeight.w800))),
                TextButton(onPressed: filtered.isEmpty ? null : () => setDialogState(() {
                  selectedIds.addAll(filtered.map((row) => _s(row['id'])));
                }), child: const Text('تحديد نتائج البحث')),
                TextButton(onPressed: selectedIds.isEmpty ? null : () => setDialogState(selectedIds.clear),
                  child: const Text('إلغاء التحديد')),
              ]),
              Expanded(child: filtered.isEmpty ? const Center(child: Text('لا توجد براندات متاحة مطابقة للبحث.'))
                : DataTable2(
                  minWidth: 820, columnSpacing: 10, horizontalMargin: 8, headingRowHeight: 42,
                  dataRowHeight: 48, showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                  columns: const [
                    DataColumn2(label: Text('اختيار'), size: ColumnSize.S, fixedWidth: 76),
                    DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                    DataColumn2(label: Text('كود البراند'), size: ColumnSize.S, fixedWidth: 115),
                    DataColumn2(label: Text('اسم البراند عربي'), size: ColumnSize.L),
                  ],
                  rows: List<DataRow>.generate(filtered.length, (index) {
                    final row = filtered[index], id = _s(filtered[index]['id']);
                    final checked = selectedIds.contains(id);
                    return DataRow(selected: checked, onSelectChanged: (_) => setDialogState(() {
                      if (checked) { selectedIds.remove(id); } else { selectedIds.add(id); }
                    }), cells: [
                      DataCell(Checkbox(shape: const CircleBorder(), value: checked, activeColor: _brandPurple,
                        onChanged: (value) => setDialogState(() {
                          if (value == true) { selectedIds.add(id); } else { selectedIds.remove(id); }
                        }))),
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(_s(row['brand_code']), style: const TextStyle(color: _brandPurple, fontWeight: FontWeight.w900))),
                      DataCell(Text(_s(row['brand_name']))),
                    ]);
                  }),
                )),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton.icon(onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.add), label: Text('إضافة المحدد (${selectedIds.length})')),
            ],
          );
        })));
    search.dispose();
    if (accepted != true || selectedIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final ids = selectedIds.toList();
      await _db.from('erp_brands').update({'brand_group_id': isUngrouped ? null : groupId})
        .eq('company_id', widget.companyId.trim()).inFilter('id', ids).select('id');
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم ربط ${ids.length} براند بالمجموعة المحددة بنجاح.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر ربط البراندات بالمجموعة: $error', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _deleteGroup(Map<String,dynamic> group) async {
    final id = _s(group['id']);
    if (id.isEmpty || _saving) return;
    if (_s(group['group_code']) == 'Brg01' || _s(group['group_name']) == 'بدون مجموعة') {
      ErpCenterToast.show(context, 'مجموعة «بدون مجموعة» أساسية ومحمية من الحذف.', isError: true);
      return;
    }
    final count = _rows.where((row) => _s(row['brand_group_id']) == id).length;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        title: const Text('حذف مجموعة البراندات'),
        content: Text('سيتم حذف المجموعة «${_s(group['group_name'])}». عدد البراندات المرتبطة بها: $count. ستنتقل هذه البراندات تلقائيًا إلى «بدون مجموعة» مع الاحتفاظ ببياناتها وأكوادها. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.delete_outline),
            label: const Text('حذف المجموعة')),
        ],
      )));
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _db.from('erp_brand_groups').delete().eq('id', id)
        .eq('company_id', widget.companyId.trim()).select('id').single();
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم حذف المجموعة ونقل برانداتها إلى بدون مجموعة.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حذف المجموعة: $error', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _toggleGroupField(Map<String,dynamic> group, String field) async {
    final id = _s(group['id']);
    if (id.isEmpty || _saving) return;
    final next = group[field] != true;
    setState(() => _saving = true);
    try {
      await _db.from('erp_brand_groups').update({field: next})
        .eq('id', id).eq('company_id', widget.companyId.trim()).select('id').single();
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, field == 'is_active'
        ? (next ? 'تم تنشيط المجموعة.' : 'تم إيقاف المجموعة.')
        : (next ? 'المجموعة ستظهر في التطبيق.' : 'تم إخفاء المجموعة من التطبيق.'));
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر تحديث بيانات المجموعة: $error', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _editGroup(Map<String,dynamic> group) async {
    final isDefault = _s(group['group_code']) == 'Brg01';
    final name = TextEditingController(text: _s(group['group_name']));
    var activityCode = _s(group['activity_code']).isEmpty ? '01' : _s(group['activity_code']);
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(title: const Text('تعديل مجموعة البراندات'),
        content: SizedBox(width: 420, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, readOnly: isDefault,
            decoration: const InputDecoration(labelText: 'اسم البراند عربي *'),
            validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم المجموعة.' : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: activityCode, isExpanded: true,
            decoration: const InputDecoration(labelText: 'النشاط التابع له المجموعة *'),
            items: _activities.map((activity) => DropdownMenuItem<String>(
              value: _s(activity['code']), child: Text('${_s(activity['name'])} — ${_s(activity['code'])}'),
            )).toList(),
            onChanged: (value) { if (value != null) activityCode = value; },
            validator: (value) => value == null || value.isEmpty ? 'اختر النشاط.' : null,
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (formKey.currentState?.validate() == true) Navigator.pop(ctx, true); }, child: const Text('حفظ')),
        ])));
    if (ok != true) { name.dispose(); return; }
    final groupId = _s(group['id']);
    final previous = Map<String, dynamic>.from(group);
    final updated = <String, dynamic>{
      ...previous,
      'group_name': isDefault ? 'بدون مجموعة' : name.text.trim(),
      'activity_code': activityCode,
    };

    // Update the visible group immediately; do not reload brands, groups and
    // activity metadata just to reflect one edited group.
    if (mounted) {
      setState(() {
        final index = _groups.indexWhere((item) => _s(item['id']) == groupId);
        if (index >= 0) _groups[index] = updated;
      });
    }
    try {
      await _db.from('erp_brand_groups').update({
        'group_name': updated['group_name'],
        'group_name_en': updated['group_name_en'],
        'activity_code': updated['activity_code'],
      }).eq('id', groupId).eq('company_id', widget.companyId.trim()).select('id').single();
      if (mounted) ErpCenterToast.show(context, 'تم تعديل بيانات المجموعة والنشاط التابع لها.');
    } catch (e) {
      // Roll back the optimistic change if the database rejects the update.
      if (mounted) {
        setState(() {
          final index = _groups.indexWhere((item) => _s(item['id']) == groupId);
          if (index >= 0) _groups[index] = previous;
        });
        ErpCenterToast.show(context, 'تعذر تعديل المجموعة: $e', isError: true);
      }
    } finally { name.dispose(); }
  }

  Future<void> _toggleGroup(Map<String,dynamic> group) async {
    try {
      await _db.from('erp_brand_groups').update({'is_active':group['is_active']!=true})
        .eq('id',_s(group['id'])).eq('company_id',widget.companyId.trim()).select('id').single();
      await _load(showLoading: false);
    } catch(e){if(mounted) ErpCenterToast.show(context,'تعذر تغيير حالة المجموعة: $e',isError:true);}
  }

  final Map<String, Future<void>> _groupAssignmentQueues = <String, Future<void>>{};
  final Map<String, int> _groupAssignmentVersions = <String, int>{};
  final Map<String, String?> _groupAssignmentPersistedValues = <String, String?>{};

  Future<void> _assignActivity(Map<String,dynamic> row, String activityCode) async {
    final id = _s(row['id']);
    if (id.isEmpty || !mounted || row['is_system'] == true) return;
    final index = _rows.indexWhere((item) => _s(item['id']) == id);
    if (index < 0 || _s(_rows[index]['activity_code']) == activityCode) return;
    final previous = Map<String,dynamic>.from(_rows[index]);
    final group = _groupById(_s(previous['brand_group_id']));
    final keepGroup = group != null && _s(group['activity_code']) == activityCode;
    final nextGroupId = keepGroup ? _s(group['id']) : null;
    setState(() { _rows[index] = <String,dynamic>{...previous,
      'activity_code': activityCode, 'brand_group_id': nextGroupId,
      'brand_group': keepGroup ? _s(group['group_name']) : ''}; });
    try {
      await _db.from('erp_brands').update({'activity_code': activityCode,
        'brand_group_id': nextGroupId, 'brand_group': keepGroup ? _s(group['group_name']) : null})
        .eq('id', id).eq('company_id', widget.companyId.trim()).select('id').single();
      if (mounted) ErpCenterToast.show(context, keepGroup
        ? 'تم تغيير نوع نشاط البراند.'
        : 'تم تغيير نوع النشاط وإلغاء المجموعة غير التابعة له. اختر مجموعة مناسبة للنشاط الجديد.');
    } catch (error) {
      if (!mounted) return;
      final current = _rows.indexWhere((item) => _s(item['id']) == id);
      if (current >= 0) setState(() => _rows[current] = previous);
      ErpCenterToast.show(context, 'تعذر تغيير نوع نشاط البراند: $error', isError: true);
    }
  }

  Future<void> _toggleBrandVisibility(Map<String,dynamic> row) async {
    final id = _s(row['id']);
    if (id.isEmpty || row['is_system'] == true) return;
    final index = _rows.indexWhere((item) => _s(item['id']) == id);
    if (index < 0) return;
    final previous = row['show_in_app'] == true;
    final next = !previous;
    setState(() => _rows[index] = <String,dynamic>{..._rows[index], 'show_in_app': next});
    try {
      await _db.from('erp_brands').update({'show_in_app': next})
        .eq('id', id).eq('company_id', widget.companyId.trim()).select('id').single();
      if (mounted) ErpCenterToast.show(context, next ? 'سيظهر البراند في التطبيق.' : 'تم إخفاء البراند من التطبيق.');
    } catch (error) {
      if (!mounted) return;
      final current = _rows.indexWhere((item) => _s(item['id']) == id);
      if (current >= 0) setState(() => _rows[current] = <String,dynamic>{..._rows[current], 'show_in_app': previous});
      ErpCenterToast.show(context, 'تعذر تحديث ظهور البراند: $error', isError: true);
    }
  }

  Future<void> _saveDisplayOrder(Map<String,dynamic> row, String value) async {
    final order = int.tryParse(value.trim());
    if (order == null || order < 0) {
      ErpCenterToast.show(context, 'ترتيب الظهور يجب أن يكون رقمًا صحيحًا يبدأ من صفر.', isError: true);
      return;
    }
    final id = _s(row['id']);
    final index = _rows.indexWhere((item) => _s(item['id']) == id);
    if (index < 0 || (int.tryParse(_s(_rows[index]['display_order'])) ?? 0) == order) return;
    final previous = _rows[index]['display_order'];
    setState(() => _rows[index] = <String,dynamic>{..._rows[index], 'display_order': order});
    try {
      await _db.from('erp_brands').update({'display_order': order})
        .eq('id', id).eq('company_id', widget.companyId.trim()).select('id').single();
      if (mounted) ErpCenterToast.show(context, 'تم حفظ ترتيب ظهور البراند في التطبيق.');
    } catch (error) {
      if (!mounted) return;
      final current = _rows.indexWhere((item) => _s(item['id']) == id);
      if (current >= 0) setState(() => _rows[current] = <String,dynamic>{..._rows[current], 'display_order': previous});
      ErpCenterToast.show(context, 'تعذر حفظ ترتيب الظهور: $error', isError: true);
    }
  }

  Future<void> _assignGroup(Map<String,dynamic> row, String? groupId) async {
    final brandId = _s(row['id']);
    if (brandId.isEmpty || !mounted) return;

    final index = _rows.indexWhere((item) => _s(item['id']) == brandId);
    if (index < 0) return;
    final previousGroupId = _rows[index]['brand_group_id']?.toString();
    if (previousGroupId == groupId) return;
    final selectedGroup = _groupById(groupId);
    if (selectedGroup != null && _s(selectedGroup['activity_code']) != _s(_rows[index]['activity_code'])) {
      ErpCenterToast.show(context, 'لا يمكن ربط البراند بمجموعة تابعة لنوع نشاط مختلف.', isError: true);
      return;
    }
    _groupAssignmentPersistedValues.putIfAbsent(brandId, () => previousGroupId);

    // Reflect the selection in the grid immediately, without waiting for
    // Supabase and without reloading the entire brands/groups catalog.
    setState(() { _rows[index] = <String, dynamic>{..._rows[index], 'brand_group_id': groupId,
      'brand_group': selectedGroup == null ? '' : _s(selectedGroup['group_name'])}; });

    final version = (_groupAssignmentVersions[brandId] ?? 0) + 1;
    _groupAssignmentVersions[brandId] = version;
    final previousWrite = _groupAssignmentQueues[brandId] ?? Future<void>.value();
    final write = previousWrite.catchError((_) {}).then((_) async {
      try {
        await _db.from('erp_brands').update({'brand_group_id': groupId,
          'brand_group': selectedGroup == null ? null : _s(selectedGroup['group_name'])})
          .eq('id', brandId).eq('company_id', widget.companyId.trim())
          .select('id').single();
        _groupAssignmentPersistedValues[brandId] = groupId;
      } catch (error) {
        // A stale request must never roll back a newer selection.
        if (mounted && _groupAssignmentVersions[brandId] == version) {
          setState(() {
            final currentIndex = _rows.indexWhere((item) => _s(item['id']) == brandId);
            if (currentIndex >= 0) {
              _rows[currentIndex] = <String, dynamic>{
                ..._rows[currentIndex],
                'brand_group_id': _groupAssignmentPersistedValues[brandId],
                'brand_group': _groupById(_groupAssignmentPersistedValues[brandId])?['group_name'] ?? '',
              };
            }
          });
          ErpCenterToast.show(context, 'تعذر تغيير مجموعة البراند: $error', isError: true);
        }
      }
    });
    _groupAssignmentQueues[brandId] = write;
    await write;
    if (_groupAssignmentVersions[brandId] == version) {
      _groupAssignmentQueues.remove(brandId);
    }
  }

  List<String> get _groupNames {
    final names = _rows.map(_groupKey).toSet().toList();
    names.sort((a,b) {
      if (a == 'بدون مجموعة') return -1;
      if (b == 'بدون مجموعة') return 1;
      return a.compareTo(b);
    });
    return names;
  }

  int _brandCodeNumber(Map<String,dynamic> row) =>
      int.tryParse(_s(row['brand_code']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int _compareBrandCodes(Map<String,dynamic> a, Map<String,dynamic> b) {
    final numeric = _brandCodeNumber(a).compareTo(_brandCodeNumber(b));
    return numeric != 0 ? numeric : _s(a['brand_code']).compareTo(_s(b['brand_code']));
  }

  List<Map<String,dynamic>> _rowsInGroup(String group) {
    return _visibleRows.where((row) => _groupKey(row) == group).toList()
      ..sort(_compareBrandCodes);
  }

  Widget _brandGridField(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _brandBorder),
      borderRadius: BorderRadius.circular(7),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    child: child,
  );

  Widget _logoPreview(Map<String,dynamic> row, {double size = 48}) {
    final bytes = _logoBytes(row['logo_data']);
    return Container(
      width: size, height: size, alignment: Alignment.center,
      padding: const EdgeInsets.all(3), clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle,
        gradient: SweepGradient(colors: [Color(0xFFFFA015), Color(0xFFFF27C3), _brandPurple, Color(0xFFFFA015)])),
      child: Container(
        padding: const EdgeInsets.all(2), clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: ClipOval(child: bytes != null && bytes.isNotEmpty
          ? Image.memory(bytes, fit: BoxFit.cover, width: size - 10, height: size - 10,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.black38))
          : const Icon(Icons.storefront_outlined, color: Color(0xFF9A86B5), size: 25)),
      ),
    );
  }

  Future<void> _removeLogo(Map<String,dynamic> row) async {
    if (row['is_system'] == true) return;
    setState(() => _saving = true);
    try {
      await _db.from('erp_brands').update({
        'logo_data': null, 'logo_mime_type': null,
      }).eq('id', _s(row['id']))
        .eq('company_id', widget.companyId.trim()).select('id').single();
      await _load(showLoading: false);
      if (mounted) ErpCenterToast.show(context, 'تم حذف شعار البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حذف الشعار: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _treeBrandRow(Map<String,dynamic> row, int index) {
    final id = _s(row['id']);
    final selected = _selectedId == id;
    final system = row['is_system'] == true;
    final activityCode = _s(row['activity_code']).isEmpty ? '01' : _s(row['activity_code']);
    final availableGroups = _groupsForActivity(activityCode);
    final selectedGroupId = availableGroups.any((group) => _s(group['id']) == _s(row['brand_group_id']))
        ? _s(row['brand_group_id']) : null;
    final activityDropdown = SizedBox(width: 145, child: DropdownButton<String>(
      isExpanded: true,
      value: _activities.any((activity) => _s(activity['code']) == activityCode) ? activityCode : null,
      hint: const Text('نوع النشاط'), underline: const SizedBox.shrink(),
      style: const TextStyle(fontSize: 11, color: Colors.black87),
      items: _activities.map((activity) => DropdownMenuItem<String>(
        value: _s(activity['code']), child: Text(_s(activity['name']), overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: system ? null : (value) { if (value != null) _assignActivity(row, value); },
    ));
    final groupDropdown = SizedBox(width: 165, child: DropdownButton<String?>(
      isExpanded: true, value: selectedGroupId, hint: const Text('بدون مجموعة'),
      underline: const SizedBox.shrink(), style: const TextStyle(fontSize: 11, color: Colors.black87),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('بدون مجموعة')),
        ...availableGroups.map((group) => DropdownMenuItem<String?>(
          value: _s(group['id']),
          child: Text('${_s(group['group_code'])} - ${_s(group['group_name'])}', overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: system ? null : (value) => _assignGroup(row, value),
    ));
    final status = SizedBox(width: 68, child: Center(child: Checkbox(
      shape: const CircleBorder(), value: row['is_active'] == true,
      activeColor: _brandPurple, visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: system ? null : (_) => _toggle(row),
    )));
    final appVisibility = SizedBox(width: 78, child: Center(child: Checkbox(
      shape: const CircleBorder(), value: row['show_in_app'] == true,
      activeColor: _brandPurple, visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: system ? null : (_) => _toggleBrandVisibility(row),
    )));
    final displayOrder = SizedBox(width: 62, child: TextFormField(
      key: ValueKey('brand-order-$id-${_s(row['display_order'])}'),
      initialValue: _s(row['display_order']).isEmpty ? '1000' : _s(row['display_order']),
      enabled: !system, textAlign: TextAlign.center, keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _brandPurple),
      decoration: const InputDecoration(isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: OutlineInputBorder(), hintText: 'ترتيب'),
      onFieldSubmitted: (value) => _saveDisplayOrder(row, value),
    ));
    final logo = InkWell(onTap: () => _showLogoDialog(row), child: _logoPreview(row, size: 46));
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFF0E7FA) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedId = id),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? _brandPurple : _brandBorder)),
            child: LayoutBuilder(builder: (context, constraints) {
              final code = Text(_s(row['brand_code']), overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple, fontSize: 11));
              final name = Text(_s(row['brand_name']), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13));

              return Row(children: [
                SizedBox(width: 28, child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                SizedBox(width: 92, child: code),
                activityDropdown, const SizedBox(width: 5), groupDropdown, const SizedBox(width: 5),
                Expanded(flex: 3, child: name), const SizedBox(width: 3),
                status, appVisibility, displayOrder, const SizedBox(width: 3),
                SizedBox(width: 50, child: Center(child: logo)),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _treeGroup(String group, int index) {
    final children = _rowsInGroup(group);
    final expanded = _expandedGroups.contains(group);
    Map<String, dynamic>? record;
    for (final candidate in _groups) {
      if (_s(candidate['group_name']) == group) { record = candidate; break; }
    }
    final groupCode = _s(record?['group_code']);
    final isDefault = groupCode == 'Brg01';
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(color: const Color(0xFFEDE1F8),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: _brandBorder)),
      child: Column(children: [
        Material(
          color: const Color(0xFFEDE1F8),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              if (expanded) { _expandedGroups.remove(group); } else { _expandedGroups.add(group); }
            }),
            child: SizedBox(height: 48, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                SizedBox(width: 28, child: Text('$index', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
                SizedBox(width: 92, child: Text(groupCode, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _brandPurple))),
                SizedBox(width: 145, child: Text(record == null ? '' : _activityName(_s(record['activity_code'])), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54))),
                const SizedBox(width: 5),
                const SizedBox(width: 165),
                const SizedBox(width: 5),
                Expanded(flex: 2, child: Text(group == 'بدون مجموعة' ? 'براندات بدون مجموعة' : group,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _brandPurple))),
                const SizedBox(width: 5),
                const Expanded(flex: 1, child: SizedBox.shrink()),
                const SizedBox(width: 3),
                SizedBox(width: 68, child: Center(child: Text('${children.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))),
                const SizedBox(width: 78),
                const SizedBox(width: 62),
                SizedBox(width: 46, child: record == null ? const SizedBox.shrink() : IconButton(
                  tooltip: 'إضافة براندات للمجموعة', visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
                  onPressed: _saving ? null : () => _openGroupBrandPicker(record!),
                  icon: const Icon(Icons.add_circle_outline, color: _brandPurple, size: 18))),
                SizedBox(width: 40, child: record == null ? const SizedBox.shrink() : PopupMenuButton<String>(
                  tooltip: 'إدارة المجموعة', padding: EdgeInsets.zero, enabled: !_saving && !isDefault,
                  icon: const Icon(Icons.more_vert, size: 18, color: _brandPurple),
                  onSelected: (value) { if (value == 'edit') _editGroup(record!); if (value == 'delete') _deleteGroup(record!); },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل المجموعة')),
                    PopupMenuItem(value: 'delete', child: Text('حذف المجموعة')),
                  ],
                )),
              ]),
            )),
          ),
        ),
        if (expanded) Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
          child: Column(children: children.asMap().entries.map((entry) => _treeBrandRow(entry.value, entry.key)).toList()),
        ),
      ]),
    );
  }

  Widget _treeHeader() {
    const headingStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _brandPurple);
    Widget filter(String key, double width, String hint) => SizedBox(width: width, child: TextField(
      controller: _columnSearch[key], onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 10),
      decoration: InputDecoration(hintText: hint, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        prefixIcon: const Icon(Icons.search, size: 12),
        prefixIconConstraints: const BoxConstraints(minWidth: 18, minHeight: 22),
        border: const OutlineInputBorder()),
    ));
    return SingleChildScrollView(controller: _treeHeaderController, scrollDirection: Axis.horizontal,
      child: SizedBox(width: 1120, child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: _brandBorder)),
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 28, child: Text('م', textAlign: TextAlign.center, style: headingStyle)),
            const SizedBox(width: 92, child: Text('كود البراند', style: headingStyle)),
            const SizedBox(width: 145, child: Text('نوع النشاط', style: headingStyle)),
            const SizedBox(width: 5),
            const SizedBox(width: 165, child: Text('مجموعة البراند', style: headingStyle)),
            const SizedBox(width: 5),
            const Expanded(flex: 2, child: Text('اسم البراند/الماركة', style: headingStyle)),
            const SizedBox(width: 5),
            const SizedBox(width: 3),
            const SizedBox(width: 68, child: Center(child: Text('نشط', style: headingStyle))),
            const SizedBox(width: 78, child: Center(child: Text('في التطبيق', style: headingStyle))),
            const SizedBox(width: 62, child: Center(child: Text('الترتيب', style: headingStyle))),
            const SizedBox(width: 50, child: Center(child: Text('الشعار', style: headingStyle))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const SizedBox(width: 28), filter('code', 92, 'بحث الكود'),
            filter('activity', 145, 'بحث النشاط'), const SizedBox(width: 5),
            filter('group', 165, 'بحث المجموعة'), const SizedBox(width: 5),
            Expanded(flex: 2, child: filter('name', double.infinity, 'بحث الاسم العربي')),
            const SizedBox(width: 5),
            const SizedBox(width: 3), const SizedBox(width: 68), const SizedBox(width: 78),
            const SizedBox(width: 62), const SizedBox(width: 50),
          ]),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactMobile = MediaQuery.sizeOf(context).width < 600;
    final rows = _visibleRows.toList()..sort(_compareBrandCodes);
    final selected = _selectedRow();
    final visibleGroups = rows.map(_groupKey).toSet().toList();
    for (final group in _groups) {
      final code = _s(group['activity_code']);
      final name = _s(group['group_name']);
      final groupFilter = _columnSearch['group']!.text.trim().toLowerCase();
      if ((_selectedActivityCode == 'all' || code == _selectedActivityCode) &&
          (groupFilter.isEmpty || name.toLowerCase().contains(groupFilter))) {
        if (name.isNotEmpty && !visibleGroups.contains(name)) visibleGroups.add(name);
      }
    }
    visibleGroups.sort((a,b) {
        if (a == 'بدون مجموعة') return -1;
        if (b == 'بدون مجموعة') return 1;
        return a.compareTo(b);
      });
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _brandCanvas,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ErpQuickTaskButton(label:'تحديث', icon:Icons.refresh_rounded, onPressed:_loading || _saving ? null : _load),
                ErpQuickTaskButton(label:'عرض شجرة', icon:Icons.account_tree_outlined, onPressed:() => setState(() => _viewMode = 'tree')),
                ErpQuickTaskButton(label:'عرض جدول', icon:Icons.table_rows_outlined, onPressed:() => setState(() => _viewMode = 'grid')),
                ErpQuickTaskButton(label:'إضافة جديد', icon:Icons.add_circle_outline, onPressed:_saving ? null : () => _edit()),
                ErpQuickTaskButton(label:'تعديل المحدد', icon:Icons.edit_outlined, onPressed:_saving ? null : () {
                  if (_viewMode == 'grid') {
                    if (selected == null || selected['is_system'] == true) { ErpCenterToast.show(context, 'حدد براندًا عاديًا من الجدول أولًا.', isError:true); return; }
                    setState(() { _gridEditing = true; _gridEditingOnlyId = _s(selected['id']); });
                    _syncGridNameControllers();
                  } else if (selected != null && selected['is_system'] != true) { _edit(row:selected); }
                }),
                if (_viewMode == 'grid') ErpQuickTaskButton(label:'تعديل الكل', icon:Icons.edit_note_outlined, onPressed:_saving ? null : () {
                  setState(() { _gridEditing = true; _gridEditingOnlyId = null; });
                  _syncGridNameControllers();
                }),
                if (_viewMode == 'grid' && _gridEditing) ...[
                  ErpQuickTaskButton(label:'حفظ التعديلات', icon:Icons.save_outlined, onPressed:_saving ? null : () => _saveGridNames(onlyId:_gridEditingOnlyId)),
                  ErpQuickTaskButton(label:'إلغاء التعديل', icon:Icons.close, onPressed:_saving ? null : () {
                    setState(() { _gridEditing = false; _gridEditingOnlyId = null; });
                    _syncGridNameControllers();
                  }),
                ],
                ErpQuickTaskButton(label:'شعار البراند', icon:Icons.image_outlined, onPressed:_saving || selected == null ? null : () => _uploadLogo(selected)),
                ErpQuickTaskButton(label:'استيراد شعارات متعددة', icon:Icons.collections_outlined, onPressed:_saving ? null : _bulkImportLogos),
                ErpQuickTaskButton(label:'حذف', icon:Icons.delete_outline, onPressed:_saving || selected == null || selected['is_system'] == true ? null : _delete),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 5, children: [
              const Text('نوع النشاط:', style: TextStyle(color: _brandPurple, fontWeight: FontWeight.w800)),
              SizedBox(width: 220, child: DropdownButtonFormField<String>(
                value: _selectedActivityCode, isExpanded: true, isDense: true,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8), border: OutlineInputBorder()),
                items: [const DropdownMenuItem(value: 'all', child: Text('كل الأنشطة')),
                  ..._activities.map((a) => DropdownMenuItem(value: _s(a['code']), child: Text(_s(a['name']), overflow: TextOverflow.ellipsis)))],
                onChanged: (value) => setState(() { _selectedActivityCode = value ?? 'all'; }),
              )),
              FilledButton.icon(onPressed: _saving ? null : _addGroup,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18), label: const Text('إضافة مجموعة براند')),
            ]),
          ),
          if (_showGroups) ...[
            Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 4), child: Row(children: [
              Expanded(child: Text('مجموعات البراندات: ${_groups.length} • إجمالي البراندات: ${_rows.length}',
                style: const TextStyle(color: _brandPurple, fontWeight: FontWeight.w800))),
              FilledButton.icon(onPressed: _saving ? null : _addGroup,
                icon: const Icon(Icons.add), label: const Text('إضافة مجموعة جديدة')),
            ])),
            if (_error != null)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1125,
                  child: DataTable2(
                  minWidth: 1125, columnSpacing: 2, horizontalMargin: 8,
                  headingRowHeight: 44, dataRowHeight: compactMobile ? 40 : 54, showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                  columns: const [
                    DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                    DataColumn2(label: Text('كود مجموعة البراند'), size: ColumnSize.M, fixedWidth: 175),
                    DataColumn2(label: Text('اسم البراند عربي'), size: ColumnSize.L, fixedWidth: 220),
                    DataColumn2(label: Text('النشاط'), size: ColumnSize.M, fixedWidth: 160),
                    DataColumn2(label: Text('عدد البراندات'), size: ColumnSize.S, fixedWidth: 115),
                    DataColumn2(label: Text('نشط أو لا'), size: ColumnSize.S, fixedWidth: 95),
                    DataColumn2(label: Text('إضافة / حذف'), size: ColumnSize.S, fixedWidth: 130),
                  ],
                  rows: [
                    ...(() {
                      final ordered = _groups.toList()..sort((a, b) {
                        final an = int.tryParse(_s(a['group_code']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        final bn = int.tryParse(_s(b['group_code']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        return an.compareTo(bn);
                      });
                      return ordered.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final group = entry.value;
                        final id = _s(group['id']);
                        final count = _rows.where((row) => _s(row['brand_group_id']) == id).length;
                        final isDefault = _s(group['group_code']) == 'Brg01';
                        return DataRow(color: WidgetStateProperty.all(index.isEven ? Colors.white : const Color(0xFFFCFAFE)),
                          cells: [
                            DataCell(Text('$index')),
                            DataCell(Text(_s(group['group_code']), style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple))),
                            DataCell(Text(_s(group['group_name']), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)), onTap: isDefault ? null : () => _editGroup(group)),
                            DataCell(Text(_activityName(_s(group['activity_code'])), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
                            DataCell(Text('$count')),
                            DataCell(Checkbox(shape: const CircleBorder(), value: group['is_active'] == true,
                              activeColor: _brandPurple, visualDensity: compactMobile ? VisualDensity.compact : VisualDensity.standard,
                              materialTapTargetSize: compactMobile ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
                              onChanged: _saving || isDefault ? null : (_) => _toggleGroupField(group, 'is_active'))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(tooltip: 'إضافة براندات للمجموعة', visualDensity: VisualDensity.compact,
                                constraints: BoxConstraints.tightFor(width: compactMobile ? 28 : 40, height: compactMobile ? 28 : 40),
                                onPressed: _saving ? null : () => _openGroupBrandPicker(group),
                                icon: const Icon(Icons.add_circle, color: _brandPurple)),
                              IconButton(tooltip: isDefault ? 'المجموعة الأساسية لا تُحذف' : 'حذف المجموعة', visualDensity: VisualDensity.compact,
                                constraints: BoxConstraints.tightFor(width: compactMobile ? 28 : 40, height: compactMobile ? 28 : 40),
                                onPressed: _saving || isDefault ? null : () => _deleteGroup(group),
                                icon: const Icon(Icons.delete, color: Colors.red)),
                            ])),
                          ]);
                      }).toList();
                    })(),
                  ],
                ),
                ),
              )),
          ] else ...[
          if (_viewMode != 'tree') Padding(
            padding: const EdgeInsets.fromLTRB(12,7,12,3),
            child: TextField(
              controller:_search,
              onChanged:(_) => setState(() {}),
              decoration: InputDecoration(
                labelText:'ابحث بكود البراند أو اسمه أو المجموعة',
                prefixIcon:const Icon(Icons.search,color:_brandPurple),
                suffixIcon:_search.text.isEmpty ? null : IconButton(
                  onPressed:() { _search.clear(); setState(() {}); },
                  icon:const Icon(Icons.clear),
                ),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                isDense:true,
              ),
            ),
          ),
          if (_error != null)
            Padding(padding:const EdgeInsets.all(7), child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:12))),
          Padding(
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),
            child:Row(children:[
              Expanded(child:Text('عدد البراندات/الماركات: ${rows.length}',
                style:const TextStyle(color:_brandPurple,fontWeight:FontWeight.w800))),
              if (_viewMode == 'tree') ...[
                TextButton.icon(
                  onPressed:_loading || visibleGroups.isEmpty ? null : () => setState(() => _expandedGroups.addAll(visibleGroups)),
                  icon:const Icon(Icons.unfold_more,size:18), label:const Text('فتح الكل')),
                TextButton.icon(
                  onPressed:_loading ? null : () => setState(() => _expandedGroups.clear()),
                  icon:const Icon(Icons.unfold_less,size:18), label:const Text('طي الكل')),
              ],
            ]),
          ),
          if (_viewMode == 'tree') _treeHeader(),
          Expanded(
            child:_loading
              ? const Center(child:CircularProgressIndicator())
              : rows.isEmpty
                ? const Center(child:Text('لا توجد براندات مطابقة للبحث.'))
                : _viewMode == 'tree'
                  ? SingleChildScrollView(
                      controller: _treeRowsController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: 1120, child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        children: visibleGroups.asMap().entries.map((entry) => _treeGroup(entry.value, entry.key + 1)).toList(),
                      )),
                    )
                  : DataTable2(
                      fixedTopRows: 1,
                      minWidth: 650,
                      columnSpacing: 2,
                      horizontalMargin: 8,
                      headingRowHeight: 42,
                      dataRowHeight: compactMobile ? 40 : 60,
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                      columns: const [
                        DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                        DataColumn2(label: Text('كود البراند'), size: ColumnSize.S, fixedWidth: 110),
                        DataColumn2(label: Text('اسم البراند/الماركة'), size: ColumnSize.S, fixedWidth: 110),
                        DataColumn2(label: Text('الشعار'), size: ColumnSize.S, fixedWidth: 58),
                        DataColumn2(label: Text('المجموعة'), size: ColumnSize.M, fixedWidth: 160),
                        DataColumn2(label: Text('نشط'), size: ColumnSize.S, fixedWidth: 58),
                        DataColumn2(label: Text('في التطبيق'), size: ColumnSize.S, fixedWidth: 68),
                      ],
                      rows: List<DataRow>.generate(rows.length, (index) {
                        final row = rows[index];
                        final id = _s(row['id']);
                        final system = row['is_system'] == true;
                        final ar = _gridNameControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['brand_name'])));
                        return DataRow(
                          color: WidgetStateProperty.all(system ? const Color(0xFFEDE1F8) : Colors.white),
                          cells: [
                            DataCell(_brandGridField(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                            DataCell(_brandGridField(Text(_s(row['brand_code']), style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple))), onTap: () => setState(() => _selectedId = id)),
                            DataCell(_brandGridField(SizedBox(width: 104, child: _gridEditing && (_gridEditingOnlyId == null || _gridEditingOnlyId == id) && !system
                              ? Focus(
                                  onKeyEvent: (_, event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) { FocusScope.of(context).nextFocus(); return KeyEventResult.handled; }
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) { FocusScope.of(context).previousFocus(); return KeyEventResult.handled; }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(controller: ar, enabled: !_saving, textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(isDense:true, contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8), border:OutlineInputBorder(), hintText:'اسم البراند بالعربية'),
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                                )
                              : Text(_s(row['brand_name']), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)), onTap: !system && !_gridEditing
                              ? () => setState(() {
                                  _selectedId = id;
                                  _gridEditing = true;
                                  _gridEditingOnlyId = id;
                                })
                              : null)),
                            DataCell(_brandGridField(InkWell(onTap: () => _showLogoDialog(row), child: _logoPreview(row, size: 50)))),
                            DataCell(_brandGridField(SizedBox(width: 150, child: DropdownButton<String?>(
                              isExpanded: true, isDense: compactMobile, itemHeight: compactMobile ? 40 : 48,
                              value: _groups.any((g) => _s(g['id']) == _s(row['brand_group_id'])) ? _s(row['brand_group_id']) : _defaultGroupId,
                              hint: const Text('بدون مجموعة'),
                              items: _groups.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text('${_s(g['group_code'])} - ${_s(g['group_name'])}', overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: system ? null : (v) => _assignGroup(row, v),
                            )))),
                            DataCell(Checkbox(shape: const CircleBorder(), value: row['is_active'] == true, activeColor: _brandPurple,
                              visualDensity: compactMobile ? VisualDensity.compact : VisualDensity.standard,
                              materialTapTargetSize: compactMobile ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
                              onChanged: system ? null : (_) => _toggle(row))),
                            DataCell(Checkbox(shape: const CircleBorder(), value: row['show_in_app'] == true, activeColor: _brandPurple,
                              visualDensity: compactMobile ? VisualDensity.compact : VisualDensity.standard,
                              materialTapTargetSize: compactMobile ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
                              onChanged: system ? null : (_) => _toggleBrandVisibility(row))),
                          ],
                        );
                      }),
                    ),
          ),
          ],
        ],
      ),
    );
  }
}

