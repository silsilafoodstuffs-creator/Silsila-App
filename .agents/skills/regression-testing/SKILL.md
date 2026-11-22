---
name: regression-testing
description: Select and run risk-based regression tests for Silsila changes across screens, business rules, data, and platforms.
---

# Regression Testing for Silsila

1. Identify the changed behavior, shared components, callers, persisted data, permissions, and platform-specific paths.
2. Build a small impact map: direct tests, neighboring screens, shared widgets/services, and critical user journeys.
3. Run the narrowest relevant test first; then run the full suite when feasible.
4. For shared ERP UI, verify the affected screen plus at least one neighboring consumer of the shared component.
5. For data or authorization changes, test both allowed and denied cases and preserve records/relationships.
6. For responsive changes, cover narrow phone, tablet/desktop, RTL and LTR as relevant.
7. For release-sensitive changes, check Web release build, browser/WebView validation, and Android Release APK using existing CI.
8. Do not weaken, delete, or rewrite a failing test merely to obtain a green build. Confirm whether the test or implementation conflicts with the current approved specification.
9. Distinguish pre-existing failures from failures introduced by the current commit using the base/head comparison.
10. Record exact commands, counts, failing test names, and unresolved risk.
