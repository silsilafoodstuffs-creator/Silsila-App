import { AlertCircle,Construction,Database } from "lucide-react";

export default function PendingWorkspace({name}:{name:string}){
 return <section className="pending-workspace" dir="rtl">
  <div className="pending-workspace-icon"><Construction size={25}/></div>
  <div className="pending-workspace-copy">
   <small>سلسلة · استكمال النقل إلى التقنية الجديدة</small>
   <h2>{name}</h2>
   <p>هذه الشاشة لم تُستكمل مواءمتها الوظيفية مع النسخة القديمة بعد.</p>
   <div className="pending-workspace-status"><AlertCircle size={16}/> غير مفعّلة للتشغيل الفعلي</div>
   <div className="pending-workspace-note"><Database size={15}/> لن نعرض سجلات افتراضية أو نحفظ بيانات محلية على أنها بيانات منشأتك. سيتم تفعيل الشاشة بعد ربط جداولها وعملياتها وصلاحياتها واختبارها على قاعدة سلسلة.</div>
  </div>
 </section>;
}
