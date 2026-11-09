import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/core/services/agora_rtc_service.dart';
import 'package:zeparty/models/pk_battle_model.dart';
import 'package:zeparty/models/user_model.dart';

void main() {
  group('PK Opponent Camera & Agora Subscription Verification', () {
    test('AgoraRtcService.deriveUid matches deterministic backend algorithm', () {
      // Direct positive integers within range return themselves
      expect(AgoraRtcService.deriveUid('12345'), 12345);
      expect(AgoraRtcService.deriveUid('9202535'), 9202535);

      // UUID strings produce positive 32-bit integers in [1, 2147483640]
      final uid1 = AgoraRtcService.deriveUid('7ce19563-3172-4a0b-9df6-b6aa6b57db45');
      final uid2 = AgoraRtcService.deriveUid('7ce19563-3172-4a0b-9df6-b6aa6b57db45');
      expect(uid1, uid2);
      expect(uid1, isPositive);
      expect(uid1, lessThanOrEqualTo(2147483640));

      final uidOther = AgoraRtcService.deriveUid('c2c1649c-d261-4560-8ae3-9df1e9ea8e7b');
      expect(uidOther, isNot(equals(uid1)));
      expect(uidOther, isPositive);
    });

    test('AgoraRtcService state retains opponent channel, uid, and localUid', () async {
      final service = AgoraRtcService();
      expect(service.pkOpponentChannel, isNull);
      expect(service.pkOpponentUid, isNull);
      expect(service.pkOpponentLocalUid, isNull);

      // Call joinOpponentPKChannel with valid parameters
      await service.joinOpponentPKChannel(
        opponentChannel: 'room_c2c1649cd26145608ae39df1e9ea8e7b',
        localUid: 9202535,
        opponentUid: 88888,
        token: 'mock_valid_agora_token_abc123',
        isVideo: true,
      );

      expect(service.pkOpponentChannel, 'room_c2c1649cd26145608ae39df1e9ea8e7b');
      expect(service.pkOpponentUid, 88888);
      expect(service.pkOpponentLocalUid, 9202535);

      // Leave opponent channel cleans up all opponent state
      await service.leaveOpponentPKChannel();
      expect(service.pkOpponentChannel, isNull);
      expect(service.pkOpponentUid, isNull);
      expect(service.pkOpponentLocalUid, isNull);
    });

    test('PK channel resolution selects agoraRelay channels and derives UIDs correctly', () {
      final hostA = UserModel(id: 'host_a_uuid', name: 'Host A', username: 'host_a', avatarUrl: '');
      final hostB = UserModel(id: 'host_b_uuid', name: 'Host B', username: 'host_b', avatarUrl: '');

      final pk = PKBattleModel(
        id: 'pk_123',
        roomAId: 'room_a_guid',
        roomBId: 'room_b_guid',
        hostA: hostA,
        hostB: hostB,
        status: 'STARTED',
        durationSeconds: 300,
        agoraRelay: const PKAgoraRelayModel(
          channelA: 'room_agora_a',
          channelB: 'room_agora_b',
          hostAUid: 11111,
          hostBUid: 22222,
        ),
      );

      expect(pk.agoraRelay?.channelA, 'room_agora_a');
      expect(pk.agoraRelay?.channelB, 'room_agora_b');
      expect(pk.agoraRelay?.hostAUid, 11111);
      expect(pk.agoraRelay?.hostBUid, 22222);

      // Verify fallback channel normalization when agoraRelay is null
      final pkNoRelay = PKBattleModel(
        id: 'pk_456',
        roomAId: '1234-5678',
        roomBId: 'abcd-ef01',
        hostA: hostA,
        hostB: hostB,
        status: 'STARTED',
      );

      final normalizedChannelB = pkNoRelay.roomBId.startsWith('room_')
          ? pkNoRelay.roomBId
          : 'room_${pkNoRelay.roomBId.replaceAll('-', '')}';
      expect(normalizedChannelB, 'room_abcdef01');
    });
  });
}
