import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/noble_badge_helper.dart';
import '../../models/svip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/svip_provider.dart';
import '../../widgets/user_avatar.dart';
import '../wallet/wallet_screen.dart';
import '../rewards/rewards_screen.dart';
import 'vip_honor_screen.dart';

// ─── Palette ───
const _kGold = Color(0xFFF5C76B);
const _kGoldDeep = Color(0xFFB8812E);
const _kGoldLight = Color(0xFFFFE9B0);
const _kBg = Color(0xFF100C09);
const _kCard = Color(0xFF221811);
const _kPurple = Color(0xFF7A34DC);

class SVIPCenterScreen extends StatefulWidget {
  const SVIPCenterScreen({super.key});

  @override
  State<SVIPCenterScreen> createState() => _SVIPCenterScreenState();
}

class _SVIPCenterScreenState extends State<SVIPCenterScreen> {
  late PageController _pageController;
  final ScrollController _tabController = ScrollController();
  final Set<int> _expandedLevels = {};

  static const double _tabWidth = 72;

  @override
  void initState() {
    super.initState();
    final svip = context.read<SVIPProvider>();
    final initial = (svip.selectedViewLevel - 1).clamp(0, 15);
    _pageController = PageController(initialPage: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      svip.fetchSVIPData();
      _centerTab(initial, animate: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _centerTab(int index, {bool animate = true}) {
    if (!_tabController.hasClients) return;
    final screenW = MediaQuery.of(context).size.width;
    final target = (index * _tabWidth) - (screenW / 2) + (_tabWidth / 2) + 16;
    final clamped = target.clamp(0.0, _tabController.position.maxScrollExtent);
    if (animate) {
      _tabController.animateTo(clamped, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _tabController.jumpTo(clamped);
    }
  }

  void _onPageChanged(int index) {
    context.read<SVIPProvider>().setSelectedViewLevel(index + 1);
    _centerTab(index);
  }

  void _onTabTap(int index) {
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
  }

  /// Exact animal spirit character background strictly matching user specifications:
  /// SVIP 1 — Wolf 🐺
  /// SVIP 2 — White Wolf 🐺
  /// SVIP 3 — Ice Wolf 🐺
  /// SVIP 4 — Unknown Fantasy Animal (Jade Astral Beast)
  /// SVIP 5 — Lion 🦁
  /// SVIP 6 — Golden Lion 🦁
  /// SVIP 7 — Wolf 🐺 (Crimson Night Wolf)
  /// SVIP 8 — Phoenix / Eagle 🦅
  /// SVIP 9 — Starlight Falcon / Fantasy Eagle 🦅
  /// SVIP 10 — Owl 🦉
  /// SVIP 11 — Lion 🦁
  /// SVIP 12 — Golden Lion 🦁
  /// SVIP 13 — Unknown Fantasy Animal (Sapphire Dragon)
  /// SVIP 14 — Unknown Fantasy Animal (Aurora Mythic Beast)
  /// SVIP 15 — Unknown Fantasy Animal (Imperial Golden Dragon King)
  /// SVIP 16 — Unknown Fantasy Animal (Celestial Emperor Dragon)
  String _beastBgForLevel(int level) {
    switch (level) {
      case 1: // Wolf 🐺
      case 2: // White Wolf 🐺
      case 3: // Ice Wolf 🐺
        return 'assets/svip/svip_wolf_bg.jpg';
      case 4: // Fantasy Animal (Emerald Jade Dragon)
        return 'assets/svip/svip_dragon_bg.jpg';
      case 5: // Lion 🦁
      case 6: // Golden Lion 🦁
        return 'assets/svip/svip_lion_bg.jpg';
      case 7: // Wolf 🐺
        return 'assets/svip/svip_wolf_bg.jpg';
      case 8: // Phoenix / Eagle 🦅
      case 9: // Starlight Falcon / Fantasy Eagle 🦅
        return 'assets/svip/svip_eagle_bg.jpg';
      case 10: // Owl 🦉
        return 'assets/svip/svip_eagle_bg.jpg';
      case 11: // Lion 🦁
      case 12: // Golden Lion 🦁
        return 'assets/svip/svip_lion_bg.jpg';
      case 13: // Fantasy Animal (Sapphire Dragon)
      case 14: // Fantasy Animal (Aurora Beast)
      case 15: // Fantasy Animal (Imperial Golden Dragon)
      case 16: // Fantasy Animal (Celestial Emperor)
      default:
        return 'assets/svip/svip_dragon_bg.jpg';
    }
  }

  /// Individual visual color matrix filter giving every SVIP level a distinct, unique beast aesthetic
  ColorFilter? _beastVisualFilter(int level) {
    switch (level) {
      case 1: // Wolf (Amber & Bronze natural dusk)
        return null;
      case 2: // White Wolf (Silver-White Celestial Platinum luminance)
        return const ColorFilter.matrix(<double>[
          1.3, 0.2, 0.2, 0, 45,
          0.2, 1.3, 0.2, 0, 45,
          0.3, 0.3, 1.5, 0, 55,
          0,   0,   0,   1, 0,
        ]);
      case 3: // Ice Wolf (Glacial Arctic Cyan & Diamond Frost Blue)
        return const ColorFilter.matrix(<double>[
          0.3, 0.0, 0.0, 0, 0,
          0.2, 1.3, 0.4, 0, 30,
          0.2, 0.4, 1.8, 0, 70,
          0,   0,   0,   1, 0,
        ]);
      case 4: // Fantasy Animal (Astral Jade & Emerald Mist)
        return const ColorFilter.matrix(<double>[
          0.3, 0.2, 0.0, 0, 0,
          0.2, 1.5, 0.2, 0, 30,
          0.1, 0.3, 0.7, 0, 10,
          0,   0,   0,   1, 0,
        ]);
      case 5: // Lion (Regal Savanna Warm Gold)
        return null;
      case 6: // Golden Lion (Imperial Sun Gold & Royal Purple)
        return const ColorFilter.matrix(<double>[
          1.5, 0.3, 0.0, 0, 25,
          0.2, 1.2, 0.0, 0, 15,
          0.1, 0.1, 0.5, 0, 10,
          0,   0,   0,   1, 0,
        ]);
      case 7: // Wolf (Crimson Twilight Shadow Wolf)
        return const ColorFilter.matrix(<double>[
          1.6, 0.1, 0.1, 0, 35,
          0.1, 0.4, 0.1, 0, 0,
          0.2, 0.1, 0.6, 0, 15,
          0,   0,   0,   1, 0,
        ]);
      case 8: // Phoenix / Eagle (Blazing Solar Fire-Gold)
        return const ColorFilter.matrix(<double>[
          1.6, 0.3, 0.0, 0, 30,
          0.3, 1.3, 0.0, 0, 20,
          0.0, 0.1, 0.3, 0, 0,
          0,   0,   0,   1, 0,
        ]);
      case 9: // Starlight Falcon (Cosmic Nebula Violet)
        return const ColorFilter.matrix(<double>[
          1.1, 0.2, 0.4, 0, 20,
          0.1, 0.7, 0.2, 0, 0,
          0.4, 0.2, 1.6, 0, 50,
          0,   0,   0,   1, 0,
        ]);
      case 10: // Owl (Mystic Royal Gold-Eyed Night Owl)
        return const ColorFilter.matrix(<double>[
          1.0, 0.1, 0.4, 0, 25,
          0.2, 0.6, 0.2, 0, 10,
          0.5, 0.2, 1.5, 0, 45,
          0,   0,   0,   1, 0,
        ]);
      case 11: // Lion (Fierce Celestial Roaring Amber-Bronze)
        return const ColorFilter.matrix(<double>[
          1.4, 0.2, 0.0, 0, 20,
          0.2, 1.1, 0.0, 0, 10,
          0.0, 0.1, 0.4, 0, 0,
          0,   0,   0,   1, 0,
        ]);
      case 12: // Golden Lion (Imperial Solar Sovereign 24k Gold)
        return const ColorFilter.matrix(<double>[
          1.7, 0.4, 0.0, 0, 40,
          0.3, 1.4, 0.0, 0, 25,
          0.1, 0.1, 0.6, 0, 15,
          0,   0,   0,   1, 0,
        ]);
      case 13: // Fantasy Animal (Deep Astral Sapphire)
        return const ColorFilter.matrix(<double>[
          0.2, 0.1, 0.4, 0, 10,
          0.1, 0.6, 0.4, 0, 20,
          0.3, 0.3, 1.7, 0, 60,
          0,   0,   0,   1, 0,
        ]);
      case 14: // Fantasy Animal (Mythic Auroral Cyan-Gold)
        return const ColorFilter.matrix(<double>[
          0.3, 0.3, 0.1, 0, 10,
          0.2, 1.4, 0.3, 0, 35,
          0.2, 0.4, 1.5, 0, 45,
          0,   0,   0,   1, 0,
        ]);
      case 15: // Fantasy Animal (Sovereign Imperial Dragon Gold)
        return const ColorFilter.matrix(<double>[
          1.6, 0.3, 0.0, 0, 35,
          0.2, 1.3, 0.0, 0, 20,
          0.1, 0.2, 0.7, 0, 20,
          0,   0,   0,   1, 0,
        ]);
      case 16: // Fantasy Animal (Grand Emperor Celestial Gold)
      default:
        return const ColorFilter.matrix(<double>[
          1.7, 0.4, 0.1, 0, 45,
          0.3, 1.4, 0.1, 0, 30,
          0.2, 0.2, 0.9, 0, 30,
          0,   0,   0,   1, 0,
        ]);
    }
  }

  /// Dynamic atmosphere colors tuned to each SVIP beast & badge color
  List<Color> _levelAtmosphereColors(int level) {
    switch (level) {
      case 1: // Wolf (Amber & Bronze Dusk)
        return const [Color(0x773A2616), Color(0x2224160C), _kBg];
      case 2: // White Wolf (Moonlit Platinum & Silver)
        return const [Color(0x7745424C), Color(0x2226242C), _kBg];
      case 3: // Ice Wolf (Glacial Arctic Cyan & Frost Blue)
        return const [Color(0x77143B54), Color(0x220C2234), _kBg];
      case 4: // Fantasy Animal (Astral Jade & Emerald Mist)
        return const [Color(0x77164434), Color(0x220D281F), _kBg];
      case 5: // Lion (Regal Savanna Gold & Forest Emerald)
        return const [Color(0x771F4828), Color(0x22122B18), _kBg];
      case 6: // Golden Lion (Imperial Sun Gold & Royal Purple)
        return const [Color(0x77481C5C), Color(0x222A0F38), _kBg];
      case 7: // Wolf (Crimson Twilight Wolf)
        return const [Color(0x774D1640), Color(0x222C0A26), _kBg];
      case 8: // Phoenix / Eagle (Blazing Solar Amber & Gold)
        return const [Color(0x77543012), Color(0x22321C0A), _kBg];
      case 9: // Starlight Falcon (Nebula Violet & Starlight)
        return const [Color(0x7742155C), Color(0x22260B36), _kBg];
      case 10: // Owl (Mystic Royal Purple & Gold Night)
        return const [Color(0x77381A54), Color(0x22220D38), _kBg];
      case 11: // Lion (Celestial Roaring Gold & Bronze)
        return const [Color(0x77583612), Color(0x2236200A), _kBg];
      case 12: // Golden Lion (Imperial Solar Gold & Purple)
        return const [Color(0x775E3F12), Color(0x2238202A), _kBg];
      case 13: // Fantasy Animal (Deep Astral Sapphire)
        return const [Color(0x772A2A5E), Color(0x2216163A), _kBg];
      case 14: // Fantasy Animal (Mythic Auroral Cyan-Gold)
        return const [Color(0x77164248), Color(0x220C262C), _kBg];
      case 15: // Fantasy Animal (Sovereign Imperial Dragon Gold)
        return const [Color(0x77604212), Color(0x223A2030), _kBg];
      case 16: // Fantasy Animal (Grand Emperor Celestial Gold)
      default:
        return const [Color(0x77644612), Color(0x223E2236), _kBg];
    }
  }

  // ─── Record Sheet ───
  void _showRecordSheet(SVIPProvider svip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF17110C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Points Record', style: TextStyle(color: _kGoldLight, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (svip.auditHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No records yet', style: TextStyle(color: Colors.white38, fontSize: 13))),
              )
            else
              ...svip.auditHistory.take(8).map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rec.note, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${rec.timestamp.year}.${rec.timestamp.month.toString().padLeft(2, '0')}.${rec.timestamp.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                        Text('+${AppFormatters.formatNumber(rec.points)}', style: const TextStyle(color: _kGold, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF17110C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => const Padding(
        padding: EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SVIP Rules', style: TextStyle(color: _kGoldLight, fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            Text(
              '• Earn SVIP points by recharging coins.\n'
              '• Reaching the required points unlocks the SVIP level and all its privileges.\n'
              '• Keep enough points before the expiry date to maintain your level.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svip = context.watch<SVIPProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: svip.isLoading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : Stack(
              children: [
                // ─── FULL PAGE SLIDER (EVERY LEVEL HAS ITS OWN DISTINCT CHARACTER BACKGROUND) ───
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: svip.levels.length,
                  itemBuilder: (context, index) => _buildLevelPage(svip, user, svip.levels[index], topPad),
                ),

                // ─── Fixed Top Bar + Text Tabs with Dot ───
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(top: topPad),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFA0B0806), Color(0xD90B0806), Color(0x000B0806)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.7, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildTopBar(),
                        _buildTabs(svip),
                      ],
                    ),
                  ),
                ),

                // ─── Fixed Bottom SVIP Store Bar (Golden-Amber + Subtle Royal Purple) ───
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildStoreBar(),
                ),
              ],
            ),
    );
  }

  // ─── Top bar: back · SVIP · Announcement Horn (VIP Honor Module) · help ───
  Widget _buildTopBar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 52,
              height: 48,
              child: Center(child: CustomPaint(size: Size(11, 18), painter: _ChevronPainter(direction: AxisDirection.left))),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('SVIP', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VIPHonorScreen())),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 44,
              height: 48,
              child: Center(
                child: CustomPaint(
                  size: Size(24, 24),
                  painter: _HonorTrophyPainter(),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _showHelpSheet,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6)),
                  alignment: Alignment.center,
                  child: const Text('?', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Text tabs: SVIP1 … SVIP16 with dot indicator ───
  Widget _buildTabs(SVIPProvider svip) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _tabController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: svip.levels.length,
        itemBuilder: (context, i) {
          final lvl = svip.levels[i];
          final selected = lvl.level == svip.selectedViewLevel;
          return GestureDetector(
            onTap: () => _onTabTap(i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: _tabWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: selected ? 14 : 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    child: Text('SVIP${lvl.level}'),
                  ),
                  const SizedBox(height: 4),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: selected ? 1 : 0,
                    child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── One full page per level (Clean Dedicated Beast Spirit Background with Custom Visual Tone) ───
  Widget _buildLevelPage(SVIPProvider svip, user, SVIPLevel lvl, double topPad) {
    final beastBg = _beastBgForLevel(lvl.level);
    final filter = _beastVisualFilter(lvl.level);
    final atmosColors = _levelAtmosphereColors(lvl.level);

    Widget beastImg = Image.asset(
      beastBg,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.35),
      errorBuilder: (_, _, _) => const SizedBox(),
    );

    if (filter != null) {
      beastImg = ColorFiltered(colorFilter: filter, child: beastImg);
    }

    return Stack(
      children: [
        // 1. Animal Spirit Character Background (Clean, unique visual per level)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 460 + topPad,
          child: beastImg,
        ),

        // 2. Dynamic Atmosphere Tint matching exact Badge Color
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 462 + topPad,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: atmosColors,
              ),
            ),
          ),
        ),

        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: topPad + 92, bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(svip, user, lvl),
              const SizedBox(height: 18),
              _buildActionPills(),
              const SizedBox(height: 22),
              _buildPrivilegeRibbon(svip, lvl),
              const SizedBox(height: 14),
              _buildPrivilegeGrid(lvl),
              const SizedBox(height: 18),
              _buildStarlightBanner(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Header: info left, crest right ───
  Widget _buildHeader(SVIPProvider svip, user, SVIPLevel lvl) {
    final isCurrent = svip.currentLevel == lvl.level;
    final isUnlocked = svip.currentLevel >= lvl.level && svip.currentLevel > 0;
    final progress = lvl.requiredPoints > 0 ? (svip.currentPoints / lvl.requiredPoints).clamp(0.0, 1.0) : 0.0;
    final remaining = (lvl.requiredPoints - svip.currentPoints).clamp(0, lvl.requiredPoints);

    final statusText = isCurrent ? 'Current Level' : (isUnlocked ? 'Unlocked' : 'Locked');
    final hint = isCurrent
        ? 'You need ${AppFormatters.formatNumber(remaining)} points to keep up to SVIP${lvl.level}'
        : isUnlocked
            ? 'You have unlocked SVIP${lvl.level}'
            : 'You need ${AppFormatters.formatNumber(remaining)} points to reach SVIP${lvl.level}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kGold.withValues(alpha: 0.3), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                          child: UserAvatar(imageUrl: user.avatarUrl, name: user.name, radius: 15),
                        ),
                        const SizedBox(width: 8),
                        _GoldText('SVIP${lvl.level}', fontSize: 26),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Thin progress line
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(height: 3, color: Colors.white24),
                          FractionallySizedBox(
                            widthFactor: isUnlocked && !isCurrent ? 1.0 : progress,
                            child: Container(
                              height: 3,
                              decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kGoldLight, _kGold])),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${AppFormatters.formatNumber(svip.currentPoints)}/${lvl.requiredPoints}',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showRecordSheet(svip),
                          child: const Row(
                            children: [
                              Text('Record', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                              SizedBox(width: 3),
                              CustomPaint(size: Size(5, 9), painter: _ChevronPainter(direction: AxisDirection.right, stroke: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(hint, style: const TextStyle(color: _kGold, fontSize: 11.5, height: 1.25)),
                    const SizedBox(height: 8),
                    Text(
                      'Expiry Date: ${svip.expiryDate.year}.${svip.expiryDate.month.toString().padLeft(2, '0')}.${svip.expiryDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                      child: Container(
                        width: 72,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(colors: [Color(0xFFA05BFF), _kPurple]),
                          boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: const Text('Keep', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Crest
            SizedBox(
              width: 140,
              child: Column(
                children: [
                  AnimatedSVIPBadge(
                    key: ValueKey('crest_${lvl.level}'),
                    assetPath: NobleBadgeHelper.getBadgeAsset('SVIP ${lvl.level}') ?? 'assets/svip/svip1_badge.webp',
                    width: 140,
                    height: 140,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Honor / Mission / Benefit pills ───
  Widget _buildActionPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _pill('🏆', 'Honor', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VIPHonorScreen()))),
          _pill('⭐', 'Mission', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen()))),
          _pill('🎁', 'Benefit', () {
            final lvl = context.read<SVIPProvider>().selectedViewLevel;
            setState(() => _expandedLevels.add(lvl));
          }),
        ],
      ),
    );
  }

  Widget _pill(String emoji, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A2C1F), Color(0xFF1F1710)],
            ),
            border: Border.all(color: _kGold.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15, height: 1.1)),
              const SizedBox(height: 1),
              Text(label, style: const TextStyle(color: Color(0xFFD9C7A6), fontSize: 10.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Ornamental "Privileges X / 37" ribbon ───
  Widget _buildPrivilegeRibbon(SVIPProvider svip, SVIPLevel lvl) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wings
          Row(
            children: const [
              Expanded(child: CustomPaint(size: Size.infinite, painter: _RibbonWingPainter(mirror: false))),
              SizedBox(width: 150),
              Expanded(child: CustomPaint(size: Size.infinite, painter: _RibbonWingPainter(mirror: true))),
            ],
          ),
          // Center plaque
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A3F1E), Color(0xFF2B1D0E)],
              ),
              border: Border.all(color: _kGold, width: 1.2),
              boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.35), blurRadius: 10)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Privileges ${lvl.privilegeIds.length} / ${svip.totalPrivilegesCount}',
                  style: const TextStyle(color: _kGoldLight, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 13,
                  height: 13,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _kGoldLight, width: 1)),
                  child: const Text('?', style: TextStyle(color: _kGoldLight, fontSize: 9, fontWeight: FontWeight.w800, height: 1.1)),
                ),
              ],
            ),
          ),
          // Top diamond
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kGoldLight, _kGoldDeep])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dedicated Privilege Asset Resolvers for SVIP 1..16 (Strict Category Isolation) ───
  String _getVipTagAsset(int level) {
    if (level <= 1) return 'assets/svip/svip1_tag.png';
    if (level <= 15) return 'assets/svip/svip${level}_tag.png';
    return 'assets/svip/svip16_tag.png';
  }

  String _getHomepageSkinAsset(int level) {
    if (level <= 15) return 'assets/svip/svip${level}_card.webp';
    return 'assets/svip/svip16_card.webp';
  }

  String _getChatBubbleAsset(int level) {
    if (level <= 15) return 'assets/svip/svip${level}_chat_bubble.webp';
    return 'assets/svip/svip16_chat_bubble.webp';
  }

  String _getAvatarFrameAsset(int level) {
    if (level <= 15) return 'assets/svip/svip${level}_frame.webp';
    return 'assets/svip/svip16_frame.webp';
  }

  String _getEntranceEffectAsset(int level) {
    if (level <= 15) return 'assets/svip/svip${level}_entry.webp';
    return 'assets/svip/svip16_entry.webp';
  }

  String _getSvipBadgeAsset(int level) {
    return NobleBadgeHelper.getBadgeAsset('SVIP $level') ?? 'assets/svip/SVIP${level < 10 ? '0$level' : (level <= 15 ? level : '15')}_badge_live.webp';
  }

  // ─── Privilege cards (3 per row, expandable, strictly category-correct) ───
  Widget _buildPrivilegeGrid(SVIPLevel lvl) {
    final l = lvl.level;

    final items = <_PrivItem>[
      _PrivItem('VIP Tag', _getVipTagAsset(l), fallback: 'assets/svip/svip1_tag.png'),
      _PrivItem('Homepage Skin', _getHomepageSkinAsset(l), fallback: 'assets/svip/svip3_card.webp', isSkin: true),
      _PrivItem('Chat Bubble', _getChatBubbleAsset(l), fallback: 'assets/svip/svip6_chat_bubble.webp'),
      _PrivItem('Avatar Frame', _getAvatarFrameAsset(l), fallback: 'assets/svip/svip6_frame.webp'),
      _PrivItem('Entrance Effect', _getEntranceEffectAsset(l), fallback: 'assets/svip/svip6_entry.webp'),
      _PrivItem('SVIP Badge', _getSvipBadgeAsset(l), fallback: 'assets/svip/SVIP01_badge_live.webp'),
    ];

    final expanded = _expandedLevels.contains(l);
    final visible = expanded ? items : items.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.98,
            ),
            itemBuilder: (_, i) => _privCard(visible[i]),
          ),
          GestureDetector(
            onTap: () => setState(() => expanded ? _expandedLevels.remove(l) : _expandedLevels.add(l)),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 34,
              width: 80,
              child: Center(
                child: CustomPaint(
                  size: const Size(16, 8),
                  painter: _ChevronPainter(direction: expanded ? AxisDirection.up : AxisDirection.down, stroke: 1.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privCard(_PrivItem item) {
    Widget img = Image.asset(
      item.asset,
      fit: item.isSkin ? BoxFit.cover : BoxFit.contain,
      errorBuilder: (_, _, _) => Image.asset(item.fallback, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox()),
    );

    if (item.isSkin) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Color(0xFFCFA766), BlendMode.multiply),
          child: img,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2B1C), _kCard],
        ),
        border: Border.all(color: _kGold.withValues(alpha: 0.28), width: 0.8),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      child: Column(
        children: [
          Expanded(child: Center(child: img)),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFBFAF95), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Starlight Summit banner ───
  Widget _buildStarlightBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/svip/svip_starlight_banner.jpg', fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: _kCard)),
              Container(color: Colors.black.withValues(alpha: 0.15)),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GoldText('Starlight', fontSize: 17, italic: false),
                    _GoldText('Summit', fontSize: 17, italic: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom "SVIP store" bar (Rich Golden-Amber with Subtle Royal Purple Under-tones) ───
  Widget _buildStoreBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
      child: SizedBox(
        height: 74 + bottomPad,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Gold & Purple Arch Frame
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(painter: _StoreBarPainter()),
            ),
            // Label
            Positioned(
              top: 30,
              child: Text(
                'SVIP store',
                style: TextStyle(
                  color: const Color(0xFFFFF7E6),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.9), blurRadius: 10),
                    Shadow(color: _kPurple.withValues(alpha: 0.6), blurRadius: 6),
                  ],
                ),
              ),
            ),
            // Crown Gem (Gold & Purple Crystal)
            Positioned(
              top: 0,
              child: Transform.rotate(
                angle: 0.785,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE599), Color(0xFFD4AF37), Color(0xFF8B3DFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: _kGoldLight, width: 1.6),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.75), blurRadius: 12),
                      BoxShadow(color: _kPurple.withValues(alpha: 0.5), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivItem {
  final String title;
  final String asset;
  final String fallback;
  final bool isSkin;
  const _PrivItem(this.title, this.asset, {required this.fallback, this.isSkin = false});
}

// ─── Gold gradient text ───
class _GoldText extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool italic;
  const _GoldText(this.text, {required this.fontSize, this.italic = true});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF4CF), _kGold, Color(0xFFC0852F)],
      ).createShader(r),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.05,
          fontWeight: FontWeight.w900,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          shadows: const [Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
      ),
    );
  }
}

