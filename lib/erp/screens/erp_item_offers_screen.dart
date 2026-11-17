import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/erp_inventory_master_repository.dart';
import '../services/erp_parties_repository.dart';

class ErpItemOffersScreen extends StatefulWidget {
  const ErpItemOffersScreen({super.key, required this.companyId, this.initialCampaignType, this.lockCampaignType = false});
  final String? companyId;
  final String? initialCampaignType;
  final bool lockCampaignType;
  @override
  State<ErpItemOffersScreen> createState() => _ErpItemOffersScreenState();
}

class _ErpItemOffersScreenState extends State<ErpItemOffersScreen> {
  final _inventory = ErpInventoryMasterRepository();
  final _partiesRepo = ErpPartiesRepository();
  final _name = TextEditingController();
  final _search = TextEditingController();
  DateTime _from = DateTime.now(), _to = DateTime.now().add(const Duration(days: 30));
  String _campaignType = 'customer_magazine';
  String _discountKind = 'special_price';
  String _customerScope = 'كل العملاء';
  String _warehouseScope = 'كل المخازن';
  String? _categoryId;
  bool _loading = false, _saving = false;
  String? _error, _message;
  String? _editingCampaignId;
  List<Map<String,dynamic>> _items = [], _categories = [], _brands = [], _parties = [], _warehouses = [], _branches = [], _campaigns = [];
  final Set<String> _selectedCustomers = {}, _selectedWarehouses = {}, _selectedBranches = {}, _governorates = {}, _districts = {}, _centers = {}, _areas = {}, _customerTypes = {};
  final List<Map<String,dynamic>> _offerLines = [];
  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _campaignTitle(String type) => const {
    'customer_magazine': 'مجلات عروض العملاء',
    'promotion': 'عروض الترويج',
    'slow_moving': 'عروض الرواكد',
  }[type] ?? 'عروض الأصناف';
  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  @override void initState() { super.initState(); if (widget.initialCampaignType != null && const {'customer_magazine','promotion','slow_moving'}.contains(widget.initialCampaignType)) _campaignType = widget.initialCampaignType!; _load(); }
  @override void dispose() { _name.dispose(); _search.dispose(); super.dispose(); }

