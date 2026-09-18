import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/support_ticket_model.dart';
import '../../providers/support_provider.dart';

class TicketDetailsScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailsScreen({
    super.key,
    required this.ticketId,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().loadTicketDetails(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    final provider = context.read<SupportProvider>();

    try {
      await provider.sendReply(widget.ticketId, text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final ticket = provider.activeTicket;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket #${ticket?.ticketNumber ?? widget.ticketId.substring(0, 6)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (ticket != null)
              Text(
                ticket.subject,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (ticket != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ticket.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ticket.status.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    ticket.status.displayName,
                    style: TextStyle(
                      color: ticket.status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: provider.isDetailLoading && ticket == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ticket == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Failed to load ticket details.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => provider.loadTicketDetails(widget.ticketId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Ticket Meta Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Theme.of(context).cardColor,
                      child: Row(
                        children: [
                          Icon(ticket.category.icon, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            ticket.category.displayName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            'Opened ${AppFormatters.formatTimeAgo(ticket.createdAt)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Messages List
                    Expanded(
                      child: ticket.messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet in this ticket.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: ticket.messages.length,
                              itemBuilder: (context, index) {
                                final msg = ticket.messages[index];
                                final isUser = msg.isFromUser;

                                return Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? AppColors.primary
                                          : isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                                        bottomRight: Radius.circular(isUser ? 4 : 16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isUser)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.verified_user_rounded, size: 13, color: Colors.blueAccent),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'ZeParty Support Agent',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blueAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Text(
                                          msg.message,
                                          style: TextStyle(
                                            color: isUser ? Colors.black : (isDark ? Colors.white : Colors.black87),
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppFormatters.formatTimeAgo(msg.createdAt),
                                          style: TextStyle(
                                            color: isUser ? Colors.black54 : Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Reply Input Bar
                    if (ticket.status == SupportTicketStatus.closed || ticket.status == SupportTicketStatus.resolved)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).cardColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'This ticket is ${ticket.status.displayName.toLowerCase()}. Open a new ticket for further assistance.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                maxLines: 3,
                                minLines: 1,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary,
                              child: IconButton(
                                icon: provider.isSendingReply
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                                onPressed: provider.isSendingReply ? null : _sendReply,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
