// Rapport PDF partagé par la patiente et notes du médecin reçues dans l'app.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/commun/rapport_pdf.dart';
import 'package:welltech/core/classification.dart';
import 'package:welltech/data/models.dart';
import 'package:welltech/medecin/calculs.dart';

Mesure locale(String id, DateTime d, int s, int di, {List<String> sym = const [], int niveau = 1, String? episode, String grade = ''}) => Mesure(
      id: id,
      date: d,
      tas: s,
      tad: di,
      pouls: 70,
      nbLectures: 2,
      grade: grade.isEmpty ? classer(s, di).name : grade,
      symptomes: sym,
      niveauAlerte: niveau,
      episodeId: episode,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hier = DateTime.now().subtract(const Duration(days: 1));
  final debut = DateTime.now().subtract(const Duration(days: 27));

  test('Mesure du téléphone → mesure du rapport : mêmes valeurs, crise conservée', () {
    final r = MesureM.depuisLocale(locale('a', hier, 185, 125, niveau: 4, episode: 'ep1', sym: ['poitrine']));
    expect(r.tas, 185);
    expect(r.grade, Grade.grade3);
    expect(r.crise, isTrue);
    expect(r.niveau, 4);
    expect(r.symptomes, ['poitrine']);
    // Grade illisible : recalculé à partir des valeurs
    expect(MesureM.depuisLocale(locale('b', hier, 150, 95, grade: '???')).grade, Grade.grade2);
  });

  test('Événements : une ligne par crise, symptômes, notes, triés par date', () {
    final d = DonneesRapport(
      profil: Profil(prenom: 'Test'),
      mesures: [
        MesureM.depuisLocale(locale('c1', hier, 185, 125, niveau: 4, episode: 'ep1', sym: ['poitrine'])),
        MesureM.depuisLocale(locale('c2', hier.add(const Duration(minutes: 5)), 182, 121, niveau: 4, episode: 'ep1')),
        MesureM.depuisLocale(locale('s1', hier.subtract(const Duration(days: 2)), 150, 95, sym: ['tete'])),
      ],
      notes: [NoteM(mesureId: 's1', texte: 'Refaire demain matin', date: hier.subtract(const Duration(days: 1)))],
    );
    final ev = evenementsRapport(d, debut);
    expect(ev.length, 3); // 1 crise (2 mesures), 1 symptôme, 1 note
    expect(ev.where((e) => e.$2.contains('185/125')).length, 1);
    expect(ev.any((e) => e.$2.contains('Refaire demain matin')), isTrue);
    for (var i = 1; i < ev.length; i++) {
      expect(ev[i].$1.isBefore(ev[i - 1].$1), isFalse);
    }
  });

  test('Nom du fichier : WellTech_Prenom_AAAA-MM-JJ.pdf, sans caractères spéciaux', () {
    expect(nomFichierRapport(Profil(prenom: 'Test')), matches(RegExp(r'^WellTech_Test_\d{4}-\d{2}-\d{2}\.pdf$')));
    expect(nomFichierRapport(Profil()), startsWith('WellTech_patiente_'));
    expect(nomFichierRapport(Profil(prenom: 'Test'), prefixe: 'WellTech_mesures'), startsWith('WellTech_mesures_Test_'));
  });

  test('Note reçue du cloud : texte, date de la note et de la mesure', () {
    final n = NoteMedecin.depuisCloud('s1', {'texte': 'Bien', 'date_ms': 1000, 'mesure_date_ms': 500, 'medecin_uid': 'x'});
    expect(n.mesureId, 's1');
    expect(n.texte, 'Bien');
    expect(n.mesureDate, DateTime.fromMillisecondsSinceEpoch(500));
    final copie = NoteMedecin.fromRow(n.toRow());
    expect(copie.texte, 'Bien');
    expect(copie.lue, isFalse);
  });

  test('Le PDF de la patiente et l’export sont de vrais fichiers PDF', () async {
    final d = DonneesRapport(
      profil: Profil(prenom: 'Test'),
      medecinNom: 'Dr Paul Test',
      mesures: [
        for (var i = 0; i < 10; i++) MesureM.depuisLocale(locale('m$i', DateTime.now().subtract(Duration(days: i)), 130 + i, 82)),
      ],
      notes: [NoteM(mesureId: 'm1', texte: 'Bien', date: hier)],
    );
    for (final octets in [await genererRapport(d, jours: 30), await genererExportMesures(d)]) {
      expect(octets.length, greaterThan(1000));
      expect(ascii.decode(octets.sublist(0, 5)), '%PDF-');
    }
  });
}
