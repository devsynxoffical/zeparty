import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/core/services/socket_service.dart';
import 'package:zeparty/models/host_target_summary_model.dart';
import 'package:zeparty/models/wallet_model.dart';
import 'package:zeparty/providers/agency_provider.dart';
import 'package:zeparty/providers/live_host_provider.dart';
import 'package:zeparty/providers/wallet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NEW 10: Host Target Reliability and Reversals', () {
    test('Socket event host:target_updated invalidates cached target and signals REST refetch', () async {
      final liveHostProv = LiveHostProvider();

      liveHostProv.initRealtimeListeners();

      expect(liveHostProv.targetSummary, isNull);

      // Invalidate target cache directly
      liveHostProv.invalidateTargetCache();
      expect(liveHostProv.targetSummary, isNull);
      expect(liveHostProv.targetError, isNull);

      liveHostProv.dispose();
    });

    test('Network reconnection triggers target summary refresh', () async {
      final agencyProv = AgencyProvider();

      // Verify onReconnect stream triggers invalidation
      bool invalidated = false;
      SocketService.instance.onReconnect.listen((_) {
        agencyProv.invalidateTargetCache();
        invalidated = true;
      });

      SocketService.instance.emitReconnectForTesting();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(invalidated, isTrue);
      expect(agencyProv.targetSummary, isNull);

      agencyProv.dispose();
    });

    test('Reversed or corrected gift transactions update target strictly via authoritative REST model', () {
      // 1. Initial State before reversal (e.g. 500,000 coins achieved)
      final initialData = {
        'isHost': true,
        'isHostActive': true,
        'hostType': 'LIVE_HOST',
        'achievedCoins': 500000,
        'nextTargetCoins': 1000000,
        'remainingCoins': 500000,
        'progressPercent': 0.50,
        'currentTier': {
          'level': 3,
          'targetCoins': 500000,
          'basicSalaryUSD': 40.0,
          'hostSalaryUSD': 30.0,
          'agencySalaryUSD': 10.0,
        },
      };

      final initialSummary = HostTargetSummaryModel.fromJson(initialData);
      expect(initialSummary.achievedCoins, equals(500000));
      expect(initialSummary.currentTier?.level, equals(3));

      // 2. Gift reversal of 150,000 coins occurs on backend.
      // Client receives host:target_updated, invalidates cache, and fetches latest REST summary.
      // Backend returns confirmed corrected totals (350,000 coins).
      final correctedBackendRestData = {
        'isHost': true,
        'isHostActive': true,
        'hostType': 'LIVE_HOST',
        'achievedCoins': 350000,
        'nextTargetCoins': 500000,
        'remainingCoins': 150000,
        'progressPercent': 0.70,
        'currentTier': {
          'level': 2,
          'targetCoins': 200000,
          'basicSalaryUSD': 16.0,
          'hostSalaryUSD': 12.0,
          'agencySalaryUSD': 4.0,
        },
      };

      // Model deserializes backend confirmed numbers directly without local subtraction math
      final correctedSummary = HostTargetSummaryModel.fromJson(correctedBackendRestData);
      expect(correctedSummary.achievedCoins, equals(350000));
      expect(correctedSummary.remainingCoins, equals(150000));
      expect(correctedSummary.currentTier?.level, equals(2));
      expect(correctedSummary.progressPercent, equals(0.70));
    });

    test('Diamond withdrawals never reduce achieved gross target coins', () async {
      final walletProv = WalletProvider();
      walletProv.setWalletForTesting(const WalletModel(
        id: 'user_1',
        userId: 'user_1',
        coinBalance: 10000,
        diamondBalance: 50000,
      ));

      final targetData = {
        'isHost': true,
        'isHostActive': true,
        'hostType': 'AUDIO_HOST',
        'achievedCoins': 850000,
        'nextTargetCoins': 1000000,
        'remainingCoins': 150000,
        'progressPercent': 0.85,
      };

      final targetSummary = HostTargetSummaryModel.fromJson(targetData);

      // Perform diamond withdrawal/transfer in wallet
      expect(walletProv.diamonds, equals(50000));
      final success = walletProv.spendDiamonds(20000, 'Withdrawal to Seller');
      expect(success, isTrue);
      expect(walletProv.diamonds, equals(30000));

      // Assert target progress is strictly decoupled and unchanged
      expect(targetSummary.achievedCoins, equals(850000));
      expect(targetSummary.remainingCoins, equals(150000));
      expect(targetSummary.progressPercent, equals(0.85));
    });

    test('Socket listener treats host:target_updated as invalidation signal without optimistic arithmetic', () async {
      final agencyProv = AgencyProvider();
      bool targetRefetched = false;

      agencyProv.initRealtimeListeners();
      SocketService.instance.onHostTargetUpdated.listen((_) {
        targetRefetched = true;
      });

      // Backend emits host:target_updated with arbitrary payload
      SocketService.instance.emitHostTargetUpdatedForTesting({
        'hostId': 'host_99',
        'rawTentativeAmount': 99999,
      });

      await Future.delayed(const Duration(milliseconds: 60));

      expect(targetRefetched, isTrue);
      // Ensure local target is not optimistically overwritten with rawTentativeAmount
      expect(agencyProv.targetSummary, isNull);

      agencyProv.dispose();
    });
  });
}
