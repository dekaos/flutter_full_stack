import 'package:flutter_full_stack_client/flutter_full_stack_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

part 'serverpod_client.g.dart';

/// Provides an initialized Serverpod [Client].
///
/// The server URL is resolved from `--dart-define=SERVER_URL=...`,
/// falling back to `assets/config.json` and then to localhost.
@Riverpod(keepAlive: true)
Future<Client> serverpodClient(Ref ref) async {
  final serverUrl = await getServerUrl();

  final client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();

  await client.auth.initialize();

  return client;
}
