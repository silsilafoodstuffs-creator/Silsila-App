import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const purple = Color(0xFF3E007D);
const orange = Color(0xFFFFA015);
const pink = Color(0xFFFF27C3);

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SilsilaLoginScreen(),
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
  int page = 1;
  int tab = 0;

  final search = TextEditingController();
  final Set<String> favorites = {};
  final List<String> cart = [];

  final List<Map<String, String>> suppliers = [
    {
      'name': 'مؤسسة الأمان للمواد الغذائية',
      'type': 'تاجر جملة',
      'minimum': 'الحد الأدنى للفاتورة: 2000 جنيه',
    },
    {
      'name': 'شركة الخير للتوزيع',
      'type': 'شركة توزيع',
      'minimum': 'الحد الأدنى للفاتورة: 1500 جنيه',
    },
    {
      'name': 'تجار المستقبل',
      'type': 'تاجر جملة جملة',
      'minimum': 'الحد الأدنى للفاتورة: 3000 جنيه',
    },
  ];

  final List<String> categories = [
    'السمن والزيوت',
    'المكرونات',
    'البقوليات',
    'المشروبات',
    'الألبان والجبن',
    'المنظفات',
    'المعلبات',
    'الحلويات',
    'الشوكولاتة',
    'المقرمشات',
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void message(String text) {
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
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سلسلة Silsila',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'بنربط السوق ببعضه',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('الإشعارات'),
                  content: const Text(
                    'هتظهر هنا إشعارات الطلبات والعروض الجديدة.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('تمام'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () => setState(() => page = 2),
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: page == 0
          ? cartPage()
          : page == 2
              ? morePage()
              : homePage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) {
          setState(() => page = value);
        },
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.length}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
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

  Widget homePage() {
    final query = search.text.trim().toLowerCase();

    final results = suppliers.where((supplier) {
      return supplier['name']!.toLowerCase().contains(query) ||
          supplier['type']!.toLowerCase().contains(query);
    }).toList();

    final categoryResults = categories.where((category) {
      return category.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: purple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلًا بيك في سلسلة 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
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
        const SizedBox(height: 16),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث عن مورد أو قسم...',
            prefixIcon: const Icon(Icons.search, color: purple),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              homeTab('الموردين', 0),
              homeTab('الأقسام', 1),
              homeTab('سوق التجار', 2),
              homeTab('العروض', 3),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (tab == 0) ...[
          const Text(
            'الموردون',
            style: TextStyle(
              fontSize: 20,
              color: purple,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            const Text('مفيش موردين مطابقين للبحث.')
          else
            ...results.map((supplier) => supplierCard(supplier)),
        ] else if (tab == 1) ...[
          const Text(
            'أقسام المواد الغذائية',
            style: TextStyle(
              fontSize: 20,
              color: purple,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (categoryResults.isEmpty)
            const Text('مفيش أقسام مطابقة للبحث.')
          else
            ...categoryResults.map(
              (category) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: purple,
                  ),
                  title: Text(category),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => message(
                    'اخترت قسم $category. تفاصيل المنتجات هتتضاف لاحقًا.',
                  ),
                ),
              ),
            ),
        ] else if (tab == 2) ...[
          featureCard(
            'سوق التجار',
            'قسم مخصص لطلبات البيع والشراء بين التجار.',
            Icons.storefront,
          ),
        ] else ...[
          featureCard(
            'مجلة العروض',
            'تابع عروض الموردين والخصومات الجديدة.',
            Icons.local_offer_outlined,
          ),
        ],
      ],
    );
  }

  Widget homeTab(String title, int index) {
    final selected = tab == index;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(title),
        selected: selected,
        selectedColor: purple,
        labelStyle: TextStyle(
          color: selected ? Colors.white : purple,
        ),
        onSelected: (_) {
          setState(() => tab = index);
        },
      ),
    );
  }

  Widget supplierCard(Map<String, String> supplier) {
    final name = supplier['name']!;
    final favorite = favorites.contains(name);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFF0E8F8),
                  child: Icon(Icons.store, color: purple),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supplier['type']!,
                        style: const TextStyle(color: purple),
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
                    message(
                      favorite
                          ? 'تم حذف المورد من المفضلة'
                          : 'تمت إضافة المورد للمفضلة',
                    );
                  },
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(supplier['minimum']!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() => cart.add(name));
                  message('تمت إضافة $name إلى السلة التجريبية');
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('إضافة للسلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget cartPage() {
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
        if (cart.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'السلة فاضية حاليًا.\nارجع للرئيسية واضغط إضافة للسلة.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          ...cart.asMap().entries.map((entry) {
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.shopping_bag_outlined,
                  color: purple,
                ),
                title: Text(entry.value),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() => cart.removeAt(entry.key));
                    message('تم حذف العنصر من السلة');
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text('عدد العناصر: ${cart.length}'),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.black,
            ),
            onPressed: () => message(
              'إتمام الطلب الحقيقي هيتضاف بعد ربط قاعدة البيانات.',
            ),
            child: const Text('متابعة الطلب'),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'المنتجات والأسعار في هذه النسخة تجريبية.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget morePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'المزيد',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: purple,
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: purple,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text('زائر تطبيق سلسلة'),
            subtitle: Text('لم يتم تسجيل الدخول'),
          ),
        ),
        menuItem(
          Icons.person_outline,
          'بياناتي',
          'التسجيل وتعديل البيانات هيتضافوا في مرحلة لاحقة.',
        ),
        menuItem(
          Icons.receipt_long,
          'سجل طلباتي',
          'سجل الطلبات الحقيقي محتاج قاعدة بيانات.',
        ),
        menuItem(
          Icons.favorite_outline,
          'الموردون المفضلون',
          favorites.isEmpty
              ? 'لسه مفيش موردين في المفضلة.'
              : favorites.join('\n'),
        ),
        menuItem(
          Icons.account_balance_wallet_outlined,
          'رصيدي ومحفظتي',
          'المحفظة هتتضاف في مرحلة لاحقة.',
        ),
        menuItem(
          Icons.settings_outlined,
          'الإعدادات',
          'إعدادات الحساب هتتضاف لاحقًا.',
        ),
        const SizedBox(height: 20),
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

  Widget menuItem(IconData icon, String title, String description) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: purple),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(description),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget featureCard(String title, String description, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: orange, size: 32),
        title: Text(title),
        subtitle: Text(description),
        onTap: () => message('$title: القسم ده تجريبي حاليًا.'),
      ),
    );
  }
}

