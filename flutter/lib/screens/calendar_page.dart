import 'dart:async';

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../services/google_calendar_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/expressive_loading_indicator.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with WidgetsBindingObserver {
  static const _calendarAutoRefreshInterval = Duration(minutes: 5);

  final _calendar = GoogleCalendarService();
  final _mcp = McpContextService();
  final _dateFormat = DateFormat('EEE, MMM d');
  final _timeFormat = DateFormat('h:mm a');
  final _dateTimeFormat = DateFormat('MMM d, h:mm a');
  final _monthFormat = DateFormat('MMMM yyyy');
  final _selectedDateFormat = DateFormat('EEEE, MMMM d');

  String? _accountEmail;
  List<calendar.Event> _events = [];
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _authorized = false;
  bool _initializing = true;
  bool _loadingEvents = false;
  bool _busy = false;
  String? _error;
  Timer? _calendarAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCalendar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarAutoRefreshTimer?.cancel();
    _calendar.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_calendar.isAuthorized) return;
    unawaited(_loadEvents());
  }

  Future<void> _initializeCalendar() async {
    try {
      await _calendar.initialize(
        onAuthChanged: (accountEmail, authorized) async {
          if (!mounted) return;
          setState(() {
            _accountEmail = accountEmail;
            _authorized = authorized;
            _error = null;
          });
          if (authorized) {
            _startCalendarAutoRefreshTimer();
            await _loadEvents();
          } else {
            _stopCalendarAutoRefreshTimer();
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _error = error.toString());
        },
      );
      if (!mounted) return;
      setState(() {
        _accountEmail = _calendar.accountEmail;
        _authorized = _calendar.isAuthorized;
        _initializing = false;
      });
      if (_calendar.isAuthorized) {
        _startCalendarAutoRefreshTimer();
        await _loadEvents();
      } else {
        _stopCalendarAutoRefreshTimer();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _initializing = false;
      });
    }
  }

  void _startCalendarAutoRefreshTimer() {
    _calendarAutoRefreshTimer ??= Timer.periodic(
      _calendarAutoRefreshInterval,
      (_) => unawaited(_loadEvents()),
    );
  }

  void _stopCalendarAutoRefreshTimer() {
    _calendarAutoRefreshTimer?.cancel();
    _calendarAutoRefreshTimer = null;
  }

  Future<void> _loadEvents() async {
    if (!_calendar.isAuthorized || _loadingEvents) return;
    setState(() => _loadingEvents = true);
    try {
      final events = await _calendar.listUpcomingEvents();
      await _saveCalendarContext(events);
      if (!mounted) return;
      setState(() {
        _events = events;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_calendar.isAuthorizationError(error)) {
        _calendar.clearAuthorization();
        _stopCalendarAutoRefreshTimer();
        setState(() {
          _authorized = false;
          _events = [];
          _error =
              'Google Calendar needs permission. Refresh Google access from Settings > Account.';
        });
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
          ? const Center(child: ExpressiveLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SectionTitle(
                    title: 'Google Calendar',
                    subtitle: _accountEmail ?? 'Primary calendar',
                    trailing: _authorized
                        ? FilledButton.icon(
                            onPressed: _busy ? null : () => _editEvent(),
                            icon: const Icon(Icons.add),
                            label: const Text('Event'),
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
                  else if (!_authorized)
                    _CalendarAccountCard(email: _accountEmail)
                  else ...[
                    if (_loadingEvents) const LinearProgressIndicator(),
                    if (_loadingEvents) const SizedBox(height: 16),
                    _CalendarWorkspace(
                      focusedMonth: _focusedMonth,
                      selectedDate: _selectedDate,
                      monthLabel: _monthFormat.format(_focusedMonth),
                      selectedDateLabel: _selectedDateFormat.format(
                        _selectedDate,
                      ),
                      events: _events,
                      eventStart: _eventStart,
                      eventTimeText: _formatEventTime,
                      onPreviousMonth: () => _moveMonth(-1),
                      onNextMonth: () => _moveMonth(1),
                      onToday: _goToToday,
                      onSelectDate: _selectDate,
                      onCreateEvent: () => _editEvent(),
                      onEditEvent: _editEvent,
                      onDeleteEvent: _deleteEvent,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _editEvent([calendar.Event? event]) async {
    final title = TextEditingController(text: event?.summary ?? '');
    final description = TextEditingController(
      text: event?.description?.toString() ?? '',
    );
    final location = TextEditingController(
      text: event?.location?.toString() ?? '',
    );
    final attendees = TextEditingController(
      text:
          event?.attendees
              ?.map((attendee) => attendee.email)
              .whereType<String>()
              .join(', ') ??
          '',
    );

    final defaultStart = _defaultEventStart();
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
                              onPressed: saving
                                  ? null
                                  : () => pickDateTime(true),
                              icon: const Icon(Icons.play_arrow_outlined),
                              label: Text(_formatDraftDateTime(start)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => pickDateTime(false),
                              icon: const Icon(Icons.stop_outlined),
                              label: Text(_formatDraftDateTime(end)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: location,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
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
                          final parsedAttendees = _parseAttendees(
                            attendees.text,
                          );
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
                          child: ExpressiveLoadingIndicator(strokeWidth: 2),
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

  void _moveMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + offset,
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _focusedMonth = DateTime(now.year, now.month);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _focusedMonth = DateTime(date.year, date.month);
    });
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

  DateTime _defaultEventStart() {
    final today = DateTime.now();
    if (_sameDate(_selectedDate, today)) {
      return _nextWholeHour();
    }
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      9,
    );
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

  Future<void> _saveCalendarContext(List<calendar.Event> events) async {
    final email = _calendar.accountEmail?.trim();
    if (email == null || email.isEmpty || !_calendar.isAuthorized) return;

    await _mcp.saveGoogleCalendarConnection(
      userId: SupabaseService.currentUserId,
      email: email,
      scopes: GoogleCalendarService.calendarScopes,
      upcomingEvents: events.map(_eventSummary).toList(growable: false),
    );
  }

  Map<String, dynamic> _eventSummary(calendar.Event event) {
    final start = _eventStart(event);
    final end = _eventEnd(event);
    return {
      'id': event.id,
      'title': event.summary ?? 'Untitled event',
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'time_text': _formatEventTime(event),
      if ((event.location ?? '').trim().isNotEmpty) 'location': event.location,
      if ((event.description ?? '').trim().isNotEmpty)
        'description': event.description,
      if ((event.attendees ?? []).isNotEmpty)
        'attendees': event.attendees
            ?.map((attendee) => attendee.email)
            .whereType<String>()
            .toList(growable: false),
    };
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

class _CalendarAccountCard extends StatelessWidget {
  const _CalendarAccountCard({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final linkedEmail = email?.trim();
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available_outlined),
              SizedBox(width: 8),
              Text(
                'Calendar account',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (linkedEmail != null && linkedEmail.isNotEmpty) ...[
            Text(
              linkedEmail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
          ],
          const Text('Manage Google connection from Settings > Account.'),
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
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
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

class _CalendarWorkspace extends StatelessWidget {
  const _CalendarWorkspace({
    required this.focusedMonth,
    required this.selectedDate,
    required this.monthLabel,
    required this.selectedDateLabel,
    required this.events,
    required this.eventStart,
    required this.eventTimeText,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onSelectDate,
    required this.onCreateEvent,
    required this.onEditEvent,
    required this.onDeleteEvent,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final String monthLabel;
  final String selectedDateLabel;
  final List<calendar.Event> events;
  final DateTime? Function(calendar.Event event) eventStart;
  final String Function(calendar.Event event) eventTimeText;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onCreateEvent;
  final ValueChanged<calendar.Event> onEditEvent;
  final ValueChanged<calendar.Event> onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    final selectedEvents =
        events.where((event) {
          final start = eventStart(event);
          return start != null && _sameDay(start, selectedDate);
        }).toList()..sort((a, b) {
          final aStart = eventStart(a);
          final bStart = eventStart(b);
          if (aStart == null || bStart == null) return 0;
          return aStart.compareTo(bStart);
        });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final calendarView = _CalendarMonthView(
          focusedMonth: focusedMonth,
          selectedDate: selectedDate,
          monthLabel: monthLabel,
          events: events,
          eventStart: eventStart,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onToday: onToday,
          onSelectDate: onSelectDate,
        );
        final agenda = _SelectedDayAgenda(
          selectedDateLabel: selectedDateLabel,
          events: selectedEvents,
          eventTimeText: eventTimeText,
          onCreateEvent: onCreateEvent,
          onEditEvent: onEditEvent,
          onDeleteEvent: onDeleteEvent,
        );

        if (!wide) {
          return Column(
            children: [calendarView, const SizedBox(height: 16), agenda],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: calendarView),
            const SizedBox(width: 16),
            SizedBox(width: 360, child: agenda),
          ],
        );
      },
    );
  }
}

class _CalendarMonthView extends StatelessWidget {
  const _CalendarMonthView({
    required this.focusedMonth,
    required this.selectedDate,
    required this.monthLabel,
    required this.events,
    required this.eventStart,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onSelectDate,
  });

  static const _weekdayLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final String monthLabel;
  final List<calendar.Event> events;
  final DateTime? Function(calendar.Event event) eventStart;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = _visibleDaysForMonth(focusedMonth);

    return BpCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton(onPressed: onToday, child: const Text('Today')),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            childAspectRatio: 3.4,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              for (final day in _weekdayLabels)
                Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          GridView.builder(
            itemCount: days.length,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.98,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final dayEvents = events.where((event) {
                final start = eventStart(event);
                return start != null && _sameDay(start, day);
              }).toList();
              return _CalendarDayCell(
                date: day,
                inFocusedMonth: day.month == focusedMonth.month,
                selected: _sameDay(day, selectedDate),
                today: _sameDay(day, DateTime.now()),
                events: dayEvents,
                onTap: () => onSelectDate(day),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DateTime> _visibleDaysForMonth(DateTime month) {
    final first = DateTime(month.year, month.month);
    final firstVisible = first.subtract(Duration(days: first.weekday % 7));
    return [
      for (var index = 0; index < 42; index++)
        DateTime(
          firstVisible.year,
          firstVisible.month,
          firstVisible.day + index,
        ),
    ];
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.inFocusedMonth,
    required this.selected,
    required this.today,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final bool inFocusedMonth;
  final bool selected;
  final bool today;
  final List<calendar.Event> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hiddenCount = events.length - 2;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.78)
                : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : Theme.of(context).dividerColor.withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: today ? colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: today
                            ? colorScheme.onPrimary
                            : inFocusedMonth
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.58,
                              ),
                        fontWeight: today || selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                for (final event in events.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _EventPill(title: event.summary ?? 'Untitled event'),
                  ),
                if (hiddenCount > 0)
                  Text(
                    '+$hiddenCount more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  const _EventPill({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title.trim().isEmpty ? 'Untitled event' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SelectedDayAgenda extends StatelessWidget {
  const _SelectedDayAgenda({
    required this.selectedDateLabel,
    required this.events,
    required this.eventTimeText,
    required this.onCreateEvent,
    required this.onEditEvent,
    required this.onDeleteEvent,
  });

  final String selectedDateLabel;
  final List<calendar.Event> events;
  final String Function(calendar.Event event) eventTimeText;
  final VoidCallback onCreateEvent;
  final ValueChanged<calendar.Event> onEditEvent;
  final ValueChanged<calendar.Event> onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    return BpCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedDateLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Add event',
                onPressed: onCreateEvent,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No events',
                message: 'Add an event for this date.',
              ),
            )
          else
            for (final event in events) ...[
              _EventCard(
                event: event,
                timeText: eventTimeText(event),
                onEdit: event.id == null ? null : () => onEditEvent(event),
                onDelete: event.id == null ? null : () => onDeleteEvent(event),
              ),
              const SizedBox(height: 10),
            ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.65),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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
