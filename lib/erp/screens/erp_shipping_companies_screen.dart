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

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: _shippingPurple.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.local_shipping_outlined, color: _shippingPurple)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إدارة شركات الشحن', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _shippingPurple)),
          SizedBox(height: 4),
          Text('إدارة الشركات المسجلة وربطها بحسابات الشحن.', style: TextStyle(color: Colors.black54)),
        ])),
        IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة')),
      ]),
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
