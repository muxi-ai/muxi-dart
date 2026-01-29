# MUXI Dart SDK

Official Dart SDK for the MUXI AI platform.

## Requirements

- Dart SDK 3.0+

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

## Quick Start

### Server Management (Control Plane)

```dart
import 'dart:io';
import 'package:muxi/muxi.dart';

void main() async {
  final server = ServerClient(ServerConfig(
    url: Platform.environment['MUXI_SERVER_URL']!,
    keyId: Platform.environment['MUXI_KEY_ID']!,
    secretKey: Platform.environment['MUXI_SECRET_KEY']!,
  ));

  // List formations
  final formations = await server.listFormations();
  print(formations);

  // Get server status
  final status = await server.status();
  print('Uptime: ${status?['uptime']}s');
  
  server.close();
}
```

### Formation Usage (Runtime API)

```dart
import 'dart:io';
import 'package:muxi/muxi.dart';

void main() async {
  final client = FormationClient(FormationConfig(
    formationId: 'my-bot',
    serverUrl: Platform.environment['MUXI_SERVER_URL'],
    adminKey: Platform.environment['MUXI_ADMIN_KEY'],
    clientKey: Platform.environment['MUXI_CLIENT_KEY'],
  ));

  // Chat (non-streaming)
  final response = await client.chat({'message': 'Hello!'}, userId: 'user123');
  print(response?['message']);

  // Chat (streaming)
  await for (final event in client.chatStream({'message': 'Tell me a story'}, userId: 'user123')) {
    stdout.write(event.data);
  }

  // Health check
  final health = await client.health();
  print('Status: ${health?['status']}');
  
  client.close();
}
```

## Webhook Verification

```dart
import 'package:muxi/muxi.dart';

void handleWebhook(String payload, String? signature) {
  final secret = Platform.environment['WEBHOOK_SECRET']!;
  
  if (!Webhook.verifySignature(payload, signature, secret)) {
    throw Exception('Invalid signature');
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
}
```

## Error Handling

```dart
import 'package:muxi/muxi.dart';

try {
  await server.getFormation('nonexistent');
} on NotFoundException catch (e) {
  print('Not found: ${e.message}');
} on AuthenticationException catch (e) {
  print('Auth failed: ${e.message}');
} on RateLimitException catch (e) {
  print('Rate limited. Retry after: ${e.retryAfter}s');
} on MuxiException catch (e) {
  print('Error: ${e.message} (${e.statusCode})');
}
```

## License

MIT
