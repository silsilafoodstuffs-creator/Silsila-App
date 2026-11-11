# تدقيق منظومة التكويد المركزي ومولدات الأكواد — سلسلة ERP
التاريخ: 2026-11-11
المصادر: `erp_program_policies_screen.dart`، شاشات الأصناف والعملاء والجغرافيا، triggers/functions في Supabase، والقيمة الفعلية الوحيدة لسجل `code_generation_registry`.

## 1. القيم الفعلية المقروءة من Supabase
| النوع | القيمة الحية | النتيجة |
|---|---|---|
| كود الصنف | `Itm` + رئيسية 2 + فرعية 2 + ثانوية 2 + براند 2 + تسلسل **3** | الطول 14 حرفًا؛ التسلسل الحالي 3 |
| فئات الأصناف | `Cat` + 2 + 2 + 2 | ثلاث مستويات فقط، والكود موروث هرميًا |
| البراند | `Bra` + 2 | البراند الافتراضي `Bra00` موجود ونشط |
| العميل | `Cus` + 8 أرقام جغرافية + 4 أرقام تسلسلية | الكود النهائي 15 حرفًا |
| الجغرافيا | الدولة 2 + المحافظة 2 + المركز/الحي 2 + المنطقة 2؛ بادئة المنطقة `Rig` | كود المنطقة مثل `Rig` ثم 8 أرقام؛ كود المحافظة/المركز رقمي بلا بادئة مستقلة |
| المورد | `Ven` + 5 | البادئة الفعلية في سجل التكويد Ven |
| المستخدم | `Usr` + أرقام نوع المستخدم الموروثة + تسلسل مستقل 5 | private trigger يولدها؛ ليست مجرد Usr+5 |

### اختلاف يجب حسمه مع قرار التصميم
قيمة `item_segments.serial` الفعلية هي **3**، كما أن default شاشة سياسات البرنامج في `item_code` يحدد `serial_digits:3`. التصميم المعتمد للصنف في متطلبات المشروع هو تسلسل من **رقمين** بعد الفئة والبراند. لذلك يلزم توحيد شاشة السياسة والـregistry والـtrigger على رقمين في مرحلة الربط؛ لا تُغيّر القاعدة الحية الآن في مرحلة التصميم.

## 2. المولدات الفعلية والـTriggers
| الكيان | Trigger / Function | سلوك التكويد |
|---|---|---|
| فئات الأصناف | `erp_item_categories_validate_tree_and_code` | يولد Cat هرميًا؛ رئيسية 2، فرعية 2 ترث الرئيسية، ثانوية 2 ترث الفرعية؛ يمنع أكثر من 3 مستويات |
| الأصناف | `erp_assign_item_hierarchical_code` | Itm + 6 أرقام الفئات + رقمين للبراند + serial؛ يقرأ serial من registry (حاليًا 3) |
| البراندات | `erp_assign_brand_code` | Bra + تسلسل 2، مع قفل advisory |
| العملاء | `erp_assign_customer_geo_code` | Cus + أرقام كود المنطقة Rig بعد إزالة الحروف + تسلسل العميل داخل المنطقة |
| الموردون | `erp_assign_central_code` | Ven + 5 افتراضيًا/القيمة المحفوظة |
| الجغرافيا | `erp_assign_geo_hierarchical_code` | المحافظة = country_code + 2؛ district = كود المحافظة + 2؛ area = Rig + كود district + 2 |
| باقي الكيانات | `erp_assign_central_code` | قراءة prefix/digits من `erp_code_policy_config` حسب type |
| الأصول/CRM/التصنيع/المقاولات/الخدمة/HR | `erp_assign_extended_central_code` | مفاتيح منفصلة وبادئات افتراضية لكل جدول |
| Workspace | `erp_assign_workspace_central_code` | يقرأ سياسة الشركة الأم من workspace platform company |
| سياسات البرنامج | `erp_assign_program_policy_code` | بعض policy codes ثابتة بمفاتيح خاصة ثم تسلسل Pol |
| أنواع HR | `erp_hr_reference_catalogs_assign_code` | يدعم employment_type وcontract_type فقط |
| مندوبو المبيعات | private `erp_assign_sales_representative_code` | يربط كود المندوب بالموظف |

