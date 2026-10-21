import 'dart:convert';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/erp_keyboard_navigation.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userAdminPurple = Color(0xFF3E007D);
const _userAdminCanvas = Color(0xFFF7F5FA);
const _userAdminActions = <String>['تحديث','إضافة','حفظ','تعديل','حذف','معاينة','طباعة','استيراد Excel','طباعة PDF'];
const _userAdminActionFields = <String,String>{
  'تحديث':'can_refresh','إضافة':'can_add','حفظ':'can_save','تعديل':'can_edit','حذف':'can_delete',
  'معاينة':'can_preview','طباعة':'can_print','استيراد Excel':'can_import_excel','طباعة PDF':'can_print_pdf',
};
const _userAdminTree = <String,Map<String,List<String>>>{
  'إدارة البرنامج':{
    'بيانات أساسية':['بيانات الشركة','أنواع المستخدمين','المستخدمين','قوالب صلاحيات المستخدمين','صلاحيات المستخدمين','إعدادات البرنامج','الفروع ومراكز التكلفة'],
    'حركات':['اختبار ومراجعة الحركات','سجل العمليات'],
    'تقارير':['تقرير المستخدمين','تقرير نشاط النظام'],
  },
  'الحسابات المالية':{
    'بيانات أساسية':['شجرة الحسابات','الفترات المالية','مراكز التكلفة','العملات','الخزائن الرئيسية والفرعية'],
    'حركات':['قيود اليومية','سندات القبض','سندات الصرف','تحويل بين الخزائن'],
    'تقارير':['ميزان المراجعة','الأستاذ العام','قائمة الدخل','الميزانية العمومية'],
  },
  'المخازن والفروع':{
    'بيانات أساسية':['دليل المخازن','مجموعات الأصناف','دليل الأصناف'],
    'حركات':['إذن إضافة','إذن صرف','تحويل مخزني','تسوية جرد'],
    'تقارير':['أرصدة الأصناف','كارت الصنف','الجرد والفروق'],
  },
  'المشتريات والموردون':{
    'بيانات أساسية':['دليل الموردين','قوائم أسعار الموردين'],
    'حركات':['طلب شراء','أمر شراء','استلام مشتريات','فاتورة مشتريات','مرتجع مشتريات'],
    'تقارير':['تحليل المشتريات','أرصدة الموردين'],
  },
  'المبيعات والعملاء':{
    'بيانات أساسية':['دليل العملاء','قوائم أسعار البيع','دليل المندوبين'],
    'حركات':['عرض سعر','أمر بيع','فاتورة مبيعات','مرتجع مبيعات','إذن التجهيز','إذن التسليم'],
    'تقارير':['المبيعات اليومية','ربحية المبيعات','أرصدة العملاء'],
  },
  'الموارد البشرية والرواتب':{
    'بيانات أساسية':['ملف الموظف','قواعد الورديات والحضور والانصراف'],
    'حركات':['الحضور والانصراف','الإجازات والأذونات','مسير الرواتب'],
    'تقارير':['تقرير الحضور','كشف الرواتب'],
  },
};

class ErpUserAdminScreen extends StatefulWidget {
  const ErpUserAdminScreen({super.key, required this.companyId, required this.initialView});
  final String? companyId;
  final String initialView;
  @override
  State<ErpUserAdminScreen> createState() => _ErpUserAdminScreenState();
}

class _ErpUserAdminScreenState extends State<ErpUserAdminScreen> {
  SupabaseClient? _db;
  final _picker = ImagePicker();
  late String _view;
  bool _loading = false, _saving = false, _editMode = false;
  String? _error, _message, _selectedId, _selectedUserId;
  List<Map<String,dynamic>> _rows = [], _types = [], _users = [], _templates = [], _rules = [];
  List<Map<String,dynamic>> _branches = [], _warehouses = [];
  String? _selectedTemplateId;
  String? _activeCompanyId;
  String _selectedPageKey = 'إدارة البرنامج|بيانات أساسية|بيانات الشركة';
  static const _typeNames = <String,String>{
    'types':'أنواع المستخدمين','users':'المستخدمين','templates':'قوالب صلاحيات المستخدمين','permissions':'صلاحيات المستخدمين'
  };

  @override void initState() { super.initState(); _view=widget.initialView; _activeCompanyId=widget.companyId; try {_db=Supabase.instance.client;} catch (_) {} _load(); }
  @override void didUpdateWidget(covariant ErpUserAdminScreen oldWidget) { super.didUpdateWidget(oldWidget); if(oldWidget.companyId!=widget.companyId || oldWidget.initialView!=widget.initialView){_activeCompanyId=widget.companyId;_view=widget.initialView;_load();} }
  @override void dispose() { super.dispose(); }
  String _s(dynamic v) => (v??'').toString();

  // Always keep the user-types grid visible even if database reads/writes are
  // blocked by company membership or RLS. These rows are preview-only until saved.
  List<Map<String, dynamic>> _localDefaultUserTypes() {
    const defaults = <Map<String, dynamic>>[
      {'name_ar':'ادمن','name_en':'Admin','show_at_login':false},
      {'name_ar':'موظف','name_en':'Employee','show_at_login':false},
      {'name_ar':'مورد','name_en':'Supplier','show_at_login':true},
      {'name_ar':'عميل','name_en':'Customer','show_at_login':true},
      {'name_ar':'مندوب','name_en':'Delegate','show_at_login':true},
      {'name_ar':'شركة شحن','name_en':'Shipping Company','show_at_login':true},
    ];
    return List<Map<String, dynamic>>.generate(defaults.length, (i) => {
      'id': 'local-default-user-type-$i',
      'type_code': i + 1,
      ...defaults[i],
      'is_active': true,
      '_local_default': true,
    });
  }
  String get _company => (_activeCompanyId ?? widget.companyId ?? '').trim();
  bool get _isType => _view=='types';
  bool get _isUser => _view=='users';
  bool get _isTemplate => _view=='templates';
  bool get _isPermissions => _view=='permissions';
  String get _table => _isType?'erp_user_types':_isUser?'erp_users':'erp_permission_templates';

