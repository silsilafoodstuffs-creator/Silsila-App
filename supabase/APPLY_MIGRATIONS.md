# ترتيب تطبيق ترحيلات Supabase — سلسلة

شغّل الملفات من SQL Editor في مشروع Supabase بالترتيب التالي:

1. `01_core_schema.sql`
2. `02_activity_classifications.sql`
3. `03_secure_checkout.sql`
4. `04_service_compatibility_fixed.sql`
5. `05_storage_policies.sql`

**مهم:** استخدم `04_service_compatibility_fixed.sql` في الترتيب أعلاه؛ فهو النسخة المصححة من ترحيل التوافق. لا تشغّل النسخة القديمة `04_service_compatibility.sql`.

هذه الملفات لا تُطبّق تلقائيًا بمجرد حفظها في GitHub. شغّل كل ملف في SQL Editor وتأكد من اكتماله قبل الانتقال إلى الملف التالي. لا تستخدم مفتاح `service_role` داخل تطبيق Flutter.

بعد تطبيق الترحيلات، يجب أن يكون لدى حساب المورد ملف مورد معتمد ومنتجات منشورة حتى تظهر منتجات قابلة للطلب. المنتجات التوضيحية في الواجهة ليست منتجات قابلة للشراء.
