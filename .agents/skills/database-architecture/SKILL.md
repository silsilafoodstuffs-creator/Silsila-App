---
name: database-architecture
description: Design and review Silsila PostgreSQL data models, relationships, tenant boundaries, migrations, and query patterns.
---

# Database Architecture for Silsila

- Map the existing schema and application data access before proposing a new table, column, view, RPC, or relationship.
- Respect Silsila's company, activity, branch, warehouse, customer, supplier, and role relationships; never assume a single-user ownership model.
- Prefer normalized relational structures for authoritative transactional data; use denormalization only with a documented consistency strategy.
- Define primary keys, foreign keys, uniqueness, nullability, check constraints, and delete/update behavior deliberately.
- Avoid cascade deletion for business records unless the domain explicitly requires it and impact is proven safe.
- Treat generated codes as business identifiers with uniqueness scope and migration rules; do not silently renumber existing records.
- Add indexes for measured query patterns and foreign-key access; avoid redundant indexes and speculative indexing.
- Use transactions for multi-step changes and make migrations idempotent where practical.
- Document data ownership, lifecycle, retention, and backfill strategy.
- Check every dependent query, trigger, view, RPC, report, import/export, and RLS policy before schema changes.
- No migration or production data mutation is authorized by this skill alone; obtain explicit approval for the specific operation.
