import 'package:flutter/material.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';

class BDCenterScreen extends StatefulWidget {
  const BDCenterScreen({super.key});

  @override
  State<BDCenterScreen> createState() => _BDCenterScreenState();
}

class _BDCenterScreenState extends State<BDCenterScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _bdStatus;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _agentsList = [];

  @override
  void initState() {
    super.initState();
    _fetchBDData();
  }

  Future<void> _fetchBDData() async {
    setState(() => _isLoading = true);
    try {
      final statusRes = await ApiClient.instance.get('/v1/bd-centers/my-status');
      final dashRes = await ApiClient.instance.get('/v1/bd-centers/dashboard');

      if (mounted) {
        setState(() {
          if (statusRes.statusCode == 200 && statusRes.data?['success'] == true) {
            _bdStatus = statusRes.data['data'] as Map<String, dynamic>?;
          }
          if (dashRes.statusCode == 200 && dashRes.data?['success'] == true) {
            _dashboardData = dashRes.data['data'] as Map<String, dynamic>?;
            _agentsList = (_dashboardData?['agents'] as List?) ?? (_dashboardData?['team'] as List?) ?? [];
          }
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bdName = _bdStatus?['name']?.toString() ?? _bdStatus?['title']?.toString() ?? 'Business Development Center';
    final bdCode = _bdStatus?['code']?.toString() ?? _bdStatus?['bdCenterId']?.toString() ?? 'BD-OFFICIAL';
    final monthlyDiamonds = _dashboardData?['monthlyDiamonds']?.toString() ?? _dashboardData?['totalGroupDiamondsMonth']?.toString() ?? '1,250,000';
    final activeAgenciesCount = _dashboardData?['totalAgencies']?.toString() ?? _agentsList.length.toString();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C091A) : AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'BD Center Dashboard',
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextPrimary(isDark)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _fetchBDData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BD Center Header Card (Fixed Right Overflow)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00838F), Color(0xFF006064), Color(0xFF004D40)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00838F).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bdName,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: $bdCode',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Colors.cyanAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'BD AGENT',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            children: [
                              Expanded(child: _buildMetricItem('Monthly Diamonds', '💎 $monthlyDiamonds')),
                              Container(width: 1, height: 28, color: Colors.white24),
                              Expanded(child: _buildMetricItem('Managed Agencies', '🏢 $activeAgenciesCount')),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Stats & Target Progress
                    Text(
                      '📊 Monthly Target & Performance',
                      style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Quarterly Target Progress', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                              const Text('82%', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: const LinearProgressIndicator(
                              value: 0.82,
                              minHeight: 8,
                              backgroundColor: Colors.white10,
                              color: Colors.cyanAccent,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keep onboarding top agencies to maximize your monthly BD commission tier.',
                            style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Team / Recruited Agencies List
                    Text(
                      '🏢 Recruited Agencies & Team',
                      style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (_agentsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'No agency linked under your BD Center yet.',
                          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _agentsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final agent = _agentsList[index] as Map<String, dynamic>;
                          final name = agent['name'] ?? agent['agencyName'] ?? 'Agency ${index + 1}';
                          final code = agent['code'] ?? agent['agencyCode'] ?? 'AG-100$index';
                          final diamonds = agent['diamonds'] ?? agent['monthlyDiamonds'] ?? '0';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                                  child: const Icon(Icons.business_rounded, color: Colors.cyanAccent, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.toString(),
                                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Code: $code',
                                        style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '💎 $diamonds',
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
