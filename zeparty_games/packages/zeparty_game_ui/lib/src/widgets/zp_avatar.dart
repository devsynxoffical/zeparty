import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../theme/zp_colors.dart';

/// Player identity frame: avatar, optional cosmetic frame, seat colour ring,
/// voice activity pulse, connection state and ready tick.
class ZpAvatar extends StatelessWidget {
  const ZpAvatar({
    super.key,
    required this.player,
    this.size = 56,
    this.seatColor,
    this.frameAsset,
    this.highlight = false,
    this.showName = true,
    this.subtitle,
  });

  final RoomPlayer player;
  final double size;
  final Color? seatColor;
  final String? frameAsset;
  final bool highlight;
  final bool showName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ring = seatColor ?? ZpColors.seat(player.seat);
    final initials = player.displayName.isEmpty ? '?' : player.displayName.characters.first.toUpperCase();
    final avatar = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (player.micActive && !player.muted)
          _Pulse(color: ZpColors.success, size: size * 1.35),
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: highlight ? ZpColors.goldLight : ring, width: highlight ? 3 : 2),
            boxShadow: highlight ? [BoxShadow(color: ZpColors.gold.withValues(alpha: 0.6), blurRadius: 18, spreadRadius: 1)] : null,
          ),
          child: ClipOval(
            child: Opacity(
              opacity: player.connected ? 1 : 0.4,
              child: player.avatarUrl != null
                  ? Image.network(player.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _Initials(initials, ring))
                  : _Initials(initials, ring),
            ),
          ),
        ),
        if (frameAsset != null)
          IgnorePointer(child: Image(image: ZpAssets.image(frameAsset!), width: size * 1.3, height: size * 1.3, errorBuilder: (_, _, _) => const SizedBox.shrink())),
        if (!player.connected)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: ZpColors.obsidian, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 12, color: ZpColors.danger),
            ),
          )
        else if (player.muted)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: ZpColors.obsidian, shape: BoxShape.circle),
              child: const Icon(Icons.mic_off_rounded, size: 12, color: ZpColors.textMuted),
            ),
          )
        else if (player.ready)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: ZpColors.success, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
    if (!showName) return avatar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 6),
        SizedBox(
          width: size * 1.6,
          child: Text(player.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: highlight ? ZpColors.goldLight : ZpColors.textSecondary)),
        ),
        if (subtitle != null) Text(subtitle!, style: t.labelSmall, maxLines: 1),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.5)])),
        alignment: Alignment.center,
        child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: widget.size * (0.8 + 0.2 * _c.value),
          height: widget.size * (0.8 + 0.2 * _c.value),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withValues(alpha: 1 - _c.value), width: 2)),
        ),
      );
}
