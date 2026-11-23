# Silsila Enterprise Readiness Baseline
Date: 2026-11-23
Repository: `silsilafoodstuffs-creator/Silsila-App`
Production database project: `teitsopmhruczplwlwgn`

## Purpose
This baseline records observed state and safe engineering decisions for improving the Silsila ERP experience, performance, security, reliability, and release quality. It is not authorization to make unreviewed destructive database changes.

## Verified repository state
- Default branch: `main`.
- Latest observed commit at review time: `ac4df87252558c9d9d2c6e5f08fa86f0484f8611` — responsive Executive Summary command-center redesign.
- Flutter SDK pinned in the main validation workflow: 3.29.3.
- Supabase Flutter dependency: `^2.10.0`.
- Full validation already covers Dart analysis, Flutter tests, Web release build, desktop/mobile Chromium WebView checks, Android Release APK build, APK signature/identity checks, and artifacts.
- The Android release workflow verifies the expected signing certificate and launcher package identity. Do not weaken these checks.

## Live Supabase Advisor snapshot
Observed 2026-11-23 around 00:41 UTC. Counts are advisor findings, not proof that every finding is exploitable or should be changed mechanically.

### Security
- 6 tables have RLS enabled but no policies: API credentials/usage buckets and historical category archive/recovery tables. Keep these private unless an explicit reviewed access requirement exists.
- 5 SECURITY DEFINER functions are executable by `anon`. Public advertising/offer functions may be intentional; inspect function bodies, returned columns, input validation, and data scope before changing grants.
- 66 SECURITY DEFINER functions are executable by `authenticated`. Review each function's identity, company, branch, warehouse, resource, and action authorization. A warning is not a reason to revoke all access.
- 17 tables have multiple permissive policies for the same role/action. Review policy semantics and query plans before consolidation.

### Performance and health
- 108 foreign keys have no covering index according to Advisor. Prioritize by table size, join/delete/update patterns, and observed slow queries; create only justified indexes and plan for production lock impact.
- 10 RLS policies re-evaluate auth/current-setting expressions per row. Where semantics permit, use scalar subqueries such as `(select auth.uid())`.
- 174 indexes are reported unused. Do not drop them solely on this signal; confirm workload/retention windows and query plans first.
- 3 historical backup tables have no primary key. Treat as archive/restore assets; do not mutate or delete without recovery verification.

## Non-negotiable safety rules
1. No destructive DDL, blanket GRANT/REVOKE, table drops, data cleanup, or migration replay based only on Advisor output.
2. Preserve tenant isolation and permission-template behavior across company, branch, warehouse, employee, cashbox, and sensitive HR/financial scopes.
3. Never expose Supabase service-role/secret keys in Flutter or any client bundle.
4. Every schema change must be additive or reversible where possible, reviewed against live dependencies, represented by a migration, and verified against the live project.
5. Do not claim load capacity without measured concurrency, latency percentiles, error rate, database saturation, and test scope.
6. Keep the existing Silsila identity: RTL, Tajawal, purple `#3E007D`, orange `#FFA015`, pink `#FF27C3`, white surfaces, compact controls, and mobile-safe typography.
7. Do not replace the current ERP navigation, permission model, business workflows, or real data for a visual refresh.

## Implementation workstreams
- **Experience:** finish responsive command-center polish, empty/loading/error states, compact data density, consistent interaction feedback, keyboard navigation, and accessible contrast.
- **Flutter performance:** profile frame build/raster time, reduce unnecessary rebuilds, dispose controllers/subscriptions, use lazy lists/tables, and avoid fetching executive data before authorization is established.
- **Data access:** require bounded queries, server-side filtering/sorting, stable keyset pagination for large operational datasets, and query-specific indexes backed by EXPLAIN/ANALYZE.
- **Database security:** inventory SECURITY DEFINER functions and policies; prove tenant/action scope for each sensitive RPC; test anon/authenticated/unauthorized cross-company access.
- **Reliability:** idempotent writes, transaction boundaries, retries only for transient failures, offline-safe drafts where supported, and observable sync failures.
- **Release quality:** retain full Web/Android Release/WebView gates; add controlled, non-destructive load smoke tests and dependency review.
- **Operations:** monitor errors, latency, slow SQL, storage growth, backup completion, and restore drills with documented RPO/RTO.

## Controlled load smoke test
The manual k6 workflow added with this baseline exercises only the public Web application shell and Flutter bootstrap asset. It is deliberately capped at 10 virtual users and performs no login, database writes, or ERP transaction simulation. It is a deployment smoke check, **not** a capacity certification or a substitute for authenticated multi-tenant load testing.

## Acceptance criteria for claiming readiness
- No unresolved critical/high security issue in the reviewed scope.
- Cross-company and cross-warehouse negative authorization tests pass.
- Large-list screens use bounded server-side pagination and filtering.
- Measured p95 latency/error rate and resource utilization are recorded under a documented workload.
- Backup restoration has been exercised, not merely scheduled.
- Full validation and signed Android Release checks pass on the exact candidate commit.
- Any skipped test or unavailable environment is explicitly reported.
