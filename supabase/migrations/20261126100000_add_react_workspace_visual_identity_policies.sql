-- Add visual identity policies consumed by the React workspace.
-- Existing company policy rows and their IDs/values remain untouched.
begin;

insert into public.erp_program_policies
 (company_id,policy_key,policy_code,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value)
select c.id,v.policy_key,v.policy_code,'الهوية البصرية',v.name_ar,v.name_en,true,true,'[]'::jsonb,v.policy_value
from public.erp_companies c
cross join (values
 ('visual_identity.screen_title_color','Idn013','لون عنوان الشاشة','Screen title color','#3E007D'),
 ('visual_identity.table_header_color','Idn014','لون صف عناوين الأعمدة','Table header background color','#FFA015'),
 ('visual_identity.table_header_text_color','Idn015','لون نص عناوين الأعمدة','Table header text color','#241735'),
 ('visual_identity.table_row_alt_color','Idn016','لون الصفوف المتبادلة','Alternating table row color','#FAF8FC'),
 ('visual_identity.table_row_hover_color','Idn017','لون تمييز الصف عند المرور','Table row hover color','#F5EFFB')
) as v(policy_key,policy_code,name_ar,name_en,policy_value)
on conflict(company_id,policy_key) do nothing;

commit;
