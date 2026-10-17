import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/trader_market_service.dart';
import 'services/order_status_service.dart';
import 'services/wallet_service.dart';
import 'services/profile_service.dart';
import 'services/notification_service.dart';

const purple = Color(0xFF3E007D);
const orange = Color(0xFFFFA015);
const pink = Color(0xFFFF27C3);
const canvas = Color(0xFFFAF8FC);

const supabaseUrl = 'https://teitsopmhruczplwlwgn.supabase.co';
const supabaseKey =
    'sb_publishable_y6pDeQ9rLq680rS7qqirPQ_LAo5ZcTu';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
  } catch (_) {}
  runApp(const SilsilaApp());
}

SupabaseClient? get database {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

const activityTypes = [
  'مواد غذائية',
  'لوازم بناء وتشطيبات',
  'أجهزة وإلكترونيات',
  'أثاث وتجهيزات',
  'سيارات ومعدات',
  'ملابس وأقمشة',
  'أدوات منزلية',
  'أدوات كهربائية',
  'أدوات مكتبية',
  'مستلزمات طبية',
  'مستحضرات تجميل',
  'زراعة ومستلزماتها',
  'قطع غيار',
  'مستلزمات مطاعم وفنادق',
  'ورقيات وتعبئة وتغليف',
  'منظفات ومطهرات',
  'مستلزمات حيوانات',
  'خدمات وشحن ونقل',
  'أنشطة أخرى',
];

const customerTypes = [
  'مستهلك نهائي',
  'محل تجزئة',
  'بقالة',
  'سوبر ماركت',
  'تاجر نصف جملة',
  'تاجر جملة',
  'تاجر جملة جملة',
  'موزع',
  'سلسلة فروع',
  'شركة أو مؤسسة',
  'مطعم أو كافيه',
  'فندق أو منشأة سياحية',
  'مصنع أو منشأة إنتاج',
  'جهة حكومية',
  'عميل آخر',
];

const supplierTypes = [
  'مصنع أو منتج',
  'وكيل معتمد',
  'مستورد',
  'موزع رئيسي',
  'تاجر جملة جملة',
  'تاجر جملة',
  'تاجر نصف جملة',
  'مورد محلي',
  'شركة توزيع',
  'مندوب شركة',
  'مورد خدمات',
  'مورد آخر',
];

const delegateTypes = [
  'مندوب مبيعات خارجي',
  'مندوب مبيعات داخلي',
  'مندوب من المنزل',
  'قائد فريق',
  'مشرف مبيعات',
  'مندوب جوكر',
  'مندوب تسليم',
  'مندوب تنسيق رفوف',
  'محصل',
  'كاشير',
  'مندوب مشتريات',
  'خدمة عملاء ومتابعة',
  'مندوب آخر',
];

const categories = [
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
  'شيكولاتة',
  'أصناف أخرى',
];

class Product {
  const Product(
    this.name,
    this.category,
    this.price,
    this.unit,
    this.icon,
  );

  final String name;
  final String category;
  final double price;
  final String unit;
  final IconData icon;
}

const products = [
  Product('زيت خليط 1 لتر', 'زيوت', 780, 'كرتونة', Icons.water_drop),
  Product('زيت عباد الشمس', 'زيوت', 960, 'كرتونة', Icons.water_drop),
  Product('سمن نباتي 1.5 كجم', 'سمنات', 720, 'كرتونة', Icons.breakfast_dining),
  Product('مكرونة 400 جم', 'مكرونات', 420, 'كرتونة', Icons.ramen_dining),
  Product('أرز معبأ', 'بقوليات', 950, 'شيكارة', Icons.grain),
  Product('سكر معبأ', 'بقوليات', 1100, 'شيكارة', Icons.icecream),
  Product('شاي أسود', 'مشروبات ساخنة', 840, 'كرتونة', Icons.coffee),
  Product('صلصة طماطم', 'معلبات', 360, 'كرتونة', Icons.lunch_dining),
  Product('فول معبأ', 'بقوليات', 480, 'كرتونة', Icons.rice_bowl),
  Product('عصير مانجو', 'عصائر', 540, 'كرتونة', Icons.local_drink),
  Product('مشروب غازي', 'مشروبات غازية', 300, 'كرتونة', Icons.local_drink),
  Product('بسكويت سادة', 'حلويات', 390, 'كرتونة', Icons.cookie),
  Product('رقائق بطاطس', 'مقرمشات', 450, 'كرتونة', Icons.fastfood),
  Product('لبن طويل الأجل', 'ألبان', 660, 'كرتونة', Icons.local_cafe),
  Product('جبنة مطبوخة', 'جبن', 600, 'كرتونة', Icons.dinner_dining),
  Product('منظف أرضيات', 'منظفات', 480, 'كرتونة', Icons.cleaning_services),
  Product('سائل أطباق', 'منظفات', 420, 'كرتونة', Icons.soap),
  Product('مناديل ورقية', 'ورقيات', 350, 'كرتونة', Icons.inventory_2),
  Product('خل أبيض', 'أصناف أخرى', 240, 'كرتونة', Icons.science),
  Product('عدس أصفر', 'بقوليات', 1250, 'شيكارة', Icons.grain),
];

const suppliers = [
  'سلسلة للمواد الغذائية',
  'مؤسسة الأمان للمواد الغذائية',
  'شركة الخير للتوزيع',
  'تجار المستقبل',
  'النور لتجارة الجملة',
  'الصفوة للتوريدات',
  'البركة للزيوت والسمن',
  'أولاد البلد للمكرونة والبقوليات',
  'رواد المشروبات والعصائر',
  'المخزن الاقتصادي للسوبر ماركت',
];

class SilsilaApp extends StatelessWidget {
  const SilsilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سلسلة Silsila',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          primary: purple,
          secondary: orange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: WelcomeScreen(),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [purple, Color(0xFF6E2BA6), Color(0xFF32105A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    size: 76,
                    color: purple,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'سلسلة Silsila',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'بنربط السوق ببعضه',
                  style: TextStyle(fontSize: 21, color: orange),
                ),
                const SizedBox(height: 12),
                const Text(
                  'منصة تجارة تجمع الموردين والتجار والأنشطة المختلفة في مكان واحد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.7),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: purple,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EntryOptionsScreen(),
                      ),
                    ),
                    child: const Text(
                      'ابدأ الآن',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text(
                    'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EntryOptionsScreen extends StatelessWidget {
  const EntryOptionsScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('سلسلة Silsila')),
            body: page,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ابدأ مع سلسلة')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.hub_rounded, size: 76, color: purple),
            const SizedBox(height: 12),
            const Text(
              'اختار طريقة دخولك',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'سلسلة .. بنربط السوق ببعضه',
              textAlign: TextAlign.center,
              style: TextStyle(color: purple, fontSize: 17),
            ),
            const SizedBox(height: 26),
            _EntryOptionTile(
              icon: Icons.login_rounded,
              title: 'تسجيل الدخول',
              subtitle: 'لديك حساب بالفعل',
              onTap: () => _open(context, const LoginScreen()),
            ),
            const SizedBox(height: 12),
            _EntryOptionTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'إنشاء مستخدم جديد',
              subtitle: 'التسجيل كعميل',
              color: orange,
              onTap: () => _open(
                context,
                const RegisterScreen(initialAccountType: 'عميل'),
              ),
            ),
            const SizedBox(height: 12),
            _EntryOptionTile(
              icon: Icons.add_business_rounded,
              title: 'تسجيل نشاط جديد',
              subtitle: 'مورد أو مندوب أو شركة شحن أو إدارة نشاط',
              color: pink,
              onTap: () => _open(
                context,
                const RegisterScreen(initialAccountType: 'إدارة نشاط'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainShell()),
                (route) => false,
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('استكشاف التطبيق كزائر'),
            ),
            const SizedBox(height: 12),
            const Text(
              'يمكنك استكشاف واجهة التطبيق كزائر. يلزم تسجيل الدخول لإتمام العمليات المرتبطة بحسابك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryOptionTile extends StatelessWidget {
  const _EntryOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = purple,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 1;
  String activity = 'مواد غذائية';
  String selectedCategory = 'الكل';
  String search = '';
  String accountName = 'تاجر سلسلة';
  final favorites = <String>{};
  final cart = <String, int>{};
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  double get total {
    double value = 0;
    for (final entry in cart.entries) {
      final matches = products.where((p) => p.name == entry.key);
      if (matches.isNotEmpty) {
        value += matches.first.price * entry.value;
      }
    }
    return value;
  }

  void addToCart(Product product) {
    setState(() {
      cart[product.name] = (cart[product.name] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${product.name} إلى السلة'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void openPage(String title, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text(title)),
            body: page,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      marketPage(),
      homePage(),
      cartPage(),
      morePage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'سلسلة Silsila',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => openPage(
              'الإشعارات',
              const NotificationsScreen(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'سوق التجار',
            ),
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text(
                  '${cart.values.fold<int>(0, (a, b) => a + b)}',
                ),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_cart),
              label: 'السلة',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open),
              label: 'المزيد',
            ),
          ],
        ),
      ),
    );
  }

  Widget homePage() {
    final visible = products.where((p) {
      final categoryMatch =
          selectedCategory == 'الكل' || p.category == selectedCategory;
      final q = search.trim().toLowerCase();
      final searchMatch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return categoryMatch && searchMatch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [purple, Color(0xFF7026A8)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلاً بك في سلسلة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'بنربط السوق ببعضه',
                style: TextStyle(color: orange, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'تجارة الجملة والتوريدات في مكان واحد.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: activity,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'نوع النشاط',
            prefixIcon: Icon(Icons.business_center),
          ),
          items: activityTypes
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            activity = v ?? 'مواد غذائية';
            selectedCategory = 'الكل';
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: (v) => setState(() => search = v),
          decoration: const InputDecoration(
            hintText: 'ابحث عن منتج أو قسم',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'الأقسام',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              'الكل',
              ...categories,
            ].map((category) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: selectedCategory == category,
                  selectedColor: orange.withOpacity(.3),
                  onSelected: (_) => setState(
                    () => selectedCategory = category,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'منتجات مقترحة',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (activity != 'مواد غذائية')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'تم اختيار نشاط $activity. المنتجات الظاهرة أدناه أمثلة غذائية مؤقتة؛ سيُخصص كتالوج مستقل لكل نشاط عند استكمال بياناته.',
              ),
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: .68,
          ),
          itemBuilder: (_, i) => productCard(visible[i]),
        ),
        const SizedBox(height: 20),
        const Text(
          'موردون مقترحون',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        ...suppliers.map(supplierTile),
      ],
    );
  }

  Widget productCard(Product product) {
    final favorite = favorites.contains(product.name);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: purple.withOpacity(.07),
              child: Stack(
                children: [
                  Center(
                    child: Icon(product.icon, size: 62, color: purple),
                  ),
                  Positioned(
                    left: 2,
                    top: 2,
                    child: IconButton(
                      onPressed: () => setState(() {
                        favorite
                            ? favorites.remove(product.name)
                            : favorites.add(product.name);
                      }),
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: favorite ? pink : purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${product.price.toStringAsFixed(0)} ج.م / ${product.unit}',
              style: const TextStyle(
                color: purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: FilledButton(
              onPressed: () => addToCart(product),
              child: const Text('أضف للسلة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget supplierTile(String name) {
    final favorite = favorites.contains(name);
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEFE6F8),
          child: Icon(Icons.store, color: purple),
        ),
        title: Text(name),
        subtitle: const Text('مورد تجريبي • تاجر جملة'),
        trailing: IconButton(
          icon: Icon(
            favorite ? Icons.favorite : Icons.favorite_border,
            color: favorite ? pink : purple,
          ),
          onPressed: () => setState(() {
            favorite ? favorites.remove(name) : favorites.add(name);
          }),
        ),
        onTap: () => openPage(
          name,
          SimpleListPage(
            title: name,
            details:
                'بيانات المورد والأسعار والحد الأدنى للطلب تُستكمل عند تفعيل حساب المورد.',
            icon: Icons.store,
          ),
        ),
      ),
    );
  }

  Widget marketPage() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'سوق التجار',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: purple,
            ),
          ),
          const SizedBox(height: 8),
          const Text('طلبات شراء وعروض بيع بين التجار.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => openPage(
              'إضافة إعلان',
              const MarketPostScreen(),
            ),
            icon: const Icon(Icons.add),
            label: const Text('إضافة طلب شراء أو عرض بيع'),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 12),
          const MarketPostsSection(),
        ],
      );

  Widget cartPage() {
    final entries = cart.entries.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'سلة المشتريات',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: purple,
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 65),
                SizedBox(height: 12),
                Text('السلة فارغة'),
              ],
            ),
          ),
        ...entries.map((entry) {
          final product =
              products.firstWhere((p) => p.name == entry.key);
          return Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(product.icon, color: purple),
              title: Text(product.name),
              subtitle: Text(
                '${product.price.toStringAsFixed(0)} ج.م × ${entry.value}',
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      if (entry.value <= 1) {
                        cart.remove(entry.key);
                      } else {
                        cart[entry.key] = entry.value - 1;
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${entry.value}'),
                  IconButton(
                    onPressed: () => setState(
                      () => cart[entry.key] = entry.value + 1,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        if (entries.isNotEmpty) ...[
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإجمالي التقديري',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${total.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الأسعار المعروضة تجريبية وليست أسعار مورد مؤكدة.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => openPage(
                        'إتمام الطلب',
                        CheckoutScreen(
                          total: total,
                          itemCount: cart.values.fold<int>(
                            0,
                            (a, b) => a + b,
                          ),
                        ),
                      ),
                      child: const Text('متابعة إتمام الطلب'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget morePage() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: purple, size: 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'النشاط: $activity',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Text(
                        'بنربط السوق ببعضه',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          menuItem(
            Icons.person_outline,
            'تسجيل الدخول',
            () => openPage('تسجيل الدخول', const LoginScreen()),
          ),
          menuItem(
            Icons.person_add_alt_1,
            'تسجيل نشاط جديد',
            () => openPage('تسجيل نشاط جديد', const RegisterScreen()),
          ),
          menuItem(
            Icons.badge_outlined,
            'تصنيف العميل',
            () => openPage(
              'تصنيف العميل',
              ClassificationScreen(
                title: 'تصنيف العميل',
                description: 'اختر التصنيف الذي يصف نشاط العميل.',
                choices: customerTypes,
                icon: Icons.storefront,
              ),
            ),
          ),
          menuItem(
            Icons.inventory_2_outlined,
            'تصنيف المورد',
            () => openPage(
              'تصنيف المورد',
              ClassificationScreen(
                title: 'تصنيف المورد',
                description: 'اختر طبيعة عمل المورد.',
                choices: supplierTypes,
                icon: Icons.warehouse,
              ),
            ),
          ),
          menuItem(
            Icons.support_agent,
            'تصنيف المندوب',
            () => openPage(
              'تصنيف المندوب',
              ClassificationScreen(
                title: 'تصنيف المندوب',
                description: 'اختر الوظيفة المناسبة للمندوب.',
                choices: delegateTypes,
                icon: Icons.badge,
              ),
            ),
          ),
          menuItem(
            Icons.local_offer_outlined,
            'العروض',
            () => openPage(
              'العروض',
              const SimpleListPage(
                title: 'العروض',
                details:
                    'ستظهر هنا عروض الموردين بعد إدخالها في قاعدة البيانات.',
                icon: Icons.local_offer,
              ),
            ),
          ),
          menuItem(
            Icons.receipt_long,
            'سجل طلباتي',
            () => openPage('سجل طلباتي', const MyOrdersScreen()),
          ),
          menuItem(
            Icons.favorite_border,
            'المفضلة',
            () => openPage(
              'المفضلة',
              FavoritesScreen(names: favorites.toList()),
            ),
          ),
          menuItem(
            Icons.account_balance_wallet_outlined,
            'رصيدي ونقاطي',
            () => openPage('رصيدي ونقاطي', const WalletOverviewScreen()),
          ),
          menuItem(
            Icons.settings_outlined,
            'إعدادات الحساب',
            () => openPage('إعدادات الحساب', const ProfileEditorScreen()),
          ),
          menuItem(
            Icons.logout_rounded,
            'تسجيل الخروج',
            logout,
          ),
        ],
      );

  Future<void> logout() async {
    try {
      await database?.auth.signOut();
    } catch (_) {
      // العودة إلى شاشة البداية حتى لو تعذر الاتصال بالخدمة.
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: WelcomeScreen(),
        ),
      ),
      (route) => false,
    );
  }

  Widget menuItem(IconData icon, String title, VoidCallback onTap) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: purple),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({
    super.key,
    required this.title,
    required this.description,
    required this.choices,
    required this.icon,
  });

  final String title;
  final String description;
  final List<String> choices;
  final IconData icon;

  @override
  State<ClassificationScreen> createState() =>
      _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  String? selected;
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.choices
        .where((e) => e.contains(search))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(widget.icon, size: 54, color: purple),
              const SizedBox(height: 8),
              Text(
                widget.description,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن تصنيف',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: filtered.map((choice) {
              return RadioListTile<String>(
                value: choice,
                groupValue: selected,
                activeColor: purple,
                title: Text(choice),
                onChanged: (v) => setState(() => selected = v),
              );
            }).toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text('اعتماد التصنيف'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialAccountType = 'عميل',
  });

  final String initialAccountType;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final whatsappController = TextEditingController();
  final addressController = TextEditingController();
  final landmarkController = TextEditingController();
  final districtController = TextEditingController();
  final areaController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String activity = 'مواد غذائية';
  late String accountType;

  @override
  void initState() {
    super.initState();
    const accountTypes = {'عميل', 'مورد', 'مندوب', 'شركة شحن', 'إدارة نشاط'};
    accountType = accountTypes.contains(widget.initialAccountType)
        ? widget.initialAccountType
        : 'عميل';
  }
  String? customerType;
  String? supplierType;
  String? delegateType;
  String governorate = 'القاهرة';
  bool sameWhatsApp = true;
  bool busy = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    whatsappController.dispose();
    addressController.dispose();
    landmarkController.dispose();
    districtController.dispose();
    areaController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    final client = database;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      final response = await client.auth.signUp(
        phone: phoneController.text.trim(),
        password: passwordController.text,
        data: {
          'full_name': nameController.text.trim(),
          'account_type': accountType,
          'activity_type': activity,
          'customer_type': customerType,
          'supplier_type': supplierType,
          'delegate_type': delegateType,
          'whatsapp_phone': sameWhatsApp
              ? phoneController.text.trim()
              : whatsappController.text.trim(),
          'governorate': governorate,
          'district': districtController.text.trim(),
          'area': areaController.text.trim(),
          'address': addressController.text.trim(),
          'landmark': landmarkController.text.trim(),
        },
      );

      if (mounted && response.user != null && response.session == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: OtpVerificationScreen(
                phone: phoneController.text.trim(),
              ),
            ),
          ),
        );
      } else if (mounted && response.session != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يكتمل إنشاء الحساب. راجع إعدادات مصادقة الهاتف في Supabase.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر التسجيل. راجع إعدادات مصادقة الهاتف في Supabase.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.person_add_alt_1, size: 54, color: purple),
        const SizedBox(height: 8),
        const Text(
          'إنشاء حساب جديد',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Form(
          key: formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: activity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع النشاط',
                ),
                items: activityTypes
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (v) => setState(
                  () => activity = v ?? 'مواد غذائية',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: accountType,
                decoration: const InputDecoration(
                  labelText: 'نوع الحساب',
                ),
                items: const [
                  DropdownMenuItem(value: 'عميل', child: Text('عميل')),
                  DropdownMenuItem(value: 'مورد', child: Text('مورد')),
                  DropdownMenuItem(value: 'مندوب', child: Text('مندوب')),
                  DropdownMenuItem(
                    value: 'شركة شحن',
                    child: Text('شركة شحن'),
                  ),
                  DropdownMenuItem(
                    value: 'إدارة نشاط',
                    child: Text('إدارة نشاط'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  accountType = v ?? 'عميل';
                  customerType = null;
                  supplierType = null;
                  delegateType = null;
                }),
              ),
              const SizedBox(height: 12),
              if (accountType == 'عميل')
                classificationDropdown(
                  'تصنيف العميل',
                  customerType,
                  customerTypes,
                  (v) => customerType = v,
                ),
              if (accountType == 'مورد')
                classificationDropdown(
                  'تصنيف المورد',
                  supplierType,
                  supplierTypes,
                  (v) => supplierType = v,
                ),
              if (accountType == 'مندوب')
                classificationDropdown(
                  'تصنيف المندوب',
                  delegateType,
                  delegateTypes,
                  (v) => delegateType = v,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم النشاط أو صاحب الحساب',
                ),
                validator: requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف المسجل لدينا',
                ),
                validator: (v) =>
                    v == null || v.trim().length < 8
                        ? 'أدخل رقم هاتف صحيحًا'
                        : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: sameWhatsApp,
                title: const Text('رقم واتساب هو نفس رقم الهاتف'),
                onChanged: (v) =>
                    setState(() => sameWhatsApp = v ?? true),
              ),
              if (!sameWhatsApp) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم واتساب',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: governorate,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: const [
                  DropdownMenuItem(value: 'القاهرة', child: Text('القاهرة')),
                  DropdownMenuItem(value: 'الجيزة', child: Text('الجيزة')),
                  DropdownMenuItem(
                    value: 'القليوبية',
                    child: Text('القليوبية'),
                  ),
                  DropdownMenuItem(
                    value: 'الإسكندرية',
                    child: Text('الإسكندرية'),
                  ),
                  DropdownMenuItem(
                    value: 'الشرقية',
                    child: Text('الشرقية'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => governorate = v ?? 'القاهرة'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: districtController,
                decoration: const InputDecoration(
                  labelText: 'المركز أو المدينة',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: areaController,
                decoration: const InputDecoration(
                  labelText: 'القرية أو الحي',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'العنوان بالتفصيل',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: landmarkController,
                decoration: const InputDecoration(
                  labelText: 'أقرب علامة مميزة (اختياري)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  helperText: '8 أحرف على الأقل مع حرف كبير وصغير ورقم ورمز',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(v) ||
                      !RegExp(r'[a-z]').hasMatch(v) ||
                      !RegExp(r'\d').hasMatch(v) ||
                      !RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
                    return 'أضف حرفًا كبيرًا وصغيرًا ورقمًا ورمزًا';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (v) => v != passwordController.text
                    ? 'كلمتا المرور غير متطابقتين'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : register,
                  child: Text(busy ? 'جارٍ التسجيل...' : 'إنشاء الحساب'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'التسجيل الفعلي يعتمد على إعداد مصادقة الهاتف وسياسات قاعدة البيانات.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget classificationDropdown(
    String label,
    String? value,
    List<String> choices,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: choices
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'اختر $label' : null,
    );
  }
}

String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'هذا الحقل مطلوب';
  }
  return null;
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final codeController = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{6}
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (phone.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب رقم الهاتف وكلمة المرور.')),
      );
      return;
    }

    final client = database;
    if (client == null) return;

    setState(() => busy = true);
    try {
      await client.auth.signInWithPassword(
        phone: phone.text.trim(),
        password: password.text,
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تسجيل الدخول. راجع إعدادات مصادقة الهاتف في Supabase.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.lock_outline, size: 60, color: purple),
          const SizedBox(height: 12),
          const Text(
            'تسجيل الدخول',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'اكتب هنا رقمك المسجل لدينا',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'اكتب كلمة المرور الخاصة بك',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : login,
            child: Text(busy ? 'جارٍ الدخول...' : 'دخول'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen(),
              ),
            ),
            child: const Text('نسيت كلمة المرور؟'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ),
            ),
            child: const Text('إنشاء نشاط جديد'),
          ),
        ],
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool codeSent = false;
  bool busy = false;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    final phone = phoneController.text.trim();
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الهاتف المسجل في الحساب.')),
      );
      return;
    }
    final client = database;
    if (client == null) return;
    setState(() => busy = true);
    try {
      await client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: false,
      );
      if (mounted) {
        setState(() => codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم طلب رمز التحقق إذا كان الرقم مسجلًا.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الرمز. راجع إعدادات SMS أو حاول لاحقًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePassword() async {
    final code = codeController.text.trim();
    final password = passwordController.text;
    if (!RegExp(r'^\d{6}
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.itemCount,
  });

  final double total;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('عدد الوحدات'),
            trailing: Text('$itemCount'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('الإجمالي التقديري'),
            trailing: Text('${total.toStringAsFixed(2)} ج.م'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'طريقة الدفع',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        ...[
          'نقدي',
          'آجل من المورد',
          'محفظة كاش',
          'تحويل بنكي',
          'من الرصيد',
        ].map(
          (method) => ListTile(
            leading: const Icon(Icons.payments_outlined, color: purple),
            title: Text(method),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('طريقة الدفع المختارة: $method')),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'هذه شاشة تجهيز الطلب. إرسال الطلب وحفظ بنوده يحتاج استكمال الربط مع جداول الطلبات وسياسات قاعدة البيانات.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class MarketPostsSection extends StatefulWidget {
  const MarketPostsSection({super.key});

  @override
  State<MarketPostsSection> createState() => _MarketPostsSectionState();
}

class _MarketPostsSectionState extends State<MarketPostsSection> {
  late Future<List<Map<String, dynamic>>> postsFuture;

  @override
  void initState() {
    super.initState();
    postsFuture = TraderMarketService().getPosts();
  }

  Future<void> refresh() async {
    setState(() => postsFuture = TraderMarketService().getPosts());
    await postsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(color: purple)),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 38, color: purple),
                  const SizedBox(height: 8),
                  const Text('تعذر تحميل إعلانات السوق من قاعدة البيانات.'),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }
        final posts = snapshot.data ?? const <Map<String, dynamic>>[];
        if (posts.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Center(child: Text('لا توجد إعلانات منشورة حتى الآن.')),
            ),
          );
        }
        return Column(
          children: posts.map((post) {
            final type = (post['post_type'] ?? '').toString();
            final isBuy = type == 'buy' || type == 'request';
            final color = isBuy ? purple : orange;
            final title = (post['title'] ?? 'إعلان').toString();
            final details = (post['description'] ?? post['details'] ?? '').toString();
            final quantity = post['quantity'];
            final governorate = (post['governorate'] ?? '').toString();
            final subtitle = [
              isBuy ? 'طلب شراء' : 'عرض بيع',
              if (quantity != null) 'الكمية: $quantity ${post['unit'] ?? ''}',
              if (governorate.isNotEmpty) governorate,
              details,
            ].where((part) => part.toString().trim().isNotEmpty).join('\\n');
            return MarketCard(
              title: title,
              type: isBuy ? 'طلب شراء' : 'عرض بيع',
              details: subtitle,
              color: color,
            );
          }).toList(),
        );
      },
    );
  }
}

