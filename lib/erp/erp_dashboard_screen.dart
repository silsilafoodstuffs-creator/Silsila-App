import 'package:flutter/material.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);
const _pink = Color(0xFFFF27C3);
const _canvas = Color(0xFFF7F5FA);

const Map<String, Map<String, List<String>>> _modules = {
  'إدارة البرنامج': {
    'بيانات أساسية': ['بيانات الشركة', 'الفروع ومراكز التكلفة', 'المستخدمون والصلاحيات', 'إعدادات النظام', 'سجل العمليات'],
    'حركات': ['إدارة الجلسات', 'سجل الدخول والخروج', 'النسخ الاحتياطي'],
    'تقارير': ['تقرير المستخدمين', 'تقرير نشاط النظام'],
  },
  'الحسابات العامة': {
    'بيانات أساسية': ['شجرة الحسابات', 'الفترات المالية', 'مراكز التكلفة', 'العملات'],
    'حركات': ['قيود اليومية', 'سندات القبض', 'سندات الصرف', 'تسويات الحسابات', 'إقفال الفترة'],
    'تقارير': ['ميزان المراجعة', 'الأستاذ العام', 'قائمة الدخل', 'الميزانية العمومية', 'حركة حساب'],
  },
  'الخزائن والبنوك': {
    'بيانات أساسية': ['الخزائن الرئيسية والفرعية', 'الحسابات البنكية', 'طرق الدفع'],
    'حركات': ['تحويل بين الخزائن', 'إيداع بنكي', 'سحب بنكي', 'مطابقة البنك'],
    'تقارير': ['أرصدة الخزائن', 'كشف حساب خزينة', 'كشف حساب بنك'],
  },
  'المخازن والمخزون': {
    'بيانات أساسية': ['دليل المخازن', 'مجموعات الأصناف', 'دليل الأصناف', 'الوحدات والتحويلات', 'الباركود', 'حدود إعادة الطلب'],
    'حركات': ['إذن إضافة', 'إذن صرف', 'تحويل مخزني', 'تسوية جرد', 'جرد فعلي', 'تسوية صلاحية وهالك'],
    'تقارير': ['أرصدة الأصناف', 'كارت الصنف', 'الجرد والفروق', 'الأصناف الراكدة', 'الأصناف قاربت على النفاد', 'تواريخ الصلاحية'],
  },
  'المشتريات': {
    'بيانات أساسية': ['سياسات الشراء', 'قوائم أسعار الموردين'],
    'حركات': ['طلب شراء', 'أمر شراء', 'استلام مشتريات', 'فاتورة مشتريات', 'مرتجع مشتريات'],
    'تقارير': ['تحليل المشتريات', 'مقارنة أسعار الموردين', 'أعمار ديون الموردين'],
  },
  'المبيعات والتوزيع': {
    'بيانات أساسية': ['قوائم أسعار البيع', 'سياسات الخصم', 'مناطق التوزيع', 'خطوط السير'],
    'حركات': ['عرض سعر', 'أمر بيع', 'فاتورة مبيعات', 'مرتجع مبيعات', 'إذن تحميل', 'تسليم طلب'],
    'تقارير': ['المبيعات اليومية', 'ربحية المبيعات', 'مبيعات حسب الفرع', 'أداء المندوبين', 'الطلبات المتأخرة'],
  },
  'الموردون': {
    'بيانات أساسية': ['دليل الموردين', 'تصنيفات الموردين', 'جهات الاتصال', 'شروط التوريد'],
    'حركات': ['كشف حساب مورد', 'تقييم مورد', 'مطابقة أرصدة', 'تسجيل مديونية'],
    'تقارير': ['أرصدة الموردين', 'أداء الموردين', 'الموردون حسب النشاط'],
  },
  'العملاء والتجار': {
    'بيانات أساسية': ['دليل العملاء', 'تصنيفات العملاء', 'فروع العملاء', 'حدود الائتمان', 'مناطق العملاء'],
    'حركات': ['كشف حساب عميل', 'تحصيلات العملاء', 'متابعة المديونيات', 'طلبات العملاء'],
    'تقارير': ['أرصدة العملاء', 'أعمار الديون', 'أفضل العملاء', 'العملاء المتوقفون'],
  },
  'الموارد البشرية': {
    'بيانات أساسية': ['هيكل الشركة', 'الإدارات والأقسام', 'الوظائف والدرجات', 'ملف الموظف', 'العقود', 'أنواع الإجازات'],
    'حركات': ['الحضور والانصراف', 'الإجازات والأذونات', 'الجزاءات والمكافآت', 'السلف', 'تقييم الأداء'],
    'تقارير': ['كشف العاملين', 'الحضور والغياب', 'رصيد الإجازات', 'انتهاء العقود'],
  },
  'الرواتب والأجور': {
    'بيانات أساسية': ['مكونات الراتب', 'الاستحقاقات والاستقطاعات', 'سياسات العمولة'],
    'حركات': ['مسير الرواتب', 'صرف الرواتب', 'عمولات المبيعات', 'تسوية سلفة'],
    'تقارير': ['ملخص الرواتب', 'مفردات المرتب', 'عمولات المندوبين'],
  },
  'الفروع ومراكز التوزيع': {
    'بيانات أساسية': ['دليل الفروع', 'المخازن التابعة', 'مراكز التكلفة', 'المناطق الجغرافية'],
    'حركات': ['تحويلات بين الفروع', 'تسويات الفروع', 'توزيع المصروفات'],
    'تقارير': ['أداء الفروع', 'أرباح وخسائر الفروع', 'حركة التحويلات'],
  },
  'المندوبون والتحصيل': {
    'بيانات أساسية': ['دليل المندوبين', 'مركبات التوزيع', 'خطوط السير'],
    'حركات': ['تسليم عهدة', 'تصفية عهدة', 'تحصيل نقدي', 'مصروفات رحلة'],
    'تقارير': ['تصفية المندوبين', 'تحصيلات يومية', 'تكلفة خطوط السير'],
  },
  'العروض والتسويق': {
    'بيانات أساسية': ['الحملات التسويقية', 'قواعد العروض', 'شرائح العملاء'],
    'حركات': ['إنشاء عرض', 'اعتماد حملة', 'تسجيل كوبون'],
    'تقارير': ['أداء العروض', 'تكلفة الحملات', 'معدل الاستجابة'],
  },
  'خدمة العملاء والدعم': {
    'بيانات أساسية': ['أنواع الطلبات', 'قنوات التواصل', 'أسباب الشكاوى'],
    'حركات': ['تذكرة دعم جديدة', 'متابعة شكوى', 'تسجيل اقتراح'],
    'تقارير': ['التذاكر المفتوحة', 'زمن الاستجابة', 'رضا العملاء'],
  },
  'التقارير والتحليلات': {
    'بيانات أساسية': ['لوحات المؤشرات', 'قوالب التقارير'],
    'حركات': ['تحديث مؤشرات الأداء', 'تصدير البيانات'],
    'تقارير': ['مؤشرات الأداء الرئيسية', 'التدفقات النقدية', 'تحليل الربحية', 'حركة المبيعات والمخزون', 'ملخص تنفيذي'],
  },
};

