import '../../matrix_api_lite.dart';

class SpacesSummary {
  /// Its presence indicates that there are more results to return.
  final String nextBatch;

  /// These are the nodes of the graph.
  final List<PublicRoomsChunk> rooms;

  /// These are the edges of the graph.
  final List<SpacesSummaryEvent> events;

  const SpacesSummary({
    required this.nextBatch,
    required this.rooms,
    required this.events,
  });

  factory SpacesSummary.fromJson(Map<String, dynamic> json) => SpacesSummary(
        nextBatch: json['next_batch'],
        rooms: (json['rooms'] as List)
            .map((i) => PublicRoomsChunk.fromJson(i))
            .toList(),
        events: (json['events'] as List)
            .map((i) => SpacesSummaryEvent.fromJson(i))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'next_batch': nextBatch,
        'rooms': rooms.map((i) => i.toJson()).toList(),
        'events': events.map((i) => i.toJson()).toList(),
      };
}

/// The objects in the array are stripped m.space.parent or m.space.child
/// events. This means that they only contain the type, state_key, content,
/// room_id and sender keys, similar to invite_state in the /sync API.
class SpacesSummaryEvent {
  final String type;
  final String stateKey;
  final SpacesSummaryEventContent content;
  final String roomId;
  final String sender;

  const SpacesSummaryEvent({
    required this.type,
    required this.stateKey,
    required this.content,
    required this.roomId,
    required this.sender,
  });

  factory SpacesSummaryEvent.fromJson(Map<String, dynamic> json) =>
      SpacesSummaryEvent(
        type: json['type'],
        stateKey: json['state_key'],
        content: SpacesSummaryEventContent.fromJson(json['content']),
        roomId: json['room_id'],
        sender: json['sender'],
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'state_key': stateKey,
        'content': content.toJson(),
        'room_id': roomId,
        'sender': sender,
      };
}

/// All fields are nullable for now because this is user created.
class SpacesSummaryEventContent {
  final List<String>? via;
  final bool? present;
  final String? order;
  final bool? autoJoin;

  const SpacesSummaryEventContent({
    required this.via,
    required this.present,
    required this.order,
    required this.autoJoin,
  });

  factory SpacesSummaryEventContent.fromJson(Map<String, dynamic> json) =>
      SpacesSummaryEventContent(
        via: List<String>.from(json['via'] ?? []),
        present: json['present'],
        order: json['order'],
        autoJoin: json['auto_join'],
      );

  Map<String, dynamic> toJson() => {
        'via': List<String>.from(via ?? []),
        'present': present,
        'order': order,
        'auto_join': autoJoin,
      };
}
