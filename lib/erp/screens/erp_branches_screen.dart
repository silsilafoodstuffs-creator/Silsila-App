import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _branchPurple = Color(0xFF3E007D);

class ErpBranchesScreen extends StatefulWidget {
  const ErpBranchesScreen({super.key, required this.companyId, this.embedded = false});
  final String? companyId;
  final bool embedded;

  @override
  State<ErpBranchesScreen> createState() => _ErpBranchesScreenState();
}

class _ErpBranchesScreenState extends State<ErpBranchesScreen> {
  SupabaseClient? _db;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _geoRows = [];
  final Set<String> _selectedBranchIds = <String>{};
  bool _loading = false;
  String? _error;
  String? _message;
  String? _editingBranchId;
  final Map<String, TextEditingController> _editFields = {};
  String? _editGovernorateId, _editDistrictId, _editAreaId;

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpBranchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  String _s(dynamic value) => (value ?? '').toString();

  String _standardBranchCode(String value) {
    final name = value.trim().toLowerCase();
    if (name.contains('القاهرة') || name.contains('cairo')) return '001';
    if (name.contains('الجيزة') || name.contains('الجيزه') || name.contains('giza')) return '002';
    if (name.contains('القليوبية') || name.contains('القليوبيه') || name.contains('qalyubia') || name.contains('qalyub')) return '003';
    if (name.contains('الشرقية') || name.contains('الشرقيه') || name.contains('sharqia') || name.contains('sharkia')) return '004';
    return '';
  }

  int _branchOrder(Map<String, dynamic> row) {
    final standardCode = _standardBranchCode(_s(row['branch_name']));
    if (standardCode.isNotEmpty) return int.parse(standardCode);
    final actualCode = int.tryParse(_s(row['branch_code']));
    return actualCode == null ? 100000 : 1000 + actualCode;
  }

