import 'package:flutter/material.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _pink = Color(0xFFFF27C3);
const _canvas = Color(0xFFF7F5FA);

const Map<String, Map<String, List<String>>> _modules = {
  'إدارة التطبيقات': {
    'بيانات أساسية': ['إعدادات هوية التطبيق', 'إدارة الشعار والصور', 'إدارة ألوان التطبيقات', 'إدارة صلاحيات التطبيقات', 'إدارة صور الأصناف والفئات', 'إدارة صور الموردين والعملاء', 'إدارة شركات الشحن', 'إعدادات عامة للتطبيقات'],
    'حركات': ['مراجعة طلبات تعديل التطبيقات', 'سجل تغييرات الهوية', 'إدارة إصدارات التطبيقات'],
    'تقارير': ['تقرير التطبيقات', 'تقرير الصلاحيات', 'تقرير تغييرات الإعدادات'],
  },
  'إدارة البرنامج': {
    'بيانات أساسية': ['بيانات الشركة', 'الفروع ومراكز التكلفة', 'المستخدمون والصلاحيات', 'إعدادات النظام', 'سجل العمليات', 'واجهة API والربط الخارجي', 'إدارة مفاتيح API', 'سجلات التكامل والطلبات'],
    'حركات': ['إدارة الجلسات', 'سجل الدخول والخروج', 'النسخ الاحتياطي', 'إعداد نقاط الربط', 'اختبار الاتصال الخارجي'],
    'تقارير': ['تقرير المستخدمين', 'تقرير نشاط النظام', 'تقرير استهلاك API', 'تقرير أخطاء التكامل'],
  },
  'الحسابات المالية': {
    'بيانات أساسية': ['شجرة الحسابات', 'الفترات المالية', 'مراكز التكلفة', 'العملات', 'الخزائن الرئيسية والفرعية', 'الحسابات البنكية', 'طرق الدفع', 'لوحات المؤشرات', 'قوالب التقارير'],
    'حركات': ['قيود اليومية', 'سندات القبض', 'سندات الصرف', 'تسويات الحسابات', 'إقفال الفترة', 'تحويل بين الخزائن', 'إيداع بنكي', 'سحب بنكي', 'مطابقة البنك', 'تحديث مؤشرات الأداء', 'تصدير البيانات'],
    'تقارير': ['ميزان المراجعة', 'الأستاذ العام', 'قائمة الدخل', 'الميزانية العمومية', 'حركة حساب', 'أرصدة الخزائن', 'كشف حساب خزينة', 'كشف حساب بنك', 'مؤشرات الأداء الرئيسية', 'التدفقات النقدية', 'تحليل الربحية', 'حركة المبيعات والمخزون', 'ملخص تنفيذي'],
  },
  'المخازن والفروع': {
    'بيانات أساسية': ['دليل المخازن', 'مجموعات الأصناف', 'دليل الأصناف', 'الوحدات والتحويلات', 'الباركود', 'حدود إعادة الطلب', 'قواعد إعادة الطلب والتنبيه', 'دليل الفروع', 'المخازن التابعة', 'مراكز التكلفة', 'المناطق الجغرافية'],
    'حركات': ['إذن إضافة', 'إذن صرف', 'تحويل مخزني', 'تسوية جرد', 'جرد فعلي', 'محاضر الجرد ومراجعة الفروق', 'تسوية صلاحية وهالك', 'تحويلات بين الفروع', 'تسويات الفروع', 'توزيع المصروفات'],
    'تقارير': ['أرصدة الأصناف', 'كارت الصنف', 'الجرد والفروق', 'الأصناف الراكدة', 'الأصناف قاربت على النفاد', 'تنبيهات إعادة الطلب', 'تواريخ الصلاحية', 'تنبيهات قرب انتهاء الصلاحية', 'أرصدة التشغيلات', 'أداء الفروع', 'أرباح وخسائر الفروع', 'حركة التحويلات'],
  },
  'المشتريات والموردون': {
    'بيانات أساسية': ['سياسات الشراء', 'قوائم أسعار الموردين', 'دليل الموردين', 'تصنيفات الموردين', 'جهات اتصال الموردين', 'شروط التوريد'],
    'حركات': ['طلب شراء', 'أمر شراء', 'استلام مشتريات', 'فاتورة مشتريات', 'مرتجع مشتريات', 'كشف حساب مورد', 'تقييم مورد', 'مطابقة أرصدة الموردين', 'تسجيل مديونية مورد'],
    'تقارير': ['تحليل المشتريات', 'مقارنة أسعار الموردين', 'أعمار ديون الموردين', 'أرصدة الموردين', 'أداء الموردين', 'الموردون حسب النشاط'],
  },
  'المبيعات والعملاء': {
    'بيانات أساسية': ['قوائم أسعار البيع', 'سياسات الخصم', 'مناطق التوزيع', 'خطوط السير', 'دليل العملاء', 'تصنيفات العملاء', 'فروع العملاء', 'حدود الائتمان', 'مناطق العملاء', 'دليل المندوبين', 'مركبات التوزيع'],
    'حركات': ['عرض سعر', 'أمر بيع', 'فاتورة مبيعات', 'مرتجع مبيعات', 'إذن تحميل', 'تسليم طلب', 'كشف حساب عميل', 'تحصيلات العملاء', 'متابعة المديونيات', 'طلبات العملاء', 'تسليم عهدة مندوب', 'تصفية عهدة مندوب', 'تحصيل نقدي', 'مصروفات رحلة'],
    'تقارير': ['المبيعات اليومية', 'ربحية المبيعات', 'مبيعات حسب الفرع', 'أداء المندوبين', 'الطلبات المتأخرة', 'أرصدة العملاء', 'أعمار الديون', 'أفضل العملاء', 'العملاء المتوقفون', 'تصفية المندوبين', 'تحصيلات يومية', 'تكلفة خطوط السير'],
  },
  'الموارد البشرية والرواتب': {
    'بيانات أساسية': ['هيكل الشركة', 'الإدارات والأقسام', 'الوظائف والدرجات', 'ملف الموظف', 'العقود', 'أنواع الإجازات', 'مكونات الراتب', 'الاستحقاقات والاستقطاعات', 'سياسات العمولة'],
    'حركات': ['الحضور والانصراف', 'الإجازات والأذونات', 'الجزاءات والمكافآت', 'السلف', 'تقييم الأداء', 'مسير الرواتب', 'صرف الرواتب', 'عمولات المبيعات', 'تسوية سلفة'],
    'تقارير': ['كشف العاملين', 'الحضور والغياب', 'رصيد الإجازات', 'انتهاء العقود', 'ملخص الرواتب', 'مفردات المرتب', 'عمولات المندوبين'],
  },
  'علاقات العملاء CRM': {
    'بيانات أساسية': ['الحملات التسويقية', 'قواعد العروض', 'شرائح العملاء', 'أنواع الطلبات', 'قنوات التواصل', 'أسباب الشكاوى'],
    'حركات': ['إنشاء عرض', 'اعتماد حملة', 'تسجيل كوبون', 'تذكرة دعم جديدة', 'متابعة شكوى', 'تسجيل اقتراح'],
    'تقارير': ['أداء العروض', 'تكلفة الحملات', 'معدل الاستجابة', 'التذاكر المفتوحة', 'زمن الاستجابة', 'رضا العملاء'],
  },
};

