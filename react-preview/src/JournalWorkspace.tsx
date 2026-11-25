import { useEffect,useMemo,useState } from "react";
import { Download,RefreshCw,BookOpen,Scale } from "lucide-react";
import { readJournal } from "./accounting";
import { supabase } from "./supabase";
type Line={account:string;debit:number;credit:number;party:string;description:string;entry:string;date:string;source:string;id:string};
type Entry={id:string;number:string;date:string;description:string;source:string;lines:Line[]};
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
export default function JournalWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const live=Boolean(supabase&&companyId);
 const [entries,setEntries]=useState<Entry[]>([]);
 const [query,setQuery]=useState("");
 const [loading,setLoading]=useState(live);
 const [message,setMessage]=useState("");
 const load=async()=>{
  if(!live||!supabase){const local=readJournal();setEntries(local.map(e=>({id:e.id,number:e.id,date:e.date,description:e.description,source:e.sourceType,lines:e.lines.map((l,i)=>({account:l.account,debit:l.debit,credit:l.credit,party:e.party,description:e.description,entry:e.id,date:e.date,source:e.sourceType,id:e.id+"-"+i}))})));setLoading(false);return;}
  setLoading(true);setMessage("");
  const [je,ac,pa]=await Promise.all([
   supabase.from("erp_journal_entries").select("id,entry_number,entry_number_display,entry_date,description,source_type,status").eq("company_id",companyId).eq("status","posted").order("entry_date",{ascending:false}).limit(500),
   supabase.from("erp_accounts").select("id,account_code,account_name").eq("company_id",companyId),
   supabase.from("erp_parties").select("id,party_name").eq("company_id",companyId)
  ]);
  const entryIds=(je.data||[]).map((e:any)=>e.id);
  const jl=entryIds.length?await supabase.from("erp_journal_lines").select("id,entry_id,account_id,description,debit,credit,party_id").in("entry_id",entryIds):{data:[],error:null};
  const err=je.error||jl.error||ac.error||pa.error;
  if(err){setMessage("تعذر تحميل دفتر الأستاذ من قاعدة سلسلة: "+err.message);setEntries([]);setLoading(false);return;}
  const accountMap=new Map<string,string>((ac.data||[]).map((a:any)=>[a.id,a.account_code+" — "+a.account_name]));
  const partyMap=new Map<string,string>((pa.data||[]).map((p:any)=>[p.id,p.party_name]));
  const linesByEntry=new Map<string,Line[]>();
  for(const l of jl.data||[]){const entry=(je.data||[]).find((e:any)=>e.id===l.entry_id);if(!entry)continue;const line:Line={id:l.id,entry:entry.entry_number_display||String(entry.entry_number),date:entry.entry_date,source:entry.source_type,description:l.description||entry.description,party:l.party_id?partyMap.get(l.party_id)||"": "",account:accountMap.get(l.account_id)||"حساب غير معروف",debit:Number(l.debit),credit:Number(l.credit)};const arr=linesByEntry.get(l.entry_id)||[];arr.push(line);linesByEntry.set(l.entry_id,arr);}
  setEntries((je.data||[]).map((e:any)=>({id:e.id,number:e.entry_number_display||String(e.entry_number),date:e.entry_date,description:e.description,source:e.source_type,lines:(linesByEntry.get(e.id)||[]).map(l=>({...l,entry:e.entry_number_display||String(e.entry_number)}))})));
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);
 const rows=useMemo(()=>entries.flatMap(e=>e.lines).filter(r=>[r.entry,r.date,r.party,r.account,r.description,r.source].join(" ").toLowerCase().includes(query.toLowerCase())),[entries,query]);
 const debit=rows.reduce((s,r)=>s+r.debit,0),credit=rows.reduce((s,r)=>s+r.credit,0);
 const trial=useMemo(()=>{const m=new Map<string,{debit:number;credit:number}>();entries.forEach(e=>e.lines.forEach(l=>{const v=m.get(l.account)||{debit:0,credit:0};v.debit+=l.debit;v.credit+=l.credit;m.set(l.account,v)}));return [...m.entries()].sort((a,b)=>a[0].localeCompare(b[0],"ar"))},[entries]);
 const exportCsv=()=>{const data=[["رقم القيد","التاريخ","البيان","الطرف","الحساب","مدين","دائن"],...rows.map(r=>[r.entry,r.date,r.description,r.party,r.account,r.debit,r.credit])];const csv=data.map(a=>a.map(v=>'"'+String(v).replace(/"/g,'""')+'"').join(",")).join("\n");const url=URL.createObjectURL(new Blob(["\uFEFF",csv],{type:"text/csv;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download="silsila-journal.csv";a.click();URL.revokeObjectURL(url)};
 return <section className="journal-workspace" dir="rtl"><div className="journal-hero"><span className="journal-hero-icon"><BookOpen size={22}/></span><div className="journal-hero-copy"><small>{live?"الإدارة المالية · دفتر الأستاذ الفعلي":"الإدارة المالية · دفتر المعاينة المحلي"}</small><h2>قيود اليومية</h2><p>{live?"يعرض القيود المرحلة من قاعدة سلسلة وحساباتها وأطرافها.":"يعرض قيود المعاينة المحلية فقط."}</p></div></div>
 <div className="journal-stats"><div><span>عدد القيود</span><b>{entries.length}</b></div><div><span>إجمالي المدين المعروض</span><b>{money(debit)} ج.م</b></div><div><span>إجمالي الدائن المعروض</span><b>{money(credit)} ج.م</b></div><div><span>فرق المراجعة</span><b>{money(debit-credit)} ج.م</b><small>{Math.abs(debit-credit)<0.01?"القيود متوازنة في نطاق العرض":"توجد فروق تحتاج مراجعة"}</small></div></div>
 <div className="journal-list"><div className="journal-list-head"><div><h3><BookOpen size={17}/> دفتر القيود المرحلة</h3><span>{live?"مصدر البيانات: erp_journal_entries وerp_journal_lines":"مصدر البيانات: سجل المعاينة المحلي"}</span></div><div className="journal-actions"><button className="journal-action" onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button><button className="journal-action primary" onClick={exportCsv}><Download size={14}/> تصدير CSV</button></div></div><div className="journal-filters"><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث برقم القيد أو التاريخ أو الطرف أو الحساب"/><span>{rows.length} سطرًا</span></div><div className="journal-table-scroll"><table><thead><tr><th>رقم القيد</th><th>التاريخ</th><th>البيان</th><th>الطرف</th><th>الحساب</th><th>مدين</th><th>دائن</th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td><b>{r.entry}</b></td><td>{r.date}</td><td>{r.description}</td><td>{r.party||"—"}</td><td>{r.account}</td><td className="journal-amount">{r.debit?money(r.debit):"—"}</td><td className="journal-amount">{r.credit?money(r.credit):"—"}</td></tr>)}{!rows.length&&<tr><td colSpan={7} className="journal-empty">{loading?"جارٍ تحميل القيود...":"لا توجد قيود مرحلة في قاعدة البيانات لهذا العرض."}</td></tr>}</tbody></table></div></div>
 <div className="journal-list"><div className="journal-list-head"><div><h3><Scale size={17}/> ميزان المراجعة</h3><span>تجميع أرصدة الحركة من القيود المرحلة الظاهرة، دون الأرصدة الافتتاحية غير المرحلة.</span></div></div><div className="journal-table-scroll"><table><thead><tr><th>الحساب</th><th>مدين</th><th>دائن</th><th>صافي الحركة</th></tr></thead><tbody>{trial.map(([account,v])=><tr key={account}><td>{account}</td><td>{money(v.debit)}</td><td>{money(v.credit)}</td><td>{money(v.debit-v.credit)}</td></tr>)}<tr><th>الإجمالي</th><th>{money(trial.reduce((s,[,v])=>s+v.debit,0))}</th><th>{money(trial.reduce((s,[,v])=>s+v.credit,0))}</th><th>{money(trial.reduce((s,[,v])=>s+v.debit-v.credit,0))}</th></tr></tbody></table></div></div>
 {message&&<div className="operation-feedback warning">{message}</div>}<div className="journal-footnote"><Scale size={15}/> {live?"قراءة فعلية للقيود المرحلة من قاعدة سلسلة. ميزان المراجعة هنا تجميع لحركة القيود، ولا يشمل الأرصدة الافتتاحية أو القيود غير المرحلة.":"دفتر المعاينة المحلي غير متصل بقاعدة الإنتاج."}</div></section>;
}
