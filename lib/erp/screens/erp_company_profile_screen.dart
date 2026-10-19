import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _companyPurple = Color(0xFF3E007D);

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
  List<Map<String, String>> _currencyOptions = [
    {'code': 'EGP', 'name': 'جنيه مصري'}, {'code': 'USD', 'name': 'دولار أمريكي'},
    {'code': 'SAR', 'name': 'ريال سعودي'}, {'code': 'AED', 'name': 'درهم إماراتي'},
    {'code': 'KWD', 'name': 'دينار كويتي'}, {'code': 'EUR', 'name': 'يورو'},
    {'code': 'GBP', 'name': 'جنيه إسترليني'},
  ];

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
    if (_db == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'سجّل الدخول إلى Supabase أولًا.';
        _message = null;
      });
      return;
    }
    if (id.isEmpty) {
      // A first-time user should see the creation form, not a red authorization error.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _message = null;
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
      _currency.text = (row['base_currency'] ?? 'EGP').toString().trim();
      try {
        final currencies = await _db!.from('erp_currencies').select('currency_code,currency_name_ar')
            .eq('company_id', id).eq('is_active', true).order('currency_code');
        for (final item in currencies) {
          final code = (item['currency_code'] ?? '').toString().trim();
          if (code.isNotEmpty && !_currencyOptions.any((option) => option['code'] == code)) {
            _currencyOptions.add({'code': code, 'name': (item['currency_name_ar'] ?? code).toString()});
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _company = Map<String, dynamic>.from(row);
        _legalName.text = (row['legal_name'] ?? '').toString();
        _tradeName.text = (row['trade_name'] ?? '').toString();
        _taxNumber.text = (row['tax_number'] ?? '').toString();
        _commercialRegister.text = (row['commercial_register'] ?? '').toString();
        _phone.text = (row['phone'] ?? '').toString();
        _email.text = (row['email'] ?? '').toString();
        _address.text = (row['address'] ?? '').toString();
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
    final db = _db;
    if (db == null) {
      setState(() => _error = 'Supabase غير مهيأ؛ تعذر الاتصال بقاعدة البيانات.');
      return;
    }
    if (db.auth.currentUser == null) {
      setState(() => _error = 'جلسة الدخول غير نشطة. سجّل الدخول إلى حسابك ثم أعد حفظ بيانات الشركة.');
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
    String? dashboardRefreshError;
    try {
      // Resolve the company from this signed-in user's own active memberships.
      // A stale company ID must never make first-time creation call the update RPC.
      final userId = db.auth.currentUser!.id;
      final membershipResult = await db
          .from('erp_company_members')
          .select('company_id, member_role')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at');
      final memberships = (membershipResult as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      Map<String, dynamic>? membershipFor(String companyId) {
        for (final membership in memberships) {
          if ((membership['company_id'] ?? '').toString() == companyId) {
            return membership;
          }
        }
        return null;
      }

      if (id.isNotEmpty && membershipFor(id) == null) {
        if (memberships.isEmpty) {
          id = '';
        } else {
          throw StateError(
            'الشركة المحددة ليست ضمن عضويات حسابك النشطة. اختر الشركة المرتبطة بحسابك.',
          );
        }
      }

      if (id.isEmpty && memberships.isNotEmpty) {
        Map<String, dynamic>? ownerMembership;
        for (final membership in memberships) {
          final role = (membership['member_role'] ?? '').toString();
          if (role == 'owner' || role == 'admin') {
            ownerMembership = membership;
            break;
          }
        }
        if (ownerMembership == null) {
          throw StateError(
            'حسابك عضو في شركة، لكنه لا يملك صلاحية مالك أو مدير لتعديل بياناتها.',
          );
        }
        id = (ownerMembership['company_id'] ?? '').toString();
      }

      if (id.isNotEmpty) {
        final role = (membershipFor(id)?['member_role'] ?? '').toString();
        if (role != 'owner' && role != 'admin') {
          throw StateError(
            'تعديل بيانات الشركة متاح لمالك الشركة أو مديرها فقط.',
          );
        }
      }

      if (id.isEmpty) {
        final createdId = await db.rpc('erp_create_company', params: {
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
        try {
          await widget.onCompanyCreated?.call(id);
        } catch (refreshError) {
          // The company creation transaction succeeded; preserve that success
          // while still reporting a separate dashboard refresh issue.
          dashboardRefreshError = refreshError.toString();
        }
      } else {
        final updatedId = await db.rpc('erp_update_company_profile', params: {
          'p_company_id': id,
          'p_legal_name': legalName,
          'p_trade_name': _nullable(_tradeName.text),
          'p_tax_number': _nullable(_taxNumber.text),
          'p_commercial_register': _nullable(_commercialRegister.text),
          'p_phone': _nullable(_phone.text),
          'p_email': _nullable(_email.text),
          'p_address': _nullable(_address.text),
          'p_base_currency': currency,
        });
        if (updatedId == null || updatedId.toString() != id) {
          throw StateError('لم تؤكد قاعدة البيانات تحديث سجل الشركة.');
        }
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        final savedMessage = widget.companyId == null && _company == null
            ? 'تم إنشاء الشركة وحفظ بياناتها وربط حسابك بها كمالك.'
            : 'تم حفظ بيانات الشركة في قاعدة البيانات.';
        _message = dashboardRefreshError == null
            ? savedMessage
            : '$savedMessage تعذر تحديث بعض مؤشرات اللوحة: $dashboardRefreshError';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذر حفظ بيانات الشركة: ${_companySaveError(error)}';
      });
    }
  }

  String _companySaveError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();
    final mentionsCompanyRpc = lower.contains('erp_create_company') ||
        lower.contains('erp_update_company_profile');
    final functionMissing = lower.contains('function') ||
        lower.contains('schema cache') ||
        lower.contains('could not find') ||
        lower.contains('pgrst202');
    if (mentionsCompanyRpc && functionMissing) {
      return 'إجراء حفظ الشركة غير ظاهر في واجهة قاعدة البيانات. تحقق من تحديث مخطط Supabase ثم أعد المحاولة. التفاصيل: $message';
    }
    if (lower.contains('مالك') || lower.contains('مدير') ||
        lower.contains('owner') || lower.contains('admin') ||
        lower.contains('42501') || lower.contains('permission denied') ||
        lower.contains('row-level security') || lower.contains('rls')) {
      return 'لا توجد عضوية نشطة بصلاحية مالك أو مدير لهذه الشركة، أو أن سياسة الوصول رفضت العملية. تأكد من اختيار الشركة الصحيحة ومن عضوية حسابك. التفاصيل: $message';
    }
    return 'تعذر حفظ بيانات الشركة من قاعدة البيانات. التفاصيل: $message';
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('بيانات الشركة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _companyPurple)),
            const SizedBox(height: 4),
            Text((_activeCompanyId ?? widget.companyId) == null ? 'سجّل بيانات شركتك لإنشاء ملفها وربط حسابك بها كمالك.' : 'تعديل البيانات القانونية والتجارية للشركة المرتبطة بحسابك.', style: const TextStyle(color: Colors.black54)),
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
                      Flexible(child: Text('ID: ${_activeCompanyId ?? widget.companyId ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 11))),
                    ]),
                  ),
                _field(_legalName, 'الاسم القانوني *', Icons.business),
                _field(_tradeName, 'الاسم التجاري', Icons.storefront_outlined),
                _field(_taxNumber, 'الرقم الضريبي', Icons.receipt_long_outlined),
                _field(_commercialRegister, 'السجل التجاري', Icons.assignment_outlined),
                _field(_phone, 'رقم الهاتف', Icons.phone_outlined, keyboard: TextInputType.phone),
                _field(_email, 'البريد الإلكتروني', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                _currencyField(),
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

  Widget _currencyField() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LayoutBuilder(builder: (context, constraints) {
          final labelWidth = (constraints.maxWidth * .30).clamp(125.0, 190.0);
          final current = _currencyOptions.any((item) => item['code'] == _currency.text) ? _currency.text : 'EGP';
          return Row(children: [
            SizedBox(width: labelWidth, child: const Padding(
              padding: EdgeInsetsDirectional.only(end: 12),
              child: Text('العملة الأساسية', style: TextStyle(color: _companyPurple, fontWeight: FontWeight.w700, fontSize: 13)),
            )),
            Expanded(child: DropdownButtonFormField<String>(
              value: current, isExpanded: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.currency_exchange, size: 20), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: _currencyOptions.map((item) => DropdownMenuItem<String>(
                value: item['code'], child: Text('${item['name']} (${item['code']})', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) { if (value != null) setState(() => _currency.text = value); },
            )),
          ]);
        }),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {int maxLines = 1, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelWidth = (constraints.maxWidth * .30).clamp(125.0, 190.0);
            return Row(
              crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: 12, top: maxLines > 1 ? 15 : 0),
                    child: Text(
                      label,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: _companyPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboard,
                    maxLines: maxLines,
                    minLines: maxLines > 1 ? maxLines : 1,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(icon, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            );
          },
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
