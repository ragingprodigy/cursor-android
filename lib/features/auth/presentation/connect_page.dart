import 'package:cursor/features/auth/presentation/connect_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectPage extends HookWidget {
  const ConnectPage({super.key});

  static final Uri dashboardUri = Uri.parse('https://cursor.com/dashboard/api');

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();

    useEffect(() {
      context.read<ConnectBloc>().add(const ConnectStarted());
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Cursor')),
      body: SafeArea(
        child: BlocBuilder<ConnectBloc, ConnectState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Connect your Cursor account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create an API key from the Cursor dashboard, then paste '
                    'the key or advanced token below.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openDashboard(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Cursor API dashboard'),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'API key or advanced token',
                    ),
                    onSubmitted: (_) => _submit(context, controller.text),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submit(context, controller.text),
                    child: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                  if (state.status == ConnectStatus.failure &&
                      state.message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.status == ConnectStatus.authenticated &&
                      state.info != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connected',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(state.info!.apiKeyName),
                            if (state.info!.userEmail != null)
                              Text(state.info!.userEmail!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDashboard(BuildContext context) async {
    context.read<ConnectBloc>().add(const ConnectOpenDashboard());
    final launched = await launchUrl(
      dashboardUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Cursor dashboard.')),
      );
    }
  }

  void _submit(BuildContext context, String apiKey) {
    context.read<ConnectBloc>().add(ConnectSubmitted(apiKey));
  }
}
