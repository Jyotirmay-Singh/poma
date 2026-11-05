import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

const focusWriteScope = 'https://www.googleapis.com/auth/calendar.app.created';

enum CalendarWriteCapability {
  disabled,
  granting,
  verifying,
  setupRequired,
  ready,
  blocked,
}

enum FocusOperationKind { create, edit, delete }

enum FocusOperationStatus {
  pending,
  sending,
  checking,
  saved,
  failed,
  expired,
  cancelled,
  needsReview,
}

String focusUuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

bool validFocusUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
).hasMatch(value);
String focusEventId(String block) {
  if (!validFocusUuid(block)) {
    throw const FormatException('Invalid block identity.');
  }
  return 'poma${block.replaceAll('-', '')}';
}

String focusUtc(DateTime value) =>
    '${value.toUtc().toIso8601String().split('.').first}Z';

class FocusPayload {
  FocusPayload({
    required this.title,
    required DateTime start,
    required DateTime end,
    this.busy = true,
    required this.zone,
    required this.zoneFingerprint,
    required this.startOffsetMinutes,
    required this.endOffsetMinutes,
  }) : start = start.toUtc(),
       end = end.toUtc() {
    if (title.trim().isEmpty ||
        title.length > 1024 ||
        !this.end.isAfter(this.start) ||
        this.start.millisecondsSinceEpoch % 1000 != 0 ||
        this.end.millisecondsSinceEpoch % 1000 != 0 ||
        zone.isEmpty ||
        zoneFingerprint.isEmpty ||
        startOffsetMinutes.abs() > 1440 ||
        endOffsetMinutes.abs() > 1440) {
      throw const FormatException('Invalid focus block.');
    }
  }
  final String title, zone, zoneFingerprint;
  final DateTime start, end;
  final int startOffsetMinutes, endOffsetMinutes;
  final bool busy;
  String get transparency => busy ? 'opaque' : 'transparent';
  String get hash => sha256
      .convert(
        utf8.encode(
          jsonEncode([title, focusUtc(start), focusUtc(end), transparency]),
        ),
      )
      .toString();
  Map<String, Object?> get fields => {
    'summary': title,
    'start': {'dateTime': focusUtc(start)},
    'end': {'dateTime': focusUtc(end)},
    'transparency': transparency,
  };
  Map<String, Object?> toJson() => {
    'title': title,
    'start': focusUtc(start),
    'end': focusUtc(end),
    'busy': busy,
    'zone': zone,
    'zoneFingerprint': zoneFingerprint,
    'startOffset': startOffsetMinutes,
    'endOffset': endOffsetMinutes,
  };
  factory FocusPayload.fromJson(Map<String, dynamic> m) => FocusPayload(
    title: m['title'] as String,
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    busy: m['busy'] as bool,
    zone: m['zone'] as String,
    zoneFingerprint: m['zoneFingerprint'] as String,
    startOffsetMinutes: m['startOffset'] as int,
    endOffsetMinutes: m['endOffset'] as int,
  );
}

class FocusCalendarBinding {
  FocusCalendarBinding({
    required this.accountKey,
    required this.clientId,
    required this.id,
    required this.calendarKey,
    required this.provisioningId,
    required this.name,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(accountKey) ||
        clientId.isEmpty ||
        id.isEmpty ||
        id == 'primary' ||
        !validFocusUuid(calendarKey) ||
        !validFocusUuid(provisioningId)) {
      throw const FormatException('Invalid calendar binding.');
    }
  }
  final String accountKey, clientId, id, calendarKey, provisioningId, name;
  String get marker =>
      'Poma-Focus-v1 calendarKey=$calendarKey provisioningId=$provisioningId';
  Map<String, Object?> toJson() => {
    'version': 1,
    'accountKey': accountKey,
    'clientId': clientId,
    'id': id,
    'calendarKey': calendarKey,
    'provisioningId': provisioningId,
    'name': name,
  };
  factory FocusCalendarBinding.fromJson(Map<String, dynamic> m) {
    if (m['version'] != 1) throw const FormatException('Unsupported binding.');
    return FocusCalendarBinding(
      accountKey: m['accountKey'] as String,
      clientId: m['clientId'] as String,
      id: m['id'] as String,
      calendarKey: m['calendarKey'] as String,
      provisioningId: m['provisioningId'] as String,
      name: m['name'] as String,
    );
  }
}

