import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/erp_app_asset_storage.dart';
import '../services/erp_app_management_service.dart';
import '../services/erp_app_settings.dart';

const _adsPurple = Color(0xFF3E007D);
const _adSlots = <String>['إعلان 1', 'إعلان 2', 'إعلان 3', 'إعلان 4', 'إعلان 5'];

class ErpAppAdvertisementsScreen extends StatefulWidget {
  const ErpAppAdvertisementsScreen({
    super.key,
    required this.companyId,
    required this.appId,
  });

  final String? companyId;
  final String? appId;

  @override
  State<ErpAppAdvertisementsScreen> createState() => _ErpAppAdvertisementsScreenState();
}

class _ErpAppAdvertisementsScreenState extends State<ErpAppAdvertisementsScreen> {
  final _repository = ErpAppManagementService();
  final _storage = ErpAppAssetStorage(bucket: 'silsila-public-ads');
  final _picker = ImagePicker();
  final Map<String, Future<String>> _urls = {};
  List<ErpAppAssetRecord> _assets = const [];
  bool _loading = false;
  String? _error;
  String? _message;
  String? _busySlot;

  bool get _ready =>
      (widget.companyId ?? '').trim().isNotEmpty &&
      (widget.appId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpAppAdvertisementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId || oldWidget.appId != widget.appId) {
      _urls.clear();
      _load();
    }
  }

  Future<void> _load() async {
    if (!_ready) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'اختر شركة نشطة واحفظ سجل تطبيق سلسلة أولًا من إدارة التطبيقات.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listAssets(appId: widget.appId!, assetType: 'banner_ad', limit: 100);
      if (!mounted) return;
      setState(() { _assets = records; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الإعلانات. تأكد من تطبيق تحديث قاعدة البيانات وصلاحيات التخزين: $error';
      });
    }
  }

  ErpAppAssetRecord? _forSlot(String slot) {
    for (final asset in _assets) {
      if (asset.displayName == slot) return asset;
    }
    return null;
  }

  Future<String> _signedUrl(String path) {
    return _urls.putIfAbsent(path, () => _storage.createSignedImageUrl(storagePath: path));
  }

  Future<void> _chooseImage(String slot, {required bool camera}) async {
    if (!_ready || _busySlot != null) return;
    setState(() { _busySlot = slot; _error = null; _message = null; });
    String? newPath;
    try {
      String fileName;
      Uint8List bytes;
      String mime;
      if (camera) {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
          maxWidth: 2400,
        );
        if (image == null) return;
        bytes = await image.readAsBytes();
        fileName = image.name.isEmpty ? '$slot.jpg' : image.name;
        mime = _mimeFor(fileName);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.single;
        if (file.bytes == null || file.bytes!.isEmpty) {
          throw StateError('تعذر قراءة الصورة؛ اختر الملف مرة أخرى.');
        }
        fileName = file.name;
        bytes = file.bytes!;
        mime = _mimeFor(fileName);
      }
      if (bytes.length > 8 * 1024 * 1024) {
        throw ArgumentError('الحد الأقصى لحجم الصورة 8 ميجابايت.');
      }
      newPath = await _storage.uploadImage(
        companyId: widget.companyId!,
        appId: widget.appId!,
        fileName: fileName,
        bytes: bytes,
        contentType: mime,
        assetType: 'banner_ad',
      );
      final old = _forSlot(slot);
      await _repository.registerAsset(ErpAppAssetRecord(
        appId: widget.appId!,
        assetType: 'banner_ad',
        storagePath: newPath,
        displayName: slot,
        mimeType: mime,
        fileSizeBytes: bytes.length,
        altText: 'إعلان سلسلة - $slot',
      ));
      // The new image is registered first. Only then remove the previous slot image.
      if (old != null && old.id != null) {
        await _repository.deleteAssetRecord(assetId: old.id!);
        try {
          await _storage.deleteImage(
            companyId: widget.companyId!,
            appId: widget.appId!,
            storagePath: old.storagePath,
          );
        } catch (_) {
          // The new slot is already active; a stale old object is safe to clean up later.
        }
      }
      _urls.clear();
      if (!mounted) return;
      setState(() => _message = 'تم حفظ $slot بنجاح. سيظهر الإعلان في واجهة التطبيق بعد تحديث بياناته.');
      await _load();
    } catch (error) {
      if (newPath != null) {
        try {
          await _storage.deleteImage(companyId: widget.companyId!, appId: widget.appId!, storagePath: newPath);
        } catch (_) {}
      }
      if (mounted) setState(() => _error = 'تعذر حفظ $slot: $error');
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  String _mimeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      default: throw ArgumentError('الصيغ المدعومة JPG وPNG وWEBP وGIF فقط.');
    }
  }

  Future<void> _deleteSlot(String slot) async {
    final old = _forSlot(slot);
    if (old == null || old.id == null || _busySlot != null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف $slot'),
        content: const Text('هل تريد إزالة هذا الإعلان من واجهة التطبيق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No / لا')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes / نعم، احذف الإعلان'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() { _busySlot = slot; _error = null; _message = null; });
    try {
      await _repository.deleteAssetRecord(assetId: old.id!);
      await _storage.deleteImage(companyId: widget.companyId!, appId: widget.appId!, storagePath: old.storagePath);
      _urls.remove(old.storagePath);
      if (mounted) setState(() => _message = 'تم حذف $slot.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حذف الإعلان: $error');
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  Widget _notice(String value, Color color) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .35))),
    child: Text(value, style: TextStyle(color: color, height: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _adsPurple.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.view_carousel_outlined, color: _adsPurple),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إدارة إعلانات التطبيق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _adsPurple)),
            SizedBox(height: 4),
            Text('إدارة خمس صور إعلانية متتابعة؛ ينتقل التطبيق تلقائيًا كل ثانيتين.', style: TextStyle(color: Colors.black54, height: 1.4)),
          ])),
          IconButton(tooltip: 'تحديث الإعلانات', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('استخدم صورًا أفقية بنسبة 16:9 تقريبًا، مع كتابة واضحة بعيدًا عن الحواف. الصيغ المدعومة JPG وPNG وWEBP وGIF، وبحد أقصى 8 ميجابايت للصورة.', style: TextStyle(height: 1.6)),
          ),
        ),
        if (_message != null) _notice(_message!, Colors.green),
        if (_error != null) _notice(_error!, Colors.red),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else ..._adSlots.map((slot) {
          final asset = _forSlot(slot);
          final busy = _busySlot == slot;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(slot, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _adsPurple))),
                  Text(asset == null ? 'غير محدد' : 'محفوظ', style: TextStyle(color: asset == null ? Colors.black54 : Colors.green, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 16 / 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: asset == null
                        ? Container(color: const Color(0xFFF4EFF9), child: const Center(child: Icon(Icons.add_photo_alternate_outlined, color: _adsPurple, size: 42)))
                        : FutureBuilder<String>(
                            future: _signedUrl(asset.storagePath),
                            builder: (context, snap) => snap.hasData
                                ? Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))
                                : const Center(child: CircularProgressIndicator()),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: false),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('استيراد من الجهاز'),
                    style: FilledButton.styleFrom(backgroundColor: _adsPurple),
                  ),
                  OutlinedButton.icon(
                    onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('تصوير بالكاميرا'),
                  ),
                  if (asset != null)
                    TextButton.icon(
                      onPressed: _busySlot != null ? null : () => _deleteSlot(slot),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('حذف الإعلان', style: TextStyle(color: Colors.red)),
                    ),
                  if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
              ]),
            ),
          );
        }),
      ],
    );
  }
}
