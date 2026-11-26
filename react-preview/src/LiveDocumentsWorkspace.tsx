import { Fragment,useEffect,useMemo,useState } from "react";
import { CheckCircle2,Eye,FileText,Package,Plus,RefreshCw,RotateCcw,Save,ShoppingCart,ShoppingBag,Trash2 } from "lucide-react";
import { supabase } from "./supabase";

type Kind="sale"|"purchase";
type Item={id:string;item_code:string;item_name:string;base_unit:string;purchase_price:number;sale_price:number;tax_rate:number};
type Unit={id:string;item_id:string;unit_code:string;unit_name:string;conversion_factor:number;is_base_unit:boolean;is_selectable:boolean};
type Party={id:string;party_code:string;party_name:string;party_kind:string};
type Wh={id:string;warehouse_code:string;warehouse_name:string;branch_id:string;branchName:string};
type Line={id:string;itemId:string;unitId:string;qty:string;price:string;discount:string};
type Doc={id:string;document_number:string;document_date:string;document_type:string;status:string;subtotal:number;discount_total:number;tax_total:number;grand_total:number;customer_id?:string;supplier_id?:string;warehouse_id:string;branch_id:string;notes?:string;created_at:string};
type Balance={warehouse_id:string;item_id:string;quantity_on_hand:number;average_unit_cost:number};
type Reservation={warehouse_id:string;item_id:string;quantity_base:number;status:string};
type DocLine={id:string;item_id:string;quantity:number;unit_price:number;discount_amount:number;tax_amount:number;line_total:number;unit_code:string|null;conversion_factor:number;base_quantity:number;batch_number:string|null;expiry_date:string|null;item_code?:string;item_name?:string;base_unit?:string};
const money=(n:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(n);
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-");};
const round2=(n:number)=>Math.round((n+Number.EPSILON)*100)/100;
const blankLine=():Line=>({id:crypto.randomUUID(),itemId:"",unitId:"",qty:"1",price:"0",discount:"0"});

export default function LiveDocumentsWorkspace({kind}:{kind:Kind}){
 const companyId=sessionStorage.getItem("silsila-company-id")||"";
 const userId=sessionStorage.getItem("silsila-user-id")||"";
 const role=sessionStorage.getItem("silsila-member-role")||"viewer";
 const live=Boolean(supabase&&companyId&&userId);
 const canCreate=["owner","admin"].includes(role);
 const [items,setItems]=useState<Item[]>([]);
 const [units,setUnits]=useState<Unit[]>([]);
 const [parties,setParties]=useState<Party[]>([]);
 const [warehouses,setWarehouses]=useState<Wh[]>([]);
 const [balances,setBalances]=useState<Balance[]>([]);
 const [reservations,setReservations]=useState<Reservation[]>([]);
 const [docs,setDocs]=useState<Doc[]>([]);
 const [docPage,setDocPage]=useState(0);
 const [docTotal,setDocTotal]=useState(0);
 const DOC_PAGE_SIZE=50;
 const [journalIds,setJournalIds]=useState<Record<string,string>>({});
 const [expandedDocId,setExpandedDocId]=useState("");
 const [detailRows,setDetailRows]=useState<Record<string,DocLine[]>>({});
 const [detailLoadingId,setDetailLoadingId]=useState("");
 const [detailErrors,setDetailErrors]=useState<Record<string,string>>({});
 const [warehouseId,setWarehouseId]=useState("");
 const [partyId,setPartyId]=useState("");
 const [date,setDate]=useState(today());
 const [notes,setNotes]=useState("");
 const [lines,setLines]=useState<Line[]>([blankLine()]);
 const [loading,setLoading]=useState(live);
 const [saving,setSaving]=useState(false);
 const [message,setMessage]=useState("");
 const [query,setQuery]=useState(""); const [docColumnFilters,setDocColumnFilters]=useState<Record<string,string>>({});
 const partyKind=kind==="sale"?"customer":"supplier";
 const docTable=kind==="sale"?"erp_sales_documents":"erp_purchase_documents";
 const title=kind==="sale"?"إذن تسليم مبيعات":"إذن استلام مشتريات";
 const Icon=kind==="sale"?ShoppingCart:ShoppingBag;
 const partyOptions=parties.filter(p=>p.party_kind===partyKind||p.party_kind==="both");
 const selectedWarehouse=warehouses.find(w=>w.id===warehouseId);
 const selectedParty=partyOptions.find(p=>p.id===partyId);
 const selectedItems=lines.map(l=>items.find(i=>i.id===l.itemId));
 const lineTotals=lines.map((l,index)=>{
  const item=selectedItems[index];
  const unit=units.find(u=>u.id===l.unitId);
  const qty=Math.max(0,Number(l.qty)||0),price=Math.max(0,Number(l.price)||0),discount=Math.max(0,Number(l.discount)||0);
  const base=round2(qty*price),disc=Math.min(base,discount),tax=round2((base-disc)*Math.max(0,Number(item?.tax_rate)||0)/100);
  return {base,discount:disc,tax,total:round2(base-disc+tax),baseQty:qty*(Number(unit?.conversion_factor)||1),unitName:unit?.unit_name||unit?.unit_code||item?.base_unit||"وحدة"};
 });
 const subtotal=round2(lineTotals.reduce((s,l)=>s+l.base,0));
 const discountTotal=round2(lineTotals.reduce((s,l)=>s+l.discount,0));
 const taxTotal=round2(lineTotals.reduce((s,l)=>s+l.tax,0));
 const grandTotal=round2(lineTotals.reduce((s,l)=>s+l.total,0));
 const loadData=async(showSpinner=true)=>{
  if(!live||!supabase){setLoading(false);return;}
  if(showSpinner)setLoading(true);
  const [br,wh,it,un,pa,bal,res,documents,journals]=await Promise.all([
   supabase.from("erp_branches").select("id,branch_name").eq("company_id",companyId).eq("is_active",true),
   supabase.from("erp_warehouses").select("id,warehouse_code,warehouse_name,branch_id").eq("company_id",companyId).eq("is_active",true).order("warehouse_code"),
   supabase.from("erp_items").select("id,item_code,item_name,base_unit,purchase_price,sale_price,tax_rate").eq("company_id",companyId).eq("is_active",true).order("item_code"),
   supabase.from("erp_item_units").select("id,item_id,unit_code,unit_name,conversion_factor,is_base_unit,is_selectable").eq("company_id",companyId).eq("is_active",true).eq("is_selectable",true).order("conversion_factor"),
   supabase.from("erp_parties").select("id,party_code,party_name,party_kind").eq("company_id",companyId).eq("is_active",true).order("party_name"),
   supabase.from("erp_stock_balances").select("warehouse_id,item_id,quantity_on_hand,average_unit_cost").eq("company_id",companyId),
   supabase.from("erp_stock_reservations").select("warehouse_id,item_id,quantity_base,status").eq("company_id",companyId).eq("status","active"),
   supabase.from(docTable).select("id,document_number,document_date,document_type,status,subtotal,discount_total,tax_total,grand_total,customer_id,supplier_id,warehouse_id,branch_id,notes,created_at",{count:"exact"}).eq("company_id",companyId).order("created_at",{ascending:false}).range(docPage*DOC_PAGE_SIZE,(docPage+1)*DOC_PAGE_SIZE-1),
   supabase.from("erp_journal_entries").select("id,source_id,source_type,status").eq("company_id",companyId).eq("source_type",kind==="sale"?"sales_accounting":"purchase_accounting").eq("status","posted").limit(500)
  ]);
  const error=br.error||wh.error||it.error||un.error||pa.error||bal.error||res.error||documents.error||journals.error;
  if(error){setMessage("تعذر تحميل بيانات التشغيل: "+error.message);setLoading(false);return;}
  const branchMap=new Map<string,string>((br.data||[]).map((b:any)=>[b.id,b.branch_name]));
  const warehouseRows=(wh.data||[]).map((w:any)=>({...w,branchName:branchMap.get(w.branch_id)||"فرع غير محدد"}));
  setWarehouses(warehouseRows);setItems((it.data||[]) as Item[]);setUnits((un.data||[]) as Unit[]);setParties((pa.data||[]) as Party[]);
  setBalances((bal.data||[]) as Balance[]);setReservations((res.data||[]) as Reservation[]);setDocs((documents.data||[]) as Doc[]);setDocTotal(documents.count||0);
  const jm:Record<string,string>={};for(const j of journals.data||[])if(j.source_id)jm[j.source_id]=j.id;setJournalIds(jm);
  setWarehouseId(old=>warehouseRows.some((w:any)=>w.id===old)?old:(warehouseRows[0]?.id||""));
  setPartyId(old=>(pa.data||[]).some((p:any)=>p.id===old&& (p.party_kind===partyKind||p.party_kind==="both"))?old:"");
  setLoading(false);
 };
 useEffect(()=>{void loadData();},[companyId,live,kind,docPage]);
 useEffect(()=>{const lastPage=Math.max(0,Math.ceil(docTotal/DOC_PAGE_SIZE)-1);if(docPage>lastPage)setDocPage(lastPage);},[docTotal,docPage]);
 const available=(itemId:string)=>{
  if(!warehouseId||!itemId)return 0;
  const onHand=Number(balances.find(b=>b.warehouse_id===warehouseId&&b.item_id===itemId)?.quantity_on_hand||0);
  const reserved=reservations.filter(r=>r.warehouse_id===warehouseId&&r.item_id===itemId).reduce((s,r)=>s+Number(r.quantity_base),0);
  return Math.max(0,onHand-reserved);
 };
 const updateLine=(id:string,patch:Partial<Line>)=>setLines(old=>old.map(l=>l.id===id?{...l,...patch}:l));
 const chooseItem=(line:Line,itemId:string)=>{
  const item=items.find(i=>i.id===itemId);if(!item){updateLine(line.id,{itemId:"",unitId:"",price:"0"});return;}
  const itemUnits=units.filter(u=>u.item_id===itemId);
  const unit=itemUnits.find(u=>u.is_base_unit)||itemUnits.slice().sort((a,b)=>Number(a.conversion_factor)-Number(b.conversion_factor))[0];
  const factor=Number(unit?.conversion_factor)||1;
  const basePrice=kind==="sale"?Number(item.sale_price):Number(item.purchase_price);
  updateLine(line.id,{itemId,unitId:unit?.id||"",price:String(round2(basePrice*factor)),discount:"0"});
 };
 const chooseUnit=(line:Line,unitId:string)=>{
  const item=items.find(i=>i.id===line.itemId),oldUnit=units.find(u=>u.id===line.unitId),nextUnit=units.find(u=>u.id===unitId);
  if(!item||!nextUnit){updateLine(line.id,{unitId});return;}
  const oldFactor=Number(oldUnit?.conversion_factor)||1,nextFactor=Number(nextUnit.conversion_factor)||1;
  const basePrice=kind==="sale"?Number(item.sale_price):Number(item.purchase_price);
  updateLine(line.id,{unitId,price:String(round2(basePrice*nextFactor)),qty:String(Number(line.qty)||1),discount:String(round2((Number(line.discount)||0)*nextFactor/oldFactor))});
 };
 const saveDraft=async()=>{
  if(!live||!supabase){setMessage("يجب تسجيل الدخول إلى المنشأة لكتابة مستندات التشغيل.");return;}
  if(!canCreate){setMessage("إنشاء مستندات التشغيل في هذه المرحلة متاح لمالك المنشأة أو مدير النظام فقط، وفق سياسات قاعدة البيانات الحالية.");return;}
  if(!selectedParty){setMessage("أضف واختر "+(kind==="sale"?"عميلًا":"موردًا")+" فعليًا من شاشة "+(kind==="sale"?"العملاء":"الموردين")+" أولًا.");return;}
  if(!selectedWarehouse){setMessage("لا يوجد مخزن نشط متاح في نطاق صلاحيتك.");return;}
  if(!date||date>today()){setMessage("تاريخ المستند مطلوب ولا يجوز أن يكون مستقبليًا.");return;}
  if(!lines.length||lines.some(l=>!l.itemId||!Number.isFinite(Number(l.qty))||Number(l.qty)<=0||!Number.isFinite(Number(l.price))||Number(l.price)<0||!Number.isFinite(Number(l.discount))||Number(l.discount)<0)){setMessage("أكمل الصنف والكمية الصحيحة والسعر غير السالب والخصم الصحيح في كل البنود.");return;}
  const requestedByItem=new Map<string,number>();
  for(let i=0;i<lines.length;i++){
   const line=lines[i],item=items.find(x=>x.id===line.itemId);
   if(!item){setMessage("أحد الأصناف لم يعد متاحًا.");return;}
   requestedByItem.set(line.itemId,(requestedByItem.get(line.itemId)||0)+lineTotals[i].baseQty);
  }
  if(kind==="sale"){
   for(const [itemId,required] of requestedByItem){
    const item=items.find(x=>x.id===itemId)!;
    const availableQty=available(itemId);
    if(availableQty<required){setMessage("إجمالي الكمية المطلوبة للصنف "+item.item_name+" ("+money(required)+" "+item.base_unit+") أكبر من المتاح ("+money(availableQty)+" "+item.base_unit+"). قلّل الكمية أو راجع الحجوزات.");return;}
   }
  }
  setSaving(true);setMessage("");
  const now=Date.now();
  const header:any={company_id:companyId,branch_id:selectedWarehouse.branch_id,warehouse_id:warehouseId,document_date:date,document_type:kind==="sale"?"delivery":"receipt",status:"draft",subtotal:0,discount_total:0,tax_total:0,grand_total:0,paid_total:0,auto_number:now,created_by:userId,is_demo_data:false,notes:notes.trim()||null};
  if(kind==="sale"){header.customer_id=partyId;header.source_channel="manual";header.is_tax_invoice=false;header.payment_type="آجل";}
  else header.supplier_id=partyId;
  const {data:doc,error:headerError}=await supabase.from(docTable).insert(header).select("id,document_number").single();
  if(headerError||!doc){setMessage("تعذر إنشاء المسودة: "+(headerError?.message||"لم يتم إرجاع رقم المستند."));setSaving(false);return;}
  const payload=lines.map((l,i)=>({item_id:l.itemId,quantity:Number(l.qty),unit_price:Number(l.price),discount:lineTotals[i].discount,tax:lineTotals[i].tax,unit_id:l.unitId||null}));
  const {error:linesError}=await supabase.rpc("erp_add_operational_document_lines_v2",{p_document_id:doc.id,p_kind:kind==="sale"?"sales":"purchase",p_lines:payload});
  if(linesError){
   await supabase.from(docTable).delete().eq("id",doc.id).eq("status","draft");
   setMessage("لم تُحفظ بنود المستند: "+linesError.message);setSaving(false);return;
  }
  setLines([blankLine()]);setNotes("");setMessage("تم حفظ "+(kind==="sale"?"إذن التسليم":"إذن الاستلام")+" "+doc.document_number+" كمسودة في قاعدة سلسلة. لم تتغير أرصدة المخزون بعد.");
  await loadData(false);setSaving(false);
 };
 const postDocument=async(doc:Doc)=>{
  if(!live||!supabase||doc.status!=="draft")return;
  if(!window.confirm("ترحيل "+doc.document_number+"؟ سيتم إنشاء حركات المخزون أولًا ثم القيد المحاسبي وفق خريطة الحسابات المعتمدة."))return;
  setSaving(true);setMessage("");
  const {error}=await supabase.rpc(kind==="sale"?"erp_post_sales_document":"erp_post_purchase_document",{p_document_id:doc.id});
  if(error){setMessage("لم يتم ترحيل المستند: "+error.message);setSaving(false);return;}
  const {data:journalId,error:accountingError}=await supabase.rpc("erp_post_operational_document_accounting",{p_document_id:doc.id,p_kind:kind==="sale"?"sales":"purchase"});
  await loadData(false);
  if(accountingError){setMessage("تم ترحيل حركة المخزون للمستند "+doc.document_number+"، لكن القيد المحاسبي لم يكتمل: "+accountingError.message+"؛ استخدم «إعادة محاولة المحاسبة» بعد معالجة السبب.");setSaving(false);return;}
  setMessage("تم ترحيل "+doc.document_number+" مخزنيًا ومحاسبيًا. رقم قيد اليومية: "+String(journalId||"—")+".");setSaving(false);
 };
 const toggleDetails=async(doc:Doc)=>{
  if(expandedDocId===doc.id){setExpandedDocId("");return;}
  setExpandedDocId(doc.id);
  if(detailRows[doc.id])return;
  if(!live||!supabase){setDetailErrors(old=>({...old,[doc.id]:"سجّل الدخول لعرض بنود المستند المحفوظة."}));return;}
  setDetailLoadingId(doc.id);setDetailErrors(old=>({...old,[doc.id]:""}));
  const lineTable=kind==="sale"?"erp_sales_lines":"erp_purchase_lines";
  const {data,error}=await supabase.from(lineTable).select("id,item_id,quantity,unit_price,discount_amount,tax_amount,line_total,unit_code,conversion_factor,base_quantity,batch_number,expiry_date").eq("document_id",doc.id).order("created_at");
  if(error){setDetailErrors(old=>({...old,[doc.id]:"تعذر تحميل بنود المستند: "+error.message}));setDetailLoadingId("");return;}
  const rows=(data||[]) as DocLine[];
  const itemIds=[...new Set(rows.map(line=>line.item_id).filter(Boolean))];
  const {data:itemData,error:itemError}=itemIds.length?await supabase.from("erp_items").select("id,item_code,item_name,base_unit").in("id",itemIds):{data:[],error:null};
  if(itemError){setDetailErrors(old=>({...old,[doc.id]:"تم تحميل البنود لكن تعذر تحميل أسماء الأصناف: "+itemError.message}));setDetailLoadingId("");return;}
  const itemMap=new Map((itemData||[]).map((item:any)=>[item.id,item]));
  setDetailRows(old=>({...old,[doc.id]:rows.map(line=>({...line,...(itemMap.get(line.item_id)||{})}))}));
  setDetailLoadingId("");
 };
 const retryAccounting=async(doc:Doc)=>{
  if(!live||!supabase||doc.status!=="posted")return;
  setSaving(true);const {data,error}=await supabase.rpc("erp_post_operational_document_accounting",{p_document_id:doc.id,p_kind:kind==="sale"?"sales":"purchase"});
  if(error)setMessage("تعذرت إعادة المحاسبة: "+error.message);
  else{setMessage("تم إنشاء القيد المحاسبي وربطه بالمستند. رقم القيد: "+String(data||"—"));await loadData(false);}
  setSaving(false);
 };
 const cancelDraft=async(doc:Doc)=>{
  if(!live||!supabase||doc.status!=="draft")return;
  if(!window.confirm("إلغاء المسودة "+doc.document_number+"؟ سيتم تحرير أي كميات محجوزة لها."))return;
  setSaving(true);const {error}=await supabase.from(docTable).update({status:"cancelled"}).eq("id",doc.id).eq("status","draft");
  if(error)setMessage("تعذر إلغاء المسودة: "+error.message);else{setMessage("تم إلغاء المسودة وتحرير الحجوزات المرتبطة بها.");await loadData(false);}
  setSaving(false);
 };
 const filteredDocs=docs.filter(d=>{const statusText=d.status==="cancelled"?"ملغي":d.status==="draft"?"مسودة":journalIds[d.id]?"مرحل مخزنيًا ومحاسبيًا":"مرحل مخزنيًا · محاسبة معلقة";const values=[d.document_number,partyOptions.find(p=>p.id===(kind==="sale"?d.customer_id:d.supplier_id))?.party_name||"",warehouses.find(w=>w.id===d.warehouse_id)?.warehouse_name||"",d.document_date,money(Number(d.grand_total)),statusText];return values.join(" ").toLowerCase().includes(query.toLowerCase())&&values.every((v,i)=>String(v??"").toLowerCase().includes((docColumnFilters[String(i)]||"").toLowerCase()));});
 const statusLabel=(d:Doc)=>d.status==="cancelled"?"ملغي":d.status==="draft"?"مسودة":journalIds[d.id]?"مرحل مخزنيًا ومحاسبيًا":"مرحل مخزنيًا · محاسبة معلقة";
 return <section className="operation-workspace" dir="rtl">
  <div className="operation-heading"><div className="operation-title"><span className="operation-icon"><Icon size={22}/></span><div><small>دورة تشغيل مرتبطة بقاعدة البيانات</small><h2>{title}</h2><p>{kind==="sale"?"إذن تسليم فعلي يحجز الكمية عند حفظ المسودة، ثم يرحّل حركة الصرف والقيد المحاسبي.":"إذن استلام فعلي يضيف المخزون عند الترحيل، ثم ينشئ القيد المحاسبي للمورد."}</p></div></div><span className="demo-pill">{live?"متصل بقاعدة سلسلة":"يتطلب تسجيل الدخول"}</span></div>
  {!live&&<div className="operation-feedback warning">سجّل الدخول بحساب المنشأة لفتح مستندات التشغيل الحقيقية.</div>}
  {live&&<><div className="operation-form-grid">
   <label><span>{kind==="sale"?"العميل":"المورد"}</span><select value={partyId} onChange={e=>setPartyId(e.target.value)}><option value="">اختر {kind==="sale"?"عميلًا":"موردًا"}</option>{partyOptions.map(p=><option key={p.id} value={p.id}>{p.party_code} — {p.party_name}</option>)}</select></label>
   <label><span>المخزن</span><select value={warehouseId} onChange={e=>setWarehouseId(e.target.value)}>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_name} — {w.branchName}</option>)}</select></label>
   <label><span>تاريخ المستند</span><input type="date" value={date} max={today()} onChange={e=>setDate(e.target.value)}/></label>
   <label><span>رقم المستند</span><input value="يولّد تلقائيًا حسب سياسة التكويد" readOnly/></label>
  </div>
  {partyOptions.length===0&&<div className="operation-feedback warning">لا يوجد {kind==="sale"?"عملاء":"موردون"} مسجلون في قاعدة المنشأة حاليًا. أضف الطرف أولًا من شاشة {kind==="sale"?"العملاء":"الموردين"}.</div>}
  {warehouses.length===0&&<div className="operation-feedback warning">لا توجد مخازن نشطة ضمن نطاق صلاحيتك.</div>}
  <div className="operation-table-card"><div className="operation-table-head"><div><b><Package size={16}/> بنود المستند</b><small>{lines.length} بند · الوحدات والأسعار تُقرأ من بيانات الصنف</small></div><button className="operation-add" onClick={()=>setLines(old=>[...old,blankLine()])}><Plus size={16}/> إضافة صنف</button></div>
   <div className="operation-table-scroll"><table><thead><tr><th>الصنف</th><th>الوحدة</th><th>الكمية</th><th>سعر الوحدة</th><th>الخصم</th><th>الضريبة</th><th>الإجمالي</th><th>المتاح</th><th></th></tr></thead><tbody>{lines.map((l,i)=>{const item=items.find(x=>x.id===l.itemId),unitList=units.filter(u=>u.item_id===l.itemId);return <tr key={l.id}>
    <td><select className="cell-input item-name" value={l.itemId} onChange={e=>chooseItem(l,e.target.value)}><option value="">اختر الصنف</option>{items.map(it=><option key={it.id} value={it.id}>{it.item_code} — {it.item_name}</option>)}</select></td>
    <td><select className="cell-input" value={l.unitId} onChange={e=>chooseUnit(l,e.target.value)} disabled={!item}><option value="">الوحدة الأساسية</option>{unitList.map(u=><option key={u.id} value={u.id}>{u.unit_name||u.unit_code} × {u.conversion_factor}</option>)}</select></td>
    <td><input className="cell-input number-input" type="number" min="0.001" step="0.001" value={l.qty} onChange={e=>updateLine(l.id,{qty:e.target.value})}/></td>
    <td><input className="cell-input number-input" type="number" min="0" step="0.01" value={l.price} onChange={e=>updateLine(l.id,{price:e.target.value})}/></td>
    <td><input className="cell-input number-input" type="number" min="0" step="0.01" value={l.discount} onChange={e=>updateLine(l.id,{discount:e.target.value})}/></td>
    <td>{item?money(lineTotals[i].tax)+" ("+item.tax_rate+"%)":"—"}</td>
    <td className="operation-amount">{money(lineTotals[i].total)} ج.م</td>
    <td>{item?money(available(item.id))+" "+item.base_unit:"—"}</td>
    <td><button className="remove-line" title="حذف البند" onClick={()=>setLines(old=>old.filter(x=>x.id!==l.id))}><Trash2 size={14}/></button></td>
   </tr>})}</tbody></table></div>
  </div>
  <div className="operation-bottom"><div className="operation-notes"><label>ملاحظات المستند<textarea value={notes} onChange={e=>setNotes(e.target.value)} rows={3} placeholder="ملاحظات التشغيل أو رقم فاتورة المورد..."/></label><div className="operation-feedback">الوحدة الأساسية: الكمية المخزنية تُحوّل تلقائيًا حسب معامل الوحدة. {kind==="sale"?"البيع لا يتجاوز المتاح بعد الحجوزات.":"الاستلام يضيف الكميات عند الترحيل فقط."}</div></div><div className="operation-totals"><div><span>الإجمالي قبل الخصم</span><b>{money(subtotal)} ج.م</b></div><div><span>الخصم</span><b>{money(discountTotal)} ج.م</b></div><div><span>الضريبة</span><b>{money(taxTotal)} ج.م</b></div><div className="grand-total"><span>صافي المستند</span><strong>{money(grandTotal)} <small>ج.م</small></strong></div></div></div>
  <div className="operation-actions"><button className="operation-save" onClick={()=>void saveDraft()} disabled={saving||loading||!canCreate||!selectedParty||!selectedWarehouse}><Save size={16}/> {saving?"جارٍ التنفيذ...":"حفظ مسودة فعلية"}</button><button className="operation-reset" onClick={()=>{setLines([blankLine()]);setNotes("");setDate(today());}}><RotateCcw size={15}/> تفريغ النموذج</button></div></>}
  {message&&<div className="operation-feedback">{message}</div>}
  <div className="operation-history"><div className="operation-table-head"><div><b><FileText size={16}/> سجل المستندات</b><small>عرض 50 مستندًا في الصفحة من قاعدة سلسلة · الترحيل المخزني منفصل عن المحاسبي</small></div><div className="treasury-row-actions"><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="بحث في المستندات"/><button className="operation-add" onClick={()=>void loadData()} disabled={loading}><RefreshCw size={14}/> تحديث</button></div></div>
   {loading?<div className="operation-empty">جارٍ تحميل السجلات...</div>:filteredDocs.length?<div className="table-wrap"><table><thead><tr className="column-filter-row">{["رقم المستند","الطرف","المخزن","التاريخ","الصافي","الحالة"].map((label,i)=><th key={label}><input aria-label={"بحث "+label} placeholder={"بحث "+label} value={docColumnFilters[String(i)]||""} onChange={e=>setDocColumnFilters(v=>({...v,[String(i)]:e.target.value}))}/></th>)}<th aria-hidden="true">—</th></tr><tr><th>رقم المستند</th><th>الطرف</th><th>المخزن</th><th>التاريخ</th><th>الصافي</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>{filteredDocs.map(d=><Fragment key={d.id}><tr><td><b>{d.document_number}</b></td><td>{partyOptions.find(p=>p.id===(kind==="sale"?d.customer_id:d.supplier_id))?.party_name||"—"}</td><td>{warehouses.find(w=>w.id===d.warehouse_id)?.warehouse_name||"—"}</td><td>{d.document_date}</td><td className="operation-amount">{money(Number(d.grand_total))} ج.م</td><td><span className={d.status==="posted"?"treasury-status posted":d.status==="cancelled"?"treasury-status":"treasury-status draft"}>{statusLabel(d)}</span></td><td><div className="treasury-row-actions"><button className="operation-add" onClick={()=>void toggleDetails(d)}><Eye size={14}/> تفاصيل البنود</button>{d.status==="draft"?<><button className="operation-add" onClick={()=>void postDocument(d)} disabled={saving}><CheckCircle2 size={14}/> ترحيل المخزون والمحاسبة</button><button className="remove-line" title="إلغاء المسودة وتحرير الحجوزات" onClick={()=>void cancelDraft(d)} disabled={saving}><Trash2 size={14}/></button></>:d.status==="posted"&&!journalIds[d.id]?<button className="operation-add" onClick={()=>void retryAccounting(d)} disabled={saving}>إعادة محاولة المحاسبة</button>:journalIds[d.id]?<small className="treasury-ref">قيد: {journalIds[d.id].slice(0,8)}</small>:<span>—</span>}</div></td></tr>{expandedDocId===d.id&&<tr className="document-detail-row"><td colSpan={7}><div className="operation-table-card"><div className="operation-table-head"><b>تفاصيل {d.document_number}</b><small>{detailRows[d.id]?.length||0} بند</small></div>{detailLoadingId===d.id?<div className="operation-empty">جارٍ تحميل البنود...</div>:detailErrors[d.id]?<div className="operation-feedback warning">{detailErrors[d.id]}</div>:detailRows[d.id]?.length?<div className="operation-table-scroll"><table><thead><tr><th>كود الصنف</th><th>الصنف</th><th>الكمية</th><th>الوحدة</th><th>معامل التحويل</th><th>الكمية الأساسية</th><th>سعر الوحدة</th><th>الخصم</th><th>الضريبة</th><th>الإجمالي</th><th>التشغيلة</th><th>الصلاحية</th></tr></thead><tbody>{detailRows[d.id].map(line=><tr key={line.id}><td>{line.item_code||"—"}</td><td>{line.item_name||"صنف غير متاح"}</td><td>{money(Number(line.quantity))}</td><td>{line.unit_code||line.base_unit||"—"}</td><td>{money(Number(line.conversion_factor)||1)}</td><td>{money(Number(line.base_quantity)||Number(line.quantity)*(Number(line.conversion_factor)||1))} {line.base_unit||""}</td><td>{money(Number(line.unit_price))} ج.م</td><td>{money(Number(line.discount_amount))} ج.م</td><td>{money(Number(line.tax_amount))} ج.م</td><td className="operation-amount">{money(Number(line.line_total))} ج.م</td><td>{line.batch_number||"—"}</td><td>{line.expiry_date||"—"}</td></tr>)}</tbody></table></div>:<div className="operation-empty">لا توجد بنود مسجلة لهذا المستند.</div>}</div></td></tr>}</Fragment>)}</tbody></table></div>:<div className="operation-empty">لا توجد مستندات محفوظة في قاعدة المنشأة حتى الآن.</div>}
  </div>
  {docTotal>DOC_PAGE_SIZE&&<div className="operation-actions document-pagination"><span>عرض {docPage*DOC_PAGE_SIZE+1}–{Math.min((docPage+1)*DOC_PAGE_SIZE,docTotal)} من {docTotal} مستند</span><div className="treasury-row-actions"><button className="operation-add" onClick={()=>setDocPage(page=>Math.max(0,page-1))} disabled={docPage===0||loading}>السابق</button><span>صفحة {docPage+1} من {Math.ceil(docTotal/DOC_PAGE_SIZE)}</span><button className="operation-add" onClick={()=>setDocPage(page=>Math.min(Math.ceil(docTotal/DOC_PAGE_SIZE)-1,page+1))} disabled={(docPage+1)*DOC_PAGE_SIZE>=docTotal||loading}>التالي</button></div></div>}
  <div className="operation-disclaimer">{kind==="sale"?"هذه المرحلة تنشئ إذن تسليم مبيعات مرتبطًا بحركة المخزون والقيد الآلي؛ إصدار فاتورة ضريبية نهائية وسلسلة عرض السعر/أمر البيع ما زالت مرحلة مستقلة.":"هذه المرحلة تنشئ إذن استلام مشتريات يضيف المخزون ويرحّل أثره المحاسبي وفق خريطة الحسابات؛ ربط أمر التوريد وأمر الشراء والفاتورة الموردية يُستكمل ضمن دورة المستندات."} التحصيل والسداد النقدي يُسجلان بسندات الخزينة المرتبطة.</div>
 </section>;
}
