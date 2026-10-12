import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import '../../domain/models/geo.dart';
import '../../domain/repositories/location_reader.dart';

/// Lecture GPS ponctuelle avec geolocator.
///
/// Vie privée : sur Android, `forceLocationManager` n'utilise que le GPS du téléphone,
/// sans le service de localisation de Google Play (qui peut envoyer à Google les Wi-Fi
/// et antennes alentour). Jamais de flux de positions, jamais d'arrière-plan.
class GeolocatorLocationReader implements LocationReader {
  static const _timeLimit = Duration(seconds: 25);

  @override
  Future<PositionFix> readOnce() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailable(LocationProblem.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationUnavailable(LocationProblem.denied);
      case LocationPermission.deniedForever:
        throw const LocationUnavailable(LocationProblem.deniedForever);
      case LocationPermission.whileInUse || LocationPermission.always || LocationPermission.unableToDetermine:
        break;
    }

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(accuracy: LocationAccuracy.high, forceLocationManager: true, timeLimit: _timeLimit)
        : Platform.isIOS
            ? AppleSettings(accuracy: LocationAccuracy.best, timeLimit: _timeLimit)
            : const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _timeLimit);
    try {
      final p = await Geolocator.getCurrentPosition(locationSettings: settings);
      return PositionFix(GeoPoint(p.latitude, p.longitude), accuracyM: p.accuracy);
    } on TimeoutException {
      throw const LocationUnavailable(LocationProblem.timeout);
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
