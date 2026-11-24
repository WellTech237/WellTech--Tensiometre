import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/core/classification.dart';
import 'package:welltech/core/controle.dart';
import 'package:welltech/core/risque.dart';
import 'package:welltech/data/models.dart';
import 'package:welltech/medecin/calculs.dart';
import 'package:welltech/medecin/simulation_calc.dart';

MesureM m(DateTime d, int s, int di, {int niveau = 1, String? episode, bool annulee = false, String id = ''}) => MesureM(
      id: id.isEmpty ? '${d.millisecondsSinceEpoch}' : id,
      date: d,
      tas: s,
      tad: di,
      grade: classer(s, di),
      niveau: niveau,
      episode: episode,
      annulee: annulee,
    );

void main() {
  final maintenant = DateTime(2026, 11, 22, 10);
  final auj = minuit(maintenant);

  group('Espace médecin : calculs', () {
    test('Points journaliers : moyenne du jour, sans crises ni mesures annulées', () {
      final l = [
        m(auj.subtract(const Duration(days: 1, hours: -8)), 140, 90),
        m(auj.subtract(const Duration(days: 1, hours: -20)), 130, 80),
        m(auj.add(const Duration(hours: 8)), 190, 125, episode: 'e1', niveau: 4),
        m(auj.add(const Duration(hours: 9)), 200, 130, annulee: true),
      ];
      final pts = pointsJournaliers(l, auj.subtract(const Duration(days: 1)));
      expect(pts.length, 1);
      expect(pts.first.t, 0);
      expect(pts.first.v.tas, 135);
      expect(pts.first.v.tad, 85);
    });

    test('Observance : prises « pris » depuis la première prise notée', () {
      final prises = [
        PriseM(jour: auj.subtract(const Duration(days: 3)), statut: 'pris'),
        PriseM(jour: auj.subtract(const Duration(days: 2)), statut: 'oubli'),
        PriseM(jour: auj.subtract(const Duration(days: 1)), statut: 'pris'),
        PriseM(jour: auj, statut: 'annule'),
      ];
      final o = observance(prises, auj.subtract(const Duration(days: 27)), maintenant)!;
      expect(o.jours, 4);
      expect(o.prises, 2);
      expect(o.taux, 0.5);
      expect(observance(const [], auj, maintenant), isNull);
    });

    test('Priorité : une alerte 911 récente place la patiente en urgence', () {
      final r = resumer(
        uid: 'u1',
        profil: Profil(prenom: 'Marie'),
        mesures: [m(maintenant.subtract(const Duration(hours: 3)), 192, 118, niveau: 4)],
        prises: const [],
        messages: const [],
        maintenant: maintenant,
      );
      expect(r.priorite, Priorite.urgence);
      expect(r.alertes, 1);
    });

    test('Priorité : tension normale chaque jour, sans message = stable', () {
      final r = resumer(
        uid: 'u2',
        profil: Profil(prenom: 'Claire'),
        mesures: [for (var i = 0; i < 7; i++) m(auj.subtract(Duration(days: i)).add(const Duration(hours: 8)), 118, 76)],
        prises: const [],
        messages: const [],
        maintenant: maintenant,
      );
      expect(r.priorite, Priorite.stable);
      expect(r.semaine.statut, StatutControle.tresBien);
      expect(r.quatreOk, [true, true, true, true]);
    });

    test('Un message non lu de la patiente la place « à voir »', () {
      final r = resumer(
        uid: 'u3',
        profil: Profil(),
        mesures: [m(maintenant.subtract(const Duration(hours: 2)), 118, 76)],
        prises: const [],
        messages: [MessageM(id: 'x', date: maintenant, deMoi: true, texte: 'Bonjour')],
        maintenant: maintenant,
      );
      expect(r.priorite, Priorite.aVoir);
      expect(r.nonLus, 1);
    });

    test('Tri : urgences, puis à voir, puis stables', () {
      ResumePatient p(String uid, Priorite pr) => ResumePatient(
            uid: uid,
            profil: Profil(),
            risque: Risque.standard,
            derniere: null,
            semaine: Indicateurs.de(const []),
            tendance: 0,
            obs: null,
            alertes: 0,
            nonLus: 0,
            mesures7: 0,
            priorite: pr,
          );
      final t = trierPatients([p('a', Priorite.stable), p('b', Priorite.urgence), p('c', Priorite.aVoir)]);
      expect(t.map((x) => x.uid).toList(), ['b', 'c', 'a']);
    });

    test('Avant / après un changement de dose', () {
      final c = auj.subtract(const Duration(days: 3));
      final l = [
        m(c.subtract(const Duration(days: 2)), 150, 95),
        m(c.subtract(const Duration(days: 1)), 146, 93),
        m(c.add(const Duration(hours: 9)), 136, 86),
        m(c.add(const Duration(days: 1, hours: 9)), 132, 84),
      ];
      final r = avantApres(l, c);
      expect(r.avant!.tas, 148);
      expect(r.apres!.tas, 134);
    });
  });

  group('Simulation de dose (modèle du client)', () {
    test('Sans médicament, la TAS revient vers 120 sans descendre dessous', () {
      final r = evaluerDose(160, 100, 0);
      expect(r.tasMin, greaterThanOrEqualTo(120));
      expect(r.sur, isTrue);
    });

    test('Avec C0 = 10 (10 mg), on retrouve la solution du client', () {
      final r = evaluerDose(160, 100, 10);
      // Ps(t) = 120 − 110·e^(−0,4t) + 150·e^(−0,5t) : minimum ≈ 117,4 vers t ≈ 5,3 h
      expect(r.tasMin, closeTo(117.4, 0.2));
      expect(r.tMin, closeTo(5.3, 0.1));
      expect(r.sur, isTrue);
    });

    test('Plus de dose = TAS plus basse ; la dose minimale efficace est sûre', () {
      final c = courbeDoseReponse(170, 100);
      for (var i = 1; i < c.length; i++) {
        expect(c[i].tasMin, lessThanOrEqualTo(c[i - 1].tasMin));
      }
      final d = doseMinimaleEfficace(170, 100);
      expect(d, isNotNull);
      final r = evaluerDose(170, 100, d!);
      expect(r.efficace && r.sur, isTrue);
    });

    test('RK4 colle à la solution exacte', () {
      expect(ecartRk4(160, 100, 10), lessThan(0.01));
    });
  });
}
