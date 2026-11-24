import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../l10n.dart';
import 'auth_service.dart';
import 'emailjs.dart';

/// Étape 2 : sauvegarde dans le cloud (Firebase).
/// Principe « boîte d'envoi » : l'application écrit TOUJOURS d'abord dans
/// SQLite ; ce qui est « pending » part vers Firestore dès qu'Internet est là.
///
/// Organisation dans Firestore :
///   users/{uid}                    profil (+ « plan », écrit par le médecin seulement)
///   users/{uid}/mesures/{uuid}     mesures (jamais modifiées ni effacées)
///   users/{uid}/prises/{AAAA-MM-JJ} une prise de médicament par jour
///   users/{uid}/messages/{uuid}    messages patiente <-> médecin
///
/// Les identifiants (UUID, ou la date pour les prises) rendent l'envoi
/// idempotent : renvoyer deux fois réécrit le même document, jamais de doublon.
class Cloud {
  Cloud._();
  static final instance = Cloud._();

  bool pret = false;
  bool _enCours = false;
  final _db = BaseLocale.instance;

  /// Plan de traitement lu dans le cloud à la dernière synchronisation
  /// (écrit par le médecin). AppState l'applique s'il a changé.
  PlanTraitement? planCloud;

  /// Nombre de nouveaux messages du médecin reçus à la dernière synchronisation.
  int nouveauxMessages = 0;

