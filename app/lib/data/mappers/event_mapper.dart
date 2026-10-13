import '../../domain/models/event.dart';
import '../../domain/models/event_stats.dart';
import '../../domain/models/geo.dart';

/// Traduction des lignes JSON de PostgREST (vues `api.events`, `api.event_count`, `api.event_timeline`, `api.event_density`)
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
        route: _route(json['route']),
        zone: _zone(json['zone']),
      );

  static EventCount count(Map<String, dynamic> json) =>
      EventCount(present: json['present'] as int, supporters: json['supporters'] as int);

  /// Ligne de `api.event_timeline`. Les sommes SQL arrivent en `numeric` : lues comme des nombres.
  static SlotArrivals arrivals(Map<String, dynamic> json) =>
      SlotArrivals(_slot(json['time_slot']), (json['arrivals'] as num).toInt());

  /// Ligne de `api.event_density`.
  static DensityCell density(Map<String, dynamic> json) =>
      DensityCell(_slot(json['time_slot']), (json['segment'] as num).toInt(), (json['n'] as num).toInt());

  /// Copie gardée sur le téléphone pour « Mes soutiens » : les champs de la liste,
  /// sous les noms de colonnes de l'API pour être relue par [event]. Ni parcours ni zone.
  static Map<String, Object?> snapshot(Event e) => {
        'id': e.id,
        'title': e.title,
        'cause': e.cause.name,
        'city': e.city,
        'starts_at': e.startsAt.toUtc().toIso8601String(),
        'ends_at': e.endsAt.toUtc().toIso8601String(),
        'status': e.isCancelled ? 'cancelled' : 'published',
        'organizer': e.organizer,
        'declared': e.declared,
        'segment_count': e.segmentCount,
        'buffer_m': e.bufferM,
      };

  static TimeSlot _slot(Object? value) => TimeSlot.parse(DateTime.parse(value as String));

  /// GeoJSON LineString → parcours.
  static EventRoute? _route(Object? geojson) {
    if (geojson is! Map || geojson['type'] != 'LineString') return null;
    return EventRoute(_points(geojson['coordinates'] as List));
  }

  /// GeoJSON Polygon → zone (contour extérieur puis trous).
  static Zone? _zone(Object? geojson) {
    if (geojson is! Map || geojson['type'] != 'Polygon') return null;
    return Zone([for (final ring in geojson['coordinates'] as List) _points(ring as List)]);
  }

  /// GeoJSON : [longitude, latitude].
  static List<GeoPoint> _points(List coords) => [
        for (final c in coords) GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
}
