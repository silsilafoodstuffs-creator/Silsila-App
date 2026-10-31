import 'package:flutter/material.dart';
import '../services/erp_company_settings_repository.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _green = Color(0xFF16834A);
const _red = Color(0xFFD32F2F);

class HrShiftRulesScreen extends StatefulWidget {
  const HrShiftRulesScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<HrShiftRulesScreen> createState() => _HrShiftRulesScreenState();
}

class _HrShiftRulesScreenState extends State<HrShiftRulesScreen> {
  final shifts = <_Shift>[ _Shift() ];
  int _selectedShiftIndex = 0;
  int? _editingShiftIndex;
  final weekdays = const ['السبت','الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة'];
  final departments = const ['كل الإدارات','الإدارة العامة','المبيعات','المخازن','الحسابات','الموارد البشرية'];
  final branches = const ['كل الفروع','الإدارة الرئيسية','فرع القاهرة','فرع الجيزة','فرع القليوبية','فرع الشرقية'];

  final _settingsRepository = ErpCompanySettingsRepository();
  bool _savingSettings = false;
  String? _savedSettingsMessage;

  @override
  void initState() {
    super.initState();
    if ((widget.companyId ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedRules());
    }
  }

  @override
  void didUpdateWidget(covariant HrShiftRulesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId && (widget.companyId ?? '').trim().isNotEmpty) {
      _loadSavedRules();
    }
  }

  Future<void> _loadSavedRules() async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty) return;
    try {
      final saved = await _settingsRepository.getSetting(companyId: companyId, key: 'hr_shift_rules');
      final raw = saved?['shifts'];
      if (raw is! List || raw.isEmpty || !mounted) return;
      final restored = raw.whereType<Map>().map((item) => _Shift.fromJson(Map<String, dynamic>.from(item))).toList();
      if (restored.isEmpty) return;
      setState(() {
        for (final shift in shifts) { shift.dispose(); }
        shifts
          ..clear()
          ..addAll(restored);
        _selectedShiftIndex = (saved?['selected_shift_index'] is num
            ? (saved!['selected_shift_index'] as num).toInt()
            : 0).clamp(0, shifts.length - 1).toInt();
        _editingShiftIndex = null;
        _savedSettingsMessage = 'تم تحميل قواعد الورديات المحفوظة.';
      });
    } catch (error) {
      if (mounted) setState(() => _savedSettingsMessage = 'تعذر تحميل القواعد المحفوظة: $error');
    }
  }

  Future<void> _saveRules() async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty) {
      _message('لا توجد شركة نشطة مرتبطة بالمستخدم؛ لم يتم حفظ القواعد.');
      return;
    }
    if (shifts.any((shift) => shift.name.text.trim().isEmpty || shift.start.text.trim().isEmpty || shift.end.text.trim().isEmpty)) {
      _message('يجب إدخال اسم ووقت بداية ونهاية لكل وردية.');
      return;
    }
    setState(() { _savingSettings = true; _savedSettingsMessage = null; });
    try {
      await _settingsRepository.saveSetting(
        companyId: companyId,
        key: 'hr_shift_rules',
        value: <String, Object?>{
          'shifts': shifts.map((shift) => shift.toJson()).toList(),
          'selected_shift_index': _selectedShiftIndex,
          'saved_at': DateTime.now().toIso8601String(),
        },
      );
      if (mounted) {
        setState(() {
          _savingSettings = false;
          _savedSettingsMessage = 'تم حفظ قواعد الورديات في قاعدة البيانات.';
        });
        _message('تم حفظ قواعد الورديات في قاعدة البيانات.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _savingSettings = false;
          _savedSettingsMessage = 'فشل حفظ قواعد الورديات: $error';
        });
        _message('فشل حفظ قواعد الورديات: $error');
      }
    }
  }

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
      OutlinedButton.icon(onPressed:_savingSettings?null:_saveRules,icon:_savingSettings?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_outlined,color:_orange),label:Text(_savingSettings?'جارٍ الحفظ...':'حفظ القواعد')),
      if(shifts.length>1) OutlinedButton.icon(onPressed:()=>_confirmDelete('الوردية المحددة',(){
        final removed=shifts.removeAt(_selectedShiftIndex);removed.dispose();
        setState((){_selectedShiftIndex=(_selectedShiftIndex-1).clamp(0,shifts.length-1).toInt();_editingShiftIndex=null;});
      }),icon:const Icon(Icons.delete_outline,color:_red),label:const Text('حذف الوردية المحددة')),
    ]),
    if(_savedSettingsMessage!=null) Padding(padding:const EdgeInsets.only(bottom:8),child:Text(_savedSettingsMessage!,style:const TextStyle(color:_purple,fontWeight:FontWeight.w700))),
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
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: TextField(
            controller: s.name,
            readOnly: !canEdit,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'اسم الوردية',
              hintText: 'اكتب اسمًا واضحًا للوردية',
              isDense: false,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            ),
            onChanged: canEdit ? (_) => setState(() {}) : null,
          ),
        ),
      ),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        Row(mainAxisSize:MainAxisSize.min,children:[
          Checkbox(value:s.nightShift,onChanged:canEdit?(v)=>setState(()=>s.nightShift=v??false):null,visualDensity:VisualDensity.compact),
          const Text('وردية ليل / سهر',style:TextStyle(fontSize:12)),
        ]),
        _field(s.start,'من',105,readOnly:!canEdit),
        _field(s.end,'إلى',105,readOnly:!canEdit),
        Container(width:125,padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),decoration:BoxDecoration(color:const Color(0xFFF1E9FA),borderRadius:BorderRadius.circular(8)),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('الساعات',style:TextStyle(fontSize:12)),Flexible(child:Text(_hours(s.start.text,s.end.text),textAlign:TextAlign.end,style:const TextStyle(color:_purple,fontSize:13,fontWeight:FontWeight.w900)))])),
      ])),
      _heading('العطلة الأسبوعية — اختيار متعدد'),
      Wrap(spacing:4,runSpacing:2,children:weekdays.map((d)=>FilterChip(label:Text(d,style:const TextStyle(fontSize:11)),selected:s.days.contains(d),selectedColor:const Color(0xFFFFE4BB),visualDensity:VisualDensity.compact,materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,onSelected:canEdit?(v)=>setState(()=>v?s.days.add(d):s.days.remove(d)):null)).toList()),
      _heading('قواعد السماح'),
      _numberFields([_num(s.graceIn,'سماح بداية الحضور',readOnly:!canEdit,width:170),_num(s.graceOut,'سماح نهاية الانصراف',readOnly:!canEdit,width:170),_num(s.monthGrace,'السماح الشهري',readOnly:!canEdit,width:170),_num(s.multiplier,'معامل الخصم',readOnly:!canEdit,width:170)]),
      _heading('قواعد الحضور والانصراف'),
      _numberFields([_num(s.earlyIn,'الحضور المبكر: قيمة الدقيقة إضافي',readOnly:!canEdit),_num(s.earlyOut,'الانصراف المبكر: قيمة الدقيقة خصم',readOnly:!canEdit),_num(s.lateOut,'الانصراف المتأخر: قيمة الدقيقة إضافي',readOnly:!canEdit)]),
      _heading('قواعد الحضور المتأخر — شرائح متتابعة'),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        horizontalMargin:12,
        columnSpacing:14,
        dataRowMinHeight:57,
        dataRowMaxHeight:57,
        headingRowHeight:57,
        headingRowColor:WidgetStateProperty.all(const Color(0xFFF1E9FA)),
        columns:const [DataColumn(label:Text('التأخير')),DataColumn(label:Text('من')),DataColumn(label:Text('إلى')),DataColumn(label:Text('جزاء/دقيقة')),DataColumn(label:Text('نوع')),DataColumn(label:Text('حذف'))],
        rows:List.generate(s.from.length,(n)=>DataRow(cells:[
          DataCell(Text('${n+1}',style:const TextStyle(fontSize:11))),
          DataCell(SizedBox(width:56,child:TextField(controller:s.from[n],readOnly:!canEdit,keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:4,vertical:8)),style:const TextStyle(fontSize:11),onChanged:canEdit?(_)=>setState((){}):null))),
          DataCell(SizedBox(width:56,child:TextField(controller:s.to[n],readOnly:!canEdit,keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:4,vertical:8)),style:const TextStyle(fontSize:11),onChanged:canEdit?(_)=>setState((){}):null))),
          DataCell(SizedBox(width:64,child:TextField(controller:s.value[n],readOnly:!canEdit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:4,vertical:8)),style:const TextStyle(fontSize:11)))),
          DataCell(DropdownButton<String>(isDense:true,style:const TextStyle(fontSize:11,color:_purple),value:s.action[n],items:const[DropdownMenuItem(value:'خصم',child:Text('خصم')),DropdownMenuItem(value:'إضافي',child:Text('إضافي'))],onChanged:canEdit?(v)=>setState(()=>s.action[n]=v??'خصم'):null)),
          DataCell(IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints(minWidth:28,minHeight:28),padding:EdgeInsets.zero,tooltip:'حذف قاعدة التأخير',onPressed:canEdit&&s.from.length>1?()=>_confirmDelete('قاعدة التأخير ${n+1}',()=>setState(()=>s.removeLateRule(n))):null,icon:const Icon(Icons.delete_outline,color:_red,size:18))),
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

  Widget _heading(String t)=>Padding(padding:const EdgeInsets.only(top:8,bottom:4),child:Text(t,style:const TextStyle(color:_purple,fontWeight:FontWeight.w900,fontSize:13)));
  Widget _field(TextEditingController c,String label,double w,{bool readOnly=false})=>SizedBox(width:w,child:Row(children:[
    SizedBox(width:35,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12))),
    Expanded(child:TextField(controller:c,readOnly:readOnly,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:6,vertical:8)),onChanged:readOnly?null:(_)=>setState((){}))),
  ]));
  String _unitFor(String label){
    if(label.contains('ساعة')||label.contains('الحضور')||label.contains('الانصراف')||label.contains('تأخير')||label.contains('الدقيقة')||label.contains('دقيقة')||label.contains('البصمة')||label.contains('السماح الشهري')||label.contains('سماح بداية')||label.contains('سماح نهاية'))return 'دقيقة';
    if(label.contains('اليوم')||label.contains('مرضي')||label.contains('إصابة')||label.contains('الأسبوعية')||label.contains('الرسمية')||label.contains('السنوية')||label.contains('غياب'))return 'يوم';
    if(label.contains('معامل'))return 'معامل';
    return 'ساعة';
  }
  Widget _num(TextEditingController c,String label,{bool readOnly=false,double width=205,String? unit})=>SizedBox(width:width,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
    Text(label,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700),maxLines:2,overflow:TextOverflow.ellipsis),
    const SizedBox(height:2),
    Row(children:[
      Expanded(child:TextField(controller:c,readOnly:readOnly,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:6)),style:const TextStyle(fontSize:12))),
      const SizedBox(width:3),
      Text(unit??_unitFor(label),style:const TextStyle(fontSize:10,color:Colors.black54)),
    ]),
  ]));
  Widget _numberFields(List<Widget> children)=>SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((child)=>Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: child,
      )).toList(),
    ),
  );

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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(rules.length, (index) => Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 122,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('$title رقم ${index + 1}',style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700),maxLines:1,overflow:TextOverflow.ellipsis),
                        const SizedBox(height:2),
                        Row(children:[
                          Expanded(child:TextField(controller:rules[index],readOnly:!canEdit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:6)),style:const TextStyle(fontSize:12))),
                          const SizedBox(width:3),
                          const Text('قيمة الجزاء',style:TextStyle(fontSize:9,color:Colors.black54)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity:VisualDensity.compact,
                    constraints:const BoxConstraints(minWidth:30,minHeight:32),
                    padding:EdgeInsets.zero,
                    tooltip: 'حذف $title رقم ${index + 1}',
                    onPressed: canEdit ? () => _confirmDelete('$title رقم ${index + 1}', () => onRemove(index)) : null,
                    icon: const Icon(Icons.delete_outline, color: _red,size:19),
                  ),
                ],
              ),
            )),
          ),
        ),
        if (canEdit)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style:OutlinedButton.styleFrom(visualDensity:VisualDensity.compact,padding:const EdgeInsets.symmetric(horizontal:10,vertical:6)),
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline, color: _orange,size:18),
              label: Text('إضافة $title'),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No / لا')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes / نعم، احذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) onDelete();
  }

  void _message(String m)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));
}

