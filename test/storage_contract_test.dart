import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source keeps the required local-first Hive storage contract', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("Hive.openBox<dynamic>('app_data')"));
    expect(source, contains("Hive.openBox<dynamic>(name)"));
    expect(source, contains("'schemaVersion'"));
    expect(source, contains("'lectures'"));
    expect(source, contains("'tasks'"));
  });

  test('the banned term is not present in user-facing Dart source', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('حصص')));
  });
}
