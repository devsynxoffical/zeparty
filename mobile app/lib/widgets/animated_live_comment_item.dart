import 'package:flutter/material.dart';
import '../core/constants/room_emoji_catalog.dart';
import '../core/constants/animated_gifts_catalog.dart';
import '../models/gift_model.dart';
import '../core/utils/noble_badge_helper.dart';
import 'user_avatar.dart';

class AnimatedLiveCommentItem extends StatefulWidget {
  final String senderId;
  final String senderName;
  final String? avatarUrl;
  final String text;
  final bool isHost;
  final bool isMod;
  final bool isVip;
  final bool isSystem;
  final bool isGift;
  final String? giftId;
  final String? giftName;
  final String? giftIcon;
  final String? nobleTitle;
  final String? avatarFrame;
  final String? chatBubble;
  final int wealthLevel;
  final VoidCallback? onTap;

  const AnimatedLiveCommentItem({
    super.key,
    required this.senderId,
    required this.senderName,
    this.avatarUrl,
    required this.text,
    this.isHost = false,
    this.isMod = false,
    this.isVip = false,
    this.isSystem = false,
    this.isGift = false,
    this.giftId,
    this.giftName,
    this.giftIcon,
    this.nobleTitle,
    this.avatarFrame,
    this.chatBubble,
    this.wealthLevel = 1,
    this.onTap,
  });

  @override
  State<AnimatedLiveCommentItem> createState() => _AnimatedLiveCommentItemState();
}