class MarketPostScreen extends StatefulWidget {
  const MarketPostScreen({super.key});

  @override
  State<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends State<MarketPostScreen> {
  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  String type = 'buy';
  bool busy = false;

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  Future<void> savePost() async {
    if (titleController.text.trim().isEmpty ||
        detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل عنوان الإعلان والتفاصيل.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await TraderMarketService().createPost(
        title: titleController.text.trim(),
        description: detailsController.text.trim(),
        postType: type,
        activityType: 'مواد غذائية',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر الإعلان في سوق التجار.')),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر نشر الإعلان. تأكد من تسجيل الدخول وإعداد قاعدة البيانات.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'نوع الإعلان'),
            items: const [
              DropdownMenuItem(value: 'buy', child: Text('طلب شراء')),
              DropdownMenuItem(value: 'sell', child: Text('عرض بيع')),
            ],
            onChanged: (v) => setState(() => type = v ?? 'buy'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'التفاصيل'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : savePost,
            child: Text(busy ? 'جارٍ النشر...' : 'نشر الإعلان'),
          ),
        ],
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> notificationsFuture;

  @override
  void initState() {
    super.initState();
    notificationsFuture = NotificationService().getMyNotifications();
  }

  Future<void> reload() async {
    setState(() => notificationsFuture = NotificationService().getMyNotifications());
    await notificationsFuture;
  }

  Future<void> markRead(String id) async {
    try {
      await NotificationService().markAsRead(id);
      await reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث الإشعار.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: purple));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 56, color: purple),
                  const Text('سجّل الدخول لعرض إشعارات حسابك.'),
                  TextButton(onPressed: reload, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          );
        }
        final notifications = snapshot.data ?? const <Map<String, dynamic>>[];
        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              children: const [
                SizedBox(height: 100),
                Icon(Icons.notifications_none, size: 62, color: purple),
                SizedBox(height: 12),
                Center(child: Text('لا توجد إشعارات جديدة.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await NotificationService().markAllAsRead();
                      await reload();
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر تحديث الإشعارات.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text('تعليم الكل كمقروء'),
                ),
              ),
              ...notifications.map((item) {
                final id = (item['id'] ?? '').toString();
                final isRead = item['is_read'] == true;
                final title = (item['title'] ?? 'إشعار').toString();
                final body = (item['body'] ?? '').toString();
                final date = item['created_at']?.toString() ?? '';
                return Card(
                  color: isRead ? Colors.white : const Color(0xFFF3ECFA),
                  child: ListTile(
                    leading: Icon(
                      isRead ? Icons.notifications_none : Icons.notifications_active,
                      color: isRead ? Colors.blueGrey : purple,
                    ),
                    title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text([body, if (date.isNotEmpty) date.split('T').first].where((v) => v.isNotEmpty).join('\\n')),
                    trailing: isRead ? null : IconButton(
                      tooltip: 'تعليم كمقروء',
                      onPressed: id.isEmpty ? null : () => markRead(id),
                      icon: const Icon(Icons.done),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final whatsappController = TextEditingController();
  final districtController = TextEditingController();
  final areaController = TextEditingController();
  final addressController = TextEditingController();
  final service = ProfileService();
  String activity = 'مواد غذائية';
  String governorate = 'القاهرة';
  bool loading = true;
  bool saving = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    whatsappController.dispose();
    districtController.dispose();
    areaController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final profile = await service.getMyProfile();
      if (profile != null) {
        nameController.text = (profile['full_name'] ?? '').toString();
        whatsappController.text = (profile['whatsapp_phone'] ?? '').toString();
        districtController.text = (profile['district'] ?? '').toString();
        areaController.text = (profile['area'] ?? '').toString();
        addressController.text = (profile['address'] ?? '').toString();
        final savedActivity = (profile['activity_type'] ?? '').toString();
        if (activityTypes.contains(savedActivity)) activity = savedActivity;
        final savedGovernorate = (profile['governorate'] ?? '').toString();
        if (const ['القاهرة','الجيزة','القليوبية','الإسكندرية','الشرقية'].contains(savedGovernorate)) {
          governorate = savedGovernorate;
        }
      }
    } catch (_) {
      loadError = 'تعذر تحميل البيانات. تأكد من تسجيل الدخول.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await service.saveMyProfile(
        fullName: nameController.text,
        activityType: activity,
        whatsappPhone: whatsappController.text,
        governorate: governorate,
        district: districtController.text,
        area: areaController.text,
        address: addressController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ بيانات الحساب.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ البيانات. تأكد من تسجيل الدخول وصلاحيات الحساب.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: purple));
    }
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 58, color: purple),
              Text(loadError!, textAlign: TextAlign.center),
              TextButton(onPressed: () => setState(() { loading = true; loadError = null; loadProfile(); }), child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.manage_accounts_outlined, size: 58, color: purple),
          const SizedBox(height: 8),
          const Text('بيانات الحساب', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'الاسم أو اسم النشاط'),
            validator: requiredValidator,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: activity,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع النشاط'),
            items: activityTypes.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setState(() => activity = value ?? activity),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم واتساب'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: governorate,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المحافظة'),
            items: const [
              DropdownMenuItem(value: 'القاهرة', child: Text('القاهرة')),
              DropdownMenuItem(value: 'الجيزة', child: Text('الجيزة')),
              DropdownMenuItem(value: 'القليوبية', child: Text('القليوبية')),
              DropdownMenuItem(value: 'الإسكندرية', child: Text('الإسكندرية')),
              DropdownMenuItem(value: 'الشرقية', child: Text('الشرقية')),
            ],
            onChanged: (value) => setState(() => governorate = value ?? governorate),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: districtController, decoration: const InputDecoration(labelText: 'المركز أو المدينة')),
          const SizedBox(height: 12),
          TextFormField(controller: areaController, decoration: const InputDecoration(labelText: 'القرية أو الحي')),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'العنوان بالتفصيل'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ البيانات'),
          ),
          const SizedBox(height: 8),
          const Text(
            'تغيير نوع الحساب وحالة الاعتماد ورقم الدخول يخضع لصلاحيات النظام.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class WalletOverviewScreen extends StatefulWidget {
  const WalletOverviewScreen({super.key});

  @override
  State<WalletOverviewScreen> createState() => _WalletOverviewScreenState();
}

class _WalletOverviewScreenState extends State<WalletOverviewScreen> {
  late Future<Map<String, dynamic>> walletFuture;

