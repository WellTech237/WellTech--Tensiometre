import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'models.dart';

/// Base SQLite chiffrée (SQLCipher). La clé est créée au premier lancement et
/// gardée dans le coffre-fort du téléphone (Keystore Android).
class BaseLocale {
  BaseLocale._();
  static final instance = BaseLocale._();

  static const _coffre = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Base non ouverte');
    return d;
  }

  Future<void> ouvrir() async {
    var cle = await _coffre.read(key: 'db_key');
    if (cle == null) {
      final r = Random.secure();
      cle = base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
      await _coffre.write(key: 'db_key', value: cle);
    }
    final chemin = p.join(await getDatabasesPath(), 'welltech.db');
    _db = await openDatabase(
      chemin,
      password: cle,
      version: 3,
      onUpgrade: (db, ancienne, nouvelle) async {
        if (ancienne < 2) await _creerTablesV2(db);
        if (ancienne < 3) await _creerTablesV3(db);
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mesures (
            id TEXT PRIMARY KEY,
            date_ms INTEGER NOT NULL,
            tas INTEGER NOT NULL,
            tad INTEGER NOT NULL,
            pouls INTEGER NOT NULL,
            nb_lectures INTEGER NOT NULL,
            grade TEXT NOT NULL,
            symptomes TEXT NOT NULL,
            niveau_alerte INTEGER NOT NULL,
            episode_id TEXT,
            sync_status TEXT NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_mesures_date ON mesures(date_ms)');
        await db.execute('''
          CREATE TABLE alertes (
            id TEXT PRIMARY KEY,
            date_ms INTEGER NOT NULL,
            niveau INTEGER NOT NULL,
            titre TEXT NOT NULL,
            detail TEXT NOT NULL,
            lue INTEGER NOT NULL
          )''');
        await db.execute('CREATE TABLE reglages (cle TEXT PRIMARY KEY, valeur TEXT NOT NULL)');
        await _creerTablesV2(db);
        await _creerTablesV3(db);
      },
    );
  }

  /// Version 2 : prises de médicament et messages.
  static Future<void> _creerTablesV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prises (
        id TEXT PRIMARY KEY,
        jour_ms INTEGER NOT NULL,
        heure_ms INTEGER,
        medicament TEXT NOT NULL,
        dose_mg REAL NOT NULL,
        statut TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prises_jour ON prises(jour_ms)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        date_ms INTEGER NOT NULL,
        de_moi INTEGER NOT NULL,
        texte TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )''');
  }

  /// Version 3 : notes du médecin sur les mesures (une par mesure).
  static Future<void> _creerTablesV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        mesure_id TEXT PRIMARY KEY,
        texte TEXT NOT NULL,
        date_ms INTEGER NOT NULL,
        mesure_date_ms INTEGER,
        lue INTEGER NOT NULL DEFAULT 0
      )''');
  }

  // --- Réglages / profil ---------------------------------------------------
  Future<String?> lireReglage(String cle) async {
    final r = await db.query('reglages', where: 'cle = ?', whereArgs: [cle], limit: 1);
    return r.isEmpty ? null : r.first['valeur'] as String;
  }

  Future<void> ecrireReglage(String cle, String valeur) =>
      db.insert('reglages', {'cle': cle, 'valeur': valeur}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Profil?> lireProfil() async {
    final s = await lireReglage('profil');
    return s == null ? null : Profil.decoder(s);
  }

  Future<void> ecrireProfil(Profil profil) => ecrireReglage('profil', profil.encoder());

  // --- Mesures ---------------------------------------------------------------
  /// insert « ignore » : réinsérer le même UUID ne crée jamais de doublon.
  Future<void> ajouterMesure(Mesure m) => db.insert('mesures', m.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<Mesure>> mesuresDepuis(DateTime debut) async {
    final r = await db.query('mesures', where: 'date_ms >= ?', whereArgs: [debut.millisecondsSinceEpoch], orderBy: 'date_ms ASC');
    return r.map(Mesure.fromRow).toList();
  }

  Future<void> supprimerMesure(String id) => db.delete('mesures', where: 'id = ?', whereArgs: [id]);

  Future<Mesure?> derniereMesure() async {
    final r = await db.query('mesures', where: 'episode_id IS NULL', orderBy: 'date_ms DESC', limit: 1);
    return r.isEmpty ? null : Mesure.fromRow(r.first);
  }

  // --- Synchronisation (étape 2) ------------------------------------------------
  Future<List<Mesure>> mesuresEnAttente() async {
    final r = await db.query('mesures', where: 'sync_status = ?', whereArgs: ['pending'], orderBy: 'date_ms ASC');
    return r.map(Mesure.fromRow).toList();
  }

  Future<void> marquerSynchro(List<String> ids) async {
    if (ids.isEmpty) return;
    final b = db.batch();
    for (final id in ids) {
      b.update('mesures', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
    }
    await b.commit(noResult: true);
  }

  /// Mesure venant du cloud (nouveau téléphone) : déjà synchronisée.
  Future<void> importerMesure(Mesure m) async {
    final row = m.toRow()..['sync_status'] = 'synced';
    await db.insert('mesures', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Mesure>> mesuresEpisode(String episodeId) async {
    final r = await db.query('mesures', where: 'episode_id = ?', whereArgs: [episodeId], orderBy: 'date_ms ASC');
    return r.map(Mesure.fromRow).toList();
  }

  // --- Alertes ---------------------------------------------------------------
  Future<void> ajouterAlerte(AlerteEnregistree a) => db.insert('alertes', a.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<AlerteEnregistree>> alertes({int limite = 30}) async {
    final r = await db.query('alertes', orderBy: 'date_ms DESC', limit: limite);
    return r.map(AlerteEnregistree.fromRow).toList();
  }

  Future<void> marquerAlertesLues() => db.update('alertes', {'lue': 1});

  Future<void> marquerAlerteLue(String id) => db.update('alertes', {'lue': 1}, where: 'id = ?', whereArgs: [id]);

  // --- Prises de médicament ---------------------------------------------------
  /// Une seule prise par jour : on remplace celle du même jour.
  Future<void> enregistrerPrise(Prise p) async {
    await db.delete('prises', where: 'jour_ms = ?', whereArgs: [p.jour.millisecondsSinceEpoch]);
    await db.insert('prises', p.toRow());
  }

  Future<void> supprimerPrise(DateTime jour) => db.delete('prises', where: 'jour_ms = ?', whereArgs: [jour.millisecondsSinceEpoch]);

  Future<List<Prise>> prisesDepuis(DateTime debut) async {
    final r = await db.query('prises', where: 'jour_ms >= ?', whereArgs: [debut.millisecondsSinceEpoch], orderBy: 'jour_ms ASC');
    return r.map(Prise.fromRow).toList();
  }

  /// Supprime toutes les données de santé du téléphone (droit à l'effacement).
  Future<void> effacerTout() async {
    for (final t in const ['mesures', 'alertes', 'reglages', 'prises', 'messages', 'notes']) {
      await db.delete(t);
    }
  }

  // --- Messages ----------------------------------------------------------------
  Future<void> ajouterMessage(Message m) => db.insert('messages', m.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<Message>> messages() async {
    final r = await db.query('messages', orderBy: 'date_ms ASC');
    return r.map(Message.fromRow).toList();
  }

  // --- Synchronisation des prises et des messages ------------------------------
  Future<List<Prise>> prisesEnAttente() async {
    final r = await db.query('prises', where: 'sync_status = ?', whereArgs: ['pending'], orderBy: 'jour_ms ASC');
    return r.map(Prise.fromRow).toList();
  }

  Future<List<Message>> messagesEnAttente() async {
    final r = await db.query('messages', where: 'sync_status = ? AND de_moi = 1', whereArgs: ['pending'], orderBy: 'date_ms ASC');
    return r.map(Message.fromRow).toList();
  }

  Future<void> marquerSynchroTable(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    final b = db.batch();
    for (final id in ids) {
      b.update(table, {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
    }
    await b.commit(noResult: true);
  }

  /// Prise venant du cloud : ajoutée seulement si ce jour-là est vide ici.
  Future<void> importerPrise(Prise p) async {
    final r = await db.query('prises', where: 'jour_ms = ?', whereArgs: [p.jour.millisecondsSinceEpoch], limit: 1);
    if (r.isNotEmpty) return;
    await db.insert('prises', p.toRow()..['sync_status'] = 'synced');
  }

  /// Message venant du cloud (message du médecin, ou nouveau téléphone).
  /// Renvoie true s'il est nouveau.
  Future<bool> importerMessage(Message m) async {
    final n = await db.insert('messages', m.toRow()..['sync_status'] = 'synced', conflictAlgorithm: ConflictAlgorithm.ignore);
    return n > 0;
  }

  // --- Notes du médecin ---------------------------------------------------------
  /// Note reçue du cloud. Nouvelle note ou texte corrigé : enregistrée comme
  /// non lue. Renvoie true dans ces deux cas.
  Future<bool> importerNote(NoteMedecin n) async {
    final r = await db.query('notes', where: 'mesure_id = ?', whereArgs: [n.mesureId], limit: 1);
    if (r.isNotEmpty) {
      final a = NoteMedecin.fromRow(r.first);
      if (a.texte == n.texte && a.date == n.date) return false;
    }
    await db.insert('notes', n.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  /// Notes écrites depuis [debut], de la plus récente à la plus ancienne.
  Future<List<NoteMedecin>> notesDepuis(DateTime debut) async {
    final r = await db.query('notes', where: 'date_ms >= ? OR mesure_date_ms >= ?', whereArgs: [debut.millisecondsSinceEpoch, debut.millisecondsSinceEpoch], orderBy: 'date_ms DESC');
    return r.map(NoteMedecin.fromRow).toList();
  }

  Future<int> notesNonLues() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM notes WHERE lue = 0');
    return (r.first['n'] as int?) ?? 0;
  }

  Future<void> marquerNotesLues() => db.update('notes', {'lue': 1}, where: 'lue = 0');

  // --- Opérations cloud en attente (annulations) --------------------------------
  // Une mesure ou une prise annulée après son envoi n'est jamais effacée du
  // cloud (traçabilité médicale) : on la marque « annulée » à la prochaine
  // synchronisation. Ces opérations attendent ici tant qu'Internet manque.
  Future<List<Map<String, dynamic>>> opsCloud() async {
    final s = await lireReglage('cloud_ops');
    if (s == null) return [];
    return List<Map<String, dynamic>>.from((jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<void> _ecrireOps(List<Map<String, dynamic>> ops) => ecrireReglage('cloud_ops', jsonEncode(ops));

  Future<void> ajouterOpCloud(String type, String cle) async {
    final ops = await opsCloud();
    ops.removeWhere((o) => o['t'] == type && o['cle'] == cle);
    ops.add({'t': type, 'cle': cle, 'ms': DateTime.now().millisecondsSinceEpoch});
    await _ecrireOps(ops);
  }

  Future<void> retirerOpCloud(String type, String cle) async {
    final ops = await opsCloud();
    final avant = ops.length;
    ops.removeWhere((o) => o['t'] == type && o['cle'] == cle);
    if (ops.length != avant) await _ecrireOps(ops);
  }
}
