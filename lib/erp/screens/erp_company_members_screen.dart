import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
        if (!_jobTitles.contains(_jobFilter)) _jobFilter = '__all__';
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
    final displayName = _memberName.text.trim();
    if (_profilesAvailable && displayName.isEmpty) {
      setState(() => _error = 'اكتب اسم المستخدم ليظهر في دليل المستخدمين.');
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

  Future<Uint8List> _membersPdfBytes() async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final doc = pw.Document();
    final rows = _filteredMembers;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
        pw.Text('دليل مستخدمي الشركة — سلسلة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
          children: [
            _pdfRow(['م', 'اسم المستخدم', 'الوظيفة', 'الفرع', 'الدور', 'الحالة'], true),
            for (var i = 0; i < rows.length; i++)
              _pdfRow([
                '${i + 1}',
                _s(rows[i]['display_name']).isEmpty ? _s(rows[i]['user_id']) : _s(rows[i]['display_name']),
                _s(rows[i]['job_title']),
                _branchName(rows[i]['branch_id']),
                _roles[_s(rows[i]['member_role'])] ?? _s(rows[i]['member_role']),
                rows[i]['is_active'] == true ? 'نشط' : 'موقوف',
              ], false),
          ],
        ),
      ],
    ));
    return doc.save();
  }

  pw.TableRow _pdfRow(List<String> values, bool header) => pw.TableRow(
    decoration: header ? const pw.BoxDecoration(color: PdfColors.orange100) : null,
    children: values.map((value) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(value, style: pw.TextStyle(fontSize: header ? 10 : 9, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
    )).toList(),
  );

  Future<void> _previewPrintMembers() async {
    try {
      final bytes = await _membersPdfBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'silsila-company-members.pdf');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذرت معاينة وطباعة دليل المستخدمين: $error');
    }
  }

  Future<void> _exportMembers() async {
    try {
      final bytes = await _membersPdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: 'silsila-company-members.pdf');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تصدير دليل المستخدمين: $error');
    }
  }

Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  @override
  Widget build(BuildContext context) {
    final currentUserId = _db?.auth.currentUser?.id;
    final visibleMembers = _filteredMembers;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(color: const Color(0xFF3E007D), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.manage_accounts_outlined, color: Color(0xFFFFA015), size: 27),
              SizedBox(width: 10),
              Expanded(child: Text('المستخدمون وعضويات الشركة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
            ]),
            const Text('دليل الأعضاء وإدارة الأدوار والوظائف والفروع.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('إضافة', Icons.person_add_alt_1_outlined, const Color(0xFF168447), _loading ? null : _addMember),
              _quickTask('معاينة / طباعة', Icons.print_outlined, const Color(0xFF4056A1), _loading || _members.isEmpty ? null : _previewPrintMembers),
              _quickTask('تصدير PDF', Icons.picture_as_pdf_outlined, const Color(0xFFB3261E), _loading || visibleMembers.isEmpty ? null : _exportMembers),
            ])),
          ]),
        )),
        const SizedBox(height: 12),
        if (!_profilesAvailable)
          _notice('لتفعيل أسماء المستخدمين والوظائف والفروع، طبّق الملف supabase/erp_company_member_profiles.sql من SQL Editor. ستظل العضويات الحالية محفوظة.', Colors.orange.shade800),
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
              const Text('أدخل UUID لمستخدم موجود بالفعل في Supabase Auth، ثم عرّف اسمه ووظيفته والفرع المرتبط به.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(width: 270, child: TextField(controller: _userId, decoration: const InputDecoration(labelText: 'معرّف المستخدم UUID', isDense: true))),
                SizedBox(width: 240, child: TextField(controller: _memberName, decoration: const InputDecoration(labelText: 'اسم المستخدم', isDense: true))),
                SizedBox(width: 220, child: TextField(controller: _jobTitle, decoration: const InputDecoration(labelText: 'الوظيفة', isDense: true))),
                SizedBox(width: 220, child: DropdownButtonFormField<String?>(
                  value: _newBranchId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الفرع', isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('بدون فرع')),
                    ..._branches.map((branch) => DropdownMenuItem<String?>(
                      value: _s(branch['id']),
                      child: Text(_s(branch['branch_name']), overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: _saving ? null : (value) => setState(() => _newBranchId = value),
                )),
                SizedBox(width: 220, child: DropdownButtonFormField<String>(
                  value: _newRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الدور داخل الشركة', isDense: true),
                  items: _roles.entries.where((entry) => entry.key != 'owner').map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: _saving ? null : (value) { if (value != null) setState(() => _newRole = value); },
                )),
                FilledButton.icon(
                  onPressed: _saving ? null : _addMember,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة العضوية'),
                  style: FilledButton.styleFrom(backgroundColor: _membersPurple),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('دليل المستخدمين', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          Text('${visibleMembers.length} من ${_members.length}', style: const TextStyle(color: _membersPurple, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, children: [
          SizedBox(width: 280, child: TextField(
            controller: _nameFilter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'بحث بالاسم أو UUID', prefixIcon: Icon(Icons.search), isDense: true),
          )),
          SizedBox(width: 220, child: DropdownButtonFormField<String>(
            value: _jobFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'فلتر الوظيفة', isDense: true),
            items: [
              const DropdownMenuItem(value: '__all__', child: Text('كل الوظائف')),
              ..._jobTitles.map((job) => DropdownMenuItem(value: job, child: Text(job, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) => setState(() => _jobFilter = value ?? '__all__'),
          )),
          SizedBox(width: 220, child: DropdownButtonFormField<String>(
            value: _branchFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'فلتر الفرع', isDense: true),
            items: [
              const DropdownMenuItem(value: '__all__', child: Text('كل الفروع')),
              ..._branches.map((branch) => DropdownMenuItem(value: _s(branch['id']), child: Text(_s(branch['branch_name']), overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) => setState(() => _branchFilter = value ?? '__all__'),
          )),
        ]),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
        else if (visibleMembers.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد نتائج مطابقة للبحث والفلاتر، أو ليست لديك صلاحية إدارة الأعضاء.')))
        else
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1E8FB)),
                columnSpacing: 14,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('م')),
                  DataColumn(label: Text('اسم المستخدم / UUID')),
                  DataColumn(label: Text('الوظيفة')),
                  DataColumn(label: Text('الفرع')),
                  DataColumn(label: Text('الدور')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('تعديل')),
                ],
                rows: [
                  for (var index = 0; index < visibleMembers.length; index++)
                    _memberRow(visibleMembers[index], index + 1, currentUserId),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  DataRow _memberRow(Map<String, dynamic> member, int index, String? currentUserId) {
    final userId = _s(member['user_id']);
    final role = _s(member['member_role']);
    final displayName = _s(member['display_name']).trim();
    final isCurrent = userId == currentUserId;
    final isOwner = role == 'owner';
    return DataRow(cells: [
      DataCell(Text('$index')),
      DataCell(SizedBox(width: 230, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(displayName.isEmpty ? (isCurrent ? 'المستخدم الحالي' : 'مستخدم بدون اسم') : displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(userId, style: const TextStyle(color: Colors.black45, fontSize: 10)),
        ],
      ))),
      DataCell(Text(_s(member['job_title']).isEmpty ? '—' : _s(member['job_title']))),
      DataCell(Text(_branchName(member['branch_id']))),
      DataCell(DropdownButton<String>(
        value: _roles.containsKey(role) ? role : 'viewer',
        items: _roles.entries.map((entry) => DropdownMenuItem(value: entry.key, enabled: entry.key != 'owner', child: Text(entry.value))).toList(),
        onChanged: isCurrent || isOwner ? null : (value) { if (value != null && value != role) _updateMember(member, role: value); },
      )),
      DataCell(Switch(
        value: member['is_active'] == true,
        onChanged: isCurrent || isOwner ? null : (value) => _updateMember(member, active: value),
      )),
      DataCell(IconButton(
        tooltip: 'تعديل الاسم والوظيفة والفرع',
        onPressed: _saving || !_profilesAvailable ? null : () => _editMemberProfile(member),
        icon: const Icon(Icons.edit_outlined, color: _membersPurple),
      )),
    ]);
  }

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .3))),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
