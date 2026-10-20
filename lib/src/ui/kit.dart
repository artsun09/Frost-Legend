import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import '../core/atlas.dart';
import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import 'palette.dart';

/// Draws a sprite cut out of a sprite sheet.
class SpriteBox extends StatelessWidget {
  const SpriteBox(this.sprite, {super.key, this.fit = BoxFit.contain, this.alignment = Alignment.center});

  final Sprite sprite;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SpritePainter(sprite, fit: fit, alignment: alignment),
      size: Size.infinite,
    );
  }
}

class SpritePainter extends CustomPainter {
  SpritePainter(this.sprite, {this.fit = BoxFit.contain, this.alignment = Alignment.center});

  final Sprite sprite;
  final BoxFit fit;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    paintSprite(canvas, sprite, Offset.zero & size, fit: fit, alignment: alignment);
  }

  @override
  bool shouldRepaint(SpritePainter old) => old.sprite != sprite || old.fit != fit;
}

void paintSprite(
  Canvas canvas,
  Sprite sprite,
  Rect dst, {
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
  Paint? paint,
}) {
  final image = Atlas.forSprite(sprite);
  if (image == null) {
    return;
  }
  final src = Rect.fromLTWH(sprite.x, sprite.y, sprite.w, sprite.h);
  final sizes = applyBoxFit(fit, src.size, dst.size);
  final inSrc = alignment.inscribe(sizes.source, src);
  final inDst = alignment.inscribe(sizes.destination, dst);
  canvas.drawImageRect(image, inSrc, inDst, paint ?? (Paint()..filterQuality = FilterQuality.medium));
}

/// Full image asset, drawn with the given fit.
class AssetArt extends StatelessWidget {
  const AssetArt(this.asset, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.color, this.blend});

  final A asset;
  final BoxFit fit;
  final Alignment alignment;
  final Color? color;
  final BlendMode? blend;

  @override
  Widget build(BuildContext context) {
    final image = Atlas.of(asset);
    if (image == null) {
      return const SizedBox.shrink();
    }
    final crop = Atlas.opaque(asset);
    if (crop != null) {
      return SizedBox.expand(
        child: CustomPaint(painter: _CroppedArtPainter(image, crop, fit, alignment)),
      );
    }
    return RawImage(
      image: image,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: blend,
      filterQuality: FilterQuality.medium,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _CroppedArtPainter extends CustomPainter {
  _CroppedArtPainter(this.image, this.crop, this.fit, this.alignment);

  final ui.Image image;
  final Rect crop;
  final BoxFit fit;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(fit, crop.size, size);
    final src = alignment.inscribe(fitted.source, crop);
    final dst = alignment.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_CroppedArtPainter old) => old.image != image || old.crop != crop || old.fit != fit;
}

/// Bold display text with a dark outline and a gradient fill.
class GoldText extends StatelessWidget {
  const GoldText(
    this.text, {
    super.key,
    required this.size,
    this.colors = goldGradient,
    this.stroke = const Color(0xFF4A2300),
    this.strokeWidth,
    this.align = TextAlign.center,
    this.maxLines = 1,
  });

  final String text;
  final double size;
  final List<Color> colors;
  final Color stroke;
  final double? strokeWidth;
  final TextAlign align;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: size, height: 1.05, letterSpacing: size * 0.03);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? math.max(2, size * 0.14)
      ..strokeJoin = StrokeJoin.round
      ..color = stroke;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          overflow: TextOverflow.visible,
          softWrap: maxLines > 1,
          style: base.copyWith(
            foreground: outline,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: align,
            maxLines: maxLines,
            overflow: TextOverflow.visible,
            softWrap: maxLines > 1,
            style: base.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Glossy pill button with a press-down bounce.
class GlossyButton extends StatefulWidget {
  const GlossyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.colors = const [Color(0xFF7DF29B), emerald, emeraldDeep],
    this.height = 52,
    this.width,
    this.radius,
    this.border = const Color(0xFFFFF1B0),
  });

  final Widget child;
  final VoidCallback? onTap;
  final List<Color> colors;
  final double height;
  final double? width;
  final double? radius;
  final Color border;

  @override
  State<GlossyButton> createState() => _GlossyButtonState();
}

