import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _settingsPurple = Color(0xFF3E007D);
const _settingsOrange = Color(0xFFFFA015);
const _settingsPink = Color(0xFFFF27C3);

class ErpProgramSettingsScreen extends StatefulWidget {
  const ErpProgramSettingsScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpProgramSettingsScreen> createState() => _ErpProgramSettingsScreenState();
}

class _ErpProgramSettingsScreenState extends State<ErpProgramSettingsScreen> {
  SupabaseClient? _db;
  final _name = TextEditingController(text: 'سلسلة');
  final _primary = TextEditingController(text: '#3E007D');
  final _secondary = TextEditingController(text: '#FFA015');
  final _accent = TextEditingController(text: '#FF27C3');
  final _background = TextEditingController(text: '#FFFFFF');
  final List<TextEditingController> _sizes = List.generate(5, (i) => TextEditingController(text: ['24','20','17','15','13'][i]));
  final List<TextEditingController> _colors = List.generate(5, (i) => TextEditingController(text: ['#3E007D','#3E007D','#3E007D','#333333','#666666'][i]));
  final List<String> _fonts = List.filled(5, 'Cairo');
  final List<String> _labels = ['العنوان الرئيسي','العنوان الفرعي الأول','العنوان الفرعي الثاني','العنوان الفرعي الثالث','النص والعناوين الصغيرة'];
  final List<String> _levels = ['heading_1','heading_2','heading_3','heading_4','heading_5'];
  String _language = 'ar';
  String? _logoBase64, _logoMime;
  bool _loading = true, _saving = false;
  String? _error, _message;
  static const _fontOptions = ['Cairo','Tajawal','Almarai','Noto Sans Arabic','Arial','Roboto'];

  @override
  void initState() { super.initState(); try { _db = Supabase.instance.client; } catch (_) {} _load(); }
  @override
  void didUpdateWidget(covariant ErpProgramSettingsScreen oldWidget) { super.didUpdateWidget(oldWidget); if(oldWidget.companyId != widget.companyId) _load(); }
  @override
  void dispose() { _name.dispose(); _primary.dispose(); _secondary.dispose(); _accent.dispose(); _background.dispose(); for(final c in _sizes) { c.dispose(); } for(final c in _colors) { c.dispose(); } super.dispose(); }

