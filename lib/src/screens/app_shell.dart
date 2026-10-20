import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_bridge.dart';
import '../core/lexicon.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';
import 'loading_screen.dart';
import 'lobby_screen.dart';

enum Stage { loading, lobby }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _booted = false;
  Stage _stage = Stage.loading;

  @override
  void initState() {
    super.initState();
    GameBridge.instance.boot().then((_) {
      if (mounted) {
        setState(() => _booted = true);
      }
    });
  }

  Future<void> _openLobby() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) {
      setState(() => _stage = Stage.lobby);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_booted) {
      return const ColoredBox(color: frostNight);
    }
    return MaterialApp(
      title: tx(T.appTitle),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: tx(T.fontFamily),
        scaffoldBackgroundColor: frostNight,
        colorScheme: ColorScheme.fromSeed(seedColor: iceBlue, brightness: Brightness.dark),
      ),
      builder: (context, child) => ToastHost(child: child ?? const SizedBox.shrink()),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: switch (_stage) {
          Stage.loading => LoadingScreen(key: const ValueKey<Stage>(Stage.loading), onDone: _openLobby),
          Stage.lobby => const LobbyScreen(key: ValueKey<Stage>(Stage.lobby)),
        },
      ),
    );
  }
}
