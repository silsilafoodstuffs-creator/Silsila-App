import 'package:flutter/material.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _green = Color(0xFF16834A);
const _red = Color(0xFFD32F2F);

class HrShiftRulesScreen extends StatefulWidget {
  const HrShiftRulesScreen({super.key});
  @override
  State<HrShiftRulesScreen> createState() => _HrShiftRulesScreenState();
}

class _HrShiftRulesScreenState extends State<HrShiftRulesScreen> {
  final shifts = <_Shift>[ _Shift() ];
  final weekdays = const ['السبت','الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة'];
  final departments = const ['كل الإدارات','الإدارة العامة','المبيعات','المخازن','الحسابات','الموارد البشرية'];
  final branches = const ['كل الفروع','الإدارة الرئيسية','فرع القاهرة','فرع الجيزة','فرع الإسكندرية'];

  @override
  void dispose() { for (final s in shifts) { s.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('قواعد الورديات والحضور والانصراف',style:TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),
    const Text('تعريف الورديات في جدول موحد مع قواعد السماح والتأخير والغياب والإجازات وتنسيب الموظفين.',style:TextStyle(color:Colors.black54,height:1.6)),
    const SizedBox(height:12),
    Wrap(spacing:8,children:[
      FilledButton.icon(onPressed:()=>setState(()=>shifts.add(_Shift())),icon:const Icon(Icons.add),label:const Text('إضافة وردية'),style:FilledButton.styleFrom(backgroundColor:_purple)),
      OutlinedButton.icon(onPressed:()=>_message('هذه مسودة واجهة. الحفظ الدائم يحتاج ربطها بقاعدة البيانات.'),icon:const Icon(Icons.save_outlined,color:_orange),label:const Text('حفظ القواعد')),
    ]),
    const SizedBox(height:12),
    const Text('فترات التأخير الخمس يجب أن تكون متتابعة: نهاية كل شريحة تليها بداية الشريحة التالية مباشرة. القيم لا تُطبق على الرواتب فعليًا قبل الربط والاعتماد.',style:TextStyle(color:_red,height:1.5)),
    const SizedBox(height:10),
    ...List.generate(shifts.length,(i)=>_shiftCard(i)),
  ]);

