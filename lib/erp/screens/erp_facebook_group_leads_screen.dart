import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _fbPurple=Color(0xFF3E007D),_fbOrange=Color(0xFFFFA015);
class ErpFacebookGroupLeadsScreen extends StatefulWidget{
 const ErpFacebookGroupLeadsScreen({super.key,required this.companyId});
 final String? companyId;
 @override State<ErpFacebookGroupLeadsScreen> createState()=>_ErpFacebookGroupLeadsScreenState();
}
class _ErpFacebookGroupLeadsScreenState extends State<ErpFacebookGroupLeadsScreen>{
 SupabaseClient? db;bool loading=true,busy=false;String? error,message;
 String search='',groupFilter='all',classFilter='all';
 List<Map<String,dynamic>> groups=[],profiles=[],links=[],interactions=[];
 static const classes=['غير محدد','عميل محتمل','مورد محتمل','تاجر جملة','مستهلك','شركة شحن','غير مناسب'];
 String s(dynamic v)=>(v??'').toString().trim();
 @override void initState(){super.initState();try{db=Supabase.instance.client;}catch(_){}load();}
 @override void didUpdateWidget(covariant ErpFacebookGroupLeadsScreen old){super.didUpdateWidget(old);if(old.companyId!=widget.companyId)load();}
 String fbUrl(String value){
  final u=Uri.tryParse(value.trim());
  if(u==null||!u.hasAuthority||u.scheme!='https')throw const FormatException('أدخل رابط HTTPS صحيحاً.');
  final h=u.host.toLowerCase();
  if(!(h=='facebook.com'||h.endsWith('.facebook.com')||h=='fb.com'||h.endsWith('.fb.com')))throw const FormatException('يجب أن يكون الرابط تابعاً لفيسبوك.');
  final path=u.path.replaceAll(RegExp(r'/+
 }
 Future<void> load()async{
  if(db==null||(widget.companyId??'').isEmpty){if(mounted)setState(()=>loading=false);return;}
  setState(() { loading=true; error=null; message=null; });
  try{
   final r=await Future.wait([
    db!.from('erp_crm_facebook_groups').select().eq('company_id',widget.companyId!).order('group_name'),
    db!.from('erp_crm_facebook_profiles').select().eq('company_id',widget.companyId!).order('display_name'),
    db!.from('erp_crm_facebook_group_profiles').select().eq('company_id',widget.companyId!),
    db!.from('erp_crm_facebook_interactions').select().eq('company_id',widget.companyId!),
   ]);
   if(!mounted)return;setState((){
    groups=(r[0] as List).cast<Map<String,dynamic>>();profiles=(r[1] as List).cast<Map<String,dynamic>>();
    links=(r[2] as List).cast<Map<String,dynamic>>();interactions=(r[3] as List).cast<Map<String,dynamic>>();
    if(groupFilter!='all'&&!groups.any((g)=>s(g['id'])==groupFilter))groupFilter='all';
   });
  }catch(e){if(mounted)setState(()=>error='تعذر تحميل البيانات. تأكد من تطبيق ترحيل قاعدة البيانات والصلاحيات.\n'+e.toString());}
  finally{if(mounted)setState(()=>loading=false);}
 }
 List<Map<String,dynamic>> get visible=>profiles.where((p){
  final id=s(p['id']);final ids=links.where((l)=>s(l['profile_id'])==id).map((l)=>s(l['group_id'])).toSet();
  final names=groups.where((g)=>ids.contains(s(g['id']))).map((g)=>s(g['group_name'])).join(' ');
  final q=search.toLowerCase().trim();
  return ids.isNotEmpty&&(groupFilter=='all'||ids.contains(groupFilter))&&(classFilter=='all'||s(p['classification'])==classFilter)&&
   (q.isEmpty||(s(p['display_name'])+' '+names+' '+s(p['profile_url'])).toLowerCase().contains(q));
 }).toList();
 void toast(String m){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));}
 Future<void> save(Future<void> Function() fn,String ok)async{
  if(db==null||(widget.companyId??'').isEmpty){toast('اختر شركة نشطة أولاً.');return;}
  setState(() { busy=true; error=null; message=null; });
  try{await fn();await load();if(mounted)setState(()=>message=ok);}
  catch(e){if(mounted)setState(()=>error='تعذر حفظ البيانات: '+e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<Map<String,String>?> form(String title,List<String> labels,{Map<String,String> initial=const{}})async{
  final c=[for(var i=0;i<labels.length;i++)TextEditingController(text:initial['v'+i.toString()]??'')];
  String cls=initial['class']??classes.first;
  final result=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
   title:Text(title),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    for(var i=0;i<labels.length;i++)if(labels[i]!='تصنيف الحساب')Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c[i],maxLines:labels[i]=='ملاحظات'?3:1,decoration:InputDecoration(labelText:labels[i],border:const OutlineInputBorder()))),
    if(labels.contains('تصنيف الحساب'))DropdownButtonFormField<String>(value:cls,decoration:const InputDecoration(labelText:'تصنيف الحساب',border:OutlineInputBorder()),items:classes.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>refresh(()=>cls=v??cls)),
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,{for(var i=0;i<c.length;i++)'v'+i.toString():c[i].text.trim(),'class':cls}),child:const Text('حفظ'))],
  ))));
  for(final x in c){x.dispose();}return result;
 }
 Future<void> addGroup()async{
  final v=await form('إضافة جروب فيسبوك',['اسم الجروب','رابط الجروب','ملاحظات']);if(v==null)return;
  if(v['v0']!.isEmpty||v['v1']!.isEmpty){toast('اسم الجروب والرابط مطلوبان.');return;}
  await save(()async{await db!.from('erp_crm_facebook_groups').insert({'company_id':widget.companyId,'group_name':v['v0'],'group_url':fbUrl(v['v1']!), 'notes':v['v2'],'created_by':db!.auth.currentUser?.id});},'تمت إضافة الجروب.');
 }
 Future<void> addProfile()async{
  if(groups.isEmpty){toast('أضف جروباً أولاً.');return;}
  final v=await form('إضافة حساب إلى الجروب',['اسم الحساب أو المستخدم','رابط الملف الشخصي','رابط صورة الحساب (اختياري)','تصنيف الحساب','ملاحظات']);if(v==null)return;
  if(v['v0']!.isEmpty||v['v1']!.isEmpty){toast('اسم الحساب ورابطه مطلوبان.');return;}
  String gid=groupFilter=='all'?s(groups.first['id']):groupFilter;
  final chosen=await showDialog<String>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
   title:const Text('اختيار الجروب'),content:DropdownButtonFormField<String>(value:gid,items:groups.map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['group_name'])))).toList(),onChanged:(x){gid=x??gid;}),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,gid),child:const Text('متابعة'))])));
  if(chosen==null)return;
  await save(()async{
   final url=fbUrl(v['v1']!),av=v['v2']!.trim();
   if(av.isNotEmpty&&Uri.tryParse(av)?.scheme!='https')throw const FormatException('رابط الصورة يجب أن يبدأ بـ HTTPS.');
   final p=await db!.from('erp_crm_facebook_profiles').upsert({
    'company_id':widget.companyId,'display_name':v['v0'],'profile_url':url,'profile_url_normalized':Uri.parse(url).replace(query:'',fragment:'').toString(),
    'avatar_url':av.isEmpty?null:av,'classification':v['class'],'notes':v['v4'],'created_by':db!.auth.currentUser?.id,
   },onConflict:'company_id,profile_url_normalized').select().single();
   await db!.from('erp_crm_facebook_group_profiles').upsert({'company_id':widget.companyId,'group_id':chosen,'profile_id':p['id'],'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_id,profile_id',ignoreDuplicates:true);
  },'تم حفظ الحساب وربطه دون تكرار.');
 }
 Future<void> interaction(Map<String,dynamic> p)async{
  final v=await form('تسجيل تواصل مع '+s(p['display_name']),['نوع التواصل','ملاحظات']);if(v==null||v['v0']!.trim().isEmpty)return;
  await save(()async{await db!.from('erp_crm_facebook_interactions').insert({'company_id':widget.companyId,'profile_id':p['id'],'interaction_type':v['v0'],'notes':v['v1'],'created_by':db!.auth.currentUser?.id});},'تم تسجيل التواصل.');
 }
 Future<void> openProfile(String url)async{try{if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication))toast('تعذر فتح الرابط.');}catch(e){toast('تعذر فتح الملف الشخصي: '+e.toString());}}
 Future<void> exportExcel()async{
  final rows=<List<String>>[];
  for(final l in links){final pp=profiles.where((p)=>s(p['id'])==s(l['profile_id']));final gg=groups.where((g)=>s(g['id'])==s(l['group_id']));
   if(pp.isEmpty||gg.isEmpty)continue;final p=pp.first,g=gg.first;
   if(groupFilter!='all'&&s(g['id'])!=groupFilter)continue;if(classFilter!='all'&&s(p['classification'])!=classFilter)continue;
   final q=search.toLowerCase().trim();if(q.isNotEmpty&&!(s(p['display_name'])+' '+s(g['group_name'])).toLowerCase().contains(q))continue;
   rows.add([s(p['display_name']),s(g['group_name'])]);
  }
  if(rows.isEmpty){toast('لا توجد بيانات للتصدير.');return;}
  try{final book=xls.Excel.createExcel(),sh=book['حسابات الجروبات'];sh.appendRow([xls.TextCellValue('م'),xls.TextCellValue('اسم الحساب أو المستخدم'),xls.TextCellValue('اسم الجروب')]);
   for(var i=0;i<rows.length;i++){sh.appendRow([xls.IntCellValue(i+1),xls.TextCellValue(rows[i][0]),xls.TextCellValue(rows[i][1])]);}
   final b=book.encode();if(b==null||b.isEmpty)throw StateError('تعذر إنشاء ملف Excel.');
   await FileSaver.instance.saveFile(name:'silsila_facebook_groups_'+DateTime.now().millisecondsSinceEpoch.toString(),bytes:Uint8List.fromList(b),fileExtension:'xlsx',mimeType:MimeType.microsoftExcel);
   if(mounted)setState(()=>message='تم تصدير '+rows.length.toString()+' صفاً إلى Excel.');
  }catch(e){if(mounted)setState(()=>error='تعذر تصدير Excel: '+e.toString());}
 }
 Future<void> importExcel()async{
  try{
   final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const['xlsx'],withData:true);if(picked==null||picked.files.isEmpty)return;
   final b=picked.files.single.bytes;if(b==null||b.isEmpty)throw StateError('الملف فارغ.');
   final book=xls.Excel.decodeBytes(b),sheet=book.tables.values.firstWhere((x)=>x.rows.isNotEmpty),rows=sheet.rows;
   String cell(int r,int c)=>c<rows[r].length?(rows[r][c]?.value?.toString().trim()??''):'';
   final h=rows.first.map((x)=>x?.value?.toString().trim()??'').toList();
   int col(List<String> names)=>h.indexWhere((x)=>names.any((n)=>x.toLowerCase()==n.toLowerCase()));
   final ni=col(['اسم الحساب أو المستخدم','اسم الحساب']),pi=col(['رابط الحساب','رابط الملف الشخصي']),gi=col(['اسم الجروب']),ui=col(['رابط الجروب']);
   if([ni,pi,gi,ui].any((x)=>x<0))throw StateError('الأعمدة المطلوبة: اسم الحساب أو المستخدم، رابط الحساب، اسم الجروب، رابط الجروب.');
   final data=<List<String>>[];for(var i=1;i<rows.length;i++){final row=[cell(i,ni),cell(i,pi),cell(i,gi),cell(i,ui)];if(row.every((x)=>x.isEmpty))continue;if(row.any((x)=>x.isEmpty))throw FormatException('بيانات ناقصة في الصف '+(i+1).toString());data.add(row);}
   if(data.isEmpty)throw StateError('لا توجد صفوف مكتملة.');
   final ok=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('تأكيد الاستيراد'),content:Text('سيتم استيراد '+data.length.toString()+' صفاً ودمج الحسابات المتكررة حسب الرابط.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('استيراد'))])));
   if(ok!=true)return;
   await save(()async{for(final row in data){
    final pu=fbUrl(row[1]),gu=fbUrl(row[3]);
    final p=await db!.from('erp_crm_facebook_profiles').upsert({'company_id':widget.companyId,'display_name':row[0],'profile_url':pu,'profile_url_normalized':Uri.parse(pu).replace(query:'',fragment:'').toString(),'classification':'غير محدد','source_method':'xlsx_import','created_by':db!.auth.currentUser?.id},onConflict:'company_id,profile_url_normalized').select().single();
    final g=await db!.from('erp_crm_facebook_groups').upsert({'company_id':widget.companyId,'group_name':row[2],'group_url':gu,'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_url_normalized').select().single();
    await db!.from('erp_crm_facebook_group_profiles').upsert({'company_id':widget.companyId,'group_id':g['id'],'profile_id':p['id'],'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_id,profile_id',ignoreDuplicates:true);
   }},'تم استيراد '+data.length.toString()+' صفاً.');
  }catch(e){if(mounted)setState(()=>error='تعذر استيراد Excel: '+e.toString());}
 }
 Widget action(String t,IconData i,Color c,VoidCallback? fn)=>FilledButton.icon(onPressed:busy?null:fn,style:FilledButton.styleFrom(backgroundColor:c,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:12,vertical:12)),icon:Icon(i,size:18),label:Text(t));
 Widget metric(String label,int n)=>Expanded(child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:const Color(0xFFF7F3FA),borderRadius:BorderRadius.circular(10)),child:Column(children:[Text(n.toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_fbPurple)),Text(label,style:const TextStyle(fontSize:10,color:Colors.black54))])));
 @override Widget build(BuildContext context){
  final rows=visible;
  return Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_fbPurple,Color(0xFF7140A4)]),borderRadius:BorderRadius.circular(17)),child:Row(children:[const Icon(Icons.groups_rounded,color:_fbOrange,size:38),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('إضافة حسابات جروبات فيسبوك',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),Text('إدارة الجروبات والحسابات المحتملة داخل علاقات العملاء',style:TextStyle(color:Color(0xFFEDE3F7)))])),IconButton(onPressed:busy||loading?null:load,icon:const Icon(Icons.refresh,color:Colors.white))])),
   const SizedBox(height:10),
   Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(12)),child:const Text('تنبيه تكامل: واجهة Meta الرسمية لا تتيح حالياً جلب أعضاء مجموعات Facebook. لا يوجد سحب آلي أو طلب كلمة مرور. أضف الحسابات التي تختارها يدوياً أو استورد بيانات مصرحاً لك باستخدامها، وافتح الملف لإرسال طلب الصداقة بنفسك.',style:TextStyle(color:Color(0xFF795000),height:1.5,fontWeight:FontWeight.w600))),
   const SizedBox(height:10),
   Wrap(spacing:8,runSpacing:8,children:[action('إضافة جروب',Icons.group_add,_fbPurple,addGroup),action('إضافة حساب',Icons.person_add_alt_1,_fbOrange,groups.isEmpty?null:addProfile),action('استيراد Excel',Icons.file_upload,Colors.green,importExcel),action('تصدير Excel',Icons.file_download,Colors.green,profiles.isEmpty?null:exportExcel),action('فتح فيسبوك',Icons.open_in_new,const Color(0xFF1877F2),()=>openProfile('https://www.facebook.com/'))]),
   const SizedBox(height:10),Row(children:[metric('الجروبات',groups.length),const SizedBox(width:7),metric('الحسابات الفريدة',profiles.length),const SizedBox(width:7),metric('سجلات التواصل',interactions.length)]),
   const SizedBox(height:10),
   Wrap(spacing:8,runSpacing:8,children:[
    SizedBox(width:245,child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(labelText:'بحث باسم الحساب أو الجروب',prefixIcon:Icon(Icons.search),border:OutlineInputBorder(),isDense:true))),
    SizedBox(width:210,child:DropdownButtonFormField<String>(value:groups.any((g)=>s(g['id'])==groupFilter)?groupFilter:'all',isExpanded:true,decoration:const InputDecoration(labelText:'الجروب',border:OutlineInputBorder(),isDense:true),items:[const DropdownMenuItem(value:'all',child:Text('كل الجروبات')),...groups.map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['group_name']),overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setState(()=>groupFilter=v??'all'))),
    SizedBox(width:190,child:DropdownButtonFormField<String>(value:classFilter,isExpanded:true,decoration:const InputDecoration(labelText:'التصنيف',border:OutlineInputBorder(),isDense:true),items:[const DropdownMenuItem(value:'all',child:Text('كل التصنيفات')),...classes.map((v)=>DropdownMenuItem(value:v,child:Text(v)))],onChanged:(v)=>setState(()=>classFilter=v??'all'))),
   ]),
   if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,style:const TextStyle(color:Colors.red))),
   if(message!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(message!,style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w700))),
   const SizedBox(height:8),
   if(loading)const Expanded(child:Center(child:CircularProgressIndicator()))
   else if(db==null||(widget.companyId??'').isEmpty)const Expanded(child:Center(child:Text('اختر شركة نشطة لبدء إدارة حسابات الجروبات.')))
   else if(rows.isEmpty)Expanded(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.groups_2_outlined,size:50,color:_fbPurple),const SizedBox(height:8),const Text('لا توجد حسابات مرتبطة بالجروب المحدد.'),TextButton.icon(onPressed:groups.isEmpty?addGroup:addProfile,icon:const Icon(Icons.add),label:Text(groups.isEmpty?'إضافة أول جروب':'إضافة حساب'))])))
   else Expanded(child:ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(ctx,i){
    final p=rows[i],pid=s(p['id']);final gids=links.where((l)=>s(l['profile_id'])==pid).map((l)=>s(l['group_id'])).toSet();
    final names=groups.where((g)=>gids.contains(s(g['id']))).map((g)=>s(g['group_name'])).join(' • ');final av=s(p['avatar_url']);
    return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE9E2F0)),borderRadius:BorderRadius.circular(13)),child:Row(children:[
     CircleAvatar(radius:24,backgroundColor:const Color(0xFFF0E9F7),backgroundImage:av.isEmpty?null:NetworkImage(av),child:av.isEmpty?const Icon(Icons.person,color:_fbPurple):null),
     const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s(p['display_name']),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),Text(names,style:const TextStyle(color:Colors.black54,fontSize:12)),Text(s(p['classification']),style:const TextStyle(color:_fbPurple,fontSize:12,fontWeight:FontWeight.w700))])),
     IconButton(tooltip:'فتح الملف لإرسال طلب صداقة يدوياً',onPressed:()=>openProfile(s(p['profile_url'])),icon:const Icon(Icons.person_search,color:Color(0xFF1877F2))),
     IconButton(tooltip:'تسجيل تواصل',onPressed:()=>interaction(p),icon:const Icon(Icons.forum_outlined,color:_fbPurple)),
     PopupMenuButton<String>(onSelected:(v)=>v=='edit'?editProfile(p):linkAnother(p),itemBuilder:(_)=>const[PopupMenuItem(value:'link',child:Text('ربط بجروب آخر')),PopupMenuItem(value:'edit',child:Text('تعديل البيانات'))]),
    ]));
   })),
  ]));
 }
 Future<void> linkAnother(Map<String,dynamic> p)async{
  String gid=groups.isEmpty?'':s(groups.first['id']);
  final v=await showDialog<String>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('ربط الحساب بجروب آخر'),content:DropdownButtonFormField<String>(value:gid,items:groups.map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['group_name'])))).toList(),onChanged:(x)=>refresh(()=>gid=x??gid)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,gid),child:const Text('ربط'))])));
  if(v==null)return;await save(()async{await db!.from('erp_crm_facebook_group_profiles').upsert({'company_id':widget.companyId,'group_id':v,'profile_id':p['id'],'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_id,profile_id',ignoreDuplicates:true);},'تم الربط دون تكرار الحساب.');
 }
 Future<void> editProfile(Map<String,dynamic> p)async{
  final v=await form('تعديل بيانات الحساب',['اسم الحساب أو المستخدم','رابط الملف الشخصي','رابط الصورة','تصنيف الحساب','ملاحظات'],initial:{'v0':s(p['display_name']),'v1':s(p['profile_url']),'v2':s(p['avatar_url']),'v4':s(p['notes']),'class':s(p['classification'])});if(v==null)return;
  await save(()async{final u=fbUrl(v['v1']!),a=v['v2']!.trim();if(a.isNotEmpty&&Uri.tryParse(a)?.scheme!='https')throw const FormatException('رابط الصورة يجب أن يبدأ HTTPS.');
   await db!.from('erp_crm_facebook_profiles').update({'display_name':v['v0'],'profile_url':u,'profile_url_normalized':Uri.parse(u).replace(query:'',fragment:'').toString(),'avatar_url':a.isEmpty?null:a,'classification':v['class'],'notes':v['v4']}).eq('id',p['id']).eq('company_id',widget.companyId!);
  },'تم تحديث بيانات الحساب.');
 }
}
class _Field{const _Field(this.key,this.label,{this.url=false,this.multi=false,this.hint});final String key,label;final bool url,multi;final String? hint;}
),'');
  return Uri.https(h,path.isEmpty?'/':path).toString();
 }
 Future<void> load()async{
  if(db==null||(widget.companyId??'').isEmpty){if(mounted)setState(()=>loading=false);return;}
  setState(()=>{loading=true,error=null,message=null});
  try{
   final r=await Future.wait([
    db!.from('erp_crm_facebook_groups').select().eq('company_id',widget.companyId!).order('group_name'),
    db!.from('erp_crm_facebook_profiles').select().eq('company_id',widget.companyId!).order('display_name'),
    db!.from('erp_crm_facebook_group_profiles').select().eq('company_id',widget.companyId!),
    db!.from('erp_crm_facebook_interactions').select().eq('company_id',widget.companyId!),
   ]);
   if(!mounted)return;setState((){
    groups=(r[0] as List).cast<Map<String,dynamic>>();profiles=(r[1] as List).cast<Map<String,dynamic>>();
    links=(r[2] as List).cast<Map<String,dynamic>>();interactions=(r[3] as List).cast<Map<String,dynamic>>();
    if(groupFilter!='all'&&!groups.any((g)=>s(g['id'])==groupFilter))groupFilter='all';
   });
  }catch(e){if(mounted)setState(()=>error='تعذر تحميل البيانات. تأكد من تطبيق ترحيل قاعدة البيانات والصلاحيات.\n'+e.toString());}
  finally{if(mounted)setState(()=>loading=false);}
 }
 List<Map<String,dynamic>> get visible=>profiles.where((p){
  final id=s(p['id']);final ids=links.where((l)=>s(l['profile_id'])==id).map((l)=>s(l['group_id'])).toSet();
  final names=groups.where((g)=>ids.contains(s(g['id']))).map((g)=>s(g['group_name'])).join(' ');
  final q=search.toLowerCase().trim();
  return ids.isNotEmpty&&(groupFilter=='all'||ids.contains(groupFilter))&&(classFilter=='all'||s(p['classification'])==classFilter)&&
   (q.isEmpty||(s(p['display_name'])+' '+names+' '+s(p['profile_url'])).toLowerCase().contains(q));
 }).toList();
 void toast(String m){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));}
 Future<void> save(Future<void> Function() fn,String ok)async{
  if(db==null||(widget.companyId??'').isEmpty){toast('اختر شركة نشطة أولاً.');return;}
  setState(()=>{busy=true,error=null,message=null});
  try{await fn();await load();if(mounted)setState(()=>message=ok);}
  catch(e){if(mounted)setState(()=>error='تعذر حفظ البيانات: '+e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<Map<String,String>?> form(String title,List<String> labels,{Map<String,String> initial=const{}})async{
  final c=[for(var i=0;i<labels.length;i++)TextEditingController(text:initial['v'+i.toString()]??'')];
  String cls=initial['class']??classes.first;
  final result=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
   title:Text(title),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    for(var i=0;i<labels.length;i++)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c[i],maxLines:labels[i]=='ملاحظات'?3:1,decoration:InputDecoration(labelText:labels[i],border:const OutlineInputBorder()))),
    if(labels.contains('تصنيف الحساب'))DropdownButtonFormField<String>(value:cls,decoration:const InputDecoration(labelText:'تصنيف الحساب',border:OutlineInputBorder()),items:classes.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>refresh(()=>cls=v??cls)),
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,{for(var i=0;i<c.length;i++)'v'+i.toString():c[i].text.trim(),'class':cls}),child:const Text('حفظ'))],
  ))));
  for(final x in c){x.dispose();}return result;
 }
 Future<void> addGroup()async{
  final v=await form('إضافة جروب فيسبوك',['اسم الجروب','رابط الجروب','ملاحظات']);if(v==null)return;
  if(v['v0']!.isEmpty||v['v1']!.isEmpty){toast('اسم الجروب والرابط مطلوبان.');return;}
  await save(()async{await db!.from('erp_crm_facebook_groups').insert({'company_id':widget.companyId,'group_name':v['v0'],'group_url':fbUrl(v['v1']!), 'notes':v['v2'],'created_by':db!.auth.currentUser?.id});},'تمت إضافة الجروب.');
 }
 Future<void> addProfile()async{
  if(groups.isEmpty){toast('أضف جروباً أولاً.');return;}
  final v=await form('إضافة حساب إلى الجروب',['اسم الحساب أو المستخدم','رابط الملف الشخصي','رابط صورة الحساب (اختياري)','ملاحظات']);if(v==null)return;
  if(v['v0']!.isEmpty||v['v1']!.isEmpty){toast('اسم الحساب ورابطه مطلوبان.');return;}
  String gid=groupFilter=='all'?s(groups.first['id']):groupFilter;
  final chosen=await showDialog<String>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
   title:const Text('اختيار الجروب'),content:DropdownButtonFormField<String>(value:gid,items:groups.map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['group_name'])))).toList(),onChanged:(x){gid=x??gid;}),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,gid),child:const Text('متابعة'))])));
  if(chosen==null)return;
  await save(()async{
   final url=fbUrl(v['v1']!),av=v['v2']!.trim();
   if(av.isNotEmpty&&Uri.tryParse(av)?.scheme!='https')throw const FormatException('رابط الصورة يجب أن يبدأ بـ HTTPS.');
   final p=await db!.from('erp_crm_facebook_profiles').upsert({
    'company_id':widget.companyId,'display_name':v['v0'],'profile_url':url,'profile_url_normalized':Uri.parse(url).replace(query:'',fragment:'').toString(),
    'avatar_url':av.isEmpty?null:av,'classification':'غير محدد','notes':v['v3'],'created_by':db!.auth.currentUser?.id,
   },onConflict:'company_id,profile_url_normalized').select().single();
   await db!.from('erp_crm_facebook_group_profiles').upsert({'company_id':widget.companyId,'group_id':chosen,'profile_id':p['id'],'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_id,profile_id',ignoreDuplicates:true);
  },'تم حفظ الحساب وربطه دون تكرار.');
 }
 Future<void> interaction(Map<String,dynamic> p)async{
  final v=await form('تسجيل تواصل مع '+s(p['display_name']),['نوع التواصل','ملاحظات']);if(v==null||v['v0']!.trim().isEmpty)return;
  await save(()async{await db!.from('erp_crm_facebook_interactions').insert({'company_id':widget.companyId,'profile_id':p['id'],'interaction_type':v['v0'],'notes':v['v1'],'created_by':db!.auth.currentUser?.id});},'تم تسجيل التواصل.');
 }
 Future<void> openProfile(String url)async{try{if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication))toast('تعذر فتح الرابط.');}catch(e){toast('تعذر فتح الملف الشخصي: '+e.toString());}}
 Future<void> exportExcel()async{
  final rows=<List<String>>[];
  for(final l in links){final pp=profiles.where((p)=>s(p['id'])==s(l['profile_id']));final gg=groups.where((g)=>s(g['id'])==s(l['group_id']));
   if(pp.isEmpty||gg.isEmpty)continue;final p=pp.first,g=gg.first;
   if(groupFilter!='all'&&s(g['id'])!=groupFilter)continue;if(classFilter!='all'&&s(p['classification'])!=classFilter)continue;
   final q=search.toLowerCase().trim();if(q.isNotEmpty&&!(s(p['display_name'])+' '+s(g['group_name'])).toLowerCase().contains(q))continue;
   rows.add([s(p['display_name']),s(g['group_name'])]);
  }
  if(rows.isEmpty){toast('لا توجد بيانات للتصدير.');return;}
  try{final book=xls.Excel.createExcel(),sh=book['حسابات الجروبات'];sh.appendRow([xls.TextCellValue('م'),xls.TextCellValue('اسم الحساب أو المستخدم'),xls.TextCellValue('اسم الجروب')]);
   for(var i=0;i<rows.length;i++){sh.appendRow([xls.IntCellValue(i+1),xls.TextCellValue(rows[i][0]),xls.TextCellValue(rows[i][1])]);}
   final b=book.encode();if(b==null||b.isEmpty)throw StateError('تعذر إنشاء ملف Excel.');
   await FileSaver.instance.saveFile(name:'silsila_facebook_groups_'+DateTime.now().millisecondsSinceEpoch.toString(),bytes:Uint8List.fromList(b),fileExtension:'xlsx',mimeType:MimeType.microsoftExcel);
   if(mounted)setState(()=>message='تم تصدير '+rows.length.toString()+' صفاً إلى Excel.');
  }catch(e){if(mounted)setState(()=>error='تعذر تصدير Excel: '+e.toString());}
 }
 Future<void> importExcel()async{
  try{
   final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const['xlsx'],withData:true);if(picked==null||picked.files.isEmpty)return;
   final b=picked.files.single.bytes;if(b==null||b.isEmpty)throw StateError('الملف فارغ.');
   final book=xls.Excel.decodeBytes(b),sheet=book.tables.values.firstWhere((x)=>x.rows.isNotEmpty),rows=sheet.rows;
   String cell(int r,int c)=>c<rows[r].length?(rows[r][c]?.value?.toString().trim()??''):'';
   final h=rows.first.map((x)=>x?.value?.toString().trim()??'').toList();
   int col(List<String> names)=>h.indexWhere((x)=>names.any((n)=>x.toLowerCase()==n.toLowerCase()));
   final ni=col(['اسم الحساب أو المستخدم','اسم الحساب']),pi=col(['رابط الحساب','رابط الملف الشخصي']),gi=col(['اسم الجروب']),ui=col(['رابط الجروب']);
   if([ni,pi,gi,ui].any((x)=>x<0))throw StateError('الأعمدة المطلوبة: اسم الحساب أو المستخدم، رابط الحساب، اسم الجروب، رابط الجروب.');
   final data=<List<String>>[];for(var i=1;i<rows.length;i++){final row=[cell(i,ni),cell(i,pi),cell(i,gi),cell(i,ui)];if(row.every((x)=>x.isEmpty))continue;if(row.any((x)=>x.isEmpty))throw FormatException('بيانات ناقصة في الصف '+(i+1).toString());data.add(row);}
   if(data.isEmpty)throw StateError('لا توجد صفوف مكتملة.');
   final ok=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('تأكيد الاستيراد'),content:Text('سيتم استيراد '+data.length.toString()+' صفاً ودمج الحسابات المتكررة حسب الرابط.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('استيراد'))])));
   if(ok!=true)return;
   await save(()async{for(final row in data){
    final pu=fbUrl(row[1]),gu=fbUrl(row[3]);
    final p=await db!.from('erp_crm_facebook_profiles').upsert({'company_id':widget.companyId,'display_name':row[0],'profile_url':pu,'profile_url_normalized':Uri.parse(pu).replace(query:'',fragment:'').toString(),'classification':'غير محدد','source_method':'xlsx_import','created_by':db!.auth.currentUser?.id},onConflict:'company_id,profile_url_normalized').select().single();
    final g=await db!.from('erp_crm_facebook_groups').upsert({'company_id':widget.companyId,'group_name':row[2],'group_url':gu,'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_url_normalized').select().single();
    await db!.from('erp_crm_facebook_group_profiles').upsert({'company_id':widget.companyId,'group_id':g['id'],'profile_id':p['id'],'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_id,profile_id',ignoreDuplicates:true);
   }},'تم استيراد '+data.length.toString()+' صفاً.');
  }catch(e){if(mounted)setState(()=>error='تعذر استيراد Excel: '+e.toString());}
 }
 Widget action(String t,IconData i,Color c,VoidCallback? fn)=>FilledButton.icon(onPressed:busy?null:fn,style:FilledButton.styleFrom(backgroundColor:c,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:12,vertical:12)),icon:Icon(i,size:18),label:Text(t));
 Widget metric(String label,int n)=>Expanded(child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:const Color(0xFFF7F3FA),borderRadius:BorderRadius.circular(10)),child:Column(children:[Text(n.toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_fbPurple)),Text(label,style:const TextStyle(fontSize:10,color:Colors.black54))])));
 @override Widget build(BuildContext context){
  final rows=visible;
  return Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_fbPurple,Color(0xFF7140A4)]),borderRadius:BorderRadius.circular(17)),child:Row(children:[const Icon(Icons.groups_rounded,color:_fbOrange,size:38),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('إضافة حسابات جروبات فيسبوك',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),Text('إدارة الجروبات والحسابات المحتملة داخل علاقات العملاء',style:TextStyle(color:Color(0xFFEDE3F7)))])),IconButton(onPressed:busy||loading?null:load,icon:const Icon(Icons.refresh,color:Colors.white))])),
   const SizedBox(height:10),
   Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(12)),child:const Text('تنبيه تكامل: واجهة Meta الرسمية لا تتيح حالياً جلب أعضاء مجموعات Facebook. لا يوجد سحب آلي أو طلب كلمة مرور. أضف الحسابات التي تختارها يدوياً أو استورد بيانات مصرحاً لك باستخدامها، وافتح الملف لإرسال طلب الصداقة بنفسك.',style:TextStyle(color:Color(0xFF795000),height:1.5,fontWeight:FontWeight.w600))),
   const SizedBox(height:10),
   Wrap(spacing:8,runSpacing:8,children:[action('إضافة جروب',Icons.group_add,_fbPurple,addGroup),action('إضافة حساب',Icons.person_add_alt_1,_fbOrange,groups.isEmpty?null:addProfile),action('استيراد Excel',Icons.file_upload,Colors.green,importExcel),action('تصدير Excel',Icons.file_download,Colors.green,profiles.isEmpty?null:exportExcel),action('فتح فيسبوك',Icons.open_in_new,const Color(0xFF1877F2),()=>openProfile('https://www.facebook.com/'))]),
   const SizedBox(height:10),Row(children:[metric('الجروبات',groups.length),const SizedBox(width:7),metric('الحسابات الفريدة',profiles.length),const SizedBox(width:7),metric('سجلات التواصل',interactions.length)]),
   const SizedBox(height:10),
   Wrap(spacing:8,runSpacing:8,children:[
    SizedBox(width:245,child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(labelText:'بحث باسم الحساب أو الجروب',prefixIcon:Icon(Icons.search),border:OutlineInputBorder(),isDense:true))),
    SizedBox(width:210,child:DropdownButtonFormField<String>(value:groups.any((g)=>s(g['id'])==groupFilter)?groupFilter:'all',isExpanded:true,decoration:const InputDecoration(labelText:'الجروب',border:OutlineInputBorder(),isDense:true),items:[const DropdownMenuItem(value:'all',child:Text('كل الجروبات')),...groups.map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['group_name']),overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setState(()=>groupFilter=v??'all'))),
    SizedBox(width:190,child:DropdownButtonFormField<String>(value:classFilter,isExpanded:true,decoration:const InputDecoration(labelText:'التصنيف',border:OutlineInputBorder(),isDense:true),items:[const DropdownMenuItem(value:'all',child:Text('كل التصنيفات')),...classes.map((v)=>DropdownMenuItem(value:v,child:Text(v)))],onChanged:(v)=>setState(()=>classFilter=v??'all'))),
   ]),
   if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,style:const TextStyle(color:Colors.red))),
   if(message!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(message!,style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w700))),
   const SizedBox(height:8),
   if(loading)const Expanded(child:Center(child:CircularProgressIndicator()))
   else if(db==null||(widget.companyId??'').isEmpty)const Expanded(child:Center(child:Text('اختر شركة نشطة لبدء إدارة حسابات الجروبات.')))
   else if(rows.isEmpty)Expanded(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.groups_2_outlined,size:50,color:_fbPurple),const SizedBox(height:8),const Text('لا توجد حسابات مرتبطة بالجروب المحدد.'),TextButton.icon(onPressed:groups.isEmpty?addGroup:addProfile,icon:const Icon(Icons.add),label:Text(groups.isEmpty?'إضافة أول جروب':'إضافة حساب'))])))
   else Expanded(child:ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(ctx,i){
    final p=rows[i],pid=s(p['id']);final gids=links.where((l)=>s(l['profile_id'])==pid).map((l)=>s(l['group_id'])).toSet();
    final names=groups.where((g)=>gids.contains(s(g['id']))).map((g)=>s(g['group_name'])).join(' • ');final av=s(p['avatar_url']);
    return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE9E2F0)),borderRadius:BorderRadius.circular(13)),child:Row(children:[
     CircleAvatar(radius:24,backgroundColor:const Color(0xFFF0E9F7),backgroundImage:av.isEmpty?null:NetworkImage(av),child:av.isEmpty?const Icon(Icons.person,color:_fbPurple):null),
     const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s(p['display_name']),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),Text(names,style:const TextStyle(color:Colors.black54,fontSize:12)),Text(s(p['classification']),style:const TextStyle(color:_fbPurple,fontSize:12,fontWeight:FontWeight.w700))])),
     IconButton(tooltip:'فتح الملف لإرسال طلب صداقة يدوياً',onPressed:()=>openProfile(s(p['profile_url'])),icon:const Icon(Icons.person_search,color:Color(0xFF1877F2))),
     IconButton(tooltip:'تسجيل تواصل',onPressed:()=>interaction(p),icon:const Icon(Icons.forum_outlined,color:_fbPurple)),
     PopupMenuButton<String>(onSelected:(v)=>v=='edit'?editProfile(p):linkAnother(p),itemBuilder:(_)=>const[PopupMenuItem(value:'link',child:Text('ربط بجروب آخر')),PopupMenuItem(value:'edit',child:Text('تعديل البيانات'))]),
    ]));
   })),
  ]));
 }
 Future<void> linkAnother(Map<String,dynamic> p)async{
  String gid=groups.isEmpty?'':s(groups.first['id']);
  final v=await showDialog<String>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('ربط الحساب بجروب آخر'),content:DropdownButtonFormField<String>(value:gid,items:groups.map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['group_name'])))).toList(),onChanged:(x)=>refresh(()=>gid=x??gid)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,gid),child:const Text('ربط'))])));
  if(v==null)return;await save(()async{await db!.from('erp_crm_facebook_group_profiles').upsert({'company_id':widget.companyId,'group_id':v,'profile_id':p['id'],'created_by':db!.auth.currentUser?.id},onConflict:'company_id,group_id,profile_id',ignoreDuplicates:true);},'تم الربط دون تكرار الحساب.');
 }
 Future<void> editProfile(Map<String,dynamic> p)async{
  final v=await form('تعديل بيانات الحساب',['اسم الحساب أو المستخدم','رابط الملف الشخصي','رابط الصورة','ملاحظات'],initial:{'v0':s(p['display_name']),'v1':s(p['profile_url']),'v2':s(p['avatar_url']),'v3':s(p['notes'])});if(v==null)return;
  await save(()async{final u=fbUrl(v['v1']!),a=v['v2']!.trim();if(a.isNotEmpty&&Uri.tryParse(a)?.scheme!='https')throw const FormatException('رابط الصورة يجب أن يبدأ HTTPS.');
   await db!.from('erp_crm_facebook_profiles').update({'display_name':v['v0'],'profile_url':u,'profile_url_normalized':Uri.parse(u).replace(query:'',fragment:'').toString(),'avatar_url':a.isEmpty?null:a,'notes':v['v3']}).eq('id',p['id']).eq('company_id',widget.companyId!);
  },'تم تحديث بيانات الحساب.');
 }
}
class _Field{const _Field(this.key,this.label,{this.url=false,this.multi=false,this.hint});final String key,label;final bool url,multi;final String? hint;}
