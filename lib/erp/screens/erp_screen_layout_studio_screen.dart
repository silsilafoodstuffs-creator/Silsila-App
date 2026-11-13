import 'package:flutter/material.dart';
import '../widgets/erp_screen_frame.dart';
import '../services/erp_screen_layout_profiles.dart';
import '../services/erp_studio_repository.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class ErpScreenLayoutStudioScreen extends StatefulWidget {
  const ErpScreenLayoutStudioScreen({
    super.key,
    this.companyId,
    this.availableScreens = const <String>[],
  });
  final String? companyId;
  final List<String> availableScreens;
  @override
  State<ErpScreenLayoutStudioScreen> createState() => _ErpScreenLayoutStudioScreenState();
}

class _ErpScreenLayoutStudioScreenState extends State<ErpScreenLayoutStudioScreen> {
  final _repository = ErpStudioRepository();
  String? _syncMessage;
  static const _defaultScreen = 'كل الشاشات - الإعداد الافتراضي';
  static const _fallbackScreens = <String>[
    'فئات الأصناف', 'دليل الأصناف', 'بيانات المخازن', 'سياسات البرنامج',
    'بيانات الشركة', 'المستخدمين', 'الملخص التنفيذي', 'شاشة المبيعات',
    'شاشة المشتريات', 'شاشة الحسابات المالية', 'شاشة الموارد البشرية',
  ];
  List<String> get _screens => <String>{
    _defaultScreen,
    ..._fallbackScreens,
    ...widget.availableScreens.where((screen) => screen.trim().isNotEmpty),
  }.toList();
  static const _views = <String, String>{
    'tree': 'شجرة', 'table': 'جدول بيانات', 'grid': 'شبكي - بطاقات', 'split': 'تقسيم جانبي',
  };
  static const _positions = <String, String>{
    'top': 'أعلى الشاشة', 'below_title': 'أسفل العنوان', 'above_content': 'قبل المحتوى',
    'right': 'يمين الشاشة', 'left': 'يسار الشاشة', 'bottom': 'أسفل الشاشة', 'hidden': 'مخفي',
  };
  static const _scrollPositions = <String, String>{
    'right': 'يمين الشاشة', 'left': 'يسار الشاشة', 'hidden': 'مخفي',
  };

  String _screen = _defaultScreen;
  String _view = 'table';
  String _tabsPosition = 'below_title';
  String _tasksPosition = 'below_title';
  String _datePosition = 'top';
  String _imagesPosition = 'right';
  String _scrollPosition = 'right';
  String _gridStyle = 'compact';
  double _rowHeight = 40;
  double _spacing = 5;
  double _contentWidth = 100;
  double _cornerRadius = 12;
  Color _primary = _purple;
  Color _accent = _orange;
  bool _showTitle = true, _showTabs = true, _showTasks = true, _showDate = true;
  bool _showFooter = true, _showImages = true, _showSidebar = true, _showScroll = true;
  bool _loading = true;
  Map<String, dynamic> _profiles = {};

  String get _profileKey => _screen == _defaultScreen ? '*' : _screen;

