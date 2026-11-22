---
name: superpowers-workflow
description: Structured planning, debugging, test-driven implementation, code review, and safe delivery inspired by the Superpowers workflow.
---

# Silsila Development Workflow

This is a Silsila-adapted workflow informed by the open-source Superpowers project. It is not a command to blindly follow upstream agent instructions; the user's explicit task and repository safety rules take precedence.

## 1. Understand the task

- Restate the requested outcome internally in concrete acceptance criteria.
- Inspect the current implementation, related specs, recent changes, and dependencies before proposing a solution.
- Reuse decisions already established in project documentation and conversation context.
- If the task is clearly specified, proceed without asking the user to repeat known details. Ask one focused question only when a missing decision would materially change the implementation.

## 2. Plan proportionately

For a small change, use a short checklist. For a broad or risky change, record:
- affected screens/modules/data paths;
- implementation sequence;
- backward compatibility concerns;
- tests and acceptance criteria;
- rollback or recovery approach.

Do not create a large planning document for a one-line change.

## 3. Implement incrementally

- Prefer a small, reviewable diff.
- Write or update a focused test before/alongside behavior changes where practical.
- Keep UI, business logic, persistence, and authorization responsibilities in their established layers.
- Avoid opportunistic refactors and unrelated formatting.
- Do not make unrelated dependency upgrades.

## 4. Debug systematically

1. Reproduce the failure and capture the exact error.
2. Identify the smallest failing layer.
3. Form one evidence-based hypothesis at a time.
4. Make the smallest change that tests the hypothesis.
5. Re-run the failing check and relevant regression tests.
6. If two or three attempts fail, stop repeating the same approach; inspect assumptions and choose a different diagnostic path.

## 5. Review before delivery

- Inspect the complete diff, not just the final edited lines.
- Check for accidental changes to business rules, database access, permissions, routes, localization, and responsive behavior.
- Check that tests actually exercise the changed behavior.
- Report remaining limitations honestly.

Reference: https://github.com/obra/superpowers
