import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/storage/secure_credentials_store.dart';
import 'package:cursor/features/auth/data/auth_remote_source.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:cursor/features/auth/presentation/connect_bloc.dart';
import 'package:dio/dio.dart';

class AppDependencies {
  AppDependencies({
    AppConfig? config,
    Dio? dio,
    SecureCredentialsStore? credentialsStore,
    AppDatabase? database,
    AuthSessionRepository? authSession,
  }) : config = config ?? AppConfig.fromEnvironment(),
       dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: (config ?? AppConfig.fromEnvironment()).apiBaseUrl,
             ),
           ),
       credentialsStore = credentialsStore ?? SecureCredentialsStore(),
       database = database ?? AppDatabase.defaults(),
       _authSessionOverride = authSession;

  static Future<AppDependencies> create(AppConfig config) async {
    return AppDependencies(config: config);
  }

  final AppConfig config;
  final Dio dio;
  final SecureCredentialsStore credentialsStore;
  final AppDatabase database;
  final AuthSessionRepository? _authSessionOverride;

  late final CursorApiClient cursorApiClient = CursorApiClient(dio);
  late final AuthRemoteSource authRemoteSource = AuthRemoteSource(
    cursorApiClient,
  );
  late final AuthSessionRepository authSession =
      _authSessionOverride ??
      AuthSessionRepository(
        apiClient: cursorApiClient,
        remoteSource: authRemoteSource,
        credentials: credentialsStore,
        config: config,
      );

  AuthSessionRepository get authSessionRepository => authSession;

  ConnectBloc createConnectBloc() {
    return ConnectBloc(authSession);
  }
}

typedef AppDi = AppDependencies;
