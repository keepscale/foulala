/// Tronçon du parcours (environ 200 m, 100 au plus), numéroté à partir de 0.
///
/// Invariant : 0 ≤ [index] < [count], comme la validation de `record_presence`.
class Segment {
  Segment._(this.index, this.count);

  /// Tronçon qui contient la position relative [fraction] (0 = départ, 1 = arrivée).
  factory Segment.at(double fraction, int count) {
    if (count < 1) throw ArgumentError.value(count, 'count', 'au moins un tronçon');
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Segment._((f * count).floor().clamp(0, count - 1), count);
  }

  /// Relit un tronçon (file d'attente locale).
  factory Segment.parse(int index, int count) {
    if (count < 1 || index < 0 || index >= count) {
      throw RangeError.range(index, 0, count - 1, 'index');
    }
    return Segment._(index, count);
  }

  final int index;
  final int count;

  /// Numéro affiché, à partir de 1 : « Tronçon 4 sur 9 ».
  int get number => index + 1;

  @override
  bool operator ==(Object other) => other is Segment && other.index == index && other.count == count;

  @override
  int get hashCode => Object.hash(index, count);
}
