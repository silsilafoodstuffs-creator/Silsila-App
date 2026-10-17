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
  int _selectedShiftIndex = 0;
  int? _editingShiftIndex;
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
    Wrap(spacing:8,runSpacing:8,children:[
      FilledButton.icon(onPressed:(){
        final s=_Shift();
        setState((){shifts.add(s);_selectedShiftIndex=shifts.length-1;_editingShiftIndex=_selectedShiftIndex;});
      },icon:const Icon(Icons.add),label:const Text('إضافة وردية'),style:FilledButton.styleFrom(backgroundColor:_purple)),
      OutlinedButton.icon(onPressed:()=>setState(()=>_editingShiftIndex=_selectedShiftIndex),icon:const Icon(Icons.edit_outlined,color:_orange),label:const Text('تعديل الوردية المحددة')),
      OutlinedButton.icon(onPressed:()=>_message('هذه مسودة واجهة. الحفظ الدائم يحتاج ربطها بقاعدة البيانات.'),icon:const Icon(Icons.save_outlined,color:_orange),label:const Text('حفظ القواعد')),
      if(shifts.length>1) OutlinedButton.icon(onPressed:()=>_confirmDelete('الوردية المحددة',(){
        final removed=shifts.removeAt(_selectedShiftIndex);removed.dispose();
        setState((){_selectedShiftIndex=(_selectedShiftIndex-1).clamp(0,shifts.length-1).toInt();_editingShiftIndex=null;});
      }),icon:const Icon(Icons.delete_outline,color:_red),label:const Text('حذف الوردية المحددة')),
    ]),
    const SizedBox(height:12),
    const Text('فترات التأخير الخمس يجب أن تكون متتابعة: نهاية كل شريحة تليها بداية الشريحة التالية مباشرة. القيم لا تُطبق على الرواتب فعليًا قبل الربط والاعتماد.',style:TextStyle(color:_red,height:1.5)),
    const SizedBox(height:10),
    Wrap(spacing:8,runSpacing:8,children:List.generate(shifts.length,(i)=>OutlinedButton.icon(
      onPressed:()=>setState(()=>_selectedShiftIndex=i),
      icon:Icon(_selectedShiftIndex==i?Icons.visibility:Icons.visibility_outlined,color:_selectedShiftIndex==i?_purple:_orange),
      label:Text(shifts[i].name.text.trim().isEmpty?'الوردية '+(i+1).toString():shifts[i].name.text),
      style:OutlinedButton.styleFrom(backgroundColor:_selectedShiftIndex==i?const Color(0xFFF1E9FA):Colors.white,side:BorderSide(color:_selectedShiftIndex==i?_purple:const Color(0xFFE8E0F0))),
    ))),
    const SizedBox(height:10),
    if(shifts.isNotEmpty)_shiftCard(_selectedShiftIndex),
  ]);

  Widget _shiftCard(int i) {
    final s=shifts[i];
    final canEdit=_editingShiftIndex==i;
    return Card(elevation:0,margin:const EdgeInsets.only(bottom:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14),side:const BorderSide(color:Color(0xFFE8E0F0))),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:Text('معاينة الوردية '+(i+1).toString(),style:const TextStyle(color:_purple,fontSize:18,fontWeight:FontWeight.w900))),
        if(canEdit) const Chip(label:Text('وضع التعديل'),backgroundColor:Color(0xFFFFE4BB)),
        TextButton.icon(onPressed:canEdit?()=>_assign(s):null,icon:const Icon(Icons.groups_2_outlined,color:_orange),label:const Text('استدعاء موظفين')),
      ]),
      Wrap(spacing:9,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,children:[
        _field(s.name,'اسم الوردية',190,readOnly:!canEdit),
        Row(mainAxisSize:MainAxisSize.min,children:[
          Checkbox(value:s.nightShift,onChanged:canEdit?(v)=>setState(()=>s.nightShift=v??false):null),
          const Text('وردية ليل / سهر'),
        ]),
        _field(s.start,'من',130,readOnly:!canEdit),
        _field(s.end,'إلى',130,readOnly:!canEdit),
        Container(width:135,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF1E9FA),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('عدد الساعات'),Text(_hours(s.start.text,s.end.text),style:const TextStyle(color:_purple,fontSize:17,fontWeight:FontWeight.w900))])),
      ]),
      _heading('العطلة الأسبوعية — اختيار متعدد'),
      Wrap(spacing:5,children:weekdays.map((d)=>FilterChip(label:Text(d),selected:s.days.contains(d),selectedColor:const Color(0xFFFFE4BB),onSelected:canEdit?(v)=>setState(()=>v?s.days.add(d):s.days.remove(d)):null)).toList()),
      _heading('قواعد السماح'),
      _numberFields([_num(s.graceIn,'سماح بداية الحضور',readOnly:!canEdit,width:170),_num(s.graceOut,'سماح نهاية الانصراف',readOnly:!canEdit,width:170),_num(s.monthGrace,'السماح الشهري',readOnly:!canEdit,width:170),_num(s.multiplier,'معامل الخصم',readOnly:!canEdit,width:170)]),
      _heading('قواعد الحضور والانصراف'),
      _numberFields([_num(s.earlyIn,'الحضور المبكر: قيمة الدقيقة إضافي',readOnly:!canEdit),_num(s.earlyOut,'الانصراف المبكر: قيمة الدقيقة خصم',readOnly:!canEdit),_num(s.lateOut,'الانصراف المتأخر: قيمة الدقيقة إضافي',readOnly:!canEdit)]),
      _heading('قواعد الحضور المتأخر — شرائح متتابعة'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        headingRowColor:WidgetStateProperty.all(const Color(0xFFF1E9FA)),
        columns:const [DataColumn(label:Text('الحالة')),DataColumn(label:Text('من دقيقة')),DataColumn(label:Text('إلى دقيقة')),DataColumn(label:Text('قيمة الدقيقة')),DataColumn(label:Text('احتساب')),DataColumn(label:Text('حذف'))],
        rows:List.generate(s.from.length,(n)=>DataRow(cells:[
          DataCell(Text('تأخير '+(n+1).toString())),
          DataCell(SizedBox(width:72,child:TextField(controller:s.from[n],readOnly:!canEdit,keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:7,vertical:9)),onChanged:canEdit?(_)=>setState((){}):null))),
          DataCell(SizedBox(width:72,child:TextField(controller:s.to[n],readOnly:!canEdit,keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:7,vertical:9)),onChanged:canEdit?(_)=>setState((){}):null))),
          DataCell(SizedBox(width:78,child:TextField(controller:s.value[n],readOnly:!canEdit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:7,vertical:9))))),
          DataCell(DropdownButton<String>(value:s.action[n],items:const[DropdownMenuItem(value:'خصم',child:Text('خصم')),DropdownMenuItem(value:'إضافي',child:Text('إضافي'))],onChanged:canEdit?(v)=>setState(()=>s.action[n]=v??'خصم'):null)),
          DataCell(IconButton(tooltip:'حذف قاعدة التأخير',onPressed:canEdit&&s.from.length>1?()=>_confirmDelete('قاعدة التأخير ${n+1}',()=>setState(()=>s.removeLateRule(n))):null,icon:const Icon(Icons.delete_outline,color:_red))),
        ])),
      )),
      if(canEdit) Align(alignment:Alignment.centerRight,child:OutlinedButton.icon(onPressed:()=>setState(()=>s.addLateRule()),icon:const Icon(Icons.add_circle_outline,color:_orange),label:const Text('إضافة قاعدة حضور متأخر'))),
      Text(_validateRanges(s),style:TextStyle(color:_validateRanges(s).startsWith('سليم')?_green:_red,fontWeight:FontWeight.w700,fontSize:12)),
      _heading('قواعد نسيان البصمة'),
      Wrap(spacing:6,runSpacing:6,children:[
        _num(s.missIn,'نسيان بصمة حضور',readOnly:!canEdit,width:175),
        _num(s.missOut,'نسيان بصمة انصراف',readOnly:!canEdit,width:175),
        _num(s.missDay,'نسيان بصمة اليوم',readOnly:!canEdit,width:175),
      ]),
      _heading('قواعد الغياب'),
      _absenceRules(
        title: 'غياب بإذن',
        rules: s.excusedRules,
        canEdit: canEdit,
        onAdd: () => setState(s.addExcusedRule),
        onRemove: (index) => setState(() => s.removeExcusedRule(index)),
      ),
      _absenceRules(
        title: 'غياب دون إذن',
        rules: s.absentRules,
        canEdit: canEdit,
        onAdd: () => setState(s.addAbsentRule),
        onRemove: (index) => setState(() => s.removeAbsentRule(index)),
      ),
      _numberFields([
        _num(s.sick,'مرضي: قيمة اليوم',readOnly:!canEdit,width:190),
        _num(s.injury,'إصابة عمل: قيمة اليوم',readOnly:!canEdit,width:190),
      ]),
      _heading('قواعد الإجازات — قيمة اليوم الإضافي'),
      Wrap(spacing:6,runSpacing:6,children:[
        _num(s.weeklyLeave,'الأسبوعية',readOnly:!canEdit,width:155),
        _num(s.publicLeave,'الرسمية',readOnly:!canEdit,width:155),
        _num(s.annualLeave,'السنوية',readOnly:!canEdit,width:155),
      ]),
      Text('الإدارات: '+s.depts.join('، ')+' | الفروع: '+s.branches.join('، ')+' | عدد الموظفين المحددين: '+s.employees.length.toString(),style:const TextStyle(color:Colors.black54,fontSize:12)),
    ])));
  }

  Widget _heading(String t)=>Padding(padding:const EdgeInsets.only(top:14,bottom:8),child:Text(t,style:const TextStyle(color:_purple,fontWeight:FontWeight.w900)));
  Widget _field(TextEditingController c,String label,double w,{bool readOnly=false})=>SizedBox(width:w,child:Row(children:[
    SizedBox(width:58,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w600))),
    Expanded(child:TextField(controller:c,readOnly:readOnly,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:10)),onChanged:readOnly?null:(_)=>setState((){}))),
  ]));
  Widget _num(TextEditingController c,String label,{bool readOnly=false,double width=260})=>SizedBox(width:width,child:Row(children:[
    SizedBox(width:width*0.58,child:Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600),maxLines:2,overflow:TextOverflow.ellipsis)),
    const SizedBox(width:4),
    Expanded(child:TextField(controller:c,readOnly:readOnly,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:8)))),
  ]));
  Widget _numberFields(List<Widget> children)=>Wrap(spacing:9,runSpacing:9,children:children);

  Widget _absenceRules({
    required String title,
    required List<TextEditingController> rules,
    required bool canEdit,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(rules.length, (index) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _num(rules[index], 'قيمة ${index + 1}', readOnly: !canEdit, width: 175),
              IconButton(
                tooltip: 'حذف قاعدة $title',
                onPressed: canEdit ? () => _confirmDelete('قاعدة $title رقم ${index + 1}', () => onRemove(index)) : null,
                icon: const Icon(Icons.delete_outline, color: _red),
              ),
            ],
          )),
        ),
        if (canEdit)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline, color: _orange),
              label: Text('إضافة قاعدة $title'),
            ),
          ),
      ],
    ),
  );

  int? _mins(String t){final p=t.split(':');if(p.length!=2)return null;final h=int.tryParse(p[0]),m=int.tryParse(p[1]);if(h==null||m==null||h>23||h<0||m>59||m<0)return null;return h*60+m;}
  String _hours(String a,String b){final x=_mins(a),y=_mins(b);if(x==null||y==null)return '—';final n=(y-x+1440)%1440;return n==0?'24 ساعة':(n~/60).toString()+' ساعة '+(n%60==0?'':(n%60).toString()+' دقيقة');}
  String _validateRanges(_Shift s){for(var i=0;i<s.from.length;i++){final a=int.tryParse(s.from[i].text),b=int.tryParse(s.to[i].text);if(a==null||b==null||a<0||b<a)return 'راجع بداية ونهاية الشريحة '+(i+1).toString();if(i>0&&a!=(int.tryParse(s.to[i-1].text)??-2)+1)return 'تنبيه: الشريحة '+(i+1).toString()+' يجب أن تبدأ بعد الشريحة السابقة بدقيقة';}return 'سليم: الشرائح متتابعة.';}

  void _assign(_Shift s){showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:const Text('استحضار وتنسيب موظفين'),content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('الإدارات'),...departments.map((d)=>CheckboxListTile(dense:true,value:s.depts.contains(d),title:Text(d),onChanged:(v)=>refresh(()=>v==true?s.depts.add(d):s.depts.remove(d)))),
    const Divider(),const Text('الفروع'),...branches.map((b)=>CheckboxListTile(dense:true,value:s.branches.contains(b),title:Text(b),onChanged:(v)=>refresh(()=>v==true?s.branches.add(b):s.branches.remove(b)))),
    const SizedBox(height:8),TextField(controller:s.employeeText,decoration:const InputDecoration(labelText:'أرقام الموظفين مفصولة بفاصلة',border:OutlineInputBorder())),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){s.employees..clear()..addAll(s.employeeText.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty));Navigator.pop(ctx);setState((){});},child:const Text('تطبيق'))])));}
  Future<void> _confirmDelete(String item, VoidCallback onDelete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل ترغب في حذف $item؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لا')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) onDelete();
  }

  void _message(String m)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));
}

