import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _taxPurple = Color(0xFF3E007D);
const _taxOrange = Color(0xFFFFA015);

class ErpEinvoiceScreen extends StatefulWidget {
  const ErpEinvoiceScreen({super.key, required this.companyId, required this.initialView});
  final String? companyId;
  final String initialView;
  @override
  State<ErpEinvoiceScreen> createState() => _ErpEinvoiceScreenState();
}

class _ErpEinvoiceScreenState extends State<ErpEinvoiceScreen> {
  static const views = <String>[
    'لوحة الفاتورة الإلكترونية','إعدادات الربط الضريبي','بيانات الممول والتوقيع الإلكتروني',
    'تكويد السلع والخدمات','فواتير إلكترونية صادرة','فواتير إلكترونية واردة',
    'إشعارات دائنة إلكترونية','إشعارات مدينة إلكترونية','إرسال المستندات للضرائب',
    'متابعة حالات الإرسال','إلغاء المستندات','رفض المستندات الواردة',
    'قبول أو رفض طلبات الإلغاء','قبول أو رفض طلبات الرفض','البحث عن مستند ضريبي',
    'المستندات الضريبية الحديثة','تفاصيل المستند والتحقق','طباعة الفاتورة الضريبية PDF',
    'طلبات حزم المستندات','تنزيل حزم المستندات','إشعارات منظومة الضرائب',
    'سجل عمليات التكامل','اختبار الاتصال الضريبي','تقارير الفاتورة الإلكترونية'
  ];
  final _formKey = GlobalKey<FormState>();
  final _taxNo = TextEditingController();
  final _branch = TextEditingController(text: '0');
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _activity = TextEditingController();
  final _search = TextEditingController();
  String _view = '';
  String _status = 'لم يتم التحقق من إعدادات الربط';
  bool _production = false, _busy = false, _loading = false;
  List<Map<String, dynamic>> _operations = [];
  String? _error;

  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }

  @override
  void initState() {
    super.initState();
    _view = views.contains(widget.initialView) ? widget.initialView : views.first;
    _loadSettings();
    _loadOperations();
  }
  @override
  void dispose() {
    _taxNo.dispose(); _branch.dispose(); _clientId.dispose(); _clientSecret.dispose(); _activity.dispose(); _search.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_db == null || widget.companyId == null) return;
    try {
      final r = await _db!.from('erp_einvoice_settings').select().eq('company_id', widget.companyId!).maybeSingle();
      if (!mounted || r == null) return;
      setState(() {
        _taxNo.text = (r['taxpayer_number'] ?? '').toString();
        _branch.text = (r['branch_code'] ?? '0').toString();
        _clientId.text = (r['client_id'] ?? '').toString();
        _clientSecret.text = (r['client_secret'] ?? '').toString();
        _activity.text = (r['activity_code'] ?? '').toString();
        _production = r['environment'] == 'production';
        _status = (r['connection_status'] ?? 'الإعدادات محفوظة ولم يتم اختبار الاتصال').toString();
      });
    } catch (e) { if (mounted) setState(() => _error = 'إعدادات الربط غير متاحة. طبّق ملف SQL المرفق أولاً. $e'); }
  }

  Future<void> _loadOperations() async {
    if (_db == null || widget.companyId == null) return;
    setState(() => _loading = true);
    try {
      final rows = await _db!.from('erp_einvoice_operations').select().eq('company_id', widget.companyId!).order('created_at', ascending: false).limit(100);
      if (mounted) setState(() { _operations = List<Map<String, dynamic>>.from(rows); _error = null; });
    } catch (e) { if (mounted) setState(() => _error = 'سجل العمليات غير متاح حتى تطبيق جداول Supabase. $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (_db == null || widget.companyId == null) { _msg('يلزم تسجيل الدخول واختيار شركة.'); return; }
    setState(() => _busy = true);
    try {
      await _db!.from('erp_einvoice_settings').upsert({
        'company_id': widget.companyId, 'taxpayer_number': _taxNo.text.trim(),
        'branch_code': _branch.text.trim(), 'client_id': _clientId.text.trim(),
        'client_secret': _clientSecret.text, 'activity_code': _activity.text.trim(),
        'environment': _production ? 'production' : 'preproduction',
        'connection_status': 'الإعدادات محفوظة؛ لم يتم التحقق من اتصال الهيئة',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _db!.auth.currentUser?.id,
      }, onConflict: 'company_id');
      if (mounted) setState(() => _status = 'تم حفظ الإعدادات؛ الاتصال بالهيئة لم يُختبر بعد');
      _msg('تم حفظ الإعدادات. الإرسال الفعلي يحتاج خدمة تكامل آمنة وشهادة رقمية.');
    } catch (e) { _msg('تعذر الحفظ: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _request(String action) async {
    if (_db == null || widget.companyId == null) { _msg('يلزم تسجيل الدخول واختيار شركة.'); return; }
    try {
      await _db!.from('erp_einvoice_operations').insert({
        'company_id': widget.companyId, 'action_key': action, 'document_type': _view,
        'reference_query': _search.text.trim().isEmpty ? null : _search.text.trim(),
        'status': 'pending_setup',
        'details': {'environment': _production ? 'production' : 'preproduction', 'note': 'طلب مسجل؛ يحتاج خدمة التكامل لمعالجته.'},
        'created_by': _db!.auth.currentUser?.id,
      });
      await _loadOperations();
      _msg('تم تسجيل الطلب في النظام، لكنه لم يُرسل إلى مصلحة الضرائب بعد.');
    } catch (e) { _msg('تعذر تسجيل الطلب: $e'); }
  }

  void _msg(String value) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value))); }
  Widget _field(String title, TextEditingController c, {bool secret = false, String? Function(String?)? validator}) =>
    TextFormField(controller: c, obscureText: secret, validator: validator, decoration: InputDecoration(labelText: title, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white));
  Widget _btn(String label, IconData icon, VoidCallback action, {bool primary = false}) =>
    FilledButton.icon(onPressed: action, icon: Icon(icon, size: 17), label: Text(label), style: FilledButton.styleFrom(backgroundColor: primary ? _taxPurple : const Color(0xFFF0E8F8), foregroundColor: primary ? Colors.white : _taxPurple));
  Widget _panel(String title, String description, Widget body) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8E0F0))), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(color: _taxPurple, fontWeight: FontWeight.w900, fontSize: 16), textAlign: TextAlign.start), const SizedBox(height: 5), Text(description, style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 14), body])));
  String _action() {
    if (_view.contains('إلغاء')) return 'cancel_document';
    if (_view.contains('رفض')) return 'reject_document';
    if (_view.contains('حزمة') || _view.contains('تنزيل')) return 'request_document_package';
    if (_view.contains('بحث') || _view.contains('حديثة')) return 'search_documents';
    if (_view.contains('طباعة')) return 'get_document_printout';
    if (_view.contains('تفاصيل')) return 'get_document_details';
    if (_view.contains('إرسال')) return 'submit_documents';
    if (_view.contains('واردة')) return 'incoming_documents';
    if (_view.contains('دائنة')) return 'credit_note';
    if (_view.contains('مدينة')) return 'debit_note';
    if (_view.contains('تكويد')) return 'item_code_lookup';
    return 'document_action';
  }

  @override
  Widget build(BuildContext context) {
    final config = _view == 'إعدادات الربط الضريبي' || _view == 'بيانات الممول والتوقيع الإلكتروني';
    final logs = <String>{'سجل عمليات التكامل','متابعة حالات الإرسال','إشعارات منظومة الضرائب','تقارير الفاتورة الإلكترونية','طلبات حزم المستندات','تنزيل حزم المستندات'}.contains(_view);
    return Directionality(textDirection: TextDirection.rtl, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_taxPurple, Color(0xFF6B35A0)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [
        const Icon(Icons.receipt_long_rounded, color: _taxOrange, size: 32), const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الفاتورة الإلكترونية المصرية', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('إدارة المستندات والتكامل مع منظومة مصلحة الضرائب', style: TextStyle(color: Colors.white70, fontSize: 12))])),
        Text(_production ? 'بيئة فعلية' : 'بيئة اختبار', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
      ])),
      const SizedBox(height: 10),
      SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, children: views.map((v) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4), child: ChoiceChip(label: Text(v), selected: _view == v, selectedColor: const Color(0xFFE9DDF5), labelStyle: TextStyle(color: _view == v ? _taxPurple : Colors.black87, fontWeight: FontWeight.w700), onSelected: (_) => setState(() => _view = v)))).toList())),
      const SizedBox(height: 10),
      Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        if (_view == views.first) ...[
          _panel('حالة الربط', _status, Wrap(spacing: 8, runSpacing: 8, children: [_btn('إعدادات الربط', Icons.settings, () => setState(() => _view = 'إعدادات الربط الضريبي'), primary: true), _btn('تسجيل اختبار اتصال', Icons.wifi_tethering, () => _request('test_connection')), _btn('تحديث السجل', Icons.refresh, _loadOperations)])),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _stat('طلبات التكامل', _operations.length.toString(), Icons.list_alt),
            _stat('قيد الإعداد', _operations.where((x) => x['status'] == 'pending_setup').length.toString(), Icons.hourglass_empty),
            _stat('البيئة', _production ? 'فعلية' : 'اختبار', Icons.shield_outlined)
          ]),
          const SizedBox(height: 10),
          _panel('دورة العمل', 'الخطوات الأساسية', const Text('١. إعداد بيانات الممول والنظام والشهادة الرقمية.\n٢. تجهيز أكواد السلع والخدمات وبيانات المستند.\n٣. توقيع المستند رقمياً وإرساله من خلال خدمة التكامل.\n٤. متابعة نتيجة التحقق والإصدار أو الرفض.\n٥. حفظ الإشعارات وإتاحة استرجاع المستند ونسخة PDF.', style: TextStyle(height: 1.8)))
        ] else if (config) ...[
          _panel('إعدادات الاتصال بالمصلحة', 'تُحفظ الإعدادات لكل شركة. استخدم مخزن أسرار آمن لخدمة التكامل في الإنتاج.', Form(key: _formKey, child: Column(children: [
            _field('رقم التسجيل الضريبي للممول', _taxNo, validator: (v) => v == null || v.trim().isEmpty ? 'أدخل رقم التسجيل الضريبي' : null),
            const SizedBox(height: 10), _field('كود الفرع', _branch, validator: (v) => v == null || v.trim().isEmpty ? 'أدخل كود الفرع' : null),
            const SizedBox(height: 10), _field('كود النشاط', _activity),
            const SizedBox(height: 10), _field('معرّف نظام التكامل Client ID', _clientId),
            const SizedBox(height: 10), _field('سر نظام التكامل Client Secret', _clientSecret, secret: true),
            SwitchListTile(value: _production, onChanged: (v) => setState(() => _production = v), title: const Text('استخدام البيئة الفعلية'), subtitle: const Text('اتركه مغلقاً أثناء الإعداد والاختبار'), activeColor: _taxPurple),
            Align(alignment: AlignmentDirectional.centerStart, child: _btn(_busy ? 'جارٍ الحفظ...' : 'حفظ الإعدادات', Icons.save, _saveSettings, primary: true))
          ]))),
          const SizedBox(height: 10),
          _panel('التوقيع والختم الإلكتروني', 'متطلب أساسي قبل الإرسال الفعلي', const Text('يلزم إعداد شهادة eSeal X.509 وخدمة توقيع آمنة وفق متطلبات الهيئة. لا تحفظ المفتاح الخاص داخل واجهة المستخدم ولا تعتبر إعدادات الشاشة بديلاً عن التوقيع الرقمي.', style: TextStyle(height: 1.7)))
        ] else if (_view == 'اختبار الاتصال الضريبي') ...[
          _panel('اختبار الاتصال', 'يسجل طلب الاختبار ولا يعني أن الاتصال بالهيئة نجح.', Wrap(spacing: 8, children: [_btn('تسجيل طلب اختبار', Icons.play_arrow, () => _request('test_connection'), primary: true), _btn('إعدادات الربط', Icons.settings, () => setState(() => _view = 'إعدادات الربط الضريبي'))]))
        ] else if (logs) ...[
          _panel(_view, 'الطلبات المسجلة في قاعدة بيانات البرنامج', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(alignment: AlignmentDirectional.centerStart, child: _btn('تحديث', Icons.refresh, _loadOperations)),
            if (_loading) const Center(child: CircularProgressIndicator())
            else if (_operations.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('لا توجد طلبات مسجلة بعد.', style: TextStyle(color: Colors.black54)))
            else ..._operations.map((op) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long, color: _taxPurple), title: Text((op['action_key'] ?? 'عملية').toString()), subtitle: Text('${op['document_type'] ?? ''} • ${op['created_at'] ?? ''}'), trailing: Text((op['status'] ?? '').toString(), style: const TextStyle(fontSize: 10, color: Colors.deepOrange))))
          ]))
        ] else ...[
          _panel(_view, 'أدوات إدارة المستندات وفق واجهات التكامل الموثقة', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _search, decoration: InputDecoration(labelText: 'رقم المستند أو UUID أو مرجع العملية', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [_btn('تسجيل طلب العملية', Icons.playlist_add_check, () => _request(_action()), primary: true), _btn('سجل التكامل', Icons.history, () => setState(() => _view = 'سجل عمليات التكامل')), if (_view.contains('فواتير') || _view.contains('إشعارات')) _btn('إعدادات الربط', Icons.settings, () => setState(() => _view = 'إعدادات الربط الضريبي'))]),
            const SizedBox(height: 12),
            const Text('تنبيه: هذه الشاشة تسجل الطلبات فقط. الإرسال والاستعلام والإلغاء والتوقيع الفعلي يحتاج خدمة خلفية آمنة وبيانات اعتماد الممول والشهادة الرقمية وربطاً ببيئة الهيئة.', style: TextStyle(color: Colors.black54, height: 1.7, fontSize: 12))
          ]))
        ]
      ])))
    ]));
  }

  Widget _stat(String label, String value, IconData icon) => SizedBox(width: 185, child: Card(elevation: 0, color: Colors.white, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon, color: _taxPurple, size: 24), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _taxPurple))]))]))));
}
