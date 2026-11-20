import 'package:dio/dio.dart';

/// Result of [requestWithRedirects], pairing the final [Response] with the
/// resolved [finalUri] after all HTTP 3xx hops.
class RedirectResponse<T> {
  final Response<T> response;
  final Uri finalUri;

  const RedirectResponse({
    required this.response,
    required this.finalUri,
  });

  T? get data => response.data;
  int? get statusCode => response.statusCode;
}

/// Executes an HTTP request with `followRedirects: false` on each hop so Dio's
/// `CookieManager` captures `Set-Cookie` headers emitted on intermediate 301,
/// 302, 303, 307, and 308 responses instead of letting `dart:io`'s `HttpClient`
/// swallow them natively.
Future<RedirectResponse<T>> requestWithRedirects<T>(
  Dio dio,
  String url, {
  String method = 'GET',
  Object? data,
  Options? options,
  ProgressCallback? onReceiveProgress,
  int maxRedirects = 10,
}) async {
  var currentUri = Uri.parse(url);
  var currentMethod = method.toUpperCase();
  var currentData = data;
  var currentHeaders = options?.headers != null
      ? Map<String, dynamic>.from(options!.headers!)
      : <String, dynamic>{};
  var currentContentType = options?.contentType;
  final callerValidateStatus = options?.validateStatus;

  for (var hop = 0; hop <= maxRedirects; hop++) {
    final hopOptions = Options(
      method: currentMethod,
      sendTimeout: options?.sendTimeout,
      receiveTimeout: options?.receiveTimeout,
      extra: options?.extra,
      headers: currentHeaders.isEmpty ? null : currentHeaders,
      preserveHeaderCase: options?.preserveHeaderCase,
      responseType: options?.responseType,
      contentType: currentContentType,
      validateStatus: (status) {
        if (status == null) return false;
        if (status >= 300 && status < 400) return true;
        if (callerValidateStatus != null) {
          return callerValidateStatus(status);
        }
        return dio.options.validateStatus(status);
      },
      receiveDataWhenStatusError: options?.receiveDataWhenStatusError,
      followRedirects: false,
      maxRedirects: options?.maxRedirects,
      persistentConnection: options?.persistentConnection,
      requestEncoder: options?.requestEncoder,
      responseDecoder: options?.responseDecoder,
      listFormat: options?.listFormat,
    );

    final response = await dio.request<T>(
      currentUri.toString(),
      data: currentData,
      onReceiveProgress: onReceiveProgress,
      options: hopOptions,
    );

    final status = response.statusCode ?? 0;
    final location = response.headers.value('location');
    final isRedirect = status == 301 ||
        status == 302 ||
        status == 303 ||
        status == 307 ||
        status == 308;

    if (!isRedirect || location == null || location.trim().isEmpty) {
      return RedirectResponse<T>(
        response: response,
        finalUri: currentUri,
      );
    }

    if (hop == maxRedirects) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Exceeded maximum redirects ($maxRedirects) at $currentUri',
      );
    }

    final previousUri = currentUri;
    currentUri = currentUri.resolve(location.trim());

    if (status == 303 ||
        ((status == 301 || status == 302) &&
            currentMethod != 'GET' &&
            currentMethod != 'HEAD')) {
      currentMethod = 'GET';
      currentData = null;
      currentContentType = null;
      currentHeaders.removeWhere(
        (k, _) {
          final lower = k.toLowerCase();
          return lower == 'content-type' || lower == 'content-length';
        },
      );
    }

    // Preserve same-origin Referer on redirects if caller did not set one.
    if (currentUri.host == previousUri.host &&
        !currentHeaders.keys.any((k) => k.toLowerCase() == 'referer')) {
      currentHeaders['Referer'] = previousUri.toString();
    }
  }

  throw StateError('Unreachable redirect termination for $url');
}
