import 'package:flutter/foundation.dart';

import '../../../domain/models/event.dart';
import '../../../domain/repositories/event_repository.dart';
import '../../../domain/repositories/presence_repository.dart';

/// État du bouton « J'y suis ! » sur le détail.
enum PresenceButton {
  /// Ouvert : la manif est en cours (ou commence dans moins de 30 min).
  open,

  /// Pas encore ouvert : il ouvrira 30 min avant le début.
  notYet,

  /// Terminée.
  over,

  /// Annulée.
  cancelled,

  /// Parcours ou zone manquants : impossible de vérifier la présence.
  unavailable,
}

class EventDetailViewModel extends ChangeNotifier {
  EventDetailViewModel({
    required this.eventId,
    required this._events,
    required this._presence,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String eventId;
  final EventRepository _events;
  final PresenceRepository _presence;
  final DateTime Function() _clock;

  EventSummary? _summary;
  bool _loading = false;
  bool _failed = false;
  bool _pending = false;

  EventSummary? get summary => _summary;
  bool get loading => _loading;
  bool get failed => _failed;

  /// Une présence de ce téléphone attend le réseau pour cette manif.
  bool get pending => _pending;

  DateTime get now => _clock();

  PresenceButton get presenceButton {
    final event = _summary?.event;
    if (event == null || event.route == null || event.zone == null) return PresenceButton.unavailable;
    if (event.isCancelled) return PresenceButton.cancelled;
    final now = _clock();
    if (event.isLive(now)) return PresenceButton.open;
    return event.isOver(now) ? PresenceButton.over : PresenceButton.notYet;
  }

  Future<void> load() async {
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      _summary = await _events.getEventSummary(eventId);
      _pending = await _presence.isPending(eventId);
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