  Future<void> _load() async {
    if (!mounted) return;
    if (_db == null) {
      setState(() { _loading = false; _error = 'الاتصال بقاعدة البيانات غير متاح.'; });
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      // Resolve the signed-in user's active company even when the dashboard supplied a stale
      // company ID. A stale non-empty ID must not leave this screen with an empty types grid.
      final userId = _db!.auth.currentUser?.id;
      if (userId != null) {
        try {
          final memberships = await _db!
              .from('erp_company_members')
              .select('company_id')
              .eq('user_id', userId)
              .eq('is_active', true)
              .order('created_at');
          final ids = (memberships as List)
              .map((row) => (row['company_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toList();
          if (ids.isNotEmpty && !ids.contains(_company)) {
            _activeCompanyId = ids.first;
          } else if (_company.isEmpty && ids.isNotEmpty) {
            _activeCompanyId = ids.first;
          }
        } catch (_) {
          // Continue with the company ID supplied by the parent if membership lookup is unavailable.
        }
      }
      if (_company.isEmpty) {
        throw StateError('لم يتم العثور على شركة نشطة مرتبطة بالمستخدم الحالي.');
      }
      List<Map<String, dynamic>> typeList = [];
      List<Map<String, dynamic>> userList = [];
      List<Map<String, dynamic>> templateList = [];

      if (_isType || _isUser || _isPermissions) {
        final result = await _db!.from('erp_user_types').select().eq('company_id', _company).order('type_code');
        typeList = (result as List).map((x) => Map<String, dynamic>.from(x)).toList();
        const defaults = <Map<String, dynamic>>[
          {'name_ar':'ادمن','name_en':'Admin','show_at_login':false},
          {'name_ar':'موظف','name_en':'Employee','show_at_login':false},
          {'name_ar':'مورد','name_en':'Supplier','show_at_login':true},
          {'name_ar':'عميل','name_en':'Customer','show_at_login':true},
          {'name_ar':'مندوب','name_en':'Delegate','show_at_login':true},
          {'name_ar':'شركة شحن','name_en':'Shipping Company','show_at_login':true},
        ];
        // Repair missing defaults one at a time. A denied/duplicate insert must
        // not abort the whole screen load or hide already-saved rows.
        var seedWarning = false;
        for (final type in defaults) {
          final exists = typeList.any((row) => _s(row['name_ar']) == type['name_ar']);
          if (!exists) {
            try {
              await _db!.from('erp_user_types').insert(<String,dynamic>{
                ...type, 'company_id':_company, 'is_active':true,
              });
            } catch (_) {
              seedWarning = true;
            }
          }
        }
        // Always show all saved types, including Delegate; never filter a type
        // from the grid because it is legacy or not shown at login.
        typeList = (await _db!.from('erp_user_types').select()
            .eq('company_id', _company).order('type_code') as List)
            .map((x) => Map<String, dynamic>.from(x))
            .toList();
        if (seedWarning && typeList.length < defaults.length && mounted) {
          setState(() => _message = 'تم تحميل الأنواع الموجودة، لكن تعذر إنشاء بعض الأنواع الناقصة. راجع صلاحيات المالك/المدير وسياسات قاعدة البيانات.');
        }
        if (typeList.isEmpty) {
          typeList = _localDefaultUserTypes();
          if (mounted) setState(() => _message =
            'تعذر جلب أنواع المستخدمين المحفوظة من قاعدة البيانات؛ يعرض الجدول الأنواع الافتراضية للمعاينة. راجع عضوية الشركة وسياسات RLS ثم اضغط تحديث.');
        }
        const priority = {'ادمن':0,'موظف':1,'مورد':2,'عميل':3,'مندوب':4,'شركة شحن':5};
        typeList.sort((a,b) => (priority[_s(a['name_ar'])] ?? 99).compareTo(priority[_s(b['name_ar'])] ?? 99));
      }
      if (_isUser || _isPermissions) {
        // Load users directly; avoid a fragile PostgREST embedded foreign-key relationship.
        final result = await _db!.from('erp_users').select().eq('company_id', _company).order('user_code');
        userList = (result as List).map((x) => Map<String,dynamic>.from(x)).toList();
        if (_isUser) {
          try {
            final b = await _db!.from('erp_branches').select().eq('company_id', _company).eq('is_active', true).order('branch_name');
            _branches = (b as List).map((x) => Map<String,dynamic>.from(x)).toList();
          } catch (_) { _branches = []; }
          try {
            final w = await _db!.from('erp_warehouses').select().eq('company_id', _company).eq('is_active', true).order('warehouse_name');
            _warehouses = (w as List).map((x) => Map<String,dynamic>.from(x)).toList();
          } catch (_) { _warehouses = []; }
        }
      }
      if (_isTemplate || _isPermissions) {
        final result = await _db!.from('erp_permission_templates').select().eq('company_id', _company).order('template_code');
        templateList = (result as List).map((x) => Map<String,dynamic>.from(x)).toList();
      }
      if (!mounted) return;
      setState(() {
        _types=typeList; _users=userList; _templates=templateList;
        _rows=_isType?typeList:_isUser?userList:_isTemplate?templateList:userList;
        if (_selectedId != null && !_rows.any((r)=>_s(r['id'])==_selectedId)) _selectedId=null;
        if (_selectedUserId != null && !userList.any((r)=>_s(r['id'])==_selectedUserId)) _selectedUserId=null;
        if (_selectedUserId==null && userList.isNotEmpty) _selectedUserId=_s(userList.first['id']);
        if (_selectedTemplateId != null && !templateList.any((r)=>_s(r['id'])==_selectedTemplateId)) _selectedTemplateId=null;
        if (_selectedTemplateId==null && templateList.isNotEmpty) _selectedTemplateId=_s(templateList.first['id']);
        _loading=false; _error=null;
        if (_isUser && userList.isEmpty) _message='لا توجد سجلات مستخدمين محفوظة لهذه الشركة حتى الآن. يمكنك إضافة مستخدم من زر إضافة.';
        if (_isType && typeList.any((r)=>r['_local_default']==true)) _message='أنواع المستخدمين الافتراضية معروضة في الجدول، لكن تعذر حفظها في قاعدة البيانات بسبب الصلاحيات أو سياسات RLS. يمكنك مراجعة السياسات ثم الضغط على تحديث.';
        if (_isType && typeList.length < 6) _message='عدد أنواع المستخدمين أقل من 6؛ راجع صلاحيات قاعدة البيانات ثم اضغط تحديث لإكمال الأنواع الناقصة.';
      });
      if (_isTemplate && _selectedId!=null) await _loadRules();
      if (_isPermissions) await _loadUserRules();
    } catch(e) {
      if (mounted) setState(() {
        _loading=false;
        _error='تعذر تحميل بيانات الشاشة: $e';
        if (_isType) {
          _types = _localDefaultUserTypes();
          _rows = List<Map<String, dynamic>>.from(_types);
          _message = 'تم إظهار الأنواع الافتراضية في الجريد للمعاينة. تعذر الوصول إلى بيانات قاعدة البيانات؛ لا تُعتبر هذه الصفوف محفوظة حتى تنجح المزامنة.';
        }
      });
    }
  }

  Future<void> _loadRules() async {
    if(_selectedId==null)return;
    try { final result=await _db!.from('erp_permission_template_rules').select().eq('company_id',_company).eq('template_id',_selectedId!).order('menu_name').order('submenu_name').order('page_name');
      if(mounted)setState(()=>_rules=(result as List).map((x)=>Map<String,dynamic>.from(x)).toList());
    } catch(e){if(mounted)setState(()=>_error='تعذر تحميل تفاصيل القالب: $e');}
  }
  Future<void> _loadUserRules() async {
    if(_selectedUserId==null)return;
    try { final result=await _db!.from('erp_user_permission_matrix').select().eq('company_id',_company);
      if(mounted)setState(()=>_rules=(result as List).map((x)=>Map<String,dynamic>.from(x)).toList());
    } catch(e){if(mounted)setState(()=>_error='تعذر تحميل صلاحيات المستخدم: $e');}
  }

  Future<void> _add() async {
    if(_saving)return;
    setState(()=>_editMode=true);
    try {
      if(_isPermissions){setState(()=>_message='اختر المستخدم ثم عدّل مربعات الصلاحيات في الجدول.');return;}
      final payload=<String,dynamic>{'company_id':_company,'is_active':true};
      if(_isType){payload.addAll({'name_ar':'نوع مستخدم جديد','name_en':'New user type','show_at_login':false});}
      else if(_isUser){payload.addAll({'name_ar':'مستخدم جديد','name_en':'New user','user_type_id':_types.isEmpty?null:_types.first['id'],'has_sub_warehouse':false});}
      else {payload.addAll({'name_ar':'قالب صلاحيات جديد','name_en':'New permission template'});}
      final row=await _db!.from(_table).insert(payload).select().single();
      if(!mounted)return;
      setState(()=>_message='تم إنشاء سجل جديد. أكمل بياناته ثم اضغط حفظ.');
      await _load();
      if(mounted)setState(()=>_selectedId=_s(row['id']));
    } catch(e){if(mounted)setState(()=>_error='تعذر إضافة السجل: $e');}
  }

  Future<void> _save() async {
    if (_isType && _rows.any((row) => row['_local_default'] == true)) {
      setState(() => _error = 'الأنواع الظاهرة حاليًا بيانات افتراضية للمعاينة فقط وليست محفوظة. أصلح صلاحيات/سياسات قاعدة البيانات ثم اضغط تحديث قبل الحفظ.');
      return;
    }
    if(!_editMode){setState(()=>_error='اضغط «تعديل» أو «إضافة» أولًا قبل تغيير البيانات.');return;}
    if(_saving)return;
    setState(()=>_saving=true);
    try {
      if(_isType||_isUser||_isTemplate||_isPermissions){
        final masterRows=_isPermissions?_users:_rows;
        final targetTable=_isPermissions?'erp_users':_table;
        for(final row in masterRows){
          final payload=<String,dynamic>{};
          if(_isType)payload.addAll({'name_ar':_s(row['name_ar']).trim(),'name_en':_s(row['name_en']).trim(),'image_data':row['image_data'],'is_active':row['is_active']==true,'show_at_login':(!['ادمن','موظف'].contains(_s(row['name_ar'])))&&row['show_at_login']==true});
          if(_isUser||_isPermissions)payload.addAll({'name_ar':_s(row['name_ar']).trim(),'name_en':_s(row['name_en']).trim(),'image_data':row['image_data'],'is_active':row['is_active']==true,'user_type_id':row['user_type_id'],if(_isUser)'has_sub_warehouse':row['has_sub_warehouse']==true});
          if(_isTemplate)payload.addAll({'name_ar':_s(row['name_ar']).trim(),'name_en':_s(row['name_en']).trim(),'image_data':row['image_data'],'is_active':row['is_active']==true});
          if(_s(row['id']).isNotEmpty) {
            await _db!.from(targetTable).update(payload).eq('company_id',_company).eq('id',row['id']);
            final password = _s(row['_password_draft']);
            if (_isUser && password.isNotEmpty) {
              await _db!.rpc('set_erp_user_password', params: {'p_user_id': row['id'], 'p_password': password});
              row['_password_draft'] = '';
            }
          }
        }
        if(_isTemplate && _selectedId!=null){
          for(final rule in _rules){
            final payload=<String,dynamic>{'company_id':_company,'template_id':_selectedId,'menu_name':rule['menu_name'],'submenu_name':rule['submenu_name']??'','page_name':rule['page_name']};
            for(final field in _userAdminActionFields.values)payload[field]=rule[field]==true;
            await _db!.from('erp_permission_template_rules').upsert(payload,onConflict:'template_id,menu_name,submenu_name,page_name');
          }
        }
        if(_isPermissions){
          for(final rule in _rules){
            final uid=_s(rule['user_id']);
            if(uid.isEmpty)continue;
            final payload=<String,dynamic>{'company_id':_company,'user_id':uid,'menu_name':rule['menu_name'],'submenu_name':rule['submenu_name']??'','page_name':rule['page_name']};
            for(final field in _userAdminActionFields.values)payload[field]=rule[field]==true;
            await _db!.from('erp_user_permission_matrix').upsert(payload,onConflict:'user_id,menu_name,submenu_name,page_name');
          }
        }
      }
      if(mounted)setState(()=>_message='تم حفظ التغييرات في قاعدة البيانات.');
      if(mounted)setState(()=>_editMode=false);
      await _load();
    } catch(e){if(mounted)setState(()=>_error='تعذر الحفظ: $e');}
    finally{if(mounted)setState(()=>_saving=false);}
  }

  Future<void> _delete() async {
    if(!_editMode){setState(()=>_error='اضغط «تعديل» أولًا قبل حذف البيانات.');return;}
    if(_isPermissions){
      if(_selectedUserId==null){setState(()=>_error='اختر مستخدمًا أولًا.');return;}
      final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('مسح صلاحيات المستخدم'),content:const Text('سيتم حذف مصفوفة صلاحيات المستخدم المحدد فقط، ولن يتم حذف حسابه. هل تريد المتابعة؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('نعم، امسح الصلاحيات'))]));
      if(ok!=true)return;
      try{await _db!.from('erp_user_permission_matrix').delete().eq('company_id',_company).eq('user_id',_selectedUserId!);await _loadUserRules();if(mounted)setState(()=>_message='تم مسح صلاحيات المستخدم المحدد.');}catch(e){if(mounted)setState(()=>_error='تعذر مسح الصلاحيات: $e');}
      return;
    }
    if(_selectedId==null){setState(()=>_error='حدد سجلًا من الجدول أولًا.');return;}
    if (_isType && _rows.any((row) => _s(row['id']) == _selectedId && row['_local_default'] == true)) {
      setState(() => _error = 'لا يمكن حذف صف افتراضي للمعاينة؛ لم يُحفظ هذا الصف في قاعدة البيانات.');
      return;
    }
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد الحذف'),content:const Text('هل تريد حذف السجل المحدد؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('نعم، احذف'))]));
    if(ok!=true)return;
    try{await _db!.from(_table).delete().eq('company_id',_company).eq('id',_selectedId!);setState(()=>_selectedId=null);await _load();if(mounted)setState(()=>_message='تم حذف السجل المحدد.');}
    catch(e){if(mounted)setState(()=>_error='تعذر حذف السجل: $e');}
  }

