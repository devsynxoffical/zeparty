import '../services/api_client.dart';
import '../../models/support_ticket_model.dart';

/// Repository for customer support ticket management and interactive messaging
class SupportRepository {
  SupportRepository._();
  static final SupportRepository instance = SupportRepository._();

  final ApiClient _client = ApiClient.instance;

  /// POST /v1/support/tickets
  /// Creates a new customer support ticket
  Future<SupportTicketModel> createTicket({
    required String subject,
    required String message,
    String category = 'GENERAL',
    String priority = 'MEDIUM',
  }) async {
    final response = await _client.post(
      '/v1/support/tickets',
      data: {
        'subject': subject,
        'message': message,
        'category': category,
        'priority': priority,
      },
    );

    final rawData = response.data['data'] as Map<String, dynamic>;
    return SupportTicketModel.fromJson(rawData);
  }

  /// GET /v1/support/tickets
  /// Retrieves a paginated list of tickets for the authenticated user
  Future<Map<String, dynamic>> getUserTickets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _client.get(
      '/v1/support/tickets',
      queryParameters: queryParams,
    );

    final dataList = response.data['data'] as List<dynamic>? ?? [];
    final tickets = dataList
        .map((t) => SupportTicketModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return {
      'tickets': tickets,
      'meta': response.data['meta'] as Map<String, dynamic>? ?? {},
    };
  }

  /// GET /v1/support/tickets/:id
  /// Retrieves ticket details with full message conversation
  Future<SupportTicketModel> getTicketDetails(String ticketId) async {
    final response = await _client.get('/v1/support/tickets/$ticketId');
    final rawData = response.data['data'] as Map<String, dynamic>;
    return SupportTicketModel.fromJson(rawData);
  }

  /// POST /v1/support/tickets/:id/reply
  /// Sends a reply message to an existing support ticket
  Future<SupportMessageModel> replyToTicket(
    String ticketId, {
    required String message,
    dynamic attachmentsJson,
  }) async {
    final payload = <String, dynamic>{
      'message': message,
    };
    if (attachmentsJson != null) {
      payload['attachmentsJson'] = attachmentsJson;
    }

    final response = await _client.post(
      '/v1/support/tickets/$ticketId/reply',
      data: payload,
    );

    final rawData = response.data['data'] as Map<String, dynamic>;
    return SupportMessageModel.fromJson(rawData);
  }
}
