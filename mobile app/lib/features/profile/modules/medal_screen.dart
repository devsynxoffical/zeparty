import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/medal_model.dart';
import '../../../../providers/auth_provider.dart';

class MedalScreen extends StatefulWidget {
  const MedalScreen({super.key});

  @override
  State<MedalScreen> createState() => _MedalScreenState();
}

class _MedalScreenState extends State<MedalScreen> {
  late List<MedalModel> _medals;
  int _selectedCategoryIndex = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _medals = List.from(MedalModel.defaultMedals);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userLevel = auth.currentUser.wealthLevel;
      _medals = MedalModel.defaultMedals.map((m) {
        final unlocked = m.isUnlockedForLevel(userLevel);
        return m.copyWith(isEarned: unlocked);
      }).toList();
      _initialized = true;
    }
  }

  void _toggleEquip(int index) {
    setState(() {
      final selectedMedal = _medals[index];
      if (!selectedMedal.isEarned) return;

      // Unequip currently equipped medal if any
      for (int i = 0; i < _medals.length; i++) {
        if (_medals[i].isEquipped && i != index) {
          _medals[i] = _medals[i].copyWith(isEquipped: false);
        }
      }

      // Toggle selected
      _medals[index] = selectedMedal.copyWith(isEquipped: !selectedMedal.isEquipped);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_medals[index].isEquipped 
          ? 'Equipped ${_medals[index].name}' 
          : 'Unequipped ${_medals[index].name}'
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  IconData _getIcon(String key) {
    switch (key) {
      case 'super_creator': return Icons.videocam_rounded;
      case 'charity_king': return Icons.diamond_rounded;
      case 'rising_star': return Icons.local_fire_department_rounded;
      default: return Icons.workspace_premium_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(isDark),
          title: Text('Medal Center', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.getPrimary(isDark),
            unselectedLabelColor: AppColors.getTextSecondary(isDark),
            indicatorColor: AppColors.getPrimary(isDark),
            tabs: const [
              Tab(text: 'Medal Wall'),
              Tab(text: 'My Medals'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMedalWall(isDark),
            _buildMyMedals(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalWall(bool isDark) {
    final primary = AppColors.getPrimary(isDark);
    final earnedCount = _medals.where((m) => m.isEarned).length;
    final categories = ['All', 'Streaming', 'Gifting', 'Activity'];

    return Column(
      children: [
        // Category Filter
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedCategoryIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? primary : AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? primary : AppColors.getBorder(isDark)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.getTextPrimary(isDark),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Progress Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorder(isDark)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stars_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Medals Collected',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$earnedCount',
                          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          ' / ${_medals.length}',
                          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: earnedCount / _medals.length,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              final currentCategory = categories[_selectedCategoryIndex];
              final displayedMedals = currentCategory == 'All' 
                ? _medals 
                : _medals.where((m) => m.category == currentCategory).toList();
              
              if (displayedMedals.isEmpty) {
                return Center(
                  child: Text('No medals in this category.', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                );
              }
              
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: displayedMedals.length,
                itemBuilder: (context, index) {
                  final medal = displayedMedals[index];
              final lockedColor = isDark ? Colors.white30 : Colors.black26;
              final lockedBg = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: medal.isEarned 
                            ? AppColors.metallicGold.withValues(alpha: 0.15) 
                            : lockedBg,
                        shape: BoxShape.circle,
                      ),
                      child: medal.iconUrl.startsWith('assets/')
                          ? Image.asset(
                              medal.iconUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(_getIcon(medal.iconUrl), color: medal.isEarned ? AppColors.metallicGold : lockedColor, size: 32),
                            )
                          : Icon(
                              _getIcon(medal.iconUrl), 
                              color: medal.isEarned ? AppColors.metallicGold : lockedColor,
                              size: 32,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        medal.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: medal.isEarned ? AppColors.getTextPrimary(isDark) : lockedColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (medal.isEarned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) => Icon(
                          Icons.star_rounded, 
                          size: 10, 
                          color: i < 2 ? AppColors.metallicGold : Colors.grey.withValues(alpha: 0.5),
                        )),
                      )
                    else
                      Icon(Icons.lock_rounded, size: 12, color: lockedColor),
                  ],
                ),
              );
            },
          );
        }),
      ),
    ],
  );
}

  Widget _buildMyMedals(bool isDark) {
    final primary = AppColors.getPrimary(isDark);
    final earnedMedals = _medals.where((m) => m.isEarned).toList();
    final lockedMedals = _medals.where((m) => !m.isEarned).toList();
    final earnedCount = earnedMedals.length;

    Widget buildMedalItem(MedalModel medal, int originalIndex) {
      final lockedColor = isDark ? Colors.white30 : Colors.black26;
      final lockedBg = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: medal.isEquipped ? AppColors.metallicGold : AppColors.getBorder(isDark),
            width: medal.isEquipped ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: medal.isEarned ? AppColors.metallicGold.withValues(alpha: 0.15) : lockedBg,
                shape: BoxShape.circle,
              ),
              child: medal.iconUrl.startsWith('assets/')
                  ? Image.asset(
                      medal.iconUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(_getIcon(medal.iconUrl), color: medal.isEarned ? AppColors.metallicGold : lockedColor, size: 26),
                    )
                  : Icon(
                      _getIcon(medal.iconUrl),
                      color: medal.isEarned ? AppColors.metallicGold : lockedColor,
                      size: 26,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          medal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: medal.isEarned ? AppColors.getTextPrimary(isDark) : lockedColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (medal.isEquipped) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.metallicGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SHOWING',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: medal.isEarned ? AppColors.getTextSecondary(isDark) : lockedColor.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            medal.isEarned
                ? TextButton(
                    onPressed: () => _toggleEquip(originalIndex),
                    style: TextButton.styleFrom(
                      foregroundColor: medal.isEquipped ? Colors.grey : AppColors.metallicGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: medal.isEquipped ? Colors.grey : AppColors.metallicGold,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(medal.isEquipped ? 'Unequip' : 'Equip'),
                  )
                : Icon(Icons.lock_outline_rounded, color: lockedColor),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medal Stats Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.premiumGradient : null,
              color: isDark ? null : AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: AppColors.metallicGold.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Honor Showcase',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Earn medals by achieving goals and showcase them on your profile.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Medals Earned: $earnedCount / ${_medals.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          value: _medals.isEmpty ? 0 : (earnedCount / _medals.length),
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white24 : AppColors.getBorder(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SECTION 1: Unlocked Medals (Active Wall)
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.metallicGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'My Medals Wall (${earnedMedals.length})',
                style: TextStyle(
                  color: AppColors.getTextPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (earnedMedals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'No medals unlocked yet. Complete tasks to earn your first medal!',
                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                ),
              ),
            )
          else
            ...earnedMedals.map((m) {
              final origIdx = _medals.indexOf(m);
              return buildMedalItem(m, origIdx);
            }),

          const SizedBox(height: 16),

          // SECTION 2: Locked Medals
          Row(
            children: [
              Icon(Icons.lock_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 18),
              const SizedBox(width: 8),
              Text(
                'Locked Medals (${lockedMedals.length})',
                style: TextStyle(
                  color: AppColors.getTextSecondary(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (lockedMedals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '🎉 Congratulations! You have unlocked all available medals!',
                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                ),
              ),
            )
          else
            ...lockedMedals.map((m) {
              final origIdx = _medals.indexOf(m);
              return buildMedalItem(m, origIdx);
            }),
        ],
      ),
    );
  }
}