  @override
  void initState() {
    super.initState();
    walletFuture = loadWallet();
  }

  Future<Map<String, dynamic>> loadWallet() async {
    final service = WalletService();
    final balance = await service.getBalance();
    final transactions = await service.getTransactions(limit: 30);
    return {'balance': balance, 'transactions': transactions};
  }

  Future<void> reload() async {
    setState(() => walletFuture = loadWallet());
    await walletFuture;
  }

  Future<void> requestTopUp() async {
    final amountController = TextEditingController();
    String method = 'تحويل بنكي';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('طلب شحن المحفظة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'مبلغ الشحن بالجنيه'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: const [
                  DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي')),
                  DropdownMenuItem(value: 'محفظة إلكترونية', child: Text('محفظة إلكترونية')),
                  DropdownMenuItem(value: 'إيداع نقدي', child: Text('إيداع نقدي')),
                ],
                onChanged: (value) => setDialogState(
                  () => method = value ?? 'تحويل بنكي',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيُسجل الطلب للمراجعة، ولن يتغير الرصيد قبل اعتماد الشحن.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );

    if (accepted != true) {
      amountController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    if (amount == null || !amount.isFinite || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل مبلغًا صحيحًا أكبر من صفر.')),
        );
      }
      return;
    }

    try {
      await WalletService().requestTopUp(
        amount: amount,
        paymentMethod: method,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل طلب الشحن للمراجعة.')),
        );
        await reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال طلب الشحن. سجّل الدخول وحاول مرة أخرى.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: walletFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: purple));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 58, color: purple),
                  const SizedBox(height: 12),
                  const Text('سجّل الدخول لعرض محفظتك ومعاملاتك.'),
                  TextButton(onPressed: reload, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const {};
        final balance = data['balance'] as double? ?? 0;
        final transactions = (data['transactions'] as List<Map<String, dynamic>>?) ?? const [];
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [purple, Color(0xFF7026A8)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      '${balance.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: requestTopUp,
                      icon: const Icon(Icons.add_card),
                      label: const Text('طلب شحن المحفظة'),
                      style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: purple),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('آخر المعاملات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (transactions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لا توجد معاملات مسجلة حتى الآن.'),
                  ),
                ),
              ...transactions.map((transaction) {
                final amount = transaction['amount'];
                final type = (transaction['transaction_type'] ?? transaction['description'] ?? 'معاملة').toString();
                final status = (transaction['status'] ?? '').toString();
                final date = transaction['created_at']?.toString() ?? '';
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz, color: purple),
                    title: Text(type),
                    subtitle: Text([status, if (date.isNotEmpty) date.split('T').first].where((v) => v.isNotEmpty).join(' • ')),
                    trailing: Text('${amount ?? 0} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Map<String, dynamic>>> ordersFuture;

  @override
  void initState() {
    super.initState();
    ordersFuture = OrderStatusService().getMyOrders();
  }

  Future<void> reload() async {
    setState(() => ordersFuture = OrderStatusService().getMyOrders());
    await ordersFuture;
  }

  Color statusColor(String status) {
    switch (status) {
      case 'تم التسليم':
        return Colors.green;
      case 'مُلغي':
        return Colors.red;
      case 'توصيل':
        return orange;
      case 'تحميل':
      case 'تنفيذ':
        return purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: purple));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 56, color: purple),
                  const SizedBox(height: 12),
                  const Text('سجّل الدخول لعرض طلباتك، أو تحقق من اتصال قاعدة البيانات.'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: reload, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          );
        }
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        if (orders.isEmpty) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              children: const [
                SizedBox(height: 100),
                Icon(Icons.receipt_long_outlined, size: 62, color: purple),
                SizedBox(height: 12),
                Center(child: Text('لا توجد طلبات مسجلة حتى الآن.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = (order['status'] ?? 'انتظار قبول').toString();
              final number = (order['order_number'] ?? order['id'] ?? '').toString();
              final total = order['total_amount'];
              final date = order['created_at']?.toString() ?? '';
              final isSupplier = order['supplier_id'] ==
                  database?.auth.currentUser?.id;
              return Card(
                color: Colors.white,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor(status).withOpacity(.12),
                    child: Icon(Icons.receipt_long, color: statusColor(status)),
                  ),
                  title: Text('طلب #$number', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${isSupplier ? 'طلب وارد' : 'طلبك'} • $status'),
                  trailing: const Icon(Icons.expand_more),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('الإجمالي: ${total ?? 0} ج.م'),
                    ),
                    if (date.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('تاريخ الطلب: ${date.split('T').first}'),
                      ),
                    if (order['payment_method'] != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('الدفع: ${order['payment_method']}'),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Center(child: Text('لم تضف عناصر للمفضلة بعد.'));
    }

    return ListView(
      children: names
          .map(
            (name) => ListTile(
              leading: const Icon(Icons.favorite, color: pink),
              title: Text(name),
            ),
          )
          .toList(),
    );
  }
}

class SimpleListPage extends StatelessWidget {
  const SimpleListPage({
    super.key,
    required this.title,
    required this.details,
    required this.icon,
  });

  final String title;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(icon, size: 64, color: purple),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(details, textAlign: TextAlign.center),
        ],
      );
}