  Widget _shiftCard(int i) {
    final s=shifts[i];
    return Card(elevation:0,margin:const EdgeInsets.only(bottom:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14),side:const BorderSide(color:Color(0xFFE8E0F0))),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:Text('الوردية '+(i+1).toString(),style:const TextStyle(color:_purple,fontSize:18,fontWeight:FontWeight.w900))),
        TextButton.icon(onPressed:()=>_assign(s),icon:const Icon(Icons.groups_2_outlined,color:_orange),label:const Text('استحضار وتنسيب')),
        if(shifts.length>1) IconButton(onPressed:()=>setState(()=>shifts.removeAt(i).dispose()),icon:const Icon(Icons.delete_outline,color:_red)),
      ]),
      Wrap(spacing:9,runSpacing:9,children:[
        _field(s.name,'اسم الوردية',190),
        _field(s.start,'من الساعة HH:MM',150),
        _field(s.end,'إلى الساعة HH:MM',150),
        Container(width:135,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF1E9FA),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('عدد الساعات'),Text(_hours(s.start.text,s.end.text),style:const TextStyle(color:_purple,fontSize:17,fontWeight:FontWeight.w900))])),
      ]),
      _heading('العطلة الأسبوعية — اختيار متعدد'),
      Wrap(spacing:5,children:weekdays.map((d)=>FilterChip(label:Text(d),selected:s.days.contains(d),selectedColor:const Color(0xFFFFE4BB),onSelected:(v)=>setState(()=>v?s.days.add(d):s.days.remove(d)))).toList()),
      _heading('قواعد السماح'),
      _numberFields([_num(s.graceIn,'سماح بداية الحضور بالدقائق'),_num(s.graceOut,'سماح نهاية الانصراف بالدقائق'),_num(s.monthGrace,'إجمالي السماح الشهري بالدقائق'),_num(s.multiplier,'معامل خصم الدقائق المتجاوزة')]),
      _heading('قواعد الحضور والانصراف'),
      _numberFields([_num(s.earlyIn,'الحضور المبكر: قيمة الدقيقة إضافي'),_num(s.earlyOut,'الانصراف المبكر: قيمة الدقيقة خصم'),_num(s.lateOut,'الانصراف المتأخر: قيمة الدقيقة إضافي')]),
      _heading('قواعد الحضور المتأخر — شرائح متتابعة'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        headingRowColor:WidgetStateProperty.all(const Color(0xFFF1E9FA)),
        columns:const [DataColumn(label:Text('الحالة')),DataColumn(label:Text('من دقيقة')),DataColumn(label:Text('إلى دقيقة')),DataColumn(label:Text('قيمة الدقيقة')),DataColumn(label:Text('احتساب'))],
        rows:List.generate(5,(n)=>DataRow(cells:[
          DataCell(Text('تأخير '+(n+1).toString())),
          DataCell(SizedBox(width:82,child:TextField(controller:s.from[n],keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()),onChanged:(_)=>setState((){})))),
          DataCell(SizedBox(width:82,child:TextField(controller:s.to[n],keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()),onChanged:(_)=>setState((){})))),
          DataCell(SizedBox(width:90,child:TextField(controller:s.value[n],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
          DataCell(DropdownButton<String>(value:s.action[n],items:const[DropdownMenuItem(value:'خصم',child:Text('خصم')),DropdownMenuItem(value:'إضافي',child:Text('إضافي'))],onChanged:(v)=>setState(()=>s.action[n]=v??'خصم'))),
        ])),
      )),
      Text(_validateRanges(s),style:TextStyle(color:_validateRanges(s).startsWith('سليم')?_green:_red,fontWeight:FontWeight.w700,fontSize:12)),
      _heading('قواعد نسيان البصمة'),
      _numberFields([_num(s.missIn,'نسيان بصمة الحضور — قيمة الحالة'),_num(s.missOut,'نسيان بصمة الانصراف — قيمة الحالة'),_num(s.missDay,'نسيان بصمة اليوم — قيمة الحالة')]),
      _heading('قواعد الغياب'),
      _numberFields([_num(s.excused1,'غياب بإذن: مرة'),_num(s.excused2,'غياب بإذن: مرتان'),_num(s.excused3,'غياب بإذن: 3 فأكثر'),_num(s.absent1,'غياب دون إذن: مرة'),_num(s.absent2,'غياب دون إذن: مرتان'),_num(s.absent3,'غياب دون إذن: 3 فأكثر'),_num(s.sick,'غياب مرضي: قيمة اليوم'),_num(s.injury,'إصابة عمل: قيمة اليوم')]),
      _heading('قواعد الإجازات — قيمة اليوم الإضافي'),
      _numberFields([_num(s.weeklyLeave,'إجازة أسبوعية'),_num(s.publicLeave,'إجازة رسمية'),_num(s.annualLeave,'إجازة سنوية')]),
      Text('الإدارات: '+s.depts.join('، ')+' | الفروع: '+s.branches.join('، ')+' | عدد الموظفين المحددين: '+s.employees.length.toString(),style:const TextStyle(color:Colors.black54,fontSize:12)),
    ])));
  }

  Widget _heading(String t)=>Padding(padding:const EdgeInsets.only(top:14,bottom:8),child:Text(t,style:const TextStyle(color:_purple,fontWeight:FontWeight.w900)));
  Widget _field(TextEditingController c,String label,double w)=>SizedBox(width:w,child:TextField(controller:c,decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder()),onChanged:(_)=>setState((){})));
  Widget _num(TextEditingController c,String label)=>SizedBox(width:210,child:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder())));
  Widget _numberFields(List<Widget> children)=>Wrap(spacing:9,runSpacing:9,children:children);

  int? _mins(String t){final p=t.split(':');if(p.length!=2)return null;final h=int.tryParse(p[0]),m=int.tryParse(p[1]);if(h==null||m==null||h>23||h<0||m>59||m<0)return null;return h*60+m;}
  String _hours(String a,String b){final x=_mins(a),y=_mins(b);if(x==null||y==null)return '—';final n=(y-x+1440)%1440;return n==0?'24 ساعة':(n~/60).toString()+' ساعة '+(n%60==0?'':(n%60).toString()+' دقيقة');}
  String _validateRanges(_Shift s){for(var i=0;i<5;i++){final a=int.tryParse(s.from[i].text),b=int.tryParse(s.to[i].text);if(a==null||b==null||a<0||b<a)return 'راجع بداية ونهاية الشريحة '+(i+1).toString();if(i>0&&a!=(int.tryParse(s.to[i-1].text)??-2)+1)return 'تنبيه: الشريحة '+(i+1).toString()+' يجب أن تبدأ بعد الشريحة السابقة بدقيقة';}return 'سليم: الشرائح متتابعة.';}

  void _assign(_Shift s){showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:const Text('استحضار وتنسيب موظفين'),content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('الإدارات'),...departments.map((d)=>CheckboxListTile(dense:true,value:s.depts.contains(d),title:Text(d),onChanged:(v)=>refresh(()=>v==true?s.depts.add(d):s.depts.remove(d)))),
    const Divider(),const Text('الفروع'),...branches.map((b)=>CheckboxListTile(dense:true,value:s.branches.contains(b),title:Text(b),onChanged:(v)=>refresh(()=>v==true?s.branches.add(b):s.branches.remove(b)))),
    const SizedBox(height:8),TextField(controller:s.employeeText,decoration:const InputDecoration(labelText:'أرقام الموظفين مفصولة بفاصلة',border:OutlineInputBorder())),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){s.employees..clear()..addAll(s.employeeText.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty));Navigator.pop(ctx);setState((){});},child:const Text('تطبيق'))])));}
  void _message(String m)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));
}

