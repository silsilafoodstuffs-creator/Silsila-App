import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpImageCollectorScreen extends StatefulWidget {
  const ErpImageCollectorScreen({super.key});

  @override
  State<ErpImageCollectorScreen> createState() => _ErpImageCollectorScreenState();
}

class _ErpImageCollectorScreenState extends State<ErpImageCollectorScreen> {
  static const _purple = Color(0xFF3E007D);
  static const _orange = Color(0xFFFFA015);
  final _url = TextEditingController();
  final Set<String> _selected = {};
  List<Map<String, dynamic>> _images = [];
  bool _loading = false;
  String? _pageUrl;
  String? _error;
  String _status = '';

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'silsila-image-collector',
      body: body,
    );
    final data = response.data;
    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      if (response.status >= 400 || result['error'] != null) {
        throw Exception(result['error']?.toString() ?? 'تعذر تنفيذ الطلب.');
      }
      return result;
    }
    throw Exception('استجابة غير مفهومة من خدمة جمع الصور.');
  }

  Future<void> _scan() async {
    final raw = _url.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'اكتب رابط صفحة المنتجات أولًا.');
      return;
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasScheme || !['http', 'https'].contains(parsed.scheme)) {
      setState(() => _error = 'أدخل رابطًا صحيحًا يبدأ بـ https:// أو http://');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ فحص الصفحة واستخراج الصور المتاحة...';
      _selected.clear();
      _images = [];
    });
    try {
      final result = await _invoke({'action': 'scan', 'url': parsed.toString()});
      final rawImages = (result['images'] as List? ?? const []);
      final images = rawImages.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
      if (!mounted) return;
      setState(() {
        _pageUrl = result['page']?.toString() ?? parsed.toString();
        _images = images;
        _status = images.isEmpty
            ? 'لم يتم العثور على صور ظاهرة في HTML. قد تكون الصفحة تعتمد على JavaScript أو تمنع الوصول.'
            : 'تم العثور على ${images.length} صورة مرشحة. راجعها وحدد الصور المطلوبة.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String url, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(url);
      } else {
        _selected.remove(url);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _images.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_images.map((x) => x['url'].toString()));
      }
    });
  }

  String _safeName(String value, {String fallback = 'image'}) {
    var name = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF_-]+'), '_');
    name = name.replaceAll(RegExp(r'_+'), '_');
    if (name.length > 70) name = name.substring(0, 70);
    return name.isEmpty ? fallback : name;
  }

  String _extension(String mime, String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif']) {
      if (path.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return switch (mime.toLowerCase()) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      'image/avif' => '.avif',
      _ => '.jpg',
    };
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final result = await _invoke({'action': 'download', 'url': url});
    final encoded = result['base64']?.toString();
    if (encoded == null || encoded.isEmpty) throw Exception('لم تصل بيانات الصورة.');
    return Uint8List.fromList(base64Decode(encoded));
  }

  Future<void> _saveZip() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'حدد صورة واحدة على الأقل قبل التنزيل.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ تنزيل الصور المحددة وتجهيز ملف ZIP...';
    });
    try {
      final archive = Archive();
      var index = 0;
      for (final image in _images.where((x) => _selected.contains(x['url'].toString()))) {
        index++;
        final url = image['url'].toString();
        final downloaded = await _invoke({'action': 'download', 'url': url});
        final encoded = downloaded['base64']?.toString();
        if (encoded == null || encoded.isEmpty) continue;
        final bytes = base64Decode(encoded);
        final title = _safeName((image['alt'] ?? '').toString(), fallback: 'image_${index.toString().padLeft(3, '0')}');
        final ext = _extension(downloaded['mime']?.toString() ?? '', url);
        archive.addFile(ArchiveFile('$title${ext}', bytes.length, bytes));
        if (mounted) setState(() => _status = 'تم تجهيز $index من ${_selected.length} صورة...');
      }
      if (archive.isEmpty) throw Exception('لم يمكن تنزيل أي صورة من الاختيارات.');
      final zipped = ZipEncoder().encode(archive);
      if (zipped == null || zipped.isEmpty) throw Exception('تعذر إنشاء ملف ZIP.');
      await FileSaver.instance.saveFile(
        name: 'silsila_images_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(zipped),
        ext: 'zip',
        mimeType: MimeType.zip,
      );
      if (mounted) setState(() => _status = 'تم تجهيز ملف ZIP للصور المختارة.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveOne(Map<String, dynamic> image) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _status = 'جارٍ تنزيل الصورة...';
    });
    try {
      final url = image['url'].toString();
      final result = await _invoke({'action': 'download', 'url': url});
      final encoded = result['base64']?.toString();
      if (encoded == null || encoded.isEmpty) throw Exception('لم تصل بيانات الصورة.');
      final bytes = Uint8List.fromList(base64Decode(encoded));
      final ext = _extension(result['mime']?.toString() ?? '', url);
      await FileSaver.instance.saveFile(
        name: _safeName((image['alt'] ?? '').toString(), fallback: 'silsila_image'),
        bytes: bytes,
        ext: ext.replaceFirst('.', ''),
        mimeType: switch (result['mime']?.toString()) {
          'image/png' => MimeType.png,
          'image/webp' => MimeType.webp,
          _ => MimeType.jpeg,
        },
      );
      if (mounted) setState(() => _status = 'تم إرسال الصورة إلى التنزيلات.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _images.isNotEmpty && _selected.length == _images.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _purple.withValues(alpha: .12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: _purple.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.photo_library_outlined, color: _purple, size: 27),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('جامع صور الأصناف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _purple)),
                    SizedBox(height: 4),
                    Text('استخراج الصور المتاحة من صفحة عامة ثم تحديدها وتنزيلها', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                ]),
                const SizedBox(height: 18),
                const Text('رابط صفحة المنتجات', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _loading ? null : _scan(),
                  decoration: InputDecoration(
                    hintText: 'https://www.example.com/products',
                    prefixIcon: const Icon(Icons.link),
                    filled: true,
                    fillColor: const Color(0xFFF8F5FB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _scan,
                    icon: _loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.travel_explore),
                    label: const Text('تنفيذ وسحب الصور'),
                    style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _images.isEmpty ? null : _selectAll,
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading || _selected.isEmpty ? null : _saveZip,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: Text('تنزيل ZIP (${_selected.length})'),
                    style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
                  ),
                ]),
                if (_pageUrl != null) ...[
                  const SizedBox(height: 10),
                  Text('المصدر: $_pageUrl', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_status, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: .07), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'ملاحظة: بعض المواقع تعرض الصور بواسطة JavaScript أو تمنع الطلبات الآلية؛ في هذه الحالة قد لا تظهر كل الصور. استخدم الصور وفق حقوق الموقع.',
                  style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.5),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: Text('الصور المستخرجة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            Text('${_images.length} صورة • محدد ${_selected.length}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          const SizedBox(height: 10),
          if (_images.isEmpty)
            Expanded(
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.image_search_outlined, size: 54, color: _purple.withValues(alpha: .35)),
                const SizedBox(height: 10),
                const Text('ضع رابط صفحة ثم اضغط «تنفيذ وسحب الصور»', style: TextStyle(color: Colors.black54)),
              ])),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 18),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 205,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .76,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final item = _images[index];
                  final imageUrl = item['url'].toString();
                  final selected = _selected.contains(imageUrl);
                  final alt = (item['alt'] ?? '').toString();
                  return InkWell(
                    onTap: () => _toggle(imageUrl, !selected),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: selected ? _purple : const Color(0xFFE7E0EE), width: selected ? 2 : 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(
                          child: Stack(fit: StackFit.expand, children: [
                            Container(color: const Color(0xFFF7F4F9), alignment: Alignment.center,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 42, color: Colors.black26),
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                            Positioned(
                              top: 6, right: 6,
                              child: Container(
                                decoration: BoxDecoration(color: selected ? _purple : Colors.white.withValues(alpha: .95), shape: BoxShape.circle),
                                child: Checkbox(
                                  value: selected,
                                  onChanged: (v) => _toggle(imageUrl, v),
                                  activeColor: _purple,
                                  side: BorderSide(color: selected ? _purple : Colors.black38),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(alt.isEmpty ? 'صورة ${index + 1}' : alt, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _loading ? null : () => _saveOne(item),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('تنزيل', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30)),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
