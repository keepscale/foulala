import '../models/event.dart';
import '../models/geo.dart';
import '../models/segment.dart';

/// Précision GPS maximale acceptée (CLAUDE.md, « Côté téléphone »).
const maxAccuracyM = 50.0;

/// Résultat de la vérification faite sur le téléphone, avant tout envoi.
sealed class PresenceCheck {
  const PresenceCheck();
}

/// Dans la zone et dans le créneau : on peut envoyer.
final class InZone extends PresenceCheck {
  const InZone({required this.slot, required this.segment});

  final TimeSlot slot;
  final Segment segment;
}

/// Hors de la zone. Rien n'est envoyé.
final class OutOfZone extends PresenceCheck {
  const OutOfZone({required this.distanceM, required this.accuracyM});

  final double distanceM;
  final double accuracyM;
}

/// Position trop imprécise pour conclure. Rien n'est envoyé.
final class TooImprecise extends PresenceCheck {
  const TooImprecise({required this.accuracyM});

  final double accuracyM;
}

/// Hors du créneau de la manif (pas encore ouverte, terminée ou annulée). Rien n'est envoyé.
final class OutsideWindow extends PresenceCheck {
  const OutsideWindow();
}

/// Vérifie, sur le téléphone, qu'on peut compter cette présence.
///
/// Dans l'ordre : créneau, précision (≤ 50 m), zone. La position [fix] ne sert qu'ici
/// et n'apparaît dans aucun résultat envoyable : [InZone] ne garde que le créneau et le tronçon.
PresenceCheck checkPresence({
  required Event event,
  required Zone zone,
  required EventRoute route,
  required PositionFix fix,
  required DateTime now,
}) {
  final slot = TimeSlot.containing(now);
  if (!event.isLive(now) || !event.acceptsSlot(slot)) return const OutsideWindow();
  if (fix.accuracyM > maxAccuracyM) return TooImprecise(accuracyM: fix.accuracyM);
  if (!zone.contains(fix.point)) {
    return OutOfZone(distanceM: zone.distanceM(fix.point), accuracyM: fix.accuracyM);
  }
  return InZone(slot: slot, segment: Segment.at(route.fractionAlong(fix.point), event.segmentCount));
}
