import '../../models/user_model.dart';
import '../../models/live_room_model.dart';
import '../../models/pk_battle_model.dart';
import '../../models/party_room_model.dart';
import '../../models/gift_model.dart';
import '../../models/post_model.dart';
import '../../models/short_video_model.dart';
import '../../models/transaction_model.dart';
import '../../models/vip_item_model.dart';
import '../../models/notification_model.dart';
import '../../models/medal_model.dart';
import '../../models/outfit_model.dart';

class DummyData {
  DummyData._();

  static const currentUser = UserModel(
    id: 'user_1001',
    username: 'danial_live',
    name: 'Danial Khan',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
    bio: 'Official Streamer & Content Creator 🚀 | Daily Streams 8 PM EST',
    followers: 48900,
    following: 320,
    diamonds: 8520,
    coins: 45000,
    rCoins: 1450.75,
    isVip: true,
    vipLevel: 'VIP 5',
    isHost: true,
    isAgency: true,
    agencyName: 'Star Stream Network',
  );

  static const List<UserModel> popularUsers = [
    UserModel(
      id: 'user_1002',
      username: 'sophia_vibe',
      name: 'Sophia Rose',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      bio: 'Singer & Vocalist 🎙️ | Music Party Host',
      followers: 128000,
      following: 150,
      isLive: true,
      badge: 'Superstar Host ⭐',
    ),
    UserModel(
      id: 'user_1003',
      username: 'alex_gamer',
      name: 'Alex Rivera',
      avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=300&q=80',
      bio: 'Pro Mobile Gamer & Streamer 🎮',
      followers: 95400,
      following: 89,
      isLive: true,
      badge: 'PK King 🏆',
    ),
    UserModel(
      id: 'user_1004',
      username: 'elena_dance',
      name: 'Elena Rostova',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      bio: 'Choreographer & Daily Vlogger 💃',
      followers: 67200,
      following: 412,
      isLive: true,
    ),
    UserModel(
      id: 'user_1005',
      username: 'marcus_beats',
      name: 'Marcus Vance',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      bio: 'DJ & EDM Producer 🎧 Live Audio Parties',
      followers: 43100,
      following: 205,
    ),
  ];

