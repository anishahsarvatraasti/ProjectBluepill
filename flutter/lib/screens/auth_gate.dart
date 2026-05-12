import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/model_helpers.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/project_logo.dart';
import 'auth_page.dart';
import 'main_shell.dart';
import 'onboarding_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _profileReload = 0;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.supabaseConfigured) {
      return const SetupRequiredPage();
    }

    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = SupabaseService.currentUser;
        if (user == null) return const AuthPage();

        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(_profileReload),
          future: _loadProfile(user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = profileSnapshot.data;
            if (_needsOnboarding(profile)) {
              return OnboardingPage(
                initialProfile: profile,
                onCompleted: () => setState(() => _profileReload++),
              );
            }
            return const MainShell();
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    final response = await SupabaseService.client
        .from('users_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return maybeRow(response);
  }

  bool _needsOnboarding(Map<String, dynamic>? profile) {
    if (profile == null) return true;
    final dreamGoal = profile['dream_goal'] ?? profile['main_mission'];
    final requiredText = [
      profile['name'],
      profile['location_city'],
      profile['dob'],
      dreamGoal,
    ];
    if (requiredText
        .any((value) => value == null || value.toString().trim().isEmpty)) {
      return true;
    }
    return _stringList(profile['skills']).isEmpty ||
        _stringList(profile['interests']).isEmpty;
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

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BpCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProjectLogo(size: 72),
                  const SizedBox(height: 18),
                  Text(
                    'Project BluePill needs Supabase credentials',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Edit flutter/.env with SUPABASE_URL and SUPABASE_ANON_KEY, run the SQL in supabase/schema.sql, then restart the app.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const SelectableText(
                      'cd flutter\ncp .env.example .env\nflutter pub get\nflutter run -d chrome',
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
