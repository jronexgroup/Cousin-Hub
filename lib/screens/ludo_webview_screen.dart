import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app_theme.dart';

class LudoWebScreen extends StatefulWidget {
  const LudoWebScreen({super.key});
  @override
  State<LudoWebScreen> createState() => _LudoWebScreenState();
}

class _LudoWebScreenState extends State<LudoWebScreen> {
  late WebViewController _ctrl;
  bool _loading = true;
  bool _error = false;

  // Best working Ludo game URLs (fallback order)
  final List<Map<String, String>> _sources = [
    {
      'url': 'https://ludoking.com/play/',
      'name': 'Ludo King™ Official',
    },
    {
      'url': 'https://www.crazygames.com/game/ludo-king',
      'name': 'Ludo King (CrazyGames)',
    },
    {
      'url': 'https://playpager.com/ludo/',
      'name': 'Ludo Online',
    },
  ];
  int _srcIdx = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1a0a2e))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _error = false; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          // Inject CSS to hide unnecessary elements & make fullscreen
          _ctrl.runJavaScript('''
            try {
              // Remove headers/footers for cleaner game view
              var style = document.createElement('style');
              style.textContent = `
                header, footer, nav, .header, .footer, .navbar,
                .ad, .ads, .advertisement, [class*="banner"],
                .cookie-notice, .popup, .modal-overlay { 
                  display: none !important; 
                }
                body { overflow: hidden !important; }
                canvas, .game-canvas, #game-container, .game-wrapper {
                  width: 100vw !important;
                  height: 100vh !important;
                }
              `;
              document.head.appendChild(style);
            } catch(e) {}
          ''');
        },
        onWebResourceError: (err) {
          if (mounted) setState(() { _loading = false; _error = true; });
        },
        onNavigationRequest: (req) => NavigationDecision.navigate,
      ))
      ..loadRequest(Uri.parse(_sources[_srcIdx]['url']!));
  }

  void _tryNextSource() {
    if (_srcIdx < _sources.length - 1) {
      _srcIdx++;
      setState(() { _loading = true; _error = false; });
      _ctrl.loadRequest(Uri.parse(_sources[_srcIdx]['url']!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0a2e),
      appBar: _buildAppBar(),
      body: Stack(children: [
        // WebView
        WebViewWidget(controller: _ctrl),

        // Loading indicator
        if (_loading) Container(
          color: const Color(0xFF1a0a2e),
          child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎲', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              const Text('Loading Ludo King...',
                style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const SizedBox(width: 200,
                child: LinearProgressIndicator(
                  color: Color(0xFF9d4edd),
                  backgroundColor: Color(0xFF2a1a4e))),
              const SizedBox(height: 12),
              Text(_sources[_srcIdx]['name']!,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]))),

        // Error state
        if (_error && !_loading) Container(
          color: const Color(0xFF1a0a2e),
          child: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('😕', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Could not load game',
                style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Please check your internet connection',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 24),
              if (_srcIdx < _sources.length - 1)
                _buildBtn('Try Alternate Source', _tryNextSource,
                  const Color(0xFF9d4edd)),
              const SizedBox(height: 12),
              _buildBtn('Retry', () {
                setState(() { _loading = true; _error = false; });
                _ctrl.loadRequest(Uri.parse(_sources[_srcIdx]['url']!));
              }, const Color(0xFF1e88e5)),
            ])))),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0d0823),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context)),
      title: Row(children: [
        const Text('🎲', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ludo King™',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
              color: Colors.white)),
          Text(_sources[_srcIdx]['name']!,
            style: const TextStyle(fontSize: 10, color: Colors.white38)),
        ]),
      ]),
      actions: [
        // Fullscreen toggle
        IconButton(
          icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
          onPressed: () => _ctrl.runJavaScript('''
            try {
              if (document.fullscreenElement) document.exitFullscreen();
              else document.documentElement.requestFullscreen();
            } catch(e) {}
          ''')),
        // Reload
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            setState(() { _loading = true; _error = false; });
            _ctrl.reload();
          }),
      ]);
  }

  Widget _buildBtn(String label, VoidCallback onTap, Color color) =>
    SizedBox(width: double.infinity,
      child: ElevatedButton(onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
        child: Text(label, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w800, fontSize: 14))));
}
