# Silsila AI Agent Skills

Project-scoped Agent Skills live under `.agents/skills/`. They are instruction files loaded by compatible AI coding agents, not app code; they add no Flutter runtime dependency and do not execute automatically.

## Skill catalogue

| Skill | Purpose |
|---|---|
| `silsila-design` | Brand, ERP visual consistency, Arabic RTL, density, responsive rules |
| `frontend-design` | Workflow-first interface design and visual critique |
| `flutter-engineering` | Flutter widgets, state, layout, architecture, and implementation |
| `dart-best-practices` | Dart typing, null safety, async lifecycle, and maintainability |
| `flutter-performance` | Evidence-based rendering, scrolling, memory, and data performance |
| `supabase-postgres-best-practices` | PostgreSQL/Supabase implementation, RLS, Storage, and safe migrations |
| `database-architecture` | Relational modeling, data lifecycle, keys, constraints, and migration design |
| `database-security` | RLS, grants, tenant isolation, Auth, RPC, Storage, and secrets |
| `webapp-testing` | Flutter Web, UI, responsive, and WebView test strategy |
| `playwright-testing` | Safe use of the existing Playwright/Chromium browser harness |
| `regression-testing` | Risk-based test selection and regression coverage |
| `code-review` | Diff review for correctness, data safety, security, and scope |
| `architecture-improvement` | Incremental architecture improvements without broad rewrites |
| `superpowers-workflow` | Proportionate planning, debugging, and incremental delivery |
| `verification-before-completion` | Evidence-based validation and honest reporting |

## How to use

- Read only the skill(s) relevant to the current task; avoid loading all files for every request.
- Combine skills where needed (for example, database architecture + database security + Supabase practices for an RLS/schema task).
- The Silsila-specific specifications and user-approved decisions take precedence over generic advice.
- Existing CI/browser scripts remain the source of truth. Playwright guidance explicitly requires reusing the current harness and does not add a second browser stack.
- No React/Vercel runtime skill is installed because this application is Flutter/Dart. General interface principles are covered by the framework-neutral frontend design guidance.

## Cost, licensing, and compatibility

- The Silsila-authored skill files are plain Markdown stored in this repository; they require no paid license, subscription, package installation, or runtime service.
- AI model usage may still be billable under the user's chosen AI service/plan. GitHub Actions minutes and browser execution are separate from merely storing these files.
- Compatible agents must support or be configured to read the Agent Skills convention and repository `AGENTS.md`; unsupported agents may ignore them.
- These files are original Silsila-specific guidance, not copied third-party skill implementations. Upstream projects are references for concepts only; review each upstream license before copying any content in the future.

## Safety and non-goals

- No Flutter app source, `pubspec.yaml`, lockfile, Supabase schema/data, secrets, migrations, or GitHub Actions workflows are changed by this skill catalogue.
- Skills do not authorize destructive SQL, production data edits, permission changes, dependency upgrades, workflow changes, or deployment.
- Avoid contradictory instructions: Silsila design specifications govern UI; the database security rules govern authorization; verification rules govern completion claims.
- Update this catalogue when the actual repository test harness or approved product standards change.

## Reference projects

- [Agent Skills specification](https://agentskills.io/)
- [Anthropic Skills](https://github.com/anthropics/skills)
- [Superpowers](https://github.com/obra/superpowers)
- [Supabase Agent Skills](https://github.com/supabase/agent-skills)
- [Flutter Agent Plugins](https://github.com/flutter/agent-plugins)
- [Vercel Agent Skills](https://github.com/vercel-labs/agent-skills) — considered, but React-specific runtime guidance is not installed for this Flutter app