class _Shift {
  _Shift();
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
  final excusedRules = List<TextEditingController>.generate(
    4, (_) => TextEditingController(text:'0'),
  );
  final absentRules = List<TextEditingController>.generate(
    4, (_) => TextEditingController(text: '1'),
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
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name.text, 'start': start.text, 'end': end.text, 'nightShift': nightShift,
    'graceIn': graceIn.text, 'graceOut': graceOut.text, 'monthGrace': monthGrace.text,
    'multiplier': multiplier.text, 'earlyIn': earlyIn.text, 'earlyOut': earlyOut.text, 'lateOut': lateOut.text,
    'from': from.map((c) => c.text).toList(), 'to': to.map((c) => c.text).toList(),
    'value': value.map((c) => c.text).toList(), 'action': List<String>.from(action),
    'missIn': missIn.text, 'missOut': missOut.text, 'missDay': missDay.text,
    'excusedRules': excusedRules.map((c) => c.text).toList(),
    'absentRules': absentRules.map((c) => c.text).toList(),
    'sick': sick.text, 'injury': injury.text, 'weeklyLeave': weeklyLeave.text,
    'publicLeave': publicLeave.text, 'annualLeave': annualLeave.text,
    'days': days.toList(), 'depts': depts.toList(), 'branches': branches.toList(),
    'employees': employees.toList(), 'employeeText': employeeText.text,
  };

