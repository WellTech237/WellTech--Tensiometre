// Rapport PDF de suivi, commun au portail du médecin et à l'appli de la
// patiente : les deux produisent EXACTEMENT le même document à partir des
// mêmes calculs (statut, moyennes des 4 grandeurs, dérivée, intégrale,
// limites, observance, courbe TAS/TAD, événements, notes, dernières mesures).
// Aucun accès réseau ni Firebase ici : seulement les données reçues.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/classification.dart';
import '../core/controle.dart';
import '../core/risque.dart';
import '../data/models.dart';
import '../l10n.dart';
import '../medecin/calculs.dart';

const _violet = PdfColor.fromInt(0xFF4433C9);
const _gris = PdfColor.fromInt(0xFF46505E);
const _ligne = PdfColor.fromInt(0xFFE3E1DA);
const _tas = PdfColor.fromInt(0xFF3B2FC0);
const _tad = PdfColor.fromInt(0xFF1F7FC4);

/// Tout ce qu'il faut pour le rapport, quelle que soit la source
/// (Firestore côté médecin, base locale côté patiente).
class DonneesRapport {
  final Profil profil;
  final String medecinNom;
  final PlanM? plan;
  final List<MesureM> mesures;
  final List<PriseM> prises;
  final List<PlanM> historique; // changements de traitement
  final List<NoteM> notes; // notes du médecin sur des mesures
  final String auteur; // métadonnée « auteur » du PDF
  const DonneesRapport({
    required this.profil,
    this.medecinNom = '',
    this.plan,
    required this.mesures,
    this.prises = const [],
    this.historique = const [],
    this.notes = const [],
    this.auteur = 'WellTech',
  });
}

/// Événements de la période, du plus ancien au plus récent : crises (une
/// ligne par épisode), symptômes, changements de traitement, notes du médecin.
List<(DateTime, String)> evenementsRapport(DonneesRapport d, DateTime debut) {
  final mes = filtrer(d.mesures, debut);
  final evenements = <(DateTime, String)>[];
  final episodes = <String>{};
  for (final m in mes) {
    if (m.crise && episodes.add(m.episode!)) {
      final n = mes.where((x) => x.episode == m.episode).length;
      evenements.add((m.date, trL('md_pdf_crise', {'v': '${m.tas}/${m.tad}', 'n': n})));
    } else if (!m.crise && m.symptomes.isNotEmpty) {
      evenements.add((m.date, '${m.symptomes.map((s) => trL('sym_$s')).join(', ')} · ${m.tas}/${m.tad}'));
    }
  }
  for (final h in d.historique) {
    if (!h.date.isBefore(debut)) {
      evenements.add((h.date, '${h.medicament} ${h.ancienneDoseMg != null ? '${nombre(h.ancienneDoseMg!)} mg > ' : ''}${nombre(h.doseMg)} mg${h.medecinNom.isNotEmpty ? ' (${h.medecinNom})' : ''}'));
    }
  }
  for (final n in d.notes) {
    if (!n.date.isBefore(debut)) evenements.add((n.date, '${trL('md_pdf_note')} : ${n.texte}'));
  }
  evenements.sort((a, b) => a.$1.compareTo(b.$1));
  return evenements;
}

/// Nom de fichier : WellTech_Prenom_Nom_2026-11-24.pdf (ou un préfixe donné).
String nomFichierRapport(Profil p, {String prefixe = 'WellTech'}) {
  final now = DateTime.now();
  final nom = '${p.prenom}_${p.nom}'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '').replaceAll(RegExp(r'^_+|_+$'), '');
  final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return '${prefixe}_${nom.isEmpty ? 'patiente' : nom}_$date.pdf';
}

Future<(pw.Font, pw.Font)> _polices() async => (
      pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegible-Regular.ttf')),
      pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegible-Bold.ttf')),
    );

