import {useEffect,useMemo,useState} from "react";
import {supabase} from "./supabase";
import SILSILA_LOGO from "./brand";
import {Activity,CalendarDays,Package,RefreshCw,ShoppingCart,Users,Wallet,ChartNoAxesCombined,Sparkles,Camera,FileBarChart,Medal} from "lucide-react";

type Metrics={sales:number|null;purchases:number|null;grossProfit:number|null;expenses:number|null};
type StaffRow={id:string;name:string;total:number;count:number};
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const day=(d:Date)=>d.toISOString().slice(0,10);
function range(period:string){
 const now=new Date(),end=new Date(now);end.setHours(23,59,59,999);
 const start=new Date(end);
 if(period==="اليوم")start.setHours(0,0,0,0);
 else if(period==="آخر 7 أيام")start.setDate(start.getDate()-6);
 else if(period==="آخر 30 يومًا")start.setDate(start.getDate()-29);
 else if(period==="هذا الشهر")start.setDate(1);
 else if(period==="هذا الربع")start.setMonth(Math.floor(start.getMonth()/3)*3,1);
 else if(period==="هذا العام")start.setMonth(0,1);
 else if(period==="العام السابق"){start.setFullYear(now.getFullYear()-1,0,1);end.setFullYear(now.getFullYear()-1,11,31);}
 return {start:day(start),end:day(end)};
}
function previousYearSpan(span:{start:string;end:string}){
 const a=new Date(span.start+"T12:00:00"),b=new Date(span.end+"T12:00:00");
 a.setFullYear(a.getFullYear()-1);b.setFullYear(b.getFullYear()-1);
 return {start:day(a),end:day(b)};
}
const blank:Metrics={sales:null,purchases:null,grossProfit:null,expenses:null};
const val=(row:any,key:string):number|null=>row?.[key]===null||row?.[key]===undefined?null:Number(row[key]);
export default function ExecutiveDashboard({period,onNavigate}:{period:string;onNavigate:(name:string)=>void}){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const [metrics,setMetrics]=useState<Metrics>(blank),[previous,setPrevious]=useState<Metrics>(blank);
 const [customers,setCustomers]=useState<number|null>(null),[salesReps,setSalesReps]=useState<StaffRow[]>([]),[buyers,setBuyers]=useState<StaffRow[]>([]);
 const [loading,setLoading]=useState(true),[error,setError]=useState(""),[access,setAccess]=useState<"checking"|"allowed"|"denied">("checking");
 const span=useMemo(()=>range(period),[period]);
 const load=async()=>{
  if(!supabase||!companyId){setMetrics(blank);setPrevious(blank);setCustomers(null);setSalesReps([]);setBuyers([]);setError("سجّل الدخول إلى منشأة نشطة لعرض المؤشرات الفعلية.");setLoading(false);setAccess("denied");return;}
  setLoading(true);setError("");
  const db=supabase;
  try{
   const {data:{user}}=await supabase.auth.getUser();
   if(!user)throw new Error("انتهت جلسة الدخول. سجّل الدخول مرة أخرى.");
   const role=(sessionStorage.getItem("silsila-member-role")||"").toLowerCase();
   let permitted=["owner","admin","administrator","systemadmin"].includes(role);
   if(!permitted){
    const {data:erpUser,error:userError}=await db.from("erp_users").select("id").eq("company_id",companyId).eq("auth_user_id",user.id).eq("is_active",true).maybeSingle();
    if(userError)throw userError;
    if(erpUser?.id){
     const {data:permission,error:permissionError}=await supabase.from("erp_user_permission_matrix").select("can_access").eq("company_id",companyId).eq("user_id",erpUser.id).eq("menu_name","إعدادات عامة").eq("submenu_name","بيانات أساسية").eq("page_name","الملخص التنفيذي").maybeSingle();
     if(permissionError)throw permissionError;
     permitted=permission?.can_access===true;
    }
   }
   if(!permitted){setAccess("denied");setMetrics(blank);setPrevious(blank);setSalesReps([]);setBuyers([]);setCustomers(null);setLoading(false);return;}
   setAccess("allowed");
   const prior=previousYearSpan(span);
   const fetchMetrics=async(start:string,end:string):Promise<Metrics>=>{
    const {data,error}=await db.rpc("erp_get_executive_metrics",{p_company_id:companyId,p_month_start:start,p_month_end:end});
    if(error)throw error;
    const row=data as any;
    return {sales:val(row,"sales"),purchases:val(row,"purchases"),grossProfit:val(row,"gross_profit_estimate"),expenses:val(row,"expenses")};
   };
   const [currentResult,previousResult,customerResult]=await Promise.allSettled([
    fetchMetrics(span.start,span.end),fetchMetrics(prior.start,prior.end),
    supabase.from("erp_parties").select("id",{count:"exact",head:true}).eq("company_id",companyId).eq("party_kind","customer").eq("is_active",true).eq("is_demo_data",false)
   ]);
   if(currentResult.status==="fulfilled")setMetrics(currentResult.value);else throw currentResult.reason;
   setPrevious(previousResult.status==="fulfilled"?previousResult.value:blank);
   if(customerResult.status==="fulfilled"){if(customerResult.value.error)throw customerResult.value.error;setCustomers(customerResult.value.count||0);}
   else setCustomers(null);
   const from=span.start,to=new Date(span.end+"T12:00:00");to.setDate(to.getDate()+1);const until=day(to);
   const [repResult,docResult,employeeResult,purchaseResult,userResult]=await Promise.allSettled([
    supabase.from("erp_sales_representatives").select("id,rep_code,rep_name,is_demo_data,is_active").eq("company_id",companyId).eq("is_active",true),
    supabase.from("erp_sales_documents").select("sales_rep_id,grand_total,document_type").eq("company_id",companyId).eq("status","posted").eq("is_demo_data",false).gte("document_date",from).lt("document_date",until),
    supabase.from("erp_employee_directory").select("id,employee_code,full_name,job_title,department_name,is_active,is_demo_data").eq("company_id",companyId).eq("is_active",true),
    supabase.from("erp_purchase_documents").select("created_by,grand_total").eq("company_id",companyId).eq("status","posted").eq("is_demo_data",false).gte("document_date",from).lt("document_date",until),
    supabase.from("erp_users").select("auth_user_id,employee_id").eq("company_id",companyId).eq("is_active",true)
   ]);
   const rows=(result:any)=>result.status==="fulfilled"&&!result.value.error?(result.value.data||[]):[];
   const reps=rows(repResult),salesDocs=rows(docResult),employees=rows(employeeResult),purchaseDocs=rows(purchaseResult),users=rows(userResult);
   const repTotals=new Map<string,StaffRow>();
   for(const rep of reps){if(rep.is_demo_data===true)continue;const id=String(rep.id);repTotals.set(id,{id,name:rep.rep_name||rep.rep_code||"مندوب غير مسمى",total:0,count:0});}
   for(const doc of salesDocs){const id=String(doc.sales_rep_id||"");const item=repTotals.get(id);if(item){item.total+=Number(doc.grand_total||0)*(doc.document_type==="return"?-1:1);item.count++;}}
   setSalesReps([...repTotals.values()].filter(x=>x.count>0).sort((a,b)=>b.total-a.total).slice(0,5));
   const authByEmployee=new Map<string,string>(users.map((u:any):[string,string]=>[String(u.employee_id),String(u.auth_user_id)]));
   const employeeByUser=new Map<string,any>();
   for(const emp of employees){if(emp.is_demo_data===true)continue;const authId=authByEmployee.get(String(emp.id));if(authId)employeeByUser.set(authId,emp);employeeByUser.set(String(emp.id),emp);}
   const buyerTotals=new Map<string,StaffRow>();
   for(const doc of purchaseDocs){const id=String(doc.created_by||"");const emp=employeeByUser.get(id);if(!emp)continue;const key=String(emp.id);const item=buyerTotals.get(key)||{id:key,name:emp.full_name||emp.employee_code||"مسؤول مشتريات",total:0,count:0};item.total+=Number(doc.grand_total||0);item.count++;buyerTotals.set(key,item);}
   setBuyers([...buyerTotals.values()].sort((a,b)=>b.total-a.total).slice(0,5));
   const optionalFailures=[repResult,docResult,employeeResult,purchaseResult,userResult].some((x:any)=>x.status==="rejected"||(x.status==="fulfilled"&&x.value.error));
   if(optionalFailures)setError("تم تحميل المؤشرات الرئيسية؛ بعض قوائم الأداء غير متاحة بسبب صلاحية أو نقص بيانات المصدر.");
  }catch(e:any){setError("تعذر تحميل الملخص التنفيذي: "+(e?.message||"خطأ غير معروف"));setMetrics(blank);setPrevious(blank);}
  finally{setLoading(false);}
 };
 useEffect(()=>{void load();},[companyId,span.start,span.end]);
 const net=metrics.grossProfit===null||metrics.expenses===null?null:metrics.grossProfit-metrics.expenses;
 const priorNet=previous.grossProfit===null||previous.expenses===null?null:previous.grossProfit-previous.expenses;
 const delta=(now:number|null,old:number|null)=>now===null||old===null||old===0?null:((now-old)/Math.abs(old))*100;
 const kpis=[
  {title:"صافي نتيجة النشاط التقديرية",value:net,prior:priorNet,note:"مجمل الربح التقديري بعد المصروفات المسجلة",icon:Wallet,tone:"green"},
  {title:"صافي المبيعات",value:metrics.sales,prior:previous.sales,note:"بعد خصم مرتجعات المبيعات",icon:ShoppingCart,tone:"purple"},
  {title:"صافي المشتريات",value:metrics.purchases,prior:previous.purchases,note:"بعد خصم مرتجعات المشتريات",icon:Package,tone:"blue"}
 ];
 const rankCard=(title:string,items:StaffRow[])=> <section className="executive-live-panel"><header><div><Medal size={18}/><b>{title}</b></div><small>أعلى 5 حسب قيمة المستندات المرحلة</small></header>{items.length?<div className="executive-ranking">{items.map((item,i)=><div className="executive-rank-row" key={item.id}><span className="executive-rank-number">{i+1}</span><div className="executive-rank-person"><b>{item.name}</b><small>{item.count.toLocaleString("ar-EG")} مستند</small></div><strong>{money(item.total)} <small>ج.م</small></strong></div>)}</div>:<div className="executive-live-empty">{loading?"جارٍ تحميل الأداء...":"لا توجد مستندات أداء مسجلة في الفترة."}</div>}</section>;
 return <section className="executive-live" dir="rtl">
  <div className="silsila-visual-hero"><div className="silsila-visual-brand"><img src={SILSILA_LOGO} alt="شعار سلسلة"/><div><b>سلسلة</b><span>SILSILA · BUSINESS OS</span><small>سلسلة .. بنربط السوق ببعضه</small></div></div><div className="silsila-visual-copy"><small><Sparkles size={14}/> منظومة إدارة أعمالك المتكاملة</small><h2>تجارتك اليومية تبدأ من هنا</h2><p>إدارة أكثر وضوحًا، وقرارات أسرع، وسوق مربوط ببعضه</p><div className="silsila-visual-underline"/></div><div className="silsila-visual-art" aria-hidden="true"><div className="silsila-visual-bars"><i/><i/><i/><i/><i/></div><div className="silsila-visual-cart"><ShoppingCart size={58}/><span><Package size={25}/></span></div><div className="silsila-visual-orbit"/></div></div>
  <div className="silsila-quick-actions"><button onClick={()=>onNavigate("فواتير البيع")}><ShoppingCart size={18}/><span>فاتورة البيع</span></button><button onClick={()=>onNavigate("جامع صور الأصناف")}><Camera size={18}/><span>جامع صور الأصناف</span></button></div>
  <div className="executive-live-head"><div><small>لوحة الأداء · بيانات فعلية من قاعدة المنشأة</small><h2>مؤشرات الأداء الرئيسية</h2><p>الفترة: {span.start} — {span.end} · مقارنة بنفس الفترة من العام السابق · مستندات مرحلة فقط · استبعاد السجلات التجريبية</p></div><button onClick={()=>void load()} disabled={loading}><RefreshCw size={15}/> تحديث</button></div>
  {error&&<div className="executive-live-error" role="status">{error}</div>}
  {access==="denied"?<div className="executive-live-empty">لا توجد صلاحية لعرض الملخص التنفيذي، أو لم يتم اختيار منشأة نشطة.</div>:<>
   <div className="executive-live-kpis">{kpis.map((k,i)=>{const change=delta(k.value,k.prior);const Icon=k.icon;return <article key={k.title} className={"executive-kpi-"+k.tone}><span><Icon size={17}/>{k.title}</span><b>{loading||k.value===null?"—":money(k.value)} <small>ج.م</small></b><i>{k.note}</i><em>{change===null?"لا تتوفر مقارنة":(change>0?"+":"")+money(change)+"% عن العام السابق"}</em></article>})}</div>
   <div className="executive-live-grid"><section className="executive-live-panel"><header><div><ChartNoAxesCombined size={17}/><b>ملخص النشاط</b></div><small>مصدر الأرقام: مؤشرات ERP المعتمدة</small></header><div className="executive-live-facts"><div><span>العملاء النشطون</span><b>{loading?"—":customers===null?"—":customers.toLocaleString("ar-EG")}</b></div><div><span>مجمل الربح التقديري</span><b>{loading||metrics.grossProfit===null?"—":money(metrics.grossProfit)+" ج.م"}</b></div><div><span>المصروفات المسجلة</span><b>{loading||metrics.expenses===null?"—":money(metrics.expenses)+" ج.م"}</b></div><div><span>حالة البيانات</span><b>{loading?"تحميل":error?"مراجعة":"مباشرة"}</b></div></div></section><section className="executive-live-panel"><header><div><CalendarDays size={17}/><b>مقارنة سنوية</b></div><small>نفس النطاق الزمني من العام السابق</small></header><div className="executive-compare-list">{kpis.map(k=><div key={k.title}><span>{k.title}</span><b>{k.prior===null?"غير متاح":money(k.prior)+" ج.م"}</b></div>)}</div></section></div>
   <div className="executive-live-grid executive-rank-grid">{rankCard("أفضل 5 مندوبي المبيعات",salesReps)}{rankCard("أفضل 5 مسؤولي المشتريات",buyers)}</div>
  </>}
  <div className="executive-live-note">لا تعرض اللوحة أرقامًا افتراضية. نتيجة النشاط تقديرية وتعتمد على مجمل الربح والمصروفات التي يعيدها مصدر المؤشرات؛ ولا تُعد بديلًا عن صافي الربح المحاسبي المعتمد من دفتر الأستاذ.</div>
 </section>;
}
