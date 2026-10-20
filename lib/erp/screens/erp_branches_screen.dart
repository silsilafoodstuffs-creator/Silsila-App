import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _branchPurple = Color(0xFF3E007D);

class ErpBranchesScreen extends StatefulWidget {
  const ErpBranchesScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpBranchesScreen> createState() => _ErpBranchesScreenState();
}

class _ErpBranchesScreenState extends State<ErpBranchesScreen> {
  SupabaseClient? _db;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  String? _message;

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
      final result = await _db!
          .from('erp_branches')
          .select('id, branch_code, branch_name, phone, address, is_main, is_active')
          .eq('company_id', companyId)
          .order('branch_code');
      if (!mounted) return;
      setState(() {
        _rows = (result as List).whereType<Map<String, dynamic>>().toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل الفروع: $error'; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final code = TextEditingController(text: _s(row?['branch_code']));
    final name = TextEditingController(text: _s(row?['branch_name']));
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
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الفرع *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder())),
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
      code.dispose(); name.dispose(); phone.dispose(); address.dispose();
      return;
    }
    try {
      final companyId = (widget.companyId ?? '').trim();
      if (companyId.isEmpty) throw StateError('لا توجد شركة نشطة.');
      if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
        throw ArgumentError('كود الفرع واسم الفرع مطلوبان.');
      }
      final payload = <String, Object?>{
        'company_id': companyId,
        'branch_code': code.text.trim(),
        'branch_name': name.text.trim(),
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
      code.dispose(); name.dispose(); phone.dispose(); address.dispose();
    }
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
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

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 5, top: 3, bottom: 3),
    child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), visualDensity: VisualDensity.compact),
      onPressed: action, icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
  );

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
      Card(color: _branchPurple, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('الفروع ومراكز التشغيل', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
          const Text('إدارة دليل الفروع الفعلي المرتبط بالشركة.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _loading ? null : () => _edit()),
            _quickTask('تعديل', Icons.edit_outlined, const Color(0xFFEF9B13), _rows.isEmpty ? null : () => _edit(_rows.first)),
            _quickTask('حذف', Icons.delete_outline, Colors.red, _rows.isEmpty ? null : () => _delete(_rows.first)),
            _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewDirectory),
          ])),
        ]),
      )),
      const SizedBox(height: 12),
      const SizedBox(height: 12),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
      else if (_rows.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد فروع مسجلة بعد.')))
      else
        ..._rows.map((row) {
          final active = row['is_active'] == true;
          final main = row['is_main'] == true;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: main ? _branchPurple : Colors.grey.shade300)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: _branchPurple.withValues(alpha: .09), child: Icon(main ? Icons.star : Icons.account_tree_outlined, color: _branchPurple)),
              title: Text('${_s(row['branch_code'])} — ${_s(row['branch_name'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${main ? 'الفرع الرئيسي • ' : ''}${active ? 'نشط' : 'موقوف'} • ${_s(row['phone']).isEmpty ? 'لا يوجد هاتف' : _s(row['phone'])}\n${_s(row['address'])}', maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Wrap(spacing: 0, children: [
                IconButton(tooltip: 'تعديل', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined, color: _branchPurple)),
                IconButton(tooltip: active ? 'إيقاف' : 'تفعيل', onPressed: () => _toggle(row), icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline, color: active ? Colors.orange : Colors.green)),
                IconButton(tooltip: 'حذف', onPressed: () => _delete(row), icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ]),
            ),
          );
        }),
    ]),
  );

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .3))),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
