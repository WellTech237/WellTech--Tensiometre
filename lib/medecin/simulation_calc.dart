// Simulation de dose pour le médecin, avec le modèle d'équations du client
// (core/modele_edo.dart). Sans Flutter : testable.
//
// Hypothèse affichée au médecin : 1 mg de la dose = 1 unité de
// concentration C(0) (le modèle du client utilise C0 = 10 pour 10 mg).
// t est en heures (unité du modèle).

import '../core/controle.dart';
import '../core/modele_edo.dart';

/// TAS en dessous de laquelle on signale un risque d'hypotension.
const seuilHypotension = 100.0;

/// Délai visé pour ramener la TAS sous 130 mmHg (heures).
const objectifHeures = 4.0;

class ResultatDose {
  final double dose;
  final double tasMin;
  final double tMin; // heure du minimum
  final double? t130; // première heure où TAS < 130 (null : jamais en 24 h)
  final double tas24; // TAS à la fin de la simulation
  const ResultatDose(this.dose, this.tasMin, this.tMin, this.t130, this.tas24);

  bool get sur => tasMin >= seuilHypotension;
  bool get efficace => t130 != null && t130! <= objectifHeures;
}

ModeleTension modelePour(double ps0, double pd0, double dose) =>
    ModeleTension(ParametresModele(ps0: ps0, pd0: pd0, c0: dose));

ResultatDose evaluerDose(double ps0, double pd0, double dose, {double duree = 24, double pas = 0.05}) {
  final m = modelePour(ps0, pd0, dose);
  var tasMin = m.ps(0), tMin = 0.0;
  double? t130 = m.ps(0) < 130 ? 0 : null;
  final n = (duree / pas).round();
  for (var i = 1; i <= n; i++) {
    final t = i * pas;
    final v = m.ps(t);
    if (v < tasMin) {
      tasMin = v;
      tMin = t;
    }
    if (t130 == null && v < 130) t130 = t;
  }
  return ResultatDose(dose, tasMin, tMin, t130, m.ps(duree));
}

/// Doses de 0 à [max] mg par paliers (comprimés de 2,5 mg).
List<ResultatDose> courbeDoseReponse(double ps0, double pd0, {double palier = 2.5, double max = 20}) => [
      for (var d = 0.0; d <= max + 1e-9; d += palier) evaluerDose(ps0, pd0, d),
    ];

/// Plus petite dose qui ramène la TAS sous 130 en moins de [objectifHeures]
/// sans jamais descendre sous [seuilHypotension]. null si aucune.
double? doseMinimaleEfficace(double ps0, double pd0, {double palier = 2.5, double max = 20}) {
  for (final r in courbeDoseReponse(ps0, pd0, palier: palier, max: max)) {
    if (r.efficace && r.sur) return r.dose;
  }
  return null;
}

/// Écart maximal entre la résolution numérique (RK4) et la solution exacte
/// sur [duree] heures : preuve que le code résout bien le système du client.
double ecartRk4(double ps0, double pd0, double dose, {double duree = 24}) {
  final m = modelePour(ps0, pd0, dose);
  var ecart = 0.0;
  for (final (t, g, _) in m.simuler(duree: duree, pas: 0.05)) {
    final e1 = (g.tas - m.ps(t)).abs();
    final e2 = (g.tad - m.pd(t)).abs();
    if (e1 > ecart) ecart = e1;
    if (e2 > ecart) ecart = e2;
  }
  return ecart;
}

/// Points (t, valeur) d'une grandeur sur [duree] heures, pour le graphique.
List<(double, double)> courbe(double ps0, double pd0, double dose, Grandeur g, {double duree = 24, double pas = 0.25}) {
  final m = modelePour(ps0, pd0, dose);
  return [
    for (var i = 0; i <= (duree / pas).round(); i++) (i * pas, m.grandeurs(i * pas).de(g)),
  ];
}
