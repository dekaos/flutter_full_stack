# The word hunt

The app opens on a game. It asks for a word in Portuguese, and the learner
finds it in English among little saucers flying through a 3D corner of space,
and shoots it. This page covers how it plays, where the words come from and
the rules they keep to, how the 3D is drawn without a 3D engine, and what to
know before changing any of it.

It started as a port of the web platform's *English-Portuguese Word Hunt*
(`WordHuntingPage.tsx`, Phaser), and kept its idea. Most of the rest was
redone: the controls, the words, the look, and the rules underneath.

## How it plays

| | |
|---|---|
| **Lobby** (`/`) | Fifteen themes in three levels, each card with the best stars and score made on it. Over a slowly turning low-poly planet |
| **Mission** (`/mission/:deck`) | Ten words from one theme, never the same one twice. Four ships to choose from at first, five from the fourth word, six from the eighth |
| **A shot** | Tap a ship, anywhere on it or its word. The rocket turns and fires; the laser lands a fifth of a second later, and only then is the shot judged |
| **The answer** | Explodes, scores, and its English word is read aloud by the device's voice |
| **A wrong ship** | Its shield takes the shot and it shows what its word means ("cat" / "gato"), so a mistake teaches something. It costs one of three shields, and cannot be shot again |
| **Time** | Fifteen seconds a word, shown as a draining bar. Running out shows the answer and moves on; it costs no shield |
| **Hints** | Three a mission. One lights the answer up, for half its points |
| **Score** | 100 a word, up to 50 more for speed, ×1.25 for each word found in a row (up to ×2) |
| **Stars** | Three for 9 or 10 words found, two for 7 or 8, one for 4 to 6 |
| **Results** | Stars, score, a new-record badge, and every word of the mission with its answer, each a tap from being heard. Play again, or pick another theme |

Pausing (the button, the system Back, or the app going to the background)
holds every clock. Back never leaves a mission by accident: it pauses, and the
pause panel has the way out.

Mobile first: everything is one thumb, tap targets are at least 48 px, and the
play area is whatever the panels leave — on a phone on its side, the prompt
moves to a side panel. With a screen reader on, the ships are also offered as a
row of buttons, since a ship flying across a canvas cannot be found by touch
exploration.

## What changed from the web version, and why

The web version had bugs a port would have copied. Each is fixed by design,
and the ones a test can hold are held:

| Web version | Here | Held by |
|---|---|---|
| For most of a second after a hit, the word just found could be shot again for the same points: the game saw no ship carrying the target and sent a new one before changing the target | A round takes one answer; a shot at a round that is over, or at a ship already missed, counts for nothing | `mission_controller_test.dart` |
| Labels overlapped, and were cut off at the edges of the screen | Each wave is laid out in disjoint cells sized to its widest word; ships roam inside their own | `space_world_test.dart`, on three screen shapes, in large text |
| Arrow keys and the space bar: unplayable on a phone | Tap to shoot | `mission_screen_test.dart` |
| The same word could be asked twice in a row | Ten different words per mission | `word_bank_test.dart` |
| The score carried on from mission to mission and dropped on a miss, saved to the server on every shot, and the leaderboard polled every two seconds | A score per mission; records kept on the device, written once per mission | `hunt_records_test.dart` |
| The 30-second timer only swapped the word, silently | A visible clock per word; running out shows the answer | `mission_controller_test.dart` |
| Assets fetched at runtime from a GitHub repository of Phaser examples | Nothing downloaded: every mesh and sound is made on the device | — |

There is no leaderboard yet. It needs accounts and an endpoint, which this app
does not have; the records are per device until it does.

## The words

They are in `lib/features/word_hunt/providers/word_bank.dart`, one enum value
per theme. The web version's list mixed rare and abstract words with basics,
repeated one, offered an insult as vocabulary, and paired words that have
several translations — so a learner who knew the language could be marked
wrong. Every word now keeps to these rules:

- **Concrete and frequent**: what a beginner meets in the first year (CEFR
  A1–A2).
- **One meaning, one answer.** A Portuguese word whose translation depends on
  context is left out, or kept only with every other reading absent from the
  whole bank: "mulher" is "woman", so "wife" is not in it; "dedo" is "finger",
  so "toe" is not either. No English word appears twice in the bank, and no
  prompt either.
- **Brazilian usage**: "tchau", not "adeus"; "ônibus", "celular", "geladeira".
- **Something to learn**: nothing spelled the same in both languages. Near
  look-alikes stay on purpose — "avó"/"avô", "manhã"/"amanhã",
  "biblioteca"/"livraria" — because they are where the learning is.
