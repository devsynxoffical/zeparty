import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/audio_host_model.dart';
import '../../providers/agency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

class AgencyCenterScreen extends StatefulWidget {
  const AgencyCenterScreen({super.key});

  @override
  State<AgencyCenterScreen> createState() => _AgencyCenterScreenState();
}

class _AgencyCenterScreenState extends State<AgencyCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addHostIdController = TextEditingController();
  final TextEditingController _removeReasonController = TextEditingController();

  String _selectedCycleFilter = 'Current Cycle';
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _addHostIdController.dispose();
    _removeReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final agencyProv = context.watch<AgencyProvider>();
    final agency = agencyProv.userAgency;
    final authUser = context.watch<AuthProvider>().currentUser;

    if (agency == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agency Center')),
        body: const Center(child: Text('No active agency access found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agency.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(isDark)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Agency ID: ${agency.id} • Owner: ${agency.ownerName}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded, color: Colors.amberAccent),
            tooltip: 'Admin Audit Log',
            onPressed: () => _showAuditLogDialog(context, agencyProv, isDark),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Team Members'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Data'),
            Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Agency Wallet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, agencyProv, isDark, primary),
          _buildTeamMembersTab(context, agencyProv, authUser.id, isDark, primary),
          _buildDataTab(context, agencyProv, isDark, primary),
          _buildAgencyWalletTab(context, agencyProv, authUser.id, isDark, primary),
        ],
      ),
    );
  }

  // ─── 1. OVERVIEW AREA (Diagram 2 & Section 1-2) ───
  Widget _buildOverviewTab(BuildContext context, AgencyProvider prov, bool isDark, Color primary) {
    final agency = prov.userAgency!;
    final hosts = prov.audioHosts;
    final activeHostsCount = hosts.where((h) => h.status == 'Active').length;
    final totalTarget = hosts.fold<int>(0, (sum, h) => sum + (h.currentLevel * 100000));
    final totalAchieved = hosts.fold<int>(0, (sum, h) => sum + h.achievedDiamonds);
    final targetProgress = totalTarget > 0 ? (totalAchieved / totalTarget).clamp(0.0, 1.0) : 0.0;
    final totalHours = hosts.fold<int>(0, (sum, h) => sum + (h.dailyOnlineMinutes ~/ 60));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agency Overview Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, Colors.purple.shade900]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        agency.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                      child: Text('ID: ${agency.id}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildSummaryItem('Active Hosts', '$activeHostsCount / ${hosts.length}', Colors.white)),
                    Expanded(child: _buildSummaryItem('Agency Commission', '\$${agency.availableBalanceUsd.toStringAsFixed(2)}', Colors.amberAccent)),
                    Expanded(child: _buildSummaryItem('Target Progress', '${(targetProgress * 100).toStringAsFixed(1)}%', Colors.cyanAccent)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: targetProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text('Agency Metrics Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _buildMetricTile(isDark, 'Total Agency Target', '$totalTarget pts', Icons.track_changes_rounded, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile(isDark, 'Achieved Target', '$totalAchieved pts', Icons.verified_rounded, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricTile(isDark, 'Pending Invitations', '${prov.invitations.where((i) => i.status == 'Pending').length}', Icons.hourglass_top_rounded, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile(isDark, 'Verified Live Hours', '$totalHours hrs', Icons.access_time_filled_rounded, Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. TEAM MEMBERS AREA (Diagram 2 & Section 3 & 6) ───
  Widget _buildTeamMembersTab(BuildContext context, AgencyProvider prov, String currentUserId, bool isDark, Color primary) {
    final searchQuery = _searchController.text.toLowerCase();
    final allHosts = prov.audioHosts;

    // Filters
    final hosts = allHosts.where((h) {
      if (_selectedStatusFilter != 'All' && h.status != _selectedStatusFilter) return false;
      if (searchQuery.isNotEmpty) {
        return h.userName.toLowerCase().contains(searchQuery) || h.userId.toLowerCase().contains(searchQuery);
      }
      return true;
    }).toList();

    final pendingCount = prov.invitations.where((i) => i.status == 'Pending').length;
    final activeCount = allHosts.where((h) => h.status == 'Active').length;

    return Column(
      children: [
        // Top Summary Cards (Section 3)
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.getCard(isDark),
          child: Row(
            children: [
              _buildCompactBadge('Total Hosts', '${allHosts.length}', Colors.blue, isDark),
              const SizedBox(width: 8),
              _buildCompactBadge('Active Hosts', '$activeCount', Colors.green, isDark),
              const SizedBox(width: 8),
              _buildCompactBadge('Pending Invites', '$pendingCount', Colors.orange, isDark),
            ],
          ),
        ),

        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search host or ID...',
                    hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, overflow: TextOverflow.ellipsis),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Status Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: AppColors.getCard(isDark), borderRadius: BorderRadius.circular(14)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatusFilter,
                    dropdownColor: AppColors.getCard(isDark),
                    style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 11, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Status')),
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'Removed', child: Text('Removed')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedStatusFilter = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showAddHostDialog(context, prov, currentUserId, isDark),
                icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Team List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hosts.length,
            itemBuilder: (context, index) {
              final host = hosts[index];
              final targetVal = host.currentLevel * 100000;
              final hours = host.dailyOnlineMinutes ~/ 60;
              final joinStr = host.joinDate.toString().split(' ').first;

              return InkWell(
                onTap: () => _showHostDetailDialog(context, host, isDark, primary),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(imageUrl: host.avatarUrl, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    host.userName,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark), fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: host.status == 'Active' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(host.status, style: TextStyle(color: host.status == 'Active' ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('ID: ${host.userId} • Joined: $joinStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('Target: ${host.achievedDiamonds}/$targetVal pts • Valid: ${hours}h / ${host.completedValidDays}d', style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        onSelected: (val) {
                          if (val == 'detail') {
                            _showHostDetailDialog(context, host, isDark, primary);
                          } else if (val == 'remove') {
                            _confirmRemoveHost(context, prov, host, currentUserId, isDark);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'detail', child: Text('View Details')),
                          if (host.status != 'Removed')
                            const PopupMenuItem(value: 'remove', child: Text('Remove Host', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 3. DATA DASHBOARD AREA (Diagram 2 & Section 4 - FULLY RESPONSIVE) ───
  Widget _buildDataTab(BuildContext context, AgencyProvider prov, bool isDark, Color primary) {
    final hosts = prov.audioHosts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date / Cycle Filter Header (Responsive Row)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Performance Data Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(isDark)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.getCard(isDark), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCycleFilter,
                    dropdownColor: AppColors.getCard(isDark),
                    style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 12, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 'Current Cycle', child: Text('Current Cycle')),
                      DropdownMenuItem(value: 'Last Cycle', child: Text('Last Cycle')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCycleFilter = v);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Per-Host Performance Data Table Card (Aligned & Overflow-Free)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: Text('Host Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text('Achieved Target', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text('Hours/Days', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text('Cycle Status', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const Divider(height: 16),
                ...hosts.map((h) {
                  final targetVal = h.currentLevel * 100000;
                  final hours = h.dailyOnlineMinutes ~/ 60;
                  final isCompleted = h.achievedDiamonds >= targetVal;

                  return InkWell(
                    onTap: () => _showHostDetailDialog(context, h, isDark, primary),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              h.userName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.getTextPrimary(isDark)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${h.achievedDiamonds}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${hours}h / ${h.completedValidDays}d',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              isCompleted ? 'Completed' : 'Active',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.green : Colors.orange,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. AGENCY WALLET AREA (Diagram 2 & Section 5 - STRICT SALARY SEPARATION) ───
  Widget _buildAgencyWalletTab(BuildContext context, AgencyProvider prov, String currentUserId, bool isDark, Color primary) {
    final agency = prov.userAgency!;
    final ledger = prov.walletLedger;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strict Salary Separation Notice Banner (Section 5)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Agency Wallet receives agency commission & target salary ONLY. Individual host salaries are credited directly to each host\'s personal wallet. Agency owner cannot manually move a host salary into the agency wallet.',
                    style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Wallet Balance Breakdown Cards (Available, Pending)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.amber.shade800, Colors.orange.shade900]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available Earnings', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('\$${agency.availableBalanceUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pending Earnings', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('\$${agency.pendingBalanceUsd.toStringAsFixed(2)}', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Text('Agency Salary Ledger History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 12),

          ...ledger.map((tx) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Agency Settlement (${tx.cycleId})', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark), fontSize: 13)),
                        Text(tx.timestamp.toString().split(' ').first, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('+\$${tx.usdAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildCompactBadge(String label, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(val, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(bool isDark, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(isDark)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HOST DETAIL MODAL (Section 3 & 6) ───
  void _showHostDetailDialog(BuildContext context, AudioHostModel host, bool isDark, Color primary) {
    final targetVal = host.currentLevel * 100000;
    final hours = host.dailyOnlineMinutes ~/ 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(bCtx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(imageUrl: host.avatarUrl, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.getTextPrimary(isDark))),
                      Text('User ID: ${host.userId} • Status: ${host.status}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Performance Detail & Target Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMetricTile(isDark, 'Achieved Target', '${host.achievedDiamonds} pts', Icons.stars_rounded, Colors.amber)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricTile(isDark, 'Required Target', '$targetVal pts', Icons.flag_rounded, Colors.blue)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMetricTile(isDark, 'Verified Live Time', '${hours}h online', Icons.access_time_rounded, Colors.purple)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricTile(isDark, 'Valid Days', '${host.completedValidDays} days', Icons.calendar_month_rounded, Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Host Salary Wallet: \$${host.availableSalaryUsd.toStringAsFixed(2)} USD (Credited directly to host personal wallet)',
                      style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADMIN AUDIT LOG MODAL (Section 6 & 7) ───
  void _showAuditLogDialog(BuildContext context, AgencyProvider prov, bool isDark) {
    final logs = prov.auditLogs;

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Admin Audit Log History', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: logs.isEmpty
              ? const Center(child: Text('No audit log entries recorded yet.'))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(log['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 11)),
                              Text(log['timestamp']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Actor: ${log['actorId']} • Target: ${log['targetId']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          if ((log['reason'] ?? '').isNotEmpty)
                            Text('Reason: ${log['reason']}', style: TextStyle(fontSize: 10, color: AppColors.getTextPrimary(isDark))),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAddHostDialog(BuildContext context, AgencyProvider prov, String currentUserId, bool isDark) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Host by User ID', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        content: TextField(
          controller: _addHostIdController,
          decoration: const InputDecoration(hintText: 'Enter User ID (e.g. user_101)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final id = _addHostIdController.text.trim();
              if (id.isNotEmpty) {
                prov.inviteMember(targetUserId: id, targetName: 'Host $id', inviterUserId: currentUserId, inviterName: 'Agency Manager');
                _addHostIdController.clear();
                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation sent to Host $id!')));
              }
            },
            child: const Text('Add Host'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveHost(BuildContext context, AgencyProvider prov, AudioHostModel host, String currentUserId, bool isDark) {
    _removeReasonController.clear();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${host.userName}?', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to remove this host from your agency? An admin audit log will be created.'),
            const SizedBox(height: 12),
            TextField(
              controller: _removeReasonController,
              decoration: const InputDecoration(hintText: 'Reason for removal (required)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final reason = _removeReasonController.text.trim().isEmpty ? 'Agency owner removal' : _removeReasonController.text.trim();
              prov.removeMember(memberUserId: host.userId, reason: reason, actorUserId: currentUserId);
              Navigator.pop(dlgCtx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${host.userName} removed from agency.')));
            },
            child: const Text('Remove Host', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
