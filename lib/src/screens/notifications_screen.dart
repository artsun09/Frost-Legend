import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _busy = false;

  Future<void> _answer(bool allow) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    var granted = false;
    if (allow) {
      try {
        granted = (await Permission.notification.request()).isGranted;
      } catch (_) {
        granted = false;
      }
    }
    GameBridge.instance.answerNotifications(granted);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: frostNight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AssetArt(landscape ? A.hNotif : A.vNotif, alignment: Alignment.center),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x00000000), Color(0xE6020A1E)],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: landscape ? Alignment.bottomRight : Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 0, 28, landscape ? 16 : 36),
                child: SizedBox(
                  width: landscape ? 300 : 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tx(T.notifHint),
                        textAlign: TextAlign.center,
                        style: display(15, color: iceWhite),
                      ),
                      const SizedBox(height: 14),
                      Pulse(
                        amount: 0.04,
                        child: GlossyButton(
                          height: landscape ? 50 : 60,
                          colors: const [goldLight, gold, goldDeep],
                          onTap: _busy ? null : () => _answer(true),
                          child: GoldText(tx(T.allow), size: 26, colors: const [Colors.white, Colors.white], stroke: const Color(0xFF7A3B00)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy ? null : () => _answer(false),
                        child: Text(tx(T.later), style: display(16, color: iceEdge)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
