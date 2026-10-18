import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/hr_attendance_rules_screen.dart';
import 'screens/erp_app_assets_screen.dart';
import 'screens/erp_program_settings_screen.dart';
import 'screens/erp_delegate_allocation_screen.dart';
import 'screens/erp_company_profile_screen.dart';
import 'screens/erp_currencies_screen.dart';
import 'screens/erp_company_members_screen.dart';
import 'screens/erp_permissions_screen.dart';
import 'screens/erp_shipping_companies_screen.dart';
import 'screens/erp_branches_screen.dart';
import 'screens/erp_cost_centers_screen.dart';
import 'screens/erp_accounts_screen.dart';
import 'screens/erp_journal_entries_screen.dart';
import 'screens/erp_ledger_reports_screen.dart';
import 'screens/erp_movement_audit_screen.dart';
import 'screens/erp_inventory_screen.dart';
import 'screens/erp_hr_operations_screen.dart';
import 'screens/erp_operational_documents_screen.dart';
import 'screens/erp_cash_vouchers_screen.dart';
import 'screens/erp_payroll_screen.dart';
import 'screens/erp_fiscal_periods_screen.dart';
import 'screens/erp_parties_screen.dart';
import 'screens/erp_inventory_master_screen.dart';
import 'screens/erp_cashboxes_screen.dart';
import 'screens/erp_price_lists_screen.dart';
import 'screens/erp_sales_targets_commissions_screen.dart';
import 'screens/erp_public_leads_screen.dart';
import 'screens/erp_einvoice_screen.dart';
import 'screens/erp_operational_account_mappings_screen.dart';
import 'services/erp_operational_documents_repository.dart';
import 'services/erp_workspace_records_service.dart';
import 'services/erp_app_management_service.dart';
import 'services/erp_app_settings.dart';
import 'services/erp_app_permission_catalog.dart';
import 'services/erp_company_settings_repository.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _pink = Color(0xFFFF27C3);
const _canvas = Color(0xFFF7F5FA);

const Map<String, Map<String, List<String>>> _modules = {
  'إدارة البرنامج': {
    'بيانات أساسية': ['إعدادات هوية التطبيق', 'إدارة الشعار والصور', 'إدارة ألوان التطبيقات', 'إدارة صلاحيات التطبيقات', 'إدارة صور الأصناف والفئات', 'إدارة صور الموردين والعملاء', 'إدارة شركات الشحن', 'إعدادات عامة للتطبيقات'],
    'حركات': ['مراجعة طلبات تعديل التطبيقات', 'سجل تغييرات الهوية', 'إدارة إصدارات التطبيقات'],
    'تقارير': ['تقرير التطبيقات', 'تقرير الصلاحيات', 'تقرير تغييرات الإعدادات'],
  },
  'إدارة التطبيقات': {
    'بيانات أساسية': ['إعدادات هوية التطبيق', 'الفروع ومراكز التكلفة', 'المستخدمون والصلاحيات', 'إدارة الصلاحيات', 'إعدادات البرنامج', 'سجل العمليات', 'واجهة API والربط الخارجي', 'إدارة مفاتيح API', 'سجلات التكامل والطلبات', 'سياسات التسعير والخصومات', 'توزيع الأصناف على المندوبين', 'قيود البيع والشراء'],
    'حركات': ['اختبار ومراجعة الحركات', 'قائمة اعتماد القيود', 'إدارة الجلسات', 'سجل الدخول والخروج', 'النسخ الاحتياطي', 'إعداد نقاط الربط', 'اختبار الاتصال الخارجي'],
    'تقارير': ['تقرير المستخدمين', 'تقرير نشاط النظام', 'تقرير استهلاك API', 'تقرير أخطاء التكامل'],
  },
  'الحسابات المالية': {
    'بيانات أساسية': ['شجرة الحسابات', 'الفترات المالية', 'مراكز التكلفة', 'العملات', 'الخزائن الرئيسية والفرعية', 'الحسابات البنكية', 'خريطة الحسابات التشغيلية', 'طرق الدفع', 'لوحات المؤشرات', 'قوالب التقارير'],
    'حركات': ['قيود اليومية', 'سندات القبض', 'سندات الصرف', 'تسويات الحسابات', 'إقفال الفترة', 'تحويل بين الخزائن', 'إيداع بنكي', 'سحب بنكي', 'مطابقة البنك', 'تحديث مؤشرات الأداء', 'تصدير البيانات'],
    'تقارير': ['ميزان المراجعة', 'الأستاذ العام', 'قائمة الدخل', 'الميزانية العمومية', 'حركة حساب', 'أرصدة الخزائن', 'كشف حساب خزينة', 'كشف حساب بنك', 'مؤشرات الأداء الرئيسية', 'التدفقات النقدية', 'تحليل الربحية', 'حركة المبيعات والمخزون', 'ملخص تنفيذي'],
  },
  'المخازن والفروع': {
    'بيانات أساسية': ['دليل المخازن', 'مجموعات الأصناف', 'دليل الأصناف', 'الوحدات والتحويلات', 'الباركود', 'حدود إعادة الطلب', 'قواعد إعادة الطلب والتنبيه', 'دليل الفروع', 'المخازن التابعة', 'مراكز التكلفة', 'المناطق الجغرافية'],
    'حركات': ['إذن إضافة', 'إذن صرف', 'تحويل مخزني', 'تسوية جرد', 'جرد فعلي', 'محاضر الجرد ومراجعة الفروق', 'تسوية صلاحية وهالك', 'تحويلات بين الفروع', 'تسويات الفروع', 'توزيع المصروفات'],
    'تقارير': ['أرصدة الأصناف', 'كارت الصنف', 'الجرد والفروق', 'الأصناف الراكدة', 'الأصناف قاربت على النفاد', 'تنبيهات إعادة الطلب', 'تواريخ الصلاحية', 'تنبيهات قرب انتهاء الصلاحية', 'أرصدة التشغيلات', 'أداء الفروع', 'أرباح وخسائر الفروع', 'حركة التحويلات'],
  },
  'المشتريات والموردون': {
    'بيانات أساسية': ['سياسات الشراء', 'قوائم أسعار الموردين', 'دليل الموردين', 'تصنيفات الموردين', 'جهات اتصال الموردين', 'شروط التوريد'],
    'حركات': ['طلب شراء', 'أمر شراء', 'استلام مشتريات', 'فاتورة مشتريات', 'مرتجع مشتريات', 'كشف حساب مورد', 'تقييم مورد', 'مطابقة أرصدة الموردين', 'تسجيل مديونية مورد'],
    'تقارير': ['تحليل المشتريات', 'مقارنة أسعار الموردين', 'أعمار ديون الموردين', 'أرصدة الموردين', 'أداء الموردين', 'الموردون حسب النشاط'],
  },
  'المبيعات والعملاء': {
    'بيانات أساسية': ['قوائم أسعار البيع', 'سياسات الخصم', 'مناطق التوزيع', 'خطوط السير', 'دليل العملاء', 'تصنيفات العملاء', 'فروع العملاء', 'حدود الائتمان', 'مناطق العملاء', 'دليل المندوبين', 'مركبات التوزيع', 'قاعدة العملاء المحتملين', 'أهداف العملاء الشهرية', 'عمولات المندوبين'],
    'حركات': ['عرض سعر', 'أمر بيع', 'فاتورة مبيعات', 'مرتجع مبيعات', 'إذن تحميل', 'تسليم طلب', 'كشف حساب عميل', 'تحصيلات العملاء', 'متابعة المديونيات', 'طلبات العملاء', 'تسليم عهدة مندوب', 'تصفية عهدة مندوب', 'تحصيل نقدي', 'مصروفات رحلة'],
    'تقارير': ['المبيعات اليومية', 'ربحية المبيعات', 'مبيعات حسب الفرع', 'أداء المندوبين', 'الطلبات المتأخرة', 'تحقيق أهداف العملاء', 'تقرير العمولات المستحقة', 'أرصدة العملاء', 'أعمار الديون', 'أفضل العملاء', 'العملاء المتوقفون', 'تصفية المندوبين', 'تحصيلات يومية', 'تكلفة خطوط السير'],
  },
  'الموارد البشرية والرواتب': {
    'بيانات أساسية': ['هيكل الشركة', 'الإدارات والأقسام', 'الوظائف والدرجات', 'ملف الموظف', 'العقود', 'أنواع الإجازات', 'قواعد الورديات والحضور والانصراف', 'أجهزة البصمة وربط الحضور', 'مكونات الراتب', 'الاستحقاقات والاستقطاعات', 'سياسات العمولة'],
    'حركات': ['الحضور والانصراف', 'الإجازات والأذونات', 'الجزاءات والمكافآت', 'السلف', 'تقييم الأداء', 'مسير الرواتب', 'صرف الرواتب', 'عمولات المبيعات', 'تسوية سلفة'],
    'تقارير': ['كشف العاملين', 'الحضور والغياب', 'رصيد الإجازات', 'انتهاء العقود', 'ملخص الرواتب', 'مفردات المرتب', 'عمولات المندوبين'],
  },
  'علاقات العملاء CRM': {
    'بيانات أساسية': ['الحملات التسويقية', 'قواعد العروض', 'شرائح العملاء', 'أنواع الطلبات', 'قنوات التواصل', 'أسباب الشكاوى'],
    'حركات': ['إنشاء عرض', 'اعتماد حملة', 'تسجيل كوبون', 'تذكرة دعم جديدة', 'متابعة شكوى', 'تسجيل اقتراح'],
    'تقارير': ['أداء العروض', 'تكلفة الحملات', 'معدل الاستجابة', 'التذاكر المفتوحة', 'زمن الاستجابة', 'رضا العملاء'],
    'الفاتورة الإلكترونية': [
      'لوحة الفاتورة الإلكترونية', 'إعدادات الربط الضريبي', 'بيانات الممول والتوقيع الإلكتروني',
      'تكويد السلع والخدمات', 'فواتير إلكترونية صادرة', 'فواتير إلكترونية واردة',
      'إشعارات دائنة إلكترونية', 'إشعارات مدينة إلكترونية', 'إرسال المستندات للضرائب',
      'متابعة حالات الإرسال', 'إلغاء المستندات', 'رفض المستندات الواردة',
      'قبول أو رفض طلبات الإلغاء', 'قبول أو رفض طلبات الرفض', 'البحث عن مستند ضريبي',
      'المستندات الضريبية الحديثة', 'تفاصيل المستند والتحقق', 'طباعة الفاتورة الضريبية PDF',
      'طلبات حزم المستندات', 'تنزيل حزم المستندات', 'إشعارات منظومة الضرائب',
      'سجل عمليات التكامل', 'اختبار الاتصال الضريبي', 'تقارير الفاتورة الإلكترونية'
    ],
  },
};

class ErpDashboardScreen extends StatefulWidget {
  const ErpDashboardScreen({super.key});
  @override
  State<ErpDashboardScreen> createState() => _ErpDashboardScreenState();
}

class _ErpDashboardScreenState extends State<ErpDashboardScreen> {
  final ErpAppManagementService _appManagementService = ErpAppManagementService();
  final ErpWorkspaceRecordsService _workspaceRecordsService = ErpWorkspaceRecordsService();
  final ErpCompanySettingsRepository _workspaceSettingsRepository = ErpCompanySettingsRepository();
  String? _appManagementCompanyId;
  bool _executiveMetricsLoading = false;
  String? _executiveMetricsError;
  double? _executiveSales;
  double? _executiveGrossProfit;
  double? _executiveCollections;
  double? _executiveReceivables;
  double? _executivePurchases;
  double? _executiveInventoryValue;
  List<double> _executiveDailySales = <double>[];
  List<double> _executiveDailyCollections = <double>[];
  List<double> _executiveInventoryGroupValues = <double>[];
  List<String> _executiveInventoryGroupLabels = <String>[];
  final Map<String, String> _managedAppIds = <String, String>{};
  bool _appManagementLoading = false;
  bool _appManagementSaving = false;
  String? _appManagementMessage;
  String _selectedPermissionRole = 'owner';
  final Map<String, bool> _managedPermissions = <String, bool>{};
  bool _permissionsLoading = false;
  List<ErpAppActivityEntry> _savedAppActivity = <ErpAppActivityEntry>[];
  bool _sidebarVisible = true;
  bool _notificationsPanelVisible = true;
  bool _activityPanelVisible = true;
  bool _quickAccessPanelVisible = true;
  String _module = 'إدارة البرنامج';
  String _selectedAppKey = 'silsila';
  String _appName = 'سلسلة';
  Color _appPrimary = const Color(0xFF3E007D);
  Color _appAccent = const Color(0xFFFFA015);
  final Map<String, Map<String, Object>> _managedAppDrafts = {
    'silsila': {'name': 'سلسلة', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
    'app_2': {'name': 'تطبيق رقم 2', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
    'app_3': {'name': 'تطبيق رقم 3', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
  };

  void _selectManagedApp(String key) {
    final draft = _managedAppDrafts[key];
    if (draft == null) return;
    setState(() {
      _selectedAppKey = key;
      _appName = draft['name'] as String;
      _appPrimary = draft['primary'] as Color;
      _appAccent = draft['accent'] as Color;
    });
    _loadSelectedManagedAppTheme();
    _loadPermissionsForSelectedApp();
    _loadSavedAppActivity();
  }

  @override
  void initState() {
    super.initState();
    _loadManagedAppsFromCloud();
  }

  Future<void> _loadManagedAppsFromCloud() async {
    if (!mounted) return;
    setState(() {
      _appManagementLoading = true;
      _appManagementMessage = null;
    });
    try {
      final companyIds = await _appManagementService.listCurrentUserCompanyIds();
      if (companyIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _appManagementCompanyId = null;
          _appManagementMessage = _appManagementService.currentUserId == null
              ? 'سجّل الدخول إلى Supabase لربط إعدادات التطبيقات.'
              : 'لا توجد عضوية شركة نشطة لهذا المستخدم؛ لم يتم تحميل أو حفظ إعدادات.';
        });
        return;
      }
      final companyId = companyIds.first;
      final apps = await _appManagementService.listApps(companyId: companyId);
      final registryRows = await _appManagementService.listAppRegistry(companyId: companyId);
      if (!mounted) return;
      setState(() {
        _appManagementCompanyId = companyId;
        _managedAppIds
          ..clear()
          ..addAll(registryRows);
        for (final app in apps) {
          String? key;
          for (final entry in registryRows.entries) {
            if (entry.value == app.id) {
              key = entry.key;
              break;
            }
          }
          if (key == null) continue;
          _managedAppDrafts[key] = {
            'name': app.name,
            'primary': _managedAppDrafts[key]?['primary'] ?? const Color(0xFF3E007D),
            'accent': _managedAppDrafts[key]?['accent'] ?? const Color(0xFFFFA015),
          };
        }
        final selectedDraft = _managedAppDrafts[_selectedAppKey];
        if (selectedDraft != null) {
          _appName = selectedDraft['name'] as String;
          _appPrimary = selectedDraft['primary'] as Color;
          _appAccent = selectedDraft['accent'] as Color;
        }
        _appManagementMessage = 'تم تحميل سجل التطبيقات من قاعدة البيانات.';
      });
      await _loadSelectedManagedAppTheme();
      await _loadPermissionsForSelectedApp();
      await _loadSavedAppActivity();
      await _loadWorkspaceSettings(companyId);
      await _loadExecutiveMetrics(companyId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appManagementMessage = 'تعذر تحميل إعدادات التطبيقات: $error';
      });
    } finally {
      if (mounted) setState(() => _appManagementLoading = false);
    }
  }

  Future<void> _loadWorkspaceSettings(String companyId) async {
    try {
      final pricing = await _workspaceSettingsRepository.getSetting(
        companyId: companyId,
        key: 'pricing_policy',
      );
      final permissions = await _workspaceSettingsRepository.getSetting(
        companyId: companyId,
        key: 'program_permissions',
      );
      final restrictions = await _workspaceSettingsRepository.getSetting(
        companyId: companyId,
        key: 'transaction_restrictions',
      );
      if (!mounted) return;
      setState(() {
        if (pricing != null) {
          _basePriceController.text = pricing['base_price']?.toString() ?? '';
          _priceLimitController.text = pricing['price_limit']?.toString() ?? '';
          _priceValueController.text = pricing['price_value']?.toString() ?? '';
          _invoiceDiscountController.text = pricing['invoice_discount']?.toString() ?? '';
          _itemDiscountController.text = pricing['item_discount']?.toString() ?? '';
          _pricingMode = pricing['mode']?.toString() == 'قيمة' ? 'قيمة' : 'نسبة';
          _pricingDirection = pricing['direction']?.toString() == 'نقصان' ? 'نقصان' : 'زيادة';
        }
        if (permissions?['values'] is Map) {
          _permissionDraft
            ..clear()
            ..addEntries((permissions!['values'] as Map).entries.map(
              (entry) => MapEntry(entry.key.toString(), entry.value == true),
            ));
        }
        if (restrictions != null) {
          _restrictionAction = restrictions['action']?.toString() ?? _restrictionAction;
          _restrictionTarget = restrictions['target']?.toString() ?? _restrictionTarget;
          _restrictionItem.text = restrictions['item']?.toString() ?? '';
          _restrictionCustomer.text = restrictions['customer']?.toString() ?? '';
          _restrictionDelegate.text = restrictions['delegate']?.toString() ?? '';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _appManagementMessage = 'تعذر تحميل إعدادات العمل المحفوظة: $error');
      }
    }
  }

  Future<bool> _saveWorkspaceSetting(
    String key,
    Map<String, Object?> value, {
    String successMessage = 'تم حفظ الإعدادات في قاعدة البيانات.',
  }) async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.trim().isEmpty) {
      _showAppManagementMessage('لا توجد شركة نشطة مرتبطة بالمستخدم؛ لم يتم الحفظ.');
      return false;
    }
    try {
      await _workspaceSettingsRepository.saveSetting(
        companyId: companyId,
        key: key,
        value: value,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: const Color(0xFF16834A)),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ الإعدادات: $error'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _loadSelectedManagedAppTheme() async {
    final selectedKey = _selectedAppKey;
    final appId = _managedAppIds[selectedKey];
    if (appId == null || appId.isEmpty) return;
    try {
      final settings = await _appManagementService.getThemeSettings(appId: appId);
      if (settings == null || !mounted || selectedKey != _selectedAppKey) return;
      final primary = _parseManagedColor(settings.primaryColor);
      final accent = _parseManagedColor(settings.accentColor);
      setState(() {
        _appName = settings.displayName;
        _appPrimary = primary;
        _appAccent = accent;
        _managedAppDrafts[selectedKey] = {
          'name': _appName,
          'primary': _appPrimary,
          'accent': _appAccent,
        };
      });
    } catch (error) {
      if (mounted && selectedKey == _selectedAppKey) {
        setState(() => _appManagementMessage = 'تعذر تحميل هوية التطبيق: $error');
      }
    }
  }

