import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'widgets/erp_quick_task_button.dart';
import 'widgets/erp_keyboard_navigation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/hr_attendance_rules_screen.dart';
import 'screens/erp_app_assets_screen.dart';
import 'screens/erp_app_advertisements_screen.dart';
import 'screens/erp_program_policies_screen.dart';
import 'screens/erp_supplier_deferred_commissions_screen.dart';
import 'screens/erp_delegate_allocation_screen.dart';
import 'screens/erp_company_profile_screen.dart';
import 'screens/erp_currencies_screen.dart';
import 'screens/erp_image_collector_screen.dart';
import 'screens/erp_item_data_import_download_screen.dart';
import 'screens/erp_user_admin_screen.dart';
import 'screens/erp_user_classifications_screen.dart';
import 'screens/erp_shipping_companies_screen.dart';
import 'screens/erp_branches_screen.dart';
import 'screens/erp_geographic_data_screen.dart';
import 'screens/erp_item_units_screen.dart';
import 'screens/erp_cost_centers_screen.dart';
import 'screens/erp_accounts_screen.dart';
import 'screens/erp_journal_entries_screen.dart';
import 'screens/erp_ledger_reports_screen.dart';
import 'screens/erp_movement_audit_screen.dart';
import 'screens/erp_inventory_screen.dart';
import 'screens/erp_hr_operations_screen.dart';
import 'screens/erp_operational_documents_screen.dart';
import 'screens/erp_sales_fulfillment_screen.dart';
import 'screens/erp_cash_vouchers_screen.dart';
import 'screens/erp_payroll_screen.dart';
import 'screens/erp_fiscal_periods_screen.dart';
import 'screens/erp_parties_screen.dart';
import 'screens/erp_inventory_master_screen.dart';
import 'screens/erp_item_categories_screen.dart';
import 'screens/erp_cashboxes_screen.dart';
import 'screens/erp_price_lists_screen.dart';
import 'screens/erp_sales_targets_commissions_screen.dart';
import 'screens/erp_item_offers_screen.dart';
import 'screens/erp_public_leads_screen.dart';
import 'screens/erp_einvoice_screen.dart';
import 'screens/erp_operational_account_mappings_screen.dart';
import 'screens/erp_activity_types_screen.dart';
import 'screens/erp_clear_data_screen.dart';
import 'services/erp_operational_documents_repository.dart';
import 'services/erp_workspace_records_service.dart';
import 'services/erp_app_management_service.dart';
import 'services/erp_app_settings.dart';
import 'services/erp_app_permission_catalog.dart';
import 'services/erp_company_settings_repository.dart';
import '../services/app_language.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _pink = Color(0xFFFF27C3);
const _canvas = Color(0xFFF7F5FA);

const Map<String, Map<String, List<String>>> _modules = {
  'إدارة البرنامج': {
    'بيانات أساسية': ['بيانات الشركة', 'الفروع', 'مراكز التكلفة', 'بيانات جغرافية', 'أنواع الأنشطة', 'أنواع المستخدمين والمستخدمين', 'تصنيفات المستخدمين', 'قوالب صلاحيات المستخدمين', 'صلاحيات المستخدمين', 'سياسات البرنامج', 'سجل العمليات', 'واجهة API والربط الخارجي', 'إدارة مفاتيح API', 'سجلات التكامل والطلبات', 'سياسات التسعير والخصومات', 'توزيع الأصناف على المندوبين', 'قيود البيع والشراء'],
    'حركات': ['اختبار ومراجعة الحركات', 'قائمة اعتماد القيود', 'إدارة الجلسات', 'سجل الدخول والخروج', 'النسخ الاحتياطي', 'مسح جميع البيانات', 'إعداد نقاط الربط', 'اختبار الاتصال الخارجي'],
    'تقارير': ['تقرير المستخدمين', 'تقرير نشاط النظام', 'تقرير استهلاك API', 'تقرير أخطاء التكامل'],
  },
  'إدارة التطبيقات': {
    'بيانات أساسية': ['إعدادات هوية التطبيق', 'إدارة الشعار والصور', 'إدارة ألوان التطبيقات', 'إدارة صلاحيات التطبيقات', 'إدارة إعلانات التطبيق', 'إدارة صور الأصناف والفئات', 'إدارة صور الموردين والعملاء', 'إدارة شركات الشحن', 'إعدادات عامة للتطبيقات'],
    'حركات': ['مراجعة طلبات تعديل التطبيقات', 'سجل تغييرات الهوية', 'إدارة إصدارات التطبيقات'],
    'تقارير': ['تقرير التطبيقات', 'تقرير الصلاحيات', 'تقرير تغييرات الإعدادات'],
  },
  'الحسابات المالية': {
    'بيانات أساسية': ['شجرة الحسابات', 'الفترات المالية', 'مراكز التكلفة', 'العملات', 'الخزائن الرئيسية والفرعية', 'الحسابات البنكية', 'خريطة الحسابات التشغيلية', 'طرق الدفع', 'لوحات المؤشرات', 'قوالب التقارير'],
    'حركات': ['قيود اليومية', 'سندات القبض', 'سندات الصرف', 'تسويات الحسابات', 'إقفال الفترة', 'تحويل بين الخزائن', 'إيداع بنكي', 'سحب بنكي', 'مطابقة البنك', 'تحديث مؤشرات الأداء', 'تصدير البيانات'],
    'تقارير': ['ميزان المراجعة', 'الأستاذ العام', 'قائمة الدخل', 'الميزانية العمومية', 'حركة حساب', 'أرصدة الخزائن', 'كشف حساب خزينة', 'كشف حساب بنك', 'مؤشرات الأداء الرئيسية', 'التدفقات النقدية', 'تحليل الربحية', 'حركة المبيعات والمخزون', 'ملخص تنفيذي'],
  },
  'المخازن والفروع': {
    'بيانات أساسية': ['دليل المخازن', 'فئات الأصناف', 'دليل الأصناف', 'وحدات الأصناف', 'الباركود', 'حدود إعادة الطلب', 'قواعد إعادة الطلب والتنبيه', 'بيانات جغرافية'],
    'حركات': ['إذن إضافة', 'إذن صرف', 'تحويل مخزني', 'تسوية جرد', 'جرد فعلي', 'محاضر الجرد ومراجعة الفروق', 'تسوية صلاحية وهالك', 'تحويلات بين الفروع', 'تسويات الفروع', 'توزيع المصروفات', 'جامع صور الأصناف', 'استيراد بيانات اصناف', 'تنزيل بيانات أصناف'],
    'تقارير': ['أرصدة الأصناف', 'كارت الصنف', 'الجرد والفروق', 'الأصناف الراكدة', 'الأصناف قاربت على النفاد', 'تنبيهات إعادة الطلب', 'تواريخ الصلاحية', 'تنبيهات قرب انتهاء الصلاحية', 'أرصدة التشغيلات', 'أداء الفروع', 'أرباح وخسائر الفروع', 'حركة التحويلات'],
  },
  'المشتريات والموردون': {
    'بيانات أساسية': ['سياسات الشراء', 'قوائم أسعار الموردين', 'دليل الموردين', 'تصنيفات الموردين', 'جهات اتصال الموردين', 'شروط التوريد'],
    'حركات': ['طلب شراء', 'أمر شراء', 'استلام مشتريات', 'فاتورة مشتريات', 'مرتجع مشتريات', 'مؤجلات وعمولات الموردين', 'كشف حساب مورد', 'تقييم مورد', 'مطابقة أرصدة الموردين', 'تسجيل مديونية مورد'],
    'تقارير': ['تحليل المشتريات', 'مقارنة أسعار الموردين', 'أعمار ديون الموردين', 'أرصدة الموردين', 'أداء الموردين', 'الموردون حسب النشاط'],
  },
  'المبيعات والعملاء': {
    'بيانات أساسية': ['قوائم أسعار البيع', 'سياسات الخصم', 'مناطق التوزيع', 'خطوط السير', 'دليل العملاء', 'تصنيفات العملاء', 'فروع العملاء', 'حدود الائتمان', 'مناطق العملاء', 'دليل المندوبين', 'مركبات التوزيع', 'قاعدة العملاء المحتملين', 'أهداف العملاء الشهرية', 'عمولات المندوبين', 'خطط العمولة'],
    'حركات': ['عروض الأصناف', 'عرض سعر', 'أمر بيع', 'فاتورة مبيعات', 'مرتجع مبيعات', 'إذن التجهيز', 'إذن التسليم', 'كشف حساب عميل', 'تحصيلات العملاء', 'متابعة المديونيات', 'طلبات العملاء', 'تسليم عهدة مندوب', 'تصفية عهدة مندوب', 'تحصيل نقدي', 'مصروفات رحلة', 'مسودات العمولات'],
    'تقارير': ['المبيعات اليومية', 'ربحية المبيعات', 'مبيعات حسب الفرع', 'أداء المندوبين', 'الطلبات المتأخرة', 'تحقيق أهداف العملاء', 'تقرير العمولات المستحقة', 'أرصدة العملاء', 'أعمار الديون', 'أفضل العملاء', 'العملاء المتوقفون', 'تصفية المندوبين', 'تحصيلات يومية', 'تكلفة خطوط السير'],
  },
  'الموارد البشرية والرواتب': {
    'بيانات أساسية': ['الهيكل الوظيفي', 'الإدارات والأقسام', 'الوظائف والدرجات', 'ملف الموظف', 'العقود', 'أنواع الإجازات', 'قواعد الورديات والحضور والانصراف', 'أجهزة البصمة وربط الحضور', 'مكونات الراتب', 'الاستحقاقات والاستقطاعات', 'سياسات العمولة'],
    'حركات': ['الحضور والانصراف', 'الإجازات والأذونات', 'الجزاءات والمكافآت', 'السلف', 'تقييم الأداء', 'مسير الرواتب', 'صرف الرواتب', 'عمولات المبيعات', 'تسوية سلفة'],
    'تقارير': ['كشف العاملين', 'الحضور والغياب', 'رصيد الإجازات', 'انتهاء العقود', 'ملخص الرواتب', 'مفردات المرتب', 'عمولات المندوبين'],
  },
  'علاقات العملاء CRM': {
    'بيانات أساسية': ['الحملات التسويقية', 'قواعد العروض', 'شرائح العملاء', 'أنواع الطلبات', 'قنوات التواصل', 'أسباب الشكاوى'],
    'حركات': ['إنشاء عرض', 'اعتماد حملة', 'تسجيل كوبون', 'تذكرة دعم جديدة', 'متابعة شكوى', 'تسجيل اقتراح'],
    'تقارير': ['أداء العروض', 'تكلفة الحملات', 'معدل الاستجابة', 'التذاكر المفتوحة', 'زمن الاستجابة', 'رضا العملاء'],
  },
  'الفاتورة الإلكترونية': {
    'بيانات أساسية': [
      'إعدادات الربط الضريبي',
      'بيانات الممول والتوقيع الإلكتروني',
      'تكويد السلع والخدمات',
    ],
    'حركات': [
      'لوحة الفاتورة الإلكترونية',
      'فواتير إلكترونية صادرة',
      'فواتير إلكترونية واردة',
      'إشعارات دائنة إلكترونية',
      'إشعارات مدينة إلكترونية',
      'إرسال المستندات للضرائب',
      'متابعة حالات الإرسال',
      'إلغاء المستندات',
      'رفض المستندات الواردة',
      'قبول أو رفض طلبات الإلغاء',
      'قبول أو رفض طلبات الرفض',
      'البحث عن مستند ضريبي',
      'المستندات الضريبية الحديثة',
      'تفاصيل المستند والتحقق',
      'طباعة الفاتورة الضريبية PDF',
      'طلبات حزم المستندات',
      'تنزيل حزم المستندات',
      'إشعارات منظومة الضرائب',
      'سجل عمليات التكامل',
      'اختبار الاتصال الضريبي',
    ],
    'تقارير': ['تقارير الفاتورة الإلكترونية'],
  },
};

