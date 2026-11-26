import { useEffect,useMemo,useState } from "react";
import { Download,RefreshCw,BookOpen,Scale,Plus,Save,Send,Trash2,X,FileText } from "lucide-react";
import { supabase } from "./supabase";
import EditDrawer from "./EditDrawer";

type Line={account:string;debit:number;credit:number;party:string;description:string;entry:string;date:string;source:string;id:string};
type Entry={id:string;number:string;date:string;description:string;source:string;status:"draft"|"posted"|"reversed";lines:Line[]};
type Account={id:string;account_code:string;account_name:string};
type LedgerBalance={account_id:string;account_code:string;account_name:string;account_type:string;is_postable:boolean;own_debit_total:number;own_credit_total:number;own_net_balance:number};
type Party={id:string;party_name:string};
type DraftLine={accountId:string;debit:string;credit:string;partyId:string;description:string};
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-");};
const roles=["owner","admin","accountant"];
const emptyLine=():DraftLine=>({accountId:"",debit:"",credit:"",partyId:"",description:""});
export default function JournalWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId);
 const canManage=roles.includes(role);
 const [entries,setEntries]=useState<Entry[]>([]);
 const [accounts,setAccounts]=useState<Account[]>([]);
 const [ledgerBalances,setLedgerBalances]=useState<LedgerBalance[]>([]);
 const [parties,setParties]=useState<Party[]>([]);
 const [query,setQuery]=useState(""); const [columnFilters,setColumnFilters]=useState<Record<string,string>>({});
 const [statusFilter,setStatusFilter]=useState<"all"|"posted"|"draft">("all");
 const [loading,setLoading]=useState(live);
 const [saving,setSaving]=useState(false);
 const [postingId,setPostingId]=useState("");
 const [message,setMessage]=useState("");
 const [error,setError]=useState("");
 const [editorOpen,setEditorOpen]=useState(false);
 const [editingId,setEditingId]=useState<string|null>(null);
 const [draftDescription,setDraftDescription]=useState("");
 const [draftDate,setDraftDate]=useState(today());
 const [draftLines,setDraftLines]=useState<DraftLine[]>([emptyLine(),emptyLine()]);
 const [editorOriginal,setEditorOriginal]=useState({description:"",date:today(),lines:[emptyLine(),emptyLine()]});

 const load=async()=>{
  if(!live||!supabase){setEntries([]);setAccounts([]);setLedgerBalances([]);setParties([]);setLoading(false);setError("سجّل الدخول إلى المنشأة لعرض دفتر القيود الفعلي.");return;}
  setLoading(true);setError("");
  const [je,ac,pa,lb]=await Promise.all([
   supabase.from("erp_journal_entries").select("id,entry_number,entry_number_display,entry_date,description,source_type,status").eq("company_id",companyId).in("status",["draft","posted"]).order("entry_date",{ascending:false}).limit(500),
   supabase.from("erp_accounts").select("id,account_code,account_name").eq("company_id",companyId).eq("is_active",true).eq("is_postable",true).order("account_code"),
   supabase.from("erp_parties").select("id,party_name").eq("company_id",companyId).eq("is_active",true).order("party_name").limit(1000),
   supabase.from("erp_account_tree_metrics").select("account_id,account_code,account_name,account_type,is_postable,own_debit_total,own_credit_total,own_net_balance").eq("company_id",companyId).eq("is_postable",true).order("account_code")
  ]);
  const entryIds=(je.data||[]).map((e:any)=>e.id);
  const jl=entryIds.length?await supabase.from("erp_journal_lines").select("id,entry_id,account_id,description,debit,credit,party_id").in("entry_id",entryIds):{data:[],error:null};
  const err=je.error||jl.error||ac.error||pa.error||lb.error;
  if(err){setMessage("");setError("تعذر تحميل دفتر القيود: "+err.message);setEntries([]);setLedgerBalances([]);setLoading(false);return;}
  const accountMap=new Map<string,string>((ac.data||[]).map((a:any)=>[a.id,a.account_code+" — "+a.account_name]));
  const partyMap=new Map<string,string>((pa.data||[]).map((p:any)=>[p.id,p.party_name]));
  const linesByEntry=new Map<string,Line[]>();
  for(const l of jl.data||[]){
   const entry=(je.data||[]).find((e:any)=>e.id===l.entry_id);if(!entry)continue;
   const number=entry.entry_number_display||String(entry.entry_number);
   const line:Line={id:l.id,entry:number,date:entry.entry_date,source:entry.source_type,description:l.description||entry.description,party:l.party_id?partyMap.get(l.party_id)||"": "",account:accountMap.get(l.account_id)||"حساب غير معروف",debit:Number(l.debit),credit:Number(l.credit)};
   const arr=linesByEntry.get(l.entry_id)||[];arr.push(line);linesByEntry.set(l.entry_id,arr);
  }
  setAccounts((ac.data||[]) as Account[]);setLedgerBalances((lb.data||[]) as LedgerBalance[]);setParties((pa.data||[]) as Party[]);
  setEntries((je.data||[]).map((e:any)=>({id:e.id,number:e.entry_number_display||String(e.entry_number),date:e.entry_date,description:e.description,source:e.source_type,status:e.status,lines:(linesByEntry.get(e.id)||[]).map(l=>({...l,entry:e.entry_number_display||String(e.entry_number)}))})));
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);

 const rows=useMemo(()=>entries.filter(e=>statusFilter==="all"||e.status===statusFilter).flatMap(e=>e.lines).filter(r=>[r.entry,r.date,r.party,r.account,r.description,r.source].join(" ").toLowerCase().includes(query.toLowerCase())),[entries,query,statusFilter]);
 const debit=ledgerBalances.reduce((s,a)=>s+Number(a.own_debit_total||0),0),credit=ledgerBalances.reduce((s,a)=>s+Number(a.own_credit_total||0),0);
 const trial=useMemo(()=>ledgerBalances.map(a=>[a.account_code+" — "+a.account_name,{debit:Number(a.own_debit_total)||0,credit:Number(a.own_credit_total)||0}] as [string,{debit:number;credit:number}]),[ledgerBalances]);
 const draftDebit=draftLines.reduce((s,l)=>s+(Number(l.debit)||0),0);
 const draftCredit=draftLines.reduce((s,l)=>s+(Number(l.credit)||0),0);
 const draftBalanced=draftDebit>0&&Math.abs(draftDebit-draftCredit)<0.005;
 const updateLine=(index:number,patch:Partial<DraftLine>)=>setDraftLines(old=>old.map((line,i)=>i===index?{...line,...patch}:line));
 const openNew=()=>{const nextLines=[emptyLine(),emptyLine()];setEditingId(null);setDraftDescription("");setDraftDate(today());setDraftLines(nextLines);setEditorOriginal({description:"",date:today(),lines:nextLines.map(l=>({...l}))});setMessage("");setError("");setEditorOpen(true);};
 const openEdit=(entry:Entry)=>{
  const nextLines=entry.lines.map(l=>({accountId:accounts.find(a=>a.account_code+" — "+a.account_name===l.account)?.id||"",debit:l.debit?String(l.debit):"",credit:l.credit?String(l.credit):"",partyId:parties.find(p=>p.party_name===l.party)?.id||"",description:l.description||""}));
  setEditingId(entry.id);setDraftDescription(entry.description);setDraftDate(entry.date);setDraftLines(nextLines);setEditorOriginal({description:entry.description,date:entry.date,lines:nextLines.map(l=>({...l}))});
  setMessage("");setError("");setEditorOpen(true);
 };
 const closeEditor=()=>{setEditorOpen(false);setEditingId(null);};
 const saveDraft=async():Promise<boolean>=>{
  if(!live||!supabase)return false;
  if(!canManage){setMessage("صلاحيات حسابك لا تسمح بإنشاء أو تعديل قيود اليومية.");return false;}
  if(!draftDescription.trim()||!draftDate){setMessage("بيان القيد وتاريخه مطلوبان.");return false;}
  if(draftLines.length<2){setMessage("يجب أن يحتوي القيد على سطرين على الأقل.");return false;}
  const lines=draftLines.map((l,i)=>({account_id:l.accountId,party_id:l.partyId||null,branch_id:null,debit:Number(l.debit)||0,credit:Number(l.credit)||0,description:l.description.trim()||draftDescription.trim(),row:i+1}));
  const invalid=lines.find(l=>!l.account_id||l.debit<0||l.credit<0||!((l.debit>0&&l.credit===0)||(l.credit>0&&l.debit===0)));
  if(invalid){setMessage("راجع سطور القيد: اختر حسابًا وأدخل قيمة مدين أو دائن فقط في كل سطر.");return false;}
  setSaving(true);setMessage("");setError("");
  const {data,error}=await supabase.rpc("erp_save_journal_draft",{p_company_id:companyId,p_entry_date:draftDate,p_description:draftDescription.trim(),p_lines:lines,p_entry_id:editingId});
  setSaving(false);
  if(error){setMessage("لم يتم حفظ مسودة القيد: "+error.message);return false;}
  setMessage("تم حفظ مسودة القيد في قاعدة سلسلة.");
  closeEditor();await load();return true;
 };
 const post=async(entry:Entry)=>{
  if(!live||!supabase||!canManage)return;
  const d=entry.lines.reduce((s,l)=>s+l.debit,0),c=entry.lines.reduce((s,l)=>s+l.credit,0);
  if(entry.lines.length<2||d<=0||Math.abs(d-c)>=0.005){setMessage("لا يمكن ترحيل القيد قبل اكتمال سطوره وتساوي إجمالي المدين والدائن.");return;}
  if(!window.confirm("ترحيل القيد "+entry.number+" بإجمالي "+money(d)+" ج.م؟ سيتم اعتماد القيد في دفتر الأستاذ."))return;
  setPostingId(entry.id);setMessage("");
  const {error}=await supabase.rpc("erp_post_journal_entry",{p_entry_id:entry.id});
  setPostingId("");
  if(error){setMessage("تعذر ترحيل القيد: "+error.message);return;}
  setMessage("تم ترحيل القيد بنجاح إلى دفتر الأستاذ.");await load();
 };
 const exportCsv=()=>{const data=[["رقم القيد","الحالة","التاريخ","البيان","الطرف","الحساب","مدين","دائن"],...rows.map(r=>[r.entry,entries.find(e=>e.number===r.entry)?.status==="draft"?"مسودة":"مرحل",r.date,r.description,r.party,r.account,r.debit,r.credit])];const csv=data.map(a=>a.map(v=>'"'+String(v).replace(/"/g,'""')+'"').join(",")).join("\n");const url=URL.createObjectURL(new Blob(["\uFEFF",csv],{type:"text/csv;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download="silsila-journal.csv";a.click();URL.revokeObjectURL(url)};

 return <section className="journal-workspace" dir="rtl">
  <div className="journal-hero"><span className="journal-hero-icon"><BookOpen size={22}/></span><div className="journal-hero-copy"><small>{live?"الإدارة المالية · دفتر الأستاذ الفعلي":"الإدارة المالية · غير متصل"}</small><h2>قيود اليومية</h2><p>مسودات القيود وحركات دفتر الأستاذ من قاعدة سلسلة مع فصل الحفظ عن الترحيل.</p></div></div>
  <div className="journal-stats"><div><span>القيود المرحلة</span><b>{entries.filter(e=>e.status==="posted").length}</b></div><div><span>إجمالي المدين المرحل</span><b>{money(debit)} ج.م</b></div><div><span>إجمالي الدائن المرحل</span><b>{money(credit)} ج.م</b></div><div><span>فرق المراجعة</span><b>{money(debit-credit)} ج.م</b><small>{Math.abs(debit-credit)<0.01?"الحركة المرحلة متوازنة":"توجد فروق تحتاج مراجعة"}</small></div></div>
  <div className="journal-list">
   <div className="journal-list-head"><div><h3><BookOpen size={17}/> دفتر القيود</h3><span>{live?"المصدر: erp_journal_entries وerp_journal_lines":"يلزم تسجيل الدخول لعرض قيود المنشأة"}</span></div><div className="journal-actions"><button className="journal-action" onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button><button className="journal-action primary" onClick={exportCsv} disabled={!rows.length}><Download size={14}/> تصدير CSV</button><button className="journal-action primary" onClick={openNew} disabled={!live||!canManage}><Plus size={14}/> قيد جديد</button></div></div>
   <div className="journal-filters"><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث برقم القيد أو التاريخ أو الطرف أو الحساب"/><select value={statusFilter} onChange={e=>setStatusFilter(e.target.value as any)}><option value="all">كل الحالات</option><option value="draft">مسودات</option><option value="posted">مرحلة</option></select><span>{rows.length} سطرًا</span></div>
   <div className="journal-table-scroll"><table><thead><tr className="column-filter-row">{["رقم القيد","التاريخ","البيان","الحساب","مدين","دائن","الحالة"].map((label,n)=><th key={label}><input aria-label={"بحث "+label} placeholder={"بحث "+label} value={columnFilters[String(n)]||""} onChange={e=>setColumnFilters(v=>({...v,[String(n)]:e.target.value}))}/></th>)}<th><span className="filter-disabled">—</span></th></tr><tr><th>رقم القيد</th><th>التاريخ</th><th>البيان</th><th>الحساب</th><th>مدين</th><th>دائن</th><th>الحالة</th><th>الإجراء</th></tr></thead><tbody>
    {entries.filter(e=>(statusFilter==="all"||e.status===statusFilter)&&([e.number,e.date,e.description].join(" ").toLowerCase().includes(query.toLowerCase())||e.lines.some(l=>[l.party,l.account,l.description].join(" ").toLowerCase().includes(query.toLowerCase())))&&[e.number,e.date,e.description,e.lines.map(l=>l.account).join(" "),e.lines.map(l=>l.debit).join(" "),e.lines.map(l=>l.credit).join(" "),e.status==="posted"?"مرحل":"مسودة"].every((v,n)=>String(v).toLowerCase().includes((columnFilters[String(n)]||"").toLowerCase()))).map(e=>e.lines.map((r,i)=><tr key={r.id}><td><b>{i===0?e.number:""}</b></td><td>{i===0?e.date:""}</td><td>{i===0?e.description:r.description}</td><td>{r.account}</td><td className="journal-amount">{r.debit?money(r.debit):"—"}</td><td className="journal-amount">{r.credit?money(r.credit):"—"}</td><td>{i===0?<span className={e.status==="posted"?"journal-status posted":"journal-status draft"}>{e.status==="posted"?"مرحل":"مسودة"}</span>:""}</td><td>{i===0&&e.status==="draft"&&canManage?<div className="journal-row-actions"><button onClick={()=>openEdit(e)} disabled={saving}><FileText size={13}/> تعديل</button><button onClick={()=>void post(e)} disabled={postingId===e.id}><Send size={13}/>{postingId===e.id?"جارٍ الترحيل":"ترحيل"}</button></div>:i===0?"—":""}</td></tr>))}{!entries.length&&<tr><td colSpan={8} className="journal-empty">{loading?"جارٍ تحميل القيود...":error||"لا توجد قيود مسجلة."}</td></tr>}
   </tbody></table></div>
  </div>
  {editorOpen&&<EditDrawer canEdit={canManage}  initialMode={editingId?"view":"edit"} title={editingId?"مسودة قيد":"إنشاء قيد يومية — مسودة"} dirty={JSON.stringify({description:draftDescription,date:draftDate,lines:draftLines})!==JSON.stringify(editorOriginal)} saving={saving} error={message} onSaveError={()=>setSaving(false)} onSave={saveDraft} onDiscard={()=>{setDraftDescription(editorOriginal.description);setDraftDate(editorOriginal.date);setDraftLines(editorOriginal.lines.map(l=>({...l})));setMessage("");setError("");}} onClose={closeEditor}><div className="journal-editor">
   <div className="journal-editor-head"><div><h3>{editingId?"تعديل مسودة قيد":"إنشاء قيد يومية — مسودة"}</h3><span>الحفظ ينشئ مسودة فقط؛ الترحيل خطوة منفصلة بعد توازن القيد.</span></div><button onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))} aria-label="إغلاق المحرر"><X size={17}/></button></div>
   <div className="journal-editor-meta"><label>بيان القيد *<input value={draftDescription} onChange={e=>setDraftDescription(e.target.value)} placeholder="وصف القيد"/></label><label>تاريخ القيد *<input type="date" value={draftDate} onChange={e=>setDraftDate(e.target.value)}/></label></div>
   <div className="journal-editor-lines"><table><thead><tr><th>الحساب *</th><th>الطرف</th><th>البيان</th><th>مدين</th><th>دائن</th><th></th></tr></thead><tbody>{draftLines.map((line,i)=><tr key={i}>
    <td><select value={line.accountId} onChange={e=>updateLine(i,{accountId:e.target.value})}><option value="">اختر حسابًا قابلًا للترحيل</option>{accounts.map(a=><option key={a.id} value={a.id}>{a.account_code} — {a.account_name}</option>)}</select></td>
    <td><select value={line.partyId} onChange={e=>updateLine(i,{partyId:e.target.value})}><option value="">بدون طرف</option>{parties.map(p=><option key={p.id} value={p.id}>{p.party_name}</option>)}</select></td>
    <td><input value={line.description} onChange={e=>updateLine(i,{description:e.target.value})} placeholder="بيان السطر"/></td>
    <td><input type="number" min="0" step="0.01" value={line.debit} onChange={e=>updateLine(i,{debit:e.target.value,credit:e.target.value?"0":line.credit})}/></td>
    <td><input type="number" min="0" step="0.01" value={line.credit} onChange={e=>updateLine(i,{credit:e.target.value,debit:e.target.value?"0":line.debit})}/></td>
    <td><button className="journal-remove-line" onClick={()=>setDraftLines(old=>old.filter((_,n)=>n!==i))} disabled={draftLines.length<=2} title="حذف السطر"><Trash2 size={14}/></button></td>
   </tr>)}</tbody></table></div>
   <div className="journal-editor-foot"><button className="journal-action" onClick={()=>setDraftLines(old=>[...old,emptyLine()])}><Plus size={14}/> إضافة سطر</button><div><span>إجمالي المدين: <b>{money(draftDebit)}</b></span><span>إجمالي الدائن: <b>{money(draftCredit)}</b></span><span className={draftBalanced?"balanced":"unbalanced"}>الفرق: <b>{money(draftDebit-draftCredit)}</b></span></div></div>
   <div className="journal-editor-actions"><button className="journal-action primary" onClick={()=>window.dispatchEvent(new Event("silsila:edit-save"))} disabled={saving}><Save size={14}/>{saving?"جارٍ الحفظ":"حفظ المسودة"}</button><button className="journal-action" onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))}>إلغاء</button></div>
  </div></EditDrawer>}
  {error&&<div className="operation-feedback warning">{error}</div>}{message&&<div className="operation-feedback">{message}</div>}
  <div className="journal-list"><div className="journal-list-head"><div><h3><Scale size={17}/> ميزان المراجعة</h3><span>تجميع حركة القيود المرحلة فقط، دون المسودات أو الأرصدة الافتتاحية.</span></div></div><div className="journal-table-scroll"><table><thead><tr><th>الحساب</th><th>مدين</th><th>دائن</th><th>صافي الحركة</th></tr></thead><tbody>{trial.map(([account,v])=><tr key={account}><td>{account}</td><td>{money(v.debit)}</td><td>{money(v.credit)}</td><td>{money(v.debit-v.credit)}</td></tr>)}<tr><th>الإجمالي</th><th>{money(trial.reduce((s,[,v])=>s+v.debit,0))}</th><th>{money(trial.reduce((s,[,v])=>s+v.credit,0))}</th><th>{money(trial.reduce((s,[,v])=>s+v.debit-v.credit,0))}</th></tr></tbody></table></div></div>
  <div className="journal-footnote"><Scale size={15}/> {live?"القيود والمسودات تُقرأ من قاعدة سلسلة. الترحيل يتحقق من توازن القيد والفترة المالية والحسابات من خلال إجراء قاعدة البيانات.":"دفتر القيود يتطلب تسجيل الدخول إلى المنشأة ولا يعرض بيانات محلية بديلة."}</div>
 </section>;
}
