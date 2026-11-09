// Host side of the two-process gift animation test. Mounts the real overlays the party room
// uses and checks that a REMOTE gift (sent by the guest process) triggers them.
//   flutter test test/realtime_gift_anim_test.dart --dart-define=E2E_BACKEND=http://127.0.0.1:8081/api --dart-define=PHONE=+92300...
//   flutter test test/realtime_role_test.dart --dart-define=E2E_BACKEND=... --dart-define=ROLE=guest --dart-define=PHONE=+92300...
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/core/config/app_config.dart';
import 'package:zeparty/core/services/api_client.dart';
import 'package:zeparty/core/services/socket_service.dart';
import 'package:zeparty/models/live_room_model.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/providers/live_gift_provider.dart';
import 'package:zeparty/providers/live_party_provider.dart';
import 'package:zeparty/widgets/gift_animation_overlay.dart';
import 'package:zeparty/widgets/tiktok_gift_overlay.dart';

const phone = String.fromEnvironment('PHONE', defaultValue: '+923001110021');
const base = String.fromEnvironment('E2E_BACKEND', defaultValue: '');
final roomFile = File('/tmp/claude-0/e2e_room.txt');

Future<UserModel> login() async {
  final api = ApiClient.instance;
  await api.post('/v1/auth/request-otp', data: {'phone': phone, 'purpose': 'LOGIN'});
  String? code;
  for (var i = 0; i < 20 && code == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final l in File('/tmp/claude-0/backend_prod.log').readAsLinesSync().reversed) {
      if (l.contains('"destination":"$phone"') && l.contains('"otp":"')) {
        code = RegExp(r'"otp":"(\d+)"').firstMatch(l)?.group(1);
        break;
      }
    }
  }
  final r2 = await api.post('/v1/auth/verify-otp', data: {'phone': phone, 'code': code, 'purpose': 'LOGIN', 'device': {'platform': 'ANDROID'}});
  final d = r2.data['data'] as Map<String, dynamic>;
  await api.saveTokens(accessToken: d['accessToken'] as String, refreshToken: d['refreshToken'] as String);
  return UserModel.fromJson(Map<String, dynamic>.from(d['user'] as Map));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});
  testWidgets('remote gifts trigger the host overlays', skip: base.isEmpty, (tester) async {
    await tester.runAsync(() async {
      AppConfig.initialize(customBaseUrl: base);
      final user = await login();
      final party = LivePartyProvider();
      final gifts = LiveGiftProvider();
      final c = await ApiClient.instance.post('/v1/rooms', data: {'title': 'Flutter E2E Party', 'roomType': 'AUDIO_PARTY', 'forceNew': true});
      final rd = c.data['data'];
      final room = LiveRoomModel.fromJson(Map<String, dynamic>.from((rd['room'] ?? rd) as Map));
      roomFile.writeAsStringSync(room.id);
      await party.joinParty(room, user);
      final roomId = party.activeRoom?.id ?? room.id;
      gifts.setActiveRoom(roomId, alternativeIds: {room.id});
      debugPrint('[host] in room $roomId');

      final overlayKey = GlobalKey<GiftAnimationOverlayState>();
      final seenVideo = <String>[];
      final seenCombo = <String>[];
      gifts.addListener(() {
        final e = gifts.currentActiveEvent;
        if (e != null && !seenCombo.contains(e.eventId)) seenCombo.add('${e.giftId}:${e.eventId}');
      });
      final rawGifts = <String>[];
      final sub = SocketService.instance.onGiftSent.listen((d) => rawGifts.add('${d['giftId']}'));

      await tester.pumpWidget(ChangeNotifierProvider<LiveGiftProvider>.value(
        value: gifts,
        child: MaterialApp(home: Scaffold(body: Stack(children: [
          GiftAnimationOverlay(key: overlayKey, roomId: roomId, alternativeIds: {room.id}),
          TikTokGiftOverlay(roomId: roomId, alternativeIds: {room.id}),
        ]))),
      ));

      // Watch for ~30 s while the guest joins and sends cg01 (MP4) then lg01 (lucky, non-video).
      for (var i = 0; i < 300; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        final st = overlayKey.currentState;
        final g = st?.currentGift;
        if (g != null && !seenVideo.contains(g.id)) seenVideo.add(g.id);
      }
      debugPrint('[host] RESULT rawGiftEvents=$rawGifts videoOverlayGifts=$seenVideo comboEvents=$seenCombo participants=${party.participants.length} giftMsgs=${party.messages.where((m) => m.isGiftMessage).length}');
      await sub.cancel();
    });
  }, timeout: const Timeout(Duration(seconds: 150)));
}
