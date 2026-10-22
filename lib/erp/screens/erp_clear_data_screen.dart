import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class ErpClearDataScreen extends StatefulWidget {
  const ErpClearDataScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpClearDataScreen> createState() => _ErpClearDataScreenState();
}

class _ErpClearDataScreenState extends State<ErpClearDataScreen> {
  final Set<String> _selected = <String>{};
  bool _busy = false;
  String _status = '';
  static const List<String> _screens = <String>[
    'بيانات الشركة', 'الفروع ومراكز التكلفة', 'أنواع المستخدمين',
    'تصنيفات المستخدمين', 'المستخدمين', 'قوالب صلاحيات المستخدمين',
    'صلاحيات المستخدمين', 'إعدادات البرنامج', 'سجل العمليات', 'إدارة الشعار والصور',
    'إدارة صور الأصناف والفئات', 'إدارة صور الموردين والعملاء', 'إدارة صلاحيات التطبيقات',
    'إدارة ألوان التطبيقات', 'سياسات التسعير والخصومات', 'شجرة الحسابات', 'الفترات المالية',
    'مراكز التكلفة', 'العملات', 'الخزائن الرئيسية والفرعية', 'سندات القبض', 'سندات الصرف',
    'دليل المخازن', 'فئات الأصناف', 'مجموعات الأصناف', 'دليل الأصناف', 'دليل الموردين',
    'دليل العملاء', 'قوائم أسعار البيع', 'قوائم أسعار الموردين', 'عروض الأصناف',
    'قاعدة العملاء المحتملين', 'الهيكل الوظيفي', 'الإدارات والأقسام', 'الوظائف والدرجات',
    'ملف الموظف', 'الإجازات والأذونات', 'مسير الرواتب', 'صرف الرواتب',
    'أهداف العملاء الشهرية', 'خطط العمولة',
    'مسودات العمولات', 'توزيع الأصناف على المندوبين',
    'عرض سعر', 'أمر بيع', 'فاتورة بيع', 'فاتورة مبيعات', 'مرتجع مبيعات', 'إذن تجهيز',
    'إذن تسليم', 'إذن إضافة', 'إذن صرف',
    'تحويل مخزني', 'تسوية جرد', 'جرد فعلي', 'أمر شراء', 'استلام مشتريات',
    'فاتورة مشتريات', 'مرتجع مشتريات', 'خريطة الحسابات التشغيلية', 'قيود اليومية',
    'إعدادات الفاتورة الإلكترونية',
    'سجلات الفاتورة الإلكترونية', 'واجهة API والربط الخارجي', 'إدارة مفاتيح API',
    'سجلات التكامل والطلبات', 'إعداد نقاط الربط', 'الحملات التسويقية',
    'قنوات التواصل',
  ];

  SupabaseClient? get _db {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  Future<void> _backupAndClear() async {
    final db = _db;
    final companyId = widget.companyId;
    if (db == null || db.auth.currentUser == null) {
      setState(() => _status = 'يجب تسجيل الدخول إلى قاعدة البيانات أولاً.'); return;
    }
    if (companyId == null || companyId.trim().isEmpty) {
      setState(() => _status = 'لا توجد شركة محددة مرتبطة بالمستخدم الحالي.'); return;
    }
    if (_selected.isEmpty) { setState(() => _status = 'حدد شاشة واحدة على الأقل.'); return; }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 38),
        title: const Text('تحذير: مسح بيانات'),
        content: Text('سيتم أخذ نسخة كاملة من بيانات الشاشات المحددة على السيرفر ثم حفظ نسخة على الجهاز. لن يبدأ الحذف إلا بعد نجاح النسختين. بعض البيانات المرجعية المشتركة وحسابات الدخول ومعرّف الشركة محمية من المسح. إذا كانت هناك سجلات مرتبطة بشاشات غير محددة، سيتوقف الحذف وتظل النسخة الاحتياطية محفوظة. الإجراء نهائي ولا يمكن التراجع عنه من هذه الشاشة. عدد الشاشات المحددة: ${_selected.length}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('موافق، متابعة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _status = 'جاري تجهيز النسخة الاحتياطية من السيرفر...'; });
    try {
      final pages = _selected.toList()..sort();
      final prepared = await db.rpc('erp_prepare_selective_data_clear', params: {
        'p_company_id': companyId,
        'p_selected_pages': pages,
      });
      if (prepared is! Map) {
        throw StateError('لم يرجع السيرفر بيانات النسخة الاحتياطية بالشكل المتوقع.');
      }
      final payload = Map<String, dynamic>.from(prepared);
      final backupId = payload['backup_id']?.toString() ?? '';
      if (backupId.isEmpty || payload['tables'] is! Map) {
        throw StateError('النسخة الاحتياطية على السيرفر غير مكتملة؛ تم إلغاء المسح.');
      }
      if (!mounted) return;
      setState(() => _status = 'تم حفظ نسخة السيرفر. جاري حفظ نسخة الجهاز...');
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
      final savedPath = await FileSaver.instance.saveFile(
        name: 'silsila_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}',
        bytes: bytes, fileExtension: 'json', mimeType: MimeType.json,
      );
      if (savedPath.isEmpty) {
        throw StateError('لم يؤكد النظام حفظ ملف النسخة الاحتياطية على الجهاز؛ تم إلغاء المسح.');
      }
      if (!mounted) return;
      setState(() => _status = 'نجحت النسختان. جاري مسح بيانات الشاشات المحددة...');
      final cleared = await db.rpc('erp_complete_selective_data_clear', params: {
        'p_company_id': companyId,
        'p_backup_id': backupId,
      });
      final result = cleared is Map ? Map<String, dynamic>.from(cleared) : <String, dynamic>{};
      if (result['success'] != true) {
        throw StateError('لم يؤكد السيرفر اكتمال عملية المسح.');
      }
      if (!mounted) return;
      setState(() {
        _status = 'اكتملت النسخة الاحتياطية على السيرفر والجهاز ثم مسح البيانات المحددة. عدد السجلات المحفوظة في النسخة: ${payload['record_count'] ?? 0}. رقم النسخة: $backupId.';
        _selected.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'توقف الإجراء بسبب خطأ. لم يُطلب المسح إلا بعد نجاح النسختين. التفاصيل: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: _purple, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        child: const Row(children: [
          Icon(Icons.delete_sweep_outlined, color: _orange, size: 27), SizedBox(width: 10),
          Expanded(child: Text('مسح جميع البيانات', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
          Text('إدارة البرنامج', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('حدد الشاشات المطلوب مسح بياناتها', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('الترتيب إلزامي: نسخة على السيرفر ← نسخة على الجهاز ← المسح. إذا فشلت إحدى النسختين فلن يبدأ المسح.'),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: _busy ? null : () => setState(() => _selected.addAll(_screens)), child: const Text('تحديد الكل')),
          TextButton(onPressed: _busy ? null : () => setState(_selected.clear), child: const Text('إلغاء التحديد')),
          Chip(label: Text('المحدد: ${_selected.length}')),
        ]),
        const Divider(),
        ..._screens.map((name) => CheckboxListTile(
          dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
          value: _selected.contains(name), title: Text(name),
          onChanged: _busy ? null : (value) => setState(() { if (value == true) { _selected.add(name); } else { _selected.remove(name); } }),
        )),
      ]))),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _busy ? null : _backupAndClear,
        style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete_forever_outlined),
        label: Text(_busy ? 'جاري تنفيذ النسخ الاحتياطي والمسح...' : 'نسخ احتياطي ثم مسح المحدد'),
      ),
      if (_status.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(10)), child: Text(_status)),
      ],
    ]),
  );
}
