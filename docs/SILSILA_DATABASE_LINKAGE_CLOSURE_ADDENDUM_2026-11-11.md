# ملحق تنفيذ ربط قاعدة البيانات — 2026-11-11

الفرع: `main`  
قاعدة Supabase: `teitsopmhruczplwlwgn`  
هذا الملحق يسجل ما طُبق فعليًا في دفعة استكمال نطاق البيانات. لا يُعد إغلاقًا نهائيًا لمرحلة الربط أو اختبار قبول.

## 1. ترحيلات نطاق الفروع والمخازن والموظفين والخزائن

تم تطبيق الترحيلات التالية على قاعدة البيانات الحية، وتسجيلها في `supabase_migrations.schema_migrations`، ورفع ملفات SQL المطابقة إلى المستودع:

- `20261111015733_enforce_branch_warehouse_employee_and_cashbox_scope`
- `20261111015846_refine_nullable_branch_scope_and_cash_voucher_scope`
- `20261111015949_scope_cash_movements_to_vouchers_and_creator`

### التغطية المطبقة

1. أضيفت الدالة `erp_user_can_access_employee_scope(company_id, employee_id)`:
   - ترفض السياق غير المسجل.
   - تسمح للمالك ومدير الشركة بنطاق الشركة.
   - للمستخدمين الآخرين تتحقق من وجود الموظف في الشركة ومن أن فرعه له تخصيص مسموح للمستخدم.
   - لا تمنح نطاقًا لموظف بلا فرع للمستخدم غير الإداري؛ يجب إسناد الفرع قبل إتاحة سجلاته.

2. أضيفت سياسات RLS من نوع RESTRICTIVE تشمل القراءة والإضافة والتعديل والحذف، لا مجرد سياسات permissive إضافية:
   - 42 جدولًا فعليًا تحمل `company_id` مع `branch_id` أو `warehouse_id` أو `employee_id`.
   - بعد إضافة السياسة الخاصة بحركات النقدية أصبح عدد سياسات النطاق المسجلة بالبادئة `erp_scope_guard_` هو 43.
   - تشمل التغطية مستندات البيع والشراء والجرد وحركات المخزون وأرصدة/حجوزات المخزون وإعدادات المخازن وسجلات الموظفين والحضور والرواتب والعهد والوثائق والورديات، إلى جانب الفروع والمخازن والخزائن وطرق الدفع المرتبطة بخزينة.
   - الصف الذي يجمع الفرع والمخزن يجب أن يمر من تحقق النطاقين؛ والصف الذي يكون فرعه فارغًا يمكنه إثبات النطاق من المخزن أو الموظف المرتبط حيث يتاح ذلك.

3. الخزائن وطرق الدفع والسندات:
   - طرق الدفع ترث نطاق الخزينة المرتبطة بها.
   - سندات القبض/الصرف تقبل نطاق الفرع الصريح أو نطاق خزينة المصدر/الوجهة.
   - حركات النقدية المرتبطة بسند ترث نطاق السند؛ الحركة غير المرتبطة بسند تقتصر على منشئها أو المالك/مدير الشركة.

4. تم الحفاظ على صلاحيات المالك ومدير الشركة، ولم تُسحب صلاحيات تشغيلية جماعية من دوال RPC.

### تحقق بنيوي

- سجل الترحيلات يعرض الإصدارات الثلاثة أعلاه.
- استعلام `pg_policies` أكد وجود 43 سياسة نطاق.
- تمت مراجعة صيغة السياسات بعد أول تطبيق وتصحيح حالة السجلات ذات `branch_id` الفارغ، ثم أضيفت حماية خاصة لسندات وحركات النقدية.
- هذا تحقق بنيوي من تعريف السياسات وليس اختبار RLS/IDOR بمستخدمين فعليين أو اختبار CRUD على كل جدول.

## 2. مراجعة SECURITY DEFINER والإعلانات العامة

