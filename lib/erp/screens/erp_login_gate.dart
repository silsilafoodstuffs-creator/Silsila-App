import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../erp_dashboard_screen.dart';

const _silsilaPurple = Color(0xFF3E007D);
const _silsilaOrange = Color(0xFFFFA015);
const _silsilaPink = Color(0xFFFF27C3);
const _pageBackground = Color(0xFFFAF8FC);
const _palePurple = Color(0xFFF5EFFB);
const _ink = Color(0xFF241735);

/// Professional Silsila-branded sign-in gate for the ERP web application.
class ErpLoginGate extends StatefulWidget {
  const ErpLoginGate({super.key});

  @override
  State<ErpLoginGate> createState() => _ErpLoginGateState();
}

class _ErpLoginGateState extends State<ErpLoginGate> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;
  bool _signedIn = false;
  bool _loading = true;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _rememberPassword = false;
  String _activity = 'مواد غذائية';
  String _accountType = 'إدارة نشاط';
  String _activityUserType = 'مستخدم رئيسي للنشاط';
  String? _error;

  static const _activityTypes = <String>[
    'مواد غذائية',
    'تجارة وتوزيع',
    'سوبر ماركت وبقالة',
    'مخازن ومستودعات',
    'تجارة عامة',
    'خدمات أخرى',
  ];

  @override
  void initState() {
    super.initState();
    try {
      final client = Supabase.instance.client;
      _signedIn = client.auth.currentSession != null;
      _loading = false;
      _authSubscription = client.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        setState(() {
          _signedIn = state.session != null;
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
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    final input = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
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
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'اكتب رقم الهاتف وكلمة المرور أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(
        phone: _normalizePhone(_phone.text),
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
      setState(() => _error = 'تعذر تسجيل الدخول. تحقق من الاتصال ورقم الهاتف وكلمة المرور.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showHelp(String title, String message, IconData icon) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: Icon(icon, color: _silsilaPurple, size: 34),
          title: Text(title, style: const TextStyle(color: _silsilaPurple, fontWeight: FontWeight.w900)),
          content: Text(message, style: const TextStyle(height: 1.7, color: _ink)),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _silsilaPurple),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTypeButton(String label, IconData icon) {
    final selected = _accountType == label;
    return Expanded(
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, color: _silsilaPurple, size: 16),
                  SizedBox(width: 6),
                  Text('بوابة دخول آمنة', style: TextStyle(color: _silsilaPurple, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          const Text('أهلًا بك في سلسلة', textAlign: TextAlign.center, style: TextStyle(color: _silsilaPurple, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('سجّل دخولك لإدارة شركتك وبياناتك بأمان', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF756A80), fontSize: 12, height: 1.6)),
          const SizedBox(height: 19),
          DropdownButtonFormField<String>(
            value: _activity,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'نوع النشاط',
              prefixIcon: Icon(Icons.business_center_outlined, color: _silsilaPurple),
              border: OutlineInputBorder(),
            ),
            items: _activityTypes.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) { if (value != null) setState(() => _activity = value); },
          ),
          const SizedBox(height: 14),
          const Text('اختار طريقة دخولك', textAlign: TextAlign.center, style: TextStyle(color: _silsilaPurple, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(children: [
            _accountTypeButton('مورد', Icons.inventory_2_outlined),
            _accountTypeButton('عميل', Icons.storefront_outlined),
            _accountTypeButton('مندوب', Icons.badge_outlined),
            _accountTypeButton('إدارة نشاط', Icons.admin_panel_settings_outlined),
          ]),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _pageBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9E1F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('تسجيل دخول النشاط', style: TextStyle(color: _silsilaPurple, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'مستخدم رئيسي للنشاط', label: Text('مستخدم رئيسي'), icon: Icon(Icons.admin_panel_settings_outlined)),
                    ButtonSegment(value: 'مستخدم فرعي للنشاط', label: Text('مستخدم فرعي'), icon: Icon(Icons.person_outline)),
                  ],
                  selected: {_activityUserType},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) => setState(() => _activityUserType = values.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(labelText: 'اكتب هنا رقمك المسجل لدينا', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _busy ? null : _login(),
                  autofillHints: const [AutofillHints.password],
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
                  title: const Text('تذكر بيانات الدخول', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('استخدم مدير كلمات المرور في المتصفح لحفظها بأمان', style: TextStyle(fontSize: 11)),
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
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login_rounded), SizedBox(width: 8), Text('دخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]),
                  ),
                ),
                TextButton(
                  onPressed: () => _showHelp('استعادة كلمة المرور', 'لاستعادة كلمة المرور، استخدم خيار الاستعادة في تطبيق سلسلة أو تواصل مع مسؤول النظام للتحقق من رقم الهاتف المسجل وإعادة تفعيل الحساب.', Icons.lock_reset_rounded),
                  child: const Text('نسيت كلمة المرور؟'),
                ),
                const Divider(height: 22),
                OutlinedButton.icon(
                  onPressed: () => _showHelp('إنشاء مستخدم جديد', 'يتم إنشاء الحساب من خلال تطبيق سلسلة، ثم يضيف مدير النشاط المستخدم إلى الشركة ويحدد صلاحياته قبل دخوله إلى نظام الإدارة.', Icons.person_add_alt_1_rounded),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إنشاء مستخدم جديد'),
                  style: OutlinedButton.styleFrom(foregroundColor: _silsilaPurple, side: const BorderSide(color: _silsilaPurple), padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _showHelp('إنشاء نشاط جديد', 'ابدأ بإنشاء حسابك في تطبيق سلسلة، ثم افتح نظام الإدارة لاستكمال بيانات الشركة. يلزم تسجيل الدخول بحساب فعلي قبل حفظ بيانات الشركة.', Icons.add_business_rounded),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('إنشاء نشاط جديد'),
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
              Container(
                width: 66,
                height: 66,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Image.asset(
                  'assets/images/silsila_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.hub_rounded, color: _silsilaPurple, size: 44),
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سلسلة Silsila', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                    SizedBox(height: 5),
                    Text('بنربط السوق ببعضه', style: TextStyle(color: _silsilaOrange, fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          const Text('منصة واحدة تربط التجارة والإدارة', style: TextStyle(color: Colors.white, fontSize: 21, height: 1.45, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'نظام سلسلة لإدارة النشاط ومتابعة العمليات، من بيانات الشركة والحسابات إلى المخازن والعملاء والموردين.',
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
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _silsilaPurple, size: 23),
              SizedBox(width: 10),
              Expanded(child: Text('رؤيتنا: سوق متصل، معلومات أوضح، وخطوات أسهل لكل شريك.', style: TextStyle(color: _silsilaPurple, fontWeight: FontWeight.w800, height: 1.6, fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn) return const ErpDashboardScreen();

    return Directionality(
      textDirection: TextDirection.rtl,
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
                                  const Text('نظام إدارة سلسلة', style: TextStyle(color: _silsilaPurple, fontWeight: FontWeight.w900, fontSize: 13)),
                                  const Spacer(),
                                  Text('SILSILA • MANAGEMENT PORTAL', style: TextStyle(color: _silsilaPurple.withValues(alpha: 0.62), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                                ],
                              ),
                              const SizedBox(height: 17),
                              content,
                              const SizedBox(height: 22),
                              const Center(
                                child: Text('سلسلة Silsila  •  بنربط السوق ببعضه', style: TextStyle(color: Color(0xFF8A7D95), fontSize: 11, fontWeight: FontWeight.w700)),
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

