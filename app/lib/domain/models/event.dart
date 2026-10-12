import 'cause.g.dart';
import 'route.dart';
import 'time_slot.dart';
import 'zone.dart';

export 'cause.g.dart';
export 'route.dart';
export 'time_slot.dart';
export 'zone.dart';

enum EventStatus { published, cancelled }

/// Une manif publiée ou annulée (les brouillons ne sortent jamais du serveur).
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.cause,
    required this.city,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.organizer,
    this.description,
    this.demands = const [],
    this.declared = false,
    this.segmentCount = 1,
    this.bufferM = 100,
    this.route,
    this.zone,
  });

  final String id;
  final String title;
  final Cause cause;
  final String city;
  final DateTime startsAt;
  final DateTime endsAt;
  final EventStatus status;
  final String organizer;
  final String? description;
  final List<String> demands;
  final bool declared;
  final int segmentCount;
  final int bufferM;

  /// Parcours et zone de présence : absents dans la liste, chargés pour le détail.
  final EventRoute? route;
  final Zone? zone;

  bool get isCancelled => status == EventStatus.cancelled;

  /// On peut dire « J'y suis ! » dès 30 min avant le début.
  DateTime get opensAt => startsAt.subtract(const Duration(minutes: 30));

  /// Même règle que `record_presence` côté SQL : créneau entre l'ouverture et la fin.
  bool acceptsSlot(TimeSlot slot) =>
      !isCancelled && !slot.start.isBefore(opensAt) && !slot.start.isAfter(endsAt);

  /// En cours : le « J'y suis ! » est possible maintenant.
  bool isLive(DateTime now) => now.isBefore(endsAt) && acceptsSlot(TimeSlot.containing(now));

  bool isOver(DateTime now) => !now.isBefore(endsAt);
}

/// Compteurs d'une manif : présents vérifiés et soutiens.
class EventCount {
  const EventCount({required this.present, required this.supporters});

  static const zero = EventCount(present: 0, supporters: 0);

  final int present;
  final int supporters;
}

/// Une manif et ses compteurs, pour la liste.
class EventSummary {
  const EventSummary(this.event, this.count);

  final Event event;
  final EventCount count;
}