class _Shift {
  final name=TextEditingController(text:'وردية صباحية'),start=TextEditingController(text:'08:00'),end=TextEditingController(text:'16:00');
  final graceIn=TextEditingController(text:'10'),graceOut=TextEditingController(text:'10'),monthGrace=TextEditingController(text:'60'),multiplier=TextEditingController(text:'1');
  final earlyIn=TextEditingController(text:'0'),earlyOut=TextEditingController(text:'1'),lateOut=TextEditingController(text:'0');
  final from=List.generate(5,(i)=>TextEditingController(text:(i==0?1:i*10+1).toString()));
  final to=List.generate(5,(i)=>TextEditingController(text:(i==4?999:(i+1)*10).toString()));
  final value=List.generate(5,(_)=>TextEditingController(text:'1'));final action=List.generate(5,(_)=>'خصم');
  final missIn=TextEditingController(text:'1'),missOut=TextEditingController(text:'1'),missDay=TextEditingController(text:'1');
  final excused1=TextEditingController(text:'0'),excused2=TextEditingController(text:'0'),excused3=TextEditingController(text:'0');
  final absent1=TextEditingController(text:'1'),absent2=TextEditingController(text:'1'),absent3=TextEditingController(text:'1'),sick=TextEditingController(text:'0'),injury=TextEditingController(text:'0');
  final weeklyLeave=TextEditingController(text:'1'),publicLeave=TextEditingController(text:'1'),annualLeave=TextEditingController(text:'1');
  final days=<String>{'الجمعة'},depts=<String>{'كل الإدارات'},branches=<String>{'كل الفروع'},employees=<String>{};
  final employeeText=TextEditingController();
  void dispose(){for(final c in [name,start,end,graceIn,graceOut,monthGrace,multiplier,earlyIn,earlyOut,lateOut,missIn,missOut,missDay,excused1,excused2,excused3,absent1,absent2,absent3,sick,injury,weeklyLeave,publicLeave,annualLeave,employeeText,...from,...to,...value]){c.dispose();}}
}

