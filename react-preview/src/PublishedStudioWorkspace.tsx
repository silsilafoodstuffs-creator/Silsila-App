import {useEffect,useState} from "react";
import {supabase} from "./supabase";
import {Eye,ShieldCheck,RefreshCw,Layers3,AlertTriangle} from "lucide-react";
type Published={id:string;name:string;design_kind:string;revision:number;published_revision:number;updated_at:string;design_json:any};
const allowed=new Set(["text","button","field","card","divider","spacer","grid","tree","table","icon","image","chart","tabs","form","list","badge","progress","stat","container","filter"]);
export default function PublishedStudioWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const [access,setAccess]=useState(false),[ready,setReady]=useState(false),[rows,setRows]=useState<Published[]>([]),[selected,setSelected]=useState<Published|null>(null),[loading,setLoading]=useState(false),[error,setError]=useState("");
 const load=async()=>{
  if(!supabase||!companyId){setError("سجّل الدخول إلى المنشأة لعرض التصميمات المنشورة.");setReady(true);return;}
  setLoading(true);setError("");
  try{
   const {data:userResult,error:userError}=await supabase.auth.getUser();if(userError)throw userError;
   const userId=userResult.user?.id;if(!userId)throw new Error("يجب تسجيل الدخول أولًا.");
   const {data:member,error:memberError}=await supabase.from("erp_company_members").select("member_role,is_active").eq("company_id",companyId).eq("user_id",userId).maybeSingle();if(memberError)throw memberError;
   if(!member||member.is_active!==true)throw new Error("لا تملك عضوية نشطة في هذه الشركة.");
   const role=String(member.member_role||"").toLowerCase();
   if(role!=="owner"&&role!=="admin"){
    const {data:perm,error:permError}=await supabase.from("erp_user_permission_matrix").select("can_access").eq("company_id",companyId).eq("user_id",userId).eq("menu_name","إعدادات عامة").eq("submenu_name","بيانات أساسية").eq("page_name","شاشات الاستوديو المنشورة").maybeSingle();if(permError)throw permError;if(perm?.can_access!==true)throw new Error("لا تملك صلاحية عرض التصميمات المنشورة.");
   }
   setAccess(true);
   const {data,error}=await supabase.from("erp_studio_designs").select("id,name,design_kind,revision,published_revision,updated_at,design_json").eq("company_id",companyId).gt("published_revision",0).order("updated_at",{ascending:false}).range(0,199);
   if(error)throw error;setRows((data||[]) as Published[]);
  }catch(e:any){setError(e?.message||"تعذر تحميل التصميمات المنشورة.");}
  finally{setLoading(false);setReady(true);}
 };
 useEffect(()=>{void load();},[companyId]);
 const render=(n:any)=>{
  if(!allowed.has(n?.type)||!n?.props||typeof n.props!=="object")return null;
  const p=n.props,text=String(p.text||p.title||p.label||n.type);
  if(n.type==="text")return <span style={{fontSize:Number(p.size)||16,fontWeight:p.bold?800:500}}>{text}</span>;
  if(n.type==="button")return <button className="published-studio-button" disabled>{text}</button>;
  if(n.type==="field")return <label className="published-studio-field">{String(p.label||"حقل")}<input placeholder={String(p.placeholder||"")} disabled/></label>;
  if(n.type==="divider")return <hr/>;
  if(n.type==="spacer")return <div style={{height:Math.min(100,Math.max(4,Number(p.height)||16))}}/>;
  if(n.type==="badge")return <span className="published-studio-badge">{text}</span>;
  if(n.type==="progress")return <div className="published-studio-progress"><span style={{width:Math.min(100,Math.max(0,Number(p.value)||0))+"%"}}/></div>;
  if(n.type==="image")return /^https:\/\//.test(String(p.src||""))?<img src={p.src} alt={text} style={{maxWidth:"100%",maxHeight:200,objectFit:"contain"}}/>:<span>صورة غير متاحة</span>;
  return <article className="published-studio-card"><b>{text}</b><small>عنصر {n.type} · عرض منشور للقراءة فقط</small></article>;
 };
 if(!ready)return <section className="published-studio">جارٍ التحقق من صلاحيات العرض...</section>;
 return <section className="published-studio" dir="rtl">
  <header><span><Eye size={22}/></span><div><small>SILSILA STUDIO · PUBLISHED DESIGNS</small><h2>شاشات الاستوديو المنشورة</h2><p>عرض التصميمات المعتمدة والمنشورة فقط، دون تعديل أو تنفيذ إجراءات تشغيلية.</p></div><b>{rows.length} تصميم منشور</b></header>
  {error&&<div className="published-studio-error"><AlertTriangle size={15}/>{error}</div>}
  {access&&<div className="published-studio-toolbar"><button onClick={()=>void load()} disabled={loading}><RefreshCw size={15}/> تحديث</button></div>}
  {access&&<div className="published-studio-layout"><aside><h3>التصميمات المنشورة</h3>{rows.map(r=><button key={r.id} className={selected?.id===r.id?"active":""} onClick={()=>setSelected(r)}><b>{r.name}</b><small>{r.design_kind} · الإصدار المنشور {r.published_revision}</small></button>)}{!rows.length&&!loading&&<p>لا توجد تصميمات منشورة حتى الآن.</p>}</aside><div className="published-studio-canvas">{selected?<><div className="published-studio-canvas-head"><b>{selected.name}</b><small>الإصدار {selected.published_revision} · {new Date(selected.updated_at).toLocaleDateString("ar-EG")}</small></div><div className="published-studio-nodes">{(Array.isArray(selected.design_json?.nodes)?selected.design_json.nodes:[]).map((n:any)=><div key={n.id}>{render(n)}</div>)}</div></>:<div className="published-studio-empty"><Layers3 size={30}/><h3>اختر تصميمًا منشورًا</h3><p>ستظهر معاينته هنا بوضع القراءة فقط.</p></div>}</div></div>}
  <style>{`.published-studio{display:grid;gap:12px;color:#241735}.published-studio>header{display:flex;align-items:center;gap:12px;padding:17px;border-radius:14px;background:linear-gradient(120deg,#3E007D,#5d2095);color:#fff}.published-studio>header>span{width:46px;height:46px;border-radius:13px;background:#ffffff20;display:grid;place-items:center}.published-studio h2{margin:2px 0;font-size:21px}.published-studio header p,.published-studio header small{margin:0;color:#e9dcf7}.published-studio header>b{margin-inline-start:auto}.published-studio-toolbar button{height:36px;border:1px solid #e7ddec;border-radius:8px;background:#fff;padding:0 11px;display:flex;align-items:center;gap:6px}.published-studio-layout{display:grid;grid-template-columns:240px minmax(0,1fr);gap:10px;min-height:430px}.published-studio-layout>aside,.published-studio-canvas{background:#fff;border:1px solid #eadff0;border-radius:12px;padding:12px;min-width:0}.published-studio-layout h3{margin:0 0 10px;color:#3E007D;font-size:14px}.published-studio-layout aside button{width:100%;display:flex;flex-direction:column;align-items:flex-start;gap:4px;padding:10px;border:0;border-radius:8px;background:#faf8fc;margin:4px 0;text-align:right;color:#38244c}.published-studio-layout aside button.active{background:#f0e6fa;outline:1px solid #d8c3eb}.published-studio-layout aside small,.published-studio-canvas-head small{font-size:10px;color:#81738d}.published-studio-canvas-head{display:flex;justify-content:space-between;gap:10px;padding-bottom:10px;border-bottom:1px solid #eee6f3}.published-studio-nodes{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;padding-top:12px}.published-studio-nodes>div{background:#faf8fc;border:1px solid #eee6f3;border-radius:9px;padding:10px;min-width:0}.published-studio-button{height:36px;border:0;border-radius:8px;background:#3E007D;color:#fff;padding:0 13px}.published-studio-field{display:flex;flex-direction:column;gap:5px;font-size:12px}.published-studio-field input{height:38px;border:1px solid #e5dceb;border-radius:7px;padding:0 8px}.published-studio-badge{display:inline-block;border-radius:999px;padding:5px 10px;background:#f0e6fa;color:#3E007D;font-size:11px}.published-studio-card{display:flex;flex-direction:column;gap:6px}.published-studio-card small{font-size:11px;color:#83758f}.published-studio-progress{height:8px;background:#eee6f3;border-radius:99px;overflow:hidden}.published-studio-progress span{display:block;height:100%;background:#FFA015}.published-studio-empty{height:100%;min-height:350px;display:grid;place-content:center;justify-items:center;color:#84758f}.published-studio-error{display:flex;gap:8px;padding:10px;border-radius:8px;background:#fff1ef;color:#a33a31;font-size:12px}@media(max-width:650px){.published-studio-layout{grid-template-columns:1fr}.published-studio-layout>aside{max-height:180px;overflow:auto}.published-studio-nodes{grid-template-columns:1fr}.published-studio>header>b{font-size:11px}}`}</style>
 </section>;
}
