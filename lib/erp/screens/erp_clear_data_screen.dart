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
    'بيانات الشركة','الفروع ومراكز التكلفة','أنواع الأنشطة','أنواع المستخدمين','تصنيفات المستخدمين',
    'المستخدمين','قوالب صلاحيات المستخدمين','صلاحيات المستخدمين','إعدادات البرنامج','سجل العمليات',
    'سياسات التسعير والخصومات','شجرة الحسابات','الفترات المالية','مراكز التكلفة','العملات',
    'الخزائن الرئيسية والفرعية','دليل المخازن','فئات الأصناف','مجموعات الأصناف','دليل الأصناف',
    'دليل الموردين','دليل العملاء','قوائم أسعار البيع','قوائم أسعار الموردين','عروض الأصناف',
    'قاعدة العملاء المحتملين','الهيكل الوظيفي','الإدارات والأقسام','الوظائف والدرجات','ملف الموظف',
    'الحملات التسويقية','قواعد العروض','قنوات التواصل','سجلات التكامل والطلبات',
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
        content: Text('سيتم أخذ نسخة احتياطية على السيرفر ثم على الجهاز. بعد نجاح النسختين فقط سيتم حذف السجلات العامة المرتبطة بالشاشات المحددة (${_selected.length} شاشة). لا يمكن التراجع من هذه الشاشة. البيانات المخزنة في جداول متخصصة مثل الفواتير والمخزون لا يشملها هذا الإصدار.'),
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
      final records = await db.from('erp_workspace_records').select('page_key,record_key,record_data,created_at,updated_at').eq('company_id', companyId).inFilter('page_key', pages);
      final backupId = 'backup_${DateTime.now().toUtc().millisecondsSinceEpoch}';
      final payload = <String, dynamic>{
        'format':'silsila-selective-backup-v1',
        'backup_id':backupId,
        'created_at':DateTime.now().toUtc().toIso8601String(),
        'company_id':companyId,
        'selected_pages':pages,
        'record_count':(records as List).length,
        'records':records,
      };
      await db.from('erp_data_backups').insert({
        'company_id':companyId,'backup_id':backupId,'backup_type':'selective_clear',
        'selected_pages':pages,'record_count':records.length,'payload':payload,
        'created_by':db.auth.currentUser!.id,
      });
      if (!mounted) return;
      setState(() => _status = 'نجحت النسخة الأولى على السيرفر. جاري الحفظ على الجهاز...');
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
      final savedPath = await FileSaver.instance.saveFile(
        name: 'silsila_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}',
        bytes: bytes, fileExtension: 'json', mimeType: MimeType.json,
      );
      if (savedPath.isEmpty) {
        throw StateError('لم يؤكد النظام حفظ ملف النسخة الاحتياطية على الجهاز؛ تم إلغاء المسح.');
      }
      if (!mounted) return;
      setState(() => _status = 'نجحت النسختان. جاري مسح السجلات المحددة...');
      await db.from('erp_workspace_records').delete().eq('company_id', companyId).inFilter('page_key', pages);
      if (!mounted) return;
      setState(() {
        _status = 'تم حفظ النسختين ثم مسح السجلات العامة المطابقة. عدد السجلات التي شملتها النسخة: ${records.length}.';
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
