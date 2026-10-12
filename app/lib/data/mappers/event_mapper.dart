import '../../domain/models/event.dart';

/// Traduction des lignes JSON de PostgREST (vues `api.events` et `api.event_count`)
/// vers les modèles du domaine. Seul endroit qui connaît les noms de colonnes de l'API.
abstract final class EventMapper {
  static Event event(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        title: json['title'] as String,
        cause: Cause.values.asNameMap()[json['cause']] ?? Cause.autre,
        city: json['city'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        status: json['status'] == 'cancelled' ? EventStatus.cancelled : EventStatus.published,
        organizer: json['organizer'] as String,
        description: json['description'] as String?,
        demands: (json['demands'] as List?)?.cast<String>() ?? const [],
        declared: json['declared'] as bool? ?? false,
        segmentCount: json['segment_count'] as int? ?? 1,
        bufferM: json['buffer_m'] as int? ?? 100,
        route: json['route'] as Map<String, dynamic>?,
        zone: json['zone'] as Map<String, dynamic>?,
      );

  static EventCount count(Map<String, dynamic> json) =>
      EventCount(present: json['present'] as int, supporters: json['supporters'] as int);
}
