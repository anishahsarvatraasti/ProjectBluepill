import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

const progressExtractionSystemPrompt = '''
You are a progress extraction assistant. Your job is to convert the user's natural language check-in answer into structured JSON. Do not give advice. Do not include extra text. Only return valid JSON.

Return this format:
{
  "completed_tasks": [],
  "missed_tasks": [],
  "partial_tasks": [],
  "habits_completed": [],
  "habits_missed": [],
  "study_minutes": null,
  "work_minutes": null,
  "exercise_minutes": null,
  "mood": null,
  "focus_score": null,
  "blockers": [],
  "lesson": null,
  "tomorrow_adjustment": null
}
''';

const agentSystemPrompt = '''
You are a personal AI Agent for Project BluePill. You help users connect their daily actions with their long-term mission. You are practical, honest, motivational, and personalized. Use the user's stored data before giving advice. Do not give generic advice. Always mention the user's mission, recent progress, weakness, and next best action when possible. Keep responses clear, human, and supportive.

When the user provides images, audio, or files, use the supplied attachment content and metadata alongside the stored user context. If a file type cannot be inspected by the active model, say what you can and cannot infer instead of pretending to have read it.
''';

class AiAttachment {
  const AiAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.textExcerpt,
  });

  final String name;
  final String mimeType;
  final List<int> bytes;
  final String? textExcerpt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio => mimeType.startsWith('audio/');

  bool get canSendToGeminiInline {
    return isImage || isAudio || mimeType == 'application/pdf';
  }

  Map<String, dynamic> toPromptContext() {
    return {
      'name': name,
      'mime_type': mimeType,
      'size_bytes': bytes.length,
      if (textExcerpt != null && textExcerpt!.trim().isNotEmpty)
        'text_excerpt': textExcerpt,
    };
  }
}

class AiService {
  Future<String> generateDailySuggestion(Map<String, dynamic> userContext) {
    return _mentorText(
      userContext,
      'Give one specific daily suggestion for today.',
      fallback:
          'Complete your top 2 tasks before adding new work. Keep the day narrow and finishable.',
    );
  }

  Future<String> generateMotivation(Map<String, dynamic> userContext) {
    return _mentorText(
      userContext,
      'Give one short motivation message in the user preferred motivation style.',
      fallback:
          'You do not need a perfect day. You need one disciplined action today.',
    );
  }

  Future<String> generateWeaknessAlert(Map<String, dynamic> userContext) {
    return _mentorText(
      userContext,
      'Identify the user most important weakness or risk this week in one sentence.',
      fallback: 'Your sleep and focus scores are low this week.',
    );
  }

  Future<Map<String, dynamic>> extractProgressFromCheckin(
    String userAnswer,
    Map<String, dynamic> userContext,
  ) async {
    final fallback = _emptyExtraction();
    if (!AppConfig.aiConfigured) {
      return {
        ...fallback,
        ..._localExtract(userAnswer),
      };
    }

    final content = await _chat(
      system: progressExtractionSystemPrompt,
      user:
          'User context JSON:\n${_compactJson(userContext)}\n\nCheck-in answer:\n$userAnswer',
      jsonMode: true,
      fallback: jsonEncode(fallback),
    );

    final decoded = _tryDecodeJson(content);
    if (decoded == null) {
      return {
        ...fallback,
        ..._localExtract(userAnswer),
      };
    }
    return {
      ...fallback,
      ...decoded,
    };
  }

  Future<String> generateWeeklyReview(Map<String, dynamic> userContext) {
    return _mentorText(
      userContext,
      'Write a concise weekly review: what worked, what failed, what changes next week.',
      fallback:
          'This week, consistency matters more than intensity. Keep one focus block, one health habit, and one night reflection non-negotiable.',
    );
  }

  Future<List<Map<String, dynamic>>> generateTaskPriorityOrder(
    List<Map<String, dynamic>> tasks,
    Map<String, dynamic> userContext,
  ) async {
    final pending = tasks.where((task) => task['status'] != 'completed');
    final local = _localTaskOrder(pending.toList());
    if (!AppConfig.aiConfigured || local.length < 2) return local;

    final content = await _chat(
      system:
          'Return only valid JSON in this format: {"ordered_task_ids":["id"],"reason":"short reason"}.',
      user:
          'Order these tasks by mission relevance, priority, deadline, and effort. Context: ${_compactJson(userContext)} Tasks: ${_compactJson(local)}',
      jsonMode: true,
      fallback: '{"ordered_task_ids":[]}',
    );

    final decoded = _tryDecodeJson(content);
    final orderedIds = decoded?['ordered_task_ids'];
    if (orderedIds is! List) return local;

    final byId = {for (final task in local) task['id'].toString(): task};
    final ordered = <Map<String, dynamic>>[];
    for (final id in orderedIds) {
      final task = byId[id.toString()];
      if (task != null) ordered.add(task);
    }
    for (final task in local) {
      if (!ordered.any((item) => item['id'] == task['id'])) {
        ordered.add(task);
      }
    }
    return ordered;
  }

