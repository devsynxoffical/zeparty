import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/repositories/social_repository.dart';

class PrivacySettingItem {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final int requiredSvipLevel;
  final String requiredNobleTier;
  final bool isGated;

  const PrivacySettingItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.requiredSvipLevel = 0,
    this.requiredNobleTier = 'None',
    this.isGated = false,
  });
}

class PrivacySettingsProvider extends ChangeNotifier {
  // Configurable privacy toggles state
  bool _stealthRoomEntry = false;
  bool _anonymousGifting = false;
  bool _hideOnlinePresence = false;
  bool _hideLevelBadges = false;
  bool _blockStrangersDm = false;
  bool _hideCpRelationship = false;
  bool _hideFollowList = false;

  bool get stealthRoomEntry => _stealthRoomEntry;
  bool get anonymousGifting => _anonymousGifting;
  bool get hideOnlinePresence => _hideOnlinePresence;
  bool get hideLevelBadges => _hideLevelBadges;
  bool get blockStrangersDm => _blockStrangersDm;
  bool get hideCpRelationship => _hideCpRelationship;
  bool get hideFollowList => _hideFollowList;

  static const List<PrivacySettingItem> privacyCatalog = [
    PrivacySettingItem(
      key: 'hide_follow_list',
      title: 'Private Followers & Following',
      description: 'Hide your followers and following lists from other users. Total counts remain visible.',
      icon: Icons.people_outline_rounded,
      isGated: false,
    ),
    PrivacySettingItem(
      key: 'stealth_entry',
      title: 'Stealth Room Entry',
      description: 'Hide entry banner and room arrival broadcast sound',
      icon: Icons.masks_rounded,
      requiredSvipLevel: 6,
      requiredNobleTier: 'Count',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'anonymous_gifting',
      title: 'Anonymous Gifting',
      description: 'Hide sender username and identity on gift feeds',
      icon: Icons.visibility_off_rounded,
      requiredSvipLevel: 3,
      requiredNobleTier: 'Baron',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'hide_online',
      title: 'Hide Online Status',
      description: 'Hide real-time online presence and last active time',
      icon: Icons.person_off_rounded,
      requiredSvipLevel: 5,
      requiredNobleTier: 'Viscount',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'hide_levels',
      title: 'Hide Wealth & Charm Levels',
      description: 'Hide public level badges on profile card and seat grid',
      icon: Icons.star_border_rounded,
      requiredSvipLevel: 2,
      requiredNobleTier: 'Knight',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'block_strangers_dm',
      title: 'Block DMs from Non-Followers',
      description: 'Only accept direct messages from users you follow',
      icon: Icons.mark_chat_read_rounded,
      isGated: false,
    ),
    PrivacySettingItem(
      key: 'hide_cp_relationship',
      title: 'Hide CP Relationship',
      description: 'Hide CP partner ring card from public profile and gift wall',
      icon: Icons.favorite_border_rounded,
      isGated: false,
    ),
  ];

  void initFromUser(UserModel user) {
    _hideFollowList = user.isPrivate;
    notifyListeners();
  }

  bool canEnable(String key, int userSvipLevel) {
    final item = privacyCatalog.firstWhere((i) => i.key == key, orElse: () => privacyCatalog.first);
    if (!item.isGated) return true;
    return userSvipLevel >= item.requiredSvipLevel;
  }

  Future<void> updateFollowListPrivacy(bool hide, {VoidCallback? onSynced}) async {
    _hideFollowList = hide;
    notifyListeners();

    try {
      await SocialRepository.instance.updatePrivacySettings(isPrivate: hide);
      onSynced?.call();
    } catch (_) {
      // Keep optimistic state or handle gracefully
    }
  }

  void toggleSetting(String key, int userSvipLevel) {
    if (!canEnable(key, userSvipLevel)) return;

    switch (key) {
      case 'hide_follow_list':
        updateFollowListPrivacy(!_hideFollowList);
        break;
      case 'stealth_entry':
        _stealthRoomEntry = !_stealthRoomEntry;
        break;
      case 'anonymous_gifting':
        _anonymousGifting = !_anonymousGifting;
        break;
      case 'hide_online':
        _hideOnlinePresence = !_hideOnlinePresence;
        break;
      case 'hide_levels':
        _hideLevelBadges = !_hideLevelBadges;
        break;
      case 'block_strangers_dm':
        _blockStrangersDm = !_blockStrangersDm;
        break;
      case 'hide_cp_relationship':
        _hideCpRelationship = !_hideCpRelationship;
        break;
    }
    notifyListeners();
  }
}
