import 'package:flutter/material.dart';

import '../data/profile_options.dart';
import '../models/model_helpers.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/profile_fields.dart';

const _onboardingSteps = [
  _OnboardingStepData(
    title: 'Your Basics',
    subtitle: 'Start with the details Agent should remember about you.',
    icon: Icons.badge_outlined,
  ),
  _OnboardingStepData(
    title: 'Dream Goal',
    subtitle: 'Tell BluePill what you are ultimately building toward.',
    icon: Icons.flag_outlined,
  ),
  _OnboardingStepData(
    title: 'Skills',
    subtitle: 'Choose what you already have or want to use more.',
    icon: Icons.construction_outlined,
  ),
  _OnboardingStepData(
    title: 'Interests',
    subtitle: 'Pick the themes Agent can use to personalize suggestions.',
    icon: Icons.auto_awesome_outlined,
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onCompleted,
    this.initialProfile,
  });

  final VoidCallback onCompleted;
  final Map<String, dynamic>? initialProfile;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _locationCity = TextEditingController();
  final _dreamGoal = TextEditingController();
  DateTime? _dob;
  List<String> _skills = [];
  List<String> _interests = [];
  int _step = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialProfile);
  }

  @override
  void dispose() {
    _name.dispose();
    _locationCity.dispose();
    _dreamGoal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepData = _onboardingSteps[_step];

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(stepData.icon, size: 18),
                          label: Text(
                              'Step ${_step + 1} of ${_onboardingSteps.length}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_step + 1) / _onboardingSteps.length,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      stepData.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stepData.subtitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    BpCard(
                      child: Form(
                        key: _formKey,
                        child: _buildStep(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (_step > 0)
                          OutlinedButton.icon(
                            onPressed:
                                _saving ? null : () => setState(() => _step--),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saving ? null : _continue,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_step == _onboardingSteps.length - 1
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward),
                          label: Text(_step == _onboardingSteps.length - 1
                              ? 'Enter Dashboard'
                              : 'Continue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _identityStep(),
      1 => _dreamGoalStep(),
      2 => _skillsStep(),
      _ => _interestsStep(),
    };
  }

  Widget _identityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          _name,
          'Name',
          Icons.person_outline,
          required: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        CityAutocompleteField(controller: _locationCity, required: true),
        const SizedBox(height: 14),
        DatePickerField(
          label: 'Date of birth',
          value: _dob,
          required: true,
          onChanged: (value) => setState(() => _dob = value),
        ),
      ],
    );
  }

  Widget _dreamGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _dreamGoal,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Dream goal',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Text(
          'This also becomes your main mission so Agent can connect advice to it.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _skillsStep() {
    return MultiSelectChipsField(
      label: 'Skills',
      icon: Icons.construction_outlined,
      options: skillOptions,
      selectedValues: _skills,
      required: true,
      onChanged: (values) => setState(() => _skills = values),
    );
  }

  Widget _interestsStep() {
    return MultiSelectChipsField(
      label: 'Interests',
      icon: Icons.interests_outlined,
      options: interestOptions,
      selectedValues: _interests,
      required: true,
      onChanged: (values) => setState(() => _interests = values),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      textInputAction: textInputAction,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_step < _onboardingSteps.length - 1) {
      setState(() => _step++);
      return;
    }
    _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dreamGoal = _dreamGoal.text.trim();
    try {
      await SupabaseService.client.from('users_profile').upsert(
        {
          'user_id': SupabaseService.currentUserId,
          'name': _name.text.trim(),
          'location_city': _locationCity.text.trim(),
          'dob': _dob == null ? null : dateKey(_dob!),
          'dream_goal': dreamGoal,
          'main_mission': dreamGoal,
          'skills': _skills,
          'interests': _interests,
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;
      widget.onCompleted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _hydrate(Map<String, dynamic>? profile) {
    if (profile == null) return;
    _name.text = profile['name']?.toString() ?? '';
    _locationCity.text = profile['location_city']?.toString() ?? '';
    _dreamGoal.text = profile['dream_goal']?.toString() ??
        profile['main_mission']?.toString() ??
        '';
    _dob = DateTime.tryParse(profile['dob']?.toString() ?? '');
    _skills = _stringList(profile['skills']);
    _interests = _stringList(profile['interests']);
  }
}

class _OnboardingStepData {
  const _OnboardingStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
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