آخر جرد metadata أظهر:
- 93 دالة `SECURITY DEFINER` إجمالًا في schema public.
- 53 دالة قابلة للتنفيذ من `authenticated`.
- 3 دوال قابلة للتنفيذ من `anon`: `get_silsila_public_ads`, `get_silsila_public_intro_ad`, `get_silsila_public_popup_ads`.

المراجعة البنيوية للدوال المتاحة للمصادق:
- دوال الإدارة العامة تتحقق من `auth.uid()` ودور admin.
- مسارات ERP الأساسية تستخدم `erp_user_has_company_role` أو تحققًا مباشرًا من الدور/الشركة.
- `erp_add_operational_document_lines_v2` لا يكرر فحص الهوية في جسمه، لكنه يستدعي `erp_add_operational_document_line_v2` لكل سطر، والدالة الداخلية تتحقق من عضوية الشركة والدور وحالة المستند والصنف والوحدة.
- دوال الإعلانات الثلاث مخصصة للـfeed العام وتعيد حقول الإعلان المحددة فقط؛ لذلك بقيت صلاحية anon مقصودة ولم تُسحب حتى لا يتعطل تحميل الإعلانات العامة.

هذه مراجعة static/metadata وتصنيف للمسارات، وليست إثباتًا لاختبار كل فرع تنفيذي أو كل محاولة IDOR. ما زال Security Advisor يعرض تحذيرات SECURITY DEFINER الثلاث العامة و53 الدالة المتاحة للمصادق. لا يجوز إخفاء التحذير باعتباره محلولًا أو سحب الصلاحيات بالجملة. كما يظهر تحذير INFO لجدولي أرشيف/نسخة احتياطية بلا سياسات؛ ACL الحالي يقصرهما على أدوار الخادم ولا يمنح anon/authenticated.

## 3. الفجوات التي لا تزال تمنع إغلاق الربط

### أ. Business Suite save غير ذري

الشاشة `erp_business_suite_screen.dart` تستدعي `_syncOperationalRecord` أولًا، وهذه الدالة تنفذ مزامنة في جداول تشغيلية متخصصة، ثم تحفظ الشاشة السجل العام في `erp_business_suite_records`. إذا نجحت المزامنة التشغيلية وفشل حفظ السجل العام فقد تبقى بيانات تشغيلية دون projection مطابق.

لم يتم إنشاء RPC تخمينية لهذا المسار؛ فالمزامنة تشمل أنواعًا تشغيلية متعددة وآثارًا جانبية مختلفة (مثل سطور BOM وفحص الجودة وأحداث التذاكر)، ويلزم نقلها كمعاملة واحدة مع allowlist وعقود payload لكل نوع. الحفظ الذري الكامل ما زال مفتوحًا.

### ب. مركز التقارير

- خريطة `_sources` تحتوي 52 مفتاح تقرير.
- 14 اسم تقرير في شرط التوجيه لا يملك مدخلًا في الخريطة.
- القارئ الحالي يقرأ أول مصدر ناجح بـ`select('*')`، ولا يدمج المصادر المتعددة ولا ينفذ معادلات القاموس أو المصالحة.
- لم تُضف مصادر خام لهذه التقارير لمجرد إزالة رسالة «غير مربوط»؛ ذلك قد يعرض بيانات غير محسوبة تحت اسم تقرير مالي/تشغيلي مضلل.
- المطلوب لكل تقرير View/RPC محسوبة مع فلاتر الفترة والنطاق وتجميع ومصالحة وصلاحيات وتصدير مطابق.

### ج. نطاق المشروعات

الجداول التالية تحمل `project_id` فقط ولا تحمل فرعًا أو مخزنًا أو موظفًا يتيح تطبيق helper الحالي مباشرة:
- `erp_construction_boq_lines`
- `erp_construction_costs`
- `erp_construction_material_requests`
- `erp_construction_payment_certificates`
- `erp_construction_site_reports`

