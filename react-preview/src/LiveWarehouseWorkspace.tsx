import {useEffect,useMemo,useState} from "react";
import {supabase} from "./supabase";
import {Building2,Plus,RefreshCw,Search,Save,Pencil,Power,Boxes,MapPin,Phone,X} from "lucide-react";

type Branch={id:string;branch_code:string;branch_name:string;is_active:boolean};
type Warehouse={id:string;branch_id:string;warehouse_code:string;warehouse_name:string;warehouse_name_en:string|null;address:string|null;location:string|null;phone:string|null;is_active:boolean};
type FormState={id:string;branch_id:string;warehouse_code:string;warehouse_name:string;warehouse_name_en:string;address:string;location:string;phone:string};
const empty=():FormState=>({id:"",branch_id:"",warehouse_code:"",warehouse_name:"",warehouse_name_en:"",address:"",location:"",phone:""});
export default function LiveWarehouseWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"",role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId),canEdit=["owner","admin","manager","operator","accountant"].includes(role);
 const [rows,setRows]=useState<Warehouse[]>([]),[branches,setBranches]=useState<Branch[]>([]),[balances,setBalances]=useState<{warehouse_id:string;quantity_on_hand:number;inventory_value:number}[]>([]);
 const [form,setForm]=useState<FormState>(empty()),[editing,setEditing]=useState(false),[showForm,setShowForm]=useState(false);
 const [query,setQuery]=useState(""),[loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[error,setError]=useState(""),[message,setMessage]=useState("");
 const load=async()=>{
  if(!supabase||!companyId){setLoading(false);setError("سجّل الدخول إلى المنشأة لعرض المخازن الفعلية.");return;}
  setLoading(true);setError("");
  const [w,b,s]=await Promise.all([
   supabase.from("erp_warehouses").select("id,branch_id,warehouse_code,warehouse_name,warehouse_name_en,address,location,phone,is_active").eq("company_id",companyId).order("warehouse_code").limit(500),
   supabase.from("erp_branches").select("id,branch_code,branch_name,is_active").eq("company_id",companyId).order("branch_code"),
   supabase.from("erp_stock_balances").select("warehouse_id,quantity_on_hand,inventory_value").eq("company_id",companyId)
  ]);
  const e=w.error||b.error||s.error;if(e){setError("تعذر تحميل سجل المخازن: "+e.message);setRows([]);}else{setRows((w.data||[]) as Warehouse[]);setBranches((b.data||[]) as Branch[]);setBalances((s.data||[]) as any[]);}
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId]);
 const filtered=useMemo(()=>rows.filter(r=>[r.warehouse_code,r.warehouse_name,r.warehouse_name_en||"",branches.find(b=>b.id===r.branch_id)?.branch_name||"",r.address||"",r.location||""].join(" ").toLowerCase().includes(query.toLowerCase())),[rows,branches,query]);
 const stats=useMemo(()=>({active:rows.filter(r=>r.is_active).length,balanceRows:balances.length,value:balances.reduce((n,r)=>n+Number(r.inventory_value||0),0)}),[rows,balances]);
 const startNew=()=>{setForm({...empty(),branch_id:branches[0]?.id||""});setEditing(false);setShowForm(true);setMessage("");};
 const startEdit=(r:Warehouse)=>{setForm({id:r.id,branch_id:r.branch_id||"",warehouse_code:r.warehouse_code,warehouse_name:r.warehouse_name,warehouse_name_en:r.warehouse_name_en||"",address:r.address||"",location:r.location||"",phone:r.phone||""});setEditing(true);setShowForm(true);setMessage("");};
 const save=async()=>{
  if(!supabase||!live)return;
  if(!canEdit){setError("لا تملك صلاحية تعديل بيانات المخازن.");return;}
  if(!form.branch_id||!form.warehouse_code.trim()||!form.warehouse_name.trim()){setError("اختر الفرع وأدخل كود المخزن واسمه.");return;}
  setSaving(true);setError("");setMessage("");
  const payload={company_id:companyId,branch_id:form.branch_id,warehouse_code:form.warehouse_code.trim(),warehouse_name:form.warehouse_name.trim(),warehouse_name_en:form.warehouse_name_en.trim()||null,address:form.address.trim()||null,location:form.location.trim()||null,phone:form.phone.trim()||null,updated_at:new Date().toISOString()};
  const result=editing?await supabase.from("erp_warehouses").update(payload).eq("company_id",companyId).eq("id",form.id).select("id").maybeSingle():await supabase.from("erp_warehouses").insert(payload).select("id").single();
  if(result.error||!result.data){setError("لم يتم حفظ المخزن: "+(result.error?.message||"لم تسمح صلاحيات المنشأة بالتعديل أو لم يتم إرجاع السجل."));setSaving(false);return;}
  setMessage(editing?"تم تحديث بيانات المخزن في قاعدة المنشأة.":"تم إضافة المخزن إلى قاعدة المنشأة.");
  setShowForm(false);setForm(empty());await load();setSaving(false);
 };
 const toggle=async(r:Warehouse)=>{
  if(!supabase||!canEdit)return;
  const next=!r.is_active;if(!window.confirm((next?"إعادة تفعيل":"إيقاف")+" المخزن «"+r.warehouse_name+"»؟ لن يتم حذف أي حركات أو أرصدة مرتبطة به."))return;
  const {error}=await supabase.from("erp_warehouses").update({is_active:next,updated_at:new Date().toISOString()}).eq("company_id",companyId).eq("id",r.id);
  if(error)setError("تعذر تغيير حالة المخزن: "+error.message);else{setMessage(next?"تم تفعيل المخزن.":"تم إيقاف المخزن دون حذف بياناته.");await load();}
 };
 return <section className="live-master live-warehouse" dir="rtl">
  <div className="live-master-head"><div className="live-master-icon"><Building2 size={22}/></div><div><small>إدارة المخازن · بيانات المنشأة الفعلية</small><h2>إدارة المخازن</h2><p>تعريف المخازن وربط كل مخزن بفرعه، مع متابعة إجمالي الكميات والقيمة الدفترية من أرصدة المخزون</p></div><span className="live-master-count"><Boxes size={15}/>{rows.length.toLocaleString("ar-EG")} مخزن</span></div>
  <div className="live-warehouse-kpis"><article><small>المخازن النشطة</small><b>{stats.active.toLocaleString("ar-EG")}</b></article><article><small>بنود الأرصدة المسجلة</small><b>{stats.balanceRows.toLocaleString("ar-EG")}</b></article><article><small>القيمة الدفترية المسجلة</small><b>{stats.value.toLocaleString("ar-EG",{maximumFractionDigits:2})} ج.م</b></article></div>
  <div className="live-master-toolbar"><div className="live-master-search"><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="ابحث بكود المخزن أو اسمه أو الفرع..."/></div><button onClick={()=>void load()} disabled={loading}><RefreshCw size={15}/> تحديث</button>{canEdit&&<button className="live-warehouse-primary" onClick={startNew}><Plus size={15}/> إضافة مخزن</button>}</div>
  {error&&<div className="live-master-error">{error}</div>}{message&&<div className="live-warehouse-message">{message}</div>}
  {showForm&&<div className="live-warehouse-form"><div className="live-warehouse-form-head"><b>{editing?"تعديل بيانات المخزن":"إضافة مخزن جديد"}</b><button onClick={()=>setShowForm(false)} aria-label="إغلاق"><X size={17}/></button></div><div className="live-warehouse-fields">
   <label><span>الفرع *</span><select value={form.branch_id} onChange={e=>setForm(v=>({...v,branch_id:e.target.value}))}><option value="">اختر الفرع</option>{branches.filter(b=>b.is_active).map(b=><option key={b.id} value={b.id}>{b.branch_code} — {b.branch_name}</option>)}</select></label>
   <label><span>كود المخزن *</span><input value={form.warehouse_code} onChange={e=>setForm(v=>({...v,warehouse_code:e.target.value}))} placeholder="أدخل الكود وفق سياسة التكويد"/></label>
   <label><span>اسم المخزن *</span><input value={form.warehouse_name} onChange={e=>setForm(v=>({...v,warehouse_name:e.target.value}))} placeholder="اسم المخزن"/></label>
   <label><span>الاسم بالإنجليزية</span><input value={form.warehouse_name_en} onChange={e=>setForm(v=>({...v,warehouse_name_en:e.target.value}))}/></label>
   <label><span>العنوان</span><input value={form.address} onChange={e=>setForm(v=>({...v,address:e.target.value}))}/></label>
   <label><span>الموقع / وصف المكان</span><input value={form.location} onChange={e=>setForm(v=>({...v,location:e.target.value}))}/></label>
   <label><span>الهاتف</span><input value={form.phone} onChange={e=>setForm(v=>({...v,phone:e.target.value}))}/></label>
  </div><div className="live-warehouse-form-actions"><button onClick={()=>void save()} disabled={saving}><Save size={15}/>{saving?"جارٍ الحفظ...":"حفظ البيانات"}</button><button onClick={()=>setShowForm(false)}>إلغاء</button></div></div>}
  <div className="live-master-summary"><span>البيانات تُقرأ وتُحفظ مباشرة في قاعدة سلسلة وفق صلاحيات الفرع</span><span>عرض {filtered.length.toLocaleString("ar-EG")} من {rows.length.toLocaleString("ar-EG")}</span></div>
  <div className="live-master-table-wrap"><table><thead><tr>{["كود المخزن","اسم المخزن","الفرع","العنوان","الهاتف","بنود الأرصدة","الحالة","إجراءات"].map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{filtered.map(r=>{const branch=branches.find(b=>b.id===r.branch_id),stock=balances.filter(b=>b.warehouse_id===r.id);return <tr key={r.id}><td className="code-cell">{r.warehouse_code}</td><td><b>{r.warehouse_name}</b>{r.warehouse_name_en&&<small>{r.warehouse_name_en}</small>}</td><td>{branch?.branch_name||"فرع غير ظاهر ضمن صلاحيتك"}</td><td>{r.address||r.location||"—"}</td><td>{r.phone||"—"}</td><td>{stock.length.toLocaleString("ar-EG")}</td><td><span className={r.is_active?"live-active":"live-inactive"}>{r.is_active?"نشط":"موقوف"}</span></td><td><div className="live-warehouse-actions">{canEdit&&<button onClick={()=>startEdit(r)} title="تعديل"><Pencil size={14}/></button>}{canEdit&&<button onClick={()=>void toggle(r)} title={r.is_active?"إيقاف":"تفعيل"}><Power size={14}/></button>}</div></td></tr>})}{!loading&&!filtered.length&&<tr><td colSpan={8} className="live-master-empty">لا توجد مخازن مطابقة.</td></tr>}</tbody></table>{loading&&<div className="live-master-empty">جارٍ تحميل بيانات المخازن...</div>}</div>
  {!live&&<div className="live-master-error">سجّل الدخول بحساب المنشأة لفتح بيانات المخازن الفعلية.</div>}
  {branches.length===0&&live&&!loading&&<p className="live-master-note">لا توجد فروع نشطة متاحة لحسابك. يلزم إعداد فرع نشط وربطه بصلاحيتك قبل إنشاء مخزن.</p>}
  <p className="live-master-note">الإيقاف لا يحذف المخزن أو أرصدته أو حركاته. لا يتم إنشاء أرصدة أو حركات مخزنية من هذه الشاشة؛ تتم من خلال مستندات التشغيل المعتمدة.</p>
 </section>;
}
