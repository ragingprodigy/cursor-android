import 'package:cursor/features/prompts/data/prompt_library_repository.dart';
import 'package:cursor/features/prompts/domain/saved_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

Future<SavedPrompt?> showPromptPickerSheet({
  required BuildContext context,
  required PromptLibraryRepository repository,
}) {
  return showModalBottomSheet<SavedPrompt>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _PromptPickerSheet(repository: repository);
    },
  );
}

class _PromptPickerSheet extends HookWidget {
  const _PromptPickerSheet({required this.repository});

  final PromptLibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    final prompts = useState<List<SavedPrompt>>([]);
    final query = useState('');
    final isLoading = useState(true);
    final error = useState<String?>(null);

    useEffect(() {
      var cancelled = false;
      Future<void>(() async {
        try {
          final loaded = await repository.list();
          if (!cancelled) {
            prompts.value = loaded;
            isLoading.value = false;
          }
        } catch (_) {
          if (!cancelled) {
            error.value = 'Unable to load prompts.';
            isLoading.value = false;
          }
        }
      });
      return () => cancelled = true;
    }, const []);

    final visible = prompts.value
        .where((prompt) => prompt.matchesQuery(query.value))
        .toList(growable: false);

    final height = MediaQuery.sizeOf(context).height * 0.7;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Use a saved prompt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => query.value = value,
            ),
            const SizedBox(height: 12),
            if (error.value != null)
              Text(
                error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                  ? Center(
                      child: Text(
                        prompts.value.isEmpty
                            ? 'No saved prompts yet. Add some in Settings → Prompt library.'
                            : 'No prompts match your search.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final prompt = visible[index];
                        return ListTile(
                          title: Text(prompt.title),
                          subtitle: Text(
                            prompt.tags.isEmpty
                                ? prompt.body
                                : prompt.tags.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(prompt),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
