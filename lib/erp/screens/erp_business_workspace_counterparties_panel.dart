import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _partyPurple = Color(0xFF3E007D);

class ErpBusinessWorkspaceCounterpartiesPanel extends StatefulWidget {
  final String workspaceId;
  final bool canManageCustomers;
  final bool canManageSuppliers;
  const ErpBusinessWorkspaceCounterpartiesPanel({
    super.key,
    required this.workspaceId,
    required this.canManageCustomers,
    required this.canManageSuppliers,
  });
  @override
  State<ErpBusinessWorkspaceCounterpartiesPanel> createState() => _ErpBusinessWorkspaceCounterpartiesPanelState();
}

class _ErpBusinessWorkspaceCounterpartiesPanelState extends State<ErpBusinessWorkspaceCounterpartiesPanel> {
  final _db = Supabase.instance.client;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _governorate = TextEditingController();
  final _district = TextEditingController();
  final _area = TextEditingController();
  String _type = 'customer';
  String? _preview;
  bool _saving = false;
  bool _loading = true;
  List<Map<String,dynamic>> _rows = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() {
    _code.dispose(); _name.dispose(); _phone.dispose(); _address.dispose();
    _governorate.dispose(); _district.dispose(); _area.dispose(); super.dispose();
  }
  bool get _canManage => _type == 'customer' ? widget.canManageCustomers : widget.canManageSuppliers;
  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final rows=await _db.from('erp_business_workspace_counterparties').select(
        'id,party_type,party_code,display_name,phone,address,governorate,district,area,is_active'
      ).eq('workspace_id',widget.workspaceId).order('display_name');
      if(mounted)setState(()=>_rows=List<Map<String,dynamic>>.from(rows));
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل الدفتر: $e'))); }
    finally { if(mounted)setState(()=>_loading=false); }
  }
  Future<void> _previewPhone(String value) async {
    final digits=value.replaceAll(RegExp(r'[^0-9]'),'');
    if(digits.length<10){setState(()=>_preview=null);return;}
    try {
      final result=await _db.rpc('erp_find_silsila_profile_by_phone',params:{
        'p_workspace_id':widget.workspaceId,'p_phone':value,
      });
      if(!mounted||_phone.text!=value)return;
      final rows=List<Map<String,dynamic>>.from(result as List);
      setState(()=>_preview=rows.isEmpty?null:(rows.first['profile_name']??'مسجل في سلسلة').toString());
    } catch (_) { if(mounted&&_phone.text==value)setState(()=>_preview=null); }
  }
  Future<void> _save() async {
    if(!_canManage||_code.text.trim().isEmpty||_name.text.trim().length<2)return;
    setState(()=>_saving=true);
    try {
      await _db.from('erp_business_workspace_counterparties').insert({
        'workspace_id':widget.workspaceId,'party_type':_type,
        'party_code':_code.text.trim(),'display_name':_name.text.trim(),
        'phone':_phone.text.trim().isEmpty?null:_phone.text.trim(),
        'address':_address.text.trim().isEmpty?null:_address.text.trim(),
        'governorate':_governorate.text.trim().isEmpty?null:_governorate.text.trim(),
        'district':_district.text.trim().isEmpty?null:_district.text.trim(),
        'area':_area.text.trim().isEmpty?null:_area.text.trim(),
        'created_by':_db.auth.currentUser!.id,
      });
      _code.clear();_name.clear();_phone.clear();_address.clear();_governorate.clear();_district.clear();_area.clear();_preview=null;
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم الحفظ في دفتر النشاط المستقل.')));
    } catch(e) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحفظ: $e'))); }
    finally { if(mounted)setState(()=>_saving=false); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding:const EdgeInsets.all(8),children:[
    const Text('عملاء وموردو نشاطي',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:_partyPurple)),
    const Text('دفتر مستقل عن بيانات سلسلة وعن دفاتر الأنشطة الأخرى.'),
    const SizedBox(height:10),
    Wrap(spacing:8,children:[
      ChoiceChip(label:const Text('عملاء نشاطي'),selected:_type=='customer',onSelected:(_)=>setState(()=>_type='customer')),
      ChoiceChip(label:const Text('موردو نشاطي'),selected:_type=='supplier',onSelected:(_)=>setState(()=>_type='supplier')),
    ]),
    if(_canManage)...[
      TextField(controller:_code,decoration:const InputDecoration(labelText:'رقم العميل / المورد')),
      TextField(controller:_name,decoration:const InputDecoration(labelText:'اسم العميل / المورد')),
      TextField(controller:_phone,keyboardType:TextInputType.phone,onChanged:_previewPhone,decoration:const InputDecoration(labelText:'رقم الموبايل')),
      if(_preview!=null) Container(margin:const EdgeInsets.symmetric(vertical:6),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.blue.withValues(alpha:.08),borderRadius:BorderRadius.circular(10)),child:Text('معاينة فقط — الاسم المسجل في سلسلة: $_preview',style:const TextStyle(color:Colors.blue,fontWeight:FontWeight.w700))),
      TextField(controller:_address,decoration:const InputDecoration(labelText:'العنوان')),
      Row(children:[Expanded(child:TextField(controller:_governorate,decoration:const InputDecoration(labelText:'المحافظة'))),const SizedBox(width:8),Expanded(child:TextField(controller:_district,decoration:const InputDecoration(labelText:'المركز / الحي')))]),
      TextField(controller:_area,decoration:const InputDecoration(labelText:'المنطقة / القرية')),
      Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_saving?null:_save,icon:const Icon(Icons.save),label:const Text('حفظ'))),
    ],
    const Divider(height:24),
    if(_loading)const Center(child:CircularProgressIndicator()) else ..._rows.where((r)=>r['party_type']==_type).map((r)=>Card(elevation:0,child:ListTile(
      leading:Icon(_type=='customer'?Icons.person_outline:Icons.local_shipping_outlined,color:_partyPurple),
      title:Text('${r['party_code']} • ${r['display_name']}'),
      subtitle:Text([r['phone'],r['governorate'],r['district'],r['area']].where((x)=>x!=null&&x.toString().isNotEmpty).join(' • ')),
      trailing:Text(r['is_active']==true?'نشط':'غير نشط'),
    ))),
  ]);
}
