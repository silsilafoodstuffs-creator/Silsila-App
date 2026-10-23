-- Idempotent supplementary Cairo locality seed for Silsila ERP.
-- These are commonly used local/neighborhood names, NOT an official administrative
-- register. Verify names and parent boundaries locally before treating them as official.
-- The official governorate/district hierarchy remains in erp_geographic_data.
with seed(parent_name, area_name, geo_code) as (
  values
    ('قسم السلام', 'أطلس 1 - القسم', 'EG-LOCAL-SALAM-ATLAS1'),
    ('قسم السلام', 'أطلس 2 - الصالون الأخضر', 'EG-LOCAL-SALAM-ATLAS2'),
    ('قسم السلام', 'أطلس 3 - ستاد المحافظ', 'EG-LOCAL-SALAM-ATLAS3'),
    ('قسم السلام', 'أطلس 4', 'EG-LOCAL-SALAM-ATLAS4'),
    ('قسم السلام', 'ميدان الإسكندرية', 'EG-LOCAL-SALAM-ALEX-SQ'),
    ('قسم السلام', 'ميدان إسبكو', 'EG-LOCAL-SALAM-ESPCO-SQ'),
    ('قسم السلام', 'زهراء إسبكو', 'EG-LOCAL-SALAM-ZAHRAA-ESPCO'),
    ('قسم السلام', 'النيل K', 'EG-LOCAL-SALAM-NILE-K'),
    ('قسم السلام', 'تقسيم مكة', 'EG-LOCAL-SALAM-MAKKA'),
    ('قسم السلام', 'مساكن الضباط', 'EG-LOCAL-SALAM-OFFICERS'),
    ('قسم السلام', 'مساكن BBC', 'EG-LOCAL-SALAM-BBC'),
    ('قسم السلام', 'ونش إسكندرية', 'EG-LOCAL-SALAM-ALEX-WINCH'),
    ('قسم السلام', 'سوق إسبكو', 'EG-LOCAL-SALAM-ESPCO-MARKET'),
    ('قسم السلام', 'تروللي إسبكو', 'EG-LOCAL-SALAM-ESPCO-TROLLEY'),
    ('قسم السلام', 'الشوارع الجديدة', 'EG-LOCAL-SALAM-NEW-STREETS'),
    ('قسم السلام', 'موقف السلام', 'EG-LOCAL-SALAM-STATION'),
    ('قسم السلام', 'القسم القديم', 'EG-LOCAL-SALAM-OLD-QISM'),
    ('قسم السلام', 'محطة عدلي منصور', 'EG-LOCAL-SALAM-ADLY-MANSOUR'),
    ('قسم شبرا', 'كلية الزراعة', 'EG-LOCAL-SHUBRA-AGRI-COLLEGE'),
    ('قسم شبرا', 'سانت تريز', 'EG-LOCAL-SHUBRA-ST-THERESA'),
    ('قسم شبرا', 'عرابي', 'EG-LOCAL-SHUBRA-ORABI'),
    ('قسم شبرا', 'جسر شبرا', 'EG-LOCAL-SHUBRA-BRIDGE'),
    ('قسم شبرا', 'الخلفاوي', 'EG-LOCAL-SHUBRA-KHALAFAWY'),
    ('قسم روض الفرج', 'منطقة روض الفرج (اسم محلي غير موثق)', 'EG-LOCAL-EGDISTEG0120-RF01'),
    ('قسم مصر الجديدة', 'الكوربة', 'EG-LOCAL-HELIO-KORBA'),
    ('قسم مصر الجديدة', 'روكسي', 'EG-LOCAL-HELIO-ROXY'),
    ('قسم مصر الجديدة', 'أرض الجولف', 'EG-LOCAL-HELIO-GOLF'),
    ('قسم مصر الجديدة', 'الميريلاند', 'EG-LOCAL-HELIO-MERYLAND'),
    ('قسم مصر الجديدة', 'منشية البكري', 'EG-LOCAL-HELIO-MANSHIA'),
    ('قسم المعادي', 'زهراء المعادي', 'EG-LOCAL-MAADI-ZAHRAA'),
    ('قسم المعادي', 'دجلة المعادي', 'EG-LOCAL-MAADI-DEGLA'),
    ('قسم المعادي', 'حدائق المعادي', 'EG-LOCAL-MAADI-GARDENS'),
    ('قسم المعادي', 'ثكنات المعادي', 'EG-LOCAL-MAADI-THAKANAT'),
    ('قسم المعادي', 'المعادي السرايات', 'EG-LOCAL-MAADI-SARAYAT'),
    ('قسم عين شمس', 'ألف مسكن', 'EG-LOCAL-AINSHAMS-ALF'),
    ('قسم عين شمس', 'عرب الجسر', 'EG-LOCAL-AINSHAMS-ARAB'),
    ('قسم عين شمس', 'شارع أحمد عصمت', 'EG-LOCAL-AINSHAMS-AHMEDESSMAT'),
    ('قسم المطرية', 'ميدان المطرية', 'EG-LOCAL-MATARIA-SQUARE'),
    ('قسم المطرية', 'عزبة النخل', 'EG-LOCAL-MATARIA-EZBET'),
    ('قسم الزيتون', 'حدائق الزيتون', 'EG-LOCAL-ZEITOUN-GARDENS'),
    ('قسم الزيتون', 'حلمية الزيتون', 'EG-LOCAL-ZEITOUN-HELMEYA'),
    ('قسم النزهة', 'شيراتون', 'EG-LOCAL-NOZHA-SHERATON'),
    ('قسم النزهة', 'أرض الجولف - النزهة', 'EG-LOCAL-NOZHA-GOLF'),
    ('قسم النزهة', 'النزهة الجديدة', 'EG-LOCAL-NOZHA-NEW'),
    ('قسم النزهة', 'ميدان الحجاز', 'EG-LOCAL-NOZHA-HEGAZ'),
    ('قسم حلوان', 'حدائق حلوان', 'EG-LOCAL-HELWAN-GARDENS'),
    ('قسم حلوان', 'المعصرة', 'EG-LOCAL-HELWAN-MAASARA'),
    ('قسم البساتين', 'عزبة النصر', 'EG-LOCAL-BASATEEN-EZBETNASR'),
    ('قسم البساتين', 'فايدة كامل', 'EG-LOCAL-BASATEEN-FAYDA'),
    ('قسم المرج', 'المرج الجديدة', 'EG-LOCAL-MARG-NEW'),
    ('قسم المرج', 'عزبة النخل', 'EG-LOCAL-MARG-EZBETNAKHL'),
    ('قسم الزاوية الحمراء', 'أرض الجنينة', 'EG-LOCAL-ZAWYA-GENENA'),
    ('قسم الزاوية الحمراء', 'مساكن الزاوية', 'EG-LOCAL-ZAWYA-HOUSING'),
    ('قسم الشروق', 'الحي الأول', 'EG-LOCAL-SHOROUK-DIST1'),
    ('قسم الشروق', 'الحي الثاني', 'EG-LOCAL-SHOROUK-DIST2'),
    ('قسم السلام', 'مساكن النهضة', 'EG-LOCAL-SALAM-NAHDA'),
    ('قسم أول مدينة نصر', 'شارع عباس العقاد', 'EG-LOCAL-NASR1-ABBAS'),
    ('قسم أول مدينة نصر', 'شارع مكرم عبيد', 'EG-LOCAL-NASR1-MAKRAM'),
    ('قسم أول مدينة نصر', 'شارع مصطفى النحاس', 'EG-LOCAL-NASR1-MOSTAFA'),
    ('قسم أول مدينة نصر', 'الحي السابع', 'EG-LOCAL-NASR1-DIST7'),
    ('قسم أول مدينة نصر', 'الحي الثامن', 'EG-LOCAL-NASR1-DIST8'),
    ('قسم ثان مدينة نصر', 'زهراء مدينة نصر', 'EG-LOCAL-NASR2-ZAHRAA'),
    ('قسم ثان مدينة نصر', 'الحي العاشر', 'EG-LOCAL-NASR2-DIST10'),
    ('قسم حدائق القبة', 'سراي القبة', 'EG-LOCAL-QOBA-SARAY'),
    ('قسم حدائق القبة', 'كوبري القبة', 'EG-LOCAL-QOBA-BRIDGE')
)
insert into public.erp_geographic_data
  (company_id, parent_id, geo_code, name_ar, level, is_active,
   source_name, name_source_name, admin_type, admin_type_source)
select
  p.company_id, p.id, s.geo_code, s.area_name, 'area', true,
  'أسماء مناطق متداولة محلياً؛ تحتاج مراجعة محلية',
  'مصطلح محلي غير معتمد رسمياً ولا يحل محل التقسيم الإداري المعتمد',
  'local_area', 'إضافة تشغيلية غير رسمية'
from seed s
join public.erp_geographic_data p
  on p.level = 'district' and p.name_ar = s.parent_name
where not exists (
  select 1
  from public.erp_geographic_data existing
  where existing.company_id = p.company_id
    and existing.parent_id = p.id
    and existing.name_ar = s.area_name
);
