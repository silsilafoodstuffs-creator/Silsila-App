import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';

class SilsilaForgotPasswordScreen extends StatefulWidget {
  const SilsilaForgotPasswordScreen({super.key});

  @override
  State<SilsilaForgotPasswordScreen> createState() =>
      _SilsilaForgotPasswordScreenState();
}

class _SilsilaForgotPasswordScreenState
    extends State<SilsilaForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'من فضلك أدخل البريد الإلكتروني.';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'من فضلك أدخل بريدًا إلكترونيًا صحيحًا.';
    }

    return null;
  }

  Future<void> _sendResetLink() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.mark_email_read_outlined,
            color: orange,
            size: 42,
          ),
          title: const Text(
            'راجع بريدك الإلكتروني',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'إذا كان البريد الإلكتروني مسجلًا، فستصلك تعليمات '
            'إعادة تعيين كلمة المرور. راجع صندوق الوارد '
            'ومجلد الرسائل غير المرغوب فيها.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الطلب: ${error.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع. حاول مرة أخرى لاحقًا.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استعادة كلمة المرور'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 58,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'نسيت كلمة المرور؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا تقلق، سنساعدك على استعادة حسابك في سلسلة. '
                        'أدخل البريد الإلكتروني المسجل لإرسال تعليمات '
                        'إعادة تعيين كلمة المرور.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.8,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                        onFieldSubmitted: (_) => _sendResetLink(),
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _sendResetLink,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _loading
                                ? 'جارٍ إرسال الطلب...'
                                : 'إرسال رابط الاستعادة',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('العودة إلى تسجيل الدخول'),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'سلسلة .. بنربط السوق ببعضه',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: orange,
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
