import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import 'erp_code_policy_panel.dart';

class ErpProgramPoliciesScreen extends StatefulWidget {
  const ErpProgramPoliciesScreen({super.key, required this.companyId});
  final String? companyId;
  @override State<ErpProgramPoliciesScreen> createState() => _ErpProgramPoliciesScreenState();
}

class _ErpProgramPoliciesScreenState extends State<ErpProgramPoliciesScreen> {
  static const tabs = ['برمجية','تكويدية','محاسبية','مخزنية','بيعية','شرائية','إدارية','الخطوط والألوان','الكل'];
  static const defaults = <Map<String,dynamic>>[
    {'key':'visual_identity.program_name','category':'برمجية','ar':'اسم المشروع','en':'Project name','value':'سلسلة','mandatory':true,'all':true},
    {'key':'visual_identity.logo','category':'برمجية','ar':'شعار المشروع','en':'Project logo','value':'','mandatory':true,'all':true},
    {'key':'code_generation_registry','category':'تكويدية','ar':'سياسات التكويد المركزي','en':'Central code generation policies','value':'إعدادات التكويد المركزي','mandatory':true,'all':true},
    {'key':'geo_code.country','category':'تكويدية','ar':'سياسة تكويد دول','en':'Country coding policy','value':'{"prefix":"Con","digits":2,"parent_digits":0}','mandatory':true,'all':true},
    {'key':'geo_code.governorate','category':'سياسات الأكواد','ar':'سياسة تكويد محافظات','en':'Governorate coding policy','value':'{"prefix":"Gov","digits":2,"parent_digits":2}','mandatory':true,'all':true},
    {'key':'geo_code.district','category':'سياسات الأكواد','ar':'سياسة تكويد أحياء/مراكز','en':'District/center coding policy','value':'{"prefix":"Dis","digits":2,"parent_digits":4}','mandatory':true,'all':true},
    {'key':'geo_code.area','category':'سياسات الأكواد','ar':'سياسة تكويد مناطق/قرى','en':'Area/village coding policy','value':'{"prefix":"Rig","digits":2,"parent_digits":6}','mandatory':true,'all':true},
    {'key':'customer_code','category':'سياسات الأكواد','ar':'سياسة تكويد العملاء','en':'Customer coding policy','value':'{"prefix":"Cus","geo_digits":8,"serial_digits":2,"required":true,"apply_to_all":true}','mandatory':true,'all':true},
    {'key':'category_code.main','category':'سياسات الأكواد','ar':'سياسة تكويد فئات أصناف رئيسية','en':'Main item category coding policy','value':'{"prefix":"Cat","digits":2,"parent_digits":0}','mandatory':true,'all':true},
    {'key':'category_code.sub','category':'سياسات الأكواد','ar':'سياسة تكويد فئات أصناف فرعية','en':'Sub item category coding policy','value':'{"prefix":"Cat","digits":2,"parent_digits":2}','mandatory':true,'all':true},
    {'key':'category_code.secondary','category':'سياسات الأكواد','ar':'سياسة تكويد فئات أصناف ثانوية','en':'Secondary item category coding policy','value':'{"prefix":"Cat","digits":2,"parent_digits":4}','mandatory':true,'all':true},
    {'key':'brand_code','category':'سياسات الأكواد','ar':'سياسة تكويد البراند','en':'Brand coding policy','value':'{"prefix":"Bra","digits":3,"parent_digits":0}','mandatory':true,'all':true},
    {'key':'item_code','category':'سياسات الأكواد','ar':'سياسة تكويد الأصناف','en':'Item coding policy','value':'{"prefix":"Itm","category_digits":6,"serial_digits":3}','mandatory':true,'all':true},
    {'key':'ui_dimensions','category':'برمجية','ar':'السماح بتعديل مساحة وحدود الأزرار والخانات','en':'Allow changing button and field dimensions'},
    {'key':'ui_reorder','category':'برمجية','ar':'نقل مكان الأزرار وتعديل ترتيب الأعمدة أو الصفوف','en':'Reposition buttons and reorder columns or rows'},
    {'key':'ui_layout_standard','category':'برمجية','ar':'المعيار الموحد لارتفاع الخانات والصفوف والمسافات بين الخانات والأعمدة','en':'Global standard for cell/row height and cell/column spacing','value':'{"row_height":50,"field_height":40,"column_spacing":3}','mandatory':true,'all':true},
    {'key':'ui_dropdown_item_height','category':'برمجية','ar':'الارتفاع القياسي لكل اختيار داخل القوائم المنسدلة','en':'Standard dropdown option height','value':'40 بكسل','all':true},
    {'key':'ui_field_label_alignment','category':'برمجية','ar':'موضع اسم الخانة بالنسبة إلى القيمة أو الاختيار','en':'Field label alignment','value':'اسم الخانة على يمين القيمة أو الاختيار في صف واحد متناسق','all':true},
    {'key':'ui_mobile_header_compact','category':'برمجية','ar':'ارتفاع الهيدر في شاشات الموبايل','en':'Compact mobile screen headers','value':'هيدر مدمج بارتفاع مناسب دون فراغات أو ارتفاع مبالغ فيه','all':true},
    {'key':'fiscal_year','category':'محاسبية','ar':'فترة السنة المالية','en':'Fiscal year','mandatory':true,'value':'01/01 - 12/31'},
    {'key':'inventory_valuation','category':'محاسبية','ar':'طريقة تقييم المخزون','en':'Inventory valuation method','mandatory':true,'value':'المتوسط المرجح','options':['المتوسط المرجح','الوارد أولاً صادر أولاً (FIFO)','التحديد المحدد']},
    {'key':'inventory_count','category':'محاسبية','ar':'طريقة الجرد','en':'Inventory counting method','mandatory':true,'value':'الجرد المستمر','options':['الجرد المستمر','الجرد الدوري']},
    {'key':'depreciation','category':'محاسبية','ar':'طريقة إهلاك الأصول','en':'Asset depreciation method','mandatory':true,'value':'القسط الثابت','options':['القسط الثابت','القسط المتناقص','وحدات الإنتاج']},
    {'key':'group_duplicate_items','category':'مخزنية','ar':'تجميع الأصناف المتكررة في شاشات المخازن','en':'Group duplicate items in inventory screens'},
    {'key':'zero_adjustment_only','category':'مخزنية','ar':'اشتراط ترحيل التسوية المخزنية بصفر فقط','en':'Require inventory adjustments to post only at zero'},
    {'key':'adjustment_sale_price','category':'مخزنية','ar':'سعر الصنف في التسوية المخزنية هو سعر البيع بدلاً من سعر الشراء','en':'Use sale price in inventory adjustments'},
    {'key':'inventory.stocktake.valuation_basis','category':'مخزنية','ar':'أساس تقييم فروق الجرد','en':'Stocktake variance valuation basis','mandatory':true,'value':'sale','options':['sale','purchase']},
    {'key':'balance_sale_price','category':'مخزنية','ar':'سعر الصنف في تقارير الأرصدة هو سعر البيع بدلاً من سعر الشراء','en':'Use sale price in balance reports'},
    {'key':'trader_market.sell_duration_hours','category':'بيعية','ar':'الحد الأقصى لمدة طلبات عايز أبيع (بالساعات)','en':'Maximum sell request duration (hours)','value':'24','enabled_default':true,'all':true},
    {'key':'trader_market.buy_duration_hours','category':'بيعية','ar':'الحد الأقصى لمدة طلبات عايز أشتري (بالساعات)','en':'Maximum buy request duration (hours)','value':'24','enabled_default':true,'all':true},
    {'key':'trader_market.transfer_duration_hours','category':'بيعية','ar':'الحد الأقصى لمدة طلبات عايز أنقل (بالساعات)','en':'Maximum transfer request duration (hours)','value':'24','enabled_default':true,'all':true},
    {'key':'trader_market.story_duration','category':'بيعية','ar':'الحد الأقصى لمدة القصة','en':'Maximum story duration','value':'60','enabled_default':true,'all':true},
    {'key':'trader_market.story_duration_unit','category':'بيعية','ar':'وحدة قياس مدة القصة','en':'Story duration unit','value':'دقيقة','options':['دقيقة','ساعة'],'enabled_default':true,'all':true},
    {'key':'customer_default_rep','category':'بيعية','ar':'إمكانية تغيير المندوب الافتراضي للعميل','en':'Allow changing customer default sales representative'},
    {'key':'customer_default_price_policy','category':'بيعية','ar':'إمكانية تغيير سياسة الأسعار الافتراضية للعميل','en':'Allow changing customer default price policy'},
    {'key':'edit_other_user_document','category':'بيعية','ar':'إمكانية تعديل المستند لغير المستخدم الأصلي','en':'Allow editing documents created by another user'},
    {'key':'customer_shortages_to_invoice','category':'بيعية','ar':'إضافة نواقص العملاء الواردة إلى فاتورة البيع مباشرة','en':'Add customer shortages directly to sales invoice'},
    {'key':'sales_invoice_audit','category':'بيعية','ar':'عمل سجل لكل حركات فاتورة البيع','en':'Log all sales invoice actions'},
    {'key':'skip_quotation','category':'بيعية','ar':'تخطي عرض أسعار في أمر البيع','en':'Skip quotation in sales order','all':true},
    {'key':'skip_sales_order','category':'بيعية','ar':'تخطي أمر البيع في فاتورة البيع','en':'Skip sales order in sales invoice'},
    {'key':'skip_supply_order','category':'شرائية','ar':'تخطي أمر التوريد في أمر الشراء','en':'Skip supply order in purchase order'},
    {'key':'skip_purchase_order','category':'شرائية','ar':'تخطي أمر الشراء في فاتورة الشراء','en':'Skip purchase order in purchase invoice'},
    {'key':'supplier_bonus_variance','category':'شرائية','ar':'تحديد نسبة فروقات وارد حوافز الموردين','en':'Set supplier incentives incoming variance','value':'0.025%'},
    {'key':'national_id_required','category':'إدارية','ar':'الرقم القومي الزامي لتسجيل موظف جديد','en':'Require national ID for new employees','all':true},
    {'key':'appearance.language','category':'الخطوط والألوان','ar':'لغة واجهة البرنامج والتطبيقات','en':'Program and apps interface language','value':'العربية','options':['العربية','الإنجليزية'],'mandatory':true,'all':true},
    {'key':'appearance.header_background','category':'الخطوط والألوان','ar':'لون الهيدر في جميع الشاشات والتقارير','en':'Header background color','value':'#3E007D','mandatory':true,'all':true},
    {'key':'appearance.screen_background','category':'الخطوط والألوان','ar':'لون الخلفية في جميع الشاشات والتقارير','en':'Screen and report background color','value':'#FFFFFF','mandatory':true,'all':true},
    {'key':'appearance.header_text','category':'الخطوط والألوان','ar':'لون خط الهيدر ونوعه','en':'Header font style','value':'{"font":"Tajawal","size":25,"bold":false,"color":"#FFFFFF"}','mandatory':true,'all':true},
    {'key':'appearance.main_heading','category':'الخطوط والألوان','ar':'تنسيق خط العنوان الرئيسي ونوعه','en':'Main heading font style','value':'{"font":"Tajawal","size":20,"bold":true,"color":"#3E007D"}','mandatory':true,'all':true},
    {'key':'appearance.subheading_1','category':'الخطوط والألوان','ar':'تنسيق خط العنوان الفرعي الأول','en':'First subheading font style','value':'{"font":"Tajawal","size":15,"bold":true,"color":"#3E007D"}','mandatory':true,'all':true},
    {'key':'appearance.subheading_2','category':'الخطوط والألوان','ar':'تنسيق خط العنوان الفرعي الثاني ونوعه','en':'Second subheading font style','value':'{"font":"Tajawal","size":10,"bold":true,"color":"#FFA015"}','mandatory':true,'all':true},
    {'key':'appearance.subheading_3','category':'الخطوط والألوان','ar':'تنسيق خط العنوان الفرعي الثالث ونوعه','en':'Third subheading font style','value':'{"font":"Tajawal","size":10,"bold":false,"color":"#FF27C3"}','mandatory':true,'all':true},
    {'key':'appearance.body_text','category':'الخطوط والألوان','ar':'تنسيق خط النصوص والعناوين الصغيرة ونوعه','en':'Body text and small labels font style','value':'{"font":"Tajawal","size":10,"bold":false,"color":"#3E007D"}','mandatory':true,'all':true},
  ];
  final db = Supabase.instance.client;
  final values = <String,Map<String,dynamic>>{};
  final Map<String, String> _policyCodes = {};
  final users = <Map<String,dynamic>>[];
  final List<String> _registeredFonts = <String>['Tajawal'];
  final Map<String, TextEditingController> _appearanceColorControllers = {};
  final Map<String, TextEditingController> _appearanceSizeControllers = {};
  final TextEditingController _programNameController = TextEditingController(text: 'سلسلة');
  String? _programLogoBase64;
  String? _programLogoMime;
  final GlobalKey<ErpCodePolicyPanelState> _codePolicyKey = GlobalKey<ErpCodePolicyPanelState>();
  final ScrollController _policyHorizontalController = ScrollController();
  final ScrollController _policyVerticalController = ScrollController();
  int tab = 0; bool loading = true, saving = false; String? error, message;
  String get company => (widget.companyId ?? '').trim();
  // The displayed identifier is always read from erp_program_policies.policy_code.
  String _programPolicyCode(String key) => _policyCodes[key] ?? '';
  @override void initState(){super.initState(); final policyKeys = defaults.map((p) => p['key']).toSet(); if (policyKeys.length != defaults.length) { throw StateError('يوجد كود داخلي مكرر في سجل سياسات البرنامج.'); } for(final p in defaults){values[p['key'] as String]={...p,'enabled':p['mandatory']==true || p['enabled_default']==true || p['key']=='skip_quotation' || p['key']=='national_id_required','all':p['mandatory']==true || p['all']==true,'user_ids':<String>[]};} _load();}
  @override void didUpdateWidget(covariant ErpProgramPoliciesScreen oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.companyId!=widget.companyId)_load();}
  Future<void> _load({bool propagateError = false}) async {
    if(company.isEmpty){setState(() { loading=false; error='اختر الشركة وسجّل الدخول أولاً.'; }); if(propagateError) throw StateError(error!); return;}
    setState(() { loading=true; error=null; message=null; });
    try {
      var rows=await db.from('erp_program_policies').select().eq('company_id',company);      if ((rows as List).isEmpty) {        final initial=defaults.map((p)=><String,dynamic>{'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],'is_enabled':p['mandatory']==true || p['enabled_default']==true || p['key']=='skip_quotation' || p['key']=='national_id_required','apply_to_all':p['mandatory']==true || p['all']==true,'user_ids':<String>[],'policy_value':p['value']??''}).toList();        await db.from('erp_program_policies').upsert(initial,onConflict:'company_id,policy_key');
        rows=await db.from('erp_program_policies').select().eq('company_id',company);
      }
      final existingKeys = (rows as List).whereType<Map<String,dynamic>>().map((row)=>(row['policy_key']??'').toString()).toSet();
      final missingPolicies = defaults.where((p)=>!existingKeys.contains(p['key'])).map((p)=><String,dynamic>{
        'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],
        'is_enabled':p['mandatory']==true || p['enabled_default']==true || p['key']=='skip_quotation' || p['key']=='national_id_required',
        'apply_to_all':p['mandatory']==true || p['all']==true,'user_ids':<String>[],'policy_value':p['value']??'',
      }).toList();
      if(missingPolicies.isNotEmpty){
        await db.from('erp_program_policies').upsert(missingPolicies,onConflict:'company_id,policy_key');
        rows=await db.from('erp_program_policies').select().eq('company_id',company);
      }
      _policyCodes
        ..clear()
        ..addEntries((rows as List).whereType<Map<String,dynamic>>().map((row) => MapEntry((row['policy_key'] ?? '').toString(), (row['policy_code'] ?? '').toString())));
      // Include database policies not represented by a dedicated editor in the
      // defaults catalog (including retained legacy policies) in the All tab.
      for (final row in (rows as List).whereType<Map<String,dynamic>>()) {
        final key = (row['policy_key'] ?? '').toString();
        if (key.isEmpty || values.containsKey(key)) continue;
        values[key] = {
          'key': key,
          'category': (row['category'] ?? 'أخرى').toString(),
          'ar': (row['name_ar'] ?? key).toString(),
          'en': (row['name_en'] ?? key).toString(),
          'value': (row['policy_value'] ?? '').toString(),
          'enabled': row['is_enabled'] == true,
          'all': row['apply_to_all'] == true,
          'user_ids': List<String>.from((row['user_ids'] as List?) ?? const []),
          'mandatory': false,
        };
      }
      for(final row in (rows as List).whereType<Map<String,dynamic>>()) { final key=(row['policy_key']??'').toString(); if(!values.containsKey(key))continue; final p=values[key]!; p['enabled']=row['is_enabled']==true; p['all']=row['apply_to_all']==true || p['mandatory']==true; p['value']=(row['policy_value']??p['value']??'').toString(); p['user_ids']=List<String>.from((row['user_ids'] as List?)??const []); }
      // Upgrade the earlier descriptive text to the persisted, editable dimensions object.
      final layoutPolicy = values['ui_layout_standard'];
      if (layoutPolicy != null) {
        var validLayout = false;
        try {
          final parsed = jsonDecode((layoutPolicy['value'] ?? '').toString());
          validLayout = parsed is Map && parsed['row_height'] != null && parsed['field_height'] != null && parsed['column_spacing'] != null;
        } catch (_) {}
        if (!validLayout) {
          layoutPolicy['value'] = jsonEncode({'row_height': 50, 'field_height': 40, 'column_spacing': 3});
          layoutPolicy['enabled'] = true;
          layoutPolicy['all'] = true;
          await db.from('erp_program_policies').upsert({
            'company_id': company,
            'policy_key': 'ui_layout_standard',
            'category': 'برمجية',
            'name_ar': layoutPolicy['ar'],
            'name_en': layoutPolicy['en'],
            'is_enabled': true,
            'apply_to_all': true,
            'user_ids': <String>[],
            'policy_value': layoutPolicy['value'],
            'policy_code': _policyCodes['ui_layout_standard'],
          }, onConflict: 'company_id,policy_key');
        }
      }
      final programSettings = await db.from('erp_program_settings').select().eq('company_id', company).maybeSingle();
      _programNameController.text = (programSettings?['program_name'] ?? 'سلسلة').toString();
      _programLogoBase64 = programSettings?['logo_base64']?.toString();
      _programLogoMime = programSettings?['logo_mime_type']?.toString();
      if (values.containsKey('visual_identity.program_name')) values['visual_identity.program_name']!['value'] = _programNameController.text;
      if (values.containsKey('visual_identity.logo')) values['visual_identity.logo']!['value'] = _programLogoBase64 == null ? '' : 'تم تحديد الشعار';
      final fontSettings = programSettings;
      final discoveredFonts = <String>{'Tajawal'};
      final savedStyles = fontSettings?['heading_styles'];
      if (savedStyles is List) {
        for (final style in savedStyles.whereType<Map>()) {
          final family = (style['font'] ?? '').toString().trim();
          if (family.isNotEmpty) discoveredFonts.add(family);
        }
      }
      final us=await db.from('erp_users').select('id,user_code,name_ar').eq('company_id',company);
      if(mounted)setState(() { users..clear()..addAll((us as List).whereType<Map<String,dynamic>>().map(Map<String,dynamic>.from)); _registeredFonts..clear()..addAll(discoveredFonts.toList()..sort()); loading=false; });
    } catch(e){if(mounted)setState(() { loading=false; error='تعذر تحميل السياسات. طبّق migration سياسات البرنامج أولاً. $e'; }); if(propagateError) rethrow;}
  }
  Future<void> _pickProgramLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر قراءة صورة الشعار.');
      if (bytes.length > 1024 * 1024) throw ArgumentError('حجم الشعار يجب ألا يتجاوز 1 ميجابايت.');
      final ext = (file.extension ?? '').toLowerCase();
      final mime = {'png':'image/png','jpg':'image/jpeg','jpeg':'image/jpeg','webp':'image/webp'}[ext];
      if (mime == null) throw ArgumentError('الصيغ المدعومة للشعار PNG وJPG وWEBP.');
      setState(() {
        _programLogoBase64 = base64Encode(bytes);
        _programLogoMime = mime;
        if (values.containsKey('visual_identity.logo')) values['visual_identity.logo']!['value'] = 'تم تحديد الشعار';
        message = 'تم اختيار الشعار. اضغط حفظ لتثبيته.';
        error = null;
      });
    } catch (e) {      if (mounted) setState(() => error = 'تعذر اختيار الشعار: $e');
    }  }
  Future<void> _save() async {
    if (_programNameController.text.trim().isEmpty) {
      setState(() { error = 'اسم المشروع مطلوب.'; });
      throw StateError(error!);
    }
    if (values.containsKey('visual_identity.program_name')) {
      values['visual_identity.program_name']!['value'] = _programNameController.text.trim();
    }
    if (values.containsKey('visual_identity.logo')) {
      values['visual_identity.logo']!['value'] = _programLogoBase64 == null ? '' : 'تم تحديد الشعار';
    }
    for (final key in ['trader_market.sell_duration_hours','trader_market.buy_duration_hours','trader_market.transfer_duration_hours']) {
      final value = int.tryParse((values[key]?['value'] ?? '24').toString());
      if (value == null || value < 1 || value > 720) {
        setState(() { error = 'مدة طلبات سوق التجار يجب أن تكون من ساعة إلى 720 ساعة.'; });
        throw StateError(error!);
      }
    }
    final storyValue = int.tryParse((values['trader_market.story_duration']?['value'] ?? '60').toString());
    final storyUnit = (values['trader_market.story_duration_unit']?['value'] ?? 'دقيقة').toString();
    if (storyValue == null || storyValue < 1 || storyValue > (storyUnit == 'ساعة' ? 24 : 1440)) {
      setState(() { error = 'مدة القصة يجب أن تكون من 1 إلى 1440 دقيقة أو 24 ساعة.'; });
      throw StateError(error!);
    }
    for (final key in ['appearance.header_background', 'appearance.screen_background']) {
      final color = (values[key]?['value'] ?? '').toString().trim();
      if (!RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(color)) {
        setState(() { error = 'أدخل كود لون صحيح بصيغة HEX مثل #3E007D.'; });
        throw StateError(error!);
      }
    }
    for (final key in _appearancePolicyKeys.where((key) => key != 'appearance.language' && key != 'appearance.header_background' && key != 'appearance.screen_background')) {
      final style = _fontStyle(values[key]!);
      final size = double.tryParse((style['size'] ?? '').toString());
      final color = (style['color'] ?? '').toString().trim();
      if (size == null || size < 8 || size > 72 || !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(color) || !_registeredFonts.contains((style['font'] ?? '').toString())) {
        setState(() { error = 'راجع نوع الخط ودرجته وكود اللون في سياسات الخطوط والألوان.'; });
        throw StateError(error!);
      }
    }
    final customerCode = _customerCodeConfig(values['customer_code']!);
    if (customerCode['prefix'] != 'Cus' || customerCode['geo_digits'] != 8 || customerCode['serial_digits'] != 2 || customerCode['required'] != true || customerCode['apply_to_all'] != true) {
      throw StateError('سياسة كود العميل ثابتة على Cus + 8 أرقام جغرافية + رقمين للتسلسل، ومفعّلة وإلزامية على الكل.');
    }
    const expectedCodePolicies = <String, Map<String, dynamic>>{
      'category_code.main': {'prefix':'Cat','digits':2,'parent_digits':0},
      'category_code.sub': {'prefix':'Cat','digits':2,'parent_digits':2},
      'category_code.secondary': {'prefix':'Cat','digits':2,'parent_digits':4},
      'brand_code': {'prefix':'Bra','digits':3,'parent_digits':0},
    };
    for (final entry in expectedCodePolicies.entries) {
      final config = _geoCodeConfig(values[entry.key]!);
      if (config['prefix'] != entry.value['prefix'] || config['digits'] != entry.value['digits'] || config['parent_digits'] != entry.value['parent_digits']) {
        throw StateError('صيغة السياسة ${values[entry.key]!['ar']} ثابتة حسب تقسيم الأكواد المعتمد.');
      }
    }
    final itemCode = _itemCodeConfig(values['item_code']!);
    if (itemCode['prefix'] != 'Itm' || itemCode['category_digits'] != 6 || itemCode['serial_digits'] != 3) {
      throw StateError('سياسة كود الصنف ثابتة على Itm + 6 أرقام للفئة الثانوية + 3 أرقام للتسلسل.');
    }
    setState(() { saving=true; error=null; message=null; });
    try { final rows=values.values.map((p)=><String,dynamic>{'company_id':company,'policy_key':p['key'],'category':p['category'],'name_ar':p['ar'],'name_en':p['en'],'is_enabled':p['mandatory']==true?true:p['enabled']==true,'apply_to_all':p['mandatory']==true||p['all']==true,'user_ids':p['mandatory']==true||p['all']==true?[]:p['user_ids'],'policy_value':p['value']??'','policy_code':_policyCodes[p['key']] }).toList(); await db.from('erp_program_policies').upsert(rows,onConflict:'company_id,policy_key');
      final settings = await db.from('erp_program_settings').select().eq('company_id',company).maybeSingle();
      await db.from('erp_program_settings').upsert({...?settings,'company_id':company,'program_name':_programNameController.text.trim().isEmpty?'سلسلة':_programNameController.text.trim(),'logo_base64':_programLogoBase64,'logo_mime_type':_programLogoMime,'updated_at':DateTime.now().toUtc().toIso8601String(),'updated_by':db.auth.currentUser?.id},onConflict:'company_id');
      if(mounted)setState(() { saving=false; message='تم حفظ سياسات البرنامج.'; }); } catch(e){if(mounted)setState(() { saving=false; error='تعذر حفظ السياسات: $e'; }); rethrow;}
  }
  Future<void> _refreshCurrentTab() async {
    if (tab == 1) {
      final panel = _codePolicyKey.currentState;
      if (panel == null) throw StateError('شاشة التكويد غير جاهزة للتحديث.');
      await panel.reloadFromHeader();
    } else {
      await _load(propagateError: true);
    }
  }

  Future<void> _saveCurrentTab() async {
    if (tab == 1) {
      final panel = _codePolicyKey.currentState;
      if (panel == null) throw StateError('شاشة التكويد غير جاهزة للحفظ.');
      await panel.saveFromHeader();
    } else {
      await _save();
    }
  }

  void _editCurrentTab() {
    {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حقول السياسات في هذا التبويب قابلة للتعديل مباشرة.'),
      ));
    }
  }

  Map<String, dynamic> _geoCodeConfig(Map<String, dynamic> policy) {
    try {      final parsed = jsonDecode((policy['value'] ?? '{}').toString());
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}    final key = (policy['key'] ?? '').toString();
    const defaults = <String, Map<String, dynamic>>{
      'geo_code.country': {'prefix':'Con','digits':2,'parent_digits':0},      'geo_code.governorate': {'prefix':'Gov','digits':2,'parent_digits':2},
      'geo_code.district': {'prefix':'Dis','digits':2,'parent_digits':4},
      'geo_code.area': {'prefix':'Rig','digits':2,'parent_digits':6},
      'category_code.main': {'prefix':'Cat','digits':2,'parent_digits':0},
      'category_code.sub': {'prefix':'Cat','digits':2,'parent_digits':2},
      'category_code.secondary': {'prefix':'Cat','digits':2,'parent_digits':4},
      'brand_code': {'prefix':'Bra','digits':3,'parent_digits':0},
    };
    return Map<String, dynamic>.from(defaults[key] ?? defaults['geo_code.country']!);
  }

  Map<String, dynamic> _customerCodeConfig(Map<String, dynamic> policy) {
    try {
      final parsed = jsonDecode((policy['value'] ?? '{}').toString());
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
    return {'prefix':'Cus','geo_digits':8,'serial_digits':2,'required':true,'apply_to_all':true};
  }

  Widget _customerCodeEditor(Map<String, dynamic> policy) {
    return const SizedBox(width:300,height:40,child:Row(children:[
      SizedBox(width:66,height:40,child:Center(child:Text('Cus',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)))),
      SizedBox(width:4),
      SizedBox(width:48,height:40,child:Center(child:Text('8',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)))),
      SizedBox(width:4),
      SizedBox(width:48,height:40,child:Center(child:Text('2',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)))),
      SizedBox(width:5),
      Expanded(child:Text('Cus0000000001  •  إلزامي على الكل',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Color(0xFF3E007D)))),
    ]));
  }

  Map<String, dynamic> _itemCodeConfig(Map<String, dynamic> policy) {
    try {
      final parsed = jsonDecode((policy['value'] ?? '{}').toString());
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
    return {'prefix':'Itm','category_digits':6,'serial_digits':3};
  }

  Widget _itemCodeEditor(Map<String, dynamic> policy) {
    final config = _itemCodeConfig(policy);
    final prefix = (config['prefix'] ?? 'Itm').toString();
    final serialDigits = int.tryParse((config['serial_digits'] ?? 3).toString()) ?? 3;
    return SizedBox(width:300,height:40,child:Row(children:[
      SizedBox(width:66,height:40,child:TextFormField(
        key:ValueKey('item-code-prefix-$prefix'),initialValue:prefix,readOnly:true,textAlign:TextAlign.center,maxLength:3,
        decoration:const InputDecoration(counterText:'',isDense:true,constraints:BoxConstraints(minHeight:40,maxHeight:40),contentPadding:EdgeInsets.symmetric(horizontal:3,vertical:4),border:OutlineInputBorder()),
        style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700),
      )),
      const SizedBox(width:4),
      const SizedBox(width:48,height:40,child:Center(child:Text('6',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)))),
      const SizedBox(width:4),
      SizedBox(width:48,height:40,child:TextFormField(
        key:ValueKey('item-code-serial-$serialDigits'),initialValue:serialDigits.toString(),readOnly:true,textAlign:TextAlign.center,maxLength:1,
        decoration:const InputDecoration(counterText:'',isDense:true,constraints:BoxConstraints(minHeight:40,maxHeight:40),contentPadding:EdgeInsets.symmetric(horizontal:3,vertical:4),border:OutlineInputBorder()),
        style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700),
      )),
      const SizedBox(width:5),
      const Expanded(child:Text('Itm010101001  •  9 أرقام',textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Color(0xFF3E007D)))),
    ]));
  }

  Widget _geoCodeEditor(Map<String, dynamic> policy) {
    final config = _geoCodeConfig(policy);
    final prefix = (config['prefix'] ?? '').toString();
    final digits = int.tryParse((config['digits'] ?? 2).toString()) ?? 2;
    final parentDigits = int.tryParse((config['parent_digits'] ?? 0).toString()) ?? 0;
    final key = (policy['key'] ?? '').toString();
    final previewDigits = key == 'brand_code'
        ? '001'
        : key.startsWith('category_code.')
            ? List.filled((parentDigits ~/ 2) + 1, '01').join()
            : List.filled(parentDigits + digits, '0').join();
    void update(String key, dynamic value) {
      final next = _geoCodeConfig(policy)..[key] = value;
      policy['value'] = jsonEncode(next);
      setState(() {});
    }
    return SizedBox(width:300,height:40,child:Row(children:[
      SizedBox(width:66,height:40,child:TextFormField(
        key:ValueKey('geo-prefix-${policy['key']}-$prefix'),initialValue:prefix,
        readOnly:key.startsWith('category_code.') || key == 'brand_code',
        textAlign:TextAlign.center,maxLength:3,
        inputFormatters:[FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))],
        style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700),
        decoration:const InputDecoration(counterText:'',isDense:true,constraints:BoxConstraints(minHeight:40,maxHeight:40),contentPadding:EdgeInsets.symmetric(horizontal:3,vertical:4),border:OutlineInputBorder()),
        onChanged:(v)=>update('prefix',v.toUpperCase()),
      )),
      const SizedBox(width:4),
      SizedBox(width:48,height:40,child:TextFormField(
        key:ValueKey('geo-digits-${policy['key']}-$digits'),initialValue:digits.toString(),
        readOnly:key.startsWith('category_code.') || key == 'brand_code',
        textAlign:TextAlign.center,maxLength:2,keyboardType:TextInputType.number,
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],        style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700),
        decoration:const InputDecoration(counterText:'',isDense:true,constraints:BoxConstraints(minHeight:40,maxHeight:40),contentPadding:EdgeInsets.symmetric(horizontal:3,vertical:4),border:OutlineInputBorder()),
        onChanged:(v){final n=int.tryParse(v);if(n!=null&&n>=1&&n<=2)update('digits',n);},
      )),      const SizedBox(width:5),
      Expanded(child:Text('$prefix$previewDigits',textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Color(0xFF3E007D)))),
    ]));
  }
  Future<void> _previewCurrentTab() async {
    final current = values.values.where((p) => tabs[tab] == 'الكل' || p['category'] == tabs[tab]).toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('معاينة ${tabs[tab]}'),
        content: SizedBox(
          width: 520,
          child: current.isEmpty
              ? const Text('المعاينة التفصيلية متاحة من محتوى التبويب الحالي.')
              : ListView(
                  shrinkWrap: true,
                  children: current.map((p) => ListTile(
                    dense: true,
                    title: Text((p['ar'] ?? '').toString()),
                    subtitle: Text('القيمة: ${(p['value'] ?? '—').toString()}'),
                    trailing: Icon(p['enabled'] == true ? Icons.check_circle : Icons.remove_circle_outline,
                      color: p['enabled'] == true ? Colors.green : Colors.grey),
                  )).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<List<List<String>>> _currentExportRows() async {
    final rows = <List<String>>[];
    if (tab == 1) {
      final record = await db.from('erp_program_policies')
          .select('policy_value')
          .eq('company_id', company)
          .eq('policy_key', 'code_generation_registry')
          .maybeSingle();
      if (record == null) throw StateError('لا توجد إعدادات تكويد محفوظة لتصديرها.');
      final payload = jsonDecode((record['policy_value'] ?? '{}').toString()) as Map<String, dynamic>;
      rows.add(['نوع التكويد', 'البادئة', 'عدد الخانات', 'تلقائي', 'مركب']);
      final types = Map<String, dynamic>.from(payload['types'] as Map? ?? {});
      for (final entry in types.entries) {
        final config = Map<String, dynamic>.from(entry.value as Map? ?? {});
        rows.add([entry.key, (config['prefix'] ?? '').toString(), (config['digits'] ?? '').toString(),
          config['automatic'] == true ? 'نعم' : 'لا', config['composite'] == true ? 'نعم' : 'لا']);
      }
      rows.add(['الأصناف', (payload['item_prefix'] ?? 'Itm').toString(), '10', payload['item_automatic'] == true ? 'نعم' : 'لا', payload['item_composite'] == true ? 'نعم' : 'لا']);
      rows.add(['التقسيم الجغرافي', (payload['geo_prefix'] ?? 'Rig').toString(), 'حسب مستويات التقسيم', 'نعم', 'نعم']);
    } else {
      rows.add(['م', 'كود السياسة', 'اسم السياسة', 'القيمة', 'مفعلة', 'على الكل', 'عدد المستخدمين']);
      final current = values.values.where((p) => tabs[tab] == 'الكل' || p['category'] == tabs[tab]).toList();
      for (var i = 0; i < current.length; i++) {
        final p = current[i];
        final key = (p['key'] ?? '').toString();
        final value = key == 'visual_identity.program_name'
            ? _programNameController.text
            : key == 'visual_identity.logo'
                ? (_programLogoBase64 == null ? 'غير محدد' : 'تم تحديد شعار')
                : key == 'code_generation_registry'
                    ? 'إعدادات التكويد المركزي'
                    : key.startsWith('geo_code.')
                        ? (() { final c = _geoCodeConfig(p); return '${c['prefix']}${List.filled((int.tryParse((c['parent_digits'] ?? 0).toString()) ?? 0) + (int.tryParse((c['digits'] ?? 2).toString()) ?? 2), '0').join()}'; })()
                        : (p['value'] ?? '').toString();
        rows.add([(i + 1).toString(), _programPolicyCode(key), (p['ar'] ?? '').toString(),
          value, p['enabled'] == true ? 'نعم' : 'لا', p['all'] == true ? 'نعم' : 'لا',
          ((p['user_ids'] as List?)?.length ?? 0).toString()]);
      }
    }
    if (rows.length <= 1) throw StateError('لا توجد بيانات في التبويب الحالي للتصدير.');
    return rows;
  }

  Future<void> _exportCurrentExcel() async {
    try {
      final rows = await _currentExportRows();
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['سياسات البرنامج'];
      for (final row in rows) {
        sheet.appendRow(row.map<excel.CellValue?>((value) => excel.TextCellValue(value)).toList());
      }
      final bytes = workbook.encode();
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'Silsila_Program_Policies',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير ملف Excel بنجاح.'), backgroundColor: Color(0xFF18865A)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تصدير Excel: $e'), backgroundColor: const Color(0xFFB42318)));
      rethrow;
    }
  }
  Future<Uint8List> _buildCurrentPdf() async {
    final rows = await _currentExportRows();
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final pdf = pw.Document();    pdf.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
        pw.Text('Silsila • ${tabs[tab]}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),        pw.TableHelper.fromTextArray(headers: rows.first, data: rows.skip(1).toList()),
      ],
    ));
    return Uint8List.fromList(await pdf.save());
  }

  Future<void> _printCurrentPolicies() async {
    try {
      final bytes = await _buildCurrentPdf();
      final printed = await Printing.layoutPdf(onLayout: (_) async => bytes);
      if (printed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال المستند إلى الطباعة.'), backgroundColor: Color(0xFF18865A)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذرت الطباعة: $e'), backgroundColor: const Color(0xFFB42318)));
      rethrow;
    }
  }

  Future<void> _exportCurrentPdf() async {
    try {
      final bytes = await _buildCurrentPdf();
      await FileSaver.instance.saveFile(
        name: 'Silsila_Program_Policies',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير PDF بنجاح.'), backgroundColor: Color(0xFF18865A)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تصدير PDF: $e'), backgroundColor: const Color(0xFFB42318)));
      rethrow;
    }
  }

  Future<void> _pickUsers(Map<String,dynamic> p) async {
    final chosen=<String>{...List<String>.from(p['user_ids'] as List)};
    final result=await showDialog<Set<String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(title:const Text('تحديد المستخدمين — F1'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>ds(() { if(chosen.length==users.length){chosen.clear();}else{chosen.addAll(users.map((u)=>(u['id']??'').toString()));} }),child:const Text('تحديد الكل / إلغاء تحديد الكل'))),Flexible(child:ListView(shrinkWrap:true,children:users.map((u){final id=(u['id']??'').toString();final name=(u['name_ar']??u['user_code']??id).toString();return CheckboxListTile(dense:true,value:chosen.contains(id),title:Text(name),onChanged:(v)=>ds(() { if(v==true){chosen.add(id);}else{chosen.remove(id);} }));}).toList()))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,chosen),child:const Text('حفظ'))])));
    if(result!=null&&mounted)setState(() { p['user_ids']=result.toList(); p['all']=false; });
  }

  static const List<String> _appearancePolicyKeys = [
    'appearance.language',
    'appearance.header_background',
    'appearance.screen_background',
    'appearance.header_text',
    'appearance.main_heading',
    'appearance.subheading_1',
    'appearance.subheading_2',
    'appearance.subheading_3',
    'appearance.body_text',
  ];

  Map<String, dynamic> _fontStyle(Map<String, dynamic> policy) {
    try {
      final parsed = jsonDecode((policy['value'] ?? '{}').toString());
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
    return {'font': 'Tajawal', 'size': 10, 'bold': false, 'color': '#3E007D'};
  }

  Color _appearanceColor(String value) {
    final hex = value.trim().replaceFirst('#', '');
    try {
      return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      return const Color(0xFFBDBDBD);
    }
  }

  Future<void> _chooseAppearanceColor(Map<String, dynamic> policy, {bool fontStyle = false}) async {
    const swatches = <Color>[
      Color(0xFF3E007D), Color(0xFF5E35B1), Color(0xFF7E57C2), Color(0xFF9575CD),
      Color(0xFFFFA015), Color(0xFFFF8F00), Color(0xFFFF5722), Color(0xFFE53935),
      Color(0xFFFF27C3), Color(0xFFD81B60), Color(0xFF8E24AA), Color(0xFF3949AB),
      Color(0xFF039BE5), Color(0xFF00897B), Color(0xFF43A047), Color(0xFF795548),
      Color(0xFF333333), Color(0xFF666666), Color(0xFF999999), Color(0xFFCCCCCC),
      Color(0xFFF5EFFB), Color(0xFFFFFFFF),
    ];
    final current = fontStyle ? (_fontStyle(policy)['color'] ?? '#3E007D').toString() : (policy['value'] ?? '#FFFFFF').toString();
    final selected = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختيار اللون'),
        content: SizedBox(width: 300, child: Wrap(
          spacing: 8, runSpacing: 8,
          children: swatches.map((color) => InkWell(
            onTap: () => Navigator.pop(ctx, color),
            child: Container(
              width: 30, height: 30,              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
              child: _appearanceColor(current).toARGB32() == color.toARGB32()
                  ? Icon(Icons.check, size: 16, color: color.computeLuminance() < .45 ? Colors.white : Colors.black87)
                  : null,
            ),
          )).toList(),        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء'))],
      ),
    );
    if (selected == null || !mounted) return;
    final hex = '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}';    setState(() {
      if (fontStyle) {
        final style = _fontStyle(policy)..['color'] = hex;
        policy['value'] = jsonEncode(style);
      } else {
        policy['value'] = hex;
      }
    });
  }

  TextEditingController _appearanceSizeController(Map<String, dynamic> policy) {
    final key = (policy['key'] ?? '').toString();
    final value = (_fontStyle(policy)['size'] ?? 10).toString();
    final controller = _appearanceSizeControllers.putIfAbsent(key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    }
    return controller;
  }

  TextEditingController _appearanceColorController(Map<String, dynamic> policy, {bool fontStyle = false}) {
    final key = (policy['key'] ?? '').toString();
    final value = fontStyle ? (_fontStyle(policy)['color'] ?? '#3E007D').toString() : (policy['value'] ?? '#FFFFFF').toString();
    final controller = _appearanceColorControllers.putIfAbsent(key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    }
    return controller;
  }

  Widget _appearanceColorEditor(Map<String, dynamic> policy, {bool fontStyle = false, double width = 150}) {
    final style = fontStyle ? _fontStyle(policy) : <String, dynamic>{};
    final value = (fontStyle ? style['color'] : policy['value'] ?? '#FFFFFF').toString();
    return SizedBox(width: width, height: 40, child: Row(children: [
      SizedBox(width: width - 66, height: 40, child: TextField(
        controller: _appearanceColorController(policy, fontStyle: fontStyle),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 9),
        decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4), border: OutlineInputBorder()),
        onChanged: (v) => setState(() {
          if (fontStyle) {
            final next = _fontStyle(policy)..['color'] = v;
            policy['value'] = jsonEncode(next);
          } else {
            policy['value'] = v;
          }
        }),
      )),
      const SizedBox(width: 3),
      SizedBox(width: 22, height: 40, child: IconButton(
        padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, tooltip: 'لوحة الألوان',
        onPressed: () => _chooseAppearanceColor(policy, fontStyle: fontStyle),
        icon: const Icon(Icons.palette_outlined, size: 17),
      )),
      const SizedBox(width: 3),
      Container(width: 4, height: 4, decoration: BoxDecoration(
        color: _appearanceColor(value), shape: BoxShape.circle, border: Border.all(color: Colors.black26),
      )),
    ]));
  }

  Widget _appearanceFontStyleEditor(Map<String, dynamic> policy) {
    final style = _fontStyle(policy);
    final font = (style['font'] ?? 'Tajawal').toString();
    final bold = style['bold'] == true;
    return SizedBox(height: 40, child: Row(children: [
      SizedBox(width: 106, height: 40, child: DropdownButtonFormField<String>(
        value: _registeredFonts.contains(font) ? font : (_registeredFonts.isEmpty ? null : _registeredFonts.first),
        isExpanded: true, isDense: true, itemHeight: 48, menuMaxHeight: 240,
        decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 4), border: OutlineInputBorder()),
        items: _registeredFonts.map((family) => DropdownMenuItem(value: family, child: Text(family, style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { if (v != null) setState(() { final next = _fontStyle(policy)..['font'] = v; policy['value'] = jsonEncode(next); }); },
      )),
      const SizedBox(width: 3),
      SizedBox(width: 53, height: 40, child: TextField(
        controller: _appearanceSizeController(policy), textAlign: TextAlign.center, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 9),
        decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4), border: OutlineInputBorder()),
        onChanged: (v) => setState(() { final next = _fontStyle(policy)..['size'] = v; policy['value'] = jsonEncode(next); }),
      )),
      const SizedBox(width: 2),
      SizedBox(width: 32, height: 40, child: Tooltip(message: 'سميك', child: Checkbox(
        value: bold, onChanged: (v) => setState(() { final next = _fontStyle(policy)..['bold'] = v == true; policy['value'] = jsonEncode(next); }),
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ))),
      const SizedBox(width: 3),
      _appearanceColorEditor(policy, fontStyle: true, width: 100),
    ]));  }

  Widget _buildFontsColorsGrid() {
    final rows = _appearancePolicyKeys.map((key) => values[key]).whereType<Map<String, dynamic>>().toList();
    Widget headerCell(String label, double width) => SizedBox(width: width, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)));
    Widget header = Card(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1), elevation: 0, color: const Color(0xFFF5EFFB),      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3), child: SizedBox(width: 1200, child: Row(children: [
        headerCell('م',34), const SizedBox(width:8), headerCell('كود السياسة',82), const SizedBox(width:8),
        headerCell('بيانات السياسة',225), const SizedBox(width:8), headerCell('القيمة / الاختيار',300), const SizedBox(width:4),
        headerCell('تفعيل',50), const SizedBox(width:4), headerCell('الكل',62), const SizedBox(width:4),
        headerCell('تحديد\nمستخدمين',80), const SizedBox(width:4), headerCell('عدد المحدد',58),
      ]))),
    );    return Scrollbar(controller: _policyVerticalController, thumbVisibility: true, scrollbarOrientation: ScrollbarOrientation.left,
      child: Scrollbar(controller: _policyHorizontalController, thumbVisibility: true, scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(controller: _policyHorizontalController, scrollDirection: Axis.horizontal,
          child: SizedBox(width: 1200, child: ListView(controller: _policyVerticalController, padding: const EdgeInsets.fromLTRB(5,1,5,3), children: [
            header,
            ...List.generate(rows.length, (index) {
              final p = rows[index];
              final key = (p['key'] ?? '').toString();
              Widget editor;
              if (key == 'appearance.language') {
                editor = SizedBox(width: 150, height: 40, child: DropdownButtonFormField<String>(
                  value: (p['value'] ?? 'العربية').toString(),
                  isExpanded: true, isDense: true, itemHeight: 48,
                  decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight:40,maxHeight:40), contentPadding: EdgeInsets.symmetric(horizontal:6,vertical:4), border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value:'العربية', child: Text('اللغة العربية')),
                    DropdownMenuItem(value:'الإنجليزية', child: Text('اللغة الإنجليزية')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => p['value'] = v); },
                ));
              } else if (key == 'appearance.header_background' || key == 'appearance.screen_background') {
                editor = _appearanceColorEditor(p, width: 150);
              } else {
                editor = _appearanceFontStyleEditor(p);
              }
              return Card(
                margin: const EdgeInsets.symmetric(vertical:1,horizontal:1), elevation:0,
                shape: RoundedRectangleBorder(side: BorderSide(color: Colors.deepPurple.withValues(alpha:.16)), borderRadius: BorderRadius.circular(6)),
                child: SizedBox(height:50, child: Padding(padding: const EdgeInsets.symmetric(horizontal:5,vertical:4),
                  child: SizedBox(width:1200, child: Row(children: [
                    SizedBox(width:34, child: Text('${index+1}', textAlign:TextAlign.center, style:const TextStyle(fontSize:10))),
                    const SizedBox(width:8),
                    SizedBox(width:82, child: Text(_programPolicyCode(key), textAlign:TextAlign.center, style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700))),
                    const SizedBox(width:8),
                    SizedBox(width:225, child: Text((p['ar'] ?? '').toString(), maxLines:2, overflow:TextOverflow.ellipsis, style:const TextStyle(fontSize:10,fontWeight:FontWeight.w600))),
                    const SizedBox(width:8),
                    SizedBox(width:300, child: Align(alignment:AlignmentDirectional.centerStart, child:editor)),
                    const SizedBox(width:4),
                    SizedBox(width:50, child: Center(child: Checkbox(value:true,onChanged:null,activeColor:Colors.green,fillColor:const WidgetStatePropertyAll<Color>(Colors.green),visualDensity:const VisualDensity(horizontal:-4,vertical:-4),materialTapTargetSize:MaterialTapTargetSize.shrinkWrap))),
                    const SizedBox(width:4),
                    SizedBox(width:62, child: Center(child: Checkbox(value:true,onChanged:null,activeColor:Colors.green,fillColor:const WidgetStatePropertyAll<Color>(Colors.green),visualDensity:const VisualDensity(horizontal:-4,vertical:-4),materialTapTargetSize:MaterialTapTargetSize.shrinkWrap))),
                    const SizedBox(width:4),
                    const SizedBox(width:80),
                    const SizedBox(width:4),
                    const SizedBox(width:58, child: Text('—',textAlign:TextAlign.center,style:TextStyle(fontSize:9))),
                  ])),
                )),
              );
            }),
            const Padding(padding:EdgeInsets.all(6),child:Text('الخطوط المعروضة مأخوذة من الخطوط المحفوظة في إعدادات الشركة بقاعدة البيانات. يمكن تعديل القيم ثم الضغط على حفظ.',style:TextStyle(fontSize:10,color:Color(0xFF3E007D)))),
          ])),
        ),
      ),
    );
  }

  Map<String, int> _layoutDimensions(Map<String, dynamic> policy) {
    try {
      final decoded = jsonDecode((policy['value'] ?? '').toString());
      if (decoded is Map) {
        return {
          'row_height': int.tryParse((decoded['row_height'] ?? 50).toString()) ?? 50,
          'field_height': int.tryParse((decoded['field_height'] ?? 40).toString()) ?? 40,
          'column_spacing': int.tryParse((decoded['column_spacing'] ?? 3).toString()) ?? 3,
        };
      }
    } catch (_) {}
    return {'row_height': 50, 'field_height': 40, 'column_spacing': 3};
  }

  void _updateLayoutDimension(Map<String, dynamic> policy, String key, int value) {
    final dimensions = _layoutDimensions(policy);
    dimensions[key] = value;
    policy['value'] = jsonEncode(dimensions);
    setState(() {});
  }

  Widget _layoutDimensionSelector(Map<String, dynamic> policy) {
    final dimensions = _layoutDimensions(policy);
    Widget selector(String label, String key, List<int> options) => SizedBox(
      width: 140,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        DropdownButtonFormField<int>(
          value: options.contains(dimensions[key]) ? dimensions[key] : options.first,          isExpanded: true, isDense: true, itemHeight: 48,
          decoration: const InputDecoration(
            isDense: true,
            constraints: BoxConstraints(minHeight: 40, maxHeight: 40),
            contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 10, color: Colors.black87),          items: options.map((v) => DropdownMenuItem<int>(value: v, child: Text('$v بكسل', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) _updateLayoutDimension(policy, key, v); },
        ),
      ]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,      children: [
        selector('ارتفاع الصفوف', 'row_height', [30, 35, 40, 45, 50, 55, 60, 70, 80, 100]),
        const SizedBox(height: 3),
        selector('ارتفاع الخانات', 'field_height', [20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 100]),
        const SizedBox(height: 3),
        selector('المسافة بين الأعمدة', 'column_spacing', [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20]),
      ],
    );
  }

  String policySearch = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _policyHorizontalController.dispose();
    _policyVerticalController.dispose();
    _programNameController.dispose();
    for (final controller in _appearanceColorControllers.values) { controller.dispose(); }
    for (final controller in _appearanceSizeControllers.values) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = policySearch.trim().toLowerCase();
    final list = values.values.where((p) {
      if (tab == 1 && p['key'] == 'code_generation_registry') return false;
      if (tabs[tab] != 'الكل' && p['category'] != tabs[tab]) return false;
      if (query.isEmpty) return true;
      final ar = (p['ar'] ?? '').toString().toLowerCase();
      final en = (p['en'] ?? '').toString().toLowerCase();
      final key = (p['key'] ?? '').toString().toLowerCase();
      return ar.contains(query) || en.contains(query) || key.contains(query);
    }).toList();
    if (tabs[tab] == 'الكل') {
      list.sort((a, b) => _programPolicyCode((a['key'] ?? '').toString())
          .compareTo(_programPolicyCode((b['key'] ?? '').toString())));
    }

    return Column(children: [
      Container(
        color: const Color(0xFF3E007D),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.policy_outlined, color: Color(0xFFFFA015), size: 23),
            const SizedBox(width: 6),
            const Expanded(child: Text('سياسات البرنامج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
            SizedBox(width: 190, height: 40, child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 11),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => policySearch = v),
              decoration: InputDecoration(
                hintText: 'ابحث باسم السياسة...',
                hintStyle: const TextStyle(fontSize: 10),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                isDense: true,
              ),
            )),
            const SizedBox(width: 3),
            SizedBox(height: 40, child: FilledButton.tonalIcon(
              onPressed: () => setState(() => policySearch = _searchController.text),
              icon: const Icon(Icons.search, size: 15),
              label: const Text('بحث', style: TextStyle(fontSize: 11)),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
            )),
          ]),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            ErpQuickTaskButton(label: 'تحديث', icon: Icons.refresh_rounded, compact: true, onPressed: loading ? null : _refreshCurrentTab),
            ErpQuickTaskButton(label: 'إضافة', icon: Icons.add_circle_outline_rounded, compact: true, onPressed: null),
            ErpQuickTaskButton(label: 'حفظ', icon: Icons.save_outlined, compact: true, onPressed: saving || (tab == 1 && (_codePolicyKey.currentState?.isSaving ?? false)) ? null : _saveCurrentTab),
            ErpQuickTaskButton(label: 'تعديل', icon: Icons.edit_outlined, compact: true, onPressed: loading ? null : _editCurrentTab),
            ErpQuickTaskButton(label: 'حذف', icon: Icons.delete_outline_rounded, compact: true, onPressed: null),
            ErpQuickTaskButton(label: 'معاينة', icon: Icons.preview_outlined, compact: true, onPressed: _previewCurrentTab),
            ErpQuickTaskButton(label: 'طباعة', icon: Icons.print_outlined, compact: true, onPressed: _printCurrentPolicies),
            ErpQuickTaskButton(label: 'Excel', icon: Icons.table_view_outlined, compact: true, onPressed: _exportCurrentExcel),
            ErpQuickTaskButton(label: 'PDF', icon: Icons.picture_as_pdf_outlined, compact: true, onPressed: _exportCurrentPdf),
          ])),
        ]),
      ),      if (error != null) Padding(padding: const EdgeInsets.all(4), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 11))),
      if (message != null) Padding(padding: const EdgeInsets.all(4), child: Text(message!, style: const TextStyle(color: Colors.green, fontSize: 11))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(tabs.length, (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: ChoiceChip(label: Text(tabs[i]), selected: tab == i, onSelected: (_) => setState(() => tab = i), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      )))),
      Expanded(
        child: tab == 7
                ? _buildFontsColorsGrid()                    : loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(child: Text(query.isEmpty ? 'لا توجد سياسات في هذه المجموعة.' : 'لا توجد سياسات تطابق البحث.', style: const TextStyle(fontSize: 12)))
                    : Scrollbar(
                      controller: _policyVerticalController,
                      thumbVisibility: true,                      scrollbarOrientation: ScrollbarOrientation.left,
                      child: Scrollbar(
                        controller: _policyHorizontalController,
                        thumbVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _policyHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: 1200, child: ListView(
                        controller: _policyVerticalController,
                        padding: const EdgeInsets.fromLTRB(5, 1, 5, 3),
                        children: [
                          if (tab == 1) SizedBox(height: 320, child: ErpCodePolicyPanel(key: _codePolicyKey, companyId: company)),
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                            elevation: 0, color: const Color(0xFFF5EFFB),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: SizedBox(width: 1200, child: Row(children: const [
                                SizedBox(width: 34, child: Text('م', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 82, child: Text('كود السياسة', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 225, child: Text('بيانات السياسة', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                SizedBox(width: 300, child: Text('القيمة / الاختيار', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 4),
                                SizedBox(width: 50, child: Text('تفعيل', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 4),
                                SizedBox(width: 62, child: Text('الكل', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 4),
                                SizedBox(width: 80, child: Text('تحديد\nمستخدمين', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                SizedBox(width: 4),
                                SizedBox(width: 58, child: Text('عدد المحدد', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              ])),
                            ),
                          ),
                          ...List.generate(list.length, (index) {
                            final p = list[index];
                            final mandatory = p['mandatory'] == true;
                            final all = p['all'] == true;
                            final options = (p['options'] as List?)?.cast<String>() ?? const <String>[];
                            final policyCode = _programPolicyCode((p['key'] ?? '').toString());
                            Widget checkColumn(String label, bool value, ValueChanged<bool?>? onChanged, double width) => SizedBox(
                              width: width,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
                                SizedBox(height: 25, child: Checkbox(value: value, onChanged: onChanged, activeColor: onChanged == null && value ? Colors.green : null, fillColor: onChanged == null && value ? const WidgetStatePropertyAll<Color>(Colors.green) : null, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                              ]),
                            );
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.16)), borderRadius: BorderRadius.circular(6)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                child: SizedBox(width: 1200, child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  SizedBox(width: 34, child: Text((index + 1).toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 82, child: Text(policyCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 225, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p['ar'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text(p['en'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 9)),
                                    if (mandatory) const Text('إلزامي', style: TextStyle(color: Color(0xFF18865A), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ])),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 300, child: ((p['key'] as String).startsWith('geo_code.') || (p['key'] as String).startsWith('category_code.') || p['key'] == 'brand_code')
                                    ? _geoCodeEditor(p)
                                    : p['key'] == 'customer_code'
                                      ? _customerCodeEditor(p)
                                      : p['key'] == 'item_code'
                                      ? _itemCodeEditor(p)
                                      : p['key'] == 'code_generation_registry'
                                      ? const Text('إعدادات التكويد المركزي', style: TextStyle(fontSize:10,fontWeight:FontWeight.w600))
                                      : p['key'] == 'visual_identity.program_name'
                                    ? TextField(
                                        controller: _programNameController,
                                        maxLines: 1,
                                        style: const TextStyle(fontSize: 11),
                                        decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 5), border: OutlineInputBorder(), hintText: 'سلسلة'),
                                        onChanged: (v) => p['value'] = v,
                                      )                                    : p['key'] == 'visual_identity.logo'
                                    ? Row(children: [
                                        if (_programLogoBase64 != null) Container(width: 34, height: 34, margin: const EdgeInsetsDirectional.only(end: 5), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(5)), child: ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.memory(base64Decode(_programLogoBase64!), fit: BoxFit.contain))),
                                        OutlinedButton.icon(onPressed: _pickProgramLogo, icon: const Icon(Icons.upload_file, size: 15), label: const Text('اختيار الشعار', style: TextStyle(fontSize: 10)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 7), visualDensity: VisualDensity.compact)),
                                        if (_programLogoBase64 != null) IconButton(onPressed: () => setState(() { _programLogoBase64 = null; _programLogoMime = null; p['value'] = ''; }), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                      ])
                                    : p['key'] == 'ui_layout_standard'
                                    ? _layoutDimensionSelector(p)
                                    : p['key'] == 'fiscal_year'
                                    ? Row(children: [
                                        Expanded(child: TextFormField(
                                          key: ValueKey('fiscal-from-' + (p['value'] ?? '').toString()),                                          initialValue: ((p['value'] ?? '01/01 - 12/31').toString().split(' - ').first),
                                          decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) {
                                            final parts = (p['value'] ?? '01/01 - 12/31').toString().split(' - ');
                                            p['value'] = '${v.trim()} - ${parts.length > 1 ? parts[1] : '12/31'}';
                                          },
                                        )),                                        const SizedBox(width: 4),
                                        Expanded(child: TextFormField(
                                          key: ValueKey('fiscal-to-' + (p['value'] ?? '').toString()),
                                          initialValue: ((p['value'] ?? '01/01 - 12/31').toString().split(' - ').length > 1 ? (p['value'] ?? '01/01 - 12/31').toString().split(' - ')[1] : '12/31'),
                                          decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) {
                                            final parts = (p['value'] ?? '01/01 - 12/31').toString().split(' - ');
                                            p['value'] = '${parts.first} - ${v.trim()}';
                                          },
                                        )),
                                      ])
                                    : (p['key'] as String).startsWith('trader_market.') && options.isEmpty
                                      ? TextFormField(
                                          key: ValueKey('market-policy-' + (p['value'] ?? '').toString()),
                                          initialValue: p['value']?.toString() ?? '24',
                                          decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) => p['value'] = v,
                                        )
                                      : p['key'] == 'supplier_bonus_variance'
                                      ? TextFormField(
                                          key: ValueKey('variance-' + (p['value'] ?? '').toString()),
                                          initialValue: p['value']?.toString() ?? '',
                                          decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) => p['value'] = v,
                                        )
                                      : options.isNotEmpty
                                        ? DropdownButtonFormField<String>(
                                            value: options.contains(p['value']) ? p['value'] as String : options.first,
                                            isExpanded: true, isDense: true, itemHeight: 48,
                                            decoration: const InputDecoration(isDense: true, constraints: BoxConstraints(minHeight: 40, maxHeight: 40), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4), border: OutlineInputBorder()),
                                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                                            items: options.map((v) => DropdownMenuItem(value: v, child: Text(p['key']=='inventory.stocktake.valuation_basis' ? (v=='sale'?'سعر البيع':'سعر الشراء') : v, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                                            onChanged: (v) => setState(() => p['value'] = v),
                                          )
                                        : Text((p['value'] ?? '').toString().isEmpty ? '—' : (p['value'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))),
                                  const SizedBox(width: 4),
                                  checkColumn('تفعيل', mandatory || p['enabled'] == true, mandatory ? null : (v) => setState(() => p['enabled'] = v == true), 50),
                                  const SizedBox(width: 4),
                                  checkColumn('الكل', mandatory || all, mandatory ? null : (v) => setState(() { p['all'] = v == true; if (v == true) p['user_ids'] = <String>[]; }), 62),
                                  const SizedBox(width: 4),
                                  SizedBox(width: 80, height: 34, child: Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1 && !mandatory && !all) { _pickUsers(p); return KeyEventResult.handled; }
                                      return KeyEventResult.ignored;
                                    },
                                    child: OutlinedButton(
                                      onPressed: mandatory || all ? null : () => _pickUsers(p),
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      child: const Text('تحديد\nمستخدمين', textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 8, height: 1.0)),
                                    ),
                                  )),
                                  const SizedBox(width: 4),
                                  SizedBox(width: 58, child: Text(mandatory ? '—' : (p['user_ids'] as List).length.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
                                ])),
                              ),
                            );
                          }),
                          if (tab == 1) ...[
                            const SizedBox(height: 6),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                'إعدادات الأبعاد قابلة للتغيير من سياسة «المعيار الموحد لارتفاع الخانات والصفوف والمسافات بين الأعمدة»، ثم اضغط حفظ لتثبيت القيم.',
                                style: TextStyle(fontSize: 10, color: Color(0xFF3E007D), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                          )),
                        ),
                      ),
                    ),
      ),
    ]);
  }