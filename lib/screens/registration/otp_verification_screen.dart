import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import 'registration_success_screen.dart';

class SilsilaOtpVerificationScreen extends StatefulWidget {
  const SilsilaOtpVerificationScreen({
    super.key,
    required this.email,
    this.onVerified,
  });

  final String email;
  final VoidCallback? onVerified;

  @override
  State<SilsilaOtpVerificationScreen> createState() =>
      _SilsilaOtpVerificationScreenState();
}

class _SilsilaOtpVerificationScreenState
    extends State<SilsilaOtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);

    try {
      final client = Supabase.instance.client;

      await client.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email.trim(),
        token: _otpController.text.trim(),
      );

      if (!mounted) return;

      if (widget.onVerified != null) {
        widget.onVerified!();
      } else {
        await Navigator.of(context).pushReplacement<bool, bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const SilsilaRegistrationSuccessScreen(),
          ),
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message.isNotEmpty
                ? error.message
                : 'تعذر التحقق من الرمز',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء التحقق. حاول مرة أخرى.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _isVerifying) return;

    setState(() => _isResending = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم طلب إعادة إرسال رمز التحقق'),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذرت إعادة إرسال الرمز. حاول مرة أخرى.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تأكيد الحساب'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          size: 48,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'رمز التحقق',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'أدخل رمز التحقق المكوّن من 6 أرقام '
                        'المرسل إلى بريدك الإلكتروني:',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'رمز التحقق',
                          hintText: '000000',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                          counterText: '',
                        ),
                        validator: (value) {
                          final code = value?.trim() ?? '';

                          if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                            return 'أدخل رمزًا صحيحًا مكوّنًا من 6 أرقام';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isVerifying ? null : _verifyCode,
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('تأكيد الرمز وتفعيل الحساب'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: (_isResending || _isVerifying)
                            ? null
                            : _resendCode,
                        icon: _isResending
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _isResending
                              ? 'جارٍ إرسال الرمز...'
                              : 'إعادة إرسال رمز التحقق',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'سلسلة .. بنربط السوق ببعضه',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: silsilaMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