class FocusBlockDraft {
  FocusBlockDraft({required this.id, required this.payload, this.taskId});
  final String id;
  final FocusPayload payload;
  final String? taskId;
  Map<String, Object?> toJson() => {
    'id': id,
    'payload': payload.toJson(),
    'taskId': taskId,
  };
  factory FocusBlockDraft.fromJson(Map<String, dynamic> m) {
    if (!validFocusUuid(m['id'] as String)) {
      throw const FormatException('Invalid draft.');
    }
    return FocusBlockDraft(
      id: m['id'] as String,
      payload: FocusPayload.fromJson(m['payload'] as Map<String, dynamic>),
      taskId: m['taskId'] as String?,
    );
  }
}

class FocusRemoteBlock {
  FocusRemoteBlock(Map<String, dynamic> value)
    : value = Map.unmodifiable(
        jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
      );
  final Map<String, dynamic> value;
  Map<String, Object?> get localJson => {
    for (final key in [
      'id',
      'etag',
      'status',
      'summary',
      'start',
      'end',
      'transparency',
      'eventType',
      'visibility',
      'reminders',
    ])
      if (value.containsKey(key)) key: value[key],
    'extendedProperties': {
      'private': {
        for (final key in [
          'pomaOwner',
          'pomaSchema',
          'pomaCalendarKey',
          'pomaBlockId',
          'pomaCreateOp',
          'pomaLastOp',
          'pomaPayloadHash',
        ])
          if (properties.containsKey(key)) key: properties[key],
      },
    },
  };
  String get id => value['id'] as String? ?? '';
  String get etag => value['etag'] as String? ?? '';
  bool get deleted => value['status'] == 'cancelled';
  Map<String, dynamic> get properties => Map<String, dynamic>.from(
    (value['extendedProperties'] as Map?)?['private'] as Map? ?? {},
  );
  String get blockId => properties['pomaBlockId'] as String? ?? '';
  String get lastOp => properties['pomaLastOp'] as String? ?? '';
  String get title => value['summary'] as String? ?? '';
  DateTime get start =>
      DateTime.parse((value['start'] as Map)['dateTime'] as String).toUtc();
  DateTime get end =>
      DateTime.parse((value['end'] as Map)['dateTime'] as String).toUtc();
  bool get busy => value['transparency'] != 'transparent';
  String get actualHash => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            title,
            focusUtc(start),
            focusUtc(end),
            busy ? 'opaque' : 'transparent',
          ]),
        ),
      )
      .toString();
  bool owned(FocusCalendarBinding binding) {
    try {
      return !deleted &&
          etag.isNotEmpty &&
          validFocusUuid(blockId) &&
          id == focusEventId(blockId) &&
          properties['pomaOwner'] == 'poma.windows' &&
          properties['pomaSchema'] == '1' &&
          properties['pomaCalendarKey'] == binding.calendarKey &&
          properties['pomaCreateOp'] == blockId &&
          validFocusUuid(lastOp) &&
          RegExp(
            r'^[0-9a-f]{64}$',
          ).hasMatch(properties['pomaPayloadHash'] as String? ?? '') &&
          title.trim().isNotEmpty &&
          title.length <= 1024 &&
          end.isAfter(start) &&
          start.millisecondsSinceEpoch % 1000 == 0 &&
          end.millisecondsSinceEpoch % 1000 == 0 &&
          const {
            null,
            'opaque',
            'transparent',
          }.contains(value['transparency']) &&
          (value['eventType'] ?? 'default') == 'default' &&
          value['recurringEventId'] == null &&
          value['originalStartTime'] == null &&
          ((value['recurrence'] as List?)?.isEmpty ?? true) &&
          ((value['attendees'] as List?)?.isEmpty ?? true) &&
          ((value['attachments'] as List?)?.isEmpty ?? true) &&
          value['conferenceData'] == null &&
          value['hangoutLink'] == null &&
          value['visibility'] == 'private' &&
          (value['reminders'] as Map?)?['useDefault'] == false &&
          (((value['reminders'] as Map?)?['overrides'] as List?)?.isEmpty ??
              true) &&
          !((value['start'] as Map).containsKey('date')) &&
          !((value['end'] as Map).containsKey('date'));
    } catch (_) {
      return false;
    }
  }

  bool matches(FocusBlockOperation op) =>
      lastOp == op.id &&
      actualHash == op.payload.hash &&
      properties['pomaPayloadHash'] == op.payload.hash;
}