class _Shift {
  final name=TextEditingController(text:'وردية صباحية'),start=TextEditingController(text:'08:00'),end=TextEditingController(text:'16:00');
  bool nightShift=false;
  final graceIn=TextEditingController(text:'10'),graceOut=TextEditingController(text:'10'),monthGrace=TextEditingController(text:'60'),multiplier=TextEditingController(text:'1');
  final earlyIn=TextEditingController(text:'0'),earlyOut=TextEditingController(text:'1'),lateOut=TextEditingController(text:'0');
  final from=List.generate(5,(i)=>TextEditingController(text:(i==0?1:i*10+1).toString()));
  final to=List.generate(5,(i)=>TextEditingController(text:(i==4?999:(i+1)*10).toString()));
  final value=List.generate(5,(_)=>TextEditingController(text:'1'));
  final action=List<String>.generate(5,(_)=>'خصم');
  void addLateRule(){
    final lastEnd=int.tryParse(to.last.text)??0;
    from.add(TextEditingController(text:(lastEnd+1).toString()));
    to.add(TextEditingController(text:(lastEnd+10).toString()));
    value.add(TextEditingController(text:'1'));
    action.add('خصم');
  }
  void removeLateRule(int index){
    if(from.length<=1)return;
    from.removeAt(index).dispose();
    to.removeAt(index).dispose();
    value.removeAt(index).dispose();
    action.removeAt(index);
  }
  final missIn=TextEditingController(text:'1'),missOut=TextEditingController(text:'1'),missDay=TextEditingController(text:'1');
  final excusedRules = <TextEditingController>[
    TextEditingController(text:'0'),
  ];
  final absentRules = List<TextEditingController>.generate(
    5, (_) => TextEditingController(text: '1'),
  );
  final sick=TextEditingController(text:'0'),injury=TextEditingController(text:'0');

