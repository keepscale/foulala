import '../models/presence_report.dart';
import '../models/presence_token.dart';

enum SubmitOutcome {
  /// Reçu par le serveur (y compris un jeton déjà compté : il ne compte qu'une fois).
  sent,

  /// Réseau indisponible : gardé sur le téléphone, renvoyé plus tard.
  queued,

  /// Refusé par le serveur (manif plus disponible, créneau hors manif…). Pas de nouvel essai.
  rejected,
}

/// Présences « J'y suis ! » : jeton par manif, envoi, file d'attente hors ligne.
abstract interface class PresenceRepository {
  /// Jeton de ce téléphone pour cette manif : repris s'il existe, sinon tiré au hasard
  /// et gardé localement. Jamais le même jeton pour deux manifs.
  Future<PresenceToken> tokenFor(String eventId);

  /// Envoie la présence, ou la met en file d'attente si le réseau sature.
  /// La file est gardée jusqu'à [retryUntil] (24 h après la fin de la manif), puis abandonnée.
  Future<SubmitOutcome> submit(PresenceReport report, {required DateTime retryUntil});

  /// Renvoie ce qui attend dans la file. À appeler au démarrage et au retour dans l'app.
  Future<void> flushPending({required DateTime now});

  /// Une présence de cette manif attend-elle encore le réseau ?
  Future<bool> isPending(String eventId);
}
