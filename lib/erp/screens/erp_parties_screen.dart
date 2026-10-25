import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Separate customer/supplier master data screens backed by erp_parties.
class ErpPartiesScreen extends StatefulWidget {
  const ErpPartiesScreen({super.key, this.initialCompanyId, this.initialKind = 'customer'});
  final String? initialCompanyId;
  final String initialKind;
  @override
  State<ErpPartiesScreen> createState() => _ErpPartiesScreenState();
}

class _ErpPartiesScreenState extends State<ErpPartiesScreen> {
  static const purple = Color(0xFF3E007D);
  static const countries = <String>[
    'مصر','السعودية','الإمارات العربية المتحدة','الكويت','قطر','البحرين','عُمان','الأردن','العراق','لبنان','سوريا','فلسطين','اليمن','ليبيا','السودان','المغرب','الجزائر','تونس',
    'Afghanistan','Albania','Argentina','Australia','Austria','Azerbaijan','Bangladesh','Belgium','Brazil','Canada','China','Denmark','Ethiopia','Finland','France','Germany','Ghana','Greece','India','Indonesia','Iran','Ireland','Italy','Japan','Kenya','Malaysia','Mexico','Netherlands','New Zealand','Nigeria','Norway','Pakistan','Poland','Portugal','Russia','Singapore','South Africa','South Korea','Spain','Sri Lanka','Sweden','Switzerland','Thailand','Turkey','Ukraine','United Kingdom','United States','Vietnam'
  ];
  SupabaseClient? get db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String? companyId;
  late String kind;
  bool loading = false, saving = false, editing = false;
  String? error, message;
  List<Map<String,dynamic>> rows = [], geos = [], classifications = [], reps = [];
  final Map<String,TextEditingController> fields = {
    for (final key in ['party_code','name_ar','name_en','address','country','geo_governorate','geo_district','geo_area','customer_type','transaction_type'])
      key: TextEditingController(text: key == 'country' ? 'مصر' : key == 'transaction_type' ? 'نقدي' : ''),
  };
  String? selectedClassification, selectedGovernorate, selectedDistrict, selectedArea, selectedRep;
  String? selectedPartyId;
  @override
  void initState() { super.initState(); companyId=widget.initialCompanyId; kind=widget.initialKind=='supplier'?'supplier':'customer'; _loadAll(); }
  @override
  void dispose() { for(final c in fields.values){c.dispose();} super.dispose(); }
  String s(dynamic v)=> (v??'').toString();
  Future<void> _loadAll() async {
    final client=db; final cid=companyId;
    if(client==null || cid==null || cid.trim().isEmpty){ if(mounted)setState(()=>error='يجب اختيار شركة نشطة وتسجيل الدخول أولاً.'); return; }
    setState(()=>loading=true);
    try {
      final result=await Future.wait<dynamic>([
        client.from('erp_parties').select('id,party_code,party_name,party_name_en,party_kind,country,address,governorate,district,center,area,customer_type,transaction_type,sales_rep_employee_id,is_active').eq('company_id',cid).eq('party_kind',kind).order('party_code').limit(2000),
        client.from('erp_geographic_data').select('id,parent_id,level,name_ar,name_en').eq('company_id',cid).eq('is_active',true).order('name_ar'),
        client.from('erp_party_classifications').select('id,name_ar,name_en').eq('company_id',cid).eq('party_kind',kind).eq('is_active',true).order('name_ar'),
        client.from('erp_employees').select('id,employee_code,full_name,job_title').eq('company_id',cid).eq('is_active',true).order('full_name'),
      ]);
      if(!mounted)return;
      setState(()=>rows=(result[0] as List).map((e)=>Map<String,dynamic>.from(e)).toList());
      geos=(result[1] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      classifications=(result[2] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      reps=(result[3] as List).map((e)=>Map<String,dynamic>.from(e)).where((e){final job=s(e['job_title']).toLowerCase(); return job.contains('مندوب')||job.contains('مبيعات')||job.contains('sales representative')||job.contains('sales rep');}).toList();
      if(mounted)setState(()=>{loading=false,error=null});
    } catch(e) { if(mounted)setState(()=>{loading=false,error='تعذر تحميل البيانات. تأكد من تطبيق ترحيل بيانات العملاء والموردين: $e'}); }
  }
  List<Map<String,dynamic>> _geoLevel(String level, [String? parent]) => geos.where((g)=>s(g['level'])==level && (parent==null ? g['parent_id']==null : s(g['parent_id'])==parent)).toList();
  Future<void> _new() async {
    setState(()=>{editing=true,error=null,message=null,selectedPartyId=null,selectedClassification=null,selectedGovernorate=null,selectedDistrict=null,selectedArea=null,selectedRep=null});
    for(final e in fields.entries){e.value.text='';}
    fields['country']!.text='مصر'; fields['transaction_type']!.text='نقدي';
    fields['party_code']!.text=await _nextCode();
  }
  Future<String> _nextCode() async {
    final prefix=kind=='customer'?'CUS':'SUP';
    final used=rows.map((r)=>s(r['party_code'])).toList();
    var n=used.length+1; var code='$prefix-${n.toString().padLeft(5,'0')}';
    while(used.contains(code)){n++;code='$prefix-${n.toString().padLeft(5,'0')}';}
    return code;
  }
  void _select(Map<String,dynamic> row) {
    setState(()=>{editing=false,selectedPartyId=s(row['id']),selectedClassification=classifications.where((c)=>s(c['name_ar'])==s(row['customer_type'])).map((c)=>s(c['id'])).firstOrNull,selectedGovernorate=geos.where((g)=>s(g['name_ar'])==s(row['governorate'])&&s(g['level'])=='governorate').map((g)=>s(g['id'])).firstOrNull,selectedRep=s(row['sales_rep_employee_id']).isEmpty?null:s(row['sales_rep_employee_id'])});
    fields['party_code']!.text=s(row['party_code']); fields['name_ar']!.text=s(row['party_name']); fields['name_en']!.text=s(row['party_name_en']); fields['country']!.text=s(row['country']).isEmpty?'مصر':s(row['country']); fields['address']!.text=s(row['address']); fields['customer_type']!.text=s(row['customer_type']); fields['transaction_type']!.text=s(row['transaction_type']).isEmpty?'نقدي':s(row['transaction_type']);
    final gov=selectedGovernorate; selectedDistrict=geos.where((g)=>s(g['name_ar'])==s(row['district'])&&s(g['parent_id'])==s(gov)).map((g)=>s(g['id'])).firstOrNull;
    selectedArea=geos.where((g)=>s(g['name_ar'])==s(row['area'])&&s(g['parent_id'])==s(selectedDistrict)).map((g)=>s(g['id'])).firstOrNull;
    setState((){});
  }
  Future<void> _save() async {
    final client=db; if(client==null||companyId==null)return;
    if(fields['party_code']!.text.trim().isEmpty||fields['name_ar']!.text.trim().isEmpty){setState(()=>error='كود ${kind=='customer'?'العميل':'المورد'} والاسم العربي مطلوبان.');return;}
    setState(()=>{saving=true,error=null,message=null});
    final gov=geos.where((g)=>s(g['id'])==selectedGovernorate).firstOrNull;
    final dist=geos.where((g)=>s(g['id'])==selectedDistrict).firstOrNull;
    final area=geos.where((g)=>s(g['id'])==selectedArea).firstOrNull;
    final cls=classifications.where((c)=>s(c['id'])==selectedClassification).firstOrNull;
    final payload=<String,dynamic>{
      'company_id':companyId,'party_code':fields['party_code']!.text.trim(),'party_name':fields['name_ar']!.text.trim(),
      'party_name_en':fields['name_en']!.text.trim().isEmpty?null:fields['name_en']!.text.trim(),'party_kind':kind,
      'country':fields['country']!.text.trim().isEmpty?'مصر':fields['country']!.text.trim(),'address':fields['address']!.text.trim().isEmpty?null:fields['address']!.text.trim(),
      'governorate':gov==null?null:s(gov['name_ar']),'district':dist==null?null:s(dist['name_ar']),'area':area==null?null:s(area['name_ar']),
      'customer_type':cls==null?null:s(cls['name_ar']),'transaction_type':kind=='customer'?(fields['transaction_type']!.text.isEmpty?'نقدي':fields['transaction_type']!.text):null,
      'sales_rep_employee_id':selectedRep,
    };
    try{
      if(selectedPartyId==null){payload['transaction_type']=kind=='customer'?'نقدي':null;await client.from('erp_parties').insert(payload);}
      else{payload.remove('transaction_type'); await client.from('erp_parties').update(payload).eq('id',selectedPartyId!).eq('company_id',companyId!);}
      if(!mounted)return; setState(()=>{saving=false,editing=false,message='تم حفظ بيانات ${kind=='customer'?'العميل':'المورد'} بنجاح.'}); await _loadAll();
    }catch(e){if(mounted)setState(()=>{saving=false,error='فشل الحفظ: $e'});}
  }
  Future<void> _manageClassifications() async {
    final controller=TextEditingController();
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('تصنيفات ${kind=='customer'?'العملاء':'الموردين'}'),content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:controller,decoration:const InputDecoration(labelText:'اسم التصنيف بالعربية')),const SizedBox(height:8),Wrap(spacing:6,children:classifications.map((c)=>Chip(label:Text(s(c['name_ar'])))).toList())])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{if(controller.text.trim().isEmpty)return;try{await db!.from('erp_party_classifications').insert({'company_id':companyId,'party_kind':kind,'name_ar':controller.text.trim(),'is_active':true});if(ctx.mounted)Navigator.pop(ctx);await _loadAll();}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('تعذر حفظ التصنيف: $e')));}},child:const Text('إضافة'))]));
    controller.dispose();
  }
  Future<void> _map() async {
    final address=[fields['country']!.text,geos.where((g)=>s(g['id'])==selectedGovernorate).map((g)=>s(g['name_ar'])).firstOrNull,geos.where((g)=>s(g['id'])==selectedDistrict).map((g)=>s(g['name_ar'])).firstOrNull,geos.where((g)=>s(g['id'])==selectedArea).map((g)=>s(g['name_ar'])).firstOrNull,fields['address']!.text].where((e)=>e!=null&&e.toString().trim().isNotEmpty).join(' ');
    final uri=Uri.https('www.google.com','/maps/search/',{'api':'1','query':address});
    if(!await launchUrl(uri,mode:LaunchMode.platformDefault)&&mounted)setState(()=>error='تعذر فتح خرائط Google.');
  }
  Widget _text(String key,String label,{bool enabled=true})=>TextField(controller:fields[key],enabled:editing&&enabled,decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:9,vertical:10)));
  Widget _drop({required String label,required String? value,required List<DropdownMenuItem<String>> items,required ValueChanged<String?>? onChanged})=>DropdownButtonFormField<String>(value:items.any((e)=>e.value==value)?value:null,isExpanded:true,decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:9,vertical:10)),items:items,onChanged:editing?onChanged:null);
  Widget _geoDrop(String level,String label,String? value,ValueChanged<String?> change,[String? parent])=>_drop(label:label,value:value,items:_geoLevel(level,parent).map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['name_ar']),overflow:TextOverflow.ellipsis))).toList(),onChanged:change);
  Widget _cell(Widget child)=>Padding(padding:const EdgeInsets.all(4),child:child);
  Widget _partyCard(Map<String,dynamic> row,int index)=>InkWell(onTap:()=>_select(row),child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:selectedPartyId==s(row['id'])?const Color(0xFFF5EFFB):Colors.white,border:Border.all(color:const Color(0xFFE1D9EA)),borderRadius:BorderRadius.circular(10)),child:Column(children:[
    Row(children:[SizedBox(width:38,child:Text('${index+1}',textAlign:TextAlign.center)),Expanded(child:Text(s(row['party_code'),),style:const TextStyle(fontWeight:FontWeight.bold)),),Expanded(flex:2,child:Text(s(row['party_name']))),Expanded(flex:2,child:Text(s(row['party_name_en']))),Expanded(child:Text(s(row['customer_type'])))]),
    const Divider(height:12),
    Row(children:[Expanded(child:Text(s(row['country']).isEmpty?'مصر':s(row['country']))),Expanded(flex:2,child:Text([row['governorate'],row['district'],row['area']].where((v)=>v!=null&&s(v).isNotEmpty).join(' / '))),Expanded(flex:2,child:Text(s(row['address']))),IconButton(tooltip:'فتح الموقع على الخريطة',onPressed:()=>launchUrl(Uri.https('www.google.com','/maps/search/',{'api':'1','query':[row['country'],row['governorate'],row['district'],row['area'],row['address']].where((v)=>v!=null&&s(v).isNotEmpty).join(' ')})),icon:const Icon(Icons.map_outlined,color:purple))]),
    const Divider(height:12),
    Row(children:[Expanded(child:Text('نوع التعامل: ${s(row['transaction_type']).isEmpty?'نقدي':s(row['transaction_type'])}')),Expanded(child:Text('المندوب: ${s(reps.where((r)=>s(r['id'])==s(row['sales_rep_employee_id'])).map((r)=>r['full_name']).firstOrNull??'—')}'))]),
  ])));
  @override
  Widget build(BuildContext context){
    final title=kind=='customer'?'بيانات العملاء':'بيانات الموردين';
    final govItems=_geoLevel('governorate').map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['name_ar'])))).toList();
    final distItems=_geoLevel('district',selectedGovernorate).map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['name_ar'])))).toList();
    final areaItems=_geoLevel('area',selectedDistrict).map((g)=>DropdownMenuItem(value:s(g['id']),child:Text(s(g['name_ar'])))).toList();
    return Directionality(textDirection:TextDirection.rtl,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:purple,borderRadius:BorderRadius.circular(12)),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),const Text('بطاقات منظمة في جدول بثلاثة صفوف لكل سجل',style:TextStyle(color:Colors.white70))])),Wrap(spacing:6,children:[OutlinedButton.icon(onPressed:loading?null:_loadAll,icon:const Icon(Icons.refresh,color:Colors.white),label:const Text('تحديث',style:TextStyle(color:Colors.white))),FilledButton.icon(onPressed:editing?null:_new,icon:const Icon(Icons.add),label:const Text('إضافة')),FilledButton.icon(onPressed:!editing||saving?null:_save,icon:const Icon(Icons.save),label:const Text('حفظ')),OutlinedButton.icon(onPressed:selectedPartyId==null||editing?null:()=>setState(()=>editing=true),icon:const Icon(Icons.edit_outlined,color:Colors.white),label:const Text('تعديل',style:TextStyle(color:Colors.white))),OutlinedButton.icon(onPressed:_manageClassifications,icon:const Icon(Icons.category_outlined,color:Colors.white),label:const Text('تصنيفات',style:TextStyle(color:Colors.white)))]) ])),
      if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),
      if(message!=null)Padding(padding:const EdgeInsets.all(8),child:Text(message!,style:const TextStyle(color:Colors.green))),
      if(loading||saving)const LinearProgressIndicator(),
      if(editing)Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
        Row(children:[Expanded(child:_text('party_code','كود ${kind=='customer'?'العميل':'المورد'} (إنجليزي + أرقام)')),Expanded(flex:2,child:_text('name_ar','الاسم بالعربية *')),Expanded(flex:2,child:_text('name_en','الاسم بالإنجليزية')),Expanded(child:_drop(label:'التصنيف',value:selectedClassification,items:classifications.map((c)=>DropdownMenuItem(value:s(c['id']),child:Text(s(c['name_ar'])))).toList(),onChanged:(v)=>setState(()=>selectedClassification=v))) ]),
        const SizedBox(height:8),
        Row(children:[Expanded(child:_drop(label:'الدولة',value:fields['country']!.text.isEmpty?'مصر':fields['country']!.text,items:countries.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v)=>setState(()=>fields['country']!.text=v??'مصر'))),Expanded(child:_geoDrop('governorate','المحافظة',selectedGovernorate,(v)=>setState(()=>{selectedGovernorate=v,selectedDistrict=null,selectedArea=null}))),Expanded(child:_geoDrop('district','مركز / حي',selectedDistrict,(v)=>setState(()=>{selectedDistrict=v,selectedArea=null}),selectedGovernorate)),Expanded(child:_geoDrop('area','منطقة / قرية',selectedArea,(v)=>setState(()=>selectedArea=v),selectedDistrict)),Expanded(flex:2,child:_text('address','العنوان')),IconButton(tooltip:'فتح خرائط Google',onPressed:_map,icon:const Icon(Icons.map_outlined,color:purple))]),
        const SizedBox(height:8),
        Row(children:[Expanded(child:_drop(label:'نوع العميل',value:fields['transaction_type']!.text,items:const [DropdownMenuItem(value:'نقدي',child:Text('نقدي')),DropdownMenuItem(value:'آجل',child:Text('آجل')),DropdownMenuItem(value:'بيع مباشر',child:Text('بيع مباشر'))],onChanged:null)),Expanded(child:_drop(label:'مندوب المبيعات',value:selectedRep,items:reps.map((r)=>DropdownMenuItem(value:s(r['id']),child:Text('${s(r['employee_code'])} - ${s(r['full_name'])}'))).toList(),onChanged:(v)=>setState(()=>selectedRep=v))),const Spacer()]),
        const Align(alignment:Alignment.centerRight,child:Text('نوع التعامل يبدأ «نقدي» ولا يُعدّل من هذه الشاشة؛ التغيير من شاشة ائتمان العملاء.',style:TextStyle(fontSize:12,color:Colors.deepOrange))),
      ]))),
      const SizedBox(height:8),
      Container(padding:const EdgeInsets.symmetric(vertical:8,horizontal:10),color:const Color(0xFFF5EFFB),child:const Row(children:[SizedBox(width:38,child:Text('م',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text('الكود',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('الاسم عربي',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('الاسم إنجليزي',style:TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text('التصنيف',style:TextStyle(fontWeight:FontWeight.bold)))])),
      Expanded(child:loading&&rows.isEmpty?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('لا توجد بيانات حتى الآن. اضغط «إضافة» لإنشاء سجل جديد.')):ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i)=>_partyCard(rows[i],i))),
    ]));
  }
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