Future<Uint8List> genererRapport(DonneesRapport d, {int jours = 28}) async {
  final (normal, gras) = await _polices();
  final now = DateTime.now();
  final debut = jourDecale(now, -(jours - 1));
  final p = d.profil;
  final pts = pointsJournaliers(d.mesures, debut);
  final ind = Indicateurs.de(pts);
  final obs = observance(d.prises, debut, now);
  final mes = filtrer(d.mesures, debut);
  final moy = ind.moyenne;

  pw.TextStyle st({double taille = 10, bool g = false, PdfColor? c}) => pw.TextStyle(fontSize: taille, fontWeight: g ? pw.FontWeight.bold : pw.FontWeight.normal, color: c);

  pw.Widget titre(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t.toUpperCase(), style: st(taille: 10, g: true, c: _violet)),
      );

  pw.Widget ligne(String k, String v) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _ligne, width: 0.7))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 150, child: pw.Text(k, style: st(g: true, c: _gris))),
          pw.Expanded(child: pw.Text(v, style: st(g: true))),
        ]),
      );

  String g4(Grandeurs? x) => x == null
      ? '—'
      : '${trL('n_tas')} ${x.tas.round()} · ${trL('n_tad')} ${x.tad.round()} · ${trL('n_pm')} ${x.pm.round()} · ${trL('n_pp')} ${x.pp.round()} mmHg';

  final evenements = evenementsRapport(d, debut);

  final doc = pw.Document(
    title: trL('md_pdf_titre'),
    author: d.auteur,
    theme: pw.ThemeData.withFont(base: normal, bold: gras),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: pw.Text(trL('md_pdf_pied', {'d': dateLongue(now)}), style: st(taille: 8, c: _gris))),
        pw.Text(trL('md_pdf_page', {'p': ctx.pageNumber, 't': ctx.pagesCount}), style: st(taille: 8, c: _gris)),
      ]),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _violet, width: 2))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('WellTech', style: st(taille: 11, g: true, c: _violet)),
            pw.Text(trL('md_pdf_titre'), style: st(taille: 20, g: true)),
            pw.Text(trL('md_pdf_periode', {'a': dateCourte(debut), 'b': dateCourte(now), 'n': jours}), style: st(taille: 11, c: _gris)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(trL('md_patiente').toUpperCase(), style: st(taille: 8, g: true, c: _gris)),
              pw.Text('${p.prenom} ${p.nom}'.trim(), style: st(taille: 13, g: true)),
              pw.Text(
                [
                  if (p.age != null) trL('pr_age', {'a': p.age}),
                  trL(p.femme ? 'md_femme' : 'md_homme'),
                  if (p.imc != null) 'IMC ${nombre(p.imc!)}',
                  trL('md_pdf_profil', {'r': calculerRisque(p).libelle}),
                ].join(' · '),
                style: st(),
              ),
              if (p.maladies.isNotEmpty || p.avc)
                pw.Text([if (p.avc) trL('md_avc'), ...p.maladies.map(nomMaladie)].join(', '), style: st(c: _gris)),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(trL('md_pdf_medecin').toUpperCase(), style: st(taille: 8, g: true, c: _gris)),
              pw.Text(d.medecinNom.isEmpty ? '—' : d.medecinNom, style: st(taille: 13, g: true)),
              if (d.plan != null)
                pw.Text('${trL('md_actuel')} : ${d.plan!.medicament} ${nombre(d.plan!.doseMg)} mg · ${heureTexte(d.plan!.heure, d.plan!.minute)}', style: st()),
            ]),
          ),
        ]),
        titre(trL('md_pdf_resume')),
        ligne(trL('md_k_statut'), ind.statut == null ? '—' : '${trL('statut_${ind.statut!.name}')} (${trL('md_k_statut_s', {'n': ind.nbDansPlage})})'),
        ligne(trL('md_pdf_moyennes'), g4(moy)),
        ligne(trL('md_k_derivee'), pts.length < 2 ? '—' : '${_signe(ind.deriveeParSemaine)} ${trL('md_mmhg_sem')}'),
        ligne(trL('md_k_integrale'), pts.length < 2 ? '—' : '${nombre(ind.integraleTas, 0)} mmHg·j · ${trL('md_k_integrale_s')}'),
        ligne(
          trL('md_k_limites'),
          pts.isEmpty
              ? '—'
              : '${ind.limites.pourcentDansPlage.round()} % · ${trL('md_k_limites_s', {
                    'r': ind.limites.retourDurable == null ? trL('su_pas_encore') : dateCourte(jourDecale(debut, ind.limites.retourDurable!.round())),
                  })}',
        ),
        ligne(trL('md_k_obs'), obs == null ? trL('md_k_obs_aucune') : '${(obs.taux * 100).round()} % (${trL('md_k_obs_s', {'n': obs.prises, 'j': obs.jours})})'),
        ligne(trL('md_k_nb'), '${mes.length}'),
        if (pts.length >= 2) ...[
          titre(trL('md_pdf_courbe')),
          pw.SizedBox(
            height: 190,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  [for (var j = 0; j <= jours - 1; j += 7) if (j == 0 || jours - 1 - j >= 4) j, jours - 1],
                  format: (v) => dateCourte(jourDecale(debut, v.round())),
                  textStyle: st(taille: 8, c: _gris),
                ),
                yAxis: pw.FixedAxis(
                  const [60, 80, 100, 120, 140, 160, 180, 200],
                  divisions: true,
                  divisionsColor: _ligne,
                  textStyle: st(taille: 8, c: _gris),
                ),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: trL('n_tas'),
                  color: _tas,
                  drawPoints: true,
                  pointSize: 2,
                  lineWidth: 1.5,
                  data: [for (final q in pts) pw.PointChartValue(q.t, q.v.tas.clamp(60, 200).toDouble())],
                ),
                pw.LineDataSet(
                  legend: trL('n_tad'),
                  color: _tad,
                  drawPoints: true,
                  pointSize: 2,
                  lineWidth: 1.5,
                  data: [for (final q in pts) pw.PointChartValue(q.t, q.v.tad.clamp(60, 200).toDouble())],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(trL('md_pdf_courbe_aide'), style: st(taille: 8, c: _gris)),
          ),
        ],
        titre(trL('md_pdf_evenements')),
        if (evenements.isEmpty)
          pw.Text(trL('md_pdf_aucun_evt'), style: st(c: _gris))
        else
          for (final e in evenements) pw.Bullet(text: '${dateCourte(e.$1)} · ${e.$2}', style: st()),
        titre(trL('md_pdf_mesures')),
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _ligne, width: 0.5)),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.6),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(0.8),
            5: pw.FlexColumnWidth(1.3),
          },
          children: [
            pw.TableRow(children: [
              for (final k in ['md_pdf_c_date', 'md_pdf_c_moment', 'md_pdf_c_val', 'n_pm', 'n_pp', 'md_pdf_c_niveau'])
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(trL(k), style: st(taille: 9, g: true, c: _gris))),
            ]),
            for (final m in mes.reversed.take(25))
              pw.TableRow(children: [
                _cell('${dateCourte(m.date)} · ${heureDe(m.date)}', st(taille: 9)),
                _cell(trL(m.matin ? 'md_m_matin' : 'md_m_soir'), st(taille: 9)),
                _cell('${m.tas}/${m.tad}${m.crise ? ' *' : ''}', st(taille: 9, g: true)),
                _cell('${m.g.pm.round()}', st(taille: 9)),
                _cell('${m.g.pp.round()}', st(taille: 9)),
                _cell(m.grade.court, st(taille: 9)),
              ]),
          ],
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(trL('md_pdf_etoile'), style: st(taille: 8, c: _gris)),
        ),
        pw.SizedBox(height: 14),
        pw.Text(trL('md_pdf_avert'), style: st(taille: 9, c: _gris)),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _cell(String t, pw.TextStyle s) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(t, style: s));

