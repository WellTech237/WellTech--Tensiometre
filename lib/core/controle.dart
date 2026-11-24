// Calculs demandés par le client (courriel du projet GNG 1503) :
// 4 grandeurs suivies ensemble (TAS, TAD, Pm, Pp), cible, valeur mesurée,
// erreur, dérivée, intégrale (erreur accumulée), limites et statut
// « très bien / partiellement / très mal contrôlée ».
// Tout est calculé sur le téléphone, sans Internet.

import 'dart:math' as math;

/// Les 4 grandeurs suivies.
enum Grandeur { tas, tad, pm, pp }

/// Une tension mesurée et les 2 grandeurs qui en découlent :
///   Pp = TAS − TAD                (pression pulsée)
///   Pm = TAD + ⅓ (TAS − TAD)      (pression moyenne)
/// Ce sont les mêmes relations que dans le modèle du client
/// (Pp = Ps − Pd et Pm = Pd + ⅓ Pp).
class Grandeurs {
  final double tas;
  final double tad;
  const Grandeurs(this.tas, this.tad);

  double get pp => tas - tad;
  double get pm => tad + (tas - tad) / 3;

  double de(Grandeur g) => switch (g) {
        Grandeur.tas => tas,
        Grandeur.tad => tad,
        Grandeur.pm => pm,
        Grandeur.pp => pp,
      };
}

/// Plage normale d'une grandeur (bornes incluses).
class Plage {
  final double min;
  final double max;
  const Plage(this.min, this.max);
  bool contient(double v) => v >= min && v <= max;
}

/// Limites normales utilisées (à valider avec une source médicale).
const plages = <Grandeur, Plage>{
  Grandeur.tas: Plage(90, 129),
  Grandeur.tad: Plage(60, 79),
  Grandeur.pm: Plage(70, 100),
  Grandeur.pp: Plage(30, 60),
};

/// Cibles du modèle du client : la TAS tend vers 120 mmHg et la TAD vers
/// 80 mmHg ; d'où Pp = 40 mmHg et Pm = 80 + 40/3 ≈ 93,3 mmHg.
const cibleTas = 120.0;
const cibleTad = 80.0;
const cibles = <Grandeur, double>{
  Grandeur.tas: cibleTas,
  Grandeur.tad: cibleTad,
  Grandeur.pm: cibleTad + (cibleTas - cibleTad) / 3,
  Grandeur.pp: cibleTas - cibleTad,
};

/// Erreur = valeur mesurée − cible (positive : au-dessus de la cible).
double erreur(Grandeur g, double mesure) => mesure - cibles[g]!;

bool dansLaPlage(Grandeur g, double v) => plages[g]!.contient(v);

/// Nombre de grandeurs (sur 4) dans leur plage normale.
int nbDansLaPlage(Grandeurs x) => Grandeur.values.where((g) => dansLaPlage(g, x.de(g))).length;

enum StatutControle { tresBien, partiel, tresMal }

/// Définitions du client :
/// - très bien contrôlée : les 4 grandeurs dans leur plage ;
/// - très mal contrôlée : aucune des 4 ;
/// - partiellement contrôlée : entre les deux.
StatutControle statutControle(Grandeurs x) {
  final n = nbDansLaPlage(x);
  if (n == 4) return StatutControle.tresBien;
  if (n == 0) return StatutControle.tresMal;
  return StatutControle.partiel;
}

/// Moyenne d'un jour (ou d'une séance) : t en jours depuis le début de la période.
class Point {
  final double t;
  final Grandeurs v;
  const Point(this.t, this.v);
}

/// Moyenne des grandeurs d'une liste de points (null si vide).
Grandeurs? moyenne(List<Point> pts) {
  if (pts.isEmpty) return null;
  final s = pts.fold<double>(0, (a, p) => a + p.v.tas) / pts.length;
  final d = pts.fold<double>(0, (a, p) => a + p.v.tad) / pts.length;
  return Grandeurs(s, d);
}

/// DÉRIVÉE : vitesse de variation de la grandeur, en mmHg par jour.
/// On prend la pente de la droite des moindres carrés : plus robuste qu'une
/// simple différence entre deux mesures (une mesure isolée ne fausse pas tout).
/// Renvoie 0 s'il y a moins de 2 points ou un seul jour.
double derivee(List<Point> pts, Grandeur g) {
  if (pts.length < 2) return 0;
  final n = pts.length;
  final mt = pts.fold<double>(0, (a, p) => a + p.t) / n;
  final mv = pts.fold<double>(0, (a, p) => a + p.v.de(g)) / n;
  var num = 0.0, den = 0.0;
  for (final p in pts) {
    num += (p.t - mt) * (p.v.de(g) - mv);
    den += (p.t - mt) * (p.t - mt);
  }
  return den == 0 ? 0 : num / den;
}

