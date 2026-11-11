import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/erp_api_integration.dart';

const _apiPurple = Color(0xFF3E007D);
const _apiOrange = Color(0xFFFFA015);

/// One workspace for the deployed read-only API gateway and server-managed API keys.
class ErpApiManagementScreen extends StatefulWidget {
  const ErpApiManagementScreen({super.key});

  @override
  State<ErpApiManagementScreen> createState() => _ErpApiManagementScreenState();
}

class _ErpApiManagementScreenState extends State<ErpApiManagementScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _url = TextEditingController();
  final Set<String> _scopes = <String>{'items:read'};
  String? _validationMessage;
  bool _active = true;
  SupabaseClient? _db;
  String? _companyId;
  String? _companyName;
  String? _keysError;
  bool _keysLoading = true;
  bool _issuing = false;
  final _keyLabel = TextEditingController(text: 'تكامل خارجي');
  List<Map<String, dynamic>> _keys = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _loadApiKeys();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _url.dispose();
    _keyLabel.dispose();
    super.dispose();
  }


  Future<void> _loadApiKeys() async {
    final db = _db;
    if (db == null) {
      if (mounted) setState(() { _keysLoading = false; _keysError = 'خدمة قاعدة البيانات غير مهيأة.'; });
      return;
    }
    if (mounted) setState(() { _keysLoading = true; _keysError = null; });
    try {
      final userId = db.auth.currentUser?.id;
      if (userId == null) throw Exception('سجّل الدخول أولًا لإدارة مفاتيح API.');
      final memberships = await db.from('erp_company_members')
          .select('company_id,member_role')
          .eq('user_id', userId).eq('is_active', true)
          .inFilter('member_role', ['owner', 'admin']).order('created_at');
      if ((memberships as List).isEmpty) throw Exception('إدارة المفاتيح متاحة لمالك الشركة أو المدير فقط.');
      final companyId = (memberships.first as Map)['company_id'].toString();
      final company = await db.from('erp_companies').select('legal_name,trade_name')
          .eq('id', companyId).maybeSingle();
      final raw = await db.rpc('erp_api_key_list', params: {'p_company_id': companyId});
      final keys = (raw as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
      if (!mounted) return;
      setState(() {
        _companyId = companyId;
        _companyName = (company?['trade_name'] ?? company?['legal_name'] ?? 'الشركة').toString();
        _keys = keys;
        _keysLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _keysLoading = false; _keysError = e.toString(); });
    }
  }

  Future<void> _issueKey() async {
    if (_db == null || _companyId == null) return;
    if (_keyLabel.text.trim().length < 2 || _scopes.isEmpty) {
      setState(() => _keysError = 'اكتب اسمًا للمفتاح واختر صلاحية قراءة واحدة على الأقل.');
      return;
    }
    setState(() { _issuing = true; _keysError = null; });
    try {
      final raw = await _db!.rpc('erp_api_key_issue', params: {
        'p_company_id': _companyId,
        'p_label': _keyLabel.text.trim(),
        'p_scopes': _scopes.toList(),
        'p_expires_at': null,
      });
      final result = Map<String, dynamic>.from(raw as Map);
      final secret = (result['api_key'] ?? '').toString();
      if (secret.isEmpty) throw Exception('لم يتم استلام المفتاح الجديد.');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تم إصدار المفتاح — احفظه الآن'),
          content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('هذه هي المرة الوحيدة التي سيظهر فيها المفتاح كاملًا. انسخه إلى مدير أسرار آمن.'),
            const SizedBox(height: 12),
            SelectableText(secret, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('حفظت المفتاح'))],
        ),
      );
      await _loadApiKeys();
    } catch (e) {
      if (mounted) setState(() => _keysError = e.toString());
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _revokeKey(Map<String, dynamic> key) async {
    if (_db == null || _companyId == null) return;
    final id = (key['id'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء مفتاح API'),
        content: Text('هل تريد إلغاء المفتاح "${key['label'] ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إلغاء المفتاح')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db!.rpc('erp_api_key_revoke', params: {'p_company_id': _companyId, 'p_key_id': id});
      await _loadApiKeys();
    } catch (e) {
      if (mounted) setState(() => _keysError = e.toString());
    }
  }

  void _validateConnection() {
    final model = ErpApiIntegration(
      clientName: _name.text,
      clientCode: _code.text,
      baseUrl: _url.text,
      scopes: _scopes,
      active: _active,
    );
    final errors = model.validate();
    setState(() => _validationMessage = errors.isEmpty
        ? 'البيانات صحيحة مبدئيًا. لم يتم إنشاء اتصال أو حفظ إعدادات بعد.'
        : errors.join('\n'));
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _apiPurple)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ]),
      );

  Widget _externalConnection() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle('واجهة API والربط الخارجي', 'كتالوج المسارات وتعريف النظام الخارجي والتحقق من بيانات الربط.'),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مسارات API المنشورة فعليًا', style: TextStyle(fontWeight: FontWeight.w900, color: _apiPurple)),
            const SizedBox(height: 6),
            ...erpApiCatalog.map((endpoint) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              SizedBox(width: 52, child: Text(endpoint.method, style: const TextStyle(fontWeight: FontWeight.w800, color: _apiPurple))),
              Expanded(child: Text('${endpoint.path}  •  ${endpoint.name}')),
              Text(endpoint.requiredScope, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]))),
            const SizedBox(height: 4),
            const Text('الخدمة منشورة وتقبل GET فقط مع التحقق من المفتاح والصلاحيات.', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ]))),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم النظام المتصل', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'رمز الربط', helperText: '3 إلى 40 حرفًا أو رقمًا أو - أو _', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'عنوان الخدمة الأساسي', hintText: 'https://example.com', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Text('الصلاحيات المسموحة', style: TextStyle(fontWeight: FontWeight.w800)),
          ...const [
            ('company:read', 'قراءة بيانات الشركة'),
            ('items:read', 'قراءة الأصناف'),
            ('customers:read', 'قراءة العملاء'),
            ('suppliers:read', 'قراءة الموردين'),
            ('inventory:read', 'قراءة المخزون'),
            ('orders:read', 'قراءة الطلبات'),
          ].map((scope) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _scopes.contains(scope.$1),
                title: Text(scope.$2),
                subtitle: Text(scope.$1),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _scopes.add(scope.$1);
                  } else {
                    _scopes.remove(scope.$1);
                  }
                }),
              )),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الربط نشط'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _apiPurple),
              onPressed: _validateConnection,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('التحقق من البيانات'),
            ),
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(10)),
              child: Text(_validationMessage!),
            ),
          ],
        ],
      );


  Widget _apiKeys() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle('إدارة مفاتيح API', 'إصدار المفاتيح وعرض بياناتها الوصفية وإلغاؤها من قاعدة البيانات.'),
          if (_companyName != null) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.business_outlined, color: _apiPurple),
            title: Text(_companyName!, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('الشركة النشطة ذات صلاحية المالك/المدير'),
          ),
          TextField(controller: _keyLabel, decoration: const InputDecoration(labelText: 'اسم المفتاح الجديد', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ...const [
            ('company:read', 'بيانات الشركة'),
            ('items:read', 'الأصناف'),
            ('customers:read', 'العملاء'),
            ('suppliers:read', 'الموردون'),
            ('inventory:read', 'أرصدة المخزون'),
            ('orders:read', 'الطلبات'),
          ].map((scope) => CheckboxListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                value: _scopes.contains(scope.$1), title: Text(scope.$2), subtitle: Text(scope.$1),
                onChanged: (value) => setState(() { if (value == true) { _scopes.add(scope.$1); } else { _scopes.remove(scope.$1); } }),
              )),
          Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(
            onPressed: _issuing || _keysLoading || _companyId == null ? null : _issueKey,
            style: FilledButton.styleFrom(backgroundColor: _apiPurple),
            icon: _issuing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add),
            label: const Text('إصدار مفتاح جديد'),
          )),
          if (_keysError != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_keysError!, style: const TextStyle(color: Colors.red))),
          const Divider(height: 28),
          Row(children: [
            const Expanded(child: Text('المفاتيح الصادرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _apiPurple))),
            IconButton(onPressed: _keysLoading ? null : _loadApiKeys, icon: const Icon(Icons.refresh)),
          ]),
          if (_keysLoading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_keys.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('لا توجد مفاتيح صادرة حتى الآن.'))
          else ..._keys.map((key) {
            final revoked = key['revoked_at'] != null;
            final expired = key['expires_at'] != null && DateTime.tryParse(key['expires_at'].toString())?.isBefore(DateTime.now()) == true;
            return Card(child: ListTile(
              leading: Icon(Icons.key_rounded, color: revoked || expired ? Colors.grey : _apiOrange),
              title: Text((key['label'] ?? 'مفتاح API').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text("${key['key_prefix'] ?? ''} • ${(key['scopes'] as List? ?? const []).join(', ')}\nآخر استخدام: ${key['last_used_at'] ?? 'لم يُستخدم'}\nالحالة: ${revoked ? 'ملغي' : expired ? 'منتهي' : 'نشط'}"),
              isThreeLine: true,
              trailing: revoked ? null : IconButton(tooltip: 'إلغاء المفتاح', onPressed: () => _revokeKey(key), icon: const Icon(Icons.block, color: Colors.red)),
            ));
          }),
          const SizedBox(height: 10),
          const Text('الأمان: لا يتم تخزين المفتاح الكامل؛ تظهر قيمته مرة واحدة عند الإصدار، وتُخزن بصمته فقط. الحد الحالي 60 طلبًا في الدقيقة لكل مفتاح.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      );


  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: _apiPurple,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إدارة مفاتيح API', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('واجهة API والربط الخارجي ومفاتيح الوصول في شاشة واحدة', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              TabBar(
                isScrollable: true,
                indicatorColor: _apiOrange,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'واجهة API والربط الخارجي'),
                  Tab(text: 'إدارة مفاتيح API'),
                ],
              ),
            ]),
          ),
          Expanded(child: TabBarView(children: [
            _externalConnection(),
            _apiKeys(),
          ])),
        ]),
      );
}

