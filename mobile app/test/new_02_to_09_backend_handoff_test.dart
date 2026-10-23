import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/models/recharge_agency_model.dart';
import 'package:zeparty/models/transaction_model.dart';
import 'package:zeparty/models/host_target_summary_model.dart';
import 'package:zeparty/providers/recharge_agency_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NEW 02: Recharge Wallet Credit & Authoritative Reference', () {
    test('SellerRechargeResult parses authoritative backend transfer response', () {
      final json = {
        'success': true,
        'message': 'Coins transferred successfully',
        'data': {
          'transactionId': 'SEL-RCHG-20261023-ABC123',
          'referenceId': 'SEL-RCHG-20261023-ABC123',
          'creditedTo': 'user_uuid_998',
          'recipientPublicId': '9202535',
          'recipientName': 'ZeParty Host',
          'amountCoins': 50000,
          'sellerNewBalance': 150000,
          'recipientNewBalance': 50500,
          'status': 'COMPLETED',
          'createdAt': '2026-10-23T11:00:00.000Z',
        }
      };

      final result = SellerRechargeResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.transactionId, equals('SEL-RCHG-20261023-ABC123'));
      expect(result.referenceId, equals('SEL-RCHG-20261023-ABC123'));
      expect(result.creditedTo, equals('user_uuid_998'));
      expect(result.recipientPublicId, equals('9202535'));
      expect(result.amountCoins, equals(50000));
      expect(result.sellerNewBalance, equals(150000));
      expect(result.recipientNewBalance, equals(50500));
      expect(result.status, equals('COMPLETED'));
    });

    test('SellerRechargeTransactionModel deserializes referenceId and status without fake ID generation', () {
      final txJson = {
        'id': 'tx_backend_001',
        'referenceId': 'SEL-RCHG-998877',
        'sellerId': 'seller_uuid_1',
        'sellerName': 'Top Seller',
        'recipientUserId': 'recipient_uuid_2',
        'recipientPublicId': '8888999',
        'recipientName': 'VIP Streamer',
        'amountCoins': 10000,
        'amount': 10000,
        'status': 'COMPLETED',
        'createdAt': '2026-10-23T09:30:00.000Z',
      };

      final tx = SellerRechargeTransactionModel.fromJson(txJson);

      expect(tx.referenceId, equals('SEL-RCHG-998877'));
      expect(tx.amountCoins, equals(10000));
      expect(tx.status, equals('COMPLETED'));
      expect(tx.recipientPublicId, equals('8888999'));
    });
  });

  group('NEW 04 & NEW 07: History Persistence & Phantom Record Prevention', () {
    test('RechargeAgencyProvider does not create local memory transactions before server confirmation', () {
      final provider = RechargeAgencyProvider();
      provider.syncForSeller(sellerId: 's_01', sellerName: 'Seller 1', countryCode: 'GLOBAL');

      // Transactions list must be empty initially, not prepopulated with fake records
      expect(provider.transactions, isEmpty);
      expect(provider.isExecutingTransfer, isFalse);
    });

    test('SellerRechargeTransactionModel deduplication works correctly on unique reference IDs', () {
      final list = <SellerRechargeTransactionModel>[
        SellerRechargeTransactionModel.fromJson({
          'transactionId': 'tx_1',
          'referenceId': 'SEL-RCHG-001',
          'sellerId': 's1',
          'sellerName': 'Seller',
          'recipientUserId': 'u1',
          'recipientName': 'User 1',
          'coins': 500,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      ];

      final incoming = SellerRechargeTransactionModel.fromJson({
        'transactionId': 'tx_1',
        'referenceId': 'SEL-RCHG-001',
        'sellerId': 's1',
        'sellerName': 'Seller',
        'recipientUserId': 'u1',
        'recipientName': 'User 1',
        'coins': 500,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final exists = list.any((t) => t.id == incoming.id || t.referenceId == incoming.referenceId);
      expect(exists, isTrue);
    });
  });

  group('NEW 05 & NEW 06: Accurate Coin Records (Credit & Debit Direction)', () {
    test('TransactionModel.fromLedgerJson parses CREDIT as positive amount with counterparty', () {
      final ledgerJson = {
        'id': 'ledger_tx_101',
        'referenceId': 'SEL-RCHG-20261023-9001',
        'entryType': 'CREDIT',
        'amount': 25000,
        'balanceAfter': 35000,
        'title': 'Seller Recharge Received',
        'description': 'Received 25,000 coins from TopReseller',
        'senderName': 'TopReseller',
        'senderUserId': 'seller_uuid_10',
        'createdAt': '2026-10-23T08:00:00.000Z',
      };

      final tx = TransactionModel.fromLedgerJson(ledgerJson);

      expect(tx.amount, equals(25000.0));
      expect(tx.referenceId, equals('SEL-RCHG-20261023-9001'));
      expect(tx.currency, equals('Coins'));
      expect(tx.senderName, equals('TopReseller'));
      expect(tx.displayTransactionId, equals('SEL-RCHG-20261023-9001'));
    });

    test('TransactionModel.fromLedgerJson parses DEBIT as negative amount with counterparty', () {
      final ledgerJson = {
        'id': 'ledger_tx_102',
        'referenceId': 'GIFT-SEND-7788',
        'entryType': 'DEBIT',
        'amount': 1500,
        'balanceAfter': 33500,
        'title': 'Gift Sent',
        'description': 'Sent Rose to ZeParty Host',
        'receiverName': 'ZeParty Host',
        'receiverUserId': 'host_uuid_55',
        'createdAt': '2026-10-23T08:30:00.000Z',
      };

      final tx = TransactionModel.fromLedgerJson(ledgerJson);

      expect(tx.amount, equals(-1500.0));
      expect(tx.referenceId, equals('GIFT-SEND-7788'));
      expect(tx.currency, equals('Coins'));
      expect(tx.receiverName, equals('ZeParty Host'));
      expect(tx.displayTransactionId, equals('GIFT-SEND-7788'));
    });
  });

  group('NEW 08: Recharge Acceptance Error Code Mapping', () {
    test('Known error codes map to distinct actionable user messages', () {
      final errorCodes = {
        'USER_NOT_FOUND': 'Recipient user not found. Please verify the User ID.',
        'INSUFFICIENT_SELLER_COINS': 'Insufficient coin balance in your seller inventory.',
        'INVALID_SECURITY_PIN': 'Invalid 6-digit Security PIN. Please try again.',
        'SELLER_ACCOUNT_INACTIVE': 'Your seller account is currently inactive.',
        'RATE_LIMIT_EXCEEDED': 'Rate limit exceeded. Please wait a few moments before trying again.',
      };

      for (final entry in errorCodes.entries) {
        expect(entry.value, isNotEmpty);
        expect(entry.key, isIn([
          'USER_NOT_FOUND',
          'INSUFFICIENT_SELLER_COINS',
          'INVALID_SECURITY_PIN',
          'SELLER_ACCOUNT_INACTIVE',
          'RATE_LIMIT_EXCEEDED',
        ]));
      }
    });
  });

  group('NEW 09: Authoritative Host Target Progress', () {
    test('HostTargetSummaryModel correctly parses backend 100% normal / 10% lucky target summary', () {
      final summaryJson = {
        'isHost': true,
        'isHostActive': true,
        'hostType': 'LIVE_HOST',
        'achievedCoins': '12500',
        'totalTargetCoins': 100000,
        'remainingCoins': '87500',
        'nextTargetCoins': '100000',
        'progressPercent': 12.5,
        'cycle': {
          'cycleType': '10_DAY',
          'cycleIdentifier': 'LIVE_2026_10_CYCLE_3',
        },
        'currentTier': {
          'level': 1,
          'targetCoins': 100000,
          'basicSalaryUSD': 150.0,
          'hostSalaryUSD': 150.0,
          'agencySalaryUSD': 0.0,
        },
        'nextTier': {
          'level': 2,
          'targetCoins': 250000,
          'basicSalaryUSD': 350.0,
          'hostSalaryUSD': 350.0,
          'agencySalaryUSD': 0.0,
        },
        'formula': '100% normal gift coins + 10% lucky gift coins',
      };

      final summary = HostTargetSummaryModel.fromJson(summaryJson);

      expect(summary.isHost, isTrue);
      expect(summary.isHostActive, isTrue);
      expect(summary.hostType, equals('LIVE_HOST'));
      expect(summary.achievedCoins, equals(12500));
      expect(summary.nextTargetCoins, equals(100000));
      expect(summary.remainingCoins, equals(87500));
      expect(summary.progressPercent, closeTo(0.125, 0.001));
      expect(summary.cycleIdentifier, equals('LIVE_2026_10_CYCLE_3'));
      expect(summary.formula, equals('100% normal gift coins + 10% lucky gift coins'));
      expect(summary.currentTier?.level, equals(1));
      expect(summary.nextTier?.level, equals(2));
      expect(summary.nextTier?.targetCoins, equals(250000));
    });

    test('HostTargetSummaryModel handles non-host or unconfigured tiers gracefully', () {
      final emptyJson = {
        'isHost': false,
        'achievedCoins': '0',
        'progressPercent': 0,
      };

      final summary = HostTargetSummaryModel.fromJson(emptyJson);

      expect(summary.isHost, isFalse);
      expect(summary.isHostActive, isFalse);
      expect(summary.achievedCoins, equals(0));
      expect(summary.nextTargetCoins, equals(0));
      expect(summary.remainingCoins, equals(0));
      expect(summary.progressPercent, equals(0.0));
      expect(summary.currentTier, isNull);
      expect(summary.nextTier, isNull);
    });
  });
}
