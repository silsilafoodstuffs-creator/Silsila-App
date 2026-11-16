import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _shiftPurple = Color(0xFF3E007D);
const _shiftOrange = Color(0xFFFFA015);
const _shiftRed = Color(0xFFD32F2F);

class ErpHrShiftMasterScreen extends StatefulWidget {
  const ErpHrShiftMasterScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpHrShiftMasterScreen> createState() => _ErpHrShiftMasterScreenState();
}

class _ErpHrShiftMasterScreenState extends State<ErpHrShiftMasterScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _assignments = [];

  static const _weekdays = <String>[
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];
  // Database uses ISO weekday numbers: Monday=1 through Sunday=7.
  static const _weekdayNumbers = <String, int>{
    'الأحد': 7, 'الإثنين': 1, 'الثلاثاء': 2, 'الأربعاء': 3,
    'الخميس': 4, 'الجمعة': 5, 'السبت': 6,
  };

  String get _companyId => (widget.companyId ?? '').trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpHrShiftMasterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isAssignmentActive(Map<String, dynamic> row) {
    final end = row['effective_to']?.toString();
    return end == null || end.isEmpty || end.compareTo(_today()) >= 0;
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = 'لا توجد شركة نشطة مرتبطة بالمستخدم.'; });
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _db.from('erp_hr_shifts').select().eq('company_id', _companyId).eq('is_active', true).order('shift_name'),
        _db.from('erp_employees').select('id,employee_code,full_name,department_id,branch_id').eq('company_id', _companyId).eq('is_active', true).order('full_name'),
        _db.from('erp_branches').select('id,branch_code,branch_name').eq('company_id', _companyId).eq('is_active', true).order('branch_name'),
        _db.from('erp_hr_departments').select('id,department_code,name_ar').eq('company_id', _companyId).eq('is_active', true).order('name_ar'),
        _db.from('erp_hr_shift_assignments').select('id,shift_id,employee_id,department_code,branch_id,effective_from,effective_to').eq('company_id', _companyId).order('effective_from', ascending: false),
      ]);
      if (!mounted) return;
      setState(() {
        _shifts = List<Map<String, dynamic>>.from(results[0] as List);
        _employees = List<Map<String, dynamic>>.from(results[1] as List);
        _branches = List<Map<String, dynamic>>.from(results[2] as List);
        _departments = List<Map<String, dynamic>>.from(results[3] as List);
        _assignments = List<Map<String, dynamic>>.from(results[4] as List);
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل الورديات والتوزيعات: $error'; });
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  int _activeAssignmentCount(String shiftId) => _assignments
      .where((row) => row['shift_id']?.toString() == shiftId && _isAssignmentActive(row))
      .length;

  Future<void> _editShift([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['shift_name']?.toString() ?? '');
    final start = TextEditingController(text: _time(existing?['start_time']?.toString()) ?? '08:00');
    final end = TextEditingController(text: _time(existing?['end_time']?.toString()) ?? '16:00');
    final grace = _map(existing?['grace_rules']);
    final arrival = TextEditingController(text: (grace['arrival_minutes'] ?? 10).toString());
    final departure = TextEditingController(text: (grace['departure_minutes'] ?? 10).toString());
    final monthly = TextEditingController(text: (grace['monthly_minutes'] ?? 60).toString());
    final multiplier = TextEditingController(text: (grace['overrun_multiplier'] ?? 1).toString());
    final selectedDays = <String>{
      for (final entry in _weekdayNumbers.entries)
        if ((existing?['weekly_holidays'] as List? ?? const []).contains(entry.value)) entry.key,
    };
    String? branchId = existing?['branch_id']?.toString();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(existing == null ? 'إضافة وردية' : 'تعديل وردية'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'اسم الوردية'),
                      validator: (value) => (value ?? '').trim().isEmpty ? 'اسم الوردية مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: start,
                        decoration: const InputDecoration(labelText: 'من (HH:mm)'),
                        validator: _validateTime,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(
                        controller: end,
                        decoration: const InputDecoration(labelText: 'إلى (HH:mm)'),
                        validator: _validateTime,
                      )),
                    ]),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: branchId,
                      decoration: const InputDecoration(labelText: 'الفرع (اختياري)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('كل فروع الشركة')),
                        ..._branches.map((branch) => DropdownMenuItem<String?>(
                          value: branch['id'].toString(),
                          child: Text('${branch['branch_name']} (${branch['branch_code']})'),
                        )),
                      ],
                      onChanged: (value) => refresh(() => branchId = value),
                    ),
                    const SizedBox(height: 12),
                    const Text('العطلة الأسبوعية', style: TextStyle(fontWeight: FontWeight.w800, color: _shiftPurple)),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: _weekdays.map((day) => FilterChip(
                        label: Text(day),
                        selected: selectedDays.contains(day),
                        onSelected: (selected) => refresh(() {
                          if (selected) { selectedDays.add(day); } else { selectedDays.remove(day); }
                        }),
                      )).toList(),
                    ),
                    const Divider(),
                    const Text('سماح الحضور والانصراف', style: TextStyle(fontWeight: FontWeight.w800, color: _shiftPurple)),
                    Row(children: [
                      Expanded(child: _numberField(arrival, 'سماح بداية الحضور بالدقائق', whole: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(departure, 'سماح نهاية الانصراف بالدقائق', whole: true)),
                    ]),
                    Row(children: [
                      Expanded(child: _numberField(monthly, 'السماح الشهري بالدقائق', whole: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(multiplier, 'معامل التجاوز')),
                    ]),
                    const SizedBox(height: 8),
                    const Text('يتم توليد كود الوردية تلقائيًا وفق سياسة التكويد المركزية عند الحفظ.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _shiftPurple),
              onPressed: _saving ? null : () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (existing != null &&
                    branchId != existing['branch_id']?.toString() &&
                    _activeAssignmentCount(existing['id'].toString()) > 0) {
                  _showMessage('لا يمكن تغيير فرع الوردية قبل إنهاء توزيعات الموظفين الحالية.', isError: true);
                  return;
                }
                final startValue = start.text.trim();
                final endValue = end.text.trim();
                final payload = <String, dynamic>{
                  'company_id': _companyId,
                  'shift_name': name.text.trim(),
                  'start_time': startValue,
                  'end_time': endValue,
                  'weekly_holidays': selectedDays.map((day) => _weekdayNumbers[day]!).toList()..sort(),
                  'grace_rules': {
                    ...grace,
                    'arrival_minutes': int.parse(arrival.text),
                    'departure_minutes': int.parse(departure.text),
                    'monthly_minutes': int.parse(monthly.text),
                    'overrun_multiplier': double.parse(multiplier.text),
                  },
                  'is_active': true,
                };
                if (branchId == null) { payload['branch_id'] = null; } else { payload['branch_id'] = branchId; }
                setState(() => _saving = true);
                try {
                  if (existing == null) {
                    await _db.from('erp_hr_shifts').insert(payload);
                  } else {
                    await _db.from('erp_hr_shifts').update(payload..remove('company_id')).eq('company_id', _companyId).eq('id', existing['id'].toString());
                  }
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  await _load();
                } catch (error) {
                  if (mounted) _showMessage('تعذر حفظ الوردية: $error', isError: true);
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
              child: const Text('حفظ الوردية'),
            ),
          ],
        ),
      ),
    );
    name.dispose(); start.dispose(); end.dispose();
    arrival.dispose(); departure.dispose(); monthly.dispose(); multiplier.dispose();
  }

  Map<String, dynamic>? _branchFor(String? id) {
    if (id == null) return null;
    for (final branch in _branches) {
      if (branch['id']?.toString() == id) return branch;
    }
    return null;
  }

  String? _weekdayName(int? number) {
    if (number == null) return null;
    for (final entry in _weekdayNumbers.entries) {
      if (entry.value == number) return entry.key;
    }
    return null;
  }

  String? _validateTime(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) return 'اكتب الوقت بصيغة HH:mm';
    return null;
  }

  String? _time(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  Widget _numberField(TextEditingController controller, String label, {bool whole = false}) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !whole),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final text = (value ?? '').trim();
      final number = whole ? int.tryParse(text)?.toDouble() : double.tryParse(text);
      if (number == null || number < 0) return whole ? 'عدد صحيح غير سالب مطلوب' : 'قيمة رقمية غير سالبة مطلوبة';
      return null;
    },
  );

  Future<void> _deactivateShift(Map<String, dynamic> shift) async {
    final id = shift['id'].toString();
    final assignedCount = _activeAssignmentCount(id);
    if (assignedCount > 0) {
      _showMessage('لا يمكن إيقاف الوردية قبل إنهاء أو نقل توزيع $assignedCount موظفًا.', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إيقاف الوردية'),
        content: Text('سيتم إيقاف «${shift['shift_name']}» مع الاحتفاظ بسجل التوزيعات السابقة. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _shiftRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _db.from('erp_hr_shifts').update({'is_active': false}).eq('company_id', _companyId).eq('id', id);
      await _load();
    } catch (error) {
      _showMessage('تعذر إيقاف الوردية: $error', isError: true);
    }
  }

  Future<void> _assignEmployees(Map<String, dynamic> shift) async {
    final shiftId = shift['id'].toString();
    final branchId = shift['branch_id']?.toString();
    final activeAssignments = _assignments.where(_isAssignmentActive).toList();
    final selected = <String>{
      for (final row in activeAssignments)
        if (row['shift_id']?.toString() == shiftId) row['employee_id'].toString(),
    };
    final initial = Set<String>.from(selected);
    final employees = _employees.where((employee) =>
      branchId == null || employee['branch_id']?.toString() == branchId
    ).toList();
    if (employees.isEmpty) {
      _showMessage('لا يوجد موظفون نشطون متاحون لهذا الفرع.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) {
                return AlertDialog(
            title: Text('توزيع الموظفين — ${shift['shift_name']}'),
            content: SizedBox(
              width: 560,
              height: 480,
              child: Column(
                children: [
                  Text('حدد الموظفين الذين يعملون على هذه الوردية. تاريخ بداية التوزيع هو ${_today()}.', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final id = employee['id'].toString();
                        final checked = selected.contains(id);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          title: Text(employee['full_name']?.toString() ?? ''),
                          subtitle: Text(employee['employee_code']?.toString() ?? ''),
                          onChanged: (value) => refresh(() {
                            if (value == true) { selected.add(id); } else { selected.remove(id); }
                          }),
                        );
                      },
                    ),
                  ),
                  Align(alignment: AlignmentDirectional.centerStart, child: Text('المحدد: ${selected.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: _shiftPurple))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _shiftPurple),
                onPressed: () async {
                  final removed = initial.difference(selected);
                  final added = selected.difference(initial);
                  try {
                    for (final row in activeAssignments.where((row) =>
                      row['shift_id']?.toString() == shiftId &&
                      removed.contains(row['employee_id']?.toString())
                    )) {
                      final effectiveFrom = row['effective_from']?.toString() ?? _today();
                      if (effectiveFrom.compareTo(_today()) <= 0) {
                        await _db.from('erp_hr_shift_assignments')
                            .update({'effective_to': _today()})
                            .eq('company_id', _companyId)
                            .eq('id', row['id'].toString());
                      } else {
                        await _db.from('erp_hr_shift_assignments')
                            .delete()
                            .eq('company_id', _companyId)
                            .eq('id', row['id'].toString());
                      }
                    }
                    final departmentCodes = {
                      for (final department in _departments)
                        department['id'].toString(): department['department_code']?.toString(),
                    };
                    final conflicts = <String>[];
                    final rowsToInsert = <Map<String, dynamic>>[];
                    for (final employeeId in added) {
                      final employee = employees.firstWhere((row) => row['id'].toString() == employeeId);
                      final hasConflict = activeAssignments.any((row) =>
                        row['employee_id']?.toString() == employeeId &&
                        row['shift_id']?.toString() != shiftId
                      );
                      if (hasConflict) {
                        conflicts.add(employee['full_name']?.toString() ?? employeeId);
                        continue;
                      }
                      rowsToInsert.add({
                        'company_id': _companyId,
                        'shift_id': shiftId,
                        'employee_id': employeeId,
                        'department_code': departmentCodes[employee['department_id']?.toString()],
                        'branch_id': employee['branch_id'],
                        'effective_from': _today(),
                      });
                    }
                    if (rowsToInsert.isNotEmpty) {
                      await _db.from('erp_hr_shift_assignments').insert(rowsToInsert);
                    }
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await _load();
                    if (conflicts.isNotEmpty) {
                      _showMessage('لم يتم توزيع ${conflicts.length} موظفًا لوجود وردية سارية أخرى: ${conflicts.take(3).join('، ')}', isError: true);
                    } else {
                      _showMessage('تم حفظ توزيع الموظفين على الوردية.');
                    }
                  } catch (error) {
                    _showMessage('تعذر حفظ التوزيع: $error', isError: true);
                  }
                },
                child: const Text('حفظ التوزيع'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? _shiftRed : _shiftPurple,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Text('الورديات وجداول العمل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _shiftPurple))),
          FilledButton.icon(
            onPressed: _saving ? null : () => _editShift(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة وردية'),
            style: FilledButton.styleFrom(backgroundColor: _shiftPurple),
          ),
          IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh, color: _shiftOrange)),
        ]),
        const SizedBox(height: 6),
        const Text('إدارة الورديات الفعلية من جداول الموارد البشرية، وتوزيع الموظفين عليها بتواريخ سريان محفوظة في قاعدة البيانات.', style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        if (_shifts.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد ورديات نشطة. أضف وردية لبدء تنظيم جداول العمل.', textAlign: TextAlign.center)))
        else
          ..._shifts.map((shift) {
            final id = shift['id'].toString();
            final branch = _branchFor(shift['branch_id']?.toString());
            final days = (shift['weekly_holidays'] as List? ?? const [])
                .map((value) => _weekdayName(int.tryParse(value.toString())))
                .whereType<String>().toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(shift['shift_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, color: _shiftPurple, fontSize: 17))),
                    Chip(label: Text(shift['shift_code']?.toString() ?? '—')),
                  ]),
                  Text('${_time(shift['start_time']?.toString())} — ${_time(shift['end_time']?.toString())}${shift['crosses_midnight'] == true ? ' (تعبر منتصف الليل)' : ''}'),
                  Text('الفرع: ${branch?['branch_name'] ?? 'كل الفروع'}  •  العطلات: ${days.isEmpty ? 'لا يوجد' : days.join('، ')}'),
                  Text('الموظفون الموزعون حاليًا: ${_activeAssignmentCount(id)}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    OutlinedButton.icon(onPressed: () => _editShift(shift), icon: const Icon(Icons.edit_outlined, color: _shiftOrange), label: const Text('تعديل')),
                    OutlinedButton.icon(onPressed: () => _assignEmployees(shift), icon: const Icon(Icons.groups_outlined, color: _shiftOrange), label: const Text('توزيع الموظفين')),
                    OutlinedButton.icon(onPressed: () => _deactivateShift(shift), icon: const Icon(Icons.pause_circle_outline, color: _shiftRed), label: const Text('إيقاف')),
                  ]),
                ]),
              ),
            );
          }),
      ],
    );
  }
}
).hasMatch(text)) return 'اكتب الوقت بصيغة HH:mm';
    return null;
  }

  String? _time(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  Widget _numberField(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final number = double.tryParse((value ?? '').trim());
      if (number == null || number < 0) return 'قيمة رقمية غير سالبة مطلوبة';
      return null;
    },
  );

  Future<void> _deactivateShift(Map<String, dynamic> shift) async {
    final id = shift['id'].toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إيقاف الوردية'),
        content: Text('سيتم إيقاف «${shift['shift_name']}» مع الاحتفاظ بسجل التوزيعات السابقة. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _shiftRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _db.from('erp_hr_shifts').update({'is_active': false}).eq('company_id', _companyId).eq('id', id);
      await _load();
    } catch (error) {
      _showMessage('تعذر إيقاف الوردية: $error', isError: true);
    }
  }

  Future<void> _assignEmployees(Map<String, dynamic> shift) async {
    final shiftId = shift['id'].toString();
    final branchId = shift['branch_id']?.toString();
    final activeAssignments = _assignments.where(_isAssignmentActive).toList();
    final selected = <String>{
      for (final row in activeAssignments)
        if (row['shift_id']?.toString() == shiftId) row['employee_id'].toString(),
    };
    final initial = Set<String>.from(selected);
    final employees = _employees.where((employee) =>
      branchId == null || employee['branch_id']?.toString() == branchId
    ).toList();
    if (employees.isEmpty) {
      _showMessage('لا يوجد موظفون نشطون متاحون لهذا الفرع.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) {
          return AlertDialog(
            title: Text('توزيع الموظفين — ${shift['shift_name']}'),
            content: SizedBox(
              width: 560,
              height: 480,
              child: Column(
                children: [
                  Text('حدد الموظفين الذين يعملون على هذه الوردية. تاريخ بداية التوزيع هو ${_today()}.', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final id = employee['id'].toString();
                        final checked = selected.contains(id);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          title: Text(employee['full_name']?.toString() ?? ''),
                          subtitle: Text(employee['employee_code']?.toString() ?? ''),
                          onChanged: (value) => refresh(() {
                            if (value == true) { selected.add(id); } else { selected.remove(id); }
                          }),
                        );
                      },
                    ),
                  ),
                  Align(alignment: AlignmentDirectional.centerStart, child: Text('المحدد: ${selected.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: _shiftPurple))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _shiftPurple),
                onPressed: () async {
                  final removed = initial.difference(selected);
                  final added = selected.difference(initial);
                  try {
                    for (final row in activeAssignments.where((row) =>
                      row['shift_id']?.toString() == shiftId &&
                      removed.contains(row['employee_id']?.toString())
                    )) {
                      final effectiveFrom = row['effective_from']?.toString() ?? _today();
                      if (effectiveFrom.compareTo(_today()) <= 0) {
                        await _db.from('erp_hr_shift_assignments')
                            .update({'effective_to': _today()})
                            .eq('company_id', _companyId)
                            .eq('id', row['id'].toString());
                      }
                    }
                    final departmentCodes = {
                      for (final department in _departments)
                        department['id'].toString(): department['department_code']?.toString(),
                    };
                    final conflicts = <String>[];
                    final rowsToInsert = <Map<String, dynamic>>[];
                    for (final employeeId in added) {
                      final employee = employees.firstWhere((row) => row['id'].toString() == employeeId);
                      final hasConflict = activeAssignments.any((row) =>
                        row['employee_id']?.toString() == employeeId &&
                        row['shift_id']?.toString() != shiftId
                      );
                      if (hasConflict) {
                        conflicts.add(employee['full_name']?.toString() ?? employeeId);
                        continue;
                      }
                      rowsToInsert.add({
                        'company_id': _companyId,
                        'shift_id': shiftId,
                        'employee_id': employeeId,
                        'department_code': departmentCodes[employee['department_id']?.toString()],
                        'branch_id': employee['branch_id'],
                        'effective_from': _today(),
                      });
                    }
                    if (rowsToInsert.isNotEmpty) {
                      await _db.from('erp_hr_shift_assignments').insert(rowsToInsert);
                    }
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await _load();
                    if (conflicts.isNotEmpty) {
                      _showMessage('لم يتم توزيع ${conflicts.length} موظفًا لوجود وردية سارية أخرى: ${conflicts.take(3).join('، ')}', isError: true);
                    } else {
                      _showMessage('تم حفظ توزيع الموظفين على الوردية.');
                    }
                  } catch (error) {
                    _showMessage('تعذر حفظ التوزيع: $error', isError: true);
                  }
                },
                child: const Text('حفظ التوزيع'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? _shiftRed : _shiftPurple,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Text('الورديات وجداول العمل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _shiftPurple))),
          FilledButton.icon(
            onPressed: _saving ? null : () => _editShift(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة وردية'),
            style: FilledButton.styleFrom(backgroundColor: _shiftPurple),
          ),
          IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh, color: _shiftOrange)),
        ]),
        const SizedBox(height: 6),
        const Text('إدارة الورديات الفعلية من جداول الموارد البشرية، وتوزيع الموظفين عليها بتواريخ سريان محفوظة في قاعدة البيانات.', style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        if (_shifts.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد ورديات نشطة. أضف وردية لبدء تنظيم جداول العمل.', textAlign: TextAlign.center)))
        else
          ..._shifts.map((shift) {
            final id = shift['id'].toString();
            final branch = _branchFor(shift['branch_id']?.toString());
            final days = (shift['weekly_holidays'] as List? ?? const [])
                .map((value) => _weekdayName(int.tryParse(value.toString())))
                .whereType<String>().toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(shift['shift_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, color: _shiftPurple, fontSize: 17))),
                    Chip(label: Text(shift['shift_code']?.toString() ?? '—')),
                  ]),
                  Text('${_time(shift['start_time']?.toString())} — ${_time(shift['end_time']?.toString())}${shift['crosses_midnight'] == true ? ' (تعبر منتصف الليل)' : ''}'),
                  Text('الفرع: ${branch?['branch_name'] ?? 'كل الفروع'}  •  العطلات: ${days.isEmpty ? 'لا يوجد' : days.join('، ')}'),
                  Text('الموظفون الموزعون حاليًا: ${_activeAssignmentCount(id)}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    OutlinedButton.icon(onPressed: () => _editShift(shift), icon: const Icon(Icons.edit_outlined, color: _shiftOrange), label: const Text('تعديل')),
                    OutlinedButton.icon(onPressed: () => _assignEmployees(shift), icon: const Icon(Icons.groups_outlined, color: _shiftOrange), label: const Text('توزيع الموظفين')),
                    OutlinedButton.icon(onPressed: () => _deactivateShift(shift), icon: const Icon(Icons.pause_circle_outline, color: _shiftRed), label: const Text('إيقاف')),
                  ]),
                ]),
              ),
            );
          }),
      ],
    );
  }
}
