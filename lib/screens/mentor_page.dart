import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import 'checkin_page.dart';

const _maxAttachments = 4;
const _maxAttachmentBytes = 8 * 1024 * 1024;

const _agentPersonas = [
  _AgentPersona(
    id: 'life',
    label: 'Life Agent',
    icon: Icons.psychology_alt_outlined,
    instructions:
        'Act as a balanced personal execution agent: direct, supportive, and action-oriented.',
    prompts: [
      'What should I focus on today?',
      'How am I doing this week?',
      'What is my next best action?',
      'Make a plan for tomorrow',
    ],
  ),
  _AgentPersona(
    id: 'discipline',
    label: 'Discipline Coach',
    icon: Icons.fitness_center_outlined,
    instructions:
        'Be concise, firm, and accountability-focused. Push the user toward the smallest hard action they can complete now.',
    prompts: [
      'Call me out on my excuses',
      'What am I avoiding?',
      'Give me a strict plan for today',
      'Reset my discipline',
    ],
  ),
  _AgentPersona(
    id: 'strategist',
    label: 'Strategist',
    icon: Icons.account_tree_outlined,
    instructions:
        'Think like an operator. Convert mission, goals, deadlines, progress, and blockers into clear priorities and tradeoffs.',
    prompts: [
      'Prioritize my tasks',
      'Find the bottleneck in my plan',
      'Turn my mission into a weekly plan',
      'What should I stop doing?',
    ],
  ),
  _AgentPersona(
    id: 'study',
    label: 'Study Partner',
    icon: Icons.school_outlined,
    instructions:
        'Help the user learn, review, and practice. Tie study actions to stored goals, tasks, journal patterns, and focus scores.',
    prompts: [
      'Make a study plan',
      'Quiz me from my notes',
      'Explain what I uploaded',
      'Help me review my progress',
    ],
  ),
  _AgentPersona(
    id: 'wellness',
    label: 'Wellness Guide',
    icon: Icons.spa_outlined,
    instructions:
        'Be calm, practical, and energy-aware. Focus on sustainable habits, reflection, sleep, stress, and recovery without giving medical advice.',
    prompts: [
      'Why is my energy low?',
      'Help me recover momentum',
      'Make today lighter but useful',
      'What pattern do my check-ins show?',
    ],
  ),
];

class MentorPage extends StatefulWidget {
  const MentorPage({super.key});

  @override
  State<MentorPage> createState() => _MentorPageState();
}

