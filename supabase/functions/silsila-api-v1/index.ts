import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: cors });
const scopesByPath: Record<string, string> = {
  "/v1/company": "company:read",
  "/v1/items": "items:read",
  "/v1/customers": "customers:read",
  "/v1/suppliers": "suppliers:read",
  "/v1/inventory/balances": "inventory:read",
  "/v1/orders": "orders:read",
};
const allowedColumns: Record<string, string> = {
  "/v1/items": "id,item_code,barcode,item_name,item_name_en,base_unit,purchase_price,sale_price,tax_rate,brand_name,is_active,updated_at",
  "/v1/customers": "id,party_code,party_name,party_kind,phone,email,is_active,credit_limit,updated_at",
  "/v1/suppliers": "id,party_code,party_name,party_kind,phone,email,is_active,updated_at",
  "/v1/inventory/balances": "company_id,branch_id,warehouse_id,item_id,quantity_on_hand,today_quantity_in,today_quantity_out,last_movement_at,inventory_value,average_unit_cost",
  "/v1/orders": "id,document_number,document_date,due_date,document_type,status,subtotal,discount_total,tax_total,grand_total,paid_total,created_at,updated_at",
};
async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET") return reply(405, { error: "method_not_allowed", message: "استخدم GET فقط؛ واجهة القراءة لا تنفذ تعديلات." });
  const url = new URL(req.url);
  const pathParts = url.pathname.split("/").filter(Boolean);
  const functionIndex = pathParts.indexOf("silsila-api-v1");
  const routedPath = functionIndex >= 0
    ? "/" + pathParts.slice(functionIndex + 1).join("/")
    : url.pathname;
  const path = routedPath.replace(/\/$/, "") || "/";
  const requiredScope = scopesByPath[path];
  if (!requiredScope) return reply(404, { error: "not_found" });
  const rawKey = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!/^slk_[a-f0-9]{64}$/.test(rawKey)) return reply(401, { error: "invalid_api_key" });
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return reply(503, { error: "gateway_not_configured" });
  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: credentials, error: authError } = await admin.rpc("erp_api_key_authenticate", {
    p_key_hash: await sha256Hex(rawKey),
  });
  if (authError) return reply(503, { error: "authentication_service_unavailable" });
  const credential = Array.isArray(credentials) ? credentials[0] : null;
  if (!credential) return reply(401, { error: "invalid_or_revoked_api_key" });
  const scopes = Array.isArray(credential.scopes) ? credential.scopes as string[] : [];
  if (!scopes.includes("read") && !scopes.includes(requiredScope)) return reply(403, { error: "insufficient_scope", required_scope: requiredScope });
  const { data: withinLimit, error: limitError } = await admin.rpc("erp_api_consume_rate_limit", {
    p_key_id: credential.key_id, p_limit: 60,
  });
  if (limitError) return reply(503, { error: "rate_limit_service_unavailable" });
  if (withinLimit !== true) return reply(429, { error: "rate_limit_exceeded", retry_after_seconds: 60 });
  const companyId = credential.company_id as string;
  if (path === "/v1/company") {
    const { data: company, error: companyError } = await admin
      .from("erp_companies")
      .select("id,legal_name,trade_name,tax_number,commercial_register,phone,email,address,base_currency")
      .eq("id", companyId)
      .maybeSingle();
    if (companyError) return reply(500, { error: "company_query_failed" });
    if (!company) return reply(404, { error: "company_not_found" });
    return reply(200, { data: company, meta: { api_version: "v1" } });
  }
  const limit = Math.min(100, Math.max(1, Number(url.searchParams.get("limit") ?? "50") || 50));
  const offset = Math.max(0, Math.min(100000, Number(url.searchParams.get("offset") ?? "0") || 0));
  let table = "";
  switch (path) {
    case "/v1/items": table = "erp_items"; break;
    case "/v1/customers":
    case "/v1/suppliers": table = "erp_parties"; break;
    case "/v1/inventory/balances": table = "erp_stock_balances"; break;
    case "/v1/orders": table = "erp_sales_documents"; break;
  }
  let query = admin.from(table).select(allowedColumns[path], { count: "exact" }).eq("company_id", companyId);
  if (path === "/v1/items" || path === "/v1/customers" || path === "/v1/suppliers" || path === "/v1/orders") {
    query = query.or("is_demo_data.is.null,is_demo_data.eq.false");
  }
  if (path === "/v1/items" || path === "/v1/customers" || path === "/v1/suppliers") query = query.eq("is_active", true);
  if (path === "/v1/customers") query = query.in("party_kind", ["customer", "both"]);
  if (path === "/v1/suppliers") query = query.in("party_kind", ["supplier", "both"]);
  const { data, error, count } = await query.order(path === "/v1/inventory/balances" ? "item_id" : "created_at", { ascending: false, nullsFirst: false }).range(offset, offset + limit - 1);
  if (error) return reply(500, { error: "data_query_failed" });
  return reply(200, { data: data ?? [], meta: { api_version: "v1", limit, offset, total: count ?? 0 } });
});
