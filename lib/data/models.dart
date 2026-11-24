import 'dart:convert';

class Medicament {
  String nom;
  String dose;
  String frequence;
  Medicament({this.nom = '', this.dose = '', this.frequence = ''});

  Map<String, dynamic> toJson() => {'nom': nom, 'dose': dose, 'frequence': frequence};
  factory Medicament.fromJson(Map<String, dynamic> j) =>
      Medicament(nom: j['nom'] ?? '', dose: j['dose'] ?? '', frequence: j['frequence'] ?? '');
}

/// Profil du patient (écran « Profil, une question à la fois »).
class Profil {
  String prenom;
  String nom;
  DateTime? naissance;
  bool femme;
  bool enceinte;
  int? semainesGrossesse;
  double? tailleCm;
  double? poidsKg;
  bool avc;
  int? anneeAvc;
  Set<String> maladies;
  String autreMaladie;
  bool prendMedicaments;
  List<Medicament> medicaments;
  String autresRenseignements;

  Profil({
    this.prenom = '',
    this.nom = '',
    this.naissance,
    this.femme = true,
    this.enceinte = false,
    this.semainesGrossesse,
    this.tailleCm,
    this.poidsKg,
    this.avc = false,
    this.anneeAvc,
    Set<String>? maladies,
    this.autreMaladie = '',
    this.prendMedicaments = false,
    List<Medicament>? medicaments,
    this.autresRenseignements = '',
  })  : maladies = maladies ?? <String>{},
        medicaments = medicaments ?? <Medicament>[];

  int? get age {
    final n = naissance;
    if (n == null) return null;
    final now = DateTime.now();
    var a = now.year - n.year;
    if (now.month < n.month || (now.month == n.month && now.day < n.day)) a--;
    return a;
  }

  double? get imc {
    final t = tailleCm, p = poidsKg;
    if (t == null || p == null || t <= 0) return null;
    final m = t / 100;
    return p / (m * m);
  }

  bool get grossesseActive => femme && enceinte;

  Map<String, dynamic> toJson() => {
        'prenom': prenom,
        'nom': nom,
        'naissance': naissance?.toIso8601String(),
        'femme': femme,
        'enceinte': enceinte,
        'semainesGrossesse': semainesGrossesse,
        'tailleCm': tailleCm,
        'poidsKg': poidsKg,
        'avc': avc,
        'anneeAvc': anneeAvc,
        'maladies': maladies.toList(),
        'autreMaladie': autreMaladie,
        'prendMedicaments': prendMedicaments,
        'medicaments': medicaments.map((m) => m.toJson()).toList(),
        'autresRenseignements': autresRenseignements,
      };

  factory Profil.fromJson(Map<String, dynamic> j) => Profil(
        prenom: j['prenom'] ?? '',
        nom: j['nom'] ?? '',
        naissance: j['naissance'] != null ? DateTime.tryParse(j['naissance']) : null,
        femme: j['femme'] ?? true,
        enceinte: j['enceinte'] ?? false,
        semainesGrossesse: j['semainesGrossesse'],
        tailleCm: (j['tailleCm'] as num?)?.toDouble(),
        poidsKg: (j['poidsKg'] as num?)?.toDouble(),
        avc: j['avc'] ?? false,
        anneeAvc: j['anneeAvc'],
        maladies: Set<String>.from(j['maladies'] ?? const []),
        autreMaladie: j['autreMaladie'] ?? '',
        prendMedicaments: j['prendMedicaments'] ?? false,
        medicaments: ((j['medicaments'] ?? const []) as List)
            .map((e) => Medicament.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        autresRenseignements: j['autresRenseignements'] ?? '',
      );

  String encoder() => jsonEncode(toJson());
  static Profil decoder(String s) => Profil.fromJson(jsonDecode(s));
}

/// Une séance de mesure : moyenne de 1 ou 2 lectures. Jamais modifiée après coup
/// (on ajoute, on ne remplace pas) pour éviter les conflits de synchronisation.
class Mesure {
  final String id; // UUID créé sur le téléphone = identifiant Firestore plus tard
  final DateTime date;
  final int tas;
  final int tad;
  final int pouls;
  final int nbLectures;
  final String grade; // nom de l'enum Grade
  final List<String> symptomes;
  final int niveauAlerte; // 1 à 4
  final String? episodeId; // mesures d'un épisode de crise
  final String syncStatus; // pending | synced

