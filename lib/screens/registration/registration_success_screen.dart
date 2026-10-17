import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class SilsilaRegistrationSuccessScreen extends StatelessWidget {
  const SilsilaRegistrationSuccessScreen({
    super.key,
    this.title = 'تم التفعيل بنجاح',
    this.message =
        'أصبح حسابك جاهزًا للمتابعة على تطبيق سلسلة.',
    this.buttonText = 'متابعة',
    this.onContinue,
  });

  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onContinue;

  void _continue(BuildContext context) {
    if (onContinue != null) {
      onContinue!();
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: silsilaCanvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 124,
                      height: 124,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F7EC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFB8E8C5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF219653),
                        size: 78,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: purple,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: silsilaMuted,
                            height: 1.8,
                          ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: silsilaBorder,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            color: purple,
                            size: 30,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'شكرًا لانضمامك إلى شبكة سلسلة '
                              'لتجارة المواد الغذائية بالجملة.',
                              style: TextStyle(
                                color: silsilaInk,
                                height: 1.7,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => _continue(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                        ),
                        label: Text(buttonText),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'سلسلة .. بنربط السوق ببعضه',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
