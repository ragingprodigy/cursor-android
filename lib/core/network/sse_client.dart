import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import 'package:cursor/core/error/app_exception.dart';

/// A single parsed Server-Sent Event.
class SseEvent extends Equatable {
  const SseEvent({required this.event, required this.data, this.id});

  /// The `event:` field, defaulting to `message` when absent per the SSE spec.
  final String event;

  /// The concatenated `data:` lines (joined with `\n`).
  final String data;

  /// The `id:` field, if present. Used to resume via `Last-Event-ID`.
  final String? id;

  @override
  List<Object?> get props => [event, data, id];
}

/// Minimal Server-Sent Events client built on top of [Dio].
///
/// Parses `event:` / `data:` / `id:` lines from a `text/event-stream`
/// response and resumes a dropped connection with a `Last-Event-ID` header
/// when a caller re-subscribes with [SseClient.stream]'s `lastEventId`.
class SseClient {
  SseClient(this._dio);

  final Dio _dio;

  Stream<SseEvent> stream(String path, {String? lastEventId}) async* {
    final cancelToken = CancelToken();
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
            if (lastEventId != null) 'Last-Event-ID': lastEventId,
          },
        ),
        cancelToken: cancelToken,
      );

      final body = response.data;
      if (body == null) {
        return;
      }

      var eventName = 'message';
      final dataLines = <String>[];
      String? id;

      final lines = body.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty) {
          if (dataLines.isNotEmpty || eventName != 'message') {
            yield SseEvent(
              event: eventName,
              data: dataLines.join('\n'),
              id: id,
            );
          }
          eventName = 'message';
          dataLines.clear();
          continue;
        }

        if (line.startsWith(':')) {
          continue;
        }

        final separatorIndex = line.indexOf(':');
        final field = separatorIndex == -1
            ? line
            : line.substring(0, separatorIndex);
        var value = separatorIndex == -1
            ? ''
            : line.substring(separatorIndex + 1);
        if (value.startsWith(' ')) {
          value = value.substring(1);
        }

        switch (field) {
          case 'event':
            eventName = value;
          case 'data':
            dataLines.add(value);
          case 'id':
            if (value.isNotEmpty) {
              id = value;
            }
          default:
            break;
        }
      }
    } on DioException catch (error) {
      throw _mapDioException(error);
    } finally {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel();
      }
    }
  }

  AppException _mapDioException(DioException error) {
    if (_isConnectionError(error)) {
      return const NetworkException();
    }

    final statusCode = error.response?.statusCode;
    return switch (statusCode) {
      401 => const UnauthorizedException(),
      429 => const RateLimitedException(),
      _ => ApiException('Cursor stream request failed', statusCode: statusCode),
    };
  }

  bool _isConnectionError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      DioExceptionType.unknown => error.response == null,
      _ => false,
    };
  }
}
