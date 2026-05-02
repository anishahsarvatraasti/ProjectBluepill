import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

class GoogleApiAuthService {
  GoogleApiAuthService._();

  static final GoogleSignIn signIn = GoogleSignIn.instance;
  static Future<void>? _initializeFuture;

  static Future<void> initialize() async {
    if (kIsWeb && !AppConfig.googleCalendarConfigured) {
      throw StateError('Missing GOOGLE_OAUTH_CLIENT_ID for Google APIs.');
    }

    _initializeFuture ??= signIn.initialize(
      clientId: AppConfig.googleOAuthClientId.isEmpty
          ? null
          : AppConfig.googleOAuthClientId,
    );
    await _initializeFuture;
  }
}
