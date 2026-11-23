import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('destructive geographic rebuild RPC is not exposed to client roles', () {
    final migration = File(
      'supabase/migrations/20261123020000_restrict_geographic_rebuild_rpc.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'revoke all on function public.erp_rebuild_geographic_hierarchical_codes(uuid)',
      ),
    );
    expect(migration, contains('from public, anon, authenticated'));
    expect(
      migration,
      contains(
        'grant execute on function public.erp_rebuild_geographic_hierarchical_codes(uuid)',
      ),
    );
    expect(migration, contains('to service_role'));

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final appSource = dartFiles.map((file) => file.readAsStringSync()).join('\n');
    expect(
      appSource,
      isNot(contains('erp_rebuild_geographic_hierarchical_codes')),
      reason: 'The RPC has no app call site; keep maintenance-only access.',
    );
  });
}
