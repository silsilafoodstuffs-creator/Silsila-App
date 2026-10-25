import 'package:flutter/material.dart';
import '../services/erp_api_integration.dart';

const _apiPurple = Color(0xFF3E007D);
const _apiOrange = Color(0xFFFFA015);

/// One workspace for API interface, external connections, and API-key management.
/// Secrets are intentionally never generated or displayed by this client-only screen.
class ErpApiManagementScreen extends StatefulWidget {
  const ErpApiManagementScreen({super.key});

  @override
  State<ErpApiManagementScreen> createState() => _ErpApiManagementScreenState();
}

class _ErpApiManagementScreenState extends State<ErpApiManagementScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _url = TextEditingController();
  final Set<String> _scopes = <String>{'items:read'};
  String? _validationMessage;
  bool _active = true;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _url.dispose();
    super.dispose();
  }

  void _validateConnection() {
    final model = ErpApiIntegration(
      clientName: _name.text,
      clientCode: _code.text,
      baseUrl: _url.text,
      scopes: _scopes,
      active: _active,
    );
    final errors = model.validate();
    setState(() => _validationMessage = errors.isEmpty
        ? 'البيانات صحيحة مبدئيًا. لم يتم إنشاء اتصال أو حفظ إعدادات بعد.'
        : errors.join('\n'));
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _apiPurple)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ]),
      );

  Widget _apiInterface() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle('واجهة API', 'كتالوج المسارات المقترحة. هذه قائمة تعريفية وليست نقاط اتصال منشورة فعليًا.'),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('المسار')),
                  DataColumn(label: Text('الطريقة')),
                  DataColumn(label: Text('الصلاحية المطلوبة')),
                  DataColumn(label: Text('الوصف')),
                ],
                rows: erpApiCatalog.map((endpoint) => DataRow(cells: [
                  DataCell(Text(endpoint.name)),
                  DataCell(SelectableText(endpoint.path)),
                  DataCell(Text(endpoint.method)),
                  DataCell(Text(endpoint.requiredScope)),
                  DataCell(SizedBox(width: 250, child: Text(endpoint.description))),
                ])).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('يجب أن تمر الطلبات الفعلية عبر خادم موثوق يتحقق من هوية المستخدم والشركة والصلاحيات وحدود الاستخدام.',
              style: TextStyle(color: Colors.black54)),
        ],
      );

  Widget _externalConnection() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle('الربط الخارجي', 'تعريف بيانات النظام الخارجي والتحقق من صحتها قبل تفعيل الحفظ والاتصال.'),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم النظام المتصل', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'رمز الربط', helperText: '3 إلى 40 حرفًا أو رقمًا أو - أو _', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'عنوان الخدمة الأساسي', hintText: 'https://example.com', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Text('الصلاحيات المسموحة', style: TextStyle(fontWeight: FontWeight.w800)),
          ...const [
            ('company:read', 'قراءة بيانات الشركة'),
            ('items:read', 'قراءة الأصناف'),
            ('customers:read', 'قراءة العملاء'),
            ('suppliers:read', 'قراءة الموردين'),
            ('inventory:read', 'قراءة المخزون'),
            ('orders:write', 'إنشاء الطلبات'),
          ].map((scope) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _scopes.contains(scope.$1),
                title: Text(scope.$2),
                subtitle: Text(scope.$1),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _scopes.add(scope.$1);
                  } else {
                    _scopes.remove(scope.$1);
                  }
                }),
              )),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الربط نشط'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _apiPurple),
              onPressed: _validateConnection,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('التحقق من البيانات'),
            ),
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(10)),
              child: Text(_validationMessage!),
            ),
          ],
        ],
      );

  Widget _apiKeys() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle('إدارة مفاتيح API', 'مكان موحد لإدارة بيانات الاعتماد ومراجعة حالتها.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.key_rounded, color: _apiOrange, size: 34),
                const SizedBox(height: 8),
                const Text('لا توجد مفاتيح معروضة في هذه الشاشة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('لم يتم توصيل إدارة المفاتيح بجدول آمن أو بخادم إصدار مفاتيح بعد. لذلك لن يتم إنشاء مفاتيح وهمية أو عرض أسرار غير مخزنة بأمان.'),
                const SizedBox(height: 12),
                const Divider(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.security_outlined, color: _apiPurple),
                  title: Text('توصية أمنية'),
                  subtitle: Text('تخزين بصمة المفتاح فقط، وإظهار القيمة السرية مرة واحدة عند إصدارها من الخادم، مع صلاحيات محددة وتاريخ انتهاء وإمكانية إلغاء المفتاح.'),
                ),
              ]),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: _apiPurple,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إدارة مفاتيح API', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('واجهة API والربط الخارجي ومفاتيح الوصول في شاشة واحدة', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              TabBar(
                isScrollable: true,
                indicatorColor: _apiOrange,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'واجهة API'),
                  Tab(text: 'الربط الخارجي'),
                  Tab(text: 'إدارة مفاتيح API'),
                ],
              ),
            ]),
          ),
          const Expanded(child: TabBarView(children: [
            _ApiCatalogTab(),
            _ApiExternalTab(),
            _ApiKeysTab(),
          ])),
        ]),
      );
}

