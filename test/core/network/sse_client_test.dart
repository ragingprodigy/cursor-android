import 'package:cursor/core/error/app_exception.dart';
import 'package:cursor/core/network/sse_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('parses event/data/id lines into SseEvents', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        'event: assistant\n'
        'data: Hello\n'
        'id: 1\n'
        '\n'
        'event: tool_call\n'
        'data: {"name":"flutter test"}\n'
        'id: 2\n'
        '\n'
        'event: done\n'
        'data: {}\n'
        'id: 3\n'
        '\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    });
    final client = SseClient(dio);

    final events = await client
        .stream('/v1/agents/bc-1/runs/run-1/stream')
        .toList();

    expect(events, [
      const SseEvent(event: 'assistant', data: 'Hello', id: '1'),
      const SseEvent(
        event: 'tool_call',
        data: '{"name":"flutter test"}',
        id: '2',
      ),
      const SseEvent(event: 'done', data: '{}', id: '3'),
    ]);
  });

  test('joins multi-line data fields with newlines', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        'event: assistant\n'
        'data: line one\n'
        'data: line two\n'
        '\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    });
    final client = SseClient(dio);

    final events = await client
        .stream('/v1/agents/bc-1/runs/run-1/stream')
        .toList();

    expect(events, [
      const SseEvent(event: 'assistant', data: 'line one\nline two'),
    ]);
  });

  test('ignores comment lines starting with a colon', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString(
        ': keep-alive\n'
        'event: assistant\n'
        'data: Hi\n'
        '\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    });
    final client = SseClient(dio);

    final events = await client
        .stream('/v1/agents/bc-1/runs/run-1/stream')
        .toList();

    expect(events, [const SseEvent(event: 'assistant', data: 'Hi')]);
  });

  test('sends Last-Event-ID header when resuming', () async {
    late RequestOptions seen;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString('', 200);
    });
    final client = SseClient(dio);

    await client
        .stream('/v1/agents/bc-1/runs/run-1/stream', lastEventId: '42')
        .toList();

    expect(seen.headers['Last-Event-ID'], '42');
    expect(seen.headers['Accept'], 'text/event-stream');
  });

  test('maps 410 responses to ApiException with statusCode', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString('stream_expired', 410);
    });
    final client = SseClient(dio);

    expect(
      () => client.stream('/v1/agents/bc-1/runs/run-1/stream').toList(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          410,
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
    final client = SseClient(dio);

    expect(
      () => client.stream('/v1/agents/bc-1/runs/run-1/stream').toList(),
      throwsA(isA<NetworkException>()),
    );
  });
}
