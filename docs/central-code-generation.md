# Central Code Generation — Silsila ERP

## Ownership and behavior

- New identifiers are assigned by Supabase `BEFORE INSERT` triggers, not by Flutter form counters.
- Generated-code fields in ERP forms are read-only. The preview is illustrative; the database-issued value is authoritative.
- Each configurable code type uses a three-letter English prefix and a configurable numeric width (1–12 digits).
- Prefix uniqueness is validated both in the policy editor and in the database policy function.
- The policy registry is stored per company in `erp_program_policies` under `code_generation_registry`.
- The preview RPC is executable by authenticated users only. The internal policy resolver is not directly executable by client roles.

## Item identifiers

Item identifiers use a separate hierarchical format:

```text
[prefix: 3 letters][primary category: 2 digits][secondary category: 2 digits][tertiary category: 2 digits][serial: 2 digits]
```

The item prefix is configurable. The eight numeric digits encode the three category levels and the item sequence.

## Covered records

The central policy covers the ERP master and transaction code families, including accounts, branches, warehouses, parties, employees, HR structure, cost centers, cashboxes, cash movements, vouchers, checkbooks, journals, price lists, sales and purchase documents, payroll, user classifications, and permission templates.

Business workspaces also receive database-generated identifiers for branches, warehouses, counterparties, departments, employees, cash movements, and operational documents, including transfers and adjustments.

## Historical identifiers

Existing non-empty identifiers are intentionally preserved. This avoids changing codes printed on historical documents or used by external integrations. New records receive the configured central format. A historical-code migration should be a separate, reviewed operation with an explicit old-to-new mapping and reference checks; it is not part of automatic insert numbering.