class FocusBlockOperation {
  FocusBlockOperation({
    required this.id,
    required this.blockId,
    required this.kind,
    required this.payload,
    required this.confirmedAt,
    required this.credentialGeneration,
    this.status = FocusOperationStatus.pending,
    this.etag,
    this.before,
    this.taskId,
    this.error,
    this.transitionAt,
    this.target,
  });
  final String id, blockId, credentialGeneration;
  final FocusOperationKind kind;
  final FocusOperationStatus status;
  final FocusPayload payload;
  final DateTime confirmedAt;
  final DateTime? transitionAt;
  final String? etag, taskId, error;
  final FocusRemoteBlock? before;
  final FocusCalendarBinding? target;
  String get eventId => focusEventId(blockId);
  bool get unresolved => const {
    FocusOperationStatus.pending,
    FocusOperationStatus.sending,
    FocusOperationStatus.checking,
    FocusOperationStatus.needsReview,
  }.contains(status);
  FocusBlockOperation state(
    FocusOperationStatus status,
    DateTime now, {
    String? error,
  }) => FocusBlockOperation(
    id: id,
    blockId: blockId,
    kind: kind,
    payload: payload,
    confirmedAt: confirmedAt,
    credentialGeneration: credentialGeneration,
    status: status,
    etag: etag,
    before: before,
    taskId: taskId,
    error: error,
    transitionAt: now,
    target: target,
  );
  Map<String, Object?> get markers => {
    'pomaOwner': 'poma.windows',
    'pomaSchema': '1',
    'pomaCalendarKey': '',
    'pomaBlockId': blockId,
    'pomaCreateOp': blockId,
    'pomaLastOp': id,
    'pomaPayloadHash': payload.hash,
  };
  Map<String, Object?> toJson() => {
    'id': id,
    'blockId': blockId,
    'kind': kind.name,
    'payload': payload.toJson(),
    'confirmedAt': focusUtc(confirmedAt),
    'credentialGeneration': credentialGeneration,
    'status': status.name,
    'etag': etag,
    'before': before?.localJson,
    'target': target?.toJson(),
    'taskId': taskId,
    'error': error,
    'transitionAt': transitionAt?.toUtc().toIso8601String(),
  };
  factory FocusBlockOperation.fromJson(Map<String, dynamic> m) {
    final id = m['id'] as String, block = m['blockId'] as String;
    if (!validFocusUuid(id) || !validFocusUuid(block)) {
      throw const FormatException('Invalid operation.');
    }
    final kind = FocusOperationKind.values.byName(m['kind'] as String);
    if (kind == FocusOperationKind.create && id != block) {
      throw const FormatException('Invalid create identity.');
    }
    return FocusBlockOperation(
      id: id,
      blockId: block,
      kind: kind,
      payload: FocusPayload.fromJson(m['payload'] as Map<String, dynamic>),
      confirmedAt: DateTime.parse(m['confirmedAt'] as String),
      credentialGeneration: m['credentialGeneration'] as String,
      target: m['target'] == null
          ? null
          : FocusCalendarBinding.fromJson(m['target'] as Map<String, dynamic>),
      status: FocusOperationStatus.values.byName(m['status'] as String),
      etag: m['etag'] as String?,
      taskId: m['taskId'] as String?,
      before: m['before'] == null
          ? null
          : FocusRemoteBlock(m['before'] as Map<String, dynamic>),
      error: m['error'] as String?,
      transitionAt: m['transitionAt'] == null
          ? null
          : DateTime.parse(m['transitionAt'] as String),
    );
  }
}

