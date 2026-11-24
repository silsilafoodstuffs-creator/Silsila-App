# Silsila Hybrid Architecture Decision & Recovery Guardrails

**Decision date:** 2026-11-25  
**Status:** Approved direction; implementation is gated on a verified off-site data-and-storage backup.

## 1. Approved target architecture

- **ERP Web:** React + TypeScript + Vite. Use browser-native DOM, accessible forms, virtualized data grids, server-side filtering/sorting/pagination, and route-level lazy loading.
- **Mobile:** Keep the existing Flutter + Dart Android application as the mobile client. Do not rewrite it as part of the web migration.
- **Backend:** Preserve Supabase Auth, PostgreSQL, RLS, Storage, and existing Edge Functions as the current system of record. Introduce a NestJS modular API only where a measured need exists; do not duplicate business rules or weaken RLS by bypassing the existing database authorization model.
- **Shared contracts:** Define versioned API contracts, generated TypeScript database types, validation schemas, permission identifiers, and domain rules in shared packages. Dart models must be generated or contract-tested against the same API schemas.
- **Data:** One production PostgreSQL database remains authoritative during migration. No schema changes or destructive operations on production as part of the initial web proof-of-concept.

## 2. Migration strategy

Use a strangler migration: implement a new React screen alongside the existing Flutter Web screen, compare behavior and performance, then move one module at a time. Start with Item Categories / Catalog because this is a known performance pain point.

The proof-of-concept must include:
- Existing category hierarchy and activity filtering semantics.
- Search, sorting, pagination, create/edit/delete, and image behavior.
- Existing role and company/branch/warehouse access constraints.
- Arabic RTL, Silsila brand tokens, Tajawal typography, and responsive behavior.
- Regression tests for all important actions and data integrity.
- Browser performance traces and server/database timings against the same data set.

Do not cut over until functional parity, authorization parity, data integrity, and performance acceptance criteria pass. Keep the current Flutter Web route available as rollback until the new screen is accepted.

## 3. Non-negotiable recovery guardrails

- The current `main` branch and the stable pre-Hybrid branch must remain untouched by experimental work.
- Never commit secrets, service-role keys, database passwords, or production exports into Git.
- Never use production data in a new development database without explicit data-minimization and access controls.
- No production migrations, RLS edits, data clearing, or storage mutations during the initial web prototype.
- Every schema change must be a reviewed migration, tested on a disposable environment, and have a documented rollback or forward-recovery plan.
- Preserve all existing ERP features, workflows, identifiers, and business semantics; visual parity alone is not completion.
- Validate restore procedures before declaring a backup complete.

## 4. Repository recovery point

- Repository: `silsilafoodstuffs-creator/Silsila-App`
- Default branch at checkpoint: `main`
- Checkpoint commit: `3d11b7c3c3940adfcf57d74c78d88508f96fba6b`
- Stable branch: `stable/flutter-pre-hybrid-2026-11-25`
- Hybrid work branch: `architecture/hybrid-foundation`
- The stable branch was created from the checkpoint commit and compared against it; GitHub reported identical histories at creation time.

The repository checkpoint includes the committed source tree, Git history reachable from the branch, 464 Supabase migration files, and five checked-in Supabase Edge Function source directories. It does not contain production database contents, Storage object bytes, Auth provider settings, project secrets, or every Dashboard-level project setting.

## 5. Supabase backup gap identified

The connected Supabase organization currently reports the **Free** plan. Supabase documentation states that Free projects do not receive automatic daily database backups; manual exports are required. Supabase database dumps also do not include Storage object bytes. The project currently has seven Storage buckets and 84 Storage object records, and five active Edge Functions.

The application table `public.erp_data_backups` is an application-level selective ERP snapshot mechanism. It is not a full PostgreSQL project backup and must not be represented as one.

Before any production-facing migration or cutover, create and verify:
1. A full logical PostgreSQL export including schema, data, roles/privileges as appropriate, and Auth-related records using a secure, supported backup procedure.
2. A separate off-site export of every Storage bucket's object bytes, preserving bucket/object paths and metadata.
3. A copy of Edge Function source and deployment configuration, plus a manifest of deployed versions/hashes.
4. An inventory of Auth providers, redirect URLs, SMTP, Realtime, API settings, secrets, and other Dashboard settings (record names/configuration only; never store secret values in Git).
5. A restore rehearsal into a separate disposable project/database, including sample file retrieval and authentication checks.

The current tool connection can inspect project metadata, migrations, table metadata, Storage bucket metadata, and Edge Function versions, but it does not provide a direct full database dump or Storage-object archive action. Therefore, no full database/Storage backup is claimed complete at this checkpoint.

## 6. Initial acceptance gates

- **Gate A — Recovery:** off-site database and Storage backups exist, checksums are recorded, and restore rehearsal succeeds.
- **Gate B — Web proof-of-concept:** category/catalog workflows pass functional, security, RTL, accessibility, and performance tests.
- **Gate C — Module migration:** every module passes regression and permission tests before route cutover.
- **Gate D — Production:** staged release, monitored cutover, rollback route, and verified recovery point.

Until Gate A is satisfied, only isolated repository documentation and non-production UI prototyping are permitted.

## 7. Isolated React category proof-of-concept — 2026-11-25

An initial non-production React + TypeScript + Vite screen now exists under `web-react/` on the Hybrid work branch only.

- Uses 10,000 generated mock category rows; it does not read or write production data.
- Implements activity filtering, deferred text search, and fixed-row-height windowing so only a small visible slice is mounted.
- Reuses the repository Tajawal font and Silsila purple/orange brand direction with Arabic RTL layout.
- Includes a smoke test and a dedicated GitHub Actions workflow.
- GitHub Actions run `45514407763` completed successfully for commit `033d2b9045adf8a184a4854fe82a4e7fb0ef8207`: 1 test passed and Vite production build passed.

This is only a technical UI/performance prototype. It is not connected to Supabase, does not implement real CRUD, RLS, permissions, image storage, full category hierarchy behavior, or measured comparison with Flutter Web. No production route was changed and no deployment or cutover occurred. The backup/restore gate remains open.
