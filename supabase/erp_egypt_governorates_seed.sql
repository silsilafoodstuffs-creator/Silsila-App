-- Seed the standard 27 Egyptian governorates for every registered ERP company.
-- Safe to rerun; existing rows with these stable codes are updated, not duplicated.
insert into public.erp_geographic_data(company_id,geo_code,name_ar,name_en,level,is_active)
select c.id,v.code,v.name_ar,v.name_en,'governorate',true
from public.erp_companies c
cross join (values
('EG-GOV-01','القاهرة','Cairo'),('EG-GOV-02','الجيزة','Giza'),('EG-GOV-03','القليوبية','Qalyubia'),
('EG-GOV-04','الإسكندرية','Alexandria'),('EG-GOV-05','البحيرة','Beheira'),('EG-GOV-06','مطروح','Matrouh'),
('EG-GOV-07','دمياط','Damietta'),('EG-GOV-08','الدقهلية','Dakahlia'),('EG-GOV-09','كفر الشيخ','Kafr El Sheikh'),
('EG-GOV-10','الغربية','Gharbia'),('EG-GOV-11','المنوفية','Monufia'),('EG-GOV-12','الشرقية','Sharqia'),
('EG-GOV-13','الإسماعيلية','Ismailia'),('EG-GOV-14','بورسعيد','Port Said'),('EG-GOV-15','السويس','Suez'),
('EG-GOV-16','شمال سيناء','North Sinai'),('EG-GOV-17','جنوب سيناء','South Sinai'),('EG-GOV-18','بني سويف','Beni Suef'),
('EG-GOV-19','الفيوم','Faiyum'),('EG-GOV-20','المنيا','Minya'),('EG-GOV-21','أسيوط','Asyut'),
('EG-GOV-22','سوهاج','Sohag'),('EG-GOV-23','قنا','Qena'),('EG-GOV-24','الأقصر','Luxor'),
('EG-GOV-25','أسوان','Aswan'),('EG-GOV-26','البحر الأحمر','Red Sea'),('EG-GOV-27','الوادي الجديد','New Valley')
) as v(code,name_ar,name_en)
on conflict(company_id,geo_code) do update
set name_ar=excluded.name_ar,name_en=excluded.name_en,level='governorate',is_active=true,updated_at=now();