// ─── Custom-drawn High-Visibility Golden Honor Trophy ───
class _HonorTrophyPainter extends CustomPainter {
  const _HonorTrophyPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Outer glow for high visibility against any background
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.38, glowPaint);

    // Rich 3D Gold Gradient Shader
    final goldShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFF9E6),
        Color(0xFFFFDF73),
        Color(0xFFFFB300),
        Color(0xFFE65100),
      ],
      stops: [0.0, 0.35, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final fillPaint = Paint()..shader = goldShader;

    final strokePaint = Paint()
      ..shader = goldShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Trophy Handles (Left & Right)
    final leftHandle = Path()
      ..moveTo(w * 0.30, h * 0.26)
      ..cubicTo(w * 0.08, h * 0.26, w * 0.08, h * 0.52, w * 0.32, h * 0.52);
    canvas.drawPath(leftHandle, strokePaint);

    final rightHandle = Path()
      ..moveTo(w * 0.70, h * 0.26)
      ..cubicTo(w * 0.92, h * 0.26, w * 0.92, h * 0.52, w * 0.68, h * 0.52);
    canvas.drawPath(rightHandle, strokePaint);

    // 2. Trophy Cup Body
    final cup = Path()
      ..moveTo(w * 0.26, h * 0.20)
      ..lineTo(w * 0.74, h * 0.20)
      ..lineTo(w * 0.70, h * 0.45)
      ..cubicTo(w * 0.68, h * 0.62, w * 0.32, h * 0.62, w * 0.30, h * 0.45)
      ..close();
    canvas.drawPath(cup, fillPaint);

    // 3. Top Rim
    final rimRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.20), width: w * 0.48, height: h * 0.09);
    canvas.drawOval(rimRect, Paint()..color = const Color(0xFFFFF4D0));

    // 4. Stem
    final stem = Path()
      ..moveTo(w * 0.45, h * 0.58)
      ..lineTo(w * 0.55, h * 0.58)
      ..lineTo(w * 0.53, h * 0.74)
      ..lineTo(w * 0.47, h * 0.74)
      ..close();
    canvas.drawPath(stem, fillPaint);

    // 5. Pedestal Base
    final base = Path()
      ..moveTo(w * 0.35, h * 0.74)
      ..lineTo(w * 0.65, h * 0.74)
      ..lineTo(w * 0.72, h * 0.88)
      ..lineTo(w * 0.28, h * 0.88)
      ..close();
    canvas.drawPath(base, fillPaint);

    // 6. Base Plate
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.87, w * 0.52, h * 0.08),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFFFD54F));

    // 7. Center Star Sparkle Highlight
    final starCenter = Offset(w * 0.5, h * 0.38);
    canvas.drawCircle(starCenter, 1.4, Paint()..color = Colors.white);

    final sparkle = Path()
      ..moveTo(starCenter.dx, starCenter.dy - 3.2)
      ..lineTo(starCenter.dx, starCenter.dy + 3.2)
      ..moveTo(starCenter.dx - 3.2, starCenter.dy)
      ..lineTo(starCenter.dx + 3.2, starCenter.dy);
    canvas.drawPath(sparkle, Paint()..color = Colors.white..strokeWidth = 1.0..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Custom-drawn chevron (no icon font) ───
class _ChevronPainter extends CustomPainter {
  final AxisDirection direction;
  final double stroke;
  const _ChevronPainter({required this.direction, this.stroke = 2.2});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (direction) {
      case AxisDirection.left:
        path..moveTo(s.width, 0)..lineTo(0, s.height / 2)..lineTo(s.width, s.height);
        break;
      case AxisDirection.right:
        path..moveTo(0, 0)..lineTo(s.width, s.height / 2)..lineTo(0, s.height);
        break;
      case AxisDirection.down:
        path..moveTo(0, 0)..lineTo(s.width / 2, s.height)..lineTo(s.width, 0);
        break;
      case AxisDirection.up:
        path..moveTo(0, s.height)..lineTo(s.width / 2, 0)..lineTo(s.width, s.height);
        break;
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter old) => old.direction != direction || old.stroke != stroke;
}

// ─── Ornamental gold wing beside the privileges plaque ───
class _RibbonWingPainter extends CustomPainter {
  final bool mirror;
  const _RibbonWingPainter({required this.mirror});

  @override
  void paint(Canvas canvas, Size s) {
    if (mirror) {
      canvas.translate(s.width, 0);
      canvas.scale(-1, 1);
    }
    final cy = s.height / 2;
    final rect = Rect.fromLTWH(0, 0, s.width, s.height);

    final fade = const LinearGradient(colors: [Color(0x00F5C76B), _kGold]).createShader(rect);

    // Main swept band
    final band = Path()
      ..moveTo(0, cy + 2)
      ..quadraticBezierTo(s.width * 0.45, cy - 12, s.width, cy - 3)
      ..lineTo(s.width, cy + 3)
      ..quadraticBezierTo(s.width * 0.5, cy - 4, 0, cy + 6)
      ..close();
    canvas.drawPath(band, Paint()..shader = fade);

    // Thin lines
    final line = Paint()
      ..shader = fade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final l1 = Path()
      ..moveTo(s.width * 0.1, cy + 10)
      ..quadraticBezierTo(s.width * 0.6, cy + 2, s.width, cy + 8);
    canvas.drawPath(l1, line);
    final l2 = Path()
      ..moveTo(s.width * 0.25, cy - 12)
      ..quadraticBezierTo(s.width * 0.7, cy - 16, s.width, cy - 9);
    canvas.drawPath(l2, line);

    // Curl near plaque
    final curl = Paint()
      ..color = _kGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(Rect.fromCircle(center: Offset(s.width - 10, cy), radius: 6), 1.2, 4.2, false, curl);
    canvas.drawCircle(Offset(s.width - 2, cy), 2.2, Paint()..color = _kGoldLight);
  }

  @override
  bool shouldRepaint(covariant _RibbonWingPainter old) => old.mirror != mirror;
}

// ─── Golden-Amber + Royal Purple Arched Store Bar (Matching Screen Luxury Theme) ───
class _StoreBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final archTop = 0.0;
    final shoulder = 16.0;

    final path = Path()
      ..moveTo(0, shoulder + 6)
      ..lineTo(w * 0.22, shoulder + 6)
      ..quadraticBezierTo(w * 0.32, shoulder, w * 0.36, archTop + 8)
      ..quadraticBezierTo(w * 0.5, archTop - 4, w * 0.64, archTop + 8)
      ..quadraticBezierTo(w * 0.68, shoulder, w * 0.78, shoulder + 6)
      ..lineTo(w, shoulder + 6)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    // Fill: Rich Golden-Bronze with subtle deep Royal Purple Under-tones
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5E3914),
            Color(0xFF381F2B),
            Color(0xFF1D101E),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Gold & Purple Rim Border
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFB8812E),
            Color(0xFFFFE9B0),
            Color(0xFFF5C76B),
            Color(0xFF8B3DFF),
            Color(0xFFB8812E),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Inner gold glow line
    final glow = Path()
      ..moveTo(w * 0.38, archTop + 14)
      ..quadraticBezierTo(w * 0.5, archTop + 4, w * 0.62, archTop + 14);
    canvas.drawPath(
      glow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = const LinearGradient(
          colors: [Color(0x00FFE9B0), Color(0xCCFFE9B0), Color(0x00FFE9B0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Animated crest (kept public — used by other screens) ───
class AnimatedSVIPBadge extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;

  const AnimatedSVIPBadge({
    super.key,
    required this.assetPath,
    this.width = 124,
    this.height = 124,
  });

  @override
  State<AnimatedSVIPBadge> createState() => _AnimatedSVIPBadgeState();
}

class _AnimatedSVIPBadgeState extends State<AnimatedSVIPBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.97, end: 1.03).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Image.asset(
        widget.assetPath,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(width: widget.width, height: widget.height),
      ),
    );
  }
}
