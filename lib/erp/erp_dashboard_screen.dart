import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'services/erp_screen_layout_profiles.dart';
import 'services/erp_print_support.dart';
import 'widgets/erp_center_toast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'widgets/erp_quick_task_button.dart';
import 'widgets/erp_screen_frame.dart';
import '../widgets/silsila_white_logo.dart';
import 'widgets/erp_keyboard_navigation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/hr_attendance_rules_screen.dart';
import 'screens/erp_app_assets_screen.dart';
import 'screens/erp_app_advertisements_screen.dart';
import 'screens/erp_program_policies_screen.dart';
import 'screens/erp_studio_published_designs_screen.dart';
import 'screens/erp_supplier_deferred_commissions_screen.dart';
import 'screens/erp_delegate_allocation_screen.dart';
import 'screens/erp_company_profile_screen.dart';
import 'screens/erp_report_center_screen.dart';
import 'screens/erp_company_branches_design_screen.dart';
import 'screens/erp_activity_branches_screen.dart';
import 'screens/erp_activity_customers_screen.dart';
import 'screens/erp_currencies_screen.dart';
import 'screens/erp_payment_methods_screen.dart';
import 'screens/erp_image_collector_screen.dart';
import 'screens/erp_item_data_import_download_screen.dart';
import 'screens/erp_user_admin_screen.dart';
import 'screens/erp_shipping_companies_screen.dart';
import 'screens/erp_geographic_data_screen.dart';
import 'screens/erp_item_units_screen.dart';
import 'screens/erp_cost_centers_screen.dart';
import 'screens/erp_accounts_screen.dart';
import 'screens/erp_journal_entries_screen.dart';
import 'screens/erp_ledger_reports_screen.dart';
import 'screens/erp_movement_audit_screen.dart';
import 'screens/erp_inventory_screen.dart';
import 'screens/erp_stocktake_screen.dart';
import 'screens/erp_hr_operations_screen.dart';
import 'screens/erp_hr_affairs_screen.dart';
import 'screens/erp_business_suite_screen.dart';
import 'screens/erp_hr_executive_dashboard_screen.dart';
import 'screens/erp_hr_leave_screen.dart';
import 'screens/erp_employee_master_screen.dart';
import 'screens/erp_hr_structure_screen.dart';
import 'screens/erp_operational_documents_screen.dart';
import 'screens/erp_sales_fulfillment_screen.dart';
import 'screens/erp_cash_vouchers_screen.dart';
import 'screens/erp_financial_operations_screen.dart';
import 'screens/erp_payroll_screen.dart';
import 'screens/erp_salary_elements_screen.dart';
import 'screens/erp_fiscal_periods_screen.dart';
import 'screens/erp_parties_screen.dart';
import 'screens/erp_customer_credit_screen.dart';
import 'screens/erp_inventory_master_screen.dart';
import 'screens/erp_item_categories_screen.dart';
import 'screens/erp_studio_screen.dart';
import 'screens/erp_cashboxes_screen.dart';
import 'screens/erp_price_lists_screen.dart';
import 'screens/erp_sales_targets_commissions_screen.dart';
import 'screens/erp_item_offers_screen.dart';
import 'screens/erp_customer_shortages_screen.dart';
import 'screens/erp_whatsapp_contacts_screen.dart';
import 'screens/erp_public_leads_screen.dart';
import 'screens/erp_facebook_group_leads_screen.dart';
import 'screens/erp_einvoice_screen.dart';
import 'screens/erp_operational_account_mappings_screen.dart';
import 'screens/erp_activity_types_screen.dart';
import 'screens/erp_activity_data_screen.dart';
import 'screens/erp_api_management_screen.dart';
import 'screens/erp_activity_log_screen.dart';
import 'screens/erp_clear_data_screen.dart';
import 'screens/erp_business_workspace_screen.dart';
import 'services/erp_operational_documents_repository.dart';
import 'services/erp_workspace_records_service.dart';
import 'services/erp_app_management_service.dart';
import 'services/erp_app_settings.dart';
import 'services/erp_app_permission_catalog.dart';
import 'services/erp_menu_catalog.dart';
import 'services/erp_company_settings_repository.dart';
import '../services/app_language.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _pink = Color(0xFFFF27C3);
const _canvas = Color(0xFFF5EFFB);

