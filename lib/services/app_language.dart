import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared language state for the Silsila customer app and ERP.
class SilsilaLanguage {
  SilsilaLanguage._();
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('ar'));
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static bool get isEnglish => locale.value.languageCode == 'en';

  static Future<void> load() async {
    try {
      final saved = await _storage.read(key: 'silsila_display_language');
      if (saved == 'en' || saved == 'ar') locale.value = Locale(saved!);
    } catch (_) {}
  }

  static Future<void> setLanguage(String language) async {
    final code = language == 'en' ? 'en' : 'ar';
    locale.value = Locale(code);
    try {
      await _storage.write(key: 'silsila_display_language', value: code);
    } catch (_) {}
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('user_settings').upsert({
          'user_id': user.id,
          'language': code,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
      }
    } catch (_) {}
  }
}

/// Shared translations for common navigation and system actions. Unknown
/// content remains unchanged rather than being mistranslated.
String silsilaText(String value) {
  if (!SilsilaLanguage.isEnglish) return value;
  const words = <String, String>{
    'سلسلة Silsila': 'Silsila',
    'سلسلة': 'Silsila',
    'ابدأ الآن': 'Get Started',
    'ابدأ مع سلسلة': 'Get started with Silsila',
    'اختار طريقة دخولك': 'Choose how to sign in',
    'تسجيل الدخول': 'Sign in',
    'لديك حساب بالفعل': 'Already have an account',
    'اختار نوع المستخدم للدخول': 'Choose your account type',
    'إعدادات البرنامج': 'Program Settings',
    'اسم البرنامج': 'Program Name',
    'لغة البرنامج': 'Program Language',
    'العربية': 'Arabic',
    'English': 'English',
    'ألوان وهوية البرنامج': 'Program Colors & Identity',
    'اللون الأساسي': 'Primary Color',
    'اللون الثانوي': 'Secondary Color',
    'لون التمييز': 'Accent Color',
    'لون الخلفية': 'Background Color',
    'نظام الخطوط — خمسة مستويات': 'Typography — Five Levels',
    'العنوان الرئيسي': 'Main Heading',
    'العنوان الفرعي الأول': 'Subheading 1',
    'العنوان الفرعي الثاني': 'Subheading 2',
    'العنوان الفرعي الثالث': 'Subheading 3',
    'النص والعناوين الصغيرة': 'Body Text & Small Headings',
    'نوع الخط': 'Font Family',
    'الحجم': 'Size',
    'لون الخط': 'Text Color',
    'اختيار صورة': 'Choose Image',
    'إزالة': 'Remove',
    'حفظ': 'Save',
    'تحديث': 'Refresh',
    'معاينة': 'Preview',
    'حفظ إعدادات البرنامج': 'Save Program Settings',
    'جارٍ الحفظ...': 'Saving...',
    'معاينة إعدادات البرنامج': 'Preview Program Settings',
    'إغلاق': 'Close',
    'تم حفظ إعدادات البرنامج في قاعدة البيانات.': 'Program settings saved to the database.',
    'صورة البرنامج / الشعار': 'Program Logo',
    'إدارة الاسم واللغة والهوية البصرية وخطوط العناوين بشكل موحد.': 'Manage the name, language, visual identity and heading typography.',
    'اللون الأساسي:': 'Primary color:',
    'اللون الثانوي:': 'Secondary color:',
    'اللغة:': 'Language:',
    'الاسم واللغة والشعار': 'Name, Language & Logo',
    'الموردين': 'Suppliers',
    'الفئات': 'Categories',
    'الأصناف': 'Products',
    'سلة المشتريات': 'Shopping Cart',
    'المزيد': 'More',
    'الإشعارات': 'Notifications',
    'بحث': 'Search',
    'حفظ التعديلات': 'Save Changes',
    'إلغاء': 'Cancel',
    'حذف': 'Delete',
    'إضافة': 'Add',
    'تعديل': 'Edit',
    'طباعة': 'Print',
    'تصدير': 'Export',
    'الملخص التنفيذي': 'Executive Summary',
    'القوائم': 'Menus',
    'إدارة البرنامج': 'Program Administration',
    'إدارة التطبيقات': 'Application Management',
    'العودة': 'Back',
    'التالي': 'Next',
    'السابق': 'Previous',
    'اسم المستخدم': 'Username',
    'كلمة المرور': 'Password',
    'البريد الإلكتروني': 'Email',
    'رقم الهاتف': 'Phone Number',
    'تأكيد': 'Confirm',
    'نعم': 'Yes',
    'لا': 'No',
  };
  return words[value] ?? value;
}

class SilsilaLanguageToggle extends StatelessWidget {
  const SilsilaLanguageToggle({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF3E007D),
    elevation: 4,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: SilsilaLanguage.isEnglish ? 'Switch to Arabic' : 'Switch to English',
      onPressed: () => SilsilaLanguage.setLanguage(SilsilaLanguage.isEnglish ? 'ar' : 'en'),
      icon: Text(
        SilsilaLanguage.isEnglish ? 'ع' : 'EN',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
      ),
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      padding: EdgeInsets.zero,
    ),
  );
}
