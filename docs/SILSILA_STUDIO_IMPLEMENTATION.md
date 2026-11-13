# Silsila Studio — implementation status

Silsila Studio is the single integrated design workspace in the ERP navigation under **إعدادات عامة → سلسلة ستوديو**. The previous standalone screen-layout entry is not exposed as a separate destination.

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

The former screen-layout editor is embedded in tab 7 and retains its local layout-profile controls. Its profiles are still local preferences and do not yet drive every ERP screen's live renderer.

## Implemented foundation

- Versioned, data-only JSON document schema (schemaVersion 1), strict component allow-list, unique component identifiers, and a bounded component count.
- Flutter component registry and schema-driven renderer for text, buttons, fields, cards, dividers, spacing, grids, trees, and tables.
- Screen editor supports adding/selecting components, drag reordering, editing exposed properties, deletion, undo/redo, preview, local draft save/open, and JSON clipboard import/export.
- Supabase repository client includes design listing, version listing, draft save, approval, publish, and restore RPC calls.
- Supabase migration is applied to the configured project. It creates company-scoped design records, immutable revision records, audit records, RLS policies, and role-checked RPC functions.
- The migration's four Studio RPC functions use a hardened `pg_catalog, public` search path; authenticated users can execute them and anonymous users cannot.
- Schema tests cover round-trip, unsupported schema version, unknown component type, duplicate IDs, and oversized component collections.

## Explicit limitations

- The report designer, icon designer, full data-binding workflow, and advanced table/Grid/tree/form designers are still planned tabs, not finished tools.
- Drag-to-reorder exists; resize handles, responsive breakpoint editing, grouping, locking, and a full layer manager are not implemented yet.
- Binding definitions are not yet connected to live ERP query/data-source execution. Imported JSON is presentation data only and never executes Dart, SQL, or arbitrary callbacks.
- Approval, publish, and restore repository methods exist, but the corresponding full UI workflows, review gates, and end-to-end tests are not complete.
- Local drafts use SharedPreferences; encrypted offline storage, conflict-aware synchronization, and multi-device draft sync are not implemented.
- The layout editor saves per-device preferences and currently previews changes; it does not yet apply its settings globally to existing ERP screen renderers.
- Live RPC behavior still needs an authenticated owner/admin end-to-end test. No claim is made that every Studio tab is production-complete.

## Security

- Studio tables have RLS enabled and company-scoped policies.
- Studio write/status changes go through RPC functions with an explicit authenticated-user and owner/admin company-role check; anonymous execution is revoked.
- JSON is constrained to a fixed schema and allow-listed component types. It cannot execute imported code or SQL.
- Do not publish a design to end users until binding validation, permission review, UI approval workflow, and end-to-end tests are complete.
