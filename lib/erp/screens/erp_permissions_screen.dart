import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _permPurple = Color(0xFF3E007D);

class ErpPermissionsScreen extends StatefulWidget {
  const ErpPermissionsScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpPermissionsScreen> createState() => _ErpPermissionsScreenState();
}

class _ErpPermissionsScreenState extends State<ErpPermissionsScreen> {
  SupabaseClient? _db;
  bool _loading=true, _saving=false, _expandAll=false;
  String _mode='template', _scope='__all__', _menuScope='__all__', _template='مشغل';
  String? _error,_message;
  List<Map<String,dynamic>> _users=[];
  final Set<String> _selectedUsers = <String>{};
  String _userFilterType = 'all';
  String _userFilterValue = '__all__';
  final Map<String,Map<String,bool>> _draft={};
  final Map<String,bool> _expanded={};
  final List<String> _actions=const ['مسموح','إضافة','تعديل','حذف','حفظ','طباعة','Excel','PDF'];
  static const Map<String,Map<String,List<String>>> _tree={
    'إدارة البرنامج':{
      'بيانات أساسية':['بيانات الشركة','الفروع ومراكز التكلفة','المستخدمون والصلاحيات','إعدادات البرنامج','سجل العمليات','واجهة API والربط الخارجي','إدارة مفاتيح API','سياسات التسعير والخصومات'],
      'حركات':['اختبار ومراجعة الحركات','قائمة اعتماد القيود','إدارة الجلسات','سجل الدخول والخروج','النسخ الاحتياطي'],
      'تقارير':['تقرير المستخدمين','تقرير نشاط النظام','تقرير أخطاء التكامل'],
    },
    'الحسابات المالية':{
      'بيانات أساسية':['شجرة الحسابات','الفترات المالية','مراكز التكلفة','العملات','الخزائن الرئيسية والفرعية','الحسابات البنكية','طرق الدفع'],
      'حركات':['قيود اليومية','سندات القبض','سندات الصرف','تسويات الحسابات','إقفال الفترة','تحويل بين الخزائن','مطابقة البنك'],
      'تقارير':['ميزان المراجعة','الأستاذ العام','قائمة الدخل','الميزانية العمومية','حركة حساب','أرصدة الخزائن','التدفقات النقدية','ملخص تنفيذي'],
    },
    'المخازن والفروع':{
      'بيانات أساسية':['دليل المخازن','مجموعات الأصناف','دليل الأصناف','الوحدات والتحويلات','الباركود','دليل الفروع'],
      'حركات':['إذن إضافة','إذن صرف','تحويل مخزني','تسوية جرد','جرد فعلي','تحويلات بين الفروع'],
      'تقارير':['أرصدة الأصناف','كارت الصنف','الجرد والفروق','الأصناف الراكدة','تواريخ الصلاحية','أداء الفروع'],
    },
    'المشتريات والموردون':{
      'بيانات أساسية':['سياسات الشراء','قوائم أسعار الموردين','دليل الموردين','تصنيفات الموردين','شروط التوريد'],
      'حركات':['طلب شراء','أمر شراء','استلام مشتريات','فاتورة مشتريات','مرتجع مشتريات','كشف حساب مورد'],
      'تقارير':['تحليل المشتريات','مقارنة أسعار الموردين','أعمار ديون الموردين','أرصدة الموردين'],
    },
    'المبيعات والعملاء':{
      'بيانات أساسية':['قوائم أسعار البيع','سياسات الخصم','مناطق التوزيع','دليل العملاء','تصنيفات العملاء','دليل المندوبين','أهداف العملاء الشهرية','عمولات المندوبين'],
      'حركات':['عرض سعر','أمر بيع','فاتورة مبيعات','مرتجع مبيعات','إذن تحميل','تسليم طلب','تحصيلات العملاء','متابعة المديونيات'],
      'تقارير':['المبيعات اليومية','ربحية المبيعات','أداء المندوبين','الطلبات المتأخرة','أرصدة العملاء','أعمار الديون'],
    },
    'الموارد البشرية والرواتب':{
      'بيانات أساسية':['هيكل الشركة','الإدارات والأقسام','الوظائف والدرجات','ملف الموظف','العقود','قواعد الورديات والحضور والانصراف','مكونات الراتب'],
      'حركات':['الحضور والانصراف','الإجازات والأذونات','مسير الرواتب','صرف الرواتب','سلف الموظفين'],
      'تقارير':['تقرير الحضور','تقرير الإجازات','كشف الرواتب','تكلفة العمالة'],
    },
    'الخزائن والبنوك':{
      'بيانات أساسية':['الخزائن الرئيسية والفرعية','الحسابات البنكية','طرق الدفع'],
      'حركات':['سندات القبض','سندات الصرف','تحويل بين الخزائن','إيداع بنكي','سحب بنكي','مطابقة البنك'],
      'تقارير':['أرصدة الخزائن','كشف حساب خزينة','كشف حساب بنك','التدفقات النقدية'],
    },
    'التقارير والتحليلات':{
      'بيانات أساسية':['قوالب التقارير','لوحات المؤشرات'],
      'حركات':['تحديث مؤشرات الأداء','تصدير البيانات'],
      'تقارير':['الملخص التنفيذي','مؤشرات المبيعات والعملاء','مؤشرات المالية والسيولة','مؤشرات المخزون والمشتريات','مؤشرات الطلبات والتوزيع','مؤشرات الموظفين والفروع','مؤشرات الرقابة والتنبيهات','مؤشرات الأداء الرئيسية','تحليل الربحية','حركة المبيعات والمخزون'],
    },
    'إدارة التطبيقات':{
      'بيانات أساسية':['إعدادات هوية التطبيق','إدارة الشعار والصور','إدارة ألوان التطبيقات','إدارة صلاحيات التطبيقات','إدارة صور الأصناف والفئات','إدارة صور الموردين والعملاء','إدارة شركات الشحن','إعدادات عامة للتطبيقات'],
      'حركات':['مراجعة طلبات تعديل التطبيقات','سجل تغييرات الهوية','إدارة إصدارات التطبيقات'],
      'تقارير':['تقرير التطبيقات','تقرير الصلاحيات','تقرير تغييرات الإعدادات'],
    },
    'المندوبون والتوزيع':{
      'بيانات أساسية':['دليل المندوبين','مركبات التوزيع','مناطق التوزيع','خطوط السير','توزيع الأصناف على المندوبين'],
      'حركات':['تسليم عهدة مندوب','تصفية عهدة مندوب','تحصيل نقدي','مصروفات رحلة','تسليم طلب'],
      'تقارير':['أداء المندوبين','تصفية المندوبين','تحصيلات يومية','تكلفة خطوط السير'],
    },
    'الشحن وخدمة العملاء':{
      'بيانات أساسية':['شركات الشحن','مناطق التغطية','إعدادات خدمة العملاء'],
      'حركات':['متابعة الشحنات','تحديث حالة التوصيل','شكاوى العملاء','طلبات الدعم'],
      'تقارير':['أداء شركات الشحن','تقرير الشكاوى','الطلبات المتأخرة'],
    },
    'التسويق والعروض':{
      'بيانات أساسية':['الحملات التسويقية','مجلة العروض','شرائح العملاء','قوالب الرسائل'],
      'حركات':['إنشاء حملة','إرسال عروض','متابعة تفاعل العملاء'],
      'تقارير':['أداء الحملات','نتائج العروض','تحليل تفاعل العملاء'],
    },
  };
  @override void initState(){super.initState();try{_db=Supabase.instance.client;}catch(_){}_load();}
  @override void didUpdateWidget(covariant ErpPermissionsScreen oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.companyId!=widget.companyId)_load();}
  String _s(dynamic v)=>(v??'').toString();
  String _key(String m,String s,String p)=>m+'::'+s+'::'+p;
  List<String> get _allKeys=>[for(final m in _tree.entries)_key(m.key,'*','*'),for(final m in _tree.entries)for(final s in m.value.entries)_key(m.key,s.key,'*'),for(final m in _tree.entries)for(final s in m.value.entries)for(final p in s.value)_key(m.key,s.key,p)];
  Map<String,Map<String,List<String>>> get _visibleTree => _menuScope == '__all__'
      ? _tree
      : Map.fromEntries(_tree.entries.where((entry) => entry.key == _menuScope));

  List<String> get _scopeKeys {
    final visible = <String>[];
    for (final menu in _visibleTree.entries) {
      visible.add(_key(menu.key, '*', '*'));
      if (_expanded[menu.key] != true) continue;
      for (final section in menu.value.entries) {
        visible.add(_key(menu.key, section.key, '*'));
        if (_expanded['${menu.key}::${section.key}'] == true) {
          for (final page in section.value) {
            visible.add(_key(menu.key, section.key, page));
          }
        }
      }
    }
    return visible;
  }

  void _setColumn(String action, bool value) {
    setState(() {
      for (final uid in _targets) {
        final map = _draft.putIfAbsent(uid, () => _blank('مخصص بلا صلاحيات'));
        for (final key in _scopeKeys) {
          map['$key::$action'] = value;
          if (action == 'مسموح' && !value) {
            for (final other in _actions.where((item) => item != 'مسموح')) {
              map['$key::$other'] = false;
            }
          }
        }
      }
      _message = 'تم تحديث عمود «$action» للقوائم المحددة. اضغط حفظ لتثبيت التغييرات.';
      _error = null;
    });
  }

  Map<String,bool> _blank(String role){
    final out=<String,bool>{};
    for(final k in _allKeys){
      final read=role!='مخصص بلا صلاحيات';
      out[k+'::مسموح']=read;
      out[k+'::إضافة']=['مدير النظام','مدير','محاسب','مشغل'].contains(role);
      out[k+'::تعديل']=['مدير النظام','مدير','محاسب'].contains(role);
      out[k+'::حذف']=role=='مدير النظام';
      out[k+'::حفظ']=!['عرض فقط','مخصص بلا صلاحيات'].contains(role);
      out[k+'::طباعة']=read;
      out[k+'::Excel']=['مدير النظام','مدير','محاسب'].contains(role);
      out[k+'::PDF']=read;
      if(role=='عرض فقط'){out[k+'::إضافة']=false;out[k+'::تعديل']=false;out[k+'::حذف']=false;out[k+'::حفظ']=false;out[k+'::Excel']=false;}
    }
    return out;
  }
  Future<void> _load() async{
    final company=(widget.companyId??'').trim();
    if(!mounted)return;
    setState(()=>_loading=true);
    if(_db==null||company.isEmpty){setState((){_loading=false;_error='اختر الشركة وسجّل الدخول أولًا.';});return;}
    try{
      final rows=await _db!.from('erp_company_members').select('id,user_id,member_role,is_active,created_at').eq('company_id',company).eq('is_active',true).order('created_at');
      final users=(rows as List).whereType<Map<String,dynamic>>().map((u)=>Map<String,dynamic>.from(u)).toList();
      // Display useful employee labels instead of opaque UUIDs. This lookup is
      // optional so missing profile setup does not prevent permission loading.
      try {
        final profileRows=await _db!.from('erp_company_member_profiles')
            .select('user_id,display_name,job_title,branch_id')
            .eq('company_id',company);
        final profiles=<String,Map<String,dynamic>>{
          for(final p in (profileRows as List).whereType<Map<String,dynamic>>())
            _s(p['user_id']):p,
        };
        for(final user in users){
          final profile=profiles[_s(user['user_id'])];
          user['display_name']=profile?['display_name'];
          user['job_title']=profile?['job_title'];
          user['branch_id']=profile?['branch_id'];
        }
      } catch (_) {
        // Older installations may not yet have the optional member directory.
      }
      final saved=await _db!.from('erp_user_permissions').select('user_id,menu_key,allow_access,can_add,can_edit,can_delete,can_save,can_print,can_export_excel,can_export_pdf').eq('company_id',company);
      _draft.clear();for(final u in users){_draft[_s(u['user_id'])]=_blank('مخصص بلا صلاحيات');}
      final fields={'مسموح':'allow_access','إضافة':'can_add','تعديل':'can_edit','حذف':'can_delete','حفظ':'can_save','طباعة':'can_print','Excel':'can_export_excel','PDF':'can_export_pdf'};
      for(final r in (saved as List).whereType<Map<String,dynamic>>()){
        final uid=_s(r['user_id']),key=_s(r['menu_key']);if(!_draft.containsKey(uid))continue;
        for(final a in fields.entries){_draft[uid]![key+'::'+a.key]=r[a.value]==true;}
      }
      if(!mounted)return;setState((){_users=users;_loading=false;_error=null;_message=null;});
    }catch(e){
      if(!mounted)return;
      final details=e.toString();
      final normalized=details.toLowerCase();
      final message = normalized.contains('erp_user_permissions') ||
              normalized.contains('does not exist') ||
              normalized.contains('42p01')
          ? 'جدول الصلاحيات غير موجود أو لم تُطبّق تهيئته. شغّل supabase/erp_user_permissions.sql من SQL Editor ثم أعد التحميل. '
          : (normalized.contains('permission denied') || normalized.contains('row-level security') || normalized.contains('rls')
              ? 'تعذر الوصول إلى الصلاحيات بسبب سياسات قاعدة البيانات. تأكد أن عضويتك مالك أو مدير للشركة وأن سياسات RLS مطبّقة. '
              : 'تعذر تحميل الصلاحيات. راجع تهيئة الجداول وسياسات الوصول. ');
      setState((){_loading=false;_error=message+details;});
    }
  }
  List<String> get _targets {
    if (_selectedUsers.isNotEmpty) return _users
        .map((u) => _s(u['user_id']))
        .where(_selectedUsers.contains)
        .toList();
    return _scope == '__all__'
        ? _users.map((u) => _s(u['user_id'])).toList()
        : [_scope];
  }

  String _userLabel(Map<String, dynamic> user) {
    final id = _s(user['user_id']);
    final name = _s(user['display_name']).trim();
    final job = _s(user['job_title']).trim();
    final role = _s(user['member_role']).trim();
    final shortId = id.length > 10 ? id.substring(0, 10) : id;
    return (name.isNotEmpty ? name : '$role — $shortId…') +
        (job.isNotEmpty ? ' — $job' : '') +
        (role.isNotEmpty && name.isNotEmpty ? ' ($role)' : '');
  }

  List<String> get _userFilterValues {
    final values = <String>{};
    for (final user in _users) {
      final value = _userFilterType == 'job'
          ? _s(user['job_title']).trim()
          : _s(user['member_role']).trim();
      if (value.isNotEmpty) values.add(value);
    }
    return values.toList()..sort();
  }

  Future<void> _pickUsersF1() async {
    final chosen = <String>{..._selectedUsers};
    if (chosen.isEmpty && _scope != '__all__') chosen.add(_scope);
    String search = '';
    String filterType = 'all';
    String filterValue = '__all__';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filterValues = <String>{};
          for (final user in _users) {
            final value = filterType == 'job'
                ? _s(user['job_title']).trim()
                : _s(user['member_role']).trim();
            if (value.isNotEmpty) filterValues.add(value);
          }
          final visible = _users.where((user) {
            final id = _s(user['user_id']);
            final role = _s(user['member_role']).trim();
            final value = filterType == 'job'
                ? _s(user['job_title']).trim()
                : role;
            final text = _userLabel(user).toLowerCase();
            return (filterValue == '__all__' || value == filterValue) &&
                (search.trim().isEmpty ||
                    text.contains(search.trim().toLowerCase()) ||
                    id.toLowerCase().contains(search.trim().toLowerCase()));
          }).toList();
          return AlertDialog(
            title: const Text('جلب المستخدمين — F1'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'بحث بالاسم أو الوظيفة أو التصنيف',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) => setDialogState(() => search = value),
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('كل المستخدمين'),
                        selected: filterType == 'all',
                        onSelected: (_) => setDialogState(() {
                          filterType = 'all';
                          filterValue = '__all__';
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('حسب التصنيف'),
                        selected: filterType == 'role',
                        onSelected: (_) => setDialogState(() {
                          filterType = 'role';
                          filterValue = '__all__';
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('حسب الوظيفة'),
                        selected: filterType == 'job',
                        onSelected: (_) => setDialogState(() {
                          filterType = 'job';
                          filterValue = '__all__';
                        }),
                      ),
                    ],
                  ),
                  if (filterType != 'all')
                    DropdownButtonFormField<String>(
                      value: filterValue,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: filterType == 'job' ? 'الوظيفة' : 'التصنيف',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '__all__',
                          child: Text('كل القيم'),
                        ),
                        ...((filterValues.toList()..sort()).map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )),
                      ],
                      onChanged: (value) => setDialogState(
                        () => filterValue = value ?? '__all__',
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('المحدد: ${chosen.length}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          chosen.addAll(visible.map((u) => _s(u['user_id'])));
                        }),
                        child: const Text('تحديد الظاهر'),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          chosen.removeAll(visible.map((u) => _s(u['user_id'])));
                        }),
                        child: const Text('إلغاء الظاهر'),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          chosen
                            ..clear()
                            ..addAll(_users.map((u) => _s(u['user_id'])));
                        }),
                        child: const Text('تحديد الكل'),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SizedBox(
                      height: 320,
                      child: visible.isEmpty
                          ? const Center(child: Text('لا يوجد مستخدمون مطابقون'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final user = visible[index];
                                final id = _s(user['user_id']);
                                return CheckboxListTile(
                                  dense: true,
                                  value: chosen.contains(id),
                                  title: Text(_userLabel(user)),
                                  subtitle: Text('التصنيف: ${_s(user['member_role'])}'),
                                  onChanged: (value) => setDialogState(() {
                                    if (value == true) {
                                      chosen.add(id);
                                    } else {
                                      chosen.remove(id);
                                    }
                                  }),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (chosen.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اختر مستخدمًا واحدًا على الأقل، أو استخدم تحديد الكل.')),
                    );
                    return;
                  }
                  setState(() {
                    _selectedUsers
                      ..clear()
                      ..addAll(chosen);
                    if (chosen.isNotEmpty) {
                      _scope = chosen.length == 1 ? chosen.first : '__selected__';
                    } else {
                      _scope = '__all__';
                    }
                    _message = chosen.isEmpty
                        ? 'لم يتم اختيار مستخدمين.'
                        : 'تم جلب ${chosen.length} مستخدم لتطبيق الصلاحيات عليهم.';
                    _error = null;
                  });
                  Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.check),
                label: const Text('اعتماد الاختيار'),
              ),
            ],
          );
        },
      ),
    );
  }
  void _applyTemplate(String role){
    final fresh=_blank(role);setState(()=>_template=role);
    setState((){
      for(final uid in _targets){_draft[uid]??={};_draft[uid]!.addAll(fresh);}
      _message='تم تطبيق القالب. اضغط حفظ لتثبيته.';_error=null;
    });
  }
  List<String> _affectedKeys(String key) {
    final parts=key.split('::');
    if(parts.length!=3)return [key];
    if(parts[1]=='*')return _allKeys.where((k)=>k.startsWith(parts[0]+'::')).toList();
    if(parts[2]=='*')return _allKeys.where((k)=>k.startsWith(parts[0]+'::'+parts[1]+'::')).toList();
    return [key];
  }
  void _setCell(String key,String action,bool value){setState((){
    final affected=_affectedKeys(key);
    for(final uid in _targets){
      final map=_draft.putIfAbsent(uid,()=>_blank('مخصص بلا صلاحيات'));
      for(final affectedKey in affected){
        map[affectedKey+'::'+action]=value;
        if(action=='مسموح'&&!value){for(final other in _actions.where((a)=>a!='مسموح'))map[affectedKey+'::'+other]=false;}
      }
    }
    _message=null;_error=null;
  });}
  bool _cell(String key,String action){
    final t=_targets;if(t.isEmpty)return false;
    return (_scope == '__all__' || _selectedUsers.isNotEmpty)
        ? t.every((uid) => _draft[uid]?[key + '::' + action] == true)
        : _draft[_scope]?[key + '::' + action] == true;
  }
  void _bulk(bool value){setState((){
    for(final uid in _targets){final map=_draft.putIfAbsent(uid,()=>_blank('مخصص بلا صلاحيات'));for(final key in _scopeKeys){for(final a in _actions){map[key+'::'+a]=value;}}}
    _message=value?'تم تحديد صلاحيات القوائم المحددة.':'تم إلغاء صلاحيات القوائم المحددة.';_error=null;
  });}
  Future<void> _save() async{
    final company=(widget.companyId??'').trim();if(_db==null||company.isEmpty){setState(()=>_error='لا توجد شركة محددة.');return;}
    final targets=_targets;if(targets.isEmpty){setState(()=>_error='لا يوجد مستخدم نشط.');return;}
    setState((){_saving=true;_error=null;_message=null;});
    try{
      for(final uid in targets){
        final values=_draft[uid]??_blank('مخصص بلا صلاحيات');
        final rows=<Map<String,dynamic>>[];
        for(final key in _allKeys){
          rows.add({'company_id':company,'user_id':uid,'menu_key':key,'allow_access':values[key+'::مسموح']==true,'can_add':values[key+'::إضافة']==true,'can_edit':values[key+'::تعديل']==true,'can_delete':values[key+'::حذف']==true,'can_save':values[key+'::حفظ']==true,'can_print':values[key+'::طباعة']==true,'can_export_excel':values[key+'::Excel']==true,'can_export_pdf':values[key+'::PDF']==true,'updated_at':DateTime.now().toUtc().toIso8601String(),'updated_by':_db!.auth.currentUser?.id});
        }
        await _db!.from('erp_user_permissions').upsert(rows,onConflict:'company_id,user_id,menu_key');
      }
      if(!mounted)return;setState((){_saving=false;_message=_scope=='__all__'?'تم حفظ الصلاحيات لجميع المستخدمين النشطين.':'تم حفظ صلاحيات المستخدم المحدد فقط.';});
    }catch(e){if(!mounted)return;setState((){_saving=false;_error='تعذر حفظ الصلاحيات: '+e.toString();});}
  }
  Widget _row(String key,String label,{bool nested=false})=>Container(margin:EdgeInsetsDirectional.only(start:nested?12:0,bottom:5),padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:Colors.black12),borderRadius:BorderRadius.circular(8)),child:Row(children:[
    Expanded(flex:3,child:Text(label,style:TextStyle(fontSize:11,fontWeight:nested?FontWeight.w600:FontWeight.w800))),
    for(final a in _actions)Expanded(flex:1,child:Center(child:Checkbox(value:_cell(key,a),onChanged:_saving?null:(v)=>_setCell(key,a,v??false),activeColor:_permPurple,visualDensity:VisualDensity.compact))),
  ]));
  Widget _section(String main,String section,List<String> pages){
    final k=main+'::'+section,open=_expanded[k]??false;
    return Card(margin:const EdgeInsets.only(bottom:7),child:Column(children:[
      ListTile(dense:true,leading:Icon(open?Icons.folder_open:Icons.folder,color:_permPurple),title:Text(section,style:const TextStyle(fontWeight:FontWeight.w800)),trailing:IconButton(tooltip:open?'طي':'فتح',onPressed:()=>setState(()=>_expanded[k]=!open),icon:Icon(open?Icons.remove_circle_outline:Icons.add_circle_outline,color:_permPurple)),onTap:()=>setState(()=>_expanded[k]=!open)),
      if(open)Padding(padding:const EdgeInsets.fromLTRB(8,0,8,8),child:Column(children:[_row(_key(main,section,'*'),'صلاحيات القائمة الفرعية'),for(final p in pages)_row(_key(main,section,p),p,nested:true)])),
    ]));
  }
  Widget _main(String main,Map<String,List<String>> sections){
    final open=_expanded[main]??false;
    return Card(margin:const EdgeInsets.only(bottom:9),child:Column(children:[
      ListTile(leading:const Icon(Icons.account_tree_outlined,color:_permPurple),title:Text(main,style:const TextStyle(fontWeight:FontWeight.w900)),trailing:IconButton(tooltip:open?'طي القائمة':'فتح القائمة',onPressed:()=>setState(()=>_expanded[main]=!open),icon:Icon(open?Icons.remove_circle_outline:Icons.add_circle_outline,color:_permPurple)),onTap:()=>setState(()=>_expanded[main]=!open)),
      if(open)Padding(padding:const EdgeInsets.fromLTRB(8,0,8,8),child:Column(children:[_row(_key(main,'*','*'),'صلاحيات القائمة الرئيسية'),for(final s in sections.entries)_section(main,s.key,s.value)])),
    ]));
  }
  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewPermissions() async {
    final enabled = _draft.values.fold<int>(0, (sum, values) => sum + values.values.where((v) => v).length);
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة إعدادات الصلاحيات'),
      content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('المستخدمون المحمّلون: ${_users.length}'),
        Text('المستخدمون المحددون: ${_selectedUsers.length}'),
        Text('القائمة الحالية: $_menuScope'),
        Text('عدد خيارات الصلاحيات المفعّلة في المسودة: $enabled'),
        Text('طريقة الإعداد: $_mode'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(color:_permPurple,child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Row(children:[Icon(Icons.admin_panel_settings_outlined,color:Color(0xFFFFA015),size:27),SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('إدارة الصلاحيات',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:Colors.white)),Text('قوالب أو تحديد يدوي حسب المستخدم والقائمة',style:TextStyle(fontSize:12,color:Colors.white70))]))]),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        _quickTask('تحديث',Icons.refresh,Colors.blue,_loading||_saving?null:_load),
        _quickTask('حفظ',Icons.save_outlined,const Color(0xFF168447),_saving?null:_save),
        _quickTask(_expandAll?'طي الكل':'فتح الكل',_expandAll?Icons.unfold_less:Icons.unfold_more,const Color(0xFFEF9B13),()=>setState((){_expandAll=!_expandAll;for(final m in _tree.keys){_expanded[m]=_expandAll;for(final sub in _tree[m]!.keys){_expanded[m+'::'+sub]=_expandAll;}}})),
        _quickTask('معاينة',Icons.visibility_outlined,const Color(0xFF6841A5),_previewPermissions),
      ])),
    ]))),
    const SizedBox(height:8),
    if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(_error!,style:const TextStyle(color:Colors.red))),
    if(_message!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(_message!,style:const TextStyle(color:Colors.green))),
    if(_loading)const Expanded(child:Center(child:CircularProgressIndicator()))else Expanded(child:ListView(padding:const EdgeInsets.only(bottom:20),children:[
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('طريقة تحديد الصلاحيات',style:TextStyle(fontWeight:FontWeight.w900,color:_permPurple)),
        const SizedBox(height:8),
        SegmentedButton<String>(segments:const[ButtonSegment(value:'template',label:Text('قالب جاهز')),ButtonSegment(value:'manual',label:Text('تحديد يدوي'))],selected:{_mode},onSelectionChanged:(v)=>setState(()=>_mode=v.first)),
        if(_mode=='template')Padding(padding:const EdgeInsets.only(top:8),child:DropdownButtonFormField<String>(value:_template,decoration:const InputDecoration(labelText:'القالب',isDense:true),items:const['مدير النظام','مدير','محاسب','مشغل','عرض فقط','مخصص بلا صلاحيات'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)_applyTemplate(v);})),
        const SizedBox(height:8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading || _saving || _users.isEmpty ? null : _pickUsersF1,
                icon: const Icon(Icons.person_search),
                label: const Text('جلب المستخدمين F1'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _permPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _userFilterType,
                decoration: const InputDecoration(labelText: 'تصفية حسب', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل المستخدمين')),
                  DropdownMenuItem(value: 'role', child: Text('التصنيف')),
                  DropdownMenuItem(value: 'job', child: Text('الوظيفة')),
                ],
                onChanged: (v) => setState(() {
                  _userFilterType = v ?? 'all';
                  _userFilterValue = '__all__';
                }),
              ),
            ),
          ],
        ),
        if (_userFilterType != 'all')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              value: _userFilterValues.contains(_userFilterValue) ? _userFilterValue : '__all__',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _userFilterType == 'job' ? 'اختيار الوظيفة' : 'اختيار التصنيف',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: '__all__', child: Text('كل القيم')),
                ..._userFilterValues.map((v) => DropdownMenuItem(value: v, child: Text(v))),
              ],
              onChanged: (v) => setState(() => _userFilterValue = v ?? '__all__'),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          _selectedUsers.isNotEmpty
              ? 'المستخدمون المحددون: ${_targets.length}. يمكن تحديد مستخدم واحد أو عدة مستخدمين أو الكل من زر F1.'
              : 'المستخدم الحالي: ${_scope == '__all__' ? 'كل المستخدمين النشطين' : _userLabel(_users.firstWhere((u) => _s(u['user_id']) == _scope, orElse: () => <String, dynamic>{'user_id': _scope}))}. استخدم F1 للاختيار المتعدد أو التصفية بالتصنيف والوظيفة.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(
          value:_menuScope,
          decoration:const InputDecoration(labelText:'نطاق القوائم',isDense:true),
          items:[
            const DropdownMenuItem(value:'__all__',child:Text('كل القوائم الرئيسية')),
            ..._tree.keys.map((name)=>DropdownMenuItem(value:name,child:Text(name))),
          ],
          onChanged:(v){if(v!=null)setState(()=>_menuScope=v);},
        ),
        const SizedBox(height:6),
        const Text('يطبّق الاختيار على المستخدم أو الكل، وعلى كل القوائم أو القائمة الرئيسية المحددة. استخدم مربعات أعلى الأعمدة لتحديد صلاحية لكل القوائم ضمن النطاق.',style:TextStyle(fontSize:12,color:Colors.black54)),
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('مصفوفة الصلاحيات',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:_permPurple)),const SizedBox(height:8),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:SizedBox(width:900,child:Column(children:[
          Row(children:[
            const Expanded(flex:3,child:Text('القائمة / الشاشة',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900))),
            for(final a in _actions)
              Expanded(flex:1,child:Column(mainAxisSize:MainAxisSize.min,children:[
                Text(a,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800),textAlign:TextAlign.center),
                Checkbox(
                  value:_scopeKeys.isNotEmpty && _targets.isNotEmpty && _scopeKeys.every((key)=>_targets.every((uid)=>_draft[uid]?[key+'::'+a]==true)),
                  onChanged:_saving?null:(value)=>_setColumn(a,value??false),
                  activeColor:_permPurple,
                  visualDensity:VisualDensity.compact,
                ),
              ])),
          ]),
          const Divider(),
          Align(alignment:AlignmentDirectional.centerStart,child:Wrap(spacing:8,children:[FilledButton.tonal(onPressed:_saving?null:()=>_bulk(true),child:const Text('تحديد الكل')),OutlinedButton(onPressed:_saving?null:()=>_bulk(false),child:const Text('إزالة الكل'))])),
          const SizedBox(height:8),
          for(final m in _visibleTree.entries)_main(m.key,m.value),
        ]))),
      ]))),
    ])),
  ]));
}