class SilsilaLoginScreen extends StatefulWidget {
  const SilsilaLoginScreen({super.key});

  @override
  State<SilsilaLoginScreen> createState() =>
      _SilsilaLoginScreenState();
}

class _SilsilaLoginScreenState extends State<SilsilaLoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.link,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'سلسلة Silsila',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: purple,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'بنربط السوق ببعضه',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: orange, fontSize: 17),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: purple,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الموبايل',
                      hintText: 'اكتب هنا رقمك المسجل لدينا',
                      prefixIcon: const Icon(
                        Icons.phone_android,
                        color: purple,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      hintText: 'اكتب كلمة المرور الخاصة بك',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: purple,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        showMessage(
                          'استعادة كلمة المرور ستُفعّل بعد ربط خدمة الحسابات.',
                        );
                      },
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (phoneController.text.trim().isEmpty ||
                            passwordController.text.isEmpty) {
                          showMessage(
                            'من فضلك اكتب رقم الموبايل وكلمة المرور.',
                          );
                          return;
                        }

                        showMessage(
                          'تسجيل الدخول غير مفعّل بعد. يلزم ربط خدمة مصادقة حقيقية.',
                        );
                      },
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: purple,
                      side: const BorderSide(color: purple),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SilsilaRegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('إنشاء حساب جديد'),
                  ),

                  const SizedBox(height: 28),
                  const Text(
                    'للموردين والعملاء والمندوبين',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
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

class SilsilaRegisterScreen extends StatefulWidget {
  const SilsilaRegisterScreen({super.key});

  @override
  State<SilsilaRegisterScreen> createState() =>
      _SilsilaRegisterScreenState();
}

class _SilsilaRegisterScreenState
    extends State<SilsilaRegisterScreen> {
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
  String area = '';

  bool whatsappSame = true;
  bool obscurePassword = true;

  final accountTypes = const [
    'مورد',
    'عميل',
    'مندوب',
    'شركة شحن',
    'إدارة نشاط',
  ];

  final governorates = const [
    'القاهرة',
    'الجيزة',
    'القليوبية',
    'الإسكندرية',
    'أخرى',
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

  InputDecoration fieldDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: purple),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: purple,
          width: 2,
        ),
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
        decoration: fieldDecoration(label, icon),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'من فضلك أدخل $label';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          title: const Text('إنشاء حساب جديد'),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(
                child: Icon(
                  Icons.link,
                  size: 58,
                  color: purple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'انضم إلى سلسلة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: purple,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'بنربط السوق ببعضه',
                textAlign: TextAlign.center,
                style: TextStyle(color: orange),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: activityType,
                decoration: fieldDecoration(
                  'نوع النشاط',
                  Icons.storefront,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'مواد غذائية',
                    child: Text('مواد غذائية'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => activityType = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: accountType,
                decoration: fieldDecoration(
                  'نوع الحساب',
                  Icons.person_outline,
                ),
                items: accountTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => accountType = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              
textField(
  email,
  'البريد الإلكتروني',
  Icons.email_outlined,
  keyboardType: TextInputType.emailAddress,
),
textField(
  name,
  'الاسم أو اسم النشاط',
  Icons.badge_outlined,
),

              textField(
                phone,
                'رقم الموبايل',
                Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: whatsappSame,
                activeColor: purple,
                title: const Text('رقم واتساب هو نفس رقم الموبايل'),
                onChanged: (value) {
                  setState(() => whatsappSame = value ?? true);
                },
              ),

              if (!whatsappSame)
                textField(
                  whatsapp,
                  'رقم واتساب',
                  Icons.chat_outlined,
                  keyboardType: TextInputType.phone,
                ),

              DropdownButtonFormField<String>(
                value: governorate.isEmpty ? null : governorate,
                decoration: fieldDecoration(
                  'المحافظة',
                  Icons.location_city,
                ),
                hint: const Text('اختر المحافظة'),
                items: governorates
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'اختر المحافظة' : null,
                onChanged: (value) {
                  setState(() {
                    governorate = value ?? '';
                    area = '';
                  });
                },
              ),
              const SizedBox(height: 14),

              textField(
                address,
                'المنطقة أو المركز أو القرية',
                Icons.map_outlined,
              ),
              textField(
                landmark,
                'العنوان بالتفصيل وعلامة مميزة',
                Icons.place_outlined,
              ),

              TextFormField(
                controller: password,
                obscureText: obscurePassword,
                decoration: fieldDecoration(
                  'كلمة المرور',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: confirmPassword,
                obscureText: true,
                decoration: fieldDecoration(
                  'تأكيد كلمة المرور',
                  Icons.lock_reset,
                ),
                validator: (value) {
                  if (value != password.text) {
                    return 'كلمتا المرور غير متطابقتين';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'البيانات سليمة. ربط إنشاء الحساب بقاعدة البيانات هو الخطوة التالية.',
                        ),
                      ),
                    );
                  },
                  child: const Text(
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
