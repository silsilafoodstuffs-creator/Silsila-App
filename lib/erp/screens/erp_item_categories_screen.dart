import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_catalog_tree_card.dart';
import '../widgets/erp_standard_data_table.dart';
import '../widgets/erp_screen_frame.dart';
import '../services/erp_workspace_records_service.dart';
import '../services/erp_screen_layout_profiles.dart';
import '../services/erp_excel_export_service.dart';
import 'erp_brands_tab.dart';

const _catPurple = Color(0xFF3E007D);
const _catOrange = Color(0xFFFFA015);
const _catCanvas = Color(0xFFF7F5FA);

String _normalizeActivityCode(String value) {
  final code = value.trim().toUpperCase();
  if (code.isEmpty) return '';
  final legacy = RegExp(r'^ACT0*(\d{1,3})$').firstMatch(code);
  if (legacy != null) {
    final number = int.tryParse(legacy.group(1)!);
    if (number != null) return number.toString().padLeft(2, '0');
  }
  if (RegExp(r'^\d{1,3}$').hasMatch(code)) {
    final number = int.tryParse(code);
    if (number != null) return number.toString().padLeft(2, '0');
  }
  return code;
}

class ErpItemCategoriesScreen extends StatefulWidget {
  const ErpItemCategoriesScreen({super.key, this.companyId, this.initialCatalogTab = 0, this.hideHeaderAndTabs = false});
  final int initialCatalogTab;
  final bool hideHeaderAndTabs;
  final String? companyId;
  @override
  State<ErpItemCategoriesScreen> createState() => _ErpItemCategoriesScreenState();
}

class _ErpItemCategoriesScreenState extends State<ErpItemCategoriesScreen> {
  SupabaseClient? _db;
  final _picker = ImagePicker();
  final _workspaceRecords = ErpWorkspaceRecordsService();
  List<Map<String,String>> _activities = <Map<String,String>>[];
  String _selectedActivityCode = '01';
  String? _company, _error, _message, _selectedId;
  bool _loading = false, _saving = false, _editing = false;
  int _level = 0;
  int _catalogTab = 0;
  String? _parentFilter;
  String? _mainCategoryFilter;
  String? _subCategoryFilter;
  List<Map<String,dynamic>> _all = [];
  List<Map<String,dynamic>> _companyCategories = [];
  List<Map<String,dynamic>> get _codingCategories => <Map<String,dynamic>>[
    ..._companyCategories.where((row) =>
      _normalizeActivityCode(_s(row['activity_code'])) ==
      _normalizeActivityCode(_selectedActivityCode)),
    ..._all.where((row) => row['_draft'] == true),
  ];
  final Map<String,TextEditingController> _ar = {};
  final Map<String,TextEditingController> _en = {};
  final Map<String,Uint8List?> _imageBytes = {};
  final Map<String,String> _imageNames = {};
  final Set<String> _expandedIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _viewMode = 'grid';

