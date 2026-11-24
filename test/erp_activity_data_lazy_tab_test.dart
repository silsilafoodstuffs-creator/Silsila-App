import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity data screen mounts only the selected category tab', () {
    final source = File('lib/erp/screens/erp_activity_data_screen.dart')
        .readAsStringSync();

    expect(source, contains('final Map<int, Widget> _tabWidgets'));
    expect(source, contains('Widget _buildTab(int tab)'));
    expect(source, contains('_tabWidgets.putIfAbsent(_selectedTab'));
    expect(source, contains('(tab) => _tabWidgets[tab] ?? const SizedBox.shrink()'));
    expect(source, contains('IndexedStack(index: _selectedTab, children: children)'));
    expect(source, contains('initialCatalogTab: tab - 1'));
    expect(source, isNot(contains('for (var tab = 0; tab < 4; tab++)')));
    expect(source, contains('if (oldWidget.companyId != widget.companyId)'));
  });
}
