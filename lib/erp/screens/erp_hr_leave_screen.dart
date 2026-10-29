import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../services/erp_hr_repository.dart';

class ErpHrLeaveScreen extends StatefulWidget {
  const ErpHrLeaveScreen({super.key,this.initialCompanyId});
  final String? initialCompanyId;
  @override State<ErpHrLeaveScreen> createState()=>_ErpHrLeaveScreenState();
}
class _ErpHrLeaveScreenState extends State<ErpHrLeaveScreen>{
  final _repo=ErpHrRepository(),_company=TextEditingController();
  List<Map<String,dynamic>> employees=[],requests=[];
  bool loading=false,saving=false;
  String? error,message;
  static const purple=Color(0xFF3E007D),orange=Color(0xFFFFA015);
  @override void initState(){super.initState();_company.text=widget.initialCompanyId??'';if(_company.text.isNotEmpty)WidgetsBinding.instance.addPostFrameCallback((_)=>load());}
  @override void dispose(){_company.dispose();super.dispose();}
  String s(dynamic v)=>(v??'').toString();
  String date(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String name(dynamic id){final list=employees.where((e)=>s(e['id'])==s(id));return list.isEmpty?s(id):'${s(list.first['employee_code'])} — ${s(list.first['full_name'])}';}
  Future<void> load()async{if(_company.text.trim().isEmpty){setState(()=>error='أدخل معرّف الشركة أولًا.');return;}setState((){loading=true;error=null;message=null;});try{final v=await Future.wait([_repo.fetchEmployees(_company.text.trim()),_repo.fetchLeaveRequests(_company.text.trim())]);if(!mounted)return;setState((){employees=v[0];requests=v[1];loading=false;});}catch(e){if(mounted)setState((){loading=false;error='تعذر تحميل الإجازات: $e';});}}
  Widget task(String l,IconData i,Color c,VoidCallback? f)=>ErpQuickTaskButton(label:l,icon:i,onPressed:f,fallbackColor:c);
  Widget notice(String t,Color c)=>Container(margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:c.withValues(alpha:.09),borderRadius:BorderRadius.circular(9)),child:Text(t,style:TextStyle(color:c)));
  Future<void> createLeave()async{
    if(employees.isEmpty){setState(()=>error='لا توجد بيانات موظفين؛ حمّل بيانات الموظفين أولًا.');return;}
    String? employeeId=s(employees.first['id']),type='سنوية',err;DateTime start=DateTime.now(),end=DateTime.now();final reason=TextEditingController();
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:const Text('طلب إجازة جديد'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(value:employeeId,isExpanded:true,decoration:const InputDecoration(labelText:'الموظف'),items:employees.map((e)=>DropdownMenuItem(value:s(e['id']),child:Text('${s(e['employee_code'])} • ${s(e['full_name'])}',overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>refresh(()=>employeeId=v)),
      DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'نوع الإجازة'),items:const [DropdownMenuItem(value:'سنوية',child:Text('سنوية')),DropdownMenuItem(value:'عارضة',child:Text('عارضة')),DropdownMenuItem(value:'مرضية',child:Text('مرضية')),DropdownMenuItem(value:'إصابة عمل',child:Text('إصابة عمل')),DropdownMenuItem(value:'رسمية',child:Text('رسمية')),DropdownMenuItem(value:'بدون أجر',child:Text('بدون أجر'))],onChanged:(v)=>refresh(()=>type=v)),
      OutlinedButton(onPressed:()async{final v=await showDatePicker(context:ctx,initialDate:start,firstDate:DateTime(2000),lastDate:DateTime(2100));if(v!=null)refresh(()=>start=v);},child:Text('من: ${date(start)}')),
      OutlinedButton(onPressed:()async{final v=await showDatePicker(context:ctx,initialDate:end,firstDate:DateTime(2000),lastDate:DateTime(2100));if(v!=null)refresh(()=>end=v);},child:Text('إلى: ${date(end)}')),
      TextField(controller:reason,maxLines:2,decoration:const InputDecoration(labelText:'السبب / الملاحظات')),if(err!=null)Text(err!,style:const TextStyle(color:Colors.red)),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{if(employeeId==null||start.isAfter(end)){refresh(()=>err='اختر الموظف وتأكد من ترتيب التاريخين.');return;}Navigator.pop(ctx);setState(()=>saving=true);try{await _repo.createLeaveRequest(companyId:_company.text.trim(),employeeId:employeeId!,leaveType:type??'سنوية',start:start,end:end,reason:reason.text);if(mounted)setState(()=>message='تم إنشاء طلب الإجازة في انتظار الاعتماد.');await load();}catch(e){if(mounted)setState(()=>error='تعذر إنشاء الطلب: $e');}finally{if(mounted)setState(()=>saving=false);}},child:const Text('حفظ الطلب'))])));
    reason.dispose();
  }
  Future<void> decide(Map<String,dynamic> r,String action)async{setState(()=>saving=true);try{await _repo.decideLeave(s(r['id']),action);if(mounted)setState(()=>message=action=='approved'?'تم اعتماد طلب الإجازة.':'تم رفض طلب الإجازة.');await load();}catch(e){if(mounted)setState(()=>error='تعذر تحديث الطلب: $e');}finally{if(mounted)setState(()=>saving=false);}}
  Future<void> preview()async{await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('معاينة الإجازات'),content:SizedBox(width:650,child:requests.isEmpty?const Text('لا توجد طلبات إجازة.'):SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:requests.take(100).map((r)=>ListTile(title:Text(name(r['employee_id'])),subtitle:Text('${s(r['leave_type'])} • ${s(r['starts_on'])} إلى ${s(r['ends_on'])} • ${s(r['status'])}'))).toList()))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));}
  @override
  Widget build(BuildContext context) {
    final tasks = Row(children: [
      task('تحديث', Icons.refresh, Colors.blue, loading ? null : load),
      task('إضافة', Icons.add_circle_outline, const Color(0xFF168447), saving ? null : createLeave),
      task('حفظ', Icons.save_outlined, const Color(0xFF168447), null),
      task('تعديل', Icons.edit_outlined, orange, null),
      task('حذف', Icons.delete_outline, Colors.red, null),
      task('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), preview),
      task('طباعة', Icons.print_outlined, const Color(0xFF536DFE), () => setState(() => message = 'استخدم طباعة المتصفح بعد فتح المعاينة.')),
      task('Excel', Icons.table_view_outlined, const Color(0xFF168447), () => setState(() => message = 'تصدير Excel غير مربوط حتى الآن.')),
      task('PDF', Icons.picture_as_pdf_outlined, Colors.red, () => setState(() => message = 'تصدير PDF غير مربوط حتى الآن.')),
    ]);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: purple,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('الإجازات والأذونات', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  const Text('طلبات الإجازة • الاعتماد • سجل القرارات', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: tasks),
                ],
              ),
            ),
          ),
          TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
          if (error != null) notice(error!, Colors.red),
          if (message != null) notice(message!, Colors.green),
          if (loading || saving) const LinearProgressIndicator(),
          Row(
            children: [
              Expanded(child: Text('طلبات الإجازات • ${requests.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              FilledButton.icon(onPressed: saving ? null : createLeave, icon: const Icon(Icons.add), label: const Text('طلب جديد')),
            ],
          ),
          Expanded(
            child: requests.isEmpty
                ? const Center(child: Text('لا توجد طلبات إجازة مسجلة.'))
                : ListView(
                    children: requests.map((r) {
                      final status = s(r['status']);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(name(r['employee_id']), style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text('${s(r['leave_type'])} • ${s(r['starts_on'])} إلى ${s(r['ends_on'])} • ${s(r['requested_days'])} يوم'),
                              if (s(r['reason']).isNotEmpty) Text('السبب: ${s(r['reason'])}'),
                              Row(
                                children: [
                                  Chip(label: Text(status)),
                                  const Spacer(),
                                  if (status == 'pending') TextButton(onPressed: saving ? null : () => decide(r, 'rejected'), child: const Text('رفض')),
                                  if (status == 'pending') FilledButton(onPressed: saving ? null : () => decide(r, 'approved'), child: const Text('اعتماد')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