class HrFingerprintDevicesScreen extends StatefulWidget {
  const HrFingerprintDevicesScreen({super.key});
  @override
  State<HrFingerprintDevicesScreen> createState()=>_HrFingerprintDevicesScreenState();
}
class _HrFingerprintDevicesScreenState extends State<HrFingerprintDevicesScreen>{
  final devices=<_Device>[];
  @override
  void dispose(){for(final d in devices){d.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('أجهزة البصمة وربط الحضور',style:TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),const Text('تعريف عدة أجهزة مع حالة اتصال مميزة بالألوان، وتجهيز السحب عبر IP أو USB.',style:TextStyle(color:Colors.black54,height:1.6)),
    const SizedBox(height:12),Wrap(spacing:8,children:[
      FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('إضافة جهاز'),style:FilledButton.styleFrom(backgroundColor:_purple)),
      OutlinedButton.icon(onPressed:()=>_msg('لم يتم إجراء اختبار فعلي. يلزم موصل متوافق مع موديل البصمة والبروتوكول.'),icon:const Icon(Icons.sync,color:_orange),label:const Text('فحص الاتصالات')),
    ]),
    const SizedBox(height:12),const Text('مهم: حالة الاتصال لا تصبح «متصل» إلا بعد دمج واختبار موصل فعلي. USB يحتاج دعمًا أصليًا على الجهاز أو خدمة وسيطة؛ هذه الواجهة لا تدّعي سحب سجلات حقيقية.',style:TextStyle(color:_red,height:1.5)),
    const SizedBox(height:10),
    if(devices.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(22),child:Text('لا توجد أجهزة معرفة بعد.',textAlign:TextAlign.center))),
    ...devices.asMap().entries.map((e){final i=e.key,d=e.value;final c=d.connected?_green:_red;return Card(elevation:0,margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13),side:BorderSide(color:c.withValues(alpha:.45))),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Expanded(child:Text(d.name.text,style:const TextStyle(color:_purple,fontSize:16,fontWeight:FontWeight.w900))),Icon(d.connected?Icons.link:Icons.link_off,color:c),Text(d.connected?'متصل':'غير متصل',style:TextStyle(color:c,fontWeight:FontWeight.w900))]),
      const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:[
        _df(d.name,'اسم الجهاز',170),_df(d.model,'الموديل والبروتوكول',190),
        SizedBox(width:140,child:DropdownButtonFormField<String>(value:d.method,decoration:const InputDecoration(labelText:'طريقة الربط',isDense:true,border:OutlineInputBorder()),items:const[DropdownMenuItem(value:'IP',child:Text('IP عبر الشبكة')),DropdownMenuItem(value:'USB',child:Text('USB'))],onChanged:(v)=>setState(()=>d.method=v??'IP'))),
        if(d.method=='IP')_df(d.ip,'عنوان IP',150),if(d.method=='IP')_df(d.port,'المنفذ',90),if(d.method=='USB')_df(d.usb,'معرّف USB',180),
      ]),
      const SizedBox(height:8),Wrap(spacing:7,children:[
        OutlinedButton.icon(onPressed:()=>_test(d),icon:Icon(Icons.network_check,color:c),label:const Text('اختبار الاتصال')),
        OutlinedButton.icon(onPressed:()=>_pull(d),icon:const Icon(Icons.download_outlined,color:_orange),label:const Text('سحب الحركات')),
        OutlinedButton.icon(onPressed:()=>_edit(d,i),icon:const Icon(Icons.edit_outlined,color:_orange),label:const Text('تعديل')),
        IconButton(onPressed:()=>setState(()=>devices.removeAt(i).dispose()),icon:const Icon(Icons.delete_outline,color:_red)),
      ]),
      if(d.note.isNotEmpty)Text(d.note,style:const TextStyle(fontSize:12,color:Colors.black54)),
    ])));}),
  ]);
  Widget _df(TextEditingController c,String label,double w)=>SizedBox(width:w,child:TextField(controller:c,decoration:InputDecoration(labelText:label,isDense:true,border:const OutlineInputBorder()),onChanged:(_)=>setState((){})));
  void _edit([_Device? old,int? index]){final d=old??_Device();showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:Text(old==null?'إضافة جهاز بصمة':'تعديل جهاز'),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:d.name,decoration:const InputDecoration(labelText:'اسم الجهاز')),
    TextField(controller:d.model,decoration:const InputDecoration(labelText:'الشركة / الموديل / البروتوكول')),
    DropdownButtonFormField<String>(value:d.method,decoration:const InputDecoration(labelText:'طريقة الربط'),items:const[DropdownMenuItem(value:'IP',child:Text('شبكة IP')),DropdownMenuItem(value:'USB',child:Text('USB'))],onChanged:(v)=>refresh(()=>d.method=v??'IP')),
    if(d.method=='IP')TextField(controller:d.ip,decoration:const InputDecoration(labelText:'عنوان IP')),
    if(d.method=='IP')TextField(controller:d.port,decoration:const InputDecoration(labelText:'المنفذ')),
    if(d.method=='USB')TextField(controller:d.usb,decoration:const InputDecoration(labelText:'معرّف USB / المنفذ')),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){setState(()=>old==null?devices.add(d):devices[index!]=d);Navigator.pop(ctx);},child:const Text('حفظ'))])));}
  void _test(_Device d){setState(()=>d.connected=false);_msg(d.method=='IP'?'اختبار IP الفعلي يحتاج موصل الجهاز والتحقق من الوصول إلى الشبكة.':'اختبار USB يحتاج إضافة دعم أصلي أو خدمة وسيطة.');}
  void _pull(_Device d){setState(()=>d.note='لم تُسحب حركات فعلية بعد؛ يلزم ربط موصل '+d.method+' وتخزين السجلات مع منع التكرار.');_msg(d.note);}
  void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
}
class _Device{
  final name=TextEditingController(text:'جهاز بصمة جديد'),model=TextEditingController(),ip=TextEditingController(),port=TextEditingController(text:'4370'),usb=TextEditingController();
  String method='IP',note='';bool connected=false;
  void dispose(){name.dispose();model.dispose();ip.dispose();port.dispose();usb.dispose();}
}
