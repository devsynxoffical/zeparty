import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/support_ticket_model.dart';
import '../../providers/support_provider.dart';
import 'create_ticket_screen.dart';
import 'ticket_details_screen.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().loadTickets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support Desk'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All Tickets'),
            Tab(text: 'Active'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTicketList(provider.tickets, provider),
          _buildTicketList(
            provider.tickets.where((t) => t.status != SupportTicketStatus.resolved && t.status != SupportTicketStatus.closed).toList(),
            provider,
          ),
          _buildTicketList(
            provider.tickets.where((t) => t.status == SupportTicketStatus.resolved || t.status == SupportTicketStatus.closed).toList(),
            provider,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const CreateTicketScreen()),
          );
        },
      ),
    );
  }

  Widget _buildTicketList(List<SupportTicketModel> tickets, SupportProvider provider) {
    if (provider.isLoading && tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => provider.loadTickets(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headset_mic_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Support Tickets',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Have an issue or inquiry? Open a ticket and our team will help you.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadTickets(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => TicketDetailsScreen(ticketId: ticket.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Number & Status Badge
                    Row(
                      children: [
                        Icon(ticket.category.icon, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '#${ticket.ticketNumber ?? ticket.id.substring(0, 6)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ticket.status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ticket.status.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            ticket.status.displayName,
                            style: TextStyle(
                              color: ticket.status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Subject
                    Text(
                      ticket.subject,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),

                    const SizedBox(height: 6),

                    // Footer with category & date
                    Row(
                      children: [
                        Text(
                          ticket.category.displayName,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const Spacer(),
                        Text(
                          AppFormatters.formatTimeAgo(ticket.updatedAt),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
