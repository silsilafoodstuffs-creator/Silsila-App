# مطابقة صفحات الموارد البشرية الـ81 بالمخطط ومسارات الشاشة — سلسلة ERP
التاريخ: 2026-11-11
المصادر: `erp_dashboard_screen.dart`, `erp_hr_affairs_screen.dart`, `erp_hr_records_screen.dart`، شاشات HR المتخصصة ومستودعات البيانات، وcatalog قاعدة Supabase.

## 1. نتيجة المراجعة
- جرد القائمة الحالي يحتوي **81 ظهورًا** تحت «موارد بشرية» و«شئون موظفين».
- التوجيه الفعلي لا يفتح 81 شاشة مستقلة؛ بل يوزعها على شاشات الموظف/الهيكل/العمليات/الإجازات/الرواتب/عناصر الأجر/الكتالوج/العمولات/لوحة HR، وما تبقى على `ErpHrRecordsScreen`.
- المخطط الفعلي يحتوي جداول متخصصة للتوظيف والعقود والحضور والتدريب والتأمينات والعهد والسلف والجزاءات والتقييمات ونهاية الخدمة والرواتب.
- يوجد View باسم `erp_employee_directory` يقرأ `erp_employees` بعد التحقق من الوصول للشركة؛ يجب أن تظل صلاحياته متوافقة مع نطاق الشركة.
- توجد فجوات توجيه واضحة، فلا يصح إعلان إغلاق HR قبل إصلاحها.

## 2. مطابقة صفحات القائمة الـ81

