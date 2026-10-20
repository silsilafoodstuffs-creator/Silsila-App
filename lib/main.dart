import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'erp/screens/erp_login_gate.dart';
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

const egyptGovernorates = [
  'القاهرة',
  'الجيزة',
  'القليوبية',
  'الإسكندرية',
  'الشرقية',
  'الدقهلية',
  'البحيرة',
  'الغربية',
  'المنوفية',
  'كفر الشيخ',
  'دمياط',
  'بورسعيد',
  'الإسماعيلية',
  'السويس',
  'شمال سيناء',
  'جنوب سيناء',
  'بني سويف',
  'الفيوم',
  'المنيا',
  'أسيوط',
  'سوهاج',
  'قنا',
  'الأقصر',
  'أسوان',
  'البحر الأحمر',
  'الوادي الجديد',
  'مطروح',
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
    this.imageUrl,
    this.subcategory,
    this.brand,
    this.packageCount = 1,
    this.smallUnit,
    this.offerPrice,
  });

  final String name;
  final String category;
  final double price;
  final String unit;
  final IconData icon;
  final String? id;
  final String? supplierId;
  final int minQuantity;
  final String? imageUrl;
  final String? subcategory;
  final String? brand;
  final int packageCount;
  final String? smallUnit;
  final double? offerPrice;

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
        hoverColor: orange.withValues(alpha: 0.10),
        splashColor: pink.withValues(alpha: 0.12),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: purple,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: orange.withValues(alpha: 0.30),
            animationDuration: const Duration(milliseconds: 180),
            overlayColor: orange.withValues(alpha: 0.18),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: purple,
            foregroundColor: Colors.white,
            elevation: 1,
            shadowColor: orange.withValues(alpha: 0.24),
            animationDuration: const Duration(milliseconds: 180),
            overlayColor: orange.withValues(alpha: 0.18),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: purple,
            overlayColor: pink.withValues(alpha: 0.10),
            side: const BorderSide(color: Color(0xFFE5DDED)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: purple,
            overlayColor: pink.withValues(alpha: 0.10),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5DDED)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5DDED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: orange, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB3261E)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.8),
          ),
        ),
      ),
      home: kIsWeb
          ? const ErpLoginGate()
          : const Directionality(
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
                Image.asset(
                  'assets/images/silsila_logo.png',
                  width: 132,
                  height: 132,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.hub_rounded,
                    size: 76,
                    color: orange,
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
                        builder: (_) => const LoginScreen(),
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
          backgroundColor: color.withValues(alpha: .12),
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

class _AdvertisementSlide {
  const _AdvertisementSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? imageUrl;
}

class _HomeAdvertisementsCarousel extends StatefulWidget {
  const _HomeAdvertisementsCarousel();

  @override
  State<_HomeAdvertisementsCarousel> createState() => _HomeAdvertisementsCarouselState();
}

class _HomeAdvertisementsCarouselState extends State<_HomeAdvertisementsCarousel> {
  static const _fallbackAds = <_AdvertisementSlide>[
    _AdvertisementSlide(icon: Icons.hub_rounded, title: 'سلسلة Silsila', subtitle: 'بنربط السوق ببعضه'),
    _AdvertisementSlide(icon: Icons.local_shipping_rounded, title: 'توريد أسرع لتجارتك', subtitle: 'الموردون والتجار في مكان واحد'),
    _AdvertisementSlide(icon: Icons.storefront_rounded, title: 'اكتشف الموردين', subtitle: 'وسّع شبكة تعاملاتك التجارية'),
    _AdvertisementSlide(icon: Icons.local_offer_rounded, title: 'عروض التجار', subtitle: 'تابع أحدث الفرص والعروض'),
    _AdvertisementSlide(icon: Icons.shopping_basket_rounded, title: 'كل احتياجات تجارتك', subtitle: 'ابدأ رحلة الشراء مع سلسلة'),
  ];

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  List<_AdvertisementSlide> _ads = _fallbackAds;
  bool _loadingAds = false;

  @override
  void initState() {
    super.initState();
    _loadManagedAdvertisements();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _ads.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadManagedAdvertisements() async {
    final client = database;
    if (client == null || _loadingAds) return;
    _loadingAds = true;
    try {
      // This read-only RPC exposes only the five public Silsila banner slots,
      // so customers do not need to belong to the ERP-owning company.
      final rows = await client.rpc('get_silsila_public_ads');
      final bySlot = <String, String>{};
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        final slot = row['display_name']?.toString() ?? '';
        final path = row['storage_path']?.toString() ?? '';
        if (const ['إعلان 1', 'إعلان 2', 'إعلان 3', 'إعلان 4', 'إعلان 5'].contains(slot) &&
            path.isNotEmpty && !bySlot.containsKey(slot)) {
          bySlot[slot] = client.storage.from('silsila-public-ads').getPublicUrl(path);
        }
      }
      if (!mounted || bySlot.isEmpty) return;
      final loaded = List<_AdvertisementSlide>.generate(5, (i) {
        final fallback = _fallbackAds[i];
        return _AdvertisementSlide(
          icon: fallback.icon,
          title: fallback.title,
          subtitle: fallback.subtitle,
          imageUrl: bySlot['إعلان ${i + 1}'],
        );
      });
      setState(() => _ads = loaded);
    } catch (_) {
      // The home page remains usable until the Supabase migration is applied.
    } finally {
      _loadingAds = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _ads.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final ad = _ads[index];
                if (ad.imageUrl != null) {
                  return Image.network(
                    ad.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackSlide(ad),
                  );
                }
                return _fallbackSlide(ad);
              },
            ),
            Positioned(
              bottom: 9,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_ads.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? orange : Colors.white54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackSlide(_AdvertisementSlide ad) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [purple, Color(0xFF7026A8), Color(0xFF32105A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ad.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text(ad.subtitle, style: const TextStyle(color: orange, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
            child: Icon(ad.icon, size: 40, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.testRole,
    this.testAccountName,
  });

  final String? testRole;
  final String? testAccountName;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 3;
  String selectedEntity = 'الفئات';
  bool listViewMode = true;
  bool showProductImages = true;
  final Set<String> expandedCatalogCategories = <String>{};
  final Set<String> expandedCatalogSubcategories = <String>{};
  final Set<String> expandedCatalogBrands = <String>{};
  String activity = 'مواد غذائية';
  String selectedCategory = 'الكل';
  String search = '';
  String accountName = 'تاجر سلسلة';
  final favorites = <String>{};
  final favoriteService = FavoriteService();
  final cart = <String, int>{};
  final cartProducts = <String, Product>{};
  final searchController = TextEditingController();
  final GlobalKey<_MarketPostsSectionState> marketPostsKey =
      GlobalKey<_MarketPostsSectionState>();
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

  // Real catalog data takes precedence whenever Supabase is configured.
  // Demo catalog entries are shown only in offline/demo mode, never as live inventory.
  List<Product> get allProducts =>
      liveProducts.isNotEmpty ? liveProducts : (database == null ? products : const <Product>[]);

  List<String> get visibleCategoryNames => liveCategoryNames.isNotEmpty
      ? ['الكل', ...liveCategoryNames]
      : (database == null ? categories : const <String>['الكل']);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('الإشعارات')),
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
    if (widget.testRole != null) {
      if (mounted) {
        setState(() {
          isAdmin = false;
          isApprovedSupplier = widget.testRole == 'supplier';
          if (widget.testAccountName != null) {
            accountName = widget.testAccountName!;
          }
        });
      }
      return;
    }
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
      Map<String, double> activeOfferPrices = <String, double>{};
      try {
        activeOfferPrices = await OfferService().getActiveProductOfferPrices();
      } catch (_) {
        // Product browsing should remain available if offer data is unavailable.
      }
      final mapped = rows.map((row) {
        final category = (row['category'] ??
                row['category_name'] ??
                '').toString();
        final rawId = row['id'];
        final id = rawId?.toString().trim();
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
          id: (id == null || id.isEmpty) ? null : id,
          supplierId: row['supplier_id']?.toString(),
          minQuantity: minQuantity < 1 ? 1 : minQuantity,
          imageUrl: (row['image_url'] ?? '').toString().trim().isEmpty ? null : row['image_url'].toString(),
          subcategory: (row['subcategory'] ?? '').toString().trim().isEmpty ? null : row['subcategory'].toString(),
          brand: (row['brand'] ?? '').toString().trim().isEmpty ? null : row['brand'].toString(),
          packageCount: (row['package_count'] is num ? (row['package_count'] as num).toInt() : int.tryParse((row['package_count'] ?? '1').toString()) ?? 1).clamp(1, 100000).toInt(),
          smallUnit: (row['small_unit'] ?? '').toString().trim().isEmpty ? null : row['small_unit'].toString(),
          offerPrice: activeOfferPrices[id ?? ''] ??
              (row['offer_price'] is num
                  ? (row['offer_price'] as num).toDouble()
                  : double.tryParse((row['offer_price'] ?? '').toString())),
        );
      }).where((p) => p.id != null && p.name.trim().isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        liveProducts = mapped;
        loadingLiveProducts = false;
        productLoadMessage = mapped.isEmpty
            ? 'لا توجد منتجات منشورة من الموردين المعتمدين حتى الآن.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingLiveProducts = false;
        productLoadMessage = 'تعذر تحميل الكتالوج الفعلي الآن؛ حدّث البيانات أو حاول لاحقًا.';
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
      OffersScreen(activityType: activity, canManage: isApprovedSupplier, availableProducts: allProducts),
      marketPage(),
      StoriesScreen(activityType: activity),
      homePage(),
      cartPage(),
      favoritesPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: Drawer(
          child: SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: morePage(),
            ),
          ),
        ),
        appBar: AppBar(
          title: const Text(
            'سلسلة Silsila',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: Builder(
            builder: (drawerContext) => IconButton(
              tooltip: 'المزيد',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(drawerContext).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: openNotifications,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (unreadNotifications > 0)
                    Positioned(
                      top: -7,
                      right: -9,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: pink,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadNotifications > 99
                              ? '99+'
                              : '$unreadNotifications',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تحديث البيانات',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                loadLiveProducts();
                loadLiveSuppliers();
                loadLiveCategories();
                loadUnreadNotifications();
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: purple.withValues(alpha: .08),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: Row(
              children: [
                _quickTask(Icons.local_offer_outlined, 'العروض', 0),
                _quickTask(Icons.storefront_outlined, 'سوق التجار', 1),
                _quickTask(Icons.auto_awesome_outlined, 'القصص', 2),
                _quickTask(Icons.home_rounded, 'الرئيسية', 3),
                _quickTask(
                  Icons.shopping_cart_outlined,
                  'السلة',
                  4,
                  badgeCount: cart.values.fold<int>(0, (a, b) => a + b),
                ),
                _quickTask(
                  Icons.favorite_border_rounded,
                  'المفضلة',
                  5,
                  badgeCount: favorites.length,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickTask(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final selected = tab == index;
    return Expanded(
      child: Material(
        color: selected ? purple.withValues(alpha: .07) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => tab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: selected ? purple : Colors.black54,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -6,
                        right: -9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: const BoxDecoration(
                            color: pink,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? purple : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    final entities = [
      ('الفئات', Icons.category_outlined),
      ('الأصناف', Icons.inventory_2_outlined),
      ('الموردين', Icons.storefront_outlined),
      ('العملاء', Icons.people_alt_outlined),
      ('المناديب', Icons.badge_outlined),
      ('شركات الشحن', Icons.local_shipping_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: [
        if (loadingLiveProducts)
          const LinearProgressIndicator(minHeight: 2),
        // Keep search as the first control on the home screen.
        SizedBox(
          height: 36,
          child: TextField(
            controller: searchController,
            onChanged: (value) => setState(() => search = value),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ابحث عن فئة أو صنف أو مورد أو عميل...',
              prefixIcon: const Icon(Icons.search, color: purple, size: 20),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 42,
                minHeight: 36,
              ),
              suffixIcon: search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        searchController.clear();
                        setState(() => search = '');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: purple.withValues(alpha: .12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: purple.withValues(alpha: .12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _HomeAdvertisementsCarousel(),
        const SizedBox(height: 12),
        const Text(
          'نوع النشاط',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 43,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: activityTypes.map((type) {
              final selected = activity == type;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.business_center_outlined,
                    size: 17,
                    color: selected ? Colors.white : purple,
                  ),
                  label: Text(type),
                  selected: selected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : purple,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: purple,
                  side: BorderSide(
                    color: purple.withValues(alpha: .15),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (_) {
                    if (activity == type) return;
                    setState(() {
                      activity = type;
                      selectedCategory = 'الكل';
                      liveProducts = [];
                      liveSuppliers = [];
                      liveCategoryNames = [];
                    });
                    loadLiveProducts();
                    loadLiveSuppliers();
                    loadLiveCategories();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'تصفح حسب',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 43,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: entities.map((entity) {
              final selected = selectedEntity == entity.$1;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: ChoiceChip(
                  avatar: Icon(
                    entity.$2,
                    size: 17,
                    color: selected ? Colors.white : purple,
                  ),
                  label: Text(entity.$1),
                  selected: selected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : purple,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: purple,
                  side: BorderSide(color: purple.withValues(alpha: .15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (_) => setState(() {
                    selectedEntity = entity.$1;
                    if (selectedEntity == 'الفئات') selectedCategory = 'الكل';
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: purple.withValues(alpha: .10)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, color: purple, size: 19),
              const SizedBox(width: 6),
              const Text(
                'طريقة العرض',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _viewModeButton(
                icon: Icons.grid_view_rounded,
                label: 'شبكي',
                selected: !listViewMode,
                onTap: () => setState(() => listViewMode = false),
              ),
              const SizedBox(width: 5),
              _viewModeButton(
                icon: Icons.view_list_rounded,
                label: 'قائمة',
                selected: listViewMode,
                onTap: () => setState(() => listViewMode = true),
              ),
              Container(
                height: 25,
                width: 1,
                color: Colors.black12,
                margin: const EdgeInsets.symmetric(horizontal: 7),
              ),
              IconButton(
                tooltip: showProductImages ? 'إخفاء الصور' : 'إظهار الصور',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () =>
                    setState(() => showProductImages = !showProductImages),
                icon: Icon(
                  showProductImages
                      ? Icons.image_rounded
                      : Icons.hide_image_outlined,
                  color: showProductImages ? purple : Colors.black45,
                  size: 20,
                ),
              ),
              Text(
                showProductImages ? 'بالصور' : 'بدون',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        if (selectedEntity == 'الفئات') ...[
          _sectionTitle('فئات الأصناف', visibleCategoryNames.length - 1),
          const SizedBox(height: 8),
          if (visibleCategoryNames.where((c) => c != 'الكل').isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('لا توجد فئات مسجلة حتى الآن.', textAlign: TextAlign.center),
            ),
          if (listViewMode) ...[
          ...visibleCategoryNames.where((c) => c != 'الكل').map((category) {
            final expanded = expandedCatalogCategories.contains(category);
            final productsInCategory = visible.where((p) => p.category == category).toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 7),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(_iconForCategory(category), color: purple),
                    title: Text(category, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${productsInCategory.length} صنف'),
                    trailing: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: purple),
                    onTap: () => setState(() {
                      if (expanded) {
                        expandedCatalogCategories.remove(category);
                      } else {
                        expandedCatalogCategories.add(category);
                      }
                    }),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12, end: 12, bottom: 10),
                      child: productsInCategory.isEmpty
                          ? const Align(
                              alignment: Alignment.centerRight,
                              child: Text('لا توجد أصناف منشورة تحت هذه الفئة بعد.', style: TextStyle(color: Colors.black54, fontSize: 12)),
                            )
: _catalogSubcategoryTree(category, productsInCategory),
                    ),
                ],
              ),
            );
          }),
          ] else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleCategoryNames.where((c) => c != 'الكل').length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (context, index) {
                final category = visibleCategoryNames.where((c) => c != 'الكل').elementAt(index);
                final productsInCategory = visible.where((p) => p.category == category).toList();
                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      selectedEntity = 'الأصناف';
                      selectedCategory = category;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Icon(_iconForCategory(category), color: purple, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text('${productsInCategory.length} صنف',
                                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left_rounded, color: purple, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

        ] else if (selectedEntity == 'الأصناف') ...[
          _sectionTitle('الأصناف', visible.length),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: visibleCategoryNames.map((category) {
                final selected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 7),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    selectedColor: orange.withValues(alpha: .25),
                    onSelected: (_) => setState(() => selectedCategory = category),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          _productResults(visible),
        ] else if (selectedEntity == 'الموردين') ...[
          _sectionTitle(
            'الموردون',
            database == null
                ? suppliers.where((name) => search.isEmpty || name.toLowerCase().contains(search.toLowerCase())).length
                : liveSuppliers.where((supplier) {
                    final name = (supplier['full_name'] ?? '').toString().toLowerCase();
                    return search.isEmpty || name.contains(search.toLowerCase());
                  }).length,
          ),
          if (database == null)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'وضع عرض تجريبي: الأسماء التالية أمثلة للواجهة وليست حسابات موردين مسجلة.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          if (loadingLiveSuppliers)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 6),
          if (liveSuppliers.isNotEmpty)
            ...liveSuppliers.where((supplier) {
              final name = (supplier['full_name'] ?? '').toString().toLowerCase();
              return search.isEmpty || name.contains(search.toLowerCase());
            }).map(supplierDirectoryTile)
          else if (database == null)
            ...suppliers.where((name) =>
                search.isEmpty || name.toLowerCase().contains(search.toLowerCase()))
                .map(supplierTile)
          else if (!loadingLiveSuppliers)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'لا توجد حسابات موردين معتمدة منشورة حاليًا.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ] else ...[
          _sectionTitle(selectedEntity, 0),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: purple.withValues(alpha: .10)),
            ),
            child: Column(
              children: [
                Icon(
                  selectedEntity == 'العملاء'
                      ? Icons.people_alt_outlined
                      : selectedEntity == 'المناديب'
                          ? Icons.badge_outlined
                          : Icons.local_shipping_outlined,
                  size: 42,
                  color: purple,
                ),
                const SizedBox(height: 9),
                Text(
                  'قسم $selectedEntity',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  selectedEntity == 'العملاء'
                      ? 'تصفح حسابات العملاء وتصنيفاتهم عند توفر بيانات الدليل.'
                      : selectedEntity == 'المناديب'
                          ? 'اعرض المناديب وتصنيفاتهم ومناطق التغطية.'
                          : 'اعرض شركات الشحن وخدمات التوصيل ومناطق الخدمة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => openPage(
                    selectedEntity,
                    SimpleListPage(
                      title: selectedEntity,
                      details: 'يمكن إدارة بيانات هذا القسم من خلال حسابات سلسلة والبيانات المعتمدة.',
                      icon: selectedEntity == 'العملاء'
                          ? Icons.people_alt_outlined
                          : selectedEntity == 'المناديب'
                              ? Icons.badge_outlined
                              : Icons.local_shipping_outlined,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح القسم'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _viewModeButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? purple : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : purple),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white : purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, int count) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: orange.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count', style: const TextStyle(color: purple, fontSize: 11)),
            ),
        ],
      );

  Widget _productResults(List<Product> visible) {
    if (visible.isEmpty) {
      final hasQuery = search.trim().isNotEmpty || selectedCategory != 'الكل';
      final message = database != null && liveProducts.isEmpty
          ? (productLoadMessage ?? 'لا توجد منتجات منشورة حاليًا من الموردين المعتمدين.')
          : hasQuery
              ? 'لا توجد أصناف مطابقة للبحث الحالي.'
              : 'لا توجد منتجات لعرضها حاليًا.';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 42, color: purple),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (database != null && liveProducts.isEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'ستظهر المنتجات هنا بعد أن ينشر المورد المعتمد الأصناف ويحدد أسعارها ووحداتها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (listViewMode) {
      return Column(
        children: visible.map(_catalogListProduct).toList(),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: showProductImages ? .70 : 1.18,
      ),
      itemBuilder: (_, i) => showProductImages
          ? productCard(visible[i])
          : _compactProductCard(visible[i]),
    );
  }

  Widget _catalogSubcategoryTree(String category, List<Product> items) {
    final subcategories = <String, List<Product>>{};
    for (final product in items) {
      final name = (product.subcategory ?? '').trim().isEmpty
          ? 'أصناف عامة'
          : product.subcategory!.trim();
      subcategories.putIfAbsent(name, () => <Product>[]).add(product);
    }

    return Column(
      children: subcategories.entries.map((subcategoryEntry) {
        final subcategory = subcategoryEntry.key;
        final subKey = '$category::$subcategory';
        final subExpanded = expandedCatalogSubcategories.contains(subKey);
        final brands = <String, List<Product>>{};
        for (final product in subcategoryEntry.value) {
          final brand = (product.brand ?? '').trim().isEmpty
              ? 'بدون ماركة'
              : product.brand!.trim();
          brands.putIfAbsent(brand, () => <Product>[]).add(product);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: purple.withValues(alpha: .10)),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.account_tree_outlined, color: purple, size: 19),
                title: Text(subcategory, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('فئة فرعية • ${subcategoryEntry.value.length} صنف'),
                trailing: Icon(subExpanded ? Icons.expand_less : Icons.expand_more, color: purple),
                onTap: () => setState(() {
                  if (subExpanded) {
                    expandedCatalogSubcategories.remove(subKey);
                  } else {
                    expandedCatalogSubcategories.add(subKey);
                  }
                }),
              ),
              if (subExpanded)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10, end: 10, bottom: 8),
                  child: Column(
                    children: brands.entries.map((brandEntry) {
                      final brandKey = '$subKey::${brandEntry.key}';
                      final brandExpanded = expandedCatalogBrands.contains(brandKey);
                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: const Icon(Icons.sell_outlined, color: orange, size: 18),
                            title: Text(brandEntry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text('${brandEntry.value.length} صنف'),
                            trailing: Icon(brandExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: orange, size: 19),
                            onTap: () => setState(() {
                              if (brandExpanded) {
                                expandedCatalogBrands.remove(brandKey);
                              } else {
                                expandedCatalogBrands.add(brandKey);
                              }
                            }),
                          ),
                          if (brandExpanded)
                            ...brandEntry.value.map(_catalogListProduct),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _catalogListProduct(Product product) {
    final key = product.cartKey;
    final quantity = cart[key] ?? 0;
    final favoriteKey = product.id == null ? product.name : 'product:${product.id}';
    final favorite = favorites.contains(favoriteKey);
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  if (product.brand != null)
                    Text('الماركة: ${product.brand}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(
                    '${product.unit}${product.packageCount > 1 ? ' • ${product.packageCount} ${product.smallUnit ?? 'وحدة'}' : ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  Row(children: [
                    if (product.offerPrice != null && product.offerPrice! < product.price) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(5)),
                        child: const Text('عرض', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 5),
                      Text('${product.price.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 11, color: Colors.black54, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 5),
                      Text('${product.offerPrice!.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, color: orange, fontWeight: FontWeight.bold)),
                    ] else
                      Text('${product.price.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _quantityControl(Icons.remove, () {
                        if (quantity <= 1) {
                          setState(() { cart.remove(key); cartProducts.remove(key); });
                        } else {
                          setState(() => cart[key] = quantity - 1);
                        }
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      _quantityControl(Icons.add, () {
                        if (quantity == 0) {
                          addToCart(product);
                        } else if (quantity < CartService.maxQuantityPerProduct) {
                          setState(() => cart[key] = quantity + 1);
                        }
                      }),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'إضافة للسلة',
                        onPressed: () => addToCart(product),
                        icon: const Icon(Icons.add_shopping_cart, color: orange, size: 21),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'المفضلة',
                        onPressed: () => toggleProductFavorite(product),
                        icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                          color: favorite ? pink : purple, size: 19),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showProductImages)
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsetsDirectional.only(start: 9),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(product.icon, size: 31, color: purple),
                      )
                    : Icon(product.icon, size: 31, color: purple),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quantityControl(IconData icon, VoidCallback onPressed) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        border: Border.all(color: purple.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 16, color: purple),
    ),
  );

  Widget _compactProductCard(Product product) {
    final key = product.id == null ? product.name : 'product:${product.id}';
    final favorite = favorites.contains(key);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: purple, size: 19),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => toggleProductFavorite(product),
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite ? pink : purple,
                    size: 18,
                  ),
                ),
              ],
            ),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${product.price.toStringAsFixed(0)} ج.م',
              style: const TextStyle(color: purple, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: () => addToCart(product),
                child: const Text('أضف للسلة', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget favoritesPage() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('المفضلة', favorites.length),
          const SizedBox(height: 10),
          if (favorites.isEmpty)
            const Padding(
              padding: EdgeInsets.all(35),
              child: Column(
                children: [
                  Icon(Icons.favorite_border, color: purple, size: 54),
                  SizedBox(height: 10),
                  Text('لم تضف منتجات أو موردين إلى المفضلة بعد.'),
                ],
              ),
            ),
          ...favorites.map((key) => ListTile(
                leading: Icon(
                  key.startsWith('supplier:') ? Icons.storefront : Icons.favorite,
                  color: pink,
                ),
                title: Text(favoriteLabel(key)),
                subtitle: Text(key.startsWith('supplier:') ? 'مورد محفوظ' : 'صنف محفوظ'),
              )),
        ],
      );

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
              color: purple.withValues(alpha: .07),
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
          const Text('سوق التجار', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: purple)),
          const SizedBox(height: 8),
          const Text('طلبات شراء وعروض بيع بين التجار.'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () => openMarketPost('buy'),
              icon: const Icon(Icons.shopping_basket_outlined),
              label: const Text('إضافة طلب شراء'),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: orange),
              onPressed: () => openMarketPost('sell'),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('طلب بيع'),
            )),
          ]),
          const SizedBox(height: 12),
          MarketPostsSection(key: marketPostsKey),
        ],
      );

  Future<void> openMarketPost(String type) async {
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text(type == 'buy' ? 'عايز أشتري' : 'عايز أبيع')),
            body: MarketPostScreen(initialType: type, availableProducts: allProducts),
          ),
        ),
      ),
    );
    if (published == true) await marketPostsKey.currentState?.refresh();
  }

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
                  Text(
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
                        widget.testAccountName ?? accountName,
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
            () => openPage('العروض', OffersScreen(activityType: activity, canManage: isApprovedSupplier, availableProducts: allProducts)),
          ),
          menuItem(
            Icons.auto_awesome,
            'قصص الموردين',
            () => openPage('قصص الموردين', StoriesScreen(activityType: activity)),
          ),
          menuItem(
            Icons.forum_outlined,
            'رسائل القصص',
            () => openPage('رسائل القصص', const StoryRepliesScreen()),
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
    final id = rawId?.toString().trim();
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
      id: (id == null || id.isEmpty) ? null : id,
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
  final ImagePicker _productPicker = ImagePicker();
  XFile? selectedProductImage;
  final service = SupplierProductService();
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? error;
  final busyIds = <String>{};

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

  Future<String> _uploadProductImage(XFile file) async {
    final client = database;
    final user = client?.auth.currentUser;
    if (client == null || user == null) throw StateError('سجّل الدخول أولًا لرفع صورة المنتج.');
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage.from('products').uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: FileOptions(
        contentType: 'image/$extension',
        upsert: false,
      ),
    );
    return client.storage.from('products').getPublicUrl(path);
  }

  Future<void> addProduct() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'زيوت');
    final price = TextEditingController();
    final unit = TextEditingController(text: 'كرتونة');
    final minimum = TextEditingController(text: '1');
    final stock = TextEditingController(text: '0');
    final subcategory = TextEditingController();
    final brand = TextEditingController();
    final packageCount = TextEditingController(text: '1');
    final smallUnit = TextEditingController(text: 'علبة');
    final imageUrl = TextEditingController();
    final offerPrice = TextEditingController();
    selectedProductImage = null;
    bool trackStock = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة منتج جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'الفئة الرئيسية')),
              TextField(controller: subcategory, decoration: const InputDecoration(labelText: 'الفئة الفرعية')),
              TextField(controller: brand, decoration: const InputDecoration(labelText: 'الماركة / البراند')),
              TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر الجملة')),
              TextField(controller: unit, decoration: const InputDecoration(labelText: 'وحدة البيع الكبرى (مثال: كرتونة)')),
              TextField(controller: packageCount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد العبوات داخل الوحدة الكبرى')),
              TextField(controller: smallUnit, decoration: const InputDecoration(labelText: 'وحدة البيع الصغرى (مثال: علبة)')),
              TextField(controller: offerPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر العرض (اختياري)')),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await _productPicker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
                      if (file != null) setDialogState(() => selectedProductImage = file);
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('اختيار صورة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await _productPicker.pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 1600);
                      if (file != null) setDialogState(() => selectedProductImage = file);
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('الكاميرا'),
                  ),
                ],
              ),
              if (selectedProductImage != null)
                Text('الصورة المختارة: ${selectedProductImage!.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
              TextField(controller: imageUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'أو رابط صورة المنتج (اختياري)')),
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
        final parsedPackageCount = int.tryParse(packageCount.text.trim()) ?? 1;
        final parsedOfferPrice = offerPrice.text.trim().isEmpty ? null : num.tryParse(offerPrice.text.trim());
        if (parsedPrice == null || parsedMinimum == null ||
            (offerPrice.text.trim().isNotEmpty && parsedOfferPrice == null)) {
          throw ArgumentError('أدخل سعرًا وحدًا أدنى صحيحين.');
        }
        final uploadedImageUrl = selectedProductImage != null
            ? await _uploadProductImage(selectedProductImage!)
            : (imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim());
        await service.createProduct(
          name: name.text,
          category: category.text,
          price: parsedPrice,
          unit: unit.text,
          minQuantity: parsedMinimum,
          stockQuantity: parsedStock,
          trackInventory: trackStock,
          subcategory: subcategory.text,
          brand: brand.text,
          packageCount: parsedPackageCount,
          smallUnit: smallUnit.text,
          imageUrl: uploadedImageUrl,
          offerPrice: parsedOfferPrice,
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
    subcategory.dispose();
    brand.dispose();
    packageCount.dispose();
    smallUnit.dispose();
    imageUrl.dispose();
    offerPrice.dispose();
  }

  Future<void> deactivateProduct(Map<String, dynamic> product) async {
    final rawId = product['id'];
    final id = rawId?.toString().trim();
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
            final id = rawId?.toString().trim();
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
                  onPressed: active && id != null && !busyIds.contains(id) ? () => deactivateProduct(product) : null,
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
    if (id == null || id <= 0) return;
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
  Timer? _storyCountdownTimer;
  final mediaUrlController = TextEditingController();
  final captionController = TextEditingController();
  final storyService = StoryService();
  final picker = ImagePicker();
  String newStoryMediaType = 'image';
  String storyFilter = 'الكل';
  int durationMinutes = 60;
  XFile? selectedMedia;
  List<Map<String, dynamic>> stories = [];
  final Set<String> viewedStoryIds = <String>{};
  bool loading = true;
  String? error;

  Future<void> pickStoryMedia(ImageSource source) async {
    try {
      final file = newStoryMediaType == 'video'
          ? await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 60))
          : await picker.pickImage(source: source, imageQuality: 88, maxWidth: 1600);
      if (file != null && mounted) setState(() => selectedMedia = file);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الكاميرا أو المعرض: $e')),
      );
    }
  }

  Future<String> uploadStoryMedia(XFile file) async {
    final client = database;
    final user = client?.auth.currentUser;
    if (client == null || user == null) throw StateError('سجّل الدخول أولًا لنشر قصة.');
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : (newStoryMediaType == 'video' ? 'mp4' : 'jpg');
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage.from('stories').uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: FileOptions(
        contentType: newStoryMediaType == 'video' ? 'video/$extension' : 'image/$extension',
        upsert: false,
      ),
    );
    return client.storage.from('stories').getPublicUrl(path);
  }

  Future<void> createStory() async {
    if (database?.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولًا لنشر قصة.')));
      return;
    }
    mediaUrlController.clear();
    captionController.clear();
    selectedMedia = null;
    newStoryMediaType = 'image';
    durationMinutes = 60;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة قصة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'image', label: Text('صورة'), icon: Icon(Icons.image_outlined)),
                  ButtonSegment(value: 'video', label: Text('فيديو'), icon: Icon(Icons.video_library_outlined)),
                  ButtonSegment(value: 'text', label: Text('نص'), icon: Icon(Icons.text_fields)),
                ],
                selected: {newStoryMediaType},
                onSelectionChanged: (values) => setDialogState(() {
                  newStoryMediaType = values.first;
                  selectedMedia = null;
                }),
              ),
              if (newStoryMediaType != 'text') ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await pickStoryMedia(ImageSource.gallery);
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('من المعرض'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await pickStoryMedia(ImageSource.camera);
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('الكاميرا'),
                  ),
                ]),
                if (selectedMedia != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('تم اختيار: ${selectedMedia!.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                TextField(
                  controller: mediaUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'أو رابط صورة/فيديو (اختياري)'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: InputDecoration(labelText: newStoryMediaType == 'text' ? 'نص القصة' : 'وصف مختصر (اختياري)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: durationMinutes,
                decoration: const InputDecoration(labelText: 'مدة ظهور القصة'),
                items: [5, 10, 15, 30, 45, 60].map((m) => DropdownMenuItem(value: m, child: Text('$m دقيقة'))).toList(),
                onChanged: (value) => setDialogState(() => durationMinutes = value ?? 60),
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
      String? url;
      if (newStoryMediaType == 'text') {
        if (captionController.text.trim().isEmpty) throw ArgumentError('اكتب نص القصة أولًا.');
      } else if (selectedMedia != null) {
        url = await uploadStoryMedia(selectedMedia!);
      } else if (mediaUrlController.text.trim().isNotEmpty) {
        url = mediaUrlController.text.trim();
      } else {
        throw ArgumentError('اختر ملفًا من المعرض أو الكاميرا أو أدخل رابطًا.');
      }
      await storyService.createStory(
        mediaUrl: url ?? '',
        mediaType: newStoryMediaType,
        caption: captionController.text,
        activityType: widget.activityType,
        duration: Duration(minutes: durationMinutes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر القصة.')));
      await loadStories();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نشر القصة: $e')));
    }
  }

  Future<void> _replyToStory(Map<String, dynamic> story) async {
    final recipientId = (story['user_id'] ?? '').toString();
    final storyId = (story['id'] ?? '').toString();
    if (recipientId.isEmpty || storyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديد صاحب القصة.')));
      return;
    }
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إرسال رسالة لصاحب القصة'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(hintText: 'اكتب ردك أو رسالتك...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.send), label: const Text('إرسال')),
        ],
      ),
    );
    if (send == true) {
      try {
        await storyService.sendReply(storyId: storyId, recipientId: recipientId, body: controller.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة لصاحب القصة.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
      }
    }
    controller.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadStories();
    _storyCountdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> loadStories() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await storyService.getActiveStories(activityType: widget.activityType);
      Set<String> viewed = <String>{};
      try {
        viewed = await storyService.getViewedStoryIds();
      } catch (_) {
        // يمكن عرض القصص حتى لو تعذر تحميل سجل المشاهدات.
      }
      if (!mounted) return;
      setState(() {
        stories = rows;
        viewedStoryIds
          ..clear()
          ..addAll(viewed);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { stories = []; error = 'تعذر تحميل القصص حاليًا.'; });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _storyCountdownTimer?.cancel();
    mediaUrlController.dispose();
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: purple));
    final filtered = stories.where((story) {
      final role = (story['user_role'] ?? story['role'] ?? '').toString().toLowerCase();
      if (storyFilter == 'الموردين') return role == 'supplier' || role == 'مورد';
      if (storyFilter == 'العملاء') return role == 'customer' || role == 'client' || role == 'عميل';
      if (storyFilter == 'شركات الشحن') return role == 'shipping_company' || role == 'شركة شحن';
      return true;
    }).toList()
      ..sort((a, b) {
        final aSeen = viewedStoryIds.contains((a['id'] ?? '').toString());
        final bSeen = viewedStoryIds.contains((b['id'] ?? '').toString());
        if (aSeen != bSeen) return aSeen ? 1 : -1;
        return (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString());
      });
    return RefreshIndicator(
      onRefresh: loadStories,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('القصص', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple))),
            FilledButton.icon(onPressed: createStory, icon: const Icon(Icons.add), label: const Text('إضافة قصة')),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['الكل', 'الموردين', 'العملاء', 'شركات الشحن'].map((filter) =>
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: storyFilter == filter,
                  selectedColor: purple,
                  labelStyle: TextStyle(color: storyFilter == filter ? Colors.white : purple),
                  onSelected: (_) => setState(() => storyFilter = filter),
                ),
              )).toList()),
          ),
          const SizedBox(height: 8),
          const Text('تختفي القصة تلقائيًا عند انتهاء مدتها، بحد أقصى 60 دقيقة.'),
          if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, textAlign: TextAlign.center)),
          if (filtered.isEmpty && error == null)
            const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد قصص نشطة حاليًا.', textAlign: TextAlign.center)),
          ...filtered.map((story) {
            final url = (story['media_url'] ?? '').toString();
            final type = (story['media_type'] ?? 'image').toString();
            final caption = (story['caption'] ?? '').toString();
            final created = DateTime.tryParse((story['created_at'] ?? '').toString());
            final expires = DateTime.tryParse((story['expires_at'] ?? '').toString());
            final remaining = expires == null ? null : expires.difference(DateTime.now());
            final remainingText = remaining == null ? '' : remaining.isNegative ? 'انتهت' : 'متبقي ${remaining.inMinutes} دقيقة';
            return Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ListTile(
                  onTap: () async {
                    final storyId = (story['id'] ?? '').toString();
                    if (storyId.isEmpty) return;
                    try {
                      await storyService.markStoryViewed(storyId);
                      if (mounted) setState(() => viewedStoryIds.add(storyId));
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر تسجيل مشاهدة القصة: $e')),
                        );
                      }
                    }
                  },
                  leading: Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: viewedStoryIds.contains((story['id'] ?? '').toString())
                            ? Colors.grey
                            : orange,
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: orange.withValues(alpha: .18),
                      backgroundImage: (story['avatar_url'] ?? '').toString().trim().isNotEmpty
                          ? NetworkImage((story['avatar_url'] ?? '').toString())
                          : null,
                      child: (story['avatar_url'] ?? '').toString().trim().isEmpty
                          ? const Icon(Icons.person_outline, color: purple)
                          : null,
                    ),
                  ),
                  title: Text((story['display_name'] ?? story['full_name'] ?? 'مستخدم سلسلة').toString()),
                  subtitle: Text(remainingText.isEmpty ? 'قصة نشطة' : remainingText),
                  trailing: Icon(
                    Icons.circle,
                    color: viewedStoryIds.contains((story['id'] ?? '').toString())
                        ? Colors.grey
                        : orange,
                    size: 14,
                  ),
                ),
                if (type == 'text')
                  Padding(padding: const EdgeInsets.all(18), child: Text(caption, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))
                else if (type == 'video' && url.isNotEmpty)
                  StoryVideoPlayer(url: url)
                else if (type == 'video')
                  const SizedBox(height: 170, child: Center(child: Icon(Icons.play_circle_outline, size: 68, color: purple)))
                else if (url.isNotEmpty)
                  Image.network(url, height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 150, child: Center(child: Icon(Icons.broken_image_outlined, size: 44))))
                else
                  const SizedBox(height: 100, child: Center(child: Icon(Icons.image_outlined, size: 42))),
                if (caption.isNotEmpty && type != 'text') Padding(padding: const EdgeInsets.all(12), child: Text(caption)),
                if (created != null) Padding(padding: const EdgeInsetsDirectional.only(start: 12, end: 12, bottom: 10), child: Text('نُشرت: ${created.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 11, color: Colors.black54))),
                if (database?.auth.currentUser?.id != (story['user_id'] ?? '').toString())
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10, bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _replyToStory(story),
                        icon: const Icon(Icons.message_outlined, size: 17),
                        label: const Text('رد / إرسال رسالة'),
                      ),
                    ),
                  ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class StoryRepliesScreen extends StatefulWidget {
  const StoryRepliesScreen({super.key});

  @override
  State<StoryRepliesScreen> createState() => _StoryRepliesScreenState();
}

