import 'dart:math';

/// Jeton anonyme d'un téléphone pour UNE manif : UUID v4 tiré au hasard.
///
/// Invariants (n° 2) : aléatoire cryptographique, jamais dérivé d'un identifiant
/// de l'appareil, et un jeton différent pour chaque manif (voir PresenceRepository.tokenFor).
class PresenceToken {
  PresenceToken._(this.value);

  static final _v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  /// Nouveau jeton. [random] n'est à fournir que dans les tests.
  factory PresenceToken.generate([Random? random]) {
    final rng = random ?? Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return PresenceToken._('${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}');
  }

  /// Relit un jeton stocké. Refuse tout ce qui n'est pas un UUID v4.
  factory PresenceToken.parse(String value) {
    final v = value.toLowerCase();
    if (!_v4.hasMatch(v)) throw FormatException("jeton qui n'est pas un UUID v4", value);
    return PresenceToken._(v);
  }

  final String value;

  /// Forme courte pour l'affichage : « 7f3c91a2-…-e04b ».
  String get short => '${value.substring(0, 8)}-…-${value.substring(value.length - 4)}';

  @override
  bool operator ==(Object other) => other is PresenceToken && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Jamais le jeton complet dans un journal ou un message d'erreur.
  @override
  String toString() => 'PresenceToken($short)';
}
