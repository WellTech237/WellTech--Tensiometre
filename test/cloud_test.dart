import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/services/cloud.dart';

void main() {
  test('Clé du jour d’une prise : AAAA-MM-JJ (un document par jour)', () {
    expect(Cloud.cleJour(DateTime(2026, 3, 5)), '2026-03-05');
    expect(Cloud.cleJour(DateTime(2026, 11, 21, 18, 5)), '2026-11-21');
  });
}
