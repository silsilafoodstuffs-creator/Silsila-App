import { useEffect, useMemo, useState } from "react";
import { supabase } from "./supabase";
import { ArrowDownToLine, ArrowUpFromLine, CheckCircle2, FileText, Plus, RefreshCw, ReceiptText, Wallet } from "lucide-react";

type VoucherKind = "receipt" | "payment";
type VoucherStatus = "draft" | "posted" | "cancelled";
type Voucher = { id:string; voucher_number:string; voucher_date:string; voucher_type:VoucherKind; amount:number; description:string; status:VoucherStatus; journal_entry_id:string|null; source_cashbox_id:string; counter_account_id:string|null; party_id:string|null; branch_id:string|null; created_at:string };
type Cashbox = { id:string; cashbox_name:string; branch_id:string; account_id:string; branchName:string; is_bank_account:boolean };
type Account = { id:string; account_code:string; account_name:string; account_type:string };
type Party = { id:string; party_name:string; party_kind:string };
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-");};
const COMPANY=sessionStorage.getItem("silsila-company-id")||"";
const USER=sessionStorage.getItem("silsila-user-id")||"";
const ROLE=sessionStorage.getItem("silsila-member-role")||"viewer";

export default function TreasuryWorkspace(){
 const companyId=COMPANY,userId=USER,role=ROLE;
 const live=Boolean(supabase&&companyId&&userId);
 const canCreate=["owner","admin","manager","operator","accountant"].includes(role);
 const [vouchers,setVouchers]=useState<Voucher[]>([]);
 const [cashboxes,setCashboxes]=useState<Cashbox[]>([]);
 const [accounts,setAccounts]=useState<Account[]>([]);
 const [parties,setParties]=useState<Party[]>([]);
 const [kind,setKind]=useState<VoucherKind>("receipt");
 const [partyId,setPartyId]=useState("");
 const [cashboxId,setCashboxId]=useState("");
 const [counterAccountId,setCounterAccountId]=useState("");
 const [date,setDate]=useState(today());
 const [amount,setAmount]=useState("0");
 const [reference,setReference]=useState("");
 const [notes,setNotes]=useState("");
 const [message,setMessage]=useState("");
 const [loading,setLoading]=useState(live);
 const [saving,setSaving]=useState(false);
 const [filter,setFilter]=useState<"all"|"draft"|"posted">("all");
 const [columnFilters,setColumnFilters]=useState<string[]>(Array(7).fill(""));
 const accountCode=kind==="receipt"?"11201":"21101";
 const counterAccounts=accounts.filter(a=>a.account_type===(kind==="receipt"?"asset":"liability"));
 const selectedCounter=accounts.find(a=>a.id===counterAccountId);
 const selectedCashbox=cashboxes.find(c=>c.id===cashboxId);
 const load=async()=>{
  if(!live||!supabase){setLoading(false);return;}
  setLoading(true);setMessage("");
  const [cb,br,ac,pa,vo]=await Promise.all([
   supabase.from("erp_cashboxes").select("id,cashbox_name,branch_id,account_id,is_bank_account").eq("company_id",companyId).eq("is_active",true).not("branch_id","is",null).order("cashbox_code"),
   supabase.from("erp_branches").select("id,branch_name").eq("company_id",companyId).eq("is_active",true),
   supabase.from("erp_accounts").select("id,account_code,account_name,account_type").eq("company_id",companyId).eq("is_active",true).eq("is_postable",true).order("account_code"),
   supabase.from("erp_parties").select("id,party_name,party_kind").eq("company_id",companyId).eq("is_active",true).order("party_name"),
   supabase.from("erp_cash_vouchers").select("*").eq("company_id",companyId).order("created_at",{ascending:false}).limit(100)
  ]);
  const err=[cb.error,br.error,ac.error,pa.error,vo.error].find(Boolean);
  if(err){setMessage("تعذر تحميل بيانات الخزينة: "+err.message);setLoading(false);return;}
  const branchMap=new Map((br.data||[]).map((b:any)=>[b.id,b.branch_name]));
  const cash=(cb.data||[]).map((c:any)=>({...c,branchName:branchMap.get(c.branch_id)||"فرع غير محدد"}));
  setCashboxes(cash);setAccounts((ac.data||[]) as Account[]);setParties((pa.data||[]) as Party[]);setVouchers((vo.data||[]) as Voucher[]);
  setCashboxId(old=>cash.some((c:any)=>c.id===old)?old:(cash[0]?.id||""));
  const target=(ac.data||[]).find((a:any)=>a.account_code===accountCode);
  setCounterAccountId(old=>(ac.data||[]).some((a:any)=>a.id===old)?old:(target?.id||""));
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);
 useEffect(()=>{const target=accounts.find(a=>a.account_code===accountCode);if(target)setCounterAccountId(target.id);},[kind,accounts]);
 const posted=vouchers.filter(v=>v.status==="posted");
 const receipts=posted.filter(v=>v.voucher_type==="receipt").reduce((s,v)=>s+Number(v.amount),0);
 const payments=posted.filter(v=>v.voucher_type==="payment").reduce((s,v)=>s+Number(v.amount),0);
 const visible=useMemo(()=>vouchers.filter(v=>(filter==="all"||v.status===filter)&&[v.voucher_number,v.voucher_type==="receipt"?"قبض":"صرف",parties.find(p=>p.id===v.party_id)?.party_name||v.description,v.voucher_date,money(Number(v.amount)),cashboxes.find(c=>c.id===v.source_cashbox_id)?.cashbox_name||"",v.status==="posted"?"مرحل":"مسودة"].every((value,i)=>value.toLowerCase().includes((columnFilters[i]||"").toLowerCase()))),[vouchers,filter,columnFilters,parties,cashboxes]);
 const reset=()=>{setPartyId("");setDate(today());setAmount("0");setReference("");setNotes("");};
 const saveDraft=async()=>{
  const value=Number(amount);
  if(!live||!supabase){setMessage("سندات الخزينة تتطلب تسجيل الدخول إلى قاعدة سلسلة؛ وضع المعاينة لا ينشئ سندات إنتاجية.");return;}
  if(!canCreate){setMessage("صلاحيات حسابك لا تسمح بإنشاء سند خزينة.");return;}
  if(!cashboxId||!selectedCashbox){setMessage("اختر خزينة مرتبطة بفرع متاح.");return;}
  if(!counterAccountId||!selectedCounter){setMessage("لا يوجد حساب مقابل صالح لهذا النوع من السند.");return;}
  if(!Number.isFinite(value)||value<=0){setMessage("أدخل مبلغًا أكبر من صفر.");return;}
  if(!date||date>today()){setMessage("تاريخ السند مطلوب ولا يجوز أن يكون في المستقبل.");return;}
  setSaving(true);setMessage("");
  const partyName=parties.find(p=>p.id===partyId)?.party_name;
  const description=[kind==="receipt"?"سند قبض":"سند صرف",partyName,reference.trim()?"مرجع "+reference.trim():"",notes.trim()].filter(Boolean).join(" — ");
  const voucherNumber=(kind==="receipt"?"REC-":"PAY-")+Date.now().toString();
  const {data,error}=await supabase.from("erp_cash_vouchers").insert({
   company_id:companyId,branch_id:selectedCashbox.branch_id,voucher_number:voucherNumber,voucher_date:date,
   voucher_type:kind,source_cashbox_id:cashboxId,counter_account_id:counterAccountId,party_id:partyId||null,
   amount:value,description,status:"draft",created_by:userId
  }).select("*").single();
  if(error){setMessage("لم يتم حفظ المسودة: "+error.message);setSaving(false);return;}
  setVouchers(old=>[data as Voucher,...old]);setMessage("تم حفظ سند حقيقي كمسودة في قاعدة سلسلة. لم تتغير أرصدة الخزينة أو دفتر الأستاذ بعد.");
  reset();setSaving(false);
 };
 const post=async(v:Voucher)=>{
  if(!live||!supabase)return;
  if(v.status!=="draft")return;
  if(!window.confirm("ترحيل السند "+v.voucher_number+" بمبلغ "+money(Number(v.amount))+" ج.م؟ سينشأ قيد يومية متوازن ويُغلق السند في قاعدة سلسلة."))return;
  setSaving(true);setMessage("");
  const {data,error}=await supabase.rpc("erp_post_cash_voucher",{p_voucher_id:v.id});
  if(error){setMessage("تعذر ترحيل السند؛ لم نغيّر حالته: "+error.message);setSaving(false);return;}
  await load();setMessage("تم ترحيل السند فعليًا وإنشاء قيد اليومية رقم "+String(data||"—")+" من خلال إجراء قاعدة البيانات الذري.");setSaving(false);
 };
 return <section className="treasury-workspace" dir="rtl">
  <div className="operation-heading"><div className="operation-title"><span className="operation-icon"><Wallet size={22}/></span><div><small>{live?"اتصال مباشر بقاعدة سلسلة":"وضع المعاينة"}</small><h2>سندات القبض والصرف</h2><p>مسودات خزينة حقيقية وترحيل محاسبي من خلال إجراءات قاعدة البيانات المعتمدة.</p></div></div><span className="demo-pill">{live?"متصل بقاعدة المنشأة":"غير متصل — معاينة فقط"}</span></div>
  <div className="treasury-kpis">
   <div><span>إجمالي سندات القبض المرحلة</span><b>{money(receipts)} ج.م</b></div>
   <div><span>إجمالي سندات الصرف المرحلة</span><b>{money(payments)} ج.م</b></div>
   <div><span>صافي السندات المرحلة</span><b>{money(receipts-payments)} ج.م</b><small>صافي حركة السندات فقط، وليس رصيد الخزينة الافتتاحي</small></div>
  </div>
  <div className="treasury-editor">
   <div className="treasury-editor-head"><div><b><ReceiptText size={16}/> إنشاء سند جديد</b><small>الحفظ ينشئ مسودة؛ الترحيل منفصل ويولّد قيدًا متوازنًا</small></div>
    <div className="treasury-switch"><button className={kind==="receipt"?"selected receipt":"receipt"} onClick={()=>setKind("receipt")}><ArrowDownToLine size={15}/> سند قبض</button><button className={kind==="payment"?"selected payment":"payment"} onClick={()=>setKind("payment")}><ArrowUpFromLine size={15}/> سند صرف</button></div>
   </div>
   <div className="treasury-fields">
    <label><span>{kind==="receipt"?"العميل (اختياري)":"المورد / المستفيد (اختياري)"}</span><select value={partyId} onChange={e=>setPartyId(e.target.value)}><option value="">بدون ربط بطرف</option>{parties.filter(p=>p.party_kind===(kind==="receipt"?"customer":"supplier")||p.party_kind==="both").map(p=><option key={p.id} value={p.id}>{p.party_name}</option>)}</select></label>
    <label><span>الخزينة / البنك</span><select value={cashboxId} onChange={e=>setCashboxId(e.target.value)}>{cashboxes.map(c=><option key={c.id} value={c.id}>{c.cashbox_name} — {c.branchName}</option>)}</select></label>
    <label><span>الحساب المقابل</span><select value={counterAccountId} onChange={e=>setCounterAccountId(e.target.value)}>{counterAccounts.map(a=><option key={a.id} value={a.id}>{a.account_code} — {a.account_name}</option>)}</select></label>
    <label><span>تاريخ السند</span><input type="date" value={date} max={today()} onChange={e=>setDate(e.target.value)}/></label>
    <label><span>المبلغ (ج.م)</span><input type="number" min="0.01" step="0.01" value={amount} onChange={e=>setAmount(e.target.value)}/></label>
    <label><span>مرجع الفاتورة (اختياري)</span><input value={reference} onChange={e=>setReference(e.target.value)} placeholder="رقم فاتورة أو مستند"/></label>
    <label className="treasury-notes"><span>بيان / ملاحظات</span><input value={notes} onChange={e=>setNotes(e.target.value)} placeholder="تفاصيل إضافية للسند"/></label>
   </div>
   <div className="treasury-form-actions"><button className="operation-save" onClick={saveDraft} disabled={saving||loading||!canCreate}><Plus size={16}/> {saving?"جارٍ الحفظ...":"حفظ كمسودة"}</button><span>الترحيل ينشئ قيد اليومية ويربطه بالسند داخل معاملة قاعدة البيانات.</span></div>
  </div>
  {message&&<div className="operation-feedback">{message}</div>}
  {loading&&<div className="operation-feedback">جارٍ تحميل بيانات الخزائن والحسابات والسندات...</div>}
  {!loading&&live&&cashboxes.length===0&&<div className="operation-feedback warning">لا توجد خزائن فرعية متاحة في نطاق صلاحيتك؛ يلزم إعداد خزينة مرتبطة بفرع قبل إنشاء السندات.</div>}
  {!live&&<div className="operation-feedback warning">سجّل الدخول بحساب منشأة لاستخدام الخزينة الفعلية. لا تُنشأ أي بيانات إنتاجية في وضع المعاينة.</div>}
  <div className="operation-history treasury-history"><div className="operation-table-head"><div><b><FileText size={15}/> سجل سندات القبض والصرف</b><small>الحالات والمبالغ تُقرأ مباشرة من قاعدة سلسلة.</small></div><div className="treasury-row-actions"><select value={filter} onChange={e=>setFilter(e.target.value as typeof filter)}><option value="all">كل السندات</option><option value="draft">المسودات فقط</option><option value="posted">المرحلة فقط</option></select><button className="operation-add" onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button></div></div>
   {visible.length?<div className="table-wrap"><table><thead><tr className="column-filter-row">{["رقم السند","النوع","الطرف / البيان","التاريخ","المبلغ","الخزينة","الحالة"].map((p,i)=><th key={p}><input placeholder={"بحث "+p} value={columnFilters[i]} onChange={e=>setColumnFilters(v=>v.map((x,j)=>j===i?e.target.value:x))}/></th>)}<th><span className="filter-disabled">—</span></th></tr><tr><th>رقم السند</th><th>النوع</th><th>الطرف / البيان</th><th>التاريخ</th><th>المبلغ</th><th>الخزينة</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>{visible.map(v=><tr key={v.id}><td><b>{v.voucher_number}</b></td><td>{v.voucher_type==="receipt"?"قبض":"صرف"}</td><td>{parties.find(p=>p.id===v.party_id)?.party_name||v.description}</td><td>{v.voucher_date}</td><td className="operation-amount">{money(Number(v.amount))} ج.م</td><td>{cashboxes.find(c=>c.id===v.source_cashbox_id)?.cashbox_name||"—"}</td><td><span className={v.status==="posted"?"treasury-status posted":"treasury-status draft"}>{v.status==="posted"?"مرحل فعليًا":v.status==="cancelled"?"ملغى":"مسودة"}</span></td><td>{v.status==="draft"&&["owner","admin","accountant"].includes(role)?<button className="operation-add" onClick={()=>void post(v)} disabled={saving}><CheckCircle2 size={14}/> ترحيل وقيد</button>:v.journal_entry_id?<small className="treasury-ref">قيد: {v.journal_entry_id.slice(0,8)}</small>:<span className="treasury-lock">—</span>}</td></tr>)}</tbody></table></div>:<div className="operation-empty">{loading?"جارٍ التحميل...":"لا توجد سندات في هذا العرض."}</div>}
  </div>
  <div className="operation-disclaimer">{live?"هذه الشاشة متصلة بقاعدة سلسلة. ترحيل السند يتم عبر erp_post_cash_voucher الذي ينشئ قيدًا متوازنًا ويربطه بالسند ذريًا.":"لا يوجد اتصال إنتاجي؛ البيانات غير متاحة في وضع المعاينة."} لا يُعرض صافي السندات على أنه رصيد خزينة شامل قبل إدخال الأرصدة الافتتاحية والتسويات.</div>
 </section>;
}
