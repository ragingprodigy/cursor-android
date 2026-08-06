import 'package:cursor/core/config/app_config.dart';
import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:cursor/core/storage/secure_credentials_store.dart';
import 'package:cursor/features/agents/data/agents_list_grouping_store.dart';
import 'package:cursor/features/agents/data/agents_repository.dart';
import 'package:cursor/features/agents/presentation/agents_bloc.dart';
import 'package:cursor/features/auth/data/auth_remote_source.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:cursor/features/auth/presentation/connect_bloc.dart';
import 'package:cursor/features/launch/data/catalog_remote_source.dart';
import 'package:cursor/features/launch/data/launch_draft_store.dart';
import 'package:cursor/features/launch/data/launch_repository.dart';
import 'package:cursor/features/launch/presentation/launch_bloc.dart';
import 'package:cursor/features/models/data/models_repository.dart';
import 'package:cursor/features/prompts/data/prompt_library_repository.dart';
import 'package:cursor/features/prompts/presentation/prompt_library_bloc.dart';
import 'package:cursor/features/thread/data/follow_up_draft_store.dart';
import 'package:cursor/features/thread/data/follow_up_model_store.dart';
import 'package:cursor/features/thread/data/run_prompt_store.dart';
import 'package:cursor/features/thread/data/run_result_store.dart';
import 'package:cursor/features/thread/data/run_thinking_store.dart';
import 'package:cursor/features/thread/data/thread_repository.dart';
import 'package:cursor/features/thread/presentation/thread_bloc.dart';
import 'package:cursor/features/usage/data/usage_repository.dart';
import 'package:cursor/features/usage/presentation/usage_bloc.dart';
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
  late final SseClient sseClient = SseClient(dio);
  late final AuthRemoteSource authRemoteSource = AuthRemoteSource(
    cursorApiClient,
  );
  late final AgentsRepository agentsRepository = AgentsRepository(
    apiClient: cursorApiClient,
    database: database,
  );
  late final AgentsListGroupingStore agentsListGroupingStore =
      AgentsListGroupingStore();
  late final ThreadRepository threadRepository = ThreadRepository(
    apiClient: cursorApiClient,
    database: database,
    sseClient: sseClient,
    runPromptStore: runPromptStore,
    runResultStore: runResultStore,
    runThinkingStore: runThinkingStore,
    onUnauthorized: authSession.signOut,
  );
  late final FollowUpDraftStore followUpDraftStore = FollowUpDraftStore(
    database.draftsDao,
  );
  late final RunPromptStore runPromptStore = RunPromptStore(
    database.runPromptsDao,
  );
  late final RunResultStore runResultStore = RunResultStore(
    database.runResultsDao,
  );
  late final RunThinkingStore runThinkingStore = RunThinkingStore(
    database.draftsDao,
  );
  late final FollowUpModelStore followUpModelStore = FollowUpModelStore(
    database.draftsDao,
  );
  late final CatalogRemoteSource catalogRemoteSource = CatalogRemoteSource(
    cursorApiClient,
  );
  late final ModelsRepository modelsRepository = ModelsRepository(
    catalogRemoteSource,
  );
  late final LaunchDraftStore launchDraftStore = LaunchDraftStore(
    database.draftsDao,
  );
  late final LaunchRepository launchRepository = LaunchRepository(
    catalogRemoteSource: catalogRemoteSource,
    runPromptStore: runPromptStore,
  );
  late final UsageRepository usageRepository = UsageRepository(
    apiClient: cursorApiClient,
    database: database,
    loadAgentUsage: threadRepository.loadAgentUsage,
  );
  late final PromptLibraryRepository promptLibraryRepository =
      PromptLibraryRepository(database.savedPromptsDao);
  late final AuthSessionRepository authSession =
      _authSessionOverride ??
      AuthSessionRepository(
        apiClient: cursorApiClient,
        remoteSource: authRemoteSource,
        credentials: credentialsStore,
        config: config,
        clearLocalCache: database.clearLocalCache,
      );

  AuthSessionRepository get authSessionRepository => authSession;

  ConnectBloc createConnectBloc() {
    return ConnectBloc(authSession);
  }

  AgentsBloc createAgentsBloc() {
    return AgentsBloc(agentsRepository, groupingStore: agentsListGroupingStore);
  }

  LaunchBloc createLaunchBloc() {
    return LaunchBloc(
      repository: launchRepository,
      draftStore: launchDraftStore,
    );
  }

  ThreadBloc createThreadBloc(String agentId) {
    return ThreadBloc(
      repository: threadRepository,
      draftStore: followUpDraftStore,
      modelsRepository: modelsRepository,
      modelStore: followUpModelStore,
      agentId: agentId,
      onUnauthorized: authSession.signOut,
    );
  }

  UsageBloc createUsageBloc() {
    return UsageBloc(usageRepository);
  }

  PromptLibraryBloc createPromptLibraryBloc() {
    return PromptLibraryBloc(promptLibraryRepository);
  }
}

typedef AppDi = AppDependencies;
