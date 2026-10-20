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
  final _memberName = TextEditingController();
  final _jobTitle = TextEditingController();
  final _nameFilter = TextEditingController();
  String _newRole = 'operator';
  String? _newBranchId;
  String _jobFilter = '__all__';
  String _branchFilter = '__all__';
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _branches = [];
  bool _profilesAvailable = true;
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
  void didUpdateWidget(covariant ErpCompanyMembersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  @override
  void dispose() {
    _userId.dispose();
    _memberName.dispose();
    _jobTitle.dispose();
    _nameFilter.dispose();
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
      final values = await Future.wait([
        _db!.from('erp_company_members')
          .select('id, user_id, member_role, is_active, created_at')
          .eq('company_id', companyId)
          .order('created_at'),
        _db!.from('erp_branches')
          .select('id, branch_code, branch_name')
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('branch_code'),
      ]);
      List<Map<String, dynamic>> profiles = [];
      var profileTableAvailable = true;
      try {
        final profileRows = await _db!
          .from('erp_company_member_profiles')
          .select('user_id, display_name, job_title, branch_id')
          .eq('company_id', companyId);
        profiles = profileRows.map((row) => Map<String, dynamic>.from(row)).toList();
      } catch (_) {
        profileTableAvailable = false;
      }
      final profileByUser = <String, Map<String, dynamic>>{
        for (final profile in profiles) _s(profile['user_id']): profile,
      };
      final memberRows = (values[0] as List).map((row) {
        final member = Map<String, dynamic>.from(row);
        final profile = profileByUser[_s(member['user_id'])];
        member['display_name'] = profile?['display_name'] ?? '';
        member['job_title'] = profile?['job_title'] ?? '';
        member['branch_id'] = profile?['branch_id'];
        return member;
      }).toList();
      if (!mounted) return;
      setState(() {
        _members = memberRows;
        _branches = (values[1] as List).map((row) => Map<String, dynamic>.from(row)).toList();
        _profilesAvailable = profileTableAvailable;
        if (!_branches.any((branch) => _s(branch['id']) == _newBranchId)) _newBranchId = null;
        if (!_branches.any((branch) => _s(branch['id']) == _branchFilter)) _branchFilter = '__all__';
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

  String _branchName(dynamic id) {
    final key = _s(id);
    if (key.isEmpty) return 'بدون فرع';
    final rows = _branches.where((branch) => _s(branch['id']) == key);
    return rows.isEmpty ? 'فرع غير متاح' : _s(rows.first['branch_name']);
  }

  List<String> get _jobTitles => _members
      .map((member) => _s(member['job_title']).trim())
      .where((title) => title.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _nameFilter.text.trim().toLowerCase();
    return _members.where((member) {
      final name = _s(member['display_name']).trim().isEmpty
          ? _s(member['user_id'])
          : _s(member['display_name']);
      final job = _s(member['job_title']);
      final branch = _s(member['branch_id']);
      final matchesName = query.isEmpty || name.toLowerCase().contains(query) ||
          _s(member['user_id']).toLowerCase().contains(query);
      final matchesJob = _jobFilter == '__all__' || job == _jobFilter;
      final matchesBranch = _branchFilter == '__all__' || branch == _branchFilter;
      return matchesName && matchesJob && matchesBranch;
    }).toList();
  }

  Future<void> _saveMemberProfile({
    required String userId,
    required String name,
    required String jobTitle,
    String? branchId,
  }) async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty || name.trim().isEmpty) {
      setState(() => _error = 'اسم المستخدم والشركة حقول مطلوبة.');
      return;
    }
    try {
      await _db!.from('erp_company_member_profiles').upsert({
        'company_id': companyId,
        'user_id': userId,
        'display_name': name.trim(),
        'job_title': jobTitle.trim().isEmpty ? null : jobTitle.trim(),
        'branch_id': branchId,
        'updated_by': _db!.auth.currentUser?.id,
      }, onConflict: 'company_id,user_id');
      if (!mounted) return;
      setState(() => _message = 'تم حفظ الاسم والوظيفة والفرع.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حفظ بيانات المستخدم. تأكد من تطبيق supabase/erp_company_member_profiles.sql: $error');
    }
  }

  Future<void> _editMemberProfile(Map<String, dynamic> member) async {
    final userId = _s(member['user_id']);
    final name = TextEditingController(text: _s(member['display_name']));
    final job = TextEditingController(text: _s(member['job_title']));
    String? branchId = _s(member['branch_id']).isEmpty ? null : _s(member['branch_id']);
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: const Text('بيانات المستخدم'),
        content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المستخدم *')),
          const SizedBox(height: 8),
          TextField(controller: job, decoration: const InputDecoration(labelText: 'الوظيفة')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: branchId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الفرع'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('بدون فرع')),
              ..._branches.map((branch) => DropdownMenuItem<String?>(
                value: _s(branch['id']),
                child: Text(_s(branch['branch_name']), overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (value) => refresh(() => branchId = value),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'name': name.text,
            'job': job.text,
            'branch': branchId,
          }), child: const Text('حفظ')),
        ],
      )),
    );
    name.dispose();
    job.dispose();
    if (result == null || !mounted) return;
    await _saveMemberProfile(
      userId: userId,
      name: _s(result['name']),
      jobTitle: _s(result['job']),
      branchId: result['branch'] as String?,
    );
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
      final displayName = _memberName.text.trim();
      if (_profilesAvailable && displayName.isEmpty) {
        setState(() => _error = 'اكتب اسم المستخدم ليظهر في دليل المستخدمين.');
        return;
      }
      await _db!.from('erp_company_members').insert({
        'company_id': companyId,
        'user_id': userId,
        'member_role': _newRole,
        'is_active': true,
      });
      String? profileWarning;
      if (_profilesAvailable) {
        try {
          await _db!.from('erp_company_member_profiles').upsert({
            'company_id': companyId,
            'user_id': userId,
            'display_name': displayName,
            'job_title': _jobTitle.text.trim().isEmpty ? null : _jobTitle.text.trim(),
            'branch_id': _newBranchId,
            'updated_by': _db!.auth.currentUser?.id,
          }, onConflict: 'company_id,user_id');
        } catch (error) {
          profileWarning = 'أُضيفت العضوية لكن تعذر حفظ الاسم والوظيفة والفرع: $error';
        }
      } else {
        profileWarning = 'أُضيفت العضوية، لكن يلزم تطبيق ترحيل بيانات المستخدمين لحفظ الاسم والوظيفة والفرع.';
      }
      if (!mounted) return;
      setState(() {
        _userId.clear();
        _memberName.clear();
        _jobTitle.clear();
        _newBranchId = null;
        _saving = false;
        _message = profileWarning ?? 'تمت إضافة المستخدم وبياناته إلى الشركة.';
        _error = null;
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
                      onChanged: isCurrent || isOwner ? null : (value) => _updateMember(member, active: value),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _roles.containsKey(role) ? role : 'viewer',
                    decoration: const InputDecoration(labelText: 'الدور الوظيفي', border: OutlineInputBorder()),
                    items: _roles.entries.map((entry) => DropdownMenuItem(value: entry.key, enabled: entry.key != 'owner', child: Text(entry.value))).toList(),
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
