# مطابقة المسارات المخصصة الـ96 بالمصادر التشغيلية — سلسلة ERP
التاريخ: 2026-11-11
المصادر: `erp_dashboard_screen.dart`، شاشات Flutter المتخصصة، repositories/services، ومخطط Supabase الحي.

## 1. النطاق
تم استخراج 96 ظهورًا من عناصر القائمة يصل توجيهها إلى مسارات مخصصة في لوحة التحكم. هذا لا يعني وجود 96 Widget مستقلة؛ بعض الصفحات تشترك في الشاشة نفسها مع `initialView` أو `kind` مختلف.

## 2. المسارات المخصصة الـ96 ومصدرها

| أرقام القائمة | الصفحات | الشاشة/المسار | المصدر التشغيلي الحقيقي |
|---|---|---|---|
| 1 | الملخص التنفيذي | لوحة الملخص | RPC `erp_get_executive_metrics` ومصادر مالية/مبيعات/مخزون؛ يلزم قاموس KPI ومصالحة حسب الفترة |
| 2 | سياسات البرنامج | ErpProgramPoliciesScreen | `erp_program_policies`, `erp_program_settings`, `erp_users`؛ يجب فصل policy key عن إعدادات العرض |
| 3 | بيانات الشركة | ErpCompanyProfileScreen | `erp_companies`, `erp_currencies`, `erp_company_members`; RPC `erp_create_company`, `erp_update_company_profile` |
| 4 | الفروع | ErpBranchesScreen | `erp_branches`, `erp_geographic_data`; RPC `erp_preview_next_central_code` |
| 5، 43 | مراكز التكلفة | ErpCostCentersScreen | `erp_cost_centers`, `erp_branches` |
| 6، 90 | بيانات جغرافية | ErpGeographicDataScreen | `erp_geographic_data`, `erp_countries`; يلزم الحفاظ على تسلسل parent والرمز الجغرافي |
| 7 | أنواع الأنشطة | ErpActivityTypesScreen | `activity_types` |
| 8 | المستخدمين | ErpUserAdminScreen | `erp_company_members`, `erp_user_types`, `erp_users`, `erp_user_classifications`, `erp_employees`, `erp_branches`, `erp_warehouses` |
| 9 | صلاحيات المستخدمين | ErpUserAdminScreen | `erp_user_permissions`, `erp_user_permission_matrix`, `erp_permission_templates`, `erp_permission_template_rules`, `erp_user_branch_warehouse_access` |
| 10 | قوالب صلاحيات المستخدمين | ErpUserAdminScreen | الجداول السابقة؛ يلزم أن يكون تطبيق القالب ذريًا مع سجل تغيير |
| 11 | سجل العمليات | ErpActivityLogScreen | الشاشة تقرأ `erp_app_activity_log` عبر `ErpAppManagementService.listActivity` وتعرض آخر 500 عملية للشركة؛ تغطية كل عمليات ERP بمسارات الكتابة ما زالت تحتاج تدقيقًا مستقلًا |
| 12 | إدارة مفاتيح API | ErpApiManagementScreen | مكتمل ربط دورة حياة المفاتيح عبر `erp_api_key_issue/list/revoke`، وتخزين بصمة فقط، ونطاقات قراءة، ومصادقة Edge Function، وحد 60 طلبًا/دقيقة؛ بوابة `silsila-api-v1` منشورة Version 3. اختبار HTTP حي وFlutter build مؤجلان لمرحلة الاختبار الشاملة |
| 14 | مراجعة الحركات | ErpMovementAuditScreen | RPC `erp_run_movement_audit`; يلزم تقرير فروق مصدره الخادمي وتفاصيل قابلة للمراجعة |
| 15 | قائمة اعتماد القيود | ErpJournalEntriesScreen | `erp_journal_entries`, `erp_journal_lines`; لاحظ أن initialStatus الحالي هو `draft`، ويجب حسم هل قائمة الاعتماد تعرض submitted أم draft |
| 19 | مسح جميع البيانات | ErpClearDataScreen | RPC `erp_prepare_selective_data_clear`, `erp_complete_selective_data_clear`; موافقة مزدوجة/نطاق شركة/نسخة احتياطية/تأكيد نهائي |
| 27، 31، 32 | إدارة الشعار والصور؛ إدارة صور الأصناف والفئات؛ إدارة صور الموردين والعملاء | ErpAppAssetsScreen | `erp_managed_apps`, `erp_app_assets`, `erp_app_theme_settings`; Supabase Storage signed URLs وسياسات bucket |
| 30 | إدارة إعلانات التطبيق | ErpAppAdvertisementsScreen | `erp_app_assets`, `erp_managed_apps`, `activity_types`; bucket `silsila-public-ads`؛ سياسات قراءة عامة مقيدة بأنواع/خانات الإعلانات |
| 33 | إدارة شركات الشحن | ErpShippingCompaniesScreen | RPCs `admin_list_shipping_companies`, `admin_save_shipping_company`; لا تعتمد على CRUD عام من Flutter |
| 41 | شجرة الحسابات | ErpAccountsScreen | `erp_accounts`, View `erp_account_tree_metrics`; يلزم التحقق من توازن الهيكل وعدم وجود دورات |
| 42، 63 | الفترات المالية؛ إقفال الفترة | ErpFiscalPeriodsScreen | `erp_fiscal_periods`; يجب أن يكون الإقفال خادميًا ويمنع ترحيلًا لاحقًا خارج الفترة |
| 44 | العملات | ErpCurrenciesScreen | `erp_currencies`; يلزم سعر صرف مؤرخ ومصدر ومراجعة |
| 45، 46 | الخزائن الرئيسية والفرعية؛ الحسابات البنكية | ErpCashboxesScreen | `erp_cashboxes`, `erp_accounts`, `erp_branches`; حسم نوع cashbox مقابل bank account |
| 47 | خريطة الحسابات التشغيلية | ErpOperationalAccountMappingsScreen | `erp_operational_account_mappings`, `erp_accounts`; RPC `erp_post_operational_document_accounting` |
| 48 | طرق الدفع | ErpPaymentMethodsScreen | `erp_payment_methods`, `erp_cashboxes` |
| 49، 50، 51، 52، 53، 54، 55، 56 | أوامر/حركات النقدية والشيكات؛ دفاتر الشيكات؛ متابعة الشيكات؛ شيكات الائتمان؛ السياسات المحاسبية | ErpFinancialOperationsScreen | `erp_cash_movements`, `erp_cash_orders`, `erp_cash_vouchers`, `erp_cheques`, `erp_checkbooks`, `erp_cashboxes`, `erp_accounts`, `erp_financial_policies`; RPCs إنشاء/ترحيل/تحويل/إصدار/تسوية الشيكات |
| 59 | قيود اليومية | ErpJournalEntriesScreen | `erp_journal_entries`, `erp_journal_lines`; RPC `erp_save_journal_draft`, `erp_post_journal_entry`, `erp_reverse_journal_entry` |
| 60، 61، 64 | سندات القبض؛ سندات الصرف؛ تحويل بين الخزائن | ErpCashVouchersScreen | `erp_cash_vouchers`, `erp_cash_movements`, `erp_cashboxes`, `erp_accounts`, `erp_parties`; RPC `erp_post_cash_voucher` |
| 70، 71، 74 | ميزان المراجعة؛ الأستاذ العام؛ حركة حساب | ErpLedgerReportsScreen | View `erp_general_ledger`; RPC `erp_get_trial_balance`; يجب أن تعتمد القيود المرحلة فقط وتطابق دفتر الأستاذ |
| 82 | ملخص تنفيذي | لوحة الملخص | نفس KPI RPC؛ يجب توحيد اسم/معادلة التقرير مع «الملخص التنفيذي» |
| 83 | بيانات المخازن | ErpInventoryMasterScreen | `erp_warehouses`, `erp_branches`, geographic links |
| 84 | فئات الأصناف | ErpItemCategoriesScreen | `erp_item_categories`; المصدر المعتمد للفئات، لا legacy item groups |
| 85 | دليل الأصناف | ErpInventoryMasterScreen | `erp_items`, `erp_item_units`, `erp_item_categories`, `erp_brands` |
| 86 | وحدات الأصناف | ErpItemUnitsScreen | `erp_item_unit_catalog`؛ يلزم توحيد هذا الدليل مع وحدات كل صنف في `erp_item_units` |
| 91، 92، 93 | إذن إضافة؛ إذن صرف؛ تحويل مخزني | ErpInventoryScreen | `erp_inventory_movements`, `erp_stock_balances`, `erp_items`, `erp_warehouses`; RPCs `erp_record_inventory_movement`, `erp_transfer_inventory_between_warehouses` |
| 94 | تسوية جرد | ErpStocktakeScreen | RPC `erp_create_manual_stock_adjustment` |
| 95، 96 | جرد فعلي؛ محاضر الجرد ومراجعة الفروق | ErpStocktakeScreen | `erp_stocktakes`, `erp_stocktake_lines`, `erp_stocktake_expense_items`; RPCs إنشاء/حفظ العد/ترحيل الجرد |
| 101 | جامع صور الأصناف | ErpImageCollectorScreen | `erp_items`, `erp_item_categories`, `erp_item_units`; التخزين في bytea حسب سياسة الصور |
| 102، 103 | استيراد بيانات أصناف؛ تنزيل بيانات أصناف | ErpItemDataImportDownloadScreen | عمليات ملفية؛ يجب أن تنتهي إلى `erp_items`, `erp_item_categories`, `erp_item_units` مع تحقق staging/duplicate/report |
| 104، 105، 106 | أرصدة الأصناف؛ كارت الصنف؛ الجرد والفروق | ErpInventoryScreen / ErpReportCenter حسب المسار | View `erp_stock_balances`, `erp_inventory_movements`, `erp_stocktakes`; التقرير يجب أن يفصل المتاح والمحجوز والتشغيلات |
| 117 | قوائم أسعار الموردين | ErpPriceListsScreen | `erp_price_lists`, `erp_price_list_lines`, `erp_party_price_lists`, `erp_currencies`, `erp_items`, `erp_item_units`, `erp_parties` |
| 118، 145 | بيانات الموردين؛ بيانات العملاء | ErpPartiesScreen | `erp_parties`, `erp_party_classifications`, `erp_party_contacts`, `erp_geographic_data`, `erp_employees`; customer geo-code RPC |
| 122، 123، 124، 125، 126 | طلب شراء؛ أمر شراء؛ استلام مشتريات؛ فاتورة مشتريات؛ مرتجع مشتريات | ErpOperationalDocumentsScreen | `erp_purchase_documents`, `erp_purchase_lines`, `erp_items`, `erp_parties`, `erp_item_units`; RPCs إضافة سطور v2 وحل السعر |
| 127 | مؤجلات وعمولات الموردين | ErpSupplierDeferredCommissionsScreen | `erp_supplier_deferred_commissions`, `erp_program_policies` |
| 138 | قوائم أسعار البيع | ErpPriceListsScreen | `erp_price_lists`, `erp_price_list_lines`, `erp_party_price_lists`; يلزم تحديد default price list حسب الطرف/الفرع |
| 140 | سياسات التسعير والخصومات | _pricingPolicyScreen | يلزم تثبيت مصدر السياسات الفعلي ومصفوفة حدود الخصم؛ لا تعتمد الواجهة وحدها |
| 141 | توزيع الأصناف على المندوبين | ErpDelegateAllocationScreen | `erp_delegate_item_assignments`, `erp_employees`, `erp_items` |
| 142 | قيود البيع والشراء | _transactionRestrictionsScreen | يلزم توثيق policy keys والمخزن/الفرع/الطرف/المستخدم ومكان فرضها خادميًا |
| 148 | حدود الائتمان | ErpCustomerCreditScreen | `erp_parties.credit_limit`; يلزم رصيد AR محسوب من دفتر الأستاذ/السندات لا من الفواتير فقط |
| 150 | بيانات مندوبين المبيعات | ErpSalesTargetsCommissionsScreen | `erp_sales_representatives`, `erp_employees` |
| 152 | قاعدة العملاء المحتملين | ErpPublicLeadsScreen / Facebook CRM | `erp_public_lead_staging`, RPC `erp_import_public_lead`; مراجعة قبل التحويل إلى party |
| 153، 155، 175 | أهداف المبيعات؛ خطط العمولة؛ مسودات العمولات | ErpSalesTargetsCommissionsScreen | `erp_customer_monthly_goals`, `erp_commission_plans`, `erp_commission_tiers`, `erp_commission_runs`, `erp_sales_documents` |
| 156، 157، 158، 159 | عروض الأصناف؛ مجلات عروض العملاء؛ عروض الترويج؛ عروض الرواكد | ErpItemOffersScreen | `erp_sales_campaigns`, `erp_sales_campaign_items`; يلزم قواعد تعارض/صلاحية/استنفاد كميات |
| 160 | نواقص العملاء | ErpCustomerShortagesScreen | `erp_customer_shortages`, `erp_parties`, `erp_items` |
| 161، 162، 163، 164 | عرض سعر؛ أمر بيع؛ فاتورة بيع؛ مرتجع مبيعات | ErpOperationalDocumentsScreen | `erp_sales_documents`, `erp_sales_lines`, `erp_parties`, `erp_items`, `erp_item_units`, reservations; RPCs إضافة سطور v2 وحل السعر |
| 165، 166 | إذن التجهيز؛ إذن التسليم | ErpSalesFulfillmentScreen | `erp_sales_fulfillment_documents`, `erp_sales_documents`, `erp_parties`; يلزم تسوية حالة الحجز والصرف |
| 168، 173 | تحصيلات العملاء؛ تحصيل نقدي | ErpCashVouchersScreen / ErpFinancialOperationsScreen | `erp_cash_vouchers`, `erp_cash_movements`, `erp_parties`; يجب ربط القبض بفواتير/أرصدة الطرف |
| 283 | إضافة حسابات جروبات فيسبوك | ErpFacebookGroupLeadsScreen | `erp_crm_facebook_groups`, `erp_crm_facebook_profiles`, `erp_crm_facebook_group_profiles`, `erp_crm_facebook_interactions` |
| 284 | سحب أرقام جروبات واتساب | ErpWhatsappContactsScreen | `erp_whatsapp_import_batches`, `erp_whatsapp_import_contacts`; يلزم consent/source/provenance وسياسة احتفاظ |

