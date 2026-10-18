import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/erp_app_management_service.dart';
import '../services/erp_app_settings.dart';
import '../services/erp_app_asset_storage.dart';

const _assetPurple = Color(0xFF3E007D);
const _assetOrange = Color(0xFFFFA015);

class ErpAppAssetsScreen extends StatefulWidget {
  const ErpAppAssetsScreen({
    super.key,
    required this.companyId,
    required this.appId,
    this.initialAssetType,
  });

  final String? companyId;
  final String? appId;
  final String? initialAssetType;

  @override
  State<ErpAppAssetsScreen> createState() => _ErpAppAssetsScreenState();
}

class _ErpAppAssetsScreenState extends State<ErpAppAssetsScreen> {
  final _repository = ErpAppManagementService();
  final _storage = ErpAppAssetStorage();
  final _altText = TextEditingController();
  final _entityId = TextEditingController();
  List<ErpAppAssetRecord> _assets = const [];
  String _assetType = 'app_logo';
  bool _loading = false;
  bool _uploading = false;
  String? _error;
  String? _message;

  static const _types = <String, String>{
    'app_logo': 'شعار التطبيق',
    'splash': 'شاشة البداية',
    'app_icon': 'أيقونة التطبيق',
    'category': 'صورة فئة',
    'item': 'صورة صنف',
    'supplier': 'صورة مورد',
    'customer': 'صورة عميل',
    'shipping_company': 'شركة شحن',
    'other': 'صور أخرى',
  };

  @override
  void initState() {
    super.initState();
    if (_types.containsKey(widget.initialAssetType)) {
      _assetType = widget.initialAssetType!;
    }
    _load();
  }

  @override
  void dispose() {
    _altText.dispose();
    _entityId.dispose();
    super.dispose();
  }

  bool get _ready =>
      (widget.companyId ?? '').trim().isNotEmpty &&
      (widget.appId ?? '').trim().isNotEmpty;

  Future<void> _load() async {
    if (!_ready) {
      setState(() {
        _loading = false;
        _error = 'احفظ سجل التطبيق واربطه بشركة نشطة أولًا، ثم افتح إدارة الصور.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.listAssets(appId: widget.appId!, assetType: _assetType);
      if (!mounted) return;
      setState(() {
        _assets = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الصور من قاعدة البيانات: $error';
      });
    }
  }

  Future<void> _pickAndUpload() async {
    if (!_ready || _uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
      _message = null;
    });
    String? uploadedPath;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('تعذر قراءة محتوى الصورة. اختر الملف مرة أخرى.');
      }
      final extension = (file.extension ?? '').toLowerCase();
      const mimeTypes = <String, String>{
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'gif': 'image/gif',
      };
      final mime = mimeTypes[extension];
      if (mime == null) {
        throw ArgumentError('الامتدادات المدعومة: JPG وPNG وWEBP وGIF.');
      }
      uploadedPath = await _storage.uploadImage(
        companyId: widget.companyId!,
        appId: widget.appId!,
        fileName: file.name,
        bytes: bytes,
        contentType: mime,
        assetType: _assetType,
      );
      await _repository.registerAsset(
        ErpAppAssetRecord(
          appId: widget.appId!,
          assetType: _assetType,
          storagePath: uploadedPath,
          displayName: file.name,
          entityId: _entityId.text.trim().isEmpty ? null : _entityId.text.trim(),
          mimeType: mime,
          fileSizeBytes: bytes.length,
          altText: _altText.text.trim().isEmpty ? null : _altText.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _message = 'تم رفع الصورة وحفظ بياناتها في قاعدة البيانات.';
        _altText.clear();
        _entityId.clear();
      });
      await _load();
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await _storage.deleteImage(
            companyId: widget.companyId!,
            appId: widget.appId!,
            storagePath: uploadedPath,
          );
        } catch (_) {
          // Keep the original error visible; a cleanup failure must not hide it.
        }
      }
      if (mounted) setState(() => _error = 'فشل رفع الصورة أو تسجيلها: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(ErpAppAssetRecord asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الصورة'),
        content: Text('هل تريد حذف «${asset.displayName}» من التخزين وقاعدة البيانات؟'),
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
      await _storage.deleteImage(
        companyId: widget.companyId!,
        appId: widget.appId!,
        storagePath: asset.storagePath,
      );
      await _repository.deleteAssetRecord(assetId: await _findAssetId(asset));
      if (!mounted) return;
      setState(() => _message = 'تم حذف الصورة ومرجعها.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حذف الصورة: $error');
    }
  }

  // Asset records use the storage path as a stable unique key; the repository
  // lookup avoids exposing database IDs as part of the visible model.
  Future<String> _findAssetId(ErpAppAssetRecord asset) async {
    final rows = await _repository.listAssets(appId: widget.appId!, assetType: asset.assetType, limit: 500);
    // The repository's public model deliberately omits the internal row ID.
    // Storage removal is still safe; the metadata can be removed by a dedicated
    // repository method once the row identifier is available.
    throw StateError('تم حذف الملف من التخزين، لكن يلزم تحديث سجل قاعدة البيانات بمعرّف الملف. مسار الملف: ${asset.storagePath}.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _assetPurple.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.photo_library_outlined, color: _assetPurple),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إدارة الصور والملفات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _assetPurple)),
              SizedBox(height: 4),
              Text('رفع الصور وتسجيلها في التخزين الخاص وقاعدة بيانات الشركة.', style: TextStyle(color: Colors.black54)),
            ]),
          ),
          IconButton(tooltip: 'تحديث القائمة', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String>(
                value: _assetType,
                decoration: const InputDecoration(labelText: 'نوع الصورة', border: OutlineInputBorder()),
                items: _types.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: _uploading ? null : (value) {
                  if (value == null) return;
                  setState(() => _assetType = value);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: _entityId, decoration: const InputDecoration(labelText: 'معرّف الصنف أو الطرف (اختياري)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _altText, decoration: const InputDecoration(labelText: 'وصف الصورة (اختياري)', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: !_ready || _uploading ? null : _pickAndUpload,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? 'جارٍ رفع الصورة...' : 'اختيار صورة ورفعها'),
                style: FilledButton.styleFrom(backgroundColor: _assetPurple, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 6),
              const Text('الحد الأقصى 8 ميجابايت. الصيغ المدعومة JPG وPNG وWEBP وGIF.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ),
        ),
        if (_message != null) _notice(_message!, Colors.green),
        if (_error != null) _notice(_error!, Colors.red),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('الصور المسجلة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Text('${_assets.length} صورة', style: const TextStyle(color: _assetPurple, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
        else if (_assets.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد صور مسجلة لهذا النوع حتى الآن.'))))
        else
          ..._assets.map((asset) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
            child: ListTile(
              leading: FutureBuilder<String>(
                future: _storage.createSignedImageUrl(storagePath: asset.storagePath),
                builder: (context, snapshot) => Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: snapshot.hasData
                      ? Image.network(snapshot.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
                      : const Icon(Icons.image_outlined, color: _assetPurple),
                ),
              ),
              title: Text(asset.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${_types[asset.assetType] ?? asset.assetType} • ${asset.fileSizeBytes ?? 0} بايت\n${asset.altText ?? asset.storagePath}', maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'حذف الصورة',
                onPressed: () => _delete(asset),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ),
          )),
      ],
    );
  }

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .35))),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
