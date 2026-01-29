# MUXI Dart SDK User Guide

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  muxi: ^0.20260129.0
```

Then run:

```bash
dart pub get
```

## Requirements

- Dart SDK 3.0+

## Quickstart

```dart
import 'dart:io';
import 'package:muxi/muxi.dart';

void main() async {
  // Server client (management, HMAC auth)
  final server = ServerClient(ServerConfig(
    url: Platform.environment['MUXI_SERVER_URL']!,
    keyId: Platform.environment['MUXI_KEY_ID']!,
    secretKey: Platform.environment['MUXI_SECRET_KEY']!,
  ));
  print(await server.status());
  
  // Formation client (runtime, key auth)
  final client = FormationClient(FormationConfig(
    serverUrl: Platform.environment['MUXI_SERVER_URL'],
    formationId: 'my-bot',
    clientKey: Platform.environment['MUXI_CLIENT_KEY'],
    adminKey: Platform.environment['MUXI_ADMIN_KEY'],
  ));
  print(await client.health());
  
  server.close();
  client.close();
}
```

## Clients

- **ServerClient** (management, HMAC): deploy/list/update formations, server health/status, server logs.
- **FormationClient** (runtime, client/admin keys): chat/audio (streaming), agents, secrets, MCP, memory, scheduler, sessions/requests, identifiers, credentials, triggers/SOPs/audit, async/A2A/logging config, overlord/LLM settings, events/logs streaming.

## Streaming

```dart
// Chat streaming with Dart Stream
await for (final event in client.chatStream({'message': 'Tell me a story'}, userId: 'user-123')) {
  stdout.write(event.data);
}

// Event streaming
await for (final event in client.streamEvents('user-123')) {
  print(event);
}

// Log streaming (admin)
await for (final log in client.streamLogs(filters: {'level': 'info'})) {
  print(log);
}
```

## Auth & Headers

- **ServerClient**: HMAC with `keyId`/`secretKey` on `/rpc` endpoints.
- **FormationClient**: `X-MUXI-CLIENT-KEY` or `X-MUXI-ADMIN-KEY` on `/api/{formation}/v1`. Override `baseUrl` for direct access (e.g., `http://localhost:9012/v1`).
- **Idempotency**: `X-Muxi-Idempotency-Key` auto-generated on every request.
- **SDK headers**: `X-Muxi-SDK`, `X-Muxi-Client` set automatically.

## Timeouts & Retries

- Default timeout: 30s (no timeout for streaming).
- Retries: `maxRetries` with exponential backoff on 429/5xx/connection errors; respects `Retry-After`.
- Debug logging: enabled when `debug: true` or `MUXI_DEBUG=1`.

## Error Handling

```dart
import 'package:muxi/muxi.dart';

try {
  await client.chat({'message': 'hello'});
} on AuthenticationException catch (e) {
  print('Auth failed: ${e.message}');
} on RateLimitException catch (e) {
  print('Rate limited. Retry after: ${e.retryAfter}s');
} on NotFoundException catch (e) {
  print('Not found: ${e.message}');
} on MuxiException catch (e) {
  print('${e.code}: ${e.message} (${e.statusCode})');
}
```

Error types: `AuthenticationException`, `AuthorizationException`, `NotFoundException`, `ValidationException`, `RateLimitException`, `ServerException`, `ConnectionException`.

## Notable Endpoints (FormationClient)

| Category | Methods |
|----------|---------|
| Chat/Audio | `chat`, `chatStream`, `audioChat`, `audioChatStream` |
| Memory | `getMemoryConfig`, `getMemories`, `addMemory`, `deleteMemory`, `getUserBuffer`, `clearUserBuffer`, `clearSessionBuffer`, `clearAllBuffers`, `getBufferStats` |
| Scheduler | `getSchedulerConfig`, `getSchedulerJobs`, `getSchedulerJob`, `createSchedulerJob`, `deleteSchedulerJob` |
| Sessions | `getSessions`, `getSession`, `getSessionMessages`, `restoreSession` |
| Requests | `getRequests`, `getRequestStatus`, `cancelRequest` |
| Agents/MCP | `getAgents`, `getAgent`, `getMcpServers`, `getMcpServer`, `getMcpTools` |
| Secrets | `getSecrets`, `getSecret`, `setSecret`, `deleteSecret` |
| Credentials | `listCredentialServices`, `listCredentials`, `getCredential`, `createCredential`, `deleteCredential` |
| Identifiers | `getUserIdentifiersForUser`, `linkUserIdentifier`, `unlinkUserIdentifier` |
| Triggers/SOP | `getTriggers`, `getTrigger`, `fireTrigger`, `getSops`, `getSop` |
| Audit | `getAuditLog`, `clearAuditLog` |
| Config | `getStatus`, `getConfig`, `getFormationInfo`, `getAsyncConfig`, `getA2aConfig`, `getLoggingConfig`, `getLoggingDestinations`, `getOverlordConfig`, `getOverlordPersona`, `getLlmSettings` |
| Streaming | `streamEvents`, `streamLogs`, `streamRequest` |
| User | `resolveUser` |

## Webhook Verification

```dart
import 'package:muxi/muxi.dart';
import 'package:shelf/shelf.dart';

Response handleWebhook(Request request) async {
  final payload = await request.readAsString();
  final signature = request.headers['x-muxi-signature'];
  final secret = Platform.environment['WEBHOOK_SECRET']!;
  
  if (!Webhook.verifySignature(payload, signature, secret)) {
    return Response.unauthorized('Invalid signature');
  }
  
  final event = Webhook.parse(payload);
  
  switch (event.status) {
    case 'completed':
      for (final item in event.content.where((c) => c.type == 'text')) {
        print(item.text);
      }
      break;
    case 'failed':
      print('Error: ${event.error?.message}');
      break;
    case 'awaiting_clarification':
      print('Question: ${event.clarification?.question}');
      break;
  }
  
  return Response.ok('{"status": "received"}');
}
```

## Testing Locally

```bash
cd dart
dart pub get
dart test
```
