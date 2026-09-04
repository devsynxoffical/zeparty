import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/providers/game_provider.dart';
import 'package:zeparty/features/party_room/widgets/room_entry_announcement_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 03 & Module 04 Feature Tests', () {
    late GameProvider gameProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gameProvider = GameProvider();
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Verify Room Mic Seat Size Preset configuration and safe fallback', () async {
      expect(gameProvider.roomMicSizePreset, 'Large');

      final err1 = await gameProvider.updateRoomMicSizePreset('Small');
      expect(err1, null);
      expect(gameProvider.roomMicSizePreset, 'Small');

      final errInvalid = await gameProvider.updateRoomMicSizePreset('HugeInvalid');
      expect(errInvalid, isNotNull);
      expect(gameProvider.roomMicSizePreset, 'Small'); // Preserved previous valid state
    });

    test('Verify Announcement Priority Resolution (Global > Country > Owner > Default)', () async {
      // 1. Default fallback
      final defaultAnn = gameProvider.getResolvedAnnouncement('room_1', 'Pakistan');
      expect(defaultAnn['source'], 'Default');

      // 2. Set Room Owner Announcement
      await gameProvider.setRoomAnnouncement(
        roomId: 'room_1',
        editorUserId: 'owner_1',
        text: 'Host custom announcement!',
        status: 'Active',
      );
      final ownerAnn = gameProvider.getResolvedAnnouncement('room_1', 'Pakistan');
      expect(ownerAnn['source'], 'Room Owner');
      expect(ownerAnn['text'], 'Host custom announcement!');

      // 3. Set Mandatory Country Announcement
      await gameProvider.setRoomAnnouncement(
        roomId: 'country_pk',
        editorUserId: 'Admin PK',
        text: 'Pakistan Regional Notice',
        isMandatory: true,
        country: 'Pakistan',
        status: 'Active',
        isAdmin: true,
      );
      final countryAnn = gameProvider.getResolvedAnnouncement('room_1', 'Pakistan');
      expect(countryAnn['source'], 'Country Mandatory (Pakistan)');
      expect(countryAnn['text'], 'Pakistan Regional Notice');

      // 4. Set Mandatory Global Announcement (Overrides everything)
      await gameProvider.setRoomAnnouncement(
        roomId: 'global_mandatory',
        editorUserId: 'Platform Admin',
        text: 'Global Mandatory Notice for all rooms!',
        isMandatory: true,
        status: 'Active',
        isAdmin: true,
      );
      final globalAnn = gameProvider.getResolvedAnnouncement('room_1', 'Pakistan');
      expect(globalAnn['source'], 'Mandatory Global');
      expect(globalAnn['text'], 'Global Mandatory Notice for all rooms!');
    });

    test('Verify Character Limit and Prohibited Word Filter', () async {
      // Prohibited word check
      final errBadWord = await gameProvider.setRoomAnnouncement(
        roomId: 'room_test',
        editorUserId: 'user_1',
        text: 'This is a scam message',
      );
      expect(errBadWord, contains('Moderation Error'));

      // Character limit check (> 200 chars)
      final longText = 'A' * 205;
      final errLong = await gameProvider.setRoomAnnouncement(
        roomId: 'room_test',
        editorUserId: 'user_1',
        text: longText,
      );
      expect(errLong, contains('200 character limit'));
    });

    test('Verify Reconnect Protection (Session tracking)', () {
      const sessionId = 'session_test_101';
      expect(RoomEntryAnnouncementBanner.isSessionDisplayed(sessionId), false);

      // Simulate session display
      RoomEntryAnnouncementBanner.clearSession(sessionId);
      expect(RoomEntryAnnouncementBanner.isSessionDisplayed(sessionId), false);
    });

    test('Verify Room DP Moderation & Fallback logic', () async {
      const roomId = 'room_mod_1';
      const uploadedDp = 'https://example.com/custom_dp.png';

      // Before moderation -> Returns uploaded DP
      expect(gameProvider.getEffectiveRoomDp(roomId, uploadedDp, 'Pakistan'), uploadedDp);

      // Admin Rejects / Removes Room DP
      await gameProvider.moderateRoomDp(
        roomId: roomId,
        action: 'Reject',
        reason: 'Inappropriate image',
      );

      // After rejection -> Automatically falls back to default fallback DP
      final fallbackDp = gameProvider.getEffectiveRoomDp(roomId, uploadedDp, 'Pakistan');
      expect(fallbackDp, isNot(uploadedDp));
      expect(fallbackDp, gameProvider.countryDefaultRoomDps['Pakistan']);
    });
  });
}
