import 'package:flutter/material.dart';

import '../core/atlas.dart';
import '../core/lexicon.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  static const _minimum = Duration(milliseconds: 2800);

  bool _artReady = false;
  double _loaded = 0;
  late final AnimationController _shown = AnimationController(vsync: this, duration: _minimum);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Atlas.loadOne(A.vLoading.index);
    await Atlas.loadOne(A.hLoading.index);
    await Atlas.trim(A.vLoading);
    await Atlas.trim(A.hLoading);
    if (!mounted) {
      return;
    }
    setState(() => _artReady = true);
    final pacing = _shown.forward();
    await Atlas.loadAll((p) {
      if (mounted) {
        setState(() => _loaded = p);
      }
    });
    await pacing;
    if (mounted) {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: frostNight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_artReady)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: AssetArt(
                landscape ? A.hLoading : A.vLoading,
                key: ValueKey<bool>(landscape),
                alignment: landscape ? Alignment.center : Alignment.topCenter,
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x00000000), Color(0xCC020A1E)],
                stops: [0, 0.62, 1],
              ),
            ),
          ),
          if (_artReady) const SnowLayer(count: 50),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(32, 0, 32, landscape ? 18 : 42),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoldText(tx(T.loading), size: landscape ? 22 : 26, colors: iceGradient, stroke: const Color(0xFF06204A)),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _shown,
                        builder: (context, _) {
                          final shown = _shown.value < _loaded ? _shown.value : _loaded;
                          return _ProgressBar(value: shown);
                        },
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xAA041029),
        border: Border.all(color: iceEdge, width: 1.5),
        boxShadow: [BoxShadow(color: iceBlue.withValues(alpha: 0.4), blurRadius: 12)],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.04, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, iceBlue, Color(0xFF1E8BE0)],
              ),
              boxShadow: [BoxShadow(color: iceBlue.withValues(alpha: 0.8), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}
