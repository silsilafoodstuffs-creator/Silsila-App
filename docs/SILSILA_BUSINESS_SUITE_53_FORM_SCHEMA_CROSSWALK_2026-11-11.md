# مطابقة نماذج Business Suite الـ53 بالمخطط الفعلي — سلسلة ERP
التاريخ: 2026-11-11
المصادر: `lib/erp/screens/erp_business_suite_screen.dart` وقراءة `pg_tables` و`information_schema.columns` في Supabase `teitsopmhruczplwlwgn`.

## 1. النتيجة التنفيذية
- عناصر قوائم Business Suite: 170 ظهورًا.
- أنواع النماذج التي تعرفها الشاشة عبر `_C(...)`: **53 نوعًا**.
- الإسنادات المباشرة إلى أسماء جداول في مسار المزامنة: **22 إسنادًا**؛ منها **19 حالة نوع/جدول** ظاهرة داخل switch رئيسي، والبقية إسنادات أخرى في مسارات متفرعة.
- استدعاءات RPC المسماة في الشاشة: 5.
- الشاشة تقرأ من الجدول المتخصص عندما يوجد ربط، وإلا تقرأ/تكتب `erp_business_suite_records` حسب `module_key` و`record_type`.
- وجود سجل عام لا يثبت وجود مستند متخصص أو سطور أو أثر دفتر. يجب عدم اعتبار 170 عنصرًا = 170 جدولًا.

## 2. قاموس النماذج × المخطط الحي

