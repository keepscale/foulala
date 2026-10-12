import '../models/geo.dart';

/// Lecture de la position, UNE fois, au moment du « J'y suis ! ».
/// Jamais en continu, jamais en arrière-plan. Le résultat ne quitte pas le téléphone.
abstract interface class LocationReader {
  /// Lève [LocationUnavailable] si la position ne peut pas être lue.
  Future<PositionFix> readOnce();

  /// Ouvre les réglages de l'app (autorisation refusée définitivement).
  Future<void> openSettings();
}

enum LocationProblem {
  /// Localisation désactivée sur le téléphone.
  serviceDisabled,

  /// Autorisation refusée (on peut la redemander).
  denied,

  /// Autorisation refusée définitivement : il faut passer par les réglages.
  deniedForever,

  /// Pas de position dans le délai imparti.
  timeout,
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.problem);

  final LocationProblem problem;

  @override
  String toString() => 'LocationUnavailable($problem)';
}
