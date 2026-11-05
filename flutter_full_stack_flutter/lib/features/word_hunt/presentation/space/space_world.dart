import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/models.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/nebula.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/palette.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/renderer.dart';

/// A word to fly: what is on the ship, and what it means.
typedef ShipWord = ({String label, String meaning});

/// One word ship, as the world flies and draws it.
class WordShip {
  WordShip._({
    required this.index,
    required this.label,
    required this.meaning,
    required this.variant,
    required this.position,
    required this.depth,
    required this.delay,
    required this.phase,
    required this.spin,
    required this.style,
    required this.facing,
  }) : destination = position,
       depthGoal = depth,
       heading = math.pi + facing;

  /// Its place among the round's choices.
  final int index;

  /// The English word on it.
  final String label;

  /// What [label] means, in Portuguese: shown once it has been shot wrongly,
  /// or when time runs out on it as the answer.
  final String meaning;

  /// Which of [ShipColours] it is painted in.
  final int variant;

  /// What kind of ship it is.
  final ShipStyle style;

  /// Which way it faces, for a style that faces where it flies: turned a
  /// little from the viewer by [facing] at rest, and round towards wherever
  /// it is going.
  double heading;
  final double facing;

  /// The part of the field it flies in. A wave's cells never overlap, and
  /// each is big enough for its ship's word, so no word is ever over
  /// another.
  Rect cell = Rect.zero;

  /// Which of the wave's cells [cell] is, counted along the rows: kept when
  /// the field changes, so the ship keeps its place in it.
  int slot = -1;

  /// Where its hull is, in pixels, as the still camera sees it.
  Offset position;
  Offset destination;
  Offset velocity = Offset.zero;

  /// How far ahead of the camera it flies, in units of the world.
  double depth;
  double depthGoal;

  /// Seconds before it starts to arrive: a wave comes in one ship after
  /// another, not all at once.
  double delay;

  /// `0` to `1` as it arrives from far off.
  double arrival = 0;

  /// `-1` while it stays; `0` to `1` as it leaves.
  double leaving = -1;

  /// Seconds before it leaves, once it has been told to: the ships that
  /// were not the answer stay a moment to watch the one that was explode.
  double lingering = 0;

  bool missed = false;
  bool hinted = false;
  bool revealed = false;
  bool exploded = false;

  /// A laser is on its way to it.
  bool targeted = false;

  /// The red of a shield taking a shot, `1` fading to `0`.
  double flash = 0;

  /// The shake of being knocked back, `1` fading to `0`.
  double wobble = 0;

  double bank = 0;
  double yaw = 0;
  final double phase;
  final double spin;
  double _retarget = 0;

  /// Where the world has it, for lasers to fly to - once [placed].
  V3 world = V3.zero;

  /// Whether [world] has been worked out yet. Until it has, the ship is
  /// not drawn: its [world] is the origin, which is the camera itself, and
  /// a ship drawn there fills the screen for a frame. (That was the pale
  /// flash as a wave flew in: each ship after the first, on the frame its
  /// wait ran out, before it had been given a place.)
  bool placed = false;

  /// Whether it is drawn: placed, in flight, and not blown up.
  bool get shown => placed && delay <= 0 && !exploded;

  /// Where the last frame drew its label and hull, for picking.
  Rect? labelRect;
  Offset? hull;
  double hullRadius = 0;

  /// Whether a tap on it fires.
  bool get shootable =>
      !missed &&
      !exploded &&
      !targeted &&
      leaving < 0 &&
      lingering <= 0 &&
      delay <= 0 &&
      arrival > _shown;

  bool get gone => exploded || leaving >= 1;
}

/// How far a ship has arrived when its word appears, and it can be shot:
/// close enough to its place that the word pops in where it will stay.
const _shown = 0.8;

class _Laser {
  _Laser(this.cannon, this.ship, this.round);

  /// Which of the fighter's cannons fired it.
  final int cannon;
  final WordShip ship;
  final int round;
  double progress = 0;
}

class _Shard {
  _Shard({
    required this.at,
    required this.velocity,
    required this.variant,
    required this.size,
    required this.life,
    required this.spin,
  });
  V3 at;
  V3 velocity;
  final int variant;
  final double size;
  final double life;
  final V3 spin;
  double age = 0;
}

class _Spark {
  _Spark({
    required this.at,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    this.drag = 2.2,
    this.about,
    this.exhaust = false,
  });

  /// The middle of the solid it flew from, whose lens it is seen through -
  /// so a ship's sparks burst from the ship as it is drawn.
  final V3? about;

  /// From the fighter's engines, and seen through the fighter's lens.
  final bool exhaust;
  V3 at;
  V3 velocity;
  final Color color;
  final double size;
  final double life;
  final double drag;
  double age = 0;
  Offset? last;
}

class _Burst {
  _Burst(this.at, this.color, {this.life = 0.6, this.reach = 2.4});
  final V3 at;
  final Color color;
  final double life;
  final double reach;
  double age = 0;
}

class _Popup {
  _Popup(this.at, this.text);
  final V3 at;
  final String text;
  double age = 0;
}

class _Rock {
  _Rock({
    required this.at,
    required this.drift,
    required this.size,
    required this.seed,
    required this.spin,
  });
  V3 at;
  final V3 drift;
  final double size;
  final int seed;
  final V3 spin;
}

/// The word hunt's space: the ships with words on them, the learner's
/// fighter and its lasers, explosions, and the sky it all happens in -
/// simulated a frame at a time, and drawn in 3D.
///
/// It decides nothing about the game. The screen tells it what the mission
/// did - a wave to fly in ([launch]), a ship that was the answer ([hit]),
/// one that was not ([miss]) - and it shows it; and it tells the screen
/// when a laser lands ([onImpact]), so the mission can decide what that
/// shot was worth.
///
/// Ships are laid out on the *screen*, not in the world: each has a place
/// in pixels and a depth, and is put into the world wherever that place
/// falls at that depth. That is what keeps every label inside the play
/// area on any screen - upright phone, tablet or browser window - and keeps
/// labels from covering one another; the web version let ships drift
/// anywhere, so words sat on top of each other and were cut off at the
/// edges. The camera itself sways, so the 3D is real: nearer ships move more,
/// and everything is lit from one sun.
class SpaceWorld extends ChangeNotifier {
  SpaceWorld({SpacePalette? palette, int seed = 7, this.ambient = false})
    : palette = palette ?? SpacePalette.lobby,
      _random = math.Random(seed) {
    _seedStars();
    _seedRocks();
    if (ambient) _seedTraffic();
  }

  /// The lobby's world: no fighter and no words, just traffic going by.
  final bool ambient;

  SpacePalette palette;
  final math.Random _random;

  /// Told when a laser reaches a ship: the round it was fired in, and the
  /// ship's index in it.
  void Function(int round, int index)? onImpact;

  /// Seconds of world time so far.
  double time = 0;

  /// The device asks for reduced motion: the camera holds still, the stars
  /// stay where they are, and the ships hover rather than roam.
  bool still = false;

  /// How lively the ships are, `0` (the first word) to `1` (the last).
  double pace = 0;

  /// The round the ships on screen belong to.
  int round = 0;

  final List<WordShip> ships = [];
  final List<WordShip> _traffic = [];
  final List<_Laser> _lasers = [];
  final List<_Shard> _shards = [];
  final List<_Spark> _sparks = [];
  final List<_Burst> _bursts = [];
  final List<_Popup> _popups = [];
  final List<_Rock> _rocks = [];

  double _warp = 0;
  double _shake = 0;
  double _alarm = 0;
  double _glee = 0;
  double _muzzle = 0;

  /// Which cannon fires next, and which fired last.
  int _cannon = 0;
  double _aimYaw = 0;
  double _aimPitch = 0.08;
  double _sinceShot = 10;
  V3? _aimAt;
  double _exhaust = 0;