كما أن `erp_construction_projects` لا يحتوي حاليًا على `branch_id` أو علاقة تخصيص مستخدم/مشروع. لا توجد بنية موثقة لتخصيص المشروع للمستخدم. لذلك لم أضع سياسة تمنع الوصول إلى هذه السجلات عشوائيًا أو أربطها بمدير المشروع النصي؛ نطاق المشروعات ما زال مفتوحًا ويتطلب إضافة علاقة مشروع-فرع/مستخدم ثم ربط واجهة التخصيص.

### د. الفاتورة الإلكترونية

قاعدة البيانات تحتوي إعدادات وعمليات الفاتورة الإلكترونية، لكن قائمة Edge Functions النشطة الحالية لا تحتوي موصلًا باسم أو وظيفة خاصة بالفاتورة الإلكترونية؛ الوظائف الموجودة تخص صور الكتالوج. لا يوجد إثبات اتصال حقيقي بالهيئة أو مصافحة أو إرسال فاتورة اختبارية وقبولها. هذا البند لا يمكن اعتباره مكتملًا دون اعتماد/شهادة وبيانات بيئة اختبار واتصال فعلي.

## 4. ما لم يتم تشغيله عمدًا

وفق ترتيب المستخدم (التصميم ثم الربط ثم الاختبار مرة واحدة)، لم يتم تشغيل:
- Dart analyze
- Flutter test
- Web build
- Android debug APK
- WebView/Smoke
- اختبار قبول RLS/IDOR شامل أو سيناريوهات CRUD على كل شاشة

لا تسجل هذه البنود على أنها ناجحة أو فاشلة؛ لم تُشغّل ضمن هذه الدفعة.

## 5. الحالة

| المجال | ما ثبت في هذه الدفعة | الحالة المتبقية |
|---|---|---|
| نطاق الفرع/المخزن/الموظف | 42 جدولًا مغطى بسياسات RESTRICTIVE، مع 43 سياسة نطاق إجمالًا بعد سياسة حركات النقدية | اختبارات RLS/IDOR فعلية؛ جداول مساحة العمل التي لا تحمل company_id؛ نطاق المشروعات |
| الخزائن والنقدية | ربط نطاق طرق الدفع والخزائن والسندات والحركات بالفرع/الخزينة | مصالحة كل مصادر النقدية والشيكات والتحويلات مع كل المسارات |
| SECURITY DEFINER | جرد 93؛ تصنيف 53 للمصادق و3 عامة | مراجعة دلالية واختبارات قبول لكل دالة؛ معالجة تحذيرات advisor حسب الحاجة دون كسر الوظائف |
| Business Suite | الحذف ذري من دفعة سابقة | الحفظ/المزامنة ما زال غير ذري |
| التقارير | جرد المصادر والـ14 اسمًا غير المسجل | 52 قارئًا خامًا لا تمثل تقارير محسوبة؛ المعادلات والمصالحة غير مغلقة |
| الفاتورة الإلكترونية | جداول الإعدادات والعمليات موجودة | لا يوجد إثبات اتصال/اعتماد فعلي بالهيئة |

**لا توجد نسبة 100% لمرحلة الربط يمكن إثباتها حتى الآن.** إغلاق التصميم 100% يظل خاصًا بالمواصفات. مرحلة الربط ما زالت مفتوحة بسبب البنود الموضحة أعلاه، والاختبار الشامل لم يبدأ.


## 6. استكمال نطاق المشروعات — 2026-11-11

تم تطبيق الترحيل `20261111021659_add_project_user_scope_assignments_and_rls` على Supabase ورفع ملفه المطابق إلى `main`.

