import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _leadPurple = Color(0xFF3E007D);
const _leadOrange = Color(0xFFFFA015);

class ErpPublicLeadsScreen extends StatefulWidget {
  const ErpPublicLeadsScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpPublicLeadsScreen> createState() => _ErpPublicLeadsScreenState();
}

class _ErpPublicLeadsScreenState extends State<ErpPublicLeadsScreen> {
  SupabaseClient? _db;
  bool _loading = true;
  String? _error;
  String _status = 'all';
  String _governorate = 'الكل';
  final List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpPublicLeadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  Future<void> _load() async {
    if (_db == null || (widget.companyId ?? '').isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final filter = 'company_id.is.null,company_id.eq.' + widget.companyId!;
      final rows = await _db!.from('erp_public_lead_staging').select()
          .or(filter).order('governorate').order('business_name');
      if (mounted) setState(() {
        _leads..clear()..addAll((rows as List).cast<Map<String, dynamic>>());
      });
    } catch (e) {
      if (mounted) setState(() => _error =
          'تعذر تحميل دليل العملاء المحتملين. تأكد من تطبيق ملفات SQL وترتيب الصلاحيات.\n' + e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleLeads => _leads.where((lead) {
    final statusMatches = _status == 'all' ||
        (lead['verification_status'] ?? 'needs_review') == _status;
    final areaMatches = _governorate == 'الكل' ||
        (lead['governorate'] ?? '').toString() == _governorate;
    return statusMatches && areaMatches;
  }).toList();

  Future<void> _importLead(Map<String, dynamic> lead) async {
    final companyId = widget.companyId;
    if (_db == null || companyId == null || companyId.isEmpty) {
      _toast('اختر شركة نشطة واربطها بقاعدة البيانات أولًا.');
      return;
    }
    if (lead['verification_status'] == 'imported') {
      _toast('هذا السجل مستورد بالفعل.');
      return;
    }
    final kind = (lead['lead_kind'] ?? '').toString();
    final partyKind = kind == 'potential_supplier' || kind == 'wholesaler' || kind == 'manufacturer'
        ? 'supplier' : 'customer';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة كمسودة غير نشطة'),
          content: Text('سيضاف "' + (lead['business_name'] ?? '').toString() +
              '" إلى دليل ' + (partyKind == 'supplier' ? 'الموردين' : 'العملاء') +
              ' داخل الشركة الحالية. المعلومات من مصدر عام وغير مؤكدة؛ لن يتم تفعيل السجل تلقائيًا.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة كمسودة')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final leadId = lead['id'].toString();
      final code = 'LEAD-' + leadId.replaceAll('-', '').substring(0, 10).toUpperCase();
      final inserted = await _db!.from('erp_parties').insert({
        'company_id': companyId,
        'party_code': code,
        'party_name': lead['business_name'],
        'party_kind': partyKind,
        'phone': lead['public_phone'],
        'address': lead['public_address'],
        'governorate': lead['governorate'],
        'district': lead['district'],
        'business_classification': lead['business_classification'],
        'source_name': lead['source_name'],
        'source_url': lead['source_url'],
        'is_demo_data': false,
        'is_active': false,
      }).select('id').single();
      await _db!.from('erp_public_lead_staging').update({
        'company_id': companyId,
        'imported_party_id': inserted['id'],
        'verification_status': 'imported',
        'verification_notes': 'أضيف كمسودة غير نشطة؛ يجب التحقق من الاسم والعنوان ووسائل الاتصال قبل التفعيل.',
      }).eq('id', leadId);
      await _load();
      _toast('تمت الإضافة كمسودة غير نشطة. راجعها قبل التفعيل.');
    } catch (e) {
      _toast('تعذرت الإضافة. تحقق من صلاحيات الشركة وملف حقول المصدر.\n' + e.toString());
    }
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSource(Map<String, dynamic> lead) async {
    final sourceUrl = (lead['source_url'] ?? '').toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text((lead['source_name'] ?? 'المصدر العام').toString()),
          content: SelectableText(sourceUrl.isEmpty ? 'لا يوجد رابط مصدر.' : sourceUrl),
          actions: [
            if (sourceUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: sourceUrl));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _toast('تم نسخ رابط المصدر.');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ الرابط'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCompany = _db != null && (widget.companyId ?? '').isNotEmpty;
    final visible = _visibleLeads;
    final areas = <String>{'الكل', ..._leads.map((e) => (e['governorate'] ?? '').toString()).where((e) => e.isNotEmpty)}.toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_leadPurple, Color(0xFF7443A6)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.travel_explore_rounded, color: _leadOrange, size: 42),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('قاعدة العملاء المحتملين', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('أدلة عامة • مصادر واضحة • مراجعة قبل الاستيراد', style: TextStyle(color: Color(0xFFEFE5F8), fontSize: 14)),
              ])),
              IconButton(tooltip: 'تحديث', onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFFFFF4DE), borderRadius: BorderRadius.circular(13)),
            child: Text(
              hasCompany
                  ? 'الأسماء والعناوين أدناه من أدلة عامة وليست عملاء متعاقدين. الاستيراد ينشئ سجلًا غير نشط حتى التحقق اليدوي.'
                  : 'يلزم اختيار شركة نشطة وتطبيق ملفات SQL الخاصة بالدليل العام وحقول المصدر حتى يتم التحميل والاستيراد.',
              style: const TextStyle(color: Color(0xFF795000), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _statusChip('all', 'الكل'),
            _statusChip('needs_review', 'بحاجة للمراجعة'),
            _statusChip('imported', 'تم الاستيراد'),
            SizedBox(width: 190, child: DropdownButtonFormField<String>(
              value: areas.contains(_governorate) ? _governorate : 'الكل',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder(), isDense: true),
              items: areas.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
              onChanged: (value) => setState(() => _governorate = value ?? 'الكل'),
            )),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 10),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (!hasCompany)
            const Expanded(child: Center(child: Text('لا يمكن تحميل السجلات قبل اختيار الشركة النشطة.')))
          else if (visible.isEmpty)
            const Expanded(child: Center(child: Text('لا توجد سجلات مطابقة للفلاتر.')))
          else
            Expanded(child: ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final lead = visible[index];
                final imported = lead['verification_status'] == 'imported';
                final kind = (lead['lead_kind'] ?? '').toString();
                final icon = kind == 'potential_supplier' || kind == 'wholesaler' || kind == 'manufacturer'
                    ? Icons.local_shipping_rounded
                    : kind == 'institution' ? Icons.account_balance_rounded : Icons.storefront_rounded;
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE9E2F0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 45, height: 45, decoration: BoxDecoration(color: _leadPurple.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _leadPurple, size: 26)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((lead['business_name'] ?? '').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        Text((lead['business_classification'] ?? 'نشاط غير محدد').toString() + ' • ' +
                            (lead['governorate'] ?? '').toString() + ' • ' + (lead['district'] ?? '').toString(),
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ])),
                      if (imported) const Chip(label: Text('مستورد'), visualDensity: VisualDensity.compact),
                    ]),
                    if ((lead['public_address'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 9), child: Text(lead['public_address'].toString())),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 5, children: [
                      OutlinedButton.icon(onPressed: () => _showSource(lead), icon: const Icon(Icons.link_rounded, size: 17), label: const Text('المصدر')),
                      if (!imported) FilledButton.icon(onPressed: () => _importLead(lead), icon: const Icon(Icons.person_add_alt_1_rounded, size: 17), label: const Text('إضافة كمسودة')),
                    ]),
                    const Text('تحقق من العنوان والنشاط ووسائل الاتصال قبل تحويل السجل إلى عميل أو مورد نشط.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ]),
                );
              },
            )),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: _status == value,
    selectedColor: const Color(0xFFEDE3F7),
    onSelected: (_) => setState(() => _status = value),
  );
}
