import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/live_room_model.dart';
import '../../models/party_participant_model.dart';
import '../../models/party_message_model.dart';
import '../../models/user_model.dart';

class LocalPartyRepository extends ChangeNotifier {
  static final LocalPartyRepository instance = LocalPartyRepository._internal();
  LocalPartyRepository._internal();

  // Mocking Firebase Streams
  final _participantsController = StreamController<List<PartyParticipantModel>>.broadcast();
  final _messagesController = StreamController<List<PartyMessageModel>>.broadcast();

  Stream<List<PartyParticipantModel>> get participantsStream => _participantsController.stream;
  Stream<List<PartyMessageModel>> get messagesStream => _messagesController.stream;

  List<PartyParticipantModel> _currentParticipants = [];
  List<PartyMessageModel> _currentMessages = [];

  void joinRoom(LiveRoomModel room, PartyParticipantModel currentUser) {
    final now = DateTime.now();

    // Create realistic room participants so host & users have an active, real-feeling party
    final isHost = room.host.id == currentUser.user.id;

    final hostParticipant = PartyParticipantModel(
      user: isHost ? currentUser.user : room.host,
      role: ParticipantRole.host,
      seatNumber: 0,
      micStatus: MicStatus.on,
      joinedAt: now.subtract(const Duration(minutes: 25)),
      isSpeaking: false,
    );

    _currentParticipants = [
      hostParticipant,
      if (!isHost) currentUser.copyWith(seatNumber: null, role: ParticipantRole.listener),
      PartyParticipantModel(
        user: const UserModel(
          id: 'user_1002',
          username: 'sophia_vibe',
          name: 'Sophia Rose',
          avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
          isOnline: true,
          isVip: true,
          vipLevel: 'VIP 4',
        ),
        role: ParticipantRole.speaker,
        seatNumber: 1,
        micStatus: MicStatus.on,
        joinedAt: now.subtract(const Duration(minutes: 18)),
        isSpeaking: true,
      ),
      PartyParticipantModel(
        user: const UserModel(
          id: 'user_1003',
          username: 'alex_gamer',
          name: 'Alex Rivera',
          avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=300&q=80',
          isOnline: true,
          isVip: true,
          vipLevel: 'VIP 6',
        ),
        role: ParticipantRole.moderator,
        seatNumber: 2,
        micStatus: MicStatus.on,
        joinedAt: now.subtract(const Duration(minutes: 12)),
        isSpeaking: false,
      ),
      PartyParticipantModel(
        user: const UserModel(
          id: 'user_1004',
          username: 'elena_dance',
          name: 'Elena Rostova',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
          isOnline: true,
          isVip: false,
        ),
        role: ParticipantRole.speaker,
        seatNumber: 3,
        micStatus: MicStatus.muted,
        joinedAt: now.subtract(const Duration(minutes: 8)),
        isSpeaking: false,
      ),
      PartyParticipantModel(
        user: const UserModel(
          id: 'user_1005',
          username: 'marcus_beats',
          name: 'Marcus Vance',
          avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
          isOnline: true,
          isVip: true,
          vipLevel: 'VIP 3',
        ),
        role: ParticipantRole.speaker,
        seatNumber: 4,
        micStatus: MicStatus.on,
        joinedAt: now.subtract(const Duration(minutes: 5)),
        isSpeaking: false,
      ),
      PartyParticipantModel(
        user: const UserModel(
          id: 'user_1006',
          username: 'zayn_m',
          name: 'Zayn Malik',
          avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
          isOnline: true,
          isVip: false,
        ),
        role: ParticipantRole.listener,
        seatNumber: null,
        micStatus: MicStatus.muted,
        joinedAt: now.subtract(const Duration(minutes: 4)),
        isSpeaking: false,
      ),
      PartyParticipantModel(
        user: const UserModel(
          id: 'user_1007',
          username: 'aisha_star',
          name: 'Aisha Noor',
          avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
          isOnline: true,
          isVip: true,
          vipLevel: 'VIP 2',
        ),
        role: ParticipantRole.listener,
        seatNumber: null,
        micStatus: MicStatus.muted,
        joinedAt: now.subtract(const Duration(minutes: 2)),
        isSpeaking: false,
      ),
    ];

    _currentMessages = [
      PartyMessageModel(
        id: '1',
        sender: hostParticipant.user,
        text: 'Welcome to the Party! Drop your favorite song requests 🎵🔥',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      PartyMessageModel(
        id: '2',
        sender: const UserModel(
          id: 'user_1002',
          username: 'sophia_vibe',
          name: 'Sophia Rose',
          avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
        ),
        text: 'Hey everyone! Having a blast here! 🎉✨',
        timestamp: now.subtract(const Duration(minutes: 3)),
      ),
      PartyMessageModel(
        id: '3',
        sender: const UserModel(
          id: 'user_1003',
          username: 'alex_gamer',
          name: 'Alex Rivera',
          avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=300&q=80',
        ),
        text: 'Who is ready for the PK match later? 🚀🏆',
        timestamp: now.subtract(const Duration(minutes: 1)),
      ),
    ];

    _participantsController.add(_currentParticipants);
    _messagesController.add(_currentMessages);
  }

  void leaveRoom() {
    _currentParticipants = [];
    _currentMessages = [];
    _participantsController.add(_currentParticipants);
    _messagesController.add(_currentMessages);
  }

  void requestSeat(PartyParticipantModel user, int seatIndex) {
    final existingIdx = _currentParticipants.indexWhere((p) => p.user.id == user.user.id);
    if (existingIdx != -1) {
      _currentParticipants[existingIdx] = _currentParticipants[existingIdx].copyWith(
        seatNumber: seatIndex,
        role: _currentParticipants[existingIdx].role == ParticipantRole.host
            ? ParticipantRole.host
            : ParticipantRole.speaker,
        micStatus: MicStatus.on,
      );
    } else {
      final participant = user.copyWith(
        seatNumber: seatIndex,
        role: ParticipantRole.speaker,
        micStatus: MicStatus.on,
      );
      _currentParticipants.add(participant);
    }
    _participantsController.add(_currentParticipants);
  }

  void kickFromSeat(String userId) {
    final index = _currentParticipants.indexWhere((p) => p.user.id == userId);
    if (index != -1) {
      _currentParticipants[index] = _currentParticipants[index].copyWith(
        seatNumber: null,
        role: ParticipantRole.listener,
        micStatus: MicStatus.muted,
      );
      _participantsController.add(_currentParticipants);
    }
  }

  void sendMessage(PartyMessageModel message) {
    _currentMessages.add(message);
    _messagesController.add(_currentMessages);
  }

  void updateMicStatus(String userId, MicStatus status) {
    final index = _currentParticipants.indexWhere((p) => p.user.id == userId);
    if (index != -1) {
      _currentParticipants[index] = _currentParticipants[index].copyWith(micStatus: status);
      _participantsController.add(_currentParticipants);
    }
  }

  void removeParticipant(String userId) {
    _currentParticipants.removeWhere((p) => p.user.id == userId);
    _participantsController.add(_currentParticipants);
  }

  void promoteToModerator(String userId) {
    final index = _currentParticipants.indexWhere((p) => p.user.id == userId);
    if (index != -1) {
      _currentParticipants[index] = _currentParticipants[index].copyWith(role: ParticipantRole.moderator);
      _participantsController.add(_currentParticipants);
    }
  }

  void demoteModerator(String userId) {
    final index = _currentParticipants.indexWhere((p) => p.user.id == userId);
    if (index != -1) {
      _currentParticipants[index] = _currentParticipants[index].copyWith(role: ParticipantRole.listener);
      _participantsController.add(_currentParticipants);
    }
  }

  void setActiveSpeaker(int uid, bool isSpeaking) {
    if (_currentParticipants.isNotEmpty) {
      const index = 0;
      _currentParticipants[index] = _currentParticipants[index].copyWith(isSpeaking: isSpeaking);
      _participantsController.add(_currentParticipants);
    }
  }

  @override
  void dispose() {
    _participantsController.close();
    _messagesController.close();
    super.dispose();
  }
}
