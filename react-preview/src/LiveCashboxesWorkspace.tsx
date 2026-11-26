import {useEffect,useMemo,useState} from "react";
import {CreditCard,Plus,RefreshCw,Search,Pencil,Save,Power,X,Landmark,Wallet,ShieldCheck} from "lucide-react";
import {supabase} from "./supabase";
import EditDrawer from "./EditDrawer";
type Cashbox={id:string;company_id:string;branch_id:string;account_id:string;cashbox_code:string;cashbox_name:string;is_bank_account:boolean;bank_name:string|null;account_number_masked:string|null;checkbook_sheet_count:number;is_active:boolean;branch_name?:string;account_label?:string;voucher_count?:number;draft_count?:number};
type Branch={id:string;branch_name:string;branch_code:string;is_active:boolean};
type Account={id:string;account_code:string;account_name:string;account_type:string;is_active:boolean};
const roles=["owner","admin","manager","operator","accountant"];
export default function LiveCashboxesWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"",role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId),canEdit=roles.includes(role);
 const [rows,setRows]=useState<Cashbox[]>([]),[branches,setBranches]=useState<Branch[]>([]),[accounts,setAccounts]=useState<Account[]>([]);
 const [query,setQuery]=useState(""),[status,setStatus]=useState("active"),[loading,setLoading]=useState(live),[saving,setSaving]=useState(false);
 const [notice,setNotice]=useState(""),[error,setError]=useState(""),[editing,setEditing]=useState<Cashbox|null>(null),[showForm,setShowForm]=useState(false);
 const [name,setName]=useState(""),[branchId,setBranchId]=useState(""),[accountId,setAccountId]=useState(""),[isBank,setIsBank]=useState(false),[bankName,setBankName]=useState(""),[maskedNumber,setMaskedNumber]=useState(""),[sheets,setSheets]=useState("25");
 const [formOriginal,setFormOriginal]=useState({name:"",branchId:"",accountId:"",isBank:false,bankName:"",maskedNumber:"",sheets:"25"});
 const snapshot=()=>({name,branchId,accountId,isBank,bankName,maskedNumber,sheets});
 const load=async()=>{
  if(!live||!supabase){setRows([]);setLoading(false);setError("سجّل الدخول إلى المنشأة لعرض خزائنها الفعلية.");return;}
  setLoading(true);setError("");
  const [cb,br,ac]=await Promise.all([
   supabase.from("erp_cashboxes").select("id,company_id,branch_id,account_id,cashbox_code,cashbox_name,is_bank_account,bank_name,account_number_masked,checkbook_sheet_count,is_active").eq("company_id",companyId).order("cashbox_code"),
   supabase.from("erp_branches").select("id,branch_name,branch_code,is_active").eq("company_id",companyId).order("branch_name"),
   supabase.from("erp_accounts").select("id,account_code,account_name,account_type,is_active").eq("company_id",companyId).eq("is_postable",true).eq("account_type","asset").order("account_code")
  ]);
  const err=cb.error||br.error||ac.error;
  if(err){setError("تعذر تحميل الخزائن أو الفروع أو الحسابات: "+err.message);setLoading(false);return;}
  const ids=(cb.data||[]).map((x:any)=>x.id);
  const [src,dst]=ids.length?await Promise.all([
   supabase.from("erp_cash_vouchers").select("id,source_cashbox_id,destination_cashbox_id,status").eq("company_id",companyId).in("source_cashbox_id",ids),
   supabase.from("erp_cash_vouchers").select("id,source_cashbox_id,destination_cashbox_id,status").eq("company_id",companyId).in("destination_cashbox_id",ids)
  ]):[{data:[],error:null},{data:[],error:null}];
  const voucherError=src.error||dst.error;
  if(voucherError){setError("تعذر قراءة ارتباطات السندات: "+voucherError.message);setLoading(false);return;}
  const voucherRows=[...new Map([...(src.data||[]),...(dst.data||[])].map((v:any)=>[v.id,v])).values()];
  const branchMap=new Map((br.data||[]).map((b:any)=>[b.id,b.branch_name]));
  const accountMap=new Map((ac.data||[]).map((a:any)=>[a.id,a.account_code+" — "+a.account_name]));
  setRows((cb.data||[]).map((x:any)=>({...x,branch_name:branchMap.get(x.branch_id)||"فرع غير متاح",account_label:accountMap.get(x.account_id)||"حساب مرتبط",voucher_count:voucherRows.filter((v:any)=>v.source_cashbox_id===x.id||v.destination_cashbox_id===x.id).length,draft_count:voucherRows.filter((v:any)=>(v.source_cashbox_id===x.id||v.destination_cashbox_id===x.id)&&v.status==="draft").length})));
  setBranches((br.data||[]) as Branch[]);setAccounts((ac.data||[]) as Account[]);setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);
 const visible=useMemo(()=>rows.filter(r=>(status==="all"||(status==="active"?r.is_active:!r.is_active))&&[r.cashbox_code,r.cashbox_name,r.branch_name||"",r.account_label||"",r.bank_name||""].join(" ").toLowerCase().includes(query.toLowerCase())),[rows,status,query]);
 const active=rows.filter(r=>r.is_active);
 const reset=()=>{setEditing(null);setShowForm(false);setName("");setBranchId(branches.find(b=>b.is_active)?.id||"");setAccountId("");setIsBank(false);setBankName("");setMaskedNumber("");setSheets("25");};
 const beginNew=()=>{const nextBranch=branches.find(b=>b.is_active)?.id||"";setEditing(null);setName("");setBranchId(nextBranch);setAccountId("");setIsBank(false);setBankName("");setMaskedNumber("");setSheets("25");setFormOriginal({name:"",branchId:nextBranch,accountId:"",isBank:false,bankName:"",maskedNumber:"",sheets:"25"});setShowForm(true);setNotice("");};
 const beginEdit=(r:Cashbox)=>{const next={name:r.cashbox_name,branchId:r.branch_id,accountId:r.account_id,isBank:r.is_bank_account,bankName:r.bank_name||"",maskedNumber:r.account_number_masked||"",sheets:String(r.checkbook_sheet_count||25)};setEditing(r);setName(next.name);setBranchId(next.branchId);setAccountId(next.accountId);setIsBank(next.isBank);setBankName(next.bankName);setMaskedNumber(next.maskedNumber);setSheets(next.sheets);setFormOriginal({...next});setShowForm(true);setNotice("");};
 const save=async():Promise<boolean>=>{
  if(!live||!supabase||!canEdit)return false;
  if(!name.trim()||!branchId||!accountId){setNotice("اسم الخزينة والفرع وحساب الأستاذ مطلوبة.");return false;}
  if(isBank&&!bankName.trim()){setNotice("اسم البنك مطلوب عند اختيار حساب بنكي.");return false;}
  const sheetCount=Number(sheets);if(!Number.isInteger(sheetCount)||sheetCount<1||sheetCount>1000){setNotice("عدد أوراق دفتر الشيكات يجب أن يكون بين 1 و1000.");return false;}
  if(editing&&(editing.voucher_count||0)>0&&(editing.branch_id!==branchId||editing.account_id!==accountId)){setNotice("لا يمكن تغيير الفرع أو حساب الأستاذ بعد ارتباط الخزينة بسندات؛ حافظ على التاريخ المحاسبي.");return false;}
  setSaving(true);setNotice("");
  const payload={cashbox_name:name.trim(),branch_id:branchId,account_id:accountId,is_bank_account:isBank,bank_name:isBank?bankName.trim():null,account_number_masked:isBank?(maskedNumber.trim()||null):null,checkbook_sheet_count:sheetCount};
  const result=editing?await supabase.from("erp_cashboxes").update(payload).eq("id",editing.id).eq("company_id",companyId).select("id").maybeSingle():await supabase.from("erp_cashboxes").insert({company_id:companyId,...payload}).select("id,cashbox_code").single();
  setSaving(false);if(result.error){setNotice("لم يتم حفظ الخزينة: "+result.error.message);return false;}
  setNotice(editing?"تم تحديث بيانات الخزينة.":"تم إنشاء الخزينة بكود مركزي "+(result.data as any)?.cashbox_code+".");reset();await load();return true;
 };
 const toggle=async(r:Cashbox)=>{
  if(!live||!supabase||!canEdit)return;
  if(r.is_active&&(r.draft_count||0)>0){setNotice("لا يمكن إيقاف الخزينة وبها سندات مسودة؛ رحّلها أو ألغها أولًا.");return;}
  if(!window.confirm((r.is_active?"إيقاف":"إعادة تفعيل")+" الخزينة "+r.cashbox_code+" — "+r.cashbox_name+"؟ لن تُحذف أي حركات أو سندات."))return;
  const {error}=await supabase.from("erp_cashboxes").update({is_active:!r.is_active}).eq("id",r.id).eq("company_id",companyId);
  if(error){setNotice("تعذر تغيير حالة الخزينة: "+error.message);return;}setNotice(r.is_active?"تم إيقاف الخزينة دون حذف تاريخها.":"تمت إعادة تفعيل الخزينة.");await load();
 };
 const availableAccounts=accounts.filter(a=>a.is_active&&!rows.some(r=>r.is_active&&r.account_id===a.id&&r.id!==editing?.id));
 const linkedAccounts=editing?accounts.filter(a=>a.id===editing.account_id):[];
 const availableBranches=branches.filter(b=>b.is_active||b.id===editing?.branch_id);
 return <section className="cashboxes-workspace" dir="rtl">
  <div className="cashboxes-head"><span><CreditCard size={23}/></span><div><small>الإدارة المالية · الخزائن والحسابات البنكية</small><h2>إدارة الخزائن والبنوك</h2><p>إدارة الخزائن المرتبطة بالفروع وحسابات الأستاذ الفعلية.</p></div><b>{live?"اتصال مباشر":"وضع المعاينة"}</b></div>
  <div className="cashboxes-kpis"><div><span>إجمالي الخزائن</span><strong>{rows.length}</strong></div><div><span>الخزائن النشطة</span><strong>{active.length}</strong></div><div><span>الحسابات البنكية</span><strong>{active.filter(r=>r.is_bank_account).length}</strong></div><div><span>السندات المرتبطة</span><strong>{rows.reduce((s,r)=>s+(r.voucher_count||0),0)}</strong></div></div>
  <div className="cashboxes-panel"><div className="cashboxes-toolbar"><div><b>سجل الخزائن الفعلي</b><small>الكود يُولّد مركزيًا عند الحفظ، ولا يُنشأ أي حساب أستاذ تلقائيًا.</small></div><div><button className="cashboxes-primary" onClick={beginNew} disabled={!live||!canEdit}><Plus size={15}/> إضافة خزينة</button><button onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button></div></div>
   {showForm&&<EditDrawer title={editing?"تعديل بيانات الخزينة":"إضافة خزينة جديدة"} dirty={JSON.stringify(snapshot())!==JSON.stringify(formOriginal)} saving={saving} onSaveError={()=>setSaving(false)} error={notice.startsWith("لم يتم")||notice.startsWith("لا يمكن")||notice.startsWith("اسم ")||notice.startsWith("عدد ")||notice.startsWith("لا تملك")?notice:""} onSave={save} onDiscard={()=>{setName(formOriginal.name);setBranchId(formOriginal.branchId);setAccountId(formOriginal.accountId);setIsBank(formOriginal.isBank);setBankName(formOriginal.bankName);setMaskedNumber(formOriginal.maskedNumber);setSheets(formOriginal.sheets);setNotice("");}} onClose={()=>setShowForm(false)}><div className="cashboxes-form"><h3>{editing?"تعديل بيانات الخزينة":"إضافة خزينة جديدة"}</h3><div className="cashboxes-fields">
    <label>اسم الخزينة *<input value={name} onChange={e=>setName(e.target.value)} placeholder="اسم الخزينة"/></label>
    <label>الفرع *<select value={branchId} disabled={!!editing&&(editing.voucher_count||0)>0} onChange={e=>setBranchId(e.target.value)}><option value="">اختر الفرع</option>{availableBranches.map(b=><option key={b.id} value={b.id}>{b.branch_code} — {b.branch_name}</option>)}</select></label>
    <label>حساب الأستاذ *<select value={accountId} disabled={!!editing&&(editing.voucher_count||0)>0} onChange={e=>setAccountId(e.target.value)}><option value="">اختر حسابًا من الأصول</option>{[...linkedAccounts,...availableAccounts].filter((a,i,x)=>x.findIndex(v=>v.id===a.id)===i).map(a=><option key={a.id} value={a.id}>{a.account_code} — {a.account_name}</option>)}</select></label>
    <label>نوع الحساب<select value={isBank?"bank":"cash"} onChange={e=>setIsBank(e.target.value==="bank")}><option value="cash">خزينة نقدية</option><option value="bank">حساب بنكي</option></select></label>
    {isBank&&<><label>اسم البنك *<input value={bankName} onChange={e=>setBankName(e.target.value)} placeholder="اسم البنك"/></label><label>رقم الحساب (آخر أرقام فقط)<input value={maskedNumber} onChange={e=>setMaskedNumber(e.target.value)} placeholder="•••• 1234"/></label></>}
    <label>عدد أوراق دفتر الشيكات<input type="number" min="1" max="1000" value={sheets} onChange={e=>setSheets(e.target.value)}/></label>
   </div><div className="cashboxes-form-actions"><button className="cashboxes-primary" onClick={()=>window.dispatchEvent(new Event("silsila:edit-save"))} disabled={saving}><Save size={14}/>{saving?"جارٍ الحفظ":"حفظ الخزينة"}</button><button onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))}><X size={14}/> إلغاء</button></div><small>سياسة التكويد المركزية تولّد بادئة Csh وتسلسل الخزينة تلقائيًا؛ لا يتم تعديل الكود يدويًا.</small></div></EditDrawer>}
   <div className="cashboxes-filters"><label><Search size={15}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث بالكود أو الاسم أو الفرع أو البنك"/></label><select value={status} onChange={e=>setStatus(e.target.value)}><option value="active">النشطة</option><option value="inactive">الموقوفة</option><option value="all">الكل</option></select></div>
   {error&&<div className="cashboxes-message">{error}</div>}
   <div className="cashboxes-table-wrap"><table><thead><tr><th>كود الخزينة</th><th>اسم الخزينة</th><th>الفرع</th><th>حساب الأستاذ</th><th>النوع</th><th>البنك / الحساب</th><th>السندات</th><th>الحالة</th><th>الإجراء</th></tr></thead><tbody>{visible.map(r=><tr key={r.id}><td className="cashboxes-code">{r.cashbox_code}</td><td><b>{r.cashbox_name}</b></td><td>{r.branch_name}</td><td>{r.account_label}</td><td>{r.is_bank_account?<span className="cashboxes-bank"><Landmark size={13}/> بنك</span>:<span className="cashboxes-cash"><Wallet size={13}/> نقدية</span>}</td><td>{r.is_bank_account?[r.bank_name,r.account_number_masked].filter(Boolean).join(" · ")||"—":"—"}</td><td>{r.voucher_count||0}{r.draft_count?" ("+r.draft_count+" مسودة)":""}</td><td>{r.is_active?<span className="cashboxes-active"><ShieldCheck size={13}/> نشطة</span>:<span className="cashboxes-inactive">موقوفة</span>}</td><td><div className="cashboxes-row-actions"><button onClick={()=>beginEdit(r)} disabled={!canEdit}><Pencil size={13}/> تعديل</button><button onClick={()=>void toggle(r)} disabled={!canEdit}><Power size={13}/>{r.is_active?"إيقاف":"تفعيل"}</button></div></td></tr>)}{!visible.length&&<tr><td colSpan={9} className="cashboxes-empty">{loading?"جارٍ تحميل الخزائن...":error?"تعذر تحميل السجلات":"لا توجد خزائن مطابقة."}</td></tr>}</tbody></table></div>
  </div>
  {notice&&<div className="cashboxes-message" role="status">{notice}</div>}
  <div className="cashboxes-note"><ShieldCheck size={15}/> لا نحذف خزينة مرتبطة بسندات، ولا نسمح بتغيير فرعها أو حسابها بعد وجود حركات. جميع القيود محكومة بصلاحيات قاعدة سلسلة.</div>
 </section>;
}
