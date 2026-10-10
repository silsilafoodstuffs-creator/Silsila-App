import 'package:flutter/material.dart';

const Color purple = Color(0xFF3E007D);
const Color orange = Color(0xFFFFA015);
const Color pink = Color(0xFFFF27C3);

void main() {
  runApp(const SilsilaApp());
}

class SilsilaApp extends StatelessWidget {
  const SilsilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سلسلة Silsila',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F7FA),
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
        appBarTheme: const AppBarTheme(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SilsilaHome(),
      ),
    );
  }
}

class SilsilaHome extends StatefulWidget {
  const SilsilaHome({super.key});

  @override
  State<SilsilaHome> createState() => _SilsilaHomeState();
}

class _SilsilaHomeState extends State<SilsilaHome> {
  int selectedBottom = 1;
  int selectedHomeTab = 0;

  final TextEditingController searchController = TextEditingController();

  final Set<String> favorites = {};

  final List<Map<String, dynamic>> cart = [];

  final List<Map<String, String>> suppliers = [
    {
      'name': 'مؤسسة الأمان للمواد الغذائية',
      'type': 'تاجر جملة',
      'price': 'الأسعار قابلة للتفاوض',
      'minimum': 'الحد الأدنى للفاتورة: 2000 جنيه',
      'items': '120 صنفًا',
    },
    {
      'name': 'شركة الخير للتجارة والتوزيع',
      'type': 'شركة توزيع',
      'price': 'الأسعار نهائية',
      'minimum': 'الحد الأدنى للفاتورة: 1500 جنيه',
      'items': '85 صنفًا',
    },
    {
      'name': 'تجار المستقبل',
      'type': 'تاجر جملة جملة',
      'price': 'الأسعار قابلة للتفاوض',
      'minimum': 'الحد الأدنى للفاتورة: 3000 جنيه',
      'items': '200 صنف',
    },
    {
      'name': 'النور لتجارة السلع الغذائية',
      'type': 'تاجر جملة',
      'price': 'الأسعار نهائية',
      'minimum': 'الحد الأدنى للفاتورة: 1000 جنيه',
      'items': '65 صنفًا',
    },
  ];

  final List<Map<String, dynamic>> categories = [
    {'name': 'السمن والزيوت', 'icon': Icons.water_drop, 'color': orange},
    {'name': 'المكرونات', 'icon': Icons.ramen_dining, 'color': purple},
    {'name': 'البقوليات', 'icon': Icons.grass, 'color': Colors.green},
    {'name': 'المشروبات', 'icon': Icons.local_drink, 'color': Colors.blue},
    {'name': 'الألبان والجبن', 'icon': Icons.egg_alt, 'color': pink},
    {'name': 'المنظفات', 'icon': Icons.cleaning_services, 'color': tealColor},
    {'name': 'المعلبات', 'icon': Icons.inventory_2, 'color': Colors.brown},
    {'name': 'الحلويات', 'icon': Icons.cake, 'color': Colors.deepOrange},
  ];

  static const Color tealColor = Color(0xFF008C95);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void showNotifications() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإشعارات'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active, color: orange, size: 42),
            SizedBox(height: 12),
            Text('أهلًا بيك في سلسلة!'),
            SizedBox(height: 8),
            Text(
              'هتظهر هنا إشعارات الطلبات والعروض والتحديثات الجديدة.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  void addToCart(String name) {
    final index = cart.indexWhere((item) => item['name'] == name);

    setState(() {
      if (index >= 0) {
        cart[index]['qty'] = (cart[index]['qty'] as int) + 1;
      } else {
        cart.add({
          'name': name,
          'price': 50,
          'qty': 1,
        });
      }
    });

    showMessage('تمت إضافة $name إلى السلة التجريبية');
  }

  int get cartCount {
    return cart.fold<int>(
      0,
      (total, item) => total + (item['qty'] as int),
    );
  }

  int get cartTotal {
    return cart.fold<int>(
      0,
      (total, item) =>
          total + ((item['price'] as int) * (item['qty'] as int)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سلسلة Silsila',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
            ),
            Text(
              'بنربط السوق ببعضه',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: showNotifications,
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'المزيد',
            onPressed: () => setState(() => selectedBottom = 2),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildSelectedPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedBottom,
        onDestinationSelected: (index) {
          setState(() {
            selectedBottom = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: 'السلة',
          ),
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (selectedBottom) {
      case 0:
        return _buildCartPage();
      case 2:
        return _buildMorePage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    final query = searchController.text.trim().toLowerCase();

    final filteredSuppliers = suppliers.where((supplier) {
      final name = supplier['name']!.toLowerCase();
      final type = supplier['type']!.toLowerCase();
      return name.contains(query) || type.contains(query);
    }).toList();

    final filteredCategories = categories.where((category) {
      return (category['name'] as String).toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [purple, Color(0xFF6B24A8)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلًا بيك في سلسلة 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'كل اللي تحتاجه لتجارتك في مكان واحد.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث عن مورد أو صنف...',
            prefixIcon: const Icon(Icons.search, color: purple),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          height: 45,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _homeTab('الموردين', 0),
              _homeTab('الأقسام', 1),
              _homeTab('سوق التجار', 2),
              _homeTab('مجلة العروض', 3),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (selectedHomeTab == 0) ...[
          _sectionTitle('الموردون', 'اكتشف المورد المناسب لتجارتك'),
          const SizedBox(height: 12),
          if (filteredSuppliers.isEmpty)
            _emptyMessage('مفيش موردين مطابقين للبحث.')
          else
            ...filteredSuppliers.map(_supplierCard),
        ] else if (selectedHomeTab == 1) ...[
          _sectionTitle('أقسام المواد الغذائية', 'اختار القسم اللي محتاجه'),
          const SizedBox(height: 12),
          if (filteredCategories.isEmpty)
            _emptyMessage('مفيش أقسام مطابقة للبحث.')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showMessage(
                    'اخترت قسم ${category['name']} — ربط المنتجات الفعلية هيتم لاحقًا.',
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          color: category['color'] as Color,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          category['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ] else if (selectedHomeTab == 2) ...[
          _sectionTitle('سوق التجار', 'مكان لعرض طلبات وعروض التجار'),
          const SizedBox(height: 12),
          _featureCard(
            Icons.storefront,
            'طلبات التجار',
            'هنا هتقدر تستعرض طلبات الشراء والبيع بين التجار.',
            orange,
          ),
          _featureCard(
            Icons.handshake_outlined,
            'فرص تجارية',
            'قسم مخصص للتواصل التجاري بين أعضاء سلسلة.',
            purple,
          ),
          const SizedBox(height: 8),
          const Text(
            'المحتوى المعروض توضيحي، ولسه مفيش تجار متصلين بالنظام.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ] else ...[
          _sectionTitle('مجلة العروض', 'تابع أحدث عروض الموردين'),
          const SizedBox(height: 12),
          _featureCard(
            Icons.local_offer,
            'العروض الجديدة',
            'هنا هتظهر العروض والخصومات عند ربط التطبيق بقاعدة البيانات.',
            pink,
          ),
          _featureCard(
            Icons.access_time,
            'العروض الحالية',
            'العروض الحقيقية هتظهر هنا بعد تفعيل حسابات الموردين.',
            orange,
          ),
        ],
      ],
    );
  }

  Widget _homeTab(String title, int index) {
    final selected = selectedHomeTab == index;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: selected,
        selectedColor: purple,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : purple,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) {
          setState(() {
            selectedHomeTab = index;
          });
        },
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: purple,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _supplierCard