class MarketCard extends StatelessWidget {
  const MarketCard({
    super.key,
    required this.title,
    required this.type,
    required this.details,
    required this.color,
  });

  final String title;
  final String type;
  final String details;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(Icons.storefront, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$type\n$details'),
          isThreeLine: true,
        ),
      );
}
).hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز التحقق المكوّن من 6 أرقام.')),
      );
      return;
    }

    final client = database;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await client.auth.verifyOTP(
        phone: widget.phone,
        token: code,
        type: OtpType.sms,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل الحساب بنجاح.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رمز التحقق غير صحيح أو انتهت صلاحيته. حاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.verified_user_outlined, size: 68, color: purple),
        const SizedBox(height: 18),
        const Text(
          'تأكيد رقم الهاتف',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى ${widget.phone}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            letterSpacing: 10,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            labelText: 'رمز التحقق',
            counterText: '',
            prefixIcon: Icon(Icons.password),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy ? null : verifyCode,
          child: Text(busy ? 'جارٍ التحقق...' : 'تأكيد وتفعيل الحساب'),
        ),
        const SizedBox(height: 12),
        const Text(
          'يلزم تفعيل إرسال رسائل SMS وإعداد مزود الهاتف في مشروع Supabase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (phone.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب رقم الهاتف وكلمة المرور.')),
      );
      return;
    }

    final client = database;
    if (client == null) return;

    setState(() => busy = true);
    try {
      await client.auth.signInWithPassword(
        phone: phone.text.trim(),
        password: password.text,
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تسجيل الدخول. راجع إعدادات مصادقة الهاتف في Supabase.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.lock_outline, size: 60, color: purple),
          const SizedBox(height: 12),
          const Text(
            'تسجيل الدخول',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'اكتب هنا رقمك المسجل لدينا',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'اكتب كلمة المرور الخاصة بك',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : login,
            child: Text(busy ? 'جارٍ الدخول...' : 'دخول'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ),
            ),
            child: const Text('إنشاء نشاط جديد'),
          ),
        ],
      );
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.itemCount,
  });

  final double total;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('عدد الوحدات'),
            trailing: Text('$itemCount'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('الإجمالي التقديري'),
            trailing: Text('${total.toStringAsFixed(2)} ج.م'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'طريقة الدفع',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        ...[
          'نقدي',
          'آجل من المورد',
          'محفظة كاش',
          'تحويل بنكي',
          'من الرصيد',
        ].map(
          (method) => ListTile(
            leading: const Icon(Icons.payments_outlined, color: purple),
            title: Text(method),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('طريقة الدفع المختارة: $method')),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'هذه شاشة تجهيز الطلب. إرسال الطلب وحفظ بنوده يحتاج استكمال الربط مع جداول الطلبات وسياسات قاعدة البيانات.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class MarketPostScreen extends StatefulWidget {
  const MarketPostScreen({super.key});

  @override
  State<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends State<MarketPostScreen> {
  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  String type = 'buy';

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'نوع الإعلان'),
            items: const [
              DropdownMenuItem(value: 'buy', child: Text('طلب شراء')),
              DropdownMenuItem(value: 'sell', child: Text('عرض بيع')),
            ],
            onChanged: (v) => setState(() => type = v ?? 'buy'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'التفاصيل'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'واجهة الإعلان جاهزة. حفظ الإعلان يحتاج ربط حقول الجدول وسياساته.',
                ),
              ),
            ),
            child: const Text('حفظ الإعلان'),
          ),
        ],
      );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Center(child: Text('لم تضف عناصر للمفضلة بعد.'));
    }

    return ListView(
      children: names
          .map(
            (name) => ListTile(
              leading: const Icon(Icons.favorite, color: pink),
              title: Text(name),
            ),
          )
          .toList(),
    );
  }
}

