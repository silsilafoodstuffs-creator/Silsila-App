import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RLS initplan migration preserves guarded policies and wraps auth.uid()', () {
    final sql = File(
      'supabase/migrations/20261123021000_optimize_auth_rls_policy_initplans.sql',
    ).readAsStringSync();

    const policyNames = <String>[
      'erp_scope_guard_erp_cash_movements',
      'erp_studio_audit_insert_admin',
      'erp_studio_versions_insert_admin',
      'erp_studio_designs_insert_admin',
      'erp_studio_designs_update_admin',
      'erp_studio_layout_profiles_insert_permission',
      'erp_studio_layout_profiles_update_permission',
      'story_favorites_manage_own',
      'story_hidden_manage_own',
      'supplier_offer_customer_categories_own',
    ];
    for (final name in policyNames) {
      expect(sql, contains('alter policy $name'));
    }

    expect(sql, contains('(select auth.uid())'));
    expect(sql, contains('erp_user_has_company_role'));
    expect(sql, contains('erp_user_can_access_branch_scope'));
    expect(sql, contains('private.erp_studio_has_action_permission'));
    expect(sql, contains('v_actor_id uuid := (select auth.uid())'));
    expect(sql, contains('and pm.user_id = v_actor_id'));
    expect(sql.trimLeft().startsWith('--'), isTrue);
    expect(sql.toLowerCase(), contains('begin;'));
    expect(sql.toLowerCase(), contains('commit;'));
  });
}
