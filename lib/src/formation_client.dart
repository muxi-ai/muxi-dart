import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'errors.dart';
import 'version.dart';
import 'version_check.dart';
import 'server_client.dart';

class FormationConfig {
  final String? formationId;
  final String? url;
  final String? serverUrl;
  final String? baseUrl;
  final String? adminKey;
  final String? clientKey;
  final int maxRetries;
  final int timeout;
  final bool debug;
  final String mode;  // "live" (default) or "draft" for local dev
  final String? app;  // Internal: for Console telemetry

  FormationConfig({
    this.formationId,
    this.url,
    this.serverUrl,
    this.baseUrl,
    this.adminKey,
    this.clientKey,
    this.maxRetries = 0,
    this.timeout = 30,
    this.debug = false,
    this.mode = 'live',
    this.app,
  });
}

class FormationClient {
  final _FormationTransport _transport;

  FormationClient(FormationConfig config) : _transport = _FormationTransport(
    baseUrl: _buildBaseUrl(config),
    adminKey: config.adminKey,
    clientKey: config.clientKey,
    timeout: config.timeout,
    maxRetries: config.maxRetries,
    debug: config.debug,
    app: config.app,
  );

  static String _buildBaseUrl(FormationConfig c) {
    if (c.baseUrl != null && c.baseUrl!.isNotEmpty) return c.baseUrl!.replaceAll(RegExp(r'/+$'), '');
    if (c.url != null && c.url!.isNotEmpty) return '${c.url!.replaceAll(RegExp(r'/+$'), '')}/v1';
    if (c.serverUrl != null && c.serverUrl!.isNotEmpty && c.formationId != null && c.formationId!.isNotEmpty) {
      final prefix = c.mode == 'draft' ? 'draft' : 'api';
      return '${c.serverUrl!.replaceAll(RegExp(r'/+$'), '')}/$prefix/${c.formationId}/v1';
    }
    throw ArgumentError('must set baseUrl, url, or serverUrl+formationId');
  }

  // Health / status
  Future<Map<String, dynamic>?> health() async => await _transport.request('GET', '/health', useAdmin: false);
  Future<Map<String, dynamic>?> getStatus() async => await _transport.request('GET', '/status');
  Future<Map<String, dynamic>?> getConfig() async => await _transport.request('GET', '/config');
  Future<Map<String, dynamic>?> getFormationInfo() async => await _transport.request('GET', '/formation');

  // Agents / MCP
  Future<Map<String, dynamic>?> getAgents() async => await _transport.request('GET', '/agents');
  Future<Map<String, dynamic>?> getAgent(String agentId) async => await _transport.request('GET', '/agents/$agentId');
  Future<Map<String, dynamic>?> getMcpServers() async => await _transport.request('GET', '/mcp/servers');
  Future<Map<String, dynamic>?> getMcpServer(String serverId) async => await _transport.request('GET', '/mcp/servers/$serverId');
  Future<Map<String, dynamic>?> getMcpTools() async => await _transport.request('GET', '/mcp/tools');

  // Secrets
  Future<Map<String, dynamic>?> getSecrets() async => await _transport.request('GET', '/secrets');
  Future<Map<String, dynamic>?> getSecret(String key) async => await _transport.request('GET', '/secrets/$key');
  Future<void> setSecret(String key, String value) async => await _transport.request('PUT', '/secrets/$key', body: {'value': value});
  Future<void> deleteSecret(String key) async => await _transport.request('DELETE', '/secrets/$key');

