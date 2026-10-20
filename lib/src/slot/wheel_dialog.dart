import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import '../core/atlas.dart';
import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../core/numbers.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

Future<WheelOutcome?> showWheel(BuildContext context, {required bool daily, RoomDef? room}) {
  final def = daily ? GameBridge.instance.catalog?.dailyWheel : room?.wheel;
  if (def == null) {
    return Future<WheelOutcome?>.value();
  }
  return showOverlayDialog<WheelOutcome>(context, WheelDialog(daily: daily, def: def, room: room));
}

class WheelDialog extends StatefulWidget {
  const WheelDialog({super.key, required this.daily, required this.def, this.room});

  final bool daily;
  final WheelDef def;
  final RoomDef? room;

  @override
  State<WheelDialog> createState() => _WheelDialogState();
}

enum _Phase { idle, waiting, spinning, done }

class _WheelDialogState extends State<WheelDialog> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  _Phase _phase = _Phase.idle;
  double _angle = 0;
  double _from = 0;
  double _to = 0;
  int _lastTick = 0;
  WheelOutcome? _outcome;
  StreamSubscription<WheelOutcome>? _line;
  Timer? _timeout;
  final _random = math.Random();

  int get _segments => widget.def.labels.length;
  double get _segAngle => 2 * math.pi / _segments;
  double get _offset => widget.def.offsetDeg * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _idle.addListener(() {
      if (_phase == _Phase.idle || _phase == _Phase.waiting) {
        setState(() => _angle += _phase == _Phase.waiting ? 0.09 : 0.004);
      }
    });
    _spin.addListener(_onSpinTick);
    _line = GameBridge.instance.wheels.where((o) => o.daily == widget.daily).listen(_onOutcome);
  }

  @override
  void dispose() {
    _line?.cancel();
    _timeout?.cancel();
    _idle.dispose();
    _spin.dispose();
    _glow.dispose();
    super.dispose();
  }

  bool get _canSpin {
    final state = GameBridge.instance.state;
    if (state == null) {
      return false;
    }
    return widget.daily ? state.dailyReady : state.wheelPending;
  }

  void _request() {
    if (_phase != _Phase.idle || !_canSpin) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.waiting);
    GameBridge.instance.spinWheel(daily: widget.daily);
    _timeout = Timer(const Duration(seconds: 4), () {
      if (mounted && _phase == _Phase.waiting) {
        setState(() => _phase = _Phase.idle);
      }
    });
  }

  void _onOutcome(WheelOutcome outcome) {
    _timeout?.cancel();
    if (!mounted) {
      return;
    }
    final center = _offset + (outcome.segment + 0.5) * _segAngle;
    final jitter = (_random.nextDouble() - 0.5) * _segAngle * 0.6;
    final current = _angle % (2 * math.pi);
    var delta = (-center - jitter - current) % (2 * math.pi);
    if (delta < 0) {
      delta += 2 * math.pi;
    }
    _from = _angle;
    _to = _angle + delta + 2 * math.pi * 6;
    _lastTick = (_from / _segAngle).floor();
    setState(() {
      _outcome = outcome;
      _phase = _Phase.spinning;
    });
    _spin.forward(from: 0).whenComplete(() {
      if (!mounted) {
        return;
      }
      HapticFeedback.heavyImpact();
      setState(() => _phase = _Phase.done);
      GameBridge.instance.publish();
    });
  }

  void _onSpinTick() {
    final t = const Cubic(0.12, 0.8, 0.22, 1).transform(_spin.value);
    final angle = _from + (_to - _from) * t;
    final tick = (angle / _segAngle).floor();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    setState(() => _angle = angle);
  }

  void _close() {
    Navigator.of(context).pop(_outcome);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final wheelSize = math.min(media.width * 0.9, media.height * 0.46);
    final catalog = GameBridge.instance.catalog;
    final title = widget.daily ? tx(T.dailyWheel) : tx(T.bonusWheel);
    final outcome = _outcome;
    final accent = widget.room == null ? const Color(0xFFFF6BC4) : Color(widget.room!.accent);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, _) => CustomPaint(
              painter: SunburstPainter(turn: _angle * 0.08, color: accent.withValues(alpha: 0.5 + 0.3 * _glow.value)),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GoldText(title, size: 40),
                const SizedBox(height: 4),
                if (widget.room != null)
                  Text(widget.room!.title, style: display(18, color: accent))
                else
                  Text(tx(T.dailyText), style: display(15, color: iceWhite)),
                const SizedBox(height: 14),
                SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (context, _) => CustomPaint(
                      painter: _WheelPainter(
                        def: widget.def,
                        angle: _angle,
                        offset: _offset,
                        badges: catalog?.jackpotBadges ?? const [],
                        winner: _phase == _Phase.done ? outcome?.segment : null,
                        glow: _glow.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _phase == _Phase.done && outcome != null
                        ? _PrizePanel(key: const ValueKey<int>(1), outcome: outcome, onCollect: _close)
                        : _SpinControls(
                            key: const ValueKey<int>(0),
                            busy: _phase != _Phase.idle,
                            canSpin: _canSpin,
                            daily: widget.daily,
                            onSpin: _request,
                            onClose: widget.daily ? _close : null,
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.done && outcome != null && outcome.coins > 0) const CoinShower(count: 40),
        ],
      ),
    );
  }
}

