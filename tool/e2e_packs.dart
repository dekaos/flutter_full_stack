// Writes a stand-in for every language pack the app names, for the
// end-to-end suite to download from a real server.
//
//     dart run tool/e2e_packs.dart [folder]     # default: build/e2e_packs
//     MODELS_DIR=$PWD/build/e2e_packs melos run server:start
//
// Why stand-ins: a real pack is 355 MB, exported by the scorer from weights
// that CI does not have. What the end-to-end suite protects is the path a
// pack takes - the request to the server's `/models`, the bytes streamed
// into a `.part`, the progress on the button, the rename once it is whole,
// the router letting practice open - and that path is the same for 8 MB of
// stand-in bytes as for the real thing. The one step they cannot pass is the
// SHA-256 check, so the suite gives its store a fingerprint that vouches for
// them (`ModelStore.fingerprint` exists for exactly this).
//
// The names come from the lexicons, so a model revision that renames its
// pack renames its stand-in too.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Big enough for the download to report progress more than once, small
/// enough to cross `adb reverse` in a second or two.
const int _bytes = 8 * 1024 * 1024;

Future<void> main(List<String> args) async {
  final repo = File.fromUri(Platform.script).parent.parent;
  final lexicons = Directory(
    '${repo.path}/flutter_full_stack_flutter/assets/lexicons',
  );
  final out = Directory(
    args.isNotEmpty ? args.first : '${repo.path}/build/e2e_packs',
  );
  await out.create(recursive: true);

  final names = <String>[
    for (final file in lexicons.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.json'),
    ))
      (jsonDecode(await file.readAsString()) as Map<String, dynamic>)['model']
          as String,
  ]..sort();
  if (names.isEmpty) {
    stderr.writeln('e2e_packs: no lexicons in ${lexicons.path}');
    exit(2);
  }

  // Seeded, so every run writes the same bytes: a stand-in that changed
  // between runs would make a resumed download join two different files.
  final random = Random(7);
  final bytes = Uint8List(_bytes);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  for (final name in names) {
    await File('${out.path}/$name').writeAsBytes(bytes, flush: true);
  }

  final folder = out.absolute.path;
  stdout
    ..writeln('e2e_packs: ${names.length} stand-ins in $folder')
    ..writeln('  ${names.join(', ')}')
    ..writeln('Serve them with: MODELS_DIR=$folder melos run server:start');
}
