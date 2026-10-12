import 'presence_token.dart';
import 'segment.dart';
import 'time_slot.dart';

/// Le SEUL message qui quitte le téléphone au « J'y suis ! » (invariant n° 3) :
/// l'id de la manif, le jeton, le créneau et le tronçon. Rien d'autre.
///
/// Ne jamais y ajouter de champ (position, précision, heure exacte, appareil…)
/// sans passer par le skill revue-vie-privee.
class PresenceReport {
  const PresenceReport({required this.eventId, required this.token, required this.slot, this.segment});

  final String eventId;
  final PresenceToken token;
  final TimeSlot slot;
  final Segment? segment;
}
