import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../services/google_calendar_service.dart';
import '../ui/bp_card.dart';
import '../ui/google_calendar_sign_in_button.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _calendar = GoogleCalendarService();
  final _dateFormat = DateFormat('EEE, MMM d');
  final _timeFormat = DateFormat('h:mm a');
  final _dateTimeFormat = DateFormat('MMM d, h:mm a');

  GoogleSignInAccount? _user;
  List<calendar.Event> _events = [];
  bool _authorized = false;
  bool _initializing = true;
  bool _loadingEvents = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCalendar();
  }

  @override
  void dispose() {
    _calendar.dispose();
    super.dispose();
  }

  Future<void> _initializeCalendar() async {
    try {
      await _calendar.initialize(
        onAuthChanged: (user, authorized) async {
          if (!mounted) return;
          setState(() {
            _user = user;
            _authorized = authorized;
            _error = null;
          });
          if (authorized) {
            await _loadEvents();
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _error = error.toString());
        },
      );
      if (!mounted) return;
      setState(() {
        _user = _calendar.currentUser;
        _authorized = _calendar.isAuthorized;
        _initializing = false;
      });
      if (_calendar.isAuthorized) {
        await _loadEvents();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _connectAndAuthorize() async {
    await _runBusyAction(() async {
      await _calendar.signInAndAuthorize();
      setState(() {
        _user = _calendar.currentUser;
        _authorized = _calendar.isAuthorized;
      });
      await _loadEvents();
    });
  }

  Future<void> _authorizeCalendar() async {
    await _runBusyAction(() async {
      await _calendar.authorizeCalendar();
      setState(() => _authorized = _calendar.isAuthorized);
      await _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    if (!_calendar.isAuthorized) return;
    setState(() => _loadingEvents = true);
    try {
      final events = await _calendar.listUpcomingEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _disconnect() async {
    await _runBusyAction(() async {
      await _calendar.disconnect();
      setState(() {
        _user = null;
        _authorized = false;
        _events = [];
      });
    });
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          if (_authorized)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadingEvents ? null : _loadEvents,
              icon: const Icon(Icons.refresh),
            ),
          if (_authorized)
            IconButton(
              tooltip: 'Add event',
              onPressed: _busy ? null : () => _editEvent(),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SectionTitle(
                    title: 'Google Calendar',
                    subtitle: _user?.email ?? 'Primary calendar',
                    trailing: _authorized
                        ? Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _disconnect,
                                icon: const Icon(Icons.link_off),
                                label: const Text('Disconnect'),
                              ),
                              FilledButton.icon(
                                onPressed: _busy ? null : () => _editEvent(),
                                icon: const Icon(Icons.add),
                                label: const Text('Event'),
                              ),
                            ],
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    _ErrorCard(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  if (!AppConfig.googleCalendarConfigured)
                    const _SetupCard()
                  else if (_user == null)
                    _ConnectCard(
                      busy: _busy,
                      onConnect: _connectAndAuthorize,
                    )
                  else if (!_authorized)
                    _AuthorizeCard(
                      busy: _busy,
                      email: _user!.email,
                      onAuthorize: _authorizeCalendar,
                      onDisconnect: _disconnect,
                    )
                  else ...[
                    if (_loadingEvents) const LinearProgressIndicator(),
                    if (_loadingEvents) const SizedBox(height: 16),
                    if (_events.isEmpty)
                      const SizedBox(
                        height: 280,
                        child: EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'No upcoming events',
                          message: 'Create a scheduled event to start.',
                        ),
                      )
                    else
                      for (final event in _events) ...[
                        _EventCard(
                          event: event,
                          timeText: _formatEventTime(event),
                          onEdit:
                              event.id == null ? null : () => _editEvent(event),
                          onDelete: event.id == null
                              ? null
                              : () => _deleteEvent(event),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _editEvent([calendar.Event? event]) async {
    final title = TextEditingController(text: event?.summary ?? '');
    final description =
        TextEditingController(text: event?.description?.toString() ?? '');
    final location =
        TextEditingController(text: event?.location?.toString() ?? '');
    final attendees = TextEditingController(
      text: event?.attendees
              ?.map((attendee) => attendee.email)
              .whereType<String>()
              .join(', ') ??
          '',
    );

    final defaultStart = _nextWholeHour();
    var start = _eventStart(event) ?? defaultStart;
    var end = _eventEnd(event) ?? defaultStart.add(const Duration(hours: 1));
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    var saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickDateTime(bool pickingStart) async {
              final current = pickingStart ? start : end;
              final pickedDate = await showDatePicker(
                context: dialogContext,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: current,
              );
              if (pickedDate == null || !dialogContext.mounted) return;
              final pickedTime = await showTimePicker(
                context: dialogContext,
                initialTime: TimeOfDay.fromDateTime(current),
              );
              if (pickedTime == null) return;
              final picked = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              setDialogState(() {
                if (pickingStart) {
                  final duration = end.difference(start);
                  start = picked;
                  end = start.add(
                    duration.isNegative || duration == Duration.zero
                        ? const Duration(hours: 1)
                        : duration,
                  );
                } else {
                  end = picked;
                }
              });
            }

            return AlertDialog(
              title: Text(event == null ? 'Add event' : 'Edit event'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorText != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  saving ? null : () => pickDateTime(true),
                              icon: const Icon(Icons.play_arrow_outlined),
                              label: Text(_formatDraftDateTime(start)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  saving ? null : () => pickDateTime(false),
                              icon: const Icon(Icons.stop_outlined),
                              label: Text(_formatDraftDateTime(end)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: location,
                        decoration:
                            const InputDecoration(labelText: 'Location'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: attendees,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Attendees',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: description,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final parsedAttendees =
                              _parseAttendees(attendees.text);
                          if (title.text.trim().isEmpty) {
                            setDialogState(
                              () => errorText = 'Event title is required.',
                            );
                            return;
                          }
                          if (!end.isAfter(start)) {
                            setDialogState(
                              () => errorText =
                                  'End time must be after start time.',
                            );
                            return;
                          }
                          if (parsedAttendees.any(
                            (email) => !email.contains('@'),
                          )) {
                            setDialogState(
                              () => errorText =
                                  'Attendees must be valid email addresses.',
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            errorText = null;
                          });

                          final draft = CalendarEventDraft(
                            title: title.text.trim(),
                            description: description.text.trim(),
                            location: location.text.trim(),
                            attendees: parsedAttendees,
                            start: start,
                            end: end,
                          );

                          try {
                            final eventId = event?.id;
                            if (eventId == null) {
                              await _calendar.createEvent(draft);
                            } else {
                              await _calendar.updateEvent(eventId, draft);
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            await _loadEvents();
                          } catch (error) {
                            setDialogState(() {
                              saving = false;
                              errorText = error.toString();
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    description.dispose();
    location.dispose();
    attendees.dispose();
  }

  Future<void> _deleteEvent(calendar.Event event) async {
    final eventId = event.id;
    if (eventId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event'),
        content: Text(event.summary ?? 'Untitled event'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusyAction(() async {
      await _calendar.deleteEvent(eventId);
      await _loadEvents();
    });
  }

  String _formatEventTime(calendar.Event event) {
    final start = _eventStart(event);
    final end = _eventEnd(event);
    if (start == null) return 'No time';
    if (end == null) return _dateTimeFormat.format(start);
    if (_sameDate(start, end)) {
      return '${_dateFormat.format(start)} • ${_timeFormat.format(start)} - ${_timeFormat.format(end)}';
    }
    return '${_dateTimeFormat.format(start)} - ${_dateTimeFormat.format(end)}';
  }

  String _formatDraftDateTime(DateTime value) {
    return _dateTimeFormat.format(value);
  }

  DateTime? _eventStart(calendar.Event? event) {
    final start = event?.start;
    return start?.dateTime?.toLocal() ?? start?.date?.toLocal();
  }

  DateTime? _eventEnd(calendar.Event? event) {
    final end = event?.end;
    return end?.dateTime?.toLocal() ?? end?.date?.toLocal();
  }

  DateTime _nextWholeHour() {
    final next = DateTime.now().add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour);
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<String> _parseAttendees(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return const BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: 8),
              Text(
                'Calendar setup needed',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text('Add GOOGLE_OAUTH_CLIENT_ID to .env and enable Calendar API.'),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.busy,
    required this.onConnect,
  });

  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available_outlined),
              SizedBox(width: 8),
              Text(
                'Connect calendar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (kIsWeb)
            googleCalendarSignInButton(onPressed: onConnect)
          else
            FilledButton.icon(
              onPressed: busy ? null : onConnect,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: const Text('Connect Google Calendar'),
            ),
        ],
      ),
    );
  }
}

class _AuthorizeCard extends StatelessWidget {
  const _AuthorizeCard({
    required this.busy,
    required this.email,
    required this.onAuthorize,
    required this.onDisconnect,
  });

  final bool busy;
  final String email;
  final VoidCallback onAuthorize;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onAuthorize,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: const Text('Allow calendar access'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onDisconnect,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BpCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.timeText,
    required this.onEdit,
    required this.onDelete,
  });

  final calendar.Event event;
  final String timeText;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final attendeeCount = event.attendees?.length ?? 0;
    return BpCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: Text(
          event.summary?.trim().isEmpty ?? true
              ? 'Untitled event'
              : event.summary!,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _EventChip(text: timeText),
              if (event.location?.trim().isNotEmpty == true)
                _EventChip(text: event.location!),
              if (attendeeCount > 0)
                _EventChip(text: '$attendeeCount attendees'),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit?.call();
            if (value == 'delete') onDelete?.call();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              enabled: onEdit != null,
              child: const Text('Edit'),
            ),
            PopupMenuItem(
              value: 'delete',
              enabled: onDelete != null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
