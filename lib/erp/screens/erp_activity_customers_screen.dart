import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _customerActivityPurple = Color(0xFF3E007D);
const _customerActivityOrange = Color(0xFFFFA015);

class ErpActivityCustomersScreen extends StatefulWidget {
  const ErpActivityCustomersScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpActivityCustomersScreen> createState() => _ErpActivityCustomersScreenState();
}

class _ErpActivityCustomersScreenState extends State<ErpActivityCustomersScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _workspaces = [];
  final Map<String, List<Map<String, dynamic>>> _categories = {};

  String _s(Object? value) => (value ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpActivityCustomersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  Future<void> _load() async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty) {
      setState(() { _loading = false; _error = 'لا توجد شركة محددة.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _db
          .from('erp_business_workspaces')
          .select('id,workspace_name,activity_type,account_kind,is_active')
          .eq('platform_company_id', companyId)
          .eq('is_active', true)
          .eq('account_kind', 'supplier')
          .order('activity_type')
          .order('workspace_name');
      final workspaces = (result as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final categories = <String, List<Map<String, dynamic>>>{};
      for (final workspace in workspaces) {
        final workspaceId = _s(workspace['id']);
        final rows = await _db
            .from('erp_activity_customer_categories')
            .select('id,workspace_id,activity_type,activity_name,customer_category,is_active')
            .eq('company_id', companyId)
            .eq('workspace_id', workspaceId)
            .order('customer_category');
        categories[workspaceId] = (rows as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _categories
          ..clear()
          ..addAll(categories);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل عملاء النشاطات: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCategory(Map<String, dynamic> workspace, {Map<String, dynamic>? row}) async {
    final controller = TextEditingController(text: _s(row?['customer_category']));
    var active = row?['is_active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(row == null ? 'إضافة فئة عملاء' : 'تعديل فئة العملاء'),
          content: SizedBox(
            width: 390,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text('نوع النشاط: ${_s(workspace['activity_type'])}'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('النشاط: ${_s(workspace['workspace_name'])}'),
              ),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم فئة العملاء *'),
              ),
              CheckboxListTile(
                value: active,
                onChanged: (value) => refresh(() => active = value ?? false),
                title: const Text('الفئة مفعلة'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true) {
      controller.dispose();
      return;
    }
    final companyId = (widget.companyId ?? '').trim();
    final name = controller.text.trim();
    controller.dispose();
    if (name.isEmpty || companyId.isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'company_id': companyId,
        'workspace_id': _s(workspace['id']),
        'activity_type': _s(workspace['activity_type']),
        'activity_name': _s(workspace['workspace_name']),
        'customer_category': name,
        'is_active': active,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (row != null) {
        await _db.from('erp_activity_customer_categories')
            .update(payload).eq('id', _s(row['id']));
      } else {
        await _db.from('erp_activity_customer_categories').upsert(
          payload,
          onConflict: 'company_id,workspace_id,customer_category',
        );
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ فئة العملاء: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فئة العملاء'),
        content: Text('هل تريد حذف فئة «${_s(row['customer_category'])}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('erp_activity_customer_categories').delete().eq('id', _s(row['id']));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف الفئة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final workspace in _workspaces) {
      groups.putIfAbsent(_s(workspace['activity_type']), () => []).add(workspace);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FC),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.white,
          child: Row(children: [
            const Icon(Icons.groups_2_outlined, color: _customerActivityPurple),
            const SizedBox(width: 8),
            const Expanded(child: Text('عملاء النشاطات', style: TextStyle(
              color: _customerActivityPurple, fontWeight: FontWeight.w800, fontSize: 17,
            ))),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ]),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _workspaces.isEmpty
                  ? const Center(child: Text('لا توجد أنشطة مرتبطة بالشركة. أضف النشاط أولًا من شاشة فروع النشاطات.'))
                  : ListView(
                      padding: const EdgeInsets.all(10),
                      children: groups.entries.map((group) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(group.key, style: const TextStyle(
                            color: _customerActivityPurple, fontWeight: FontWeight.w800,
                          )),
                          subtitle: Text('${group.value.length} نشاط'),
                          children: group.value.map((workspace) {
                            final id = _s(workspace['id']);
                            final rows = _categories[id] ?? const <Map<String, dynamic>>[];
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(start: 10, end: 10, bottom: 10),
                              child: Card(
                                color: const Color(0xFFF8F4FC),
                                child: ExpansionTile(
                                  initiallyExpanded: true,
                                  title: Text(_s(workspace['workspace_name']),
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('فئات العملاء: ${rows.where((r) => r['is_active'] == true).length} مفعلة'),
                                  trailing: IconButton(
                                    tooltip: 'إضافة فئة',
                                    onPressed: _saving ? null : () => _editCategory(workspace),
                                    icon: const Icon(Icons.add_circle_outline, color: _customerActivityOrange),
                                  ),
                                  children: rows.isEmpty
                                      ? [const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text('لم تُضف فئات عملاء لهذا النشاط بعد.'),
                                        )]
                                      : rows.map((row) => ListTile(
                                          dense: true,
                                          leading: Checkbox(
                                            shape: const CircleBorder(),
                                            value: row['is_active'] == true,
                                            onChanged: (value) async {
                                              try {
                                                await _db.from('erp_activity_customer_categories')
                                                    .update({'is_active': value ?? false})
                                                    .eq('id', _s(row['id']));
                                                await _load();
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('تعذر تحديث الفئة: $e')),
                                                );
                                              }
                                            },
                                          ),
                                          title: Text(_s(row['customer_category'])),
                                          trailing: PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') _editCategory(workspace, row: row);
                                              if (value == 'delete') _deleteCategory(row);
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                              PopupMenuItem(value: 'delete', child: Text('حذف')),
                                            ],
                                          ),
                                        )).toList(),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )).toList(),
                    ),
        ),
      ]),
    );
  }
}