class ErpDashboardScreen extends StatefulWidget {
  const ErpDashboardScreen({super.key});
  @override
  State<ErpDashboardScreen> createState() => _ErpDashboardScreenState();
}

class _ErpDashboardScreenState extends State<ErpDashboardScreen> {
  String _module = 'إدارة البرنامج';
  String _appName = 'سلسلة';
  Color _appPrimary = const Color(0xFF3E007D);
  Color _appAccent = const Color(0xFFFFA015);
  bool _allowImageManagement = true;
  bool _allowThemeManagement = true;
  bool _allowPermissionManagement = true;
  final List<String> _activityLog = ['تم فتح لوحة ERP', 'تم تجهيز أقسام المخازن والفروع', 'تمت إضافة نماذج إدارة المستندات'];
  String _group = 'بيانات أساسية';
  String _page = 'بيانات الشركة';
  String _search = '';
  final Map<String, List<Map<String, String>>> _saved = {};

  List<String> get _pages => _modules[_module]![_group]!;
  List<Map<String, String>> get _rows {
    final rows = _saved[_page] ?? _sampleRows(_page);
    if (_search.trim().isEmpty) return rows;
    return rows.where((r) => r.values.any((v) => v.toLowerCase().contains(_search.toLowerCase()))).toList();
  }

