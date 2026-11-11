create table if not exists public.erp_api_credentials (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  label text not null check (char_length(btrim(label)) between 2 and 80),
  key_prefix text not null,
  key_hash text not null unique,
  scopes text[] not null default array['read']::text[],
  expires_at timestamptz,
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint erp_api_credentials_scopes_check check (
    cardinality(scopes) between 1 and 12
    and scopes <@ array['read','items:read','customers:read','suppliers:read','inventory:read','orders:read']::text[]
  ),
  constraint erp_api_credentials_expiry_check check (expires_at is null or expires_at > created_at)
);
create index if not exists erp_api_credentials_company_created_idx
  on public.erp_api_credentials(company_id, created_at desc);
alter table public.erp_api_credentials enable row level security;
revoke all on public.erp_api_credentials from public, anon, authenticated;
grant all on public.erp_api_credentials to service_role;

create or replace function public.erp_api_key_issue(
  p_company_id uuid, p_label text, p_scopes text[] default array['read']::text[],
  p_expires_at timestamptz default null
) returns jsonb
language plpgsql security definer set search_path = '' set row_security = off
as $$
declare
  v_key text;
  v_id uuid;
  v_prefix text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول' using errcode='28000'; end if;
  if not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'إصدار مفاتيح API متاح لمالك الشركة أو المدير فقط' using errcode='42501';
  end if;
  if p_label is null or char_length(btrim(p_label)) not between 2 and 80 then
    raise exception 'اسم المفتاح يجب أن يكون بين حرفين و80 حرفًا' using errcode='22023';
  end if;
  if p_scopes is null or cardinality(p_scopes) not between 1 and 12
     or not (p_scopes <@ array['read','items:read','customers:read','suppliers:read','inventory:read','orders:read']::text[]) then
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
$$;

create or replace function public.erp_api_key_list(p_company_id uuid)
returns table(id uuid,label text,key_prefix text,scopes text[],expires_at timestamptz,last_used_at timestamptz,revoked_at timestamptz,created_at timestamptz)
language plpgsql stable security definer set search_path = '' set row_security = off
as $$
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول' using errcode='28000'; end if;
  if not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'عرض مفاتيح API متاح لمالك الشركة أو المدير فقط' using errcode='42501';
  end if;
  return query select c.id,c.label,c.key_prefix,c.scopes,c.expires_at,c.last_used_at,c.revoked_at,c.created_at
    from public.erp_api_credentials c where c.company_id=p_company_id order by c.created_at desc;
end;
$$;

create or replace function public.erp_api_key_revoke(p_company_id uuid,p_key_id uuid)
returns boolean
language plpgsql security definer set search_path = '' set row_security = off
as $$
declare v_prefix text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول' using errcode='28000'; end if;
  if not public.erp_user_has_company_role(p_company_id,array['owner','admin']::text[]) then
    raise exception 'إلغاء مفاتيح API متاح لمالك الشركة أو المدير فقط' using errcode='42501';
  end if;
  update public.erp_api_credentials set revoked_at=coalesce(revoked_at,now())
    where id=p_key_id and company_id=p_company_id returning key_prefix into v_prefix;
  if v_prefix is null then return false; end if;
  perform public.erp_append_app_activity_log(p_company_id,'إلغاء مفتاح API','api_key',p_key_id::text,null,
    jsonb_build_object('key_prefix',v_prefix));
  return true;
end;
$$;

revoke all on function public.erp_api_key_issue(uuid,text,text[],timestamptz) from public,anon;
revoke all on function public.erp_api_key_list(uuid) from public,anon;
revoke all on function public.erp_api_key_revoke(uuid,uuid) from public,anon;
grant execute on function public.erp_api_key_issue(uuid,text,text[],timestamptz) to authenticated;
grant execute on function public.erp_api_key_list(uuid) to authenticated;
grant execute on function public.erp_api_key_revoke(uuid,uuid) to authenticated;
