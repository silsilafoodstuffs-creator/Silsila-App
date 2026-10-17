import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  SettingsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client != null) {
      return client;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.',
      );
    }
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return user.id;
  }

  static const Map<String, dynamic> defaultSettings = {
    'language': 'ar',
    'notifications_enabled': true,
    'offers_notifications': true,
    'order_notifications': true,
    'price_display': 'final',
    'theme': 'light',
  };

  static const List<String> supportedLanguages = ['ar', 'en'];

  static const List<String> supportedPriceDisplays = [
    'final',
    'negotiable',
  ];

  static const List<String> supportedThemes = [
    'light',
    'dark',
    'system',
  ];

  /// جلب إعدادات المستخدم أو القيم الافتراضية.
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _requireClient
        .from('user_settings')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      return Map<String, dynamic>.from(defaultSettings);
    }

    final saved = Map<String, dynamic>.from(response);

    return {
      ...defaultSettings,
      ...saved,
    };
  }

  /// إنشاء إعدادات المستخدم أو تحديثها.
  Future<Map<String, dynamic>> saveSettings({
    String? language,
    bool? notificationsEnabled,
    bool? offersNotifications,
    bool? orderNotifications,
    String? priceDisplay,
    String? theme,
  }) async {
    final cleanLanguage = _clean(language);
    final cleanPriceDisplay = _clean(priceDisplay);
    final cleanTheme = _clean(theme);

    if (cleanLanguage != null &&
        !supportedLanguages.contains(cleanLanguage)) {
      throw ArgumentError('اللغة المحددة غير مدعومة.');
    }

    if (cleanPriceDisplay != null &&
        !supportedPriceDisplays.contains(cleanPriceDisplay)) {
      throw ArgumentError('طريقة عرض الأسعار غير صحيحة.');
    }

    if (cleanTheme != null &&
        !supportedThemes.contains(cleanTheme)) {
      throw ArgumentError('المظهر المحدد غير مدعوم.');
    }

    final userId = _userId;
    final current = await getSettings();

    final next = <String, dynamic>{
      'user_id': userId,
      'language': cleanLanguage ?? current['language'],
      'notifications_enabled':
          notificationsEnabled ?? current['notifications_enabled'],
      'offers_notifications':
          offersNotifications ?? current['offers_notifications'],
      'order_notifications':
          orderNotifications ?? current['order_notifications'],
      'price_display':
          cleanPriceDisplay ?? current['price_display'],
      'theme': cleanTheme ?? current['theme'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _requireClient
        .from('user_settings')
        .upsert(
          next,
          onConflict: 'user_id',
        )
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// إعادة إعدادات المستخدم إلى القيم الافتراضية.
  Future<Map<String, dynamic>> resetSettings() {
    return saveSettings(
      language: 'ar',
      notificationsEnabled: true,
      offersNotifications: true,
      orderNotifications: true,
      priceDisplay: 'final',
      theme: 'light',
    );
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
