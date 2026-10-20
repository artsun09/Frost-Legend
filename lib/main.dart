import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rinf/rinf.dart';

import 'src/bindings/bindings.dart';
import 'src/screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await initializeRust(assignRustSignal);
  runApp(const FrostLegendRoot());
}

class FrostLegendRoot extends StatefulWidget {
  const FrostLegendRoot({super.key});

  @override
  State<FrostLegendRoot> createState() => _FrostLegendRootState();
}

class _FrostLegendRootState extends State<FrostLegendRoot> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        finalizeRust();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}
