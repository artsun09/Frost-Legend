import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import '../core/atlas.dart';
import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../core/numbers.dart';
import '../slot/fishing_screen.dart';
import '../slot/overlays.dart';
import '../slot/reels.dart';
import '../slot/wheel_dialog.dart';
import '../ui/dialogs.dart';
import '../ui/hud.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

const _whiteFill = [Colors.white, Colors.white];

class SlotScreen extends StatefulWidget {
  const SlotScreen({super.key});

  @override
  State<SlotScreen> createState() => _SlotScreenState();
}

class _SlotScreenState extends State<SlotScreen> with TickerProviderStateMixin {
  final _board = ReelBoardController();
  final _bridge = GameBridge.instance;
  late final SlotDef _slot = _bridge.slot;
  late final AnimationController _spinRing = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  StreamSubscription<SpinOutcome>? _line;
  Completer<SpinOutcome>? _pending;
  bool _spinning = false;
  bool _auto = false;
  bool _inBonus = false;
  int? _shownBalance;
  int _lastWin = 0;
  String _feature = Lex.blank;
  String? _flash;
  int _flashId = 0;

  @override
  void initState() {
    super.initState();
    _line = _bridge.spins.listen((outcome) {
      final pending = _pending;
      if (pending != null && !pending.isCompleted) {
        pending.complete(outcome);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _bridge.state;
      if (state != null && (state.wheelPending || state.fishPending >= 0)) {
        Future<void>.delayed(const Duration(milliseconds: 600), _playBonus);
      }
    });
  }

  @override
  void dispose() {
    _line?.cancel();
    _spinRing.dispose();
    super.dispose();
  }

  Color get _accent => Color(_slot.accent);

  void _showFlash(String text) {
    final id = ++_flashId;
    setState(() => _flash = text);
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (mounted && _flashId == id) {
        setState(() => _flash = null);
      }
    });
  }

  Future<void> _spin() async {
    final state = _bridge.state;
    if (_spinning || _inBonus || !mounted || state == null) {
      return;
    }
    if (state.wheelPending || state.fishPending >= 0) {
      await _playBonus();
      return;
    }
    if (state.balance < state.bet) {
      setState(() => _auto = false);
      if (state.refillReady) {
        await showRefill(context);
      } else {
        _bridge.say(tx(T.notEnough));
      }
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _spinning = true;
      _shownBalance = state.balance - state.bet;
      _lastWin = 0;
      _feature = Lex.blank;
    });
    _spinRing.repeat();
    _board.start();
    final pending = Completer<SpinOutcome>();
    _pending = pending;
    _bridge.spin(auto: _auto);

    SpinOutcome? outcome;
    try {
      outcome = await pending.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      outcome = null;
    }
    if (!mounted) {
      return;
    }
    if (outcome == null || !outcome.accepted) {
      await _board.abort();
      setState(() => _auto = false);
      _finish();
      return;
    }

    await _board.land(outcome, turbo: _auto);
    if (!mounted) {
      return;
    }
    _spinRing.stop();
    _board.present(outcome);
    setState(() {
      _shownBalance = null;
      _lastWin = outcome!.totalWin;
      _feature = outcome.featureLabel;
    });
    _bridge.publish();
    if (outcome.totalWin > 0) {
      HapticFeedback.mediumImpact();
    }

    if (outcome.tier > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        await showBigWin(context, slot: _slot, label: outcome.tierLabel, amount: outcome.totalWin, tier: outcome.tier);
      }
    } else if (outcome.totalWin > 0) {
      await Future<void>.delayed(Duration(milliseconds: _auto ? 1100 : 500));
    } else if (_auto) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted) {
      return;
    }
    if (outcome.levelUp) {
      await showLevelUp(context, reward: outcome.levelReward);
    }
    _finish();
    if (outcome.wheelTriggered && mounted) {
      setState(() => _auto = false);
      _showFlash(tx(T.bonusWheel));
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await _playBonus();
      return;
    }
    _continue();
  }

  void _finish() {
    _spinRing.stop();
    if (mounted) {
      setState(() {
        _spinning = false;
        _shownBalance = null;
      });
    }
  }

  void _continue() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    if (_auto) {
      Future<void>.delayed(const Duration(milliseconds: 250), _spin);
    }
  }

  Future<void> _playBonus() async {
    if (!mounted || _inBonus) {
      return;
    }
    setState(() => _inBonus = true);
    _board.clear();
    if (_bridge.state?.wheelPending ?? false) {
      final outcome = await showBonusWheel(context);
      if (mounted && outcome != null && outcome.fish < 0) {
        setState(() => _lastWin = outcome.coins);
      }
    }
    if (mounted && (_bridge.state?.fishPending ?? -1) >= 0) {
      final caught = await Navigator.of(context).push(fadeRoute<FishOutcome?>(const FishingScreen()));
      if (mounted && caught != null) {
        setState(() => _lastWin = caught.coins);
      }
    }
    if (mounted) {
      setState(() => _inBonus = false);
      _bridge.publish();
    }
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    if (_auto && !_spinning) {
      _spin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _bridge.catalog;
    final tint = Color(_slot.tint);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: frostNight,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AssetArt(A.values[_slot.background.clamp(0, A.values.length - 1)], alignment: Alignment.topCenter),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tint.withValues(alpha: 0.55),
                    tint.withValues(alpha: 0.05),
                    tint.withValues(alpha: 0.65),
                    const Color(0xF2020818),
                  ],
                  stops: const [0, 0.32, 0.7, 1],
                ),
              ),
            ),
            SnowLayer(count: 45, color: Color.lerp(Colors.white, _accent, 0.3)!),
            SafeArea(
              child: ListenableBuilder(
                listenable: _bridge,
                builder: (context, _) {
                  final state = _bridge.state;
                  if (state == null || catalog == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                        child: TopHud(
                          state: state,
                          balance: _shownBalance,
                          leading: RoundIconButton(
                            icon: Icons.settings_rounded,
                            onTap: () {
                              if (!_spinning) {
                                setState(() => _auto = false);
                                showSettings(context);
                              }
                            },
                          ),
                          trailing: RoundIconButton(
                            icon: Icons.info_outline_rounded,
                            onTap: () => showPaytable(context, state.bet),
                          ),
                        ),
                      ),
                      _JackpotStrip(state: state, catalog: catalog),
                      Expanded(child: _stage(catalog)),
                      _WinBar(lastWin: _lastWin, feature: _feature, accent: _accent),
                      _Controls(
                        state: state,
                        spinning: _spinning || _inBonus,
                        auto: _auto,
                        ring: _spinRing,
                        accent: _accent,
                        onSpin: () {
                          if (_auto) {
                            setState(() => _auto = false);
                          } else {
                            _spin();
                          }
                        },
                        onAuto: _toggleAuto,
                        onBet: (step) => _bridge.changeBet(step),
                      ),
                    ],
                  );
                },
              ),
            ),
            ListenableBuilder(
              listenable: _bridge,
              builder: (context, _) {
                final state = _bridge.state;
                if (state == null || !state.refillReady || _spinning) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  right: 14,
                  top: MediaQuery.paddingOf(context).top + 120,
                  child: RefillBadge(onTap: () => showRefill(context)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage(Catalog catalog) {
    return LayoutBuilder(
      builder: (context, box) {
        final boardW = math.min(box.maxWidth - 16, (box.maxHeight - 24) * 5 / 3.3);
        final boardH = boardW * 3.3 / 5;
        final above = box.maxHeight - boardH - 8;
        final mascotH = above + boardH * 0.3;
        final logo = Atlas.of(A.gameName);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -box.maxWidth * 0.04,
              bottom: 8 + boardH * 0.7,
              height: mascotH,
              width: box.maxWidth * 0.42,
              child: IgnorePointer(child: SpriteBox(_slot.leftMascot, alignment: Alignment.bottomLeft)),
            ),
            Positioned(
              right: -box.maxWidth * 0.04,
              bottom: 8 + boardH * 0.7,
              height: mascotH,
              width: box.maxWidth * 0.4,
              child: IgnorePointer(child: SpriteBox(_slot.rightMascot, alignment: Alignment.bottomRight)),
            ),
            if (logo != null)
              Positioned(
                left: box.maxWidth * 0.24,
                right: box.maxWidth * 0.24,
                top: 0,
                height: math.max(0, above - 4),
                child: IgnorePointer(
                  child: Pulse(
                    amount: 0.025,
                    period: const Duration(milliseconds: 2200),
                    child: RawImage(image: logo, fit: BoxFit.contain),
                  ),
                ),
              ),
            Positioned(
              left: (box.maxWidth - boardW) / 2,
              bottom: 8,
              width: boardW,
              height: boardH,
              child: ReelBoard(slot: _slot, paylines: catalog.paylines, controller: _board),
            ),
            if (_flash != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8 + boardH * 0.38,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<int>(_flashId),
                    tween: Tween(begin: 0.3, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, s, child) => Transform.scale(scale: s, child: child),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: const Color(0xD9050C22),
                          border: Border.all(color: gold, width: 2.5),
                          boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.6), blurRadius: 24)],
                        ),
                        child: GoldText(_flash!, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JackpotStrip extends StatelessWidget {
  const _JackpotStrip({required this.state, required this.catalog});

  final PlayerState state;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final badges = catalog.jackpotBadges;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          for (var i = 0; i < badges.length && i < state.jackpots.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    SizedBox(height: 40, child: SpriteBox(badges[i])),
                    Container(
                      height: 22,
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: const Color(0xCC050C22),
                        border: Border.all(color: Color(catalog.jackpotColors[i]), width: 1.5),
                      ),
                      child: Center(
                        child: FittedBox(
                          child: TickingNumber(
                            value: state.jackpots[i],
                            builder: (shown) => Text(grouped(shown), style: display(13, color: goldLight)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WinBar extends StatelessWidget {
  const _WinBar({required this.lastWin, required this.feature, required this.accent});

  final int lastWin;
  final String feature;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(tx(T.lines), style: display(13, color: Colors.white60)),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: feature.isNotEmpty
                    ? Align(
                        key: ValueKey<String>(feature),
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FittedBox(child: Pulse(child: Text(feature, style: display(14, color: accent)))),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Text(tx(T.win), style: display(16, color: Colors.white70)),
            const SizedBox(width: 6),
            TickingNumber(
              value: lastWin,
              duration: const Duration(milliseconds: 900),
              builder: (shown) => GoldText(grouped(shown), size: 26),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.spinning,
    required this.auto,
    required this.ring,
    required this.accent,
    required this.onSpin,
    required this.onAuto,
    required this.onBet,
  });

  final PlayerState state;
  final bool spinning;
  final bool auto;
  final Animation<double> ring;
  final Color accent;
  final VoidCallback onSpin;
  final VoidCallback onAuto;
  final void Function(int step) onBet;

  @override
  Widget build(BuildContext context) {
    final betLocked = spinning || auto;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6102A5E), Color(0xF2050C22)],
        ),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.8), width: 2)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tx(T.bet), style: display(14, color: Colors.white70)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _BetButton(icon: Icons.remove_rounded, onTap: betLocked || !state.canBetDown ? null : () => onBet(-1)),
                    Expanded(
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xCC030916),
                          border: Border.all(color: iceEdge.withValues(alpha: 0.6)),
                        ),
                        child: Center(
                          child: FittedBox(child: Text(grouped(state.bet), style: display(19, color: goldLight))),
                        ),
                      ),
                    ),
                    _BetButton(icon: Icons.add_rounded, onTap: betLocked ? null : () => onBet(1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SpinButton(spinning: spinning, auto: auto, ring: ring, accent: accent, onTap: onSpin),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tx(T.auto), style: display(14, color: Colors.white70)),
                const SizedBox(height: 4),
                GlossyButton(
                  height: 40,
                  radius: 12,
                  colors: auto
                      ? const [Color(0xFFFF9D9D), ruby, rubyDeep]
                      : const [Color(0xFFB08CFF), violet, violetDeep],
                  onTap: onAuto,
                  child: FittedBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(auto ? Icons.stop_rounded : Icons.autorenew_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(auto ? tx(T.stop) : tx(T.auto), style: display(16)),
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

class _BetButton extends StatelessWidget {
  const _BetButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlossyButton(
      height: 40,
      width: 40,
      radius: 12,
      colors: const [Color(0xFF5CC8FF), Color(0xFF1E6FD9), Color(0xFF0D3A8C)],
      border: iceEdge,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _SpinButton extends StatelessWidget {
  const _SpinButton({
    required this.spinning,
    required this.auto,
    required this.ring,
    required this.accent,
    required this.onTap,
  });

  final bool spinning;
  final bool auto;
  final Animation<double> ring;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    const colors = [Color(0xFF9DFFB5), emerald, emeraldDeep];
    final enabled = !spinning || auto;
    return Pulse(
      active: !spinning && !auto,
      amount: 0.04,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: ring,
                builder: (context, _) => Transform.rotate(
                  angle: ring.value * 2 * math.pi,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [goldLight, accent, goldDeep, accent, goldLight]),
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 20)],
                    ),
                  ),
                ),
              ),
              Container(
                width: size - 12,
                height: size - 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: colors, center: Alignment(-0.3, -0.4), radius: 0.95),
                ),
                child: Center(
                  child: auto
                      ? const Icon(Icons.stop_rounded, color: Colors.white, size: 46)
                      : spinning
                          ? const Icon(Icons.hourglass_top_rounded, color: Colors.white70, size: 38)
                          : GoldText(tx(T.spin), size: 26, colors: _whiteFill, stroke: emeraldDeep),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
