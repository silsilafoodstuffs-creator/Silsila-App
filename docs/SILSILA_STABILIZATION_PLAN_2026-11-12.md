# Silsila ERP Stabilization and UI Unification

**Date:** 2026-11-12  
**Baseline:** `main` at `7db839cad5aee5a00e291142c7f3717fc23360ab`  
**Working branch:** `stabilization/ui-unification-2026-11`

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
3. The Android validation runner was using the runner's default Java `25.0.5` with Gradle `8.10.2`. The latest main validation failed in `flutter build apk --debug` with `What went wrong: 25.0.5`, while Dart analysis, Flutter tests, Web build and desktop/mobile WebView checks passed on that commit.
4. A successful static analysis or Web build does not prove the Android build, every CRUD path, or every screen's database integration.

## Changes in this stabilization branch

- Added `ErpQuickTaskKind` so screens can select action style semantically instead of relying on Arabic/English label parsing. The old inference remains as a backwards-compatible fallback for screens not yet migrated.
- Migrated the item-category and brand toolbars to explicit semantic action kinds. Tree and table actions now retain their actual icons.
- Added widget regression tests for tree/table icon and color behavior.
- Applied the project's 40px row target to the item-category and brand DataTables; compacted brand tree rows and brand table images.
- Pinned JDK 17 (Temurin) in both full-validation and release-APK workflows. The Java setup is intentionally performed without Gradle caching before Android project generation, because the repository currently does not track an `android/` directory and CI generates the platform project dynamically.
- Added the stabilization branch to full-validation triggers for safe CI verification.

## Validation status

The current branch CI run is:
- Dart analysis: passed.
- Focused company-branches screen test: passed.
- Web build: passed.
- Desktop/mobile WebView smoke test: passed.
- Full Flutter test suite: failed; failure details must be inspected before merge.
- Android debug APK: running at the time of this report; do not mark successful until the job and APK artifact verification complete.

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
