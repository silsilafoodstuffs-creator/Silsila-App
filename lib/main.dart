import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/trader_market_service.dart';
import 'services/order_status_service.dart';
import 'services/wallet_service.dart';
import 'services/profile_service.dart';
import 'services/notification_service.dart';
import 'services/product_service.dart';
import 'services/supplier_service.dart';
import 'services/category_service.dart';
import 'services/supplier_product_service.dart';
import 'services/offer_service.dart';
import 'services/supplier_offer_service.dart';
import 'services/story_service.dart';
import 'services/user_service.dart';
import 'services/support_service.dart';
import 'services/delivery_service.dart';
import 'services/favorite_service.dart';
import 'services/loyalty_service.dart';
import 'services/address_service.dart';
import 'services/review_service.dart';
import 'services/checkout_service.dart';
import 'services/cart_service.dart';
import 'screens/registration/registration_success_screen.dart';

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
    this.icon, {
    this.id,
    this.supplierId,
    this.minQuantity = 1,
  });

  final String name;
  final String category;
  final double price;
  final String unit;
  final IconData icon;
  final int? id;
  final String? supplierId;
  final int minQuantity;

  String get cartKey => id == null ? 'demo:$name' : 'product:$id';
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
  final favoriteService = FavoriteService();
  final cart = <String, int>{};
  final cartProducts = <String, Product>{};
  final searchController = TextEditingController();
  final productService = ProductService();
  final supplierService = SupplierService();
  final categoryService = CategoryService();
  List<String> liveCategoryNames = [];
  List<Product> liveProducts = [];
  List<Map<String, dynamic>> liveSuppliers = [];
  bool loadingLiveSuppliers = false;
  bool isAdmin = false;
  bool isApprovedSupplier = false;
  int unreadNotifications = 0;
  bool loadingLiveProducts = false;
  String? productLoadMessage;

  List<Product> get allProducts =>
      liveProducts.isNotEmpty ? liveProducts : products;

  List<String> get visibleCategoryNames => liveCategoryNames.isNotEmpty
      ? ['الكل', ...liveCategoryNames]
      : categories;

  @override
  void initState() {
    super.initState();
    loadLiveProducts();
    loadLiveSuppliers();
    loadLiveCategories();
    loadCurrentRole();
    loadFavoriteKeys();
    loadUnreadNotifications();
  }

  Future<void> loadUnreadNotifications() async {
    if (database?.auth.currentUser == null) {
      if (mounted) setState(() => unreadNotifications = 0);
      return;
    }
    try {
      final count = await NotificationService().getUnreadCount();
      if (mounted) setState(() => unreadNotifications = count);
    } catch (_) {
      // Keep the header usable if notifications are temporarily unavailable.
    }
  }

  Future<void> openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text('الإشعارات')),
            body: NotificationsScreen(),
          ),
        ),
      ),
    );
    await loadUnreadNotifications();
  }

  Future<void> loadFavoriteKeys() async {
    if (database?.auth.currentUser == null) return;
    try {
      final keys = await favoriteService.getFavoriteKeys();
      if (!mounted) return;
      setState(() {
        favorites.removeWhere((key) => key.startsWith('product:') || key.startsWith('supplier:'));
        favorites.addAll(keys);
      });
    } catch (_) {
      // Keep local favorites usable when the account is offline or not signed in.
    }
  }

  String favoriteLabel(String key) {
    if (key.startsWith('product:')) {
      final id = key.substring('product:'.length);
      for (final product in allProducts) {
        if (product.id?.toString() == id) return product.name;
      }
      return 'منتج محفوظ';
    }
    if (key.startsWith('supplier:')) {
      final id = key.substring('supplier:'.length);
      for (final supplier in liveSuppliers) {
        if ((supplier['id'] ?? '').toString() == id) {
          return (supplier['full_name'] ?? 'مورد محفوظ').toString();
        }
      }
      return 'مورد محفوظ';
    }
    return key;
  }

  Future<void> toggleProductFavorite(Product product) async {
    final key = product.id == null ? product.name : 'product:${product.id}';
    final next = !favorites.contains(key);
    setState(() {
      if (next) {
        favorites.add(key);
      } else {
        favorites.remove(key);
      }
    });
    if (product.id == null || database?.auth.currentUser == null) return;
    try {
      await favoriteService.setProductFavorite(productId: product.id!, favorite: next);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (next) {
          favorites.remove(key);
        } else {
          favorites.add(key);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ المفضلة: ${e.toString()}')),
      );
    }
  }

  Future<void> toggleSupplierFavorite(String supplierId) async {
    final key = 'supplier:$supplierId';
    final next = !favorites.contains(key);
    setState(() {
      if (next) {
        favorites.add(key);
      } else {
        favorites.remove(key);
      }
    });
    if (database?.auth.currentUser == null) return;
    try {
      await favoriteService.setSupplierFavorite(supplierId: supplierId, favorite: next);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (next) {
          favorites.remove(key);
        } else {
          favorites.add(key);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ المورد في المفضلة: ${e.toString()}')),
      );
    }
  }

  Future<void> loadLiveCategories() async {
    if (database == null) return;
    try {
      final rows = await categoryService.getCategories(activityType: activity);
      if (!mounted) return;
      setState(() {
        liveCategoryNames = rows
            .where((row) => row['parent_id'] == null)
            .map((row) => (row['name'] ?? '').toString())
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList();
        if (!visibleCategoryNames.contains(selectedCategory)) {
          selectedCategory = 'الكل';
        }
      });
    } catch (_) {
      if (mounted) setState(() => liveCategoryNames = []);
    }
  }

  Future<void> loadCurrentRole() async {
    try {
      final profile = await ProfileService().getMyProfile();
      if (mounted) setState(() {
        isAdmin = profile?['role'] == 'admin';
        isApprovedSupplier = profile?['role'] == 'supplier' &&
            ['approved', 'active', 'مفعل', 'معتمد'].contains(profile?['account_status']);
      });
    } catch (_) {
      if (mounted) setState(() { isAdmin = false; isApprovedSupplier = false; });
    }
  }

  Future<void> loadLiveSuppliers() async {
    if (database == null) return;
    if (mounted) setState(() => loadingLiveSuppliers = true);
    try {
      final rows = await supplierService.getSuppliers(activityType: activity, limit: 100);
      if (!mounted) return;
      setState(() => liveSuppliers = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => liveSuppliers = []);
    } finally {
      if (mounted) setState(() => loadingLiveSuppliers = false);
    }
  }

  Future<void> loadLiveProducts() async {
    if (database == null) return;
    if (mounted) setState(() {
      loadingLiveProducts = true;
      productLoadMessage = null;
    });
    try {
      final rows = await productService.getProducts(
        activityType: activity,
        limit: 100,
      );
      final mapped = rows.map((row) {
        final category = (row['category'] ??
                row['category_name'] ??
                '').toString();
        final rawId = row['id'];
        final id = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final rawPrice = row['price'];
        final price = rawPrice is num
            ? rawPrice.toDouble()
            : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
        final rawMin = row['min_quantity'] ?? row['minimum_quantity'];
        final minQuantity = rawMin is num
            ? rawMin.toInt()
            : int.tryParse(rawMin?.toString() ?? '') ?? 1;
        return Product(
          (row['name'] ?? '').toString(),
          category,
          price,
          (row['unit'] ?? 'وحدة').toString(),
          _iconForCategory(category),
          id: id,
          supplierId: row['supplier_id']?.toString(),
          minQuantity: minQuantity < 1 ? 1 : minQuantity,
        );
      }).where((p) => p.id != null && p.name.trim().isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        liveProducts = mapped;
        loadingLiveProducts = false;
        productLoadMessage = mapped.isEmpty
            ? 'لا توجد منتجات منشورة حاليًا؛ تعرض أمثلة توضيحية مؤقتة.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingLiveProducts = false;
        productLoadMessage = 'تعذر تحميل الكتالوج الآن؛ تُعرض أمثلة توضيحية مؤقتة.';
      });
    }
  }

  IconData _iconForCategory(String category) {
    if (category.contains('زيت')) return Icons.water_drop;
    if (category.contains('سمن')) return Icons.breakfast_dining;
    if (category.contains('مكرون')) return Icons.ramen_dining;
    if (category.contains('مشروب') || category.contains('عصير')) {
      return Icons.local_drink;
    }
    if (category.contains('منظف')) return Icons.cleaning_services;
    if (category.contains('ورقي')) return Icons.inventory_2;
    if (category.contains('جبن') || category.contains('ألبان')) {
      return Icons.local_cafe;
    }
    return Icons.shopping_basket;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Product? productForCartKey(String key) {
    final stored = cartProducts[key];
    if (stored != null) return stored;
    for (final product in allProducts) {
      if (product.cartKey == key) return product;
    }
    return null;
  }

  double get total {
    double value = 0;
    for (final entry in cart.entries) {
      final product = productForCartKey(entry.key);
      if (product != null) value += product.price * entry.value;
    }
    return value;
  }

  void addToCart(Product product) {
    const maxQuantityPerProduct = CartService.maxQuantityPerProduct;
    final key = product.cartKey;
    final currentQuantity = cart[key] ?? 0;
    final nextQuantity = currentQuantity == 0
        ? product.minQuantity
        : currentQuantity + 1;

    if (nextQuantity < 1 || nextQuantity > maxQuantityPerProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وصلت للحد الأقصى المسموح لكمية هذا المنتج.')),
      );
      return;
    }

    setState(() {
      cartProducts[key] = product;
      cart[key] = nextQuantity;
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
            onPressed: openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (unreadNotifications > 0)
                  Positioned(
                    top: -7,
                    right: -9,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: const BoxDecoration(color: pink, shape: BoxShape.circle),
                      child: Text(
                        unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
              setState(() {});
              loadLiveProducts();
            },
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
    final visible = allProducts.where((p) {
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
        if (loadingLiveProducts) const LinearProgressIndicator(minHeight: 2),
        if (productLoadMessage != null) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(productLoadMessage!, style: const TextStyle(color: Colors.black54)),
        ),
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
          onChanged: (v) {
            setState(() {
              activity = v ?? 'مواد غذائية';
              selectedCategory = 'الكل';
              liveProducts = [];
              liveCategoryNames = [];
            });
            loadLiveProducts();
            loadLiveSuppliers();
            loadLiveCategories();
          },
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
              ...visibleCategoryNames,
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
        if (loadingLiveSuppliers) const LinearProgressIndicator(minHeight: 2),
        if (liveSuppliers.isNotEmpty)
          ...liveSuppliers.map(supplierDirectoryTile)
        else
          ...suppliers.map(supplierTile),
      ],
    );
  }

  Widget productCard(Product product) {
    final favoriteKey = product.id == null ? product.name : 'product:${product.id}';
    final favorite = favorites.contains(favoriteKey);
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
                      onPressed: () => toggleProductFavorite(product),
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

  Widget supplierDirectoryTile(Map<String, dynamic> supplier) {
    final id = (supplier['id'] ?? '').toString();
    final name = (supplier['full_name'] ?? 'مورد سلسلة').toString();
    final location = [
      supplier['governorate'],
      supplier['district'],
    ].where((value) => value != null && value.toString().trim().isNotEmpty)
      .join(' • ');
    final favoriteKey = 'supplier:$id';
    final favorite = favorites.contains(favoriteKey);
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEFE6F8),
          child: Icon(Icons.store, color: purple),
        ),
        title: Text(name),
        subtitle: Text(location.isEmpty ? 'مورد معتمد على سلسلة' : location),
        trailing: IconButton(
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
            color: favorite ? pink : purple),
          onPressed: () => toggleSupplierFavorite(id),
        ),
        onTap: () => openPage(
          name,
          SupplierDetailScreen(
            supplierId: id,
            fallbackName: name,
            onAddToCart: addToCart,
          ),
        ),
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
          final product = productForCartKey(entry.key) ?? Product(entry.key, '', 0, 'وحدة', Icons.shopping_basket);
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
                      if (entry.value <= product.minQuantity) {
                        cart.remove(entry.key);
                      } else {
                        cart[entry.key] = entry.value - 1;
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${entry.value}'),
                  IconButton(
                    onPressed: entry.value >= CartService.maxQuantityPerProduct
                        ? null
                        : () => setState(
                              () => cart[entry.key] = entry.value + 1,
                            ),
                    tooltip: 'زيادة الكمية',
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
                    allProducts.any((p) => p.id != null) ? 'الإجمالي تقديري وقد يتغير عند تأكيد الطلب من قاعدة البيانات.' : 'الأسعار المعروضة أمثلة توضيحية وليست أسعار مورد مؤكدة.',
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
                          itemCount: cart.values.fold<int>(0, (a, b) => a + b),
                          items: entries.map((entry) => <String, dynamic>{
                            'product': productForCartKey(entry.key) ?? Product(entry.key, '', 0, 'وحدة', Icons.shopping_basket),
                            'quantity': entry.value,
                          }).toList(),
                          onSuccess: () { if (mounted) setState(() { cart.clear(); cartProducts.clear(); }); },
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
            () => openPage('العروض', OffersScreen(activityType: activity, canManage: isApprovedSupplier)),
          ),
          menuItem(
            Icons.auto_awesome,
            'قصص الموردين',
            () => openPage('قصص الموردين', StoriesScreen(activityType: activity)),
          ),
          menuItem(
            Icons.receipt_long,
            'سجل طلباتي',
            () => openPage('سجل طلباتي', const MyOrdersScreen()),
          ),
          menuItem(
            Icons.support_agent,
            'الدعم والشكاوى',
            () => openPage('الدعم والشكاوى', const SupportScreen()),
          ),
          menuItem(
            Icons.local_shipping_outlined,
            'الشحن والتوصيل',
            () => openPage('الشحن والتوصيل', const DeliveryScreen()),
          ),
          menuItem(
            Icons.favorite_border,
            'المفضلة',
            () => openPage(
              'المفضلة',
              FavoritesScreen(names: favorites.map(favoriteLabel).toList()),
            ),
          ),
          menuItem(
            Icons.account_balance_wallet_outlined,
            'رصيدي ونقاطي',
            () => openPage('رصيدي ونقاطي', const WalletOverviewScreen()),
          ),
          menuItem(
            Icons.stars_outlined,
            'نقاط الولاء وأهدافي',
            () => openPage('نقاط الولاء وأهدافي', const LoyaltyOverviewScreen()),
          ),
          menuItem(
            Icons.settings_outlined,
            'إعدادات الحساب',
            () => openPage('إعدادات الحساب', const ProfileEditorScreen()),
          ),
          menuItem(
            Icons.location_on_outlined,
            'عناويني المحفوظة',
            () => openPage('عناويني المحفوظة', const AddressBookScreen()),
          ),
          if (isApprovedSupplier)
            menuItem(
              Icons.inventory_2_outlined,
              'إدارة منتجاتي',
              () => openPage('إدارة منتجاتي', const SupplierProductsScreen()),
            ),
          if (isAdmin)
            menuItem(
              Icons.admin_panel_settings_outlined,
              'مراجعة الحسابات الجديدة',
              () => openPage('مراجعة الحسابات', const AdminApprovalsScreen()),
            ),
          if (isAdmin)
            menuItem(
              Icons.account_balance_wallet,
              'مراجعة طلبات شحن المحافظ',
              () => openPage('مراجعة شحن المحافظ', const AdminTopUpReviewScreen()),
            ),
          if (isAdmin)
            menuItem(
              Icons.local_shipping,
              'إدارة شركات الشحن',
              () => openPage('إدارة شركات الشحن', const AdminShippingCompaniesScreen()),
            ),
          if (isAdmin)
            menuItem(
              Icons.support_agent,
              'إدارة تذاكر الدعم',
              () => openPage('إدارة تذاكر الدعم', const AdminSupportTicketsScreen()),
            ),
          if (isAdmin)
            menuItem(
              Icons.category_outlined,
              'إدارة أقسام المنتجات',
              () => openPage('إدارة الأقسام', const AdminCategoriesScreen()),
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

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({
    super.key,
    required this.supplierId,
    required this.fallbackName,
    required this.onAddToCart,
  });
  final String supplierId;
  final String fallbackName;
  final ValueChanged<Product> onAddToCart;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final supplierService = SupplierService();
  final productService = SupplierProductService();
  final reviewService = ReviewService();
  Map<String, dynamic>? ratingSummary;
  List<Map<String, dynamic>> reviews = [];
  Map<String, dynamic>? supplier;
  Map<String, dynamic>? details;
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadSupplier();
  }

  Future<void> loadSupplier() async {
    try {
      final profile = await supplierService.getSupplierById(widget.supplierId);
      final supplierDetails = await supplierService.getSupplierDetails(widget.supplierId);
      final supplierProducts = await productService.getSupplierProducts(widget.supplierId);
      Map<String, dynamic>? loadedRating;
      List<Map<String, dynamic>> loadedReviews = [];
      try {
        loadedRating = await reviewService.getSupplierRating(widget.supplierId);
        loadedReviews = await reviewService.getSupplierReviews(widget.supplierId, limit: 20);
      } catch (_) {
        // Supplier and catalog remain visible if reviews are not configured yet.
      }
      if (!mounted) return;
      setState(() {
        supplier = profile;
        details = supplierDetails;
        products = supplierProducts;
        ratingSummary = loadedRating;
        reviews = loadedReviews;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'تعذر تحميل بيانات المورد ومنتجاته.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Product toProduct(Map<String, dynamic> row) {
    final rawId = row['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final rawPrice = row['price'];
    final price = rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
    final rawMinimum = row['min_quantity'] ?? row['minimum_quantity'];
    final minimum = rawMinimum is num ? rawMinimum.toInt() : int.tryParse(rawMinimum?.toString() ?? '') ?? 1;
    final category = (row['category'] ?? '').toString();
    return Product(
      (row['name'] ?? '').toString(),
      category,
      price,
      (row['unit'] ?? 'وحدة').toString(),
      Icons.shopping_basket,
      id: id,
      supplierId: row['supplier_id']?.toString(),
      minQuantity: minimum < 1 ? 1 : minimum,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    final name = (supplier?['full_name'] ?? widget.fallbackName).toString();
    final rating = ratingSummary?['average'] ?? details?['rating'];
    final reviewCount = ratingSummary?['count'] ?? 0;
    final minimumInvoice = details?['minimum_invoice'];
    return RefreshIndicator(
      onRefresh: loadSupplier,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.store, size: 52, color: purple),
                const SizedBox(height: 8),
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('نوع المورد: ${details?['supplier_type'] ?? supplier?['supplier_type'] ?? 'غير محدد'}'),
                Text('النشاط: ${details?['activity_type'] ?? supplier?['activity_type'] ?? 'غير محدد'}'),
                if ((supplier?['governorate'] ?? '').toString().isNotEmpty)
                  Text('المحافظة: ${supplier?['governorate']}'),
                if (details?['description'] != null && details!['description'].toString().trim().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(details!['description'].toString())),
                if (minimumInvoice != null) Text('الحد الأدنى للفاتورة: $minimumInvoice ج.م'),
                if (details?['minimum_items'] != null) Text('الحد الأدنى للأصناف: ${details?['minimum_items']}'),
                if (rating is num) Text('التقييم: ${rating.toStringAsFixed(1)} / 5 • ${reviewCount} تقييم'),
                Text(details?['accepts_negotiation'] == true ? 'الأسعار قابلة للتفاوض' : 'راجع سياسة الأسعار مع المورد'),
                if (details?['is_verified'] == true)
                  const Padding(padding: EdgeInsets.only(top: 8), child: Chip(label: Text('مورد موثّق'))),
              ]),
            ),
          ),
          if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          const SizedBox(height: 8),
          const Text('منتجات المورد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: purple)),
          if (products.isEmpty && error == null)
            const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد منتجات منشورة حاليًا.', textAlign: TextAlign.center)),
          ...products.map((row) {
            final product = toProduct(row);
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: purple),
                title: Text(product.name),
                subtitle: Text('${product.price.toStringAsFixed(2)} ج.م / ${product.unit} • الحد الأدنى ${product.minQuantity}'),
                trailing: IconButton(
                  tooltip: 'إضافة للسلة',
                  icon: const Icon(Icons.add_shopping_cart, color: orange),
                  onPressed: product.id == null ? null : () => widget.onAddToCart(product),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          const Text('آراء العملاء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: purple)),
          if (reviews.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تقييمات منشورة لهذا المورد بعد.')),
          ...reviews.map((review) => Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: orange),
              title: Text('${review['rating'] ?? 0} / 5'),
              subtitle: Text((review['comment'] ?? 'بدون تعليق').toString()),
            ),
          )),
        ],
      ),
    );
  }
}

class SupplierProductsScreen extends StatefulWidget {
  const SupplierProductsScreen({super.key});

  @override
  State<SupplierProductsScreen> createState() => _SupplierProductsScreenState();
}

class _SupplierProductsScreenState extends State<SupplierProductsScreen> {
  final service = SupplierProductService();
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? error;
  final busyIds = <int>{};

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final userId = database?.auth.currentUser?.id;
      if (userId == null) throw StateError('يجب تسجيل الدخول أولًا.');
      final rows = await service.getSupplierProducts(userId, activeOnly: false);
      if (!mounted) return;
      setState(() { products = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() { error = 'تعذر تحميل منتجاتك. تأكد من اعتماد حساب المورد وتطبيق ترحيلات Supabase.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addProduct() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'زيوت');
    final price = TextEditingController();
    final unit = TextEditingController(text: 'كرتونة');
    final minimum = TextEditingController(text: '1');
    final stock = TextEditingController(text: '0');
    bool trackStock = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة منتج جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'القسم')),
              TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر الجملة')),
              TextField(controller: unit, decoration: const InputDecoration(labelText: 'وحدة البيع')),
              TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الحد الأدنى للكمية')),
              TextField(controller: stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية المتاحة')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: trackStock,
                title: const Text('تتبع المخزون ومنع البيع بعد النفاد'),
                onChanged: (value) => setDialogState(() => trackStock = value ?? false),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ المنتج')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      try {
        final parsedPrice = num.tryParse(price.text.trim());
        final parsedMinimum = num.tryParse(minimum.text.trim());
        final parsedStock = num.tryParse(stock.text.trim()) ?? 0;
        if (parsedPrice == null || parsedMinimum == null) {
          throw ArgumentError('أدخل سعرًا وحدًا أدنى صحيحين.');
        }
        await service.createProduct(
          name: name.text,
          category: category.text,
          price: parsedPrice,
          unit: unit.text,
          minQuantity: parsedMinimum,
          stockQuantity: parsedStock,
          trackInventory: trackStock,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر المنتج.')));
        await loadProducts();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة المنتج: $e')));
      }
    }
    name.dispose();
    category.dispose();
    price.dispose();
    unit.dispose();
    minimum.dispose();
    stock.dispose();
  }

  Future<void> deactivate(Map<String, dynamic> product) async {
    final rawId = product['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || busyIds.contains(id)) return;
    setState(() => busyIds.add(id));
    try {
      await service.deactivateProduct(id);
      await loadProducts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إيقاف المنتج: $e')));
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadProducts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('منتجاتي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple))),
            FilledButton.icon(onPressed: addProduct, icon: const Icon(Icons.add), label: const Text('إضافة')),
          ]),
          if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          if (products.isEmpty && error == null) const Padding(padding: EdgeInsets.all(24), child: Text('لم تنشر منتجات بعد.', textAlign: TextAlign.center)),
          ...products.map((product) {
            final rawId = product['id'];
            final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
            final active = product['is_active'] == true || product['is_available'] == true;
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: purple),
                title: Text((product['name'] ?? '').toString()),
                subtitle: Text('${product['category'] ?? 'بدون قسم'} • ${product['price'] ?? 0} ج.م / ${product['unit'] ?? 'وحدة'}'
                    '\nالحد الأدنى: ${product['min_quantity'] ?? product['minimum_quantity'] ?? 1}'
                    '\nالمخزون: ${product['track_inventory'] == true ? product['stock_quantity'] : 'غير متتبع'}'),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: active ? 'إيقاف المنتج' : 'المنتج متوقف',
                  onPressed: active && id != null && !busyIds.contains(id) ? () => deactivate(product) : null,
                  icon: Icon(active ? Icons.pause_circle_outline : Icons.check_circle_outline, color: active ? orange : Colors.grey),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final service = DeliveryService();
  final orderIdController = TextEditingController();
  final pickupController = TextEditingController();
  final deliveryController = TextEditingController();
  final notesController = TextEditingController();
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> deliveries = [];
  String? companyId;
  bool loading = true;
  bool sending = false;
  bool isShippingCompany = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadDeliveryData();
  }

  @override
  void dispose() {
    orderIdController.dispose();
    pickupController.dispose();
    deliveryController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> loadDeliveryData() async {
    try {
      final profile = await ProfileService().getMyProfile();
      if ((profile?['role'] ?? '').toString() == 'shipping_company') {
        final assigned = await service.getAssignedDeliveries();
        if (!mounted) return;
        setState(() {
          isShippingCompany = true;
          companies = [];
          deliveries = assigned;
          error = null;
        });
        return;
      }
      final loadedCompanies = await service.getShippingCompanies();
      final loadedDeliveries = await service.getMyDeliveries();
      if (!mounted) return;
      setState(() {
        companies = loadedCompanies;
        deliveries = loadedDeliveries;
        if (companyId == null && companies.isNotEmpty) {
          companyId = companies.first['id']?.toString();
        }
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'تعذر تحميل شركات الشحن أو الشحنات السابقة.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateAssignedDelivery(Map<String, dynamic> delivery, String status) async {
    final id = (delivery['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() => sending = true);
    try {
      await service.updateDeliveryStatus(deliveryId: id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث الشحنة إلى: $status')));
      await loadDeliveryData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الشحنة: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> submitDelivery() async {
    final orderText = orderIdController.text.trim();
    if (int.tryParse(orderText) == null ||
        (companyId ?? '').isEmpty ||
        pickupController.text.trim().isEmpty ||
        deliveryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل رقم الطلب وشركة الشحن وعنوانَي الاستلام والتوصيل.')));
      return;
    }
    setState(() => sending = true);
    try {
      await service.createDelivery(
        orderId: orderText,
        shippingCompanyId: companyId!,
        pickupAddress: pickupController.text,
        deliveryAddress: deliveryController.text,
        notes: notesController.text,
      );
      if (!mounted) return;
      orderIdController.clear();
      pickupController.clear();
      deliveryController.clear();
      notesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب التوصيل.')));
      await loadDeliveryData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء الشحنة: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    if (isShippingCompany) {
      return RefreshIndicator(
        onRefresh: loadDeliveryData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('الشحنات المسندة لشركتك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
            if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
            if (deliveries.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد شحنات مسندة حاليًا.', textAlign: TextAlign.center)),
            ...deliveries.map((delivery) {
              final status = (delivery['status'] ?? 'pending').toString();
              final nextStatus = switch (status) {
                'pending' => 'قيد الاستلام',
                'قيد الاستلام' => 'في الطريق',
                'في الطريق' => 'تم التسليم',
                _ => null,
              };
              final isClosed = status == 'تم التسليم' || status == 'ملغي' || status == 'مُلغي';
              return Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('شحنة الطلب رقم ${delivery['order_id'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 6),
                    Text('الحالة: $status'),
                    Text('عنوان التوصيل: ${delivery['delivery_address'] ?? 'غير محدد'}'),
                    if ((delivery['pickup_address'] ?? '').toString().isNotEmpty)
                      Text('عنوان الاستلام: ${delivery['pickup_address']}'),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (nextStatus != null)
                        Expanded(child: FilledButton(
                          onPressed: sending ? null : () => updateAssignedDelivery(delivery, nextStatus),
                          child: Text(nextStatus == 'تم التسليم' ? 'تأكيد التسليم' : 'تحديث إلى $nextStatus'),
                        )),
                      if (!isClosed && status != 'pending') ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: sending ? null : () => updateAssignedDelivery(delivery, 'ملغي'),
                          child: const Text('إلغاء الشحنة'),
                        ),
                      ],
                    ]),
                  ]),
                ),
              );
            }),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('طلب شحن وتوصيل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(error!)),
        if (companies.isEmpty && !loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('لا توجد شركات شحن نشطة حاليًا.')),
        TextField(controller: orderIdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الطلب')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: companies.any((company) => company['id']?.toString() == companyId) ? companyId : null,
          decoration: const InputDecoration(labelText: 'شركة الشحن'),
          items: companies.map((company) => DropdownMenuItem<String>(
            value: company['id'].toString(),
            child: Text((company['name'] ?? 'شركة شحن').toString()),
          )).toList(),
          onChanged: companies.isEmpty ? null : (value) => setState(() => companyId = value),
        ),
        const SizedBox(height: 10),
        TextField(controller: pickupController, maxLines: 2, decoration: const InputDecoration(labelText: 'عنوان الاستلام')),
        const SizedBox(height: 10),
        TextField(controller: deliveryController, maxLines: 2, decoration: const InputDecoration(labelText: 'عنوان التوصيل')),
        const SizedBox(height: 10),
        TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: sending || companies.isEmpty ? null : submitDelivery,
          icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.local_shipping),
          label: Text(sending ? 'جارٍ إرسال الطلب...' : 'طلب التوصيل'),
        ),
        const Divider(height: 32),
        const Text('شحناتي السابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (!loading && deliveries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد شحنات سابقة.')),
        ...deliveries.map((delivery) => Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined, color: purple),
            title: Text('طلب رقم ${delivery['order_id'] ?? '-'}'),
            subtitle: Text((delivery['delivery_address'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text((delivery['status'] ?? 'pending').toString()),
          ),
        )),
      ],
    );
  }
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final service = SupportService();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  final orderIdController = TextEditingController();
  String category = 'general';
  List<Map<String, dynamic>> tickets = [];
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadTickets();
  }

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    orderIdController.dispose();
    super.dispose();
  }

  Future<void> loadTickets() async {
    try {
      final rows = await service.getMyTickets();
      if (!mounted) return;
      setState(() { tickets = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() { error = 'سجّل الدخول لعرض تذاكر الدعم.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submitTicket() async {
    if (sending) return;
    if (subjectController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل عنوان الشكوى والتفاصيل.')));
      return;
    }
    final orderText = orderIdController.text.trim();
    if (orderText.isNotEmpty && int.tryParse(orderText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الطلب يجب أن يكون رقمًا صحيحًا.')));
      return;
    }
    setState(() => sending = true);
    try {
      await service.createTicket(
        subject: subjectController.text,
        message: messageController.text,
        category: category,
        orderId: orderText.isEmpty ? null : orderText,
      );
      if (!mounted) return;
      subjectController.clear();
      messageController.clear();
      orderIdController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال تذكرة الدعم.')));
      await loadTickets();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التذكرة: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('الدعم الفني والشكاوى', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
        const SizedBox(height: 12),
        TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'عنوان الشكوى أو الاستفسار')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: category,
          decoration: const InputDecoration(labelText: 'نوع التذكرة'),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('استفسار عام')),
            DropdownMenuItem(value: 'orders', child: Text('الطلبات')),
            DropdownMenuItem(value: 'payments', child: Text('الدفع والمحفظة')),
            DropdownMenuItem(value: 'account', child: Text('الحساب والتفعيل')),
            DropdownMenuItem(value: 'technical', child: Text('مشكلة تقنية')),
          ],
          onChanged: (value) => setState(() => category = value ?? 'general'),
        ),
        const SizedBox(height: 10),
        TextField(controller: orderIdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الطلب (اختياري)')),
        const SizedBox(height: 10),
        TextField(controller: messageController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'اشرح المشكلة بالتفصيل')),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: sending ? null : submitTicket,
          icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
          label: Text(sending ? 'جارٍ الإرسال...' : 'إرسال التذكرة'),
        ),
        const Divider(height: 32),
        const Text('تذاكري السابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: purple))),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        if (!loading && tickets.isEmpty && error == null) const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تذاكر سابقة.')),
        ...tickets.map((ticket) => Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent, color: purple),
            title: Text((ticket['subject'] ?? 'تذكرة دعم').toString()),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text((ticket['message'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                if ((ticket['admin_reply'] ?? '').toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'رد سلسلة: ${ticket['admin_reply']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: purple, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            trailing: Text((ticket['status'] ?? 'open').toString()),
          ),
        )),
      ],
    );
  }
}

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final service = CategoryService();
  List<Map<String, dynamic>> categories = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final rows = await service.getCategories(activeOnly: false);
      if (!mounted) return;
      setState(() { categories = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'هذه الشاشة للمسؤول المعتمد فقط، وتحتاج صلاحيات إدارة الأقسام.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editCategory({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: (existing?['name'] ?? '').toString());
    final icon = TextEditingController(text: (existing?['icon'] ?? '').toString());
    final order = TextEditingController(text: (existing?['sort_order'] ?? 0).toString());
    bool active = existing?['is_active'] != false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة قسم' : 'تعديل القسم'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم القسم')),
            TextField(controller: icon, decoration: const InputDecoration(labelText: 'رمز القسم (اختياري)')),
            TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ترتيب العرض')),
            CheckboxListTile(value: active, onChanged: (value) => setDialogState(() => active = value ?? true), title: const Text('قسم نشط'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      try {
        final sortOrder = int.tryParse(order.text.trim()) ?? 0;
        final categoryId = existing?['id'];
        if (categoryId == null) {
          await service.createCategory(
            name: name.text,
            icon: icon.text.trim().isEmpty ? null : icon.text.trim(),
            sortOrder: sortOrder,
          );
        } else {
          await service.updateCategory(
            categoryId: categoryId is int ? categoryId : int.parse(categoryId.toString()),
            name: name.text,
            icon: icon.text.trim(),
            sortOrder: sortOrder,
            isActive: active,
          );
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القسم.')));
        await loadCategories();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ القسم: $e')));
      }
    }
    name.dispose();
    icon.dispose();
    order.dispose();
  }

  Future<void> toggleCategory(Map<String, dynamic> category) async {
    final rawId = category['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) return;
    try {
      await service.updateCategory(categoryId: id, isActive: category['is_active'] != true);
      await loadCategories();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تغيير حالة القسم: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadCategories,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('أقسام المنتجات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple))),
          FilledButton.icon(onPressed: () => editCategory(), icon: const Icon(Icons.add), label: const Text('إضافة')),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        ...categories.map((category) {
          final active = category['is_active'] == true;
          return Card(
            child: ListTile(
              leading: Icon(Icons.category_outlined, color: active ? purple : Colors.grey),
              title: Text((category['name'] ?? '').toString()),
              subtitle: Text('ترتيب العرض: ${category['sort_order'] ?? 0} • ${active ? 'نشط' : 'متوقف'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') editCategory(existing: category);
                  if (value == 'toggle') toggleCategory(category);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'toggle', child: Text(active ? 'إيقاف' : 'تفعيل')),
                ],
              ),
            ),
          );
        }),
      ]),
    );
  }
}

class AdminSupportTicketsScreen extends StatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  State<AdminSupportTicketsScreen> createState() => _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState extends State<AdminSupportTicketsScreen> {
  final service = UserService();
  List<Map<String, dynamic>> tickets = [];
  final busyIds = <String>{};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadTickets();
  }

  Future<void> loadTickets() async {
    try {
      final rows = await service.getPendingSupportTickets();
      if (!mounted) return;
      setState(() { tickets = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'هذه الشاشة متاحة للمسؤول المعتمد فقط، وتحتاج تطبيق ترحيل الدعم.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> respond(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] ?? '').toString();
    if (id.isEmpty || busyIds.contains(id)) return;
    final reply = TextEditingController(text: (ticket['admin_reply'] ?? '').toString());
    String status = 'in_progress';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الرد على تذكرة الدعم'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text((ticket['subject'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text((ticket['message'] ?? '').toString()),
            const SizedBox(height: 12),
            TextField(controller: reply, maxLines: 4, decoration: const InputDecoration(labelText: 'الرد الذي سيصل للمستخدم')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'حالة التذكرة'),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('مفتوحة')),
                DropdownMenuItem(value: 'in_progress', child: Text('قيد المعالجة')),
                DropdownMenuItem(value: 'resolved', child: Text('تم الحل')),
                DropdownMenuItem(value: 'closed', child: Text('مغلقة')),
              ],
              onChanged: (value) => setDialogState(() => status = value ?? 'in_progress'),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ وإرسال')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      setState(() => busyIds.add(id));
      try {
        await service.updateSupportTicket(
          ticketId: id,
          status: status,
          reply: reply.text.trim().isEmpty ? null : reply.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث التذكرة وإرسال الرد.')));
        await loadTickets();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث التذكرة: $e')));
      } finally {
        if (mounted) setState(() => busyIds.remove(id));
      }
    }
    reply.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadTickets,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('تذاكر الدعم المفتوحة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        if (tickets.isEmpty && error == null) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد تذاكر مفتوحة.', textAlign: TextAlign.center)),
        ...tickets.map((ticket) {
          final id = (ticket['id'] ?? '').toString();
          final date = ticket['created_at']?.toString() ?? '';
          return Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: purple),
              title: Text((ticket['subject'] ?? 'تذكرة دعم').toString()),
              subtitle: Text([
                (ticket['full_name'] ?? 'مستخدم').toString(),
                (ticket['category'] ?? 'general').toString(),
                (ticket['status'] ?? 'open').toString(),
                if (date.isNotEmpty) date.split('T').first,
              ].join(' • ')),
              trailing: IconButton(
                onPressed: busyIds.contains(id) ? null : () => respond(ticket),
                icon: const Icon(Icons.reply, color: orange),
                tooltip: 'مراجعة والرد',
              ),
              onTap: () => respond(ticket),
            ),
          );
        }),
      ]),
    );
  }
}

