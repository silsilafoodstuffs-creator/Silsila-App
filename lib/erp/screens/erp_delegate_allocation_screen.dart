import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _delegatePurple = Color(0xFF3E007D);
const _delegateOrange = Color(0xFFFFA015);

class ErpDelegateAllocationScreen extends StatefulWidget {
  const ErpDelegateAllocationScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpDelegateAllocationScreen> createState() => _ErpDelegateAllocationScreenState();
}

class _ErpDelegateAllocationScreenState extends State<ErpDelegateAllocationScreen> {
  SupabaseClient? _db;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _items = [];
  final Set<String> _assigned = {};
  final TextEditingController _search = TextEditingController();
  String? _employeeId;
  bool _loading = false;
  String? _error;
  String? _message;
  final Set<String> _savingItems = {};

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpDelegateAllocationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic value) => (value ?? '').toString();
  String _key(String employeeId, String itemId) => '$employeeId:$itemId';

  Future<void> _load() async {
    final companyId = (widget.companyId ?? '').trim();
    if (_db == null || companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = _db == null
            ? 'سجّل الدخول إلى Supabase أولًا.'
            : 'لا توجد شركة نشطة مرتبطة بالمستخدم.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final employeesRaw = await _db!
          .from('erp_employees')
          .select('id, employee_code, full_name, job_title')
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('full_name');
      final itemsRaw = await _db!
          .from('erp_items')
          .select('id, item_code, item_name, base_unit')
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('item_name');
      final assignmentsRaw = await _db!
          .from('erp_delegate_item_assignments')
          .select('employee_id, item_id')
          .eq('company_id', companyId)
          .eq('is_active', true);
      final employees = (employeesRaw as List)
          .whereType<Map<String, dynamic>>()
          .where((row) {
            final title = _s(row['job_title']).toLowerCase();
            return title.contains('مندوب') ||
                title.contains('مبيعات') ||
                title.contains('sales');
          })
          .toList(growable: false);
      final items = (itemsRaw as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final assigned = <String>{};
      for (final row in (assignmentsRaw as List).whereType<Map<String, dynamic>>()) {
        final employeeId = _s(row['employee_id']);
        final itemId = _s(row['item_id']);
        if (employeeId.isNotEmpty && itemId.isNotEmpty) {
          assigned.add(_key(employeeId, itemId));
        }
      }
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _items = items;
        _assigned
          ..clear()
          ..addAll(assigned);
        if (_employeeId == null || !employees.any((e) => _s(e['id']) == _employeeId)) {
          _employeeId = employees.isEmpty ? null : _s(employees.first['id']);
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المندوبين والأصناف أو جدول التوزيع. تأكد من تطبيق erp_delegate_item_assignments_schema.sql. التفاصيل: $error';
      });
    }
  }

  Future<void> _setAssignment(Map<String, dynamic> item, bool enabled) async {
    final companyId = (widget.companyId ?? '').trim();
    final employeeId = _employeeId;
    final itemId = _s(item['id']);
    if (companyId.isEmpty || employeeId == null || employeeId.isEmpty || itemId.isEmpty) return;
    final key = _key(employeeId, itemId);
    final wasAssigned = _assigned.contains(key);
    setState(() {
      _savingItems.add(itemId);
      if (enabled) {
        _assigned.add(key);
      } else {
        _assigned.remove(key);
      }
      _error = null;
      _message = null;
    });
    try {
      if (enabled) {
        await _db!.from('erp_delegate_item_assignments').upsert({
          'company_id': companyId,
          'employee_id': employeeId,
          'item_id': itemId,
          'is_active': true,
          'assigned_by': _db!.auth.currentUser?.id,
        }, onConflict: 'company_id,employee_id,item_id');
      } else {
        await _db!
            .from('erp_delegate_item_assignments')
            .update({'is_active': false})
            .eq('company_id', companyId)
            .eq('employee_id', employeeId)
            .eq('item_id', itemId);
      }
      if (mounted) setState(() => _message = 'تم حفظ توزيع الصنف في قاعدة البيانات.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasAssigned) {
          _assigned.add(key);
        } else {
          _assigned.remove(key);
        }
        _error = 'تعذر حفظ التوزيع: $error';
      });
    } finally {
      if (mounted) setState(() => _savingItems.remove(itemId));
    }
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 5, top: 3, bottom: 3),
    child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), visualDensity: VisualDensity.compact),
      onPressed: action, icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
  );

  Future<void> _previewDelegateData() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة توزيع المندوبين'),
      content: SizedBox(width: 700, child: _employees.isEmpty ? const Text('لا توجد بيانات موظفين محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _employees.take(100).map((r) => ListTile(
          dense: true,
          title: Text(_s(r['full_name']).isEmpty ? _s(r['employee_name']) : _s(r['full_name'])),
          subtitle: Text('كود الموظف: ${_s(r['employee_code'])}'),
          trailing: _s(r['id']) == _employeeId ? const Icon(Icons.check_circle, color: Colors.green) : null,
          onTap: () { Navigator.pop(ctx); setState(() => _employeeId = _s(r['id'])); },
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? employee;
    for (final row in _employees) {
      if (_s(row['id']) == _employeeId) { employee = row; break; }
    }
    final query = _search.text.trim().toLowerCase();
    final visibleItems = _items.where((item) =>
      _s(item['item_name']).toLowerCase().contains(query) ||
      _s(item['item_code']).toLowerCase().contains(query)
    ).toList(growable: false);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(color: _delegatePurple, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.assignment_ind_outlined, color: Color(0xFFFFA015), size: 27),
              SizedBox(width: 10),
              Expanded(child: Text('توزيع الأصناف على المندوبين', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
            ]),
            const Text('اختيار موظف مبيعات نشط وتحديد الأصناف المسموح له ببيعها.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('معاينة المندوبين', Icons.visibility_outlined, const Color(0xFF6841A5), _previewDelegateData),
            ])),
          ]),
        )),
        const SizedBox(height: 16),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String>(
                value: _employeeId,
                decoration: const InputDecoration(labelText: 'المندوب / موظف المبيعات', border: OutlineInputBorder()),
                items: _employees.map((row) => DropdownMenuItem(
                  value: _s(row['id']),
                  child: Text('${_s(row['employee_code'])} — ${_s(row['full_name'])}'),
                )).toList(),
                onChanged: (value) => setState(() => _employeeId = value),
              ),
              if (_employees.isEmpty && !_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('لا يوجد موظف نشط مصنف كمندوب أو مبيعات. أضف الموظف من الموارد البشرية وحدد المسمى الوظيفي أولًا.', style: TextStyle(color: Colors.deepOrange)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'بحث في الأصناف',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(employee == null ? 'قائمة الأصناف' : 'أصناف ${_s(employee['full_name'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          Text('${visibleItems.where((item) => _employeeId != null && _assigned.contains(_key(_employeeId!, _s(item['id'])))).length} محدد', style: const TextStyle(color: _delegatePurple, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد أصناف فعلية نشطة في قاعدة البيانات لهذا النشاط.')))
        else if (_employees.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا يمكن إنشاء توزيع قبل تسجيل مندوب/موظف مبيعات نشط.')))
        else if (visibleItems.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد أصناف مطابقة للبحث.')))
        else
          ...visibleItems.map((item) {
            final itemId = _s(item['id']);
            final checked = _employeeId != null && _assigned.contains(_key(_employeeId!, itemId));
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: checked ? _delegateOrange : Colors.grey.shade300)),
              child: CheckboxListTile(
                value: checked,
                onChanged: _savingItems.contains(itemId) ? null : (value) => _setAssignment(item, value == true),
                title: Text(_s(item['item_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_s(item['item_code'])} • ${_s(item['base_unit'])}'),
                secondary: _savingItems.contains(itemId)
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.inventory_2_outlined, color: _delegatePurple),
                activeColor: _delegatePurple,
              ),
            );
          }),
      ]),
    );
  }

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
