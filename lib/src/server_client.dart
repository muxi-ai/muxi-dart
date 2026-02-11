import 'dart:async';
import 'transport.dart';

/// Configuration for [ServerClient].
///
/// Use this to configure the MUXI server connection with HMAC authentication.
class ServerConfig {
  /// The base URL of the MUXI server (e.g., 'https://api.muxi.org').
  final String url;

  /// Your HMAC key ID for authentication.
  final String keyId;

  /// Your HMAC secret key for authentication.
  final String secretKey;

  /// Maximum number of retry attempts for failed requests.
  final int maxRetries;

  /// Request timeout in seconds.
  final int timeout;

  /// Enable debug logging.
  final bool debug;

  /// Internal: for Console telemetry.
  final String? app;

  /// Creates a new [ServerConfig].
  ServerConfig({
    required this.url,
    required this.keyId,
    required this.secretKey,
    this.maxRetries = 0,
    this.timeout = 30,
    this.debug = false,
    this.app,
  });
}

/// Represents a Server-Sent Event.
class SseEvent {
  /// The event type.
  final String event;

  /// The event data payload.
  final String data;

  /// Creates a new [SseEvent].
  SseEvent(this.event, this.data);
}

/// Client for managing MUXI formations via the server API.
///
/// Use this client to manage formations, API keys, and server status.
/// Requires HMAC authentication.
///
/// ```dart
/// final config = ServerConfig(
///   url: 'https://api.muxi.org',
///   keyId: 'your-key-id',
///   secretKey: 'your-secret-key',
/// );
/// final client = ServerClient(config);
/// final formations = await client.listFormations();
/// ```
class ServerClient {
  final Transport _transport;

  /// Creates a new [ServerClient] with the given configuration.
  ServerClient(ServerConfig config) : _transport = Transport(
    baseUrl: config.url,
    keyId: config.keyId,
    secretKey: config.secretKey,
    timeout: config.timeout,
    maxRetries: config.maxRetries,
    debug: config.debug,
    app: config.app,
  );

  // Unauthenticated
  Future<int> ping() async {
    final resp = await _transport.requestJson('GET', '/ping');
    return resp is Map ? resp.length : 0;
  }

  Future<Map<String, dynamic>?> health() async => await _transport.requestJson('GET', '/health');

  // Authenticated
  Future<Map<String, dynamic>?> status() async => await _rpcGet('/rpc/server/status');
  Future<Map<String, dynamic>?> listFormations() async => await _rpcGet('/rpc/formations');
  Future<Map<String, dynamic>?> getFormation(String formationId) async => await _rpcGet('/rpc/formations/$formationId');
  Future<Map<String, dynamic>?> stopFormation(String formationId) async => await _rpcPost('/rpc/formations/$formationId/stop', {});
  Future<Map<String, dynamic>?> startFormation(String formationId) async => await _rpcPost('/rpc/formations/$formationId/start', {});
  Future<Map<String, dynamic>?> restartFormation(String formationId) async => await _rpcPost('/rpc/formations/$formationId/restart', {});
  Future<Map<String, dynamic>?> rollbackFormation(String formationId) async => await _rpcPost('/rpc/formations/$formationId/rollback', {});
  Future<Map<String, dynamic>?> deleteFormation(String formationId) async => await _rpcDelete('/rpc/formations/$formationId');
  Future<Map<String, dynamic>?> cancelUpdate(String formationId) async => await _rpcPost('/rpc/formations/$formationId/cancel-update', {});
  Future<Map<String, dynamic>?> deployFormation(String formationId, Map<String, dynamic> payload) async => await _rpcPost('/rpc/formations/$formationId/deploy', payload);
  Future<Map<String, dynamic>?> updateFormation(String formationId, Map<String, dynamic> payload) async => await _rpcPost('/rpc/formations/$formationId/update', payload);
  Future<Map<String, dynamic>?> getFormationLogs(String formationId, {int? limit}) async => await _rpcGet('/rpc/formations/$formationId/logs', params: limit != null ? {'limit': limit} : null);
  Future<Map<String, dynamic>?> getServerLogs({int? limit}) async => await _rpcGet('/rpc/server/logs', params: limit != null ? {'limit': limit} : null);

  // Streaming
  Stream<SseEvent> deployFormationStream(String formationId, Map<String, dynamic> payload) => _streamSse('/rpc/formations/$formationId/deploy/stream', payload);
  Stream<SseEvent> updateFormationStream(String formationId, Map<String, dynamic> payload) => _streamSse('/rpc/formations/$formationId/update/stream', payload);
  Stream<SseEvent> startFormationStream(String formationId) => _streamSse('/rpc/formations/$formationId/start/stream', {});
  Stream<SseEvent> restartFormationStream(String formationId) => _streamSse('/rpc/formations/$formationId/restart/stream', {});
  Stream<SseEvent> rollbackFormationStream(String formationId) => _streamSse('/rpc/formations/$formationId/rollback/stream', {});
  Stream<SseEvent> streamFormationLogs(String formationId) => _streamSseGet('/rpc/formations/$formationId/logs/stream');

  Future<Map<String, dynamic>?> _rpcGet(String path, {Map<String, dynamic>? params}) async => await _transport.requestJson('GET', path, params: params);
  Future<Map<String, dynamic>?> _rpcPost(String path, Map<String, dynamic> body) async => await _transport.requestJson('POST', path, body: body);
  Future<Map<String, dynamic>?> _rpcDelete(String path) async => await _transport.requestJson('DELETE', path);

  Stream<SseEvent> _streamSse(String path, Map<String, dynamic> body) async* {
    String? currentEvent;
    final dataParts = <String>[];

    await for (final line in _transport.streamLines('POST', path, body: body)) {
      if (line.startsWith(':')) continue;
      if (line.isEmpty) {
        if (dataParts.isNotEmpty) yield SseEvent(currentEvent ?? 'message', dataParts.join('\n'));
        currentEvent = null;
        dataParts.clear();
        continue;
      }
      if (line.startsWith('event:')) currentEvent = line.substring(6).trim();
      else if (line.startsWith('data:')) dataParts.add(line.substring(5).trim());
    }
  }

  Stream<SseEvent> _streamSseGet(String path) async* {
    String? currentEvent;
    final dataParts = <String>[];

    await for (final line in _transport.streamLines('GET', path)) {
      if (line.startsWith(':')) continue;
      if (line.isEmpty) {
        if (dataParts.isNotEmpty) yield SseEvent(currentEvent ?? 'message', dataParts.join('\n'));
        currentEvent = null;
        dataParts.clear();
        continue;
      }
      if (line.startsWith('event:')) currentEvent = line.substring(6).trim();
      else if (line.startsWith('data:')) dataParts.add(line.substring(5).trim());
    }
  }

  void close() => _transport.close();
}