class AdminShippingCompaniesScreen extends StatefulWidget {
  const AdminShippingCompaniesScreen({super.key});

  @override
  State<AdminShippingCompaniesScreen> createState() => _AdminShippingCompaniesScreenState();
}

class _AdminShippingCompaniesScreenState extends State<AdminShippingCompaniesScreen> {
  final service = DeliveryService();
  List<Map<String, dynamic>> companies = [];
  bool loading = true;
  final busyIds = <String>{};
  String? error;

  @override
  void initState() {
    super.initState();
    loadCompanies();
  }

  Future<void> loadCompanies() async {
    try {
      final rows = await service.getAllShippingCompaniesForAdmin();
      if (!mounted) return;
      setState(() { companies = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'هذه الشاشة متاحة للمسؤول المعتمد فقط، وتحتاج تطبيق ترحيل الشحن.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editCompany({Map<String, dynamic>? company}) async {
    final name = TextEditingController(text: (company?['name'] ?? '').toString());
    final phone = TextEditingController(text: (company?['phone'] ?? '').toString());
    final profileId = TextEditingController(text: (company?['profile_id'] ?? '').toString());
    bool active = company?['is_active'] != false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(company == null ? 'إضافة شركة شحن' : 'تعديل شركة الشحن'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم شركة الشحن')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            TextField(controller: profileId, decoration: const InputDecoration(labelText: 'معرّف حساب شركة الشحن (UUID اختياري)')),
            CheckboxListTile(value: active, onChanged: (value) => setDialogState(() => active = value ?? true), title: const Text('شركة نشطة'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      try {
        await service.saveShippingCompany(
          companyId: company?['id']?.toString(),
          profileId: profileId.text.trim().isEmpty ? null : profileId.text.trim(),
          name: name.text,
          phone: phone.text,
          isActive: active,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ شركة الشحن.')));
        await loadCompanies();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الشركة: $e')));
      }
    }
    name.dispose();
    phone.dispose();
    profileId.dispose();
  }

  Future<void> toggleCompany(Map<String, dynamic> company) async {
    final id = (company['id'] ?? '').toString();
    if (id.isEmpty || busyIds.contains(id)) return;
    setState(() => busyIds.add(id));
    try {
      await service.saveShippingCompany(
        companyId: id,
        profileId: company['profile_id']?.toString(),
        name: (company['name'] ?? '').toString(),
        phone: company['phone']?.toString(),
        isActive: company['is_active'] != true,
      );
      await loadCompanies();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الشركة: $e')));
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadCompanies,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('شركات الشحن', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple))),
          FilledButton.icon(onPressed: () => editCompany(), icon: const Icon(Icons.add), label: const Text('إضافة')),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        if (companies.isEmpty && error == null) const Padding(padding: EdgeInsets.all(24), child: Text('لم تتم إضافة شركات شحن بعد.', textAlign: TextAlign.center)),
        ...companies.map((company) {
          final id = (company['id'] ?? '').toString();
          final active = company['is_active'] == true;
          return Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(Icons.local_shipping_outlined, color: active ? purple : Colors.grey),
              title: Text((company['name'] ?? 'شركة شحن').toString()),
              subtitle: Text([
                if ((company['phone'] ?? '').toString().isNotEmpty) company['phone'].toString(),
                if ((company['profile_id'] ?? '').toString().isNotEmpty) 'حساب مرتبط',
                active ? 'نشطة' : 'متوقفة',
              ].join(' • ')),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') editCompany(company: company);
                  if (value == 'toggle') toggleCompany(company);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'toggle', child: Text(active ? 'إيقاف' : 'تفعيل')),
                ],
              ),
            ),
          );
        }),
      ]),
    );
  }
}

