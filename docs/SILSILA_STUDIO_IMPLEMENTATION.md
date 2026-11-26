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
- Layout profiles are cached locally, queued while offline, and synchronized per company. Global color/density tokens are applied to ERP pages through the dashboard runtime; the shared `ErpScreenFrame` also applies title/tab/task/footer visibility and content-width settings.

## Known functional boundaries — do not treat these as complete

- Data bindings are read-only for preview and published display. They do not execute create/update/delete operations against ERP business tables.
- Button actions in preview are simulations. There is no general-purpose action/workflow binding engine for arbitrary ERP commands.
- The published-design viewer displays published custom designs, but publishing does not replace the internals of an existing dedicated ERP screen or automatically remap all existing controls.
- Width/height are adjusted through property controls, not freehand drag-resize handles. Grouping currently records group membership metadata; nested visual group containers and a full hierarchical layer tree are not implemented.
- Report, chart, grid, tree, form, and icon components are foundational configurable components, not a full BI/reporting suite or a custom vector/icon drawing tool.
- Image components accept HTTPS image sources; a dedicated upload/crop/asset-library workflow is not implemented.
- Per-screen visibility and content-width controls are fully honored by screens using the shared frame. Global theme and data-density tokens apply through the ERP dashboard runtime; dedicated screens may still need conversion to the shared frame for every layout-position option to control their internal title bars, tabs, and toolbars.
- Local drafts use platform secure storage where available, with a SharedPreferences fallback. Layout profiles remain local preferences plus company-scoped cloud copies. Offline synchronization is manual/retryable and revision-conflict aware; background automatic synchronization is not implemented.
- A live authenticated owner/admin end-to-end workflow test is still required for central save, restore, approval, and publish. UI and database paths exist, but no claim of full production certification is made until CI and account-level testing pass.

## Security boundaries

- Imported JSON is presentation data only. No imported Dart, JavaScript, SQL, arbitrary callback, or executable expression is accepted.
- Database-side validation independently enforces the supported node types and the source/field allow-list.
- Data-source table names and column names come from a fixed registry; callers cannot supply arbitrary identifiers.
- Company isolation and write permissions are enforced by RLS and owner/admin role policies. Anonymous access is revoked.
- Published custom designs render read-only in the published-design viewer. Business mutations must continue through the ERP's existing validated business workflows.


## React migration checkpoint — 2026-11-26

The parallel React branch now includes an initial functional Studio workspace and a separate published-design viewer:

- react-preview/src/StudioWorkspace.tsx lists company-scoped designs and opens versioned design documents.
- Draft save uses the existing erp_studio_save_draft RPC with optimistic revision checking; approval, publish, and restore use the existing Studio RPCs.
- Revision history reads erp_studio_design_versions; published designs are exposed through a separate read-only screen.
- The React document validator rejects unsupported schema versions, unknown component types, duplicate/oversized IDs, invalid parent containers, cyclic nesting, invalid design kinds, and data sources outside the fixed allow-list.
- Preview bindings are read-only, company-scoped, limited to 50 rows per source, and exclude demo rows for sources that expose is_demo_data.
- Preview button actions are simulations only. Published components are read-only.

**Parity is not complete.** The current React editor is a foundation, not a full port of the Flutter Studio. It does not yet include the complete 10-tab editor experience, multi-select/drag-resize, undo/redo, visual grouping and layer tree, offline encrypted draft cache, full component renderer parity, asset upload/crop, or automatic published-design integration into existing ERP screens. Existing Flutter Studio remains the full-featured editor until these gaps are implemented and verified. Do not delete or disable Flutter Studio based on this checkpoint.

Validation: React Preview Validation builds the Vite app and runs Playwright browser smoke tests. This is not yet an authenticated owner/admin end-to-end test of save/restore/approve/publish against production data.