  void addExcusedRule() => excusedRules.add(TextEditingController(text:'0'));
  void addAbsentRule() => absentRules.add(TextEditingController(text:'1'));
  void removeExcusedRule(int index) {
    if (excusedRules.length <= 1) return;
    excusedRules.removeAt(index).dispose();
  }
  void removeAbsentRule(int index) {
    if (absentRules.length <= 1) return;
    absentRules.removeAt(index).dispose();
  }
  final weeklyLeave=TextEditingController(text:'1'),publicLeave=TextEditingController(text:'1'),annualLeave=TextEditingController(text:'1');
  final days=<String>{'الجمعة'},depts=<String>{'كل الإدارات'},branches=<String>{'كل الفروع'},employees=<String>{};
  final employeeText=TextEditingController();
  void dispose(){for(final c in [name,start,end,graceIn,graceOut,monthGrace,multiplier,earlyIn,earlyOut,lateOut,missIn,missOut,missDay,sick,injury,weeklyLeave,publicLeave,annualLeave,employeeText,...excusedRules,...absentRules,...from,...to,...value]){c.dispose();}}
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
        IconButton(tooltip:'حذف الجهاز',onPressed:()=>_confirmDeviceDelete(i,d),icon:const Icon(Icons.delete_outline,color:_red)),
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
  Future<void> _confirmDeviceDelete(int index, _Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف جهاز البصمة'),
        content: Text('هل تريد حذف الجهاز «${device.name.text}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لا'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      if (index >= 0 && index < devices.length && identical(devices[index], device)) {
        devices.removeAt(index);
      } else {
        devices.remove(device);
      }
    });
    device.dispose();
  }

  void _test(_Device d){setState(()=>d.connected=false);_msg(d.method=='IP'?'اختبار IP الفعلي يحتاج موصل الجهاز والتحقق من الوصول إلى الشبكة.':'اختبار USB يحتاج إضافة دعم أصلي أو خدمة وسيطة.');}
  void _pull(_Device d){setState(()=>d.note='لم تُسحب حركات فعلية بعد؛ يلزم ربط موصل '+d.method+' وتخزين السجلات مع منع التكرار.');_msg(d.note);}
  void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
}
class _Device{
  final name=TextEditingController(text:'جهاز بصمة جديد'),model=TextEditingController(),ip=TextEditingController(),port=TextEditingController(text:'4370'),usb=TextEditingController();
  String method='IP',note='';bool connected=false;
  void dispose(){name.dispose();model.dispose();ip.dispose();port.dispose();usb.dispose();}
}
