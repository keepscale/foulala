import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/services/local_store.dart';
import 'package:foulala/data/services/private_file.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('foulala_store_'));
  tearDown(() => dir.delete(recursive: true));

  PrivateFile file() => PrivateFile(directory: () async => dir);

  test('ce qui est écrit est relu par une nouvelle instance (redémarrage de l\'app)', () async {
    final store = LocalStore(file());
    await store.setCity('Lyon');
    await store.setToken('e1', 'a');
    await store.setSupportToken('e1', 'b');
    await store.setPending(['p1']);
    await store.setSupports(['s1', 's2']);

    final again = LocalStore(file());
    expect(await again.getCity(), 'Lyon');
    expect(await again.getToken('e1'), 'a');
    expect(await again.getSupportToken('e1'), 'b');
    expect(await again.getPending(), ['p1']);
    expect(await again.getSupports(), ['s1', 's2']);
  });

  test('file vide : la clé disparaît du fichier', () async {
    final store = LocalStore(file());
    await store.setPending(['p1']);
    await store.setPending([]);
    expect(await LocalStore(file()).getPending(), isEmpty);
    expect(File('${dir.path}/store.json').readAsStringSync(), isNot(contains('pending')));
  });

  test('écritures rapprochées : la dernière gagne, sans fichier temporaire qui traîne', () async {
    final store = LocalStore(file());
    await Future.wait([for (var i = 0; i < 20; i++) store.setToken('e$i', 't$i')]);
    final again = LocalStore(file());
    for (var i = 0; i < 20; i++) {
      expect(await again.getToken('e$i'), 't$i');
    }
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['store.json']);
  });

  test('fichier abîmé : on repart de zéro au lieu de planter', () async {
    File('${dir.path}/store.json').writeAsStringSync('{pas du json');
    final store = LocalStore(file());
    expect(await store.getCity(), isNull);
    await store.setCity('Paris');
    expect(await LocalStore(file()).getCity(), 'Paris');
  });

  test('une liste modifiée après coup par l\'appelant ne change pas ce qui est stocké', () async {
    final store = LocalStore(file());
    final entries = ['a'];
    await store.setSupports(entries);
    entries.add('b');
    expect(await store.getSupports(), ['a']);
  });
}