class AdminTopUpReviewScreen extends StatefulWidget {
  const AdminTopUpReviewScreen({super.key});

  @override
  State<AdminTopUpReviewScreen> createState() => _AdminTopUpReviewScreenState();
}

class _AdminTopUpReviewScreenState extends State<AdminTopUpReviewScreen> {
  final service = UserService();
  List<Map<String, dynamic>> requests = [];
  final busyIds = <String>{};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    try {
      final rows = await service.getPendingTopUps();
      if (!mounted) return;
      setState(() { requests = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() { error = 'هذه الشاشة للمسؤول المعتمد فقط، وتحتاج تطبيق ترحيل مراجعة المحافظ.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> review(Map<String, dynamic> request, bool approve) async {
    final id = (request['id'] ?? '').toString();
    if (id.isEmpty || busyIds.contains(id)) return;
    setState(() => busyIds.add(id));
    try {
      await service.reviewTopUp(
        requestId: id,
        approve: approve,
        note: approve ? 'تمت مراجعة واعتماد الشحن.' : 'تم رفض طلب الشحن بعد المراجعة.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'تم اعتماد الشحن وإضافة الرصيد.' : 'تم رفض طلب الشحن.'),
      ));
      await loadRequests();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذرت مراجعة الطلب: $e')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('طلبات شحن المحفظة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
          const SizedBox(height: 8),
          const Text('لا يُضاف أي مبلغ إلى رصيد المستخدم إلا بعد الاعتماد من الإدارة.'),
          if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          if (requests.isEmpty && error == null) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد طلبات شحن معلقة.', textAlign: TextAlign.center)),
          ...requests.map((request) {
            final id = (request['id'] ?? '').toString();
            final busy = busyIds.contains(id);
            final name = (request['full_name'] ?? 'مستخدم').toString();
            final amount = request['amount'] ?? 0;
            final method = (request['payment_method'] ?? '').toString();
            final reference = (request['reference'] ?? '').toString();
            final date = request['created_at']?.toString() ?? '';
            return Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('المبلغ: $amount ج.م'),
                  Text('طريقة الدفع: $method'),
                  if (reference.isNotEmpty) Text('مرجع الدفع: $reference'),
                  if (date.isNotEmpty) Text('التاريخ: ${date.split('T').first}'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: busy ? null : () => review(request, false),
                      child: const Text('رفض الطلب'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(
                      onPressed: busy ? null : () => review(request, true),
                      child: Text(busy ? 'جارٍ الحفظ...' : 'اعتماد وإضافة الرصيد'),
                    )),
                  ]),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final service = UserService();
  final profileService = ProfileService();
  List<Map<String, dynamic>> accounts = [];
  bool loading = true;
  String? error;
  final busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await service.getPendingAccounts();
      if (!mounted) return;
      setState(() => accounts = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() { accounts = []; error = 'هذه الشاشة متاحة للمسؤول المعتمد فقط، وتحتاج تطبيق ترحيلات الإدارة.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateStatus(Map<String, dynamic> account, String status) async {
    final id = (account['id'] ?? '').toString();
    if (id.isEmpty || busyIds.contains(id)) return;
    setState(() => busyIds.add(id));
    try {
      await profileService.updateAccountStatus(userId: id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved' ? 'تم اعتماد الحساب.' : 'تم رفض الحساب.')),
      );
      await loadAccounts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الحساب: $e')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadAccounts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('طلبات تفعيل الحسابات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
          if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, textAlign: TextAlign.center)),
          if (accounts.isEmpty && error == null)
            const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد حسابات معلقة للمراجعة.', textAlign: TextAlign.center)),
          ...accounts.map((account) {
            final id = (account['id'] ?? '').toString();
            final name = (account['full_name'] ?? 'حساب جديد').toString();
            final phone = (account['phone'] ?? 'لا يوجد رقم').toString();
            final type = (account['account_type'] ?? 'غير محدد').toString();
            final activity = (account['activity_type'] ?? 'غير محدد').toString();
            final location = [account['governorate'], account['district']]
                .where((v) => v != null && v.toString().trim().isNotEmpty)
                .join(' • ');
            final busy = busyIds.contains(id);
            return Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('نوع الحساب: $type'),
                  Text('النشاط: $activity'),
                  Text('الهاتف: $phone'),
                  if (location.isNotEmpty) Text('الموقع: $location'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: busy ? null : () => updateStatus(account, 'rejected'),
                      child: const Text('رفض'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(
                      onPressed: busy ? null : () => updateStatus(account, 'approved'),
                      child: Text(busy ? 'جارٍ الحفظ...' : 'اعتماد الحساب'),
                    )),
                  ]),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key, required this.activityType});
  final String activityType;

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final mediaUrlController = TextEditingController();
  final captionController = TextEditingController();
  String newStoryMediaType = 'image';

  Future<void> createStory() async {
    if (database?.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولًا لنشر قصة.')),
      );
      return;
    }
    mediaUrlController.clear();
    captionController.clear();
    newStoryMediaType = 'image';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('نشر قصة جديدة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: mediaUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'رابط الصورة أو الفيديو'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: newStoryMediaType,
                decoration: const InputDecoration(labelText: 'نوع الوسائط'),
                items: const [
                  DropdownMenuItem(value: 'image', child: Text('صورة')),
                  DropdownMenuItem(value: 'video', child: Text('فيديو')),
                ],
                onChanged: (value) => setDialogState(() => newStoryMediaType = value ?? 'image'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف مختصر (اختياري)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('نشر')),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await service.createStory(
        mediaUrl: mediaUrlController.text,
        mediaType: newStoryMediaType,
        caption: captionController.text,
        activityType: widget.activityType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر القصة.')));
      await loadStories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نشر القصة: $error')));
    }
  }

  final service = StoryService();
  List<Map<String, dynamic>> stories = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await service.getActiveStories(activityType: widget.activityType);
      if (!mounted) return;
      setState(() => stories = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() { stories = []; error = 'تعذر تحميل القصص حاليًا.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    mediaUrlController.dispose();
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadStories,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: createStory, icon: const Icon(Icons.add), label: const Text('إضافة قصة'))),
          const SizedBox(height: 10),
          const Text('قصص الموردين', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
          const SizedBox(height: 8),
          const Text('تختفي القصة تلقائيًا عند انتهاء مدتها.'),
          if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, textAlign: TextAlign.center)),
          if (stories.isEmpty && error == null)
            const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد قصص نشطة حاليًا.', textAlign: TextAlign.center)),
          ...stories.map((story) {
            final url = (story['media_url'] ?? '').toString();
            final isVideo = (story['media_type'] ?? 'image').toString() == 'video';
            final caption = (story['caption'] ?? '').toString();
            return Card(
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (isVideo)
                  const SizedBox(height: 190, child: Center(child: Icon(Icons.play_circle_outline, size: 70, color: purple)))
                else if (url.isNotEmpty)
                  Image.network(url, height: 190, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 190, child: Center(child: Icon(Icons.broken_image_outlined, size: 48))))
                else
                  const SizedBox(height: 190, child: Center(child: Icon(Icons.image_outlined, size: 48))),
                if (caption.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(caption)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, required this.activityType, required this.canManage});
  final String activityType;
  final bool canManage;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final service = OfferService();
  final supplierService = SupplierOfferService();

  Future<void> createOffer() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final discount = TextEditingController();
    final imageUrl = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء عرض جديد'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان العرض')),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل العرض')),
          TextField(controller: discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نسبة الخصم (اختياري)')),
          TextField(controller: imageUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط صورة العرض (اختياري)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('نشر العرض')),
        ],
      ),
    );
    if (accepted == true) {
      try {
        final discountValue = discount.text.trim().isEmpty ? null : double.tryParse(discount.text.trim());
        if (discount.text.trim().isNotEmpty && discountValue == null) {
          throw ArgumentError('أدخل نسبة خصم صحيحة.');
        }
        final now = DateTime.now();
        await supplierService.createOffer(
          title: title.text,
          description: description.text,
          startsAt: now,
          endsAt: now.add(const Duration(days: 7)),
          imageUrl: imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
          activityType: widget.activityType,
          discountPercentage: discountValue,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر العرض لمدة 7 أيام.')));
        await loadOffers();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نشر العرض: $e')));
      }
    }
    title.dispose();
    description.dispose();
    discount.dispose();
    imageUrl.dispose();
  }
  List<Map<String, dynamic>> offers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadOffers();
  }

