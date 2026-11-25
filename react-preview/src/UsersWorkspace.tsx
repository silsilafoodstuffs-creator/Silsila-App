import { useMemo, useState } from "react";
import { Users, UserRoundCog, Tags, ShieldCheck, KeyRound, Search, Plus, Pencil, Trash2, Save, X, Sparkles, CheckCircle2, Download, RefreshCw, LockKeyhole } from "lucide-react";

type Row = {id:string; code:string; name:string; parent?:string; detail?:string; template?:string; status:string};
const initial:Record<string,Row[]> = {
 users:[
  {id:"u1",code:"USR-0001",name:"مدير النظام",parent:"مدير نظام",detail:"الإدارة المركزية",template:"مدير النظام",status:"نشط"},
  {id:"u2",code:"USR-0002",name:"مسؤول المبيعات",parent:"موظف",detail:"فرع المقر الرئيسي",template:"مدير مبيعات",status:"نشط"},
  {id:"u3",code:"USR-0003",name:"أمين المخزن",parent:"موظف",detail:"المخزن الرئيسي",template:"أمين مخزن",status:"نشط"}
 ],
 types:[
  {id:"t1",code:"UT-001",name:"عميل",detail:"حسابات العملاء والتجار",status:"نشط"},
  {id:"t2",code:"UT-002",name:"مورد",detail:"الشركات والوكلاء والموردون",status:"نشط"},
  {id:"t3",code:"UT-003",name:"مستهلك",detail:"مستخدم نهائي",status:"نشط"},
  {id:"t4",code:"UT-004",name:"شركة شحن",detail:"شركات النقل والتوصيل",status:"نشط"},
  {id:"t5",code:"UT-005",name:"موظف",detail:"العاملون داخل المنشأة",status:"نشط"},
  {id:"t6",code:"UT-006",name:"مدير نظام",detail:"إدارة النظام والمنشأة",status:"نشط"}
 ],
 categories:[
  {id:"c1",code:"UC-001",name:"سوبر ماركت",parent:"عميل",detail:"متجر تجزئة",status:"نشط"},
  {id:"c2",code:"UC-002",name:"تاجر إعادة بيع",parent:"عميل",detail:"نشاط إعادة البيع",status:"نشط"},
  {id:"c3",code:"UC-003",name:"شركة",parent:"مورد",detail:"مورد في شكل شركة",status:"نشط"},
  {id:"c4",code:"UC-004",name:"وكيل",parent:"مورد",detail:"وكيل علامة أو منتج",status:"نشط"},
  {id:"c5",code:"UC-005",name:"شركة توزيع",parent:"مورد",detail:"توزيع وتوريد",status:"نشط"}
 ],
 templates:[
  {id:"p1",code:"TPL-001",name:"مدير النظام",parent:"مدير نظام",detail:"إدارة كاملة للنظام",status:"نشط"},
  {id:"p2",code:"TPL-002",name:"مدير مبيعات",parent:"موظف",detail:"المبيعات والعملاء والتقارير",status:"نشط"},
  {id:"p3",code:"TPL-003",name:"أمين مخزن",parent:"موظف",detail:"الأصناف والحركات المخزنية",status:"نشط"},
  {id:"p4",code:"TPL-004",name:"محاسب",parent:"موظف",detail:"الحسابات والخزينة والقيود",status:"نشط"}
 ],
 permissions:[
  {id:"r1",code:"PER-001",name:"لوحة الملخص التنفيذي",parent:"عرض · تصدير",detail:"الرئيسية",status:"نشط"},
  {id:"r2",code:"PER-002",name:"إدارة المستخدمين",parent:"عرض · إضافة · تعديل · حذف",detail:"إدارة النظام",status:"نشط"},
  {id:"r3",code:"PER-003",name:"فواتير المبيعات",parent:"عرض · إضافة · تعديل · اعتماد · طباعة",detail:"إدارة الأعمال",status:"نشط"},
  {id:"r4",code:"PER-004",name:"المخازن والجرد",parent:"عرض · إضافة · تعديل · اعتماد",detail:"المخازن",status:"نشط"},
  {id:"r5",code:"PER-005",name:"الحسابات والقيود",parent:"عرض · إضافة · تعديل · اعتماد",detail:"الإدارة المالية",status:"نشط"}
 ]
};
const tabs=[{id:"users",label:"المستخدمون",icon:Users},{id:"types",label:"أنواع المستخدمين",icon:UserRoundCog},{id:"categories",label:"التصنيفات",icon:Tags},{id:"templates",label:"قوالب الصلاحيات",icon:ShieldCheck},{id:"permissions",label:"مصفوفة الصلاحيات",icon:KeyRound}];
const titles:Record<string,string>={users:"سجل المستخدمين",types:"أنواع الحسابات",categories:"تصنيفات المستخدمين",templates:"قوالب المستخدمين والصلاحيات",permissions:"الصلاحيات حسب الوحدة والإجراء"};
export default function UsersWorkspace(){
 const [tab,setTab]=useState("users");
 const [data,setData]=useState<Record<string,Row[]>>(()=>{try{const raw=localStorage.getItem("silsila-users-center-v1");return raw?{...initial,...JSON.parse(raw)}:initial}catch{return initial}});
 const [query,setQuery]=useState(""); const [editor,setEditor]=useState(false); const [editing,setEditing]=useState<Row|null>(null); const [form,setForm]=useState({code:"",name:"",parent:"",detail:""}); const [message,setMessage]=useState("");
 const saveData=(next:Record<string,Row[]>)=>{setData(next);try{localStorage.setItem("silsila-users-center-v1",JSON.stringify(next))}catch{}};
 const rows=useMemo(()=>data[tab].filter(r=>[r.code,r.name,r.parent||"",r.detail||""].join(" ").toLowerCase().includes(query.toLowerCase())),[data,tab,query]);
 const openNew=()=>{setEditing(null);setForm({code:"",name:"",parent:"",detail:""});setEditor(true);setMessage("")};
 const openEdit=(r:Row)=>{setEditing(r);setForm({code:r.code,name:r.name,parent:r.parent||"",detail:r.detail||""});setEditor(true);setMessage("")};
 const save=()=>{if(!form.code.trim()||!form.name.trim()){setMessage("أدخل الكود والاسم قبل الحفظ.");return}const list=data[tab];if(list.some(r=>r.id!==editing?.id&&r.code===form.code)){setMessage("الكود مستخدم بالفعل.");return}const row:Row={id:editing?.id||tab+"-"+Date.now(),...form,status:editing?.status||"نشط"};saveData({...data,[tab]:editing?list.map(r=>r.id===editing.id?row:r):[row,...list]});setEditor(false);setMessage("تم الحفظ محليًا في نسخة المعاينة.");};
 const toggle=(r:Row)=>saveData({...data,[tab]:data[tab].map(x=>x.id===r.id?{...x,status:x.status==="نشط"?"موقوف":"نشط"}:x)});
 const remove=(r:Row)=>{if(confirm("تأكيد حذف "+r.name+"؟"))saveData({...data,[tab]:data[tab].filter(x=>x.id!==r.id)})};
 const exportCsv=()=>{const csv=[["الكود","الاسم","النوع / الارتباط","التفاصيل","الحالة"],...rows.map(r=>[r.code,r.name,r.parent||"",r.detail||"",r.status])].map(a=>a.map(x=>'"'+String(x).replace(/"/g,'""')+'"').join(",")).join("\n");const url=URL.createObjectURL(new Blob(["\uFEFF",csv],{type:"text/csv;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download="silsila-"+tab+".csv";a.click();URL.revokeObjectURL(url)};
 const activeUsers=data.users.filter(r=>r.status==="نشط").length;
 return <div className="users-center" dir="rtl">
  <section className="users-hero"><div className="users-hero-icon"><Users size={25}/></div><div className="users-hero-copy"><small>مركز إدارة الحسابات والهوية والصلاحيات</small><h2>المستخدمين</h2><p>إدارة موحدة لكل أنواع المستخدمين وتصنيفاتهم وقوالبهم وصلاحياتهم من شاشة واحدة مترابطة</p></div><span className="users-hero-glow"><Sparkles size={27}/></span></section>
  <div className="users-summary"><div><span>إجمالي المستخدمين</span><b>{data.users.length}</b><small>كل الحسابات المسجلة</small></div><div><span>مستخدمون نشطون</span><b>{activeUsers}</b><small>حسابات مفعلة</small></div><div><span>أنواع المستخدمين</span><b>{data.types.length}</b><small>أنواع الحسابات</small></div><div><span>قوالب الصلاحيات</span><b>{data.templates.length}</b><small>قوالب جاهزة للتعيين</small></div></div>
  <nav className="users-tabs" aria-label="أقسام المستخدمين">{tabs.map(t=>{const I=t.icon;return <button key={t.id} className={tab===t.id?"active":""} onClick={()=>{setTab(t.id);setQuery("");setEditor(false);setMessage("")}}><I size={16}/>{t.label}{t.id==="users"&&<em>{data.users.length}</em>}</button>})}</nav>
  {tab==="permissions"?<section className="users-permission-panel"><div className="users-panel-heading"><div><b>مصفوفة الصلاحيات</b><small>تصور تنظيمي للصلاحيات التي يمكن تجميعها داخل القوالب وربطها بالمستخدمين</small></div><span className="users-readonly"><LockKeyhole size={13}/> نموذج استرشادي</span></div><div className="users-permission-table"><table><thead><tr><th>الوحدة / الشاشة</th><th>عرض</th><th>إضافة</th><th>تعديل</th><th>حذف</th><th>اعتماد</th><th>طباعة</th><th>تصدير</th></tr></thead><tbody>{["الملخص التنفيذي","المستخدمين","العملاء والموردون","المبيعات","المشتريات","المخازن والأصناف","الحسابات المالية","الخزينة والبنوك","الموارد البشرية","إعدادات عامة"].map((m,i)=><tr key={m}><td>{m}</td>{Array.from({length:7},(_,j)=><td key={j}><input type="checkbox" defaultChecked={i===1||i===0?j<3:j===0||j===1}/></td>)}</tr>)}</tbody></table></div><p className="users-hint">تفعيل المربعات هنا للمعاينة البصرية فقط؛ ربط الصلاحيات الفعلي بمحرك المصادقة لم يتم بعد.</p></section>:<section className="users-list-panel">
   <div className="users-list-head"><div><h3>{titles[tab]}</h3><span>{tab==="users"?"كل حساب مرتبط بنوع وتصنيف وقالب صلاحيات ونطاق عمل":tab==="types"?"تعريف طبيعة الحساب ومساحة استخدامه":tab==="categories"?"كل تصنيف تابع لنوع مستخدم محدد": "تجميع الصلاحيات في قوالب قابلة للإسناد"}</span></div><div className="users-actions"><button className="users-action secondary" onClick={()=>{setQuery("");setMessage("تم تحديث العرض من البيانات المحلية.")}}><RefreshCw size={14}/> تحديث</button><button className="users-action secondary" onClick={exportCsv}><Download size={14}/> Excel / CSV</button><button className="users-action primary" onClick={openNew}><Plus size={15}/> إضافة</button></div></div>
   <div className="users-filters"><div className="users-search"><Search size={15}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="ابحث بالكود أو الاسم أو النوع أو التفاصيل..."/></div><span>عرض {rows.length} من {data[tab].length}</span></div>
   <div className="users-table-scroll"><table><thead><tr><th>الكود</th><th>{tab==="users"?"اسم المستخدم":"الاسم"}</th><th>{tab==="users"?"نوع المستخدم":tab==="categories"?"تابع لنوع":"الدور / الارتباط"}</th><th>{tab==="users"?"قالب الصلاحيات":"التفاصيل"}</th><th>الحالة</th><th>الإجراءات</th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td className="users-code">{r.code}</td><td><b>{r.name}</b></td><td>{r.parent||"—"}</td><td>{tab==="users"?r.template||"غير معين":r.detail||"—"}</td><td><button className={r.status==="نشط"?"users-status on":"users-status off"} onClick={()=>toggle(r)}>{r.status}</button></td><td><div className="users-row-actions"><button title="تعديل" onClick={()=>openEdit(r)}><Pencil size={14}/></button><button title="حذف" onClick={()=>remove(r)}><Trash2 size={14}/></button></div></td></tr>)}{!rows.length&&<tr><td colSpan={6} className="users-empty">لا توجد نتائج مطابقة.</td></tr>}</tbody></table></div>
  </section>}
  {editor&&<section className="users-editor"><div className="users-editor-head"><div><b>{editing?"تعديل سجل":"إضافة سجل جديد"} · {tabs.find(t=>t.id===tab)?.label}</b><small>أدخل البيانات الأساسية ثم احفظ</small></div><button onClick={()=>setEditor(false)}><X size={16}/></button></div><div className="users-editor-fields"><label><span>الكود *</span><input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))}/></label><label><span>الاسم *</span><input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))}/></label><label><span>{tab==="categories"?"نوع المستخدم":tab==="users"?"نوع المستخدم / الدور":"الارتباط / الدور"}</span><input value={form.parent} onChange={e=>setForm(v=>({...v,parent:e.target.value}))} placeholder="مثال: عميل، مورد، موظف"/></label><label><span>التفاصيل</span><input value={form.detail} onChange={e=>setForm(v=>({...v,detail:e.target.value}))}/></label></div><div className="users-editor-foot"><button className="users-action primary" onClick={save}><Save size={14}/> حفظ</button><button className="users-action secondary" onClick={()=>setEditor(false)}>إلغاء</button>{message&&<small>{message}</small>}</div></section>}
  {message&&!editor&&<div className="users-feedback"><CheckCircle2 size={15}/>{message}</div>}
  <div className="users-footnote"><ShieldCheck size={16}/><span>هذه شاشة موحدة للمعاينة؛ التغييرات تحفظ داخل هذا المتصفح فقط. لم يتم ربطها بمصادقة حقيقية أو قاعدة بيانات الإنتاج، والصلاحيات لا تمنع الدخول فعليًا حتى استكمال الربط الخلفي.</span></div>
 </div>
}
