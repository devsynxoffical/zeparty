import '../services/api_client.dart';
import '../../models/user_asset_model.dart';

class BackpackRepository {
  static final BackpackRepository instance = BackpackRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  BackpackRepository._internal();

  /// Fetch the authenticated user's backpack/inventory of assets
  Future<List<UserAssetModel>> fetchBackpack() async {
    final response = await _apiClient.get('/v1/users/me/assets');
    final data = response.data?['data'] as List? ?? [];
    return data
        .map((item) => UserAssetModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Equip an owned asset by ID
  Future<UserAssetModel> equipAsset(String userAssetId) async {
    final response = await _apiClient.post('/v1/users/me/assets/$userAssetId/equip');
    final data = response.data?['data'] as Map<String, dynamic>;
    return UserAssetModel.fromJson(data);
  }

  /// Unequip an owned asset by ID
  Future<UserAssetModel> unequipAsset(String userAssetId) async {
    final response = await _apiClient.post('/v1/users/me/assets/$userAssetId/unequip');
    final data = response.data?['data'] as Map<String, dynamic>;
    return UserAssetModel.fromJson(data);
  }
}
