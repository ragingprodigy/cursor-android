import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/storage/secure_credentials_store.dart';
import 'package:cursor/features/auth/data/auth_remote_source.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:cursor/features/auth/presentation/connect_bloc.dart';
import 'package:dio/dio.dart';

class AppDi {
  AppDi({AppConfig? config, Dio? dio, SecureCredentialsStore? credentialsStore})
    : config = config ?? AppConfig.fromEnvironment(),
      dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: (config ?? AppConfig.fromEnvironment()).apiBaseUrl,
            ),
          ),
      credentialsStore = credentialsStore ?? SecureCredentialsStore();

  final AppConfig config;
  final Dio dio;
  final SecureCredentialsStore credentialsStore;

  late final CursorApiClient cursorApiClient = CursorApiClient(dio);
  late final AuthRemoteSource authRemoteSource = AuthRemoteSource(
    cursorApiClient,
  );
  late final AuthSessionRepository authSessionRepository =
      AuthSessionRepository(
        apiClient: cursorApiClient,
        remoteSource: authRemoteSource,
        credentials: credentialsStore,
        config: config,
      );

  ConnectBloc createConnectBloc() {
    return ConnectBloc(authSessionRepository);
  }
}
