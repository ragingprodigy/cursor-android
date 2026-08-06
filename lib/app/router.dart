import 'package:cursor/app/di.dart';
import 'package:cursor/features/agents/presentation/agents_page.dart';
import 'package:cursor/features/auth/presentation/connect_page.dart';
import 'package:cursor/features/launch/presentation/launch_page.dart';
import 'package:cursor/features/prompts/presentation/prompt_edit_page.dart';
import 'package:cursor/features/prompts/presentation/prompt_library_page.dart';
import 'package:cursor/features/settings/presentation/settings_page.dart';
import 'package:cursor/features/thread/presentation/thread_page.dart';
import 'package:cursor/features/usage/presentation/usage_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(AppDependencies dependencies) {
  return GoRouter(
    initialLocation: '/agents',
    refreshListenable: dependencies.authSession,
    redirect: (context, state) {
      final isAuthenticated = dependencies.authSession.isAuthenticated;
      final isConnecting = state.matchedLocation == '/connect';

      if (!isAuthenticated) {
        return isConnecting ? null : '/connect';
      }

      return isConnecting ? '/agents' : null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => dependencies.createConnectBloc(),
            child: const ConnectPage(),
          );
        },
      ),
      GoRoute(
        path: '/agents',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => dependencies.createAgentsBloc(),
            child: const AgentsPage(),
          );
        },
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              return BlocProvider(
                create: (_) => dependencies.createLaunchBloc(),
                child: const LaunchPage(),
              );
            },
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final agentId = state.pathParameters['id']!;
              return BlocProvider(
                create: (_) => dependencies.createThreadBloc(agentId),
                child: const ThreadPage(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          return SettingsPage(
            authSession: dependencies.authSession,
            database: dependencies.database,
          );
        },
        routes: [
          GoRoute(
            path: 'prompts',
            builder: (context, state) {
              return BlocProvider(
                create: (_) => dependencies.createPromptLibraryBloc(),
                child: const PromptLibraryPage(),
              );
            },
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) {
                  return PromptEditPage(
                    repository: dependencies.promptLibraryRepository,
                  );
                },
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  return PromptEditPage(
                    repository: dependencies.promptLibraryRepository,
                    promptId: state.pathParameters['id'],
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/usage',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => dependencies.createUsageBloc(),
            child: const UsagePage(),
          );
        },
      ),
    ],
  );
}
