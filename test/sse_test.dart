import 'dart:async';
import 'dart:io';

import 'package:muxi/src/errors.dart';
import 'package:muxi/src/formation_client.dart';
import 'package:test/test.dart';

Future<HttpServer> _startServer(
    FutureOr<void> Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(() async {
    await for (final request in server) {
      await handler(request);
    }
  }());
  return server;
}

FormationClient _client(HttpServer server) {
  return FormationClient(FormationConfig(
    baseUrl: 'http://${server.address.host}:${server.port}',
    clientKey: 'client-key',
    adminKey: 'admin-key',
  ));
}

void main() {
  group('SSE parsing', () {
    test('flushes event-only done frames', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write(': keepalive\n\n');
        request.response.write('event: done\n\n');
        await request.response.close();
      });
      addTearDown(server.close);

      final events =
          await _client(server).chatStream({'message': 'hi'}).toList();
      expect(events.length, 1);
      expect(events.first.event, 'done');
      expect(events.first.data, '');
    });

    test('preserves multiline data', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('event: planning\n');
        request.response.write('data: one\n');
        request.response.write('data: two\n\n');
        await request.response.close();
      });
      addTearDown(server.close);

      final events = await _client(server).streamEvents('user-1').toList();
      expect(events.single.event, 'planning');
      expect(events.single.data, 'one\ntwo');
    });

    test('route-level errors surface as exceptions', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('event: error\n');
        request.response
            .write('data: {"error":"boom","type":"RUNTIME_ERROR"}\n\n');
        await request.response.close();
      });
      addTearDown(server.close);

      expect(
        _client(server).chatStream({'message': 'hi'}).drain<void>(),
        throwsA(isA<MuxiException>()
            .having((e) => e.code, 'code', 'RUNTIME_ERROR')),
      );
    });
  });
}
