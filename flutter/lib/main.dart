import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // The app can still open and show setup instructions.
  }

  if (AppConfig.supabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  await ThemeController.instance.load();
  runApp(const ProjectBluePillApp());
}

class ProjectBluePillApp extends StatelessWidget {
  const ProjectBluePillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BluePillThemeChoice>(
      valueListenable: ThemeController.instance,
      builder: (context, themeChoice, _) {
        return MaterialApp(
          title: 'Project BluePill',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: const Duration(milliseconds: 450),
          themeAnimationCurve: Easing.emphasizedDecelerate,
          theme: themeChoice == BluePillThemeChoice.light
              ? AppTheme.blueWhite()
              : AppTheme.blueBlack(),
          home: const AuthGate(),
        );
      },
    );
  }
}
