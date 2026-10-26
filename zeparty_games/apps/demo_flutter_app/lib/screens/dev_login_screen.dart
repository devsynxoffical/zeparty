import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../main.dart';

/// Dev-only entry: pick a backend and a user id. In the real app the host
/// supplies identity and token; this screen stands in for that.
class DevLoginScreen extends StatefulWidget {
  const DevLoginScreen({super.key});
  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
  final _api = TextEditingController(text: kApiBase);
  final _ws = TextEditingController(text: kWsUrl);
  final _user = TextEditingController(text: 'player1');
  final _name = TextEditingController(text: 'Player One');
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _api.text = p.getString('zp_api') ?? _api.text;
        _ws.text = p.getString('zp_ws') ?? _ws.text;
        _user.text = p.getString('zp_last_user') ?? _user.text;
      });
    });
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await devLogin(_api.text.trim(), _user.text.trim(), _name.text.trim());
      if (!mounted) return;
      await launchGames(context, apiBase: _api.text.trim(), wsUrl: _ws.text.trim(), session: session);
    } catch (e) {
      setState(() => _error = 'Could not reach backend: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: ZpBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(ZpSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ZpPanel(
                  glow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('ZEPARTY', style: t.labelSmall?.copyWith(color: ZpColors.gold, letterSpacing: 4), textAlign: TextAlign.center),
                      Text('Games Demo', style: t.headlineLarge, textAlign: TextAlign.center),
                      const SizedBox(height: ZpSpace.sm),
                      Text('Development shell. Start the backend with npm run dev, then sign in with any user id. Open a second instance with another id to play against yourself.', style: t.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: ZpSpace.xl),
                      TextField(controller: _api, decoration: const InputDecoration(labelText: 'API base URL')),
                      const SizedBox(height: ZpSpace.md),
                      TextField(controller: _ws, decoration: const InputDecoration(labelText: 'WebSocket URL')),
                      const SizedBox(height: ZpSpace.md),
                      Row(children: [
                        Expanded(child: TextField(controller: _user, decoration: const InputDecoration(labelText: 'User id'))),
                        const SizedBox(width: ZpSpace.md),
                        Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name'))),
                      ]),
                      if (_error != null) ...[const SizedBox(height: ZpSpace.md), Text(_error!, style: t.bodySmall?.copyWith(color: ZpColors.danger))],
                      const SizedBox(height: ZpSpace.xl),
                      ZpButton(label: 'Enter game center', icon: Icons.login_rounded, loading: _busy, onPressed: _busy ? null : _go, expand: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
