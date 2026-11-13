# Silsila Studio — implementation status

This branch introduces the first safe vertical slice of Silsila Studio.

## Implemented in this increment
- ERP navigation entry for استوديو التصميم والتطوير.
- Versioned JSON document model (schemaVersion 1) with strict component allow-list and bounded component count.
- Flutter component registry and schema-driven renderer for text, buttons, fields, cards, dividers, spacing, grids, trees and tables.
- Visual editor foundation with component insertion, selection, reordering, property editing, deletion, undo/redo, preview, local draft save/open, and JSON import/export.
- Unit tests for document round-trip and rejection of unsupported schema/component input.
- Supabase migration defining company-scoped design records, immutable revision records, audit records, and membership/owner-admin RLS policies.

## Explicit limitations (not implemented yet)
- Local draft persistence currently uses SharedPreferences; it is not encrypted, not a conflict-resolving offline database, and does not yet synchronize to Supabase.
- Cloud repository operations, binding review/test workflow, approval/publish/rollback, role-specific Studio permission catalog, audit event integration, and offline conflict resolution remain to be implemented.
- Current tree/table/grid preview widgets are structural starter renderers, not full production designers.
- Report designer, icon designer/import pipeline, advanced tree/grid/table/form designers, drag-resize handles, responsive breakpoints, and full component library management remain outstanding.
- No migration has been applied to the live Supabase project by this code change.
- No Flutter analyzer, tests, Web build, Android APK, or WebView run is claimed until executed by CI.

## Safety
The renderer accepts data-only schemas from a fixed registry. It never evaluates imported code, SQL, callbacks, or arbitrary expressions. Supabase schema changes require manual review and migration application.
