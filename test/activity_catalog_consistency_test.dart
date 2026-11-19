import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/services/activity_service.dart';

void main() {
  test('fallback activity catalogue contains the canonical 01..20 sequence', () {
    final activities = ActivityService.fallbackActivities;
    final codes = activities.map((activity) => activity['code']).toList();

    expect(codes, List<String>.generate(20, (index) => (index + 1).toString().padLeft(2, '0')));
    expect(activities.every((activity) => (activity['name'] ?? '').trim().isNotEmpty), isTrue);
  });

  test('database migration seeds all 20 activity codes in both catalogues', () {
    final migration = File(
      'supabase/migrations/20261118134000_unify_activity_codes_and_seed_all_activities.sql',
    );
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    final tupleMatches = RegExp(r"\('([0-9]{2})','[^']*','[^']*',[0-9]+\)")
        .allMatches(sql);
    final counts = <String, int>{};
    for (final match in tupleMatches) {
      final code = match.group(1)!;
      counts[code] = (counts[code] ?? 0) + 1;
    }

    final expectedCodes = List<String>.generate(
      20,
      (index) => (index + 1).toString().padLeft(2, '0'),
    );
    expect(counts.keys.toSet(), expectedCodes.toSet());
    for (final code in expectedCodes) {
      expect(counts[code], 2, reason: 'Activity $code must be seeded in both tables.');
    }
    expect(sql, contains('ON CONFLICT (code) DO UPDATE SET'));
    expect(sql, contains('ON CONFLICT (company_id, page_key, record_key) DO NOTHING'));
  });
}
