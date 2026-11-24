import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/core/controle.dart';
import 'package:welltech/core/modele_edo.dart';

void main() {
  group('4 grandeurs (définitions du client)', () {
    test('Pp = TAS − TAD et Pm = TAD + ⅓(TAS − TAD)', () {
      const g = Grandeurs(150, 90);
      expect(g.pp, 60);
      expect(g.pm, 110);
    });

    test('cibles du modèle : 120 / 80, donc Pp 40 et Pm ≈ 93,3', () {
      expect(cibles[Grandeur.tas], 120);
      expect(cibles[Grandeur.tad], 80);
      expect(cibles[Grandeur.pp], 40);
      expect(cibles[Grandeur.pm]!, closeTo(93.33, 0.01));
    });

    test('erreur = mesure − cible', () {
      expect(erreur(Grandeur.tas, 148), 28);
      expect(erreur(Grandeur.tad, 76), -4);
    });

    test('statut : 4 dans la plage = très bien, 0 = très mal, sinon partiel', () {
      expect(statutControle(const Grandeurs(118, 76)), StatutControle.tresBien); // Pm 90, Pp 42
      expect(statutControle(const Grandeurs(148, 92)), StatutControle.partiel); // seule Pp (56) est normale
      expect(statutControle(const Grandeurs(200, 130)), StatutControle.tresMal); // Pm 153, Pp 70
    });
  });

  group('Dérivée, intégrale, limites', () {
    const pts = [
      Point(0, Grandeurs(150, 95)),
      Point(1, Grandeurs(148, 94)),
      Point(2, Grandeurs(146, 92)),
      Point(3, Grandeurs(144, 91)),
    ];

    test('dérivée = pente des moindres carrés (−2 mmHg/jour)', () {
      expect(derivee(pts, Grandeur.tas), closeTo(-2, 1e-9));
      expect(Indicateurs.de(pts).deriveeParSemaine, closeTo(-14, 1e-9));
    });

    test('intégrale = erreur accumulée (trapèzes) par rapport à 120', () {
      // (30+28)/2 + (28+26)/2 + (26+24)/2 = 29 + 27 + 25 = 81
      expect(integrale(pts, Grandeur.tas), closeTo(81, 1e-9));
    });

    test('limites : % dans la plage et retour durable', () {
      const l = [Point(0, Grandeurs(140, 90)), Point(1, Grandeurs(126, 78)), Point(2, Grandeurs(124, 76))];
      final r = limites(l);
      expect(r.pourcentDansPlage, closeTo(66.7, 0.1));
      expect(r.retourDurable, 1);
      expect(limites(const [Point(0, Grandeurs(140, 90))]).retourDurable, isNull);
    });
  });

  group('Modèle d’équations différentielles', () {
    const m = ModeleTension();

    test('constantes : K1 = −110, B1 = 150, K2 ≈ −6,67, B2 ≈ 26,67', () {
      final c = m.constantes;
      expect(c.k1, closeTo(-110, 1e-9));
      expect(c.b1, closeTo(150, 1e-9));
      expect(c.k2, closeTo(-6.667, 1e-3));
      expect(c.b2, closeTo(26.667, 1e-3));
    });

    test('conditions initiales et valeurs connues', () {
      expect(m.ps(0), closeTo(160, 1e-9));
      expect(m.pd(0), closeTo(100, 1e-9));
      expect(m.ps(1), closeTo(137.244, 1e-3));
      expect(m.pd(5), closeTo(79.736, 1e-3));
      expect(m.pp(10), closeTo(39.719, 1e-3));
      expect(m.pm(30), closeTo(93.322, 1e-3));
    });

    test('Runge-Kutta 4 retrouve la solution exacte', () {
      final r = m.simuler(duree: 10, pas: 0.01);
      for (final (t, g, _) in r.where((e) => (e.$1 * 100).round() % 100 == 0)) {
        expect(g.tas, closeTo(m.ps(t), 1e-4));
        expect(g.tad, closeTo(m.pd(t), 1e-4));
      }
    });

    test('à long terme : TAS → 120 et TAD → 80', () {
      expect(m.ps(60), closeTo(120, 0.01));
      expect(m.pd(60), closeTo(80, 0.01));
    });

    test('correcteur de dose (médecin) : arrondi au comprimé et borné', () {
      const c = CorrecteurDose();
      expect(c.proposer([]), 5);
      expect(c.proposer([0]), 5);
      final d = c.proposer([10, 8]);
      expect(d % 2.5, 0);
      expect(d, inInclusiveRange(0, 20));
      expect(c.proposer([100, 100]), 20);
    });
  });
}
