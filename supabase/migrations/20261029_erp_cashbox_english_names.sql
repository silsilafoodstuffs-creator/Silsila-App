-- Bilingual treasury names required by the ERP treasury grid.
begin;
alter table public.erp_cashboxes
  add column if not exists cashbox_name_en text not null default '';

update public.erp_cashboxes
set cashbox_name_en = case
  when cashbox_name_en is null or btrim(cashbox_name_en) = '' then
    case
      when is_bank_account then coalesce(nullif(bank_name, ''), 'Bank Account')
      when branch_id is null then 'Central Treasury'
      else 'Branch Treasury'
    end
  else cashbox_name_en
end;
commit;