| م | الوحدة | record_type | الجداول الفعلية المرشحة | الحالة والقرار التصميمي |
|---:|---|---|---|---|
| 1 | أصول ثابتة | asset_category | `erp_asset_categories` | موجود؛ فئات الأصل وحساباته وطريقة الإهلاك |
| 2 | أصول ثابتة | asset_model | لا يوجد جدول نماذج أصل | جديد؛ يمكن استخدام قالب أصل بعد تصميمه، لا حفظه كسجل عام |
| 3 | أصول ثابتة | asset_location | `erp_branches`, `erp_warehouses`, `erp_hr_work_locations` | جزئي؛ يلزم hierarchy لمبنى/دور/غرفة وربط الموقع |
| 4 | أصول ثابتة | asset_cost_center | `erp_cost_centers` | جزئي؛ يلزم FK حقيقي للأصل وتوزيع النسب وتاريخ السريان |
| 5 | أصول ثابتة | depreciation_method | `erp_asset_categories.depreciation_method`, `erp_fixed_assets.depreciation_method` | موجود كقيمة على الفئة/الأصل؛ لا يوجد دليل مستقل لكتالوج طرق الإهلاك |
| 6 | أصول ثابتة | asset_accounts | `erp_asset_categories` | موجود جزئيًا؛ الحقول تربط حساب الأصل/المجمع/المصروف، ويلزم ربط أرباح وخسائر الاستبعاد |
| 7 | أصول ثابتة | asset_supplier | `erp_parties`, `erp_party_contacts` | جزئي؛ المورد كطرف، لكن ضمانات وصيانة الأصول تحتاج عقد/سجل مورد أصل |
| 8 | أصول ثابتة | asset_policy | `erp_financial_policies`, `erp_program_policies` | جزئي؛ لا يوجد كيان سياسة رسملة/اعتماد أصول مستقل مثبت |
| 9 | أصول ثابتة | depreciation | `erp_asset_depreciation_runs`, `erp_asset_depreciation_inputs`, `erp_asset_depreciation_lines` | موجود؛ يلزم ربط الحسابات والقيود وسيناريوهات العكس |
| 10 | أصول ثابتة | asset_disposal | `erp_asset_disposals` | موجود؛ يلزم اعتماد وربط القيد والعائد/الخسارة |
| 11 | أصول ثابتة | asset_movement | `erp_asset_movements` | موجود؛ يلزم توحيد النقل والعهدة والصيانة والجرد كأنواع واضحة |
| 12 | أصول ثابتة | asset | `erp_fixed_assets` | موجود؛ أصل ثابت مع تكلفة وعمر وقيمة تخريدية وحسابات |
| 13 | تصنيع | manufactured_product | `erp_items` | جزئي؛ المنتج النهائي هو صنف، لكن خصائص التصنيع/التتبع والجودة تحتاج امتدادًا مضبوطًا |
| 14 | تصنيع | material_alternative | لا يوجد جدول بدائل خامات ظاهر | جديد؛ مادة أصلية/بديلة ونسبة تحويل وموافقة جودة |
| 15 | تصنيع | quality_template | لا يوجد جدول قوالب جودة ظاهر | جديد؛ قالب/معيار/مرحلة/حدود قبول وعينة |
| 16 | تصنيع | production_shift | `erp_hr_shifts`, `erp_manufacturing_work_centers` | جزئي؛ وردية HR ليست بالضرورة تقويم طاقة إنتاجية |
| 17 | تصنيع | subcontract_manufacturing | `erp_parties`, `erp_production_orders` | غير مكتمل؛ يلزم مستند تصنيع لدى الغير وخامات مرسلة ومستلمة وخدمة وتكلفة |
| 18 | تصنيع | production_plan | `erp_production_orders`, `erp_manufacturing_boms` | جزئي؛ لا يوجد تخطيط طلب/طاقة مستقل ظاهر |
| 19 | تصنيع | bom | `erp_manufacturing_boms`, `erp_manufacturing_bom_lines` | موجود؛ قائمة مواد متعددة السطور |
| 20 | تصنيع | work_center | `erp_manufacturing_work_centers` | موجود |
| 21 | تصنيع | production_quality_check | `erp_production_quality_checks` | موجود؛ يلزم ربط قوالب الجودة ونقاط القياس |
| 22 | تصنيع | production_variance | `erp_production_variances` | موجود؛ يلزم مصالحة كمية/تكلفة فعلية مقابل معيارية |
| 23 | تصنيع | production_order | `erp_production_orders`, `erp_production_material_movements`, `erp_inventory_movements` | موجود؛ صرف خامات واستلام منتج وأثر مخزني |
| 24 | مقاولات | construction_setup | `erp_construction_projects`, `erp_cost_centers` | جزئي؛ يلزم تعريف إعدادات المشروع والميزانية والعملة والفترة |
| 25 | مقاولات | contract_template | لا يوجد جدول قوالب عقود ظاهر | جديد؛ قالب بنود وشروط وإصدار واعتماد |
| 26 | مقاولات | material_request | `erp_construction_material_requests`, `erp_construction_material_request_lines` | موجود؛ طلب متعدد البنود |
| 27 | مقاولات | material_movement | `erp_construction_material_movements`, `erp_inventory_movements` | موجود؛ RPC للحركة المخزنية مع ربط المشروع |
| 28 | مقاولات | construction_cost | `erp_construction_costs` | موجود؛ يلزم مصدر التكلفة وربطها ببند BOQ ومركز التكلفة |
| 29 | مقاولات | construction_item | `erp_items`, `erp_construction_boq_lines` | جزئي؛ الصنف/بند BOQ موجود، لكن دليل بنود مقاولات موحد يحتاج قرار |
| 30 | مقاولات | construction_resource | `erp_employees`, `erp_parties`, `erp_items` | جزئي؛ الموارد متعددة الأنواع وتحتاج كتالوج موارد وعلاقات |
| 31 | مقاولات | project_cost_code | لا يوجد project cost code catalog ظاهر | جديد؛ كود تكلفة مرتبط بالمشروع وBOQ والحساب |
| 32 | مقاولات | tender | لا يوجد سجل مناقصات مستقل ظاهر | جديد؛ دعوة/موردون/عروض/ترسية/تاريخ |
| 33 | مقاولات | site_permit | لا يوجد سجل تصاريح موقع ظاهر | جديد؛ تصريح ومرفق وجهة إصدار وتواريخ |
| 34 | مقاولات | certificate | `erp_construction_payment_certificates`, `erp_construction_certificate_lines` | موجود؛ مستخلص متعدد البنود واعتماد/دفع |
| 35 | مقاولات | subcontractor | `erp_parties`, `erp_party_contacts` | جزئي؛ المقاول طرف مورد؛ يلزم ملف تعاقد/ضمان/مستخلصات |
| 36 | مقاولات | boq | `erp_construction_boq_lines` | موجود كسطور؛ يلزم رأس BOQ/إصدار/اعتماد إذا لم يكن متاحًا في كيان المشروع |
| 37 | مقاولات | site_report | `erp_construction_site_reports` | موجود؛ يلزم مرفقات واعتماد ومؤلف/توقيت |
| 38 | مقاولات | project | `erp_construction_projects` | موجود |
| 39 | خدمة وعلاقات عملاء | customer_profile | `erp_parties`, `erp_party_contacts` | موجود جزئيًا؛ ملف الطرف موحد، وتفاصيل CRM تحتاج ربطًا |
| 40 | خدمة وعلاقات عملاء | customer_segment | لا يوجد segment catalog ظاهر | جديد؛ شروط ديناميكية وقواعد عضوية محفوظة وقابلة لإعادة الاستخدام |
| 41 | خدمة وعلاقات عملاء | escalation_rule | `erp_service_sla_policies.escalation_minutes` | جزئي؛ يوجد وقت تصعيد، لكن لا يوجد سلم تصعيد متعدد المستويات/وجهات |
| 42 | خدمة وعلاقات عملاء | response_template | لا يوجد جدول قوالب ردود ظاهر | جديد؛ نصوص ردود معتمدة وإصدارات وقنوات |
| 43 | خدمة وعلاقات عملاء | customer_survey | `erp_service_tickets.satisfaction_score` | جزئي؛ يوجد score على التذكرة، ولا يوجد استبيان وأسئلة وإجابات وعينة |
| 44 | خدمة وعلاقات عملاء | service_team | `erp_employees`, `erp_hr_departments` | جزئي؛ لا يوجد فريق خدمة مستقل وعضويته/توزيعه |
| 45 | خدمة وعلاقات عملاء | communication_channel | `erp_service_tickets.channel` | جزئي؛ قيمة نصية وليست دليل قنوات |
| 46 | خدمة وعلاقات عملاء | sla_policy | `erp_service_sla_policies` | موجود |
| 47 | خدمة وعلاقات عملاء | service_priority | `erp_service_tickets.priority` | جزئي؛ القيمة نصية وليست دليل أولوية وقواعد تصعيد |
| 48 | خدمة وعلاقات عملاء | service_reason | `erp_service_tickets.category` | جزئي؛ التصنيف نصي وليس دليل أسباب شكاوى/خدمة |
| 49 | خدمة وعلاقات عملاء | service_catalog | لا يوجد service catalog ظاهر | جديد؛ خدمة/نوع/مدة/تكلفة/أهلية/SLA |
| 50 | خدمة وعلاقات عملاء | ticket | `erp_service_tickets`, `erp_service_ticket_events` | موجود؛ رأس تذكرة وسجل أحداث وSLA |
| 51 | خدمة وعلاقات عملاء | opportunity | `erp_crm_leads` | موجود؛ يلزم مراحل فرص ومصدر/قيمة متوقعة وربط تحويل |
| 52 | خدمة وعلاقات عملاء | field_task | `erp_service_visits` | موجود؛ يلزم توقيت وموقع ومرفقات ونتيجة |
| 53 | خدمة وعلاقات عملاء | activity | `erp_crm_activities` | موجود؛ نشاط مرتبط بطرف/فرصة/تذكرة ومستخدم مسؤول |

