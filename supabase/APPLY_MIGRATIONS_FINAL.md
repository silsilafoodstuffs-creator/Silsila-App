# سلسلة Silsila — ترتيب التهيئة النهائي لقاعدة Supabase

استخدم الملفات التالية بالترتيب من SQL Editor في مشروع Supabase:

1. `01_core_schema.sql`
2. `02_activity_classifications.sql`
3. `03_secure_checkout_fixed.sql`
4. `04_service_compatibility_fixed.sql`
5. `05_storage_policies.sql`

تجنب تشغيل النسخ القديمة `03_secure_checkout.sql` و`04_service_compatibility.sql`؛ استخدم النسخ ذات اللاحقة `fixed` المذكورة أعلاه.

في إدارة المخزون، الحقل `track_inventory` يحدد ما إذا كان المخزون يُدار فعليًا. عند تفعيله، يمنع النظام طلب كمية أكبر من المتاح ويخصم الكمية ضمن معاملة إنشاء الطلب. إذا لم يُفعّل، لا يُعامل الصفر باعتباره نفاد مخزون.

ترحيلات GitHub لا تُطبّق تلقائيًا على Supabase. شغّل كل ملف يدويًا بالترتيب، ولا تضع مفتاح `service_role` داخل تطبيق Flutter.
