---
name: silsila-design
description: Mandatory Silsila product identity, ERP screen, Arabic RTL, responsive layout, and design-system rules. Use for any Silsila UI design, redesign, styling, or visual bug fix.
---

# Silsila Design System

## Design intent

Build a premium, modern, polished enterprise ERP experience for the Egyptian wholesale-trading market. The interface should feel deliberate, fast, compact, consistent, and trustworthy—not like a generic admin template.

## Brand identity

- Official product name: **سلسلة / Silsila**.
- Slogan: **سلسلة .. بنربط السوق ببعضه**.
- Welcome phrase: **تجارتك اليومية تبدأ من هنا**.
- Core palette:
  - Purple: `#3E007D`
  - Orange: `#FFA015`
  - Pink: `#FF27C3`
  - White: `#FFFFFF`
  - Supporting surfaces may use `#FAF8FC`, `#F5EFFB`, and `#241735`.
- Primary Arabic font: Tajawal. Kufam and Romman are available for deliberate supporting use.
- Respect the existing logo and assets. Do not recreate, distort, crop, or replace the logo without an explicit request.
- Keep Arabic brand lettering connected and readable on mobile; never allow vertical one-character wrapping.

## Product language

- Use the exact official spelling **سلسلة**.
- For the relevant user-type cards/buttons use: **عميل، مورد، مستهلك، شركة شحن**.
- Do not use **جملة** or **قطاعي** as substitutes for those approved labels.
- Do not include the personal name **عبد العاطي الفرشوطي** in designs unless explicitly requested.
- Use the project's approved business terminology, including **فئات الأصناف** rather than **مجموعات الأصناف**.

## Layout and density

- Follow `docs/RESPONSIVE_UI_STANDARD.md` as a binding acceptance standard.
- Follow the current project-wide UI measurements and any newer explicit project decision. Current baseline: field/row height 40 px and spacing 5 px, except screens with a more specific approved compact standard.
- Keep labels beside their fields where the screen specification requires it; do not move labels above fields as a generic redesign.
- Dropdown option rows should retain the approved 40 px baseline unless a screen-specific decision supersedes it.
- Avoid oversized headers, excessive whitespace, decorative gradients, and oversized cards in dense ERP workflows.
- Keep table headers and data cells on identical column geometry. Do not repeat column headings inside every tree row.
- Use compact, consistent controls and preserve the existing nine quick-task actions and their fixed semantics where applicable.
- Never add horizontal scrolling between table rows. For genuinely wide grids, use a coherent table-level horizontal scroll region or a responsive alternative without splitting the row structure.

## Responsive and accessibility rules

- Support small phones, standard phones, tablets, laptops, wide desktops, portrait, landscape, short-height windows, and browser resizing.
- Support Arabic RTL and English LTR, including input direction, alignment, navigation, and mixed numerals.
- Use constraints and available viewport dimensions rather than device-name assumptions.
- Avoid overflow, clipped actions, unreadable squeezed columns, and one-character-per-line wrapping.
- Keep keyboard focus visible, tap targets practical, and text readable at increased scaling.
- Respect reduced-motion preferences and avoid decorative motion that slows ERP work.

## Required design workflow

1. Inspect the existing screen and related shared components before changing anything.
2. Read the applicable screen specification and current design standards.
3. Describe the intended change briefly and keep it scoped to the user's request.
4. Reuse established components, spacing, typography, and colors.
5. Compare the result at narrow, medium, and wide widths; include RTL/LTR where applicable.
6. Check neighboring screens that share the modified component.
7. Do not redesign unrelated screens or alter business behavior as a visual side effect.

## Non-goals

This skill does not authorize changing database schemas, permissions, routes, calculations, or workflows. Those require their own relevant skill and explicit task scope.
