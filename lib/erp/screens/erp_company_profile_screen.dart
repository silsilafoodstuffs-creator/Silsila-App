import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/erp_app_asset_storage.dart';
import '../services/erp_company_settings_repository.dart';

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
  final _companyCode = TextEditingController();
  final _taxOffice = TextEditingController();
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
  String? _logoStoragePath;
  String? _logoPreviewUrl;
  bool _uploadingLogo = false;
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
    _companyCode.dispose();
    _taxOffice.dispose();
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
      Map<String, dynamic>? profileSettings;
      try {
        profileSettings = await ErpCompanySettingsRepository(client: _db).getSetting(
          companyId: id, key: 'company_profile_extra');
      } catch (_) {}
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
        _companyCode.text = (profileSettings?['company_code'] ?? 'SIL-${id.replaceAll('-', '').substring(0, id.replaceAll('-', '').length >= 8 ? 8 : id.replaceAll('-', '').length).toUpperCase()}').toString();
        _taxOffice.text = (profileSettings?['tax_office'] ?? '').toString();
        _logoStoragePath = (profileSettings?['logo_path'] ?? '').toString().trim().isEmpty ? null : profileSettings!['logo_path'].toString();
        _logoPreviewUrl = null;
        _phone.text = (row['phone'] ?? '').toString();
        _email.text = (row['email'] ?? '').toString();
        _address.text = (row['address'] ?? '').toString();
        _loading = false;
      });
      if (_logoStoragePath != null) {
        try {
          final url = await ErpAppAssetStorage(client: _db).createSignedImageUrl(storagePath: _logoStoragePath!);
          if (mounted) setState(() => _logoPreviewUrl = url);
        } catch (_) {}
      }
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
      // Store auxiliary company details separately so existing company RPCs and
      // installations remain compatible while the schema is upgraded safely.
      final cleanCode = _companyCode.text.trim();
      if (cleanCode.isNotEmpty) {
        await ErpCompanySettingsRepository(client: db).saveSetting(
          companyId: id,
          key: 'company_profile_extra',
          value: <String, Object?>{
            'company_code': cleanCode,
            'tax_office': _taxOffice.text.trim().isEmpty ? null : _taxOffice.text.trim(),
            'logo_path': _logoStoragePath,
          },
        );
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

  Future<void> _chooseCompanyImage(ImageSource source) async {
    final companyId = (_activeCompanyId ?? widget.companyId ?? '').trim();
    if (companyId.isEmpty) {
      setState(() => _error = 'احفظ بيانات الشركة أولًا قبل رفع صورتها.');
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (picked == null) return;
      setState(() { _uploadingLogo = true; _error = null; _message = null; });
      final bytes = await picked.readAsBytes();
      final type = _imageContentType(picked.name, bytes);
      final path = await ErpAppAssetStorage(client: _db).uploadImage(
        companyId: companyId,
        appId: 'erp-company-profile',
        fileName: picked.name,
        bytes: bytes,
        contentType: type,
        assetType: 'other',
      );
      final preview = await ErpAppAssetStorage(client: _db).createSignedImageUrl(storagePath: path);
      if (!mounted) return;
      setState(() {
        _logoStoragePath = path;
        _logoPreviewUrl = preview;
        _uploadingLogo = false;
        _message = 'تم رفع صورة المنشأة. اضغط حفظ لتثبيت بياناتها.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingLogo = false;
        _error = 'تعذر استيراد صورة المنشأة. تحقق من صلاحيات مخزن الصور: $error';
      });
    }
  }

  String _imageContentType(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
    throw ArgumentError('امتداد الصورة غير مدعوم؛ استخدم JPG أو PNG أو WEBP أو GIF.');
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
                Row(children: [
                  Expanded(child: _field(_companyCode, 'كود الشركة', Icons.qr_code_2)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_legalName, 'الاسم القانوني *', Icons.business)),
                ]),
                Row(children: [
                  Expanded(child: _field(_tradeName, 'الاسم التجاري', Icons.storefront_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_taxNumber, 'الرقم الضريبي', Icons.receipt_long_outlined)),
                ]),
                Row(children: [
                  Expanded(child: _field(_commercialRegister, 'السجل التجاري', Icons.assignment_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_taxOffice, 'المأمورية الضريبية', Icons.account_balance_outlined)),
                ]),
                Row(children: [
                  Expanded(child: _field(_phone, 'رقم الهاتف', Icons.phone_outlined, keyboard: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_email, 'البريد الإلكتروني', Icons.email_outlined, keyboard: TextInputType.emailAddress)),
                ]),
                _currencyField(),
                _field(_address, 'العنوان', Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8F4FC), borderRadius: BorderRadius.circular(12), border: Border.all(color: _companyPurple.withValues(alpha: .15))),
                  child: Row(children: [
                    Container(width: 84, height: 84, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)), clipBehavior: Clip.antiAlias,
                      child: _logoPreviewUrl == null ? const Icon(Icons.business, size: 38, color: _companyPurple) : Image.network(_logoPreviewUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 38, color: _companyPurple))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('صورة المنشأة / الشعار', style: TextStyle(color: _companyPurple, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(onPressed: _uploadingLogo ? null : () => _chooseCompanyImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('استيراد صورة')),
                        OutlinedButton.icon(onPressed: _uploadingLogo ? null : () => _chooseCompanyImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined, size: 18), label: const Text('الكاميرا')),
                      ]),
                      if (_uploadingLogo) const LinearProgressIndicator(minHeight: 3),
                    ])),
                  ]),
                ),
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