## 3. فجوات بين شاشة السياسات والمولدات
1. **تسلسل الصنف:** الشاشة والـregistry والـtrigger حاليًا 3؛ المطلوب 2 حسب صيغة كود الصنف المعتمدة.
2. **بادئات الجغرافيا:** شاشة السياسات تعرض Con وGov وDis وRig. المولد الفعلي لا يقرأ Con/Gov/Dis؛ يستخدم `erp_countries.country_code` للأرقام، ويستخدم `geo_prefix` (Rig) عند مستوى area فقط. يجب إما تغيير تسميات/قيم الواجهة لتوضح أنها مقاطع رقمية، أو تعديل المولد إذا كان المطلوب فعلًا بادئات لكل مستوى. لا تترك سياسة واجهة لا تؤثر في المولد.
3. **معاينة الفئات:** `erp_preview_next_central_code(...,'category')` يحسب تسلسلًا عامًا Cat، بينما trigger الفئات يولد كودًا هرميًا بحسب `parent_id`. لا تستخدم المعاينة العامة لهذه الصفحة.
4. **معاينة الأصناف:** لا يظهر RPC مخصص لمعاينة كود الصنف النهائي حسب الفئة الثانوية والبراند وتسلسل المجموعة؛ يلزم `erp_preview_next_item_code` يطابق trigger.
5. **المورد عند فشل المعاينة:** شاشة الأطراف ترجع fallback `Sup00001`، بينما البادئة الحية Ven. لأن trigger المركزي يحافظ على أي `party_code` غير فارغ، يمكن حفظ Sup بدل Ven إذا فشل RPC. يجب أن يكون fallback فارغًا/دع trigger يولد، أو يكون Ven متطابقًا.
6. **العميل:** الشاشة لا تولد كودًا عامًا عند فتح نموذج العميل؛ تنتظر اختيار المنطقة ثم تستدعي `erp_preview_next_customer_geo_code`، وهذا صحيح. لكن trigger يتجاوز التوليد إذا وصل `party_code` غير فارغ، ولا يتحقق من صيغته؛ يلزم فرض التحقق حتى لا يمكن حفظ كود غير مطابق.
7. **تعديل كود موجود:** معظم مولدات `erp_assign_central_code` تحافظ على الكود المرسل غير الفارغ دون التحقق من مطابقته للسياسة. يجب تحديد هل الإدخال اليدوي مسموح، وإن كان ممنوعًا فيجب فرضه خادميًا.
8. **تغيير فئة/براند الصنف:** Trigger الصنف يعيد توليد `item_code` عند تغيير `category_id` أو `brand_id`. هذا يغيّر كود صنف قائم بعد إصدار فواتير/مستندات؛ التصميم يحتاج قرار ثبات الكود أو سجل أكواد سابقة/alias. لا يُعاد ترقيم السجل بصمت.
9. **نقل العميل جغرافيًا:** تغيير `geographic_area_id` يعيد توليد `party_code`. يلزم تحديد هل الكود ثابت بعد الإنشاء أم يتغير مع الموقع مع سجل تاريخي واضح.
10. **نقل مستوى جغرافي:** تغيير `parent_id` أو `level` يعيد توليد كود الجغرافيا، لكن لا يوجد cascade ظاهر لإعادة بناء أكواد العملاء المرتبطين بالمنطقة؛ قد يبقى كود العميل يحمل مقطعًا جغرافيًا قديمًا.
11. **تعديل الكود يدويًا:** بعض triggers تعمل فقط عند INSERT أو عند تحديث حقول محددة (مثل category_id/brand_id أو parent_id/level)، وليس عند تغيير عمود الكود وحده. يجب منع تعديل الأكواد الصادرة أو التحقق منها في trigger يشمل عمود الكود.
12. **معاينة العميل العامة:** `erp_preview_next_central_code('customer')` يعطي تسلسل Cus عامًّا، وليس كود العميل الجغرافي النهائي؛ الشاشة تستخدم RPC الجغرافي الصحيح، ويجب منع أي شاشة أخرى من استخدام المعاينة العامة للعميل.
13. **مفاتيح السياسات:** `erp_program_policies_screen.dart` يكتب `item_segments` ويستخدمها المولد كـfallback لأطوال الفئات، بينما واجهة الفئات تحفظ مفاتيح مستقلة `category_code.main/sub/secondary`. يجب توثيق مصدر الحقيقة حتى لا تتباعد القيم.
14. **مستويات الجغرافيا:** المخطط والمولد يستخدمان `governorate`, `district`, `area`; تسمية «مركز» في الواجهة تقابل `district` تقنيًا، وليست مستوى `center` مستقلًا. يجب توحيد labels/level codes.