- **Decoys from the same theme**, so telling "Tuesday" from "Thursday" is the
  game, not spotting the only word that is not an animal.
- **American spelling** in the words ("gray", "pants"): the voice that reads
  them is en-US, as practice's is.

`word_bank_test.dart` checks what a machine can: enough words per theme, no
duplicates in either language, no identical spellings, a length that fits a
ship, dictionary casing, and that the web version's problem words stay out.
The semantic rules — one meaning, Brazilian usage — are checked by a person.

**To add a word**, add a `WordPair` to its theme and run the tests. **To add a
theme**, add an enum value with its level, then give it a name in both `.arb`
files and an icon and hue in `presentation/deck_look.dart`; the `switch`es
there are exhaustive, so the analyzer lists what is missing.

## The 3D

It is real 3D — a perspective camera, solids lit by one sun, depth — drawn on
an ordinary Flutter canvas, with no engine and no assets:

- **Meshes are made from numbers** (`space/models.dart`): the saucers and the
  rocket are profiles turned on a lathe, the planet and rocks are subdivided
  icosahedra pushed out by noise. Nothing to license, nothing in the bundle.
- **One renderer** (`space/renderer.dart`) turns, lights and projects every
  mesh of a frame, drops faces turned away, sorts the rest far to near (a
  counting sort, linear in the faces) and hands them to the canvas as one
  `drawVertices` call per layer. Each face is flat-shaded — sun, sky and
  ground light, a rim light, a highlight, fog — which is the low-poly look.
  About 2,000 faces a frame.
- **Glows are 2D, over the 3D**: engine flame, lasers, sparks, shields, the
  atmosphere — additive radial gradients at projected points. So are the
  words, which are always on top and always upright.
- **Every theme is a corner of space of its own**, from one hue
  (`space/palette.dart`): sky, nebulae, planet, light. The sky stays near
  black whatever the hue, because words are read over it.

**Why not Flame.** It was considered. Flame's 3D
(`flame_3d`) and `flutter_scene` both run on Flutter GPU, which is
experimental, Impeller-only and absent on the web — and the web is a build
target here. Flame's 2D engine would have brought a game loop and components,
which a `Ticker` and a `CustomPainter` already give, plus a dependency and
bundle size, and the 3D would still have had to be written. The app's
pronunciation scenes are drawn the same way, with `IsoStage`.

**Layout is on the screen, not in the world.** A ship has a place in pixels
and a depth, and is put into the world wherever that place falls at that depth.
That is what keeps every word inside the play area on any screen. Each wave is
given a grid of cells — as many across as gives the widest word the most room —
and each ship roams inside its own, so no word is ever over another. When even
the best grid is too small (six long phrases on a narrow phone in large text),
the words and ships of that wave are made just small enough to fit. The
camera's sway is budgeted into the field's margins, so a word never drifts
under a panel.

**The game decides nothing in the world.** `MissionController` owns every rule
and clock; `SpaceWorld` only shows what it is told (a wave, a hit, a miss) and
reports when a laser lands. The screen in between is a diff of two states.

## Sound and the voice

Four sounds were added to `Sound` — `laser`, `burst`, `bonk`, `warp` — made
the same way as the rest (see [sound.md](sound.md)), and the countdown,
hint and results reuse existing ones. All of it goes through `SoundBoard`, so
its rules hold: nothing is heard over the word being read aloud, and the app
bar's switch turns the sounds off. The word is read 450 ms after the hit, once
the explosion's sparkle has rung — the reading stops every sound.

## Records

`HuntRecords` keeps each theme's best score and best stars — separately, so a
high score earned with hints does not take away three stars won another day —
in one JSON file in the app's support folder. It fails quietly both ways: the
web build has no such folder and simply starts from nothing each time.

## Testing it

**Never `pumpAndSettle` while the word hunt is on screen.** Its space moves on
every frame, so it never settles: the test times out. Pump frames instead
(`frames` in `test/features/word_hunt/app_support.dart`), or go to the screen
you want first — a route covered by another has its tickers muted, so the
language chooser, opened over the lobby, settles as it always did. That is why
`router_test.dart`, `follow_the_device_test.dart`, the end-to-end suite and
the frame-timing suite now start by going to the chooser.

The mission screen tests open the real app with a seeded mission
(`missionRandomProvider`), fake speakers and voice, and records in memory, and
tap ships where they are drawn: `SpaceView.world` exposes the ships' label
rectangles.

The frame-timing suite does not measure the word hunt yet. A new summary
needs a baseline recorded on the CI emulator first (`--require-baseline` fails
on a screen without one), so it still measures the chooser and practice — and
since the chooser is now reached from the lobby rather than launched into, its
baseline may need recording again.
