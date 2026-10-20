import 'package:flutter/material.dart';

import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../core/numbers.dart';
import '../screens/web_page.dart';
import 'kit.dart';
import 'palette.dart';

const _whiteFill = [Colors.white, Colors.white];

Future<void> showSettings(BuildContext context) {
  return showOverlayDialog<void>(context, const _SettingsPanel(), dismissible: true);
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  void _open(BuildContext context, T title, L link) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WebPage(title: tx(title), url: Lex.link(link))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: FrostPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoldText(tx(T.settings), size: 30),
                  const SizedBox(height: 18),
                  GlossyButton(
                    colors: const [Color(0xFF5CC8FF), Color(0xFF1E6FD9), Color(0xFF0D3A8C)],
                    onTap: () => _open(context, T.privacy, L.privacy),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(tx(T.privacy), style: display(19)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlossyButton(
                    colors: const [Color(0xFFB08CFF), violet, violetDeep],
                    onTap: () => _open(context, T.support, L.support),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(tx(T.support), style: display(19)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tx(T.disclaimer),
                    textAlign: TextAlign.center,
                    style: body(12.5, color: iceWhite.withValues(alpha: 0.8), weight: FontWeight.w400),
                  ),
                  const SizedBox(height: 16),
                  GlossyButton(
                    width: 170,
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
      ),
    );
  }
}

Future<void> showRefill(BuildContext context) {
  return showOverlayDialog<void>(context, const _RefillPanel(), dismissible: true);
}

class _RefillPanel extends StatelessWidget {
  const _RefillPanel();

  @override
  Widget build(BuildContext context) {
    final amount = GameBridge.instance.state?.refillAmount ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Colors.transparent,
            child: FrostPanel(
              accent: gold,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoldText(tx(T.refill), size: 32),
                  const SizedBox(height: 10),
                  Text(tx(T.refillText), textAlign: TextAlign.center, style: display(16, color: iceWhite)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CoinIcon(size: 34),
                      const SizedBox(width: 8),
                      GoldText(grouped(amount), size: 34),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Pulse(
                    amount: 0.04,
                    child: GlossyButton(
                      width: 200,
                      onTap: () {
                        GameBridge.instance.refill();
                        Navigator.of(context).pop();
                      },
                      child: GoldText(tx(T.take), size: 24, colors: _whiteFill, stroke: emeraldDeep),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
