import '../models/event.dart';

enum SupportOutcome {
  /// Reçu par le serveur (y compris un soutien déjà compté : il ne compte qu'une fois).
  sent,

  /// Réseau indisponible : rien n'est gardé, l'utilisateur réessaiera.
  offline,

  /// Refusé par le serveur (manif annulée ou plus disponible).
  rejected,
}

/// Soutiens « Je soutiens » : jeton par manif, envoi, et liste gardée sur le téléphone.
abstract interface class SupportRepository {
  /// Envoie le soutien avec un jeton propre à cette manif, distinct de celui du « J'y suis ! ».
  /// Une fois reçu, la manif rejoint la liste locale « Mes soutiens ».
  Future<SupportOutcome> support(Event event);

  /// Ce téléphone soutient-il déjà cette manif ?
  Future<bool> isSupported(String eventId);

  /// Manifs soutenues depuis ce téléphone, telles qu'elles étaient au moment du soutien.
  /// Lues sur le téléphone seulement : le serveur ne sait pas qui soutient quoi.
  Future<List<Event>> supportedEvents();
}
