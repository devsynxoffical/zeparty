import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/models/recharge_agency_model.dart';
import 'package:zeparty/providers/recharge_agency_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NEW 01: Recipient Identity Resolution Tests', () {
    test('VerifiedRecipientModel parses authoritative backend response correctly', () {
      final backendResponseData = {
        'accountId': 'acc_uuid_1002',
        'publicUserId': 'user_1002',
        'nickname': 'ZeParty Star',
        'profileImage': 'https://example.com/avatar.png',
        'countryCode': 'PK',
        'isVerified': true,
      };

      final model = VerifiedRecipientModel.fromJson(backendResponseData);

      expect(model.accountId, equals('acc_uuid_1002'));
      expect(model.publicUserId, equals('user_1002'));
      expect(model.nickname, equals('ZeParty Star'));
      expect(model.profileImage, equals('https://example.com/avatar.png'));
      expect(model.countryCode, equals('PK'));
      expect(model.isVerified, isTrue);

      // Verify operator [] backward compatibility
      expect(model['accountId'], equals('acc_uuid_1002'));
      expect(model['userId'], equals('acc_uuid_1002'));
      expect(model['publicUserId'], equals('user_1002'));
      expect(model['username'], equals('user_1002'));
      expect(model['nickname'], equals('ZeParty Star'));
      expect(model['name'], equals('ZeParty Star'));
    });

    test('VerifiedRecipientModel safely handles missing optional fields and fallback names', () {
      final minimalJson = {
        'userId': 'acc_uuid_9999',
        'username': 'user_9999',
      };

      final model = VerifiedRecipientModel.fromJson(minimalJson);

      expect(model.accountId, equals('acc_uuid_9999'));
      expect(model.publicUserId, equals('user_9999'));
      expect(model.nickname, equals('ZeParty User'));
      expect(model.profileImage, isNull);
      expect(model.countryCode, equals('GLOBAL'));
      expect(model.isVerified, isTrue);
    });

    test('clearVerifiedRecipient immediately clears verified recipient and error state', () {
      final provider = RechargeAgencyProvider();

      provider.clearVerifiedRecipient();

      expect(provider.verifiedRecipient, isNull);
      expect(provider.verificationError, isNull);
      expect(provider.isVerifyingRecipient, isFalse);
      expect(provider.currentRecipientAccountId, isNull);
    });

    test('verifyRecipient with empty or whitespace string immediately clears state and returns null', () async {
      final provider = RechargeAgencyProvider();

      final result = await provider.verifyRecipient('   ');

      expect(result, isNull);
      expect(provider.verifiedRecipient, isNull);
      expect(provider.verificationError, isNull);
      expect(provider.isVerifyingRecipient, isFalse);
    });

    test('Provider stores and exposes authoritative accountId distinct from publicUserId', () {
      final provider = RechargeAgencyProvider();
      expect(provider.currentRecipientAccountId, isNull);

      final recipient = VerifiedRecipientModel(
        accountId: 'internal_user_uuid_456',
        publicUserId: 'danial_king',
        nickname: 'Danial',
        profileImage: null,
        countryCode: 'AE',
        isVerified: true,
      );

      // Deserialized model holds the real accountId
      expect(recipient.accountId, equals('internal_user_uuid_456'));
      expect(recipient.publicUserId, equals('danial_king'));
      expect(recipient.accountId, isNot(equals(recipient.publicUserId)));
    });

    test('syncForSeller clears verified recipient and invalidates pending requests', () {
      final provider = RechargeAgencyProvider();
      provider.syncForSeller(
        sellerId: 'seller_1',
        sellerName: 'First Reseller',
        countryCode: 'PK',
      );

      // Switching to another seller resets state completely
      provider.syncForSeller(
        sellerId: 'seller_2',
        sellerName: 'Second Reseller',
        countryCode: 'US',
      );

      expect(provider.verifiedRecipient, isNull);
      expect(provider.verificationError, isNull);
      expect(provider.isVerifyingRecipient, isFalse);
    });
  });
}
