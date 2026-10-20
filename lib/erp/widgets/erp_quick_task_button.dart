import 'package:flutter/material.dart';

/// One consistent visual system for ERP task actions across every screen.
class ErpQuickTaskButton extends StatelessWidget {
  const ErpQuickTaskButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.fallbackColor = const Color(0xFF3E007D),
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color fallbackColor;
  final bool compact;

  Color get _color {
    final value = label.trim().toLowerCase();
    if (value.contains('تحديث') || value.contains('تحميل') || value.contains('إعادة تحميل')) {
      return const Color(0xFF2475B8);
    }
    if (value == 'إضافة' || value.contains('إضافة ') || value.contains('إضافة/')) {
      return const Color(0xFF18865A);
    }
    if (value == 'حفظ' || value.contains('حفظ ')) {
      return const Color(0xFF6F42C1);
    }
    if (value == 'تعديل' || value.contains('تعديل ')) {
      return const Color(0xFFFFA015);
    }
    if (value == 'حذف' || value.contains('حذف ')) {
      return const Color(0xFFB42318);
    }
    if (value.contains('معاينة') || value.contains('عرض')) {
      return const Color(0xFF6E2BA6);
    }
    if (value.contains('excel') || value.contains('استيراد')) {
      return const Color(0xFF16834A);
    }
    if (value.contains('pdf')) {
      return const Color(0xFFD32F2F);
    }
    if (value.contains('طباعة') || value.contains('print')) {
      return const Color(0xFFFF27C3);
    }
    if (value.contains('إلغاء')) {
      return const Color(0xFF64748B);
    }
    return fallbackColor;
  }

  IconData get _icon {
    final value = label.trim().toLowerCase();
    if (value.contains('تحديث') || value.contains('تحميل')) return Icons.refresh_rounded;
    if (value == 'إضافة' || value.contains('إضافة ') || value.contains('إضافة/')) return Icons.add_circle_outline_rounded;
    if (value == 'حفظ' || value.contains('حفظ ')) return Icons.save_outlined;
    if (value == 'تعديل' || value.contains('تعديل ')) return Icons.edit_outlined;
    if (value == 'حذف' || value.contains('حذف ')) return Icons.delete_outline_rounded;
    if (value.contains('معاينة') || value.contains('عرض')) return Icons.preview_outlined;
    if (value.contains('تصدير')) return Icons.file_download_outlined;
    if (value.contains('excel') || value.contains('استيراد')) return Icons.file_upload_outlined;
    if (value.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (value.contains('طباعة') || value.contains('print')) return Icons.print_outlined;
    if (value.contains('إلغاء')) return Icons.clear_all_rounded;
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 5, top: 3, bottom: 3),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(_icon, size: compact ? 16 : 17),
        label: Text(
          label,
          softWrap: false,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: .35),
          disabledForegroundColor: Colors.white70,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 8 : 10,
          ),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}
