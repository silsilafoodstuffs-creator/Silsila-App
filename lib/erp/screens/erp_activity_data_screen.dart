import 'package:flutter/material.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'erp_activity_types_screen.dart';
import 'erp_item_categories_screen.dart';

/// Activity and item-category masters. Keep one category editor alive so
/// switching category levels never creates duplicate full-catalog loaders.
class ErpActivityDataScreen extends StatefulWidget {
  const ErpActivityDataScreen({super.key, this.companyId});
  final String? companyId;

  @override
  State<ErpActivityDataScreen> createState() => _ErpActivityDataScreenState();
}

class _ErpActivityDataScreenState extends State<ErpActivityDataScreen> {
  int _selectedTab = 0;
  late Widget _activityTypes;
  late Widget _itemCategories;

  static const _tabs = <String>[
    'أنواع الأنشطة',
    'فئات الأصناف',
  ];

  @override
  void initState() {
    super.initState();
    _createScreens();
  }

  void _createScreens() {
    _activityTypes = ErpActivityTypesScreen(
      key: ValueKey('activity-types-${widget.companyId}'),
      companyId: widget.companyId,
      hideHeader: true,
    );
    // One stateful screen owns the complete three-level category catalog and
    // the brands tab. Its internal tabs filter the same in-memory dataset.
    _itemCategories = ErpItemCategoriesScreen(
      key: ValueKey('item-categories-${widget.companyId}'),
      companyId: widget.companyId,
    );
  }

  @override
  void didUpdateWidget(covariant ErpActivityDataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _createScreens();
    }
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions();
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
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [_activityTypes, _itemCategories],
            ),
          ),
        ],
      ),
    );
  }
}
