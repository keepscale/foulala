import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../domain/models/event.dart';
import '../../../domain/models/event_stats.dart';
import '../../../domain/repositories/event_repository.dart';
import '../../core/themes/tokens.g.dart';

/// Une barre du graphique des arrivées.
class ArrivalBar {
  const ArrivalBar(this.slot, this.n, {this.current = false});

  final TimeSlot slot;

  /// Arrivées, ou null si moins de [privacyThreshold] : la barre est masquée.
  final int? n;

  /// Quart d'heure en cours (manif en direct) : pas encore complet.
  final bool current;
}

/// Densité par tronçon pour un quart d'heure.
class DensityView {
  const DensityView(this.slot, this.cells);

  final TimeSlot slot;

  /// Une case par tronçon, du départ à l'arrivée ; null si masquée (moins de 20 personnes).
  final List<int?> cells;

  int get max => cells.whereType<int>().fold(0, math.max);
}

/// Compteur détaillé d'une manif (maquette Compteur).
class CounterViewModel extends ChangeNotifier {
  CounterViewModel({
    required this.event,
    required this._events,
    DateTime Function()? clock,
    this.refreshEvery = const Duration(minutes: 1),
  }) : _clock = clock ?? DateTime.now;

  final Event event;
  final EventRepository _events;
  final DateTime Function() _clock;

  /// En direct, les chiffres sont relus à ce rythme.
  final Duration refreshEvery;

  EventStats? _stats;
  bool _failed = false;
  DateTime? _updatedAt;
  Timer? _timer;
  bool _disposed = false;

  EventStats? get stats => _stats;
  bool get failed => _failed;

  /// Heure de la dernière lecture réussie.
  DateTime? get updatedAt => _updatedAt;

  bool get live => event.isLive(_clock());

  Future<void> load() async {
    _failed = false;
    try {
      _stats = await _events.getEventStats(event.id);
      _updatedAt = _clock();
    } catch (_) {
      _failed = _stats == null; // une relecture ratée garde les chiffres déjà affichés
    }
    if (_disposed) return;
    _timer ??= live ? Timer.periodic(refreshEvery, (_) => _refresh()) : null;
    notifyListeners();
  }

  void _refresh() {
    if (!live) {
      _timer?.cancel();
      _timer = null;
    }
    load();
  }

  /// Arrivées par quart d'heure, du premier créneau accepté (30 min avant le début)
  /// jusqu'au créneau en cours, ou jusqu'à la fin. Moins de 20 arrivées : masqué.
  List<ArrivalBar> get bars {
    final stats = _stats;
    final now = _clock();
    if (stats == null || now.isBefore(event.opensAt)) return const [];
    final byStart = {for (final a in stats.arrivals) a.slot: a.n};
    final isLive = live;
    var slot = TimeSlot.containing(event.opensAt);
    if (slot.start.isBefore(event.opensAt)) slot = TimeSlot.containing(slot.end);
    final last = isLive ? TimeSlot.containing(now) : TimeSlot.containing(event.endsAt);
    final result = <ArrivalBar>[];
    while (slot.compareTo(last) <= 0) {
      final n = byStart[slot] ?? 0;
      result.add(ArrivalBar(slot, n >= privacyThreshold ? n : null, current: isLive && slot == last));
      slot = TimeSlot.containing(slot.end);
    }
    return result;
  }

  /// Quart d'heure qui a vu le plus d'arrivées, parmi ceux qu'on peut afficher.
  ArrivalBar? get peak {
    ArrivalBar? best;
    for (final b in bars) {
      if (b.n != null && (best == null || b.n! > best.n!)) best = b;
    }
    return best;
  }

  /// Densité du dernier quart d'heure qui a au moins une case affichable.
  DensityView? get density {
    final cells = _stats?.density ?? const [];
    if (cells.isEmpty) return null;
    final slot = cells.map((c) => c.slot).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final values = List<int?>.filled(event.segmentCount, null);
    for (final c in cells) {
      if (c.slot == slot && c.segment >= 0 && c.segment < values.length && c.n >= privacyThreshold) {
        values[c.segment] = c.n;
      }
    }
    return DensityView(slot, values);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
