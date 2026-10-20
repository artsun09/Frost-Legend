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
Future<void> showBigWin(BuildContext context, {required SlotDef slot, required String label, required int amount, required int tier}) {
  HapticFeedback.heavyImpact();
  return showOverlayDialog<void>(
    context,
    _Celebration(slot: slot, title: label, amount: amount, tier: tier),
    dismissible: true,
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.slot, required this.title, required this.amount, required this.tier});

  final SlotDef slot;
  final String title;
  final int amount;
  final int tier;

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
    final slot = widget.slot;
    final mascot = switch (widget.tier) {
      3 => slot.leftMascot,
      2 => slot.rightMascot,
      _ => slot.angler,
    };
    final wheels = slot.decorWheels;
    final decor = wheels.isEmpty ? null : wheels[(widget.tier - 1).clamp(0, wheels.length - 1)];
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
                painter: SunburstPainter(turn: _c.value * 6.283, color: Color(slot.accent)),
              ),
            ),
            if (decor != null)
              Align(
                alignment: const Alignment(0, -0.42),
                child: SizedBox.square(
                  dimension: media.width * 0.9,
                  child: SpinningArt(decor, period: const Duration(seconds: 16), opacity: 0.35),
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
                child: SpriteBox(mascot, alignment: Alignment.bottomCenter),
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
                    const SizedBox(height: 12),
                    _AmountPlate(amount: widget.amount, duration: Duration(milliseconds: 1600 + widget.tier * 600)),
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

class _AmountPlate extends StatelessWidget {
  const _AmountPlate({required this.amount, required this.duration});

  final int amount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            value: amount,
            duration: duration,
            builder: (shown) => GoldText(grouped(shown), size: 44),
          ),
        ],
      ),
    );
  }
}

/// Level-up reward popup.
Future<void> showLevelUp(BuildContext context, {required int reward}) {
  HapticFeedback.mediumImpact();
  final state = GameBridge.instance.state;
  final wheels = GameBridge.instance.catalog?.slot.decorWheels ?? const <int>[];
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
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (wheels.isNotEmpty) SpinningArt(wheels.last, period: const Duration(seconds: 9)),
                        const Icon(Icons.star_rounded, color: gold, size: 46, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                      ],
                    ),
                  ),
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

/// Paytable, wild features and bonus rules at the current bet.
Future<void> showPaytable(BuildContext context, int bet) {
  return showOverlayDialog<void>(context, _Paytable(bet: bet), dismissible: true);
}

class _Paytable extends StatelessWidget {
  const _Paytable({required this.bet});

  final int bet;

  @override
  Widget build(BuildContext context) {
    final catalog = GameBridge.instance.catalog;
    if (catalog == null) {
      return const SizedBox.shrink();
    }
    final slot = catalog.slot;
    final symbols = [
      for (final s in slot.symbols)
        if (s.kind == 0) s,
    ].reversed.toList();
    final scatter = slot.symbols.where((s) => s.kind == 2);
    final accent = Color(slot.accent);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: FrostPanel(
            accent: accent,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Column(
              children: [
                GoldText(tx(T.paytable), size: 30),
                Text(slot.title, style: display(16, color: accent)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _Heading(tx(T.features)),
                      for (final f in slot.features)
                        _FeatureCard(title: f.title, text: f.text, sprite: f.sprite, color: Color(f.color)),
                      _Heading(tx(T.wheelPrizes)),
                      if (scatter.isNotEmpty)
                        _FeatureCard(
                          title: tx(T.scatter),
                          text: catalog.infoLines.elementAtOrNull(1) ?? Lex.blank,
                          sprite: scatter.first.sprite,
                          color: ember,
                        ),
                      _FishingCard(catalog: catalog),
                      const SizedBox(height: 6),
                      _Heading(tx(T.paytable)),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.9,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final s in slot.symbols)
                            if (s.kind == 1) _PayCell(symbol: s, bet: bet),
                          for (final s in symbols) _PayCell(symbol: s, bet: bet),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final line in catalog.infoLines)
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(text, style: display(15, color: iceEdge)),
          ),
          const Expanded(child: Divider(color: Colors.white24)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.text, required this.sprite, required this.color});

  final String title;
  final String text;
  final Sprite sprite;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(width: 58, height: 64, child: SpriteBox(sprite)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: display(17, color: color)),
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

class _FishingCard extends StatelessWidget {
  const _FishingCard({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: iceEdge.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(width: 58, height: 110, child: SpriteBox(catalog.slot.angler)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx(T.fishingBonus), style: display(17, color: iceEdge)),
                const SizedBox(height: 3),
                Text(catalog.infoLines.elementAtOrNull(2) ?? Lex.blank, style: body(12.5, color: iceWhite, weight: FontWeight.w400)),
                const SizedBox(height: 6),
                for (final fish in catalog.fish)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 30, height: 30, child: SpriteBox(fish.sprite)),
                        const SizedBox(width: 6),
                        Text(fish.name, style: display(13, color: Color.lerp(Color(fish.color), Colors.white, 0.25)!)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(fish.prizes, style: display(12, color: goldLight)),
                          ),
                        ),
                      ],
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