  Future<void> _chooseImage(Map<String,dynamic> row) async {
    final source=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('استيراد صورة'),onTap:()=>Navigator.pop(c,'gallery')),
      ListTile(leading:const Icon(Icons.photo_camera_outlined),title:const Text('التقاط صورة'),onTap:()=>Navigator.pop(c,'camera')),
      if(row['image_data']!=null)ListTile(leading:const Icon(Icons.delete_outline),title:const Text('إزالة الصورة'),onTap:()=>Navigator.pop(c,'remove')),
    ])));
    if(source==null)return;
    if(source=='remove'){setState(()=>row['image_data']=null);return;}
    try{
      Uint8List? bytes;
      if(source=='camera'){final file=await _picker.pickImage(source:ImageSource.camera,imageQuality:75,maxWidth:900);if(file!=null)bytes=await file.readAsBytes();}
      else {final result=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);if(result!=null&&result.files.isNotEmpty)bytes=result.files.single.bytes;}
      if(bytes!=null&&mounted)setState(()=>row['image_data']=base64Encode(bytes!));
    }catch(e){if(mounted)setState(()=>_error='تعذر تحميل الصورة: $e');}
  }

  Future<void> _openMenuPicker({required String parentId,required bool template}) async {
    final selected=<String>{};
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,refresh)=>AlertDialog(
      title:const Text('جلب قوائم النظام'),
      content:SizedBox(width:680,height:520,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        for(final menu in _userAdminTree.entries)
          ExpansionTile(title:Text(menu.key,style:const TextStyle(fontWeight:FontWeight.w900,color:_userAdminPurple)),children:[
            for(final sub in menu.value.entries)
              ExpansionTile(tilePadding:const EdgeInsetsDirectional.only(start:18,end:8),title:Text(sub.key,style:const TextStyle(fontWeight:FontWeight.w700)),children:[
                for(final page in sub.value)
                  CheckboxListTile(dense:true,contentPadding:const EdgeInsetsDirectional.only(start:28,end:8),title:Text(page),value:selected.contains('${menu.key}|${sub.key}|${page}'),onChanged:(v)=>refresh(()=>v==true?selected.add('${menu.key}|${sub.key}|${page}'):selected.remove('${menu.key}|${sub.key}|${page}')),
                  ),
              ]),
          ]),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إضافة القوائم المحددة'))],
    )));
    if(selected.isEmpty||!mounted)return;
    if(template && _selectedId!=parentId){setState(()=>_selectedId=parentId);await _loadRules();}
    if(!template && _selectedUserId!=parentId){setState(()=>_selectedUserId=parentId);await _loadUserRules();}
    final relevantRules=template?_rules:_rules.where((r)=>_s(r['user_id'])==parentId).toList();
    final existing=relevantRules.map((r)=>'${r['menu_name']}|${r['submenu_name']}|${r['page_name']}').toSet();
    setState((){
      for(final key in selected){
        if(existing.contains(key))continue;
        final parts=key.split('|');
        _rules.add({'menu_name':parts[0],'submenu_name':parts[1],'page_name':parts[2],if(!template)'user_id':parentId,for(final field in _userAdminActionFields.values)field:false});
      }
    });
    setState(()=>_message='تم جلب القوائم المحددة. اضغط حفظ لتثبيتها.');
  }

  Future<void> _importExcel() async {
    try{
      final file=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['xlsx','xls'],withData:true);
      if(file==null||file.files.isEmpty||file.files.single.bytes==null)return;
      final book=excel.Excel.decodeBytes(file.files.single.bytes!);
      final sheets=book.tables.values.where((s)=>s.maxRows>0);
      if(sheets.isEmpty)throw StateError('الملف لا يحتوي على بيانات.');
      final rows=sheets.first.rows;
      if(_isPermissions)throw StateError('استيراد Excel متاح لسجلات الأنواع والمستخدمين والقوالب، وليس لمصفوفة الصلاحيات.');
      for(final row in rows.skip(1)){
        if(row.length<2)continue;
        final ar=row[0]?.value?.toString().trim()??'';
        final en=row[1]?.value?.toString().trim()??'';
        if(ar.isEmpty)continue;
        final payload=<String,dynamic>{'company_id':_company,'name_ar':ar,'name_en':en,'is_active':true};
        if(_isType)payload['show_at_login']=false;
        if(_isUser&&_types.isNotEmpty)payload['user_type_id']=_types.first['id'];
        if(_isType||_isUser||_isTemplate)await _db!.from(_table).insert(payload);
      }
      await _load();if(mounted)setState(()=>_message='تم استيراد البيانات من Excel.');
    }catch(e){if(mounted)setState(()=>_error='تعذر الاستيراد: $e');}
  }

  Future<void> _printPdf() async {
    try{
      final doc=pw.Document();
      doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4.landscape,build:(context)=>[
        pw.Text('سلسلة — ${_typeNames[_view]}',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:12),
        pw.Table(border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),children:[
          pw.TableRow(children:['م','الكود','الاسم العربي','الاسم الإنجليزي','الحالة'].map((x)=>pw.Padding(padding:const pw.EdgeInsets.all(6),child:pw.Text(x))).toList()),
          for(var i=0;i<_rows.length;i++)pw.TableRow(children:[
            '${i+1}',_s(_rows[i][_isType?'type_code':_isUser?'user_code':'template_code']),_s(_rows[i]['name_ar']),_s(_rows[i]['name_en']),_rows[i]['is_active']==true?'نشط':'غير نشط'
          ].map((x)=>pw.Padding(padding:const pw.EdgeInsets.all(5),child:pw.Text(x,style:const pw.TextStyle(fontSize:9)))).toList()),
        ]),
      ]));
      await Printing.layoutPdf(onLayout:(_)=>doc.save());
    }catch(e){if(mounted)setState(()=>_error='تعذرت الطباعة: $e');}
  }

  Future<void> _preview() async {
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('معاينة — ${_typeNames[_view]}'),content:SizedBox(width:700,child:Text('عدد السجلات: ${_rows.length}\n\n'+_rows.take(12).map((r)=>'${_s(r['name_ar'])} — ${_s(r['name_en'])}').join('\n'))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إغلاق'))]));
  }

Widget _toolbar() => Container(
  color: _userAdminCanvas,
  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _taskButton('تحديث', Icons.refresh_rounded, _loading ? null : _load),
      _taskButton('إضافة', Icons.add_circle_outline_rounded, _saving ? null : _add),
      _taskButton('حفظ', Icons.save_outlined, _saving ? null : _save),
      _taskButton('تعديل', Icons.edit_outlined, _saving || _editMode ? null : () => setState(() => _editMode = true)),
      _taskButton('حذف', Icons.delete_outline_rounded, _saving ? null : _delete),
      _taskButton('معاينة', Icons.preview_outlined, _preview),
      _taskButton('طباعة', Icons.print_outlined, _printPdf),
      _taskButton('استيراد Excel', Icons.file_upload_outlined, _importExcel),
      _taskButton('طباعة PDF', Icons.picture_as_pdf_outlined, _printPdf),
    ]),
  ),
);

