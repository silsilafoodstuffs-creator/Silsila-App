# Silsila AI Agent Skills

This repository includes project-scoped Agent Skills under `.agents/skills/`. They are guidance loaded by compatible AI coding agents; they do not run inside the Silsila app and do not add Flutter runtime dependencies.

## Installed project skills

| Skill | Purpose |
|---|---|
| `silsila-design` | Brand identity, ERP visual consistency, Arabic RTL, density, and responsive acceptance rules |
| `frontend-design` | Distinctive, workflow-first UI design and critique |
| `flutter-engineering` | Flutter/Dart architecture, layout, state, performance, and testing |
| `supabase-postgres-best-practices` | PostgreSQL schema, Supabase security, RLS, Storage, and safe migrations |
| `webapp-testing` | Flutter Web, browser/WebView, widget, and responsive testing |
| `superpowers-workflow` | Task planning, incremental implementation, systematic debugging, and review |
| `verification-before-completion` | Evidence-based validation and honest completion reporting |

## Why these were selected

Silsila is Flutter/Dart with Supabase, so Flutter and Supabase practices are directly applicable. React-specific runtime optimization skills are intentionally not installed because the app is not built with React. The Vercel Web Interface Guidelines skill is not vendored because its source repository does not declare a repository license in its GitHub metadata; its general review ideas can be consulted upstream without copying its content.

The Anthropic Agent Skills repository is used as a reference for the general frontend-design and webapp-testing skill concepts, but its files are not copied into this repository because the checked source tree did not expose a clear top-level license file. The Silsila versions here are original, project-specific instructions.

## Upstream references

- [Agent Skills specification](https://agentskills.io/)
- [Anthropic Skills](https://github.com/anthropics/skills)
- [Superpowers](https://github.com/obra/superpowers) — MIT
- [Supabase Agent Skills](https://github.com/supabase/agent-skills) — MIT
- [Flutter Agent Plugins](https://github.com/flutter/agent-plugins) — BSD-3-Clause
- [Vercel Agent Skills](https://github.com/vercel-labs/agent-skills) — consulted as a reference; React-specific guidance is not applicable to this Flutter app

## Safety and scope

- Skills are instructions only; no application dependency or Supabase schema was changed to add them.
- No workflow, deployment, application, or production data changes are part of this skills package.
- Read `AGENTS.md` for routing and project-wide guardrails.
- Review and update these skills when the product specifications or CI acceptance checks change.
