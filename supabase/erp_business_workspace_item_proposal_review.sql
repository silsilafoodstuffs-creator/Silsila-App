create or replace function private.can_review_business_workspace_item_proposals()
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth,private
as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='management' and p.account_status='active') $$;
revoke all on function private.can_review_business_workspace_item_proposals() from public,anon;
grant execute on function private.can_review_business_workspace_item_proposals() to authenticated;

alter policy business_workspace_select on public.erp_business_workspaces using(private.can_access_business_workspace(id,'workspace.enter') or private.can_review_business_workspace_item_proposals());
alter policy workspace_select on public.erp_business_workspace_item_proposals using(private.can_access_business_workspace(workspace_id,'items.read') or private.can_review_business_workspace_item_proposals());
alter policy workspace_update on public.erp_business_workspace_item_proposals using(private.can_access_business_workspace(workspace_id,'items.propose') or private.can_review_business_workspace_item_proposals()) with check(private.can_access_business_workspace(workspace_id,'items.propose') or private.can_review_business_workspace_item_proposals());

create or replace function private.review_business_workspace_item_proposal(
 p_proposal_id uuid,p_decision text,p_company_id uuid default null,p_category_id uuid default null,
 p_item_code text default null,p_item_name text default null,p_item_name_en text default null,p_unit_name text default null,p_note text default null
) returns uuid language plpgsql security definer set search_path=pg_catalog,public,auth,private
as $$
declare v_user uuid:=(select auth.uid()); v_proposal public.erp_business_workspace_item_proposals%rowtype; v_item_id uuid; v_category_id uuid; v_code text; v_activity text;
begin
 if v_user is null or not private.can_review_business_workspace_item_proposals() then raise exception 'Only active Silsila management users can review workspace item proposals' using errcode='42501'; end if;
 if p_decision not in ('approve','reject') then raise exception 'Decision must be approve or reject' using errcode='22023'; end if;
 select * into v_proposal from public.erp_business_workspace_item_proposals where id=p_proposal_id for update;
 if not found then raise exception 'Proposal not found' using errcode='P0002'; end if;
 if v_proposal.status<>'pending' then raise exception 'Only pending proposals can be reviewed' using errcode='22023'; end if;
 if p_decision='reject' then update public.erp_business_workspace_item_proposals set status='rejected',reviewed_by=v_user,reviewed_at=now(),review_note=nullif(trim(coalesce(p_note,'')),'') where id=p_proposal_id; return null; end if;
 if p_company_id is null then raise exception 'Company is required to approve an item' using errcode='22023'; end if;
 if p_category_id is not null and not exists(select 1 from public.erp_item_categories c where c.id=p_category_id and c.company_id=p_company_id and c.is_active) then raise exception 'Selected category does not belong to the active company' using errcode='23503'; end if;
 select activity_type into v_activity from public.erp_business_workspaces where id=v_proposal.workspace_id;
 v_category_id:=p_category_id;
 if v_category_id is null and nullif(trim(coalesce(v_proposal.proposed_category,'')),'') is not null then
  select c.id into v_category_id from public.erp_item_categories c where c.company_id=p_company_id and c.is_active
   and lower(trim(c.category_name))=lower(trim(v_proposal.proposed_category))
   and (v_activity is null or c.activity_code is null or c.activity_code in (select a.code from public.activity_types a where lower(a.name)=lower(v_activity) or lower(a.code)=lower(v_activity)))
  order by c.created_at limit 1;
 end if;
 v_code:=coalesce(nullif(trim(p_item_code),''),'PRP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)));
 insert into public.erp_items(company_id,item_code,item_name,item_name_en,base_unit,purchase_price,sale_price,reorder_level,expiry_tracking,is_active,tax_rate,discount_limit,brand_name,package_description,source_name,is_demo_data,show_in_app,category_id)
 values(p_company_id,v_code,coalesce(nullif(trim(p_item_name),''),v_proposal.name_ar),coalesce(p_item_name_en,v_proposal.name_en,''),coalesce(nullif(trim(p_unit_name),''),v_proposal.unit_name),0,0,0,false,true,0,0,null,v_proposal.description,'اقتراح نشاط من منصة سلسلة',false,true,v_category_id)
 returning id into v_item_id;
 update public.erp_business_workspace_item_proposals set status='approved',reviewed_by=v_user,reviewed_at=now(),review_note=nullif(trim(coalesce(p_note,'')),''),platform_item_id=v_item_id where id=p_proposal_id;
 return v_item_id;
end $$;
revoke all on function private.review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) from public,anon;
grant execute on function private.review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) to authenticated;
create or replace function public.erp_review_business_workspace_item_proposal(
 p_proposal_id uuid,p_decision text,p_company_id uuid default null,p_category_id uuid default null,
 p_item_code text default null,p_item_name text default null,p_item_name_en text default null,p_unit_name text default null,p_note text default null
) returns uuid language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select private.review_business_workspace_item_proposal(p_proposal_id,p_decision,p_company_id,p_category_id,p_item_code,p_item_name,p_item_name_en,p_unit_name,p_note); $$;
revoke all on function public.erp_review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) from public,anon;
grant execute on function public.erp_review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) to authenticated;
