import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _membersPurple = Color(0xFF3E007D);

class ErpCompanyMembersScreen extends StatefulWidget {
  const ErpCompanyMembersScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpCompanyMembersScreen> createState() => _ErpCompanyMembersScreenState();
}

class _ErpCompanyMembersScreenState extends State<ErpCompanyMembersScreen> {
  SupabaseClient? _db;
  final _userId = TextEditingController();
  String _newRole = 'operator';
  List<Map<String, dynamic>> _members = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  static const Map<String, String> _roles = {
    'owner': 'مالك الشركة',
    'admin': 'مدير النظام',
    'manager': 'مدير',
    'accountant': 'محاسب',
    'operator': 'مشغل',
    'viewer': 'عرض فقط',
  };

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  String _s(dynamic value) => (value ?? '').toString();

  Future<void> _load() async {
    final companyId = (widget.companyId ?? '').trim();
    if (_db == null || companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = _db == null ? 'سجّل الدخول إلى Supabase أولًا.' : 'لا توجد شركة نشطة مرتبطة بالمستخدم.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _db!
          .from('erp_company_members')
          .select('id, user_id, member_role, is_active, created_at')
          .eq('company_id', companyId)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _members = (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل عضويات الشركة. يجب أن يكون حسابك مالكًا أو مديرًا: $error';
      });
    }
  }

  Future<void> _addMember() async {
    final companyId = (widget.companyId ?? '').trim();
    final userId = _userId.text.trim();
    if (companyId.isEmpty || userId.isEmpty) {
      setState(() => _error = 'أدخل معرّف مستخدم مسجل في Supabase.');
      return;
    }
    if (userId == _db?.auth.currentUser?.id) {
      setState(() => _error = 'حسابك عضو بالفعل؛ لا تضف نفسك مرة أخرى.');
      return;
    }
    if (_members.any((row) => _s(row['user_id']) == userId)) {
      setState(() => _error = 'هذا المستخدم عضو بالفعل في الشركة.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _db!.from('erp_company_members').insert({
        'company_id': companyId,
        'user_id': userId,
        'member_role': _newRole,
        'is_active': true,
      });
      if (!mounted) return;
      setState(() {
        _userId.clear();
        _saving = false;
        _message = 'تمت إضافة المستخدم إلى الشركة.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذرت إضافة العضو. تأكد أن UUID يعود لمستخدم مسجل وأن حسابك مالك/مدير: $error';
      });
    }
  }

  Future<void> _updateMember(Map<String, dynamic> member, {String? role, bool? active}) async {
    final id = _s(member['id']);
    if (id.isEmpty) return;
    final userId = _s(member['user_id']);
    if (userId == _db?.auth.currentUser?.id && active == false) {
      setState(() => _error = 'لا يمكن إيقاف عضوية حسابك الحالي من هذه الشاشة.');
      return;
    }
    if (_s(member['member_role']) == 'owner' && role != null) {
      setState(() => _error = 'لا يمكن تغيير دور مالك الشركة من هذه الشاشة.');
      return;
    }
    final previousRole = _s(member['member_role']);
    final previousActive = member['is_active'] == true;
    setState(() {
      if (role != null) member['member_role'] = role;
      if (active != null) member['is_active'] = active;
      _error = null;
      _message = null;
    });
    try {
      final payload = <String, Object?>{};
      if (role != null) payload['member_role'] = role;
      if (active != null) payload['is_active'] = active;
      await _db!.from('erp_company_members').update(payload).eq('id', id);
      if (mounted) setState(() => _message = 'تم حفظ تعديل عضوية المستخدم.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        member['member_role'] = previousRole;
        member['is_active'] = previousActive;
        _error = 'تعذر حفظ العضوية: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _db?.auth.currentUser?.id;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: _membersPurple.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.manage_accounts_outlined, color: _membersPurple),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المستخدمون وعضويات الشركة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _membersPurple)),
            SizedBox(height: 4),
            Text('إدارة المستخدمين المسجلين وأدوارهم وحالة عضويتهم الفعلية.', style: TextStyle(color: Colors.black54)),
          ])),
          IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 14),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('إضافة مستخدم مسجل', style: TextStyle(fontWeight: FontWeight.w900, color: _membersPurple)),
              const SizedBox(height: 5),
              const Text('أدخل UUID لمستخدم موجود بالفعل في Supabase Auth. إنشاء الحساب أو إرسال الدعوة يتم من نظام المصادقة.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 10),
              TextField(controller: _userId, decoration: const InputDecoration(labelText: 'معرّف المستخدم UUID', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _newRole,
                decoration: const InputDecoration(labelText: 'الدور داخل الشركة', border: OutlineInputBorder()),
                items: _roles.entries.where((entry) => entry.key != 'owner').map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: _saving ? null : (value) { if (value != null) setState(() => _newRole = value); },
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _addMember,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة العضوية'),
                style: FilledButton.styleFrom(backgroundColor: _membersPurple),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('أعضاء الشركة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          Text('${_members.length} مستخدم', style: const TextStyle(color: _membersPurple, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
        else if (_members.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد عضويات ظاهرة لهذا المستخدم أو ليست لديه صلاحية الإدارة.')))
        else
          ..._members.map((member) {
            final userId = _s(member['user_id']);
            final role = _s(member['member_role']);
            final isCurrent = userId == currentUserId;
            final isOwner = role == 'owner';
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    CircleAvatar(backgroundColor: _membersPurple.withValues(alpha: .1), child: const Icon(Icons.person_outline, color: _membersPurple)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isCurrent ? 'المستخدم الحالي' : 'مستخدم ${userId.length > 12 ? userId.substring(0, 12) : userId}…', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(userId, style: const TextStyle(color: Colors.black45, fontSize: 11)),
                    ])),
                    Switch(
                      value: member['is_active'] == true,
                      onChanged: isCurrent ? null : (value) => _updateMember(member, active: value),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _roles.containsKey(role) ? role : 'viewer',
                    decoration: const InputDecoration(labelText: 'الدور الوظيفي', border: OutlineInputBorder()),
                    items: _roles.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                    onChanged: isCurrent || isOwner ? null : (value) { if (value != null && value != role) _updateMember(member, role: value); },
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .3))),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
