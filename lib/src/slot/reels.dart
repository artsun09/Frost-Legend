import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import '../core/numbers.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

const reelCount = 5;
const rowCount = 3;

const _kindWild = 1;
const _kindScatter = 2;

class ReelBoardController {
  _ReelBoardState? _state;

  void start() => _state?._start();

  Future<void> land(SpinOutcome outcome, {bool turbo = false}) =>
      _state?._land(outcome, turbo: turbo) ?? Future<void>.value();

  Future<void> abort() => _state?._abort() ?? Future<void>.value();

  void present(SpinOutcome outcome) => _state?._present(outcome);

  void clear() => _state?._clear();
}

class _Reel {
  double pos = 0;
  double speed = 0;
  bool spinning = false;
  bool stopping = false;
  bool teasing = false;
  double stopFrom = 0;
  double stopTo = 0;
  double stopElapsed = 0;
  double stopDuration = 1;
  final Map<int, int> fixed = {};
  Completer<void>? landed;
}

/// Ease-out with a small overshoot so reels settle with a soft bounce.
class _LandCurve extends Curve {
  const _LandCurve();

  static const _s = 0.85;

  @override
  double transformInternal(double t) {
    final u = t - 1;
    return 1 + (_s + 1) * u * u * u + _s * u * u;
  }
}

class ReelBoard extends StatefulWidget {
  const ReelBoard({super.key, required this.slot, required this.paylines, required this.controller});

  final SlotDef slot;
  final List<int> paylines;
  final ReelBoardController controller;

  @override
  State<ReelBoard> createState() => _ReelBoardState();
}

class _ReelBoardState extends State<ReelBoard> with SingleTickerProviderStateMixin {
  static const _maxSpeed = 24.0;
  static const _accel = 90.0;

  final List<_Reel> _reels = List.generate(reelCount, (_) => _Reel());
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _clock = 0;

  List<int> _values = List.filled(reelCount * rowCount, 0);
  List<LineWin> _wins = const [];
  List<int> _scatters = const [];
  List<int> _expanded = const [];
  double _winsSince = 0;
  late List<int> _filler;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    final symbols = widget.slot.symbols;
    _filler = [
      for (var i = 0; i < symbols.length; i++)
        if (symbols[i].kind != _kindScatter) ...[i, if (symbols[i].kind == 0 && i < symbols.length / 2) i],
    ];
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(ReelBoard old) {
    super.didUpdateWidget(old);
    widget.controller._state = this;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    for (final reel in _reels) {
      if (reel.landed != null && !reel.landed!.isCompleted) {
        reel.landed!.complete();
      }
    }
    super.dispose();
  }

