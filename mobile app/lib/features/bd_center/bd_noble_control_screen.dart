import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/bd_center_provider.dart';
import '../../providers/noble_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';

class BDNobleControlScreen extends StatefulWidget {
  const BDNobleControlScreen({super.key});

  @override
  State<BDNobleControlScreen> createState() => _BDNobleControlScreenState();
}

class _BDNobleControlScreenState extends State<BDNobleControlScreen> {
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  String _selectedRankId = 'duke';
  bool _hasSearched = false;
  Map<String, dynamic>? _targetUser;

  void _searchUser() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _hasSearched = true;
      _targetUser = {
        'userId': query,
        'nickname': 'Noble Lord $query',
        'avatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
        'currentRank': 'Duke',
        'rankId': 'duke',
        'sentCoins': 1420000,
        'status': 'Active (Automatic Sent-Coins)',
        'expiry': '2026-10-15',
      };
    });
  }

  void _executeManualGrant(BDCenterProvider bd, NobleProvider noble) {
    if (_targetUser == null) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a mandatory audit reason for manual Noble grant.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
        title: const Text('Confirm Manual Aristocracy Grant'),
        content: Text(
          'Are you sure you want to manually set rank ${_selectedRankId.toUpperCase()} for User ID ${_targetUser!['userId']}?\n\nReason: $reason',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              noble.manualGrantNoble(
                rankId: _selectedRankId,
                reason: reason,
                operatorId: bd.bdUserId,
              );
              bd.operatorGrantNoble(
                targetUserId: _targetUser!['userId'],
                rankId: _selectedRankId,
                reason: reason,
                operatorId: bd.bdUserId,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${_selectedRankId.toUpperCase()} successfully granted to ${_targetUser!['userId']}'),
                  backgroundColor: AppColors.success,
                ),
              );

              setState(() {
                _targetUser!['currentRank'] = _selectedRankId.toUpperCase();
                _targetUser!['rankId'] = _selectedRankId;
                _targetUser!['status'] = 'Active (Manual BD Grant)';
                _reasonController.clear();
              });
            },
            child: const Text('Confirm & Log Audit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _executeRevoke(BDCenterProvider bd, NobleProvider noble) {
    if (_targetUser == null) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a mandatory audit reason for revoking Noble rank.')),
      );
      return;
    }

    noble.manualRevokeNoble(reason: reason, operatorId: bd.bdUserId);
    bd.operatorGrantNoble(
      targetUserId: _targetUser!['userId'],
      rankId: 'NONE',
      reason: 'REVOCATION: $reason',
      operatorId: bd.bdUserId,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Noble Rank Revoked successfully'), backgroundColor: Colors.redAccent),
    );

    setState(() {
      _targetUser!['currentRank'] = 'None';
      _targetUser!['status'] = 'Revoked / Inactive';
      _reasonController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final bd = context.watch<BDCenterProvider>();
    final noble = context.watch<NobleProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'BD Noble / Aristocracy Control',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _searchController,
                    hintText: 'Enter User ID or Nickname',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                GoldButton(
                  text: 'Lookup',
                  width: 90,
                  height: 48,
                  onPressed: _searchUser,
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_hasSearched && _targetUser != null) ...[
              Text(
                'Target Account Aristocracy Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 10),

              // User Info Card
              PremiumCard(
                padding: const EdgeInsets.all(16),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(_targetUser!['avatarUrl']),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _targetUser!['nickname'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                              Text(
                                'User ID: ${_targetUser!['userId']} • ${_targetUser!['status']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _targetUser!['currentRank'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: AppColors.getBorder(isDark), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Eligible Sent Coins', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                        Text('${AppFormatters.formatNumber(_targetUser!['sentCoins'])} coins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Expiry', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                        Text(_targetUser!['expiry'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Manual Operation Controls
              Text(
                'Manual BD Aristocracy Actions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 10),

              PremiumCard(
                padding: const EdgeInsets.all(16),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRankId,
                      decoration: InputDecoration(
                        labelText: 'Select Noble Rank',
                        labelStyle: TextStyle(color: primary, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                        ),
                      ),
                      dropdownColor: AppColors.getCard(isDark),
                      items: noble.ranks.map((r) {
                        return DropdownMenuItem(
                          value: r.id,
                          child: Text(
                            r.name,
                            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRankId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _reasonController,
                      hintText: 'Mandatory Operator Reason / Note for Audit Log',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GoldButton(
                            text: 'Grant / Upgrade Rank',
                            onPressed: () => _executeManualGrant(bd, noble),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                            foregroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.redAccent, width: 0.8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onPressed: () => _executeRevoke(bd, noble),
                          child: const Text('Revoke', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
