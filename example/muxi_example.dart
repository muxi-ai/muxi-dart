import 'package:muxi/muxi.dart';

void main() async {
  // Server Client - for managing formations
  final serverConfig = ServerConfig(
    url: 'https://api.muxi.org',
    keyId: 'your-key-id',
    secretKey: 'your-secret-key',
  );
  final server = ServerClient(serverConfig);

  // Check server status
  final status = await server.status();
  print('Server status: $status');

  // List formations
  final formations = await server.listFormations();
  print('Formations: $formations');

  // Formation Client - for interacting with agents
  final formationConfig = FormationConfig(
    formationId: 'your-formation-id',
    clientKey: 'your-client-key',
  );
  final formation = FormationClient(formationConfig);

  // Send a message to an agent
  final response = await formation.chat({
    'agent': 'assistant',
    'input': 'Hello, how can you help me?',
  });
  print('Agent response: $response');

  // Clean up
  server.close();
  formation.close();
}
