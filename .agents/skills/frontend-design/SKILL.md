---
name: frontend-design
description: Create or refine distinctive, high-quality Silsila user interfaces without generic dashboard styling. Use when designing new UI or materially improving an existing screen.
---

# Frontend Design for Silsila

Use this skill together with `silsila-design`. The Silsila project identity and its approved specifications always take precedence over generic aesthetic suggestions.

## Design approach

- Design for the actual workflow and user role, not for a screenshot alone.
- Start by identifying the screen's primary task, most important data, user decisions, and error-prone interactions.
- Use hierarchy, alignment, typography, spacing, and restrained color to make dense business information easy to scan.
- Choose a clear visual focal point; do not decorate every card, field, or section.
- Use real domain labels and realistic content from the existing product. Avoid generic placeholder copy in finished screens.
- Prefer reusable Flutter components and theme tokens over one-off styling.

## Visual quality bar

- Preserve Silsila purple/orange/pink/white identity and Tajawal typography.
- Use consistent field, row, button, icon, border, and radius treatments.
- Give tables and trees clear column alignment and predictable density.
- Keep actions visually distinguishable by importance and state.
- Provide empty, loading, error, disabled, selected, focused, and success states where relevant.
- Make validation errors specific and place them next to the affected control.
- Avoid generic SaaS card mosaics, excessive shadows, unnecessary gradients, decorative labels, and animation on every element.

## Before implementation

Produce a compact design note in the task plan:
- user and primary job;
- information hierarchy;
- layout and responsive behavior;
- component reuse;
- important states;
- acceptance checks.

For a clear, explicitly scoped user request, do not delay implementation with redundant approval questions. If a missing decision would materially change the result, ask one focused question.

## After implementation

Review the actual rendered UI when tooling is available. Compare against the project's design blueprint and responsive standard. Fix alignment, overflow, Arabic wrapping, visual inconsistency, and interaction issues before completion.