## 3. نتائج تقنية مهمة من مسارات الربط
1. **إدارة مفاتيح API**: تم ربط إصدار/عرض metadata/إلغاء المفاتيح بقاعدة البيانات، مع تخزين SHA-256 فقط وظهور السر مرة واحدة، وربط بوابة قراءة محددة النطاقات ومحددة المعدل. يظل اختبار HTTP من عميل خارجي واختبار Flutter ضمن مرحلة الاختبار الشاملة.
2. **سجل العمليات**: الشاشة تستخدم سجل الشركة المركزي `erp_app_activity_log`، كما تسجل دورة مفاتيح API عمليات الإصدار والإلغاء. لا يعني ذلك اكتمال تغطية كل عمليات ERP؛ يلزم تدقيق جميع مسارات الكتابة قبل إعلان اكتمال التدقيق الشامل.
3. **اعتماد القيود**: route «قائمة اعتماد القيود» يمرر `initialStatus: draft`. يجب تحديد حالات submitted/pending_approval قبل ربط الموافقات.
4. **الصور والإعلانات**: البيانات الوصفية في `erp_app_assets` والملفات في Storage. يلزم فصل bucket العام للإعلانات عن صور الموظفين/الموردين/العملاء الخاصة، مع signed URLs وانتهاء صلاحية.
5. **الأستاذ والمخزون**: Views `erp_general_ledger` و`erp_stock_balances` موجودة؛ يجب تثبيت أنها security_invoker وأن صلاحيات المصدر لا تتسرب عبرها.
6. **العمليات المحاسبية**: `erp_post_operational_document_accounting` يربط مستندات التشغيل بالأستاذ عبر `erp_operational_account_mappings`; يجب أن يكون idempotent وأن يرفض المستند غير المعتمد أو المرحل مسبقًا.
7. **مسح البيانات**: RPCs تحضير/إكمال المسح موجودة؛ يجب اختبار الاستعادة واحتفاظ ملفات Storage والعضويات والمستخدمين وبيانات التكويد قبل أي تنفيذ إنتاجي.
8. **الفاتورة الإلكترونية**: وجود `erp_einvoice_settings` و`erp_einvoice_operations` لا يثبت اتصالًا مع الهيئة أو صحة توقيع/شهادة؛ يلزم backend موثوق وتوقيع رقمي واختبار حقيقي قبل وصفها كتكامل فعلي.
9. **استيراد الأصناف**: يجب أن تكون هناك مرحلة staging وملف أخطاء وتحقق من الكود/الفئة/البراند/الوحدة والباركود، ثم upsert مضبوط؛ لا يستورد الملف مباشرة إلى جدول الإنتاج دون معاينة.
10. **WhatsApp/Facebook leads**: يجب احترام الموافقات والخصوصية ومصدر البيانات والحد من البيانات الشخصية؛ تحويل lead إلى party يجب أن يكون بعد مراجعة وتفادي التكرار.

