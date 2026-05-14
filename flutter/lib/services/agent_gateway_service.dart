import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

class AgentGatewayService {
  AgentGatewayService({SupabaseClient? client, http.Client? httpClient})
    : _client = client ?? SupabaseService.client,
      _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  Future<Map<String, dynamic>> createAgentRun({
    required String message,
    Object? conversationId,
    List<Map<String, dynamic>> attachments = const [],
    String? idempotencyKey,
  }) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again before messaging Agent.');
    }

    final response = await _http
        .post(
          _workerUri('/agent/chat'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': message,
            if (conversationId != null) 'conversation_id': conversationId,
            if (attachments.isNotEmpty) 'attachments': attachments,
            if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
          }),
        )
        .timeout(const Duration(seconds: 90));

    final data = _decodeJsonResponse(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data['detail'] ?? data['error'] ?? response.body;
      throw StateError(detail.toString());
    }
    return data;
  }

  Future<Map<String, dynamic>> getAgentRun(Object runId) async {
    final data = await _client
        .from('agent_runs')
        .select('id, status, result, error, conversation_id, updated_at')
        .eq('id', runId)
        .single();
    return Map<String, dynamic>.from(data as Map);
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

  Uri _workerUri(String path) {
    final baseUrl = AppConfig.fastApiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw StateError('FASTAPI_BASE_URL is not configured.');
    }
    return Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
  }

  Map<String, dynamic> _decodeJsonResponse(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'data': decoded};
    } catch (_) {
      return {'data': body};
    }
  }
}
