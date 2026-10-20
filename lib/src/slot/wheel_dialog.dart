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

const _whiteFill = [Colors.white, Colors.white];

/// Bonus wheel triggered by 3+ scatters.
Future<WheelOutcome?> showBonusWheel(BuildContext context) {
  final catalog = GameBridge.instance.catalog;
  if (catalog == null) {
    return Future<WheelOutcome?>.value();
  }
  return showOverlayDialog<WheelOutcome>(context, BonusWheelDialog(def: catalog.wheel, fish: catalog.fish));
}

class BonusWheelDialog extends StatefulWidget {
  const BonusWheelDialog({super.key, required this.def, required this.fish});

  final WheelDef def;
  final List<FishDef> fish;

  @override
  State<BonusWheelDialog> createState() => _BonusWheelDialogState();
}

enum _Phase { idle, waiting, spinning, done }

class _BonusWheelDialogState extends State<BonusWheelDialog> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 6200));
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

  @override
  void initState() {
    super.initState();
    _idle.addListener(() {
      if (_phase == _Phase.idle || _phase == _Phase.waiting) {
        setState(() => _angle += _phase == _Phase.waiting ? 0.09 : 0.004);
      }
    });
    _spin.addListener(_onSpinTick);
    _line = GameBridge.instance.wheels.listen(_onOutcome);
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

  void _request() {
    if (_phase != _Phase.idle || !(GameBridge.instance.state?.wheelPending ?? false)) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.waiting);
    GameBridge.instance.spinWheel();
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
    final center = (outcome.segment + 0.5) * _segAngle;
    final jitter = (_random.nextDouble() - 0.5) * _segAngle * 0.6;
    final current = _angle % (2 * math.pi);
    var delta = (-center - jitter - current) % (2 * math.pi);
    if (delta < 0) {
      delta += 2 * math.pi;
    }
    _from = _angle;
    _to = _angle + delta + 2 * math.pi * 7;
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
    final wheelSize = math.min(media.width * 0.98, media.height * 0.52);
    final outcome = _outcome;
    final fishIndex = outcome?.fish ?? -1;
    final caught = _phase == _Phase.done && fishIndex >= 0 && fishIndex < widget.fish.length ? widget.fish[fishIndex] : null;
    final accent = caught == null ? iceBlue : Color(caught.color);

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
                GoldText(tx(T.bonusWheel), size: 40),
                Text(tx(T.iceFishing), style: display(18, color: iceEdge)),
                const SizedBox(height: 6),
                SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (context, _) => CustomPaint(
                      painter: _IceWheelPainter(
                        def: widget.def,
                        fish: widget.fish,
                        angle: _angle,
                        winner: _phase == _Phase.done ? outcome?.segment : null,
                        glow: _glow.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _phase == _Phase.done && outcome != null
                        ? _PrizePanel(key: const ValueKey<int>(1), outcome: outcome, fish: caught, onCollect: _close)
                        : _SpinButton(key: const ValueKey<int>(0), busy: _phase != _Phase.idle, onSpin: _request),
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

class _SpinButton extends StatelessWidget {
  const _SpinButton({super.key, required this.busy, required this.onSpin});

  final bool busy;
  final VoidCallback onSpin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pulse(
        active: !busy,
        amount: 0.05,
        child: GlossyButton(
          width: 260,
          height: 62,
          colors: const [goldLight, gold, goldDeep],
          onTap: busy ? null : onSpin,
          child: GoldText(tx(T.spinWheel), size: 24, colors: _whiteFill, stroke: const Color(0xFF7A3B00)),
        ),
      ),
    );
  }
}

class _PrizePanel extends StatelessWidget {
  const _PrizePanel({super.key, required this.outcome, required this.fish, required this.onCollect});

  final WheelOutcome outcome;
  final FishDef? fish;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final fish = this.fish;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fish != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 56, height: 56, child: SpriteBox(fish.sprite)),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  child: GoldText(
                    fish.name,
                    size: 40,
                    colors: [Colors.white, Color.lerp(Color(fish.color), Colors.white, 0.3)!, Color(fish.color)],
                    stroke: const Color(0xFF06204A),
                  ),
                ),
              ),
            ],
          ),
          Text(fish.prizes, style: display(16, color: goldLight)),
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 40),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  child: TickingNumber(
                    value: outcome.coins,
                    duration: const Duration(milliseconds: 1400),
                    builder: (shown) => GoldText(grouped(shown), size: 44),
                  ),
                ),
              ),
            ],
          ),
          Text(outcome.headline, style: display(16, color: iceWhite)),
        ],
        const SizedBox(height: 12),
        Pulse(
          amount: 0.04,
          child: GlossyButton(
            width: 240,
            height: 56,
            colors: fish == null
                ? const [Color(0xFF7DF29B), emerald, emeraldDeep]
                : const [Color(0xFF8CE4FF), Color(0xFF2E8BFF), Color(0xFF0D3A8C)],
            onTap: onCollect,
            child: GoldText(
              fish == null ? tx(T.collect) : tx(T.fishingBonus),
              size: 22,
              colors: _whiteFill,
              stroke: fish == null ? emeraldDeep : const Color(0xFF06204A),
            ),
          ),
        ),
      ],
    );
  }
}

