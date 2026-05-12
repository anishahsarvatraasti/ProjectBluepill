import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget platformGoogleCalendarSignInButton({
  required VoidCallback onPressed,
  required String label,
}) {
  return google_web.renderButton(
    configuration: google_web.GSIButtonConfiguration(
      size: google_web.GSIButtonSize.large,
      text: google_web.GSIButtonText.continueWith,
      theme: google_web.GSIButtonTheme.filledBlue,
      type: google_web.GSIButtonType.standard,
      minimumWidth: 260,
    ),
  );
}
