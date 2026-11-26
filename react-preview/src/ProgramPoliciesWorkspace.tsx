import {useCallback,useEffect,useMemo,useState} from "react";
import {AlertTriangle,CheckCircle2,Database,Eye,FileDown,FileText,LockKeyhole,Palette,Printer,RefreshCw,Save,Search,Settings2,ShieldCheck,SlidersHorizontal,X} from "lucide-react";
import {supabase} from "./supabase";
import EditDrawer from "./EditDrawer";

type Policy=Record<string,any>;
const categories=["الكل","برمجية","تكويدية","محاسبية","مخزنية","بيعية","شرائية","إدارية","الخطوط والألوان","الهوية البصرية"];
const hiddenKeys=new Set<string>(["code_generation_registry","code_type.cash_voucher","code_type.sales_representative","code_type.sales_campaign","code_type.customer_monthly_goal","code_type.employee_monthly_target"]);
const codePolicy=(p:Policy)=>p.category==="تكويدية"||String(p.policy_key||"").startsWith("code_")||String(p.policy_key||"").startsWith("geo_code.")||String(p.policy_key||"").startsWith("category_code.")||String(p.policy_key||"").startsWith("item_code");
const text=(v:any)=>v==null?"":String(v);
const parseObject=(v:any)=>{try{const x=JSON.parse(text(v));return x&&typeof x==="object"&&!Array.isArray(x)?x:null;}catch{return null;}};
export default function ProgramPoliciesWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const userId=sessionStorage.getItem("silsila-user-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const [rows,setRows]=useState<Policy[]>([]),[category,setCategory]=useState("الكل"),[query,setQuery]=useState("");
 const [selected,setSelected]=useState<Policy|null>(null),[selectedOriginal,setSelectedOriginal]=useState<Policy|null>(null),[draft,setDraft]=useState<Policy>({});
 const [loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[error,setError]=useState(""),[notice,setNotice]=useState("");
 const [permissionsReady,setPermissionsReady]=useState(false),[canRead,setCanRead]=useState(true),[canEdit,setCanEdit]=useState(false);
 const [lockedCodes,setLockedCodes]=useState<Set<string>>(new Set()),[lockCheckReady,setLockCheckReady]=useState(false);
 const [users,setUsers]=useState<Policy[]>([]);
 const [programSettings,setProgramSettings]=useState<Policy>({});
 const [programName,setProgramName]=useState("سلسلة"),[logoBase64,setLogoBase64]=useState(""),[logoMime,setLogoMime]=useState("");
 const [editMode,setEditMode]=useState(false),[previewOpen,setPreviewOpen]=useState(false);
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
   const {data:settings,error:settingsError}=await supabase.from("erp_program_settings").select("*").eq("company_id",companyId).maybeSingle();
   if(!settingsError){
    const saved=settings||{};
    setProgramSettings(saved);
    setProgramName(text(saved.program_name)||"سلسلة");
    setLogoBase64(text(saved.logo_base64));
    setLogoMime(text(saved.logo_mime_type));
   }
   setRows((data||[]).filter((p:any)=>!hiddenKeys.has(text(p.policy_key))).map((p:any)=>{
    if(p.policy_key==="visual_identity.program_name")return {...p,policy_value:text(settings?.program_name)||"سلسلة"};
    if(p.policy_key==="visual_identity.logo")return {...p,policy_value:settings?.logo_base64?"تم تحديد الشعار":"لم يتم تحديد شعار"};
    return p;
   }));
   const {data:userRows,error:userError}=await supabase.from("erp_users").select("id,user_code,name_ar").eq("company_id",companyId).order("name_ar");
   if(!userError)setUsers(userRows||[]);
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
 const isLocked=(p:Policy)=>{if(!codePolicy(p))return false;const key=text(p.policy_key);return !lockCheckReady||lockedCodes.has("__ALL_CODE_POLICIES_LOCKED_UNTIL_CHECK__")||lockedCodes.has(key);}; // Honor the database lock registry: protect issued-code policies, but allow unlocked policies to use the existing central coding rules.
 const openEditor=(p:Policy)=>{setSelected(p);setSelectedOriginal({...p});setDraft({...p});setError("");setNotice("");};
 const closeEditor=()=>{setSelected(null);setSelectedOriginal(null);setDraft({});};
 const update=async():Promise<boolean>=>{
  if(!supabase||!selected)return false;
  if(!canEdit){setError("لا تملك صلاحية تعديل السياسات.");return false;}
  if(isLocked(selected)){setError("سياسة التكويد محمية حاليًا لضمان عدم تغيير الأكواد الصادرة. لم يتم تعديل أي قيمة.");return false;}
  const key=text(selected.policy_key),value=text(draft.policy_value);
  if(key==="visual_identity.program_name"&&!programName.trim()){setError("اسم المشروع مطلوب.");return false;}
  if(key.startsWith("visual_identity.")&&key.endsWith("_color")&&!/^#[0-9a-fA-F]{6}$/.test(value)){setError("قيمة اللون غير صحيحة. استخدم صيغة HEX مثل #FFA015.");return false;}
  if(["appearance.header_text","appearance.main_heading","appearance.subheading_1","appearance.subheading_2","appearance.subheading_3","appearance.body_text","visual_identity.heading_1"].includes(key)){const font=parseObject(value)||{};if(!["Tajawal","Kufam","Romman"].includes(text(font.font)||"Tajawal")){setError("اختر خطًا معتمدًا: Tajawal أو Kufam أو Romman.");return false;}if(!Number.isFinite(Number(font.size))||Number(font.size)<12||Number(font.size)>72){setError("حجم الخط يجب أن يكون بين 12 و72px لضمان وضوح القراءة.");return false;}if(font.color&&!/^#[0-9a-fA-F]{6}$/.test(text(font.color))){setError("لون الخط غير صحيح. استخدم صيغة HEX.");return false;}}
  if(key==="appearance.header_background"||key==="appearance.screen_background"){if(!/^#[0-9a-fA-F]{6}$/.test(value)){setError("أدخل لونًا صحيحًا بصيغة HEX.");return false;}}
  setSaving(true);setError("");setNotice("");
  try{
   if(key==="visual_identity.program_name"||key==="visual_identity.logo"){
    const nextSettings={...programSettings,company_id:companyId,program_name:programName.trim()||"سلسلة",logo_base64:logoBase64||null,logo_mime_type:logoMime||null,updated_at:new Date().toISOString()};
    const {error:settingsError}=await supabase.from("erp_program_settings").upsert(nextSettings,{onConflict:"company_id"});
    if(settingsError)throw settingsError;
    setProgramSettings(nextSettings);
   }
   if(codePolicy(selected)&&json){
    const codeKey=key,cfg=parseObject(draft.policy_value)||{};
    if(codeKey==="customer_code"){
     if(!/^[A-Za-z]{1,10}$/.test(text(cfg.prefix))||Number(cfg.geo_digits)!==8||Number(cfg.serial_digits)<1||Number(cfg.serial_digits)>12)throw new Error("كود العميل يتطلب بادئة صحيحة و8 أرقام جغرافية وتسلسلًا من 1 إلى 12.");
    }else if(codeKey==="item_code"){
     if(!/^[A-Za-z]{3}$/.test(text(cfg.prefix))||Number(cfg.category_digits)!==8||Number(cfg.brand_digits)!==4||Number(cfg.serial_digits)<1||Number(cfg.serial_digits)>8)throw new Error("كود الصنف يحتفظ بـ8 أرقام للفئات (النشاط + 3 مستويات) و4 للبراند، مع بادئة من 3 أحرف وتسلسل من 1 إلى 8.");
    }else if(codeKey.startsWith("code_policy.")||codeKey.startsWith("code_type.")){
     if(!/^[A-Za-z]{3}$/.test(text(cfg.prefix))||Number(cfg.digits)<1||Number(cfg.digits)>12)throw new Error("بادئة الكود يجب أن تكون 3 أحرف إنجليزية وعدد الأرقام من 1 إلى 12.");
    }
    const registryRow=await supabase.from("erp_program_policies").select("id,policy_value").eq("company_id",companyId).eq("policy_key","code_generation_registry").maybeSingle();
    if(registryRow.error)throw registryRow.error;
    if(!registryRow.data)throw new Error("سجل التكويد المركزي غير موجود؛ تم إلغاء الحفظ لحماية الأكواد الحالية.");
    if(registryRow.data){
     let payload=parseObject(registryRow.data.policy_value)||{},types=parseObject(payload.types)||{};
     const legacy:Record<string,string>={"code_policy.employee":"employee","code_policy.user":"user","code_policy.supplier":"supplier","code_policy.representative":"delegate","code_policy.branch":"branch","code_policy.department":"department","code_policy.work_location":"work_location","code_policy.job":"job","code_policy.grade":"grade","code_policy.salary_element":"salary_element"};
     if(codeKey.startsWith("code_type.")){
      const typeKey=codeKey.slice("code_type.".length);types[typeKey]={...(parseObject(types[typeKey])||{}),prefix:cfg.prefix,digits:cfg.digits};
     }else if(legacy[codeKey]){
      const typeKey=legacy[codeKey];types[typeKey]={...(parseObject(types[typeKey])||{}),prefix:cfg.prefix,digits:cfg.digits};
     }else if(codeKey==="customer_code"){
      types.customer={...(parseObject(types.customer)||{}),prefix:cfg.prefix,digits:cfg.serial_digits,serial_digits:cfg.serial_digits,geo_digits:8,fields:[{name:"كود الدولة والمحافظة والحي/المركز والمنطقة بدون حروف",digits:8},{name:"تسلسل العميل",digits:cfg.serial_digits}]};
     }else if(codeKey==="item_code"){
      payload.item_prefix=cfg.prefix;payload.item_segments={...(parseObject(payload.item_segments)||{}),main:2,sub:2,secondary:2,serial:cfg.serial_digits};
     }
     payload.types=types;
     const {error:registryError}=await supabase.from("erp_program_policies").update({policy_value:JSON.stringify(payload),updated_at:new Date().toISOString()}).eq("id",registryRow.data.id).eq("company_id",companyId);
     if(registryError)throw registryError;
    }
   }
   const {data,error}=await supabase.from("erp_program_policies").update({policy_value:key==="visual_identity.program_name"?programName.trim():key==="visual_identity.logo"?(logoBase64?"تم تحديد الشعار":""):value,is_enabled:draft.is_enabled===true,apply_to_all:draft.apply_to_all===true,user_ids:Array.isArray(draft.user_ids)?draft.user_ids:[],updated_at:new Date().toISOString()}).eq("id",selected.id).eq("company_id",companyId).select("id").single();
   if(error)throw error;if(!data)throw new Error("لم يؤكد النظام حفظ السياسة.");
   setNotice("تم حفظ السياسة بنجاح في قاعدة البيانات المشتركة.");
   await load();closeEditor();return true;
  }catch(e:any){setError("فشل حفظ السياسة: "+(e?.message||String(e)));return false;}
  finally{setSaving(false);}
 };
 const fieldLabel=(p:Policy)=>p.name_ar||p.policy_key||"سياسة بدون اسم";
 const codeDetails=(p:Policy)=>{
  const key=text(p.policy_key),cfg=parseObject(p.policy_value)||{};
  if(key==="customer_code")return {prefix:text(cfg.prefix)||"Cus",structure:`${cfg.geo_digits??8} أرقام جغرافية + ${cfg.serial_digits??4} تسلسلية`,example:`${text(cfg.prefix)||"Cus"}000000000001`};
  if(key==="item_code")return {prefix:text(cfg.prefix)||"Itm",structure:`${cfg.category_digits??8} أرقام فئات + ${cfg.brand_digits??4} للبراند + ${cfg.serial_digits??3} للتسلسل`,example:`${text(cfg.prefix)||"Itm"}${"0".repeat(Math.max(0,Number(cfg.category_digits??8)+Number(cfg.brand_digits??4)+Number(cfg.serial_digits??3)-1))}1`};
  if(key.startsWith("geo_code.")||key.startsWith("category_code.")||key==="brand_code"){
   const own=Number(cfg.digits??(key==="brand_code"?4:2)),parent=Number(cfg.parent_digits??0),prefix=text(cfg.prefix);
   return {prefix,structure:parent?`${parent} موروثة + ${own} خاصة`:`${own} أرقام`,example:prefix+"0".repeat(Math.max(0,parent+own-1))+"1"};
  }
  if(key.startsWith("code_policy.")||key.startsWith("code_type.")){
   const prefix=text(cfg.prefix),digits=Number(cfg.digits??3);
   return {prefix,structure:`${digits} أرقام تسلسلية`,example:prefix+"0".repeat(Math.max(0,digits-1))+"1"};
  }
  return null;
 };
 const exportExcel=()=>{
  const headers=["م","كود السياسة","اسم السياسة","القيمة","الحالة","نطاق التطبيق","عدد المستخدمين"];
  const lines=[headers,...visible.map((p,i)=>[String(i+1),text(p.policy_code),fieldLabel(p),text(p.policy_value),p.is_enabled?"مفعلة":"متوقفة",p.apply_to_all?"كل المستخدمين":"مستخدمون محددون",String((p.user_ids||[]).length)])];
  const html="<html><head><meta charset='utf-8'></head><body><table border='1'>"+lines.map(row=>"<tr>"+row.map(v=>"<td>"+String(v).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")+"</td>").join("")+"</tr>").join("")+"</table></body></html>";
  const url=URL.createObjectURL(new Blob([html],{type:"application/vnd.ms-excel;charset=utf-8"}));
  const a=document.createElement("a");a.href=url;a.download="Silsila_Program_Policies.xls";a.click();URL.revokeObjectURL(url);
 };
 const printPolicies=()=>window.print();
 const valueKind=(p:Policy)=>{const key=text(p.policy_key);if(codePolicy(p)&&parseObject(p.policy_value))return "codeConfig";if(key==="visual_identity.program_name")return "programName";if(key==="visual_identity.logo")return "logo";if(["appearance.header_text","appearance.main_heading","appearance.subheading_1","appearance.subheading_2","appearance.subheading_3","appearance.body_text","visual_identity.heading_1"].includes(key))return "fontStyle";if(key==="ui_layout_standard")return "layout";if(key==="appearance.dark_mode")return "boolean";if(key==="appearance.theme_preset")return "theme";if(key==="appearance.language")return "language";if(key==="appearance.header_background"||key==="appearance.screen_background"||key.startsWith("visual_identity.")&&key.endsWith("_color"))return "color";if(["inventory_valuation","inventory_count","depreciation","inventory.stocktake.valuation_basis","trader_market.story_duration_unit"].includes(key))return "choice";return "text";};
 const optionsFor=(p:Policy)=>{const k=text(p.policy_key);if(k==="appearance.theme_preset")return ["glossy","classic"];if(k==="appearance.language")return ["العربية","الإنجليزية"];if(k==="inventory_valuation")return ["المتوسط المرجح","الوارد أولاً صادر أولاً (FIFO)","التحديد المحدد"];if(k==="inventory_count")return ["الجرد المستمر","الجرد الدوري"];if(k==="depreciation")return ["القسط الثابت","القسط المتناقص","وحدات الإنتاج"];if(k==="inventory.stocktake.valuation_basis")return ["sale","purchase"];if(k==="trader_market.story_duration_unit")return ["دقيقة","ساعة"];return [];};
 const json=parseObject(draft.policy_value);
 const setJson=(key:string,value:any)=>setDraft((old:Policy)=>{const obj=parseObject(old.policy_value)||{};return {...old,policy_value:JSON.stringify({...obj,[key]:value})};});
 const s:Record<string,any>={};
 return <section className="program-policies" dir="rtl">
  <style>{`
  .program-policies{color:#241735;display:flex;flex-direction:column;gap:14px;min-width:0}.pp-head{display:flex;align-items:center;gap:13px;padding:18px 20px;border:1px solid #eadff4;border-radius:18px;background:linear-gradient(120deg,#fff 0%,#faf6ff 100%)}.pp-head-icon{width:46px;height:46px;border-radius:14px;background:#3E007D;color:#fff;display:grid;place-items:center}.pp-head h2{margin:0;color:#3E007D;font-size:22px;font-weight:900}.pp-head p{margin:4px 0 0;color:#756984;font-size:13px}.pp-count{margin-inline-start:auto;display:flex;align-items:center;gap:7px;color:#3E007D;font-weight:800;white-space:nowrap}.pp-alert,.pp-notice{display:flex;align-items:center;gap:8px;padding:10px 13px;border-radius:10px;font-size:13px}.pp-alert{background:#fff1ef;color:#a52b20}.pp-notice{background:#eefaf2;color:#176b38}.pp-toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.pp-search{display:flex;align-items:center;gap:8px;flex:1;min-width:210px;background:#fff;border:1px solid #e7ddec;border-radius:10px;padding:0 12px;height:42px}.pp-search input{border:0;outline:0;flex:1;min-width:0;font:inherit}.pp-refresh,.pp-btn{height:40px;border:1px solid #e5d9ec;border-radius:10px;background:#fff;color:#49345d;padding:0 13px;display:inline-flex;align-items:center;justify-content:center;gap:7px;font:inherit;cursor:pointer}.pp-tabs{display:flex;gap:7px;overflow-x:auto;padding:2px 0 6px;scrollbar-width:thin}.pp-tab{border:1px solid #e8ddec;border-radius:999px;background:#fff;padding:9px 14px;white-space:nowrap;color:#5b4a69;font:inherit;cursor:pointer}.pp-tab.active{background:#3E007D;color:#fff;border-color:#3E007D}.pp-tab small{margin-inline-start:7px;opacity:.75}.pp-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,330px),1fr));gap:10px}.pp-card{border:1px solid #eadff0;border-radius:13px;background:#fff;padding:13px;display:flex;flex-direction:column;gap:9px;min-width:0}.pp-card-top{display:flex;align-items:flex-start;gap:8px}.pp-card h3{margin:0;font-size:14px;color:#38234e;line-height:1.6}.pp-card code{font-size:12px;color:#51445C;direction:ltr;overflow-wrap:anywhere}.pp-card-value{background:#faf8fc;border-radius:8px;padding:8px 10px;color:#655574;font-size:12px;white-space:pre-wrap;overflow-wrap:anywhere;max-height:76px;overflow:hidden}.pp-card-foot{display:flex;align-items:center;gap:7px;flex-wrap:wrap;font-size:12px;color:#51445C}.pp-state{border-radius:999px;padding:4px 8px;background:#f1edf5}.pp-state.on{background:#eaf8ef;color:#237445}.pp-state.off{background:#fff1ef;color:#a33a31}.pp-state.lock{background:#fff5e5;color:#8a5a10}.pp-edit{margin-inline-start:auto;border:0;background:#f4edf9;color:#3E007D;border-radius:8px;padding:7px 10px;display:flex;align-items:center;gap:6px;font:inherit;cursor:pointer}.pp-edit:disabled{opacity:.45;cursor:not-allowed}.pp-empty{padding:34px;text-align:center;color:#84758f;background:#faf8fc;border-radius:12px}.pp-editor{border:1px solid #d8c5e7;border-radius:16px;background:#fff;padding:16px;display:flex;flex-direction:column;gap:13px;box-shadow:0 12px 35px #3e007d12}.pp-editor-head{display:flex;align-items:center;gap:10px}.pp-editor-head h3{margin:0;color:#3E007D;font-size:17px}.pp-editor-head button{margin-inline-start:auto;border:0;background:#f5effb;border-radius:8px;padding:7px;cursor:pointer}.pp-fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.pp-field{display:flex;flex-direction:column;gap:6px;min-width:0}.pp-field.full{grid-column:1/-1}.pp-field label{font-size:12px;font-weight:800;color:#574365}.pp-field input,.pp-field select,.pp-field textarea{width:100%;box-sizing:border-box;border:1px solid #e3d8ea;border-radius:9px;padding:10px 11px;font:inherit;color:#38244c;background:#fff;min-height:40px}.pp-field textarea{min-height:90px;resize:vertical}.pp-color{display:flex;gap:9px;align-items:center}.pp-color input[type=color]{width:52px;padding:3px;min-height:40px}.pp-toggle{display:flex;gap:8px;align-items:center;font-size:13px;color:#4e3b5d}.pp-toggle input{accent-color:#3E007D;width:17px;height:17px}.pp-meta{display:flex;gap:14px;flex-wrap:wrap;color:#7d6c89;font-size:11px}.pp-meta code{direction:ltr}.pp-actions{display:flex;gap:8px;justify-content:flex-start}.pp-save{background:#3E007D;color:#fff;border:0;border-radius:10px;padding:10px 18px;font:inherit;font-weight:800;display:flex;align-items:center;gap:8px;cursor:pointer}.pp-save:disabled{opacity:.5;cursor:not-allowed}@media(max-width:680px){.pp-head{padding:13px}.pp-head h2{font-size:18px}.pp-count{font-size:11px}.pp-fields{grid-template-columns:1fr}.pp-editor{padding:12px}.pp-list{grid-template-columns:1fr}}`}</style>
  <header className="pp-head"><div className="pp-head-icon"><SlidersHorizontal size={23}/></div><div><h2>سياسات البرنامج</h2><p>نقل شاشة السياسات إلى React مع ربط مباشر ببيانات سلسلة الأصلية</p></div><div className="pp-count"><Database size={16}/>{rows.length.toLocaleString("ar-EG")} سياسة</div></header>
  {error&&<div className="pp-alert"><AlertTriangle size={16}/>{error}</div>}{notice&&<div className="pp-notice"><CheckCircle2 size={16}/>{notice}</div>}
  <div className="pp-toolbar"><label className="pp-search"><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="ابحث باسم السياسة أو الكود أو القيمة"/></label></div>
  <div className="pp-quick-actions">
   <button onClick={()=>void load()} disabled={loading}><RefreshCw size={15}/> تحديث</button>
   <button disabled title="إضافة سياسة جديدة غير متاحة؛ السياسات تُدار من كتالوج البرنامج">＋ إضافة</button>
   <button onClick={()=>selected&&void update()} disabled={!selected||saving||!canEdit||!editMode||isLocked(selected)}><Save size={15}/> حفظ</button>
   <button onClick={()=>{setEditMode(v=>!v);setSelected(null);}} disabled={!canEdit}>{editMode?"إنهاء التعديل":"تعديل"}</button>
   <button disabled title="لا يمكن حذف سياسات البرنامج الأساسية">حذف</button>
   <button onClick={()=>setPreviewOpen(true)}><Eye size={15}/> معاينة</button>
   <button onClick={printPolicies}><Printer size={15}/> طباعة</button>
   <button onClick={exportExcel}><FileDown size={15}/> Excel</button>
   <button onClick={printPolicies}><FileText size={15}/> PDF</button>
  </div>
  <nav className="pp-tabs" aria-label="تصنيفات سياسات البرنامج">{categories.map(c=><button key={c} className={"pp-tab"+(category===c?" active":"")} onClick={()=>{setCategory(c);setSelected(null);}}>{c}<small>{counts[c]||0}</small></button>)}</nav>
  {selected&&<EditDrawer title={fieldLabel(selected)} dirty={JSON.stringify(draft)!==JSON.stringify(selectedOriginal)||((selected.policy_key==="visual_identity.program_name")&&programName!==text(programSettings.program_name))||((selected.policy_key==="visual_identity.logo")&&logoBase64!==text(programSettings.logo_base64))} saving={saving} error={error} onSaveError={()=>setSaving(false)} onSave={update} onDiscard={()=>{setDraft({...((selectedOriginal||selected)||{})});setProgramName(text(programSettings.program_name)||"سلسلة");setLogoBase64(text(programSettings.logo_base64));setLogoMime(text(programSettings.logo_mime_type));setError("");setNotice("");}} onClose={closeEditor}><div className="pp-editor"><div className="pp-editor-head"><Settings2 size={19}/><h3>{fieldLabel(selected)}</h3><button onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))} aria-label="إغلاق"><X size={17}/></button></div>
   <div className="pp-fields">
    <div className="pp-field full"><label>قيمة السياسة</label>
     {valueKind(selected)==="codeConfig"&&json?<div className="pp-code-editor">
       <div><label>البادئة</label><input dir="ltr" maxLength={selected.policy_key==="customer_code"?10:3} value={text(json.prefix)} readOnly={selected.policy_key.startsWith("geo_code.")||selected.policy_key.startsWith("category_code.")||selected.policy_key==="brand_code"||isLocked(selected)} onChange={e=>setJson("prefix",e.target.value.toUpperCase())}/></div>
       {selected.policy_key==="customer_code"?<><div><label>الخانات الجغرافية (ثابتة)</label><input value="8" readOnly/></div><div><label>خانات التسلسل</label><input type="number" min="1" max="12" value={Number(json.serial_digits??4)} disabled={isLocked(selected)} onChange={e=>setJson("serial_digits",Number(e.target.value))}/></div></>:
       selected.policy_key==="item_code"?<><div><label>خانات الفئات (النشاط + 3 مستويات)</label><input value="8" readOnly/></div><div><label>خانات البراند (ثابتة)</label><input value="4" readOnly/></div><div><label>خانات التسلسل</label><input type="number" min="1" max="8" value={Number(json.serial_digits??3)} disabled={isLocked(selected)} onChange={e=>setJson("serial_digits",Number(e.target.value))}/></div></>:
       <div><label>عدد الأرقام</label><input type="number" min="1" max="12" value={Number(json.digits??2)} readOnly={selected.policy_key.startsWith("geo_code.")||selected.policy_key.startsWith("category_code.")||selected.policy_key==="brand_code"||isLocked(selected)} onChange={e=>setJson("digits",Number(e.target.value))}/></div>}
       <div className="pp-code-preview"><b>معاينة الكود</b><code>{codeDetails({...selected,policy_value:JSON.stringify(draft.policy_value?json:{})})?.example||"—"}</code><small>لا يتم تغيير تقسيمات الكود المعتمدة أو ترتيب مكوناتها.</small></div>
      </div>:
      valueKind(selected)==="programName"?<input value={programName} onChange={e=>setProgramName(e.target.value)} placeholder="اسم البرنامج"/>:
      valueKind(selected)==="logo"?<div className="pp-logo-editor">{logoBase64&&<img alt="شعار البرنامج" src={`data:${logoMime||"image/png"};base64,${logoBase64}`}/>}<input type="file" accept="image/png,image/jpeg,image/webp" onChange={e=>{const file=e.target.files?.[0];if(!file)return;if(file.size>1024*1024){setError("حجم الشعار يجب ألا يتجاوز 1 ميجابايت.");return;}const reader=new FileReader();reader.onload=()=>{const result=String(reader.result||"");const parts=result.split(",");setLogoMime(file.type);setLogoBase64(parts[1]||"");};reader.readAsDataURL(file);}}/></div>:
      valueKind(selected)==="fontStyle"&&json?<div className="pp-font-editor"><label>نوع الخط<select value={text(json.font)||"Tajawal"} onChange={e=>setJson("font",e.target.value)}><option value="Tajawal">Tajawal</option><option value="Kufam">Kufam</option><option value="Romman">Romman</option></select></label><label>الحجم<input type="number" min="12" max="72" value={Math.max(12,Number(json.size??14))} onChange={e=>setJson("size",Number(e.target.value))}/></label><label>اللون<input type="color" value={/^#[0-9a-fA-F]{6}$/.test(text(json.color))?text(json.color):"#3E007D"} onChange={e=>setJson("color",e.target.value.toUpperCase())}/></label><label className="pp-toggle"><input type="checkbox" checked={json.bold===true} onChange={e=>setJson("bold",e.target.checked)}/> خط سميك</label></div>:
      valueKind(selected)==="layout"&&json?<div className="pp-layout-values">{[{key:"row_height",label:"ارتفاع الصفوف",fallback:40},{key:"field_height",label:"ارتفاع الخانات",fallback:40},{key:"column_spacing",label:"المسافة الأفقية",fallback:5},{key:"vertical_spacing",label:"المسافة الرأسية",fallback:5}].map(item=><label key={item.key}>{item.label}<div><input type="number" min="0" max="120" value={Number(json[item.key]??item.fallback)} onChange={e=>setJson(item.key,Number(e.target.value))}/> <b>px</b></div></label>)}<small>المعيار المعتمد: ارتفاع الصف والحقل 40px، والمسافة بين الأعمدة والصفوف 5px.</small></div>:
      valueKind(selected)==="boolean"?<select value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value}))}><option value="true">مفعّل</option><option value="false">غير مفعّل</option></select>:
      valueKind(selected)==="theme"||valueKind(selected)==="language"||valueKind(selected)==="choice"?<select value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value}))}>{optionsFor(selected).map(o=><option key={o} value={o}>{o}</option>)}</select>:
      valueKind(selected)==="color"?<div className="pp-color"><input type="color" value={/^#[0-9a-fA-F]{6}$/.test(text(draft.policy_value))?text(draft.policy_value):"#3E007D"} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value.toUpperCase()}))}/><input dir="ltr" value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value.toUpperCase()}))}/></div>:
      <textarea dir="auto" value={text(draft.policy_value)} onChange={e=>setDraft((x:Policy)=>({...x,policy_value:e.target.value}))} spellCheck={false}/>}
    </div>
    {json&&<><div className="pp-field"><label>معاينة / محتوى JSON</label><textarea dir="ltr" readOnly value={JSON.stringify(json,null,2)}/></div><div className="pp-field"><label>ملاحظة</label><input readOnly value="تُحفظ قيمة السياسة كما هي؛ لا يتم تغيير بنية التكويد تلقائيًا."/></div></>}
    <div className="pp-field"><label>نطاق التطبيق</label><label className="pp-toggle"><input type="checkbox" checked={draft.apply_to_all===true} onChange={e=>setDraft((x:Policy)=>({...x,apply_to_all:e.target.checked}))}/> تطبيق على جميع المستخدمين</label></div>
    <div className="pp-field"><label>حالة السياسة</label><label className="pp-toggle"><input type="checkbox" checked={draft.is_enabled===true} onChange={e=>setDraft((x:Policy)=>({...x,is_enabled:e.target.checked}))}/> السياسة مفعّلة</label></div>
    <div className="pp-field full"><label>المستخدمون المطبق عليهم</label><label className="pp-toggle"><input type="checkbox" checked={draft.apply_to_all===true} onChange={e=>setDraft((x:Policy)=>({...x,apply_to_all:e.target.checked,user_ids:[]}))}/> جميع المستخدمين</label>{!draft.apply_to_all&&<div className="pp-user-picker">{users.map(u=><label key={u.id}><input type="checkbox" checked={(draft.user_ids||[]).includes(u.id)} onChange={e=>setDraft((x:Policy)=>({...x,user_ids:e.target.checked?[...(x.user_ids||[]),u.id]:(x.user_ids||[]).filter((id:string)=>id!==u.id)}))}/>{u.name_ar||u.user_code||u.id}</label>)}</div>}</div>
   </div>
   {isLocked(selected)&&<div className="pp-alert"><LockKeyhole size={16}/>سياسة التكويد مقفلة للحفاظ على الأكواد الحالية، أو تعذر التحقق من حالة القفل. لا يمكن تعديلها الآن.</div>}
   <div className="pp-meta"><span>كود السياسة: <b>{text(selected.policy_code)||"—"}</b></span><span>المفتاح: <code>{text(selected.policy_key)}</code></span><span>التصنيف: {text(selected.category)}</span></div>
   <div className="pp-actions"><button className="pp-save" disabled={saving||!canEdit||!editMode||isLocked(selected)} onClick={()=>window.dispatchEvent(new Event("silsila:edit-save"))}><Save size={16}/>{saving?"جارٍ الحفظ...":"حفظ التعديلات"}</button><button className="pp-btn" onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))}>إلغاء</button></div>
  </div></EditDrawer>}
  {loading?<div className="pp-empty">جارٍ تحميل السياسات المحفوظة...</div>:!canRead?<div className="pp-empty">لا تملك صلاحية عرض هذه الشاشة.</div>:visible.length===0?<div className="pp-empty">لا توجد سياسات مطابقة.</div>:<div className="pp-table-wrap"><table className="pp-table"><thead><tr><th>م</th><th>كود السياسة</th><th>بيانات السياسة</th><th>القيمة / التركيب</th>{category==="تكويدية"&&<><th>البادئة</th><th>مثال الكود</th></>}<th>التفعيل</th><th>نطاق التطبيق</th><th>عدد المستخدمين</th><th>الإجراء</th></tr></thead><tbody>{visible.map((p,i)=>{const details=codeDetails(p);return <tr key={p.id}><td>{i+1}</td><td dir="ltr">{text(p.policy_code)||"—"}</td><td><strong>{fieldLabel(p)}</strong><small dir="ltr">{text(p.policy_key)}</small></td><td className="pp-value-cell">{details?details.structure:(text(p.policy_value)||"—")}</td>{category==="تكويدية"&&<><td dir="ltr">{details?.prefix||"—"}</td><td dir="ltr">{details?.example||"—"}</td></>}<td><span className={"pp-state "+(p.is_enabled?"on":"off")}>{p.is_enabled?"مفعّلة":"متوقفة"}</span></td><td>{p.apply_to_all?"كل المستخدمين":"مستخدمون محددون"}</td><td>{(p.user_ids||[]).length}</td><td><button className="pp-edit" disabled={!canEdit||!editMode||isLocked(p)} onClick={()=>openEditor(p)}><Palette size={14}/> تعديل</button>{isLocked(p)&&<small className="pp-lock-note">محمية بعد بدء التكويد</small>}</td></tr>})}</tbody></table></div>}
  {previewOpen&&<div className="pp-modal-backdrop" onClick={()=>setPreviewOpen(false)}><div className="pp-preview-modal" onClick={e=>e.stopPropagation()}><div className="pp-editor-head"><h3>معاينة سياسات البرنامج — {category}</h3><button onClick={()=>setPreviewOpen(false)}><X size={17}/></button></div><p>عدد السياسات المعروضة: {visible.length} من إجمالي {rows.length} سياسة.</p><div className="pp-preview-list">{visible.map(p=><div key={p.id}><b>{text(p.policy_code)} · {fieldLabel(p)}</b><span>{text(p.policy_value)||"—"}</span></div>)}</div><div className="pp-actions"><button className="pp-btn" onClick={printPolicies}>طباعة المعاينة</button><button className="pp-save" onClick={()=>setPreviewOpen(false)}>إغلاق</button></div></div></div>}
  <footer style={{fontSize:11,color:"#8a7b95",padding:"4px 2px"}}>مصدر البيانات: erp_program_policies · السياسات الأساسية والقديمة محفوظة في قاعدة البيانات المشتركة. يتم إخفاء السجلات الداخلية المكررة فقط وفق سلوك الشاشة الأصلية.</footer>
  <style>{`.pp-code-editor{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.pp-code-editor>div:not(.pp-code-preview){display:flex;flex-direction:column;gap:5px}.pp-code-editor label{font-size:12px;font-weight:800}.pp-code-editor input{min-height:40px;border:1px solid #e3d8ea;border-radius:8px;padding:8px;font:inherit}.pp-code-preview{grid-column:1/-1;display:flex;align-items:center;gap:12px;padding:10px;background:#faf8fc;border-radius:9px}.pp-code-preview code{direction:ltr;color:#3E007D;font-weight:900}.pp-code-preview small{color:#8b7a98}.pp-logo-editor{display:flex;align-items:center;gap:12px}.pp-logo-editor img{width:70px;height:70px;object-fit:contain;border:1px solid #eadff0;border-radius:10px;padding:5px}.pp-font-editor{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.pp-font-editor label{display:flex;flex-direction:column;gap:5px}.pp-font-editor input:not([type=checkbox]){min-height:40px;border:1px solid #e3d8ea;border-radius:8px;padding:8px;font:inherit}.pp-font-editor input[type=color]{width:100%;padding:3px}.pp-layout-values{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.pp-layout-values label{display:flex;flex-direction:column;gap:6px;padding:9px;background:#faf8fc;border-radius:8px;font-size:12px}.pp-layout-values label div{display:flex;align-items:center;gap:6px}.pp-layout-values input{width:88px;min-height:36px;border:1px solid #e3d8ea;border-radius:8px;padding:5px 8px;font:inherit}.pp-layout-values small{grid-column:1/-1;color:#806f8e}.pp-quick-actions{display:flex;gap:5px;flex-wrap:wrap}.pp-quick-actions button{height:36px;padding:0 11px;border:1px solid #e6dceb;border-radius:8px;background:#fff;color:#49345d;display:flex;align-items:center;gap:6px;font:inherit;font-size:12px}.pp-quick-actions button:disabled{opacity:.45;cursor:not-allowed}.pp-table-wrap{width:100%;overflow:auto;border:1px solid #eadff0;border-radius:12px;background:#fff}.pp-table{width:100%;border-collapse:collapse;min-width:900px;white-space:normal}.pp-table th{background:#FFA015;color:#241735;font-size:15px;padding:11px 9px;text-align:right;white-space:nowrap}.pp-table td{border-bottom:1px solid #f0eaf4;padding:9px;font-size:14px;vertical-align:middle}.pp-table tbody tr:nth-child(even){background:#FAF8FC}.pp-table tbody tr:hover{background:#F5EFFB}.pp-table td small{display:block;color:#9688a1;font-size:12px;margin-top:3px}.pp-value-cell{max-width:330px;overflow-wrap:anywhere}.pp-lock-note{color:#95651a!important}.pp-user-picker{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:7px;max-height:190px;overflow:auto;padding:9px;border:1px solid #eadff0;border-radius:9px}.pp-user-picker label{display:flex;align-items:center;gap:7px;font-size:12px}.pp-modal-backdrop{position:fixed;inset:0;background:#1a0c28a8;z-index:1000;display:grid;place-items:center;padding:18px}.pp-preview-modal{width:min(900px,100%);max-height:85vh;overflow:auto;background:white;border-radius:16px;padding:18px;display:flex;flex-direction:column;gap:12px}.pp-preview-list{display:flex;flex-direction:column;gap:7px}.pp-preview-list>div{display:flex;justify-content:space-between;gap:12px;padding:9px;background:#faf8fc;border-radius:8px;font-size:12px}.pp-preview-list span{max-width:55%;overflow-wrap:anywhere;color:#756984}@media print{.pp-quick-actions,.pp-toolbar,.pp-tabs,.pp-edit,.pp-editor{display:none!important}.program-policies{color:#000}.pp-table-wrap{overflow:visible}.pp-table{min-width:0}}`}</style>
 </section>;
}