  Future<void> loadOffers() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await service.getOffers(activityType: widget.activityType);
      if (!mounted) return;
      setState(() => offers = result);
    } catch (_) {
      if (!mounted) return;
      setState(() { offers = []; error = 'تعذر تحميل العروض. تأكد من الاتصال بقاعدة البيانات.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadOffers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('عروض الموردين', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple))),
            if (widget.canManage) FilledButton.icon(onPressed: createOffer, icon: const Icon(Icons.add), label: const Text('إضافة عرض')),
          ]),
          const SizedBox(height: 8),
          Text('النشاط: ${widget.activityType}'),
          if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, textAlign: TextAlign.center)),
          if (offers.isEmpty && error == null)
            const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد عروض منشورة حاليًا.', textAlign: TextAlign.center)),
          ...offers.map((offer) {
            final title = (offer['title'] ?? 'عرض من المورد').toString();
            final description = (offer['description'] ?? '').toString();
            final discount = offer['discount_percentage'];
            final ends = offer['ends_at']?.toString();
            return Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.local_offer, color: orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                    if (discount is num && discount > 0)
                      Chip(label: Text('خصم ${discount.toStringAsFixed(0)}%')),
                  ]),
                  if (description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(description)),
                  if (ends != null && ends.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('ينتهي: ${ends.split('T').first}', style: const TextStyle(color: Colors.black54, fontSize: 12))),
                ]),
              ),
            );
          }),
        ],
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
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';

                    if (value.isEmpty) {
                      return 'أدخل رقم واتساب';
                    }

                    if (value.replaceAll(RegExp(r'\D'), '').length < 8) {
                      return 'أدخل رقم واتساب صحيحًا';
                    }

                    return null;
                  },
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
                