  /// Notes du médecin nouvelles ou corrigées à la dernière synchronisation.
  int nouvellesNotes = 0;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  /// Si google-services.json manque ou si Firebase échoue, l'application
  /// continue en mode 100 % local.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      pret = true;
    } catch (_) {
      pret = false;
    }
  }

  DocumentReference<Map<String, dynamic>> _utilisateur(String uid) => _fs.collection('users').doc(uid);

  /// Clé d'une journée (identifiant du document « prise ») : 2026-11-21.
  static String cleJour(DateTime j) =>
      '${j.year.toString().padLeft(4, '0')}-${j.month.toString().padLeft(2, '0')}-${j.day.toString().padLeft(2, '0')}';

  static String messageErreur(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => trL('cl_err_email_pris'),
        'invalid-email' => trL('cl_err_email'),
        'weak-password' => trL('cl_err_mdp_faible'),
        'user-not-found' || 'wrong-password' || 'invalid-credential' => trL('cl_err_identifiants'),
        'network-request-failed' => trL('cl_err_reseau'),
        'too-many-requests' => trL('cl_err_trop'),
        _ => trL('cl_err_compte', {'c': e.code}),
      };

  /// Crée le compte Firebase d'une inscription faite hors ligne.
  /// Renvoie null si le compte cloud est prêt, sinon un message.
  Future<String?> assurerCompte() async {
    if (!pret) return trL('cl_non_config');
    if (_auth.currentUser != null) return null;
    final auth = AuthService.instance;
    final email = await auth.email();
    final mdp = await auth.mdpEnAttente();
    if (email == null) return trL('cl_aucun_compte');
    if (mdp == null) return trL('cl_reconnecter');
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: mdp);
      try {
        await _auth.currentUser?.sendEmailVerification();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Compte peut-être créé lors d'un essai précédent : on tente la connexion.
        try {
          await _auth.signInWithEmailAndPassword(email: email, password: mdp);
        } on FirebaseAuthException catch (e2) {
          return messageErreur(e2);
        }
      } else {
        return messageErreur(e);
      }
    }
    await auth.marquerCloudActif();
    return null;
  }

  // --- Conversion -------------------------------------------------------------
  Map<String, dynamic> _mesureVersCloud(Mesure m) => {
        'id': m.id,
        'date': Timestamp.fromMillisecondsSinceEpoch(m.date.millisecondsSinceEpoch),
        'date_ms': m.date.millisecondsSinceEpoch,
        'tas': m.tas,
        'tad': m.tad,
        // Les 4 grandeurs du client, prêtes pour l'espace médecin.
        'pp': m.tas - m.tad,
        'pm': double.parse((m.tad + (m.tas - m.tad) / 3).toStringAsFixed(1)),
        'pouls': m.pouls,
        'nb_lectures': m.nbLectures,
        'grade': m.grade,
        'symptomes': m.symptomes,
        'niveau_alerte': m.niveauAlerte,
        'episode_id': m.episodeId,
      };

  Mesure _mesureDepuisCloud(Map<String, dynamic> d) => Mesure(
        id: d['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch((d['date_ms'] as num).toInt()),
        tas: (d['tas'] as num).toInt(),
        tad: (d['tad'] as num).toInt(),
        pouls: (d['pouls'] as num).toInt(),
        nbLectures: (d['nb_lectures'] as num?)?.toInt() ?? 1,
        grade: d['grade'] as String,
        symptomes: List<String>.from(d['symptomes'] ?? const []),
        niveauAlerte: (d['niveau_alerte'] as num?)?.toInt() ?? 1,
        episodeId: d['episode_id'] as String?,
        syncStatus: 'synced',
      );

  Map<String, dynamic> _priseVersCloud(Prise p) => {
        'jour': cleJour(p.jour),
        'jour_ms': p.jour.millisecondsSinceEpoch,
        'heure_ms': p.heure?.millisecondsSinceEpoch,
        'medicament': p.medicament,
        'dose_mg': p.doseMg,
        'statut': p.statut,
        'maj': FieldValue.serverTimestamp(),
      };

  Prise? _priseDepuisCloud(String id, Map<String, dynamic> d) {
    final statut = d['statut'] as String?;
    if (statut != 'pris' && statut != 'oubli') return null; // « annule » : ignorée
    final h = d['heure_ms'] as num?;
    return Prise(
      id: 'cloud-$id',
      jour: DateTime.fromMillisecondsSinceEpoch((d['jour_ms'] as num).toInt()),
      heure: h == null ? null : DateTime.fromMillisecondsSinceEpoch(h.toInt()),
      medicament: (d['medicament'] as String?) ?? '',
      doseMg: (d['dose_mg'] as num?)?.toDouble() ?? 0,
      statut: statut!,
      syncStatus: 'synced',
    );
  }

  Map<String, dynamic> _messageVersCloud(Message m) => {
        'id': m.id,
        'date': Timestamp.fromMillisecondsSinceEpoch(m.date.millisecondsSinceEpoch),
        'date_ms': m.date.millisecondsSinceEpoch,
        'de_moi': true,
        'texte': m.texte,
      };

  /// Robuste : un message écrit par l'espace médecin peut n'avoir que
  /// « date » (Timestamp) et pas « id » ni « date_ms ».
  Message _messageDepuisCloud(String docId, Map<String, dynamic> d) => Message(
        id: (d['id'] as String?) ?? docId,
        date: d['date_ms'] is num
            ? DateTime.fromMillisecondsSinceEpoch((d['date_ms'] as num).toInt())
            : (d['date'] is Timestamp ? (d['date'] as Timestamp).toDate() : DateTime.now()),
        deMoi: d['de_moi'] == true,
        texte: (d['texte'] as String?) ?? '',
        syncStatus: 'synced',
      );

  // --- Envoi --------------------------------------------------------------------
  /// Envoie des documents par lots de 400 (limite Firestore : 500 par lot),
  /// puis les marque « synced » sur le téléphone.
  Future<void> _envoyerParLots<T>(
    List<T> elements,
    void Function(WriteBatch b, T e) ecrire,
    Future<void> Function(List<T> lot) marquer,
  ) async {
    for (var i = 0; i < elements.length; i += 400) {
      final lot = elements.skip(i).take(400).toList();
      final b = _fs.batch();
      for (final e in lot) {
        ecrire(b, e);
      }
      await b.commit();
      await marquer(lot);
    }
  }

  /// Applique les annulations en attente. Une mesure n'est jamais effacée du
  /// cloud : elle est marquée « annulee » (elle disparaît des calculs).
  Future<void> _appliquerOps(String uid) async {
    final ops = await _db.opsCloud();
    for (final o in ops) {
      final type = o['t'] as String;
      final cle = o['cle'] as String;
      try {
        if (type == 'mesure_annulee') {
          await _utilisateur(uid).collection('mesures').doc(cle).update({
            'annulee': true,
            'annulee_ms': o['ms'],
          });
        } else if (type == 'prise_annulee') {
          await _utilisateur(uid).collection('prises').doc(cle).set({
            'jour': cle,
            'statut': 'annule',
            'maj': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } on FirebaseException catch (e) {
        // Jamais envoyée : rien à annuler dans le cloud.
        if (e.code != 'not-found') rethrow;
      }
      await _db.retirerOpCloud(type, cle);
    }
  }

  /// Envoie le profil, les annulations, les mesures, les prises et les messages
  /// en attente, puis reçoit le plan et les messages du médecin.
  /// Renvoie un message court (dans la langue de l'application).
  Future<String> synchroniser({required bool enLigne, Profil? profil}) async {
    if (!pret) return trL('cl_non_config');
    if (!await AuthService.instance.consentementCloud()) return trL('cl_refusee');
    if (!enLigne) return trL('cl_hors_ligne');
    if (_enCours) return trL('cl_en_cours');
    _enCours = true;
    nouveauxMessages = 0;
    nouvellesNotes = 0;
    try {
      final err = await assurerCompte();
      if (err != null) return err;
      final uid = _auth.currentUser!.uid;
      final moi = _utilisateur(uid);

      if (profil != null) {
        await moi.set({
          'email': _auth.currentUser!.email,
          'profil': profil.toJson(),
          'maj': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 1. Annulations d'abord : une prise notée de nouveau après une
      //    annulation est envoyée ensuite et remplace bien l'annulation.
      await _appliquerOps(uid);

      // 2. Mesures, prises, messages en attente.
      final mesures = await _db.mesuresEnAttente();
      await _envoyerParLots<Mesure>(
        mesures,
        (b, m) => b.set(moi.collection('mesures').doc(m.id), _mesureVersCloud(m)),
        (lot) => _db.marquerSynchro(lot.map((m) => m.id).toList()),
      );
      // Alerte de crise (niveau 4) : courriel au médecin choisi, une fois
      // par épisode. Ne remplace jamais le 911, que l'app a déjà proposé.
      await _alerterMedecin(mesures);
      final prises = await _db.prisesEnAttente();
      await _envoyerParLots<Prise>(
        prises,
        (b, p) => b.set(moi.collection('prises').doc(cleJour(p.jour)), _priseVersCloud(p)),
        (lot) => _db.marquerSynchroTable('prises', lot.map((p) => p.id).toList()),
      );
      final messages = await _db.messagesEnAttente();
      await _envoyerParLots<Message>(
        messages,
        (b, m) => b.set(moi.collection('messages').doc(m.id), _messageVersCloud(m)),
        (lot) => _db.marquerSynchroTable('messages', lot.map((m) => m.id).toList()),
      );
      // Fin de l'envoi : le portail du médecin, abonné à ce document, se met
      // à jour tout seul (tout est déjà arrivé quand « maj » change).
      await moi.set({'maj': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      // 3. Réception : plan de traitement et messages écrits par le médecin.
      final doc = await moi.get();
      final plan = doc.data()?['plan'];
      planCloud = plan is Map ? PlanTraitement.fromJson(Map<String, dynamic>.from(plan)) : null;
      final recus = await moi.collection('messages').where('de_moi', isEqualTo: false).get();
      for (final d in recus.docs) {
        if (await _db.importerMessage(_messageDepuisCloud(d.id, d.data()))) nouveauxMessages++;
      }
      nouvellesNotes = await _recevoirNotesEtPlans(moi);

      await _db.ecrireReglage('derniere_synchro', DateTime.now().millisecondsSinceEpoch.toString());
      final n = mesures.length + prises.length + messages.length;
      if (nouveauxMessages > 0) return trL('cl_messages_recus', {'n': nouveauxMessages});
      return n == 0 ? trL('cl_a_jour') : trL('cl_envoyes', {'n': n});
    } on FirebaseAuthException catch (e) {
      return messageErreur(e);
    } on FirebaseException catch (e) {
      return trL('cl_err_cloud', {'c': e.code});
    } finally {
      _enCours = false;
    }
  }

  /// Connexion sur un nouveau téléphone : récupère le profil, les mesures,
  /// les prises et les messages. Renvoie (message d'erreur ou null, profil).
  Future<(String?, Profil?)> connecterEtRecuperer(String email, String motDePasse) async {
    if (!pret) return (trL('cl_non_config'), null);
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: motDePasse);
    } on FirebaseAuthException catch (e) {
      return (messageErreur(e), null);
    }
    final moi = _utilisateur(_auth.currentUser!.uid);
    Profil? profil;
    try {
      final doc = await moi.get();
      final p = doc.data()?['profil'];
      if (p is Map) profil = Profil.fromJson(Map<String, dynamic>.from(p));
      final plan = doc.data()?['plan'];
      planCloud = plan is Map ? PlanTraitement.fromJson(Map<String, dynamic>.from(plan)) : null;
      final medecin = doc.data()?['medecin_nom'];
      if (medecin is String) await _db.ecrireReglage('medecin', medecin);
      final emailMedecin = doc.data()?['medecin_email'];
      if (emailMedecin is String) await _db.ecrireReglage('medecin_email', emailMedecin);

      final mesures = await moi.collection('mesures').orderBy('date_ms').get();
      for (final d in mesures.docs) {
        if (d.data()['annulee'] == true) continue; // annulée : pas dans l'historique
        await _db.importerMesure(_mesureDepuisCloud(d.data()));
      }
      final prises = await moi.collection('prises').get();
      for (final d in prises.docs) {
        final p = _priseDepuisCloud(d.id, d.data());
        if (p != null) await _db.importerPrise(p);
      }
      final messages = await moi.collection('messages').get();
      for (final d in messages.docs) {
        await _db.importerMessage(_messageDepuisCloud(d.id, d.data()));
      }
      await _recevoirNotesEtPlans(moi, dejaLues: true);
    } on FirebaseException catch (e) {
      return (trL('cl_err_recuperation', {'c': e.code}), profil);
    }
    return (null, profil);
  }

  /// Notes du médecin (users/{uid}/notes) et historique des plans
  /// (users/{uid}/plans, pour le rapport PDF). Une erreur ici n'empêche pas le
  /// reste de la synchronisation. Renvoie le nombre de notes nouvelles.
  Future<int> _recevoirNotesEtPlans(DocumentReference<Map<String, dynamic>> moi, {bool dejaLues = false}) async {
    var n = 0;
    try {
      final notes = await moi.collection('notes').get();
      for (final d in notes.docs) {
        final note = NoteMedecin.depuisCloud(d.id, d.data());
        if (note.texte.trim().isEmpty) continue;
        if (await _db.importerNote(note)) n++;
      }
      if (dejaLues) await _db.marquerNotesLues(); // nouveau téléphone : rien de « nouveau »
      final plans = await moi.collection('plans').orderBy('date_ms', descending: true).limit(30).get();
      await _db.ecrireReglage('plans_historique', jsonEncode([
        for (final d in plans.docs)
          {for (final e in d.data().entries) if (e.value == null || e.value is num || e.value is String || e.value is bool) e.key: e.value},
      ]));
    } on FirebaseException {
      // Règles pas encore publiées ou réseau coupé : on réessaiera.
    }
    return dejaLues ? 0 : n;
  }

  // --- Médecin --------------------------------------------------------------------
  /// Lie le dossier au médecin dont la patiente a reçu le code (ex. MBG-4821).
  /// Ce médecin pourra lire les mesures, prises et messages, et modifier le
  /// plan de traitement. Renvoie (message d'erreur ou null, nom du médecin).
  Future<(String?, String?)> lierMedecin(String code) async {
    if (!pret) return (trL('cl_non_config'), null);
    if (!await AuthService.instance.consentementCloud()) return (trL('mm_cloud_requis'), null);
    final err = await assurerCompte();
    if (err != null) return (err, null);
    final c = code.trim().toUpperCase().replaceAll(' ', '');
    if (c.length < 6) return (trL('mm_code_inconnu'), null);
    try {
      final doc = await _fs.collection('codes_medecin').doc(c).get();
      final d = doc.data();
      if (!doc.exists || d == null || d['uid'] is! String) return (trL('mm_code_inconnu'), null);
      final nom = (d['nom'] as String?) ?? c;
      final emailMedecin = (d['email'] as String?) ?? '';
      await _utilisateur(_auth.currentUser!.uid).set({
        'medecin_uid': d['uid'],
        'medecin_nom': nom,
        'medecin_email': emailMedecin,
        'medecin_lie_le': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _db.ecrireReglage('medecin', nom);
      await _db.ecrireReglage('medecin_code', c);
      await _db.ecrireReglage('medecin_email', emailMedecin);
      await AuthService.instance.changerPartage(true);
      return (null, nom);
    } on FirebaseAuthException catch (e) {
      return (messageErreur(e), null);
    } on FirebaseException catch (e) {
      return (trL('cl_err_cloud', {'c': e.code}), null);
    }
  }

  /// Retire l'accès du médecin (il ne voit plus le dossier).
  Future<String?> delierMedecin() async {
    if (!pret) return trL('cl_non_config');
    final err = await assurerCompte();
    if (err != null) return err;
    try {
      await _utilisateur(_auth.currentUser!.uid).set({'medecin_uid': '', 'medecin_nom': '', 'medecin_email': ''}, SetOptions(merge: true));
      await _db.ecrireReglage('medecin', '');
      await _db.ecrireReglage('medecin_code', '');
      await _db.ecrireReglage('medecin_email', '');
      await _db.ecrireReglage('alertes_a_envoyer', '[]');
      await AuthService.instance.changerPartage(false);
      return null;
    } on FirebaseException catch (e) {
      return trL('cl_err_cloud', {'c': e.code});
    }
  }

  /// Courriel d'alerte au médecin pour chaque NOUVELLE crise de niveau 4.
  /// Une crise = toutes les mesures de niveau 4 à moins de 2 h les unes des
  /// autres (la 1re mesure n'a pas encore d'épisode, les suivantes oui : on se
  /// fie donc à l'heure, pas à l'identifiant d'épisode).
  /// Les alertes non envoyées (pas de réseau, EmailJS indisponible) attendent
  /// dans « alertes_a_envoyer » et repartent à la synchronisation suivante.
  /// Le courriel ne contient ni le nom ni les valeurs (données de santé).
  static const _fenetreCrise = 2 * 3600 * 1000; // 2 h en millisecondes

  /// Ajoute aux alertes en attente les mesures de niveau 4 qui ouvrent une
  /// nouvelle crise. Fonction pure (testée).
  static List<int> nouvellesCrises(List<Mesure> envoyees, List<int> enAttente, int dernierEnvoiMs) {
    final l = [...enAttente];
    final dates = [for (final m in envoyees) if (m.niveauAlerte >= 4) m.date.millisecondsSinceEpoch]..sort();
    for (final ms in dates) {
      final dejaCouverte = ms - dernierEnvoiMs < _fenetreCrise && ms >= dernierEnvoiMs - _fenetreCrise ||
          l.any((p) => (p - ms).abs() < _fenetreCrise);
      if (!dejaCouverte) l.add(ms);
    }
    return l;
  }

  Future<void> _alerterMedecin(List<Mesure> envoyees) async {
    final s = await _db.lireReglage('alertes_a_envoyer');
    final enAttente = <int>[];
    try {
      if (s != null && s.isNotEmpty) enAttente.addAll(List<num>.from(jsonDecode(s) as List).map((n) => n.toInt()));
    } catch (_) {}
    final dernier = int.tryParse(await _db.lireReglage('alerte_medecin_ms') ?? '') ?? -_fenetreCrise * 10;
    final aEnvoyer = nouvellesCrises(envoyees, enAttente, dernier);
    if (aEnvoyer.isEmpty) return;
    await _db.ecrireReglage('alertes_a_envoyer', jsonEncode(aEnvoyer));

    var email = await _db.lireReglage('medecin_email') ?? '';
    if (email.isEmpty) {
      // Lien fait avant cette fonction : on retrouve le courriel par le code.
      final code = await _db.lireReglage('medecin_code') ?? '';
      if (code.isNotEmpty) {
        try {
          email = ((await _fs.collection('codes_medecin').doc(code).get()).data()?['email'] as String?) ?? '';
          if (email.isNotEmpty) await _db.ecrireReglage('medecin_email', email);
        } catch (_) {}
      }
    }
    if (email.isEmpty || (await _db.lireReglage('medecin') ?? '').isEmpty) return;

    aEnvoyer.sort();
    final ok = await envoyerEmailJs(modeleGenerique, {
      'to_email': email,
      'sujet': trL('al_med_sujet'),
      'message': trL('al_med_corps', {'d': dateHeure(DateTime.fromMillisecondsSinceEpoch(aEnvoyer.first)), 'n': aEnvoyer.length}),
    });
    if (!ok) return;
    await _db.ecrireReglage('alerte_medecin_ms', '${aEnvoyer.last}');
    await _db.ecrireReglage('alertes_a_envoyer', '[]');
  }

  Future<DateTime?> derniereSynchro() async {
    final s = await _db.lireReglage('derniere_synchro');
    return s == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(s));
  }
}
