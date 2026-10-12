import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/gen_tokens.dart';

void main() {
  final json = jsonDecode(File(tokensPath).readAsStringSync()) as Map<String, dynamic>;
  const reason = 'Relancer : dart run tool/gen_tokens.dart';

  test('$causePath est à jour avec design/tokens.json', () {
    expect(File(causePath).readAsStringSync(), generateCause(json), reason: reason);
  });

  test('$themePath est à jour avec design/tokens.json', () {
    expect(File(themePath).readAsStringSync(), generateTheme(json), reason: reason);
  });
}
