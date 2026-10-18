-- Public business-directory prospect staging for Silsila.
-- Source names/addresses below were found in public listings and must be verified before CRM import.
-- Do not use this as proof of a supplier relationship or copy private/customer-only competitor data.
-- Apply after erp_schema.sql. Staging rows are not active ERP customers/suppliers.

create table if not exists public.erp_public_lead_staging (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.erp_companies(id) on delete cascade,
  business_name text not null,
  lead_kind text not null default 'potential_customer' check (lead_kind in ('potential_customer','potential_supplier','institution','retail_chain','wholesaler','manufacturer','unknown')),
  business_classification text,
  governorate text,
  district text,
  public_address text,
  public_phone text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  source_name text not null,
  source_url text not null,
  source_record_date date not null default current_date,
  verification_status text not null default 'needs_review' check (verification_status in ('needs_review','verified','duplicate','not_relevant','imported')),
  verification_notes text,
  imported_party_id uuid references public.erp_parties(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_name,source_url,business_name)
);

create index if not exists erp_public_lead_staging_area_idx on public.erp_public_lead_staging(governorate,district);
create index if not exists erp_public_lead_staging_status_idx on public.erp_public_lead_staging(verification_status,lead_kind);
alter table public.erp_public_lead_staging enable row level security;

-- Requires erp_security_membership.sql. Public source records are readable by signed-in users;
-- only company managers can attach/import a lead into their own company.
drop policy if exists erp_public_leads_read_authenticated on public.erp_public_lead_staging;
create policy erp_public_leads_read_authenticated on public.erp_public_lead_staging for select to authenticated using (company_id is null or public.erp_user_can_access_company(company_id));
-- Direct updates are intentionally disabled; use erp_import_public_lead RPC to claim a lead safely.
-- Remove earlier illustrative entries that did not have a sufficiently specific public listing.
delete from public.erp_public_lead_staging
where company_id is null
  and business_name in (
    'Seoudi Supermarket - Sheraton Branch',
    'Seoudi Super Market - New Cairo',
    'El Abed Supermarket',
    'AM GROUP Misr',
    'HORECA STAR',
    'الشركة المصرية لتجارة الجملة - فرع هايبر الطيران',
    'الشركة المصرية لتجارة الجملة - ملحق جملة المطرية',
    'شركة النيل للمجمعات الاستهلاكية - فرع به تموين'
  )
  and verification_status='needs_review';

