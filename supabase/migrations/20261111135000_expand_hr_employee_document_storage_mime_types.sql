-- Employee document upload accepts PDF, DOC and DOCX in the Flutter client.
-- Keep the existing private bucket, company-scoped policies and 8 MiB size cap.
begin;

do $$
begin
  if not exists (
    select 1 from storage.buckets where id = 'erp-company-assets'
  ) then
    raise exception 'Required storage bucket erp-company-assets does not exist';
  end if;
end;
$$;

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
]
where id = 'erp-company-assets';

commit;
