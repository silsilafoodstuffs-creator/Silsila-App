import {useCallback,useEffect,useMemo,useState} from "react";
import {supabase} from "./supabase";
import {Building2,GitBranch,Layers3,Tags,Award,SlidersHorizontal,Search,RefreshCw,Plus,Pencil,Save,X,CheckCircle2,Database,AlertTriangle} from "lucide-react";

type Kind="policies"|"company"|"branches"|"activities"|"activity-categories"|"brand-groups"|"brands";
type Row=Record<string,any>;
type Field={key:string;label:string;required?:boolean;type?:"select"|"number"|"email"|"tel";options?:string[]};
const defs:Record<Kind,{title:string;table:string;icon:any;description:string;columns:string[];fields:Field[];search:string[];companyScoped:boolean}> = {
 policies:{title:"سياسات البرنامج",table:"erp_program_policies",icon:SlidersHorizontal,description:"السياسات الفعلية المحفوظة للمؤسسة: التشغيل والتكويد والهوية وباقي الإعدادات.",columns:["policy_code","category","name_ar","policy_value","is_enabled","apply_to_all"],fields:[{key:"policy_value",label:"قيمة السياسة"}],search:["policy_code","policy_key","name_ar","name_en","category"],companyScoped:true},
 company:{title:"بيانات الشركة",table:"erp_companies",icon:Building2,description:"البيانات القانونية والتجارية ووسائل الاتصال والعملة والبيانات الإضافية.",columns:["legal_name","trade_name","tax_number","commercial_register","phone","email","base_currency","address"],fields:[{key:"legal_name",label:"الاسم القانوني",required:true},{key:"trade_name",label:"الاسم التجاري"},{key:"tax_number",label:"الرقم الضريبي"},{key:"commercial_register",label:"السجل التجاري"},{key:"phone",label:"الهاتف",type:"tel"},{key:"email",label:"البريد الإلكتروني",type:"email"},{key:"base_currency",label:"العملة",required:true,options:["EGP","USD","SAR","AED","KWD","EUR","GBP"]},{key:"address",label:"العنوان"},{key:"english_name",label:"الاسم بالإنجليزية"},{key:"company_code",label:"كود الشركة"},{key:"tax_office",label:"مأمورية الضرائب"},{key:"country",label:"الدولة"}],search:["legal_name","trade_name","phone"],companyScoped:true},
 branches:{title:"فروع الشركة",table:"erp_branches",icon:GitBranch,description:"الفروع الفعلية التابعة للشركة مع بيانات الاتصال والعنوان والحالة.",columns:["branch_code","branch_name","branch_name_en","phone","email","address","is_main","is_active"],fields:[{key:"branch_code",label:"كود الفرع",required:true},{key:"branch_name",label:"اسم الفرع",required:true},{key:"branch_name_en",label:"الاسم بالإنجليزية"},{key:"phone",label:"الهاتف",type:"tel"},{key:"phone2",label:"هاتف إضافي",type:"tel"},{key:"email",label:"البريد الإلكتروني",type:"email"},{key:"address",label:"العنوان"},{key:"location",label:"وصف الموقع"}],search:["branch_code","branch_name","branch_name_en","phone"],companyScoped:true},
 activities:{title:"الأنشطة",table:"activity_types",icon:Layers3,description:"الدليل الرئيسي لأنشطة سلسلة، مع الكود والترتيب والظهور في التطبيق.",columns:["code","name","name_en","sort_order","is_active","show_in_app"],fields:[{key:"code",label:"كود النشاط",required:true},{key:"name",label:"اسم النشاط",required:true},{key:"name_en",label:"الاسم بالإنجليزية"},{key:"sort_order",label:"ترتيب العرض",type:"number"}],search:["code","name","name_en"],companyScoped:false},
 "activity-categories":{title:"فئات الأنشطة",table:"erp_activity_customer_categories",icon:Tags,description:"الفئات المرتبطة بكل نشاط ومساحة عمل كما هي محفوظة في المشروع القديم.",columns:["activity_type","activity_name","customer_category","is_active"],fields:[{key:"activity_type",label:"كود النشاط",required:true},{key:"activity_name",label:"اسم النشاط",required:true},{key:"customer_category",label:"اسم الفئة",required:true}],search:["activity_type","activity_name","customer_category"],companyScoped:true},
 "brand-groups":{title:"مجموعات البراندات",table:"erp_brand_groups",icon:Layers3,description:"مجموعات العلامات التجارية حسب النشاط، مع الحفاظ على أكواد المجموعات الحالية.",columns:["group_code","group_name","group_name_en","activity_code","is_active","show_in_app"],fields:[{key:"group_code",label:"كود المجموعة",required:true},{key:"group_name",label:"اسم المجموعة",required:true},{key:"group_name_en",label:"الاسم بالإنجليزية"},{key:"activity_code",label:"النشاط",required:true}],search:["group_code","group_name","group_name_en","activity_code"],companyScoped:true},
 brands:{title:"البراندات",table:"erp_brands",icon:Award,description:"العلامات التجارية وربط كل براند بنشاط ومجموعة، مع الاحتفاظ بالصور والترتيب الحاليين.",columns:["brand_code","brand_name","brand_name_en","brand_group","activity_code","is_active","show_in_app"],fields:[{key:"brand_code",label:"كود البراند",required:true},{key:"brand_name",label:"اسم البراند",required:true},{key:"brand_name_en",label:"الاسم بالإنجليزية"},{key:"activity_code",label:"النشاط",required:true},{key:"brand_group_id",label:"مجموعة البراند",type:"select"}],search:["brand_code","brand_name","brand_name_en","brand_group","activity_code"],companyScoped:true}
};
const textValue=(v:any)=>v==null?"":String(v);
export default function FoundationWorkspace({kind}:{kind:Kind}){
 const cfg=defs[kind],Icon=cfg.icon;
 const [companyId]=useState(()=>sessionStorage.getItem("silsila-company-id")||"");
 const [rows,setRows]=useState<Row[]>([]),[query,setQuery]=useState(""),[category,setCategory]=useState("الكل");
 const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[error,setError]=useState(""),[notice,setNotice]=useState("");
 const [editing,setEditing]=useState<Row|null>(null),[form,setForm]=useState<Row>({});
 const [extra,setExtra]=useState<Row>({}),[activities,setActivities]=useState<Row[]>([]),[groups,setGroups]=useState<Row[]>([]);
 const load=useCallback(async()=>{
  if(!supabase){setError("اتصال قاعدة البيانات غير مهيأ.");setLoading(false);return;}
  if(!companyId){setError("لا توجد شركة نشطة في جلسة الدخول.");setLoading(false);return;}
  setLoading(true);setError("");setNotice("");
  try{
   if(kind==="company"){
    const {data,error}=await supabase.from("erp_companies").select("id,legal_name,trade_name,tax_number,commercial_register,phone,email,address,base_currency,is_active").eq("id",companyId).maybeSingle();
    if(error)throw error;if(!data)throw new Error("لم يتم العثور على بيانات الشركة أو لا توجد صلاحية لعرضها.");
    const {data:extraRow}=await supabase.from("erp_company_settings").select("setting_value").eq("company_id",companyId).eq("setting_key","company_profile_extra").maybeSingle();
    const merged={...data,...(extraRow?.setting_value||{})};setRows([merged]);setExtra(extraRow?.setting_value||{});setEditing(null);setForm(merged);
   }else{
    let q=supabase.from(cfg.table).select(kind==="policies"?"id,company_id,policy_key,policy_code,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value":kind==="brands"?"id,company_id,brand_code,brand_name,brand_name_en,brand_group,brand_group_id,activity_code,is_active,show_in_app,display_order,is_system":kind==="brand-groups"?"id,company_id,group_code,group_name,group_name_en,activity_code,is_active,show_in_app":kind==="branches"?"id,company_id,branch_code,branch_name,branch_name_en,phone,phone2,email,address,location,is_main,is_active":"*");
    if(cfg.companyScoped)q=q.eq("company_id",companyId);
    if(kind==="activity-categories"){
      const {data:ws,error:wsError}=await supabase.from("erp_business_workspaces").select("id,workspace_name,activity_type,platform_company_id").eq("platform_company_id",companyId).eq("is_active",true);
      if(wsError)throw wsError;
      const ids=(ws||[]).map((x:any)=>x.id);setActivities(ws||[]);
      if(!ids.length){setRows([]);setLoading(false);return;}
      q=q.in("workspace_id",ids);
    }
    const order=kind==="policies"?"category":kind==="activities"?"sort_order":kind==="activity-categories"?"activity_name":kind==="brand-groups"?"group_code":kind==="brands"?"brand_code":"branch_code";
    const {data,error}=await q.order(order,{ascending:true});if(error)throw error;setRows(data||[]);
    if(kind==="activities"){setActivities(data||[]);}
    if(kind==="brand-groups"){setGroups(data||[]);}
    if(kind==="brands"||kind==="brand-groups"){
      const {data:acts}=await supabase.from("activity_types").select("code,name").order("sort_order");setActivities(acts||[]);
      if(kind==="brands"){const {data:gs}=await supabase.from("erp_brand_groups").select("id,group_code,group_name,activity_code").eq("company_id",companyId).order("group_code");setGroups(gs||[]);}
    }
   }
  }catch(e:any){setError("تعذر تحميل "+cfg.title+": "+(e?.message||String(e)));setRows([]);}
  finally{setLoading(false);}
 },[companyId,cfg,kind]);
 useEffect(()=>{void load();},[load]);
 const visible=useMemo(()=>rows.filter(r=>(!query.trim()||cfg.search.some(k=>textValue(r[k]).toLowerCase().includes(query.trim().toLowerCase())))&&(category==="الكل"||r.category===category)),[rows,query,category,cfg]);
 const startNew=()=>{
  if(kind==="company"){setEditing(rows[0]||{});setForm(rows[0]||{});return;}
  setEditing(null);const initial:Row={is_active:true,show_in_app:true,apply_to_all:true};
  if(kind==="activities"){initial.code="ACT"+String(Math.max(0,...rows.map(r=>Number(String(r.code||"").replace(/\D/g,""))||0))+1).padStart(3,"0");initial.sort_order=rows.length+1;}
  if(kind==="activity-categories"){initial.workspace_id=activities[0]?.id||"";initial.activity_type=activities[0]?.activity_type||"";initial.activity_name=activities[0]?.workspace_name||"";}
  if(kind==="brand-groups"){initial.activity_code=activities[0]?.code||"ACT001";}
  if(kind==="brands"){initial.activity_code=activities[0]?.code||"ACT001";initial.brand_group_id=groups[0]?.id||"";}
  setForm(initial);
 };
 const startEdit=(r:Row)=>{setEditing(r);setForm({...r});};
 const setField=(key:string,value:any)=>setForm((old:Row)=>({...old,[key]:value}));
 const save=async()=>{
  if(!supabase)return;
  for(const f of cfg.fields){if(f.required&&!textValue(form[f.key]).trim()){setError("حقل «"+f.label+"» مطلوب.");return;}}
  setSaving(true);setError("");setNotice("");
  try{
   if(kind==="company"){
    const payload={legal_name:textValue(form.legal_name).trim(),trade_name:textValue(form.trade_name).trim()||null,tax_number:textValue(form.tax_number).trim()||null,commercial_register:textValue(form.commercial_register).trim()||null,phone:textValue(form.phone).trim()||null,email:textValue(form.email).trim()||null,address:textValue(form.address).trim()||null,base_currency:textValue(form.base_currency||"EGP").trim().toUpperCase()};
    const {error}=await supabase.from("erp_companies").update(payload).eq("id",companyId);if(error)throw error;
    const current=await supabase.auth.getUser();const extras={...extra,english_name:textValue(form.english_name),company_code:textValue(form.company_code),tax_office:textValue(form.tax_office),country:textValue(form.country||"مصر"),phone2:textValue(form.phone2),logo_path:extra.logo_path||""};
    const {error:extraError}=await supabase.from("erp_company_settings").upsert({company_id:companyId,setting_key:"company_profile_extra",setting_value:extras,updated_by:current.data.user?.id||null},{onConflict:"company_id,setting_key"});if(extraError)throw extraError;
   }else if(kind==="policies"){
    if(!editing?.id)throw new Error("لا يمكن إنشاء سياسة غير معرفة في دليل سياسات المشروع.");
    const {error}=await supabase.from(cfg.table).update({policy_value:textValue(form.policy_value),is_enabled:form.is_enabled===true,apply_to_all:form.apply_to_all===true,updated_at:new Date().toISOString()}).eq("id",editing.id).eq("company_id",companyId);if(error)throw error;
   }else{
    const payload:Row={...form};
    delete payload.id;delete payload.created_at;delete payload.updated_at;
    if(kind==="activity-categories"){payload.workspace_id=payload.workspace_id||activities[0]?.id;if(!payload.workspace_id)throw new Error("لا توجد مساحة نشاط مرتبطة بالشركة.");}
    if(kind==="brands"){const g=groups.find(x=>x.id===payload.brand_group_id);payload.brand_group=g?.group_name||null;}
    if(cfg.companyScoped)payload.company_id=companyId;
    if(editing?.id){const {error}=await supabase.from(cfg.table).update(payload).eq("id",editing.id).eq(cfg.companyScoped?"company_id":"id",cfg.companyScoped?companyId:editing.id);if(error)throw error;}
    else{const {error}=await supabase.from(cfg.table).insert(payload);if(error)throw error;}
   }
   setNotice("تم حفظ التعديلات في قاعدة البيانات بنجاح.");await load();if(kind!=="company")setEditing(null);
  }catch(e:any){setError("لم يتم الحفظ: "+(e?.message||String(e)));}
  finally{setSaving(false);}
 };
 const remove=async(r:Row)=>{
  if(!supabase||kind==="policies"||kind==="company")return;
  if(!window.confirm("تأكيد تعطيل السجل؟ سيتم تغيير حالته دون حذف البيانات المرتبطة."))return;
  const statusField=kind==="activities"?"is_active":"is_active";
  let update=supabase.from(cfg.table).update({[statusField]:false}).eq("id",r.id);if(cfg.companyScoped)update=update.eq("company_id",companyId);const {error}=await update;
  if(error)setError("تعذر تعطيل السجل: "+error.message);else{setNotice("تم تعطيل السجل دون حذفه.");await load();}
 };
 const policyCategories=["الكل",...Array.from(new Set(rows.map(r=>r.category).filter(Boolean)))];
 return <section className="foundation-workspace" dir="rtl">
  <header className="foundation-head"><span><Icon size={22}/></span><div><small>سلسلة · البيانات الفعلية للمشروع القديم</small><h2>{cfg.title}</h2><p>{cfg.description}</p></div><b><Database size={15}/>{rows.length.toLocaleString("ar-EG")} سجل</b></header>
  {error&&<div className="foundation-error"><AlertTriangle size={16}/>{error}</div>}{notice&&<div className="foundation-notice"><CheckCircle2 size={16}/>{notice}</div>}
  {kind!=="company"&&<div className="foundation-tools"><label><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="ابحث بالكود أو الاسم..."/></label>{kind==="policies"&&<select value={category} onChange={e=>setCategory(e.target.value)}>{policyCategories.map(x=><option key={x}>{x}</option>)}</select>}<button onClick={()=>void load()}><RefreshCw size={15}/> تحديث</button>{kind!=="policies"&&<button className="foundation-add" onClick={startNew}><Plus size={15}/> إضافة جديد</button>}</div>}
  {kind==="company"&&<div className="foundation-tools"><span>بيانات الشركة المسجلة حاليًا</span><button onClick={()=>void load()}><RefreshCw size={15}/> تحديث</button><button className="foundation-add" onClick={()=>startEdit(rows[0]||{})}><Pencil size={15}/> تعديل البيانات</button></div>}
  {editing&&<div className="foundation-editor"><div className="foundation-editor-head"><b>{kind==="company"?"تعديل بيانات الشركة":kind==="policies"?"تعديل السياسة: "+(editing.name_ar||editing.policy_key):editing.id?"تعديل سجل":"إضافة سجل جديد"}</b><button onClick={()=>setEditing(null)} aria-label="إغلاق"><X size={17}/></button></div>
   {kind==="policies"? <div className="foundation-form"><label><span>قيمة السياسة</span><textarea value={textValue(form.policy_value)} onChange={e=>setField("policy_value",e.target.value)}/></label><label className="foundation-check"><input type="checkbox" checked={form.is_enabled===true} disabled={editing.policy_key==="data_integrity.prevent_delete_with_references"} onChange={e=>setField("is_enabled",e.target.checked)}/> السياسة مفعّلة</label><label className="foundation-check"><input type="checkbox" checked={form.apply_to_all===true} disabled={editing.policy_key==="data_integrity.prevent_delete_with_references"} onChange={e=>setField("apply_to_all",e.target.checked)}/> تطبق على جميع المستخدمين</label></div>:
   <div className="foundation-form">{cfg.fields.map(f=><label key={f.key}><span>{f.label}{f.required?" *":""}</span>{f.options?<select value={textValue(form[f.key])} onChange={e=>setField(f.key,e.target.value)}>{f.options.map(o=><option key={o} value={o}>{o}</option>)}</select>:f.key==="brand_group_id"?<select value={textValue(form[f.key])} onChange={e=>setField(f.key,e.target.value)}>{groups.map(g=><option key={g.id} value={g.id}>{g.group_code} · {g.group_name}</option>)}</select>:f.key==="activity_type"&&kind==="activity-categories"?<select value={textValue(form.workspace_id)} onChange={e=>{const w=activities.find(x=>x.id===e.target.value);setForm((old:Row)=>({...old,workspace_id:e.target.value,activity_type:w?.activity_type||"",activity_name:w?.workspace_name||""}));}}>{activities.map(w=><option key={w.id} value={w.id}>{w.workspace_name}</option>)}</select>:<input type={f.type||"text"} value={textValue(form[f.key])} onChange={e=>setField(f.key,f.type==="number"?Number(e.target.value):e.target.value)}/>}</label>)}
    {kind==="branches"&&<><label className="foundation-check"><input type="checkbox" checked={form.is_main===true} onChange={e=>setField("is_main",e.target.checked)}/> فرع رئيسي</label><label className="foundation-check"><input type="checkbox" checked={form.is_active!==false} onChange={e=>setField("is_active",e.target.checked)}/> نشط</label></>}
    {(kind==="activities"||kind==="brand-groups"||kind==="brands")&&<><label className="foundation-check"><input type="checkbox" checked={form.is_active!==false} onChange={e=>setField("is_active",e.target.checked)}/> نشط</label><label className="foundation-check"><input type="checkbox" checked={form.show_in_app!==false} onChange={e=>setField("show_in_app",e.target.checked)}/> يظهر في تطبيق سلسلة</label></>}
   </div>}
   <div className="foundation-editor-actions"><button className="foundation-save" disabled={saving} onClick={()=>void save()}><Save size={15}/>{saving?"جارٍ الحفظ...":"حفظ البيانات"}</button><button onClick={()=>setEditing(null)}>إلغاء</button></div>
  </div>}
  {kind==="company"?<div className="foundation-company-summary">{rows.map(r=><div key={r.id}><b>{r.trade_name||r.legal_name}</b><span>{r.legal_name}</span><span>{r.phone||"—"} · {r.email||"—"}</span><span>{r.address||"—"}</span><strong>{r.base_currency||"EGP"}</strong></div>)}</div>:
  <div className="foundation-table-wrap"><table><thead><tr>{cfg.columns.map(c=><th key={c}>{({policy_code:"الكود",category:"التصنيف",name_ar:"السياسة",policy_value:"القيمة",is_enabled:"التفعيل",apply_to_all:"النطاق",legal_name:"الاسم القانوني",trade_name:"الاسم التجاري",tax_number:"الرقم الضريبي",commercial_register:"السجل التجاري",phone:"الهاتف",email:"البريد",base_currency:"العملة",address:"العنوان",branch_code:"الكود",branch_name:"الفرع",branch_name_en:"الاسم الإنجليزي",is_main:"رئيسي",code:"الكود",name:"النشاط",name_en:"الاسم الإنجليزي",sort_order:"الترتيب",activity_type:"كود النشاط",activity_name:"النشاط",customer_category:"الفئة",group_code:"الكود",group_name:"المجموعة",group_name_en:"الاسم الإنجليزي",activity_code:"النشاط",brand_code:"الكود",brand_name:"البراند",brand_name_en:"الاسم الإنجليزي",brand_group:"المجموعة",show_in_app:"عرض بالتطبيق"} as Record<string,string>)[c]||c}</th>) }<th>الإجراءات</th></tr></thead><tbody>{visible.map(r=><tr key={r.id}>{cfg.columns.map(c=><td key={c}>{c==="is_enabled"||c==="apply_to_all"||c==="is_active"||c==="is_main"||c==="show_in_app"?<span className={r[c]?"foundation-yes":"foundation-no"}>{r[c]?"نعم":"لا"}</span>:c==="policy_value"?<span className="foundation-value">{textValue(r[c]).slice(0,100)||"—"}</span>:textValue(r[c])||"—"}</td>)}<td><div className="foundation-actions"><button title="تعديل" onClick={()=>startEdit(r)}><Pencil size={14}/></button>{kind!=="policies"&&r.is_active!==false&&<button title="تعطيل" onClick={()=>void remove(r)}><X size={14}/></button>}</div></td></tr>)}{!loading&&!visible.length&&<tr><td colSpan={cfg.columns.length+1} className="foundation-empty">لا توجد سجلات مطابقة.</td></tr>}</tbody></table>{loading&&<div className="foundation-empty">جارٍ تحميل البيانات الحقيقية...</div>}</div>}
  <p className="foundation-foot">تُحفظ التعديلات في جداول المشروع الأصلية وتخضع لصلاحيات Supabase وعلاقات البيانات. لا يتم حذف السجلات المرتبطة من هذه الشاشة.</p>
 </section>;
}
