import '../../domain/models/presence_report.dart';
import '../../domain/models/presence_token.dart';
import '../../domain/models/segment.dart';
import '../../domain/models/time_slot.dart';

/// Présence en attente de réseau, gardée sur le téléphone.
class PendingPresence {
  const PendingPresence(this.report, this.retryUntil);

  final PresenceReport report;
  final DateTime retryUntil;
}

abstract final class PresenceMapper {
  /// Corps de `POST /rpc/presence` : les quatre champs autorisés, et eux seuls (invariant n° 3).
  static Map<String, Object?> toApi(PresenceReport r) => {
        'event_id': r.eventId,
        'token': r.token.value,
        'time_slot': r.slot.start.toIso8601String(),
        'segment': r.segment?.index,
      };

  /// File d'attente locale : le rapport, plus de quoi le revalider et savoir quand l'abandonner.
  static Map<String, Object?> toStore(PendingPresence p) => {
        ...toApi(p.report),
        'segment_count': p.report.segment?.count,
        'retry_until': p.retryUntil.toUtc().toIso8601String(),
      };

  static PendingPresence fromStore(Map<String, dynamic> json) {
    final index = json['segment'] as int?;
    return PendingPresence(
      PresenceReport(
        eventId: json['event_id'] as String,
        token: PresenceToken.parse(json['token'] as String),
        slot: TimeSlot.parse(DateTime.parse(json['time_slot'] as String)),
        segment: index == null ? null : Segment.parse(index, json['segment_count'] as int),
      ),
      DateTime.parse(json['retry_until'] as String),
    );
  }
}