## 4. العقد النهائي المطلوب لمولدات الأكواد
- كل كود له format contract واحد في registry، وتُشتق منه شاشة السياسة والـpreview والـtrigger والـvalidation.
- لا توجد قيم prefix/digits مكررة في ملفات Flutter أو triggers إلا كـfallback آمن؛ المصدر النهائي هو registry.
- قفل advisory لكل نطاق تسلسل، مع unique constraint/فهرس فريد مناسب لكل شركة ونوع كود/نطاق جغرافي/فئة/براند.
- Preview لا يحجز الرقم ولا يضمنه؛ الحفظ يولد الرقم خادميًا ويعيد القيمة النهائية.
- أي كود صادر لا يتغير بصمت بعد ربطه بمستندات. إعادة التصنيف لا تعيد كتابة كود السجل؛ إذا اقتضت السياسة تغييرًا، يحتفظ النظام بالكود السابق في alias/history ويربطه بالمعرف الثابت.
- customer code يتطلب منطقة فعالة ذات كود جغرافي صالح؛ supplier code لا يتطلب منطقة إلا إذا قررت السياسة ذلك.
- فئة الصنف ثلاثة مستويات فقط، والصنف يجب أن يرتبط بفئة ثانوية نشطة وبراند نشط.
- كود المستخدم يرث جزءًا رقميًا من نوع المستخدم ثم تسلسلًا مستقلًا؛ preview يجب أن يحاكي ذلك إذا أضيف.
- كل fallback في Flutter لا يضع قيمة غير مطابقة للـregistry.
- اختبارات التكويد النهائية تشمل إدخالًا متزامنًا، اختلاف الشركة، حدود السعة، تكرار البادئة، تغيير الأب، تغيير المنطقة، تغيير الفئة/البراند، كود يدوي غير صالح، وحالة غياب الإعداد.

## 5. قرارات مطلوب اعتمادها قبل الربط
1. توحيد تسلسل كود الصنف على رقمين (بدل 3 الحالي) في جميع الطبقات.
2. اعتماد صيغة الجغرافيا: مقاطع رقمية للدولة/المحافظة/المركز/المنطقة مع Rig للمنطقة فقط، أو اعتماد بادئة مستقلة لكل مستوى وتعديل المولد بالكامل.
3. منع تغيير كود الصنف/العميل بعد الإصدار، أو وضع آلية تاريخ/alias إن كان تغيره مطلوبًا.
4. استبدال fallback المورد `Sup00001` بـVen مطابق أو ترك الكود فارغًا حتى التوليد الخادمي.
5. إضافة preview RPC هرمي للفئات والأصناف، وعدم استخدام preview المركزي العام للفئات/العميل.
6. فرض تحقق خادمي للكود غير الفارغ ومنع تجاوز الصيغة بالكتابة المباشرة.

## 6. حدود المراجعة
هذه مراجعة قراءة فقط للقيم والـtriggers والواجهات. لم يتم تغيير `code_generation_registry` أو أكواد السجلات أو triggers أو migrations. لم يتم إنشاء بيانات أو إعادة ترقيم سجلات موجودة.


## 7. سجل الـ80 نوعًا الفعلي في code_generation_registry

تم استخراج المفاتيح مباشرة من JSONB الحي. هذه هي قائمة أنواع الكود المخزنة حاليًا؛ لا تعني أن كل trigger/preview مربوط بها بالكامل.

