# Silsila API v1 — Integration Guide

## Base URL

`https://teitsopmhruczplwlwgn.supabase.co/functions/v1/silsila-api-v1`

All routes are read-only `GET`. Send the API key in the HTTP Authorization header:

```http
Authorization: Bearer slk_<64-hex-characters>
```

Never place the key in a URL, browser query string, mobile app source, logs, or client-side public configuration. Issue keys from **إدارة مفاتيح API** in the ERP. The full secret is returned once at issuance; the database stores only its SHA-256 digest.

## Routes and scopes

| Route | Required scope | Description |
|---|---|---|
| `GET /v1/company` | `company:read` | Company profile fields permitted for API use |
| `GET /v1/items` | `items:read` | Active non-demo item catalog |
| `GET /v1/customers` | `customers:read` | Active customers, including counterparties marked both |
| `GET /v1/suppliers` | `suppliers:read` | Active suppliers, including counterparties marked both |
| `GET /v1/inventory/balances` | `inventory:read` | Stock balance rows by company |
| `GET /v1/orders` | `orders:read` | Non-demo sales documents |

The `read` scope grants access to all read routes. Grant only the narrow scopes an integration actually needs.

## Pagination

List routes accept:
- `limit`: 1–100; default 50
- `offset`: 0–100000; default 0

Successful list responses use `data` and `meta` fields. `meta` contains `api_version`, `limit`, `offset`, and `total`.

## Example

```bash
curl --fail-with-body \
  -H "Authorization: Bearer $SILSILA_API_KEY" \
  "https://teitsopmhruczplwlwgn.supabase.co/functions/v1/silsila-api-v1/v1/items?limit=50&offset=0"
```

Keep `SILSILA_API_KEY` in a server-side secret manager. Do not embed it in Flutter or a public web build.

## Security and limits

- API key format: `slk_` followed by 64 lowercase hexadecimal characters.
- The gateway hashes the presented key and authenticates it server-side.
- Revoked and expired keys are rejected.
- The gateway enforces 60 requests per minute per key.
- Maximum page size is 100 rows.
- Responses use `Cache-Control: no-store`.
- Unsupported methods return HTTP 405; unknown routes return 404.
- Invalid keys return 401; missing scope returns 403; rate limit returns 429.
- Data access is constrained by the company bound to the issued key.
- Key issuance and revocation are restricted to company owners/admins and recorded in the company activity log.

## Operational note

The Edge Function is deployed as `silsila-api-v1` (Version 3). Database lifecycle functions were smoke-tested transactionally, with all temporary test writes rolled back. A real HTTP request from an external network and Flutter build/runtime checks remain part of the project-wide test phase; do not treat deployment status alone as a successful end-to-end client test.
