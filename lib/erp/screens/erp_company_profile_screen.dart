import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _companyPurple = Color(0xFF3E007D);
const _companyOrange = Color(0xFFFFA015);

class ErpCompanyProfileScreen extends StatefulWidget {
  const ErpCompanyProfileScreen({super.key, required this.companyId, this.onCompanyCreated});
  final String? companyId;
  final Future<void> Function(String companyId)? onCompanyCreated;

  @override
  State<ErpCompanyProfileScreen> createState() => _ErpCompanyProfileScreenState();
}

class _ErpCompanyProfileScreenState extends State<ErpCompanyProfileScreen> {
  SupabaseClient? _db;
  final _legalName = TextEditingController();
  final _tradeName = TextEditingController();
  final _taxNumber = TextEditingController();
  final _commercialRegister = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _currency = TextEditingController(text: 'EGP');
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;
  Map<String, dynamic>? _company;
  String? _activeCompanyId;

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _activeCompanyId = widget.companyId;
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpCompanyProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _activeCompanyId = widget.companyId;
      _load();
    }
  }

  @override
  void dispose() {
    _legalName.dispose();
    _tradeName.dispose();
    _taxNumber.dispose();
    _commercialRegister.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _currency.dispose();
    super.dispose();
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _load() async {
    final id = (_activeCompanyId ?? widget.companyId ?? '').trim();
    if (_db == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = _db == null ? 'سجّل الدخول إلى Supabase أولًا.' : 'لا توجد شركة نشطة مرتبطة بالمستخدم.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final row = await _db!
          .from('erp_companies')
          .select('id, legal_name, trade_name, tax_number, commercial_register, phone, email, address, base_currency, is_active')
          .eq('id', id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() {
          _loading = false;
          _error = 'لم يتم العثور على بيانات الشركة أو لا توجد صلاحية لعرضها.';
        });
        return;
      }
      setState(() {
        _company = Map<String, dynamic>.from(row);
        _legalName.text = (row['legal_name'] ?? '').toString();
        _tradeName.text = (row['trade_name'] ?? '').toString();
        _taxNumber.text = (row['tax_number'] ?? '').toString();
        _commercialRegister.text = (row['commercial_register'] ?? '').toString();
        _phone.text = (row['phone'] ?? '').toString();
        _email.text = (row['email'] ?? '').toString();
        _address.text = (row['address'] ?? '').toString();
        _currency.text = (row['base_currency'] ?? 'EGP').toString().trim();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات الشركة: $error';
      });
    }
  }

  Future<void> _save() async {
    var id = (_activeCompanyId ?? widget.companyId ?? '').trim();
    final legalName = _legalName.text.trim();
    final currency = _currency.text.trim().toUpperCase();
    if (_db == null) {
      setState(() => _error = 'Supabase غير مهيأ؛ تعذر الاتصال بقاعدة البيانات.');
      return;
    }
    if (legalName.isEmpty) {
      setState(() => _error = 'الاسم القانوني للشركة مطلوب.');
      return;
    }
    if (currency.length != 3 || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      setState(() => _error = 'العملة الأساسية يجب أن تكون رمزًا من 3 أحرف مثل EGP.');
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      setState(() => _error = 'البريد الإلكتروني غير صحيح.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      if (id.isEmpty) {
        final createdId = await _db!.rpc('erp_create_company', params: {
          'p_legal_name': legalName,
          'p_trade_name': _nullable(_tradeName.text),
          'p_tax_number': _nullable(_taxNumber.text),
          'p_commercial_register': _nullable(_commercialRegister.text),
          'p_phone': _nullable(_phone.text),
          'p_email': _nullable(_email.text),
          'p_address': _nullable(_address.text),
          'p_base_currency': currency,
        });
        id = createdId.toString();
        if (id.isEmpty || id == 'null') {
          throw StateError('لم تُرجع قاعدة البيانات معرّف الشركة الجديدة.');
        }
        _activeCompanyId = id;
        await widget.onCompanyCreated?.call(id);
      } else {
        await _db!.from('erp_companies').update({
          'legal_name': legalName,
          'trade_name': _nullable(_tradeName.text),
          'tax_number': _nullable(_taxNumber.text),
          'commercial_register': _nullable(_commercialRegister.text),
          'phone': _nullable(_phone.text),
          'email': _nullable(_email.text),
          'address': _nullable(_address.text),
          'base_currency': currency,
        }).eq('id', id);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = widget.companyId == null && _company == null
            ? 'تم إنشاء الشركة وحفظ بياناتها وربط حسابك بها كمالك.'
            : 'تم حفظ بيانات الشركة في قاعدة البيانات.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذر حفظ بيانات الشركة. تأكد من صلاحية مالك/مدير الشركة وتطبيق سياسات قاعدة البيانات: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _companyPurple.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.business_outlined, color: _companyPurple),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('بيانات الشركة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _companyPurple)),
            SizedBox(height: 4),
            Text((_activeCompanyId ?? widget.companyId) == null ? 'سجّل بيانات شركتك لإنشاء ملفها وربط حسابك بها كمالك.' : 'تعديل البيانات القانونية والتجارية للشركة المرتبطة بحسابك.', style: TextStyle(color: Colors.black54)),
          ])),
          IconButton(tooltip: 'إعادة تحميل', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_company != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      const Icon(Icons.verified_user_outlined, color: _companyPurple, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('حالة الشركة: ${_company!['is_active'] == true ? 'نشطة' : 'موقوفة'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Flexible(child: Text('ID: ${widget.companyId ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 11))),
                    ]),
                  ),
                _field(_legalName, 'الاسم القانوني *', Icons.business),
                _field(_tradeName, 'الاسم التجاري', Icons.storefront_outlined),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _sizedField(_taxNumber, 'الرقم الضريبي', Icons.receipt_long_outlined),
                  _sizedField(_commercialRegister, 'السجل التجاري', Icons.assignment_outlined),
                  _sizedField(_phone, 'رقم الهاتف', Icons.phone_outlined, keyboard: TextInputType.phone),
                  _sizedField(_email, 'البريد الإلكتروني', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  _sizedField(_currency, 'العملة الأساسية (3 أحرف)', Icons.currency_exchange),
                ]),
                _field(_address, 'العنوان', Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving || _loading ? null : _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جارٍ الحفظ...' : ((_activeCompanyId ?? widget.companyId) == null ? 'إنشاء الشركة وحفظ البيانات' : 'حفظ بيانات الشركة')),
                  style: FilledButton.styleFrom(backgroundColor: _companyPurple, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        ),
      );

  Widget _sizedField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) =>
      SizedBox(
        width: 280,
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        ),
      );

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
