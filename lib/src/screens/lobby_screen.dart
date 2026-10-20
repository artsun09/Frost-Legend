import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import '../core/atlas.dart';
import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../slot/wheel_dialog.dart';
import '../ui/dialogs.dart';
import '../ui/hud.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';
import 'slot_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _pages = PageController(viewportFraction: 0.74);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
    GameBridge.instance.enter(-1);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _openRoom(int index, RoomDef room) async {
    final state = GameBridge.instance.state;
    if (state == null || state.level < room.unlockLevel) {
      return;
    }
    GameBridge.instance.enter(index);
    await Navigator.of(context).push(fadeRoute<void>(SlotScreen(roomIndex: index)));
    GameBridge.instance.enter(-1);
  }

  @override
  Widget build(BuildContext context) {
    final bridge = GameBridge.instance;
    final rooms = bridge.catalog?.rooms ?? const <RoomDef>[];
    return Scaffold(
      backgroundColor: frostNight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AssetArt(A.bg1, alignment: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66041029), Color(0x22041029), Color(0xDD041029), Color(0xF2020818)],
                stops: [0, 0.3, 0.72, 1],
              ),
            ),
          ),
          const SnowLayer(count: 60),
          SafeArea(
            child: ListenableBuilder(
              listenable: bridge,
              builder: (context, _) {
                final state = bridge.state;
                if (state == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: TopHud(
                        state: state,
                        leading: const _Avatar(),
                        trailing: RoundIconButton(icon: Icons.settings_rounded, onTap: () => showSettings(context)),
                      ),
                    ),
                    Expanded(
                      flex: 26,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                        child: Pulse(
                          amount: 0.025,
                          period: const Duration(milliseconds: 2200),
                          child: const AssetArt(A.gameName, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    GoldText(tx(T.chooseRealm), size: 20, colors: iceGradient, stroke: const Color(0xFF06204A)),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 52,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final delta = (index - _page).abs().clamp(0.0, 1.0);
                          return Transform.scale(
                            scale: 1 - delta * 0.1,
                            child: Opacity(
                              opacity: 1 - delta * 0.35,
                              child: _RoomCard(
                                room: rooms[index],
                                state: state,
                                onPlay: () => _openRoom(index, rooms[index]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _PageDots(count: rooms.length, page: _page),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: _DailyStrip(state: state),
                    ),
                  ],
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: bridge,
            builder: (context, _) {
              final state = bridge.state;
              if (state == null || !state.refillReady) {
                return const SizedBox.shrink();
              }
              return Positioned(
                right: 14,
                top: MediaQuery.paddingOf(context).top + 64,
                child: RefillBadge(onTap: () => showRefill(context)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final image = Atlas.of(A.icon);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: gold, width: 2.5),
        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      child: ClipOval(
        child: image == null ? const SizedBox.shrink() : RawImage(image: image, fit: BoxFit.cover),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.state, required this.onPlay});

  final RoomDef room;
  final PlayerState state;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final locked = state.level < room.unlockLevel;
    final accent = Color(room.accent);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: GestureDetector(
        onTap: locked ? null : onPlay,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accent, width: 3),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 22),
              const BoxShadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RoomBackdrop(room: room),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(room.tint).withValues(alpha: 0.75),
                        Color(room.tint).withValues(alpha: 0.05),
                        Color(room.tint).withValues(alpha: 0.95),
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 46,
                  top: 70,
                  child: SpriteBox(room.cardArt, alignment: Alignment.bottomCenter),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 14,
                  child: Column(
                    children: [
                      FittedBox(child: GoldText(room.title, size: 30)),
                      const SizedBox(height: 4),
                      Text(
                        room.tagline,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: display(13, color: iceWhite),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 14,
                  child: locked
                      ? const SizedBox.shrink()
                      : Pulse(
                          amount: 0.035,
                          child: GlossyButton(
                            height: 54,
                            onTap: onPlay,
                            colors: const [goldLight, gold, goldDeep],
                            child: GoldText(tx(T.play), size: 26, colors: const [Colors.white, Colors.white], stroke: const Color(0xFF7A3B00)),
                          ),
                        ),
                ),
                if (locked)
                  ColoredBox(
                    color: const Color(0xB3020814),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, color: gold, size: 64),
                        const SizedBox(height: 8),
                        GoldText(tx(T.locked), size: 26),
                        const SizedBox(height: 6),
                        HudPill(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(child: Text(room.lockLabel, style: display(17, color: goldLight))),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = (page.round() == i);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          width: active ? 22 : 9,
          height: 9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: active ? gold : Colors.white38,
          ),
        );
      }),
    );
  }
}

class _DailyStrip extends StatefulWidget {
  const _DailyStrip({required this.state});

  final PlayerState state;

  @override
  State<_DailyStrip> createState() => _DailyStripState();
}

class _DailyStripState extends State<_DailyStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final wheel = GameBridge.instance.catalog?.dailyWheel;
    return GestureDetector(
      onTap: () => showWheel(context, daily: true),
      child: Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xE6611B9B), Color(0xE6B4206F), Color(0xE6E0662A)]),
          border: Border.all(color: goldLight, width: 2),
          boxShadow: [BoxShadow(color: const Color(0xFFFF6BC4).withValues(alpha: 0.45), blurRadius: 18)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child: wheel == null
                  ? const SizedBox.shrink()
                  : AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => Transform.rotate(
                        angle: _spin.value * 2 * math.pi,
                        child: AssetArt(A.wheelSweet, fit: BoxFit.contain),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(child: GoldText(tx(T.dailyWheel), size: 24)),
                  const SizedBox(height: 2),
                  Text(tx(T.dailyText), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(12, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            state.dailyReady
                ? Pulse(
                    child: GlossyButton(
                      height: 46,
                      colors: const [goldLight, gold, goldDeep],
                      onTap: () => showWheel(context, daily: true),
                      child: Text(state.dailyLabel, style: display(17)),
                    ),
                  )
                : HudPill(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_rounded, color: iceEdge, size: 18),
                        const SizedBox(width: 6),
                        Text(state.dailyLabel, style: display(16, color: iceWhite)),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class RoomBackdrop extends StatelessWidget {
  const RoomBackdrop({super.key, required this.room});

  final RoomDef room;

  @override
  Widget build(BuildContext context) {
    final asset = A.values[room.background.clamp(0, A.values.length - 1)];
    return AssetArt(
      asset,
      alignment: Alignment.topCenter,
      color: Color(room.tint).withValues(alpha: 0.5),
      blend: BlendMode.hue,
    );
  }
}