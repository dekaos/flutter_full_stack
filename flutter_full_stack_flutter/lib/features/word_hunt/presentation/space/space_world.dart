import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/models.dart';
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
  }) : destination = position,
       depthGoal = depth;

  /// Its place among the round's choices.
  final int index;

  /// The English word on it.
  final String label;

  /// What [label] means, in Portuguese: shown once it has been shot wrongly,
  /// or when time runs out on it as the answer.
  final String meaning;

  /// Which of [ShipColours] it is painted in.
  final int variant;

  /// The part of the field it flies in. A wave's cells never overlap, and
  /// each is big enough for its ship's word, so no word is ever over
  /// another.
  Rect cell = Rect.zero;

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

  /// Where the world has it, for lasers to fly to.
  V3 world = V3.zero;

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
  _Laser(this.from, this.ship, this.round);
  final V3 from;
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
  });
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
/// rocket and its lasers, explosions, and the sky it all happens in -
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

  /// The lobby's world: no rocket and no words, just traffic going by.
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
    // A turned phone: everyone keeps their place, relative to the field,
    // in a new arrangement that fits it.
    if (!before.isEmpty && ships.isNotEmpty) {
      Offset map(Offset p) => Offset(
        _field.left + (p.dx - before.left) / before.width * _field.width,
        _field.top + (p.dy - before.top) / before.height * _field.height,
      );
      _arrange(_crew);
      for (final ship in ships) {
        ship
          ..position = _inside(ship, map(ship.position))
          ..destination = _inside(ship, map(ship.destination));
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

  /// Shares the field out among [crew]: a grid of cells, as many across as
  /// gives each the most room for the widest word among them, handed out
  /// in a random order so a wave does not line up the same way twice.
  /// When even the best grid is too small - six long phrases on a narrow
  /// phone, in large text - everything is made just small enough to fit.
  void _arrange(List<WordShip> crew) {
    if (crew.isEmpty || _field.isEmpty) return;
    _fit = 1;
    var width = 0.0;
    var height = 0.0;
    for (final ship in crew) {
      final box = _footprint(ship, Offset.zero, _nearest);
      width = math.max(width, box.width);
      height = math.max(height, box.height);
    }
    var best = 0.0;
    var across = 1;
    for (var cols = 1; cols <= crew.length; cols++) {
      final rows = (crew.length / cols).ceil();
      final room = math.min(
        _field.width / cols / (width + _gap),
        _field.height / rows / (height + _gap),
      );
      if (room > best) {
        best = room;
        across = cols;
      }
    }
    _fit = math.min(1, best * 0.97);
    final down = (crew.length / across).ceil();
    final cellWidth = _field.width / across;
    final cellHeight = _field.height / down;
    final cells = [
      for (var row = 0; row < down; row++)
        for (var col = 0; col < across; col++)
          Rect.fromLTWH(
            _field.left + col * cellWidth,
            _field.top + row * cellHeight,
            cellWidth,
            cellHeight,
          ).deflate(_gap / 2),
    ]..shuffle(_random);
    for (final (i, ship) in crew.indexed) {
      ship.cell = cells[i];
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
    _lasers.add(_Laser(_nose, ship, round));
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
      return;
    }
    ship
      ..arrival = math.min(1, ship.arrival + dt / 0.75)
      ..flash = math.max(0, ship.flash - dt * 1.6)
      ..wobble = math.max(0, ship.wobble - dt * 1.4)
      ..yaw += ship.spin * dt;
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

    final arrive = Curves.easeOutCubic.transform(ship.arrival);
    var screen = Offset.lerp(_vanishing, ship.position, arrive)!;
    var depth = ship.depth + (1 - arrive) * 46;
    if (ship.leaving > 0) {
      final away = ship.leaving * ship.leaving;
      depth += away * 70;
      screen = screen.translate(0, -away * 70);
    }
    final bob = still ? 0.0 : math.sin(time * 1.7 + ship.phase) * 0.07;
    ship.world = _base!.unproject(screen, depth) + V3(0, bob, 0);
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

  V3 get _rocketAt {
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

  static const _rocketScale = 0.62;

  Rot get _rocketTurn {
    final roll =
        (still ? 0.0 : math.sin(time * 0.8) * 0.06) +
        (_aimYawGoal - _aimYaw) * 0.9;
    return Rot.euler(yaw: _aimYaw, pitch: _aimPitch, roll: roll);
  }

  double _aimYawGoal = 0;

  V3 get _nose => _rocketAt + _rocketTurn.forward * (1.05 * _rocketScale);

  V3 get _engine =>
      _rocketAt + _rocketTurn.apply(const V3(0, 0, 0.64 * _rocketScale));

  void _aim(double dt) {
    if (_base == null || ambient) return;
    final target = _sinceShot < 0.7 && _aimAt != null
        ? _aimAt!
        : _base!.unproject(_field.center, 9);
    final facing = Rot.facing(target - _rocketAt);
    _aimYawGoal = facing.yaw;
    final ease = 1 - math.exp(-dt * 12);
    _aimYaw += (facing.yaw - _aimYaw) * ease;
    _aimPitch += (facing.pitch - _aimPitch) * ease;

    // Exhaust, streaming back from the engine towards the learner.
    _exhaust += dt * 34;
    while (_exhaust >= 1) {
      _exhaust -= 1;
      final back = _rocketTurn.apply(const V3(0, 0, 1));
      _sparks.add(
        _Spark(
          at: _engine,
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
    ship.yaw += ship.spin * dt;
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
      ..world =
          _base!.unproject(at, ship.depth) +
          V3(0, math.sin(time * 1.2 + ship.phase) * 0.12, 0);
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
      _renderer.draw(
        Models.saucer(ship.variant),
        at: ship.world,
        turn:
            Rot.euler(
              pitch: 0.34 + _elevation(swayed, ship.world),
              roll: ship.bank,
            ) *
            Rot.euler(yaw: ship.yaw),
        scale: _shipScale,
        fog: 0.9,
      );
    }
    for (final ship in ships) {
      if (ship.delay > 0 || ship.exploded) continue;
      _paintShip(ship, swayed);
    }
    for (final shard in _shards) {
      final left = 1 - shard.age / shard.life;
      _renderer.draw(
        Models.shard(shard.variant),
        at: shard.at,
        turn: Rot.euler(
          yaw: shard.spin.x * shard.age,
          pitch: shard.spin.y * shard.age,
          roll: shard.spin.z * shard.age,
        ),
        scale: shard.size * (0.3 + 0.7 * left),
        glow: 0.2 * left,
        fog: 0.3,
      );
    }
    if (!ambient) {
      final bob = still ? 0.0 : math.sin(time * 1.3) * 0.035;
      _renderer.draw(
        Models.rocket,
        at: _rocketAt + V3(0, bob, 0),
        turn: _rocketTurn,
        scale: _rocketScale,
        fog: 0,
      );
    }
    _renderer.flush(canvas);
    facesDrawn += _renderer.drawn;

    for (final ship in ships) {
      if (ship.delay > 0 || ship.exploded) continue;
      _paintShipLight(canvas, swayed, ship);
    }
    if (!ambient) _paintEngine(canvas, swayed);
    _paintSparks(canvas, swayed);
    _paintLasers(canvas, swayed);
    _paintBursts(canvas, swayed);

    final drawn = [
      for (final ship in ships)
        if (ship.delay <= 0 && !ship.exploded) ship,
    ]..sort((a, b) => b.depth.compareTo(a.depth));
    for (final ship in drawn) {
      _paintLabel(canvas, swayed, ship);
    }
    _paintPopups(canvas, swayed);
    _paintVeil(canvas);
  }

  void _paintSky(Canvas canvas, Camera camera) {
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
        fog: 0.45,
      )
      ..draw(
        Models.rings(palette),
        at: at,
        turn: tilt,
        scale: radius,
        fog: 0.5,
      );
    final orbit = time * 0.09 + 1.2;
    _renderer.draw(
      Models.moon(palette),
      at:
          at +
          V3(
            math.cos(orbit) * radius * 2.6,
            math.sin(orbit) * radius * 0.5,
            math.sin(orbit) * radius * 2.6,
          ),
      turn: Rot.euler(yaw: time * 0.05),
      scale: radius * 0.16,
      fog: 0.45,
    );
    final centre = camera.project(at);
    if (centre == null) return null;
    return (centre, radius * camera.scaleAt(camera.depthOf(at)));
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

  void _paintShip(WordShip ship, Camera camera) {
    final wobble = ship.wobble * math.sin(time * 34) * 0.3;
    final tip = 0.34 + _elevation(camera, ship.world);
    final pulse = 0.5 + 0.5 * math.sin(time * 6);
    final (tint, tinted) = ship.flash > 0
        ? (const Rgb(1, 0.3, 0.38), ship.flash * 0.65)
        : ship.missed
        ? (const Rgb(0.42, 0.45, 0.55), 0.6)
        : ship.revealed || ship.hinted
        ? (const Rgb(1, 0.84, 0.35), 0.12 + 0.16 * pulse)
        : (null, 0.0);
    _renderer.draw(
      Models.saucer(ship.variant),
      at: ship.world,
      turn:
          Rot.euler(pitch: tip + wobble, roll: ship.bank + wobble * 0.6) *
          Rot.euler(yaw: ship.yaw),
      scale:
          _shipScale *
          (0.85 + 0.15 * Curves.easeOutBack.transform(ship.arrival)),
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
      _glow(
        canvas,
        at.translate(0, radius * 0.3),
        radius * 0.9,
        ShipColours.lights[ship.variant].color.withValues(alpha: 0.5),
        strength: fade,
      );
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
    final at = camera.project(_engine);
    if (at == null) return;
    final scale = camera.scaleAt(camera.depthOf(_engine));
    final flicker = still ? 1.0 : 0.85 + 0.15 * math.sin(time * 41);
    _glow(
      canvas,
      at,
      0.55 * scale * flicker,
      const Color(0xFFFF7A3D).withValues(alpha: 0.75),
    );
    _glow(
      canvas,
      at,
      0.22 * scale * flicker,
      const Color(0xFFFFF1C1),
    );
    if (_muzzle > 0) {
      final nose = camera.project(_nose);
      if (nose != null) {
        _glow(
          canvas,
          nose,
          0.5 * scale * _muzzle,
          palette.glow,
          strength: _muzzle,
        );
      }
    }
  }

  void _paintSparks(Canvas canvas, Camera camera) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round;
    for (final spark in _sparks) {
      final at = camera.project(spark.at);
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
    for (final laser in _lasers) {
      final target = laser.ship.world;
      final head = laser.from.lerp(target, laser.progress.clamp(0, 1));
      final tail = laser.from.lerp(
        target,
        (laser.progress - 0.4).clamp(0, 1),
      );
      final a = camera.project(tail);
      final b = camera.project(head);
      if (a == null || b == null) continue;
      final width = (camera.scaleAt(camera.depthOf(head)) * 0.12).clamp(
        3.0,
        14.0,
      );
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
