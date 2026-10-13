import 'event.dart';

/// Arrivées pendant un quart d'heure (vue `event_timeline`).
class SlotArrivals {
  const SlotArrivals(this.slot, this.n);

  final TimeSlot slot;
  final int n;
}

/// Présences signalées sur un tronçon pendant un quart d'heure (vue `event_density`).
/// Le serveur ne renvoie jamais une case de moins de 20 personnes.
class DensityCell {
  const DensityCell(this.slot, this.segment, this.n);

  final TimeSlot slot;
  final int segment;
  final int n;
}

/// Chiffres du compteur d'une manif : totaux, arrivées par quart d'heure, densité par tronçon.
class EventStats {
  const EventStats({required this.count, this.arrivals = const [], this.density = const []});

  final EventCount count;
  final List<SlotArrivals> arrivals;
  final List<DensityCell> density;
}