| رقم القائمة | الصفحة | وجهة التوجيه الحالية | المصدر الفعلي/ملاحظة التصميم |
|---:|---|---|---|
| 190 | ملخص إدارة موارد بشرية | ErpHrExecutiveDashboardScreen | جداول الموظفين والهيكل والحضور والرواتب والتوظيف والتدريب والامتثال؛ يلزم اعتماد مؤشرات خادمية ومصالحتها |
| 191 | بيانات الموظفين | ErpEmployeeMasterScreen | `erp_employees`, `erp_employee_documents`, `erp_hr_jobs`, `erp_hr_departments`, `erp_hr_work_locations` |
| 192 | بيانات الوظائف | ErpHrStructureScreen | `erp_hr_jobs`, `erp_hr_job_grades` |
| 193 | بيانات الإدارات | ErpHrStructureScreen | `erp_hr_departments` |
| 194 | العقود | ErpHrRecordsScreen | `erp_hr_employee_contracts` |
| 195 | أنواع الإجازات | ErpHrLeaveScreen | قائمة نوع الإجازة hard-coded؛ لا تستخدم `erp_hr_reference_catalogs` |
| 196 | قواعد الورديات والحضور والانصراف | HrShiftRulesScreen | يحفظ JSON في `erp_company_settings` بمفتاح `hr_shift_rules`؛ لا يستخدم `erp_hr_shifts` أو `erp_hr_shift_assignments` رغم وجودهما |
| 197 | أجهزة البصمة وربط الحضور | ErpHrRecordsScreen (fallback) | خطأ ترتيب توجيه: شرط `HrFingerprintDevicesScreen` موجود لاحقًا في Dashboard، لكن شرط وحدة HR يسبقه ويلتقط الصفحة أولًا؛ فتسقط داخل HR Affairs إلى fallback `erp_hr_end_of_service_settlements` |
| 198 | عناصر المرتبات | ErpSalaryElementsScreen | `erp_hr_salary_elements` |
| 199 | سياسات العمولة | ErpSalesTargetsCommissionsScreen | `erp_commission_plans`, `erp_commission_tiers` |
| 200 | الحضور والانصراف | ErpHrOperationsScreen | `erp_attendance_records`, `erp_hr_attendance_events`, `erp_hr_fingerprint_devices` |
| 201 | الإجازات والأذونات | ErpHrLeaveScreen | `erp_leave_requests` مع RPC `erp_decide_leave_request` |
| 202 | الجزاءات والمكافآت | ErpHrRecordsScreen | `erp_hr_employee_actions` |
| 203 | السلف | ErpHrRecordsScreen | `erp_hr_employee_advances` |
| 204 | تقييم الأداء | ErpHrRecordsScreen | `erp_hr_performance_reviews` |
| 205 | مسير الرواتب | ErpPayrollScreen | `erp_payroll_runs`, `erp_payroll_lines` |
| 206 | صرف الرواتب | ErpPayrollScreen | `erp_payroll_runs` + RPC الاعتماد والترحيل |
| 207 | عمولات المبيعات | ErpSalesTargetsCommissionsScreen | `erp_sales_representatives`, `erp_commission_runs`, `erp_commission_plans` |
| 208 | تسوية سلفة | ErpHrRecordsScreen | `erp_hr_employee_advances`; يلزم منع التسوية المباشرة دون حركة مالية/خصم رواتب مرتبط |
| 209 | كشف العاملين | ErpEmployeeMasterScreen | `erp_employee_directory` / `erp_employees` |
| 210 | الحضور والغياب | ErpHrOperationsScreen | `erp_attendance_records` |
| 211 | رصيد الإجازات | ErpHrLeaveScreen | فجوة: الشاشة تعرض طلبات الإجازة؛ لا تحسب استحقاقًا/مستخدمًا/مرحلًا/رصيدًا |
| 212 | انتهاء العقود | ErpHrRecordsScreen (read-only) | `erp_hr_employee_contracts`; يلزم تقرير حسب تاريخ القطع والتنبيه |
| 213 | ملخص الرواتب | ErpPayrollScreen | `erp_payroll_runs`, `erp_payroll_lines` |
| 214 | مفردات المرتب | ErpPayrollScreen | `erp_payroll_lines`, `erp_hr_salary_elements` |
| 215 | شريط قبض موظف | ErpPayrollScreen | `erp_payroll_runs`, `erp_payroll_lines`, `erp_employees`; يلزم تحقق خصوصية الموظف |
| 216 | شريط قبض مجمع | ErpPayrollScreen | مسير معتمد فقط؛ نطاق فرع/إدارة وصلاحية تنزيل |
| 217 | عمولات المندوبين | ErpSalesTargetsCommissionsScreen | `erp_commission_runs`, `erp_commission_plans`, `erp_sales_documents` |
| 218 | دليل الموظفين | ErpEmployeeMasterScreen | `erp_employees` وView `erp_employee_directory` |
| 219 | ملفات ومستندات الموظفين | ErpEmployeeMasterScreen | `erp_employee_documents` مع Storage path؛ يلزم سياسات تنزيل ومرفقات |
| 220 | الهيكل التنظيمي | ErpHrStructureScreen | `erp_hr_departments`, `erp_hr_jobs`, `erp_hr_job_grades` |
| 221 | الإدارات والأقسام | ErpHrStructureScreen | `erp_hr_departments` |
| 222 | الوظائف والدرجات | ErpHrStructureScreen | `erp_hr_jobs`, `erp_hr_job_grades` |
| 223 | المسميات الوظيفية | ErpHrStructureScreen | `erp_hr_jobs` |
| 224 | مواقع العمل | ErpHrStructureScreen | `erp_hr_work_locations` |
| 225 | أنواع التوظيف | ErpHrCatalogScreen | `erp_hr_reference_catalogs`، catalog_type=employment_type |
| 226 | أنواع العقود | ErpHrCatalogScreen | `erp_hr_reference_catalogs`، catalog_type=contract_type؛ يلزم مزامنة القيمة مع العقود |
| 227 | أنواع الإجازات | ErpHrLeaveScreen | فجوة توجيه مكررة؛ المطلوب catalog_type=leave_type أو شاشة دليل مستقلة |
| 228 | قواعد وسياسات الحضور | HrShiftRulesScreen | تحفظ JSON في `erp_company_settings`؛ لا تطبق فعليًا على حساب الحضور |
| 229 | الورديات وجداول العمل | HrShiftRulesScreen | الجداول الفعلية `erp_hr_shifts` و`erp_hr_shift_assignments` غير مستخدمة من هذه الشاشة |
| 230 | عناصر المرتبات | ErpSalaryElementsScreen | `erp_hr_salary_elements` |
| 231 | مكونات الأجر | ErpSalaryElementsScreen | `erp_hr_salary_elements` |
| 232 | المزايا والاستحقاقات | ErpSalaryElementsScreen | `erp_hr_salary_elements`؛ يلزم ضبط الطبيعة والقيمة الثابتة/النسبية |
| 233 | سياسات شئون الموظفين | HrShiftRulesScreen | خطأ توجيه: كل سياسات شئون الموظفين تفتح محرر الورديات |
| 234 | طلبات التوظيف | ErpHrRecordsScreen | `erp_hr_recruitment_candidates` |
| 235 | إدارة المرشحين | ErpHrRecordsScreen | `erp_hr_recruitment_candidates` |
| 236 | المقابلات والتقييم | ErpHrRecordsScreen | `erp_hr_recruitment_candidates`؛ المقابلات حقول داخل المرشح وليست أحداث مقابلات متعددة |
| 237 | عروض العمل | ErpHrRecordsScreen | `erp_hr_recruitment_candidates`؛ العرض جزء من سجل المرشح |
| 238 | التعيينات ومباشرة العمل | ErpHrRecordsScreen | `erp_hr_employee_movements`؛ يلزم تحويل مرشح مقبول إلى موظف دون تكرار |
| 239 | فترة الاختبار | ErpHrRecordsScreen | `erp_hr_employee_movements`؛ لا يوجد سجل متابعة فترة اختبار مستقل |
| 240 | نقل وندب الموظفين | ErpHrRecordsScreen | `erp_hr_employee_movements` |
| 241 | الترقيات والتغييرات الوظيفية | ErpHrRecordsScreen | `erp_hr_employee_movements` |
| 242 | الحضور والانصراف | ErpHrOperationsScreen | `erp_attendance_records` |
| 243 | الجداول والورديات | HrShiftRulesScreen | JSON settings حاليًا؛ المطلوب `erp_hr_shifts` + `erp_hr_shift_assignments` |
| 244 | الإجازات والأذونات | ErpHrLeaveScreen | `erp_leave_requests` |
| 245 | طلبات العمل الإضافي | ErpHrRecordsScreen | `erp_hr_overtime_requests`؛ يلزم ربط الاعتماد بمسير الرواتب |
| 246 | السلف | ErpHrRecordsScreen | `erp_hr_employee_advances` |
| 247 | الجزاءات والمكافآت | ErpHrRecordsScreen | `erp_hr_employee_actions`؛ يلزم قيد/عنصر راتب عند التطبيق |
| 248 | تقييم الأداء | ErpHrRecordsScreen | `erp_hr_performance_reviews` |
| 249 | إدارة العقود وتجديدها | ErpHrRecordsScreen | `erp_hr_employee_contracts` |
| 250 | إنهاء الخدمة وإخلاء الطرف | ErpHrRecordsScreen | `erp_hr_employee_movements`؛ يلزم checklist إخلاء طرف وربط التسوية |
| 251 | تسويات نهاية الخدمة | ErpHrRecordsScreen | `erp_hr_end_of_service_settlements` |
| 252 | متابعة عهد الموظفين | ErpHrRecordsScreen | `erp_hr_employee_custodies` |
| 253 | كشف العاملين | ErpEmployeeMasterScreen | `erp_employee_directory` |
| 254 | دليل الموظفين حسب الإدارة | ErpEmployeeMasterScreen | `erp_employee_directory`; يلزم فلتر إدارة وتصدير مضبوط |
| 255 | توزيع القوى العاملة | ErpHrExecutiveDashboardScreen | `erp_employees`, `erp_hr_departments`, `erp_hr_jobs`, `erp_hr_staffing_plans` |
| 256 | الوظائف الشاغرة | ErpHrRecordsScreen | خطأ توجيه/نموذج: شرط `الوظائف الشاغرة` يضعها ضمن `erp_hr_recruitment_candidates` بدل `erp_hr_staffing_plans` و`erp_hr_jobs` |
| 257 | طلبات التوظيف ومراحل الاختيار | ErpHrRecordsScreen | `erp_hr_recruitment_candidates` |
| 258 | تقرير المقابلات | ErpHrRecordsScreen (read-only) | `erp_hr_recruitment_candidates`; لا يوجد سجل مقابلات متعدد الأحداث |
| 259 | الحضور والغياب والتأخيرات | ErpHrOperationsScreen | `erp_attendance_records`, `erp_hr_attendance_events` |
| 260 | ساعات العمل الإضافية | ErpHrRecordsScreen (read-only) | `erp_hr_overtime_requests` |
| 261 | أرصدة الإجازات | ErpHrLeaveScreen | فجوة: الطلبات لا تساوي دفتر رصيد الإجازات |
| 262 | حركة التعيينات وترك الخدمة | ErpHrRecordsScreen (read-only) | `erp_hr_employee_movements` |
| 263 | معدل دوران العمالة | ErpHrExecutiveDashboardScreen | `erp_employees`, `erp_hr_employee_movements`; يلزم تحديد متوسط القوى العاملة وتعريف الفترة |
| 264 | انتهاء وتجديد العقود | ErpHrRecordsScreen (read-only) | `erp_hr_employee_contracts` |
| 265 | تقرير السلف | ErpHrRecordsScreen (read-only) | `erp_hr_employee_advances` |
| 266 | تقرير الجزاءات والمكافآت | ErpHrRecordsScreen (read-only) | `erp_hr_employee_actions` |
| 267 | تقييمات الأداء | ErpHrRecordsScreen (read-only) | `erp_hr_performance_reviews` |
| 268 | تكلفة العمالة | ErpHrExecutiveDashboardScreen | `erp_payroll_runs`, `erp_payroll_lines`, `erp_employees`; يلزم فصل التكلفة المستحقة والمرحلة |
| 269 | ملخص الرواتب | ErpPayrollScreen | `erp_payroll_runs`, `erp_payroll_lines` |
| 270 | مفردات المرتب | ErpPayrollScreen | `erp_payroll_lines`, `erp_hr_salary_elements` |

