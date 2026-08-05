import 'dart:convert';

import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/launch/domain/launch_catalog.dart';

class CatalogRemoteSource {
  CatalogRemoteSource(this._apiClient);

  final CursorApiClient _apiClient;

  Future<List<LaunchRepositoryOption>> listRepositories() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/v1/repositories',
    );
    return _parseRepositories(response.data);
  }

  Future<List<LaunchModel>> listModels() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/v1/models');
    return _parseModels(response.data);
  }

  Future<Object?> createAgent(Map<String, Object?> body) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/v1/agents',
      data: body,
    );
    return response.data;
  }

  List<LaunchRepositoryOption> _parseRepositories(Object? data) {
    final items = _itemsFromPayload(data, 'repositories');
    return items
        .map((item) {
          if (item is String && item.trim().isNotEmpty) {
            final url = item.trim();
            return LaunchRepositoryOption(name: _nameFromUrl(url), url: url);
          }
          if (item is! Map<String, dynamic>) {
            throw const ApiException(
              'Cursor repositories response item was invalid.',
            );
          }

          final url =
              _stringAt(item, 'url') ??
              _stringAt(item, 'repoUrl') ??
              _stringAt(item, 'repo_url') ??
              _stringAt(item, 'repositoryUrl') ??
              _stringAt(item, 'repository_url') ??
              _stringAt(item, 'htmlUrl') ??
              _stringAt(item, 'html_url');
          if (url == null) {
            throw const ApiException('Cursor repository item was missing url.');
          }

          final name =
              _stringAt(item, 'name') ??
              _stringAt(item, 'fullName') ??
              _stringAt(item, 'full_name') ??
              _nameFromUrl(url);
          return LaunchRepositoryOption(
            name: name,
            url: url,
            defaultBranch:
                _stringAt(item, 'defaultBranch') ??
                _stringAt(item, 'default_branch'),
          );
        })
        .toList(growable: false);
  }

  List<LaunchModel> _parseModels(Object? data) {
    final items = _itemsFromPayload(data, 'models');
    final models = items
        .map((item) {
          if (item is String && item.trim().isNotEmpty) {
            final id = item.trim();
            return LaunchModel(id: id, name: id);
          }
          if (item is! Map<String, dynamic>) {
            throw const ApiException(
              'Cursor models response item was invalid.',
            );
          }

          final id = _stringAt(item, 'id') ?? _stringAt(item, 'model');
          if (id == null) {
            throw const ApiException('Cursor model item was missing id.');
          }
          return LaunchModel(
            id: id,
            name:
                _stringAt(item, 'name') ?? _stringAt(item, 'displayName') ?? id,
          );
        })
        .toList(growable: false);

    return models.where((model) => !model.isDefault).toList(growable: false);
  }

  List<Object?> _itemsFromPayload(Object? data, String alternateKey) {
    if (data is List) {
      return data;
    }

    final payload = _asMap(data);
    final items = payload['items'] ?? payload[alternateKey];
    if (items is List) {
      return items;
    }
    throw ApiException('Cursor $alternateKey response did not include items.');
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
        throw const ApiException('Cursor catalog response was not valid JSON.');
      }
    }
    throw const ApiException('Cursor catalog response was invalid.');
  }

  String? _stringAt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String _nameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.length >= 2) {
      final owner = uri.pathSegments[uri.pathSegments.length - 2];
      final repo = uri.pathSegments.last.replaceFirst(RegExp(r'\.git$'), '');
      return '$owner/$repo';
    }
    return url;
  }
}
