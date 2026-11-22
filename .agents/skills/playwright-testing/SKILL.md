---
name: playwright-testing
description: Use Playwright safely for existing Silsila browser/WebView automation; do not add a second browser stack unnecessarily.
---

# Playwright Testing for Silsila

- First inspect the existing browser harness, scripts, package manifests, and CI workflow. The current repository already has a Chromium WebView test path; reuse it.
- Do not install Playwright or browser binaries again if the repository/CI already provides them.
- Keep Playwright as a test-only tool. Never add it to Flutter runtime dependencies or ship browser automation code in the app.
- Test the built Flutter Web output at the production base path `/Silsila-App/`, not only the development server.
- Wait for Flutter bootstrap and app readiness before assertions; avoid fixed sleeps when a stable readiness signal exists.
- Prefer accessible roles, labels, text, and stable test keys over brittle CSS or positional selectors.
- Cover desktop and mobile viewport behavior, RTL/LTR, navigation, key forms, console errors, failed requests, and overflow where relevant.
- Capture traces/screenshots on failure when the existing harness supports them.
- Use isolated test accounts/data. Never submit real orders, payments, messages, or irreversible production actions.
- Report browser, viewport, command, and exact result. A skipped or unavailable browser run is not a pass.
