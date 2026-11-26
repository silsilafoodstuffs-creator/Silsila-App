import {useEffect,useMemo,useState} from "react";
import {BriefcaseBusiness,Plus,RefreshCw,Search,UserRound,Users} from "lucide-react";
import {supabase} from "./supabase";
import EditDrawer from "./EditDrawer";

type Employee={id:string;employee_code:string;full_name:string;full_name_en:string|null;phone:string|null;job_title:string|null;department_name:string|null;hire_date:string|null;employment_status:string;is_active:boolean;base_salary:number;branch_id:string|null;department_id:string|null;job_id:string|null;work_location_id:string|null};
type Branch={id:string;branch_code:string;branch_name:string};
type Department={id:string;department_code:string;name_ar:string};
type Job={id:string;job_code:string;name_ar:string;department_id:string|null};
type Location={id:string;location_code:string;name_ar:string};
type Form={fullName:string;branchId:string;departmentId:string;jobId:string;locationId:string;phone:string;hireDate:string;status:string;baseSalary:string;nationalId:string};
const blank:Form={fullName:"",branchId:"",departmentId:"",jobId:"",locationId:"",phone:"",hireDate:"",status:"active",baseSalary:"0",nationalId:""};
const today=()=>new Date().toISOString().slice(0,10);
const money=(v:number)=>new Intl.NumberFormat("ar-EG",{minimumFractionDigits:2,maximumFractionDigits:2}).format(v||0);
const statusLabel=(s:string)=>({active:"نشط",on_leave:"إجازة",suspended:"موقوف",terminated:"منتهي الخدمة"}[s]||s);

