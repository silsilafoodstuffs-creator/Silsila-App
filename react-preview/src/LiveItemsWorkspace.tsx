import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "./supabase";
import EditDrawer from "./EditDrawer";
import { Search, RefreshCw, Package, Pencil, Save, X, Boxes, Tags, Award, AlertCircle } from "lucide-react";

type Item = { id:string; company_id:string; item_code:string; item_name:string; item_name_en:string; barcode:string|null; base_unit:string; purchase_price:number; sale_price:number; reorder_level:number; tax_rate:number; discount_limit:number; category_id:string|null; brand_id:string|null; brand_name:string|null; is_active:boolean; expiry_tracking:boolean; show_in_app:boolean };
type Unit = { id:string; item_id:string; unit_code:string; unit_name:string; conversion_factor:number; is_base_unit:boolean; unit_level:number|null; inner_quantity:number|null; is_active:boolean; is_implicit:boolean; is_selectable:boolean };
type Ref = { id:string; name:string; code:string };
const money=(v:number)=>new Intl.NumberFormat("ar-EG",{maximumFractionDigits:2}).format(Number(v)||0);
export default function LiveItemsWorkspace(){
 const companyId=sessionStorage.getItem("silsila-company-id");
 const [items,setItems]=useState<Item[]>([]),[units,setUnits]=useState<Unit[]>([]),[categories,setCategories]=useState<Ref[]>([]),[brands,setBrands]=useState<Ref[]>([]);
 const [search,setSearch]=useState(""),[active,setActive]=useState("all"),[loading,setLoading]=useState(true),[error,setError]=useState(""),[notice,setNotice]=useState("");
 const [editing,setEditing]=useState<Item|null>(null),[editingOriginal,setEditingOriginal]=useState<Item|null>(null),[saving,setSaving]=useState(false);
 const [showCreate,setShowCreate]=useState(false),[creating,setCreating]=useState(false);
 const [draft,setDraft]=useState({item_name:"",item_name_en:"",barcode:"",category_id:"",brand_id:"",base_unit:"وحدة",purchase_price:"0",sale_price:"0",tax_rate:"0",reorder_level:"0"});
 const load=useCallback(async()=>{
  if(!supabase||!companyId){setLoading(false);setError("سجّل الدخول إلى المنشأة لعرض سجل الأصناف الفعلي. وضع المعاينة لا يعرض بيانات منشأة.");return;}
  setLoading(true);setError("");
  const [ir,ur,cr,br]=await Promise.all([
   supabase.from("erp_items").select("id,company_id,item_code,item_name,item_name_en,barcode,base_unit,purchase_price,sale_price,reorder_level,tax_rate,discount_limit,category_id,brand_id,brand_name,is_active,expiry_tracking,show_in_app").eq("company_id",companyId).order("item_name").limit(500),
   supabase.from("erp_item_units").select("id,item_id,unit_code,unit_name,conversion_factor,is_base_unit,unit_level,inner_quantity,is_active,is_implicit,is_selectable").eq("company_id",companyId).order("conversion_factor",{ascending:false}).limit(3000),
   supabase.from("erp_item_categories").select("id,category_name,category_code").eq("company_id",companyId).eq("is_active",true).order("category_name").limit(1000),
   supabase.from("erp_brands").select("id,brand_name,brand_code").eq("company_id",companyId).eq("is_active",true).order("brand_name").limit(1000)
  ]);
  const firstError=ir.error||ur.error||cr.error||br.error;
  if(firstError){setError("تعذر تحميل سجل الأصناف أو وحداته أو مراجعه: "+firstError.message);setItems([]);setUnits([]);}
  else{setItems((ir.data||[]) as Item[]);setUnits((ur.data||[]) as Unit[]);setCategories((cr.data||[]).map((x:any)=>({id:x.id,name:x.category_name,code:x.category_code})));setBrands((br.data||[]).map((x:any)=>({id:x.id,name:x.brand_name,code:x.brand_code})));}
  setLoading(false);
 },[companyId]);
 useEffect(()=>{void load();},[load]);
 const filtered=useMemo(()=>items.filter(i=>(active==="all"||(active==="active"?i.is_active:!i.is_active))&&[i.item_code,i.item_name,i.item_name_en,i.barcode||"",i.brand_name||""].join(" ").toLowerCase().includes(search.trim().toLowerCase())),[items,active,search]);
 const unitRows=useMemo(()=>units.filter(u=>editing?.id===u.item_id),[units,editing]);
 const begin=(item:Item)=>{setNotice("");setEditingOriginal({...item});setEditing({...item});};
 const save=async():Promise<boolean>=>{if(!editing||!supabase)return false;if(!editing.item_name.trim()){setNotice("اسم الصنف مطلوب.");return false;}setSaving(true);setNotice("");
  const payload={item_name:editing.item_name.trim(),item_name_en:editing.item_name_en||"",barcode:editing.barcode||null,base_unit:editing.base_unit,purchase_price:Number(editing.purchase_price)||0,sale_price:Number(editing.sale_price)||0,reorder_level:Number(editing.reorder_level)||0,tax_rate:Number(editing.tax_rate)||0,discount_limit:Number(editing.discount_limit)||0,category_id:editing.category_id,brand_id:editing.brand_id,brand_name:brands.find(b=>b.id===editing.brand_id)?.name||editing.brand_name||null,is_active:editing.is_active,expiry_tracking:editing.expiry_tracking,show_in_app:editing.show_in_app};
  const {data,error}=await supabase.from("erp_items").update(payload).eq("id",editing.id).eq("company_id",companyId).select("id").maybeSingle();
  setSaving(false);if(error){setNotice("لم يتم الحفظ: "+error.message);return false;}if(!data){setNotice("لم يتم تحديث السجل؛ تحقق من صلاحية التعديل والوصول إلى الشركة.");return false;}
  setNotice("تم حفظ تعديلات الصنف في قاعدة البيانات.");setEditing(null);setEditingOriginal(null);await load();return true;
 };
 const createItem=async()=>{
  if(!supabase||!companyId)return;
  const category=categories.find(c=>c.id===draft.category_id);
  if(!draft.item_name.trim()){setNotice("اسم الصنف مطلوب.");return;}
  if(!category||category.code.length!==8){setNotice("اختر فئة ثانوية مكتملة حتى يتم توليد كود الصنف وفق سياسة التكويد.");return;}
  const unitName=draft.base_unit.trim();
  if(!unitName){setNotice("اسم الوحدة الأساسية مطلوب.");return;}
  setCreating(true);setNotice("");
  const {data,error}=await supabase.rpc("erp_create_item_with_units",{
   p_item:{
    company_id:companyId,item_name:draft.item_name.trim(),item_name_en:draft.item_name_en.trim(),
    category_id:draft.category_id,brand_id:draft.brand_id||null,barcode:draft.barcode.trim()||null,
    base_unit:unitName,purchase_price:Number(draft.purchase_price)||0,sale_price:Number(draft.sale_price)||0,
    tax_rate:Number(draft.tax_rate)||0,reorder_level:Number(draft.reorder_level)||0,expiry_tracking:false
   },
   p_units:[{unit_code:"Unt001",unit_name:unitName,conversion_factor:1,is_base_unit:true,unit_level:3,inner_quantity:null,is_implicit:false,is_selectable:true}]
  });
  setCreating(false);
  if(error){setNotice("لم يتم إنشاء الصنف: "+error.message);return;}
  const created=Array.isArray(data)?data[0]:data;
  setNotice("تم إنشاء الصنف وربط وحدته الأساسية. كود الصنف: "+(created?.item_code||"تم توليده مركزيًا"));
  setShowCreate(false);
  setDraft({item_name:"",item_name_en:"",barcode:"",category_id:"",brand_id:"",base_unit:"وحدة",purchase_price:"0",sale_price:"0",tax_rate:"0",reorder_level:"0"});
  await load();
 };
 const countActive=items.filter(i=>i.is_active).length;
 return <section className="live-items" dir="rtl">
  <style>{`.live-items{color:var(--text-primary,#241735);display:grid;gap:12px}.li-head{display:flex;align-items:center;gap:12px;background:linear-gradient(120deg,#3e007d,#5a1598);color:#fff;border-radius:16px;padding:18px}.li-head .li-mark{width:46px;height:46px;border-radius:13px;background:#ffffff20;display:grid;place-items:center}.li-head h2{margin:2px 0;font-size:22px}.li-head p,.li-head small{margin:0;color:#eee0ff}.li-kpis{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}.li-kpi,.li-panel,.li-editor{background:var(--surface,#fff);border:1px solid var(--border,#e9e2f0);border-radius:13px;padding:12px}.li-kpi span,.li-kpi b{display:block}.li-kpi span{color:var(--text-muted,#746b7d);font-size:12px}.li-kpi b{font-size:21px;margin-top:4px}.li-tools{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.li-search{display:flex;align-items:center;gap:8px;flex:1;min-width:220px;border:1px solid var(--border,#ddd);border-radius:9px;padding:0 10px;height:40px}.li-search input{border:0;outline:0;background:transparent;width:100%;color:inherit}.live-items button,.live-items select,.live-items input{font:inherit}.li-tools button,.li-action{height:38px;border:1px solid var(--border,#ddd);background:#fff;border-radius:9px;padding:0 12px;display:inline-flex;align-items:center;gap:6px;cursor:pointer;color:#3e007d}.li-create{background:#3e007d!important;color:#fff!important;border-color:#3e007d!important}.li-create-form{background:#fff;border:1px solid #e5d9f0;border-radius:12px;padding:14px;margin:12px 0}.li-create-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.li-create-grid label{display:grid;gap:5px;font-size:12px;color:#62576d}.li-create-grid input,.li-create-grid select{height:40px;border:1px solid #ddd;border-radius:8px;padding:0 9px;min-width:0;background:#fff;color:#241735}.li-create-actions{display:flex;gap:8px;margin-top:12px}.li-create-form h3{margin:0 0 10px;color:#3e007d}.li-tools select,.li-editor input,.li-editor select{height:38px;border:1px solid var(--border,#ddd);border-radius:8px;padding:0 9px;background:#fff;color:#241735;min-width:0}.li-table-wrap{overflow:auto}.li-table{width:100%;border-collapse:separate;border-spacing:0;min-width:820px}.li-table th{background:#3e007d;color:#fff;text-align:right;padding:11px 10px;font-weight:600;white-space:nowrap}.li-table td{padding:10px;border-bottom:1px solid #eee8f2;vertical-align:middle}.li-table tr:hover td{background:#faf7fd}.li-code{font-weight:700;color:#3e007d;direction:ltr;text-align:right}.li-sub{font-size:11px;color:#82788c;display:block;margin-top:3px}.li-status{border-radius:20px;padding:4px 9px;font-size:11px;background:#e8f7ef;color:#167347}.li-off{background:#f4edf7;color:#7b7182}.li-error,.li-note{padding:11px;border-radius:10px;background:#fff5e8;color:#885000}.li-editor-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.li-editor label{display:grid;gap:5px;font-size:12px;color:#62576d}.li-editor h3{margin:0 0 10px}.li-editor-actions{display:flex;gap:8px;justify-content:flex-start;margin-top:12px}.li-primary{background:#3e007d!important;color:#fff!important;border-color:#3e007d!important}.li-unit-list{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}.li-unit{border:1px solid #e7dff0;background:#faf7fd;border-radius:8px;padding:6px 9px;font-size:12px}.li-empty{text-align:center;padding:30px;color:#756b80}@media(max-width:700px){.li-kpis{grid-template-columns:1fr 1fr}.li-editor-grid,.li-create-grid{grid-template-columns:1fr 1fr}.li-head{padding:13px}.li-head h2{font-size:19px}}`}</style>
  <div className="li-head"><span className="li-mark"><Package size={24}/></span><div><small>دليل الأصناف · بيانات المنشأة المباشرة</small><h2>المخازن والأصناف</h2><p>سجل الأصناف والفئات والبراندات والوحدات المرتبطة بها</p></div></div>
  <div className="li-kpis"><div className="li-kpi"><span>إجمالي الأصناف</span><b>{items.length.toLocaleString("ar-EG")}</b></div><div className="li-kpi"><span>الأصناف النشطة</span><b>{countActive.toLocaleString("ar-EG")}</b></div><div className="li-kpi"><span>وحدات القياس المعرفة</span><b>{units.length.toLocaleString("ar-EG")}</b></div></div>
  <div className="li-panel"><div className="li-tools"><label className="li-search"><Search size={16}/><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="ابحث بالكود أو اسم الصنف أو الباركود أو البراند"/></label><select value={active} onChange={e=>setActive(e.target.value)}><option value="all">كل الحالات</option><option value="active">نشط</option><option value="inactive">موقوف</option></select><button className="li-create" onClick={()=>setShowCreate(v=>!v)}><Package size={15}/> إضافة صنف</button><button onClick={()=>void load()}><RefreshCw size={15}/> تحديث</button></div>
   {showCreate&&<div className="li-create-form"><h3>إضافة صنف جديد</h3><div className="li-create-grid">
    <label>اسم الصنف *<input value={draft.item_name} onChange={e=>setDraft(v=>({...v,item_name:e.target.value}))} placeholder="اسم الصنف"/></label>
    <label>الاسم بالإنجليزية<input value={draft.item_name_en} onChange={e=>setDraft(v=>({...v,item_name_en:e.target.value}))}/></label>
    <label>الباركود<input value={draft.barcode} onChange={e=>setDraft(v=>({...v,barcode:e.target.value}))}/></label>
    <label>الفئة الثانوية *<select value={draft.category_id} onChange={e=>setDraft(v=>({...v,category_id:e.target.value}))}><option value="">اختر الفئة الثانوية</option>{categories.filter(c=>c.code.length===8).map(c=><option key={c.id} value={c.id}>{c.code} · {c.name}</option>)}</select></label>
    <label>البراند / الماركة<select value={draft.brand_id} onChange={e=>setDraft(v=>({...v,brand_id:e.target.value}))}><option value="">بدون براند</option>{brands.map(b=><option key={b.id} value={b.id}>{b.code} · {b.name}</option>)}</select></label>
    <label>الوحدة الأساسية *<input value={draft.base_unit} onChange={e=>setDraft(v=>({...v,base_unit:e.target.value}))} placeholder="وحدة"/></label>
    <label>سعر الشراء<input type="number" min="0" value={draft.purchase_price} onChange={e=>setDraft(v=>({...v,purchase_price:e.target.value}))}/></label>
    <label>سعر البيع<input type="number" min="0" value={draft.sale_price} onChange={e=>setDraft(v=>({...v,sale_price:e.target.value}))}/></label>
    <label>الضريبة %<input type="number" min="0" value={draft.tax_rate} onChange={e=>setDraft(v=>({...v,tax_rate:e.target.value}))}/></label>
    <label>حد إعادة الطلب<input type="number" min="0" value={draft.reorder_level} onChange={e=>setDraft(v=>({...v,reorder_level:e.target.value}))}/></label>
   </div><div className="li-create-actions"><button className="li-action li-primary" disabled={creating} onClick={()=>void createItem()}><Save size={15}/>{creating?"جارٍ الإنشاء":"حفظ الصنف وتوليد الكود"}</button><button className="li-action" onClick={()=>setShowCreate(false)}><X size={15}/> إلغاء</button></div><div className="li-sub">سيُنشأ الصنف ووحدته الأساسية داخل معاملة واحدة عبر إجراء قاعدة البيانات، ويُولّد كود الصنف من سياسة التكويد الحالية.</div></div>}
   {error&&<div className="li-error"><AlertCircle size={15}/> {error}</div>}
   <div className="li-table-wrap"><table className="li-table"><thead><tr><th>كود الصنف</th><th>اسم الصنف</th><th>الفئة</th><th>البراند</th><th>الوحدة الأساسية</th><th>شراء</th><th>بيع</th><th>الوحدات</th><th>نشط؟</th><th>تعديل</th></tr></thead><tbody>{filtered.map(i=><tr key={i.id}><td className="li-code">{i.item_code}</td><td><b>{i.item_name}</b>{i.barcode&&<span className="li-sub">{i.barcode}</span>}</td><td>{categories.find(c=>c.id===i.category_id)?.name||"—"}</td><td>{brands.find(b=>b.id===i.brand_id)?.name||i.brand_name||"—"}</td><td>{i.base_unit}</td><td>{money(i.purchase_price)}</td><td>{money(i.sale_price)}</td><td>{units.filter(u=>u.item_id===i.id&&!u.is_implicit).length}</td><td><input className="silsila-bool-check" type="checkbox" checked={i.is_active===true} disabled readOnly aria-label={i.is_active===true?"نشط":"لا"}/></td><td><button className="li-action" onClick={()=>begin(i)}><Pencil size={14}/> تعديل</button></td></tr>)}{!loading&&!filtered.length&&<tr><td colSpan={10} className="li-empty">لا توجد أصناف مطابقة في سجل المنشأة.</td></tr>}</tbody></table>{loading&&<div className="li-empty">جارٍ تحميل بيانات الأصناف والوحدات والمراجع...</div>}</div>
   <div className="li-sub">عرض أول 500 صنف. يتم تحديث البيانات من قاعدة المنشأة مباشرة.</div>
  </div>
  {editing&&<EditDrawer title={"تعديل بيانات الصنف · "+editing.item_code} dirty={JSON.stringify(editing)!==JSON.stringify(editingOriginal)} saving={saving} error={notice.startsWith("لم يتم")||notice.startsWith("اسم الصنف")?notice:""} onSaveError={()=>setSaving(false)} onSave={save} onDiscard={()=>{setEditing(editingOriginal);setNotice("");}} onClose={()=>{setEditing(null);setEditingOriginal(null);}}><div className="li-editor"><h3>تعديل بيانات الصنف · {editing.item_code}</h3><div className="li-editor-grid">
   <label>اسم الصنف<input value={editing.item_name} onChange={e=>setEditing(v=>v?{...v,item_name:e.target.value}:v)}/></label>
   <label>الاسم بالإنجليزية<input value={editing.item_name_en||""} onChange={e=>setEditing(v=>v?{...v,item_name_en:e.target.value}:v)}/></label>
   <label>الباركود<input value={editing.barcode||""} onChange={e=>setEditing(v=>v?{...v,barcode:e.target.value}:v)}/></label>
   <label>الفئة الثانوية<select value={editing.category_id||""} onChange={e=>setEditing(v=>v?{...v,category_id:e.target.value||null}:v)}><option value="">اختر الفئة</option>{categories.map(c=><option key={c.id} value={c.id}>{c.code} · {c.name}</option>)}</select></label>
   <label>البراند / الماركة<select value={editing.brand_id||""} onChange={e=>setEditing(v=>v?{...v,brand_id:e.target.value||null}:v)}><option value="">اختر البراند</option>{brands.map(b=><option key={b.id} value={b.id}>{b.code} · {b.name}</option>)}</select></label>
   <label>الوحدة الأساسية<input value={editing.base_unit} onChange={e=>setEditing(v=>v?{...v,base_unit:e.target.value}:v)}/></label>
   <label>سعر الشراء<input type="number" min="0" value={editing.purchase_price} onChange={e=>setEditing(v=>v?{...v,purchase_price:Number(e.target.value)}:v)}/></label>
   <label>سعر البيع<input type="number" min="0" value={editing.sale_price} onChange={e=>setEditing(v=>v?{...v,sale_price:Number(e.target.value)}:v)}/></label>
   <label>حد إعادة الطلب<input type="number" min="0" value={editing.reorder_level} onChange={e=>setEditing(v=>v?{...v,reorder_level:Number(e.target.value)}:v)}/></label>
   <label>الضريبة %<input type="number" min="0" value={editing.tax_rate} onChange={e=>setEditing(v=>v?{...v,tax_rate:Number(e.target.value)}:v)}/></label>
   <label>حد الخصم %<input type="number" min="0" value={editing.discount_limit} onChange={e=>setEditing(v=>v?{...v,discount_limit:Number(e.target.value)}:v)}/></label>
   <label>الحالة<select value={editing.is_active?"true":"false"} onChange={e=>setEditing(v=>v?{...v,is_active:e.target.value==="true"}:v)}><option value="true">نشط</option><option value="false">موقوف</option></select></label>
  </div><div className="li-unit-list">{unitRows.map(u=><span className="li-unit" key={u.id}>{u.unit_name} · ×{u.conversion_factor}{u.is_base_unit?" · أساسية":""}{u.is_implicit?" · تلقائية مخفية":""}{!u.is_selectable?" · غير قابلة للاختيار":""}</span>)}</div><div className="li-editor-actions"><button className="li-action li-primary" disabled={saving} onClick={()=>window.dispatchEvent(new Event("silsila:edit-save"))}><Save size={15}/>{saving?"جارٍ الحفظ":"حفظ التعديلات"}</button><button className="li-action" onClick={()=>window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",bubbles:true}))}><X size={15}/> إلغاء</button></div></div></EditDrawer>}
  {notice&&<div className="li-note">{notice}</div>}
  <div className="li-sub"><Tags size={14}/> ربط الفئات والبراندات من السجلات المركزية. <Award size={14}/> أكواد الأصناف لا تُكتب يدويًا؛ المولّد المركزي يحددها عند إنشاء صنف جديد.</div>
 </section>;
}
