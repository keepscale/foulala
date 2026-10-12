import 'package:flutter/foundation.dart';

import '../../../domain/models/event.dart';
import '../../../domain/models/geo.dart';
import '../../../domain/models/presence_report.dart';
import '../../../domain/presence/check_presence.dart';
import '../../../domain/repositories/event_repository.dart';
import '../../../domain/repositories/location_reader.dart';
import '../../../domain/repositories/presence_repository.dart';

/// États de l'écran « J'y suis ! » (maquette Presence : envoyée, en attente de réseau, hors zone).
sealed class PresenceState {
  const PresenceState();
}

final class Checking extends PresenceState {
  const Checking();
}

final class Sent extends PresenceState {
  const Sent(this.report, {this.present});

  final PresenceReport report;

  /// Compteur relu après l'envoi, si le réseau a suivi.
  final int? present;
}

final class Queued extends PresenceState {
  const Queued(this.report);

  final PresenceReport report;
}

final class NotInZone extends PresenceState {
  const NotInZone({required this.distanceM, required this.accuracyM});

  final double distanceM;
  final double accuracyM;
}

final class Imprecise extends PresenceState {
  const Imprecise(this.accuracyM);

  final double accuracyM;
}

final class Closed extends PresenceState {
  const Closed();
}

final class Rejected extends PresenceState {
  const Rejected();
}

final class NoLocation extends PresenceState {
  const NoLocation(this.problem);

  final LocationProblem problem;
}

class PresenceViewModel extends ChangeNotifier {
  PresenceViewModel({
    required this.event,
    required this._presence,
    required this._location,
    required this._events,
    DateTime Function()? clock,
  })  : assert(event.route != null && event.zone != null),
        _clock = clock ?? DateTime.now;

  /// Les jetons en attente sont gardés jusqu'à 24 h après la fin, comme la purge côté serveur.
  static const retryWindow = Duration(hours: 24);

  final Event event;
  final PresenceRepository _presence;
  final LocationReader _location;
  final EventRepository _events;
  final DateTime Function() _clock;

  PresenceState _state = const Checking();
  PositionFix? _fix;
  bool _disposed = false;

  PresenceState get state => _state;

  /// Position lue, affichée sur le schéma. Reste en mémoire, le temps de l'écran : jamais stockée ni envoyée.
  PositionFix? get fix => _fix;

  /// Lit la position une fois, vérifie sur le téléphone, puis envoie (ou met en attente).
  Future<void> run() async {
    _set(const Checking());
    _fix = null;
    final PositionFix fix;
    try {
      fix = await _location.readOnce();
    } on LocationUnavailable catch (e) {
      _set(NoLocation(e.problem));
      return;
    }
    _fix = fix;

    final check = checkPresence(event: event, zone: event.zone!, route: event.route!, fix: fix, now: _clock());
    switch (check) {
      case OutsideWindow():
        _set(const Closed());
      case TooImprecise(:final accuracyM):
        _set(Imprecise(accuracyM));
      case OutOfZone(:final distanceM, :final accuracyM):
        _set(NotInZone(distanceM: distanceM, accuracyM: accuracyM));
      case InZone(:final slot, :final segment):
        final report = PresenceReport(
          eventId: event.id,
          token: await _presence.tokenFor(event.id),
          slot: slot,
          segment: segment,
        );
        final outcome = await _presence.submit(report, retryUntil: event.endsAt.add(retryWindow));
        switch (outcome) {
          case SubmitOutcome.sent:
            _set(Sent(report));
            await _refreshCount(report);
          case SubmitOutcome.queued:
            _set(Queued(report));
          case SubmitOutcome.rejected:
            _set(const Rejected());
        }
    }
  }

  /// En attente de réseau : nouvel essai à la demande.
  Future<void> retrySending() async {
    final current = _state;
    if (current is! Queued) return;
    await _presence.flushPending(now: _clock());
    if (!await _presence.isPending(event.id)) {
      _set(Sent(current.report));
      await _refreshCount(current.report);
    }
  }

  Future<void> openSettings() => _location.openSettings();

  Future<void> _refreshCount(PresenceReport report) async {
    try {
      final present = (await _events.getEventSummary(event.id)).count.present;
      if (_state case Sent(report: final r) when r == report) _set(Sent(report, present: present));
    } catch (_) {
      // Pas grave : la présence est comptée, seul le chiffre manque.
    }
  }

  void _set(PresenceState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