- جدول تخصيص صريح `erp_user_project_access` يربط الشركة والمشروع ومستخدم ERP وحالة السماح.
- الدالة `erp_user_can_access_project_scope(company_id, project_id)` لا تسمح بالوصول للمستخدم العادي إلا بتخصيص صريح؛ المالك ومدير الشركة يحتفظان بنطاق الشركة.
- RPC `erp_replace_user_project_access` تستبدل تخصيصات مستخدم واحد ذريًا، وتتحقق من دور المنفذ ونشاط المستخدم وتبعية كل مشروع للشركة وعدم تكرار المشروع.
- Trigger يمنح منشئ المشروع تخصيصًا تلقائيًا إذا كان مرتبطًا بمستخدم ERP نشط.
- أضيفت 13 سياسة RLS تقييدية مرتبطة بالمشروع: سياسة لكل من عمليات SELECT/INSERT/UPDATE/DELETE على سجل المشروع، وسياسات على جداول المشروع المباشرة والسطور التابعة للمستخلصات وطلبات المواد.
- جداول السطور التابعة التي لا تحمل `project_id` ترث النطاق من المستخلص أو طلب المواد الأب.
- تحقق metadata بعد التطبيق: 13 سياسة مشروع، 43 سياسة فرع/مخزن/موظف/نقدية، صفر مشروعات قائمة، وصفر تخصيصات مشروع قائمة. لم تُنشأ بيانات تشغيلية تجريبية.
- لم يكتمل بعد ربط واجهة إدارة المستخدمين لتعديل تخصيصات المشروعات؛ RPC والجدول جاهزان لكن إدارة التخصيص من الواجهة تحتاج إضافة تبويب واضح. كما لم ينجح تشغيل اختبار SQL بمحاكاة JWT عبر أداة التنفيذ (رفضته فحوص الأمان)، لذلك التحقق الحالي بنيوي فقط، وليس اختبارًا سلوكيًا بمستخدمين فعليين.

## 7. تحسين تحميل التقارير متعددة المصادر

تم تحديث `lib/erp/screens/erp_report_center_screen.dart` بحيث:
- يحمل كل المصادر المعرفة للتقرير بدل التوقف عند أول جدول ينجح.
- يضيف `_source_table` لكل صف لتمييز الجدول الأصلي.
- يدير ترقيم الصفحات لكل مصدر مستقلًا، حتى لا تتوقف الدفعات عند مصدر واحد.
- يبقي الشاشة معلنة صراحة أنها قارئ بيانات مصدرية، وليست تقريرًا ماليًا محسوبًا.

هذا يغلق نقص قراءة المصدر الثاني والثالث في التقارير متعددة المصادر، لكنه **لا** يحول القارئ الخام إلى معادلات تقارير. الأسماء الأربعة عشر التي لا تزال بلا مصدر في خريطة القارئ هي:
`تقرير استهلاك API`، `تقرير أخطاء التكامل`، `الأصناف الراكدة`، `الأصناف قاربت على النفاد`، `تنبيهات إعادة الطلب`، `مقارنة أسعار الموردين`، `تكلفة خطوط السير`، `شريط قبض موظف`، `شريط قبض مجمع`، `تكلفة الحملات`، `معدل الاستجابة`، `التذاكر المفتوحة`، `زمن الاستجابة`، `رضا العملاء`.
بعض هذه العناصر قد يكون له شاشة متخصصة في مسار آخر، لكن لا يوجد له مدخل في خريطة قارئ التقارير العامة. لا يجوز ربطه بجدول قريب بالاسم دون إثبات المعادلة والمصدر الصحيح.

## 8. تحديث Security Advisor بعد دفعة المشروع

آخر فحص Security Advisor بعد ترحيل المشروعات أظهر:
- 55 دالة SECURITY DEFINER قابلة للتنفيذ من `authenticated`.
- 3 دوال عامة قابلة للتنفيذ من `anon`، وهي دوال الإعلانات الثلاث.
- تحذير حماية كلمات المرور المسرّبة ما زال قائمًا.
- إشعار INFO لجدولي الأرشيف والنسخة الاحتياطية بلا سياسات RLS؛ صلاحياتهما المباشرة مقيدة لأدوار الخادم حسب المراجعة السابقة.

