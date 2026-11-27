import { useEffect,useMemo,useState } from "react";
import { AlertTriangle,ArrowLeftRight,Boxes,ChevronLeft,ChevronRight,Clock3,Package,RefreshCw,Search,Truck } from "lucide-react";
import { supabase } from "./supabase";
import EditDrawer from "./EditDrawer";

type Warehouse={id:string;warehouse_code:string;warehouse_name:string;branch_id:string};
type Item={id:string;item_code:string;item_name:string;base_unit:string;purchase_price:number;sale_price:number};
type Balance={company_id:string;branch_id:string;warehouse_id:string;item_id:string;quantity_on_hand:number;today_quantity_in:number;today_quantity_out:number;last_movement_at:string|null;inventory_value:number;average_unit_cost:number};
type Reservation={warehouse_id:string;item_id:string;quantity_base:number;status:string};
type Movement={id:string;movement_date:string;movement_type:string;warehouse_id:string;item_id:string;quantity_in:number;quantity_out:number;unit_cost:number;notes:string|null;batch_number:string|null};
type TransferForm={itemId:string;sourceId:string;targetId:string;quantity:string;notes:string};
const PAGE_SIZE=100;
const fmt=(value:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:3}).format(Number(value)||0);
const money=(value:number)=>new Intl.NumberFormat("ar-EG",{minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(value)||0);
const emptyTransfer:TransferForm={itemId:"",sourceId:"",targetId:"",quantity:"1",notes:""};

export default function LiveInventoryWorkspace({mode="balances"}:{mode?:"balances"|"transfers"}){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const live=Boolean(supabase&&companyId);
 const [warehouses,setWarehouses]=useState<Warehouse[]>([]);
 const [items,setItems]=useState<Item[]>([]);
 const [balances,setBalances]=useState<Balance[]>([]);
 const [reservations,setReservations]=useState<Reservation[]>([]);
 const [movements,setMovements]=useState<Movement[]>([]);
 const [loading,setLoading]=useState(live);
 const [busy,setBusy]=useState(false);
 const [message,setMessage]=useState("");
 const [query,setQuery]=useState("");
 const [warehouseFilter,setWarehouseFilter]=useState("all");
 const [page,setPage]=useState(0);
 const [total,setTotal]=useState(0);
 const [historyOpen,setHistoryOpen]=useState(false);
 const [drawerOpen,setDrawerOpen]=useState(false);
 const [transfer,setTransfer]=useState<TransferForm>(emptyTransfer);
 const [initialTransfer,setInitialTransfer]=useState<TransferForm>(emptyTransfer);
 const [transferError,setTransferError]=useState("");
 const [movementPage,setMovementPage]=useState(0);
 const [movementTotal,setMovementTotal]=useState(0);
 const [movementQuery,setMovementQuery]=useState("");

 const load=async()=>{
  if(!live||!supabase){setLoading(false);return;}
  setLoading(true);setMessage("");
  const from=page*PAGE_SIZE,to=from+PAGE_SIZE-1;
  const [wh,it,bal,res,mov]=await Promise.all([
   supabase.from("erp_warehouses").select("id,warehouse_code,warehouse_name,branch_id").eq("company_id",companyId).eq("is_active",true).order("warehouse_name"),
   supabase.from("erp_items").select("id,item_code,item_name,base_unit,purchase_price,sale_price").eq("company_id",companyId).eq("is_active",true).order("item_name").range(0,1999),
   supabase.from("erp_stock_balances").select("company_id,branch_id,warehouse_id,item_id,quantity_on_hand,today_quantity_in,today_quantity_out,last_movement_at,inventory_value,average_unit_cost",{count:"exact"}).eq("company_id",companyId).order("last_movement_at",{ascending:false}).range(from,to),
   supabase.from("erp_stock_reservations").select("warehouse_id,item_id,quantity_base,status").eq("company_id",companyId).eq("status","active"),
   supabase.from("erp_inventory_movements").select("id,movement_date,movement_type,warehouse_id,item_id,quantity_in,quantity_out,unit_cost,notes,batch_number",{count:"exact"}).eq("company_id",companyId).order("movement_date",{ascending:false}).range(movementPage*PAGE_SIZE,movementPage*PAGE_SIZE+PAGE_SIZE-1)
  ]);
  const error=wh.error||it.error||bal.error||res.error||mov.error;
  if(error){setMessage("تعذر تحميل دفتر المخزون من قاعدة البيانات: "+error.message);setLoading(false);return;}
  setWarehouses((wh.data||[]) as Warehouse[]);setItems((it.data||[]) as Item[]);
  setBalances((bal.data||[]) as Balance[]);setReservations((res.data||[]) as Reservation[]);
  setMovements((mov.data||[]) as Movement[]);setTotal(bal.count||0);setMovementTotal(mov.count||0);setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,live,page,movementPage]);
 const warehouseMap=useMemo(()=>new Map(warehouses.map(x=>[x.id,x])),[warehouses]);
 const itemMap=useMemo(()=>new Map(items.map(x=>[x.id,x])),[items]);
 const reservedFor=(warehouseId:string,itemId:string)=>reservations.filter(x=>x.warehouse_id===warehouseId&&x.item_id===itemId).reduce((sum,x)=>sum+Number(x.quantity_base||0),0);
 const filtered=balances.filter(row=>{
  const item=itemMap.get(row.item_id),wh=warehouseMap.get(row.warehouse_id);
  const text=[item?.item_code,item?.item_name,item?.base_unit,wh?.warehouse_code,wh?.warehouse_name].join(" ").toLocaleLowerCase();
  return (warehouseFilter==="all"||row.warehouse_id===warehouseFilter)&&text.includes(query.toLocaleLowerCase());
 });
 const pageValue=balances.reduce((sum,row)=>sum+Number(row.inventory_value||0),0);
 const pageQuantity=balances.reduce((sum,row)=>sum+Number(row.quantity_on_hand||0),0);
 const currentItem=items.find(x=>x.id===transfer.itemId);
 const sourceBalance=balances.find(x=>x.item_id===transfer.itemId&&x.warehouse_id===transfer.sourceId);
 const currentReserved=transfer.itemId&&transfer.sourceId?reservedFor(transfer.sourceId,transfer.itemId):0;
 const available=Math.max(0,Number(sourceBalance?.quantity_on_hand||0)-currentReserved);
 const dirty=JSON.stringify(transfer)!==JSON.stringify(initialTransfer);
 const openTransfer=()=>{
  const next={...emptyTransfer,sourceId:warehouses[0]?.id||"",targetId:warehouses[1]?.id||""};
  setTransfer(next);setInitialTransfer(next);setTransferError("");setDrawerOpen(true);
 };
 const closeTransfer=()=>{setDrawerOpen(false);setTransfer(emptyTransfer);setInitialTransfer(emptyTransfer);setTransferError("");};
 const saveTransfer=async():Promise<boolean>=>{
  if(!supabase||!companyId){setTransferError("اتصال قاعدة البيانات غير متاح.");return false;}
  const qty=Number(transfer.quantity);
  if(!transfer.itemId||!transfer.sourceId||!transfer.targetId||!Number.isFinite(qty)||qty<=0){setTransferError("أكمل الصنف والمخزنين والكمية الصحيحة.");return false;}
  if(transfer.sourceId===transfer.targetId){setTransferError("يجب اختيار مخزنين مختلفين.");return false;}
  setBusy(true);setTransferError("");setMessage("");
  const [freshBalance,freshReservations]=await Promise.all([
   supabase.from("erp_stock_balances").select("quantity_on_hand,average_unit_cost").eq("company_id",companyId).eq("warehouse_id",transfer.sourceId).eq("item_id",transfer.itemId).maybeSingle(),
   supabase.from("erp_stock_reservations").select("quantity_base").eq("company_id",companyId).eq("warehouse_id",transfer.sourceId).eq("item_id",transfer.itemId).eq("status","active")
  ]);
  if(freshBalance.error||freshReservations.error){setBusy(false);setTransferError("تعذر التحقق من الرصيد الفعلي والحجوزات قبل التحويل: "+(freshBalance.error||freshReservations.error)?.message);return false;}
  const actualOnHand=Number(freshBalance.data?.quantity_on_hand||0);
  const actualReserved=(freshReservations.data||[]).reduce((sum,row)=>sum+Number(row.quantity_base||0),0);
  const actualAvailable=Math.max(0,actualOnHand-actualReserved);
  if(qty>actualAvailable){setBusy(false);setTransferError("الكمية المطلوبة أكبر من الرصيد المتاح بعد استبعاد الحجوزات: "+fmt(actualAvailable)+" "+(currentItem?.base_unit||"وحدة"));return false;}
  const {data,error}=await supabase.rpc("erp_transfer_inventory_between_warehouses",{
   p_company_id:companyId,p_source_warehouse_id:transfer.sourceId,p_target_warehouse_id:transfer.targetId,
   p_item_id:transfer.itemId,p_quantity:qty,p_unit_cost:Number(freshBalance.data?.average_unit_cost||currentItem?.purchase_price||0),
   p_transfer_date:new Date().toISOString(),p_batch_number:null,p_expiry_date:null,p_notes:transfer.notes.trim()||null
  });
  setBusy(false);
  if(error){setTransferError("لم يتم تسجيل التحويل: "+error.message);return false;}
  setMessage("تم تسجيل التحويل المخزني المزدوج بنجاح. رقم العملية: "+String(data||"—"));
  await load();return true;
 };
 const visibleMovements=movements.filter(row=>{
  const item=itemMap.get(row.item_id),wh=warehouseMap.get(row.warehouse_id);
  return [item?.item_code,item?.item_name,wh?.warehouse_name,row.movement_type,row.notes,row.batch_number].join(" ").toLocaleLowerCase().includes(movementQuery.toLocaleLowerCase());
 });
 const movementLabels:Record<string,string>={opening:"رصيد افتتاحي",purchase_receipt:"استلام مشتريات",sales_issue:"صرف مبيعات",customer_return:"مرتجع عميل",supplier_return:"مرتجع مورد",transfer_in:"تحويل وارد",transfer_out:"تحويل صادر",adjustment:"تسوية مخزنية",waste:"هالك"};
 return <section className="live-inventory" dir="rtl">
  <div className="live-inventory-hero"><div className="live-inventory-mark"><Boxes size={24}/></div><div><small>المخازن · دفتر المخزون الفعلي</small><h2>{mode==="transfers"?"التحويلات المخزنية":"أرصدة المخزون"}</h2><p>الأرصدة والتكلفة والحركات تُقرأ مباشرة من دفتر الحركات المعتمد في قاعدة سلسلة.</p></div><span className="live-inventory-status">{live?"متصل بقاعدة البيانات":"يتطلب تسجيل الدخول"}</span></div>
  {!live&&<div className="live-inventory-alert">سجّل الدخول إلى المنشأة لعرض أرصدة المخزون الفعلية.</div>}
  {message&&<div className="live-inventory-message">{message}</div>}
  {live&&<>
   <div className="live-inventory-kpis"><article><small>سجلات الأرصدة في الصفحة</small><strong>{fmt(filtered.length)} / {fmt(total)}</strong></article><article><small>كمية الصفحة الحالية</small><strong>{fmt(pageQuantity)}</strong></article><article><small>قيمة المخزون في الصفحة</small><strong>{money(pageValue)} ج.م</strong></article><article><small>الحركات المسجلة</small><strong>{fmt(movementTotal)}</strong></article></div>
   <div className="live-inventory-panel">
    <div className="live-inventory-toolbar"><div><b><Package size={17}/> {mode==="transfers"?"الأرصدة المتاحة للتحويل":"أرصدة حسب الصنف والمخزن"}</b><small>الكمية والقيمة ومتوسط التكلفة من دفتر الحركات</small></div><div className="live-inventory-actions"><button onClick={openTransfer} disabled={warehouses.length<2||!items.length}><ArrowLeftRight size={15}/> تحويل مخزني</button><button onClick={()=>void load()} disabled={loading}><RefreshCw size={15}/> تحديث</button></div></div>
    <div className="live-inventory-filters"><label><Search size={15}/><input value={query} onChange={e=>{setQuery(e.target.value);setPage(0);}} placeholder="بحث بكود الصنف أو الاسم أو المخزن"/></label><select value={warehouseFilter} onChange={e=>{setWarehouseFilter(e.target.value);setPage(0);}}><option value="all">كل المخازن</option>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_code} — {w.warehouse_name}</option>)}</select></div>
    <div className="live-inventory-table-wrap"><table><thead><tr><th>كود الصنف</th><th>الصنف</th><th>المخزن</th><th>الوحدة الأساسية</th><th>الرصيد الفعلي</th><th>المحجوز</th><th>المتاح</th><th>متوسط التكلفة</th><th>قيمة المخزون</th><th>آخر حركة</th></tr></thead><tbody>
    {loading?<tr><td colSpan={10} className="live-inventory-empty">جارٍ تحميل البيانات الفعلية...</td></tr>:filtered.map(row=>{const item=itemMap.get(row.item_id),wh=warehouseMap.get(row.warehouse_id),reserved=reservedFor(row.warehouse_id,row.item_id);return <tr key={row.warehouse_id+row.item_id}><td>{item?.item_code||"—"}</td><td><b>{item?.item_name||"صنف غير معروف"}</b></td><td>{wh?.warehouse_name||"مخزن غير معروف"}</td><td>{item?.base_unit||"—"}</td><td>{fmt(row.quantity_on_hand)}</td><td>{fmt(reserved)}</td><td className="live-inventory-available">{fmt(Math.max(0,Number(row.quantity_on_hand)-reserved))}</td><td>{money(row.average_unit_cost)} ج.م</td><td>{money(row.inventory_value)} ج.م</td><td>{row.last_movement_at?new Date(row.last_movement_at).toLocaleString("ar-EG"):"—"}</td></tr>})}
    {!loading&&!filtered.length&&<tr><td colSpan={10} className="live-inventory-empty">لا توجد أرصدة مطابقة في قاعدة البيانات.</td></tr>}
    </tbody></table></div>
    <div className="live-inventory-pagination"><span>عرض {total?Math.min(page*PAGE_SIZE+1,total):0}–{Math.min((page+1)*PAGE_SIZE,total)} من {total}</span><div><button disabled={page===0||loading} onClick={()=>setPage(x=>Math.max(0,x-1))}><ChevronRight size={16}/> السابق</button><button disabled={(page+1)*PAGE_SIZE>=total||loading} onClick={()=>setPage(x=>x+1)}>التالي <ChevronLeft size={16}/></button></div></div>
   </div>
   <div className="live-inventory-panel">
    <div className="live-inventory-toolbar"><div><b><Clock3 size={17}/> سجل حركات المخزون</b><small>حركات معتمدة فقط؛ لا توجد كتابة مباشرة على دفتر الحركات</small></div><button onClick={()=>setHistoryOpen(v=>!v)}>{historyOpen?"إخفاء الحركات":"عرض الحركات"}</button></div>
    {historyOpen&&<><div className="live-inventory-filters"><label><Search size={15}/><input value={movementQuery} onChange={e=>setMovementQuery(e.target.value)} placeholder="بحث في نوع الحركة أو الصنف أو المخزن"/></label></div><div className="live-inventory-table-wrap"><table><thead><tr><th>التاريخ</th><th>نوع الحركة</th><th>الصنف</th><th>المخزن</th><th>وارد</th><th>صادر</th><th>تكلفة الوحدة</th><th>البيان</th><th>التشغيلة</th></tr></thead><tbody>{visibleMovements.map(m=><tr key={m.id}><td>{new Date(m.movement_date).toLocaleString("ar-EG")}</td><td>{movementLabels[m.movement_type]||m.movement_type}</td><td>{itemMap.get(m.item_id)?.item_name||"—"}</td><td>{warehouseMap.get(m.warehouse_id)?.warehouse_name||"—"}</td><td>{fmt(m.quantity_in)}</td><td>{fmt(m.quantity_out)}</td><td>{money(m.unit_cost)}</td><td>{m.notes||"—"}</td><td>{m.batch_number||"—"}</td></tr>)}{!visibleMovements.length&&<tr><td colSpan={9} className="live-inventory-empty">لا توجد حركات مطابقة.</td></tr>}</tbody></table></div><div className="live-inventory-pagination"><span>صفحة {movementPage+1} · {movementTotal} حركة</span><div><button disabled={movementPage===0} onClick={()=>setMovementPage(x=>Math.max(0,x-1))}>السابق</button><button disabled={(movementPage+1)*PAGE_SIZE>=movementTotal} onClick={()=>setMovementPage(x=>x+1)}>التالي</button></div></div></>}
   </div>
   <div className="live-inventory-note"><AlertTriangle size={16}/> التسويات والجرد تُرحّل عبر دورة الجرد المعتمدة فقط؛ لم نربط تعديلًا مباشرًا للأرصدة حتى لا يتم تجاوز مراجعة العجز والتكلفة والصلاحيات.</div>
  </>}
  {drawerOpen&&<EditDrawer title="تحويل مخزني بين مخزنين" dirty={dirty} saving={busy} error={transferError} onSave={saveTransfer} onDiscard={()=>{setTransfer(initialTransfer);setTransferError("");}} onClose={closeTransfer}>
   <div className="live-inventory-drawer-form">
    <label>الصنف<select value={transfer.itemId} onChange={e=>setTransfer(v=>({...v,itemId:e.target.value}))}><option value="">اختر الصنف</option>{items.map(i=><option key={i.id} value={i.id}>{i.item_code} — {i.item_name}</option>)}</select></label>
    <label>مخزن الصرف<select value={transfer.sourceId} onChange={e=>setTransfer(v=>({...v,sourceId:e.target.value}))}><option value="">اختر مخزن الصرف</option>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_name}</option>)}</select></label>
    <label>مخزن الاستلام<select value={transfer.targetId} onChange={e=>setTransfer(v=>({...v,targetId:e.target.value}))}><option value="">اختر مخزن الاستلام</option>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_name}</option>)}</select></label>
    <label>الكمية المراد تحويلها<input type="number" min="0.001" step="0.001" value={transfer.quantity} onChange={e=>setTransfer(v=>({...v,quantity:e.target.value}))}/></label>
    <label>ملاحظات التحويل<textarea rows={3} value={transfer.notes} onChange={e=>setTransfer(v=>({...v,notes:e.target.value}))}/></label>
    <div className="live-inventory-availability"><span>الرصيد المتاح في مخزن الصرف</span><b>{fmt(available)} {currentItem?.base_unit||""}</b></div>
    {currentReserved>0&&<div className="live-inventory-alert">يوجد {fmt(currentReserved)} وحدة محجوزة؛ لا يسمح هذا النموذج بتحويل الصنف حتى تحرير الحجز.</div>}
   </div>
  </EditDrawer>}
 </section>;
}
