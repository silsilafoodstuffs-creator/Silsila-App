# Silsila React Web Performance POC

Isolated React + TypeScript + Vite proof of concept. It is not connected to Supabase and uses 10,000 generated mock category records in browser memory.

## Run locally
```bash
cd web-react
npm install
npm run dev
npm run build
npm test
```

## Scope
- Arabic RTL shell and Silsila visual tokens.
- Activity filter and deferred search.
- Fixed-height virtualized list to avoid rendering thousands of DOM rows at once.
- Responsive layout.

## Explicit exclusions
No production credentials, Supabase client, real customer data, writes, authentication, or migration. No route replacement or production deployment. Functional parity, authorization parity, database pagination, and performance comparison against Flutter Web remain acceptance gates.

CI validation is executed by `.github/workflows/react-web-poc.yml` on changes to this isolated directory.
