import {useEffect,useMemo,useState} from "react";
import {Building2,BriefcaseBusiness,MapPin,Plus,RefreshCw,Search} from "lucide-react";
import {supabase} from "./supabase";
import EditDrawer from "./EditDrawer";

type Department={id:string;department_code:string;name_ar:string;name_en:string;department_level:string;parent_id:string|null;work_location_id:string|null;is_active:boolean};
type Job={id:string;job_code:string;name_ar:string;name_en:string;department_id:string|null;is_active:boolean};
type Location={id:string;location_code:string;name_ar:string;location_type:string;address:string|null;is_active:boolean};
type Form={nameAr:string;nameEn:string;level:string;parentId:string;departmentId:string;locationId:string;locationType:string;address:string};
const blank:Form={nameAr:"",nameEn:"",level:"directorate",parentId:"",departmentId:"",locationId:"",locationType:"branch",address:""};
const levelLabel=(v:string)=>({directorate:"إدارة رئيسية",department:"إدارة",section:"قسم"}[v]||v);
const locationLabel=(v:string)=>v==="central"?"إدارة مركزية":"فرع";

export default function LiveHrStructureWorkspace({kind}:{kind:"department"|"job"|"location"}){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId),canManage=["owner","admin","manager"].includes(role);
 const [departments,setDepartments]=useState<Department[]>([]);
 const [jobs,setJobs]=useState<Job[]>([]);
 const [locations,setLocations]=useState<Location[]>([]);
 const [loading,setLoading]=useState(live),[saving,setSaving]=useState(false);
 const [error,setError]=useState(""),[message,setMessage]=useState(""),[query,setQuery]=useState("");
 const [drawerOpen,setDrawerOpen]=useState(false),[selected,setSelected]=useState<Department|Job|Location|null>(null);
 const [form,setForm]=useState<Form>(blank),[initial,setInitial]=useState<Form>(blank);
 const dirty=JSON.stringify(form)!==JSON.stringify(initial);
 const departmentMap=useMemo(()=>new Map(departments.map(x=>[x.id,x])),[departments]);
 const locationMap=useMemo(()=>new Map(locations.map(x=>[x.id,x])),[locations]);
 const title=kind==="department"?"الهيكل التنظيمي":kind==="job"?"الوظائف والتعيينات":"مواقع العمل";
 const codeLabel=kind==="department"?"كود الإدارة":kind==="job"?"كود الوظيفة":"كود الموقع";
 const rows=(kind==="department"?departments:kind==="job"?jobs:locations).filter((row:any)=>[row.department_code||row.job_code||row.location_code,row.name_ar,row.name_en||"",row.department_level||"",row.location_type||"",departmentMap.get(row.department_id||row.parent_id||"")?.name_ar||""].join(" ").toLocaleLowerCase().includes(query.toLocaleLowerCase()));
 const load=async()=>{
  if(!live||!supabase){setLoading(false);return;}
  setLoading(true);setError("");
  const [d,j,l]=await Promise.all([
   supabase.from("erp_hr_departments").select("id,department_code,name_ar,name_en,department_level,parent_id,work_location_id,is_active").eq("company_id",companyId).order("department_code"),
   supabase.from("erp_hr_jobs").select("id,job_code,name_ar,name_en,department_id,is_active").eq("company_id",companyId).order("job_code"),
   supabase.from("erp_hr_work_locations").select("id,location_code,name_ar,location_type,address,is_active").eq("company_id",companyId).order("location_code")
  ]);
  const failure=d.error||j.error||l.error;
  if(failure){setError("تعذر تحميل البيانات التنظيمية: "+failure.message);setLoading(false);return;}
  setDepartments((d.data||[]) as Department[]);setJobs((j.data||[]) as Job[]);setLocations((l.data||[]) as Location[]);setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);
 const openNew=()=>{
  const next={...blank,locationId:locations.find(x=>x.location_type==="central")?.id||locations[0]?.id||"",departmentId:departments.find(x=>x.department_level!=="section")?.id||""};
  setSelected(null);setForm(next);setInitial(next);setError("");setDrawerOpen(true);
 };
 const openEdit=(row:Department|Job|Location)=>{
  const next:Form=kind==="department"?{...blank,nameAr:(row as Department).name_ar,nameEn:(row as Department).name_en||"",level:(row as Department).department_level,parentId:(row as Department).parent_id||"",locationId:(row as Department).work_location_id||""}:kind==="job"?{...blank,nameAr:(row as Job).name_ar,nameEn:(row as Job).name_en||"",departmentId:(row as Job).department_id||""}:{...blank,nameAr:(row as Location).name_ar,locationType:(row as Location).location_type,address:(row as Location).address||""};
  setSelected(row);setForm(next);setInitial(next);setError("");setDrawerOpen(true);
 };
 const save=async():Promise<boolean>=>{
  if(!supabase||!companyId)return false;
  if(!canManage){setError("تعديل البيانات التنظيمية متاح لمالك المنشأة أو مديرها أو مدير الموارد البشرية.");return false;}
  if(!form.nameAr.trim()){setError("الاسم بالعربية مطلوب.");return false;}
  if(kind==="department"){
   if(!form.locationId){setError("اختر موقع العمل للإدارة.");return false;}
   if(form.level!=="directorate"&&!form.parentId){setError("اختر الإدارة الأب للمستوى التابع.");return false;}
   if(selected&&form.parentId===selected.id){setError("لا يمكن أن تتبع الإدارة نفسها.");return false;}
   const parent=departmentMap.get(form.parentId);
   if(form.level==="department"&&parent&&parent.department_level!=="directorate"){setError("الإدارة يجب أن تتبع إدارة رئيسية.");return false;}
   if(form.level==="section"&&parent&&parent.department_level!=="department"){setError("القسم يجب أن يتبع إدارة.");return false;}
  }
  if(kind==="job"&&!form.departmentId){setError("اختر الإدارة التابعة للوظيفة.");return false;}
  setSaving(true);setError("");setMessage("");
  try{
   if(kind==="department"){
    const payload={company_id:companyId,department_code:selected?(selected as Department).department_code:"",name_ar:form.nameAr.trim(),name_en:form.nameEn.trim(),department_level:form.level,parent_id:form.level==="directorate"?null:form.parentId,work_location_id:form.locationId,is_active:selected?selected.is_active:true};
    const result=selected?await supabase.from("erp_hr_departments").update(payload).eq("id",selected.id).eq("company_id",companyId):await supabase.from("erp_hr_departments").insert(payload);
    if(result.error)throw result.error;
   }else if(kind==="job"){
    const payload={company_id:companyId,job_code:selected?(selected as Job).job_code:"",name_ar:form.nameAr.trim(),name_en:form.nameEn.trim(),department_id:form.departmentId,is_active:selected?selected.is_active:true};
    const result=selected?await supabase.from("erp_hr_jobs").update(payload).eq("id",selected.id).eq("company_id",companyId):await supabase.from("erp_hr_jobs").insert(payload);
    if(result.error)throw result.error;
   }else{
    const payload={company_id:companyId,location_code:selected?(selected as Location).location_code:"",name_ar:form.nameAr.trim(),location_type:form.locationType,address:form.address.trim()||null,is_active:selected?selected.is_active:true};
    const result=selected?await supabase.from("erp_hr_work_locations").update(payload).eq("id",selected.id).eq("company_id",companyId):await supabase.from("erp_hr_work_locations").insert(payload);
    if(result.error)throw result.error;
   }
   setSaving(false);setDrawerOpen(false);setSelected(null);setMessage("تم حفظ "+title+" بنجاح وفق سياسة التكويد المركزية.");await load();return true;
  }catch(e){setSaving(false);setError("تعذر حفظ البيانات: "+(e instanceof Error?e.message:String(e)));return false;}
 };
 return <section className="live-hr-structure" dir="rtl">
  <div className="live-hr-structure-head"><div className="live-hr-structure-icon">{kind==="department"?<Building2 size={22}/>:kind==="job"?<BriefcaseBusiness size={22}/>:<MapPin size={22}/>}</div><div><small>الموارد البشرية · البيانات الرئيسية</small><h2>{title}</h2><p>{kind==="department"?"بناء الإدارات والأقسام وربطها بمواقع العمل.":kind==="job"?"تعريف الوظائف وربط كل وظيفة بالإدارة التابعة لها.":"إدارة مواقع العمل المركزية ومواقع الفروع."}</p></div><span>{live?"بيانات مباشرة":"معاينة فقط"}</span></div>
  {error&&!drawerOpen&&<div className="live-hr-structure-error">{error}</div>}{message&&<div className="live-hr-structure-message">{message}</div>}
  {!live&&<div className="live-hr-structure-alert">سجّل الدخول إلى المنشأة لعرض البيانات التنظيمية الفعلية.</div>}
  {live&&<div className="live-hr-structure-panel"><div className="live-hr-structure-toolbar"><div><b>{title}</b><small>{rows.length} سجلًا في القائمة</small></div><div><label><Search size={14}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث بالكود أو الاسم"/></label><button onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button><button className="primary" onClick={openNew} disabled={!canManage}><Plus size={14}/> إضافة</button></div></div>
   <div className="live-hr-structure-table-wrap"><table><thead><tr><th>{codeLabel}</th><th>الاسم بالعربية</th><th>{kind==="department"?"المستوى":kind==="job"?"الإدارة":"النوع"}</th><th>{kind==="department"?"الإدارة الأب":kind==="job"?"الاسم بالإنجليزية":"العنوان"}</th><th>{kind==="department"?"موقع العمل":kind==="job"?"الإدارة":"العنوان"}</th><th>نشط؟</th><th>إجراء</th></tr></thead><tbody>{loading?<tr><td colSpan={7}>جارٍ التحميل...</td></tr>:rows.map((row:any)=><tr key={row.id}><td>{row.department_code||row.job_code||row.location_code}</td><td><b>{row.name_ar}</b></td><td>{kind==="department"?levelLabel(row.department_level):kind==="job"?departmentMap.get(row.department_id||"")?.name_ar||"—":locationLabel(row.location_type)}</td><td>{kind==="department"?departmentMap.get(row.parent_id||"")?.name_ar||"—":kind==="job"?row.name_en||"—":row.address||"—"}</td><td>{kind==="department"?locationMap.get(row.work_location_id||"")?.name_ar||"—":kind==="job"?departmentMap.get(row.department_id||"")?.name_ar||"—":row.address||"—"}</td><td><input className="silsila-bool-check" type="checkbox" checked={row.is_active===true} disabled readOnly aria-label={row.is_active===true?"نشط":"لا"}/></td><td><button onClick={()=>openEdit(row)} disabled={!canManage}>تعديل</button></td></tr>)}{!loading&&!rows.length&&<tr><td colSpan={7}>لا توجد سجلات مطابقة.</td></tr>}</tbody></table></div>
  </div>}
  {drawerOpen&&<EditDrawer title={selected?"تعديل "+title:"إضافة "+title} dirty={dirty} saving={saving} error={error} onSave={save} onSaveError={()=>setSaving(false)} onDiscard={()=>{setForm(initial);setError("");}} onClose={()=>{setDrawerOpen(false);setSelected(null);}}>
   <div className="live-hr-structure-form">
    <label>الاسم بالعربية<input value={form.nameAr} onChange={e=>setForm(v=>({...v,nameAr:e.target.value}))} maxLength={150}/></label>
    {kind!=="location"&&<label>الاسم بالإنجليزية<input value={form.nameEn} onChange={e=>setForm(v=>({...v,nameEn:e.target.value}))} maxLength={150}/></label>}
    {kind==="department"&&<>
     <label>المستوى التنظيمي<select value={form.level} onChange={e=>setForm(v=>({...v,level:e.target.value,parentId:e.target.value==="directorate"?"":v.parentId}))}><option value="directorate">إدارة رئيسية</option><option value="department">إدارة</option><option value="section">قسم</option></select></label>
     {form.level!=="directorate"&&<label>يتبع الإدارة<select value={form.parentId} onChange={e=>setForm(v=>({...v,parentId:e.target.value}))}><option value="">اختر الإدارة الأب</option>{departments.filter(d=>d.id!==selected?.id&&(form.level==="department"?d.department_level==="directorate":d.department_level==="department")).map(d=><option key={d.id} value={d.id}>{d.department_code} — {d.name_ar}</option>)}</select></label>}
     <label>موقع العمل<select value={form.locationId} onChange={e=>setForm(v=>({...v,locationId:e.target.value}))}><option value="">اختر موقع العمل</option>{locations.filter(l=>l.is_active).map(l=><option key={l.id} value={l.id}>{l.location_code} — {l.name_ar}</option>)}</select></label>
    </>}
    {kind==="job"&&<label>الإدارة التابعة<select value={form.departmentId} onChange={e=>setForm(v=>({...v,departmentId:e.target.value}))}><option value="">اختر الإدارة</option>{departments.filter(d=>d.is_active&&d.department_level!=="section").map(d=><option key={d.id} value={d.id}>{d.department_code} — {d.name_ar}</option>)}</select></label>}
    {kind==="location"&&<><label>نوع الموقع<select value={form.locationType} onChange={e=>setForm(v=>({...v,locationType:e.target.value}))}><option value="central">إدارة مركزية</option><option value="branch">فرع</option></select></label><label>العنوان<input value={form.address} onChange={e=>setForm(v=>({...v,address:e.target.value}))} maxLength={300}/></label></>}
    <div className="live-hr-structure-code-note">الكود يُنشأ تلقائيًا وفق سياسة التكويد المركزية ولا يُكتب يدويًا.</div>
   </div>
  </EditDrawer>}
 </section>;
}
