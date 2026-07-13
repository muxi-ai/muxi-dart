import 'dart:async';
import 'dart:io';

import 'package:muxi/src/errors.dart';
import 'package:muxi/src/formation_client.dart';
import 'package:muxi/src/server_client.dart';
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

    test('parses widgets from a ui frame', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('event: ui\n');
        request.response.write(
            'data: {"ui":[{"type":"options","id":"w1","prompt":"Which?",'
            '"options":[{"value":"us","label":"United States"}]},'
            '{"type":"action_link","id":"w2","label":"Dash","url":"https://x.io"}]}\n\n');
        request.response.write('event: done\n\n');
        await request.response.close();
      });
      addTearDown(server.close);

      final events =
          await _client(server).chatStream({'message': 'hi'}).toList();
      final uiEvent = events.firstWhere((e) => e.event == 'ui');
      final widgets = parseUiWidgets(uiEvent);

      expect(widgets.length, 2);
      expect(widgets[0]['type'], 'options');
      expect(widgets[0]['options'][0]['label'], 'United States');
      expect(widgets[1]['url'], 'https://x.io');
    });

    test('parse ui widgets ignores other frames', () {
      expect(parseUiWidgets(SseEvent('message', 'hi')), isEmpty);
      expect(parseUiWidgets(SseEvent('ui', 'not json')), isEmpty);
      expect(parseUiWidgets(SseEvent('ui', '{"ui":{}}')), isEmpty);
    });

    test('unwraps the echoed idempotency_key from the envelope', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
            '{"object":"api_response","timestamp":123,'
            '"request":{"id":"req-1","idempotency_key":"idem-42"},'
            '"data":{"foo":"bar"},"success":true}');
        await request.response.close();
      });
      addTearDown(server.close);

      final out = await _client(server).chat({'message': 'hi'});

      expect(out?['foo'], 'bar');
      expect(out?['request_id'], 'req-1');
      expect(out?['idempotency_key'], 'idem-42');
    });

    test('omits idempotency_key when not echoed', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
            '{"object":"api_response","request":{"id":"req-1"},'
            '"data":{"foo":"bar"},"success":true}');
        await request.response.close();
      });
      addTearDown(server.close);

      final out = await _client(server).chat({'message': 'hi'});

      expect(out, isNot(contains('idempotency_key')));
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
