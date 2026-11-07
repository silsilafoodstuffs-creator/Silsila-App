import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hrCatalogPurple = Color(0xFF3E007D);

class ErpHrCatalogScreen extends StatefulWidget {
  const ErpHrCatalogScreen({
    super.key,
    required this.companyId,
    required this.catalogType,
    required this.title,
  });

  final String? companyId;
  final String catalogType;
  final String title;

  @override
  State<ErpHrCatalogScreen> createState() => _ErpHrCatalogScreenState();
}

class _ErpHrCatalogScreenState extends State<ErpHrCatalogScreen> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String,dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final company = (widget.companyId ?? '').trim();
    if (company.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = 'افتح بيانات الشركة أولًا.'; });
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await _db.from('erp_hr_reference_catalogs')
          .select('id,code,name_ar,name_en,description,is_active,sort_order')
          .eq('company_id', company)
          .eq('catalog_type', widget.catalogType)
          .order('sort_order')
          .order('name_ar');
      if (!mounted) return;
      setState(() {
        _rows = (result as List).map((e) => Map<String,dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل الدليل: $e'; });
    }
  }

  Future<void> _edit({Map<String,dynamic>? row}) async {
    final name = TextEditingController(text: row?['name_ar']?.toString() ?? '');
    final english = TextEditingController(text: row?['name_en']?.toString() ?? '');
    final description = TextEditingController(text: row?['description']?.toString() ?? '');
    var active = row?['is_active'] != false;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(row == null ? 'إضافة إلى ${widget.title}' : 'تعديل ${widget.title}'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (row != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('الكود: ${row['code']}', style: const TextStyle(color: _hrCatalogPurple, fontWeight: FontWeight.w800)),
                      ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'الاسم بالعربية *', border: OutlineInputBorder()),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم العربي مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: english,
                      decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: description,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'الوصف / ملاحظات', border: OutlineInputBorder()),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نشط'),
                      value: active,
                      onChanged: (v) => refresh(() => active = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _hrCatalogPurple),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final company = (widget.companyId ?? '').trim();
                final payload = <String,dynamic>{
                  'company_id': company,
                  'catalog_type': widget.catalogType,
                  'name_ar': name.text.trim(),
                  'name_en': english.text.trim().isEmpty ? null : english.text.trim(),
                  'description': description.text.trim().isEmpty ? null : description.text.trim(),
                  'is_active': active,
                };
                try {
                  if (row == null) {
                    await _db.from('erp_hr_reference_catalogs').insert(payload);
                  } else {
                    payload.remove('catalog_type');
                    await _db.from('erp_hr_reference_catalogs').update(payload)
                        .eq('id', row['id']).eq('company_id', company);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    english.dispose();
    description.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(Map<String,dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف «${row['name_ar']}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _db.from('erp_hr_reference_catalogs').delete()
          .eq('id', row['id']).eq('company_id', (widget.companyId ?? '').trim());
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _rows.where((r) {
      final value = '${r['code']} ${r['name_ar']} ${r['name_en'] ?? ''}'.toLowerCase();
      return query.isEmpty || value.contains(query);
    }).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFFAF8FC),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.title, style: const TextStyle(color: _hrCatalogPurple, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('دليل مرجعي مرتبط بالشركة. يُنشأ الكود تلقائيًا عند الحفظ ولا يتكرر داخل نفس الدليل.', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _loading ? null : () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة نوع'),
                          style: FilledButton.styleFrom(backgroundColor: _hrCatalogPurple),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تحديث'),
                        ),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'بحث بالكود أو الاسم',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('عدد السجلات: ${_rows.length} • المعروض: ${visible.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? const Center(child: Text('لا توجد أنواع مسجلة بعد. استخدم «إضافة نوع» لإنشاء أول سجل.'))
                      : Card(
                          elevation: 0,
                          color: Colors.white,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('الكود')),
                                DataColumn(label: Text('الاسم بالعربية')),
                                DataColumn(label: Text('الاسم بالإنجليزية')),
                                DataColumn(label: Text('الحالة')),
                                DataColumn(label: Text('الإجراءات')),
                              ],
                              rows: visible.map((r) => DataRow(cells: [
                                DataCell(Text(r['code']?.toString() ?? '')),
                                DataCell(Text(r['name_ar']?.toString() ?? '')),
                                DataCell(Text(r['name_en']?.toString() ?? '')),
                                DataCell(Text(r['is_active'] == true ? 'نشط' : 'غير نشط')),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(tooltip: 'تعديل', onPressed: () => _edit(row: r), icon: const Icon(Icons.edit_outlined, color: _hrCatalogPurple)),
                                  IconButton(tooltip: 'حذف', onPressed: () => _delete(r), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                                ])),
                              ])).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
