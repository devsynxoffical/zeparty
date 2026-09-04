import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String coverUrl;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.coverUrl,
  });
}

class MusicPickerSheet extends StatefulWidget {
  final Function(MusicTrack track) onTrackSelected;
  const MusicPickerSheet({super.key, required this.onTrackSelected});

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  String _searchQuery = '';
  String? _playingTrackId;

  final List<MusicTrack> _tracks = const [
    MusicTrack(
      id: 'm1',
      title: 'Party Stream Anthem',
      artist: 'DJ Gold Beats',
      duration: '0:30',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=200&q=80',
    ),
    MusicTrack(
      id: 'm2',
      title: 'Midnight Vibes',
      artist: 'Acoustic Soul',
      duration: '0:45',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=200&q=80',
    ),
    MusicTrack(
      id: 'm3',
      title: 'PK Battle Hype',
      artist: 'Electronic Pulse',
      duration: '0:60',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
    ),
    MusicTrack(
      id: 'm4',
      title: 'Summer Chillout',
      artist: 'Tropical Breeze',
      duration: '0:30',
      coverUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=200&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final filteredTracks = _tracks.where((t) {
      return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.artist.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.getBorder(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '🎵 Select Sound Track',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),

          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: InputDecoration(
              hintText: 'Search songs or artists...',
              hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.warmGold : AppColors.royalBlue),
              filled: true,
              fillColor: AppColors.getSurface(isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: filteredTracks.length,
              itemBuilder: (context, index) {
                final track = filteredTracks[index];
                final isPlaying = _playingTrackId == track.id;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      track.coverUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    track.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  subtitle: Text(
                    '${track.artist} • ${track.duration}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                            icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: isDark ? AppColors.warmGold : AppColors.royalBlue,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            _playingTrackId = isPlaying ? null : track.id;
                          });
                        },
                      ),
                      ElevatedButton(
                         style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.warmGold : AppColors.royalBlue,
                          foregroundColor: isDark ? AppColors.black : AppColors.white,
                        ),
                        onPressed: () {
                          widget.onTrackSelected(track);
                          Navigator.pop(context);
                        },
                        child: const Text('Use'),
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
