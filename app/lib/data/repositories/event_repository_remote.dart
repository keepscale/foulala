import '../../domain/models/event.dart';
import '../../domain/repositories/event_repository.dart';
import '../mappers/event_mapper.dart';
import '../services/foulala_api.dart';

/// Manifs lues depuis l'API PostgREST.
class EventRepositoryRemote implements EventRepository {
  EventRepositoryRemote(this._api);

  final FoulalaApi _api;

  @override
  Future<List<String>> getCities() => _api.getCities();

  @override
  Future<List<EventSummary>> getEventSummaries(String city) async {
    final events = (await _api.getEvents(city)).map(EventMapper.event).toList();
    final counts = {
      for (final row in await _api.getCounts(events.map((e) => e.id)))
        row['event_id'] as String: EventMapper.count(row),
    };
    return [for (final e in events) EventSummary(e, counts[e.id] ?? EventCount.zero)];
  }
}