  Color _parseColor(String value, Color fallback) {
    var raw = value.trim().replaceFirst('#','');
    if(raw.length == 8) raw = raw.substring(2);
    if(!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) return fallback;
    return Color(int.parse('FF'+raw, radix:16));
  }
  bool _validColor(String value) => RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value.trim());
  Future<void> _load() async {
    final company = (widget.companyId ?? '').trim();
    if(!mounted) return;
    setState(() { _loading = true; _error = null; _message = null; });
    if(company.isEmpty || _db == null) { setState(() { _loading=false; _error='اختر الشركة أولًا وتأكد من تسجيل الدخول والاتصال بقاعدة البيانات.'; }); return; }
    try {
      final row = await _db!.from('erp_program_settings').select().eq('company_id',company).maybeSingle();
      if(!mounted) return;
      if(row != null) {
        _name.text = (row['program_name'] ?? 'سلسلة').toString();
        _language = (row['language_code'] ?? 'ar').toString();
        _primary.text = (row['identity_primary_color'] ?? '#3E007D').toString();
        _secondary.text = (row['identity_secondary_color'] ?? '#FFA015').toString();
        _accent.text = (row['identity_accent_color'] ?? '#FF27C3').toString();
        _background.text = (row['identity_background_color'] ?? '#FFFFFF').toString();
        _logoBase64 = row['logo_base64']?.toString(); _logoMime = row['logo_mime_type']?.toString();
        final styles = row['heading_styles'];
        if(styles is List) {
          for(var i=0; i<5 && i<styles.length; i++) {
            if(styles[i] is Map) {
              final style = Map<String,dynamic>.from(styles[i] as Map);
              _sizes[i].text = (style['size'] ?? _sizes[i].text).toString();
              _colors[i].text = (style['color'] ?? _colors[i].text).toString();
              final font = (style['font'] ?? _fonts[i]).toString();
              _fonts[i] = _fontOptions.contains(font) ? font : 'Cairo';
            }
          }
        }
      }
      setState(() { _loading=false; });
    } catch(e) { if(!mounted) return; setState(() { _loading=false; _error='تعذر تحميل الإعدادات. تأكد من تطبيق ملف SQL الخاص بإعدادات البرنامج. $e'; }); }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type:FileType.image,allowMultiple:false,withData:true);
      if(result == null || result.files.isEmpty) return;
      final file = result.files.single, bytes = result.files.single.bytes;
      if(bytes == null || bytes.isEmpty) throw StateError('تعذر قراءة الصورة المختارة.');
      if(bytes.length > 1024*1024) throw ArgumentError('حجم الشعار يجب ألا يتجاوز 1 ميجابايت.');
      final ext = (file.extension ?? '').toLowerCase();
      final mime = {'png':'image/png','jpg':'image/jpeg','jpeg':'image/jpeg','webp':'image/webp'}[ext];
      if(mime == null) throw ArgumentError('الصيغ المدعومة للشعار: PNG وJPG وWEBP.');
      setState(() { _logoBase64=base64Encode(bytes); _logoMime=mime; _message='تم اختيار الشعار، احفظ الإعدادات لتثبيته.'; _error=null; });
    } catch(e) { if(mounted) setState(()=>_error='تعذر اختيار الشعار: $e'); }
  }

  Future<void> _save() async {
    final company = (widget.companyId ?? '').trim();
    if(company.isEmpty || _db == null) { setState(()=>_error='لا توجد شركة محددة أو اتصال بقاعدة البيانات.'); return; }
    if(_name.text.trim().isEmpty) { setState(()=>_error='اسم البرنامج مطلوب.'); return; }
    final allColors = [_primary.text,_secondary.text,_accent.text,_background.text,..._colors.map((c)=>c.text)];
    if(allColors.any((c)=>!_validColor(c))) { setState(()=>_error='أدخل الألوان بصيغة HEX صحيحة مثل #3E007D.'); return; }
    for(var i=0;i<5;i++) {
      final size = double.tryParse(_sizes[i].text.trim());
      if(size == null || size < 8 || size > 72) { setState(()=>_error='حجم الخط في "${_labels[i]}" يجب أن يكون من 8 إلى 72.'); return; }
    }
    setState(() { _saving=true; _error=null; _message=null; });
    try {
      final styles = List.generate(5,(i)=>{'key':_levels[i],'label':_labels[i],'font':_fonts[i],'size':double.parse(_sizes[i].text.trim()),'color':_colors[i].text.trim().toUpperCase()});
      await _db!.from('erp_program_settings').upsert({
        'company_id':company,'program_name':_name.text.trim(),'language_code':_language,
        'logo_base64':_logoBase64,'logo_mime_type':_logoMime,
        'identity_primary_color':_primary.text.trim().toUpperCase(),
        'identity_secondary_color':_secondary.text.trim().toUpperCase(),
        'identity_accent_color':_accent.text.trim().toUpperCase(),
        'identity_background_color':_background.text.trim().toUpperCase(),
        'heading_styles':styles,'updated_at':DateTime.now().toUtc().toIso8601String(),
        'updated_by':_db!.auth.currentUser?.id,
      },onConflict:'company_id');
      if(!mounted) return;
      setState(() { _saving=false; _message='تم حفظ إعدادات البرنامج في قاعدة البيانات.'; });
    } catch(e) { if(!mounted) return; setState(() { _saving=false; _error='تعذر حفظ الإعدادات: $e'; }); }
  }

  Widget _textField(TextEditingController controller,String label,{String? hint}) => TextField(controller:controller,style:const TextStyle(fontSize:14),decoration:InputDecoration(labelText:label,hintText:hint,isDense:true,constraints:const BoxConstraints(minHeight:52),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10))));
  Widget _colorField(TextEditingController c,String label) => Row(children:[Expanded(child:_textField(c,label,hint:'#3E007D')),const SizedBox(width:10),Container(width:42,height:42,decoration:BoxDecoration(color:_parseColor(c.text,_settingsPurple),borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.black12)))]);
  Widget _section(String title,IconData icon,Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Icon(icon,color:_settingsPurple),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:_settingsPurple))]),const SizedBox(height:14),child])));
  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewSettings() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة إعدادات البرنامج'),
      content: SizedBox(width: 540, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('اسم البرنامج: ${_name.text.trim().isEmpty ? 'سلسلة' : _name.text.trim()}'),
        const SizedBox(height: 8),
        Text('اللغة: ${_language == 'ar' ? 'العربية' : 'English'}'),
        const SizedBox(height: 8),
        Text('اللون الأساسي: ${_primary.text.trim()}'),
        const SizedBox(height: 8),
        Text('اللون الثانوي: ${_secondary.text.trim()}'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl,child:Padding(padding:const EdgeInsets.all(18),child:_loading?const Center(child:CircularProgressIndicator()):SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(color:_settingsPurple,child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Row(children:[Icon(Icons.tune_rounded,color:Color(0xFFFFA015),size:28),SizedBox(width:10),Expanded(child:Text('إعدادات البرنامج',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:Colors.white)))]),
      const Text('إدارة الاسم واللغة والهوية البصرية وخطوط العناوين بشكل موحد.',style:TextStyle(color:Colors.white70)),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        _quickTask('تحديث',Icons.refresh_rounded,Colors.blue,_loading?null:_load),
        _quickTask('حفظ',Icons.save_outlined,const Color(0xFF168447),_saving?null:_save),
        _quickTask('معاينة',Icons.visibility_outlined,const Color(0xFF6841A5),_previewSettings),
      ])),
    ]))),
    const SizedBox(height:14),
    _section('الاسم واللغة والشعار',Icons.apps_rounded,Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _textField(_name,'اسم البرنامج'),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_language,isExpanded:true,decoration:const InputDecoration(labelText:'لغة البرنامج',isDense:true,constraints:BoxConstraints(minHeight:52)),items:const[DropdownMenuItem(value:'ar',child:Text('العربية')),DropdownMenuItem(value:'en',child:Text('English'))],onChanged:(v){if(v!=null)setState(()=>_language=v);}),
      const SizedBox(height:12),
      Row(children:[Container(width:78,height:78,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.black12)),child:_logoBase64==null?const Icon(Icons.image_outlined,size:34,color:_settingsPurple):ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(_logoBase64!),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('صورة البرنامج / الشعار',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:_pickLogo,icon:const Icon(Icons.upload_file_rounded),label:const Text('اختيار صورة')),if(_logoBase64!=null)TextButton.icon(onPressed:(){setState((){_logoBase64=null;_logoMime=null;});},icon:const Icon(Icons.delete_outline),label:const Text('إزالة'))])]))]),
    ])),
    _section('ألوان وهوية البرنامج',Icons.palette_outlined,Column(children:[
      _colorField(_primary,'اللون الأساسي'),const SizedBox(height:10),_colorField(_secondary,'اللون الثانوي'),const SizedBox(height:10),_colorField(_accent,'لون التمييز'),const SizedBox(height:10),_colorField(_background,'لون الخلفية'),
      const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[for(final c in [_settingsPurple,_settingsOrange,_settingsPink,Colors.white,Colors.black])Container(width:32,height:32,decoration:BoxDecoration(color:c,shape:BoxShape.circle,border:Border.all(color:Colors.black12)))])
    ])),
    _section('نظام الخطوط — خمسة مستويات',Icons.text_fields_rounded,Column(children:[
      for(var i=0;i<5;i++) ...[
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF7F5FA),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('${i+1}. ${_labels[i]}',style:TextStyle(fontSize:double.tryParse(_sizes[i].text)??14,color:_parseColor(_colors[i].text,_settingsPurple),fontWeight:FontWeight.w800)),
          const SizedBox(height:10),
          Row(children:[Expanded(flex:3,child:DropdownButtonFormField<String>(value:_fonts[i],isExpanded:true,decoration:const InputDecoration(labelText:'نوع الخط',isDense:true,constraints:BoxConstraints(minHeight:52)),items:_fontOptions.map((font)=>DropdownMenuItem(value:font,child:Text(font,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)setState(()=>_fonts[i]=v);})),const SizedBox(width:10),Expanded(flex:1,child:_textField(_sizes[i],'الحجم'))]),
          const SizedBox(height:10),_colorField(_colors[i],'لون الخط')
        ])),
        if(i<4) const SizedBox(height:10),
      ]
    ])),
    if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(_error!,style:const TextStyle(color:Colors.red,fontWeight:FontWeight.w600))),
    if(_message!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(_message!,style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w600))),
    const SizedBox(height:8),Align(alignment:AlignmentDirectional.centerStart,child:FilledButton.icon(onPressed:_saving?null:_save,icon:Icon(_saving?Icons.hourglass_top_rounded:Icons.save_rounded),label:Text(_saving?'جارٍ الحفظ...':'حفظ إعدادات البرنامج'))),
  ]))));
}