## 3. عمليات RPC المرصودة في الشاشة
الأسماء التي تظهر كاستدعاءات RPC في الملف:
- `erp_record_construction_stock_movement`
- `erp_calculate_asset_depreciation`
- `erp_post_asset_depreciation_run`
- `erp_post_asset_disposal`
- `erp_record_production_stock_movement`

يجب عند الربط مطابقة كل استدعاء مع توقيعه الفعلي، صلاحيات EXECUTE، تحقق الشركة/الفرع/المخزن، idempotency، وسجل التدقيق. لا يعتبر ظهور اسم RPC في Flutter إثباتًا لصحة صلاحياته أو نجاحه.

## 4. دورة المستندات الموحدة المطلوبة
- تعريف/مسودة → إرسال → اعتماد → ترحيل → إقفال.
- الحالات المتخصصة: رفض، إلغاء قبل الترحيل، عكس بعد الترحيل، استكمال جزئي، تعليق، انتهاء صلاحية.
- الترحيل يجب أن يكون idempotent ويكتب أثرًا ذريًا في المخزون/الأستاذ/الخزينة.
- المستند المرحل لا يحذف ولا يعدّل بصمت؛ التصحيح بمستند عكسي أو تسوية مرتبطة بالأصل.
- رأس المستند يضم الشركة والفرع والمشروع/المخزن والطرف والتاريخ والعملة ومركز التكلفة والمرفقات والحالة.
- السطور تحفظ FK للصنف/الخدمة/المورد والوحدة وعامل التحويل والكمية والسعر والخصم والضريبة والإجمالي.