  Future<void> _load() async {
    final companyId = (widget.companyId ?? '').trim();
    if (_db == null || companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = _db == null ? 'سجّل الدخول إلى Supabase أولًا.' : 'لا توجد شركة نشطة مرتبطة بالمستخدم.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Branch records are the primary data. Geographic metadata is optional;
      // a failed geography query must not prevent the branch directory from loading.
      final result = await _db!
          .from('erp_branches')
          .select('id, branch_code, branch_name, branch_name_en, email, phone, phone2, landline1, landline2, location, address, governorate_id, district_id, area_id, is_main, is_active')
          .eq('company_id', companyId)
          .order('branch_code');
      List<Map<String, dynamic>> geoRows = [];
      try {
        final geoResult = await _db!.from('erp_geographic_data')
            .select('id,parent_id,geo_code,name_ar,name_en,level,is_active')
            .eq('company_id', companyId).eq('is_active', true).order('geo_code');
        geoRows = (geoResult as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _rows = (result as List).whereType<Map<String, dynamic>>().toList();
        _rows.sort((a, b) {
          final order = _branchOrder(a).compareTo(_branchOrder(b));
          if (order != 0) return order;
          return _s(a['branch_code']).compareTo(_s(b['branch_code']));
        });
        _rows = List<Map<String, dynamic>>.unmodifiable(_rows);
        _selectedBranchIds.removeWhere((id) => !_rows.any((row) => _s(row['id']) == id));
        _geoRows = geoRows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل الفروع: $error'; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    if (row != null) {
      for (final controller in _editFields.values) {
        controller.dispose();
      }
      _editFields
        ..clear()
        ..addAll({
          'branch_code': TextEditingController(text: _s(row['branch_code'])),
          'branch_name': TextEditingController(text: _s(row['branch_name'])),
          'branch_name_en': TextEditingController(text: _s(row['branch_name_en'])),
          'email': TextEditingController(text: _s(row['email'])),
          'phone': TextEditingController(text: _s(row['phone'])),
          'phone2': TextEditingController(text: _s(row['phone2'])),
          'landline1': TextEditingController(text: _s(row['landline1'])),
          'landline2': TextEditingController(text: _s(row['landline2'])),
          'location': TextEditingController(text: _s(row['location'])),
          'address': TextEditingController(text: _s(row['address'])),
        });
      setState(() {
        _editingBranchId = _s(row['id']);
        _editGovernorateId = _s(row['governorate_id']).isEmpty ? null : _s(row['governorate_id']);
        _editDistrictId = _s(row['district_id']).isEmpty ? null : _s(row['district_id']);
        _editAreaId = _s(row['area_id']).isEmpty ? null : _s(row['area_id']);
        _error = null;
        _message = 'وضع تعديل مباشر: عدّل البيانات داخل صف الفرع ثم اضغط حفظ الصف.';
      });
      return;
    }
    final defaultCode = (_rows.length + 1).toString().padLeft(3, '0');
    final code = TextEditingController(text: row == null ? defaultCode : _s(row['branch_code']));
    var lastAutoCode = defaultCode;
    final name = TextEditingController(text: _s(row?['branch_name']));
    final nameEn = TextEditingController(text: _s(row?['branch_name_en']));
    final email = TextEditingController(text: _s(row?['email']));
    final phone2 = TextEditingController(text: _s(row?['phone2']));
    final landline1 = TextEditingController(text: _s(row?['landline1']));
    final landline2 = TextEditingController(text: _s(row?['landline2']));
    final location = TextEditingController(text: _s(row?['location']));
    String? governorateId = _s(row?['governorate_id']).isEmpty ? null : _s(row?['governorate_id']);
    String? districtId = _s(row?['district_id']).isEmpty ? null : _s(row?['district_id']);
    String? areaId = _s(row?['area_id']).isEmpty ? null : _s(row?['area_id']);
    final phone = TextEditingController(text: _s(row?['phone']));
    final address = TextEditingController(text: _s(row?['address']));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row == null ? 'إضافة فرع' : 'تعديل بيانات الفرع'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'كود الفرع *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                onChanged: (value) {
                  final suggested = _standardBranchCode(value);
                  if (code.text == lastAutoCode) {
                    final nextCode = suggested.isEmpty ? defaultCode : suggested;
                    code.text = nextCode;
                    lastAutoCode = nextCode;
                  }
                },
                decoration: const InputDecoration(labelText: 'اسم الفرع عربي *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'اسم الفرع إنجليزي', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'موبايل 1', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phone2, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'موبايل 2', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: landline1, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'تليفون أرضي 1', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: landline2, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'تليفون أرضي 2', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: location, decoration: const InputDecoration(labelText: 'الموقع / وصف المكان', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: governorateId, isExpanded: true, decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder()),
                items: [const DropdownMenuItem<String>(value: null, child: Text('اختر المحافظة')), ..._geoRows.where((g) => g['level'] == 'governorate').map((g) => DropdownMenuItem(value: _s(g['id']), child: Text(_s(g['name_ar']))))],
                onChanged: (v) => setState(() { governorateId = v; districtId = null; areaId = null; })),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: districtId, isExpanded: true, decoration: const InputDecoration(labelText: 'الحي / المركز', border: OutlineInputBorder()),
                items: [const DropdownMenuItem<String>(value: null, child: Text('اختر الحي أو المركز')), ..._geoRows.where((g) => g['level'] == 'district' && _s(g['parent_id']) == (governorateId ?? '')).map((g) => DropdownMenuItem(value: _s(g['id']), child: Text(_s(g['name_ar']))))],
                onChanged: (v) => setState(() { districtId = v; areaId = null; })),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: areaId, isExpanded: true, decoration: const InputDecoration(labelText: 'المنطقة / القرية', border: OutlineInputBorder()),
                items: [const DropdownMenuItem<String>(value: null, child: Text('اختر المنطقة أو القرية')), ..._geoRows.where((g) => g['level'] == 'area' && _s(g['parent_id']) == (districtId ?? '')).map((g) => DropdownMenuItem(value: _s(g['id']), child: Text(_s(g['name_ar']))))],
                onChanged: (v) => setState(() => areaId = v)),
              const SizedBox(height: 10),
              TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (result != true) {
      code.dispose(); name.dispose(); nameEn.dispose(); email.dispose(); phone.dispose(); phone2.dispose(); landline1.dispose(); landline2.dispose(); location.dispose(); address.dispose();
      return;
    }
    try {
      final companyId = (widget.companyId ?? '').trim();
      if (companyId.isEmpty) throw StateError('لا توجد شركة نشطة.');
      if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
        throw ArgumentError('كود الفرع واسم الفرع مطلوبان.');
      }
      final cleanCode = code.text.trim();
      const allowedCodeChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-';
      if (cleanCode.isEmpty || cleanCode.split('').any((ch) => !allowedCodeChars.contains(ch))) {
        throw ArgumentError('كود الفرع يجب أن يتكون من حروف إنجليزية وأرقام وشرطة فقط.');
      }
      final payload = <String, Object?>{
        'company_id': companyId,
        'branch_code': code.text.trim(),
        'branch_name': name.text.trim(),
        'branch_name_en': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'phone2': phone2.text.trim().isEmpty ? null : phone2.text.trim(),
        'landline1': landline1.text.trim().isEmpty ? null : landline1.text.trim(),
        'landline2': landline2.text.trim().isEmpty ? null : landline2.text.trim(),
        'location': location.text.trim().isEmpty ? null : location.text.trim(),
        'governorate_id': governorateId, 'district_id': districtId, 'area_id': areaId,
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'address': address.text.trim().isEmpty ? null : address.text.trim(),
        'is_main': row?['is_main'] == true,
        'is_active': row?['is_active'] != false,
      };
      if (row == null) {
        payload['is_main'] = false;
        payload['is_active'] = true;
        await _db!.from('erp_branches').insert(payload);
      } else {
        await _db!.from('erp_branches').update(payload).eq('id', row['id']).eq('company_id', companyId);
      }
      if (!mounted) return;
      setState(() => _message = 'تم حفظ بيانات الفرع في قاعدة البيانات.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ الفرع: $error');
    } finally {
      code.dispose(); name.dispose(); nameEn.dispose(); phone.dispose(); phone2.dispose(); landline1.dispose(); landline2.dispose(); location.dispose(); address.dispose();
    }
  }

  Widget _inlineField(String key, {double width = 130, TextInputType? keyboardType}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: _editFields[key],
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _saveInlineEdit(Map<String, dynamic> row) async {
    final companyId = (widget.companyId ?? '').trim();
    final code = _editFields['branch_code']!.text.trim();
    final name = _editFields['branch_name']!.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'كود الفرع واسم الفرع العربي مطلوبان.');
      return;
    }
    const allowed = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-';
    if (code.split('').any((ch) => !allowed.contains(ch))) {
      setState(() => _error = 'كود الفرع يجب أن يتكون من حروف إنجليزية وأرقام وشرطة فقط.');
      return;
    }
    try {
      await _db!.from('erp_branches').update({
        'branch_code': code,
        'branch_name': name,
        'branch_name_en': _editFields['branch_name_en']!.text.trim().isEmpty ? null : _editFields['branch_name_en']!.text.trim(),
        'email': _editFields['email']!.text.trim().isEmpty ? null : _editFields['email']!.text.trim(),
        'phone': _editFields['phone']!.text.trim().isEmpty ? null : _editFields['phone']!.text.trim(),
        'phone2': _editFields['phone2']!.text.trim().isEmpty ? null : _editFields['phone2']!.text.trim(),
        'landline1': _editFields['landline1']!.text.trim().isEmpty ? null : _editFields['landline1']!.text.trim(),
        'landline2': _editFields['landline2']!.text.trim().isEmpty ? null : _editFields['landline2']!.text.trim(),
        'location': _editFields['location']!.text.trim().isEmpty ? null : _editFields['location']!.text.trim(),
        'address': _editFields['address']!.text.trim().isEmpty ? null : _editFields['address']!.text.trim(),
        'governorate_id': _editGovernorateId,
        'district_id': _editDistrictId,
        'area_id': _editAreaId,
      }).eq('id', row['id']).eq('company_id', companyId);
      for (final controller in _editFields.values) {
        controller.dispose();
      }
      if (!mounted) return;
      setState(() {
        _editFields.clear();
        _editingBranchId = null;
        _message = 'تم حفظ تعديلات الفرع بنجاح.';
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ تعديلات الفرع: $error');
    }
  }

  void _cancelInlineEdit() {
    for (final controller in _editFields.values) {
      controller.dispose();
    }
    setState(() {
      _editFields.clear();
      _editingBranchId = null;
      _message = null;
      _error = null;
    });
  }

  Map<String, dynamic>? get _singleSelectedBranch {
    if (_selectedBranchIds.length != 1) return null;
    final id = _selectedBranchIds.single;
    for (final row in _rows) {
      if (_s(row['id']) == id) return row;
    }
    return null;
  }

  void _selectBranch(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedBranchIds.add(id);
      } else {
        _selectedBranchIds.remove(id);
      }
      _error = null;
      _message = _selectedBranchIds.length > 1
          ? 'تم تحديد أكثر من فرع. اختر فرعًا واحدًا فقط لتنفيذ التعديل.'
          : null;
    });
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    final companyId = (widget.companyId ?? '').trim();
    final id = _s(row['id']);
    final next = row['is_active'] != true;
    if (row['is_main'] == true && !next) {
      setState(() => _error = 'لا يمكن إيقاف الفرع الرئيسي قبل تعيين فرع رئيسي بديل.');
      return;
    }
    try {
      await _db!.from('erp_branches').update({'is_active': next}).eq('id', id).eq('company_id', companyId);
      if (mounted) setState(() => _message = next ? 'تم تفعيل الفرع.' : 'تم إيقاف الفرع.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تغيير حالة الفرع: $error');
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (row['is_main'] == true) {
      setState(() => _error = 'لا يمكن حذف الفرع الرئيسي.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفرع'),
        content: Text('هل تريد حذف «${_s(row['branch_name'])}»؟ لن يسمح النظام بحذف فرع مرتبط بمخازن أو حركات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No / لا')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Yes / نعم، احذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _db!
          .from('erp_branches')
          .delete()
          .eq('id', row['id'])
          .eq('company_id', (widget.companyId ?? '').trim());
      if (mounted) setState(() => _message = 'تم حذف الفرع.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حذف الفرع؛ قد يكون مرتبطًا بمخازن أو مراكز تكلفة أو حركات: $error');
    }
  }

  String _geoName(dynamic id) { final rows = _geoRows.where((g) => _s(g['id']) == _s(id)); return rows.isEmpty ? '' : _s(rows.first['name_ar']); }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewDirectory() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة الدليل'),
      content: SizedBox(width: 720, child: _rows.isEmpty ? const Text('لا توجد بيانات محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _rows.take(100).map((r) => ListTile(
          dense: true, title: Text('${r['branch_name'] ?? r['center_name'] ?? r['name'] ?? '—'}'),
          subtitle: Text('${r['branch_code'] ?? r['center_code'] ?? r['code'] ?? ''} • ${r['is_active'] == true ? 'نشط' : 'موقوف'}'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!widget.embedded)
        Card(color: _branchPurple, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(
              children: [
                const Expanded(
                  child: Text('الفروع', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                OutlinedButton.icon(
                  onPressed: _singleSelectedBranch == null
                      ? null
                      : () => _openBranchInGoogleMaps(_singleSelectedBranch!),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('خرائط Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  ),
                ),
              ],
            ),
            const Text('إدارة دليل الفروع الفعلي المرتبط بالشركة.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6), _branchActions(),
          ]),
        ))
      else
        Padding(padding: const EdgeInsets.only(bottom: 6), child: _branchActions()),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_rows.isEmpty)
        const Expanded(child: Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد فروع مسجلة بعد.')))))
      else
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) => _branchCard(_rows[index], index),
        )),
    ]),
  );

  Widget _branchActions() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
      _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _loading ? null : () => _edit()),
      _quickTask('تعديل', Icons.edit_outlined, const Color(0xFFEF9B13), _singleSelectedBranch == null ? null : () => _edit(_singleSelectedBranch)),
      _quickTask('حذف', Icons.delete_outline, Colors.red, _singleSelectedBranch == null ? null : () => _delete(_singleSelectedBranch!)),
      _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewDirectory),
    ]),
  );

  Widget _branchCard(Map<String, dynamic> row, int index) {
    final id = _s(row['id']);
    final editing = _editingBranchId == id;
    final selected = _selectedBranchIds.contains(id);
    Widget textCell(String label, String value, {double width = 190}) => SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value.trim().isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
    Widget inputCell(String label, String key, {double width = 190, TextInputType? keyboard}) => SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3), _inlineField(key, width: width, keyboardType: keyboard),
      ]),
    );
    Widget geoDropdown(String label, String? value, String level, ValueChanged<String?> onChanged, {String? parent, double width = 200}) =>
      SizedBox(width: width, child: DropdownButtonFormField<String>(
        value: value, isExpanded: true, isDense: true, menuMaxHeight: 280,
        decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(9))),
        items: [
          DropdownMenuItem<String>(value: null, child: Text('اختر $label')),
          ..._geoRows.where((g) => g['level'] == level && (parent == null || _s(g['parent_id']) == parent))
            .map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: onChanged,
      ));
    return Card(
      margin: EdgeInsets.zero, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: selected || editing ? _branchPurple.withValues(alpha: .65) : _branchPurple.withValues(alpha: .18), width: selected || editing ? 1.4 : 1)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 28, child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: _branchPurple))),
          Checkbox(shape: const CircleBorder(), value: selected, onChanged: (v) => _selectBranch(id, v == true), visualDensity: VisualDensity.compact, activeColor: _branchPurple),
          const SizedBox(width: 6),
          Expanded(child: Wrap(spacing: 10, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
            editing ? inputCell('كود الفرع', 'branch_code', width: 135) : textCell('كود الفرع', _s(row['branch_code']), width: 135),
            editing ? inputCell('اسم الفرع عربي', 'branch_name', width: 210) : textCell('اسم الفرع عربي', _s(row['branch_name']), width: 210),
            editing ? inputCell('اسم الفرع إنجليزي', 'branch_name_en', width: 210) : textCell('اسم الفرع إنجليزي', _s(row['branch_name_en']), width: 210),
          ])),
          if (editing) ...[
            IconButton(tooltip: 'حفظ الصف', onPressed: () => _saveInlineEdit(row), icon: const Icon(Icons.save_rounded, color: Colors.green)),
            IconButton(tooltip: 'إلغاء التعديل', onPressed: _cancelInlineEdit, icon: const Icon(Icons.close_rounded, color: Colors.grey)),
          ] else ...[
            IconButton(tooltip: 'تعديل الفرع', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined, color: _branchPurple)),
            IconButton(tooltip: 'حذف الفرع', onPressed: () => _delete(row), icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ],
        ]),
        const Divider(height: 5),
        Padding(padding: const EdgeInsetsDirectional.only(start: 34), child: Wrap(spacing: 6, runSpacing: 4, children: [
          editing ? geoDropdown('المحافظة', _editGovernorateId, 'governorate', (v) => setState(() { _editGovernorateId=v; _editDistrictId=null; _editAreaId=null; }), width: 220) : textCell('المحافظة', _geoName(row['governorate_id']), width: 220),
          editing ? geoDropdown('الحي / المركز', _editDistrictId, 'district', (v) => setState(() { _editDistrictId=v; _editAreaId=null; }), parent: _editGovernorateId, width: 220) : textCell('الحي / المركز', _geoName(row['district_id']), width: 220),
          editing ? geoDropdown('المنطقة / القرية', _editAreaId, 'area', (v) => setState(() => _editAreaId=v), parent: _editDistrictId, width: 220) : textCell('المنطقة / القرية', _geoName(row['area_id']), width: 220),
        ])),
        const Divider(height: 8),
        Padding(padding: const EdgeInsetsDirectional.only(start: 34), child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          editing ? inputCell('العنوان', 'address', width: 300) : textCell('العنوان', _s(row['address']), width: 300),
          editing ? inputCell('علامة مميزة', 'location', width: 220) : textCell('علامة مميزة', _s(row['location']), width: 220),

        ])),
        const Divider(height: 8),
        Padding(padding: const EdgeInsetsDirectional.only(start: 34), child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          editing ? inputCell('إيميل الفرع', 'email', width: 235, keyboard: TextInputType.emailAddress) : textCell('إيميل الفرع', _s(row['email']), width: 235),
          editing ? inputCell('موبايل', 'phone', width: 165, keyboard: TextInputType.phone) : textCell('موبايل', _s(row['phone']), width: 165),
          editing ? inputCell('أرضي', 'landline1', width: 165, keyboard: TextInputType.phone) : textCell('أرضي', _s(row['landline1']), width: 165),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(shape: const CircleBorder(), value: row['is_main'] == true, onChanged: editing ? null : (v) => _setMain(row, v == true), activeColor: _branchPurple, visualDensity: VisualDensity.compact),
            const Text('رئيسي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Checkbox(shape: const CircleBorder(), value: row['is_main'] != true, onChanged: editing ? null : (v) { if (v == true && row['is_main'] == true) return; }, activeColor: _branchPurple, visualDensity: VisualDensity.compact),
            const Text('عادي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          if (!editing) IconButton(tooltip: row['is_active'] == true ? 'إيقاف الفرع' : 'تفعيل الفرع', onPressed: () => _toggle(row), icon: Icon(row['is_active'] == true ? Icons.check_circle : Icons.pause_circle_outline, color: row['is_active'] == true ? Colors.green : Colors.grey)),
        ])),
      ])),
    );
  }

  Future<void> _setMain(Map<String, dynamic> row, bool isMain) async {
    final companyId = (widget.companyId ?? '').trim();
    try {
      if (isMain) {
        await _db!.from('erp_branches').update({'is_main': false}).eq('company_id', companyId);
      }
      await _db!.from('erp_branches').update({'is_main': isMain}).eq('id', row['id']).eq('company_id', companyId);
      if (mounted) setState(() => _message = isMain ? 'تم تعيين الفرع الرئيسي.' : 'تم تعيين الفرع كفرع عادي.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تغيير نوع الفرع: $error');
    }
  }

  Future<void> _openBranchInGoogleMaps(Map<String, dynamic> row) async {
    final parts = <String>[
      _s(row['branch_name']),
      _s(row['address']),
      _s(row['location']),
      _geoName(row['area_id']),
      _geoName(row['district_id']),
      _geoName(row['governorate_id']),
    ].where((value) => value.trim().isNotEmpty && value.trim() != '—').toList();
    final query = parts.join('، ');
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query.isEmpty ? 'مصر' : query});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'تعذر فتح خرائط Google. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.');
    }
  }

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .3))),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}