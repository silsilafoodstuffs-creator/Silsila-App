import { useMemo,useState } from "react";
import { BookOpen,Plus,Search,Trash2,ShieldCheck,Wallet,RefreshCw } from "lucide-react";
import { readJournal } from "./accounting";

type AccountType="asset"|"liability"|"equity"|"revenue"|"expense";
type Account={id:string;code:string;name:string;type:AccountType;parent:string;system:boolean;active:boolean};
const KEY="silsila-react-preview:accounting:chart";
const types:{value:AccountType;label:string;code:string}[]=[
 {value:"asset",label:"أصول",code:"1"},{value:"liability",label:"التزامات",code:"2"},{value:"equity",label:"حقوق ملكية",code:"3"},{value:"revenue",label:"إيرادات",code:"4"},{value:"expense",label:"مصروفات",code:"5"}
];
const defaults:Account[]=[
 {id:"grp-assets",code:"1",name:"الأصول",type:"asset",parent:"",system:true,active:true},
 {id:"grp-liabilities",code:"2",name:"الالتزامات",type:"liability",parent:"",system:true,active:true},
 {id:"grp-equity",code:"3",name:"حقوق الملكية",type:"equity",parent:"",system:true,active:true},
 {id:"grp-revenue",code:"4",name:"الإيرادات",type:"revenue",parent:"",system:true,active:true},
 {id:"grp-expenses",code:"5",name:"المصروفات",type:"expense",parent:"",system:true,active:true},
 {id:"cash",code:"1101",name:"الخزينة الرئيسية",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"bank",code:"1102",name:"البنك الرئيسي",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"checks",code:"1103",name:"شيكات تحت التحصيل",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"card-in",code:"1104",name:"حسابات التحصيل الإلكتروني",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"inventory",code:"1201",name:"مخزون البضائع",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"customers",code:"1301",name:"العملاء",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"vat-in",code:"1302",name:"ضريبة القيمة المضافة - مدخلات",type:"asset",parent:"grp-assets",system:true,active:true},
 {id:"suppliers",code:"2101",name:"الموردون",type:"liability",parent:"grp-liabilities",system:true,active:true},
 {id:"vat-out",code:"2102",name:"ضريبة القيمة المضافة - مخرجات",type:"liability",parent:"grp-liabilities",system:true,active:true},
 {id:"card-out",code:"2103",name:"حسابات الدفع الإلكتروني",type:"liability",parent:"grp-liabilities",system:true,active:true},
 {id:"sales",code:"4101",name:"مبيعات البضائع",type:"revenue",parent:"grp-revenue",system:true,active:true}
];
const read=():Account[]=>{try{const raw=localStorage.getItem(KEY);if(!raw)return defaults;const parsed=JSON.parse(raw);return Array.isArray(parsed)?[...defaults.filter(d=>!parsed.some((x:Account)=>x.id===d.id)),...parsed]:defaults;}catch{return defaults;}};
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const typeLabel=(v:AccountType)=>types.find(t=>t.value===v)?.label||v;
export default function AccountsWorkspace(){
 const [accounts,setAccounts]=useState<Account[]>(read);
 const [query,setQuery]=useState("");const [typeFilter,setTypeFilter]=useState("all");
 const [showForm,setShowForm]=useState(false);const [code,setCode]=useState("");const [name,setName]=useState("");const [type,setType]=useState<AccountType>("asset");const [parent,setParent]=useState("grp-assets");const [message,setMessage]=useState("");
 const journal=readJournal();
 const rows=useMemo(()=>accounts.filter(a=>a.active&&(typeFilter==="all"||a.type===typeFilter)&&[a.code,a.name,typeLabel(a.type)].join(" ").toLowerCase().includes(query.toLowerCase())).map(a=>{const lines=journal.flatMap(e=>e.lines.filter(l=>l.account===a.name));const debit=lines.reduce((s,l)=>s+l.debit,0),credit=lines.reduce((s,l)=>s+l.credit,0);return {...a,debit,credit,balance:debit-credit};}),[accounts,query,typeFilter,journal]);
 const save=()=>{if(!code.trim()||!name.trim()){setMessage("أدخل كود الحساب واسمه.");return;}if(accounts.some(a=>a.code===code.trim()||a.name.trim().toLowerCase()===name.trim().toLowerCase())){setMessage("كود الحساب أو اسمه مستخدم بالفعل.");return;}const next=[...accounts,{id:"acc-"+Date.now().toString(36),code:code.trim(),name:name.trim(),type,parent,system:false,active:true}];try{localStorage.setItem(KEY,JSON.stringify(next));setAccounts(next);setShowForm(false);setCode("");setName("");setMessage("تمت إضافة الحساب إلى الدليل المحلي.");}catch{setMessage("تعذر حفظ الحساب في مساحة المتصفح.");}};
 const remove=(a:Account)=>{if(a.system){setMessage("الحسابات الأساسية محمية من الحذف.");return;}if(journal.some(e=>e.lines.some(l=>l.account===a.name))){setMessage("لا يمكن حذف حساب له حركات؛ يمكنك تعطيله بدلًا من ذلك.");return;}const next=accounts.map(x=>x.id===a.id?{...x,active:false}:x);localStorage.setItem(KEY,JSON.stringify(next));setAccounts(next);setMessage("تم تعطيل الحساب محليًا.");};
 return <section className="accounts-workspace" dir="rtl">
  <div className="accounts-hero"><span className="accounts-icon"><BookOpen size={22}/></span><div><small>الإدارة المالية · التأسيس المحاسبي</small><h2>دليل الحسابات</h2><p>هيكل الحسابات الأساسي مع حماية الحسابات النظامية وقراءة الحركات المرتبطة بدفتر القيود المحلي.</p></div><span className="accounts-local">محلي للمعاينة</span></div>
  <div className="accounts-summary"><div><span>إجمالي الحسابات</span><b>{accounts.filter(a=>a.active).length}</b></div><div><span>حسابات أساسية محمية</span><b>{accounts.filter(a=>a.system).length}</b></div><div><span>حسابات مضافة</span><b>{accounts.filter(a=>!a.system&&a.active).length}</b></div><div><span>قيود مرتبطة</span><b>{journal.length}</b></div></div>
  <div className="accounts-panel"><div className="accounts-panel-head"><div><b>شجرة الحسابات</b><small>الأرصدة المعروضة ناتجة عن القيود المحلية فقط، ولا تشمل أرصدة افتتاحية.</small></div><button className="accounts-add" onClick={()=>setShowForm(v=>!v)}><Plus size={15}/> إضافة حساب</button></div>
  {showForm&&<div className="accounts-form"><label><span>كود الحساب</span><input value={code} onChange={e=>setCode(e.target.value)} placeholder="مثال 1105"/></label><label><span>اسم الحساب</span><input value={name} onChange={e=>setName(e.target.value)} placeholder="اسم الحساب"/></label><label><span>طبيعة الحساب</span><select value={type} onChange={e=>{const t=e.target.value as AccountType;setType(t);setParent(defaults.find(a=>a.type===t&&a.parent==="")?.id||"");}}>{types.map(t=><option key={t.value} value={t.value}>{t.label}</option>)}</select></label><label><span>الحساب الأب</span><select value={parent} onChange={e=>setParent(e.target.value)}>{accounts.filter(a=>a.type===type&&a.parent===""&&a.active).map(a=><option key={a.id} value={a.id}>{a.code} · {a.name}</option>)}</select></label><div className="accounts-form-actions"><button onClick={save}>حفظ الحساب</button><button className="cancel" onClick={()=>setShowForm(false)}>إلغاء</button></div></div>}
  <div className="accounts-filters"><div><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث بالكود أو اسم الحساب"/></div><select value={typeFilter} onChange={e=>setTypeFilter(e.target.value)}><option value="all">كل الأنواع</option>{types.map(t=><option key={t.value} value={t.value}>{t.label}</option>)}</select><button onClick={()=>{setAccounts(read());setMessage("تم تحديث الدليل من التخزين المحلي.");}}><RefreshCw size={14}/> تحديث</button></div>
  <div className="accounts-table-scroll"><table><thead><tr><th>كود الحساب</th><th>اسم الحساب</th><th>النوع</th><th>مدين</th><th>دائن</th><th>صافي الحركة</th><th>الحماية</th><th>إجراء</th></tr></thead><tbody>{rows.map(a=><tr key={a.id}><td className="accounts-code">{a.code}</td><td><b>{a.name}</b></td><td>{typeLabel(a.type)}</td><td>{money(a.debit)}</td><td>{money(a.credit)}</td><td className="accounts-balance">{money(a.balance)}</td><td>{a.system?<span className="accounts-protected"><ShieldCheck size={13}/> نظامي</span>:"قابل للإدارة"}</td><td>{a.system?<span className="accounts-lock">محمي</span>:<button className="accounts-delete" onClick={()=>remove(a)} title="تعطيل الحساب"><Trash2 size={14}/></button>}</td></tr>)}{!rows.length&&<tr><td colSpan={8} className="accounts-empty">لا توجد حسابات مطابقة.</td></tr>}</tbody></table></div>
  </div>{message&&<div className="accounts-message" role="status">{message}</div>}<div className="accounts-note"><Wallet size={15}/> هذه بداية دليل الحسابات وليست إعدادًا محاسبيًا نهائيًا. لا توجد أرصدة افتتاحية أو ميزان مراجعة معتمد، كما أن الربط مع دليل إنتاجي وقاعدة بيانات مشتركة لم يُفعّل بعد.</div>
 </section>;
}
