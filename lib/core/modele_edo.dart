// Modèle d'équations différentielles du projet (forme matricielle partagée) :
//
//   x1 = Ps − 120   (écart de la pression systolique à sa cible)
//   x2 = Pd − 80    (écart de la pression diastolique à sa cible)
//   C  = concentration du médicament
//
//   dX/dt = A · X  avec  X = [x1, x2, C]ᵀ  et
//   A = [ −a1   0   −γ1 ]
//       [  0   −a2  −γ2 ]
//       [  0    0   −k  ]
//
// Valeurs du projet : a1 = 0,4 ; a2 = 0,2 ; γ1 = 1,5 ; γ2 = 0,8 ; k = 0,5 ;
// Ps(0) = 160, Pd(0) = 100, C(0) = 10.
//
// Solution exacte (constantes recalculées avec la condition initiale) :
//   Ps(t) = 120 − 110·e^(−0,4t) + 150·e^(−0,5t)
//   Pd(t) =  80 − 6,67·e^(−0,2t) + 26,67·e^(−0,5t)
//   Pp(t) = Ps − Pd,  Pm(t) = Pd + ⅓·Pp
//
// Ce module sert à l'espace médecin et aux tests ; l'application de la
// patiente ne propose JAMAIS de changer la dose.

import 'dart:math' as math;

import 'controle.dart';

class ParametresModele {
  final double a1, a2, g1, g2, k;
  final double ps0, pd0, c0;
  const ParametresModele({
    this.a1 = 0.4,
    this.a2 = 0.2,
    this.g1 = 1.5,
    this.g2 = 0.8,
    this.k = 0.5,
    this.ps0 = 160,
    this.pd0 = 100,
    this.c0 = 10,
  });

  /// Matrice A du système dX/dt = A·X.
  List<List<double>> get matrice => [
        [-a1, 0, -g1],
        [0, -a2, -g2],
        [0, 0, -k],
      ];
}

class ModeleTension {
  final ParametresModele p;
  const ModeleTension([this.p = const ParametresModele()]);

  // Solution particulière B·e^(−kt) : B = −γ·C0 / (a − k) ; puis K = x(0) − B.
  double get _b1 => -p.g1 * p.c0 / (p.a1 - p.k);
  double get _b2 => -p.g2 * p.c0 / (p.a2 - p.k);
  double get _k1 => (p.ps0 - cibleTas) - _b1;
  double get _k2 => (p.pd0 - cibleTad) - _b2;

  /// Constantes de la solution exacte (K1, B1, K2, B2), pour le rapport.
  ({double k1, double b1, double k2, double b2}) get constantes => (k1: _k1, b1: _b1, k2: _k2, b2: _b2);

  double concentration(double t) => p.c0 * math.exp(-p.k * t);

  /// Pression systolique Ps(t), t en heures (unité du modèle).
  double ps(double t) => cibleTas + _k1 * math.exp(-p.a1 * t) + _b1 * math.exp(-p.k * t);

  /// Pression diastolique Pd(t).
  double pd(double t) => cibleTad + _k2 * math.exp(-p.a2 * t) + _b2 * math.exp(-p.k * t);

  Grandeurs grandeurs(double t) => Grandeurs(ps(t), pd(t));
  double pp(double t) => ps(t) - pd(t);
  double pm(double t) => pd(t) + pp(t) / 3;

  /// Résolution numérique (Runge-Kutta 4) de dX/dt = A·X : sert à vérifier la
  /// solution exacte et à simuler des doses répétées.
  /// [prises] : instants (même unité que t) et quantité ajoutée à C.
  List<(double t, Grandeurs g, double c)> simuler({
    required double duree,
    double pas = 0.05,
    List<(double t, double dose)> prises = const [],
  }) {
    final a = p.matrice;
    var x = [p.ps0 - cibleTas, p.pd0 - cibleTad, p.c0];
    List<double> f(List<double> v) => [
          for (var i = 0; i < 3; i++) a[i][0] * v[0] + a[i][1] * v[1] + a[i][2] * v[2],
        ];
    final res = <(double, Grandeurs, double)>[(0.0, Grandeurs(x[0] + cibleTas, x[1] + cibleTad), x[2])];
    var t = 0.0;
    final restantes = [...prises]..sort((u, v) => u.$1.compareTo(v.$1));
    while (t < duree - 1e-9) {
      while (restantes.isNotEmpty && restantes.first.$1 <= t + 1e-9) {
        x[2] += restantes.removeAt(0).$2;
      }
      final h = math.min(pas, duree - t);
      final k1 = f(x);
      final k2 = f([for (var i = 0; i < 3; i++) x[i] + h / 2 * k1[i]]);
      final k3 = f([for (var i = 0; i < 3; i++) x[i] + h / 2 * k2[i]]);
      final k4 = f([for (var i = 0; i < 3; i++) x[i] + h * k3[i]]);
      x = [for (var i = 0; i < 3; i++) x[i] + h / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i])];
      t += h;
      res.add((t, Grandeurs(x[0] + cibleTas, x[1] + cibleTad), x[2]));
    }
    return res;
  }
}

/// Correction de dose proposée par une loi PID (aide à la décision du MÉDECIN).
/// e = TAS mesurée − cible ; la dose est arrondie au comprimé et bornée.
class CorrecteurDose {
  final double kp, ki, kd;
  final double doseBase, doseMin, doseMax, palier;
  const CorrecteurDose({
    this.kp = 1.0,
    this.ki = 0.4,
    this.kd = 0.5,
    this.doseBase = 5,
    this.doseMin = 0,
    this.doseMax = 20,
    this.palier = 2.5,
  });

  /// [erreurs] : erreurs successives (une par jour), la dernière en dernier.
  double proposer(List<double> erreurs) {
    if (erreurs.isEmpty) return doseBase;
    final e = erreurs.last;
    final somme = erreurs.reduce((a, b) => a + b);
    final de = erreurs.length > 1 ? e - erreurs[erreurs.length - 2] : 0.0;
    final u = doseBase + kp * e + ki * somme + kd * de;
    final arrondi = (u / palier).roundToDouble() * palier;
    return arrondi.clamp(doseMin, doseMax).toDouble();
  }
}
