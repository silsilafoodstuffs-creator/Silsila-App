import {useCallback,useEffect,useMemo,useState} from "react";
import {AlertTriangle,CheckCircle2,ChevronDown,Database,LockKeyhole,Palette,RefreshCw,Save,Search,Settings2,ShieldCheck,SlidersHorizontal,X} from "lucide-react";
import {supabase} from "./supabase";

type Policy=Record<string,any>;
const categories=["الكل","برمجية","تكويدية","محاسبية","مخزنية","بيعية","شرائية","إدارية","الخطوط والألوان"];
const hiddenKeys=new Set(["code_generation_registry","code_type.cash_voucher","code_type.sales_representative","code_type.sales_campaign","code_type.customer_monthly_goal","code_type.employee_monthly_target"]);
const codePolicy=(p:Policy)=>p.category==="تكويدية"||String(p.policy_key||"").startsWith("code_")||String(p.policy_key||"").startsWith("geo_code.")||String(p.policy_key||"").startsWith("category_code.")||String(p.policy_key||"").startsWith("item_code");
const text=(v:any)=>v==null?"":String(v);
const parseObject=(v:any)=>{try{const x=JSON.parse(text(v));return x&&typeof x==="object"&&!Array.isArray(x)?x:null;}catch{return null;}};
export default function ProgramPoliciesWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const userId=sessionStorage.getItem("silsila-user-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const [rows,setRows]=useState<Policy[]>([]),[category,setCategory]=useState("الكل"),[query,setQuery]=useState("");
 const [selected,setSelected]=useState<Policy|null>(null),[draft,setDraft]=useState<Policy>({});
 const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[error,setError]=useState(""),[notice,setNotice]=useState("");
 const [permissionsReady,setPermissionsReady]=useState(false),[canRead,setCanRead]=useState(true),[canEdit,setCanEdit]=useState(false);
 const [lockedCodes,setLockedCodes]=useState<Set<string>>(new Set()),[lockCheckReady,setLockCheckReady]=useState(false);
 const load=useCallback(async()=>{
  if(!supabase){setError("اتصال قاعدة البيانات غير مهيأ.");setLoading(false);return;}
  if(!companyId||!userId){setError("جلسة الدخول لا تحتوي على الشركة والمستخدم النشطين.");setLoading(false);return;}
  setLoading(true);setError("");setNotice("");
  try{
   const {data:perms,error:permError}=await supabase.from("erp_user_permissions").select("menu_key,allow_access,can_edit,can_save").eq("company_id",companyId).eq("user_id",userId);
   if(permError)throw permError;
   const keys=["إعدادات عامة::بيانات أساسية::سياسات البرنامج","إدارة البرنامج::بيانات أساسية::إعدادات البرنامج","إعدادات عامة::بيانات أساسية::*","إعدادات عامة::*::*","إدارة البرنامج::بيانات أساسية::*","إدارة البرنامج::*::*"];
   const permission=(perms||[]).find((p:any)=>keys.includes(p.menu_key));
   setCanRead(permission?.allow_access!==false);setCanEdit(["owner","admin"].includes(role)||(permission?.can_edit===true||permission?.can_save===true));setPermissionsReady(true);
   if(permission?.allow_access===false)throw new Error("لا تملك صلاحية عرض سياسات البرنامج.");
   const {data,error}=await supabase.from("erp_program_policies").select("*").eq("company_id",companyId).order("category",{ascending:true}).order("policy_code",{ascending:true});
   if(error)throw error;
   setRows((data||[]).filter((p:any)=>!hiddenKeys.has(text(p.policy_key))));
   try{
    const {data:locks,error:lockError}=await supabase.rpc("erp_code_policy_lock_status",{p_company_id:companyId});
    if(lockError)throw lockError;
    setLockedCodes(new Set((Array.isArray(locks)?locks:[]).map((x:any)=>String(x))));
    setLockCheckReady(true);
   }catch{setLockedCodes(new Set(["__ALL_CODE_POLICIES_LOCKED_UNTIL_CHECK__"]));setLockCheckReady(false);}
  }catch(e:any){setError("تعذر تحميل سياسات البرنامج: "+(e?.message||String(e)));setRows([]);}
  finally{setLoading(false);}
 },[companyId,userId,role]);
 useEffect(()=>{void load();},[load]);
 const visible=useMemo(()=>rows.filter(p=>(category==="الكل"||p.category===category)&&(!query.trim()||[p.policy_code,p.policy_key,p.name_ar,p.name_en,p.category,p.policy_value].some(v=>text(v).toLowerCase().includes(query.trim().toLowerCase())))),[rows,category,query]);
 const counts=useMemo(()=>Object.fromEntries(categories.map(c=>[c,c==="الكل"?rows.length:rows.filter(p=>p.category===c).length])),[rows]);
 const isLocked=(p:Policy)=>codePolicy(p)&&(!lockCheckReady||lockedCodes.has("__ALL_CODE_POLICIES_LOCKED_UNTIL_CHECK__")||lockedCodes.has(text(p.policy_key)));
 const openEditor=(p:Policy)=>{setSelected(p);setDraft({...p});setError("");setNotice("");};
 const closeEditor=()=>{setSelected(null);setDraft({});};
 const update=async()=>{
  if(!supabase||!selected)return;
  if(!canEdit){setError("لا تملك صلاحية تعديل السياسات.");return;}
  if(isLocked(selected)){setError("سياسة التكويد محمية حاليًا لضمان عدم تغيير الأكواد الصادرة. لم يتم تعديل أي قيمة.");return;}
  const key=text(selected.policy_key),value=text(draft.policy_value);
  if(key.startsWith("visual_identity.")&&key.endsWith("_color")&&!/^#[0-9a-fA-F]{6}$/.test(value)){setError("قيمة اللون غير صحيحة. استخدم صيغة HEX مثل #FFA015.");return;}
  if(key==="appearance.header_background"||key==="appearance.screen_background"){if(!/^#[0-9a-fA-F]{6}$/.test(value)){setError("أدخل لونًا صحيحًا بصيغة HEX.");return;}}
  setSaving(true);setError("");setNotice("");
  try{
   const {data,error}=await supabase.from("erp_program_policies").update({policy_value:value,is_enabled:draft.is_enabled===true,apply_to_all:draft.apply_to_all===true,user_ids:Array.isArray(draft.user_ids)?draft.user_ids:[],updated_at:new Date().toISOString()}).eq("id",selected.id).eq("company_id",companyId).select("id").single();
   if(error)throw error;if(!data)throw new Error("لم يؤكد النظام حفظ السياسة.");
   setNotice("تم حفظ السياسة بنجاح في قاعدة البيانات المشتركة.");
   await load();closeEditor();
  }catch(e:any){setError("فشل حفظ السياسة: "+(e?.message||String(e)));}
  finally{setSaving(false);}
 };
 const fieldLabel=(p:Policy)=>p.name_ar||p.policy_key||"سياسة بدون اسم";
 const valueKind=(p:Policy)=>{const key=text(p.policy_key);if(key==="appearance.dark_mode")return "boolean";if(key==="appearance.theme_preset")return "theme";if(key==="appearance.language")return "language";if(key==="appearance.header_background"||key==="appearance.screen_background"||key.startsWith("visual_identity.")&&key.endsWith("_color"))return "color";if(["inventory_valuation","inventory_count","depreciation","inventory.stocktake.valuation_basis","trader_market.story_duration_unit"].includes(key))return "choice";return "text";};
 const optionsFor=(p:Policy)=>{const k=text(p.policy_key);if(k==="appearance.theme_preset")return ["glossy","classic"];if(k==="appearance.language")return ["العربية","الإنجليزية"];if(k==="inventory_valuation")return ["المتوسط المرجح","الوارد أولاً صادر أولاً (FIFO)","التحديد المحدد"];if(k==="inventory_count")return ["الجرد المستمر","الجرد الدوري"];if(k==="depreciation")return ["القسط الثابت","القسط المتناقص","وحدات الإنتاج"];if(k==="inventory.stocktake.valuation_basis")return ["sale","purchase"];if(k==="trader_market.story_duration_unit")return ["دقيقة","ساعة"];return [];};
 const json=parseObject(draft.policy_value);
 const setJson=(key:string,value:any)=>setDraft((old:Policy)=>{const obj=parseObject(old.policy_value)||{};return {...old,policy_value:JSON.stringify({...obj,[key]:value})};});
 const s:Record<string,any>={};
 return <section className="program-policies" dir="rtl">
  <style>{`
  .program-policies{color:#241735;display:flex;flex-direction:column;gap:14px;min-width:0}.pp-head{display:flex;align-items:center;gap:13px;padding:18px 20px;border:1px solid #eadff4;border-radius:18px;background:linear-gradient(120deg,#fff 0%,#faf6ff 100%)}.pp-head-icon{width:46px;height:46px;border-radius:14px;background:#3E007D;color:#fff;display:grid;place-items:center}.pp-head h2{margin:0;color:#3E007D;font-size:22px;font-weight:900}.pp-head p{margin:4px 0 0;color:#756984;font-size:13px}.pp-count{margin-inline-start:auto;display:flex;align-items:center;gap:7px;color:#3E007D;font-weight:800;white-space:nowrap}.pp-alert,.pp-notice{display:flex;align-items:center;gap:8px;padding:10px 13px;border-radius:10px;font-size:13px}.pp-alert{background:#fff1ef;color:#a52b20}.pp-notice{background:#eefaf2;color:#176b38}.pp-toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.pp-search{display:flex;align-items:center;gap:8px;flex:1;min-width:210px;background:#fff;border:1px solid #e7ddec;border-radius:10px;padding:0 12px;height:42px}.pp-search input{border:0;outline:0;flex:1;min-width:0;font:inherit}.pp-refresh,.pp-btn{height:40px;border:1px solid #e5d9ec;border-radius:10px;background:#fff;color:#49345d;padding:0 13px;display:inline-flex;align-items:center;justify-content:center;gap:7px;font:inherit;cursor:pointer}.pp-tabs{display:flex;gap:7px;overflow-x:auto;padding:2px 0 6px;scrollbar-width:thin}.pp-tab{border:1px solid #e8ddec;border-radius:999px;background:#fff;padding:9px 14px;white-space:nowrap;color:#5b4a69;font:inherit;cursor:pointer}.pp-tab.active{background:#3E007D;color:#fff;border-color:#3E007D}.pp-tab small{margin-inline-start:7px;opacity:.75}.pp-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,330px),1fr));gap:10px}.pp-card{border:1px solid #eadff0;border-radius:13px;background:#fff;padding:13px;display:flex;flex-direction:column;gap:9px;min-width:0}.pp-card-top{display:flex;align-items:flex-start;gap:8px}.pp-card h3{margin:0;font-size:14px;color:#38234e;line-height:1.6}.pp-card code{font-size:10px;color:#8b7a98;direction:ltr;overflow-wrap:anywhere}.pp-card-value{background:#faf8fc;border-radius:8px;padding:8px 10px;color:#655574;font-size:12px;white-space:pre-wrap;overflow-wrap:anywhere;max-height:76px;overflow:hidden}.pp-card-foot{display:flex;align-items:center;gap:7px;flex-wrap:wrap;font-size:11px;color:#776887}.pp-state{border-radius:999px;padding:4px 8px;background:#f1edf5}.pp-state.on{background:#eaf8ef;color:#237445}.pp-state.off{background:#fff1ef;color:#a33a31}.pp-state.lock{background:#fff5e5;color:#8a5a10}.pp-edit{margin-inline-start:auto;border:0;background:#f4edf9;color:#3E007D;border-radius:8px;padding:7px 10px;display:flex;align-items:center;gap:6px;font:inherit;cursor:pointer}.pp-edit:disabled{opacity:.45;cursor:not-allowed}.pp-empty{padding:34px;text-align:center;color:#84758f;background:#faf8fc;border-radius:12px}.pp-editor{border:1px solid #d8c5e7;border-radius:16px;background:#fff;padding:16px;display:flex;flex-direction:column;gap:13px;box-shadow:0 12px 35px #3e007d12}.pp-editor-head{display:flex;align-items:center;gap:10px}.pp-editor-head h3{margin:0;color:#3E007D;font-size:17px}.pp-editor-head button{margin-inline-start:auto;border:0;background:#f5effb;border-radius:8px;padding:7px;cursor:pointer}.pp-fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.pp-field{display:flex;flex-direction:column;gap:6px;min-width:0}.pp-field.full{grid-column:1/-1}.pp-field label{font-size:12px;font-weight:800;color:#574365}.pp-field input,.pp-field select,.pp-field textarea{width:100%;box-sizing:border-box;border:1px solid #e3d8ea;border-radius:9px;padding:10px 11px;font:inherit;color:#38244c;background:#fff;min-height:40px}.pp-field textarea{min-height:90px;resize:vertical}.pp-color{display:flex;gap:9px;align-items:center}.pp-color input[type=color]{width:52px;padding:3px;min-height:40px}.pp-toggle{display:flex;gap:8px;align-items:center;font-size:13px;color:#4e3b5d}.pp-toggle input{accent-color:#3E007D;width:17px;height:17px}.pp-meta{display:flex;gap:14px;flex-wrap:wrap;color:#7d6c89;font-size:11px}.pp-meta code{direction:ltr}.pp-actions{display:flex;gap:8px;justify-content:flex-start}.pp-save{background:#3E007D;color:#fff;border:0;border-radius:10px;padding:10px 18px;font:inherit;font-weight:800;display:flex;align-items:center;gap:8px;cursor:pointer}.pp-save:disabled{opacity:.5;cursor:not-allowed}@media(max-width:680px){.pp-head{padding:13px}.pp-head h2{font-size:18px}.pp-count{font-size:11px}.pp-fields{grid-template-columns:1fr}.pp-editor{padding:12px}.pp-list{grid-template-columns:1fr}}`}</style>
  <header className="pp-head"><div className="pp-head-icon"><SlidersHorizontal size={23}/></div><div><h2>سياسات البرنامج</h2><p>نقل شاشة السياسات إلى React مع ربط مباشر ببيانات سلسلة الأصلية</p></div><div className="pp-count"><Database size={16}/>{rows.length.toLocaleString("ar-EG")} سياسة</div></header>
  {error&&<div className="pp-alert"><AlertTriangle size={16}/>{error}</div>}{notice&&<div className="pp-notice"><CheckCircle2 size={16}/>{notice}</div>}
  <div className="pp-toolbar"><label className="pp-search"><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="ابحث باسم السياسة أو الكود أو القيمة"/></label><button className="pp-refresh" onClick={()=>void load()}><RefreshCw size={15}/> تحديث البيانات</button></div>
  <nav className="pp-tabs" aria-label="تصنيفات سياسات البرنامج">{categories.map(c=><button key={c} className={"pp-tab"+(category===c?" active":"")} onClick={()=>{setCategory(c);setSelected(null);}}>{c}<small>{counts[c]||0}</small></button>)}</nav>
  {selected&&<div className="pp-editor"><div className="pp-editor-head"><Settings2 size={19}/><h3>{fieldLabel(selected)}</h3><button onClick={closeEditor} aria-label="إغلاق"><X size={17}/></button></div>
   <div className="pp-fields">
    <div className="pp-field full"><label>قيمة السياسة</label>
     {valueKind(selected)==="boolean"?<select value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value}))}><option value="true">مفعّل</option><option value="false">غير مفعّل</option></select>:
      valueKind(selected)==="theme"||valueKind(selected)==="language"||valueKind(selected)==="choice"?<select value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value}))}>{optionsFor(selected).map(o=><option key={o} value={o}>{o}</option>)}</select>:
      valueKind(selected)==="color"?<div className="pp-color"><input type="color" value={/^#[0-9a-fA-F]{6}$/.test(text(draft.policy_value))?text(draft.policy_value):"#3E007D"} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value.toUpperCase()}))}/><input dir="ltr" value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value.toUpperCase()}))}/></div>:
      <textarea dir="auto" value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value}))} spellCheck={false}/>}
    </div>
    {json&&<><div className="pp-field"><label>معاينة / محتوى JSON</label><textarea dir="ltr" readOnly value={JSON.stringify(json,null,2)}/></div><div className="pp-field"><label>ملاحظة</label><input readOnly value="تُحفظ قيمة السياسة كما هي؛ لا يتم تغيير بنية التكويد تلقائيًا."/></div></>}
    <div className="pp-field"><label>نطاق التطبيق</label><label className="pp-toggle"><input type="checkbox" checked={draft.apply_to_all===true} onChange={e=>setDraft((x:Policy)=>({...x,apply_to_all:e.target.checked}))}/> تطبيق على جميع المستخدمين</label></div>
    <div className="pp-field"><label>حالة السياسة</label><label className="pp-toggle"><input type="checkbox" checked={draft.is_enabled===true} onChange={e=>setDraft((x:Policy)=>({...x,is_enabled:e.target.checked}))}/> السياسة مفعّلة</label></div>
   </div>
   {isLocked(selected)&&<div className="pp-alert"><LockKeyhole size={16}/>سياسة التكويد مقفلة للحفاظ على الأكواد الحالية، أو تعذر التحقق من حالة القفل. لا يمكن تعديلها الآن.</div>}
   <div className="pp-meta"><span>كود السياسة: <b>{text(selected.policy_code)||"—"}</b></span><span>المفتاح: <code>{text(selected.policy_key)}</code></span><span>التصنيف: {text(selected.category)}</span></div>
   <div className="pp-actions"><button className="pp-save" disabled={saving||!canEdit||isLocked(selected)} onClick={()=>void update()}><Save size={16}/>{saving?"جارٍ الحفظ...":"حفظ التعديلات"}</button><button className="pp-btn" onClick={closeEditor}>إلغاء</button></div>
  </div>}
  {loading?<div className="pp-empty">جارٍ تحميل السياسات المحفوظة...</div>:!canRead?<div className="pp-empty">لا تملك صلاحية عرض هذه الشاشة.</div>:visible.length===0?<div className="pp-empty">لا توجد سياسات مطابقة.</div>:<div className="pp-list">{visible.map(p=><article className="pp-card" key={p.id}><div className="pp-card-top"><div style={{minWidth:0,flex:1}}><h3>{fieldLabel(p)}</h3><code>{text(p.policy_code)} · {text(p.policy_key)}</code></div>{p.is_enabled?<ShieldCheck size={18} color="#23834a"/>:<X size={17} color="#a33a31"/>}</div><div className="pp-card-value">{text(p.policy_value)||"لا توجد قيمة محددة"}</div><div className="pp-card-foot"><span className={"pp-state "+(p.is_enabled?"on":"off")}>{p.is_enabled?"مفعّلة":"متوقفة"}</span><span className="pp-state">{p.apply_to_all?"كل المستخدمين":"نطاق محدد"}</span>{isLocked(p)&&<span className="pp-state lock"><LockKeyhole size={11} style={{verticalAlign:"middle"}}/> محمية</span>}<button className="pp-edit" disabled={!canEdit||isLocked(p)} onClick={()=>openEditor(p)}><Palette size={14}/> تعديل السياسة</button></div></article>)}</div>}
  <footer style={{fontSize:11,color:"#8a7b95",padding:"4px 2px"}}>مصدر البيانات: erp_program_policies · لا تُنشأ نسخ موازية ولا تُحذف سياسات قديمة من هذه الشاشة.</footer>
 </section>;
}
