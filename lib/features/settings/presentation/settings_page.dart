import 'package:cursor/core/db/app_database.dart';
import 'package:cursor/features/auth/data/auth_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({
    required this.authSession,
    required this.database,
    super.key,
  });

  final AuthSessionRepository authSession;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final info = authSession.currentInfo;
    final theme = Theme.of(context);
    final isSigningOut = useState(false);
    final isClearingCache = useState(false);

    Future<void> signOut() async {
      if (isSigningOut.value) {
        return;
      }
      isSigningOut.value = true;
      await authSession.signOut();
      if (context.mounted) {
        isSigningOut.value = false;
      }
    }

    Future<void> clearCache() async {
      if (isClearingCache.value) {
        return;
      }
      isClearingCache.value = true;
      try {
        await database.clearLocalCache();
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Local cache cleared.')));
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear local cache.')),
        );
      } finally {
        if (context.mounted) {
          isClearingCache.value = false;
        }
      }
    }

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
                    _SettingsValue(
                      label: 'API key',
                      value: info?.apiKeyName ?? 'Connected Cursor API key',
                    ),
                    const SizedBox(height: 12),
                    _SettingsValue(
                      label: 'User email',
                      value: info?.userEmail ?? 'Not provided by API',
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: isSigningOut.value ? null : signOut,
                      icon: const Icon(Icons.logout),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: isSigningOut.value
                            ? const SizedBox.square(
                                key: ValueKey('signing-out'),
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign out', key: ValueKey('sign-out')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local cache', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Clear cached agents, threads, and unsent drafts stored '
                      'on this device. Your API key remains connected.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isClearingCache.value ? null : clearCache,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: isClearingCache.value
                            ? const SizedBox.square(
                                key: ValueKey('clearing-cache'),
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Clear local cache',
                                key: ValueKey('clear-cache'),
                              ),
                      ),
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

class _SettingsValue extends StatelessWidget {
  const _SettingsValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
