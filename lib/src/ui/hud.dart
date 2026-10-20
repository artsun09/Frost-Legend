import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import '../core/lexicon.dart';
import '../core/numbers.dart';
import 'kit.dart';
import 'palette.dart';

class TopHud extends StatelessWidget {
  const TopHud({super.key, required this.state, required this.leading, required this.trailing, this.balance});

  final PlayerState state;
  final Widget leading;
  final Widget trailing;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    final progress = state.xpNext <= 0 ? 0.0 : (state.xp / state.xpNext).clamp(0.0, 1.0);
    return Row(
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: gold, size: 18),
                  const SizedBox(width: 3),
                  Text(state.levelLabel, style: display(16, color: goldLight)),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xAA041029),
                  border: Border.all(color: iceEdge.withValues(alpha: 0.6)),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    widthFactor: progress.clamp(0.03, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(colors: [Color(0xFFFFF27A), gold, Color(0xFFFF9D2E)]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 6,
          child: HudPill(
            height: 42,
            padding: const EdgeInsets.only(left: 4, right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 32),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TickingNumber(
                      value: balance ?? state.balance,
                      builder: (shown) => Text(grouped(shown), style: display(20, color: goldLight)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

class RefillBadge extends StatelessWidget {
  const RefillBadge({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pulse(
      amount: 0.08,
      child: GlossyButton(
        height: 46,
        colors: const [Color(0xFFFF9DD6), Color(0xFFFF3D9A), Color(0xFF9E0F55)],
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(tx(T.refill), style: display(16)),
          ],
        ),
      ),
    );
  }
}
