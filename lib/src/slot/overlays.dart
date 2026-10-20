import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../core/numbers.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

const _whiteFill = [Colors.white, Colors.white];

/// Big / mega / epic win celebration with a count-up.
Future<void> showBigWin(BuildContext context, {required RoomDef room, required String label, required int amount, required int tier}) {
  HapticFeedback.heavyImpact();
  return showOverlayDialog<void>(
    context,
    _Celebration(room: room, title: label, amount: amount, tier: tier),
    dismissible: true,
  );
}

/// Free spins summary.
Future<void> showFreeSpinsDone(BuildContext context, {required RoomDef room, required int amount}) {
  return showOverlayDialog<void>(
    context,
    _Celebration(room: room, title: tx(T.freeSpinsDone), amount: amount, tier: 1, subtitle: tx(T.totalWin)),
    dismissible: true,
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.room, required this.title, required this.amount, required this.tier, this.subtitle});

  final RoomDef room;
  final String title;
  final int amount;
  final int tier;
  final String? subtitle;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer(Duration(milliseconds: 3800 + widget.tier * 700), _close);
  }

  void _close() {
    _auto?.cancel();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = switch (widget.tier) {
      3 => const [Color(0xFFFFE6FF), Color(0xFFFF7AE0), Color(0xFF9E2BFF)],
      2 => const [Colors.white, Color(0xFF8CF7FF), Color(0xFF2E7BFF)],
      _ => goldGradient,
    };
    final media = MediaQuery.sizeOf(context);
    return GestureDetector(
      onTap: _close,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: SunburstPainter(turn: _c.value * 6.283, color: Color(widget.room.accent)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: media.height * 0.42,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.translate(offset: Offset(0, t * media.height * 0.3), child: child),
                child: SpriteBox(widget.room.mascot, alignment: Alignment.bottomCenter),
              ),
            ),
            const CoinShower(count: 60),
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: media.height * 0.18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.2, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (context, s, child) => Transform.scale(scale: s, child: child),
                      child: Pulse(
                        amount: 0.05,
                        child: FittedBox(child: GoldText(widget.title, size: 56, colors: colors)),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(widget.subtitle!, style: display(20, color: iceWhite)),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: const Color(0xCC07122E),
                        border: Border.all(color: gold, width: 2.5),
                        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.5), blurRadius: 20)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(size: 40),
                          const SizedBox(width: 10),
                          TickingNumber(
                            value: widget.amount,
                            duration: Duration(milliseconds: 1600 + widget.tier * 600),
                            builder: (shown) => GoldText(grouped(shown), size: 44),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(tx(T.tapToContinue), style: display(14, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Level-up reward popup.
Future<void> showLevelUp(BuildContext context, {required int reward}) {
  HapticFeedback.mediumImpact();
  final state = GameBridge.instance.state;
  return showOverlayDialog<void>(
    context,
    Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: Colors.transparent,
            child: FrostPanel(
              accent: gold,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: gold, size: 70),
                  GoldText(tx(T.levelUp), size: 40),
                  const SizedBox(height: 4),
                  Text(state?.levelLabel ?? Lex.blank, style: display(24, color: iceWhite)),
                  const SizedBox(height: 12),
                  Text(tx(T.reward), style: display(16, color: iceEdge)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CoinIcon(size: 32),
                      const SizedBox(width: 8),
                      GoldText(grouped(reward), size: 34),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) => GlossyButton(
                      width: 200,
                      onTap: () => Navigator.of(context).pop(),
                      child: GoldText(tx(T.collect), size: 22, colors: _whiteFill, stroke: emeraldDeep),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    dismissible: true,
  );
}

/// Paytable and rules for a room at the current bet.
Future<void> showPaytable(BuildContext context, RoomDef room, int bet) {
  return showOverlayDialog<void>(context, _Paytable(room: room, bet: bet), dismissible: true);
}

class _Paytable extends StatelessWidget {
  const _Paytable({required this.room, required this.bet});

  final RoomDef room;
  final int bet;

  @override
  Widget build(BuildContext context) {
    final catalog = GameBridge.instance.catalog;
    final symbols = [
      for (final s in room.symbols)
        if (s.kind != 2) s,
    ].reversed.toList();
    final scatter = room.symbols.where((s) => s.kind == 2);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: FrostPanel(
            accent: Color(room.accent),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Column(
              children: [
                GoldText(tx(T.paytable), size: 30),
                Text(room.title, style: display(16, color: Color(room.accent))),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _FeatureCard(title: room.featureTitle, text: room.featureText, sprite: room.mascot),
                      if (scatter.isNotEmpty)
                        _FeatureCard(title: tx(T.scatter), text: catalog?.infoLines.elementAtOrNull(1) ?? Lex.blank, sprite: scatter.first.sprite),
                      const SizedBox(height: 6),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.9,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [for (final s in symbols) _PayCell(symbol: s, bet: bet)],
                      ),
                      const SizedBox(height: 10),
                      for (final line in catalog?.infoLines ?? const <String>[])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.ac_unit_rounded, color: iceBlue, size: 14),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: Text(line, style: body(13, color: iceWhite, weight: FontWeight.w400))),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        tx(T.disclaimer),
                        textAlign: TextAlign.center,
                        style: body(11, color: Colors.white54, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GlossyButton(
                  width: 180,
                  height: 46,
                  colors: const [goldLight, gold, goldDeep],
                  onTap: () => Navigator.of(context).pop(),
                  child: GoldText(tx(T.close), size: 20, colors: _whiteFill, stroke: const Color(0xFF7A3B00)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.text, required this.sprite});

  final String title;
  final String text;
  final Sprite sprite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          SizedBox(width: 54, height: 70, child: SpriteBox(sprite)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: display(17, color: goldLight)),
                const SizedBox(height: 3),
                Text(text, style: body(12.5, color: iceWhite, weight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayCell extends StatelessWidget {
  const _PayCell({required this.symbol, required this.bet});

  final SymbolDef symbol;
  final int bet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Color(symbol.glow).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: SpriteBox(symbol.sprite)),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (symbol.badge.isNotEmpty) Text(symbol.badge, style: display(12, color: ruby)),
                for (var i = symbol.pays.length - 1; i >= 0; i--)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: (i + 3).toString() + tx(T.space), style: display(12, color: Colors.white60)),
                          TextSpan(text: compact(symbol.pays[i] * bet ~/ 20), style: display(13, color: goldLight)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