class _AnimatedLiveCommentItemState extends State<AnimatedLiveCommentItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.25, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getSenderColor(String id) {
    if (id.isEmpty || id == 'system') return const Color(0xFFFFD54F);
    final palette = [
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFFF4081), // Pink Accent
      const Color(0xFF00E676), // Bright Green
      const Color(0xFFFFD54F), // Amber Gold
      const Color(0xFFB388FF), // Purple Accent
      const Color(0xFFFF6E40), // Deep Orange
      const Color(0xFF40C4FF), // Light Blue
    ];
    return palette[id.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isEntryNotice = widget.text.contains('entered the room') ||
        widget.text.contains('joined the party') ||
        widget.text.contains('has joined') ||
        widget.isSystem;

    if (isEntryNotice) {
      final senderAccent = _getSenderColor(widget.senderId);
      final isEntered = widget.text.contains('entered the room');
      final badgeAsset = NobleBadgeHelper.getBadgeAsset(
        widget.nobleTitle ?? (widget.isVip ? 'Baron' : null),
      );
      final hasAvatar = widget.avatarUrl != null &&
          widget.avatarUrl!.isNotEmpty &&
          widget.senderId != 'system';

      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEntered ? senderAccent.withValues(alpha: 0.4) : const Color(0xFFFFD54F).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasAvatar) ...[
                        UserAvatar(
                          imageUrl: widget.avatarUrl!,
                          name: widget.senderName,
                          radius: 9,
                          showVipFrame: widget.isVip,
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (badgeAsset != null) ...[
                        Image.asset(
                          badgeAsset,
                          height: 14,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: isEntered
                            ? RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.senderName.isNotEmpty ? widget.senderName : widget.senderId,
                                      style: TextStyle(
                                        color: senderAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' entered the room',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Text(
                                widget.text,
                                style: const TextStyle(
                                  color: Color(0xFFFFE082),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final nameColor = widget.nobleTitle != null && widget.nobleTitle!.isNotEmpty
        ? NobleBadgeHelper.getColoredNicknameColor(
            NobleBadgeHelper.getTierFromTitle(widget.nobleTitle),
          )
        : (widget.isHost
            ? const Color(0xFFFFD54F)
            : (widget.isMod ? const Color(0xFF64B5F6) : _getSenderColor(widget.senderId)));

    final defaultAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';
    final avatarToUse = (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) ? widget.avatarUrl! : defaultAvatar;

    final hasCustomBubble = widget.chatBubble != null && widget.chatBubble!.isNotEmpty && widget.chatBubble != 'none';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender Profile Avatar with Frame Overlay
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: UserAvatar(
                    imageUrl: avatarToUse,
                    name: widget.senderName,
                    radius: 14,
                    showVipFrame: widget.isVip,
                    frameAsset: (widget.avatarFrame != null && widget.avatarFrame!.isNotEmpty && widget.avatarFrame != 'none')
                        ? widget.avatarFrame
                        : (widget.nobleTitle != null && widget.nobleTitle!.isNotEmpty
                            ? NobleBadgeHelper.getFrameAsset(widget.nobleTitle)
                            : (widget.isVip ? NobleBadgeHelper.getFrameAsset('Baron') : null)),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: hasCustomBubble
                        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
                        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      image: hasCustomBubble
                          ? DecorationImage(
                              image: (widget.chatBubble!.startsWith('http://') || widget.chatBubble!.startsWith('https://'))
                                  ? NetworkImage(widget.chatBubble!) as ImageProvider
                                  : AssetImage(widget.chatBubble!),
                              fit: BoxFit.fill,
                            )
                          : null,
                      gradient: !hasCustomBubble
                          ? (widget.isGift
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFFE91E63).withValues(alpha: 0.45),
                                    const Color(0xFF880E4F).withValues(alpha: 0.3),
                                  ],
                                )
                              : (widget.isHost
                                  ? LinearGradient(
                                      colors: [
                                        const Color(0xFF4A148C).withValues(alpha: 0.5),
                                        const Color(0xFF311B92).withValues(alpha: 0.35),
                                      ],
                                    )
                                  : null))
                          : null,
                      color: (!hasCustomBubble && !widget.isGift && !widget.isHost)
                          ? (widget.isMod
                              ? const Color(0xFF0D47A1).withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.55))
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: !hasCustomBubble
                          ? Border.all(
                              color: widget.isGift
                                  ? const Color(0xFFFF4081).withValues(alpha: 0.6)
                                  : (widget.isHost
                                      ? Colors.amber.withValues(alpha: 0.4)
                                      : (widget.isMod
                                          ? Colors.blueAccent.withValues(alpha: 0.35)
                                          : Colors.white.withValues(alpha: 0.09))),
                              width: 0.8,
                            )
                          : null,
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          if (widget.isHost)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Host',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            )
                          else if (widget.isMod)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2979FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Mod',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),

                          // Real Noble/SVIP/Role PNG Badge Asset
                          if (NobleBadgeHelper.getBadgeAsset(widget.nobleTitle ?? (widget.isVip ? 'Baron' : (widget.isHost ? 'Host' : (widget.isMod ? 'Admin' : null)))) != null)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Image.asset(
                                  NobleBadgeHelper.getBadgeAsset(widget.nobleTitle ?? (widget.isVip ? 'Baron' : (widget.isHost ? 'Host' : (widget.isMod ? 'Admin' : null))))!,
                                  height: 16,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                              ),
                            ),

                          TextSpan(
                            text: '${widget.senderName}: ',
                            style: TextStyle(
                              color: nameColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          ...() {
                            final emojiItem = RoomEmojiCatalog.findByReactionString(widget.text);
                            if (emojiItem != null) {
                              return [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Image.asset(
                                      emojiItem.iconAsset,
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Text(
                                        emojiItem.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ];
                            }

                            // Issue 54 Requirement D: Replace generic gift box emoji with actual sent gift artwork
                            if (widget.isGift || widget.text.contains('🎁')) {
                              // 1. Resolve matching gift from explicit params or text regex
                              GiftModel? matchedGift;
                              if (widget.giftId != null && widget.giftId!.isNotEmpty) {
                                matchedGift = AnimatedGiftsCatalog.allGifts.where(
                                  (g) => g.id.toLowerCase() == widget.giftId!.toLowerCase(),
                                ).firstOrNull;
                              }
                              if (matchedGift == null && widget.giftName != null && widget.giftName!.isNotEmpty) {
                                final searchName = widget.giftName!.toLowerCase();
                                matchedGift = AnimatedGiftsCatalog.allGifts.where(
                                  (g) => g.name.toLowerCase() == searchName || g.id.toLowerCase() == searchName,
                                ).firstOrNull;
                              }

                              String? extractedName;
                              final xMatch = RegExp(r'×\s*(.+?)(?:\s*🎁|\s*to|\s*!|$)', caseSensitive: false).firstMatch(widget.text);
                              if (xMatch != null) {
                                extractedName = xMatch.group(1)?.trim();
                              } else {
                                final sentMatch = RegExp(r'sent\s+\d*\s*×?\s*(.+?)(?:\s*🎁|\s*to|\s*!|$)', caseSensitive: false).firstMatch(widget.text);
                                if (sentMatch != null) {
                                  extractedName = sentMatch.group(1)?.trim();
                                }
                              }

                              if (matchedGift == null && extractedName != null && extractedName.isNotEmpty) {
                                final searchName = extractedName.toLowerCase();
                                matchedGift = AnimatedGiftsCatalog.allGifts.where(
                                  (g) => g.name.toLowerCase() == searchName || g.id.toLowerCase() == searchName,
                                ).firstOrNull;
                              }

                              final String? iconPath = matchedGift?.icon ?? widget.giftIcon;

                              Widget buildActualGiftWidget() {
                                if (iconPath != null && iconPath.isNotEmpty) {
                                  const blackMatrix = <double>[
                                    1.0, 0.0, 0.0, 0.0, 0.0,
                                    0.0, 1.0, 0.0, 0.0, 0.0,
                                    0.0, 0.0, 1.0, 0.0, 0.0,
                                    3.0, 3.0, 3.0, 0.0, -45.0,
                                  ];
                                  final img = iconPath.startsWith('assets/')
                                      ? Image.asset(
                                          iconPath,
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                          errorBuilder: (ctx, err, stack) => const Text('🎁', style: TextStyle(fontSize: 14)),
                                        )
                                      : (iconPath.startsWith('http')
                                          ? Image.network(
                                              iconPath,
                                              width: 24,
                                              height: 24,
                                              fit: BoxFit.contain,
                                              errorBuilder: (ctx, err, stack) => const Text('🎁', style: TextStyle(fontSize: 14)),
                                            )
                                          : Text(iconPath, style: const TextStyle(fontSize: 14)));

                                  return ColorFiltered(
                                    colorFilter: const ColorFilter.matrix(blackMatrix),
                                    child: img,
                                  );
                                }
                                return const Text('🎁', style: TextStyle(fontSize: 14));
                              }

                              if (widget.text.contains('🎁')) {
                                final parts = widget.text.split('🎁');
                                final prefix = parts[0];
                                final suffix = parts.sublist(1).join('🎁');

                                return [
                                  TextSpan(
                                    text: prefix,
                                    style: const TextStyle(
                                      color: Colors.yellowAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: buildActualGiftWidget(),
                                    ),
                                  ),
                                  TextSpan(
                                    text: suffix,
                                    style: const TextStyle(
                                      color: Colors.yellowAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ];
                              } else if (widget.isGift) {
                                return [
                                  TextSpan(
                                    text: widget.text,
                                    style: const TextStyle(
                                      color: Colors.yellowAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: buildActualGiftWidget(),
                                    ),
                                  ),
                                ];
                              }
                            }

                            return [
                              TextSpan(
                                text: widget.text,
                                style: TextStyle(
                                  color: widget.isGift ? Colors.yellowAccent : Colors.white,
                                  fontWeight: widget.isGift ? FontWeight.w700 : FontWeight.w400,
                                  fontSize: 12.5,
                                ),
                              ),
                            ];
                          }(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
