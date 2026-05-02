import 'package:flutter/material.dart';

import '../models/model_helpers.dart';
import '../services/ai_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _mood = TextEditingController();
  final _content = TextEditingController();
  final _mcp = McpContextService();
  final _ai = AiService();
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;
  bool _summarizing = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _mood.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return _mcp.getRecentJournalEntries(SupabaseService.currentUserId,
        limit: 20);
  }

  void _refresh() {
    setState(() {
      _future = _load();
      _hydrated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final entries = snapshot.data ?? [];
          _hydrateToday(entries);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              BpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Reflection',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mood,
                      decoration: const InputDecoration(
                        labelText: 'Mood',
                        prefixIcon: Icon(Icons.mood_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _content,
                      minLines: 7,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Reflection',
                        alignLabelWithHint: true,
                        hintText:
                            'How do I feel today?\nWhat went well?\nWhat went wrong?\nWhat did I learn?\nWhat will I improve tomorrow?',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _summarizing ? null : _summarize,
                          icon: _summarizing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text('AI summarize patterns'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Recent Entries',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.edit_note_outlined,
                  title: 'No reflections yet',
                  message: 'Write your first honest entry today.',
                )
              else
                for (final entry in entries) ...[
                  BpCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                compactDate(entry['date']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(entry['mood']?.toString() ?? ''),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(entry['content'].toString()),
                        if (entry['ai_summary'] != null &&
                            entry['ai_summary'].toString().isNotEmpty) ...[
                          const Divider(height: 24),
                          Text(
                            entry['ai_summary'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  void _hydrateToday(List<Map<String, dynamic>> entries) {
    if (_hydrated) return;
    final today = dateKey(DateTime.now());
    final todayEntry = entries.where((entry) => entry['date'] == today);
    if (todayEntry.isNotEmpty) {
      _mood.text = todayEntry.first['mood']?.toString() ?? '';
      _content.text = todayEntry.first['content']?.toString() ?? '';
    }
    _hydrated = true;
  }

  Future<void> _save({String? summary}) async {
    if (_content.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('journal_entries').upsert(
        {
          'user_id': SupabaseService.currentUserId,
          'date': dateKey(DateTime.now()),
          'mood': _mood.text.trim(),
          'content': _content.text.trim(),
          if (summary != null) 'ai_summary': summary,
        },
        onConflict: 'user_id,date',
      );
      _refresh();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _summarize() async {
    setState(() => _summarizing = true);
    try {
      await _save();
      final context = await _mcp.getUserContext(SupabaseService.currentUserId);
      final summary = await _ai.sendMentorMessage(
        'Summarize my journal patterns this week. Mention mood pattern, recurring lesson, and one improvement for tomorrow.',
        context,
      );
      await _save(summary: summary);
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }
}
