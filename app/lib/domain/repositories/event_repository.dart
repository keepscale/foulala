import '../models/event.dart';

/// Manifs publiées (ou annulées) et leurs compteurs.
abstract interface class EventRepository {
  /// Villes qui ont au moins une manif visible, triées.
  Future<List<String>> getCities();

  /// Manifs d'une ville avec leurs compteurs, par date de début.
  Future<List<EventSummary>> getEventSummaries(String city);
}
