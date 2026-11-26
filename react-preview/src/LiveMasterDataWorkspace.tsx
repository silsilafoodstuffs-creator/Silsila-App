import {useEffect,useMemo,useState} from "react";
import {supabase} from "./supabase";
import {Search,RefreshCw,MapPin,Tags,Award,Layers3,ChevronDown,ChevronLeft,Database,CheckCircle2} from "lucide-react";

type Kind="geo"|"categories"|"brands"|"groups";
type Row=Record<string,any>;
const config:Record<Kind,{title:string;table:string;fields:string;search:string[];icon:any;subtitle:string}> = {
 geo:{title:"البيانات الجغرافية",table:"erp_geographic_data",fields:"id,parent_id,geo_code,name_ar,name_en,level,is_active,hierarchical_code,admin_type",search:["geo_code","name_ar","name_en"],icon:MapPin,subtitle:"الشجرة الجغرافية الكاملة: دولة ومحافظات ووحدات إدارية ومناطق"},
 categories:{title:"فئات الأصناف",table:"erp_item_categories",fields:"id,parent_id,category_code,category_name,category_name_en,activity_code,is_active,show_in_app",search:["category_code","category_name","category_name_en"],icon:Tags,subtitle:"الفئات الرئيسية والفرعية والثانوية المرتبطة بالأصناف"},
 brands:{title:"البراندات",table:"erp_brands",fields:"id,brand_code,brand_name,brand_name_en,brand_group,brand_group_id,activity_code,is_active,show_in_app,display_order",search:["brand_code","brand_name","brand_name_en","brand_group"],icon:Award,subtitle:"العلامات التجارية وربطها بالمجموعات والأنشطة"},
 groups:{title:"مجموعات البراندات",table:"erp_brand_groups",fields:"id,group_code,group_name,group_name_en,activity_code,is_active,show_in_app",search:["group_code","group_name","group_name_en"],icon:Layers3,subtitle:"مجموعات العلامات التجارية حسب النشاط"}
};
export default function LiveMasterDataWorkspace({kind}:{kind:Kind}){
 const cfg=config[kind],Icon=cfg.icon,companyId=sessionStorage.getItem("silsila-company-id");
 const [rows,setRows]=useState<Row[]>([]),[query,setQuery]=useState(""),[columnFilters,setColumnFilters]=useState<Record<string,string>>({}),[level,setLevel]=useState("الكل"),[loading,setLoading]=useState(true),[error,setError]=useState(""),[total,setTotal]=useState(0),[page,setPage]=useState(0);
 const load=async()=>{if(!supabase||!companyId){setError("سجّل الدخول إلى المنشأة لعرض البيانات الفعلية.");setLoading(false);return;}setLoading(true);setError("");
 let q=supabase.from(cfg.table).select(cfg.fields,{count:"exact"}).eq("company_id",companyId).order(kind==="geo"?"geo_code":kind==="categories"?"category_code":kind==="brands"?"brand_code":"group_code").range(page*100,page*100+99);
 if(query.trim()){const parts=cfg.search.map(k=>k+" .ilike .%"+query.trim()+"%");q=q.or(parts.map(x=>x.replace(" .ilike .","")).join(","));}
 if(kind==="geo"&&level!=="الكل")q=q.eq("level",level);
 const {data,error,count}=await q;if(error){setError("تعذر تحميل البيانات من "+cfg.table+": "+error.message);setRows([]);}else{setRows(data||[]);setTotal(count||0);}setLoading(false);
 };
 useEffect(()=>{void load();},[companyId,kind,page,query,level]);
 const childCount=useMemo(()=>{const m=new Map<string,number>();for(const r of rows)if(r.parent_id)m.set(r.parent_id,(m.get(r.parent_id)||0)+1);return m;},[rows]);
 const columns=kind==="geo"?[{key:"code",label:"الكود"},{key:"name",label:"الاسم بالعربية"},{key:"name_en",label:"الاسم بالإنجليزية"},{key:"level",label:"المستوى"},{key:"admin",label:"التقسيم الإداري"},{key:"active",label:"نشط أو لا"}]:kind==="brands"?[{key:"code",label:"الكود"},{key:"name",label:"البراند"},{key:"group",label:"المجموعة"},{key:"activity",label:"النشاط"},{key:"active",label:"نشط أو لا"},{key:"app",label:"عرض بالتطبيق"}]:[{key:"code",label:"الكود"},{key:"name",label:kind==="categories"?"اسم الفئة":"المجموعة"},{key:"name_en",label:"الاسم بالإنجليزية"},{key:"activity",label:"النشاط"},{key:"active",label:"نشط أو لا"},{key:"app",label:"عرض بالتطبيق"}];
 const cellValue=(r:Row,key:string)=>key==="code"?(r.geo_code||r.category_code||r.brand_code||r.group_code||""):key==="name"?(r.name_ar||r.category_name||r.brand_name||r.group_name||""):key==="name_en"?(r.name_en||r.category_name_en||r.brand_name_en||r.group_name_en||""):key==="level"?r.level||"":key==="admin"?r.admin_type||"":key==="group"?r.brand_group||"":key==="activity"?r.activity_code||"":key==="active"?(r.is_active?"نشط":"لا"):key==="app"?(r.show_in_app?"نعم":"لا"):"";
 const visibleRows=useMemo(()=>rows.filter(r=>columns.every(col=>String(cellValue(r,col.key)).toLowerCase().includes((columnFilters[col.key]||"").toLowerCase()))),[rows,columns,columnFilters]);
 return <section className="live-master" dir="rtl">
  <div className="live-master-head"><div className="live-master-icon"><Icon size={22}/></div><div><small>بيانات المنشأة الحقيقية · Supabase</small><h2>{cfg.title}</h2><p>{cfg.subtitle}</p></div><span className="live-master-count"><Database size={15}/>{total.toLocaleString("ar-EG")} سجل</span></div>
  <div className="live-master-toolbar"><div className="live-master-search"><Search size={16}/><input value={query} onChange={e=>{setPage(0);setQuery(e.target.value)}} placeholder="ابحث بالكود أو الاسم..."/></div>{kind==="geo"&&<select value={level} onChange={e=>{setPage(0);setLevel(e.target.value)}}><option>الكل</option><option value="country">دولة</option><option value="governorate">محافظة</option><option value="district">قسم / مركز / مدينة</option><option value="area">منطقة / قرية</option></select>}<button onClick={()=>void load()}><RefreshCw size={15}/> تحديث</button></div>
  {error&&<div className="live-master-error">{error}</div>}
  <div className="live-master-summary"><span><CheckCircle2 size={15}/> البيانات محفوظة بالفعل في قاعدة المنشأة</span><span>عرض {rows.length.toLocaleString("ar-EG")} من {total.toLocaleString("ar-EG")}</span></div>
  <div className="live-master-table-wrap"><table><thead><tr className="column-filter-row">{columns.map(col=><th key={col.key}><input aria-label={"بحث "+col.label} placeholder={"بحث "+col.label} value={columnFilters[col.key]||""} onChange={e=>setColumnFilters(v=>({...v,[col.key]:e.target.value}))}/></th>)}</tr><tr>{columns.map(col=><th key={col.key}>{col.label}</th>)}</tr></thead><tbody>{visibleRows.map(r=><tr key={r.id}>{columns.map(col=><td key={col.key} className={col.key==="code"?"code-cell":""}>{col.key==="active"?<input className="silsila-bool-check" type="checkbox" checked={r.is_active===true} disabled readOnly aria-label={r.is_active===true?"نشط":"لا"}/>:col.key==="admin"?<>{cellValue(r,col.key)||"—"}{childCount.get(r.id)?<small> · {childCount.get(r.id)} تابع بالصفحة الحالية</small>:""}</>:cellValue(r,col.key)||"—"}</td>)}</tr>)}{!loading&&!visibleRows.length&&<tr><td colSpan={columns.length} className="live-master-empty">لا توجد سجلات مطابقة.</td></tr>}</tbody></table>{loading&&<div className="live-master-empty">جارٍ تحميل البيانات...</div>}</div>
  <div className="live-master-pagination"><button disabled={page===0} onClick={()=>setPage(p=>Math.max(0,p-1))}>السابق</button><span>صفحة {page+1} · 100 سجل لكل صفحة</span><button disabled={(page+1)*100>=total} onClick={()=>setPage(p=>p+1)}>التالي <ChevronLeft size={14}/></button></div>
  <p className="live-master-note">هذه الشاشة تقرأ السجلات الحالية مباشرة ولا تنشئ نسخة مكررة. إجراءات الإضافة والتعديل والاستيراد ستُفتح بعد مطابقة صلاحيات الكتابة والقيود المرجعية الخاصة بكل جدول.</p>
 </section>;
}
