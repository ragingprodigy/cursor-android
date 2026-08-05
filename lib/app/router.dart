import 'package:cursor/app/di.dart';
import 'package:cursor/features/agents/presentation/agents_page.dart';
import 'package:cursor/features/auth/presentation/connect_page.dart';
import 'package:cursor/features/settings/presentation/settings_page.dart';
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
        builder: (context, state) => const AgentsPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const NewAgentPage(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              return AgentDetailPage(agentId: state.pathParameters['id']!);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          return SettingsPage(authSession: dependencies.authSession);
        },
      ),
    ],
  );
}
