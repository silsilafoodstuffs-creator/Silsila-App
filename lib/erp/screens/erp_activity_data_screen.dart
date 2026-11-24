import 'package:flutter/material.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'erp_activity_types_screen.dart';
import 'erp_item_categories_screen.dart';

/// Unified activity master: activity data first, followed by the five
/// existing item-category tabs without changing their underlying workflows.
class ErpActivityDataScreen extends StatefulWidget {
  const ErpActivityDataScreen({super.key, this.companyId});
  final String? companyId;

  @override
  State<ErpActivityDataScreen> createState() => _ErpActivityDataScreenState();
}

class _ErpActivityDataScreenState extends State<ErpActivityDataScreen> {
  int _selectedTab = 0;
  static const _tabs = <String>[
    'أنواع الأنشطة',
    'الفئة الرئيسية',
    'الفئة الفرعية',
    'الفئة الثانوية',
    'البراندات/الماركات',
  ];

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions();
    final Widget selectedContent = _selectedTab == 0
        ? ErpActivityTypesScreen(
            key: ValueKey('activity-types-${widget.companyId}'),
            companyId: widget.companyId,
            hideHeader: true,
          )
        : ErpItemCategoriesScreen(
            key: ValueKey('activity-category-${_selectedTab - 1}-${widget.companyId}'),
            companyId: widget.companyId,
            initialCatalogTab: _selectedTab - 1,
            hideHeaderAndTabs: true,
          );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF3E007D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(children: [
              Icon(Icons.account_tree_outlined, color: Colors.white),
              SizedBox(width: 8),
              Text('أنواع وفئات الأنشطة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              Spacer(),
              Text('إدارة البرنامج • بيانات أساسية', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var tab = 0; tab < _tabs.length; tab++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 5),
                    child: ChoiceChip(
                      label: Text(_tabs[tab]),
                      selected: _selectedTab == tab,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTab = tab);
                      },
                      selectedColor: const Color(0xFF3E007D),
                      backgroundColor: const Color(0xFFF7F5FA),
                      labelStyle: TextStyle(
                        color: _selectedTab == tab ? Colors.white : const Color(0xFF3E007D),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(child: KeyedSubtree(
            key: ValueKey('activity-data-tab-${_selectedTab}-${widget.companyId}'),
            child: selectedContent,
          )),
        ],
      ),
    );
  }
}
