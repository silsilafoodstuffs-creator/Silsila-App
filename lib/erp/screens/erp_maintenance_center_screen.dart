import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ErpMaintenanceCenterScreen extends StatelessWidget {
  const ErpMaintenanceCenterScreen({super.key});

  static const _purple = Color(0xFF3E007D);
  static const _orange = Color(0xFFFFA015);
  static const _repoUrl = 'https://github.com/silsilafoodstuffs-creator/Silsila-App';
  static const _actionsUrl = 'https://github.com/silsilafoodstuffs-creator/Silsila-App/actions';
  static const _supabaseUrl = 'https://supabase.com/dashboard/project/teitsopmhruczplwlwgn';

  Future<void> _open(BuildContext context, String value) async {
    try {
      final opened = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
        );
      }
    }
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الأمر. شغّله من مجلد المشروع.')),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback action,
    Color color = _purple,
  }) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE9E1F1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _purple))),
            ]),
            const SizedBox(height: 9),
            Expanded(child: Text(description,
              style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black54))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(buttonLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: .35)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commandTile(BuildContext context, String title, String command) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9E1F1)),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
            const SizedBox(height: 4),
            SelectableText(command, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ],
        )),
        IconButton(
          tooltip: 'نسخ الأمر',
          onPressed: () => _copy(context, command),
          icon: const Icon(Icons.copy_rounded, color: _purple, size: 19),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFFB),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_purple, Color(0xFF6420A0)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(children: [
                    Icon(Icons.build_circle_outlined, color: _orange, size: 34),
                    SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مركز الصيانة والتطوير',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('أدوات فحص ومتابعة مشروع سلسلة',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 3 ? 1.35 : columns == 2 ? 1.45 : 2.0,
                  children: [
                    _actionCard(context: context, icon: Icons.play_circle_outline,
                      title: 'اختبارات GitHub Actions',
                      description: 'متابعة فحوص Dart Analyze وFlutter Test وبناء الويب وAndroid وحالة النشر.',
                      buttonLabel: 'فتح نتائج الاختبارات',
                      action: () => _open(context, _actionsUrl), color: const Color(0xFF2475B8)),
                    _actionCard(context: context, icon: Icons.code_rounded,
                      title: 'مستودع سلسلة',
                      description: 'مراجعة الفروع والتغييرات والـ commits والملفات وسجل التطوير.',
                      buttonLabel: 'فتح المستودع',
                      action: () => _open(context, _repoUrl)),
                    _actionCard(context: context, icon: Icons.storage_rounded,
                      title: 'قاعدة بيانات Supabase',
                      description: 'فتح لوحة المشروع لمراجعة الجداول وسياسات RLS وسجلات التشغيل.',
                      buttonLabel: 'فتح لوحة قاعدة البيانات',
                      action: () => _open(context, _supabaseUrl), color: const Color(0xFF16865A)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('أوامر الفحص المحلية',
                  style: TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('الأزرار التالية تنسخ الأوامر فقط؛ تشغيلها يتم من Terminal داخل مجلد المشروع، ولا تنفذ أوامر بناء على جهاز المستخدم.',
                  style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5)),
                const SizedBox(height: 9),
                _commandTile(context, 'تحليل الكود', 'flutter analyze'),
                const SizedBox(height: 7),
                _commandTile(context, 'اختبارات Flutter', 'flutter test'),
                const SizedBox(height: 7),
                _commandTile(context, 'بناء نسخة الويب', 'flutter build web --release --base-href "/Silsila-App/"'),
                const SizedBox(height: 7),
                _commandTile(context, 'بناء APK إصدار Release', 'flutter build apk --release'),
                const SizedBox(height: 7),
                _commandTile(context, 'تنسيق ملفات Dart', 'dart format .'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    border: Border.all(color: _orange.withValues(alpha: .6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.verified_user_outlined, color: Color(0xFF9A5B00), size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'ضوابط الأمان: هذا المركز لا يحذف بيانات ولا يعدّل قاعدة البيانات ولا ينشر إصدارًا. لا تُعلن أي نتيجة ناجحة إلا بعد ظهورها فعليًا في GitHub Actions. الإصلاح والدمج والنشر تظل خطوات منفصلة تتطلب مراجعة.',
                      style: TextStyle(color: Color(0xFF714500), fontSize: 12, height: 1.55),
                    )),
                  ]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
