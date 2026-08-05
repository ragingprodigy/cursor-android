import 'package:bloc_test/bloc_test.dart';
import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';
import 'package:cursor/features/auth/presentation/connect_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthSessionRepository extends Mock
    implements AuthSessionRepository {}

void main() {
  late AuthSessionRepository repository;

  final info = ApiKeyInfo(
    apiKeyName: 'Production API Key',
    userEmail: 'developer@example.com',
    userId: 42,
    createdAt: DateTime.parse('2026-04-13T18:30:00.000Z'),
  );

  setUp(() {
    repository = _MockAuthSessionRepository();
  });

  blocTest<ConnectBloc, ConnectState>(
    'submit valid key emits authenticated',
    build: () {
      when(() => repository.connect('valid-key')).thenAnswer((_) async => info);
      return ConnectBloc(repository);
    },
    act: (bloc) => bloc.add(const ConnectSubmitted(' valid-key ')),
    expect: () => [
      const ConnectState.submitting(),
      ConnectState.authenticated(info),
    ],
    verify: (_) {
      verify(() => repository.connect('valid-key')).called(1);
    },
  );

  blocTest<ConnectBloc, ConnectState>(
    'repository unauthorized emits failure message',
    build: () {
      when(
        () => repository.connect('invalid-key'),
      ).thenThrow(const UnauthorizedException('Invalid API key'));
      return ConnectBloc(repository);
    },
    act: (bloc) => bloc.add(const ConnectSubmitted('invalid-key')),
    expect: () => const [
      ConnectState.submitting(),
      ConnectState.failure('Invalid API key'),
    ],
  );

  blocTest<ConnectBloc, ConnectState>(
    'empty key emits failure without calling repository',
    build: () => ConnectBloc(repository),
    act: (bloc) => bloc.add(const ConnectSubmitted('   ')),
    expect: () => const [ConnectState.failure('Enter an API key to connect.')],
    verify: (_) {
      verifyNever(() => repository.connect(any()));
    },
  );
}
