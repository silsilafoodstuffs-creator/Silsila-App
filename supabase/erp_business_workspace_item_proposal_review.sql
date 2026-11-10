create or replace function private.can_review_business_workspace_item_proposals()
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth,private
as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='management' and p.account_status='active') $$;
revoke all on function private.can_review_business_workspace_item_proposals() from public,anon;
grant execute on function private.can_review_business_workspace_item_proposals() to authenticated;

alter policy business_workspace_select on public.erp_business_workspaces using(private.can_access_business_workspace(id,'workspace.enter') or private.can_review_business_workspace_item_proposals());
alter policy workspace_select on public.erp_business_workspace_item_proposals using(private.can_access_business_workspace(workspace_id,'items.read') or private.can_review_business_workspace_item_proposals());
alter policy workspace_update on public.erp_business_workspace_item_proposals using(private.can_access_business_workspace(workspace_id,'items.propose') or private.can_review_business_workspace_item_proposals()) with check(private.can_access_business_workspace(workspace_id,'items.propose') or private.can_review_business_workspace_item_proposals());

CREATE OR REPLACE FUNCTION private.review_business_workspace_item_proposal(
 p_proposal_id uuid,p_decision text,p_company_id uuid default null,p_category_id uuid default null,
 p_item_code text default null,p_item_name text default null,p_item_name_en text default null,p_unit_name text default null,p_note text default null
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,private
AS $function$
DECLARE
 v_user uuid := (select auth.uid());
 v_proposal public.erp_business_workspace_item_proposals%rowtype;
 v_item_id uuid;
 v_category_id uuid;
 v_activity text;
BEGIN
 IF v_user IS NULL OR NOT private.can_review_business_workspace_item_proposals() THEN
  RAISE EXCEPTION 'Only active Silsila management users can review workspace item proposals' USING errcode='42501';
 END IF;
 IF p_decision NOT IN ('approve','reject') THEN
  RAISE EXCEPTION 'Decision must be approve or reject' USING errcode='22023';
 END IF;
 SELECT * INTO v_proposal
 FROM public.erp_business_workspace_item_proposals
 WHERE id=p_proposal_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found' USING errcode='P0002'; END IF;
 IF v_proposal.status<>'pending' THEN
  RAISE EXCEPTION 'Only pending proposals can be reviewed' USING errcode='22023';
 END IF;
 IF p_decision='reject' THEN
  UPDATE public.erp_business_workspace_item_proposals
  SET status='rejected',reviewed_by=v_user,reviewed_at=now(),
      review_note=nullif(trim(coalesce(p_note,'')),'')
  WHERE id=p_proposal_id;
  RETURN NULL;
 END IF;
 IF p_company_id IS NULL THEN
  RAISE EXCEPTION 'Company is required to approve an item' USING errcode='22023';
 END IF;
 SELECT activity_type INTO v_activity
 FROM public.erp_business_workspaces WHERE id=v_proposal.workspace_id;

 v_category_id:=p_category_id;
 IF v_category_id IS NULL AND nullif(trim(coalesce(v_proposal.proposed_category,'')),'') IS NOT NULL THEN
  SELECT c.id INTO v_category_id
  FROM public.erp_item_categories c
  WHERE c.company_id=p_company_id AND c.is_active
    AND c.parent_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.erp_item_categories parent
      WHERE parent.id=c.parent_id AND parent.company_id=c.company_id
        AND parent.parent_id IS NOT NULL AND parent.is_active
    )
    AND lower(trim(c.category_name))=lower(trim(v_proposal.proposed_category))
    AND (v_activity IS NULL OR c.activity_code IS NULL OR c.activity_code IN (
      SELECT a.code FROM public.activity_types a
      WHERE lower(a.name)=lower(v_activity) OR lower(a.code)=lower(v_activity)
    ))
  ORDER BY c.created_at LIMIT 1;
 END IF;

 IF v_category_id IS NULL OR NOT EXISTS (
   SELECT 1
   FROM public.erp_item_categories c
   JOIN public.erp_item_categories parent
     ON parent.id=c.parent_id AND parent.company_id=c.company_id
   JOIN public.erp_item_categories main
     ON main.id=parent.parent_id AND main.company_id=parent.company_id
   WHERE c.id=v_category_id AND c.company_id=p_company_id
     AND c.is_active AND parent.is_active AND main.is_active
 ) THEN
  RAISE EXCEPTION 'يجب اختيار فئة ثانوية نشطة مرتبطة بفئة فرعية ورئيسية قبل اعتماد الصنف'
    USING errcode='22023';
 END IF;

 -- p_item_code is retained only for RPC compatibility. The database trigger
 -- generates the authoritative item code from the item-code policy.
 INSERT INTO public.erp_items(
  company_id,item_code,item_name,item_name_en,base_unit,purchase_price,sale_price,
  reorder_level,expiry_tracking,is_active,tax_rate,discount_limit,brand_name,
  package_description,source_name,is_demo_data,show_in_app,category_id
 ) VALUES(
  p_company_id,NULL,coalesce(nullif(trim(p_item_name),''),v_proposal.name_ar),
  coalesce(p_item_name_en,v_proposal.name_en,''),
  coalesce(nullif(trim(p_unit_name),''),v_proposal.unit_name),
  0,0,0,false,true,0,0,null,v_proposal.description,
  'اقتراح نشاط من منصة سلسلة',false,true,v_category_id
 ) RETURNING id INTO v_item_id;

 UPDATE public.erp_business_workspace_item_proposals
 SET status='approved',reviewed_by=v_user,reviewed_at=now(),
     review_note=nullif(trim(coalesce(p_note,'')),''),
     platform_item_id=v_item_id
 WHERE id=p_proposal_id;
 RETURN v_item_id;
END;
$function$;
revoke all on function private.review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) from public,anon;
grant execute on function private.review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) to authenticated;
create or replace function public.erp_review_business_workspace_item_proposal(
 p_proposal_id uuid,p_decision text,p_company_id uuid default null,p_category_id uuid default null,
 p_item_code text default null,p_item_name text default null,p_item_name_en text default null,p_unit_name text default null,p_note text default null
) returns uuid language sql security invoker set search_path=pg_catalog,public,auth,private
as $$ select private.review_business_workspace_item_proposal(p_proposal_id,p_decision,p_company_id,p_category_id,p_item_code,p_item_name,p_item_name_en,p_unit_name,p_note); $$;
revoke all on function public.erp_review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) from public,anon;
grant execute on function public.erp_review_business_workspace_item_proposal(uuid,text,uuid,uuid,text,text,text,text,text) to authenticated;
