import { useEffect, useMemo, useState } from "react";
import { postVoucherJournal } from "./accounting";
import { ArrowDownToLine, ArrowUpFromLine, CheckCircle2, FileText, Plus, ReceiptText, Trash2, Wallet } from "lucide-react";

type VoucherKind = "receipt" | "payment";
type VoucherStatus = "draft" | "posted";
type Voucher = { id:string; kind:VoucherKind; status:VoucherStatus; party:string; date:string; amount:number; method:string; reference:string; notes:string; createdAt:string; postedAt?:string };
const STORE="silsila-react-preview:treasury:vouchers";
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-");};
const read=():Voucher[]=>{try{const v=localStorage.getItem(STORE);return v?JSON.parse(v):[];}catch{return [];}};

export default function TreasuryWorkspace(){
 const [vouchers,setVouchers]=useState<Voucher[]>(read);
 const [kind,setKind]=useState<VoucherKind>("receipt");
 const [party,setParty]=useState("");
 const [date,setDate]=useState(today());
 const [amount,setAmount]=useState("0");
 const [method,setMethod]=useState("نقدي");
 const [reference,setReference]=useState("");
 const [notes,setNotes]=useState("");
 const [message,setMessage]=useState("");
 const [filter,setFilter]=useState<"all"|"draft"|"posted">("all"); const [columnFilters,setColumnFilters]=useState<string[]>(Array(7).fill(""));
 useEffect(()=>{try{localStorage.setItem(STORE,JSON.stringify(vouchers));}catch{setMessage("تعذر الحفظ في مساحة المتصفح المحلية.");}},[vouchers]);
 const posted=vouchers.filter(v=>v.status==="posted");
 const receipts=posted.filter(v=>v.kind==="receipt").reduce((s,v)=>s+v.amount,0);
 const payments=posted.filter(v=>v.kind==="payment").reduce((s,v)=>s+v.amount,0);
 const balance=receipts-payments;
 const visible=useMemo(()=>vouchers.filter(v=>(filter==="all"||v.status===filter)&&[v.id,v.kind==="receipt"?"قبض":"صرف",v.party,v.date,money(v.amount),v.method,v.status==="posted"?"معتمد محليًا":"مسودة"].every((value,i)=>value.toLowerCase().includes((columnFilters[i]||"").toLowerCase()))).slice().sort((a,b)=>b.createdAt.localeCompare(a.createdAt)),[vouchers,filter,columnFilters]);
 const reset=()=>{setParty("");setDate(today());setAmount("0");setMethod("نقدي");setReference("");setNotes("");};
 const saveDraft=()=>{
  const value=Number(amount);
  if(!party.trim()){setMessage("أدخل اسم العميل أو المورد.");return;}
  if(!Number.isFinite(value)||value<=0){setMessage("أدخل مبلغًا أكبر من صفر.");return;}
  const v:Voucher={id:(kind==="receipt"?"REC-":"PAY-")+Date.now().toString().slice(-9),kind,status:"draft",party:party.trim(),date,amount:value,method,reference:reference.trim(),notes:notes.trim(),createdAt:new Date().toISOString()};
  setVouchers(old=>[v,...old]);setMessage("حُفظ السند كمسودة فقط؛ لم يتغير رصيد الخزينة.");reset();
 };
 const post=(v:Voucher)=>{
  if(v.status!=="draft")return;
  const action=v.kind==="receipt"?"إثبات القبض":"إثبات الصرف";
  if(!window.confirm(action+" بمبلغ "+money(v.amount)+" ج.م؟ سيُسجل كتأثير محلي تجريبي فقط، دون ترحيل محاسبي أو اتصال بالإنتاج."))return;
  try{const journaled=postVoucherJournal({sourceId:v.id,sourceType:v.kind,date:v.date,party:v.party,amount:v.amount,method:v.method,reference:v.reference});if(!journaled)throw new Error("يوجد قيد سابق لهذا السند؛ لم يتم تكرار الاعتماد.");}catch(error){setMessage(error instanceof Error?error.message:"تعذر إنشاء القيد المحاسبي.");return;}
  setVouchers(old=>old.map(x=>x.id===v.id&&x.status==="draft"?{...x,status:"posted",postedAt:new Date().toISOString()}:x));
  setMessage("تم اعتماد السند وإنشاء قيد محاسبي مزدوج داخل دفتر القيود المحلي. لم يتغير أي رصيد إنتاجي.");
 };
 const remove=(id:string)=>{const v=vouchers.find(x=>x.id===id);if(v?.status==="draft"&&window.confirm("حذف المسودة المحلية؟"))setVouchers(old=>old.filter(x=>x.id!==id));};
 return <section className="treasury-workspace" dir="rtl">
  <div className="operation-heading"><div className="operation-title"><span className="operation-icon"><Wallet size={22}/></span><div><small>دورة مالية تجريبية · سجل محلي</small><h2>سندات القبض والصرف</h2><p>إنشاء المسودات ومراجعتها واعتمادها محليًا مع سجل واضح للحركات.</p></div></div><span className="demo-pill">معاينة فقط — لا يؤثر على الإنتاج</span></div>
  <div className="treasury-kpis">
   <div><span>إجمالي سندات القبض المعتمدة محليًا</span><b>{money(receipts)} ج.م</b></div>
   <div><span>إجمالي سندات الصرف المعتمدة محليًا</span><b>{money(payments)} ج.م</b></div>
   <div><span>صافي حركة السجل المحلي</span><b>{money(balance)} ج.م</b><small>ليس رصيد خزينة فعليًا</small></div>
  </div>
  <div className="treasury-editor">
   <div className="treasury-editor-head"><div><b><ReceiptText size={16}/> إنشاء سند جديد</b><small>لا يؤثر الحفظ كمسودة على الإجماليات أعلاه</small></div>
    <div className="treasury-switch"><button className={kind==="receipt"?"selected receipt":"receipt"} onClick={()=>setKind("receipt")}><ArrowDownToLine size={15}/> سند قبض</button><button className={kind==="payment"?"selected payment":"payment"} onClick={()=>setKind("payment")}><ArrowUpFromLine size={15}/> سند صرف</button></div>
   </div>
   <div className="treasury-fields">
    <label><span>{kind==="receipt"?"استلام من (العميل)":"صرف إلى (المورد / المستفيد)"}</span><input value={party} onChange={e=>setParty(e.target.value)} placeholder="اسم الطرف"/></label>
    <label><span>تاريخ السند</span><input type="date" value={date} onChange={e=>setDate(e.target.value)}/></label>
    <label><span>المبلغ (ج.م)</span><input type="number" min="0.01" step="0.01" value={amount} onChange={e=>setAmount(e.target.value)}/></label>
    <label><span>طريقة السداد</span><select value={method} onChange={e=>setMethod(e.target.value)}><option>نقدي</option><option>تحويل بنكي</option><option>شيك</option><option>بطاقة</option></select></label>
    <label><span>مرجع الفاتورة (اختياري)</span><input value={reference} onChange={e=>setReference(e.target.value)} placeholder="رقم فاتورة أو مستند"/></label>
    <label className="treasury-notes"><span>بيان / ملاحظات</span><input value={notes} onChange={e=>setNotes(e.target.value)} placeholder="تفاصيل إضافية للسند"/></label>
   </div>
   <div className="treasury-form-actions"><button className="operation-save" onClick={saveDraft}><Plus size={16}/> حفظ كمسودة</button><span>الاعتماد خطوة منفصلة من سجل السندات.</span></div>
  </div>
  {message&&<div className="operation-feedback">{message}</div>}
  <div className="operation-history treasury-history"><div className="operation-table-head"><div><b><FileText size={15}/> سجل سندات القبض والصرف</b><small>المسودة لا تدخل في إجمالي الحركات؛ الاعتماد المحلي فقط يغير مؤشرات المعاينة.</small></div><select value={filter} onChange={e=>setFilter(e.target.value as typeof filter)}><option value="all">كل السندات</option><option value="draft">المسودات فقط</option><option value="posted">المعتمدة محليًا</option></select></div>
   {visible.length?<div className="table-wrap"><table><thead><tr className="column-filter-row">{["رقم السند","النوع","الطرف","التاريخ","المبلغ","الطريقة","الحالة"].map((p,i)=><th key={p}><input placeholder={"بحث "+p} value={columnFilters[i]} onChange={e=>setColumnFilters(v=>v.map((x,j)=>j===i?e.target.value:x))}/></th>)}<th><span className="filter-disabled">—</span></th></tr><tr><th>رقم السند</th><th>النوع</th><th>الطرف</th><th>التاريخ</th><th>المبلغ</th><th>الطريقة</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>{visible.map(v=><tr key={v.id}><td><b>{v.id}</b></td><td>{v.kind==="receipt"?"قبض":"صرف"}</td><td>{v.party}<small className="treasury-ref">{v.reference||"—"}</small></td><td>{v.date}</td><td className="operation-amount">{money(v.amount)} ج.م</td><td>{v.method}</td><td><span className={v.status==="posted"?"treasury-status posted":"treasury-status draft"}>{v.status==="posted"?"معتمد محليًا":"مسودة"}</span></td><td>{v.status==="draft"?<div className="treasury-row-actions"><button className="operation-add" onClick={()=>post(v)}><CheckCircle2 size={14}/> اعتماد</button><button className="remove-line" onClick={()=>remove(v.id)} title="حذف المسودة"><Trash2 size={14}/></button></div>:<span className="treasury-lock">مغلق</span>}</td></tr>)}</tbody></table></div>:<div className="operation-empty">لا توجد سندات في هذا العرض.</div>}
  </div>
  <div className="operation-disclaimer">حدود هذه المرحلة: جميع السندات محفوظة في هذا المتصفح فقط. الاعتماد يغيّر حالة السند ومؤشرات السجل المحلي، لكنه لا يرحّل قيدًا إلى دفتر الأستاذ، ولا يربط فاتورة أو حساب عميل/مورد، ولا يغيّر خزينة أو بنكًا فعليًا. لا يوجد اتصال بقاعدة بيانات الإنتاج.</div>
 </section>;
}
