---
name: verification-before-completion
description: Required evidence-based verification and reporting before claiming a Silsila task is complete.
---

# Verification Before Completion

A task is not complete merely because code was edited or a command was started.

## Required process

1. Inspect the final diff and confirm only intended files changed.
2. Run the narrowest relevant tests first.
3. For Flutter/Dart changes, run applicable checks:
   - `flutter analyze lib test --no-fatal-infos --no-fatal-warnings`
   - `flutter test`
   - `flutter build web --release --base-href "/Silsila-App/"`
   - `flutter build apk --release` through the repository's signed release preparation when required.
4. For browser-facing changes, verify the real browser/WebView workflow, not just compilation.
5. For Supabase changes, verify schema, RLS, grants, relationships, and representative least-privilege access.
6. Inspect GitHub Actions runs for the exact commit or pull request head. Do not use a different commit's green result as proof.
7. If a check is not available in the current environment, state that it was not run and identify the CI check that should run it.
8. Distinguish build success from runtime verification and from successful installation/update on a physical device.

## Reporting format

Report:
- commit or pull request;
- files and behavior changed;
- checks run and their exact outcomes;
- checks skipped/not run and why;
- known risks or follow-up actions.

Never state "all tests passed" unless every required test actually ran and passed. Never claim an APK is installable/updatable on a user's phone based solely on a successful build.
