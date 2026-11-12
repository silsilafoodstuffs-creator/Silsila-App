import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/erp_app_asset_storage.dart';
import '../../services/activity_service.dart';
import '../services/erp_app_management_service.dart';
import '../services/erp_app_settings.dart';
import 'erp_app_ticker_ads_tab.dart';
import '../widgets/erp_quick_task_button.dart';

const _adsPurple = Color(0xFF3E007D);
const _adsOrange = Color(0xFFFFA015);
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
  bool _editMode = false;
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
        if (camera) {
          final picked = await _picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 15),
          );
          if (picked == null) return;
          fileName = picked.name;
          bytes = await picked.readAsBytes();
        } else {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.video,
            allowMultiple: false,
            withData: true,
          );
          if (result == null || result.files.isEmpty) return;
          final picked = result.files.single;
          if (picked.bytes == null || picked.bytes!.isEmpty) {
            throw StateError('تعذر قراءة الفيديو؛ اختر الملف مرة أخرى.');
          }
          fileName = picked.name;
          bytes = picked.bytes!;
        }
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
        targetType: _targetTypes[_keyFor(slot, _scopeCode)] ?? 'none',
        targetCode: (_targetCodes[_keyFor(slot, _scopeCode)] ?? '').trim().isEmpty ? null : _targetCodes[_keyFor(slot, _scopeCode)]!.trim(),
        durationSeconds: _durations[_keyFor(slot, _scopeCode)] ?? (slot == _introSlot ? 4 : slot == _popupSlot ? 5 : 2),
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

  Future<void> _saveAllMetadata() async {
    if (_busySlot != null || !_editMode) return;
    setState(() { _busySlot = 'all'; _error = null; _message = null; });
    try {
      for (final slot in _adSlots) {
        final localAsset = _forSlot(slot);
        final sourceAsset = localAsset ?? _effectiveSlot(slot);
        if (sourceAsset == null) continue;
        final key = _keyFor(slot, _scopeCode);
        final type = _targetTypes[key] ?? sourceAsset.targetType;
        final code = (_targetCodes[key] ?? sourceAsset.targetCode ?? '').trim();
        if (type != 'none' && code.isEmpty) {
          throw ArgumentError('اكتب كود الوجهة لإعلان «$slot» قبل الحفظ.');
        }
        final updated = ErpAppAssetRecord(
          id: localAsset?.id, appId: sourceAsset.appId, assetType: sourceAsset.assetType,
          storagePath: sourceAsset.storagePath, displayName: slot,
          entityId: sourceAsset.entityId, mimeType: sourceAsset.mimeType,
          fileSizeBytes: sourceAsset.fileSizeBytes, altText: sourceAsset.altText,
          targetType: type, targetCode: type == 'none' ? null : code,
          durationSeconds: _durations[key] ?? sourceAsset.durationSeconds,
          activityCode: _scopeCode,
        );
        if (localAsset?.id != null) {
          await _repository.updateAssetRecord(assetId: localAsset!.id!, asset: updated);
        } else if (_scopeCode != null) {
          await _repository.registerAsset(updated);
        }
      }
      if (mounted) setState(() { _message = 'تم حفظ إعدادات الإعلانات بنجاح.'; _editMode = false; });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ إعدادات الإعلانات: $error');
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  Future<void> _deleteSlot(String slot) async {
    final old = _forSlot(slot);
    if (old == null || old.id == null || _busySlot != null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حذف $slot'),
          content: const Text('هل ترغب في حذف هذا الإعلان؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('إلغاء الأمر')),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('نعم')),
          ],
        ),
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              labelColor: _adsPurple,
              unselectedLabelColor: Colors.black54,
              indicatorColor: _adsOrange,
              tabs: const [
                Tab(text: 'بوسترات التمرير', icon: Icon(Icons.view_carousel_outlined, size: 18)),
                Tab(text: 'شريط التمرير', icon: Icon(Icons.horizontal_distribute_outlined, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(child: _buildPosterTab()),
                ErpAppTickerAdsTab(companyId: widget.companyId, appId: widget.appId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Icon(Icons.view_carousel_outlined, color: _adsPurple, size: 20),
          const SizedBox(width: 6),
          const Expanded(child: Text('إدارة إعلانات التطبيق',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _adsPurple))),
        ]),
        const SizedBox(height: 3),
        Wrap(spacing: 2.5, runSpacing: 2.5, children: [
          ErpQuickTaskButton(label: 'تحديث', icon: Icons.refresh, compact: true,
            onPressed: _loading || _busySlot != null ? null : _load),
          ErpQuickTaskButton(label: 'تعديل', icon: Icons.edit_outlined, compact: true,
            onPressed: _busySlot != null || _loading ? null : () => setState(() => _editMode = !_editMode)),
          ErpQuickTaskButton(label: 'حفظ', icon: Icons.save_outlined, compact: true,
            onPressed: !_editMode || _busySlot != null || _loading ? null : _saveAllMetadata),
        ]),
        const SizedBox(height: 5),
        SizedBox(height: 40, child: DropdownButtonFormField<String>(itemHeight: 40, 
          value: _selectedActivityCode,
          decoration: const InputDecoration(labelText: 'نطاق عرض الإعلانات حسب النشاط', border: OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
          items: [
            const DropdownMenuItem(value: _allActivities, child: Text('كل الأنشطة (الإعلانات العامة)')),
            ..._activities.map((a) => DropdownMenuItem(value: a['code'], child: Text('${a['name']} — ${a['code']}'))),
          ],
          onChanged: _loading || _busySlot != null ? null : (value) {
            setState(() { _selectedActivityCode = value ?? _allActivities; _message = null; _error = null; });
            _load();
          },
        )),
        const SizedBox(height: 5),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_isGlobalScope
              ? 'هذه الإعلانات عامة لكل الأنشطة. عند اختيار نشاط محدد يمكنك رفع إعلانات خاصة به؛ وتكون له الأولوية، ثم تُستكمل إعلانات الهيدر الناقصة من أول إعلانات النطاق العام. إعلان البداية الخاص بالنشاط يتقدم على إعلان البداية العام.'
              : 'هذه الإعلانات مخصصة للنشاط المحدد. ما ترفعه هنا يتقدم على الإعلان العام، وأي خانات هيدر غير محددة ستُستكمل تلقائيًا من الإعلانات العامة. إعلان البداية أيضًا له أولوية النشاط ثم العام.',
              style: const TextStyle(height: 1.6)),
          ),
        ),
        if (_message != null) _notice(_message!, Colors.green),
        if (_error != null) _notice(_error!, Colors.red),
        const SizedBox(height: 5),
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
            margin: const EdgeInsets.only(bottom: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 150,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AspectRatio(
                      aspectRatio: 16 / 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: effectiveAsset == null
                          ? Material(color: const Color(0xFFF4EFF9), child: InkWell(
                              onTap: () => launchUrl(Uri.parse('https://wa.me/201019617100'), mode: LaunchMode.externalApplication),
                              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Image.asset('assets/images/silsila_logo.png', width: 42, height: 20, fit: BoxFit.contain),
                                const Text('ضع إعلانك هنا', style: TextStyle(color: _adsPurple, fontWeight: FontWeight.w900, fontSize: 10)),
                                const Text('01019617100', style: TextStyle(color: _adsPurple, fontSize: 9)),
                                const Text('واتساب سلسلة', style: TextStyle(color: _adsPurple, fontSize: 9)),
                              ])),
                            ))
                          : effectiveAsset.mimeType == 'video/mp4'
                            ? Container(color: const Color(0xFFF4EFF9), child: const Center(child: Icon(Icons.play_circle_outline, color: _adsPurple, size: 28)))
                            : FutureBuilder<String>(
                                future: _signedUrl(effectiveAsset.storagePath),
                                builder: (context, snap) => snap.hasData
                                  ? Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))
                                  : const Center(child: CircularProgressIndicator()),
                              ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(slot, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _adsPurple)),
                    Text(asset != null ? 'محفوظ' : inherited ? 'موروث' : 'غير محدد',
                      style: TextStyle(fontSize: 9, color: asset != null ? Colors.green : inherited ? _adsOrange : Colors.black54)),
                  ]),
                ),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Wrap(spacing: 4, runSpacing: 3, children: [
                    OutlinedButton.icon(
                      onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: false),
                      icon: const Icon(Icons.folder_open_outlined, size: 15),
                      label: const Text('من الجهاز'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: true),
                      icon: const Icon(Icons.photo_camera_outlined, size: 15),
                      label: const Text('كاميرا'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
                    ),
                    if (slot == _introSlot)
                      OutlinedButton.icon(
                        onPressed: !_ready || _busySlot != null ? null : () => _chooseImage(slot, camera: false, video: true),
                        icon: const Icon(Icons.video_library_outlined, size: 15),
                        label: const Text('فيديو'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  SizedBox(height: 38, child: DropdownButtonFormField<String>(
                    value: targetType,
                    itemHeight: 40,
                    decoration: const InputDecoration(labelText: 'التوجه عند الضغط', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('بدون توجيه')),
                      DropdownMenuItem(value: 'category', child: Text('فتح فئة أصناف')),
                      DropdownMenuItem(value: 'supplier', child: Text('فتح مورد')),
                    ],
                    onChanged: !_editMode || _busySlot != null ? null : (value) => setState(() => _targetTypes[key] = value ?? 'none'),
                  )),
                  if (targetType != 'none') ...[
                    const SizedBox(height: 3),
                    SizedBox(height: 38, child: TextFormField(
                      key: ValueKey('target-code-$key'),
                      initialValue: _targetCodes[key] ?? asset?.targetCode ?? '',
                      decoration: const InputDecoration(labelText: 'كود الوجهة', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
                      enabled: _editMode,
                      onChanged: (value) => _targetCodes[key] = value,
                    )),
                  ],
                  if (slot == _popupSlot || slot == _introSlot) ...[
                    const SizedBox(height: 3),
                    SizedBox(height: 38, child: TextFormField(
                      key: ValueKey('duration-$key'),
                      initialValue: (_durations[key] ?? asset?.durationSeconds ?? (slot == _introSlot ? 4 : 5)).toString(),
                      keyboardType: TextInputType.number,
                      enabled: _editMode,
                      decoration: InputDecoration(labelText: slot == _introSlot ? 'مدة البداية بالثواني' : 'مدة المنبثق بالثواني', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
                      onChanged: (value) => _durations[key] = int.tryParse(value) ?? 5,
                    )),
                  ],
                  Row(children: [
                    Expanded(child: Text(_editMode ? 'وضع التعديل نشط' : 'فعّل تعديل من الهيدر لتغيير الإعدادات',
                      style: const TextStyle(fontSize: 10, color: Colors.black54))),
                    if (asset != null)
                      TextButton.icon(
                        onPressed: _busySlot != null ? null : () => _deleteSlot(slot),
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        label: const Text('حذف الإعلان', style: TextStyle(color: Colors.red, fontSize: 11)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 5)),
                      ),
                    if (busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                ])),
              ]),
            ),
          );
        }),
      ],
    );
  }
}