String _signe(double v) => '${v > 0 ? '+' : (v < 0 ? '−' : '')}${nombre(v.abs())}';

/// Export complet des mesures (toutes, de la plus récente à la plus
/// ancienne) : date, valeurs, Pm, Pp, pouls, catégorie, niveau, symptômes et
/// note éventuelle du médecin. Les mesures annulées n'y figurent pas.
Future<Uint8List> genererExportMesures(DonneesRapport d) async {
  final (normal, gras) = await _polices();
  final now = DateTime.now();
  final p = d.profil;
  final mes = [for (final m in d.mesures) if (!m.annulee) m]..sort((a, b) => b.date.compareTo(a.date));
  final notes = {for (final n in d.notes) n.mesureId: n};
  pw.TextStyle st({double taille = 9, bool g = false, PdfColor? c}) => pw.TextStyle(fontSize: taille, fontWeight: g ? pw.FontWeight.bold : pw.FontWeight.normal, color: c);
  pw.Widget cel(String t, pw.TextStyle s) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2), child: pw.Text(t, style: s));

  final doc = pw.Document(title: trL('ex_pdf_titre'), author: d.auteur, theme: pw.ThemeData.withFont(base: normal, bold: gras));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(trL('md_pdf_pied', {'d': dateLongue(now)}), style: st(taille: 8, c: _gris)),
        pw.Text(trL('md_pdf_page', {'p': ctx.pageNumber, 't': ctx.pagesCount}), style: st(taille: 8, c: _gris)),
      ]),
      build: (ctx) => [
        pw.Text('WellTech', style: st(taille: 11, g: true, c: _violet)),
        pw.Text(trL('ex_pdf_titre'), style: st(taille: 18, g: true)),
        pw.Text(
          [
            '${p.prenom} ${p.nom}'.trim(),
            if (p.age != null) trL('pr_age', {'a': p.age}),
            trL('ex_pdf_nb', {'n': mes.length}),
            if (mes.isNotEmpty) '${dateCourte(mes.last.date)} – ${dateCourte(mes.first.date)}',
          ].where((s) => s.isNotEmpty).join(' · '),
          style: st(taille: 11, c: _gris),
        ),
        pw.SizedBox(height: 10),
        if (mes.isEmpty)
          pw.Text(trL('su_vide'), style: st(taille: 11))
        else
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _ligne, width: 0.5)),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(0.9),
              2: pw.FlexColumnWidth(0.5),
              3: pw.FlexColumnWidth(0.5),
              4: pw.FlexColumnWidth(0.6),
              5: pw.FlexColumnWidth(1.0),
              6: pw.FlexColumnWidth(0.5),
              7: pw.FlexColumnWidth(3.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _violet, width: 1))),
                children: [
                  for (final k in ['md_pdf_c_date', 'md_pdf_c_val', 'n_pm', 'n_pp', 'ex_pdf_c_pouls', 'ex_pdf_c_cat', 'md_pdf_c_niveau', 'ex_pdf_c_detail'])
                    cel(trL(k), st(g: true, c: _gris)),
                ],
              ),
              for (final m in mes)
                pw.TableRow(children: [
                  cel('${dateCourte(m.date)} · ${heureDe(m.date)}', st()),
                  cel('${m.tas}/${m.tad}${m.crise ? ' *' : ''}', st(g: true)),
                  cel('${m.g.pm.round()}', st()),
                  cel('${m.g.pp.round()}', st()),
                  cel(m.pouls > 0 ? '${m.pouls}' : '—', st()),
                  cel(m.grade.court, st()),
                  cel('${m.niveau}', st()),
                  cel(
                    [
                      if (m.symptomes.isNotEmpty) m.symptomes.map((s) => trL('sym_$s')).join(', '),
                      if (notes[m.id] != null) '${trL('md_pdf_note')} : ${notes[m.id]!.texte}',
                    ].join(' · '),
                    st(),
                  ),
                ]),
            ],
          ),
        pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text(trL('md_pdf_etoile'), style: st(taille: 8, c: _gris))),
        pw.SizedBox(height: 8),
        pw.Text(trL('md_pdf_avert'), style: st(taille: 8, c: _gris)),
      ],
    ),
  );
  return doc.save();
}
