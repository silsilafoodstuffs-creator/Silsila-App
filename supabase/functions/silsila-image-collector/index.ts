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
  // The collector accepts hostnames, not literal IP addresses. This avoids
  // direct requests to loopback, private-network, and IPv6 link-local targets.
  if (!h || h.startsWith("[") || /^[0-9.]+$/.test(h) ||
      h === "localhost" || h.endsWith(".localhost") || h.endsWith(".local") ||
      h.endsWith(".internal") || h.endsWith(".test")) {
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

function productMetadata(html: string, base: URL) {
  const products: Array<Record<string, unknown>> = [];
  const normalizeImage = (raw: string) => {
    try {
      const u = new URL(raw, base);
      for (const key of ["width", "height", "w", "h", "quality", "q", "fit", "format", "fm", "utm_source", "utm_medium", "utm_campaign"]) u.searchParams.delete(key);
      u.hash = "";
      return u.href.toLowerCase();
    } catch { return ""; }
  };
  const propertyValue = (obj: Record<string, unknown>, names: string[]): string => {
    const raw = obj.additionalProperty;
    const props = Array.isArray(raw) ? raw : raw ? [raw] : [];
    for (const entry of props) {
      if (!entry || typeof entry !== "object") continue;
      const p = entry as Record<string, unknown>;
      const label = String(p.name ?? p.propertyID ?? "").toLowerCase().replace(/[\s_-]+/g, "");
      if (names.some(name => label.includes(name))) {
        const val = p.value ?? p.valueReference;
        if (val !== undefined && val !== null && String(val).trim()) return String(val).trim();
      }
    }
    return "";
  };
  const walk = (value: unknown) => {
    if (Array.isArray(value)) { for (const item of value) walk(item); return; }
    if (!value || typeof value !== "object") return;
    const obj = value as Record<string, unknown>;
    const rawType = obj["@type"];
    const types = (Array.isArray(rawType) ? rawType : [rawType]).map(x => String(x ?? "").toLowerCase());
    if (types.includes("product")) {
      const imagesRaw = obj.image;
      const images = (Array.isArray(imagesRaw) ? imagesRaw : [imagesRaw]).map(x => {
        if (typeof x === "string") return x;
        if (x && typeof x === "object") return String((x as Record<string, unknown>).url ?? (x as Record<string, unknown>).contentUrl ?? "");
        return "";
      }).filter(Boolean);
      const offersRaw = obj.offers;
      const offers = Array.isArray(offersRaw) ? offersRaw[0] : offersRaw;
      const offer = offers && typeof offers === "object" ? offers as Record<string, unknown> : {};
      const brandRaw = obj.brand;
      const brand = brandRaw && typeof brandRaw === "object" ? String((brandRaw as Record<string, unknown>).name ?? "") : String(brandRaw ?? "");
      const weightRaw = obj.weight;
      const weight = weightRaw && typeof weightRaw === "object" ? String((weightRaw as Record<string, unknown>).value ?? "") + " " + String(((weightRaw as Record<string, unknown>).unitCode ?? (weightRaw as Record<string, unknown>).unitText) ?? "") : String(weightRaw ?? obj.size ?? "");
      const productName = String(obj.name ?? "").trim();
      const mainUnit = String(obj.unitText ?? obj.unit ?? propertyValue(obj, ["mainunit", "sellingunit", "unitname", "وحدةرئيسية", "وحدةالبيع"])).trim();
      const subUnit = propertyValue(obj, ["minorunit", "subunit", "smallunit", "وحدةفرعية"]);
      const internalCount = propertyValue(obj, [
        "internalcount", "unitsperpack", "unitspackage", "packquantity",
        "quantityperunit", "innerpack", "عددداخلي", "عددالوحدات", "العددالداخلي",
      ]);
      const fullNameParts = [productName];
      if (weight.trim() && !productName.toLowerCase().includes(weight.trim().toLowerCase())) fullNameParts.push(weight.trim());
      if (mainUnit && !productName.toLowerCase().includes(mainUnit.toLowerCase())) fullNameParts.push(mainUnit);
      if (internalCount && !productName.includes(internalCount)) fullNameParts.push("عدد داخلي " + internalCount);
      const item = {
        product_name: productName,
        product_full_name: fullNameParts.filter(Boolean).join(" ").trim(),
        barcode: String(obj.gtin13 ?? obj.gtin14 ?? obj.gtin12 ?? obj.gtin8 ?? obj.gtin ?? ""),
        major_unit: mainUnit,
        minor_unit: subUnit,
        internal_count: internalCount,
        other_units: propertyValue(obj, ["otherunits", "units", "وحداتأخرى"]),
        sale_price: String(offer.price ?? offer.lowPrice ?? ""),
        main_category: String(obj.category ?? ""),
        subcategory: "",
        brand,
        weight: weight.trim(),
        description: String(obj.description ?? ""),
        _images: images.map(x => normalizeImage(x)),
      };
      products.push(item);
    }
    for (const [key, child] of Object.entries(obj)) {
      if (key !== "offers" && key !== "brand" && key !== "image") walk(child);
    }
  };
  for (const match of html.matchAll(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    try { walk(JSON.parse(decodeEntities(match[1].trim()))); } catch { /* ignore invalid JSON-LD */ }
  }
  const byImage = new Map<string, Record<string, unknown>>();
  for (const product of products) {
    for (const key of product._images as string[]) if (key && !byImage.has(key)) byImage.set(key, product);
  }
  return { byImage, normalizeImage };
}

function readableText(fragment: string): string {
  return decodeEntities(fragment
    .replace(/<script\\b[\\s\\S]*?<\\/script>/gi, " ")
    .replace(/<style\\b[\\s\\S]*?<\\/style>/gi, " ")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/\\s+/g, " "))
    .trim();
}

function usableEntityName(value: string): boolean {
  const name = value.trim().replace(/\\s+/g, " ");
  if (name.length < 2 || name.length > 120) return false;
  if (!/[a-zA-Z\\u0600-\\u06FF]/.test(name)) return false;
  if (/^(?:img|image|photo|dsc|pxl|pic)?[-_ .]*\\d+(?:[-_ .]+\\d+)*$/i.test(name)) return false;
  if (/^[-_ .]+\\d+(?:[-_ .]+\\d+)*$/.test(name)) return false;
  if (/^(?:image|product|item|category|view|details|read more|عرض|صورة|منتج)$/i.test(name)) return false;
  return true;
}

// Many shops put the real item name in a nearby product-card heading rather
// than in the image alt or URL. Recover that name from the image's HTML context.
function contextualEntityName(html: string, imageIndex: number): string {
  const start = Math.max(0, imageIndex - 2600);
  const end = Math.min(html.length, imageIndex + 2600);
  const fragment = html.slice(start, end);
  const candidates: Array<{ name: string; score: number }> = [];
  const rx = /<(h[1-6]|a|span|div|p)[^>]*(?:class|id)=["']([^"']*(?:product[-_ ]?(?:title|name)|woocommerce-loop-product__title|item[-_ ]?(?:title|name)|category[-_ ]?(?:title|name)|group[-_ ]?(?:title|name)|card-title|product-name|product-title)[^"']*)["'][^>]*>([\\s\\S]{1,500}?)<\\/\\1>/gi;
  let match: RegExpExecArray | null;
  while ((match = rx.exec(fragment)) !== null) {
    const name = readableText(match[3]);
    if (!usableEntityName(name)) continue;
    const selector = match[2].toLowerCase();
    let score = 20 - Math.min(10, Math.abs((start + match.index) - imageIndex) / 260);
    if (/product[-_ ]?(?:title|name)|woocommerce-loop-product__title|item[-_ ]?(?:title|name)|category[-_ ]?(?:title|name)|group[-_ ]?(?:title|name)/i.test(selector)) score += 20;
    if (name.length > 80) score -= 8;
    candidates.push({ name, score });
  }
  candidates.sort((a, b) => b.score - a.score);
  if (candidates.length) return candidates[0].name;

  // As a secondary fallback, use a descriptive linked title/aria-label.
  const before = html.slice(Math.max(0, imageIndex - 1200), imageIndex);
  const anchorOpen = before.lastIndexOf("<a");
  const anchorClose = before.lastIndexOf("</a>");
  if (anchorOpen > anchorClose) {
    const attrs = before.slice(anchorOpen).match(/(?:title|aria-label)=["']([^"']+)["']/i)?.[1] ?? "";
    const name = readableText(attrs);
    if (usableEntityName(name)) return name;
  }
  return "";
}

function pageImages(html: string, base: URL) {
  const found = new Map<string, Record<string, unknown>>();
  const metadata = productMetadata(html, base);
  const blocked = /(?:^|[\/_\-. ])(?:logo|site[-_ ]?logo|brand[-_ ]?logo|header|masthead|banner|hero|favicon|sprite|placeholder|no[-_ ]?image|loading|spinner|avatar|profile|icon|social|payment|footer|menu|navigation|nav)(?:$|[\/_\-. ])/i;
  const tracking = new Set(["fbclid", "gclid", "dclid", "msclkid", "ref", "source", "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id", "campaign", "tracking", "width", "height", "w", "h", "quality", "q", "fit", "crop", "auto", "format", "fm", "resize"]);
  const normalize = (u: URL) => {
    const path = u.pathname
      .replace(/[-_](?:\d{2,4}x\d{2,4}|\d{2,4}w|thumb(?:nail)?|small|medium|large)(?=\.[a-z0-9]+$)/i, "")
      .replace(/\/(?:thumb|thumbnail|small|medium|large|resized)\//i, "/");
    const params = [...u.searchParams.entries()]
      .filter(([k]) => !tracking.has(k.toLowerCase()))
      .sort(([a, av], [b, bv]) => a.toLowerCase().localeCompare(b.toLowerCase()) || av.localeCompare(bv));
    return u.origin.toLowerCase() + path + (params.length ? "?" + new URLSearchParams(params).toString() : "");
  };
  const add = (raw: string, alt = "", hint = "", width = 0, height = 0, contextName = "") => {
    const clean = decodeEntities(raw.trim());
    if (!clean || clean.startsWith("data:") || clean.startsWith("blob:")) return;
    try {
      const u = safeUrl(new URL(clean, base).toString());
      const context = (u.pathname + " " + u.search + " " + alt + " " + hint).toLowerCase();
      if (/\.svg(?:$|\?)/i.test(u.href) || blocked.test(context)) return;
      if ((width > 0 && width < 90) || (height > 0 && height < 70)) return;
      const key = normalize(u);
      const structured = metadata.byImage.get(metadata.normalizeImage(u.href)) ?? {};
      if (!found.has(key)) {
        const readableAlt = usableEntityName(alt) ? alt : "";
        const entityName = String(structured.product_full_name ?? structured.product_name ?? "").trim() ||
          (usableEntityName(contextName) ? contextName : "") || readableAlt;
        found.set(key, {
          ...structured,
          url: u.href,
          alt: alt.slice(0, 180),
          context_name: contextName.slice(0, 180),
          product_name: entityName.slice(0, 180),
        });
      }
    } catch { /* skip unsafe or malformed candidates */ }
  };
  for (const m of html.matchAll(/<img\b[^>]*>/gi)) {
    const tag = m[0];
    const alt = decodeEntities(tag.match(/\balt=["']([^"']*)["']/i)?.[1] ?? "");
    const title = decodeEntities(tag.match(/\btitle=["']([^"']*)["']/i)?.[1] ?? "");
    const hint = [
      tag.match(/\bclass=["']([^"']*)["']/i)?.[1] ?? "",
      tag.match(/\bid=["']([^"']*)["']/i)?.[1] ?? "",
      tag.match(/\bitemprop=["']([^"']*)["']/i)?.[1] ?? "",
    ].join(" ");
    const width = Number(tag.match(/\bwidth=["']?(\d+)/i)?.[1] ?? 0);
    const height = Number(tag.match(/\bheight=["']?(\d+)/i)?.[1] ?? 0);
    const srcset = tag.match(/\b(?:srcset|data-srcset)=["']([^"']+)["']/i)?.[1];
    const src = tag.match(/\b(?:src|data-src|data-original|data-lazy-src|data-image)=["']([^"']+)["']/i)?.[1];
    if (srcset) {
      const choices = srcset.split(",").map(x => {
        const parts = x.trim().split(/\s+/);
        const descriptor = parts[1] ?? "1x";
        const value = descriptor.endsWith("w") ? Number.parseInt(descriptor, 10) : Number.parseFloat(descriptor) * 1000;
        return { url: parts[0], value: Number.isFinite(value) ? value : 0 };
      }).filter(x => x.url).sort((a, b) => b.value - a.value);
      if (choices.length) add(choices[0].url, alt || title, hint, width, height, contextName);
    }
    if (src) add(src, alt || title, hint, width, height, contextName);
  }
  // Open Graph images are deliberately not collected: they commonly represent
  // the site logo, page banner, or social preview rather than an individual item.
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
