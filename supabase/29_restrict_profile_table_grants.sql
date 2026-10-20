-- Reduce direct client privileges on identity tables.
-- Public marketplace reads continue through the deliberately filtered supplier views.
begin;

revoke all on public.profiles from anon;
revoke all on public.supplier_details from anon;
grant select on public.supplier_directory to anon, authenticated;
grant select on public.supplier_public_details to anon, authenticated;

-- Profile changes must go through row-scoped RLS; direct row deletion is not a client feature.
revoke delete, truncate, references, trigger on public.profiles from authenticated;
revoke truncate, references, trigger on public.supplier_details from authenticated;

commit;
