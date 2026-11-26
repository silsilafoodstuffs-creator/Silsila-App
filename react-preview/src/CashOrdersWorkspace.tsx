import {useEffect,useMemo,useState} from "react";
import {CheckCircle2,FileText,Plus,RefreshCw,Wallet} from "lucide-react";
import {supabase} from "./supabase";
type Party={id:string;party_name:string;party_kind:string};
type Cashbox={id:string;cashbox_name:string;is_bank_account:boolean;account_id:string};
type Account={id:string;account_code:string;account_name:string;account_type:string};
type Order={id:string;order_number:string;order_date:string;order_type:"receipt"|"payment";party_type:string;party_id:string|null;party_name:string;amount:number;description:string;sales_document_id:string|null;status:"draft"|"approved"|"converted"|"cancelled";cash_voucher_id:string|null};
type SalesDoc={id:string;document_number:string;customer_id:string;grand_total:number;paid_total:number;status:string;document_type:string};
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-")};
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
export default function CashOrdersWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"",userId=sessionStorage.getItem("silsila-user-id")||"",role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId&&userId),canCreate=["owner","admin","manager","operator","accountant"].includes(role),canApprove=["owner","admin","manager","accountant"].includes(role),canConvert=["owner","admin","manager","accountant"].includes(role);
 const [orders,setOrders]=useState<Order[]>([]),[parties,setParties]=useState<Party[]>([]),[cashboxes,setCashboxes]=useState<Cashbox[]>([]),[accounts,setAccounts]=useState<Account[]>([]),[salesDocs,setSalesDocs]=useState<SalesDoc[]>([]);
 const [type,setType]=useState<"receipt"|"payment">("receipt"),[partyType,setPartyType]=useState<"customer"|"supplier">("customer"),[partyId,setPartyId]=useState(""),[salesDocId,setSalesDocId]=useState(""),[date,setDate]=useState(today()),[amount,setAmount]=useState(""),[description,setDescription]=useState("");
 const [filter,setFilter]=useState("all"),[loading,setLoading]=useState(live),[saving,setSaving]=useState(false),[notice,setNotice]=useState("");
 const [cashboxByOrder,setCashboxByOrder]=useState<Record<string,string>>({}),[accountByOrder,setAccountByOrder]=useState<Record<string,string>>({});
 const selectedParty=parties.find(p=>p.id===partyId),selectedDoc=salesDocs.find(d=>d.id===salesDocId);
 const reservedForDoc=(id:string)=>orders.filter(o=>o.sales_document_id===id&&o.status!=="cancelled").reduce((sum,o)=>sum+Number(o.amount),0);
 const outstanding=selectedDoc?Math.max(0,Number(selectedDoc.grand_total)-Number(selectedDoc.paid_total)-reservedForDoc(selectedDoc.id)):0;
 const load=async()=>{
  if(!live||!supabase){setLoading(false);return}setLoading(true);setNotice("");
  const [o,p,c,a,d]=await Promise.all([
   supabase.from("erp_cash_orders").select("*").eq("company_id",companyId).order("created_at",{ascending:false}).limit(100),
   supabase.from("erp_parties").select("id,party_name,party_kind").eq("company_id",companyId).eq("is_active",true).order("party_name"),
   supabase.from("erp_cashboxes").select("id,cashbox_name,is_bank_account,account_id").eq("company_id",companyId).eq("is_active",true).eq("is_bank_account",false).order("cashbox_name"),
   supabase.from("erp_accounts").select("id,account_code,account_name,account_type").eq("company_id",companyId).eq("is_active",true).eq("is_postable",true).order("account_code"),
   supabase.from("erp_sales_documents").select("id,document_number,customer_id,grand_total,paid_total,status,document_type").eq("company_id",companyId).eq("document_type","order").in("status",["approved","posted"]).order("document_date",{ascending:false}).limit(200)
  ]);
  const err=o.error||p.error||c.error||a.error||d.error;if(err){setNotice("تعذر تحميل أوامر الخزينة: "+err.message);setLoading(false);return}
  setOrders((o.data||[]) as Order[]);setParties((p.data||[]) as Party[]);setCashboxes((c.data||[]) as Cashbox[]);setAccounts((a.data||[]) as Account[]);setSalesDocs((d.data||[]) as SalesDoc[]);setLoading(false);
 };
 useEffect(()=>{void load()},[companyId,live]);
 const visible=useMemo(()=>orders.filter(o=>filter==="all"||o.status===filter),[orders,filter]);
 const partyOptions=parties.filter(p=>partyType==="customer"?(p.party_kind==="customer"||p.party_kind==="both"):partyType==="supplier"?(p.party_kind==="supplier"||p.party_kind==="both"):true);
 const docOptions=salesDocs.filter(d=>d.customer_id===partyId&&Number(d.grand_total)-Number(d.paid_total)-reservedForDoc(d.id)>0);
 const reset=()=>{setPartyId("");setSalesDocId("");setAmount("");setDescription("");setDate(today())};
 const save=async()=>{
  if(!live||!supabase||!canCreate)return;
  if(!selectedParty||!partyId){setNotice("اختر العميل أو المورد أولًا.");return}
  if(type==="receipt"&&partyType!=="customer"){setNotice("أمر التوريد من هذا المسار مخصص للعملاء.");return}
  if(type==="payment"&&partyType!=="supplier"){setNotice("أمر الصرف من هذا المسار مخصص للموردين.");return}
  const value=Number(amount);if(!Number.isFinite(value)||value<=0){setNotice("أدخل مبلغًا أكبر من صفر.");return}
  if(!date||date>today()){setNotice("تاريخ الأمر مطلوب ولا يجوز أن يكون في المستقبل.");return}
  if(salesDocId&&(!selectedDoc||selectedDoc.customer_id!==partyId||value>outstanding)){setNotice("قيمة الأمر لا يجوز أن تتجاوز المبلغ المتبقي على أمر البيع.");return}
  setSaving(true);setNotice("");
  const {data,error}=await supabase.from("erp_cash_orders").insert({company_id:companyId,order_date:date,order_type:type,party_type:partyType,party_id:partyId,party_name:selectedParty.party_name,amount:value,description:description.trim(),sales_document_id:type==="receipt"?salesDocId||null:null,status:"draft",created_by:userId}).select("*").single();
  if(error){setNotice("لم يتم حفظ الأمر: "+error.message);setSaving(false);return}
  setOrders(old=>[data as Order,...old]);setNotice("تم إنشاء أمر "+(type==="receipt"?"توريد":"صرف")+" كمسودة بالكود المركزي "+data.order_number+". لم تتحرك الخزينة بعد.");reset();setSaving(false);
 };
 const approve=async(o:Order)=>{
  if(!live||!supabase||!canApprove||o.status!=="draft")return;
  if(!window.confirm("اعتماد الأمر "+o.order_number+"؟ الاعتماد لا ينشئ حركة نقدية بعد."))return;
  setSaving(true);const {data,error}=await supabase.from("erp_cash_orders").update({status:"approved",approved_by:userId,approved_at:new Date().toISOString()}).eq("id",o.id).eq("company_id",companyId).eq("status","draft").select("*").maybeSingle();
  if(error||!data){setNotice(error?"تعذر اعتماد الأمر: "+error.message:"لم يتم الاعتماد؛ ربما تغيرت حالة الأمر.");await load()}else{setOrders(old=>old.map(x=>x.id===o.id?data as Order:x));setNotice("تم اعتماد الأمر. لم تُسجل حركة خزينة قبل التنفيذ.")}setSaving(false);
 };
 const convert=async(o:Order)=>{
  if(!live||!supabase||!canConvert||!["draft","approved"].includes(o.status))return;
  const cashboxId=cashboxByOrder[o.id]||"",accountId=accountByOrder[o.id]||"";
  if(!cashboxId||!accountId){setNotice("حدد الخزينة والحساب المقابل قبل التنفيذ.");return}
  if(!window.confirm("تنفيذ الأمر "+o.order_number+" بقيمة "+money(Number(o.amount))+" ج.م؟ سينشأ سند خزينة وحركة نقدية مرتبطة داخل قاعدة البيانات."))return;
  setSaving(true);setNotice("");
  const {data,error}=await supabase.rpc("erp_convert_cash_order",{p_order_id:o.id,p_cashbox_id:cashboxId,p_counter_account_id:accountId});
  if(error){setNotice("تعذر تنفيذ الأمر دون إنشاء حركة مكتملة: "+error.message);setSaving(false);return}
  await load();setNotice("تم تنفيذ الأمر وإنشاء حركة نقدية وسند خزينة مرتبطين. رقم الحركة: "+String(data||"—"));setSaving(false);
 };
  return <section className="treasury-workspace" dir="rtl">
  <div className="operation-heading"><div className="operation-title"><span className="operation-icon"><Wallet size={22}/></span><div><small>{live?"اتصال مباشر بقاعدة سلسلة":"وضع المعاينة"}</small><h2>أوامر الصرف والتوريد</h2><p>إنشاء الأوامر واعتمادها ثم تنفيذها وربط الحركة بسند الخزينة.</p></div></div><span className="demo-pill">{live?"متصل بقاعدة المنشأة":"معاينة فقط"}</span></div>
  <div className="treasury-editor"><div className="treasury-editor-head"><div><b><Plus size={16}/> أمر جديد</b><small>الأمر لا يغيّر الأرصدة إلا بعد التنفيذ</small></div><div className="treasury-switch"><button className={type==="receipt"?"selected receipt":"receipt"} onClick={()=>{setType("receipt");setPartyType("customer");setPartyId("");setSalesDocId("")}}>أمر توريد / تحصيل</button><button className={type==="payment"?"selected payment":"payment"} onClick={()=>{setType("payment");setPartyType("supplier");setPartyId("");setSalesDocId("")}}>أمر صرف</button></div></div>
   <div className="treasury-fields">
    <label><span>نوع الطرف</span><input value={partyType==="customer"?"عميل":"مورد"} disabled readOnly/></label>
    <label><span>{partyType==="customer"?"العميل":"المورد"}</span><select value={partyId} onChange={e=>{setPartyId(e.target.value);setSalesDocId("")}}><option value="">اختر الطرف</option>{partyOptions.map(p=><option key={p.id} value={p.id}>{p.party_name}</option>)}</select></label>
    {type==="receipt"&&partyType==="customer"&&<label><span>ربط بأمر بيع (اختياري)</span><select value={salesDocId} onChange={e=>{setSalesDocId(e.target.value);const d=salesDocs.find(x=>x.id===e.target.value);if(d)setAmount(String(Math.max(0,Number(d.grand_total)-Number(d.paid_total)-reservedForDoc(d.id))))}}><option value="">بدون ربط بأمر بيع</option>{docOptions.map(d=><option key={d.id} value={d.id}>{d.document_number} — متبقي {money(Number(d.grand_total)-Number(d.paid_total)-reservedForDoc(d.id))} ج.م</option>)}</select></label>}
    <label><span>تاريخ الأمر</span><input type="date" value={date} max={today()} onChange={e=>setDate(e.target.value)}/></label>
    <label><span>المبلغ (ج.م)</span><input type="number" min="0.01" step="0.01" max={salesDocId?outstanding:undefined} value={amount} onChange={e=>setAmount(e.target.value)}/></label>
    <label className="treasury-notes"><span>البيان</span><input value={description} onChange={e=>setDescription(e.target.value)} placeholder="بيان الأمر"/></label>
   </div>
   <div className="treasury-form-actions"><button className="operation-save" onClick={save} disabled={saving||!live||!canCreate}><Plus size={16}/> حفظ الأمر</button><span>يُولّد رقم مركزي، وتُفصل المسودة عن الاعتماد والتنفيذ.</span></div>
  </div>
  {notice&&<div className="operation-feedback" role="status">{notice}</div>}
  {!live&&<div className="operation-feedback warning">سجّل الدخول بحساب منشأة لعرض أوامر الخزينة الفعلية أو تنفيذها.</div>}
  <div className="operation-history treasury-history"><div className="operation-table-head"><div><b><FileText size={15}/> سجل الأوامر</b><small>حتى آخر 100 أمر في نطاق المنشأة.</small></div><div className="treasury-row-actions"><select value={filter} onChange={e=>setFilter(e.target.value)}><option value="all">كل الحالات</option><option value="draft">مسودة</option><option value="approved">معتمد</option><option value="converted">منفذ</option><option value="cancelled">ملغى</option></select><button className="operation-add" onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button></div></div>
   {visible.length?<div className="table-wrap"><table><thead><tr><th>رقم الأمر</th><th>النوع</th><th>الطرف</th><th>التاريخ</th><th>المبلغ</th><th>الحالة</th><th>التنفيذ</th></tr></thead><tbody>{visible.map(o=><tr key={o.id}><td><b>{o.order_number}</b></td><td>{o.order_type==="receipt"?"توريد":"صرف"}</td><td>{o.party_name}{o.sales_document_id?" · مرتبط بأمر بيع":""}</td><td>{o.order_date}</td><td className="operation-amount">{money(Number(o.amount))} ج.م</td><td><span className={o.status==="converted"?"treasury-status posted":"treasury-status draft"}>{o.status==="draft"?"مسودة":o.status==="approved"?"معتمد":o.status==="converted"?"منفذ":"ملغى"}</span></td><td>{o.status==="converted"?<small>تم التنفيذ</small>:<div className="treasury-row-actions">{o.status==="draft"&&canApprove&&<button className="operation-add" onClick={()=>void approve(o)} disabled={saving}><CheckCircle2 size={14}/> اعتماد</button>}{canConvert&&o.status==="approved"&&<><select aria-label={"الخزينة لأمر "+o.order_number} value={cashboxByOrder[o.id]||""} onChange={e=>setCashboxByOrder(v=>({...v,[o.id]:e.target.value}))}><option value="">الخزينة</option>{cashboxes.map(c=><option key={c.id} value={c.id}>{c.cashbox_name}</option>)}</select><select aria-label={"الحساب المقابل لأمر "+o.order_number} value={accountByOrder[o.id]||""} onChange={e=>setAccountByOrder(v=>({...v,[o.id]:e.target.value}))}><option value="">الحساب المقابل</option>{accounts.filter(a=>a.account_type===(o.order_type==="payment"?"liability":"asset")&&a.id!==cashboxes.find(c=>c.id===(cashboxByOrder[o.id]||""))?.account_id).map(a=><option key={a.id} value={a.id}>{a.account_code} — {a.account_name}</option>)}</select><button className="operation-add" onClick={()=>void convert(o)} disabled={saving}>تنفيذ</button></>}</div>}</td></tr>)}</tbody></table></div>:<div className="operation-empty">{loading?"جارٍ التحميل...":"لا توجد أوامر في هذا العرض."}</div>}
  </div>
  <div className="operation-disclaimer">التنفيذ يستدعي erp_convert_cash_order ذريًا، وينشئ حركة نقدية وسند خزينة مرتبطًا بها؛ لا يتم إنشاء بيانات تجريبية في وضع المعاينة.</div>
 </section>;
}
