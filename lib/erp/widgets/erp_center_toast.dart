import 'dart:async';
import 'package:flutter/material.dart';

/// Compact, centered in-app feedback for ERP actions.
class ErpCenterToast {
  ErpCenterToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 1900),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || message.trim().isEmpty) return;

    _timer?.cancel();
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;

    final background = isError ? const Color(0xFFB42318) : const Color(0xFF18865A);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: SafeArea(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 150),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: .96 + (.04 * value),
                    child: child,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: IntrinsicWidth(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white.withValues(alpha: .72), width: .8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .16),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                              color: Colors.white, size: 19),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
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
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () {
      if (identical(_entry, entry)) {
        try {
          entry.remove();
        } catch (_) {}
        _entry = null;
      }
    });
  }
}
