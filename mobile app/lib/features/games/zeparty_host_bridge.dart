import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../../core/services/agora_rtc_service.dart';
import '../../providers/room_overlay_provider.dart';
import '../profile/user_profile_details_screen.dart';

/// Connects the premium games to the ZeParty host app: haptics, profile
/// navigation, local mic control and voice activity (for music ducking).
///
/// The games never capture or play voice; they only observe it through here.
class ZePartyAppHostBridge extends ZePartyHostBridge {
  ZePartyAppHostBridge();

  final AgoraRtcService _agora = AgoraRtcService.instance;

  @override
  Stream<bool> get voiceActive {
    // Agora reports the currently loudest speaker; while someone is talking we
    // emit true and fall back to false once activity stops for two seconds.
    late final StreamController<bool> controller;
    StreamSubscription<int>? sub;
    Timer? idle;
    controller = StreamController<bool>.broadcast(
      onListen: () {
        sub = _agora.activeSpeakerStream.listen((_) {
          controller.add(true);
          idle?.cancel();
          idle = Timer(const Duration(seconds: 2), () => controller.add(false));
        });
      },
      onCancel: () {
        sub?.cancel();
        idle?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> setLocalMuted(bool muted) async {
    if (!_agora.isInitialized) return;
    try {
      await _agora.muteLocalAudio(muted);
    } catch (_) {}
  }

  @override
  Future<void> openProfile(String userId) async {
    final nav = RoomOverlayProvider.navigatorKey.currentState;
    if (nav == null || userId.isEmpty) return;
    await nav.push(MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: userId)));
  }

  @override
  Future<void> haptic(HapticKind kind) async {
    switch (kind) {
      case HapticKind.light:
        await HapticFeedback.lightImpact();
      case HapticKind.medium:
        await HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        await HapticFeedback.heavyImpact();
      case HapticKind.success:
        await HapticFeedback.mediumImpact();
      case HapticKind.error:
        await HapticFeedback.vibrate();
    }
  }
}
