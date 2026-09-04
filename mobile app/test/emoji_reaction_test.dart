import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zeparty/models/emoji_reaction_model.dart';
import 'package:zeparty/providers/emoji_reaction_provider.dart';
import 'package:zeparty/widgets/animated_emoji_reaction.dart';
import 'package:zeparty/widgets/emoji_reaction_overlay.dart';
import 'package:zeparty/widgets/emoji_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmojiReactionModel Tests', () {
    test('Verify model serialization and copyWith', () {
      final now = DateTime.now();
      final reaction = EmojiReactionModel(
        reactionId: 'react_101',
        roomId: 'room_live_1',
        senderId: 'user_99',
        emoji: '🔥',
        timestamp: now,
        seatId: 2,
        senderName: 'Alex',
      );

      final map = reaction.toMap();
      expect(map['reactionId'], 'react_101');
      expect(map['roomId'], 'room_live_1');
      expect(map['senderId'], 'user_99');
      expect(map['emoji'], '🔥');
      expect(map['seatId'], 2);
      expect(map['senderName'], 'Alex');

      final deserialized = EmojiReactionModel.fromMap(map);
      expect(deserialized.reactionId, reaction.reactionId);
      expect(deserialized.roomId, reaction.roomId);
      expect(deserialized.senderId, reaction.senderId);
      expect(deserialized.emoji, reaction.emoji);

      final updated = reaction.copyWith(emoji: '❤️');
      expect(updated.emoji, '❤️');
      expect(updated.reactionId, reaction.reactionId);
    });
  });

  group('EmojiReactionProvider State & Rule Tests', () {
    late EmojiReactionProvider provider;

    setUp(() {
      provider = EmojiReactionProvider();
      provider.setActiveRoom('room_001');
    });

    test('Verify reaction creation and receiving', () {
      final success = provider.sendReaction(
        roomId: 'room_001',
        senderId: 'user_1',
        emoji: '❤️',
        seatId: 0,
        senderName: 'Host',
      );

      expect(success, true);
      expect(provider.activeReactions.length, 1);
      expect(provider.activeReactions.first.emoji, '❤️');
      expect(provider.activeReactions.first.senderId, 'user_1');
    });

    test('Verify room isolation (reactions from other rooms are ignored)', () {
      final success = provider.sendReaction(
        roomId: 'room_OTHER_999',
        senderId: 'user_2',
        emoji: '😂',
      );

      expect(success, false);
      expect(provider.activeReactions.isEmpty, true);
    });

    test('Verify duplicate reaction prevention', () {
      final now = DateTime.now();
      final reaction = EmojiReactionModel(
        reactionId: 'dup_react_001',
        roomId: 'room_001',
        senderId: 'user_1',
        emoji: '✨',
        timestamp: now,
      );

      final added1 = provider.receiveReaction(reaction);
      final added2 = provider.receiveReaction(reaction);

      expect(added1, true);
      expect(added2, false);
      expect(provider.activeReactions.length, 1);
    });

    test('Verify rapid spam rate limiting per user', () {
      final sent1 = provider.sendReaction(
        roomId: 'room_001',
        senderId: 'user_spammer',
        emoji: '🔥',
      );
      expect(sent1, true);

      // Immediately send again without delay (should be throttled)
      final sentSpam = provider.sendReaction(
        roomId: 'room_001',
        senderId: 'user_spammer',
        emoji: '😍',
      );
      expect(sentSpam, false);
      expect(provider.activeReactions.length, 1);
    });

    test('Verify clearRoom resets all reactions', () {
      provider.sendReaction(
        roomId: 'room_001',
        senderId: 'user_1',
        emoji: '🎉',
      );

      expect(provider.activeReactions.isNotEmpty, true);
      provider.clearRoom();
      expect(provider.activeReactions.isEmpty, true);
      expect(provider.activeRoomId, null);
    });

    test('Verify GlobalKey anchor registration', () {
      final key = GlobalKey();
      provider.registerAnchor('party_seat_0', key);

      expect(provider.getAnchorKey('party_seat_0'), key);
      provider.unregisterAnchor('party_seat_0');
      expect(provider.getAnchorKey('party_seat_0'), null);
    });
  });

  group('Emoji Reaction Widget Tests', () {
    testWidgets('AnimatedEmojiReaction renders emoji text and disposes cleanly', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                AnimatedEmojiReaction(
                  emoji: '❤️',
                  startPosition: const Offset(150, 300),
                  duration: const Duration(milliseconds: 600),
                  onComplete: () {
                    completed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('❤️'), findsOneWidget);

      // Pump through animation
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('❤️'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(completed, true);
    });

    testWidgets('EmojiReactionOverlay renders active reactions from provider', (tester) async {
      final provider = EmojiReactionProvider();
      provider.setActiveRoom('test_room');
      provider.sendReaction(
        roomId: 'test_room',
        senderId: 'user_test',
        emoji: '🔥',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<EmojiReactionProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  EmojiReactionOverlay(roomId: 'test_room'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('EmojiPickerSheet displays categories and triggers onEmojiSelected', (tester) async {
      String? selectedEmoji;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiPickerSheet(
              onEmojiSelected: (emoji) {
                selectedEmoji = emoji;
              },
            ),
          ),
        ),
      );

      expect(find.text('❤️'), findsWidgets);
      await tester.tap(find.text('❤️').first);
      await tester.pumpAndSettle();

      expect(selectedEmoji, '❤️');
    });
  });
}
