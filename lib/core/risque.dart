import '../data/models.dart';
import '../l10n.dart';
import 'classification.dart';

/// Profil de risque (règles proposées par l'équipe, à valider avec le client).
enum Risque { standard, modere, eleve, tresEleve, grossesse }

extension RisqueInfo on Risque {
  String get libelle => trL('risque_$name');
  String get effet => trL('risque_effet_$name');

  /// Les profils élevés font monter les alertes d'un niveau.
  bool get renforce => this == Risque.eleve || this == Risque.tresEleve;
}

/// Antécédents enregistrés dans le profil (valeurs stockées en français,
/// affichées dans la langue choisie avec [nomMaladie]).
const maladiesListe = <String>[
  'Diabète',
  'Maladie rénale',
  'Maladie cardiaque',
  'Cholestérol élevé',
  'Apnée du sommeil',
  'HTA dans la famille',
  'Tabac',
];

const emojisMaladies = <String>['🩸', '🫘', '❤️', '🍳', '😴', '👪', '🚬'];

String nomMaladie(String m) {
  final i = maladiesListe.indexOf(m);
  return i < 0 ? m : trL('mal_$i');
}

List<String> facteurs(Profil p) {
  final f = <String>[];
  final age = p.age;
  if (age != null && age >= 65) f.add(trL('facteur_age', {'a': age}));
  final imc = p.imc;
  if (imc != null && imc >= 30) f.add('IMC ${nombre(imc)}');
  f.addAll(p.maladies.where(maladiesListe.contains).map(nomMaladie));
  if (p.autreMaladie.trim().isNotEmpty) f.add(p.autreMaladie.trim());
  return f;
}

Risque calculerRisque(Profil p) {
  if (p.grossesseActive) return Risque.grossesse;
  if (p.avc) return Risque.tresEleve;
  final n = facteurs(p).length;
  final cardiaque = p.maladies.contains('Maladie cardiaque');
  if (n >= 2 || cardiaque) return Risque.eleve;
  if (n == 1) return Risque.modere;
  return Risque.standard;
}

/// Un symptôme proposé après la mesure.
/// [alarme] : signe d'alarme AHA/ACC (avec une tension sévère : 911).
class Symptome {
  final String id;
  final String emoji;
  final bool alarme;
  const Symptome(this.id, this.emoji, this.alarme);
  String get libelle => trL('sym_$id');
}

const symptomesBase = <Symptome>[
  Symptome('poitrine', '🫀', true),
  Symptome('souffle', '😮‍💨', true),
  Symptome('faiblesse', '🖐️', true),
  Symptome('vision', '👁️', true),
  Symptome('parole', '🗣️', true),
  Symptome('dos', '🦴', true),
  Symptome('tete', '🤕', false),
];

/// Pendant la grossesse, le mal de tête fort devient un signe d'alarme et
/// 2 signes s'ajoutent.
const symptomesGrossesse = <Symptome>[
  Symptome('ventre', '😣', true),
  Symptome('gonflement', '🦶', true),
];

List<Symptome> symptomesPour({required bool grossesse}) => [
      for (final s in symptomesBase) grossesse && s.id == 'tete' ? const Symptome('tete', '🤕', true) : s,
      if (grossesse) ...symptomesGrossesse,
    ];

class DecisionAlerte {
  final int niveau; // 1 Information, 2 Attention, 3 Médecin, 4 Urgence
  final String cleTitre;
  final String cleConseil;
  const DecisionAlerte(this.niveau, this.cleTitre, this.cleConseil);

  String get titre => trL(cleTitre);
  String get conseil => trL(cleConseil);
  String get nomNiveau => trL('niveau_$niveau');
}

/// Matrice d'alertes : grade × symptômes × profil.
/// - symptomesCoches : signes d'alarme cochés ;
/// - symptomesAutres : autres symptômes (mal de tête hors grossesse, « Autre ») :
///   transmis au médecin, ils ne déclenchent pas l'urgence à eux seuls.
DecisionAlerte deciderAlerte({
  required Grade grade,
  required List<String> symptomesCoches,
  required List<String> symptomesAutres,
  required Risque risque,
}) {
  final alarme = symptomesCoches.isNotEmpty;
  final unSymptome = alarme || symptomesAutres.isNotEmpty;

  // Signe d'alarme : appeler le 911, quelle que soit la tension (consigne AHA :
  // douleur à la poitrine, difficulté à parler… ne doivent jamais attendre).
  if (alarme && (grade == Grade.grade3 || grade.index >= Grade.grade2.index)) {
    return const DecisionAlerte(4, 'd4_titre', 'd4_conseil');
  }

  int niveau;
  if (grade == Grade.grade3) {
    niveau = 3;
  } else if (grade == Grade.grade2 || grade == Grade.grade1) {
    niveau = unSymptome ? 3 : 2;
  } else {
    niveau = unSymptome ? 2 : 1;
  }
  if (alarme) niveau = 3; // signe d'alarme avec une tension pas très haute : médecin aujourd'hui
  if (risque.renforce && niveau < 4) niveau += 1;
  if (risque == Risque.grossesse && alarme && grade.index >= Grade.grade2.index) niveau = 4;

  return switch (niveau) {
    4 => const DecisionAlerte(4, 'd4_titre', 'd4b_conseil'),
    3 => const DecisionAlerte(3, 'd3_titre', 'd3_conseil'),
    2 => const DecisionAlerte(2, 'd2_titre', 'd2_conseil'),
    _ => const DecisionAlerte(1, 'd1_titre', 'd1_conseil'),
  };
}