  Future<void> _loadPermissionsForSelectedApp() async {
    final appId = _managedAppIds[_selectedAppKey];
    if (appId == null || appId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _managedPermissions
          ..clear()
          ..addAll({
            for (final key in ErpAppPermissionCatalog.permissions.keys)
              key: ErpAppPermissionCatalog.defaultAllowList[_selectedPermissionRole]?.contains(key) ?? false,
          });
      });
      return;
    }
    setState(() => _permissionsLoading = true);
    try {
      final saved = await _appManagementService.listPermissions(appId: appId);
      final values = <String, bool>{
        for (final key in ErpAppPermissionCatalog.permissions.keys)
          key: ErpAppPermissionCatalog.defaultAllowList[_selectedPermissionRole]?.contains(key) ?? false,
      };
      for (final permission in saved) {
        if (permission.roleKey == _selectedPermissionRole &&
            ErpAppPermissionCatalog.isKnownPermission(permission.permissionKey)) {
          values[permission.permissionKey] = permission.allowed;
        }
      }
      if (!mounted) return;
      setState(() {
        _managedPermissions
          ..clear()
          ..addAll(values);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _appManagementMessage = 'تعذر تحميل صلاحيات التطبيق: $error');
      }
    } finally {
      if (mounted) setState(() => _permissionsLoading = false);
    }
  }

  Future<void> _changeManagedPermission(String permissionKey, bool allowed) async {
    final appId = _managedAppIds[_selectedAppKey];
    if (appId == null || appId.isEmpty) {
      _showAppManagementMessage('احفظ سجل التطبيق أولًا قبل حفظ صلاحياته.');
      return;
    }
    final permission = ErpAppPermission(
      appId: appId,
      roleKey: _selectedPermissionRole,
      permissionKey: permissionKey,
      allowed: allowed,
    );
    final errors = ErpAppPermissionCatalog.validate(permission);
    if (errors.isNotEmpty) {
      _showAppManagementMessage(errors.join(' '));
      return;
    }
    final previous = _managedPermissions[permissionKey] ?? false;
    setState(() => _managedPermissions[permissionKey] = allowed);
    try {
      await _appManagementService.savePermission(permission);
      if (mounted) {
        setState(() {
          _appManagementMessage = 'تم حفظ صلاحية «${ErpAppPermissionCatalog.permissions[permissionKey]}» لدور ${ErpAppPermissionCatalog.roles[_selectedPermissionRole]}.';
          _activityLog.insert(0, 'تم تعديل صلاحية ${permissionKey} للدور ${_selectedPermissionRole}');
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _managedPermissions[permissionKey] = previous;
        _appManagementMessage = 'لم يتم حفظ الصلاحية: $error';
      });
    }
  }

  Future<void> _loadSavedAppActivity() async {
    final companyId = _appManagementCompanyId;
    final appId = _managedAppIds[_selectedAppKey];
    if (companyId == null || appId == null || appId.isEmpty) {
      if (mounted) setState(() => _savedAppActivity = <ErpAppActivityEntry>[]);
      return;
    }
    try {
      final entries = await _appManagementService.listActivity(
        companyId: companyId,
        appId: appId,
        limit: 10,
      );
      if (mounted) setState(() => _savedAppActivity = entries);
    } catch (error) {
      if (mounted) setState(() => _appManagementMessage = 'تعذر تحميل سجل النشاطات: $error');
    }
  }

  Color _parseManagedColor(String value) {
    final hex = value.trim().replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? const Color(0xFF3E007D) : Color(parsed);
  }

  Future<void> _saveManagedAppToCloud() async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.isEmpty) {
      _showAppManagementMessage('لا يمكن الحفظ قبل وجود عضوية شركة نشطة في Supabase.');
      return;
    }
    if (_appName.trim().isEmpty) {
      _showAppManagementMessage('اكتب اسم التطبيق قبل الحفظ.');
      return;
    }
    setState(() {
      _appManagementSaving = true;
      _appManagementMessage = null;
    });
    try {
      final appId = await _appManagementService.saveManagedApp(
        companyId: companyId,
        appKey: _selectedAppKey,
        displayName: _appName.trim(),
        status: _selectedAppKey == 'silsila'
            ? ErpManagedAppStatus.active
            : ErpManagedAppStatus.inDevelopment,
      );
      await _appManagementService.saveThemeSettings(
        ErpAppThemeSettings(
          appId: appId,
          displayName: _appName.trim(),
          primaryColor: '#${_appPrimary.value.toRadixString(16).substring(2).toUpperCase()}',
          accentColor: '#${_appAccent.value.toRadixString(16).substring(2).toUpperCase()}',
        ),
      );
      if (!mounted) return;
      setState(() {
        _managedAppIds[_selectedAppKey] = appId;
        _appManagementMessage = 'تم حفظ اسم التطبيق وألوانه في قاعدة البيانات.';
        _activityLog.insert(0, 'تم حفظ إعدادات هوية التطبيق $_appName في Supabase');
      });
      await _loadPermissionsForSelectedApp();
      await _loadSavedAppActivity();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appManagementMessage = 'لم يتم الحفظ في قاعدة البيانات: $error';
      });
    } finally {
      if (mounted) setState(() => _appManagementSaving = false);
    }
  }

  void _showAppManagementMessage(String message) {
    if (!mounted) return;
    setState(() => _appManagementMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateManagedAppDraft({String? name, Color? primary, Color? accent}) {
    setState(() {
      if (name != null) _appName = name;
      if (primary != null) _appPrimary = primary;
      if (accent != null) _appAccent = accent;
      _managedAppDrafts[_selectedAppKey] = {
        'name': _appName,
        'primary': _appPrimary,
        'accent': _appAccent,
      };
    });
  }
  bool _allowImageManagement = true;
  bool _allowThemeManagement = true;
  bool _allowPermissionManagement = true;
  final List<String> _activityLog = ['تم فتح لوحة ERP', 'تم تجهيز أقسام المخازن والفروع', 'تمت إضافة نماذج إدارة المستندات'];
  String _group = 'بيانات أساسية';
  String _page = 'بيانات الشركة';
  String _search = '';
  String _accountSearch = '';
  final TextEditingController _accountSearchController = TextEditingController();
  Map<String, String>? _selectedRecord;
  final Map<String, List<Map<String, String>>> _saved = {};
  final Set<String> _cloudLoadedWorkspacePages = <String>{};
  final Set<String> _workspacePageLoadsInProgress = <String>{};

  List<String> get _pages => _modules[_module]![_group]!;
  List<Map<String, String>> get _rows {
    final rows = _cloudLoadedWorkspacePages.contains(_page)
        ? (_saved[_page] ?? <Map<String, String>>[])
        : (_saved[_page] ?? _sampleRows(_page));
    if (_search.trim().isEmpty) return rows;
    return rows.where((r) => r.values.any((v) => v.toLowerCase().contains(_search.toLowerCase()))).toList();
  }

  List<Map<String, String>> _sampleRows(String page) {
    if (page == 'شجرة الحسابات') {
      return [
        {'الكود': '1', 'اسم الحساب': 'الأصول', 'المستوى': 'رئيسي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '11', 'اسم الحساب': 'الأصول المتداولة', 'المستوى': 'فرعي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '111', 'اسم الحساب': 'الخزائن', 'المستوى': 'فرعي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '11101', 'اسم الحساب': 'الخزينة الرئيسية', 'المستوى': 'تحليلي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '2', 'اسم الحساب': 'الالتزامات', 'المستوى': 'رئيسي', 'الطبيعة': 'دائن', 'الحالة': 'نشط'},
        {'الكود': '3', 'اسم الحساب': 'حقوق الملكية', 'المستوى': 'رئيسي', 'الطبيعة': 'دائن', 'الحالة': 'نشط'},
        {'الكود': '4', 'اسم الحساب': 'الإيرادات', 'المستوى': 'رئيسي', 'الطبيعة': 'دائن', 'الحالة': 'نشط'},
        {'الكود': '5', 'اسم الحساب': 'المصروفات', 'المستوى': 'رئيسي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
      ];
    }
    if (page.contains('خزائن')) {
      return [
        {'الكود': 'CASH-001', 'الاسم': 'الخزينة الرئيسية', 'النوع': 'رئيسية', 'الفرع': 'الإدارة العامة', 'الرصيد': '125,450 ج.م', 'الحالة': 'نشط'},
        {'الكود': 'CASH-002', 'الاسم': 'خزينة فرع العبور', 'النوع': 'فرعية', 'الفرع': 'العبور', 'الرصيد': '24,800 ج.م', 'الحالة': 'نشط'},
      ];
    }
    if (page.contains('إعادة الطلب') || page.contains('النفاد')) {
      return [
        {'الصنف': 'زيت عباد الشمس', 'المخزن': 'المخزن الرئيسي', 'الرصيد الحالي': '12 كرتونة', 'الحد الأدنى': '20 كرتونة', 'الكمية المقترحة': '28 كرتونة', 'الحالة': 'تنبيه تجريبي'},
        {'الصنف': 'مكرونة 400 جم', 'المخزن': 'المخزن الرئيسي', 'الرصيد الحالي': '8 كراتين', 'الحد الأدنى': '15 كرتونة', 'الكمية المقترحة': '22 كرتونة', 'الحالة': 'تنبيه تجريبي'},
      ];
    }
    if (page.contains('الصلاحية') || page.contains('التشغيلات')) {
      return [
        {'الصنف': 'عصير معبأ', 'رقم التشغيلة': 'BATCH-DEMO-01', 'تاريخ الصلاحية': 'بيانات توضيحية', 'الرصيد': '6 كراتين', 'الحالة': 'يتطلب متابعة'},
      ];
    }
    if (page.contains('الجرد') || page == 'جرد فعلي') {
      return [
        {'رقم المحضر': 'COUNT-DEMO-001', 'المخزن': 'المخزن الرئيسي', 'التاريخ': '—', 'عدد الأصناف': '—', 'الحالة': 'مسودة تجريبية'},
      ];
    }
    if (page.contains('الأصناف') || page == 'دليل الأصناف') {
      return [
        {'الكود': 'SKU-001', 'الاسم': 'زيت عباد الشمس', 'المجموعة': 'زيوت', 'الوحدة': 'كرتونة', 'المخزون': '120', 'الحالة': 'نشط'},
        {'الكود': 'SKU-002', 'الاسم': 'مكرونة 400 جم', 'المجموعة': 'مكرونات', 'الوحدة': 'كرتونة', 'المخزون': '85', 'الحالة': 'نشط'},
        {'الكود': 'SKU-003', 'الاسم': 'سمن نباتي', 'المجموعة': 'سمنات', 'الوحدة': 'كرتونة', 'المخزون': '42', 'الحالة': 'نشط'},
      ];
    }
    if (page.contains('API') || page.contains('الربط الخارجي') || page.contains('التكامل')) {
      return [
        {'البند': 'حالة واجهة API', 'القيمة': 'غير مفعّلة', 'التفاصيل': 'تحتاج إعداد الخادم والمصادقة', 'الحالة': 'تجهيز'},
        {'البند': 'نمط الربط', 'القيمة': 'REST / JSON', 'التفاصيل': 'قابل للتحديد عند التنفيذ', 'الحالة': 'تصميم'},
        {'البند': 'سجل الطلبات', 'القيمة': 'غير متصل', 'التفاصيل': 'لن تُحفظ طلبات فعلية قبل ربط الخادم', 'الحالة': 'غير متصل'},
      ];
    }
    if (page.contains('المورد')) {
      return [{'الكود': 'SUP-001', 'الاسم': 'مورد تجريبي', 'التصنيف': 'موزع رئيسي', 'الهاتف': '01000000000', 'الرصيد': '0 ج.م', 'الحالة': 'نشط'}];
    }
    if (page.contains('العملاء') || page.contains('العميل')) {
      return [{'الكود': 'CUS-001', 'الاسم': 'عميل تجريبي', 'التصنيف': 'تاجر جملة', 'الهاتف': '01000000000', 'الرصيد': '0 ج.م', 'الحالة': 'نشط'}];
    }
    if (_group == 'تقارير') {
      return [{'المؤشر': 'حالة التقرير', 'القيمة': 'نموذج عرض', 'ملاحظة': 'غير مرتبط بقاعدة البيانات بعد'}];
    }
    return [
      {'الكود': 'DEMO-001', 'الاسم': page, 'الوصف': 'سجل توضيحي للواجهة', 'الحالة': 'نموذج'},
      {'الكود': 'DEMO-002', 'الاسم': 'مثال إضافي', 'الوصف': 'بيانات تجريبية فقط', 'الحالة': 'نموذج'},
    ];
  }

  void _openAddDialog() {
    final code = TextEditingController();
    final name = TextEditingController();
    final details = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('إضافة سجل — $_page'),
        content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, decoration: const InputDecoration(labelText: 'الكود / الرقم المرجعي')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم / البيان')),
          const SizedBox(height: 12),
          TextField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف أو ملاحظات')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final rows = List<Map<String, String>>.from(_saved[_page] ?? _sampleRows(_page));
            rows.insert(0, {'الكود': code.text.trim().isEmpty ? 'NEW-${rows.length + 1}' : code.text.trim(), 'الاسم': name.text.trim(), 'الوصف': details.text.trim(), 'الحالة': 'مسودة'});
            final newRecord = Map<String, String>.from(rows.first);
            newRecord['_مرجع داخلي'] = newRecord['الكود'] ?? newRecord['الاسم'] ?? newRecord.values.first;
            rows[0] = newRecord;
            setState(() {
              _saved[_page] = rows;
              _selectedRecord = newRecord;
              _activityLog.insert(0, 'تمت إضافة سجل جديد في شاشة $_page');
            });
            Navigator.pop(dctx);
            final companyId = _appManagementCompanyId;
            if (companyId == null || companyId.trim().isEmpty) {
              _showActionMessage('تمت الإضافة محليًا فقط. سجّل الدخول واربط المستخدم بشركة نشطة لتفعيل الحفظ الدائم.');
            } else {
              try {
                await _workspaceRecordsService.saveRecord(companyId: companyId, pageKey: _page, record: newRecord);
                _showActionMessage('تم حفظ السجل الجديد في قاعدة البيانات.');
              } catch (error) {
                _showActionMessage('تعذر الحفظ الدائم: $error');
              }
            }
          }, child: const Text('حفظ السجل')),
        ],
      ),
    ).then((_) { code.dispose(); name.dispose(); details.dispose(); });
  }

  void _showActionMessage(String message) {
    setState(() => _activityLog.insert(0, message));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveCurrentPage() async {
    final companyId = _appManagementCompanyId;
    final rows = _saved[_page] ?? const <Map<String, String>>[];
    if (rows.isEmpty) {
      _showActionMessage('لا توجد سجلات أدخلتها يدويًا لحفظها في هذه الشاشة.');
      return;
    }
    if (companyId == null || companyId.trim().isEmpty) {
      _showActionMessage('الحفظ الدائم غير متاح: سجّل الدخول واربط المستخدم بشركة نشطة.');
      return;
    }
    try {
      var savedCount = 0;
      for (final row in rows) {
        // Only rows loaded from the database or explicitly created in this session
        // carry this internal key. Never upload static sample rows as business data.
        if (!row.containsKey('_مرجع داخلي')) continue;
        await _workspaceRecordsService.saveRecord(companyId: companyId, pageKey: _page, record: row);
        savedCount++;
      }
      if (!mounted) return;
      _showActionMessage(savedCount == 0
          ? 'لم توجد سجلات فعلية للحفظ؛ أمثلة الواجهة لم تُرفع إلى قاعدة البيانات.'
          : 'تم حفظ $savedCount سجلًا في قاعدة البيانات.');
    } catch (error) {
      if (!mounted) return;
      _showActionMessage('تعذر حفظ سجلات الشاشة: $error');
    }
  }

  void _editCurrentRecord() {
    final rows = List<Map<String, String>>.from(_saved[_page] ?? _sampleRows(_page));
    if (rows.isEmpty) { _showActionMessage('لا يوجد سجل لتعديله في شاشة $_page'); return; }
    final selected = _selectedRecord;
    final selectedIndex = selected == null ? 0 : rows.indexWhere((row) => _sameRecord(row, selected));
    final targetIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final canPersistSelectedRecord = rows[targetIndex].containsKey('_مرجع داخلي');
    final controllers = <String, TextEditingController>{for (final entry in rows[targetIndex].entries) if (entry.key != '_مرجع داخلي') entry.key: TextEditingController(text: entry.value)};
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('تعديل سجل — $_page'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: controllers.entries.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: entry.value, decoration: InputDecoration(labelText: entry.key)),
      )).toList()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          final updated = <String, String>{for (final entry in controllers.entries) entry.key: entry.value.text.trim()};
          final internalKey = rows[targetIndex]['_مرجع داخلي'];
          if (internalKey != null) updated['_مرجع داخلي'] = internalKey;
          rows[targetIndex] = updated;
          setState(() { _saved[_page] = rows; _selectedRecord = updated; });
          Navigator.pop(dialogContext);
          final companyId = _appManagementCompanyId;
          final originalCode = rows[targetIndex]['الكود'] ?? rows[targetIndex]['الاسم'] ?? '';
          if (canPersistSelectedRecord && companyId != null && companyId.trim().isNotEmpty &&
              !originalCode.startsWith('DEMO-') &&
              !originalCode.contains('تجريبي') &&
              !originalCode.contains('توضيحي')) {
            _workspaceRecordsService.saveRecord(companyId: companyId, pageKey: _page, record: updated)
              .then((_) { if (mounted) _showActionMessage('تم حفظ تعديل السجل في قاعدة البيانات.'); })
              .catchError((Object error) { if (mounted) _showActionMessage('تم التعديل محليًا لكن فشل الحفظ الدائم: $error'); });
          } else {
            _showActionMessage('تم تعديل السجل محليًا؛ لا يُحفظ السجل التوضيحي في قاعدة البيانات.');
          }
        }, child: const Text('حفظ التعديل')),
      ],
    )).then((_) { for (final controller in controllers.values) { controller.dispose(); } });
  }

  Future<void> _deleteCurrentRecord() async {
    final selected = _selectedRecord;
    if (selected == null) {
      _showActionMessage('حدد سجلًا من الجدول أولًا ثم اضغط حذف.');
      return;
    }
    final visibleCode = selected['الكود'] ?? selected['الاسم'] ?? selected['اسم الحساب'] ?? '';
    if (!selected.containsKey('_مرجع داخلي') || visibleCode.startsWith('DEMO-') || visibleCode.contains('تجريبي') || visibleCode.contains('توضيحي')) {
      _showActionMessage('هذا سجل توضيحي وليس بيانات فعلية؛ لن يتم حذفه من قاعدة البيانات.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف السجل'),
        content: Text('هل تريد حذف السجل «$visibleCode» من شاشة «$_page»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final companyId = _appManagementCompanyId;
    final recordKey = selected['_مرجع داخلي'] ?? visibleCode;
    try {
      if (companyId != null && companyId.trim().isNotEmpty) {
        await _workspaceRecordsService.deleteRecord(companyId: companyId, pageKey: _page, recordKey: recordKey);
      }
      final rows = List<Map<String, String>>.from(_saved[_page] ?? _sampleRows(_page));
      rows.removeWhere((row) => _sameRecord(row, selected));
      setState(() {
        _saved[_page] = rows;
        _selectedRecord = null;
      });
      _showActionMessage(companyId == null
          ? 'تم حذف السجل من الجلسة الحالية فقط؛ لا توجد شركة مرتبطة للحذف الدائم.'
          : 'تم حذف السجل من قاعدة البيانات.');
    } catch (error) {
      _showActionMessage('تعذر حذف السجل من قاعدة البيانات: $error');
    }
  }

  bool _sameRecord(Map<String, String> a, Map<String, String> b) => a.length == b.length && a.entries.every((entry) => b[entry.key] == entry.value);

  String _currentPageCsv() {
    final rows = _rows;
    if (rows.isEmpty) return '';
    final keys = rows.first.keys.toList();
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    return [
      '\uFEFF${keys.map(cell).join(',')}',
      ...rows.map((row) => keys.map((key) => cell(row[key] ?? '')).join(',')),
    ].join('\\r\\n');
  }

  void _exportExcel() {
    final csv = _currentPageCsv();
    if (csv.isEmpty) { _showActionMessage('لا توجد بيانات لتصديرها من شاشة $_page'); return; }
    Clipboard.setData(ClipboardData(text: csv));
    _showActionMessage('تم تجهيز ملف CSV متوافق مع Excel ونسخ محتواه للحافظة. استخدم لصق في Excel ثم احفظه بصيغة XLSX.');
  }

  void _showPrintPreview({required bool pdf}) {
    final rows = _rows;
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(pdf ? 'تصدير PDF — $_page' : 'معاينة الطباعة — $_page'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('سلسلة Silsila • $_module • $_group', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8), Text('الشاشة: $_page • عدد السجلات: ${rows.length}'), const Divider(),
        if (rows.isEmpty) const Text('لا توجد بيانات لعرضها.')
        else ...rows.take(30).map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join('  |  ')))),
        if (rows.length > 30) const Text('تم عرض أول 30 سجلًا في المعاينة.'),
        const SizedBox(height: 8),
        Text(pdf ? 'هذه معاينة تجهيز PDF؛ يلزم إضافة محرك PDF للتنزيل الفعلي.' : 'هذه معاينة للطباعة؛ إرسالها إلى الطابعة يحتاج تفعيل خدمة الطباعة في نسخة التشغيل.', style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
    ));
  }

  Widget _recordAction(String label, IconData icon, Color color, VoidCallback action) => FilledButton.icon(
    onPressed: action,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );

  Widget _recordToolbar({bool includeAdd = true}) => Wrap(spacing: 7, runSpacing: 7, children: [
    if (includeAdd) _recordAction('إضافة', Icons.add_rounded, const Color(0xFF18865A), _openAddDialog),
    _recordAction('تعديل', Icons.edit_outlined, _orange, _editCurrentRecord),
    _recordAction('حذف', Icons.delete_outline_rounded, const Color(0xFFB42318), _deleteCurrentRecord),
    _recordAction('حفظ', Icons.save_outlined, _purple, _saveCurrentPage),
    _recordAction('طباعة', Icons.print_outlined, _pink, () => _showPrintPreview(pdf: false)),
    _recordAction('تصدير Excel', Icons.table_view_outlined, const Color(0xFF16834A), _exportExcel),
    _recordAction('تصدير PDF', Icons.picture_as_pdf_outlined, const Color(0xFFD32F2F), () => _showPrintPreview(pdf: true)),
  ]);

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 900;
      return Scaffold(
        backgroundColor: _canvas,
        drawer: compact ? Drawer(child: _sidebar()) : null,
        body: Row(children: [
          if (!compact && _sidebarVisible) SizedBox(width: 275, child: _sidebar()),
          Expanded(child: Column(children: [
            _header(compact),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(compact ? 14 : 26), child: _page == 'إعدادات البرنامج' ? ErpProgramSettingsScreen(companyId: _appManagementCompanyId) : _page == 'عن البرنامج' ? _about() : _page == 'قاعدة العملاء المحتملين' ? ErpPublicLeadsScreen(companyId: _appManagementCompanyId) : _page == 'أهداف العملاء الشهرية' || _page == 'عمولات المندوبين' || _page == 'تحقيق أهداف العملاء' || _page == 'تقرير العمولات المستحقة' ? ErpSalesTargetsCommissionsScreen(companyId: _appManagementCompanyId, initialTabIndex: _page == 'عمولات المندوبين' ? 1 : _page == 'تقرير العمولات المستحقة' ? 3 : 0) : _page == 'العملاء' || _page == 'الموردون' || _page == 'دليل العملاء' || _page == 'دليل الموردين' ? ErpPartiesScreen(initialCompanyId: _appManagementCompanyId, initialKind: _page == 'الموردون' || _page == 'دليل الموردين' ? 'supplier' : 'customer') : _page == 'العملات' ? ErpCurrenciesScreen(companyId: _appManagementCompanyId) : _page == 'شجرة الحسابات' ? ErpAccountsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الفترات المالية' || _page == 'إقفال الفترة' ? ErpFiscalPeriodsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'قائمة اعتماد القيود' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId, initialStatus: 'draft') : _page == 'قيود اليومية' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId) : _page == 'ميزان المراجعة' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.trialBalance, initialCompanyId: _appManagementCompanyId) : _page == 'الأستاذ العام' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.generalLedger, initialCompanyId: _appManagementCompanyId) : _page == 'حركة حساب' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.accountMovement, initialCompanyId: _appManagementCompanyId) : _page == 'الملخص التنفيذي' || _page == 'ملخص تنفيذي' ? _home() : _module == 'إدارة البرنامج' && _page == 'بيانات الشركة' ? ErpCompanyProfileScreen(companyId: _appManagementCompanyId, onCompanyCreated: (companyId) async { if (!mounted) return; setState(() => _appManagementCompanyId = companyId); await _loadWorkspaceSettings(companyId); await _loadExecutiveMetrics(companyId); }) : _page == 'إدارة الشعار والصور' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey], initialAssetType: 'app_logo') : _page == 'إدارة صور الأصناف والفئات' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey], initialAssetType: 'item') : _page == 'إدارة صور الموردين والعملاء' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey], initialAssetType: 'supplier') : _page == 'إدارة شركات الشحن' ? const ErpShippingCompaniesScreen() : _page == 'دليل الفروع' ? ErpBranchesScreen(companyId: _appManagementCompanyId) : _page == 'الفروع ومراكز التكلفة' ? ErpCostCentersScreen(companyId: _appManagementCompanyId) : _module == 'إدارة التطبيقات' ? _appManagement() : _page == 'اختبار ومراجعة الحركات' ? ErpMovementAuditScreen(initialCompanyId: _appManagementCompanyId) : _page == 'دليل المخازن' ? ErpInventoryMasterScreen(initialCompanyId: _appManagementCompanyId, initialView: 'warehouses') : _page == 'مجموعات الأصناف' ? ErpInventoryMasterScreen(initialCompanyId: _appManagementCompanyId, initialView: 'groups') : _page == 'دليل الأصناف' ? ErpInventoryMasterScreen(initialCompanyId: _appManagementCompanyId, initialView: 'items') : _page == 'أرصدة الأصناف' || _page == 'كارت الصنف' || _page == 'الجرد والفروق' || _page == 'إذن إضافة' || _page == 'إذن صرف' || _page == 'تحويل مخزني' || _page == 'تسوية جرد' || _page == 'جرد فعلي' ? ErpInventoryScreen(initialCompanyId: _appManagementCompanyId) : _page == 'ملف الموظف' || _page == 'الحضور والانصراف' || _page == 'الإجازات والأذونات' ? ErpHrOperationsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'مسير الرواتب' || _page == 'صرف الرواتب' ? ErpPayrollScreen(initialCompanyId: _appManagementCompanyId) : _page == 'قوائم أسعار البيع' ? ErpPriceListsScreen(initialCompanyId: _appManagementCompanyId, initialKind: 'sale') : _page == 'قوائم أسعار الموردين' || _page == 'قوائم أسعار الشراء' ? ErpPriceListsScreen(initialCompanyId: _appManagementCompanyId, initialKind: 'purchase') : _page == 'خريطة الحسابات التشغيلية' ? ErpOperationalAccountMappingsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الخزائن الرئيسية والفرعية' ? ErpCashboxesScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الحسابات البنكية' ? ErpCashboxesScreen(initialCompanyId: _appManagementCompanyId, initialBankOnly: true) : _page == 'سندات القبض' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'receipt') : _page == 'سندات الصرف' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'payment') : _page == 'تحويل بين الخزائن' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'transfer') : _page == 'طلب شراء' || _page == 'أمر شراء' || _page == 'استلام مشتريات' || _page == 'فاتورة مشتريات' || _page == 'مرتجع مشتريات' ? ErpOperationalDocumentsScreen(initialCompanyId: _appManagementCompanyId, kind: ErpOperationalKind.purchase, initialDocumentType: _page == 'طلب شراء' || _page == 'أمر شراء' ? 'order' : _page == 'استلام مشتريات' ? 'receipt' : _page == 'مرتجع مشتريات' ? 'return' : 'invoice') : _page == 'عرض سعر' || _page == 'أمر بيع' || _page == 'فاتورة مبيعات' || _page == 'إذن تحميل' || _page == 'تسليم طلب' || _page == 'مرتجع مبيعات' ? ErpOperationalDocumentsScreen(initialCompanyId: _appManagementCompanyId, kind: ErpOperationalKind.sales, initialDocumentType: _page == 'عرض سعر' ? 'quotation' : _page == 'أمر بيع' ? 'order' : _page == 'إذن تحميل' || _page == 'تسليم طلب' ? 'delivery' : _page == 'مرتجع مبيعات' ? 'return' : 'invoice') : _page == 'المستخدمون والصلاحيات' ? ErpCompanyMembersScreen(companyId: _appManagementCompanyId) : _modules['علاقات العملاء CRM']!['الفاتورة الإلكترونية']!.contains(_page) ? ErpEinvoiceScreen(companyId: _appManagementCompanyId, initialView: _page) : _page == 'إدارة الصلاحيات' ? ErpPermissionsScreen(companyId: _appManagementCompanyId) : _page == 'سياسات التسعير والخصومات' ? _pricingPolicyScreen() : _page == 'توزيع الأصناف على المندوبين' ? ErpDelegateAllocationScreen(companyId: _appManagementCompanyId) : _page == 'قيود البيع والشراء' ? _transactionRestrictionsScreen() : _page == 'قائمة اعتماد القيود' ? _journalApprovalScreen() : _page == 'قواعد الورديات والحضور والانصراف' ? HrShiftRulesScreen(companyId: _appManagementCompanyId) : _page == 'أجهزة البصمة وربط الحضور' ? HrFingerprintDevicesScreen(companyId: _appManagementCompanyId) : _workspace())),
            if (!compact && (_notificationsPanelVisible || _activityPanelVisible || _quickAccessPanelVisible))
              SizedBox(
                width: 286,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 14),
                  child: _rightPanel(),
                ),
              ),
            ])),
          ])),
        ]),
      );
    }));
  }

  final Set<String> _expandedModules = <String>{};
  final Set<String> _expandedGroups = <String>{};

  Widget _sidebar() => Container(
    color: _purple,
    child: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _orange.withValues(alpha: .85), width: 1.4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/silsila_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.link_rounded,
                      color: _purple,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سلسلة Silsila', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  SizedBox(height: 4),
                  Text('سلسلة .. بنربط السوق ببعضه', style: TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('ERP • إدارة موارد المؤسسة', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              )),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
          ..._modules.entries.map((moduleEntry) {
            final name = moduleEntry.key;
            final moduleOpen = _expandedModules.contains(name);
            final selectedModule = name == _module;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => setState(() {
                      if (moduleOpen) {
                        _expandedModules.remove(name);
                        _expandedGroups.removeWhere((key) => key.startsWith('$name::'));
                      } else {
                        _expandedModules.add(name);
                      }
                    }),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      selected: moduleOpen || selectedModule,
                      selectedTileColor: const Color(0xFF7040A0),
                      leading: Icon(_iconFor(name), color: _orange, size: 20),
                      title: Text(name, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: moduleOpen || selectedModule ? FontWeight.w800 : FontWeight.w500)),
                      onTap: () => setState(() {
                        _module = name;
                        _group = moduleEntry.value.keys.first;
                        _page = moduleEntry.value[_group]!.first;
                        _search = '';
                      }),
                    ),
                  )),
                  IconButton(
                    tooltip: moduleOpen ? 'طي القائمة' : 'توسيع القائمة',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      if (moduleOpen) {
                        _expandedModules.remove(name);
                        _expandedGroups.removeWhere((key) => key.startsWith('$name::'));
                      } else {
                        _expandedModules.add(name);
                      }
                    }),
                    icon: Icon(moduleOpen ? Icons.expand_more_rounded : Icons.chevron_left_rounded, color: moduleOpen ? Colors.white : _orange, size: 24),
                  ),
                ]),
              ),
              if (moduleOpen)
                ...moduleEntry.value.entries.map((groupEntry) {
                  final groupKey = '$name::${groupEntry.key}';
                  final groupOpen = _expandedGroups.contains(groupKey);
                  final selectedGroup = selectedModule && _group == groupEntry.key;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(start: 13, end: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () => setState(() {
                            if (groupOpen) {
                              _expandedGroups.remove(groupKey);
                            } else {
                              _expandedModules.add(name);
                              _expandedGroups.add(groupKey);
                            }
                          }),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -3),
                            contentPadding: const EdgeInsetsDirectional.only(start: 10, end: 2),
                            selected: selectedGroup,
                            selectedTileColor: const Color(0xFF7040A0),
                            title: Text(groupEntry.key, style: TextStyle(color: selectedGroup ? _orange : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                            onTap: () => setState(() {
                              _module = name;
                              _group = groupEntry.key;
                              _page = groupEntry.value.first;
                              _search = '';
                            }),
                          ),
                        )),
                        IconButton(
                          tooltip: groupOpen ? 'طي الشاشات' : 'عرض الشاشات',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: () => setState(() {
                            if (groupOpen) {
                              _expandedGroups.remove(groupKey);
                            } else {
                              _expandedGroups.add(groupKey);
                            }
                          }),
                          icon: Icon(groupOpen ? Icons.expand_more_rounded : Icons.chevron_left_rounded, color: groupOpen ? Colors.white : _orange, size: 22),
                        ),
                      ]),
                      if (groupOpen)
                        ...groupEntry.value.map((page) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 20, end: 5),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                            minLeadingWidth: 12,
                            leading: Icon(page == _page && selectedModule ? Icons.radio_button_checked_rounded : Icons.circle_outlined, color: _orange, size: 11),
                            title: Text(page, style: TextStyle(color: page == _page && selectedModule ? Colors.white : Colors.white70, fontSize: 10.5, fontWeight: page == _page && selectedModule ? FontWeight.w800 : FontWeight.normal)),
                            onTap: () => setState(() {
                              _module = name;
                              _group = groupEntry.key;
                              _page = page;
                              _search = '';
                              _expandedModules.add(name);
                              _expandedGroups.add(groupKey);
                            }),
                          ),
                        )),
                    ]),
                  );
                }),
            ]);
          }).toList(),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), selected: _page == 'عن البرنامج', selectedTileColor: Colors.white.withValues(alpha: .14), leading: const Icon(Icons.info_outline_rounded, color: _orange, size: 20), title: const Text('عن البرنامج', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)), onTap: () => setState(() { _page = 'عن البرنامج'; _search = ''; }))),
          ],
        )),
        const Divider(color: Colors.white24, height: 1),
        const Padding(padding: EdgeInsets.all(14), child: Column(children: [
          Text('سلسلة للبرمجيات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('سلسلة .. بنربط السوق ببعضه', style: TextStyle(color: _orange, fontSize: 12)),
        ])),
      ]),
    ),
  );

  IconData _iconFor(String name) {
    if (name.contains('إدارة البرنامج')) return Icons.settings_suggest_rounded;
    if (name.contains('الحسابات')) return Icons.account_balance_rounded;
    if (name.contains('الخزائن')) return Icons.account_balance_wallet_rounded;
    if (name.contains('المخازن')) return Icons.warehouse_rounded;
    if (name.contains('المشتريات')) return Icons.shopping_cart_rounded;
    if (name.contains('المبيعات')) return Icons.point_of_sale_rounded;
    if (name.contains('الموردون')) return Icons.factory_rounded;
    if (name.contains('العملاء')) return Icons.groups_rounded;
    if (name.contains('الموارد')) return Icons.badge_rounded;
    if (name.contains('الرواتب')) return Icons.payments_rounded;
    if (name.contains('الفروع')) return Icons.hub_rounded;
    if (name.contains('المندوبون')) return Icons.delivery_dining_rounded;
    if (name.contains('العروض')) return Icons.campaign_rounded;
    if (name.contains('الدعم')) return Icons.support_agent_rounded;
    return Icons.query_stats_rounded;
  }

  Widget _rightPanel() => Container(
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFECE7F2)))),
    child: SafeArea(child: ListView(padding: const EdgeInsets.all(12), children: [
      if (_notificationsPanelVisible) ...[
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.notifications_active_outlined, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('لوحة التنبيهات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)), child: const Text('3', style: TextStyle(color: _purple, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 12),
            _notice(Icons.inventory_2_outlined, 'مراجعة المخزون', 'راجع حدود إعادة الطلب والصلاحية', _orange),
            _notice(Icons.security_outlined, 'صلاحيات المستخدمين', 'إعداد سياسات الوصول قبل التشغيل', _pink),
            _notice(Icons.cloud_off_outlined, 'الربط بقاعدة البيانات', 'بعض الشاشات ما زالت تجريبية', Colors.white),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      if (_activityPanelVisible) ...[
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.history_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('سجل النشاطات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            ]),
            const SizedBox(height: 12),
            ..._activityLog.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 7, color: _orange),
                const SizedBox(width: 9),
                Expanded(child: Text(entry, style: const TextStyle(fontSize: 11, height: 1.5, color: Colors.white, fontWeight: FontWeight.w800))),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (_quickAccessPanelVisible) ...[
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.star_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('الوصول السريع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 5, runSpacing: 5, children: [
              _quick('قواعد الحضور والانصراف', Icons.access_time_filled_rounded, () => _open('الموارد البشرية والرواتب', 'حركات', 'قواعد الورديات والحضور والانصراف')),
              _quick('شجرة الحسابات', Icons.account_tree_rounded, () => _open('الحسابات المالية', 'بيانات أساسية', 'شجرة الحسابات')),
              _quick('الخزائن', Icons.account_balance_wallet_rounded, () => _open('الحسابات المالية', 'بيانات أساسية', 'الخزائن الرئيسية والفرعية')),
              _quick('دليل الأصناف', Icons.inventory_2_rounded, () => _open('المخازن والفروع', 'بيانات أساسية', 'دليل الأصناف')),
              _quick('دليل العملاء', Icons.groups_rounded, () => _open('المبيعات والعملاء', 'بيانات أساسية', 'دليل العملاء')),
              _quick('ملف الموظف', Icons.badge_rounded, () => _open('الموارد البشرية والرواتب', 'بيانات أساسية', 'ملف الموظف')),
              _quick('قواعد الورديات', Icons.schedule_rounded, () => _open('الموارد البشرية والرواتب', 'حركات', 'قواعد الورديات والحضور والانصراف')),
              _quick('أجهزة البصمة', Icons.fingerprint_rounded, () => _open('الموارد البشرية والرواتب', 'حركات', 'أجهزة البصمة وربط الحضور')),
            ]),
          ]),
        ),
      ],
      if (_notificationsPanelVisible || _activityPanelVisible)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('ملاحظة: التنبيهات وسجل النشاطات حاليًا أمثلة محلية، وليسا متصلين بعد بأحداث النظام الفعلية.', style: TextStyle(color: Colors.black54, fontSize: 10, height: 1.6)),
        ),
      if (!_notificationsPanelVisible && !_activityPanelVisible && !_quickAccessPanelVisible)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('تم إخفاء لوحات المهام. استخدم زر إظهار اللوحات في الشريط العلوي لإعادتها.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.6)),
        ),
    ])),
  );

  Widget _notice(IconData icon, String title, String detail, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white)),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.5, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );

  Widget _appManagement() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _recordToolbar(includeAdd: false),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6E2BA6)]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة التطبيقات', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      Text('مكان موحد لتخصيص الهوية والألوان والصور والصلاحيات وإعدادات التطبيقات التابعة لسلسلة.', style: TextStyle(color: Colors.white70, height: 1.7)),
    ])),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('التطبيقات التابعة لسلسلة', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('إدارة تطبيق سلسلة والتطبيقات الإضافية من مكان واحد؛ التطبيقات غير المنشورة تظل قيد التجهيز دون إظهار قسم مستقل لها.', style: TextStyle(color: Colors.black54, height: 1.6, fontSize: 12)),
      const SizedBox(height: 12),
      _managedAppCard('تطبيق سلسلة', 'التطبيق الرئيسي', Icons.apps_rounded, _selectedAppKey == 'silsila', () => _selectManagedApp('silsila')),
      _managedAppCard('تطبيق رقم 2', 'قيد التجهيز — يمكن استكمال إعداداته هنا', Icons.phone_android_rounded, _selectedAppKey == 'app_2', () => _selectManagedApp('app_2')),
      _managedAppCard('تطبيق رقم 3', 'قيد التجهيز — يمكن استكمال إعداداته هنا', Icons.web_rounded, _selectedAppKey == 'app_3', () => _selectManagedApp('app_3')),
      const Divider(height: 28),
      const Text('هوية التطبيق المحدد', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      TextFormField(key: ValueKey(_selectedAppKey), initialValue: _appName, decoration: const InputDecoration(labelText: 'اسم التطبيق', border: OutlineInputBorder()), onChanged: (v) => _updateManagedAppDraft(name: v)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _colorChoice('بنفسجي', const Color(0xFF3E007D), _appPrimary, (v) => _updateManagedAppDraft(primary: v)),
        _colorChoice('برتقالي', const Color(0xFFFFA015), _appAccent, (v) => _updateManagedAppDraft(accent: v)),
        _colorChoice('وردي', const Color(0xFFFF27C3), _appAccent, (v) => _updateManagedAppDraft(accent: v)),
        _colorChoice('أزرق', const Color(0xFF1565C0), _appAccent, (v) => _updateManagedAppDraft(accent: v)),
      ]),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _appPrimary, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.apps_rounded, color: Colors.white, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_appName.trim().isEmpty ? 'اسم التطبيق' : _appName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const Text('معاينة الألوان المختارة', style: TextStyle(color: Colors.white70, fontSize: 11))])), Container(width: 18, height: 18, decoration: BoxDecoration(color: _appAccent, shape: BoxShape.circle))])),
      const SizedBox(height: 18),
      const Text('إدارة الملفات والصور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 8),
      _managementTile(Icons.image_outlined, 'شعار التطبيق وصورة البداية', 'تحديد ملفات الهوية التي ستستخدم عند ربط رفع الملفات'),
      _managementTile(Icons.category_outlined, 'صور الأصناف والفئات', 'إضافة صور المنتجات وتصنيفات المواد الغذائية'),
      _managementTile(Icons.factory_outlined, 'صور الموردين والعملاء', 'إدارة الشعارات والصور والبيانات التعريفية'),
      _managementTile(Icons.local_shipping_outlined, 'شركات الشحن', 'صور الشركات وبيانات التواصل وخيارات التوصيل'),
      const SizedBox(height: 18),
      const Text('صلاحيات الأدوار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _selectedPermissionRole,
        decoration: const InputDecoration(labelText: 'الدور الوظيفي', border: OutlineInputBorder()),
        items: ErpAppPermissionCatalog.roles.entries
            .map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: _permissionsLoading ? null : (value) {
          if (value == null) return;
          setState(() => _selectedPermissionRole = value);
          _loadPermissionsForSelectedApp();
        },
      ),
      const SizedBox(height: 8),
      if (_permissionsLoading)
        const LinearProgressIndicator(minHeight: 2),
      Wrap(
        spacing: 6,
        runSpacing: 2,
        children: ErpAppPermissionCatalog.permissions.entries.map((entry) {
          final enabled = _managedPermissions[entry.key] ?? false;
          return FilterChip(
            label: Text(entry.value, style: const TextStyle(fontSize: 11)),
            selected: enabled,
            onSelected: (value) => _changeManagedPermission(entry.key, value),
            selectedColor: const Color(0xFFE9DDF8),
            checkmarkColor: _purple,
          );
        }).toList(),
      ),
      const SizedBox(height: 6),
      const Text('تُحفظ كل صلاحية منفردة في Supabase. لا تُعد هذه الواجهة بديلًا عن تحقق الخادم وسياسات RLS.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.6)),
      const SizedBox(height: 18),
      const Text('سجل النشاطات المحفوظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 6),
      if (_savedAppActivity.isEmpty)
        const Text('لا توجد أحداث محفوظة للتطبيق أو أن سجل النشاطات غير مهيأ.', style: TextStyle(color: Colors.black54, fontSize: 11))
      else
        ..._savedAppActivity.map((entry) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_rounded, color: _orange, size: 18),
          title: Text('${entry.action} • ${entry.entityType}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: Text('${entry.createdAt.toLocal()} • ${entry.entityId}', style: const TextStyle(fontSize: 10)),
        )),
      const SizedBox(height: 12),
      if (_appManagementMessage != null)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _appManagementMessage!.startsWith('تم حفظ') || _appManagementMessage!.startsWith('تم تحميل')
                ? const Color(0xFFEAF7EF)
                : const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_appManagementMessage!, style: const TextStyle(fontSize: 12, height: 1.5)),
        ),
      FilledButton.icon(
        onPressed: _appManagementSaving ? null : _saveManagedAppToCloud,
        icon: _appManagementSaving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(_appManagementSaving ? 'جارٍ الحفظ...' : 'حفظ الاسم والألوان في قاعدة البيانات'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _appManagementLoading ? null : _loadManagedAppsFromCloud,
        icon: const Icon(Icons.cloud_download_outlined),
        label: Text(_appManagementLoading ? 'جارٍ تحميل الإعدادات...' : 'إعادة تحميل الإعدادات المحفوظة'),
      ),
      const SizedBox(height: 8),
      const Text('الحفظ الدائم يعمل بعد تهيئة Supabase وتطبيق جداول إدارة التطبيقات وسياسات RLS المقيدة بالشركة. لم يتم ربط رفع الصور أو فرض الصلاحيات من هذه الأزرار.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.7)),
    ])),
  ]);

  Widget _managedAppCard(String title, String subtitle, IconData icon, bool active, VoidCallback onTap) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    color: active ? const Color(0xFFFFF7EB) : const Color(0xFFFCFAFD),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(color: active ? _orange : const Color(0xFFECE7F2)),
    ),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: _orange),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Icon(active ? Icons.check_circle_rounded : Icons.tune_rounded, color: active ? _orange : _pink, size: 20),
    ),
  );

  Widget _colorChoice(String label, Color color, Color selected, ValueChanged<Color> onSelect) => OutlinedButton(
    onPressed: () => onSelect(color),
    style: OutlinedButton.styleFrom(side: BorderSide(color: selected == color ? _pink : const Color(0xFFECE7F2), width: selected == color ? 2 : 1), overlayColor: _pink.withValues(alpha: .10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Text(label)]),
  );

  Widget _managementTile(IconData icon, String title, String detail) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _purple)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    subtitle: Text(detail, style: const TextStyle(fontSize: 11, height: 1.5)),
    trailing: const Icon(Icons.chevron_left_rounded, color: _purple),
    onTap: () {
      final target = switch (title) {
        'شعار التطبيق وصورة البداية' => 'إدارة الشعار والصور',
        'صور الأصناف والفئات' => 'إدارة صور الأصناف والفئات',
        'صور الموردين والعملاء' => 'إدارة صور الموردين والعملاء',
        'شركات الشحن' => 'إدارة شركات الشحن',
        _ => 'إعدادات هوية التطبيق',
      };
      setState(() {
        _module = 'إدارة التطبيقات';
        _group = 'بيانات أساسية';
        _page = target;
        _selectedRecord = null;
      });
    },
  );

  Widget _header(bool compact) => Container(height: 76, padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE7F2)))), child: Row(children: [
    Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsetsDirectional.only(end: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7DDF1)),
      ),
      child: Image.asset('assets/images/silsila_logo.png', fit: BoxFit.contain),
    ),
    if (compact)
      Builder(builder: (ctx) => IconButton(
        tooltip: 'عرض القوائم الرئيسية',
        onPressed: () => Scaffold.of(ctx).openDrawer(),
        icon: const Icon(Icons.menu_rounded, color: _purple),
      ))
    else
      IconButton(
        tooltip: _sidebarVisible ? 'إخفاء جميع القوائم الرئيسية' : 'إظهار جميع القوائم الرئيسية',
        onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
        icon: Icon(Icons.menu_rounded, color: _purple),
      ),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_module, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: _goHome,
            borderRadius: BorderRadius.circular(5),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              child: Text('الرئيسية', style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
            ),
          ),
          const Text('/', style: TextStyle(color: Colors.black45, fontSize: 11)),
          InkWell(
            onTap: () {
              final groups = _modules[_module]!;
              _open(_module, groups.keys.first, groups.values.first.first);
            },
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              child: Text(_module, style: const TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
            ),
          ),
          const Text('/', style: TextStyle(color: Colors.black45, fontSize: 11)),
          Text(_page, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    ])),
    if (!compact) SizedBox(width: 190, child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'بحث سريع', prefixIcon: const Icon(Icons.search_rounded), isDense: true, filled: true, fillColor: _canvas, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
    const SizedBox(width: 4),
    if (!compact) ...[
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: (_notificationsPanelVisible || _activityPanelVisible || _quickAccessPanelVisible)
            ? 'إخفاء لوحات المهام الثلاث'
            : 'إظهار لوحات المهام الثلاث',
        onPressed: () => setState(() {
          final showPanels = !(_notificationsPanelVisible || _activityPanelVisible || _quickAccessPanelVisible);
          _notificationsPanelVisible = showPanels;
          _activityPanelVisible = showPanels;
          _quickAccessPanelVisible = showPanels;
        }),
        icon: const Icon(Icons.menu_rounded, color: _purple),
      ),
    ],
    IconButton(visualDensity: VisualDensity.compact, tooltip: 'الإشعارات', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مركز الإشعارات التجريبي'))), icon: const Icon(Icons.notifications_none_rounded, color: _purple)),
    const CircleAvatar(radius: 18, backgroundColor: Color(0xFFF0E7FA), child: Icon(Icons.person_rounded, color: _purple, size: 20)),
  ]));

  double? get _executiveLast7Sales => _executiveDailySales.isEmpty ? null : _executiveDailySales.fold<double>(0,(sum,value)=>sum+value);

  String _executiveMoney(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => match[1]! + ',',
    ) + ' ج.م';
  }

  Future<void> _loadExecutiveMetrics(String companyId) async {
    if (!mounted || companyId.isEmpty) return;
    setState(() {
      _executiveMetricsLoading = true;
      _executiveMetricsError = null;
    });
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    try {
      final result = await Supabase.instance.client.rpc(
        'erp_get_executive_metrics',
        params: {
          'p_company_id': companyId,
          'p_month_start': monthStart.toIso8601String().substring(0, 10),
          'p_month_end': nextMonth.toIso8601String().substring(0, 10),
        },
      );
      final data = Map<String, dynamic>.from(result as Map);
      double? numberValue(String key) {
        final value = data[key];
        return value == null ? null : double.tryParse(value.toString());
      }
      List<double> numberList(String key) {
        final raw = data[key];
        if (raw is! List) return <double>[];
        return raw.map((value) => double.tryParse(value.toString()) ?? 0).toList();
      }
      List<String> stringList(String key) {
        final raw = data[key];
        if (raw is! List) return <String>[];
        return raw.map((value) => value.toString()).toList();
      }
      if (!mounted) return;
      setState(() {
        _executiveSales = numberValue('sales');
        _executiveCollections = numberValue('collections');
        _executiveReceivables = numberValue('receivables');
        _executivePurchases = numberValue('purchases');
        _executiveGrossProfit = numberValue('gross_profit_estimate');
        _executiveInventoryValue = numberValue('inventory_value_estimate');
        _executiveDailySales = numberList('daily_sales');
        _executiveDailyCollections = numberList('daily_collections');
        _executiveInventoryGroupLabels = stringList('inventory_group_labels');
        _executiveInventoryGroupValues = numberList('inventory_group_values');
        _executiveMetricsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _executiveMetricsError = error.toString();
        _executiveMetricsLoading = false;
      });
    }
  }

  Widget _home() {
    final sections = <Map<String, Object>>[
      {
        'title': 'المبيعات والعملاء',
        'icon': Icons.point_of_sale_rounded,
        'color': _purple,
        'items': <Map<String, Object>>[
          {'title': 'صافي المبيعات', 'value': _executiveMoney(_executiveSales), 'note': 'الشهر الحالي • فواتير مرحلة', 'icon': Icons.point_of_sale_rounded, 'color': _purple, 'details': 'إجمالي فواتير البيع بعد خصم المرتجعات والخصومات، مع مقارنة يومية وشهرية وبحسب الفرع والمندوب.'},
          {'title': 'نمو المبيعات', 'value': '—%', 'note': 'عن الفترة السابقة', 'icon': Icons.trending_up_rounded, 'color': _green, 'details': 'نسبة نمو صافي المبيعات ومقارنة الأداء بالفترة السابقة والمستهدف.'},
          {'title': 'متوسط الفاتورة', 'value': '— ج.م', 'note': 'لكل فاتورة', 'icon': Icons.receipt_long_rounded, 'color': _orange, 'details': 'متوسط قيمة فاتورة البيع وتحليل التغير حسب العميل والمندوب والفرع.'},
          {'title': 'أفضل العملاء', 'value': '—', 'note': 'حسب قيمة الشراء', 'icon': Icons.groups_rounded, 'color': _pink, 'details': 'ترتيب العملاء حسب المبيعات والربحية وانتظام السداد.'},
          {'title': 'العملاء المتوقفون', 'value': '—', 'note': 'دون شراء حديث', 'icon': Icons.person_off_outlined, 'color': _orange, 'details': 'العملاء الذين لم يشتروا خلال الفترة المحددة مع قيمة مشترياتهم السابقة.'},
          {'title': 'مرتجعات المبيعات', 'value': '—%', 'note': 'من المبيعات', 'icon': Icons.assignment_return_outlined, 'color': _pink, 'details': 'قيمة ونسبة المرتجعات وأسبابها والأصناف والعملاء الأعلى في المرتجعات.'},
        ],
      },
      {
        'title': 'المالية والسيولة',
        'icon': Icons.account_balance_wallet_outlined,
        'color': _green,
        'items': <Map<String, Object>>[
          {'title': 'مجمل الربح التقديري', 'value': _executiveMoney(_executiveGrossProfit), 'note': 'على تكلفة الشراء الحالية', 'icon': Icons.account_balance_rounded, 'color': _green, 'details': 'صافي الربح بعد تكلفة المبيعات والمصروفات وفق القيود المحاسبية المرحلة.'},
          {'title': 'المدفوع على الفواتير', 'value': _executiveMoney(_executiveCollections), 'note': 'المدفوع المسجل على فواتير البيع', 'icon': Icons.payments_outlined, 'color': _green, 'details': 'المبالغ المحصلة والمتبقية ومعدل التحصيل حسب العميل والمندوب والفترة.'},
          {'title': 'ديون العملاء', 'value': _executiveMoney(_executiveReceivables), 'note': 'فواتير مرحلة غير مسددة بالكامل', 'icon': Icons.groups_rounded, 'color': _pink, 'details': 'أرصدة العملاء وأعمار الديون والمتأخرات وحدود الائتمان.'},
          {'title': 'مستحقات الموردين', 'value': '— ج.م', 'note': 'مواعيد الاستحقاق', 'icon': Icons.local_shipping_outlined, 'color': _orange, 'details': 'أرصدة الموردين ومواعيد الاستحقاق وأعمار الديون وخطة السداد.'},
          {'title': 'السيولة المتاحة', 'value': '— ج.م', 'note': 'الخزائن والبنوك', 'icon': Icons.account_balance_wallet_rounded, 'color': _purple, 'details': 'الأرصدة المتاحة في الخزائن والحسابات البنكية وحركة النقدية.'},
          {'title': 'المصروفات', 'value': '— ج.م', 'note': 'من الإيرادات —%', 'icon': Icons.money_off_csred_outlined, 'color': _pink, 'details': 'تحليل المصروفات حسب النوع والفرع ومركز التكلفة ومقارنتها بالإيرادات.'},
        ],
      },
      {
        'title': 'المخزون والمشتريات',
        'icon': Icons.warehouse_outlined,
        'color': const Color(0xFF2475B8),
        'items': <Map<String, Object>>[
          {'title': 'قيمة المخزون', 'value': _executiveMoney(_executiveInventoryValue), 'note': 'تقدير بتكلفة الشراء الحالية', 'icon': Icons.inventory_2_outlined, 'color': const Color(0xFF2475B8), 'details': 'قيمة المخزون المتاح والمحجوز حسب المخزن والفرع والصنف.'},
          {'title': 'تحت حد الطلب', 'value': '— صنف', 'note': 'بحاجة للشراء', 'icon': Icons.warning_amber_rounded, 'color': _orange, 'details': 'الأصناف التي وصلت إلى حد إعادة الطلب والكميات المقترحة للشراء.'},
          {'title': 'قرب انتهاء الصلاحية', 'value': '— صنف', 'note': 'خلال 30 / 60 / 90 يومًا', 'icon': Icons.event_busy_outlined, 'color': _pink, 'details': 'الأصناف القريبة من انتهاء الصلاحية مع الكميات والقيمة والمخزن.'},
          {'title': 'الأصناف الراكدة', 'value': '— صنف', 'note': 'بلا حركة', 'icon': Icons.inventory_outlined, 'color': _orange, 'details': 'الأصناف التي لم تتحرك خلال فترة محددة وقيمة رأس المال المجمد بها.'},
          {'title': 'دوران المخزون', 'value': '— مرة', 'note': 'خلال الفترة', 'icon': Icons.sync_alt_rounded, 'color': _purple, 'details': 'معدل دوران المخزون ومتوسط أيام التخزين حسب المجموعة والصنف.'},
          {'title': 'تغير تكلفة الشراء', 'value': '—%', 'note': 'مقارنة بآخر شراء', 'icon': Icons.price_change_outlined, 'color': const Color(0xFF2475B8), 'details': 'تغير تكلفة الشراء ومقارنة أسعار الصنف بين الموردين.'},
        ],
      },
      {
        'title': 'الطلبات والتوزيع',
        'icon': Icons.local_shipping_outlined,
        'color': _orange,
        'items': <Map<String, Object>>[
          {'title': 'طلبات قيد التنفيذ', 'value': '— طلب', 'note': 'في مراحل التشغيل', 'icon': Icons.sync_rounded, 'color': _purple, 'details': 'الطلبات حسب حالة القبول والتجهيز والتحميل والتسليم.'},
          {'title': 'طلبات متأخرة', 'value': '— طلب', 'note': 'تجاوزت الموعد', 'icon': Icons.pending_actions_rounded, 'color': _pink, 'details': 'الطلبات المتأخرة وأسباب التأخير والمسؤول وموعد التسليم المتوقع.'},
          {'title': 'التسليم في الموعد', 'value': '—%', 'note': 'من إجمالي الطلبات', 'icon': Icons.task_alt_rounded, 'color': _green, 'details': 'نسبة التسليم في الموعد ومقارنة أداء الفروع والمندوبين وشركات الشحن.'},
          {'title': 'أداء المندوبين', 'value': '—%', 'note': 'تنفيذ وتحصيل', 'icon': Icons.badge_outlined, 'color': _orange, 'details': 'مبيعات المندوب وتحصيلاته والطلبات المسلمة والمرتجعات.'},
          {'title': 'تكلفة التوزيع', 'value': '— ج.م', 'note': 'لكل طلب / رحلة', 'icon': Icons.route_outlined, 'color': const Color(0xFF2475B8), 'details': 'تكلفة الرحلات والتوصيل مقارنة بقيمة المبيعات وعدد الطلبات.'},
          {'title': 'طلبات ملغاة', 'value': '— طلب', 'note': 'نسبة الإلغاء —%', 'icon': Icons.cancel_outlined, 'color': _pink, 'details': 'عدد وقيمة الطلبات الملغاة مع تحليل أسباب الإلغاء.'},
        ],
      },
      {
        'title': 'الموظفون والفروع',
        'icon': Icons.business_outlined,
        'color': _pink,
        'items': <Map<String, Object>>[
          {'title': 'حضور الموظفين', 'value': '—%', 'note': 'اليوم / الشهر', 'icon': Icons.groups_outlined, 'color': _green, 'details': 'الحضور والغياب والتأخير والإجازات بحسب الفرع والإدارة.'},
          {'title': 'تكلفة الرواتب', 'value': '— ج.م', 'note': 'والعمولات', 'icon': Icons.payments_rounded, 'color': _purple, 'details': 'الرواتب والعمولات والاستقطاعات والسلف والمستحقات.'},
          {'title': 'أداء الفروع', 'value': '—%', 'note': 'مقارنة بالمستهدف', 'icon': Icons.domain_outlined, 'color': _orange, 'details': 'مقارنة الفروع في المبيعات والربحية والتحصيل والمخزون والمصروفات.'},
          {'title': 'عهد المندوبين', 'value': '— ج.م', 'note': 'قيد التسوية', 'icon': Icons.assignment_ind_outlined, 'color': _pink, 'details': 'العهد النقدية والبضائع المسلمة للمندوبين وما تم تحصيله أو تسويته.'},
        ],
      },
      {
        'title': 'الرقابة والتنبيهات',
        'icon': Icons.fact_check_outlined,
        'color': _purple,
        'items': <Map<String, Object>>[
          {'title': 'بانتظار الاعتماد', 'value': '— حركة', 'note': 'مستندات وقيود', 'icon': Icons.approval_rounded, 'color': _orange, 'details': 'المستندات والقيود التي تنتظر الاعتماد مع تاريخ الإنشاء والمسؤول.'},
          {'title': 'ملاحظات الحركات', 'value': '— ملاحظة', 'note': 'تحتاج مراجعة', 'icon': Icons.rule_folder_outlined, 'color': _pink, 'details': 'الحركات التي تحتاج إلى مراجعة أو استكمال بيانات أو تصحيح الربط.'},
          {'title': 'تجاوز الائتمان', 'value': '— عميل', 'note': 'تجاوز الحد المعتمد', 'icon': Icons.credit_score_outlined, 'color': _orange, 'details': 'العملاء الذين تجاوزوا حدود الائتمان مع الرصيد والحد المعتمد.'},
          {'title': 'اكتمال البيانات', 'value': '—%', 'note': 'البيانات الأساسية', 'icon': Icons.checklist_rounded, 'color': _green, 'details': 'مؤشر اكتمال البيانات الأساسية واكتشاف الحقول الناقصة والمكررة.'},
        ],
      },
    ];

    final allItems = sections.expand((section) => section['items'] as List<Map<String, Object>>).toList();

    return LayoutBuilder(builder: (context, outerConstraints) {
      final wide = outerConstraints.maxWidth >= 900;
      final mid = outerConstraints.maxWidth >= 600;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [Color(0xFF3E007D), Color(0xFF6330A0), Color(0xFF8A50B7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x183E007D), blurRadius: 18, offset: Offset(0, 7))],
          ),
          child: Row(children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .22))),
              child: const Icon(Icons.insights_rounded, color: _orange, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الملخص التنفيذي', style: TextStyle(fontSize: 29, height: 1.2, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.3)),
              const SizedBox(height: 6),
              const Text('مركز قيادة الأداء المالي والتشغيلي • مؤشرات وتحليلات موحدة للإدارة', style: TextStyle(color: Color(0xFFECE2F8), fontSize: 15, height: 1.5)),
              const SizedBox(height: 5),
              Text(_appManagementCompanyId == null ? 'اختر شركة نشطة لعرض المؤشرات الفعلية' : _executiveMetricsLoading ? 'جارٍ تحميل الحركات المرحلة من قاعدة البيانات…' : _executiveMetricsError != null ? 'تعذر تحميل بعض المؤشرات؛ راجع إعدادات قاعدة البيانات' : 'المؤشرات الرئيسية من الحركات المرحلة؛ بقية المؤشرات حسب اكتمال الربط', style: const TextStyle(color: Color(0xFFFFDDA8), fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 12),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'تحديث الملخص',
                onPressed: () { final companyId = _appManagementCompanyId; if (companyId != null) _loadExecutiveMetrics(companyId); },
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .12), foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh_rounded, size: 24),
              ),
              _summaryAction('كل التحليلات', () => _showExecutiveCategoryDetails('جميع التحليلات', allItems)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000 ? 6 : constraints.maxWidth >= 650 ? 3 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 6 ? 1.25 : columns == 3 ? 1.35 : 1.2,
            children: [
              _executiveKpi('صافي المبيعات', _executiveMoney(_executiveSales), 'الشهر الحالي • فواتير مرحلة', Icons.point_of_sale_rounded, _purple),
              _executiveKpi('مجمل الربح التقديري', _executiveMoney(_executiveGrossProfit), 'على تكلفة الشراء الحالية', Icons.trending_up_rounded, _green),
              _executiveKpi('المحصّل على الفواتير', _executiveMoney(_executiveCollections), 'المدفوع المسجل بالفواتير', Icons.payments_outlined, _orange),
              _executiveKpi('مديونية العملاء', _executiveMoney(_executiveReceivables), 'فواتير غير مسددة بالكامل', Icons.groups_rounded, _pink),
              _executiveKpi('قيمة المخزون', _executiveMoney(_executiveInventoryValue), 'من حركات المخزون والتكلفة الحالية', Icons.inventory_2_rounded, const Color(0xFF2475B8)),
              _executiveKpi('مشتريات الشهر', _executiveMoney(_executivePurchases), 'فواتير شراء مرحلة وغير تجريبية', Icons.local_shipping_outlined, const Color(0xFF168A70)),
            ],
          );
        }),
        const SizedBox(height: 16),
        if (wide || mid)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _executiveChartPanel(
                title: 'اتجاه المبيعات',
                caption: 'آخر 7 أيام • فواتير مرحلة وغير تجريبية',
                color: _purple,
                value: _executiveMoney(_executiveSales),
                chart: _ExecutiveChartPainter(color: _purple, values: _executiveDailySales),
              )),
              const SizedBox(width: 12),
              Expanded(child: _executiveChartPanel(
                title: 'مزيج الأداء',
                caption: 'مبيعات • مشتريات • المحصّل',
                color: _orange,
                value: _executiveMoney(_executivePurchases),
                chart: _ExecutiveBarsPainter(values: <double>[_executiveSales ?? 0, _executivePurchases ?? 0, _executiveCollections ?? 0]),
              )),
            ]),
            const SizedBox(height: 12),
            _executiveHighlights(),
          ])
        else ...[
          _executiveChartPanel(
            title: 'اتجاه المبيعات',
            caption: 'آخر 7 أيام • فواتير مرحلة وغير تجريبية',
            color: _purple,
            value: _executiveMoney(_executiveSales),
            chart: const _ExecutiveChartPainter(color: _purple),
          ),
          const SizedBox(height: 3),
          _executiveChartPanel(
            title: 'مزيج الأداء',
            caption: 'مبيعات • مشتريات • المحصّل',
            color: _orange,
            value: _executiveMoney(_executivePurchases),
            chart: _ExecutiveBarsPainter(values: <double>[_executiveSales ?? 0, _executivePurchases ?? 0, _executiveCollections ?? 0]),
          ),
          const SizedBox(height: 12),
          _executiveHighlights(),
        ],
        const SizedBox(height: 16),
        _executiveAdditionalCharts(sideBySide: wide || mid),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1150 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: columns == 3 ? 1.0 : columns == 2 ? 1.05 : 1.0,
            children: sections.map((section) => _executiveSectionCompact(
              title: section['title'] as String,
              icon: section['icon'] as IconData,
              color: section['color'] as Color,
              items: section['items'] as List<Map<String, Object>>,
            )).toList(),
          );
        }),
        const SizedBox(height: 4),
        const Row(children: [
          Icon(Icons.info_outline_rounded, color: _orange, size: 11),
          SizedBox(width: 4),
          Expanded(child: Text('المؤشرات الرقمية والمخططات توضيحية حتى ربطها بالحركات الفعلية المعتمدة.', style: TextStyle(fontSize: 11, color: Colors.black54))),
        ]),
      ]);
    });
  }

  Widget _summaryAction(String label, VoidCallback onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 25),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label, style: const TextStyle(color: _purple, fontSize: 12, fontWeight: FontWeight.w800)),
  );

  Widget _executiveChartPanel({
    List<String> footerLabels = const <String>['بداية الفترة','منتصف الفترة','اليوم'],
    required String title,
    required String caption,
    required Color color,
    required String value,
    required CustomPainter chart,
  }) => Container(
    height: 264,
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E0EF)),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, color: _purple, fontWeight: FontWeight.w900))),
        Text(value, style: TextStyle(fontSize: 21, color: color, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 4),
      Text(caption, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      const SizedBox(height: 8),
      Expanded(child: CustomPaint(painter: chart, child: const SizedBox.expand())),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: footerLabels.take(3).map((label) => Expanded(
        child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
      )).toList()),
    ]),
  );

  Widget _executiveAdditionalCharts({required bool sideBySide}) {
    final charts = <Widget>[
      _executiveChartPanel(
        title: 'المدفوع المسجل على الفواتير',
        caption: 'آخر 7 أيام • بيانات الفواتير المرحلة',
        color: const Color(0xFF168A70),
        value: _executiveMoney(_executiveCollections),
        chart: _ExecutiveChartPainter(color: const Color(0xFF168A70), values: _executiveDailyCollections),
      ),
      _executiveChartPanel(
        title: 'قيمة المخزون حسب المجموعة',
        caption: 'تقدير على تكلفة الشراء الحالية',
        color: _pink,
        value: _executiveMoney(_executiveInventoryValue),
        chart: _ExecutiveBarsPainter(values: _executiveInventoryGroupValues),
        footerLabels: _executiveInventoryGroupLabels.isEmpty
            ? const <String>['مجموعة 1','مجموعة 2','مجموعة 3']
            : _executiveInventoryGroupLabels.take(3).toList(),
      ),
    ];
    if (sideBySide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: charts[0]),
        const SizedBox(width: 12),
        Expanded(child: charts[1]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      charts[0],
      const SizedBox(height: 12),
      charts[1],
    ]);
  }

  Widget _executiveHighlights() => Container(
    height: 226,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E0EF)),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('مؤشرات تحتاج متابعة', style: TextStyle(fontSize: 20, color: _purple, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      _executiveHighlightRow('مديونية العملاء', _executiveMoney(_executiveReceivables), _pink),
      _executiveHighlightRow('مبيعات آخر 7 أيام', _executiveMoney(_executiveLast7Sales), _purple),
      _executiveHighlightRow('مشتريات الشهر', _executiveMoney(_executivePurchases), _orange),
      _executiveHighlightRow('قيمة المخزون التقديرية', _executiveMoney(_executiveInventoryValue), const Color(0xFF2475B8)),
    ]),
  );

  Widget _executiveHighlightRow(String label, String value, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 9),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Flexible(child: Text(value, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w900))),
      ]),
    ),
  );

  Widget _executiveSectionCompact({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, Object>> items,
  }) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E0EF)), boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w900))),
        _summaryAction('عرض الكل', () => _showExecutiveCategoryDetails(title, items)),
      ]),
      const Divider(height: 14, thickness: 1, color: Color(0xFFEFEAF4)),
      ...items.map((item) => _executiveCompactMetric(
        title: item['title'] as String,
        value: item['value'] as String,
        note: item['note'] as String,
        icon: item['icon'] as IconData,
        color: item['color'] as Color,
        details: item['details'] as String,
      )),
    ]),
  );

  Widget _executiveCompactMetric({
    required String title,
    required String value,
    required String note,
    required IconData icon,
    required Color color,
    required String details,
  }) => InkWell(
    onTap: () => _showExecutiveAnalysisDetails(title, value, note, details, color),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Color(0xFF342B3C), fontWeight: FontWeight.w800, height: 1.2)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black45, height: 1.2)),
        ])),
        const SizedBox(width: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_left_rounded, size: 16, color: Colors.black38),
      ]),
    ),
  );

  void _showExecutiveCategoryDetails(String title, List<Map<String, Object>> items) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('التحليلات • $title', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: items.map((item) => ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            leading: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 18),
            title: Text(item['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            subtitle: Text(item['note'] as String, style: const TextStyle(fontSize: 11)),
            trailing: Text(item['value'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: item['color'] as Color)),
            onTap: () {
              Navigator.pop(dialogContext);
              _showExecutiveAnalysisDetails(item['title'] as String, item['value'] as String, item['note'] as String, item['details'] as String, item['color'] as Color);
            },
          )).toList())),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showExecutiveAnalysisDetails(String title, String value, String note, String details, Color color) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(note, style: const TextStyle(color: Colors.black54, fontSize: 10)),
          const SizedBox(height: 10),
          Text(details, style: const TextStyle(fontSize: 11, height: 1.6)),
          const SizedBox(height: 7),
          const Text('تظهر النتائج الرقمية التفصيلية بعد ربط المؤشر بالحركات الفعلية المعتمدة.', style: TextStyle(color: Colors.black54, fontSize: 9, height: 1.4)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  static const Color _green = Color(0xFF18865A);

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
  ]);

  Widget _executiveKpi(String title, String value, String note, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6DDED)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 25)),
          const SizedBox(width: 11),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, maxLines: 1, style: TextStyle(color: color, fontSize: 25, fontWeight: FontWeight.w900))),
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 13)),
          ])),
        ]),
      );

  Widget _executivePanel({required String title, required String subtitle, required IconData icon, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE6DDED)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFFF0E7FA), borderRadius: BorderRadius.circular(5)), child: Icon(icon, color: _purple, size: 13)),
            const SizedBox(width: 5),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: _purple, fontSize: 12, fontWeight: FontWeight.w900)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 10)),
            ])),
          ]),
          const SizedBox(height: 3),
          child,
        ]),
      );

  Widget _executiveProgress(String label, String value, double? progress, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w700))),
          Text(value, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 4,
            color: const Color(0xFFEFEAF4),
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: (progress ?? 0.0).clamp(0.0, 1.0).toDouble(),
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ]);

  Widget _executiveMiniStat(String title, String value, IconData icon, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w700))),
        Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)),
      ]);

  Widget _dashboardPanel(String title, IconData icon, List<Widget> metrics, {String? footer, List<Widget> actions = const []}) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8E0F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF0E7FA), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _purple, size: 20)),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(color: _purple, fontSize: 15, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 13),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 650 ? 3 : constraints.maxWidth >= 400 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: columns == 1 ? 4.3 : columns == 2 ? 2.7 : 2.15,
              children: metrics,
            );
          }),
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(footer, style: const TextStyle(color: Colors.black54, fontSize: 11, height: 1.6)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ]),
      );

  Widget _dashboardMetric(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFAF8FC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFECE7F2))),
        child: Row(children: [
          Container(width: 33, height: 33, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 10, height: 1.3, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
          ])),
        ]),
      );

  Widget _dashboardBreakdown(String title, IconData icon, List<String> labels) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8E0F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: _purple, size: 21),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(color: _purple, fontSize: 14, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12),
          ...labels.map((label) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(children: [
              SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 12, decoration: BoxDecoration(color: const Color(0xFFECE7F2), borderRadius: BorderRadius.circular(8)))),
              const SizedBox(width: 10),
              const Text('—', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900)),
            ]),
          )),
          const Text('لا توجد قيم مرسومة بعد؛ أطوال الأعمدة والقيم ستُحسب من بيانات النظام الفعلية.', style: TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
      );

  Widget _dashboardRankingPanel(String title, IconData icon, VoidCallback onViewAll) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8E0F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: _purple, size: 21),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(color: _purple, fontSize: 14, fontWeight: FontWeight.w900))),
            TextButton(onPressed: onViewAll, child: const Text('عرض الكل', style: TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const Divider(height: 14),
          ...List.generate(5, (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(width: 25, height: 25, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF0E7FA), borderRadius: BorderRadius.circular(8)), child: Text('\${index + 1}', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 11))),
              const SizedBox(width: 9),
              Expanded(child: Text('بانتظار بيانات \${index + 1}', style: const TextStyle(color: Colors.black54, fontSize: 11))),
              const Text('—', style: TextStyle(color: _purple, fontWeight: FontWeight.w900)),
            ]),
          )),
          const Text('سيتم ترتيب القائمة بالقيمة أو نسبة تحقيق الهدف وفق نوع التحليل بعد ربط البيانات.', style: TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
      );

  Widget _dashboardAction(String title, VoidCallback onPressed) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: _purple, side: const BorderSide(color: Color(0xFFD8C3EF)), visualDensity: VisualDensity.compact),
        child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      );

  void _goHome() => setState(() {
    _module = 'إدارة البرنامج';
    _group = 'بيانات أساسية';
    _page = 'بيانات الشركة';
    _search = '';
    _selectedRecord = null;
  });

  void _open(String module, String group, String page) {
    setState(() {
      _module = module;
      _group = group;
      _page = page;
      _search = '';
      _selectedRecord = null;
      _expandedModules.add(module);
      _expandedGroups.add('$module::$group');
    });
    _loadWorkspacePage(page);
  }

  Future<void> _loadWorkspacePage(String page) async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.trim().isEmpty ||
        _cloudLoadedWorkspacePages.contains(page) ||
        !_workspacePageLoadsInProgress.add(page)) return;
    try {
      final records = await _workspaceRecordsService.listPage(companyId: companyId, pageKey: page);
      if (!mounted || companyId != _appManagementCompanyId) return;
      setState(() {
        _saved[page] = records;
        _cloudLoadedWorkspacePages.add(page);
      });
    } catch (error) {
      if (mounted) _showActionMessage('تعذر تحميل بيانات "$page" من قاعدة البيانات. تأكد من تطبيق supabase/erp_workspace_records.sql وصلاحيات العضوية. $error');
    } finally {
      _workspacePageLoadsInProgress.remove(page);
    }
  }

  Widget _quick(String title, IconData icon, VoidCallback action) => OutlinedButton.icon(
    onPressed: action,
    icon: Icon(icon, size: 15, color: _orange),
    label: Text(title, softWrap: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, height: 1.1)),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      iconColor: _orange,
      backgroundColor: _purple,
      overlayColor: Colors.white24,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      side: const BorderSide(color: _purple),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
    ),
  );

  Widget _workspace() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(spacing: 8, runSpacing: 8, children: _modules[_module]!.keys.map((g) {
      final selected = g == _group;
      return ChoiceChip(label: Text(g), selected: selected, selectedColor: _purple, labelStyle: TextStyle(color: selected ? Colors.white : _purple, fontWeight: FontWeight.w700), onSelected: (_) { final targetPage = _modules[_module]![g]!.first; setState(() { _group = g; _page = targetPage; _search = ''; }); _loadWorkspacePage(targetPage); });
    }).toList()),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final titleBlock = Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(13)), child: Icon(_iconFor(_module), color: _purple)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_page, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _purple)),
            const SizedBox(height: 4),
            Text('$_module • $_group', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ])),
        ]);
        final toolbar = _recordToolbar(includeAdd: _group != 'تقارير');
        if (constraints.maxWidth >= 760) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            Flexible(child: Align(alignment: Alignment.centerLeft, child: toolbar)),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleBlock,
          const SizedBox(height: 12),
          toolbar,
        ]);
      }),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: _pages.map((p) => ActionChip(
        label: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: p == _page ? const Color(0xFF6E2BA6) : _purple,
        side: BorderSide(color: p == _page ? _orange : const Color(0xFF6E2BA6), width: p == _page ? 2 : 1),
        onPressed: () { setState(() { _page = p; _selectedRecord = null; }); _loadWorkspacePage(p); },
      )).toList()),
      const SizedBox(height: 16),
      if (_group == 'تقارير') const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('نموذج تقارير تجريبي؛ ستظهر المؤشرات الفعلية بعد ربط مصادر البيانات واعتماد المعادلات المحاسبية.', style: TextStyle(color: Colors.black54, height: 1.6))),
      if (_rows.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد نتائج مطابقة.', textAlign: TextAlign.center))
      else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F0FA)), showCheckboxColumn: true, columns: _rows.first.keys.where((k) => k != '_مرجع داخلي').map((k) => DataColumn(label: Text(k, style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)))).toList(), rows: _rows.map((r) => DataRow(selected: _selectedRecord != null && _sameRecord(r, _selectedRecord!), onSelectChanged: (selected) => setState(() => _selectedRecord = selected == true ? Map<String, String>.from(r) : null), cells: _rows.first.keys.where((k) => k != '_مرجع داخلي').map((k) => DataCell(Text(r[k] ?? '—'), onTap: () => setState(() => _selectedRecord = Map<String, String>.from(r)))).toList())).toList())),
      const SizedBox(height: 12),
      Text('عدد السجلات المعروضة: ${_rows.length} • تحقق من حالة الحفظ بجوار كل عملية', style: const TextStyle(color: Colors.black45, fontSize: 11)),
    ])),
  ]);

  final Set<String> _expandedAccounts = {'1', '11', '12', '2', '3', '4', '5'};

  static const List<_AccountNode> _chartOfAccounts = [
    _AccountNode('1', 'الأصول', 'مدين', children: [
      _AccountNode('11', 'الأصول المتداولة', 'مدين', children: [
        _AccountNode('111', 'النقدية وما في حكمها', 'مدين', children: [
          _AccountNode('11101', 'الخزائن الرئيسية', 'مدين', analytical: true, balance: 125450, movements: 42, change: 8.4),
          _AccountNode('11102', 'الخزائن الفرعية', 'مدين', analytical: true, balance: 24800, movements: 18, change: -2.1),
          _AccountNode('11103', 'البنوك والحسابات الجارية', 'مدين', analytical: true, balance: 310000, movements: 27, change: 5.6),
          _AccountNode('11104', 'شيكات تحت التحصيل', 'مدين', analytical: true, balance: 18000, movements: 4, change: 12),
        ]),
        _AccountNode('112', 'العملاء وأوراق القبض', 'مدين', children: [
          _AccountNode('11201', 'عملاء محليون', 'مدين', analytical: true, balance: 425000, movements: 86, change: 6.3),
          _AccountNode('11202', 'أوراق قبض', 'مدين', analytical: true, balance: 35000, movements: 5, change: -1.2),
          _AccountNode('11203', 'مخصص ديون مشكوك فيها', 'دائن', analytical: true, balance: -12000, movements: 2, change: .8),
        ]),
        _AccountNode('113', 'المخزون', 'مدين', children: [
          _AccountNode('11301', 'مخزون المواد الغذائية', 'مدين', analytical: true, balance: 680000, movements: 142, change: 9.7),
          _AccountNode('11302', 'بضاعة بالطريق', 'مدين', analytical: true, balance: 45000, movements: 7, change: 3.1),
          _AccountNode('11303', 'مخزون لدى الغير', 'مدين', analytical: true, balance: 12000, movements: 3, change: -4),
        ]),
        _AccountNode('114', 'مدفوعات ومصروفات مقدمة', 'مدين', children: [
          _AccountNode('11401', 'إيجارات مقدمة', 'مدين', analytical: true, balance: 24000, movements: 2, change: -8),
          _AccountNode('11402', 'تأمينات لدى الغير', 'مدين', analytical: true, balance: 15000, movements: 1),
        ]),
      ]),
      _AccountNode('12', 'الأصول غير المتداولة', 'مدين', children: [
        _AccountNode('121', 'الأصول الثابتة بالتكلفة', 'مدين', children: [
          _AccountNode('12101', 'الأراضي والمباني', 'مدين', analytical: true, balance: 900000, movements: 1),
          _AccountNode('12102', 'السيارات ووسائل النقل', 'مدين', analytical: true, balance: 320000, movements: 6, change: 2),
          _AccountNode('12103', 'الأثاث والتجهيزات', 'مدين', analytical: true, balance: 85000, movements: 3),
          _AccountNode('12104', 'أجهزة الحاسب والبرامج', 'مدين', analytical: true, balance: 65000, movements: 4, change: 15),
        ]),
        _AccountNode('12201', 'مجمع إهلاك الأصول الثابتة', 'دائن', analytical: true, balance: -76000, movements: 12, change: 6),
      ]),
    ]),
    _AccountNode('2', 'الالتزامات', 'دائن', children: [
      _AccountNode('21', 'الالتزامات المتداولة', 'دائن', children: [
        _AccountNode('21101', 'موردو مواد غذائية محليون', 'دائن', analytical: true, balance: -390000, movements: 74, change: 4.8),
        _AccountNode('21102', 'أوراق دفع', 'دائن', analytical: true, balance: -28000, movements: 6, change: -3),
        _AccountNode('21201', 'رواتب وأجور مستحقة', 'دائن', analytical: true, balance: -42000, movements: 3, change: 2.5),
        _AccountNode('21301', 'ضريبة قيمة مضافة مستحقة', 'دائن', analytical: true, balance: -36000, movements: 8, change: 2.2),
      ]),
      _AccountNode('22', 'التزامات طويلة الأجل', 'دائن', children: [
        _AccountNode('22101', 'قروض وتسهيلات طويلة الأجل', 'دائن', analytical: true, balance: -150000, movements: 2, change: -5),
      ]),
    ]),
    _AccountNode('3', 'حقوق الملكية', 'دائن', children: [
      _AccountNode('3101', 'رأس المال المدفوع', 'دائن', analytical: true, balance: -1000000, movements: 1),
      _AccountNode('3102', 'جاري الشركاء', 'دائن', analytical: true, balance: -65000, movements: 9, change: 1),
      _AccountNode('3201', 'أرباح مرحلة', 'دائن', analytical: true, balance: -210000, movements: 1),
    ]),
    _AccountNode('4', 'الإيرادات', 'دائن', children: [
      _AccountNode('4101', 'مبيعات جملة', 'دائن', analytical: true, balance: -1450000, movements: 215, change: 11.5),
      _AccountNode('4102', 'مردودات ومسموحات المبيعات', 'مدين', analytical: true, balance: 32000, movements: 14, change: -2.4),
      _AccountNode('4103', 'خصم مسموح به', 'مدين', analytical: true, balance: 14000, movements: 11, change: 1.8),
      _AccountNode('4201', 'إيرادات خدمات وتوصيل', 'دائن', analytical: true, balance: -12000, movements: 7, change: 7),
    ]),
    _AccountNode('5', 'المصروفات والتكاليف', 'مدين', children: [
      _AccountNode('5101', 'تكلفة البضاعة المباعة', 'مدين', analytical: true, balance: 990000, movements: 187, change: 8.2),
      _AccountNode('5102', 'مشتريات', 'مدين', analytical: true, balance: 780000, movements: 102, change: 10.4),
      _AccountNode('5103', 'مردودات ومسموحات المشتريات', 'دائن', analytical: true, balance: -18000, movements: 8, change: -1.7),
      _AccountNode('5201', 'رواتب وأجور', 'مدين', analytical: true, balance: 95000, movements: 12, change: 4),
      _AccountNode('5202', 'إيجارات', 'مدين', analytical: true, balance: 48000, movements: 12),
      _AccountNode('5203', 'مرافق واتصالات', 'مدين', analytical: true, balance: 14500, movements: 12, change: 2.7),
      _AccountNode('5301', 'وقود وصيانة سيارات', 'مدين', analytical: true, balance: 37000, movements: 22, change: 6.8),
      _AccountNode('5302', 'عمولات مندوبي المبيعات', 'مدين', analytical: true, balance: 28000, movements: 10, change: 5.1),
    ]),
    _AccountNode('6', 'حسابات رقابية وإقفال', 'مدين', children: [
      _AccountNode('6101', 'بضاعة بالطريق - وسيط', 'مدين', analytical: true),
      _AccountNode('6102', 'حساب تسوية فروق المخزون', 'مدين', analytical: true),
      _AccountNode('6201', 'ملخص الدخل', 'مدين', analytical: true),
    ]),
  ];

  Widget _accountTree() {
    final query = _accountSearch.trim().toLowerCase();
    bool matches(_AccountNode n) => query.isEmpty || n.code.toLowerCase().contains(query) || n.name.toLowerCase().contains(query) || n.nature.toLowerCase().contains(query) || n.children.any(matches);
    final roots = _chartOfAccounts.where(matches).toList();
    final accountCount = _allAccountCodes(_chartOfAccounts).length;
    final analyticalCount = _countAnalyticalAccounts(_chartOfAccounts);
    final movementCount = _totalAccountMovements(_chartOfAccounts);
    final absoluteTotal = _totalAbsoluteAnalyticalBalance(_chartOfAccounts);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('دليل الحسابات الهرمي', style: TextStyle(color: _purple, fontSize: 22, fontWeight: FontWeight.w900))),
        TextButton.icon(onPressed: () { _accountSearchController.clear(); setState(() { _accountSearch = ''; _expandedAccounts.addAll(_allAccountCodes(_chartOfAccounts)); }); }, icon: const Icon(Icons.unfold_more), label: const Text('فرد الكل')),
        TextButton.icon(onPressed: () { _accountSearchController.clear(); setState(() { _accountSearch = ''; _expandedAccounts.clear(); }); }, icon: const Icon(Icons.unfold_less), label: const Text('طي الكل')),
      ]),
      const Text('هيكل حسابات مبدئي وفق التصنيف المحاسبي الشائع. الأرصدة وعدد الحركات ومعدلات التغير المعروضة بيانات توضيحية وليست أرصدة دفتر أستاذ فعلية.', style: TextStyle(height: 1.6, color: Colors.black54)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _summaryChip('إجمالي الحسابات', accountCount.toString(), _purple),
        _summaryChip('الحسابات التحليلية', analyticalCount.toString(), const Color(0xFF16834A)),
        _summaryChip('عدد الحركات التوضيحي', movementCount.toString(), _orange),
        _summaryChip('إجمالي القيم المطلقة', _money(absoluteTotal) + ' ج.م', _pink),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _accountSearchController, onChanged: (v) => setState(() { _accountSearch = v; if (v.trim().isNotEmpty) _expandedAccounts.addAll(_matchingAncestorCodes(_chartOfAccounts, v.trim().toLowerCase())); }), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث بكود الحساب أو اسمه أو طبيعته', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), 
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Container(constraints: const BoxConstraints(minWidth: 1000), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(color: _purple, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: const Row(children: [
          SizedBox(width: 340, child: Text('الحساب / الكود / الحسابات التابعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 145, child: Text('الرصيد (ج.م)', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 110, child: Text('عدد الحركات', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 105, child: Text('نسبة من الإجمالي', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 125, child: Text('مؤشر الحساب', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 115, child: Text('معدل التغير', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
        ])),
        ...roots.expand((n) => _accountNodeRows(n, 0, query)),
      ]))),
      const SizedBox(height: 10),
      const Text('ربط الحسابات بالقيود والفواتير والخزائن والمخازن واعتماد القيود وترحيلها يحتاج استكمال طبقة الحفظ والصلاحيات وقاعدة البيانات؛ هذه الشاشة لا ترحّل أي حركة.', style: TextStyle(color: Colors.black54, height: 1.6)),
    ]);
  }

  Set<String> _allAccountCodes(List<_AccountNode> nodes) {
    final result = <String>{};
    for (final n in nodes) { result.add(n.code); result.addAll(_allAccountCodes(n.children)); }
    return result;
  }

  int _countAnalyticalAccounts(List<_AccountNode> nodes) => nodes.fold<int>(0, (sum, node) => sum + (node.analytical ? 1 : 0) + _countAnalyticalAccounts(node.children));

  int _totalAccountMovements(List<_AccountNode> nodes) => nodes.fold<int>(0, (sum, node) => sum + node.movements + _totalAccountMovements(node.children));

  double _totalAbsoluteAnalyticalBalance(List<_AccountNode> nodes) => nodes.fold<double>(0, (sum, node) => sum + (node.analytical ? node.balance.abs() : 0) + _totalAbsoluteAnalyticalBalance(node.children));

  double _displayAccountBalance(_AccountNode node) => node.analytical ? node.balance : node.balance + node.children.fold<double>(0, (sum, child) => sum + _displayAccountBalance(child));

  int _displayAccountMovements(_AccountNode node) => node.movements + node.children.fold<int>(0, (sum, child) => sum + _displayAccountMovements(child));

  int _descendantAccountCount(_AccountNode node) => node.children.fold<int>(0, (sum, child) => sum + 1 + _descendantAccountCount(child));

  Set<String> _matchingAncestorCodes(List<_AccountNode> nodes, String query) {
    final result = <String>{};
    for (final node in nodes) {
      final childMatches = _matchingAncestorCodes(node.children, query);
      final selfMatches = node.code.toLowerCase().contains(query) || node.name.toLowerCase().contains(query) || node.nature.toLowerCase().contains(query);
      if (childMatches.isNotEmpty || selfMatches) {
        if (node.children.isNotEmpty && childMatches.isNotEmpty) result.add(node.code);
        result.addAll(childMatches);
      }
    }
    return result;
  }

  List<Widget> _accountNodeRows(_AccountNode node, int depth, String query) {
    final hasChildren = node.children.isNotEmpty;
    final children = node.children.where((child) => query.isEmpty || _accountNodeHasMatch(child, query)).toList();
    final expanded = _expandedAccounts.contains(node.code);
    final balance = _displayAccountBalance(node);
    final movements = _displayAccountMovements(node);
    final share = _totalAbsoluteAnalyticalBalance(_chartOfAccounts) == 0 ? 0.0 : balance.abs() / _totalAbsoluteAnalyticalBalance(_chartOfAccounts) * 100;
    final color = node.change > 0 ? const Color(0xFF18865A) : node.change < 0 ? const Color(0xFFD32F2F) : Colors.grey;
    final row = Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0ECF4)))), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(children: [
      SizedBox(width: 340, child: Row(children: [
        SizedBox(width: depth * 20.0),
        if (hasChildren) IconButton(visualDensity: VisualDensity.compact, tooltip: expanded ? 'طي الحسابات التابعة' : 'فرد الحسابات التابعة', onPressed: () => setState(() { if (expanded) { _expandedAccounts.remove(node.code); } else { _expandedAccounts.add(node.code); } }), icon: Icon(expanded ? Icons.remove_circle_outline : Icons.add_circle_outline, color: _purple, size: 20)) else const SizedBox(width: 36),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(node.name, style: TextStyle(fontWeight: hasChildren ? FontWeight.w900 : FontWeight.w600, color: hasChildren ? _purple : Colors.black87)),
          Text(node.code + ' • ' + node.nature + ' • ' + _descendantAccountCount(node).toString() + ' حساب تابع', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
      ])),
      SizedBox(width: 145, child: Text(_money(balance), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
      SizedBox(width: 110, child: Text(movements.toString(), textAlign: TextAlign.end)),
      SizedBox(width: 105, child: Text(share.toStringAsFixed(2) + '%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, color: _purple))),
      SizedBox(width: 125, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: node.analytical ? const Color(0xFFE8F5E9) : const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(20)), child: Text(node.analytical ? 'تحليلي' : 'تجميعي', style: TextStyle(color: node.analytical ? const Color(0xFF18865A) : _purple, fontWeight: FontWeight.w800, fontSize: 11))))),
      SizedBox(width: 115, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(node.change > 0 ? Icons.trending_up : node.change < 0 ? Icons.trending_down : Icons.trending_flat, color: color, size: 17), const SizedBox(width: 3), Text((node.change > 0 ? '+' : '') + node.change.toStringAsFixed(1) + '%', style: TextStyle(color: color, fontWeight: FontWeight.w800))])),
    ]));
    return [row, if (hasChildren && expanded) ...children.expand((child) => _accountNodeRows(child, depth + 1, query))];
  }

  bool _accountNodeHasMatch(_AccountNode node, String query) => node.code.toLowerCase().contains(query) || node.name.toLowerCase().contains(query) || node.nature.toLowerCase().contains(query) || node.children.any((child) => _accountNodeHasMatch(child, query));

  String _money(double value) {
    final parts = value.abs().toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (m) => ',');
    return (value < 0 ? '-' : '') + whole + '.' + parts[1];
  }
  String _auditPeriod = 'من بداية النظام حتى تاريخه';
  String _auditStart = '2026-01-01';
  String _auditEnd = '2026-10-17';
  String _auditModule = 'كل الحركات';
  final Set<String> _auditChecked = {};
  final Map<String, bool> _permissionDraft = {};
  String _permissionRole = 'مدير النظام';
  String _pricingMode = 'نسبة';
  String _pricingDirection = 'زيادة';
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _priceLimitController = TextEditingController();
  final TextEditingController _priceValueController = TextEditingController();
  final TextEditingController _invoiceDiscountController = TextEditingController();
  final TextEditingController _itemDiscountController = TextEditingController();
  String _restrictionTarget = 'الصنف';
  String _restrictionAction = 'إيقاف البيع';
  final TextEditingController _restrictionItem = TextEditingController();
  final TextEditingController _restrictionCustomer = TextEditingController();
  final TextEditingController _restrictionDelegate = TextEditingController();
  final Set<String> _allocatedItems = {};
  final Set<String> _approvedJournals = {};

  Widget _movementAuditScreen() {
    const areas = ['كل الحركات','العملاء','الموردون','المخازن','الأصناف','البنوك','الخزائن','الموظفون','القيود المحاسبية','المبيعات','المشتريات','المردودات','التحويلات'];
    final startDate = DateTime.tryParse(_auditPeriod == 'شهر محدد' && _auditStart.length == 7 ? '$_auditStart-01' : _auditStart);
    final endDate = DateTime.tryParse(_auditPeriod == 'شهر محدد' && _auditStart.length == 7 ? '${_auditStart}-31' : _auditEnd);
    final rows = _auditSampleRows.where((r) {
      if (_auditModule != 'كل الحركات' && r['area'] != _auditModule) return false;
      final date = DateTime.tryParse(r['date'] ?? '');
      if (_auditPeriod == 'من بداية النظام حتى تاريخه') return true;
      if (date == null || startDate == null) return false;
      if (_auditPeriod == 'شهر محدد') {
        return (r['date'] ?? '').startsWith(_auditStart);
      }
      return !date.isBefore(DateTime(startDate.year, startDate.month, startDate.day)) &&
          (endDate == null || !date.isAfter(DateTime(endDate.year, endDate.month, endDate.day)));
    }).toList();
    final issueCount = rows.where((r) => r['issue'] != 'سليم').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _screenHeading('اختبار ومراجعة الحركات', 'فحص تجميعي حسب المجال والفترة، وعرض تقرير بالملاحظات مع إجراء ضبط لكل مستند'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE7F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: 250, child: DropdownButtonFormField<String>(
              value: _auditPeriod,
              decoration: const InputDecoration(labelText: 'نطاق الفحص', border: OutlineInputBorder()),
              items: const ['من بداية النظام حتى تاريخه','شهر محدد','من تاريخ إلى تاريخ'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged:(v)=>setState(()=>_auditPeriod=v ?? _auditPeriod),
            )),
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              value: _auditModule,
              decoration: const InputDecoration(labelText: 'تجميع الحركات حسب', border: OutlineInputBorder()),
              items: areas.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged:(v)=>setState(()=>_auditModule=v ?? _auditModule),
            )),
            if (_auditPeriod != 'من بداية النظام حتى تاريخه')
              SizedBox(width: 190, child: TextFormField(
                key: ValueKey('audit-start-$_auditPeriod'),
                initialValue: _auditStart,
                decoration: InputDecoration(labelText: _auditPeriod == 'شهر محدد' ? 'الشهر (YYYY-MM)' : 'من تاريخ (YYYY-MM-DD)', border: const OutlineInputBorder(), hintText: _auditPeriod == 'شهر محدد' ? '2026-10' : '2026-10-01'),
                onChanged:(v)=>_auditStart=v.trim(),
              )),
            if (_auditPeriod == 'من تاريخ إلى تاريخ')
              SizedBox(width: 190, child: TextFormField(
                key: ValueKey('audit-end-$_auditPeriod'),
                initialValue: _auditEnd,
                decoration: const InputDecoration(labelText:'إلى تاريخ (YYYY-MM-DD)', border:OutlineInputBorder(), hintText:'2026-10-31'),
                onChanged:(v)=>_auditEnd=v.trim(),
              )),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => setState(() {
                _auditChecked.clear();
                _activityLog.insert(0, 'تم تشغيل عرض مراجعة الحركات للفترة: $_auditPeriod، المجال: $_auditModule');
              }),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('فحص وعرض التقرير'),
              style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _auditPeriod = 'من بداية النظام حتى تاريخه';
                _auditModule = 'كل الحركات';
                _auditStart = '2026-10';
                _auditEnd = '2026-10-17';
                _auditChecked.clear();
              }),
              icon: const Icon(Icons.restart_alt),
              label: const Text('إعادة ضبط الفلاتر'),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      _notice(Icons.info_outline, 'مصدر البيانات', 'هذه الشاشة تعرض عينة واجهة فقط حاليًا؛ لم تُربط بعد بجداول الحركات الفعلية. لذلك لا تعتبر نتائجها تدقيقًا محاسبيًا فعليًا ولا تعدّل المستند الأصلي. الفحص الفعلي يحتاج ربط مصادر الحركات وقواعد التحقق بالخادم.', _orange),
      const SizedBox(height: 12),
      Wrap(spacing:8,runSpacing:8,children:[
        _summaryChip('الحركات بالتقرير',rows.length.toString(),_purple),
        _summaryChip('ملاحظات تحتاج مراجعة',issueCount.toString(),_orange),
        _summaryChip('تمت مراجعتها يدويًا',_auditChecked.where((doc)=>rows.any((r)=>r['doc']==doc)).length.toString(),const Color(0xFF18865A)),
      ]),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد حركات ضمن الفلاتر المختارة في العينة الحالية.', textAlign: TextAlign.center)))
      else
        ...rows.map((r) {
          final isOkay = r['issue'] == 'سليم';
          final reviewed = _auditChecked.contains(r['doc']);
          return Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Row(children:[
                  Expanded(child:Text('${r['area']} • ${r['name']}',style:const TextStyle(fontWeight:FontWeight.w900,color:_purple))),
                  Text('${r['date']}',style:const TextStyle(fontSize:12)),
                ]),
                const SizedBox(height:6),
                Text('المستند: ${r['doc']} • القيمة: ${r['value']} ج.م'),
                const SizedBox(height:7),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color:(isOkay?const Color(0xFF18865A):const Color(0xFFD32F2F)).withOpacity(.08),borderRadius:BorderRadius.circular(9)),
                  child: Text('نتيجة الفحص: ${r['issue']}',style:TextStyle(color:isOkay?const Color(0xFF18865A):const Color(0xFFD32F2F),fontWeight:FontWeight.w800)),
                ),
                const SizedBox(height:8),
                Wrap(spacing:8,runSpacing:8,children:[
                  OutlinedButton.icon(
                    onPressed:()=>_showAuditFix(r),
                    icon:const Icon(Icons.build_circle_outlined),
                    label:const Text('ضبط الحركة'),
                  ),
                  OutlinedButton.icon(
                    onPressed:()=>setState(()=>reviewed?_auditChecked.remove(r['doc']):_auditChecked.add(r['doc']!)),
                    icon:Icon(reviewed?Icons.check_circle:Icons.check_circle_outline),
                    label:Text(reviewed?'إلغاء المراجعة':'تمت المراجعة'),
                  ),
                ]),
              ]),
            ),
          );
        }),
      const SizedBox(height: 8),
      const Text('مجالات الفحص: العملاء، الموردون، المخازن، الأصناف، البنوك، الخزائن، الموظفون، القيود المحاسبية، المبيعات، المشتريات، المردودات والتحويلات.',style:TextStyle(color:Colors.black54,height:1.6)),
    ]);
  }

  static const List<Map<String,String>> _auditSampleRows = [
    {'area':'العملاء','name':'فاتورة عميل','date':'2026-10-15','doc':'SAL-1042','value':'12500','issue':'حساب العميل غير محدد'},
    {'area':'الموردون','name':'فاتورة مورد','date':'2026-10-14','doc':'PUR-209','value':'8400','issue':'سليم'},
    {'area':'المخازن','name':'صرف مخزني','date':'2026-10-12','doc':'INV-077','value':'3100','issue':'كمية الصرف أكبر من المتاح'},
    {'area':'البنوك','name':'إيداع بنكي','date':'2026-10-11','doc':'BNK-031','value':'5000','issue':'مرجع البنك غير موجود'},
    {'area':'الخزائن','name':'أمر صرف','date':'2026-10-10','doc':'CSH-014','value':'2200','issue':'سليم'},
    {'area':'الموظفون','name':'عهدة مندوب','date':'2026-10-09','doc':'EMP-008','value':'1500','issue':'مركز التكلفة غير محدد'},
    {'area':'القيود المحاسبية','name':'قيد يومية','date':'2026-10-08','doc':'JV-301','value':'18000','issue':'القيد غير متوازن'},
    {'area':'المبيعات','name':'فاتورة مبيعات','date':'2026-10-07','doc':'SAL-1038','value':'7600','issue':'سليم'},
    {'area':'المشتريات','name':'فاتورة مشتريات','date':'2026-10-06','doc':'PUR-201','value':'9200','issue':'ضريبة غير محددة'},
    {'area':'المردودات','name':'مرتجع مبيعات','date':'2026-10-05','doc':'RET-015','value':'800','issue':'المستند الأصلي غير مربوط'},
    {'area':'التحويلات','name':'تحويل مخزني','date':'2026-10-04','doc':'TRF-026','value':'4200','issue':'مخزن الوجهة غير محدد'},
    {'area':'الأصناف','name':'حركة صنف','date':'2026-10-03','doc':'ITM-422','value':'0','issue':'سليم'},
  ];

  void _showAuditFix(Map<String,String> row) {
    final controller=TextEditingController(text:row['issue']);
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('ضبط الحركة ${row['doc']}'),content:TextField(controller:controller,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظة الضبط المقترح',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){setState(()=>_activityLog.insert(0,'مراجعة ${row['doc']}: ${controller.text}'));Navigator.pop(ctx);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('سُجلت ملاحظة المراجعة محليًا؛ لم يتم تعديل المستند الأصلي.')));},child:const Text('تسجيل الملاحظة'))]));
  }

  Widget _permissionsScreen() {
    const roles=['مدير النظام','مدير مالي','مدير مخازن','موظف مبيعات','موظف مشتريات','أمين خزينة','مندوب مبيعات','مندوب تسليم','مراجع'];
    const rights=['عرض','إضافة','تعديل','حذف','اعتماد','عكس الحركة','ترحيل','تصدير','طباعة','تخطي ربط المستند الأصلي','تخطي التحضير'];
    const scopes=['بيانات أساسية','الحسابات المالية','المخازن والفروع','المبيعات والعملاء','المشتريات والموردون','الموارد البشرية','إدارة البرنامج','سياسات التسعير','توزيع الأصناف','قيود البيع والشراء'];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('المستخدمون والصلاحيات','تحديد الصلاحيات حسب نوع المستخدم والدور الوظيفي'),
      Wrap(spacing:10,children:[SizedBox(width:260,child:DropdownButtonFormField<String>(value:_permissionRole,decoration:const InputDecoration(labelText:'تصنيف المستخدم / الدور',border:OutlineInputBorder()),items:roles.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_permissionRole=v??_permissionRole)),),FilledButton.icon(onPressed:()=>_saveWorkspaceSetting('program_permissions', {'role':_permissionRole,'values':Map<String, bool>.from(_permissionDraft)}, successMessage:'تم حفظ إعدادات الصلاحيات في قاعدة البيانات.').then((_) {}),icon:const Icon(Icons.save),label:const Text('حفظ الصلاحيات'))]),
      const SizedBox(height:12),
      const Text('ضع علامة صح لمنح الصلاحية وأزلها لمنعها. لا تطبق هذه الاختيارات حماية فعلية قبل ربطها بهوية المستخدم والخادم وسياسات قاعدة البيانات.',style:TextStyle(color:Colors.black54,height:1.6)),
      const SizedBox(height:8),
      ...scopes.map((scope)=>Card(child:ExpansionTile(title:Text(scope,style:const TextStyle(fontWeight:FontWeight.w800,color:_purple)),children:[Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:12,runSpacing:4,children:rights.map((right){final key='$_permissionRole::$scope::$right';final enabled=_permissionDraft[key]??(_permissionRole=='مدير النظام'&&right!='عكس الحركة');return SizedBox(width:145,child:CheckboxListTile(dense:true,contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setState(()=>_permissionDraft[key]=v??false),title:Text(right,style:const TextStyle(fontSize:12))));}).toList()))]))),
    ]);
  }

  Widget _pricingPolicyScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('سياسات التسعير والخصومات','حد تسعير الصنف والزيادة أو النقصان وحدود خصم الصنف والفاتورة'),
      Wrap(spacing:12,runSpacing:12,children:[_fieldBox('سعر الصنف الأساسي',_basePriceController),_fieldBox('حد التسعير المعتمد',_priceLimitController),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_pricingMode,decoration:const InputDecoration(labelText:'طريقة التعديل',border:OutlineInputBorder()),items:const ['نسبة','قيمة'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingMode=v??_pricingMode))),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_pricingDirection,decoration:const InputDecoration(labelText:'الاتجاه من حد التسعير',border:OutlineInputBorder()),items:const ['زيادة','نقصان'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingDirection=v??_pricingDirection)),),_fieldBox(_pricingMode=='نسبة'?'نسبة الزيادة / النقصان %':'قيمة الزيادة / النقصان',_priceValueController),_fieldBox('أقصى خصم على إجمالي الفاتورة %',_invoiceDiscountController),_fieldBox('أقصى خصم على مستوى الصنف %',_itemDiscountController)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>_saveWorkspaceSetting('pricing_policy', {'base_price':_basePriceController.text.trim(),'price_limit':_priceLimitController.text.trim(),'mode':_pricingMode,'direction':_pricingDirection,'price_value':_priceValueController.text.trim(),'invoice_discount':_invoiceDiscountController.text.trim(),'item_discount':_itemDiscountController.text.trim()}, successMessage:'تم حفظ سياسة التسعير في قاعدة البيانات.').then((_) {}),icon:const Icon(Icons.save),label:const Text('حفظ سياسة التسعير')),
      const SizedBox(height:8),
      const Text('يجب أن يُحسب السعر النهائي من حد التسعير المسجل للصنف، مع منع تجاوز صلاحية المستخدم وحدود الخصم. يلزم ربط الحقول ببيانات الأصناف وقاعدة البيانات قبل تطبيقها على الفواتير.',style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _delegateAllocationScreen() {
    const delegates=['مندوب مبيعات 01','مندوب مبيعات 02','مندوب مبيعات 03','مندوب مبيعات 04'];
    const items=['زيت طعام 1 لتر','أرز 1 كجم','سكر 1 كجم','مكرونة 400 جم','سمن نباتي','شاي','جبن أبيض','منظفات'];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('توزيع الأصناف على المندوبين','تخصيص الأصناف المهمة التي يُسمح لكل مندوب ببيعها'),
      const Text('اختيار الصنف والمندوب أدناه تجريبي حتى ربط دليل الأصناف والمندوبين الفعلي.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:10),
      ...delegates.map((delegate)=>Card(child:ExpansionTile(title:Text(delegate,style:const TextStyle(fontWeight:FontWeight.w800,color:_purple)),children:items.map((item){final key='$delegate::$item';return CheckboxListTile(value:_allocatedItems.contains(key),onChanged:(v)=>setState(()=>v==true?_allocatedItems.add(key):_allocatedItems.remove(key)),title:Text(item),subtitle:const Text('السماح ببيع الصنف المهم لهذا المندوب'));}).toList()))),
      FilledButton.icon(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('توزيع الأصناف مسودة محلية ولم يُحفظ بالخادم.'))),icon:const Icon(Icons.save),label:const Text('حفظ التوزيع'))]);
  }

  Widget _transactionRestrictionsScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قيود البيع والشراء','إيقاف البيع أو الشراء أو تحديد الحد حسب الصنف أو الفاتورة أو العميل أو المندوب'),
      Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:220,child:DropdownButtonFormField<String>(value:_restrictionAction,decoration:const InputDecoration(labelText:'الإجراء',border:OutlineInputBorder()),items:const ['إيقاف البيع','إيقاف الشراء','تحديد حد البيع'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionAction=v??_restrictionAction))),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_restrictionTarget,decoration:const InputDecoration(labelText:'مستوى تطبيق القيد',border:OutlineInputBorder()),items:const ['الصنف','الفاتورة الواحدة','العميل','المندوب'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionTarget=v??_restrictionTarget))),_fieldBox('كود الصنف / الفاتورة / العميل / المندوب',_restrictionItem),_fieldBox('العميل (اختياري)',_restrictionCustomer),_fieldBox('المندوب (اختياري)',_restrictionDelegate)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('إضافة قيد'),content:Text('الإجراء: $_restrictionAction • المستوى: $_restrictionTarget • المعرف: ${_restrictionItem.text}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),FilledButton(onPressed:() async {final saved=await _saveWorkspaceSetting('transaction_restrictions', {'action':_restrictionAction,'target':_restrictionTarget,'item':_restrictionItem.text.trim(),'customer':_restrictionCustomer.text.trim(),'delegate':_restrictionDelegate.text.trim()}, successMessage:'تم حفظ إعداد القيد في قاعدة البيانات.');if(saved&&mounted){setState(()=>_activityLog.insert(0,'تم حفظ إعداد قيد: $_restrictionAction / $_restrictionTarget / ${_restrictionItem.text}'));Navigator.pop(ctx);}},child:const Text('حفظ الإعداد'))])),icon:const Icon(Icons.block),label:const Text('إضافة قيد / إيقاف')),
      const SizedBox(height:8),
      const Text('يتم حفظ إعداد القيد في قاعدة البيانات. يلزم ربط قواعد حفظ وترحيل الفواتير بهذا الإعداد حتى يمنع البيع أو الشراء فعليًا على مستوى الخادم.',style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _journalApprovalScreen() {
    const journals=[('JV-301','قيد مشتريات','2026-10-08','18,000','غير متوازن'),('JV-302','قيد مبيعات','2026-10-09','7,600','بانتظار الاعتماد'),('JV-303','قيد خزينة','2026-10-10','2,200','بانتظار الاعتماد')];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قائمة اعتماد القيود','مراجعة القيود قبل اعتمادها أو إعادتها للتعديل أو تسجيل طلب عكس'),
      const Text('القيود أدناه أمثلة للواجهة فقط، ولا تمثل قيودًا محفوظة في دفتر الأستاذ.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:10),
      ...journals.map((j)=>Card(child:ListTile(title:Text('${j.$1} • ${j.$2}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${j.$3} • ${j.$4} ج.م • ${j.$5}'),trailing:Wrap(spacing:3,children:[IconButton(tooltip:'اعتماد',onPressed:()=>setState(()=>_approvedJournals.add(j.$1)),icon:const Icon(Icons.check_circle_outline,color:Color(0xFF18865A))),IconButton(tooltip:'إعادة للتعديل',onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم تسجيل طلب إعادة ${j.$1} للمراجعة محليًا.'))),icon:const Icon(Icons.edit_outlined,color:_orange)),IconButton(tooltip:'طلب عكس',onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم تسجيل طلب عكس ${j.$1} محليًا؛ لم يُعكس القيد.'))),icon:const Icon(Icons.undo,color:_pink))]),leading:Icon(_approvedJournals.contains(j.$1)?Icons.verified:Icons.pending_actions,color:_approvedJournals.contains(j.$1)?const Color(0xFF18865A):_orange)))),
      const SizedBox(height:8),
      const Text('زر الاعتماد في هذه المرحلة يسجل اختيارًا داخل الجلسة فقط؛ الترحيل المالي الحقيقي يتطلب التحقق من توازن القيد وصلاحية المستخدم وحالة الفترة المالية.',style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _screenHeading(String title,String subtitle)=>Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:Colors.black54,height:1.5))]));
  Widget _summaryChip(String label,String value,Color color)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:color.withOpacity(.09),borderRadius:BorderRadius.circular(10)),child:Text('$label: $value',style:TextStyle(color:color,fontWeight:FontWeight.w800)));
  Widget _fieldBox(String label,TextEditingController controller)=>SizedBox(width:220,child:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

  Widget _about() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE7F2))), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('عن البرنامج', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
    SizedBox(height: 12),
    Text('تم إنشاء هذا البرنامج بواسطة شركة سلسلة للبرمجيات — أ. محمد عبد العاطي.', style: TextStyle(fontWeight: FontWeight.w700, height: 1.7)),
    Text('موبايل: 01121237271', style: TextStyle(height: 1.7)),
    Text('البريد الإلكتروني: attymanatty@gmail.com', style: TextStyle(height: 1.7)),
    SizedBox(height: 6),
    Text('خبرة في جوانب تجارة وتوزيع المواد الغذائية لمدة تقارب 20 عامًا، والمشاركة في تطوير كبرى التجار والشركات بنظام الفروع وإعادة هيكلتها وتطويرها في مختلف الأقسام.', style: TextStyle(height: 1.8)),
    SizedBox(height: 8),
    Text('المنظومة مصممة للتوسع إلى إدارة مالية ومخزنية وتشغيلية موحدة متعددة الفروع.', style: TextStyle(color: _purple, height: 1.7)),
  ]));

}

