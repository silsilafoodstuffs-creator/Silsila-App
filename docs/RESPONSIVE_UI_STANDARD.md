# Silsila Responsive UI Standard

This is a permanent acceptance requirement for every new screen, redesign, and bug fix in Silsila. No change is complete merely because it looks correct on one device.

## Required device coverage

- Mobile web and native mobile, portrait and landscape.
- Small phones (320–360 logical px), standard phones (375–430 px), tablets (600–900 px), laptops, and wide desktop screens.
- Arabic RTL and English LTR.
- Browser zoom and increased system text scaling where supported.

## Layout rules

- Prefer constraints and available viewport dimensions (LayoutBuilder, MediaQuery) over device-name or diagonal-size assumptions. A 17-inch near-square display, a widescreen all-in-one, a tablet in either orientation, and a browser resized to a narrow window must all adapt from their actual available width and height.
- Treat width and height as independent constraints; never assume a 17-inch screen is widescreen or that desktop always has enough vertical space.
- Use SafeArea for content near system/browser insets.
- Use Expanded, Flexible, Wrap, and scroll views where appropriate; prevent narrow columns from forcing text to wrap one character per line.
- Use a sensible maxWidth for forms and reading content, but let them shrink to available width with horizontal padding.
- Tables and dense ERP grids must remain usable through responsive columns, card/list alternatives, or intentional horizontal scrolling. Do not squeeze every column into an unreadable sliver.
- Table headings and their cells must share the same column geometry. Keep headings vertically centered, allow sensible two-line wrapping only when the column can support it, and never force Arabic words into one-character-per-line wrapping.
- On narrow viewports, relocate side rails into full-width tool panels instead of reserving a narrow fixed rail beside the data area. Never hide controls or data merely because a saved layout profile places them on a side.
- Use available content width on compact and medium screens; apply optional desktop content-width profiles only when the viewport is genuinely wide. Preserve a usable vertical scroll path for short-height and landscape viewports.
- Buttons and fields must fit the available width, retain readable labels, and have practical touch targets.
- Keep Arabic/English direction, alignment, and text entry correct; do not hard-code left/right when directional alignment is appropriate.
- Images, dialogs, navigation, menus, and overlays must respect viewport constraints and safe areas.
- Never fix overflow by globally shrinking text until it is unreadable.

## Minimum validation before declaring a UI task complete

- Run Dart formatting, flutter analyze, relevant tests, and a Flutter web release build.
- Inspect automated CI results and the deployed web entry point when deployment is part of the change.
- Review layouts at widths 320, 360, 390, 600, 768, 1024, 1180, 1366, and 1600 logical pixels, including portrait tablet, landscape phone, short-height browser windows, near-square desktop viewports, and widescreen desktop viewports.
- Check that no text is split vertically one character per line, no controls overlap, no content is clipped without a usable scroll path, and no horizontal overflow occurs unintentionally.
- Re-test both RTL and LTR after shared layout or typography changes.

This standard applies to the ERP, customer app, login/registration flows, dialogs, tables, dashboards, and every future screen.
