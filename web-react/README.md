# Silsila React Web workspace

This is the React + TypeScript + Vite web client being migrated alongside the existing Flutter mobile application.

## Supabase connection

Set these Vite build-time variables in the deployment environment:

```env
VITE_SUPABASE_URL=https://teitsopmhruczplwlwgn.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-project-publishable-key
```

The browser client uses only the Supabase publishable key. Never put a Supabase secret/service-role key in this project or any `VITE_*` variable. Authentication uses the existing Supabase Auth email/password accounts and persisted sessions.

## Current migration slice: Item Categories

- Reads real `public.categories` rows from Supabase.
- Uses server-side search, activity filtering, sorting, count and pagination.
- Reads activity choices from `public.activity_types`.
- RLS remains the authority for row visibility.
- Create/update/delete are intentionally not exposed until the category table has reviewed write policies and matching authorization tests.
- No generated mock category records are included.

## Local development

```bash
cp .env.example .env.local
# replace the publishable key with the project's publishable key
npm install
npm test
npm run build
npm run dev
```

The Vercel project root directory is `web-react`; its shared Tajawal font is loaded from the repository's existing `assets/fonts/Tajawal.ttf` file.
