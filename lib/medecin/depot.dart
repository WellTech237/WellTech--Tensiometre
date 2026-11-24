// Accès aux données Firestore pour l'espace médecin.
// Les règles Firestore garantissent que le médecin ne lit QUE les dossiers des
// patientes qui l'ont choisi (champ medecin_uid), et qu'il n'écrit que le
// plan de traitement, ses messages et ses notes.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models.dart';
import 'calculs.dart';
import 'notification_admin.dart';

/// Ce que le compte connecté peut voir.
enum Acces { medecin, attente, refuse, admin }

/// Compte médecin (document medecins/{uid}). Créé par le médecin lui-même à
/// l'inscription, avec le statut « en_attente » ; seul l'administrateur le
/// passe à « valide » (ou « refuse », avec un motif).
class Medecin {
  final String uid;
  final String nom;
  final String? code;
  final String email;
  final String telephone;
  final String numeroOrdre;
  final String statut; // en_attente | valide | refuse
  final String motif;
  final DateTime? demandeLe;
  final DateTime? decisionLe;
  const Medecin(
    this.uid,
    this.nom,
    this.code, {
    this.email = '',
    this.telephone = '',
    this.numeroOrdre = '',
    this.statut = 'en_attente',
    this.motif = '',
    this.demandeLe,
    this.decisionLe,
  });

  bool get valide => statut == 'valide';
  bool get refuse => statut == 'refuse';

  factory Medecin.depuis(String uid, Map<String, dynamic> d) {
    DateTime? date(Object? v) => v is Timestamp ? v.toDate() : null;
    return Medecin(
      uid,
      (d['nom'] as String?) ?? '',
      d['code'] as String?,
      email: (d['email'] as String?) ?? '',
      telephone: (d['telephone'] as String?) ?? '',
      numeroOrdre: (d['numero_ordre'] as String?) ?? '',
      statut: (d['statut'] as String?) ?? 'en_attente',
      motif: (d['motif'] as String?) ?? '',
      demandeLe: date(d['demande_le']),
      decisionLe: date(d['decision_le']),
    );
  }
}

/// Tout ce qu'il faut pour afficher le dossier d'une patiente.
class Dossier {
  final String uid;
  final Profil profil;
  final String? email;
  final DateTime? derniereSynchro;
  final PlanM? plan;
  final List<MesureM> mesures;
  final List<PriseM> prises;
  final List<MessageM> messages;
  final List<PlanM> historique; // du plus récent au plus ancien
  final Map<String, NoteM> notes; // par identifiant de mesure
  const Dossier({
    required this.uid,
    required this.profil,
    required this.email,
    required this.derniereSynchro,
    required this.plan,
    required this.mesures,
    required this.prises,
    required this.messages,
    required this.historique,
    required this.notes,
  });
}

class Depot {
  Depot._();
  static final instance = Depot._();

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Medecin? medecin;
  bool admin = false;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> _user(String uid) => _fs.collection('users').doc(uid);

  // --- Connexion ----------------------------------------------------------------
  static String _erreurAuth(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'cl_err_email',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'cl_err_identifiants',
        'email-already-in-use' => 'cl_err_email_pris',
        'weak-password' => 'cl_err_mdp_faible',
        'network-request-failed' => 'cl_err_reseau',
        'too-many-requests' => 'cl_err_trop',
        'requires-recent-login' => 'md_err_reconnexion',
        _ => 'cl_err_identifiants',
      };

