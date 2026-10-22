import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const TABLES = ["categories", "erp_item_categories", "erp_items", "products"] as const;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST required" }, 405);
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Authentication required" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "Server configuration missing" }, 500);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Invalid session" }, 401);

  const userId = userData.user.id;
  const [{ data: memberships, error: membershipError }, { data: profile }] = await Promise.all([
    admin.from("erp_company_members").select("member_role").eq("user_id", userId).eq("is_active", true),
    admin.from("profiles").select("role").eq("id", userId).maybeSingle(),
  ]);
  if (membershipError) return json({ error: "Could not verify account permissions" }, 403);
  const roles = [
    ...(memberships ?? []).map((m: { member_role?: string }) => String(m.member_role ?? "").toLowerCase()),
    String(profile?.role ?? "").toLowerCase(),
  ];
  if (!roles.some((role) => ["owner", "admin", "company_admin", "مالك", "مدير", "مدير النظام"].includes(role))) {
    return json({ error: "صلاحية مالك/مدير الشركة مطلوبة." }, 403);
  }

  const cache = new Map<string, { hex: string; mime: string }>();
  const summary: Record<string, { migrated: number; skipped: number; failed: number }> = {};
  let totalMigrated = 0;
  for (const table of TABLES) {
    summary[table] = { migrated: 0, skipped: 0, failed: 0 };
    const { data: rows, error } = await admin.from(table)
      .select("id,image_url").not("image_url", "is", null).is("image_data", null).limit(1000);
    if (error) { summary[table].failed++; continue; }

    for (const row of rows ?? []) {
      const imageUrl = String(row.image_url ?? "");
      let parsed: URL;
      try { parsed = new URL(imageUrl); } catch { summary[table].skipped++; continue; }
      const allowedPath = parsed.hostname === "cdn.jsdelivr.net" && parsed.protocol === "https:" &&
        /^\/gh\/twitter\/twemoji@14\.0\.2\/assets\/72x72\/[0-9a-f-]+\.png$/i.test(parsed.pathname);
      if (!allowedPath) { summary[table].skipped++; continue; }
      try {
        let asset = cache.get(imageUrl);
        if (!asset) {
          const response = await fetch(imageUrl, { redirect: "error" });
          if (!response.ok) throw new Error("Image download failed");
          const declaredLength = Number(response.headers.get("content-length") ?? 0);
          if (declaredLength > MAX_IMAGE_BYTES) throw new Error("Image too large");
          const bytes = new Uint8Array(await response.arrayBuffer());
          if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) throw new Error("Invalid image size");
          asset = { hex: Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join(""), mime: "image/png" };
          cache.set(imageUrl, asset);
        }
        const { error: updateError } = await admin.from(table).update({
          image_data: "\\x" + asset.hex, image_mime_type: asset.mime, image_url: null,
        }).eq("id", row.id);
        if (updateError) throw updateError;
        summary[table].migrated++;
        totalMigrated++;
      } catch { summary[table].failed++; }
    }
  }
  return json({ success: true, total_migrated: totalMigrated, tables: summary });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