  factory _Shift.fromJson(Map<String, dynamic> json) {
    final shift = _Shift();
    void setText(TextEditingController controller, String key) {
      if (json[key] != null) controller.text = json[key].toString();
    }
    setText(shift.name, 'name'); setText(shift.start, 'start'); setText(shift.end, 'end');
    shift.nightShift = json['nightShift'] == true;
    setText(shift.graceIn, 'graceIn'); setText(shift.graceOut, 'graceOut');
    setText(shift.monthGrace, 'monthGrace'); setText(shift.multiplier, 'multiplier');
    setText(shift.earlyIn, 'earlyIn'); setText(shift.earlyOut, 'earlyOut'); setText(shift.lateOut, 'lateOut');
    setText(shift.missIn, 'missIn'); setText(shift.missOut, 'missOut'); setText(shift.missDay, 'missDay');
    setText(shift.sick, 'sick'); setText(shift.injury, 'injury');
    setText(shift.weeklyLeave, 'weeklyLeave'); setText(shift.publicLeave, 'publicLeave'); setText(shift.annualLeave, 'annualLeave');
    setText(shift.employeeText, 'employeeText');
    void setControllerList(List<TextEditingController> target, String key, String fallback) {
      final raw = json[key];
      if (raw is! List || raw.isEmpty) return;
      for (final controller in target) { controller.dispose(); }
      target.clear();
      target.addAll(raw.map((value) => TextEditingController(text: value.toString())));
    }
    setControllerList(shift.from, 'from', '1');
    setControllerList(shift.to, 'to', '10');
    setControllerList(shift.value, 'value', '1');
    setControllerList(shift.excusedRules, 'excusedRules', '0');
    setControllerList(shift.absentRules, 'absentRules', '1');
    final actions = json['action'];
    if (actions is List && actions.isNotEmpty) {
      shift.action
        ..clear()
        ..addAll(actions.map((value) => value.toString()));
      while (shift.action.length < shift.from.length) { shift.action.add('خصم'); }
      if (shift.action.length > shift.from.length) shift.action.removeRange(shift.from.length, shift.action.length);
    }
    void setStringSet(Set<String> target, String key) {
      final raw = json[key];
      if (raw is List) { target..clear()..addAll(raw.map((value) => value.toString())); }
    }
    setStringSet(shift.days, 'days'); setStringSet(shift.depts, 'depts');
    setStringSet(shift.branches, 'branches'); setStringSet(shift.employees, 'employees');
    return shift;
  }

