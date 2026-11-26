import { useEffect, useMemo, useState } from "react";
import { BookOpen, Plus, RefreshCw, Search, ShieldCheck, Power, Database, X } from "lucide-react";
import { supabase } from "./supabase";
import EditDrawer from "./EditDrawer";

type Account = {
 id:string; company_id:string; parent_id:string|null; account_code:string; account_name:string;
 account_type:"asset"|"liability"|"equity"|"revenue"|"expense"; normal_balance:"debit"|"credit";
 is_postable:boolean; is_active:boolean; own_debit_total:number; own_credit_total:number;
 own_net_balance:number; own_movement_count:number; subtree_net_balance:number;
 descendant_account_count:number; descendant_postable_count:number;
};
const types=[{value:"asset",label:"الأصول"},{value:"liability",label:"الالتزامات"},{value:"equity",label:"حقوق الملكية"},{value:"revenue",label:"الإيرادات"},{value:"expense",label:"المصروفات"}] as const;
const typeLabel=(v:string)=>types.find(t=>t.value===v)?.label||v;
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(Number(n)||0);
const normalFor=(t:string)=>t==="asset"||t==="expense"?"debit":"credit";
const roles=["owner","admin","manager","operator","accountant"];
export default function AccountsWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId);
 const canEdit=roles.includes(role);
 const [accounts,setAccounts]=useState<Account[]>([]);
 const [query,setQuery]=useState("");
 const [typeFilter,setTypeFilter]=useState("all");
 const [statusFilter,setStatusFilter]=useState("active");
 const [showForm,setShowForm]=useState(false);
 const [name,setName]=useState("");
 const [type,setType]=useState<Account["account_type"]>("asset");
 const [parent,setParent]=useState("");
 const [normal,setNormal]=useState<"debit"|"credit">("debit");
 const [postable,setPostable]=useState(true);
 const [formOriginal,setFormOriginal]=useState({name:"",type:"asset" as Account["account_type"],parent:"",normal:"debit" as "debit"|"credit",postable:true});
 const [loading,setLoading]=useState(live);
 const [saving,setSaving]=useState(false);
 const [seeding,setSeeding]=useState(false);
 const [message,setMessage]=useState("");
 const [error,setError]=useState("");

 const load=async()=>{
  if(!live||!supabase){setLoading(false);setError("سجّل الدخول إلى المنشأة لعرض دليل الحسابات الحقيقي.");return;}
  setLoading(true);setError("");
  const {data,error}=await supabase.from("erp_account_tree_metrics")
   .select("account_id,company_id,parent_id,account_code,account_name,account_type,normal_balance,is_postable,is_active,own_debit_total,own_credit_total,own_net_balance,own_movement_count,subtree_net_balance,descendant_account_count,descendant_postable_count")
   .eq("company_id",companyId).order("account_code",{ascending:true});
  if(error){setAccounts([]);setError("تعذر تحميل دليل الحسابات: "+error.message);setLoading(false);return;}
  setAccounts((data||[]).map((a:any)=>({...a,id:a.account_id,own_debit_total:Number(a.own_debit_total)||0,own_credit_total:Number(a.own_credit_total)||0,own_net_balance:Number(a.own_net_balance)||0,own_movement_count:Number(a.own_movement_count)||0,subtree_net_balance:Number(a.subtree_net_balance)||0,descendant_account_count:Number(a.descendant_account_count)||0,descendant_postable_count:Number(a.descendant_postable_count)||0})) as Account[]);
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);

 const visible=useMemo(()=>accounts.filter(a=>
  (statusFilter==="all"||(statusFilter==="active"?a.is_active:!a.is_active))&&
  (typeFilter==="all"||a.account_type===typeFilter)&&
  [a.account_code,a.account_name,typeLabel(a.account_type)].join(" ").toLowerCase().includes(query.toLowerCase())
 ),[accounts,statusFilter,typeFilter,query]);
 const active=accounts.filter(a=>a.is_active);
 const postedMovements=accounts.reduce((s,a)=>s+a.own_movement_count,0);
 const totalDebit=accounts.reduce((s,a)=>s+a.own_debit_total,0);
 const totalCredit=accounts.reduce((s,a)=>s+a.own_credit_total,0);
 const parentOptions=active.filter(a=>a.account_type===type&&!a.is_postable);
 const resetForm=()=>{setName("");setType("asset");setParent("");setNormal("debit");setPostable(true);setShowForm(false);};
 const save=async():Promise<boolean>=>{
  if(!live||!supabase)return false;
  if(!canEdit){setMessage("صلاحيات حسابك لا تسمح بإضافة حساب.");return false;}
  if(!name.trim()){setMessage("اسم الحساب مطلوب.");return false;}
  const parentAccount=parent?accounts.find(a=>a.id===parent):null;
  if(parent&&!parentAccount){setMessage("الحساب الأب المحدد غير صالح.");return false;}
  if(parentAccount&&parentAccount.account_type!==type){setMessage("يجب أن تكون طبيعة الحساب الفرعي متوافقة مع الحساب الأب.");return false;}
  setSaving(true);setMessage("");
  const {data,error}=await supabase.from("erp_accounts").insert({
   company_id:companyId,parent_id:parent||null,account_name:name.trim(),account_type:type,
   normal_balance:normal,is_postable:postable,is_active:true
  }).select("id,account_code,account_name").single();
  setSaving(false);
  if(error){setMessage("لم يتم حفظ الحساب: "+error.message);return false;}
  setMessage("تم إنشاء الحساب بكود مركزي "+data.account_code+" وفق سياسة التكويد الحالية.");
  resetForm();await load();return true;
 };
 const seed=async()=>{
  if(!live||!supabase||!canEdit)return;
  if(!window.confirm("سيتم إنشاء شجرة الحسابات القياسية للشركة داخل قاعدة سلسلة. الحسابات الموجودة لن تُكرر. هل تريد المتابعة؟"))return;
  setSeeding(true);setMessage("");
  const {data,error}=await supabase.rpc("erp_seed_standard_chart_of_accounts",{p_company_id:companyId});
  setSeeding(false);
  if(error){setMessage("تعذر تهيئة شجرة الحسابات: "+error.message);return;}
  setMessage("اكتملت تهيئة الشجرة القياسية. الحسابات الجديدة: "+String(data??0)+".");
  await load();
 };
 const deactivate=async(a:Account)=>{
  if(!live||!supabase||!canEdit)return;
  if(a.descendant_account_count>0){setMessage("لا يمكن إيقاف حساب أب له حسابات فرعية. عالج الحسابات التابعة أولًا.");return;}
  if(a.own_movement_count>0){setMessage("هذا الحساب له حركات مرحلة؛ لا يمكن إيقافه من دليل الحسابات.");return;}
  if(!window.confirm("إيقاف الحساب "+a.account_code+" — "+a.account_name+"؟ لن تُحذف أي بيانات."))return;
  const {error}=await supabase.from("erp_accounts").update({is_active:false}).eq("id",a.id).eq("company_id",companyId);
  if(error){setMessage("تعذر إيقاف الحساب: "+error.message);return;}
  setMessage("تم إيقاف الحساب دون حذف سجلاته.");await load();
 };
 const depth=(a:Account)=>{let d=0,p=a.parent_id,guard=0;while(p&&guard++<12){const x=accounts.find(z=>z.id===p);if(!x)break;d++;p=x.parent_id;}return d;};

 return <section className="accounts-workspace" dir="rtl">
  <div className="accounts-hero"><span className="accounts-icon"><BookOpen size={22}/></span><div><small>الإدارة المالية · الدليل المحاسبي</small><h2>دليل الحسابات</h2><p>شجرة الحسابات والأرصدة المرحلة من قاعدة سلسلة، مع توليد مركزي لأكواد الحسابات.</p></div><span className="accounts-local">{live?"اتصال مباشر":"غير متصل"}</span></div>
  <div className="accounts-summary">
   <div><span>الحسابات النشطة</span><b>{active.length}</b></div>
   <div><span>الحسابات القابلة للترحيل</span><b>{active.filter(a=>a.is_postable).length}</b></div>
   <div><span>الحركات المرحلة</span><b>{postedMovements}</b></div>
   <div><span>فرق المدين والدائن</span><b>{money(totalDebit-totalCredit)} ج.م</b></div>
  </div>
  <div className="accounts-panel">
   <div className="accounts-panel-head"><div><b>شجرة الحسابات الفعلية</b><small>المصدر: erp_accounts وerp_account_tree_metrics — الأرصدة من القيود المرحلة فقط.</small></div>
    <div className="accounts-head-actions">{accounts.length===0&&live&&canEdit&&<button className="accounts-add secondary" disabled={seeding} onClick={()=>void seed()}><Database size={14}/>{seeding?"جارٍ التهيئة":"تهيئة الشجرة القياسية"}</button>}<button className="accounts-add" disabled={!canEdit||!live} onClick={()=>{if(showForm){window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}));return;}setFormOriginal({name:"",type:"asset",parent:"",normal:"debit",postable:true});setName("");setType("asset");setParent("");setNormal("debit");setPostable(true);setMessage("");setShowForm(true);}}><Plus size={15}/> إضافة حساب</button></div>
   </div>
   {showForm&&<EditDrawer title="إضافة حساب جديد" dirty={JSON.stringify({name,type,parent,normal,postable})!==JSON.stringify(formOriginal)} saving={saving} error={message} onSaveError={()=>setSaving(false)} onSave={save} onDiscard={()=>{setName(formOriginal.name);setType(formOriginal.type);setParent(formOriginal.parent);setNormal(formOriginal.normal);setPostable(formOriginal.postable);setMessage("");}} onClose={resetForm}><div className="accounts-form live-form">
    <label><span>اسم الحساب *</span><input value={name} onChange={e=>setName(e.target.value)} placeholder="اسم الحساب"/></label>
    <label><span>طبيعة الحساب</span><select value={type} onChange={e=>{const t=e.target.value as Account["account_type"];setType(t);setNormal(normalFor(t));setParent("");}}>{types.map(t=><option key={t.value} value={t.value}>{t.label}</option>)}</select></label>
    <label><span>الحساب الأب</span><select value={parent} onChange={e=>setParent(e.target.value)}><option value="">حساب رئيسي</option>{parentOptions.map(a=><option key={a.id} value={a.id}>{a.account_code} · {a.account_name}</option>)}</select></label>
    <label><span>الرصيد الطبيعي</span><select value={normal} onChange={e=>setNormal(e.target.value as "debit"|"credit")}><option value="debit">مدين</option><option value="credit">دائن</option></select></label>
    <label><span>قابل للترحيل</span><select value={postable?"yes":"no"} onChange={e=>setPostable(e.target.value==="yes")}><option value="yes">نعم — حساب حركة</option><option value="no">لا — حساب تجميعي</option></select></label>
    <div className="accounts-form-actions"><button disabled={saving} onClick={()=>window.dispatchEvent(new Event("silsila:edit-save"))}>{saving?"جارٍ الحفظ":"حفظ الحساب وتوليد الكود"}</button><button className="cancel" onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))}><X size={13}/> إلغاء</button></div>
    <small className="accounts-code-note">كود الحساب لا يُكتب يدويًا؛ يتم توليده تلقائيًا من سياسة التكويد المركزية في قاعدة البيانات.</small>
   </div></EditDrawer>}
   <div className="accounts-filters"><div><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث بالكود أو اسم الحساب"/></div>
    <select value={typeFilter} onChange={e=>setTypeFilter(e.target.value)}><option value="all">كل أنواع الحسابات</option>{types.map(t=><option key={t.value} value={t.value}>{t.label}</option>)}</select>
    <select value={statusFilter} onChange={e=>setStatusFilter(e.target.value)}><option value="active">النشطة</option><option value="inactive">الموقوفة</option><option value="all">الكل</option></select>
    <button onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button>
   </div>
   {error&&<div className="accounts-message">{error}</div>}
   <div className="accounts-table-scroll"><table><thead><tr><th>كود الحساب</th><th>اسم الحساب</th><th>النوع</th><th>الرصيد الطبيعي</th><th>مدين</th><th>دائن</th><th>صافي الحركة</th><th>الطبيعة</th><th>الحالة / الإجراء</th></tr></thead><tbody>
    {visible.map(a=><tr key={a.id}><td className="accounts-code">{a.account_code}</td><td><span style={{paddingRight:depth(a)*16}}><b>{a.account_name}</b></span></td><td>{typeLabel(a.account_type)}</td><td>{a.normal_balance==="debit"?"مدين":"دائن"}</td><td>{money(a.own_debit_total)}</td><td>{money(a.own_credit_total)}</td><td className="accounts-balance">{money(a.own_net_balance)}</td><td>{a.is_postable?"حساب حركة":"حساب تجميعي"}</td><td>{a.is_active?<span className="accounts-protected"><ShieldCheck size={13}/> نشط</span>:<span className="accounts-lock">موقوف</span>}{a.is_active&&canEdit&&<button className="accounts-delete" title="إيقاف دون حذف" onClick={()=>void deactivate(a)}><Power size={14}/></button>}</td></tr>)}
    {!visible.length&&<tr><td colSpan={9} className="accounts-empty">{loading?"جارٍ تحميل دليل الحسابات...":error?"تعذر عرض البيانات":"لا توجد حسابات مطابقة في قاعدة الشركة."}</td></tr>}
   </tbody></table></div>
  </div>
  {message&&<div className="accounts-message" role="status">{message}</div>}
  <div className="accounts-note"><ShieldCheck size={15}/> الحسابات والحركات لا تُحذف من هذه الشاشة. أكواد الحسابات تُولّد مركزيًا، وصلاحيات الحفظ والإيقاف محكومة بسياسات RLS في قاعدة سلسلة.</div>
 </section>;
}