class _MentorPageState extends State<MentorPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _mcp = McpContextService();
  final _ai = AiService();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      role: 'assistant',
      text:
          'I am Agent. Choose a persona, attach anything useful, and ask what you need next.',
      personaLabel: 'Life Agent',
    ),
  ];
  final _attachments = <_AgentInputAttachment>[];
  _AgentPersona _persona = _agentPersonas.first;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_sending &&
        (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent'),
        actions: [
          IconButton(
            tooltip: 'Start check-in',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CheckinPage()),
            ),
            icon: const Icon(Icons.question_answer_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _PersonaBar(
            selected: _persona,
            onChanged: (persona) => setState(() => _persona = persona),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final prompt in _persona.prompts)
                  _PromptChip(text: prompt, onTap: _ask),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemBuilder: (context, index) {
                      return _ChatBubble(message: _messages[index]);
                    },
                    itemCount: _messages.length,
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_attachments.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final attachment in _attachments)
                            _AttachmentChip(
                              attachment: attachment,
                              onDeleted: () => setState(
                                () => _attachments.remove(attachment),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ComposerIconButton(
                        tooltip: 'Attach image',
                        icon: Icons.image_outlined,
                        onPressed: _sending
                            ? null
                            : () => _pickAttachment(_AttachmentKind.image),
                      ),
                      const SizedBox(width: 6),
                      _ComposerIconButton(
                        tooltip: 'Attach voice',
                        icon: Icons.mic_none_outlined,
                        onPressed: _sending
                            ? null
                            : () => _pickAttachment(_AttachmentKind.voice),
                      ),
                      const SizedBox(width: 6),
                      _ComposerIconButton(
                        tooltip: 'Attach file',
                        icon: Icons.attach_file,
                        onPressed: _sending
                            ? null
                            : () => _pickAttachment(_AttachmentKind.file),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Message ${_persona.label}...',
                            prefixIcon: const Icon(Icons.chat_bubble_outline),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: canSend ? _send : null,
                        child: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ask(String text) {
    _controller.text = text;
    _send();
  }

  Future<void> _pickAttachment(_AttachmentKind kind) async {
    if (_attachments.length >= _maxAttachments) {
      _showSnack('Remove an attachment before adding another.');
      return;
    }

    final remaining = _maxAttachments - _attachments.length;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: remaining > 1,
        withData: true,
        type: _pickerType(kind),
        allowedExtensions: _allowedExtensions(kind),
      );
      if (result == null || result.files.isEmpty) return;

      final next = <_AgentInputAttachment>[];
      for (final file in result.files.take(remaining)) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          _showSnack('Could not read ${file.name}.');
          continue;
        }
        if (bytes.length > _maxAttachmentBytes) {
          _showSnack('${file.name} is larger than 8 MB.');
          continue;
        }
        final mimeType = _mimeTypeFor(file, kind);
        next.add(
          _AgentInputAttachment(
            name: file.name,
            mimeType: mimeType,
            bytes: bytes,
            textExcerpt: _textExcerpt(file.name, mimeType, bytes),
          ),
        );
      }

      if (next.isEmpty || !mounted) return;
      setState(() => _attachments.addAll(next));
    } catch (error) {
      _showSnack('Could not attach file: $error');
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (_sending || (text.isEmpty && _attachments.isEmpty)) return;

    final promptText = text.isEmpty
        ? 'Review my attachments and connect them to my current goals.'
        : text;
    final visibleText = text.isEmpty ? 'Review these attachments.' : text;
    final messageAttachments = List<_AgentInputAttachment>.from(_attachments);
    final history = _historyForPrompt();
    final userId = SupabaseService.currentUserId;

    setState(() {
      _sending = true;
      _messages.add(
        _ChatMessage(
          role: 'user',
          text: visibleText,
          attachments: messageAttachments,
        ),
      );
      _controller.clear();
      _attachments.clear();
    });
    _scrollToEnd();

    try {
      final userContext = await _mcp.getUserContext(userId);
      final reply = await _ai.sendAgentMessage(
        message: promptText,
        userContext: userContext,
        personaName: _persona.label,
        personaInstructions: _persona.instructions,
        attachments: [
          for (final attachment in messageAttachments)
            attachment.toAiAttachment(),
        ],
        chatHistory: history,
      );

      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: reply,
            personaLabel: _persona.label,
          ),
        ),
      );
      _scrollToEnd();

      try {
        await _mcp.saveAIFeedback(userId, {
          'feedback_type': 'suggestion',
          'message': '${_persona.label}: $reply',
          'related_data': {
            'source': 'agent_chat',
            'persona': _persona.id,
            'attachments': [
              for (final attachment in messageAttachments)
                attachment.toMetadata(),
            ],
          },
        });
      } catch (_) {
        // Chat should still succeed if storing the reply fails.
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(role: 'assistant', text: error.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<Map<String, String>> _historyForPrompt() {
    final recent = _messages.length <= 10
        ? _messages
        : _messages.sublist(_messages.length - 10);
    return [
      for (final message in recent)
        {
          'role': message.role,
          'text': message.text,
        },
    ];
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PersonaBar extends StatelessWidget {
  const _PersonaBar({
    required this.selected,
    required this.onChanged,
  });

  final _AgentPersona selected;
  final ValueChanged<_AgentPersona> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final dropdown = DropdownButtonFormField<_AgentPersona>(
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Persona',
              prefixIcon: Icon(Icons.support_agent_outlined),
            ),
            items: [
              for (final persona in _agentPersonas)
                DropdownMenuItem(
                  value: persona,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(persona.icon, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(persona.label)),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          );

          final status = Chip(
            avatar: const Icon(Icons.storage_outlined, size: 18),
            label: const Text('Stored data connected'),
            visualDensity: VisualDensity.compact,
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                dropdown,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: status),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 360, child: dropdown),
              const SizedBox(width: 12),
              status,
            ],
          );
        },
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.text, required this.onTap});

  final String text;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
      child: ActionChip(
        avatar: const Icon(Icons.auto_awesome, size: 18),
        label: Text(text),
        onPressed: () => onTap(text),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor =
        isUser ? colorScheme.primaryContainer : colorScheme.surface;
    final textColor =
        isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            color: bubbleColor,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser
                        ? Icons.person_outline
                        : Icons.support_agent_outlined,
                    size: 20,
                    color: textColor,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: DefaultTextStyle(
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: textColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser && message.personaLabel != null) ...[
                            Text(
                              message.personaLabel!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(message.text),
                          if (message.attachments.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final attachment in message.attachments)
                                  _AttachmentChip(
                                    attachment: attachment,
                                    dense: true,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    this.onDeleted,
    this.dense = false,
  });

  final _AgentInputAttachment attachment;
  final VoidCallback? onDeleted;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final label =
        '${attachment.name} (${_formatBytes(attachment.bytes.length)})';
    return InputChip(
      avatar: Icon(_iconForMime(attachment.mimeType), size: 18),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dense ? 180 : 260),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      onDeleted: onDeleted,
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _AgentPersona {
  const _AgentPersona({
    required this.id,
    required this.label,
    required this.icon,
    required this.instructions,
    required this.prompts,
  });

  final String id;
  final String label;
  final IconData icon;
  final String instructions;
  final List<String> prompts;
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.personaLabel,
    this.attachments = const [],
  });

  final String role;
  final String text;
  final String? personaLabel;
  final List<_AgentInputAttachment> attachments;
}