  // Chat
  Future<Map<String, dynamic>?> chat(Map<String, dynamic> payload, {String userId = ''}) async => await _transport.request('POST', '/chat', body: payload, useAdmin: false, userId: userId);
  Stream<SseEvent> chatStream(Map<String, dynamic> payload, {String userId = ''}) => _transport.streamSse('POST', '/chat', body: {...payload, 'stream': true}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> audioChat(Map<String, dynamic> payload, {String userId = ''}) async => await _transport.request('POST', '/audiochat', body: payload, useAdmin: false, userId: userId);
  Stream<SseEvent> audioChatStream(Map<String, dynamic> payload, {String userId = ''}) => _transport.streamSse('POST', '/audiochat', body: {...payload, 'stream': true}, useAdmin: false, userId: userId);

  // Sessions
  Future<Map<String, dynamic>?> getSessions(String userId, {int? limit}) async => await _transport.request('GET', '/sessions', params: {'user_id': userId, if (limit != null) 'limit': limit}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> getSession(String sessionId, String userId) async => await _transport.request('GET', '/sessions/$sessionId', useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> getSessionMessages(String sessionId, String userId) async => await _transport.request('GET', '/sessions/$sessionId/messages', useAdmin: false, userId: userId);
  Future<void> restoreSession(String sessionId, String userId, List<Map<String, dynamic>> messages) async => await _transport.request('POST', '/sessions/$sessionId/restore', body: {'messages': messages}, useAdmin: false, userId: userId);

  // Requests
  Future<Map<String, dynamic>?> getRequests(String userId) async => await _transport.request('GET', '/requests', useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> getRequestStatus(String requestId, String userId) async => await _transport.request('GET', '/requests/$requestId', useAdmin: false, userId: userId);
  Future<void> cancelRequest(String requestId, String userId) async => await _transport.request('DELETE', '/requests/$requestId', useAdmin: false, userId: userId);

  // Memory
  Future<Map<String, dynamic>?> getMemoryConfig() async => await _transport.request('GET', '/memory');
  Future<Map<String, dynamic>?> getMemories(String userId, {int? limit}) async => await _transport.request('GET', '/memories', params: {'user_id': userId, if (limit != null) 'limit': limit}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> addMemory(String userId, String type, String detail) async => await _transport.request('POST', '/memories', body: {'user_id': userId, 'type': type, 'detail': detail}, useAdmin: false, userId: userId);
  Future<void> deleteMemory(String userId, String memoryId) async => await _transport.request('DELETE', '/memories/$memoryId', params: {'user_id': userId}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> getUserBuffer(String userId) async => await _transport.request('GET', '/memory/buffer', params: {'user_id': userId}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> clearUserBuffer(String userId) async => await _transport.request('DELETE', '/memory/buffer', params: {'user_id': userId}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> clearSessionBuffer(String userId, String sessionId) async => await _transport.request('DELETE', '/memory/buffer/$sessionId', params: {'user_id': userId}, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> clearAllBuffers() async => await _transport.request('DELETE', '/memory/buffer');
  Future<Map<String, dynamic>?> getBufferStats() async => await _transport.request('GET', '/memory/stats');

  // Scheduler
  Future<Map<String, dynamic>?> getSchedulerConfig() async => await _transport.request('GET', '/scheduler');
  Future<Map<String, dynamic>?> getSchedulerJobs(String userId) async => await _transport.request('GET', '/scheduler/jobs', params: {'user_id': userId});
  Future<Map<String, dynamic>?> getSchedulerJob(String jobId) async => await _transport.request('GET', '/scheduler/jobs/$jobId');
  Future<Map<String, dynamic>?> createSchedulerJob(String type, String schedule, String message, String userId) async => await _transport.request('POST', '/scheduler/jobs', body: {'type': type, 'schedule': schedule, 'message': message, 'user_id': userId});
  Future<void> deleteSchedulerJob(String jobId) async => await _transport.request('DELETE', '/scheduler/jobs/$jobId');

  // Config endpoints
  Future<Map<String, dynamic>?> getAsyncConfig() async => await _transport.request('GET', '/async');
  Future<Map<String, dynamic>?> getA2aConfig() async => await _transport.request('GET', '/a2a');
  Future<Map<String, dynamic>?> getLoggingConfig() async => await _transport.request('GET', '/logging');
  Future<Map<String, dynamic>?> getLoggingDestinations() async => await _transport.request('GET', '/logging/destinations');

  // Credentials
  Future<Map<String, dynamic>?> listCredentialServices() async => await _transport.request('GET', '/credentials/services');
  Future<Map<String, dynamic>?> listCredentials(String userId) async => await _transport.request('GET', '/credentials', useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> getCredential(String credentialId, String userId) async => await _transport.request('GET', '/credentials/$credentialId', useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> createCredential(String userId, Map<String, dynamic> payload) async => await _transport.request('POST', '/credentials', body: payload, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> deleteCredential(String credentialId, String userId) async => await _transport.request('DELETE', '/credentials/$credentialId', useAdmin: false, userId: userId);

  // User identifiers
  Future<Map<String, dynamic>?> getUserIdentifiersForUser(String userId) async => await _transport.request('GET', '/users/identifiers/$userId');
  Future<Map<String, dynamic>?> linkUserIdentifier(String muxiUserId, List<dynamic> identifiers) async => await _transport.request('POST', '/users/identifiers', body: {'muxi_user_id': muxiUserId, 'identifiers': identifiers});
  Future<void> unlinkUserIdentifier(String identifier) async => await _transport.request('DELETE', '/users/identifiers/$identifier');

  // Overlord / LLM
  Future<Map<String, dynamic>?> getOverlordConfig() async => await _transport.request('GET', '/overlord');
  Future<Map<String, dynamic>?> getOverlordPersona() async => await _transport.request('GET', '/overlord/persona');
  Future<Map<String, dynamic>?> getLlmSettings() async => await _transport.request('GET', '/llm/settings');

  // Triggers / SOP / Audit
  Future<Map<String, dynamic>?> getTriggers() async => await _transport.request('GET', '/triggers', useAdmin: false);
  Future<Map<String, dynamic>?> getTrigger(String name) async => await _transport.request('GET', '/triggers/$name', useAdmin: false);
  Future<Map<String, dynamic>?> fireTrigger(String name, dynamic data, {bool async = false, String userId = ''}) async => await _transport.request('POST', '/triggers/$name', params: {'async': async.toString()}, body: data, useAdmin: false, userId: userId);
  Future<Map<String, dynamic>?> getSops() async => await _transport.request('GET', '/sops', useAdmin: false);
  Future<Map<String, dynamic>?> getSop(String name) async => await _transport.request('GET', '/sops/$name', useAdmin: false);
  Future<Map<String, dynamic>?> getAuditLog() async => await _transport.request('GET', '/audit');
  Future<void> clearAuditLog() async => await _transport.request('DELETE', '/audit?confirm=clear-audit-log');

  // Streaming
  Stream<SseEvent> streamEvents(String userId) => _transport.streamSse('GET', '/events', params: {'user_id': userId}, useAdmin: false, userId: userId);
  Stream<SseEvent> streamRequest(String userId, String sessionId, String requestId) => _transport.streamSse('GET', '/events/$sessionId/$requestId', useAdmin: false, userId: userId);
  Stream<SseEvent> streamLogs({Map<String, dynamic>? filters}) => _transport.streamSse('GET', '/logs', params: filters);

  // Resolve user
  Future<Map<String, dynamic>?> resolveUser(String identifier, {bool createUser = false}) async => await _transport.request('POST', '/users/resolve', body: {'identifier': identifier, 'create_user': createUser}, useAdmin: false);

  void close() => _transport.close();
}

class _FormationTransport {
  final String baseUrl;
  final String? adminKey;
  final String? clientKey;
  final int timeout;
  final int maxRetries;
  final bool debug;
  final String? app;
  final http.Client _client;

  _FormationTransport({
    required this.baseUrl,
    this.adminKey,
    this.clientKey,
    this.timeout = 30,
    this.maxRetries = 0,
    this.debug = false,
    this.app,
  }) : _client = http.Client();

  Future<Map<String, dynamic>?> request(String method, String path, {Map<String, dynamic>? params, dynamic body, bool useAdmin = true, String userId = ''}) async {
    final (url, _) = _buildUrl(path, params);
    final headers = _buildHeaders(useAdmin, userId, body != null);

    final request = http.Request(method, Uri.parse(url));
    headers.forEach((k, v) => request.headers[k] = v);
    if (body != null) request.body = jsonEncode(body);

    final streamedResponse = await _client.send(request).timeout(Duration(seconds: timeout));
    final response = await http.Response.fromStream(streamedResponse);

    // Check for SDK updates (non-blocking, once per process)
    VersionCheck.checkForUpdates(response.headers);

    if (response.statusCode >= 400) {
      String? code;
      var message = 'Unknown error';
      try { final p = jsonDecode(response.body); code = p['code'] ?? p['error']; message = p['message'] ?? message; } catch (_) {}
      throw mapError(response.statusCode, code, message, null, int.tryParse(response.headers['retry-after'] ?? ''));
    }

    if (response.body.isEmpty) return null;

    try {
      final parsed = jsonDecode(response.body);
      return _unwrapEnvelope(parsed);
    } catch (_) {
      return null;
    }
  }

  Stream<SseEvent> streamSse(String method, String path, {Map<String, dynamic>? params, dynamic body, bool useAdmin = true, String userId = ''}) async* {
    final (url, _) = _buildUrl(path, params);
    final headers = _buildHeaders(useAdmin, userId, body != null, accept: 'text/event-stream');

    final request = http.Request(method, Uri.parse(url));
    headers.forEach((k, v) => request.headers[k] = v);
    if (body != null) request.body = jsonEncode(body);

    final response = await _client.send(request);
    String? currentEvent;
    final dataParts = <String>[];

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
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

  (String url, String fullPath) _buildUrl(String path, Map<String, dynamic>? params) {
    final relPath = path.startsWith('/') ? path : '/$path';
    var query = '';
    if (params != null && params.isNotEmpty) {
      final filtered = params.entries.where((e) => e.value != null).map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');
      if (filtered.isNotEmpty) query = '?$filtered';
    }
    final fullPath = '$relPath$query';
    return ('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$fullPath', fullPath);
  }

  Map<String, String> _buildHeaders(bool useAdmin, String userId, bool hasBody, {String accept = 'application/json'}) {
    final headers = <String, String>{
      'X-Muxi-SDK': 'dart/$muxiVersion',
      'X-Muxi-Client': 'dart/$muxiVersion',
      'X-Muxi-Idempotency-Key': DateTime.now().millisecondsSinceEpoch.toString(),
      'Accept': accept,
    };
    if (app != null && app!.isNotEmpty) headers['X-Muxi-App'] = app!;
    if (useAdmin) headers['X-MUXI-ADMIN-KEY'] = adminKey ?? (throw ArgumentError('admin key required'));
    else headers['X-MUXI-CLIENT-KEY'] = clientKey ?? (throw ArgumentError('client key required'));
    if (userId.isNotEmpty) headers['X-Muxi-User-ID'] = userId;
    if (hasBody) headers['Content-Type'] = 'application/json';
    return headers;
  }

  Map<String, dynamic>? _unwrapEnvelope(dynamic obj) {
    if (obj is! Map<String, dynamic> || !obj.containsKey('data')) {
      return obj is Map<String, dynamic> ? obj : null;
    }
    final req = obj['request'] as Map<String, dynamic>?;
    final requestId = req?['id'] ?? obj['request_id'];
    final data = obj['data'];
    if (data is Map<String, dynamic>) {
      final out = Map<String, dynamic>.from(data);
      if (requestId != null) out['request_id'] ??= requestId;
      if (obj['timestamp'] != null) out['timestamp'] ??= obj['timestamp'];
      return out;
    }
    return data is Map<String, dynamic> ? data : obj;
  }

  void close() => _client.close();
}
