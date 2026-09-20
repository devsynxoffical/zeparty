import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String category;
  final IconData icon;
  final Color themeColor;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.category = 'Trending',
    this.icon = Icons.music_note_rounded,
    this.themeColor = AppColors.primary,
  });
}

class MusicPickerSheet extends StatefulWidget {
  final Function(MusicTrack track) onTrackSelected;
  const MusicPickerSheet({super.key, required this.onTrackSelected});

  static void show(BuildContext context, {required Function(MusicTrack track) onTrackSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => MusicPickerSheet(onTrackSelected: onTrackSelected),
    );
  }

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String? _playingTrackId;
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    '🔥 Trending',
    '🎉 Party EDM',
    '🎤 Pop Hits',
    '🎸 Acoustic',
    '🎮 Gaming',
    '🎧 Chill Vibes',
  ];

  final List<MusicTrack> _tracks = const [
    MusicTrack(
      id: 'm_original',
      title: 'Original Sound',
      artist: 'Video Audio Track',
      duration: 'Full',
      category: 'All',
      icon: Icons.mic_rounded,
      themeColor: Color(0xFF6366F1),
    ),
    MusicTrack(
      id: 'm1',
      title: 'ZeParty Anthem (Club Edit)',
      artist: 'DJ Gold Beats',
      duration: '0:30',
      category: '🎉 Party EDM',
      icon: Icons.nightlife_rounded,
      themeColor: Color(0xFFFFB300),
    ),
    MusicTrack(
      id: 'm2',
      title: 'Neon Nights & Starlight',
      artist: 'Cyber Pulse',
      duration: '0:45',
      category: '🔥 Trending',
      icon: Icons.bolt_rounded,
      themeColor: Color(0xFFE91E63),
    ),
    MusicTrack(
      id: 'm3',
      title: 'Midnight Acoustic Soul',
      artist: 'Maya Rivera',
      duration: '0:60',
      category: '🎸 Acoustic',
      icon: Icons.audiotrack_rounded,
      themeColor: Color(0xFF4CAF50),
    ),
    MusicTrack(
      id: 'm4',
      title: 'PK Battle Champions Hype',
      artist: 'Bass Arena',
      duration: '0:30',
      category: '🎮 Gaming',
      icon: Icons.sports_esports_rounded,
      themeColor: Color(0xFF9C27B0),
    ),
    MusicTrack(
      id: 'm5',
      title: 'Summer Sunset Horizon',
      artist: 'Tropical Island',
      duration: '0:45',
      category: '🎧 Chill Vibes',
      icon: Icons.wb_sunny_rounded,
      themeColor: Color(0xFFFF9800),
    ),
    MusicTrack(
      id: 'm6',
      title: 'Pop Superstar Energy',
      artist: 'Nova Sky',
      duration: '0:30',
      category: '🎤 Pop Hits',
      icon: Icons.star_rounded,
      themeColor: Color(0xFF00BCD4),
    ),
    MusicTrack(
      id: 'm7',
      title: 'Lo-Fi Rain & Coffee Beats',
      artist: 'Study Lounge',
      duration: '0:60',
      category: '🎧 Chill Vibes',
      icon: Icons.headphones_rounded,
      themeColor: Color(0xFF3F51B5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredTracks = _tracks.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.artist.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || t.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF130D26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E24AA), Color(0xFFFFB300)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Sound & Music Library',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.getTextPrimary(isDark),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.getTextSecondary(isDark)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search songs, trending sounds, or artists...',
              hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              filled: true,
              fillColor: AppColors.getSurface(isDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Category Filter Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.getBorder(isDark),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Tracks List
          Expanded(
            child: filteredTracks.isEmpty
                ? Center(
                    child: Text(
                      'No tracks found matching "$_searchQuery"',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredTracks.length,
                    separatorBuilder: (context, index) => Divider(
                      color: AppColors.getBorder(isDark).withValues(alpha: 0.5),
                      height: 12,
                    ),
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      final isPlaying = _playingTrackId == track.id;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // Cover / Icon Avatar
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: track.themeColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: track.themeColor.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Icon(
                                  track.icon,
                                  color: track.themeColor,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Title & Artist
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        track.artist,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.getTextSecondary(isDark),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.getSurface(isDark),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          track.duration,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.getTextSecondary(isDark),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Play / Preview Button
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                color: track.themeColor,
                                size: 30,
                              ),
                              onPressed: () {
                                setState(() {
                                  _playingTrackId = isPlaying ? null : track.id;
                                });
                              },
                            ),

                            // Use Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getPrimary(isDark),
                                foregroundColor: AppColors.onPrimary(isDark: isDark),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                widget.onTrackSelected(track);
                                Navigator.pop(context);
                              },
                              child: const Text('Use', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
