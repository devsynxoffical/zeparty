import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/core/constants/animated_gifts_catalog.dart';
import 'package:zeparty/models/gift_model.dart';
import 'package:zeparty/widgets/animated_live_comment_item.dart';

void main() {
  group('Issue 54: Gift Artwork and Room Message Tests', () {
    test('Catalog contains valid Fresh Juice and Classic Rose with correct assets', () {
      final juice = AnimatedGiftsCatalog.allGifts.firstWhere((g) => g.name == 'Fresh Juice');
      expect(juice.id, equals('cg02'));
      expect(juice.icon, equals('assets/gifts/classic/CG02_Fresh_Juice_150_coins.png'));

      final rose = AnimatedGiftsCatalog.allGifts.firstWhere((g) => g.name == 'Classic Rose');
      expect(rose.id, equals('cg01'));
      expect(rose.icon, equals('assets/gifts/classic/CG01_Classic_Rose_100_coins.png'));
    });

    test('Gift message parsing extracts gift name accurately from text', () {
      const text = 'Javis sent 1 × Fresh Juice 🎁 to Javis';
      final parts = text.split('🎁');
      expect(parts.length, equals(2));

      final prefix = parts[0];
      final xMatch = RegExp(r'×\s*(.+?)$').firstMatch(prefix.trim());
      expect(xMatch, isNotNull);
      final giftName = xMatch!.group(1)?.trim();
      expect(giftName, equals('Fresh Juice'));

      final matchedGift = AnimatedGiftsCatalog.allGifts.firstWhere(
        (g) => g.name.toLowerCase() == giftName!.toLowerCase(),
      );
      expect(matchedGift.id, equals('cg02'));
      expect(matchedGift.icon, contains('CG02_Fresh_Juice'));
    });

    testWidgets('AnimatedLiveCommentItem renders gift message without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedLiveCommentItem(
              senderId: 'user_1',
              senderName: 'Javis',
              text: 'Javis sent 1 × Fresh Juice 🎁 to Javis',
              isGift: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedLiveCommentItem), findsOneWidget);
      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Fresh Juice'),
      );
      expect(richTextFinder, findsOneWidget);
    });
  });
}
