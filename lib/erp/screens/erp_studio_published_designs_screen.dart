import 'package:flutter/material.dart';

import '../services/erp_studio_repository.dart';
import '../services/studio_document.dart';
import '../services/studio_renderer.dart';

const _publishedPurple = Color(0xFF3E007D);

class ErpStudioPublishedDesignsScreen extends StatefulWidget {
  const ErpStudioPublishedDesignsScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpStudioPublishedDesignsScreen> createState() => _ErpStudioPublishedDesignsScreenState();
}

class _ErpStudioPublishedDesignsScreenState extends State<ErpStudioPublishedDesignsScreen> {
  final _repository = ErpStudioRepository();
  List<Map<String, dynamic>> _designs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = widget.companyId;
    if (company == null || company.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لا توجد شركة نشطة لعرض التصميمات المنشورة.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.listDesigns(company);
      final published = rows.where((row) => row['status'] == 'published').toList();
      if (mounted) setState(() => _designs = published);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل التصميمات المنشورة: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final company = widget.companyId;
    if (company == null) return;
    try {
      final id = row['id'].toString();
      final remote = await _repository.getDesign(companyId: company, designId: id);
      final raw = remote['design_json'];
      if (raw is! Map) throw const FormatException('مخطط التصميم المنشور غير صالح.');
      final document = StudioDocument.fromJson(Map<String, dynamic>.from(raw));
      final data = await _repository.previewBindings(companyId: company, document: document, limit: 50);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _PublishedDesignPreview(
          document: document,
          dataBySource: data,
          revision: (remote['published_revision'] as num?)?.toInt() ?? (remote['revision'] as num?)?.toInt() ?? 0,
        ),
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح التصميم المنشور: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFFAF8FC),
      appBar: AppBar(
        title: const Text('شاشات الاستوديو المنشورة'),
        backgroundColor: _publishedPurple,
        foregroundColor: Colors.white,
        actions: [IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _designs.isEmpty
                  ? const Center(child: Text('لا توجد تصميمات منشورة لهذه الشركة حتى الآن.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _designs.length,
                      itemBuilder: (context, index) {
                        final row = _designs[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.web_asset_outlined, color: _publishedPurple),
                            title: Text((row['name'] ?? '').toString()),
                            subtitle: Text('${row['design_kind']} • الإصدار المنشور ${row['published_revision'] ?? row['revision']}'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _open(row),
                          ),
                        );
                      },
                    ),
    ),
  );
}

class _PublishedDesignPreview extends StatelessWidget {
  const _PublishedDesignPreview({
    required this.document,
    required this.dataBySource,
    required this.revision,
  });

  final StudioDocument document;
  final Map<String, List<Map<String, dynamic>>> dataBySource;
  final int revision;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text(document.name),
        backgroundColor: _publishedPurple,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('تصميم منشور • الإصدار $revision', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ),
      ),
      body: StudioDocumentRenderer(document: document, dataBySource: dataBySource),
    ),
  );
}
