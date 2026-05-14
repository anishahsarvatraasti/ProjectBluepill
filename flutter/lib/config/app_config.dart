import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const _googleOAuthClientIdDefine = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
  );
  static const _authRedirectOriginDefine = String.fromEnvironment(
    'AUTH_REDIRECT_ORIGIN',
  );
  static const _fastApiBaseUrlDefine = String.fromEnvironment(
    'FASTAPI_BASE_URL',
  );

  static String get supabaseUrl => _firstNonEmpty([
    dotenv.env['SUPABASE_URL'],
    dotenv.env['NEXT_PUBLIC_SUPABASE_URL'],
    _supabaseUrlDefine,
  ]);
  static String get supabaseAnonKey => _firstNonEmpty([
    dotenv.env['SUPABASE_ANON_KEY'],
    dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'],
    _supabaseAnonKeyDefine,
  ]);

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

  static String get googleOAuthClientId => _firstNonEmpty([
    dotenv.env['GOOGLE_OAUTH_CLIENT_ID'],
    dotenv.env['GOOGLE_CLIENT_ID'],
    _googleOAuthClientIdDefine,
  ]);

  static String get authRedirectOrigin => _firstNonEmpty([
    dotenv.env['AUTH_REDIRECT_ORIGIN'],
    dotenv.env['APP_ORIGIN'],
    _authRedirectOriginDefine,
  ]);

  static String get fastApiBaseUrl => _firstNonEmpty([
    dotenv.env['FASTAPI_BASE_URL'],
    dotenv.env['WORKER_BASE_URL'],
    _fastApiBaseUrlDefine,
  ]);

  static String authRedirectUrl(Uri currentUri) {
    final configured = _normalizedOrigin(authRedirectOrigin);
    if (configured.isNotEmpty) return configured;
    return _withTrailingSlash(currentUri.origin);
  }

  static bool get supabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      !supabaseAnonKey.contains('your-supabase');

  static bool get googleCalendarConfigured =>
      googleOAuthClientId.endsWith('.apps.googleusercontent.com');
  static bool get googleApisConfigured => googleCalendarConfigured;
  static bool get fastApiConfigured =>
      fastApiBaseUrl.startsWith('http://') ||
      fastApiBaseUrl.startsWith('https://');

  static bool get aiConfigured {
    if (aiProvider == 'openrouter') return openRouterApiKey.isNotEmpty;
    if (aiProvider == 'gemini') return geminiApiKey.isNotEmpty;
    return openAiApiKey.isNotEmpty;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _normalizedOrigin(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return _withTrailingSlash(trimmed);
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/',
    ).toString();
  }

  static String _withTrailingSlash(String value) =>
      value.endsWith('/') ? value : '$value/';
}
