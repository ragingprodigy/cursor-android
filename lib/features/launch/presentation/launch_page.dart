import 'package:cursor/features/launch/domain/launch_catalog.dart';
import 'package:cursor/features/launch/presentation/launch_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class LaunchPage extends HookWidget {
  const LaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      context.read<LaunchBloc>().add(const LaunchStarted());
      return null;
    }, const []);

    return BlocListener<LaunchBloc, LaunchState>(
      listenWhen: (previous, current) {
        return previous.createdAgentId != current.createdAgentId &&
            current.createdAgentId != null;
      },
      listener: (context, state) {
        context.go('/agents/${Uri.encodeComponent(state.createdAgentId!)}');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New agent')),
        body: SafeArea(
          child: BlocBuilder<LaunchBloc, LaunchState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return _LaunchForm(state: state);
            },
          ),
        ),
      ),
    );
  }
}

class _LaunchForm extends HookWidget {
  const _LaunchForm({required this.state});

  final LaunchState state;

  @override
  Widget build(BuildContext context) {
    final promptController = useTextEditingController(text: state.prompt);
    final refController = useTextEditingController(
      text: state.startingRef ?? '',
    );

    useEffect(() {
      _syncTextController(promptController, state.prompt);
      return null;
    }, [state.prompt]);
    useEffect(() {
      _syncTextController(refController, state.startingRef ?? '');
      return null;
    }, [state.startingRef]);

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Launch Cloud Agent',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe the work, optionally choose a repository and ref, '
                  'then create a new Cursor Cloud Agent.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        if (state.catalogMessage != null) ...[
          const SizedBox(height: 16),
          _MessageBanner(
            icon: Icons.info_outline,
            message: state.catalogMessage!,
          ),
        ],
        if (state.failureMessage != null) ...[
          const SizedBox(height: 16),
          _MessageBanner(
            icon: Icons.error_outline,
            message: state.failureMessage!,
            isError: true,
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: promptController,
          minLines: 5,
          maxLines: 10,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: 'Prompt',
            hintText: 'Ask the agent to implement, debug, or investigate...',
            errorText: state.validationMessage,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<LaunchBloc>().add(LaunchPromptChanged(value));
          },
        ),
        const SizedBox(height: 18),
        Autocomplete<LaunchRepositoryOption>(
          key: ValueKey(_repositoryText(state)),
          displayStringForOption: (option) => option.name,
          initialValue: TextEditingValue(text: _repositoryText(state)),
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            final options = _repositoryOptions(state);
            if (query.isEmpty) {
              return options;
            }
            return options.where((option) {
              return option.name.toLowerCase().contains(query) ||
                  option.url.toLowerCase().contains(query);
            });
          },
          onSelected: (option) {
            context.read<LaunchBloc>().add(
              LaunchRepositoryChanged(
                option.url,
                startingRef: option.defaultBranch ?? state.startingRef,
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Repository',
                hintText: 'Search repositories or paste a repo URL',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<LaunchBloc>().add(LaunchRepositoryChanged(value));
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(option.name),
                        subtitle: Text(option.url),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        TextField(
          controller: refController,
          decoration: const InputDecoration(
            labelText: 'Starting ref',
            hintText: 'main, branch name, tag, or commit SHA',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<LaunchBloc>().add(LaunchStartingRefChanged(value));
          },
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          value: _selectedModelId(state),
          decoration: const InputDecoration(
            labelText: 'Model',
            border: OutlineInputBorder(),
          ),
          items: state.models
              .map((model) {
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(model.name),
                );
              })
              .toList(growable: false),
          onChanged: (value) {
            context.read<LaunchBloc>().add(LaunchModelChanged(value));
          },
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: state.isSubmitting
              ? null
              : () {
                  context.read<LaunchBloc>().add(const LaunchSubmitted());
                },
          icon: state.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rocket_launch_outlined),
          label: Text(state.isSubmitting ? 'Creating...' : 'Create agent'),
        ),
      ],
    );
  }

  List<LaunchRepositoryOption> _repositoryOptions(LaunchState state) {
    final selected = state.selectedRepoUrl;
    if (selected == null ||
        state.repositories.any((option) => option.url == selected)) {
      return state.repositories;
    }
    return [
      LaunchRepositoryOption(name: selected, url: selected),
      ...state.repositories,
    ];
  }

  String _repositoryText(LaunchState state) {
    final selected = state.selectedRepoUrl;
    if (selected == null) {
      return '';
    }
    for (final option in state.repositories) {
      if (option.url == selected) {
        return option.name;
      }
    }
    return selected;
  }

  String _selectedModelId(LaunchState state) {
    final selected = state.selectedModelId;
    if (selected != null && state.models.any((model) => model.id == selected)) {
      return selected;
    }
    return LaunchModel.defaultModel.id;
  }

  void _syncTextController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