  Future<String> generateMissionAdvice(Map<String, dynamic> userContext) {
    return _mentorText(
      userContext,
      'Give practical advice on connecting dream mission, goals, and today tasks.',
      fallback:
          'Make the mission visible in today task list: one yearly goal should produce one weekly goal and one concrete task today.',
    );
  }

  Future<String> sendMentorMessage(
    String message,
    Map<String, dynamic> userContext,
  ) {
    return sendAgentMessage(message: message, userContext: userContext);
  }

  Future<String> sendAgentMessage({
    required String message,
    required Map<String, dynamic> userContext,
    String personaName = 'Life Agent',
    String personaInstructions =
        'Act as a balanced personal execution agent: direct, supportive, and action-oriented.',
    List<AiAttachment> attachments = const [],
    List<Map<String, String>> chatHistory = const [],
  }) {
    final system = '''
$agentSystemPrompt

Selected persona: $personaName
$personaInstructions
''';

    return _mentorText(
      userContext,
      _agentRequest(
        message: message,
        personaName: personaName,
        chatHistory: chatHistory,
        attachments: attachments,
      ),
      fallback:
          _agentFallback(personaName: personaName, attachments: attachments),
      systemOverride: system,
      attachments: attachments,
    );
  }

  Future<String> _mentorText(
    Map<String, dynamic> userContext,
    String request, {
    required String fallback,
    String? systemOverride,
    List<AiAttachment> attachments = const [],
  }) {
    if (!AppConfig.aiConfigured) return Future.value(fallback);
    return _chat(
      system: systemOverride ?? agentSystemPrompt,
      user: 'User context JSON:\n${_compactJson(userContext)}\n\n$request',
      fallback: fallback,
      attachments: attachments,
    );
  }

