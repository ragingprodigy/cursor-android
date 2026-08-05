import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/error/app_exception.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future? cancelFuture,
  ) {
    return handler(options);
  }
}

void main() {
  test('attaches bearer token when api key set', () async {
    late RequestOptions seen;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final client = CursorApiClient(dio);
    client.setApiKey('test-key');
    await client.get<Map<String, dynamic>>('/v1/me');
    expect(seen.headers['Authorization'], 'Bearer test-key');
  });

  test('maps 401 to UnauthorizedException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        '{"message":"Invalid API key"}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final client = CursorApiClient(dio);
    expect(() => client.get('/v1/me'), throwsA(isA<UnauthorizedException>()));
  });

  test('maps 429 to RateLimitedException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        '{"message":"Too many requests"}',
        429,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final client = CursorApiClient(dio);
    expect(() => client.get('/v1/me'), throwsA(isA<RateLimitedException>()));
  });

  test('maps server messages to ApiException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        '{"message":"Something went wrong"}',
        500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final client = CursorApiClient(dio);
    expect(
      () => client.get('/v1/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having(
              (error) => error.message,
              'message',
              'Something went wrong',
            ),
      ),
    );
  });

  test('maps connection failures to NetworkException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final client = CursorApiClient(dio);
    expect(() => client.get('/v1/me'), throwsA(isA<NetworkException>()));
  });
}
