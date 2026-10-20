import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../core/numbers.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

const _whiteFill = [Colors.white, Colors.white];

/// Rod tip inside the fisherman sprite, as fractions of the sprite rect.
const _tipX = 0.19;
const _tipY = 0.01;

/// Above this tension the fish fights back and reeling slows down.
const _redZone = 0.82;

enum _Phase { ready, reeling, waiting, burst, done }

/// Ice fishing mini game: hold to reel in the bonus fish picked by Rust.
class FishingScreen extends StatefulWidget {
  const FishingScreen({super.key});

  @override
  State<FishingScreen> createState() => _FishingScreenState();
}

class _FishingScreenState extends State<FishingScreen> with SingleTickerProviderStateMixin {
  final _bridge = GameBridge.instance;
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  StreamSubscription<FishOutcome>? _line;
  Timer? _timeout;

  late final int _fishIndex = _bridge.state?.fishPending ?? 0;
  _Phase _phase = _Phase.ready;
  Duration _last = Duration.zero;
  double _t = 0;
  double _progress = 0;
  double _tension = 0.1;
  double _burst = 0;
  double _nextClick = 0;
  bool _holding = false;
  FishOutcome? _outcome;

  FishDef? get _fish {
    final list = _bridge.catalog?.fish ?? const <FishDef>[];
    final index = _outcome?.fish ?? _fishIndex;
    return index >= 0 && index < list.length ? list[index] : null;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _line = _bridge.catches.listen(_onCatch);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _line?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _t += dt;
    switch (_phase) {
      case _Phase.ready:
      case _Phase.reeling:
        _reel(dt);
      case _Phase.waiting:
        _tension += (0.95 - _tension) * math.min(1, dt * 6);
      case _Phase.burst:
        _burst += dt;
        _tension += (0.2 - _tension) * math.min(1, dt * 3);
        if (_burst >= 1.25) {
          HapticFeedback.heavyImpact();
          setState(() => _phase = _Phase.done);
        }
      case _Phase.done:
        _burst += dt;
    }
    _frame.value++;
  }

  void _reel(double dt) {
    if (_holding) {
      if (_phase == _Phase.ready) {
        setState(() => _phase = _Phase.reeling);
      }
      final pull = 0.56 + 0.28 * math.sin(_t * 2.1) + 0.14 * math.sin(_t * 5.3 + 1);
      _tension += (pull - _tension) * math.min(1, dt * 5);
      final rate = _tension > _redZone ? 0.06 : 0.24;
      _progress = math.min(1, _progress + rate * dt);
      if (_t >= _nextClick) {
        _nextClick = _t + (_tension > _redZone ? 0.12 : 0.22);
        HapticFeedback.selectionClick();
      }
    } else {
      _tension += (0.12 - _tension) * math.min(1, dt * 3);
      _progress = math.max(0, _progress - 0.05 * dt);
    }
    if (_progress >= 1 && _phase != _Phase.waiting) {
      HapticFeedback.heavyImpact();
      setState(() => _phase = _Phase.waiting);
      _bridge.reelIn();
      _timeout = Timer(const Duration(seconds: 4), () {
        if (mounted && _phase == _Phase.waiting) {
          setState(() {
            _phase = _Phase.reeling;
            _progress = 0.9;
          });
        }
      });
    }
  }

