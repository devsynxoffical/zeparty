import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/providers/game_provider.dart';
import 'package:zeparty/providers/wallet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 02 - Room Theme & Room DP Upload Fee Tests', () {
    late GameProvider gameProvider;
    late WalletProvider walletProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gameProvider = GameProvider();
      walletProvider = WalletProvider();
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Verify default upload price is 100,000 Coins and enabled', () {
      expect(gameProvider.paidRoomThemeUploadsEnabled, true);
      expect(gameProvider.customRoomThemeUploadPrice, 100000);
      expect(gameProvider.getCustomRoomThemeUploadPrice('Global'), 100000);
    });

    test('Verify central price resolution for country overrides and disabled feature', () async {
      // Global price
      expect(gameProvider.getCustomRoomThemeUploadPrice('United States'), 100000);

      // Country override
      expect(gameProvider.getCustomRoomThemeUploadPrice('Pakistan'), 100000);

      // Disable paid uploads -> Price resolves to 0 (Free)
      await gameProvider.updateRoomThemeUploadConfig(enabled: false, globalPrice: 100000);
      expect(gameProvider.getCustomRoomThemeUploadPrice('Global'), 0);
      expect(gameProvider.getCustomRoomThemeUploadPrice('Pakistan'), 0);
    });

    test('Verify payment transaction with sufficient vs insufficient wallet balance', () async {
      // Clear wallet to 0 for exact calculation
      final currentBal = walletProvider.coins;
      if (currentBal > 0) {
        walletProvider.spendCoins(currentBal, 'reset');
      }
      expect(walletProvider.coins, 0);

      // Wallet balance: 50,000 Coins (Price: 100,000) -> Insufficient
      walletProvider.earnCoins(50000, 'Test Deposit');
      final resultFail = await gameProvider.processRoomThemePayment(
        walletProvider: walletProvider,
        userId: 'usr_test_1',
        roomId: 'room_101',
        uploadType: 'Room Theme',
        userCountry: 'Global',
      );

      expect(resultFail['success'], false);
      expect(resultFail['error'], 'INSUFFICIENT_COINS');
      expect(walletProvider.coins, 50000); // 0 coins deducted

      // Deposit 100,000 more (Balance: 150,000 Coins) -> Sufficient
      walletProvider.earnCoins(100000, 'Test Deposit 2');
      expect(walletProvider.coins, 150000);

      final resultSuccess = await gameProvider.processRoomThemePayment(
        walletProvider: walletProvider,
        userId: 'usr_test_1',
        roomId: 'room_101',
        uploadType: 'Room Theme',
        userCountry: 'Global',
      );

      expect(resultSuccess['success'], true);
      expect(resultSuccess['chargedAmount'], 100000);
      expect(walletProvider.coins, 50000); // 100,000 coins deducted cleanly
    });

    test('Verify automatic refund logic when upload is cancelled/failed', () async {
      walletProvider.earnCoins(100000, 'Test Deposit for Refund');
      final initialBalance = walletProvider.coins;

      final payment = await gameProvider.processRoomThemePayment(
        walletProvider: walletProvider,
        userId: 'usr_test_2',
        roomId: 'room_202',
        uploadType: 'Party Room Background',
        userCountry: 'Global',
      );

      expect(payment['success'], true);
      final String txId = payment['transactionId'];
      expect(walletProvider.coins, initialBalance - 100000);

      // Simulate gallery cancel / upload error -> Trigger refund
      final refunded = await gameProvider.refundRoomThemePayment(
        walletProvider: walletProvider,
        transactionId: txId,
        reason: 'Image picker cancelled by user',
      );

      expect(refunded, true);
      expect(walletProvider.coins, initialBalance); // Fully restored

      // Duplicate refund attempt should be blocked
      final refundAgain = await gameProvider.refundRoomThemePayment(
        walletProvider: walletProvider,
        transactionId: txId,
        reason: 'Duplicate refund attempt',
      );
      expect(refundAgain, false);
      expect(walletProvider.coins, initialBalance);
    });

    test('Verify admin price update & audit log generation', () async {
      await gameProvider.updateRoomThemeUploadConfig(
        enabled: true,
        globalPrice: 150000,
        adminId: 'Admin Owner Test',
      );

      expect(gameProvider.customRoomThemeUploadPrice, 150000);
      expect(gameProvider.getCustomRoomThemeUploadPrice('Global'), 150000);
      expect(gameProvider.roomThemePriceAdminLogs.isNotEmpty, true);
      final latestLog = gameProvider.roomThemePriceAdminLogs.first;
      expect(latestLog['previousPrice'], 100000);
      expect(latestLog['newPrice'], 150000);
      expect(latestLog['adminId'], 'Admin Owner Test');
    });
  });
}
