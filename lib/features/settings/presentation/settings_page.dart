import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({required this.authSession, super.key});

  final AuthSessionRepository authSession;

  @override
  Widget build(BuildContext context) {
    final info = authSession.currentInfo;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(info?.apiKeyName ?? 'Connected Cursor API key'),
                    if (info?.userEmail != null) ...[
                      const SizedBox(height: 4),
                      Text(info!.userEmail!),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => authSession.signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
