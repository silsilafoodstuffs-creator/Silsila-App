import 'package:flutter/material.dart';
import 'studio_document.dart';

/// Safe allow-listed renderer. Documents describe presentation only and cannot
/// invoke arbitrary Dart, SQL, network calls or callbacks.
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
  };

  static Widget build(StudioNode node, {bool interactive = false}) {
    final p = node.props;
    switch (node.type) {
      case 'text':
        return Text(
          (p['text'] ?? 'نص جديد').toString(),
          textAlign: _align(p['align']),
          style: TextStyle(
            fontSize: _number(p['size'], 14).clamp(8, 48).toDouble(),
            fontWeight: p['bold'] == true ? FontWeight.bold : FontWeight.normal,
            color: Color(_integer(p['color'], 0xFF241735)),
          ),
        );
      case 'button':
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: interactive ? () {} : null,
            icon: const Icon(Icons.touch_app_outlined, size: 18),
            label: Text((p['text'] ?? 'زر جديد').toString()),
          ),
        );
      case 'field':
        return Row(children: [
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
      case 'card':
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((p['title'] ?? 'بطاقة').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text((p['subtitle'] ?? 'محتوى البطاقة').toString()),
            ]),
          ),
        );
      case 'divider':
        return const Divider(height: 10);
      case 'spacer':
        return SizedBox(height: _number(p['height'], 10).clamp(1, 100).toDouble());
      case 'grid':
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: _number(p['columns'], 2).round().clamp(1, 6).toInt(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          childAspectRatio: 2.4,
          children: List.generate(4, (i) => DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('عنصر ${i + 1}')),
          )),
        );
      case 'tree':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          ListTile(dense: true, leading: Icon(Icons.folder_outlined), title: Text('عنصر رئيسي')),
          Padding(padding: EdgeInsetsDirectional.only(start: 28), child: ListTile(dense: true, leading: Icon(Icons.insert_drive_file_outlined), title: Text('عنصر فرعي'))),
        ]);
      case 'table':
        return Table(
          border: TableBorder.all(color: const Color(0xFFE1D8EA)),
          children: const [
            TableRow(children: [Padding(padding: EdgeInsets.all(6), child: Text('الاسم')), Padding(padding: EdgeInsets.all(6), child: Text('الحالة'))]),
            TableRow(children: [Padding(padding: EdgeInsets.all(6), child: Text('مثال')), Padding(padding: EdgeInsets.all(6), child: Text('نشط'))]),
          ],
        );
      default:
        return const Text('مكون غير مدعوم');
    }
  }

  static double _number(dynamic value, num fallback) =>
      value is num ? value.toDouble() : fallback.toDouble();
  static int _integer(dynamic value, int fallback) => value is int ? value : fallback;
  static TextAlign _align(dynamic value) => value == 'center'
      ? TextAlign.center
      : value == 'end' ? TextAlign.end : TextAlign.start;
}

class StudioDocumentRenderer extends StatelessWidget {
  const StudioDocumentRenderer({super.key, required this.document, this.interactive = false});
  final StudioDocument document;
  final bool interactive;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        for (final node in document.nodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: StudioComponentRegistry.build(node, interactive: interactive),
          ),
      ],
    ),
  );
}
