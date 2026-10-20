import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _costPurple = Color(0xFF3E007D);

class ErpCostCentersScreen extends StatefulWidget {
  const ErpCostCentersScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpCostCentersScreen> createState() => _ErpCostCentersScreenState();
}

class _ErpCostCentersScreenState extends State<ErpCostCentersScreen> {
  SupabaseClient? _db;
  List<Map<String, dynamic>> _centers = [];
  List<Map<String, dynamic>> _branches = [];
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
  void didUpdateWidget(covariant ErpCostCentersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  String _s(dynamic value) => (value ?? '').toString();

  Future<void> _load() async {
    final companyId = (widget.companyId ?? '').trim();
    if (_db == null || companyId.isEmpty) {
      setState(() { _loading = false; _error = _db == null ? 'سجّل الدخول إلى Supabase أولًا.' : 'لا توجد شركة نشطة مرتبطة بالمستخدم.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final centers = await _db!
          .from('erp_cost_centers')
          .select('id, center_code, center_name, branch_id, parent_id, is_active')
          .eq('company_id', companyId)
          .order('center_code');
      final branches = await _db!
          .from('erp_branches')
          .select('id, branch_code, branch_name')
          .eq('company_id', companyId)
          .order('branch_code');
      if (!mounted) return;
      setState(() {
        _centers = (centers as List).whereType<Map<String, dynamic>>().toList(growable: false);
        _branches = (branches as List).whereType<Map<String, dynamic>>().toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل مراكز التكلفة. تأكد من تطبيق erp_cost_centers_schema.sql: $error'; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final code = TextEditingController(text: _s(row?['center_code']));
    final name = TextEditingController(text: _s(row?['center_name']));
    String branchId = _s(row?['branch_id']);
    String parentId = _s(row?['parent_id']);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text(row == null ? 'إضافة مركز تكلفة' : 'تعديل مركز التكلفة'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'كود مركز التكلفة *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم مركز التكلفة *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _branches.any((b) => _s(b['id']) == branchId) ? branchId : '',
                decoration: const InputDecoration(labelText: 'الفرع (اختياري)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('بدون فرع محدد')),
                  ..._branches.map((b) => DropdownMenuItem(value: _s(b['id']), child: Text('${_s(b['branch_code'])} — ${_s(b['branch_name'])}'))),
                ],
                onChanged: (value) => refresh(() => branchId = value ?? ''),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: row != null && parentId == _s(row['id']) ? '' : parentId,
                decoration: const InputDecoration(labelText: 'مركز التكلفة الأب (اختياري)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('بدون أب')),
                  ..._centers.where((center) => _s(center['id']) != _s(row?['id'])).map((center) => DropdownMenuItem(value: _s(center['id']), child: Text('${_s(center['center_code'])} — ${_s(center['center_name'])}'))),
                ],
                onChanged: (value) => refresh(() => parentId = value ?? ''),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      )),
    );
    if (result != true) { code.dispose(); name.dispose(); return; }
    try {
      final companyId = (widget.companyId ?? '').trim();
      if (companyId.isEmpty) throw StateError('لا توجد شركة نشطة.');
      if (code.text.trim().isEmpty || name.text.trim().isEmpty) throw ArgumentError('كود واسم مركز التكلفة مطلوبان.');
      if (row != null && parentId == _s(row['id'])) throw ArgumentError('لا يمكن ربط مركز التكلفة بنفسه.');
      final payload = <String, Object?>{
        'company_id': companyId,
        'center_code': code.text.trim(),
        'center_name': name.text.trim(),
        'branch_id': branchId.isEmpty ? null : branchId,
        'parent_id': parentId.isEmpty ? null : parentId,
        'is_active': row?['is_active'] != false,
      };
      if (row == null) {
        payload['is_active'] = true;
        await _db!.from('erp_cost_centers').insert(payload);
      } else {
        await _db!.from('erp_cost_centers').update(payload).eq('id', row['id']).eq('company_id', companyId);
      }
      if (mounted) setState(() => _message = 'تم حفظ مركز التكلفة في قاعدة البيانات.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ مركز التكلفة: $error');
    } finally {
      code.dispose(); name.dispose();
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    try {
      await _db!
          .from('erp_cost_centers')
          .update({'is_active': row['is_active'] != true})
          .eq('id', row['id'])
          .eq('company_id', (widget.companyId ?? '').trim());
      if (mounted) setState(() => _message = 'تم تغيير حالة مركز التكلفة.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تغيير الحالة: $error');
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مركز التكلفة'),
        content: Text('هل تريد حذف «${_s(row['center_name'])}»؟ لا يمكن حذفه إذا كان له مراكز فرعية مرتبطة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _db!
          .from('erp_cost_centers')
          .delete()
          .eq('id', row['id'])
          .eq('company_id', (widget.companyId ?? '').trim());
      if (mounted) setState(() => _message = 'تم حذف مركز التكلفة.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حذف المركز؛ قد يكون مرتبطًا بمراكز فرعية أو بحركات مالية: $error');
    }
  }

  Future<void> _seedStandardTemplate() async {
    final companyId = (widget.companyId ?? '').trim();
    if (_db == null || companyId.isEmpty) {
      setState(() => _error = 'اختر شركة نشطة وسجّل الدخول أولاً.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء مراكز التكلفة القياسية'),
        content: const Text('سيضيف البرنامج هيكلًا مناسبًا لتوزيع المواد الغذائية بالجملة، مع الحفاظ على المراكز الموجودة وعدم استبدالها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إنشاء الهيكل')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final result = await _db!.rpc('erp_seed_standard_cost_centers', params: {'p_company_id': companyId});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'تم إنشاء الهيكل القياسي. عدد المراكز الجديدة: ${result ?? 0}.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر إنشاء الهيكل القياسي. تأكد من تطبيق supabase/erp_cost_centers_standard_template.sql ثم أعد المحاولة. التفاصيل: $error';
      });
    }
  }

  String _branchLabel(String? id) {
    if (id == null || id.isEmpty) return 'بدون فرع';
    for (final row in _branches) {
      if (_s(row['id']) == id) return '${_s(row['branch_code'])} — ${_s(row['branch_name'])}';
    }
    return 'فرع غير متاح';
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: _costPurple.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.account_balance_outlined, color: _costPurple)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مراكز التكلفة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _costPurple)),
          SizedBox(height: 4),
          Text('تصنيف المصروفات والإيرادات حسب مركز وفرع النشاط.', style: TextStyle(color: Colors.black54)),
        ])),
        IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        OutlinedButton.icon(onPressed: _loading ? null : _seedStandardTemplate, icon: const Icon(Icons.account_tree_outlined), label: const Text('إنشاء الهيكل القياسي')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة مركز')),
      ]),
      const SizedBox(height: 12),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
      else if (_centers.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد مراكز تكلفة مسجلة بعد.')))
      else
        ..._centers.map((row) {
          final active = row['is_active'] == true;
          final parent = _centers.where((item) => _s(item['id']) == _s(row['parent_id']));
          final parentLabel = parent.isEmpty ? 'بدون مركز أب' : _s(parent.first['center_name']);
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: Colors.grey.shade300)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: _costPurple.withValues(alpha: .09), child: const Icon(Icons.account_balance_outlined, color: _costPurple)),
              title: Text('${_s(row['center_code'])} — ${_s(row['center_name'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_branchLabel(row['branch_id']?.toString())}\n$parentLabel • ${active ? 'نشط' : 'موقوف'}', maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Wrap(spacing: 0, children: [
                IconButton(tooltip: 'تعديل', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined, color: _costPurple)),
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
