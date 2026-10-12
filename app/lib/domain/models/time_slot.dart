/// Créneau d'un quart d'heure. Seule information temporelle envoyée au serveur :
/// jamais l'heure exacte (invariant n° 3).
///
/// Invariant : [start] est en UTC et tombe sur un multiple de 15 minutes depuis l'epoch,
/// comme `date_bin('15 minutes', …, 'epoch')` côté SQL et la contrainte CHECK de `presence`.
class TimeSlot implements Comparable<TimeSlot> {
  TimeSlot._(this.start);

  static const length = Duration(minutes: 15);

  /// Le créneau qui contient [t], arrondi au quart d'heure inférieur.
  factory TimeSlot.containing(DateTime t) {
    final ms = t.toUtc().millisecondsSinceEpoch;
    final step = length.inMilliseconds;
    return TimeSlot._(DateTime.fromMillisecondsSinceEpoch(ms - ms % step, isUtc: true));
  }

  /// Relit un créneau (file d'attente locale). Refuse une heure qui n'est pas un quart d'heure.
  factory TimeSlot.parse(DateTime start) {
    final slot = TimeSlot.containing(start);
    if (slot.start != start.toUtc()) {
      throw ArgumentError.value(start, 'start', "n'est pas un début de quart d'heure");
    }
    return slot;
  }

  final DateTime start;

  DateTime get end => start.add(length);

  @override
  int compareTo(TimeSlot other) => start.compareTo(other.start);

  @override
  bool operator ==(Object other) => other is TimeSlot && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'TimeSlot(${start.toIso8601String()})';
}
