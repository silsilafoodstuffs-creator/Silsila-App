# Central Code Generation — Silsila ERP

## Ownership and behavior

- There is one user-facing coding-policy location: **إعدادات عامة > سياسات البرنامج > تكويدية**. The former standalone **سياسات الأكواد** screen was retired after confirming its geographic, customer, category, brand, item, and 67 central entity-code definitions are covered by the coding tab. The central database registry and generation triggers remain in place; no policy data or issued identifiers were deleted.

- New identifiers are assigned atomically by Supabase `BEFORE INSERT` triggers, not by Flutter form counters.
- Code-policy values are edited and saved from the coding-policy tab; the database policy resolver and triggers remain authoritative.
- Prefixes and digit widths lock independently for each code family after its first persisted code. If the lock-status check is unavailable, code-format editing remains disabled rather than risking an issued identifier.
- Existing identifiers are preserved unless an explicit, reviewed historical-code migration is run. The November 2026 brand-width migration is such an explicit operation and rebuilds linked item codes after a preflight check.
- Standard central code types use a three-letter English prefix and configurable numeric width. Item serial width is configurable from 1–8 digits; customer serial width is configurable from 1–12 digits.
- Prefix uniqueness is validated in the policy editor and database policy resolver.
- Per-company policy settings are stored in `erp_program_policies` under `code_generation_registry`. Legacy policy keys are synchronized to their corresponding central keys.
- The authenticated preview RPC for extended entities is `erp_preview_next_extended_central_code(company_id, entity_key)`. Internal policy resolver and trigger functions are not directly executable by client roles.

## Item identifiers

The current item-code format is:

```text
[Itm: 3 letters][primary category: 2 digits][secondary category: 2 digits][tertiary category: 2 digits][brand: 2 digits][serial: 3 digits]
```

The default first-code example is `Itm01010101001`:
- `Itm`: item prefix.
- `010101`: the three inherited category levels, each two digits.
- `01`: the numeric part of the selected brand code; the brand prefix is omitted.
- `001`: the serial within the company/category/brand combination.

The database resolves the selected secondary category and active company brand, then generates the next serial under a transaction-scoped advisory lock. A missing brand selection resolves to the system brand `بدون علامة تجارية` (brand code `Bra00`). Workspace item proposal approval requires a valid secondary category and leaves `item_code` blank for the same database trigger; the former random `PRP-` placeholder is not used.

## Brand identifiers

- The company-scoped brand master is `erp_brands`; each row has a unique `brand_code` within its company.
- Brand codes use a three-letter prefix (default `Bra`) followed by two digits (default first assigned code `Bra01`).
- The system brand `بدون علامة تجارية` uses `Bra00`; item codes inherit only its numeric segment (`00`).
- Item-to-brand links use `erp_items.brand_id` with a company-scoped foreign key. The brand name stored on an item is synchronized from the selected active brand.

## Customer, category, and geographic identifiers

- Customer codes use `Cus` by default, followed by eight inherited geographic digits and a four-digit customer serial. The prefix and serial width remain configurable in Program Policies > Coding; the generator and preview use the same four-digit fallback for new companies.
- Country code is two digits (Egypt is `20`). Governorate, center/district, and area segment widths are independently configured in the geographic policy; child codes inherit their parent's numeric code.
- Category hierarchy codes use `Cat` plus two digits for each of the three levels: main, subcategory, and secondary category. The category hierarchy remains aligned with the six category digits embedded in item codes.

## Warehouse storage locations and HR sections

- Root warehouses use `Whs` plus a five-digit serial. A child row in `erp_warehouses` (`parent_warehouse_id` set) is a storage location: `Loc` + the branch code without its prefix + the parent warehouse code without its prefix + a three-digit serial. Only direct children of active root warehouses are allowed; the branch is inherited from the parent when available, otherwise it must be selected.
- Section rows in `erp_hr_departments` (`department_level='section'`) use `Sec` + the parent department code without its prefix + a three-digit serial. The parent must be an active directorate or department.
- The storage-location and section serials are company-wide rather than restarting per parent. Department code suffixes are not unique across parents, so the section serial is company-wide. The storage-location serial is also company-wide for consistent collision protection. Existing legacy codes are preserved and never rewritten.

## User identifiers

- User codes inherit the numeric portion of the selected user-type code, not an employee code. The user prefix remains separate from the inherited type digits and the user serial.
- When a central user-type policy changes, linked user codes are refreshed according to the inheritance rule while existing unrelated code families remain unchanged.

## Covered records

The central code families cover accounts, branches, warehouses, parties, employees, HR structure, cost centers, cashboxes, cash movements, vouchers, checkbooks, journals, price lists, sales and purchase documents, payroll, user classifications, permission templates, and business-workspace records.

The extended generator also covers fixed assets and asset categories/depreciation/disposals; CRM activities and leads; construction projects, material requests, material movements, payment certificates and site reports; manufacturing BOMs/work centers; production orders, quality checks and variances; service tickets, visits and SLA policies; HR contracts, advances and custodies; and business-suite records. Workspace item links use a workspace-scoped code generator.

## Default fallback alignment

The database generator and preview defaults match Program Policies: supplier `Ven`/5, representative `Rep`/5, branch `Brn`/3, department `Dep`/3, storage location `Loc`/3, section `Sec`/3, work location `Plc`/3, grade `Grd`/3, salary element `Elm`/3, item units `UNT`/4, payment methods `PAY`/4, shifts `Shf`/5, user classifications `Cls`/5, customer serial `Cus`/4, user type `Typ`/2, and permission template `Tpl`/5. These are fallbacks for companies without a saved registry; saved company policies remain authoritative.

## Adding a future code family

Whenever a new screen introduces a persisted identifier:

1. Add a `_codePolicyTypeDefinitions` entry with a unique three-letter prefix and suitable digit width.
2. Add the table/column mapping to `erp_assign_extended_central_code` (or the workspace-scoped generator where the row is keyed by `workspace_id`).
3. Add the matching first-code check to `erp_code_policy_lock_status`.
4. Add the matching entry to the authenticated preview mapping.
5. Add a database migration and a test proving that an insert with an empty code receives a value and that the policy locks after the first issued code.

Do not add a visible policy row without wiring its database generator and lock check. Keep preview values illustrative; the database trigger remains authoritative.

## Historical identifiers

A historical-code migration must be a separate, reviewed operation with an explicit old-to-new mapping and reference checks. It must preserve record IDs and foreign-key relationships, verify uniqueness before changing data, and fail before mutation when the preflight checks detect a collision or invalid hierarchy.
