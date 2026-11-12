import 'dart:async';
import 'package:flutter/material.dart';
import 'erp_center_toast.dart';

/// Semantic action kinds keep button styling independent from localized labels.
enum ErpQuickTaskKind {
  update,
  add,
  save,
  edit,
  delete,
  preview,
  exportExcel,
  exportPdf,
  print,
  cancel,
  treeView,
  tableView,
  image,
  custom,
}

/// One consistent visual system for ERP task actions across every screen.
class ErpQuickTaskButton extends StatelessWidget {
  const ErpQuickTaskButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.fallbackColor = const Color(0xFF3E007D),
    this.compact = false,
    this.kind,
  });

  final String label;
  final IconData icon;
  final FutureOr<void> Function()? onPressed;
  final Color fallbackColor;
  final bool compact;
  final ErpQuickTaskKind? kind;

  Color get _color {
    switch (kind) {
      case ErpQuickTaskKind.update:
        return const Color(0xFF2475B8);
      case ErpQuickTaskKind.add:
        return const Color(0xFF18865A);
      case ErpQuickTaskKind.save:
        return const Color(0xFF6F42C1);
      case ErpQuickTaskKind.edit:
        return const Color(0xFFFFA015);
      case ErpQuickTaskKind.delete:
        return const Color(0xFFB42318);
      case ErpQuickTaskKind.preview:
      case ErpQuickTaskKind.treeView:
      case ErpQuickTaskKind.tableView:
        return const Color(0xFF6E2BA6);
      case ErpQuickTaskKind.exportExcel:
        return const Color(0xFF16834A);
      case ErpQuickTaskKind.exportPdf:
        return const Color(0xFFD32F2F);
      case ErpQuickTaskKind.print:
        return const Color(0xFFFF27C3);
      case ErpQuickTaskKind.cancel:
        return const Color(0xFF64748B);
      case ErpQuickTaskKind.image:
      case ErpQuickTaskKind.custom:
        return fallbackColor;
      case null:
        break;
    }
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
    switch (kind) {
      case ErpQuickTaskKind.update:
        return Icons.refresh_rounded;
      case ErpQuickTaskKind.add:
        return Icons.add_circle_outline_rounded;
      case ErpQuickTaskKind.save:
        return Icons.save_outlined;
      case ErpQuickTaskKind.edit:
        return Icons.edit_outlined;
      case ErpQuickTaskKind.delete:
        return Icons.delete_outline_rounded;
      case ErpQuickTaskKind.preview:
        return Icons.preview_outlined;
      case ErpQuickTaskKind.exportExcel:
        return Icons.file_upload_outlined;
      case ErpQuickTaskKind.exportPdf:
        return Icons.picture_as_pdf_outlined;
      case ErpQuickTaskKind.print:
        return Icons.print_outlined;
      case ErpQuickTaskKind.cancel:
        return Icons.clear_all_rounded;
      case ErpQuickTaskKind.treeView:
        return Icons.account_tree_outlined;
      case ErpQuickTaskKind.tableView:
        return Icons.table_rows_outlined;
      case ErpQuickTaskKind.image:
      case ErpQuickTaskKind.custom:
        return icon;
      case null:
        break;
    }
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
        onPressed: onPressed == null ? null : () async {
          final action = label.trim();
          final isSave = kind == ErpQuickTaskKind.save ||
              (kind == null && action.contains('حفظ'));
          final isDelete = kind == ErpQuickTaskKind.delete ||
              (kind == null && action.contains('حذف'));
          if (isSave || isDelete) {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(isSave ? 'تأكيد الحفظ' : 'تأكيد الحذف'),
                content: Text(isSave ? 'هل ترغب في الحفظ؟' : 'هل ترغب في الحذف؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(isSave ? 'حفظ' : 'حذف'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
          }
          try {
            await Future<void>.sync(onPressed!);
            if (!context.mounted) return;
            final successMessage = kind == ErpQuickTaskKind.save || (kind == null && isSave)
                ? 'تم الحفظ'
                : kind == ErpQuickTaskKind.delete || (kind == null && isDelete)
                    ? 'تم الحذف'
                    : kind == ErpQuickTaskKind.update || (kind == null && action.contains('تحديث'))
                        ? 'تم التحديث'
                        : null;
            if (successMessage != null) {
              ErpCenterToast.show(context, successMessage);
            }
          } catch (error) {
            if (!context.mounted) return;
            ErpCenterToast.show(context, 'تعذر تنفيذ العملية: $error', isError: true, duration: const Duration(seconds: 3));
          }
        },
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