## 5. قائمة الكيانات التي يلزم تصميمها قبل الربط
لا تظهر كيانات مستقلة لهذه الوظائف في المخطط الحي الحالي، ويجب حسمها كتصميم قبل تنفيذ migrations:
1. قوالب الأصول ونماذجها وسياسات الرسملة.
2. بدائل الخامات وقوالب الجودة وخطة الإنتاج والتصنيع لدى الغير.
3. قوالب العقود وأكواد التكلفة والمناقصات وتصاريح المواقع.
4. شرائح العملاء وقوالب الردود والاستبيانات وفرق الخدمة ودليل القنوات والأولويات والأسباب وكتالوج الخدمات.
5. أي جداول رأس/سطور إضافية لازمة لضمان عدم استخدام `erp_business_suite_records.details JSONB` كبديل دائم للعمليات التي تحتاج علاقات ومصالحة.

## 6. الحدود
هذه مطابقة تصميمية مبنية على تعريفات الشاشة ووجود أسماء الجداول والأعمدة في catalog. لم يتم تعديل Flutter أو SQL أو قاعدة Supabase، ولم يتم إنشاء سجلات أو حذف بيانات. لا تعتبر هذه الوثيقة اختبارًا وظيفيًا أو أمنيًا.


## 7. مراجعة نمط الحفظ والقراءة الفعلي في الشاشة

تم فحص `_load`, `_edit`, `_syncOperationalRecord`, `_delete`:
- النماذج العادية تقرأ من `erp_business_suite_records` حسب company_id/module_key/record_type.
- عند الحفظ، تُكتب الحقول العامة في `erp_business_suite_records`، ثم يحاول `_syncOperationalRecord` مزامنتها إلى جدول تشغيلي متخصص في الحالات المدعومة.
- تقارير Business Suite لا تقرأ السجل العام؛ تقرأ `_reportTable` مباشرة من جدول تشغيلي واحد باستخدام `select('*')` وحد أقصى 1500 صف، دون تجميع متعدد الجداول أو فلاتر فترة/فرع/مشروع موحدة.
- بعض البيانات نفسها تظهر في مصدرين: سجل عام به `details JSONB` وسجل تشغيلي به أعمدة منظمة. يجب تحديد مصدر الحقيقة بوضوح؛ التصميم المستهدف أن تكون الجداول التشغيلية مصدر الحقيقة، والسجل العام Projection/واجهة قائمة فقط أو يُستغنى عنه للأنواع المتخصصة.
- البحث والتصفية في النماذج يتمان على الصفوف المحملة في الذاكرة، ولا توجد pagination خادمية كاملة بعد حد 1500.
- حذف السجل يحذف الجدول التشغيلي مباشرة من Flutter في بعض الحالات ثم السجل العام؛ توجد حواجز لبعض الحركات المرحّلة، لكنها ليست سياسة عامة لكل الجداول والأنواع.
- التحقق العام للنموذج يفرض الكود والاسم وصحة الرقم/التاريخ فقط؛ لا يغطي كل FK/قواعد الأعمال أو التحقق من الحالة على مستوى الخادم.

### شروط إغلاق هذا النمط
1. كل نوع متخصص له source of truth واحد؛ لا تحفظ قيمة مالية/مخزنية في JSON وتكررها في أعمدة مستقلة دون استراتيجية مزامنة.
2. إنشاء/تعديل/إرسال/اعتماد/ترحيل/عكس/حذف كل كيان يتم عبر RPC متخصصة أو RLS مدروسة، وليس delete مباشرًا من Flutter.
3. جميع transitions تعتمد على حالة المصدر الفعلية، لا status عام قابل للتغيير من Dropdown.
4. التقارير المتخصصة تستخدم Views/RPC مجمعة ومصالحة، وليس `select('*')` الخام.
5. كل صفحة تطبق فلاتر tenant/branch/project/warehouse، مع server-side pagination.
6. `erp_business_suite_records` لا يستخدم كبديل دائم لجدول رأس/سطور أو لدفتر مالي/مخزني.
