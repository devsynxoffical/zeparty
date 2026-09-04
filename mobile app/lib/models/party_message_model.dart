import 'user_model.dart';

class PartyMessageModel {
  final String id;
  final UserModel sender;
  final UserModel? receiver;
  final String text;
  final DateTime timestamp;
  final bool isSystemMessage;
  final bool isGiftMessage;
  final String? giftId;
  final String? giftName;
  final String? giftIcon;
  final int? quantity;
  final String? transactionId;
  final DateTime? serverTimestamp;

  const PartyMessageModel({
    required this.id,
    required this.sender,
    this.receiver,
    required this.text,
    required this.timestamp,
    this.isSystemMessage = false,
    this.isGiftMessage = false,
    this.giftId,
    this.giftName,
    this.giftIcon,
    this.quantity,
    this.transactionId,
    this.serverTimestamp,
  });
}
