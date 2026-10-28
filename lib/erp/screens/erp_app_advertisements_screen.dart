import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/erp_app_asset_storage.dart';
import '../../services/activity_service.dart';
import '../services/erp_app_management_service.dart';
import '../services/erp_app_settings.dart';

const _adsPurple = Color(0xFF3E007D);
const _bannerSlots = <String>['إعلان 1', 'إعلان 2', 'إعلان 3', 'إعلان 4', 'إعلان 5'];
const _popupSlot = 'إعلان منبثق';
const _introSlot = 'إعلان البداية';
const _allActivities = 'ALL';

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
  String _selectedActivityCode = _allActivities;
  List<Map<String, String>> _activities = const [];
  final Map<String, String> _targetTypes = {};
  final Map<String, String> _targetCodes = {};
  final Map<String, int> _durations = {};

  List<String> get _adSlots => [..._bannerSlots, _popupSlot, _introSlot];

  String _assetTypeForSlot(String slot) => _bannerSlots.contains(slot)
      ? 'banner_ad' : slot == _popupSlot ? 'popup_ad' : 'intro_ad';

  bool get _isGlobalScope => _selectedActivityCode == _allActivities;

  bool get _ready =>
      (widget.companyId ?? '').trim().isNotEmpty &&
      (widget.appId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadActivities();
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

  Future<void> _loadActivities() async {
    final rows = await ActivityService().getActivities();
    if (!mounted) return;
    setState(() {
      _activities = rows.map((row) => <String, String>{
        'code': row['code']?.toString() ?? '',
        'name': row['name']?.toString() ?? '',
      }).where((row) => row['code']!.isNotEmpty && row['name']!.isNotEmpty).toList();
      if (_selectedActivityCode != _allActivities && !_activities.any((a) => a['code'] == _selectedActivityCode)) {
        _selectedActivityCode = _allActivities;
      }
    });
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
      final records = await _repository.listAssets(appId: widget.appId!, limit: 300);
      if (!mounted) return;
      setState(() {
        _assets = records.where((record) => record.assetType == 'banner_ad' || record.assetType == 'popup_ad' || record.assetType == 'intro_ad').toList();
        for (final record in records) {
          final key = _keyFor(record.displayName, record.activityCode);
          _targetTypes[key] = record.targetType;
          _targetCodes[key] = record.targetCode ?? '';
          _durations[key] = record.durationSeconds;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الإعلانات. تأكد من تطبيق تحديث قاعدة البيانات وصلاحيات التخزين: $error';
      });
    }
  }

  String? get _scopeCode => _isGlobalScope ? null : _selectedActivityCode;

  String _keyFor(String slot, String? activityCode) => '${activityCode ?? _allActivities}::$slot';

  ErpAppAssetRecord? _forSlot(String slot, {bool globalOnly = false}) {
    final wantedCode = globalOnly ? null : _scopeCode;
    for (final asset in _assets) {
      if (asset.displayName == slot && asset.activityCode == wantedCode) return asset;
    }
    return null;
  }

  ErpAppAssetRecord? _effectiveSlot(String slot) =>
      _forSlot(slot) ?? (_isGlobalScope ? null : _forSlot(slot, globalOnly: true));

  Future<String> _signedUrl(String path) {
    return _urls.putIfAbsent(path, () => _storage.createSignedImageUrl(storagePath: path));
  }

  Future<void> _chooseImage(String slot, {required bool camera, bool video = false}) async {
    if (!_ready || _busySlot != null) return;
    setState(() { _busySlot = slot; _error = null; _message = null; });
    String? newPath;
    try {
      String fileName;
      Uint8List bytes;
      String mime;
      if (video) {
        final picked = camera
            ? await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 15))
            : (await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false, withData: true))?.files.singleOrNull;
        if (picked == null) return;
        fileName = picked.name;
        bytes = await picked.readAsBytes();
        mime = 'video/mp4';
      } else if (camera) {
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
      if (video) {
        newPath = await _storage.uploadVideo(
          companyId: widget.companyId!, appId: widget.appId!, fileName: fileName,
          bytes: bytes, assetType: 'intro_ad',
        );
      } else {
        if (bytes.length > 8 * 1024 * 1024) {
          throw ArgumentError('الحد الأقصى لحجم الصورة 8 ميجابايت.');
        }
        newPath = await _storage.uploadImage(
        companyId: widget.companyId!,
        appId: widget.appId!,
        fileName: fileName,
        bytes: bytes,
        contentType: mime,
          assetType: _assetTypeForSlot(slot),
        );
      }
      final old = _forSlot(slot);
      await _repository.registerAsset(ErpAppAssetRecord(
        appId: widget.appId!,
        assetType: _assetTypeForSlot(slot),
        activityCode: _scopeCode,
        storagePath: newPath,
        displayName: slot,
        mimeType: mime,
        fileSizeBytes: bytes.length,
        altText: 'إعلان سلسلة - $slot',
        targetType: 'none',
        durationSeconds: slot == _introSlot ? 4 : slot == _popupSlot ? 5 : 2,
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
      case 'mp4': return 'video/mp4';
      default: throw ArgumentError('الصيغ المدعومة JPG وPNG وWEBP وGIF، وفيديو MP4 لإعلان البداية.');
    }
  }

  Future<void> _saveMetadata(String slot, ErpAppAssetRecord asset) async {
    if (asset.id == null || _busySlot != null) return;
    setState(() { _busySlot = slot; _error = null; _message = null; });
    try {
      final key = _keyFor(slot, asset.activityCode);
      final type = _targetTypes[key] ?? asset.targetType;
      final code = (_targetCodes[key] ?? asset.targetCode ?? '').trim();
      final duration = _durations[key] ?? asset.durationSeconds;
      if (type != 'none' && code.isEmpty) throw ArgumentError('اكتب كود الفئة أو المورد قبل الحفظ.');
      await _repository.updateAssetRecord(assetId: asset.id!, asset: ErpAppAssetRecord(
        id: asset.id, appId: asset.appId, assetType: asset.assetType,
        storagePath: asset.storagePath, displayName: asset.displayName,
        entityId: asset.entityId, mimeType: asset.mimeType,
        fileSizeBytes: asset.fileSizeBytes, altText: asset.altText,
        targetType: type, targetCode: type == 'none' ? null : code,
        durationSeconds: duration, activityCode: asset.activityCode,
      ));
      if (mounted) setState(() => _message = 'تم حفظ إعدادات $slot.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ إعدادات الإعلان: $error');
    } finally {
      if (mounted) setState(() => _busySlot = null);
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
            Text('إعلانات الهيدر والمنبثق والبداية، مع تخصيصها حسب النشاط أو جميع الأنشطة.', style: TextStyle(color: Colors.black54, height: 1.4)),
          ])),
          IconButton(tooltip: 'تحديث الإعلانات', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _selectedActivityCode,
          decoration: const InputDecoration(labelText: 'نطاق عرض الإعلانات حسب النشاط', border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: _allActivities, child: Text('كل الأنشطة (الإعلانات العامة)')),
            ..._activities.map((a) => DropdownMenuItem(value: a['code'], child: Text('${a['name']} — ${a['code']}'))),
          ],
          onChanged: _loading || _busySlot != null ? null : (value) {
            setState(() { _selectedActivityCode = value ?? _allActivities; _message = null; _error = null; });
            _load();
          },
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(_isGlobalScope
              ? 'هذه الإعلانات عامة لكل الأنشطة. عند اختيار نشاط محدد يمكنك رفع إعلانات خاصة به؛ وتكون له الأولوية، ثم تُستكمل إعلانات الهيدر الناقصة من أول إعلانات النطاق العام. إعلان البداية الخاص بالنشاط يتقدم على إعلان البداية العام.'
              : 'هذه الإعلانات مخصصة للنشاط المحدد. ما ترفعه هنا يتقدم على الإعلان العام، وأي خانات هيدر غير محددة ستُستكمل تلقائيًا من الإعلانات العامة. إعلان البداية أيضًا له أولوية النشاط ثم العام.',
              style: const TextStyle(height: 1.6)),
          ),
        ),
        if (_message != null) _notice(_message!, Colors.green),
        if (_error != null) _notice(_error!, Colors.red),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else ..._adSlots.map((slot) {
          final asset = _forSlot(slot);
          final effectiveAsset = asset ?? _effectiveSlot(slot);
          final inherited = asset == null && effectiveAsset != null;
          final key = _keyFor(slot, _scopeCode);
          final busy = _busySlot == slot;
          final targetType = _targetTypes[key] ?? asset?.targetType ?? 'none';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(slot, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _adsPurple))),
                  Text(asset != null ? 'محفوظ لهذا النشاط' : inherited ? 'موروث من كل الأنشطة' : 'غير محدد', style: TextStyle(color: asset != null ? Colors.green : inherited ? orange : Colors.black54, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 16 / 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: effectiveAsset == null
                        ? Container(color: const Color(0xFFF4EFF9), child: Center(child: Icon(slot == _introSlot ? Icons.movie_creation_outlined : Icons.add_photo_alternate_outlined, color: _adsPurple, size: 42)))
                        : effectiveAsset.mimeType == 'video/mp4'
                            ? Container(color: const Color(0xFFF4EFF9), child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_circle_outline, color: _adsPurple, size: 42), Text('فيديو MP4 محفوظ', style: TextStyle(color: _adsPurple))])))
                            : FutureBuilder<String>(
                                future: _signedUrl(effectiveAsset.storagePath),
                                builder: (context, snap) => snap.hasData
                                    ? Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))
                                    : const Center(child: CircularProgressIndicator()),
                              ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: targetType,
                  decoration: const InputDecoration(labelText: 'التوجه عند الضغط على الصورة', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('بدون توجيه')),
                    DropdownMenuItem(value: 'category', child: Text('فتح فئة أصناف')),
                    DropdownMenuItem(value: 'supplier', child: Text('فتح مورد')),
                  ],
                  onChanged: _busySlot != null ? null : (value) => setState(() => _targetTypes[slot] = value ?? 'none'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('target-code-$key'),
                  initialValue: _targetCodes[key] ?? asset?.targetCode ?? '',
                  decoration: InputDecoration(labelText: targetType == 'category' ? 'كود الفئة' : targetType == 'supplier' ? 'كود المورد / معرّف حساب المورد' : 'كود الوجهة (اختياري)', hintText: 'اختياري عند اختيار بدون توجيه', border: const OutlineInputBorder(), isDense: true),
                  onChanged: (value) => _targetCodes[key] = value,
                ),
                if (slot == _popupSlot || slot == _introSlot) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('duration-$key'),
                    initialValue: (_durations[key] ?? asset?.durationSeconds ?? (slot == _introSlot ? 4 : 5)).toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: slot == _introSlot ? 'مدة فيديو / صورة البداية بالثواني' : 'مدة ظهور الإعلان المنبثق بالثواني', border: const OutlineInputBorder(), isDense: true),
                    onChanged: (value) => _durations[key] = int.tryParse(value) ?? 5,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: false),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(slot == _introSlot ? 'صورة من الجهاز' : 'استيراد صورة من الجهاز'),
                    style: FilledButton.styleFrom(backgroundColor: _adsPurple),
                  ),
                  OutlinedButton.icon(
                    onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(slot == _introSlot ? 'تصوير صورة بالكاميرا' : 'تصوير بالكاميرا'),
                  ),
                  if (slot == _introSlot) ...[
                    FilledButton.icon(
                      onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: false, video: true),
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('فيديو من الجهاز (MP4)'),
                      style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: _adsPurple),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: true, video: true),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('تصوير فيديو بالكاميرا'),
                    ),
                  ],

                  if (asset != null)
                    OutlinedButton.icon(
                      onPressed: _busySlot != null ? null : () => _saveMetadata(slot, asset),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ إعدادات الإعلان'),
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
