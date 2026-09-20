import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/animations/app_animations.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final bool isLive;
  final bool showVipFrame;
  final bool isPremium;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
    this.isLive = false,
    this.showVipFrame = false,
    this.isPremium = false,
    this.onTap,
  });

  bool _isValidRemoteOrLocal(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return true;
    if (trimmed.startsWith('assets/')) return true;
    if (trimmed.startsWith('/') || trimmed.startsWith('file://')) return true;
    try {
      final f = File(trimmed.replaceFirst('file://', ''));
      return f.existsSync() && f.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  String _getInitials(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return 'Z';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.trim().substring(0, 1).toUpperCase();
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.getPrimary(isDark),
            AppColors.accent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.85,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValidImage = _isValidRemoteOrLocal(imageUrl);

    Widget avatarContent;
    if (hasValidImage) {
      final clean = imageUrl!.trim().replaceFirst('file://', '');
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        avatarContent = ClipOval(
          child: Image.network(
            clean,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(isDark),
          ),
        );
      } else if (clean.startsWith('assets/')) {
        avatarContent = ClipOval(
          child: Image.asset(
            clean,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(isDark),
          ),
        );
      } else {
        avatarContent = ClipOval(
          child: Image.file(
            File(clean),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(isDark),
          ),
        );
      }
    } else {
      avatarContent = _buildPlaceholder(isDark);
    }

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
      child: avatarContent,
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
