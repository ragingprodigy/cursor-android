import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/launch/data/catalog_remote_source.dart';
import 'package:cursor/features/launch/domain/launch_catalog.dart';
import 'package:cursor/features/thread/data/run_prompt_store.dart';
import 'package:equatable/equatable.dart';

class LaunchRequest extends Equatable {
  const LaunchRequest({
    required this.prompt,
    this.repoUrl,
    this.startingRef,
    this.modelId,
  });

  final String prompt;
  final String? repoUrl;
  final String? startingRef;
  final String? modelId;

  @override
  List<Object?> get props => [prompt, repoUrl, startingRef, modelId];
}

class LaunchRepository {
  LaunchRepository({
    required CatalogRemoteSource catalogRemoteSource,
    RunPromptStore? runPromptStore,
  }) : this._(catalogRemoteSource, runPromptStore);

  LaunchRepository._(this._catalogRemoteSource, this._runPromptStore);

  final CatalogRemoteSource _catalogRemoteSource;
  final RunPromptStore? _runPromptStore;

  static const _repositoryCacheTtl = Duration(hours: 1);
  static const _modelCacheTtl = Duration(hours: 1);

  _CacheEntry<LaunchRepositoryOption>? _repositoryCache;
  _CacheEntry<LaunchModel>? _modelCache;

  Future<LaunchCatalog> loadCatalog({bool forceRefresh = false}) async {
    final messages = <String>[];
    final repositories = await _loadRepositories(
      forceRefresh: forceRefresh,
      messages: messages,
    );
    final models = await _loadModels(
      forceRefresh: forceRefresh,
      messages: messages,
    );

    return LaunchCatalog(
      repositories: repositories,
      models: [LaunchModel.defaultModel, ...models],
      message: messages.isEmpty ? null : messages.join(' '),
    );
  }

  Future<String> createAgent(LaunchRequest request) async {
    final response = await _catalogRemoteSource.createAgent(
      _bodyFromRequest(request),
    );
    final created = _createdAgentFromResponse(response);
    await _saveInitialPrompt(
      agentId: created.agentId,
      runId: created.initialRunId,
      text: request.prompt,
    );
    return created.agentId;
  }

  Future<List<LaunchRepositoryOption>> _loadRepositories({
    required bool forceRefresh,
    required List<String> messages,
  }) async {
    final cache = _repositoryCache;
    if (!forceRefresh &&
        cache != null &&
        !cache.isExpired(_repositoryCacheTtl)) {
      return cache.items;
    }

    try {
      final repositories = await _catalogRemoteSource.listRepositories();
      _repositoryCache = _CacheEntry(repositories);
      return repositories;
    } on AppException catch (error) {
      messages.add(
        _catalogFallbackMessage(error.message, hasCache: cache != null),
      );
      return cache?.items ?? const [];
    } catch (_) {
      messages.add(
        _catalogFallbackMessage(
          'Unable to load repositories.',
          hasCache: cache != null,
        ),
      );
      return cache?.items ?? const [];
    }
  }

  Future<List<LaunchModel>> _loadModels({
    required bool forceRefresh,
    required List<String> messages,
  }) async {
    final cache = _modelCache;
    if (!forceRefresh && cache != null && !cache.isExpired(_modelCacheTtl)) {
      return cache.items;
    }

    try {
      final models = await _catalogRemoteSource.listModels();
      _modelCache = _CacheEntry(models);
      return models;
    } on AppException catch (error) {
      messages.add(
        _catalogFallbackMessage(error.message, hasCache: cache != null),
      );
      return cache?.items ?? const [];
    } catch (_) {
      messages.add(
        _catalogFallbackMessage(
          'Unable to load models.',
          hasCache: cache != null,
        ),
      );
      return cache?.items ?? const [];
    }
  }

  Map<String, Object?> _bodyFromRequest(LaunchRequest request) {
    final prompt = request.prompt.trim();
    final repoUrl = _blankToNull(request.repoUrl);
    final startingRef = _blankToNull(request.startingRef);
    final modelId = _blankToNull(request.modelId);

    return {
      'prompt': {'text': prompt},
      // The API treats an omitted model as "Default"; do not send a default id.
      if (modelId != null && modelId != LaunchModel.defaultModel.id)
        'model': {'id': modelId},
      if (repoUrl != null)
        'repos': [
          {'url': repoUrl, if (startingRef != null) 'startingRef': startingRef},
        ],
    };
  }

  _CreatedAgent _createdAgentFromResponse(Object? data) {
    final payload = _asMap(data);
    final agent = payload['agent'];
    if (agent is Map<String, dynamic>) {
      final id = _stringAt(agent, 'id');
      if (id != null) {
        return _CreatedAgent(
          agentId: id,
          initialRunId:
              _runIdFromPayload(payload) ??
              _stringAt(agent, 'latestRunId') ??
              _stringAt(agent, 'latest_run_id'),
        );
      }
    }
    final id = _stringAt(payload, 'id') ?? _stringAt(payload, 'agentId');
    if (id != null) {
      return _CreatedAgent(
        agentId: id,
        initialRunId: _runIdFromPayload(payload),
      );
    }
    throw const ApiException(
      'Cursor create agent response was missing agent id.',
    );
  }

  String? _runIdFromPayload(Map<String, dynamic> payload) {
    final direct =
        _stringAt(payload, 'runId') ??
        _stringAt(payload, 'run_id') ??
        _stringAt(payload, 'latestRunId') ??
        _stringAt(payload, 'latest_run_id');
    if (direct != null) {
      return direct;
    }

    for (final key in const ['run', 'initialRun', 'initial_run', 'latestRun']) {
      final value = payload[key];
      if (value is Map<String, dynamic>) {
        final id = _stringAt(value, 'id') ?? _stringAt(value, 'runId');
        if (id != null) {
          return id;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on FormatException {
        throw const ApiException(
          'Cursor create agent response was not valid JSON.',
        );
      }
    }
    throw const ApiException('Cursor create agent response was invalid.');
  }

  String? _stringAt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String _catalogFallbackMessage(String message, {required bool hasCache}) {
    if (hasCache) {
      return '$message Showing cached catalog.';
    }
    return '$message Catalog options may be empty.';
  }

  Future<void> _saveInitialPrompt({
    required String agentId,
    required String? runId,
    required String text,
  }) async {
    final store = _runPromptStore;
    if (store == null) {
      return;
    }

    try {
      if (runId == null) {
        await store.savePendingInitialPrompt(agentId: agentId, text: text);
      } else {
        await store.savePrompt(agentId: agentId, runId: runId, text: text);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to save initial run prompt.',
        name: 'LaunchRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class _CreatedAgent {
  const _CreatedAgent({required this.agentId, required this.initialRunId});

  final String agentId;
  final String? initialRunId;
}

class _CacheEntry<T> {
  _CacheEntry(Iterable<T> items)
    : items = List.unmodifiable(items),
      cachedAt = DateTime.now().toUtc();

  final List<T> items;
  final DateTime cachedAt;

  bool isExpired(Duration ttl) {
    return DateTime.now().toUtc().difference(cachedAt) > ttl;
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
