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
import 'package:zeparty/providers/live_provider.dart';

const role = String.fromEnvironment('ROLE', defaultValue: 'host');
const phone = String.fromEnvironment('PHONE', defaultValue: '+923001110001');
// Two-process end-to-end test against a local backend. Skipped unless run with
//   flutter test test/realtime_role_test.dart --dart-define=E2E_BACKEND=http://127.0.0.1:8081/api --dart-define=ROLE=host
const base = String.fromEnvironment('E2E_BACKEND', defaultValue: '');
final roomFile = File('/tmp/claude-0/e2e_live_room.txt');

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
    final provider = LiveProvider();
    final joinSeen = <String>[];
    final sub = SocketService.instance.userJoinedStream.listen((d) => joinSeen.add((d['userId'] ?? d['user']?['id'] ?? '?').toString()));

    LiveRoomModel room;
    if (role == 'host') {
      final c = await ApiClient.instance.post('/v1/rooms', data: {'title': 'Flutter E2E Live', 'roomType': 'LIVE_VIDEO'});
      final rd = c.data['data'];
      room = LiveRoomModel.fromJson(Map<String, dynamic>.from((rd['room'] ?? rd) as Map));
      roomFile.writeAsStringSync(room.id);
      debugPrint('[$role] created room ${room.id}');
    } else {
      for (var i = 0; i < 120 && !roomFile.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      final id = roomFile.readAsStringSync().trim();
      final r = await ApiClient.instance.get('/v1/rooms/$id');
      room = LiveRoomModel.fromJson(Map<String, dynamic>.from(r.data['data'] as Map));
      debugPrint('[$role] fetched room ${room.id} status=${room.status}');
    }
    await provider.joinRoom(room, currentUser: user); var ok = provider.activeRoom != null;
    if (role == 'host' && const bool.fromEnvironment('RACE')) {
      // ignore: unawaited_futures
      provider.leaveRoom();
      await provider.joinRoom(room, currentUser: user);
      ok = provider.activeRoom != null;
      debugPrint('[$role] RACE re-join -> $ok');
    }
    debugPrint('[$role] joinParty -> $ok activeRoom=${provider.activeRoom?.id} socketConnected=${SocketService.instance.isConnected}');

    if (role == 'guest') {
      await Future<void>.delayed(const Duration(seconds: 3));
      provider.sendMessage('hello from guest', user.username, user: user);
      debugPrint('[$role] sent chat');
      await Future<void>.delayed(const Duration(seconds: 10));
      final sawHost = provider.messages.any((m) => m.text.contains('hello from host'));
      debugPrint('[$role] RESULT sawHostChat=$sawHost joinEventsSeen=$joinSeen viewers=${provider.viewers.length} messages=${provider.messages.length}');
    } else {
      await Future<void>.delayed(const Duration(seconds: 14));
      provider.sendMessage('hello from host', user.username, user: user);
      await Future<void>.delayed(const Duration(seconds: 8));
      final sawGuest = provider.messages.any((m) => m.text.contains('hello from guest'));
      debugPrint('[$role] RESULT sawGuestChat=$sawGuest joinEventsSeen=$joinSeen viewers=${provider.viewers.length} messages=${provider.messages.length} texts=${provider.messages.map((m) => m.text).toList()}');
    }
    await sub.cancel();
  }, timeout: const Timeout(Duration(seconds: 120)));
}
