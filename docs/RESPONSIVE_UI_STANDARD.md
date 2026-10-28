# Silsila Responsive UI Standard

This is a permanent acceptance requirement for every new screen, redesign, and bug fix in Silsila. No change is complete merely because it looks correct on one device.

## Required device coverage

- Mobile web and native mobile, portrait and landscape.
- Small phones (320–360 logical px), standard phones (375–430 px), tablets (600–900 px), laptops, and wide desktop screens.
- Arabic RTL and English LTR.
- Browser zoom and increased system text scaling where supported.

## Layout rules

- Prefer constraints and breakpoints (LayoutBuilder, MediaQuery) over fixed screen-sized widths.
- Use SafeArea for content near system/browser insets.
- Use Expanded, Flexible, Wrap, and scroll views where appropriate; prevent narrow columns from forcing text to wrap one character per line.
- Use a sensible maxWidth for forms and reading content, but let them shrink to available width with horizontal padding.
- Tables and dense ERP grids must remain usable on phones through responsive columns, card/list alternatives, or intentional horizontal scrolling. Do not squeeze every column into an unreadable sliver.
- Buttons and fields must fit the available width, retain readable labels, and have practical touch targets.
- Keep Arabic/English direction, alignment, and text entry correct; do not hard-code left/right when directional alignment is appropriate.
- Images, dialogs, navigation, menus, and overlays must respect viewport constraints and safe areas.
- Never fix overflow by globally shrinking text until it is unreadable.

## Minimum validation before declaring a UI task complete

- Run Dart formatting, flutter analyze, relevant tests, and a Flutter web release build.
- Inspect automated CI results and the deployed web entry point when deployment is part of the change.
- Review layouts at widths 320, 360, 390, 600, 768, 1024, and 1366 logical pixels, plus landscape on mobile.
- Check that no text is split vertically one character per line, no controls overlap, no content is clipped without a usable scroll path, and no horizontal overflow occurs unintentionally.
- Re-test both RTL and LTR after shared layout or typography changes.

This standard applies to the ERP, customer app, login/registration flows, dialogs, tables, dashboards, and every future screen.