  Future<String> _chat({
    required String system,
    required String user,
    required String fallback,
    bool jsonMode = false,
    List<AiAttachment> attachments = const [],
  }) async {
    try {
      if (AppConfig.aiProvider == 'gemini') {
        return _geminiChat(
          system: system,
          user: user,
          fallback: fallback,
          attachments: attachments,
        );
      }
      return _openAiCompatibleChat(
        system: system,
        user: user,
        fallback: fallback,
        jsonMode: jsonMode,
        attachments: attachments,
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<String> _openAiCompatibleChat({
    required String system,
    required String user,
    required String fallback,
    required bool jsonMode,
    required List<AiAttachment> attachments,
  }) async {
    final provider = AppConfig.aiProvider;
    final apiKey = provider == 'openrouter'
        ? AppConfig.openRouterApiKey
        : AppConfig.openAiApiKey;
    final model = provider == 'openrouter'
        ? AppConfig.openRouterModel
        : AppConfig.openAiModel;
    final baseUrl = provider == 'openrouter'
        ? AppConfig.openRouterBaseUrl
        : AppConfig.openAiBaseUrl;

    if (apiKey.isEmpty) return fallback;

    final uri =
        Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions');
    final imageAttachments = jsonMode
        ? <AiAttachment>[]
        : attachments.where((attachment) => attachment.isImage).toList();
    final userContent = imageAttachments.isEmpty
        ? user
        : [
            {'type': 'text', 'text': user},
            for (final attachment in imageAttachments)
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${attachment.mimeType};base64,${base64Encode(attachment.bytes)}',
                },
              },
          ];

    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': userContent},
      ],
      'temperature': jsonMode ? 0.1 : 0.7,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
            if (provider == 'openrouter')
              'HTTP-Referer': AppConfig.openRouterSiteUrl,
            if (provider == 'openrouter')
              'X-Title': AppConfig.openRouterAppName,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return fallback;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final choice = choices.first;
      if (choice is Map && choice['message'] is Map) {
        final message = choice['message'] as Map;
        return message['content']?.toString() ?? fallback;
      }
    }
    return fallback;
  }

  Future<String> _geminiChat({
    required String system,
    required String user,
    required String fallback,
    required List<AiAttachment> attachments,
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty) return fallback;
    final model = AppConfig.geminiModel;
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final parts = <Map<String, dynamic>>[
      {'text': user},
      for (final attachment in attachments.where(
        (attachment) => attachment.canSendToGeminiInline,
      ))
        {
          'inlineData': {
            'mimeType': attachment.mimeType,
            'data': base64Encode(attachment.bytes),
          },
        },
    ];

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': parts,
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return fallback;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final candidate = candidates.first;
      if (candidate is Map && candidate['content'] is Map) {
        final content = candidate['content'] as Map;
        final parts = content['parts'];
        if (parts is List && parts.isNotEmpty) {
          final part = parts.first;
          if (part is Map) return part['text']?.toString() ?? fallback;
        }
      }
    }
    return fallback;
  }

  List<Map<String, dynamic>> _localTaskOrder(List<Map<String, dynamic>> tasks) {
    final ordered = [...tasks];
    const priorityWeight = {'high': 0, 'medium': 1, 'low': 2};
    ordered.sort((a, b) {
      final priority = (priorityWeight[a['priority']] ?? 1)
          .compareTo(priorityWeight[b['priority']] ?? 1);
      if (priority != 0) return priority;
      final aDate = DateTime.tryParse(a['due_date']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['due_date']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return ordered;
  }

  Map<String, dynamic> _emptyExtraction() {
    return {
      'completed_tasks': [],
      'missed_tasks': [],
      'partial_tasks': [],
      'habits_completed': [],
      'habits_missed': [],
      'study_minutes': null,
      'work_minutes': null,
      'exercise_minutes': null,
      'mood': null,
      'focus_score': null,
      'blockers': [],
      'lesson': null,
      'tomorrow_adjustment': null,
    };
  }

  Map<String, dynamic> _localExtract(String answer) {
    final lower = answer.toLowerCase();
    final minutesMatch =
        RegExp(r'(\d+)\s*(minute|min|minutes|mins)').firstMatch(lower);
    final focusMatch = RegExp(r'focus(?:ed)?\D*(10|[1-9])').firstMatch(lower);
    final blockers = <String>[
      if (lower.contains('tired')) 'tired',
      if (lower.contains('stress')) 'stress',
      if (lower.contains('busy')) 'busy',
      if (lower.contains('sleep')) 'sleep',
    ];

    return {
      'study_minutes': lower.contains('stud')
          ? int.tryParse(minutesMatch?.group(1) ?? '')
          : null,
      'work_minutes': lower.contains('work')
          ? int.tryParse(minutesMatch?.group(1) ?? '')
          : null,
      'exercise_minutes': lower.contains('gym') ||
              lower.contains('workout') ||
              lower.contains('exercise')
          ? int.tryParse(minutesMatch?.group(1) ?? '')
          : null,
      'mood': lower.contains('tired') || lower.contains('low')
          ? 'low energy'
          : null,
      'focus_score': int.tryParse(focusMatch?.group(1) ?? ''),
      'blockers': blockers,
    };
  }

  Map<String, dynamic>? _tryDecodeJson(String content) {
    final cleaned = content
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _compactJson(Object value) {
    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(value);
    return text.length <= 9000 ? text : '${text.substring(0, 9000)}\n...';
  }

  String _agentRequest({
    required String message,
    required String personaName,
    required List<Map<String, String>> chatHistory,
    required List<AiAttachment> attachments,
  }) {
    final historyText = chatHistory.isEmpty
        ? 'No prior messages in this session.'
        : chatHistory
            .map((item) => '${item['role'] ?? 'user'}: ${item['text'] ?? ''}')
            .join('\n');
    final attachmentText = attachments.isEmpty
        ? 'No attachments.'
        : _compactJson(
            attachments.map((item) => item.toPromptContext()).toList());

    return '''
Selected persona: $personaName

Conversation history:
$historyText

User message:
$message

Attachments:
$attachmentText
''';
  }

  String _agentFallback({
    required String personaName,
    required List<AiAttachment> attachments,
  }) {
    final attachmentNote = attachments.isEmpty
        ? ''
        : ' I can see you attached ${attachments.length} item${attachments.length == 1 ? '' : 's'}, but the AI provider is not configured right now.';
    return 'Based on your stored data, your $personaName recommends finishing one high-priority task and completing a short check-in so your next action stays connected to your mission.$attachmentNote';
  }
}