| type_key | prefix | digits | automatic | composite |
|---|---|---:|---|---|
| `account` | `Acc` | 5 |  |  |
| `asset_category` | `Aca` | 3 |  |  |
| `asset_depreciation_run` | `Adr` | 5 |  |  |
| `asset_disposal` | `Adp` | 5 |  |  |
| `branch` | `Brn` | 3 |  |  |
| `brand` | `Bra` | 2 | true | false |
| `business_suite_record` | `Bsr` | 5 |  |  |
| `cash_movement` | `Cmv` | 5 |  |  |
| `cash_order` | `Cso` | 5 |  |  |
| `cash_payment` | `Cpy` | 5 |  |  |
| `cash_receipt` | `Rcp` | 5 |  |  |
| `cash_transfer` | `Trf` | 5 |  |  |
| `cashbox` | `Csh` | 5 |  |  |
| `category` | `Cat` | 6 | true | true |
| `checkbook` | `Ckb` | 5 |  |  |
| `commission_plan` | `Com` | 5 |  |  |
| `construction_material_movement` | `Cmm` | 5 |  |  |
| `construction_material_request` | `Cmr` | 5 |  |  |
| `construction_payment_certificate` | `Cpc` | 5 |  |  |
| `construction_project` | `Cpj` | 5 |  |  |
| `construction_site_report` | `Csr` | 5 |  |  |
| `cost_center` | `Cst` | 5 |  |  |
| `crm_activity` | `Act` | 5 |  |  |
| `crm_lead` | `Led` | 5 |  |  |
| `customer` | `Cus` | 4 | true | true |
| `delegate` | `Rep` | 5 |  |  |
| `department` | `Dep` | 3 |  |  |
| `employee` | `Emp` | 5 |  |  |
| `fixed_asset` | `Ast` | 5 |  |  |
| `grade` | `Grd` | 3 |  |  |
| `hr_advance` | `Hav` | 5 |  |  |
| `hr_contract` | `Hct` | 5 |  |  |
| `hr_custody` | `Hcy` | 5 |  |  |
| `job` | `Job` | 5 |  |  |
| `journal_entry` | `Jrn` | 5 |  |  |
| `manufacturing_bom` | `Mfb` | 5 |  |  |
| `manufacturing_work_center` | `Mwc` | 4 |  |  |
| `payment_method` | `PAY` | 4 |  |  |
| `payroll_run` | `Prl` | 5 |  |  |
| `permission_template` | `Tpl` | 5 |  |  |
| `price_list` | `Pli` | 5 |  |  |
| `production_order` | `Pdo` | 5 |  |  |
| `production_quality_check` | `Pqc` | 5 |  |  |
| `production_variance` | `Pvr` | 5 |  |  |
| `purchase_invoice` | `Piv` | 5 |  |  |
| `purchase_order` | `Por` | 5 |  |  |
| `purchase_receipt` | `Prr` | 5 |  |  |
| `purchase_return` | `Prt` | 5 |  |  |
| `quotation` | `Qot` | 5 |  |  |
| `salary_element` | `Elm` | 3 |  |  |
| `sales_delivery` | `Dlv` | 5 |  |  |
| `sales_fulfillment` | `Ful` | 5 |  |  |
| `sales_invoice` | `Siv` | 5 |  |  |
| `sales_order` | `Sor` | 5 |  |  |
| `sales_return` | `Srt` | 5 |  |  |
| `service_sla_policy` | `Slp` | 4 |  |  |
| `service_ticket` | `Svt` | 5 |  |  |
| `service_visit` | `Svs` | 5 |  |  |
| `shift` | `Shf` | 5 |  |  |
| `supplier` | `Ven` | 5 |  |  |
| `unit` | `UNT` | 4 |  |  |
| `user` | `Usr` | 5 |  |  |
| `user_classification` | `Cls` | 5 |  |  |
| `user_type` | `Typ` | 2 |  |  |
| `warehouse` | `Whs` | 5 |  |  |
| `work_location` | `Plc` | 3 |  |  |
| `workspace_adjustment` | `Wad` | 5 |  |  |
| `workspace_branch` | `Wbr` | 5 |  |  |
| `workspace_cash_movement` | `Wcm` | 5 |  |  |
| `workspace_customer` | `Wcu` | 5 |  |  |
| `workspace_department` | `Wdp` | 5 |  |  |
| `workspace_employee` | `Wem` | 5 |  |  |
| `workspace_item_link` | `Wil` | 5 |  |  |
| `workspace_purchase` | `Wpi` | 5 |  |  |
| `workspace_purchase_return` | `Wpr` | 5 |  |  |
| `workspace_sale` | `Wsi` | 5 |  |  |
| `workspace_sale_return` | `Wsr` | 5 |  |  |
| `workspace_supplier` | `Wsu` | 5 |  |  |
| `workspace_transfer` | `Wtr` | 5 |  |  |
| `workspace_warehouse` | `Wwh` | 5 |  |  |

