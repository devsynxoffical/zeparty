import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/party_participant_model.dart';
import '../core/utils/noble_badge_helper.dart';

class AnimatedLiveCommentItem extends StatefulWidget {
  final Key? key;
  final String senderId;
  final String senderName;
  final String? avatarUrl;
  final String text;
  final bool isHost;
  final bool isMod;
  final bool isVip;
  final bool isSystem;
  final bool isGift;
  final String? nobleTitle;
  final int wealthLevel;
  final VoidCallback? onTap;

  const AnimatedLiveCommentItem({
    this.key,
    required this.senderId,
    required this.senderName,
    this.avatarUrl,
    required this.text,
    this.isHost = false,
    this.isMod = false,
    this.isVip = false,
    this.isSystem = false,
    this.isGift = false,
    this.nobleTitle,
    this.wealthLevel = 1,
    this.onTap,
  }) : super(key: key);

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
    final isEntryNotice = widget.text.contains('entered the room') || widget.isSystem;

    if (isEntryNotice) {
      final senderAccent = _getSenderColor(widget.senderId);
      final isEntered = widget.text.contains('entered the room');

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
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEntered ? senderAccent.withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
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
                            color: Color(0xFFFFD54F),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
                // Sender Profile Avatar (CR 39)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 7, top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isHost
                          ? Colors.amber
                          : (widget.isVip ? Colors.purpleAccent : nameColor.withValues(alpha: 0.6)),
                      width: 1.2,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(avatarToUse),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: widget.isGift
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
                              : null),
                      color: (!widget.isGift && !widget.isHost)
                          ? (widget.isMod
                              ? const Color(0xFF0D47A1).withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.55))
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.isGift
                            ? const Color(0xFFFF4081).withValues(alpha: 0.6)
                            : (widget.isHost
                                ? Colors.amber.withValues(alpha: 0.4)
                                : (widget.isMod
                                    ? Colors.blueAccent.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.09))),
                        width: 0.8,
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          if (widget.isHost)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 5),
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
                                margin: const EdgeInsets.only(right: 5),
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
                            )
                          else if (widget.isVip)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.purpleAccent, Colors.pinkAccent],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                          TextSpan(
                            text: widget.text,
                            style: TextStyle(
                              color: widget.isGift ? Colors.yellowAccent : Colors.white,
                              fontWeight: widget.isGift ? FontWeight.w700 : FontWeight.w400,
                              fontSize: 12.5,
                            ),
                          ),
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