class SimpleListPage extends StatelessWidget {
  const SimpleListPage({
    super.key,
    required this.title,
    required this.details,
    required this.icon,
  });

  final String title;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(icon, size: 64, color: purple),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(details, textAlign: TextAlign.center),
        ],
      );
}

class MarketCard extends StatelessWidget {
  const MarketCard({
    super.key,
    required this.title,
    required this.type,
    required this.details,
    required this.color,
  });

  final String title;
  final String type;
  final String details;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(Icons.storefront, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$type\n$details'),
          isThreeLine: true,
        ),
      );
}
).hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز التحقق المكوّن من 6 أرقام.')),
      );
      return;
    }
    if (password.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور تحتاج 8 أحرف وحرفًا كبيرًا وصغيرًا ورقمًا ورمزًا.')),
      );
      return;
    }
    if (password != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور غير متطابقتين.')),
      );
      return;
    }
    final client = database;
    if (client == null) return;
    setState(() => busy = true);
    try {
      await client.auth.verifyOTP(
        phone: phoneController.text.trim(),
        token: code,
        type: OtpType.sms,
      );
      await client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح.')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تغيير كلمة المرور. تحقق من الرمز وإعدادات الهاتف.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.lock_reset_rounded, size: 62, color: purple),
        const SizedBox(height: 12),
        const Text(
          'استعادة كلمة المرور',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف المسجل',
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : sendCode,
          icon: const Icon(Icons.sms_outlined),
          label: Text(busy ? 'جارٍ إرسال الرمز...' : 'إرسال رمز التحقق'),
        ),
        if (codeSent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'رمز التحقق المرسل برسالة SMS',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : changePassword,
            child: Text(busy ? 'جارٍ التحديث...' : 'تأكيد وتغيير كلمة المرور'),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'تعتمد استعادة الحساب على تفعيل مصادقة الهاتف وإعداد مزود SMS في Supabase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.itemCount,
  });

  final double total;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('عدد الوحدات'),
            trailing: Text('$itemCount'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('الإجمالي التقديري'),
            trailing: Text('${total.toStringAsFixed(2)} ج.م'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'طريقة الدفع',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        ...[
          'نقدي',
          'آجل من المورد',
          'محفظة كاش',
          'تحويل بنكي',
          'من الرصيد',
        ].map(
          (method) => ListTile(
            leading: const Icon(Icons.payments_outlined, color: purple),
            title: Text(method),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('طريقة الدفع المختارة: $method')),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'هذه شاشة تجهيز الطلب. إرسال الطلب وحفظ بنوده يحتاج استكمال الربط مع جداول الطلبات وسياسات قاعدة البيانات.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class MarketPostScreen extends StatefulWidget {
  const MarketPostScreen({super.key});

  @override
  State<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends State<MarketPostScreen> {
  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  String type = 'buy';

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'نوع الإعلان'),
            items: const [
              DropdownMenuItem(value: 'buy', child: Text('طلب شراء')),
              DropdownMenuItem(value: 'sell', child: Text('عرض بيع')),
            ],
            onChanged: (v) => setState(() => type = v ?? 'buy'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'التفاصيل'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'واجهة الإعلان جاهزة. حفظ الإعلان يحتاج ربط حقول الجدول وسياساته.',
                ),
              ),
            ),
            child: const Text('حفظ الإعلان'),
          ),
        ],
      );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Center(child: Text('لم تضف عناصر للمفضلة بعد.'));
    }

    return ListView(
      children: names
          .map(
            (name) => ListTile(
              leading: const Icon(Icons.favorite, color: pink),
              title: Text(name),
            ),
          )
          .toList(),
    );
  }
}

