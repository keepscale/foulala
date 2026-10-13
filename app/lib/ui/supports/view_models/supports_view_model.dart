import 'package:flutter/foundation.dart';

import '../../../domain/models/event.dart';
import '../../../domain/repositories/support_repository.dart';

/// « Mes soutiens » : lu sur le téléphone seulement.
class SupportsViewModel extends ChangeNotifier {
  SupportsViewModel({required this._supports, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SupportRepository _supports;
  final DateTime Function() _clock;

  List<Event> _upcoming = const [];
  List<Event> _past = const [];
  bool _loaded = false;

  /// En cours ou à venir, la plus proche d'abord.
  List<Event> get upcoming => _upcoming;

  /// Terminées, la plus récente d'abord.
  List<Event> get past => _past;

  bool get loaded => _loaded;
  bool get isEmpty => _upcoming.isEmpty && _past.isEmpty;
  DateTime get now => _clock();

  Future<void> load() async {
    final events = await _supports.supportedEvents();
    final now = _clock();
    _upcoming = events.where((e) => !e.isOver(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    _past = events.where((e) => e.isOver(now)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    _loaded = true;
    notifyListeners();
  }
}
