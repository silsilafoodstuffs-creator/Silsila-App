import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json; charset=utf-8" } });
}
function rasterMime(bytes: Uint8Array): string | null {
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) return "image/png";
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.length >= 12 && String.fromCharCode(...bytes.subarray(0,4)) === "RIFF" && String.fromCharCode(...bytes.subarray(8,12)) === "WEBP") return "image/webp";
  if (bytes.length >= 6 && ["GIF87a","GIF89a"].includes(String.fromCharCode(...bytes.subarray(0,6)))) return "image/gif";
  return null;
}
function hex(bytes: Uint8Array): string {
  return "\\x" + Array.from(bytes, b => b.toString(16).padStart(2,"0")).join("");
}
function byteLengthFromDb(value: unknown): number {
  if (typeof value !== "string") return 0;
  if (value.startsWith("\\x")) return Math.floor((value.length - 2) / 2);
  return 0;
}
function clean(value: unknown): string { return String(value ?? "").replace(/<[^>]*>/g," ").replace(/&amp;/g,"&").replace(/\s+/g," ").trim(); }

async function findCommonsImage(query: string): Promise<{bytes:Uint8Array; mime:string; source:string; attribution:string}|null> {
  const url = new URL("https://commons.wikimedia.org/w/api.php");
  url.searchParams.set("action","query");
  url.searchParams.set("generator","search");
  url.searchParams.set("gsrsearch", query + " filetype:bitmap");
  url.searchParams.set("gsrnamespace","6");
  url.searchParams.set("gsrlimit","10");
  url.searchParams.set("prop","imageinfo");
  url.searchParams.set("iiprop","url|mime|size|extmetadata");
  url.searchParams.set("iiurlwidth","800");
  url.searchParams.set("format","json");
  const sr = await fetch(url,{headers:{"User-Agent":"SilsilaERP/1.0 (catalog image import)"},signal:AbortSignal.timeout(12000)});
  if (!sr.ok) throw new Error("Wikimedia search HTTP " + sr.status);
  const json = await sr.json();
  const pages = Object.values(json?.query?.pages ?? {}) as Array<Record<string,unknown>>;
  for (const page of pages) {
    const info = (page.imageinfo as Array<Record<string,unknown>>|undefined)?.[0];
    if (!info || !String(info.mime ?? "").startsWith("image/")) continue;
    const sourceUrl = String(info.thumburl ?? info.url ?? "");
    if (!sourceUrl.startsWith("https://")) continue;
    const response = await fetch(sourceUrl,{headers:{"User-Agent":"SilsilaERP/1.0 (catalog image import)"},signal:AbortSignal.timeout(15000)});
    if (!response.ok) continue;
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length < 5000 || bytes.length > 5*1024*1024) continue;
    const mime = rasterMime(bytes);
    if (!mime) continue;
    const meta = (info.extmetadata ?? {}) as Record<string,{value?:string}>;
    const license = clean(meta.LicenseShortName?.value ?? "Wikimedia Commons");
    const artist = clean(meta.Artist?.value ?? meta.Credit?.value ?? "Wikimedia Commons contributor").slice(0,250);
    const licenseUrl = clean(meta.LicenseUrl?.value ?? "https://commons.wikimedia.org/");
    return {bytes,mime,source:String(info.descriptionurl ?? page.title ?? sourceUrl),attribution:artist+" — "+license+" ("+licenseUrl+")"};
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok",{headers:cors});
  if (req.method !== "POST") return respond({error:"استخدم POST."},405);
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey || !authorization.startsWith("Bearer ")) return respond({error:"يلزم تسجيل الدخول قبل استيراد الصور."},401);
  const userClient = createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
  const token = authorization.replace(/^Bearer\s+/i,"");
  const {data:{user},error:authError} = await userClient.auth.getUser(token);
  if (authError || !user) return respond({error:"جلسة الدخول غير صالحة."},401);
  let body: Record<string,unknown>;
  try { body = await req.json(); } catch { return respond({error:"بيانات الطلب غير صالحة."},400); }
  const companyId = String(body.company_id ?? "");
  const offset = Math.max(0,Math.floor(Number(body.offset ?? 0)));
  const limit = Math.min(8,Math.max(1,Math.floor(Number(body.limit ?? 8))));
  if (!/^[0-9a-f-]{36}$/i.test(companyId)) return respond({error:"معرّف الشركة غير صالح."},400);
  const admin = createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:membership,error:membershipError} = await admin.from("erp_company_members").select("company_id")
    .eq("company_id",companyId).eq("user_id",user.id).eq("is_active",true).maybeSingle();
  if (membershipError || !membership) return respond({error:"ليس لديك صلاحية استيراد صور هذه الشركة."},403);
  const {data:rows,error:rowsError} = await admin.from("erp_items")
    .select("id,item_code,item_name,item_name_en,brand_name,image_data,image_mime_type")
    .eq("company_id",companyId).order("item_code").range(offset,offset+limit-1);
  if (rowsError) return respond({error:rowsError.message},500);
  const results:Array<Record<string,unknown>>=[];
  for (const row of rows ?? []) {
    const id=String(row.id), mime=String(row.image_mime_type ?? ""), bytes=byteLengthFromDb(row.image_data);
    if (["image/jpeg","image/png","image/webp","image/gif"].includes(mime) && bytes >= 5000) {
      results.push({id,code:row.item_code,status:"already_real"}); continue;
    }
    const en=clean(row.item_name_en), ar=clean(row.item_name), brand=clean(row.brand_name);
    const query=[brand,en || ar].filter(Boolean).join(" ");
    try {
      const match=await findCommonsImage(query);
      if (!match) { results.push({id,code:row.item_code,status:"not_found"}); continue; }
      const {error:updateError}=await admin.from("erp_items").update({
        image_data:hex(match.bytes),image_mime_type:match.mime,image_url:null,
      }).eq("id",id).eq("company_id",companyId);
      if (updateError) throw updateError;
      results.push({id,code:row.item_code,status:"imported",mime:match.mime,source:match.source,attribution:match.attribution});
    } catch (error) { results.push({id,code:row.item_code,status:"error",error:String(error).slice(0,220)}); }
  }
  return respond({
    offset,requested:rows?.length ?? 0,
    imported:results.filter(x=>x.status==="imported").length,
    already_real:results.filter(x=>x.status==="already_real").length,
    not_found:results.filter(x=>x.status==="not_found").length,
    errors:results.filter(x=>x.status==="error").length,results,
  });
});
