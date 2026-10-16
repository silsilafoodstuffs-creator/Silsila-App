import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  SettingsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
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

  /// جلب إعدادات المستخدم أو القيم الافتراضية.
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client
        .from('user_settings')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      return Map<String, dynamic>.from(defaultSettings);
    }

    return {
      ...defaultSettings,
      ...Map<String, dynamic>.from(response),
    };
  }

  /// إنشاء الإعدادات أو تحديثها.
  Future<Map<String, dynamic>> saveSettings({
    String? language,
    bool? notificationsEnabled,
    bool? offersNotifications,
    bool? orderNotifications,
    String? priceDisplay,
    String? theme,
  }) async {
    final current = await getSettings();

    final next = <String, dynamic>{
      'user_id': _userId,
      'language': language ?? current['language'],
      'notifications_enabled':
          notificationsEnabled ?? current['notifications_enabled'],
      'offers_notifications':
          offersNotifications ?? current['offers_notifications'],
      'order_notifications':
          orderNotifications ?? current['order_notifications'],
      'price_display': priceDisplay ?? current['price_display'],
      'theme': theme ?? current['theme'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (!const ['ar', 'en'].contains(next['language'])) {
      throw ArgumentError('اللغة المحددة غير مدعومة.');
    }

    if (!const ['final', 'negotiable'].contains(next['price_display'])) {
      throw ArgumentError('طريقة عرض الأسعار غير صحيحة.');
    }

    if (!const ['light', 'dark', 'system'].contains(next['theme'])) {
      throw ArgumentError('المظهر المحدد غير مدعوم.');
    }

    final response = await _client
        .from('user_settings')
        .upsert(
          next,
          onConflict: 'user_id',
        )
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// إعادة الإعدادات إلى قيمها الافتراضية.
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
}
