import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/activity_service.dart';

const _tickerPurple = Color(0xFF3E007D);


class _TickerAdsPreview extends StatefulWidget {
  const _TickerAdsPreview({required this.brands});

  final List<Map<String, dynamic>> brands;

  @override
  State<_TickerAdsPreview> createState() => _TickerAdsPreviewState();
}

class _TickerAdsPreviewState extends State<_TickerAdsPreview> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _autoScroll = true;
  double _speed = 0.55;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 24), (_) {
      if (!_autoScroll || !mounted || !_scrollController.hasClients ||
          widget.brands.length < 2) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;
      final next = position.pixels + _speed;
      _scrollController.jumpTo(next >= position.maxScrollExtent ? 0 : next);
    });
  }

  @override
  void didUpdateWidget(covariant _TickerAdsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brands.length != widget.brands.length &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Uint8List? _bytes(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final hex = raw.startsWith(r'\x') ? raw.substring(2) : raw;
    if (hex.isEmpty || hex.length.isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        hex.length ~/ 2,
        (index) => int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
      ));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4D9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
              child: Text('معاينة تفاعلية لشريط البراندات',
                style: TextStyle(color: _tickerPurple, fontWeight: FontWeight.w900)),
            ),
            const Text('تمرير تلقائي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Switch.adaptive(
              value: _autoScroll,
              activeColor: _tickerPurple,
              onChanged: (value) => setState(() => _autoScroll = value),
            ),
          ]),
          Row(children: [
            const Text('السرعة', style: TextStyle(fontSize: 11, color: _tickerPurple, fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                value: _speed,
                min: 0.2,
                max: 2.0,
                divisions: 18,
                activeColor: _tickerPurple,
                onChanged: (value) => setState(() => _speed = value),
              ),
            ),
            SizedBox(width: 34, child: Text(_speed.toStringAsFixed(1), textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const Text(
            'اسحب للتحريك في أي اتجاه، واستخدم إصبعين للتكبير والتصغير. السحب اليدوي يوقف التمرير التلقائي حتى تعيد تشغيله.',
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: widget.brands.isEmpty
                  ? const Center(child: Text('لا توجد براندات نشطة للمعاينة.'))
                  : InteractiveViewer(
                      constrained: false,
                      panEnabled: true,
                      scaleEnabled: true,
                      panAxis: PanAxis.free,
                      minScale: 0.65,
                      maxScale: 2.5,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width - 64,
                        height: 94,
                        child: NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (notification.direction != ScrollDirection.idle && _autoScroll) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _autoScroll = false);
                              });
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: widget.brands.length,
                            itemBuilder: (context, index) {
                              final brand = widget.brands[index];
                              final bytes = _bytes(brand['logo_data']);
                              final name = (brand['brand_name'] ?? '').toString();
                              return SizedBox(
                                width: 78,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: SweepGradient(colors: [
                                          Color(0xFFFFA015), Color(0xFFFF27C3),
                                          _tickerPurple, Color(0xFFFFA015),
                                        ]),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                        clipBehavior: Clip.antiAlias,
                                        child: bytes == null
                                            ? const Icon(Icons.storefront_outlined, color: _tickerPurple, size: 27)
                                            : Image.memory(bytes, fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined, color: _tickerPurple)),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    SizedBox(width: 74, child: Text(name, maxLines: 1,
                                      overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 9, color: _tickerPurple, fontWeight: FontWeight.w700))),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ErpAppTickerAdsTab extends StatefulWidget {
  const ErpAppTickerAdsTab({
    super.key,
    required this.companyId,
    required this.appId,
  });

  final String? companyId;
  final String? appId;

  @override
  State<ErpAppTickerAdsTab> createState() => _ErpAppTickerAdsTabState();
}

class _ErpAppTickerAdsTabState extends State<ErpAppTickerAdsTab> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, String>> _activities = [];
  final Map<int, String> _slotOwners = {};
  String _activityCode = 'ALL';
  bool _loading = false;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  String? _error;
  String? _message;

  SupabaseClient get _db => Supabase.instance.client;
  int get _slotCount {
    final lastAssigned = _slotOwners.keys.fold<int>(
      0, (current, slot) => slot > current ? slot : current,
    );
    return _brands.length > lastAssigned ? _brands.length : lastAssigned;
  }

  String _s(dynamic value) => (value ?? '').toString();

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
  void didUpdateWidget(covariant ErpAppTickerAdsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.appId != widget.appId) {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    try {
      final rows = await ActivityService().getActivities();
      if (!mounted) return;
      setState(() {
        _activities = rows.map((row) => <String, String>{
          'code': _s(row['code']),
          'name': _s(row['name']),
        }).where((row) =>
          row['code']!.isNotEmpty && row['name']!.isNotEmpty).toList();
      });
    } catch (_) {
      // Global scope remains usable if the activity catalogue is unavailable.
    }
  }

  Future<void> _load() async {
    if (!_ready) {
      if (mounted) setState(() => _error =
          'اختر شركة نشطة واحفظ سجل تطبيق سلسلة أولًا من إدارة التطبيقات.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final brandRowsResult = await _db.from('erp_brands')
          .select('id,brand_code,brand_name,brand_name_en,logo_data,logo_mime_type,is_active,activity_code')
          .eq('company_id', widget.companyId!.trim())
          .eq('is_active', true)
          .eq('is_system', false)
          .order('display_order')
          .order('brand_code');
      final brandRows = List<Map<String, dynamic>>.from(brandRowsResult);
      // Brand-to-activity ownership is explicit on the brand master.
      // The global scope remains company-wide.
      if (_activityCode != 'ALL') {
        brandRows.removeWhere(
          (brand) => _s(brand['activity_code']) != _activityCode,
        );
      }
      var query = _db.from('erp_app_ticker_ads')
          .select('slot_no,brand_id')
          .eq('app_id', widget.appId!);
      query = _activityCode == 'ALL'
          ? query.isFilter('activity_code', null)
          : query.eq('activity_code', _activityCode);
      final assignedRows = await query.order('slot_no');
      if (!mounted) return;
      final activeBrandIds = List<Map<String, dynamic>>.from(brandRows)
          .map((brand) => _s(brand['id']))
          .toSet();
      final validAssignments = (assignedRows as List)
          .where((row) => activeBrandIds.contains(_s(row['brand_id'])))
          .toList();
      final nextOwners = <int, String>{
        for (final row in validAssignments)
          (row['slot_no'] as num).toInt(): _s(row['brand_id']),
      };
      final assignedBrandIds = nextOwners.values.toSet();
      var nextSlot = nextOwners.keys.isEmpty
          ? 1
          : nextOwners.keys.reduce((a, b) => a > b ? a : b) + 1;
      // Append all remaining active brands in the selected activity scope
      // without changing the user's existing manually assigned positions.
      for (final brand in List<Map<String, dynamic>>.from(brandRows)) {
        final brandId = _s(brand['id']);
        if (assignedBrandIds.add(brandId)) {
          nextOwners[nextSlot++] = brandId;
        }
      }
      setState(() {
        _brands = List<Map<String, dynamic>>.from(brandRows);
        _slotOwners
          ..clear()
          ..addAll(nextOwners);
        _hasUnsavedChanges = nextOwners.length != validAssignments.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل البراندات أو توزيع شريط التمرير. تأكد من تطبيق تحديث قاعدة البيانات: $error';
      });
    }
  }

  List<Map<String, dynamic>> get _visibleBrands {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return _brands;
    return _brands.where((brand) =>
      _s(brand['brand_name']).toLowerCase().contains(term) ||
      _s(brand['brand_name_en']).toLowerCase().contains(term) ||
      _s(brand['brand_code']).toLowerCase().contains(term)
    ).toList();
  }

  Uint8List? _logoBytes(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final hex = raw.startsWith(r'\x') ? raw.substring(2) : raw;
    if (hex.isEmpty || hex.length.isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        hex.length ~/ 2,
        (index) => int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
      ));
    } catch (_) {
      return null;
    }
  }

  void _showConflict(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.deepOrange,
    ));
  }

  void _toggleSlot(String brandId, int slot, bool checked) {
    final owner = _slotOwners[slot];
    if (checked && owner != null && owner != brandId) {
      final other = _brands.where((b) => _s(b['id']) == owner);
      final otherName = other.isEmpty ? 'براند آخر' : _s(other.first['brand_name']);
      _showConflict('الخانة رقم $slot مخصصة بالفعل لـ $otherName. ألغِ تحديدها أولًا.');
      return;
    }
    setState(() {
      if (checked) {
        _slotOwners[slot] = brandId;
      } else if (owner == brandId) {
        _slotOwners.remove(slot);
      }
      _message = null;
      _hasUnsavedChanges = true;
    });
  }

  void _toggleAll(String brandId, bool checked) {
    final conflicts = <int>[];
    for (var slot = 1; slot <= _slotCount; slot++) {
      final owner = _slotOwners[slot];
      if (checked && owner != null && owner != brandId) conflicts.add(slot);
    }
    if (conflicts.isNotEmpty) {
      _showConflict('الخانات ${conflicts.join('، ')} مستخدمة لبراندات أخرى. ألغِ تحديدها أولًا.');
      return;
    }
    setState(() {
      for (var slot = 1; slot <= _slotCount; slot++) {
        if (checked) {
          _slotOwners[slot] = brandId;
        } else if (_slotOwners[slot] == brandId) {
          _slotOwners.remove(slot);
        }
      }
      _message = null;
      _hasUnsavedChanges = true;
    });
  }

  Future<bool> _confirmPendingChanges() async {
    if (!_hasUnsavedChanges) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديلات غير محفوظة'),
        content: const Text('هل ترغب في الحفظ؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'cancel'), child: const Text('إلغاء الأمر')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'discard'), child: const Text('لأ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'save'), child: const Text('نعم')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return false;
    if (choice == 'save') {
      await _save();
      return mounted && _error == null && !_hasUnsavedChanges;
    }
    return choice == 'discard';
  }

  Future<void> _refresh() async {
    if (!await _confirmPendingChanges()) return;
    await _load();
  }

  Future<void> _changeActivity(String nextCode) async {
    if (nextCode == _activityCode || !await _confirmPendingChanges()) return;
    if (!mounted) return;
    setState(() {
      _activityCode = nextCode;
      _slotOwners.clear();
      _hasUnsavedChanges = false;
    });
    await _load();
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final assignments = _slotOwners.entries
          .map((entry) => <String, Object>{
            'slot_no': entry.key,
            'brand_id': entry.value,
          }).toList()
        ..sort((a, b) => (a['slot_no'] as int).compareTo(b['slot_no'] as int));
      final count = await _db.rpc('erp_save_app_ticker_ads', params: {
        'p_app_id': widget.appId,
        'p_activity_code': _activityCode == 'ALL' ? null : _activityCode,
        'p_assignments': assignments,
      });
      if (!mounted) return;
      setState(() => _message = 'تم حفظ توزيع ${count ?? assignments.length} موضعًا إعلانيًا بنجاح.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ توزيع شريط التمرير: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _brandLogo(Map<String, dynamic> brand) {
    final bytes = _logoBytes(brand['logo_data']);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFFB),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5DDEE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? const Icon(Icons.storefront_outlined, color: _tickerPurple)
          : Image.memory(bytes, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, color: _tickerPurple)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brands = _visibleBrands;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: [
              const Icon(Icons.view_carousel_outlined, color: _tickerPurple),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'إعلانات شريط التمرير',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _tickerPurple),
              )),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading || _saving ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: _activityCode,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'نطاق الإعلانات حسب النشاط',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('كل الأنشطة (إعلان عام)'),
                ),
                ..._activities.map((activity) => DropdownMenuItem(
                  value: activity['code'],
                  child: Text('${activity['name']} — ${activity['code']}'),
                )),
              ],
              onChanged: _loading || _saving ? null : (value) =>
                  _changeActivity(value ?? 'ALL'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ابحث باسم البراند العربي أو الإنجليزي أو كوده',
                prefixIcon: Icon(Icons.search, color: _tickerPurple),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'حدد مواضع كل براند من 1 إلى $_slotCount. لا يمكن تخصيص الموضع نفسه لأكثر من براند في النطاق الواحد. المواضع غير المحددة في النشاط تستكمل من إعدادات كل الأنشطة.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
          _TickerAdsPreview(brands: _brands),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_message!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : brands.isEmpty
                    ? const Center(child: Text('لا توجد براندات مطابقة للبحث.'))
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                            columnSpacing: 2.5,
                            horizontalMargin: 2.5,
                            headingRowHeight: 40,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 44,
                            columns: [
                              const DataColumn(label: Text('م')),
                              const DataColumn(label: Text('كود البراند')),
                              const DataColumn(label: Text('الصورة')),
                              const DataColumn(label: Text('اسم البراند')),
                              const DataColumn(label: Text('الكل')),
                              ...List.generate(_slotCount, (index) => DataColumn(
                                label: Text('${index + 1}'),
                              )),
                            ],
                            rows: brands.asMap().entries.map((entry) {
                              final rowIndex = entry.key + 1;
                              final brand = entry.value;
                              final id = _s(brand['id']);
                              final selectedCount = _slotOwners.values.where((owner) => owner == id).length;
                              return DataRow(cells: [
                                DataCell(SizedBox(width: 24, child: Text('$rowIndex', textAlign: TextAlign.center))),
                                DataCell(SizedBox(width: 66, child: Text(_s(brand['brand_code']), maxLines: 1, overflow: TextOverflow.ellipsis))),
                                DataCell(SizedBox(width: 40, height: 40, child: _brandLogo(brand))),
                                DataCell(SizedBox(width: 150, child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_s(brand['brand_name']), maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                    if (_s(brand['brand_name_en']).trim().isNotEmpty)
                                      Text(_s(brand['brand_name_en']), maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ))),
                                DataCell(SizedBox(width: 28, child: Checkbox(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: const CircleBorder(),
                                  value: selectedCount == 0 ? false : (_slotCount > 0 && selectedCount == _slotCount) ? true : null,
                                  tristate: true,
                                  onChanged: _saving ? null : (value) => _toggleAll(id, value == true),
                                ))),
                                ...List.generate(_slotCount, (index) {
                                  final slot = index + 1;
                                  return DataCell(SizedBox(width: 28, child: Checkbox(
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: const CircleBorder(),
                                    value: _slotOwners[slot] == id,
                                    onChanged: _saving ? null : (value) =>
                                      _toggleSlot(id, slot, value == true),
                                  )));
                                }),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text('المواضع المحددة: ${_slotOwners.length}/$_slotCount',
                style: const TextStyle(color: _tickerPurple, fontWeight: FontWeight.w900)),
              const Spacer(),
              FilledButton.icon(
                onPressed: !_ready || _saving || _loading ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ التوزيع'),
                style: FilledButton.styleFrom(backgroundColor: _tickerPurple),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
