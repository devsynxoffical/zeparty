import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import 'zp_button.dart';
import 'zp_panel.dart';
import 'zp_states.dart';

/// Blurred modal scrim used by pause, disconnect and reconnection overlays.
class ZpOverlay extends StatelessWidget {
  const ZpOverlay({super.key, required this.child, this.dismissible = false, this.onDismiss});
  final Widget child;
  final bool dismissible;
  final VoidCallback? onDismiss;
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: dismissible ? onDismiss : null,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(ZpSpace.xl),
            child: GestureDetector(onTap: () {}, child: child),
          ),
        ),
      ).animate().fadeIn(duration: ZpDurations.base),
    );
  }
}

/// Shown while the socket is reconnecting. Blocks input to prevent stale actions.
class ReconnectingOverlay extends StatelessWidget {
  const ReconnectingOverlay({super.key, required this.status, this.onLeave});
  final SocketStatus status;
  final VoidCallback? onLeave;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZpOverlay(
      child: ZpPanel(
        glow: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZpLoading(),
            const SizedBox(height: ZpSpace.lg),
            Text(status == SocketStatus.connecting ? 'Connecting' : 'Reconnecting', style: t.headlineSmall),
            const SizedBox(height: ZpSpace.sm),
            Text('Your seat is held for 60 seconds.\nThe match continues when you are back.', style: t.bodyMedium, textAlign: TextAlign.center),
            if (onLeave != null) ...[const SizedBox(height: ZpSpace.xl), ZpButton(label: 'Leave match', kind: ZpButtonKind.ghost, onPressed: onLeave)],
          ],
        ),
      ),
    );
  }
}

/// Non-blocking banner when another player drops.
class PlayerDisconnectedBanner extends StatelessWidget {
  const PlayerDisconnectedBanner({super.key, required this.players});
  final List<RoomPlayer> players;
  @override
  Widget build(BuildContext context) {
    final gone = players.where((p) => !p.connected).toList();
    if (gone.isEmpty) return const SizedBox.shrink();
    final names = gone.map((p) => p.displayName).join(', ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ZpSpace.lg),
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.md, vertical: ZpSpace.sm),
      decoration: BoxDecoration(color: ZpColors.danger.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(ZpRadius.md), border: Border.all(color: ZpColors.danger.withValues(alpha: 0.5))),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: ZpColors.danger, size: 18),
        const SizedBox(width: ZpSpace.sm),
        Expanded(child: Text('$names disconnected. Waiting up to 60 s, turns auto-play meanwhile.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZpColors.ivory))),
      ]),
    ).animate().fadeIn().slideY(begin: -0.3, end: 0);
  }
}

/// Pause / settings overlay shown from the in-game HUD.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.onResume, required this.onLeave, required this.onSettings, this.spectator = false});
  final VoidCallback onResume;
  final VoidCallback onLeave;
  final VoidCallback onSettings;
  final bool spectator;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZpOverlay(
      dismissible: true,
      onDismiss: onResume,
      child: ZpPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paused', style: t.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: ZpSpace.xs),
            Text(spectator ? 'You are spectating.' : 'The match keeps running for other players.', style: t.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: ZpSpace.xl),
            ZpButton(label: 'Resume', onPressed: onResume, expand: true),
            const SizedBox(height: ZpSpace.md),
            ZpButton(label: 'Settings', kind: ZpButtonKind.secondary, onPressed: onSettings, expand: true, icon: Icons.tune_rounded),
            const SizedBox(height: ZpSpace.md),
            ZpButton(label: spectator ? 'Stop watching' : 'Leave match', kind: ZpButtonKind.danger, onPressed: onLeave, expand: true),
          ],
        ),
      ),
    );
  }
}

/// Toast shown briefly inside game screens (extra turn, capture, achievements).
class GameToast extends StatelessWidget {
  const GameToast({super.key, required this.text, this.icon, this.color = ZpColors.gold});
  final String text;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
        decoration: BoxDecoration(
          color: ZpColors.obsidian.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(ZpRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: color, size: 20), const SizedBox(width: ZpSpace.sm)],
          Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
        ]),
      ).animate().fadeIn(duration: 160.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack).then(delay: 1400.ms).fadeOut(duration: 300.ms);
}