validator: (v) {
  if (v == null || v.isEmpty) {
    return 'أعد كتابة كلمة المرور';
  }

  if (v != passwordController.text) {
    return 'كلمتا المرور غير متطابقتين';
  }

  return null;
},
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

String? passwordValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'أدخل كلمة المرور';
  }

  if (value.length < 8) {
    return 'يجب ألا تقل كلمة المرور عن 8 أحرف';
  }

  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'أضف حرفًا إنجليزيًا كبيرًا';
  }

  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'أضف حرفًا إنجليزيًا صغيرًا';
  }

  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'أضف رقمًا واحدًا على الأقل';
  }

  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return 'أضف رمزًا خاصًا مثل @ أو #';
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
  void dispose() { codeController.dispose(); super.dispose(); }

  
  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6 || int.tryParse(code) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رمز التحقق المكوّن من 6 أرقام.'),
        ),
      );
      return;
    }

    final client = database;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الاتصال بالخدمة غير متاح حاليًا.'),
        ),
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

      if (!mounted) return;

      await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => SilsilaRegistrationSuccessScreen(
            onContinue: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const MainShell(),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'رمز التحقق غير صحيح أو انتهت صلاحيته. حاول مرة أخرى.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> resendCode() async {
    if (busy) return;
    final client = database;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا.')));
      return;
    }
    setState(() => busy = true);
    try {
      await client.auth.resend(phone: widget.phone, type: OtpType.sms);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم طلب إرسال رمز جديد إلى هاتفك.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال رمز جديد. حاول لاحقًا.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Icon(Icons.verified_user_outlined, size: 64, color: purple),
    const SizedBox(height: 12),
    const Text('تأكيد رقم الهاتف', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text('أدخل رمز التحقق المرسل إلى ${widget.phone}', textAlign: TextAlign.center),
    const SizedBox(height: 20),
    TextField(controller: codeController, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, autofillHints: const [AutofillHints.oneTimeCode], decoration: const InputDecoration(labelText: 'رمز التحقق', prefixIcon: Icon(Icons.password))),
    const SizedBox(height: 12),
    FilledButton(onPressed: busy ? null : verifyCode, child: Text(busy ? 'جارٍ التحقق...' : 'تأكيد وتفعيل الحساب')),
    TextButton(onPressed: busy ? null : resendCode, child: const Text('إعادة إرسال الرمز')),
  ]);
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
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الاتصال بالخدمة غير متاح حاليًا. حاول مرة أخرى لاحقًا.'),
        ),
      );
      return;
    }

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
  final phone = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool codeSent = false;
  bool busy = false;
  @override
  void dispose() { phone.dispose(); code.dispose(); password.dispose(); confirmation.dispose(); super.dispose(); }

  Future<void> sendCode() async {
    final value = phone.text.trim();
    if (value.length < 8) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم الهاتف المسجل.'))); return; }
    final client = database;
    if (client == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا.'))); return; }
    setState(() => busy = true);
    try { await client.auth.signInWithOtp(phone: value, shouldCreateUser: false); if (mounted) { setState(() => codeSent = true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم طلب إرسال رمز التحقق.'))); } }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال الرمز. راجع إعدادات الرسائل النصية.'))); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> updatePassword() async {
    final token = code.text.trim();
    if (token.length != 6 || int.tryParse(token) == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رمز التحقق المكوّن من 6 أرقام.'))); return; }
    if (password.text.length < 8 || password.text != confirmation.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تأكد من أن كلمة المرور 8 أحرف على الأقل وأن التأكيد مطابق.'))); return; }
    final client = database;
    if (client == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا.'))); return; }
    setState(() => busy = true);
    try {
      await client.auth.verifyOTP(phone: phone.text.trim(), token: token, type: OtpType.sms);
      await client.auth.updateUser(UserAttributes(password: password.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح.')));
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (route) => false);
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث كلمة المرور. تحقق من الرمز وحاول مرة أخرى.'))); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Icon(Icons.lock_reset, size: 60, color: purple),
    const SizedBox(height: 12),
    const Text('استعادة كلمة المرور', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف المسجل', prefixIcon: Icon(Icons.phone))),
    FilledButton(onPressed: busy ? null : sendCode, child: Text(busy ? 'جارٍ الإرسال...' : 'إرسال رمز التحقق')),
    if (codeSent) ...[
      TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'رمز التحقق')),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
      TextField(controller: confirmation, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
      FilledButton(onPressed: busy ? null : updatePassword, child: Text(busy ? 'جارٍ التحديث...' : 'تحديث كلمة المرور')),
    ],
  ]);
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
            ].where((part) => part.toString().trim().isNotEmpty).join('\n');
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
                    subtitle: Text([body, if (date.isNotEmpty) date.split('T').first].where((v) => v.isNotEmpty).join('\n')),
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

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final service = AddressService();
  List<Map<String, dynamic>> addresses = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    try {
      final rows = await service.getAddresses();
      if (!mounted) return;
      setState(() { addresses = rows; error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'سجّل الدخول لعرض عناوينك المحفوظة.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editAddress({Map<String, dynamic>? existing}) async {
    final title = TextEditingController(text: (existing?['title'] ?? '').toString());
    final governorate = TextEditingController(text: (existing?['governorate'] ?? '').toString());
    final district = TextEditingController(text: (existing?['district'] ?? '').toString());
    final village = TextEditingController(text: (existing?['village'] ?? '').toString());
    final landmark = TextEditingController(text: (existing?['landmark'] ?? '').toString());
    final address = TextEditingController(text: (existing?['address'] ?? '').toString());
    bool isDefault = existing?['is_default'] == true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة عنوان جديد' : 'تعديل العنوان'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم العنوان (المنزل، المخزن...)')),
            TextField(controller: governorate, decoration: const InputDecoration(labelText: 'المحافظة')),
            TextField(controller: district, decoration: const InputDecoration(labelText: 'المركز أو المدينة')),
            TextField(controller: village, decoration: const InputDecoration(labelText: 'القرية أو الحي')),
            TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'العنوان بالتفصيل')),
            TextField(controller: landmark, decoration: const InputDecoration(labelText: 'علامة مميزة (اختياري)')),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isDefault,
              title: const Text('جعله العنوان الافتراضي'),
              onChanged: (value) => setDialogState(() => isDefault = value ?? false),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ العنوان')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      try {
        final args = {
          'title': title.text,
          'governorate': governorate.text,
          'district': district.text,
          'village': village.text,
          'landmark': landmark.text,
          'address': address.text,
          'isDefault': isDefault,
        };
        if (existing == null) {
          await service.addAddress(
            title: args['title'] as String,
            governorate: args['governorate'] as String,
            address: args['address'] as String,
            district: args['district'] as String,
            village: args['village'] as String,
            landmark: args['landmark'] as String,
            isDefault: args['isDefault'] as bool,
          );
        } else {
          await service.updateAddress(
            addressId: existing['id'].toString(),
            title: args['title'] as String,
            governorate: args['governorate'] as String,
            address: args['address'] as String,
            district: args['district'] as String,
            village: args['village'] as String,
            landmark: args['landmark'] as String,
            isDefault: args['isDefault'] as bool,
          );
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العنوان.')));
        await loadAddresses();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ العنوان: $e')));
      }
    }
    title.dispose();
    governorate.dispose();
    district.dispose();
    village.dispose();
    landmark.dispose();
    address.dispose();
  }

  Future<void> deleteAddress(Map<String, dynamic> item) async {
    try {
      await service.deleteAddress(item['id'].toString());
      await loadAddresses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف العنوان: $e')));
    }
  }

  Future<void> makeDefault(Map<String, dynamic> item) async {
    try {
      await service.setDefaultAddress(item['id'].toString());
      await loadAddresses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تعيين العنوان الافتراضي: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: loadAddresses,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('عناويني المحفوظة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple))),
          FilledButton.icon(onPressed: () => editAddress(), icon: const Icon(Icons.add), label: const Text('إضافة')),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        if (addresses.isEmpty && error == null) const Padding(padding: EdgeInsets.all(24), child: Text('لم تحفظ عناوين بعد.', textAlign: TextAlign.center)),
        ...addresses.map((item) {
          final isDefault = item['is_default'] == true;
          final subtitle = [
            item['governorate'],
            item['district'],
            item['village'],
            item['address'],
            if ((item['landmark'] ?? '').toString().isNotEmpty) 'علامة مميزة: ${item['landmark']}',
          ].where((value) => value != null && value.toString().trim().isNotEmpty).join(' • ');
          return Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(isDefault ? Icons.location_on : Icons.location_on_outlined, color: isDefault ? orange : purple),
              title: Row(children: [
                Expanded(child: Text((item['title'] ?? 'عنوان').toString())),
                if (isDefault) const Chip(label: Text('افتراضي')),
              ]),
              subtitle: Text(subtitle),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') editAddress(existing: item);
                  if (value == 'default') makeDefault(item);
                  if (value == 'delete') deleteAddress(item);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  if (!isDefault) const PopupMenuItem(value: 'default', child: Text('تعيين افتراضي')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ),
          );
        }),
      ]),
    );
  }
}

