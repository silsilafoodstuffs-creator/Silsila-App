import {useEffect,useMemo,useRef,useState} from "react";
import {AlertTriangle,ClipboardCheck,Plus,RefreshCw,Save,CheckCircle2,Package} from "lucide-react";
import {supabase} from "./supabase";
import EditDrawer from "./EditDrawer";

type Warehouse={id:string;warehouse_code:string;warehouse_name:string;branch_id:string|null};
type Item={id:string;item_code:string;item_name:string;base_unit:string};
type Unit={id:string;item_id:string;unit_name:string;conversion_factor:number;is_active:boolean;is_selectable:boolean};
type Stocktake={id:string;warehouse_id:string;status:string;count_mode:string;valuation_basis:string;source:string;created_at:string;notes:string|null};
type Line={id:string;item_id:string;warehouse_id:string;available_snapshot:number;reserved_snapshot:number;physical_snapshot:number;counted_quantity:number;variance_quantity:number;unit_id:string|null;conversion_factor:number;valuation_price:number;valuation_value:number};
type Employee={id:string;employee_code:string;full_name:string};
type Expense={id:string;item_code:string;name_ar:string};
const n=(v:any)=>Number.isFinite(Number(v))?Number(v):0;
const fmt=(v:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:3}).format(v);
const money=(v:number)=>new Intl.NumberFormat("ar-EG",{minimumFractionDigits:2,maximumFractionDigits:2}).format(v);

