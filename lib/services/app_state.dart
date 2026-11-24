import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/classification.dart';
import '../core/controle.dart';
import '../core/risque.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../commun/rapport_pdf.dart';
import '../l10n.dart';
import '../medecin/calculs.dart' show MesureM, NoteM, PlanM, PriseM;
import 'cloud.dart';
import 'notifications.dart';
import 'partage_pdf.dart';

/// État partagé de l'application (profil, dernière mesure, réseau).
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  final _uuid = const Uuid();
  final db = BaseLocale.instance;

  Profil profil = Profil();
  Mesure? derniere;
  bool enLigne = false;
  TimeOfDay heureMatin = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay heureSoir = const TimeOfDay(hour: 18, minute: 0);
  int alertesNonLues = 0;

  /// Notes du médecin pas encore vues (pastille sur l'onglet Suivi).
  int notesNonLues = 0;

  bool voixAuto = false;
  ContactUrgence? contact;
  PlanTraitement? _plan;

  /// Rappel de prise de médicament (à l'heure du plan) et relance 30 min après.
  bool rappelMedic = true;
  bool relanceMedic = true;

  /// Onglet à ouvrir (ex. 3 = Traitement quand on touche un rappel de
  /// médicament) ; la coquille principale l'applique dès qu'elle est affichée.
  final ongletDemande = ValueNotifier<int?>(null);

  Risque get risque => calculerRisque(profil);

  /// Plan du médecin, ou à défaut le 1er médicament du profil.
  PlanTraitement? get plan {
    if (_plan != null) return _plan;
    if (profil.medicaments.isEmpty) return null;
    final m = profil.medicaments.first;
    final dose = double.tryParse(m.dose.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return PlanTraitement(medicament: m.nom, doseMg: dose);
  }

  /// Réglages d'affichage (langue, taille du texte) lus avant le 1er écran.
  Future<void> chargerReglagesUi() async {
    final l = await db.lireReglage('langue');
    if (l != null) ReglagesUi.instance.changerLangue(l);
    final e = double.tryParse(await db.lireReglage('echelle') ?? '');
    if (e != null) ReglagesUi.instance.changerEchelle(e);
  }

  Future<void> changerLangue(String l) async {
    ReglagesUi.instance.changerLangue(l);
    await db.ecrireReglage('langue', l);
    await Notifications.instance.programmerMesures(heureMatin, heureSoir); // textes des rappels
    await reprogrammerMedicament();
    notifyListeners();
  }

  /// (Re)programme les rappels de médicament d'après le plan, en sautant les
  /// jours où la prise est déjà notée (prise ou oubli).
  Future<void> reprogrammerMedicament() async {
    final p = plan;
    final notes = await db.prisesDepuis(aujourdhui());
    try {
      await Notifications.instance.programmerMedicament(
        medicament: p?.medicament,
        doseMg: p?.doseMg ?? 0,
        heure: p?.heure ?? 20,
        minute: p?.minute ?? 0,
        actif: rappelMedic,
        relance: relanceMedic,
        joursNotes: {for (final x in notes) if (x.statut == 'pris' || x.statut == 'oubli') DateTime(x.jour.year, x.jour.month, x.jour.day)},
      );
    } catch (_) {
      // Pas de permission de notification : l'application continue sans rappel.
    }
  }

  Future<void> changerRappelMedic({bool? actif, bool? relance}) async {
    rappelMedic = actif ?? rappelMedic;
    relanceMedic = relance ?? relanceMedic;
    await db.ecrireReglage('rappel_medic', '${rappelMedic ? 1 : 0},${relanceMedic ? 1 : 0}');
    await reprogrammerMedicament();
    notifyListeners();
  }

  Future<void> changerEchelle(double e) async {
    ReglagesUi.instance.changerEchelle(e);
    await db.ecrireReglage('echelle', '$e');
    notifyListeners();
  }

  Future<void> changerVoixAuto(bool v) async {
    voixAuto = v;
    await db.ecrireReglage('voix_auto', v ? '1' : '0');
    notifyListeners();
  }

  Future<void> changerContact(ContactUrgence c) async {
    contact = c;
    await db.ecrireReglage('contact', c.encoder());
    notifyListeners();
  }

  /// Appelé quand le plan arrive de l'espace médecin (jamais par la patiente).
  Future<void> recevoirPlan(PlanTraitement p) async {
    _plan = p;
    await db.ecrireReglage('plan', p.encoder());
    await reprogrammerMedicament(); // nouvelle heure ou nouvelle dose
    notifyListeners();
  }

  Future<void> charger() async {
    profil = await db.lireProfil() ?? Profil();
    voixAuto = (await db.lireReglage('voix_auto')) == '1';
    final c = await db.lireReglage('contact');
    contact = c == null ? null : ContactUrgence.decoder(c);
    medecinNom = (await db.lireReglage('medecin')) ?? '';
    final pl = await db.lireReglage('plan');
    _plan = pl == null ? null : PlanTraitement.decoder(pl);
    derniere = await db.derniereMesure();
    final h = await db.lireReglage('heures');
    if (h != null) {
      final parts = h.split(',');
      heureMatin = _lireHeure(parts[0]);
      heureSoir = _lireHeure(parts[1]);
    }
    alertesNonLues = (await db.alertes()).where((a) => !a.lue).length;
    notesNonLues = await db.notesNonLues();
    final rm = (await db.lireReglage('rappel_medic'))?.split(',');
    if (rm != null && rm.length == 2) {
      rappelMedic = rm[0] == '1';
      relanceMedic = rm[1] == '1';
    }
    await reprogrammerMedicament(); // repousse les 21 jours de rappels à chaque ouverture
    final reseau = Connectivity();
    enLigne = !(await reseau.checkConnectivity()).contains(ConnectivityResult.none);
    reseau.onConnectivityChanged.listen((r) {
      final avant = enLigne;
      enLigne = !r.contains(ConnectivityResult.none);
      notifyListeners();
      // Retour du réseau : on envoie tout ce qui attend (boîte d'envoi).
      if (enLigne && !avant) synchroniser();
    });
    notifyListeners();
    if (enLigne) synchroniser();
  }

  String dernierMessageSynchro = '';

  /// Médecin choisi par la patiente (vide : aucun).
  String medecinNom = '';

  Future<String?> lierMedecin(String code) async {
    final (err, nom) = await Cloud.instance.lierMedecin(code);
    if (nom != null) medecinNom = nom;
    notifyListeners();
    return err;
  }

  Future<String?> delierMedecin() async {
    final err = await Cloud.instance.delierMedecin();
    if (err == null) medecinNom = '';
    notifyListeners();
    return err;
  }

  /// Envoie le profil et les mesures en attente vers Firebase (si configuré,
  /// si le patient l'a accepté et si Internet est disponible).
  Future<String> synchroniser() async {
    final cloud = Cloud.instance;
    final m = await cloud.synchroniser(enLigne: enLigne, profil: profil.prenom.isEmpty ? null : profil);
    // Plan écrit par le médecin dans le cloud : appliqué s'il a changé.
    // (La patiente ne modifie jamais sa dose elle-même.)
    final pc = cloud.planCloud;
    if (pc != null && (_plan == null || _plan!.encoder() != pc.encoder())) {
      await recevoirPlan(pc);
    }
    notesNonLues = await db.notesNonLues();
    dernierMessageSynchro = m;
    notifyListeners();
    return m;
  }

  // --- Notes du médecin ----------------------------------------------------------
  /// Notes écrites (ou portant sur une mesure) des [jours] derniers jours.
  Future<List<NoteMedecin>> notesDepuis(int jours) => db.notesDepuis(jourDecale(aujourdhui(), -(jours - 1)));

  Future<void> marquerNotesLues() async {
    if (notesNonLues == 0) return;
    await db.marquerNotesLues();
    notesNonLues = 0;
    notifyListeners();
  }

  // --- Rapport PDF et export -----------------------------------------------------
  /// Mêmes données que le dossier du médecin, lues dans la base du téléphone :
  /// le PDF partagé est identique à celui que le médecin télécharge.
  Future<DonneesRapport> donneesRapport() async {
    final debut = DateTime(2000);
    final mesures = await db.mesuresDepuis(debut);
    final prises = await db.prisesDepuis(debut);
    final notes = await db.notesDepuis(debut);
    final p = plan;
    final planM = p == null
        ? null
        : PlanM(
            medicament: p.medicament,
            doseMg: p.doseMg,
            heure: p.heure,
            minute: p.minute,
            ancienneDoseMg: p.ancienneDoseMg,
            date: p.dateModif ?? DateTime.fromMillisecondsSinceEpoch(0),
            medecinNom: p.modifiePar ?? '',
          );
    var historique = <PlanM>[];
    try {
      final h = await db.lireReglage('plans_historique');
      if (h != null) historique = [for (final x in jsonDecode(h) as List) PlanM.depuis(Map<String, dynamic>.from(x as Map))];
    } catch (_) {}
    // Pas d'historique reçu : le dernier changement du plan suffit.
    if (historique.isEmpty && planM != null && p?.dateModif != null && p?.ancienneDoseMg != null) historique = [planM];
    return DonneesRapport(
      profil: profil,
      medecinNom: medecinNom,
      plan: planM,
      mesures: [for (final m in mesures) MesureM.depuisLocale(m)],
      prises: [for (final x in prises) PriseM(jour: x.jour, statut: x.statut, heure: x.heure, medicament: x.medicament, doseMg: x.doseMg)],
      historique: historique,
      notes: [for (final n in notes) NoteM(mesureId: n.mesureId, texte: n.texte, date: n.date)],
      auteur: '${profil.prenom} ${profil.nom}'.trim().isEmpty ? 'WellTech' : '${profil.prenom} ${profil.nom}'.trim(),
    );
  }

  /// Rapport de suivi des [jours] derniers jours, partagé (courriel,
  /// messagerie, Fichiers…) avec la feuille de partage d'Android.
  Future<void> partagerRapport({int jours = 28}) async {
    final octets = await genererRapport(await donneesRapport(), jours: jours);
    await partagerPdf(octets, nomFichierRapport(profil));
  }

  /// Toutes les mesures dans un PDF (tableau complet).
  Future<void> exporterMesures() async {
    final octets = await genererExportMesures(await donneesRapport());
    await partagerPdf(octets, nomFichierRapport(profil, prefixe: 'WellTech_mesures'));
  }

  static TimeOfDay _lireHeure(String s) {
    final hm = s.split(':');
    return TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1]));
  }

  static String formatHeure(TimeOfDay t) => heureTexte(t.hour, t.minute);

  Future<void> enregistrerProfil(Profil p, {bool synchroniser = true}) async {
    profil = p;
    await db.ecrireProfil(p);
    if (_plan == null) await reprogrammerMedicament(); // médicament déclaré dans le profil
    notifyListeners();
    if (synchroniser) this.synchroniser();
  }

  Future<void> changerHeures(TimeOfDay matin, TimeOfDay soir) async {
    heureMatin = matin;
    heureSoir = soir;
    await db.ecrireReglage('heures', '${matin.hour}:${matin.minute},${soir.hour}:${soir.minute}');
    await Notifications.instance.programmerMesures(matin, soir);
    notifyListeners();
  }

  /// Prochaine mesure prévue (matin ou soir).
  DateTime prochaineMesure() {
    final now = DateTime.now();
    final m = DateTime(now.year, now.month, now.day, heureMatin.hour, heureMatin.minute);
    final s = DateTime(now.year, now.month, now.day, heureSoir.hour, heureSoir.minute);
    if (now.isBefore(m)) return m;
    if (now.isBefore(s)) return s;
    return DateTime(now.year, now.month, now.day + 1, heureMatin.hour, heureMatin.minute);
  }

  /// Enregistre une séance de mesure + l'alerte associée. Renvoie la décision.
  Future<(Mesure, DecisionAlerte)> enregistrerMesure({
    required int tas,
    required int tad,
    required int pouls,
    required int nbLectures,
    required List<String> symptomesCoches,
    required List<String> symptomesAutres,
    String? episodeId,
  }) async {
    final grade = classerPour(tas, tad, enceinte: profil.grossesseActive);
    final decision = deciderAlerte(grade: grade, symptomesCoches: symptomesCoches, symptomesAutres: symptomesAutres, risque: risque);
    final m = Mesure(
      id: _uuid.v4(),
      date: DateTime.now(),
      tas: tas,
      tad: tad,
      pouls: pouls,
      nbLectures: nbLectures,
      grade: grade.name,
      symptomes: [...symptomesCoches, ...symptomesAutres],
      niveauAlerte: decision.niveau,
      episodeId: episodeId,
    );
    await db.ajouterMesure(m);
    if (episodeId == null) derniere = m;
    if (decision.niveau >= 2) {
      await db.ajouterAlerte(AlerteEnregistree(
        id: _uuid.v4(),
        date: m.date,
        niveau: decision.niveau,
        titre: decision.titre,
        detail: '$tas/$tad (${grade.court})${m.symptomes.isEmpty ? '' : ' · ${m.symptomes.join(', ')}'}',
      ));
      alertesNonLues++;
      if (decision.niveau >= 3) {
        await Notifications.instance.alerter(decision.niveau, decision.titre, '$tas/$tad · ${decision.conseil}');
      }
    }
    notifyListeners();
    synchroniser(); // sans attendre : l'affichage ne dépend pas du réseau
    return (m, decision);
  }

  String nouvelEpisode() => _uuid.v4();

  /// « Annuler » juste après l'enregistrement (faire et défaire).
  /// La mesure est effacée du téléphone. Si elle était déjà partie dans le
  /// cloud, elle y est marquée « annulée » (jamais effacée : traçabilité).
  Future<void> annulerMesure(Mesure m) async {
    await db.supprimerMesure(m.id);
    await db.ajouterOpCloud('mesure_annulee', m.id);
    derniere = await db.derniereMesure();
    notifyListeners();
    synchroniser();
  }

  // --- Calculs du client sur une période ---------------------------------------
  /// Moyennes journalières (hors mesures de crise) des [jours] derniers jours,
  /// t = numéro du jour (0 = premier jour de la période).
  Future<List<Point>> pointsJournaliers(int jours, {int? heureMin, int? heureMax}) async {
    final now = DateTime.now();
    final debut = jourDecale(now, -(jours - 1));
    final toutes = (await db.mesuresDepuis(debut)).where((m) => m.episodeId == null).where((m) {
      if (heureMin != null && m.date.hour < heureMin) return false;
      if (heureMax != null && m.date.hour >= heureMax) return false;
      return true;
    });
    final parJour = <int, List<Mesure>>{};
    for (final m in toutes) {
      final j = joursEntre(debut, m.date);
      parJour.putIfAbsent(j, () => []).add(m);
    }
    final cles = parJour.keys.toList()..sort();
    return [
      for (final j in cles)
        Point(
          j.toDouble(),
          Grandeurs(
            parJour[j]!.map((m) => m.tas).reduce((a, b) => a + b) / parJour[j]!.length,
            parJour[j]!.map((m) => m.tad).reduce((a, b) => a + b) / parJour[j]!.length,
          ),
        ),
    ];
  }

  // --- Prises de médicament -------------------------------------------------------
  static DateTime aujourdhui() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<List<Prise>> prisesSemaine() => db.prisesDepuis(jourDecale(aujourdhui(), -6));

  Future<void> noterPrise(DateTime heure) async {
    final p = plan;
    if (p == null) return;
    await db.enregistrerPrise(Prise(id: _uuid.v4(), jour: aujourdhui(), heure: heure, medicament: p.medicament, doseMg: p.doseMg, statut: 'pris'));
    await db.retirerOpCloud('prise_annulee', Cloud.cleJour(aujourdhui()));
    await reprogrammerMedicament(); // plus de relance aujourd'hui
    notifyListeners();
    synchroniser();
  }

  Future<void> noterOubli() async {
    final p = plan;
    if (p == null) return;
    await db.enregistrerPrise(Prise(id: _uuid.v4(), jour: aujourdhui(), heure: null, medicament: p.medicament, doseMg: p.doseMg, statut: 'oubli'));
    await db.retirerOpCloud('prise_annulee', Cloud.cleJour(aujourdhui()));
    await reprogrammerMedicament();
    notifyListeners();
    synchroniser();
  }

  Future<void> annulerPriseDuJour() async {
    await db.supprimerPrise(aujourdhui());
    await db.ajouterOpCloud('prise_annulee', Cloud.cleJour(aujourdhui()));
    await reprogrammerMedicament(); // la relance du jour revient si l'heure n'est pas passée
    notifyListeners();
    synchroniser();
  }

  // --- Alertes --------------------------------------------------------------------
  Future<void> marquerAlerteLue(String id) async {
    await db.marquerAlerteLue(id);
    alertesNonLues = (await db.alertes()).where((x) => !x.lue).length;
    notifyListeners();
  }

  // --- Messages ------------------------------------------------------------------
  Future<List<Message>> messages() => db.messages();

  Future<void> envoyerMessage(String texte) async {
    await db.ajouterMessage(Message(id: _uuid.v4(), date: DateTime.now(), deMoi: true, texte: texte));
    notifyListeners();
    synchroniser(); // part dès qu'Internet est là (sinon reste « en attente »)
  }
}
