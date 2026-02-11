import 'dart:io';
import 'package:test/test.dart';
import 'package:muxi/muxi.dart';

String? env(String name) => Platform.environment[name];

String requireEnv(String name) {
  final value = env(name);
  if (value == null || value.isEmpty) {
    throw TestFailure('$name not set');
  }
  return value;
}

void main() {
  late ServerClient serverClient;
  late FormationClient formationClient;
  var configured = false;

  setUpAll(() {
    try {
      final serverUrl = requireEnv('MUXI_SDK_E2E_SERVER_URL');
      final keyId = requireEnv('MUXI_SDK_E2E_KEY_ID');
      final secretKey = requireEnv('MUXI_SDK_E2E_SECRET_KEY');
      final formationId = requireEnv('MUXI_SDK_E2E_FORMATION_ID');
      final clientKey = requireEnv('MUXI_SDK_E2E_CLIENT_KEY');
      final adminKey = requireEnv('MUXI_SDK_E2E_ADMIN_KEY');

      serverClient = ServerClient(ServerConfig(
        url: serverUrl,
        keyId: keyId,
        secretKey: secretKey,
      ));

      formationClient = FormationClient(FormationConfig(
        serverUrl: serverUrl,
        formationId: formationId,
        clientKey: clientKey,
        adminKey: adminKey,
      ));

      configured = true;
    } catch (e) {
      // Will skip tests
    }
  });

  group('ServerClient Integration', () {
    test('ping returns pong', () async {
      if (!configured) return;
      final result = await serverClient.ping();
      expect(result, greaterThanOrEqualTo(0));
    });

    test('health returns status', () async {
      if (!configured) return;
      final result = await serverClient.health();
      expect(result, isNotNull);
    });

    test('status returns server info', () async {
      if (!configured) return;
      final result = await serverClient.status();
      expect(result, isNotNull);
    });

    test('listFormations returns formations', () async {
      if (!configured) return;
      final result = await serverClient.listFormations();
      expect(result, isNotNull);
    });
  });

  group('FormationClient Integration', () {
    test('health returns status', () async {
      if (!configured) return;
      final result = await formationClient.health();
      expect(result, isNotNull);
    });

    test('getStatus returns formation status', () async {
      if (!configured) return;
      final result = await formationClient.getStatus();
      expect(result, isNotNull);
    });

    test('getConfig returns configuration', () async {
      if (!configured) return;
      final result = await formationClient.getConfig();
      expect(result, isNotNull);
    });

    test('getAgents returns agents list', () async {
      if (!configured) return;
      final result = await formationClient.getAgents();
      expect(result, isNotNull);
    });
  });
}
