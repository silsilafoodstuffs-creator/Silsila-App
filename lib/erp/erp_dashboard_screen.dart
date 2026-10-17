import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String _selectedAppKey = 'silsila';
  String _appName = 'سلسلة';
  Color _appPrimary = const Color(0xFF3E007D);
  Color _appAccent = const Color(0xFFFFA015);
  final Map<String, Map<String, Object>> _managedAppDrafts = {
    'silsila': {'name': 'سلسلة', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
    'app_2': {'name': 'تطبيق رقم 2', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
    'app_3': {'name': 'تطبيق رقم 3', 'primary': const Color(0xFF3E007D), 'accent': const Color(0xFFFFA015)},
  };

  void _selectManagedApp(String key) {
    final draft = _managedAppDrafts[key];
    if (draft == null) return;
    setState(() {
      _selectedAppKey = key;
      _appName = draft['name'] as String;
      _appPrimary = draft['primary'] as Color;
      _appAccent = draft['accent'] as Color;
    });
  }

  void _updateManagedAppDraft({String? name, Color? primary, Color? accent}) {
    setState(() {
      if (name != null) _appName = name;
      if (primary != null) _appPrimary = primary;
      if (accent != null) _appAccent = accent;
      _managedAppDrafts[_selectedAppKey] = {
        'name': _appName,
        'primary': _appPrimary,
        'accent': _appAccent,
      };
    });
  }
  bool _allowImageManagement = true;
  bool _allowThemeManagement = true;
  bool _allowPermissionManagement = true;
  final List<String> _activityLog = ['تم فتح لوحة ERP', 'تم تجهيز أقسام المخازن والفروع', 'تمت إضافة نماذج إدارة المستندات'];
  String _group = 'بيانات أساسية';
  String _page = 'بيانات الشركة';
  String _search = '';
  Map<String, String>? _selectedRecord;
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
            setState(() {
              _saved[_page] = rows;
              _selectedRecord = Map<String, String>.from(rows.first);
              _activityLog.insert(0, 'تمت إضافة سجل جديد في شاشة $_page داخل الجلسة الحالية');
            });
            Navigator.pop(dctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمت إضافة السجل محليًا. لم يُحفظ في قاعدة البيانات.')),
            );
          }, child: const Text('حفظ السجل')),
        ],
      ),
    ).then((_) { code.dispose(); name.dispose(); details.dispose(); });
  }

  void _showActionMessage(String message) {
    setState(() => _activityLog.insert(0, message));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _saveCurrentPage() {
    setState(() => _activityLog.insert(0, 'تم حفظ حالة شاشة $_page داخل الجلسة الحالية'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات المحلية لهذه الشاشة. الحفظ الدائم يتطلب ربط قاعدة البيانات.')));
  }

  void _editCurrentRecord() {
    final rows = List<Map<String, String>>.from(_saved[_page] ?? _sampleRows(_page));
    if (rows.isEmpty) { _showActionMessage('لا يوجد سجل لتعديله في شاشة $_page'); return; }
    final selected = _selectedRecord;
    final selectedIndex = selected == null ? 0 : rows.indexWhere((row) => _sameRecord(row, selected));
    final targetIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final controllers = <String, TextEditingController>{for (final entry in rows[targetIndex].entries) entry.key: TextEditingController(text: entry.value)};
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('تعديل سجل — $_page'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: controllers.entries.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: entry.value, decoration: InputDecoration(labelText: entry.key)),
      )).toList()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          final updated = {for (final entry in controllers.entries) entry.key: entry.value.text.trim()};
          rows[targetIndex] = updated;
          setState(() { _saved[_page] = rows; _selectedRecord = updated; });
          Navigator.pop(dialogContext);
          _showActionMessage('تم تعديل سجل محلي في شاشة $_page');
        }, child: const Text('حفظ التعديل')),
      ],
    )).then((_) { for (final controller in controllers.values) { controller.dispose(); } });
  }

  bool _sameRecord(Map<String, String> a, Map<String, String> b) => a.length == b.length && a.entries.every((entry) => b[entry.key] == entry.value);

  String _currentPageCsv() {
    final rows = _rows;
    if (rows.isEmpty) return '';
    final keys = rows.first.keys.toList();
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    return [
      '\uFEFF${keys.map(cell).join(',')}',
      ...rows.map((row) => keys.map((key) => cell(row[key] ?? '')).join(',')),
    ].join('\\r\\n');
  }

  void _exportExcel() {
    final csv = _currentPageCsv();
    if (csv.isEmpty) { _showActionMessage('لا توجد بيانات لتصديرها من شاشة $_page'); return; }
    Clipboard.setData(ClipboardData(text: csv));
    _showActionMessage('تم تجهيز ملف CSV متوافق مع Excel ونسخ محتواه للحافظة. استخدم لصق في Excel ثم احفظه بصيغة XLSX.');
  }

  void _showPrintPreview({required bool pdf}) {
    final rows = _rows;
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(pdf ? 'تصدير PDF — $_page' : 'معاينة الطباعة — $_page'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('سلسلة Silsila • $_module • $_group', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8), Text('الشاشة: $_page • عدد السجلات: ${rows.length}'), const Divider(),
        if (rows.isEmpty) const Text('لا توجد بيانات لعرضها.')
        else ...rows.take(30).map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join('  |  ')))),
        if (rows.length > 30) const Text('تم عرض أول 30 سجلًا في المعاينة.'),
        const SizedBox(height: 8),
        Text(pdf ? 'هذه معاينة تجهيز PDF؛ يلزم إضافة محرك PDF للتنزيل الفعلي.' : 'هذه معاينة للطباعة؛ إرسالها إلى الطابعة يحتاج تفعيل خدمة الطباعة في نسخة التشغيل.', style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
    ));
  }

  Widget _recordAction(String label, IconData icon, Color color, VoidCallback action) => FilledButton.icon(
    onPressed: action,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );

  Widget _recordToolbar({bool includeAdd = true}) => Wrap(spacing: 7, runSpacing: 7, children: [
    if (includeAdd) _recordAction('إضافة', Icons.add_rounded, const Color(0xFF18865A), _openAddDialog),
    _recordAction('تعديل', Icons.edit_outlined, _orange, _editCurrentRecord),
    _recordAction('حفظ', Icons.save_outlined, _purple, _saveCurrentPage),
    _recordAction('طباعة', Icons.print_outlined, _pink, () => _showPrintPreview(pdf: false)),
    _recordAction('تصدير Excel', Icons.table_view_outlined, const Color(0xFF16834A), _exportExcel),
    _recordAction('تصدير PDF', Icons.picture_as_pdf_outlined, const Color(0xFFD32F2F), () => _showPrintPreview(pdf: true)),
  ]);

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
              Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(compact ? 14 : 26), child: _page == 'عن البرنامج' ? _about() : _module == 'إدارة البرنامج' && _page == 'بيانات الشركة' ? _home() : _module == 'إدارة التطبيقات' ? _appManagement() : _workspace())),
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
          children: [
          ..._modules.entries.map((moduleEntry) {
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
                    leading: Icon(_iconFor(name), color: _orange, size: 20),
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
                          icon: Text(groupOpen ? '−' : '+', style: const TextStyle(color: _orange, fontSize: 21, fontWeight: FontWeight.w700)),
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
                            leading: Icon(page == _page && selectedModule ? Icons.radio_button_checked_rounded : Icons.circle_outlined, color: _orange, size: 11),
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
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), selected: _page == 'عن البرنامج', selectedTileColor: Colors.white.withValues(alpha: .14), leading: const Icon(Icons.info_outline_rounded, color: _orange, size: 20), title: const Text('عن البرنامج', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)), onTap: () => setState(() { _page = 'عن البرنامج'; _search = ''; }))),
          ],
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

  Widget _rightPanel() => Container(
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFECE7F2)))),
    child: SafeArea(child: ListView(padding: const EdgeInsets.all(12), children: [
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(child: Text('لوحة التنبيهات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)), child: const Text('3', style: TextStyle(color: _purple, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12),
          _notice(Icons.inventory_2_outlined, 'مراجعة المخزون', 'راجع حدود إعادة الطلب والصلاحية', _orange),
          _notice(Icons.security_outlined, 'صلاحيات المستخدمين', 'إعداد سياسات الوصول قبل التشغيل', _pink),
          _notice(Icons.cloud_off_outlined, 'الربط بقاعدة البيانات', 'بعض الشاشات ما زالت تجريبية', Colors.white),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [Icon(Icons.history_rounded, color: Colors.white), SizedBox(width: 8), Expanded(child: Text('سجل النشاطات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)))]),
          const SizedBox(height: 12),
          ..._activityLog.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 7, color: _orange), const SizedBox(width: 9), Expanded(child: Text(entry, style: const TextStyle(fontSize: 11, height: 1.5, color: Colors.white, fontWeight: FontWeight.w800)))]))),
        ]),
      ),
      const SizedBox(height: 12),
      const Text('ملاحظة: التنبيهات وسجل النشاطات حاليًا أمثلة محلية، وليسا متصلين بعد بأحداث النظام الفعلية.', style: TextStyle(color: Colors.black54, fontSize: 10, height: 1.6)),
    ])),
  );

  Widget _notice(IconData icon, String title, String detail, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white)),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.5, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );

  Widget _appManagement() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _recordToolbar(includeAdd: false),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6E2BA6)]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة التطبيقات', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      Text('مكان موحد لتخصيص الهوية والألوان والصور والصلاحيات وإعدادات التطبيقات التابعة لسلسلة.', style: TextStyle(color: Colors.white70, height: 1.7)),
    ])),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('التطبيقات التابعة لسلسلة', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('إدارة تطبيق سلسلة والتطبيقات الإضافية من مكان واحد؛ التطبيقات غير المنشورة تظل قيد التجهيز دون إظهار قسم مستقل لها.', style: TextStyle(color: Colors.black54, height: 1.6, fontSize: 12)),
      const SizedBox(height: 12),
      _managedAppCard('تطبيق سلسلة', 'التطبيق الرئيسي', Icons.apps_rounded, _selectedAppKey == 'silsila', () => _selectManagedApp('silsila')),
      _managedAppCard('تطبيق رقم 2', 'قيد التجهيز — يمكن استكمال إعداداته هنا', Icons.phone_android_rounded, _selectedAppKey == 'app_2', () => _selectManagedApp('app_2')),
      _managedAppCard('تطبيق رقم 3', 'قيد التجهيز — يمكن استكمال إعداداته هنا', Icons.web_rounded, _selectedAppKey == 'app_3', () => _selectManagedApp('app_3')),
      const Divider(height: 28),
      const Text('هوية التطبيق المحدد', style: TextStyle(color: _purple, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      TextFormField(key: ValueKey(_selectedAppKey), initialValue: _appName, decoration: const InputDecoration(labelText: 'اسم التطبيق', border: OutlineInputBorder()), onChanged: (v) => _updateManagedAppDraft(name: v)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _colorChoice('بنفسجي', const Color(0xFF3E007D), _appPrimary, (v) => _updateManagedAppDraft(primary: v)),
        _colorChoice('برتقالي', const Color(0xFFFFA015), _appAccent, (v) => _updateManagedAppDraft(accent: v)),
        _colorChoice('وردي', const Color(0xFFFF27C3), _appAccent, (v) => _updateManagedAppDraft(accent: v)),
        _colorChoice('أزرق', const Color(0xFF1565C0), _appAccent, (v) => _updateManagedAppDraft(accent: v)),
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
      FilledButton.icon(onPressed: () => setState(() => _activityLog.insert(0, 'تم حفظ مسودة إعدادات التطبيق داخل الجلسة الحالية')), icon: const Icon(Icons.save_outlined), label: const Text('حفظ المسودة الحالية')),
      const SizedBox(height: 8),
      const Text('تُحفظ مسودات الاسم والألوان لكل تطبيق داخل حالة الواجهة الحالية فقط، وتُفقد عند إغلاقها. الحفظ الدائم ورفع الصور وتطبيق الصلاحيات يتطلب ربطًا آمنًا بقاعدة البيانات.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.7)),
    ])),
  ]);

  Widget _managedAppCard(String title, String subtitle, IconData icon, bool active, VoidCallback onTap) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    color: active ? const Color(0xFFFFF7EB) : const Color(0xFFFCFAFD),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(color: active ? _orange : const Color(0xFFECE7F2)),
    ),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: _orange),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Icon(active ? Icons.check_circle_rounded : Icons.tune_rounded, color: active ? _orange : _pink, size: 20),
    ),
  );

  Widget _colorChoice(String label, Color color, Color selected, ValueChanged<Color> onSelect) => OutlinedButton(
    onPressed: () => onSelect(color),
    style: OutlinedButton.styleFrom(side: BorderSide(color: selected == color ? _pink : const Color(0xFFECE7F2), width: selected == color ? 2 : 1), overlayColor: _pink.withValues(alpha: .10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
      Wrap(
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: _goHome,
            borderRadius: BorderRadius.circular(5),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              child: Text('الرئيسية', style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
            ),
          ),
          const Text('/', style: TextStyle(color: Colors.black45, fontSize: 11)),
          InkWell(
            onTap: () {
              final groups = _modules[_module]!;
              _open(_module, groups.keys.first, groups.values.first.first);
            },
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              child: Text(_module, style: const TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
            ),
          ),
          const Text('/', style: TextStyle(color: Colors.black45, fontSize: 11)),
          Text(_page, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
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
  ]);

  void _goHome() => setState(() {
    _module = 'إدارة البرنامج';
    _group = 'بيانات أساسية';
    _page = 'بيانات الشركة';
    _search = '';
    _selectedRecord = null;
  });

  void _open(String module, String group, String page) => setState(() {
    _module = module;
    _group = group;
    _page = page;
    _search = '';
    _selectedRecord = null;
    _expandedModules.add(module);
    _expandedGroups.add('$module::$group');
  });

  Widget _quick(String title, IconData icon, VoidCallback action) => OutlinedButton.icon(
    onPressed: action, icon: Icon(icon, size: 19), label: Text(title),
    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: _purple, overlayColor: Colors.white24, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16), side: const BorderSide(color: _purple), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
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
      ]),
      const SizedBox(height: 12),
      _recordToolbar(includeAdd: _group != 'تقارير'),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: _pages.map((p) => ActionChip(
        label: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: p == _page ? const Color(0xFF6E2BA6) : _purple,
        side: BorderSide(color: p == _page ? _orange : const Color(0xFF6E2BA6), width: p == _page ? 2 : 1),
        onPressed: () => setState(() { _page = p; _selectedRecord = null; }),
      )).toList()),
      const SizedBox(height: 16),
      if (_group == 'تقارير') const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('نموذج تقارير تجريبي؛ ستظهر المؤشرات الفعلية بعد ربط مصادر البيانات واعتماد المعادلات المحاسبية.', style: TextStyle(color: Colors.black54, height: 1.6))),
      if (_rows.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد نتائج مطابقة.', textAlign: TextAlign.center))
      else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F0FA)), showCheckboxColumn: true, columns: _rows.first.keys.map((k) => DataColumn(label: Text(k, style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)))).toList(), rows: _rows.map((r) => DataRow(selected: _selectedRecord != null && _sameRecord(r, _selectedRecord!), onSelectChanged: (selected) => setState(() => _selectedRecord = selected == true ? Map<String, String>.from(r) : null), cells: _rows.first.keys.map((k) => DataCell(Text(r[k] ?? '—'), onTap: () => setState(() => _selectedRecord = Map<String, String>.from(r)))).toList())).toList())),
      const SizedBox(height: 12),
      Text('عدد السجلات المعروضة: ${_rows.length} • بيانات توضيحية', style: const TextStyle(color: Colors.black45, fontSize: 11)),
    ])),
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
