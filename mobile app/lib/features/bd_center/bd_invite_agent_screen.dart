import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bd_center_model.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';

class BDInviteAgentScreen extends StatefulWidget {
  const BDInviteAgentScreen({super.key});

  @override
  State<BDInviteAgentScreen> createState() => _BDInviteAgentScreenState();
}

class _BDInviteAgentScreenState extends State<BDInviteAgentScreen> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAgencyId;
  String? _selectedAgencyName;
  bool _hasSearched = false;
  Map<String, dynamic>? _foundUser;

  void _searchUser() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _hasSearched = true;
      // Simulated user lookup
      _foundUser = {
        'userId': query,
        'nickname': 'Creator $query',
        'avatarUrl': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
        'status': 'Eligible for BD Invitation',
        'isEligible': true,
      };
    });
  }

  void _sendInvite(BDCenterProvider bd) async {
    if (_foundUser == null || _selectedAgencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an agency to assign.')),
      );
      return;
    }

    final success = await bd.sendAgentInvitation(
      targetUserId: _foundUser!['userId'],
      targetNickname: _foundUser!['nickname'],
      agencyId: _selectedAgencyId!,
      agencyName: _selectedAgencyName!,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Agency Invitation dispatched successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _foundUser = null;
          _hasSearched = false;
          _searchController.clear();
          _noteController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A pending invitation already exists for this user ID.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final bd = context.watch<BDCenterProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'Invite Agent',
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
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _searchController,
                    hintText: 'Enter User ID to invite',
                    prefixIcon: const Icon(Icons.search_rounded),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                GoldButton(
                  text: 'Search',
                  width: 90,
                  height: 48,
                  onPressed: _searchUser,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Search Result Card
            if (_hasSearched && _foundUser != null) ...[
              Text(
                'Candidate Found',
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
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(_foundUser!['avatarUrl']),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundUser!['nickname'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                              Text(
                                'User ID: ${_foundUser!['userId']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _foundUser!['status'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Agency Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Assign to Agency',
                        labelStyle: TextStyle(color: primary, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                        ),
                      ),
                      dropdownColor: AppColors.getCard(isDark),
                      items: bd.agencies.map((agency) {
                        return DropdownMenuItem(
                          value: agency.id,
                          child: Text(
                            agency.name,
                            style: TextStyle(
                              color: AppColors.getTextPrimary(isDark),
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAgencyId = val;
                          _selectedAgencyName = bd.agencies.firstWhere((a) => a.id == val).name;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _noteController,
                      hintText: 'Add an invitation note (optional)',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    GoldButton(
                      text: 'Dispatch Official Invitation',
                      onPressed: () => _sendInvite(bd),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Invitation History Section
            Text(
              'Recent BD Invitations (${bd.invitations.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            if (bd.invitations.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No invitations sent yet.',
                    style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bd.invitations.length,
                itemBuilder: (context, index) {
                  final item = bd.invitations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(14),
                      radius: 14,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(item.targetAvatar),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.targetNickname,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                                Text(
                                  'ID: ${item.targetUserId} • ${item.agencyName}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                ),
                                if (item.note != null)
                                  Text(
                                    'Note: ${item.note}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildStatusBadge(item.status),
                              if (item.status == BDInvitationStatus.pending) ...[
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => bd.cancelInvitation(item.id),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BDInvitationStatus status) {
    Color color;
    String label;
    switch (status) {
      case BDInvitationStatus.pending:
        color = Colors.orangeAccent;
        label = 'Pending';
        break;
      case BDInvitationStatus.accepted:
        color = Colors.greenAccent;
        label = 'Accepted';
        break;
      case BDInvitationStatus.rejected:
        color = Colors.redAccent;
        label = 'Rejected';
        break;
      case BDInvitationStatus.expired:
        color = Colors.grey;
        label = 'Expired';
        break;
      case BDInvitationStatus.cancelled:
        color = Colors.deepOrange;
        label = 'Cancelled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
