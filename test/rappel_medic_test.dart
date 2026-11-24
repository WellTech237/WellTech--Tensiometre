import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/services/notifications.dart';

/// Rappels de médicament : horaires calculés (sans plugin de notification).
void main() {
  final matin = DateTime(2026, 11, 23, 9, 0); // avant la prise de 20 h

  test('21 jours : un rappel + une relance par jour', () {
    final r = horairesMedicament(maintenant: matin, heure: 20, minute: 0, relance: true);
    expect(r.length, 42);
    expect(r.first.quand, DateTime(2026, 11, 23, 20, 0));
    expect(r[1].quand, DateTime(2026, 11, 23, 20, 30));
    expect(r[1].relance, isTrue);
    expect(r.last.quand, DateTime(2026, 12, 13, 20, 30));
    expect(r.map((x) => x.indice).toSet().length, 42); // identifiants uniques
    expect(r.every((x) => x.indice < Notifications.joursMedic * 2), isTrue);
  });

  test('sans relance : un seul rappel par jour', () {
    final r = horairesMedicament(maintenant: matin, heure: 20, minute: 0, relance: false);
    expect(r.length, 21);
    expect(r.any((x) => x.relance), isFalse);
  });

  test('prise notée aujourd’hui : plus de rappel ni de relance ce jour', () {
    final r = horairesMedicament(
      maintenant: matin, heure: 20, minute: 0, relance: true,
      joursNotes: {DateTime(2026, 11, 23)},
    );
    expect(r.length, 40);
    expect(r.first.quand, DateTime(2026, 11, 24, 20, 0));
  });

  test('entre l’heure de prise et la relance : seule la relance reste', () {
    final r = horairesMedicament(maintenant: DateTime(2026, 11, 23, 20, 10), heure: 20, minute: 0, relance: true);
    expect(r.first.relance, isTrue);
    expect(r.first.quand, DateTime(2026, 11, 23, 20, 30));
  });

  test('relance qui passe minuit (23 h 45 + 30 min)', () {
    final r = horairesMedicament(maintenant: matin, heure: 23, minute: 45, relance: true);
    expect(r[1].quand, DateTime(2026, 11, 24, 0, 15));
  });

  test('changement d’heure (mars) : toujours 20 h 00, heure locale', () {
    final r = horairesMedicament(maintenant: DateTime(2027, 3, 13, 9), heure: 20, minute: 0, relance: false);
    expect(r.every((x) => x.quand.hour == 20 && x.quand.minute == 0), isTrue);
  });
}
