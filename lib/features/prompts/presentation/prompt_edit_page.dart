import 'package:cursor/features/prompts/data/prompt_library_repository.dart';
import 'package:cursor/features/prompts/domain/saved_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class PromptEditPage extends HookWidget {
  const PromptEditPage({
    required this.repository,
    this.promptId,
    super.key,
  });

  final PromptLibraryRepository repository;
  final String? promptId;

  @override
  Widget build(BuildContext context) {
    final isNew = promptId == null;
    final titleController = useTextEditingController();
    final bodyController = useTextEditingController();
    final notesController = useTextEditingController();
    final tagsController = useTextEditingController();
    final isLoading = useState(true);
    final isSaving = useState(false);
    final error = useState<String?>(null);
    final existing = useState<SavedPrompt?>(null);

    useEffect(() {
      var cancelled = false;
      Future<void>(() async {
        if (promptId == null) {
          if (!cancelled) {
            isLoading.value = false;
          }
          return;
        }
        try {
          final prompt = await repository.getById(promptId!);
          if (cancelled) {
            return;
          }
          if (prompt == null) {
            error.value = 'Prompt not found.';
            isLoading.value = false;
            return;
          }
          existing.value = prompt;
          titleController.text = prompt.title;
          bodyController.text = prompt.body;
          notesController.text = prompt.notes ?? '';
          tagsController.text = prompt.tags.join(', ');
          isLoading.value = false;
        } catch (_) {
          if (!cancelled) {
            error.value = 'Unable to load prompt.';
            isLoading.value = false;
          }
        }
      });
      return () => cancelled = true;
    }, [promptId]);

    Future<void> save() async {
      if (isSaving.value) {
        return;
      }
      isSaving.value = true;
      error.value = null;
      try {
        await repository.upsert(
          id: existing.value?.id ?? promptId,
          title: titleController.text,
          body: bodyController.text,
          notes: notesController.text,
          tags: tagsController.text.split(','),
        );
        if (context.mounted) {
          context.pop();
        }
      } on ArgumentError catch (err) {
        error.value = err.message?.toString() ?? 'Invalid prompt.';
      } catch (_) {
        error.value = 'Unable to save prompt.';
      } finally {
        isSaving.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New prompt' : 'Edit prompt')),
      body: SafeArea(
        child: isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (error.value != null) ...[
                    Text(
                      error.value!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bodyController,
                    minLines: 8,
                    maxLines: 16,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (optional)',
                      hintText: 'review, testing, comma-separated',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isSaving.value ? null : save,
                    icon: isSaving.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isNew ? 'Create prompt' : 'Save changes'),
                  ),
                ],
              ),
      ),
    );
  }
}
