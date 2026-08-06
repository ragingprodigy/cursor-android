import 'package:cursor/app/app.dart';
import 'package:cursor/app/di.dart';
import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthSessionRepository extends Mock
    implements AuthSessionRepository {}

void main() {
  testWidgets('shows connect screen when unauthenticated', (
    WidgetTester tester,
  ) async {
    final authSession = _MockAuthSessionRepository();
    when(() => authSession.isAuthenticated).thenReturn(false);
    when(() => authSession.currentInfo).thenReturn(null);
    when(() => authSession.restore()).thenAnswer((_) async => null);

    final dependencies = AppDependencies(
      config: const AppConfig(apiBaseUrl: 'https://api.example.test'),
      database: AppDatabase.memory(),
      authSession: authSession,
    );

    await tester.pumpWidget(CursorApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('Connect your Cursor account'), findsOneWidget);
  });
}
