import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/design/premium_card.dart';
import 'game_screen.dart';
import 'rocket_game_sheet.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  String _selectedCategory = 'All Games';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<_GameInfo> _allGames = const [
    _GameInfo(
      title: 'Wheel of Fortune',
      description: 'Spin the diamond wheel for up to 20× multiplier! Place your wager and spin live.',
      icon: '🎡',
      entryFee: 50,
      maxWin: '1,000 🪙',
      gameName: 'Wheel of Fortune',
      category: 'Quick Games',
      badge: 'POPULAR',
    ),
    _GameInfo(
      title: 'Rocket Launch',
      description: 'Contribute diamonds to launch the rocket and win community prizes!',
      icon: '🚀',
      entryFee: 10,
      maxWin: 'Shared Prize Pool',
      gameName: 'Rocket Game',
      category: 'Multiplayer',
      badge: 'COMMUNITY',
    ),
    _GameInfo(
      title: 'Lucky Fruit Slots',
      description: 'Match 3 symbols to hit jackpot! Real-time results shown to your live audience.',
      icon: '🎰',
      entryFee: 30,
      maxWin: '3,000 🪙',
      gameName: 'Lucky Fruit Slots',
      category: 'Quick Games',
      badge: 'JACKPOT',
    ),
    _GameInfo(
      title: 'Treasure Box Mystery',
      description: 'Open mystery boxes for coin surprises! Audience sees your result live.',
      icon: '📦',
      entryFee: 20,
      maxWin: '500 🪙',
      gameName: 'Treasure Box Mystery',
      category: 'Skill Games',
      badge: 'NEW',
    ),
    _GameInfo(
      title: 'Lucky Dice Roll',
      description: 'Predict high roll results to double your coins in seconds!',
      icon: '🎲',
      entryFee: 50,
      maxWin: '2,000 🪙',
      gameName: 'Lucky Dice Roll',
      category: 'Quick Games',
      badge: 'HOT',
    ),
    _GameInfo(
      title: 'Coin Flip Double',
      description: 'Pick Heads or Tails and double your entry coins instantly.',
      icon: '🪙',
      entryFee: 40,
      maxWin: '1,500 🪙',
      gameName: 'Coin Flip Double',
      category: 'Multiplayer',
      badge: 'FAST',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);

    final filteredGames = _allGames.where((g) {
      final matchesCategory = _selectedCategory == 'All Games' || g.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          g.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        title: Text(
          '🎮 Games & Economy Lobby',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              decoration: InputDecoration(
                hintText: 'Search games by name or category...',
                hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.warmGold),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Category Chips Row
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All Games', 'Quick Games', 'Skill Games', 'Multiplayer'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.warmGold,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.black : AppColors.getTextSecondary(isDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Banner Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars_rounded, color: primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Win coins in real-time! All rewards are stored directly into your secure wallet.',
                      style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Available Games (${filteredGames.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
            ),
            const SizedBox(height: 14),

            if (filteredGames.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No games matched your search criteria.'),
                ),
              )
            else
              ...filteredGames.map((game) => _GameCard(game: game, isDark: isDark)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _GameInfo {
  final String title, description, icon, maxWin, gameName, category, badge;
  final int entryFee;
  const _GameInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.entryFee,
    required this.maxWin,
    required this.gameName,
    required this.category,
    required this.badge,
  });
}

class _GameCard extends StatelessWidget {
  final _GameInfo game;
  final bool isDark;
  const _GameCard({required this.game, required this.isDark});

  void _showWagerSheet(BuildContext context) {
    if (game.gameName == 'Rocket Game') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const RocketGameSheet(),
      );
      return;
    }

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    int wager = game.entryFee;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.getBorder(isDark), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(game.icon, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text(game.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 6),
              Text('Max Win: ${game.maxWin}', style: TextStyle(color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 20),
              Text('Set Your Wager', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setS(() { if (wager > game.entryFee) wager -= 10; }),
                    icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.getPrimary(isDark), size: 32),
                  ),
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text('$wager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setS(() => wager += 10),
                    icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.getPrimary(isDark), size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Your balance: 🪙 ${wallet.coins}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: wallet.coins >= wager
                      ? () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => GameScreen(gameName: game.gameName, wager: wager),
                          ));
                        }
                      : null,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: wallet.coins >= wager ? AppColors.getAccentGradient(isDark) : null,
                      color: wallet.coins < wager ? AppColors.getBorder(isDark) : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: wallet.coins >= wager ? AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16) : null,
                    ),
                    child: Center(
                      child: Text(
                        wallet.coins >= wager ? 'Enter Game — 🪙 $wager' : 'Insufficient Coins',
                        style: TextStyle(
                          color: wallet.coins >= wager ? AppColors.onPrimary(isDark: isDark) : AppColors.getTextSecondary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return GestureDetector(
      onTap: () => _showWagerSheet(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PremiumCard(
          padding: const EdgeInsets.all(14),
          radius: 20,
          borderColor: AppColors.getBorderStrong(isDark),
          child: Row(
            children: [
              Text(game.icon, style: const TextStyle(fontSize: 42)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _pill(game.badge.isNotEmpty ? game.badge : 'Max ${game.maxWin}', isDark),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill('Min 🪙 ${game.entryFee}', isDark),
                        _pill('Win ${game.maxWin}', isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: primary, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, bool isDark) {
    final primary = AppColors.getPrimary(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.5), width: 0.9),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: primary, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