class ErpDashboardScreen extends StatefulWidget {
  const ErpDashboardScreen({super.key, this.initialPage});

  final String? initialPage;
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
  bool _notificationsPanelVisible = true;
  bool _activityPanelVisible = true;
  bool _quickAccessPanelVisible = true;
  bool _mainSidebarVisible = true;
  bool _utilitySidebarVisible = true;
  bool _executiveAccessChecked = false;
  bool _executiveSummaryAllowed = true;
  bool _executivePartialConfigured = false;
  final Set<String> _executiveAllowedSections = <String>{};
  static const Map<String, String> _executivePermissionSectionKeys = {
    'المبيعات والعملاء': 'مؤشرات المبيعات والعملاء',
    'المالية والسيولة': 'مؤشرات المالية والسيولة',
    'المخزون والمشتريات': 'مؤشرات المخزون والمشتريات',
    'الطلبات والتوزيع': 'مؤشرات الطلبات والتوزيع',
    'الموظفون والفروع': 'مؤشرات الموظفين والفروع',
    'الرقابة والتنبيهات': 'مؤشرات الرقابة والتنبيهات',
  };
  String _module = 'الحسابات المالية';
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
    if (widget.initialPage == 'بيانات الشركة') {
      _module = 'إدارة البرنامج';
      _group = 'بيانات أساسية';
      _page = 'بيانات الشركة';
    }
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
      // These requests are independent; run them together to reduce dashboard startup latency.
      final initialResults = await Future.wait<dynamic>([
        _appManagementService.listApps(companyId: companyId),
        _appManagementService.listAppRegistry(companyId: companyId),
      ]);
      final apps = initialResults[0] as List<ErpManagedApp>;
      final registryRows = initialResults[1] as Map<String, String>;
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
      // None of these loaders depends on another loader's network result.
      // Await them together so the screen is not delayed by a serial chain of requests.
      await Future.wait<void>([
        _loadSelectedManagedAppTheme(),
        _loadPermissionsForSelectedApp(),
        _loadSavedAppActivity(),
        _loadWorkspaceSettings(companyId),
        _loadExecutivePermissions(companyId),
        _loadExecutiveMetrics(companyId),
      ]);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appManagementMessage = 'تعذر تحميل إعدادات التطبيقات: $error';
      });
    } finally {
      if (mounted) setState(() => _appManagementLoading = false);
    }
  }

  Future<void> _loadExecutivePermissions(String companyId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() { _executiveAccessChecked = true; _executiveSummaryAllowed = true; _executivePartialConfigured = false; _executiveAllowedSections.clear(); });
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('erp_user_permissions')
          .select('menu_key,allow_access')
          .eq('company_id', companyId)
          .eq('user_id', userId);
      final permissions = <String, bool>{
        for (final row in (rows as List).whereType<Map<String, dynamic>>())
          (row['menu_key'] ?? '').toString(): row['allow_access'] == true,
      };
      const parentKey = 'التقارير والتحليلات::تقارير::الملخص التنفيذي';
      final childKeys = _executivePermissionSectionKeys.values
          .map((label) => 'التقارير والتحليلات::تقارير::$label')
          .toList();
      final hasParent = permissions.containsKey(parentKey);
      final configuredChildren = childKeys.where(permissions.containsKey).toList();
      if (!mounted) return;
      setState(() {
        _executiveAccessChecked = true;
        _executiveSummaryAllowed = hasParent ? permissions[parentKey] == true : true;
        _executivePartialConfigured = configuredChildren.isNotEmpty;
        _executiveAllowedSections
          ..clear()
          ..addAll(_executivePermissionSectionKeys.entries
              .where((entry) => permissions['التقارير والتحليلات::تقارير::${entry.value}'] == true)
              .map((entry) => entry.key));
        if (!_executivePartialConfigured) {
          _executiveAllowedSections.addAll(_executivePermissionSectionKeys.keys);
        }
      });
    } catch (_) {
      // Keep the summary usable until the permissions schema is installed.
      if (mounted) setState(() {
        _executiveAccessChecked = true;
        _executiveSummaryAllowed = true;
        _executivePartialConfigured = false;
        _executiveAllowedSections..clear()..addAll(_executivePermissionSectionKeys.keys);
      });
    }
  }

  Future<void> _loadWorkspaceSettings(String companyId) async {
    try {
      final settings = await Future.wait<Map<String, dynamic>?>([
        _workspaceSettingsRepository.getSetting(
          companyId: companyId,
          key: 'pricing_policy',
        ),
        _workspaceSettingsRepository.getSetting(
          companyId: companyId,
          key: 'program_permissions',
        ),
        _workspaceSettingsRepository.getSetting(
          companyId: companyId,
          key: 'transaction_restrictions',
        ),
      ]);
      final pricing = settings[0];
      final permissions = settings[1];
      final restrictions = settings[2];
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
          primaryColor: '#${_appPrimary.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          accentColor: '#${_appAccent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
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
  final List<String> _activityLog = ['تم فتح لوحة ERP', 'تم تجهيز أقسام المخازن والفروع', 'تمت إضافة نماذج إدارة المستندات'];
  String _group = 'تقارير';
  String _page = 'ملخص تنفيذي';
  String _search = '';
  Map<String, String>? _selectedRecord;
  final Map<String, List<Map<String, String>>> _saved = {};
  final Set<String> _cloudLoadedWorkspacePages = <String>{};
  final Set<String> _workspacePageLoadsInProgress = <String>{};

  List<Map<String, String>> get _rows {
    final rows = _cloudLoadedWorkspacePages.contains(_page)
        ? (_saved[_page] ?? <Map<String, String>>[])
        : (_saved[_page] ?? _sampleRows(_page));
    if (_search.trim().isEmpty) return rows;
    return rows.where((r) => r.values.any((v) => v.toLowerCase().contains(_search.toLowerCase()))).toList();
  }

  List<String> get _gridKeys {
    if (_rows.isNotEmpty) {
      return _rows.first.keys.where((key) => key != '_مرجع داخلي').toList();
    }
    if (_page == 'الهيكل الوظيفي') {
      return const ['م', 'كود الهيكل', 'المسمى الوظيفي', 'الإدارة / القسم', 'يتبع إلى', 'المستوى الإداري', 'الحالة'];
    }
    return const [];
  }

  List<Map<String, String>> _sampleRows(String page) {
    if (page == 'الهيكل الوظيفي') {
      return [
        {'م': '1', 'كود الهيكل': 'ORG-001', 'المسمى الوظيفي': 'المدير العام', 'الإدارة / القسم': 'الإدارة العامة', 'يتبع إلى': '—', 'المستوى الإداري': 'إدارة عليا', 'الحالة': 'نموذج تجريبي'},
        {'م': '2', 'كود الهيكل': 'ORG-002', 'المسمى الوظيفي': 'مدير المبيعات', 'الإدارة / القسم': 'المبيعات', 'يتبع إلى': 'المدير العام', 'المستوى الإداري': 'إدارة وسطى', 'الحالة': 'نموذج تجريبي'},
        {'م': '3', 'كود الهيكل': 'ORG-003', 'المسمى الوظيفي': 'مدير المخازن', 'الإدارة / القسم': 'المخازن', 'يتبع إلى': 'المدير العام', 'المستوى الإداري': 'إدارة وسطى', 'الحالة': 'نموذج تجريبي'},
        {'م': '4', 'كود الهيكل': 'ORG-004', 'المسمى الوظيفي': 'مسؤول الحسابات', 'الإدارة / القسم': 'الحسابات المالية', 'يتبع إلى': 'المدير العام', 'المستوى الإداري': 'وظيفة تنفيذية', 'الحالة': 'نموذج تجريبي'},
      ];
    }
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
    final isOrgChart = _page == 'الهيكل الوظيفي';
    final code = TextEditingController();
    final name = TextEditingController();
    final details = TextEditingController();
    final parent = TextEditingController();
    final level = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('إضافة سجل — $_page'),
        content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, decoration: InputDecoration(labelText: isOrgChart ? 'كود الهيكل' : 'الكود / الرقم المرجعي')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: InputDecoration(labelText: isOrgChart ? 'المسمى الوظيفي' : 'الاسم / البيان')),
          const SizedBox(height: 12),
          TextField(controller: details, maxLines: isOrgChart ? 1 : 3, decoration: InputDecoration(labelText: isOrgChart ? 'الإدارة / القسم' : 'الوصف أو ملاحظات')),
          if (isOrgChart) ...[
            const SizedBox(height: 12),
            TextField(controller: parent, decoration: const InputDecoration(labelText: 'يتبع إلى')),
            const SizedBox(height: 12),
            TextField(controller: level, decoration: const InputDecoration(labelText: 'المستوى الإداري')),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(silsilaText('No / لا'))),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final rows = List<Map<String, String>>.from(_saved[_page] ?? _sampleRows(_page));
            final generatedCode = code.text.trim().isEmpty ? 'NEW-${rows.length + 1}' : code.text.trim();
            final Map<String, String> row = isOrgChart
                ? {'م': '${rows.length + 1}', 'كود الهيكل': generatedCode, 'المسمى الوظيفي': name.text.trim(), 'الإدارة / القسم': details.text.trim(), 'يتبع إلى': parent.text.trim().isEmpty ? '—' : parent.text.trim(), 'المستوى الإداري': level.text.trim().isEmpty ? 'غير محدد' : level.text.trim(), 'الحالة': 'نشط'}
                : {'الكود': generatedCode, 'الاسم': name.text.trim(), 'الوصف': details.text.trim(), 'الحالة': 'مسودة'};
            rows.insert(0, row);
            final newRecord = Map<String, String>.from(rows.first);
            newRecord['_مرجع داخلي'] = isOrgChart ? (newRecord['كود الهيكل'] ?? generatedCode) : (newRecord['الكود'] ?? newRecord['الاسم'] ?? newRecord.values.first);
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
          }, child: Text(silsilaText('حفظ السجل'))),
        ],
      ),
    ).then((_) { code.dispose(); name.dispose(); details.dispose(); parent.dispose(); level.dispose(); });
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

    void saveChanges(BuildContext dialogContext) {
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
    }

    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('تعديل سجل — $_page'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: controllers.entries.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: entry.value, decoration: InputDecoration(labelText: entry.key)),
      )).toList()))),
      actions: [
        TextButton(
          onPressed: () async {
            final wantsSave = await showDialog<bool>(
              context: dialogContext,
              builder: (confirmContext) => AlertDialog(
                title: const Text('تأكيد الرجوع'),
                content: const Text('هل ترغب في حفظ التعديلات؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('لا')),
                  FilledButton(onPressed: () => Navigator.pop(confirmContext, true), child: const Text('نعم')),
                ],
              ),
            );
            if (wantsSave == true && dialogContext.mounted) {
              saveChanges(dialogContext);
            } else if (wantsSave == false && dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }
          },
          child: Text(silsilaText('رجوع')),
        ),
        FilledButton(onPressed: () => saveChanges(dialogContext), child: Text(silsilaText('حفظ التعديل'))),
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
        title: Text(silsilaText('تأكيد حذف السجل')),
        content: Text('هل تريد حذف السجل «$visibleCode» من شاشة «$_page»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(silsilaText('No / لا'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(silsilaText('Yes / نعم، احذف'))),
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

  Future<void> _importExcel() async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.trim().isEmpty) {
      _showActionMessage('لا يمكن الاستيراد قبل ربط المستخدم بشركة نشطة.');
      return;
    }
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showActionMessage('تعذر قراءة الملف. اختر ملف Excel بصيغة XLSX.');
        return;
      }
      final workbook = excel.Excel.decodeBytes(bytes);
      final sheets = workbook.tables.values.where((sheet) => sheet.rows.isNotEmpty).toList();
      if (sheets.isEmpty) {
        _showActionMessage('ملف Excel لا يحتوي على صفوف قابلة للاستيراد.');
        return;
      }
      final rows = sheets.first.rows;
      final headers = rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
      if (headers.every((header) => header.isEmpty)) {
        _showActionMessage('يجب أن يحتوي الصف الأول على أسماء الأعمدة.');
        return;
      }
      final imported = <Map<String, String>>[];
      for (final row in rows.skip(1)) {
        final record = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          if (headers[i].isNotEmpty && headers[i] != '_مرجع داخلي') {
            record[headers[i]] = row[i]?.value?.toString() ?? '';
          }
        }
        if (record.values.any((value) => value.trim().isNotEmpty)) imported.add(record);
      }
      if (imported.isEmpty) {
        _showActionMessage('لم يتم العثور على سجلات بعد صف العناوين.');
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(silsilaText('تأكيد استيراد Excel')),
          content: Text('سيتم استيراد ${imported.length} سجلًا إلى شاشة «$_page». ستُحدّث السجلات التي تتطابق مفاتيحها. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(silsilaText('إلغاء'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(silsilaText('استيراد'))),
          ],
        ),
      );
      if (confirm != true) return;
      var savedCount = 0;
      for (final record in imported) {
        await _workspaceRecordsService.saveRecord(companyId: companyId, pageKey: _page, record: record);
        savedCount++;
      }
      await _loadWorkspacePage(_page);
      if (mounted) _showActionMessage('تم استيراد $savedCount سجلًا من ملف Excel إلى شاشة «$_page».');
    } catch (error) {
      if (mounted) _showActionMessage('تعذر استيراد ملف Excel: $error');
    }
  }


  Future<void> _printCurrentPagePdf() async {
    if (_rows.isEmpty) {
      _showActionMessage('لا توجد بيانات للطباعة من شاشة $_page');
      return;
    }
    try {
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      final keys = _rows.first.keys.where((key) => key != '_مرجع داخلي').toList();
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
          pw.Text('Silsila • $_module • $_page', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: keys,
            data: _rows.map((row) => keys.map((key) => row[key] ?? '').toList()).toList(),
          ),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) async => document.save());
    } catch (error) {
      if (mounted) _showActionMessage('تعذرت الطباعة أو إنشاء PDF: $error');
    }
  }

  void _showPrintPreview({required bool pdf}) {
    final rows = _rows;
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(pdf ? 'تصدير PDF — $_page' : 'معاينة الطباعة — $_page'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('سلسلة Silsila • $_module • $_group', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8), Text('الشاشة: $_page • عدد السجلات: ${rows.length}'), const Divider(),
        if (rows.isEmpty) Text(silsilaText('لا توجد بيانات لعرضها.'))
        else ...rows.take(30).map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join('  |  ')))),
        if (rows.length > 30) Text(silsilaText('تم عرض أول 30 سجلًا في المعاينة.')),
        const SizedBox(height: 8),
        Text(pdf ? 'هذه معاينة تجهيز PDF؛ يلزم إضافة محرك PDF للتنزيل الفعلي.' : 'هذه معاينة للطباعة؛ إرسالها إلى الطابعة يحتاج تفعيل خدمة الطباعة في نسخة التشغيل.', style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(silsilaText('إغلاق')))],
    ));
  }

  Widget _recordAction(String label, IconData icon, Color color, VoidCallback action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color, compact: true);

  Widget _recordToolbar({bool includeAdd = true}) {
    final reports = _group == 'تقارير';
    // Keep the task actions on one horizontal line at every viewport width.
    // Narrow screens can scroll the toolbar horizontally instead of wrapping.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _recordAction('تحديث', Icons.refresh_rounded, const Color(0xFF2475B8), () => _loadWorkspacePage(_page)),
        if (!reports && includeAdd) _recordAction('إضافة', Icons.add_rounded, const Color(0xFF18865A), _openAddDialog),
        if (!reports) _recordAction('حفظ', Icons.save_outlined, _purple, _saveCurrentPage),
        if (!reports) _recordAction('تعديل', Icons.edit_outlined, _orange, _editCurrentRecord),
        if (!reports) _recordAction('حذف', Icons.delete_outline_rounded, const Color(0xFFB42318), _deleteCurrentRecord),
        _recordAction('معاينة', Icons.preview_outlined, const Color(0xFF6E2BA6), () => _showPrintPreview(pdf: false)),
        _recordAction('طباعة', Icons.print_outlined, _pink, _printCurrentPagePdf),
        _recordAction('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF16834A), _importExcel),
        _recordAction('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFD32F2F), _printCurrentPagePdf),
        if (reports) _recordAction('إلغاء التحديد', Icons.clear_all_rounded, _purple, () => setState(() => _selectedRecord = null)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: SilsilaLanguage.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: LayoutBuilder(builder: (context, c) {
        // Responsive breakpoints: keep navigation, workspace, and utility panels visible.
        final width = c.maxWidth;
        final compact = width < 980;
        // Keep both navigation and work panels visible at every desktop breakpoint.
        // Their widths adapt to the viewport; the center workspace receives all remaining space.
        final sidebarWidth = width < 760 ? 148.0 : width < 1050 ? 178.0 : width < 1320 ? 205.0 : width < 1550 ? 228.0 : 248.0;
        final rightPanelWidth = width < 760 ? 148.0 : width < 1050 ? 178.0 : width < 1320 ? 205.0 : width < 1550 ? 228.0 : 248.0;
        final pagePadding = width < 480 ? 6.0 : width < 980 ? 8.0 : width < 1450 ? 12.0 : 16.0;
        return Scaffold(
          backgroundColor: _canvas,
          body: Row(children: [
            if (_mainSidebarVisible) SizedBox(width: sidebarWidth, child: _sidebar()),
            Expanded(child: Column(children: [
              _header(compact),
              Expanded(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // This screen has its own bounded-height tree/grid and must
                    // not be nested in SingleChildScrollView.
                    child: (
                      _page == 'بيانات جغرافية' ||
                      _page == 'أنواع المستخدمين والمستخدمين' ||
                      _page == 'أنواع المستخدمين' ||
                      _page == 'المستخدمين' ||
                      _page == 'قوالب صلاحيات المستخدمين' ||
                      _page == 'صلاحيات المستخدمين' ||
                      _page == 'سياسات البرنامج'
                    )
                        ? Padding(
                            padding: EdgeInsets.all(pagePadding),
                            child: ErpKeyboardNavigation(
                              child: _page == 'بيانات جغرافية'
                                  ? ErpGeographicDataScreen(
                                      companyId: _appManagementCompanyId,
                                    )
                                  : _page == 'سياسات البرنامج'
                                      ? ErpProgramPoliciesScreen(
                                          companyId: _appManagementCompanyId,
                                        )
                                      : ErpUserAdminScreen(
                                          companyId: _appManagementCompanyId,
                                          initialView: _page == 'قوالب صلاحيات المستخدمين'
                                              ? 'templates'
                                              : _page == 'صلاحيات المستخدمين'
                                                  ? 'permissions'
                                                  : 'hierarchy',
                                        ),
                            ),
                          )
                        : SingleChildScrollView(
                      padding: EdgeInsets.all(pagePadding),
                      child: ErpKeyboardNavigation(child: _page == 'مسح جميع البيانات' ? ErpClearDataScreen(companyId: _appManagementCompanyId) : _page == 'أنواع الأنشطة' ? ErpActivityTypesScreen(companyId: _appManagementCompanyId) : _page == 'سياسات البرنامج' ? ErpProgramPoliciesScreen(companyId: _appManagementCompanyId) : _page == 'مؤجلات وعمولات الموردين' ? ErpSupplierDeferredCommissionsScreen(companyId: _appManagementCompanyId) : _page == 'عن البرنامج' ? _about() : _page == 'قاعدة العملاء المحتملين' ? ErpPublicLeadsScreen(companyId: _appManagementCompanyId) : _page == 'أهداف العملاء الشهرية' || _page == 'عمولات المندوبين' || _page == 'عمولات المبيعات' || _page == 'خطط العمولة' || _page == 'مسودات العمولات' || _page == 'تحقيق أهداف العملاء' || _page == 'تقرير العمولات المستحقة' ? ErpSalesTargetsCommissionsScreen(companyId: _appManagementCompanyId, initialTabIndex: _page == 'عمولات المندوبين' || _page == 'عمولات المبيعات' ? 1 : _page == 'خطط العمولة' ? 2 : _page == 'مسودات العمولات' || _page == 'تقرير العمولات المستحقة' ? 3 : 0) : _page == 'العملاء' || _page == 'الموردون' || _page == 'دليل العملاء' || _page == 'دليل الموردين' ? ErpPartiesScreen(initialCompanyId: _appManagementCompanyId, initialKind: _page == 'الموردون' || _page == 'دليل الموردين' ? 'supplier' : 'customer') : _page == 'العملات' ? ErpCurrenciesScreen(companyId: _appManagementCompanyId) : _page == 'شجرة الحسابات' ? ErpAccountsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الفترات المالية' || _page == 'إقفال الفترة' ? ErpFiscalPeriodsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'قائمة اعتماد القيود' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId, initialStatus: 'draft') : _page == 'قيود اليومية' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId) : _page == 'ميزان المراجعة' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.trialBalance, initialCompanyId: _appManagementCompanyId) : _page == 'الأستاذ العام' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.generalLedger, initialCompanyId: _appManagementCompanyId) : _page == 'حركة حساب' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.accountMovement, initialCompanyId: _appManagementCompanyId) : _page == 'الملخص التنفيذي' || _page == 'ملخص تنفيذي' ? _home() : _module == 'إدارة البرنامج' && _page == 'بيانات الشركة' ? ErpCompanyProfileScreen(companyId: _appManagementCompanyId, onCompanyCreated: (companyId) async { if (!mounted) return; setState(() => _appManagementCompanyId = companyId); await _loadWorkspaceSettings(companyId); await _loadExecutiveMetrics(companyId); }) : _page == 'إدارة إعلانات التطبيق' ? ErpAppAdvertisementsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey]) : _page == 'إدارة الشعار والصور' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey], initialAssetType: 'app_logo') : _page == 'إدارة صور الأصناف والفئات' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey], initialAssetType: 'item') : _page == 'إدارة صور الموردين والعملاء' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey], initialAssetType: 'supplier') : _page == 'إدارة شركات الشحن' ? const ErpShippingCompaniesScreen() : _page == 'الفروع' || _page == 'دليل الفروع' ? ErpBranchesScreen(companyId: _appManagementCompanyId) : _page == 'مراكز التكلفة' || _page == 'الفروع ومراكز التكلفة' ? ErpCostCentersScreen(companyId: _appManagementCompanyId) : _page == 'بيانات جغرافية' ? ErpGeographicDataScreen(companyId: _appManagementCompanyId) : _module == 'إدارة التطبيقات' ? _appManagement() : _page == 'اختبار ومراجعة الحركات' ? ErpMovementAuditScreen(initialCompanyId: _appManagementCompanyId) : _page == 'جامع صور الأصناف' ? const ErpImageCollectorScreen() : _page == 'استيراد بيانات اصناف' ? const ErpItemDataImportScreen() : _page == 'تنزيل بيانات أصناف' ? const ErpItemDataDownloadScreen() : _page == 'دليل المخازن' ? ErpInventoryMasterScreen(initialCompanyId: _appManagementCompanyId, initialView: 'warehouses') : _page == 'فئات الأصناف' ? ErpItemCategoriesScreen(companyId: _appManagementCompanyId) : _page == 'دليل الأصناف' ? ErpInventoryMasterScreen(initialCompanyId: _appManagementCompanyId, initialView: 'items') : _page == 'وحدات الأصناف' ? ErpItemUnitsScreen(companyId: _appManagementCompanyId) : _page == 'أرصدة الأصناف' || _page == 'كارت الصنف' || _page == 'الجرد والفروق' || _page == 'إذن إضافة' || _page == 'إذن صرف' || _page == 'تحويل مخزني' || _page == 'تسوية جرد' || _page == 'جرد فعلي' ? ErpInventoryScreen(initialCompanyId: _appManagementCompanyId) : _page == 'ملف الموظف' || _page == 'الحضور والانصراف' || _page == 'الإجازات والأذونات' ? ErpHrOperationsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'مسير الرواتب' || _page == 'صرف الرواتب' ? ErpPayrollScreen(initialCompanyId: _appManagementCompanyId) : _page == 'عروض الأصناف' ? ErpItemOffersScreen(companyId: _appManagementCompanyId) : _page == 'قوائم أسعار البيع' ? ErpPriceListsScreen(initialCompanyId: _appManagementCompanyId, initialKind: 'sale') : _page == 'قوائم أسعار الموردين' || _page == 'قوائم أسعار الشراء' ? ErpPriceListsScreen(initialCompanyId: _appManagementCompanyId, initialKind: 'purchase') : _page == 'خريطة الحسابات التشغيلية' ? ErpOperationalAccountMappingsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الخزائن الرئيسية والفرعية' ? ErpCashboxesScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الحسابات البنكية' ? ErpCashboxesScreen(initialCompanyId: _appManagementCompanyId, initialBankOnly: true) : _page == 'سندات القبض' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'receipt') : _page == 'سندات الصرف' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'payment') : _page == 'تحويل بين الخزائن' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'transfer') : _page == 'طلب شراء' || _page == 'أمر شراء' || _page == 'استلام مشتريات' || _page == 'فاتورة مشتريات' || _page == 'مرتجع مشتريات' ? ErpOperationalDocumentsScreen(initialCompanyId: _appManagementCompanyId, kind: ErpOperationalKind.purchase, initialDocumentType: _page == 'طلب شراء' || _page == 'أمر شراء' ? 'order' : _page == 'استلام مشتريات' ? 'receipt' : _page == 'مرتجع مشتريات' ? 'return' : 'invoice') : _page == 'إذن التجهيز' ? ErpSalesFulfillmentScreen(companyId: _appManagementCompanyId ?? '', kind: 'preparation') : _page == 'إذن التسليم' ? ErpSalesFulfillmentScreen(companyId: _appManagementCompanyId ?? '', kind: 'delivery') : _page == 'عرض سعر' || _page == 'أمر بيع' || _page == 'فاتورة مبيعات' || _page == 'مرتجع مبيعات' ? ErpOperationalDocumentsScreen(initialCompanyId: _appManagementCompanyId, kind: ErpOperationalKind.sales, initialDocumentType: _page == 'عرض سعر' ? 'quotation' : _page == 'أمر بيع' ? 'order' : _page == 'مرتجع مبيعات' ? 'return' : 'invoice') : _page == 'أنواع المستخدمين والمستخدمين' || _page == 'أنواع المستخدمين' || _page == 'المستخدمين' ? ErpUserAdminScreen(companyId: _appManagementCompanyId, initialView: 'hierarchy') : _page == 'تصنيفات المستخدمين' ? ErpUserClassificationsScreen(companyId: _appManagementCompanyId) : _page == 'قوالب صلاحيات المستخدمين' ? ErpUserAdminScreen(companyId: _appManagementCompanyId, initialView: 'templates') : _page == 'صلاحيات المستخدمين' ? ErpUserAdminScreen(companyId: _appManagementCompanyId, initialView: 'permissions') : _modules['الفاتورة الإلكترونية']![_group]!.contains(_page) ? ErpEinvoiceScreen(companyId: _appManagementCompanyId, initialView: _page) : _page == 'سياسات التسعير والخصومات' ? _pricingPolicyScreen() : _page == 'توزيع الأصناف على المندوبين' ? ErpDelegateAllocationScreen(companyId: _appManagementCompanyId) : _page == 'قيود البيع والشراء' ? _transactionRestrictionsScreen() : _page == 'قائمة اعتماد القيود' ? _journalApprovalScreen() : _page == 'قواعد الورديات والحضور والانصراف' ? HrShiftRulesScreen(companyId: _appManagementCompanyId) : _page == 'أجهزة البصمة وربط الحضور' ? HrFingerprintDevicesScreen(companyId: _appManagementCompanyId) : _workspace()),
                    ),
                  ),
                  if (_utilitySidebarVisible) SizedBox(
                    width: rightPanelWidth,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(top: 12),
                      child: _rightPanel(),
                    ),
                  ),
                ],
              )),
            ])),
          ]),
        );
      }),
    );
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
              Image.asset(
                'assets/images/silsila_logo.png',
                width: 58,
                height: 58,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.link_rounded,
                  color: _orange,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(silsilaText('سلسلة Silsila'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  SizedBox(height: 4),
                  Text(silsilaText('سلسلة .. بنربط السوق ببعضه'), style: TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text(silsilaText('ERP • إدارة موارد المؤسسة'), style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                      onTap: () {
                        setState(() {
                          _module = name;
                          if (_expandedModules.contains(name)) {
                            _expandedModules.remove(name);
                            _expandedGroups.removeWhere((key) => key.startsWith('$name::'));
                          } else {
                            _expandedModules.add(name);
                            _expandedGroups.removeWhere((key) => key.startsWith('$name::'));
                          }
                        });
                      },
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
                        _module = name;
                        _expandedModules.add(name);
                        _expandedGroups.removeWhere((key) => key.startsWith('$name::'));
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
                  return Container(
                    color: const Color(0xFFF1E8FA),
                    child: Padding(
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
                            selectedTileColor: const Color(0xFFFFA015),
                            hoverColor: const Color(0xFFFFA015),
                            title: Text(groupEntry.key, style: const TextStyle(color: Color(0xFF3E007D), fontSize: 11, fontWeight: FontWeight.w800)),
                            onTap: () {
                              setState(() {
                                _module = name;
                                _group = groupEntry.key;
                                if (groupOpen) {
                                  _expandedGroups.remove(groupKey);
                                } else {
                                  _expandedModules.add(name);
                                  _expandedGroups.add(groupKey);
                                }
                              });
                            },
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
                          icon: Icon(groupOpen ? Icons.expand_more_rounded : Icons.chevron_left_rounded, color: const Color(0xFF3E007D), size: 22),
                        ),
                      ]),
                      if (groupOpen)
                        ...groupEntry.value.map((page) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 20, end: 5),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                            hoverColor: const Color(0xFFFFA015),
                            selected: page == _page && selectedModule,
                            selectedTileColor: const Color(0xFFFFA015),
                            minLeadingWidth: 12,
                            leading: Icon(page == _page && selectedModule ? Icons.radio_button_checked_rounded : Icons.circle_outlined, color: const Color(0xFF3E007D), size: 11),
                            title: Text(page, style: TextStyle(color: const Color(0xFF3E007D), fontSize: 10.5, fontWeight: page == _page && selectedModule ? FontWeight.w800 : FontWeight.normal)),
                            onTap: () {
                              setState(() {
                                _module = name;
                                _group = groupEntry.key;
                                _page = page;
                                _search = '';
                                _expandedModules.add(name);
                                _expandedGroups.add(groupKey);
                              });
                              _loadWorkspacePage(page);
                            },
                          ),
                        )),
                    ]),
                  ));
                }),
            ]);
          }).toList(),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), selected: _page == 'عن البرنامج', selectedTileColor: Colors.white.withValues(alpha: .14), leading: const Icon(Icons.info_outline_rounded, color: _orange, size: 20), title: Text(silsilaText('عن البرنامج'), style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)), onTap: () => setState(() { _page = 'عن البرنامج'; _search = ''; }))),
          ],
        )),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: _leaveCurrentUser,
                icon: const Icon(Icons.logout_rounded, size: 20, color: _orange),
                label: Text(
                  silsilaText('تسجيل خروج'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: const Size(0, 42),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  overlayColor: Colors.white.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Padding(padding: EdgeInsets.all(14), child: Column(children: [
          Text(silsilaText('سلسلة للبرمجيات'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(silsilaText('سلسلة .. بنربط السوق ببعضه'), style: TextStyle(color: _orange, fontSize: 12)),
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
              Expanded(child: Text(silsilaText('لوحة التنبيهات'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)), child: Text(silsilaText('3'), style: TextStyle(color: _purple, fontWeight: FontWeight.w900))),
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
              Expanded(child: Text(silsilaText('سجل النشاطات'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
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
              Expanded(child: Text(silsilaText('الوصول السريع'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 5, runSpacing: 5, children: [
              _quick('فاتورة البيع', Icons.point_of_sale_rounded, () => _open('المبيعات والعملاء', 'حركات', 'فاتورة مبيعات')),
              _quick('جامع صور الأصناف', Icons.photo_library_outlined, () => _open('المخازن والفروع', 'حركات', 'جامع صور الأصناف')),
            ]),
          ]),
        ),
      ],
      if (_notificationsPanelVisible || _activityPanelVisible)
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(silsilaText('ملاحظة: التنبيهات وسجل النشاطات حاليًا أمثلة محلية، وليسا متصلين بعد بأحداث النظام الفعلية.'), style: TextStyle(color: Colors.black54, fontSize: 10, height: 1.6)),
        ),
      if (!_notificationsPanelVisible && !_activityPanelVisible && !_quickAccessPanelVisible)
        Padding(
          padding: EdgeInsets.all(12),
          child: Text(silsilaText('تم إخفاء لوحات المهام. استخدم زر إظهار اللوحات في الشريط العلوي لإعادتها.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.6)),
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
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6E2BA6)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(silsilaText('إدارة التطبيقات'), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      Text(silsilaText('مكان موحد لتخصيص الهوية والألوان والصور والصلاحيات وإعدادات التطبيقات التابعة لسلسلة.'), style: TextStyle(color: Colors.white70, height: 1.7)),
    ])),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(silsilaText('التطبيقات التابعة لسلسلة'), style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(silsilaText('إدارة تطبيق سلسلة والتطبيقات الإضافية من مكان واحد؛ التطبيقات غير المنشورة تظل قيد التجهيز دون إظهار قسم مستقل لها.'), style: TextStyle(color: Colors.black54, height: 1.6, fontSize: 12)),
      const SizedBox(height: 12),
      _managedAppCard('تطبيق سلسلة', 'التطبيق الرئيسي', Icons.apps_rounded, _selectedAppKey == 'silsila', () => _selectManagedApp('silsila')),
      _managedAppCard('تطبيق رقم 2', 'قيد التجهيز — يمكن استكمال إعداداته هنا', Icons.phone_android_rounded, _selectedAppKey == 'app_2', () => _selectManagedApp('app_2')),
      _managedAppCard('تطبيق رقم 3', 'قيد التجهيز — يمكن استكمال إعداداته هنا', Icons.web_rounded, _selectedAppKey == 'app_3', () => _selectManagedApp('app_3')),
      const Divider(height: 28),
      Text(silsilaText('هوية التطبيق المحدد'), style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
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
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _appPrimary, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.apps_rounded, color: Colors.white, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_appName.trim().isEmpty ? 'اسم التطبيق' : _appName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text(silsilaText('معاينة الألوان المختارة'), style: TextStyle(color: Colors.white70, fontSize: 11))])), Container(width: 18, height: 18, decoration: BoxDecoration(color: _appAccent, shape: BoxShape.circle))])),
      const SizedBox(height: 18),
      Text(silsilaText('إدارة الملفات والصور'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 8),
      _managementTile(Icons.image_outlined, 'شعار التطبيق وصورة البداية', 'تحديد ملفات الهوية التي ستستخدم عند ربط رفع الملفات'),
      _managementTile(Icons.category_outlined, 'صور الأصناف والفئات', 'إضافة صور المنتجات وتصنيفات المواد الغذائية'),
      _managementTile(Icons.factory_outlined, 'صور الموردين والعملاء', 'إدارة الشعارات والصور والبيانات التعريفية'),
      _managementTile(Icons.local_shipping_outlined, 'شركات الشحن', 'صور الشركات وبيانات التواصل وخيارات التوصيل'),
      const SizedBox(height: 18),
      Text(silsilaText('صلاحيات الأدوار'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
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
      Text(silsilaText('تُحفظ كل صلاحية منفردة في Supabase. لا تُعد هذه الواجهة بديلًا عن تحقق الخادم وسياسات RLS.'), style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.6)),
      const SizedBox(height: 18),
      Text(silsilaText('سجل النشاطات المحفوظ'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 6),
      if (_savedAppActivity.isEmpty)
        Text(silsilaText('لا توجد أحداث محفوظة للتطبيق أو أن سجل النشاطات غير مهيأ.'), style: TextStyle(color: Colors.black54, fontSize: 11))
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
      Text(silsilaText('الحفظ الدائم يعمل بعد تهيئة Supabase وتطبيق جداول إدارة التطبيقات وسياسات RLS المقيدة بالشركة. لم يتم ربط رفع الصور أو فرض الصلاحيات من هذه الأزرار.'), style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.7)),
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

  Widget _header(bool compact) => Container(height: compact ? 62 : 72, padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE7F2)))), child: Row(children: [
    Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Image.asset(
        'assets/images/silsila_logo.png',
        width: 38,
        height: 38,
        fit: BoxFit.contain,
      ),
    ),
    if (compact)
      const SizedBox(width: 4),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_module, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: compact ? 15 : 18)),
      if (!compact) const SizedBox(height: 4),
      Wrap(
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: _goHome,
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              child: Text(silsilaText('الرئيسية'), style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
            ),
          ),
          Text(silsilaText('/'), style: TextStyle(color: Colors.black45, fontSize: 11)),
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
          Text(silsilaText('/'), style: TextStyle(color: Colors.black45, fontSize: 11)),
          Text(_page, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    ])),
    if (!compact) ...[
      SizedBox(width: 190, child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'بحث سريع', prefixIcon: const Icon(Icons.search_rounded), isDense: true, filled: true, fillColor: _canvas, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
    ],
    const SizedBox(width: 4),

    IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _mainSidebarVisible ? 'إخفاء القوائم الرئيسية' : 'إظهار القوائم الرئيسية',
      onPressed: () => setState(() => _mainSidebarVisible = !_mainSidebarVisible),
      icon: Icon(Icons.more_horiz_rounded, color: _mainSidebarVisible ? _purple : _orange),
    ),
    IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _utilitySidebarVisible ? 'إخفاء النشاطات والتنبيهات والوصول السريع' : 'إظهار النشاطات والتنبيهات والوصول السريع',
      onPressed: () => setState(() => _utilitySidebarVisible = !_utilitySidebarVisible),
      icon: Icon(Icons.more_vert_rounded, color: _utilitySidebarVisible ? _purple : _orange),
    ),
    IconButton(visualDensity: VisualDensity.compact, tooltip: 'الإشعارات', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(silsilaText('مركز الإشعارات التجريبي')))), icon: const Icon(Icons.notifications_none_rounded, color: _purple)),
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
    if (!_executiveAccessChecked && _appManagementCompanyId != null) {
      return const Center(child: CircularProgressIndicator());
    }
    if ((_executiveAccessChecked && !_executiveSummaryAllowed) || (_executivePartialConfigured && _executiveAllowedSections.isEmpty)) {
      return Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7E0EF))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, color: _purple, size: 52),
          const SizedBox(height: 12),
          Text(_executiveSummaryAllowed ? 'لا توجد أقسام متاحة في الملخص التنفيذي' : 'الملخص التنفيذي غير متاح لحسابك', style: const TextStyle(color: _purple, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(silsilaText('اطلب من مسؤول النظام منح صلاحية الملخص التنفيذي أو تفعيل قسم واحد على الأقل من أقسامه.'), textAlign: TextAlign.center, style: TextStyle(height: 1.6)),
        ]),
      ));
    }
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
          {'title': 'دوران المخزون', 'value': '— مرة', 'note': 'خلال الفترة', 'icon': Icons.sync_alt_rounded, 'color': _purple, 'details': 'معدل دوران المخزون ومتوسط أيام التخزين حسب الفئة والصنف.'},
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

    final visibleSections = _executivePartialConfigured
        ? sections.where((section) => _executiveAllowedSections.contains(section['title'])).toList()
        : sections;
    final allItems = visibleSections.expand((section) => section['items'] as List<Map<String, Object>>).toList();
    final canSales = !_executivePartialConfigured || _executiveAllowedSections.contains('المبيعات والعملاء');
    final canFinance = !_executivePartialConfigured || _executiveAllowedSections.contains('المالية والسيولة');
    final canInventory = !_executivePartialConfigured || _executiveAllowedSections.contains('المخزون والمشتريات');


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
              Text(silsilaText('الملخص التنفيذي'), style: TextStyle(fontSize: 29, height: 1.2, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.3)),
              const SizedBox(height: 6),
              Text(silsilaText('مركز قيادة الأداء المالي والتشغيلي • مؤشرات وتحليلات موحدة للإدارة'), style: TextStyle(color: Color(0xFFECE2F8), fontSize: 15, height: 1.5)),
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
              if (canSales) _executiveKpi('صافي المبيعات', _executiveMoney(_executiveSales), 'الشهر الحالي • فواتير مرحلة', Icons.point_of_sale_rounded, _purple),
              if (canFinance) _executiveKpi('مجمل الربح التقديري', _executiveMoney(_executiveGrossProfit), 'على تكلفة الشراء الحالية', Icons.trending_up_rounded, _green),
              if (canFinance) _executiveKpi('المحصّل على الفواتير', _executiveMoney(_executiveCollections), 'المدفوع المسجل بالفواتير', Icons.payments_outlined, _orange),
              if (canFinance) _executiveKpi('مديونية العملاء', _executiveMoney(_executiveReceivables), 'فواتير غير مسددة بالكامل', Icons.groups_rounded, _pink),
              if (canInventory) _executiveKpi('قيمة المخزون', _executiveMoney(_executiveInventoryValue), 'من حركات المخزون والتكلفة الحالية', Icons.inventory_2_rounded, const Color(0xFF2475B8)),
              if (canInventory) _executiveKpi('مشتريات الشهر', _executiveMoney(_executivePurchases), 'فواتير شراء مرحلة وغير تجريبية', Icons.local_shipping_outlined, const Color(0xFF168A70)),
            ],
          );
        }),
        const SizedBox(height: 16),
        if ((wide || mid) && (canSales || canFinance || canInventory))
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (canSales) Expanded(child: _executiveChartPanel(
                title: 'اتجاه المبيعات',
                caption: 'آخر 7 أيام • فواتير مرحلة وغير تجريبية',
                color: _purple,
                value: _executiveMoney(_executiveSales),
                chart: _ExecutiveChartPainter(color: _purple, values: _executiveDailySales),
              )),
              const SizedBox(width: 12),
              if (canSales || canFinance) Expanded(child: _executiveChartPanel(
                title: 'مزيج الأداء',
                caption: 'مبيعات • مشتريات • المحصّل',
                color: _orange,
                value: _executiveMoney(_executivePurchases),
                chart: _ExecutiveBarsPainter(values: <double>[_executiveSales ?? 0, _executivePurchases ?? 0, _executiveCollections ?? 0]),
              )),
            ]),
            const SizedBox(height: 12),
            if (canSales && canFinance && canInventory) _executiveHighlights(),
          ])
        else ...[
          if (canSales) _executiveChartPanel(
            title: 'اتجاه المبيعات',
            caption: 'آخر 7 أيام • فواتير مرحلة وغير تجريبية',
            color: _purple,
            value: _executiveMoney(_executiveSales),
            chart: const _ExecutiveChartPainter(color: _purple),
          ),
          const SizedBox(height: 3),
          if (canSales || canFinance) _executiveChartPanel(
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
        if (canFinance || canInventory) _executiveAdditionalCharts(sideBySide: wide || mid, showCollections: canFinance, showInventory: canInventory),
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
            children: visibleSections.map((section) => _executiveSectionCompact(
              title: section['title'] as String,
              icon: section['icon'] as IconData,
              color: section['color'] as Color,
              items: section['items'] as List<Map<String, Object>>,
            )).toList(),
          );
        }),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.info_outline_rounded, color: _orange, size: 11),
          SizedBox(width: 4),
          Expanded(child: Text(silsilaText('المؤشرات الرقمية والمخططات توضيحية حتى ربطها بالحركات الفعلية المعتمدة.'), style: TextStyle(fontSize: 11, color: Colors.black54))),
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

  Widget _executiveAdditionalCharts({required bool sideBySide, required bool showCollections, required bool showInventory}) {
    final charts = <Widget>[
      if (showCollections) _executiveChartPanel(
        title: 'المدفوع المسجل على الفواتير',
        caption: 'آخر 7 أيام • بيانات الفواتير المرحلة',
        color: const Color(0xFF168A70),
        value: _executiveMoney(_executiveCollections),
        chart: _ExecutiveChartPainter(color: const Color(0xFF168A70), values: _executiveDailyCollections),
      ),
      if (showInventory) _executiveChartPanel(
        title: 'قيمة المخزون حسب الفئة',
        caption: 'تقدير على تكلفة الشراء الحالية',
        color: _pink,
        value: _executiveMoney(_executiveInventoryValue),
        chart: _ExecutiveBarsPainter(values: _executiveInventoryGroupValues),
        footerLabels: _executiveInventoryGroupLabels.isEmpty
            ? const <String>['مجموعة 1','مجموعة 2','مجموعة 3']
            : _executiveInventoryGroupLabels.take(3).toList(),
      ),
    ];
    if (charts.isEmpty) return const SizedBox.shrink();
    if (charts.length == 1) return charts.first;
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
      Text(silsilaText('مؤشرات تحتاج متابعة'), style: TextStyle(fontSize: 20, color: _purple, fontWeight: FontWeight.w900)),
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
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(silsilaText('إغلاق')))],
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
          Text(silsilaText('تظهر النتائج الرقمية التفصيلية بعد ربط المؤشر بالحركات الفعلية المعتمدة.'), style: TextStyle(color: Colors.black54, fontSize: 9, height: 1.4)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(silsilaText('إغلاق')))],
      ),
    );
  }

  static const Color _green = Color(0xFF18865A);

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
      const SizedBox(height: 16),
      if (_group == 'تقارير') Padding(padding: EdgeInsets.only(bottom: 12), child: Text(silsilaText('نموذج تقارير تجريبي؛ ستظهر المؤشرات الفعلية بعد ربط مصادر البيانات واعتماد المعادلات المحاسبية.'), style: TextStyle(color: Colors.black54, height: 1.6))),
      if (_rows.isEmpty && _page != 'الهيكل الوظيفي') Padding(padding: EdgeInsets.all(28), child: Text(silsilaText('لا توجد نتائج مطابقة.'), textAlign: TextAlign.center))
       else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F0FA)), showCheckboxColumn: true, columns: _gridKeys.map((k) => DataColumn(label: Text(k, style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)))).toList(), rows: _rows.map((r) => DataRow(selected: _selectedRecord != null && _sameRecord(r, _selectedRecord!), onSelectChanged: (selected) => setState(() => _selectedRecord = selected == true ? Map<String, String>.from(r) : null), cells: _gridKeys.map((k) => DataCell(Text(r[k] ?? '—'), onTap: () => setState(() => _selectedRecord = Map<String, String>.from(r)))).toList())).toList())),
      const SizedBox(height: 12),
      Text('عدد السجلات المعروضة: ${_rows.length} • تحقق من حالة الحفظ بجوار كل عملية', style: const TextStyle(color: Colors.black45, fontSize: 11)),
    ])),
  ]);

  final Map<String, bool> _permissionDraft = {};
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
  final Set<String> _approvedJournals = {};

  Widget _pricingPolicyScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('سياسات التسعير والخصومات','حد تسعير الصنف والزيادة أو النقصان وحدود خصم الصنف والفاتورة'),
      Wrap(spacing:12,runSpacing:12,children:[_fieldBox('سعر الصنف الأساسي',_basePriceController),_fieldBox('حد التسعير المعتمد',_priceLimitController),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_pricingMode,decoration:const InputDecoration(labelText:'طريقة التعديل',border:OutlineInputBorder()),items:const ['نسبة','قيمة'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingMode=v??_pricingMode))),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_pricingDirection,decoration:const InputDecoration(labelText:'الاتجاه من حد التسعير',border:OutlineInputBorder()),items:const ['زيادة','نقصان'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingDirection=v??_pricingDirection)),),_fieldBox(_pricingMode=='نسبة'?'نسبة الزيادة / النقصان %':'قيمة الزيادة / النقصان',_priceValueController),_fieldBox('أقصى خصم على إجمالي الفاتورة %',_invoiceDiscountController),_fieldBox('أقصى خصم على مستوى الصنف %',_itemDiscountController)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>_saveWorkspaceSetting('pricing_policy', {'base_price':_basePriceController.text.trim(),'price_limit':_priceLimitController.text.trim(),'mode':_pricingMode,'direction':_pricingDirection,'price_value':_priceValueController.text.trim(),'invoice_discount':_invoiceDiscountController.text.trim(),'item_discount':_itemDiscountController.text.trim()}, successMessage:'تم حفظ سياسة التسعير في قاعدة البيانات.').then((_) {}),icon:const Icon(Icons.save),label:Text(silsilaText('حفظ سياسة التسعير'))),
      const SizedBox(height:8),
      Text(silsilaText('يجب أن يُحسب السعر النهائي من حد التسعير المسجل للصنف، مع منع تجاوز صلاحية المستخدم وحدود الخصم. يلزم ربط الحقول ببيانات الأصناف وقاعدة البيانات قبل تطبيقها على الفواتير.'),style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _transactionRestrictionsScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قيود البيع والشراء','إيقاف البيع أو الشراء أو تحديد الحد حسب الصنف أو الفاتورة أو العميل أو المندوب'),
      Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:220,child:DropdownButtonFormField<String>(value:_restrictionAction,decoration:const InputDecoration(labelText:'الإجراء',border:OutlineInputBorder()),items:const ['إيقاف البيع','إيقاف الشراء','تحديد حد البيع'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionAction=v??_restrictionAction))),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_restrictionTarget,decoration:const InputDecoration(labelText:'مستوى تطبيق القيد',border:OutlineInputBorder()),items:const ['الصنف','الفاتورة الواحدة','العميل','المندوب'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionTarget=v??_restrictionTarget))),_fieldBox('كود الصنف / الفاتورة / العميل / المندوب',_restrictionItem),_fieldBox('العميل (اختياري)',_restrictionCustomer),_fieldBox('المندوب (اختياري)',_restrictionDelegate)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text(silsilaText('إضافة قيد')),content:Text('الإجراء: $_restrictionAction • المستوى: $_restrictionTarget • المعرف: ${_restrictionItem.text}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(silsilaText('إغلاق'))),FilledButton(onPressed:() async {final saved=await _saveWorkspaceSetting('transaction_restrictions', {'action':_restrictionAction,'target':_restrictionTarget,'item':_restrictionItem.text.trim(),'customer':_restrictionCustomer.text.trim(),'delegate':_restrictionDelegate.text.trim()}, successMessage:'تم حفظ إعداد القيد في قاعدة البيانات.');if(saved&&mounted){setState(()=>_activityLog.insert(0,'تم حفظ إعداد قيد: $_restrictionAction / $_restrictionTarget / ${_restrictionItem.text}'));Navigator.pop(ctx);}},child:Text(silsilaText('حفظ الإعداد')))])),icon:const Icon(Icons.block),label:Text(silsilaText('إضافة قيد / إيقاف'))),
      const SizedBox(height:8),
      Text(silsilaText('يتم حفظ إعداد القيد في قاعدة البيانات. يلزم ربط قواعد حفظ وترحيل الفواتير بهذا الإعداد حتى يمنع البيع أو الشراء فعليًا على مستوى الخادم.'),style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _journalApprovalScreen() {
    const journals=[('JV-301','قيد مشتريات','2026-10-08','18,000','غير متوازن'),('JV-302','قيد مبيعات','2026-10-09','7,600','بانتظار الاعتماد'),('JV-303','قيد خزينة','2026-10-10','2,200','بانتظار الاعتماد')];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قائمة اعتماد القيود','مراجعة القيود قبل اعتمادها أو إعادتها للتعديل أو تسجيل طلب عكس'),
      Text(silsilaText('القيود أدناه أمثلة للواجهة فقط، ولا تمثل قيودًا محفوظة في دفتر الأستاذ.'),style:TextStyle(color:Colors.black54)),
      const SizedBox(height:10),
      ...journals.map((j)=>Card(child:ListTile(title:Text('${j.$1} • ${j.$2}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${j.$3} • ${j.$4} ج.م • ${j.$5}'),trailing:Wrap(spacing:3,children:[IconButton(tooltip:'اعتماد',onPressed:()=>setState(()=>_approvedJournals.add(j.$1)),icon:const Icon(Icons.check_circle_outline,color:Color(0xFF18865A))),IconButton(tooltip:'إعادة للتعديل',onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم تسجيل طلب إعادة ${j.$1} للمراجعة محليًا.'))),icon:const Icon(Icons.edit_outlined,color:_orange)),IconButton(tooltip:'طلب عكس',onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم تسجيل طلب عكس ${j.$1} محليًا؛ لم يُعكس القيد.'))),icon:const Icon(Icons.undo,color:_pink))]),leading:Icon(_approvedJournals.contains(j.$1)?Icons.verified:Icons.pending_actions,color:_approvedJournals.contains(j.$1)?const Color(0xFF18865A):_orange)))),
      const SizedBox(height:8),
      Text(silsilaText('زر الاعتماد في هذه المرحلة يسجل اختيارًا داخل الجلسة فقط؛ الترحيل المالي الحقيقي يتطلب التحقق من توازن القيد وصلاحية المستخدم وحالة الفترة المالية.'),style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _screenHeading(String title,String subtitle)=>Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:Colors.black54,height:1.5))]));
  Widget _fieldBox(String label,TextEditingController controller)=>SizedBox(width:220,child:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

  Future<void> _openAboutLink(String value) async {
    final uri = Uri.parse(value);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط. تأكد من وجود التطبيق أو المتصفح المناسب.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
      );
    }
  }

  Widget _aboutIconButton({
    required String label,
    required IconData icon,
    required String url,
    Color color = _purple,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: IconButton(
      tooltip: label,
      onPressed: () => _openAboutLink(url),
      icon: Icon(icon, color: color, size: 25),
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        fixedSize: const Size(46, 46),
      ),
    ),
  );

  Future<void> _leaveCurrentUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل خروج'),
        content: const Text(
          'سيتم إنهاء جلسة المستخدم الحالي والعودة إلى شاشة الدخول. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Supabase.instance.client.auth.signOut();
      // ErpLoginGate listens to Supabase auth changes and displays the login
      // form again, allowing another user to sign in.
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنهاء جلسة الدخول: $error')),
      );
    }
  }

  Widget _about() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE7F2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(silsilaText('عن البرنامج'), style: const TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(silsilaText('تم إنشاء هذا البرنامج بواسطة شركة سلسلة للبرمجيات — أ. محمد عبد العاطي.'), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.7)),
            const Text('موبايل: 01121237271', style: TextStyle(height: 1.7)),
            const Text('البريد الإلكتروني: attymanatty@gmail.com', style: TextStyle(height: 1.7)),
            const SizedBox(height: 6),
            Text(silsilaText('خبرة في جوانب تجارة وتوزيع المواد الغذائية لمدة تقارب 20 عامًا، والمشاركة في تطوير كبرى التجار والشركات بنظام الفروع وإعادة هيكلتها وتطويرها في مختلف الأقسام.'), style: const TextStyle(height: 1.8)),
            const SizedBox(height: 8),
            Text(silsilaText('المنظومة مصممة للتوسع إلى إدارة مالية ومخزنية وتشغيلية موحدة متعددة الفروع.'), style: const TextStyle(color: _purple, height: 1.7)),
            const SizedBox(height: 20),
            const Divider(),
            const Text('تواصل معنا', style: TextStyle(color: _purple, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _aboutIconButton(label: 'اتصال أرضي', icon: Icons.call, url: 'tel:0222784248', color: const Color(0xFF176B3A)),
                  _aboutIconButton(label: 'اتصال موبايل', icon: Icons.phone_android, url: 'tel:01019617100', color: const Color(0xFF176B3A)),
                  _aboutIconButton(label: 'واتساب', icon: FontAwesomeIcons.whatsapp, url: 'https://wa.me/201019617100', color: const Color(0xFF128C7E)),
                  _aboutIconButton(label: 'رسالة SMS', icon: Icons.sms_outlined, url: 'sms:01019617100', color: const Color(0xFF176B3A)),
                  _aboutIconButton(label: 'تيك توك', icon: FontAwesomeIcons.tiktok, url: 'https://www.tiktok.com/search?q=Silsila', color: Colors.black87),
                  _aboutIconButton(label: 'فيسبوك', icon: FontAwesomeIcons.facebookF, url: 'https://www.facebook.com/search/top?q=Silsila', color: const Color(0xFF1877F2)),
                  _aboutIconButton(label: 'إنستجرام', icon: FontAwesomeIcons.instagram, url: 'https://www.instagram.com/explore/search/keyword/?q=Silsila', color: const Color(0xFFC13584)),
                  _aboutIconButton(label: 'لينكد إن', icon: FontAwesomeIcons.linkedinIn, url: 'https://www.linkedin.com/search/results/companies/?keywords=Silsila', color: const Color(0xFF0A66C2)),
                  _aboutIconButton(label: 'ماسنجر', icon: FontAwesomeIcons.facebookMessenger, url: 'https://www.messenger.com/', color: const Color(0xFF0866FF)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'اضغط على شعار التطبيق لفتح وسيلة التواصل المناسبة.',
              style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.5),
            ),
          ]),
        ),
      ),
    ]),
  );

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