## 4. شروط إغلاق الـ96 مسارًا
- Route Registry واحد صريح؛ لا تعتمد على شروط أسماء متفرقة متضاربة.
- كل صفحة مرتبطة بمصدر فعلي أو محددة بوضوح ككيان جديد مطلوب.
- كل عملية كتابة تمر عبر RLS/RPC وتحقق الشركة/الفرع/المخزن.
- المستندات متعددة السطور لها line tables وقيود FK؛ لا تخزنها كنص أو JSON عام.
- كل عملية اعتماد/ترحيل/عكس تسجل أثرًا خادميًا وتمنع التكرار.
- كل تقرير له مصدر محسوب ومعادلة ومصالحة؛ لا يستخدم قارئ خام `select('*')`.
- مفاتيح API والشهادات لا تحفظ أو تعرض على Flutter.
- كل مرفق له bucket وRLS/Storage policy وsigned URL حسب الخصوصية.
- RTL والموبايل والطباعة والتصدير تخضع لمعايير المشروع الموحدة في الاختبار الشامل.

## 5. الحدود
هذه مطابقة تصميمية من كود المسارات والـrepositories وSupabase catalog. لم يتم تعديل أي شاشة أو SQL أو بيانات. لم يتم تشغيل اختبارات أو بناء APK/Web أو نشر.


## 6. الوصول السريع وإدارة النشاط
- قائمة الوصول السريع في `erp_dashboard_screen.dart` أصبحت تقتصر على «فاتورة البيع» و«جامع صور الأصناف»؛ وأزيل «إدارة نشاطي» منها في commit `f28c5911d655e975c50932771d8ff7d8ad00369f`.
- التصميم المعتمد للمشروع يقصر الوصول السريع على «فاتورة البيع» و«جامع صور الأصناف» فقط؛ «إدارة نشاطي» تبقى في القائمة الرئيسية تحت «إدارة نشاط».
- لا تنشئ شاشة «إدارة نشاطي» نشاطًا جديدًا؛ تربط نشاطًا قائمًا بحساب/شركة قائمة، وتكون معاينة حسابات المورد/العميل لمدير سلسلة فقط.
- يوجد RPC `erp_admin_link_existing_activity_account` ودوال عرض الحسابات غير المرتبطة؛ يلزم استمرار التحقق من مستخدم منصة سلسلة ومنع تكرار الربط.
- تم تعديل الوصول السريع فعليًا وإزالة «إدارة نشاطي» منه؛ وتبقى «إدارة نشاطي» في القائمة الرئيسية فقط.
