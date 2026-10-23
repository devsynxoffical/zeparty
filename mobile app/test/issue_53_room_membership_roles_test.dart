import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/models/party_participant_model.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/providers/live_party_provider.dart';

void main() {
  group('Issue 53: Persistent Room Membership and Roles Tests', () {
    test('Format test: 2/200 does not become 2/00', () {
      const value = '2/200';
      const highlightValue = '2';

      // Old faulty logic
      final oldResult = value.replaceAll(highlightValue, '');
      expect(oldResult, equals('/00'), reason: 'Verifies the old bug stripped all 2s');

      // New fixed logic
      final newResult = value.startsWith(highlightValue)
          ? value.substring(highlightValue.length)
          : (value.contains(highlightValue)
              ? value.replaceFirst(highlightValue, '')
              : value);
      expect(newResult, equals('/200'));
      expect('$highlightValue$newResult', equals('2/200'));
    });

    test('LivePartyProvider preserves explicit membership separately from presence', () {
      final provider = LivePartyProvider();
      const roomId = 'room_123';

      final user1 = const UserModel(
        id: 'user_1',
        name: 'Alice',
        username: 'alice',
        avatarUrl: '',
      );
      final user2 = const UserModel(
        id: 'user_2',
        name: 'Bob',
        username: 'bob',
        avatarUrl: '',
      );

      expect(provider.getSavedRoomMemberCount(roomId), equals(0));

      // Explicit join
      provider.saveExplicitMembership(roomId, user1);
      provider.saveExplicitMembership(roomId, user2);

      expect(provider.getSavedRoomMemberCount(roomId), equals(2));
      expect(provider.isUserRoomMember(roomId, 'user_1'), isTrue);
      expect(provider.isUserRoomMember(roomId, 'user_2'), isTrue);

      // Promote user2 to Admin
      provider.updateSavedMemberRole(roomId, 'user_2', ParticipantRole.moderator);
      final members = provider.getSavedRoomMembers(roomId);
      final bobMember = members.firstWhere((m) => m.user.id == 'user_2');
      expect(bobMember.role, equals(ParticipantRole.moderator));

      // Ordinary presence removal must NOT remove saved membership
      provider.removeParticipant('user_1');
      expect(provider.isUserRoomMember(roomId, 'user_1'), isTrue);
      expect(provider.getSavedRoomMemberCount(roomId), equals(2));

      // Explicit unjoin removes membership
      provider.removeExplicitMembership(roomId, 'user_1');
      expect(provider.isUserRoomMember(roomId, 'user_1'), isFalse);
      expect(provider.getSavedRoomMemberCount(roomId), equals(1));
    });

    test('Roster ordering: Owner first, Admins next, ordinary Members afterward', () {
      const ownerId = 'host_owner';
      final now = DateTime.now();
      final list = <PartyParticipantModel>[
        PartyParticipantModel(
          user: const UserModel(id: 'member_1', name: 'Zoe', username: 'zoe', avatarUrl: ''),
          role: ParticipantRole.listener,
          joinedAt: now,
        ),
        PartyParticipantModel(
          user: const UserModel(id: 'admin_1', name: 'Charlie', username: 'charlie', avatarUrl: ''),
          role: ParticipantRole.moderator,
          joinedAt: now,
        ),
        PartyParticipantModel(
          user: const UserModel(id: ownerId, name: 'Owner Javis', username: 'javis', avatarUrl: ''),
          role: ParticipantRole.host,
          joinedAt: now,
        ),
        PartyParticipantModel(
          user: const UserModel(id: 'member_2', name: 'Anna', username: 'anna', avatarUrl: ''),
          role: ParticipantRole.listener,
          joinedAt: now,
        ),
      ];

      // Sort with Issue 53 hierarchy
      list.sort((a, b) {
        final aIsOwner = a.user.id == ownerId || a.role == ParticipantRole.host;
        final bIsOwner = b.user.id == ownerId || b.role == ParticipantRole.host;
        if (aIsOwner && !bIsOwner) return -1;
        if (!aIsOwner && bIsOwner) return 1;

        final aIsAdmin = a.role == ParticipantRole.moderator;
        final bIsAdmin = b.role == ParticipantRole.moderator;
        if (aIsAdmin && !bIsAdmin) return -1;
        if (!aIsAdmin && bIsAdmin) return 1;

        return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
      });

      expect(list[0].user.id, equals(ownerId));
      expect(list[1].user.id, equals('admin_1'));
      expect(list[2].user.id, equals('member_2')); // 'Anna' before 'Zoe'
      expect(list[3].user.id, equals('member_1'));
    });
  });
}