class _ApiCatalogTab extends StatelessWidget {
  const _ApiCatalogTab();
  @override
  Widget build(BuildContext context) => const _ApiTabContent(kind: 0);
}
class _ApiExternalTab extends StatelessWidget {
  const _ApiExternalTab();
  @override
  Widget build(BuildContext context) => const _ApiTabContent(kind: 1);
}
class _ApiKeysTab extends StatelessWidget {
  const _ApiKeysTab();
  @override
  Widget build(BuildContext context) => const _ApiTabContent(kind: 2);
}

/// Small tab host keeps the tab bar and its body mounted within the dashboard's
/// bounded content area. Detailed editable connection controls live above in
/// the screen state and will be persisted once the secure backend is connected.
class _ApiTabContent extends StatelessWidget {
  const _ApiTabContent({required this.kind});
  final int kind;
  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 0:
        return ListView(padding: const EdgeInsets.all(14), children: [
          const Text('كتالوج واجهة API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _apiPurple)),
          const SizedBox(height: 8),
          ...erpApiCatalog.map((endpoint) => Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFF5EFFB), child: Text(endpoint.method, style: const TextStyle(fontSize: 10, color: _apiPurple))),
            title: Text(endpoint.name),
            subtitle: Text('${endpoint.path} • ${endpoint.requiredScope}\n${endpoint.description}'),
            isThreeLine: true,
          ))),
          const Text('المسارات تعريفية فقط؛ لم يتم نشر API فعلي حتى الآن.', style: TextStyle(color: Colors.black54)),
        ]);
      case 1:
        return const _ApiConnectionPlaceholder();
      default:
        return const _ApiKeysPlaceholder();
    }
  }
}
class _ApiConnectionPlaceholder extends StatelessWidget {
  const _ApiConnectionPlaceholder();
  @override
  Widget build(BuildContext context) => const ListView(padding: EdgeInsets.all(14), children: [
    Text('الربط الخارجي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _apiPurple)),
    SizedBox(height: 8),
    Card(child: Padding(padding: EdgeInsets.all(16), child: Text('إعدادات الربط والتحقق من العنوان والصلاحيات. يلزم ربط الحفظ بخادم موثوق قبل تشغيل اتصال فعلي.'))),
  ]);
}
class _ApiKeysPlaceholder extends StatelessWidget {
  const _ApiKeysPlaceholder();
  @override
  Widget build(BuildContext context) => const ListView(padding: EdgeInsets.all(14), children: [
    Text('إدارة مفاتيح API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _apiPurple)),
    SizedBox(height: 8),
    Card(child: Padding(padding: EdgeInsets.all(16), child: Text('إدارة المفاتيح تحتاج مخزنًا آمنًا وخدمة إصدار وإلغاء على الخادم. لن يتم إنشاء أو عرض مفاتيح وهمية داخل التطبيق.'))),
  ]);
}
