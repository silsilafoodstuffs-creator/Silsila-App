import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpPhysicalStocktakeScreen extends StatefulWidget {
  const ErpPhysicalStocktakeScreen({super.key, required this.companyId});
  final String companyId;
  @override
  State<ErpPhysicalStocktakeScreen> createState() => _ErpPhysicalStocktakeScreenState();
}

class _ErpPhysicalStocktakeScreenState extends State<ErpPhysicalStocktakeScreen> {
  final _db = Supabase.instance.client;
  List<Map<String,dynamic>> _warehouses=[];
  List<Map<String,dynamic>> _documents=[];
  List<Map<String,dynamic>> _lines=[];
  List<Map<String,dynamic>> _employees=[];
  List<Map<String,dynamic>> _expenses=[];
  String? _warehouseId, _documentId, _targetId;
  String _targetType='employee', _countMode='detailed';
  bool _loading=false, _saving=false;
  String? _error, _message;
  bool get _isDraft => _documents.any((d)=>d['id']==_documentId && d['status']=='draft');
  double _n(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;
  String _s(dynamic v)=>(v??'').toString();
  double get _shortageValue => _lines.fold(0.0,(sum,l)=>sum+(_n(l['counted_quantity'])<_n(l['physical_snapshot'])?(_n(l['physical_snapshot'])-_n(l['counted_quantity']))*_n(l['valuation_price']):0));
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(()=>_loading=true); _error=null;
    try {
      final results=await Future.wait([
        _db.from('erp_warehouses').select('id,warehouse_code,warehouse_name,branch_id').eq('company_id',widget.companyId).eq('is_active',true).order('warehouse_code'),
        _db.from('erp_stocktakes').select('id,warehouse_id,status,count_mode,valuation_basis,notes,created_at,posted_at').eq('company_id',widget.companyId).order('created_at',ascending:false).limit(100),
        _db.from('erp_employees').select('id,employee_code,full_name').eq('company_id',widget.companyId).eq('is_active',true).order('employee_code'),
        _db.from('erp_stocktake_expense_items').select('id,item_code,name_ar').eq('company_id',widget.companyId).eq('is_active',true).order('item_code'),
      ]);
      if(!mounted)return;
      setState(()=>{
        _warehouses=List<Map<String,dynamic>>.from(results[0]);
        _documents=List<Map<String,dynamic>>.from(results[1]);
        _employees=List<Map<String,dynamic>>.from(results[2]);
        _expenses=List<Map<String,dynamic>>.from(results[3]);
        _warehouseId??=_warehouses.isEmpty?null:_s(_warehouses.first['id']);
        _loading=false;
      });
      if(_documentId!=null) await _loadLines(_documentId!);
    } catch(e){if(mounted)setState(()=>{_loading=false,_error='تعذر تحميل الجرد: $e'});}
  }
  Future<void> _loadLines(String id) async {
    setState(()=>_loading=true);
    try {
      final rows=await _db.from('erp_stocktake_lines').select('id,stocktake_id,company_id,item_id,available_snapshot,reserved_snapshot,physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,valuation_price,valuation_value').eq('stocktake_id',id).order('item_id');
      final lines=List<Map<String,dynamic>>.from(rows);
      final ids=lines.map((r)=>_s(r['item_id'])).toList();
      if(ids.isNotEmpty){
        final items=await _db.from('erp_items').select('id,item_code,item_name,base_unit').inFilter('id',ids);
        final byId={for(final item in items) _s(item['id']):Map<String,dynamic>.from(item)};
        for(final line in lines){line['_item']=byId[_s(line['item_id'])]??{};}
      }
      if(mounted)setState(()=>{_lines=lines,_documentId=id,_loading=false});
    }catch(e){if(mounted)setState(()=>{_loading=false,_error='تعذر تحميل بنود الجرد: $e'});}
  }
  Future<void> _create() async {
    if(_warehouseId==null){setState(()=>_error='اختر المخزن أولاً.');return;}
    setState(()=>{_saving=true,_error=null});
    try{
      final id=await _db.rpc('erp_create_physical_stocktake',params:{
        'p_company_id':widget.companyId,'p_warehouse_id':_warehouseId,
        'p_count_mode':_countMode,'p_valuation_basis':null,'p_notes':'جرد فعلي',
      });
      await _load();
      await _loadLines(id.toString());
      if(mounted)setState(()=>_message='تم إنشاء محضر الجرد ولقطة الأرصدة.');
    }catch(e){if(mounted)setState(()=>_error='تعذر إنشاء محضر الجرد: $e');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  Future<void> _saveDraft() async {
    if(_documentId==null||!_isDraft)return;
    setState(()=>{_saving=true,_error=null});
    try{
      for(final line in _lines){
        final counted=_n(line['counted_quantity']);
        await _db.from('erp_stocktake_lines').update({'counted_quantity':counted}).eq('id',line['id']).eq('stocktake_id',_documentId!);
      }
      await _loadLines(_documentId!);
      if(mounted)setState(()=>_message='تم حفظ كميات الجرد كمسودة دون تغيير أرصدة المخزون.');
    }catch(e){if(mounted)setState(()=>_error='تعذر حفظ كميات الجرد: $e');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  Future<void> _post() async {
    if(_documentId==null||!_isDraft)return;
    await _saveDraft();
    if(!mounted)return;
    if(_shortageValue>0&&_targetId==null){setState(()=>_error='اختر موظفاً أو بند صرف لتوجيه قيمة العجز قبل الترحيل.');return;}
    setState(()=>{_saving=true,_error=null});
    try{
      final result=await _db.rpc('erp_post_physical_stocktake',params:{
        'p_stocktake_id':_documentId,'p_target_type':_shortageValue>0?_targetType:null,
        'p_target_id':_shortageValue>0?_targetId:null,
      });
      await _load(); await _loadLines(_documentId!);
      if(mounted)setState(()=>_message='تم ترحيل الجرد وتحديث دفتر حركات المخزون. نتيجة الترحيل: $result');
    }catch(e){if(mounted)setState(()=>_error='تعذر ترحيل الجرد: $e');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  String _warehouseName(String id){final x=_warehouses.where((w)=>_s(w['id'])==id);return x.isEmpty?id:'${_s(x.first['warehouse_code'])} — ${_s(x.first['warehouse_name'])}';}
  @override
  Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Padding(
    padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Card(color:const Color(0xFF3E007D),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('الجرد الفعلي وتسوية الفروق',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(onPressed:_loading?null:_load,icon:const Icon(Icons.refresh,color:Colors.white),label:const Text('تحديث',style:TextStyle(color:Colors.white))),
          FilledButton.icon(onPressed:_saving?null:_create,icon:const Icon(Icons.add),label:const Text('محضر جرد جديد')),
          FilledButton.icon(onPressed:_saving||!_isDraft?null:_saveDraft,icon:const Icon(Icons.save),label:const Text('حفظ مسودة')),
          FilledButton.icon(onPressed:_saving||!_isDraft?null:_post,icon:const Icon(Icons.verified),label:const Text('اعتماد وترحيل')),
        ]),
      ]))),
      if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
      if(_message!=null)Text(_message!,style:const TextStyle(color:Colors.green)),
      if(_loading)const LinearProgressIndicator(),
      Row(children:[
        Expanded(child:DropdownButtonFormField<String>(value:_warehouseId,decoration:const InputDecoration(labelText:'المخزن',isDense:true),items:_warehouses.map((w)=>DropdownMenuItem(value:_s(w['id']),child:Text(_warehouseName(_s(w['id']))))).toList(),onChanged:(v)=>setState(()=>_warehouseId=v))),
        const SizedBox(width:10),
        Expanded(child:DropdownButtonFormField<String>(value:_countMode,decoration:const InputDecoration(labelText:'وضع الجرد',isDense:true),items:const [DropdownMenuItem(value:'default',child:Text('الوحدة الافتراضية للمخزن')),DropdownMenuItem(value:'detailed',child:Text('تفصيلي'))],onChanged:(v)=>setState(()=>_countMode=v??'detailed'))),
      ]),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(value:_documentId,decoration:const InputDecoration(labelText:'محاضر الجرد',isDense:true),items:_documents.map((d)=>DropdownMenuItem(value:_s(d['id']),child:Text('${_warehouseName(_s(d['warehouse_id']))} • ${_s(d['status'])=='posted'?'مرحّل':'مسودة'} • ${_s(d['created_at']).toString().split('T').first}'))).toList(),onChanged:(v){if(v!=null)_loadLines(v);}),
      if(_documentId!=null)...[
        const SizedBox(height:8),
        Text('تفصيل الأرصدة • متاح: ${_lines.fold<double>(0,(s,l)=>s+_n(l['available_snapshot'])).toStringAsFixed(2)} • حجز: ${_lines.fold<double>(0,(s,l)=>s+_n(l['reserved_snapshot'])).toStringAsFixed(2)} • عجز بالقيمة: ${_shortageValue.toStringAsFixed(2)} ج.م',style:const TextStyle(fontWeight:FontWeight.w800)),
        Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(
          columns:const [DataColumn(label:Text('م')),DataColumn(label:Text('كود الصنف')),DataColumn(label:Text('اسم الصنف')),DataColumn(label:Text('رصيد متاح')),DataColumn(label:Text('رصيد حجز')),DataColumn(label:Text('رصيد فعلي')),DataColumn(label:Text('الجرد الفعلي')),DataColumn(label:Text('الفرق')),DataColumn(label:Text('نوع الفرق')),DataColumn(label:Text('القيمة'))],
          rows:List.generate(_lines.length,(i){final l=_lines[i],item=l['_item'] as Map<String,dynamic>???{};final variance=_n(l['counted_quantity'])-_n(l['physical_snapshot']);final value=variance.abs()*_n(l['valuation_price']);return DataRow(cells:[
            DataCell(Text('${i+1}')),DataCell(Text(_s(item['item_code']))),DataCell(Text(_s(item['item_name']))),
            DataCell(Text(_n(l['available_snapshot']).toStringAsFixed(2))),DataCell(Text(_n(l['reserved_snapshot']).toStringAsFixed(2))),DataCell(Text(_n(l['physical_snapshot']).toStringAsFixed(2))),
            DataCell(SizedBox(width:105,child:TextFormField(initialValue:_n(l['counted_quantity']).toStringAsFixed(2),enabled:_isDraft,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(v)=>setState(()=>l['counted_quantity']=double.tryParse(v)??0),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder())))),
            DataCell(Text(variance.toStringAsFixed(2),style:TextStyle(color:variance<0?Colors.red:variance>0?Colors.green:Colors.black,fontWeight:FontWeight.w800))),
            DataCell(Text(variance<0?'عجز':variance>0?'زيادة':'مطابق',style:TextStyle(color:variance<0?Colors.red:variance>0?Colors.green:Colors.black))),
            DataCell(Text(value.toStringAsFixed(2))),
          ]);}),
        )))),
        if(_shortageValue>0&&_isDraft)...[
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:DropdownButtonFormField<String>(value:_targetType,decoration:const InputDecoration(labelText:'توجيه العجز إلى',isDense:true),items:const [DropdownMenuItem(value:'employee',child:Text('موظف')),DropdownMenuItem(value:'expense',child:Text('بند صرف'))],onChanged:(v)=>setState(()=>{_targetType=v??'employee',_targetId=null}))),
            const SizedBox(width:8),
            Expanded(child:DropdownButtonFormField<String>(value:_targetId,decoration:InputDecoration(labelText:_targetType=='employee'?'الموظف':'بند الصرف',isDense:true),items:(_targetType=='employee'?_employees:_expenses).map((x)=>DropdownMenuItem(value:_s(x['id']),child:Text(_targetType=='employee'?' ${_s(x['employee_code'])} — ${_s(x['full_name'])}':'${_s(x['item_code'])} — ${_s(x['name_ar'])}'))).toList(),onChanged:(v)=>setState(()=>_targetId=v))),
          ]),
        ],
      ],
    ]),
  ));
}