class SimpleListPage extends StatelessWidget {
  const SimpleListPage({
    super.key,
    required this.title,
    required this.details,
    required this.icon,
  });

  final String title;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(icon, size: 64, color: purple),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(details, textAlign: TextAlign.center),
        ],
      );
}

class MarketCard extends StatelessWidget {
  const MarketCard({
    super.key,
    required this.title,
    required this.type,
    required this.details,
    required this.color,
  });

  final String title;
  final String type;
  final String details;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(Icons.storefront, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$type\n$details'),
          isThreeLine: true,
        ),
      );
}
).hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز التحقق المكوّن من 6 أرقام.')),
      );
      return;
    }

    final client = database;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await client.auth.verifyOTP(
        phone: widget.phone,
        token: code,
        type: OtpType.sms,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل الحساب بنجاح.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رمز التحقق غير صحيح أو انتهت صلاحيته. حاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.verified_user_outlined, size: 68, color: purple),
        const SizedBox(height: 18),
        const Text(
          'تأكيد رقم الهاتف',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى ${widget.phone}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            letterSpacing: 10,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            labelText: 'رمز التحقق',
            counterText: '',
            prefixIcon: Icon(Icons.password),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy ? null : verifyCode,
          child: Text(busy ? 'جارٍ التحقق...' : 'تأكيد وتفعيل الحساب'),
        ),
        const SizedBox(height: 12),
        const Text(
          'يلزم تفعيل إرسال رسائل SMS وإعداد مزود الهاتف في مشروع Supabase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (phone.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب رقم الهاتف وكلمة المرور.')),
      );
      return;
    }

    final client = database;
    if (client == null) return;

    setState(() => busy = true);
    try {
      await client.auth.signInWithPassword(
        phone: phone.text.trim(),
        password: password.text,
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تسجيل الدخول. راجع إعدادات مصادقة الهاتف في Supabase.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.lock_outline, size: 60, color: purple),
          const SizedBox(height: 12),
          const Text(
            'تسجيل الدخول',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'اكتب هنا رقمك المسجل لدينا',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'اكتب كلمة المرور الخاصة بك',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : login,
            child: Text(busy ? 'جارٍ الدخول...' : 'دخول'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ),
            ),
            child: const Text('إنشاء نشاط جديد'),
          ),
        ],
      );
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.itemCount,
  });

  final double total;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('عدد الوحدات'),
            trailing: Text('$itemCount'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('الإجمالي التقديري'),
            trailing: Text('${total.toStringAsFixed(2)} ج.م'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'طريقة الدفع',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        ...[
          'نقدي',
          'آجل من المورد',
          'محفظة كاش',
          'تحويل بنكي',
          'من الرصيد',
        ].map(
          (method) => ListTile(
            leading: const Icon(Icons.payments_outlined, color: purple),
            title: Text(method),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('طريقة الدفع المختارة: $method')),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'هذه شاشة تجهيز الطلب. إرسال الطلب وحفظ بنوده يحتاج استكمال الربط مع جداول الطلبات وسياسات قاعدة البيانات.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class MarketPostScreen extends StatefulWidget {
  const MarketPostScreen({super.key});

  @override
  State<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends State<MarketPostScreen> {
  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  String type = 'buy';

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'نوع الإعلان'),
            items: const [
              DropdownMenuItem(value: 'buy', child: Text('طلب شراء')),
              DropdownMenuItem(value: 'sell', child: Text('عرض بيع')),
            ],
            onChanged: (v) => setState(() => type = v ?? 'buy'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'التفاصيل'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'واجهة الإعلان جاهزة. حفظ الإعلان يحتاج ربط حقول الجدول وسياساته.',
                ),
              ),
            ),
            child: const Text('حفظ الإعلان'),
          ),
        ],
      );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Center(child: Text('لم تضف عناصر للمفضلة بعد.'));
    }

    return ListView(
      children: names
          .map(
            (name) => ListTile(
              leading: const Icon(Icons.favorite, color: pink),
              title: Text(name),
            ),
          )
          .toList(),
    );
  }
}

class SimpleListPage extends StatelessWidget {
  const SimpleListPage({
    super.key,
    required this.title,
    required this.details,
    required this.icon,
  });

  final String title;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(icon, size: 64, color: purple),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(details, textAlign: TextAlign.center),
        ],
      );
}

class MarketCard extends StatelessWidget {
  const MarketCard({
    super.key,
    required this.title,
    required this.type,
    required this.details,
    required this.color,
  });

  final String title;
  final String type;
  final String details;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(Icons.storefront, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$type\n$details'),
          isThreeLine: true,
        ),
      );
}
