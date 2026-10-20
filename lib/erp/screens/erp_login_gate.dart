import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../erp_dashboard_screen.dart';

const _erpPurple = Color(0xFF3E007D);
const _erpOrange = Color(0xFFFFA015);

/// Keeps the ERP available only to a real Supabase-authenticated session.
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
  String? _error;

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
      _error = 'تعذر تهيئة الاتصال الآمن بقاعدة البيانات.';
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
    final input = value.trim().replaceAll(RegExp(r'[\\s().-]'), '');
    if (input.startsWith('+')) return input;
    final digits = input.replaceAll(RegExp(r'\\D'), '');
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
        if (!_signedIn) {
          _error = 'لم يتم إنشاء جلسة دخول. أعد المحاولة.';
        }
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول. تحقق من الاتصال ثم أعد المحاولة. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn) return const ErpDashboardScreen();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5FA),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hub_rounded, color: _erpPurple, size: 62),
                      const SizedBox(height: 10),
                      const Text(
                        'سلسلة Silsila',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _erpPurple,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'تسجيل الدخول إلى نظام إدارة البرنامج',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف المسجل',
                            prefixIcon: Icon(Icons.phone_android),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _busy ? null : _login(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _login,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_busy ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول والمتابعة'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _erpPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'يلزم تسجيل الدخول بحسابك الفعلي قبل إنشاء بيانات الشركة أو تعديلها.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