class _SpinControls extends StatelessWidget {
  const _SpinControls({
    super.key,
    required this.busy,
    required this.canSpin,
    required this.daily,
    required this.onSpin,
    this.onClose,
  });

  final bool busy;
  final bool canSpin;
  final bool daily;
  final VoidCallback onSpin;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final state = GameBridge.instance.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pulse(
          active: !busy && canSpin,
          amount: 0.05,
          child: GlossyButton(
            width: 260,
            height: 62,
            colors: const [goldLight, gold, goldDeep],
            onTap: busy || !canSpin ? null : onSpin,
            child: GoldText(
              canSpin || busy ? tx(T.spinWheel) : (state?.dailyLabel ?? tx(T.spinWheel)),
              size: 24,
              colors: const [Colors.white, Colors.white],
              stroke: const Color(0xFF7A3B00),
            ),
          ),
        ),
        if (onClose != null && !busy)
          TextButton(
            onPressed: onClose,
            child: Text(tx(T.close), style: display(17, color: iceEdge)),
          ),
      ],
    );
  }
}

class _PrizePanel extends StatelessWidget {
  const _PrizePanel({super.key, required this.outcome, required this.onCollect});

  final WheelOutcome outcome;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final badges = GameBridge.instance.catalog?.jackpotBadges ?? const <Sprite>[];
    final jackpot = outcome.jackpot;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (jackpot >= 0 && jackpot < badges.length)
              SizedBox(width: 54, height: 64, child: SpriteBox(badges[jackpot]))
            else if (outcome.freeSpins > 0)
              const Icon(Icons.auto_awesome_rounded, color: iceBlue, size: 40)
            else
              const CoinIcon(size: 40),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                child: outcome.coins > 0
                    ? TickingNumber(
                        value: outcome.coins,
                        duration: const Duration(milliseconds: 1400),
                        builder: (shown) => GoldText(grouped(shown), size: 44),
                      )
                    : GoldText(outcome.headline, size: 40, colors: iceGradient, stroke: const Color(0xFF06204A)),
              ),
            ),
          ],
        ),
        if (outcome.coins > 0) Text(outcome.headline, style: display(16, color: iceWhite)),
        const SizedBox(height: 12),
        Pulse(
          amount: 0.04,
          child: GlossyButton(
            width: 220,
            height: 56,
            onTap: onCollect,
            child: GoldText(tx(T.collect), size: 24, colors: const [Colors.white, Colors.white], stroke: emeraldDeep),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.def,
    required this.angle,
    required this.offset,
    required this.badges,
    required this.winner,
    required this.glow,
  });

  final WheelDef def;
  final double angle;
  final double offset;
  final List<Sprite> badges;
  final int? winner;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final image = Atlas.at(def.asset);
    if (image == null) {
      return;
    }
    final center = size.center(Offset.zero);
    final side = size.shortestSide;
    final n = def.labels.length;
    final seg = 2 * math.pi / n;
    final rim = def.rim;

    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = math.min(side / iw, side / ih);
    final width = iw * scale;
    final src = Rect.fromLTWH(0, 0, iw, ih);
    final dst = Rect.fromLTWH(
      center.dx - rim.hubX * iw * scale,
      center.dy - rim.hubY * ih * scale,
      width,
      ih * scale,
    );
    final disc = rim.disc * width;
    final art = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawCircle(
      center,
      side * 0.47,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: disc)));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawImageRect(image, src, dst.shift(-center), art);

    final radius = disc * 0.64;
    for (var i = 0; i < n; i++) {
      final a = offset + (i + 0.5) * seg;
      canvas.save();
      canvas.rotate(a);
      final kind = i < def.kinds.length ? def.kinds[i] : 0;
      if (kind >= 2 && kind - 2 < badges.length) {
        final h = side * 0.15;
        paintSprite(canvas, badges[kind - 2], Rect.fromCenter(center: Offset(0, -radius), width: h * 0.82, height: h));
      } else {
        canvas.rotate(-math.pi / 2);
        _label(canvas, def.labels[i], Color(i < def.colors.length ? def.colors[i] : 0xFFFFFFFF), side, radius);
      }
      canvas.restore();
    }
    canvas.restore();

    final win = winner;
    if (win != null) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: disc), -math.pi / 2 - seg / 2, seg, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(center, disc, [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.25 + 0.3 * glow),
          ]),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = goldLight.withValues(alpha: 0.6 + 0.4 * glow),
      );
    }

    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(dst.inflate(2))
        ..addOval(Rect.fromCircle(center: center, radius: disc)),
    );
    canvas.drawImageRect(image, src, dst, art);
    canvas.restore();

    canvas.save();
    canvas.clipPath(
      Path()
        ..moveTo(center.dx - rim.pointerHalf * width, center.dy - rim.pointerTop * width)
        ..lineTo(center.dx + rim.pointerHalf * width, center.dy - rim.pointerTop * width)
        ..lineTo(center.dx, center.dy - rim.pointerTip * width)
        ..close(),
    );
    canvas.drawImageRect(image, src, dst, art);
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Color color, double side, double radius) {
    final fontSize = side * 0.058;
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.22
            ..color = const Color(0xFF1A0A2E),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(radius - fill.width / 2, -fill.height / 2);
    stroke.paint(canvas, at);
    fill.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => true;
}