class FocusJournal {
  FocusJournal(
    this.accountKey, {
    this.binding,
    this.provisioning,
    this.provisioningState = 'none',
    Map<String, FocusBlockDraft>? drafts,
    Map<String, FocusBlockOperation>? operations,
    Map<String, FocusRemoteBlock>? blocks,
  }) : drafts = drafts ?? {},
       operations = operations ?? {},
       blocks = blocks ?? {};
  final String accountKey;
  FocusCalendarBinding? binding, provisioning;
  String provisioningState;
  final Map<String, FocusBlockDraft> drafts;
  final Map<String, FocusBlockOperation> operations;
  final Map<String, FocusRemoteBlock> blocks;
  Map<String, Object?> toJson() => {
    'version': 1,
    'accountKey': accountKey,
    'binding': binding?.toJson(),
    'provisioning': provisioning?.toJson(),
    'provisioningState': provisioningState,
    'drafts': drafts.values.map((d) => d.toJson()).toList(),
    'operations': operations.values.map((o) => o.toJson()).toList(),
    'blocks': blocks.values.map((b) => b.localJson).toList(),
  };
  factory FocusJournal.decode(String value, String account) {
    if (utf8.encode(value).length > 16 * 1024 * 1024) {
      throw const FormatException('Journal too large.');
    }
    final m = jsonDecode(value) as Map<String, dynamic>;
    if (m['version'] != 1 || m['accountKey'] != account) {
      throw const FormatException('Invalid journal.');
    }
    final result = FocusJournal(
      account,
      provisioningState: m['provisioningState'] as String,
    );
    if (!const {
      'none',
      'prepared',
      'sending',
      'checking',
      'bound',
      'needsReview',
    }.contains(result.provisioningState)) {
      throw const FormatException('Invalid setup state.');
    }
    result.binding = m['binding'] == null
        ? null
        : FocusCalendarBinding.fromJson(m['binding'] as Map<String, dynamic>);
    result.provisioning = m['provisioning'] == null
        ? null
        : FocusCalendarBinding.fromJson(
            m['provisioning'] as Map<String, dynamic>,
          );
    for (final binding in [result.binding, result.provisioning]) {
      if (binding != null && binding.accountKey != account) {
        throw const FormatException('Wrong account.');
      }
    }
    for (final v in m['drafts'] as List) {
      final d = FocusBlockDraft.fromJson(v as Map<String, dynamic>);
      if (result.drafts.containsKey(d.id)) {
        throw const FormatException('Duplicate draft.');
      }
      result.drafts[d.id] = d;
    }
    for (final v in m['operations'] as List) {
      final o = FocusBlockOperation.fromJson(v as Map<String, dynamic>);
      if (result.operations.containsKey(o.id)) {
        throw const FormatException('Duplicate operation.');
      }
      result.operations[o.id] = o;
    }
    for (final v in m['blocks'] as List) {
      final b = FocusRemoteBlock(v as Map<String, dynamic>);
      if (result.blocks.containsKey(b.id)) {
        throw const FormatException('Duplicate block.');
      }
      result.blocks[b.id] = b;
    }
    return result;
  }
  FocusJournal copy() => FocusJournal.decode(jsonEncode(toJson()), accountKey);
}
