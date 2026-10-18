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
drop policy if exists erp_public_leads_update_manager on public.erp_public_lead_staging;
create policy erp_public_leads_update_manager on public.erp_public_lead_staging for update to authenticated using (company_id is null or public.erp_user_has_company_role(company_id,array['owner','admin','manager','sales_manager']::text[])) with check (company_id is not null and public.erp_user_has_company_role(company_id,array['owner','admin','manager','sales_manager']::text[]));

insert into public.erp_public_lead_staging
(business_name,lead_kind,business_classification,governorate,district,public_address,source_name,source_url,verification_status,verification_notes)
values
('Seoudi Supermarket - Sheraton Branch','potential_customer','سوبر ماركت / سلسلة تجزئة','القاهرة','النزهة - شيراتون','13 Khaled Ibn Al Walid, Sheraton Al Matar, El Nozha, Cairo Governorate','Google Maps public business listing','https://www.google.com/maps/search/?api=1&query=Seoudi+Supermarket+Sheraton+Cairo','needs_review','اسم وعنوان منشوران علنًا؛ تأكد من بيانات الفرع وملاءمة نشاط البيع بالجملة قبل الاستيراد.'),
('Seoudi Super Market - New Cairo','potential_customer','سوبر ماركت / سلسلة تجزئة','القاهرة','القاهرة الجديدة','11835 Akhnaton, New Cairo 1, Cairo Governorate','Google Maps public business listing','https://www.google.com/maps/search/?api=1&query=Seoudi+Super+Market+Akhnaton+New+Cairo','needs_review','فرع تجزئة عام، ليس عميل جملة مؤكدًا.'),
('El Abed Supermarket','potential_customer','سوبر ماركت','القاهرة','روض الفرج / شبرا','56 Shobra Street, near Masarra Street, Cairo','Google Maps public business listing','https://www.google.com/maps/search/?api=1&query=El+Abed+Supermarket+Shobra+Cairo','needs_review','عنوان من دليل عام؛ التحقق الهاتفي مطلوب قبل التعامل.'),
('2M Wholesale Market','potential_customer','سوق جملة / سوبر ماركت','القاهرة','مدينة نصر','27 El Obour Buildings, Salah Salem Road, Nasr City, Cairo','Egypt Yellow Pages','https://yellowpages.com.eg/en/search/wholesale','needs_review','مدرج في دليل يلو بيجز ضمن نتائج wholesale؛ راجع الصفحة وبيانات النشاط قبل الاعتماد.'),
('El Ammar For Wholesale','potential_supplier','تاجر جملة / موزع محتمل','القاهرة','المرج','14 Hammam El Faramawy Street, El Safa City, El Marg, Cairo','Egypt Yellow Pages','https://yellowpages.com.eg/en/search/wholesale','needs_review','الاسم والعنوان ضمن نتائج دليل الجملة؛ لم يتم التحقق من نوع السلع أو بيانات الاتصال.'),
('El Attar For Wholesale','potential_supplier','تاجر جملة / موزع محتمل','الجيزة','بولاق الدكرور','68 Teraet Zeineen Street, Bulaq El Dakrour, Giza','Egypt Yellow Pages','https://yellowpages.com.eg/en/search/wholesale','needs_review','الاسم والعنوان ضمن نتائج دليل الجملة؛ تحقق من السلع والنشاط الفعلي.'),
('El Ekhwa For Wholesale','potential_supplier','تاجر جملة / موزع محتمل','القليوبية','شبرا الخيمة','68 El Ekhwa Tower, Shoubra El Mezalat, Shoubra El Kheima, Qalyubia','Egypt Yellow Pages','https://yellowpages.com.eg/en/search/wholesale','needs_review','العنوان مصاغ من دليل عام وقد يحتاج تصحيحًا ميدانيًا.'),
('AM GROUP Misr','potential_supplier','شركة توزيع / أغذية ومشروبات','القليوبية','مدينة العبور - المنطقة الصناعية','Obour Industrial Zone, Qalyubia, Egypt','Google Maps public business listing','https://www.google.com/maps/search/?api=1&query=AM+GROUP+Misr+Obour+Egypt','needs_review','شركة ذات حضور عام في التوزيع والتجارة؛ يلزم التواصل الرسمي لتأكيد المورد والمنتجات.'),
('HORECA STAR','potential_supplier','مورد أغذية وخدمات تموين','القاهرة','القاهرة الجديدة','Cairo Business Park, Second New Cairo, Cairo Governorate','Google Maps public business listing','https://www.google.com/maps/search/?api=1&query=HORECA+STAR+Cairo+Business+Park','needs_review','مورد B2B للضيافة والتموين وفق وصفه العام؛ تحقق من شروط التوريد.'),
('الشركة المصرية لتجارة الجملة - فرع هايبر الطيران','institution','منفذ جملة / مجمع استهلاكي','القاهرة','مدينة نصر','مدينة نصر، القاهرة','جهاز حماية المستهلك - دليل المجمعات الاستهلاكية','https://cpa.gov.eg/ar-eg/المجمعات-الاستهلاكية/','needs_review','مذكور ضمن دليل عام للمجمعات الاستهلاكية؛ يجب التحقق من الاسم التشغيلي وإمكانية التعامل التجاري.'),
('الشركة المصرية لتجارة الجملة - ملحق جملة المطرية','institution','منفذ جملة / تموين','القاهرة','المطرية','المطرية، القاهرة','جهاز حماية المستهلك - دليل المجمعات الاستهلاكية','https://cpa.gov.eg/ar-eg/المجمعات-الاستهلاكية/','needs_review','مدرج في دليل عام؛ ليس عميلًا متعاقدًا ولا يعني أن التوريد متاح.'),
('شركة النيل للمجمعات الاستهلاكية - فرع به تموين','institution','منفذ تموين / مجمع استهلاكي','القاهرة','شبرا / مناطق متعددة','القاهرة - تفاصيل الفرع بحاجة لاستخراج من الدليل الرسمي','جهاز حماية المستهلك - دليل المجمعات الاستهلاكية','https://cpa.gov.eg/ar-eg/المجمعات-الاستهلاكية/','needs_review','اسم مجموعة فروع وارد في دليل رسمي؛ يجب اختيار الفرع المحدد قبل استخدامه كعنوان عميل.')
on conflict(source_name,source_url,business_name) do update set
  lead_kind=excluded.lead_kind,
  business_classification=excluded.business_classification,
  governorate=excluded.governorate,
  district=excluded.district,
  public_address=excluded.public_address,
  verification_status='needs_review',
  verification_notes=excluded.verification_notes,
  updated_at=now();

comment on table public.erp_public_lead_staging is 'Publicly listed prospective business leads; verify source details and commercial suitability before importing as ERP parties.';
