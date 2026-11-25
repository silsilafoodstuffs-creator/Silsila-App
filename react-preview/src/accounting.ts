export type JournalLine = { account:string; debit:number; credit:number };
export type JournalEntry = { id:string; sourceId:string; sourceType:"sale"|"purchase"|"receipt"|"payment"; date:string; party:string; description:string; lines:JournalLine[]; postedAt:string };
const KEY="silsila-react-preview:accounting:journal";
export const readJournal=():JournalEntry[]=>{try{const value=localStorage.getItem(KEY);return value?JSON.parse(value):[]}catch{return []}};
export const addJournalEntry=(entry:JournalEntry)=>{const current=readJournal();if(current.some(x=>x.sourceId===entry.sourceId))return false;const debit=entry.lines.reduce((s,l)=>s+l.debit,0),credit=entry.lines.reduce((s,l)=>s+l.credit,0);if(!entry.lines.length||entry.lines.some(l=>!l.account.trim()||!Number.isFinite(l.debit)||!Number.isFinite(l.credit)||l.debit<0||l.credit<0||(l.debit>0&&l.credit>0))||Math.abs(debit-credit)>0.005)throw new Error("القيد غير صالح أو غير متوازن؛ لم يتم الترحيل.");localStorage.setItem(KEY,JSON.stringify([entry,...current]));return true;};
const line=(account:string,debit=0,credit=0)=>({account,debit:Number(debit.toFixed(2)),credit:Number(credit.toFixed(2))});
const id=()=> "JRN-"+Date.now().toString(36).toUpperCase()+"-"+Math.random().toString(36).slice(2,7).toUpperCase();
export function postDocumentJournal(input:{sourceId:string;sourceType:"sale"|"purchase";date:string;party:string;total:number;subtotal:number;tax:number;payment:string}){
 const cash=input.payment==="نقدي"?"الخزينة الرئيسية":input.payment==="تحويل بنكي"?"البنك الرئيسي":input.payment==="بطاقة"?"حسابات التحصيل الإلكتروني":"العملاء";
 const lines:JournalLine[]=input.sourceType==="sale"
 ?[line(cash,input.total),line("مبيعات البضائع",0,input.subtotal),...(input.tax>0?[line("ضريبة القيمة المضافة - مخرجات",0,input.tax)]:[])]
 :[line("مخزون البضائع",input.subtotal),...(input.tax>0?[line("ضريبة القيمة المضافة - مدخلات",input.tax)]:[]),line(input.payment==="نقدي"?"الخزينة الرئيسية":input.payment==="تحويل بنكي"?"البنك الرئيسي":input.payment==="بطاقة"?"حسابات الدفع الإلكتروني":"الموردون",0,input.total)];
 return addJournalEntry({id:id(),sourceId:input.sourceId,sourceType:input.sourceType,date:input.date,party:input.party,description:input.sourceType==="sale"?"ترحيل فاتورة بيع":"ترحيل فاتورة شراء",lines,postedAt:new Date().toISOString()});
}
export function postVoucherJournal(input:{sourceId:string;sourceType:"receipt"|"payment";date:string;party:string;amount:number;method:string;reference:string}){
 const cash=input.method==="نقدي"?"الخزينة الرئيسية":input.method==="تحويل بنكي"?"البنك الرئيسي":input.method==="شيك"?"شيكات تحت التحصيل":input.sourceType==="receipt"?"حسابات التحصيل الإلكتروني":"حسابات الدفع الإلكتروني";
 const lines:JournalLine[]=input.sourceType==="receipt"?[line(cash,input.amount),line("العملاء",0,input.amount)]:[line("الموردون",input.amount),line(cash,0,input.amount)];
 return addJournalEntry({id:id(),sourceId:input.sourceId,sourceType:input.sourceType,date:input.date,party:input.party,description:input.sourceType==="receipt"?"ترحيل سند قبض":"ترحيل سند صرف",lines,postedAt:new Date().toISOString()});
}
