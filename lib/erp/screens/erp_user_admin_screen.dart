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
import 'erp_user_classifications_screen.dart';

const _userAdminPurple = Color(0xFF3E007D);
const _userAdminCanvas = Color(0xFFF7F5FA);
const _userAdminActions = <String>['مسموح','تحديث','إضافة','حفظ','تعديل','حذف','معاينة','طباعة','Excel','PDF'];
const _userAdminActionFields = <String,String>{
  'مسموح':'can_access','تحديث':'can_refresh','إضافة':'can_add','حفظ':'can_save','تعديل':'can_edit','حذف':'can_delete',
  'معاينة':'can_preview','طباعة':'can_print','Excel':'can_import_excel','PDF':'can_print_pdf',
};
const _userAdminTree = <String,Map<String,List<String>>>{
  'إعدادات عامة':{
    'بيانات أساسية':['بيانات الشركة','مراكز التكلفة','بيانات جغرافية','أنواع الأنشطة','المستخدمين','سياسات البرنامج','سجل العمليات','واجهة API والربط الخارجي','إدارة مفاتيح API','سجلات التكامل والطلبات','سياسات التسعير والخصومات','توزيع الأصناف على المندوبين','قيود البيع والشراء'],
    'حركات':['اختبار ومراجعة الحركات','قائمة اعتماد القيود','إدارة الجلسات','سجل الدخول والخروج','النسخ الاحتياطي','مسح جميع البيانات','إعداد نقاط الربط','اختبار الاتصال الخارجي'],
    'تقارير':['تقرير المستخدمين','تقرير نشاط النظام','تقرير استهلاك API','تقرير أخطاء التكامل'],
  },
  'إدارة تطبيقات':{
    'بيانات أساسية':['إعدادات هوية التطبيق','إدارة الشعار والصور','إدارة ألوان التطبيقات','إدارة صلاحيات التطبيقات','إدارة إعلانات التطبيق','إدارة صور الأصناف والفئات','إدارة صور الموردين والعملاء','إدارة شركات الشحن','إعدادات عامة للتطبيقات'],
    'حركات':['مراجعة طلبات تعديل التطبيقات','سجل تغييرات الهوية','إدارة إصدارات التطبيقات'],
    'تقارير':['تقرير التطبيقات','تقرير الصلاحيات','تقرير تغييرات الإعدادات'],
  },
  'حسابات مالية':{
    'بيانات أساسية':['شجرة الحسابات','الفترات المالية','مراكز التكلفة','العملات','الخزائن الرئيسية والفرعية','الحسابات البنكية','خريطة الحسابات التشغيلية','طرق الدفع','لوحات المؤشرات','قوالب التقارير'],
    'حركات':['قيود اليومية','سندات القبض','سندات الصرف','تسويات الحسابات','إقفال الفترة','تحويل بين الخزائن','إيداع بنكي','سحب بنكي','مطابقة البنك','تحديث مؤشرات الأداء','تصدير البيانات'],
    'تقارير':['ميزان المراجعة','الأستاذ العام','قائمة الدخل','الميزانية العمومية','حركة حساب','أرصدة الخزائن','كشف حساب خزينة','كشف حساب بنك','مؤشرات الأداء الرئيسية','التدفقات النقدية','تحليل الربحية','حركة المبيعات والمخزون','ملخص تنفيذي'],
  },
  'مخازن':{
    'بيانات أساسية':['دليل المخازن والفروع','فئات الأصناف','دليل الأصناف','وحدات الأصناف','الباركود','حدود إعادة الطلب','قواعد إعادة الطلب والتنبيه','بيانات جغرافية'],
    'حركات':['إذن إضافة','إذن صرف','تحويل مخزني','تسوية جرد','جرد فعلي','محاضر الجرد ومراجعة الفروق','تسوية صلاحية وهالك','تحويلات بين الفروع','تسويات الفروع','توزيع المصروفات','جامع صور الأصناف','استيراد بيانات اصناف','تنزيل بيانات أصناف'],
    'تقارير':['أرصدة الأصناف','كارت الصنف','الجرد والفروق','الأصناف الراكدة','الأصناف قاربت على النفاد','تنبيهات إعادة الطلب','تواريخ الصلاحية','تنبيهات قرب انتهاء الصلاحية','أرصدة التشغيلات','أداء الفروع','أرباح وخسائر الفروع','حركة التحويلات'],
  },
  'مشتريات':{
    'بيانات أساسية':['سياسات الشراء','قوائم أسعار الموردين','دليل الموردين','تصنيفات الموردين','جهات اتصال الموردين','شروط التوريد'],
    'حركات':['طلب شراء','أمر شراء','استلام مشتريات','فاتورة مشتريات','مرتجع مشتريات','مؤجلات وعمولات الموردين','كشف حساب مورد','تقييم مورد','مطابقة أرصدة الموردين','تسجيل مديونية مورد'],
    'تقارير':['تحليل المشتريات','مقارنة أسعار الموردين','أعمار ديون الموردين','أرصدة الموردين','أداء الموردين','الموردون حسب النشاط'],
  },
  'مبيعات':{
    'بيانات أساسية':['قوائم أسعار البيع','سياسات الخصم','مناطق التوزيع','خطوط السير','دليل العملاء','تصنيفات العملاء','فروع العملاء','حدود الائتمان','مناطق العملاء','دليل المندوبين','مركبات التوزيع','قاعدة العملاء المحتملين','أهداف العملاء الشهرية','عمولات المندوبين','خطط العمولة'],
    'حركات':['عروض الأصناف','عرض سعر','أمر بيع','فاتورة مبيعات','مرتجع مبيعات','إذن التجهيز','إذن التسليم','كشف حساب عميل','تحصيلات العملاء','متابعة المديونيات','طلبات العملاء','تسليم عهدة مندوب','تصفية عهدة مندوب','تحصيل نقدي','مصروفات رحلة','مسودات العمولات'],
    'تقارير':['المبيعات اليومية','ربحية المبيعات','مبيعات حسب الفرع','أداء المندوبين','الطلبات المتأخرة','تحقيق أهداف العملاء','تقرير العمولات المستحقة','أرصدة العملاء','أعمار الديون','أفضل العملاء','العملاء المتوقفون','تصفية المندوبين','تحصيلات يومية','تكلفة خطوط السير'],
  },
  'موارد بشرية':{
    'بيانات أساسية':['الهيكل الوظيفي','الإدارات والأقسام','الوظائف والدرجات','ملف الموظف','العقود','أنواع الإجازات','قواعد الورديات والحضور والانصراف','أجهزة البصمة وربط الحضور','مكونات الراتب','الاستحقاقات والاستقطاعات','سياسات العمولة'],
    'حركات':['الحضور والانصراف','الإجازات والأذونات','الجزاءات والمكافآت','السلف','تقييم الأداء','مسير الرواتب','صرف الرواتب','عمولات المبيعات','تسوية سلفة'],
    'تقارير':['كشف العاملين','الحضور والغياب','رصيد الإجازات','انتهاء العقود','ملخص الرواتب','مفردات المرتب','عمولات المندوبين'],
  },
  'علاقات عملاء':{
    'بيانات أساسية':['الحملات التسويقية','قواعد العروض','شرائح العملاء','أنواع الطلبات','قنوات التواصل','أسباب الشكاوى'],
    'حركات':['إنشاء عرض','اعتماد حملة','تسجيل كوبون','تذكرة دعم جديدة','متابعة شكوى','تسجيل اقتراح'],
    'تقارير':['أداء العروض','تكلفة الحملات','معدل الاستجابة','التذاكر المفتوحة','زمن الاستجابة','رضا العملاء'],
  },
  'فاتورة إلكترونية':{
    'بيانات أساسية':['إعدادات الربط الضريبي','بيانات الممول والتوقيع الإلكتروني','تكويد السلع والخدمات'],
    'حركات':['لوحة الفاتورة الإلكترونية','فواتير إلكترونية صادرة','فواتير إلكترونية واردة','إشعارات دائنة إلكترونية','إشعارات مدينة إلكترونية','إرسال المستندات للضرائب','متابعة حالات الإرسال','إلغاء المستندات','رفض المستندات الواردة','قبول أو رفض طلبات الإلغاء','قبول أو رفض طلبات الرفض','البحث عن مستند ضريبي','المستندات الضريبية الحديثة','تفاصيل المستند والتحقق','طباعة الفاتورة الضريبية PDF','طلبات حزم المستندات','تنزيل حزم المستندات','إشعارات منظومة الضرائب','سجل عمليات التكامل','اختبار الاتصال الضريبي'],
    'تقارير':['تقارير الفاتورة الإلكترونية'],
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
  List<Map<String,dynamic>> _branches = [], _warehouses = [], _employees = [];
  String? _selectedTemplateId;
  String? _selectedNodeKind;
  String _viewMode = 'tree';
  bool _permissionAllUsers = true;
  String _permissionMode = 'template';
  final Set<String> _permissionSelectedUserIds = <String>{};
  final Set<String> _expandedHierarchyNodes = <String>{};
  final TextEditingController _hierarchySearchController = TextEditingController();
  String _hierarchySearch = '';
  String? _activeCompanyId;
  String _selectedPageKey = 'إعدادات عامة|بيانات أساسية|بيانات الشركة';
  static const _typeNames = <String,String>{
    'types':'أنواع المستخدمين','users':'المستخدمين','hierarchy':'احتياطي شاشة المستخدمين','classifications':'المستخدمين','templates':'قوالب صلاحيات المستخدمين','permissions':'صلاحيات المستخدمين'
  };

  @override void initState() { super.initState(); _view=widget.initialView; _activeCompanyId=widget.companyId; try {_db=Supabase.instance.client;} catch (_) {} _load(); }
  @override void didUpdateWidget(covariant ErpUserAdminScreen oldWidget) { super.didUpdateWidget(oldWidget); if(oldWidget.companyId!=widget.companyId || oldWidget.initialView!=widget.initialView){_activeCompanyId=widget.companyId;_view=widget.initialView;_load();} }
  @override void dispose() { _hierarchySearchController.dispose(); super.dispose(); }
  String _s(dynamic v) => (v??'').toString();

  String _nextUniqueName(String base, {String field = 'name_ar'}) {
    final used = _rows
        .map((row) => _s(row[field]))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!used.contains(base)) return base;
    var suffix = 2;
    while (used.contains('$base $suffix')) {
      suffix++;
    }
    return '$base $suffix';
  }

  // Always keep the user-types grid visible even if database reads/writes are
  // blocked by company membership or RLS. These rows are preview-only until saved.
  List<Map<String, dynamic>> _localDefaultUserTypes() {
    const defaults = <Map<String, dynamic>>[
      {'name_ar':'ادمن','name_en':'Admin','description':'إدارة النظام والصلاحيات','show_at_login':false},
      {'name_ar':'مورد','name_en':'Supplier','description':'توريد الأصناف والأسعار','show_at_login':true},
      {'name_ar':'عميل','name_en':'Customer','description':'شراء الأصناف ومتابعة الطلبات','show_at_login':true},
      {'name_ar':'شركة شحن','name_en':'Shipping Company','description':'إدارة الشحن والتوصيل','show_at_login':true},
      {'name_ar':'مندوب','name_en':'Sales Representative','description':'البيع والتوزيع والتحصيل','show_at_login':true},
    ];
    return List<Map<String, dynamic>>.generate(defaults.length, (i) => {
      'id': 'local-default-user-type-$i',
      'type_code': i + 1,
      'type_code_display': 'UT${(i + 1).toString().padLeft(4, '0')}',
      ...defaults[i],
      'is_active': true,
      '_local_default': true,
    });
  }
  String get _company => (_activeCompanyId ?? widget.companyId ?? '').trim();
  bool get _isHierarchy => _view=='hierarchy';
  bool get _isType => _view=='types';
  bool get _isUser => _view=='users';
  bool get _isTemplate => _view=='templates';
  bool get _isPermissions => _view=='permissions';
  String get _table => _isType?'erp_user_types':_isUser?'erp_users':'erp_permission_templates';

  Future<void> _load() async {
    if (!mounted) return;
    if (_db == null) {
      setState(() {
        _loading = false;
        _error = 'الاتصال بقاعدة البيانات غير متاح.';
        if (_isType || _isHierarchy) {
          _types = _localDefaultUserTypes();
          _rows = List<Map<String, dynamic>>.from(_types);
          _message = 'الجريد ظاهر بالأنواع الافتراضية للمعاينة، لكن قاعدة البيانات غير متاحة حاليًا.';
        }
      });
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
      String? loadWarning;
      List<Map<String, dynamic>> typeList = [];
      List<Map<String, dynamic>> userList = [];
      List<Map<String, dynamic>> templateList = [];

      if (_isType || _isUser || _isHierarchy || _isPermissions) {
        try {
        final result = await _db!.from('erp_user_types').select().eq('company_id', _company).order('type_code');
        typeList = (result as List).map((x) => Map<String, dynamic>.from(x)).toList();
        const defaults = <Map<String, dynamic>>[
          {'name_ar':'ادمن','name_en':'Admin','description':'إدارة النظام والصلاحيات','show_at_login':false},
          {'name_ar':'مورد','name_en':'Supplier','description':'توريد الأصناف والأسعار','show_at_login':true},
          {'name_ar':'عميل','name_en':'Customer','description':'شراء الأصناف ومتابعة الطلبات','show_at_login':true},
          {'name_ar':'شركة شحن','name_en':'Shipping Company','description':'إدارة الشحن والتوصيل','show_at_login':true},
          {'name_ar':'مندوب','name_en':'Sales Representative','description':'البيع والتوزيع والتحصيل','show_at_login':true},
        ];
        // Repair missing defaults one at a time. A denied/duplicate insert must
        // not abort the whole screen load or hide already-saved rows.
        var seedWarning = false;
        for (final type in defaults) {
          final exists = typeList.any((row) => _s(row['name_ar']) == type['name_ar']);
          if (!exists) {
            try {
              // Idempotent seed: another tab/session may have created this type
              // after the initial read. Ignore the unique (company_id, name_ar)
              // conflict instead of surfacing a failed request in database logs.
              await _db!.from('erp_user_types').upsert(<String,dynamic>{
                ...type, 'company_id':_company, 'is_active':true,
              }, onConflict: 'company_id,name_ar', ignoreDuplicates: true);
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
        const priority = {'ادمن':0,'مورد':1,'عميل':2,'شركة شحن':3,'مندوب':4};
        typeList.sort((a,b) => (priority[_s(a['name_ar'])] ?? 99).compareTo(priority[_s(b['name_ar'])] ?? 99));
        } catch (e) {
          // A type-table/RLS failure must not abort loading the independent users table.
          typeList = _localDefaultUserTypes();
          loadWarning = 'تعذر تحميل أنواع المستخدمين من قاعدة البيانات؛ تظهر الأنواع الافتراضية للمعاينة. تفاصيل الخطأ: $e';
        }
      }
      if (_isUser || _isHierarchy || _isPermissions) {
        // Load users directly; avoid a fragile PostgREST embedded foreign-key relationship.
        try {
          final result = await _db!.from('erp_users').select().eq('company_id', _company);
          userList = (result as List).map((x) => Map<String,dynamic>.from(x)).toList();
        } catch (e) {
          // Keep the screen alive and show the actual data-access failure rather than
          // replacing the entire hierarchy with an empty widget.
          userList = [];
          loadWarning = 'تعذر تحميل المستخدمين من قاعدة البيانات. راجع الشركة النشطة وسياسات RLS. تفاصيل الخطأ: $e';
        }
        // User codes are prefixed strings (USR-1, USR-2, ...); sort by the
        // numeric suffix so USR-10 does not appear before USR-2.
        int codeNumber(Map<String, dynamic> row) {
          final match = RegExp(r'-(\d+)$').firstMatch((row['user_code'] ?? '').toString());
          return int.tryParse(match?.group(1) ?? '') ?? 0;
        }
        userList.sort((a, b) => codeNumber(a).compareTo(codeNumber(b)));
        if (_isUser || _isHierarchy) {
          try {
            final e = await _db!.from('erp_employees').select('id,employee_code,full_name,full_name_en,is_active').eq('company_id', _company).eq('is_active', true).order('employee_code');
            _employees = (e as List).map((x) => Map<String,dynamic>.from(x)).toList();
          } catch (_) { _employees = []; }
          try {
            final b = await _db!.from('erp_branches').select().eq('company_id', _company).eq('is_active', true).order('branch_code');
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
        _rows=_isType?typeList:_isHierarchy?typeList:_isTemplate?templateList:userList;
        if (_selectedId != null && (_isHierarchy ? !typeList.any((r)=>_s(r['id'])==_selectedId) && !userList.any((r)=>_s(r['id'])==_selectedId) : !_rows.any((r)=>_s(r['id'])==_selectedId))) _selectedId=null;
        if (_selectedUserId != null && !userList.any((r)=>_s(r['id'])==_selectedUserId)) _selectedUserId=null;
        if (_selectedUserId==null && userList.isNotEmpty) _selectedUserId=_s(userList.first['id']);
        if (_selectedTemplateId != null && !templateList.any((r)=>_s(r['id'])==_selectedTemplateId)) _selectedTemplateId=null;
        if (_selectedTemplateId==null && templateList.isNotEmpty) _selectedTemplateId=_s(templateList.first['id']);
        _loading=false; _error=loadWarning;
        if ((_isUser || _isHierarchy) && userList.isEmpty && loadWarning == null) _message='لا توجد سجلات مستخدمين محفوظة لهذه الشركة حتى الآن. يمكنك إضافة مستخدم من زر إضافة.';
        if ((_isType || _isHierarchy) && typeList.any((r)=>r['_local_default']==true)) _message='أنواع المستخدمين الافتراضية معروضة في الجدول، لكن تعذر حفظها في قاعدة البيانات بسبب الصلاحيات أو سياسات RLS. يمكنك مراجعة السياسات ثم الضغط على تحديث.';
        if ((_isType || _isHierarchy) && typeList.length < 5) _message='عدد أنواع المستخدمين أقل من 5؛ راجع صلاحيات قاعدة البيانات ثم اضغط تحديث لإكمال الأنواع الناقصة.';
      });
      if (_isTemplate && _selectedId!=null) await _loadRules();
      if (_isPermissions) await _loadUserRules();
    } catch(e) {
      if (mounted) setState(() {
        _loading=false;
        _error='تعذر تحميل بيانات الشاشة: $e';
        if (_isType || _isHierarchy) {
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

  bool _hierarchyMatches(Map<String, dynamic> row, {required bool type}) {
    if (_hierarchySearch.isEmpty) return true;
    final code = _s(row[type ? 'type_code' : 'user_code']).toLowerCase();
    return code.contains(_hierarchySearch) ||
      _s(row['name_ar']).toLowerCase().contains(_hierarchySearch) ||
      _s(row['name_en']).toLowerCase().contains(_hierarchySearch);
  }

  List<Map<String, dynamic>> _usersForType(String typeId) => _users
      .where((u) => _s(u['user_type_id']) == typeId && _s(u['parent_user_id']).isEmpty)
      .toList();

  List<Map<String, dynamic>> _childrenForUser(String userId) => _users
      .where((u) => _s(u['parent_user_id']) == userId)
      .toList();

  bool _typeBranchMatches(Map<String, dynamic> type) {
    if (_hierarchyMatches(type, type: true)) return true;
    for (final user in _users.where((u) => _s(u['user_type_id']) == _s(type['id']))) {
      if (_userBranchMatches(user)) return true;
    }
    return false;
  }

  bool _userBranchMatches(Map<String, dynamic> user) {
    if (_hierarchyMatches(user, type: false)) return true;
    return _childrenForUser(_s(user['id'])).any(_userBranchMatches);
  }

  void _selectHierarchyNode(String kind, Map<String, dynamic> row) {
    setState(() {
      _selectedNodeKind = kind;
      _selectedId = _s(row['id']);
      _selectedUserId = kind == 'user' ? _s(row['id']) : null;
      _message = kind == 'type' ? 'تم تحديد نوع المستخدم.' :
        _s(row['parent_user_id']).isEmpty ? 'تم تحديد المستخدم الرئيسي.' : 'تم تحديد مستخدم فرعي.';
    });
  }

  Future<void> _addHierarchyNode() async {
    if (_db == null || _company.isEmpty) {
      setState(() => _error = 'اتصل بقاعدة البيانات وحدد الشركة قبل الإضافة.');
      return;
    }
    try {
      if (_selectedNodeKind == 'user') {
        final parent = _users.where((u) => _s(u['id']) == _selectedId).firstOrNull;
        if (parent == null) {
          setState(() => _error = 'حدد المستخدم الذي تريد إضافة مستخدم فرعي تحته.');
          return;
        }
        final result = await _db!.from('erp_users').insert({
          'company_id': _company,
          'name_ar': 'مستخدم فرعي جديد',
          'name_en': 'New sub-user',
          'user_type_id': parent['user_type_id'],
          'parent_user_id': parent['id'],
          'is_active': true,
          'has_sub_warehouse': false,
        }).select().single();
        final row = Map<String, dynamic>.from(result);
        setState(() {
          _users.add(row);
          _selectedId = _s(row['id']);
          _selectedNodeKind = 'user';
          _editMode = true;
          _error = null;
          _message = 'تمت إضافة مستخدم فرعي تحت المستخدم المحدد. أكمل بياناته ثم اضغط حفظ.';
        });
      } else if (_selectedNodeKind == 'type') {
        final result = await _db!.from('erp_users').insert({
          'company_id': _company,
          'name_ar': 'مستخدم رئيسي جديد',
          'name_en': 'New primary user',
          'user_type_id': _selectedId,
          'parent_user_id': null,
          'is_active': true,
          'has_sub_warehouse': false,
        }).select().single();
        final row = Map<String, dynamic>.from(result);
        setState(() {
          _users.add(row);
          _selectedId = _s(row['id']);
          _selectedNodeKind = 'user';
          _selectedUserId = _s(row['id']);
          _editMode = true;
          _error = null;
          _message = 'تمت إضافة مستخدم رئيسي تحت نوع المستخدم المحدد.';
        });
      } else {
        final result = await _db!.from('erp_user_types').insert({
          'company_id': _company,
          'name_ar': 'نوع مستخدم جديد',
          'name_en': 'New user type',
          'show_at_login': false,
          'is_active': true,
        }).select().single();
        final row = Map<String, dynamic>.from(result);
        setState(() {
          _types.add(row);
          _selectedId = _s(row['id']);
          _selectedNodeKind = 'type';
          _editMode = true;
          _error = null;
          _message = 'تمت إضافة نوع مستخدم جديد.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذرت إضافة العنصر الهرمي: $e');
    }
  }

  Future<void> _saveHierarchy() async {
    if (!_editMode) {
      setState(() => _error = 'اضغط تعديل أو إضافة أولًا قبل حفظ التغييرات.');
      return;
    }
    if (_types.any((r) => r['_local_default'] == true)) {
      setState(() => _error = 'لا يمكن حفظ الأنواع الافتراضية للمعاينة؛ اضغط تحديث حتى تُحمّل الأنواع المحفوظة من قاعدة البيانات.');
      return;
    }
    if (_saving || _db == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      for (final type in _types) {
        final id = _s(type['id']);
        if (id.isEmpty || type['_local_default'] == true) continue;
        await _db!.from('erp_user_types').update({
          'name_ar': _s(type['name_ar']).trim(),
          'name_en': _s(type['name_en']).trim(),
          'description': _s(type['description']).trim().split(RegExp(r'\s+')).take(10).join(' '),
          'image_data': type['image_data'],
          'is_active': type['is_active'] == true,
          'show_at_login': type['show_at_login'] == true,
        }).eq('company_id', _company).eq('id', id);
      }
      for (final user in _users) {
        final id = _s(user['id']);
        if (id.isEmpty) continue;
        await _db!.from('erp_users').update({
          'name_ar': _s(user['name_ar']).trim(),
          'name_en': _s(user['name_en']).trim(),
          'image_data': user['image_data'],
          'is_active': user['is_active'] == true,
          'user_type_id': user['user_type_id'],
          'parent_user_id': _s(user['parent_user_id']).isEmpty ? null : user['parent_user_id'],
          'has_sub_warehouse': user['has_sub_warehouse'] == true,
        }).eq('company_id', _company).eq('id', id);
        final password = _s(user['_password_draft']);
        if (password.isNotEmpty) {
          await _db!.rpc('set_erp_user_password', params: {'p_user_id': id, 'p_password': password});
          user['_password_draft'] = '';
        }
      }
      if (mounted) setState(() { _editMode = false; _message = 'تم حفظ أنواع المستخدمين والمستخدمين وعلاقاتهم في قاعدة البيانات.'; });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حفظ الهيكل الهرمي للمستخدمين: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteHierarchyNode() async {
    if (_selectedId == null || _selectedNodeKind == null) {
      setState(() => _error = 'حدد نوع مستخدم أو مستخدمًا من الشجرة أولًا.');
      return;
    }
    if (!_editMode) {
      setState(() => _error = 'اضغط تعديل أولًا قبل الحذف.');
      return;
    }
    final isType = _selectedNodeKind == 'type';
    final hasChildren = !isType && _childrenForUser(_selectedId!).isNotEmpty;
    final linkedUsers = isType && _users.any((u) => _s(u['user_type_id']) == _selectedId);
    if (linkedUsers) {
      setState(() => _error = 'لا يمكن حذف نوع المستخدم لأنه مرتبط بمستخدمين. انقل المستخدمين إلى نوع آخر أو احذفهم أولًا.');
      return;
    }
    final prompt = isType
      ? 'سيتم حذف نوع المستخدم المحدد. هل تريد المتابعة؟'
      : hasChildren
        ? 'هذا المستخدم له مستخدمون فرعيون. حذف السجل قد يجعلهم مستخدمين رئيسيين. هل تريد المتابعة؟'
        : 'هل تريد حذف المستخدم المحدد؟';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'), content: Text(prompt),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No / لا')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes / نعم، احذف')),
      ],
    ));
    if (ok != true) return;
    try {
      if (isType) {
        await _db!.from('erp_user_types').delete().eq('company_id', _company).eq('id', _selectedId!);
        _types.removeWhere((t) => _s(t['id']) == _selectedId);
      } else {
        await _db!.from('erp_users').delete().eq('company_id', _company).eq('id', _selectedId!);
        _users.removeWhere((u) => _s(u['id']) == _selectedId);
      }
      setState(() { _selectedId = null; _selectedNodeKind = null; _editMode = false; });
      await _load();
      if (mounted) setState(() => _message = 'تم حذف السجل المحدد.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر الحذف: $e');
    }
  }

  Widget _hierarchyTreeNode(Map<String, dynamic> row, int depth, {required String kind}) {
    final isType = kind == 'type';
    final id = _s(row['id']);
    final nodeKey = '$kind:$id';
    final children = isType
        ? _usersForType(id).where(_userBranchMatches).toList()
        : _childrenForUser(id).where(_userBranchMatches).toList();
    final hasChildren = children.isNotEmpty;
    final expanded = _expandedHierarchyNodes.contains(nodeKey);
    final selected = _selectedNodeKind == kind && _selectedId == id;
    final color = isType ? const Color(0xFFEDE1F8) : depth == 1 ? const Color(0xFFFFE4BE) : const Color(0xFFFFDDF3);
    final level = isType ? 'نوع مستخدم' : _s(row['parent_user_id']).isEmpty ? 'مستخدم رئيسي' : 'مستخدم فرعي';
    final name = _s(row['name_ar']).trim().isEmpty ? 'بدون اسم' : _s(row['name_ar']);
    Widget statusCheck(String label, String field, {bool forceHidden = false}) {
      final value = field == 'show_at_login' ? row[field] == true && !forceHidden : row[field] == true;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(
          shape: const CircleBorder(),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: value,
          onChanged: _editMode && !forceHidden ? (v) => setState(() => row[field] = v == true) : null,
        ),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ]);
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 14, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _selectHierarchyNode(kind, row),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsetsDirectional.only(start: 6, end: 5, top: 3, bottom: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? _userAdminPurple : Colors.black12, width: selected ? 1.7 : 1),
              ),
              child: Row(children: [
                if (hasChildren)
                  IconButton(
                    tooltip: expanded ? 'طي الفروع' : 'فتح الفروع',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 30),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() {
                      if (expanded) { _expandedHierarchyNodes.remove(nodeKey); } else { _expandedHierarchyNodes.add(nodeKey); }
                    }),
                    icon: Icon(expanded ? Icons.expand_more : Icons.chevron_left, color: _userAdminPurple, size: 20),
                  )
                else const SizedBox(width: 24),
                Icon(isType ? Icons.badge_outlined : depth == 1 ? Icons.person_outline : Icons.people_alt_outlined,
                    color: _userAdminPurple, size: 19),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _editMode
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            TextFormField(
                              key: ValueKey('hierarchy-$kind-$id-ar'),
                              initialValue: _s(row['name_ar']),
                              onChanged: (v) => row['name_ar'] = v,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 5), labelText: 'الاسم بالعربية', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 3),
                            TextFormField(
                              key: ValueKey('hierarchy-$kind-$id-en'),
                              initialValue: _s(row['name_en']),
                              onChanged: (v) => row['name_en'] = v,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 5), labelText: 'English name', border: OutlineInputBorder()),
                            ),
                          ])
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text('$level • ${_s(row[isType ? 'type_code' : 'user_code'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                            if (_s(row['name_en']).isNotEmpty) Text(_s(row['name_en']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                          ]),
                  ),
                ),
                if (selected)
                  Flexible(
                    flex: 5,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(spacing: 3, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.end, children: [
                        statusCheck('نشط', 'is_active'),
                        if (isType)
                          statusCheck('عند الدخول', 'show_at_login', forceHidden: ['ادمن', 'موظف'].contains(_s(row['name_ar'])))
                        else ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () => _openBranchWarehousePicker(id),
                            icon: const Icon(Icons.account_tree_outlined, size: 15),
                            label: const Text('الفروع', style: TextStyle(fontSize: 11)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () => setState(() { _selectedNodeKind = 'user'; _selectedId = id; _selectedUserId = id; }),
                            icon: const Icon(Icons.person_add_alt_1, size: 15),
                            label: const Text('فرعي', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ]),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'تحديد السجل',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                    padding: EdgeInsets.zero,
                    onPressed: () => _selectHierarchyNode(kind, row),
                    icon: Icon(Icons.radio_button_unchecked, color: _userAdminPurple, size: 19),
                  ),
              ]),
            ),
          ),
        ),
        if (hasChildren && expanded)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 7, top: 3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children.map((child) => _hierarchyTreeNode(child, depth + 1, kind: 'user')).toList()),
          ),
      ]),
    );
  }

  // Include every loaded user in the hierarchy grid, even if legacy links
  // point to a deleted type/parent. Guard against accidental parent cycles.
  List<Map<String, dynamic>> _flattenHierarchy() {
    final result = <Map<String, dynamic>>[];
    final visited = <String>{};
    void addUser(Map<String, dynamic> user, int depth) {
      final id = _s(user['id']);
      if (id.isEmpty || !visited.add(id)) return;
      result.add({'kind':'user','depth':depth,'row':user});
      for (final child in _childrenForUser(id)) {
        addUser(child, depth + 1);
      }
    }
    for (final type in _types) {
      result.add({'kind':'type','depth':0,'row':type});
      for (final user in _usersForType(_s(type['id']))) addUser(user, 1);
    }
    for (final user in _users) {
      if (!visited.contains(_s(user['id']))) addUser(user, 1);
    }
    return result;
  }

  List<Map<String, dynamic>> _orphanHierarchyRoots() {
    final reachable = <String>{};
    void markUser(Map<String, dynamic> user) {
      final id = _s(user['id']);
      if (id.isEmpty || !reachable.add(id)) return;
      for (final child in _childrenForUser(id)) {
        markUser(child);
      }
    }
    for (final type in _types) {
      for (final user in _usersForType(_s(type['id']))) markUser(user);
    }
    final orphans = _users.where((u) => !reachable.contains(_s(u['id']))).toList();
    final orphanIds = orphans.map((u) => _s(u['id'])).toSet();
    final roots = orphans.where((u) => !orphanIds.contains(_s(u['parent_user_id']))).toList();
    return roots.isEmpty && orphans.isNotEmpty ? orphans : roots;
  }

  Widget _hierarchyView() {
    if (_expandedHierarchyNodes.isEmpty && _hierarchySearch.isEmpty) {
      _expandedHierarchyNodes.addAll(_types.map((t) => 'type:' + _s(t['id'])));
    }
    final types = _types.where(_typeBranchMatches).toList();
    final flat = _flattenHierarchy().where((item) {
      final row = Map<String, dynamic>.from(item['row'] as Map);
      return item['kind'] == 'type' ? _typeBranchMatches(row) : _userBranchMatches(row);
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 4), child: TextField(
        controller: _hierarchySearchController,
        onChanged: (v) => setState(() => _hierarchySearch = v.trim().toLowerCase()),
        decoration: InputDecoration(labelText: 'بحث في أنواع المستخدمين وأسماء المستخدمين', prefixIcon: const Icon(Icons.search, color: _userAdminPurple), suffixIcon: _hierarchySearch.isEmpty ? null : IconButton(onPressed: () { _hierarchySearchController.clear(); setState(() => _hierarchySearch = ''); }, icon: const Icon(Icons.clear)), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Wrap(spacing: 8, children: [
        ChoiceChip(label: const Text('عرض شجرة'), selected: _viewMode == 'tree', selectedColor: const Color(0xFFEDE1F8), onSelected: (_) => setState(() => _viewMode = 'tree')),
        ChoiceChip(label: const Text('عرض جدول'), selected: _viewMode == 'grid', selectedColor: const Color(0xFFEDE1F8), onSelected: (_) => setState(() => _viewMode = 'grid')),
      ])),
      Expanded(child: _viewMode == 'tree'
        ? ListView(padding: const EdgeInsets.all(8), children: [
            ...types.map((t) => _hierarchyTreeNode(t, 0, kind: 'type')),
            if (_orphanHierarchyRoots().isNotEmpty) ...[
              Container(
                margin: const EdgeInsetsDirectional.only(top: 8, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFA015)),
                ),
                child: Text(
                  'مستخدمون غير مرتبطين بنوع أو بمستخدم رئيسي (' + _orphanHierarchyRoots().length.toString() + ') — تم إظهارهم بدل إخفائهم',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ..._orphanHierarchyRoots().map((u) => _hierarchyTreeNode(u, 1, kind: 'user')),
            ],
            if (types.isEmpty && _users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد سجلات محفوظة للأنواع أو المستخدمين. اضغط تحديث، أو إضافة لإنشاء أول سجل.')),
              ),
          ])
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0E8F8)),
          columns: const [DataColumn(label: Text('النوع / المستوى')), DataColumn(label: Text('الكود')), DataColumn(label: Text('الاسم العربي')), DataColumn(label: Text('الاسم الإنجليزي')), DataColumn(label: Text('الحالة'))],
          rows: flat.map((item) {
            final kind = _s(item['kind']); final depth = item['depth'] as int; final row = Map<String, dynamic>.from(item['row'] as Map); final isType = kind == 'type'; final id = _s(row['id']);
            final selected = _selectedNodeKind == kind && _selectedId == id;
            final indent = List<String>.filled(depth, '  ').join();
            final levelLabel = isType ? 'نوع مستخدم' : depth == 1 ? 'مستخدم رئيسي' : 'مستخدم فرعي';
            return DataRow(selected: selected, color: WidgetStateProperty.all(isType ? const Color(0xFFEDE1F8) : depth == 1 ? const Color(0xFFFFE4BE) : const Color(0xFFFFDDF3)), onSelectChanged: (_) => _selectHierarchyNode(kind, row), cells: [
              DataCell(Text('$indent$levelLabel')),
              DataCell(Text(_s(row[isType ? 'type_code' : 'user_code']))),
              DataCell(SizedBox(width: 180, child: TextFormField(key: ValueKey('hier-grid-$kind-$id-ar-$_editMode'), initialValue: _s(row['name_ar']), enabled: _editMode, onChanged: (v) => row['name_ar'] = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
              DataCell(SizedBox(width: 180, child: TextFormField(key: ValueKey('hier-grid-$kind-$id-en-$_editMode'), initialValue: _s(row['name_en']), enabled: _editMode, onChanged: (v) => row['name_en'] = v, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
              DataCell(Checkbox(shape: const CircleBorder(), value: row['is_active'] == true, onChanged: _editMode ? (v) => setState(() => row['is_active'] = v == true) : null)),
            ]);
          }).toList(),
        )))),
    ]);
  }

  Future<void> _add() async {
    if (_isHierarchy) { await _addHierarchyNode(); return; }
    if (_saving) return;
    if (_isType && _rows.any((row) => row['_local_default'] == true)) {
      setState(() => _error = 'لا يمكن الإضافة قبل اتصال قاعدة البيانات وتحميل الأنواع المحفوظة؛ الصفوف الحالية للمعاينة فقط.');
      return;
    }
    if (_isPermissions) {
      setState(() {
        _editMode = true;
        _message = 'اختر المستخدم ثم عدّل مربعات الصلاحيات في الجدول.';
        _error = null;
      });
      return;
    }
    if (_company.isEmpty || _db == null) {
      setState(() => _error = 'حدد الشركة وتأكد من الاتصال بقاعدة البيانات قبل الإضافة.');
      return;
    }
    setState(() { _editMode = true; _error = null; });
    try {
      final payload = <String, dynamic>{'company_id': _company, 'is_active': true};
      if (_isType) {
        payload.addAll({'name_ar': _nextUniqueName('نوع مستخدم جديد'), 'name_en': _nextUniqueName('New user type', field: 'name_en'), 'description': '', 'show_at_login': false});
      } else if (_isUser) {
        if (_employees.isEmpty) { setState(() => _error = 'لا يمكن إنشاء مستخدم قبل إضافة موظف نشط من شاشة ملف الموظف.'); return; }
        final selectedEmployee = await _pickEmployee();
        if (selectedEmployee == null) { setState(() => _error = 'إضافة المستخدم أُلغيت: يجب اختيار موظف أولًا.'); return; }
        payload.addAll({
          'employee_id': selectedEmployee['id'],
          'name_ar': _s(selectedEmployee['full_name']),
          'name_en': _s(selectedEmployee['full_name_en']).isNotEmpty ? _s(selectedEmployee['full_name_en']) : _s(selectedEmployee['full_name']),
          'user_type_id': _types.where((t)=>t['is_active']==true).isEmpty ? null : _types.firstWhere((t)=>t['is_active']==true)['id'],
          'has_sub_warehouse': false,
        });
      } else {
        payload.addAll({'name_ar': _nextUniqueName('قالب صلاحيات جديد'), 'name_en': _nextUniqueName('New permission template', field: 'name_en')});
      }
      final result = await _db!.from(_table).insert(payload).select().single();
      if (!mounted) return;
      final row = Map<String, dynamic>.from(result);
      setState(() {
        // Keep the current in-memory edits in every previous row. Reloading here
        // would overwrite unsaved text/checkbox changes with the database snapshot.
        _rows.add(row);
        if (_isType) {
          _types = _rows;
        } else if (_isUser) {
          _users = _rows;
          _selectedUserId = _s(row['id']);
        } else {
          _templates = _rows;
        }
        _selectedId = _s(row['id']);
        _message = 'تم إنشاء سجل جديد دون إعادة تحميل الجريد. أكمل بياناته ثم اضغط حفظ.';
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر إضافة السجل: $e');
    }
  }

  Future<void> _save() async {
    if (_isHierarchy) { await _saveHierarchy(); return; }
    if (_isType && _rows.any((row) => row['_local_default'] == true)) {
      setState(() => _error = 'الأنواع الظاهرة حاليًا بيانات افتراضية للمعاينة فقط وليست محفوظة. أصلح صلاحيات/سياسات قاعدة البيانات ثم اضغط تحديث قبل الحفظ.');
      return;
    }
    if(!_editMode){setState(()=>_error='اضغط «تعديل» أو «إضافة» أولًا قبل تغيير البيانات.');return;}
    if(_saving)return;
    setState(()=>_saving=true);
    try {
      if(_isType||_isUser||_isTemplate){
        final masterRows=_rows;
        final targetTable=_table;
        for(final row in masterRows){
          final payload=<String,dynamic>{};
          if(_isType)payload.addAll({'name_ar':_s(row['name_ar']).trim(),'name_en':_s(row['name_en']).trim(),'description':_s(row['description']).trim().split(RegExp(r'\s+')).take(10).join(' '),'image_data':row['image_data'],'is_active':row['is_active']==true,'show_at_login':row['show_at_login']==true});
          if(_isUser){ if(_s(row['employee_id']).isEmpty) throw StateError('يجب ربط المستخدم «${_s(row['name_ar'])}» بموظف أولًا.'); payload.addAll({'name_ar':_s(row['name_ar']).trim(),'name_en':_s(row['name_en']).trim(),'employee_id':row['employee_id'],'image_data':row['image_data'],'is_active':row['is_active']==true,'user_type_id':row['user_type_id'],'has_sub_warehouse':row['has_sub_warehouse']==true}); }
          if(_isTemplate)payload.addAll({'name_ar':_s(row['name_ar']).trim(),'name_en':_s(row['name_en']).trim(),'image_data':row['image_data'],'is_active':row['is_active']==true});
          if(_s(row['id']).isNotEmpty) {
            await _db!.from(targetTable).update(payload).eq('company_id',_company).eq('id',row['id']);
            final password = _s(row['_password_draft']);
            if (_isUser && password.isNotEmpty) {
              if (password != _s(row['_password_confirmation_draft'])) throw StateError('كلمتا المرور غير متطابقتين للمستخدم ${_s(row['name_ar'])}.');
              await _db!.rpc('set_erp_user_password', params: {'p_user_id': row['id'], 'p_password': password});
              row['_password_draft'] = '';
              row['_password_confirmation_draft'] = '';
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
      }
        if(_isPermissions){
          final targetIds = _permissionTargetIds;
          if(targetIds.isEmpty) throw StateError('حدد مستخدمًا واحدًا على الأقل قبل حفظ الصلاحيات.');
          for(final uid in targetIds) {
            await _db!.from('erp_user_permission_matrix').delete().eq('company_id',_company).eq('user_id',uid);
          }
          for(final rule in _rules.where((r)=>targetIds.contains(_s(r['user_id'])))){
            final uid=_s(rule['user_id']);
            if(uid.isEmpty)continue;
            final payload=<String,dynamic>{'company_id':_company,'user_id':uid,'menu_name':rule['menu_name'],'submenu_name':rule['submenu_name']??'','page_name':rule['page_name']};
            for(final field in _userAdminActionFields.values)payload[field]=rule[field]==true;
            await _db!.from('erp_user_permission_matrix').insert(payload);
          }
        }
      if(mounted)setState(()=>_message='تم حفظ التغييرات في قاعدة البيانات.');
      if(mounted)setState(()=>_editMode=false);
      await _load();
    } catch(e){if(mounted)setState(()=>_error='تعذر الحفظ: $e');}
    finally{if(mounted)setState(()=>_saving=false);}
  }

  Future<void> _delete() async {
    if (_isHierarchy) { await _deleteHierarchyNode(); return; }
    if(!_editMode){setState(()=>_error='اضغط «تعديل» أولًا قبل حذف البيانات.');return;}
    if(_isPermissions){
      if(_selectedUserId==null){setState(()=>_error='اختر مستخدمًا أولًا.');return;}
      final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('مسح صلاحيات المستخدم'),content:const Text('سيتم حذف مصفوفة صلاحيات المستخدم المحدد فقط، ولن يتم حذف حسابه. هل تريد المتابعة؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('No / لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Yes / نعم، امسح الصلاحيات'))]));
      if(ok!=true)return;
      try{await _db!.from('erp_user_permission_matrix').delete().eq('company_id',_company).eq('user_id',_selectedUserId!);await _loadUserRules();if(mounted)setState(()=>_message='تم مسح صلاحيات المستخدم المحدد.');}catch(e){if(mounted)setState(()=>_error='تعذر مسح الصلاحيات: $e');}
      return;
    }
    if(_selectedId==null){setState(()=>_error='حدد سجلًا من الجدول أولًا.');return;}
    if (_isType && _rows.any((row) => _s(row['id']) == _selectedId && row['_local_default'] == true)) {
      setState(() => _error = 'لا يمكن حذف صف افتراضي للمعاينة؛ لم يُحفظ هذا الصف في قاعدة البيانات.');
      return;
    }
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد الحذف'),content:const Text('هل تريد حذف السجل المحدد؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Yes / نعم، احذف'))]));
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
        _rules.add({'menu_name':parts[0],'submenu_name':parts[1],'page_name':parts[2],if(!template)'user_id':parentId,for(final field in _userAdminActionFields.values)field:false,if(template)'can_access':true});
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
    onChanged:(v){ if(field=='description'){ final words=v.trim().split(RegExp(r'\s+')).where((w)=>w.isNotEmpty).take(10).toList(); row[field]=words.join(' '); } else { row[field]=v; } },
  ));

  Future<void> _openBranchWarehousePicker(String userId) async {
    if (_branches.isEmpty || _warehouses.isEmpty) {
      if (mounted) setState(() => _error = 'لا توجد فروع أو مخازن نشطة متاحة. أضف الفروع والمخازن أولًا ثم أعد المحاولة.');
      return;
    }
    try {
      final existing = await _db!.from('erp_user_branch_warehouse_access').select().eq('company_id', _company).eq('user_id', userId);
      final current = (existing as List).map((x) => Map<String, dynamic>.from(x)).toList();
      final selected = <String>{for (final x in current.where((x) => x['is_allowed'] == true)) '${x['branch_id']}|${x['warehouse_id']}'};
      String? primary = current.where((x) => x['is_default'] == true).map((x) => '${x['branch_id']}|${x['warehouse_id']}').firstOrNull;
      final allKeys = <String>{for (final branch in _branches) for (final warehouse in _warehouses.where((w) => _s(w['branch_id']) == _s(branch['id']))) '${branch['id']}|${warehouse['id']}'};
      final picked = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
          final allSelected = allKeys.isNotEmpty && selected.containsAll(allKeys);
          final rows = <DataRow>[];
          var index = 0;
          void addWarehouseRows(Map<String, dynamic> branch, Map<String, dynamic> warehouse, int depth) {
            final key = '${branch['id']}|${warehouse['id']}';
            final isSelected = selected.contains(key);
            final children = _warehouses.where((w) => _s(w['parent_warehouse_id']) == _s(warehouse['id'])).toList();
            rows.add(DataRow(
              color: WidgetStateProperty.all(depth == 0 ? const Color(0xFFF5EFFB) : Colors.white),
              cells: [
                DataCell(Text('${++index}')),
                DataCell(Padding(
                  padding: EdgeInsetsDirectional.only(start: depth * 22),
                  child: SizedBox(
                    width: 260,
                    child: Row(children: [
                      Icon(depth == 0 ? Icons.warehouse_outlined : Icons.subdirectory_arrow_left, size: 17, color: _userAdminPurple),
                      const SizedBox(width: 5),
                      Expanded(child: Text(_s(warehouse['warehouse_name']), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: depth == 0 ? FontWeight.w800 : FontWeight.normal))),
                    ]),
                  ),
                )),
                DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: isSelected, onChanged: (v) => setDialogState(() {
                  if (v == true) {
                    selected.add(key);
                  } else {
                    selected.remove(key);
                    if (primary == key) primary = null;
                  }
                }))),
                DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: primary == key, onChanged: (v) => setDialogState(() {
                  if (v == true) { selected.add(key); primary = key; } else if (primary == key) { primary = null; }
                }))),
              ],
            ));
            for (final child in children) { addWarehouseRows(branch, child, depth + 1); }
          }
          for (final branch in _branches) {
            final branchWarehouses = _warehouses.where((w) => _s(w['branch_id']) == _s(branch['id']) && _s(w['parent_warehouse_id']).isEmpty).toList();
            final branchKeys = _warehouses.where((w) => _s(w['branch_id']) == _s(branch['id'])).map((w) => '${branch['id']}|${w['id']}').toSet();
            final branchChecked = branchKeys.isNotEmpty && selected.containsAll(branchKeys);
            rows.add(DataRow(
              color: WidgetStateProperty.all(const Color(0xFFEDE1F8)),
              cells: [
                DataCell(Text('${++index}')),
                DataCell(Text(_s(branch['branch_name']), style: const TextStyle(fontWeight: FontWeight.w900, color: _userAdminPurple))),
                DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: branchChecked, onChanged: (v) => setDialogState(() {
                  if (v == true) {
                    selected.addAll(branchKeys);
                  } else {
                    selected.removeAll(branchKeys);
                    if (primary != null && branchKeys.contains(primary)) primary = null;
                  }
                }))),
                const DataCell(Text('—')),
              ],
            ));
            for (final warehouse in branchWarehouses) { addWarehouseRows(branch, warehouse, 0); }
          }
          return AlertDialog(
            title: const Text('F1 — الفروع والمخازن'),
            content: SizedBox(
              width: 760,
              height: 520,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('حدد الفروع أو المخازن المسموح بها، ثم اختر مخزنًا افتراضيًا واحدًا. تظهر المخازن الفرعية أسفل مخازنها الرئيسية.', style: TextStyle(fontSize: 12)),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: const Text('اختيار الكل'),
                  value: allSelected,
                  onChanged: (v) => setDialogState(() {
                    if (v == true) { selected.addAll(allKeys); } else { selected.clear(); primary = null; }
                  }),
                ),
                const Divider(height: 1),
                Expanded(child: SingleChildScrollView(child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 42,
                    dataRowMinHeight: 39,
                    dataRowMaxHeight: 44,
                    horizontalMargin: 8,
                    columnSpacing: 22,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF0E8F8)),
                    columns: const [
                      DataColumn(label: Text('م')),
                      DataColumn(label: Text('اسم الفرع / المخزن')),
                      DataColumn(label: Text('اختيار')),
                      DataColumn(label: Text('المخزن الافتراضي')),
                    ],
                    rows: rows,
                  ),
                ))),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(onPressed: () {
                if (primary != null && !selected.contains(primary)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المخزن الافتراضي يجب أن يكون ضمن المخازن المختارة.')));
                  return;
                }
                Navigator.pop(dialogContext, {'allowed': selected.toList(), 'default': primary});
              }, child: const Text('حفظ الاختيارات')),
            ],
          );
        }),
      );
      if (picked == null) return;
      final keys = (picked['allowed'] as List).cast<String>();
      final defaultKey = picked['default'] as String?;
      await _db!.from('erp_user_branch_warehouse_access').delete().eq('company_id', _company).eq('user_id', userId);
      for (final key in keys) {
        final parts = key.split('|');
        await _db!.from('erp_user_branch_warehouse_access').insert({
          'company_id': _company, 'user_id': userId, 'branch_id': parts[0], 'warehouse_id': parts[1],
          'is_allowed': true, 'is_default': key == defaultKey,
        });
      }
      if (mounted) setState(() => _message = 'تم حفظ صلاحيات الفروع والمخازن والمخزن الافتراضي.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حفظ صلاحيات الفروع والمخازن: $e');
    }
  }

  String _employeeLabel(String employeeId) {
    if (employeeId.isEmpty) return 'غير مرتبط بموظف';
    final e = _employees.where((x) => _s(x['id']) == employeeId).firstOrNull;
    if (e == null) return 'موظف غير موجود';
    return '${_s(e['employee_code'])} — ${_s(e['full_name'])}';
  }

  Future<Map<String,dynamic>?> _pickEmployee() async {
    if (_employees.isEmpty) {
      if (mounted) setState(() => _error = 'لا توجد سجلات موظفين نشطة. أضف الموظف أولًا من شاشة ملف الموظف.');
      return null;
    }
    final search = TextEditingController();
    final picked = await showDialog<Map<String,dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final q = search.text.trim().toLowerCase();
        final rows = _employees.where((e) => '${_s(e['employee_code'])} ${_s(e['full_name'])} ${_s(e['full_name_en'])}'.toLowerCase().contains(q)).toList();
        return AlertDialog(
          title: const Text('اختيار موظف وربطه بالمستخدم'),
          content: SizedBox(width: 620, height: 420, child: Column(children: [
            TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث بالكود أو الاسم', isDense: true), onChanged: (_) => setDialogState(() {})),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
              final e = rows[i];
              return ListTile(title: Text(_s(e['full_name'])), subtitle: Text('${_s(e['employee_code'])} • ${_s(e['full_name_en'])}'), onTap: () => Navigator.pop(ctx, e));
            })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء'))],
        );
      }),
    );
    search.dispose();
    return picked;
  }

  Future<void> _openEmployeePicker(Map<String,dynamic> row) async {
    final picked = await _pickEmployee();
    if (picked == null || !mounted) return;
    setState(() {
      row['employee_id'] = picked['id'];
      row['name_ar'] = picked['full_name'];
      row['name_en'] = _s(picked['full_name_en']).isNotEmpty ? picked['full_name_en'] : picked['full_name'];
      _error = null;
      _message = 'تم ربط المستخدم بموظف ${_s(picked['employee_code'])}. احفظ التعديلات لتثبيت الربط.';
    });
  }

  Widget _masterGrid(){
    final codeField=_isType?'type_code_display':_isUser?'user_code':'template_code_display';
    return SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      headingRowHeight: 57,dataRowMinHeight: 57,dataRowMaxHeight: 57,horizontalMargin:8,columnSpacing:12,
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF0E8F8)),
      columns:[
        const DataColumn(label:Text('م')),
        DataColumn(label:Text(_isType?'كود النوع':_isUser?'كود المستخدم':'كود القالب')),
        if(!_isUser)const DataColumn(label:Text('اسم عربي')),
        if(!_isUser)const DataColumn(label:Text('اسم إنجليزي')),
        if(_isUser)const DataColumn(label:Text('اسم المستخدم')),
        if(_isUser)const DataColumn(label:Text('كود الموظف (F1)')),
        if(_isUser)const DataColumn(label:Text('كلمة المرور')),
        if(_isUser)const DataColumn(label:Text('تأكيد كلمة المرور')),
        if(_isUser)const DataColumn(label:Text('نوع المستخدم')),
        if(_isType)const DataColumn(label:Text('يظهر في التطبيق')),
        if(!_isUser && !_isType)const DataColumn(label:Text('الصورة')),
        const DataColumn(label:Text('نشط')),
        if(_isType)const DataColumn(label:Text('وصف مختصر (10 كلمات)')),
        if(_isUser)const DataColumn(label:Text('له خزينة فرعية')),
        if(_isUser)const DataColumn(label:Text('الفروع والمخازن')),
        if(_isTemplate)const DataColumn(label:Text('قوائم وصلاحيات')),
      ],
      rows:List.generate(_rows.length,(i){
        final row=_rows[i];final id=_s(row['id']);
        return DataRow(selected:id==_selectedId,onSelectChanged:(v)async{setState(()=>_selectedId=v==true?id:null);if(v==true&&_isTemplate)await _loadRules();},cells:[
          DataCell(Text('${i+1}')),DataCell(Text(_s(row[codeField]).isNotEmpty ? _s(row[codeField]) : (_isType ? 'UT${_s(row['type_code']).padLeft(4, '0')}' : _isTemplate ? 'PT${_s(row['template_code']).padLeft(4, '0')}' : _s(row[codeField])))),
          if(!_isUser)DataCell(_textCell(row,'name_ar')),if(!_isUser)DataCell(_textCell(row,'name_en')),
          if(_isUser)DataCell(_textCell(row,'name_ar',width:165)),
          if(_isUser)DataCell(SizedBox(width:170,child:Row(children:[Expanded(child:Text(_employeeLabel(_s(row['employee_id'])),maxLines:2,overflow:TextOverflow.ellipsis)),IconButton(tooltip:'بحث عن موظف (F1)',visualDensity:VisualDensity.compact,onPressed:_editMode?()=>_openEmployeePicker(row):null,icon:const Icon(Icons.search,size:18))]))),
          if(_isUser)DataCell(SizedBox(width:175,child:Row(children:[Expanded(child:TextFormField(initialValue:_s(row['_password_draft']),obscureText:row['_password_visible']!=true,enabled:_editMode,decoration:const InputDecoration(hintText:'كلمة مرور',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:7),border:OutlineInputBorder()),onChanged:(v)=>row['_password_draft']=v)),IconButton(tooltip:'إظهار/إخفاء كلمة المرور',visualDensity:VisualDensity.compact,onPressed:_editMode?()=>setState(()=>row['_password_visible']=row['_password_visible']!=true):null,icon:Icon(row['_password_visible']==true?Icons.visibility_off:Icons.visibility,size:18))]))),
          if(_isUser)DataCell(SizedBox(width:155,child:TextFormField(initialValue:_s(row['_password_confirmation_draft']),obscureText:row['_password_visible']!=true,enabled:_editMode,decoration:const InputDecoration(hintText:'تأكيد كلمة المرور',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:7),border:OutlineInputBorder()),onChanged:(v)=>row['_password_confirmation_draft']=v))),
          if(_isUser)DataCell(SizedBox(width:115,child:DropdownButtonFormField<String>(
            key:ValueKey('${id}-type-${row['user_type_id']}'),value:_types.any((t)=>_s(t['id'])==_s(row['user_type_id']))?_s(row['user_type_id']):null,isExpanded:true,
            decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:5),border:OutlineInputBorder()),
            items:_types.where((t)=>t['is_active']==true).map((t)=>DropdownMenuItem(value:_s(t['id']),child:Text(_s(t['name_ar']),overflow:TextOverflow.ellipsis))).toList(),
            onChanged:_editMode?(v)=>setState(()=>row['user_type_id']=v):null,
          ))),
          if(_isType)DataCell(Checkbox(shape:const CircleBorder(),value:row['show_at_login']==true,onChanged:_editMode?(v)=>setState(()=>row['show_at_login']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
          if(!_isUser && !_isType)DataCell(_imageCell(row)),
          DataCell(Checkbox(shape:const CircleBorder(),value:row['is_active']==true,onChanged:_editMode?(v)=>setState(()=>row['is_active']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
          if(_isType)DataCell(_textCell(row,'description',width:220)),
          if(_isUser)DataCell(Checkbox(value:row['has_sub_warehouse']==true,onChanged:_editMode?(v)=>setState(()=>row['has_sub_warehouse']=v==true):null,visualDensity:VisualDensity.compact,activeColor:_userAdminPurple)),
          if(_isUser)DataCell(OutlinedButton.icon(onPressed:()=>_openBranchWarehousePicker(id),icon:const Icon(Icons.add_location_alt_outlined,size:16),label:const Text('+ فروع'))),
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

  List<String> get _permissionTargetIds {
    final available = _users.map((u) => _s(u['id'])).where((id) => id.isNotEmpty).toList();
    if (_permissionAllUsers) return available;
    return available.where(_permissionSelectedUserIds.contains).toList();
  }

  Map<String,dynamic>? _permissionRule(String uid, String menu, String submenu, String page) {
    return _rules.where((r) => _s(r['user_id']) == uid &&
      _s(r['menu_name']) == menu && _s(r['submenu_name']) == submenu &&
      _s(r['page_name']) == page).firstOrNull;
  }

  bool _permissionChecked(String menu, String submenu, String page, String field) {
    final targets = _permissionTargetIds;
    if (targets.isEmpty) return false;
    bool valueFor(String uid) {
      final exact = _permissionRule(uid, menu, submenu, page);
      if (exact != null) return exact[field] == true;
      if (page != '*' || field != 'can_access') return false;
      final pages = submenu == '*'
          ? [for (final sub in (_userAdminTree[menu] ?? const <String,List<String>>{}).entries) ...sub.value.map((p) => [sub.key,p])]
          : [for (final p in (_userAdminTree[menu]?[submenu] ?? const <String>[])) [submenu,p]];
      return pages.any((pair) => _permissionRule(uid, menu, pair[0], pair[1])?['can_access'] == true);
    }
    return targets.every(valueFor);
  }

  void _setPermissionTreeValue(String menu, String submenu, String page, String field, bool value) {
    final targets = _permissionTargetIds;
    if (targets.isEmpty) {
      setState(() => _error = 'حدد مستخدمًا واحدًا على الأقل، أو اختر كل المستخدمين.');
      return;
    }
    final keys = <List<String>>[];
    if (page != '*') {
      keys.add([menu, submenu, page]);
    } else if (submenu != '*') {
      keys.add([menu, submenu, '*']);
      for (final p in (_userAdminTree[menu]?[submenu] ?? const <String>[])) {
        keys.add([menu, submenu, p]);
      }
    } else {
      keys.add([menu, '*', '*']);
      for (final sub in (_userAdminTree[menu] ?? const <String,List<String>>{}).entries) {
        keys.add([menu, sub.key, '*']);
        for (final p in sub.value) { keys.add([menu, sub.key, p]); }
      }
    }
    setState(() {
      for (final uid in targets) {
        for (final key in keys) {
          var rule = _permissionRule(uid, key[0], key[1], key[2]);
          if (rule == null) {
            rule = <String,dynamic>{
              'company_id':_company,'user_id':uid,'menu_name':key[0],
              'submenu_name':key[1],'page_name':key[2],
              for (final field in _userAdminActionFields.values) field:false,
            };
            _rules.add(rule);
          }
          rule[field] = value;
          if (field == 'can_access' && !value) {
            for (final action in _userAdminActionFields.values.where((f) => f != 'can_access')) {
              rule[action] = false;
            }
          } else if (field != 'can_access' && value) {
            rule['can_access'] = true;
          }
        }
      }
      _error = null;
      _message = 'تم تحديث الصلاحيات كمسودة. اضغط حفظ لتثبيت التغييرات.';
    });
  }

  Widget _permissionRuleCells(String menu, String submenu, String page) {
    return Row(mainAxisSize:MainAxisSize.min,children:[
      for (final entry in _userAdminActionFields.entries)
        SizedBox(width:72,child:Center(child:Checkbox(
          shape:const CircleBorder(),
          value:_permissionChecked(menu,submenu,page,entry.value),
          onChanged:_editMode ? (v)=>_setPermissionTreeValue(menu,submenu,page,entry.value,v==true) : null,
          visualDensity:VisualDensity.compact,activeColor:_userAdminPurple,
        ))),
    ]);
  }

  Widget _permissionTreeRow(String label, String menu, String submenu, String page, {bool strong=false}) {
    return Container(
      color: strong ? const Color(0xFFF0E8F8) : Colors.white,
      padding: const EdgeInsetsDirectional.only(start:8,end:4,top:3,bottom:3),
      child: Row(children:[
        Expanded(flex:3,child:Text(label,style:TextStyle(fontWeight:strong?FontWeight.w900:FontWeight.w600,fontSize:12,color:strong?_userAdminPurple:Colors.black87))),
        Expanded(flex:7,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:_permissionRuleCells(menu,submenu,page))),
      ]),
    );
  }

  void _changePermissionMode(String mode) {
    setState(() {
      _permissionMode = mode;
      if (mode == 'manual') {
        final targets = _permissionTargetIds.toSet();
        _rules.removeWhere((r) => targets.contains(_s(r['user_id'])));
        _message = 'تم بدء تحديد يدوي بصلاحيات غير محددة للمستخدمين المستهدفين.';
      }
      _editMode = true;
      _error = null;
    });
  }

  Future<void> _openTemplatePicker() async {
    final picked = await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('جلب قالب صلاحيات (F1)'),
      content:SizedBox(width:460,height:360,child:ListView(children:[
        for(final template in _templates.where((t)=>t['is_active']==true))
          ListTile(title:Text(_s(template['name_ar'])),subtitle:Text(_s(template['template_code_display'])),onTap:()=>Navigator.pop(ctx,_s(template['id']))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء'))],
    ));
    if (picked == null || !mounted) return;
    setState(()=>_selectedTemplateId=picked);
    await _applyTemplate();
  }

  Widget _permissionUsersGrid(){
    final targets = _permissionTargetIds;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Wrap(spacing:12,runSpacing:6,alignment:WrapAlignment.start,crossAxisAlignment:WrapCrossAlignment.center,children:[
        Row(mainAxisSize:MainAxisSize.min,children:[
          Checkbox(shape:const CircleBorder(),value:_permissionAllUsers,onChanged:_editMode?(v)=>setState(()=>_permissionAllUsers=v==true):null),
          const Text('كل المستخدمين'),
        ]),
        Row(mainAxisSize:MainAxisSize.min,children:[
          Checkbox(shape:const CircleBorder(),value:!_permissionAllUsers,onChanged:_editMode?(v)=>setState(()=>_permissionAllUsers=!(v==true)):null),
          const Text('مستخدمون محددون'),
        ]),
        OutlinedButton.icon(onPressed:_load,icon:const Icon(Icons.person_search),label:const Text('جلب مستخدمين')),
        Row(mainAxisSize:MainAxisSize.min,children:[
          Checkbox(shape:const CircleBorder(),value:_permissionMode=='template',onChanged:_editMode?(v)=>_changePermissionMode(v==true?'template':'manual'):null),
          const Text('تحديد قالب ثابت'),
        ]),
        Row(mainAxisSize:MainAxisSize.min,children:[
          Checkbox(shape:const CircleBorder(),value:_permissionMode=='manual',onChanged:_editMode?(v)=>_changePermissionMode(v==true?'manual':'template'):null),
          const Text('تحديد صلاحيات يدوي'),
        ]),
        if(_permissionMode=='template') OutlinedButton.icon(
          onPressed:_editMode?_openTemplatePicker:null,
          icon:const Icon(Icons.file_open_outlined),label:Text(_selectedTemplateId==null?'جلب قالب (F1)': 'تغيير القالب (F1)')),
        if(_permissionMode=='template') OutlinedButton.icon(
          onPressed:_editMode&&_selectedTemplateId!=null?_applyTemplate:null,
          icon:const Icon(Icons.playlist_add_check),label:const Text('تطبيق القالب')),
      ]),
      if(!_permissionAllUsers) Container(
        constraints:const BoxConstraints(maxHeight:130),
        decoration:BoxDecoration(color:const Color(0xFFFAF8FC),border:Border.all(color:_userAdminPurple.withValues(alpha:.15)),borderRadius:BorderRadius.circular(8)),
        child:SingleChildScrollView(child:Wrap(spacing:8,runSpacing:2,children:[
          for(final user in _users) SizedBox(width:210,child:CheckboxListTile(
            dense:true,controlAffinity:ListTileControlAffinity.leading,
            value:_permissionSelectedUserIds.contains(_s(user['id'])),
            title:Text(_s(user['name_ar']),maxLines:1,overflow:TextOverflow.ellipsis),
            subtitle:Text(_s(user['user_code'])),contentPadding:const EdgeInsets.symmetric(horizontal:6),
            onChanged:_editMode?(v)=>setState(()=>v==true?_permissionSelectedUserIds.add(_s(user['id'])):_permissionSelectedUserIds.remove(_s(user['id']))):null,
          )),
        ]))),
      Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text('المستخدمون المستهدفون: ${targets.length} • كل صف رئيسي عند إلغاء «مسموح» يلغي صلاحيات الشاشات التابعة له.',style:TextStyle(color:Colors.grey.shade700,fontSize:12))),
      Container(color:const Color(0xFFEDE4F8),padding:const EdgeInsetsDirectional.only(start:8,end:4,top:6,bottom:6),child:Row(children:[
        const Expanded(flex:3,child:Text('القائمة / الشاشة',style:TextStyle(fontWeight:FontWeight.w900,color:_userAdminPurple))),
        Expanded(flex:7,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          for(final action in _userAdminActions) SizedBox(width:72,child:Text(action,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))),
        ]))),
      ])),
      Expanded(child:ListView(children:[
        for(final menu in _userAdminTree.entries) ExpansionTile(
          key:PageStorageKey<String>('perm-menu-${menu.key}'),
          tilePadding:const EdgeInsets.symmetric(horizontal:4),
          title:_permissionTreeRow(menu.key,menu.key,'*','*',strong:true),
          children:[
            for(final sub in menu.value.entries) ExpansionTile(
              key:PageStorageKey<String>('perm-sub-${menu.key}-${sub.key}'),
              tilePadding:const EdgeInsetsDirectional.only(start:16,end:4),
              title:_permissionTreeRow(sub.key,menu.key,sub.key,'*',strong:true),
              children:[for(final page in sub.value)
                _permissionTreeRow(page,menu.key,sub.key,page)],
            ),
          ],
        ),
      ])),
    ]);
  }

  @override Widget build(BuildContext context){
    ErpKeyboardNavigation.registerActions(add: _add, save: _save);
    final title=_typeNames[_view]??'المستخدمين';
    return Focus(autofocus:true,onKeyEvent:(node,event){
      if(event is KeyDownEvent && event.logicalKey==LogicalKeyboardKey.f1){
        if(_isTemplate && _selectedId!=null){_openMenuPicker(parentId:_selectedId!,template:true);return KeyEventResult.handled;}
        if(_isPermissions){_openTemplatePicker();return KeyEventResult.handled;}
        if(_isUser && _selectedId!=null){ final user=_users.where((u)=>_s(u['id'])==_selectedId).firstOrNull; if(user!=null)_openEmployeePicker(user); return KeyEventResult.handled; }
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
      if(_isPermissions)Padding(padding:const EdgeInsets.all(8),child:Text('حدد المستخدمين ثم اختر قالب صلاحيات أو عدّل الصلاحيات يدويًا حسب القوائم.',style:TextStyle(color:Colors.grey.shade700))),
      if(!_isPermissions)Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _userTab('أنواع المستخدمين', 'types', Icons.badge_outlined), const SizedBox(width: 6),
          _userTab('تصنيفات المستخدمين', 'classifications', Icons.category_outlined), const SizedBox(width: 6),
          _userTab('قوالب صلاحيات المستخدمين', 'templates', Icons.fact_check_outlined), const SizedBox(width: 6),
          _userTab('المستخدمين', 'users', Icons.people_alt_outlined), const SizedBox(width: 6),
          _userTab('احتياطي شاشة المستخدمين', 'hierarchy', Icons.account_tree_outlined),
        ])),
      ),
      Expanded(child:_view=='classifications'
        ? ErpUserClassificationsScreen(companyId: _company)
        : _loading ? const Center(child:CircularProgressIndicator())
        : _isPermissions ? _ruleGrid()
        : _isHierarchy ? _hierarchyView()
        : SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(_isTemplate) ...[_masterGrid(),const SizedBox(height:12),_ruleGrid()] else _masterGrid(),
        ])))),
    ])));
  }

  Widget _userTab(String label, String view, IconData icon) {
    final selected = _view == view;
    return OutlinedButton.icon(
      onPressed: selected ? null : () {
        setState(() { _view = view; _editMode = false; _error = null; _message = null; });
        if (view != 'classifications') _load();
      },
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : _userAdminPurple,
        backgroundColor: selected ? _userAdminPurple : Colors.white,
        side: BorderSide(color: _userAdminPurple.withValues(alpha: selected ? 1 : .3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _applyTemplate() async {
    final targets = _permissionTargetIds;
    if(targets.isEmpty || _selectedTemplateId==null) {
      if(mounted)setState(()=>_error='اختر المستخدمين المستهدفين ثم حدد قالب الصلاحيات.');
      return;
    }
    try {
      final source=await _db!.from('erp_permission_template_rules').select()
        .eq('company_id',_company).eq('template_id',_selectedTemplateId!);
      final sourceRules=(source as List).whereType<Map<String,dynamic>>().toList();
      setState(() {
        _rules.removeWhere((r)=>targets.contains(_s(r['user_id'])));
        for(final uid in targets) {
          for(final item in sourceRules) {
            _rules.add(<String,dynamic>{
              'company_id':_company,'user_id':uid,'menu_name':item['menu_name'],
              'submenu_name':item['submenu_name']??'','page_name':item['page_name'],
              for(final field in _userAdminActionFields.values) field:item[field]==true,
            });
          }
        }
        _editMode=true;
        _error=null;
        _message='تم تحميل القالب كمسودة على ${targets.length} مستخدم. اضغط حفظ لتثبيت الصلاحيات.';
      });
    } catch(e) { if(mounted)setState(()=>_error='تعذر جلب القالب: $e'); }
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
