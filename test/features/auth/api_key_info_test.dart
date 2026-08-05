import 'package:flutter_test/flutter_test.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';

void main() {
  test('parses user-scoped /v1/me payload', () {
    final info = ApiKeyInfo.fromJson({
      'apiKeyName': 'Production API Key',
      'userId': 42,
      'createdAt': '2026-04-13T18:30:00.000Z',
      'userEmail': 'developer@example.com',
    });
    expect(info.apiKeyName, 'Production API Key');
    expect(info.userEmail, 'developer@example.com');
    expect(info.userId, 42);
  });
}
