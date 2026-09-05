import 'dart:io';

import 'package:flutter_app_back_server/src/generated/endpoints.dart';
import 'package:flutter_app_back_server/src/generated/protocol.dart';
import 'package:flutter_app_back_server/src/web/routes/app_config_route.dart';
import 'package:flutter_app_back_server/src/web/routes/root.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

/// The starting point of the Serverpod server.
Future<void> run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  //
  // Token managers validate and issue authentication keys, and the identity
  // providers are the authentication options available for users.
  final pod = Serverpod(args, Protocol(), Endpoints())
    ..initializeAuthServices(
      tokenManagerBuilders: [
        // Use JWT for authentication keys towards the server.
        JwtConfigFromPasswords(),
      ],
      identityProviderBuilders: [
        // Configure the email identity provider for email/password
        // authentication.
        EmailIdpConfigFromPasswords(
          sendRegistrationVerificationCode: _sendRegistrationCode,
          sendPasswordResetVerificationCode: _sendPasswordResetCode,
        ),
      ],
    );

  // Setup a default page at the web root.
  pod.webServer
    ..addRoute(RootRoute())
    ..addRoute(RootRoute(), '/index.html')
    // Serve all files in the web/static relative directory under /.
    ..addRoute(
      StaticRoute.directory(Directory(Uri(path: 'web/static').toFilePath())),
    )
    // Serve the app config, built from the server's api url, to the Flutter
    // app.
    ..addRoute(
      AppConfigRoute(apiConfig: pod.config.apiServer),
      '/app/assets/assets/config.json',
    );

  // Checks if the flutter web app has been built and serves it if it has.
  final appDir = Directory(Uri(path: 'web/app').toFilePath());
  if (appDir.existsSync()) {
    // Serve the flutter web app under the /app path.
    pod.webServer.addRoute(FlutterRoute(appDir), '/app');
  } else {
    // If the flutter web app has not been built, serve the build app page.
    pod.webServer.addRoute(
      StaticRoute.file(
        File(Uri(path: 'web/pages/build_flutter_app.html').toFilePath()),
      ),
      '/app/**',
    );
  }

  // Start the server.
  await pod.start();
}

void _sendRegistrationCode(
  Session session, {
  required String email,
  required UuidValue accountRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) {
  // NOTE: Here you call your mail service to send the verification code to
  // the user. For testing, we will just log the verification code.
  session.log('[EmailIdp] Registration code ($email): $verificationCode');
}

void _sendPasswordResetCode(
  Session session, {
  required String email,
  required UuidValue passwordResetRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) {
  // NOTE: Here you call your mail service to send the verification code to
  // the user. For testing, we will just log the verification code.
  session.log('[EmailIdp] Password reset code ($email): $verificationCode');
}
