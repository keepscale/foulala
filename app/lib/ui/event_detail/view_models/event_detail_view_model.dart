import 'package:flutter/foundation.dart';

import '../../../domain/models/event.dart';
import '../../../domain/repositories/event_repository.dart';
import '../../../domain/repositories/presence_repository.dart';
import '../../../domain/repositories/support_repository.dart';

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
    required this._supports,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String eventId;
  final EventRepository _events;
  final PresenceRepository _presence;
  final SupportRepository _supports;
  final DateTime Function() _clock;

  EventSummary? _summary;
  bool _loading = false;
  bool _failed = false;
  bool _pending = false;
  bool _supported = false;
  bool _supporting = false;

  EventSummary? get summary => _summary;
  bool get loading => _loading;
  bool get failed => _failed;

  /// Une présence de ce téléphone attend le réseau pour cette manif.
  bool get pending => _pending;

  /// Ce téléphone soutient déjà cette manif.
  bool get supported => _supported;

  /// Envoi du soutien en cours.
  bool get supporting => _supporting;

  /// « Je soutiens » : possible tant que la manif n'est pas annulée (le serveur refuse ensuite).
  bool get canSupport => _summary != null && !_summary!.event.isCancelled;

  /// Le compteur détaillé a quelque chose à montrer dès l'ouverture du « J'y suis ! ».
  bool get hasCounter {
    final event = _summary?.event;
    return event != null && !event.isCancelled && !_clock().isBefore(event.opensAt);
  }

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
      _supported = await _supports.isSupported(eventId);
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Envoie le soutien. Renvoie le résultat pour que l'écran l'annonce, ou null si rien n'est parti.
  Future<SupportOutcome?> support() async {
    final event = _summary?.event;
    if (event == null || _supported || _supporting || !canSupport) return null;
    _supporting = true;
    notifyListeners();
    final SupportOutcome outcome;
    try {
      outcome = await _supports.support(event);
    } finally {
      _supporting = false;
    }
    if (outcome == SupportOutcome.sent) {
      _supported = true;
      notifyListeners();
      await load(); // compteur de soutiens à jour
    } else {
      notifyListeners();
    }
    return outcome;
  }

  // L'écran peut se fermer pendant un envoi ou un chargement.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