Widget _taskButton(String label, IconData icon, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, compact: true);

  Widget _imageCell(Map<String,dynamic> row){
    final raw=_s(row['image_data']);
    return Row(mainAxisSize:MainAxisSize.min,children:[
      if(raw.isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(5),child:Image.memory(base64Decode(raw),width:30,height:30,fit:BoxFit.cover))
      else const Icon(Icons.image_outlined,size:22,color:Colors.black38),
      IconButton(tooltip:'استيراد صورة أو تصوير',visualDensity:VisualDensity.compact,onPressed:_editMode?()=>_chooseImage(row):null,icon:const Icon(Icons.add_a_photo_outlined,size:18,color:_userAdminPurple)),
    ]);
  }
  Widget _textCell(Map<String,dynamic> row,String field,{double width=145})=>SizedBox(width:width,child:TextFormField(
    key:ValueKey('${row['id']}-$field-${row[field]}-$_editMode'),initialValue:_s(row[field]),enabled:_editMode,
    decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:7,vertical:8),border:OutlineInputBorder()),
    onChanged:(v)=>row[field]=v,
  ));

  Future<void> _openBranchWarehousePicker(String userId) async {
    if (_branches.isEmpty || _warehouses.isEmpty) {
      if(mounted)setState(()=>_error='لا توجد فروع أو مخازن نشطة متاحة. أضف الفروع والمخازن أولًا ثم أعد المحاولة.');
      return;
    }
    try {
      final existing = await _db!.from('erp_user_branch_warehouse_access').select().eq('company_id',_company).eq('user_id',userId);
      final current = (existing as List).map((x)=>Map<String,dynamic>.from(x)).toList();
      final selected = <String>{for(final x in current.where((x)=>x['is_allowed']==true)) '${x['branch_id']}|${x['warehouse_id']}'};
      String? primary = current.where((x)=>x['is_default']==true).map((x)=>'${x['branch_id']}|${x['warehouse_id']}').firstOrNull;
      final picked = await showDialog<Map<String,dynamic>>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setDialogState)=>AlertDialog(
        title:const Text('الفروع والمخازن المسموح بها'),
        content:SizedBox(width:650,height:460,child:Column(children:[
          const Text('حدد الفروع والمخازن المسموح بها، ثم اختر مخزنًا افتراضيًا واحدًا لاستخدامه تلقائيًا في الحركات.',style:TextStyle(fontSize:12)),
          Expanded(child:ListView(children:[
            for(final branch in _branches) ...[
              Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Text(_s(branch['branch_name']),style:const TextStyle(fontWeight:FontWeight.w800,color:_userAdminPurple))),
              for(final warehouse in _warehouses.where((w)=>w['branch_id']==branch['id']))
                Builder(builder:(context){
                  final key='${branch['id']}|${warehouse['id']}';
                  final enabled=selected.contains(key);
                  return Row(children:[
                    Checkbox(value:enabled,onChanged:(v)=>setDialogState((){
                      if(v==true)selected.add(key);else{selected.remove(key);if(primary==key)primary=null;}
                    })),
                    Expanded(child:Text(_s(warehouse['warehouse_name']))),
                    Radio<String>(value:key,groupValue:primary,onChanged:enabled?(v)=>setDialogState(()=>primary=v):null),
                    const Text('افتراضي',style:TextStyle(fontSize:11)),
                  ]);
                }),
            ]
          ])),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),
          FilledButton(onPressed:(){
            if(primary!=null&&!selected.contains(primary)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المخزن الافتراضي يجب أن يكون ضمن المخازن المسموح بها.')));return;}
            Navigator.pop(dialogContext,{'allowed':selected.toList(),'default':primary});
          },child:const Text('حفظ الاختيارات')),
        ],
      )));
      if(picked==null)return;
      final keys=(picked['allowed'] as List).cast<String>();
      final defaultKey=picked['default'] as String?;
      await _db!.from('erp_user_branch_warehouse_access').delete().eq('company_id',_company).eq('user_id',userId);
      for(final key in keys){
        final parts=key.split('|');
        await _db!.from('erp_user_branch_warehouse_access').insert({'company_id':_company,'user_id':userId,'branch_id':parts[0],'warehouse_id':parts[1],'is_allowed':true,'is_default':key==defaultKey});
      }
      if(mounted)setState(()=>_message='تم حفظ صلاحيات الفروع والمخازن والمخزن الافتراضي.');
    }catch(e){if(mounted)setState(()=>_error='تعذر حفظ صلاحيات الفروع والمخازن: $e');}
  }

  Widget _masterGrid(){
    final codeField=_isType?'type_code':_isUser?'user_code':'template_code';
    return SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      headingRowHeight: 57,dataRowMinHeight: 57,dataRowMaxHeight: 57,horizontalMargin:8,columnSpacing:12,
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF0E8F8)),
      columns:[
        const DataColumn(label:Text('م')),DataColumn(label:Text(_isType?'كود النوع':_isUser?'كود المستخدم':'كود القالب')),
        if(!_isUser)const DataColumn(label:Text('اسم عربي')),if(!_isUser)const DataColumn(label:Text('اسم إنجليزي')),if(_isUser)const DataColumn(label:Text('اسم المستخدم')),if(_isUser)const DataColumn(label:Text('كلمة المرور')),
        if(_isUser)const DataColumn(label:Text('نوع المستخدم')),
        if(!_isUser)const DataColumn(label:Text('الصورة')),const DataColumn(label:Text('نشط')),if(_isUser)const DataColumn(label:Text('له خزينة فرعية')),if(_isUser)const DataColumn(label:Text('الفروع والمخازن')),
        if(_isType)const DataColumn(label:Text('يظهر للدخول')),
        if(_isTemplate)const DataColumn(label:Text('قوائم وصلاحيات')),
      ],
      rows:List.generate(_rows.length,(i){
        final row=_rows[i];final id=_s(row['id']);
        return DataRow(selected:id==_selectedId,onSelectChanged:(v)async{setState(()=>_selectedId=v==true?id:null);if(v==true&&_isTemplate)await _loadRules();},cells:[
          DataCell(Text('${i+1}')),DataCell(Text(_s(row[codeField]))),
          if(!_isUser)DataCell(_textCell(row,'name_ar')),if(!_isUser)DataCell(_textCell(row,'name_en')),
          if(_isUser)DataCell(_textCell(row,'name_ar',width:165)),
          if(_isUser)DataCell(SizedBox(width:185,child:Row(children:[Expanded(child:TextFormField(initialValue:_s(row['_password_draft']),obscureText:row['_password_visible']!=true,decoration:const InputDecoration(hintText:'كلمة مرور جديدة',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:7),border:OutlineInputBorder()),onChanged:(v)=>row['_password_draft']=v)),IconButton(tooltip:'إظهار/إخفاء كلمة المرور',visualDensity:VisualDensity.compact,onPressed:()=>setState(()=>row['_password_visible']=row['_password_visible']!=true),icon:Icon(row['_password_visible']==true?Icons.visibility_off:Icons.visibility,size:18))]))),
          if(_isUser)DataCell(SizedBox(width:155,child:DropdownButtonFormField<String>(
            key:ValueKey('${id}-type-${row['user_type_id']}'),value:_types.any((t)=>_s(t['id'])==_s(row['user_type_id']))?_s(row['user_type_id']):null,isExpanded:true,
            decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:5),border:OutlineInputBorder()),
            items:_types.map((t)=>DropdownMenuItem(value:_s(t['id']),child:Text(_s(t['name_ar']),overflow:TextOverflow.ellipsis))).toList(),
            onChanged:_editMode?(v)=>setState(()=>row['user_type_id']=v):null,
          ))),
          if(!_isUser)DataCell(_imageCell(row)),
          DataCell(Checkbox(value:row['is_active']==true,onChanged:_editMode?(v)=>setState(()=>row['is_active']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
          if(_isUser)DataCell(Checkbox(value:row['has_sub_warehouse']==true,onChanged:_editMode?(v)=>setState(()=>row['has_sub_warehouse']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
          if(_isUser)DataCell(OutlinedButton.icon(onPressed:()=>_openBranchWarehousePicker(id),icon:const Icon(Icons.add_location_alt_outlined,size:16),label:const Text('+ فروع'))),
          if(_isType)DataCell(Checkbox(value:!['ادمن','موظف'].contains(_s(row['name_ar']))&&row['show_at_login']==true,onChanged:_editMode&&!['ادمن','موظف'].contains(_s(row['name_ar']))?(v)=>setState(()=>row['show_at_login']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
          if(_isTemplate)DataCell(OutlinedButton.icon(onPressed:()async{setState(()=>_selectedId=id);await _loadRules();await _openMenuPicker(parentId:id,template:true);},icon:const Icon(Icons.drive_file_move_outlined,size:16),label:const Text('جلب قوائم'))),
        ]);
      }),
    ));
  }

  List<Map<String,String>> get _permissionPages => [
    for(final menu in _userAdminTree.entries)
      for(final sub in menu.value.entries)
        for(final page in sub.value)
          {'key':'${menu.key}|${sub.key}|${page}','label':'${menu.key} › ${sub.key} › ${page}'}
  ];

  Map<String,dynamic>? _userRuleFor(String userId) {
    for(final rule in _rules){
      if(_s(rule['user_id'])==userId &&
        '${rule['menu_name']}|${rule['submenu_name']}|${rule['page_name']}'==_selectedPageKey) return rule;
    }
    return null;
  }

  void _setUserPermission(Map<String,dynamic> user,String field,bool value) {
    final uid=_s(user['id']);
    var rule=_userRuleFor(uid);
    if(rule==null){
      final parts=_selectedPageKey.split('|');
      rule={'company_id':_company,'user_id':uid,'menu_name':parts[0],'submenu_name':parts[1],'page_name':parts[2],
        for(final name in _userAdminActionFields.values)name:false};
      _rules.add(rule);
    }
    setState(()=>rule![field]=value);
  }

  Widget _ruleGrid(){
    if(_isPermissions)return _permissionUsersGrid();
    final parentId=_selectedId;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:DropdownButtonFormField<String>(
          key:ValueKey('permission-parent-$parentId-template'),
          value:parentId,
          decoration:const InputDecoration(isDense:true,labelText:'القالب المحدد'),
          items:_rows.map((r)=>DropdownMenuItem(value:_s(r['id']),child:Text(_s(r['name_ar']),overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v)async{setState(()=>_selectedId=v);if(v!=null)await _loadRules();},
        )),
        const SizedBox(width:8),
        OutlinedButton.icon(onPressed:parentId==null?null:()=>_openMenuPicker(parentId:parentId,template:true),icon:const Icon(Icons.account_tree_outlined),label:const Text('جلب قوائم (F1)')),
      ]),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        headingRowHeight: 57,dataRowMinHeight: 57,dataRowMaxHeight: 57,horizontalMargin:7,columnSpacing:8,
        columns:[const DataColumn(label:Text('القائمة الرئيسية / الفرعية / الشاشة')),for(final action in _userAdminActions)DataColumn(label:SizedBox(width:80,child:Text(action,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))))],
        rows:_rules.map((rule)=>DataRow(cells:[
          DataCell(SizedBox(width:250,child:Text('${rule['menu_name']} › ${rule['submenu_name']} › ${rule['page_name']}',maxLines:2,overflow:TextOverflow.ellipsis))),
          for(final field in _userAdminActionFields.values)DataCell(Center(child:Checkbox(value:rule[field]==true,onChanged:_editMode?(v)=>setState(()=>rule[field]=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple))),
        ])).toList(),
      )),
    ]);
  }

  Widget _permissionUsersGrid(){
    final pages=_permissionPages;
    final pageValue=pages.any((p)=>p['key']==_selectedPageKey)?_selectedPageKey:(pages.isEmpty?null:pages.first['key']);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.start,children:[
        SizedBox(width:340,child:DropdownButtonFormField<String>(
          key:ValueKey('permission-page-$pageValue'),
          value:pageValue,
          isExpanded:true,
          decoration:const InputDecoration(labelText:'القائمة / الشاشة المطلوب تحديد صلاحياتها',isDense:true),
          items:pages.map((p)=>DropdownMenuItem(value:p['key'],child:Text(p['label']!,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v)=>setState(()=>_selectedPageKey=v??_selectedPageKey),
        )),
        OutlinedButton.icon(onPressed:_openUserPicker,icon:const Icon(Icons.person_search),label:const Text('جلب مستخدمين')),
        SizedBox(width:190,child:DropdownButtonFormField<String>(
          key:ValueKey('template-select-$_selectedTemplateId'),
          value:_templates.any((t)=>_s(t['id'])==_selectedTemplateId)?_selectedTemplateId:null,
          decoration:const InputDecoration(labelText:'قالب صلاحيات',isDense:true),
          items:_templates.where((t)=>t['is_active']==true).map((t)=>DropdownMenuItem(value:_s(t['id']),child:Text(_s(t['name_ar']),overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v)=>setState(()=>_selectedTemplateId=v),
        )),
        OutlinedButton.icon(onPressed:_selectedUserId==null||_selectedTemplateId==null?null:_applyTemplate,icon:const Icon(Icons.playlist_add_check),label:const Text('تطبيق القالب')),
      ]),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        headingRowHeight: 57,dataRowMinHeight: 57,dataRowMaxHeight: 57,horizontalMargin:7,columnSpacing:9,
        columns:[
          const DataColumn(label:Text('م')),
          const DataColumn(label:Text('كود المستخدم')),
          const DataColumn(label:Text('اسم المستخدم عربي')),
          const DataColumn(label:Text('اسم المستخدم إنجليزي')),
          const DataColumn(label:Text('نوع المستخدم')),
          const DataColumn(label:Text('الصورة')),
          const DataColumn(label:Text('نشط')),
          for(final action in _userAdminActions)DataColumn(label:SizedBox(width:82,child:Text(action,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)))),
        ],
        rows:List.generate(_users.length,(i){
          final user=_users[i];final uid=_s(user['id']);final rule=_userRuleFor(uid);
          return DataRow(selected:uid==_selectedUserId,onSelectChanged:(v)=>setState(()=>_selectedUserId=v==true?uid:null),cells:[
            DataCell(Text('${i+1}')),
            DataCell(Text(_s(user['user_code']))),
            DataCell(_textCell(user,'name_ar')),
            DataCell(_textCell(user,'name_en')),
            DataCell(SizedBox(width:150,child:DropdownButtonFormField<String>(
              key:ValueKey('${uid}-permission-type-${user['user_type_id']}'),
              value:_types.any((t)=>_s(t['id'])==_s(user['user_type_id']))?_s(user['user_type_id']):null,
              isExpanded:true,decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:5),border:OutlineInputBorder()),
              items:_types.map((t)=>DropdownMenuItem(value:_s(t['id']),child:Text(_s(t['name_ar']),overflow:TextOverflow.ellipsis))).toList(),
              onChanged:_editMode?(v)=>setState(()=>user['user_type_id']=v):null,
            ))),
            DataCell(_imageCell(user)),
            DataCell(Checkbox(value:user['is_active']==true,onChanged:_editMode?(v)=>setState(()=>user['is_active']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
            for(final field in _userAdminActionFields.values)DataCell(Center(child:Checkbox(value:rule?[field]==true,onChanged:(v)=>_setUserPermission(user,field,v==true),visualDensity:VisualDensity.compact,activeColor:_userAdminPurple))),
          ]);
        }),
      )),
    ]);
  }

  @override Widget build(BuildContext context){
    ErpKeyboardNavigation.registerActions(add: _add, save: _save);
    final title=_typeNames[_view]??'المستخدمين';
    return Focus(autofocus:true,onKeyEvent:(node,event){
      if(event is KeyDownEvent && event.logicalKey==LogicalKeyboardKey.f1){
        if(_isTemplate && _selectedId!=null){_openMenuPicker(parentId:_selectedId!,template:true);return KeyEventResult.handled;}
        if(_isPermissions && _selectedUserId!=null){_openMenuPicker(parentId:_selectedUserId!,template:false);return KeyEventResult.handled;}
        if(_isUser && _selectedId!=null){_openBranchWarehousePicker(_selectedId!);return KeyEventResult.handled;}
      }
      return KeyEventResult.ignored;
    },child:Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),child:Row(children:[
        const Icon(Icons.admin_panel_settings_outlined,color:_userAdminPurple,size:27),const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_userAdminPurple)),Text('إدارة البيانات والصلاحيات للشركة الحالية',style:TextStyle(fontSize:11,color:Colors.grey.shade700))])),
      ])),
      _toolbar(),
      if(_error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_error!,style:const TextStyle(color:Colors.red))),
      if(_message!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_message!,style:const TextStyle(color:Colors.green))),
      if(_isPermissions)Padding(padding:const EdgeInsets.all(8),child:Text('حدد المستخدم ثم عيّن صلاحيات كل شاشة باستخدام أعمدة المهام التسعة. زر جلب المستخدمين يتيح الاختيار من القائمة.',style:TextStyle(color:Colors.grey.shade700))),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(_isPermissions) _ruleGrid() else if(_isTemplate) ...[_masterGrid(),const SizedBox(height:12),_ruleGrid()] else _masterGrid(),

      ]))))),
    ])));
  }

  Future<void> _applyTemplate() async {
    if(_selectedUserId==null||_selectedTemplateId==null)return;
    try{
      final source=await _db!.from('erp_permission_template_rules').select().eq('company_id',_company).eq('template_id',_selectedTemplateId!);
      for(final item in (source as List).whereType<Map<String,dynamic>>()){
        final payload=<String,dynamic>{'company_id':_company,'user_id':_selectedUserId,'menu_name':item['menu_name'],'submenu_name':item['submenu_name']??'','page_name':item['page_name']};
        for(final field in _userAdminActionFields.values)payload[field]=item[field]==true;
        await _db!.from('erp_user_permission_matrix').upsert(payload,onConflict:'user_id,menu_name,submenu_name,page_name');
      }
      await _loadUserRules();
      if(mounted)setState(()=>_message='تم تطبيق قالب الصلاحيات على المستخدم المحدد.');
    }catch(e){if(mounted)setState(()=>_error='تعذر تطبيق القالب: $e');}
  }

  Future<void> _openUserPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('جلب مستخدمين'),
        content: SizedBox(
          width: 500,
          child: ListView(
            shrinkWrap: true,
            children: _users.map((user) => ListTile(
              title: Text(_s(user['name_ar'])),
              subtitle: Text(_s(user['name_en'])),
              selected: _s(user['id']) == _selectedUserId,
              onTap: () => Navigator.pop(dialogContext, _s(user['id'])),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
    if (selected != null) {
      setState(() => _selectedUserId = selected);
      await _loadUserRules();
    }
  }
}