  void _onCatch(FishOutcome outcome) {
    _timeout?.cancel();
    if (!mounted) {
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _outcome = outcome;
      _phase = _Phase.burst;
      _burst = 0;
      _holding = false;
    });
    _bridge.publish();
  }

  void _hold(bool down) {
    if (_phase == _Phase.ready || _phase == _Phase.reeling) {
      setState(() => _holding = down);
    }
  }

  void _collect() {
    Navigator.of(context).pop(_outcome);
  }

  @override
  Widget build(BuildContext context) {
    final slot = _bridge.slot;
    final fish = _fish;
    final color = fish == null ? iceBlue : Color(fish.color);
    return PopScope(
      canPop: _phase == _Phase.done,
      child: Scaffold(
        backgroundColor: frostNight,
        body: LayoutBuilder(
          builder: (context, box) {
            final g = _Geometry(box.biggest, slot.fisherman);
            return Stack(
              fit: StackFit.expand,
              children: [
                AssetArt(A.values[slot.fishingBackground.clamp(0, A.values.length - 1)], alignment: Alignment.topCenter),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99041029), Color(0x11041029), Color(0x00041029)],
                      stops: [0, 0.3, 1],
                    ),
                  ),
                ),
                RepaintBoundary(child: CustomPaint(painter: _IcePainter(this, g, _frame))),
                const SnowLayer(count: 40),
                ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, child) => Positioned.fromRect(
                    rect: g.man.shift(Offset(g.shake(_t, _tension), 0)),
                    child: child!,
                  ),
                  child: Transform.flip(flipX: true, child: SpriteBox(slot.fisherman, fit: BoxFit.fill)),
                ),
                RepaintBoundary(child: CustomPaint(painter: _CatchPainter(this, g, _frame, fish?.sprite, color))),
                SafeArea(child: _overlay(fish, color)),
                if (_phase == _Phase.done) const CoinShower(count: 50),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _overlay(FishDef? fish, Color color) {
    final outcome = _outcome;
    return Column(
      children: [
        const SizedBox(height: 10),
        GoldText(tx(T.fishingBonus), size: 36),
        if (fish != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.black, 0.35)!, color, Color.lerp(color, Colors.black, 0.35)!]),
              border: Border.all(color: Colors.white70, width: 1.5),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 30, height: 30, child: SpriteBox(fish.sprite)),
                const SizedBox(width: 8),
                Text(fish.name, style: display(18)),
                const SizedBox(width: 10),
                Text(fish.prizes, style: display(13, color: goldLight)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: _phase == _Phase.waiting || _phase == _Phase.burst ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Pulse(amount: 0.08, child: GoldText(tx(T.fishOn), size: 34, colors: iceGradient, stroke: const Color(0xFF06204A))),
        ),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _phase == _Phase.done && outcome != null
              ? _CatchPanel(key: const ValueKey<int>(1), outcome: outcome, fish: fish, onCollect: _collect)
              : _ReelControls(
                  key: const ValueKey<int>(0),
                  state: this,
                  rod: _bridge.slot.rod,
                  enabled: _phase == _Phase.ready || _phase == _Phase.reeling,
                ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _Geometry {
  _Geometry(this.size, Sprite fisherman) {
    final h = size.height * 0.44;
    final w = h * fisherman.w / fisherman.h;
    man = Rect.fromLTWH(size.width * 0.01, size.height * 0.74 - h, w, h);
    tip = Offset(man.right - w * _tipX, man.top + h * _tipY);
    hole = Offset(size.width * 0.72, size.height * 0.71);
    holeRx = size.width * 0.19;
    holeRy = holeRx * 0.3;
    horizon = size.height * 0.5;
    perch = Offset(size.width * 0.52, size.height * 0.36);
  }

  final Size size;
  late final Rect man;
  late final Offset tip;
  late final Offset hole;
  late final double holeRx;
  late final double holeRy;
  late final double horizon;
  late final Offset perch;

  double shake(double t, double tension) => math.sin(t * 31) * 1.6 * tension;

  /// End of the flexible rod tip, bending towards the hole under tension.
  Offset bentTip(double t, double tension) {
    final s = Offset(shake(t, tension), 0);
    return tip + s + Offset(size.width * (0.05 + 0.07 * tension), -size.height * 0.045 + size.height * 0.085 * tension);
  }

  Offset bentControl(double t, double tension) => tip + Offset(shake(t, tension), -size.height * 0.07);
}

class _IcePainter extends CustomPainter {
  _IcePainter(this.s, this.g, Listenable repaint) : super(repaint: repaint);

  final _FishingScreenState s;
  final _Geometry g;

  @override
  void paint(Canvas canvas, Size size) {
    final ice = Rect.fromLTRB(0, g.horizon, size.width, size.height);
    canvas.drawRect(
      ice,
      Paint()
        ..shader = ui.Gradient.linear(ice.topCenter, ice.bottomCenter, [
          const Color(0x00D6ECFF),
          const Color(0xC8DDF0FF),
          const Color(0xF2EEF7FF),
          const Color(0xFFF8FCFF),
        ], [0, 0.12, 0.45, 1]),
    );

    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x667FB4E0);
    final rnd = math.Random(7);
    for (var i = 0; i < 9; i++) {
      var p = Offset(rnd.nextDouble() * size.width, g.horizon + size.height * (0.05 + rnd.nextDouble() * 0.4));
      final path = Path()..moveTo(p.dx, p.dy);
      for (var k = 0; k < 4; k++) {
        p += Offset((rnd.nextDouble() - 0.5) * size.width * 0.12, (rnd.nextDouble() - 0.3) * size.height * 0.03);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, crack);
    }

    final hole = g.hole;
    final outer = Rect.fromCenter(center: hole, width: g.holeRx * 2.5, height: g.holeRy * 2.7);
    canvas.drawOval(
      outer.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x553A6A9A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(outer.topCenter, outer.bottomCenter, [
          Colors.white,
          const Color(0xFFD5E9FA),
        ]),
    );
    final water = Rect.fromCenter(center: hole, width: g.holeRx * 2, height: g.holeRy * 2);
    canvas.drawOval(
      water,
      Paint()
        ..shader = ui.Gradient.radial(hole + Offset(0, g.holeRy * 0.3), g.holeRx, [
          const Color(0xFF1A6DA8),
          const Color(0xFF0B3A66),
          const Color(0xFF031428),
        ], [0, 0.55, 1]),
    );
    canvas.drawArc(
      water.deflate(2),
      math.pi * 1.05,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x8862A8DE),
    );

    final speed = s._holding || s._phase == _Phase.waiting ? 1.6 : 0.6;
    canvas.save();
    canvas.clipPath(Path()..addOval(water));
    for (var i = 0; i < 3; i++) {
      final k = ((s._t * speed * 0.5) + i / 3) % 1;
      final r = Rect.fromCenter(center: hole, width: g.holeRx * 2 * k, height: g.holeRy * 2 * k);
      canvas.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.35 * (1 - k)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IcePainter old) => false;
}

