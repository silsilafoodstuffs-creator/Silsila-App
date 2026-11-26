import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase, supabaseConfigError } from "./lib/supabase";

type Category = {
  id: number;
  name: string;
  parent_id: number | null;
  icon: string | null;
  image_url: string | null;
  sort_order: number;
  is_active: boolean;
  activity_type: string | null;
  created_at: string;
};

const PAGE_SIZE = 25;

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState("");
  const [rows, setRows] = useState<Category[]>([]);
  const [parents, setParents] = useState<Record<number, string>>({});
  const [activities, setActivities] = useState<string[]>([]);
  const [activity, setActivity] = useState("الكل");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [dataError, setDataError] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    if (!supabase) { setAuthReady(true); return; }
    let alive = true;
    supabase.auth.getSession().then(({ data, error }) => {
      if (!alive) return;
      if (error) setAuthError(error.message);
      setSession(data.session);
      setAuthReady(true);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setAuthReady(true);
    });
    return () => { alive = false; listener.subscription.unsubscribe(); };
  }, []);

  useEffect(() => {
    if (!supabase || !authReady) return;
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setDataError("");
      try {
        let request = supabase.from("categories")
          .select("id,name,parent_id,icon,image_url,sort_order,is_active,activity_type,created_at", { count: "exact" })
          .order("sort_order", { ascending: true })
          .order("name", { ascending: true })
          .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
        if (activity !== "الكل") request = request.eq("activity_type", activity);
        if (query.trim()) request = request.ilike("name", `%${query.trim().replace(/[%_]/g, "\\$&")}%`);
        const { data, error, count } = await request;
        if (error) throw error;
        if (cancelled) return;
        const categories = (data ?? []) as Category[];
        setRows(categories);
        setTotal(count ?? 0);
        const parentIds = [...new Set(categories.map((item) => item.parent_id).filter((id): id is number => id !== null))];
        if (parentIds.length) {
          const { data: parentRows, error: parentError } = await supabase.from("categories").select("id,name").in("id", parentIds);
          if (parentError) throw parentError;
          if (!cancelled) setParents(Object.fromEntries((parentRows ?? []).map((item) => [item.id, item.name])));
        } else if (!cancelled) setParents({});
        const { data: activityRows, error: activityError } = await supabase.from("activity_types").select("name").eq("is_active", true).order("sort_order");
        if (activityError) throw activityError;
        if (!cancelled) setActivities((activityRows ?? []).map((item) => item.name));
      } catch (error) {
        if (!cancelled) setDataError(error instanceof Error ? error.message : "تعذر قراءة فئات الأصناف من قاعدة البيانات.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [authReady, session, activity, query, page, refreshKey]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const rangeLabel = useMemo(() => total ? `${page * PAGE_SIZE + 1}–${Math.min((page + 1) * PAGE_SIZE, total)} من ${total}` : "لا توجد سجلات", [page, total]);

  async function signIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!supabase) return;
    setAuthBusy(true); setAuthError("");
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error) setAuthError(error.message);
    setAuthBusy(false);
  }

  async function signOut() {
    if (!supabase) return;
    const { error } = await supabase.auth.signOut();
    if (error) setAuthError(error.message);
  }

  if (supabaseConfigError) return <main className="shell"><header className="topbar"><div className="brand-mark">س</div><div><strong>سلسلة</strong><small>بنربط السوق ببعضه</small></div></header><section className="panel config-panel"><h1>إعداد اتصال قاعدة البيانات</h1><p>{supabaseConfigError}</p><p>أضف متغيري VITE_SUPABASE_URL و VITE_SUPABASE_PUBLISHABLE_KEY إلى إعدادات بيئة البناء، ثم أعد النشر.</p></section></main>;

  if (!authReady) return <main className="shell"><section className="panel"><p>جارٍ التحقق من جلسة الدخول…</p></section></main>;

  if (!session) return <main className="shell auth-shell"><header className="topbar"><div className="brand-mark">س</div><div><strong>سلسلة</strong><small>بنربط السوق ببعضه</small></div><span className="env">اتصال Supabase مباشر</span></header><form className="panel auth-panel" onSubmit={signIn}><span className="eyebrow">SILSILA ERP · SECURE SIGN IN</span><h1>تسجيل الدخول</h1><p>استخدم بريدك الإلكتروني وكلمة المرور المعتمدين في سلسلة.</p><label>البريد الإلكتروني<input type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></label><label>كلمة المرور<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label>{authError && <p className="error" role="alert">{authError}</p>}<button type="submit" disabled={authBusy}>{authBusy ? "جارٍ تسجيل الدخول…" : "دخول"}</button></form></main>;

  return <main className="shell"><header className="topbar"><div className="brand-mark">س</div><div><strong>سلسلة</strong><small>بنربط السوق ببعضه</small></div><span className="env">متصل بقاعدة البيانات · جلسة موثقة</span><button className="secondary" onClick={signOut}>تسجيل الخروج</button></header>
    <section className="intro"><div><span className="eyebrow">SILSILA ERP · LIVE DATA</span><h1>إدارة فئات الأصناف</h1><p>بيانات حقيقية مقروءة مباشرة من Supabase مع تطبيق صلاحيات قاعدة البيانات.</p></div><div className="metric"><b>{total.toLocaleString("en-US")}</b><span>فئة مطابقة</span></div></section>
    <section className="panel"><div className="toolbar"><label className="search">⌕ <input aria-label="بحث" value={query} onChange={(event) => { setQuery(event.target.value); setPage(0); }} placeholder="ابحث باسم الفئة…" /></label><select aria-label="نوع النشاط" value={activity} onChange={(event) => { setActivity(event.target.value); setPage(0); }}><option>الكل</option>{activities.map((item) => <option key={item} value={item}>{item}</option>)}</select><button type="button" onClick={() => setRefreshKey((value) => value + 1)}>تحديث</button></div>
      <div className="table-head"><span>التسلسل</span><span>اسم الفئة</span><span>الفئة الرئيسية</span><span>نوع النشاط</span><span>الحالة</span></div>
      <div className="data-list" aria-live="polite">{loading ? <p className="state">جارٍ تحميل البيانات من قاعدة البيانات…</p> : dataError ? <p className="error state" role="alert">{dataError}</p> : rows.length === 0 ? <p className="state">لا توجد فئات مطابقة.</p> : rows.map((item) => <div className="data-row" key={item.id}><code>{item.id}</code><strong>{item.name}</strong><span>{item.parent_id ? parents[item.parent_id] ?? "—" : "رئيسية"}</span><span>{item.activity_type ?? "—"}</span><span className={item.is_active ? "status-active" : "status-inactive"}>{item.is_active ? "نشط" : "غير نشط"}</span></div>)}</div>
      <footer className="table-foot"><span>{rangeLabel}</span><div className="pagination"><button className="secondary" disabled={page===0 || loading} onClick={() => setPage((value) => value - 1)}>السابق</button><span>صفحة {page + 1} من {totalPages}</span><button className="secondary" disabled={page+1>=totalPages || loading} onClick={() => setPage((value) => value + 1)}>التالي</button></div></footer>
    </section><p className="notice">مرحلة الربط الحالية: قراءة مباشرة ومصادقة حقيقية. الإضافة والتعديل والحذف متوقفة عمدًا حتى استكمال سياسات الكتابة المعتمدة ومراجعة الصلاحيات؛ لا يتم تجاوز RLS.</p></main>;
}
