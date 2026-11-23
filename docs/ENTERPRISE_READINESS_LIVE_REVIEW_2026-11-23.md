# Silsila Enterprise Readiness — Live Review

Date: 2026-11-23
Repository branch: `chore/enterprise-readiness-foundation`
Production Supabase project: `teitsopmhruczplwlwgn`

## Scope and safety

This review used read-only Supabase catalog, Advisor, and `pg_stat_statements` queries. No production rows, policies, grants, functions, indexes, authentication settings, or schema objects were changed.

Performance counters below are cumulative since `pg_stat_statements_info.stats_reset = 2026-10-10 18:10:00+00`; they are not a controlled benchmark and must not be interpreted as a 24-hour sample or as proof of capacity.

## Confirmed security posture

- 110 public-schema `SECURITY DEFINER` functions were inventoried.
- All 110 have an explicit `search_path` setting.
- 5 are executable by `anon`; 66 are executable by `authenticated`. These are exposure counts, not vulnerability counts. Each RPC still needs a function-specific authorization review.
- 63 function bodies directly reference `auth.uid()`. Some of the others delegate identity checks to guarded helper functions; absence of a direct reference is not, by itself, proof of an authorization defect.
- The shared company-role helper checks `auth.uid()`, active company membership, and allowed role. The warehouse/branch scope helpers also verify active ERP user linkage and explicit warehouse/branch assignment for non-owner/admin roles.
- Six RLS-enabled tables have no policies: four category archive/recovery snapshots and two API credential/usage tables. They remain inaccessible through RLS and should stay private unless a reviewed use case requires access.
- Supabase Advisor reports leaked-password protection disabled. This setting must be enabled through the project's Auth security configuration; this review did not change Auth settings.
- Multiple-permissive-policy and per-row auth-initplan warnings remain for targeted review; do not consolidate policies without preserving their OR semantics and tenant/branch scope.

### High-impact RPCs sampled

The following functions were inspected at source level: document posting (sales/purchase), physical stocktake posting and count saving, inventory movement/transfer, payroll recalculation, selective data-clear preparation, company profile update, user branch/warehouse assignment, and ERP user password update.

The inspected examples include active-company-role checks and, where applicable, warehouse scope checks. `set_erp_user_password` does not directly call `auth.uid()`, but delegates authorization to `erp_user_has_company_role`, which does. This is a reason to preserve and regression-test the helper, not to add blanket grants or revoke privileges.

## Measured performance signals

### Query statistics

| Query family | Calls since reset | Mean | Maximum | Notes |
|---|---:|---:|---:|---|
| `erp_get_executive_metrics` RPC | 1,221 | 87 ms | 1,028 ms | Aggregates sales, inventory, journal, HR, cash, and master-data KPIs |
| Geographic data by company ordered by `geo_code` | 168 | 543 ms | 1,064 ms | Reads the geographic directory; current indexes include `(company_id, geo_code)` |
| Geographic data by company + active ordered by `geo_code` | 138 | 276 ms | 929 ms | Existing index coverage should be checked with an authenticated EXPLAIN before adding another index |
| ERP item catalog including binary image projection | 181 | 370 ms | 7,362 ms | The catalog query selected `image_data` in the metadata request |
| ERP item-category list by company/code | 346 | 60 ms | 1,473 ms | Existing company/code indexes are present |

### Data and index observations

- `erp_geographic_data` has approximately 6,164 live rows and 13 MB total size. Existing indexes include unique `(company_id, geo_code)`, `(company_id, hierarchical_code)`, `(company_id, level, geo_code)`, and `(company_id, parent_id, level)`.
- `erp_item_categories` has approximately 1,170 live rows and 6.2 MB total size. Existing indexes include `(company_id, category_code)`, `(company_id, activity_code, category_code)`, and `(company_id, activity_code, parent_id)`.
- `erp_items` currently has one active/app-visible row with a stored image; its image payload is about 2.12 MB. This is a real payload-size signal, but not enough to justify modifying stored production image bytes without an approved image-processing policy.
- Several foreign keys without a covering index are on tables with very low current row estimates. Prioritize by table growth and actual join/delete workload; do not add all Advisor-suggested indexes mechanically.

## Code change in this branch

`ProductService` now retrieves ERP catalog metadata without selecting binary category/item images. It fetches image bytes in a second bounded query only for ERP products that remain in the final visible result page, and strips the internal marker before returning product maps. If optional image retrieval fails, catalog metadata still returns and marketplace images are not overwritten.

A focused contract test verifies that the metadata projections exclude `image_data` and that image retrieval is scoped to selected IDs.

This reduces unnecessary image transfer for rows filtered out by category and page limit. It does not shrink the stored 2.12 MB image itself and requires full Flutter validation before claiming a measured speed improvement.

## Work still required before enterprise-readiness claims

1. Add authenticated, non-production negative tests for cross-company, cross-branch, cross-warehouse, employee, HR, and finance access. Never impersonate real production users for this test.
2. Review every exposed `SECURITY DEFINER` RPC, including all 5 anon-executable functions and all 66 authenticated-executable functions; classify intentional public reads versus sensitive writes and prove action/tenant scope.
3. Enable leaked-password protection in Supabase Auth and verify the setting after the change.
4. Capture authenticated `EXPLAIN (ANALYZE, BUFFERS)` for the measured geographic, catalog, and executive-dashboard queries in a staging environment with representative data.
5. Evaluate keyset pagination for large geographic/category/item lists; current UI screens may fetch broad directories for tree/dropdown construction.
6. Review the executive metrics RPC for repeated scans and expensive CTEs, then optimize only against representative plans and KPI reconciliation tests.
7. Perform controlled read-only and authenticated transaction load tests in staging; record p50/p95/p99, error rates, database CPU/connections, and saturation.
8. Configure application error/latency monitoring, alert thresholds, and operational ownership.
9. Verify full Postgres backup retention and complete a restore drill; the ERP selective JSON backup is not a substitute for a full database restore.
10. Implement offline-safe drafts and conflict-aware sync only after idempotency and transaction boundaries are defined and tested.

## Acceptance gates

- Do not change production grants, RLS policies, function security modes, or indexes until a reviewed migration and non-production regression suite prove the exact behavior.
- Keep full Web, Android Release signing, WebView, and Flutter tests required on the exact candidate commit.
- Do not call the application production-ready or load-certified until the security, restore, monitoring, and workload gates above have evidence.
