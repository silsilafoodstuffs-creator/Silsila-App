import {useEffect,useRef,useState} from "react";
import type {ReactNode} from "react";
import {AlertTriangle,Save,X,Pencil,RotateCcw} from "lucide-react";

type Props={
 title:string;
 dirty:boolean;
 saving?:boolean;
 error?:string;
 onSave:()=>Promise<boolean>;
 onDiscard:()=>void;
 onClose:()=>void;
 onSaveError?:()=>void;
 initialMode?:"view"|"edit";
 canEdit?:boolean;
 children:ReactNode;
};

export default function EditDrawer({title,dirty,saving=false,onSave,onDiscard,onClose,onSaveError,initialMode="edit",canEdit=true,children,error=""}:Props){
 const [confirmOpen,setConfirmOpen]=useState(false);
 const [viewMode,setViewMode]=useState(initialMode==="view");
 const [saveError,setSaveError]=useState("");
 const [internalSaving,setInternalSaving]=useState(false);
 const isSaving=saving||internalSaving;
 const busy=useRef(false);
 const requestClose=()=>{if(isSaving||busy.current)return;if(dirty)setConfirmOpen(true);else onClose();};
 useEffect(()=>{window.dispatchEvent(new CustomEvent("silsila:edit-state",{detail:{dirty}}));},[dirty]);
 useEffect(()=>()=>{window.dispatchEvent(new Event("silsila:edit-closed"));},[]);
 useEffect(()=>{
  const key=(event:KeyboardEvent)=>{if(event.key==="Escape"){event.preventDefault();if(confirmOpen){setConfirmOpen(false);window.dispatchEvent(new Event("silsila:edit-navigation-cancel"));}else requestClose();}};
  const externalClose=()=>requestClose();
  const directSave=()=>{if(!isSaving)setConfirmOpen(true);};
  const beforeUnload=(event:BeforeUnloadEvent)=>{if(dirty){event.preventDefault();event.returnValue="";}};
  window.addEventListener("keydown",key);
  window.addEventListener("silsila:edit-request-close",externalClose);
  window.addEventListener("silsila:edit-save",directSave);
  window.addEventListener("beforeunload",beforeUnload);
  return()=>{window.removeEventListener("keydown",key);window.removeEventListener("silsila:edit-request-close",externalClose);window.removeEventListener("silsila:edit-save",directSave);window.removeEventListener("beforeunload",beforeUnload);};
 },[confirmOpen,dirty,isSaving,onSave,onSaveError,onClose]);
 const saveAndClose=async()=>{
  if(busy.current||isSaving)return;
  busy.current=true;setInternalSaving(true);
  try{setSaveError("");const saved=await onSave();if(saved){setConfirmOpen(false);onClose();}}
  catch(error){onSaveError?.();setSaveError(error instanceof Error?error.message:"تعذر حفظ التعديلات. النافذة ما زالت مفتوحة.");}
  finally{busy.current=false;setInternalSaving(false);}
 };
 const discardAndClose=()=>{onDiscard();setConfirmOpen(false);onClose();};
 return <div className="silsila-edit-layer" dir="rtl">
  <button className="silsila-edit-scrim" aria-label="إغلاق نافذة التعديل" onClick={requestClose}/>
  <aside className="silsila-edit-drawer" role="dialog" aria-modal="true" aria-label={title}>
   <header className="silsila-edit-drawer-head"><div><small>سلسلة · {viewMode?"معاينة البيانات":"تعديل البيانات"}</small><h2>{title}</h2></div><div className="silsila-edit-drawer-tools">{viewMode?<button type="button" className="drawer-edit-toggle" onClick={()=>setViewMode(false)} disabled={isSaving||!canEdit}><Pencil size={15}/> تعديل</button>:<><button type="button" className="drawer-edit-toggle" onClick={()=>{onDiscard();setViewMode(true);}} disabled={isSaving}><RotateCcw size={15}/> العدول عن التعديل</button><button type="button" className="drawer-save-toggle" onClick={()=>{if(dirty)setConfirmOpen(true);else setViewMode(true);}} disabled={isSaving||!canEdit}><Save size={15}/> حفظ</button></>}<button type="button" aria-label="إغلاق" onClick={requestClose} disabled={isSaving}><X size={19}/></button></div></header>
   <div className="silsila-edit-drawer-body">{(error||saveError)&&<div role="alert" className="silsila-edit-inline-error">{error||saveError}</div>}<fieldset disabled={viewMode} className="silsila-edit-drawer-fieldset">{children}</fieldset></div>
  </aside>
  {confirmOpen&&<div className="silsila-edit-confirm-backdrop" role="presentation">
   <section className="silsila-edit-confirm" role="alertdialog" aria-modal="true" aria-labelledby="silsila-edit-confirm-title">
    <div className="silsila-edit-confirm-icon"><AlertTriangle size={22}/></div>
    <h3 id="silsila-edit-confirm-title">هل ترغب في حفظ التعديلات؟</h3>
    <p>لديك تغييرات لم يتم حفظها بعد. اختر كيف تريد المتابعة.</p>
    {(error||saveError)&&<p role="alert" className="silsila-edit-save-error">{error||saveError}</p>}
    <div className="silsila-edit-confirm-actions">
     <button className="primary" type="button" onClick={()=>void saveAndClose()} disabled={isSaving}><Save size={15}/>{isSaving?"جارٍ الحفظ...":"نعم، حفظ التعديلات"}</button>
     <button className="danger" type="button" onClick={discardAndClose} disabled={isSaving}>لا، تجاهل التعديلات</button>
     <button className="quiet" type="button" onClick={()=>{setConfirmOpen(false);window.dispatchEvent(new Event("silsila:edit-navigation-cancel"));}} disabled={isSaving}>إلغاء الأمر</button>
    </div>
   </section>
  </div>}
  <style>{`.silsila-edit-layer{position:fixed;inset:0;z-index:1200;direction:rtl}.silsila-edit-scrim{position:absolute;inset:0;width:100%;height:100%;background:#160b22a6;cursor:default}.silsila-edit-drawer{position:absolute;inset-block:0;left:0;width:min(620px,94vw);background:#fff;box-shadow:18px 0 55px #160b2240;display:flex;flex-direction:column;animation:silsilaDrawerIn .22s ease-out}.silsila-edit-drawer-head{min-height:76px;padding:14px 18px;background:#3E007D;color:#fff;display:flex;align-items:center;justify-content:space-between;gap:12px}.silsila-edit-drawer-head small{font-size:10px;color:#e8d9f7}.silsila-edit-drawer-head h2{margin:2px 0 0;font-size:19px}.silsila-edit-drawer-tools{display:flex;align-items:center;gap:7px}.silsila-edit-drawer-tools button{min-height:36px;border-radius:8px;padding:0 10px;background:#ffffff20;color:#fff;display:flex;align-items:center;justify-content:center;gap:6px;font:inherit;font-size:12px}.silsila-edit-drawer-tools .drawer-save-toggle{background:#FFA015;color:#241735;font-weight:800}.silsila-edit-drawer-fieldset{display:contents;border:0;margin:0;padding:0;min-width:0}.silsila-edit-drawer-fieldset:disabled{opacity:.9}.silsila-edit-drawer-fieldset:disabled input,.silsila-edit-drawer-fieldset:disabled select,.silsila-edit-drawer-fieldset:disabled textarea{cursor:default;background:#f8f6fa;color:#51445C}.silsila-edit-drawer-head button[aria-label="إغلاق"]{width:36px;height:36px;border-radius:9px;background:#ffffff20;color:#fff;display:grid;place-items:center;padding:0}.silsila-edit-drawer-body{padding:16px;overflow:auto;min-height:0;flex:1}.silsila-edit-drawer-body>.li-editor,.silsila-edit-drawer-body>.pp-editor{border:0;border-radius:0;box-shadow:none;padding:0}.silsila-edit-confirm-backdrop{position:absolute;inset:0;background:#160b2266;display:grid;place-items:center;padding:18px;z-index:2}.silsila-edit-confirm{width:min(420px,100%);background:#fff;border-radius:16px;padding:22px;box-shadow:0 20px 65px #160b2255;text-align:center}.silsila-edit-confirm-icon{width:46px;height:46px;border-radius:50%;background:#fff4df;color:#9a6200;display:grid;place-items:center;margin:0 auto 12px}.silsila-edit-confirm h3{margin:0;color:#3E007D;font-size:18px}.silsila-edit-confirm p{color:#756984;font-size:13px;line-height:1.7}.silsila-edit-confirm-actions{display:grid;gap:8px;margin-top:16px}.silsila-edit-confirm-actions button{min-height:40px;border-radius:9px;padding:8px 12px;display:flex;align-items:center;justify-content:center;gap:7px;font:inherit}.silsila-edit-confirm-actions .primary{background:#3E007D;color:#fff}.silsila-edit-confirm-actions .danger{background:#fff1ef;color:#a33a31}.silsila-edit-confirm-actions .quiet{background:#f4f0f7;color:#59476a}.silsila-edit-confirm-actions button:disabled{opacity:.55;cursor:wait}.silsila-edit-inline-error{margin-bottom:12px;padding:10px 12px;border-radius:9px;background:#fff1ef;color:#a33a31;font-size:12px}.silsila-edit-save-error{color:#a33a31;background:#fff1ef;border-radius:8px;padding:9px;font-size:12px}@keyframes silsilaDrawerIn{from{transform:translateX(-24px);opacity:.7}to{transform:translateX(0);opacity:1}}@media(max-width:600px){.silsila-edit-drawer{width:100vw}.silsila-edit-drawer-body{padding:12px}}`}</style>
 </div>;
}
