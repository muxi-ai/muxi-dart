import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'errors.dart';
import 'version.dart';

class Transport {
  static const _retryStatuses = {429, 500, 502, 503, 504};
  
  final String baseUrl;
  final String keyId;
  final String secretKey;
  final int timeout;
  final int maxRetries;
  final bool debug;
  final http.Client _client;

  Transport({
    required this.baseUrl,
    required this.keyId,
    required this.secretKey,
    this.timeout = 30,
    this.maxRetries = 0,
    this.debug = false,
  }) : _client = http.Client();

  Future<dynamic> requestJson(String method, String path, {Map<String, dynamic>? params, dynamic body}) async {
    final (url, fullPath) = _buildUrl(path, params);
    final headers = _buildHeaders(method, fullPath);

    var attempt = 0;
    var backoff = 0.5;

    while (true) {
      final startTime = DateTime.now();
      try {
        final request = http.Request(method, Uri.parse(url));
        headers.forEach((k, v) => request.headers[k] = v);
        
        if (body != null) {
          request.body = jsonEncode(body);
        }

        final streamedResponse = await _client.send(request).timeout(Duration(seconds: timeout));
        final response = await http.Response.fromStream(streamedResponse);
        final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;
        _log('$method $fullPath -> ${response.statusCode} (${elapsed.toStringAsFixed(3)}s)');

        if (response.statusCode >= 400) {
          final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');

          if (_retryStatuses.contains(response.statusCode) && attempt < maxRetries) {
            final sleepFor = backoff < 30 ? backoff : 30.0;
            _log('retry $method $fullPath after ${sleepFor}s due to ${response.statusCode}');
            await Future.delayed(Duration(milliseconds: (sleepFor * 1000).toInt()));
            backoff *= 2;
            attempt++;
            continue;
          }

          String? code;
          var message = 'Unknown error';
          Map<String, dynamic>? details;

          try {
            final payload = jsonDecode(response.body);
            code = payload['code'] ?? payload['error'];
            message = payload['message'] ?? message;
            details = payload is Map<String, dynamic> ? payload : null;
          } catch (_) {}

          throw mapError(response.statusCode, code, message, details, retryAfter);
        }

        if (response.body.isEmpty) return null;

        try {
          final parsed = jsonDecode(response.body);
          return _unwrapEnvelope(parsed);
        } catch (_) {
          return response.body;
        }
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          final sleepFor = backoff < 30 ? backoff : 30.0;
          _log('retry $method $fullPath after ${sleepFor}s due to connection error: $e');
          await Future.delayed(Duration(milliseconds: (sleepFor * 1000).toInt()));
          backoff *= 2;
          attempt++;
          continue;
        }
        throw ConnectionException(e.message);
      } on TimeoutException {
        if (attempt < maxRetries) {
          final sleepFor = backoff < 30 ? backoff : 30.0;
          _log('retry $method $fullPath after ${sleepFor}s due to timeout');
          await Future.delayed(Duration(milliseconds: (sleepFor * 1000).toInt()));
          backoff *= 2;
          attempt++;
          continue;
        }
        throw ConnectionException('Request timed out');
      }
    }
  }

  Stream<String> streamLines(String method, String path, {Map<String, dynamic>? params, dynamic body}) async* {
    final (url, fullPath) = _buildUrl(path, params);
    final headers = _buildHeaders(method, fullPath, accept: 'text/event-stream');

    final request = http.Request(method, Uri.parse(url));
    headers.forEach((k, v) => request.headers[k] = v);
    
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response = await _client.send(request);
    await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      yield chunk;
    }
  }

  (String url, String fullPath) _buildUrl(String path, Map<String, dynamic>? params) {
    final relPath = path.startsWith('/') ? path : '/$path';
    var query = '';
    if (params != null) {
      final filtered = params.entries.where((e) => e.value != null).map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');
      if (filtered.isNotEmpty) query = '?$filtered';
    }
    final fullPath = '$relPath$query';
    return ('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$fullPath', fullPath);
  }

  Map<String, String> _buildHeaders(String method, String path, {String accept = 'application/json'}) => {
    'Authorization': Auth.buildAuthHeader(keyId, secretKey, method, path),
    'Content-Type': 'application/json',
    'Accept': accept,
    'X-Muxi-SDK': 'dart/$muxiVersion',
    'X-Muxi-Client': 'dart/${Platform.version.split(' ').first}',
    'X-Muxi-Idempotency-Key': _generateUuid(),
  };

  dynamic _unwrapEnvelope(dynamic obj) {
    if (obj is! Map<String, dynamic> || !obj.containsKey('data')) return obj;

    final req = obj['request'] as Map<String, dynamic>?;
    final requestId = req?['id'] ?? obj['request_id'];
    final ts = obj['timestamp'];
    final data = obj['data'];

    if (data is Map<String, dynamic>) {
      final out = Map<String, dynamic>.from(data);
      if (requestId != null) out['request_id'] ??= requestId;
      if (ts != null) out['timestamp'] ??= ts;
      return out;
    }

    return data ?? obj;
  }

  String _generateUuid() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return '${random.toRadixString(16)}-${(random ~/ 1000).toRadixString(16)}-4000-8000-${random.toRadixString(16)}';
  }

  void _log(String msg) {
    if (debug || Platform.environment['MUXI_DEBUG'] == '1') {
      stderr.writeln('[MUXI] $msg');
    }
  }

  void close() => _client.close();
}