insert into public.erp_public_lead_staging
(business_name,lead_kind,business_classification,governorate,district,public_address,source_name,source_url,verification_status,verification_notes)
values
('Seoudi Supermarket - New Cairo / The Waterway','potential_customer','سوبر ماركت / سلسلة تجزئة','القاهرة','القاهرة الجديدة','Mohamed Naguib Spine, The Waterway Compound, 1st Compound, New Cairo, Cairo','Egypt Yellow Pages - business profile','https://yellowpages.com.eg/en/profile/%D8%B3%D8%B9%D9%88%D8%AF%D9%89-%D8%B3%D9%88%D8%A8%D8%B1-%D9%85%D8%A7%D8%B1%D9%83%D8%AA/696386?categoryId=3725&inKey=4757&key=%D8%B3%D9%88%D8%A8%D8%B1-%D9%85%D8%A7%D8%B1%D9%83%D8%AA&mod=category&position=7','needs_review','الاسم والعنوان منشوران في صفحة دليل محددة. فرع تجزئة وليس عميل جملة مؤكدًا؛ راجع بيانات الاتصال وملاءمة النشاط.'),
('Seoudi Supermarket - Nasr City','potential_customer','سوبر ماركت / سلسلة تجزئة','القاهرة','مدينة نصر','Mohamed Hassanein Heikal St., off Abbas El Akkad St., Nasr City, Cairo','Egypt Yellow Pages - business profile','https://yellowpages.com.eg/en/profile/%D8%B3%D8%B9%D9%88%D8%AF%D9%89-%D9%85%D8%A7%D8%B1%D9%83%D8%AA/656182','needs_review','صفحة دليل محددة تعرض هذا العنوان؛ تحقق من حالة الفرع الحالية قبل التواصل.'),
('100 Sanf & Sanf Supermarket','potential_customer','سوبر ماركت','القاهرة','دار السلام','55 El Gesr El Barrany St., El Matbaa Sq., Dar El Salam, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','مدرج في نتائج دليل السوبر ماركت بالقاهرة؛ رابط المصدر صفحة تصنيف وليس صفحة فرع منفردة.'),
('2 Friends Market','potential_customer','ماركت / تجزئة','القاهرة','مدينة نصر','21 Ahmed Mohamed Ibrahim St., Nasr City, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','مدرج في نتائج دليل السوبر ماركت بالقاهرة؛ رابط المصدر صفحة تصنيف وليس صفحة فرع منفردة.'),
('2M Wholesale Market','potential_customer','سوبر ماركت / سوق جملة محتمل','القاهرة','مدينة نصر','27 El Obour Buildings, Salah Salem Road, Nasr City, Cairo','Egypt Yellow Pages - wholesale directory','https://yellowpages.com.eg/en/search/wholesale','needs_review','مدرج في دليل الجملة لكن تصنيفه الظاهر سوبر ماركت؛ تحقق من كونه مناسبًا للتوريد أو الشراء بالجملة.'),
('El Hamd For General Supplies','potential_supplier','مورد توريدات عامة ومواد غذائية محتمل','القاهرة','المعادي','13 El Ethad St., intersection of Road 70, Maadi, Cairo','Egypt Yellow Pages - wholesale food category','https://yellowpages.com.eg/en/category/wholesale-food','needs_review','دليل يلوبيدجز يصفه بأنه يقدم توريدات غذائية ومستلزمات بوفيه ونظافة؛ تحقق من النشاط الحالي.'),
('El Ammar For Wholesale','potential_supplier','تاجر جملة محتمل','القاهرة','المرج','14 Hammam El Faramawy St., El Safa City, El Marg, Cairo','Egypt Yellow Pages - wholesale directory','https://yellowpages.com.eg/en/search/wholesale','needs_review','اسم وعنوان منشوران في نتائج الدليل؛ نوع المنتجات الغذائية غير مؤكد من نتيجة التصنيف وحدها.'),
('El Attar For Wholesale','potential_supplier','تاجر جملة محتمل','الجيزة','بولاق الدكرور','68 Teraet Zeineen St., Bulaq El Dakrour, Giza','Egypt Yellow Pages - wholesale directory','https://yellowpages.com.eg/en/search/wholesale','needs_review','اسم وعنوان منشوران في نتائج الدليل؛ تحقق من السلع والنشاط الفعلي قبل التصنيف كمورد.'),
('El Ekhwa For Wholesale','potential_supplier','تاجر جملة محتمل','القليوبية','شبرا الخيمة','68 El Ekhwa Tower, Shoubra El Mezalat, Shoubra El Kheima, Qalyubia','Egypt Yellow Pages - wholesale directory','https://yellowpages.com.eg/en/search/wholesale','needs_review','اسم وعنوان منشوران في نتائج الدليل؛ يلزم التحقق من المنتجات ووسائل الاتصال.'),
('El Eman Wholesale','potential_supplier','تاجر جملة محتمل','القاهرة','مدينة نصر - عزبة الهجانة','Khaled Ibn El Walid St., Ezbet El Hagana, Nasr City, Cairo','Egypt Yellow Pages - wholesale directory','https://yellowpages.com.eg/en/search/wholesale','needs_review','مدرج في نتائج دليل الجملة؛ تحقق من النشاط الغذائي قبل اعتماده كمورد.'),
('3alam Market','potential_customer','ماركت / تجزئة','القاهرة','مدينة نصر','26 El Nozha St., El Saah Square, Nasr City, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('3M Market','potential_customer','ماركت / تجزئة','القاهرة','مصر الجديدة - ميدان الحجاز','13 Ismail El Mazny St., off Ammar Ibn Yasser St., Hegaz Square, Heliopolis, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('7 Market','potential_customer','ماركت / تجزئة','القاهرة','عين شمس الشرقية','9 Mohamed Fouad Hafez St., Ain Shams El Sharkeya, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('247 Supermarket','potential_customer','سوبر ماركت','القاهرة','شيراتون - مصر الجديدة','6 Farouk Amer St., Floor 3 Flat 8, Sheraton Buildings, Heliopolis, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','العنوان كما يظهر في دليل عام؛ تحقق من العنوان التجاري قبل التواصل.'),
('3 Boys Mini Market','potential_customer','ميني ماركت','القاهرة','غمرة','72 El Qobaisy St., Ghamrah, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('3 Star Supermarket','potential_customer','سوبر ماركت','القاهرة','مدينة نصر','13 El Nozha St., Nasr City, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/cairo-supermarkets/213','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('S & M Mini Market','potential_customer','ميني ماركت','القاهرة','مصر الجديدة','170 El Nozha St., Heliopolis, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/CAIRO-Supermarkets/213/ls','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('S & S Market','potential_customer','ماركت / تجزئة','القاهرة','ألماظة - مصر الجديدة','11 Gamal Nouh St., Almaza, Heliopolis, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/CAIRO-Supermarkets/213/ls','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('Saad El Labban Market','potential_customer','ماركت / تجزئة','القاهرة','مصر القديمة','46 Abou Bakr El Seddik St., Ard El Gameeya, Misr El Kadima, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/CAIRO-Supermarkets/213/ls','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.'),
('Sabeh Supermarket','potential_customer','سوبر ماركت','القاهرة','حلوان - المشروع الأمريكي','19 Atlas St., 1st Neighbourhood, American Project, Helwan, Cairo','Egypt Yellow Pages - supermarket directory','https://yellowpages.com.eg/en/category/CAIRO-Supermarkets/213/ls','needs_review','الاسم والعنوان واردان في نتائج دليل السوبر ماركت؛ تحقق من الفرع الحالي.')
on conflict(source_name,source_url,business_name) do update set
  lead_kind=excluded.lead_kind,
  business_classification=excluded.business_classification,
  governorate=excluded.governorate,
  district=excluded.district,
  public_address=excluded.public_address,
  verification_status='needs_review',
  verification_notes=excluded.verification_notes,
  updated_at=now();(source_name,source_url,business_name) do update set
  lead_kind=excluded.lead_kind,
  business_classification=excluded.business_classification,
  governorate=excluded.governorate,
  district=excluded.district,
  public_address=excluded.public_address,
  verification_status='needs_review',
  verification_notes=excluded.verification_notes,
  updated_at=now();

comment on table public.erp_public_lead_staging is 'Publicly listed prospective business leads; verify source details and commercial suitability before importing as ERP parties.';
