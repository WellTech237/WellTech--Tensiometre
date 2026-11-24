// Classification de la tension artérielle selon les lignes directrices
// AHA/ACC 2025 (catégories adultes) et seuils propres à la grossesse.
// Tout est calculé sur le téléphone : fonctionne sans Internet.

import '../l10n.dart';

enum Grade { normale, elevee, grade1, grade2, grade3 }

extension GradeInfo on Grade {
  /// Libellé complet traduit (ex. « Stade 2 · tension haute »).
  String get libelle => trL('g_$name');

  /// Libellé court traduit (ex. « Stade 2 »).
  String get court => trL('gc_$name');

  /// Icône d'accompagnement (jamais la couleur seule).
  String get icone => const {
        Grade.normale: '✓',
        Grade.elevee: '•',
        Grade.grade1: '!',
        Grade.grade2: '⚠',
        Grade.grade3: '⚠',
      }[this]!;
}

/// Bornes de vraisemblance : au-delà, on demande de vérifier la saisie.
/// Ce ne sont PAS des seuils médicaux, seulement un garde-fou contre les fautes de frappe.
class Bornes {
  static const tasMin = 70, tasMax = 250;
  static const tadMin = 40, tadMax = 150;
  static const poulsMin = 30, poulsMax = 220;
}

/// Renvoie un message d'erreur, ou null si les valeurs sont plausibles.
String? verifierValeurs({int? tas, int? tad, int? pouls}) {
  if (tas != null && (tas < Bornes.tasMin || tas > Bornes.tasMax)) {
    return trL('err_plage', {'a': Bornes.tasMin, 'b': Bornes.tasMax});
  }
  if (tad != null && (tad < Bornes.tadMin || tad > Bornes.tadMax)) {
    return trL('err_plage', {'a': Bornes.tadMin, 'b': Bornes.tadMax});
  }
  if (tas != null && tad != null && tas <= tad) {
    return trL('err_ordre');
  }
  if (pouls != null && (pouls < Bornes.poulsMin || pouls > Bornes.poulsMax)) {
    return trL('err_plage', {'a': Bornes.poulsMin, 'b': Bornes.poulsMax});
  }
  return null;
}

/// Classe une tension (adulte, hors grossesse).
/// Normale < 120 et < 80 ; Élevée 120-129 et < 80 ; Stade 1 130-139 ou 80-89 ;
/// Stade 2 >= 140 ou >= 90 ; Sévère > 180 et/ou > 120.
Grade classer(int tas, int tad) {
  if (tas > 180 || tad > 120) return Grade.grade3;
  if (tas >= 140 || tad >= 90) return Grade.grade2;
  if (tas >= 130 || tad >= 80) return Grade.grade1;
  if (tas >= 120) return Grade.elevee;
  return Grade.normale;
}

/// Grossesse : HTA dès 140/90, sévère dès 160/110.
Grade classerGrossesse(int tas, int tad) {
  if (tas >= 160 || tad >= 110) return Grade.grade3;
  if (tas >= 140 || tad >= 90) return Grade.grade2;
  return Grade.normale;
}

Grade classerPour(int tas, int tad, {required bool enceinte}) =>
    enceinte ? classerGrossesse(tas, tad) : classer(tas, tad);

/// Grade de la TAS seule (pour les bandes de couleur des graphiques).
Grade gradeTas(int v) => v > 180
    ? Grade.grade3
    : v >= 140
        ? Grade.grade2
        : v >= 130
            ? Grade.grade1
            : v >= 120
                ? Grade.elevee
                : Grade.normale;

/// Grade de la TAD seule.
Grade gradeTad(int v) => v > 120
    ? Grade.grade3
    : v >= 90
        ? Grade.grade2
        : v >= 80
            ? Grade.grade1
            : Grade.normale;

String etatPouls(int bpm) => trL(bpm < 60 ? 'pouls_lent' : (bpm > 100 ? 'pouls_rapide' : 'pouls_normal'));
