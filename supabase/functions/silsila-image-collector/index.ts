import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function safeUrl(raw: string): URL {
  const u = new URL(raw);
  if (!["http:", "https:"].includes(u.protocol)) throw new Error("يسمح بروابط HTTP وHTTPS فقط.");
  const h = u.hostname.toLowerCase();
  if (!h || h === "localhost" || h.endsWith(".localhost") || h.endsWith(".local") ||
      h === "0.0.0.0" || h === "127.0.0.1" || h === "::1" ||
      /^10\./.test(h) || /^192\.168\./.test(h) ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(h) || /^169\.254\./.test(h)) {
    throw new Error("الرابط يشير إلى عنوان محلي أو غير مسموح.");
  }
  if (u.username || u.password) throw new Error("لا تستخدم رابطًا يحتوي على بيانات دخول.");
  return u;
}

async function readLimited(response: Response, max: number): Promise<Uint8Array> {
  const reader = response.body?.getReader();
  if (!reader) throw new Error("تعذر قراءة محتوى الرابط.");
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > max) {
      await reader.cancel();
      throw new Error("حجم المحتوى أكبر من الحد المسموح.");
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { out.set(chunk, offset); offset += chunk.length; }
  return out;
}

function decodeEntities(s: string): string {
  return s.replace(/&amp;/g, "&").replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
}

function pageImages(html: string, base: URL) {
  const found = new Map<string, { url: string; alt: string }>();
  const add = (raw: string, alt = "") => {
    const clean = decodeEntities(raw.trim());
    if (!clean || clean.startsWith("data:") || clean.startsWith("blob:")) return;
    try {
      const u = safeUrl(new URL(clean, base).toString());
      if (!/\.(svg)(?:$|\?)/i.test(u.href)) found.set(u.href, { url: u.href, alt: alt.slice(0, 180) });
    } catch { /* skip unsafe or malformed candidates */ }
  };
  for (const m of html.matchAll(/<meta\b[^>]*(?:property|name)=["'](?:og:image|twitter:image)["'][^>]*>/gi)) {
    const tag = m[0]; const content = tag.match(/content=["']([^"']+)["']/i)?.[1]; if (content) add(content);
  }
  for (const m of html.matchAll(/<img\b[^>]*>/gi)) {
    const tag = m[0];
    const alt = tag.match(/\balt=["']([^"']*)["']/i)?.[1] ?? "";
    let src = tag.match(/\b(?:src|data-src|data-original|data-lazy-src)=["']([^"']+)["']/i)?.[1];
    const srcset = tag.match(/\bsrcset=["']([^"']+)["']/i)?.[1];
    if (srcset) {
      const first = srcset.split(",").map(x => x.trim().split(/\s+/)[0]).filter(Boolean).pop();
      if (first) add(first, alt);
    }
    if (src) add(src, alt);
  }
  return [...found.values()].slice(0, 160);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "استخدم POST." }, 405);
  try {
    const body = await req.json();
    const action = String(body.action ?? "scan");
    if (action === "scan") {
      const page = safeUrl(String(body.url ?? ""));
      const res = await fetch(page, {
        redirect: "manual",
        headers: { "User-Agent": "SilsilaImageCollector/1.0 (product image selection)", "Accept": "text/html,application/xhtml+xml" },
        signal: AbortSignal.timeout(18000),
      });
      if (res.status >= 300 && res.status < 400) return json({ error: "الموقع يحوّل الرابط تلقائيًا. افتح الرابط النهائي من شريط العنوان ثم أعد المحاولة." }, 422);
      if (!res.ok) return json({ error: `الموقع رفض الطلب أو أعاد HTTP ${res.status}.` }, 422);
      const type = res.headers.get("content-type") ?? "";
      if (!type.includes("text/html") && !type.includes("application/xhtml")) return json({ error: "الرابط لا يبدو صفحة HTML." }, 422);
      const htmlBytes = await readLimited(res, 2_500_000);
      const html = new TextDecoder().decode(htmlBytes);
      const images = pageImages(html, page);
      return json({ page: page.href, count: images.length, images });
    }
    if (action === "download") {
      const target = safeUrl(String(body.url ?? ""));
      const res = await fetch(target, {
        redirect: "manual",
        headers: { "User-Agent": "SilsilaImageCollector/1.0", "Accept": "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8" },
        signal: AbortSignal.timeout(18000),
      });
      if (res.status >= 300 && res.status < 400) return json({ error: "رابط الصورة يحوّل إلى رابط آخر؛ تعذر تنزيله بأمان." }, 422);
      if (!res.ok) return json({ error: `تعذر تنزيل الصورة (HTTP ${res.status}).` }, 422);
      const type = (res.headers.get("content-type") ?? "").split(";")[0].toLowerCase();
      if (!type.startsWith("image/") || type === "image/svg+xml") return json({ error: "الرابط لا يعيد صورة نقطية مدعومة." }, 422);
      const bytes = await readLimited(res, 5_000_000);
      let binary = "";
      for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, Math.min(i + 0x8000, bytes.length)));
      return json({ mime: type, base64: btoa(binary), bytes: bytes.length });
    }
    return json({ error: "الأمر غير معروف." }, 400);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "حدث خطأ غير متوقع." }, 400);
  }
});
