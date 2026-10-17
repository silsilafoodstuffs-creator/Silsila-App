# سلسلة Silsila — ترتيب التهيئة النهائي لقاعدة Supabase

استخدم الملفات التالية بالترتيب من SQL Editor في مشروع Supabase:

1. `01_core_schema.sql`
2. `02_activity_classifications.sql`
3. `03_secure_checkout_fixed.sql`
4. `04_service_compatibility_fixed.sql`
5. `05_storage_policies.sql`
6. `06_admin_account_approval.sql`
7. `07_security_role_hardening.sql`
8. `08_supplier_data_privacy.sql`
9. `09_approved_marketplace_policies.sql`

تجنب تشغيل النسخ القديمة `03_secure_checkout.sql` و`04_service_compatibility.sql`؛ استخدم النسخ ذات اللاحقة `fixed` المذكورة أعلاه.

في إدارة المخزون، الحقل `track_inventory` يحدد ما إذا كان المخزون يُدار فعليًا. عند تفعيله، يمنع النظام طلب كمية أكبر من المتاح ويخصم الكمية ضمن معاملة إنشاء الطلب. إذا لم يُفعّل، لا يُعامل الصفر باعتباره نفاد مخزون.

بعد الترحيلات، عيّن حساب المسؤول الموثوق يدويًا من SQL Editor: حدّث حسابه ليكون `account_type = 'إدارة نشاط'` و`role = 'admin'`. لا تمنح هذه الصلاحية من واجهة التسجيل. ترحيل الخصوصية الأخير يجعل بيانات الضرائب والسجل التجاري خاصة بالمورد ولا يعرض عنوان الملف الشخصي ضمن دليل الموردين. ترحيل السياسات الأخير يمنع الحسابات غير المعتمدة من نشر المنتجات والعروض والقصص وإعلانات السوق، ويشترط طلبًا مسلّمًا لإضافة تقييم.

ترحيلات GitHub لا تُطبّق تلقائيًا على Supabase. شغّل كل ملف يدويًا بالترتيب، ولا تضع مفتاح `service_role` داخل تطبيق Flutter.
