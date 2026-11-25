import { useEffect, useState, type ReactNode, type FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { ArrowLeft, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck, Building2 } from "lucide-react";
import { isSupabaseConfigured, supabase } from "./supabase";
import SILSILA_LOGO from "./brand";

type Company = { id: string; name: string; role: string };
type ActivityOption = { code: string; name: string };
const userTypeIcons: Record<string, string> = {
  "مورد": "▣", "عميل": "▤", "مندوب": "♙", "شركة شحن": "⇢", "ادمن": "✦", "أدمن": "✦",
};

export default function AuthGate({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [companyId, setCompanyId] = useState("");
  const [preview, setPreview] = useState(false);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [message, setMessage] = useState("");
  const [activities, setActivities] = useState<ActivityOption[]>([]);
  const [activity, setActivity] = useState("");
  const [userTypes, setUserTypes] = useState<string[]>([]);
  const [accountType, setAccountType] = useState("");
  const [activityUserType, setActivityUserType] = useState("مستخدم رئيسي للنشاط");

  const loadCompanies = async (current: Session) => {
    const client = supabase;
    if (!client) return false;
    setBusy(true);
    const { data: memberships, error } = await client
      .from("erp_company_members")
      .select("company_id,member_role")
      .eq("user_id", current.user.id)
      .eq("is_active", true);
    if (error) {
      setMessage("تعذر تحميل عضوية المنشأة: " + error.message);
      setBusy(false);
      return false;
    }
    const ids = [...new Set((memberships || []).map((m: any) => m.company_id))];
    if (!ids.length) {
      setMessage("تم التحقق من الحساب، لكنه غير مرتبط بعضوية نشطة في منشأة ERP.");
      setBusy(false);
      return false;
    }
    const { data: orgs, error: orgError } = await client
      .from("erp_companies")
      .select("id,legal_name,trade_name")
      .in("id", ids);
    if (orgError) {
      setMessage("تعذر تحميل بيانات المنشأة: " + orgError.message);
      setBusy(false);
      return false;
    }
    const choices = (orgs || []).map((org: any) => ({
      id: org.id,
      name: org.trade_name || org.legal_name,
      role: (memberships || []).find((m: any) => m.company_id === org.id)?.member_role || "viewer",
    }));
    setCompanies(choices);
    const chosen = choices.find((c) => c.id === companyId) || choices[0];
    setCompanyId(chosen.id);
    sessionStorage.setItem("silsila-company-id", chosen.id);
    sessionStorage.setItem("silsila-user-id", current.user.id);
    sessionStorage.setItem("silsila-member-role", chosen.role);
    sessionStorage.removeItem("silsila-preview-mode");
    setBusy(false);
    return true;
  };

  useEffect(() => {
    const client = supabase;
    if (!client) {
      setPreview(sessionStorage.getItem("silsila-preview-mode") === "true");
      setReady(true);
      return;
    }
    let alive = true;
    client.auth.getSession().then(async ({ data, error }) => {
      if (!alive) return;
      if (error) setMessage(error.message);
      if (data.session) {
        setSession(data.session);
        const ok = await loadCompanies(data.session);
        if (!alive) return;
        if (!ok) await client.auth.signOut();
      } else {
        setPreview(sessionStorage.getItem("silsila-preview-mode") === "true");
      }
      setReady(true);
    }).catch((error) => {
      if (alive) {
        setMessage(error instanceof Error ? error.message : "تعذر استعادة جلسة الدخول.");
        setReady(true);
      }
    });
    return () => { alive = false; };
  }, []);

  const signIn = async (event: FormEvent) => {
    event.preventDefault();
    const client = supabase;
    if (!client || !isSupabaseConfigured) {
      setMessage("إعداد اتصال Supabase غير مكتمل في بيئة النشر.");
      return;
    }
    setBusy(true);
    setMessage("");
    const { data, error } = await client.auth.signInWithPassword({ email: email.trim(), password });
    if (error || !data.session) {
      setMessage("تعذر تسجيل الدخول: " + (error?.message || "لم يتم إنشاء جلسة."));
      setBusy(false);
      return;
    }
    setSession(data.session);
    const ok = await loadCompanies(data.session);
    if (!ok) {
      await client.auth.signOut();
      setSession(null);
    }
  };

  const resetPassword = async () => {
    const client = supabase;
    if (!client || !email.trim()) {
      setMessage("اكتب البريد الإلكتروني أولاً.");
      return;
    }
    setBusy(true);
    const { error } = await client.auth.resetPasswordForEmail(email.trim(), { redirectTo: window.location.origin });
    setMessage(error ? "تعذر إرسال الرابط: " + error.message : "إذا كان البريد مسجلاً، فسيصلك رابط استعادة كلمة المرور.");
    setBusy(false);
  };

  const signOut = async () => {
    await supabase?.auth.signOut();
    sessionStorage.removeItem("silsila-company-id");
    sessionStorage.removeItem("silsila-user-id");
    sessionStorage.removeItem("silsila-member-role");
    sessionStorage.removeItem("silsila-preview-mode");
    setSession(null);
    setCompanies([]);
    setCompanyId("");
    setPreview(false);
    setPassword("");
  };

  const enterPreview = () => {
    sessionStorage.setItem("silsila-preview-mode", "true");
    setPreview(true);
    setMessage("");
  };

  if (!ready || busy && !session && !preview) {
    return <div className="login-screen" dir="rtl"><div className="login-form-heading"><h2>سلسلة</h2><p>جارٍ تجهيز مساحة العمل الآمنة...</p></div></div>;
  }

  if (session && companies.length > 0) {
    const selected = companies.find((c) => c.id === companyId) || companies[0];
    return <><div key={selected.id}>{children}</div><div style={{position:"fixed",left:16,bottom:14,zIndex:1000,display:"flex",alignItems:"center",gap:10,padding:"9px 13px",borderRadius:14,background:"#241735",color:"#fff",boxShadow:"0 8px 28px #160b2b55",fontSize:12}}>
      <ShieldCheck size={16}/><span>{selected.name} · {selected.role}</span>
      {companies.length > 1 && <select aria-label="اختيار المنشأة" value={companyId} onChange={(e)=>{const c=companies.find(x=>x.id===e.target.value);if(c){setCompanyId(c.id);sessionStorage.setItem("silsila-company-id",c.id);sessionStorage.setItem("silsila-member-role",c.role);}}} style={{maxWidth:150}}>{companies.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select>}

    </div></>;
  }

  if (preview) return <>{children}<div style={{position:"fixed",left:16,bottom:14,zIndex:1000,display:"flex",alignItems:"center",gap:10,padding:"9px 13px",borderRadius:14,background:"#4b2a6b",color:"#fff",fontSize:12}}><Eye size={15}/> معاينة محلية فقط <button onClick={()=>{sessionStorage.removeItem("silsila-preview-mode");setPreview(false);}} style={{color:"#fff",background:"transparent",border:0,cursor:"pointer"}}>إنهاء المعاينة</button></div></>;

  return <div className="login-screen" dir="rtl">
    <div className="login-frame">
      <header className="login-frame-header">
        <img src={SILSILA_LOGO} alt="شعار سلسلة" />
        <div className="login-frame-brand"><b>سلسلة</b><span>منظومة إدارة الأعمال المتكاملة</span></div>
        <strong className="login-frame-slogan">سلسلة .. بنربط السوق ببعضه</strong>
      </header>
      <div className="login-layout">
      <section className="login-brand-panel">
        <div className="login-brand-art"><img src={SILSILA_LOGO} alt="شعار سلسلة" /></div>
        <div className="login-brand-copy"><span className="login-eyebrow"><ShieldCheck size={14}/> اتصال آمن بقاعدة بيانات المنشأة</span><h1>تجارتك اليومية<br/><em>تبدأ من هنا</em></h1><p>سجّل الدخول للوصول إلى بيانات منشأتك المشتركة، وفق عضويتك وصلاحياتك.</p></div>
        <div className="login-brand-footer">سلسلة .. بنربط السوق ببعضه</div>
      </section>
      <section className="login-form-panel">
        <div className="login-mobile-brand"><div className="login-brand-mark"><img src={SILSILA_LOGO} alt="شعار سلسلة"/></div><b>سلسلة</b></div>
        <div className="login-form-heading"><span>مرحبًا بعودتك</span><h2>تسجيل الدخول</h2><p>استخدم حسابك المسجل في سلسلة.</p></div>
        <form className="login-form" onSubmit={signIn}>
          <label className="login-select-label"><span>نوع النشاط</span><select aria-label="نوع النشاط" value={activity} onChange={(e)=>setActivity(e.target.value)} disabled={!activities.length}><option value="">{activities.length ? "اختر النشاط" : "لا توجد أنشطة متاحة"}</option>{activities.map((item)=><option key={item.code} value={item.code}>{item.name}</option>)}</select></label>
          <div className="login-choice-block">
            <span className="login-choice-title">اختار طريقة دخولك</span>
            {userTypes.length ? <div className="login-user-type-options">{userTypes.map((type)=><button type="button" key={type} className={accountType===type?"selected":""} aria-pressed={accountType===type} onClick={()=>setAccountType(type)}><span>{userTypeIcons[type] || "♙"}</span>{type}</button>)}</div> : <p className="login-catalog-empty">لا توجد أنواع مستخدمين نشطة ومسموح بظهورها في التطبيق.</p>}
          </div>
          <div className="login-activity-user">
            <span className="login-choice-title">تسجيل دخول النشاط</span>
            <div className="login-segmented" role="group" aria-label="نوع مستخدم النشاط">
              <button type="button" className={activityUserType==="مستخدم رئيسي للنشاط"?"selected":""} aria-pressed={activityUserType==="مستخدم رئيسي للنشاط"} onClick={()=>setActivityUserType("مستخدم رئيسي للنشاط")}>مستخدم رئيسي</button>
              <button type="button" className={activityUserType==="مستخدم فرعي للنشاط"?"selected":""} aria-pressed={activityUserType==="مستخدم فرعي للنشاط"} onClick={()=>setActivityUserType("مستخدم فرعي للنشاط")}>مستخدم فرعي</button>
            </div>
          </div>
          <label><span>البريد الإلكتروني</span><div className="login-input-wrap"><Mail size={17}/><input type="email" autoComplete="username" value={email} onChange={e=>setEmail(e.target.value)} placeholder="name@company.com" required/></div></label>
          <label><span>كلمة المرور</span><div className="login-input-wrap"><LockKeyhole size={17}/><input type={showPassword?"text":"password"} autoComplete="current-password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="أدخل كلمة المرور" required/><button type="button" onClick={()=>setShowPassword(!showPassword)} aria-label="إظهار أو إخفاء كلمة المرور">{showPassword?<EyeOff size={17}/>:<Eye size={17}/>}</button></div></label>
          <div className="login-form-meta"><span></span><button type="button" onClick={resetPassword}>نسيت كلمة المرور؟</button></div>
          <button className="login-submit" type="submit" disabled={busy}>{busy?"جارٍ التحقق...":"تسجيل الدخول"} <ArrowLeft size={17}/></button>
          {message&&<div className="login-message" role="status">{message}</div>}
        </form>
        <div className="login-preview-access"><div><b>استكشاف التصميم أولاً</b><span>لن يتم الاتصال ببيانات الإنتاج في وضع المعاينة.</span></div><button type="button" onClick={enterPreview}>دخول المعاينة <ArrowLeft size={15}/></button></div>
        <div className="login-security-note"><Building2 size={15}/> صلاحيات المنشأة تُطبّق من قاعدة البيانات</div>
        <footer>© 2026 سلسلة · جميع الحقوق محفوظة</footer>
      </section>
      </div>
      <footer className="login-frame-footer"><span>© 2026 سلسلة · جميع الحقوق محفوظة</span><strong>سلسلة .. بنربط السوق ببعضه</strong></footer>
    </div>
  </div>;
}
