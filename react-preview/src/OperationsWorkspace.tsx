import { useMemo, useState } from "react";
import { Plus, Trash2, Save, RotateCcw, Package, ShoppingCart, ShoppingBag, CheckCircle2 } from "lucide-react";

type Line = { id:number; name:string; unit:string; qty:number; price:number };
const seed:Line[] = [
 {id:1,name:"أرز مصري فاخر 1 كجم",unit:"كرتونة",qty:2,price:720},
 {id:2,name:"سكر أبيض 1 كجم",unit:"كرتونة",qty:1,price:650},
];
const fmt=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
export default function OperationsWorkspace({kind}:{kind:"sale"|"purchase"|"inventory"}){
 const [lines,setLines]=useState<Line[]>(seed);
 const [party,setParty]=useState(kind==="sale"?"مؤسسة النور التجارية":"شركة الأمل للتوريدات");
 const [discount,setDiscount]=useState(0);
 const [tax,setTax]=useState(14);
 const [saved,setSaved]=useState(false);
 const [nextId,setNextId]=useState(3);
 const subtotal=useMemo(()=>lines.reduce((s,l)=>s+l.qty*l.price,0),[lines]);
 const discountValue=Math.min(subtotal,Math.max(0,discount));
 const taxValue=(subtotal-discountValue)*Math.max(0,tax)/100;
 const total=subtotal-discountValue+taxValue;
 const title=kind==="sale"?"فاتورة بيع جديدة":kind==="purchase"?"فاتورة شراء جديدة":"إدارة الأصناف والمخزون";
 const Icon=kind==="sale"?ShoppingCart:kind==="purchase"?ShoppingBag:Package;
 const update=(id:number,key:"name"|"unit"|"qty"|"price",value:string)=>{
  setLines(old=>old.map(l=>l.id===id?{...l,[key]:key==="qty"||key==="price"?Math.max(0,Number(value)||0):value}:l));setSaved(false);
 };
 const add=()=>{setLines(old=>[...old,{id:nextId,name:"صنف جديد",unit:"كرتونة",qty:1,price:0}]);setNextId(n=>n+1);setSaved(false)};
 const reset=()=>{setLines(kind==="inventory"?[]:seed);setDiscount(0);setTax(14);setSaved(false)};
 return <section className="operation-workspace" dir="rtl">
  <div className="operation-heading"><div className="operation-title"><span className="operation-icon"><Icon size={22}/></span><div><small>مساحة تشغيل تفاعلية · بيانات تجريبية</small><h2>{title}</h2><p>{kind==="sale"?"أدخل بيانات العميل والأصناف واحسب إجمالي الفاتورة مباشرة.":kind==="purchase"?"سجّل المورد والأصناف الواردة وتابع قيمة التوريد.":"أضف الأصناف وعدّل أرصدتها وأسعارها داخل المعاينة."}</p></div></div><span className="demo-pill">معاينة فقط — لا يؤثر على الإنتاج</span></div>
  {kind!=="inventory"&&<div className="operation-form-grid"><label><span>{kind==="sale"?"العميل":"المورد"}</span><input value={party} onChange={e=>setParty(e.target.value)} placeholder="اكتب الاسم"/></label><label><span>رقم المستند</span><input value={kind==="sale"?"SAL-DRAFT-001":"PUR-DRAFT-001"} readOnly/></label><label><span>تاريخ المستند</span><input type="date" defaultValue="2026-11-25"/></label><label><span>طريقة السداد</span><select defaultValue="نقدي"><option>نقدي</option><option>آجل</option><option>تحويل بنكي</option></select></label></div>}
  <div className="operation-table-card"><div className="operation-table-head"><div><b>{kind==="inventory"?"قائمة الأصناف":"أصناف المستند"}</b><small>{lines.length} بند — يمكنك تعديل الكميات والأسعار</small></div><button className="operation-add" onClick={add}><Plus size={16}/> إضافة صنف</button></div><div className="operation-table-scroll"><table><thead><tr><th>الصنف</th><th>الوحدة</th><th>الكمية</th><th>{kind==="inventory"?"سعر البيع":"سعر الوحدة"}</th><th>{kind==="inventory"?"قيمة الرصيد":"الإجمالي"}</th><th></th></tr></thead><tbody>{lines.map(l=><tr key={l.id}><td><input className="cell-input item-name" value={l.name} onChange={e=>update(l.id,"name",e.target.value)}/></td><td><select className="cell-input" value={l.unit} onChange={e=>update(l.id,"unit",e.target.value)}><option>كرتونة</option><option>وحدة</option><option>كيلو</option><option>عبوة</option></select></td><td><input className="cell-input number-input" type="number" min="0" value={l.qty} onChange={e=>update(l.id,"qty",e.target.value)}/></td><td><input className="cell-input number-input" type="number" min="0" value={l.price} onChange={e=>update(l.id,"price",e.target.value)}/></td><td className="operation-amount">{fmt(l.qty*l.price)} ج.م</td><td><button className="remove-line" title="حذف الصنف" onClick={()=>setLines(old=>old.filter(x=>x.id!==l.id))}><Trash2 size={15}/></button></td></tr>)}</tbody></table>{lines.length===0&&<div className="operation-empty">لا توجد أصناف بعد. اضغط «إضافة صنف» للبدء.</div>}</div></div>
  {kind!=="inventory"&&<div className="operation-bottom"><div className="operation-notes"><label>ملاحظات المستند<textarea placeholder="أضف أي ملاحظات..." rows={3}/></label><div className="operation-tax"><label><span>الخصم (ج.م)</span><input type="number" min="0" value={discount} onChange={e=>setDiscount(Number(e.target.value)||0)}/></label><label><span>الضريبة (%)</span><input type="number" min="0" value={tax} onChange={e=>setTax(Number(e.target.value)||0)}/></label></div></div><div className="operation-totals"><div><span>الإجمالي قبل الخصم</span><b>{fmt(subtotal)} ج.م</b></div><div><span>الخصم</span><b>{fmt(discountValue)} ج.م</b></div><div><span>الضريبة</span><b>{fmt(taxValue)} ج.م</b></div><div className="grand-total"><span>صافي الفاتورة</span><strong>{fmt(total)} <small>ج.م</small></strong></div></div></div>}
  {kind==="inventory"&&<div className="inventory-summary"><div><span>عدد الأصناف المعروضة</span><b>{lines.length}</b></div><div><span>إجمالي قيمة الرصيد التجريبي</span><b>{fmt(subtotal)} ج.م</b></div><div><span>تنبيه</span><b>الأرصدة غير مرتبطة بالمخازن الفعلية</b></div></div>}
  <div className="operation-actions"><button className="operation-save" onClick={()=>setSaved(true)}><Save size={16}/> {kind==="inventory"?"حفظ التعديلات التجريبية":"حفظ مسودة تجريبية"}</button><button className="operation-reset" onClick={reset}><RotateCcw size={15}/> إعادة ضبط</button>{saved&&<span className="saved-feedback"><CheckCircle2 size={16}/> تم الحفظ داخل جلسة المعاينة فقط</span>}</div>
 </section>
}