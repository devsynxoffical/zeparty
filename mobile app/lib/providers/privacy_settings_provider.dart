import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/privacy_eligibility_model.dart';
import '../core/repositories/social_repository.dart';
import '../core/services/api_client.dart';

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
  bool _antiFollow = false;
  bool _failedToFind = false;
  bool _genderPrivacy = false;
  bool _invisibleVisit = false;
  bool _rankInvisible = false;
  bool _svipHidden = false;
  bool _mystery = false;

  PrivacyEligibilityModel? _eligibility;
  bool _isLoadingEligibility = false;
  String? _eligibilityError;

  bool get stealthRoomEntry => _stealthRoomEntry;
  bool get anonymousGifting => _anonymousGifting;
  bool get hideOnlinePresence => _hideOnlinePresence;
  bool get hideLevelBadges => _hideLevelBadges;
  bool get blockStrangersDm => _blockStrangersDm;
  bool get hideCpRelationship => _hideCpRelationship;
  bool get hideFollowList => _hideFollowList;
  bool get antiFollow => _antiFollow;
  bool get failedToFind => _failedToFind;
  bool get genderPrivacy => _genderPrivacy;
  bool get invisibleVisit => _invisibleVisit;
  bool get rankInvisible => _rankInvisible;
  bool get svipHidden => _svipHidden;
  bool get mystery => _mystery;

  PrivacyEligibilityModel? get eligibility => _eligibility;
  bool get isLoadingEligibility => _isLoadingEligibility;
  String? get eligibilityError => _eligibilityError;

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
      key: 'invisible_visit',
      title: 'Invisible Profile Visit',
      description: 'Browse profile visitors without recording footprint or notification',
      icon: Icons.remove_red_eye_outlined,
      requiredSvipLevel: 9,
      requiredNobleTier: 'Configurable',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'rank_invisible',
      title: 'Rank Invisible',
      description: 'Conceal ranking on daily, weekly, and monthly contributor leaderboards',
      icon: Icons.leaderboard_outlined,
      requiredSvipLevel: 11,
      requiredNobleTier: 'Configurable',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'svip_hidden',
      title: 'SVIP Identity Hidden',
      description: 'Conceal SVIP level badge, card accents, and elite entrance',
      icon: Icons.shield_outlined,
      requiredSvipLevel: 13,
      requiredNobleTier: 'Configurable',
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'mystery',
      title: 'Mystery Mode',
      description: 'Anonymize profile identity and room activity into mystery persona',
      icon: Icons.auto_awesome_rounded,
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'gender_privacy',
      title: 'Gender Privacy',
      description: 'Hide gender indicator on profile card and room seats',
      icon: Icons.transgender_rounded,
      isGated: false,
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
    PrivacySettingItem(
      key: 'anti_follow',
      title: 'Anti-Follow Shield',
      description: 'Prevent targeted accounts from following or tracking your activities',
      icon: Icons.security_rounded,
      isGated: true,
    ),
    PrivacySettingItem(
      key: 'failed_to_find',
      title: 'Failed to Find Stealth',
      description: 'Hide your profile from public search results and ID search suggestions',
      icon: Icons.search_off_rounded,
      isGated: true,
    ),
  ];

  void initFromUser(UserModel user) {
    _hideFollowList = user.isPrivate;
    notifyListeners();
  }

  void setEligibility(PrivacyEligibilityModel eligibility) {
    _eligibility = eligibility;
    _antiFollow = eligibility.antiFollow.isEnabled;
    _failedToFind = eligibility.failedToFind.isEnabled;
    notifyListeners();
  }

  bool getSettingValue(String key) {
    switch (key.toLowerCase()) {
      case 'hide_follow_list':
        return _hideFollowList;
      case 'stealth_entry':
      case 'room_invisible':
        return _stealthRoomEntry;
      case 'anonymous_gifting':
      case 'hide_gift_record':
        return _anonymousGifting;
      case 'hide_online':
        return _hideOnlinePresence;
      case 'hide_levels':
      case 'hide_wealth':
        return _hideLevelBadges;
      case 'invisible_visit':
        return _invisibleVisit;
      case 'rank_invisible':
        return _rankInvisible;
      case 'svip_hidden':
        return _svipHidden;
      case 'mystery':
        return _mystery;
      case 'gender_privacy':
        return _genderPrivacy;
      case 'block_strangers_dm':
        return _blockStrangersDm;
      case 'hide_cp_relationship':
        return _hideCpRelationship;
      case 'anti_follow':
        return _antiFollow;
      case 'failed_to_find':
        return _failedToFind;
      default:
        return false;
    }
  }

  void _setSettingValue(String key, bool val) {
    switch (key.toLowerCase()) {
      case 'hide_follow_list':
        _hideFollowList = val;
        break;
      case 'stealth_entry':
      case 'room_invisible':
        _stealthRoomEntry = val;
        break;
      case 'anonymous_gifting':
      case 'hide_gift_record':
        _anonymousGifting = val;
        break;
      case 'hide_online':
        _hideOnlinePresence = val;
        break;
      case 'hide_levels':
      case 'hide_wealth':
        _hideLevelBadges = val;
        break;
      case 'invisible_visit':
        _invisibleVisit = val;
        break;
      case 'rank_invisible':
        _rankInvisible = val;
        break;
      case 'svip_hidden':
        _svipHidden = val;
        break;
      case 'mystery':
        _mystery = val;
        break;
      case 'gender_privacy':
        _genderPrivacy = val;
        break;
      case 'block_strangers_dm':
        _blockStrangersDm = val;
        break;
      case 'hide_cp_relationship':
        _hideCpRelationship = val;
        break;
      case 'anti_follow':
        _antiFollow = val;
        break;
      case 'failed_to_find':
        _failedToFind = val;
        break;
    }
  }

  String _toCanonicalBackendKey(String key) {
    switch (key.toLowerCase()) {
      case 'stealth_entry':
        return 'ROOM_INVISIBLE';
      case 'anonymous_gifting':
        return 'HIDE_GIFT_RECORD';
      case 'hide_levels':
        return 'HIDE_WEALTH';
      case 'hide_follow_list':
        return 'HIDE_FOLLOW_LIST';
      case 'hide_online':
        return 'HIDE_ONLINE';
      case 'invisible_visit':
        return 'INVISIBLE_VISIT';
      case 'rank_invisible':
        return 'RANK_INVISIBLE';
      case 'svip_hidden':
        return 'SVIP_HIDDEN';
      case 'mystery':
        return 'MYSTERY';
      case 'gender_privacy':
        return 'GENDER_PRIVACY';
      case 'block_strangers_dm':
        return 'BLOCK_STRANGERS_DM';
      case 'anti_follow':
        return 'ANTI_FOLLOW';
      case 'failed_to_find':
        return 'FAILED_TO_FIND';
      default:
        return key.toUpperCase();
    }
  }

  Future<void> fetchEligibility() async {
    _isLoadingEligibility = true;
    _eligibilityError = null;
    notifyListeners();

    try {
      Response response;
      try {
        response = await ApiClient.instance.get('/v1/users/me/privacy-settings');
      } catch (_) {
        response = await ApiClient.instance.get('/v1/users/privacy/eligibility');
      }

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        _eligibility = PrivacyEligibilityModel.fromJson(raw);
        _hideFollowList = raw['hideFollowList'] ?? raw['isPrivate'] ?? _hideFollowList;
        _stealthRoomEntry = raw['stealthEntry'] ?? raw['roomInvisible'] ?? _stealthRoomEntry;
        _anonymousGifting = raw['anonymousGifting'] ?? raw['hideGiftRecord'] ?? _anonymousGifting;
        _hideOnlinePresence = raw['hideOnline'] ?? _hideOnlinePresence;
        _hideLevelBadges = raw['hideWealth'] ?? _hideLevelBadges;
        _blockStrangersDm = raw['blockStrangersDm'] ?? _blockStrangersDm;
        _genderPrivacy = raw['genderPrivacy'] ?? _genderPrivacy;
        _invisibleVisit = raw['invisibleVisit'] ?? _invisibleVisit;
        _rankInvisible = raw['rankInvisible'] ?? _rankInvisible;
        _svipHidden = raw['svipHidden'] ?? _svipHidden;
        _mystery = raw['mystery'] ?? _mystery;
        _antiFollow = _eligibility!.antiFollow.isEnabled;
        _failedToFind = _eligibility!.failedToFind.isEnabled;
      }
    } catch (e) {
      _eligibilityError = e.toString();
    } finally {
      _isLoadingEligibility = false;
      notifyListeners();
    }
  }

  bool canEnable(String key, int userSvipLevel) {
    final canonical = _toCanonicalBackendKey(key);
    final feat = _eligibility?.getFeature(canonical);
    if (feat != null) {
      return feat.eligible;
    }
    if (key == 'anti_follow') {
      return _eligibility?.antiFollow.eligible ?? false;
    }
    if (key == 'failed_to_find') {
      return _eligibility?.failedToFind.eligible ?? false;
    }
    final item = privacyCatalog.firstWhere((i) => i.key == key, orElse: () => privacyCatalog.first);
    if (!item.isGated) return true;
    return userSvipLevel >= item.requiredSvipLevel;
  }

  String getIneligibilityReason(String key) {
    final canonical = _toCanonicalBackendKey(key);
    final feat = _eligibility?.getFeature(canonical);
    if (feat != null && feat.reason.isNotEmpty) {
      return feat.reason;
    }
    if (key == 'anti_follow') {
      return _eligibility?.antiFollow.reason ?? 'Requires higher SVIP or Noble status.';
    }
    if (key == 'failed_to_find') {
      return _eligibility?.failedToFind.reason ?? 'Requires higher SVIP or Noble status.';
    }
    final item = privacyCatalog.firstWhere((i) => i.key == key, orElse: () => privacyCatalog.first);
    return 'Enabling "${item.title}" requires SVIP Tier ${item.requiredSvipLevel} or ${item.requiredNobleTier} Noble Status.';
  }

  Future<void> updateFollowListPrivacy(bool hide, {VoidCallback? onSynced}) async {
    _hideFollowList = hide;
    notifyListeners();

    try {
      await SocialRepository.instance.updatePrivacySettings(isPrivate: hide);
      await ApiClient.instance.put('/v1/users/me/privacy-settings', data: {
        'key': 'HIDE_FOLLOW_LIST',
        'isEnabled': hide,
      });
      onSynced?.call();
    } catch (_) {
      // Keep optimistic state or handle gracefully
    }
  }

  Future<bool> updateSetting(String key, bool enable) async {
    final prev = getSettingValue(key);
    _setSettingValue(key, enable);
    notifyListeners();

    final canonicalKey = _toCanonicalBackendKey(key);
    try {
      await ApiClient.instance.put('/v1/users/me/privacy-settings', data: {
        'key': canonicalKey,
        'isEnabled': enable,
      });
      return true;
    } on DioException catch (dioErr) {
      _setSettingValue(key, prev);
      final respData = dioErr.response?.data;
      final serverMsg = respData is Map ? (respData['message'] ?? respData['error']) : null;
      _eligibilityError = serverMsg?.toString() ?? 'Update failed ($canonicalKey)';
      notifyListeners();
      return false;
    } catch (e) {
      _setSettingValue(key, prev);
      _eligibilityError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleAntiFollow(bool enable) async {
    return updateSetting('anti_follow', enable);
  }

  Future<bool> toggleFailedToFind(bool enable) async {
    return updateSetting('failed_to_find', enable);
  }

  void toggleSetting(String key, int userSvipLevel) {
    if (!canEnable(key, userSvipLevel)) return;
    final current = getSettingValue(key);
    updateSetting(key, !current);
  }
}
