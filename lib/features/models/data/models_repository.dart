import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/features/launch/data/catalog_remote_source.dart';
import 'package:cursor/features/launch/domain/launch_catalog.dart';
import 'package:equatable/equatable.dart';

class ModelsCatalog extends Equatable {
  const ModelsCatalog({required this.models, this.message});

  final List<LaunchModel> models;
  final String? message;

  @override
  List<Object?> get props => [models, message];
}

class ModelsRepository {
  ModelsRepository(this._catalogRemoteSource);

  final CatalogRemoteSource _catalogRemoteSource;

  static const _modelCacheTtl = Duration(hours: 1);

  _ModelCache? _cache;

  Future<ModelsCatalog> loadModels({bool forceRefresh = false}) async {
    final cache = _cache;
    if (!forceRefresh && cache != null && !cache.isExpired(_modelCacheTtl)) {
      return ModelsCatalog(models: _withDefault(cache.models));
    }

    try {
      final models = await _catalogRemoteSource.listModels();
      _cache = _ModelCache(models);
      return ModelsCatalog(models: _withDefault(models));
    } on AppException catch (error) {
      return ModelsCatalog(
        models: _withDefault(cache?.models ?? const []),
        message: _fallbackMessage(error.message, hasCache: cache != null),
      );
    } catch (_) {
      return ModelsCatalog(
        models: _withDefault(cache?.models ?? const []),
        message: _fallbackMessage(
          'Unable to load models.',
          hasCache: cache != null,
        ),
      );
    }
  }

  List<LaunchModel> _withDefault(List<LaunchModel> models) {
    return [LaunchModel.defaultModel, ...models];
  }

  String _fallbackMessage(String message, {required bool hasCache}) {
    if (hasCache) {
      return '$message Showing cached models.';
    }
    return '$message Model picker may only show Default.';
  }
}

class _ModelCache {
  _ModelCache(Iterable<LaunchModel> models)
    : models = List.unmodifiable(models),
      cachedAt = DateTime.now().toUtc();

  final List<LaunchModel> models;
  final DateTime cachedAt;

  bool isExpired(Duration ttl) {
    return DateTime.now().toUtc().difference(cachedAt) > ttl;
  }
}