class ErpDashboardScreen extends StatefulWidget {
  const ErpDashboardScreen({super.key});
  @override
  State<ErpDashboardScreen> createState() => _ErpDashboardScreenState();
}

class _ErpDashboardScreenState extends State<ErpDashboardScreen> {
  String _module = 'إدارة البرنامج';
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
    if (page.contains('الأصناف') || page == 'دليل الأصناف') {
      return [
        {'الكود': 'SKU-001', 'الاسم': 'زيت عباد الشمس', 'المجموعة': 'زيوت', 'الوحدة': 'كرتونة', 'المخزون': '120', 'الحالة': 'نشط'},
        {'الكود': 'SKU-002', 'الاسم': 'مكرونة 400 جم', 'المجموعة': 'مكرونات', 'الوحدة': 'كرتونة', 'المخزون': '85', 'الحالة': 'نشط'},
        {'الكود': 'SKU-003', 'الاسم': 'سمن نباتي', 'المجموعة': 'سمنات', 'الوحدة': 'كرتونة', 'المخزون': '42', 'الحالة': 'نشط'},
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
          Expanded(child: Column(children: [
            _header(compact),
            Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(compact ? 14 : 26), child: _module == 'إدارة البرنامج' && _page == 'بيانات الشركة' ? _home() : _workspace())),
          ])),
        ]),
      );
    }));
  }

  Widget _sidebar() => Container(color: _purple, child: SafeArea(child: Column(children: [
    const Padding(padding: EdgeInsets.all(20), child: Row(children: [
      CircleAvatar(backgroundColor: Colors.white, radius: 24, child: Icon(Icons.hub_rounded, color: _purple, size: 30)),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('سلسلة Silsila', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
        SizedBox(height: 4),
        Text('ERP • إدارة موارد المؤسسة', style: TextStyle(color: Colors.white70, fontSize: 11)),
      ])),
    ])),
    const Divider(color: Colors.white24, height: 1),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 10), children: _modules.keys.map((name) {
      final selected = name == _module;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2), child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: Colors.white.withValues(alpha: .14),
        leading: Icon(_iconFor(name), color: selected ? _orange : Colors.white70, size: 21),
        title: Text(name, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        trailing: Icon(selected ? Icons.keyboard_arrow_down_rounded : Icons.chevron_left_rounded, color: Colors.white60, size: 18),
        onTap: () => setState(() { _module = name; _group = 'بيانات أساسية'; _page = _modules[name]![_group]!.first; _search = ''; }),
      ));
    }).toList())),
    const Divider(color: Colors.white24, height: 1),
    const Padding(padding: EdgeInsets.all(14), child: Column(children: [
      Text('سلسلة للبرمجيات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
      Text('بنربط السوق ببعضه', style: TextStyle(color: _orange, fontSize: 12)),
    ])),
  ])));

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
      _quick('شجرة الحسابات', Icons.account_tree_rounded, () => _open('الحسابات العامة', 'بيانات أساسية', 'شجرة الحسابات')),
      _quick('الخزائن', Icons.account_balance_wallet_rounded, () => _open('الخزائن والبنوك', 'بيانات أساسية', 'الخزائن الرئيسية والفرعية')),
      _quick('دليل الأصناف', Icons.inventory_2_rounded, () => _open('المخازن والمخزون', 'بيانات أساسية', 'دليل الأصناف')),
      _quick('دليل العملاء', Icons.groups_rounded, () => _open('العملاء والتجار', 'بيانات أساسية', 'دليل العملاء')),
      _quick('ملف الموظف', Icons.badge_rounded, () => _open('الموارد البشرية', 'بيانات أساسية', 'ملف الموظف')),
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
