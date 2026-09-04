import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  int _equippedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    final titles = [
      {'name': 'Top Donator', 'unlocked': true, 'color': Colors.amber},
      {'name': 'Party King', 'unlocked': true, 'color': Colors.purpleAccent},
      {'name': 'Star Streamer', 'unlocked': false, 'color': Colors.blueAccent},
      {'name': 'Aristocrat', 'unlocked': false, 'color': Colors.redAccent},
    ];

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('My Titles', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: titles.length,
        itemBuilder: (context, index) {
          final title = titles[index];
          final unlocked = title['unlocked'] as bool;
          final color = title['color'] as Color;
          final isEquipped = _equippedIndex == index;

          return Card(
            color: AppColors.getCard(isDark),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: unlocked ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: unlocked ? color : Colors.grey),
                ),
                child: Text(
                  title['name'] as String,
                  style: TextStyle(color: unlocked ? color : Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              trailing: unlocked
                  ? ElevatedButton(
                      onPressed: () {
                        setState(() => _equippedIndex = index);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Equipped [${title['name']}] Title')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEquipped ? Colors.grey : primary, 
                        foregroundColor: isEquipped ? Colors.white : AppColors.onPrimary(isDark: isDark)
                      ),
                      child: Text(isEquipped ? 'Equipped' : 'Equip'),
                    )
                  : const Icon(Icons.lock, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
