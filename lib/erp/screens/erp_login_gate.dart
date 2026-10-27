import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/activity_service.dart';
import '../erp_dashboard_screen.dart';
import '../../services/app_language.dart';

const _silsilaPurple = Color(0xFF3E007D);
const _silsilaOrange = Color(0xFFFFA015);
const _silsilaPink = Color(0xFFFF27C3);
const _pageBackground = Color(0xFFFAF8FC);
const _palePurple = Color(0xFFF5EFFB);

/// Professional Silsila-branded sign-in gate for the ERP web application.
class ErpLoginGate extends StatefulWidget {
  const ErpLoginGate({super.key});

  @override
  State<ErpLoginGate> createState() => _ErpLoginGateState();
}

class _ErpLoginGateState extends State<ErpLoginGate> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;
  bool _signedIn = false;
  bool _loading = true;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _rememberPassword = false;
  bool _recoveryInProgress = false;
  bool _newActivityPending = false;
  String _activity = 'مواد غذائية';
  String _accountType = 'إدارة نشاط';
  String _activityUserType = 'مستخدم رئيسي للنشاط';
  String? _error;
  List<String> _activityTypes = const <String>[];
  bool _activitiesLoading = true;
  List<String> _visibleUserTypes = const <String>[];
  bool _userTypesLoading = true;

  Future<void> _loadVisibleUserTypes() async {
    try {
      final rows = await Supabase.instance.client
          .from('erp_user_types')
          .select('name_ar,name_en')
          .eq('is_active', true)
          .eq('show_at_login', true)
          .order('type_code');
      final names = <String>[];
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        final name = (row['name_ar'] ?? '').toString().trim();
        if (name.isNotEmpty && !names.contains(name)) names.add(name);
      }
      if (!mounted) return;
      setState(() {
        _visibleUserTypes = names;
        if (!_visibleUserTypes.contains(_accountType) && names.isNotEmpty) {
          _accountType = names.first;
        }
        _userTypesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _visibleUserTypes = const <String>[];
        _userTypesLoading = false;
      });
    }
  }

  IconData _userTypeIcon(String type) => switch (type) {
    'مورد' => Icons.inventory_2_outlined,
    'عميل' => Icons.storefront_outlined,
    'مندوب' => Icons.badge_outlined,
    'شركة شحن' => Icons.local_shipping_outlined,
    'ادمن' || 'أدمن' => Icons.admin_panel_settings_outlined,
    _ => Icons.person_outline,
  };

  Future<void> _loadActivityTypes() async {
    try {
      final rows = await ActivityService().getActivities();
      final names = rows
          .map((row) => row['name']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _activityTypes = names;
        if (!_activityTypes.contains(_activity) && _activityTypes.isNotEmpty) {
          _activity = _activityTypes.first;
        }
        _activitiesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activityTypes = ActivityService.fallbackActivities
            .map((row) => row['name']!)
            .toList(growable: false);
        if (!_activityTypes.contains(_activity) && _activityTypes.isNotEmpty) {
          _activity = _activityTypes.first;
        }
        _activitiesLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActivityTypes();
    _loadVisibleUserTypes();
    try {
      final client = Supabase.instance.client;
      _signedIn = client.auth.currentSession != null;
      _loading = false;
      _authSubscription = client.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        setState(() {
          _signedIn = state.session != null && !_recoveryInProgress;
          _loading = false;
          if (_signedIn) _error = null;
        });
      });
    } catch (_) {
      _loading = false;
      _error = 'تعذر تهيئة الاتصال الآمن. حدّث الصفحة أو تحقق من إعدادات الاتصال.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    final input = _asciiDigits(value).trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (input.startsWith('+')) return input;
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    if (digits.startsWith('20')) return '+$digits';
    if (digits.startsWith('0') && digits.length >= 10) {
      return '+20${digits.substring(1)}';
    }
    return '+$digits';
  }

  Future<void> _login() async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || _password.text.isEmpty) {
      setState(() => _error = 'اكتب البريد الإلكتروني الصحيح وكلمة المرور أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(
        email: email,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _signedIn = client.auth.currentSession != null;
        if (!_signedIn) _error = 'لم يتم إنشاء جلسة دخول. أعد المحاولة.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول: ${error.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _asciiDigits(String value) => value.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
    final code = match.group(0)!.codeUnitAt(0);
    return String.fromCharCode(0x30 + (code >= 0x0660 && code <= 0x0669 ? code - 0x0660 : code - 0x06F0));
  });

  String? _validateNewPassword(String value) {
    if (value.length < 8 || !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'استخدم 8 أحرف على الأقل مع حرف كبير وصغير ورقم ورمز.';
    }
    return null;
  }

  Future<void> _openRegisterDialog({required bool newActivity}) async {
    if (_activitiesLoading) await _loadActivityTypes();
    if (!mounted) return;
    _newActivityPending = newActivity;
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false, obscure = true, obscureConfirm = true;
    var error = '', activity = _activityTypes.contains(_activity) ? _activity : (_activityTypes.isNotEmpty ? _activityTypes.first : '');
    var accountType = newActivity ? 'إدارة نشاط' : _accountType;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: SilsilaLanguage.isEnglish ? TextDirection.ltr : TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, refresh) => AlertDialog(
              title: Text(newActivity ? 'إنشاء نشاط جديد' : 'إنشاء مستخدم جديد'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'اسم النشاط أو صاحب الحساب',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'اكتب الاسم' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            return value.contains('@') && value.contains('.')
                                ? null
                                : 'أدخل بريدًا إلكترونيًا صحيحًا';
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _activityTypes.contains(activity) ? activity : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'نوع النشاط',
                            hintText: _activitiesLoading ? 'جارٍ تحميل الأنشطة...' : 'اختر النشاط',
                          ),
                          items: _activityTypes
                              .map((v) => DropdownMenuItem<String>(value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _activitiesLoading ? null : (v) {
                            if (v != null) refresh(() => activity = v);
                          },
                        ),
                        if (!newActivity) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _visibleUserTypes.contains(accountType) ? accountType : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'نوع الحساب'),
                            items: _visibleUserTypes
                                .map((type) => DropdownMenuItem<String>(value: type, child: Text(silsilaText(type), overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: _visibleUserTypes.isEmpty ? null : (v) {
                              if (v != null) refresh(() => accountType = v);
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                          validator: (v) {
                            final digits =
                                _asciiDigits(v ?? '').replaceAll(RegExp(r'\D'), '');
                            return digits.length < 10 || digits.length > 15
                                ? 'أدخل رقم هاتف صحيحًا'
                                : null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: password,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            helperText: '8 أحرف على الأقل مع حرف كبير وصغير ورقم ورمز',
                            suffixIcon: IconButton(
                              onPressed: () => refresh(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => _validateNewPassword(v ?? ''),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: confirmation,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  refresh(() => obscureConfirm = !obscureConfirm),
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => v != password.text
                              ? 'كلمتا المرور غير متطابقتين'
                              : null,
                        ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: Text(error, style: const TextStyle(color: Color(0xFFB42318), height: 1.5))),
                      ],
                    ]),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: Text(silsilaText('إلغاء'))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _silsilaPurple),
                  onPressed: busy ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    refresh(() { busy = true; error = ''; });
                    try {
                      final client = Supabase.instance.client;
                      final response = await client.auth.signUp(
                        email: email.text.trim().toLowerCase(),
                        password: password.text,
                        data: {
                          'full_name': name.text.trim(),
                          'contact_phone': _normalizePhone(_asciiDigits(phone.text)),
                          'account_type': newActivity ? 'إدارة نشاط' : accountType,
                          'activity_type': activity,
                          'activity_user_type': newActivity ? 'مستخدم رئيسي للنشاط' : _activityUserType,
                        },
                      );
                      if (response.user == null) throw StateError('لم يتم إنشاء الحساب.');
                      if (response.session != null) {
                        if (mounted) setState(() { _signedIn = true; _phone.text = phone.text; });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } else {
                        refresh(() { error = 'تم إنشاء الحساب. راجع بريدك الإلكتروني لتأكيد الحساب قبل تسجيل الدخول.'; busy = false; });
                      }
                    } on AuthException catch (e) {
                      refresh(() { error = e.message; busy = false; });
                    } catch (e) {
                      refresh(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
                    } finally {
                      if (dialogContext.mounted && busy) refresh(() => busy = false);
                    }
                  },
                  child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(silsilaText('إنشاء الحساب')),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (!_signedIn) _newActivityPending = false;
      name.dispose(); email.dispose(); phone.dispose(); password.dispose(); confirmation.dispose();
    }
  }

  Future<void> _openPasswordRecovery() async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'اكتب البريد الإلكتروني المسجل أولًا لاستعادة كلمة المرور.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _error = 'إذا كان البريد مسجلًا، فستصلك رسالة لاستعادة كلمة المرور.');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر إرسال رسالة الاستعادة: ${error.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر إرسال رسالة الاستعادة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _accountTypeButton(String label, IconData icon) {
    final selected = _accountType == label;
    return SizedBox(
      width: 126,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: selected ? _silsilaPurple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _accountType = label),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? _silsilaPurple : const Color(0xFFE5DDED)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: _silsilaOrange, size: 17),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : _silsilaPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPanel({
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8DFF1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _silsilaPurple, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Color(0xFF6F6579), fontSize: 12, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7DDED)),
        boxShadow: const [
          BoxShadow(color: Color(0x120F0020), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(color: _palePurple, borderRadius: BorderRadius.circular(30)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, color: _silsilaPurple, size: 16),
                  SizedBox(width: 6),
                  Text(silsilaText('بوابة دخول آمنة'), style: TextStyle(color: _silsilaPurple, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(silsilaText('أهلًا بك في سلسلة'), textAlign: TextAlign.center, style: TextStyle(color: _silsilaPurple, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(silsilaText('سجّل دخولك لإدارة شركتك وبياناتك بأمان'), textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF756A80), fontSize: 12, height: 1.6)),
          const SizedBox(height: 19),
          DropdownButtonFormField<String>(
            value: _activityTypes.contains(_activity) ? _activity : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'نوع النشاط',
              prefixIcon: const Icon(Icons.business_center_outlined, color: _silsilaPurple),
              border: const OutlineInputBorder(),
              hintText: _activitiesLoading ? 'جارٍ تحميل الأنشطة...' : 'اختر النشاط',
            ),
            items: _activityTypes.map((item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _activitiesLoading ? null : (value) {
              if (value != null) setState(() => _activity = value);
            },
          ),
          const SizedBox(height: 14),
          Text(silsilaText('اختار طريقة دخولك'), textAlign: TextAlign.center, style: TextStyle(color: _silsilaPurple, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (_userTypesLoading)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (_visibleUserTypes.isEmpty)
            const Text('لا توجد أنواع مستخدمين نشطة ومسموح بظهورها في التطبيق. راجع تبويب أنواع المستخدمين في إعدادات سلسلة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.deepOrange, height: 1.5))
          else
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 8, children: [
              for (final type in _visibleUserTypes) _accountTypeButton(type, _userTypeIcon(type)),
            ]),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _pageBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9E1F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(silsilaText('تسجيل دخول النشاط'), style: TextStyle(color: _silsilaPurple, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'مستخدم رئيسي للنشاط', label: Text(silsilaText('مستخدم رئيسي')), icon: Icon(Icons.admin_panel_settings_outlined)),
                    ButtonSegment(value: 'مستخدم فرعي للنشاط', label: Text(silsilaText('مستخدم فرعي')), icon: Icon(Icons.person_outline)),
                  ],
                  selected: {_activityUserType},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) => setState(() => _activityUserType = values.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: _rememberPassword ? const [AutofillHints.email] : const [],
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني المسجل', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _busy ? null : _login(),
                  autofillHints: _rememberPassword ? const [AutofillHints.password] : const [],
                  decoration: InputDecoration(
                    labelText: 'اكتب كلمة المرور الخاصة بك',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _rememberPassword,
                  activeColor: _silsilaPurple,
                  title: Text(silsilaText('تذكر بيانات الدخول'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(silsilaText('استخدم مدير كلمات المرور في المتصفح لحفظها بأمان'), style: TextStyle(fontSize: 11)),
                  onChanged: (value) => setState(() => _rememberPassword = value ?? false),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12, height: 1.5)),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  height: 49,
                  child: FilledButton(
                    onPressed: _busy || _loading ? null : _login,
                    style: FilledButton.styleFrom(backgroundColor: _silsilaPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                    child: _busy
                        ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login_rounded), SizedBox(width: 8), Text(silsilaText('دخول'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]),
                  ),
                ),
                TextButton(
                  onPressed: _openPasswordRecovery,
                  child: Text(silsilaText('نسيت كلمة المرور؟')),
                ),
                const Divider(height: 22),
                OutlinedButton.icon(
                  onPressed: () => _openRegisterDialog(newActivity: false),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(silsilaText('إنشاء مستخدم جديد')),
                  style: OutlinedButton.styleFrom(foregroundColor: _silsilaPurple, side: const BorderSide(color: _silsilaPurple), padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _openRegisterDialog(newActivity: true),
                  icon: const Icon(Icons.add_business_rounded),
                  label: Text(silsilaText('إنشاء نشاط جديد')),
                  style: FilledButton.styleFrom(backgroundColor: _silsilaOrange, foregroundColor: _silsilaPurple, padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_silsilaPurple, Color(0xFF5B1496), Color(0xFF32105A)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/silsila_logo.png',
                width: 66,
                height: 66,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.hub_rounded, color: _silsilaOrange, size: 44),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(silsilaText('سلسلة Silsila'), style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                    SizedBox(height: 5),
                    Text(silsilaText('بنربط السوق ببعضه'), style: TextStyle(color: _silsilaOrange, fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          Text(silsilaText('منصة واحدة تربط التجارة والإدارة'), style: TextStyle(color: Colors.white, fontSize: 21, height: 1.45, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(silsilaText('نظام سلسلة لإدارة النشاط ومتابعة العمليات، من بيانات الشركة والحسابات إلى المخازن والعملاء والموردين.'),
            style: TextStyle(color: Color(0xFFEDE4F6), height: 1.8, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _BrandPill(icon: Icons.security_rounded, text: 'دخول آمن'),
              _BrandPill(icon: Icons.sync_alt_rounded, text: 'ربط العمليات'),
              _BrandPill(icon: Icons.insights_rounded, text: 'رؤية أوضح'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _informationColumn({bool includeHeader = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeHeader) _brandHeader(),
        if (includeHeader) const SizedBox(height: 13),
        _infoPanel(
          icon: Icons.apartment_rounded,
          title: 'عن الشركة',
          description: 'سلسلة منظومة تجارة وإدارة تساعد الأنشطة على تنظيم بياناتها ومتابعة أعمالها من مكان واحد.',
          accent: _silsilaOrange,
        ),
        const SizedBox(height: 10),
        _infoPanel(
          icon: Icons.phone_iphone_rounded,
          title: 'عن التطبيق',
          description: 'تطبيق يربط الموردين والعملاء والتجار، ويسهّل اكتشاف العروض والتواصل التجاري.',
          accent: _silsilaPink,
        ),
        const SizedBox(height: 10),
        _infoPanel(
          icon: Icons.dashboard_customize_rounded,
          title: 'عن البرنامج',
          description: 'مساحة الإدارة لمتابعة بيانات الشركة والحسابات والمخازن والموارد البشرية والصلاحيات.',
          accent: _silsilaPurple,
        ),
        const SizedBox(height: 10),
        _infoPanel(
          icon: Icons.handshake_rounded,
          title: 'شركاء النجاح',
          description: 'الموردون وشركاء التوزيع والنقل والتقنية؛ معًا لبناء تجربة تجارية مترابطة.',
          accent: _silsilaOrange,
        ),
        const SizedBox(height: 10),
        _infoPanel(
          icon: Icons.groups_2_rounded,
          title: 'عملاؤنا',
          description: 'التجار والسوبر ماركت والبقالات ومقدمو خدمات التوريد وكل نشاط يحتاج إلى إدارة أوضح.',
          accent: _silsilaPink,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _palePurple, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _silsilaPurple, size: 23),
              SizedBox(width: 10),
              Expanded(child: Text(silsilaText('رؤيتنا: سوق متصل، معلومات أوضح، وخطوات أسهل لكل شريك.'), style: TextStyle(color: _silsilaPurple, fontWeight: FontWeight.w800, height: 1.6, fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn) return ErpDashboardScreen(initialPage: _newActivityPending ? 'بيانات الشركة' : null);

    return Directionality(
      textDirection: SilsilaLanguage.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _silsilaPurple))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1050;
                    final content = wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: _informationColumn()),
                              const SizedBox(width: 22),
                              Expanded(flex: 10, child: _loginForm()),
                            ],
                          )
                        : Column(
                            children: [
                              _brandHeader(),
                              const SizedBox(height: 16),
                              _loginForm(),
                              const SizedBox(height: 18),
                              _informationColumn(includeHeader: false),
                            ],
                          );
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16, vertical: 20),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.circle, color: _silsilaOrange, size: 9),
                                  const SizedBox(width: 7),
                                  Text(silsilaText('نظام إدارة سلسلة'), style: TextStyle(color: _silsilaPurple, fontWeight: FontWeight.w900, fontSize: 13)),
                                  const Spacer(),
                                  Text(silsilaText('SILSILA • MANAGEMENT PORTAL'), style: TextStyle(color: _silsilaPurple.withValues(alpha: 0.62), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                                ],
                              ),
                              const SizedBox(height: 17),
                              content,
                              const SizedBox(height: 22),
                              Center(
                                child: Text(silsilaText('سلسلة Silsila  •  بنربط السوق ببعضه'), style: TextStyle(color: Color(0xFF8A7D95), fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _silsilaOrange, size: 15),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

