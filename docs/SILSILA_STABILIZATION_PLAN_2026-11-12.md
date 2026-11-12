# Silsila ERP Stabilization and UI Unification

**Date:** 2026-11-12  
**Main baseline before concurrent CI update:** `7db839cad5aee5a00e291142c7f3717fc23360ab`  
**Current main base:** `7d636d64f91dcf75256cd1e7e00281ef6b2e0c51`  
**Working branch:** `stabilization/ui-unification-2026-11-v2`

## Purpose

This work is separate from Silsila Studio. It stabilizes the existing ERP, reduces regressions between screens, unifies shared UI behavior, and closes operational gaps without rebuilding the product or changing production data.

## Repository inventory at baseline

The recursive Git tree contained 815 tracked files:

| Area | Count | Notes |
|---|---:|---|
| `lib/erp/screens/*.dart` | 70 | Includes one backup screen and a shared panel; not 70 independently complete routes |
| `lib/erp/services/*.dart` | 31 | Repositories and service layer |
| `lib/erp/widgets/*.dart` | 3 | Only the ERP-specific widget folder; other widgets exist elsewhere |
| `test/**/*_test.dart` | 18 | Automated test files, not a complete per-screen coverage matrix |
| `supabase/migrations/*.sql` | 417 | Historical migrations; count does not prove all are applied to the hosted project |

The repository already contains:
- `docs/SILSILA_ERP_COMPLETION_AUDIT.md`
- `docs/SILSILA_CORE_96_DIRECT_ROUTES_SCHEMA_CROSSWALK_2026-11-11.md`
- specialized repositories for accounts, inventory, documents, parties, payroll, reports, and other domains.

These documents are starting evidence, not proof that every route is operationally complete.

## Confirmed defects and risks

1. The shared `ErpQuickTaskButton` inferred both icon and color from the localized label. Consequently, labels containing «عرض» could replace a caller-supplied tree/table icon with a preview icon. Label wording could also change action styling unexpectedly.
2. The brand catalog and item categories had separate tree/table implementations and different row sizing.
3. The Android runner defaulted to Java `25.0.5` with Gradle `8.10.2`. The latest main validation failed in `flutter build apk --debug` with `What went wrong: 25.0.5`, while Dart analysis, Flutter tests, Web build and desktop/mobile WebView checks passed on that commit.
4. A successful static analysis or Web build does not prove the Android build, every CRUD path, or every screen's database integration.

## Confirmed completion backlog from the existing route/UI audits

The existing repository audits already identify substantial work that must not be hidden behind a visual refresh:

- 485 menu entries, 468 unique page labels, and 17 repeated labels.
- 63 menu entries still route to the generic `_workspace()` instead of a domain-specific screen.
- 14 report names in `_isDatabaseReport` have no matching source key in the report reader; the 45 intersecting source mappings are candidates, not proof of calculated/reconciled reports.
- 170 Business Suite entries share 53 record/form types and still need page-by-page mapping to the correct operational entity, line tables, and RPC lifecycle.
- The active `main.dart` ThemeData differs from the unused `SilsilaTheme.light`: active tables are 48–64px with 12/14px margins/spacing, while the approved standard is 40px and 5px. Switching the entire theme blindly is unsafe because many screens have not been migrated/tested against compact table cells.
- `_pricingPolicyScreen` and `_transactionRestrictionsScreen` save company-scoped configuration to `erp_company_settings`; the repository explicitly documents that these settings do not themselves enforce price or transaction rules in trusted posting RPCs. Server-side enforcement remains required before those policies can be described as operational.

Existing design references that should be used rather than recreated:
- `SILSILA_MENU_ROUTE_PAGE_INVENTORY_2026-11-11.md`
- `SILSILA_GENERIC_WORKSPACE_PAGE_DESIGN_CLOSURE_2026-11-11.md`
- `SILSILA_REPORTS_FORMULA_DICTIONARY_2026-11-11.md`
- `SILSILA_RLS_PERMISSION_SCOPE_DESIGN_MATRIX_2026-11-11.md`
- `SILSILA_UI_GLOBAL_DESIGN_COMPLIANCE_AUDIT_2026-11-11.md`

These are the next integration backlog, not completed work.

## Changes in this stabilization branch

- Added `ErpQuickTaskKind` so screens can select action style semantically instead of relying on Arabic/English label parsing. The old inference remains as a backwards-compatible fallback for screens not yet migrated.
- Migrated the item-category and brand toolbars to explicit semantic action kinds. Tree and table actions now retain their actual icons.
- Added widget regression tests for tree/table action icon and color behavior.
- Added a shared `ErpStandardDataTable` component and migrated both item categories and brands to it, centralizing 40px row/header metrics and compact table spacing.
- Added a shared `ErpCatalogTreeCard` and migrated both item categories and brands to it, centralizing tree indentation, selection, border and spacing.
- Compacted brand tree rows and brand table images; fixed the brand group count interpolation.
- Kept the Java 17 fix already committed to `main`, then added JDK 17 to the release APK workflow. The full-validation workflow also includes this branch for safe CI verification.
- Added this baseline and acceptance-gate document.

## Validation status

Validation must be read from the latest run for this branch. Do not infer success from a prior SHA. Required checks:
- Dart analysis
- Full Flutter test suite and focused tests
- Production-path Web build and output verification
- Desktop and mobile WebView smoke tests
- Android debug APK build and output verification
- Release APK workflow after successful full validation

No Supabase schema, RLS policy, migration, or production data was changed in this slice.

## Stabilization sequence

### A. Shared UI foundation
- Introduce explicit semantic action types for quick actions, toolbar controls, and common dialogs.
- Establish shared design tokens for colors, spacing, field heights, row heights, typography, and RTL.
- Keep legacy behavior available while migrating screens in controlled groups.
- Prevent generic widgets from inventing success messages or confirmation dialogs when the screen owns the operation.

### B. Catalog family
- Use item categories as the visual reference for brand catalog tree/table structure.
- Align visible columns, selection behavior, image controls, active state, search, expand/collapse, and row density.
- Keep the data model honest: brand groups are groupings, not a fabricated multi-level parent/child database hierarchy.

### C. Screen and route inventory
For every route, record:
- route/menu entry and target screen;
- specialized screen versus generic workspace fallback;
- source repository/service and Supabase tables/RPCs;
- company/branch/warehouse scoping;
- RLS and role checks;
- read/create/update/delete/approve/post behavior;
- loading, empty, error and success states;
- responsive and RTL behavior;
- automated test coverage and manual acceptance evidence.

### D. Data integration and completion
- Fix missing or incorrect repository bindings before UI rewrites.
- Do not introduce new schema or migrations unless a confirmed functional gap requires them.
- Do not write directly to unrelated tables from presentation widgets.
- Use transactions/RPCs for multi-row operations that must be atomic.
- Preserve company scoping and RLS; never weaken authorization to make a screen work.

### E. Regression and release gate
A screen is complete only when its required operations work against the correct data source and authorization model. The release gate must include:
- `flutter analyze lib test`
- `flutter test`
- production-path Web build and output verification
- desktop and mobile WebView smoke tests
- Android debug APK build and output verification
- release APK workflow after successful full validation
- focused CRUD and permission tests for changed screens.

## Safety rules

- Work on the stabilization branch first; do not overwrite `main` while CI is red.
- Do not reset or delete production data.
- Do not claim a migration is applied based only on a SQL file existing in the repository.
- Do not claim a screen is complete based only on its route or Dart file existing.
- Every reported percentage must be based on a defined checklist with evidence.
