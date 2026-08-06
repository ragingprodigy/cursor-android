import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';

class AuthRemoteSource {
  const AuthRemoteSource(this._apiClient);

  final CursorApiClient _apiClient;

  Future<ApiKeyInfo> me() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/v1/me');
    final data = response.data;

    if (data == null) {
      throw const ApiException('Cursor API returned an empty profile');
    }

    return ApiKeyInfo.fromJson(data);
  }
}