  static final List<LiveRoomModel> liveRooms = [
    LiveRoomModel(
      id: 'room_001',
      title: '✨ Late Night Chill & Music Sessions 🎵 Sing With Me!',
      host: popularUsers[0],
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80',
      viewerCount: 4820,
      category: 'Music',
      startTime: DateTime.now().subtract(const Duration(minutes: 42)),
    ),
    LiveRoomModel(
      id: 'room_002',
      title: '🔥 INTENSE PK BATTLE VS ALEX RIVERA! SEND GIFTS!',
      host: popularUsers[1],
      coverUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80',
      viewerCount: 8930,
      category: 'PK',
      startTime: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    LiveRoomModel(
      id: 'room_003',
      title: '💃 Dance Routine Showcase & Q&A | Join Party',
      host: popularUsers[2],
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?auto=format&fit=crop&w=600&q=80',
      viewerCount: 3120,
      category: 'Live',
      startTime: DateTime.now().subtract(const Duration(minutes: 68)),
    ),
    LiveRoomModel(
      id: 'room_004',
      title: '🎧 DJ EDM Party Night - Request Your Songs!',
      host: popularUsers[3],
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=600&q=80',
      viewerCount: 2450,
      category: 'Party',
      startTime: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    LiveRoomModel(
      id: 'room_005',
      title: '🎙️ Midnight Chat & Storytime (Join Up!)',
      host: currentUser,
      coverUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=600&q=80',
      viewerCount: 890,
      category: 'Party',
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    LiveRoomModel(
      id: 'room_006',
      title: '🎮 Gamers Lounge - Let\'s squad up!',
      host: popularUsers[1],
      coverUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80',
      viewerCount: 1540,
      category: 'Party',
      startTime: DateTime.now().subtract(const Duration(minutes: 60)),
    ),
    LiveRoomModel(
      id: 'room_007',
      title: '🎤 Karaoke Night - Anyone can sing!',
      host: popularUsers[0],
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80',
      viewerCount: 3200,
      category: 'Party',
      startTime: DateTime.now().subtract(const Duration(minutes: 120)),
    ),
  ];

  static final PKBattleModel samplePkBattle = PKBattleModel(
    id: 'pk_99',
    hostA: popularUsers[0],
    hostB: popularUsers[1],
    scoreA: 14500,
    scoreB: 18200,
    remainingTime: const Duration(minutes: 2, seconds: 45),
  );

  static final PartyRoomModel samplePartyRoom = PartyRoomModel(
    id: 'party_101',
    title: '🎉 Multi-Seat Global Voice Party | Meet Friends',
    host: currentUser,
    roomType: 'Open Party',
    totalListeners: 1420,
    seats: [
      PartySeatModel(seatIndex: 1, user: currentUser),
      PartySeatModel(seatIndex: 2, user: popularUsers[0]),
      PartySeatModel(seatIndex: 3, user: popularUsers[1]),
      PartySeatModel(seatIndex: 4, user: popularUsers[2]),
      PartySeatModel(seatIndex: 5, user: popularUsers[3]),
      const PartySeatModel(seatIndex: 6, isMuted: false),
      const PartySeatModel(seatIndex: 7, isMuted: true),
      const PartySeatModel(seatIndex: 8, isLocked: true),
    ],
  );

  static const List<GiftModel> gifts = [
    GiftModel(id: 'g1', name: 'Rose', icon: '🌹', diamondPrice: 10, category: 'Popular', label: 'HOT'),
    GiftModel(id: 'g2', name: 'Love Heart', icon: '💖', diamondPrice: 50, category: 'Popular'),
    GiftModel(id: 'g3', name: 'Sports Car', icon: '🏎️', diamondPrice: 500, category: 'Luxury', label: 'NEW'),
    GiftModel(id: 'g4', name: 'Private Jet', icon: '🛩️', diamondPrice: 2000, category: 'Luxury'),
    GiftModel(id: 'g5', name: 'Golden Crown', icon: '👑', diamondPrice: 1000, category: 'VIP', label: 'MAX'),
    GiftModel(id: 'g6', name: 'Castle', icon: '🏰', diamondPrice: 5000, category: 'VIP'),
    GiftModel(id: 'g7', name: 'Firework', icon: '🎆', diamondPrice: 300, category: 'Special', label: 'x50'),
    GiftModel(id: 'g8', name: 'Magic Wand', icon: '🪄', diamondPrice: 150, category: 'Special'),
  ];

  static final List<PostModel> posts = [
    PostModel(
      id: 'p1',
      author: popularUsers[0],
      content: 'Thank you everyone for tuning into tonight’s live stream! Over 8,000 viewers! You guys are amazing! ❤️🎤',
      imageUrls: ['https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80'],
      likes: 3420,
      comments: 184,
      shares: 45,
      isLiked: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    PostModel(
      id: 'p2',
      author: popularUsers[1],
      content: 'Got the victory in today’s PK Battle tournament! Thanks to my top gifters for the insane support! 🏆🚀',
      imageUrls: ['https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80'],
      likes: 5120,
      comments: 310,
      shares: 98,
      createdAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
  ];

  static final List<ShortVideoModel> shortVideos = [
    ShortVideoModel(
      id: 'v1',
      creator: popularUsers[0],
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      caption: 'Acoustic session snippet from yesterday’s live stream! 🎸✨ #singing #live',
      musicTitle: 'Original Sound - Sophia Rose',
      likes: 12400,
      comments: 420,
      gifts: 890,
      isLiked: true,
    ),
    ShortVideoModel(
      id: 'v2',
      creator: popularUsers[1],
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      caption: 'Insane 1v4 clutch moment in PK championship match! 🔥🎮 #esports #pkbattle',
      musicTitle: 'Battle Hype Beats - Alex Rivera',
      likes: 28900,
      comments: 940,
      gifts: 1540,
    ),
  ];

  static final List<TransactionModel> transactions = [
    TransactionModel(
      id: 'tx_001',
      title: 'Platinum Coin Package',
      type: 'Recharge',
      amount: 50000,
      currency: 'Coins',
      status: 'Completed',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TransactionModel(
      id: 'tx_002',
      title: 'Host Earnings Cashout',
      type: 'Withdrawal',
      amount: 450.00,
      currency: 'USD',
      status: 'Paid',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    TransactionModel(
      id: 'tx_003',
      title: 'Sent Golden Crown Gift',
      type: 'Gift Sent',
      amount: 1000,
      currency: 'Diamonds',
      status: 'Completed',
      date: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  static const List<VipItemModel> vipItems = [
    VipItemModel(
      id: 'vip_1',
      title: 'Gold Dragon Entry Effect',
      description: 'Display an animated dragon entrance when joining live streams.',
      icon: '🐉',
      category: 'Entry Effects',
      coinPrice: 5000,
      isOwned: true,
    ),
    VipItemModel(
      id: 'vip_2',
      title: 'Crown Avatar Frame',
      description: 'Gold shimmering crown surrounding your profile avatar.',
      icon: '👑',
      category: 'Avatar Frames',
      coinPrice: 3500,
      isOwned: true,
    ),
    VipItemModel(
      id: 'vip_3',
      title: 'Golden VIP Badge',
      description: 'Exclusive golden badge displayed next to your username in chat.',
      icon: '🎖️',
      category: 'Badges',
      coinPrice: 2000,
    ),
    VipItemModel(
      id: 'vip_4',
      title: 'Neon Cyan Name Color',
      description: 'Stand out in chat feeds with custom glowing cyan text.',
      icon: '🎨',
      category: 'Username Colors',
      coinPrice: 1500,
    ),
  ];

  static final List<AppNotificationModel> notifications = [
    AppNotificationModel(
      id: 'n1',
      title: 'New Follower',
      message: 'Sophia Rose started following you.',
      category: 'Follower',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    AppNotificationModel(
      id: 'n2',
      title: 'Gift Received! 🎁',
      message: 'Alex Rivera sent you a Golden Crown (1,000 Diamonds).',
      category: 'Gift',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    AppNotificationModel(
      id: 'n3',
      title: 'PK Battle Invitation',
      message: 'Elena Rostova invited you to a 5-minute PK Battle!',
      category: 'Invitation',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotificationModel(
      id: 'n4',
      title: 'Recharge Successful',
      message: 'Your account was credited with 50,000 Coins.',
      category: 'Recharge',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static const List<MedalModel> userMedals = [
    MedalModel(
      id: 'm1',
      name: 'Super Creator',
      description: 'Streamed for over 100 hours in total.',
      iconUrl: 'super_creator',
      isEarned: true,
      isEquipped: true,
      category: 'Streaming',
    ),
    MedalModel(
      id: 'm2',
      name: 'Charity King',
      description: 'Donated over 50,000 diamonds in a week.',
      iconUrl: 'charity_king',
      isEarned: true,
      isEquipped: false,
      category: 'Gifting',
    ),
    MedalModel(
      id: 'm3',
      name: 'Rising Star',
      description: 'Gained 1,000 followers in a single day.',
      iconUrl: 'rising_star',
      isEarned: false,
      category: 'Activity',
    ),
    MedalModel(
      id: 'm4',
      name: 'ZeParty Legend',
      description: 'Won 10 consecutive PK battles.',
      iconUrl: 'zep_legend',
      isEarned: false,
      category: 'Activity',
    ),
  ];

  static const List<OutfitModel> userOutfits = [
    OutfitModel(
      id: 'o1',
      name: 'Gold Crown Frame',
      category: OutfitCategory.frame,
      imageUrl: 'assets/images/frame_neon.jpg',
      status: OutfitStatus.active,
      daysRemaining: 15,
    ),
    OutfitModel(
      id: 'o2',
      name: 'Neon Cyber Frame',
      category: OutfitCategory.frame,
      imageUrl: 'assets/images/frame_neon.jpg',
      status: OutfitStatus.available,
    ),
    OutfitModel(
      id: 'o3',
      name: 'Fire Dragon Frame',
      category: OutfitCategory.frame,
      imageUrl: 'assets/images/frame_neon.jpg',
      status: OutfitStatus.expired,
    ),
    OutfitModel(
      id: 'o4',
      name: 'VIP Gold Chat Bubble',
      category: OutfitCategory.bubble,
      imageUrl: 'assets/images/card_vip.jpg',
      status: OutfitStatus.active,
      daysRemaining: 30,
    ),
    OutfitModel(
      id: 'o5',
      name: 'Heart Emoji Bubble',
      category: OutfitCategory.bubble,
      imageUrl: 'assets/images/effect_floating_hearts.jpg',
      status: OutfitStatus.available,
    ),
    OutfitModel(
      id: 'o6',
      name: 'Sports Car Entry',
      category: OutfitCategory.car,
      imageUrl: 'assets/images/gift_supercar.jpg',
      status: OutfitStatus.active,
      daysRemaining: 5,
    ),
    OutfitModel(
      id: 'o7',
      name: 'Golden Dragon Ride',
      category: OutfitCategory.car,
      imageUrl: 'assets/images/gift_supercar.jpg',
      status: OutfitStatus.available,
    ),
    OutfitModel(
      id: 'o8',
      name: 'Starfall Entrance',
      category: OutfitCategory.effect,
      imageUrl: 'assets/images/effect_floating_hearts.jpg',
      status: OutfitStatus.available,
    ),
  ];
}
