import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/providers/live_party_provider.dart';
import 'package:zeparty/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 05 & Module 06 Feature Tests', () {
    late LivePartyProvider partyProvider;

    const senderUser = UserModel(
      id: 'u_sender_101',
      username: 'danial_k',
      name: 'Danial Khan',
      avatarUrl: 'https://example.com/sender.png',
    );

    const receiverUser = UserModel(
      id: 'u_receiver_202',
      username: 'sophia_r',
      name: 'Sophia Rose',
      avatarUrl: 'https://example.com/receiver.png',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      partyProvider = LivePartyProvider();
    });

    test('Verify Module 05 Gift Activity Message formatting and transaction deduplication', () {
      const txId = 'tx_gift_999';

      // 1. Send first gift activity message
      partyProvider.sendGiftActivityMessage(
        sender: senderUser,
        receiver: receiverUser,
        giftId: 'g_rose',
        giftName: 'Rose',
        giftIcon: '🌹',
        quantity: 5,
        transactionId: txId,
      );

      final msgList = partyProvider.messages;
      expect(msgList.isNotEmpty, true);
      final lastMsg = msgList.last;

      expect(lastMsg.isGiftMessage, true);
      expect(lastMsg.sender.id, senderUser.id);
      expect(lastMsg.receiver?.id, receiverUser.id);
      expect(lastMsg.quantity, 5);
      expect(lastMsg.text, 'Danial Khan sent 5 × Rose 🌹 to Sophia Rose');

      // 2. Duplicate transaction attempt with same transaction ID
      final initialCount = partyProvider.messages.length;
      partyProvider.sendGiftActivityMessage(
        sender: senderUser,
        receiver: receiverUser,
        giftId: 'g_rose',
        giftName: 'Rose',
        giftIcon: '🌹',
        quantity: 5,
        transactionId: txId, // Duplicate txId
      );

      // Verify no duplicate message was added
      expect(partyProvider.messages.length, initialCount);
    });

    test('Verify Module 06 Room Lock PIN & Approval Access Control', () {
      expect(partyProvider.isRoomLocked, false);

      // Configure PIN mode lock
      partyProvider.configureRoomLock(isLocked: true, mode: 'PIN', pin: '4321');
      expect(partyProvider.isRoomLocked, true);
      expect(partyProvider.roomLockMode, 'PIN');
      expect(partyProvider.validateRoomPin('4321'), true);
      expect(partyProvider.validateRoomPin('0000'), false);

      // Request join room in Approval mode
      partyProvider.configureRoomLock(isLocked: true, mode: 'Approval');
      partyProvider.requestJoinRoom(senderUser);
      expect(partyProvider.pendingJoinRequests.length, 1);
      expect(partyProvider.pendingJoinRequests.first['userId'], senderUser.id);

      partyProvider.handleJoinRequest(senderUser.id, true);
      expect(partyProvider.pendingJoinRequests.isEmpty, true);
    });

    test('Verify Module 06 YouTube Shared Sync controls', () {
      expect(partyProvider.youtubePlayState, 'stopped');

      partyProvider.startYouTubeTrack(
        videoId: 'dQw4w9WgXcQ',
        title: 'Lo-Fi Chill Beats',
        sessionId: 'yt_sess_1',
      );

      expect(partyProvider.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(partyProvider.youtubeTitle, 'Lo-Fi Chill Beats');
      expect(partyProvider.youtubePlayState, 'playing');

      partyProvider.setYouTubePlayState('paused', position: 45);
      expect(partyProvider.youtubePlayState, 'paused');
      expect(partyProvider.youtubePositionSeconds, 45);

      partyProvider.stopYouTubeTrack();
      expect(partyProvider.youtubeVideoId, null);
      expect(partyProvider.youtubePlayState, 'stopped');
    });

    test('Verify Module 06 Server-controlled Super Wheel spin', () {
      const sessionId = 'spin_sess_888';
      final result = partyProvider.spinSuperWheelServer(
        userId: senderUser.id,
        sessionId: sessionId,
        costCoins: 100,
      );

      expect(result['sessionId'], sessionId);
      expect(result['userId'], senderUser.id);
      expect(result['prize'], isNotNull);
      expect(partyProvider.lastSuperWheelResult, isNotNull);
    });

    test('Verify Module 06 Lucky Bag creation and single-claim duplicate protection', () {
      const bagId = 'bag_sess_777';

      // 1. Create Lucky Bag
      final err = partyProvider.createLuckyBag(
        id: bagId,
        totalCoins: 1000,
        totalClaims: 2,
      );
      expect(err, null);
      expect(partyProvider.isLuckyBagActive, true);

      // 2. Claim by receiverUser
      final claim1 = partyProvider.claimLuckyBag(
        userId: receiverUser.id,
        userName: receiverUser.name,
      );
      expect(claim1, isNotNull);
      expect(claim1!['status'], 'Success');

      // 3. Duplicate claim by receiverUser (Blocked)
      final claimDup = partyProvider.claimLuckyBag(
        userId: receiverUser.id,
        userName: receiverUser.name,
      );
      expect(claimDup!['status'], 'Already Claimed');

      // 4. Claim by senderUser (Last claim)
      final claim2 = partyProvider.claimLuckyBag(
        userId: senderUser.id,
        userName: senderUser.name,
      );
      expect(claim2!['status'], 'Success');
      expect(partyProvider.isLuckyBagActive, false); // Fully claimed
    });
  });
}
