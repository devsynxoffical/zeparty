import '../services/api_client.dart';

/// Repository for submitting and tracking moderation & violation reports
class ReportRepository {
  ReportRepository._();
  static final ReportRepository instance = ReportRepository._();

  final ApiClient _client = ApiClient.instance;

  /// POST /v1/reports
  /// Submits a user violation report with anti-spam deduplication
  Future<Map<String, dynamic>> submitReport({
    String? reportedUserId,
    String? reportedRoomId,
    String? reportedPostId,
    String? reportedCommentId,
    String? reportedMessageId,
    required String violationType,
    String? description,
    String? screenshotUrl,
    String priority = 'MEDIUM',
  }) async {
    final payload = <String, dynamic>{
      'violationType': violationType,
      'priority': priority,
    };

    if (reportedUserId != null && reportedUserId.isNotEmpty) {
      payload['reportedUserId'] = reportedUserId;
    }
    if (reportedRoomId != null && reportedRoomId.isNotEmpty) {
      payload['reportedRoomId'] = reportedRoomId;
    }
    if (reportedPostId != null && reportedPostId.isNotEmpty) {
      payload['reportedPostId'] = reportedPostId;
    }
    if (reportedCommentId != null && reportedCommentId.isNotEmpty) {
      payload['reportedCommentId'] = reportedCommentId;
    }
    if (reportedMessageId != null && reportedMessageId.isNotEmpty) {
      payload['reportedMessageId'] = reportedMessageId;
    }
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }
    if (screenshotUrl != null && screenshotUrl.isNotEmpty) {
      payload['screenshotUrl'] = screenshotUrl;
    }

    final response = await _client.post('/v1/reports', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// GET /v1/reports/:id
  /// Retrieves details and resolution of a submitted report
  Future<Map<String, dynamic>> getReportDetails(String reportId) async {
    final response = await _client.get('/v1/reports/$reportId');
    return response.data as Map<String, dynamic>;
  }
}
