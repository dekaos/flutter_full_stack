// Exits non-zero if any of the TCP ports given as arguments is already taken.
//
// Why this exists: when Serverpod cannot bind a port it logs "Failed to start
// the Serverpod servers" and then stays alive instead of exiting, and in that
// state it stops answering SIGTERM too - only SIGKILL removes it. So a second
// `server:start` or `server:debug` does not fail fast. It leaves behind a
// process that looks like a running server but serves nothing, and the next
// run collides with that one as well. Three of those had piled up before this
// check existed.
//
// Written in Dart rather than shell so it runs the same on Windows, and
// because binding is the real question - `lsof` only approximates it, and is
// not installed everywhere.
//
// This is a guard, not a lock: a port can still be taken between this check
// and the server's own bind. It catches the case that actually happens, which
// is a server already running.

import 'dart:io';

Future<void> main(List<String> args) async {
  final taken = <int>[];

  for (final arg in args) {
    final port = int.tryParse(arg);
    if (port == null) {
      stderr.writeln('require_free_ports: not a port number: $arg');
      exit(2);
    }
    if (!await _isFree(port)) taken.add(port);
  }

  if (taken.isEmpty) return;

  for (final port in taken) {
    final owner = await _describeOwner(port);
    stderr.writeln('Port $port is already in use${owner ?? ''}.');
  }
  stderr
    ..writeln()
    ..writeln(
      'Stop that server before starting another one. A stale one that failed '
      'to bind ignores SIGTERM, so it needs `kill -9 <pid>`.',
    );
  exit(1);
}

/// Whether [port] can be bound right now.
///
/// Binds the same way the server does - IPv6 any, which on a dual-stack host
/// also covers IPv4 - so this answers the question the server will ask, rather
/// than guessing from a process listing.
Future<bool> _isFree(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv6, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}

/// A ` by pid 123 (command)` suffix when the owner can be identified.
///
/// Best effort and POSIX only: it shells out to `lsof`, which is absent on
/// Windows and on some minimal Linux images. Returns null when unavailable, so
/// the port is still reported, just without the hint.
Future<String?> _describeOwner(int port) async {
  if (Platform.isWindows) return null;
  try {
    final lsof = await Process.run('lsof', [
      '-t',
      '-nP',
      '-iTCP:$port',
      '-sTCP:LISTEN',
    ]);
    final pid = (lsof.stdout as String).split('\n').first.trim();
    if (pid.isEmpty) return null;

    final ps = await Process.run('ps', ['-o', 'command=', '-p', pid]);
    final command = (ps.stdout as String).trim().split('\n').first;
    if (command.isEmpty) return ' by pid $pid';

    final short = command.length > 70
        ? '${command.substring(0, 70)}...'
        : command;
    return ' by pid $pid ($short)';
  } on ProcessException {
    return null;
  }
}
