import 'package:flutter/material.dart';
import 'studio_document.dart';

const _studioPrimary = Color(0xFF3E007D);

/// Fixed component allow-list. A Studio document is data only; it cannot execute code.
class StudioComponentRegistry {
  static const supportedTypes = <String, String>{
    'text': 'نص',
    'button': 'زر',
    'field': 'حقل إدخال',
    'card': 'بطاقة',
    'divider': 'فاصل',
    'spacer': 'مسافة',
    'grid': 'شبكة',
    'tree': 'شجرة بيانات',
    'table': 'جدول',
    'icon': 'أيقونة',
    'image': 'صورة',
    'chart': 'رسم بياني',
    'tabs': 'تبويبات',
    'form': 'نموذج',
    'list': 'قائمة',
    'badge': 'شارة',
    'progress': 'مؤشر تقدم',
    'stat': 'مؤشر رقمي',
    'container': 'حاوية ومجموعة',
    'filter': 'حقل بحث وتصفية',
  };

  static const iconNames = <String, IconData>{
    'dashboard': Icons.dashboard_outlined,
    'inventory': Icons.inventory_2_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'people': Icons.people_outline,
    'warehouse': Icons.warehouse_outlined,
    'payments': Icons.payments_outlined,
    'chart': Icons.bar_chart_outlined,
    'settings': Icons.settings_outlined,
    'search': Icons.search,
    'calendar': Icons.calendar_month_outlined,
    'image': Icons.image_outlined,
    'folder': Icons.folder_outlined,
    'check': Icons.check_circle_outline,
    'warning': Icons.warning_amber_outlined,
    'truck': Icons.local_shipping_outlined,
  };

