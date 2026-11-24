// Tests des parties critiques (sécurité de la patiente et exactitude) :
// valeurs limites AHA, matrice d'alerte, jours autour de l'heure d'été,
// un seul courriel au médecin par crise.

import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/core/classification.dart';
import 'package:welltech/core/controle.dart';
import 'package:welltech/core/risque.dart';
import 'package:welltech/data/models.dart';
import 'package:welltech/services/cloud.dart';

Mesure crise(DateTime d, {String? episode, int niveau = 4}) => Mesure(
      id: '${d.millisecondsSinceEpoch}',
      date: d,
      tas: 190,
      tad: 125,
      pouls: 90,
      nbLectures: 1,
      grade: 'grade3',
      symptomes: const ['poitrine'],
      niveauAlerte: niveau,
      episodeId: episode,
    );

void main() {
  group('Classification AHA : valeurs limites', () {
    final attendu = <(int, int), Grade>{
      (119, 79): Grade.normale,
      (120, 79): Grade.elevee,
      (129, 79): Grade.elevee,
      (130, 79): Grade.grade1,
      (119, 80): Grade.grade1,
      (139, 89): Grade.grade1,
      (140, 89): Grade.grade2,
      (139, 90): Grade.grade2,
      (180, 120): Grade.grade2,
      (181, 120): Grade.grade3,
      (180, 121): Grade.grade3,
      (200, 70): Grade.grade3,
    };
    attendu.forEach((v, g) => test('${v.$1}/${v.$2} → ${g.name}', () => expect(classer(v.$1, v.$2), g)));

    test('Grossesse : 140/90 et 160/110', () {
      expect(classerGrossesse(139, 89), Grade.normale);
      expect(classerGrossesse(140, 85), Grade.grade2);
      expect(classerGrossesse(150, 109), Grade.grade2);
      expect(classerGrossesse(160, 100), Grade.grade3);
      expect(classerGrossesse(150, 110), Grade.grade3);
    });

    test('Saisies invalides', () {
      expect(verifierValeurs(tas: 80, tad: 80), isNotNull); // TAS ≤ TAD
      expect(verifierValeurs(tas: 251, tad: 100), isNotNull);
      expect(verifierValeurs(tas: 120, tad: 39), isNotNull);
      expect(verifierValeurs(tas: 120, tad: 80, pouls: 221), isNotNull);
      expect(verifierValeurs(tas: 250, tad: 150, pouls: 30), isNull);
    });
  });

  test('Matrice d’alerte : règles de sécurité sur les 100 combinaisons', () {
    for (final g in Grade.values) {
      for (final alarme in [false, true]) {
        for (final autre in [false, true]) {
          for (final r in Risque.values) {
            final n = deciderAlerte(
              grade: g,
              symptomesCoches: alarme ? const ['x'] : const [],
              symptomesAutres: autre ? const ['y'] : const [],
              risque: r,
            ).niveau;
            final cas = '${g.name} alarme=$alarme autre=$autre ${r.name}';
            expect(n, inInclusiveRange(1, 4), reason: cas);
            if (alarme && g.index >= Grade.grade2.index) expect(n, 4, reason: cas);
            if (alarme) expect(n, greaterThanOrEqualTo(3), reason: cas);
            if (g == Grade.grade3) expect(n, greaterThanOrEqualTo(3), reason: cas);
          }
        }
      }
    }
  });

  group('Jours de calendrier et heure d’été', () {
    test('Passage à l’heure d’été (mars) : 4 jours = 0, 1, 2, 3', () {
      final d0 = DateTime(2027, 3, 13);
      expect([for (var k = 0; k < 4; k++) joursEntre(d0, DateTime(2027, 3, 13 + k, 8))], [0, 1, 2, 3]);
    });
    test('Retour à l’heure normale (novembre)', () {
      final d0 = DateTime(2026, 10, 31);
      expect([for (var k = 0; k < 4; k++) joursEntre(d0, DateTime(2026, 10, 31 + k, 23, 30))], [0, 1, 2, 3]);
    });
    test('jourDecale tombe toujours à minuit', () {
      final d = jourDecale(DateTime(2026, 11, 3, 15), -3);
      expect([d.year, d.month, d.day, d.hour], [2026, 10, 31, 0]);
    });
  });

  group('Courriel au médecin : un seul par crise', () {
    final t0 = DateTime(2026, 11, 22, 20);
    test('1re mesure sans épisode + re-mesures avec épisode = 1 seule alerte', () {
      final l = Cloud.nouvellesCrises([
        crise(t0),
        crise(t0.add(const Duration(minutes: 5)), episode: 'E1'),
        crise(t0.add(const Duration(minutes: 10)), episode: 'E1'),
      ], const [], 0);
      expect(l.length, 1);
    });
    test('Déjà envoyée : une re-mesure 30 min après ne renvoie rien', () {
      final l = Cloud.nouvellesCrises([crise(t0.add(const Duration(minutes: 30)), episode: 'E1')], const [], t0.millisecondsSinceEpoch);
      expect(l, isEmpty);
    });
    test('Nouvelle crise le lendemain = nouvelle alerte', () {
      final l = Cloud.nouvellesCrises([crise(t0.add(const Duration(days: 1)))], const [], t0.millisecondsSinceEpoch);
      expect(l.length, 1);
    });
    test('Mesures de niveau < 4 : aucune alerte', () {
      expect(Cloud.nouvellesCrises([crise(t0, niveau: 3)], const [], 0), isEmpty);
    });
  });
}
