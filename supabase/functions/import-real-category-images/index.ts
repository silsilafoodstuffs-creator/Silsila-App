import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function rasterMime(bytes: Uint8Array): string | null {
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) return "image/png";
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.length >= 12 && String.fromCharCode(...bytes.subarray(0, 4)) === "RIFF" && String.fromCharCode(...bytes.subarray(8, 12)) === "WEBP") return "image/webp";
  if (bytes.length >= 6 && ["GIF87a", "GIF89a"].includes(String.fromCharCode(...bytes.subarray(0, 6)))) return "image/gif";
  return null;
}

function hex(bytes: Uint8Array): string {
  return "\\x" + Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
}

function decodeEntities(value: string): string {
  return value.replace(/&amp;/g, "&").replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
}

async function findCommonsImage(query: string): Promise<{
  bytes: Uint8Array; mime: string; url: string; attribution: string;
} | null> {
  const searchUrl = new URL("https://commons.wikimedia.org/w/api.php");
  searchUrl.searchParams.set("action", "query");
  searchUrl.searchParams.set("generator", "search");
  searchUrl.searchParams.set("gsrsearch", query + " filetype:bitmap");
  searchUrl.searchParams.set("gsrnamespace", "6");
  searchUrl.searchParams.set("gsrlimit", "8");
  searchUrl.searchParams.set("prop", "imageinfo");
  searchUrl.searchParams.set("iiprop", "url|mime|size|extmetadata");
  searchUrl.searchParams.set("iiurlwidth", "640");
  searchUrl.searchParams.set("format", "json");
  searchUrl.searchParams.set("origin", "*");
  const searchResponse = await fetch(searchUrl, {
    headers: { "User-Agent": "SilsilaERP/1.0 (category image catalog; contact through repository)" },
    signal: AbortSignal.timeout(12000),
  });
  if (!searchResponse.ok) throw new Error("Wikimedia Commons search HTTP " + searchResponse.status);
  const json = await searchResponse.json();
  const pages = Object.values(json?.query?.pages ?? {}) as Array<Record<string, unknown>>;
  for (const page of pages) {
    const info = (page.imageinfo as Array<Record<string, unknown>> | undefined)?.[0];
    if (!info) continue;
    const mime = String(info.mime ?? "");
    if (!["image/jpeg", "image/png", "image/webp", "image/gif"].includes(mime)) continue;
    const size = Number(info.size ?? 0);
    if (size < 12000 || size > 8 * 1024 * 1024) continue;
    const url = String(info.thumburl ?? info.url ?? "");
    if (!url.startsWith("https://")) continue;
    const imageResponse = await fetch(url, {
      headers: { "User-Agent": "SilsilaERP/1.0 (category image catalog)" },
      signal: AbortSignal.timeout(15000),
    });
    if (!imageResponse.ok) continue;
    const buffer = new Uint8Array(await imageResponse.arrayBuffer());
    if (buffer.length < 10000 || buffer.length > 5 * 1024 * 1024) continue;
    const detected = rasterMime(buffer);
    if (!detected) continue;
    const metadata = (info.extmetadata ?? {}) as Record<string, { value?: string }>;
    const license = decodeEntities(String(metadata.LicenseShortName?.value ?? "Wikimedia Commons"));
    const artist = decodeEntities(String(metadata.Artist?.value ?? metadata.Credit?.value ?? "Wikimedia Commons contributor"))
      .replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim().slice(0, 350);
    const licenseUrl = decodeEntities(String(metadata.LicenseUrl?.value ?? "https://commons.wikimedia.org/"));
    return {
      bytes: buffer,
      mime: detected,
      url: String(info.descriptionurl ?? page.title ?? url),
      attribution: artist + " — " + license + " (" + licenseUrl + ")",
    };
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond({ error: "POST only" }, 405);
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey || !authorization.startsWith("Bearer ")) {
    return respond({ error: "يلزم تسجيل الدخول قبل استيراد الصور." }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return respond({ error: "جلسة الدخول غير صالحة." }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return respond({ error: "بيانات الطلب غير صالحة." }, 400); }
  const companyId = String(body.company_id ?? "");
  const activityCode = String(body.activity_code ?? "");
  const offset = Math.max(0, Math.floor(Number(body.offset ?? 0)));
  const limit = Math.min(12, Math.max(1, Math.floor(Number(body.limit ?? 12))));
  if (!/^[0-9a-f-]{36}$/i.test(companyId) || !/^ACT[A-Z0-9]+$/i.test(activityCode)) {
    return respond({ error: "الشركة أو كود النشاط غير صالح." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: membership, error: membershipError } = await admin
    .from("erp_company_members").select("company_id")
    .eq("company_id", companyId).eq("user_id", user.id).eq("is_active", true).maybeSingle();
  if (membershipError || !membership) return respond({ error: "ليس لديك صلاحية استيراد صور هذه الشركة." }, 403);

  const { data: rows, error: rowsError } = await admin
    .from("erp_item_categories")
    .select("id,category_code,category_name,category_name_en,image_mime_type")
    .eq("company_id", companyId).eq("activity_code", activityCode)
    .order("category_code").range(offset, offset + limit - 1);
  if (rowsError) return respond({ error: rowsError.message }, 500);

  const results: Array<Record<string, unknown>> = [];
  for (const row of rows ?? []) {
    const id = String(row.id);
    if (["image/jpeg", "image/png", "image/webp", "image/gif"].includes(String(row.image_mime_type ?? ""))) {
      results.push({ id, code: row.category_code, status: "already_real" });
      continue;
    }
    const en = String(row.category_name_en ?? "").trim();
    const ar = String(row.category_name ?? "").trim();
    const query = en.length >= 3 ? en : ar;
    try {
      const match = await findCommonsImage(query);
      if (!match) {
        results.push({ id, code: row.category_code, status: "not_found" });
        continue;
      }
      const { error: updateError } = await admin.from("erp_item_categories").update({
        image_data: hex(match.bytes),
        image_mime_type: match.mime,
        image_url: null,
        image_source_url: match.url,
        image_attribution: match.attribution,
      }).eq("id", id).eq("company_id", companyId);
      if (updateError) throw updateError;
      results.push({ id, code: row.category_code, status: "imported", mime: match.mime, source: match.url });
    } catch (error) {
      results.push({ id, code: row.category_code, status: "error", error: String(error).slice(0, 240) });
    }
  }
  const imported = results.filter(x => x.status === "imported").length;
  return respond({
    activity_code: activityCode, offset, requested: rows?.length ?? 0,
    imported, already_real: results.filter(x => x.status === "already_real").length,
    not_found: results.filter(x => x.status === "not_found").length,
    errors: results.filter(x => x.status === "error").length, results,
  });
});
