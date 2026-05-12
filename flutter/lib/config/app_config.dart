import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
      '';
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
      '';

  static String get aiProvider =>
      (dotenv.env['AI_PROVIDER'] ?? 'openai').trim().toLowerCase();

  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get openAiBaseUrl =>
      dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1';
  static String get openAiModel => dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini';

  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static String get openRouterModel =>
      dotenv.env['OPENROUTER_MODEL'] ?? 'openai/gpt-4o-mini';
  static String get openRouterBaseUrl =>
      dotenv.env['OPENROUTER_BASE_URL'] ?? 'https://openrouter.ai/api/v1';
  static String get openRouterSiteUrl =>
      dotenv.env['OPENROUTER_SITE_URL'] ?? 'https://project-bluepill.local';
  static String get openRouterAppName =>
      dotenv.env['OPENROUTER_APP_NAME'] ?? 'Project BluePill';

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get geminiModel =>
      dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';

  static String get googleOAuthClientId =>
      dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ??
      dotenv.env['GOOGLE_CLIENT_ID'] ??
      '';

  static bool get supabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      !supabaseAnonKey.contains('your-supabase');

  static bool get googleCalendarConfigured =>
      googleOAuthClientId.endsWith('.apps.googleusercontent.com');
  static bool get googleApisConfigured => googleCalendarConfigured;

  static bool get aiConfigured {
    if (aiProvider == 'openrouter') return openRouterApiKey.isNotEmpty;
    if (aiProvider == 'gemini') return geminiApiKey.isNotEmpty;
    return openAiApiKey.isNotEmpty;
  }
}
