import 'package:flutter/material.dart';

void main() {
  runApp(const SilsilaApp());
}

class SilsilaApp extends StatelessWidget {
  const SilsilaApp({super.key});

  static const Color purple = Color(0xFF3E007D);
  static const Color orange = Color(0xFFFFA015);
  static const Color pink = Color(0xFFFF27C3);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سلسلة Silsila',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          primary: purple,
          secondary: orange,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SilsilaHomePage(),
    );
  }
}

class SilsilaHomePage extends StatefulWidget {
  const SilsilaHomePage({super.key});

  @override
  State<SilsilaHomePage> createState() => _SilsilaHomePageState();
}

class _SilsilaHomePageState extends State<SilsilaHomePage> {
  int selectedIndex = 1;

  final List<Map<String, Object>> categories = [
    {'name': 'زيوت', 'icon': Icons.water_drop_outlined},
    {'name': 'مكرونة', 'icon': Icons.ramen_dining},
    {'name': 'بقوليات', 'icon': Icons.grain},
    {'name': 'منظفات', 'icon': Icons.cleaning_services_outlined},
    {'name': 'مشروبات', 'icon': Icons.local_drink_outlined},
    {'name': 'معلبات', 'icon': Icons.inventory_2_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: SilsilaApp.purple,
          foregroundColor: Colors.white,
          title: const Text(
            'سلسلة Silsila',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
              tooltip: 'الإشعارات',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.menu),
              tooltip: 'القائمة',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'سلسلة .. بنربط السوق ببعضه',
              style: TextStyle(
                color: SilsilaApp.purple,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Search
            TextField(
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن مورد أو صنف...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Categories
            const Text(
              'الأقسام الرئيسية',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SilsilaApp.purple,
              ),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final category = categories[index];

                return Container(
                  decoration: BoxDecoration(
                    color: SilsilaApp.purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SilsilaApp.purple.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        size: 34,
                        color: SilsilaApp.purple,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['name'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Suppliers heading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الموردون',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SilsilaApp.purple,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('عرض الكل'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Demo supplier cards
            _supplierCard(
              name: 'مورد المواد الغذائية',
              description: 'مواد غذائية متنوعة',
              minimum: 'الحد الأدنى للطلب: 1,000 جنيه',
            ),

            _supplierCard(
              name: 'مورد الزيوت والسمن',
              description: 'زيوت وسمن بأسعار الجملة',
              minimum: 'الحد الأدنى للطلب: 500 جنيه',
            ),

            _supplierCard(
              name: 'مورد المكرونة والبقوليات',
              description: 'أصناف متنوعة للتجار',
              minimum: 'الحد الأدنى للطلب: 750 جنيه',
            ),

            const SizedBox(height: 12),

            // Offers banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SilsilaApp.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: SilsilaApp.purple,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تابع أحدث عروض الموردين داخل سلسلة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SilsilaApp.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        bottomNavigationBar: NavigationBar(
  selectedIndex: selectedIndex,
  onDestinationSelected: (index) {
    setState(() {
      selectedIndex = index;
    });
  },
  indicatorColor: SilsilaApp.orange.withValues(alpha: 0.25),
  destinations: const [
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'السلة',
    ),
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz),
      label: 'المزيد',
    ),
  ],
),
),
);
}

Widget _supplierCard({
  required String name,
  required String description,
  required String minimum,
}) {
  return Card(
    color: Colors.white,
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SilsilaApp.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: SilsilaApp.purple,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(description),
                const SizedBox(height: 5),
                Text(
                  minimum,
                  style: const TextStyle(
                    color: SilsilaApp.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.favorite_border,
              color: SilsilaApp.pink,
            ),
            tooltip: 'إضافة للمفضلة',
          ),
        ],
      ),
    ),
  );
}
}