export default function LiveStocktakeWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const live=Boolean(supabase&&companyId);
 const [warehouses,setWarehouses]=useState<Warehouse[]>([]);
 const [items,setItems]=useState<Item[]>([]);
 const [units,setUnits]=useState<Unit[]>([]);
 const [employees,setEmployees]=useState<Employee[]>([]);
 const [expenses,setExpenses]=useState<Expense[]>([]);
 const [docs,setDocs]=useState<Stocktake[]>([]);
 const [warehouseId,setWarehouseId]=useState("");
 const [notes,setNotes]=useState("");
 const [selected,setSelected]=useState<Stocktake|null>(null);
 const [lines,setLines]=useState<Line[]>([]);
 const [counts,setCounts]=useState<Record<string,string>>({});
 const [initialCounts,setInitialCounts]=useState<Record<string,string>>({});
 const [targetType,setTargetType]=useState<"employee"|"expense">("employee");
 const [targetId,setTargetId]=useState("");
 const [loading,setLoading]=useState(live);
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState("");
 const [message,setMessage]=useState("");
 const [drawerOpen,setDrawerOpen]=useState(false);
 const postRequested=useRef(false);
 const itemMap=useMemo(()=>new Map(items.map(x=>[x.id,x])),[items]);
 const warehouseMap=useMemo(()=>new Map(warehouses.map(x=>[x.id,x])),[warehouses]);
 const unitMap=useMemo(()=>new Map(units.map(x=>[x.id,x])),[units]);
 const dirty=JSON.stringify(counts)!==JSON.stringify(initialCounts);
 const countPayload=()=>lines.map(line=>({line_id:line.id,counted_quantity:Number(counts[line.id]??"0")*(n(line.conversion_factor)||1)}));
 const deltas=lines.map(line=>({line,actual:n(counts[line.id]??"0")*(n(line.conversion_factor)||1),delta:n(counts[line.id]??"0")*(n(line.conversion_factor)||1)-n(line.physical_snapshot)}));
 const shortageValue=deltas.reduce((sum,x)=>sum+(x.delta<0?Math.abs(x.delta)*n(x.line.valuation_price):0),0);
 const varianceValue=deltas.reduce((sum,x)=>sum+Math.abs(x.delta)*n(x.line.valuation_price),0);
 const load=async()=>{
  if(!live||!supabase){setLoading(false);return;}
  setLoading(true);setError("");
  const [w,i,u,d,e,x]=await Promise.all([
   supabase.from("erp_warehouses").select("id,warehouse_code,warehouse_name,branch_id").eq("company_id",companyId).eq("is_active",true).order("warehouse_code"),
   supabase.from("erp_items").select("id,item_code,item_name,base_unit").eq("company_id",companyId).eq("is_active",true).order("item_code").range(0,1999),
   supabase.from("erp_item_units").select("id,item_id,unit_name,conversion_factor,is_active,is_selectable").eq("company_id",companyId).eq("is_active",true).eq("is_selectable",true),
   supabase.from("erp_stocktakes").select("id,warehouse_id,status,count_mode,valuation_basis,source,created_at,notes").eq("company_id",companyId).order("created_at",{ascending:false}).limit(100),
   supabase.from("erp_employees").select("id,employee_code,full_name").eq("company_id",companyId).eq("is_active",true).order("employee_code"),
   supabase.from("erp_stocktake_expense_items").select("id,item_code,name_ar").eq("company_id",companyId).eq("is_active",true).order("item_code")
  ]);
  const failure=w.error||i.error||u.error||d.error||e.error||x.error;
  if(failure){setError("تعذر تحميل بيانات الجرد: "+failure.message);setLoading(false);return;}
  setWarehouses((w.data||[]) as Warehouse[]);setItems((i.data||[]) as Item[]);setUnits((u.data||[]) as Unit[]);
  setDocs((d.data||[]) as Stocktake[]);setEmployees((e.data||[]) as Employee[]);setExpenses((x.data||[]) as Expense[]);
  setWarehouseId(old=>old&&w.data?.some(row=>row.id===old)?old:(w.data?.[0]?.id||""));
  setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live]);
 const loadLines=async(doc:Stocktake)=>{
  if(!supabase)return;
  setError("");setBusy(true);
  const {data,error}=await supabase.from("erp_stocktake_lines").select("id,item_id,warehouse_id,available_snapshot,reserved_snapshot,physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value").eq("stocktake_id",doc.id).order("created_at");
  setBusy(false);
  if(error){setError("تعذر تحميل بنود المحضر: "+error.message);setBusy(false);return;}
  const rows=(data||[]) as Line[];
  const initial:Record<string,string>={};
  for(const line of rows){const factor=n(line.conversion_factor)||1;initial[line.id]=(n(line.counted_quantity)/factor).toFixed(3);}
  setSelected(doc);setLines(rows);setCounts(initial);setInitialCounts(initial);setTargetId("");setDrawerOpen(true);
 };
 const createDoc=async()=>{
  if(!supabase||!warehouseId){setError("اختر المخزن أولًا.");return;}
  if(!items.length){setError("لا توجد أصناف نشطة في المنشأة لإنشاء محضر جرد.");return;}
  setBusy(true);setError("");setMessage("");
  const {data,error}=await supabase.rpc("erp_create_physical_stocktake",{p_company_id:companyId,p_warehouse_id:warehouseId,p_count_mode:"detailed",p_valuation_basis:null,p_notes:notes.trim()||null});
  setBusy(false);
  if(error){setError("تعذر إنشاء محضر الجرد: "+error.message);return;}
  const id=String(data);setNotes("");await load();
  const created:Stocktake={id,warehouse_id:warehouseId,status:"draft",count_mode:"detailed",valuation_basis:"",source:"stocktake",created_at:new Date().toISOString(),notes:null};
  const selectedWarehouse=warehouseMap.get(warehouseId);
  setMessage("تم إنشاء محضر جرد فعلي بمخزن "+(selectedWarehouse?selectedWarehouse.warehouse_name:"المخزن المحدد"));
  await loadLines(created);
 };
 const saveOrPost=async():Promise<boolean>=>{
  if(!supabase||!selected)return false;
  if(selected.status!=="draft"){setError("هذا المحضر مرحّل ولا يقبل التعديل.");return false;}
  if(!lines.length){setError("لا توجد بنود في محضر الجرد؛ لا يمكن حفظه أو ترحيله.");return false;}
  const payload=countPayload();
  if(payload.some(x=>!Number.isFinite(x.counted_quantity)||x.counted_quantity<0)){setError("الكميات المعدودة يجب أن تكون أرقامًا صحيحة ولا تقبل السالب.");return false;}
  setBusy(true);setError("");
  if(postRequested.current){
   if(shortageValue>0&&!targetId){setBusy(false);setError("يوجد عجز بقيمة "+money(shortageValue)+" ج.م؛ اختر الموظف أو بند الصرف لتوجيه العجز.");postRequested.current=false;return false;}
   const {data,error}=await supabase.rpc("erp_post_physical_stocktake_with_counts",{p_stocktake_id:selected.id,p_counts:payload,p_target_type:shortageValue>0?targetType:null,p_target_id:shortageValue>0?targetId:null});
   setBusy(false);postRequested.current=false;
   if(error){setError("تعذر ترحيل الجرد؛ لم تُحفظ الكميات أو الحركات جزئيًا: "+error.message);return false;}
   setMessage("تم حفظ الكميات وترحيل الجرد وحركات التسوية في معاملة واحدة. "+JSON.stringify(data));
   setDrawerOpen(false);setSelected(null);await load();return true;
  }
  const {error}=await supabase.rpc("erp_save_physical_stocktake_counts",{p_stocktake_id:selected.id,p_counts:payload});
  setBusy(false);
  if(error){setError("تعذر حفظ مسودة الجرد: "+error.message);return false;}
  setMessage("تم حفظ كميات المسودة دون تغيير أرصدة المخزون.");
  setInitialCounts({...counts});await load();return true;
 };
 const openDraft=(doc:Stocktake)=>void loadLines(doc);
 const currentTargets=targetType==="employee"?employees:expenses;
 return <section className="live-stocktake" dir="rtl">
  <div className="live-stocktake-head"><div className="live-stocktake-icon"><ClipboardCheck size={23}/></div><div><small>المخازن · محاضر الجرد والتسويات المعتمدة</small><h2>الجرد المخزني</h2><p>إنشاء لقطة رصيد، إدخال الكميات الفعلية، مراجعة الفروق، ثم الترحيل الذري لحركات التسوية.</p></div><span>{live?"بيانات المنشأة المباشرة":"يتطلب تسجيل الدخول"}</span></div>
  {!live&&<div className="live-stocktake-alert">سجّل الدخول إلى المنشأة لعرض محاضر الجرد الفعلية.</div>}
  {error&&<div className="live-stocktake-error">{error}</div>}{message&&<div className="live-stocktake-message">{message}</div>}
  {live&&<>
   <div className="live-stocktake-create"><label>المخزن<select value={warehouseId} onChange={e=>setWarehouseId(e.target.value)}>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_code} — {w.warehouse_name}</option>)}</select></label><label>ملاحظات المحضر<input value={notes} onChange={e=>setNotes(e.target.value)} placeholder="اختياري"/></label><button onClick={()=>void createDoc()} disabled={busy||!warehouseId}><Plus size={15}/> إنشاء محضر جرد</button></div>
   <div className="live-stocktake-list"><div className="live-stocktake-list-head"><b>محاضر الجرد</b><button onClick={()=>void load()} disabled={loading}><RefreshCw size={14}/> تحديث</button></div><div className="live-stocktake-table-wrap"><table><thead><tr><th>المخزن</th><th>المصدر</th><th>التاريخ</th><th>الحالة</th><th>الإجراء</th></tr></thead><tbody>{loading?<tr><td colSpan={5}>جارٍ تحميل المحاضر...</td></tr>:docs.filter(d=>d.source==="stocktake").map(doc=><tr key={doc.id}><td>{warehouseMap.get(doc.warehouse_id)?.warehouse_name||"—"}</td><td>جرد فعلي</td><td>{new Date(doc.created_at).toLocaleString("ar-EG")}</td><td><span className={doc.status==="posted"?"posted":"draft"}>{doc.status==="posted"?"مرحّل":doc.status==="draft"?"مسودة":doc.status}</span></td><td>{doc.status==="draft"?<button onClick={()=>openDraft(doc)}>فتح المحضر</button>:<span>تم الترحيل</span>}</td></tr>)}{!loading&&!docs.some(d=>d.source==="stocktake")&&<tr><td colSpan={5}>لا توجد محاضر جرد بعد.</td></tr>}</tbody></table></div></div>
  </>}
  {drawerOpen&&selected&&<EditDrawer title={"محضر جرد فعلي · "+selected.id.slice(0,8)} dirty={dirty} saving={busy} error={error} onSave={saveOrPost} onSaveError={()=>setBusy(false)} onDiscard={()=>{setCounts({...initialCounts});setError("");}} onClose={()=>{setDrawerOpen(false);setSelected(null);}}>
   <div className="live-stocktake-summary"><div><small>عدد الأصناف</small><b>{lines.length}</b></div><div><small>قيمة الفروق</small><b>{money(varianceValue)} ج.م</b></div><div><small>قيمة العجز</small><b>{money(shortageValue)} ج.م</b></div></div>
   <div className="live-stocktake-table-wrap"><table><thead><tr><th>كود الصنف</th><th>الصنف</th><th>رصيد النظام</th><th>الكمية الفعلية</th><th>الفرق</th><th>سعر التقييم</th></tr></thead><tbody>{lines.map(line=>{const item=itemMap.get(line.item_id),unit=unitMap.get(line.unit_id||""),factor=n(line.conversion_factor)||1,actual=n(counts[line.id]??"0")*factor,delta=actual-n(line.physical_snapshot);return <tr key={line.id}><td>{item?.item_code||"—"}</td><td>{item?.item_name||"—"}<small>{unit?.unit_name||item?.base_unit||"وحدة"}</small></td><td>{fmt(n(line.physical_snapshot)/factor)}</td><td><input type="number" min="0" step="0.001" value={counts[line.id]??"0"} disabled={selected.status!=="draft"} onChange={e=>setCounts(v=>({...v,[line.id]:e.target.value}))}/></td><td className={delta<0?"shortage":delta>0?"increase":""}>{fmt(delta/factor)}</td><td>{money(n(line.valuation_price))} ج.م</td></tr>})}{!lines.length&&<tr><td colSpan={6}>لا توجد بنود في هذا المحضر.</td></tr>}</tbody></table></div>
   {shortageValue>0&&selected.status==="draft"&&<div className="live-stocktake-target"><label>توجيه قيمة العجز<select value={targetType} onChange={e=>{setTargetType(e.target.value as "employee"|"expense");setTargetId("");}}><option value="employee">موظف</option><option value="expense">بند صرف</option></select></label><label>الجهة المسؤولة<select value={targetId} onChange={e=>setTargetId(e.target.value)}><option value="">اختر الجهة</option>{currentTargets.map((x:any)=><option key={x.id} value={x.id}>{targetType==="employee"?x.employee_code+" — "+x.full_name:x.item_code+" — "+x.name_ar}</option>)}</select></label></div>}
   <div className="live-stocktake-drawer-actions"><button disabled={busy||selected.status!=="draft"} onClick={()=>{postRequested.current=false;window.dispatchEvent(new Event("silsila:edit-save"));}}><Save size={14}/> حفظ المسودة</button><button disabled={busy||selected.status!=="draft"} onClick={()=>{postRequested.current=true;window.dispatchEvent(new Event("silsila:edit-save"));}}><CheckCircle2 size={14}/> حفظ وترحيل الجرد</button></div>
  </EditDrawer>}
  <div className="live-stocktake-note"><AlertTriangle size={15}/> لا يتم تعديل دفتر المخزون مباشرة. الترحيل يستخدم الإجراء الذري المعتمد الذي يعيد فحص لقطة الرصيد وصلاحيات المخزن ويمنع الترحيل إذا تغيرت حركة الصنف بعد إنشاء المحضر.</div>
 </section>;
}