class LoyaltyOverviewScreen extends StatefulWidget {
  const LoyaltyOverviewScreen({super.key});

  @override
  State<LoyaltyOverviewScreen> createState() => _LoyaltyOverviewScreenState();
}

class _LoyaltyOverviewScreenState extends State<LoyaltyOverviewScreen> {
  final service = LoyaltyService();
  late Future<Map<String, dynamic>> dataFuture;

  @override
  void initState() {
    super.initState();
    dataFuture = loadData();
  }

  Future<Map<String, dynamic>> loadData() async {
    final results = await Future.wait([
      service.getPointsBalance(),
      service.getPointsHistory(limit: 50),
      service.getMyGoals(),
    ]);
    return {
      'balance': results[0] as int,
      'history': results[1] as List<Map<String, dynamic>>,
      'goals': results[2] as List<Map<String, dynamic>>,
    };
  }

  Future<void> reload() async {
    setState(() => dataFuture = loadData());
    await dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: purple));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.stars_outlined, size: 58, color: purple),
                const Text('سجّل الدخول لعرض نقاط الولاء وأهدافك.', textAlign: TextAlign.center),
                TextButton(onPressed: reload, child: const Text('إعادة المحاولة')),
              ]),
            ),
          );
        }
        final data = snapshot.data ?? const {};
        final balance = data['balance'] as int? ?? 0;
        final history = (data['history'] as List<Map<String, dynamic>>?) ?? const [];
        final goals = (data['goals'] as List<Map<String, dynamic>>?) ?? const [];
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [purple, Color(0xFF7026A8), pink]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('رصيد نقاط سلسلة', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('$balance نقطة', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('تابع تعاملاتك وأهدافك واستفد من برنامج الولاء.', style: TextStyle(color: Colors.white)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('أهدافي', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            if (goals.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('ستظهر أهدافك هنا عند إضافتها إلى حسابك.'))),
            ...goals.map((goal) {
              final title = (goal['title'] ?? goal['name'] ?? 'هدف جديد').toString();
              final current = num.tryParse((goal['current_value'] ?? 0).toString()) ?? 0;
              final target = num.tryParse((goal['target_value'] ?? goal['target'] ?? 0).toString()) ?? 0;
              final progress = service.calculateGoalProgress(currentValue: current, targetValue: target);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress / 100, color: orange, backgroundColor: purple.withOpacity(.1)),
                    const SizedBox(height: 6),
                    Text('$current من $target • ${progress.toStringAsFixed(0)}%'),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 20),
            const Text('سجل النقاط', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            if (history.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد حركات نقاط مسجلة حتى الآن.'))),
            ...history.map((entry) {
              final points = entry['points'] ?? 0;
              final description = (entry['description'] ?? 'حركة نقاط').toString();
              final date = entry['created_at']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: Icon(Icons.stars, color: (points is num && points < 0) ? Colors.red : orange),
                  title: Text(description),
                  subtitle: Text(date.isEmpty ? '' : date.split('T').first),
                  trailing: Text('$points نقطة', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            }),
          ]),
        );
      },
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
    final topUps = await service.getMyTopUpRequests(limit: 30);
    return {'balance': balance, 'transactions': transactions, 'topUps': topUps};
  }

  Future<void> reload() async {
    setState(() => walletFuture = loadWallet());
    await walletFuture;
  }

  Future<void> requestTopUp() async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
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
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(labelText: 'رقم مرجع التحويل أو الإيداع (اختياري)'),
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
      referenceController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    final paymentReference = referenceController.text.trim();
    amountController.dispose();
    referenceController.dispose();
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
        reference: paymentReference.isEmpty ? null : paymentReference,
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
        final topUps = (data['topUps'] as List<Map<String, dynamic>>?) ?? const [];
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
              const SizedBox(height: 22),
              const Text('طلبات الشحن وحالة المراجعة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (topUps.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد طلبات شحن سابقة.'))),
              ...topUps.map((request) {
                final amount = request['amount'];
                final status = (request['status'] ?? 'pending').toString();
                final method = (request['payment_method'] ?? '').toString();
                final reference = (request['reference'] ?? '').toString();
                final date = request['created_at']?.toString() ?? '';
                final note = (request['review_note'] ?? '').toString();
                final statusLabel = switch (status) {
                  'approved' => 'تم الاعتماد',
                  'rejected' => 'مرفوض',
                  'pending' => 'قيد المراجعة',
                  _ => status,
                };
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: Icon(
                      status == 'approved' ? Icons.check_circle_outline : status == 'rejected' ? Icons.cancel_outlined : Icons.hourglass_top,
                      color: status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : orange,
                    ),
                    title: Text('${amount ?? 0} ج.م • $statusLabel'),
                    subtitle: Text([
                      if (method.isNotEmpty) method,
                      if (reference.isNotEmpty) 'مرجع: $reference',
                      if (date.isNotEmpty) date.split('T').first,
                      if (note.isNotEmpty) note,
                    ].join(' • ')),
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

  Future<void> changeSupplierOrderStatus(Map<String, dynamic> order, String nextStatus) async {
    final id = int.tryParse((order['id'] ?? '').toString());
    if (id == null) return;
    try {
      await OrderStatusService().updateOrderStatus(orderId: id, status: nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث الطلب إلى: $nextStatus')));
      await reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الطلب: $e')));
    }
  }

  Future<void> cancelCustomerOrder(Map<String, dynamic> order) async {
    final id = int.tryParse((order['id'] ?? '').toString());
    if (id == null) return;
    try {
      await OrderStatusService().cancelOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب.')));
      await reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إلغاء الطلب: $e')));
    }
  }

  Future<void> reviewSupplier(Map<String, dynamic> order) async {
    final supplierId = (order['supplier_id'] ?? '').toString();
    final orderId = (order['id'] ?? '').toString();
    if (supplierId.isEmpty || orderId.isEmpty) return;
    final comment = TextEditingController();
    int rating = 5;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تقييم المورد'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('كيف كانت تجربتك مع هذا المورد؟'),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: () => setDialogState(() => rating = value),
                  icon: Icon(value <= rating ? Icons.star : Icons.star_border, color: orange, size: 30),
                );
              }),
            ),
            TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(labelText: 'تعليق اختياري')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إرسال التقييم')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      try {
        await ReviewService().addReview(
          supplierId: supplierId,
          orderId: orderId,
          rating: rating,
          comment: comment.text,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكرًا لك، تم إرسال تقييمك.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التقييم: $e')));
      }
    }
    comment.dispose();
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
                    const SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: OrderStatusService().getOrderItems(int.tryParse((order['id'] ?? '').toString()) ?? 0),
                      builder: (context, itemSnapshot) {
                        if (itemSnapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator(minHeight: 2);
                        }
                        if (itemSnapshot.hasError) {
                          return const Align(alignment: Alignment.centerRight, child: Text('تعذر تحميل تفاصيل الأصناف.'));
                        }
                        final items = itemSnapshot.data ?? const <Map<String, dynamic>>[];
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...items.map((item) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text((item['product_name'] ?? 'منتج').toString()),
                            subtitle: Text('${item['quantity'] ?? 0} ${item['unit'] ?? ''} × ${item['unit_price'] ?? 0} ج.م'),
                            trailing: Text('${item['line_total'] ?? item['total_price'] ?? 0} ج.م'),
                          )),
                        ]);
                      },
                    ),
                    if (isSupplier) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (status == 'انتظار قبول')
                          FilledButton(onPressed: () => changeSupplierOrderStatus(order, 'تنفيذ'), child: const Text('قبول الطلب')),
                        if (status == 'تنفيذ')
                          FilledButton(onPressed: () => changeSupplierOrderStatus(order, 'تحميل'), child: const Text('بدء التحميل')),
                        if (status == 'تحميل')
                          FilledButton(onPressed: () => changeSupplierOrderStatus(order, 'توصيل'), child: const Text('إرسال للتوصيل')),
                        if (status == 'توصيل')
                          FilledButton(onPressed: () => changeSupplierOrderStatus(order, 'تم التسليم'), child: const Text('تأكيد التسليم')),
                        if (status == 'انتظار قبول' || status == 'تنفيذ')
                          OutlinedButton(onPressed: () => changeSupplierOrderStatus(order, 'مُلغي'), child: const Text('إلغاء الطلب')),
                      ]),
                    ],
                    if (!isSupplier && status == 'انتظار قبول')
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => cancelCustomerOrder(order),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('إلغاء الطلب'),
                        ),
                      ),
                    if (!isSupplier && status == 'تم التسليم')
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => reviewSupplier(order),
                          icon: const Icon(Icons.star_outline),
                          label: const Text('تقييم المورد'),
                        ),
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

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.total, required this.itemCount, required this.items, required this.onSuccess});
  final double total;
  final int itemCount;
  final List<Map<String, dynamic>> items;
  final VoidCallback onSuccess;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}