class _CatchPainter extends CustomPainter {
  _CatchPainter(this.s, this.g, Listenable repaint, this.sprite, this.color) : super(repaint: repaint);

  final _FishingScreenState s;
  final _Geometry g;
  final Sprite? sprite;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = s._t;
    final tension = s._tension;
    final tip = g.tip + Offset(g.shake(t, tension), 0);
    final end = g.bentTip(t, tension);
    final control = g.bentControl(t, tension);

    final rod = Path()
      ..moveTo(tip.dx, tip.dy + size.height * 0.02)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      rod,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5
        ..color = const Color(0xFF0D1C36),
    );
    canvas.drawPath(
      rod,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..color = const Color(0xFF3F7BD1),
    );
    canvas.drawCircle(end, 3, Paint()..color = const Color(0xFF9FD8FF));

    final burst = s._phase == _Phase.burst || s._phase == _Phase.done;
    final fishAt = burst ? _fishCenter(size) : g.hole;
    final mouth = burst ? fishAt - Offset(0, _fishSize(size) * 0.42) : g.hole;
    final mid = Offset.lerp(end, mouth, 0.5)!;
    final sag = (1 - tension) * size.height * 0.08;
    final buzz = math.sin(t * 47) * 2.2 * tension;
    final line = Path()
      ..moveTo(end.dx, end.dy)
      ..quadraticBezierTo(mid.dx + buzz, mid.dy + sag, mouth.dx, mouth.dy);
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    if (!burst) {
      return;
    }
    _splash(canvas, size);
    final sprite = this.sprite;
    if (sprite == null) {
      return;
    }
    final side = _fishSize(size);
    canvas.drawCircle(
      fishAt,
      side * 0.62,
      Paint()
        ..shader = ui.Gradient.radial(fishAt, side * 0.62, [
          color.withValues(alpha: 0.75),
          color.withValues(alpha: 0),
        ]),
    );
    final p = (s._burst / 1.0).clamp(0.0, 1.0);
    final wiggle = math.sin(s._burst * 18) * 0.28 * (1 - p) + math.sin(t * 3) * 0.05;
    canvas.save();
    canvas.translate(fishAt.dx, fishAt.dy);
    canvas.rotate(wiggle);
    paintSprite(canvas, sprite, Rect.fromCenter(center: Offset.zero, width: side, height: side));
    canvas.restore();
  }

  double _fishSize(Size size) {
    final p = Curves.easeOutBack.transform((s._burst / 1.0).clamp(0.0, 1.0));
    return size.width * (0.18 + 0.38 * p);
  }

  Offset _fishCenter(Size size) {
    final p = (s._burst / 1.0).clamp(0.0, 1.0);
    final e = Curves.easeOutCubic.transform(p);
    final arc = math.sin(p * math.pi) * size.height * 0.06;
    final base = Offset.lerp(g.hole, g.perch, e)!;
    final bob = s._phase == _Phase.done ? math.sin(s._t * 2.2) * 5 : 0.0;
    return base - Offset(0, arc) + Offset(0, bob);
  }

  void _splash(Canvas canvas, Size size) {
    final k = s._burst;
    if (k > 1.6) {
      return;
    }
    final rnd = math.Random(3);
    final paint = Paint();
    for (var i = 0; i < 26; i++) {
      final a = -math.pi * (0.15 + 0.7 * rnd.nextDouble());
      final v = size.height * (0.35 + 0.45 * rnd.nextDouble());
      final p = g.hole + Offset(math.cos(a) * v * k, math.sin(a) * v * k + size.height * 0.9 * k * k);
      final fade = (1 - k / 1.6).clamp(0.0, 1.0);
      paint.color = Color.lerp(const Color(0xFFB9ECFF), Colors.white, rnd.nextDouble())!.withValues(alpha: fade);
      canvas.drawCircle(p, 2.5 + rnd.nextDouble() * 4, paint);
    }
  }

  @override
  bool shouldRepaint(_CatchPainter old) => old.sprite != sprite;
}

