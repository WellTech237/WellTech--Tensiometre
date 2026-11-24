// Calculs de l'espace médecin, sans Flutter ni Firebase (testables).
// Ils réutilisent les MÊMES fonctions que l'application de la patiente
// (core/controle.dart) : 4 grandeurs, erreur, dérivée, intégrale, limites,
// statut « très bien / partiellement / très mal contrôlée ».

import '../core/classification.dart';
import '../core/controle.dart';
import '../core/risque.dart';
import '../data/models.dart';

const _jourMs = 24 * 3600 * 1000;

DateTime minuit(DateTime d) => DateTime(d.year, d.month, d.day);

/// Une mesure lue dans Firestore.
class MesureM {
  final String id;
  final DateTime date;
  final int tas;
  final int tad;
  final int pouls;
  final Grade grade;
  final List<String> symptomes;
  final int niveau; // niveau d'alerte 1 à 4
  final String? episode; // non null : mesure d'un épisode de crise
  final bool annulee;

  const MesureM({
    required this.id,
    required this.date,
    required this.tas,
    required this.tad,
    this.pouls = 0,
    this.grade = Grade.normale,
    this.symptomes = const [],
    this.niveau = 1,
    this.episode,
    this.annulee = false,
  });

  Grandeurs get g => Grandeurs(tas.toDouble(), tad.toDouble());
  bool get crise => episode != null;
  bool get matin => date.hour < 12;

  /// Mesure de la base du téléphone (rapport PDF de la patiente).
  factory MesureM.depuisLocale(Mesure m) {
    Grade grade;
    try {
      grade = Grade.values.byName(m.grade);
    } catch (_) {
      grade = classer(m.tas, m.tad);
    }
    return MesureM(
      id: m.id,
      date: m.date,
      tas: m.tas,
      tad: m.tad,
      pouls: m.pouls,
      grade: grade,
      symptomes: m.symptomes,
      niveau: m.niveauAlerte,
      episode: m.episodeId,
    );
  }

  factory MesureM.depuis(String id, Map<String, dynamic> d) {
    final tas = (d['tas'] as num?)?.toInt() ?? 0;
    final tad = (d['tad'] as num?)?.toInt() ?? 0;
    Grade grade;
    try {
      grade = Grade.values.byName((d['grade'] as String?) ?? '');
    } catch (_) {
      grade = classer(tas, tad);
    }
    return MesureM(
      id: (d['id'] as String?) ?? id,
      date: DateTime.fromMillisecondsSinceEpoch((d['date_ms'] as num?)?.toInt() ?? 0),
      tas: tas,
      tad: tad,
      pouls: (d['pouls'] as num?)?.toInt() ?? 0,
      grade: grade,
      symptomes: List<String>.from(d['symptomes'] ?? const []),
      niveau: (d['niveau_alerte'] as num?)?.toInt() ?? 1,
      episode: d['episode_id'] as String?,
      annulee: d['annulee'] == true,
    );
  }
}

/// Prise de médicament d'une journée.
class PriseM {
  final DateTime jour;
  final String statut; // pris | oubli | annule
  final DateTime? heure;
  final String medicament;
  final double doseMg;
  const PriseM({required this.jour, required this.statut, this.heure, this.medicament = '', this.doseMg = 0});

  bool get prise => statut == 'pris';