  int symbolAt(int reel, int k) {
    final fixed = _reels[reel].fixed[k];
    if (fixed != null) {
      return fixed;
    }
    var h = k * 0x9E3779B1 + reel * 0x85EBCA77 + 0x2545F491;
    h ^= h >> 15;
    h = (h * 0x2C1B3C6D) & 0x7fffffff;
    h ^= h >> 12;
    return _filler[h % _filler.length];
  }

  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _clock += dt;
    for (final reel in _reels) {
      if (!reel.spinning) {
        continue;
      }
      if (reel.stopping) {
        reel.stopElapsed += dt;
        final t = (reel.stopElapsed / reel.stopDuration).clamp(0.0, 1.0);
        reel.pos = reel.stopFrom + (reel.stopTo - reel.stopFrom) * const _LandCurve().transform(t);
        if (t >= 1) {
          reel.pos = reel.stopTo;
          reel.spinning = false;
          reel.stopping = false;
          reel.teasing = false;
          reel.speed = 0;
          HapticFeedback.lightImpact();
          reel.landed?.complete();
          reel.landed = null;
        }
      } else {
        final target = reel.teasing ? _maxSpeed * 0.7 : _maxSpeed;
        reel.speed = math.min(target, reel.speed + _accel * dt);
        reel.pos -= reel.speed * dt;
      }
    }
    _frame.value++;
  }

  void _start() {
    _clear();
    _values = List.filled(reelCount * rowCount, 0);
    for (var i = 0; i < reelCount; i++) {
      final reel = _reels[i];
      reel.fixed.removeWhere((k, _) => k > reel.pos + 6);
      reel.spinning = true;
      reel.stopping = false;
      reel.teasing = false;
      reel.speed = -4.5 - i * 0.6;
      reel.landed?.complete();
      reel.landed = null;
    }
  }

  Future<void> _land(SpinOutcome outcome, {required bool turbo}) async {
    final grid = outcome.grid;
    if (grid.length != reelCount * rowCount) {
      return _abort();
    }
    final scatter = widget.slot.symbols.indexWhere((s) => s.kind == _kindScatter);
    var scattersSoFar = 0;
    await Future<void>.delayed(Duration(milliseconds: turbo ? 120 : 320));
    for (var i = 0; i < reelCount; i++) {
      if (!mounted) {
        return;
      }
      final reel = _reels[i];
      final tease = scattersSoFar >= 2;
      if (tease) {
        reel.teasing = true;
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }
      _settle(reel, [for (var row = 0; row < rowCount; row++) grid[i * rowCount + row]], distance: tease ? 8 : 5);
      scattersSoFar += [for (var row = 0; row < rowCount; row++) grid[i * rowCount + row]].where((s) => s == scatter).length;
      if (i < reelCount - 1) {
        await Future<void>.delayed(Duration(milliseconds: turbo ? 70 : 160));
      }
    }
    await Future.wait(_reels.map((r) => r.landed?.future ?? Future<void>.value()));
    _values = List.of(outcome.cellValues.length == reelCount * rowCount ? outcome.cellValues : _values);
    _expanded = outcome.expandedReels;
  }

  Future<void> _abort() async {
    for (final reel in _reels) {
      if (reel.spinning) {
        _settle(reel, null);
      }
    }
    await Future.wait(_reels.map((r) => r.landed?.future ?? Future<void>.value()));
  }

  void _settle(_Reel reel, List<int>? column, {int distance = 5}) {
    if (!reel.spinning) {
      reel.spinning = true;
      reel.speed = _maxSpeed * 0.5;
    }
    final target = (reel.pos - distance).floorToDouble();
    if (column != null) {
      for (var row = 0; row < rowCount; row++) {
        reel.fixed[target.toInt() + row] = column[row];
      }
    }
    final speed = math.max(reel.speed, _maxSpeed * 0.6);
    reel.stopFrom = reel.pos;
    reel.stopTo = target;
    reel.stopElapsed = 0;
    reel.stopDuration = ((reel.pos - target) * (3 + _LandCurve._s) / speed).clamp(0.35, 1.4);
    reel.stopping = true;
    reel.landed ??= Completer<void>();
  }

  void _present(SpinOutcome outcome) {
    _wins = outcome.wins;
    _scatters = outcome.scatterCells.length >= 3 ? outcome.scatterCells : const [];
    _winsSince = _clock;
  }

  void _clear() {
    _wins = const [];
    _scatters = const [];
    _expanded = const [];
  }

  @override
  Widget build(BuildContext context) {
    final frame = Color(widget.slot.frame);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, frame, Color.lerp(frame, Colors.black, 0.45)!, frame, Colors.white],
          stops: const [0, 0.2, 0.5, 0.8, 1],
        ),
        boxShadow: [
          BoxShadow(color: frame.withValues(alpha: 0.65), blurRadius: 22),
          const BoxShadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(Color(widget.slot.tint), Colors.white, 0.12)!.withValues(alpha: 0.86),
                Color.lerp(Color(widget.slot.tint), Colors.black, 0.5)!.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BoardPainter(this, _frame),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.s, Listenable repaint) : super(repaint: repaint);

  final _ReelBoardState s;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / reelCount;
    final cellH = size.height / rowCount;
    final slot = s.widget.slot;
    final symbols = slot.symbols;
    final accent = Color(slot.accent);
    final showingWins = s._wins.isNotEmpty || s._scatters.isNotEmpty;
    final winTime = s._clock - s._winsSince;

    final lineCount = s._wins.length;
    final cycle = lineCount <= 1 || winTime < 1.8 ? -1 : ((winTime - 1.8) / 1.2).floor() % lineCount;
    final activeWins = cycle < 0 ? s._wins : [s._wins[cycle]];
    final winCells = <int>{for (final w in activeWins) ...w.cells, ...s._scatters};
    final pulse = 0.5 + 0.5 * math.sin(s._clock * 7);

    for (var reel = 0; reel < reelCount; reel++) {
      final column = Rect.fromLTWH(reel * cellW, 0, cellW, size.height);
      canvas.drawRect(
        column.deflate(2),
        Paint()
          ..shader = ui.Gradient.linear(column.topCenter, column.bottomCenter, [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.10),
          ], [0, 0.5, 1]),
      );
      if (reel > 0) {
        canvas.drawLine(
          Offset(reel * cellW, 6),
          Offset(reel * cellW, size.height - 6),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..strokeWidth = 1.2,
        );
      }
      final r = s._reels[reel];
      if (r.teasing) {
        canvas.drawRect(
          column,
          Paint()
            ..shader = ui.Gradient.linear(column.topCenter, column.bottomCenter, [
              gold.withValues(alpha: 0.15 + 0.25 * pulse),
              ember.withValues(alpha: 0.35 + 0.25 * pulse),
              gold.withValues(alpha: 0.15 + 0.25 * pulse),
            ], [0, 0.5, 1]),
        );
      }
      if (s._expanded.contains(reel) && !r.spinning) {
        final glow = column.deflate(3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(glow, const Radius.circular(14)),
          Paint()
            ..shader = ui.Gradient.linear(glow.topCenter, glow.bottomCenter, [
              gold.withValues(alpha: 0.55),
              ember.withValues(alpha: 0.35),
              gold.withValues(alpha: 0.55),
            ], [0, 0.5, 1]),
        );
      }
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var reel = 0; reel < reelCount; reel++) {
      final r = s._reels[reel];
      final first = r.pos.floor() - 1;
      final blur = r.spinning && !r.stopping ? (r.speed.abs() / 3).clamp(0.0, 7.0) : 0.0;
      for (var k = first; k <= first + rowCount + 1; k++) {
        final y = (k - r.pos) * cellH;
        if (y > size.height || y + cellH < 0) {
          continue;
        }
        final symbolIndex = s.symbolAt(reel, k);
        if (symbolIndex < 0 || symbolIndex >= symbols.length) {
          continue;
        }
        final symbol = symbols[symbolIndex];
        final landed = !r.spinning && k >= r.pos && k < r.pos + rowCount;
        final cellIndex = landed ? reel * rowCount + (k - r.pos.toInt()) : -1;
        final winning = cellIndex >= 0 && winCells.contains(cellIndex);
        final dimmed = showingWins && !winning;

        var rect = Rect.fromLTWH(reel * cellW, y, cellW, cellH);
        if (winning) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(14)),
            Paint()
              ..shader = ui.Gradient.radial(rect.center, rect.shortestSide * 0.7, [
                Color(symbol.glow).withValues(alpha: 0.55 + 0.3 * pulse),
                Color(symbol.glow).withValues(alpha: 0),
              ]),
          );
          rect = Rect.fromCenter(
            center: rect.center,
            width: rect.width * (1 + 0.08 * pulse),
            height: rect.height * (1 + 0.08 * pulse),
          );
        }
        final paint = Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, dimmed ? 0.35 : 1);
        if (blur > 0.5) {
          paint.imageFilter = ui.ImageFilter.blur(sigmaX: 0, sigmaY: blur);
        }
        final inset = symbol.kind == _kindWild ? 0.04 : 0.1;
        paintSprite(canvas, symbol.sprite, rect.deflate(rect.shortestSide * inset), paint: paint);

        if (symbol.badge.isNotEmpty && blur < 0.5) {
          _badge(canvas, rect, symbol.badge, dimmed);
        }
        if (cellIndex >= 0 && s._values[cellIndex] > 0) {
          _valuePlate(canvas, rect, compact(s._values[cellIndex]), dimmed);
        }
      }
    }
    canvas.restore();

    for (final win in activeWins) {
      _drawLine(canvas, cellW, cellH, win, Color(symbols[win.symbol.clamp(0, symbols.length - 1)].glow), cycle >= 0);
    }
    for (final cell in winCells) {
      final reel = cell ~/ rowCount;
      final row = cell % rowCount;
      final rect = Rect.fromLTWH(reel * cellW, row * cellH, cellW, cellH).deflate(3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Color.lerp(accent, Colors.white, pulse)!,
      );
    }
  }

  void _drawLine(Canvas canvas, double cellW, double cellH, LineWin win, Color color, bool single) {
    final lines = s.widget.paylines;
    final start = win.line * reelCount;
    if (start + reelCount > lines.length) {
      return;
    }
    final points = [
      for (var reel = 0; reel < reelCount; reel++)
        Offset(reel * cellW + cellW / 2, lines[start + reel] * cellH + cellH / 2),
    ];
    final path = Path()..moveTo(0, points.first.dy);
    for (final p in points) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(cellW * reelCount, points.last.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(color, Colors.white, 0.55)!,
    );
    if (single) {
      final anchor = points[math.min(win.count, reelCount) - 1];
      _amountTag(canvas, anchor, grouped(win.amount), color);
    }
  }

  void _amountTag(Canvas canvas, Offset at, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: display(16, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(center: at, width: painter.width + 18, height: painter.height + 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(12)),
      Paint()..color = const Color(0xE6081633),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    painter.paint(canvas, box.center - Offset(painter.width / 2, painter.height / 2));
  }

  void _badge(Canvas canvas, Rect cell, String text, bool dimmed) {
    final size = cell.height * 0.17;
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: Colors.white, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: Offset(cell.center.dx, cell.bottom - cell.height * 0.14),
      width: painter.width + size * 1.4,
      height: painter.height + size * 0.2,
    );
    final alpha = dimmed ? 0.4 : 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()
        ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, [
          rubyDeep.withValues(alpha: alpha),
          ruby.withValues(alpha: alpha),
          rubyDeep.withValues(alpha: alpha),
        ], [0, 0.5, 1]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = gold.withValues(alpha: alpha),
    );
    painter.paint(canvas, box.center - Offset(painter.width / 2, painter.height / 2));
  }

  void _valuePlate(Canvas canvas, Rect cell, String text, bool dimmed) {
    final size = cell.height * 0.16;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: dimmed ? goldLight.withValues(alpha: 0.5) : goldLight,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: Offset(cell.center.dx, cell.bottom - cell.height * 0.15),
      width: painter.width + size,
      height: painter.height + size * 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()..color = const Color(0xD9061A3D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = gold,
    );
    painter.paint(canvas, box.center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_BoardPainter old) => false;
}