class _IceWheelPainter extends CustomPainter {
  _IceWheelPainter({
    required this.def,
    required this.fish,
    required this.angle,
    required this.winner,
    required this.glow,
  });

  final WheelDef def;
  final List<FishDef> fish;
  final double angle;
  final int? winner;
  final double glow;

  static const _ink = Color(0xFF14304D);
  static const _stroke = Color(0xFF0A1A2E);

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
    final dst = Rect.fromLTWH(center.dx - rim.hubX * iw * scale, center.dy - rim.hubY * ih * scale, width, ih * scale);
    final disc = rim.disc * width;
    final art = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawCircle(
      center,
      disc * 1.3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: disc * 1.02)));
    canvas.rotate(angle);
    _disc(canvas, disc * 1.02, n, seg);
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
            Colors.white.withValues(alpha: 0.3 + 0.35 * glow),
          ]),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = goldLight.withValues(alpha: 0.6 + 0.4 * glow),
      );
    }

    _hub(canvas, center, disc * 0.27);

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

  /// Draws the spinning face around the origin; segment 0 is centred under
  /// the pointer when [angle] is minus half a segment.
  void _disc(Canvas canvas, double r, int n, double seg) {
    final light = Color(def.light);
    final dark = Color(def.dark);
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * seg;
      final fishIndex = i < def.fish.length ? def.fish[i] : -1;
      final isFish = fishIndex >= 0 && fishIndex < fish.length;
      final base = isFish ? Color(fish[fishIndex].color) : (i.isEven ? light : dark);
      final path = Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), start, seg, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, r, [
            Color.lerp(base, Colors.black, 0.25)!,
            base,
            Color.lerp(base, Colors.white, isFish ? 0.18 : 0.08)!,
          ], [0.25, 0.7, 1]),
      );
    }

    final divider = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1, r * 0.008);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * seg;
      canvas.drawLine(Offset(math.cos(a), math.sin(a)) * r * 0.26, Offset(math.cos(a), math.sin(a)) * r, divider);
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * r * 0.955,
        r * 0.018,
        Paint()..color = const Color(0xFFF4FAFF),
      );
    }

    for (var i = 0; i < n; i++) {
      final mid = -math.pi / 2 + (i + 0.5) * seg;
      final fishIndex = i < def.fish.length ? def.fish[i] : -1;
      canvas.save();
      canvas.rotate(mid);
      if (fishIndex >= 0 && fishIndex < fish.length) {
        final h = r * 0.2;
        canvas.save();
        canvas.translate(r * 0.83, 0);
        canvas.rotate(math.pi / 2);
        paintSprite(canvas, fish[fishIndex].sprite, Rect.fromCenter(center: Offset.zero, width: h, height: h));
        canvas.restore();
        _radial(canvas, def.labels[i], Colors.white, r * 0.31, r * 0.4, r * 0.085, stroke: true);
      } else {
        final ink = i.isEven ? _ink : Colors.white;
        _radial(canvas, def.labels[i], ink, r * 0.52, r * 0.42, r * 0.14, stroke: !i.isEven);
      }
      canvas.restore();
    }
  }

  /// Text laid along the +x axis from [from], fitted to [maxLength].
  void _radial(Canvas canvas, String text, Color color, double from, double maxLength, double fontSize, {required bool stroke}) {
    final probe = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = probe.width > maxLength ? fontSize * maxLength / probe.width : fontSize;
    final fill = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(from + (maxLength - fill.width) / 2, -fill.height / 2);
    if (stroke) {
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            letterSpacing: 0.5,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.2
              ..color = _stroke,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, at);
    }
    fill.paint(canvas, at);
  }

  void _hub(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(
      center,
      r * 1.12,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      center,
      r * 1.08,
      Paint()
        ..shader = ui.Gradient.linear(center - Offset(r, r), center + Offset(r, r), [
          const Color(0xFFF2FAFF),
          const Color(0xFF8FB4D6),
          const Color(0xFFE6F2FF),
        ], [0, 0.5, 1]),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(center - Offset(r * 0.3, r * 0.4), r * 1.3, [
          const Color(0xFF3F8FE0),
          const Color(0xFF123E7A),
          const Color(0xFF071C3D),
        ], [0, 0.6, 1]),
    );
    final words = def.hubLabel.split(tx(T.space));
    final lines = words.length >= 2 ? [words.first, words.sublist(1).join(tx(T.space))] : words;
    final fontSize = r * 0.42;
    final painters = [
      for (final line in lines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.white,
              height: 1,
              shadows: const [Shadow(color: Color(0xFF02101F), blurRadius: 4, offset: Offset(0, 2))],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final widest = painters.fold<double>(0, (w, p) => math.max(w, p.width));
    final fit = widest > r * 1.6 ? r * 1.6 / widest : 1.0;
    final total = painters.fold<double>(0, (h, p) => h + p.height) * fit;
    canvas.save();
    canvas.translate(center.dx, center.dy - total / 2);
    canvas.scale(fit);
    var y = 0.0;
    for (final p in painters) {
      p.paint(canvas, Offset(-p.width / 2, y));
      y += p.height;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IceWheelPainter old) => true;
}
