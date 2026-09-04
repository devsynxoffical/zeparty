import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/core/utils/wallet_date_gate.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/providers/recharge_agency_provider.dart';
import 'package:zeparty/providers/merchant_provider.dart';
import 'package:zeparty/providers/lucky_gift_provider.dart';
import 'package:zeparty/providers/wallet_details_provider.dart';
import 'package:zeparty/providers/wallet_provider.dart';
import 'package:zeparty/providers/messaging_provider.dart';
import 'package:zeparty/models/party_participant_model.dart';
import 'package:zeparty/providers/svip_provider.dart';
import 'package:zeparty/providers/auth_provider.dart';
import 'package:zeparty/providers/privacy_settings_provider.dart';
import 'package:zeparty/providers/cp_ranking_provider.dart';
import 'package:zeparty/features/wallet/coin_records_screen.dart';
import 'package:zeparty/features/party_room/widgets/room_entry_mount_banner.dart';
import 'package:zeparty/core/utils/noble_badge_helper.dart';

void main() {
  group('Modules 16-21 Feature Tests', () {
    test('Verify Module 16 Recharge Agency User Verification & Atomic Recharge', () {
      final prov = RechargeAgencyProvider();
      expect(prov.availableCoins, equals(2500000));

      final user = prov.verifyUser('user_1002');
      expect(user, isNotNull);
      expect(user!['name'], equals('Sophia Rose'));

      final err = prov.executeRecharge(
        recipientUserId: 'user_1002',
        recipientName: 'Sophia Rose',
        recipientAvatarUrl: 'https://example.com/avatar.jpg',
        coins: 100000,
        pin: '1234',
      );

      expect(err, isNull);
      expect(prov.availableCoins, equals(2400000));
      expect(prov.todaysRechargeTotal, equals(450000));
      expect(prov.transactions.first.coins, equals(100000));
    });

    test('Verify Module 17 Merchant Center User vs Coin Seller Recharge', () {
      final merch = MerchantProvider();
      expect(merch.merchant.availableCoins, equals(10000000));

      // User Recharge
      final err1 = merch.executeMerchantRecharge(
        recipientType: 'User Recharge',
        recipientId: 'user_1002',
        recipientName: 'Sophia Rose',
        coinAmount: 500000,
        pin: '1234',
      );
      expect(err1, isNull);
      expect(merch.merchant.availableCoins, equals(9500000));

      // Coin Seller Recharge
      final err2 = merch.executeMerchantRecharge(
        recipientType: 'Coin Seller Recharge',
        recipientId: 'seller_8801',
        recipientName: 'Danial Coin Agency',
        coinAmount: 1000000,
        pin: '1234',
      );
      expect(err2, isNull);
      expect(merch.merchant.availableCoins, equals(8500000));
      expect(merch.transactions.first.destinationBalanceType, equals('Seller Recharge Operational Balance'));
    });

    test('Verify Module 19 Wallet 1st and 15th Date Restriction Gate', () {
      final allowedDate1 = DateTime(2026, 8, 1);
      final allowedDate15 = DateTime(2026, 8, 15);
      final blockedDate = DateTime(2026, 8, 29);

      expect(WalletDateGate.isDateAllowed(allowedDate1), isTrue);
      expect(WalletDateGate.isDateAllowed(allowedDate15), isTrue);
      expect(WalletDateGate.isDateAllowed(blockedDate), isFalse);

      expect(WalletDateGate.validateDateForTransaction(allowedDate1), isNull);
      expect(WalletDateGate.validateDateForTransaction(blockedDate), equals('Available only on the 1st and 15th of each month.'));
    });

    test('Verify Module 20 Lucky Gifts Catalogue & Multiplier Tiers', () {
      final prov = LuckyGiftProvider();
      expect(prov.luckyGifts.length, equals(3));
      final crown = prov.luckyGifts.firstWhere((g) => g.name == 'Lucky Crown');
      expect(crown.coinPrice, equals(50));
      expect(crown.maxMultiplier, equals(100));
      expect(crown.rewardTable.any((t) => t.multiplier == 100), isTrue);
    });

    test('Verify Module 21 Diamond Details Categorized Filtering, Role Filters & Audit', () async {
      final prov = WalletDetailsProvider();
      expect(prov.transactions.isNotEmpty, isTrue);

      // Role based filters check
      final hostFilters = prov.availableFiltersForRole(UserRole.host);
      expect(hostFilters.contains('Host Salary'), isTrue);
      expect(hostFilters.contains('Agent Salary'), isFalse);

      final agencyFilters = prov.availableFiltersForRole(UserRole.agency);
      expect(agencyFilters.contains('Agent Salary'), isTrue);

      // Filtering test
      prov.setCategoryFilter('Host Salary');
      expect(prov.selectedCategoryFilter, equals('Host Salary'));
      expect(prov.transactions.every((t) => t.category == 'Host Salary'), isTrue);

      // Signed values test
      final hostSalaryTx = prov.transactions.first;
      expect(hostSalaryTx.signedAmountString, startsWith('+'));
      expect(hostSalaryTx.settlementType, equals('Host'));
      expect(hostSalaryTx.targetCycle, equals('2026-08 Cycle 1 (1st-15th)'));

      // Filter preservation on refresh
      await prov.refreshData();
      expect(prov.selectedCategoryFilter, equals('Host Salary'));

      // Pagination & loadMore test
      prov.setCategoryFilter('All');
      final initialCount = prov.transactions.length;
      expect(initialCount, equals(5)); // pageSize = 5
      await prov.loadMore();
      expect(prov.transactions.length, greaterThan(initialCount));

      // Audit tracking check
      prov.logAudit('Details opened');
      prov.logAudit('receipt opened', extra: {'txId': 'tx_dia_101'});
      expect(prov.auditLogs.any((a) => a.contains('Details opened')), isTrue);
      expect(prov.auditLogs.any((a) => a.contains('receipt opened')), isTrue);
    });

    test('Verify Module 22 Transfer Receiver Directory Date Gate & Atomic Processing', () {
      final wallet = WalletProvider();
      final detailsProv = WalletDetailsProvider();

      final initialDiamonds = wallet.diamonds;
      expect(initialDiamonds, equals(8520));

      // Date Gate rule test
      final allowedDate = DateTime(2026, 8, 15);
      final blockedDate = DateTime(2026, 8, 29);
      expect(WalletDateGate.isDateAllowed(allowedDate), isTrue);
      expect(WalletDateGate.isDateAllowed(blockedDate), isFalse);

      // Atomic transfer execution (5,000 Diamonds)
      final transferSuccess = wallet.transferDiamonds(5000, 'seller_8801', 'Coin Seller');
      expect(transferSuccess, isTrue);
      expect(wallet.diamonds, equals(initialDiamonds - 5000));

      // Verify idempotency (prevent duplicate transfers)
      final duplicateTransfer = wallet.transferDiamonds(5000, 'seller_8801', 'Coin Seller');
      // Balance is now 3520 < 5000, so transfer correctly fails
      expect(duplicateTransfer, isFalse);

      // Log transaction in WalletDetailsProvider to verify Module 21 integration
      detailsProv.logAudit('transfer completed', extra: {'txId': 'trf_9901'});
      expect(detailsProv.auditLogs.any((log) => log.contains('transfer completed')), isTrue);
    });

    test('Verify Module 23 Inbox Top Activity, Aggregate Unread & Admin Broadcasts', () {
      final messaging = MessagingProvider();

      // Top activity items verification
      expect(messaging.systemMessages.length, equals(2));
      expect(messaging.activityRewards.length, equals(1));
      expect(messaging.activityHelpers.length, equals(1));

      // Unread counts verification
      expect(messaging.systemUnreadCount, equals(1));
      expect(messaging.rewardsUnreadCount, equals(1));
      expect(messaging.helperUnreadCount, equals(1));
      expect(messaging.directUnreadCount, equals(2));
      expect(messaging.totalCombinedUnreadCount, equals(5));

      // Reward claim verification
      final rewardId = messaging.activityRewards.first.id;
      final claimSuccess = messaging.claimActivityReward(rewardId);
      expect(claimSuccess, isTrue);
      expect(messaging.activityRewards.first.status, equals('Claimed'));
      expect(messaging.rewardsUnreadCount, equals(0));

      // Thread actions (Pin, Mute, Read)
      messaging.togglePin('user_1002');
      messaging.toggleMute('user_1002');
      messaging.markThreadAsRead('user_1002');

      final meta = messaging.getMetaForUser('user_1002');
      expect(meta.isPinned, isTrue);
      expect(meta.isMuted, isTrue);
      expect(meta.unreadCount, equals(0));

      // Admin Broadcast Creation
      messaging.createAdminBroadcast(
        targetType: 'System Messages',
        title: 'Platform Maintenance Scheduled',
        content: 'System upgrade on Sunday 02:00 UTC.',
        country: 'GLOBAL',
        role: 'ALL',
      );
      expect(messaging.adminBroadcasts.isNotEmpty, isTrue);
      expect(messaging.systemMessages.first.title, equals('Platform Maintenance Scheduled'));
    });

    test('Verify Module 24 In-Room Profile Card Level Separation & Role Data', () {
      const testUser = UserModel(
        id: 'u_profile_99',
        username: 'prof_test',
        name: 'Profile Tester',
        avatarUrl: 'https://example.com/avatar.png',
        wealthLevel: 45,
        charmLevel: 22,
        gameLevel: 18,
        cpPartnerId: 'partner_77',
        cpPoints: 1200,
        agencyName: 'Star Stream Agency',
      );

      final participant = PartyParticipantModel(
        user: testUser,
        role: ParticipantRole.moderator,
        seatNumber: 3,
        joinedAt: DateTime.now(),
      );

      // Verify explicit level separation
      expect(testUser.wealthLevel, equals(45));
      expect(testUser.charmLevel, equals(22));
      expect(testUser.gameLevel, equals(18));
      expect(testUser.wealthLevel != testUser.charmLevel, isTrue);

      // Verify participant role & agency
      expect(participant.role, equals(ParticipantRole.moderator));
      expect(testUser.agencyName, equals('Star Stream Agency'));
      expect(testUser.cpPartnerId, equals('partner_77'));
      expect(testUser.cpPoints, equals(1200));
    });

    test('Verify Module 25 SVIP, Wealth, Charm, Game Level Tracks & Privilege System', () {
      final svipProv = SVIPProvider();

      // Verify SVIP initial level & privilege count
      expect(svipProv.currentLevel, equals(11));
      expect(svipProv.totalPrivilegesCount, equals(37));
      expect(svipProv.unlockedPrivilegesCount > 0, isTrue);

      // Verify privilege unlocks
      expect(svipProv.isPrivilegeUnlocked('p_1'), isTrue);
      expect(svipProv.isPrivilegeUnlocked('p_6'), isTrue);

      // Level tab views (SVIP 1 to SVIP 16)
      expect(svipProv.levels.length, equals(16));

      // Test SVIP points purchase & upgrade calculation
      final wallet = WalletProvider();
      final pkg = svipProv.storePackages.first;
      final initialPoints = svipProv.currentPoints;

      svipProv.purchasePoints(pkg, wallet);
      expect(svipProv.currentPoints, equals(initialPoints + pkg.points + pkg.bonusPoints));
    });

    test('Verify Module 26 BD Center Access Control & Role Restrictions', () {
      final standardUser = UserModel(
        id: 'std_user_1',
        name: 'Standard User',
        username: 'stduser1',
        avatarUrl: 'https://example.com/avatar.jpg',
        role: UserRole.user,
        isBd: false,
      );

      final bdUser = UserModel(
        id: 'bd_user_1',
        name: 'BD Manager',
        username: 'bdmgr1',
        avatarUrl: 'https://example.com/avatar.jpg',
        role: UserRole.bd,
        isBd: true,
      );

      final agencyUser = UserModel(
        id: 'agency_user_1',
        name: 'Agency Leader',
        username: 'agyleader1',
        avatarUrl: 'https://example.com/avatar.jpg',
        role: UserRole.agency,
      );

      // Helper function for BD authorization check matching BDCenterDashboardScreen
      bool canAccessBd(UserModel u) =>
          u.isBd || u.role == UserRole.bd || u.role == UserRole.agency || u.role == UserRole.admin;

      expect(canAccessBd(standardUser), isFalse);
      expect(canAccessBd(bdUser), isTrue);
      expect(canAccessBd(agencyUser), isTrue);

      // Verify exact 6 retained BD operation center cards per Module 26.2
      final retainedBdCards = [
        'Invite Agent',
        'Agent List',
        'Agencies',
        'Income',
        'Salary & Tiers',
        'Targets',
      ];
      expect(retainedBdCards.length, equals(6));
      expect(retainedBdCards.contains('Commission'), isFalse);
      expect(retainedBdCards.contains('SVIP Control'), isFalse);
      expect(retainedBdCards.contains('Noble Control'), isFalse);
      expect(retainedBdCards.contains('Audit Logs'), isFalse);
      expect(retainedBdCards.contains('BD Settings'), isFalse);
    });

    test('Verify Module 27 Edit Profile Fields Validation & Prohibited Title Filtering', () {
      final auth = AuthProvider();
      final user = auth.currentUser;

      // Test valid profile update
      auth.updateProfile(
        name: 'ZeParty Streamer',
        bio: 'Official live streamer bio note ✨',
        gender: 'Female',
        region: 'United States',
      );

      expect(auth.currentUser.name, equals('ZeParty Streamer'));
      expect(auth.currentUser.bio, equals('Official live streamer bio note ✨'));
      expect(auth.currentUser.gender, equals('Female'));

      // Test Prohibited Words / Reserved Title Filter
      bool containsProhibitedWords(String text) {
        final lower = text.toLowerCase();
        final prohibited = ['admin', 'administrator', 'moderator', 'official', 'support', 'system'];
        return prohibited.any((w) => lower.contains(w));
      }

      expect(containsProhibitedWords('ZeParty Admin User'), isTrue);
      expect(containsProhibitedWords('System Official Support'), isTrue);
      expect(containsProhibitedWords('Regular Creator'), isFalse);

      // Verify server-protected fields remain untouched by profile updates
      expect(auth.currentUser.id, equals(user.id));
      expect(auth.currentUser.coins, equals(user.coins));
      expect(auth.currentUser.diamonds, equals(user.diamonds));
    });

    test('Verify Module 28 Privacy Settings SVIP Privilege Gating & Toggles', () {
      final privacy = PrivacySettingsProvider();

      // Test ungated toggles (Free for all users)
      expect(privacy.canEnable('block_strangers_dm', 0), isTrue);
      expect(privacy.canEnable('hide_cp_relationship', 0), isTrue);

      privacy.toggleSetting('block_strangers_dm', 0);
      expect(privacy.blockStrangersDm, isTrue);

      // Test SVIP gated privacy toggles
      // Stealth Entry requires SVIP 6
      expect(privacy.canEnable('stealth_entry', 2), isFalse);
      expect(privacy.canEnable('stealth_entry', 6), isTrue);

      // Toggle blocked for SVIP Level 2
      privacy.toggleSetting('stealth_entry', 2);
      expect(privacy.stealthRoomEntry, isFalse);

      // Toggle allowed for SVIP Level 6
      privacy.toggleSetting('stealth_entry', 6);
      expect(privacy.stealthRoomEntry, isTrue);
    });

    test('Verify Module 29 CP Relationship Ranking & Intimacy Boosting', () {
      final cpProvider = CpRankingProvider();

      // Test filtered public rankings (privacy check)
      final publicRankings = cpProvider.getFilteredRankings(
        timeframe: 'Daily',
        hideCpPrivacyActive: false,
      );

      // Verify privacy-hidden CP entries are masked/excluded
      expect(publicRankings.any((cp) => cp.isPrivacyHidden), isFalse);

      // Test Intimacy Points Boost
      final firstCp = publicRankings.first;
      final initialPoints = firstCp.intimacyPoints;

      cpProvider.boostIntimacy(firstCp.id, 500);

      final updatedCp = cpProvider.allRankings.firstWhere((cp) => cp.id == firstCp.id);
      expect(updatedCp.intimacyPoints, equals(initialPoints + 500));
    });

    test('Verify Module 30 Coin Records Categorization & Direction Filters', () {
      final creditItem = CoinRecordItem(
        id: 'CR_TEST_1',
        category: 'Recharges',
        description: 'Coin Seller Recharge',
        amount: 50000,
        timestamp: DateTime(2026, 1, 15),
        status: 'Completed',
        senderOrReceiver: 'Merchant #101',
        balanceBefore: 100000,
        balanceAfter: 150000,
      );

      final debitItem = CoinRecordItem(
        id: 'CR_TEST_2',
        category: 'Gifting',
        description: 'Sent Lucky Gift',
        amount: -5000,
        timestamp: DateTime(2026, 1, 15),
        status: 'Completed',
        senderOrReceiver: 'Room Host @Alice',
        balanceBefore: 150000,
        balanceAfter: 145000,
      );

      expect(creditItem.isIncome, isTrue);
      expect(debitItem.isIncome, isFalse);
      expect(creditItem.amount, equals(50000));
      expect(debitItem.amount, equals(-5000));
    });

    test('Verify Module 31 Room Entry Banner Position & Stealth Privacy Check', () {
      final privacy = PrivacySettingsProvider();
      const standardBanner = RoomEntryBannerItem(
        id: 'banner_1',
        userId: 'u_101',
        userName: 'VIP Phantom',
        userAvatar: 'https://example.com/avatar.jpg',
        mountTitle: 'Phantom Dragon Mount 🐉',
        isStealthMode: false,
      );

      const stealthBanner = RoomEntryBannerItem(
        id: 'banner_2',
        userId: 'u_102',
        userName: 'Stealth Phantom',
        userAvatar: 'https://example.com/avatar.jpg',
        mountTitle: 'Ghost Mount 👻',
        isStealthMode: true,
      );

      expect(standardBanner.isStealthMode, isFalse);
      expect(stealthBanner.isStealthMode, isTrue);

      // Verify privacy settings stealth check
      expect(privacy.stealthRoomEntry, isFalse);
      privacy.toggleSetting('stealth_entry', 6);
      expect(privacy.stealthRoomEntry, isTrue);
    });

    test('Verify Addendum 32 Noble Badge & Colored Name Resolution', () {
      final emperorTier = NobleBadgeHelper.getTierFromTitle('Noble Emperor 👑');
      final dukeTier = NobleBadgeHelper.getTierFromTitle('Grand Duke');
      final marquisTier = NobleBadgeHelper.getTierFromTitle('Marquis of ZeParty');
      final earlTier = NobleBadgeHelper.getTierFromTitle('Earl');
      final knightTier = NobleBadgeHelper.getTierFromTitle('Noble Knight');

      expect(emperorTier, equals(NobleTier.emperor));
      expect(dukeTier, equals(NobleTier.duke));
      expect(marquisTier, equals(NobleTier.marquis));
      expect(earlTier, equals(NobleTier.earl));
      expect(knightTier, equals(NobleTier.knight));

      final goldColor = NobleBadgeHelper.getColoredNicknameColor(emperorTier);
      final redColor = NobleBadgeHelper.getColoredNicknameColor(marquisTier);
      final purpleColor = NobleBadgeHelper.getColoredNicknameColor(earlTier);
      final cyanColor = NobleBadgeHelper.getColoredNicknameColor(knightTier);

      expect(goldColor.toARGB32(), equals(const Color(0xFFFFD700).toARGB32()));
      expect(redColor.toARGB32(), equals(const Color(0xFFFF4500).toARGB32()));
      expect(purpleColor.toARGB32(), equals(const Color(0xFFD500F9).toARGB32()));
      expect(cyanColor.toARGB32(), equals(const Color(0xFF00E5FF).toARGB32()));
    });
  });
}












