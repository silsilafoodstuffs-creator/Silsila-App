import {useEffect,useMemo,useState} from "react";
import {supabase} from "./supabase";
import SILSILA_LOGO from "./brand";
import {Activity,ArrowDownLeft,ArrowUpLeft,CalendarDays,Package,RefreshCw,ShoppingCart,Users,Wallet,ChartNoAxesCombined,Sparkles,Camera,FileBarChart} from "lucide-react";
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
function range(period:string){const end=new Date();end.setHours(23,59,59,999);const start=new Date(end);if(period==="اليوم")start.setHours(0,0,0,0);else if(period==="آخر 7 أيام")start.setDate(start.getDate()-6);else if(period==="آخر 30 يومًا")start.setDate(start.getDate()-29);else if(period==="هذا الشهر")start.setDate(1);else if(period==="هذا الربع"){start.setMonth(Math.floor(start.getMonth()/3)*3,1);}else if(period==="هذا العام"){start.setMonth(0,1);}return {start:start.toISOString().slice(0,10),end:end.toISOString().slice(0,10)};}
export default function ExecutiveDashboard({period,onNavigate}:{period:string;onNavigate:(name:string)=>void}){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const [sales,setSales]=useState<any[]>([]),[purchases,setPurchases]=useState<any[]>([]),[customers,setCustomers]=useState(0),[loading,setLoading]=useState(true),[error,setError]=useState("");
 const span=useMemo(()=>range(period),[period]);
 const load=async()=>{if(!supabase||!companyId){setSales([]);setPurchases([]);setCustomers(0);setError("سجّل الدخول إلى المنشأة لعرض مؤشرات حقيقية.");setLoading(false);return;}setLoading(true);setError("");
  const [s,p,c]=await Promise.all([
   supabase.from("erp_sales_documents").select("id,document_date,grand_total,status,document_type").eq("company_id",companyId).eq("is_demo_data",false).eq("status","posted").gte("document_date",span.start).lte("document_date",span.end).order("document_date"),
   supabase.from("erp_purchase_documents").select("id,document_date,grand_total,status,document_type").eq("company_id",companyId).eq("is_demo_data",false).eq("status","posted").gte("document_date",span.start).lte("document_date",span.end).order("document_date"),
   supabase.from("erp_parties").select("id",{count:"exact",head:true}).eq("company_id",companyId).eq("party_kind","customer").eq("is_active",true).eq("is_demo_data",false)
  ]);
  const e=s.error||p.error||c.error;if(e)setError("تعذر تحميل الملخص: "+e.message);
  setSales(s.data||[]);setPurchases(p.data||[]);setCustomers(c.count||0);setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,span.start,span.end]);
 const salesTotal=sales.reduce((n,r)=>n+Number(r.grand_total||0),0),purchaseTotal=purchases.reduce((n,r)=>n+Number(r.grand_total||0),0),delta=salesTotal-purchaseTotal;
 const trend=useMemo(()=>{const m=new Map<string,{sales:number;purchase:number}>();for(const r of sales){const k=r.document_date;(m.get(k)||m.set(k,{sales:0,purchase:0}).get(k)!).sales+=Number(r.grand_total||0);}for(const r of purchases){const k=r.document_date;(m.get(k)||m.set(k,{sales:0,purchase:0}).get(k)!).purchase+=Number(r.grand_total||0);}return [...m.entries()].sort((a,b)=>a[0].localeCompare(b[0])).slice(-12);},[sales,purchases]);
 const max=Math.max(1,...trend.flatMap(x=>[x[1].sales,x[1].purchase]));
 return <section className="executive-live" dir="rtl">
  <div className="silsila-visual-hero">
   <div className="silsila-visual-brand"><img src={SILSILA_LOGO} alt="شعار سلسلة"/><div><b>سلسلة</b><span>SILSILA · BUSINESS OS</span><small>سلسلة .. بنربط السوق ببعضه</small></div></div>
   <div className="silsila-visual-copy"><small><Sparkles size={14}/> منظومة إدارة أعمالك المتكاملة</small><h2>تجارتك اليومية تبدأ من هنا</h2><p>إدارة أكثر وضوحًا، وقرارات أسرع، وسوق مربوط ببعضه</p><div className="silsila-visual-underline"/></div>
   <div className="silsila-visual-art" aria-hidden="true"><div className="silsila-visual-bars"><i/><i/><i/><i/><i/></div><div className="silsila-visual-cart"><ShoppingCart size={58}/><span><Package size={25}/></span></div><div className="silsila-visual-orbit"/></div>
  </div>
  <div className="silsila-quick-actions">
   <button onClick={()=>onNavigate("فواتير البيع")}><ShoppingCart size={18}/><span>فاتورة البيع</span></button>
   <button onClick={()=>onNavigate("جامع صور الأصناف")}><Camera size={18}/><span>جامع صور الأصناف</span></button>
   <button onClick={()=>onNavigate("المخازن والأصناف")}><Package size={18}/><span>إدارة الأصناف</span></button>
   <button onClick={()=>onNavigate("تقارير المبيعات")}><FileBarChart size={18}/><span>تقارير المبيعات</span></button>
  </div>
  <div className="executive-live-head"><div><small>لوحة الأداء · بيانات فعلية من قاعدة المنشأة</small><h2>مؤشرات الأداء الرئيسية</h2><p>الفترة: {span.start} — {span.end} · المستندات المرحلة فقط · استبعاد السجلات التجريبية</p></div><button onClick={()=>void load()} disabled={loading}><RefreshCw size={15}/> تحديث</button></div>
  {error&&<div className="executive-live-error">{error}</div>}
  <div className="executive-live-kpis">
   <article><span><ShoppingCart size={17}/> صافي المبيعات المرحلة</span><b>{loading?"—":money(salesTotal)} <small>ج.م</small></b><i>{sales.length.toLocaleString("ar-EG")} مستند</i></article>
   <article><span><Package size={17}/> صافي المشتريات المرحلة</span><b>{loading?"—":money(purchaseTotal)} <small>ج.م</small></b><i>{purchases.length.toLocaleString("ar-EG")} مستند</i></article>
   <article><span><Activity size={17}/> فرق المبيعات والمشتريات</span><b>{loading?"—":money(delta)} <small>ج.م</small></b><i>مؤشر حركة وليس صافي ربح محاسبي</i></article>
   <article><span><Users size={17}/> العملاء النشطون</span><b>{loading?"—":customers.toLocaleString("ar-EG")}</b><i>حسب ملفات العملاء النشطة</i></article>
  </div>
  <div className="executive-live-grid"><section><header><div><ChartNoAxesCombined size={17}/><b>حركة المستندات المرحلة</b></div><small>قيمة المبيعات والمشتريات حسب اليوم</small></header>{trend.length?<div className="executive-live-chart">{trend.map(([day,v])=><div className="executive-live-day" key={day}><div className="executive-live-bars"><i title={"مبيعات "+money(v.sales)} style={{height:Math.max(3,v.sales/max*100)+"%"}}/><i title={"مشتريات "+money(v.purchase)} style={{height:Math.max(3,v.purchase/max*100)+"%"}}/></div><small>{new Date(day).toLocaleDateString("ar-EG",{day:"numeric",month:"numeric"})}</small></div>)}</div>:<div className="executive-live-empty">{loading?"جارٍ تحميل المؤشرات...":"لا توجد مستندات مرحلة خلال الفترة المختارة."}</div>}<div className="executive-live-legend"><span><i/> المبيعات</span><span><i/> المشتريات</span></div></section>
   <section><header><div><Wallet size={17}/><b>ملخص النشاط</b></div><small>مصدر البيانات والحالة</small></header><div className="executive-live-facts"><div><span>مستندات المبيعات</span><b>{sales.length.toLocaleString("ar-EG")}</b></div><div><span>مستندات المشتريات</span><b>{purchases.length.toLocaleString("ar-EG")}</b></div><div><span>العملاء النشطون</span><b>{customers.toLocaleString("ar-EG")}</b></div><div><span>حالة البيانات</span><b>{loading?"تحميل":error?"بحاجة لمراجعة":"مباشرة"}</b></div></div></section></div>
  <div className="executive-live-note">لا تعرض اللوحة أرقامًا افتراضية ولا تعتبر الفرق بين المبيعات والمشتريات صافي ربح. صافي نتيجة النشاط يحتاج اكتمال احتساب الإيرادات والمصروفات والقيود المرحلة من دفتر الأستاذ.</div>
 </section>;
}