  @override
  void initState() {
    super.initState();
    _company = widget.companyId;
    _catalogTab = widget.initialCatalogTab.clamp(0, 3).toInt();
    try { _db = Supabase.instance.client; } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _ar.values) { c.dispose(); }
    for (final c in _en.values) { c.dispose(); }
    _searchController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  List<Map<String,dynamic>> get _parents => _all.where((r) => r['parent_id'] == null).toList();
  List<Map<String,dynamic>> get _secondaryParents => _all.where((r) => r['parent_id'] != null && _parentOf(r) != null && _parentOf(r)!['parent_id'] == null).toList();
  Map<String,dynamic>? _parentOf(Map<String,dynamic> row) {
    for (final r in _all) { if (_s(r['id']) == _s(row['parent_id'])) return r; }
    return null;
  }
  Future<void> _load() async {
    if (_db == null) {
      if (mounted) setState(() { _error = 'Supabase غير مهيأ.'; _loading = false; });
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; _message = null; });
    try {
      var company = (_company ?? '').trim();
      final uid = _db!.auth.currentUser?.id;
      final activeCompanies = <String>[];
      if (uid != null) {
        final memberships = await _db!.from('erp_company_members')
            .select('company_id')
            .eq('user_id', uid)
            .eq('is_active', true)
            .order('created_at');
        for (final membership in (memberships as List)) {
          final memberCompany = _s(membership['company_id']).trim();
          if (memberCompany.isNotEmpty && !activeCompanies.contains(memberCompany)) {
            activeCompanies.add(memberCompany);
          }
        }
      }
      // Preserve an explicitly selected company. System administrators may
      // access it through elevated RLS policies without a membership row.
      // If its catalog is empty, the guarded fallback below checks only the
      // user's verified active memberships.
      if (company.isEmpty && activeCompanies.isNotEmpty) {
        company = activeCompanies.first;
      }
      if (company.isEmpty) throw StateError('لم يتم تحديد الشركة الحالية أو عضويتها النشطة.');
      _company = company;

      // Read the canonical catalog once. Activity metadata is optional and
      // must never prevent the actual categories from loading.
      var rawRows = await _db!.from('erp_item_categories')
          .select('*')
          .eq('company_id', company)
          .order('category_code')
          .limit(10000);
      // Retry only against the user's other verified memberships when a stale
      // company context yields no rows. Never read another company's catalog.
      if ((rawRows as List).isEmpty && activeCompanies.isNotEmpty) {
        for (final candidate in activeCompanies.where((id) => id != company)) {
          final candidateRows = await _db!.from('erp_item_categories')
              .select('*')
              .eq('company_id', candidate)
              .order('category_code')
              .limit(10000);
          if ((candidateRows as List).isNotEmpty) {
            company = candidate;
            _company = candidate;
            rawRows = candidateRows;
            break;
          }
        }
      }
      final catalog = (rawRows as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (catalog.isEmpty) {
        throw StateError('لم تُرجع قاعدة البيانات فئات للشركة المحددة. تحقق من الشركة النشطة وصلاحية قراءة فئات الأصناف.');
      }

      const activityNames = <String, String>{
        '01': 'مواد غذائية', '02': 'لوازم بناء', '03': 'ملابس واكسسوارات',
        '04': 'أجهزة وإلكترونيات', '05': 'سيارات ومعدات', '06': 'خدمات شحن ونقل',
        '07': 'أثاث وديكورات', '08': 'مستلزمات طبية', '09': 'زراعة ومستلزمات زراعية',
        '10': 'مستلزمات حيوانات وأعلاف', '11': 'أنشطة أخرى', '12': 'كتب ومطبوعات',
      };

      // Normalize both legacy activity identifiers and the current two-digit
      // identifiers before building the picker or filtering the catalog.
      String normalizeActivity(String value) {
        final code = value.trim().toUpperCase();
        if (code.isEmpty) return '';
        final legacy = RegExp(r'^ACT0*(\d{1,3})$').firstMatch(code);
        if (legacy != null) {
          final number = int.tryParse(legacy.group(1)!);
          if (number != null) return number.toString().padLeft(2, '0');
        }
        if (RegExp(r'^\d{1,3}$').hasMatch(code)) {
          final number = int.tryParse(code);
          if (number != null) return number.toString().padLeft(2, '0');
        }
        return code;
      }

      // Always fetch the selected activity independently of the broad catalog
      // request. This prevents server row caps, cached partial catalogs, or
      // mixed-activity pagination from silently omitting one activity.
      final selectedCode = normalizeActivity(_selectedActivityCode);
      final selectedActivityRows = await _db!.from('erp_item_categories')
          .select('*')
          .eq('company_id', company)
          .eq('activity_code', selectedCode)
          .order('category_code')
          .limit(10000);
      final catalogById = <String, Map<String, dynamic>>{
        for (final row in catalog) _s(row['id']): row,
      };
      for (final raw in (selectedActivityRows as List)) {
        if (raw is Map) {
          final row = Map<String, dynamic>.from(raw);
          final id = _s(row['id']);
          if (id.isNotEmpty) catalogById[id] = row;
        }
      }
      final completeCatalog = catalogById.values.toList(growable: false);

      final actualCodes = <String>{};
      for (final row in completeCatalog) {
        final code = normalizeActivity(_s(row['activity_code']));
        if (code.isNotEmpty) actualCodes.add(code);
      }
      // Always include active, visible activities from the authoritative master.
      try {
        final masterRows = await _db!.from('activity_types')
            .select('code,name,is_active,show_in_app')
            .eq('is_active', true)
            .eq('show_in_app', true)
            .order('code');
        for (final raw in (masterRows as List)) {
          final code = normalizeActivity(_s(raw['code']));
          if (code.isNotEmpty) actualCodes.add(code);
        }
      } catch (_) {
        // Preserve the company catalog if the shared activity master is unavailable.
      }

      final sortedActualCodes = actualCodes.toList()..sort();
      const defaultActivity = '01';
      final displayCodes = actualCodes.isEmpty ? <String>{defaultActivity} : actualCodes;
      _activities = displayCodes.map((code) => <String, String>{
        'code': code,
        'name': activityNames[code] ?? 'نشاط $code',
      }).toList()
        ..sort((a, b) => a['code']!.compareTo(b['code']!));

      final wanted = normalizeActivity(_selectedActivityCode);
      _selectedActivityCode = displayCodes.contains(wanted)
          ? wanted
          : displayCodes.contains(defaultActivity)
              ? defaultActivity
              : sortedActualCodes.isNotEmpty ? sortedActualCodes.first : defaultActivity;

      // Keep complete source rows (including names, status, and visibility)
      // for code generation and every downstream category workflow.
      _companyCategories = completeCatalog
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      _all = completeCatalog.where((row) {
        final rawCode = normalizeActivity(_s(row['activity_code']));
        if (rawCode.isEmpty) return _selectedActivityCode == defaultActivity;
        return rawCode == _selectedActivityCode;
      }).toList();
      _expandedIds.addAll(_all.map((row) => _s(row['id'])));
      _syncControllers();
      if (_parentFilter != null &&
          !_all.any((row) => _s(row['id']) == _parentFilter)) {
        _parentFilter = null;
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل فئات الأصناف: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importRealCategoryImages() async {
    if (_db == null || (_company ?? '').isEmpty) {
      setState(() => _error = 'حدد الشركة وسجل الدخول أولًا.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('استيراد صور حقيقية للفئات'),
        content: const Text('سيتم البحث عن صور فوتوغرافية مناسبة من Wikimedia Commons لكل فئات جميع الأنشطة، وحفظ الصورة ومصدرها وبيانات الترخيص داخل قاعدة البيانات. الصور الحقيقية الموجودة لن يتم استبدالها. قد تستغرق العملية وقتًا حسب عدد الفئات وتوفر الصور المطابقة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ابدأ الاستيراد')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _saving = true; _error = null; _message = 'جارٍ تجهيز استيراد الصور الحقيقية…'; });
    var imported = 0, notFound = 0, errors = 0, alreadyReal = 0, completed = 0, total = 0;
    try {
      final catalogRows = await _db!.from('erp_item_categories')
        .select('activity_code,category_code')
        .eq('company_id', _company!)
        .not('activity_code', 'is', null)
        .order('activity_code').order('category_code');
      final catalogGroups = <String,List<Map<String,dynamic>>>{};
      for (final raw in (catalogRows as List)) {
        final row = Map<String,dynamic>.from(raw);
        final code = _s(row['activity_code']);
        if (code.isEmpty) continue;
        catalogGroups.putIfAbsent(code, () => <Map<String,dynamic>>[]).add(row);
      }
      for (final entry in catalogGroups.entries) {
        final activityCode = entry.key;
        final count = entry.value.length;
        total += count;
        for (var offset = 0; offset < count; offset += 12) {
          if (!mounted) return;
          final response = await _db!.functions.invoke(
            'import-real-category-images',
            body: <String, dynamic>{
              'company_id': _company,
              'activity_code': activityCode,
              'offset': offset,
              'limit': 12,
            },
          );
          if (response.status < 200 || response.status >= 300) {
            throw StateError('تعذر استيراد صور نشاط $activityCode (HTTP ${response.status}): ${response.data}');
          }
          final data = response.data;
          if (data is Map) {
            imported += int.tryParse('${data['imported'] ?? 0}') ?? 0;
            notFound += int.tryParse('${data['not_found'] ?? 0}') ?? 0;
            errors += int.tryParse('${data['errors'] ?? 0}') ?? 0;
            alreadyReal += int.tryParse('${data['already_real'] ?? 0}') ?? 0;
          }
          completed += (count - offset) >= 12 ? 12 : (count - offset);
          if (mounted) setState(() => _message =
            'استيراد صور الفئات الحقيقية: $completed من $total فئة تم فحصها حتى الآن. تم استيراد $imported صورة فوتوغرافية؛ غير المتاحة $notFound.');
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      await _load();
      if (mounted) setState(() => _message =
        'انتهى فحص الفئات: تم استيراد $imported صورة حقيقية، و$alreadyReal صورة حقيقية كانت موجودة، و$notFound فئة لم يُعثر لها على صورة مناسبة، و$errors أخطاء استيراد. صور المصدر والترخيص محفوظة مع الصورة.');
    } catch (e) {
      if (mounted) setState(() => _error = 'توقف استيراد الصور الحقيقية: $e. يمكنك إعادة المحاولة؛ الصور التي تم حفظها لن تُستبدل.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _migrateImages() async {
    if (_db == null) {
      setState(() => _error = 'اتصال قاعدة البيانات غير متاح.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final response = await _db!.functions.invoke('migrate-catalog-images', body: <String, dynamic>{});
      if (response.status < 200 || response.status >= 300) {
        throw StateError('فشل نقل الصور (HTTP ${response.status}).');
      }
      final data = response.data;
      final migrated = data is Map ? (data['total_migrated'] ?? 0) : 0;
      await _load();
      if (mounted) setState(() => _message = 'تم حفظ ${migrated} صورة كبيانات فعلية داخل قاعدة البيانات. أعد فتح الشاشات التي تعرض الصور.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر نقل الصور إلى قاعدة البيانات: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _syncControllers() {
    final keep = <String>{};
    for (final row in _all) {
      final id = _s(row['id']); keep.add(id);
      _ar.putIfAbsent(id, () => TextEditingController());
      _en.putIfAbsent(id, () => TextEditingController());
      _ar[id]!.text = _s(row['category_name']);
      _en[id]!.text = _s(row['category_name_en']);
    }
    for (final id in _ar.keys.where((id) => !keep.contains(id)).toList()) {
      _ar.remove(id)?.dispose(); _en.remove(id)?.dispose();
      _imageBytes.remove(id); _imageNames.remove(id);
    }
  }

  bool _isDescendantOf(Map<String,dynamic> row, String ancestorId) {
    var parentId = _s(row['parent_id']);
    final visited = <String>{};
    while (parentId.isNotEmpty && visited.add(parentId)) {
      if (parentId == ancestorId) return true;
      Map<String,dynamic>? parent;
      for (final candidate in _all) { if (_s(candidate['id']) == parentId) { parent = candidate; break; } }
      parentId = parent == null ? '' : _s(parent['parent_id']);
    }
    return false;
  }

  int _rowLevel(Map<String,dynamic> row) {
    if (row['parent_id'] == null) return 0;
    final p = _parentOf(row);
    if (p == null || p['parent_id'] == null) return 1;
    return 2;
  }

  Future<void> _add({String? parentIdOverride}) async {
    if (_company == null || _company!.isEmpty) { setState(() => _error = 'حدد الشركة أولًا.'); return; }
    String? parentId = parentIdOverride;
    if (parentId == null && _level == 1 && _parents.isNotEmpty) parentId = _parentFilter ?? _s(_parents.first['id']);
    if (parentId == null && _level == 2 && _secondaryParents.isNotEmpty) {
      final candidates = _secondaryParents.where((r) => _parentFilter == null || _s(_parentOf(r)?['id']) == _parentFilter).toList();
      if (candidates.isNotEmpty) parentId = _s(candidates.first['id']);
    }
    if (_level > 0 && parentId == null) {
      setState(() => _error = _level == 1 ? 'أضف فئة رئيسية أولًا.' : 'أضف فئة فرعية أولًا.');
      return;
    }
    final siblingsForNew = _codingCategories.where((r) =>
      _s(r['parent_id']) == (parentId ?? '')).toList();
    final next = siblingsForNew.length + 1;
    final pathSegments = <String>[];
    String? ancestorId = parentId;
    while (ancestorId != null && ancestorId.isNotEmpty) {
      Map<String,dynamic>? ancestor;
      for (final candidate in _codingCategories) {
        if (_s(candidate['id']) == ancestorId) { ancestor = candidate; break; }
      }
      if (ancestor == null) break;
      final ancestorParentId = _s(ancestor['parent_id']);
      final ancestorSiblings = _codingCategories.where((r) =>
        _s(r['parent_id']) == ancestorParentId).toList();
      ancestorSiblings.sort((a,b) {
        final aDate = DateTime.tryParse(_s(a['created_at']));
        final bDate = DateTime.tryParse(_s(b['created_at']));
        if (aDate != null && bDate != null) {
          final byDate = aDate.compareTo(bDate);
          return byDate != 0 ? byDate : _s(a['id']).compareTo(_s(b['id']));
        }
        if (aDate != null) return -1;
        if (bDate != null) return 1;
        return _codingCategories.indexOf(a).compareTo(_codingCategories.indexOf(b));
      });
      final ancestorRank = ancestorSiblings.indexWhere((r) => _s(r['id']) == ancestorId) + 1;
      if (ancestorRank < 1) break;
      pathSegments.insert(0, ancestorRank.toString().padLeft(2,'0'));
      ancestorId = ancestorParentId.isEmpty ? null : ancestorParentId;
    }
    pathSegments.add(next.toString().padLeft(2,'0'));
    final hierarchicalDigits = pathSegments.join();
    final draft = <String,dynamic>{
      'id':'draft-${DateTime.now().microsecondsSinceEpoch}', 'company_id':_company, 'activity_code':_selectedActivityCode,
      'category_code':'$_selectedActivityCode$hierarchicalDigits', 'category_name':'','category_name_en':'',
      'parent_id':parentId,'is_active':true,'show_in_app':true,'image_url':null,'image_data':null,'image_mime_type':null,'_draft':true,
    };
    setState(() { _editing = true; _all.add(draft); _selectedId = _s(draft['id']); _expandedIds.add(_s(parentId)); _expandedIds.add(_s(draft['id'])); _syncControllers(); });
  }

  Future<void> _pickImage(Map<String,dynamic> row, {ImageSource? source}) async {
    final id = _s(row['id']);
    try {
      source ??= await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('اختيار صورة من الجهاز'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('تصوير صورة للفئة'), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ])));
      if (source == null) return;
      final file = await _picker.pickImage(source: source, imageQuality: 82, maxWidth: 1400);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() { _imageBytes[id] = bytes; _imageNames[id] = file.name; _selectedId = id; });
    } catch (e) { setState(() => _error = 'تعذر اختيار صورة الفئة: $e'); }
  }

  String _byteaHex(Uint8List bytes) =>
      '\\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Uint8List? _decodeBytea(dynamic value) {
    final raw = _s(value);
    final prefixLength = raw.startsWith(r'\\x') ? 3 : raw.startsWith(r'\x') ? 2 : 0;
    if (prefixLength == 0 || raw.length <= prefixLength || (raw.length - prefixLength).isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        (raw.length - prefixLength) ~/ 2,
        (i) => int.parse(raw.substring(prefixLength + i * 2, prefixLength + 2 + i * 2), radix: 16),
      ));
    } catch (_) { return null; }
  }

  bool get _showCategoryImages => ErpScreenLayoutProfiles.forScreen('فئات الأصناف')['showImages'] as bool? ?? true;

  Uint8List? _categoryImageBytes(Map<String,dynamic> row) =>
      _imageBytes[_s(row['id'])] ?? _decodeBytea(row['image_data']);

  Widget _imagePreview(Map<String,dynamic> row, {double size = 54}) {
    final bytes = _categoryImageBytes(row);
    final attribution = _s(row['image_attribution']).trim();
    final source = _s(row['image_source_url']).trim();
    return Tooltip(message: attribution.isNotEmpty ? attribution : source.isNotEmpty ? source : 'صورة الفئة', child: Container(
      width: size, height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFD8CBE7)),
      ),
      child: bytes != null && bytes.isNotEmpty
          ? (_s(row['image_mime_type']) == 'image/svg+xml'
              ? SvgPicture.memory(bytes, fit: BoxFit.contain, width: size, height: size)
              : Image.memory(bytes, fit: BoxFit.cover, width: size, height: size,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.black38)))
          : const Icon(Icons.category_outlined, color: Color(0xFF9A86B5), size: 25),
    ));
  }

  void _removeImage(Map<String,dynamic> row) {
    final id = _s(row['id']);
    setState(() {
      _imageBytes.remove(id);
      _imageNames.remove(id);
      row['image_data'] = null;
      row['image_mime_type'] = null;
      row['image_url'] = null;
      row['image_source_url'] = null;
      row['image_attribution'] = null;
      row['_remove_image'] = true;
      _selectedId = id;
    });
  }

  String? _imageMime(Map<String,dynamic> row) {
    final name = (_imageNames[_s(row['id'])] ?? '').toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    final existing = _s(row['image_mime_type']);
    return existing.isEmpty ? null : existing;
  }

  Future<void> _save() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا قبل حفظ أي تغييرات.'); return; }
    if (_db == null || _company == null) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      for (final row in _all.toList()) {
        final id = _s(row['id']);
        final ar = (_ar[id]?.text ?? _s(row['category_name'])).trim();
        final en = (_en[id]?.text ?? _s(row['category_name_en'])).trim();
        if (ar.isEmpty) { if (row['_draft'] == true) continue; throw StateError('اسم الفئة العربية مطلوب للكود ${row['category_code']}.'); }
        final normalizedName = ar.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        final duplicate = _all.any((other) => _s(other['id']) != id &&
          (_ar[_s(other['id'])]?.text ?? _s(other['category_name'])).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim() == normalizedName);
        if (duplicate) throw StateError('اسم الفئة «$ar» مستخدم بالفعل في مستوى فئة آخر أو داخل المستوى نفسه.');
        final rowLevel = _rowLevel(row);
        if (rowLevel == 1 && (_s(row['parent_id']).isEmpty || !_parents.any((p) => _s(p['id']) == _s(row['parent_id'])))) {
          throw StateError('اختر الفئة الرئيسية للفئة الفرعية ${row['category_code']}.');
        }
        if (rowLevel == 2) {
          final selectedParent = _parentOf(row);
          if (selectedParent == null || selectedParent['parent_id'] == null) {
            throw StateError('اختر الفئة الفرعية للفئة الثانوية ${row['category_code']}.');
          }
          final mainId = _s(row['_main_parent_id']);
          if (mainId.isNotEmpty && _s(selectedParent['parent_id']) != mainId) {
            throw StateError('الفئة الفرعية المختارة لا تتبع الفئة الرئيسية المحددة.');
          }
        }
        final selectedBytes = _imageBytes[id];
        final payload = <String,dynamic>{
          'company_id':_company, 'activity_code':_s(row['activity_code']).isEmpty ? _selectedActivityCode : _s(row['activity_code']), 'category_code':row['_draft'] == true ? '' : _s(row['category_code']), 'category_name':ar,
          'category_name_en':en, 'parent_id':row['parent_id'], 'is_active':row['is_active'] == true,
          'show_in_app':row['show_in_app'] == true,
          'image_url':(selectedBytes != null || row['_remove_image'] == true) ? null : row['image_url'],
          'image_source_url':(selectedBytes != null || row['_remove_image'] == true) ? null : row['image_source_url'],
          'image_attribution':(selectedBytes != null || row['_remove_image'] == true) ? null : row['image_attribution'],
          if (row['_remove_image'] == true) ...{'image_data':null, 'image_mime_type':null},
          if (selectedBytes != null && selectedBytes.isNotEmpty) ...{
            'image_data':_byteaHex(selectedBytes), 'image_mime_type':_imageMime(row),
          },
        };
        if (row['_draft'] == true) {
          final oldDraftId = id;
          final inserted = await _db!.from('erp_item_categories').insert(payload).select().single();
          final newId = _s(inserted['id']);
          row..['id']=newId..remove('_draft');
          for (final child in _all.where((candidate) => _s(candidate['parent_id']) == oldDraftId)) { child['parent_id'] = newId; }
        } else {
          await _db!.from('erp_item_categories').update(payload).eq('id',id).eq('company_id',_company!);
        }
      }
      await _load();
      if (mounted) setState(() { _editing = false; _message = 'تم حفظ فئات الأصناف في قاعدة البيانات.'; });
    } catch (e) { if (mounted) setState(() => _error = 'تعذر حفظ الفئات: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _delete() async {
    if (!_editing) { setState(() => _error = 'اضغط «تعديل» أولًا قبل حذف الفئات.'); return; }
    final id = _selectedId;
    if (id == null) { setState(() => _error = 'حدد فئة من الجريد أولًا.'); return; }
    Map<String, dynamic>? row;
    for (final candidate in _all) { if (_s(candidate['id']) == id) { row = candidate; break; } }
    if (row == null) return;
    final selectedRow = row;
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('تأكيد الحذف'), content: Text('حذف الفئة «${_s(selectedRow['category_name'])}»؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('No / لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Yes / نعم، احذف'))]));
    if (yes != true) return;
    try {
      if (selectedRow['_draft'] != true) await _db!.from('erp_item_categories').delete().eq('id',id).eq('company_id',_company!);
      setState(() { _all.removeWhere((r)=>_s(r['id'])==id); _selectedId=null; _syncControllers(); _message='تم حذف الفئة.'; });
    } catch(e) { setState(()=>_error='تعذر حذف الفئة: $e'); }
  }

  Future<void> _exportCategoriesExcel() async {
    try {
      final rows = _all.where((r) => r['_draft'] != true).map((r) => <String, dynamic>{
        'كود الفئة': r['category_code'], 'اسم الفئة': r['category_name'],
        'معرف الفئة الأب': r['parent_id'],
        'كود النشاط': r['activity_code'], 'نشطة': r['is_active'] == true ? 'نعم' : 'لا',
        'تظهر بالتطبيق': r['show_in_app'] == true ? 'نعم' : 'لا',
      }).toList();
      await exportErpExcel(fileName: 'silsila_item_categories', sheets: {'فئات الأصناف': rows}, columns: {'فئات الأصناف': {for (final key in ['كود الفئة','اسم الفئة','معرف الفئة الأب','كود النشاط','نشطة','تظهر بالتطبيق']) key: key}});
      if (mounted) setState(() => _message = 'تم تصدير ${rows.length} فئة من النشاط المحدد.');
    } catch (e) { if (mounted) setState(() => _error = 'تعذر تصدير فئات الأصناف: $e'); }
  }

  Widget _task(String label, IconData icon, VoidCallback? action) =>
    SizedBox(width:112, child: ErpQuickTaskButton(label:label,icon:icon,onPressed:action,compact:true));

  List<Map<String,dynamic>> _childrenOf(Map<String,dynamic> parent) =>
      _all.where((r) => _s(r['parent_id']) == _s(parent['id'])).toList()
        ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));

  bool _matchesSearch(Map<String,dynamic> row) {
    if (_searchQuery.isEmpty) return true;
    return _s(row['category_code']).toLowerCase().contains(_searchQuery) ||
      _s(row['category_name']).toLowerCase().contains(_searchQuery) ||
      _s(row['category_name_en']).toLowerCase().contains(_searchQuery);
  }

  bool _branchMatches(Map<String,dynamic> row) {
    if (_matchesSearch(row)) return true;
    return _childrenOf(row).any(_branchMatches);
  }

  Widget _treeNode(Map<String,dynamic> row, int depth) {
    final id = _s(row['id']);
    final children = _childrenOf(row);
    final expanded = _expandedIds.contains(id);
    final ar = _ar.putIfAbsent(id, () => TextEditingController(text: _s(row['category_name'])));
    final en = _en.putIfAbsent(id, () => TextEditingController(text: _s(row['category_name_en'])));
    final level = _rowLevel(row);
    final active = row['is_active'] == true;
    final visible = row['show_in_app'] == true;
    return ErpCatalogTreeCard(
      depth: depth,
      selected: _selectedId == id,
      backgroundColor: level == 0 ? const Color(0xFFEDE1F8) : level == 1 ? const Color(0xFFFFE4BE) : const Color(0xFFFFDDF3),
      selectedColor: const Color(0xFFF0E7FA),
      borderColor: const Color(0xFFE8E1EF),
      selectedBorderColor: _catPurple,
      onTap: () => setState(() => _selectedId = id),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 34, child: IconButton(
              padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
              tooltip: expanded ? 'طي الفئات التابعة' : 'عرض الفئات التابعة',
              onPressed: children.isEmpty ? null : () => setState(() {
                if (expanded) { _expandedIds.remove(id); } else { _expandedIds.add(id); }
              }),
              icon: Icon(children.isEmpty ? Icons.circle_outlined : expanded ? Icons.keyboard_arrow_down : Icons.chevron_left, color: _catPurple),
            )),
            SizedBox(width: 105, child: Text(_s(row['category_code']), overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _catPurple, fontSize: 12))),
            Expanded(child: TextField(controller: ar, enabled: _editing,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'اسم الفئة عربي'),
              onTap: () => setState(() => _selectedId = id))),
            const SizedBox(width: 8),
            if (_showCategoryImages) _imagePreview(row, size: 48),
          ]),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 34, top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4, runSpacing: 2,
              children: [
                Tooltip(message: 'نشط', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(shape: const CircleBorder(), value: active, activeColor: _catPurple,
                    visualDensity: VisualDensity.compact,
                    onChanged: _editing ? (v) => setState(() => row['is_active'] = v == true) : null),
                  const Text('نشط', style: TextStyle(fontSize: 11)),
                ])),
                Tooltip(message: 'ظهور في التطبيق', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(shape: const CircleBorder(), value: visible, activeColor: _catOrange,
                    visualDensity: VisualDensity.compact,
                    onChanged: _editing ? (v) => setState(() => row['show_in_app'] = v == true) : null),
                  const Text('في التطبيق', style: TextStyle(fontSize: 11)),
                ])),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'استيراد صورة حقيقية من الجهاز',
                  onPressed: _editing ? () => _pickImage(row, source: ImageSource.gallery) : null,
                  icon: const Icon(Icons.photo_library_outlined, color: _catPurple)),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'التقاط صورة بالكاميرا',
                  onPressed: _editing ? () => _pickImage(row, source: ImageSource.camera) : null,
                  icon: const Icon(Icons.photo_camera_outlined, color: _catOrange)),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'حذف الصورة',
                  onPressed: _editing && _categoryImageBytes(row) != null ? () => _removeImage(row) : null,
                  icon: const Icon(Icons.hide_image_outlined, color: Colors.redAccent)),
                if (level < 2) IconButton(visualDensity: VisualDensity.compact,
                  tooltip: level == 0 ? 'إضافة فئة فرعية' : 'إضافة فئة ثانوية',
                  onPressed: _saving ? null : () { setState(() { _level = level + 1; _editing = true; }); _add(parentIdOverride: id); },
                  icon: const Icon(Icons.add_circle_outline, color: _catPurple)),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'تحديد الفئة',
                  onPressed: () => setState(() => _selectedId = id),
                  icon: Icon(Icons.radio_button_checked, color: _selectedId == id ? _catPurple : Colors.black26)),
              ],
            ),
          ),
          if (children.isNotEmpty)
            Padding(padding: const EdgeInsetsDirectional.only(start: 42, top: 1),
              child: Text('${children.length} فئة تابعة • ${level == 0 ? 'رئيسية' : level == 1 ? 'فرعية' : 'ثانوية'}',
                style: const TextStyle(fontSize: 10, color: Colors.black54))),
          if (expanded) ...children.where(_branchMatches).map((child) => _treeNode(child, depth + 1)),
        ]),
    );
  }

  @override
  Future<void> _showCategoryPreview(Map<String, dynamic> row) async {
    final parent = _parentOf(row);
    Map<String, String>? activity;
    for (final candidate in _activities) {
      if (candidate['code'] == _s(row['activity_code'])) { activity = candidate; break; }
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة الفئة'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _imagePreview(row, size: 112),
              const SizedBox(height: 12),
              _previewLine('الكود', _s(row['category_code'])),
              _previewLine('اسم الفئة', _s(row['category_name'])),
              _previewLine('نوع النشاط', activity?['name'] ?? _s(row['activity_code'])),
              _previewLine('الفئة الأب', parent == null ? '—' : _s(parent['category_name'])),
              _previewLine('الحالة', row['is_active'] == true ? 'نشطة' : 'غير نشطة'),
              _previewLine('الظهور في التطبيق', row['show_in_app'] == true ? 'نعم' : 'لا'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  Widget _previewLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 112, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: _catPurple))),
      Expanded(child: Text(value.isEmpty ? '—' : value, textAlign: TextAlign.start)),
    ]),
  );

  Future<void> _deleteCategoryRow(Map<String, dynamic> row) async {
    if (!_editing) {
      setState(() => _error = 'اضغط «تعديل» أولًا قبل حذف الفئات.');
      return;
    }
    setState(() => _selectedId = _s(row['id']));
    await _delete();
  }

  Future<void> _recodeCategories() async {
    if (_db == null || (_company ?? '').isEmpty) {
      setState(() => _error = 'حدد الشركة أولًا.');
      return;
    }
    if (_editing || _saving) {
      setState(() => _error = 'احفظ التعديلات الحالية أو ألغِها قبل إعادة التكويد.');
      return;
    }
    final rowsById = <String, Map<String, dynamic>>{
      for (final row in _companyCategories) if (_s(row['id']).isNotEmpty) _s(row['id']): row,
    };
    for (final row in _all) { if (_s(row['id']).isNotEmpty) rowsById[_s(row['id'])] = row; }
    final rows = rowsById.values.where((row) => row['_draft'] != true).toList();
    if (_all.any((row) => row['_draft'] == true)) {
      setState(() => _error = 'احفظ الفئات الجديدة أولًا قبل إعادة التكويد.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = 'جارٍ إعادة تكويد الفئات حسب السياسات الهرمية…'; });
    try {
      final policyRow = await _db!.from('erp_program_policies')
          .select('policy_value')
          .eq('company_id', _company!)
          .eq('policy_key', 'code_generation_registry')
          .maybeSingle();
      final rawPolicy = policyRow?['policy_value'];
      final policy = rawPolicy is String ? jsonDecode(rawPolicy) : rawPolicy;
      final segments = policy is Map ? policy['category_segments'] : null;
      final mainDigits = int.tryParse('${segments is Map ? segments['main'] : ''}') ?? 2;
      final subDigits = int.tryParse('${segments is Map ? segments['sub'] : ''}') ?? 2;
      final secondaryDigits = int.tryParse('${segments is Map ? segments['secondary'] : ''}') ?? 2;
      if (mainDigits != 2 || subDigits != 2 || secondaryDigits != 2) {
        throw StateError('سياسة تكويد الفئات الحالية لا تطابق بنية الكود الهرمي المعتمدة (2+2+2).');
      }
      // Recode every activity in the company catalog, not just the activity
      // currently selected in the screen. This is essential when a root category
      // is reassigned to another activity.
      List<Map<String, dynamic>> ordered(List<Map<String, dynamic>> source) {
        final result = source.toList();
        result.sort((a, b) {
          final byCode = _s(a['category_code']).compareTo(_s(b['category_code']));
          return byCode != 0 ? byCode : _s(a['id']).compareTo(_s(b['id']));
        });
        return result;
      }
      Future<void> saveCode(Map<String, dynamic> row, String code) async {
        if (_s(row['category_code']) == code) return;
        await _db!.from('erp_item_categories')
            .update({'category_code': code})
            .eq('id', _s(row['id']))
            .eq('company_id', _company!);
        row['category_code'] = code;
      }
      String segment(int index) => index.toString().padLeft(2, '0');

      final roots = ordered(rows.where((row) => row['parent_id'] == null).toList());
      final rootsByActivity = <String, List<Map<String, dynamic>>>{};
      for (final root in roots) {
        final activityCode = _normalizeActivityCode(_s(root['activity_code']));
        if (!RegExp(r'^\\d{2}
      var subCount = 0;
      final subsByRoot = <String, List<Map<String, dynamic>>>{};
      for (final root in roots) {
        final rootId = _s(root['id']);
        final subs = ordered(rows.where((row) => _s(row['parent_id']) == rootId).toList());
        if (subs.length > 99) throw StateError('الفئة «${_s(root['category_name'])}» لديها أكثر من 99 فئة فرعية.');
        subsByRoot[rootId] = subs;
        for (var i = 0; i < subs.length; i++) {
          await saveCode(subs[i], _s(root['category_code']) + segment(i + 1));
          subCount++;
        }
      }

      var secondaryCount = 0;
      for (final subs in subsByRoot.values) {
        for (final sub in subs) {
          final subId = _s(sub['id']);
          final secondary = ordered(rows.where((row) => _s(row['parent_id']) == subId).toList());
          if (secondary.length > 99) throw StateError('الفئة «${_s(sub['category_name'])}» لديها أكثر من 99 فئة ثانوية.');
          for (var i = 0; i < secondary.length; i++) {
            await saveCode(secondary[i], _s(sub['category_code']) + segment(i + 1));
            secondaryCount++;
          }
        }
      }
      await _load();
      if (mounted) {
        setState(() {
          _editing = false;
          _message = 'اكتملت إعادة التكويد دون حذف أي سجل: ${roots.length} رئيسية، ${subCount} فرعية، ${secondaryCount} ثانوية.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذرت إعادة تكويد الفئات: $error');
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _add, save: _save);
    final activityFieldWidth = (MediaQuery.sizeOf(context).width * 0.25)
        .clamp(180.0, 320.0).toDouble();
    final visibleRows = _all.where((row) {
      if (_rowLevel(row) != _catalogTab || !_matchesSearch(row)) return false;
      if (_catalogTab >= 1 && _mainCategoryFilter != null) {
        final mainId = _catalogTab == 1 ? _s(row['parent_id']) : _s(_parentOf(row)?['parent_id']);
        if (mainId != _mainCategoryFilter) return false;
      }
      if (_catalogTab == 2 && _subCategoryFilter != null && _s(row['parent_id']) != _subCategoryFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    final mainFilterOptions = _all.where((row) => _rowLevel(row) == 0).toList()
      ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    final subFilterOptions = _all.where((row) => _rowLevel(row) == 1 &&
      (_mainCategoryFilter == null || _s(row['parent_id']) == _mainCategoryFilter)).toList()
      ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    final levelName = _catalogTab == 1 ? 'فرعية' : _catalogTab == 2 ? 'ثانوية' : 'رئيسية';
    Map<String, dynamic>? selectedRow;
    for (final row in visibleRows) {
      if (_s(row['id']) == _selectedId) { selectedRow = row; break; }
    }
    final previewRow = selectedRow;
    final actions = <Widget>[
      _task('تحديث', Icons.refresh_rounded, _loading || _saving ? null : _load),
      _task('إضافة', Icons.add_circle_outline_rounded, _saving || _editing ? null : _add),
      _task('حفظ', Icons.save_outlined, _saving || !_editing ? null : _save),
      _task('تعديل', Icons.edit_outlined, _saving || _editing || _all.isEmpty ? null : () => setState(() => _editing = true)),
      _task('حذف', Icons.delete_outline_rounded, _saving || !_editing ? null : _delete),
      _task('معاينة', Icons.preview_outlined, previewRow == null ? null : () => _showCategoryPreview(previewRow)),
      _task('إعادة تكويد', Icons.numbers_rounded, _saving || _editing ? null : _recodeCategories),
      _task('تصدير Excel', Icons.file_download_outlined, _saving ? null : _exportCategoriesExcel),
      _task('نقل الصور للقاعدة', Icons.cloud_download_outlined, _saving || _loading ? null : _migrateImages),
      _task('صور حقيقية', Icons.photo_library_outlined, _saving || _loading ? null : _importRealCategoryImages),
    ];
    final tabs = widget.hideHeaderAndTabs
        ? const <String>[]
        : const ['الفئة الرئيسية', 'الفئة الفرعية', 'الفئة الثانوية', 'البراندات/الماركات'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ErpScreenFrame(
        title: 'فئات الأصناف',
        profileKey: 'فئات الأصناف',
        showFrameTitle: !widget.hideHeaderAndTabs,
        subtitle: 'إدارة الفئات الرئيسية والفرعية والثانوية والبراندات/الماركات',
        icon: Icons.account_tree_outlined,
        tabs: tabs,
        selectedTab: _catalogTab,
        onTabSelected: (tab) {
          if (_saving) return;
          setState(() {
            _catalogTab = tab;
            if (tab < 3) {
              _level = tab;
              _parentFilter = null;
              _selectedId = null;
            }
          });
        },
        actions: actions,
        applyContentWidth: false,
        padding: const EdgeInsets.all(4),
        child: _catalogTab == 3
            ? ErpBrandsTab(key: const ValueKey('brands-tab'), companyId: _company ?? '')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 58,
                          child: Text('نوع النشاط', style: TextStyle(
                            fontWeight: FontWeight.w800, color: _catPurple,
                          )),
                        ),
                        SizedBox(
                          width: activityFieldWidth,
                          child: DropdownButtonFormField<String>(
                            itemHeight: 40,
                            value: _selectedActivityCode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            ),
                            items: _activities.map((activity) => DropdownMenuItem<String>(
                              value: activity['code'],
                              child: Text('${activity['code']} - ${activity['name']}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: _editing || _loading || _saving ? null : (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedActivityCode = value;
                                _parentFilter = null;
                                _selectedId = null;
                              });
                              _load();
                            },
                          ),
                        ),
                        if (_catalogTab >= 1) ...[
                          const SizedBox(width: 8),
                          const Text('فئة رئيسية', style: TextStyle(fontWeight: FontWeight.w800, color: _catPurple)),
                          SizedBox(width: 180, child: DropdownButtonFormField<String?>(
                            value: _mainCategoryFilter, itemHeight: 40, isExpanded: true,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
                            items: [const DropdownMenuItem<String?>(value: null, child: Text('الكل')), ...mainFilterOptions.map((p) => DropdownMenuItem<String?>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis)))],
                            onChanged: _loading || _saving ? null : (value) => setState(() { _mainCategoryFilter = value; _subCategoryFilter = null; }),
                          )),
                        ],
                        if (_catalogTab == 2) ...[
                          const SizedBox(width: 8),
                          const Text('فئة فرعية', style: TextStyle(fontWeight: FontWeight.w800, color: _catPurple)),
                          SizedBox(width: 180, child: DropdownButtonFormField<String?>(
                            value: _subCategoryFilter, itemHeight: 40, isExpanded: true,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
                            items: [const DropdownMenuItem<String?>(value: null, child: Text('الكل')), ...subFilterOptions.map((p) => DropdownMenuItem<String?>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis)))],
                            onChanged: _loading || _saving ? null : (value) => setState(() => _subCategoryFilter = value),
                          )),
                        ],
                        const SizedBox(width: 10),
                        Text('الفئات ${levelName == 'رئيسية' ? 'الرئيسية' : levelName == 'فرعية' ? 'الفرعية' : 'الثانوية'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _catPurple)),
                        const Spacer(),
                        Text('${visibleRows.length} فئة',
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(padding: const EdgeInsets.all(7), child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12))),
                  if (_message != null)
                    Padding(padding: const EdgeInsets.all(7), child: Text(_message!,
                      style: const TextStyle(color: Color(0xFF3E007D), fontSize: 11))),
                  const SizedBox(height: 3),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE4DDED)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ErpStandardDataTable(
                                headingColor: const Color(0xFFF1EAF9),
                                rowHeight: 40,
                                showCheckboxColumn: false,
                                columns: [
                                  const DataColumn(label: Text('م')),
                                  DataColumn(label: Text('كود فئة $levelName')),
                                  const DataColumn(label: Text('اسم الفئة')),
                                  if (_catalogTab == 0) const DataColumn(label: Text('نوع النشاط')),
                                  if (_catalogTab == 1) const DataColumn(label: Text('فئة رئيسية')),
                                  if (_catalogTab == 2) const DataColumn(label: Text('فئة فرعية')),
                                  const DataColumn(label: Text('معاينة')),
                                  const DataColumn(label: Text('صورة الفئة')),
                                  const DataColumn(label: Text('نشط')),
                                  const DataColumn(label: Text('يظهر في التطبيق')),
                                  const DataColumn(label: Text('حذف')),
                                ],
                                rows: visibleRows.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final row = entry.value;
                                  final id = _s(row['id']);
                                  return DataRow(
                                    selected: _selectedId == id,
                                    onSelectChanged: (_) => setState(() => _selectedId = id),
                                    cells: [
                                      DataCell(SizedBox(width: 38, child: Text('${i + 1}',
                                        textAlign: TextAlign.center))),
                                      DataCell(SizedBox(width: 112, child: Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Text(_s(row['category_code']),
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: _catPurple)),
                                      ))),
                                      DataCell(SizedBox(
                                        width: 220,
                                        height: 36,
                                        child: Center(child: TextField(
                                          controller: _ar.putIfAbsent(id,
                                            () => TextEditingController(text: _s(row['category_name']))),
                                          enabled: _editing,
                                          textAlignVertical: TextAlignVertical.center,
                                          decoration: const InputDecoration(
                                            isDense: true, border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          ),
                                        )),
                                      )),
                                      if (_catalogTab == 0) DataCell(SizedBox(width: 190, child: DropdownButtonFormField<String>(
                                        value: _activities.any((a) => a['code'] == _s(row['activity_code'])) ? _s(row['activity_code']) : _selectedActivityCode,
                                        itemHeight: 40, isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 3)),
                                        items: _activities.map((a) => DropdownMenuItem<String>(value: a['code'], child: Text('${a['code']} - ${a['name']}', overflow: TextOverflow.ellipsis))).toList(),
                                        onChanged: _editing ? (value) { if (value == null) return; setState(() { row['activity_code'] = value; for (final child in _all.where((r) => _isDescendantOf(r, id))) { child['activity_code'] = value; } }); } : null,
                                      ))),
                                      if (_catalogTab == 1) DataCell(SizedBox(width: 190, child: DropdownButtonFormField<String>(
                                        value: _parents.any((p) => _s(p['id']) == _s(row['parent_id'])) ? _s(row['parent_id']) : null,
                                        itemHeight: 40, isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 3)),
                                        items: _parents.map((p) => DropdownMenuItem<String>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis))).toList(),
                                        onChanged: _editing ? (value) { if (value == null) return; setState(() { row['parent_id'] = value; final activity = _s(_all.firstWhere((p) => _s(p['id']) == value)['activity_code']); row['activity_code'] = activity; for (final child in _all.where((r) => _isDescendantOf(r, id))) { child['activity_code'] = activity; } }); } : null,
                                      ))),
                                      if (_catalogTab == 2) DataCell(SizedBox(width: 190, child: DropdownButtonFormField<String>(
                                        value: _secondaryParents.any((p) => _s(p['id']) == _s(row['parent_id'])) ? _s(row['parent_id']) : null,
                                        itemHeight: 40, isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 3)),
                                        items: _secondaryParents.where((p) => _mainCategoryFilter == null || _s(_parentOf(p)?['id']) == _mainCategoryFilter).map((p) => DropdownMenuItem<String>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis))).toList(),
                                        onChanged: _editing ? (value) { if (value == null) return; setState(() { row['parent_id'] = value; row['activity_code'] = _s(_parentOf(_all.firstWhere((p) => _s(p['id']) == value))?['activity_code']); }); } : null,
                                      ))),
                                      DataCell(SizedBox(width: 72, child: IconButton(
                                        tooltip: 'معاينة بيانات الفئة',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _showCategoryPreview(row),
                                        icon: const Icon(Icons.visibility_outlined, size: 19, color: _catPurple),
                                      ))),
                                      DataCell(SizedBox(width: 142, child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _imagePreview(row, size: 34),
                                          IconButton(
                                            tooltip: 'اختيار صورة من الجهاز',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: _editing ? () => _pickImage(row, source: ImageSource.gallery) : null,
                                            icon: const Icon(Icons.photo_library_outlined, size: 18, color: _catPurple),
                                          ),
                                          IconButton(
                                            tooltip: 'تصوير صورة للفئة',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: _editing ? () => _pickImage(row, source: ImageSource.camera) : null,
                                            icon: const Icon(Icons.photo_camera_outlined, size: 18, color: _catOrange),
                                          ),
                                        ],
                                      ))),
                                      DataCell(Checkbox(
                                        shape: const CircleBorder(),
                                        visualDensity: VisualDensity.compact,
                                        value: row['is_active'] == true,
                                        activeColor: _catPurple,
                                        onChanged: _editing ? (value) => setState(() {
                                          row['is_active'] = value == true;
                                          if (value != true) row['show_in_app'] = false;
                                        }) : null,
                                      )),
                                      DataCell(Checkbox(
                                        shape: const CircleBorder(),
                                        visualDensity: VisualDensity.compact,
                                        value: row['show_in_app'] == true && row['is_active'] == true,
                                        activeColor: _catOrange,
                                        onChanged: _editing && row['is_active'] == true
                                            ? (value) => setState(() => row['show_in_app'] = value == true)
                                            : null,
                                      )),
                                      DataCell(IconButton(
                                        tooltip: 'حذف الفئة',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _editing ? () => _deleteCategoryRow(row) : null,
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318), size: 19),
                                      )),
                                    ],
                                  );
                                }).toList(),

                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

}
).hasMatch(activityCode)) {
          throw StateError('كود النشاط غير صالح للفئة الرئيسية «${_s(root['category_name'])}».');
        }
        rootsByActivity.putIfAbsent(activityCode, () => <Map<String, dynamic>>[]).add(root);
      }
      for (final entry in rootsByActivity.entries) {
        if (entry.value.length > 99) throw StateError('النشاط ${entry.key} يتجاوز 99 فئة رئيسية.');
        for (var i = 0; i < entry.value.length; i++) {
          await saveCode(entry.value[i], entry.key + segment(i + 1));
        }
      }

      var subCount = 0;
      final subsByRoot = <String, List<Map<String, dynamic>>>{};
      for (final root in roots) {
        final rootId = _s(root['id']);
        final subs = ordered(rows.where((row) => _s(row['parent_id']) == rootId).toList());
        if (subs.length > 99) throw StateError('الفئة «${_s(root['category_name'])}» لديها أكثر من 99 فئة فرعية.');
        subsByRoot[rootId] = subs;
        for (var i = 0; i < subs.length; i++) {
          await saveCode(subs[i], _s(root['category_code']) + segment(i + 1));
          subCount++;
        }
      }

      var secondaryCount = 0;
      for (final subs in subsByRoot.values) {
        for (final sub in subs) {
          final subId = _s(sub['id']);
          final secondary = ordered(rows.where((row) => _s(row['parent_id']) == subId).toList());
          if (secondary.length > 99) throw StateError('الفئة «${_s(sub['category_name'])}» لديها أكثر من 99 فئة ثانوية.');
          for (var i = 0; i < secondary.length; i++) {
            await saveCode(secondary[i], _s(sub['category_code']) + segment(i + 1));
            secondaryCount++;
          }
        }
      }
      await _load();
      if (mounted) {
        setState(() {
          _editing = false;
          _message = 'اكتملت إعادة التكويد دون حذف أي سجل: ${roots.length} رئيسية، ${subCount} فرعية، ${secondaryCount} ثانوية.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذرت إعادة تكويد الفئات: $error');
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _add, save: _save);
    final activityFieldWidth = (MediaQuery.sizeOf(context).width * 0.25)
        .clamp(180.0, 320.0).toDouble();
    final visibleRows = _all.where((row) {
      if (_rowLevel(row) != _catalogTab || !_matchesSearch(row)) return false;
      if (_catalogTab >= 1 && _mainCategoryFilter != null) {
        final mainId = _catalogTab == 1 ? _s(row['parent_id']) : _s(_parentOf(row)?['parent_id']);
        if (mainId != _mainCategoryFilter) return false;
      }
      if (_catalogTab == 2 && _subCategoryFilter != null && _s(row['parent_id']) != _subCategoryFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    final mainFilterOptions = _all.where((row) => _rowLevel(row) == 0).toList()
      ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    final subFilterOptions = _all.where((row) => _rowLevel(row) == 1 &&
      (_mainCategoryFilter == null || _s(row['parent_id']) == _mainCategoryFilter)).toList()
      ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    final levelName = _catalogTab == 1 ? 'فرعية' : _catalogTab == 2 ? 'ثانوية' : 'رئيسية';
    Map<String, dynamic>? selectedRow;
    for (final row in visibleRows) {
      if (_s(row['id']) == _selectedId) { selectedRow = row; break; }
    }
    final previewRow = selectedRow;
    final actions = <Widget>[
      _task('تحديث', Icons.refresh_rounded, _loading || _saving ? null : _load),
      _task('إضافة', Icons.add_circle_outline_rounded, _saving || _editing ? null : _add),
      _task('حفظ', Icons.save_outlined, _saving || !_editing ? null : _save),
      _task('تعديل', Icons.edit_outlined, _saving || _editing || _all.isEmpty ? null : () => setState(() => _editing = true)),
      _task('حذف', Icons.delete_outline_rounded, _saving || !_editing ? null : _delete),
      _task('معاينة', Icons.preview_outlined, previewRow == null ? null : () => _showCategoryPreview(previewRow)),
      _task('إعادة تكويد', Icons.numbers_rounded, _saving || _editing ? null : _recodeCategories),
      _task('تصدير Excel', Icons.file_download_outlined, _saving ? null : _exportCategoriesExcel),
      _task('نقل الصور للقاعدة', Icons.cloud_download_outlined, _saving || _loading ? null : _migrateImages),
      _task('صور حقيقية', Icons.photo_library_outlined, _saving || _loading ? null : _importRealCategoryImages),
    ];
    final tabs = widget.hideHeaderAndTabs
        ? const <String>[]
        : const ['الفئة الرئيسية', 'الفئة الفرعية', 'الفئة الثانوية', 'البراندات/الماركات'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ErpScreenFrame(
        title: 'فئات الأصناف',
        profileKey: 'فئات الأصناف',
        showFrameTitle: !widget.hideHeaderAndTabs,
        subtitle: 'إدارة الفئات الرئيسية والفرعية والثانوية والبراندات/الماركات',
        icon: Icons.account_tree_outlined,
        tabs: tabs,
        selectedTab: _catalogTab,
        onTabSelected: (tab) {
          if (_saving) return;
          setState(() {
            _catalogTab = tab;
            if (tab < 3) {
              _level = tab;
              _parentFilter = null;
              _selectedId = null;
            }
          });
        },
        actions: actions,
        applyContentWidth: false,
        padding: const EdgeInsets.all(4),
        child: _catalogTab == 3
            ? ErpBrandsTab(key: const ValueKey('brands-tab'), companyId: _company ?? '')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 58,
                          child: Text('نوع النشاط', style: TextStyle(
                            fontWeight: FontWeight.w800, color: _catPurple,
                          )),
                        ),
                        SizedBox(
                          width: activityFieldWidth,
                          child: DropdownButtonFormField<String>(
                            itemHeight: 40,
                            value: _selectedActivityCode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            ),
                            items: _activities.map((activity) => DropdownMenuItem<String>(
                              value: activity['code'],
                              child: Text('${activity['code']} - ${activity['name']}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: _editing || _loading || _saving ? null : (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedActivityCode = value;
                                _parentFilter = null;
                                _selectedId = null;
                              });
                              _load();
                            },
                          ),
                        ),
                        if (_catalogTab >= 1) ...[
                          const SizedBox(width: 8),
                          const Text('فئة رئيسية', style: TextStyle(fontWeight: FontWeight.w800, color: _catPurple)),
                          SizedBox(width: 180, child: DropdownButtonFormField<String?>(
                            value: _mainCategoryFilter, itemHeight: 40, isExpanded: true,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
                            items: [const DropdownMenuItem<String?>(value: null, child: Text('الكل')), ...mainFilterOptions.map((p) => DropdownMenuItem<String?>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis)))],
                            onChanged: _loading || _saving ? null : (value) => setState(() { _mainCategoryFilter = value; _subCategoryFilter = null; }),
                          )),
                        ],
                        if (_catalogTab == 2) ...[
                          const SizedBox(width: 8),
                          const Text('فئة فرعية', style: TextStyle(fontWeight: FontWeight.w800, color: _catPurple)),
                          SizedBox(width: 180, child: DropdownButtonFormField<String?>(
                            value: _subCategoryFilter, itemHeight: 40, isExpanded: true,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
                            items: [const DropdownMenuItem<String?>(value: null, child: Text('الكل')), ...subFilterOptions.map((p) => DropdownMenuItem<String?>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis)))],
                            onChanged: _loading || _saving ? null : (value) => setState(() => _subCategoryFilter = value),
                          )),
                        ],
                        const SizedBox(width: 10),
                        Text('الفئات ${levelName == 'رئيسية' ? 'الرئيسية' : levelName == 'فرعية' ? 'الفرعية' : 'الثانوية'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _catPurple)),
                        const Spacer(),
                        Text('${visibleRows.length} فئة',
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(padding: const EdgeInsets.all(7), child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12))),
                  if (_message != null)
                    Padding(padding: const EdgeInsets.all(7), child: Text(_message!,
                      style: const TextStyle(color: Color(0xFF3E007D), fontSize: 11))),
                  const SizedBox(height: 3),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE4DDED)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ErpStandardDataTable(
                                headingColor: const Color(0xFFF1EAF9),
                                rowHeight: 40,
                                showCheckboxColumn: false,
                                columns: [
                                  const DataColumn(label: Text('م')),
                                  DataColumn(label: Text('كود فئة $levelName')),
                                  const DataColumn(label: Text('اسم الفئة')),
                                  if (_catalogTab == 0) const DataColumn(label: Text('نوع النشاط')),
                                  if (_catalogTab == 1) const DataColumn(label: Text('فئة رئيسية')),
                                  if (_catalogTab == 2) const DataColumn(label: Text('فئة فرعية')),
                                  const DataColumn(label: Text('معاينة')),
                                  const DataColumn(label: Text('صورة الفئة')),
                                  const DataColumn(label: Text('نشط')),
                                  const DataColumn(label: Text('يظهر في التطبيق')),
                                  const DataColumn(label: Text('حذف')),
                                ],
                                rows: visibleRows.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final row = entry.value;
                                  final id = _s(row['id']);
                                  return DataRow(
                                    selected: _selectedId == id,
                                    onSelectChanged: (_) => setState(() => _selectedId = id),
                                    cells: [
                                      DataCell(SizedBox(width: 38, child: Text('${i + 1}',
                                        textAlign: TextAlign.center))),
                                      DataCell(SizedBox(width: 112, child: Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Text(_s(row['category_code']),
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: _catPurple)),
                                      ))),
                                      DataCell(SizedBox(
                                        width: 220,
                                        height: 36,
                                        child: Center(child: TextField(
                                          controller: _ar.putIfAbsent(id,
                                            () => TextEditingController(text: _s(row['category_name']))),
                                          enabled: _editing,
                                          textAlignVertical: TextAlignVertical.center,
                                          decoration: const InputDecoration(
                                            isDense: true, border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          ),
                                        )),
                                      )),
                                      if (_catalogTab == 0) DataCell(SizedBox(width: 190, child: DropdownButtonFormField<String>(
                                        value: _activities.any((a) => a['code'] == _s(row['activity_code'])) ? _s(row['activity_code']) : _selectedActivityCode,
                                        itemHeight: 40, isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 3)),
                                        items: _activities.map((a) => DropdownMenuItem<String>(value: a['code'], child: Text('${a['code']} - ${a['name']}', overflow: TextOverflow.ellipsis))).toList(),
                                        onChanged: _editing ? (value) { if (value == null) return; setState(() { row['activity_code'] = value; for (final child in _all.where((r) => _isDescendantOf(r, id))) { child['activity_code'] = value; } }); } : null,
                                      ))),
                                      if (_catalogTab == 1) DataCell(SizedBox(width: 190, child: DropdownButtonFormField<String>(
                                        value: _parents.any((p) => _s(p['id']) == _s(row['parent_id'])) ? _s(row['parent_id']) : null,
                                        itemHeight: 40, isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 3)),
                                        items: _parents.map((p) => DropdownMenuItem<String>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis))).toList(),
                                        onChanged: _editing ? (value) { if (value == null) return; setState(() { row['parent_id'] = value; final activity = _s(_all.firstWhere((p) => _s(p['id']) == value)['activity_code']); row['activity_code'] = activity; for (final child in _all.where((r) => _isDescendantOf(r, id))) { child['activity_code'] = activity; } }); } : null,
                                      ))),
                                      if (_catalogTab == 2) DataCell(SizedBox(width: 190, child: DropdownButtonFormField<String>(
                                        value: _secondaryParents.any((p) => _s(p['id']) == _s(row['parent_id'])) ? _s(row['parent_id']) : null,
                                        itemHeight: 40, isExpanded: true,
                                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 3)),
                                        items: _secondaryParents.where((p) => _mainCategoryFilter == null || _s(_parentOf(p)?['id']) == _mainCategoryFilter).map((p) => DropdownMenuItem<String>(value: _s(p['id']), child: Text(_s(p['category_name']), overflow: TextOverflow.ellipsis))).toList(),
                                        onChanged: _editing ? (value) { if (value == null) return; setState(() { row['parent_id'] = value; row['activity_code'] = _s(_parentOf(_all.firstWhere((p) => _s(p['id']) == value))?['activity_code']); }); } : null,
                                      ))),
                                      DataCell(SizedBox(width: 72, child: IconButton(
                                        tooltip: 'معاينة بيانات الفئة',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _showCategoryPreview(row),
                                        icon: const Icon(Icons.visibility_outlined, size: 19, color: _catPurple),
                                      ))),
                                      DataCell(SizedBox(width: 142, child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _imagePreview(row, size: 34),
                                          IconButton(
                                            tooltip: 'اختيار صورة من الجهاز',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: _editing ? () => _pickImage(row, source: ImageSource.gallery) : null,
                                            icon: const Icon(Icons.photo_library_outlined, size: 18, color: _catPurple),
                                          ),
                                          IconButton(
                                            tooltip: 'تصوير صورة للفئة',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: _editing ? () => _pickImage(row, source: ImageSource.camera) : null,
                                            icon: const Icon(Icons.photo_camera_outlined, size: 18, color: _catOrange),
                                          ),
                                        ],
                                      ))),
                                      DataCell(Checkbox(
                                        shape: const CircleBorder(),
                                        visualDensity: VisualDensity.compact,
                                        value: row['is_active'] == true,
                                        activeColor: _catPurple,
                                        onChanged: _editing ? (value) => setState(() {
                                          row['is_active'] = value == true;
                                          if (value != true) row['show_in_app'] = false;
                                        }) : null,
                                      )),
                                      DataCell(Checkbox(
                                        shape: const CircleBorder(),
                                        visualDensity: VisualDensity.compact,
                                        value: row['show_in_app'] == true && row['is_active'] == true,
                                        activeColor: _catOrange,
                                        onChanged: _editing && row['is_active'] == true
                                            ? (value) => setState(() => row['show_in_app'] = value == true)
                                            : null,
                                      )),
                                      DataCell(IconButton(
                                        tooltip: 'حذف الفئة',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _editing ? () => _deleteCategoryRow(row) : null,
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318), size: 19),
                                      )),
                                    ],
                                  );
                                }).toList(),

                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

}