class _ReelControls extends StatelessWidget {
  const _ReelControls({super.key, required this.state, required this.rod, required this.enabled});

  final _FishingScreenState state;
  final Sprite rod;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: state._frame,
            builder: (context, _, _) => Column(
              children: [
                _Meter(
                  value: state._progress,
                  height: 22,
                  colors: const [Color(0xFF8CF7FF), Color(0xFF2E8BFF)],
                  marker: Icons.phishing_rounded,
                ),
                const SizedBox(height: 10),
                _Meter(
                  value: state._tension,
                  height: 14,
                  colors: const [emerald, Color(0xFFFFD45A)],
                  danger: _redZone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tx(T.tension),
            style: display(14, color: iceWhite).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
          ),
          const SizedBox(height: 10),
          Listener(
            onPointerDown: (_) => state._hold(true),
            onPointerUp: (_) => state._hold(false),
            onPointerCancel: (_) => state._hold(false),
            child: Pulse(
              active: enabled && !state._holding,
              amount: 0.04,
              child: AnimatedScale(
                scale: state._holding ? 0.95 : 1,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: enabled
                          ? const [Color(0xFF8CE4FF), Color(0xFF2E8BFF), Color(0xFF0D3A8C)]
                          : const [Color(0xFF6D7F96), Color(0xFF3D4D63), Color(0xFF222D3D)],
                    ),
                    border: Border.all(color: const Color(0xFFFFF1B0), width: 2.5),
                    boxShadow: [
                      BoxShadow(color: iceBlue.withValues(alpha: state._holding ? 0.9 : 0.45), blurRadius: state._holding ? 26 : 14),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(angle: 0.6, child: SizedBox(width: 20, height: 56, child: SpriteBox(rod))),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          child: GoldText(tx(T.holdToReel), size: 26, colors: _whiteFill, stroke: const Color(0xFF06204A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.value, required this.height, required this.colors, this.danger, this.marker});

  final double value;
  final double height;
  final List<Color> colors;
  final double? danger;
  final IconData? marker;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final v = value.clamp(0.0, 1.0);
        final hot = danger != null && v > danger!;
        return SizedBox(
          height: height + (marker == null ? 0 : 10),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  color: const Color(0xCC050C22),
                  border: Border.all(color: iceEdge.withValues(alpha: 0.7), width: 1.5),
                ),
              ),
              if (danger != null)
                Positioned(
                  left: w * danger!,
                  right: 0,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(height / 2)),
                      color: ruby.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              Container(
                width: math.max(height, w * v),
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: LinearGradient(colors: hot ? const [ember, ruby] : colors),
                  boxShadow: [BoxShadow(color: (hot ? ruby : colors.last).withValues(alpha: 0.6), blurRadius: 8)],
                ),
              ),
              if (marker != null)
                Positioned(
                  left: (w * v - height).clamp(0.0, w - height * 1.6),
                  child: Icon(marker, color: Colors.white, size: height * 1.5, shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CatchPanel extends StatelessWidget {
  const _CatchPanel({super.key, required this.outcome, required this.fish, required this.onCollect});

  final FishOutcome outcome;
  final FishDef? fish;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final catalog = GameBridge.instance.catalog;
    final badges = catalog?.jackpotBadges ?? const <Sprite>[];
    final jackpot = outcome.jackpot;
    final color = fish == null ? gold : Color(fish!.color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FrostPanel(
        accent: color,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Lex.join([tx(T.youCaught), fish?.name ?? Lex.blank]), style: display(17, color: iceWhite)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (jackpot >= 0 && jackpot < badges.length) ...[
                  SizedBox(width: 52, height: 62, child: SpriteBox(badges[jackpot])),
                  const SizedBox(width: 8),
                ],
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: GoldText(outcome.plate, size: 52),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 32),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    child: TickingNumber(
                      value: outcome.coins,
                      duration: const Duration(milliseconds: 1600),
                      builder: (shown) => GoldText(grouped(shown), size: 36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Pulse(
              amount: 0.04,
              child: GlossyButton(
                width: 220,
                height: 56,
                onTap: onCollect,
                child: GoldText(tx(T.collect), size: 24, colors: _whiteFill, stroke: emeraldDeep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