export default function LiveEmployeeWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId);
 const canManage=["owner","admin","manager"].includes(role);
 const [employees,setEmployees]=useState<Employee[]>([]);
 const [branches,setBranches]=useState<Branch[]>([]);
 const [departments,setDepartments]=useState<Department[]>([]);
 const [jobs,setJobs]=useState<Job[]>([]);
 const [locations,setLocations]=useState<Location[]>([]);
 const [loading,setLoading]=useState(live);
 const [saving,setSaving]=useState(false);
 const [error,setError]=useState("");
 const [message,setMessage]=useState("");
 const [query,setQuery]=useState("");
 const [drawerOpen,setDrawerOpen]=useState(false);
 const [selected,setSelected]=useState<Employee|null>(null);
 const [form,setForm]=useState<Form>(blank);
 const [initial,setInitial]=useState<Form>(blank);
 const dirty=JSON.stringify(form)!==JSON.stringify(initial);
 const departmentMap=useMemo(()=>new Map(departments.map(x=>[x.id,x])),[departments]);
 const branchMap=useMemo(()=>new Map(branches.map(x=>[x.id,x])),[branches]);
 const jobMap=useMemo(()=>new Map(jobs.map(x=>[x.id,x])),[jobs]);
 const filtered=employees.filter(e=>[e.employee_code,e.full_name,e.department_name||"",e.job_title||"",branchMap.get(e.branch_id||"")?.branch_name||"",statusLabel(e.employment_status)].join(" ").toLocaleLowerCase().includes(query.toLocaleLowerCase()));
 const availableJobs=jobs.filter(j=>!form.departmentId||!j.department_id||j.department_id===form.departmentId);
 const load=async()=>{
  if(!live||!supabase){setLoading(false);return;}
  setLoading(true);setError("");
  const [e,b,d,j,l]=await Promise.all([
   supabase.from("erp_employees").select("id,employee_code,full_name,full_name_en,phone,job_title,department_name,hire_date,employment_status,is_active,base_salary,branch_id,department_id,job_id,work_location_id").eq("company_id",companyId).order("employee_code").range(0,1999),
   supabase.from("erp_branches").select("id,branch_code,branch_name").eq("company_id",companyId).eq("is_active",true).order("branch_code"),
   supabase.from("erp_hr_departments").select("id,department_code,name_ar").eq("company_id",companyId).eq("is_active",true).order("department_code"),
   supabase.from("erp_hr_jobs").select("id,job_code,name_ar,department_id").eq("company_id",companyId).eq("is_active",true).order("job_code"),
   supabase.from("erp_hr_work_locations").select("id,location_code,name_ar").eq("company_id",companyId).eq("is_active",true).order("location_code")
  ]);
  const failure=e.error||b.error||d.error||j.error||l.error;
  if(failure){setError("تعذر تحميل ملفات العاملين: "+failure.message);setLoading(false);return;}
  setEmployees((e.data||[]) as Employee[]);setBranches((b.data||[]) as Branch[]);setDepartments((d.data||[]) as Department[]);setJobs((j.data||[]) as Job[]);setLocations((l.data||[]) as Location[]);
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);
 const openNew=()=>{
  const next={...blank,branchId:branches[0]?.id||""};
  setSelected(null);setForm(next);setInitial(next);setError("");setDrawerOpen(true);
 };
 const openEdit=(row:Employee)=>{
  const next:Form={fullName:row.full_name,branchId:row.branch_id||"",departmentId:row.department_id||"",jobId:row.job_id||"",locationId:row.work_location_id||"",phone:row.phone||"",hireDate:row.hire_date||"",status:row.employment_status||"active",baseSalary:String(row.base_salary||0),nationalId:""};
  setSelected(row);setForm(next);setInitial(next);setError("");setDrawerOpen(true);
 };
 const save=async():Promise<boolean>=>{
  if(!supabase||!companyId)return false;
  if(!canManage){setError("إضافة أو تعديل ملفات الموظفين متاح لمالك المنشأة أو مديرها أو مدير الموارد البشرية.");return false;}
  if(!form.fullName.trim()||!form.branchId){setError("اسم الموظف والفرع مطلوبان.");return false;}
  if(form.nationalId.trim()&&!/^\d{14}$/.test(form.nationalId.trim())){setError("الرقم القومي يجب أن يتكون من 14 رقمًا.");return false;}
  const salary=Number(form.baseSalary);
  if(!Number.isFinite(salary)||salary<0){setError("الراتب الأساسي يجب أن يكون صفرًا أو أكثر.");return false;}
  if(form.hireDate&&form.hireDate>today()){setError("تاريخ التعيين لا يجوز أن يكون في المستقبل.");return false;}
  const department=departmentMap.get(form.departmentId);
  const job=jobMap.get(form.jobId);
  if(job?.department_id&&job.department_id!==form.departmentId){setError("الوظيفة المحددة لا تتبع الإدارة المختارة.");return false;}
  setSaving(true);setError("");setMessage("");
  try{
   if(selected){
    const payload:any={branch_id:form.branchId,full_name:form.fullName.trim(),phone:form.phone.trim()||null,department_id:form.departmentId||null,job_id:form.jobId||null,work_location_id:form.locationId||null,department_name:department?.name_ar||null,job_title:job?.name_ar||null,hire_date:form.hireDate||null,employment_status:form.status,is_active:form.status==="active",base_salary:salary,updated_at:new Date().toISOString()};
    if(form.nationalId.trim())payload.national_id=form.nationalId.trim();
    const {error}=await supabase.from("erp_employees").update(payload).eq("id",selected.id).eq("company_id",companyId);
    if(error)throw error;
    setMessage("تم تعديل ملف الموظف "+selected.employee_code+" بنجاح.");
   }else{
    const {data,error}=await supabase.rpc("erp_create_employee",{p_company_id:companyId,p_branch_id:form.branchId,p_full_name:form.fullName.trim(),p_national_id:form.nationalId.trim()||null,p_phone:form.phone.trim()||null,p_job_title:job?.name_ar||null,p_department_name:department?.name_ar||null,p_base_salary:salary,p_department_id:form.departmentId||null,p_job_id:form.jobId||null,p_work_location_id:form.locationId||null,p_hire_date:form.hireDate||null});
    if(error)throw error;
    setMessage("تم إنشاء ملف الموظف بنجاح. معرّف السجل: "+String(data).slice(0,8));
   }
   setSaving(false);setDrawerOpen(false);setSelected(null);await load();return true;
  }catch(e){setSaving(false);setError("تعذر حفظ ملف الموظف: "+(e instanceof Error?e.message:String(e)));return false;}
 };
 return <section className="live-employee" dir="rtl">
  <div className="live-employee-head"><div className="live-employee-icon"><Users size={23}/></div><div><small>الموارد البشرية · البيانات الرئيسية</small><h2>ملفات الموظفين</h2><p>بيانات العاملين مرتبطة بالفرع والإدارة والوظيفة وموقع العمل في قاعدة سلسلة.</p></div><span>{live?"بيانات مباشرة":"معاينة فقط"}</span></div>
  {error&&!drawerOpen&&<div className="live-employee-error">{error}</div>}{message&&<div className="live-employee-message">{message}</div>}
  {!live&&<div className="live-employee-alert">سجّل الدخول إلى منشأتك لعرض ملفات الموظفين الحقيقية.</div>}
  {live&&<div className="live-employee-panel">
   <div className="live-employee-toolbar"><div><b><BriefcaseBusiness size={16}/> سجل العاملين</b><small>{filtered.length} موظفًا ضمن السجلات المحمّلة</small></div><div><label><Search size={14}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث بالكود أو الاسم أو الإدارة"/></label><button onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button><button className="primary" onClick={openNew} disabled={!canManage||!branches.length}><Plus size={14}/> موظف جديد</button></div></div>
   <div className="live-employee-table-wrap"><table><thead><tr><th>كود الموظف</th><th>اسم الموظف</th><th>الفرع</th><th>الإدارة</th><th>الوظيفة</th><th>تاريخ التعيين</th><th>الراتب الأساسي</th><th>حالة التوظيف</th><th>نشط؟</th><th>الإجراء</th></tr></thead><tbody>{loading?<tr><td colSpan={10}>جارٍ تحميل ملفات الموظفين...</td></tr>:filtered.map(e=><tr key={e.id}><td>{e.employee_code}</td><td><b>{e.full_name}</b></td><td>{branchMap.get(e.branch_id||"")?.branch_name||"—"}</td><td>{e.department_name||departmentMap.get(e.department_id||"")?.name_ar||"—"}</td><td>{e.job_title||jobMap.get(e.job_id||"")?.name_ar||"—"}</td><td>{e.hire_date||"—"}</td><td>{money(Number(e.base_salary))} ج.م</td><td><span className={e.is_active?"active":"inactive"}>{statusLabel(e.employment_status)}</span></td><td><input className="silsila-bool-check" type="checkbox" checked={e.is_active===true} disabled readOnly aria-label={e.is_active===true?"نشط":"لا"}/></td><td><button onClick={()=>openEdit(e)} disabled={!canManage}>تعديل</button></td></tr>)}{!loading&&!filtered.length&&<tr><td colSpan={10}>لا توجد ملفات موظفين مطابقة.</td></tr>}</tbody></table></div>
  </div>}
  {drawerOpen&&<EditDrawer title={selected?"تعديل ملف موظف":"إضافة موظف جديد"} dirty={dirty} saving={saving} error={error} onSave={save} onSaveError={()=>setSaving(false)} onDiscard={()=>{setForm(initial);setError("");}} onClose={()=>{setDrawerOpen(false);setSelected(null);}}>
   <div className="live-employee-form">
    <label>اسم الموظف<input value={form.fullName} onChange={e=>setForm(v=>({...v,fullName:e.target.value}))} maxLength={200}/></label>
    <label>الفرع<select value={form.branchId} onChange={e=>setForm(v=>({...v,branchId:e.target.value}))}><option value="">اختر الفرع</option>{branches.map(b=><option key={b.id} value={b.id}>{b.branch_code} — {b.branch_name}</option>)}</select></label>
    <label>الإدارة / القسم<select value={form.departmentId} onChange={e=>setForm(v=>({...v,departmentId:e.target.value,jobId:""}))}><option value="">اختر الإدارة</option>{departments.map(d=><option key={d.id} value={d.id}>{d.department_code} — {d.name_ar}</option>)}</select></label>
    <label>الوظيفة<select value={form.jobId} onChange={e=>setForm(v=>({...v,jobId:e.target.value}))}><option value="">اختر الوظيفة</option>{availableJobs.map(j=><option key={j.id} value={j.id}>{j.job_code} — {j.name_ar}</option>)}</select></label>
    <label>موقع العمل<select value={form.locationId} onChange={e=>setForm(v=>({...v,locationId:e.target.value}))}><option value="">غير محدد</option>{locations.map(l=><option key={l.id} value={l.id}>{l.location_code} — {l.name_ar}</option>)}</select></label>
    <label>رقم الهاتف<input value={form.phone} onChange={e=>setForm(v=>({...v,phone:e.target.value}))} maxLength={40}/></label>
    <label>تاريخ التعيين<input type="date" value={form.hireDate} max={today()} onChange={e=>setForm(v=>({...v,hireDate:e.target.value}))}/></label>
    <label>الراتب الأساسي (ج.م)<input type="number" min="0" step="0.01" value={form.baseSalary} onChange={e=>setForm(v=>({...v,baseSalary:e.target.value}))}/></label>
    <label>حالة الموظف<select value={form.status} onChange={e=>setForm(v=>({...v,status:e.target.value}))}><option value="active">نشط</option><option value="on_leave">إجازة</option><option value="suspended">موقوف</option><option value="terminated">منتهي الخدمة</option></select></label>
    <label>الرقم القومي (14 رقمًا)<input value={form.nationalId} onChange={e=>setForm(v=>({...v,nationalId:e.target.value.replace(/\D/g,"").slice(0,14)}))} inputMode="numeric" maxLength={14} placeholder={selected?"اتركه فارغًا دون تغيير الرقم الحالي":"قد تشترط سياسة المنشأة إدخاله"}/></label>
    <div className="live-employee-code-note">كود الموظف يُنشأ تلقائيًا من سياسة التكويد المركزية ولا يُكتب يدويًا.</div>
   </div>
  </EditDrawer>}
 </section>;
}
