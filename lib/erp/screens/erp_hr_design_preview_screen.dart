import 'package:flutter/material.dart';

const _previewPurple = Color(0xFF3E007D);
const _previewOrange = Color(0xFFFFA015);
const _previewPink = Color(0xFFFF27C3);

/// Visual-only HR screen. It deliberately has no repository, API, or database dependency.
class ErpHrDesignPreviewScreen extends StatelessWidget {
  const ErpHrDesignPreviewScreen({
    super.key,
    required this.page,
    required this.group,
  });

  final String page;
  final String group;

  List<String> get _columns {
    if (page.contains('حضور') || page.contains('غياب')) {
      return const ['كود الموظف', 'اسم الموظف', 'التاريخ', 'الحضور', 'الانصراف', 'الحالة'];
    }
    if (page.contains('عقد')) {
      return const ['كود الموظف', 'اسم الموظف', 'نوع العقد', 'تاريخ البداية', 'تاريخ النهاية', 'الحالة'];
    }
    if (page.contains('توظيف') || page.contains('مقابلات') || page.contains('تعيين')) {
      return const ['رقم الطلب', 'المرشح', 'الوظيفة', 'تاريخ الطلب', 'المرحلة', 'الحالة'];
    }
    if (page.contains('إجاز')) {
      return const ['رقم الطلب', 'الموظف', 'نوع الإجازة', 'من', 'إلى', 'الحالة'];
    }
    if (page.contains('راتب') || page.contains('رواتب') || page.contains('عمالة')) {
      return const ['كود الموظف', 'اسم الموظف', 'الأساسي', 'الإضافي', 'الاستقطاعات', 'الصافي'];
    }
    return const ['الكود', 'الاسم', 'التصنيف', 'الإدارة / القسم', 'تاريخ التسجيل', 'الحالة'];
  }

  List<List<String>> get _sampleRows => [
    ['EMP-0001', 'موظف تجريبي 1', 'إداري', 'الإدارة المركزية', '01-11-2026', 'نشط'],
    ['EMP-0002', 'موظف تجريبي 2', 'تشغيل', 'المخازن', '03-11-2026', 'نشط'],
    ['EMP-0003', 'موظف تجريبي 3', 'مبيعات', 'المبيعات', '04-11-2026', 'مراجعة'],
  ];

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    final rows = _sampleRows;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F5FA),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9E1F1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _previewPurple.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.badge_outlined, color: _previewPurple, size: 27),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(page, style: const TextStyle(color: _previewPurple, fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('شئون موظفين  /  $group', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(color: _previewOrange.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                    child: const Text('معاينة تصميم فقط', style: TextStyle(color: _previewPurple, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8EA), borderRadius: BorderRadius.circular(12), border: Border.all(color: _previewOrange.withValues(alpha: .45))),
              child: const Row(
                children: [
                  Icon(Icons.visibility_outlined, color: _previewOrange),
                  SizedBox(width: 9),
                  Expanded(child: Text('هذه شاشة تجريبية ببيانات افتراضية للمعاينة. لا تقرأ أو تحفظ أو تعدّل أي بيانات في النظام.', style: TextStyle(fontSize: 12, height: 1.5))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric('إجمالي السجلات', '128', Icons.groups_outlined, _previewPurple),
                _metric('نشط', '116', Icons.verified_outlined, const Color(0xFF18865A)),
                _metric('قيد المراجعة', '12', Icons.pending_actions_outlined, _previewPink),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9E1F1))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('شكل قائمة البيانات المقترح', style: TextStyle(color: _previewPurple, fontWeight: FontWeight.w900, fontSize: 15))),
                      OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.add, size: 17), label: const Text('إضافة')),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.tune, size: 17), label: const Text('تصفية')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                      columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(color: _previewPurple, fontWeight: FontWeight.w800)))).toList(),
                      rows: rows.map((row) => DataRow(cells: List.generate(columns.length, (i) => DataCell(Text(i < row.length ? row[i] : '—'))))).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('الأرقام والأسماء المعروضة أمثلة شكلية فقط، وستُعاد مراجعة الحقول والأزرار ومسار العمل معك قبل ربط أي وظيفة.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withValues(alpha: .2))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
        ],
      ),
    );
  }
}
