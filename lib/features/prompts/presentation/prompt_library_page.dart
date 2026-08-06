import 'package:cursor/features/prompts/domain/saved_prompt.dart';
import 'package:cursor/features/prompts/presentation/prompt_library_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class PromptLibraryPage extends HookWidget {
  const PromptLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      context.read<PromptLibraryBloc>().add(const PromptLibraryStarted());
      return null;
    }, const []);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Prompt library')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add prompt',
        onPressed: () => context.push('/settings/prompts/new'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: BlocBuilder<PromptLibraryBloc, PromptLibraryState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Filter by title, tags, or notes',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      context.read<PromptLibraryBloc>().add(
                        PromptLibraryQueryChanged(value),
                      );
                    },
                  ),
                ),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      state.message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(child: _PromptList(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PromptList extends StatelessWidget {
  const _PromptList({required this.state});

  final PromptLibraryState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == PromptLibraryStatus.loading ||
        state.status == PromptLibraryStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    final prompts = state.visiblePrompts;
    if (prompts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.query.trim().isEmpty
                ? 'No saved prompts yet. Tap + to add a reusable prompt.'
                : 'No prompts match your search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 88),
      itemCount: prompts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final prompt = prompts[index];
        return _PromptTile(prompt: prompt);
      },
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({required this.prompt});

  final SavedPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (prompt.tags.isNotEmpty) prompt.tags.join(' · '),
      if (prompt.notes != null) prompt.notes!,
    ];

    return Card(
      child: ListTile(
        title: Text(prompt.title),
        subtitle: subtitleParts.isEmpty
            ? Text(
                prompt.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                subtitleParts.join('\n'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        isThreeLine: subtitleParts.isNotEmpty || prompt.body.isNotEmpty,
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, prompt),
        ),
        onTap: () => context.push(
          '/settings/prompts/${Uri.encodeComponent(prompt.id)}',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SavedPrompt prompt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete prompt?'),
          content: Text('Delete “${prompt.title}”? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      context.read<PromptLibraryBloc>().add(
        PromptLibraryDeleteRequested(prompt.id),
      );
    }
  }
}
