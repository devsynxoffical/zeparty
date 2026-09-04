import 'user_model.dart';

class PartySeatModel {
  final int seatIndex;
  final UserModel? user;
  final bool isMuted;
  final bool isLocked;

  const PartySeatModel({
    required this.seatIndex,
    this.user,
    this.isMuted = false,
    this.isLocked = false,
  });
}

class PartyRoomModel {
  final String id;
  final String title;
  final UserModel host;
  final String roomType; // Open Party, Moderated Party
  final List<PartySeatModel> seats;
  final int totalListeners;

  const PartyRoomModel({
    required this.id,
    required this.title,
    required this.host,
    required this.roomType,
    required this.seats,
    required this.totalListeners,
  });
}
