import 'package:flutter/material.dart';

const _branchPurple = Color(0xFF3E007D);
const _branchOrange = Color(0xFFFFA015);

/// تصميم تجريبي مستقل لفروع الشركة.
/// لا يتصل بقاعدة البيانات ولا يقرأ أو يغيّر سجلات الفروع الحالية.
class ErpCompanyBranchesDesignScreen extends StatefulWidget {
  const ErpCompanyBranchesDesignScreen({super.key});

  @override
  State<ErpCompanyBranchesDesignScreen> createState() =>
      _ErpCompanyBranchesDesignScreenState();
}

class _ErpCompanyBranchesDesignScreenState
    extends State<ErpCompanyBranchesDesignScreen> {
  final List<_BranchDraft> _branches = [_BranchDraft(number: 1)];
  int _nextNumber = 2;

  void _addBranch() => setState(() {
    _branches.add(_BranchDraft(number: _nextNumber++));
  });

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _field(String label, {double width = 190, String? initial}) =>
      SizedBox(
        width: width,
        child: TextFormField(
          initialValue: initial,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _choice(String label, List<String> options, {double width = 180}) =>
      SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          value: options.first,
          isExpanded: true,
          itemHeight: 40,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (_) {},
        ),
      );

  Widget _uploadButton(String label, IconData icon) => OutlinedButton.icon(
    onPressed: () => _message('واجهة تصميمية فقط — سيتم تفعيل الاستيراد بعد اعتماد الشاشة.'),
    icon: Icon(icon, size: 17),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: _branchPurple,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    ),
  );

  Widget _section(int number, String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 27, height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _branchPurple.withValues(alpha: .08), borderRadius: BorderRadius.circular(7)),
          child: Text('$number', style: const TextStyle(color: _branchPurple, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [child])),
      ],
    ),
  );

  Widget _branchCard(_BranchDraft branch) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(color: _branchPurple.withValues(alpha: .18)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('الفرع رقم ${branch.number}', style: const TextStyle(color: _branchPurple, fontWeight: FontWeight.w900, fontSize: 15)),
          const Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('رئيسي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            Checkbox(value: branch.isMain, onChanged: (v) => setState(() { for (final item in _branches) { item.isMain = false; } branch.isMain = v ?? false; }), visualDensity: VisualDensity.compact, activeColor: _branchPurple),
            const SizedBox(width: 3),
            const Text('نشط', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Checkbox(value: branch.isActive, onChanged: (v) => setState(() => branch.isActive = v ?? false), visualDensity: VisualDensity.compact, activeColor: _branchPurple),
            IconButton(tooltip: 'حذف التصميم', onPressed: _branches.length == 1 ? null : () => setState(() => _branches.remove(branch)), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
          ]),
        ]),
        const Divider(height: 12),
        _section(1, 'البيانات الأساسية',
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 42, child: Text('${branch.number}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
            _field('كود الفرع', width: 135, initial: 'Brn${branch.number.toString().padLeft(2, '0')}'),
            const SizedBox(width: 8),
            _field('اسم الفرع عربي', width: 190, initial: branch.number == 1 ? 'الفرع الرئيسي' : null),
            const SizedBox(width: 8),
            _field('اسم الفرع إنجليزي', width: 190),
            const SizedBox(width: 8),
            Container(width: 54, height: 48, decoration: BoxDecoration(color: const Color(0xFFF7F5FA), border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.store_mall_directory_outlined, color: _branchPurple, size: 25)),
            const SizedBox(width: 8),
            _uploadButton('استيراد من الجهاز', Icons.upload_file),
            _uploadButton('استيراد من الكاميرا', Icons.camera_alt_outlined),
          ]),
        ),
        _section(2, 'الموقع الجغرافي',
          Row(mainAxisSize: MainAxisSize.min, children: [
            _choice('الدولة', const ['مصر', 'السعودية', 'الإمارات']),
            _choice('المحافظة', const ['اختر المحافظة', 'القاهرة', 'الجيزة', 'القليوبية']),
            _choice('حي / مركز', const ['اختر الحي / المركز', 'مدينة العبور', 'شبرا الخيمة']),
            _choice('منطقة / قرية', const ['اختر المنطقة / القرية', 'الحي الأول', 'الحي الثاني']),
          ]),
        ),
        _section(3, 'العنوان والموقع',
          Row(mainAxisSize: MainAxisSize.min, children: [
            _field('عنوان الفرع', width: 520),
            _uploadButton('استيراد موقع من الخريطة', Icons.map_outlined),
            _uploadButton('معاينة الموقع', Icons.location_on_outlined),
          ]),
        ),
        _section(4, 'بيانات الاتصال',
          Row(mainAxisSize: MainAxisSize.min, children: [
            _field('موبايل الفرع 1', width: 175),
            _field('موبايل الفرع 2', width: 175),
            _field('أرضي الفرع', width: 175),
            _field('إيميل الفرع', width: 230),
          ]),
        ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: _branchPurple, borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          const Icon(Icons.account_tree_outlined, color: _branchOrange, size: 25),
          const SizedBox(width: 9),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('فروع الشركة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            Text('تصميم تجريبي مستقل — لا توجد أي صلة ببيانات الفروع الحالية', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          FilledButton.icon(onPressed: _addBranch, icon: const Icon(Icons.add, size: 18), label: const Text('إضافة فرع'), style: FilledButton.styleFrom(backgroundColor: _branchOrange, foregroundColor: Colors.black87)),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 1120, child: Column(children: _branches.map(_branchCard).toList())),
        ),
      )),
    ]),
  );
}

class _BranchDraft {
  _BranchDraft({required this.number, this.isMain = false, this.isActive = true});
  final int number;
  bool isMain;
  bool isActive;
}
