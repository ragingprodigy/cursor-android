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
      throw await _mapDioException(error);
    } finally {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel();
      }
    }
  }

  Future<AppException> _mapDioException(DioException error) async {
    if (_isConnectionError(error)) {
      return const NetworkException();
    }

    final response = error.response;
    final statusCode = response?.statusCode;
    final details = await _apiErrorDetailsFromResponseData(response?.data);
    final message = _apiErrorMessage(details);
    return switch (statusCode) {
      401 => UnauthorizedException(message ?? 'API key rejected'),
      429 => RateLimitedException(message ?? 'Rate limited'),
      _ => ApiException(
        message ?? 'Cursor stream request failed',
        statusCode: statusCode,
        code: details.code,
      ),
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

  Future<_ApiErrorDetails> _apiErrorDetailsFromResponseData(
    Object? data,
  ) async {
    if (data is ResponseBody) {
      final bytes = <int>[];
      await for (final chunk in data.stream.cast<List<int>>()) {
        bytes.addAll(chunk);
      }
      return _apiErrorDetailsFromString(
        utf8.decode(bytes, allowMalformed: true),
      );
    }

    if (data is List<int>) {
      return _apiErrorDetailsFromString(
        utf8.decode(data, allowMalformed: true),
      );
    }

    if (data is String) {
      return _apiErrorDetailsFromString(data);
    }

    if (data is Map) {
      return _apiErrorDetailsFromMap(data);
    }

    return const _ApiErrorDetails();
  }

  _ApiErrorDetails _apiErrorDetailsFromString(String data) {
    if (data.trim().isEmpty) {
      return const _ApiErrorDetails();
    }

    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return _apiErrorDetailsFromMap(decoded);
      }
    } on FormatException {
      return const _ApiErrorDetails();
    }

    return const _ApiErrorDetails();
  }

  _ApiErrorDetails _apiErrorDetailsFromMap(Map<dynamic, dynamic> data) {
    final code = _nonEmptyString(data['code']);
    final message = _nonEmptyString(data['message']);
    return _ApiErrorDetails(code: code, message: message);
  }

  String? _apiErrorMessage(_ApiErrorDetails details) {
    final code = details.code;
    final message = details.message;
    if (code != null && message != null) {
      return '$code: $message';
    }
    return code ?? message;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ApiErrorDetails {
  const _ApiErrorDetails({this.code, this.message});

  final String? code;
  final String? message;
}
