create or replace function public.erp_api_key_issue(
  p_company_id uuid,
  p_label text,
  p_scopes text[] default array['read']::text[],
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set row_security = off
as $function$
declare
  v_key text;
  v_id uuid;
  v_prefix text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول' using errcode='28000';
  end if;
  if not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'إصدار مفاتيح API متاح لمالك الشركة أو المدير فقط' using errcode='42501';
  end if;
  if p_label is null or char_length(btrim(p_label)) not between 2 and 80 then
    raise exception 'اسم المفتاح يجب أن يكون بين حرفين و80 حرفًا' using errcode='22023';
  end if;
  if p_scopes is null or cardinality(p_scopes) not between 1 and 12
     or not (p_scopes <@ array['read','company:read','items:read','customers:read','suppliers:read','inventory:read','orders:read']::text[]) then
    raise exception 'نطاقات API المطلوبة غير مدعومة' using errcode='22023';
  end if;
  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'تاريخ انتهاء المفتاح يجب أن يكون في المستقبل' using errcode='22023';
  end if;
  v_key := 'slk_' || encode(extensions.gen_random_bytes(32),'hex');
  v_prefix := left(v_key,12);
  insert into public.erp_api_credentials(company_id,created_by,label,key_prefix,key_hash,scopes,expires_at)
  values(p_company_id,auth.uid(),btrim(p_label),v_prefix,encode(extensions.digest(convert_to(v_key,'UTF8'),'sha256'),'hex'),p_scopes,p_expires_at)
  returning id into v_id;
  perform public.erp_append_app_activity_log(p_company_id,'إصدار مفتاح API','api_key',v_id::text,null,
    jsonb_build_object('label',btrim(p_label),'key_prefix',v_prefix,'scopes',p_scopes));
  return jsonb_build_object('id',v_id,'api_key',v_key,'key_prefix',v_prefix,'scopes',p_scopes,'expires_at',p_expires_at,
    'warning','يظهر المفتاح الكامل مرة واحدة فقط؛ احفظه في مدير أسرار آمن.');
end;
$function$;
revoke all on function public.erp_api_key_issue(uuid,text,text[],timestamptz) from public, anon;
grant execute on function public.erp_api_key_issue(uuid,text,text[],timestamptz) to authenticated;