class _GlossyButtonState extends State<GlossyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final radius = BorderRadius.circular(widget.radius ?? widget.height / 2);
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: widget.border, width: 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.colors,
              ),
              boxShadow: [
                BoxShadow(color: widget.colors.last.withValues(alpha: 0.6), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  alignment: Alignment.center,
                  fit: constraints.hasBoundedWidth ? StackFit.expand : StackFit.loose,
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.48,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0.05)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: constraints.hasBoundedWidth ? Center(child: widget.child) : widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button used in top bars.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.size = 44});

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GlossyButton(
      onTap: onTap,
      height: size,
      width: size,
      colors: const [Color(0xFF5CC8FF), Color(0xFF1E6FD9), Color(0xFF0D3A8C)],
      border: iceEdge,
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: CoinPainter()));
  }
}

class CoinPainter extends CustomPainter {
  CoinPainter({this.turn = 0});

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    paintCoin(canvas, size.center(Offset.zero), size.shortestSide / 2, turn);
  }

  @override
  bool shouldRepaint(CoinPainter old) => old.turn != turn;
}

void paintCoin(Canvas canvas, Offset center, double radius, double turn) {
  final squash = math.cos(turn).abs().clamp(0.15, 1.0);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(squash, 1);
  final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
  canvas.drawCircle(
    Offset.zero,
    radius,
    Paint()..shader = const RadialGradient(colors: [goldLight, gold, goldDeep], stops: [0, 0.55, 1]).createShader(rect),
  );
  canvas.drawCircle(
    Offset.zero,
    radius * 0.78,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..color = const Color(0xFFB86A0A),
  );
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius * 0.5 : radius * 0.22;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
  }
  star.close();
  canvas.drawPath(star, Paint()..color = const Color(0xFFFFF7D0));
  canvas.restore();
}

/// Dark translucent capsule for HUD values.
class HudPill extends StatelessWidget {
  const HudPill({super.key, required this.child, this.height = 40, this.padding});

  final Widget child;
  final double height;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6143270), Color(0xE6071637)],
        ),
        border: Border.all(color: iceEdge.withValues(alpha: 0.7), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: child,
    );
  }
}

/// Integer that animates towards its new value.
class TickingNumber extends StatefulWidget {
  const TickingNumber({super.key, required this.value, required this.builder, this.duration = const Duration(milliseconds: 700)});

  final int value;
  final Widget Function(int shown) builder;
  final Duration duration;

  @override
  State<TickingNumber> createState() => _TickingNumberState();
}

class _TickingNumberState extends State<TickingNumber> {
  late int _from = widget.value;

  @override
  void didUpdateWidget(TickingNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(widget.value),
      tween: Tween(begin: 0, end: 1),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => widget.builder((_from + (widget.value - _from) * t).round()),
    );
  }
}

/// Gently pulsing scale, used to draw the eye.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.amount = 0.06, this.period = const Duration(milliseconds: 1100), this.active = true});

  final Widget child;
  final double amount;
  final Duration period;
  final bool active;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(
        scale: 1 + widget.amount * Curves.easeInOut.transform(_c.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Falling snow drawn over any screen.
class SnowLayer extends StatefulWidget {
  const SnowLayer({super.key, this.count = 70, this.color = Colors.white});

  final int count;
  final Color color;

  @override
  State<SnowLayer> createState() => _SnowLayerState();
}

class _Flake {
  _Flake(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        size = 0.8 + r.nextDouble() * 2.6,
        speed = 0.02 + r.nextDouble() * 0.05,
        sway = r.nextDouble() * math.pi * 2;

  double x;
  double y;
  final double size;
  final double speed;
  double sway;
}

class _SnowLayerState extends State<SnowLayer> with SingleTickerProviderStateMixin {
  final _random = math.Random();
  late final List<_Flake> _flakes = List.generate(widget.count, (_) => _Flake(_random));
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _frame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      for (final f in _flakes) {
        f.y += f.speed * dt;
        f.sway += dt * 1.3;
        f.x += math.sin(f.sway) * 0.0006;
        if (f.y > 1.02) {
          f.y = -0.02;
          f.x = _random.nextDouble();
        }
      }
      _frame.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SnowPainter(_flakes, widget.color, _frame),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SnowPainter extends CustomPainter {
  _SnowPainter(this.flakes, this.color, Listenable repaint) : super(repaint: repaint);

  final List<_Flake> flakes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final f in flakes) {
      paint.color = color.withValues(alpha: 0.35 + f.size / 6);
      canvas.drawCircle(Offset(f.x * size.width, f.y * size.height), f.size, paint);
    }
  }

  @override
  bool shouldRepaint(_SnowPainter old) => false;
}

/// Hosts short messages coming from Rust on top of the app.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  StreamSubscription<String>? _line;
  String? _text;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _line = GameBridge.instance.toasts.listen(show);
  }

  void show(String text) {
    _hide?.cancel();
    setState(() => _text = text);
    _hide = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _text = null);
      }
    });
  }

  @override
  void dispose() {
    _line?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 24,
          right: 24,
          top: MediaQuery.paddingOf(context).top + 64,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: text == null
                  ? const SizedBox.shrink()
                  : Material(
                      key: ValueKey<String>(text),
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xEE0B1E46),
                          border: Border.all(color: gold, width: 1.5),
                          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 12)],
                        ),
                        child: Text(text, textAlign: TextAlign.center, style: display(16, color: goldLight)),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Framed dialog panel shared by popups.
