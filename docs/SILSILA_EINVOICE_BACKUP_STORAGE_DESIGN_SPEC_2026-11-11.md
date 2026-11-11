# مواصفات إغلاق الفاتورة الإلكترونية والنسخ الاحتياطي والتخزين — سلسلة ERP
التاريخ: 2026-11-11
المصادر: `erp_einvoice_screen.dart`، جداول Supabase الحية، `erp_clear_data_screen.dart`، `erp_data_backups`، وStorage buckets/policies.

## 1. الحالة الفعلية للفاتورة الإلكترونية

### 1.1 الموجود الآن
- جداول public ذات الصلة فقط: `erp_einvoice_settings` و`erp_einvoice_operations`.
- `erp_einvoice_settings` يحتوي taxpayer_number, branch_code, activity_code, client_id, environment, connection_status, updated_by, updated_at.
- `erp_einvoice_operations` يحتوي action_key, document_type, reference_query, status, details JSONB, response_data JSONB, created_by, created_at, processed_at.
- الشاشة تعرض 24 وجهة، وتقرأ/تكتب هذين الجدولين فقط.
- لا يوجد في الشاشة RPC أو Edge Function أو HTTP client يتصل بمنظومة الضرائب.
- زر اختبار الاتصال/الإرسال/الإلغاء/القبول/الرفض/البحث/تنزيل الحزم يسجل صفًا في `erp_einvoice_operations` بحالة `pending_setup` ورسالة صريحة بأن الطلب لم يُرسل إلى الهيئة.
- حفظ الإعدادات يغير `connection_status` إلى نص يفيد بأن الاتصال لم يتم اختباره.
- لا توجد جداول مخصصة ظاهرة لتكويد السلع والخدمات أو خريطة أكواد الضرائب أو الشهادات أو payloads أو مستندات واردة/صادرة أو سجل محاولات وإعادة إرسال.

**النتيجة:** الشاشة الحالية واجهة إعداد وتسجيل طلبات داخلية فقط؛ لا يجوز وصفها بأنها تكامل ضريبي فعلي أو اختبار اتصال ناجح.

## 2. عقد التكامل الضريبي المستهدف

### 2.1 إعدادات الممول والفرع
الجدول الحالي `erp_einvoice_settings` يحتفظ بالبيانات غير السرية فقط:
- company_id, taxpayer_number, branch_code, activity_code, environment.
- certificate_secret_ref (مرجع إلى secret vault، لا قيمة الشهادة أو private key).
- client_id إن كان معرفًا عامًا لا سرًا؛ أما client_secret في vault.
- certificate_thumbprint, certificate_expiry, certificate_status.
- schema_version, api_base_profile, enabled, updated_by/at.

لا تُخزن private key أو password أو bearer token في Flutter أو `erp_program_policies` أو `details JSONB`. يقتصر Flutter على عرض حالة/انتهاء الشهادة دون استرجاع السر.

### 2.2 كتالوج ربط السلع والخدمات
كيان مقترح `erp_einvoice_item_mappings`:
- company_id, item_id أو service_id (واحد فقط)، tax_item_code, tax_item_type, tax_unit_code, internal_unit_id, conversion_factor, tax_category, effective_from/to, is_active, approved_by/at.
- unique per company + item/service + effective range.
- التحقق من كود الوحدة والسلعة حسب قاموس الهيئة من خدمة خادمية مؤرخة؛ لا يكتب المستخدم كودًا حرًا بلا validation.

### 2.3 طابور المستندات ومحاولات الإرسال
توسيع `erp_einvoice_operations` أو إنشاء queue/attempt tables منفصلة:
- operation_id, company_id, source_document_type, source_document_id, action_key, idempotency_key, correlation_id.
- status: queued, processing, submitted, accepted, rejected, retry_wait, failed, cancelled.
- tax_document_uuid, submission_uuid, http_status, authority_error_code, authority_error_message, request_hash, response_hash.
- attempt_count, next_retry_at, processed_at, worker_id, created_by.
- request/response redacted JSON أو private object path؛ لا تحفظ أسرارًا أو بيانات اعتماد.
- جدول `erp_einvoice_operation_attempts` append-only لكل محاولة مع زمنها ونتيجتها ورسالة الخطأ المنقحة.

