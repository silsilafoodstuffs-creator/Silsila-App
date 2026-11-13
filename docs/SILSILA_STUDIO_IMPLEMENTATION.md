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
- Screen editor: add/select/multi-select, drag reorder, property editing, width/height resizing controls, duplicate, delete, group/ungroup metadata, hide/show, lock/unlock, layer ordering, undo/redo, local draft save/open, and JSON clipboard import/export.
- Report, icon/element, and table/Grid tabs use the same schema-driven editor with focused component libraries and document kinds.
- Preview supports editable form controls and simulated button actions. Simulated actions never execute ERP business transactions.
- Safe read-only data binding for explicitly allow-listed company-scoped sources: items, brands, item categories, warehouses, sales documents, purchase documents, and stock balances. The app filters demo documents where the source exposes an `is_demo_data` flag and applies the active company ID plus Supabase RLS.
- Repository workflows: list/open designs, read revision history, save drafts, restore prior revisions, approve, publish, and read bound data for preview.
- Company-scoped Supabase persistence for design documents, immutable revisions, audit events, and layout profiles. RLS is enabled on all four tables.
- Studio mutation RPCs use `SECURITY INVOKER`; Supabase Security Advisor reports no Studio-specific security findings.
- Postgres validation triggers enforce supported schema versions, node limits, unique IDs, allow-listed component types, and allowed data-source fields for designs and revisions.
- Offline draft cache tracks pending changes and provides batch, optimistic-revision synchronization to Supabase.
- Layout profiles are cached locally, queued while offline, and synchronized per company. Global color/density tokens are applied to ERP pages through the dashboard runtime; the shared `ErpScreenFrame` also applies title/tab/task/footer visibility and content-width settings.

## Known functional boundaries — do not treat these as complete

- Data bindings are read-only for preview and published display. They do not execute create/update/delete operations against ERP business tables.
- Button actions in preview are simulations. There is no general-purpose action/workflow binding engine for arbitrary ERP commands.
- The published-design viewer displays published custom designs, but publishing does not replace the internals of an existing dedicated ERP screen or automatically remap all existing controls.
- Width/height are adjusted through property controls, not freehand drag-resize handles. Grouping currently records group membership metadata; nested visual group containers and a full hierarchical layer tree are not implemented.
- Report, chart, grid, tree, form, and icon components are foundational configurable components, not a full BI/reporting suite or a custom vector/icon drawing tool.
- Image components accept HTTPS image sources; a dedicated upload/crop/asset-library workflow is not implemented.
- Per-screen visibility and content-width controls are fully honored by screens using the shared frame. Global theme and data-density tokens apply through the ERP dashboard runtime; dedicated screens may still need conversion to the shared frame for every layout-position option to control their internal title bars, tabs, and toolbars.
- Local drafts and layout profiles use SharedPreferences. Offline synchronization is manual/retryable and revision-conflict aware; encrypted local storage and background automatic synchronization are not implemented.
- A live authenticated owner/admin end-to-end workflow test is still required for central save, restore, approval, and publish. UI and database paths exist, but no claim of full production certification is made until CI and account-level testing pass.

## Security boundaries

- Imported JSON is presentation data only. No imported Dart, JavaScript, SQL, arbitrary callback, or executable expression is accepted.
- Database-side validation independently enforces the supported node types and the source/field allow-list.
- Data-source table names and column names come from a fixed registry; callers cannot supply arbitrary identifiers.
- Company isolation and write permissions are enforced by RLS and owner/admin role policies. Anonymous access is revoked.
- Published custom designs render read-only in the published-design viewer. Business mutations must continue through the ERP's existing validated business workflows.
