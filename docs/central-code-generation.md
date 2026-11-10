# Central Code Generation — Silsila ERP

## Ownership and behavior

- New identifiers are assigned by Supabase `BEFORE INSERT` triggers, not by Flutter form counters.
- Code-policy values can be changed only after pressing **تعديل** for the current policy tab. Saving closes edit mode and confirms with **تم الحفظ**.
- Prefixes and digit widths lock independently for each code family as soon as that family has its first persisted code. The policy screen reads the lock state from `erp_code_policy_lock_status`; if that check is unavailable, code-format editing stays disabled rather than risking a change to an issued code.
- Existing non-empty identifiers are intentionally preserved. This avoids changing codes printed on historical documents or used by external integrations. New records receive the configured central format.
- Standard central code types use a three-letter English prefix and configurable numeric width (1–12 digits). The item serial width is configurable from 1–8 digits; customer serial width remains 1–12 digits.
- Prefix uniqueness is validated in the policy editor and in the database policy resolver.
- The policy registry is stored per company in `erp_program_policies` under `code_generation_registry`. Legacy employee, user, supplier, representative, branch, department, job, work-location, grade, and salary-element policies are synchronized to the corresponding central keys.
- The authenticated preview RPC for extended entities is `erp_preview_next_extended_central_code(company_id, entity_key)`. The internal policy resolver and trigger functions are not directly executable by client roles.

## Item identifiers

Item identifiers use this format:

```text
[prefix: 3 letters][primary category: 2 digits][secondary category: 2 digits][tertiary category: 2 digits][serial: 1–8 digits]
```

The default is `Itm` + six inherited category digits + a three-digit serial. The prefix and serial width are editable until the first item code is issued. The three category segments remain two digits each to preserve the existing category hierarchy. Workspace item proposal approval now requires a valid secondary category and inserts a blank `item_code`; the database trigger assigns the same central item code. The former random `PRP-` placeholder is no longer used.

## Customer and geographic identifiers

- Customer codes inherit the geographic hierarchy and use the customer policy's prefix and serial width. They lock after the first customer code is issued.
- Country, governorate, district, and area codes retain the fixed two-digit hierarchy used by the existing geographic/customer-code functions. Their labels in the policy grid explain the parent inheritance.
- Category hierarchy codes retain their existing `Cat` + two-digit-per-level structure. Their prefix/segment layout is kept fixed to protect existing item-category and item-code paths.
- The brand policy remains a reserved policy because the current schema has no independent brand master/code column; it must not be treated as a generated brand identifier until that model exists.

## Covered records

The central code families cover accounts, branches, warehouses, parties, employees, HR structure, cost centers, cashboxes, cash movements, vouchers, checkbooks, journals, price lists, sales and purchase documents, payroll, user classifications, permission templates, and business-workspace records.

The extended generator now also covers fixed assets and asset categories/depreciation/disposals; CRM activities and leads; construction projects, material requests, material movements, payment certificates and site reports; manufacturing BOMs/work centers; production orders, quality checks and variances; service tickets, visits and SLA policies; HR contracts, advances and custodies; and business-suite records. Workspace item links use a workspace-scoped code generator.

## Adding a future code family

Whenever a new screen introduces a persisted identifier:

1. Add a `_codePolicyTypeDefinitions` entry with a unique three-letter prefix and suitable digit width.
2. Add the table/column mapping to `erp_assign_extended_central_code` (or the workspace-scoped generator where the row is keyed by `workspace_id`).
3. Add the matching first-code check to `erp_code_policy_lock_status`.
4. Add the matching entry to the authenticated preview mapping.
5. Add a database migration and a test proving that an insert with an empty code receives a value and that the policy locks after the first issued code.

Do not add a visible policy row without wiring its database generator and lock check. Keep preview values illustrative; the database trigger remains authoritative.

## Historical identifiers

A historical-code migration must be a separate, reviewed operation with an explicit old-to-new mapping and reference checks. It is not part of automatic insert numbering.
