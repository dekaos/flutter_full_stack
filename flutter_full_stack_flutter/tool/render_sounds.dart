// Writes every sound the app makes to WAV files, to listen to while tuning
// a recipe in lib/core/audio/sound.dart:
//
//     dart run tool/render_sounds.dart [directory]
//
// The app makes the same sounds on the device the first time it needs them;
// nothing here is shipped.

import 'dart:io';

import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/synth.dart';

void main(List<String> args) {
  final directory = Directory(args.isEmpty ? 'build/sounds' : args.first)
    ..createSync(recursive: true);
  for (final sound in Sound.values) {
    final samples = sound.render();
    // At the volume it is played at, so the files compare as they will
    // sound side by side.
    for (var i = 0; i < samples.length; i++) {
      samples[i] *= sound.volume;
    }
    File('${directory.path}/${sound.name}.wav').writeAsBytesSync(wav(samples));
  }
  stdout.writeln(
    'Wrote ${Sound.values.length} sounds to ${directory.absolute.path}',
  );
}
