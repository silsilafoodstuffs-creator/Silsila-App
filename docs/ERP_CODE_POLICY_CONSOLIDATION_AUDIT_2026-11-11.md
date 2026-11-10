# Silsila ERP — Code Policy Consolidation Audit
Date: 2026-11-11
Branch: `main`
Supabase project: `teitsopmhruczplwlwgn`

## Scope

Consolidate code policies in **Program Policies > Coding**, retire the duplicate standalone code-policy screen, align persisted policy metadata with the central generator, preserve all issued identifiers, and verify the important code paths without leaving test records.

## Completed

- Removed the standalone `ErpCodePolicyPanel` from ERP navigation, permission navigation, and validation path filters. The old source file is no longer present in `main`.
- Removed the stale standalone screen entry from the archived navigation backup and deleted the obsolete manual `Build Silsila ERP Web Preview` workflow.
- Kept the single authoritative policy editor at `Program Policies > Coding`.
- The unified editor defines 67 central code families plus the dedicated geographic, customer, category, brand, item, and business-policy definitions.
- The UI filters five retired legacy duplicate policy rows from the grid, preview, and exports. The internal `code_generation_registry` remains in Supabase as generator storage but is hidden from all user-facing policy views. Legacy rows were preserved; no issued data was deleted.
- Updated the customer registry's nested serial field metadata to match the approved four-digit customer serial.
- Aligned persisted and central-registry policy values for:
  - Payment methods: `PAY` + 4 digits (matches issued `PAY0001`… codes).
  - Item units: `UNT` + 4 digits (matches issued `UNT0001`… codes).
  - Shifts: `Shf` + 5 digits.
  - Permission templates: `Tpl` + 5 digits (matches issued codes).
  - User classifications: `Cls` + 5 digits (matches issued codes).
- Updated the central generator and preview fallbacks for unit and payment-method codes.
- Corrected Egypt's country-master code from `02` to `20`, matching the already-issued geographic hierarchy. Existing geographic codes were not rewritten.
- Documented 67 central code definitions and the aligned code formats.

## Live database verification

- Egypt: exactly one active country row with code `20`.
- Geographic hierarchy: 27 governorates, 365 districts, and 5,772 areas; all existing hierarchical codes match the expected `20` / `Rig20...` patterns.
- Item categories: 88 main, 264 subcategories, and 528 secondary categories; every level matches its two-digit hierarchical segment.
- Brands: 70 records, all matching `BraNN`; one default `Bra00` exists.
- Items: 1 existing item, valid `Itm` code.
- Customers: no current customer records; customer policy and registry both specify 8 inherited geographic digits plus a four-digit serial.
- Users: 3 existing user codes match the user-type-only inheritance rule; 6 user types have valid `TypNN` codes.
- Permission templates: 10 existing `TplNNNNN` codes.
- Payment methods: 6 existing `PAYNNNN` codes.
- Item units: 16 existing `UNTNNNN` codes.
- User classifications: 9 existing `ClsNNNNN` codes.
- Shifts: no current rows; policy is set to `Shf` + 5 digits.
- No duplicate central prefixes were found.
- All active `code_type.*` policy rows with registry entries match their central-registry prefix and width. Five retired duplicate legacy rows intentionally have no active registry entry and remain hidden from the UI.

## Transactional generator checks

A transaction-based insert/rollback check successfully exercised geographic area, customer, item/default-brand, employee, sales representative, user, payment method, item unit, shift, permission-template, and user-classification generators. All generated values matched their expected formats. The transaction was rolled back, and a follow-up query confirmed zero temporary test records remained.

## Validation and deployment status

- Full validation workflow is now manual-only (`workflow_dispatch`) so it does not consume time after every commit, consistent with the agreed milestone/final-test approach.
- Production Pages deployment remains automatic on pushes to `main` and can also be run manually.
- The separate ERP preview workflow was removed.
- No final GitHub Actions run result was available during this audit. Flutter Analyze, Flutter Test, Web build, WebView desktop/mobile, Android Debug APK, deployed Pages smoke test, and deployed WebView checks remain **unverified until the manual validation and production deployment runs report their results**.

## Completion estimate for this work package

| Area | Completion |
|---|---:|
| Standalone screen retirement and navigation/permission cleanup | 100% |
| Duplicate-policy filtering and unified editor coverage | 100% |
| Central policy/registry consistency for active code families | 100% |
| Geographic, customer, category, brand, item, user and representative generator checks | 100% for tested paths |
| Unit/payment/shift/template/classification generator checks | 100% for tested paths |
| UI geometry: global text-field theme is 40px; all 50 active screens with explicit dropdown option heights use 40px; global DataTable theme sets 40px rows and 5px column spacing, and all 11 active screens with explicit table overrides were normalized | 95% (runtime visual verification remains) |
| Final Flutter/Web/Android/Pages workflow evidence | 0% verified |

Estimated completion for this coding-policy consolidation work package: **85%**. The remaining portion is final CI/build/deployment evidence and runtime visual verification across all screens. This is not a claim that the entire Silsila ERP product is 85% functionally complete.

## Broader project items still open

The master implementation backlog still contains work outside this coding-policy task: full CRUD/RLS and company-isolation review, complete purchasing/sales/inventory/finance/HR workflows, CRM/service lifecycle, asset/manufacturing/construction integration, report-to-source reconciliation, electronic invoicing and external integrations, real-device testing, and Supabase security/performance findings. These are not counted as completed by this code-policy audit.