  Map<String, dynamic> get _current => Map<String, dynamic>.from(_profiles[_profileKey] is Map
      ? _profiles[_profileKey] as Map : _profiles['*'] is Map ? _profiles['*'] as Map : <String,dynamic>{});

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await ErpScreenLayoutProfiles.load();
      final company = widget.companyId;
      if (company != null && company.trim().isNotEmpty) {
        try {
          final remote = await _repository.loadLayoutProfiles(company);
          await ErpScreenLayoutProfiles.mergeRemote(remote);
        } catch (error) {
          _syncMessage = 'تعذر تحميل التخطيطات المركزية؛ تم الاحتفاظ بالنسخ المحلية: $error';
        }
      }
      _profiles = Map<String, dynamic>.from(ErpScreenLayoutProfiles.profiles.value);
      _apply(_current);
    } catch (_) {
      // Keep usable defaults if local preferences are unavailable.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(Map<String, dynamic> value) {
    _view = value['view'] as String? ?? 'table';
    _tabsPosition = value['tabsPosition'] as String? ?? 'below_title';
    _tasksPosition = value['tasksPosition'] as String? ?? 'below_title';
    _datePosition = value['datePosition'] as String? ?? 'top';
    _imagesPosition = value['imagesPosition'] as String? ?? 'right';
    _scrollPosition = value['scrollPosition'] as String? ?? 'right';
    _gridStyle = value['gridStyle'] as String? ?? 'compact';
    _rowHeight = (value['rowHeight'] as num?)?.toDouble() ?? 40;
    _spacing = (value['spacing'] as num?)?.toDouble() ?? 5;
    _contentWidth = (value['contentWidth'] as num?)?.toDouble() ?? 100;
    _cornerRadius = (value['cornerRadius'] as num?)?.toDouble() ?? 12;
    _showTitle = value['showTitle'] as bool? ?? true;
    _showTabs = value['showTabs'] as bool? ?? true;
    _showTasks = value['showTasks'] as bool? ?? true;
    _showDate = value['showDate'] as bool? ?? true;
    _showFooter = value['showFooter'] as bool? ?? true;
    _showImages = value['showImages'] as bool? ?? true;
    _showSidebar = value['showSidebar'] as bool? ?? true;
    _showScroll = value['showScroll'] as bool? ?? true;
    _primary = Color((value['primary'] as int?) ?? _purple.value);
    _accent = Color((value['accent'] as int?) ?? _orange.value);
  }

  Map<String, dynamic> _serialize() => <String,dynamic>{
    'view':_view, 'tabsPosition':_tabsPosition, 'tasksPosition':_tasksPosition,
    'datePosition':_datePosition, 'imagesPosition':_imagesPosition,
    'scrollPosition':_scrollPosition, 'gridStyle':_gridStyle,
    'rowHeight':_rowHeight, 'spacing':_spacing, 'contentWidth':_contentWidth,
    'cornerRadius':_cornerRadius, 'showTitle':_showTitle, 'showTabs':_showTabs,
    'showTasks':_showTasks, 'showDate':_showDate, 'showFooter':_showFooter,
    'showImages':_showImages, 'showSidebar':_showSidebar, 'showScroll':_showScroll,
    'primary':_primary.value, 'accent':_accent.value,
  };

  Future<void> _save() async {
    await ErpScreenLayoutProfiles.save(_profileKey, _serialize());
    final company = widget.companyId;
    if (company != null && company.trim().isNotEmpty) {
      try {
        await _repository.saveLayoutProfile(companyId: company, profileKey: _profileKey, profile: _serialize());
        await ErpScreenLayoutProfiles.markSynced(_profileKey);
        _syncMessage = 'تم حفظ التخطيط محلياً ومركزياً.';
      } catch (error) {
        _syncMessage = 'حُفظ التخطيط محلياً، والمزامنة المركزية معلقة: $error';
      }
    } else {
      _syncMessage = 'تم حفظ التخطيط محلياً؛ اختر شركة نشطة للمزامنة المركزية.';
    }
    if (!mounted) return;
    setState(() => _profiles = Map<String, dynamic>.from(ErpScreenLayoutProfiles.profiles.value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_syncMessage!)));
  }

  Future<void> _reset() async {
    final company = widget.companyId;
    if (company != null && company.trim().isNotEmpty) {
      try {
        await _repository.deleteLayoutProfile(companyId: company, profileKey: _profileKey);
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف النسخة المركزية: $error'), backgroundColor: Colors.red));
        return;
      }
    }
    await ErpScreenLayoutProfiles.reset(_profileKey);
    if (!mounted) return;
    setState(() { _profiles = Map<String, dynamic>.from(ErpScreenLayoutProfiles.profiles.value); _apply(_current); });
  }

  Future<void> _syncPendingProfiles() async {
    final company = widget.companyId;
    if (company == null || company.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب اختيار شركة نشطة للمزامنة المركزية.')));
      return;
    }
    try {
      final pending = ErpScreenLayoutProfiles.pendingProfiles();
      var synced = 0;
      final errors = <String>[];
      for (final entry in pending.entries) {
        try {
          await _repository.saveLayoutProfile(companyId: company, profileKey: entry.key, profile: entry.value);
          await ErpScreenLayoutProfiles.markSynced(entry.key);
          synced++;
        } catch (error) {
          errors.add('${entry.key}: $error');
        }
      }
      if (!mounted) return;
      setState(() => _syncMessage = errors.isEmpty
          ? 'تمت مزامنة $synced تخطيط.'
          : 'تمت مزامنة $synced، وتعذرت مزامنة ${errors.length}.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_syncMessage!)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت المزامنة: $error'), backgroundColor: Colors.red));
    }
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    elevation: 1, margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFECE7F2))),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children:[Icon(icon,color:_purple,size:19),const SizedBox(width:8),Text(title,style:const TextStyle(fontWeight:FontWeight.w900,color:_purple,fontSize:14))]),
      const SizedBox(height:8), ...children,
    ])),
  );

  Widget _choice(String label, String value, List<String> keys, Map<String,String> labels, ValueChanged<String?> onChanged) =>
    Padding(padding: const EdgeInsets.symmetric(vertical:3), child: Row(children:[
      SizedBox(width:150,child:Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
      Expanded(child:DropdownButtonFormField<String>(
        value:value, isExpanded:true, isDense:true,
        decoration:const InputDecoration(border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:9,vertical:8)),
        items:keys.map((k)=>DropdownMenuItem(value:k,child:Text(labels[k]??k,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12)))).toList(),
        onChanged:onChanged,
      )),
    ]));

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => SizedBox(
    width: 190, child: CheckboxListTile(
      dense:true, contentPadding:EdgeInsets.zero, controlAffinity:ListTileControlAffinity.leading,
      activeColor:_purple, value:value, onChanged:(v)=>onChanged(v==true),
      title:Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
    ));

  Widget _slider(String label, double value, double min, double max, String suffix, ValueChanged<double> onChanged) =>
    Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[
      SizedBox(width:150,child:Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
      Expanded(child:Slider(value:value,min:min,max:max,divisions:(max-min).round(),activeColor:_purple,onChanged:onChanged)),
      SizedBox(width:52,child:Text('${value.toStringAsFixed(0)}$suffix',textAlign:TextAlign.end,style:const TextStyle(fontSize:11))),
    ]));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection:TextDirection.rtl,
    child:ErpScreenFrame(
      title:'استوديو تخطيط الشاشات',
      subtitle:'تخصيص تخطيط الواجهات مع الحفاظ على وظائف كل شاشة',
      icon:Icons.dashboard_customize_outlined,
      actions:[
        ElevatedButton.icon(onPressed:_loading?null:_save,icon:const Icon(Icons.save_outlined),label:const Text('حفظ الإعدادات')),
        const SizedBox(width:6),
        OutlinedButton.icon(onPressed:_loading?null:_syncPendingProfiles,icon:const Icon(Icons.cloud_sync_outlined),label:const Text('مزامنة التخطيطات')),
        const SizedBox(width:6),
        OutlinedButton.icon(onPressed:_loading?null:_reset,icon:const Icon(Icons.restart_alt),label:const Text('استعادة الافتراضي')),
      ],
      footer:Text(_syncMessage ?? 'التخطيطات تحفظ محلياً وتتم مزامنتها مركزياً عند توفر الاتصال وصلاحية مدير الشركة. إعدادات الألوان والكثافة تطبق على صفحات ERP؛ خيارات إظهار عناصر العنوان تعمل مع الإطار الموحد.'),
      child:_loading?const Center(child:CircularProgressIndicator()):SingleChildScrollView(
        padding:const EdgeInsets.all(4),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _section('الشاشة المستهدفة',Icons.web_asset_outlined,[
            _choice('تطبيق الإعداد على',_screen,_screens,{for(final s in _screens)s:s},(v){if(v==null)return;setState((){_screen=v;_apply(_current);});}),
            const Text('اختيار «كل الشاشات» يحدد القيم الافتراضية العامة، ويمكن تخصيص كل شاشة بصورة مستقلة.',style:TextStyle(fontSize:11,color:Colors.black54)),
          ]),
          _section('طريقة عرض البيانات',Icons.view_quilt_outlined,[
            _choice('نمط العرض',_view,_views.keys.toList(),_views,(v)=>setState(()=>_view=v??_view)),
            _choice('شكل Grid Data',_gridStyle,['compact','comfortable','striped','outlined'],{'compact':'مضغوط','comfortable':'مريح','striped':'صفوف متبادلة','outlined':'حدود كاملة'},(v)=>setState(()=>_gridStyle=v??_gridStyle)),
            _toggle('إظهار الشريط الجانبي',_showSidebar,(v)=>setState(()=>_showSidebar=v)),
          ]),
          _section('مواضع عناصر الشاشة',Icons.open_with,[
            _choice('مكان التبويبات',_tabsPosition,_positions.keys.toList(),_positions,(v)=>setState(()=>_tabsPosition=v??_tabsPosition)),
            _choice('مكان أزرار المهام',_tasksPosition,_positions.keys.toList(),_positions,(v)=>setState(()=>_tasksPosition=v??_tasksPosition)),
            _choice('مكان التاريخ والفلاتر الزمنية',_datePosition,_positions.keys.toList(),_positions,(v)=>setState(()=>_datePosition=v??_datePosition)),
            _choice('مكان الصور',_imagesPosition,_positions.keys.toList(),_positions,(v)=>setState(()=>_imagesPosition=v??_imagesPosition)),
            _choice('مكان شريط التمرير',_scrollPosition,_scrollPositions.keys.toList(),_scrollPositions,(v)=>setState(()=>_scrollPosition=v??_scrollPosition)),
          ]),
          _section('إظهار وإخفاء المكونات',Icons.visibility_outlined,[
            Wrap(spacing:8,runSpacing:0,children:[
              _toggle('العنوان',_showTitle,(v)=>setState(()=>_showTitle=v)),
              _toggle('التبويبات',_showTabs,(v)=>setState(()=>_showTabs=v)),
              _toggle('أزرار المهام',_showTasks,(v)=>setState(()=>_showTasks=v)),
              _toggle('التاريخ',_showDate,(v)=>setState(()=>_showDate=v)),
              _toggle('التذييل ومعلومات الصفحة',_showFooter,(v)=>setState(()=>_showFooter=v)),
              _toggle('الصور',_showImages,(v)=>setState(()=>_showImages=v)),
              _toggle('أشرطة التمرير',_showScroll,(v)=>setState(()=>_showScroll=v)),
            ]),
          ]),
          _section('الأبعاد والمسافات',Icons.aspect_ratio,[
            _slider('ارتفاع الصف والحقل',_rowHeight,32,64,' px',(v)=>setState(()=>_rowHeight=v)),
            _slider('المسافة بين العناصر',_spacing,0,20,' px',(v)=>setState(()=>_spacing=v)),
            _slider('عرض منطقة المحتوى',_contentWidth,60,100,'%',(v)=>setState(()=>_contentWidth=v)),
            _slider('استدارة الزوايا',_cornerRadius,0,24,' px',(v)=>setState(()=>_cornerRadius=v)),
          ]),
          _section('ألوان الواجهة',Icons.palette_outlined,[
            Wrap(spacing:8,children:[
              for(final entry in <String,Color>{'البنفسجي':_purple,'البرتقالي':_orange,'الوردي':const Color(0xFFFF27C3),'أزرق':const Color(0xFF1976D2),'رمادي داكن':const Color(0xFF424242)}.entries)
                ChoiceChip(label:Text(entry.key),selected:_primary==entry.value,onSelected:(_)=>setState(()=>_primary=entry.value),selectedColor:entry.value.withValues(alpha:.18),side:BorderSide(color:entry.value)),
            ]),
            const SizedBox(height:6),
            Row(children:[const Text('لون التمييز: ',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700)),Container(width:24,height:24,decoration:BoxDecoration(color:_accent,borderRadius:BorderRadius.circular(6))),const SizedBox(width:8),Text('#${_accent.value.toRadixString(16).substring(2).toUpperCase()}',style:const TextStyle(fontSize:11))]),
            Wrap(spacing:6,children:[
              for(final c in const [Color(0xFFFFA015),Color(0xFFFF27C3),Color(0xFF1976D2),Color(0xFF26A69A),Color(0xFF6D4C41)])
                InkWell(onTap:()=>setState(()=>_accent=c),child:Container(width:25,height:25,decoration:BoxDecoration(color:c,shape:BoxShape.circle,border:Border.all(color:Colors.black12)))),
            ]),
          ]),
          _section('معاينة فورية للتخطيط',Icons.preview_outlined,[
            Container(
              padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(_cornerRadius),border:Border.all(color:_primary.withValues(alpha:.35)),boxShadow:const [BoxShadow(color:Color(0x10000000),blurRadius:5)]),
              child:LayoutBuilder(builder:(context,constraints){
                Widget chip(String label,Color color)=>Container(
                  padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
                  decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(7),border:Border.all(color:color.withValues(alpha:.25))),
                  child:Text(label,style:TextStyle(fontSize:10,color:color,fontWeight:FontWeight.w700)),
                );
                Widget tabs()=>Wrap(spacing:5,runSpacing:4,children:['بيانات','حركات','تقارير'].map((t)=>chip(t,_primary)).toList());
                Widget tasks()=>Wrap(spacing:4,runSpacing:4,children:['تحديث','إضافة','حفظ','تعديل','حذف','معاينة','طباعة','Excel','PDF'].map((t)=>chip(t,_accent)).toList());
                Widget date()=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),decoration:BoxDecoration(color:const Color(0xFFF5EFFB),borderRadius:BorderRadius.circular(7)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.calendar_month_outlined,size:15),SizedBox(width:5),Text('من تاريخ — إلى تاريخ',style:TextStyle(fontSize:10))]));
                Widget images()=>const Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.image_outlined,size:34,color:Colors.black38),Text('صور الأصناف',style:TextStyle(fontSize:9,color:Colors.black54))]);
                Widget scrollIndicator()=>Container(width:5,height:54,decoration:BoxDecoration(color:_showScroll?const Color(0xFFD9CDE8):Colors.transparent,borderRadius:BorderRadius.circular(5)));
                Widget sampleData()=>Container(
                  width:double.infinity,
                  padding:const EdgeInsets.all(7),
                  decoration:BoxDecoration(color:_primary.withValues(alpha:.045),border:Border.all(color:_primary.withValues(alpha:.12)),borderRadius:BorderRadius.circular(6)),
                  child:_view=='grid'
                    ?Wrap(spacing:5,runSpacing:5,children:List.generate(4,(i)=>Container(width:(constraints.maxWidth-55)/2,height:_rowHeight,alignment:Alignment.center,decoration:BoxDecoration(border:Border.all(color:_primary.withValues(alpha:.2)),borderRadius:BorderRadius.circular(5)),child:Text('بطاقة ${i+1}',style:const TextStyle(fontSize:10))))
                    :_view=='tree'
                      ?Column(crossAxisAlignment:CrossAxisAlignment.start,children:const [Text('▾ دليل البيانات',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700)),Padding(padding:EdgeInsetsDirectional.only(start:18),child:Text('• عنصر رئيسي\n• عنصر فرعي',style:TextStyle(fontSize:10)))])
                      :_view=='split'
                        ?Row(children:[Expanded(child:Text('قائمة العناصر\nعنصر 1\nعنصر 2',style:TextStyle(fontSize:10))),const VerticalDivider(width:12),Expanded(child:Text('تفاصيل العنصر المحدد',style:TextStyle(fontSize:10)))])
                        :Column(children:[Container(height:28,alignment:Alignment.centerRight,color:_primary.withValues(alpha:.10),child:const Text('الكود     اسم الصنف     الرصيد',style:TextStyle(fontSize:9,fontWeight:FontWeight.w700))),for(var i=0;i<3;i++)Container(height:_rowHeight/1.7,alignment:Alignment.centerRight,padding:const EdgeInsets.symmetric(horizontal:5),color:i.isEven?Colors.white:const Color(0xFFFAF8FC),child:Text('ITM-00${i+1}     صنف تجريبي     120',style:const TextStyle(fontSize:9)))]),
                );
                final dateWidget=_showDate&&_datePosition!='hidden'?date():null;
                final tabsWidget=_showTabs&&_tabsPosition!='hidden'?tabs():null;
                final tasksWidget=_showTasks&&_tasksPosition!='hidden'?tasks():null;
                final imagesWidget=_showImages&&_imagesPosition!='hidden'?images():null;
                final top=<Widget>[], middle=<Widget>[], bottom=<Widget>[];
                final sideLeft=<Widget>[],sideRight=<Widget>[];
                void place(Widget? widget,String position){
                  if(widget==null||position=='hidden')return;
                  if(position=='top'||position=='above_content')top.add(widget);
                  else if(position=='bottom')bottom.add(widget);
                  else if(position=='left')sideLeft.add(widget);
                  else if(position=='right')sideRight.add(widget);
                  else middle.add(widget);
                }
                place(dateWidget,_datePosition);
                place(tabsWidget,_tabsPosition);
                place(tasksWidget,_tasksPosition);
                place(imagesWidget,_imagesPosition);
                if(_showSidebar){
                  sideLeft.insert(0,Container(width:42,padding:const EdgeInsets.all(5),color:_primary.withValues(alpha:.06),child:const Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.dashboard_outlined,size:16),Icon(Icons.inventory_2_outlined,size:16),Icon(Icons.settings_outlined,size:16)])));
                }
                if(_showScroll&&_scrollPosition=='left')sideLeft.add(scrollIndicator());
                if(_showScroll&&_scrollPosition=='right')sideRight.add(scrollIndicator());
                return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  if(_showTitle)Text(_screen,style:TextStyle(color:_primary,fontWeight:FontWeight.w900,fontSize:17)),
                  for(final item in top)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:item),
                  Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    if(sideLeft.isNotEmpty)Column(children:sideLeft.map((w)=>Padding(padding:const EdgeInsets.all(3),child:w)).toList()),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                      for(final item in middle)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:item),
                      sampleData(),
                    ])),
                    if(sideRight.isNotEmpty)Column(children:sideRight.map((w)=>Padding(padding:const EdgeInsets.all(3),child:w)).toList()),
                  ]),
                  for(final item in bottom)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:item),
                  if(_showFooter)const Text('معلومات الصفحة • إجمالي السجلات • حالة التحميل',style:TextStyle(fontSize:10,color:Colors.black54)),
                ]);
              }),
            ),
            const Padding(padding:EdgeInsets.only(top:5),child:Text('المعاينة توضح توزيع العناصر المختارة قبل الحفظ؛ تطبيق المواضع على الشاشة الفعلية يعتمد على مكونات الشاشة المرتبطة بإطار التخطيط.',style:TextStyle(fontSize:10,color:Colors.black54))),
          ]),
        ]),
      ),
    ),
  );
}
