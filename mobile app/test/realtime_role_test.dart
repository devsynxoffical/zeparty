// Drives the app's real SocketService + LivePartyProvider against a local backend.
// Run twice concurrently: --dart-define=ROLE=host and --dart-define=ROLE=guest.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/core/config/app_config.dart';
import 'package:zeparty/core/services/api_client.dart';
import 'package:zeparty/core/services/socket_service.dart';
import 'package:zeparty/models/live_room_model.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/providers/live_party_provider.dart';

const role = String.fromEnvironment('ROLE', defaultValue: 'host');
const phone = String.fromEnvironment('PHONE', defaultValue: '+923001110001');
// Two-process end-to-end test against a local backend. Skipped unless run with
//   flutter test test/realtime_role_test.dart --dart-define=E2E_BACKEND=http://127.0.0.1:8081/api --dart-define=ROLE=host
const base = String.fromEnvironment('E2E_BACKEND', defaultValue: '');
final roomFile = File('/tmp/claude-0/e2e_room.txt');

Future<UserModel> login() async {
  final api = ApiClient.instance;
  await api.post('/v1/auth/request-otp', data: {'phone': phone, 'purpose': 'LOGIN'});
  // In production mode the code is not returned; the mock provider logs it. Read it from the server log.
  String? code;
  for (var i = 0; i < 20 && code == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final lines = File('/tmp/claude-0/backend_prod.log').readAsLinesSync().reversed;
    for (final l in lines) {
      if (l.contains('"destination":"$phone"') && l.contains('"otp":"')) {
        code = RegExp(r'"otp":"(\d+)"').firstMatch(l)?.group(1);
        break;
      }
    }
  }
  if (code == null) throw StateError('no OTP found in server log for $phone');
  final r2 = await api.post('/v1/auth/verify-otp', data: {'phone': phone, 'code': code, 'purpose': 'LOGIN', 'device': {'platform': 'ANDROID'}});
  final d = r2.data['data'] as Map<String, dynamic>;
  await api.saveTokens(accessToken: d['accessToken'] as String, refreshToken: d['refreshToken'] as String);
  return UserModel.fromJson(Map<String, dynamic>.from(d['user'] as Map));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // flutter_test installs a mock HttpClient that answers 400 to everything
  SharedPreferences.setMockInitialValues({});
  test('realtime $role', skip: base.isEmpty ? 'needs --dart-define=E2E_BACKEND' : false, () async {
    AppConfig.initialize(customBaseUrl: base);
    final user = await login();
    debugPrint('[$role] logged in as ${user.id} / ${user.username}');
    final provider = LivePartyProvider();
    final joinSeen = <String>[];
    final sub = SocketService.instance.userJoinedStream.listen((d) => joinSeen.add((d['userId'] ?? d['user']?['id'] ?? '?').toString()));

    LiveRoomModel room;
    if (role == 'host') {
      final c = await ApiClient.instance.post('/v1/rooms', data: {'title': 'Flutter E2E Party', 'roomType': 'AUDIO_PARTY', 'forceNew': true});
      final rd = c.data['data'];
      room = LiveRoomModel.fromJson(Map<String, dynamic>.from((rd['room'] ?? rd) as Map));
      roomFile.writeAsStringSync(room.id);
      debugPrint('[$role] created room ${room.id}');
    } else {
      // Wait for the host process to publish the room id (it may still be logging in / creating).
      for (var i = 0; i < 120 && !roomFile.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      final id = roomFile.readAsStringSync().trim();
      final r = await ApiClient.instance.get('/v1/rooms/$id');
      room = LiveRoomModel.fromJson(Map<String, dynamic>.from(r.data['data'] as Map));
      debugPrint('[$role] fetched room ${room.id} status=${room.status}');
    }
    var ok = await provider.joinParty(room, user);
    debugPrint('[$role] joinParty -> $ok activeRoom=${provider.activeRoom?.id} socketConnected=${SocketService.instance.isConnected}');
    if (role == 'host' && const bool.fromEnvironment('RACE')) {
      // What the phone does when the host backs out and re-enters quickly: the screen's dispose()
      // calls leaveParty() without awaiting it, and the next screen's initState calls joinParty().
      // ignore: unawaited_futures
      provider.leaveParty();
      ok = await provider.joinParty(room, user);
      debugPrint('[$role] RACE re-join -> $ok activeRoom=${provider.activeRoom?.id}');
    }

    final giftEvents = <String>[];
    final giftSub = SocketService.instance.giftSentStream.listen((d) => giftEvents.add('${d['giftId']}:${d['senderUserId']}'));
    if (role == 'guest') {
      await Future<void>.delayed(const Duration(seconds: 3));
      provider.sendMessage(user, 'hello from guest');
      debugPrint('[$role] sent chat');
      // Gift flow exactly as the gift dialog does it: REST /v1/gifts/send with the room id.
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        for (final giftId in ['cg01', 'lg01']) {
          final g = await ApiClient.instance.post('/v1/gifts/send', data: {'giftId': giftId, 'recipientUserId': room.host.id, 'quantity': 1, 'roomId': room.id});
          debugPrint('[$role] gift $giftId sent: ${g.data['success']} tx=${g.data['data']?['transactionId']}');
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('[$role] GIFT SEND FAILED: $e');
      }
      await Future<void>.delayed(const Duration(seconds: 8));
      final sawHost = provider.messages.any((m) => m.text.contains('hello from host'));
      debugPrint('[$role] RESULT sawHostChat=$sawHost joinEventsSeen=$joinSeen participants=${provider.participants.length} messages=${provider.messages.length} giftEvents=$giftEvents');
    } else {
      await Future<void>.delayed(const Duration(seconds: 14));
      provider.sendMessage(user, 'hello from host');
      await Future<void>.delayed(const Duration(seconds: 8));
      final sawGuest = provider.messages.any((m) => m.text.contains('hello from guest'));
      final sawGift = provider.messages.any((m) => m.isGiftMessage);
      debugPrint('[$role] RESULT sawGuestChat=$sawGuest sawGuestGift=$sawGift giftEvents=$giftEvents joinEventsSeen=$joinSeen participants=${provider.participants.length} messages=${provider.messages.length} texts=${provider.messages.map((m) => m.text).toList()}');
    }
    await giftSub.cancel();
    await sub.cancel();
  }, timeout: const Timeout(Duration(seconds: 120)));
}
