---
name: flutter-performance
description: Diagnose and improve Flutter rendering, scrolling, memory, startup, and responsiveness without speculative optimization.
---

# Flutter Performance for Silsila

## Measure first
- Reproduce the slowdown on the affected screen and identify whether it is build, layout, paint, image decoding, I/O, or network work.
- Prefer Flutter DevTools, performance overlays, timeline traces, and profile/release builds where available.
- Record the affected device/viewport and a before/after observation; do not claim a speedup without measurement.

## Rendering and state
- Keep expensive filtering, sorting, parsing, and aggregation out of frequently called `build()` methods.
- Use `const`, stable keys, and localized state updates where they materially reduce rebuild work.
- Avoid rebuilding large trees for small field changes; preserve the project's existing state-management approach.
- Use lazy lists/grids for large collections and paginate database-backed datasets.
- Avoid nested unbounded scrollables and repeated shrink-wrapped lists in large data screens.

## Data and assets
- Avoid N+1 Supabase requests; select only required columns and use bounded pagination.
- Cache only data with a clear invalidation policy; never trade correctness or tenant isolation for caching.
- Resize/compress images appropriately and avoid decoding full-resolution assets into small thumbnails.
- Cancel obsolete requests and prevent stale asynchronous results from overwriting newer state.

## Safety
- Do not introduce isolates, caches, memoization layers, packages, or architecture changes without profiling evidence.
- Preserve RTL/LTR, table alignment, accessibility, and the approved compact ERP density.
- Verify behavior and memory/resource cleanup after optimization.
