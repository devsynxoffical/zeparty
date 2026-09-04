import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/animations/app_animations.dart';
import '../core/utils/performance_utils.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isLive;
  final bool showVipFrame;
  final bool isPremium;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.isLive = false,
    this.showVipFrame = false,
    this.isPremium = false,
    this.onTap,
  });

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    } else if (url.startsWith('assets/')) {
      return AssetImage(url);
    } else {
      final file = File(url);
      if (file.existsSync()) {
        return FileImage(file);
      }
      return NetworkImage(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validUrl = (imageUrl != null && imageUrl!.isNotEmpty)
        ? imageUrl!
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
    final cacheDim = PerformanceUtils.getMemCacheWidth(radius * 2);

    Widget avatar = Container(
      padding: EdgeInsets.all(isLive || showVipFrame || isPremium ? 2.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isLive
            ? LinearGradient(colors: [AppColors.live, AppColors.getPrimary(isDark)])
            : (showVipFrame || isPremium ? AppColors.getPremiumGradient(isDark) : null),
        border: !isLive && !showVipFrame && !isPremium
            ? Border.all(
                color: isDark ? AppColors.borderGold : AppColors.lightBorder,
                width: 1.2,
              )
            : null,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: isDark ? AppColors.softBlack : AppColors.lightSurface,
        backgroundImage: ResizeImage.resizeIfNeeded(
          cacheDim,
          cacheDim,
          _getImageProvider(validUrl),
        ),
      ),
    );

    if (showVipFrame && !isLive) {
      avatar = GoldGlowBorder(
        borderRadius: radius + 4,
        color: AppColors.getPrimary(isDark),
        minOpacity: 0.25,
        maxOpacity: 0.7,
        child: avatar,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          if (isLive)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.live,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A widget showing a user avatar with an online/offline badge + optional last-seen text.
class UserAvatarWithStatus extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isOnline;
  final String? lastSeen; // e.g. "Online 3 hours ago"
  final bool showLastSeenText;
  final bool isVip;
  final VoidCallback? onTap;

  const UserAvatarWithStatus({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.isOnline = false,
    this.lastSeen,
    this.showLastSeenText = false,
    this.isVip = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              UserAvatar(
                imageUrl: imageUrl,
                radius: radius,
                showVipFrame: isVip,
              ),
              // Online / Offline status dot
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: radius * 0.5,
                  height: radius * 0.5,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF22C55E) : const Color(0xFF6B7280),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showLastSeenText && !isOnline && lastSeen != null) ...[
            const SizedBox(height: 4),
            Text(
              lastSeen!,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.getTextSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (showLastSeenText && isOnline) ...[
            const SizedBox(height: 4),
            const Text(
              'Online',
              style: TextStyle(fontSize: 9, color: Color(0xFF22C55E), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact online status badge widget for use inline.
class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final String? lastSeen;

  const OnlineStatusBadge({super.key, required this.isOnline, this.lastSeen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF22C55E) : const Color(0xFF6B7280),
            shape: BoxShape.circle,
            boxShadow: isOnline
                ? [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.5), blurRadius: 4)]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isOnline ? 'Online' : (lastSeen ?? 'Offline'),
          style: TextStyle(
            fontSize: 11,
            color: isOnline ? const Color(0xFF22C55E) : AppColors.getTextSecondary(isDark),
            fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
