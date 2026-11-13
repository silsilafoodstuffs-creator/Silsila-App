# Silsila Studio — implementation and verification status

Silsila Studio is the single integrated design workspace in ERP navigation under **إعدادات عامة → سلسلة ستوديو**. The former standalone screen-layout editor is embedded as tab 7. A separate **شاشات الاستوديو المنشورة** destination provides a read-only viewer for published designs.

## Integrated workspace tabs

1. لوحة الاستوديو
2. مصمم الشاشات
3. مصمم التقارير
4. مصمم الأيقونات والعناصر
5. مصمم الجداول وGrid
6. مصادر البيانات والربط
7. تخطيط وتنسيق الشاشات
8. المعاينة والاختبار
9. الإصدارات والاستعادة
10. الاعتماد والنشر

## Implemented

- Versioned data-only design schema v2 with backwards reading of v1 documents, component allow-list, duplicate-ID rejection, bounded node/property counts, and JSON-only property validation.
- Flutter component registry and renderer for text, buttons, fields, cards, dividers, spacing, grids, trees, tables, icons, images (HTTPS only), charts, tabs, forms, lists, badges, progress indicators, stat cards, containers, and filters.
- Screen editor: add/select/multi-select, drag reorder with an explicit layer handle, direct drag-resize handles plus numeric width/height controls, duplicate, delete, group/ungroup with visual group containers, hide/show, lock/unlock, layer ordering, undo/redo, encrypted local draft save/open with a fallback cache, and JSON clipboard import/export.
- Report, icon/element, and table/Grid tabs use the same schema-driven editor with focused component libraries and document kinds.
- Preview supports editable form controls and simulated button actions. Simulated actions never execute ERP business transactions.
- Safe read-only data binding for explicitly allow-listed company-scoped sources: items, brands, item categories, warehouses, sales documents, purchase documents, and stock balances. The app filters demo documents where the source exposes an `is_demo_data` flag and applies the active company ID plus Supabase RLS.
- Repository workflows: list/open designs, read revision history, save drafts, restore prior revisions, approve, publish, and read bound data for preview.
- Company-scoped Supabase persistence for design documents, immutable revisions, audit events, and layout profiles. RLS is enabled on all four tables.
- Studio mutation RPCs use `SECURITY INVOKER`; Supabase Security Advisor reports no Studio-specific security findings.
- Postgres validation triggers enforce supported schema versions, node limits, unique IDs, allow-listed component types, and allowed data-source fields for designs and revisions.
- Offline draft cache tracks pending changes and provides batch, optimistic-revision synchronization to Supabase.
- Layout profiles are cached locally, queued while offline, and synchronized per company. Global color/density tokens, main navigation visibility, and configurable scrollbar side/visibility are applied through the dashboard runtime. The shared outer `ErpScreenFrame` applies configurable group-tab placement across all ERP routes without duplicating dedicated screen titles. Workspace pages also pass individual task buttons into the frame, so task placement controls affect the real buttons there. The frame exposes optional date/image/sidebar slots and content-width control. The layout editor receives its target list from the complete ERP navigation tree rather than a short hard-coded list. Generic workspace data renders as table, tree, grid cards, or split list/details.



## Current layout integration work — PR 28

- Branch: `feature/silsila-studio-layout-controls`.
- Pull request: https://github.com/silsilafoodstuffs-creator/Silsila-App/pull/28 (open draft; do not merge before validation).
- Current work adds the full ERP menu catalog to the screen selector, live tab/task positioning (including vertical RTL side rails), actual workspace table/tree/grid/split modes, global group-tab placement, main sidebar visibility, and configurable dashboard scrollbar orientation/visibility.
- Widget tests cover frame positioning, RTL side placement, optional date/image/sidebar slots, Studio preview controls, and selecting a screen from the supplied ERP route catalog.
- GitHub Actions results for the current head have not yet been confirmed; no CI pass is claimed.

## Known functional boundaries — do not treat these as complete

- Data bindings are read-only for preview and published display. They do not execute create/update/delete operations against ERP business tables.
- Button actions in preview are simulations. There is no general-purpose action/workflow binding engine for arbitrary ERP commands.
- The published-design viewer displays published custom designs, but publishing does not replace the internals of an existing dedicated ERP screen or automatically remap all existing controls.
- Width/height are adjusted through property controls, not freehand drag-resize handles. Grouping currently records group membership metadata; nested visual group containers and a full hierarchical layer tree are not implemented.
- Report, chart, grid, tree, form, and icon components are foundational configurable components, not a full BI/reporting suite or a custom vector/icon drawing tool.
- Image components accept HTTPS image sources; a dedicated upload/crop/asset-library workflow is not implemented.
- Group-tab placement is applied globally by the shared outer frame. Per-screen content width, title/footer visibility, task placement, and generic data-view modes are honored by the shared-frame workspace. Main navigation visibility and scrollbar settings apply at the dashboard runtime. Dedicated screens that build their own taskbars, date filters, or image panels still need explicit adapters before those individual elements can be repositioned; the frame's date/image slots are available but do not automatically discover widgets inside arbitrary screens.
- Local drafts use platform secure storage where available, with a SharedPreferences fallback. Layout profiles remain local preferences plus company-scoped cloud copies. Offline synchronization is manual/retryable and revision-conflict aware; background automatic synchronization is not implemented.
- A live authenticated owner/admin end-to-end workflow test is still required for central save, restore, approval, and publish. UI and database paths exist, but no claim of full production certification is made until CI and account-level testing pass.

## Security boundaries

- Imported JSON is presentation data only. No imported Dart, JavaScript, SQL, arbitrary callback, or executable expression is accepted.
- Database-side validation independently enforces the supported node types and the source/field allow-list.
- Data-source table names and column names come from a fixed registry; callers cannot supply arbitrary identifiers.
- Company isolation and write permissions are enforced by RLS and owner/admin role policies. Anonymous access is revoked.
- Published custom designs render read-only in the published-design viewer. Business mutations must continue through the ERP's existing validated business workflows.