  factory PriseM.depuis(Map<String, dynamic> d) {
    final h = d['heure_ms'] as num?;
    return PriseM(
      jour: DateTime.fromMillisecondsSinceEpoch((d['jour_ms'] as num?)?.toInt() ?? 0),
      statut: (d['statut'] as String?) ?? 'annule',
      heure: h == null ? null : DateTime.fromMillisecondsSinceEpoch(h.toInt()),
      medicament: (d['medicament'] as String?) ?? '',
      doseMg: (d['dose_mg'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Une version du plan de traitement (historique).
class PlanM {
  final String medicament;
  final double doseMg;
  final int heure;
  final int minute;
  final double? ancienneDoseMg;
  final DateTime date;
  final String medecinNom;
  const PlanM({
    required this.medicament,
    required this.doseMg,
    this.heure = 20,
    this.minute = 0,
    this.ancienneDoseMg,
    required this.date,
    this.medecinNom = '',
  });

  factory PlanM.depuis(Map<String, dynamic> d) => PlanM(
        medicament: (d['medicament'] as String?) ?? '',
        doseMg: (d['doseMg'] as num?)?.toDouble() ?? 0,
        heure: (d['heure'] as num?)?.toInt() ?? 20,
        minute: (d['minute'] as num?)?.toInt() ?? 0,
        ancienneDoseMg: (d['ancienneDoseMg'] as num?)?.toDouble(),
        // Historique : date_ms ; plan courant (format de l'app) : dateModif.
        date: d['date_ms'] is num
            ? DateTime.fromMillisecondsSinceEpoch((d['date_ms'] as num).toInt())
            : (DateTime.tryParse((d['dateModif'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0)),
        medecinNom: (d['medecin_nom'] as String?) ?? (d['modifiePar'] as String?) ?? '',
      );
}

class MessageM {
  final String id;
  final DateTime date;
  final bool deMoi; // true : écrit par la patiente
  final String texte;
  final bool lu;
  const MessageM({required this.id, required this.date, required this.deMoi, required this.texte, this.lu = false});

  factory MessageM.depuis(String id, Map<String, dynamic> d) => MessageM(
        id: (d['id'] as String?) ?? id,
        date: DateTime.fromMillisecondsSinceEpoch((d['date_ms'] as num?)?.toInt() ?? 0),
        deMoi: d['de_moi'] == true,
        texte: (d['texte'] as String?) ?? '',
        lu: d['lu'] == true,
      );
}

class NoteM {
  final String mesureId;
  final String texte;
  final DateTime date;
  const NoteM({required this.mesureId, required this.texte, required this.date});
}

enum Moment { tous, matin, soir }

/// Mesures valides (non annulées) depuis [debut], éventuellement sans les
/// crises et pour un moment de la journée.
List<MesureM> filtrer(List<MesureM> l, DateTime debut, {Moment moment = Moment.tous, bool sansCrises = false}) => [
      for (final m in l)
        if (!m.annulee &&
            !m.date.isBefore(debut) &&
            !(sansCrises && m.crise) &&
            (moment == Moment.tous || (moment == Moment.matin) == m.matin))
          m,
    ]..sort((a, b) => a.date.compareTo(b.date));

/// Moyennes journalières (hors crises), t = jours depuis [debut].
/// Mêmes points que l'écran « Suivi » de la patiente.
List<Point> pointsJournaliers(List<MesureM> mesures, DateTime debut, {Moment moment = Moment.tous}) {
  final d0 = minuit(debut);
  final parJour = <int, List<MesureM>>{};
  for (final m in filtrer(mesures, d0, moment: moment, sansCrises: true)) {
    parJour.putIfAbsent(joursEntre(d0, m.date), () => []).add(m);
  }
  final jours = parJour.keys.toList()..sort();
  return [
    for (final j in jours)
      Point(
        j.toDouble(),
        Grandeurs(
          parJour[j]!.fold<double>(0, (a, m) => a + m.tas) / parJour[j]!.length,
          parJour[j]!.fold<double>(0, (a, m) => a + m.tad) / parJour[j]!.length,
        ),
      ),
  ];
}

/// Observance : part des jours avec une prise « pris », du premier jour suivi
/// (première prise notée ou début de période) jusqu'à [fin]. null si aucune
/// prise n'a jamais été notée.
({int prises, int jours, double taux})? observance(List<PriseM> prises, DateTime debut, DateTime fin) {
  final valides = prises.where((p) => p.statut != 'annule').toList();
  if (valides.isEmpty) return null;
  final premier = valides.map((p) => minuit(p.jour)).reduce((a, b) => a.isBefore(b) ? a : b);
  final d0 = premier.isAfter(minuit(debut)) ? premier : minuit(debut);
  final d1 = minuit(fin);
  if (d1.isBefore(d0)) return null;
  final jours = joursEntre(d0, d1) + 1;
  final n = valides.where((p) => p.prise && !minuit(p.jour).isBefore(d0) && !minuit(p.jour).isAfter(d1)).length;
  return (prises: n, jours: jours, taux: n / jours);
}

enum Priorite { urgence, aVoir, stable }

/// Ligne de la liste des patients.
class ResumePatient {
  final String uid;
  final Profil profil;
  final Risque risque;
  final MesureM? derniere;
  final Indicateurs semaine; // 7 derniers jours
  final double tendance; // dérivée de la TAS sur 28 jours, mmHg / semaine
  final ({int prises, int jours, double taux})? obs; // 28 jours
  final int alertes; // niveau >= 3 sur 7 jours
  final int nonLus; // messages de la patiente non lus
  final int mesures7; // nombre de mesures sur 7 jours
  final Priorite priorite;

  const ResumePatient({
    required this.uid,
    required this.profil,
    required this.risque,
    required this.derniere,
    required this.semaine,
    required this.tendance,
    required this.obs,
    required this.alertes,
    required this.nonLus,
    required this.mesures7,
    required this.priorite,
  });

  String get nomComplet {
    final n = '${profil.prenom} ${profil.nom}'.trim();
    return n.isEmpty ? '—' : n;
  }

  /// Les 4 grandeurs moyennes (7 jours) dans leur plage ? (TAS, TAD, Pm, Pp)
  List<bool> get quatreOk {
    final m = semaine.moyenne;
    if (m == null) return const [false, false, false, false];
    return [for (final g in Grandeur.values) dansLaPlage(g, m.de(g))];
  }
}

ResumePatient resumer({
  required String uid,
  required Profil profil,
  required List<MesureM> mesures,
  required List<PriseM> prises,
  required List<MessageM> messages,
  DateTime? maintenant,
}) {
  final now = maintenant ?? DateTime.now();
  final aujourdhui = minuit(now);
  final d7 = jourDecale(aujourdhui, -6);
  final d28 = jourDecale(aujourdhui, -27);
  final valides = filtrer(mesures, DateTime.fromMillisecondsSinceEpoch(0));
  final derniere = valides.isEmpty ? null : valides.last;
  final semaine = Indicateurs.de(pointsJournaliers(mesures, d7));
  final tendance = derivee(pointsJournaliers(mesures, d28), Grandeur.tas) * 7;
  final recentes = filtrer(mesures, d7);
  final alertes = recentes.where((m) => m.niveau >= 3).length;
  final nonLus = messages.where((m) => m.deMoi && !m.lu).length;
  final urgence = valides.any((m) => m.niveau >= 4 && now.difference(m.date).inHours < 48) ||
      (derniere != null && derniere.grade == Grade.grade3 && now.difference(derniere.date).inHours < 48);
  final aVoir = alertes > 0 || nonLus > 0 || semaine.statut == StatutControle.tresMal ||
      (derniere != null && derniere.grade.index >= Grade.grade2.index) ||
      derniere == null || now.difference(derniere.date).inDays >= 3;
  return ResumePatient(
    uid: uid,
    profil: profil,
    risque: calculerRisque(profil),
    derniere: derniere,
    semaine: semaine,
    tendance: tendance,
    obs: observance(prises, d28, now),
    alertes: alertes,
    nonLus: nonLus,
    mesures7: recentes.length,
    priorite: urgence ? Priorite.urgence : (aVoir ? Priorite.aVoir : Priorite.stable),
  );
}

/// Trie : urgences d'abord, puis à voir, puis stables ; dans chaque groupe,
/// la mesure la plus récente en premier.
List<ResumePatient> trierPatients(List<ResumePatient> l) => [...l]..sort((a, b) {
      final p = a.priorite.index.compareTo(b.priorite.index);
      if (p != 0) return p;
      final da = a.derniere?.date.millisecondsSinceEpoch ?? 0;
      final db = b.derniere?.date.millisecondsSinceEpoch ?? 0;
      return db.compareTo(da);
    });

/// Comparaison avant / après un changement de traitement : moyennes des
/// 7 jours avant et depuis le changement (hors crises).
({Grandeurs? avant, Grandeurs? apres}) avantApres(List<MesureM> mesures, DateTime changement) {
  final c = minuit(changement);
  final avant = filtrer(mesures, jourDecale(c, -7), sansCrises: true).where((m) => m.date.isBefore(c)).toList();
  final apres = filtrer(mesures, c, sansCrises: true);
  Grandeurs? moy(List<MesureM> l) => l.isEmpty
      ? null
      : Grandeurs(l.fold<double>(0, (a, m) => a + m.tas) / l.length, l.fold<double>(0, (a, m) => a + m.tad) / l.length);
  return (avant: moy(avant), apres: moy(apres));
}

/// Erreurs journalières de la TAS (moyenne du jour − cible 120), pour le
/// correcteur PID (une valeur par jour, la plus récente en dernier).
List<double> erreursJournalieres(List<MesureM> mesures, DateTime debut) =>
    [for (final p in pointsJournaliers(mesures, debut)) erreur(Grandeur.tas, p.v.tas)];

/// Jours écoulés (avec décimales) entre [debut] et [d] : abscisse des graphiques.
double joursDepuis(DateTime debut, DateTime d) => (d.millisecondsSinceEpoch - minuit(debut).millisecondsSinceEpoch) / _jourMs;
