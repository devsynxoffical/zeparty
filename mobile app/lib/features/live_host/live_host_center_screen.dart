import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/live_host_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/policy/live_host_policy.dart';
import '../live/create_live_room_screen.dart';
import '../settings/support_center_screen.dart';
import '../wallet/authorized_sellers_screen.dart';
import '../wallet/diamond_transfer_screen.dart';

class LiveHostCenterScreen extends StatefulWidget {
  const LiveHostCenterScreen({super.key});

  @override
  State<LiveHostCenterScreen> createState() => _LiveHostCenterScreenState();
}

class _LiveHostCenterScreenState extends State<LiveHostCenterScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _loadData() {
    if (!mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user.id.isNotEmpty) {
      context.read<LiveHostProvider>().fetchHostProfile(user.id);
      context.read<LiveHostProvider>().fetchHostTargetSummary();
      context.read<LiveHostProvider>().fetchAttendance();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = context.watch<AuthProvider>().currentUser;
    final liveHostProv = context.watch<LiveHostProvider>();

    final liveHost = liveHostProv.activeLiveHost;
    final targetSummary = liveHostProv.targetSummary;

    if (liveHost == null) {
      if (liveHostProv.isLoading) {
        return Scaffold(
          backgroundColor: AppColors.getBackground(isDark),
          appBar: AppBar(
            title: const Text('Live Host Center'),
            backgroundColor: AppColors.getBackground(isDark),
            elevation: 0,
          ),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (liveHostProv.profileError != null) {
        return Scaffold(
          backgroundColor: AppColors.getBackground(isDark),
          appBar: AppBar(
            title: const Text('Live Host Center'),
            backgroundColor: AppColors.getBackground(isDark),
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load host profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    liveHostProv.profileError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('Live Host Center'),
          backgroundColor: AppColors.getBackground(isDark),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active Direct Live Host profile found.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    final currentLevel =
        targetSummary?.currentTier?.level ??
        LiveHostPolicy.getLevelForDiamonds(liveHost.achievedDiamonds).level;
    final achievedCoins = targetSummary?.achievedCoins ?? 0;
    final nextTargetCoins = targetSummary?.nextTargetCoins ?? 100000;
    final remainingCoins =
        targetSummary?.remainingCoins ??
        (nextTargetCoins > achievedCoins ? nextTargetCoins - achievedCoins : 0);
    final progressPct =
        targetSummary?.progressPercent ??
        (nextTargetCoins > 0
            ? (achievedCoins / nextTargetCoins).clamp(0.0, 1.0)
            : 1.0);

    final currentPolicy = LiveHostPolicy.getLevelForDiamonds(
      liveHost.achievedDiamonds,
    );

    final isEligibleForPay = LiveHostPolicy.isTargetEligible(
      achievedDiamonds: liveHost.achievedDiamonds,
      completedValidDays: liveHost.completedValidDays,
      targetLevel: currentLevel,
    );

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Direct Live Host Center'),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.table_chart_rounded,
              color: Colors.amberAccent,
            ),
            tooltip: 'Policy Table',
            onPressed: () => _showPolicyTableDialog(context, isDark),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.redAccent),
            tooltip: 'Go Live',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            liveHostProv.fetchHostProfile(authUser.id),
            liveHostProv.fetchHostTargetSummary(),
            liveHostProv.fetchAttendance(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Host Profile Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF416C).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(liveHost.avatarUrl),
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
                                      liveHost.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.blueAccent,
                                    size: 16,
                                  ),
                                ],
                              ),
                              Text(
                                'ID: ${liveHost.userId} • Live Host ID: ${liveHost.liveHostId}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Region: ${liveHost.countryCode} • Status: ${liveHost.status}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Level $currentLevel',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                color: Colors.amberAccent,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                targetSummary?.cycleBadge ??
                                    '10-Day Settlement Cycle',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            targetSummary?.cycleDateRange ??
                                (targetSummary?.cycleIdentifier ??
                                    'Cycle 1-10'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${targetSummary?.countdownDays ?? 0}d left',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target Achieved: $achievedCoins 🪙',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          targetSummary?.nextTier != null
                              ? 'Next Target: $nextTargetCoins 🪙'
                              : (nextTargetCoins > achievedCoins
                                    ? 'Target: $nextTargetCoins 🪙'
                                    : 'MAX LEVEL'),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${(progressPct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'Remaining: $remainingCoins 🪙',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    if (targetSummary?.formula != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Target Formula: ${targetSummary!.formula}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Direct Salary Policy Breakdown Card
              Card(
                color: AppColors.getCard(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Direct Salary Policy (100% Direct Payout)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.amberAccent,
                            ),
                            onPressed: () =>
                                _showPolicyTableDialog(context, isDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Direct Basic Salary:'),
                          Text(
                            '\$${currentPolicy.basicSalaryUsd.toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Target Settlement Eligibility:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isEligibleForPay
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEligibleForPay ? 'ELIGIBLE' : 'IN PROGRESS',
                              style: TextStyle(
                                color: isEligibleForPay
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Paid 100% directly by platform to host wallet. ZERO agency commission deducted.',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Verified Live Time Tracker Card (Direct Live Host 1-Hour Daily Streaming Requirement)
              Card(
                color: AppColors.getCard(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Live Streaming Time (1 Hour/Day Requirement)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Direct Live Hosts require 1 verified hour (60 mins) of live video streaming per valid day (vs Audio Hosts requiring 2 hours).',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Required Valid Days: ${currentPolicy.validDaysRequired} days',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Completed: ${liveHost.completedValidDays} / ${currentPolicy.validDaysRequired}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            liveHost.isTodayValid
                                ? Icons.check_circle_rounded
                                : Icons.access_time_filled_rounded,
                            color: liveHost.isTodayValid
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              liveHost.isTodayValid
                                  ? 'Today Status: VALID (${liveHost.dailyLiveMinutes} mins streaming)'
                                  : 'Today Status: IN PROGRESS (${liveHost.dailyLiveMinutes} / 60 mins)',
                              style: TextStyle(
                                color: liveHost.isTodayValid
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Live Host Wallet Card
              Card(
                color: AppColors.getCard(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Host Direct Wallet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pending Salary',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                  ),
                                ),
                                Text(
                                  '\$${liveHost.pendingSalaryUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Available Salary',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                                Text(
                                  '\$${liveHost.availableSalaryUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DiamondTransferScreen(),
                              ),
                            ),
                            child: const Text('Transfer'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthorizedSellersScreen(),
                              ),
                            ),
                            child: const Text('Withdraw'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Navigation Grid Options
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildGridOption(
                    context,
                    'Go Live',
                    Icons.videocam_rounded,
                    Colors.redAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateLiveRoomScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Transfer',
                    Icons.swap_horiz_rounded,
                    Colors.blueAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DiamondTransferScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Target Details',
                    Icons.bar_chart_rounded,
                    Colors.amberAccent,
                    () {
                      _showPolicyTableDialog(context, isDark);
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Withdraw',
                    Icons.storefront_rounded,
                    Colors.greenAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthorizedSellersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Rules',
                    Icons.gavel_rounded,
                    Colors.purpleAccent,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '📜 Live Host Rules & Guidelines opened.',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Support',
                    Icons.support_agent_rounded,
                    Colors.orangeAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const SupportCenterScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Settings',
                    Icons.settings_rounded,
                    Colors.grey,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '⚙️ Live Host Payment Settings opened.',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildGridOption(
                    context,
                    'Policy Table',
                    Icons.table_view_rounded,
                    Colors.tealAccent,
                    () {
                      _showPolicyTableDialog(context, isDark);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridOption(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPolicyTableDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Official Live Host Policy Table',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 36,
              columnSpacing: 10,
              columns: const [
                DataColumn(
                  label: Text(
                    'Level',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Diamonds',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Days',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Salary',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              rows: LiveHostPolicy.policyTable.map((l) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        'Lv ${l.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${l.diamondTarget}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${l.validDaysRequired}d',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '\$${l.basicSalaryUsd.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
