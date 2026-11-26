import { createContext, useContext, useEffect, useState, type ReactNode, type FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { ArrowLeft, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck, Building2 } from "lucide-react";
import { isSupabaseConfigured, supabase } from "./supabase";
import SILSILA_LOGO from "./brand";

type Company = { id: string; name: string; role: string };
type AuthContextValue = { signOut: () => Promise<boolean>; preview: boolean };
const AuthContext = createContext<AuthContextValue | null>(null);
export const useAuth = () => useContext(AuthContext);
type ActivityOption = { code: string; name: string };
const userTypeIcons: Record<string, string> = {
  "مورد": "▣", "عميل": "▤", "مندوب": "♙", "شركة شحن": "⇢", "ادمن": "✦", "أدمن": "✦",
};

export default function AuthGate({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [companyId, setCompanyId] = useState("");
  const [preview, setPreview] = useState(false);
  const [editDirty, setEditDirty] = useState(false);
  const [pendingCompanyId, setPendingCompanyId] = useState("");
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState(() => { try { return localStorage.getItem("silsila-login-email") || ""; } catch { return ""; } });
  const [rememberMe, setRememberMe] = useState(() => { try { return localStorage.getItem("silsila-remember-login") === "true"; } catch { return false; } });
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [message, setMessage] = useState("");
  const [activities, setActivities] = useState<ActivityOption[]>([]);
  const [activity, setActivity] = useState("");
  const [userTypes, setUserTypes] = useState<string[]>([]);
  const [accountType, setAccountType] = useState("إدارة نشاط");
  const [activityUserType, setActivityUserType] = useState("مستخدم رئيسي للنشاط");
  const [registerMode, setRegisterMode] = useState<"user" | "activity" | null>(null);
  const [registerBusy, setRegisterBusy] = useState(false);
  const [registerError, setRegisterError] = useState("");
  const [registerName, setRegisterName] = useState("");
  const [registerEmail, setRegisterEmail] = useState("");
  const [registerPhone, setRegisterPhone] = useState("");
  const [registerPassword, setRegisterPassword] = useState("");
  const [registerConfirm, setRegisterConfirm] = useState("");
  const [registerActivity, setRegisterActivity] = useState("");
  const [registerAccountType, setRegisterAccountType] = useState("");
  const [showRegisterPassword, setShowRegisterPassword] = useState(false);
  const [showRegisterConfirm, setShowRegisterConfirm] = useState(false);

  useEffect(() => {
    const client = supabase;
    if (!client) return;
    let alive = true;
    const loadLoginCatalogs = async () => {
      const [activityResult, userTypeResult] = await Promise.all([
        client.from("activity_types").select("id,code,name,name_en,sort_order,is_active,show_in_app").eq("is_active", true).eq("show_in_app", true).order("sort_order", { ascending: true }),
        client.from("erp_user_types").select("name_ar,name_en,type_code").eq("is_active", true).eq("show_at_login", true).order("type_code", { ascending: true }),
      ]);
      if (!alive) return;
      if (!activityResult.error) {
        const rows = (activityResult.data || []).map((row: any) => ({ code: String(row.code || "").trim(), name: String(row.name || "").trim() })).filter((row: ActivityOption) => row.code && row.name);
        setActivities(rows);
        if (rows.length && !rows.some((row: ActivityOption) => row.code === activity)) setActivity(rows[0].code);
      }
      if (!userTypeResult.error) {
        const names = [...new Set((userTypeResult.data || []).map((row: any) => String(row.name_ar || "").trim()).filter(Boolean))] as string[];
        setUserTypes(names);
        if (names.length && !names.includes(accountType)) setAccountType(names[0]);
      }
    };
    void loadLoginCatalogs();
    return () => { alive = false; };
  }, []);

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
    const metadata = current.user.user_metadata || {};
    const profileName = String(metadata.full_name || metadata.name || metadata.display_name || "").trim();
    if (profileName) sessionStorage.setItem("silsila-user-name", profileName);
    else sessionStorage.removeItem("silsila-user-name");
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
    try {
      if (rememberMe) { localStorage.setItem("silsila-login-email", email.trim()); localStorage.setItem("silsila-remember-login", "true"); }
      else { localStorage.removeItem("silsila-login-email"); localStorage.removeItem("silsila-remember-login"); }
      const { data, error } = await client.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
      if (error || !data.session) throw error || new Error("لم يتم إنشاء جلسة دخول.");
      setSession(data.session);
      const ok = await loadCompanies(data.session);
      if (!ok) {
        await client.auth.signOut();
        setSession(null);
      }
    } catch (error) {
      setMessage("تعذر تسجيل الدخول: " + (error instanceof Error ? error.message : "تحقق من البريد الإلكتروني وكلمة المرور."));
    } finally {
      setBusy(false);
    }
  };

  const normalizePhone = (value: string) => {
    const digits = value.replace(/[٠-٩۰-۹]/g, (digit) => String.fromCharCode(48 + (digit.charCodeAt(0) >= 0x0660 && digit.charCodeAt(0) <= 0x0669 ? digit.charCodeAt(0) - 0x0660 : digit.charCodeAt(0) - 0x06f0))).replace(/[^0-9+]/g, "");
    if (digits.startsWith("+")) return digits;
    if (digits.startsWith("00")) return "+" + digits.slice(2);
    if (digits.startsWith("20")) return "+" + digits;
    if (digits.startsWith("0") && digits.length >= 10) return "+20" + digits.slice(1);
    return "+" + digits;
  };

  const openRegistration = (mode: "user" | "activity") => {
    setRegisterMode(mode);
    setRegisterError("");
    setRegisterName("");
    setRegisterEmail("");
    setRegisterPhone("");
    setRegisterPassword("");
    setRegisterConfirm("");
    setRegisterActivity(activity || activities[0]?.code || "");
    setRegisterAccountType(mode === "activity" ? "إدارة نشاط" : (userTypes.includes(accountType) ? accountType : userTypes[0] || ""));
  };

  const register = async (event: FormEvent) => {
    event.preventDefault();
    const client = supabase;
    if (!client || !isSupabaseConfigured) { setRegisterError("إعداد اتصال Supabase غير مكتمل."); return; }
    if (!registerMode) return;
    const phoneDigits = registerPhone.replace(/[^0-9٠-٩۰-۹]/g, "");
    if (!registerName.trim()) { setRegisterError("اكتب اسم النشاط التجاري أو صاحب الحساب."); return; }
    if (!registerEmail.trim().includes("@") || !registerEmail.trim().includes(".")) { setRegisterError("أدخل بريدًا إلكترونيًا صحيحًا."); return; }
    if (!registerActivity) { setRegisterError("اختر نوع النشاط."); return; }
    if (phoneDigits.length < 10 || phoneDigits.length > 15) { setRegisterError("أدخل رقم هاتف صحيحًا من 10 إلى 15 رقمًا."); return; }
    if (registerPassword.length < 8 || !/[A-Z]/.test(registerPassword) || !/[a-z]/.test(registerPassword) || !/[0-9]/.test(registerPassword) || !/[^A-Za-z0-9]/.test(registerPassword)) {
      setRegisterError("كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، وحرف كبير وصغير ورقم ورمز.");
      return;
    }
    if (registerPassword !== registerConfirm) { setRegisterError("كلمتا المرور غير متطابقتين."); return; }
    setRegisterBusy(true);
    setRegisterError("");
    try {
      const { data, error } = await client.auth.signUp({
        email: registerEmail.trim().toLowerCase(),
        password: registerPassword,
        options: { data: {
          full_name: registerName.trim(),
          contact_phone: normalizePhone(registerPhone),
          account_type: registerMode === "activity" ? "إدارة نشاط" : registerAccountType,
          activity_type: registerActivity,
          activity_user_type: registerMode === "activity" ? "مستخدم رئيسي للنشاط" : activityUserType,
        } },
      });
      if (error) throw error;
      if (!data.user) throw new Error("لم يتم إنشاء الحساب.");
      if (data.session) {
        setRegisterMode(null);
        setSession(data.session);
        const ok = await loadCompanies(data.session);
        if (!ok) {
          await client.auth.signOut();
          setSession(null);
          setMessage("تم إنشاء الحساب، لكن لا توجد عضوية منشأة نشطة مرتبطة به. راجع ربط الحساب بالمنشأة قبل تسجيل الدخول.");
        }
      } else {
        setRegisterMode(null);
        setMessage("تم إنشاء الحساب. راجع بريدك الإلكتروني لتأكيد الحساب قبل تسجيل الدخول.");
      }
    } catch (error) {
      setRegisterError(error instanceof Error ? error.message : "تعذر إنشاء الحساب. حاول مرة أخرى.");
    } finally {
      setRegisterBusy(false);
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

  const applyCompany = (id: string) => {
    const company = companies.find((item) => item.id === id);
    if (!company) return;
    setCompanyId(company.id);
    sessionStorage.setItem("silsila-company-id", company.id);
    sessionStorage.setItem("silsila-member-role", company.role);
  };
  const requestCompanyChange = (id: string) => {
    if (id === companyId) return;
    if (editDirty) {
      setPendingCompanyId(id);
      window.dispatchEvent(new Event("silsila:edit-request-close"));
    } else applyCompany(id);
  };
  useEffect(() => {
    const editState = (event: Event) => setEditDirty(Boolean((event as CustomEvent<{dirty?:boolean}>).detail?.dirty));
    const editClosed = () => setEditDirty(false);
    const editCancelled = () => setPendingCompanyId("");
    window.addEventListener("silsila:edit-state", editState);
    window.addEventListener("silsila:edit-closed", editClosed);
    window.addEventListener("silsila:edit-navigation-cancel", editCancelled);
    return () => {
      window.removeEventListener("silsila:edit-state", editState);
      window.removeEventListener("silsila:edit-closed", editClosed);
      window.removeEventListener("silsila:edit-navigation-cancel", editCancelled);
    };
  }, [companies]);
  useEffect(() => {
    if (!editDirty && pendingCompanyId) {
      applyCompany(pendingCompanyId);
      setPendingCompanyId("");
    }
  }, [editDirty, pendingCompanyId, companies]);
  const signOut = async (): Promise<boolean> => {
    if (supabase) {
      const { error } = await supabase.auth.signOut();
      if (error) { setMessage("تعذر تسجيل الخروج: " + error.message); return false; }
    }
    setMessage("");
    sessionStorage.removeItem("silsila-company-id");
    sessionStorage.removeItem("silsila-user-id");
    sessionStorage.removeItem("silsila-user-name");
    sessionStorage.removeItem("silsila-member-role");
    sessionStorage.removeItem("silsila-preview-mode");
    setSession(null);
    setCompanies([]);
    setCompanyId("");
    setPreview(false);
    setPassword("");
    return true;
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
    return <AuthContext.Provider value={{signOut,preview:false}}><div key={selected.id}>{children}</div>{message&&<div role="alert" style={{position:"fixed",right:18,top:18,zIndex:1400,maxWidth:420,padding:"11px 14px",borderRadius:10,background:"#fff1ef",color:"#a33a31",boxShadow:"0 8px 28px #160b2b30",fontSize:12}}>{message}</div>}<div style={{position:"fixed",left:16,bottom:14,zIndex:1000,display:"flex",alignItems:"center",gap:10,padding:"9px 13px",borderRadius:14,background:"#241735",color:"#fff",boxShadow:"0 8px 28px #160b2b55",fontSize:12}}>
      <ShieldCheck size={16}/><span>{selected.name} · {selected.role}</span>
      {companies.length > 1 && <select aria-label="اختيار المنشأة" value={companyId} onChange={(e)=>requestCompanyChange(e.target.value)} style={{maxWidth:150}}>{companies.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select>}

    </div></AuthContext.Provider>;
  }

  if (preview) return <AuthContext.Provider value={{signOut,preview:true}}>{children}<div style={{position:"fixed",left:16,bottom:14,zIndex:1000,display:"flex",alignItems:"center",gap:10,padding:"9px 13px",borderRadius:14,background:"#4b2a6b",color:"#fff",fontSize:12}}><Eye size={15}/> معاينة محلية فقط <button onClick={()=>{sessionStorage.removeItem("silsila-preview-mode");setPreview(false);}} style={{color:"#fff",background:"transparent",border:0,cursor:"pointer"}}>إنهاء المعاينة</button></div></AuthContext.Provider>;

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
          <div className="login-form-meta"><label className="login-remember"><input type="checkbox" checked={rememberMe} onChange={(e)=>setRememberMe(e.target.checked)}/> تذكرني</label><button type="button" onClick={resetPassword}>نسيت كلمة المرور؟</button></div>
          <button className="login-submit" type="submit" disabled={busy}>{busy?"جارٍ التحقق...":"تسجيل الدخول"} <ArrowLeft size={17}/></button>
          {message&&<div className="login-message" role="status">{message}</div>}
        </form>
        <div className="login-registration-actions">
          <button type="button" onClick={() => openRegistration("user")}>إنشاء مستخدم جديد</button>
          <button type="button" onClick={() => openRegistration("activity")}>تسجيل حساب نشاط</button>
        </div>
        <div className="login-preview-access"><div><b>استكشاف التصميم أولاً</b><span>لن يتم الاتصال ببيانات الإنتاج في وضع المعاينة.</span></div><button type="button" onClick={enterPreview}>دخول المعاينة <ArrowLeft size={15}/></button></div>
        <div className="login-security-note"><Building2 size={15}/> صلاحيات المنشأة تُطبّق من قاعدة البيانات</div>
        <footer>© 2026 سلسلة · جميع الحقوق محفوظة</footer>
      </section>
      </div>
      {registerMode && <div role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !registerBusy) setRegisterMode(null); }} style={{position:"fixed",inset:0,zIndex:2000,background:"#160b28a8",display:"grid",placeItems:"center",padding:16}}>
        <form onSubmit={register} dir="rtl" style={{width:"min(100%,520px)",maxHeight:"90vh",overflowY:"auto",background:"#fff",borderRadius:20,padding:22,boxShadow:"0 24px 80px #12051f66",display:"grid",gap:12}}>
          <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",gap:12}}><div><span style={{fontSize:11,color:"#8b55b4"}}>سلسلة · تسجيل آمن</span><h2 style={{margin:"4px 0",fontSize:21,color:"#3E007D"}}>{registerMode === "activity" ? "تسجيل حساب نشاط" : "إنشاء مستخدم جديد"}</h2></div><button type="button" disabled={registerBusy} onClick={()=>setRegisterMode(null)} aria-label="إغلاق" style={{background:"#f5effb",color:"#3E007D",borderRadius:9,width:34,height:34}}>×</button></div>
          <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>اسم النشاط التجاري / صاحب الحساب<input value={registerName} onChange={e=>setRegisterName(e.target.value)} required autoComplete="name" style={{height:42,border:"1px solid #e4d9ed",borderRadius:9,padding:"0 11px",font: "inherit"}}/></label>
          <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>البريد الإلكتروني<input type="email" value={registerEmail} onChange={e=>setRegisterEmail(e.target.value)} required autoComplete="email" style={{height:42,border:"1px solid #e4d9ed",borderRadius:9,padding:"0 11px",font:"inherit"}}/></label>
          <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>نوع النشاط<select value={registerActivity} onChange={e=>setRegisterActivity(e.target.value)} required style={{height:42,border:"1px solid #e4d9ed",borderRadius:9,padding:"0 11px",font:"inherit"}}><option value="">اختر النشاط</option>{activities.map(item=><option key={item.code} value={item.code}>{item.name}</option>)}</select></label>
          {registerMode === "user" && <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>نوع الحساب<select value={registerAccountType} onChange={e=>setRegisterAccountType(e.target.value)} required style={{height:42,border:"1px solid #e4d9ed",borderRadius:9,padding:"0 11px",font:"inherit"}}><option value="">اختر نوع الحساب</option>{userTypes.map(type=><option key={type} value={type}>{type}</option>)}</select></label>}
          <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>رقم الهاتف<input type="tel" value={registerPhone} onChange={e=>setRegisterPhone(e.target.value)} required autoComplete="tel" style={{height:42,border:"1px solid #e4d9ed",borderRadius:9,padding:"0 11px",font:"inherit"}}/></label>
          <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>كلمة المرور<div style={{display:"flex",border:"1px solid #e4d9ed",borderRadius:9,alignItems:"center",paddingInline:10}}><input type={showRegisterPassword?"text":"password"} value={registerPassword} onChange={e=>setRegisterPassword(e.target.value)} required autoComplete="new-password" style={{height:42,border:0,outline:0,flex:1,minWidth:0,font:"inherit"}}/><button type="button" onClick={()=>setShowRegisterPassword(v=>!v)} aria-label="إظهار كلمة المرور" style={{background:"transparent",color:"#7442a0"}}>{showRegisterPassword?<EyeOff size={17}/>:<Eye size={17}/>}</button></div><small style={{color:"#93859f"}}>8 أحرف على الأقل، حرف كبير وصغير ورقم ورمز</small></label>
          <label style={{display:"grid",gap:5,fontSize:12,color:"#51415f"}}>تأكيد كلمة المرور<div style={{display:"flex",border:"1px solid #e4d9ed",borderRadius:9,alignItems:"center",paddingInline:10}}><input type={showRegisterConfirm?"text":"password"} value={registerConfirm} onChange={e=>setRegisterConfirm(e.target.value)} required autoComplete="new-password" style={{height:42,border:0,outline:0,flex:1,minWidth:0,font:"inherit"}}/><button type="button" onClick={()=>setShowRegisterConfirm(v=>!v)} aria-label="إظهار تأكيد كلمة المرور" style={{background:"transparent",color:"#7442a0"}}>{showRegisterConfirm?<EyeOff size={17}/>:<Eye size={17}/>}</button></div></label>
          {registerError && <div role="alert" style={{background:"#fff0ef",color:"#a33a31",borderRadius:9,padding:10,fontSize:12,lineHeight:1.7}}>{registerError}</div>}
          <div style={{display:"flex",gap:9}}><button type="button" disabled={registerBusy} onClick={()=>setRegisterMode(null)} style={{height:43,flex:1,borderRadius:9,background:"#f5effb",color:"#3E007D"}}>إلغاء</button><button type="submit" disabled={registerBusy} style={{height:43,flex:1,borderRadius:9,background:"#3E007D",color:"#fff",fontWeight:800}}>{registerBusy?"جارٍ إنشاء الحساب...":"إنشاء الحساب"}</button></div>
        </form>
      </div>}
      <footer className="login-frame-footer"><span>© 2026 سلسلة · جميع الحقوق محفوظة</span><strong>سلسلة .. بنربط السوق ببعضه</strong></footer>
    </div>
  </div>;
}
