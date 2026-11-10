# Central Code Generation — Silsila ERP

## Ownership and behavior

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

- Customer codes use the `Cus` prefix by default, followed by the inherited geographic digits and the customer serial. The customer prefix and serial width are configurable in the customer policy.
- Country code is two digits (Egypt is `20`). Governorate, center/district, and area segment widths are independently configured in the geographic policy; child codes inherit their parent's numeric code.
- Category hierarchy codes use `Cat` plus two digits for each of the three levels: main, subcategory, and secondary category. The category hierarchy remains aligned with the six category digits embedded in item codes.

## User identifiers

- User codes inherit the numeric portion of the selected user-type code, not an employee code. The user prefix remains separate from the inherited type digits and the user serial.
- When a central user-type policy changes, linked user codes are refreshed according to the inheritance rule while existing unrelated code families remain unchanged.

## Covered records

The central code families cover accounts, branches, warehouses, parties, employees, HR structure, cost centers, cashboxes, cash movements, vouchers, checkbooks, journals, price lists, sales and purchase documents, payroll, user classifications, permission templates, and business-workspace records.

The extended generator also covers fixed assets and asset categories/depreciation/disposals; CRM activities and leads; construction projects, material requests, material movements, payment certificates and site reports; manufacturing BOMs/work centers; production orders, quality checks and variances; service tickets, visits and SLA policies; HR contracts, advances and custodies; and business-suite records. Workspace item links use a workspace-scoped code generator.

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
