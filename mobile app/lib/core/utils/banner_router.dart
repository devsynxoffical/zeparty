import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/store/store_screen.dart';
import '../../features/vip/vip_store_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../features/games/game_lobby_screen.dart';
import '../../features/social/short_videos_screen.dart';
import '../../features/party_room/live_party_room_screen.dart';
import '../../models/live_room_model.dart';
import '../../models/user_model.dart';

class BannerRouter {
  /// Route deep links (`zeparty://...` or `https://...`) from banner taps
  static void handleBannerTap(
    BuildContext context,
    String? destinationUrl, {
    VoidCallback? onPartyTap,
    VoidCallback? onLiveTap,
  }) {
    if (destinationUrl == null || destinationUrl.trim().isEmpty) return;

    final cleanUrl = destinationUrl.trim();
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) return;

    if (uri.scheme == 'zeparty') {
      final host = uri.host.toLowerCase();
      final pathSegments = uri.pathSegments;

      switch (host) {
        case 'party':
          if (onPartyTap != null) {
            onPartyTap();
          } else {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          break;
        case 'live':
          if (onLiveTap != null) {
            onLiveTap();
          } else {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          break;
        case 'store':
        case 'gifts':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreScreen()));
          break;
        case 'recharge':
        case 'wallet':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
          break;
        case 'vip':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const VipStoreScreen()));
          break;
        case 'games':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLobbyScreen()));
          break;
        case 'shorts':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ShortVideosScreen()));
          break;
        case 'room':
          final roomId = pathSegments.isNotEmpty ? pathSegments.first : null;
          if (roomId != null && roomId.isNotEmpty) {
            final targetRoom = LiveRoomModel(
              id: roomId,
              title: 'Voice Room #$roomId',
              host: UserModel(
                id: 'host',
                username: 'host',
                name: 'Host',
                avatarUrl: '',
                bio: '',
                gender: 'M',
                region: 'PK',
              ),
              coverUrl: '',
              viewerCount: 1,
              category: 'PARTY',
              startTime: DateTime.now(),
              roomType: 'AUDIO_PARTY',
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: targetRoom)),
            );
          } else if (onPartyTap != null) {
            onPartyTap();
          }
          break;
        default:
          if (onPartyTap != null) {
            onPartyTap();
          }
          break;
      }
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