### 2.4 دورة المستند
1. التحقق من إعدادات الشركة/الفرع والبيئة والشهادة.
2. تحديد المستند المصدر وحالته: فاتورة/إشعار دائن/إشعار مدين؛ يمنع إرسال draft أو مستند غير مرحّل.
3. تحويل رأس المستند والسطور إلى payload وفق schema version معتمد، مع أكواد الضريبة والوحدة.
4. التحقق المحلي والخادمي من الأرقام والضرائب والإجماليات والعملات والعميل/المورد.
5. توقيع payload خادميًا باستخدام شهادة محفوظة في Vault/خدمة آمنة.
6. إدراج operation بمعرف idempotency قبل الإرسال.
7. إرسال عبر Edge Function/worker باستخدام secret server-side فقط.
8. تسجيل submission UUID وresponse/error دون حفظ الأسرار.
9. polling للنتيجة وإدارة accepted/rejected/retry.
10. الإلغاء والإشعارات الدائنة/المدينة تخضع لقواعد الهيئة وحالة المستند الأصلي؛ لا تسجل كـgeneric action فقط.
11. طباعة PDF/تنزيل حزمة المستندات يعتمد على payload/response المعتمد، لا إنشاء PDF محلي يوحي بأنه مستند ضريبي معتمد.

### 2.5 واجهات الخادم المقترحة
هذه أسماء تصميمية وليست موجودة حاليًا:
- `einvoice_validate_document`
- `einvoice_queue_document`
- `einvoice_submit_worker`
- `einvoice_poll_status`
- `einvoice_cancel_document`
- `einvoice_handle_incoming_document`
- `einvoice_request_document_package`
- `einvoice_test_connection`

كل واجهة تتحقق من الشركة والفرع والدور، وتستخدم idempotency، وتكتب سجل تدقيق. لا تُمنح anon صلاحية لهذه الدوال.

## 3. مواصفات النسخ الاحتياطي والمسح الانتقائي

### 3.1 الواقع الحالي
- `erp_data_backups` يحتوي backup_type, selected_pages, record_count, payload JSONB, created_by, created_at.
- توجد دالتان فقط: `erp_prepare_selective_data_clear` و`erp_complete_selective_data_clear`.
- شاشة مسح البيانات تستخدم التحضير ثم الإكمال.
- لم يظهر RPC لاستعادة نسخة انتقائية، ولا bucket خاص للنسخ الاحتياطية.
- `payload JSONB` هو لقطة بيانات انتقائية، وليس نسخة PostgreSQL كاملة ولا يثبت قابلية استعادة العلاقات والملفات.

### 3.2 عقد النسخة الانتقائية
- backup_id UUID غير قابل للتكرار، company_id، schema_version، app_version، selected_pages، table_manifest، record_count، checksum، created_by، created_at، status.
- يحفظ payload صغيرًا في DB أو ملف JSON/NDJSON مشفرًا في bucket خاص `erp-backups` مع storage_path وchecksum؛ يفضل عدم تضخيم صف JSONB عند أحجام كبيرة.
- table_manifest يحدد ترتيب الاستعادة والعلاقات والجداول التابعة والاستثناءات.
- لا تُنسخ كلمات مرور أو tokens أو private keys أو بيانات Auth غير القابلة للاستعادة.
- الملفات في Storage تحفظ manifest لمساراتها، ولا تعتبر نسخة بيانات DB كافية لاستعادة الملفات.

### 3.3 دورة المسح
1. Preview فقط: يعرض عدد السجلات لكل جدول، الجداول التابعة، والمستثنيات؛ لا حذف.
2. إنشاء snapshot/checksum والتحقق من نجاحه.
3. تأكيد ثانٍ من مستخدم مخول، مع إدخال نص تأكيد وسبب العملية.
4. تنفيذ حذف في RPC واحدة/دفعات محكومة مع سجل audit.
5. تسجيل كل جدول وعدد المحذوف والمستثنى والفشل.
6. بعد النجاح، إعادة تحميل النظام والتحقق من بقاء الشركة والمستخدمين والعضويات والسياسات والمرجعيات.
7. لا تحذف أي بيانات فعلية للمستخدم بالاسم أو الكود وحدهما؛ רשימת IDs المستهدفة و`is_demo_data` الموثوق مع Preview وموافقة.