class _CheckoutScreenState extends State<CheckoutScreen> {
  final address = TextEditingController();
  final notes = TextEditingController();
  final service = CheckoutService();
  final addressService = AddressService();
  List<Map<String, dynamic>> savedAddresses = [];
  String? selectedAddressId;
  String method = 'نقدي';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    loadSavedAddresses();
  }

  Future<void> loadSavedAddresses() async {
    if (database?.auth.currentUser == null) return;
    try {
      final rows = await addressService.getAddresses();
      if (!mounted) return;
      setState(() {
        savedAddresses = rows;
        Map<String, dynamic>? preferred;
        for (final row in rows) {
          if (row['is_default'] == true) {
            preferred = row;
            break;
          }
        }
        if (preferred != null) {
          selectedAddressId = preferred['id']?.toString();
          address.text = formatAddress(preferred);
        } else if (rows.isNotEmpty && address.text.trim().isEmpty) {
          selectedAddressId = rows.first['id']?.toString();
          address.text = formatAddress(rows.first);
        }
      });
    } catch (_) {
      // Manual address entry remains available if saved addresses cannot be loaded.
    }
  }

  String formatAddress(Map<String, dynamic> item) {
    return [
      item['governorate'],
      item['district'],
      item['village'],
      item['address'],
      if ((item['landmark'] ?? '').toString().trim().isNotEmpty) 'علامة مميزة: ${item['landmark']}',
    ].where((value) => value != null && value.toString().trim().isNotEmpty).join('، ');
  }

  Future<void> openAddressBook() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text('عناويني المحفوظة')),
            body: AddressBookScreen(),
          ),
        ),
      ),
    );
    await loadSavedAddresses();
  }
  @override
  void dispose() { address.dispose(); notes.dispose(); super.dispose(); }
  Future<void> send() async {
    if (database?.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولًا لإتمام الطلب.')));
      return;
    }
    if (address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل عنوان التوصيل بالتفصيل قبل تأكيد الطلب.')));
      return;
    }
    if (widget.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('السلة فارغة؛ أضف منتجات أولًا.')));
      return;
    }
    final items = <CartItem>[];
    for (final row in widget.items) {
      final p = row['product'] as Product;
      if (p.id == null || (p.supplierId ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن طلب المنتجات التوضيحية؛ اختر منتجًا منشورًا من مورد.')));
        return;
      }
      items.add(CartItem(productId: p.id!, name: p.name, supplierId: p.supplierId!, category: p.category, unit: p.unit, price: p.price, minQuantity: p.minQuantity, quantity: row['quantity'] as int));
    }
    setState(() => busy = true);
    try {
      final code = {'نقدي':'cash','آجل مورد':'supplier_credit','محفظة كاش':'wallet','تحويل بنكي':'bank_transfer','من الرصيد':'account_balance'}[method]!;
      final created = await service.checkout(items: items, paymentMethod: code, deliveryAddress: address.text, notes: notes.text);
      if (!mounted) return;
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء ${created.length} طلب.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(child: ListTile(title: const Text('عدد الوحدات'), trailing: Text('${widget.itemCount}'))),
    Card(child: ListTile(title: const Text('الإجمالي التقديري'), trailing: Text('${widget.total.toStringAsFixed(2)} ج.م'))),
    if (savedAddresses.isNotEmpty)
      DropdownButtonFormField<String>(
        value: savedAddresses.any((item) => item['id']?.toString() == selectedAddressId) ? selectedAddressId : null,
        decoration: const InputDecoration(labelText: 'اختر عنوانًا محفوظًا'),
        items: savedAddresses.map((item) => DropdownMenuItem<String>(
          value: item['id'].toString(),
          child: Text((item['title'] ?? 'عنوان محفوظ').toString()),
        )).toList(),
        onChanged: (value) {
          Map<String, dynamic>? selected;
          for (final item in savedAddresses) {
            if (item['id']?.toString() == value) {
              selected = item;
              break;
            }
          }
          if (selected == null) return;
          setState(() {
            selectedAddressId = value;
            address.text = formatAddress(selected);
          });
        },
      ),
    TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'عنوان التوصيل بالتفصيل')),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: openAddressBook,
        icon: const Icon(Icons.location_on_outlined),
        label: const Text('إدارة العناوين المحفوظة'),
      ),
    ),
    const SizedBox(height: 10),
    TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات إضافية')),
    const SizedBox(height: 10),
    const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
    ...['نقدي','آجل مورد','محفظة كاش','تحويل بنكي','من الرصيد'].map((v) => RadioListTile<String>(value: v, groupValue: method, title: Text(v), onChanged: (x) => setState(() => method = x ?? 'نقدي'))),
    FilledButton(onPressed: busy ? null : send, child: Text(busy ? 'جارٍ الإرسال...' : 'تأكيد وإرسال الطلب')),
    const Text('يتم التحقق من السعر داخل قاعدة البيانات عند إنشاء الطلب.', style: TextStyle(fontSize: 12, color: Colors.black54)),
  ]);
}

