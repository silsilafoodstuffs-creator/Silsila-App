---
name: code-review
description: Review Silsila changes for correctness, regressions, security, data integrity, maintainability, and scope before delivery.
---

# Code Review for Silsila

Review in priority order:

1. **Correctness:** Does the change meet the user's acceptance criteria and preserve edge cases?
2. **Data integrity:** Could it lose, duplicate, detach, or silently rewrite business records, category links, generated codes, or history?
3. **Authorization:** Can another company, branch, role, or unauthenticated user read or mutate protected data?
4. **Regression:** Are shared components, routes, reports, imports, exports, and platform variants affected?
5. **UI quality:** Are RTL/LTR, responsive constraints, table geometry, keyboard access, and empty/error/loading states correct?
6. **Reliability:** Are async lifecycles, disposal, retries, and error messages safe?
7. **Scope:** Are unrelated files, dependencies, workflows, secrets, generated files, or formatting changes included?

- Inspect the full diff and relevant call sites, not just the patch summary.
- Report findings with severity and exact file/line references when available.
- Separate confirmed defects from questions and style preferences.
- Do not approve a change with an unresolved data-loss, tenant-isolation, secret-exposure, or destructive-migration risk.
- Do not make code changes during a review unless implementation was requested; otherwise report actionable findings.
