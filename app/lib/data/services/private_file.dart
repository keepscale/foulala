import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Fichier JSON privé de l'app, **exclu des sauvegardes** (iCloud, Google, transfert d'appareil).
///
/// Il vit dans `Application Support/private/` (iOS) ou `files/private/` (Android) :
/// - iOS : le dossier est marqué `isExcludedFromBackup` (canal `foulala/backup`, AppDelegate.swift) ;
/// - Android : `allowBackup="false"` et `data_extraction_rules.xml` excluent tout.
/// Il disparaît avec l'app à la désinstallation, contrairement au trousseau iOS.
class PrivateFile {
  PrivateFile({Future<Directory> Function()? directory}) : _directory = directory ?? _defaultDirectory;

  static const _backup = MethodChannel('foulala/backup');

  final Future<Directory> Function() _directory;
  late final Future<File> _file = _open();

  static Future<Directory> _defaultDirectory() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/private');
    await dir.create(recursive: true);
    // À chaque ouverture : le marqueur peut se perdre si le dossier est recréé.
    if (Platform.isIOS) await _backup.invokeMethod<bool>('excludeFromBackup', dir.path);
    return dir;
  }

  Future<File> _open() async => File('${(await _directory()).path}/store.json');

  /// Contenu du fichier ; vide s'il n'existe pas encore ou s'il est illisible.
  Future<Map<String, Object?>> read() async {
    final file = await _file;
    try {
      if (!await file.exists()) return {};
      return (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>();
    } on Object {
      return {}; // fichier abîmé : on repart de zéro plutôt que de bloquer l'app
    }
  }

  /// Remplace le contenu. Écrit à côté puis renomme : un arrêt brutal ne laisse jamais un fichier à moitié écrit.
  Future<void> write(Map<String, Object?> values) async {
    final file = await _file;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(values), flush: true);
    await tmp.rename(file.path);
  }
}
