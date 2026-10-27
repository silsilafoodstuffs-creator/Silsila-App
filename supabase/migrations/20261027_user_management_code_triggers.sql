-- Keep display codes populated for newly inserted types and templates.
create or replace function public.erp_set_user_type_display_code()
returns trigger language plpgsql set search_path=public as $$
begin
  new.type_code_display := 'UT' || lpad(new.type_code::text, 4, '0');
  return new;
end;
$$;
drop trigger if exists erp_user_types_display_code_trigger on public.erp_user_types;
create trigger erp_user_types_display_code_trigger
before insert or update of type_code on public.erp_user_types
for each row execute function public.erp_set_user_type_display_code();

create or replace function public.erp_set_permission_template_display_code()
returns trigger language plpgsql set search_path=public as $$
begin
  new.template_code_display := 'PT' || lpad(new.template_code::text, 4, '0');
  return new;
end;
$$;
drop trigger if exists erp_permission_templates_display_code_trigger on public.erp_permission_templates;
create trigger erp_permission_templates_display_code_trigger
before insert or update of template_code on public.erp_permission_templates
for each row execute function public.erp_set_permission_template_display_code();