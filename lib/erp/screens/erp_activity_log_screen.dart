import 'package:flutter/material.dart';

import '../services/erp_app_management_service.dart';
import '../services/erp_app_settings.dart';

class ErpActivityLogScreen extends StatefulWidget {
  const ErpActivityLogScreen({super.key, required this.companyId});

  final String? companyId;

  @override
  State<ErpActivityLogScreen> createState() => _ErpActivityLogScreenState();
}

class _ErpActivityLogScreenState extends State<ErpActivityLogScreen> {
  final ErpAppManagementService _service = ErpAppManagementService();
  late Future<List<ErpAppActivityEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ErpAppActivityEntry>> _load() {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      return Future<List<ErpAppActivityEntry>>.error(
        StateError('لا توجد شركة نشطة مرتبطة بالمستخدم الحالي.'),
      );
    }
    return _service.listActivity(companyId: companyId, limit: 500);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}-${two(local.month)}-${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _details(Map<String, Object?> details) {
    if (details.isEmpty) return '—';
    return details.entries
        .map((entry) => '${entry.key}: ${entry.value ?? ''}')
        .join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF3E007D);
    const orange = Color(0xFFFFA015);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'سجل العمليات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: purple),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: purple),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'يعرض آخر 500 عملية مسجلة للشركة وفق صلاحيات الوصول المطبقة في قاعدة البيانات.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<ErpAppActivityEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: purple));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 36),
                        const SizedBox(height: 8),
                        Text('تعذر تحميل سجل العمليات: ${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
                final rows = snapshot.data ?? const <ErpAppActivityEntry>[];
                if (rows.isEmpty) {
                  return const Center(child: Text('لا توجد عمليات مسجلة حتى الآن.'));
                }
                return Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                        columns: const [
                          DataColumn(label: Text('التاريخ والوقت')),
                          DataColumn(label: Text('العملية')),
                          DataColumn(label: Text('نوع السجل')),
                          DataColumn(label: Text('المعرف')),
                          DataColumn(label: Text('المستخدم')),
                          DataColumn(label: Text('التفاصيل')),
                        ],
                        rows: rows.map((entry) => DataRow(cells: [
                          DataCell(Text(_date(entry.createdAt))),
                          DataCell(Text(entry.action)),
                          DataCell(Text(entry.entityType)),
                          DataCell(SelectableText(entry.entityId)),
                          DataCell(SelectableText(entry.actorId ?? '—')),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Text(_details(entry.details), maxLines: 3, overflow: TextOverflow.ellipsis),
                          )),
                        ])).toList(growable: false),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: orange),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'السجل للعرض والمراجعة فقط؛ لا يتم تعديل أو حذف قيود السجل من هذه الشاشة.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
