import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/erp_screen_frame.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class ErpScreenLayoutStudioScreen extends StatefulWidget {
  const ErpScreenLayoutStudioScreen({super.key});
  @override
  State<ErpScreenLayoutStudioScreen> createState() => _ErpScreenLayoutStudioScreenState();
}

class _ErpScreenLayoutStudioScreenState extends State<ErpScreenLayoutStudioScreen> {
  static const _storageKey = 'silsila_screen_layout_profiles_v1';
  static const _screens = <String>[
    'كل الشاشات - الإعداد الافتراضي', 'فئات الأصناف', 'دليل الأصناف', 'بيانات المخازن',
    'سياسات البرنامج', 'بيانات الشركة', 'المستخدمين', 'الملخص التنفيذي',
    'شاشة المبيعات', 'شاشة المشتريات', 'شاشة الحسابات المالية', 'شاشة الموارد البشرية',
  ];
  static const _views = <String, String>{
    'tree': 'شجرة', 'table': 'جدول بيانات', 'grid': 'شبكي - بطاقات', 'split': 'تقسيم جانبي',
  };
  static const _positions = <String, String>{
    'top': 'أعلى الشاشة', 'below_title': 'أسفل العنوان', 'above_content': 'قبل المحتوى',
    'right': 'يمين الشاشة', 'left': 'يسار الشاشة', 'bottom': 'أسفل الشاشة', 'hidden': 'مخفي',
  };

  String _screen = _screens.first;
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
  bool _showFooter = true, _showImages = true, _showSidebar = false, _showScroll = true;
  bool _loading = true;
  Map<String, dynamic> _profiles = {};

  Map<String, dynamic> get _current => Map<String, dynamic>.from(_profiles[_screen] is Map
      ? _profiles[_screen] as Map : _profiles['*'] is Map ? _profiles['*'] as Map : <String,dynamic>{});

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) _profiles = Map<String,dynamic>.from(decoded);
      }
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
    _showSidebar = value['showSidebar'] as bool? ?? false;
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
    final next = Map<String,dynamic>.from(_profiles)..[_screen] = _serialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(next));
    if (!mounted) return;
    setState(() => _profiles = next);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات تخطيط الشاشة على هذا الجهاز.')));
  }

  Future<void> _reset() async {
    setState(() { _profiles.remove(_screen); _apply(_current); });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_profiles));
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
        OutlinedButton.icon(onPressed:_loading?null:_reset,icon:const Icon(Icons.restart_alt),label:const Text('استعادة الافتراضي')),
      ],
      footer:const Text('الإصدار الحالي يحفظ ملفات التخطيط محليًا على الجهاز؛ ربطها بتطبيقات المستخدمين ومزامنتها مركزيًا مرحلة تالية.'),
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
            _choice('مكان شريط التمرير',_scrollPosition,_positions.keys.toList(),_positions,(v)=>setState(()=>_scrollPosition=v??_scrollPosition)),
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
              child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                if(_showTitle)Text(_screen,style:TextStyle(color:_primary,fontWeight:FontWeight.w900,fontSize:17)),
                if(_showTabs)Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Wrap(spacing:5,children:['بيانات','حركات','تقارير'].map((t)=>Chip(label:Text(t),backgroundColor:_primary.withValues(alpha:.10),side:BorderSide(color:_primary))).toList())),
                if(_showTasks)Wrap(spacing:5,children:['تحديث','إضافة','حفظ','تعديل','حذف','معاينة','طباعة','Excel','PDF'].map((t)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:_accent.withValues(alpha:.16),borderRadius:BorderRadius.circular(7)),child:Text(t,style:const TextStyle(fontSize:10)))).toList()),
                const SizedBox(height:8),
                Container(height:_rowHeight,alignment:Alignment.centerRight,padding:const EdgeInsets.symmetric(horizontal:8),color:_primary.withValues(alpha:.06),child:Text('صف بيانات تجريبي • ${_views[_view]} • ${_gridStyle}',style:const TextStyle(fontSize:11))),
                if(_showImages)const Align(alignment:Alignment.centerLeft,child:Icon(Icons.image_outlined,size:30,color:Colors.black38)),
                if(_showFooter)const Text('معلومات الصفحة • إجمالي السجلات • حالة التحميل',style:TextStyle(fontSize:10,color:Colors.black54)),
              ]),
            ),
          ]),
        ]),
      ),
    ),
  );
}