class FrostPanel extends StatelessWidget {
  const FrostPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.accent = iceEdge});

  final Widget child;
  final EdgeInsets padding;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2163C82), Color(0xF20A1A44), Color(0xF2050C22)],
        ),
        border: Border.all(color: accent, width: 2.5),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 24),
          const BoxShadow(color: Color(0xAA000000), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

/// Radiating light rays behind prizes.
class SunburstPainter extends CustomPainter {
  SunburstPainter({required this.turn, required this.color});

  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide * 0.75;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turn);
    final paint = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, radius, [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]);
    const rays = 16;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - 0.09) * radius, math.sin(a - 0.09) * radius)
        ..lineTo(math.cos(a + 0.09) * radius, math.sin(a + 0.09) * radius)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SunburstPainter old) => old.turn != turn;
}

/// Shower of spinning coins for celebrations.
class CoinShower extends StatefulWidget {
  const CoinShower({super.key, this.count = 46});

  final int count;

  @override
  State<CoinShower> createState() => _CoinShowerState();
}

class _Coin {
  _Coin(math.Random r)
      : x = r.nextDouble(),
        y = -r.nextDouble() * 1.2,
        vy = 0.25 + r.nextDouble() * 0.35,
        vx = (r.nextDouble() - 0.5) * 0.08,
        size = 9 + r.nextDouble() * 12,
        turn = r.nextDouble() * math.pi,
        spin = 4 + r.nextDouble() * 6;

  double x;
  double y;
  final double vy;
  final double vx;
  final double size;
  double turn;
  final double spin;
}

class _CoinShowerState extends State<CoinShower> with SingleTickerProviderStateMixin {
  final _random = math.Random();
  late final List<_Coin> _coins = List.generate(widget.count, (_) => _Coin(_random));
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _frame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      for (final c in _coins) {
        c.y += c.vy * dt;
        c.x += c.vx * dt;
        c.turn += c.spin * dt;
        if (c.y > 1.1) {
          c.y = -0.1;
          c.x = _random.nextDouble();
        }
      }
      _frame.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CoinShowerPainter(_coins, _frame), size: Size.infinite),
    );
  }
}

class _CoinShowerPainter extends CustomPainter {
  _CoinShowerPainter(this.coins, Listenable repaint) : super(repaint: repaint);

  final List<_Coin> coins;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      paintCoin(canvas, Offset(c.x * size.width, c.y * size.height), c.size, c.turn);
    }
  }

  @override
  bool shouldRepaint(_CoinShowerPainter old) => false;
}

Route<R> fadeRoute<R>(Widget page) {
  return PageRouteBuilder<R>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.06, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

Future<R?> showOverlayDialog<R>(BuildContext context, Widget child, {bool dismissible = false}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: tx(T.close),
    barrierColor: const Color(0xB3020814),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, a, b) => child,
    transitionBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}
