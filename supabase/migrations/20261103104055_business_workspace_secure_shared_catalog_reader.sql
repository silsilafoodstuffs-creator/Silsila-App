create or replace function private.get_business_workspace_catalog_items(p_workspace_id uuid)
returns table(id uuid,item_code text,item_name text,item_name_en text,base_unit text,category_id uuid,category_name text)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,private
as $$
declare v_company uuid; v_activity text;
begin
 if (select auth.uid()) is null or not private.can_access_business_workspace(p_workspace_id,'items.read') then
  raise exception 'Insufficient permission to read the shared item catalog for this workspace' using errcode='42501';
 end if;
 select platform_company_id,activity_type into v_company,v_activity
 from public.erp_business_workspaces where id=p_workspace_id and is_active;
 if v_company is null then raise exception 'The workspace is not linked to a Silsila company catalog' using errcode='22023'; end if;
 return query
 select i.id,i.item_code,i.item_name,i.item_name_en,i.base_unit,i.category_id,c.category_name
 from public.erp_items i
 left join public.erp_item_categories c on c.id=i.category_id and c.company_id=v_company and c.is_active
 where i.company_id=v_company and i.is_active
  and (nullif(trim(coalesce(v_activity,'')),'') is null or exists(
    select 1 from public.activity_types a
    where a.is_active and lower(trim(coalesce(a.code,'')))=lower(trim(v_activity))
      and c.activity_code=a.code
  ))
 order by i.item_name limit 1000;
end
$$;
revoke all on function private.get_business_workspace_catalog_items(uuid) from public,anon;
grant execute on function private.get_business_workspace_catalog_items(uuid) to authenticated;
create or replace function public.erp_get_business_workspace_catalog_items(p_workspace_id uuid)
returns table(id uuid,item_code text,item_name text,item_name_en text,base_unit text,category_id uuid,category_name text)
language sql stable security invoker
set search_path=pg_catalog,public,auth,private
as $$ select * from private.get_business_workspace_catalog_items(p_workspace_id); $$;
revoke all on function public.erp_get_business_workspace_catalog_items(uuid) from public,anon;
grant execute on function public.erp_get_business_workspace_catalog_items(uuid) to authenticated;
