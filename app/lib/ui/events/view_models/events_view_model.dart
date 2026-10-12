import 'package:flutter/foundation.dart';

import '../../../domain/models/event.dart';
import '../../../domain/repositories/city_repository.dart';
import '../../../domain/repositories/event_repository.dart';

/// Liste des manifs d'une ville, rangées en « En ce moment », « À venir » et « Terminées ».
class EventsViewModel extends ChangeNotifier {
  EventsViewModel({
    required this._events,
    required this._cities,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final EventRepository _events;
  final CityRepository _cities;
  final DateTime Function() _clock;

  String? _city;
  List<String> _availableCities = const [];
  List<EventSummary> _all = const [];
  Cause? _filter;
  bool _loading = false;
  bool _failed = false;

  String? get city => _city;
  List<String> get availableCities => _availableCities;
  Cause? get filter => _filter;
  bool get loading => _loading;
  bool get failed => _failed;

  /// Aucune ville choisie : l'écran doit proposer d'en choisir une.
  bool get needsCity => !_loading && _city == null;

  /// Causes présentes dans la ville, dans l'ordre de design/tokens.json.
  List<Cause> get causes {
    final present = _all.map((s) => s.event.cause).toSet();
    return Cause.values.where(present.contains).toList();
  }

  Iterable<EventSummary> get _visible => _filter == null ? _all : _all.where((s) => s.event.cause == _filter);

  List<EventSummary> get live {
    final now = _clock();
    return _visible.where((s) => s.event.isLive(now)).toList();
  }

  /// À venir, annulées comprises (l'annulation est une information utile).
  List<EventSummary> get upcoming {
    final now = _clock();
    return _visible.where((s) => !s.event.isLive(now) && !s.event.isOver(now)).toList();
  }

  /// Terminées, de la plus récente à la plus ancienne. Les annulées passées sont omises.
  List<EventSummary> get past {
    final now = _clock();
    return _visible.where((s) => s.event.isOver(now) && !s.event.isCancelled).toList()
      ..sort((a, b) => b.event.startsAt.compareTo(a.event.startsAt));
  }

  Future<void> load() async {
    _city = await _cities.getCity();
    await _fetch(withCities: true);
  }

  Future<void> refresh() => _fetch(withCities: _availableCities.isEmpty);

  Future<void> selectCity(String city) async {
    if (city == _city) return;
    _city = city;
    _filter = null;
    _all = const [];
    await _cities.setCity(city);
    await _fetch();
  }

  void setFilter(Cause? cause) {
    if (cause == _filter) return;
    _filter = cause;
    notifyListeners();
  }

  Future<void> _fetch({bool withCities = false}) async {
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      if (withCities) _availableCities = await _events.getCities();
      final city = _city;
      if (city != null) _all = await _events.getEventSummaries(city);
    } catch (_) {
      // Pas de détail dans l'interface : on propose simplement de réessayer.
      _failed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