## 3. جداول HR الحقيقية وعلاقاتها
| المجال | الجداول/العروض |
|---|---|
| الموظفون والملفات | `erp_employees`, `erp_employee_directory` (View), `erp_employee_documents` |
| الهيكل | `erp_hr_departments`, `erp_hr_jobs`, `erp_hr_job_grades`, `erp_hr_work_locations`, `erp_hr_staffing_plans` |
| التوظيف والحركات | `erp_hr_recruitment_candidates`, `erp_hr_employee_movements` |
| العقود والامتثال | `erp_hr_employee_contracts`, `erp_hr_employee_compliance` |
| التدريب والتقييم | `erp_hr_training_records`, `erp_hr_performance_reviews` |
| الحضور والبصمة | `erp_attendance_records`, `erp_hr_attendance_events`, `erp_hr_fingerprint_devices` |
| الورديات | `erp_hr_shifts`, `erp_hr_shift_assignments` |
| الإجازات | `erp_leave_requests` |
| الأجر والرواتب | `erp_hr_salary_elements`, `erp_payroll_runs`, `erp_payroll_lines` |
| السلف والعهد والإجراءات | `erp_hr_employee_advances`, `erp_hr_employee_custodies`, `erp_hr_employee_actions`, `erp_hr_overtime_requests` |
| نهاية الخدمة | `erp_hr_end_of_service_settlements` |
| إعدادات الشركة | `erp_company_settings`؛ تستخدمها شاشة الورديات حاليًا لتخزين JSON |
| كتالوج HR | `erp_hr_reference_catalogs`؛ تستخدمه الشاشة حاليًا لأنواع التوظيف والعقود فقط |