العدد ارتفع من 53 إلى 55 لأن دالة التحقق من نطاق المشروع وRPC إدارة التخصيص أصبحا قابلين للتنفيذ من المستخدم المسجل. لا يعني ذلك أنهما ثغرتان؛ لكنهما ضمن قائمة المراجعة الدلالية والاختبار.

## 9. الحالة المحدثة

| المجال | الحالة بعد الدفعة الجديدة |
|---|---|
| نطاق الفروع والمخازن والموظفين والخزائن | 43 سياسة نطاق بنيوية؛ اختبار RLS/IDOR الشامل لم يكتمل |
| نطاق المشروعات | نموذج تخصيص + RPC + 13 سياسة؛ واجهة إدارة التخصيص واختبار JWT الفعلي متبقيان |
| مركز التقارير | كل المصادر المعرفة تُقرأ وتُدمج؛ 14 تقريرًا بلا مدخل في الخريطة، والمعادلات المحاسبية/التشغيلية غير مغلقة |
| Business Suite | ما زال الحفظ التشغيلي والسجل العام خارج معاملة واحدة |
| SECURITY DEFINER | 55 authenticated + 3 anon؛ لا يزال الفحص الدلالي واختبار كل endpoint مطلوبًا |
| الفاتورة الإلكترونية | لا يوجد اتصال هيئة مثبت أو إرسال/قبول تجريبي |

لم يتم تشغيل Dart Analyze أو Flutter Test أو Web Build أو Android APK أو WebView/Smoke؛ هذه تظل مرحلة الاختبار النهائية المؤجلة.


## 10. Project access UI closure and database audit — 2026-11-11

- Added the authorized read RPC `erp_get_user_project_access(company_id, user_id)`. It requires an authenticated owner/admin/manager, verifies the target ERP user is active and belongs to the same company, and returns the company's projects with the target user's effective allow flag.
- The RPC is `SECURITY DEFINER`, uses an empty `search_path`, disables row security only inside the function, revokes execution from `PUBLIC` and `anon`, and grants execution only to `authenticated`.
- Added a project-assignment picker to `erp_user_admin_screen.dart` in both hierarchy and user-grid views. It reads through the authorized RPC and persists the full selection through the existing atomic `erp_replace_user_project_access` RPC. Empty selection clears the user's project assignments.
- Applied migration version `20261111022227` (migration name `20261111024500_add_project_access_read_rpc`). Repository migration filename is `20261111022227_20261111024500_add_project_access_read_rpc.sql`.
- Current project data count remains zero, and no user-project assignments exist. Therefore the new assignment flow is implemented but cannot be behaviorally verified against a real project/user pair without creating test data; no test data was inserted.
- Database metadata audit: all public tables have RLS enabled (0 exceptions); all public views report `security_invoker=true` (0 exceptions).
- SECURITY DEFINER inventory: 97 total functions, 56 executable by `authenticated`, 3 executable by `anon` (the three public ad-feed RPCs). Twelve authenticated-executable functions do not contain a direct `auth.uid()` reference; the reviewed document-line, price-list, payroll, document-posting and password functions delegate authorization to `erp_user_has_company_role`. This static check is not a substitute for full per-function adversarial testing.
- Supabase Security Advisor continues to report leaked-password protection disabled. It also reports callable SECURITY DEFINER functions as findings; many are deliberate authenticated RPC endpoints with role checks. Leaked-password protection requires enabling the Auth setting in project configuration.
- No Dart analyze, Flutter tests, Web build, APK, WebView or smoke tests were run in this linkage pass, in accordance with the requested single final test phase.


## 11. Payroll payslip report source views — 2026-11-11

