import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/activity_service.dart';
import '../widgets/erp_quick_task_button.dart';

const _tickerPurple = Color(0xFF3E007D);

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
  bool _editMode = false;
  String? _error;
  String? _message;

  SupabaseClient get _db => Supabase.instance.client;
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
      final brandRows = await _db.from('erp_brands')
          .select('id,brand_code,brand_name,logo_data,logo_mime_type,is_active')
          .eq('company_id', widget.companyId!.trim())
          .eq('is_active', true)
          .order('display_order')
          .order('brand_code');
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
          .where((row) => activeBrandIds.contains(_s(row['brand_id'])));
      setState(() {
        _brands = List<Map<String, dynamic>>.from(brandRows);
        _slotOwners
          ..clear()
          ..addEntries(validAssignments.map((row) => MapEntry(
            (row['slot_no'] as num).toInt(), _s(row['brand_id']),
          )));
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
    if (!_editMode || _saving) return;
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
    });
  }

  void _toggleAll(String brandId, bool checked) {
    if (!_editMode || _saving) return;
    final conflicts = <int>[];
    for (var slot = 1; slot <= 25; slot++) {
      final owner = _slotOwners[slot];
      if (checked && owner != null && owner != brandId) conflicts.add(slot);
    }
    if (conflicts.isNotEmpty) {
      _showConflict('الخانات ${conflicts.join('، ')} مستخدمة لبراندات أخرى. ألغِ تحديدها أولًا.');
      return;
    }
    setState(() {
      for (var slot = 1; slot <= 25; slot++) {
        if (checked) {
          _slotOwners[slot] = brandId;
        } else if (_slotOwners[slot] == brandId) {
          _slotOwners.remove(slot);
        }
      }
      _message = null;
    });
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
      setState(() { _message = 'تم حفظ توزيع ${count ?? assignments.length} موضعًا إعلانيًا بنجاح.'; _editMode = false; });
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
      width: 42,
      height: 42,
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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 3),
            child: Row(children: [
              const Icon(Icons.view_carousel_outlined, color: _tickerPurple, size: 20),
              const SizedBox(width: 6),
              const Expanded(child: Text('إعلانات شريط التمرير',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _tickerPurple))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Wrap(spacing: 2.5, runSpacing: 2.5, children: [
              ErpQuickTaskButton(label: 'تحديث', icon: Icons.refresh, compact: true,
                onPressed: _loading || _saving ? null : _load),
              ErpQuickTaskButton(label: 'تعديل', icon: Icons.edit_outlined, compact: true,
                onPressed: _saving || _loading ? null : () => setState(() => _editMode = !_editMode)),
              ErpQuickTaskButton(label: 'حفظ', icon: Icons.save_outlined, compact: true,
                onPressed: !_ready || _saving || _loading || !_editMode ? null : _save),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            child: SizedBox(height: 40, child: DropdownButtonFormField<String>(
              value: _activityCode,
              isDense: true,
              itemHeight: 40,
              decoration: const InputDecoration(
                labelText: 'نطاق الإعلان حسب النشاط',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
              onChanged: _loading || _saving ? null : (value) {
                setState(() {
                  _activityCode = value ?? 'ALL';
                  _slotOwners.clear();
                });
                _load();
              },
            )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 2.5, 5, 2.5),
            child: SizedBox(height: 40, child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ابحث باسم البراند أو كوده',
                prefixIcon: Icon(Icons.search, color: _tickerPurple, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                border: OutlineInputBorder(),
              ),
            )),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              _editMode ? 'وضع التعديل نشط. حدد مواضع البراندات ثم اضغط حفظ من شريط المهام.' : 'اضغط تعديل أولاً لتغيير التوزيع. لا يمكن تخصيص الموضع نفسه لأكثر من براند في النطاق الواحد.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
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
                            horizontalMargin: 10,
                            columns: [
                              const DataColumn(label: Text('م')),
                              const DataColumn(label: Text('كود البراند')),
                              const DataColumn(label: Text('الصورة')),
                              const DataColumn(label: Text('اسم البراند')),
                              const DataColumn(label: Text('الكل')),
                              ...List.generate(25, (index) => DataColumn(label: Text('${index + 1}'))),
                            ],
                            rows: brands.asMap().entries.map((entry) {
                              final rowNo = entry.key + 1;
                              final brand = entry.value;
                              final id = _s(brand['id']);
                              final selectedCount = _slotOwners.values.where((owner) => owner == id).length;
                              return DataRow(cells: [
                                DataCell(Text('$rowNo', style: const TextStyle(fontWeight: FontWeight.w800))),
                                DataCell(Text(_s(brand['brand_code']), style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(_brandLogo(brand)),
                                DataCell(SizedBox(width: 145, child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_s(brand['brand_name']), maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(_s(brand['brand_name_en']).isEmpty ? '—' : _s(brand['brand_name_en']),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  ],
                                ))),
                                DataCell(Checkbox(
                                  shape: const CircleBorder(),
                                  value: selectedCount == 0 ? false : selectedCount == 25 ? true : null,
                                  tristate: true,
                                  onChanged: !_editMode || _saving ? null : (value) => _toggleAll(id, value == true),
                                )),
                                ...List.generate(25, (index) {
                                  final slot = index + 1;
                                  return DataCell(Checkbox(
                                    shape: const CircleBorder(),
                                    value: _slotOwners[slot] == id,
                                    onChanged: !_editMode || _saving ? null : (value) =>
                                      _toggleSlot(id, slot, value == true),
                                  ));
                                }),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text('المواضع المحددة: ${_slotOwners.length}/25',
              style: const TextStyle(color: _tickerPurple, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
