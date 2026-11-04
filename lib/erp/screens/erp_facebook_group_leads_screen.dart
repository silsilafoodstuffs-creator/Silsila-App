import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _facebookPurple = Color(0xFF3E007D);
const _facebookOrange = Color(0xFFFFA015);

class ErpFacebookGroupLeadsScreen extends StatefulWidget {
  const ErpFacebookGroupLeadsScreen({super.key, required this.companyId});

  final String? companyId;

  @override
  State<ErpFacebookGroupLeadsScreen> createState() =>
      _ErpFacebookGroupLeadsScreenState();
}

class _ErpFacebookGroupLeadsScreenState
    extends State<ErpFacebookGroupLeadsScreen> {
  SupabaseClient? _db;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;
  String _search = '';
  String _groupFilter = 'all';
  String _classFilter = 'all';

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _interactions = [];

  static const List<String> _classes = [
    'غير محدد',
    'عميل محتمل',
    'مورد محتمل',
    'تاجر جملة',
    'مستهلك',
    'شركة شحن',
    'غير مناسب',
  ];

  String _s(dynamic value) => (value ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    try {
      _db = Supabase.instance.client;
    } catch (_) {}
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpFacebookGroupLeadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _load();
    }
  }

  String _facebookUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      throw const FormatException('أدخل رابط HTTPS صحيحاً.');
    }
    final host = uri.host.toLowerCase();
    final validHost = host == 'facebook.com' ||
        host.endsWith('.facebook.com') ||
        host == 'fb.com' ||
        host.endsWith('.fb.com');
    if (!validHost) {
      throw const FormatException('يجب أن يكون الرابط تابعاً لفيسبوك.');
    }
    var path = uri.path;
    while (path.endsWith('/') && path.isNotEmpty) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) path = '/';
    return Uri.https(host, path, uri.queryParameters).toString();
  }

  String _facebookGroupUrl(String value) {
    return Uri.parse(_facebookUrl(value)).replace(query: '', fragment: '').toString();
  }

  Future<void> _load() async {
    final companyId = widget.companyId;
    if (_db == null || companyId == null || companyId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final results = await Future.wait([
        _db!.from('erp_crm_facebook_groups').select()
            .eq('company_id', companyId).order('group_name'),
        _db!.from('erp_crm_facebook_profiles').select()
            .eq('company_id', companyId).order('display_name'),
        _db!.from('erp_crm_facebook_group_profiles').select()
            .eq('company_id', companyId),
        _db!.from('erp_crm_facebook_interactions').select()
            .eq('company_id', companyId),
      ]);

      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List).cast<Map<String, dynamic>>();
        _profiles = (results[1] as List).cast<Map<String, dynamic>>();
        _links = (results[2] as List).cast<Map<String, dynamic>>();
        _interactions = (results[3] as List).cast<Map<String, dynamic>>();
        if (_groupFilter != 'all' &&
            !_groups.any((g) => _s(g['id']) == _groupFilter)) {
          _groupFilter = 'all';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل البيانات. تأكد من تطبيق ترحيل قاعدة البيانات والصلاحيات. ' +
              error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleProfiles {
    final query = _search.toLowerCase().trim();
    return _profiles.where((profile) {
      final profileId = _s(profile['id']);
      final groupIds = _links
          .where((link) => _s(link['profile_id']) == profileId)
          .map((link) => _s(link['group_id']))
          .toSet();
      final groupNames = _groups
          .where((group) => groupIds.contains(_s(group['id'])))
          .map((group) => _s(group['group_name']))
          .join(' ');
      final searchable = [
        _s(profile['display_name']),
        _s(profile['profile_url']),
        groupNames,
      ].join(' ').toLowerCase();

      return groupIds.isNotEmpty &&
          (_groupFilter == 'all' || groupIds.contains(_groupFilter)) &&
          (_classFilter == 'all' ||
              _s(profile['classification']) == _classFilter) &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_db == null || (widget.companyId ?? '').isEmpty) {
      _toast('اختر شركة نشطة أولاً.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      await operation();
      await _load();
      if (mounted) setState(() => _message = successMessage);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذر حفظ البيانات: ' + error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _showForm({
    required String title,
    required List<String> fields,
    Map<String, String> initial = const {},
    bool withClassification = false,
  }) async {
    final controllers = <String, TextEditingController>{};
    for (var i = 0; i < fields.length; i++) {
      controllers['field_' + i.toString()] = TextEditingController(
        text: initial['field_' + i.toString()] ?? '',
      );
    }
    var classification = initial['classification'] ?? _classes.first;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < fields.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: controllers['field_' + i.toString()],
                          maxLines: fields[i] == 'ملاحظات' ? 3 : 1,
                          decoration: InputDecoration(
                            labelText: fields[i],
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    if (withClassification)
                      DropdownButtonFormField<String>(
                        value: classification,
                        decoration: const InputDecoration(
                          labelText: 'تصنيف الحساب',
                          border: OutlineInputBorder(),
                        ),
                        items: _classes
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) => refresh(
                          () => classification = value ?? classification,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final values = <String, String>{};
                  for (var i = 0; i < fields.length; i++) {
                    values['field_' + i.toString()] =
                        controllers['field_' + i.toString()]!.text.trim();
                  }
                  values['classification'] = classification;
                  Navigator.pop(dialogContext, values);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _addGroup() async {
    final values = await _showForm(
      title: 'إضافة جروب فيسبوك',
      fields: const ['اسم الجروب', 'رابط الجروب', 'ملاحظات'],
    );
    if (values == null) return;
    if (values['field_0']!.isEmpty || values['field_1']!.isEmpty) {
      _toast('اسم الجروب والرابط مطلوبان.');
      return;
    }

    await _save(() async {
      await _db!.from('erp_crm_facebook_groups').insert({
        'company_id': widget.companyId,
        'group_name': values['field_0'],
        'group_url': _facebookGroupUrl(values['field_1']!),
        'notes': values['field_2'],
        'created_by': _db!.auth.currentUser?.id,
      });
    }, successMessage: 'تمت إضافة الجروب.');
  }

  Future<void> _addProfile() async {
    if (_groups.isEmpty) {
      _toast('أضف جروباً أولاً.');
      return;
    }

    final values = await _showForm(
      title: 'إضافة حساب إلى الجروب',
      fields: const [
        'اسم الحساب أو المستخدم',
        'رابط الملف الشخصي',
        'رابط صورة الحساب (اختياري)',
        'ملاحظات',
      ],
      withClassification: true,
    );
    if (values == null) return;
    if (values['field_0']!.isEmpty || values['field_1']!.isEmpty) {
      _toast('اسم الحساب ورابطه مطلوبان.');
      return;
    }

    var selectedGroupId = _groupFilter == 'all'
        ? _s(_groups.first['id'])
        : _groupFilter;

    final chosenGroup = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('اختيار الجروب'),
            content: DropdownButtonFormField<String>(
              value: selectedGroupId,
              items: _groups
                  .map((group) => DropdownMenuItem(
                        value: _s(group['id']),
                        child: Text(_s(group['group_name'])),
                      ))
                  .toList(),
              onChanged: (value) => refresh(
                () => selectedGroupId = value ?? selectedGroupId,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, selectedGroupId),
                child: const Text('متابعة'),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosenGroup == null) return;

    await _save(() async {
      final profileUrl = _facebookUrl(values['field_1']!);
      final avatar = values['field_2']!.trim();
      if (avatar.isNotEmpty && Uri.tryParse(avatar)?.scheme != 'https') {
        throw const FormatException('رابط الصورة يجب أن يبدأ بـ HTTPS.');
      }

      final profile = await _db!
          .from('erp_crm_facebook_profiles')
          .upsert({
            'company_id': widget.companyId,
            'display_name': values['field_0'],
            'profile_url': profileUrl,
            'profile_url_normalized': Uri.parse(profileUrl).replace(fragment: '').toString(),
            'avatar_url': avatar.isEmpty ? null : avatar,
            'classification': values['classification'],
            'notes': values['field_3'],
            'created_by': _db!.auth.currentUser?.id,
          }, onConflict: 'company_id,profile_url_normalized')
          .select()
          .single();

      await _db!.from('erp_crm_facebook_group_profiles').upsert({
        'company_id': widget.companyId,
        'group_id': chosenGroup,
        'profile_id': profile['id'],
        'created_by': _db!.auth.currentUser?.id,
      }, onConflict: 'company_id,group_id,profile_id', ignoreDuplicates: true);
    }, successMessage: 'تم حفظ الحساب وربطه بالجروب دون تكرار.');
  }

  Future<void> _linkAnotherGroup(Map<String, dynamic> profile) async {
    var selectedGroupId =
        _groups.isEmpty ? '' : _s(_groups.first['id']);

    final chosenGroup = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ربط الحساب بجروب آخر'),
            content: DropdownButtonFormField<String>(
              value: selectedGroupId.isEmpty ? null : selectedGroupId,
              items: _groups
                  .map((group) => DropdownMenuItem(
                        value: _s(group['id']),
                        child: Text(_s(group['group_name'])),
                      ))
                  .toList(),
              onChanged: (value) => refresh(
                () => selectedGroupId = value ?? selectedGroupId,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, selectedGroupId),
                child: const Text('ربط'),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosenGroup == null || chosenGroup.isEmpty) return;

    await _save(() async {
      await _db!.from('erp_crm_facebook_group_profiles').upsert({
        'company_id': widget.companyId,
        'group_id': chosenGroup,
        'profile_id': profile['id'],
        'created_by': _db!.auth.currentUser?.id,
      }, onConflict: 'company_id,group_id,profile_id', ignoreDuplicates: true);
    }, successMessage: 'تم ربط الحساب بالجروب دون تكرار.');
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final values = await _showForm(
      title: 'تعديل بيانات الحساب',
      fields: const [
        'اسم الحساب أو المستخدم',
        'رابط الملف الشخصي',
        'رابط الصورة',
        'ملاحظات',
      ],
      initial: {
        'field_0': _s(profile['display_name']),
        'field_1': _s(profile['profile_url']),
        'field_2': _s(profile['avatar_url']),
        'field_3': _s(profile['notes']),
        'classification': _s(profile['classification']),
      },
      withClassification: true,
    );
    if (values == null) return;

    await _save(() async {
      final profileUrl = _facebookUrl(values['field_1']!);
      final avatar = values['field_2']!.trim();
      if (avatar.isNotEmpty && Uri.tryParse(avatar)?.scheme != 'https') {
        throw const FormatException('رابط الصورة يجب أن يبدأ بـ HTTPS.');
      }
      await _db!.from('erp_crm_facebook_profiles').update({
        'display_name': values['field_0'],
        'profile_url': profileUrl,
        'profile_url_normalized':
            Uri.parse(profileUrl).replace(fragment: '').toString(),
        'avatar_url': avatar.isEmpty ? null : avatar,
        'classification': values['classification'],
        'notes': values['field_3'],
      }).eq('id', profile['id']).eq('company_id', widget.companyId!);
    }, successMessage: 'تم تحديث بيانات الحساب.');
  }

  Future<void> _recordInteraction(Map<String, dynamic> profile) async {
    final values = await _showForm(
      title: 'تسجيل تواصل مع ' + _s(profile['display_name']),
      fields: const ['نوع التواصل', 'ملاحظات'],
    );
    if (values == null || values['field_0']!.isEmpty) return;

    await _save(() async {
      await _db!.from('erp_crm_facebook_interactions').insert({
        'company_id': widget.companyId,
        'profile_id': profile['id'],
        'interaction_type': values['field_0'],
        'notes': values['field_1'],
        'created_by': _db!.auth.currentUser?.id,
      });
    }, successMessage: 'تم تسجيل التواصل.');
  }

  Future<void> _openFacebook(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _toast('تعذر فتح الرابط.');
    } catch (error) {
      _toast('تعذر فتح الرابط: ' + error.toString());
    }
  }

  Future<void> _openSelectedGroup() async {
    final selected =
        _groups.where((group) => _s(group['id']) == _groupFilter);
    if (selected.isEmpty) {
      _toast('اختر جروباً من قائمة التصفية أولاً.');
      return;
    }
    await _openFacebook(_s(selected.first['group_url']));
  }

  Future<void> _exportExcel() async {
    final rows = <List<String>>[];
    for (final link in _links) {
      final profileRows = _profiles.where(
        (profile) => _s(profile['id']) == _s(link['profile_id']),
      );
      final groupRows = _groups.where(
        (group) => _s(group['id']) == _s(link['group_id']),
      );
      if (profileRows.isEmpty || groupRows.isEmpty) continue;

      final profile = profileRows.first;
      final group = groupRows.first;
      if (_groupFilter != 'all' &&
          _s(group['id']) != _groupFilter) continue;
      if (_classFilter != 'all' &&
          _s(profile['classification']) != _classFilter) continue;

      final query = _search.toLowerCase().trim();
      final searchable =
          (_s(profile['display_name']) + ' ' + _s(group['group_name']))
              .toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) continue;

      rows.add([
        _s(profile['display_name']),
        _s(group['group_name']),
      ]);
    }

    if (rows.isEmpty) {
      _toast('لا توجد بيانات للتصدير.');
      return;
    }

    try {
      final workbook = xls.Excel.createExcel();
      final sheet = workbook['حسابات الجروبات'];
      sheet.appendRow([
        xls.TextCellValue('م'),
        xls.TextCellValue('اسم الحساب أو المستخدم'),
        xls.TextCellValue('اسم الجروب'),
      ]);
      for (var i = 0; i < rows.length; i++) {
        sheet.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(rows[i][0]),
          xls.TextCellValue(rows[i][1]),
        ]);
      }
      final bytes = workbook.encode();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('تعذر إنشاء ملف Excel.');
      }
      await FileSaver.instance.saveFile(
        name: 'silsila_facebook_groups_' +
            DateTime.now().millisecondsSinceEpoch.toString(),
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) {
        setState(() => _message =
            'تم تصدير ' + rows.length.toString() + ' صفاً إلى Excel.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذر تصدير Excel: ' + error.toString());
      }
    }
  }

  Future<void> _importExcel() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('الملف فارغ.');
      }

      final workbook = xls.Excel.decodeBytes(bytes);
      final sheets =
          workbook.tables.values.where((sheet) => sheet.rows.isNotEmpty);
      if (sheets.isEmpty) throw StateError('ملف Excel لا يحتوي بيانات.');
      final rows = sheets.first.rows;

      String cell(int row, int column) {
        if (column >= rows[row].length) return '';
        return rows[row][column]?.value?.toString().trim() ?? '';
      }

      final headers =
          rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
      int findColumn(List<String> candidates) {
        return headers.indexWhere((header) =>
            candidates.any((candidate) =>
                header.toLowerCase() == candidate.toLowerCase()));
      }

      final nameColumn =
          findColumn(['اسم الحساب أو المستخدم', 'اسم الحساب']);
      final profileColumn =
          findColumn(['رابط الحساب', 'رابط الملف الشخصي']);
      final groupNameColumn = findColumn(['اسم الجروب']);
      final groupUrlColumn = findColumn(['رابط الجروب']);

      if ([nameColumn, profileColumn, groupNameColumn, groupUrlColumn]
          .any((column) => column < 0)) {
        throw StateError(
          'الأعمدة المطلوبة: اسم الحساب أو المستخدم، رابط الحساب، اسم الجروب، رابط الجروب.',
        );
      }

      final importedRows = <List<String>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = [
          cell(i, nameColumn),
          cell(i, profileColumn),
          cell(i, groupNameColumn),
          cell(i, groupUrlColumn),
        ];
        if (row.every((value) => value.isEmpty)) continue;
        if (row.any((value) => value.isEmpty)) {
          throw FormatException('بيانات ناقصة في الصف ' + (i + 1).toString());
        }
        importedRows.add(row);
      }
      if (importedRows.isEmpty) {
        throw StateError('لا توجد صفوف مكتملة.');
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الاستيراد'),
            content: Text(
              'سيتم استيراد ' +
                  importedRows.length.toString() +
                  ' صفاً ودمج الحسابات المتكررة حسب رابط الحساب.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('استيراد'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;

      // Validate every URL before sending any row. The database RPC then
      // applies the whole workbook in one transaction (all-or-nothing).
      final rpcRows = <Map<String, dynamic>>[];
      for (var index = 0; index < importedRows.length; index++) {
        final row = importedRows[index];
        try {
          final profileUrl = _facebookUrl(row[1]);
          final groupUrl = _facebookGroupUrl(row[3]);
          rpcRows.add({
            'display_name': row[0],
            'profile_url': profileUrl,
            'profile_url_normalized':
                Uri.parse(profileUrl).replace(fragment: '').toString(),
            'group_name': row[2],
            'group_url': groupUrl,
          });
        } on FormatException catch (error) {
          throw FormatException(
            'رابط غير صالح في الصف ' + (index + 2).toString() + ': ' + error.message,
          );
        }
      }

      await _save(() async {
        await _db!.rpc(
          'erp_crm_facebook_import_group_leads',
          params: {
            'p_company_id': widget.companyId,
            'p_rows': rpcRows,
          },
        );
      }, successMessage: 'تم استيراد ' + importedRows.length.toString() +
          ' صفاً بنجاح في عملية واحدة.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذر استيراد Excel: ' + error.toString());
      }
    }
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return FilledButton.icon(
      onPressed: _busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _metric(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _facebookPurple,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _visibleProfiles;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_facebookPurple, Color(0xFF7140A4)],
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded,
                    color: _facebookOrange, size: 38),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة حسابات جروبات فيسبوك',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'إدارة الجروبات والحسابات المحتملة داخل علاقات العملاء',
                        style: TextStyle(color: Color(0xFFEDE3F7)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy || _loading ? null : _load,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4DE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'تنبيه تكامل: واجهة Meta الرسمية لا تتيح حالياً جلب أعضاء مجموعات Facebook. لا يوجد سحب آلي أو طلب كلمة مرور. أضف الحسابات التي تختارها يدوياً أو استورد بيانات مصرحاً لك باستخدامها، وافتح الملف لإرسال طلب الصداقة بنفسك.',
              style: TextStyle(
                color: Color(0xFF795000),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                  'إضافة جروب', Icons.group_add, _facebookPurple, _addGroup),
              _actionButton(
                'إضافة حساب',
                Icons.person_add_alt_1,
                _facebookOrange,
                _groups.isEmpty ? null : _addProfile,
              ),
              _actionButton(
                  'استيراد Excel', Icons.file_upload, Colors.green, _importExcel),
              _actionButton(
                'تصدير Excel',
                Icons.file_download,
                Colors.green,
                _profiles.isEmpty ? null : _exportExcel,
              ),
              _actionButton(
                'فتح الجروب المحدد',
                Icons.groups,
                const Color(0xFF1877F2),
                _groupFilter == 'all' ? null : _openSelectedGroup,
              ),
              _actionButton(
                'فتح فيسبوك',
                Icons.open_in_new,
                const Color(0xFF1877F2),
                () => _openFacebook('https://www.facebook.com/'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metric('الجروبات', _groups.length),
              const SizedBox(width: 7),
              _metric('الحسابات الفريدة', _profiles.length),
              const SizedBox(width: 7),
              _metric('سجلات التواصل', _interactions.length),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 245,
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    labelText: 'بحث باسم الحساب أو الجروب',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  value: _groups.any((group) =>
                          _s(group['id']) == _groupFilter)
                      ? _groupFilter
                      : 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الجروب',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('كل الجروبات')),
                    ..._groups.map((group) => DropdownMenuItem(
                          value: _s(group['id']),
                          child: Text(
                            _s(group['group_name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _groupFilter = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  value: _classFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('كل التصنيفات')),
                    ..._classes.map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _classFilter = value ?? 'all'),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_db == null || (widget.companyId ?? '').isEmpty)
            const Expanded(
              child: Center(
                child: Text('اختر شركة نشطة لبدء إدارة حسابات الجروبات.'),
              ),
            )
          else if (profiles.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_2_outlined,
                        size: 50, color: _facebookPurple),
                    const SizedBox(height: 8),
                    const Text('لا توجد حسابات مرتبطة بالجروب المحدد.'),
                    TextButton.icon(
                      onPressed: _groups.isEmpty ? _addGroup : _addProfile,
                      icon: const Icon(Icons.add),
                      label: Text(
                          _groups.isEmpty ? 'إضافة أول جروب' : 'إضافة حساب'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final profileId = _s(profile['id']);
                  final groupIds = _links
                      .where((link) => _s(link['profile_id']) == profileId)
                      .map((link) => _s(link['group_id']))
                      .toSet();
                  final groupNames = _groups
                      .where((group) => groupIds.contains(_s(group['id'])))
                      .map((group) => _s(group['group_name']))
                      .join(' • ');
                  final avatar = _s(profile['avatar_url']);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE9E2F0)),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF0E9F7),
                          backgroundImage:
                              avatar.isEmpty ? null : NetworkImage(avatar),
                          child: avatar.isEmpty
                              ? const Icon(Icons.person,
                                  color: _facebookPurple)
                              : null,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _s(profile['display_name']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                groupNames,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _s(profile['classification']),
                                style: const TextStyle(
                                  color: _facebookPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'فتح الملف لإرسال طلب صداقة يدوياً',
                          onPressed: () =>
                              _openFacebook(_s(profile['profile_url'])),
                          icon: const Icon(Icons.person_search,
                              color: Color(0xFF1877F2)),
                        ),
                        IconButton(
                          tooltip: 'تسجيل تواصل',
                          onPressed: () => _recordInteraction(profile),
                          icon: const Icon(Icons.forum_outlined,
                              color: _facebookPurple),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editProfile(profile);
                            } else {
                              _linkAnotherGroup(profile);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'link',
                              child: Text('ربط بجروب آخر'),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل البيانات'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
