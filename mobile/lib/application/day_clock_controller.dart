import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../domain/calendar_data.dart';
import '../domain/calendar_event_creation.dart';
import '../domain/day_clock.dart';
import 'calendar_agenda_controller.dart';
import 'calendar_read_controller.dart';
import 'calendar_event_creation_ports.dart';
import 'calendar_event_creation_controller.dart';
import 'focus_block_ports.dart';

DateTime _deviceLocal(DateTime value) => value.toLocal();

enum DayClockDisplayState {
  unavailable,
  hidden,
  refreshing,
  refreshNeeded,
  outsideCoverage,
  inaccessible,
  missing,
  available,
  selected,
}

class DayClockController extends ChangeNotifier
    implements CalendarEventCreationController {
  DayClockController({
    required this.reader,
    required this.agenda,
    this.time,
    this.localize = _deviceLocal,
    this.unlocked = false,
  }) {
    _storageRevision = reader.connection.storageRevision;
    reader.addListener(_changed);
    agenda.addListener(_formatted);
    _sync();
  }
  final CalendarReadController reader;
  final CalendarAgendaController agenda;
  final DateTime Function(DateTime) localize;
  FocusTimeResolver? time;
  bool followingNow = true;
  bool unlocked, _disposed = false;
  int _storageRevision = 0;
  CalendarDate? _date;
  DayClockHalf? _half;
  String? selectedIdentity, _windowKey;
  DayClockWindow? _window;
  Map<String, int> _lanes = {};
  late DayClockProjection projection;
  @override
  CalendarEventDraft? draft;
  String? draftAccountLabel;
  @override
  CalendarCreationState creationState = CalendarCreationState.draft;
  @override
  CalendarCreateIntent? review;
  Map<String, String> errors = {};
  String? validationMessage;
  String overlapMessage = 'Availability unknown until the times are checked.';
  final Map<String, String> _destinations = {};
  int _validation = 0;
  CalendarCreationController? creation;
  String? _restoredCreationAccount;
  String? _creationAuthority;
  int _viewRevision = 0, _revealToken = 0;
  int revealRevision = 0;
  String? _receiptId, _revealingId;
  Future<bool>? _revealing;
  bool get revealing => _revealing != null;

  CalendarCreateOperation? _savedOperation(CalendarCreateOperation op) {
    final current = creation?.journal?.operations[op.operationId];
    return !_disposed &&
            unlocked &&
            op.intent.accountKey == reader.connection.verifiedAccountKey &&
            creation?.journal?.accountKey == op.intent.accountKey &&
            current?.state == CalendarCreationState.saved &&
            current?.event != null &&
            current?.eventId == op.eventId &&
            current?.intent.hash == op.intent.hash &&
            current?.intent.calendarId == op.intent.calendarId
        ? current
        : null;
  }

  CalendarCreateOperation? get savedReceipt {
    final journal = creation?.journal;
    if (!unlocked ||
        journal == null ||
        journal.accountKey != reader.connection.verifiedAccountKey) {
      return null;
    }
    final saved =
        journal.operations.values
            .where(
              (op) =>
                  op.state == CalendarCreationState.saved && op.event != null,
            )
            .toList()
          ..sort((a, b) {
            final time = (b.transitionAt ?? b.confirmedAt ?? DateTime.utc(1970))
                .compareTo(
                  a.transitionAt ?? a.confirmedAt ?? DateTime.utc(1970),
                );
            return time != 0 ? time : b.operationId.compareTo(a.operationId);
          });
    return saved.where((op) => op.operationId == _receiptId).firstOrNull ??
        saved.firstOrNull;
  }

  CalendarEvent? savedReaderEvent(CalendarCreateOperation op) =>
      _savedOperation(op) == null || reader.accountKey != op.intent.accountKey
      ? null
      : reader.events
            .where(
              (event) =>
                  event.id == op.eventId &&
                  event.calendarId == op.intent.calendarId,
            )
            .firstOrNull;

  bool _startCovered(CalendarEvent event) {
    final start = event.startUtc == null ? null : localize(event.startUtc!);
    final date = start == null
        ? event.startDate
        : CalendarDate(start.year, start.month, start.day);
    return date != null &&
        date.compareTo(reader.window.first) >= 0 &&
        date.compareTo(reader.window.until) < 0;
  }

  DayClockDisplayState savedDisplayState(CalendarCreateOperation op) {
    if (_savedOperation(op) == null) return DayClockDisplayState.unavailable;
    if (_revealingId == op.operationId) return DayClockDisplayState.refreshing;
    if (!reader.connection.mayRead ||
        reader.failure != null ||
        reader.loading ||
        reader.saving) {
      return DayClockDisplayState.refreshNeeded;
    }
    if (!reader.sources.any(
      (s) => s.id == op.intent.calendarId && s.readable,
    )) {
      return DayClockDisplayState.inaccessible;
    }
    final event = savedReaderEvent(op);
    if (!_startCovered(event ?? op.event!)) {
      return DayClockDisplayState.outsideCoverage;
    }
    if (!reader.selected.contains(op.intent.calendarId)) {
      return DayClockDisplayState.hidden;
    }
    if (reader.sourceFailures.containsKey(op.intent.calendarId) ||
        reader.snapshots[op.intent.calendarId]?.fresh(
              reader.now,
              reader.window,
            ) !=
            true) {
      return DayClockDisplayState.refreshNeeded;
    }
    if (event == null) return DayClockDisplayState.missing;
    return selectedIdentity == calendarEventIdentity(event) &&
            selectedEvent != null
        ? DayClockDisplayState.selected
        : DayClockDisplayState.available;
  }

  String savedDisplayMessage(
    CalendarCreateOperation op,
  ) => switch (savedDisplayState(op)) {
    DayClockDisplayState.unavailable =>
      'Saved to Google Calendar. Restore its original account to show it.',
    DayClockDisplayState.hidden =>
      'Saved to Google Calendar. Its calendar is hidden. Show on Day Clock includes it in your selection.',
    DayClockDisplayState.refreshing =>
      'Saved to Google Calendar. Refreshing to show the event…',
    DayClockDisplayState.refreshNeeded =>
      'Saved to Google Calendar. Displaying it needs a refresh. Try Show on Day Clock again or open it in Google Calendar.',
    DayClockDisplayState.outsideCoverage =>
      'Saved to Google Calendar. This event is outside the retained seven-date clock coverage. Open it in Google Calendar.',
    DayClockDisplayState.inaccessible =>
      'Saved to Google Calendar. Its calendar is no longer accessible in this account. Open it in Google Calendar to check access.',
    DayClockDisplayState.missing =>
      'Saved to Google Calendar. The event is absent from the refreshed schedule; it may have moved or been removed. Open it in Google Calendar.',
    DayClockDisplayState.available =>
      'Saved to Google Calendar. Ready to show its date and time on Day Clock.',
    DayClockDisplayState.selected =>
      'Saved to Google Calendar. Highlighted on Day Clock and in the agenda.',
  };

  /// Reconciliation only. It can never submit or retry a Google insertion.
  Future<bool> revealSaved(CalendarCreateOperation op) {
    if (_savedOperation(op) == null) return Future.value(false);
    if (_revealingId == op.operationId && _revealing != null) {
      return _revealing!;
    }
    final token = ++_revealToken, view = _viewRevision;
    final session = reader.connection.sessionGeneration;
    _receiptId = op.operationId;
    _revealingId = op.operationId;
    bool current() =>
        token == _revealToken &&
        view == _viewRevision &&
        session == reader.connection.sessionGeneration &&
        _savedOperation(op) != null;
    final result = () async {
      try {
        final included = await reader.includeForReveal(
          op.intent.accountKey,
          op.intent.calendarId,
          current: current,
        );
        if (!included ||
            !current() ||
            reader.failure != null ||
            reader.sourceFailures.containsKey(op.intent.calendarId)) {
          return false;
        }
        final event = savedReaderEvent(op);
        if (event == null ||
            !_startCovered(event) ||
            event.startUtc == null ||
            reader.snapshots[op.intent.calendarId]?.fresh(
                  reader.now,
                  reader.window,
                ) !=
                true) {
          return false;
        }
        final start = localize(event.startUtc!);
        followingNow = false;
        _date = CalendarDate(start.year, start.month, start.day);
        _half = start.hour < 12 ? DayClockHalf.am : DayClockHalf.pm;
        _sync();
        selectedIdentity = calendarEventIdentity(event);
        if (selectedEvent == null) {
          selectedIdentity = null;
          return false;
        }
        ++revealRevision;
        return true;
      } catch (_) {
        // The durable Saved receipt is independent of read/display failure.
        return false;
      } finally {
        if (token == _revealToken) {
          _revealing = null;
          _revealingId = null;
          _notify();
        }
      }
    }();
    _revealing = result;
    _notify();
    return result;
  }

  CalendarCreateOperation? get operation =>
      creation?.journal?.operations[draft?.id];
  bool get creationBusy => creation?.busy == true;
  void attachCreation(CalendarCreationController value) {
    creation = value;
    time = value.time;
    value.addListener(_creationChanged);
    value.setUnlocked(unlocked);
    _creationChanged();
  }

  void _creationChanged() {
    final authority =
        '${reader.connection.sessionGeneration}/${reader.connection.creationGeneration}/'
        '${reader.connection.creationEnabled}/${reader.connection.creationUpgradeActive}';
    if (_creationAuthority != authority) {
      _creationAuthority = authority;
      touchDraft(notify: false);
    }
    final j = creation?.journal;
    if (j != null && _restoredCreationAccount != j.accountKey) {
      _restoredCreationAccount = j.accountKey;
      if (draft == null) {
        draft = j.drafts.values
            .where(
              (d) => j.operations[d.id]?.state != CalendarCreationState.saved,
            )
            .lastOrNull;
        draftAccountLabel = reader.connection.verifiedAccountLabel;
      }
    }
    if (operation case final op?) {
      creationState = op.state;
      validationMessage = op.message;
    } else if (creation?.message case final message?) {
      validationMessage = reader.connection.creationMessage ?? message;
    }
    _notify();
  }

  void restoreCreationDraft(String id) {
    final value = creation?.journal?.drafts[id];
    if (value == null || !unlocked || creationBusy) return;
    draft = CalendarEventDraft.fromJson(value.toJson());
    draftAccountLabel = reader.connection.verifiedAccountLabel;
    touchDraft(notify: false);
    _creationChanged();
  }

  Future<bool> keepDraft() async {
    if (draft == null || creation == null) return true;
    final saved = await creation!.keepDraft(draft!);
    _creationChanged();
    return saved;
  }

  void bindUnboundDraft() {
    final value = draft, key = reader.connection.verifiedAccountKey;
    if (value == null || value.accountKey != null || key == null || !unlocked) {
      return;
    }
    value.accountKey = key;
    value.calendarId =
        destinations.where((s) => s.primary).firstOrNull?.id ??
        destinations.firstOrNull?.id;
    draftAccountLabel = reader.connection.verifiedAccountLabel;
    touchDraft();
  }

  Future<void> enableCreation() async {
    touchDraft();
    await creation?.enable(draft: draft);
    touchDraft();
    validationMessage = reader.connection.creationMessage ?? creation?.message;
    _notify();
  }

  Future<void> openSaved(CalendarCreateOperation op) async {
    final url = safeCalendarUrl(op.event?.eventUrl, meeting: false);
    if (!unlocked ||
        op.state != CalendarCreationState.saved ||
        url == null ||
        op.intent.accountKey != reader.connection.verifiedAccountKey ||
        creation?.journal?.operations[op.operationId]?.state !=
            CalendarCreationState.saved) {
      return;
    }
    try {
      await agenda.platform.openCalendarLink(url, 'event', agenda.generation);
    } catch (_) {
      validationMessage =
          'The event is saved, but the browser could not be opened. Try Open event again.';
      _notify();
    }
  }

  CalendarDate get date => _date!;
  DayClockHalf get half => _half!;
  @override
  bool get creationConnected => creation?.ready == true;
  @override
  Future<CalendarCreateResult> submitReviewed() async {
    final intent = review, value = draft, owner = creation;
    final view = _viewRevision, selection = reader.selectionRevision;
    if (intent == null ||
        value == null ||
        owner == null ||
        !unlocked ||
        creationBusy) {
      return const CalendarCreateResult(
        CalendarCreationState.failed,
        message:
            'Google saving is unavailable in this build. Your draft is kept.',
      );
    }
    // Revalidate raw fields as well as the reviewed resolution before confirmation.
    final before = jsonEncode(value.toJson());
    final validation = _validation;
    await validateDraft();
    if (!unlocked ||
        value != draft ||
        before != jsonEncode(value.toJson()) ||
        _validation != validation + 1 ||
        review?.hash != intent.hash ||
        review?.calendarId != intent.calendarId ||
        review?.zoneFingerprint != intent.zoneFingerprint) {
      return const CalendarCreateResult(
        CalendarCreationState.draft,
        message: 'Review this task again before sending.',
      );
    }
    final result = await owner.submit(
      value,
      intent,
      retry: operation?.retryAllowed == true,
    );
    if (!unlocked ||
        draft != value ||
        reader.connection.verifiedAccountKey != intent.accountKey) {
      return result;
    }
    creationState = result.state;
    validationMessage = result.message;
    if (result.state == CalendarCreationState.saved) {
      _receiptId = value.id;
      final saved = owner.journal?.operations[value.id];
      if (value.showOnDayClock &&
          saved != null &&
          view == _viewRevision &&
          selection == reader.selectionRevision) {
        await revealSaved(saved);
      }
    }
    _notify();
    return result;
  }

  @override
  Future<CalendarCreateResult> reconcile(
    CalendarCreateOperation operation,
  ) async {
    final value = draft, revision = _validation;
    final view = _viewRevision, selection = reader.selectionRevision;
    final previousState =
        creation?.journal?.operations[operation.operationId]?.state;
    final account = reader.connection.verifiedAccountKey;
    final result =
        await creation?.check(operation) ??
        const CalendarCreateResult(
          CalendarCreationState.checking,
          message: 'Google save recovery is not connected in this build.',
        );
    if (_disposed ||
        !unlocked ||
        draft != value ||
        _validation != revision ||
        account != reader.connection.verifiedAccountKey ||
        operation.intent.accountKey != account) {
      return result;
    }
    creationState = result.state;
    validationMessage = result.message;
    if (result.state == CalendarCreationState.saved &&
        previousState != CalendarCreationState.saved &&
        value?.showOnDayClock == true &&
        view == _viewRevision &&
        selection == reader.selectionRevision) {
      final saved = creation?.journal?.operations[operation.operationId];
      if (saved != null) await revealSaved(saved);
    }
    _notify();
    return result;
  }

  bool get canRead =>
      unlocked &&
      reader.connection.mayRead &&
      !reader.connection.cleanupPending &&
      !reader.saving &&
      reader.accountKey != null &&
      reader.accountKey == reader.connection.verifiedAccountKey;
  bool get covered =>
      date.compareTo(reader.window.first) >= 0 &&
      date.compareTo(reader.window.until) < 0;
  List<CalendarSource> get destinations =>
      reader.accountKey == reader.connection.verifiedAccountKey
      ? reader.sources.where((s) => s.accessRole == 'owner').toList()
      : const [];
  String get timezoneLabel {
    final local = localize(reader.now);
    return '${local.timeZoneName} (${dayClockOffset(local.timeZoneOffset.inMinutes)}), device timezone';
  }

  CalendarEvent? get selectedEvent => [
    ...projection.agenda,
    ...projection.allDay,
  ].where((e) => calendarEventIdentity(e) == selectedIdentity).firstOrNull;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _formatted() {
    if (review != null) _updateOverlaps();
    _notify();
  }

  void _changed() {
    final connection = reader.connection;
    if (connection.verifiedAccountKey == null &&
        (draft?.accountKey != null ||
            _storageRevision != connection.storageRevision)) {
      draft = null;
      draftAccountLabel = null;
      _restoredCreationAccount = null;
      _destinations.clear();
      touchDraft(notify: false);
    }
    _storageRevision = connection.storageRevision;
    _sync();
    // A reviewed draft never carries authority through credential or access changes.
    if (review != null &&
        (review!.accountKey != reader.connection.verifiedAccountKey ||
            !destinations.any((s) => s.id == review!.calendarId))) {
      touchDraft(notify: false);
    }
    if (review != null) _updateOverlaps();
    _notify();
  }

  void _sync() {
    final now = localize(reader.now);
    if (followingNow || _date == null) {
      _date = CalendarDate(now.year, now.month, now.day);
      _half = now.hour < 12 ? DayClockHalf.am : DayClockHalf.pm;
    }
    final key = '$date/${half.name}/${now.timeZoneName}/${now.timeZoneOffset}';
    if (_windowKey != key) {
      _windowKey = key;
      _lanes = {};
      _window = DayClockWindow.build(
        date: date,
        half: half,
        day: reader.clock.dayWindow(date),
        localize: localize,
      );
    }
    projection = DayClockProjection.project(
      window: _window!,
      events: canRead && covered ? agenda.events : const [],
      nowUtc: reader.now,
      previousLanes: _lanes,
    );
    _lanes = projection.lanes;
    if (selectedEvent == null || !canRead) selectedIdentity = null;
  }

  void setUnlocked(bool value) {
    if (value == unlocked) return;
    unlocked = value;
    ++_viewRevision;
    creation?.setUnlocked(value);
    touchDraft(notify: false);
    _changed();
  }

  void timeContextChanged() {
    ++_viewRevision;
    unawaited(creation?.initialize());
    _windowKey = null;
    touchDraft(notify: false);
    _changed();
  }

  void browse(CalendarDate value, DayClockHalf selectedHalf) {
    ++_viewRevision;
    followingNow = false;
    _date = value;
    _half = selectedHalf;
    selectedIdentity = null;
    _changed();
  }

  void now() {
    ++_viewRevision;
    followingNow = true;
    _changed();
  }

  void select(CalendarEvent event) {
    ++_viewRevision;
    selectedIdentity = calendarEventIdentity(event);
    _notify();
  }

  CalendarEventDraft beginDraft({double? minute}) {
    if (operation?.state == CalendarCreationState.saved ||
        operation?.state == CalendarCreationState.failed) {
      draft = null;
      touchDraft(notify: false);
    }
    if (operation != null && draft != null) return draft!;
    if (draft != null &&
        (minute == null ||
            draft!.accountKey != reader.connection.verifiedAccountKey)) {
      return draft!;
    }
    final local = localize(reader.now);
    var minutes = minute?.round();
    if (minutes == null) {
      final same =
          date.toString() ==
              CalendarDate(local.year, local.month, local.day).toString() &&
          (local.hour < 12) == (half == DayClockHalf.am);
      minutes = same
          ? (((local.hour % 12) * 60 + local.minute) ~/ 15 + 1) * 15
          : 60;
    }
    minutes = minutes.clamp(0, 719);
    final start = DateTime.utc(
      date.year,
      date.month,
      date.day,
      (half == DayClockHalf.pm ? 12 : 0),
      minutes,
    );
    var duration = const Duration(hours: 1);
    if (draft case final previous?) {
      try {
        final retained =
            review?.endUtc.difference(review!.startUtc) ??
            _draftWall(
              previous.endDate,
              previous.endTime,
              previous.endPm,
            ).difference(
              _draftWall(
                previous.startDate,
                previous.startTime,
                previous.startPm,
              ),
            );
        if (retained > Duration.zero) duration = retained;
      } catch (_) {
        // An explicit new dial position gives invalid time fields a fresh interval.
      }
    }
    final end = start.add(duration);
    if (draft case final previous?) {
      previous.startDate = _dateText(start);
      previous.endDate = _dateText(end);
      previous.startTime = _timeText(start);
      previous.endTime = _timeText(end);
      previous.startPm = start.hour >= 12;
      previous.endPm = end.hour >= 12;
      touchDraft();
      return previous;
    }
    final key = reader.connection.verifiedAccountKey;
    final owned = destinations;
    final remembered = _destinations[key] ?? creation?.journal?.destination;
    final target =
        owned.where((s) => s.id == remembered).firstOrNull ??
        owned.where((s) => s.primary).firstOrNull ??
        owned.firstOrNull;
    draftAccountLabel = reader.connection.verifiedAccountLabel;
    draft = CalendarEventDraft(
      accountKey: key,
      startDate: _dateText(start),
      endDate: _dateText(end),
      startTime: _timeText(start),
      endTime: _timeText(end),
      startPm: start.hour >= 12,
      endPm: end.hour >= 12,
      calendarId: target?.id,
    );
    touchDraft();
    return draft!;
  }

  void touchDraft({bool notify = true}) {
    _validation++;
    review = null;
    errors = {};
    validationMessage = null;
    creationState = operation?.state ?? CalendarCreationState.draft;
    overlapMessage = 'Availability unknown until the times are checked.';
    if (notify) _notify();
  }

  void discardDraft() {
    if (operation != null || creationBusy) return;
    final id = draft?.id;
    if (id != null && creation != null) {
      unawaited(
        creation!.discard(id).catchError((Object _) {
          _creationChanged();
        }),
      );
    }
    draft = null;
    draftAccountLabel = null;
    touchDraft();
  }

  void _updateOverlaps() {
    final intent = review!;
    final start = localize(intent.startUtc), end = localize(intent.endUtc);
    final range = CalendarWindow(
      first: CalendarDate(start.year, start.month, start.day),
      until: CalendarDate(
        end.year,
        end.month,
        end.day,
      ).plusDays(end.hour == 0 && end.minute == 0 ? 0 : 1),
      startUtc: intent.startUtc,
      endUtc: intent.endUtc,
    );
    final current = operation;
    final count = agenda.events
        .where(
          (e) =>
              e.overlaps(range) &&
              !(current != null &&
                  e.id == current.eventId &&
                  e.calendarId == current.intent.calendarId),
        )
        .length;
    overlapMessage =
        '$count known calendar overlap${count == 1 ? '' : 's'}. '
        '${canRead && agenda.verified(range) ? 'Selected-calendar coverage is current; overlaps are advisory.' : 'Availability unknown: selected-calendar coverage is missing, stale or outside the retained window.'}';
  }

  @override
  Future<void> validateDraft() async {
    final value = draft;
    if (value == null || _disposed) return;
    final revision = ++_validation;
    errors = {};
    review = null;
    validationMessage = null;
    creationState = CalendarCreationState.validating;
    final account = reader.connection.verifiedAccountKey;
    final target = value.calendarId;
    if (value.title.trim().isEmpty || value.title.length > 1024) {
      errors['title'] = 'Enter a title of 1–1024 characters.';
    }
    if (account == null) {
      errors['calendar'] =
          'Connect Google, then choose the account and calendar for this draft.';
    } else if (value.accountKey == null) {
      errors['calendar'] =
          'Use the connected account for this draft, then choose an owned calendar.';
    } else if (value.accountKey != account) {
      errors['calendar'] =
          'This draft needs its original Google account. Discard it to start with another account.';
    } else if (!destinations.any((s) => s.id == target)) {
      errors['calendar'] =
          'Choose an owned Google calendar, including your primary calendar.';
    }
    if (value.colorId != null &&
        reader.palette?.colors.containsKey(value.colorId) != true) {
      errors['color'] =
          'Choose an available Google colour or Calendar default.';
    }
    DateTime? endpoint(String date, String text, bool pm, String key) {
      try {
        return _draftWall(date, text, pm);
      } catch (_) {
        errors[key] =
            'Use a real date (YYYY-MM-DD) and a time such as 10:00 with AM or PM.';
        return null;
      }
    }

    final start = endpoint(
      value.startDate,
      value.startTime,
      value.startPm,
      'start',
    );
    final end = endpoint(value.endDate, value.endTime, value.endPm, 'end');
    final title = value.title.trim(),
        busy = value.busy,
        colorId = value.colorId,
        taskId = value.taskId;
    if (errors.isNotEmpty || start == null || end == null) {
      creationState = CalendarCreationState.draft;
      _notify();
      return;
    }
    if (time == null) {
      validationMessage =
          'Device time validation is unavailable in this build. Your draft is kept.';
      creationState = CalendarCreationState.draft;
      _notify();
      return;
    }
    _notify();
    try {
      final resolved = await Future.wait([
        time!.resolve(start),
        time!.resolve(end),
      ]);
      if (_disposed || revision != _validation) return;
      if (!unlocked ||
          account != reader.connection.verifiedAccountKey ||
          !destinations.any((s) => s.id == target)) {
        validationMessage =
            'Account or calendar access changed. Check this draft again.';
      } else if (resolved[0].fingerprint != resolved[1].fingerprint) {
        validationMessage =
            'The device timezone changed. Check the endpoint times again.';
      } else if (!resolved[0].utc.isAfter(reader.now)) {
        errors['start'] = 'Choose a future start time.';
      } else if (!resolved[1].utc.isAfter(resolved[0].utc)) {
        errors['end'] =
            'End must be after start. For overnight tasks, explicitly change the end date.';
      } else {
        review = CalendarCreateIntent(
          accountKey: account!,
          calendarId: target!,
          title: title,
          startUtc: resolved[0].utc,
          endUtc: resolved[1].utc,
          zone: resolved[0].zone,
          zoneFingerprint: resolved[0].fingerprint,
          startOffset: resolved[0].offsetMinutes,
          endOffset: resolved[1].offsetMinutes,
          busy: busy,
          colorId: colorId,
          taskId: taskId,
        );
        _destinations[account] = target;
        _updateOverlaps();
      }
    } catch (_) {
      if (_disposed || revision != _validation) return;
      validationMessage =
          'A time is skipped or repeated by daylight saving, or device rules are unavailable. Choose an unambiguous local time and check again.';
    }
    if (_disposed || revision != _validation) return;
    creationState = review == null
        ? CalendarCreationState.draft
        : CalendarCreationState.ready;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revealToken;
    _validation++;
    reader.removeListener(_changed);
    agenda.removeListener(_formatted);
    creation?.removeListener(_creationChanged);
    draft = null;
    _destinations.clear();
    super.dispose();
  }
}

String dayClockOffset(int minutes) =>
    'UTC${minutes < 0 ? '-' : '+'}'
    '${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes.abs() % 60).toString().padLeft(2, '0')}';
String _dateText(DateTime value) =>
    CalendarDate(value.year, value.month, value.day).toString();
String _timeText(DateTime value) =>
    '${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')}';

DateTime _draftWall(String date, String text, bool pm) {
  final day = CalendarDate.parse(date);
  final match = RegExp(
    r'^(1[0-2]|0?[1-9]):([0-5][0-9])$',
  ).firstMatch(text.trim());
  if (match == null) throw const FormatException('Invalid wall time.');
  return DateTime.utc(
    day.year,
    day.month,
    day.day,
    int.parse(match[1]!) % 12 + (pm ? 12 : 0),
    int.parse(match[2]!),
  );
}
