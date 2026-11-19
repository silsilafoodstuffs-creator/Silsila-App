# Silsila Studio — Visual Style Library

## Purpose

Refresh the Silsila Studio shell with a responsive Glossy Neon Luxury presentation, and extend the ERP screen-layout Studio so saved per-screen profiles control real ERP widgets through the shared dashboard runtime and `ErpScreenFrame`, rather than changing preview-only JSON.

## Presets and component styles

- Theme presets: Glossy Neon Luxury, Neon Purple, Glass Orange, Platinum, Royal Violet, Classic.
- Header styles: Glossy, Glass, Neon, Minimal.
- Button styles: Glossy, Glass, Neon, Pill, Outline.
- Table styles: Glass, Neon, Minimal, Outlined.
- Tree/list styles: Neon, Nested Cards, Compact, Outlined.
- Existing controls remain available for target screen, title/tabs/tasks/date/image placement, visibility, view mode, grid density, row height, spacing, content width, corner radius, and primary/accent colors.

## Runtime application

Saved profiles are applied through `ErpScreenLayoutRuntime` to the ERP subtree:
- Elevated, filled, outlined and text buttons receive the selected shape, fill, elevation and foreground.
- DataTable receives selected row sizing, header typography, spacing, border, surface and neon/glass decoration.
- ExpansionTile and ListTile receive the selected tree/list density, indentation and shape.
- Cards and input decorations receive the selected surface, border, radius and color tokens.
- App bars receive the selected light/dark header color treatment.
- Screens using `ErpScreenFrame` additionally receive the configurable glossy/glass/neon/minimal header, tab treatment, live tab placement (top/left/right/bottom/hidden), live taskbar placement (top/below-title/bottom/hidden), and per-screen frame visibility/content-width controls. The active dashboard screen profile is passed through an inherited scope so nested frames use the selected menu screen's profile even when their internal title differs.

## Safety and compatibility

- Existing profile JSON remains backward-compatible: missing new keys use Glossy Neon Luxury defaults.
- Existing screen actions and callbacks are not replaced; only inherited visual themes and frame composition are changed.
- The Studio profile is saved with the existing local/company-scoped profile persistence flow and existing permission checks.
- Business data, transactions, database schema, RLS and Supabase production configuration are not changed by this visual work.

## Known boundaries — not a 100% acceptance claim

- A custom widget that hardcodes its own colors, decoration or button style can override inherited theme tokens.
- Generic saved metadata such as view mode (table/grid/tree/split), date/image/scroll placement and sidebar visibility cannot safely rearrange arbitrary screen-specific widget trees. Those settings require explicit adapters in each target screen; the Studio UI now explains this boundary rather than implying a universal automatic transformation.
- Alternating striped rows are not offered as a generic DataTable preset because Flutter's inherited DataTable theme cannot reliably alternate arbitrary row colors without a row-aware adapter.
- Header/task/date/image placement is effective only where the screen exposes those regions through `ErpScreenFrame`; the frame does not discover arbitrary private widget trees.
- The tree presets style standard ExpansionTile/ListTile controls. Bespoke tree renderers require an explicit adapter.
- A complete acceptance pass still needs the full validation workflow and visual review of representative desktop/mobile screens, including screens with custom widgets.
