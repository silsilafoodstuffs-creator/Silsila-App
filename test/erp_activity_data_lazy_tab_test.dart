import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity data screen mounts only the selected category tab', () {
    final source = File('lib/erp/screens/erp_activity_data_screen.dart')
        .readAsStringSync();

    expect(source, contains('final Widget selectedContent = _selectedTab == 0'));
    expect(source, contains('initialCatalogTab: _selectedTab - 1'));
    expect(source, contains('child: selectedContent'));
    expect(source, contains('ValueKey(\'activity-data-tab-'));
    expect(source, isNot(contains('IndexedStack(')));
    expect(source, isNot(contains('for (var tab = 0; tab < 4; tab++)')));
  });
}