  Size size = Size.zero;
  EdgeInsets clear = EdgeInsets.zero;
  Camera? _base;
  Rect _field = Rect.zero;

  final Renderer _renderer = Renderer();

  /// Faces drawn in the last frame, across both batches: for tests and for
  /// keeping an eye on the budget.
  int facesDrawn = 0;

  /// Where the last frame drew the planet and its moon - the middle and
  /// the radius, in pixels - for tests; the moon's is `null` when there was
  /// none.
  @visibleForTesting
  (Offset, double)? planetOnScreen;
  @visibleForTesting
  (Offset, double)? moonOnScreen;

  // ------------------------------------------------------------- layout --

  /// Where the ships may be: the canvas less what the screen covers.
  Rect get field => _field;

  /// Sizes the world to [size], with [clear] of each edge covered by the
  /// screen's own panels - the ships keep out from under them.
  void layout(Size size, EdgeInsets clear) {
    if (size == this.size && clear == this.clear) return;
    final before = _field;
    this.size = size;
    this.clear = clear;
    final base = _base = Camera(
      eye: V3.zero,
      rotation: Rot.euler(pitch: -0.1),
      size: size,
    );
    // The camera sways, and carries the nearest ships furthest: the field
    // keeps that far in from what the screen covers, so a word never
    // drifts under a panel.
    final swayX = base.focal * (_swayYaw + _swayX / _nearest);
    final swayY = base.focal * (_swayPitch + _swayY / _nearest);
    _field = Rect.fromLTRB(
      clear.left + 8 + swayX,
      clear.top + 6 + swayY,
      math.max(clear.left + 9 + swayX, size.width - clear.right - 8 - swayX),
      math.max(clear.top + 7 + swayY, size.height - clear.bottom - 6 - swayY),
    );
    // The panels above changed, or the phone turned: every ship keeps its
    // cell, and its place in it, wherever the cell now is. Dealing the cells
    // out again would send each ship somewhere else at once.
    if (!before.isEmpty && ships.isNotEmpty) {
      final was = {for (final ship in ships) ship: ship.cell};
      _arrange(_crew, deal: false);
      for (final ship in ships) {
        final from = was[ship]!;
        final to = ship.cell;
        Offset move(Offset p) => from.isEmpty || to.isEmpty
            ? Offset(
                _field.left +
                    (p.dx - before.left) / before.width * _field.width,
                _field.top +
                    (p.dy - before.top) / before.height * _field.height,
              )
            : Offset(
                to.left + (p.dx - from.left) / from.width * to.width,
                to.top + (p.dy - from.top) / from.height * to.height,
              );
        ship
          ..position = _inside(ship, move(ship.position))
          ..destination = _inside(ship, move(ship.destination));
      }
    }
  }

  /// How far the camera sways: across and up, in units of the world, and
  /// turning, in radians.
  static const _swayX = 0.08;
  static const _swayY = 0.04;
  static const _swayYaw = 0.006;
  static const _swayPitch = 0.004;

  /// The ships of the wave still flying: not gone, not on their way out.
  List<WordShip> get _crew => [
    for (final ship in ships)
      if (!ship.exploded && ship.leaving < 0) ship,
  ];

  /// How much a crowded wave's words and ships are made smaller to fit:
  /// `1` when they fit as they are, which is nearly always.
  double _fit = 1;

  static const _gap = 10.0;

  /// The wave's grid: cells across and down.
  int _across = 1;
  int _down = 1;

  /// Shares the field out among [crew]: a grid of cells, as many across as
  /// gives each the most room for the widest word among them, handed out
  /// in a random order so a wave does not line up the same way twice.
  /// When even the best grid is too small - six long phrases on a narrow
  /// phone, in large text - everything is made just small enough to fit.
  ///
  /// With [deal] off, as when the field changes under a wave, the grid and
  /// who has which cell stay as they were; only the cells' size, and how
  /// small things must be to fit them, follow the field.
  void _arrange(List<WordShip> crew, {bool deal = true}) {
    if (crew.isEmpty || _field.isEmpty) return;
    _fit = 1;
    var width = 0.0;
    var height = 0.0;
    for (final ship in crew) {
      final box = _footprint(ship, Offset.zero, _nearest);
      width = math.max(width, box.width);
      height = math.max(height, box.height);
    }
    double room(int across, int down) => math.min(
      _field.width / across / (width + _gap),
      _field.height / down / (height + _gap),
    );
    final slots = _across * _down;
    final keep =
        !deal &&
        slots >= crew.length &&
        crew.every((ship) => ship.slot >= 0 && ship.slot < slots);
    if (!keep) {
      var best = 0.0;
      for (var cols = 1; cols <= crew.length; cols++) {
        final rows = (crew.length / cols).ceil();
        if (room(cols, rows) > best) {
          best = room(cols, rows);
          _across = cols;
          _down = rows;
        }
      }
      final order = [for (var i = 0; i < _across * _down; i++) i]
        ..shuffle(_random);
      for (final (i, ship) in crew.indexed) {
        ship.slot = order[i];
      }
    }
    _fit = math.min(1, room(_across, _down) * 0.97);
    final cellWidth = _field.width / _across;
    final cellHeight = _field.height / _down;
    for (final ship in crew) {
      ship.cell = Rect.fromLTWH(
        _field.left + ship.slot % _across * cellWidth,
        _field.top + ship.slot ~/ _across * cellHeight,
        cellWidth,
        cellHeight,
      ).deflate(_gap / 2);
    }
  }

  /// A depth for a ship, [t] of the way from the nearest to the furthest -
  /// further for a crowded wave, which is how its ships are made smaller.
  double _depthAt(double t) => (_nearest + (_furthest - _nearest) * t) / _fit;

  // ------------------------------------------------------------ labels --

  TextStyle _labelStyle = const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  TextScaler _textScaler = TextScaler.noScaling;
  final Map<String, TextPainter> _texts = {};

  /// What the words on the ships are set in.
  void typeset(TextStyle style, TextScaler scaler) {
    if (style == _labelStyle && scaler == _textScaler) return;
    _labelStyle = style;
    _textScaler = scaler;
    _forgetTexts();
  }

  void _forgetTexts() {
    for (final painter in _texts.values) {
      painter.dispose();
    }
    _texts.clear();
  }