  Mesure({
    required this.id,
    required this.date,
    required this.tas,
    required this.tad,
    required this.pouls,
    required this.nbLectures,
    required this.grade,
    required this.symptomes,
    required this.niveauAlerte,
    this.episodeId,
    this.syncStatus = 'pending',
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'date_ms': date.millisecondsSinceEpoch,
        'tas': tas,
        'tad': tad,
        'pouls': pouls,
        'nb_lectures': nbLectures,
        'grade': grade,
        'symptomes': jsonEncode(symptomes),
        'niveau_alerte': niveauAlerte,
        'episode_id': episodeId,
        'sync_status': syncStatus,
      };

  factory Mesure.fromRow(Map<String, Object?> r) => Mesure(
        id: r['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(r['date_ms'] as int),
        tas: r['tas'] as int,
        tad: r['tad'] as int,
        pouls: r['pouls'] as int,
        nbLectures: r['nb_lectures'] as int,
        grade: r['grade'] as String,
        symptomes: List<String>.from(jsonDecode(r['symptomes'] as String)),
        niveauAlerte: r['niveau_alerte'] as int,
        episodeId: r['episode_id'] as String?,
        syncStatus: r['sync_status'] as String,
      );
}

class AlerteEnregistree {
  final String id;
  final DateTime date;
  final int niveau;
  final String titre;
  final String detail;
  final bool lue;

  AlerteEnregistree({required this.id, required this.date, required this.niveau, required this.titre, required this.detail, this.lue = false});

  Map<String, Object?> toRow() => {
        'id': id,
        'date_ms': date.millisecondsSinceEpoch,
        'niveau': niveau,
        'titre': titre,
        'detail': detail,
        'lue': lue ? 1 : 0,
      };

  factory AlerteEnregistree.fromRow(Map<String, Object?> r) => AlerteEnregistree(
        id: r['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(r['date_ms'] as int),
        niveau: r['niveau'] as int,
        titre: r['titre'] as String,
        detail: r['detail'] as String,
        lue: (r['lue'] as int) == 1,
      );
}

/// Prise de médicament (heure réelle notée par la patiente).
/// Elle relie la dose à la tension, comme le demande le client.
class Prise {
  final String id;
  final DateTime jour; // jour concerné (minuit)
  final DateTime? heure; // heure réelle de la prise, null si oubliée
  final String medicament;
  final double doseMg;
  final String statut; // pris | oubli
  final String syncStatus;

  Prise({required this.id, required this.jour, required this.heure, required this.medicament, required this.doseMg, required this.statut, this.syncStatus = 'pending'});

  bool get prise => statut == 'pris';

  Map<String, Object?> toRow() => {
        'id': id,
        'jour_ms': jour.millisecondsSinceEpoch,
        'heure_ms': heure?.millisecondsSinceEpoch,
        'medicament': medicament,
        'dose_mg': doseMg,
        'statut': statut,
        'sync_status': syncStatus,
      };

  factory Prise.fromRow(Map<String, Object?> r) => Prise(
        id: r['id'] as String,
        jour: DateTime.fromMillisecondsSinceEpoch(r['jour_ms'] as int),
        heure: r['heure_ms'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['heure_ms'] as int),
        medicament: r['medicament'] as String,
        doseMg: (r['dose_mg'] as num).toDouble(),
        statut: r['statut'] as String,
        syncStatus: r['sync_status'] as String,
      );
}

/// Plan de traitement. Seul le médecin le modifie (depuis l'espace médecin) ;
/// au départ, il est repris du profil.
class PlanTraitement {
  final String medicament;
  final double doseMg;
  final int heure; // heure prévue
  final int minute;
  final String? modifiePar;
  final DateTime? dateModif;
  final double? ancienneDoseMg;

  const PlanTraitement({required this.medicament, required this.doseMg, this.heure = 20, this.minute = 0, this.modifiePar, this.dateModif, this.ancienneDoseMg});

  Map<String, dynamic> toJson() => {
        'medicament': medicament,
        'doseMg': doseMg,
        'heure': heure,
        'minute': minute,
        'modifiePar': modifiePar,
        'dateModif': dateModif?.toIso8601String(),
        'ancienneDoseMg': ancienneDoseMg,
      };

  factory PlanTraitement.fromJson(Map<String, dynamic> j) => PlanTraitement(
        medicament: j['medicament'] ?? '',
        doseMg: (j['doseMg'] as num?)?.toDouble() ?? 0,
        heure: j['heure'] ?? 20,
        minute: j['minute'] ?? 0,
        modifiePar: j['modifiePar'],
        dateModif: j['dateModif'] != null ? DateTime.tryParse(j['dateModif']) : null,
        ancienneDoseMg: (j['ancienneDoseMg'] as num?)?.toDouble(),
      );

  String encoder() => jsonEncode(toJson());
  static PlanTraitement decoder(String s) => PlanTraitement.fromJson(jsonDecode(s));
}

/// Contact d'urgence (prévenu par SMS en cas de crise).
class ContactUrgence {
  final String nom;
  final String telephone;
  const ContactUrgence(this.nom, this.telephone);
  String encoder() => jsonEncode({'nom': nom, 'tel': telephone});
  static ContactUrgence decoder(String s) {
    final j = jsonDecode(s);
    return ContactUrgence(j['nom'] ?? '', j['tel'] ?? '');
  }
}

/// Message entre la patiente et son médecin (gardé sur le téléphone ;
/// l'envoi au médecin passera par l'espace médecin, à venir).
class Message {
  final String id;
  final DateTime date;
  final bool deMoi;
  final String texte;
  final String syncStatus;
  Message({required this.id, required this.date, required this.deMoi, required this.texte, this.syncStatus = 'pending'});

  Map<String, Object?> toRow() => {'id': id, 'date_ms': date.millisecondsSinceEpoch, 'de_moi': deMoi ? 1 : 0, 'texte': texte, 'sync_status': syncStatus};
  factory Message.fromRow(Map<String, Object?> r) => Message(
        id: r['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(r['date_ms'] as int),
        deMoi: (r['de_moi'] as int) == 1,
        texte: r['texte'] as String,
        syncStatus: r['sync_status'] as String,
      );
}

/// Note du médecin sur une mesure (reçue du cloud, lue par la patiente).
/// Une note par mesure : le médecin peut la corriger, la nouvelle remplace
/// l'ancienne.
class NoteMedecin {
  final String mesureId;
  final String texte;
  final DateTime date; // date de la note
  final DateTime? mesureDate; // date de la mesure annotée
  final bool lue;
  const NoteMedecin({required this.mesureId, required this.texte, required this.date, this.mesureDate, this.lue = false});

  Map<String, Object?> toRow() => {
        'mesure_id': mesureId,
        'texte': texte,
        'date_ms': date.millisecondsSinceEpoch,
        'mesure_date_ms': mesureDate?.millisecondsSinceEpoch,
        'lue': lue ? 1 : 0,
      };

  factory NoteMedecin.fromRow(Map<String, Object?> r) => NoteMedecin(
        mesureId: r['mesure_id'] as String,
        texte: r['texte'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(r['date_ms'] as int),
        mesureDate: r['mesure_date_ms'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['mesure_date_ms'] as int),
        lue: (r['lue'] as int? ?? 0) == 1,
      );

  /// Document Firestore users/{uid}/notes/{mesureId}.
  factory NoteMedecin.depuisCloud(String mesureId, Map<String, dynamic> d) => NoteMedecin(
        mesureId: mesureId,
        texte: (d['texte'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((d['date_ms'] as num?)?.toInt() ?? 0),
        mesureDate: d['mesure_date_ms'] is num ? DateTime.fromMillisecondsSinceEpoch((d['mesure_date_ms'] as num).toInt()) : null,
      );
}
