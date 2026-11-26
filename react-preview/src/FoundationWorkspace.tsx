import {useCallback,useEffect,useMemo,useState} from "react";
import {supabase} from "./supabase";
import EditDrawer from "./EditDrawer";
import {Building2,GitBranch,Layers3,Tags,Award,SlidersHorizontal,Search,RefreshCw,Plus,Pencil,Save,X,CheckCircle2,Database,AlertTriangle} from "lucide-react";

type Kind="policies"|"company"|"branches"|"activities"|"activity-categories"|"brand-groups"|"brands";
type Row=Record<string,any>;
type Geo={id:string;parent_id:string|null;name_ar:string;level:"governorate"|"district"|"area";geo_code?:string};
type Field={key:string;label:string;required?:boolean;type?:"select"|"number"|"email"|"tel";options?:string[]};
const defs:Record<Kind,{title:string;table:string;icon:any;description:string;columns:string[];fields:Field[];search:string[];companyScoped:boolean}> = {
 policies:{title:"سياسات البرنامج",table:"erp_program_policies",icon:SlidersHorizontal,description:"السياسات الفعلية المحفوظة للمؤسسة: التشغيل والتكويد والهوية وباقي الإعدادات.",columns:["policy_code","category","name_ar","policy_value","is_enabled","apply_to_all"],fields:[{key:"policy_value",label:"قيمة السياسة"}],search:["policy_code","policy_key","name_ar","name_en","category"],companyScoped:true},
 company:{title:"بيانات الشركة",table:"erp_companies",icon:Building2,description:"البيانات القانونية والتجارية ووسائل الاتصال والعملة والبيانات الإضافية.",columns:["legal_name","trade_name","tax_number","commercial_register","phone","email","base_currency","address"],fields:[{key:"legal_name",label:"الاسم القانوني",required:true},{key:"trade_name",label:"الاسم التجاري"},{key:"tax_number",label:"الرقم الضريبي"},{key:"commercial_register",label:"السجل التجاري"},{key:"phone",label:"الهاتف",type:"tel"},{key:"email",label:"البريد الإلكتروني",type:"email"},{key:"base_currency",label:"العملة",required:true,options:["EGP","USD","SAR","AED","KWD","EUR","GBP"]},{key:"address",label:"العنوان"},{key:"english_name",label:"الاسم بالإنجليزية"},{key:"company_code",label:"كود الشركة"},{key:"tax_office",label:"مأمورية الضرائب"},{key:"country",label:"الدولة"}],search:["legal_name","trade_name","phone"],companyScoped:true},
 branches:{title:"فروع الشركة",table:"erp_branches",icon:GitBranch,description:"الفروع الفعلية التابعة للشركة مع بيانات الاتصال والعنوان والحالة.",columns:["branch_code","branch_name","branch_name_en","phone","email","governorate_id","district_id","area_id","address","is_main","is_active"],fields:[{key:"branch_code",label:"كود الفرع",required:true},{key:"branch_name",label:"اسم الفرع",required:true},{key:"branch_name_en",label:"الاسم بالإنجليزية"},{key:"phone",label:"الهاتف",type:"tel"},{key:"phone2",label:"هاتف إضافي",type:"tel"},{key:"email",label:"البريد الإلكتروني",type:"email"},{key:"governorate_id",label:"المحافظة"},{key:"district_id",label:"المركز / الحي"},{key:"area_id",label:"المنطقة"},{key:"address",label:"العنوان"},{key:"location",label:"وصف الموقع"}],search:["branch_code","branch_name","branch_name_en","phone","address","location"],companyScoped:true},
 activities:{title:"الأنشطة",table:"activity_types",icon:Layers3,description:"الدليل الرئيسي لأنشطة سلسلة، مع الكود والترتيب والظهور في التطبيق.",columns:["code","name","name_en","sort_order","is_active","show_in_app"],fields:[{key:"code",label:"كود النشاط",required:true},{key:"name",label:"اسم النشاط",required:true},{key:"name_en",label:"الاسم بالإنجليزية"},{key:"sort_order",label:"ترتيب العرض",type:"number"}],search:["code","name","name_en"],companyScoped:false},
 "activity-categories":{title:"فئات الأنشطة",table:"erp_activity_customer_categories",icon:Tags,description:"الفئات المرتبطة بكل نشاط ومساحة عمل كما هي محفوظة في المشروع القديم.",columns:["activity_type","activity_name","customer_category","is_active"],fields:[{key:"activity_type",label:"النشاط / مساحة العمل",required:true},{key:"activity_name",label:"اسم النشاط (تلقائي)",required:true},{key:"customer_category",label:"اسم الفئة",required:true}],search:["activity_type","activity_name","customer_category"],companyScoped:true},
 "brand-groups":{title:"مجموعات البراندات",table:"erp_brand_groups",icon:Layers3,description:"مجموعات العلامات التجارية حسب النشاط، مع الحفاظ على أكواد المجموعات الحالية.",columns:["group_code","group_name","group_name_en","activity_code","is_active","show_in_app"],fields:[{key:"group_code",label:"كود المجموعة",required:true},{key:"group_name",label:"اسم المجموعة",required:true},{key:"group_name_en",label:"الاسم بالإنجليزية"},{key:"activity_code",label:"النشاط",required:true}],search:["group_code","group_name","group_name_en","activity_code"],companyScoped:true},
 brands:{title:"البراندات",table:"erp_brands",icon:Award,description:"العلامات التجارية وربط كل براند بنشاط ومجموعة، مع الاحتفاظ بالصور والترتيب الحاليين.",columns:["brand_code","brand_name","brand_name_en","brand_group","activity_code","is_active","show_in_app"],fields:[{key:"brand_code",label:"كود البراند",required:true},{key:"brand_name",label:"اسم البراند",required:true},{key:"brand_name_en",label:"الاسم بالإنجليزية"},{key:"activity_code",label:"النشاط",required:true},{key:"brand_group_id",label:"مجموعة البراند",required:true,type:"select"}],search:["brand_code","brand_name","brand_name_en","brand_group","activity_code"],companyScoped:true}
};
const textValue=(v:any)=>v==null?"":String(v);
const permissionAliases:Record<Kind,string[]> = {
 policies:["إدارة البرنامج::بيانات أساسية::إعدادات البرنامج"],
 company:["إدارة البرنامج::بيانات أساسية::بيانات الشركة"],
 branches:["إدارة البرنامج::بيانات أساسية::الفروع ومراكز التكلفة"],
 activities:[],
 "activity-categories":[],
 "brand-groups":[],
 brands:[]
};
export default function FoundationWorkspace({kind}:{kind:Kind}){
 const cfg=defs[kind],Icon=cfg.icon;
 const [companyId]=useState(()=>sessionStorage.getItem("silsila-company-id")||"");
 const [userId]=useState(()=>sessionStorage.getItem("silsila-user-id")||"");
 const [role]=useState(()=>sessionStorage.getItem("silsila-member-role")||"viewer");
 const [rows,setRows]=useState<Row[]>([]),[query,setQuery]=useState(""),[category,setCategory]=useState("الكل"),[columnQueries,setColumnQueries]=useState<Record<string,string>>({});
 const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[error,setError]=useState(""),[notice,setNotice]=useState("");
 const [editing,setEditing]=useState<Row|null>(null),[form,setForm]=useState<Row>({}),[formOriginal,setFormOriginal]=useState<Row>({});
 const [extra,setExtra]=useState<Row>({}),[activities,setActivities]=useState<Row[]>([]),[groups,setGroups]=useState<Row[]>([]);
 const [permissions,setPermissions]=useState<Row[]>([]),[permissionsReady,setPermissionsReady]=useState(false);
 const [geographies,setGeographies]=useState<Geo[]>([]),[companyEditing,setCompanyEditing]=useState(false),[confirmCompanySave,setConfirmCompanySave]=useState(false);
 const adminRole=["owner","admin"].includes(role);
 const permissionKey="إعدادات عامة::بيانات أساسية::"+cfg.title;
 const permission=permissions.find(p=>[permissionKey,...permissionAliases[kind]].includes(p.menu_key))||permissions.find(p=>p.menu_key==="إعدادات عامة::بيانات أساسية::*")||permissions.find(p=>p.menu_key==="إعدادات عامة::*::*")||permissions.find(p=>p.menu_key==="إدارة البرنامج::بيانات أساسية::*")||permissions.find(p=>p.menu_key==="إدارة البرنامج::*::*");
 const roleCanWrite=kind==="company"?adminRole:(kind==="policies"||kind==="activities"||kind==="brand-groups"||kind==="brands")?adminRole:kind==="activity-categories"?["owner","admin","manager"].includes(role):["owner","admin","manager","operator","accountant"].includes(role);
 const canRead=!permissionsReady||permission?.allow_access!==false;
 const canAdd=permissionsReady&&canRead&&(permission?permission.can_add===true:(kind!=="company"&&kind!=="policies"&&roleCanWrite));
 const canEdit=permissionsReady&&canRead&&(permission?(permission.can_edit===true||permission.can_save===true):roleCanWrite);
 const canDeactivate=permissionsReady&&canRead&&(permission?permission.can_delete===true:adminRole);
 const groupsForActivity=groups.filter(g=>!form.activity_code||g.activity_code===form.activity_code);
 const governorates=geographies.filter(g=>g.level==="governorate");
 const districts=geographies.filter(g=>g.level==="district"&&g.parent_id===form.governorate_id);
 const areas=geographies.filter(g=>g.level==="area"&&g.parent_id===form.district_id);
 const load=useCallback(async()=>{
  if(!supabase){setError("اتصال قاعدة البيانات غير مهيأ.");setLoading(false);return;}
  if(!companyId){setError("لا توجد شركة نشطة في جلسة الدخول.");setLoading(false);return;}
  setLoading(true);setError("");setNotice("");
  try{
   if(!userId)throw new Error("جلسة المستخدم غير مكتملة. أعد تسجيل الدخول.");
   const {data:permissionRows,error:permissionError}=await supabase.from("erp_user_permissions").select("menu_key,allow_access,can_add,can_edit,can_delete,can_save").eq("company_id",companyId).eq("user_id",userId);
   if(permissionError)throw permissionError;
   const loadedPermissions=permissionRows||[];setPermissions(loadedPermissions);setPermissionsReady(true);
   const exact=loadedPermissions.find((p:any)=>[ "إعدادات عامة::بيانات أساسية::"+cfg.title,...permissionAliases[kind] ].includes(p.menu_key))||loadedPermissions.find((p:any)=>p.menu_key==="إعدادات عامة::بيانات أساسية::*")||loadedPermissions.find((p:any)=>p.menu_key==="إعدادات عامة::*::*")||loadedPermissions.find((p:any)=>p.menu_key==="إدارة البرنامج::بيانات أساسية::*")||loadedPermissions.find((p:any)=>p.menu_key==="إدارة البرنامج::*::*");
   if(exact?.allow_access===false)throw new Error("لا تملك صلاحية عرض هذه الشاشة.");
   if(kind==="company"){
    const {data,error}=await supabase.from("erp_companies").select("id,legal_name,trade_name,tax_number,commercial_register,phone,email,address,base_currency,is_active").eq("id",companyId).maybeSingle();
    if(error)throw error;if(!data)throw new Error("لم يتم العثور على بيانات الشركة أو لا توجد صلاحية لعرضها.");
    const {data:extraRow}=await supabase.from("erp_company_settings").select("setting_value").eq("company_id",companyId).eq("setting_key","company_profile_extra").maybeSingle();
    const merged={...data,...(extraRow?.setting_value||{})};setRows([merged]);setExtra(extraRow?.setting_value||{});setEditing(null);setForm(merged);setFormOriginal(merged);
   }else{
    let q=supabase.from(cfg.table).select(kind==="policies"?"id,company_id,policy_key,policy_code,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value":kind==="brands"?"id,company_id,brand_code,brand_name,brand_name_en,brand_group,brand_group_id,activity_code,is_active,show_in_app,display_order,is_system":kind==="brand-groups"?"id,company_id,group_code,group_name,group_name_en,activity_code,is_active,show_in_app":kind==="branches"?"id,company_id,branch_code,branch_name,branch_name_en,phone,phone2,email,address,location,governorate_id,district_id,area_id,is_main,is_active":"*");
    if(cfg.companyScoped)q=q.eq("company_id",companyId);
    if(kind==="activity-categories"){
      const {data:ws,error:wsError}=await supabase.from("erp_business_workspaces").select("id,workspace_name,activity_type,platform_company_id").eq("platform_company_id",companyId).eq("is_active",true);
      if(wsError)throw wsError;
      const ids=(ws||[]).map((x:any)=>x.id);setActivities(ws||[]);
      if(!ids.length){setRows([]);setLoading(false);return;}
      q=q.in("workspace_id",ids);
    }
    const order=kind==="policies"?"category":kind==="activities"?"sort_order":kind==="activity-categories"?"activity_name":kind==="brand-groups"?"group_code":kind==="brands"?"brand_code":"branch_code";
    const {data,error}=await q.order(order,{ascending:true});if(error)throw error;
    if(kind==="branches"){
     const {data:geoBase,error:geoError}=await supabase.from("erp_geographic_data").select("id,parent_id,name_ar,level,geo_code").eq("company_id",companyId).eq("is_active",true).in("level",["governorate","district"]).order("name_ar");
     if(geoError)throw geoError;
     const districtIds=[...new Set((data||[]).map((r:any)=>r.district_id).filter(Boolean))];
     let selectedAreas:Geo[]=[];
     if(districtIds.length){const {data:areaRows,error:areaError}=await supabase.from("erp_geographic_data").select("id,parent_id,name_ar,level,geo_code").eq("company_id",companyId).eq("is_active",true).eq("level","area").in("parent_id",districtIds).order("name_ar");if(areaError)throw areaError;selectedAreas=(areaRows||[]) as Geo[];}
     setGeographies([...((geoBase||[]) as Geo[]),...selectedAreas]);
    }
    setRows(data||[]);
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
 const visible=useMemo(()=>rows.filter(r=>(!query.trim()||cfg.search.some(k=>textValue(r[k]).toLowerCase().includes(query.trim().toLowerCase())))&&(category==="الكل"||r.category===category)&&cfg.columns.every(k=>textValue(r[k]).toLowerCase().includes((columnQueries[k]||"").toLowerCase()))),[rows,query,category,cfg,columnQueries]);
 const startNew=()=>{
  if(kind==="company"){const current=rows[0]||{};setEditing(current);setForm({...current});setFormOriginal({...current});return;}
  setEditing(null);const initial:Row={is_active:true,show_in_app:true,apply_to_all:true};
  if(kind==="branches"){initial.governorate_id="";initial.district_id="";initial.area_id="";}
  if(kind==="activities"){initial.id=Math.max(0,...rows.map(r=>Number(r.id)||0))+1;initial.code="ACT"+String(Math.max(0,...rows.map(r=>Number(String(r.code||"").replace(/\D/g,""))||0))+1).padStart(3,"0");initial.sort_order=rows.length+1;}
  if(kind==="activity-categories"){initial.workspace_id=activities[0]?.id||"";initial.activity_type=activities[0]?.activity_type||"";initial.activity_name=activities[0]?.workspace_name||"";}
  if(kind==="brand-groups"){initial.activity_code=activities[0]?.code||"ACT001";}
  if(kind==="brands"){initial.activity_code=activities[0]?.code||"ACT001";initial.brand_group_id=groups[0]?.id||"";}
  setForm(initial);setFormOriginal({...initial});
 };
 const startEdit=(r:Row)=>{if(kind==="company"){setForm({...r});setFormOriginal({...r});setCompanyEditing(true);return;}setEditing(r);setForm({...r});setFormOriginal({...r});};
 const setField=(key:string,value:any)=>setForm((old:Row)=>({...old,[key]:value}));
 const save=async():Promise<boolean>=>{
  if(!supabase)return false;
  for(const f of cfg.fields){if(f.required&&!textValue(form[f.key]).trim()){setError("حقل «"+f.label+"» مطلوب.");return false;}}
  setSaving(true);setError("");setNotice("");
  try{
   if(kind==="company"){
    const payload={legal_name:textValue(form.legal_name).trim(),trade_name:textValue(form.trade_name).trim()||null,tax_number:textValue(form.tax_number).trim()||null,commercial_register:textValue(form.commercial_register).trim()||null,phone:textValue(form.phone).trim()||null,email:textValue(form.email).trim()||null,address:textValue(form.address).trim()||null,base_currency:textValue(form.base_currency||"EGP").trim().toUpperCase()};
    if(!canEdit)throw new Error("لا تملك صلاحية تعديل بيانات الشركة.");
    const {data:updatedCompany,error}=await supabase.from("erp_companies").update(payload).eq("id",companyId).select("id").single();if(error)throw error;if(!updatedCompany)throw new Error("لم يتم تأكيد تحديث بيانات الشركة.");
    const current=await supabase.auth.getUser();const extras={...extra,english_name:textValue(form.english_name),company_code:textValue(form.company_code),tax_office:textValue(form.tax_office),country:textValue(form.country||"مصر"),phone2:textValue(form.phone2),logo_path:extra.logo_path||""};
    const {data:updatedExtra,error:extraError}=await supabase.from("erp_company_settings").upsert({company_id:companyId,setting_key:"company_profile_extra",setting_value:extras,updated_by:current.data.user?.id||null},{onConflict:"company_id,setting_key"}).select("company_id").single();if(extraError)throw extraError;if(!updatedExtra)throw new Error("لم يتم تأكيد حفظ البيانات الإضافية.");
   }else if(kind==="policies"){
    if(!canEdit)throw new Error("لا تملك صلاحية تعديل سياسات البرنامج.");
    if(!editing?.id)throw new Error("لا يمكن إنشاء سياسة غير معرفة في دليل سياسات المشروع.");
    if(["visual_identity.screen_title_color","visual_identity.table_header_color","visual_identity.table_header_text_color","visual_identity.table_row_alt_color","visual_identity.table_row_hover_color"].includes(editing.policy_key)&&!/^#[0-9a-fA-F]{6}$/.test(textValue(form.policy_value)))throw new Error("قيمة اللون غير صحيحة. استخدم كود HEX مثل #FFA015.");
    const {data:updatedPolicy,error}=await supabase.from(cfg.table).update({policy_value:textValue(form.policy_value),is_enabled:form.is_enabled===true,apply_to_all:form.apply_to_all===true,updated_at:new Date().toISOString()}).eq("id",editing.id).eq("company_id",companyId).select("id").single();if(error)throw error;if(!updatedPolicy)throw new Error("لم يتم تأكيد تحديث السياسة.");
   }else{
    if(editing?.id&&!canEdit)throw new Error("لا تملك صلاحية تعديل هذا السجل.");
    if(!editing?.id&&!canAdd)throw new Error("لا تملك صلاحية إضافة سجلات جديدة.");
    const payload:Row={...form};
    const nextActivityId=payload.id;
    delete payload.id;delete payload.created_at;delete payload.updated_at;
    if(kind==="activities"&&!editing?.id)payload.id=nextActivityId;
    if(kind==="branches"){
     const governorate=geographies.find(g=>g.id===payload.governorate_id&&g.level==="governorate");
     const district=geographies.find(g=>g.id===payload.district_id&&g.level==="district"&&g.parent_id===payload.governorate_id);
     const area=geographies.find(g=>g.id===payload.area_id&&g.level==="area"&&g.parent_id===payload.district_id);
     if(payload.governorate_id&&!governorate)throw new Error("اختر محافظة صحيحة.");
     if(payload.district_id&&!district)throw new Error("المركز أو الحي يجب أن يتبع المحافظة المختارة.");
     if(payload.area_id&&!area)throw new Error("المنطقة يجب أن تتبع المركز أو الحي المختار.");
    }
    if(kind==="activity-categories"){
     payload.workspace_id=payload.workspace_id||activities[0]?.id;
     if(!payload.workspace_id)throw new Error("لا توجد مساحة نشاط مرتبطة بالشركة.");
     const workspace=activities.find(x=>x.id===payload.workspace_id);
     if(!workspace)throw new Error("اختر مساحة نشاط صحيحة.");
     if(!textValue(workspace.activity_type).trim())throw new Error("مساحة العمل المحددة غير مرتبطة بنوع نشاط صالح.");
     payload.activity_type=workspace.activity_type;payload.activity_name=workspace.workspace_name;
    }
    if(kind==="brand-groups"){
     if(!activities.some(a=>a.code===payload.activity_code))throw new Error("اختر نشاطًا صحيحًا لمجموعة البراندات.");
     if(!/^Brg[0-9]{2}$/.test(textValue(payload.group_code)))throw new Error("كود مجموعة البراندات يجب أن يكون بالشكل Brg01.");
    }
    if(kind==="brands"){
     const g=groups.find(x=>x.id===payload.brand_group_id&&x.activity_code===payload.activity_code);
     if(!g)throw new Error("اختر مجموعة براندات تابعة للنشاط المحدد.");
     payload.brand_group=g.group_name;
    }
    if(cfg.companyScoped)payload.company_id=companyId;
    if(editing?.id){
     const {data:updated,error}=await supabase.from(cfg.table).update(payload).eq("id",editing.id).eq(cfg.companyScoped?"company_id":"id",cfg.companyScoped?companyId:editing.id).select("id").single();
     if(error)throw error;if(!updated)throw new Error("لم يتم تأكيد تحديث السجل.");
    }else{
     const {data:created,error}=await supabase.from(cfg.table).insert(payload).select("id").single();
     if(error)throw error;if(!created)throw new Error("لم يتم تأكيد إنشاء السجل.");
    }
   }
   setNotice("تم حفظ التعديلات في قاعدة البيانات بنجاح.");await load();setEditing(null);if(kind==="company"){setCompanyEditing(false);setFormOriginal({...form});}return true;
  }catch(e:any){setError("لم يتم الحفظ: "+(e?.message||String(e)));return false;}
  finally{setSaving(false);}
 };
 const remove=async(r:Row)=>{
  if(!supabase||kind==="policies"||kind==="company")return;
  if(!canDeactivate){setError("لا تملك صلاحية تعطيل هذا السجل.");return;}
  if(!window.confirm("تأكيد تعطيل السجل؟ سيتم تغيير حالته دون حذف البيانات المرتبطة."))return;
  const {data:updated,error:deactivateError}=await supabase.from(cfg.table).update({is_active:false}).eq("id",r.id).eq(cfg.companyScoped?"company_id":"id",cfg.companyScoped?companyId:r.id).select("id").single();
  if(deactivateError)setError("تعذر تعطيل السجل: "+deactivateError.message);else if(!updated)setError("لم يتم تأكيد تعطيل السجل.");else{setNotice("تم تعطيل السجل دون حذفه.");await load();}
 };
 const policyCategories=["الكل",...Array.from(new Set(rows.map(r=>r.category).filter(Boolean)))];
 return <section className="foundation-workspace" dir="rtl">
  <header className="foundation-head"><span><Icon size={22}/></span><div><small>سلسلة · البيانات الفعلية للمشروع القديم</small><h2>{cfg.title}</h2><p>{cfg.description}</p></div><b><Database size={15}/>{rows.length.toLocaleString("ar-EG")} سجل</b></header>
  {error&&<div className="foundation-error"><AlertTriangle size={16}/>{error}</div>}{notice&&<div className="foundation-notice"><CheckCircle2 size={16}/>{notice}</div>}{!canRead&&<div className="foundation-error"><AlertTriangle size={16}/>لا تملك صلاحية عرض هذه الشاشة.</div>}
  {kind!=="company"&&<div className="foundation-tools"><label><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="ابحث بالكود أو الاسم..."/></label>{kind==="policies"&&<select value={category} onChange={e=>setCategory(e.target.value)}>{policyCategories.map(x=><option key={x}>{x}</option>)}</select>}<button onClick={()=>void load()}><RefreshCw size={15}/> تحديث</button>{kind!=="policies"&&<button className="foundation-add" onClick={startNew} disabled={!canAdd}><Plus size={15}/> إضافة جديد</button>}</div>}
  {kind==="company"&&<div className="foundation-tools"><span>بيانات الشركة المسجلة حاليًا</span><button onClick={()=>void load()}><RefreshCw size={15}/> تحديث</button><button className="foundation-add" onClick={()=>startEdit(rows[0]||{})} disabled={!canEdit||!rows.length}><Pencil size={15}/> تعديل البيانات</button></div>}
  {editing&&<EditDrawer canEdit={canEdit} initialMode={Boolean(editing?.id)?"view":"edit"} title={kind==="company"?"تعديل بيانات الشركة":kind==="policies"?"تعديل السياسة: "+(editing.name_ar||editing.policy_key):editing.id?"تعديل سجل":"إضافة سجل جديد"} dirty={JSON.stringify(form)!==JSON.stringify(formOriginal)} saving={saving} error={error} onSaveError={()=>setSaving(false)} onSave={save} onDiscard={()=>{setForm(formOriginal);setError("");setNotice("");}} onClose={()=>setEditing(null)}><div className="foundation-editor"><div className="foundation-editor-head"><b>{kind==="company"?"تعديل بيانات الشركة":kind==="policies"?"تعديل السياسة: "+(editing.name_ar||editing.policy_key):editing.id?"تعديل سجل":"إضافة سجل جديد"}</b><button onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))} aria-label="إغلاق"><X size={17}/></button></div>
   {kind==="policies"? <div className="foundation-form">
    {String(editing.policy_key||"").startsWith("visual_identity.")&&["visual_identity.screen_title_color","visual_identity.table_header_color","visual_identity.table_header_text_color","visual_identity.table_row_alt_color","visual_identity.table_row_hover_color"].includes(editing.policy_key)?
     <label className="foundation-color-editor"><span>قيمة اللون</span><div><input type="color" aria-label="اختيار اللون" value={/^#[0-9a-fA-F]{6}$/.test(textValue(form.policy_value))?textValue(form.policy_value):"#3E007D"} onChange={e=>setField("policy_value",e.target.value.toUpperCase())}/><input type="text" dir="ltr" spellCheck={false} value={textValue(form.policy_value)} onChange={e=>setField("policy_value",e.target.value.toUpperCase())} placeholder="#3E007D"/><i style={{background:/^#[0-9a-fA-F]{6}$/.test(textValue(form.policy_value))?textValue(form.policy_value):"#ffffff"}}/></div><small>أدخل كود HEX من 6 خانات أو اختر اللون من المنتقي.</small></label>:
     <label><span>قيمة السياسة</span><textarea value={textValue(form.policy_value)} onChange={e=>setField("policy_value",e.target.value)}/></label>}
    <label className="foundation-check"><input type="checkbox" checked={form.is_enabled===true} disabled={editing.policy_key==="data_integrity.prevent_delete_with_references"} onChange={e=>setField("is_enabled",e.target.checked)}/> السياسة مفعّلة</label>
    <label className="foundation-check"><input type="checkbox" checked={form.apply_to_all===true} disabled={editing.policy_key==="data_integrity.prevent_delete_with_references"} onChange={e=>setField("apply_to_all",e.target.checked)}/> تطبق على جميع المستخدمين</label>
    <div className="foundation-policy-meta"><span>كود السياسة: <b>{textValue(editing.policy_code)}</b></span><span>المفتاح التقني: <code>{textValue(editing.policy_key)}</code></span></div>
   </div>:
   <div className="foundation-form">{cfg.fields.map(f=><label key={f.key}><span>{f.label}{f.required?" *":""}</span>{f.options?<select value={textValue(form[f.key])} onChange={e=>setField(f.key,e.target.value)}>{f.options.map(o=><option key={o} value={o}>{o}</option>)}</select>:f.key==="governorate_id"&&kind==="branches"?<select value={textValue(form.governorate_id)} onChange={e=>setForm((old:Row)=>({...old,governorate_id:e.target.value,district_id:"",area_id:""}))}><option value="">اختر المحافظة</option>{governorates.map(g=><option key={g.id} value={g.id}>{g.name_ar}</option>)}</select>:f.key==="district_id"&&kind==="branches"?<select value={textValue(form.district_id)} disabled={!form.governorate_id} onChange={async e=>{const districtId=e.target.value;setForm((old:Row)=>({...old,district_id:districtId,area_id:""}));if(!districtId||!supabase)return;const {data:areaRows,error:areaError}=await supabase.from("erp_geographic_data").select("id,parent_id,name_ar,level,geo_code").eq("company_id",companyId).eq("is_active",true).eq("level","area").eq("parent_id",districtId).order("name_ar");if(areaError){setError("تعذر تحميل المناطق التابعة: "+areaError.message);return;}setGeographies(old=>[...old.filter(g=>g.level!=="area"||g.parent_id!==districtId),...((areaRows||[]) as Geo[])]);}}><option value="">اختر المركز / الحي</option>{districts.map(g=><option key={g.id} value={g.id}>{g.name_ar}</option>)}</select>:f.key==="area_id"&&kind==="branches"?<select value={textValue(form.area_id)} disabled={!form.district_id} onChange={e=>setField("area_id",e.target.value)}><option value="">اختر المنطقة</option>{areas.map(g=><option key={g.id} value={g.id}>{g.name_ar}</option>)}</select>:f.key==="brand_group_id"?<select value={textValue(form[f.key])} onChange={e=>setField(f.key,e.target.value)}><option value="">اختر مجموعة البراندات</option>{groupsForActivity.map(g=><option key={g.id} value={g.id}>{g.group_code} · {g.group_name}</option>)}</select>:f.key==="activity_type"&&kind==="activity-categories"?<select value={textValue(form.workspace_id)} onChange={e=>{const w=activities.find(x=>x.id===e.target.value);setForm((old:Row)=>({...old,workspace_id:e.target.value,activity_type:w?.activity_type||"",activity_name:w?.workspace_name||""}));}}>{activities.map(w=><option key={w.id} value={w.id}>{w.workspace_name}</option>)}</select>:f.key==="activity_code"&&(kind==="brand-groups"||kind==="brands")?<select value={textValue(form.activity_code)} onChange={e=>{const next=e.target.value;const first=groups.find(g=>g.activity_code===next);setForm((old:Row)=>({...old,activity_code:next,...(kind==="brands"?{brand_group_id:first?.id||"",brand_group:first?.group_name||""}:{})}));}}>{activities.map(a=><option key={a.code} value={a.code}>{a.code} · {a.name}</option>)}</select>:f.key==="activity_name"&&kind==="activity-categories"?<input value={textValue(form.activity_name)} readOnly aria-readonly="true"/>:<input type={f.type||"text"} value={textValue(form[f.key])} onChange={e=>setField(f.key,f.type==="number"?Number(e.target.value):e.target.value)}/>}</label>)}
    {kind==="branches"&&<><label className="foundation-check"><input type="checkbox" checked={form.is_main===true} onChange={e=>setField("is_main",e.target.checked)}/> فرع رئيسي</label><label className="foundation-check"><input type="checkbox" checked={form.is_active!==false} onChange={e=>setField("is_active",e.target.checked)}/> نشط</label></>}
    {(kind==="activities"||kind==="brand-groups"||kind==="brands")&&<><label className="foundation-check"><input type="checkbox" checked={form.is_active!==false} onChange={e=>setField("is_active",e.target.checked)}/> نشط</label><label className="foundation-check"><input type="checkbox" checked={form.show_in_app!==false} onChange={e=>setField("show_in_app",e.target.checked)}/> يظهر في تطبيق سلسلة</label></>}
   </div>}
   <div className="foundation-editor-actions"><button className="foundation-save" disabled={saving||(!canEdit&&!canAdd)} onClick={()=>window.dispatchEvent(new Event("silsila:edit-save"))}><Save size={15}/>{saving?"جارٍ الحفظ...":"حفظ البيانات"}</button><button onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))}>إلغاء</button></div>
  </div></EditDrawer>}
  {kind==="company"?<><div className="foundation-company-card"><div className="foundation-company-card-head"><div><small>ملف المنشأة</small><h3>{textValue(form.trade_name||form.legal_name)||"بيانات الشركة"}</h3><span>نفس بطاقة البيانات للمعاينة والتعديل</span></div>{companyEditing?<div className="foundation-company-card-actions"><button className="foundation-save" disabled={!canEdit||saving} onClick={()=>setConfirmCompanySave(true)}><Save size={15}/> حفظ</button><button onClick={()=>{setForm({...formOriginal});setCompanyEditing(false);setError("");}}>العدول عن التعديل</button></div>:<button className="foundation-save" onClick={()=>setCompanyEditing(true)} disabled={!canEdit}><Pencil size={15}/> تعديل</button>}</div><div className="foundation-company-fields"><label key="legal_name"><span>الاسم القانوني</span>{companyEditing?<input value={textValue(form.legal_name)} onChange={e=>setField("legal_name",e.target.value)}/>:<b>{textValue(form.legal_name)||"—"}</b>}</label><label key="trade_name"><span>الاسم التجاري</span>{companyEditing?<input value={textValue(form.trade_name)} onChange={e=>setField("trade_name",e.target.value)}/>:<b>{textValue(form.trade_name)||"—"}</b>}</label><label key="tax_number"><span>الرقم الضريبي</span>{companyEditing?<input value={textValue(form.tax_number)} onChange={e=>setField("tax_number",e.target.value)}/>:<b>{textValue(form.tax_number)||"—"}</b>}</label><label key="commercial_register"><span>السجل التجاري</span>{companyEditing?<input value={textValue(form.commercial_register)} onChange={e=>setField("commercial_register",e.target.value)}/>:<b>{textValue(form.commercial_register)||"—"}</b>}</label><label key="phone"><span>الهاتف</span>{companyEditing?<input value={textValue(form.phone)} onChange={e=>setField("phone",e.target.value)}/>:<b>{textValue(form.phone)||"—"}</b>}</label><label key="phone2"><span>هاتف إضافي</span>{companyEditing?<input value={textValue(form.phone2)} onChange={e=>setField("phone2",e.target.value)}/>:<b>{textValue(form.phone2)||"—"}</b>}</label><label key="email"><span>البريد الإلكتروني</span>{companyEditing?<input value={textValue(form.email)} onChange={e=>setField("email",e.target.value)}/>:<b>{textValue(form.email)||"—"}</b>}</label><label key="base_currency"><span>العملة</span>{companyEditing?<input value={textValue(form.base_currency)} onChange={e=>setField("base_currency",e.target.value)}/>:<b>{textValue(form.base_currency)||"—"}</b>}</label><label key="address"><span>العنوان</span>{companyEditing?<input value={textValue(form.address)} onChange={e=>setField("address",e.target.value)}/>:<b>{textValue(form.address)||"—"}</b>}</label><label key="english_name"><span>الاسم بالإنجليزية</span>{companyEditing?<input value={textValue(form.english_name)} onChange={e=>setField("english_name",e.target.value)}/>:<b>{textValue(form.english_name)||"—"}</b>}</label><label key="company_code"><span>كود الشركة</span>{companyEditing?<input value={textValue(form.company_code)} onChange={e=>setField("company_code",e.target.value)}/>:<b>{textValue(form.company_code)||"—"}</b>}</label><label key="tax_office"><span>مأمورية الضرائب</span>{companyEditing?<input value={textValue(form.tax_office)} onChange={e=>setField("tax_office",e.target.value)}/>:<b>{textValue(form.tax_office)||"—"}</b>}</label><label key="country"><span>الدولة</span>{companyEditing?<input value={textValue(form.country)} onChange={e=>setField("country",e.target.value)}/>:<b>{textValue(form.country)||"—"}</b>}</label></div></div>{confirmCompanySave&&<div className="foundation-company-confirm"><section role="alertdialog" aria-modal="true"><AlertTriangle size={24}/><h3>تأكيد حفظ بيانات الشركة</h3><p>هل ترغب في حفظ التعديلات على بيانات الشركة؟</p><div><button onClick={()=>{setConfirmCompanySave(false);void save();}}>نعم، حفظ</button><button onClick={()=>{setConfirmCompanySave(false);setForm({...formOriginal});setCompanyEditing(false);}}>لا، تجاهل التعديلات</button><button onClick={()=>setConfirmCompanySave(false)}>إلغاء الأمر</button></div></section></div>}</>:
  <div className="foundation-table-wrap"><table><thead><tr className="column-filter-row">{cfg.columns.map(c=><th key={c}><input aria-label={"بحث "+c} placeholder={"بحث "+c} value={columnQueries[c]||""} onChange={e=>setColumnQueries(old=>({...old,[c]:e.target.value}))}/></th>)}<th><span className="filter-disabled">—</span></th></tr><tr>{cfg.columns.map(c=><th key={c}>{({policy_code:"الكود",category:"التصنيف",name_ar:"السياسة",policy_value:"القيمة",is_enabled:"التفعيل",apply_to_all:"النطاق",is_active:"نشط أو لا",legal_name:"الاسم القانوني",trade_name:"الاسم التجاري",tax_number:"الرقم الضريبي",commercial_register:"السجل التجاري",phone:"الهاتف",email:"البريد",base_currency:"العملة",address:"العنوان",branch_code:"الكود",branch_name:"الفرع",branch_name_en:"الاسم الإنجليزي",is_main:"رئيسي",code:"الكود",name:"النشاط",name_en:"الاسم الإنجليزي",sort_order:"الترتيب",activity_type:"كود النشاط",activity_name:"النشاط",governorate_id:"المحافظة",district_id:"المركز / الحي",area_id:"المنطقة",customer_category:"الفئة",group_code:"الكود",group_name:"المجموعة",group_name_en:"الاسم الإنجليزي",activity_code:"النشاط",brand_code:"الكود",brand_name:"البراند",brand_name_en:"الاسم الإنجليزي",brand_group:"المجموعة",show_in_app:"عرض بالتطبيق"} as Record<string,string>)[c]||c}</th>) }<th>الإجراءات</th></tr></thead><tbody>{visible.map(r=><tr key={r.id} onDoubleClick={()=>kind==="branches"&&canRead&&startEdit(r)} className={kind==="branches"?"foundation-clickable-row":""}>{cfg.columns.map(c=><td key={c}>{c==="is_active"?<input className="silsila-bool-check" type="checkbox" checked={r[c]===true} disabled readOnly aria-label={r[c]===true?"نشط":"لا"}/>:c==="is_enabled"||c==="apply_to_all"||c==="is_main"||c==="show_in_app"?<span className={r[c]?"foundation-yes":"foundation-no"}>{r[c]?"نعم":"لا"}</span>:c==="policy_value"?<span className="foundation-value">{textValue(r[c]).slice(0,100)||"—"}</span>:c==="governorate_id"||c==="district_id"||c==="area_id"?geographies.find(g=>g.id===r[c])?.name_ar||"—":textValue(r[c])||"—"}</td>)}<td><div className="foundation-actions"><button title="تعديل" onClick={()=>startEdit(r)} disabled={!canEdit}><Pencil size={14}/></button>{kind!=="policies"&&r.is_active!==false&&<button title="تعطيل" onClick={()=>void remove(r)} disabled={!canDeactivate}><X size={14}/></button>}</div></td></tr>)}{!loading&&!visible.length&&<tr><td colSpan={cfg.columns.length+1} className="foundation-empty">لا توجد سجلات مطابقة.</td></tr>}</tbody></table>{loading&&<div className="foundation-empty">جارٍ تحميل البيانات الحقيقية...</div>}</div>}
  <p className="foundation-foot">تُحفظ التعديلات في جداول المشروع الأصلية وتخضع لصلاحيات Supabase وعلاقات البيانات. لا يتم حذف السجلات المرتبطة من هذه الشاشة.</p>
 </section>;
}
