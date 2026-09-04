import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/providers/live_party_provider.dart';
import 'package:zeparty/providers/wallet_provider.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/models/banner_item_model.dart';
import 'package:zeparty/models/relationship_card_model.dart';
import 'package:zeparty/models/relationship_invitation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modules 07, 08, 09 & 10 Feature Tests', () {
    late LivePartyProvider partyProvider;
    late WalletProvider walletProvider;

    const hostUser = UserModel(
      id: 'u_host_101',
      username: 'danial_host',
      name: 'Danial Host',
      avatarUrl: 'https://example.com/host.png',
    );

    const targetUser = UserModel(
      id: 'u_target_202',
      username: 'sophia_target',
      name: 'Sophia Target',
      avatarUrl: 'https://example.com/target.png',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      partyProvider = LivePartyProvider();
      walletProvider = WalletProvider();
    });

    test('Verify Module 07 Atomic Mic Seat Management (Take, Move, Lock, Mute, Audit Logs)', () {
      // 1. Take Mic 2
      final err1 = partyProvider.takeMicSeat(2, hostUser);
      expect(err1, null);
      expect(partyProvider.participants.any((p) => p.user.id == hostUser.id && p.seatNumber == 2), true);

      // 2. Atomic Move to Mic 5
      final err2 = partyProvider.takeMicSeat(5, hostUser);
      expect(err2, null);
      expect(partyProvider.participants.any((p) => p.user.id == hostUser.id && p.seatNumber == 5), true);
      expect(partyProvider.participants.any((p) => p.user.id == hostUser.id && p.seatNumber == 2), false);

      // 3. Lock Mic 3 & Mute Mic 5
      partyProvider.lockMicSeat(3, true, actor: hostUser);
      expect(partyProvider.isSeatLocked(3), true);

      partyProvider.muteMicSeat(5, true, actor: hostUser);

      // 4. Verify Audit Logging
      expect(partyProvider.micSeatAuditLogs.isNotEmpty, true);
      expect(partyProvider.micSeatAuditLogs.any((log) => log['action'] == 'TAKE_MIC'), true);
      expect(partyProvider.micSeatAuditLogs.any((log) => log['action'] == 'LOCK_MIC'), true);
      expect(partyProvider.micSeatAuditLogs.any((log) => log['action'] == 'MUTE_MIC'), true);
    });

    test('Verify Module 07 Mic Invitation Creation', () {
      final inviteId = partyProvider.inviteUserToMic(1, hostUser, targetUser);
      expect(inviteId, isNotNull);
      expect(partyProvider.micSeatInvitations.isNotEmpty, true);
      expect(partyProvider.micSeatInvitations.first['targetUserId'], targetUser.id);
    });

    test('Verify Module 08 Mic Reaction Anchoring & Spam Rate Limiting', () {
      // 1. Host takes Mic 0
      partyProvider.takeMicSeat(0, hostUser);

      // 2. Send reaction 1
      final sent1 = partyProvider.sendMicReaction(
        reactionAsset: '🔥',
        category: 'Popular',
        sender: hostUser,
      );
      expect(sent1, true);
      expect(partyProvider.activeMicReactions[0], isNotNull);
      expect(partyProvider.activeMicReactions[0]!['reactionAsset'], '🔥');

      // 3. Rapid spam attempt (should be rate-limited / throttled)
      final sentSpam = partyProvider.sendMicReaction(
        reactionAsset: '⭐',
        category: 'Smiles',
        sender: hostUser,
      );
      expect(sentSpam, false);
    });

    test('Verify Module 09 Banner Item Schedule Activity Validation', () {
      final activeBanner = BannerItemModel(
        id: 'b1',
        title: 'Active Event',
        subtitle: 'Sub',
        imageUrl: 'img.png',
        contentType: 'Event',
        destination: 'event_101',
        startDate: DateTime.now().subtract(const Duration(hours: 2)),
        endDate: DateTime.now().add(const Duration(hours: 24)),
      );

      final expiredBanner = BannerItemModel(
        id: 'b2',
        title: 'Expired Event',
        subtitle: 'Sub',
        imageUrl: 'img.png',
        contentType: 'Promotional',
        destination: 'room_202',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(activeBanner.isCurrentlyActive, true);
      expect(expiredBanner.isCurrentlyActive, false);
    });

    test('Verify Module 10 Relationship Card Purchase & Invitation Flow', () {
      const card = RelationshipCardModel(
        id: 'card_cp',
        name: 'Eternal CP Ring Card',
        type: 'CP',
        imageUrl: 'assets/images/cp_ring.png',
        coinPrice: 500,
        benefits: 'CP Ring',
      );

      // Initial wallet balance is 45000 Coins in WalletProvider
      const initialCoins = 45000;

      // Purchase Card
      final success = walletProvider.spendCoins(card.coinPrice, 'Relationship Card: ${card.name}');
      expect(success, true);
      expect(walletProvider.coins, initialCoins - card.coinPrice);

      // Create Pending Invitation
      final invitation = RelationshipInvitationModel(
        id: 'inv_rel_101',
        transactionId: 'tx_rel_555',
        senderUserId: hostUser.id,
        senderUserName: hostUser.name,
        targetUserId: targetUser.id,
        targetUserName: targetUser.name,
        card: card,
        status: RelationshipInvitationStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
      );

      // Verify status is pending (Purchase alone does not activate relationship)
      expect(invitation.status, RelationshipInvitationStatus.pending);
      expect(invitation.isExpired, false);
    });
  });
}