## 4. فجوات التصميم الحرجة التي يجب إغلاقها
1. **أجهزة البصمة وربط الحضور** لا تصل إلى شاشة الأجهزة؛ بل تسقط إلى نموذج HR عام، والـfallback الافتراضي هو تسوية نهاية الخدمة. يجب توجيهها إلى شاشة إدارة الأجهزة/المزامنة.
2. **الوظائف الشاغرة** تذهب إلى نموذج المرشحين؛ يجب أن تقرأ `erp_hr_staffing_plans` مع الوظائف والعدد المعتمد والإشغال.
3. **أنواع الإجازات** تفتح شاشة طلبات الإجازة بقائمة hard-coded، وليس دليل أنواع إجازات.
4. **أرصدة الإجازات** تفتح شاشة طلبات فقط؛ لا توجد معادلة رصيد معتمدة في الشاشة. يجب تعريف الرصيد الافتتاحي والاستحقاق والتجميع والترحيل والمستخدم والحجز.
5. **قواعد الورديات** تحفظ في `erp_company_settings.setting_value` JSON تحت `hr_shift_rules`، رغم وجود `erp_hr_shifts` و`erp_hr_shift_assignments`. كما أن الشاشة تصرح بأن القواعد لا تطبق على الرواتب قبل الربط. يجب جعل الجداول المعيارية مصدر الحقيقة وربطها بمحرك الحضور والرواتب.
6. **سياسات شئون الموظفين** تفتح محرر الورديات؛ يجب أن تكون شاشة سياسات منفصلة عن إعداد الوردية.
7. **فترة الاختبار** ممثلة ضمن حركة الموظف ولا توجد متابعة فترة اختبار/تقييم/قرار تثبيت أو تمديد.
8. **المقابلات** مخزنة كحقول على المرشح؛ لا يوجد interview event متعدد الجولات أو أعضاء لجنة ومرفقات ونتائج منفصلة.
9. **العروض الوظيفية** حقول داخل المرشح؛ يلزم سجل عرض مستقل إذا كان هناك إصدار/تعديل/قبول/رفض/انتهاء.
10. **الإجازات** تحتسب أيامًا تقويمية شاملة في `ErpHrRepository.createLeaveRequest`؛ يلزم تحديد هل تُحسب أيام العمل فقط وفق الوردية والعطلات وسياسة النوع.
11. **تسوية السلفة** لا يجب أن تكون تعديلًا مباشرًا لحقل `settled_amount` فقط؛ يجب أن تنشئ حركة مالية/استقطاع راتب مرتبطة بالسلفة.
12. **إضافة الموظف** تمر بمسار منفصل وتستخدم كودًا مولدًا؛ يجب توحيد الملف الوظيفي والتعيين والعقد والوثائق والتأمينات ومنع التكرار.
13. **سجلات HR الحساسة** (الراتب، الرقم القومي، التأمين، الجزاءات، التقييم) تحتاج فصل صلاحية الحقل/السجل عن صلاحية فتح الشاشة، مع نطاق الشركة والفرع والموظف.
14. **لوحة HR** لا تعتمد على تجميعات Flutter غير المقيدة؛ المؤشرات المالية والعددية يجب أن تأتي من RPC/View خادمي مع نطاق صلاحية ومصالحة.