  Future<List<Map<String,dynamic>>> _fetchAllItems(String companyId) async {
    const pageSize=500; var offset=0; final result=<Map<String,dynamic>>[];
    while(true) { final page=await _inventory.fetchItems(companyId,offset:offset,pageSize:pageSize,includeImageData:true); result.addAll(page.where((item)=>item['is_active']!=false)); if(page.length<pageSize) break; offset+=page.length; }
    return result;
  }
  Future<void> _load() async {
    final company = widget.companyId;
    if (company == null || company.isEmpty) { setState(() => _error = 'اربط الشاشة بشركة نشطة أولًا.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        _fetchAllItems(company), _inventory.fetchCategories(company,pageSize:2000), _inventory.fetchBrands(company), _inventory.fetchWarehouses(company), _inventory.fetchBranches(company),
        _partiesRepo.fetchParties(company, kind: 'customer'),
        _db!.from('erp_sales_campaigns').select('id,title,campaign_type,start_date,end_date,is_active,target_customer_ids,target_warehouse_ids,target_branch_ids,target_governorates,target_districts,target_areas,target_centers,target_customer_types').eq('company_id', company).order('created_at', ascending: false).limit(100),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (values[0] as List).cast<Map<String,dynamic>>();
        _categories = (values[1] as List).cast<Map<String,dynamic>>().where((row)=>row['is_active']!=false).toList();
        _brands = (values[2] as List).cast<Map<String,dynamic>>();
        _warehouses = (values[3] as List).cast<Map<String,dynamic>>();
        _branches = (values[4] as List).cast<Map<String,dynamic>>();
        _parties = (values[5] as List).cast<Map<String,dynamic>>();
        _campaigns = (values[6] as List).map((r) => Map<String,dynamic>.from(r)).where((r) => !widget.lockCampaignType || _s(r['campaign_type']) == _campaignType).toList();
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل بيانات العروض: $e'; }); }
  }

  Future<void> _chooseDate(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: start ? _from : _to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (selected != null) setState(() { if (start) { _from = selected; if (_to.isBefore(_from)) _to = _from; } else { _to = selected; if (_to.isBefore(_from)) _from = _to; } });
  }

  Future<void> _pickMulti({required String title, required List<Map<String,dynamic>> options, required String idKey, required String labelKey, required Set<String> selected}) async {
    final draft = Set<String>.from(selected);
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text(title, textDirection: TextDirection.rtl),
      content: SizedBox(width: 520, height: 420, child: options.isEmpty ? const Center(child: Text('لا توجد بيانات متاحة لهذا الاختيار.')) : ListView(children: options.map((r) {
        final id = _s(r[idKey]); final label = _s(r[labelKey]);
        return CheckboxListTile(value: draft.contains(id), title: Text(label, textDirection: TextDirection.rtl), onChanged: (v) => refresh(() { v == true ? draft.add(id) : draft.remove(id); }));
      }).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { setState(() { selected..clear()..addAll(draft); }); Navigator.pop(ctx); }, child: const Text('تطبيق الاختيار'))],
    )));
  }

  Future<void> _pickGeographicTargets() async {
    final tree=<String,Map<String,Map<String,Set<String>>>>{};
    for(final party in _parties.where((p)=>p['is_active']!=false)) {
      final gov=_s(party['governorate']).trim().isEmpty?'غير محدد':_s(party['governorate']).trim();
      final center=_s(party['center']).trim().isEmpty?'غير محدد':_s(party['center']).trim();
      final district=_s(party['district']).trim().isEmpty?'غير محدد':_s(party['district']).trim();
      final area=_s(party['area']).trim().isEmpty?'غير محدد':_s(party['area']).trim();
      (tree[gov]??=<String,Map<String,Set<String>>>{}).putIfAbsent(center,()=> <String,Set<String>>{});
      (tree[gov]![center]??=<String,Set<String>>{}).putIfAbsent(district,()=> <String>{}).add(area);
    }
    String geoValue(Map<String,dynamic> row,String field)=>_s(row[field]).trim().isEmpty?'غير محدد':_s(row[field]).trim();
    int countWhere(bool Function(Map<String,dynamic>) test)=>_parties.where((p)=>p['is_active']!=false&&test(p)).length;
    void toggleArea(String area,bool selected){if(selected)_areas.add(area);else _areas.remove(area);}
    void toggleDistrict(String district,Set<String> areas,bool selected){if(selected)_districts.add(district);else _districts.remove(district);for(final area in areas)toggleArea(area,selected);}
    void toggleCenter(String center,Map<String,Set<String>> districts,bool selected){if(selected)_centers.add(center);else _centers.remove(center);for(final entry in districts.entries)toggleDistrict(entry.key,entry.value,selected);}
    void toggleGovernorate(String gov,Map<String,Map<String,Set<String>>> centers,bool selected){if(selected)_governorates.add(gov);else _governorates.remove(gov);for(final entry in centers.entries)toggleCenter(entry.key,entry.value,selected);}
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
      Widget areaNode(String gov,String center,String district,String area){
        final count=countWhere((p)=>geoValue(p,'governorate')==gov&&geoValue(p,'center')==center&&geoValue(p,'district')==district&&geoValue(p,'area')==area);
        return CheckboxListTile(dense:true,contentPadding:const EdgeInsetsDirectional.only(start:44),value:_areas.contains(area),title:Text(area),subtitle:Text('$count عميل'),onChanged:(v)=>refresh(()=>toggleArea(area,v==true)));
      }
      Widget districtNode(String gov,String center,String district,Set<String> areas){
        final count=countWhere((p)=>geoValue(p,'governorate')==gov&&geoValue(p,'center')==center&&geoValue(p,'district')==district);
        return ExpansionTile(leading:Checkbox(value:_districts.contains(district),onChanged:(v)=>refresh(()=>toggleDistrict(district,areas,v==true))),title:Text(district),subtitle:Text('$count عميل'),children:areas.map((area)=>areaNode(gov,center,district,area)).toList());
      }
      Widget centerNode(String gov,String center,Map<String,Set<String>> districts){
        final count=countWhere((p)=>geoValue(p,'governorate')==gov&&geoValue(p,'center')==center);
        return ExpansionTile(leading:Checkbox(value:_centers.contains(center),onChanged:(v)=>refresh(()=>toggleCenter(center,districts,v==true))),title:Text(center),subtitle:Text('$count عميل'),children:districts.entries.map((e)=>districtNode(gov,center,e.key,e.value)).toList());
      }
      return AlertDialog(title:const Text('استهداف العملاء حسب الموقع الجغرافي'),content:SizedBox(width:640,height:560,child:Column(children:[
        Row(children:[Text('المحدد: '+(_governorates.length+_centers.length+_districts.length+_areas.length).toString(),style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF3E007D))),const Spacer(),TextButton(onPressed:()=>refresh(() { for(final p in _parties.where((p)=>p['is_active']!=false)) { _governorates.add(geoValue(p,'governorate')); _centers.add(geoValue(p,'center')); _districts.add(geoValue(p,'district')); _areas.add(geoValue(p,'area')); } }),child:const Text('تحديد الكل')),TextButton(onPressed:()=>refresh(() { _governorates.clear(); _centers.clear(); _districts.clear(); _areas.clear(); }),child:const Text('إلغاء الكل'))]),
        Expanded(child:tree.isEmpty?const Center(child:Text('لا توجد بيانات جغرافية مسجلة للعملاء.')):ListView(children:tree.entries.map((entry){final gov=entry.key;final centers=entry.value;final count=countWhere((p)=>geoValue(p,'governorate')==gov);return ExpansionTile(leading:Checkbox(value:_governorates.contains(gov),onChanged:(v)=>refresh(()=>toggleGovernorate(gov,centers,v==true))),title:Text(gov,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('$count عميل'),children:centers.entries.map((e)=>centerNode(gov,e.key,e.value)).toList());}).toList())),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('اعتماد الاستهداف'))]);
    }));
  }
  List<Map<String,dynamic>> _distinctOptions(String field) {
    final values = _parties.map((p)=>_s(p[field])).where((v)=>v.isNotEmpty).toSet().toList()..sort();
    return values.map((v)=>{'id':v,'name':v}).toList();
  }

  Uint8List? _itemImageBytes(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final prefix = raw.startsWith(r'\\x') ? 3 : raw.startsWith(r'\x') ? 2 : 0;
    if (prefix == 0 || raw.length <= prefix || (raw.length - prefix).isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        (raw.length - prefix) ~/ 2,
        (index) => int.parse(raw.substring(prefix + index * 2, prefix + index * 2 + 2), radix: 16),
      ));
    } catch (_) { return null; }
  }

  Future<void> _pickProducts() async {
    final chosen = _offerLines.map((line) => _s(line['item_id'])).toSet();
    final search = TextEditingController();
    final expandedCategories = <String>{};
    final expandedBrands = <String>{};
    final brandNames = <String,String>{for(final brand in _brands) _s(brand['id']):_s(brand['brand_name'])};
    String categoryId(Map<String,dynamic> row) => _s(row['id']);
    String parentId(Map<String,dynamic> row) => _s(row['parent_id']);
    List<Map<String,dynamic>> childrenOf(String id) => _categories.where((row)=>parentId(row)==id).toList();
    List<Map<String,dynamic>> itemsOf(String id) => _items.where((item)=>_s(item['category_id'])==id && (search.text.trim().isEmpty || _s(item['item_name']).toLowerCase().contains(search.text.trim().toLowerCase()) || _s(item['item_code']).toLowerCase().contains(search.text.trim().toLowerCase()) || _s(item['barcode']).toLowerCase().contains(search.text.trim().toLowerCase()))).toList();
    List<Map<String,dynamic>> descendantsItems(String id, [Set<String>? visited]) {
      final seen=visited??<String>{}; if(!seen.add(id)) return <Map<String,dynamic>>[];
      final result=<Map<String,dynamic>>[]..addAll(itemsOf(id));
      for(final child in childrenOf(id)) result.addAll(descendantsItems(categoryId(child),seen));
      return result;
    }
    Map<String,List<Map<String,dynamic>>> groupByBrand(List<Map<String,dynamic>> products) {
      final groups=<String,List<Map<String,dynamic>>>{};
      for(final item in products) { final id=_s(item['brand_id']); final label=brandNames[id] ?? _s(item['brand_name']); final key=label.trim().isEmpty?'بدون ماركة':label.trim(); (groups[key]??=<Map<String,dynamic>>[]).add(item); }
      final keys=groups.keys.toList()..sort((a,b)=>a=='بدون ماركة'?1:b=='بدون ماركة'?-1:a.compareTo(b));
      return {for(final key in keys)key:groups[key]!};
    }
    void addProducts(List<Map<String,dynamic>> products) {
      for(final item in products) { final id=_s(item['id']); if(id.isEmpty) continue; chosen.add(id); }
    }
    Widget productNode(Map<String,dynamic> item, void Function(void Function()) refresh) {
      final id=_s(item['id']); final selected=chosen.contains(id); final image=_s(item['image_url']); final imageBytes=_itemImageBytes(item['image_data']);
      return Padding(padding:const EdgeInsetsDirectional.only(start:18,bottom:4),child:Row(children:[
        Checkbox(value:selected,onChanged:(value)=>refresh(()=>value==true?chosen.add(id):chosen.remove(id))),
        if(imageBytes!=null)ClipRRect(borderRadius:BorderRadius.circular(7),child:Image.memory(imageBytes,width:38,height:38,fit:BoxFit.cover)) else if(image.startsWith('http'))ClipRRect(borderRadius:BorderRadius.circular(7),child:Image.network(image,width:38,height:38,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.inventory_2_outlined,size:30))) else const Icon(Icons.inventory_2_outlined,size:30,color:Color(0xFF3E007D)),
        const SizedBox(width:7),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_s(item['item_name']),style:const TextStyle(fontWeight:FontWeight.w700)),Text('كود: '+_s(item['item_code'])+' • الوحدة: '+_s(item['base_unit'])+' • السعر الأصلي: '+_n(item['sale_price']).toStringAsFixed(2)+' ج.م',style:const TextStyle(fontSize:11,color:Colors.black54))])),
      ]));
    }
    Widget brandNode(String categoryKey, String brand, List<Map<String,dynamic>> products, void Function(void Function()) refresh) {
      final key=categoryKey+'|'+brand; final expanded=expandedBrands.contains(key) || search.text.trim().isNotEmpty;
      return Padding(padding:const EdgeInsetsDirectional.only(start:16),child:Column(children:[
        InkWell(onTap:()=>refresh(()=>expanded?expandedBrands.remove(key):expandedBrands.add(key)),child:Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Icon(expanded?Icons.expand_more:Icons.chevron_left,color:const Color(0xFFFF27C3)),Expanded(child:Text(brand,style:const TextStyle(color:Color(0xFFFF27C3),fontWeight:FontWeight.w800))),Text(products.length.toString()+' صنف',style:const TextStyle(fontSize:11)),TextButton(onPressed:()=>refresh(()=>addProducts(products)),child:const Text('تحديد الكل'))]))),
        if(expanded)...products.map((item)=>productNode(item,refresh)),
      ]));
    }
    late Widget Function(Map<String,dynamic>,int,void Function(void Function())) categoryNode;
    categoryNode=(category,depth,refresh) {
      final id=categoryId(category); final expanded=expandedCategories.contains(id) || search.text.trim().isNotEmpty; final products=itemsOf(id); final childRows=childrenOf(id);
      final groups=groupByBrand(products);
      final all=descendantsItems(id);
      return Padding(padding:EdgeInsetsDirectional.only(start:depth*14.0,bottom:5),child:Container(decoration:BoxDecoration(color:depth==0?const Color(0xFFF5EFFB):Colors.white,borderRadius:BorderRadius.circular(9),border:Border.all(color:const Color(0xFFE2D5EF))),child:Column(children:[
        Row(children:[IconButton(visualDensity:VisualDensity.compact,onPressed:()=>refresh(()=>expanded?expandedCategories.remove(id):expandedCategories.add(id)),icon:Icon(expanded?Icons.expand_more:Icons.chevron_left,color:const Color(0xFF3E007D))),Expanded(child:InkWell(onTap:()=>refresh(()=>expanded?expandedCategories.remove(id):expandedCategories.add(id)),child:Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(_s(category['category_name'])+' ('+all.length.toString()+')',style:TextStyle(fontWeight:FontWeight.w900,color:depth==0?const Color(0xFF3E007D):const Color(0xFF5A3A75)))))),TextButton(onPressed:()=>refresh(()=>addProducts(all)),child:const Text('تحديد الفئة'))]),
        if(expanded)...groups.entries.map((entry)=>brandNode(id,entry.key,entry.value,refresh)),
        if(expanded)...childRows.map((child)=>categoryNode(child,depth+1,refresh)),
      ])));
    };
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
      final roots=_categories.where((row)=>parentId(row).isEmpty || parentId(row)=='null').toList();
      final allVisible=_items.where((item)=>search.text.trim().isEmpty || _s(item['item_name']).toLowerCase().contains(search.text.trim().toLowerCase()) || _s(item['item_code']).toLowerCase().contains(search.text.trim().toLowerCase()) || _s(item['barcode']).toLowerCase().contains(search.text.trim().toLowerCase())).toList();
      return AlertDialog(title:const Text('اختيار أصناف العرض'),content:SizedBox(width:780,height:590,child:Column(children:[
        TextField(controller:search,onChanged:(_)=>refresh((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'ابحث باسم الصنف أو الكود أو الباركود',isDense:true,border:OutlineInputBorder())),
        const SizedBox(height:7),
        Row(children:[Text('المحدد: '+chosen.length.toString()+' صنف',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF3E007D))),const Spacer(),TextButton(onPressed:()=>refresh(()=>addProducts(allVisible)),child:Text(search.text.trim().isEmpty?'تحديد كل الأصناف':'تحديد نتائج البحث')),TextButton(onPressed:()=>refresh(()=>chosen.clear()),child:const Text('إلغاء الكل'))]),
        Expanded(child:_categories.isEmpty||roots.isEmpty?ListView(children:allVisible.map((item)=>productNode(item,refresh)).toList()):ListView(children:roots.map((category)=>categoryNode(category,0,refresh)).toList())),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){setState(()=>_offerLines.removeWhere((line)=>!chosen.contains(_s(line['item_id']))));for(final id in chosen){if(_offerLines.any((line)=>_s(line['item_id'])==id))continue;final item=_items.firstWhere((row)=>_s(row['id'])==id);final sale=_n(item['sale_price']);_offerLines.add({'item_id':id,'item_code':_s(item['item_code']),'item_name':_s(item['item_name']),'unit':_s(item['base_unit']),'sale_price':sale,'offer_price':sale,'offer_qty':100.0,'remaining_qty':100.0,'min_quantity':1.0,'discount':0.0});}Navigator.pop(ctx);},child:const Text('اعتماد الأصناف المحددة'))]);
    }));
    search.dispose();
  }

  Future<void> _editCampaign(Map<String,dynamic> campaign) async {
    final id=_s(campaign['id']); if(id.isEmpty) return;
    setState(()=>_loading=true);
    try {
      final rows=await _db!.from('erp_sales_campaign_items').select('item_id,offer_price,min_quantity,max_quantity,offer_quantity,remaining_quantity,discount_value,discount_kind,is_active').eq('company_id',widget.companyId!.trim()).eq('campaign_id',id);
      final next=<Map<String,dynamic>>[];
      for(final raw in rows) {
        final row=Map<String,dynamic>.from(raw); if(row['is_active']==false) continue;
        final matches=_items.where((v)=>_s(v['id'])==_s(row['item_id'])).toList(); final item=matches.isEmpty?null:matches.first;
        if(item==null) continue;
        next.add({'item_id':_s(item['id']),'item_code':_s(item['item_code']),'item_name':_s(item['item_name']),'unit':_s(item['base_unit']),'sale_price':_n(item['sale_price']),'offer_price':_n(row['offer_price']),'offer_qty':_n(row['offer_quantity'])>0?_n(row['offer_quantity']):_n(row['max_quantity']),'remaining_qty':_n(row['remaining_quantity']),'discount':_n(row['discount_value']),'min_quantity':_n(row['min_quantity'])});
      }
      if(!mounted)return;
      setState(() {
        _editingCampaignId=id; _name.text=_s(campaign['title']); _campaignType=_s(campaign['campaign_type']); _discountKind=rows.isEmpty?'special_price':_s(rows.first['discount_kind']);
        _from=DateTime.tryParse(_s(campaign['start_date']))??DateTime.now(); _to=DateTime.tryParse(_s(campaign['end_date']))??_from;
        _offerLines..clear()..addAll(next);
        _selectedCustomers..clear()..addAll((campaign['target_customer_ids'] as List? ?? const []).map((v)=>v.toString()));
        _selectedWarehouses..clear()..addAll((campaign['target_warehouse_ids'] as List? ?? const []).map((v)=>v.toString()));
        _selectedBranches..clear()..addAll((campaign['target_branch_ids'] as List? ?? const []).map((v)=>v.toString()));
        _governorates..clear()..addAll((campaign['target_governorates'] as List? ?? const []).map((v)=>v.toString()));
        _districts..clear()..addAll((campaign['target_districts'] as List? ?? const []).map((v)=>v.toString()));
        _areas..clear()..addAll((campaign['target_areas'] as List? ?? const []).map((v)=>v.toString()));
        _centers..clear()..addAll((campaign['target_centers'] as List? ?? const []).map((v)=>v.toString()));
        _customerTypes..clear()..addAll((campaign['target_customer_types'] as List? ?? const []).map((v)=>v.toString()));
        _customerScope=_selectedCustomers.isEmpty?'كل العملاء':'عملاء محددون'; _warehouseScope=_selectedWarehouses.isEmpty?'كل المخازن':'مخازن محددة';
        _loading=false; _message='تم تحميل العرض للتعديل. احفظ التغييرات بعد المراجعة.'; _error=null;
      });
    } catch(error) { if(mounted)setState(()=>_loading=false); if(mounted)setState(()=>_error='تعذر تحميل تفاصيل العرض للتعديل: $error'); }
  }
  Future<void> _deleteCampaign(Map<String, dynamic> campaign) async {
    final campaignId = _s(campaign['id']);
    if (campaignId.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إيقاف العرض'),
        content: Text('سيتم إيقاف العرض «${_s(campaign['title'])}» مع الاحتفاظ بسجله. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، أوقف العرض'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final company = widget.companyId?.trim() ?? '';
    if (company.isEmpty || _db == null) {
      if (mounted) setState(() => _error = 'لا توجد شركة نشطة لحذف العرض.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _db!.from('erp_sales_campaigns')
          .update({'is_active':false}).eq('id', campaignId).eq('company_id', company);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم إيقاف العرض مع الاحتفاظ بسجله وبنوده.'; });
      await _load();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حذف العرض: $e'; });
    }
  }

  Future<void> _save() async {
    final company = widget.companyId?.trim() ?? '';
    final db = _db;
    if (company.isEmpty || db == null) { setState(() => _error = 'لا توجد شركة نشطة أو اتصال بقاعدة البيانات.'); return; }
    if (_name.text.trim().isEmpty || _offerLines.isEmpty) { setState(() => _error = 'أدخل اسم العرض واختر صنفًا واحدًا على الأقل.'); return; }
    if (_customerScope == 'عملاء محددون' && _selectedCustomers.isEmpty) { setState(() => _error = 'اختر عميلًا واحدًا على الأقل أو غيّر النطاق إلى كل العملاء.'); return; }
    if (_warehouseScope == 'مخازن محددة' && _selectedWarehouses.isEmpty) { setState(() => _error = 'اختر مخزنًا واحدًا على الأقل أو غيّر النطاق إلى كل المخازن.'); return; }
    if (_to.isBefore(_from)) { setState(() => _error = 'تاريخ نهاية العرض يجب ألا يسبق بدايته.'); return; }
    for (final line in _offerLines) {
      if (_n(line['offer_qty']) <= 0 || _n(line['min_quantity']) <= 0 || _n(line['min_quantity']) > _n(line['offer_qty']) || _n(line['remaining_qty']) < 0 || _n(line['remaining_qty']) > _n(line['offer_qty']) || _n(line['offer_price']) < 0) {
        setState(() => _error = 'راجع أسعار وكميات العرض؛ المتبقي لا يتجاوز الكمية الأصلية.'); return;
      }
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final singleCustomer = _selectedCustomers.length == 1 ? _selectedCustomers.first : null;
      final campaignData = {
        'company_id':company, 'campaign_type':_campaignType, 'title':_name.text.trim(),
        'start_date':_date(_from), 'end_date':_date(_to), 'owner_party_id':singleCustomer,
        'owner_label':_selectedCustomers.isEmpty ? 'كل العملاء' : 'عملاء محددون',
        'is_active':true,
        'target_customer_ids':_selectedCustomers.toList(),
        'target_warehouse_ids':_selectedWarehouses.toList(),
        'target_branch_ids':_selectedBranches.toList(),
        'target_governorates':_governorates.toList(), 'target_districts':_districts.toList(),
        'target_areas':_areas.toList(), 'target_centers':_centers.toList(), 'target_customer_types':_customerTypes.toList(),
      };
      final campaignId = _editingCampaignId ?? _s((await db.from('erp_sales_campaigns').insert(campaignData).select('id').single())['id']);
      if(_editingCampaignId != null) { await db.from('erp_sales_campaigns').update(campaignData).eq('id',campaignId).eq('company_id',company); await db.from('erp_sales_campaign_items').update({'is_active':false}).eq('campaign_id',campaignId).eq('company_id',company); }
      final rows = _offerLines.map((line) {
        final offerPrice = _n(line['offer_price']);
        final discountValue = _n(line['discount']);
        return <String,dynamic>{
          'company_id':company, 'campaign_id':campaignId, 'item_id':_s(line['item_id']),
          'offer_price':offerPrice, 'min_quantity':_n(line['min_quantity'])>0?_n(line['min_quantity']):1,
          'max_quantity':_n(line['offer_qty']), 'offer_quantity':_n(line['offer_qty']), 'remaining_quantity':_n(line['remaining_qty']),
          'discount_value':discountValue, 'discount_kind':_discountKind,
          'representative_incentive':_campaignType == 'slow_moving' ? 2 : 0,
          'customer_incentive':_campaignType == 'promotion' ? 2 : 0, 'is_active':true,
        };
      }).toList();
      await db.from('erp_sales_campaign_items').upsert(rows, onConflict:'campaign_id,item_id');
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم حفظ العرض وبنوده في قاعدة بيانات العروض.'; _name.clear(); _offerLines.clear(); _editingCampaignId=null; });
      await _load();
    } catch (e) { if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ العرض: $e'; }); }
  }

  Widget _field(String label, Widget child) => Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 5), child]));
  InputDecoration _dec(String label) => InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10));
  Widget _notice(String text, bool error) => Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:error?Colors.red.shade50:Colors.green.shade50,borderRadius:BorderRadius.circular(8)),child:Text(text,style:TextStyle(color:error?Colors.red.shade900:Colors.green.shade900)));

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewOffer() async {
    final now=DateTime.now();
    final status=_to.isBefore(DateTime(now.year,now.month,now.day))?'منتهي':_from.isAfter(DateTime(now.year,now.month,now.day))?'مجدول':'ساري خلال الفترة المحددة';
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('معاينة مجلة العرض'),content:SizedBox(width:680,height:520,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('اسم العرض: '+(_name.text.trim().isEmpty?'—':_name.text.trim()),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
      const SizedBox(height:6),Text('النوع: '+_campaignTitle(_campaignType)+' • الحالة: '+status),
      Text('الفترة: '+_date(_from)+' إلى '+_date(_to)),
      Text('العملاء: '+(_selectedCustomers.isEmpty?'كل العملاء':_selectedCustomers.length.toString()+' محدد')+' • المخازن: '+(_selectedWarehouses.isEmpty?'كل المخازن':_selectedWarehouses.length.toString()+' محدد')),
      Text('الفروع: '+_selectedBranches.length.toString()+' • المناطق: '+(_governorates.length+_districts.length+_centers.length+_areas.length).toString()+' • تصنيفات العملاء: '+_customerTypes.length.toString()),
      const Divider(),
      Text('الأصناف ('+_offerLines.length.toString()+')',style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF3E007D))),
      ..._offerLines.map((line)=>Card(margin:const EdgeInsets.symmetric(vertical:4),child:ListTile(title:Text(_s(line['item_name']),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('الوحدة: '+_s(line['unit'])+' • أقل كمية: '+_n(line['min_quantity']).toString()+' • الكمية: '+_n(line['offer_qty']).toString()+' • المتبقي: '+_n(line['remaining_qty']).toString()),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text(_n(line['sale_price']).toStringAsFixed(2)+' ج.م',style:const TextStyle(decoration:TextDecoration.lineThrough,color:Colors.black45,fontSize:11)),Text(_n(line['offer_price']).toStringAsFixed(2)+' ج.م',style:const TextStyle(color:Color(0xFFFFA015),fontWeight:FontWeight.w900))])))),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));
  }
  Future<void> _confirmRemoveOfferLine(Map<String, dynamic> line) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الصنف من العرض'),
        content: Text('هل تريد حذف «${_s(line['item_name'])}» من قائمة أصناف العرض؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No / لا')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes / نعم، احذف'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) setState(() => _offerLines.remove(line));
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(save: _save);
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) { _pickProducts(); return null; },
          ),
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(color: const Color(0xFF3E007D), child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          const Icon(Icons.local_offer, color: Color(0xFFFFA015), size: 26),
                          const SizedBox(width: 8),
                          Expanded(child: Text(widget.lockCampaignType ? _campaignTitle(_campaignType) : 'عروض الأصناف', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
                        ]),
                        const SizedBox(height: 8),
                        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                          _quickTask('تحديث', Icons.refresh, Colors.blue, _load),
                          _quickTask('إضافة / مسح النموذج', Icons.add_circle_outline, const Color(0xFF168447), () {
                            _name.clear(); _search.clear(); _offerLines.clear(); _editingCampaignId=null;
                            setState(() { _message = 'نموذج عرض جديد جاهز.'; _error = null; });
                          }),
                          _quickTask(_editingCampaignId == null ? 'حفظ / نشر / جدولة' : 'حفظ التعديلات', Icons.save_outlined, const Color(0xFF168447), _save),
                          _quickTask('اختيار الأصناف', Icons.inventory_2_outlined, const Color(0xFF137C8B), _pickProducts),
                          _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewOffer),
                        ])),
                      ]),
                    )),
                    const SizedBox(height: 8),
                    if (_error != null) _notice(_error!, true),
                    if (_message != null) _notice(_message!, false),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _field('اسم العرض', TextField(
                                    controller: _name,
                                    decoration: _dec('مثال: عرض نهاية الأسبوع'),
                                  )),
                                ),
                                Expanded(
                                  child: _field('نوع العرض في المبيعات', DropdownButtonFormField<String>(itemHeight: 48, 
                                    value: _campaignType,
                                    decoration: _dec('نوع العرض'),
                                    items: const [
                                      DropdownMenuItem(value: 'customer_magazine', child: Text('عرض للعملاء')),
                                      DropdownMenuItem(value: 'promotion', child: Text('عرض ترويج')),
                                      DropdownMenuItem(value: 'slow_moving', child: Text('عرض الرواكد')),
                                    ],
                                    onChanged: widget.lockCampaignType ? null : (v) => setState(() => _campaignType = v ?? _campaignType),
                                  )),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _field('طريقة التسعير', DropdownButtonFormField<String>(itemHeight: 48, 
                                    value: _discountKind,
                                    decoration: _dec('طريقة التسعير'),
                                    items: const [
                                      DropdownMenuItem(value: 'special_price', child: Text('سعر عرض خاص')),
                                      DropdownMenuItem(value: 'percent', child: Text('خصم نسبة')),
                                      DropdownMenuItem(value: 'amount', child: Text('خصم قيمة')),
                                      DropdownMenuItem(value: 'buy_get', child: Text('اشترِ كمية واحصل على كمية')),
                                      DropdownMenuItem(value: 'clearance', child: Text('تصفية رواكد')),
                                    ],
                                    onChanged: (v) => setState(() {
                                      _discountKind = v ?? _discountKind;
                                      for (final line in _offerLines) {
                                        final base = _n(line['sale_price']);
                                        final discount = _n(line['discount']);
                                        if (_discountKind == 'percent') {
                                          line['offer_price'] = (base - base * discount / 100).clamp(0, double.infinity);
                                        } else if (_discountKind == 'amount') {
                                          line['offer_price'] = (base - discount).clamp(0, double.infinity);
                                        }
                                      }
                                    }),
                                  )),
                                ),
                                Expanded(
                                  child: _field('بداية العرض', OutlinedButton.icon(
                                    onPressed: () => _chooseDate(true),
                                    icon: const Icon(Icons.calendar_month),
                                    label: Text(_date(_from)),
                                  )),
                                ),
                                Expanded(
                                  child: _field('نهاية العرض', OutlinedButton.icon(
                                    onPressed: () => _chooseDate(false),
                                    icon: const Icon(Icons.event_busy),
                                    label: Text(_date(_to)),
                                  )),
                                ),
                              ],
                            ),
                            const Divider(),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text('نطاق تطبيق العرض', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E007D))),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _field('العملاء', DropdownButtonFormField<String>(itemHeight: 48, 
                                    value: _customerScope,
                                    decoration: _dec('تطبيق على'),
                                    items: const [
                                      DropdownMenuItem(value: 'كل العملاء', child: Text('كل العملاء')),
                                      DropdownMenuItem(value: 'عملاء محددون', child: Text('عملاء محددون')),
                                    ],
                                    onChanged: (v) => setState(() => _customerScope = v ?? _customerScope),
                                  )),
                                ),
                                Expanded(
                                  child: _field('المخازن والفروع', DropdownButtonFormField<String>(itemHeight: 48, 
                                    value: _warehouseScope,
                                    decoration: _dec('تطبيق على'),
                                    items: const [
                                      DropdownMenuItem(value: 'كل المخازن', child: Text('كل المخازن')),
                                      DropdownMenuItem(value: 'مخازن محددة', child: Text('مخازن محددة')),
                                    ],
                                    onChanged: (v) => setState(() => _warehouseScope = v ?? _warehouseScope),
                                  )),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'جلب العملاء', options: _parties, idKey: 'id', labelKey: 'party_name', selected: _selectedCustomers),
                                  icon: const Icon(Icons.people_alt),
                                  label: Text('جلب العملاء (${_selectedCustomers.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'جلب المخازن', options: _warehouses, idKey: 'id', labelKey: 'warehouse_name', selected: _selectedWarehouses),
                                  icon: const Icon(Icons.warehouse),
                                  label: Text('جلب المخازن (${_selectedWarehouses.length})'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'الفروع', options: _branches, idKey: 'id', labelKey: 'branch_name', selected: _selectedBranches),
                                  icon: const Icon(Icons.store),
                                  label: Text('الفروع (${_selectedBranches.length})'),
                                ),
                                OutlinedButton.icon(onPressed:_pickGeographicTargets,icon:const Icon(Icons.account_tree_outlined),label:Text('المحافظات والمراكز والأحياء والمناطق/القرى (${_governorates.length+_centers.length+_districts.length+_areas.length})')),
                                OutlinedButton.icon(
                                  onPressed: () => _pickMulti(title: 'تصنيفات العملاء', options: _distinctOptions('customer_type'), idKey: 'id', labelKey: 'name', selected: _customerTypes),
                                  icon: const Icon(Icons.category),
                                  label: Text('تصنيفات العملاء (${_customerTypes.length})'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: _dec('بحث الأصناف — اضغط F1 لجلب الأصناف'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(onPressed: _pickProducts, icon: const Icon(Icons.playlist_add), label: const Text('جلب الأصناف F1')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(itemHeight: 48, 
                            value: _categoryId,
                            decoration: _dec('تصفية حسب الفئة'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('كل الفئات')),
                              ..._categories.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text(_s(g['category_name'])))),
                            ],
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => setState(() => _categoryId = null), child: const Text('الكل')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('كود')),
                            DataColumn(label: Text('الصنف')),
                            DataColumn(label: Text('الوحدة')),
                            DataColumn(label: Text('السعر الأصلي')),
                            DataColumn(label: Text('سعر العرض')),
                            DataColumn(label: Text('أقل كمية')),
                            DataColumn(label: Text('كمية العرض')),
                            DataColumn(label: Text('المتبقي')),
                            DataColumn(label: Text('خصم')),
                            DataColumn(label: Text('حذف')),
                          ],
                          rows: _offerLines.map((line) => DataRow(cells: [
                            DataCell(Text(_s(line['item_code']))),
                            DataCell(SizedBox(width: 180, child: Text(_s(line['item_name'])))),
                            DataCell(Text(_s(line['unit']))),
                            DataCell(Text.rich(TextSpan(children:[TextSpan(text:_n(line['sale_price']).toStringAsFixed(2),style:TextStyle(decoration:_n(line['offer_price'])<_n(line['sale_price'])?TextDecoration.lineThrough:TextDecoration.none,color:_n(line['offer_price'])<_n(line['sale_price'])?Colors.black45:null)),TextSpan(text:' ج.م')]))),
                            DataCell(SizedBox(
                              width: 90,
                              child: TextFormField(
                                initialValue: _s(line['offer_price']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('السعر'),
                                onChanged: (v) => setState(() => line['offer_price'] = _n(v)),
                              ),
                            )),
                            DataCell(SizedBox(width:85,child:TextFormField(initialValue:_s(line['min_quantity'] ?? 1),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:_dec('أقل كمية'),onChanged:(v)=>setState(()=>line['min_quantity']=_n(v))))),
                            DataCell(SizedBox(
                              width: 85,
                              child: TextFormField(
                                initialValue: _s(line['offer_qty']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('الكمية'),
                                onChanged: (v) => setState(() => line['offer_qty'] = _n(v)),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 85,
                              child: TextFormField(
                                initialValue: _s(line['remaining_qty']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('المتبقي'),
                                onChanged: (v) => setState(() => line['remaining_qty'] = _n(v)),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 75,
                              child: TextFormField(
                                initialValue: _s(line['discount']),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _dec('الخصم'),
                                onChanged: (v) => setState(() {
                                  line['discount'] = _n(v);
                                  final base = _n(line['sale_price']);
                                  final discount = _n(v);
                                  if (_discountKind == 'percent') {
                                    line['offer_price'] = (base - base * discount / 100).clamp(0, double.infinity);
                                  } else if (_discountKind == 'amount') {
                                    line['offer_price'] = (base - discount).clamp(0, double.infinity);
                                  }
                                }),
                              ),
                            )),
                            DataCell(IconButton(
                              tooltip: 'حذف الصنف',
                              onPressed: () => _confirmRemoveOfferLine(line),
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                            )),
                          ])).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'عدد الأصناف: ${_offerLines.length} | يتم حفظ العروض في جداول الحملات الفعلية المتصلة بأزرار جلب العروض في فاتورة البيع.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ العرض'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('العروض المسجلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E007D))),
                    if (_campaigns.isEmpty)
                      const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد عروض مسجلة بعد.')),
                    ..._campaigns.map((campaign) => Card(
                      child: ListTile(
                        leading: Icon(
                          _s(campaign['campaign_type']) == 'slow_moving'
                              ? Icons.inventory_2_outlined
                              : _s(campaign['campaign_type']) == 'promotion'
                                  ? Icons.campaign_outlined
                                  : Icons.menu_book_outlined,
                          color: const Color(0xFF3E007D),
                        ),
                        title: Text(_s(campaign['title'])),
                        subtitle: Text('${_s(campaign['start_date'])} ← ${_s(campaign['end_date'])} | ${_s(campaign['campaign_type'])}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_s(campaign['is_active']) == 'true' ? Icons.check_circle : Icons.pause_circle_outline,
                            color: _s(campaign['is_active']) == 'true' ? Colors.green : Colors.grey),
                          IconButton(tooltip:'تعديل العرض',onPressed:_saving?null:()=>_editCampaign(campaign),icon:const Icon(Icons.edit_outlined,color:Color(0xFF3E007D))),
                          IconButton(tooltip:'إيقاف العرض',onPressed:_saving?null:()=>_deleteCampaign(campaign),icon:const Icon(Icons.pause_circle_outline,color:Colors.red)),
                        ]),
                      ),
                    )),
                  ],
                ),
        ),
      ),
    );
  }

}