  static Widget build(
    StudioNode node, {
    bool interactive = false,
    Map<String, List<Map<String, dynamic>>> dataBySource = const {},
    ValueChanged<String>? onAction,
  }) {
    if (node.hidden) return const SizedBox.shrink();
    final p = node.props;
    final binding = p['binding'] is Map
        ? Map<String, dynamic>.from(p['binding'] as Map)
        : const <String, dynamic>{};
    final sourceKey = binding['source']?.toString();
    final rows = sourceKey == null ? const <Map<String, dynamic>>[] : dataBySource[sourceKey] ?? const [];
    final field = binding['field']?.toString();
    final firstValue = rows.isEmpty || field == null ? null : rows.first[field];
    final width = p['width'] is num ? (p['width'] as num).toDouble().clamp(40, 2400).toDouble() : null;

    Widget content;
    switch (node.type) {
      case 'text':
        content = Text(
          firstValue?.toString() ?? (p['text'] ?? 'نص جديد').toString(),
          textAlign: _align(p['align']),
          style: TextStyle(
            fontSize: _number(p['size'], 14).clamp(8, 48).toDouble(),
            fontWeight: p['bold'] == true ? FontWeight.bold : FontWeight.normal,
            color: Color(_integer(p['color'], 0xFF241735)),
          ),
        );
        break;
      case 'button':
        content = Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: interactive && onAction != null
                ? () => onAction((p['actionKey'] ?? 'preview').toString())
                : null,
            icon: Icon(_icon(p['icon']?.toString()), size: 18),
            label: Text((p['text'] ?? 'زر جديد').toString()),
          ),
        );
        break;
      case 'field':
        content = Row(children: [
          SizedBox(width: 92, child: Text((p['label'] ?? 'اسم الحقل').toString())),
          const SizedBox(width: 5),
          Expanded(child: SizedBox(height: 40, child: TextField(
            enabled: interactive,
            decoration: InputDecoration(
              hintText: (p['hint'] ?? 'أدخل القيمة').toString(),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ))),
        ]);
        break;
      case 'card':
      case 'container':
        content = Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((p['title'] ?? '').toString().isNotEmpty)
                Text((p['title'] ?? 'بطاقة').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(firstValue?.toString() ?? (p['subtitle'] ?? 'محتوى البطاقة').toString()),
            ]),
          ),
        );
        break;
      case 'divider':
        content = const Divider(height: 10);
        break;
      case 'spacer':
        content = SizedBox(height: _number(p['height'], 10).clamp(1, 300).toDouble());
        break;
      case 'grid':
        final data = rows.isEmpty ? List.generate(4, (i) => {'label': 'عنصر ${i + 1}'}) : rows;
        final labelField = (p['labelField'] ?? field ?? 'label').toString();
        content = GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: _number(p['columns'], 2).round().clamp(1, 6).toInt(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          childAspectRatio: 2.4,
          children: data.take(100).map((row) => DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text((row[labelField] ?? _firstValue(row) ?? 'عنصر').toString(), textAlign: TextAlign.center),
            )),
          )).toList(),
        );
        break;
      case 'tree':
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final row in (rows.isEmpty ? const [{'label': 'عنصر رئيسي'}] : rows).take(100))
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined),
              title: Text((row[field ?? 'label'] ?? _firstValue(row) ?? 'عنصر').toString()),
            ),
        ]);
        break;
      case 'table':
        final columns = (p['columns'] is List ? (p['columns'] as List) : [field ?? 'item_code', 'item_name'])
            .map((e) => e.toString()).take(8).toList();
        final tableRows = rows.isEmpty ? const [{'item_code': 'مثال', 'item_name': 'بيانات تجريبية'}] : rows;
        content = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 48,
            columnSpacing: 12,
            columns: columns.map((key) => DataColumn(label: Text(key))).toList(),
            rows: tableRows.take(100).map((row) => DataRow(
              cells: columns.map((key) => DataCell(Text((row[key] ?? '').toString()))).toList(),
            )).toList(),
          ),
        );
        break;
      case 'icon':
        content = Icon(_icon(p['name']?.toString()), size: _number(p['size'], 30).clamp(12, 96).toDouble(),
            color: Color(_integer(p['color'], 0xFF3E007D)));
        break;
      case 'image':
        final uri = Uri.tryParse((p['url'] ?? '').toString());
        content = uri != null && uri.scheme == 'https'
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(uri.toString(), height: _number(p['height'], 120), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)))
            : const Icon(Icons.image_outlined, size: 42, color: Colors.black38);
        break;
      case 'chart':
        final valueField = (p['valueField'] ?? 'grand_total').toString();
        final labelField = (p['labelField'] ?? 'document_number').toString();
        final chartRows = rows.take(8).toList();
        final maxValue = chartRows.fold<double>(0, (m, r) => _number(r[valueField], 0) > m ? _number(r[valueField], 0) : m);
        content = Column(children: chartRows.isEmpty
            ? const [Text('اربط مصدر بيانات لعرض الرسم البياني.')]
            : chartRows.map((r) {
                final value = _number(r[valueField], 0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 90, child: Text((r[labelField] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(child: LinearProgressIndicator(value: maxValue <= 0 ? 0 : value / maxValue, minHeight: 12)),
                    const SizedBox(width: 6),
                    Text(value.toStringAsFixed(0)),
                  ]),
                );
              }).toList());
        break;
      case 'tabs':
        final labels = (p['labels'] is List ? p['labels'] as List : const ['بيانات', 'حركات', 'تقارير'])
            .map((e) => e.toString()).take(12).toList();
        content = Wrap(spacing: 5, children: labels.map((e) => Chip(label: Text(e))).toList());
        break;
      case 'form':
        content = Column(children: [
          for (final label in (p['fields'] is List ? p['fields'] as List : const ['الاسم', 'الكود']).take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                SizedBox(width: 100, child: Text(label.toString())),
                Expanded(child: SizedBox(height: 40, child: TextField(
                  enabled: interactive,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ))),
              ]),
            ),
        ]);
        break;
      case 'list':
        final listRows = rows.isEmpty ? const [{'label': 'عنصر تجريبي'}] : rows;
        content = Column(children: listRows.take(100).map((r) => ListTile(
          dense: true,
          leading: const Icon(Icons.circle, size: 7),
          title: Text((r[field ?? 'item_name'] ?? (r.isEmpty ? '' : r.values.first)).toString()),
        )).toList());
        break;
      case 'badge':
        content = Chip(
          label: Text((p['text'] ?? firstValue ?? 'حالة').toString()),
          backgroundColor: Color(_integer(p['color'], 0xFFFFA015)).withValues(alpha: .16),
          side: BorderSide.none,
        );
        break;
      case 'progress':
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((p['label'] ?? 'نسبة الإنجاز').toString()),
          LinearProgressIndicator(value: (_number(p['value'], .65)).clamp(0, 1).toDouble()),
        ]);
        break;
      case 'stat':
        content = Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((p['label'] ?? 'المؤشر').toString()),
            Text((firstValue ?? p['value'] ?? '0').toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _studioPrimary)),
          ]),
        ));
        break;
      case 'filter':
        content = TextField(
          enabled: interactive,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: (p['hint'] ?? 'بحث وتصفية').toString(),
            border: const OutlineInputBorder(),
          ),
        );
        break;
      default:
        content = const Text('مكون غير مدعوم');
    }

    if (width != null) return SizedBox(width: width, child: content);
    return content;
  }

  static dynamic _firstValue(Map<String, dynamic> row) => row.isEmpty ? null : row.values.first;
  static IconData _icon(String? name) => iconNames[name] ?? Icons.widgets_outlined;
  static double _number(dynamic value, num fallback) =>
      value is num ? value.toDouble() : fallback.toDouble();
  static int _integer(dynamic value, int fallback) => value is int ? value : fallback;
  static TextAlign _align(dynamic value) => value == 'center'
      ? TextAlign.center
      : value == 'end' ? TextAlign.end : TextAlign.start;
}

class StudioDocumentRenderer extends StatelessWidget {
  const StudioDocumentRenderer({
    super.key,
    required this.document,
    this.interactive = false,
    this.dataBySource = const {},
    this.onAction,
  });

  final StudioDocument document;
  final bool interactive;
  final Map<String, List<Map<String, dynamic>>> dataBySource;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        for (final node in document.nodes.where((e) => !e.hidden))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: StudioComponentRegistry.build(node, interactive: interactive, dataBySource: dataBySource, onAction: onAction),
          ),
      ],
    ),
  );
}
