---
name: flutter-engineering
description: Flutter and Dart engineering standards for the Silsila ERP application. Use for Dart code, widget composition, architecture, state, routing, performance, localization, and layout fixes.
---

# Flutter Engineering for Silsila

## Project facts

- The application is Flutter/Dart, not React.
- Respect the Dart SDK and Flutter versions pinned by the repository and CI. Do not upgrade the toolchain or dependencies as an incidental change.
- Keep the existing application architecture and package choices unless the task requires a justified improvement.
- Keep business logic out of presentation widgets where the existing architecture provides services/controllers/repositories.

## Implementation rules

1. Inspect neighboring files and existing patterns before introducing a new abstraction.
2. Prefer small, focused, testable changes over broad refactors.
3. Use null safety and sound typing. Avoid `dynamic`, unsafe casts, and broad exception swallowing.
4. Dispose controllers, focus nodes, animation controllers, streams, and subscriptions correctly.
5. Use stable keys for widgets that need deterministic testing.
6. Avoid expensive work in `build()`; cache or move computations to the appropriate layer.
7. Use `const` where it is correct and useful; do not apply mechanical edits that obscure intent.
8. Keep dependencies pinned through the existing lockfile. Do not add a package merely to solve a problem already covered by Flutter/Dart.
9. Preserve existing public APIs and screen routes unless explicitly requested.
10. For shared components, inspect all call sites and test affected screens.

## Responsive Flutter layout

- Use `LayoutBuilder`, `MediaQuery`, constraints, `SafeArea`, `Expanded`, `Flexible`, `Wrap`, and scrollables according to actual constraints.
- Treat width and height independently.
- Avoid fixed widths that exceed available space and avoid shrinking text to conceal overflow.
- Keep data tables readable. If a grid is wider than the viewport, use a coherent table-level scroll region or a suitable responsive presentation.
- Ensure Arabic RTL and English LTR layout and text entry remain correct.
- Never create a horizontal scroll view between rows or split header and body into mismatched scrolling regions.

## Testing and analysis

- Add or update focused widget tests for changed UI behavior.
- Use integration tests only for genuine end-to-end user flows and avoid adding new test frameworks without need.
- Run the narrowest relevant tests first, then the repository's full validation commands when feasible:
  - `flutter analyze lib test --no-fatal-infos --no-fatal-warnings`
  - `flutter test`
  - `flutter build web --release --base-href "/Silsila-App/"`
  - `flutter build apk --release` (CI uses the repository's signed-release preparation script).
- Do not apply `dart fix --apply` or bulk formatting across unrelated files without reviewing the diff.