class _AgentInputAttachment {
  const _AgentInputAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.textExcerpt,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? textExcerpt;

  AiAttachment toAiAttachment() {
    return AiAttachment(
      name: name,
      mimeType: mimeType,
      bytes: bytes,
      textExcerpt: textExcerpt,
    );
  }

  Map<String, dynamic> toMetadata() {
    return {
      'name': name,
      'mime_type': mimeType,
      'size_bytes': bytes.length,
    };
  }
}

enum _AttachmentKind { image, voice, file }

FileType _pickerType(_AttachmentKind kind) {
  if (kind == _AttachmentKind.file) return FileType.any;
  return FileType.custom;
}

List<String>? _allowedExtensions(_AttachmentKind kind) {
  return switch (kind) {
    _AttachmentKind.image => ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'],
    _AttachmentKind.voice => [
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
        'flac',
        'webm',
      ],
    _AttachmentKind.file => null,
  };
}

String _mimeTypeFor(PlatformFile file, _AttachmentKind kind) {
  final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
  const mimeByExtension = {
    'aac': 'audio/aac',
    'csv': 'text/csv',
    'css': 'text/css',
    'dart': 'text/plain',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'flac': 'audio/flac',
    'gif': 'image/gif',
    'heic': 'image/heic',
    'html': 'text/html',
    'jpeg': 'image/jpeg',
    'jpg': 'image/jpeg',
    'js': 'text/javascript',
    'json': 'application/json',
    'log': 'text/plain',
    'm4a': 'audio/mp4',
    'md': 'text/markdown',
    'mp3': 'audio/mpeg',
    'ogg': 'audio/ogg',
    'pdf': 'application/pdf',
    'png': 'image/png',
    'txt': 'text/plain',
    'ts': 'text/plain',
    'wav': 'audio/wav',
    'webm': 'audio/webm',
    'webp': 'image/webp',
    'xml': 'application/xml',
    'yaml': 'text/yaml',
    'yml': 'text/yaml',
  };

  final mapped = mimeByExtension[extension];
  if (mapped != null) return mapped;
  if (kind == _AttachmentKind.image) return 'image/jpeg';
  if (kind == _AttachmentKind.voice) return 'audio/mpeg';
  return 'application/octet-stream';
}

String? _textExcerpt(String name, String mimeType, Uint8List bytes) {
  final lowerName = name.toLowerCase();
  final looksText = mimeType.startsWith('text/') ||
      mimeType == 'application/json' ||
      mimeType == 'application/xml' ||
      lowerName.endsWith('.md') ||
      lowerName.endsWith('.log');
  if (!looksText) return null;

  final text = utf8.decode(bytes, allowMalformed: true).trim();
  if (text.isEmpty) return null;
  return text.length <= 5000 ? text : '${text.substring(0, 5000)}\n...';
}

IconData _iconForMime(String mimeType) {
  if (mimeType.startsWith('image/')) return Icons.image_outlined;
  if (mimeType.startsWith('audio/')) return Icons.graphic_eq_outlined;
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mimeType.startsWith('text/') || mimeType == 'application/json') {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
