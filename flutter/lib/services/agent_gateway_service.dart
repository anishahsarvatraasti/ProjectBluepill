import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AgentGatewayService {
  AgentGatewayService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createAgentRun({
    required String message,
    Object? conversationId,
    List<Map<String, dynamic>> attachments = const [],
    String? idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      'agent-chat',
      body: {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (attachments.isNotEmpty) 'attachments': attachments,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );
    return _mapResponse(response.data);
  }

  Future<Map<String, dynamic>> createScheduledJob({
    required String jobType,
    required DateTime scheduledFor,
    Map<String, dynamic> payload = const {},
    String? idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      'schedule-job',
      body: {
        'job_type': jobType,
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'payload': payload,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );
    return _mapResponse(response.data);
  }

  Future<Map<String, dynamic>> decideApproval({
    required Object approvalId,
    required bool approved,
    Map<String, dynamic> decisionPayload = const {},
  }) async {
    final response = await _client.functions.invoke(
      'approve-action',
      body: {
        'approval_id': approvalId,
        'decision': approved ? 'approved' : 'rejected',
        'decision_payload': decisionPayload,
      },
    );
    return _mapResponse(response.data);
  }

  Map<String, dynamic> _mapResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }
}