  List<Map<String, String>> _sampleRows(String page) {
    if (page == 'شجرة الحسابات') {
      return [
        {'الكود': '1', 'اسم الحساب': 'الأصول', 'المستوى': 'رئيسي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '11', 'اسم الحساب': 'الأصول المتداولة', 'المستوى': 'فرعي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '111', 'اسم الحساب': 'الخزائن', 'المستوى': 'فرعي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '11101', 'اسم الحساب': 'الخزينة الرئيسية', 'المستوى': 'تحليلي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
        {'الكود': '2', 'اسم الحساب': 'الالتزامات', 'المستوى': 'رئيسي', 'الطبيعة': 'دائن', 'الحالة': 'نشط'},
        {'الكود': '3', 'اسم الحساب': 'حقوق الملكية', 'المستوى': 'رئيسي', 'الطبيعة': 'دائن', 'الحالة': 'نشط'},
        {'الكود': '4', 'اسم الحساب': 'الإيرادات', 'المستوى': 'رئيسي', 'الطبيعة': 'دائن', 'الحالة': 'نشط'},
        {'الكود': '5', 'اسم الحساب': 'المصروفات', 'المستوى': 'رئيسي', 'الطبيعة': 'مدين', 'الحالة': 'نشط'},
      ];
    }
    if (page.contains('خزائن')) {
      return [
        {'الكود': 'CASH-001', 'الاسم': 'الخزينة الرئيسية', 'النوع': 'رئيسية', 'الفرع': 'الإدارة العامة', 'الرصيد': '125,450 ج.م', 'الحالة': 'نشط'},
        {'الكود': 'CASH-002', 'الاسم': 'خزينة فرع العبور', 'النوع': 'فرعية', 'الفرع': 'العبور', 'الرصيد': '24,800 ج.م', 'الحالة': 'نشط'},
      ];
    }
    if (page.contains('إعادة الطلب') || page.contains('النفاد')) {
      return [
        {'الصنف': 'زيت عباد الشمس', 'المخزن': 'المخزن الرئيسي', 'الرصيد الحالي': '12 كرتونة', 'الحد الأدنى': '20 كرتونة', 'الكمية المقترحة': '28 كرتونة', 'الحالة': 'تنبيه تجريبي'},
        {'الصنف': 'مكرونة 400 جم', 'المخزن': 'المخزن الرئيسي', 'الرصيد الحالي': '8 كراتين', 'الحد الأدنى': '15 كرتونة', 'الكمية المقترحة': '22 كرتونة', 'الحالة': 'تنبيه تجريبي'},
      ];
    }
    if (page.contains('الصلاحية') || page.contains('التشغيلات')) {
      return [
        {'الصنف': 'عصير معبأ', 'رقم التشغيلة': 'BATCH-DEMO-01', 'تاريخ الصلاحية': 'بيانات توضيحية', 'الرصيد': '6 كراتين', 'الحالة': 'يتطلب متابعة'},
      ];
    }
    if (page.contains('الجرد') || page == 'جرد فعلي') {
      return [
        {'رقم المحضر': 'COUNT-DEMO-001', 'المخزن': 'المخزن الرئيسي', 'التاريخ': '—', 'عدد الأصناف': '—', 'الحالة': 'مسودة تجريبية'},
      ];
    }
    if (page.contains('الأصناف') || page == 'دليل الأصناف') {
      return [
        {'الكود': 'SKU-001', 'الاسم': 'زيت عباد الشمس', 'المجموعة': 'زيوت', 'الوحدة': 'كرتونة', 'المخزون': '120', 'الحالة': 'نشط'},
        {'الكود': 'SKU-002', 'الاسم': 'مكرونة 400 جم', 'المجموعة': 'مكرونات', 'الوحدة': 'كرتونة', 'المخزون': '85', 'الحالة': 'نشط'},
        {'الكود': 'SKU-003', 'الاسم': 'سمن نباتي', 'المجموعة': 'سمنات', 'الوحدة': 'كرتونة', 'المخزون': '42', 'الحالة': 'نشط'},
      ];
    }
    if (page.contains('API') || page.contains('الربط الخارجي') || page.contains('التكامل')) {
      return [
        {'البند': 'حالة واجهة API', 'القيمة': 'غير مفعّلة', 'التفاصيل': 'تحتاج إعداد الخادم والمصادقة', 'الحالة': 'تجهيز'},
        {'البند': 'نمط الربط', 'القيمة': 'REST / JSON', 'التفاصيل': 'قابل للتحديد عند التنفيذ', 'الحالة': 'تصميم'},
        {'البند': 'سجل الطلبات', 'القيمة': 'غير متصل', 'التفاصيل': 'لن تُحفظ طلبات فعلية قبل ربط الخادم', 'الحالة': 'غير متصل'},
      ];
    }
    if (page.contains('المورد')) {
      return [{'الكود': 'SUP-001', 'الاسم': 'مورد تجريبي', 'التصنيف': 'موزع رئيسي', 'الهاتف': '01000000000', 'الرصيد': '0 ج.م', 'الحالة': 'نشط'}];
    }
    if (page.contains('العملاء') || page.contains('العميل')) {
      return [{'الكود': 'CUS-001', 'الاسم': 'عميل تجريبي', 'التصنيف': 'تاجر جملة', 'الهاتف': '01000000000', 'الرصيد': '0 ج.م', 'الحالة': 'نشط'}];
    }
    if (_group == 'تقارير') {
      return [{'المؤشر': 'حالة التقرير', 'القيمة': 'نموذج عرض', 'ملاحظة': 'غير مرتبط بقاعدة البيانات بعد'}];
    }
    return [
      {'الكود': 'DEMO-001', 'الاسم': page, 'الوصف': 'سجل توضيحي للواجهة', 'الحالة': 'نموذج'},
      {'الكود': 'DEMO-002', 'الاسم': 'مثال إضافي', 'الوصف': 'بيانات تجريبية فقط', 'الحالة': 'نموذج'},
    ];
  }

  void _openAddDialog() {
    final code = TextEditingController();
    final name = TextEditingController();
    final details = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('إضافة سجل — $_page'),
        content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, decoration: const InputDecoration(labelText: 'الكود / الرقم المرجعي')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم / البيان')),
          const SizedBox(height: 12),
          TextField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف أو ملاحظات')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty) return;
            final rows = List<Map<String, String>>.from(_saved[_page] ?? _sampleRows(_page));
            rows.insert(0, {'الكود': code.text.trim().isEmpty ? 'NEW-${rows.length + 1}' : code.text.trim(), 'الاسم': name.text.trim(), 'الوصف': details.text.trim(), 'الحالة': 'مسودة'});
            setState(() => _saved[_page] = rows);
            Navigator.pop(dctx);
          }, child: const Text('حفظ السجل')),
        ],
      ),
    ).then((_) { code.dispose(); name.dispose(); details.dispose(); });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 900;
      return Scaffold(
        backgroundColor: _canvas,
        drawer: compact ? Drawer(child: _sidebar()) : null,
        body: Row(children: [
          if (!compact) SizedBox(width: 275, child: _sidebar()),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Column(children: [
              _header(compact),
              Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(compact ? 14 : 26), child: _module == 'إدارة البرنامج' && _page == 'بيانات الشركة' ? _home() : _module == 'إدارة التطبيقات' ? _appManagement() : _workspace())),
            ])),
            if (!compact) SizedBox(width: 286, child: _rightPanel()),
          ])),
        ]),
      );
    }));
  }

  final Set<String> _expandedModules = {'إدارة البرنامج'};
  final Set<String> _expandedGroups = {'إدارة البرنامج::بيانات أساسية'};

  Widget _sidebar() => Container(
    color: _purple,
    child: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Image.asset('assets/images/silsila_logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سلسلة Silsila', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              SizedBox(height: 4),
              Text('سلسلة .. بنربط السوق ببعضه', style: TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('ERP • إدارة موارد المؤسسة', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ])),
          ]),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: _modules.entries.map((moduleEntry) {
            final name = moduleEntry.key;
            final moduleOpen = _expandedModules.contains(name);
            final selectedModule = name == _module;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Row(children: [
                  Expanded(child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    selected: selectedModule,
                    selectedTileColor: Colors.white.withValues(alpha: .14),
                    leading: Icon(_iconFor(name), color: selectedModule ? _orange : Colors.white70, size: 20),
                    title: Text(name, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: selectedModule ? FontWeight.w800 : FontWeight.w500)),
                    onTap: () => setState(() {
                      _module = name;
                      _group = moduleEntry.value.keys.first;
                      _page = moduleEntry.value[_group]!.first;
                      _search = '';
                      if (!moduleOpen) _expandedModules.add(name);
                    }),
                  )),
                  IconButton(
                    tooltip: moduleOpen ? 'طي القائمة' : 'توسيع القائمة',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      if (moduleOpen) {
                        _expandedModules.remove(name);
                        _expandedGroups.removeWhere((key) => key.startsWith('$name::'));
                      } else {
                        _expandedModules.add(name);
                      }
                    }),
                    icon: Text(moduleOpen ? '−' : '+', style: const TextStyle(color: _orange, fontSize: 25, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              if (moduleOpen)
                ...moduleEntry.value.entries.map((groupEntry) {
                  final groupKey = '$name::${groupEntry.key}';
                  final groupOpen = _expandedGroups.contains(groupKey);
                  final selectedGroup = selectedModule && _group == groupEntry.key;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(start: 13, end: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -3),
                          contentPadding: const EdgeInsetsDirectional.only(start: 10, end: 2),
                          selected: selectedGroup,
                          selectedTileColor: Colors.white.withValues(alpha: .08),
                          title: Text(groupEntry.key, style: TextStyle(color: selectedGroup ? _orange : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                          onTap: () => setState(() {
                            _module = name;
                            _group = groupEntry.key;
                            _page = groupEntry.value.first;
                            _search = '';
                            _expandedGroups.add(groupKey);
                          }),
                        )),
                        IconButton(
                          tooltip: groupOpen ? 'طي الشاشات' : 'عرض الشاشات',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: () => setState(() {
                            if (groupOpen) {
                              _expandedGroups.remove(groupKey);
                            } else {
                              _expandedGroups.add(groupKey);
                            }
                          }),
                          icon: Text(groupOpen ? '−' : '+', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      if (groupOpen)
                        ...groupEntry.value.map((page) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 20, end: 5),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                            minLeadingWidth: 12,
                            leading: Icon(page == _page && selectedModule ? Icons.radio_button_checked_rounded : Icons.circle_outlined, color: page == _page && selectedModule ? _orange : Colors.white38, size: 11),
                            title: Text(page, style: TextStyle(color: page == _page && selectedModule ? Colors.white : Colors.white70, fontSize: 10.5, fontWeight: page == _page && selectedModule ? FontWeight.w800 : FontWeight.normal)),
                            onTap: () => setState(() {
                              _module = name;
                              _group = groupEntry.key;
                              _page = page;
                              _search = '';
                              _expandedModules.add(name);
                              _expandedGroups.add(groupKey);
                            }),
                          ),
                        )),
                    ]),
                  );
                }),
            ]);
          }).toList(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('تطبيقات قيد التطوير', style: TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 12))),
          _appLink('تطبيق سلسلة', 'التطبيق الرئيسي', Icons.apps_rounded, true),
          _appLink('تطبيق رقم 2', 'جاري إنشاؤه', Icons.phone_android_rounded, false),
          _appLink('تطبيق رقم 3', 'جاري إنشاؤه', Icons.web_rounded, false),
        )),
        const Divider(color: Colors.white24, height: 1),
        const Padding(padding: EdgeInsets.all(14), child: Column(children: [
          Text('سلسلة للبرمجيات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('سلسلة .. بنربط السوق ببعضه', style: TextStyle(color: _orange, fontSize: 12)),
        ])),
      ]),
    ),
  );

  IconData _iconFor(String name) {
    if (name.contains('إدارة البرنامج')) return Icons.settings_suggest_rounded;
    if (name.contains('الحسابات')) return Icons.account_balance_rounded;
    if (name.contains('الخزائن')) return Icons.account_balance_wallet_rounded;
    if (name.contains('المخازن')) return Icons.warehouse_rounded;
    if (name.contains('المشتريات')) return Icons.shopping_cart_rounded;
    if (name.contains('المبيعات')) return Icons.point_of_sale_rounded;
    if (name.contains('الموردون')) return Icons.factory_rounded;
    if (name.contains('العملاء')) return Icons.groups_rounded;
    if (name.contains('الموارد')) return Icons.badge_rounded;
    if (name.contains('الرواتب')) return Icons.payments_rounded;
    if (name.contains('الفروع')) return Icons.hub_rounded;
    if (name.contains('المندوبون')) return Icons.delivery_dining_rounded;
    if (name.contains('العروض')) return Icons.campaign_rounded;
    if (name.contains('الدعم')) return Icons.support_agent_rounded;
    return Icons.query_stats_rounded;
  }

  Widget _appLink(String title, String subtitle, IconData icon, bool active) => ListTile(
    dense: true,
    leading: Icon(icon, color: active ? _orange : Colors.white70, size: 19),
    title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle, style: TextStyle(color: active ? Colors.white70 : Colors.white54, fontSize: 10)),
    onTap: active ? () => _open('إدارة التطبيقات', 'بيانات أساسية', 'إعدادات هوية التطبيق') : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title — $subtitle'))),
  );

  Widget _rightPanel() => Container(
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFECE7F2)))),
    child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [const Icon(Icons.notifications_active_outlined, color: _purple), const SizedBox(width: 8), const Expanded(child: Text('لوحة التنبيهات', style: TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 16))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFF1D9), borderRadius: BorderRadius.circular(20)), child: const Text('3', style: TextStyle(color: Color(0xFF9A5A00), fontWeight: FontWeight.w900)))]),
      const SizedBox(height: 12),
      _notice(Icons.inventory_2_outlined, 'مراجعة المخزون', 'راجع حدود إعادة الطلب والصلاحية', _orange),
      _notice(Icons.security_outlined, 'صلاحيات المستخدمين', 'إعداد سياسات الوصول قبل التشغيل', _pink),
      _notice(Icons.cloud_off_outlined, 'الربط بقاعدة البيانات', 'بعض الشاشات ما زالت تجريبية', _purple),
      const SizedBox(height: 22),
      const Divider(color: Color(0xFFECE7F2)),
      const SizedBox(height: 12),
      const Row(children: [Icon(Icons.history_rounded, color: _purple), SizedBox(width: 8), Expanded(child: Text('سجل النشاطات', style: TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 16)))]),
      const SizedBox(height: 12),
      ..._activityLog.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 7, color: _orange), const SizedBox(width: 9), Expanded(child: Text(entry, style: const TextStyle(fontSize: 11, height: 1.5, color: Colors.black87)))]))),
      const SizedBox(height: 12),
      const Text('ملاحظة: التنبيهات وسجل النشاطات حاليًا أمثلة محلية، وليسا متصلين بعد بأحداث النظام الفعلية.', style: TextStyle(color: Colors.black54, fontSize: 10, height: 1.6)),
    ])),
  );

  Widget _notice(IconData icon, String title, String detail, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: _canvas, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFECE7F2))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 19), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)), const SizedBox(height: 4), Text(detail, style: const TextStyle(color: Colors.black54, fontSize: 10, height: 1.5))]))]),
  );

  Widget _appManagement() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6E2BA6)]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة التطبيقات', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      Text('مكان موحد لتخصيص الهوية والألوان والصور والصلاحيات وإعدادات التطبيقات التابعة لسلسلة.', style: TextStyle(color: Colors.white70, height: 1.7)),
    ])),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('هوية التطبيق الحالي', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      TextFormField(initialValue: _appName, decoration: const InputDecoration(labelText: 'اسم التطبيق', border: OutlineInputBorder()), onChanged: (v) => setState(() => _appName = v)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _colorChoice('بنفسجي', const Color(0xFF3E007D), _appPrimary, (v) => setState(() => _appPrimary = v)),
        _colorChoice('برتقالي', const Color(0xFFFFA015), _appAccent, (v) => setState(() => _appAccent = v)),
        _colorChoice('وردي', const Color(0xFFFF27C3), _appPrimary, (v) => setState(() => _appPrimary = v)),
        _colorChoice('أزرق', const Color(0xFF1565C0), _appPrimary, (v) => setState(() => _appPrimary = v)),
      ]),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _appPrimary, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.apps_rounded, color: Colors.white, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_appName.trim().isEmpty ? 'اسم التطبيق' : _appName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const Text('معاينة الألوان المختارة', style: TextStyle(color: Colors.white70, fontSize: 11))])), Container(width: 18, height: 18, decoration: BoxDecoration(color: _appAccent, shape: BoxShape.circle))])),
      const SizedBox(height: 18),
      const Text('إدارة الملفات والصور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 8),
      _managementTile(Icons.image_outlined, 'شعار التطبيق وصورة البداية', 'تحديد ملفات الهوية التي ستستخدم عند ربط رفع الملفات'),
      _managementTile(Icons.category_outlined, 'صور الأصناف والفئات', 'إضافة صور المنتجات وتصنيفات المواد الغذائية'),
      _managementTile(Icons.factory_outlined, 'صور الموردين والعملاء', 'إدارة الشعارات والصور والبيانات التعريفية'),
      _managementTile(Icons.local_shipping_outlined, 'شركات الشحن', 'صور الشركات وبيانات التواصل وخيارات التوصيل'),
      const SizedBox(height: 18),
      const Text('صلاحيات الإدارة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowThemeManagement, onChanged: (v) => setState(() => _allowThemeManagement = v), title: const Text('السماح بتعديل الاسم والألوان'), subtitle: const Text('إعداد محلي للواجهة فقط')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowImageManagement, onChanged: (v) => setState(() => _allowImageManagement = v), title: const Text('السماح بإدارة الصور'), subtitle: const Text('يتطلب لاحقًا ربط التخزين والصلاحيات بالخادم')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowPermissionManagement, onChanged: (v) => setState(() => _allowPermissionManagement = v), title: const Text('السماح بإدارة صلاحيات المستخدمين'), subtitle: const Text('ليس بديلًا عن صلاحيات قاعدة البيانات')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => setState(() => _activityLog.insert(0, 'تم تعديل إعدادات واجهة إدارة التطبيقات محليًا')), icon: const Icon(Icons.save_outlined), label: const Text('تسجيل التعديلات في سجل النشاطات')),
      const SizedBox(height: 8),
      const Text('تنبيه: هذه المعاينة تغيّر الحالة داخل الواجهة الحالية فقط. حفظ الهوية ورفع الصور وتطبيق الصلاحيات على المستخدمين يحتاج تخزينًا وقاعدة بيانات وخادمًا موثوقًا.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.7)),
    ])),
  ]);

  Widget _colorChoice(String label, Color color, Color selected, ValueChanged<Color> onSelect) => OutlinedButton(
    onPressed: () => onSelect(color),
    style: OutlinedButton.styleFrom(side: BorderSide(color: selected == color ? _purple : const Color(0xFFECE7F2), width: selected == color ? 2 : 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Text(label)]),
  );

  Widget _managementTile(IconData icon, String title, String detail) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _purple)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    subtitle: Text(detail, style: const TextStyle(fontSize: 11, height: 1.5)),
    trailing: const Icon(Icons.chevron_left_rounded, color: _purple),
  );

  Widget _header(bool compact) => Container(height: 76, padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 25), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE7F2)))), child: Row(children: [
    if (compact) Builder(builder: (ctx) => IconButton(onPressed: () => Scaffold.of(ctx).openDrawer(), icon: const Icon(Icons.menu_rounded, color: _purple))),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_module, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 4),
      Text('الرئيسية  /  $_module  /  $_page', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
    ])),
    if (!compact) SizedBox(width: 240, child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'بحث سريع', prefixIcon: const Icon(Icons.search_rounded), isDense: true, filled: true, fillColor: _canvas, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
    const SizedBox(width: 8),
    IconButton(tooltip: 'الإشعارات', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مركز الإشعارات التجريبي'))), icon: const Icon(Icons.notifications_none_rounded, color: _purple)),
    const CircleAvatar(backgroundColor: Color(0xFFF0E7FA), child: Icon(Icons.person_rounded, color: _purple)),
  ]));

  Widget _home() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(26), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6E2BA6)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('مرحبًا بك في نظام سلسلة ERP', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
      SizedBox(height: 10),
      Text('منظومة موحدة لإدارة الحسابات والمخازن والمبيعات والمشتريات والفروع والموارد البشرية.', style: TextStyle(color: Colors.white70, height: 1.8)),
      SizedBox(height: 15),
      Text('تنبيه: هذه واجهة تأسيسية ببيانات تجريبية، ولم يتم ربطها بعد بقاعدة بيانات تشغيلية.', style: TextStyle(color: Colors.white, fontSize: 12)),
    ])),
    const SizedBox(height: 22),
    const Text('الملخص التنفيذي', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _purple)),
    const SizedBox(height: 12),
    LayoutBuilder(builder: (context, c) {
      final n = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
      return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: n, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: n == 1 ? 3.1 : 1.7, children: const [
        _Metric(title: 'مبيعات اليوم', value: '—', note: 'بانتظار ربط البيانات', icon: Icons.trending_up_rounded, color: _purple),
        _Metric(title: 'تحصيلات اليوم', value: '—', note: 'بانتظار ربط البيانات', icon: Icons.payments_outlined, color: Color(0xFF18865A)),
        _Metric(title: 'طلبات قيد التنفيذ', value: '—', note: 'بانتظار ربط البيانات', icon: Icons.local_shipping_outlined, color: _orange),
        _Metric(title: 'تنبيهات المخزون', value: '—', note: 'بانتظار ربط البيانات', icon: Icons.inventory_2_outlined, color: _pink),
      ]);
    }),
    const SizedBox(height: 22),
    const Text('الوصول السريع', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _purple)),
    const SizedBox(height: 12),
    Wrap(spacing: 9, runSpacing: 9, children: [
      _quick('شجرة الحسابات', Icons.account_tree_rounded, () => _open('الحسابات المالية', 'بيانات أساسية', 'شجرة الحسابات')),
      _quick('الخزائن', Icons.account_balance_wallet_rounded, () => _open('الحسابات المالية', 'بيانات أساسية', 'الخزائن الرئيسية والفرعية')),
      _quick('دليل الأصناف', Icons.inventory_2_rounded, () => _open('المخازن والفروع', 'بيانات أساسية', 'دليل الأصناف')),
      _quick('دليل العملاء', Icons.groups_rounded, () => _open('المبيعات والعملاء', 'بيانات أساسية', 'دليل العملاء')),
      _quick('ملف الموظف', Icons.badge_rounded, () => _open('الموارد البشرية والرواتب', 'بيانات أساسية', 'ملف الموظف')),
    ]),
    const SizedBox(height: 22),
    _about(),
  ]);

  void _open(String module, String group, String page) => setState(() { _module = module; _group = group; _page = page; _search = ''; });

  Widget _quick(String title, IconData icon, VoidCallback action) => OutlinedButton.icon(
    onPressed: action, icon: Icon(icon, size: 19), label: Text(title),
    style: OutlinedButton.styleFrom(foregroundColor: _purple, backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16), side: const BorderSide(color: Color(0xFFE5DDED)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
  );

  Widget _workspace() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(spacing: 8, runSpacing: 8, children: _modules[_module]!.keys.map((g) {
      final selected = g == _group;
      return ChoiceChip(label: Text(g), selected: selected, selectedColor: _purple, labelStyle: TextStyle(color: selected ? Colors.white : _purple, fontWeight: FontWeight.w700), onSelected: (_) => setState(() { _group = g; _page = _modules[_module]![g]!.first; _search = ''; }));
    }).toList()),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(13)), child: Icon(_iconFor(_module), color: _purple)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_page, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _purple)), const SizedBox(height: 4), Text('$_module • $_group', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
        if (_group != 'تقارير') FilledButton.icon(onPressed: _openAddDialog, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('إضافة')),
      ]),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: _pages.map((p) => ActionChip(label: Text(p), backgroundColor: p == _page ? const Color(0xFFF1E9FA) : const Color(0xFFF9F7FB), side: BorderSide(color: p == _page ? _purple : const Color(0xFFECE7F2)), onPressed: () => setState(() => _page = p))).toList()),
      const SizedBox(height: 16),
      if (_group == 'تقارير') const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('نموذج تقارير تجريبي؛ ستظهر المؤشرات الفعلية بعد ربط مصادر البيانات واعتماد المعادلات المحاسبية.', style: TextStyle(color: Colors.black54, height: 1.6))),
      if (_rows.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد نتائج مطابقة.', textAlign: TextAlign.center))
      else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F0FA)), columns: _rows.first.keys.map((k) => DataColumn(label: Text(k, style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)))).toList(), rows: _rows.map((r) => DataRow(cells: _rows.first.keys.map((k) => DataCell(Text(r[k] ?? '—'))).toList())).toList())),
      const SizedBox(height: 12),
      Text('عدد السجلات المعروضة: ${_rows.length} • بيانات توضيحية', style: const TextStyle(color: Colors.black45, fontSize: 11)),
    ])),
    const SizedBox(height: 18),
    _about(),
  ]);

  Widget _about() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE7F2))), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('عن البرنامج', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
    SizedBox(height: 12),
    Text('تم إنشاء هذا البرنامج بواسطة شركة سلسلة للبرمجيات — أ. محمد عبد العاطي.', style: TextStyle(fontWeight: FontWeight.w700, height: 1.7)),
    Text('موبايل: 01121237271', style: TextStyle(height: 1.7)),
    Text('البريد الإلكتروني: attymanatty@gmail.com', style: TextStyle(height: 1.7)),
    SizedBox(height: 6),
    Text('خبرة في جوانب تجارة وتوزيع المواد الغذائية لمدة تقارب 20 عامًا، والمشاركة في تطوير كبرى التجار والشركات بنظام الفروع وإعادة هيكلتها وتطويرها في مختلف الأقسام.', style: TextStyle(height: 1.8)),
    SizedBox(height: 8),
    Text('المنظومة مصممة للتوسع إلى إدارة مالية ومخزنية وتشغيلية موحدة متعددة الفروع.', style: TextStyle(color: _purple, height: 1.7)),
  ]));

}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.note, required this.icon, required this.color});
  final String title, value, note;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F2))), child: Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
    const SizedBox(width: 12),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(color: _purple, fontSize: 21, fontWeight: FontWeight.w900)),
      Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 10)),
    ])),
  ]));
}