  /// Connecte un médecin ou l'administrateur.
  /// Renvoie (accès, null) si tout va bien, sinon (null, clé du message d'erreur).
  Future<(Acces?, String?)> connecter(String email, String mdp) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: mdp);
    } on FirebaseAuthException catch (e) {
      return (null, _erreurAuth(e));
    }
    return chargerSession();
  }

  /// Rôle du compte connecté : administrateur (document admins/{uid}),
  /// médecin validé, demande en attente ou refusée.
  /// Le médecin validé reçoit un code à donner aux patientes (une seule fois).
  Future<(Acces?, String?)> chargerSession() async {
    final u = _auth.currentUser;
    if (u == null) return (null, 'md_err_session');
    admin = false;
    medecin = null;
    try {
      final a = await _fs.collection('admins').doc(u.uid).get();
      if (a.exists) {
        admin = true;
        return (Acces.admin, null);
      }
      final doc = await _fs.collection('medecins').doc(u.uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        return (null, 'md_err_pas_medecin');
      }
      var m = Medecin.depuis(u.uid, doc.data()!);
      if (m.valide && (m.code == null || m.code!.isEmpty)) {
        final code = await _creerCode(u.uid, m.nom);
        m = Medecin.depuis(u.uid, {...doc.data()!, 'code': code});
      } else if (m.valide) {
        await _completerCode(m.code!, u.email ?? '');
      }
      medecin = m;
      if (m.valide) return (Acces.medecin, null);
      return (m.refuse ? Acces.refuse : Acces.attente, null);
    } on FirebaseException {
      await _auth.signOut();
      return (null, 'md_err_pas_medecin');
    }
  }

  /// Inscription d'un médecin : le compte est créé avec SON mot de passe,
  /// mais il reste bloqué (« en_attente ») jusqu'à la validation par
  /// l'administrateur. Renvoie null si tout va bien, sinon une clé de texte.
  Future<String?> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String numeroOrdre,
    required String mdp,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: mdp);
      final u = cred.user!;
      await _fs.collection('medecins').doc(u.uid).set({
        'nom': nom.trim(),
        'email': u.email,
        'telephone': telephone.trim(),
        'numero_ordre': numeroOrdre.trim(),
        'statut': 'en_attente',
        'demande_le': FieldValue.serverTimestamp(),
      });
      try {
        await u.sendEmailVerification();
      } catch (_) {}
      // Alerte aux administrateurs (sans attendre : un échec ne bloque rien).
      notifierAdmins(nom: nom.trim(), email: u.email ?? email.trim(), telephone: telephone.trim(), numeroOrdre: numeroOrdre.trim());
      await chargerSession();
      return null;
    } on FirebaseAuthException catch (e) {
      return _erreurAuth(e);
    } on FirebaseException catch (e) {
      return 'md_err_firestore_${e.code == 'permission-denied' ? 'regles' : 'autre'}';
    }
  }

  /// Après un refus : le médecin corrige ses informations et renvoie sa demande.
  Future<String?> renvoyerDemande({required String nom, required String telephone, required String numeroOrdre}) async {
    try {
      await _fs.collection('medecins').doc(_uid).update({
        'nom': nom.trim(),
        'telephone': telephone.trim(),
        'numero_ordre': numeroOrdre.trim(),
        'statut': 'en_attente',
        'motif': '',
        'demande_le': FieldValue.serverTimestamp(),
      });
      notifierAdmins(
        nom: nom.trim(),
        email: _auth.currentUser?.email ?? '',
        telephone: telephone.trim(),
        numeroOrdre: numeroOrdre.trim(),
        renvoi: true,
      );
      await chargerSession();
      return null;
    } on FirebaseException {
      return 'md_err_chargement';
    }
  }

  /// Changement de mot de passe (le médecin redonne l'ancien : Firebase exige
  /// une connexion récente pour cette opération).
  Future<String?> changerMotDePasse(String ancien, String nouveau) async {
    final u = _auth.currentUser;
    if (u == null || u.email == null) return 'md_err_session';
    try {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: ancien));
      await u.updatePassword(nouveau);
      return null;
    } on FirebaseAuthException catch (e) {
      return _erreurAuth(e);
    }
  }

  // --- Administrateur -------------------------------------------------------------------
  /// Toutes les demandes et tous les comptes médecins (lecture réservée à l'admin).
  Future<List<Medecin>> comptesMedecins() async {
    final q = await _fs.collection('medecins').get();
    final l = [for (final d in q.docs) Medecin.depuis(d.id, d.data())];
    l.sort((a, b) => (b.demandeLe ?? DateTime(2000)).compareTo(a.demandeLe ?? DateTime(2000)));
    return l;
  }

  // --- Mises à jour en direct --------------------------------------------------------
  // Ces flux ne transportent pas de données : ils signalent seulement qu'un
  // document a changé, et l'écran recharge alors ce qu'il affiche. Le premier
  // instantané (l'état au moment de l'abonnement) est ignoré.

  /// Une patiente liée a changé : nouvelle patiente, patiente retirée, ou fin
  /// d'une synchronisation de son téléphone (champ « maj » de son dossier).
  Stream<void> changementsPatients() =>
      _fs.collection('users').where('medecin_uid', isEqualTo: _uid).snapshots().skip(1).map((_) {});

  /// Le dossier d'une patiente a changé (synchronisation, nouveau plan…).
  Stream<void> changementsDossier(String uid) => _user(uid).snapshots().skip(1).map((_) {});

  /// Statut du compte du médecin connecté, en direct (attente → validé).
  Stream<String> statutDuCompte() =>
      _fs.collection('medecins').doc(_uid).snapshots().map((d) => (d.data()?['statut'] as String?) ?? '');

  /// Demandes et comptes médecins (administrateur) : un changement.
  Stream<void> changementsMedecins() => _fs.collection('medecins').snapshots().skip(1).map((_) {});

  /// Nombre de demandes en attente, en direct (pour l'alerte de l'espace
  /// Administration quand une nouvelle demande arrive).
  Stream<int> demandesEnAttente() =>
      _fs.collection('medecins').where('statut', isEqualTo: 'en_attente').snapshots().map((q) => q.size);

  /// Décision de l'administrateur : « valide », « refuse » (avec motif) ou
  /// retour « en_attente ». Un compte refusé ou suspendu perd tout accès.
  Future<void> decider(String uid, String statut, {String motif = ''}) => _fs.collection('medecins').doc(uid).update({
        'statut': statut,
        'motif': motif,
        'decision_le': FieldValue.serverTimestamp(),
        'decision_par': _uid,
      });

  /// Codes créés avant l'alerte de crise : on y ajoute le courriel du médecin
  /// (l'app de la patiente s'en sert pour le prévenir d'une alerte de niveau 4).
  Future<void> _completerCode(String code, String email) async {
    if (email.isEmpty) return;
    try {
      final ref = _fs.collection('codes_medecin').doc(code);
      final s = await ref.get();
      if (s.exists && (s.data()?['email'] as String? ?? '') != email) await ref.update({'email': email});
    } catch (_) {}
  }

  Future<String?> _creerCode(String uid, String nom) async {
    final lettres = nom.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').replaceFirst(RegExp(r'^DR'), '');
    final prefixe = (lettres.length >= 3 ? lettres.substring(0, 3) : '${lettres}MED'.substring(0, 3));
    final r = Random.secure();
    for (var essai = 0; essai < 5; essai++) {
      final code = '$prefixe-${1000 + r.nextInt(9000)}';
      try {
        // create() échoue si ce code existe déjà : on en essaie un autre.
        await _fs.runTransaction((tx) async {
          final ref = _fs.collection('codes_medecin').doc(code);
          final s = await tx.get(ref);
          if (s.exists) throw StateError('pris');
          tx.set(ref, {'uid': uid, 'nom': nom, 'email': _auth.currentUser?.email ?? ''});
        });
        await _fs.collection('medecins').doc(uid).update({'code': code});
        return code;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> deconnecter() async {
    medecin = null;
    admin = false;
    await _auth.signOut();
  }

  Future<void> motDePasseOublie(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  // --- Lecture ------------------------------------------------------------------
  Future<List<MesureM>> _mesures(String uid, DateTime depuis) async {
    final q = await _user(uid)
        .collection('mesures')
        .where('date_ms', isGreaterThanOrEqualTo: depuis.millisecondsSinceEpoch)
        .orderBy('date_ms')
        .get();
    return [for (final d in q.docs) MesureM.depuis(d.id, d.data())];
  }

  Future<List<PriseM>> _prises(String uid) async {
    final q = await _user(uid).collection('prises').get();
    return [for (final d in q.docs) PriseM.depuis(d.data())];
  }

  Future<List<MessageM>> _messages(String uid) async {
    final q = await _user(uid).collection('messages').get();
    return [for (final d in q.docs) MessageM.depuis(d.id, d.data())]..sort((a, b) => a.date.compareTo(b.date));
  }

  static Profil _profil(Map<String, dynamic>? d) {
    final p = d?['profil'];
    return p is Map ? Profil.fromJson(Map<String, dynamic>.from(p)) : Profil();
  }

  /// Liste des patientes qui ont choisi ce médecin, avec leurs indicateurs.
  Future<List<ResumePatient>> patients() async {
    final q = await _fs.collection('users').where('medecin_uid', isEqualTo: _uid).get();
    final depuis = minuit(DateTime.now()).subtract(const Duration(days: 30));
    final res = await Future.wait(q.docs.map((doc) async {
      final r = await Future.wait([_mesures(doc.id, depuis), _prises(doc.id), _messages(doc.id)]);
      return resumer(
        uid: doc.id,
        profil: _profil(doc.data()),
        mesures: r[0] as List<MesureM>,
        prises: r[1] as List<PriseM>,
        messages: r[2] as List<MessageM>,
      );
    }));
    return trierPatients(res);
  }

  /// Dossier complet (90 derniers jours de mesures).
  Future<Dossier> dossier(String uid) async {
    final doc = await _user(uid).get();
    final d = doc.data();
    final depuis = minuit(DateTime.now()).subtract(const Duration(days: 92));
    final r = await Future.wait([
      _mesures(uid, depuis),
      _prises(uid),
      _messages(uid),
      _user(uid).collection('plans').orderBy('date_ms', descending: true).get(),
      _user(uid).collection('notes').get(),
    ]);
    final plans = r[3] as QuerySnapshot<Map<String, dynamic>>;
    final notes = r[4] as QuerySnapshot<Map<String, dynamic>>;
    final plan = d?['plan'];
    final maj = d?['maj'];
    return Dossier(
      uid: uid,
      profil: _profil(d),
      email: d?['email'] as String?,
      derniereSynchro: maj is Timestamp ? maj.toDate() : null,
      plan: plan is Map ? PlanM.depuis(Map<String, dynamic>.from(plan)) : null,
      mesures: r[0] as List<MesureM>,
      prises: r[1] as List<PriseM>,
      messages: r[2] as List<MessageM>,
      historique: [for (final p in plans.docs) PlanM.depuis(p.data())],
      notes: {
        for (final n in notes.docs)
          n.id: NoteM(
            mesureId: n.id,
            texte: (n.data()['texte'] as String?) ?? '',
            date: DateTime.fromMillisecondsSinceEpoch((n.data()['date_ms'] as num?)?.toInt() ?? 0),
          ),
      },
    );
  }

  // --- Écriture -------------------------------------------------------------------
  String _id() {
    final r = Random.secure();
    return List.generate(20, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
  }

  Future<void> envoyerMessage(String uid, String texte) async {
    final id = _id();
    final now = DateTime.now();
    await _user(uid).collection('messages').doc(id).set({
      'id': id,
      'date': Timestamp.fromDate(now),
      'date_ms': now.millisecondsSinceEpoch,
      'de_moi': false,
      'texte': texte,
      'medecin_uid': _uid,
    });
  }

  /// Marque les messages de la patiente comme lus.
  Future<void> marquerLus(String uid, List<MessageM> messages) async {
    final aMarquer = messages.where((m) => m.deMoi && !m.lu).toList();
    if (aMarquer.isEmpty) return;
    final b = _fs.batch();
    for (final m in aMarquer) {
      b.update(_user(uid).collection('messages').doc(m.id), {'lu': true});
    }
    await b.commit();
  }

  /// Nouveau plan : écrit dans le dossier (l'application de la patiente
  /// l'applique à la prochaine synchronisation), ajouté à l'historique, et
  /// la patiente reçoit un message.
  Future<void> modifierPlan(String uid, {required PlanM? ancien, required String medicament, required double doseMg, required int heure, required int minute, required String message}) async {
    final m = medecin!;
    final now = DateTime.now();
    final plan = PlanTraitement(
      medicament: medicament,
      doseMg: doseMg,
      heure: heure,
      minute: minute,
      modifiePar: m.nom,
      dateModif: now,
      ancienneDoseMg: ancien?.doseMg,
    );
    final b = _fs.batch();
    b.update(_user(uid), {'plan': plan.toJson(), 'plan_maj': FieldValue.serverTimestamp()});
    b.set(_user(uid).collection('plans').doc(_id()), {
      'medicament': medicament,
      'doseMg': doseMg,
      'heure': heure,
      'minute': minute,
      'ancienneDoseMg': ancien?.doseMg,
      'date_ms': now.millisecondsSinceEpoch,
      'medecin_uid': m.uid,
      'medecin_nom': m.nom,
    });
    final id = _id();
    b.set(_user(uid).collection('messages').doc(id), {
      'id': id,
      'date': Timestamp.fromDate(now),
      'date_ms': now.millisecondsSinceEpoch,
      'de_moi': false,
      'texte': message,
      'medecin_uid': m.uid,
    });
    await b.commit();
  }

  /// Note sur une mesure, visible par la patiente (envoyée aussi en message).
  Future<void> annoter(String uid, MesureM mesure, String texte, String message) async {
    final now = DateTime.now();
    final b = _fs.batch();
    b.set(_user(uid).collection('notes').doc(mesure.id), {
      'texte': texte,
      'date_ms': now.millisecondsSinceEpoch,
      'mesure_date_ms': mesure.date.millisecondsSinceEpoch,
      'medecin_uid': _uid,
    });
    final id = _id();
    b.set(_user(uid).collection('messages').doc(id), {
      'id': id,
      'date': Timestamp.fromDate(now),
      'date_ms': now.millisecondsSinceEpoch,
      'de_moi': false,
      'texte': message,
      'medecin_uid': _uid,
    });
    await b.commit();
  }
}
