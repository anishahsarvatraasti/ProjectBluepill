import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as google_auth;

import 'google_api_auth_service.dart';

typedef CalendarAuthChanged = FutureOr<void> Function(
  GoogleSignInAccount? user,
  bool authorized,
);

class GoogleCalendarService {
  GoogleCalendarService();

  static const List<String> calendarScopes = [
    CalendarApi.calendarEventsScope,
  ];

  final GoogleSignIn _signIn = GoogleApiAuthService.signIn;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;
  google_auth.AuthClient? _authClient;
  CalendarApi? _calendarApi;

  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isAuthorized => _authorization != null;

  Future<void> initialize({
    required CalendarAuthChanged onAuthChanged,
    required void Function(Object error) onError,
  }) async {
    await GoogleApiAuthService.initialize();

    await _authSubscription?.cancel();
    _authSubscription = _signIn.authenticationEvents.listen((event) async {
      try {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            await _setUser(event.user);
          case GoogleSignInAuthenticationEventSignOut():
            _clearAuthClient();
            _currentUser = null;
            _authorization = null;
        }
        await onAuthChanged(_currentUser, isAuthorized);
      } catch (error) {
        onError(error);
      }
    }, onError: onError);

    final lightweight = _signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      final user = await lightweight;
      if (user != null) {
        await _setUser(user);
        await onAuthChanged(_currentUser, isAuthorized);
      }
    }
  }

  Future<void> signInAndAuthorize() async {
    GoogleSignInAccount? user = _currentUser;
    if (user == null) {
      if (!_signIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Use the Google sign-in button before authorizing Calendar.',
        );
      }
      user = await _signIn.authenticate(scopeHint: calendarScopes);
      await _setUser(user);
    }
    await authorizeCalendar();
  }

  Future<void> authorizeCalendar() async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Connect a Google account first.');
    }
    final authorization =
        await user.authorizationClient.authorizeScopes(calendarScopes);
    _setAuthorization(authorization);
  }

  Future<List<Event>> listUpcomingEvents({
    int days = 30,
    int maxResults = 50,
  }) async {
    final api = _requireApi();
    final now = DateTime.now();
    final timeMin = DateTime(now.year, now.month, now.day);
    final timeMax = timeMin.add(Duration(days: days));
    final result = await api.events.list(
      'primary',
      maxResults: maxResults,
      orderBy: 'startTime',
      showDeleted: false,
      singleEvents: true,
      timeMin: timeMin,
      timeMax: timeMax,
    );
    return (result.items ?? [])
        .where((event) => event.status != 'cancelled')
        .toList(growable: false);
  }

  Future<Event> createEvent(CalendarEventDraft draft) async {
    final api = _requireApi();
    return api.events.insert(
      _eventFromDraft(draft),
      'primary',
      sendUpdates: draft.attendees.isEmpty ? 'none' : 'all',
    );
  }

  Future<Event> updateEvent(String eventId, CalendarEventDraft draft) async {
    final api = _requireApi();
    return api.events.patch(
      _eventFromDraft(draft),
      'primary',
      eventId,
      sendUpdates: draft.attendees.isEmpty ? 'none' : 'all',
    );
  }

  Future<void> deleteEvent(String eventId) async {
    final api = _requireApi();
    await api.events.delete('primary', eventId, sendUpdates: 'all');
  }

  Future<void> disconnect() async {
    await _signIn.disconnect();
    _clearAuthClient();
    _currentUser = null;
    _authorization = null;
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _clearAuthClient();
  }

  Future<void> _setUser(GoogleSignInAccount user) async {
    _currentUser = user;
    final authorization =
        await user.authorizationClient.authorizationForScopes(calendarScopes);
    if (authorization == null) {
      _clearAuthClient();
      _authorization = null;
      return;
    }
    _setAuthorization(authorization);
  }

  void _setAuthorization(GoogleSignInClientAuthorization authorization) {
    _clearAuthClient();
    _authorization = authorization;
    _authClient = authorization.authClient(scopes: calendarScopes);
    _calendarApi = CalendarApi(_authClient!);
  }

  void _clearAuthClient() {
    _authClient?.close();
    _authClient = null;
    _calendarApi = null;
  }

  CalendarApi _requireApi() {
    final api = _calendarApi;
    if (api == null) {
      throw StateError('Authorize Google Calendar access first.');
    }
    return api;
  }

  Event _eventFromDraft(CalendarEventDraft draft) {
    return Event(
      summary: draft.title,
      description: draft.description.isEmpty ? null : draft.description,
      location: draft.location.isEmpty ? null : draft.location,
      start: EventDateTime(dateTime: draft.start),
      end: EventDateTime(dateTime: draft.end),
      attendees: draft.attendees
          .map((email) => EventAttendee(email: email))
          .toList(growable: false),
    );
  }
}

class CalendarEventDraft {
  const CalendarEventDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.attendees,
    required this.start,
    required this.end,
  });

  final String title;
  final String description;
  final String location;
  final List<String> attendees;
  final DateTime start;
  final DateTime end;
}
