-- User requested the complete catalogue to be available for every configured activity.
UPDATE public.activity_types
SET show_in_app = true
WHERE is_active = true
  AND code BETWEEN 'ACT001' AND 'ACT020';

UPDATE public.erp_item_categories
SET show_in_app = true
WHERE company_id = '47278c99-7743-4dd4-9ce6-d11f28e02504'
  AND activity_code BETWEEN 'ACT001' AND 'ACT020'
  AND is_active = true;