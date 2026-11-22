---
name: dart-best-practices
description: Focused Dart language, API, typing, async, and maintainability standards for Silsila. Use when editing Dart source or tests.
---

# Dart Best Practices for Silsila

- Follow the Dart SDK version pinned by the repository; do not use newer language features without checking compatibility.
- Prefer sound null safety, explicit domain types, small functions, and immutable values where practical.
- Avoid `dynamic`, force unwraps, unsafe casts, ignored futures, and broad catch-and-ignore blocks.
- Use `Future` and `async/await` consistently; handle errors at a layer that can add context or recover.
- Do not start unawaited asynchronous work unless its lifecycle and errors are deliberately handled.
- Use `StreamSubscription.cancel()`, `Timer.cancel()`, and dispose/close owned resources.
- Keep parsing and validation at boundaries. Do not let untrusted JSON become unchecked domain state.
- Prefer exhaustive switches and sealed/enum-based state where compatible with current SDK.
- Keep public APIs stable; inspect call sites before changing signatures.
- Use lints already enabled by the repository. Do not introduce a new lint package or mass-format unrelated files.
- Add focused tests for edge cases, null/empty values, errors, and numeric precision when relevant.
- Run targeted tests and `flutter analyze lib test --no-fatal-infos --no-fatal-warnings` as applicable.