final _modules = ErpMenuCatalog.modules;

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
  bool _showAllSalesPerformance = false;
  bool _showAllPurchasePerformance = false;
  List<Map<String, dynamic>> _executiveSalesReps = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _executiveSalesDocuments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _executivePurchaseEmployees = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _executivePurchaseDocuments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _executiveEmployeeTargets = <Map<String, dynamic>>[];
  String _executivePeriod = 'السنة الحالية';
  double? _executivePreviousSales;
  double? _executivePreviousPurchases;
  double? _executivePreviousGrossProfit;
  String? _executiveMetricsError;
  double? _executiveSales;
  double? _executiveGrossSales;
  double? _executiveSalesReturns;
  double? _executiveGrossPurchases;
  double? _executivePurchaseReturns;
  double? _executiveGrossProfit;
  double? _executiveCollections;
  double? _executiveReceivables;
  double? _executivePurchases;
  double? _executiveInventoryValue;
  double? _executiveExpenses;
  double? _executivePreviousExpenses;
  double? _executiveFixedAssetsGross;
  double? _executiveFixedAssetsDepreciation;
  double? _executiveFixedAssetsNet;
  double? _executiveCashInflows;
  double? _executiveCashOutflows;
  double? _executiveCashNetFlow;
  double? _executiveAverageInvoice;
  double? _executiveSalesReturnRate;
  double? _executiveAttendanceRate;
  double? _executivePayrollNetTotal;
  int? _executiveInvoiceCount;
  int? _executiveReorderItemCount;
  int? _executiveExpiryBatchCount;
  int? _executiveExpiredBatchCount;
  int? _executiveExpiryNext60BatchCount;
  int? _executiveSlowMovingItemCount;
  int? _executiveFulfillmentPendingCount;
  int? _executivePendingApprovalCount;
  int? _executiveSupplierOverdueDocuments;
  int? _executiveCreditLimitExceededCount;
  int? _executiveFulfillmentCancelledCount;
  double? _executiveSupplierPayables;
  double? _executiveInventoryTurnoverRate;
  double? _executiveDataCompletenessRate;
  List<Map<String, dynamic>> _executiveBranchSales = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _executiveTopProfitableItems = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _executiveCategorySales = <Map<String, dynamic>>[];
  List<String> _executiveTopCustomers = <String>[];
  List<String> _executiveTopItems = <String>[];
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
  int _pendingStocktakeDrafts = 0;
  bool _stocktakeAlertsLoading = false;
  bool _notificationsPanelVisible = true;
  bool _activityPanelVisible = true;
  bool _quickAccessPanelVisible = true;
  String _hrStructureView = 'tree';
  bool _mainSidebarVisible = true;
  bool _utilitySidebarVisible = true;
  bool _executiveAccessChecked = false;
  bool _executiveSummaryAllowed = false;
  bool _hrDashboardAccessChecked = false;
  bool _hrDashboardAllowed = false;
  bool _hrDashboardCanManage = false;
  bool _hrDashboardCanApproveStaffingPlans = false;
  bool _executivePartialConfigured = false;
  final Set<String> _executiveAllowedSections = <String>{};
  final Set<String> _quickAccessKeys = <String>{};
  final Map<String, bool> _screenAccessPermissions = <String, bool>{};
  final Map<String, bool> _screenActionPermissions = <String, bool>{};
  bool _isSystemAdmin = false;
  static const Map<String, String> _executivePermissionSectionKeys = {
    'مبيعات': 'مؤشرات المبيعات والعملاء',
    'المالية والسيولة': 'مؤشرات المالية والسيولة',
    'المخزون والمشتريات': 'مؤشرات المخزون والمشتريات',
    'الطلبات والتوزيع': 'مؤشرات الطلبات والتوزيع',
    'الموظفون والفروع': 'مؤشرات الموظفين والفروع',
    'الرقابة والتنبيهات': 'مؤشرات الرقابة والتنبيهات',
  };
  String _module = 'إعدادات عامة';
  String _selectedAppKey = 'silsila';
  String _appName = 'سلسلة';
  Color _appPrimary = const Color(0xFF3E007D);
  Color _appAccent = const Color(0xFFFFA015);
  final Map<String, Map<String, Object>> _managedAppDrafts = {
    'silsila': {'name': 'سلسلة', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
    'app_2': {'name': 'تطبيق رقم 2', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
    'app_3': {'name': 'تطبيق رقم 3', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
  };

  bool _isDatabaseReport(String page) => const <String>{
    'تقرير المستخدمين', 'تقرير نشاط النظام', 'تقرير استهلاك API', 'تقرير أخطاء التكامل',
    'تقرير التطبيقات', 'تقرير الصلاحيات', 'تقرير تغييرات الإعدادات',
    'قائمة الدخل', 'الميزانية العمومية', 'أرصدة الخزائن', 'كشف حساب خزينة',
    'كشف حساب بنك', 'مؤشرات الأداء الرئيسية', 'التدفقات النقدية', 'تحليل الربحية',
    'أداء الفروع', 'أرباح وخسائر الفروع', 'حركة التحويلات',
    'الأصناف الراكدة', 'الأصناف قاربت على النفاد', 'تنبيهات إعادة الطلب',
    'تواريخ الصلاحية', 'تنبيهات قرب انتهاء الصلاحية', 'أرصدة التشغيلات',
    'تحليل المشتريات', 'مقارنة أسعار الموردين', 'أعمار ديون الموردين',
    'أرصدة الموردين', 'أداء الموردين', 'الموردون حسب النشاط',
    'المبيعات اليومية', 'ربحية المبيعات', 'مبيعات حسب الفرع', 'أداء المندوبين',
    'الطلبات المتأخرة', 'أرصدة العملاء', 'أعمار الديون', 'أفضل العملاء',
    'العملاء المتوقفون', 'تحصيلات يومية', 'تصفية المندوبين', 'تكلفة خطوط السير',
    'تحقيق أهداف العملاء', 'تقرير العمولات المستحقة',
    'كشف العاملين', 'الحضور والغياب', 'رصيد الإجازات', 'انتهاء العقود',
    'ملخص الرواتب', 'مفردات المرتب', 'شريط قبض موظف', 'شريط قبض مجمع', 'عمولات المندوبين',
    'أداء العروض', 'تكلفة الحملات', 'معدل الاستجابة', 'التذاكر المفتوحة',
    'زمن الاستجابة', 'رضا العملاء',
  }.contains(page);

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
    unawaited(ErpScreenLayoutProfiles.load().catchError((Object _) {}));
    if (widget.initialPage == 'بيانات الشركة') {
      _module = 'إعدادات عامة';
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
          _isSystemAdmin = false;
          _executiveAccessChecked = true;
          _executiveSummaryAllowed = false;
          _hrDashboardAccessChecked = true;
          _hrDashboardAllowed = false;
          _screenAccessPermissions.clear();
          _screenActionPermissions.clear();
          _quickAccessKeys.clear();
          _ensureCurrentScreenAllowed();
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
      // Load authorization before requesting executive figures. A user without
      // access must not fetch or render data from the executive dashboard.
      await Future.wait<void>([
        _loadSelectedManagedAppTheme(),
        _loadPermissionsForSelectedApp(),
        _loadSavedAppActivity(),
        _loadWorkspaceSettings(companyId),
        _loadExecutivePermissions(companyId),
      ]);
      if (_executiveSummaryAllowed) {
        await _loadExecutiveMetrics(companyId);
      }
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
      if (mounted) setState(() {
        _hrDashboardAccessChecked = true;
        _hrDashboardAllowed = false;
        _isSystemAdmin = false;
        _screenActionPermissions.clear();
        _hrDashboardCanManage = false;
        _hrDashboardCanApproveStaffingPlans = false;
        _executiveAccessChecked = true;
        _executiveSummaryAllowed = false;
        _executivePartialConfigured = false;
        _isSystemAdmin = false;
        _screenAccessPermissions.clear();
        _screenActionPermissions.clear();
        _quickAccessKeys.clear();
        _executiveAllowedSections.clear();
        _ensureCurrentScreenAllowed();
      });
      return;
    }
    try {
      final db = Supabase.instance.client;
      String jobTitle = '';
      String memberRole = '';
      bool isActiveCompanyMember = false;
      try {
        final profile = await db.from('erp_company_member_profiles')
            .select('job_title')
            .eq('company_id', companyId)
            .eq('user_id', userId)
            .maybeSingle();
        jobTitle = (profile?['job_title'] ?? '').toString().trim();
      } catch (_) {}
      try {
        final member = await db.from('erp_company_members')
            .select('member_role')
            .eq('company_id', companyId)
            .eq('user_id', userId)
            .eq('is_active', true)
            .maybeSingle();
        isActiveCompanyMember = member != null;
        memberRole = (member?['member_role'] ?? '').toString().trim().toLowerCase();
      } catch (_) {}
      final permissions = <String, bool>{};
      final quickAccess = <String>{};
      final actionPermissions = <String, bool>{};
      const legacyActionFields = <String, String>{
        'إضافة': 'can_add', 'حفظ': 'can_save', 'تعديل': 'can_edit',
        'حذف': 'can_delete', 'طباعة': 'can_print',
        'تصدير Excel': 'can_export_excel', 'طباعة PDF': 'can_export_pdf',
      };
      const matrixActionFields = <String, String>{
        'تحديث': 'can_refresh', 'إضافة': 'can_add', 'حفظ': 'can_save',
        'تعديل': 'can_edit', 'حذف': 'can_delete', 'معاينة': 'can_preview',
        'طباعة': 'can_print', 'استيراد Excel': 'can_import_excel',
        'تصدير Excel': 'can_export_excel', 'طباعة PDF': 'can_print_pdf',
      };
      try {
        final rows = await db.from('erp_user_permissions')
            .select('menu_key,allow_access,show_in_quick_tasks,can_add,can_save,can_edit,can_delete,can_print,can_export_excel,can_export_pdf')
            .eq('company_id', companyId).eq('user_id', userId);
        for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
          final key = (row['menu_key'] ?? '').toString();
          permissions[key] = row['allow_access'] == true;
          if (row['allow_access'] == true && row['show_in_quick_tasks'] == true) quickAccess.add(key);
          for (final action in legacyActionFields.entries) {
            actionPermissions[key + '::' + action.key] = row[action.value] == true;
          }
        }
      } catch (_) {
        // Continue with the canonical matrix on installations without the legacy table.
      }
      // The user administration screen stores its canonical matrix against the
      // ERP user record (linked to the authenticated account by auth_user_id).
      String erpUserTypeName = '';
      try {
        final erpUser = await db.from('erp_users')
            .select('id,user_type_id')
            .eq('company_id', companyId)
            .eq('auth_user_id', userId)
            .eq('is_active', true)
            .maybeSingle();
        final erpUserId = erpUser?['id']?.toString();
        final userTypeId = erpUser?['user_type_id']?.toString();
        if (userTypeId != null && userTypeId.isNotEmpty) {
          try {
            final userType = await db.from('erp_user_types')
                .select('name_ar,name_en')
                .eq('company_id', companyId)
                .eq('id', userTypeId)
                .maybeSingle();
            erpUserTypeName = '${userType?['name_ar'] ?? ''} ${userType?['name_en'] ?? ''}'.trim().toLowerCase();
          } catch (_) {}
        }
        if (erpUserId != null && erpUserId.isNotEmpty) {
          final matrix = await db.from('erp_user_permission_matrix')
              .select('menu_name,submenu_name,page_name,can_access,can_refresh,can_add,can_save,can_edit,can_delete,can_preview,can_print,can_import_excel,can_export_excel,can_print_pdf,show_in_quick_tasks')
              .eq('company_id', companyId)
              .eq('user_id', erpUserId);
          for (final row in (matrix as List).whereType<Map<String, dynamic>>()) {
            final key = '${row['menu_name']}::${row['submenu_name']}::${row['page_name']}';
            permissions[key] = row['can_access'] == true;
            if (row['can_access'] == true && row['show_in_quick_tasks'] == true) {
              quickAccess.add(key);
            } else {
              quickAccess.remove(key);
            }
            for (final action in matrixActionFields.entries) {
              actionPermissions[key + '::' + action.key] = row[action.value] == true;
            }
          }
        }
      } catch (_) {
        // Older installations may only have the legacy permission table.
      }
      // Quick access is personal navigation state, not a permission flag.
      // Read it from its own RLS-protected table so every authenticated
      // company member can retain favorites without changing their permissions.
      try {
        final savedQuickAccess = await db.from('erp_user_quick_access')
            .select('menu_key')
            .eq('company_id', companyId)
            .eq('user_id', userId);
        quickAccess
          ..clear()
          ..addAll((savedQuickAccess as List)
              .whereType<Map<String, dynamic>>()
              .map((row) => (row['menu_key'] ?? '').toString())
              .where((key) => key.isNotEmpty));
      } catch (_) {
        // Keep legacy permission-backed favorites available on older installs.
      }
      const hrDashboardKey = 'موارد بشرية::بيانات أساسية::ملخص إدارة موارد بشرية';
      final isHrManager = isActiveCompanyMember && jobTitle == 'مدير موارد بشرية';
      final isHrResponsible = jobTitle == 'مسئول موارد بشرية' || jobTitle == 'مسؤول موارد بشرية';
      final normalizedMemberRole = memberRole.replaceAll(RegExp(r'[\s_-]+'), '');
      final normalizedJobTitle = jobTitle.replaceAll(RegExp(r'[\s_-]+'), '');
      final normalizedUserTypes = erpUserTypeName
          .split(RegExp(r'\s+'))
          .map((value) => value.replaceAll(RegExp(r'[\s_-]+'), ''))
          .where((value) => value.isNotEmpty)
          .toSet();
      final isCompanyAdmin = isActiveCompanyMember && (
        <String>{
          'owner', 'admin', 'administrator', 'systemadmin', 'superadmin',
          'مديرالنظام', 'مديرالنظامالرئيسي', 'ادمن', 'أدمن', 'مسؤولالنظام',
        }.contains(normalizedMemberRole) ||
        normalizedUserTypes.any((value) => <String>{
          'admin', 'administrator', 'systemadmin', 'superadmin', 'ادمن', 'أدمن',
          'مديرالنظام', 'مديرالنظامالرئيسي',
        }.contains(value)) ||
        <String>{'مديرالنظام', 'مديرالنظامالرئيسي'}.contains(normalizedJobTitle)
      );
      if (isCompanyAdmin) {
        for (final module in _modules.entries) {
          for (final group in module.value.entries) {
            for (final page in group.value) {
              permissions[module.key + '::' + group.key + '::' + page] = true;
            }
          }
        }
      }
      final hrDashboardAllowed = isActiveCompanyMember && !isHrResponsible &&
          (isHrManager || isCompanyAdmin || permissions[hrDashboardKey] == true);
      const executiveKey = 'إعدادات عامة::بيانات أساسية::الملخص التنفيذي';
      final executiveSummaryAllowed = isCompanyAdmin || permissions[executiveKey] == true;
      final childKeys = _executivePermissionSectionKeys.values
          .map((label) => 'التقارير والتحليلات::تقارير::$label')
          .toList();
      final configuredChildren = childKeys.where(permissions.containsKey).toList();
      if (!mounted) return;
      setState(() {
        _hrDashboardAccessChecked = true;
        _isSystemAdmin = isCompanyAdmin;
        _hrDashboardAllowed = isCompanyAdmin || hrDashboardAllowed;
        _hrDashboardCanManage = isHrManager || isCompanyAdmin;
        _hrDashboardCanApproveStaffingPlans = isCompanyAdmin;
        _screenAccessPermissions
          ..clear()
          ..addAll(permissions);
        _screenActionPermissions
          ..clear()
          ..addAll(actionPermissions);
        _quickAccessKeys
          ..clear()
          ..addAll(quickAccess);
        _executiveAccessChecked = true;
        _executiveSummaryAllowed = executiveSummaryAllowed;
        _executivePartialConfigured = configuredChildren.isNotEmpty;
        _executiveAllowedSections
          ..clear()
          ..addAll(_executivePermissionSectionKeys.entries
              .where((entry) => permissions['التقارير والتحليلات::تقارير::${entry.value}'] == true)
              .map((entry) => entry.key));
        if (!_executivePartialConfigured) {
          _executiveAllowedSections.addAll(_executivePermissionSectionKeys.keys);
        }
        _ensureCurrentScreenAllowed();
      });
    } catch (_) {
      // Keep the summary usable until the permissions schema is installed.
      if (mounted) setState(() {
        _hrDashboardAccessChecked = true;
        _hrDashboardAllowed = false;
        _hrDashboardCanManage = false;
        _hrDashboardCanApproveStaffingPlans = false;
        _executiveAccessChecked = true;
        _executiveSummaryAllowed = false;
        _executivePartialConfigured = false;
        _executiveAllowedSections..clear()..addAll(_executivePermissionSectionKeys.keys);
        _screenAccessPermissions.clear();
        _screenActionPermissions.clear();
        _quickAccessKeys.clear();
        _ensureCurrentScreenAllowed();
      });
    }
  }

  String _screenPermissionKey(String module, String group, String page) => '$module::$group::$page';

  bool _canOpenScreen(String module, String group, String page) {
    if (_isSystemAdmin) return true;
    if (page == 'ملخص إدارة موارد بشرية') return _hrDashboardAccessChecked && _hrDashboardAllowed;
    return _screenAccessPermissions[_screenPermissionKey(module, group, page)] == true;
  }

  void _ensureCurrentScreenAllowed() {
    if (_isSystemAdmin || _canOpenScreen(_module, _group, _page)) return;
    for (final module in _modules.entries) {
      for (final group in module.value.entries) {
        for (final page in group.value) {
          if (_canOpenScreen(module.key, group.key, page)) {
            _module = module.key;
            _group = group.key;
            _page = page;
            _search = '';
            _selectedRecord = null;
            return;
          }
        }
      }
    }
    _page = 'عن البرنامج';
    _search = '';
    _selectedRecord = null;
  }

  bool _canPerformCurrentAction(String action) {
    if (_isSystemAdmin) return true;
    final key = _screenPermissionKey(_module, _group, _page) + '::' + action;
    return _screenActionPermissions[key] == true;
  }

  bool _canPerformActionLabel(String label) {
    if (_isSystemAdmin) return true;
    final value = label.trim().toLowerCase();
    String? action;
    if (value.contains('استيراد')) {
      action = 'استيراد Excel';
    } else if (value.contains('تصدير') || value.contains('excel')) {
      action = 'تصدير Excel';
    } else if (value.contains('pdf')) {
      action = 'طباعة PDF';
    } else if (value.contains('معاينة')) {
      action = 'معاينة';
    } else if (value.contains('طباعة') || value.contains('print')) {
      action = 'طباعة';
    } else if (value.contains('تحديث') || value.contains('تحميل')) {
      action = 'تحديث';
    } else if (value.contains('إضافة')) {
      action = 'إضافة';
    } else if (value.contains('حفظ')) {
      action = 'حفظ';
    } else if (value.contains('تعديل')) {
      action = 'تعديل';
    } else if (value.contains('حذف')) {
      action = 'حذف';
    }
    return action == null || _canPerformCurrentAction(action);
  }

  Future<void> _toggleQuickAccess(String module, String group, String page) async {
    final companyId = _appManagementCompanyId;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final key = _screenPermissionKey(module, group, page);
    if (companyId == null || userId == null || !_canOpenScreen(module, group, page)) return;
    final add = !_quickAccessKeys.contains(key);
    setState(() {
      if (add) { _quickAccessKeys.add(key); } else { _quickAccessKeys.remove(key); }
    });
    try {
      final db = Supabase.instance.client;
      if (add) {
        final saved = await db.from('erp_user_quick_access').upsert({
          'company_id': companyId,
          'user_id': userId,
          'menu_key': key,
          'menu_name': module,
          'submenu_name': group,
          'page_name': page,
        }, onConflict: 'company_id,user_id,menu_key')
            .select('menu_key')
            .maybeSingle();
        if (saved == null || saved['menu_key'] != key) {
          throw StateError('لم يتم تأكيد حفظ الشاشة في الوصول السريع.');
        }
      } else {
        await db.from('erp_user_quick_access')
            .delete()
            .eq('company_id', companyId)
            .eq('user_id', userId)
            .eq('menu_key', key);
        final remaining = await db.from('erp_user_quick_access')
            .select('menu_key')
            .eq('company_id', companyId)
            .eq('user_id', userId)
            .eq('menu_key', key)
            .maybeSingle();
        if (remaining != null) {
          throw StateError('تعذر إزالة الشاشة من الوصول السريع.');
        }
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (add) { _quickAccessKeys.remove(key); } else { _quickAccessKeys.add(key); }
      });
      _showActionMessage('تعذر تحديث الوصول السريع: $error');
    }
  }

  Widget _quickAccessScreenButton(String module, String group, String page) {
    final key = _screenPermissionKey(module, group, page);
    final allowed = _canOpenScreen(module, group, page);
    final selected = _quickAccessKeys.contains(key);
    return IconButton(
      tooltip: !allowed ? 'الشاشة غير متاحة ضمن صلاحيات المستخدم' : selected ? 'إزالة من الوصول السريع' : 'إضافة إلى الوصول السريع',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      onPressed: allowed ? () => _toggleQuickAccess(module, group, page) : null,
      icon: Icon(selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 17, color: selected ? Colors.red : (allowed ? _purple : Colors.black26)),
    );
  }

  List<Widget> _quickAccessScreenTiles() {
    final tiles = <Widget>[];
    for (final module in _modules.entries) {
      for (final group in module.value.entries) {
        for (final page in group.value) {
          final key = _screenPermissionKey(module.key, group.key, page);
          if (!_quickAccessKeys.contains(key) || !_canOpenScreen(module.key, group.key, page)) continue;
          tiles.add(_quick(page, Icons.favorite_rounded, () => _open(module.key, group.key, page)));
        }
      }
    }
    return tiles;
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
        ErpCenterToast.show(context, successMessage);
      }
      return true;
    } catch (error) {
      if (mounted) {
        ErpCenterToast.show(context, 'فشل حفظ الإعدادات: $error', isError: true);
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
    ErpCenterToast.show(context, message);
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
  String _group = 'بيانات أساسية';
  String _page = 'الملخص التنفيذي';
  String _search = '';
  Map<String, String>? _selectedRecord;
  final Map<String, List<Map<String, String>>> _saved = {};
  final Set<String> _cloudLoadedWorkspacePages = <String>{};
  final Set<String> _workspacePageLoadsInProgress = <String>{};
  final Map<String, int> _workspaceOffsets = <String, int>{};
  final Map<String, bool> _workspaceHasMore = <String, bool>{};

  List<Map<String, String>> get _rows {
    final source = _saved[_page] ?? <Map<String, String>>[];
    final query = _search.trim().toLowerCase();
    final rows = query.isEmpty
        ? List<Map<String, String>>.from(source)
        : source.where((row) => row.values.any((value) => value.toLowerCase().contains(query))).toList();
    String codeOf(Map<String, String> row) {
      const preferred = ['الكود', 'كود الهيكل', 'كود المجموعة', 'كود البراند', 'كود الصنف', 'كود العميل', 'كود المورد', 'رقم المستند', 'الرقم', 'code', 'document_code'];
      for (final key in preferred) {
        final value = row[key]?.trim() ?? '';
        if (value.isNotEmpty) return value.toUpperCase();
      }
      for (final entry in row.entries) {
        final key = entry.key.toLowerCase();
        if (key.contains('كود') || key.contains('code')) {
          final value = entry.value.trim();
          if (value.isNotEmpty) return value.toUpperCase();
        }
      }
      return '';
    }
    rows.sort((a, b) {
      final aCode = codeOf(a);
      final bCode = codeOf(b);
      if (aCode.isEmpty) return bCode.isEmpty ? 0 : 1;
      if (bCode.isEmpty) return -1;
      return aCode.compareTo(bCode);
    });
    return rows;
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

  String _workspaceCodePrefix() {
    final page = _page;
    if (page.contains('مورد') || page.contains('شراء')) return 'SUP';
    if (page.contains('عميل') || page.contains('بيع')) return 'CUS';
    if (page.contains('موظف') || page.contains('مرتبات') || page.contains('رواتب')) return 'EMP';
    if (page.contains('وظائف')) return 'JOB';
    if (page.contains('إدارات') || page.contains('أقسام')) return 'DEP';
    if (page.contains('نشاط')) return 'ACT';
    if (page.contains('فرع')) return 'BRN';
    if (page.contains('مخزن')) return 'WH';
    if (page.contains('صنف') || page.contains('باركود')) return 'ITM';
    if (page.contains('وحدات')) return 'UNT';
    if (page.contains('حساب')) return 'ACC';
    if (page.contains('خزائن') || page.contains('خزينة')) return 'CSH';
    if (page.contains('حملة') || page.contains('عرض')) return 'MKT';
    if (page.contains('إجاز')) return 'LEV';
    if (page.contains('سياس')) return 'POL';
    return 'GEN';
  }

  String _nextWorkspaceCode() {
    final prefix = _workspaceCodePrefix();
    var maxNumber = 0;
    final rows = _saved[_page] ?? const <Map<String, String>>[];
    for (final row in rows) {
      for (final key in const ['الكود', 'كود الهيكل', 'رقم المستند', 'الرقم']) {
        final value = (row[key] ?? '').trim().toUpperCase();
        final match = RegExp('^' + prefix + r'(\d+)$').firstMatch(value);
        final number = int.tryParse(match?.group(1) ?? '');
        if (number != null && number > maxNumber) maxNumber = number;
      }
    }
    return prefix + (maxNumber + 1).toString().padLeft(4, '0');
  }

  void _openAddDialog() {
    final isOrgChart = _page == 'الهيكل الوظيفي';
    final code = TextEditingController(text: _nextWorkspaceCode());
    final name = TextEditingController();
    final nameEn = TextEditingController();
    final details = TextEditingController();
    final parent = TextEditingController();
    final level = TextEditingController();
    var isActive = true;
    var showInApp = true;
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('إضافة سجل — ' + _page),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, readOnly: true, decoration: InputDecoration(labelText: isOrgChart ? 'كود الهيكل' : 'الكود التلقائي', helperText: 'تكويد سلسلة القياسي • بادئة إنجليزية وأرقام')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: InputDecoration(labelText: isOrgChart ? 'المسمى الوظيفي بالعربية' : 'الاسم بالعربية')),
          const SizedBox(height: 12),
          TextField(controller: nameEn, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Name in English')),
          const SizedBox(height: 12),
          TextField(controller: details, maxLines: isOrgChart ? 1 : 3, decoration: InputDecoration(labelText: isOrgChart ? 'الإدارة / القسم' : 'الوصف أو ملاحظات')),
          if (isOrgChart) ...[
            const SizedBox(height: 12),
            TextField(controller: parent, decoration: const InputDecoration(labelText: 'يتبع إلى')),
            const SizedBox(height: 12),
            TextField(controller: level, decoration: const InputDecoration(labelText: 'المستوى الإداري')),
          ],
          const Divider(height: 22),
          CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: isActive, title: const Text('نشط'), onChanged: (value) => setDialogState(() => isActive = value ?? false)),
          CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: showInApp, title: const Text('عرض في التطبيق'), subtitle: const Text('ألغِ الاختيار للسجلات الداخلية التي لا تظهر للعملاء أو الموردين'), onChanged: (value) => setDialogState(() => showInApp = value ?? false)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(silsilaText('إلغاء'))),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) {
              _showActionMessage('أدخل الاسم العربي قبل الحفظ.');
              return;
            }
            final rows = List<Map<String, String>>.from(_saved[_page] ?? <Map<String, String>>[]);
            final generatedCode = code.text.trim();
            final Map<String, String> row = isOrgChart
                ? {'م': (rows.length + 1).toString(), 'كود الهيكل': generatedCode, 'المسمى الوظيفي': name.text.trim(), 'اسم إنجليزي': nameEn.text.trim(), 'الإدارة / القسم': details.text.trim(), 'يتبع إلى': parent.text.trim().isEmpty ? '—' : parent.text.trim(), 'المستوى الإداري': level.text.trim().isEmpty ? 'غير محدد' : level.text.trim(), 'الحالة': isActive ? 'نشط' : 'غير نشط', 'عرض في التطبيق': showInApp ? 'نعم' : 'لا'}
                : {'الكود': generatedCode, 'الاسم': name.text.trim(), 'اسم إنجليزي': nameEn.text.trim(), 'الوصف': details.text.trim(), 'الحالة': isActive ? 'نشط' : 'غير نشط', 'عرض في التطبيق': showInApp ? 'نعم' : 'لا'};
            rows.insert(0, row);
            final newRecord = Map<String, String>.from(rows.first);
            newRecord['_مرجع داخلي'] = isOrgChart ? (newRecord['كود الهيكل'] ?? generatedCode) : (newRecord['الكود'] ?? newRecord['الاسم'] ?? newRecord.values.first);
            rows[0] = newRecord;
            setState(() {
              _saved[_page] = rows;
              _selectedRecord = newRecord;
              _activityLog.insert(0, 'تمت إضافة سجل جديد في شاشة ' + _page);
            });
            Navigator.pop(dialogContext);
            final companyId = _appManagementCompanyId;
            if (companyId == null || companyId.trim().isEmpty) {
              _showActionMessage('تمت الإضافة محليًا فقط. سجّل الدخول واربط المستخدم بشركة نشطة لتفعيل الحفظ الدائم.');
            } else {
              try {
                await _workspaceRecordsService.saveRecord(companyId: companyId, pageKey: _page, record: newRecord);
                try {
                  await _appManagementService.requestActivityLog(
                    companyId: companyId,
                    action: 'create',
                    entityType: 'workspace_record',
                    entityId: generatedCode,
                    details: <String, Object?>{
                      'page': _page,
                      'record_name': newRecord['الاسم'] ?? '',
                    },
                  );
                } catch (logError) {
                  _showActionMessage('تم حفظ السجل، لكن تعذر تسجيل حدث المراجعة: $logError');
                  return;
                }
                _showActionMessage('تم حفظ السجل وتسجيل العملية في سجل المراجعة.');
              } catch (error) {
                _showActionMessage('تعذر الحفظ الدائم: ' + error.toString());
              }
            }
          }, child: Text(silsilaText('حفظ السجل'))),
        ],
      )),
    ).then((_) { code.dispose(); name.dispose(); nameEn.dispose(); details.dispose(); parent.dispose(); level.dispose(); });
  }

  void _showActionMessage(String message) {
    setState(() => _activityLog.insert(0, message));
    ErpCenterToast.show(context, message);
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
          ? 'لا توجد سجلات فعلية جديدة للحفظ.'
          : 'تم حفظ $savedCount سجلًا في قاعدة البيانات.');
    } catch (error) {
      if (!mounted) return;
      _showActionMessage('تعذر حفظ سجلات الشاشة: $error');
    }
  }

  void _editCurrentRecord() {
    final rows = List<Map<String, String>>.from(_saved[_page] ?? <Map<String, String>>[]);
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
        _showActionMessage('تم تعديل السجل محليًا؛ هذا السجل غير مرتبط بسجل محفوظ في قاعدة البيانات.');
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

  Future<bool> _confirmGridDeletion({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(silsilaText(title)),
        content: Text(message),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(silsilaText('نعم، احذف')),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(silsilaText('لا'))),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(silsilaText('إلغاء الأمر'))),
        ],
      ),
    );
    return result == true;
  }

  String _workspaceRecordLabel(Map<String, String> row) =>
      row['الكود'] ?? row['الاسم'] ?? row['اسم الحساب'] ?? row['رقم المستند'] ?? 'السجل';

  bool _isPersistedWorkspaceRecord(Map<String, String> row) {
    final label = _workspaceRecordLabel(row);
    return (row['_مرجع داخلي'] ?? '').trim().isNotEmpty &&
        !label.startsWith('DEMO-') && !label.contains('تجريبي') && !label.contains('توضيحي');
  }

  Future<void> _deleteWorkspaceRow(Map<String, String> selected) async {
    if (!_isPersistedWorkspaceRecord(selected)) {
      _showActionMessage('هذا الصف غير مرتبط بسجل دائم في قاعدة البيانات؛ لم يتم حذفه.');
      return;
    }
    final label = _workspaceRecordLabel(selected);
    final approved = await _confirmGridDeletion(
      title: 'تأكيد حذف الصف',
      message: 'هل ترغب في حذف «$label» من شاشة «$_page» فقط؟',
    );
    if (!approved || !mounted) return;
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.trim().isEmpty) {
      _showActionMessage('لا توجد شركة نشطة؛ تعذر تنفيذ الحذف الدائم.');
      return;
    }
    try {
      await _workspaceRecordsService.deleteRecord(
        companyId: companyId, pageKey: _page,
        recordKey: selected['_مرجع داخلي']!,
      );
      final rows = List<Map<String, String>>.from(_saved[_page] ?? <Map<String, String>>[]);
      rows.removeWhere((row) => _sameRecord(row, selected));
      setState(() {
        _saved[_page] = rows;
        if (_selectedRecord != null && _sameRecord(_selectedRecord!, selected)) _selectedRecord = null;
      });
      _showActionMessage('تم حذف الصف «$label» فقط.');
    } catch (error) {
      _showActionMessage('تعذر حذف الصف من قاعدة البيانات: $error');
    }
  }

  Future<void> _chooseWorkspaceDeleteScope() async {
    final scope = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(silsilaText('اختر نطاق الحذف')),
        content: Text('هل تريد حذف صف واحد أم جميع بيانات شاشة «$_page»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'row'), child: Text(silsilaText('حذف الصف المحدد'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
            onPressed: () => Navigator.pop(ctx, 'grid'),
            child: Text(silsilaText('حذف الجريد بالكامل')),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(silsilaText('إلغاء الأمر'))),
        ],
      ),
    );
    if (scope == 'row') {
      await _deleteCurrentRecord();
    } else if (scope == 'grid') {
      await _deleteEntireWorkspaceGrid();
    }
  }

  Future<void> _deleteCurrentRecord() async {
    final selected = _selectedRecord;
    if (selected == null) {
      _showActionMessage('اختر صفًا إذا أردت حذفه منفردًا، أو استخدم حذف الجريد بالكامل.');
      return;
    }
    await _deleteWorkspaceRow(selected);
  }

  Future<void> _deleteEntireWorkspaceGrid() async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.trim().isEmpty) {
      _showActionMessage('لا توجد شركة نشطة مرتبطة؛ تعذر حذف الجريد.');
      return;
    }
    while (_workspaceHasMore[_page] == true && mounted) {
      final previousOffset = _workspaceOffsets[_page] ?? 0;
      await _loadWorkspacePage(_page, loadMore: true);
      while (_workspacePageLoadsInProgress.contains(_page) && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if ((_workspaceOffsets[_page] ?? 0) <= previousOffset) {
        _showActionMessage('تعذر تحميل بقية السجلات؛ أوقفنا الحذف حتى لا نحذف جزءًا من الجريد فقط.');
        return;
      }
    }
    if (!mounted) return;
    final allRows = List<Map<String, String>>.from(_saved[_page] ?? <Map<String, String>>[]);
    if (allRows.isEmpty) {
      _showActionMessage('الجريد فارغ؛ لا توجد بيانات لحذفها.');
      return;
    }
    final invalid = allRows.where((row) => !_isPersistedWorkspaceRecord(row)).length;
    if (invalid > 0) {
      _showActionMessage('توقف الحذف الآمن: يوجد $invalid صف غير مرتبط بسجل دائم. لم يُحذف أي صف.');
      return;
    }
    final approved = await _confirmGridDeletion(
      title: 'تحذير: حذف الجريد بالكامل',
      message: 'هل ترغب في حذف جميع بيانات شاشة «$_page» بالكامل؟ عدد السجلات: ${allRows.length}. لن تتأثر شاشات أخرى، ولا يمكن التراجع عن الحذف.',
    );
    if (!approved || !mounted) return;
    try {
      for (final row in allRows) {
        await _workspaceRecordsService.deleteRecord(
          companyId: companyId, pageKey: _page,
          recordKey: row['_مرجع داخلي']!,
        );
      }
      if (!mounted) return;
      setState(() {
        _saved[_page] = <Map<String, String>>[];
        _workspaceOffsets[_page] = 0;
        _workspaceHasMore[_page] = false;
        _cloudLoadedWorkspacePages.add(_page);
        _selectedRecord = null;
      });
      _showActionMessage('تم حذف الجريد بالكامل (${allRows.length} سجلًا).');
    } catch (error) {
      await _loadWorkspacePage(_page);
      _showActionMessage('توقف حذف الجريد بسبب خطأ: $error. تم تحديث البيانات لعرض ما بقي.');
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
          final header = headers[i];
          if (header.isEmpty) continue;
          final value = row[i]?.value?.toString() ?? '';
          if (header == 'معرف الاستيراد' || header == '_مرجع داخلي') {
            if (value.trim().isNotEmpty) record['_مرجع داخلي'] = value.trim();
          } else {
            record[header] = value;
          }
        }
        if (record.entries.any((entry) => entry.key != '_مرجع داخلي' && entry.value.trim().isNotEmpty)) imported.add(record);
      }
      if (imported.isEmpty) {
        _showActionMessage('لم يتم العثور على سجلات بعد صف العناوين.');
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(silsilaText('تأكيد استيراد Excel')),
          content: Text('سيتم فحص ${imported.length} صفًا في شاشة «$_page». ستُحدّث السجلات التي تحمل معرف الاستيراد نفسه، وتُضاف السجلات الجديدة دون تكرار المعرفات. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(silsilaText('إلغاء'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(silsilaText('استيراد'))),
          ],
        ),
      );
      if (confirm != true) return;
      var savedCount = 0;
      var duplicateCount = 0;
      final seen = <String>{};
      final failedRows = <Map<String, String>>[];
      for (var index = 0; index < imported.length; index++) {
        final record = imported[index];
        final identity = (record['_مرجع داخلي'] ?? record['الكود'] ?? record['كود الصنف'] ?? record['كود العميل'] ?? record['كود المورد'] ?? record['رقم المستند'] ?? record['الاسم'] ?? record['اسم الحساب'] ?? record.values.where((v) => v.trim().isNotEmpty).join('|')).trim().toLowerCase();
        if (identity.isEmpty || !seen.add(identity)) {
          duplicateCount++;
          continue;
        }
        try {
          await _workspaceRecordsService.saveRecord(companyId: companyId, pageKey: _page, record: record);
          savedCount++;
        } catch (error) {
          failedRows.add({...record, 'سبب الفشل': error.toString(), 'رقم الصف في الملف': (index + 2).toString()});
        }
      }
      await _loadWorkspacePage(_page);
      if (failedRows.isNotEmpty) {
        await _saveWorkspaceExcelFile('silsila_failed_import_${DateTime.now().millisecondsSinceEpoch}', failedRows, sheetName: 'الصفوف الفاشلة');
      }
      if (mounted) {
        final pending = failedRows.length;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('نتيجة استيراد Excel'),
            content: Text('الشاشة: $_page\\nإجمالي الصفوف: ${imported.length}\\nتم الحفظ أو التحديث بنجاح: $savedCount\\nصفوف مكررة تم تجاوزها: $duplicateCount\\nفشل: $pending\\nالمتبقي للمراجعة: $pending${pending > 0 ? '\\nتم إنشاء ملف Excel مستقل بالصفوف الفاشلة على جهازك.' : ''}'),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
          ),
        );
      }
    } catch (error) {
      if (mounted) _showActionMessage('تعذر استيراد ملف Excel: $error');
    }
  }


  Future<void> _saveWorkspaceExcelFile(String fileName, List<Map<String, String>> rows, {String sheetName = 'بيانات الشاشة'}) async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook[sheetName];
    final columns = <String>[];
    for (final row in rows) {
      for (final key in row.keys) {
        if (!columns.contains(key)) columns.add(key);
      }
    }
    sheet.appendRow(columns.map((key) => excel.TextCellValue(key)).toList());
    for (final row in rows) {
      sheet.appendRow(columns.map((key) => excel.TextCellValue(row[key] ?? '')).toList());
    }
    final encoded = workbook.encode();
    if (encoded == null || encoded.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
    await FileSaver.instance.saveFile(name: fileName, bytes: Uint8List.fromList(encoded), fileExtension: 'xlsx', mimeType: MimeType.microsoftExcel);
  }

  Future<void> _exportExcel() async {
    final rows = _rows;
    if (rows.isEmpty) {
      _showActionMessage('لا توجد بيانات فعلية ظاهرة في شاشة «$_page» لتصديرها.');
      return;
    }
    try {
      final exportRows = rows.map((row) => <String, String>{
        for (final entry in row.entries.where((entry) => entry.key != '_مرجع داخلي')) entry.key: entry.value,
        'معرف الاستيراد': row['_مرجع داخلي'] ?? '',
      }).toList();
      await _saveWorkspaceExcelFile('silsila_${_page.replaceAll(RegExp(r'[^a-zA-Z0-9ء-ي]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}', exportRows);
      if (mounted) _showActionMessage('تم تصدير ${rows.length} سجلًا من شاشة «$_page». يحتوي الملف على معرف استيراد ثابت لإعادة التحديث دون تكرار.');
    } catch (error) {
      if (mounted) _showActionMessage('تعذر تصدير بيانات الشاشة إلى Excel: $error');
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
      document.addPage(pw.MultiPage(header: ErpPrintSupport.header, footer: ErpPrintSupport.footer, textDirection: pw.TextDirection.rtl, 
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
          ErpPrintSupport.text('Silsila • $_module • $_page', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: keys,
            data: ErpPrintSupport.normalizeTable(_rows.map((row) => keys.map((key) => row[key] ?? '').toList()).toList()),
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
        if (_page == 'الإدارات والأقسام') ...[
          _recordAction('عرض شجرة', Icons.account_tree_outlined, _hrStructureView == 'tree' ? _purple : Colors.blueGrey, () => setState(() => _hrStructureView = 'tree')),
          _recordAction('عرض جدول', Icons.table_rows_outlined, _hrStructureView == 'table' ? _purple : Colors.blueGrey, () => setState(() => _hrStructureView = 'table')),
        ],
        if (_canPerformCurrentAction('تحديث')) _recordAction('تحديث', Icons.refresh_rounded, const Color(0xFF2475B8), () => _loadWorkspacePage(_page)),
        if (!reports && includeAdd && _canPerformCurrentAction('إضافة')) _recordAction('إضافة', Icons.add_rounded, const Color(0xFF18865A), _openAddDialog),
        if (!reports && _canPerformCurrentAction('حفظ')) _recordAction('حفظ', Icons.save_outlined, _purple, _saveCurrentPage),
        if (!reports && _canPerformCurrentAction('تعديل')) _recordAction('تعديل', Icons.edit_outlined, _orange, _editCurrentRecord),
        if (!reports && _canPerformCurrentAction('حذف')) _recordAction('حذف', Icons.delete_outline_rounded, const Color(0xFFB42318), _chooseWorkspaceDeleteScope),
        if (_canPerformCurrentAction('معاينة')) _recordAction('معاينة', Icons.preview_outlined, const Color(0xFF6E2BA6), () => _showPrintPreview(pdf: false)),
        if (_canPerformCurrentAction('طباعة')) _recordAction('طباعة', Icons.print_outlined, _pink, _printCurrentPagePdf),
        if (_canPerformCurrentAction('استيراد Excel')) _recordAction('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF16834A), _importExcel),
        if (_canPerformCurrentAction('تصدير Excel')) _recordAction('تصدير Excel', Icons.file_download_outlined, const Color(0xFF16834A), _exportExcel),
        if (_canPerformCurrentAction('طباعة PDF')) _recordAction('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFD32F2F), _printCurrentPagePdf),
        if (reports) _recordAction('إلغاء التحديد', Icons.clear_all_rounded, _purple, () => setState(() => _selectedRecord = null)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ErpScreenLayoutRuntime(
      screen: _page,
      child: ErpQuickTaskPermissionScope(
        canPerform: (label) => _canPerformActionLabel(label),
        child: Directionality(
      textDirection: SilsilaLanguage.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: LayoutBuilder(builder: (context, c) {
        // Responsive breakpoints: keep navigation, workspace, and utility panels visible.
        final width = c.maxWidth;
        final compact = width < 980;
        final mobile = width < 980;
        // On phones, navigation panels become overlay drawers instead of squeezing
        // the workspace into a few dozen pixels (which breaks Arabic word shaping).
        final sidebarWidth = width < 1050 ? 178.0 : width < 1320 ? 205.0 : width < 1550 ? 228.0 : 248.0;
        final rightPanelWidth = width < 1050 ? 178.0 : width < 1320 ? 205.0 : width < 1550 ? 228.0 : 248.0;
        final pagePadding = width < 480 ? 10.0 : width < 980 ? 8.0 : width < 1450 ? 12.0 : 16.0;
        return Scaffold(
          backgroundColor: _canvas,
          drawer: mobile ? Drawer(
            width: width < 380 ? width * .88 : 320,
            child: _sidebar(),
          ) : null,
          endDrawer: mobile ? Drawer(
            width: width < 380 ? width * .88 : 320,
            child: _rightPanel(),
          ) : null,
          body: !_executiveAccessChecked
              ? const Center(child: CircularProgressIndicator())
              : Row(children: [
            if (!mobile && _mainSidebarVisible) SizedBox(width: sidebarWidth, child: _sidebar()),
            Expanded(child: Column(children: [
              _header(compact, mobile: mobile),
              Expanded(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // This screen has its own bounded-height tree/grid and must
                    // not be nested in SingleChildScrollView.
                    child: (
                      _page == 'بيانات جغرافية' ||
                      _page == 'الفروع' ||
                      _page == 'فروع النشاطات' ||
                      _page == 'عملاء النشاطات' ||
                      _page == 'مراكز التكلفة' ||
                      _page == 'الفروع ومراكز التكلفة' ||
                      _page == 'المستخدمين' ||
                      _page == 'قوالب صلاحيات المستخدمين' ||
                      _page == 'صلاحيات المستخدمين' ||
                      _page == 'سياسات البرنامج' ||
                      _page == 'سلسلة ستوديو' ||
                      _page == 'شاشات الاستوديو المنشورة' ||
                      _page == 'بيانات المخازن' ||
                      _page == 'دليل المخازن والفروع' ||
                      _page == 'دليل المخازن' ||
                      _page == 'دليل الأصناف' ||
                      _page == 'حركة نقدية' || _page == 'أمر صرف / توريد نقدية' ||
                      _page == 'أمر صرف شيكات' || _page == 'حركة صرف / توريد شيكات' ||
                      _page == 'تسجيل دفاتر شيكات' || _page == 'متابعة الشيكات' ||
                      _page == 'شيكات الائتمان' || _page == 'السياسات المحاسبية'
                    )
                        ? Padding(
                            padding: EdgeInsets.all(pagePadding),
                            child: ErpKeyboardNavigation(
                              child: _page == 'بيانات جغرافية'
                                  ? ErpGeographicDataScreen(
                                      companyId: _appManagementCompanyId,
                                    )
                                  : (_page == 'حركة نقدية' || _page == 'أمر صرف / توريد نقدية' || _page == 'أمر صرف شيكات' || _page == 'حركة صرف / توريد شيكات' || _page == 'تسجيل دفاتر شيكات' || _page == 'متابعة الشيكات' || _page == 'شيكات الائتمان' || _page == 'السياسات المحاسبية')
                                      ? ErpFinancialOperationsScreen(companyId: _appManagementCompanyId, initialView: _page)
                                      : (_module == 'شئون موظفين' || _module == 'موارد بشرية')
                                      ? ErpHrAffairsScreen(page: _page, companyId: _appManagementCompanyId, canManage: _hrDashboardCanManage)
                                      : _page == 'الفروع'
                                      ? ErpCompanyBranchesDesignScreen(companyId: _appManagementCompanyId, embedded: true)
                                      : _page == 'فروع النشاطات'
                                      ? ErpActivityBranchesScreen(companyId: _appManagementCompanyId)
                                      : _page == 'عملاء النشاطات'
                                      ? ErpActivityCustomersScreen(companyId: _appManagementCompanyId)
                                      : (_page == 'مراكز التكلفة' || _page == 'الفروع ومراكز التكلفة')
                                      ? ErpCostCentersScreen(companyId: _appManagementCompanyId)
                                       : _page == 'سلسلة ستوديو'
                                      ? SilsilaStudioScreen(companyId: _appManagementCompanyId, availableScreens: (_modules.values.expand((module) => module.values.expand((items) => items)).toSet().toList()..sort()))
                                      : _page == 'شاشات الاستوديو المنشورة'
                                      ? ErpStudioPublishedDesignsScreen(companyId: _appManagementCompanyId)
                                      : _page == 'سياسات البرنامج'
                                      ? ErpProgramPoliciesScreen(
                                          companyId: _appManagementCompanyId,
                                        )
                                      : (_page == 'بيانات المخازن' || _page == 'دليل المخازن والفروع' || _page == 'دليل المخازن')
                                          ? ErpInventoryMasterScreen(key: ValueKey('$_page-$_appManagementCompanyId'), initialCompanyId: _appManagementCompanyId, initialView: 'warehouses')
                                          : _page == 'دليل الأصناف'
                                              ? ErpInventoryMasterScreen(key: ValueKey('$_page-$_appManagementCompanyId'), initialCompanyId: _appManagementCompanyId, initialView: 'items')
                                              : ErpUserAdminScreen(
                                          companyId: _appManagementCompanyId,
                                          initialView: _page == 'قوالب صلاحيات المستخدمين'
                                              ? 'templates'
                                              : _page == 'صلاحيات المستخدمين'
                                                  ? 'permissions'
                                                  : 'types',
                                        ),
                            ),
                          )
                        : _page == 'إدارة نشاطي'
                        ? ErpKeyboardNavigation(child: ErpBusinessWorkspaceScreen(onExit: _goHome))
                        : _page == 'إدارة إعلانات التطبيق'
                        ? ErpKeyboardNavigation(child: ErpAppAdvertisementsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey] ?? ''))
                        : _page == 'بيانات الأنشطة'
                        ? ErpKeyboardNavigation(child: ErpActivityDataScreen(companyId: _appManagementCompanyId))
                        : _page == 'فئات الأصناف'
                        ? ErpKeyboardNavigation(child: ErpActivityDataScreen(companyId: _appManagementCompanyId))
                        : SingleChildScrollView(
                      padding: EdgeInsets.all(pagePadding),
                      child: ErpKeyboardNavigation(child: _page == 'مسح جميع البيانات' ? ErpClearDataScreen(companyId: _appManagementCompanyId) : _page == 'بيانات الأنشطة' ? ErpActivityDataScreen(companyId: _appManagementCompanyId) : _page == 'سياسات البرنامج' ? ErpProgramPoliciesScreen(companyId: _appManagementCompanyId) : _page == 'مؤجلات وعمولات الموردين' ? ErpSupplierDeferredCommissionsScreen(companyId: _appManagementCompanyId) : _page == 'عن البرنامج' ? _about() : _page == 'قاعدة العملاء المحتملين' ? ErpPublicLeadsScreen(companyId: _appManagementCompanyId) : _page == 'إضافة حسابات جروبات فيسبوك' ? ErpFacebookGroupLeadsScreen(companyId: _appManagementCompanyId) : _page == 'أهداف المبيعات' || _page == 'بيانات مندوبين المبيعات' || _page == 'عمولات المندوبين' || _page == 'عمولات المبيعات' || _page == 'خطط العمولة' || _page == 'مسودات العمولات' || _page == 'تحقيق أهداف العملاء' || _page == 'تقرير العمولات المستحقة' ? (_page == 'بيانات مندوبين المبيعات' ? ErpSalesRepresentativesScreen(companyId: _appManagementCompanyId) : ErpSalesTargetsCommissionsScreen(companyId: _appManagementCompanyId, initialTabIndex: _page == 'عمولات المندوبين' || _page == 'عمولات المبيعات' ? 1 : _page == 'خطط العمولة' ? 2 : _page == 'مسودات العمولات' || _page == 'تقرير العمولات المستحقة' ? 3 : 0)) : _page == 'بيانات العملاء' || _page == 'بيانات الموردين' ? ErpPartiesScreen(initialCompanyId: _appManagementCompanyId, initialKind: _page == 'بيانات الموردين' ? 'supplier' : 'customer') : _page == 'حدود الائتمان' ? ErpCustomerCreditScreen(companyId: _appManagementCompanyId) : (_page == 'حركة نقدية' || _page == 'أمر صرف / توريد نقدية' || _page == 'أمر صرف شيكات' || _page == 'حركة صرف / توريد شيكات' || _page == 'تسجيل دفاتر شيكات' || _page == 'متابعة الشيكات' || _page == 'شيكات الائتمان' || _page == 'السياسات المحاسبية') ? ErpFinancialOperationsScreen(companyId: _appManagementCompanyId, initialView: _page) : _page == 'طرق الدفع' ? ErpPaymentMethodsScreen(companyId: _appManagementCompanyId) : _page == 'العملات' ? ErpCurrenciesScreen(companyId: _appManagementCompanyId) : _page == 'شجرة الحسابات' ? ErpAccountsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الفترات المالية' || _page == 'إقفال الفترة' ? ErpFiscalPeriodsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'قائمة اعتماد القيود' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId, initialStatus: 'draft') : _page == 'قيود اليومية' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId) : _page == 'ميزان المراجعة' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.trialBalance, initialCompanyId: _appManagementCompanyId) : _page == 'الأستاذ العام' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.generalLedger, initialCompanyId: _appManagementCompanyId) : _page == 'حركة حساب' ? ErpLedgerReportsScreen(kind: ErpLedgerReportKind.accountMovement, initialCompanyId: _appManagementCompanyId) : _page == 'الملخص التنفيذي' || _page == 'ملخص تنفيذي' ? _home() : _module == 'إعدادات عامة' && _page == 'بيانات الشركة' ? ErpCompanyProfileScreen(companyId: _appManagementCompanyId, onCompanyCreated: (companyId) async { if (!mounted) return; setState(() => _appManagementCompanyId = companyId); await _loadWorkspaceSettings(companyId); await _loadExecutiveMetrics(companyId); }) : _page == 'إدارة الشعار والصور' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey] ?? '', initialAssetType: 'app_logo') : _page == 'إدارة صور الأصناف والفئات' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey] ?? '', initialAssetType: 'item') : _page == 'إدارة صور الموردين والعملاء' ? ErpAppAssetsScreen(companyId: _appManagementCompanyId, appId: _managedAppIds[_selectedAppKey] ?? '', initialAssetType: 'supplier') : _page == 'إدارة شركات الشحن' ? const ErpShippingCompaniesScreen() : _page == 'الفروع' ? ErpCompanyBranchesDesignScreen(companyId: _appManagementCompanyId, embedded: true) : _page == 'فروع النشاطات' ? ErpActivityBranchesScreen(companyId: _appManagementCompanyId) : _page == 'عملاء النشاطات' ? ErpActivityCustomersScreen(companyId: _appManagementCompanyId) : _page == 'مراكز التكلفة' || _page == 'الفروع ومراكز التكلفة' ? ErpCostCentersScreen(companyId: _appManagementCompanyId) : _page == 'بيانات جغرافية' ? ErpGeographicDataScreen(companyId: _appManagementCompanyId) : _module == 'إدارة تطبيقات' && !_isDatabaseReport(_page) ? _appManagement() : _page == 'مراجعة الحركات' ? ErpMovementAuditScreen(initialCompanyId: _appManagementCompanyId) : _page == 'جامع صور الأصناف' ? const ErpImageCollectorScreen() : _page == 'استيراد بيانات اصناف' ? const ErpItemDataImportScreen() : _page == 'تنزيل بيانات أصناف' ? const ErpItemDataDownloadScreen() : (_page == 'بيانات المخازن' || _page == 'دليل المخازن والفروع' || _page == 'دليل المخازن') ? ErpInventoryMasterScreen(key: ValueKey('$_page-$_appManagementCompanyId'), initialCompanyId: _appManagementCompanyId, initialView: 'warehouses') : _page == 'فئات الأصناف' ? ErpActivityDataScreen(companyId: _appManagementCompanyId) : _page == 'دليل الأصناف' ? ErpInventoryMasterScreen(key: ValueKey('$_page-$_appManagementCompanyId'), initialCompanyId: _appManagementCompanyId, initialView: 'items') : _page == 'وحدات الأصناف' ? ErpItemUnitsScreen(companyId: _appManagementCompanyId) : _page == 'جرد فعلي' || _page == 'محاضر الجرد ومراجعة الفروق' || _page == 'الجرد والفروق' || _page == 'تقارير جرد المخزن' || _page == 'تسوية جرد' ? ErpStocktakeScreen(key: ValueKey('$_page-$_appManagementCompanyId'), companyId: _appManagementCompanyId ?? '', title: _page == 'تسوية جرد' ? 'التسوية المخزنية' : (_page == 'الجرد والفروق' || _page == 'تقارير جرد المخزن') ? 'تقارير جرد المخزن' : 'الجرد الفعلي للمخازن') : _page == 'أرصدة الأصناف' || _page == 'كارت الصنف' || _page == 'إذن إضافة' || _page == 'إذن صرف' || _page == 'تحويل مخزني' ? ErpInventoryScreen(initialCompanyId: _appManagementCompanyId) : _page == 'ملخص إدارة موارد بشرية' ? ErpHrExecutiveDashboardScreen(companyId: _appManagementCompanyId, canManage: _hrDashboardCanManage, canApproveStaffingPlans: _hrDashboardCanApproveStaffingPlans) : _page == 'بيانات الموظفين' || _page == 'ملف الموظف' ? ErpEmployeeMasterScreen(initialCompanyId: _appManagementCompanyId) : _page == 'بيانات الوظائف' || _page == 'بيانات الإدارات' || _page == 'مواقع العمل' || _page == 'الإدارات والأقسام' || _page == 'الوظائف والدرجات' || _page == 'الهيكل الوظيفي' ? ErpHrStructureScreen(key: ValueKey('$_page-$_appManagementCompanyId'), initialCompanyId: _appManagementCompanyId, initialTab: _page == 'بيانات الإدارات' ? 'بيانات الإدارات' : _page == 'بيانات الوظائف' ? 'بيانات الوظائف' : _page, initialView: _hrStructureView, onViewChanged: (view) => setState(() => _hrStructureView = view)) : _page == 'الحضور والانصراف' ? ErpHrOperationsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الإجازات والأذونات' ? ErpHrLeaveScreen(initialCompanyId: _appManagementCompanyId) : _page == 'عناصر المرتبات' ? ErpSalaryElementsScreen(companyId: _appManagementCompanyId) : _page == 'شريط قبض موظف' || _page == 'شريط قبض مجمع' ? ErpPayslipReportsScreen(companyId: _appManagementCompanyId, initialTab: _page == 'شريط قبض مجمع' ? 1 : 0) : _page == 'مسير الرواتب' || _page == 'صرف الرواتب' ? ErpPayrollScreen(initialCompanyId: _appManagementCompanyId) : _page == 'عروض الأصناف' ? ErpItemOffersScreen(companyId: _appManagementCompanyId) : _page == 'مجلات عروض العملاء' ? ErpItemOffersScreen(companyId: _appManagementCompanyId, initialCampaignType: 'customer_magazine', lockCampaignType: true) : _page == 'عروض الترويج' ? ErpItemOffersScreen(companyId: _appManagementCompanyId, initialCampaignType: 'promotion', lockCampaignType: true) : _page == 'عروض الرواكد' ? ErpItemOffersScreen(companyId: _appManagementCompanyId, initialCampaignType: 'slow_moving', lockCampaignType: true) : _page == 'نواقص العملاء' ? ErpCustomerShortagesScreen(companyId: _appManagementCompanyId) : _page == 'سحب أرقام جروبات واتساب' ? ErpWhatsappContactsScreen(companyId: _appManagementCompanyId) : _page == 'قوائم أسعار البيع' ? ErpPriceListsScreen(initialCompanyId: _appManagementCompanyId, initialKind: 'sale') : _page == 'قوائم أسعار الموردين' || _page == 'قوائم أسعار الشراء' ? ErpPriceListsScreen(initialCompanyId: _appManagementCompanyId, initialKind: 'purchase') : _page == 'خريطة الحسابات التشغيلية' ? ErpOperationalAccountMappingsScreen(initialCompanyId: _appManagementCompanyId) : _page == 'الخزائن الرئيسية والفرعية' ? ErpCashboxesScreen(initialCompanyId: _appManagementCompanyId) : _page == 'طرق الدفع' ? ErpPaymentMethodsScreen(companyId: _appManagementCompanyId) : _page == 'الحسابات البنكية' ? ErpCashboxesScreen(initialCompanyId: _appManagementCompanyId, initialBankOnly: true) : _page == 'سندات القبض' || _page == 'تحصيلات العملاء' || _page == 'تحصيل نقدي' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'receipt') : _page == 'سندات الصرف' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'payment') : _page == 'تحويل بين الخزائن' ? ErpCashVouchersScreen(initialCompanyId: _appManagementCompanyId, initialType: 'transfer') : _page == 'طلب شراء' || _page == 'أمر شراء' || _page == 'استلام مشتريات' || _page == 'فاتورة مشتريات' || _page == 'مرتجع مشتريات' ? ErpOperationalDocumentsScreen(key: ValueKey('purchase-document-$_page'), initialCompanyId: _appManagementCompanyId, kind: ErpOperationalKind.purchase, initialDocumentType: _page == 'طلب شراء' || _page == 'أمر شراء' ? 'order' : _page == 'استلام مشتريات' ? 'receipt' : _page == 'مرتجع مشتريات' ? 'return' : 'invoice') : _page == 'إذن التجهيز' ? ErpSalesFulfillmentScreen(companyId: _appManagementCompanyId ?? '', kind: 'preparation') : _page == 'إذن التسليم' || _page == 'إذن تحميل' || _page == 'تسليم طلب' ? ErpSalesFulfillmentScreen(companyId: _appManagementCompanyId ?? '', kind: 'delivery') : _page == 'عرض سعر' || _page == 'أمر بيع' || _page == 'فاتورة بيع' || _page == 'مرتجع مبيعات' ? ErpOperationalDocumentsScreen(key: ValueKey('sales-document-$_page'), initialCompanyId: _appManagementCompanyId, kind: ErpOperationalKind.sales, initialDocumentType: _page == 'عرض سعر' ? 'quotation' : _page == 'أمر بيع' ? 'order' : _page == 'مرتجع مبيعات' ? 'return' : 'invoice') : _page == 'المستخدمين' || _page == 'صلاحيات المستخدمين' || _page == 'قوالب صلاحيات المستخدمين' || _page == 'احتياطي شاشة المستخدمين' ? ErpUserAdminScreen(companyId: _appManagementCompanyId, initialView: _page == 'صلاحيات المستخدمين' ? 'permissions' : _page == 'قوالب صلاحيات المستخدمين' ? 'templates' : _page == 'احتياطي شاشة المستخدمين' ? 'hierarchy' : 'types') : ['أصول ثابتة','تصنيع','مقاولات','خدمة ومتابعة وعلاقات عملاء'].contains(_module) ? ErpBusinessSuiteScreen(module: _module, group: _group, page: _page, companyId: _appManagementCompanyId) : _modules['فاتورة الكترونية']![_group]!.contains(_page) ? ErpEinvoiceScreen(companyId: _appManagementCompanyId, initialView: _page) : _page == 'سجل العمليات' ? ErpActivityLogScreen(companyId: _appManagementCompanyId) : _page == 'إدارة مفاتيح API' || _page == 'واجهة API والربط الخارجي' || _page == 'الربط الخارجي' ? const ErpApiManagementScreen() : _page == 'سياسات التسعير والخصومات' ? _pricingPolicyScreen() : _page == 'توزيع الأصناف على المندوبين' ? ErpDelegateAllocationScreen(companyId: _appManagementCompanyId) : _page == 'قيود البيع والشراء' ? _transactionRestrictionsScreen() : _page == 'قائمة اعتماد القيود' ? ErpJournalEntriesScreen(initialCompanyId: _appManagementCompanyId, initialStatus: 'draft') : _page == 'قواعد الورديات والحضور والانصراف' ? HrShiftRulesScreen(companyId: _appManagementCompanyId) : _page == 'أجهزة البصمة وربط الحضور' ? HrFingerprintDevicesScreen(companyId: _appManagementCompanyId) : _isDatabaseReport(_page) ? ErpReportCenterScreen(companyId: _appManagementCompanyId, reportName: _page) : _workspace()),
                    ),
                  ),
                  if (!mobile && _utilitySidebarVisible) SizedBox(
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
        ),
      ),
    );
  }

  final Set<String> _expandedModules = <String>{};
  final Set<String> _expandedGroups = <String>{};

  Widget _sidebar() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF26004F), Color(0xFF3E007D), Color(0xFF5A1594), Color(0xFF26004F)], stops: [0, .38, .72, 1]),
      boxShadow: [BoxShadow(color: Color(0x443E007D), blurRadius: 20, offset: Offset(4, 0))],
    ),
    child: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'إخفاء القوائم الرئيسية',
                onPressed: () => setState(() => _mainSidebarVisible = false),
                icon: const Icon(Icons.menu_rounded, color: _orange, size: 25),
              ),
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
          ..._modules.entries
              .where((moduleEntry) => _isSystemAdmin || moduleEntry.value.entries.any((groupEntry) =>
                  groupEntry.value.any((page) => _canOpenScreen(moduleEntry.key, groupEntry.key, page))))
              .map((moduleEntry) {
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
                ...moduleEntry.value.entries
                  .where((groupEntry) => _isSystemAdmin || groupEntry.value.any((page) =>
                      _canOpenScreen(name, groupEntry.key, page)))
                  .map((groupEntry) {
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
                        ...groupEntry.value
                            .where((page) => _canOpenScreen(name, groupEntry.key, page))
                            .map((page) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 20, end: 5),
                          child: Row(children: [
                            Expanded(child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -3),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                              hoverColor: const Color(0xFFFFA015),
                              selected: page == _page && selectedModule,
                              selectedTileColor: const Color(0xFFFFA015),
                              minLeadingWidth: 12,
                              leading: Icon(page == _page && selectedModule ? Icons.radio_button_checked_rounded : Icons.circle_outlined, color: const Color(0xFF3E007D), size: 11),
                              title: Text(page, style: TextStyle(color: const Color(0xFF3E007D), fontSize: 10.5, fontWeight: page == _page && selectedModule ? FontWeight.w800 : FontWeight.normal)),
                              onTap: () => _open(name, groupEntry.key, page),
                            )),
                            _quickAccessScreenButton(name, groupEntry.key, page),
                          ]),
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
    if (name.contains('إعدادات عامة')) return Icons.settings_suggest_rounded;
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
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)), child: Text(_stocktakeAlertsLoading ? '…' : _pendingStocktakeDrafts.toString(), style: TextStyle(color: _purple, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _open('مخازن', 'حركات', 'تسوية جرد'),
              borderRadius: BorderRadius.circular(10),
              child: _notice(Icons.inventory_2_outlined, 'تسويات جرد غير مرحلة', 'يوجد $_pendingStocktakeDrafts مستند جرد أو تسوية يدوية محفوظ كمسودة ولم يُرحّل بعد. اضغط لفتح شاشة التسوية.', _pendingStocktakeDrafts > 0 ? _orange : Colors.white),
            ),
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
              Expanded(child: Text(silsilaText('آخر إجراءات هذه الجلسة'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
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
              ..._quickAccessScreenTiles(),
            ]),
          ]),
        ),
      ],
      if (_notificationsPanelVisible || _activityPanelVisible)
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(silsilaText('ملاحظة: تنبيهات محاضر الجرد مرتبطة بقاعدة البيانات، أما آخر الإجراءات المعروضة فهي محلية لهذه الجلسة وليست سجل تدقيق مركزيًا.'), style: TextStyle(color: Colors.black54, fontSize: 10, height: 1.6)),
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
      Text(silsilaText('إدارة تطبيقات'), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
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
      DropdownButtonFormField<String>(itemHeight: 48, 
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
        _module = 'إدارة تطبيقات';
        _group = 'بيانات أساسية';
        _page = target;
        _selectedRecord = null;
      });
    },
  );

  Widget _header(bool compact, {bool mobile = false}) => Container(height: compact ? 62 : 72, padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12), decoration: BoxDecoration(
    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFF8F1FF), Color(0xFFF2E7FB)]),
    border: const Border(bottom: BorderSide(color: Color(0xFFE4D2F1), width: 1)),
    boxShadow: [BoxShadow(color: _purple.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 4)), BoxShadow(color: _pink.withValues(alpha: .08), blurRadius: 18, spreadRadius: -5)],
  ), child: Row(children: [
    Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: const SilsilaWhiteLogo(
        width: 38,
        height: 38,
      ),
    ),
    if (compact)
      const SizedBox(width: 4),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_module, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: compact ? 15 : 18)),
      if (!compact) const SizedBox(height: 4),
      if (!mobile) Wrap(
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

    if (mobile) ...[
      Builder(builder: (buttonContext) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'القائمة الرئيسية',
        onPressed: () => Scaffold.of(buttonContext).openDrawer(),
        icon: const Icon(Icons.menu_rounded, color: _orange),
      )),
      Builder(builder: (buttonContext) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'النشاطات والتنبيهات والوصول السريع',
        onPressed: () => Scaffold.of(buttonContext).openEndDrawer(),
        icon: const Icon(Icons.dashboard_customize_outlined, color: _purple),
      )),
    ] else ...[
      if (!_mainSidebarVisible)
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'إظهار القوائم الرئيسية',
          onPressed: () => setState(() => _mainSidebarVisible = true),
          icon: const Icon(Icons.menu_rounded, color: _orange),
        ),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: _utilitySidebarVisible ? 'إخفاء النشاطات والتنبيهات والوصول السريع' : 'إظهار النشاطات والتنبيهات والوصول السريع',
        onPressed: () => setState(() => _utilitySidebarVisible = !_utilitySidebarVisible),
        icon: Icon(Icons.menu_rounded, color: _utilitySidebarVisible ? _purple : _orange),
      ),
    ],
    IconButton(visualDensity: VisualDensity.compact, tooltip: 'الإشعارات', onPressed: () => ErpCenterToast.show(context, silsilaText('مركز الإشعارات')), icon: const Icon(Icons.notifications_none_rounded, color: _purple)),
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

  ({DateTime start, DateTime end}) _executivePeriodBounds(DateTime now, DateTime activityStart) {
    final today = DateTime(now.year, now.month, now.day);
    switch (_executivePeriod) {
      case 'السنة السابقة':
        return (start: DateTime(now.year - 1), end: DateTime(now.year));
      case 'السنة الحالية':
        return (start: DateTime(now.year), end: DateTime(now.year + 1));
      case 'الشهر السابق':
        return (start: DateTime(now.year, now.month - 1), end: DateTime(now.year, now.month));
      case 'الشهر الحالي':
        return (start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1));
      default:
        return (start: DateTime(activityStart.year, activityStart.month, activityStart.day), end: today.add(const Duration(days: 1)));
    }
  }

  double? _executiveChange(double? current, double? previous) {
    if (current == null || previous == null || previous == 0) return null;
    return ((current - previous) / previous.abs()) * 100;
  }

  Future<void> _loadStocktakeAlerts(String companyId) async {
    if (companyId.isEmpty) return;
    if (mounted) setState(() => _stocktakeAlertsLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('erp_stocktakes')
          .select('id')
          .eq('company_id', companyId)
          .inFilter('source', ['stocktake', 'manual'])
          .eq('status', 'draft');
      if (mounted) setState(() => _pendingStocktakeDrafts = (rows as List).length);
    } catch (_) {
      // Preserve the last known count if the user has no permission to read stocktakes.
    } finally {
      if (mounted) setState(() => _stocktakeAlertsLoading = false);
    }
  }

  Future<void> _loadExecutiveMetrics(String companyId) async {
    if (!mounted || companyId.isEmpty) return;
    _loadStocktakeAlerts(companyId);
    setState(() {
      _executiveMetricsLoading = true;
      _executiveMetricsError = null;
    });
    final now = DateTime.now();
    DateTime activityStart = DateTime(2000, 1, 1);
    try {
      final company = await Supabase.instance.client
          .from('erp_companies')
          .select('created_at')
          .eq('id', companyId)
          .maybeSingle();
      final createdAt = company?['created_at']?.toString();
      if (createdAt != null && createdAt.isNotEmpty) {
        activityStart = DateTime.tryParse(createdAt)?.toLocal() ?? activityStart;
      }
    } catch (_) {
      // Keep a conservative fallback if company metadata is not readable.
    }
    final bounds = _executivePeriodBounds(now, activityStart);
    final duration = bounds.end.difference(bounds.start);
    final previousEnd = bounds.start;
    final previousStart = _executivePeriod == 'من بداية النشاط'
        ? bounds.start
        : bounds.start.subtract(duration);
    try {
      Future<Map<String, dynamic>> fetchMetrics(DateTime start, DateTime end) async {
        final raw = await Supabase.instance.client.rpc(
          'erp_get_executive_metrics',
          params: {
            'p_company_id': companyId,
            'p_month_start': start.toIso8601String().substring(0, 10),
            'p_month_end': end.toIso8601String().substring(0, 10),
          },
        );
        return Map<String, dynamic>.from(raw as Map);
      }
      final currentData = await fetchMetrics(bounds.start, bounds.end);
      // Fetch document-level totals for the visible gross/returns breakdown.
      // Keep these separate from the server-calculated net KPI values.
      final fromDate = bounds.start.toIso8601String().substring(0, 10);
      final toDate = bounds.end.toIso8601String().substring(0, 10);
      final breakdownResults = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('erp_sales_documents')
            .select('document_type,grand_total')
            .eq('company_id', companyId)
            .eq('status', 'posted')
            .eq('is_demo_data', false)
            .gte('document_date', fromDate)
            .lt('document_date', toDate),
        Supabase.instance.client
            .from('erp_purchase_documents')
            .select('document_type,grand_total')
            .eq('company_id', companyId)
            .eq('status', 'posted')
            .eq('is_demo_data', false)
            .gte('document_date', fromDate)
            .lt('document_date', toDate),
      ]);
      double sumDocumentType(dynamic rows, String type) {
        if (rows is! List) return 0;
        return rows.whereType<Map>().where((row) => row['document_type']?.toString() == type)
            .fold<double>(0, (sum, row) => sum + (double.tryParse(row['grand_total']?.toString() ?? '') ?? 0));
      }
      final salesRows = breakdownResults[0];
      final purchaseRows = breakdownResults[1];
      final grossSales = sumDocumentType(salesRows, 'invoice');
      final salesReturns = sumDocumentType(salesRows, 'return');
      final grossPurchases = sumDocumentType(purchaseRows, 'invoice');
      final purchaseReturns = sumDocumentType(purchaseRows, 'return');
      Map<String, dynamic> previousData = <String, dynamic>{};
      if (_executivePeriod != 'من بداية النشاط' && previousEnd.isAfter(previousStart)) {
        previousData = await fetchMetrics(previousStart, previousEnd);
      }
      double? numberValue(Map<String, dynamic> data, String key) {
        final value = data[key];
        return value == null ? null : double.tryParse(value.toString());
      }
      List<double> numberList(Map<String, dynamic> data, String key) {
        final raw = data[key];
        if (raw is! List) return <double>[];
        return raw.map((value) => double.tryParse(value.toString()) ?? 0).toList();
      }
      List<Map<String, dynamic>> mapList(Map<String, dynamic> data, String key) {
        final raw = data[key];
        if (raw is! List) return <Map<String, dynamic>>[];
        return raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      }
      List<String> stringList(Map<String, dynamic> data, String key) {
        final raw = data[key];
        if (raw is! List) return <String>[];
        return raw.map((value) => value.toString()).toList();
      }
      if (!mounted) return;
      setState(() {
        _executiveSales = numberValue(currentData, 'sales');
        _executiveGrossSales = grossSales;
        _executiveSalesReturns = salesReturns;
        _executiveGrossPurchases = grossPurchases;
        _executivePurchaseReturns = purchaseReturns;
        _executiveCollections = numberValue(currentData, 'collections');
        _executiveReceivables = numberValue(currentData, 'receivables');
        _executivePurchases = numberValue(currentData, 'purchases');
        _executiveGrossProfit = numberValue(currentData, 'gross_profit_estimate');
        _executiveInventoryValue = numberValue(currentData, 'inventory_value_estimate');
        _executiveExpenses = numberValue(currentData, 'expenses');
        _executivePreviousExpenses = numberValue(previousData, 'expenses');
        _executiveFixedAssetsGross = numberValue(currentData, 'fixed_assets_gross');
        _executiveFixedAssetsDepreciation = numberValue(currentData, 'fixed_assets_depreciation');
        _executiveFixedAssetsNet = numberValue(currentData, 'fixed_assets_net');
        _executiveCashInflows = numberValue(currentData, 'cash_inflows');
        _executiveCashOutflows = numberValue(currentData, 'cash_outflows');
        _executiveCashNetFlow = numberValue(currentData, 'cash_net_flow');
        _executiveAverageInvoice = numberValue(currentData, 'average_invoice');
        _executiveSalesReturnRate = numberValue(currentData, 'sales_return_rate');
        _executiveAttendanceRate = numberValue(currentData, 'attendance_rate');
        _executivePayrollNetTotal = numberValue(currentData, 'payroll_net_total');
        _executiveInvoiceCount = numberValue(currentData, 'invoice_count')?.toInt();
        _executiveReorderItemCount = numberValue(currentData, 'reorder_item_count')?.toInt();
        _executiveExpiryBatchCount = numberValue(currentData, 'expiry_batch_count_30d')?.toInt();
        _executiveSlowMovingItemCount = numberValue(currentData, 'slow_moving_item_count')?.toInt();
        _executiveFulfillmentPendingCount = numberValue(currentData, 'fulfillment_pending_count')?.toInt();
        _executivePendingApprovalCount = numberValue(currentData, 'pending_approval_count')?.toInt();
        _executiveSupplierPayables = numberValue(currentData, 'supplier_payables');
        _executiveSupplierOverdueDocuments = numberValue(currentData, 'supplier_overdue_documents')?.toInt();
        _executiveCreditLimitExceededCount = numberValue(currentData, 'credit_limit_exceeded_count')?.toInt();
        _executiveFulfillmentCancelledCount = numberValue(currentData, 'fulfillment_cancelled_count')?.toInt();
        _executiveInventoryTurnoverRate = numberValue(currentData, 'inventory_turnover_rate');
        _executiveDataCompletenessRate = numberValue(currentData, 'data_completeness_rate');
        _executiveBranchSales = mapList(currentData, 'branch_sales');
        _executiveTopProfitableItems = mapList(currentData, 'top_profitable_items');
        _executiveCategorySales = mapList(currentData, 'category_sales');
        _executiveTopCustomers = ((currentData['top_customers'] as List?) ?? const [])
            .whereType<Map>().map((row) => row['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
        _executiveTopItems = ((currentData['top_items'] as List?) ?? const [])
            .whereType<Map>().map((row) => row['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
        _executivePreviousSales = numberValue(previousData, 'sales');
        _executivePreviousPurchases = numberValue(previousData, 'purchases');
        _executivePreviousGrossProfit = numberValue(previousData, 'gross_profit_estimate');
        _executiveDailySales = numberList(currentData, 'daily_sales');
        _executiveDailyCollections = numberList(currentData, 'daily_collections');
        // Keep the RPC response contract aligned with erp_executive_metrics_rpc.sql.
        _executiveInventoryGroupLabels = stringList(currentData, 'inventory_category_labels');
        _executiveInventoryGroupValues = numberList(currentData, 'inventory_category_values');
        _executiveMetricsLoading = false;
      });
      await _loadExecutiveStaffPerformance(companyId, bounds.start, bounds.end);
      await _loadExecutiveExpiryMetrics(companyId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _executiveMetricsError = error.toString();
        _executiveMetricsLoading = false;
      });
    }
  }

  Future<void> _loadExecutiveStaffPerformance(String companyId, DateTime start, DateTime end) async {
    // Load each optional source independently. A missing column/table or an RLS
    // restriction must not hide the names returned successfully by other sources.
    Future<List<dynamic>> safeRows(dynamic Function() request) async {
      try {
        final result = await request();
        return result is List ? result : <dynamic>[];
      } catch (_) {
        return <dynamic>[];
      }
    }

    final from = start.toIso8601String().substring(0, 10);
    final to = end.toIso8601String().substring(0, 10);
    final month = DateTime(start.year, start.month).toIso8601String().substring(0, 10);
    final results = await Future.wait<List<dynamic>>([
      safeRows(() => Supabase.instance.client
          .from('erp_sales_representatives').select('*')
          .eq('company_id', companyId).eq('is_active', true)),
      safeRows(() => Supabase.instance.client
          .from('erp_sales_documents').select('*')
          .eq('company_id', companyId).eq('status', 'posted')
          .gte('document_date', from).lt('document_date', to)),
      safeRows(() => Supabase.instance.client
          .from('erp_employee_directory').select('*')
          .eq('company_id', companyId).eq('is_active', true)),
      safeRows(() => Supabase.instance.client
          .from('erp_purchase_documents').select('*')
          .eq('company_id', companyId).eq('status', 'posted')
          .gte('document_date', from).lt('document_date', to)),
      safeRows(() => Supabase.instance.client
          .from('erp_employee_monthly_targets')
          .select('employee_id,target_type,target_month,target_amount')
          .eq('company_id', companyId).eq('target_month', month)),
      safeRows(() => Supabase.instance.client
          .from('erp_users').select('auth_user_id,employee_id')
          .eq('company_id', companyId).eq('is_active', true)),
    ]);
    if (!mounted) return;

    final salesReps = results[0]
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['is_demo_data'] != true)
        .toList()
      ..sort((a, b) => _staffName(a, const ['rep_name', 'full_name', 'name_ar', 'name'])
          .compareTo(_staffName(b, const ['rep_name', 'full_name', 'name_ar', 'name'])));

    final salesDocuments = results[1]
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['is_demo_data'] != true)
        .toList();

    final employeeAuthIds = <String, String>{};
    for (final raw in results[5]) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final employeeId = row['employee_id']?.toString() ?? '';
      final authUserId = row['auth_user_id']?.toString() ?? '';
      if (employeeId.isNotEmpty && authUserId.isNotEmpty) {
        employeeAuthIds[employeeId] = authUserId;
      }
    }
    final employees = results[2]
        .whereType<Map>()
        .map((row) {
          final employee = Map<String, dynamic>.from(row);
          employee['auth_user_id'] ??= employeeAuthIds[employee['id']?.toString()];
          return employee;
        })
        .toList();

    final purchaseDocuments = results[3]
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['is_demo_data'] != true)
        .toList();

    final purchaseCreatorIds = purchaseDocuments
        .map((row) => row['created_by']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final purchasingEmployees = employees.where((employee) {
      final role = [
        employee['job_title'], employee['department_name'],
        employee['job_name'], employee['department'], employee['role_name'],
      ].whereType<Object>().join(' ').toLowerCase();
      final employeeIds = [
        employee['id'], employee['user_id'], employee['auth_user_id'],
      ].whereType<Object>().map((value) => value.toString()).toSet();
      final isPurchasingRole = role.contains('مشت') ||
          role.contains('شراء') || role.contains('procurement') ||
          role.contains('purchas');
      return isPurchasingRole || employeeIds.intersection(purchaseCreatorIds).isNotEmpty;
    }).toList()
      ..sort((a, b) => _staffName(a, const ['full_name', 'name_ar', 'employee_name', 'name'])
          .compareTo(_staffName(b, const ['full_name', 'name_ar', 'employee_name', 'name'])));

    setState(() {
      _executiveSalesReps = salesReps;
      _executiveSalesDocuments = salesDocuments;
      _executivePurchaseEmployees = purchasingEmployees;
      _executivePurchaseDocuments = purchaseDocuments;
      _executiveEmployeeTargets = results[4]
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
  }

  String _staffName(Map<String, dynamic> row, List<String> candidates) {
    for (final key in candidates) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    final code = row['employee_code']?.toString().trim() ?? row['rep_code']?.toString().trim() ?? '';
    return code.isEmpty ? 'اسم غير مسجل' : 'بدون اسم ($code)';
  }

  Widget _executivePeriodCheckbox(String period) {
    final selected = _executivePeriod == period;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => _changeExecutivePeriod(period),
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1E6FF) : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? _purple : const Color(0xFFE7E0EF)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
              value: selected,
              onChanged: (value) {
                if (value == true) _changeExecutivePeriod(period);
              },
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(period, style: TextStyle(
              color: selected ? _purple : const Color(0xFF51465D),
              fontSize: 10,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            )),
          ]),
        ),
      ),
    );
  }

  void _changeExecutivePeriod(String period) {
    if (_executivePeriod == period) return;
    setState(() => _executivePeriod = period);
    final companyId = _appManagementCompanyId;
    if (companyId != null) _loadExecutiveMetrics(companyId);
  }

  Future<void> _loadExecutiveExpiryMetrics(String companyId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final horizon = today.add(const Duration(days: 60));
      final rows = await Supabase.instance.client
          .from('erp_inventory_movements')
          .select('item_id,batch_number,expiry_date,quantity_in,quantity_out')
          .eq('company_id', companyId)
          .not('expiry_date', 'is', null)
          .lte('expiry_date', horizon.toIso8601String().substring(0, 10))
          .limit(10000);

      final batches = <String, Map<String, dynamic>>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final expiry = DateTime.tryParse(row['expiry_date']?.toString() ?? '');
        if (expiry == null) continue;
        final key = '${row['item_id']}|${row['batch_number']}|${row['expiry_date']}';
        final batch = batches.putIfAbsent(key, () => {'expiry': expiry, 'quantity': 0.0});
        batch['quantity'] = (batch['quantity'] as double) +
            (_performanceNumber(row['quantity_in']) - _performanceNumber(row['quantity_out']));
      }

      var expired = 0;
      var next30 = 0;
      var next60 = 0;
      for (final batch in batches.values) {
        if ((batch['quantity'] as double) <= 0) continue;
        final expiry = batch['expiry'] as DateTime;
        if (expiry.isBefore(today)) {
          expired++;
        } else if (!expiry.isAfter(today.add(const Duration(days: 30)))) {
          next30++;
        } else {
          next60++;
        }
      }
      if (!mounted) return;
      setState(() {
        _executiveExpiredBatchCount = expired;
        _executiveExpiryNext60BatchCount = next60;
        _executiveExpiryBatchCount = next30;
      });
    } catch (_) {
      // Expiry alerts are supplementary; do not interrupt financial analytics.
    }
  }

  double _performanceNumber(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  double _salesRepActual(Map<String, dynamic> rep) {
    final id = rep['id']?.toString();
    return _executiveSalesDocuments.where((doc) => doc['sales_rep_id']?.toString() == id).fold<double>(0, (sum, doc) {
      final amount = _performanceNumber(doc['grand_total']);
      return sum + (doc['document_type']?.toString() == 'return' ? -amount : amount);
    });
  }

  double _purchaseEmployeeActual(Map<String, dynamic> employee) {
    final employeeIds = <String>{
      employee['id']?.toString() ?? '',
      employee['auth_user_id']?.toString() ?? '',
    }..remove('');
    return _executivePurchaseDocuments.where((doc) =>
      employeeIds.contains(doc['created_by']?.toString())
    ).fold<double>(0, (sum, doc) {
      final amount = _performanceNumber(doc['grand_total']);
      return sum + (doc['document_type']?.toString() == 'return' ? -amount : amount);
    });
  }

  double _employeeTarget(String employeeId, String type) {
    final matching = _executiveEmployeeTargets.where((target) => target['employee_id']?.toString() == employeeId && target['target_type']?.toString() == type);
    return matching.isEmpty ? 0 : _performanceNumber(matching.first['target_amount']);
  }

  Widget _staffPerformanceCard({required String title, required IconData icon, required Color color, required List<Map<String, dynamic>> people, required double Function(Map<String, dynamic>) actualFor, required double Function(Map<String, dynamic>) targetFor, required String Function(Map<String, dynamic>) nameFor, required String Function(Map<String, dynamic>) classificationFor, required bool showAll, required VoidCallback onToggle, required String emptyText, ValueChanged<Map<String, dynamic>>? onEditTarget}) {
    final sorted = [...people]..sort((a, b) {
      final aTarget = targetFor(a), bTarget = targetFor(b);
      final aRate = aTarget > 0 ? actualFor(a) / aTarget : -1.0;
      final bRate = bTarget > 0 ? actualFor(b) / bTarget : -1.0;
      return bRate.compareTo(aRate);
    });
    final visible = showAll ? sorted : sorted.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7E0EF)), boxShadow: const [BoxShadow(color: Color(0x0A3E007D), blurRadius: 14, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w900))),
          Text('${people.length}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        if (people.isEmpty) Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(Icons.groups_2_outlined, size: 30, color: color.withValues(alpha: .65)),
              const SizedBox(height: 7),
              Text(emptyText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.5)),
              const SizedBox(height: 4),
              const Text('ستظهر البيانات هنا عند تسجيل الموظفين والأهداف والمستندات المعتمدة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
        ),
        ...visible.map((person) {
          final actual = actualFor(person);
          final target = targetFor(person);
          final ratio = target > 0 ? actual / target : 0.0;
          final rateColor = target <= 0 ? Colors.black45 : ratio >= 1 ? _green : ratio >= .7 ? _orange : Colors.red.shade700;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(nameFor(person), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF2C2435), fontWeight: FontWeight.w900))),
                const SizedBox(width: 8),
                Text(target > 0 ? '${(ratio * 100).toStringAsFixed(0)}%' : 'الهدف غير محدد', style: TextStyle(fontSize: 12, color: rateColor, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(classificationFor(person), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700))),
                Text('فعلي: ${_executiveMoney(actual)}', style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('هدف: ${target > 0 ? _executiveMoney(target) : '—'}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                if (onEditTarget != null) IconButton(tooltip: 'تحديد الهدف الشهري', visualDensity: VisualDensity.compact, constraints: const BoxConstraints.tightFor(width: 28, height: 28), padding: EdgeInsets.zero, onPressed: () => onEditTarget(person), icon: const Icon(Icons.edit_outlined, size: 15, color: _purple)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: target > 0 ? ratio.clamp(0.0, 1.0).toDouble() : 0, minHeight: 7, backgroundColor: const Color(0xFFEFEAF4), color: rateColor)),
            ]),
          );
        }),
        if (people.length > 5) Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: onToggle, icon: Icon(showAll ? Icons.expand_less : Icons.expand_more), label: Text(showAll ? 'عرض أقل' : 'عرض الكل (${people.length})'))),
      ]),
    );
  }

  Future<void> _editPurchaseTarget(Map<String, dynamic> employee) async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    final month = DateTime(_executivePeriodBounds(DateTime.now(), DateTime.now()).start.year, _executivePeriodBounds(DateTime.now(), DateTime.now()).start.month);
    final controller = TextEditingController(text: _employeeTarget(employee['id'].toString(), 'purchase').toStringAsFixed(2));
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('هدف المشتريات الشهري — ${employee['full_name'] ?? ''}'),
        content: SizedBox(width: 360, child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'قيمة الهدف (ج.م)', border: OutlineInputBorder()),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ الهدف')),
        ],
      ),
    ));
    if (ok != true) return;
    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount < 0) {
      if (mounted) ErpCenterToast.show(context, 'أدخل قيمة هدف صحيحة لا تقل عن صفر.');
      return;
    }
    try {
      final targetMonth = month.toIso8601String().substring(0, 10);
      await Supabase.instance.client.from('erp_employee_monthly_targets').upsert({
        'company_id': companyId,
        'employee_id': employee['id'],
        'target_type': 'purchase',
        'target_month': targetMonth,
        'target_amount': amount,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'company_id,employee_id,target_type,target_month');
      await _loadExecutiveStaffPerformance(companyId, month, DateTime(month.year, month.month + 1));
      if (mounted) ErpCenterToast.show(context, 'تم حفظ هدف المشتريات الشهري.');
    } catch (e) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حفظ الهدف: $e', isError: true, duration: const Duration(seconds: 3));
    }
  }

  Widget _executiveStaffPerformance() => LayoutBuilder(builder: (context, constraints) {
    final sales = _staffPerformanceCard(
      title: 'أداء مندوبي المبيعات', icon: Icons.trending_up_rounded, color: _purple,
      people: _executiveSalesReps,
      actualFor: _salesRepActual,
      targetFor: (rep) => _performanceNumber(rep['monthly_sales_target']),
      nameFor: (rep) => _staffName(rep, const ['rep_name', 'full_name', 'name_ar', 'name']),
      classificationFor: (rep) => (rep['rep_classification'] ?? rep['channel'] ?? 'مندوب مبيعات').toString(),
      showAll: _showAllSalesPerformance,
      onToggle: () => setState(() => _showAllSalesPerformance = !_showAllSalesPerformance),
      emptyText: 'لا توجد بيانات مندوبي مبيعات نشطة. أضف المندوبين وحدد أهدافهم الشهرية لعرض نسب الإنجاز.',
    );
    final purchases = _staffPerformanceCard(
      title: 'أداء مسؤولي المشتريات', icon: Icons.shopping_cart_checkout_rounded, color: const Color(0xFF2475B8),
      people: _executivePurchaseEmployees,
      actualFor: _purchaseEmployeeActual,
      targetFor: (employee) => _employeeTarget(employee['id'].toString(), 'purchase'),
      nameFor: (employee) => _staffName(employee, const ['full_name', 'name_ar', 'employee_name', 'name']),
      classificationFor: (employee) => '${employee['job_title'] ?? 'مسؤول مشتريات'} • ${employee['department_name'] ?? 'المشتريات'}',
      showAll: _showAllPurchasePerformance,
      onToggle: () => setState(() => _showAllPurchasePerformance = !_showAllPurchasePerformance),
      emptyText: 'لا توجد بيانات لموظفي المشتريات النشطين. اربط الموظف بقسم/وظيفة المشتريات وحدد له هدفًا شهريًا.',
      onEditTarget: _editPurchaseTarget,
    );
    if (constraints.maxWidth < 760) return Column(children: [sales, const SizedBox(height: 12), purchases]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: sales), const SizedBox(width: 12), Expanded(child: purchases)]);
  });

  Widget _home() {
    if (!_executiveAccessChecked && _appManagementCompanyId != null) {
      return const Center(child: CircularProgressIndicator());
    }
    if ((_executiveAccessChecked && !_executiveSummaryAllowed) || (_executivePartialConfigured && _executiveAllowedSections.isEmpty)) {
      return Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE7E0EF))),
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
        'title': 'مبيعات',
        'icon': Icons.point_of_sale_rounded,
        'color': _purple,
        'items': <Map<String, Object>>[
          {'title': 'صافي مبيعات', 'value': _executiveMoney(_executiveSales), 'note': '$_executivePeriod • فواتير مرحلة', 'icon': Icons.point_of_sale_rounded, 'color': _purple, 'details': 'إجمالي فواتير البيع بعد خصم المرتجعات والخصومات، مع مقارنة يومية وشهرية وبحسب الفرع والمندوب.'},
          {'title': 'نمو المبيعات', 'value': _executivePreviousSales != null && _executivePreviousSales! > 0 && _executiveSales != null ? '${((_executiveSales! - _executivePreviousSales!) / _executivePreviousSales! * 100).toStringAsFixed(1)}%' : '—%', 'note': 'عن الفترة السابقة', 'icon': Icons.trending_up_rounded, 'color': _green, 'details': 'نسبة نمو صافي المبيعات ومقارنة الأداء بالفترة السابقة والمستهدف.'},
          {'title': 'متوسط الفاتورة', 'value': _executiveMoney(_executiveAverageInvoice), 'note': '${_executiveInvoiceCount ?? 0} فاتورة مرحلة', 'icon': Icons.receipt_long_rounded, 'color': _orange, 'details': 'متوسط قيمة فاتورة البيع وتحليل التغير حسب العميل والمندوب والفرع.'},
          {'title': 'أفضل العملاء', 'value': _executiveTopCustomers.isEmpty ? '—' : _executiveTopCustomers.first, 'note': 'أفضل 5: ${_executiveTopCustomers.take(5).join('، ')}', 'icon': Icons.groups_rounded, 'color': _pink, 'details': 'ترتيب العملاء حسب المبيعات والربحية وانتظام السداد.'},
          {'title': 'العملاء المتوقفون', 'value': '—', 'note': 'دون شراء حديث', 'icon': Icons.person_off_outlined, 'color': _orange, 'details': 'العملاء الذين لم يشتروا خلال الفترة المحددة مع قيمة مشترياتهم السابقة.'},
          {'title': 'مرتجعات المبيعات', 'value': _executiveSalesReturnRate == null ? '—%' : '${_executiveSalesReturnRate!.toStringAsFixed(1)}%', 'note': 'من إجمالي المبيعات', 'icon': Icons.assignment_return_outlined, 'color': _pink, 'details': 'قيمة ونسبة المرتجعات وأسبابها والأصناف والعملاء الأعلى في المرتجعات.'},
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
          {'title': 'مستحقات الموردين', 'value': _executiveSupplierPayables == null ? '— ج.م' : _executiveMoney(_executiveSupplierPayables), 'note': 'مستندات متأخرة: ${_executiveSupplierOverdueDocuments ?? '—'}', 'icon': Icons.local_shipping_outlined, 'color': _orange, 'details': 'أرصدة الموردين ومواعيد الاستحقاق وأعمار الديون وخطة السداد.'},
          {'title': 'السيولة المتاحة', 'value': '— ج.م', 'note': 'الخزائن والبنوك', 'icon': Icons.account_balance_wallet_rounded, 'color': _purple, 'details': 'الأرصدة المتاحة في الخزائن والحسابات البنكية وحركة النقدية.'},
          {'title': 'المصروفات', 'value': _executiveMoney(_executiveExpenses), 'note': 'من الإيرادات ${_executiveSales != null && _executiveSales! > 0 && _executiveExpenses != null ? (_executiveExpenses! / _executiveSales! * 100).toStringAsFixed(1) : '—'}%', 'icon': Icons.money_off_csred_outlined, 'color': _pink, 'details': 'إجمالي المصروفات من قيود اليومية المرحلة خلال الفترة، مع نسبة المصروفات إلى صافي المبيعات.'},
        ],
      },
      {
        'title': 'المخزون والمشتريات',
        'icon': Icons.warehouse_outlined,
        'color': const Color(0xFF2475B8),
        'items': <Map<String, Object>>[
          {'title': 'قيمة المخزون', 'value': _executiveMoney(_executiveInventoryValue), 'note': 'تقدير بتكلفة الشراء الحالية', 'icon': Icons.inventory_2_outlined, 'color': const Color(0xFF2475B8), 'details': 'قيمة المخزون المتاح والمحجوز حسب المخزن والفرع والصنف.'},
          {'title': 'تحت حد الطلب', 'value': '${_executiveReorderItemCount ?? '—'} صنف', 'note': 'بحاجة للشراء', 'icon': Icons.warning_amber_rounded, 'color': _orange, 'details': 'الأصناف التي وصلت إلى حد إعادة الطلب والكميات المقترحة للشراء.'},
          {'title': 'منتهية الصلاحية', 'value': '${_executiveExpiredBatchCount ?? '—'} تشغيلة', 'note': 'رصيد متبقٍ بعد تاريخ الانتهاء', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFD92D48), 'details': 'تشغيلات انتهى تاريخ صلاحيتها وما زال لها رصيد موجب؛ يلزم عزلها ومراجعة التسوية أو الإعدام.'},
          {'title': 'قرب انتهاء الصلاحية', 'value': '${_executiveExpiryBatchCount ?? '—'} تشغيلة', 'note': 'خلال 30 يومًا', 'icon': Icons.event_busy_outlined, 'color': _pink, 'details': 'الأصناف القريبة من انتهاء الصلاحية مع الكميات والقيمة والمخزن.'},
          {'title': 'انتهاء خلال 31–60 يومًا', 'value': '${_executiveExpiryNext60BatchCount ?? '—'} تشغيلة', 'note': 'نافذة تنبيه مبكر', 'icon': Icons.date_range_rounded, 'color': _orange, 'details': 'تشغيلات ستنتهي خلال الفترة من اليوم 31 إلى اليوم 60، لإتاحة وقت كافٍ للتصريف أو إعادة التوزيع.'},
          {'title': 'الأصناف الراكدة', 'value': '${_executiveSlowMovingItemCount ?? '—'} صنف', 'note': 'بلا صرف خلال 90 يومًا', 'icon': Icons.inventory_outlined, 'color': _orange, 'details': 'الأصناف التي لم تتحرك خلال فترة محددة وقيمة رأس المال المجمد بها.'},
          {'title': 'دوران المخزون', 'value': _executiveInventoryTurnoverRate == null ? '— مرة' : '${_executiveInventoryTurnoverRate!.toStringAsFixed(2)} مرة', 'note': 'تكلفة المبيعات ÷ قيمة المخزون الحالية', 'icon': Icons.sync_alt_rounded, 'color': _purple, 'details': 'معدل دوران المخزون ومتوسط أيام التخزين حسب الفئة والصنف.'},
          {'title': 'تغير تكلفة الشراء', 'value': '—%', 'note': 'مقارنة بآخر شراء', 'icon': Icons.price_change_outlined, 'color': const Color(0xFF2475B8), 'details': 'تغير تكلفة الشراء ومقارنة أسعار الصنف بين الموردين.'},
          {'title': 'أعلى الأصناف مبيعًا', 'value': _executiveTopItems.isEmpty ? '—' : _executiveTopItems.first, 'note': 'أفضل 5: ${_executiveTopItems.take(5).join('، ')}', 'icon': Icons.inventory_2_outlined, 'color': _purple, 'details': 'ترتيب الأصناف حسب صافي الكمية وقيمة المبيعات والربحية خلال الفترة المحددة؛ تظهر النتائج بعد ربط تفاصيل فواتير البيع بالأصناف.'},
          {'title': 'الأصناف الأعلى ربحية', 'value': _executiveTopProfitableItems.isEmpty ? '—' : (_executiveTopProfitableItems.first['name']?.toString() ?? '—'), 'note': _executiveTopProfitableItems.take(5).map((item) => item['name']?.toString() ?? '').where((name) => name.isNotEmpty).join('، ').isEmpty ? 'حسب هامش الربح' : _executiveTopProfitableItems.take(5).map((item) => item['name']?.toString() ?? '').where((name) => name.isNotEmpty).join('، '), 'icon': Icons.trending_up_rounded, 'color': _green, 'details': 'تحليل هامش الربح للصنف بعد تكلفة المبيعات والخصومات والمرتجعات.'},
          {'title': 'مساهمة فئات الأصناف', 'value': _executiveCategorySales.isEmpty ? '—%' : '${_executiveCategorySales.length} فئة', 'note': _executiveCategorySales.take(3).map((item) => '${item['name'] ?? ''}: ${_performanceNumber(item['sales']).toStringAsFixed(0)}').join(' • '), 'icon': Icons.donut_large_rounded, 'color': _orange, 'details': 'توزيع صافي المبيعات والربحية على فئات الأصناف الرئيسية والفرعية.'},
          {'title': 'الأصناف بطيئة الحركة', 'value': '— صنف', 'note': 'تحتاج مراجعة', 'icon': Icons.hourglass_bottom_rounded, 'color': _pink, 'details': 'تحديد الأصناف منخفضة الحركة وربطها بقيمة المخزون والمدة منذ آخر حركة.'},
        ],
      },
      {
        'title': 'الطلبات والتوزيع',
        'icon': Icons.local_shipping_outlined,
        'color': _orange,
        'items': <Map<String, Object>>[
          {'title': 'طلبات قيد التنفيذ', 'value': '${_executiveFulfillmentPendingCount ?? '—'} طلب', 'note': 'في مراحل التشغيل', 'icon': Icons.sync_rounded, 'color': _purple, 'details': 'الطلبات حسب حالة القبول والتجهيز والتحميل والتسليم.'},
          {'title': 'طلبات متأخرة', 'value': '— طلب', 'note': 'تجاوزت الموعد', 'icon': Icons.pending_actions_rounded, 'color': _pink, 'details': 'الطلبات المتأخرة وأسباب التأخير والمسؤول وموعد التسليم المتوقع.'},
          {'title': 'التسليم في الموعد', 'value': '—%', 'note': 'من إجمالي الطلبات', 'icon': Icons.task_alt_rounded, 'color': _green, 'details': 'نسبة التسليم في الموعد ومقارنة أداء الفروع والمندوبين وشركات الشحن.'},
          {'title': 'أداء المندوبين', 'value': '—%', 'note': 'تنفيذ وتحصيل', 'icon': Icons.badge_outlined, 'color': _orange, 'details': 'مبيعات المندوب وتحصيلاته والطلبات المسلمة والمرتجعات.'},
          {'title': 'تكلفة التوزيع', 'value': '— ج.م', 'note': 'لكل طلب / رحلة', 'icon': Icons.route_outlined, 'color': const Color(0xFF2475B8), 'details': 'تكلفة الرحلات والتوصيل مقارنة بقيمة المبيعات وعدد الطلبات.'},
          {'title': 'طلبات ملغاة', 'value': '${_executiveFulfillmentCancelledCount ?? '—'} طلب', 'note': 'من مستندات التجهيز والتسليم', 'icon': Icons.cancel_outlined, 'color': _pink, 'details': 'عدد وقيمة الطلبات الملغاة مع تحليل أسباب الإلغاء.'},
        ],
      },
      {
        'title': 'الموظفون والفروع',
        'icon': Icons.business_outlined,
        'color': _pink,
        'items': <Map<String, Object>>[
          {'title': 'حضور الموظفين', 'value': _executiveAttendanceRate == null ? '—%' : '${_executiveAttendanceRate!.toStringAsFixed(1)}%', 'note': 'من سجلات الحضور بالفترة', 'icon': Icons.groups_outlined, 'color': _green, 'details': 'الحضور والغياب والتأخير والإجازات بحسب الفرع والإدارة.'},
          {'title': 'تكلفة الرواتب', 'value': _executiveMoney(_executivePayrollNetTotal), 'note': 'صافي المسيرات المعتمدة', 'icon': Icons.payments_rounded, 'color': _purple, 'details': 'الرواتب والعمولات والاستقطاعات والسلف والمستحقات.'},
          {'title': 'أداء الفروع', 'value': _executiveBranchSales.isEmpty ? '—' : (_executiveBranchSales.first['name']?.toString() ?? '—'), 'note': _executiveBranchSales.take(3).map((item) => '${item['name'] ?? ''}: ${_performanceNumber(item['sales']).toStringAsFixed(0)}').join(' • '), 'icon': Icons.domain_outlined, 'color': _orange, 'details': 'مقارنة الفروع في المبيعات والربحية والتحصيل والمخزون والمصروفات.'},
          {'title': 'عهد المندوبين', 'value': '— ج.م', 'note': 'قيد التسوية', 'icon': Icons.assignment_ind_outlined, 'color': _pink, 'details': 'العهد النقدية والبضائع المسلمة للمندوبين وما تم تحصيله أو تسويته.'},
        ],
      },
      {
        'title': 'الرقابة والتنبيهات',
        'icon': Icons.fact_check_outlined,
        'color': _purple,
        'items': <Map<String, Object>>[
          {'title': 'بانتظار الاعتماد', 'value': '${_executivePendingApprovalCount ?? '—'} حركة', 'note': 'مسودات البيع والشراء والقيود', 'icon': Icons.approval_rounded, 'color': _orange, 'details': 'المستندات والقيود التي تنتظر الاعتماد مع تاريخ الإنشاء والمسؤول.'},
          {'title': 'ملاحظات الحركات', 'value': '— ملاحظة', 'note': 'تحتاج مراجعة', 'icon': Icons.rule_folder_outlined, 'color': _pink, 'details': 'الحركات التي تحتاج إلى مراجعة أو استكمال بيانات أو تصحيح الربط.'},
          {'title': 'تجاوز الائتمان', 'value': '${_executiveCreditLimitExceededCount ?? '—'} عميل', 'note': 'تجاوز حد الائتمان المسجل', 'icon': Icons.credit_score_outlined, 'color': _orange, 'details': 'العملاء الذين تجاوزوا حدود الائتمان مع الرصيد والحد المعتمد.'},
          {'title': 'اكتمال البيانات', 'value': _executiveDataCompletenessRate == null ? '—%' : '${_executiveDataCompletenessRate!.toStringAsFixed(1)}%', 'note': 'اكتمال الحقول الأساسية للبيانات النشطة', 'icon': Icons.checklist_rounded, 'color': _green, 'details': 'مؤشر اكتمال البيانات الأساسية واكتشاف الحقول الناقصة والمكررة.'},
        ],
      },
    ];

    final visibleSections = _executivePartialConfigured
        ? sections.where((section) => _executiveAllowedSections.contains(section['title'])).toList()
        : sections;
    final allItems = visibleSections.expand((section) => section['items'] as List<Map<String, Object>>).toList();
    final canSales = !_executivePartialConfigured || _executiveAllowedSections.contains('مبيعات');
    final canFinance = !_executivePartialConfigured || _executiveAllowedSections.contains('المالية والسيولة');
    final canInventory = !_executivePartialConfigured || _executiveAllowedSections.contains('المخزون والمشتريات');


    return LayoutBuilder(builder: (context, outerConstraints) {
      final wide = outerConstraints.maxWidth >= 900;
      final mid = outerConstraints.maxWidth >= 600;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9E2F1)),
            boxShadow: const [BoxShadow(color: Color(0x0D3E007D), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9DDF5))),
              child: const Icon(Icons.insights_rounded, color: _purple, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(silsilaText('الملخص التنفيذي'), style: const TextStyle(fontSize: 22, height: 1.15, fontWeight: FontWeight.w900, color: _purple, letterSpacing: -.3))),
                const SizedBox(width: 12),
                SizedBox(
                  width: 250,
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 3.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 3,
                    children: [
                      _executivePeriodCheckbox('السنة السابقة'),
                      _executivePeriodCheckbox('الشهر السابق'),
                      _executivePeriodCheckbox('السنة الحالية'),
                      _executivePeriodCheckbox('الشهر الحالي'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(silsilaText('مركز قيادة الأداء المالي والتشغيلي • مؤشرات وتحليلات موحدة للإدارة'), style: const TextStyle(color: Color(0xFF6D6178), fontSize: 12, height: 1.35)),
              const SizedBox(height: 5),
              Text(_appManagementCompanyId == null ? 'اختر شركة نشطة لعرض المؤشرات الفعلية' : _executiveMetricsLoading ? 'جارٍ تحميل الحركات المرحلة للفترة المحددة…' : _executiveMetricsError != null ? 'تعذر تحميل بعض المؤشرات؛ راجع إعدادات قاعدة البيانات' : 'الفترة المحددة: $_executivePeriod • المؤشرات من الحركات المرحلة', style: const TextStyle(color: Color(0xFFB36B00), fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 12),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'تحديث الملخص',
                onPressed: () { final companyId = _appManagementCompanyId; if (companyId != null) _loadExecutiveMetrics(companyId); },
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5EFFB), foregroundColor: _purple),
                icon: const Icon(Icons.refresh_rounded, size: 24),
              ),
              _summaryAction('كل التحليلات', () => _showExecutiveCategoryDetails('جميع التحليلات', allItems)),
            ]),
          ]),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(builder: (context, constraints) {
          final cards = <Widget>[
            _executiveAnalysisCard(
              title: 'مجمل الربح التقديري',
              icon: Icons.assessment_outlined,
              trend: _executiveChange(_executiveGrossProfit, _executivePreviousGrossProfit),
              rows: [
                _analysisRow('مجمل الربح التقديري', _executiveGrossProfit, _executiveChange(_executiveGrossProfit, _executivePreviousGrossProfit)),
                _analysisRow('التغير عن الفترة السابقة', _executiveChange(_executiveGrossProfit, _executivePreviousGrossProfit), null, isPercent: true),
                _analysisRow('هامش الربح التقديري', _executiveGrossProfit != null && _executiveSales != null && _executiveSales! > 0 ? (_executiveGrossProfit! / _executiveSales! * 100) : null, null, isPercent: true),
              ],
            ),
            _executiveAnalysisCard(
              title: 'صافي المبيعات',
              icon: Icons.point_of_sale_rounded,
              trend: _executiveChange(_executiveSales, _executivePreviousSales),
              rows: [
                _analysisRow('المبيعات', _executiveGrossSales, null),
                _analysisRow('المرتجعات', _executiveSalesReturns, null),
                _analysisRow('صافي مبيعات', _executiveSales, _executiveChange(_executiveSales, _executivePreviousSales)),
              ],
            ),
            _executiveAnalysisCard(
              title: 'صافي المشتريات',
              icon: Icons.shopping_cart_outlined,
              trend: _executiveChange(_executivePurchases, _executivePreviousPurchases),
              rows: [
                _analysisRow('المشتريات', _executiveGrossPurchases, null),
                _analysisRow('المرتجعات', _executivePurchaseReturns, null),
                _analysisRow('صافي مشتريات', _executivePurchases, _executiveChange(_executivePurchases, _executivePreviousPurchases)),
              ],
            ),
            _executiveAnalysisCard(
              title: 'المصروفات',
              icon: Icons.money_off_csred_outlined,
              rows: [
                _analysisRow('إجمالي المصروفات', _executiveExpenses, _executiveChange(_executiveExpenses, _executivePreviousExpenses)),
                _analysisRow('التغير عن الفترة السابقة', _executiveChange(_executiveExpenses, _executivePreviousExpenses), null, isPercent: true),
                _analysisRow('نسبة المصروفات من المبيعات', _executiveSales != null && _executiveSales! > 0 && _executiveExpenses != null ? (_executiveExpenses! / _executiveSales! * 100) : null, null, isPercent: true),
              ],
            ),
            _executiveAnalysisCard(
              title: 'الأصول والإهلاك وصافي الأصول',
              icon: Icons.account_balance_outlined,
              rows: [
                _analysisRow('إجمالي تكلفة الأصول', _executiveFixedAssetsGross, null),
                _analysisRow('مجمع الإهلاك', _executiveFixedAssetsDepreciation, null),
                _analysisRow('صافي القيمة الدفترية', _executiveFixedAssetsNet, null),
              ],
            ),
            _executiveAnalysisCard(
              title: 'التدفقات الداخلة والخارجة',
              icon: Icons.swap_vert_circle_outlined,
              rows: [
                _analysisRow('التدفقات الداخلة', _executiveCashInflows, null),
                _analysisRow('التدفقات الخارجة', _executiveCashOutflows, null),
                _analysisRow('صافي التدفق النقدي', _executiveCashNetFlow, null),
              ],
            ),
          ];

          // Use a shrink-wrapped grid so all six financial analysis cards remain
          // visible inside the dashboard's scrollable workspace on desktop/tablet/mobile.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: constraints.maxWidth >= 700 ? 3 : constraints.maxWidth >= 460 ? 2 : 1,
                childAspectRatio: constraints.maxWidth >= 700 ? .95 : constraints.maxWidth >= 460 ? 1.0 : 1.15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: cards,
              ),
              const SizedBox(height: 12),
              _executiveStaffPerformance(),
            ],
          );
        }),
        const SizedBox(height: 16),
        if ((wide || mid) && (canSales || canFinance || canInventory))
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (canSales) Expanded(child: _executiveChartPanel(
                title: 'اتجاه المبيعات',
                caption: 'آخر 7 أيام • فواتير المبيعات المرحلة',
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
                chart: _ExecutiveDonutPainter(values: <double>[_executiveSales ?? 0, _executivePurchases ?? 0, _executiveCollections ?? 0]),
              )),
            ]),
            const SizedBox(height: 12),
            if (canSales && canFinance && canInventory) _executiveHighlights(),
          ])
        else ...[
          if (canSales) _executiveChartPanel(
            title: 'اتجاه المبيعات',
            caption: 'آخر 7 أيام • فواتير المبيعات المرحلة',
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
            chart: _ExecutiveDonutPainter(values: <double>[_executiveSales ?? 0, _executivePurchases ?? 0, _executiveCollections ?? 0]),
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
          Expanded(child: Text(silsilaText(_appManagementCompanyId == null ? 'لا توجد شركة نشطة مرتبطة؛ لم تُحمّل بيانات فعلية.' : _executiveMetricsLoading ? 'يتم تحميل البيانات الفعلية للفترة المحددة.' : _executiveMetricsError != null ? 'تعذر تحميل بعض المؤشرات من قاعدة البيانات؛ راجع رسالة الخطأ قبل الاعتماد على النتائج.' : 'المؤشرات المعروضة تعتمد على البيانات التي أمكن تحميلها. تظهر الشرطة (—) عند عدم توفر بيانات المؤشر أو عدم ربطه بعد.'), style: TextStyle(fontSize: 11, color: Colors.black54))),
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
    height: 208,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E0EF)),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: _purple, fontWeight: FontWeight.w900))),
        Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 4),
      Text(caption, style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
        footerLabels: _executiveInventoryGroupLabels.take(3).toList(),
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
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E0EF)), boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w900))),
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
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF342B3C), fontWeight: FontWeight.w800, height: 1.2)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black45, height: 1.2)),
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

  Map<String, Object?> _analysisRow(String label, double? value, double? change, {bool isPercent = false}) => <String, Object?>{
    'label': label,
    'value': value,
    'change': change,
    'isPercent': isPercent,
  };

  Widget _executiveKpiCard({
    required String title,
    required double? value,
    required double? change,
    required IconData icon,
    required Color color,
    required String note,
  }) {
    final trendColor = change == null ? Colors.black45 : change >= 0 ? _green : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: .055)],
        ),
        border: Border.all(color: color.withValues(alpha: .42), width: 1.3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .13), blurRadius: 16, offset: const Offset(0, 5)),
          const BoxShadow(color: Color(0x08FFFFFF), blurRadius: 3, offset: Offset(-1, -1)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_executiveMoney(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, color: Color(0xFF241735), fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          ],
        )),
        const SizedBox(width: 6),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: change == null
                    ? [const Color(0xFFB9B0C4), const Color(0xFF766A86)]
                    : change >= 0
                        ? [const Color(0xFF32C58A), const Color(0xFF087A54)]
                        : [const Color(0xFFFF8794), const Color(0xFFCB2944)],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: trendColor.withValues(alpha: .22), blurRadius: 9, offset: const Offset(0, 3))],
            ),
            child: Icon(
              change == null ? Icons.remove_rounded : change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(height: 3),
          Text(change == null ? '—%' : '${change.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: trendColor, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _executiveAnalysisCard({
    required String title,
    required IconData icon,
    required List<Map<String, Object?>> rows,
    double? trend,
  }) {
    final chartRows = rows.where((row) => row['isPercent'] != true).toList();
    final donutRows = chartRows.isEmpty ? rows : chartRows;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF3E007D), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x183E007D), blurRadius: 12, spreadRadius: 0, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 18, color: _purple),
          const SizedBox(width: 6),
          Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.15, fontWeight: FontWeight.w900, color: _purple))),
          if (trend != null) ...[
            const SizedBox(width: 4),
            Icon(
              trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 19,
              color: trend >= 0 ? _green : Colors.red.shade700,
            ),
            const SizedBox(width: 2),
            Text(
              '${trend.abs().toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: trend >= 0 ? _green : Colors.red.shade700,
              ),
            ),
          ],
        ]),
        const Divider(height: 8),
        SizedBox(
          height: 82,
          child: Row(children: [
            SizedBox(width: 82, height: 82, child: CustomPaint(
              painter: _ExecutiveDonutPainter(values: donutRows.map((row) => (row['value'] as num?)?.toDouble() ?? 0).toList()),
            )),
            const SizedBox(width: 8),
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: donutRows.map((row) {
                final value = ((row['value'] as num?)?.toDouble() ?? 0).abs();
                final total = donutRows.fold<double>(0, (sum, item) => sum + (((item['value'] as num?)?.toDouble() ?? 0).abs()));
                final percent = total == 0 ? 0.0 : value / total * 100;
                final label = (row['label'] ?? '').toString();
                return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text(
                  '$label  •  ${percent.toStringAsFixed(1)}%  •  ${_executiveMoney((row['value'] as num?)?.toDouble()).replaceAll(' ج.م', '')}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF51465D)),
                ));
              }).toList(),
            )),
          ]),
        ),
        const Divider(height: 8),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: rows.map((row) {
            final label = row['label']! as String;
            final value = row['value'] as double?;
            final change = row['change'] as double?;
            final isPercent = row['isPercent'] == true;
            final hasData = value != null;
            final positive = change != null && change >= 0;
            final color = change == null ? Colors.black45 : positive ? _green : Colors.red.shade700;
            return Row(children: [
              Expanded(flex: 5, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w900))),
              Expanded(flex: 3, child: Text(
                !hasData ? '—' : isPercent ? '${value.toStringAsFixed(1)}%' : _executiveMoney(value).replaceAll(' ج.م', ''),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87),
              )),
              SizedBox(width: 58, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Icon(change == null ? Icons.remove_rounded : positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: color),
                Text(change == null ? '—%' : '${change.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
              ])),
            ]);
          }).toList(),
        )),
      ]),
    );
  }

  void _goHome() => setState(() {
    _module = 'إعدادات عامة';
    _group = 'بيانات أساسية';
    _page = 'بيانات الشركة';
    _search = '';
    _selectedRecord = null;
  });

  void _open(String module, String group, String page) {
    if (!_canOpenScreen(module, group, page)) return;
    setState(() {
      _module = module;
      _group = group;
      _page = page;
      _search = '';
      _selectedRecord = null;
      _expandedModules.add(module);
      _expandedGroups.add('$module::$group');
    });
    if (page != 'الملخص التنفيذي' && module != 'شئون موظفين' && module != 'موارد بشرية' && !['أصول ثابتة', 'تصنيع', 'مقاولات', 'خدمة ومتابعة وعلاقات عملاء'].contains(module)) _loadWorkspacePage(page);
  }

  Future<void> _loadWorkspacePage(String page, {bool loadMore = false}) async {
    final companyId = _appManagementCompanyId;
    if (companyId == null || companyId.trim().isEmpty ||
        (!loadMore && _cloudLoadedWorkspacePages.contains(page)) ||
        (loadMore && _workspaceHasMore[page] != true) ||
        !_workspacePageLoadsInProgress.add(page)) return;
    final offset = loadMore ? (_workspaceOffsets[page] ?? 0) : 0;
    try {
      final records = await _workspaceRecordsService.listPage(
        companyId: companyId, pageKey: page, offset: offset, pageSize: 500,
      );
      if (!mounted || companyId != _appManagementCompanyId) return;
      setState(() {
        final existing = _saved[page] ?? <Map<String, String>>[];
        _saved[page] = loadMore ? <Map<String, String>>[...existing, ...records] : records;
        _workspaceOffsets[page] = offset + records.length;
        _workspaceHasMore[page] = records.length == 500;
        _cloudLoadedWorkspacePages.add(page);
      });
    } catch (error) {
      if (mounted) _showActionMessage('تعذر تحميل بيانات "$page" من قاعدة البيانات. تأكد من صلاحيات عضوية الشركة. $error');
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

  Widget _workspace() {
    final rows = _rows;
    final loadedCount = (_saved[_page] ?? <Map<String, String>>[]).length;
    final toolbar = _recordToolbar(includeAdd: _group != 'تقارير');
    return ErpScreenFrame(
      title: _page,
      subtitle: '$_module • $_group',
      icon: _iconFor(_module),
      actions: [toolbar],
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      footer: Row(children: [
        Expanded(child: Text('عدد السجلات المعروضة: ${rows.length}')),
        Text('إجمالي السجلات المحمّلة: $loadedCount'),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_group == 'تقارير')
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(
            silsilaText('لم يتم ربط مصدر البيانات الفعلي لهذا التقرير بعد.'),
            style: const TextStyle(color: Colors.black54, height: 1.6),
          )),
        if (_group != 'تقارير')
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF4DF), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFA015))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: Color(0xFF8A4B00), size: 19),
              SizedBox(width: 8),
              Expanded(child: Text(
                'تنبيه مراجعة: هذه شاشة عامة غير مرتبطة حتى الآن بجدول الحركة المتخصص. السجلات هنا تحفظ كسجلات مساحة عمل، ولا تُعد قيودًا محاسبية أو حركات مخزون أو مستندات بيع/شراء معتمدة.',
                style: TextStyle(color: Color(0xFF6D4100), height: 1.45, fontSize: 12, fontWeight: FontWeight.w600),
              )),
            ]),
          )),
        Expanded(child: rows.isEmpty && _page != 'الهيكل الوظيفي'
          ? Center(child: Text(silsilaText('لا توجد نتائج مطابقة.'), textAlign: TextAlign.center))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F0FA)),
                showCheckboxColumn: false,
                columns: [
                  ..._gridKeys.map((k) => DataColumn(label: Text(k, style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)))),
                  const DataColumn(label: Text('إجراءات')),
                ],
                rows: rows.map((r) => DataRow(
                  selected: _selectedRecord != null && _sameRecord(r, _selectedRecord!),
                  onSelectChanged: (selected) => setState(() => _selectedRecord = selected == true ? Map<String, String>.from(r) : null),
                  cells: [
                    ..._gridKeys.map((k) => DataCell(Text(r[k] ?? '—'),
                      onTap: () => setState(() => _selectedRecord = Map<String, String>.from(r)))),
                    DataCell(IconButton(
                      tooltip: 'حذف هذا الصف فقط',
                      onPressed: _isPersistedWorkspaceRecord(r) ? () => _deleteWorkspaceRow(Map<String, String>.from(r)) : null,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)),
                    )),
                  ],
                )).toList(),
              ),
            ),
        ),
        if (_workspaceHasMore[_page] == true || _workspacePageLoadsInProgress.contains(_page))
          Align(alignment: Alignment.center, child: Padding(padding: const EdgeInsets.only(top: 10), child: OutlinedButton.icon(
            onPressed: _workspacePageLoadsInProgress.contains(_page) ? null : () => _loadWorkspacePage(_page, loadMore: true),
            icon: _workspacePageLoadsInProgress.contains(_page)
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.expand_more),
            label: Text(_workspacePageLoadsInProgress.contains(_page) ? 'جارٍ تحميل السجلات...' : 'تحميل 500 سجل إضافي'),
          ))),
      ]),
    );
  }

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

  Widget _pricingPolicyScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('سياسات التسعير والخصومات','حد تسعير الصنف والزيادة أو النقصان وحدود خصم الصنف والفاتورة'),
      Wrap(spacing:12,runSpacing:12,children:[_fieldBox('سعر الصنف الأساسي',_basePriceController),_fieldBox('حد التسعير المعتمد',_priceLimitController),SizedBox(width:220,child:DropdownButtonFormField<String>(itemHeight: 48, value:_pricingMode,decoration:const InputDecoration(labelText:'طريقة التعديل',border:OutlineInputBorder()),items:const ['نسبة','قيمة'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingMode=v??_pricingMode))),SizedBox(width:220,child:DropdownButtonFormField<String>(itemHeight: 48, value:_pricingDirection,decoration:const InputDecoration(labelText:'الاتجاه من حد التسعير',border:OutlineInputBorder()),items:const ['زيادة','نقصان'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingDirection=v??_pricingDirection)),),_fieldBox(_pricingMode=='نسبة'?'نسبة الزيادة / النقصان %':'قيمة الزيادة / النقصان',_priceValueController),_fieldBox('أقصى خصم على إجمالي الفاتورة %',_invoiceDiscountController),_fieldBox('أقصى خصم على مستوى الصنف %',_itemDiscountController)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>_saveWorkspaceSetting('pricing_policy', {'base_price':_basePriceController.text.trim(),'price_limit':_priceLimitController.text.trim(),'mode':_pricingMode,'direction':_pricingDirection,'price_value':_priceValueController.text.trim(),'invoice_discount':_invoiceDiscountController.text.trim(),'item_discount':_itemDiscountController.text.trim()}, successMessage:'تم حفظ سياسة التسعير في قاعدة البيانات.').then((_) {}),icon:const Icon(Icons.save),label:Text(silsilaText('حفظ سياسة التسعير'))),
      const SizedBox(height:8),
      Text(silsilaText('يجب أن يُحسب السعر النهائي من حد التسعير المسجل للصنف، مع منع تجاوز صلاحية المستخدم وحدود الخصم. يلزم ربط الحقول ببيانات الأصناف وقاعدة البيانات قبل تطبيقها على الفواتير.'),style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _transactionRestrictionsScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قيود البيع والشراء','إيقاف البيع أو الشراء أو تحديد الحد حسب الصنف أو الفاتورة أو العميل أو المندوب'),
      Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:220,child:DropdownButtonFormField<String>(itemHeight: 48, value:_restrictionAction,decoration:const InputDecoration(labelText:'الإجراء',border:OutlineInputBorder()),items:const ['إيقاف البيع','إيقاف الشراء','تحديد حد البيع'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionAction=v??_restrictionAction))),SizedBox(width:220,child:DropdownButtonFormField<String>(itemHeight: 48, value:_restrictionTarget,decoration:const InputDecoration(labelText:'مستوى تطبيق القيد',border:OutlineInputBorder()),items:const ['الصنف','الفاتورة الواحدة','العميل','المندوب'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionTarget=v??_restrictionTarget))),_fieldBox('كود الصنف / الفاتورة / العميل / المندوب',_restrictionItem),_fieldBox('العميل (اختياري)',_restrictionCustomer),_fieldBox('المندوب (اختياري)',_restrictionDelegate)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text(silsilaText('إضافة قيد')),content:Text('الإجراء: $_restrictionAction • المستوى: $_restrictionTarget • المعرف: ${_restrictionItem.text}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(silsilaText('إغلاق'))),FilledButton(onPressed:() async {final saved=await _saveWorkspaceSetting('transaction_restrictions', {'action':_restrictionAction,'target':_restrictionTarget,'item':_restrictionItem.text.trim(),'customer':_restrictionCustomer.text.trim(),'delegate':_restrictionDelegate.text.trim()}, successMessage:'تم حفظ إعداد القيد في قاعدة البيانات.');if(saved&&mounted){setState(()=>_activityLog.insert(0,'تم حفظ إعداد قيد: $_restrictionAction / $_restrictionTarget / ${_restrictionItem.text}'));Navigator.pop(ctx);}},child:Text(silsilaText('حفظ الإعداد')))])),icon:const Icon(Icons.block),label:Text(silsilaText('إضافة قيد / إيقاف'))),
      const SizedBox(height:8),
      Text(silsilaText('يتم حفظ إعداد القيد في قاعدة البيانات. يلزم ربط قواعد حفظ وترحيل الفواتير بهذا الإعداد حتى يمنع البيع أو الشراء فعليًا على مستوى الخادم.'),style:TextStyle(color:Colors.black54,height:1.6))]);
  }


  Widget _screenHeading(String title,String subtitle)=>Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:Colors.black54,height:1.5))]));
  Widget _fieldBox(String label,TextEditingController controller)=>SizedBox(width:220,child:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

  Future<void> _openAboutLink(String value) async {
    final uri = Uri.parse(value);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ErpCenterToast.show(context, 'تعذر فتح الرابط. تأكد من وجود التطبيق أو المتصفح المناسب.', isError: true, duration: const Duration(seconds: 3));
      }
    } catch (_) {
      if (!mounted) return;
      ErpCenterToast.show(context, 'تعذر فتح الرابط على هذا الجهاز.', isError: true, duration: const Duration(seconds: 3));
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
      ErpCenterToast.show(context, 'تعذر إنهاء جلسة الدخول: $error', isError: true, duration: const Duration(seconds: 3));
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

class _ExecutiveDonutPainter extends CustomPainter {
  const _ExecutiveDonutPainter({this.values = const <double>[]});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const palette = [_purple, _orange, Color(0xFF18865A), _pink, Color(0xFF4C9BE8)];
    final total = values.fold<double>(0, (sum, value) => sum + (value > 0 ? value : 0));
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = (size.shortestSide * .20).clamp(10.0, 22.0);
    final rect = Rect.fromCircle(center: center, radius: (size.shortestSide - stroke) / 2);
    final basePaint = Paint()
      ..color = const Color(0xFFEFEAF4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 6.28318530718, false, basePaint);
    if (total <= 0) return;
    var start = -1.57079632679;
    for (var i = 0; i < values.length; i++) {
      final value = values[i] > 0 ? values[i] : 0;
      if (value == 0) continue;
      final sweep = value / total * 6.28318530718;
      final paint = Paint()
        ..color = palette[i % palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
    final label = TextPainter(
      text: TextSpan(
        text: '100%',
        style: TextStyle(color: _purple, fontSize: (size.shortestSide * .12).clamp(10.0, 15.0), fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);
    label.paint(canvas, Offset(center.dx - label.width / 2, center.dy - label.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ExecutiveDonutPainter oldDelegate) => oldDelegate.values != values;
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
    final source = values;
    if (source.isEmpty) return;
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
    final source = values;
    if (source.length < 2) return;
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

/// Applies saved Studio visual tokens and density to every ERP page subtree.
class ErpScreenLayoutRuntime extends StatelessWidget {
  const ErpScreenLayoutRuntime({super.key, required this.screen, required this.child});

  final String screen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ErpScreenLayoutProfiles.profiles,
      builder: (context, profiles, _) {
        final raw = profiles[screen] is Map
            ? profiles[screen] as Map
            : profiles['*'] is Map ? profiles['*'] as Map : const {};
        final profile = Map<String, dynamic>.from(raw);
        final themePreset = profile['themePreset'] as String? ?? 'glossy_neon_luxury';
        final buttonStyle = profile['buttonStyle'] as String? ?? 'glossy';
        final tableStyle = profile['tableStyle'] as String? ?? 'glass';
        final treeStyle = profile['treeStyle'] as String? ?? 'neon';
        final headerStyle = profile['headerStyle'] as String? ?? 'glossy';
        final primary = Color((profile['primary'] as int?) ?? const Color(0xFF3E007D).toARGB32());
        final accent = Color((profile['accent'] as int?) ?? const Color(0xFFFF27C3).toARGB32());
        final rowHeight = ((profile['rowHeight'] as num?)?.toDouble() ?? 40).clamp(28, 80).toDouble();
        final radius = ((profile['cornerRadius'] as num?)?.toDouble() ?? 12).clamp(0, 30).toDouble();
        final buttonRadius = buttonStyle == 'pill' ? 28.0 : radius;
        final buttonFill = buttonStyle == 'glass' ? primary.withValues(alpha: .10) : buttonStyle == 'outline' ? Colors.transparent : primary;
        final buttonForeground = buttonStyle == 'glass' || buttonStyle == 'outline' ? primary : Colors.white;
        final base = Theme.of(context);
        final border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: primary.withValues(alpha: .18)),
        );
        final theme = base.copyWith(
          colorScheme: base.colorScheme.copyWith(primary: primary, secondary: accent),
          cardTheme: CardThemeData(
            color: themePreset == 'platinum' ? const Color(0xFFF8F9FC) : Colors.white,
            elevation: themePreset == 'classic' ? 1 : 5,
            shadowColor: accent.withValues(alpha: .22),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius + (themePreset == 'classic' ? 0 : 3)),
              side: BorderSide(color: accent.withValues(alpha: .20)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonFill, foregroundColor: buttonForeground,
              elevation: buttonStyle == 'outline' || buttonStyle == 'glass' ? 0 : buttonStyle == 'neon' ? 9 : 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
              side: buttonStyle == 'neon' ? BorderSide(color: accent.withValues(alpha: .9), width: 1.2) : buttonStyle == 'outline' ? BorderSide(color: primary.withValues(alpha: .8), width: 1.1) : BorderSide.none,
              shadowColor: accent.withValues(alpha: buttonStyle == 'neon' ? .55 : .30),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: buttonFill, foregroundColor: buttonForeground,
              elevation: buttonStyle == 'outline' || buttonStyle == 'glass' ? 0 : buttonStyle == 'neon' ? 8 : 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
              side: buttonStyle == 'neon' ? BorderSide(color: accent.withValues(alpha: .9), width: 1.2) : BorderSide.none,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primary, side: BorderSide(color: accent.withValues(alpha: .75)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius))),
          ),
          dataTableTheme: base.dataTableTheme.copyWith(
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight + 8,
            headingRowHeight: rowHeight,
            columnSpacing: 2,
            headingTextStyle: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12),
            dividerThickness: tableStyle == 'minimal' ? .4 : tableStyle == 'outlined' ? 1.6 : 1,
            decoration: BoxDecoration(
              color: tableStyle == 'glass' ? Colors.white.withValues(alpha: .94) : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: tableStyle == 'neon' ? accent.withValues(alpha: .75) : primary.withValues(alpha: tableStyle == 'outlined' ? .55 : .16), width: tableStyle == 'outlined' ? 1.5 : 1),
              boxShadow: tableStyle == 'neon' ? [BoxShadow(color: accent.withValues(alpha: .14), blurRadius: 14)] : const [],
            ),
          ),
          inputDecorationTheme: base.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: themePreset == 'classic' ? Colors.white : const Color(0xFFFCF9FF),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: accent, width: 1.6)),
            constraints: BoxConstraints(minHeight: rowHeight, maxHeight: rowHeight + 4),
          ),
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: headerStyle == 'minimal' || headerStyle == 'glass' ? Colors.white : primary,
            foregroundColor: headerStyle == 'minimal' || headerStyle == 'glass' ? primary : Colors.white,
            elevation: headerStyle == 'minimal' ? 0 : 5,
            shadowColor: accent.withValues(alpha: .24),
          ),
          expansionTileTheme: base.expansionTileTheme.copyWith(
            tilePadding: EdgeInsets.symmetric(horizontal: treeStyle == 'compact' ? 6 : 12),
            childrenPadding: EdgeInsetsDirectional.only(start: treeStyle == 'nested_cards' ? 18 : 12, end: 8, bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: accent.withValues(alpha: .45))),
            iconColor: primary, collapsedIconColor: primary,
          ),
          listTileTheme: base.listTileTheme.copyWith(
            dense: treeStyle == 'compact',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            minVerticalPadding: spacing,
          ),
        );
        return ErpScreenLayoutScope(screen: screen, profile: profile, child: Theme(data: theme, child: child));
      },
    );
  }
}
