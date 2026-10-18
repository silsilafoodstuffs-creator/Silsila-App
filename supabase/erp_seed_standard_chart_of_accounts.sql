-- Silsila ERP: standard Arabic chart of accounts for Egyptian wholesale/distribution businesses.
-- Safe to run after supabase/erp_schema.sql and supabase/erp_account_integrity.sql.
-- This script DEFINES an idempotent seeding function; it does not guess which company to seed.
-- After applying this file in Supabase SQL Editor, run:
-- select public.erp_seed_standard_chart_of_accounts('YOUR_COMPANY_UUID'::uuid);
-- Existing account codes are preserved (ON CONFLICT DO NOTHING). Review and back up production data first.

create or replace function public.erp_seed_standard_chart_of_accounts(p_company_id uuid)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row jsonb;
  v_parent_code text;
  v_account_id uuid;
  v_inserted integer := 0;
  v_result integer;
  v_accounts jsonb := $accounts$
[
 {"code":"1","name":"الأصول","type":"asset","balance":"debit","parent":null,"postable":false},
 {"code":"11","name":"الأصول المتداولة","type":"asset","balance":"debit","parent":"1","postable":false},
 {"code":"111","name":"النقدية وما في حكمها","type":"asset","balance":"debit","parent":"11","postable":false},
 {"code":"11101","name":"الخزينة الرئيسية","type":"asset","balance":"debit","parent":"111","postable":true},
 {"code":"11102","name":"الخزائن الفرعية","type":"asset","balance":"debit","parent":"111","postable":true},
 {"code":"11103","name":"العهد النقدية","type":"asset","balance":"debit","parent":"111","postable":true},
 {"code":"1111","name":"البنوك","type":"asset","balance":"debit","parent":"111","postable":false},
 {"code":"111101","name":"البنك - حساب جاري 1","type":"asset","balance":"debit","parent":"1111","postable":true},
 {"code":"112","name":"العملاء وأوراق القبض","type":"asset","balance":"debit","parent":"11","postable":false},
 {"code":"11201","name":"عملاء محليون","type":"asset","balance":"debit","parent":"112","postable":true},
 {"code":"11202","name":"عملاء تجزئة","type":"asset","balance":"debit","parent":"112","postable":true},
 {"code":"11203","name":"عملاء جملة ونصف جملة","type":"asset","balance":"debit","parent":"112","postable":true},
 {"code":"11204","name":"أوراق قبض","type":"asset","balance":"debit","parent":"112","postable":true},
 {"code":"11205","name":"مخصص ديون مشكوك في تحصيلها","type":"asset","balance":"credit","parent":"112","postable":true},
 {"code":"113","name":"المخزون","type":"asset","balance":"debit","parent":"11","postable":false},
 {"code":"11301","name":"مخزون مواد غذائية","type":"asset","balance":"debit","parent":"113","postable":true},
 {"code":"11302","name":"مخزون مواد تعبئة وتغليف","type":"asset","balance":"debit","parent":"113","postable":true},
 {"code":"11303","name":"بضاعة بالطريق","type":"asset","balance":"debit","parent":"113","postable":true},
 {"code":"11304","name":"بضاعة لدى الغير","type":"asset","balance":"debit","parent":"113","postable":true},
 {"code":"11305","name":"مخزون تالف وهالك","type":"asset","balance":"debit","parent":"113","postable":true},
 {"code":"114","name":"السلف والعهد المدينة","type":"asset","balance":"debit","parent":"11","postable":false},
 {"code":"11401","name":"سلف الموظفين","type":"asset","balance":"debit","parent":"114","postable":true},
 {"code":"11402","name":"عهد المندوبين","type":"asset","balance":"debit","parent":"114","postable":true},
 {"code":"11403","name":"دفعات مقدمة للموردين","type":"asset","balance":"debit","parent":"114","postable":true},
 {"code":"11404","name":"مصروفات مدفوعة مقدماً","type":"asset","balance":"debit","parent":"114","postable":true},
 {"code":"115","name":"ضرائب مدينة","type":"asset","balance":"debit","parent":"11","postable":false},
 {"code":"11501","name":"ضريبة قيمة مضافة - مدخلات","type":"asset","balance":"debit","parent":"115","postable":true},
 {"code":"12","name":"الأصول غير المتداولة","type":"asset","balance":"debit","parent":"1","postable":false},
 {"code":"121","name":"الأصول الثابتة","type":"asset","balance":"debit","parent":"12","postable":false},
 {"code":"12101","name":"أراضٍ","type":"asset","balance":"debit","parent":"121","postable":true},
 {"code":"12102","name":"مبانٍ وتجهيزات","type":"asset","balance":"debit","parent":"121","postable":true},
 {"code":"12103","name":"سيارات ووسائل نقل","type":"asset","balance":"debit","parent":"121","postable":true},
 {"code":"12104","name":"أثاث ومعدات مكتبية","type":"asset","balance":"debit","parent":"121","postable":true},
 {"code":"12105","name":"أجهزة حاسب وبرامج","type":"asset","balance":"debit","parent":"121","postable":true},
 {"code":"122","name":"مجمع الإهلاك","type":"asset","balance":"credit","parent":"12","postable":false},
 {"code":"12201","name":"مجمع إهلاك المباني والتجهيزات","type":"asset","balance":"credit","parent":"122","postable":true},
 {"code":"12202","name":"مجمع إهلاك السيارات","type":"asset","balance":"credit","parent":"122","postable":true},
 {"code":"12203","name":"مجمع إهلاك الأثاث والمعدات","type":"asset","balance":"credit","parent":"122","postable":true},
 {"code":"2","name":"الالتزامات","type":"liability","balance":"credit","parent":null,"postable":false},
 {"code":"21","name":"الالتزامات المتداولة","type":"liability","balance":"credit","parent":"2","postable":false},
 {"code":"211","name":"الموردون وأوراق الدفع","type":"liability","balance":"credit","parent":"21","postable":false},
 {"code":"21101","name":"موردو مواد غذائية محليون","type":"liability","balance":"credit","parent":"211","postable":true},
 {"code":"21102","name":"موردو تعبئة وتغليف","type":"liability","balance":"credit","parent":"211","postable":true},
 {"code":"21103","name":"موردون متنوعون","type":"liability","balance":"credit","parent":"211","postable":true},
 {"code":"21104","name":"أوراق دفع","type":"liability","balance":"credit","parent":"211","postable":true},
 {"code":"212","name":"مصروفات مستحقة","type":"liability","balance":"credit","parent":"21","postable":false},
 {"code":"21201","name":"رواتب وأجور مستحقة","type":"liability","balance":"credit","parent":"212","postable":true},
 {"code":"21202","name":"إيجارات مستحقة","type":"liability","balance":"credit","parent":"212","postable":true},
 {"code":"21203","name":"مرافق وخدمات مستحقة","type":"liability","balance":"credit","parent":"212","postable":true},
 {"code":"213","name":"ضرائب دائنة","type":"liability","balance":"credit","parent":"21","postable":false},
 {"code":"21301","name":"ضريبة قيمة مضافة - مخرجات","type":"liability","balance":"credit","parent":"213","postable":true},
 {"code":"21302","name":"ضرائب خصم وتحصيل","type":"liability","balance":"credit","parent":"213","postable":true},
 {"code":"214","name":"دفعات مقدمة من العملاء","type":"liability","balance":"credit","parent":"21","postable":true},
 {"code":"22","name":"الالتزامات طويلة الأجل","type":"liability","balance":"credit","parent":"2","postable":false},
 {"code":"22101","name":"قروض طويلة الأجل","type":"liability","balance":"credit","parent":"22","postable":true},
 {"code":"3","name":"حقوق الملكية","type":"equity","balance":"credit","parent":null,"postable":false},
 {"code":"31","name":"رأس المال","type":"equity","balance":"credit","parent":"3","postable":false},
 {"code":"3101","name":"رأس مال المالك","type":"equity","balance":"credit","parent":"31","postable":true},
 {"code":"3102","name":"زيادات رأس المال","type":"equity","balance":"credit","parent":"31","postable":true},
 {"code":"32","name":"الاحتياطيات والأرباح المحتجزة","type":"equity","balance":"credit","parent":"3","postable":false},
 {"code":"3201","name":"احتياطي قانوني","type":"equity","balance":"credit","parent":"32","postable":true},
 {"code":"3202","name":"أرباح وخسائر مرحلة","type":"equity","balance":"credit","parent":"32","postable":true},
 {"code":"33","name":"مسحوبات المالك","type":"equity","balance":"debit","parent":"3","postable":true},
 {"code":"4","name":"الإيرادات","type":"revenue","balance":"credit","parent":null,"postable":false},
 {"code":"41","name":"إيرادات النشاط الرئيسي","type":"revenue","balance":"credit","parent":"4","postable":false},
 {"code":"4101","name":"مبيعات مواد غذائية","type":"revenue","balance":"credit","parent":"41","postable":true},
 {"code":"4102","name":"مبيعات بضائع أخرى","type":"revenue","balance":"credit","parent":"41","postable":true},
 {"code":"4103","name":"مبيعات نقدية","type":"revenue","balance":"credit","parent":"41","postable":true},
 {"code":"4104","name":"مبيعات آجلة","type":"revenue","balance":"credit","parent":"41","postable":true},
 {"code":"42","name":"مردودات وخصومات المبيعات","type":"revenue","balance":"debit","parent":"4","postable":false},
 {"code":"4201","name":"مردودات المبيعات","type":"revenue","balance":"debit","parent":"42","postable":true},
 {"code":"4202","name":"خصومات مسموح بها","type":"revenue","balance":"debit","parent":"42","postable":true},
 {"code":"43","name":"إيرادات أخرى","type":"revenue","balance":"credit","parent":"4","postable":false},
 {"code":"4301","name":"إيرادات نقل وتوصيل محصلة","type":"revenue","balance":"credit","parent":"43","postable":true},
 {"code":"4302","name":"إيرادات متنوعة","type":"revenue","balance":"credit","parent":"43","postable":true},
 {"code":"5","name":"المصروفات وتكلفة النشاط","type":"expense","balance":"debit","parent":null,"postable":false},
 {"code":"51","name":"تكلفة البضاعة المباعة","type":"expense","balance":"debit","parent":"5","postable":false},
 {"code":"5101","name":"تكلفة البضاعة المباعة - مواد غذائية","type":"expense","balance":"debit","parent":"51","postable":true},
 {"code":"5102","name":"مردودات مشتريات","type":"expense","balance":"credit","parent":"51","postable":true},
 {"code":"5103","name":"خصومات مكتسبة من الموردين","type":"expense","balance":"credit","parent":"51","postable":true},
 {"code":"5104","name":"نقل ومصاريف مشتريات","type":"expense","balance":"debit","parent":"51","postable":true},
 {"code":"52","name":"مصروفات البيع والتوزيع","type":"expense","balance":"debit","parent":"5","postable":false},
 {"code":"5201","name":"أجور وعمولات المبيعات","type":"expense","balance":"debit","parent":"52","postable":true},
 {"code":"5202","name":"وقود وصيانة سيارات التوزيع","type":"expense","balance":"debit","parent":"52","postable":true},
 {"code":"5203","name":"مصاريف تحميل وتنزيل","type":"expense","balance":"debit","parent":"52","postable":true},
 {"code":"5204","name":"مصروفات توصيل وشحن","type":"expense","balance":"debit","parent":"52","postable":true},
 {"code":"53","name":"المصروفات العمومية والإدارية","type":"expense","balance":"debit","parent":"5","postable":false},
 {"code":"5301","name":"رواتب وأجور إدارية","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5302","name":"إيجار المقر والمخازن","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5303","name":"كهرباء ومياه واتصالات","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5304","name":"أدوات مكتبية ومطبوعات","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5305","name":"صيانة وإصلاحات","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5306","name":"اشتراكات وبرامج وخدمات تقنية","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5307","name":"أتعاب مهنية ومحاسبية","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5308","name":"رسوم بنكية","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5309","name":"إهلاك الأصول الثابتة","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"5310","name":"مصروفات ضيافة ونظافة","type":"expense","balance":"debit","parent":"53","postable":true},
 {"code":"54","name":"مصروفات تمويلية وأخرى","type":"expense","balance":"debit","parent":"5","postable":false},
 {"code":"5401","name":"فوائد ومصاريف تمويل","type":"expense","balance":"debit","parent":"54","postable":true},
 {"code":"5402","name":"غرامات ومصروفات متنوعة","type":"expense","balance":"debit","parent":"54","postable":true},
 {"code":"5403","name":"خسائر بيع أصول","type":"expense","balance":"debit","parent":"54","postable":true}
]
$accounts$::jsonb;
begin
  if p_company_id is null then
    raise exception 'يجب تحديد الشركة قبل إنشاء شجرة الحسابات.';
  end if;

  if not exists (select 1 from public.erp_companies c where c.id = p_company_id) then
    raise exception 'الشركة المحددة غير موجودة في erp_companies.';
  end if;

  for v_row in
    select value
    from jsonb_array_elements(v_accounts) with ordinality as a(value, ord)
    order by ord
  loop
    v_parent_code := nullif(v_row->>'parent', '');

    if v_parent_code is null then
      v_account_id := null;
    else
      select a.id into v_account_id
      from public.erp_accounts a
      where a.company_id = p_company_id
        and a.account_code = v_parent_code;

      if v_account_id is null then
        raise exception 'لم يتم العثور على الحساب الأب % أثناء إنشاء الحساب %.', v_parent_code, v_row->>'code';
      end if;
    end if;

    insert into public.erp_accounts (
      company_id, parent_id, account_code, account_name,
      account_type, normal_balance, is_postable, is_active
    ) values (
      p_company_id, v_account_id, v_row->>'code', v_row->>'name',
      v_row->>'type', v_row->>'balance', (v_row->>'postable')::boolean, true
    )
    on conflict (company_id, account_code) do nothing
    returning id into v_account_id;

    if found then
      v_inserted := v_inserted + 1;
    else
      select a.id into v_account_id
      from public.erp_accounts a
      where a.company_id = p_company_id
        and a.account_code = v_row->>'code';
    end if;
  end loop;

  return v_inserted;
end;
$$;

comment on function public.erp_seed_standard_chart_of_accounts(uuid) is
  'Adds the standard Arabic chart of accounts for a specified company; preserves existing account codes and returns inserted row count.';
