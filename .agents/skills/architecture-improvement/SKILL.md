---
name: architecture-improvement
description: Improve Silsila application architecture incrementally while preserving existing behavior, compatibility, and delivery stability.
---

# Architecture Improvement for Silsila

- Understand the current architecture, module boundaries, dependency direction, and existing conventions before proposing a refactor.
- Prefer incremental improvements that solve a demonstrated problem over broad rewrites or pattern adoption for its own sake.
- Keep presentation, business rules, persistence, and authorization responsibilities in their established layers.
- Avoid circular dependencies, oversized widgets/services, duplicate sources of truth, and hidden global mutable state.
- Introduce abstractions only when they reduce real coupling or duplication and have clear ownership.
- Preserve routes, public APIs, persisted formats, business calculations, and integration contracts unless explicitly requested.
- For migrations, use a staged compatibility plan: support old and new paths during transition, backfill safely, verify, then remove obsolete paths only with approval.
- Define measurable acceptance criteria and tests before a structural change.
- Refactor one coherent boundary at a time; keep each commit reviewable and reversible.
- Do not add a framework, state-management package, code generator, or dependency solely to make architecture look more modern.
- Obtain explicit approval before destructive schema changes, data rewrites, or production behavior changes.
