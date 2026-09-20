import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gift_model.dart';
import '../models/live_gift_event_model.dart';
import '../providers/live_gift_provider.dart';
import 'basic_gift_animator.dart';
import 'standard_gift_animator.dart';
import 'premium_gift_animator.dart';
import 'legendary_gift_animator.dart';

/// TikTok-Style Live Gifting Animation Stack Overlay Layer.
/// Manages 4-level gift animations without blocking live room controls.
class TikTokGiftOverlay extends StatelessWidget {
  final String roomId;

  const TikTokGiftOverlay({
    super.key,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveGiftProvider>(
      builder: (context, provider, child) {
        final activeEvent = provider.currentActiveEvent;
        if (activeEvent == null) return const SizedBox.shrink();

        return IgnorePointer(
          ignoring: activeEvent.animationLevel != GiftAnimationLevel.legendary,
          child: _buildLevelAnimator(context, provider, activeEvent),
        );
      },
    );
  }

  Widget _buildLevelAnimator(
    BuildContext context,
    LiveGiftProvider provider,
    LiveGiftEventModel event,
  ) {
    void onComplete() {
      provider.onCurrentEventCompleted();
    }

    switch (event.animationLevel) {
      case GiftAnimationLevel.basic:
        return BasicGiftAnimator(
          key: ValueKey('anim_${event.eventId}_${event.comboCount}'),
          event: event,
          onComplete: onComplete,
        );
      case GiftAnimationLevel.standard:
        return StandardGiftAnimator(
          key: ValueKey('anim_${event.eventId}_${event.comboCount}'),
          event: event,
          onComplete: onComplete,
        );
      case GiftAnimationLevel.premium:
        return PremiumGiftAnimator(
          key: ValueKey('anim_${event.eventId}_${event.comboCount}'),
          event: event,
          onComplete: onComplete,
        );
      case GiftAnimationLevel.legendary:
        return LegendaryGiftAnimator(
          key: ValueKey('anim_${event.eventId}_${event.comboCount}'),
          event: event,
          onComplete: onComplete,
        );
    }
  }
}