- Added `erp_v_employee_payslips`: one row per employee/payroll line, joining payroll runs, payroll lines and employee master data; only approved, posted or paid payroll runs are included.
- Added `erp_v_payroll_payslip_summary`: totals grouped by payroll run, branch and department, including employee count, basic pay, allowances, commissions, overtime, deductions, gross and net.
- Both views use PostgreSQL `security_invoker=true`, so underlying RLS policies on payroll runs, payroll lines and employees remain effective. SELECT is granted to authenticated; no SECURITY DEFINER bypass was added.
- Registered both views in the generic report reader and added search columns. Updated the report formula dictionary.
- The live schema inspection confirmed all three underlying tables have RLS enabled; payroll run/line SELECT policies are role-limited, and payroll lines also inherit employee-scope restrictions. The views contain no seeded or fabricated payroll rows.
- Migration applied as version `20261111023400`, name `create_payroll_payslip_report_views`. No application or behavioral tests were run; this is schema/source linkage only.


## 12. Active payroll payslip screen now reads RLS-invoker views — 2026-11-11

- The dedicated `ErpPayslipReportsScreen` is the actual route for both «شريط قبض موظف» and «شريط قبض مجمع»; these names do not use the generic `ErpReportCenterScreen` route.
- Updated the dedicated screen to load employee payslip rows from `erp_v_employee_payslips` and aggregate run totals from `erp_v_payroll_payslip_summary`, rather than reading payroll lines directly for the payslip report.
- Aggregate totals are explicitly labelled as within the current user's permitted scope because the views run with invoker security and preserve RLS/employee branch scope.
- The views include only payroll runs in approved, posted or paid states. No payroll data was inserted or altered.
- The generic report-center map remains at 52 keys; its documented 45/59 overlap is unchanged. The two payslip reports are handled by their dedicated screen, not counted as generic report-center source coverage.
- The payroll view migration file is present in main and its applied database version is `20261111023400`.


## 13. Service ticket report views — 2026-11-11

- Added `erp_v_service_open_tickets` as a `security_invoker` view over `erp_service_tickets`, excluding closed/resolved/cancelled tickets and exposing age plus timestamp-based first-response/resolution overdue flags.
- Added `erp_v_service_ticket_response_metrics` as a `security_invoker` view joining the ticket to its SLA policy. It exposes calendar response minutes and an explicit response SLA status.
- For policies marked `business_hours_only=true`, the view deliberately returns a null SLA pass/fail result and `business_calendar_required`; it does not falsely calculate working-time SLA from wall-clock timestamps.
- Both views revoke `PUBLIC`/`anon` access and grant SELECT to `authenticated`. Metadata check confirmed `security_invoker=true`, authenticated SELECT=true, anon SELECT=false for both views.
- Routed the customer-service «التذاكر المفتوحة» report to the open-ticket view and «زمن الاستجابة»/«معدل الاستجابة» reports to the response-metrics view.
- Applied Supabase migration version `20261111024620` (`add_rls_service_ticket_report_views`). The repository migration file uses the exact applied version prefix.
- No real ticket rows exist to validate business behavior; no test data was inserted. The working-hours SLA calendar, aggregate response-rate presentation, and independent satisfaction survey model remain open. This is source linkage, not a claim that those report formulas are fully closed.


## 14. Customer-service satisfaction and ticket report integration — 2026-11-11

- Added `erp_v_service_customer_satisfaction` as a `security_invoker` aggregate view over ticket satisfaction scores. It returns total tickets, rated tickets, average and median score, minimum/maximum, rating coverage, and last update timestamp.
- The report is explicit that its population is tickets with recorded satisfaction scores; it is not a substitute for a separate survey/respondent model and does not infer satisfaction for unrated customers.
- Routed «رضا العملاء» to this aggregate view and mapped its score/count fields into the Business Suite report row.
- Applied migration version `20261111024712` (`add_service_customer_satisfaction_summary_view`). SELECT is granted only to authenticated after revoking PUBLIC/anon; the view runs with invoker security.
- No ticket/survey data was inserted. Behavioral aggregation remains unverified because the live company has no ticket sample rows.
