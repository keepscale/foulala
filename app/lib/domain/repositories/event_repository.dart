import '../models/event.dart';
import '../models/event_stats.dart';

/// Manifs publiées (ou annulées) et leurs compteurs.
abstract interface class EventRepository {
  /// Villes qui ont au moins une manif visible, triées.
  Future<List<String>> getCities();

  /// Manifs d'une ville avec leurs compteurs, par date de début. Sans parcours ni zone.
  Future<List<EventSummary>> getEventSummaries(String city);

  /// Une manif avec son parcours, sa zone de présence et ses compteurs.
  Future<EventSummary> getEventSummary(String id);

  /// Compteur détaillé d'une manif : totaux, arrivées et densité (seuil de 20 appliqué par le serveur).
  Future<EventStats> getEventStats(String id);
}
