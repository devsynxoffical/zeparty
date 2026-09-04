import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/premium_card.dart';

class BDAgentListScreen extends StatefulWidget {
  const BDAgentListScreen({super.key});

  @override
  State<BDAgentListScreen> createState() => _BDAgentListScreenState();
}

class _BDAgentListScreenState extends State<BDAgentListScreen> {
  final _searchController = TextEditingController();
  String _filterAgency = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final bd = context.watch<BDCenterProvider>();

    final query = _searchController.text.trim().toLowerCase();
    final filtered = bd.agents.where((a) {
      final matchesQuery = query.isEmpty ||
          a.nickname.toLowerCase().contains(query) ||
          a.userId.contains(query) ||
          a.agencyName.toLowerCase().contains(query);
      final matchesAgency = _filterAgency == 'All' || a.agencyId == _filterAgency;
      return matchesQuery && matchesAgency;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'BD Connected Agents (${bd.agents.length})',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            CustomTextField(
              controller: _searchController,
              hintText: 'Search by User ID, Name or Agency',
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Agency Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('All', 'All', isDark, primary),
                  ...bd.agencies.map((ag) => _buildFilterChip(ag.name, ag.id, isDark, primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List of Agents
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching agents found.',
                        style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final agent = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(16),
                            radius: 16,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: NetworkImage(agent.avatarUrl),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  agent.nickname,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: AppColors.getTextPrimary(isDark),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'ACTIVE',
                                                  style: TextStyle(
                                                    color: Colors.greenAccent,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: ${agent.userId} • ${agent.agencyName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.getTextSecondary(isDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${agent.activeHostsCount} Hosts',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: primary,
                                          ),
                                        ),
                                        Text(
                                          'Assigned: ${agent.assignmentDate.month}/${agent.assignmentDate.year}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.getTextSecondary(isDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Month',
                                            style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark)),
                                          ),
                                          Text(
                                            '${AppFormatters.formatNumber(agent.currentMonthDiamonds)} 💎',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.getTextPrimary(isDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Previous Month',
                                            style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark)),
                                          ),
                                          Text(
                                            '${AppFormatters.formatNumber(agent.previousMonthDiamonds)} 💎',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.getTextSecondary(isDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String title, String agencyId, bool isDark, Color primary) {
    final isSelected = _filterAgency == agencyId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : AppColors.getTextPrimary(isDark),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: primary,
        backgroundColor: AppColors.getCard(isDark),
        onSelected: (val) {
          setState(() {
            _filterAgency = agencyId;
          });
        },
      ),
    );
  }
}
