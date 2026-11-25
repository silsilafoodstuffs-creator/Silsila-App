import { useEffect, useMemo, useState } from "react";
import { Plus, Trash2, Save, RotateCcw, Package, ShoppingCart, ShoppingBag, CheckCircle2, FileText, Clock3 } from "lucide-react";

type Line = { id:number; name:string; unit:string; qty:number; price:number };
type SavedDocument = { id:string; party:string; date:string; payment:string; total:number; lines:number; kind:string; savedAt:string; lineItems?:Line[]; discount?:number; tax?:number; notes?:string; status?:"draft"|"posted"; postedAt?:string };
type StockMovement = { id:string; documentId:string; documentKind:string; date:string; party:string; item:string; unit:string; qty:number; direction:"in"|"out"; createdAt:string };
const STOCK_MOVEMENTS_KEY="silsila-react-preview:stock-movements";
const seed:Line[] = [
 {id:1,name:"أرز مصري فاخر 1 كجم",unit:"كرتونة",qty:2,price:720},
 {id:2,name:"سكر أبيض 1 كجم",unit:"كرتونة",qty:1,price:650},
];
const fmt=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-");};
const read=(key:string,fallback:any)=>{try{const v=localStorage.getItem(key);return v?JSON.parse(v):fallback;}catch{return fallback;}};
export default function OperationsWorkspace({kind}:{kind:"sale"|"purchase"|"inventory"}){
 const key="silsila-react-preview:operations:"+kind;
 const docsKey="silsila-react-preview:documents";
 const [lines,setLines]=useState<Line[]>(()=>read(key,kind==="inventory"?seed:seed));
 const partyListKey="silsila-react-preview:"+(kind==="sale"?"العملاء":"الموردون");
 const partyOptions=read(partyListKey,[]) as {name?:string}[];
 const itemOptions=read("silsila-react-preview:المخازن والأصناف",[]) as {name?:string}[];
 const itemListId="silsila-items-"+kind;
 const partyListId="silsila-parties-"+kind;
 const [party,setParty]=useState(kind==="sale"?"مؤسسة النور التجارية":"شركة الأمل للتوريدات");
 const [discount,setDiscount]=useState(0); const [tax,setTax]=useState(14);
 const [date,setDate]=useState(today()); const [payment,setPayment]=useState("نقدي");
 const [notes,setNotes]=useState(""); const [saved,setSaved]=useState(false);
 const [message,setMessage]=useState(""); const [nextId,setNextId]=useState(3);
 const [documents,setDocuments]=useState<SavedDocument[]>(()=>read(docsKey,[]));
 const [stockMovements,setStockMovements]=useState<StockMovement[]>(()=>read(STOCK_MOVEMENTS_KEY,[]));\n const [lineFilters,setLineFilters]=useState<string[]>(Array(5).fill("")); const [movementFilters,setMovementFilters]=useState<string[]>(Array(7).fill("")); const [documentFilters,setDocumentFilters]=useState<string[]>(Array(6).fill(""));
 const subtotal=useMemo(()=>lines.reduce((s,l)=>s+l.qty*l.price,0),[lines]);
 const discountValue=Math.min(subtotal,Math.max(0,discount));
 const taxValue=(subtotal-discountValue)*Math.max(0,tax)/100;
 const total=subtotal-discountValue+taxValue;
 const title=kind==="sale"?"فاتورة بيع جديدة":kind==="purchase"?"فاتورة شراء جديدة":"إدارة الأصناف والمخزون";
 const Icon=kind==="sale"?ShoppingCart:kind==="purchase"?ShoppingBag:Package;
 useEffect(()=>{try{localStorage.setItem(key,JSON.stringify(lines));}catch{}},[key,lines]);
 useEffect(()=>{try{localStorage.setItem(docsKey,JSON.stringify(documents));}catch{}},[docsKey,documents]);
 useEffect(()=>{try{localStorage.setItem(STOCK_MOVEMENTS_KEY,JSON.stringify(stockMovements));}catch{}},[stockMovements]);
 const update=(id:number,k:"name"|"unit"|"qty"|"price",v:string)=>{setLines(old=>old.map(l=>l.id===id?{...l,[k]:k==="qty"||k==="price"?Math.max(0,Number(v)||0):v}:l));setSaved(false);};
 const add=()=>{setLines(old=>[...old,{id:nextId,name:"",unit:"كرتونة",qty:1,price:0}]);setNextId(n=>n+1);setSaved(false);};
 const reset=()=>{setLines(kind==="inventory"?[]:seed);setDiscount(0);setTax(14);setNotes("");setSaved(false);setMessage("");};
 const save=()=>{
  if(kind==="inventory"){
   if(lines.some(l=>!l.name.trim())){setMessage("اكتب اسم كل صنف قبل الحفظ.");return;}
   setSaved(true);setMessage("تم حفظ قائمة الأصناف محليًا على هذا المتصفح.");return;
  }
  if(!party.trim()){setMessage("أدخل اسم العميل أو المورد.");return;}
  if(!lines.length||lines.some(l=>!l.name.trim()||l.qty<=0)){setMessage("أضف صنفًا صحيحًا، وتأكد من الاسم والكمية.");return;}
  const prefix=kind==="sale"?"SAL":"PUR";
  const doc:SavedDocument={id:prefix+"-"+Date.now().toString().slice(-8),party:party.trim(),date,payment,total,lines:lines.length,kind,status:"draft",savedAt:new Date().toISOString(),lineItems:lines.map(line=>({...line})),discount:discountValue,tax,notes};
  setDocuments(old=>[doc,...old].slice(0,100));setSaved(true);setMessage("تم حفظ المسودة محليًا. لم يتم ترحيلها أو إرسالها إلى قاعدة بيانات.");
 };
 const recent=documents.filter(d=>d.kind===kind).slice(0,5);\n const filteredLines=lines.filter(l=>[l.name,l.unit,String(l.qty),String(l.price),fmt(l.qty*l.price)].every((v,i)=>v.toLowerCase().includes((lineFilters[i]||"").toLowerCase())));\n const filteredMovements=stockMovements.slice(0,30).filter(m=>[m.documentId,m.documentKind==="purchase"?"شراء":"بيع",m.item,m.party,m.date,fmt(m.qty)+" "+m.unit,m.direction==="in"?"وارد":"صادر"].every((v,i)=>v.toLowerCase().includes((movementFilters[i]||"").toLowerCase())));\n const filteredRecent=recent.filter(d=>[d.id,d.party,d.date,String(d.lines),fmt(d.total),d.status==="posted"?"معتمد محليًا":"مسودة"].every((v,i)=>v.toLowerCase().includes((documentFilters[i]||"").toLowerCase())));
 const reopenDoc=(doc:SavedDocument)=>{if(!doc.lineItems?.length){setMessage("هذه مسودة قديمة لا تحتوي تفاصيل الأصناف؛ لا يمكن استعادتها بالكامل.");return;}setParty(doc.party);setDate(doc.date);setPayment(doc.payment);setLines(doc.lineItems.map(line=>({...line})));setNextId(Math.max(0,...doc.lineItems.map(line=>line.id))+1);setDiscount(doc.discount??0);setTax(doc.tax??14);setNotes(doc.notes??"");setSaved(false);setMessage("تم تحميل المسودة إلى شاشة التحرير. التعديلات لن تغيّر النسخة المحفوظة إلا عند حفظ مسودة جديدة.");window.scrollTo({top:0,behavior:"smooth"});};
 const postDoc=(doc:SavedDocument)=>{
  if(doc.status==="posted"){setMessage("هذا المستند سبق اعتماده محليًا.");return;}
  if(!doc.lineItems?.length){setMessage("لا يمكن اعتماد مستند لا يحتوي تفاصيل أصناف.");return;}
  if(!window.confirm("اعتماد المستند "+doc.id+"؟ ستنشأ حركة مخزنية محلية لكل بند. هذا لا يرحّل محاسبيًا ولا يغيّر مخزون الإنتاج."))return;
  const movements:StockMovement[]=doc.lineItems.map((line,index)=>({id:doc.id+"-"+index,documentId:doc.id,documentKind:doc.kind,date:doc.date,party:doc.party,item:line.name,unit:line.unit,qty:line.qty,direction:doc.kind==="purchase"?"in":"out",createdAt:new Date().toISOString()}));
  setStockMovements(old=>[...movements,...old.filter(m=>m.documentId!==doc.id)]);
  setDocuments(old=>old.map(d=>d.id===doc.id?{...d,status:"posted",postedAt:new Date().toISOString()}:d));
  setMessage("تم اعتماد المستند وإنشاء حركات مخزنية محلية مرتبطة به. لم يتم تحديث أرصدة فعلية أو قاعدة الإنتاج.");
 };
 const removeDoc=(id:string)=>setDocuments(old=>old.filter(d=>d.id!==id));
 return <section className="operation-workspace" dir="rtl">
  <div className="operation-heading"><div className="operation-title"><span className="operation-icon"><Icon size={22}/></span><div><small>مساحة تشغيل تفاعلية · بيانات محلية</small><h2>{title}</h2><p>{kind==="sale"?"أنشئ مسودة بيع واحسب الخصم والضريبة والإجمالي، ثم راجع سجل المسودات.":kind==="purchase"?"سجّل مسودة توريد واحسب قيمتها واحتفظ بسجل محلي للمستندات.":"أدر قائمة الأصناف التجريبية مع حفظ الأسماء والوحدات والأرصدة محليًا."}</p></div></div><span className="demo-pill">معاينة فقط — لا يؤثر على الإنتاج</span></div>
  {kind!=="inventory"&&<div className="operation-form-grid"><label><span>{kind==="sale"?"العميل":"المورد"}</span><input list={partyListId} value={party} onChange={e=>setParty(e.target.value)} placeholder="اكتب الاسم أو اختر من السجلات المحفوظة"/><datalist id={partyListId}>{partyOptions.map((p,i)=>p.name?<option key={i} value={p.name}/>:null)}</datalist></label><label><span>رقم المستند</span><input value={kind==="sale"?"مسودة بيع تلقائية":"مسودة شراء تلقائية"} readOnly/></label><label><span>تاريخ المستند</span><input type="date" value={date} onChange={e=>setDate(e.target.value)}/></label><label><span>طريقة السداد</span><select value={payment} onChange={e=>setPayment(e.target.value)}><option>نقدي</option><option>آجل</option><option>تحويل بنكي</option><option>بطاقة</option></select></label></div>}
  <div className="operation-table-card"><div className="operation-table-head"><div><b>{kind==="inventory"?"قائمة الأصناف":"أصناف المستند"}</b><small>{lines.length} بند — تعديلاتك محفوظة محليًا</small></div><button className="operation-add" onClick={add}><Plus size={16}/> إضافة صنف</button></div><div className="operation-table-scroll"><table><thead><tr><th>الصنف</th><th>الوحدة</th><th>{kind==="inventory"?"الرصيد":"الكمية"}</th><th>{kind==="inventory"?"سعر البيع":"سعر الوحدة"}</th><th>{kind==="inventory"?"قيمة الرصيد":"الإجمالي"}</th><th>إجراء</th></tr><tr className="column-filter-row">{["اسم الصنف","الوحدة","الكمية","السعر","الإجمالي"].map((p,i)=><th key={p}><input placeholder={"بحث "+p} value={lineFilters[i]} onChange={e=>setLineFilters(v=>v.map((x,j)=>j===i?e.target.value:x))}/></th>)}<th><span className="filter-disabled">—</span></th></tr></thead><tbody>{filteredLines.map(l=><tr key={l.id}><td><input className="cell-input item-name" list={itemListId} value={l.name} placeholder="اسم الصنف" onChange={e=>update(l.id,"name",e.target.value)}/></td><td><select className="cell-input" value={l.unit} onChange={e=>update(l.id,"unit",e.target.value)}><option>كرتونة</option><option>وحدة</option><option>كيلو</option><option>عبوة</option></select></td><td><input className="cell-input number-input" type="number" min="0" value={l.qty} onChange={e=>update(l.id,"qty",e.target.value)}/></td><td><input className="cell-input number-input" type="number" min="0" value={l.price} onChange={e=>update(l.id,"price",e.target.value)}/></td><td className="operation-amount">{fmt(l.qty*l.price)} ج.م</td><td><button className="remove-line" title="حذف الصنف" onClick={()=>setLines(old=>old.filter(x=>x.id!==l.id))}><Trash2 size={15}/></button></td></tr>)}</tbody></table><datalist id={itemListId}>{itemOptions.map((item,i)=>item.name?<option key={i} value={item.name}/>:null)}</datalist>{lines.length===0&&<div className="operation-empty">لا توجد أصناف بعد. اضغط «إضافة صنف» للبدء.</div>}</div></div>
  {kind!=="inventory"&&<div className="operation-bottom"><div className="operation-notes"><label>ملاحظات المستند<textarea value={notes} onChange={e=>setNotes(e.target.value)} placeholder="أضف أي ملاحظات..." rows={3}/></label><div className="operation-tax"><label><span>الخصم (ج.م)</span><input type="number" min="0" value={discount} onChange={e=>setDiscount(Math.max(0,Number(e.target.value)||0))}/></label><label><span>الضريبة (%)</span><input type="number" min="0" value={tax} onChange={e=>setTax(Math.max(0,Number(e.target.value)||0))}/></label></div></div><div className="operation-totals"><div><span>الإجمالي قبل الخصم</span><b>{fmt(subtotal)} ج.م</b></div><div><span>الخصم</span><b>{fmt(discountValue)} ج.م</b></div><div><span>الضريبة</span><b>{fmt(taxValue)} ج.م</b></div><div className="grand-total"><span>صافي الفاتورة</span><strong>{fmt(total)} <small>ج.م</small></strong></div></div></div>}
  {kind==="inventory"&&<div className="inventory-summary"><div><span>عدد الأصناف المعروضة</span><b>{lines.length}</b></div><div><span>إجمالي قيمة الرصيد التجريبي</span><b>{fmt(subtotal)} ج.م</b></div><div><span>تنبيه</span><b>الأرصدة غير مرتبطة بالمخازن الفعلية</b></div></div>}
  <div className="operation-actions"><button className="operation-save" onClick={save}><Save size={16}/> {kind==="inventory"?"حفظ قائمة الأصناف":"حفظ مسودة"}</button><button className="operation-reset" onClick={reset}><RotateCcw size={15}/> إعادة ضبط</button>{saved&&<span className="saved-feedback"><CheckCircle2 size={16}/> تم الحفظ محليًا</span>}</div>
  {message&&<div className={saved?"operation-feedback":"operation-feedback warning"}>{message}</div>}
  {kind==="inventory"&&<div className="operation-history"><div className="operation-table-head"><div><b><Package size={15}/> سجل الحركات المخزنية المرتبطة بالمستندات</b><small>تظهر هنا البنود الناتجة عن اعتماد مسودات البيع والشراء محليًا</small></div><span>{stockMovements.length} حركة</span></div>{stockMovements.length?<div className="table-wrap"><table><thead><tr><th>المستند</th><th>النوع</th><th>الصنف</th><th>الطرف</th><th>التاريخ</th><th>الكمية</th><th>الاتجاه</th></tr><tr className="column-filter-row">{["المستند","النوع","الصنف","الطرف","التاريخ","الكمية","الاتجاه"].map((p,i)=><th key={p}><input placeholder={"بحث "+p} value={movementFilters[i]} onChange={e=>setMovementFilters(v=>v.map((x,j)=>j===i?e.target.value:x))}/></th>)}</tr></thead><tbody>{filteredMovements.map(m=><tr key={m.id}><td><b>{m.documentId}</b></td><td>{m.documentKind==="purchase"?"شراء":"بيع"}</td><td>{m.item}</td><td>{m.party}</td><td>{m.date}</td><td>{fmt(m.qty)} {m.unit}</td><td><span className={m.direction==="in"?"treasury-status posted":"treasury-status draft"}>{m.direction==="in"?"وارد":"صادر"}</span></td></tr>)}</tbody></table></div>:<div className="operation-empty">لا توجد حركات مخزنية معتمدة محليًا بعد. احفظ مسودة بيع أو شراء ثم اعتمدها لتظهر حركاتها هنا.</div>}</div>}
  {kind!=="inventory"&&<div className="operation-history"><div className="operation-table-head"><div><b><FileText size={15}/> سجل المسودات المحفوظة</b><small>آخر خمس مسودات محفوظة على هذا المتصفح</small></div><span><Clock3 size={14}/> {recent.length} مستندات</span></div>{recent.length?<div className="table-wrap"><table><thead><tr><th>رقم المسودة</th><th>{kind==="sale"?"العميل":"المورد"}</th><th>التاريخ</th><th>البنود</th><th>الصافي</th><th>الحالة</th><th>اعتماد</th><th>استعادة</th><th>حذف</th></tr><tr className="column-filter-row">{["رقم المسودة",kind==="sale"?"العميل":"المورد","التاريخ","البنود","الصافي","الحالة"].map((p,i)=><th key={p}><input placeholder={"بحث "+p} value={documentFilters[i]} onChange={e=>setDocumentFilters(v=>v.map((x,j)=>j===i?e.target.value:x))}/></th>)}<th><span className="filter-disabled">—</span></th><th><span className="filter-disabled">—</span></th><th><span className="filter-disabled">—</span></th></tr></thead><tbody>{filteredRecent.map(d=><tr key={d.id}><td><b>{d.id}</b></td><td>{d.party}</td><td>{d.date}</td><td>{d.lines}</td><td className="operation-amount">{fmt(d.total)} ج.م</td><td><span className={d.status==="posted"?"treasury-status posted":"treasury-status draft"}>{d.status==="posted"?"معتمد محليًا":"مسودة"}</span></td><td>{d.status==="posted"?<span className="treasury-lock">تم إنشاء الحركة</span>:<button className="operation-add" onClick={()=>postDoc(d)}>اعتماد وحركة مخزون</button>}</td><td><button className="operation-add" onClick={()=>reopenDoc(d)} title="استعادة المسودة للتحرير">تحميل</button></td><td>{d.status==="posted"?<span className="treasury-lock">—</span>:<button className="remove-line" onClick={()=>removeDoc(d.id)} title="حذف المسودة المحلية"><Trash2 size={14}/></button>}</td></tr>)}</tbody></table></div>:<div className="operation-empty">لا توجد مسودات محفوظة حتى الآن.</div>}</div>}
  <div className="operation-disclaimer">البيانات محفوظة محليًا في المتصفح فقط. اعتماد البيع والشراء ينشئ سجل حركات مخزنية محليًا فقط؛ لا يتم تحديث رصيد فعلي أو ترحيل محاسبي، ولا يوجد اتصال بقاعدة بيانات الإنتاج.</div>
 </section>;
}
