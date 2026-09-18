import 'dart:async';
import 'package:flutter/material.dart';
import '../core/repositories/support_repository.dart';
import '../core/services/socket_service.dart';
import '../models/support_ticket_model.dart';

class SupportProvider extends ChangeNotifier {
  final SupportRepository _repository = SupportRepository.instance;
  final SocketService _socketService = SocketService.instance;

  List<SupportTicketModel> _tickets = [];
  bool _isLoading = false;
  String? _errorMessage;

  SupportTicketModel? _activeTicket;
  bool _isDetailLoading = false;
  bool _isSendingReply = false;

  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _ticketUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _ticketResolvedSub;

  List<SupportTicketModel> get tickets => List.unmodifiable(_tickets);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SupportTicketModel? get activeTicket => _activeTicket;
  bool get isDetailLoading => _isDetailLoading;
  bool get isSendingReply => _isSendingReply;

  SupportProvider() {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _messageSub = _socketService.onTicketMessage.listen((data) {
      final ticketId = data['ticketId']?.toString();
      if (ticketId == null) return;

      final newMsg = SupportMessageModel.fromJson(data);

      if (_activeTicket != null && _activeTicket!.id == ticketId) {
        final existing = _activeTicket!.messages.any((m) => m.id == newMsg.id);
        if (!existing) {
          _activeTicket = _activeTicket!.copyWith(
            messages: [..._activeTicket!.messages, newMsg],
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }

      // Update in tickets list as well
      final idx = _tickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _tickets[idx] = _tickets[idx].copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
    });

    _ticketUpdatedSub = _socketService.onTicketUpdated.listen((data) {
      final ticketId = data['ticketId']?.toString() ?? data['id']?.toString();
      if (ticketId == null) return;

      final statusStr = data['status']?.toString();
      if (statusStr != null) {
        final status = SupportTicketStatusExtension.fromString(statusStr);
        if (_activeTicket != null && _activeTicket!.id == ticketId) {
          _activeTicket = _activeTicket!.copyWith(status: status, updatedAt: DateTime.now());
          notifyListeners();
        }

        final idx = _tickets.indexWhere((t) => t.id == ticketId);
        if (idx != -1) {
          _tickets[idx] = _tickets[idx].copyWith(status: status, updatedAt: DateTime.now());
          notifyListeners();
        }
      }
    });

    _ticketResolvedSub = _socketService.onTicketResolved.listen((data) {
      final ticketId = data['ticketId']?.toString() ?? data['id']?.toString();
      if (ticketId == null) return;

      if (_activeTicket != null && _activeTicket!.id == ticketId) {
        _activeTicket = _activeTicket!.copyWith(
          status: SupportTicketStatus.resolved,
          resolvedAt: DateTime.now(),
          resolutionNotes: data['resolutionNotes']?.toString(),
        );
        notifyListeners();
      }

      final idx = _tickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _tickets[idx] = _tickets[idx].copyWith(
          status: SupportTicketStatus.resolved,
          resolvedAt: DateTime.now(),
        );
        notifyListeners();
      }
    });
  }

  /// Loads all support tickets for current user
  Future<void> loadTickets({String? status, bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getUserTickets(status: status);
      _tickets = (result['tickets'] as List<SupportTicketModel>?) ?? [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Creates a new support ticket
  Future<SupportTicketModel> createTicket({
    required String subject,
    required String message,
    String category = 'GENERAL',
    String priority = 'MEDIUM',
  }) async {
    try {
      final ticket = await _repository.createTicket(
        subject: subject,
        message: message,
        category: category,
        priority: priority,
      );

      _tickets.insert(0, ticket);
      notifyListeners();
      return ticket;
    } catch (e) {
      rethrow;
    }
  }

  /// Loads details and conversation for a specific ticket
  Future<void> loadTicketDetails(String ticketId) async {
    _isDetailLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeTicket = await _repository.getTicketDetails(ticketId);
      _isDetailLoading = false;
      notifyListeners();
    } catch (e) {
      _isDetailLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Sends a reply inside an open support ticket
  Future<void> sendReply(String ticketId, String message, {dynamic attachmentsJson}) async {
    if (message.trim().isEmpty) return;

    _isSendingReply = true;
    notifyListeners();

    try {
      final newMsg = await _repository.replyToTicket(
        ticketId,
        message: message,
        attachmentsJson: attachmentsJson,
      );

      if (_activeTicket != null && _activeTicket!.id == ticketId) {
        final exists = _activeTicket!.messages.any((m) => m.id == newMsg.id);
        if (!exists) {
          _activeTicket = _activeTicket!.copyWith(
            messages: [..._activeTicket!.messages, newMsg],
            updatedAt: DateTime.now(),
          );
        }
      }

      _isSendingReply = false;
      notifyListeners();
    } catch (e) {
      _isSendingReply = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _ticketUpdatedSub?.cancel();
    _ticketResolvedSub?.cancel();
    super.dispose();
  }
}
