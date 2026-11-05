# The word hunt

The app opens on a game. It asks for a word in Portuguese, and the learner
finds it in English among ships of every kind flying through a 3D corner of space,
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
| **A shot** | Tap a ship, anywhere on it or its word. The learner's fighter turns and fires from one cannon, then the other; the laser lands a fifth of a second later, and only then is the shot judged |
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

It is real 3D — a perspective camera, lit solids, depth — drawn on an
ordinary Flutter canvas, with no engine and no assets:

- **Meshes are made from numbers** (`space/models.dart`): hulls, nacelles
  and domes are profiles turned on a lathe, wings and fins are slabs, cargo
  is boxes, and the planet, moon and rocks are subdivided icosahedra pushed
  out by noise. Nothing to license, nothing in the bundle.
- **The learner flies a working spacecraft**, not a toy rocket: a panelled,
  faceted hull, a framed glass canopy, twin engines on pylons, short swept
  wings with navigation lights (red to port, green to starboard), radiator
  fins and two laser cannons under the nose that fire in turn. It is in a
  utilitarian, hard science-fiction spirit - the look of a craft built to
  be used - but an original design: no ship, name, logo or livery is taken
  from any game. It is in CNA's white and red over graphite.
- **The words fly on six kinds of ship** (`ShipStyle`): a saucer, a scout
  drone with one glowing eye, a swept-wing interceptor, a cargo hauler, a
  ray, and a probe on solar panels. Each wave gives every ship a different
  kind, in a random order, in its own colour. The saucer turns about itself;
  the others face where they fly, turning towards the side they are going.
  Their engines, eyes and lamps glow - only when turned towards the viewer,
  since a light behind its ship is hidden by it. Their colours are chosen
  when they are drawn (`Swatch`), so six meshes serve every colour.
- **Shading is smooth** (`space/mesh.dart`). Each corner has its own normal,
  colour and finish, and the GPU blends the three corners' light across
  each triangle, so a curve looks curved rather than cut from facets. A mesh
  is built in parts — a hull, a dome, a fin — each smoothed within itself up
  to a crease angle and kept sharp against the others, which is how a
  saucer's rim stays a crisp edge between two smooth shells, and a
  hauler's containers stay boxes. A planet's
  colours are per corner too, so its coasts fade from sea to land.
  `mesh_test.dart` holds this.
- **Materials** (`Finish`): glossy paint, chrome, glass, water, rock. Light
  is worked out per corner in linear light — the sun, the sky above and the
  dark below, a highlight shaped by the finish, the surroundings reflected
  in metal and glass, a fresnel sheen at grazing angles, an atmosphere round
  the planet's edge — then tone mapped (ACES) and encoded for the screen.
  Adding colours in screen values, as the first version did, washes
  everything out.
- **One renderer** (`space/renderer.dart`) turns, lights and projects every
  mesh of a frame, drops faces turned away or off the screen (and lights
  only the corners of faces it keeps), sorts the rest far to near and hands
  them to the canvas as one `drawVertices` call per layer. The sort is
  exact, and paints each solid whole — a ship, the fighter, a splinter — in
  front of or behind the next; only the planet and its rings, which go round
  each other, are sorted face by face. It used to be a bucket sort over the
  frame's depths, which made faces a hair apart (a fin and the craft's
  body, a dome and its hull) swap places from frame to frame whenever ships
  flew far off — that is, every time the words changed — and flicker.
  `renderer_test.dart` holds it.
- **The sky is painted once per theme** (`space/nebula.dart`): clouds of gas
  folded over themselves by domain-warped noise, dark lanes of dust, a faint
  galactic band — 192 pixels square, made on another isolate the first time
  a theme's space asks for it, and drawn scaled up, since it is soft by
  nature. Until it is ready, a plainer gradient sky stands in.
- **Each solid is seen through its own lens** (`Camera.lensAt`). The
  camera's field of view is set across the shorter side, so an upright
  phone sees about 104° top to bottom — a wide angle, which stretches what
  is off to the side as a wide-angle photo does: a planet in a corner came
  out half as long again one way as the other, and the craft at the bottom
  stood tall. So each solid is projected as if the camera had turned to face
  it squarely, then placed where the camera puts its middle, at the size it
  gives it there. Depth, light and which side is seen are unchanged; only
  the stretch is gone. `renderer_test.dart` holds a ball in a corner round.
- **Glows are 2D, over the 3D**: the engine's flame, lasers, sparks,
  shields — additive radial gradients at projected points, each through the
  lens of the solid it belongs to, so a flame stays on its nozzle. So are the
  words, which are always on top and always upright.
- **Every theme is a corner of space of its own**, from one hue
  (`space/palette.dart`): sky, nebula, planet, light. The sky stays dark
  whatever the hue, because words are read over it.

About 6,200 faces a frame — the fighter and the planet are the heaviest —
for roughly 1.6 times the work of the faceted first version, which drew
2,400. Measured in a JIT test run on a laptop, so only the ratio means
anything; the frame-timing suite does not cover the word hunt yet.

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
under a panel. When the field changes under a wave — a phone turned — every
ship keeps its cell and its place in it; and the prompt card above keeps one
height whatever it shows, so it never moves the field as the words change.

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