## 5. قرار التصميم النهائي المقترح
- إنشاء Route Registry صريح لكل صفحة HR وعدم استخدام fallback صامت إلى `erp_hr_end_of_service_settlements`.
- إضافة صفحات مستقلة/تبويبات صحيحة للأجهزة، الوظائف الشاغرة، أنواع الإجازات، أرصدة الإجازات، وسياسات شئون الموظفين.
- توحيد الورديات في `erp_hr_shifts` وتوزيع الموظفين عبر `erp_hr_shift_assignments`; ترحيل JSON القديم عند الربط دون فقد بيانات.
- تعريف دفتر أرصدة إجازات/حركات رصيد، وسجل مقابلات وعروض وظيفية، وفترة اختبار، وتسوية سلفة مالية مترابطة.
- كل اعتماد/صرف/ترحيل يتم عبر RPC خادمي، ولا تُعتبر أزرار الموافقة في Flutter ضمانًا للصلاحية.
- تقارير الرواتب والحضور والتقييم والامتثال تعرض فقط البيانات المصرح بها، وتطبق نفس نطاقات RLS على التصدير والطباعة.

## 6. حدود المراجعة
هذه مطابقة من الكود والـcatalog. لم يتم تعديل مسارات Flutter أو SQL أو بيانات HR. لم يتم اختبار اتصال أجهزة البصمة أو تنفيذ رواتب/إجازات تجريبية، ولم يتم تشغيل الاختبار الشامل.


### تصحيح ترتيب شرط أجهزة البصمة
في `erp_dashboard_screen.dart` يوجد شرط مباشر لفتح `HrFingerprintDevicesScreen`، لكنه يأتي بعد شرط `_module == 'شئون موظفين' || _module == 'موارد بشرية'`. لذلك لا يصل التنفيذ إلى شرط الأجهزة عند اختيار الصفحة من وحدة HR؛ إذ يتم التقاطها أولًا بواسطة `ErpHrAffairsScreen`. يجب نقل شرط الأجهزة قبل شرط الوحدة أو توجيهه صراحة داخل `ErpHrAffairsScreen`.