  TextPainter _text(
    String text, {
    Color color = const Color(0xFFFFFFFF),
    double size = 1,
    FontWeight weight = FontWeight.w700,
  }) => _texts.putIfAbsent(
    '$text|${color.toARGB32()}|$size|${weight.value}',
    () => TextPainter(
      text: TextSpan(
        text: text,
        style: _labelStyle.copyWith(
          color: color,
          fontSize: (_labelStyle.fontSize ?? 17) * size,
          fontWeight: weight,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: _textScaler,
      maxLines: 1,
    )..layout(),
  );

  static const _labelPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 7,
  );

  Size _labelSize(WordShip ship) {
    final text = _text(ship.label);
    return Size(
      text.width + _labelPadding.horizontal,
      text.height + _labelPadding.vertical,
    );
  }

  /// How big a ship's word is drawn at [depth]: a little bigger near, a
  /// little smaller far, and smaller still in a crowded wave.
  double _labelScale(double depth) =>
      (1.08 - (depth * _fit - _nearest) * 0.05).clamp(0.86, 1.08) * _fit;

  /// How a ship's label and hull sit around its place, in pixels: the box
  /// that must stay inside its cell.
  Rect _footprint(WordShip ship, Offset at, double depth) {
    final hull = _shipRadius(depth);
    final label = _labelSize(ship) * _labelScale(depth);
    final width = math.max(label.width, hull * 2.2);
    final top = at.dy - hull * 0.95 - 8 - label.height;
    return Rect.fromLTRB(
      at.dx - width / 2,
      top,
      at.dx + width / 2,
      at.dy + hull * 0.6,
    );
  }

  static const _shipScale = 0.86;
  static const _nearest = 6.2;
  static const _furthest = 9;

  double _shipRadius(double depth) =>
      0.96 * _shipScale * (_base?.scaleAt(depth) ?? 30);

  // ----------------------------------------------------------- commands --

  /// Flies in the ships of round [round], one per word, in that order -
  /// sending off whatever was there before.
  void launch(int round, List<ShipWord> words, {double pace = 0}) {
    depart();
    this.round = round;
    this.pace = pace.clamp(0.0, 1.0);
    _warp = 1;
    final wave = <WordShip>[];
    // A mix of kinds in every wave, never two of one until each has flown.
    final styles = [...ShipStyle.values]..shuffle(_random);
    for (final (i, word) in words.indexed) {
      final ship = WordShip._(
        index: i,
        label: word.label,
        meaning: word.meaning,
        variant: (round * 2 + i) % ShipColours.count,
        position: _field.center,
        depth: _nearest,
        delay: i * 0.09,
        phase: _random.nextDouble() * math.pi * 2,
        spin: (0.5 + _random.nextDouble() * 0.7) * (i.isEven ? 1 : -1),
        style: styles[i % styles.length],
        facing: (_random.nextDouble() - 0.5) * 1.1,
      );
      wave.add(ship);
    }
    _arrange(wave);
    for (final ship in wave) {
      ship
        ..depth = _depthAt(_random.nextDouble() * 0.9)
        ..depthGoal = ship.depth
        ..position = _spotFor(ship)
        ..destination = ship.position
        .._retarget = 2 + _random.nextDouble() * 3;
    }
    ships.addAll(wave);
  }

  /// Sends every ship still here on its way.
  void depart() {
    for (final ship in ships) {
      if (ship.leaving < 0 && !ship.exploded) ship.leaving = 0;
      ship.targeted = false;
    }
    _lasers.clear();
  }

  WordShip? _ship(int index) {
    for (final ship in ships) {
      if (ship.index == index && !ship.gone && ship.leaving < 0) return ship;
    }
    return null;
  }

  /// Fires at ship [index], if it can be shot. Returns whether a laser left.
  bool fire(int index) {
    final ship = _ship(index);
    if (ship == null || !ship.shootable || ambient) return false;
    ship.targeted = true;
    _cannon = (_cannon + 1) % Models.muzzles.length;
    _lasers.add(_Laser(_cannon, ship, round));
    _aimAt = ship.world;
    _sinceShot = 0;
    _muzzle = 1;
    return true;
  }

  /// Ship [index] was the answer: it explodes, worth [points].
  void hit(int index, int points) {
    final ship = _ship(index);
    if (ship == null) return;
    ship.exploded = true;
    final at = ship.world;
    for (var i = 0; i < 26; i++) {
      _shards.add(
        _Shard(
          at: at,
          velocity: _scatter(2.2 + _random.nextDouble() * 3.4),
          variant: ship.variant,
          size: 0.08 + _random.nextDouble() * 0.12,
          life: 0.8 + _random.nextDouble() * 0.6,
          spin: _scatter(4 + _random.nextDouble() * 8),
        ),
      );
    }
    final colours = [
      ShipColours.lights[ship.variant].color,
      const Color(0xFFFFD166),
      const Color(0xFFFFFFFF),
      palette.glow,
    ];
    for (var i = 0; i < 54; i++) {
      _sparks.add(
        _Spark(
          at: at,
          about: at,
          velocity: _scatter(1.5 + _random.nextDouble() * 6.5),
          color: colours[i % colours.length],
          size: 1.6 + _random.nextDouble() * 2.6,
          life: 0.45 + _random.nextDouble() * 0.7,
        ),
      );
    }
    _bursts
      ..add(_Burst(at, const Color(0xFFFFF4D6), life: 0.32, reach: 3.6))
      ..add(_Burst(at, const Color(0xFFFFD166), reach: 2.8))
      ..add(_Burst(at, palette.glow, life: 0.75, reach: 2));
    _popups.add(_Popup(at, '+$points'));
    _shake = math.max(_shake, 0.5);
    _glee = 1;
    // The rest have nothing left to do here.
    for (final other in ships) {
      if (!other.exploded && other.leaving < 0) other.lingering = 0.35;
    }
  }

  /// Ship [index] was not the answer: its shield takes the shot, it is
  /// knocked back, and it shows what its word means.
  void miss(int index) {
    final ship = _ship(index);
    if (ship == null) return;
    ship
      ..missed = true
      ..flash = 1
      ..wobble = 1
      ..velocity = ship.velocity + Offset(0, -60 * _fieldScale)
      ..depthGoal = math.min(ship.depthGoal + 1.4, _depthAt(1) + 1.5);
    for (var i = 0; i < 16; i++) {
      _sparks.add(
        _Spark(
          at: ship.world,
          about: ship.world,
          velocity: _scatter(1 + _random.nextDouble() * 2.5),
          color: const Color(0xFFFF6B81),
          size: 1.4 + _random.nextDouble() * 1.6,
          life: 0.35 + _random.nextDouble() * 0.3,
        ),
      );
    }
    _shake = math.max(_shake, 0.35);
    _alarm = 1;
  }

  /// Time ran out on ship [index], the answer: it shows what it means, and
  /// the rest leave.
  void reveal(int index) {
    final ship = _ship(index);
    if (ship == null) return;
    ship.revealed = true;
    for (final other in ships) {
      if (other != ship && other.leaving < 0) other.leaving = 0;
    }
  }

  /// A hint: ship [index] glows until the round is over.
  void hint(int index) => _ship(index)?.hinted = true;

  /// Which ship is under [point], if any can be shot: the nearest, when
  /// they overlap. Generous - a finger is not a cursor.
  int? pick(Offset point) {
    WordShip? best;
    var bestScore = double.infinity;
    for (final ship in ships) {
      if (!ship.shootable) continue;
      final label = ship.labelRect;
      final hull = ship.hull;
      if (label == null || hull == null) continue;
      final reach = math.max(ship.hullRadius * 1.25, 26);
      final onLabel = _atLeast(label, 48).contains(point);
      final onHull = (point - hull).distance <= reach;
      if (!onLabel && !onHull) continue;
      final score = ship.depth;
      if (score < bestScore) {
        bestScore = score;
        best = ship;
      }
    }
    return best?.index;
  }

  static Rect _atLeast(Rect r, double side) => Rect.fromCenter(
    center: r.center,
    width: math.max(r.width + 8, side),
    height: math.max(r.height + 8, side),
  );

  // -------------------------------------------------------------- motion --

  double get _fieldScale => (_field.shortestSide / 360).clamp(0.8, 1.8);

  /// Moves everything on by [dt] seconds.
  void tick(double dt) {
    if (dt <= 0 || _base == null) return;
    time += dt;
    _warp = math.max(0, _warp - dt * 1.3);
    _shake = math.max(0, _shake - dt * 2.2);
    _alarm = math.max(0, _alarm - dt * 1.8);
    _glee = math.max(0, _glee - dt * 1.6);
    _muzzle = math.max(0, _muzzle - dt * 9);
    _sinceShot += dt;

    _moveStars(dt);
    for (final rock in _rocks) {
      rock.at = rock.at + rock.drift * dt;
      final edge = -rock.at.z * 0.95;
      if (rock.at.x > edge) rock.at = V3(-edge, rock.at.y, rock.at.z);
      if (rock.at.x < -edge) rock.at = V3(edge, rock.at.y, rock.at.z);
    }

    for (final ship in ships) {
      _fly(ship, dt);
    }
    ships.removeWhere((ship) => ship.gone);
    for (final ship in _traffic) {
      _cruise(ship, dt);
    }

    _aim(dt);
    _moveLasers(dt);
    _moveDebris(dt);
    notifyListeners();
  }

  void _fly(WordShip ship, double dt) {
    if (ship.delay > 0) {
      ship.delay -= dt;
      // Its wait over, it flies from this frame on - placed in it.
      if (ship.delay > 0) return;
    }
    ship
      ..arrival = math.min(1, ship.arrival + dt / 0.75)
      ..flash = math.max(0, ship.flash - dt * 1.6)
      ..wobble = math.max(0, ship.wobble - dt * 1.4)
      ..yaw += ship.spin * ship.style.spin * dt;
    if (ship.lingering > 0) {
      ship.lingering -= dt;
      if (ship.lingering <= 0 && ship.leaving < 0) ship.leaving = 0;
    } else if (ship.leaving >= 0) {
      ship.leaving = math.min(1, ship.leaving + dt / 0.6);
    }

    final cruise = still
        ? 0.0
        : ship.missed
        ? 6.0 * _fieldScale
        : (13 + 22 * pace) * _fieldScale;
    ship._retarget -= dt;
    if (ship._retarget <= 0 ||
        (ship.destination - ship.position).distance < 10) {
      ship
        ..depthGoal = ship.missed
            ? ship.depthGoal
            : _depthAt(_random.nextDouble())
        ..destination = _spotFor(ship)
        .._retarget = 3.5 + _random.nextDouble() * 3;
    }

    final towards = ship.destination - ship.position;
    final steer = towards.distance < 1
        ? Offset.zero
        : towards / towards.distance * cruise;

    final ease = 1 - math.exp(-dt * 2.4);
    ship
      ..velocity = Offset.lerp(ship.velocity, steer, ease)!
      ..position += ship.velocity * dt
      ..depth += (ship.depthGoal - ship.depth) * (1 - math.exp(-dt * 0.5))
      ..bank += (-ship.velocity.dx * 0.006 - ship.bank) * ease;
    ship.position = _inside(ship, ship.position);
    if (ship.style.spin == 0) _steer(ship, dt, cruise);

    final arrive = Curves.easeOutCubic.transform(ship.arrival);
    var screen = Offset.lerp(_vanishing, ship.position, arrive)!;
    var depth = ship.depth + (1 - arrive) * 46;
    if (ship.leaving > 0) {
      final away = ship.leaving * ship.leaving;
      depth += away * 70;
      screen = screen.translate(0, -away * 70);
    }
    final bob = still ? 0.0 : math.sin(time * 1.7 + ship.phase) * 0.07;
    ship
      ..world = _base!.unproject(screen, depth) + V3(0, bob, 0)
      ..placed = true;
  }

  /// Turns [ship] towards the way it is flying: facing the viewer, a little
  /// aside, when it hovers, and round towards one side as it goes that way
  /// - never snapping, as nothing that size could.
  void _steer(WordShip ship, double dt, double cruise) {
    final across = cruise <= 0
        ? 0.0
        : (ship.velocity.dx / cruise).clamp(-1.5, 1.5);
    final goal = math.pi + ship.facing * 0.6 + math.atan(across / 0.6);
    ship.heading += (goal - ship.heading) * (1 - math.exp(-dt * 1.8));
  }

  /// [at], moved just enough for [ship]'s footprint to be in its cell - or,
  /// were it bigger than the cell, put in its middle.
  Offset _inside(WordShip ship, Offset at) {
    final bounds = ship.cell.isEmpty ? _field : ship.cell;
    final box = _footprint(ship, at, ship.depth);
    double shift(double low, double high, double from, double to) =>
        high - low >= to - from
        ? (from + to) / 2 - (low + high) / 2
        : low < from
        ? from - low
        : high > to
        ? to - high
        : 0;
    return at.translate(
      shift(box.left, box.right, bounds.left, bounds.right),
      shift(box.top, box.bottom, bounds.top, bounds.bottom),
    );
  }

  /// Somewhere in [ship]'s cell for it to go.
  Offset _spotFor(WordShip ship) {
    final bounds = ship.cell.isEmpty ? _field : ship.cell;
    return _inside(
      ship,
      Offset(
        bounds.left + _random.nextDouble() * bounds.width,
        bounds.top + _random.nextDouble() * bounds.height,
      ),
    );
  }

  /// Where ships come in from, and stars stream out of.
  Offset get _vanishing =>
      Offset(_field.center.dx, _field.top + _field.height * 0.35);

  V3 get _fighterAt {
    final base = _base!;
    return base.unproject(
      // Under the middle of the field, whichever side the panels are on.
      Offset(
        (clear.left + size.width - clear.right) / 2,
        size.height - clear.bottom * 0.52,
      ),
      3.3,
    );
  }

  static const _fighterScale = 0.6;

  Rot get _fighterTurn {
    final roll =
        (still ? 0.0 : math.sin(time * 0.8) * 0.06) +
        (_aimYawGoal - _aimYaw) * 0.9;
    return Rot.euler(yaw: _aimYaw, pitch: _aimPitch, roll: roll);
  }

  double _aimYawGoal = 0;

  /// Where the fighter is drawn: where it flies, bobbing as it hovers.
  V3 get _fighterShown =>
      _fighterAt + V3(0, still ? 0 : math.sin(time * 1.3) * 0.035, 0);

  /// Where cannon [i] fires from, in the world.
  V3 _muzzleOf(int i) =>
      _fighterShown + _fighterTurn.apply(Models.muzzles[i] * _fighterScale);

  /// Where engine [i] is, in the world.
  V3 _engine(int i) =>
      _fighterShown + _fighterTurn.apply(Models.exhausts[i] * _fighterScale);

  void _aim(double dt) {
    if (_base == null || ambient) return;
    final target = _sinceShot < 0.7 && _aimAt != null
        ? _aimAt!
        : _base!.unproject(_field.center, 9);
    final facing = Rot.facing(target - _fighterAt);
    _aimYawGoal = facing.yaw;
    final ease = 1 - math.exp(-dt * 12);
    _aimYaw += (facing.yaw - _aimYaw) * ease;
    _aimPitch += (facing.pitch - _aimPitch) * ease;

    // Exhaust, streaming back from the engine towards the learner.
    _exhaust += dt * 34;
    while (_exhaust >= 1) {
      _exhaust -= 1;
      final back = _fighterTurn.apply(const V3(0, 0, 1));
      _sparks.add(
        _Spark(
          at: _engine(_sparks.length.isEven ? 0 : 1),
          exhaust: true,
          velocity: back * (1.2 + _random.nextDouble() * 1.2) + _scatter(0.25),
          color: _random.nextBool()
              ? const Color(0xFFFFB347)
              : const Color(0xFFFF6A3D),
          size: 1.2 + _random.nextDouble() * 1.6,
          life: 0.22 + _random.nextDouble() * 0.2,
          drag: 1,
        ),
      );
    }
  }

  void _moveLasers(double dt) {
    for (final laser in _lasers.toList()) {
      laser.progress += dt / 0.2;
      if (laser.progress < 1) continue;
      _lasers.remove(laser);
      final ship = laser.ship..targeted = false;
      if (ship.gone || ship.leaving >= 0) continue;
      for (var i = 0; i < 8; i++) {
        _sparks.add(
          _Spark(
            at: ship.world,
            about: ship.world,
            velocity: _scatter(1 + _random.nextDouble() * 2),
            color: const Color(0xFFFFFFFF),
            size: 1.4,
            life: 0.25,
          ),
        );
      }
      onImpact?.call(laser.round, ship.index);
    }
  }

  void _moveDebris(double dt) {
    for (final shard in _shards) {
      shard
        ..age += dt
        ..at = shard.at + shard.velocity * dt
        ..velocity = shard.velocity * math.exp(-dt * 1.6);
    }
    _shards.removeWhere((shard) => shard.age >= shard.life);
    for (final spark in _sparks) {
      spark
        ..age += dt
        ..at = spark.at + spark.velocity * dt
        ..velocity = spark.velocity * math.exp(-dt * spark.drag);
    }
    _sparks.removeWhere((spark) => spark.age >= spark.life);
    for (final burst in _bursts) {
      burst.age += dt;
    }
    _bursts.removeWhere((burst) => burst.age >= burst.life);
    for (final popup in _popups) {
      popup.age += dt;
    }
    _popups.removeWhere((popup) => popup.age >= 1.2);
  }

  V3 _scatter(double speed) {
    // A direction uniform over the ball.
    final z = _random.nextDouble() * 2 - 1;
    final a = _random.nextDouble() * math.pi * 2;
    final r = math.sqrt(1 - z * z);
    return V3(r * math.cos(a), r * math.sin(a), z) * speed;
  }

  // --------------------------------------------------------- scenery --

  static const _starCount = 260;
  final Float64List _starX = Float64List(_starCount);
  final Float64List _starY = Float64List(_starCount);
  final Float64List _starZ = Float64List(_starCount);
  final Float64List _starTwinkle = Float64List(_starCount);
  final Float64List _starLastX = Float64List(_starCount);
  final Float64List _starLastY = Float64List(_starCount);

  void _seedStars() {
    for (var i = 0; i < _starCount; i++) {
      _respawnStar(i, z: 0.08 + _random.nextDouble() * 0.92);
    }
  }

  void _respawnStar(int i, {double z = 1}) {
    _starX[i] = _random.nextDouble() * 2 - 1;
    _starY[i] = _random.nextDouble() * 2 - 1;
    _starZ[i] = z;
    _starTwinkle[i] = _random.nextDouble() * math.pi * 2;
    _starLastX[i] = double.nan;
  }

  void _moveStars(double dt) {
    if (still) return;
    final speed = 0.018 + _warp * _warp * 1.4;
    for (var i = 0; i < _starCount; i++) {
      _starZ[i] -= dt * speed;
      if (_starZ[i] <= 0.06) _respawnStar(i);
    }
  }

  void _seedRocks() {
    for (var i = 0; i < 5; i++) {
      final depth = 20 + _random.nextDouble() * 18;
      // Out at the sides, where they give the sky depth without standing
      // behind a word.
      final side = i.isEven ? 1 : -1;
      _rocks.add(
        _Rock(
          at: V3(
            side * (0.4 + _random.nextDouble() * 0.45) * depth * 0.7,
            (_random.nextDouble() * 2 - 1) * depth * 0.5,
            -depth,
          ),
          drift: V3(
            (0.12 + _random.nextDouble() * 0.3) * (i.isEven ? 1 : -1),
            (_random.nextDouble() - 0.5) * 0.06,
            0,
          ),
          size: 0.35 + _random.nextDouble() * 0.55,
          seed: i % 4,
          spin: V3(
            _random.nextDouble() * 0.5,
            _random.nextDouble() * 0.4,
            0,
          ),
        ),
      );
    }
  }

  /// A few ships going about their business, in the lobby.
  void _seedTraffic() {
    for (var i = 0; i < 4; i++) {
      _traffic.add(
        WordShip._(
          index: i,
          label: '',
          meaning: '',
          variant: i,
          style: ShipStyle.values[(i * 2 + 1) % ShipStyle.values.length],
          facing: 0,
          position: Offset.zero,
          depth: 11 + i * 3.5,
          delay: 0,
          phase: _random.nextDouble() * math.pi * 2,
          spin: 0.6 + _random.nextDouble() * 0.5,
        )..arrival = 1,
      );
    }
  }

  void _cruise(WordShip ship, double dt) {
    ship.yaw += ship.spin * ship.style.spin * dt;
    if (size.isEmpty) return;
    // Each loops a wide lazy ellipse of its own.
    final t = still
        ? ship.phase
        : time * (0.05 + ship.index * 0.012) + ship.phase;
    final at = Offset(
      size.width * (0.5 + 0.42 * math.cos(t)),
      size.height * (0.42 + 0.3 * math.sin(t * 1.3 + ship.index)),
    );
    ship
      ..bank = -math.sin(t) * 0.25
      // Nose along its loop, as far as it moves across.
      ..heading = math.pi + math.atan(-math.sin(t) * 2.5)
      ..world =
          _base!.unproject(at, ship.depth) +
          V3(0, math.sin(time * 1.2 + ship.phase) * 0.12, 0)
      ..placed = true;
  }

  // ------------------------------------------------------------- paint --

  /// Draws the whole of it on [canvas], sized as last [layout] said.
  void paint(Canvas canvas) {
    final base = _base;
    if (base == null || size.isEmpty) return;
    final shake = still ? 0.0 : _shake * _shake * 0.06;
    final swayed = Camera(
      eye: V3(
        (still ? 0 : _swayX * math.sin(time * 0.21)) +
            (_random.nextDouble() - 0.5) * shake,
        (still ? 0 : _swayY * math.sin(time * 0.17 + 1)) +
            (_random.nextDouble() - 0.5) * shake,
        0,
      ),
      rotation: Rot.euler(
        yaw: still ? 0 : _swayYaw * math.sin(time * 0.23),
        pitch: -0.1 + (still ? 0 : _swayPitch * math.sin(time * 0.19)),
      ),
      size: size,
    );

    _paintSky(canvas, swayed);
    _paintStars(canvas, swayed);
    _paintFlares(canvas, swayed);

    // The far world, then its glow, then the near world over both.
    _renderer.begin(swayed, palette.lighting);
    final planet = _paintPlanet(swayed);
    for (final rock in _rocks) {
      _renderer.draw(
        Models.rock(palette, rock.seed),
        at: rock.at,
        turn: Rot.euler(
          yaw: time * rock.spin.x + rock.seed,
          pitch: time * rock.spin.y,
        ),
        scale: rock.size,
      );
    }
    _renderer.flush(canvas);
    facesDrawn = _renderer.drawn;
    if (planet != null) _atmosphere(canvas, planet.$1, planet.$2);

    _renderer.begin(swayed, palette.lighting);
    for (final ship in _traffic) {
      if (!ship.placed) continue;
      _renderer.draw(
        Models.ship(ship.style),
        at: ship.world,
        turn: _turnOf(ship, swayed),
        scale: _shipScale,
        paint: ShipColours.body[ship.variant],
        trim: ShipColours.lights[ship.variant],
        fog: 0.9,
      );
    }
    for (final ship in ships) {
      if (!ship.shown) continue;
      _paintShip(ship, swayed);
    }
    for (final shard in _shards) {
      final left = 1 - shard.age / shard.life;
      _renderer.draw(
        Models.shard,
        at: shard.at,
        turn: Rot.euler(
          yaw: shard.spin.x * shard.age,
          pitch: shard.spin.y * shard.age,
          roll: shard.spin.z * shard.age,
        ),
        scale: shard.size * (0.3 + 0.7 * left),
        paint: ShipColours.body[shard.variant],
        trim: ShipColours.lights[shard.variant],
        glow: 0.2 * left,
        fog: 0.3,
      );
    }
    if (!ambient) {
      _renderer.draw(
        Models.fighter,
        at: _fighterShown,
        turn: _fighterTurn,
        scale: _fighterScale,
        fog: 0,
      );
    }
    _renderer.flush(canvas);
    facesDrawn += _renderer.drawn;

    for (final ship in ships) {
      if (!ship.shown) continue;
      _paintShipLight(canvas, swayed, ship);
    }
    if (!ambient) _paintEngine(canvas, swayed);
    _paintSparks(canvas, swayed);
    _paintLasers(canvas, swayed);
    _paintBursts(canvas, swayed);

    final drawn = [
      for (final ship in ships)
        if (ship.shown) ship,
    ]..sort((a, b) => b.depth.compareTo(a.depth));
    for (final ship in drawn) {
      _paintLabel(canvas, swayed, ship);
    }
    _paintPopups(canvas, swayed);
    _paintVeil(canvas);
  }

  void _paintSky(Canvas canvas, Camera camera) {
    final nebula = Nebula.of(palette);
    if (nebula != null) {
      _paintNebula(canvas, camera, nebula);
      return;
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          palette.skyTop,
          palette.skyBottom,
        ]),
    );
    // The nebulae, drifting a little and moving against the camera, as
    // what is furthest away does.
    final shift = Offset(-camera.eye.x * 18, camera.eye.y * 18);
    final reach = size.longestSide;
    const places = [
      (0.12, 0.2, 0.5),
      (0.9, 0.48, 0.42),
      (0.3, 0.95, 0.62),
      (0.62, 0.3, 0.22),
      (0.08, 0.66, 0.26),
    ];
    for (final (i, (fx, fy, fr)) in places.indexed) {
      final drift = still
          ? Offset.zero
          : Offset(
              math.sin(time * 0.03 + i * 2) * 0.03 * size.width,
              math.cos(time * 0.025 + i) * 0.02 * size.height,
            );
      final centre =
          Offset(size.width * fx, size.height * fy) + drift + shift * (i + 1.0);
      final colour = palette.nebulae[i % palette.nebulae.length];
      canvas.drawCircle(
        centre,
        reach * fr,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            reach * fr,
            [
              colour,
              colour.withValues(alpha: colour.a * 0.35),
              colour.withValues(alpha: 0),
            ],
            const [0, 0.45, 1],
          ),
      );
    }
  }

  /// The painted nebula, covering the canvas, drifting very slowly and
  /// moving against the camera as what is furthest away does.
  void _paintNebula(Canvas canvas, Camera camera, ui.Image image) {
    final cover = size.longestSide * 1.12;
    final drift = still
        ? Offset.zero
        : Offset(math.sin(time * 0.017), math.cos(time * 0.013)) *
              (size.shortestSide * 0.02);
    final centre =
        size.center(Offset.zero) +
        drift +
        Offset(-camera.eye.x * 22, camera.eye.y * 22);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: centre, width: cover, height: cover),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  final Float32List _points = Float32List(_starCount * 2);
  final Float32List _streaks = Float32List(_starCount * 4);

  void _paintStars(Canvas canvas, Camera camera) {
    final centre = _vanishing.translate(-camera.eye.x * 40, camera.eye.y * 40);
    final reach = size.longestSide * 0.55;
    final streaking = _warp > 0.08;
    // Three sizes, three brightnesses: nine batches of points, rather than
    // a call per star.
    for (var band = 0; band < 3; band++) {
      for (var light = 0; light < 3; light++) {
        var n = 0;
        var lines = 0;
        for (var i = 0; i < _starCount; i++) {
          final z = _starZ[i];
          final near = 1 - z;
          final starBand = near < 0.55
              ? 0
              : near < 0.85
              ? 1
              : 2;
          if (starBand != band) continue;
          final twinkle =
              0.72 + 0.28 * math.sin(time * (1.5 + i % 5) + _starTwinkle[i]);
          final starLight = twinkle * (0.35 + 0.65 * near) < 0.5
              ? 0
              : twinkle * (0.35 + 0.65 * near) < 0.75
              ? 1
              : 2;
          if (starLight != light) continue;
          final x = centre.dx + _starX[i] / z * reach * 0.3;
          final y = centre.dy + _starY[i] / z * reach * 0.3;
          if (x < -4 || y < -4 || x > size.width + 4 || y > size.height + 4) {
            if (!still) _respawnStar(i);
            continue;
          }
          if (streaking && !_starLastX[i].isNaN) {
            _streaks
              ..[lines * 4] = _starLastX[i]
              ..[lines * 4 + 1] = _starLastY[i]
              ..[lines * 4 + 2] = x
              ..[lines * 4 + 3] = y;
            lines++;
          } else {
            _points
              ..[n * 2] = x
              ..[n * 2 + 1] = y;
            n++;
          }
          _starLastX[i] = x;
          _starLastY[i] = y;
        }
        final paint = Paint()
          ..color = Color.fromRGBO(235, 240, 255, 0.55 + light * 0.22)
          ..strokeCap = StrokeCap.round
          ..strokeWidth =
              (1.2 + band * 1.2) * (size.shortestSide / 400).clamp(0.9, 1.6);
        if (n > 0) {
          canvas.drawRawPoints(
            ui.PointMode.points,
            Float32List.sublistView(_points, 0, n * 2),
            paint,
          );
        }
        if (lines > 0) {
          canvas.drawRawPoints(
            ui.PointMode.lines,
            Float32List.sublistView(_streaks, 0, lines * 4),
            paint,
          );
        }
      }
    }
  }

  /// A handful of bright stars, each twinkling with a cross of light: what
  /// makes a sky look deep rather than dotted.
  void _paintFlares(Canvas canvas, Camera camera) {
    const flares = [
      (0.08, 0.12, 1.0),
      (0.42, 0.06, 0.7),
      (0.7, 0.34, 0.8),
      (0.18, 0.52, 0.6),
      (0.93, 0.7, 0.75),
      (0.55, 0.88, 0.65),
    ];
    final shift = Offset(-camera.eye.x * 26, camera.eye.y * 26);
    final unit = (size.shortestSide / 400).clamp(0.8, 1.8);
    for (final (i, (fx, fy, k)) in flares.indexed) {
      final twinkle = still
          ? 0.85
          : 0.6 + 0.4 * math.sin(time * (0.9 + i * 0.37) + i * 1.7);
      final at = Offset(size.width * fx, size.height * fy) + shift;
      final reach = 9 * k * unit * twinkle;
      _glow(canvas, at, reach * 1.6, const Color(0xFFDDE8FF), strength: 0.6);
      final ray = Paint()
        ..blendMode = BlendMode.plus
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1 * unit
        ..color = Color.fromRGBO(225, 235, 255, 0.55 * twinkle);
      canvas
        ..drawLine(at.translate(-reach, 0), at.translate(reach, 0), ray)
        ..drawLine(at.translate(0, -reach), at.translate(0, reach), ray)
        ..drawCircle(
          at,
          1.4 * unit,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * twinkle),
        );
    }
  }

  /// Draws the planet, its rings and its moon into the batch; returns where
  /// it is on the screen and how big, for its atmosphere.
  (Offset, double)? _paintPlanet(Camera camera) {
    final base = _base!;
    // Up in a corner: a landmark, never behind a word.
    final anchor = ambient
        ? Offset(size.width * 0.86, size.height * 0.31)
        : Offset(size.width * 0.97, size.height * 0.1);
    final depth = ambient ? 44.0 : 46.0;
    final radius = ambient ? 10.5 : 13.0;
    final at = base.unproject(anchor, depth);
    final tilt = Rot.euler(pitch: 0.42, roll: -0.36);
    // Under reduced motion the planet holds still, and its moon with it.
    final time = still ? 0.0 : this.time;
    _renderer
      ..draw(
        Models.planet(palette),
        at: at,
        turn: tilt * Rot.euler(yaw: time * 0.035),
        scale: radius,
        fog: 0.35,
        limb: palette.air,
        whole: false,
      )
      ..draw(
        Models.rings(palette),
        at: at,
        turn: tilt,
        scale: radius,
        fog: 0.5,
        whole: false,
      );
    // The moon keeps close to its planet: just outside the rings, on an
    // orbit tipped most of the way towards the viewer, so it goes behind the
    // planet at the top and round in front below without ever coming much
    // nearer than it. It used to swing a wide loop that brought it far
    // nearer than its planet and down through the words; in a mission it is
    // left out, the planet being half off the screen in a corner.
    moonOnScreen = null;
    if (ambient) {
      final orbit = time * 0.11 + 1.2;
      final moon =
          at +
          Rot.euler(pitch: 1.25, roll: -0.36).apply(
            V3(math.cos(orbit), 0, math.sin(orbit)) * (radius * 2.4),
          );
      _renderer.draw(
        Models.moon(palette),
        at: moon,
        turn: Rot.euler(yaw: time * 0.05),
        scale: radius * 0.18,
        fog: 0.4,
      );
      final shown = camera.project(moon);
      if (shown != null) {
        moonOnScreen = (
          shown,
          radius * 0.18 * camera.scaleAt(camera.depthOf(moon)),
        );
      }
    }
    final centre = camera.project(at);
    if (centre == null) return null;
    return planetOnScreen = (
      centre,
      radius * camera.scaleAt(camera.depthOf(at)),
    );
  }

  void _atmosphere(Canvas canvas, Offset centre, double radius) {
    final glow = palette.glow;
    canvas.drawCircle(
      centre,
      radius * 1.22,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          centre,
          radius * 1.22,
          [
            glow.withValues(alpha: 0),
            glow.withValues(alpha: 0),
            glow.withValues(alpha: 0.26),
            glow.withValues(alpha: 0),
          ],
          const [0, 0.76, 0.83, 1],
        ),
    );
  }

  /// How far above the eye's level [at] is seen, as an angle: a ship is
  /// tipped by it, so each is seen from a little above wherever it flies,
  /// rather than from below at the top of the screen and from overhead at
  /// the bottom.
  static double _elevation(Camera camera, V3 at) {
    final d = at - camera.eye;
    return math.atan2(d.dot(camera.up), d.dot(camera.forward));
  }

  /// How [ship] is turned: spun about itself or facing where it goes, then
  /// tipped to be seen from a little above, banked into its turn, and
  /// shaken when a shot has just hit its shield.
  Rot _turnOf(WordShip ship, Camera camera) {
    final wobble = ship.wobble * math.sin(time * 34) * 0.3;
    final tip = ship.style.tip + _elevation(camera, ship.world);
    return Rot.euler(pitch: tip + wobble, roll: ship.bank + wobble * 0.6) *
        Rot.euler(yaw: ship.style.spin > 0 ? ship.yaw : ship.heading);
  }

  double _scaleOf(WordShip ship) =>
      _shipScale * (0.85 + 0.15 * Curves.easeOutBack.transform(ship.arrival));

  void _paintShip(WordShip ship, Camera camera) {
    final pulse = 0.5 + 0.5 * math.sin(time * 6);
    final (tint, tinted) = ship.flash > 0
        ? (const Rgb(1, 0.3, 0.38), ship.flash * 0.65)
        : ship.missed
        ? (const Rgb(0.42, 0.45, 0.55), 0.6)
        : ship.revealed || ship.hinted
        ? (const Rgb(1, 0.84, 0.35), 0.12 + 0.16 * pulse)
        : (null, 0.0);
    _renderer.draw(
      Models.ship(ship.style),
      at: ship.world,
      turn: _turnOf(ship, camera),
      scale: _scaleOf(ship),
      paint: ShipColours.body[ship.variant],
      trim: ShipColours.lights[ship.variant],
      tint: tint,
      tinted: tinted,
      light: ship.missed ? 0.55 : 1,
      glow: ship.hinted || ship.revealed ? 0.12 * pulse : 0,
      fog: 0.6,
    );
  }

  /// The lamp under a ship, its shield, its hint - light drawn over it.
  void _paintShipLight(Canvas canvas, Camera camera, WordShip ship) {
    final at = camera.project(ship.world);
    if (at == null) return;
    final depth = camera.depthOf(ship.world);
    final radius = 0.96 * _shipScale * camera.scaleAt(depth);
    ship
      ..hull = at
      ..hullRadius = radius;
    final fade =
        (ship.leaving > 0 ? 1 - ship.leaving : 1) *
        Curves.easeIn.transform(ship.arrival);
    if (!ship.missed) {
      final turn = _turnOf(ship, camera);
      final scale = _scaleOf(ship);
      final lens = camera.lensAt(ship.world);
      final colour = ShipColours.lights[ship.variant].color;
      for (final light in ship.style.lights) {
        final where = ship.world + turn.apply(light.at * scale);
        var towards = 1.0;
        if (light.facing case final facing?) {
          towards = turn.apply(facing).dot((camera.eye - where).unit);
          if (towards <= 0) continue;
        }
        final shown = lens.project(where);
        if (shown == null) continue;
        _glow(
          canvas,
          shown,
          radius * light.size * (0.5 + 0.5 * towards),
          colour.withValues(alpha: 0.55),
          strength: fade,
        );
      }
    }
    if (ship.flash > 0) {
      final shield = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          at,
          radius * 1.55,
          [
            const Color(0x00FF5D73),
            const Color(0x00FF5D73),
            Color.fromRGBO(255, 93, 115, 0.75 * ship.flash),
            const Color(0x00FF5D73),
          ],
          const [0, 0.6, 0.9, 1],
        );
      canvas
        ..drawCircle(at, radius * 1.55, shield)
        ..drawCircle(
          at,
          radius * (1.3 + 0.2 * (1 - ship.flash)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Color.fromRGBO(255, 180, 190, ship.flash),
        );
    }
    if (ship.hinted || ship.revealed) {
      final pulse = 0.5 + 0.5 * math.sin(time * 6);
      _glow(
        canvas,
        at,
        radius * (1.9 + 0.3 * pulse),
        const Color(0xFFFFD166).withValues(alpha: 0.55),
        strength: fade,
      );
      canvas.drawCircle(
        at,
        radius * (1.35 + 0.12 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Color.fromRGBO(255, 214, 102, 0.85 * fade),
      );
    }
  }

  void _paintEngine(Canvas canvas, Camera camera) {
    final fighter = camera.lensAt(_fighterShown);
    final flicker = still
        ? 1.0
        : 0.86 + 0.08 * math.sin(time * 41) + 0.06 * math.sin(time * 67 + 1);
    final scale = camera.scaleAt(camera.depthOf(_fighterShown));
    for (var i = 0; i < Models.exhausts.length; i++) {
      final at = fighter.project(_engine(i));
      if (at == null) continue;
      // Light thrown round the bell, then the plasma, then its white-hot
      // heart.
      _glow(
        canvas,
        at,
        0.75 * scale * flicker,
        const Color(0xFF3A8BFF).withValues(alpha: 0.32),
      );
      _glow(
        canvas,
        at,
        0.34 * scale * flicker,
        const Color(0xFF8FD8FF).withValues(alpha: 0.85),
      );
      _glow(canvas, at, 0.14 * scale * flicker, const Color(0xFFF2FBFF));
    }
    if (_muzzle > 0) {
      final muzzle = fighter.project(_muzzleOf(_cannon));
      if (muzzle != null) {
        _glow(
          canvas,
          muzzle,
          0.45 * scale * _muzzle,
          palette.glow,
          strength: _muzzle,
        );
        _glow(
          canvas,
          muzzle,
          0.16 * scale * _muzzle,
          const Color(0xFFFFFFFF),
          strength: _muzzle,
        );
      }
    }
  }

  void _paintSparks(Canvas canvas, Camera camera) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round;
    final fighter = ambient ? null : camera.lensAt(_fighterShown);
    final lenses = Map<V3, Lens>.identity();
    for (final spark in _sparks) {
      final about = spark.about;
      final lens = spark.exhaust
          ? fighter
          : about == null
          ? null
          : lenses.putIfAbsent(about, () => camera.lensAt(about));
      final at = lens?.project(spark.at) ?? camera.project(spark.at);
      if (at == null) continue;
      final left = 1 - spark.age / spark.life;
      final scale = (camera.scaleAt(camera.depthOf(spark.at)) / 40).clamp(
        0.4,
        3.0,
      );
      paint
        ..color = spark.color.withValues(alpha: left)
        ..strokeWidth = spark.size * scale * (0.5 + 0.5 * left);
      final last = spark.last;
      if (last != null && (last - at).distance > 1.5) {
        canvas.drawLine(last, at, paint);
      } else {
        canvas.drawCircle(at, paint.strokeWidth / 2, paint);
      }
      spark.last = at;
    }
  }

  void _paintLasers(Canvas canvas, Camera camera) {
    final fighter = camera.lensAt(_fighterShown);
    for (final laser in _lasers) {
      final from = _muzzleOf(laser.cannon);
      final target = laser.ship.world;
      // Each end where its solid is drawn: the cannon through the fighter's
      // lens, the ship through its own, whose middle is where the camera
      // puts it.
      final start = fighter.project(from);
      final end = camera.project(target);
      if (start == null || end == null) continue;
      final head = laser.progress.clamp(0.0, 1.0);
      // A bolt, not a beam: a fifth of the way long.
      final tail = (laser.progress - 0.2).clamp(0.0, 1.0);
      final a = Offset.lerp(start, end, tail)!;
      final b = Offset.lerp(start, end, head)!;
      final depth =
          camera.depthOf(from) +
          (camera.depthOf(target) - camera.depthOf(from)) * head;
      final width = (camera.scaleAt(depth) * 0.09).clamp(2.5, 10.0);
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width * 2.6
            ..color = palette.glow.withValues(alpha: 0.35),
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width
            ..color = const Color(0xFFF4FBFF),
        );
      _glow(canvas, b, width * 2.4, palette.glow);
    }
  }

  void _paintBursts(Canvas canvas, Camera camera) {
    for (final burst in _bursts) {
      final at = camera.project(burst.at);
      if (at == null) continue;
      final t = burst.age / burst.life;
      final scale = camera.scaleAt(camera.depthOf(burst.at));
      _glow(
        canvas,
        at,
        burst.reach * scale * (0.35 + 0.65 * Curves.easeOut.transform(t)),
        burst.color,
        strength: 1 - t,
      );
      canvas.drawCircle(
        at,
        burst.reach * scale * Curves.easeOutCubic.transform(t) * 0.8,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t) + 0.5
          ..color = burst.color.withValues(alpha: 0.8 * (1 - t)),
      );
    }
  }

  void _paintLabel(Canvas canvas, Camera camera, WordShip ship) {
    final hull = ship.hull;
    if (hull == null) return;
    final show = ship.leaving > 0
        ? 1 - (ship.leaving * 3).clamp(0.0, 1.0)
        : ((ship.arrival - _shown) / (1 - _shown)).clamp(0.0, 1.0);
    if (show <= 0) {
      ship.labelRect = null;
      return;
    }
    final pop = Curves.easeOutBack.transform(show);
    final lightLabel = ship.revealed || ship.hinted;
    final ink = ship.missed
        ? const Color(0xFFB9BFCF)
        : lightLabel
        ? const Color(0xFF2B1D00)
        : const Color(0xFFFFFFFF);
    final text = _text(ship.label, color: ink);
    final depthScale = _labelScale(ship.depth);
    final width = text.width + _labelPadding.horizontal;
    final height = text.height + _labelPadding.vertical;
    final centre = hull.translate(
      ship.wobble * math.sin(time * 40) * 6,
      -(ship.hullRadius * 0.95 + 8 + height * depthScale / 2),
    );
    final rect = Rect.fromCenter(
      center: centre,
      width: width * depthScale,
      height: height * depthScale,
    );
    ship.labelRect = rect;

    final accent = ship.missed
        ? const Color(0xFFFF6B81)
        : lightLabel
        ? const Color(0xFFFFD166)
        : ShipColours.lights[ship.variant].color;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(depthScale * pop)
      ..translate(-centre.dx, -centre.dy);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: width, height: height),
      Radius.circular(height / 2),
    );
    canvas
      ..drawRRect(
        pill.shift(const Offset(0, 3)),
        Paint()..color = const Color(0x66000000),
      )
      ..drawRRect(
        pill,
        Paint()
          ..color = ship.missed
              ? const Color(0xE6331420)
              : lightLabel
              ? const Color(0xFFFFD166)
              : const Color(0xE60A1030),
      )
      ..drawRRect(
        pill.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent,
      );
    text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));

    if (ship.missed || ship.revealed) {
      // What the word means: the mistake becomes something learned.
      final meaning = _text(
        ship.meaning,
        color: ship.revealed
            ? const Color(0xFFFFE7A6)
            : const Color(0xFFFFC2CC),
        size: 0.82,
        weight: FontWeight.w600,
      );
      // Tucked under the word, over its ship: never into a neighbour's
      // cell.
      final under = centre.translate(0, height / 2 + meaning.height / 2 + 6);
      final tag = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: under,
          width: meaning.width + 18,
          height: meaning.height + 8,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(tag, Paint()..color = const Color(0xD9000000));
      meaning.paint(
        canvas,
        under - Offset(meaning.width / 2, meaning.height / 2),
      );
    }
    canvas.restore();
  }

  void _paintPopups(Canvas canvas, Camera camera) {
    for (final popup in _popups) {
      final at = camera.project(popup.at);
      if (at == null) continue;
      final t = popup.age / 1.2;
      final text = _text(
        popup.text,
        color: const Color(0xFFFFD166),
        size: 1.5,
        weight: FontWeight.w800,
      );
      final rise = Curves.easeOutCubic.transform(t) * 70;
      final grow = Curves.easeOutBack.transform((t * 3).clamp(0.0, 1.0));
      final centre = at.translate(0, -30 - rise);
      final fade = 1 - Curves.easeIn.transform(t);
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..scale(grow)
        ..translate(-centre.dx, -centre.dy);
      if (fade < 1) {
        canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fade));
      }
      text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
      if (fade < 1) canvas.restore();
      canvas.restore();
    }
  }

  /// Darkened corners, which hold the eye in the middle - and red at the
  /// edges for a shot that missed, gold for one that hit.
  void _paintVeil(Canvas canvas) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final reach = size.longestSide * 0.75;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          reach,
          const [Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
          const [0, 0.55, 1],
        ),
    );
    final alarm = still ? _alarm * 0.5 : _alarm;
    if (alarm > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            reach,
            [
              const Color(0x00FF3355),
              const Color(0x00FF3355),
              Color.fromRGBO(255, 51, 85, 0.5 * alarm),
            ],
            const [0, 0.5, 1],
          ),
      );
    }
    final glee = still ? _glee * 0.5 : _glee;
    if (glee > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            centre,
            reach,
            [
              const Color(0x00FFD166),
              const Color(0x00FFD166),
              Color.fromRGBO(255, 209, 102, 0.28 * glee),
            ],
            const [0, 0.55, 1],
          ),
      );
    }
  }

  void _glow(
    Canvas canvas,
    Offset at,
    double radius,
    Color color, {
    double strength = 1,
  }) {
    if (radius < 0.5 || strength <= 0) return;
    final a = color.a * strength.clamp(0.0, 1.0);
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          at,
          radius,
          [
            color.withValues(alpha: a),
            color.withValues(alpha: a * 0.32),
            color.withValues(alpha: 0),
          ],
          const [0, 0.35, 1],
        ),
    );
  }

  @override
  void dispose() {
    _forgetTexts();
    super.dispose();
  }
}
