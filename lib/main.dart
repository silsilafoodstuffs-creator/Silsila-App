import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'auth/forgot_password_screen.dart';

const purple = Color(0xFF3E007D);
const orange = Color(0xFFFFA015);
const pink = Color(0xFFFF27C3);
const palePurple = Color(0xFFF5EFFB);
const ink = Color(0xFF241735);
const canvas = Color(0xFFFAF8FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://teitsopmhruczplwlwgn.supabase.co',
    publishableKey: 'sb_publishable_y6pDeQ9rLq680rS7qqirPQ_LAo5ZcTu',
  );

  runApp(const SilsilaApp());
}

class SilsilaApp extends StatelessWidget {
  const SilsilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سلسلة Silsila',
      theme: SilsilaTheme.light.copyWith(
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          primary: purple,
          secondary: orange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const SilsilaSplashScreen(),
    );
  }
}

// ============================================================
// صفحة البداية
// ============================================================

class SilsilaWelcomeScreen extends StatefulWidget {
  const SilsilaWelcomeScreen({super.key});

  @override
  State<SilsilaWelcomeScreen> createState() =>
      _SilsilaWelcomeScreenState();
}

class _SilsilaWelcomeScreenState extends State<SilsilaWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> arrowAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    arrowAnimation = Tween<double>(
      begin: 0,
      end: 9,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: purple,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -90,
            child: _glowCircle(270, pink.withValues(alpha: 0.16)),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _glowCircle(310, orange.withValues(alpha: 0.15)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 35,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: purple,
                        size: 78,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'سلسلة Silsila',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'بنربط السوق ببعضه',
                      style: TextStyle(
                        color: orange,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'تجارتك اليومية تبدأ من هنا',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 60),
                    SizedBox(
                      width: 235,
                      height: 58,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: orange,
                          foregroundColor: purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Directionality(
                                textDirection: TextDirection.rtl,
                                child: SilsilaLoginScreen(),
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'ابدأ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedBuilder(
                              animation: arrowAnimation,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, arrowAnimation.value),
                                child: child,
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'من المورد إلى تاجر التجزئة',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ============================================================
// الواجهة الرئيسية المطوّرة
// ============================================================

class SilsilaHome extends StatefulWidget {
  const SilsilaHome({super.key});

  @override
  State<SilsilaHome> createState() => _SilsilaHomeState();
}

class _SilsilaHomeState extends State<SilsilaHome> {
  int page = 1;
  int tab = 0;
  int bannerIndex = 0;
  String displayName = 'تاجر سلسلة';
  String accountTypeLabel = 'عميل';
  bool profileLoaded = false;

  final search = TextEditingController();
  final bannerController = PageController();
  final Set<String> favorites = {};
  final List<String> cart = [];

  final List<Map<String, String>> banners = [
    {
      'tag': 'عروض سلسلة',
      'title': 'وفّر في مشترياتك',
      'subtitle': 'اكتشف فرص شراء مميزة لتجارتك',
      'icon': 'local_offer',
    },
    {
      'tag': 'سوق التجار',
      'title': 'كل السوق في مكان واحد',
      'subtitle': 'اكتشف الموردين والأصناف بسهولة',
      'icon': 'storefront',
    },
    {
      'tag': 'اختياراتنا',
      'title': 'احتياجات محلك أقرب ليك',
      'subtitle': 'تصفح الأقسام واكتشف منتجات جديدة',
      'icon': 'inventory_2',
    },
  ];

  // بيانات موردين افتراضية للاختبار فقط، وليست حسابات دخول حقيقية.
  final List<Map<String, String>> suppliers = [
    {'name': 'سلسلة للمواد الغذائية', 'type': 'تاجر جملة', 'minimum': 'الحد الأدنى 3000 جنيه'},
    {'name': 'مؤسسة الأمان للمواد الغذائية', 'type': 'تاجر جملة', 'minimum': 'الحد الأدنى 2000 جنيه'},
    {'name': 'شركة الخير للتوزيع', 'type': 'شركة توزيع', 'minimum': 'الحد الأدنى 1500 جنيه'},
    {'name': 'تجار المستقبل', 'type': 'تاجر جملة جملة', 'minimum': 'الحد الأدنى 3000 جنيه'},
    {'name': 'النور لتجارة الجملة', 'type': 'تاجر جملة', 'minimum': 'الحد الأدنى 2500 جنيه'},
    {'name': 'الصفوة للتوريدات', 'type': 'شركة توزيع', 'minimum': 'الحد الأدنى 2000 جنيه'},
    {'name': 'البركة للزيوت والسمن', 'type': 'تاجر جملة', 'minimum': 'الحد الأدنى 1800 جنيه'},
    {'name': 'أولاد البلد للمكرونة والبقوليات', 'type': 'تاجر جملة', 'minimum': 'الحد الأدنى 1200 جنيه'},
    {'name': 'رواد المشروبات والعصائر', 'type': 'شركة توزيع', 'minimum': 'الحد الأدنى 2200 جنيه'},
    {'name': 'المخزن الاقتصادي للسوبر ماركت', 'type': 'تاجر جملة جملة', 'minimum': 'الحد الأدنى 3500 جنيه'},
  ];

  // عملاء افتراضيون للسيناريوهات التجريبية فقط، لا يتم إنشاء حسابات Auth لهم.
  final List<Map<String, String>> demoCustomers = [
    {'name': 'سوبر ماركت النخبة', 'type': 'سوبر ماركت'},
    {'name': 'ماركت الرحمة', 'type': 'بقالة'},
    {'name': 'تجارة أولاد حسن', 'type': 'تاجر نصف جملة'},
    {'name': 'سوبر ماركت الأمل', 'type': 'سوبر ماركت'},
    {'name': 'بقالة البركة', 'type': 'بقالة'},
    {'name': 'ماركت الإيمان', 'type': 'سوبر ماركت'},
    {'name': 'مؤسسة الفجر التجارية', 'type': 'تاجر نصف جملة'},
    {'name': 'سوبر ماركت المدينة', 'type': 'سوبر ماركت'},
    {'name': 'بقالة السلام', 'type': 'بقالة'},
    {'name': 'ماركت الصفاء', 'type': 'سوبر ماركت'},
  ];

  // كتالوج وأسعار افتراضية للاختبار؛ لا تمثل عروض بيع حقيقية.
  final List<Map<String, dynamic>> products = [
    {'name': 'زيت خليط 1 لتر', 'description': 'زيوت • كرتونة 12 عبوة', 'price': 'سعر تجريبي 780 ج.م', 'icon': Icons.water_drop_outlined, 'color': orange},
    {'name': 'زيت عباد الشمس 1 لتر', 'description': 'زيوت • كرتونة 12 عبوة', 'price': 'سعر تجريبي 960 ج.م', 'icon': Icons.water_drop, 'color': orange},
    {'name': 'سمن نباتي 1.5 كجم', 'description': 'سمنات • كرتونة 6 عبوات', 'price': 'سعر تجريبي 720 ج.م', 'icon': Icons.breakfast_dining, 'color': orange},
    {'name': 'مكرونة 400 جم', 'description': 'مكرونات • كرتونة 20 كيس', 'price': 'سعر تجريبي 420 ج.م', 'icon': Icons.ramen_dining_outlined, 'color': purple},
    {'name': 'أرز أبيض 1 كجم', 'description': 'حبوب وبقوليات • شيكارة', 'price': 'سعر تجريبي 950 ج.م', 'icon': Icons.grain, 'color': purple},
    {'name': 'سكر أبيض 1 كجم', 'description': 'سلع أساسية • شيكارة', 'price': 'سعر تجريبي 1100 ج.م', 'icon': Icons.icecream_outlined, 'color': pink},
    {'name': 'شاي أسود 250 جم', 'description': 'مشروبات ساخنة • كرتونة', 'price': 'سعر تجريبي 840 ج.م', 'icon': Icons.coffee_outlined, 'color': purple},
    {'name': 'صلصة طماطم 300 جم', 'description': 'معلبات • كرتونة 24 عبوة', 'price': 'سعر تجريبي 360 ج.م', 'icon': Icons.inventory_2_outlined, 'color': orange},
    {'name': 'فول مدمس 400 جم', 'description': 'معلبات • كرتونة 24 علبة', 'price': 'سعر تجريبي 480 ج.م', 'icon': Icons.lunch_dining_outlined, 'color': orange},
    {'name': 'عصير مانجو 1 لتر', 'description': 'عصائر • كرتونة 12 عبوة', 'price': 'سعر تجريبي 540 ج.م', 'icon': Icons.local_drink_outlined, 'color': pink},
    {'name': 'مشروب غازي  cola', 'description': 'مشروبات غازية • عبوة', 'price': 'سعر تجريبي 300 ج.م', 'icon': Icons.local_drink, 'color': pink},
    {'name': 'بسكويت سادة', 'description': 'مقرمشات وحلويات • كرتونة', 'price': 'سعر تجريبي 390 ج.م', 'icon': Icons.cookie_outlined, 'color': orange},
    {'name': 'شيبسي بطعم الجبنة', 'description': 'مقرمشات • كرتونة', 'price': 'سعر تجريبي 450 ج.م', 'icon': Icons.fastfood_outlined, 'color': pink},
    {'name': 'لبن طويل الأجل 1 لتر', 'description': 'ألبان • كرتونة 12 عبوة', 'price': 'سعر تجريبي 660 ج.م', 'icon': Icons.local_cafe_outlined, 'color': purple},
    {'name': 'جبنة بيضاء 500 جم', 'description': 'جبن • عبوة', 'price': 'سعر تجريبي 600 ج.م', 'icon': Icons.breakfast_dining_outlined, 'color': orange},
    {'name': 'منظف أرضيات 1 لتر', 'description': 'منظفات • كرتونة', 'price': 'سعر تجريبي 480 ج.م', 'icon': Icons.cleaning_services_outlined, 'color': Colors.teal},
    {'name': 'سائل أطباق 650 مل', 'description': 'منظفات • كرتونة', 'price': 'سعر تجريبي 420 ج.م', 'icon': Icons.soap_outlined, 'color': Colors.teal},
    {'name': 'مناديل ورقية', 'description': 'ورقيات • باكيتات', 'price': 'سعر تجريبي 350 ج.م', 'icon': Icons.cleaning_services, 'color': purple},
    {'name': 'خل أبيض 1 لتر', 'description': 'مواد غذائية • كرتونة', 'price': 'سعر تجريبي 240 ج.م', 'icon': Icons.water_drop, 'color': orange},
    {'name': 'عدس أصفر 1 كجم', 'description': 'حبوب وبقوليات • شيكارة', 'price': 'سعر تجريبي 1250 ج.م', 'icon': Icons.grain, 'color': purple},
  ];

  final List<String> categories = [
    'سمنات',
    'زيوت',
    'مكرونات',
    'بقوليات',
    'مشروبات ساخنة',
    'مشروبات غازية',
    'جبن',
    'ألبان',
    'عصائر',
    'مقرمشات',
    'منظفات',
    'خردوات',
    'مكملات طعام',
    'مكملات حلويات',
    'معلبات',
    'ورقيات',
    'مخبوزات',
    'حلويات',
    'شوكولاتة',
    'أصناف أخرى',
  ];

  final List<Map<String, dynamic>> stories = [
    {'name': 'عروض اليوم', 'icon': Icons.local_offer, 'color': orange},
    {'name': 'موردون', 'icon': Icons.storefront, 'color': purple},
    {'name': 'منتجات جديدة', 'icon': Icons.new_releases, 'color': pink},
    {'name': 'الأكثر طلبًا', 'icon': Icons.trending_up, 'color': Colors.teal},
    {'name': 'اختياراتنا', 'icon': Icons.stars, 'color': Colors.deepOrange},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => profileLoaded = true);
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, account_type')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      final name = (profile?['full_name'] as String?)?.trim();
      final rawType = profile?['account_type'] as String?;
      const labels = <String, String>{
        'supplier': 'مورد',
        'customer': 'عميل',
        'delegate': 'مندوب',
        'shipping_company': 'شركة شحن',
        'business_admin': 'إدارة نشاط معتمدة',
      };
      setState(() {
        if (name != null && name.isNotEmpty) displayName = name;
        accountTypeLabel = labels[rawType] ?? 'عميل';
        profileLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => profileLoaded = true);
    }
  }

  @override
  void dispose() {
    search.dispose();
    bannerController.dispose();
    super.dispose();
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: page == 0
            ? cartPage()
            : page == 2
                ? morePage()
                : homePage(),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: palePurple,
        selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.length}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_bag, color: purple),
            label: 'السلة',
          ),
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: purple),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded, color: purple),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }

  Widget homePage() {
    final query = search.text.trim().toLowerCase();

    final filteredSuppliers = suppliers.where((item) =>
        item['name']!.toLowerCase().contains(query) ||
        item['type']!.toLowerCase().contains(query)).toList();

    final filteredCategories = categories.where(
      (item) => item.toLowerCase().contains(query),
    ).toList();

    final filteredProducts = products.where((item) =>
        item['name'].toString().toLowerCase().contains(query) ||
        item['description'].toString().toLowerCase().contains(query)).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _demoDataNotice()),
        SliverToBoxAdapter(child: _buildSearch()),
        SliverToBoxAdapter(child: _buildQuickOverview()),
        SliverToBoxAdapter(child: _buildBannerSlider()),
        SliverToBoxAdapter(child: _buildStories()),
        SliverToBoxAdapter(
          child: _sectionHeader(
            'تصفح الأقسام',
            'كل احتياجات تجارتك',
            onTap: () => setState(() => tab = 1),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategoryGrid()),
        SliverToBoxAdapter(
          child: _sectionHeader(
            'منتجات مختارة',
            'اكتشف أصنافًا جديدة',
            onTap: () => setState(() => tab = 1),
          ),
        ),
        if (tab == 0)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 174,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: filteredProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) =>
                    _productCard(filteredProducts[index]),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _sectionHeader(
            tab == 1 ? 'الأقسام' : 'الموردون المميزون',
            tab == 1 ? 'اختار القسم المناسب' : 'ابدأ الشراء من المورد المناسب',
            onTap: () => setState(() => tab = tab == 0 ? 1 : 0),
          ),
        ),
        if (tab == 0)
          if (filteredSuppliers.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('مفيش موردين مطابقين للبحث.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => _supplierCard(filteredSuppliers[index]),
                  childCount: filteredSuppliers.length,
                ),
              ),
            )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => _categoryCard(filteredCategories[index]),
                childCount: filteredCategories.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 26),
            child: Center(
              child: Text(
                'سلسلة Silsila • بنربط السوق ببعضه',
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _demoDataNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: orange.withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: purple, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'نسخة تجريبية — الموردون والمنتجات والأسعار ليست بيانات بيع فعلية.',
                style: TextStyle(color: ink, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [purple, Color(0xFF7137A4)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.link_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلًا ${displayName == 'تاجر سلسلة' ? 'بيك' : displayName} 👋',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'بنربط السوق ببعضه',
                  style: TextStyle(color: purple, fontSize: 12),
                ),
              ],
            ),
          ),
          _roundIcon(
            Icons.notifications_none_rounded,
            () => _showInfo(
              'الإشعارات',
              'هتظهر هنا إشعارات الطلبات والعروض الجديدة بعد تفعيلها.',
            ),
          ),
          const SizedBox(width: 8),
          _roundIcon(Icons.menu_rounded, () => setState(() => page = 2)),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFECE5F2)),
          ),
          child: Icon(icon, color: purple),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 15),
      child: TextField(
        controller: search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'بتدور على منتج أو مورد؟',
          hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
          prefixIcon: const Icon(Icons.search_rounded, color: purple),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    search.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFECE5F2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: purple, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOverview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFECE5F2)),
          boxShadow: [
            BoxShadow(
              color: purple.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palePurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.store_mall_directory_outlined,
                      color: purple, size: 24),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سوق الجملة في مكان واحد',
                          style: TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          )),
                      SizedBox(height: 4),
                      Text('اكتشف الأقسام والموردين وابدأ تجهيز مشترياتك',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                            height: 1.5,
                          )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('B2B', style: TextStyle(
                    color: purple, fontSize: 11, fontWeight: FontWeight.w900,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _overviewMetric(Icons.storefront_outlined,
                    '${suppliers.length}', 'موردون', purple)),
                const SizedBox(width: 8),
                Expanded(child: _overviewMetric(Icons.category_outlined,
                    '${categories.length}', 'أقسام', orange)),
                const SizedBox(width: 8),
                Expanded(child: _overviewMetric(Icons.favorite_border_rounded,
                    '${favorites.length}', 'مفضلة', pink)),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.black45, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'نسخة استعراضية — بيانات الموردين والأسعار تحتاج إلى الربط الفعلي.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontSize: 9,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewMetric(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
              Text(label, style: const TextStyle(color: ink, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    return Column(
      children: [
        SizedBox(
          height: 176,
          child: PageView.builder(
            controller: bannerController,
            itemCount: banners.length,
            onPageChanged: (index) => setState(() => bannerIndex = index),
            itemBuilder: (_, index) {
              final banner = banners[index];
              final icon = banner['icon'] == 'storefront'
                  ? Icons.storefront_rounded
                  : banner['icon'] == 'inventory_2'
                      ? Icons.inventory_2_rounded
                      : Icons.local_offer_rounded;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [purple, Color(0xFF6A2BA0)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: orange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                banner['tag']!,
                                style: const TextStyle(
                                  color: purple,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Text(
                              banner['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              banner['subtitle']!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: Icon(icon, color: orange, size: 38),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: bannerIndex == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: bannerIndex == index ? purple : const Color(0xFFD9CDE5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStories() {
    return Column(
      children: [
        _sectionHeader('اكتشف الجديد', 'حكايات السوق والعروض'),
        SizedBox(
          height: 105,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 15),
            itemBuilder: (_, index) {
              final story = stories[index];
              final color = story['color'] as Color;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showInfo(
                  story['name'] as String,
                  'محتوى ${story['name']} تجريبي حاليًا، وسيتم ربطه بالعروض الحقيقية لاحقًا.',
                ),
                child: SizedBox(
                  width: 69,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [color, pink, orange],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: canvas,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 27,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(
                              story['icon'] as IconData,
                              color: color,
                              size: 27,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        story['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 23, 18, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: const Text(
                'عرض الكل',
                style: TextStyle(
                  color: purple,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final icons = [
      Icons.water_drop_outlined,
      Icons.ramen_dining_outlined,
      Icons.grain,
      Icons.local_drink_outlined,
      Icons.bubble_chart_outlined,
      Icons.egg_alt_outlined,
      Icons.cleaning_services_outlined,
      Icons.inventory_2_outlined,
    ];
    final colors = [purple, orange, pink, Colors.teal];

    return SizedBox(
      height: 101,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final color = colors[index % colors.length];
          return InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () {
              search.text = categories[index];
              setState(() => tab = 1);
            },
            child: Container(
              width: 91,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFFECE5F2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icons[index % icons.length],
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    categories[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final color = product['color'] as Color;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFECE5F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                product['icon'] as IconData,
                color: color,
                size: 45,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product['name'] as String,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            product['description'] as String,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 5),
          Text(
            product['price'] as String,
            style: const TextStyle(
              fontSize: 10,
              color: purple,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 29,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: purple,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                final name = product['name'] as String;
                setState(() => cart.add(name));
                message('تمت إضافة $name إلى السلة التجريبية');
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
              label: const Text('أضف للسلة', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierCard(Map<String, String> supplier) {
    final name = supplier['name']!;
    final favorite = favorites.contains(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFECE5F2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palePurple,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.storefront, color: purple, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      supplier['type']!,
                      style: const TextStyle(
                        color: purple,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (favorite) {
                      favorites.remove(name);
                    } else {
                      favorites.add(name);
                    }
                  });
                  message(favorite
                      ? 'تم حذف المورد من المفضلة'
                      : 'تمت إضافة المورد للمفضلة');
                },
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: pink,
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: orange, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  supplier['minimum']!,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: () => _showInfo(
                name,
                'نوع المورد: ${supplier['type']}\n${supplier['minimum']}\n\nهذه بطاقة تجريبية. لم يتم ربط بيانات المورد أو كتالوجه بقاعدة البيانات بعد.',
              ),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('عرض تفاصيل المورد'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(String category) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: palePurple,
          child: Icon(Icons.inventory_2_outlined, color: purple),
        ),
        title: Text(category),
        trailing: const Icon(Icons.chevron_left, color: purple),
        onTap: () => message('قسم $category تجريبي حاليًا.'),
      ),
    );
  }

  Widget cartPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'سلة مشترياتك',
          style: TextStyle(
            fontSize: 25,
            color: purple,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'راجع اختياراتك قبل متابعة الطلب',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        if (cart.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 58, color: purple),
                SizedBox(height: 15),
                Text(
                  'سلتك لسه فاضية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                SizedBox(height: 8),
                Text('تصفح الموردين وأضف احتياجات تجارتك.'),
              ],
            ),
          )
        else ...[
          ...cart.asMap().entries.map(
            (entry) => Card(
              child: ListTile(
                leading: const Icon(Icons.storefront, color: purple),
                title: Text(entry.value),
                subtitle: const Text('عنصر تجريبي'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() => cart.removeAt(entry.key));
                    message('تم حذف العنصر');
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: purple,
              padding: const EdgeInsets.all(15),
            ),
            onPressed: () => message(
              'إتمام الطلب الحقيقي يتطلب ربط المنتجات والطلبات بقاعدة البيانات.',
            ),
            child: const Text(
              'متابعة الطلب',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'البيانات والأسعار المعروضة تجريبية.',
          style: TextStyle(color: Colors.black45, fontSize: 12),
        ),
      ],
    );
  }

  Widget morePage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [purple, Color(0xFF7137A4)]),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person_outline, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'حساب $accountTypeLabel • كل خدمات تجارتك في مكان واحد',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!profileLoaded)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _menuItem(Icons.person_outline, 'بياناتي',
            'إدارة بيانات الحساب قيد التطوير.'),
        _menuItem(Icons.receipt_long_outlined, 'سجل طلباتي',
            'سجل الطلبات الحقيقي سيتم ربطه بقاعدة البيانات.'),
        _menuItem(Icons.favorite_outline, 'الموردون المفضلون',
            favorites.isEmpty ? 'لا توجد عناصر في المفضلة.' : favorites.join('\n')),
        _menuItem(Icons.groups_outlined, 'عملاء تجريبيون',
            demoCustomers.map((item) => '${item['name']} — ${item['type']}').join('\n')),
        _menuItem(Icons.account_balance_wallet_outlined, 'رصيدي ومحفظتي',
            'خدمات المحفظة ستتاح بعد تجهيز النظام المالي.'),
        _menuItem(Icons.receipt_long_rounded, 'كشف حسابي',
            'كشف حساب تجريبي للاختبار: رصيد افتتاحي 0.00 ج.م، إجمالي مدين 0.00 ج.م، إجمالي دائن 0.00 ج.م، الرصيد الحالي 0.00 ج.م. سيتم ربط الحركات الفعلية بقاعدة البيانات لاحقًا.'),
        _menuItem(Icons.local_offer_outlined, 'العروض',
            'العروض الحالية تجريبية لحين ربطها بالموردين.'),
        _menuItem(Icons.settings_outlined, 'الإعدادات',
            'إعدادات الحساب قيد التطوير.'),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const Directionality(
                  textDirection: TextDirection.rtl,
                  child: SilsilaWelcomeScreen(),
                ),
              ),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'سلسلة Silsila\nبنربط السوق ببعضه',
            textAlign: TextAlign.center,
            style: TextStyle(color: purple, height: 1.8),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, String description) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: palePurple,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: purple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_left, color: purple),
        onTap: () => _showInfo(title, description),
      ),
    );
  }

  void _showInfo(String title, String description) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// تسجيل الدخول
// ============================================================




Widget _accountDestination(String accountType) {
  if (accountType == 'customer') return const SilsilaHome();
  return SilsilaRolePortalScreen(accountType: accountType);
}

class SilsilaRolePortalScreen extends StatelessWidget {
  final String accountType;

  const SilsilaRolePortalScreen({super.key, required this.accountType});

  String get roleName {
    switch (accountType) {
      case 'supplier':
        return 'المورد';
      case 'delegate':
        return 'المندوب';
      case 'shipping_company':
        return 'شركة الشحن';
      case 'business_admin':
        return 'إدارة النشاط';
      default:
        return 'الحساب';
    }
  }

  String get roleDescription {
    switch (accountType) {
      case 'supplier':
        return 'مساحة المورد لإدارة الأصناف والأسعار والطلبات ستُفعّل بعد تجهيز وحدات المورد وربطها بقاعدة البيانات.';
      case 'delegate':
        return 'مساحة المندوب لمتابعة المهام والتسليمات قيد التجهيز.';
      case 'shipping_company':
        return 'مساحة شركة الشحن لمتابعة الشحنات والتكليفات قيد التجهيز.';
      case 'business_admin':
        return 'هذا النوع لا يفعّل أدوات الإدارة تلقائيًا. يجب اعتماد صلاحيات الإدارة من جهة موثوقة قبل إتاحة أي وظائف إدارية.';
      default:
        return 'تعذر تحديد نوع الحساب. راجع بيانات حسابك مع الدعم.';
    }
  }

  IconData get roleIcon {
    switch (accountType) {
      case 'supplier':
        return Icons.storefront_rounded;
      case 'delegate':
        return Icons.badge_outlined;
      case 'shipping_company':
        return Icons.local_shipping_outlined;
      case 'business_admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        title: const Text('سلسلة Silsila'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: SilsilaSplashScreen(),
                  ),
                ),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [purple, Color(0xFF7137A4)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(roleIcon, color: orange, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  'أهلًا بك في مساحة $roleName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سلسلة .. بنربط السوق ببعضه',
                  style: TextStyle(color: orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFECE5F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.construction_rounded, color: orange),
                    SizedBox(width: 8),
                    Text(
                      'المساحة قيد التجهيز',
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  roleDescription,
                  style: const TextStyle(color: ink, height: 1.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'تم توجيهك حسب نوع الحساب المسجل في قاعدة البيانات. لن تظهر وظائف غير جاهزة أو صلاحيات إدارية من شاشة التسجيل.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class SilsilaSplashScreen extends StatelessWidget {
  const SilsilaSplashScreen({super.key});

  void start(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: SilsilaEntryOptionsScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/silsila_background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: purple),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Image.asset(
                  'assets/images/silsila_logo.png',
                  width: 190,
                  height: 190,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.link_rounded,
                    size: 110,
                    color: purple,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: pink.withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () => start(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: pink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 17,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Kufam',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('ابدأ الآن'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SilsilaEntryOptionsScreen extends StatelessWidget {
  const SilsilaEntryOptionsScreen({super.key});

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: page,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: pink.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(title),
          style: FilledButton.styleFrom(
            backgroundColor: pink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Kufam',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeIllustration() {
    return SizedBox(
      width: 250,
      height: 225,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 205,
            height: 205,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: purple.withValues(alpha: 0.08),
              border: Border.all(
                color: purple.withValues(alpha: 0.18),
                width: 2,
              ),
            ),
          ),
          Positioned(
            top: 4,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: orange,
              child: const Icon(
                Icons.storefront_rounded,
                color: purple,
                size: 29,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 77,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: pink,
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 77,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: purple,
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
          ),
          Positioned(
            right: 36,
            bottom: 2,
            child: CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFF20A67A),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
          Positioned(
            left: 36,
            bottom: 2,
            child: CircleAvatar(
              radius: 23,
              backgroundColor: orange,
              child: const Icon(
                Icons.delivery_dining_rounded,
                color: purple,
                size: 27,
              ),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: purple.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.store_mall_directory_rounded,
              color: purple,
              size: 76,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/silsila_background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: canvas),
          ),
          ColoredBox(
            color: Colors.white.withValues(alpha: 0.84),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/silsila_logo.png',
                        width: 100,
                        height: 82,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.link_rounded,
                          color: purple,
                          size: 65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'أهلًا بك في تطبيق سلسلة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kufam',
                        color: purple,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'منصتك لربط التجار والموردين والمناديب بالعملاء وشركات الشحن في سوق واحد.. بكل سهولة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kufam',
                        color: ink,
                        fontSize: 14,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: _storeIllustration()),
                    const SizedBox(height: 8),
                    const Text(
                      'طريقة تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kufam',
                        color: purple,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _actionButton(
                      title: 'تسجيل دخول مستخدم حالي',
                      icon: Icons.login_rounded,
                      onPressed: () =>
                          _openPage(context, const SilsilaLoginScreen()),
                    ),
                    const SizedBox(height: 13),
                    _actionButton(
                      title: 'إنشاء حساب جديد',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: () =>
                          _openPage(context, const SilsilaRegisterScreen()),
                    ),
                    const SizedBox(height: 13),
                    _actionButton(
                      title: 'تسجيل نشاط تجاري جديد',
                      icon: Icons.add_business_rounded,
                      onPressed: () => _openPage(
                        context,
                        const SilsilaRegisterScreen(activityRegistration: true),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'سلسلة .. بنربط السوق ببعضه',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kufam',
                        color: purple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class SilsilaLoginScreen extends StatefulWidget {
  const SilsilaLoginScreen({super.key});

  @override
  State<SilsilaLoginScreen> createState() => _SilsilaLoginScreenState();
}

class _SilsilaLoginScreenState extends State<SilsilaLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> login() async {
    if (isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('من فضلك اكتب البريد الإلكتروني وكلمة المرور.');
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showMessage('من فضلك اكتب بريدًا إلكترونيًا صحيحًا.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = authResponse.user;
      if (user == null) {
        showMessage('تم التحقق من الدخول لكن لم نستطع تحديد الحساب. حاول مرة أخرى.');
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('account_type')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      final accountType = profile?['account_type'] as String?;
      if (accountType == null || accountType.isEmpty) {
        showMessage('تم تسجيل الدخول، لكن ملف الحساب غير مكتمل. تواصل مع الدعم قبل متابعة الاستخدام.');
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: _accountDestination(accountType),
          ),
        ),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final error = e.message.toLowerCase();
      if (error.contains('email not confirmed')) {
        showMessage('البريد الإلكتروني لم يتم تأكيده بعد.');
      } else if (error.contains('invalid login credentials')) {
        showMessage('البريد الإلكتروني أو كلمة المرور غير صحيحة.');
      } else {
        showMessage('تعذر تسجيل الدخول: ${e.message}');
      }
    } catch (_) {
      if (!mounted) return;
      showMessage('حدث خطأ أثناء تسجيل الدخول. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [purple, Color(0xFF7137A4)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.link_rounded, color: Colors.white, size: 58),
                        SizedBox(height: 10),
                        Text(
                          'سلسلة Silsila',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'بنربط السوق ببعضه',
                          style: TextStyle(color: orange, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'أهلاً بعودتك',
                    style: TextStyle(
                      color: ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'سجّل دخولك وتابع تجارتك بسهولة',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: _decoration(
                      'البريد الإلكتروني',
                      Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    onSubmitted: (_) => login(),
                    decoration: _decoration(
                      'كلمة المرور',
                      Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => obscurePassword = !obscurePassword,
                        ),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SilsilaForgotPasswordScreen(),
                        ),
                      ),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: purple,
                        side: const BorderSide(color: purple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SilsilaRegisterScreen(),
                        ),
                      ),
                      child: const Text('إنشاء حساب جديد'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// تسجيل حساب جديد
// ============================================================

class SilsilaRegisterScreen extends StatefulWidget {
  final bool activityRegistration;

  const SilsilaRegisterScreen({
    super.key,
    this.activityRegistration = false,
  });

  @override
  State<SilsilaRegisterScreen> createState() => _SilsilaRegisterScreenState();
}

class _SilsilaRegisterScreenState extends State<SilsilaRegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final address = TextEditingController();
  final landmark = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  String accountType = 'عميل';
  String activityType = 'مواد غذائية';
  String governorate = '';
  bool whatsappSame = true;
  bool obscurePassword = true;
  bool isRegistering = false;

  final accountTypes = const [
    'مورد',
    'عميل',
    'مندوب',
    'شركة شحن',
  ];

  final governorates = const [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'القليوبية', 'البحيرة',
    'مطروح', 'دمياط', 'الدقهلية', 'كفر الشيخ', 'الغربية', 'المنوفية',
    'الشرقية', 'بورسعيد', 'الإسماعيلية', 'السويس', 'شمال سيناء',
    'جنوب سيناء', 'بني سويف', 'الفيوم', 'المنيا', 'أسيوط', 'سوهاج',
    'قنا', 'الأقصر', 'أسوان', 'البحر الأحمر', 'الوادي الجديد',
  ];

  @override
  void dispose() {
    email.dispose();
    name.dispose();
    phone.dispose();
    whatsapp.dispose();
    address.dispose();
    landmark.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: purple),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFECE5F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFECE5F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: purple, width: 1.5),
      ),
    );
  }

  Widget textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: decoration(label, icon),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'من فضلك أدخل $label';
          }
          return null;
        },
      ),
    );
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> registerAccount() async {
    if (isRegistering || !formKey.currentState!.validate()) return;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email.text.trim())) {
      showMessage('اكتب بريدًا إلكترونيًا صحيحًا.');
      return;
    }

    if (password.text.length < 8) {
      showMessage('كلمة المرور يجب ألا تقل عن 8 أحرف.');
      return;
    }

    if (password.text != confirmPassword.text) {
      showMessage('كلمتا المرور غير متطابقتين.');
      return;
    }

    setState(() => isRegistering = true);

    try {
      final phoneValue = phone.text.trim();
      final response = await Supabase.instance.client.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {
          'full_name': name.text.trim(),
          'phone': phoneValue,
          'whatsapp': whatsappSame ? phoneValue : whatsapp.text.trim(),
          'whatsapp_same': whatsappSame,
          'activity_type': activityType,
          'account_type': {
            'مورد': 'supplier',
            'عميل': 'customer',
            'مندوب': 'delegate',
            'شركة شحن': 'shipping_company',
          }[accountType] ?? 'customer',
          'governorate': governorate,
          'district': address.text.trim(),
          'address': landmark.text.trim(),
        },
      );

      if (!mounted) return;

      if (response.user == null) {
        showMessage('تعذر إنشاء الحساب، حاول مرة أخرى.');
      } else if (response.session == null) {
        showMessage('تم إنشاء الحساب. راجع بريدك الإلكتروني لتأكيده.');
        Navigator.pop(context);
      } else {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('account_type')
            .eq('id', response.user!.id)
            .maybeSingle();
        if (!mounted) return;
        final createdType = profile?['account_type'] as String?;
        if (createdType == null || createdType.isEmpty) {
          showMessage('تم إنشاء حساب الدخول، لكن ملف النشاط لم يكتمل. لا تغلق التطبيق وراجع إعدادات قاعدة البيانات.');
          return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: _accountDestination(createdType),
            ),
          ),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) showMessage('تعذر التسجيل: ${e.message}');
    } catch (_) {
      if (mounted) showMessage('حصل خطأ أثناء التسجيل. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء حساب جديد')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Center(
                child: Icon(Icons.link_rounded, color: purple, size: 53),
              ),
              const SizedBox(height: 8),
              const Text(
                'انضم إلى سلسلة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: purple,
                ),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                value: activityType,
                decoration: decoration('نوع النشاط', Icons.storefront),
                items: const [
                  DropdownMenuItem(
                    value: 'مواد غذائية',
                    child: Text('مواد غذائية'),
                  ),
                ],
                onChanged: isRegistering
                    ? null
                    : (value) => setState(
                          () => activityType = value ?? 'مواد غذائية',
                        ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: accountType,
                decoration: decoration('نوع الحساب', Icons.person_outline),
                items: accountTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: isRegistering
                    ? null
                    : (value) => setState(
                          () => accountType = value ?? 'عميل',
                        ),
              ),
              if (widget.activityRegistration) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: orange.withValues(alpha: 0.55)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: purple),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'سجّل بيانات نشاطك التجاري كحساب عميل للشراء من الموردين. صلاحيات إدارة المنصة لا تُمنح من شاشة التسجيل وتحتاج إلى اعتماد منفصل.',
                          style: TextStyle(color: ink, fontSize: 12, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              textField(email, 'البريد الإلكتروني', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              textField(name, 'الاسم أو اسم النشاط', Icons.badge_outlined),
              textField(phone, 'رقم الموبايل', Icons.phone_android,
                  keyboardType: TextInputType.phone),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: purple,
                value: whatsappSame,
                title: const Text('رقم واتساب هو نفس رقم الموبايل'),
                onChanged: isRegistering
                    ? null
                    : (value) => setState(
                          () => whatsappSame = value ?? true,
                        ),
              ),
              if (!whatsappSame)
                textField(whatsapp, 'رقم واتساب', Icons.chat_outlined,
                    keyboardType: TextInputType.phone),
              DropdownButtonFormField<String>(
                value: governorate.isEmpty ? null : governorate,
                decoration: decoration('المحافظة', Icons.location_city),
                hint: const Text('اختر المحافظة'),
                items: governorates.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                validator: (value) =>
                    value == null ? 'اختر المحافظة' : null,
                onChanged: isRegistering
                    ? null
                    : (value) => setState(() => governorate = value ?? ''),
              ),
              const SizedBox(height: 14),
              textField(address, 'المنطقة أو المركز أو القرية', Icons.map_outlined),
              textField(landmark, 'العنوان بالتفصيل وعلامة مميزة',
                  Icons.place_outlined),
              TextFormField(
                controller: password,
                obscureText: obscurePassword,
                decoration: decoration('كلمة المرور', Icons.lock_outline)
                    .copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => obscurePassword = !obscurePassword,
                    ),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'كلمة المرور يجب ألا تقل عن 8 أحرف'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: confirmPassword,
                obscureText: true,
                decoration: decoration(
                  'تأكيد كلمة المرور',
                  Icons.lock_reset,
                ),
                validator: (value) => value != password.text
                    ? 'كلمتا المرور غير متطابقتين'
                    : null,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isRegistering ? null : registerAccount,
                  child: isRegistering
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'إنشاء الحساب',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _decoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: purple),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFECE5F2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFECE5F2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: purple, width: 1.5),
    ),
  );
}
