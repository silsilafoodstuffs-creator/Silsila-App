import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/hr_attendance_rules_screen.dart';
import 'screens/erp_accounts_screen.dart';
import 'screens/erp_journal_entries_screen.dart';
import 'screens/erp_ledger_reports_screen.dart';

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
    'بيانات أساسية': ['بيانات الشركة', 'الفروع ومراكز التكلفة', 'المستخدمون والصلاحيات', 'إعدادات النظام', 'سجل العمليات', 'واجهة API والربط الخارجي', 'إدارة مفاتيح API', 'سجلات التكامل والطلبات', 'سياسات التسعير والخصومات', 'توزيع الأصناف على المندوبين', 'قيود البيع والشراء'],
    'حركات': ['اختبار ومراجعة الحركات', 'قائمة اعتماد القيود', 'إدارة الجلسات', 'سجل الدخول والخروج', 'النسخ الاحتياطي', 'إعداد نقاط الربط', 'اختبار الاتصال الخارجي'],
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
    'حركات': ['الحضور والانصراف', 'أجهزة البصمة وربط الحضور', 'قواعد الورديات والحضور والانصراف', 'الإجازات والأذونات', 'الجزاءات والمكافآت', 'السلف', 'تقييم الأداء', 'مسير الرواتب', 'صرف الرواتب', 'عمولات المبيعات', 'تسوية سلفة'],
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
  String _accountSearch = '';
  final TextEditingController _accountSearchController = TextEditingController();
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
              Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(compact ? 14 : 26), child: _page == 'عن البرنامج' ? _about() : _page == 'شجرة الحسابات' ? const ErpAccountsScreen() : _page == 'قيود اليومية' ? const ErpJournalEntriesScreen() : _page == 'ميزان المراجعة' ? const ErpLedgerReportsScreen(kind: ErpLedgerReportKind.trialBalance) : _page == 'الأستاذ العام' ? const ErpLedgerReportsScreen(kind: ErpLedgerReportKind.generalLedger) : _page == 'حركة حساب' ? const ErpLedgerReportsScreen(kind: ErpLedgerReportKind.accountMovement) : _module == 'إدارة البرنامج' && _page == 'بيانات الشركة' ? _home() : _module == 'إدارة التطبيقات' ? _appManagement() : _page == 'اختبار ومراجعة الحركات' ? _movementAuditScreen() : _page == 'المستخدمون والصلاحيات' ? _permissionsScreen() : _page == 'سياسات التسعير والخصومات' ? _pricingPolicyScreen() : _page == 'توزيع الأصناف على المندوبين' ? _delegateAllocationScreen() : _page == 'قيود البيع والشراء' ? _transactionRestrictionsScreen() : _page == 'قائمة اعتماد القيود' ? _journalApprovalScreen() : _page == 'قواعد الورديات والحضور والانصراف' ? const HrShiftRulesScreen() : _page == 'أجهزة البصمة وربط الحضور' ? const HrFingerprintDevicesScreen() : _workspace())),
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
      _quick('قواعد الورديات', Icons.schedule_rounded, () => _open('الموارد البشرية والرواتب', 'حركات', 'قواعد الورديات والحضور والانصراف')),
      _quick('أجهزة البصمة', Icons.fingerprint_rounded, () => _open('الموارد البشرية والرواتب', 'حركات', 'أجهزة البصمة وربط الحضور')),
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
    onPressed: action, icon: Icon(icon, size: 19, color: _orange), label: Text(title),
    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, iconColor: _orange, backgroundColor: _purple, overlayColor: Colors.white24, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16), side: const BorderSide(color: _purple), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
  );

  Widget _workspace() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(spacing: 8, runSpacing: 8, children: _modules[_module]!.keys.map((g) {
      final selected = g == _group;
      return ChoiceChip(label: Text(g), selected: selected, selectedColor: _purple, labelStyle: TextStyle(color: selected ? Colors.white : _purple, fontWeight: FontWeight.w700), onSelected: (_) => setState(() { _group = g; _page = _modules[_module]![g]!.first; _search = ''; }));
    }).toList()),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final titleBlock = Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(13)), child: Icon(_iconFor(_module), color: _purple)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_page, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _purple)),
            const SizedBox(height: 4),
            Text('$_module • $_group', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ])),
        ]);
        final toolbar = _recordToolbar(includeAdd: _group != 'تقارير');
        if (constraints.maxWidth >= 760) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            Flexible(child: Align(alignment: Alignment.centerLeft, child: toolbar)),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleBlock,
          const SizedBox(height: 12),
          toolbar,
        ]);
      }),
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

  final Set<String> _expandedAccounts = {'1', '11', '12', '2', '3', '4', '5'};

  static const List<_AccountNode> _chartOfAccounts = [
    _AccountNode('1', 'الأصول', 'مدين', children: [
      _AccountNode('11', 'الأصول المتداولة', 'مدين', children: [
        _AccountNode('111', 'النقدية وما في حكمها', 'مدين', children: [
          _AccountNode('11101', 'الخزائن الرئيسية', 'مدين', analytical: true, balance: 125450, movements: 42, change: 8.4),
          _AccountNode('11102', 'الخزائن الفرعية', 'مدين', analytical: true, balance: 24800, movements: 18, change: -2.1),
          _AccountNode('11103', 'البنوك والحسابات الجارية', 'مدين', analytical: true, balance: 310000, movements: 27, change: 5.6),
          _AccountNode('11104', 'شيكات تحت التحصيل', 'مدين', analytical: true, balance: 18000, movements: 4, change: 12),
        ]),
        _AccountNode('112', 'العملاء وأوراق القبض', 'مدين', children: [
          _AccountNode('11201', 'عملاء محليون', 'مدين', analytical: true, balance: 425000, movements: 86, change: 6.3),
          _AccountNode('11202', 'أوراق قبض', 'مدين', analytical: true, balance: 35000, movements: 5, change: -1.2),
          _AccountNode('11203', 'مخصص ديون مشكوك فيها', 'دائن', analytical: true, balance: -12000, movements: 2, change: .8),
        ]),
        _AccountNode('113', 'المخزون', 'مدين', children: [
          _AccountNode('11301', 'مخزون المواد الغذائية', 'مدين', analytical: true, balance: 680000, movements: 142, change: 9.7),
          _AccountNode('11302', 'بضاعة بالطريق', 'مدين', analytical: true, balance: 45000, movements: 7, change: 3.1),
          _AccountNode('11303', 'مخزون لدى الغير', 'مدين', analytical: true, balance: 12000, movements: 3, change: -4),
        ]),
        _AccountNode('114', 'مدفوعات ومصروفات مقدمة', 'مدين', children: [
          _AccountNode('11401', 'إيجارات مقدمة', 'مدين', analytical: true, balance: 24000, movements: 2, change: -8),
          _AccountNode('11402', 'تأمينات لدى الغير', 'مدين', analytical: true, balance: 15000, movements: 1),
        ]),
      ]),
      _AccountNode('12', 'الأصول غير المتداولة', 'مدين', children: [
        _AccountNode('121', 'الأصول الثابتة بالتكلفة', 'مدين', children: [
          _AccountNode('12101', 'الأراضي والمباني', 'مدين', analytical: true, balance: 900000, movements: 1),
          _AccountNode('12102', 'السيارات ووسائل النقل', 'مدين', analytical: true, balance: 320000, movements: 6, change: 2),
          _AccountNode('12103', 'الأثاث والتجهيزات', 'مدين', analytical: true, balance: 85000, movements: 3),
          _AccountNode('12104', 'أجهزة الحاسب والبرامج', 'مدين', analytical: true, balance: 65000, movements: 4, change: 15),
        ]),
        _AccountNode('12201', 'مجمع إهلاك الأصول الثابتة', 'دائن', analytical: true, balance: -76000, movements: 12, change: 6),
      ]),
    ]),
    _AccountNode('2', 'الالتزامات', 'دائن', children: [
      _AccountNode('21', 'الالتزامات المتداولة', 'دائن', children: [
        _AccountNode('21101', 'موردو مواد غذائية محليون', 'دائن', analytical: true, balance: -390000, movements: 74, change: 4.8),
        _AccountNode('21102', 'أوراق دفع', 'دائن', analytical: true, balance: -28000, movements: 6, change: -3),
        _AccountNode('21201', 'رواتب وأجور مستحقة', 'دائن', analytical: true, balance: -42000, movements: 3, change: 2.5),
        _AccountNode('21301', 'ضريبة قيمة مضافة مستحقة', 'دائن', analytical: true, balance: -36000, movements: 8, change: 2.2),
      ]),
      _AccountNode('22', 'التزامات طويلة الأجل', 'دائن', children: [
        _AccountNode('22101', 'قروض وتسهيلات طويلة الأجل', 'دائن', analytical: true, balance: -150000, movements: 2, change: -5),
      ]),
    ]),
    _AccountNode('3', 'حقوق الملكية', 'دائن', children: [
      _AccountNode('3101', 'رأس المال المدفوع', 'دائن', analytical: true, balance: -1000000, movements: 1),
      _AccountNode('3102', 'جاري الشركاء', 'دائن', analytical: true, balance: -65000, movements: 9, change: 1),
      _AccountNode('3201', 'أرباح مرحلة', 'دائن', analytical: true, balance: -210000, movements: 1),
    ]),
    _AccountNode('4', 'الإيرادات', 'دائن', children: [
      _AccountNode('4101', 'مبيعات جملة', 'دائن', analytical: true, balance: -1450000, movements: 215, change: 11.5),
      _AccountNode('4102', 'مردودات ومسموحات المبيعات', 'مدين', analytical: true, balance: 32000, movements: 14, change: -2.4),
      _AccountNode('4103', 'خصم مسموح به', 'مدين', analytical: true, balance: 14000, movements: 11, change: 1.8),
      _AccountNode('4201', 'إيرادات خدمات وتوصيل', 'دائن', analytical: true, balance: -12000, movements: 7, change: 7),
    ]),
    _AccountNode('5', 'المصروفات والتكاليف', 'مدين', children: [
      _AccountNode('5101', 'تكلفة البضاعة المباعة', 'مدين', analytical: true, balance: 990000, movements: 187, change: 8.2),
      _AccountNode('5102', 'مشتريات', 'مدين', analytical: true, balance: 780000, movements: 102, change: 10.4),
      _AccountNode('5103', 'مردودات ومسموحات المشتريات', 'دائن', analytical: true, balance: -18000, movements: 8, change: -1.7),
      _AccountNode('5201', 'رواتب وأجور', 'مدين', analytical: true, balance: 95000, movements: 12, change: 4),
      _AccountNode('5202', 'إيجارات', 'مدين', analytical: true, balance: 48000, movements: 12),
      _AccountNode('5203', 'مرافق واتصالات', 'مدين', analytical: true, balance: 14500, movements: 12, change: 2.7),
      _AccountNode('5301', 'وقود وصيانة سيارات', 'مدين', analytical: true, balance: 37000, movements: 22, change: 6.8),
      _AccountNode('5302', 'عمولات مندوبي المبيعات', 'مدين', analytical: true, balance: 28000, movements: 10, change: 5.1),
    ]),
    _AccountNode('6', 'حسابات رقابية وإقفال', 'مدين', children: [
      _AccountNode('6101', 'بضاعة بالطريق - وسيط', 'مدين', analytical: true),
      _AccountNode('6102', 'حساب تسوية فروق المخزون', 'مدين', analytical: true),
      _AccountNode('6201', 'ملخص الدخل', 'مدين', analytical: true),
    ]),
  ];

  Widget _accountTree() {
    final query = _accountSearch.trim().toLowerCase();
    bool matches(_AccountNode n) => query.isEmpty || n.code.toLowerCase().contains(query) || n.name.toLowerCase().contains(query) || n.nature.toLowerCase().contains(query) || n.children.any(matches);
    final roots = _chartOfAccounts.where(matches).toList();
    final accountCount = _allAccountCodes(_chartOfAccounts).length;
    final analyticalCount = _countAnalyticalAccounts(_chartOfAccounts);
    final movementCount = _totalAccountMovements(_chartOfAccounts);
    final absoluteTotal = _totalAbsoluteAnalyticalBalance(_chartOfAccounts);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('دليل الحسابات الهرمي', style: TextStyle(color: _purple, fontSize: 22, fontWeight: FontWeight.w900))),
        TextButton.icon(onPressed: () { _accountSearchController.clear(); setState(() { _accountSearch = ''; _expandedAccounts.addAll(_allAccountCodes(_chartOfAccounts)); }); }, icon: const Icon(Icons.unfold_more), label: const Text('فرد الكل')),
        TextButton.icon(onPressed: () { _accountSearchController.clear(); setState(() { _accountSearch = ''; _expandedAccounts.clear(); }); }, icon: const Icon(Icons.unfold_less), label: const Text('طي الكل')),
      ]),
      const Text('هيكل حسابات مبدئي وفق التصنيف المحاسبي الشائع. الأرصدة وعدد الحركات ومعدلات التغير المعروضة بيانات توضيحية وليست أرصدة دفتر أستاذ فعلية.', style: TextStyle(height: 1.6, color: Colors.black54)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _summaryChip('إجمالي الحسابات', accountCount.toString(), _purple),
        _summaryChip('الحسابات التحليلية', analyticalCount.toString(), const Color(0xFF16834A)),
        _summaryChip('عدد الحركات التوضيحي', movementCount.toString(), _orange),
        _summaryChip('إجمالي القيم المطلقة', _money(absoluteTotal) + ' ج.م', _pink),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _accountSearchController, onChanged: (v) => setState(() { _accountSearch = v; if (v.trim().isNotEmpty) _expandedAccounts.addAll(_matchingAncestorCodes(_chartOfAccounts, v.trim().toLowerCase())); }), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث بكود الحساب أو اسمه أو طبيعته', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), 
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Container(constraints: const BoxConstraints(minWidth: 1000), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE7F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(color: _purple, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: const Row(children: [
          SizedBox(width: 340, child: Text('الحساب / الكود / الحسابات التابعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 145, child: Text('الرصيد (ج.م)', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 110, child: Text('عدد الحركات', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 105, child: Text('نسبة من الإجمالي', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 125, child: Text('مؤشر الحساب', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          SizedBox(width: 115, child: Text('معدل التغير', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
        ])),
        ...roots.expand((n) => _accountNodeRows(n, 0, query)),
      ]))),
      const SizedBox(height: 10),
      const Text('ربط الحسابات بالقيود والفواتير والخزائن والمخازن واعتماد القيود وترحيلها يحتاج استكمال طبقة الحفظ والصلاحيات وقاعدة البيانات؛ هذه الشاشة لا ترحّل أي حركة.', style: TextStyle(color: Colors.black54, height: 1.6)),
    ]);
  }

  Set<String> _allAccountCodes(List<_AccountNode> nodes) {
    final result = <String>{};
    for (final n in nodes) { result.add(n.code); result.addAll(_allAccountCodes(n.children)); }
    return result;
  }

  int _countAnalyticalAccounts(List<_AccountNode> nodes) => nodes.fold<int>(0, (sum, node) => sum + (node.analytical ? 1 : 0) + _countAnalyticalAccounts(node.children));

  int _totalAccountMovements(List<_AccountNode> nodes) => nodes.fold<int>(0, (sum, node) => sum + node.movements + _totalAccountMovements(node.children));

  double _totalAbsoluteAnalyticalBalance(List<_AccountNode> nodes) => nodes.fold<double>(0, (sum, node) => sum + (node.analytical ? node.balance.abs() : 0) + _totalAbsoluteAnalyticalBalance(node.children));

  double _displayAccountBalance(_AccountNode node) => node.analytical ? node.balance : node.balance + node.children.fold<double>(0, (sum, child) => sum + _displayAccountBalance(child));

  int _displayAccountMovements(_AccountNode node) => node.movements + node.children.fold<int>(0, (sum, child) => sum + _displayAccountMovements(child));

  int _descendantAccountCount(_AccountNode node) => node.children.fold<int>(0, (sum, child) => sum + 1 + _descendantAccountCount(child));

  Set<String> _matchingAncestorCodes(List<_AccountNode> nodes, String query) {
    final result = <String>{};
    for (final node in nodes) {
      final childMatches = _matchingAncestorCodes(node.children, query);
      final selfMatches = node.code.toLowerCase().contains(query) || node.name.toLowerCase().contains(query) || node.nature.toLowerCase().contains(query);
      if (childMatches.isNotEmpty || selfMatches) {
        if (node.children.isNotEmpty && childMatches.isNotEmpty) result.add(node.code);
        result.addAll(childMatches);
      }
    }
    return result;
  }

  List<Widget> _accountNodeRows(_AccountNode node, int depth, String query) {
    final hasChildren = node.children.isNotEmpty;
    final children = node.children.where((child) => query.isEmpty || _accountNodeHasMatch(child, query)).toList();
    final expanded = _expandedAccounts.contains(node.code);
    final balance = _displayAccountBalance(node);
    final movements = _displayAccountMovements(node);
    final share = _totalAbsoluteAnalyticalBalance(_chartOfAccounts) == 0 ? 0.0 : balance.abs() / _totalAbsoluteAnalyticalBalance(_chartOfAccounts) * 100;
    final color = node.change > 0 ? const Color(0xFF18865A) : node.change < 0 ? const Color(0xFFD32F2F) : Colors.grey;
    final row = Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0ECF4)))), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(children: [
      SizedBox(width: 340, child: Row(children: [
        SizedBox(width: depth * 20.0),
        if (hasChildren) IconButton(visualDensity: VisualDensity.compact, tooltip: expanded ? 'طي الحسابات التابعة' : 'فرد الحسابات التابعة', onPressed: () => setState(() { if (expanded) { _expandedAccounts.remove(node.code); } else { _expandedAccounts.add(node.code); } }), icon: Icon(expanded ? Icons.remove_circle_outline : Icons.add_circle_outline, color: _purple, size: 20)) else const SizedBox(width: 36),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(node.name, style: TextStyle(fontWeight: hasChildren ? FontWeight.w900 : FontWeight.w600, color: hasChildren ? _purple : Colors.black87)),
          Text(node.code + ' • ' + node.nature + ' • ' + _descendantAccountCount(node).toString() + ' حساب تابع', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
      ])),
      SizedBox(width: 145, child: Text(_money(balance), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
      SizedBox(width: 110, child: Text(movements.toString(), textAlign: TextAlign.end)),
      SizedBox(width: 105, child: Text(share.toStringAsFixed(2) + '%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, color: _purple))),
      SizedBox(width: 125, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: node.analytical ? const Color(0xFFE8F5E9) : const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(20)), child: Text(node.analytical ? 'تحليلي' : 'تجميعي', style: TextStyle(color: node.analytical ? const Color(0xFF18865A) : _purple, fontWeight: FontWeight.w800, fontSize: 11))))),
      SizedBox(width: 115, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(node.change > 0 ? Icons.trending_up : node.change < 0 ? Icons.trending_down : Icons.trending_flat, color: color, size: 17), const SizedBox(width: 3), Text((node.change > 0 ? '+' : '') + node.change.toStringAsFixed(1) + '%', style: TextStyle(color: color, fontWeight: FontWeight.w800))])),
    ]));
    return [row, if (hasChildren && expanded) ...children.expand((child) => _accountNodeRows(child, depth + 1, query))];
  }

  bool _accountNodeHasMatch(_AccountNode node, String query) => node.code.toLowerCase().contains(query) || node.name.toLowerCase().contains(query) || node.nature.toLowerCase().contains(query) || node.children.any((child) => _accountNodeHasMatch(child, query));

  String _money(double value) {
    final parts = value.abs().toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (m) => ',');
    return (value < 0 ? '-' : '') + whole + '.' + parts[1];
  }
  String _auditPeriod = 'من بداية النظام حتى تاريخه';
  String _auditStart = '2026-01-01';
  String _auditEnd = '2026-10-17';
  String _auditModule = 'كل الحركات';
  final Set<String> _auditChecked = {};
  final Map<String, bool> _permissionDraft = {};
  String _permissionRole = 'مدير النظام';
  String _pricingMode = 'نسبة';
  String _pricingDirection = 'زيادة';
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _priceLimitController = TextEditingController();
  final TextEditingController _priceValueController = TextEditingController();
  final TextEditingController _invoiceDiscountController = TextEditingController();
  final TextEditingController _itemDiscountController = TextEditingController();
  String _restrictionTarget = 'الصنف';
  String _restrictionAction = 'إيقاف البيع';
  final TextEditingController _restrictionItem = TextEditingController();
  final TextEditingController _restrictionCustomer = TextEditingController();
  final TextEditingController _restrictionDelegate = TextEditingController();
  final Set<String> _allocatedItems = {};
  final Set<String> _approvedJournals = {};

  Widget _movementAuditScreen() {
    const areas = ['كل الحركات','العملاء','الموردون','المخازن','الأصناف','البنوك','الخزائن','الموظفون','القيود المحاسبية','المبيعات','المشتريات','المردودات','التحويلات'];
    final startDate = DateTime.tryParse(_auditPeriod == 'شهر محدد' && _auditStart.length == 7 ? '$_auditStart-01' : _auditStart);
    final endDate = DateTime.tryParse(_auditPeriod == 'شهر محدد' && _auditStart.length == 7 ? '${_auditStart}-31' : _auditEnd);
    final rows = _auditSampleRows.where((r) {
      if (_auditModule != 'كل الحركات' && r['area'] != _auditModule) return false;
      final date = DateTime.tryParse(r['date'] ?? '');
      if (_auditPeriod == 'من بداية النظام حتى تاريخه') return true;
      if (date == null || startDate == null) return false;
      if (_auditPeriod == 'شهر محدد') {
        return (r['date'] ?? '').startsWith(_auditStart);
      }
      return !date.isBefore(DateTime(startDate.year, startDate.month, startDate.day)) &&
          (endDate == null || !date.isAfter(DateTime(endDate.year, endDate.month, endDate.day)));
    }).toList();
    final issueCount = rows.where((r) => r['issue'] != 'سليم').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _screenHeading('اختبار ومراجعة الحركات', 'فحص تجميعي حسب المجال والفترة، وعرض تقرير بالملاحظات مع إجراء ضبط لكل مستند'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE7F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: 250, child: DropdownButtonFormField<String>(
              value: _auditPeriod,
              decoration: const InputDecoration(labelText: 'نطاق الفحص', border: OutlineInputBorder()),
              items: const ['من بداية النظام حتى تاريخه','شهر محدد','من تاريخ إلى تاريخ'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged:(v)=>setState(()=>_auditPeriod=v ?? _auditPeriod),
            )),
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              value: _auditModule,
              decoration: const InputDecoration(labelText: 'تجميع الحركات حسب', border: OutlineInputBorder()),
              items: areas.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged:(v)=>setState(()=>_auditModule=v ?? _auditModule),
            )),
            if (_auditPeriod != 'من بداية النظام حتى تاريخه')
              SizedBox(width: 190, child: TextFormField(
                key: ValueKey('audit-start-$_auditPeriod'),
                initialValue: _auditStart,
                decoration: InputDecoration(labelText: _auditPeriod == 'شهر محدد' ? 'الشهر (YYYY-MM)' : 'من تاريخ (YYYY-MM-DD)', border: const OutlineInputBorder(), hintText: _auditPeriod == 'شهر محدد' ? '2026-10' : '2026-10-01'),
                onChanged:(v)=>_auditStart=v.trim(),
              )),
            if (_auditPeriod == 'من تاريخ إلى تاريخ')
              SizedBox(width: 190, child: TextFormField(
                key: ValueKey('audit-end-$_auditPeriod'),
                initialValue: _auditEnd,
                decoration: const InputDecoration(labelText:'إلى تاريخ (YYYY-MM-DD)', border:OutlineInputBorder(), hintText:'2026-10-31'),
                onChanged:(v)=>_auditEnd=v.trim(),
              )),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => setState(() {
                _auditChecked.clear();
                _activityLog.insert(0, 'تم تشغيل عرض مراجعة الحركات للفترة: $_auditPeriod، المجال: $_auditModule');
              }),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('فحص وعرض التقرير'),
              style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _auditPeriod = 'من بداية النظام حتى تاريخه';
                _auditModule = 'كل الحركات';
                _auditStart = '2026-10';
                _auditEnd = '2026-10-17';
                _auditChecked.clear();
              }),
              icon: const Icon(Icons.restart_alt),
              label: const Text('إعادة ضبط الفلاتر'),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      _notice(Icons.info_outline, 'مصدر البيانات', 'هذه الشاشة تعرض عينة واجهة فقط حاليًا؛ لم تُربط بعد بجداول الحركات الفعلية. لذلك لا تعتبر نتائجها تدقيقًا محاسبيًا فعليًا ولا تعدّل المستند الأصلي. الفحص الفعلي يحتاج ربط مصادر الحركات وقواعد التحقق بالخادم.', _orange),
      const SizedBox(height: 12),
      Wrap(spacing:8,runSpacing:8,children:[
        _summaryChip('الحركات بالتقرير',rows.length.toString(),_purple),
        _summaryChip('ملاحظات تحتاج مراجعة',issueCount.toString(),_orange),
        _summaryChip('تمت مراجعتها يدويًا',_auditChecked.where((doc)=>rows.any((r)=>r['doc']==doc)).length.toString(),const Color(0xFF18865A)),
      ]),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد حركات ضمن الفلاتر المختارة في العينة الحالية.', textAlign: TextAlign.center)))
      else
        ...rows.map((r) {
          final isOkay = r['issue'] == 'سليم';
          final reviewed = _auditChecked.contains(r['doc']);
          return Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Row(children:[
                  Expanded(child:Text('${r['area']} • ${r['name']}',style:const TextStyle(fontWeight:FontWeight.w900,color:_purple))),
                  Text('${r['date']}',style:const TextStyle(fontSize:12)),
                ]),
                const SizedBox(height:6),
                Text('المستند: ${r['doc']} • القيمة: ${r['value']} ج.م'),
                const SizedBox(height:7),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color:(isOkay?const Color(0xFF18865A):const Color(0xFFD32F2F)).withOpacity(.08),borderRadius:BorderRadius.circular(9)),
                  child: Text('نتيجة الفحص: ${r['issue']}',style:TextStyle(color:isOkay?const Color(0xFF18865A):const Color(0xFFD32F2F),fontWeight:FontWeight.w800)),
                ),
                const SizedBox(height:8),
                Wrap(spacing:8,runSpacing:8,children:[
                  OutlinedButton.icon(
                    onPressed:()=>_showAuditFix(r),
                    icon:const Icon(Icons.build_circle_outlined),
                    label:const Text('ضبط الحركة'),
                  ),
                  OutlinedButton.icon(
                    onPressed:()=>setState(()=>reviewed?_auditChecked.remove(r['doc']):_auditChecked.add(r['doc']!)),
                    icon:Icon(reviewed?Icons.check_circle:Icons.check_circle_outline),
                    label:Text(reviewed?'إلغاء المراجعة':'تمت المراجعة'),
                  ),
                ]),
              ]),
            ),
          );
        }),
      const SizedBox(height: 8),
      const Text('مجالات الفحص: العملاء، الموردون، المخازن، الأصناف، البنوك، الخزائن، الموظفون، القيود المحاسبية، المبيعات، المشتريات، المردودات والتحويلات.',style:TextStyle(color:Colors.black54,height:1.6)),
    ]);
  }

  static const List<Map<String,String>> _auditSampleRows = [
    {'area':'العملاء','name':'فاتورة عميل','date':'2026-10-15','doc':'SAL-1042','value':'12500','issue':'حساب العميل غير محدد'},
    {'area':'الموردون','name':'فاتورة مورد','date':'2026-10-14','doc':'PUR-209','value':'8400','issue':'سليم'},
    {'area':'المخازن','name':'صرف مخزني','date':'2026-10-12','doc':'INV-077','value':'3100','issue':'كمية الصرف أكبر من المتاح'},
    {'area':'البنوك','name':'إيداع بنكي','date':'2026-10-11','doc':'BNK-031','value':'5000','issue':'مرجع البنك غير موجود'},
    {'area':'الخزائن','name':'أمر صرف','date':'2026-10-10','doc':'CSH-014','value':'2200','issue':'سليم'},
    {'area':'الموظفون','name':'عهدة مندوب','date':'2026-10-09','doc':'EMP-008','value':'1500','issue':'مركز التكلفة غير محدد'},
    {'area':'القيود المحاسبية','name':'قيد يومية','date':'2026-10-08','doc':'JV-301','value':'18000','issue':'القيد غير متوازن'},
    {'area':'المبيعات','name':'فاتورة مبيعات','date':'2026-10-07','doc':'SAL-1038','value':'7600','issue':'سليم'},
    {'area':'المشتريات','name':'فاتورة مشتريات','date':'2026-10-06','doc':'PUR-201','value':'9200','issue':'ضريبة غير محددة'},
    {'area':'المردودات','name':'مرتجع مبيعات','date':'2026-10-05','doc':'RET-015','value':'800','issue':'المستند الأصلي غير مربوط'},
    {'area':'التحويلات','name':'تحويل مخزني','date':'2026-10-04','doc':'TRF-026','value':'4200','issue':'مخزن الوجهة غير محدد'},
    {'area':'الأصناف','name':'حركة صنف','date':'2026-10-03','doc':'ITM-422','value':'0','issue':'سليم'},
  ];

  void _showAuditFix(Map<String,String> row) {
    final controller=TextEditingController(text:row['issue']);
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('ضبط الحركة ${row['doc']}'),content:TextField(controller:controller,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظة الضبط المقترح',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){setState(()=>_activityLog.insert(0,'مراجعة ${row['doc']}: ${controller.text}'));Navigator.pop(ctx);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('سُجلت ملاحظة المراجعة محليًا؛ لم يتم تعديل المستند الأصلي.')));},child:const Text('تسجيل الملاحظة'))]));
  }

  Widget _permissionsScreen() {
    const roles=['مدير النظام','مدير مالي','مدير مخازن','موظف مبيعات','موظف مشتريات','أمين خزينة','مندوب مبيعات','مندوب تسليم','مراجع'];
    const rights=['عرض','إضافة','تعديل','حذف','اعتماد','عكس الحركة','ترحيل','تصدير','طباعة','تخطي ربط المستند الأصلي','تخطي التحضير'];
    const scopes=['بيانات أساسية','الحسابات المالية','المخازن والفروع','المبيعات والعملاء','المشتريات والموردون','الموارد البشرية','إدارة البرنامج','سياسات التسعير','توزيع الأصناف','قيود البيع والشراء'];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('المستخدمون والصلاحيات','تحديد الصلاحيات حسب نوع المستخدم والدور الوظيفي'),
      Wrap(spacing:10,children:[SizedBox(width:260,child:DropdownButtonFormField<String>(value:_permissionRole,decoration:const InputDecoration(labelText:'تصنيف المستخدم / الدور',border:OutlineInputBorder()),items:roles.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_permissionRole=v??_permissionRole)),),FilledButton.icon(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مسودة الصلاحيات محلية فقط؛ يلزم حفظها بالخادم مع تطبيق RLS.'))),icon:const Icon(Icons.save),label:const Text('حفظ المسودة'))]),
      const SizedBox(height:12),
      const Text('ضع علامة صح لمنح الصلاحية وأزلها لمنعها. لا تطبق هذه الاختيارات حماية فعلية قبل ربطها بهوية المستخدم والخادم وسياسات قاعدة البيانات.',style:TextStyle(color:Colors.black54,height:1.6)),
      const SizedBox(height:8),
      ...scopes.map((scope)=>Card(child:ExpansionTile(title:Text(scope,style:const TextStyle(fontWeight:FontWeight.w800,color:_purple)),children:[Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:12,runSpacing:4,children:rights.map((right){final key='$_permissionRole::$scope::$right';final enabled=_permissionDraft[key]??(_permissionRole=='مدير النظام'&&right!='عكس الحركة');return SizedBox(width:145,child:CheckboxListTile(dense:true,contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setState(()=>_permissionDraft[key]=v??false),title:Text(right,style:const TextStyle(fontSize:12))));}).toList()))]))),
    ]);
  }

  Widget _pricingPolicyScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('سياسات التسعير والخصومات','حد تسعير الصنف والزيادة أو النقصان وحدود خصم الصنف والفاتورة'),
      Wrap(spacing:12,runSpacing:12,children:[_fieldBox('سعر الصنف الأساسي',_basePriceController),_fieldBox('حد التسعير المعتمد',_priceLimitController),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_pricingMode,decoration:const InputDecoration(labelText:'طريقة التعديل',border:OutlineInputBorder()),items:const ['نسبة','قيمة'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingMode=v??_pricingMode))),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_pricingDirection,decoration:const InputDecoration(labelText:'الاتجاه من حد التسعير',border:OutlineInputBorder()),items:const ['زيادة','نقصان'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_pricingDirection=v??_pricingDirection)),),_fieldBox(_pricingMode=='نسبة'?'نسبة الزيادة / النقصان %':'قيمة الزيادة / النقصان',_priceValueController),_fieldBox('أقصى خصم على إجمالي الفاتورة %',_invoiceDiscountController),_fieldBox('أقصى خصم على مستوى الصنف %',_itemDiscountController)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إعداد حقول السياسة في الواجهة فقط؛ لم تُحفظ السياسة على الخادم بعد.'))),icon:const Icon(Icons.save),label:const Text('حفظ مسودة السياسة')),
      const SizedBox(height:8),
      const Text('يجب أن يُحسب السعر النهائي من حد التسعير المسجل للصنف، مع منع تجاوز صلاحية المستخدم وحدود الخصم. يلزم ربط الحقول ببيانات الأصناف وقاعدة البيانات قبل تطبيقها على الفواتير.',style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _delegateAllocationScreen() {
    const delegates=['مندوب مبيعات 01','مندوب مبيعات 02','مندوب مبيعات 03','مندوب مبيعات 04'];
    const items=['زيت طعام 1 لتر','أرز 1 كجم','سكر 1 كجم','مكرونة 400 جم','سمن نباتي','شاي','جبن أبيض','منظفات'];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('توزيع الأصناف على المندوبين','تخصيص الأصناف المهمة التي يُسمح لكل مندوب ببيعها'),
      const Text('اختيار الصنف والمندوب أدناه تجريبي حتى ربط دليل الأصناف والمندوبين الفعلي.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:10),
      ...delegates.map((delegate)=>Card(child:ExpansionTile(title:Text(delegate,style:const TextStyle(fontWeight:FontWeight.w800,color:_purple)),children:items.map((item){final key='$delegate::$item';return CheckboxListTile(value:_allocatedItems.contains(key),onChanged:(v)=>setState(()=>v==true?_allocatedItems.add(key):_allocatedItems.remove(key)),title:Text(item),subtitle:const Text('السماح ببيع الصنف المهم لهذا المندوب'));}).toList()))),
      FilledButton.icon(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('توزيع الأصناف مسودة محلية ولم يُحفظ بالخادم.'))),icon:const Icon(Icons.save),label:const Text('حفظ التوزيع'))]);
  }

  Widget _transactionRestrictionsScreen() {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قيود البيع والشراء','إيقاف البيع أو الشراء أو تحديد الحد حسب الصنف أو الفاتورة أو العميل أو المندوب'),
      Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:220,child:DropdownButtonFormField<String>(value:_restrictionAction,decoration:const InputDecoration(labelText:'الإجراء',border:OutlineInputBorder()),items:const ['إيقاف البيع','إيقاف الشراء','تحديد حد البيع'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionAction=v??_restrictionAction))),SizedBox(width:220,child:DropdownButtonFormField<String>(value:_restrictionTarget,decoration:const InputDecoration(labelText:'مستوى تطبيق القيد',border:OutlineInputBorder()),items:const ['الصنف','الفاتورة الواحدة','العميل','المندوب'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>_restrictionTarget=v??_restrictionTarget))),_fieldBox('كود الصنف / الفاتورة / العميل / المندوب',_restrictionItem),_fieldBox('العميل (اختياري)',_restrictionCustomer),_fieldBox('المندوب (اختياري)',_restrictionDelegate)]),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('إضافة قيد'),content:Text('الإجراء: $_restrictionAction • المستوى: $_restrictionTarget • المعرف: ${_restrictionItem.text}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),FilledButton(onPressed:(){setState(()=>_activityLog.insert(0,'مسودة قيد: $_restrictionAction / $_restrictionTarget / ${_restrictionItem.text}'));Navigator.pop(ctx);},child:const Text('حفظ المسودة'))])),icon:const Icon(Icons.block),label:const Text('إضافة قيد / إيقاف')),
      const SizedBox(height:8),
      const Text('هذه مسودة واجهة؛ منع البيع أو الشراء الفعلي يجب أن يُطبق أيضًا في منطق حفظ الفاتورة والخادم، وليس في الشاشة وحدها.',style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _journalApprovalScreen() {
    const journals=[('JV-301','قيد مشتريات','2026-10-08','18,000','غير متوازن'),('JV-302','قيد مبيعات','2026-10-09','7,600','بانتظار الاعتماد'),('JV-303','قيد خزينة','2026-10-10','2,200','بانتظار الاعتماد')];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_screenHeading('قائمة اعتماد القيود','مراجعة القيود قبل اعتمادها أو إعادتها للتعديل أو تسجيل طلب عكس'),
      const Text('القيود أدناه أمثلة للواجهة فقط، ولا تمثل قيودًا محفوظة في دفتر الأستاذ.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:10),
      ...journals.map((j)=>Card(child:ListTile(title:Text('${j.$1} • ${j.$2}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${j.$3} • ${j.$4} ج.م • ${j.$5}'),trailing:Wrap(spacing:3,children:[IconButton(tooltip:'اعتماد',onPressed:()=>setState(()=>_approvedJournals.add(j.$1)),icon:const Icon(Icons.check_circle_outline,color:Color(0xFF18865A))),IconButton(tooltip:'إعادة للتعديل',onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم تسجيل طلب إعادة ${j.$1} للمراجعة محليًا.'))),icon:const Icon(Icons.edit_outlined,color:_orange)),IconButton(tooltip:'طلب عكس',onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم تسجيل طلب عكس ${j.$1} محليًا؛ لم يُعكس القيد.'))),icon:const Icon(Icons.undo,color:_pink))]),leading:Icon(_approvedJournals.contains(j.$1)?Icons.verified:Icons.pending_actions,color:_approvedJournals.contains(j.$1)?const Color(0xFF18865A):_orange)))),
      const SizedBox(height:8),
      const Text('زر الاعتماد في هذه المرحلة يسجل اختيارًا داخل الجلسة فقط؛ الترحيل المالي الحقيقي يتطلب التحقق من توازن القيد وصلاحية المستخدم وحالة الفترة المالية.',style:TextStyle(color:Colors.black54,height:1.6))]);
  }

  Widget _screenHeading(String title,String subtitle)=>Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_purple,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:Colors.black54,height:1.5))]));
  Widget _summaryChip(String label,String value,Color color)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:color.withOpacity(.09),borderRadius:BorderRadius.circular(10)),child:Text('$label: $value',style:TextStyle(color:color,fontWeight:FontWeight.w800)));
  Widget _fieldBox(String label,TextEditingController controller)=>SizedBox(width:220,child:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

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

class _AccountNode {
  const _AccountNode(this.code, this.name, this.nature, {this.children = const [], this.analytical = false, this.balance = 0, this.movements = 0, this.change = 0});
  final String code, name, nature;
  final List<_AccountNode> children;
  final bool analytical;
  final double balance, change;
  final int movements;
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
