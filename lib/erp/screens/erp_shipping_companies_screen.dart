import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _shippingPurple = Color(0xFF3E007D);

class ErpShippingCompaniesScreen extends StatefulWidget {
  const ErpShippingCompaniesScreen({super.key});

  @override
  State<ErpShippingCompaniesScreen> createState() => _ErpShippingCompaniesScreenState();
}

class _ErpShippingCompaniesScreenState extends State<ErpShippingCompaniesScreen> {
  SupabaseClient? _db;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  String _s(dynamic value) => (value ?? '').toString();

  Future<void> _load() async {
    if (_db == null) {
      setState(() { _loading = false; _error = 'سجّل الدخول إلى Supabase أولًا.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _db!.rpc('admin_list_shipping_companies');
      final rows = result is List ? result.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل شركات الشحن. هذه العملية متاحة لحساب إدارة النشاط المخول فقط، وتحتاج تطبيق supabase/18_shipping_operations.sql: $error';
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: _s(row?['name']));
    final phone = TextEditingController(text: _s(row?['phone']));
    final profile = TextEditingController(text: _s(row?['profile_id']));
    bool active = row?['is_active'] != false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text(row == null ? 'إضافة شركة شحن' : 'تعديل شركة الشحن'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم شركة الشحن *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: profile, decoration: const InputDecoration(labelText: 'معرّف حساب شركة الشحن UUID (اختياري)', border: OutlineInputBorder())),
              SwitchListTile(
                value: active,
                onChanged: (value) => refresh(() => active = value),
                title: const Text('الشركة نشطة'),
                contentPadding: EdgeInsets.zero,
              ),
              const Text('عند ربط الحساب، يجب أن يكون حساب Supabase مسجلًا بدور شركة شحن.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      )),
    );
    if (result != true) {
      name.dispose(); phone.dispose(); profile.dispose();
      return;
    }
    try {
      if (name.text.trim().isEmpty) throw ArgumentError('اسم شركة الشحن مطلوب.');
      final profileId = profile.text.trim();
      await _db!.rpc('admin_save_shipping_company', params: {
        'p_company_id': row == null ? null : row['id'],
        'p_profile_id': profileId.isEmpty ? null : profileId,
        'p_name': name.text.trim(),
        'p_phone': phone.text.trim(),
        'p_is_active': active,
      });
      if (!mounted) return;
      setState(() => _message = 'تم حفظ شركة الشحن في قاعدة البيانات.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ شركة الشحن: $error');
    } finally {
      name.dispose(); phone.dispose(); profile.dispose();
    }
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 5, top: 3, bottom: 3),
    child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), visualDensity: VisualDensity.compact),
      onPressed: action, icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
  );

  Future<void> _previewShippingCompanies() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة شركات الشحن'),
      content: SizedBox(width: 700, child: _rows.isEmpty ? const Text('لا توجد شركات شحن محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _rows.take(100).map((r) => ListTile(
          dense: true, title: Text('${r['company_name'] ?? r['name'] ?? '—'}'),
          subtitle: Text('${r['phone'] ?? ''} • ${r['is_active'] == true ? 'نشطة' : 'موقوفة'}'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: _shippingPurple, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.local_shipping_outlined, color: Color(0xFFFFA015), size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('إدارة شركات الشحن', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
          ]),
          const Text('إدارة الشركات المسجلة وربطها بحسابات الشحن.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), () => _edit()),
            _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewShippingCompanies),
          ])),
        ]),
      )),
      const SizedBox(height: 12),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
      else if (_rows.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد شركات شحن ظاهرة أو لا توجد صلاحية للإدارة.')))
      else
        ..._rows.map((row) {
          final active = row['is_active'] == true;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: active ? Colors.green.shade200 : Colors.grey.shade300)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: _shippingPurple.withValues(alpha: .09), child: const Icon(Icons.local_shipping_outlined, color: _shippingPurple)),
              title: Text(_s(row['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('الهاتف: ${_s(row['phone']).isEmpty ? '—' : _s(row['phone'])}\nالحساب: ${_s(row['profile_id']).isEmpty ? 'غير مربوط' : _s(row['profile_id'])}\nالحالة: ${active ? 'نشطة' : 'موقوفة'}'),
              isThreeLine: true,
              trailing: IconButton(tooltip: 'تعديل', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined, color: _shippingPurple)),
            ),
          );
        }),
    ]),
  );

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .3))),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