/// INTÉGRALE : erreur accumulée ∫ (valeur − cible) dt, en mmHg·jour,
/// par la méthode des trapèzes entre les points (triés par t).
/// Positive : la grandeur est restée surtout au-dessus de sa cible.
double integrale(List<Point> pts, Grandeur g) {
  if (pts.length < 2) return 0;
  final l = [...pts]..sort((a, b) => a.t.compareTo(b.t));
  var s = 0.0;
  for (var i = 1; i < l.length; i++) {
    final e0 = erreur(g, l[i - 1].v.de(g));
    final e1 = erreur(g, l[i].v.de(g));
    s += (e0 + e1) / 2 * (l[i].t - l[i - 1].t);
  }
  return s;
}

/// LIMITES : part des points dans la plage pour les 4 grandeurs, et premier
/// point à partir duquel la grandeur reste dans sa plage jusqu'à la fin.
class Limites {
  /// % de points où les 4 grandeurs sont dans leur plage (0 à 100).
  final double pourcentDansPlage;

  /// t (jours) du retour durable dans la plage de la TAS et de la TAD, ou null.
  final double? retourDurable;
  const Limites(this.pourcentDansPlage, this.retourDurable);
}

Limites limites(List<Point> pts) {
  if (pts.isEmpty) return const Limites(0, null);
  final l = [...pts]..sort((a, b) => a.t.compareTo(b.t));
  final ok = l.where((p) => nbDansLaPlage(p.v) == 4).length;
  double? retour;
  for (var i = l.length - 1; i >= 0; i--) {
    final p = l[i].v;
    if (dansLaPlage(Grandeur.tas, p.tas) && dansLaPlage(Grandeur.tad, p.tad)) {
      retour = l[i].t;
    } else {
      break;
    }
  }
  return Limites(100 * ok / l.length, retour);
}

Grandeurs? _moyenneDe(List<Point> pts) => moyenne(pts);
Limites _limitesDe(List<Point> pts) => limites(pts);

/// Les 3 indicateurs du client réunis, calculés sur une période.
class Indicateurs {
  final Grandeurs? moyenne;
  final StatutControle? statut;
  final int nbDansPlage;
  final double deriveeParSemaine; // TAS, mmHg / semaine
  final double integraleTas; // mmHg·jour par rapport à la cible 120
  final Limites limites;
  final int nbPoints;
  const Indicateurs({
    required this.moyenne,
    required this.statut,
    required this.nbDansPlage,
    required this.deriveeParSemaine,
    required this.integraleTas,
    required this.limites,
    required this.nbPoints,
  });

  static Indicateurs de(List<Point> pts) {
    // Les champs « moyenne » et « limites » masquent les fonctions du même
    // nom dans la classe : on passe par les alias _moyenneDe / _limitesDe.
    final m = _moyenneDe(pts);
    return Indicateurs(
      moyenne: m,
      statut: m == null ? null : statutControle(m),
      nbDansPlage: m == null ? 0 : nbDansLaPlage(m),
      deriveeParSemaine: derivee(pts, Grandeur.tas) * 7,
      integraleTas: integrale(pts, Grandeur.tas),
      limites: _limitesDe(pts),
      nbPoints: pts.length,
    );
  }
}

/// Nombre de jours de CALENDRIER entre deux dates (b − a), insensible à
/// l'heure d'été : entre deux minuits locaux il n'y a pas toujours 24 h
/// (23 h en mars, 25 h en novembre), d'où un calcul sur les dates seules.
int joursEntre(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Minuit local du jour situé [n] jours de calendrier après [d] (n < 0 : avant).
DateTime jourDecale(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Arrondi d'affichage (1 décimale).
double arrondi1(double v) => (v * 10).roundToDouble() / 10;

/// Écart-type simple (utile pour signaler des mesures très variables).
double ecartType(List<double> v) {
  if (v.length < 2) return 0;
  final m = v.reduce((a, b) => a + b) / v.length;
  return math.sqrt(v.fold<double>(0, (a, x) => a + (x - m) * (x - m)) / (v.length - 1));
}
