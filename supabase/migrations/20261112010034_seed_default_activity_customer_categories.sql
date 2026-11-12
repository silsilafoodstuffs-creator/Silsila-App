insert into public.erp_activity_customer_categories
  (company_id, workspace_id, activity_type, activity_name, customer_category, is_active)
select w.platform_company_id, w.id, w.activity_type, w.workspace_name, c.category, true
from public.erp_business_workspaces w
cross join lateral unnest(
  case w.activity_type
    when 'ACT001' then array[
      'مستهلك نهائي','بقالة','سوبر ماركت','محل مواد غذائية','مطعم أو كافيه',
      'فندق أو منشأة سياحية','موزع','شركة أو مؤسسة','مصنع أو منشأة إنتاج','جهة حكومية','عميل آخر'
    ]::text[]
    when 'ACT002' then array[
      'مستهلك نهائي','مقاول','شركة مقاولات','مهندس أو مكتب استشاري',
      'محل مستلزمات بناء','موزع','مصنع أو منشأة إنتاج','جهة حكومية','عميل آخر'
    ]::text[]
    when 'ACT003' then array[
      'مستهلك نهائي','محل ملابس','متجر إلكتروني','موزع','شركة أو مؤسسة','مصنع ملابس','جهة حكومية','عميل آخر'
    ]::text[]
    when 'ACT004' then array[
      'مستهلك نهائي','متجر أجهزة','شركة تقنية','موزع','شركة أو مؤسسة','جهة حكومية','مركز صيانة','عميل آخر'
    ]::text[]
    else array[
      'مستهلك نهائي','محل متخصص','متجر إلكتروني','موزع','شركة أو مؤسسة',
      'مصنع أو منشأة إنتاج','جهة حكومية','عميل آخر'
    ]::text[]
  end
) as c(category)
where w.is_active = true and w.account_kind = 'supplier'
on conflict (company_id, workspace_id, customer_category) do nothing;
