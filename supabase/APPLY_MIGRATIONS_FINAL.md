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
10. `10_admin_account_queue.sql`
11. `11_approved_supplier_details_view.sql`
12. `12_wallet_order_payments.sql`
13. `13_wallet_order_refunds.sql`
14. `14_atomic_multi_supplier_checkout.sql`
15. `15_supplier_favorites.sql`
16. `16_admin_wallet_topups.sql`
17. `17_order_notifications.sql`
18. `18_shipping_operations.sql`
19. `19_admin_support_tickets.sql`
20. `20_profile_privilege_hardening.sql`
21. `21_shipping_delivery_creation_hardening.sql`
22. `22_atomic_default_address.sql`
23. `23_atomic_default_address_save.sql`
24. `24_foreign_key_indexes.sql`
25. `25_trigger_function_rpc_hardening.sql`
26. `26_offer_item_minimum_quantity.sql`
27. `27_trader_market_negotiations.sql`

تجنب تشغيل النسخ القديمة `03_secure_checkout.sql` و`04_service_compatibility.sql`؛ استخدم النسخ ذات اللاحقة `fixed` المذكورة أعلاه.

في إدارة المخزون، الحقل `track_inventory` يحدد ما إذا كان المخزون يُدار فعليًا. عند تفعيله، يمنع النظام طلب كمية أكبر من المتاح ويخصم الكمية ضمن معاملة إنشاء الطلب. إذا لم يُفعّل، لا يُعامل الصفر باعتباره نفاد مخزون.

بعد الترحيلات، عيّن حساب المسؤول الموثوق يدويًا من SQL Editor: حدّث حسابه ليكون `account_type = 'إدارة نشاط'` و`role = 'admin'`. لا تمنح هذه الصلاحية من واجهة التسجيل. ترحيل الخصوصية الأخير يجعل بيانات الضرائب والسجل التجاري خاصة بالمورد ولا يعرض عنوان الملف الشخصي ضمن دليل الموردين. ترحيل السياسات الأخير يمنع الحسابات غير المعتمدة من نشر المنتجات والعروض والقصص وإعلانات السوق، ويشترط طلبًا مسلّمًا لإضافة تقييم.

ترحيلات GitHub لا تُطبّق تلقائيًا على Supabase. شغّل كل ملف يدويًا بالترتيب، ولا تضع مفتاح `service_role` داخل تطبيق Flutter. الترحيل 21 يقيّد إنشاء طلب الشحن ليكون الحساب طالب الشحنة طرفًا في الطلب، وأن تكون شركة الشحن المسندة نشطة. الترحيل 22 يضيف عملية ذرية لتعيين العنوان الافتراضي. الترحيل 23 يجعل إضافة العنوان الافتراضي أو تعديله عملية ذرية واحدة، مع التحقق من ملكية العنوان والإحداثيات.


## إعداد أول مسؤول بشكل آمن

بعد تطبيق جميع الترحيلات، يجب تعيين حساب المسؤول الأول يدويًا من Supabase SQL Editor باستخدام معرّف مستخدم موثوق من جدول Authentication. لا تسمح بترقية الحساب من داخل التطبيق.

```sql
BEGIN;
ALTER TABLE public.profiles DISABLE TRIGGER silsila_profiles_role_compatibility;
UPDATE public.profiles
SET role = 'admin', account_status = 'approved', updated_at = NOW()
WHERE id = 'ضع-UUID-حساب-المسؤول-الموثوق-هنا';
ALTER TABLE public.profiles ENABLE TRIGGER silsila_profiles_role_compatibility;
COMMIT;
```

استبدل القيمة بالـ UUID الصحيح فقط، وتأكد من وجود صف الملف الشخصي لهذا المستخدم. لا تشغّل هذا الإجراء على حساب غير موثوق.


ترحيل 26 يضيف `min_quantity` إلى `offer_items` لتخزين أقل كمية مطلوبة لكل صنف داخل مجلة العرض. شغّله بعد الترحيلات 1–25 قبل اختبار نشر عروض تحتوي على أقل كمية.

ترحيل 27 يضيف تاريخ انتهاء طلب سوق التجار وخيار قابلية التفاوض، وينشئ سجلًا لتبادل أسعار التفاوض بين الطرفين. شغّله بعد الترحيلات السابقة قبل استخدام حقول التفاوض وتاريخ الصلاحية.

## تهيئة جداول مساحة عمل ERP

بعد تطبيق مخطط ERP الأساسي وسياسات عضوية الشركة، شغّل الملف `supabase/erp_workspace_settings_records_security.sql` مرة واحدة. ينشئ إعدادات الشركة وسجلات الشاشات العامة مع تفعيل RLS وتقييد القراءة والكتابة بعضوية الشركة ودورها. تم تصميمه ليكون إضافيًا وآمنًا لإعادة التشغيل؛ لا يحذف بيانات موجودة.

