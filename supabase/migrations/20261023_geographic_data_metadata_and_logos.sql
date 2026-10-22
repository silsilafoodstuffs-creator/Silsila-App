-- Add provenance, coordinates and governorate image references for the geographic master data.
-- Administrative hierarchy counts: 27 governorates, 365 districts, 5,716 shiyakhas/area records.
-- Division source: Open Admin Data, CC BY 4.0; compare official structure with CAPMAS and Ministry of Local Development.
alter table public.erp_geographic_data
  add column if not exists logo_url text,
  add column if not exists logo_source_url text,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

create index if not exists idx_erp_geographic_data_company_level
  on public.erp_geographic_data(company_id, level, geo_code);

update public.erp_geographic_data g
set logo_url = v.logo_url,
    logo_source_url = v.logo_source_url,
    updated_at = now()
from (values
  ('EG-GOV-01','https://commons.wikimedia.org/wiki/Special:FilePath/Emblem%20Cairo%20Governorate.svg','https://commons.wikimedia.org/wiki/File:Emblem%20Cairo%20Governorate.svg'),
  ('EG-GOV-02','https://commons.wikimedia.org/wiki/Special:FilePath/Emblem%20Giza%20Governorate.jpg','https://commons.wikimedia.org/wiki/File:Emblem%20Giza%20Governorate.jpg'),
  ('EG-GOV-03','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Qalubiya%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20Qalubiya%20Governorate.png'),
  ('EG-GOV-04','https://commons.wikimedia.org/wiki/Special:FilePath/Emblem%20Alexandria%20Governorate.jpg','https://commons.wikimedia.org/wiki/File:Emblem%20Alexandria%20Governorate.jpg'),
  ('EG-GOV-05','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Behira%20Govenorate.JPG','https://commons.wikimedia.org/wiki/File:Flag%20of%20Behira%20Govenorate.JPG'),
  ('EG-GOV-06','https://commons.wikimedia.org/wiki/Special:FilePath/Matrouh%20Governorate-logo.PNG','https://commons.wikimedia.org/wiki/File:Matrouh%20Governorate-logo.PNG'),
  ('EG-GOV-07','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20de%20Damietta.png','https://commons.wikimedia.org/wiki/File:Governadorat%20de%20Damietta.png'),
  ('EG-GOV-08','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20de%20Daqahliya.png','https://commons.wikimedia.org/wiki/File:Governadorat%20de%20Daqahliya.png'),
  ('EG-GOV-09','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Kafr%20El-Sheikh%20Governorate-official.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20Kafr%20El-Sheikh%20Governorate-official.png'),
  ('EG-GOV-10','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Gharbia%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20Gharbia%20Governorate.png'),
  ('EG-GOV-11','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Menoufia%20Governorate.PNG','https://commons.wikimedia.org/wiki/File:Flag%20of%20Menoufia%20Governorate.PNG'),
  ('EG-GOV-12','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20Of%20Sharkia%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20Of%20Sharkia%20Governorate.png'),
  ('EG-GOV-13','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20d%27Ismailiya.png','https://commons.wikimedia.org/wiki/File:Governadorat%20d%27Ismailiya.png'),
  ('EG-GOV-14','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Port%20Said%20Governorate.PNG','https://commons.wikimedia.org/wiki/File:Flag%20of%20Port%20Said%20Governorate.PNG'),
  ('EG-GOV-15','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20the%20governorate%20of%20suez.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20the%20governorate%20of%20suez.png'),
  ('EG-GOV-16','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20de%20Sinai-Sinai%20del%20nord.png','https://commons.wikimedia.org/wiki/File:Governadorat%20de%20Sinai-Sinai%20del%20nord.png'),
  ('EG-GOV-17','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20South%20Sinai%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20South%20Sinai%20Governorate.png'),
  ('EG-GOV-18','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20de%20Bani%20Suwayf.png','https://commons.wikimedia.org/wiki/File:Governadorat%20de%20Bani%20Suwayf.png'),
  ('EG-GOV-19','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20de%20Faium.png','https://commons.wikimedia.org/wiki/File:Governadorat%20de%20Faium.png'),
  ('EG-GOV-20','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Minya%20Governorate.jpg','https://commons.wikimedia.org/wiki/File:Flag%20of%20Minya%20Governorate.jpg'),
  ('EG-GOV-21','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20the%20Asyut%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20the%20Asyut%20Governorate.png'),
  ('EG-GOV-22','https://commons.wikimedia.org/wiki/Special:FilePath/Governadorat%20de%20Suhaj.png','https://commons.wikimedia.org/wiki/File:Governadorat%20de%20Suhaj.png'),
  ('EG-GOV-23','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Qena%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20Qena%20Governorate.png'),
  ('EG-GOV-24','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Luxor%20Governorate.gif','https://commons.wikimedia.org/wiki/File:Flag%20of%20Luxor%20Governorate.gif'),
  ('EG-GOV-25','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Aswan%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20Aswan%20Governorate.png'),
  ('EG-GOV-26','https://commons.wikimedia.org/wiki/Special:FilePath/Red%20sea%20governorate%20flag.png','https://commons.wikimedia.org/wiki/File:Red%20sea%20governorate%20flag.png'),
  ('EG-GOV-27','https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20New%20Valley%20Governorate.png','https://commons.wikimedia.org/wiki/File:Flag%20of%20New%20Valley%20Governorate.png')
) as v(geo_code, logo_url, logo_source_url)
where g.geo_code = v.geo_code
  and g.level = 'governorate';
