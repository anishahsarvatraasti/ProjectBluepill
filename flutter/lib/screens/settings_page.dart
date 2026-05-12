import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/profile_options.dart';
import '../models/model_helpers.dart';
import '../services/supabase_service.dart';
import '../theme/theme_controller.dart';
import '../ui/bp_card.dart';
import '../ui/expressive_loading_indicator.dart';
import '../ui/profile_fields.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _name = TextEditingController();
  final _locationCity = TextEditingController();
  final _dreamGoal = TextEditingController();
  final _role = TextEditingController();
  final _yearlyGoal = TextEditingController();
  final _struggle = TextEditingController();
  DateTime? _dob;
  String _educationStatus = 'student';
  List<String> _skills = [];
  List<String> _interests = [];
  String _motivationStyle = 'friendly';
  late Future<Map<String, dynamic>?> _future;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _locationCity.dispose();
    _dreamGoal.dispose();
    _role.dispose();
    _yearlyGoal.dispose();
    _struggle.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _load() async {
    final data = await SupabaseService.client
        .from('users_profile')
        .select()
        .eq('user_id', SupabaseService.currentUserId)
        .maybeSingle();
    return maybeRow(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ExpressiveLoadingIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          _hydrate(snapshot.data);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              BpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      icon: Icons.account_circle_outlined,
                      title: 'Account',
                    ),
                    const SizedBox(height: 14),
                    _AccountRow(
                      label: 'Email',
                      value: SupabaseService.currentUser?.email ?? 'Unknown',
                    ),
                    _AccountRow(
                      label: 'User ID',
                      value: SupabaseService.currentUserId,
                      mono: true,
                    ),
                    const SizedBox(height: 12),
                    _StatusRow(
                      label: 'Supabase',
                      enabled: AppConfig.supabaseConfigured,
                    ),
                    _StatusRow(
                      label: 'AI provider',
                      enabled: AppConfig.aiConfigured,
                    ),
                    Text('Provider: ${AppConfig.aiProvider}'),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => SupabaseService.client.auth.signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      icon: Icons.badge_outlined,
                      title: 'Details',
                    ),
                    const SizedBox(height: 14),
                    _field(_name, 'Name'),
                    CityAutocompleteField(controller: _locationCity),
                    const SizedBox(height: 12),
                    DatePickerField(
                      label: 'Date of birth',
                      value: _dob,
                      onChanged: (value) => setState(() => _dob = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _educationStatus,
                      decoration: const InputDecoration(
                        labelText: 'Education',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        for (final status in educationStatuses)
                          DropdownMenuItem(
                            value: status,
                            child: Text(educationLabel(status)),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _educationStatus = value ?? _educationStatus,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(_dreamGoal, 'Dream goal', lines: 3),
                    const SizedBox(height: 12),
                    MultiSelectChipsField(
                      label: 'Skills',
                      icon: Icons.construction_outlined,
                      options: skillOptions,
                      selectedValues: _skills,
                      onChanged: (values) => setState(() => _skills = values),
                    ),
                    const SizedBox(height: 16),
                    MultiSelectChipsField(
                      label: 'Interests',
                      icon: Icons.interests_outlined,
                      options: interestOptions,
                      selectedValues: _interests,
                      onChanged: (values) =>
                          setState(() => _interests = values),
                    ),
                    const SizedBox(height: 16),
                    _field(_role, 'Current role'),
                    _field(_yearlyGoal, 'Main goal this year'),
                    _field(_struggle, 'Main struggle', lines: 2),
                    DropdownButtonFormField<String>(
                      initialValue: _motivationStyle,
                      decoration: const InputDecoration(
                        labelText: 'Motivation style',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'soft', child: Text('Soft')),
                        DropdownMenuItem(
                            value: 'strict', child: Text('Strict')),
                        DropdownMenuItem(
                          value: 'friendly',
                          child: Text('Friendly'),
                        ),
                        DropdownMenuItem(
                          value: 'business mentor',
                          child: Text('Business mentor'),
                        ),
                        DropdownMenuItem(
                          value: 'military discipline',
                          child: Text('Military discipline'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _motivationStyle = value ?? _motivationStyle,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: ExpressiveLoadingIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save settings'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      icon: Icons.palette_outlined,
                      title: 'Theme',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Default is Dark. Switch to Light when you want a brighter dashboard.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<BluePillThemeChoice>(
                      valueListenable: ThemeController.instance,
                      builder: (context, selectedTheme, _) {
                        return SegmentedButton<BluePillThemeChoice>(
                          segments: const [
                            ButtonSegment(
                              value: BluePillThemeChoice.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: BluePillThemeChoice.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                          ],
                          selected: {selectedTheme},
                          onSelectionChanged: (selection) {
                            ThemeController.instance.setTheme(selection.single);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  void _hydrate(Map<String, dynamic>? profile) {
    if (_hydrated || profile == null) return;
    _name.text = profile['name']?.toString() ?? '';
    _locationCity.text = profile['location_city']?.toString() ?? '';
    _dreamGoal.text = profile['dream_goal']?.toString() ??
        profile['main_mission']?.toString() ??
        '';
    _dob = DateTime.tryParse(profile['dob']?.toString() ?? '');
    final education = profile['education_status']?.toString();
    if (education != null && educationStatuses.contains(education)) {
      _educationStatus = education;
    }
    _skills = _stringList(profile['skills']);
    _interests = _stringList(profile['interests']);
    _role.text = profile['current_role']?.toString() ?? '';
    _yearlyGoal.text = profile['yearly_goal']?.toString() ?? '';
    _struggle.text = profile['main_struggle']?.toString() ?? '';
    _motivationStyle = profile['motivation_style']?.toString() ?? 'friendly';
    _hydrated = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dreamGoal = _dreamGoal.text.trim();
      await SupabaseService.client.from('users_profile').update({
        'name': _name.text.trim(),
        'location_city': _locationCity.text.trim(),
        'dob': _dob == null ? null : dateKey(_dob!),
        'education_status': _educationStatus,
        'dream_goal': dreamGoal,
        'main_mission': dreamGoal,
        'skills': _skills,
        'interests': _interests,
        'current_role': _role.text.trim(),
        'yearly_goal': _yearlyGoal.text.trim(),
        'main_struggle': _struggle.text.trim(),
        'motivation_style': _motivationStyle,
      }).eq('user_id', SupabaseService.currentUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.error_outline,
            color: enabled ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text('$label: ${enabled ? 'configured' : 'not configured'}'),
        ],
      ),
    );
  }
}