class _StoryRepliesScreenState extends State<StoryRepliesScreen> {
  final StoryService _service = StoryService();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final messages = await _service.getMyReplies();
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (e) {
      if (!mounted) return;
      setState(() { _messages = []; _error = 'تعذر تحميل الرسائل. تأكد من تسجيل الدخول: $e'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = database?.auth.currentUser?.id;
    if (_loading) return const Center(child: CircularProgressIndicator(color: purple));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('رسائل القصص', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: purple)),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)),
          if (_messages.isEmpty && _error == null)
            const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد رسائل حتى الآن.', textAlign: TextAlign.center)),
          ..._messages.map((message) {
            final incoming = message['recipient_id']?.toString() == userId;
            final created = DateTime.tryParse((message['created_at'] ?? '').toString());
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (incoming ? orange : purple).withValues(alpha: .12),
                  child: Icon(incoming ? Icons.mark_email_unread_outlined : Icons.send_outlined, color: incoming ? orange : purple),
                ),
                title: Text(incoming ? 'رسالة واردة' : 'رسالتك المرسلة', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text((message['body'] ?? '').toString()),
                isThreeLine: true,
                trailing: Text(created == null ? '' : created.toLocal().toString().substring(0, 16), style: const TextStyle(fontSize: 10)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class StoryVideoPlayer extends StatefulWidget {
  const StoryVideoPlayer({super.key, required this.url});
  final String url;

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox(height: 170, child: Center(child: Icon(Icons.video_file_outlined, size: 48, color: purple)));
    }
    if (!_controller.value.isInitialized) {
      return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator(color: purple)));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
            iconSize: 42,
            onPressed: () => setState(() {
              if (_controller.value.isPlaying) {
                _controller.pause();
              } else {
                _controller.play();
              }
            }),
            icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
          ),
        ],
      ),
    );
  }
}

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, required this.activityType, required this.canManage, this.availableProducts = const <Product>[]});
  final String activityType;
  final bool canManage;
  final List<Product> availableProducts;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final service = OfferService();
  final supplierService = SupplierOfferService();
  final Set<String> selectedProductIds = <String>{};
  final Map<String, TextEditingController> offerPrices = <String, TextEditingController>{};
  final Map<String, TextEditingController> minimumQuantities = <String, TextEditingController>{};
  final Map<int, Future<List<Map<String, dynamic>>>> _offerItemsCache = {};

  @override
  void dispose() {
    for (final controller in offerPrices.values) {
      controller.dispose();
    }
    for (final controller in minimumQuantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> createOffer() async {
    selectedProductIds.clear();
    final title = TextEditingController();
    final description = TextEditingController();
    final discount = TextEditingController();
    final imageUrl = TextEditingController();
    final districts = TextEditingController();
    final areas = TextEditingController();
    final selectedGovernorates = <String>{};
    final selectedCustomerTypes = <String>{};
    String magazineColor = '#FFA015';
    int durationDays = 7;
    String selectedMainCategory = 'الكل';
    String selectedSubcategory = 'الكل';
    String selectedBrand = 'الكل';
    List<Product> filterOfferProducts() => widget.availableProducts.where((product) =>
      (selectedMainCategory == 'الكل' || product.category == selectedMainCategory) &&
      (selectedSubcategory == 'الكل' || (product.subcategory ?? 'أصناف عامة') == selectedSubcategory) &&
      (selectedBrand == 'الكل' || (product.brand ?? 'بدون ماركة') == selectedBrand)
    ).toList();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء عرض جديد'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            final visibleOfferProducts = filterOfferProducts();
            final mainCategories = <String>{'الكل', ...widget.availableProducts.map((p) => p.category)}.toList();
            final subcategories = <String>{'الكل', ...widget.availableProducts.where((p) => selectedMainCategory == 'الكل' || p.category == selectedMainCategory).map((p) => p.subcategory ?? 'أصناف عامة')}.toList();
            final brands = <String>{'الكل', ...widget.availableProducts.where((p) => (selectedMainCategory == 'الكل' || p.category == selectedMainCategory) && (selectedSubcategory == 'الكل' || (p.subcategory ?? 'أصناف عامة') == selectedSubcategory)).map((p) => p.brand ?? 'بدون ماركة')}.toList();
            return SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان العرض / المجلة')),
                  TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل العرض')),
                  TextField(controller: discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نسبة الخصم (اختياري)')),
                  DropdownButtonFormField<String>(
                    value: selectedMainCategory,
                    decoration: const InputDecoration(labelText: 'تصفية الفئة الرئيسية'),
                    items: mainCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedMainCategory = v ?? 'الكل';
                      selectedSubcategory = 'الكل';
                      selectedBrand = 'الكل';
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedSubcategory,
                    decoration: const InputDecoration(labelText: 'تصفية الفئة الفرعية'),
                    items: subcategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedSubcategory = v ?? 'الكل';
                      selectedBrand = 'الكل';
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedBrand,
                    decoration: const InputDecoration(labelText: 'تصفية الماركة'),
                    items: brands.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBrand = v ?? 'الكل'),
                  ),
                  TextField(controller: imageUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط صورة العرض (اختياري)')),
                  DropdownButtonFormField<String>(
                    value: magazineColor,
                    decoration: const InputDecoration(labelText: 'لون مجلة العرض'),
                    items: const [
                      DropdownMenuItem(value: '#FFA015', child: Text('برتقالي')),
                      DropdownMenuItem(value: '#3E007D', child: Text('بنفسجي')),
                      DropdownMenuItem(value: '#168A4A', child: Text('أخضر')),
                      DropdownMenuItem(value: '#E53935', child: Text('أحمر')),
                      DropdownMenuItem(value: '#1976D2', child: Text('أزرق')),
                    ],
                    onChanged: (value) => setDialogState(() => magazineColor = value ?? '#FFA015'),
                  ),
                  DropdownButtonFormField<int>(
                    value: durationDays,
                    decoration: const InputDecoration(labelText: 'مدة العرض'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('يوم واحد')),
                      DropdownMenuItem(value: 7, child: Text('أسبوع')),
                      DropdownMenuItem(value: 14, child: Text('أسبوعان')),
                      DropdownMenuItem(value: 30, child: Text('شهر')),
                    ],
                    onChanged: (value) => setDialogState(() => durationDays = value ?? 7),
                  ),
                  TextField(controller: districts, decoration: const InputDecoration(labelText: 'المراكز / الأحياء (افصل بينها بفاصلة)')),
                  TextField(controller: areas, decoration: const InputDecoration(labelText: 'المناطق (افصل بينها بفاصلة)')),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('استهداف المحافظات (${selectedGovernorates.length})'),
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: egyptGovernorates.map((name) => FilterChip(
                          label: Text(name, style: const TextStyle(fontSize: 11)),
                          selected: selectedGovernorates.contains(name),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) { selectedGovernorates.add(name); } else { selectedGovernorates.remove(name); }
                          }),
                        )).toList(),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('أنواع العملاء المستهدفة (${selectedCustomerTypes.length})'),
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: customerTypes.map((name) => FilterChip(
                          label: Text(name, style: const TextStyle(fontSize: 11)),
                          selected: selectedCustomerTypes.contains(name),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) { selectedCustomerTypes.add(name); } else { selectedCustomerTypes.remove(name); }
                          }),
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Expanded(child: Text('الأصناف الداخلة في العرض', style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton(
                      onPressed: () => setDialogState(() {
                        if (selectedProductIds.length == visibleOfferProducts.length) {
                          selectedProductIds.clear();
                        } else {
                          selectedProductIds.addAll(visibleOfferProducts.map((p) => p.cartKey));
                        }
                      }),
                      child: Text(selectedProductIds.length == visibleOfferProducts.length ? 'إلغاء الكل' : 'تحديد الكل'),
                    ),
                  ]),
                  ...visibleOfferProducts.map((p) {
                    offerPrices.putIfAbsent(p.cartKey, () => TextEditingController(text: p.price.toStringAsFixed(2)));
                    minimumQuantities.putIfAbsent(p.cartKey, () => TextEditingController(text: p.minQuantity.toString()));
                    return CheckboxListTile(
                      dense: true,
                      value: selectedProductIds.contains(p.cartKey),
                      secondary: SizedBox(
                        width: 48,
                        height: 48,
                        child: p.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.network(p.imageUrl!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(p.icon, color: purple)),
                              )
                            : Icon(p.icon, color: purple),
                      ),
                      title: Text(p.name),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('السعر الحالي: ${p.price.toStringAsFixed(2)} ج.م'),
                        const SizedBox(height: 5),
                        Row(children: [
                          Expanded(child: TextField(controller: offerPrices[p.cartKey], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, labelText: 'سعر العرض'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: minimumQuantities[p.cartKey], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, labelText: 'أقل كمية'))),
                        ]),
                      ]),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) { selectedProductIds.add(p.cartKey); } else { selectedProductIds.remove(p.cartKey); }
                      }),
                    );
                  }),
                  if (visibleOfferProducts.isEmpty) const Text('لا توجد أصناف محملة لهذا النشاط.'),
                ],
              ),
            ),
          );
          },
        ),
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
        if (selectedProductIds.isEmpty) {
          await supplierService.createOffer(
            title: title.text,
            description: description.text,
            startsAt: now,
            endsAt: now.add(Duration(days: durationDays)),
            imageUrl: imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
            activityType: widget.activityType,
            discountPercentage: discountValue,
            magazineColor: magazineColor,
            targetGovernorates: selectedGovernorates.toList(),
            targetDistricts: districts.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
            targetAreas: areas.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
            targetCustomerTypes: selectedCustomerTypes.toList(),
          );
        } else {
          final selectedItems = <Map<String, dynamic>>[];
          for (final p in widget.availableProducts.where((p) => selectedProductIds.contains(p.cartKey))) {
            final price = double.tryParse(offerPrices[p.cartKey]?.text.trim() ?? '');
            if (price == null || !price.isFinite || price < 0) {
              throw ArgumentError('سعر العرض غير صحيح للصنف ${p.name}');
            }
            final minimumQuantity = double.tryParse(minimumQuantities[p.cartKey]?.text.trim() ?? '');
            if (minimumQuantity == null || !minimumQuantity.isFinite || minimumQuantity <= 0) {
              throw ArgumentError('أقل كمية غير صحيحة للصنف ${p.name}');
            }
            selectedItems.add({
              'product_id': p.id,
              'product_name': p.name,
              'original_price': p.price,
              'offer_price': price,
              'min_quantity': minimumQuantity,
            });
          }
          await supplierService.createOfferWithItems(
            title: title.text.trim().isEmpty ? 'مجلة عروض سلسلة' : title.text.trim(),
            items: selectedItems,
            description: description.text,
            startsAt: now,
            endsAt: now.add(Duration(days: durationDays)),
            imageUrl: imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
            activityType: widget.activityType,
            discountPercentage: discountValue,
            magazineColor: magazineColor,
            targetGovernorates: selectedGovernorates.toList(),
            targetDistricts: districts.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
            targetAreas: areas.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
            targetCustomerTypes: selectedCustomerTypes.toList(),
          );
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ العرض. عدد الأصناف: ${selectedProductIds.length}')));
        await loadOffers();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نشر العرض: $e')));
      }
    }
    title.dispose();
    description.dispose();
    discount.dispose();
    imageUrl.dispose();
    districts.dispose();
    areas.dispose();
  }
  String _csvCell(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';

  Future<List<Map<String, dynamic>>> _offerItems(Map<String, dynamic> offer) async {
    final id = offer['id'];
    if (id is! num || database == null) return <Map<String, dynamic>>[];
    final rows = await database!.from('offer_items').select().eq('offer_id', id.toInt());
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _exportOfferCsv(Map<String, dynamic> offer) async {
    try {
      final items = await _offerItems(offer);
      final rows = <List<Object?>>[
        ['عنوان العرض', 'الوصف', 'بداية العرض', 'نهاية العرض', 'الخصم', 'الصنف', 'السعر الأصلي', 'سعر العرض'],
      ];
      if (items.isEmpty) {
        rows.add([offer['title'], offer['description'], offer['start_at'], offer['ends_at'], offer['discount_percentage'], '', '', '']);
      } else {
        for (final item in items) {
          rows.add([offer['title'], offer['description'], offer['start_at'], offer['ends_at'], offer['discount_percentage'], item['product_name'], item['original_price'], item['offer_price']]);
        }
      }
      final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير بيانات العرض إلى Excel',
        fileName: 'silsila_offer_${offer['id']}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (mounted && saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز ملف CSV المتوافق مع Excel.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تصدير Excel: $e')));
    }
  }

  Future<void> _exportOfferPdf(Map<String, dynamic> offer) async {
    try {
      final items = await _offerItems(offer);
      final fontData = await rootBundle.load('assets/fonts/Tajawal.ttf');
      final font = pw.Font.ttf(fontData);
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('سلسلة Silsila - مجلة عروض', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('عنوان العرض: ${offer['title'] ?? ''}'),
                pw.Text('التفاصيل: ${offer['description'] ?? ''}'),
                pw.Text('بداية العرض: ${offer['start_at'] ?? ''}'),
                pw.Text('نهاية العرض: ${offer['ends_at'] ?? ''}'),
                pw.Text('الخصم: ${offer['discount_percentage'] ?? 0}%'),
                pw.SizedBox(height: 14),
                if (items.isNotEmpty)
                  pw.TableHelper.fromTextArray(
                    headers: ['الصنف', 'السعر الأصلي', 'سعر العرض', 'الخصم %'],
                    data: items.map((item) => [
                      item['product_name'] ?? '',
                      item['original_price'] ?? '',
                      item['offer_price'] ?? '',
                      item['discount_percentage'] ?? '',
                    ]).toList(),
                    headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                    cellStyle: pw.TextStyle(font: font),
                  ),
              ],
            ),
          ),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء PDF: $e')));
    }
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    final id = offer['id'];
    if (id is! num) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العرض'),
        content: Text('هل تريد حذف العرض «${offer['title'] ?? ''}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supplierService.deleteOffer(id.toInt());
      await loadOffers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العرض.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف العرض: $e')));
    }
  }

  Future<void> _editOffer(Map<String, dynamic> offer) async {
    final rawId = offer['id'];
    if (rawId is! num) return;
    final title = TextEditingController(text: (offer['title'] ?? '').toString());
    final description = TextEditingController(text: (offer['description'] ?? '').toString());
    final discount = TextEditingController(text: (offer['discount_percentage'] ?? offer['discount_percent'] ?? '').toString());
    final imageUrl = TextEditingController(text: (offer['image_url'] ?? '').toString());
    String listText(Object? value) => value is List ? value.map((e) => e.toString()).join(', ') : (value ?? '').toString();
    final governorates = TextEditingController(text: listText(offer['target_governorates']));
    final districts = TextEditingController(text: listText(offer['target_districts']));
    final areas = TextEditingController(text: listText(offer['target_areas']));
    final customerTypesController = TextEditingController(text: listText(offer['target_customer_types']));
    DateTime startsAt = DateTime.tryParse((offer['start_at'] ?? '').toString())?.toLocal() ?? DateTime.now();
    DateTime endsAt = DateTime.tryParse((offer['ends_at'] ?? offer['end_at'] ?? '').toString())?.toLocal() ?? DateTime.now().add(const Duration(days: 7));
    String magazineColor = (offer['magazine_color'] ?? '#FFA015').toString();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل العرض'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان العرض')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل')),
                TextField(controller: discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نسبة الخصم')),
                TextField(controller: imageUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط صورة العرض')),
                DropdownButtonFormField<String>(
                  value: magazineColor,
                  decoration: const InputDecoration(labelText: 'لون مجلة العرض'),
                  items: const [
                    DropdownMenuItem(value: '#FFA015', child: Text('برتقالي')),
                    DropdownMenuItem(value: '#3E007D', child: Text('بنفسجي')),
                    DropdownMenuItem(value: '#168A4A', child: Text('أخضر')),
                    DropdownMenuItem(value: '#E53935', child: Text('أحمر')),
                    DropdownMenuItem(value: '#1976D2', child: Text('أزرق')),
                  ],
                  onChanged: (value) => setDialogState(() => magazineColor = value ?? '#FFA015'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('بداية العرض'),
                  subtitle: Text('${startsAt.year}/${startsAt.month.toString().padLeft(2, '0')}/${startsAt.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_month, color: purple),
                  onTap: () async {
                    final value = await showDatePicker(context: context, initialDate: startsAt, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (value != null) setDialogState(() => startsAt = DateTime(value.year, value.month, value.day, startsAt.hour, startsAt.minute));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نهاية العرض'),
                  subtitle: Text('${endsAt.year}/${endsAt.month.toString().padLeft(2, '0')}/${endsAt.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.event_available, color: orange),
                  onTap: () async {
                    final value = await showDatePicker(context: context, initialDate: endsAt, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (value != null) setDialogState(() => endsAt = DateTime(value.year, value.month, value.day, 23, 59));
                  },
                ),
                TextField(controller: governorates, decoration: const InputDecoration(labelText: 'المحافظات المستهدفة (افصل بينها بفاصلة)')),
                TextField(controller: districts, decoration: const InputDecoration(labelText: 'المراكز / الأحياء المستهدفة')),
                TextField(controller: areas, decoration: const InputDecoration(labelText: 'المناطق المستهدفة')),
                TextField(controller: customerTypesController, decoration: const InputDecoration(labelText: 'أنواع العملاء المستهدفة')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ التعديلات')),
          ],
        ),
      ),
    );
    if (accepted != true) {
      title.dispose(); description.dispose(); discount.dispose(); imageUrl.dispose();
      governorates.dispose(); districts.dispose(); areas.dispose(); customerTypesController.dispose();
      return;
    }
    try {
      final discountValue = discount.text.trim().isEmpty ? null : double.tryParse(discount.text.trim());
      if (discount.text.trim().isNotEmpty && discountValue == null) throw ArgumentError('نسبة الخصم غير صحيحة.');
      List<String> parseList(String value) => value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();
      await supplierService.updateOffer(
        offerId: rawId.toInt().toString(),
        title: title.text,
        description: description.text,
        imageUrl: imageUrl.text.trim(),
        startsAt: startsAt,
        endsAt: endsAt,
        discountPercentage: discountValue,
        magazineColor: magazineColor,
        targetGovernorates: parseList(governorates.text),
        targetDistricts: parseList(districts.text),
        targetAreas: parseList(areas.text),
        targetCustomerTypes: parseList(customerTypesController.text),
      );
      await loadOffers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تعديلات العرض.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تعديل العرض: $e')));
    } finally {
      title.dispose(); description.dispose(); discount.dispose(); imageUrl.dispose();
      governorates.dispose(); districts.dispose(); areas.dispose(); customerTypesController.dispose();
    }
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
    setState(() { loading = true; error = null; _offerItemsCache.clear(); });
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
            final magazineHex = (offer['magazine_color'] ?? '#FFA015').toString().replaceFirst('#', '');
            final magazineValue = int.tryParse(magazineHex, radix: 16) ?? 0xFFFFA015;
            return Card(
              color: Color(magazineValue | 0xFF000000).withValues(alpha: .09),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Color(magazineValue | 0xFF000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (offer['image_url'] ?? '').toString().trim().isNotEmpty
                          ? Image.network(
                              (offer['image_url'] ?? '').toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                            )
                          : const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مجلة العروض', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    )),
                    if (discount is num && discount > 0)
                      Chip(label: Text('خصم ${discount.toStringAsFixed(0)}%')),
                  ]),
                  if (description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(description)),
                  if (offer['id'] is num)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _offerItemsCache.putIfAbsent(
                        (offer['id'] as num).toInt(),
                        () => service.getOfferItems((offer['id'] as num).toInt()),
                      ),
                      builder: (context, snapshot) {
                        final items = snapshot.data ?? const <Map<String, dynamic>>[];
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('أصناف العرض', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...items.map((item) {
                                final oldPrice = item['original_price'];
                                final newPrice = item['offer_price'];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.inventory_2_outlined, color: purple),
                                  title: Text((item['product_name'] ?? '').toString()),
                                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      if (oldPrice != null)
                                        Text('${oldPrice} ج.م', style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.black54)),
                                      const SizedBox(width: 8),
                                      if (newPrice != null)
                                        Text('${newPrice} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: orange)),
                                    ]),
                                    if (item['min_quantity'] != null)
                                      Text('أقل كمية: ${item['min_quantity']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  ]),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  if (ends != null && ends.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('ينتهي: ${ends.split('T').first}', style: const TextStyle(color: Colors.black54, fontSize: 12))),
                  if (widget.canManage) ...[
                    const Divider(height: 18),
                    Wrap(spacing: 7, children: [
                      OutlinedButton.icon(onPressed: () => _editOffer(offer), icon: const Icon(Icons.edit_outlined, size: 17), label: const Text('تعديل')),
                      OutlinedButton.icon(onPressed: () => _deleteOffer(offer), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), icon: const Icon(Icons.delete_outline, size: 17), label: const Text('حذف')),
                      OutlinedButton.icon(onPressed: () => _exportOfferCsv(offer), icon: const Icon(Icons.table_view_outlined, size: 17), label: const Text('Excel')),
                      OutlinedButton.icon(onPressed: () => _exportOfferPdf(offer), icon: const Icon(Icons.picture_as_pdf_outlined, size: 17), label: const Text('PDF')),
                    ]),
                  ],
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
    this.initialActivity = 'مواد غذائية',
  });

  final String initialAccountType;
  final String initialActivity;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final whatsappController = TextEditingController();
  final addressController = TextEditingController();
  final landmarkController = TextEditingController();
  final districtController = TextEditingController();
  final areaController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String activity = 'مواد غذائية';
  late String accountType;

  @override
  void initState() {
    super.initState();
    const accountTypes = {'عميل', 'مورد', 'مندوب', 'شركة شحن', 'إدارة نشاط'};
    accountType = accountTypes.contains(widget.initialAccountType)
        ? widget.initialAccountType
        : 'عميل';
    activity = activityTypes.contains(widget.initialActivity)
        ? widget.initialActivity
        : activityTypes.first;
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
    emailController.dispose();
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

    final normalizedPhone = normalizePhoneForAuth(phoneController.text);
    setState(() => busy = true);
    try {
      final response = await client.auth.signUp(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text,
        data: {
          'full_name': nameController.text.trim(),
          'contact_phone': normalizedPhone,
          'account_type': accountType,
          'activity_type': activity,
          'customer_type': customerType,
          'supplier_type': supplierType,
          'delegate_type': delegateType,
          'whatsapp_phone': sameWhatsApp
              ? normalizedPhone
              : normalizePhoneForAuth(whatsappController.text),
          'governorate': governorate,
          'district': districtController.text.trim(),
          'area': areaController.text.trim(),
          'address': addressController.text.trim(),
          'landmark': landmarkController.text.trim(),
        },
      );

      if (mounted && response.user != null && response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب. راجع بريدك الإلكتروني لتأكيد الحساب قبل تسجيل الدخول.'),
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
              'لم يكتمل إنشاء الحساب. راجع البريد الإلكتروني وكلمة المرور.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر التسجيل. تحقق من البريد الإلكتروني وكلمة المرور وإعدادات البريد في Supabase.',
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
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  return value.contains('@') && value.contains('.')
                      ? null
                      : 'أدخل بريدًا إلكترونيًا صحيحًا';
                },
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
                  prefixIcon: Icon(Icons.phone_rounded),
                  helperText: 'أدخل رقم الهاتف بالأرقام المصرية أو الدولية',
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  final digits = value.replaceAll(RegExp(r'\D'), '');

                  if (value.isEmpty) {
                    return 'أدخل رقم الهاتف';
                  }

                  if (RegExp(r'[A-Za-z]').hasMatch(value)) {
                    return 'رقم الهاتف لا يجب أن يحتوي على حروف';
                  }

                  if (digits.length < 10 || digits.length > 15) {
                    return 'أدخل رقم هاتف صحيحًا من 10 إلى 15 رقمًا';
                  }

                  return null;
                },
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
                    helperText: 'أدخل رقم واتساب بالأرقام المصرية أو الدولية',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    final digits = value.replaceAll(RegExp(r'\D'), '');

                    if (value.isEmpty) {
                      return 'أدخل رقم واتساب';
                    }

                    if (RegExp(r'[A-Za-z]').hasMatch(value)) {
                      return 'رقم واتساب لا يجب أن يحتوي على حروف';
                    }

                    if (digits.length < 10 || digits.length > 15) {
                      return 'أدخل رقم واتساب صحيحًا من 10 إلى 15 رقمًا';
                    }

                    return null;
                  },
                ),
              ],

             
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: governorate,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'المحافظة',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: egyptGovernorates
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
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
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  helperText:
                      '8 أحرف على الأقل مع حرف كبير وصغير ورقم ورمز',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
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
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    tooltip: obscureConfirmPassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                    onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    icon: Icon(obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
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
          'التسجيل يعتمد على البريد الإلكتروني وسياسات قاعدة البيانات؛ رقم الهاتف يُحفظ لبيانات التواصل فقط.',
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


/// توحيد رقم الهاتف إلى صيغة E.164 المطلوبة لمصادقة الهاتف.
/// يدعم أرقام مصر المحلية مثل 010... و02...، والأرقام الدولية.
String normalizeArabicDigits(String input) {
  return input.replaceAllMapped(
    RegExp(r'[٠-٩۰-۹]'),
    (match) {
      final code = match.group(0)!.codeUnitAt(0);
      final digit = code >= 0x0660 && code <= 0x0669
          ? code - 0x0660
          : code - 0x06F0;
      return String.fromCharCode(0x30 + digit);
    },
  );
}

String normalizePhoneForAuth(String input) {
  final asciiInput = normalizeArabicDigits(input.trim());
  final compact = asciiInput.replaceAll(RegExp(r'[\s().-]'), '');
  final digits = compact.replaceAll(RegExp(r'\D'), '');

  if (compact.startsWith('+')) return '+' + digits;
  if (digits.startsWith('00')) return '+' + digits.substring(2);
  if (digits.startsWith('20')) return '+' + digits;
  if (digits.startsWith('0') && (digits.length == 10 || digits.length == 11)) {
    return '+20' + digits.substring(1);
  }
  return '+' + digits;
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


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool busy = false;
  bool obscurePassword = true;
  bool rememberEmail = false;
  String activity = activityTypes.first;
  String accountType = 'عميل';
  String activityUserType = 'مستخدم رئيسي للنشاط';

  static const _emailKey = 'silsila_login_email';
  static const _legacyPasswordKey = 'silsila_login_password';
  static const _rememberKey = 'silsila_login_remember';

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      // Remove passwords stored by older versions; only the email may be remembered.
      await _secureStorage.delete(key: _legacyPasswordKey);
      final remembered = await _secureStorage.read(key: _rememberKey) == 'true';
      if (!remembered) return;
      final savedEmail = await _secureStorage.read(key: _emailKey);
      if (!mounted) return;
      setState(() {
        rememberEmail = true;
        email.text = savedEmail ?? '';
      });
    } catch (_) {
      // A device without secure-storage support can still log in normally.
    }
  }

  Future<void> _saveOrClearCredentials() async {
    try {
      await _secureStorage.delete(key: _legacyPasswordKey);
      if (rememberEmail) {
        await _secureStorage.write(key: _emailKey, value: email.text.trim().toLowerCase());
        await _secureStorage.write(key: _rememberKey, value: 'true');
      } else {
        await _secureStorage.delete(key: _emailKey);
        await _secureStorage.delete(key: _rememberKey);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ إعداد تذكّر البريد على هذا الجهاز.')),
      );
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final enteredEmail = email.text.trim().toLowerCase();
    if (enteredEmail.isEmpty || !enteredEmail.contains('@') || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب البريد الإلكتروني الصحيح وكلمة المرور.')),
      );
      return;
    }
    final client = database;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاتصال بالخدمة غير متاح حاليًا. حاول مرة أخرى لاحقًا.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await client.auth.signInWithPassword(
        email: enteredEmail,
        password: password.text,
      );
      await _saveOrClearCredentials();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل الدخول: ${error.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تسجيل الدخول. راجع البريد الإلكتروني وكلمة المرور.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final value = email.text.trim().toLowerCase();
    if (value.isEmpty || !value.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب البريد الإلكتروني أولًا لاستعادة كلمة المرور.')),
      );
      return;
    }
    final client = database;
    if (client == null) return;
    try {
      await client.auth.resetPasswordForEmail(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('إذا كان البريد مسجلًا، فستصلك رسالة لاستعادة كلمة المرور.')),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر إرسال رسالة الاستعادة: ${error.message}')),
        );
      }
    }
  }

  void _openPage(Widget page, String title) {
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

  Widget _accountTypeButton({
    required String label,
    required IconData icon,
  }) {
    final selected = accountType == label;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? purple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => accountType = label),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? purple : const Color(0xFFE5DDED)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: orange, size: 17),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

  @override
  Widget build(BuildContext context) {
    const testLoginEnabled = bool.fromEnvironment(
      'SILSILA_TEST_LOGIN',
      defaultValue: false,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل الدخول'), centerTitle: true),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Center(
                    child: SizedBox(
                      height: 100,
                      width: 250,
                      child: Image.asset(
                        'assets/images/silsila_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hub_rounded, color: purple, size: 44),
                            SizedBox(width: 10),
                            Text(
                              'سلسلة Silsila',
                              style: TextStyle(
                                color: purple,
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: activity,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع النشاط',
                      prefixIcon: Icon(Icons.business_center_outlined),
                    ),
                    items: activityTypes
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => activity = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'اختار طريقة دخولك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: purple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _accountTypeButton(label: 'مورد', icon: Icons.inventory_2_outlined),
                      _accountTypeButton(label: 'عميل', icon: Icons.storefront_outlined),
                      _accountTypeButton(label: 'مندوب', icon: Icons.badge_outlined),
                      _accountTypeButton(label: 'شركة شحن', icon: Icons.local_shipping_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5DDED)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تسجيل دخول (نشاط حالي)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: purple,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'مستخدم رئيسي للنشاط',
                              label: Text('مستخدم رئيسي'),
                              icon: Icon(Icons.admin_panel_settings_outlined),
                            ),
                            ButtonSegment<String>(
                              value: 'مستخدم فرعي للنشاط',
                              label: Text('مستخدم فرعي'),
                              icon: Icon(Icons.person_outline),
                            ),
                          ],
                          selected: {activityUserType},
                          showSelectedIcon: false,
                          onSelectionChanged: (values) {
                            setState(() => activityUserType = values.first);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني المسجل',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => busy ? null : login(),
                          decoration: InputDecoration(
                            labelText: 'اكتب كلمة المرور الخاصة بك',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: obscurePassword
                                  ? 'إظهار كلمة المرور'
                                  : 'إخفاء كلمة المرور',
                              onPressed: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: rememberEmail,
                          activeColor: purple,
                          title: const Text(
                            'تذكر البريد الإلكتروني',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'يتم حفظ البريد فقط؛ لا يتم تخزين كلمة المرور على الجهاز.',
                            style: TextStyle(fontSize: 12),
                          ),
                          onChanged: (value) => setState(
                            () => rememberEmail = value ?? false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: busy ? null : login,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            testLoginEnabled
                                ? 'دخول تجريبي'
                                : (busy ? 'جارٍ الدخول...' : 'دخول'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _sendPasswordReset,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openPage(
                      RegisterScreen(initialAccountType: accountType, initialActivity: activity),
                      'إنشاء مستخدم جديد',
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إنشاء مستخدم جديد'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _openPage(
                      RegisterScreen(initialAccountType: 'إدارة نشاط', initialActivity: activity),
                      'إنشاء نشاط جديد',
                    ),
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('إنشاء نشاط جديد'),
                    style: FilledButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: purple,
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
                ],
              ),
            ),
          ),
        ),
      ),
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
    final nextFuture = TraderMarketService().getPosts();
    setState(() => postsFuture = nextFuture);
    try {
      await nextFuture;
    } catch (_) {
      // يعرض FutureBuilder رسالة الخطأ وزر إعادة المحاولة.
    }
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
            final color = isBuy ? Colors.green.shade700 : orange;
            final title = (post['title'] ?? 'إعلان').toString();
            final details = (post['description'] ?? post['details'] ?? '').toString();
            final quantity = post['quantity'];
            final targetPrice = post['target_price'];
            final category = (post['category'] ?? '').toString();
            final governorate = (post['governorate'] ?? '').toString();
            final contactPhone = (post['contact_phone'] ?? '').toString();
            final subtitle = [
              isBuy ? 'طلب شراء' : 'عرض بيع',
              if (category.isNotEmpty) 'القسم: $category',
              if (quantity != null) 'الكمية: $quantity ${post['unit'] ?? ''}',
              if (targetPrice != null) 'السعر: $targetPrice جنيه',
              if (governorate.isNotEmpty) governorate,
              if (contactPhone.isNotEmpty) 'للتواصل: $contactPhone',
              details,
            ].where((part) => part.toString().trim().isNotEmpty).join('\n');
            return MarketCard(
              postId: (post['id'] ?? '').toString(),
              postOwnerId: (post['user_id'] ?? '').toString(),
              expiryDate: (post['expiry_date'] ?? '').toString(),
              isNegotiable: post['is_negotiable'] == true,
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
  const MarketPostScreen({
    super.key,
    this.initialType = 'buy',
    this.availableProducts = const <Product>[],
  });

  final String initialType;
  final List<Product> availableProducts;

  @override
  State<MarketPostScreen> createState() => _MarketPostScreenState();
}

class _MarketPostScreenState extends State<MarketPostScreen> {
  final Set<String> selectedProducts = <String>{};
  bool selectAllProducts = false;

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
  }
  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final priceController = TextEditingController();
  final governorateController = TextEditingController();
  final categoryController = TextEditingController();
  final contactPhoneController = TextEditingController();
  DateTime? expiryDate;
  bool isNegotiable = false;
  late String type;
  bool busy = false;

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    quantityController.dispose();
    unitController.dispose();
    priceController.dispose();
    governorateController.dispose();
    categoryController.dispose();
    contactPhoneController.dispose();
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

    final quantityText = quantityController.text.trim();
    final priceText = priceController.text.trim();
    final contactText = contactPhoneController.text.trim();
    final normalizedContact = contactText.isEmpty ? null : normalizePhoneForAuth(contactText);
    final quantity = quantityText.isEmpty ? null : double.tryParse(quantityText);
    final targetPrice = priceText.isEmpty ? null : double.tryParse(priceText);
    if (contactText.isNotEmpty &&
        !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalizedContact ?? '')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم تواصل صحيحًا أو اترك الحقل فارغًا.')),
      );
      return;
    }
    if ((quantityText.isNotEmpty && (quantity == null || !quantity.isFinite || quantity <= 0)) ||
        (priceText.isNotEmpty && (targetPrice == null || !targetPrice.isFinite || targetPrice < 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('راجع الكمية والسعر؛ يجب إدخال أرقام صحيحة.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await TraderMarketService().createPost(
        title: titleController.text.trim(),
        description: [
          detailsController.text.trim(),
          if (selectedProducts.isNotEmpty)
            'الأصناف: ${widget.availableProducts.where((p) => selectedProducts.contains(p.name)).map((p) => p.name).join('، ')}',
        ].join('\n'),
        postType: type,
        activityType: 'مواد غذائية',
        quantity: quantity,
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        targetPrice: targetPrice,
        governorate: governorateController.text.trim().isEmpty ? null : governorateController.text.trim(),
        category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
        contactPhone: contactPhoneController.text.trim().isEmpty ? null : normalizePhoneForAuth(contactPhoneController.text),
        expiryDate: expiryDate,
        isNegotiable: isNegotiable,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            decoration: BoxDecoration(color: type == 'buy' ? Colors.green.shade700 : purple, borderRadius: BorderRadius.circular(14)),
            child: Text(type == 'buy' ? 'عايز أشتري' : 'عايز أبيع',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'الملاحظات أو التفاصيل'),
          ),
          if (widget.availableProducts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('اختيار الأصناف', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: () => setState(() {
                  selectAllProducts = !selectAllProducts;
                  selectedProducts
                    ..clear()
                    ..addAll(selectAllProducts ? widget.availableProducts.map((p) => p.name) : const <String>[]);
                }),
                child: Text(selectAllProducts ? 'إلغاء تحديد الكل' : 'تحديد الكل'),
              ),
            ]),
            ...widget.availableProducts.map((product) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selectedProducts.contains(product.name),
              title: Text(product.name),
              subtitle: Text('${product.category} • ${product.price.toStringAsFixed(2)} ج.م / ${product.unit}'),
              secondary: Icon(product.icon, color: purple),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  selectedProducts.add(product.name);
                } else {
                  selectedProducts.remove(product.name);
                }
                selectAllProducts = selectedProducts.length == widget.availableProducts.length;
              }),
            )),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'عنوان العرض أو الطلب'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'الكمية (اختياري)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: unitController,
            decoration: const InputDecoration(labelText: 'وحدة القياس (كرتونة، كيلو...)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: type == 'buy' ? 'السعر المستهدف بالجنيه (اختياري)' : 'سعر العرض بالجنيه (اختياري)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: categoryController,
            decoration: const InputDecoration(labelText: 'القسم أو الصنف (اختياري)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: governorateController,
            decoration: const InputDecoration(labelText: 'المحافظة (اختياري)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم للتواصل (اختياري)', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: isNegotiable, onChanged: (value) => setState(() => isNegotiable = value), title: const Text('السعر قابل للتفاوض البسيط'), subtitle: const Text('يمكن للطرف الآخر إرسال سعر مقترح للموافقة أو الرفض أو التعديل.')),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_busy_outlined, color: purple), title: const Text('تاريخ صلاحية الطلب'), subtitle: Text(expiryDate == null ? 'غير محدد' : '${expiryDate!.year}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.day.toString().padLeft(2, '0')}'), trailing: IconButton(tooltip: 'اختيار التاريخ', icon: const Icon(Icons.calendar_month), onPressed: () async { final now = DateTime.now(); final value = await showDatePicker(context: context, initialDate: expiryDate ?? now.add(const Duration(days: 7)), firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(2100)); if (value != null) setState(() => expiryDate = value); })),
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
    final nextRequest = NotificationService().getMyNotifications();
    setState(() => notificationsFuture = nextRequest);

    // يظل الخطأ ظاهرًا في FutureBuilder دون استثناء غير معالج
    // عند السحب للتحديث أو الضغط على إعادة المحاولة.
    try {
      await nextRequest;
    } catch (_) {
      // يعرض FutureBuilder حالة الخطأ ورسالة إعادة المحاولة.
    }
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
        if (egyptGovernorates.contains(savedGovernorate)) {
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
        whatsappPhone: whatsappController.text.trim().isEmpty
            ? null
            : normalizePhoneForAuth(whatsappController.text),
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
            validator: (value) {
              final input = value?.trim() ?? '';
              if (input.isEmpty) return null;
              final normalized = normalizePhoneForAuth(input);
              if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
                return 'أدخل رقم واتساب صحيحًا';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: governorate,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المحافظة'),
            
                items: egyptGovernorates
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
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
    final title = (item['title'] ?? 'هذا العنوان').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل ترغب في حذف العنوان "$title"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لا'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
                    LinearProgressIndicator(value: progress / 100, color: orange, backgroundColor: purple.withValues(alpha: .1)),
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
                    backgroundColor: statusColor(status).withValues(alpha: .12),
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

class MarketCard extends StatefulWidget {
  const MarketCard({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.expiryDate,
    required this.isNegotiable,
    required this.title,
    required this.type,
    required this.details,
    required this.color,
  });

  final String postId;
  final String postOwnerId;
  final String expiryDate;
  final bool isNegotiable;
  final String title;
  final String type;
  final String details;
  final Color color;

  @override
  State<MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends State<MarketCard> {
  final TraderMarketService _service = TraderMarketService();
  final TextEditingController _negotiationPrice = TextEditingController();
  Map<String, int> _counts = const {'view': 0, 'accept': 0, 'reject': 0};
  bool _busy = false;
  bool _closed = false;
  bool _detailsExpanded = false;
  bool _hasAccepted = false;
  String? _negotiationStatus;
  late Future<List<Map<String, dynamic>>> _negotiationsFuture;

  @override
  void initState() {
    super.initState();
    _negotiationsFuture = _service.getNegotiations(widget.postId);
    _service.hasInteraction(widget.postId, 'accept').then((value) {
      if (mounted) setState(() => _hasAccepted = value);
    }).catchError((_) {});
    _service.getInteractionCounts(widget.postId).then((value) {
      if (mounted) setState(() => _counts = value);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _negotiationPrice.dispose();
    super.dispose();
  }

  Future<void> _interact(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.recordInteraction(
        postId: widget.postId,
        interactionType: action,
      );
      final counts = await _service.getInteractionCounts(widget.postId);
      if (mounted) setState(() {
        _counts = counts;
        if (action == 'accept') _hasAccepted = true;
      });
      if (mounted && action != 'view') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'accept'
              ? 'تم تسجيل قبولك للمنشور.'
              : 'تم تسجيل رفضك للمنشور.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل التفاعل. تأكد من تسجيل الدخول: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showNegotiationDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اقتراح سعر تفاوض'),
        content: TextField(
          controller: _negotiationPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'السعر المقترح بالجنيه',
            prefixIcon: Icon(Icons.currency_exchange),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إرسال الاقتراح')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final price = double.tryParse(_negotiationPrice.text.trim());
    if (price == null || !price.isFinite || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل سعر تفاوض صحيحًا أكبر من صفر.')),
      );
      return;
    }
    try { await _service.proposeNegotiation(postId: widget.postId, proposedPrice: price); if (!mounted) return; setState(() { _negotiationStatus = 'تم إرسال اقتراح السعر: ${price.toStringAsFixed(2)} ج.م'; _negotiationsFuture = _service.getNegotiations(widget.postId); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال اقتراح السعر لصاحب الطلب.'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التفاوض: $e'))); }
  }

  Future<void> _respondNegotiation(Map<String, dynamic> row, String action) async {
    try {
      await _service.respondToNegotiation(
        negotiationId: (row['id'] ?? '').toString(),
        action: action,
      );
      if (!mounted) return;
      setState(() => _negotiationsFuture = _service.getNegotiations(widget.postId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accept' ? 'تم قبول سعر التفاوض.' : 'تم رفض سعر التفاوض.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث التفاوض: $e')),
      );
    }
  }

  Future<void> _counterNegotiation(Map<String, dynamic> row) async {
    final controller = TextEditingController(text: (row['proposed_price'] ?? '').toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل سعر التفاوض'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'السعر الجديد بالجنيه'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إرسال السعر المعدل')),
        ],
      ),
    );
    final price = double.tryParse(controller.text.trim());
    controller.dispose();
    if (confirmed != true || price == null || !price.isFinite || price <= 0) {
      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل سعرًا صحيحًا أكبر من صفر.')));
      }
      return;
    }
    try {
      await _service.respondToNegotiation(
        negotiationId: (row['id'] ?? '').toString(),
        action: 'counter',
        counterPrice: price,
      );
      if (!mounted) return;
      setState(() => _negotiationsFuture = _service.getNegotiations(widget.postId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال السعر المعدل للطرف الآخر.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تعديل التفاوض: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();
    final detailLines = widget.details.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    final parsed = <String, String>{};
    for (final line in detailLines) {
      final splitAt = line.indexOf(':');
      if (splitAt > 0) parsed[line.substring(0, splitAt).trim()] = line.substring(splitAt + 1).trim();
    }
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.color.withValues(alpha: .24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 10, 4),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: .10),
                border: Border.all(color: widget.color.withValues(alpha: .40)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إغلاق هذا الطلب من القائمة',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _closed = true),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.type == 'طلب شراء' ? 'عايز أشتري' : 'عايز أبيع',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 7),
            if (_negotiationStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(_negotiationStatus!, style: const TextStyle(color: purple, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () {
                      setState(() => _detailsExpanded = !_detailsExpanded);
                      _interact('view');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: orange,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
                      minimumSize: const Size(0, 36),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text('معاينة ${_counts['view'] ?? 0}')),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _interact('accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
                      minimumSize: const Size(0, 36),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text('قبول ${_counts['accept'] ?? 0}')),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _interact('reject'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
                      minimumSize: const Size(0, 36),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text('رفض ${_counts['reject'] ?? 0}')),
                  ),
                ),
              ],
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F4FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Expanded(child: Text('تفاصيل الطلب', style: TextStyle(fontWeight: FontWeight.w700))),
                    Icon(_detailsExpanded ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down, color: purple),
                  ],
                ),
              ),
            ),
            if (_detailsExpanded) ...[
              const SizedBox(height: 8),
              if (parsed['الصنف'] != null) _detailRow('اسم الصنف', parsed['الصنف']!),
              if (parsed['الكمية'] != null) _detailRow('الكمية', parsed['الكمية']!),
              if (parsed['تاريخ الصلاحية'] != null) _detailRow('تاريخ الصلاحية', parsed['تاريخ الصلاحية']!),
              if (parsed['السعر'] != null) _detailRow('سعر العرض', parsed['السعر']!),
              if (parsed['التفاوض'] != null) _detailRow('التفاوض', parsed['التفاوض']!),
              _detailRow('تاريخ الصلاحية', widget.expiryDate.isEmpty ? 'غير محدد' : widget.expiryDate),
              _detailRow('السعر', widget.isNegotiable ? 'قابل للتفاوض البسيط' : 'السعر نهائي'),
              if (parsed.isEmpty || detailLines.any((line) => !line.contains(':')))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(widget.details, style: const TextStyle(height: 1.5)),
                ),
            ],
            if (widget.isNegotiable && _hasAccepted && widget.postOwnerId != database?.auth.currentUser?.id) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _busy ? null : _showNegotiationDialog, icon: const Icon(Icons.currency_exchange), label: const Text('اقتراح سعر تفاوض')),
            ],
            if (_detailsExpanded)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _negotiationsFuture,
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                  final userId = database?.auth.currentUser?.id;
                  if (rows.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Divider(),
                    const Text('سجل التفاوض', style: TextStyle(fontWeight: FontWeight.bold, color: purple)),
                    ...rows.map((row) {
                      final pendingForMe = row['recipient_id']?.toString() == userId && row['status'] == 'pending';
                      final proposer = row['proposer_id']?.toString() == userId;
                      final price = row['proposed_price']?.toString() ?? '—';
                      final status = switch ((row['status'] ?? '').toString()) { 'accepted' => 'مقبول', 'rejected' => 'مرفوض', 'countered' => 'تم تقديم سعر مقابل', _ => 'بانتظار الرد' };
                      return Card(margin: const EdgeInsets.only(top: 6), child: Padding(padding: const EdgeInsets.all(9), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('${proposer ? 'اقتراحك' : 'اقتراح وارد'}: $price ج.م', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('الحالة: $status', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        if (pendingForMe) Wrap(spacing: 6, children: [
                          TextButton(onPressed: () => _respondNegotiation(row, 'accept'), child: const Text('قبول السعر')),
                          TextButton(onPressed: () => _respondNegotiation(row, 'reject'), child: const Text('رفض')),
                          TextButton(onPressed: () => _counterNegotiation(row), child: const Text('تعديل السعر')),
                        ]),
                      ])));
                    }),
                  ]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 112, child: Text(label, style: const TextStyle(color: purple, fontWeight: FontWeight.w700))),
      Expanded(child: Text(value)),
    ]),
  );
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
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('عناويني المحفوظة')),
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
            address.text = formatAddress(selected!);
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

