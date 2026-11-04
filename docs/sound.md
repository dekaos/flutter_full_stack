# Sound

Practice is heard as well as seen: the scenes and the hiding cat make a few
soft sounds as they move, an attempt's score is answered with a chime, and the
sentence can be listened to before it is said. So is the language chooser:
each language's place is heard as its page comes into view. This page covers what plays,
the rules about when, and how to change any of it.

## What plays

| What | When | Where it is defined |
|---|---|---|
| A scene's sounds | As its story is told, each on its beat: the clock tower's bell on each stroke, a cup as it lands on its saucer, a robin as each one lands. Nothing once the scene is at rest | `SceneScript.sounds`, in each `*_scene.dart`, on the same constants its drawing keeps time by |
| The chooser's places | When a language's page comes into view, its place arrives and is heard once its story is told: a Broadway brass fanfare as the firework from the Statue of Liberty's torch bursts into a heart over New York, a flamenco guitar as a dancer strikes her pose in Seville's Plaza de España, a Korean temple bell. Only the page in view is heard, so a page only peeked at in a swipe stays silent. Brought back into view, a place tells its story again | `SceneSound` in `new_york_scene.dart`, `seville_scene.dart` and `temple_bell_scene.dart`; `CountryScene.heard` |
| The cat's sounds | During a visit: a meow as it starts to wash (the washing itself is silent, as a cat's is); a soft closed-mouthed "mrrm" through the slow blink; a trill as it hops | `CatGesture.sounds` in `cat.dart`, timed through a visit by `CatPose.at` |
| The score's chime | When an attempt is scored, in its `ScoreBand`: brighter the better, and never a buzzer | `chimeFor` in `practice_screen.dart` |
| The sentence, read aloud | When the learner taps the listen button beside the record button, or a word of the sentence once it is scored. The sentence lights up word by word as it is read, following the engine's progress (`PhraseVoice.spoken`: iOS `willSpeakRange`, Android `onRangeStart`) | `PracticeController.listen` and `hear`, `PlatformPhraseVoice` |
| The learner's own attempt | When they tap its voice message, or the "as you said it" button beside a word's hint. That plays just the word, with 80 ms either side | `PracticeController.replay`, `SoundBoard.replay`, `excerpt` in `synth.dart` |

The sounds are **made on the device, not recorded**. Each one is a short recipe
in `lib/core/audio/sound.dart`, built from the tones, noise, filters and
envelopes in `synth.dart`. So there is no audio file to license, nothing in the
APK, and a sound is changed by editing its recipe. They are written as WAV files to the temporary directory, because a file is
what every platform's player can open. The whole set is about 1 MB.

**When the sound gets ready.** Getting it ready means rendering the sounds
(about 120 ms of CPU on a laptop, most of a second on a modest phone), setting
up the native players and asking the speech engine for its voices. That once
ran as practice opened, competed with the first scene's arrival, and made it
stutter. Now:

- `SoundBoard.warm` does all of it on the language screen, once that screen
  has risen in, while the learner reads the choices. The rendering runs on
  another isolate.
- The practice screen calls it too, but only after its first scene has
  arrived. That covers arriving straight at practice.
- A sound cued before the board is ready is dropped, not played late: the
  sounds are tied to moments, and a late one is worse than none.

The sentence is read by the platform's own text to speech (`flutter_tts`):
AVSpeechSynthesizer on iOS, the system engine on Android. It works offline,
like the rest of practice. It reads only in the accent the language's phonemes
are scored against, which is the espeak-ng voice in
[pronunciation-models.md](pronunciation-models.md):

| Language | Locales, best first |
|---|---|
| English | `en-US` |
| Spanish | `es-MX`, `es-US`, `es-419`. Never `es-ES`, which reads "cerveza" with a /θ/ the lexicon marks wrong |
| Korean | `ko-KR` |

Among the voices on the device in that accent, the best is chosen: premium or
enhanced on iOS, very high on Android. Voices that need a network connection
are skipped. If there is no voice in the right accent, the listen button is not
shown. A reading in the wrong accent would teach exactly what the score marks
as an error.

## The rules

All of them live in `SoundBoard` (`lib/core/audio/sound_board.dart`). Anything
that makes a sound goes through it.

1. **Nothing plays while the microphone is open.** A sound in the recording
   ends up in the score. `PracticeController` calls `SoundBoard.hush()` and
   waits for silence *before* `recorder.start()`. Every way the microphone
   closes gives the speakers back: scored, swiped away, failed to start, or
   the screen left. This includes the reading. `practice_controller_test.dart`
   checks the board is silent at the moment the recorder starts.
2. **The lesson is never talked over.** The reading and the playback of the
   learner's attempt each stop every sound, and any sound cued while either
   plays is dropped. The two also stop each other. A request overtaken while
   it starts gives way to the later one instead of starting on top of it.
   The attempt is played back as it was recorded, only brought up to a clear
   level (at most 8 times) and eased in and out so a word cut from the middle
   does not click.
3. **The sounds can be turned off** from the app bar (`SoundEffects`, shown
   by `AppBarActions.sounds`). The
   reading cannot: the learner asks for it, and it is part of the lesson. Like
   the theme and the language, the setting is not persisted.