  void dispose(){for(final c in [name,start,end,graceIn,graceOut,monthGrace,multiplier,earlyIn,earlyOut,lateOut,missIn,missOut,missDay,sick,injury,weeklyLeave,publicLeave,annualLeave,employeeText,...excusedRules,...absentRules,...from,...to,...value]){c.dispose();}}
}

class HrFingerprintDevicesScreen extends StatefulWidget {
  const HrFingerprintDevicesScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<HrFingerprintDevicesScreen> createState()=>_HrFingerprintDevicesScreenState();
}
class _HrFingerprintDevicesScreenState extends State<HrFingerprintDevicesScreen>{
  final devices=<_Device>[];
  final _settingsRepository = ErpCompanySettingsRepository();
  bool _savingDevices = false;
  String? _devicesMessage;

  @override
  void initState() {
    super.initState();
    if ((widget.companyId ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedDevices());
    }
  }

  @override
  void didUpdateWidget(covariant HrFingerprintDevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId && (widget.companyId ?? '').trim().isNotEmpty) {
      _loadSavedDevices();
    }
  }

  Future<void> _loadSavedDevices() async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty) return;
    try {
      final saved = await _settingsRepository.getSetting(companyId: companyId, key: 'hr_fingerprint_devices');
      final raw = saved?['devices'];
      if (raw is! List || !mounted) return;
      final restored = raw.whereType<Map>().map((item) => _Device.fromJson(Map<String, dynamic>.from(item))).toList();
      setState(() {
        for (final device in devices) { device.dispose(); }
        devices
          ..clear()
          ..addAll(restored);
        _devicesMessage = 'تم تحميل إعدادات أجهزة البصمة المحفوظة.';
      });
    } catch (error) {
      if (mounted) setState(() => _devicesMessage = 'تعذر تحميل إعدادات الأجهزة: $error');
    }
  }

  Future<void> _saveDevices() async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty) {
      _msg('لا توجد شركة نشطة؛ لم يتم حفظ الأجهزة.');
      return;
    }
    setState(() => _savingDevices = true);
    try {
      await _settingsRepository.saveSetting(
        companyId: companyId,
        key: 'hr_fingerprint_devices',
        value: <String, Object?>{
          'devices': devices.map((device) => device.toJson()).toList(),
          'saved_at': DateTime.now().toIso8601String(),
        },
      );
      if (mounted) {
        setState(() {
          _savingDevices = false;
          _devicesMessage = 'تم حفظ إعدادات أجهزة البصمة في قاعدة البيانات.';
        });
        _msg('تم حفظ إعدادات أجهزة البصمة في قاعدة البيانات.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _savingDevices = false;
          _devicesMessage = 'فشل حفظ إعدادات الأجهزة: $error';
        });
        _msg('فشل حفظ إعدادات الأجهزة: $error');
      }
    }
  }
  @override
  void dispose(){for(final d in devices){d.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('أجهزة البصمة وربط الحضور',style:TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),const Text('تعريف عدة أجهزة مع حالة اتصال مميزة بالألوان، وتجهيز السحب عبر IP أو USB.',style:TextStyle(color:Colors.black54,height:1.6)),
    const SizedBox(height:12),Wrap(spacing:8,children:[
      FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('إضافة جهاز'),style:FilledButton.styleFrom(backgroundColor:_purple)),
      OutlinedButton.icon(onPressed:_savingDevices?null:_saveDevices,icon:_savingDevices?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_outlined,color:_orange),label:Text(_savingDevices?'جارٍ الحفظ...':'حفظ الأجهزة')),
      OutlinedButton.icon(onPressed:()=>_msg('لم يتم إجراء اختبار فعلي. يلزم موصل متوافق مع موديل البصمة والبروتوكول.'),icon:const Icon(Icons.sync,color:_orange),label:const Text('فحص الاتصالات')),
    ]),
    if(_devicesMessage!=null) Padding(padding:const EdgeInsets.only(bottom:8),child:Text(_devicesMessage!,style:const TextStyle(color:_purple,fontWeight:FontWeight.w700))),
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
  _Device();
  final name=TextEditingController(text:'جهاز بصمة جديد'),model=TextEditingController(),ip=TextEditingController(),port=TextEditingController(text:'4370'),usb=TextEditingController();
  String method='IP',note='';bool connected=false;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name.text, 'model': model.text, 'ip': ip.text, 'port': port.text,
    'usb': usb.text, 'method': method, 'note': note, 'connected': connected,
  };

  factory _Device.fromJson(Map<String, dynamic> json) {
    final device = _Device();
    device.name.text = (json['name'] ?? 'جهاز بصمة جديد').toString();
    device.model.text = (json['model'] ?? '').toString();
    device.ip.text = (json['ip'] ?? '').toString();
    device.port.text = (json['port'] ?? '4370').toString();
    device.usb.text = (json['usb'] ?? '').toString();
    device.method = (json['method'] ?? 'IP').toString() == 'USB' ? 'USB' : 'IP';
    device.note = (json['note'] ?? '').toString();
    // Connection state is deliberately reset: a stored flag is not proof of a live device.
    device.connected = false;
    return device;
  }

  void dispose(){name.dispose();model.dispose();ip.dispose();port.dispose();usb.dispose();}
}
