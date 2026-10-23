import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/erp_app_management_service.dart';
import '../services/erp_app_settings.dart';
import '../services/erp_app_asset_storage.dart';

const _assetPurple = Color(0xFF3E007D);

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
  final Map<String, Future<String>> _signedUrlFutures = {};
  final Map<String, DateTime> _signedUrlCreatedAt = {};
  String _assetType = 'app_logo';
  bool _loading = false;
  int _loadGeneration = 0;
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
  void didUpdateWidget(covariant ErpAppAssetsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId || oldWidget.appId != widget.appId || oldWidget.initialAssetType != widget.initialAssetType) {
      if (oldWidget.companyId != widget.companyId || oldWidget.appId != widget.appId) {
        _signedUrlFutures.clear();
        _signedUrlCreatedAt.clear();
      }
      if (_types.containsKey(widget.initialAssetType)) _assetType = widget.initialAssetType!;
      _load();
    }
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

  Future<String> _signedUrlFor(String storagePath) async {
    final now = DateTime.now();
    final createdAt = _signedUrlCreatedAt[storagePath];
    final cached = _signedUrlFutures[storagePath];
    if (cached != null &&
        createdAt != null &&
        now.difference(createdAt) < const Duration(minutes: 12)) {
      return cached;
    }

    final future = _storage.createSignedImageUrl(storagePath: storagePath);
    _signedUrlFutures[storagePath] = future;
    _signedUrlCreatedAt[storagePath] = now;
    try {
      return await future;
    } catch (_) {
      // A failed request should not poison the cache; a rebuild may retry it.
      if (identical(_signedUrlFutures[storagePath], future)) {
        _signedUrlFutures.remove(storagePath);
        _signedUrlCreatedAt.remove(storagePath);
      }
      rethrow;
    }
  }
  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!_ready) {
      if (!mounted) return;
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
      final result = await _repository.listAssets(
        appId: widget.appId!,
        assetType: _assetType,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _assets = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
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
      if (result == null || result.files.isEmpty) return;
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
      final entityId = _entityId.text.trim();
      if (entityId.isNotEmpty && !_isUuid(entityId)) {
        throw ArgumentError('معرّف الصنف أو الطرف يجب أن يكون UUID صحيحًا.');
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
          entityId: entityId.isEmpty ? null : entityId,
          mimeType: mime,
          fileSizeBytes: bytes.length,
          altText: _altText.text.trim().isEmpty ? null : _altText.text.trim(),
        ),
      );
      String? themeWarning;
      if (const {'app_logo', 'splash', 'app_icon'}.contains(_assetType)) {
        try {
          final current = await _repository.getThemeSettings(appId: widget.appId!);
          await _repository.saveThemeSettings(ErpAppThemeSettings(
            appId: widget.appId!,
            displayName: current?.displayName.isNotEmpty == true ? current!.displayName : 'سلسلة',
            primaryColor: current?.primaryColor ?? '#3E007D',
            accentColor: current?.accentColor ?? '#FFA015',
            logoPath: _assetType == 'app_logo' ? uploadedPath : current?.logoPath,
            splashImagePath: _assetType == 'splash' ? uploadedPath : current?.splashImagePath,
            iconPath: _assetType == 'app_icon' ? uploadedPath : current?.iconPath,
          ));
        } catch (error) {
          themeWarning = 'تم رفع الصورة، لكن تعذر ربطها بهوية التطبيق: $error';
        }
      }
      if (!mounted) return;
      setState(() {
        _message = themeWarning ?? 'تم رفع الصورة وحفظ بياناتها في قاعدة البيانات.';
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
        } catch (_) {}
      }
      if (mounted) setState(() => _error = 'فشل رفع الصورة أو تسجيلها: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _edit(ErpAppAssetRecord asset) async {
    final id = asset.id;
    if (id == null || id.isEmpty) {
      setState(() => _error = 'معرّف الصورة غير متاح للتعديل.');
      return;
    }
    final name = TextEditingController(text: asset.displayName);
    final entity = TextEditingController(text: asset.entityId ?? '');
    final alt = TextEditingController(text: asset.altText ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات الصورة'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم الصورة *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: entity,
                decoration: const InputDecoration(labelText: 'معرّف الصنف أو الطرف (UUID اختياري)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: alt,
                decoration: const InputDecoration(labelText: 'وصف الصورة'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ التعديلات')),
        ],
      ),
    );
    if (saved != true) {
      name.dispose();
      entity.dispose();
      alt.dispose();
      return;
    }
    try {
      final entityId = entity.text.trim();
      if (entityId.isNotEmpty && !_isUuid(entityId)) {
        throw ArgumentError('معرّف الصنف أو الطرف يجب أن يكون UUID صحيحًا.');
      }
      if (name.text.trim().isEmpty) {
        throw ArgumentError('اسم الصورة مطلوب.');
      }
      await _repository.updateAssetRecord(
        assetId: id,
        asset: ErpAppAssetRecord(
          id: id,
          appId: asset.appId,
          assetType: asset.assetType,
          storagePath: asset.storagePath,
          displayName: name.text.trim(),
          entityId: entityId.isEmpty ? null : entityId,
          mimeType: asset.mimeType,
          fileSizeBytes: asset.fileSizeBytes,
          altText: alt.text.trim().isEmpty ? null : alt.text.trim(),
        ),
      );
      if (mounted) setState(() => _message = 'تم حفظ تعديلات بيانات الصورة.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تعديل بيانات الصورة: $error');
    } finally {
      name.dispose();
      entity.dispose();
      alt.dispose();
    }
  }

  Future<void> _delete(ErpAppAssetRecord asset) async {
    final id = asset.id;
    if (id == null || id.isEmpty) {
      setState(() => _error = 'معرّف سجل الصورة غير متاح؛ لم يتم حذف أي شيء.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الصورة'),
        content: Text('هل تريد حذف «${asset.displayName}» من التخزين وقاعدة البيانات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No / لا')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes / نعم، احذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (const {'app_logo', 'splash', 'app_icon'}.contains(asset.assetType)) {
        final current = await _repository.getThemeSettings(appId: widget.appId!);
        if (current != null) {
          await _repository.saveThemeSettings(ErpAppThemeSettings(
            appId: current.appId,
            displayName: current.displayName,
            primaryColor: current.primaryColor,
            accentColor: current.accentColor,
            logoPath: current.logoPath == asset.storagePath ? null : current.logoPath,
            splashImagePath: current.splashImagePath == asset.storagePath ? null : current.splashImagePath,
            iconPath: current.iconPath == asset.storagePath ? null : current.iconPath,
          ));
        }
      }
      await _storage.deleteImage(
        companyId: widget.companyId!,
        appId: widget.appId!,
        storagePath: asset.storagePath,
      );
      await _repository.deleteAssetRecord(assetId: id);
      if (!mounted) return;
      setState(() => _message = 'تم حذف الصورة ومرجعها.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حذف الصورة: $error');
    }
  }

  bool _isUuid(String value) {
    final parts = value.split('-');
    if (parts.length != 5) return false;
    const lengths = [8, 4, 4, 4, 12];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].length != lengths[i] || int.tryParse(parts[i], radix: 16) == null) {
        return false;
      }
    }
    return true;
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
            decoration: BoxDecoration(
              color: _assetPurple.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(14),
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
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
              TextField(
                controller: _entityId,
                decoration: const InputDecoration(labelText: 'معرّف الصنف أو الطرف (UUID اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _altText,
                decoration: const InputDecoration(labelText: 'وصف الصورة (اختياري)', border: OutlineInputBorder()),
              ),
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
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
        else if (_assets.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد صور مسجلة لهذا النوع حتى الآن.'))))
        else
          ..._assets.map((asset) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: FutureBuilder<String>(
                future: _signedUrlFor(asset.storagePath),
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
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'تعديل بيانات الصورة',
                  onPressed: () => _edit(asset),
                  icon: const Icon(Icons.edit_outlined, color: _assetPurple),
                ),
                IconButton(
                  tooltip: 'حذف الصورة',
                  onPressed: () => _delete(asset),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ]),
            ),
          )),
      ],
    );
  }

  Widget _notice(String message, Color color) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