4. **Under reduced motion nothing is heard but the score and the reading.**
   The scene's story, the places' stories and the cat's visit are not
   played, so their sounds are not either.

## Levels

Every sound is made equally loud: its loudest 50 ms at -18 dBFS, unless that
would clip. `Sound.volume` alone then sets the balance. The values were set by
measuring each sound with A-weighting and a phone-speaker roll-off below
350 Hz, not by eye:

- score chimes: about -21 to -25 dB;
- the cat: about -25 to -30 dB;
- the scenes and the places: about -27 to -30 dB;
- the breeze: softer still, about -32 dB.

Noise is the hardest thing to make sound gentle on a phone. White noise
filtered into a band still hisses at its edges, and a phone barely plays the
low rumble that would cover that hiss.

- **The breeze is the one sound still made of noise.** It uses `softNoise`,
  which falls away 6 dB an octave and has no hiss to begin with, and it is
  kept under 1 kHz.
- **The wave is told in notes, with no noise at all.** It is a soft harp run
  up a pentatonic scale into the break, a few drops, and the run falling back
  down. Two noise versions were tried, and both still read as wind on a
  phone.

Prefer notes to noise for anything new.

- **The meow is a throat, not an instrument.** A stack of sines in step,
  with a regular vibrato, sounds like an organ or a singer. The meow is a
  source and a filter, as speech synthesis does it: `_glottis` makes the
  puffs of air through the vocal folds, with the small irregularity of a
  living voice in their pitch and loudness (`_wobble`) and breath through
  them; resonances of a small mouth, higher than a person's, then move with
  the "m-i-a-ow" - a hum through the nose, wide open, rounding to close.
  The pitch arches over 450-780 Hz, a domestic cat's range.
- **The fanfare is brass, built from harmonics.** Each note is a trumpet's
  stack of ten harmonics through a filter that opens as it is blown - the
  "blat" that makes brass sound like brass - with vibrato on the held chord.
  Two notes lead in, then a major chord with its sixth, the big band's sound,
  spread over a section's worth of voices a hair apart. It starts 550 ms
  ahead of its cue (`Sound.hit`), so the chord lands as the heart opens.
- **The guitar is plucked strings.** `string` in `synth.dart` is
  Karplus-Strong: a burst of noise going round a loop one period long, each
  time round a little softer and duller, as a string is. The noise is only
  the pluck; what is heard is a note.
- **The temple bell is pitched up.** A real one hums far below what a phone
  can play, so its hum is at 196 Hz and its upper partials are loud enough
  to carry it. The slow pulse a Korean bell is known for comes from pairs of
  partials a fraction of a hertz apart.

All of them sit well below a reading, which plays at full volume.

## The audio session, per platform

**iOS has one `AVAudioSession` for the whole app, and three users of it.**
Each one sets it to suit itself, and iOS keeps whatever was set last:

| Who | Category | Why |
|---|---|---|
| Sounds (`PlatformSoundOutput`) | `ambient` | mixes with the learner's music, and the silent switch silences it, as it should a decoration |
| Reading (`PlatformPhraseVoice`) | `playback`, ducking others | heard with the switch on silent: the learner asked for it, as they would press play on a video |
| Microphone (`record`) | `playAndRecord`, default to speaker | set when recording starts, and left that way when it stops |

So **each one sets its category again every time it plays**. A sound played
after a recording would otherwise play in `playAndRecord` and ignore the silent
switch.

audioplayers also deactivates the session whenever none of its players is
playing. That is harmless only because rule 1 stops every player *before* the
recorder activates the session again.

**Android** has no shared category. Sounds play as a game's effects, at the
media volume, without taking audio focus, so the learner's music carries on.
Android 11+ hides the text-to-speech engine from apps that do not declare they
look for one. The `TTS_SERVICE` entry under `<queries>` in `AndroidManifest.xml`
is what lets a voice be found at all.

`flutter_tts` has no Swift Package, only a podspec. That was accepted because
`ios/` is on CocoaPods for `record` already (see AGENTS.md). audioplayers does
ship one.

## Changing or adding a sound

1. Edit or add the recipe in `sound.dart`. A new `Sound` needs a `volume`, and
   a `hit` if what it marks comes after its start, like a wave's break after
   its swell.
2. Listen to it: `dart run tool/render_sounds.dart build/sounds` writes every
   sound at its playing volume.
3. Re-measure it against the others before choosing its `volume` (see
   [Levels](#levels)).
4. Cue it on a beat: in a scene's `sounds:` with the constant its drawing uses,
   or in `CatGesture.sounds`. Never cue it on a time of its own.

`sound_test.dart` holds every sound to these limits:

- short;
- never clipping;
- silent at both ends;
- made at the shared level;
- the same every time it is made.

`scene_script_test.dart` holds every scene's sounds inside act two and in order.
`prompt_scene_test.dart` and `hiding_cat_test.dart` check each one is heard
once, on its moment. `country_scene_test.dart` does both for the chooser's
places, and `language_screen_test.dart` checks each is heard as its page
comes into view.
