import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:silsila_app/services/auth_service.dart';

void main() {
  late AuthService auth;

  setUp(() {
    auth = AuthService(
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
    );
  });

  test('rejects malformed email before making an auth request', () async {
    await expectLater(
      auth.login(email: 'not-an-email', password: 'StrongPass1!'),
      throwsArgumentError,
    );
  });

  test('rejects missing password before making an auth request', () async {
    await expectLater(
      auth.login(email: 'trader@example.com', password: ''),
      throwsArgumentError,
    );
  });

  test('rejects weak password during email registration', () async {
    await expectLater(
      auth.register(email: 'trader@example.com', password: 'weak'),
      throwsArgumentError,
    );
  });

  test('does not claim a session when no user is signed in', () {
    expect(auth.isLoggedIn, isFalse);
    expect(auth.currentUserId, isNull);
    expect(auth.currentEmail, isNull);
  });
}
