-- Standardize the four initial Silsila operating branches and their display order.
-- Branch IDs stay unchanged so warehouses, cashboxes, and historical transactions
-- remain linked to the same branch records. Numeric codes determine dropdown order.

do $$
begin
  if exists (
    select 1
    from public.erp_branches b
    where b.branch_name in (
      'فرع القاهرة','القاهرة','فرع الجيزة','الجيزة',
      'فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه',
      'فرع الشرقية','فرع الشرقيه','الشرقية','الشرقيه'
    )
    and exists (
      select 1 from public.erp_branches other
      where other.company_id = b.company_id
        and other.id <> b.id
        and other.branch_code = case
          when b.branch_name in ('فرع القاهرة','القاهرة') then '001'
          when b.branch_name in ('فرع الجيزة','الجيزة') then '002'
          when b.branch_name in ('فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه') then '003'
          else '004'
        end
        and other.branch_name not in (
          'فرع القاهرة','القاهرة','فرع الجيزة','الجيزة',
          'فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه',
          'فرع الشرقية','فرع الشرقيه','الشرقية','الشرقيه'
        )
    )
  ) then
    raise exception 'Branch codes 001-004 are already used by other branches; resolve the conflict before applying this migration.';
  end if;

  -- Temporarily free the current codes to avoid unique(company_id, branch_code) conflicts.
  update public.erp_branches b
  set branch_code = '__silsila_branch_order__' || b.id::text
  where b.branch_name in (
    'فرع القاهرة','القاهرة','فرع الجيزة','الجيزة',
    'فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه',
    'فرع الشرقية','فرع الشرقيه','الشرقية','الشرقيه'
  );

  update public.erp_branches b
  set
    branch_code = case
      when b.branch_name in ('فرع القاهرة','القاهرة') then '001'
      when b.branch_name in ('فرع الجيزة','الجيزة') then '002'
      when b.branch_name in ('فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه') then '003'
      else '004'
    end,
    branch_name = case
      when b.branch_name in ('فرع القاهرة','القاهرة') then 'فرع القاهرة'
      when b.branch_name in ('فرع الجيزة','الجيزة') then 'فرع الجيزة'
      when b.branch_name in ('فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه') then 'فرع القليوبية'
      else 'فرع الشرقية'
    end,
    branch_name_en = case
      when b.branch_name in ('فرع القاهرة','القاهرة') then 'Cairo Branch'
      when b.branch_name in ('فرع الجيزة','الجيزة') then 'Giza Branch'
      when b.branch_name in ('فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه') then 'Qalyubia Branch'
      else 'Sharqia Branch'
    end,
    is_main = (b.branch_name in ('فرع القاهرة','القاهرة')),
    updated_at = now()
  where b.branch_code like '__silsila_branch_order__%'
    and b.branch_name in (
      'فرع القاهرة','القاهرة','فرع الجيزة','الجيزة',
      'فرع القليوبية','فرع القليوبيه','القليوبية','القليوبيه',
      'فرع الشرقية','فرع الشرقيه','الشرقية','الشرقيه'
    );
end;
$$;
