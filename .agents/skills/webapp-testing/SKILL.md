---
name: webapp-testing
description: Validate Silsila Flutter Web, mobile browser/WebView behavior, responsive layouts, and user interactions with automated tests.
---

# Silsila Web and UI Testing

## Test the application that exists

- Silsila is a Flutter application compiled to web; do not assume it is a React/Next.js app.
- Inspect the existing test harness before adding tools. The repository already contains browser validation scripts and GitHub Actions workflows.
- Prefer the existing `tools/web_view_test.mjs` and CI browser workflow over introducing another Playwright setup.
- Do not add npm, Python, or Flutter dependencies unless needed and explicitly justified.

## Test layers

1. **Dart analysis:** catch type, API, and lint issues.
2. **Widget tests:** verify rendering, validation, state changes, callbacks, and RTL behavior.
3. **Flutter tests:** run the existing suite for regressions.
4. **Web release build:** verify the production base path `/Silsila-App/`.
5. **Browser/WebView tests:** use the repository's Chromium-based workflow to detect page errors, failed requests, stale assets, and desktop/mobile rendering problems.
6. **Android release validation:** use the existing signed-release workflow and verify the APK artifact; a debug APK is not a substitute for the requested release package.

## UI test cases

For a changed screen, cover as applicable:
- initial loading, populated, empty, error, and disabled states;
- primary and secondary actions;
- form input, validation, save/cancel, and navigation;
- long Arabic and English labels;
- RTL and LTR;
- narrow phone, standard phone, tablet, desktop, landscape, and short-height viewports;
- overflow, clipping, scrolling, table header/body alignment, and keyboard focus.

## Browser automation discipline

- Inspect the rendered page and available selectors before acting.
- Wait for the Flutter app to finish bootstrapping before asserting on UI.
- Capture screenshots and browser console/page errors when supported.
- Use stable accessible labels or keys rather than brittle positional selectors.
- Never claim a browser test passed if it was skipped, blocked, or not run.

## Avoid destructive testing

Use isolated fixtures or existing test data. Do not run UI tests that submit real orders, payments, customer messages, or irreversible operations against production data.
