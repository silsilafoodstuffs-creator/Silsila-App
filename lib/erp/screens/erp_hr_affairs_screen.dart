import 'package:flutter/material.dart';
import 'erp_employee_master_screen.dart';
import 'erp_hr_executive_dashboard_screen.dart';
import 'erp_hr_leave_screen.dart';
import 'erp_hr_operations_screen.dart';
import 'erp_hr_records_screen.dart';
import 'erp_hr_catalog_screen.dart';
import 'erp_hr_structure_screen.dart';
import 'erp_payroll_screen.dart';
import 'erp_salary_elements_screen.dart';
import 'erp_sales_targets_commissions_screen.dart';
import 'hr_attendance_rules_screen.dart';

class ErpHrAffairsScreen extends StatelessWidget {
  const ErpHrAffairsScreen({
    super.key,
    required this.page,
    required this.companyId,
    this.canManage = false,
  });

  final String page;
  final String? companyId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (page == 'عمولات المبيعات' || page == 'عمولات المندوبين' || page == 'سياسات العمولة') {
      return ErpSalesTargetsCommissionsScreen(companyId: companyId, initialTabIndex: page == 'سياسات العمولة' ? 2 : 1);
    }
    if (page == 'ملخص إدارة موارد بشرية' || page == 'ملخص تنفيذي الموارد البشرية' || page == 'توزيع القوى العاملة' || page == 'تكلفة العمالة' || page == 'معدل دوران العمالة') {
      return ErpHrExecutiveDashboardScreen(companyId: companyId, canManage: canManage);
    }
    if (page == 'أنواع التوظيف' || page == 'أنواع العقود') {
      return ErpHrCatalogScreen(
        companyId: companyId,
        catalogType: page == 'أنواع التوظيف' ? 'employment_type' : 'contract_type',
        title: page,
      );
    }
    if (page == 'دليل الموظفين' || page == 'بيانات الموظفين' || page == 'ملف الموظف' || page == 'ملفات ومستندات الموظفين' || page == 'كشف العاملين' || page == 'دليل الموظفين حسب الإدارة') {
      return ErpEmployeeMasterScreen(initialCompanyId: companyId);
    }
    if (page == 'الهيكل التنظيمي' || page == 'بيانات الوظائف' || page == 'بيانات الإدارات' || page == 'الوظائف الشاغرة' ||
        page == 'الإدارات والأقسام' || page == 'الوظائف والدرجات' || page == 'المسميات الوظيفية' ||
        page == 'مواقع العمل' || page == 'الهيكل الوظيفي') {
      final tab = page == 'بيانات الإدارات' || page == 'الإدارات والأقسام'
          ? 'بيانات الإدارات'
          : page == 'بيانات الوظائف' || page == 'المسميات الوظيفية' || page == 'الوظائف الشاغرة'
              ? 'بيانات الوظائف'
              : page == 'مواقع العمل'
                  ? 'مواقع العمل'
                  : page == 'الوظائف والدرجات'
                      ? 'درجات الوظائف'
                      : 'الهيكل التنظيمي';
      return ErpHrStructureScreen(
        key: ValueKey('hr-structure-$page-$companyId'),
        initialCompanyId: companyId,
        initialTab: tab,
      );
    }
    if (page == 'الحضور والانصراف' || page == 'كشف الحضور والغياب' || page == 'الحضور والغياب' ||
        page == 'الحضور والغياب والتأخيرات') {
      return ErpHrOperationsScreen(initialCompanyId: companyId);
    }
    if (page == 'الإجازات والأذونات' || page == 'أنواع الإجازات' || page == 'أرصدة الإجازات' || page == 'رصيد الإجازات') {
      return ErpHrLeaveScreen(initialCompanyId: companyId);
    }
    if (page == 'عناصر المرتبات' || page == 'مكونات الأجر' || page == 'المزايا والاستحقاقات' ||
        page == 'سياسات العمولة') {
      return ErpSalaryElementsScreen(companyId: companyId);
    }
    if (page == 'مسير الرواتب' || page == 'صرف الرواتب' || page == 'شريط قبض موظف' ||
        page == 'شريط قبض مجمع' || page == 'مفردات المرتب' || page == 'ملخص الرواتب') {
      return ErpPayrollScreen(initialCompanyId: companyId);
    }
    if (page == 'قواعد الورديات والحضور والانصراف' || page == 'قواعد وسياسات الحضور' ||
        page == 'الورديات وجداول العمل' || page == 'الجداول والورديات' ||
        page == 'سياسات شئون الموظفين') {
      return HrShiftRulesScreen(companyId: companyId);
    }
    return ErpHrRecordsScreen(page: page, companyId: companyId);
  }
}
