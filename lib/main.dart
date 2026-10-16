import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainShell(),
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
              const SimpleListPage(
                title: 'الإشعارات',
                details:
                    'ستظهر هنا تحديثات الطلبات والعروض والتنبيهات بعد تفعيلها.',
                icon: Icons.notifications,
              ),
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
          const MarketCard(
            title: 'مطلوب زيت خليط',
            type: 'طلب شراء',
            details: 'مثال توضيحي لطلب توريد.',
            color: purple,
          ),
          const MarketCard(
            title: 'عرض مكرونة معبأة',
            type: 'عرض بيع',
            details: 'مثال توضيحي لعرض مورد.',
            color: orange,
          ),
          const SizedBox(height: 12),
          const Text(
            'الإعلانات المعروضة تجريبية وليست عروضًا مؤكدة.',
            style: TextStyle(color: Colors.black54),
          ),
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
            () => openPage(
              'سجل طلباتي',
              const SimpleListPage(
                title: 'الطلبات',
                details:
                    'حالات الطلب: انتظار القبول، التنفيذ، التحميل، التوصيل، تم التسليم، ملغي.',
                icon: Icons.receipt_long,
              ),
            ),
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
            () => openPage(
              'رصيدي ونقاطي',
              const SimpleListPage(
                title: 'الرصيد والنقاط',
                details:
                    'الأرصدة والنقاط ستظهر بعد تفعيل نظام الحسابات.',
                icon: Icons.account_balance_wallet,
              ),
            ),
          ),
          menuItem(
            Icons.settings_outlined,
            'إعدادات الحساب',
            () => openPage(
              'إعدادات الحساب',
              const SimpleListPage(
                title: 'إعدادات الحساب',
                details: 'إدارة البيانات والعناوين وكلمة المرور.',
                icon: Icons.settings,
              ),
            ),
          ),
        ],
      );

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
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final whatsappController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();

  String activity = 'مواد غذائية';
  String accountType = 'عميل';
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
    passwordController.dispose();
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
      await client.auth.signUp(
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
          'address': addressController.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال طلب التسجيل. قد يُطلب رمز تحقق حسب إعدادات النظام.',
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
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'العنوان وأقرب علامة مميزة',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور (8 أحرف على الأقل)',
                ),
                validator: (v) =>
                    v == null || v.length < 8
                        ? 'كلمة المرور يجب ألا تقل عن 8 أحرف'
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
      if (mounted) Navigator.pop(context);
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
