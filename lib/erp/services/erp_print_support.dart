import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared RTL PDF direction, numeric shaping and print metadata for Silsila.
class ErpPrintSupport {
  ErpPrintSupport._();

  static String normalizeText(Object? value) {
    final source = (value ?? '').toString();
    final latin = StringBuffer();
    for (final rune in source.runes) {
      final char = String.fromCharCode(rune);
      final mapped = switch (char) {
        '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
        '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
        '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
        '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
        _ => char,
      };
      latin.write(mapped);
    }
    return latin.toString().replaceAllMapped(
      RegExp(r'[0-9]+'),
      (match) => '\u200E${match.group(0)}\u200E',
    );
  }

  static List<String> normalizeStrings(Iterable<Object?> values) =>
      values.map(normalizeText).toList(growable: false);

  static List<List<String>> normalizeTable(Iterable<Iterable<Object?>> rows) =>
      rows.map((row) => normalizeStrings(row)).toList(growable: false);

  static pw.Widget text(Object? value, {pw.TextStyle? style, pw.TextAlign? textAlign}) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Text(normalizeText(value), style: style, textAlign: textAlign),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _printedBy() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 'غير محدد';
      final metadata = user.userMetadata ?? const <String,dynamic>{};
      final name = (metadata['full_name'] ?? metadata['name'] ?? metadata['display_name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      return user.email?.trim().isNotEmpty == true ? user.email!.trim() : user.id;
    } catch (_) {
      return 'غير محدد';
    }
  }

  static pw.Widget header(pw.Context context) {
    final now = DateTime.now().toLocal();
    final date = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    final time = '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: pw.PdfColor(.78, .74, .83), width: .6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                text('سلسلة | Silsila', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                text('تاريخ الطباعة: $date  •  الوقت: $time', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.SizedBox(height: 3),
            text('مستخدم الطباعة: ${_printedBy()}', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  static pw.Widget footer(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 7),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: pw.PdfColor(.84, .82, .87), width: .5)),
      ),
      alignment: pw.Alignment.center,
      child: pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Text(
          normalizeText('Page ${context.pageNumber} / ${context.pagesCount}'),
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }
}
