import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpCodePolicyService {
  ErpCodePolicyService(this.db);
  final SupabaseClient db;

  Future<Map<String,dynamic>> load(String companyId) async {
    final row = await db.from('erp_program_policies').select('policy_value')
      .eq('company_id',companyId).eq('policy_key','code_generation_registry').maybeSingle();
    if (row == null || (row['policy_value']??'').toString().isEmpty) return {'item_prefix':'itm','types':{}};
    return Map<String,dynamic>.from(jsonDecode(row['policy_value'].toString()) as Map);
  }

  Future<String> nextItemCode({required String companyId, required String? categoryId}) async {
    final cfg = await load(companyId);
    final prefix = (cfg['item_prefix'] ?? 'itm').toString();
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(prefix)) throw StateError('بادئة كود الصنف غير صحيحة.');
    if (categoryId == null || categoryId.isEmpty) throw StateError('يجب اختيار فئة رئيسية وفرعية وثانوية قبل توليد كود الصنف.');
    final categories = await db.from('erp_item_categories')
      .select('id,parent_id,category_code,is_active').eq('company_id',companyId).eq('is_active',true);
    final rows = List<Map<String,dynamic>>.from(categories);
    final byId = {for(final row in rows) row['id'].toString():row};
    final selected = byId[categoryId];
    if (selected == null) throw StateError('فئة الصنف المختارة غير موجودة أو غير نشطة.');
    final hierarchy = <Map<String,dynamic>>[selected];
    var parent = selected['parent_id']?.toString();
    while (parent != null && parent.isNotEmpty) {
      final row = byId[parent];
      if (row == null) break;
      hierarchy.insert(0,row);
      parent = row['parent_id']?.toString();
    }
    if (hierarchy.length != 3) throw StateError('يجب ربط الصنف بفئة رئيسية وفرعية وثانوية لاكتمال كود الصنف.');
    final segments = <String>[];
    for (var level=0; level<3; level++) {
      final node = hierarchy[level];
      final parentId = node['parent_id']?.toString();
      final siblings = rows.where((r)=>(r['parent_id']?.toString() ?? '')==(parentId ?? '')).toList()
        ..sort((a,b)=>(a['category_code']??'').toString().compareTo((b['category_code']??'').toString()));
      final index = siblings.indexWhere((r)=>r['id'].toString()==node['id'].toString())+1;
      if (index < 1 || index > 99) throw StateError('عدد الفئات في المستوى الواحد يجب ألا يتجاوز 99 فئة لتكوين الكود.');
      segments.add(index.toString().padLeft(2,'0'));
    }
    final categoryPrefix = '$prefix${segments.join()}';
    final existing = await db.from('erp_items').select('item_code').eq('company_id',companyId).like('item_code','$categoryPrefix%');
    var maxSerial = 0;
    for(final row in (existing as List)) {
      final code = (row['item_code']??'').toString();
      if(code.length != categoryPrefix.length+2) continue;
      final serial = int.tryParse(code.substring(categoryPrefix.length));
      if(serial != null && serial > maxSerial) maxSerial = serial;
    }
    if(maxSerial >= 99) throw StateError('اكتمل الحد الأقصى وهو 99 صنفاً داخل هذه الفئات.');
    return '$categoryPrefix${(maxSerial+1).toString().padLeft(2,'0')}';
  }
}