### 3.4 الاستعادة
إضافة `erp_restore_selective_data_backup` بتدفق:
- Preview compatibility: schema version، table set، FK conflicts، uniqueness، missing reference.
- اختيار الاستعادة الكاملة أو صفحات محددة.
- Transactional restore أو staged import مع rollback.
- تعارضات: skip/replace فقط وفق سياسة واضحة، لا overwrite صامت.
- إعادة إنشاء العلاقات بترتيب parent→child.
- استعادة ملفات Storage من backup manifest.
- سجل من قام بالاستعادة والسبب وعدد السجلات.
- لا يسمح بالاستعادة فوق مستندات مالية مرحّلة دون مسار تعويض/عكس معتمد.

### 3.5 النسخ الكامل وPITR
النسخة الكاملة واستعادة نقطة زمنية مسؤولية منصة Supabase/خطة النسخ الاحتياطي، وليست جدول `erp_data_backups`. يجب تحديد سياسة RPO/RTO ومدة الاحتفاظ وتجربة restore على بيئة معتمدة قبل الإنتاج. لا تنشأ بيئة Preview دائمة لهذا المشروع؛ اختبار الاستعادة يتم ضمن نافذة صيانة/إجراء مضبوط مع موافقة المستخدم.

## 4. Storage buckets الحالية وقراراتها

| Bucket | public | حد الحجم | MIME المسموح | الاستخدام/القرار |
|---|---:|---:|---|---|
| `erp-company-assets` | لا | 8 MB | JPEG/PNG/WebP/GIF | خاص؛ شعارات الشركة والأصول، وتستخدمه سياسات مستندات الموظفين أيضًا |
| `silsila-public-ads` | نعم | 50 MB | JPEG/PNG/WebP/GIF/MP4 | إعلان عام؛ الكتابة والحذف للمسؤولين فقط حسب الشركة والتطبيق |
| `products` | نعم | غير محدد | غير محدد | صور عامة للمنتجات؛ لا تخزن فيه مستندات أو ملفات شخصية |
| `offers` | نعم | غير محدد | غير محدد | صور عروض عامة |
| `stories` | نعم | غير محدد | غير محدد | وسائط قصص عامة |
| `profiles` | نعم | غير محدد | غير محدد | صور ملفات عامة؛ يلزم حصر المحتوى على صور الملف فقط |

### 4.1 فجوات Storage
- سياسات `erp-company-assets` تستخدم `erp_user_has_company_role(owner/admin/manager)` لمستندات الموظفين، ولا تمنح HR manager صراحةً ما لم يكن أيضًا manager.
- Bucket `erp-company-assets` يسمح بأنواع صور فقط، رغم وجود مسار `employee_documents`; ملفات PDF/DOCX غير مسموح بها وفق bucket MIME الحالي.
- لا يوجد bucket خاص للنسخ الاحتياطية أو الشهادات الضريبية.
- bucket `profiles` عام وسياسة SELECT عامة لكل كائناته؛ يجب التأكد أن الكائنات لا تحتوي وثائق أو صور خاصة غير مخصصة للنشر.
- `products/offers/stories` عامة؛ يجب أن يكون المسار/البيانات المنشورة فقط هي التي ترفع لهذه buckets، وألا تعتمد خصوصية الطرف على اسم المجلد وحده.
- صور فئات الأصناف يجب أن تظل bytes داخل قاعدة البيانات حسب قرار المشروع، ولا تستبدل بمسارات عامة أو URLs خارجية.

### 4.2 تنظيم Storage المستهدف
- `erp-company-assets`: شعار/أيقونة/صور الشركة فقط، مع MIME محدد.
- `erp-employee-documents`: private، PDF/JPEG/PNG/WebP، حدود حجم مناسبة، سياسات HR حسب employee scope.
- `erp-backups`: private service-only، تشفير وchecksum وانتهاء صلاحية signed URL.
- `erp-tax-certificates`: private service-only أو Vault؛ لا download مباشر من Flutter.
- buckets العامة تبقى للمحتوى الذي وافق المستخدم على نشره فقط.

## 5. حدود المراجعة
هذه مواصفات تصميمية مبنية على الجداول والشاشة وStorage catalog/policies. لم يتم الاتصال بمصلحة الضرائب، ولم تُرسل مستندات، ولم يتم رفع شهادة أو حفظ سر، ولم يتم إنشاء bucket أو تغيير policy أو حذف/استعادة بيانات.
