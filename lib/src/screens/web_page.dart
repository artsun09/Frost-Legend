import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/lexicon.dart';
import '../ui/kit.dart';
import '../ui/palette.dart';

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) {
              setState(() => _progress = value);
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _failed = false);
            }
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      );
    _load();
  }

  void _load() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: frostNight,
      appBar: AppBar(
        backgroundColor: frostDeep,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: GoldText(widget.title, size: 22),
        bottom: _progress < 100 && !_failed
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 3,
                  color: iceBlue,
                  backgroundColor: Colors.white12,
                ),
              )
            : null,
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: iceEdge, size: 54),
                    const SizedBox(height: 14),
                    Text(tx(T.webError), textAlign: TextAlign.center, style: display(18, color: iceWhite)),
                    const SizedBox(height: 20),
                    GlossyButton(
                      width: 180,
                      onTap: () {
                        _load();
                      },
                      child: GoldText(tx(T.retry), size: 20, colors: const [Colors.white, Colors.white], stroke: emeraldDeep),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