class _AccountNode {
  const _AccountNode(this.code, this.name, this.nature, {this.children = const [], this.analytical = false, this.balance = 0, this.movements = 0, this.change = 0});
  final String code, name, nature;
  final List<_AccountNode> children;
  final bool analytical;
  final double balance, change;
  final int movements;
}
class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.note, required this.icon, required this.color});
  final String title, value, note;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F2))), child: Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
    const SizedBox(width: 12),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(color: _purple, fontSize: 21, fontWeight: FontWeight.w900)),
      Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 10)),
    ])),
  ]));
}


class _ExecutiveBarsPainter extends CustomPainter {
  const _ExecutiveBarsPainter({this.values = const <double>[]});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFEDE7F4)..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final source = values.isEmpty ? const <double>[.48, .72, .56, .88, .64, .79, .42] : values;
    final maxValue = source.fold<double>(0, (max, value) => value > max ? value : max);
    const colors = [_purple, _orange, _pink, _purple, _orange, _pink, _purple];
    final slot = size.width / source.length;
    for (var i = 0; i < source.length; i++) {
      final barWidth = slot * .48;
      final normalized = maxValue <= 0 ? .025 : (source[i] / maxValue).clamp(0.0, 1.0);
      final h = size.height * normalized;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(slot * i + (slot - barWidth) / 2, size.height - h, barWidth, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = colors[i % colors.length].withValues(alpha: .82));
    }
  }

  @override
  bool shouldRepaint(covariant _ExecutiveBarsPainter oldDelegate) => oldDelegate.values != values;
}

class _ExecutiveChartPainter extends CustomPainter {
  const _ExecutiveChartPainter({required this.color, this.values = const <double>[]});
  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEDE7F4)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final source = values.length >= 2
        ? values
        : const <double>[.28, .42, .34, .66, .58, .82, .73];
    final maxValue = source.fold<double>(0, (max, value) => value > max ? value : max);
    final points = List<Offset>.generate(source.length, (i) {
      final x = source.length == 1 ? 0.0 : size.width * i / (source.length - 1);
      final normalized = maxValue <= 0 ? .04 : (source[i] / maxValue).clamp(0.0, 1.0);
      final y = size.height * (.88 - normalized * .70);
      return Offset(x, y);
    });
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .18), color.withValues(alpha: .01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(path, linePaint);
    final dotPaint = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(point, 8, Paint()..color = color.withValues(alpha: .13));
    }
  }

  @override
  bool shouldRepaint(covariant _ExecutiveChartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
