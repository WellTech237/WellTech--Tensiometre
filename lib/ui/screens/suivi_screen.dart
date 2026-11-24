import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/controle.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/voix.dart';
import '../../theme.dart';
import '../partage.dart';
import '../widgets.dart';
import 'aide_screen.dart';

/// Mon suivi : les 4 grandeurs dans le temps + les indicateurs du client
/// (statut de contrôle, dérivée, intégrale, limites) en mots simples.
class SuiviScreen extends StatefulWidget {
  const SuiviScreen({super.key});
  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _Donnees {
  final List<Point> points;
  final Grandeurs? matin;
  final Grandeurs? soir;
  final List<NoteMedecin> notes; // de la plus récente à la plus ancienne
  final Map<String, Mesure> mesures; // mesures annotées, par identifiant
  _Donnees(this.points, this.matin, this.soir, this.notes, this.mesures);
}

class _SuiviScreenState extends State<SuiviScreen> {
  int _jours = 7;
  final _series = <Grandeur>{Grandeur.tas, Grandeur.tad};
  int? _choisi; // index dans la liste des points
  // Notes non lues à l'ouverture : gardent leur étiquette « Nouveau » tant
  // que l'écran reste ouvert, même après avoir été marquées lues.
  final _nouvelles = <String>{};

  static const _couleurs = {Grandeur.tas: Wt.serieTas, Grandeur.tad: Wt.serieTad, Grandeur.pm: Wt.seriePm, Grandeur.pp: Wt.seriePp};
  static const _tirets = {Grandeur.tas: null, Grandeur.tad: null, Grandeur.pm: [7, 5], Grandeur.pp: [2, 5]};

  Future<_Donnees> _charger() async {
    final e = AppState.instance;
    final pts = await e.pointsJournaliers(_jours);
    final matin = moyenne(await e.pointsJournaliers(_jours, heureMax: 12));
    final soir = moyenne(await e.pointsJournaliers(_jours, heureMin: 12));
    final notes = await e.notesDepuis(_jours);
    _nouvelles.addAll(notes.where((n) => !n.lue).map((n) => n.mesureId));
    final ids = notes.map((n) => n.mesureId).toSet();
    final mesures = {
      for (final m in await e.db.mesuresDepuis(jourDecale(DateTime.now(), -(_jours + 30))))
        if (ids.contains(m.id)) m.id: m,
    };
    return _Donnees(pts, matin, soir, notes, mesures);
  }

  /// Minuit du jour affiché à la position [t] du graphique.
  DateTime _jourDu(double t) {
    final x = _dateDu(t);
    return DateTime(x.year, x.month, x.day);
  }

  /// Jour (minuit) auquel une note se rapporte : celui de la mesure annotée.
  DateTime _jourDe(NoteMedecin n, _Donnees d) {
    final x = d.mesures[n.mesureId]?.date ?? n.mesureDate ?? n.date;
    return DateTime(x.year, x.month, x.day);
  }

  DateTime _dateDu(double t) {
    final now = DateTime.now();
    return jourDecale(now, -(_jours - 1 - t.round()));
  }

  String _nom(BuildContext context, Grandeur g) => context.tr('n_${g.name}');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => FutureBuilder<_Donnees>(
      future: _charger(),
      builder: (context, snap) {
        final d = snap.data;
        final pts = d?.points ?? const <Point>[];
        final ind = Indicateurs.de(pts);
        final choisi = pts.isEmpty ? null : (_choisi != null && _choisi! < pts.length ? _choisi! : pts.length - 1);
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          EnTete(context.tr('su_titre'), actions: [BoutonEcouter(texte: () => _resume(ind))]),
          SegmentedButton<int>(
            style: SegmentedButton.styleFrom(minimumSize: const Size(0, 50), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 7, label: Text(context.tr('su_7'))),
              ButtonSegment(value: 30, label: Text(context.tr('su_30'))),
              ButtonSegment(value: 90, label: Text(context.tr('su_90'))),
            ],
            selected: {_jours},
            onSelectionChanged: (s) => setState(() {
              _jours = s.first;
              _choisi = null;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in Grandeur.values)
              FilterChip(
                label: Text(_nom(context, g), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _series.contains(g) ? Wt.blanc : Wt.encre)),
                selected: _series.contains(g),
                showCheckmark: true,
                checkmarkColor: Wt.blanc,
                selectedColor: _couleurs[g],
                backgroundColor: Wt.blanc,
                side: BorderSide(color: _couleurs[g]!, width: 2),
                shape: const StadiumBorder(),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (v) => setState(() {
                  if (v) {
                    _series.add(g);
                  } else if (_series.length > 1) {
                    _series.remove(g);
                  }
                }),
              ),
          ]),
          const SizedBox(height: 12),
          if (snap.connectionState != ConnectionState.done && d == null)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (pts.isEmpty)
            Carte(child: Column(children: [const Emo('📈', taille: 32), const SizedBox(height: 8), Text(context.tr('su_vide'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.5))]))
          else ...[
            Carte(padding: const EdgeInsets.fromLTRB(6, 14, 14, 8), child: SizedBox(height: 240, child: _graphique(pts, choisi!))),
            const SizedBox(height: 10),
            Text('👆 ${context.tr('su_toucher')}', style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final actif = i == choisi;
                  final date = _dateDu(pts[i].t);
                  return ChoiceChip(
                    label: Text(_jours == 7 ? jourCourt(date) : dateCourte(date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    selected: actif,
                    showCheckmark: false,
                    selectedColor: Wt.violetClair,
                    backgroundColor: Wt.blanc,
                    side: BorderSide(color: actif ? Wt.violet : Wt.bordure, width: 2),
                    onSelected: (_) => setState(() => _choisi = i),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Carte(
              bordure: Wt.violetClair,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📅 ${dateLongue(_dateDu(pts[choisi!].t))} · ${pts[choisi!].v.tas.round()}/${pts[choisi!].v.tad.round()} mmHg', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
                const SizedBox(height: 10),
                QuatreValeurs(pts[choisi!].v),
                // Notes du médecin sur les mesures de ce jour.
                for (final n in d!.notes)
                  if (_jourDe(n, d!) == _jourDu(pts[choisi!].t)) ...[
                    const SizedBox(height: 10),
                    _bulleNote(context, n, d!),
                  ],
              ]),
            ),
            const SizedBox(height: 12),
            _carteIndicateurs(context, ind, d),
          ],
          if (d != null && d.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _carteNotes(context, d),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => preparerEtPartager(context, () => AppState.instance.partagerRapport(jours: _jours)),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(context.tr('su_partager')),
          ),
        ]);
      },
    ),
    );
  }

  /// Une note du médecin : sur quelle mesure, quand, et son texte.
  Widget _bulleNote(BuildContext context, NoteMedecin n, _Donnees d) {
    final m = d.mesures[n.mesureId];
    final quand = m?.date ?? n.mesureDate;
    final medecin = AppState.instance.medecinNom;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Wt.vertClair, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('🩺 ${medecin.isEmpty ? context.tr('no_medecin') : medecin}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.vertTexte)),
          if (_nouvelles.contains(n.mesureId))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Wt.vert, borderRadius: BorderRadius.circular(999)),
              child: Text(context.tr('tr_nouveau'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.blanc)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(n.texte, style: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          quand == null
              ? context.tr('no_le', {'d': dateCourte(n.date)})
              : context.tr('no_sur', {
                  'v': m == null ? '' : ' ${m.tas}/${m.tad}',
                  'd': '${dateCourte(quand)} · ${heureDe(quand)}',
                }),
          style: const TextStyle(fontSize: 14, color: Wt.gris, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  /// Toutes les notes de la période, de la plus récente à la plus ancienne.
  Widget _carteNotes(BuildContext context, _Donnees d) => Carte(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🩺 ${context.tr('no_titre', {'n': d.notes.length})}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.tr('no_aide'), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
          for (final n in d.notes.take(10)) ...[
            const SizedBox(height: 10),
            _bulleNote(context, n, d),
          ],
        ]),
      );

  String _resume(Indicateurs ind) {
    final m = ind.moyenne;
    if (m == null) return trL('su_vide');
    return trL('su_voix', {
      'n': ind.nbDansPlage,
      't': Voix.tension(m.tas.round(), m.tad.round()),
      'd': nombre(ind.deriveeParSemaine.abs()),
      'sens': trL(ind.deriveeParSemaine <= 0 ? 'su_baisse' : 'su_hausse'),
    });
  }

  Widget _carteIndicateurs(BuildContext context, Indicateurs ind, _Donnees? d) {
    final st = ind.statut!;
    final cs = couleursStatut(st);
    final der = ind.deriveeParSemaine;
    final lim = ind.limites;
    Widget ligne(String emoji, String titre, String technique, String sous, String valeur, Color couleur) => Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Wt.bordure))),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Emo(emoji, taille: 22, boite: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  TextSpan(text: ' $technique', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Wt.gris)),
                ])),
                Text(sous, style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(valeur, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleur)),
          ]),
        );
    final retour = lim.retourDurable == null ? context.tr('su_pas_encore') : dateCourte(_dateDu(lim.retourDurable!));
    return Carte(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
          Text('🎯 ${context.tr('su_statut')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: cs.fond, borderRadius: BorderRadius.circular(999)),
            child: Text(libelleStatut(context, st), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.texte)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(context.tr('su_statut_s', {'n': ind.nbDansPlage}), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ligne(der <= 0 ? '📉' : '📈', context.tr('su_d1'), context.tr('su_d1t'), '${context.tr('su_d1u')} · ${context.tr(der <= 0 ? 'su_baisse' : 'su_hausse')}',
            '${der > 0 ? '+' : ''}${nombre(der)}', der <= 0 ? Wt.vertTexte : Wt.rougeTexte),
        ligne('∑', context.tr('su_d2'), context.tr('su_d2t'), context.tr('su_d2u', {'c': cibleTas.round()}), nombre(ind.integraleTas, 0), const Color(0xFF7A2E00)),
        ligne('📏', context.tr('su_d3'), context.tr('su_d3t'), context.tr('su_d3u', {'r': retour}), '${lim.pourcentDansPlage.round()} %', Wt.violetFonce),
        if (d?.matin != null || d?.soir != null)
          ligne('🌗', context.tr('su_ms'), '', '☀️ ${_txt(d?.matin)} · 🌙 ${_txt(d?.soir)}', '', Wt.encre),
        TextButton(
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AideScreen(ouvert: 4))),
          child: Text('ℹ️ ${context.tr('su_aide')}'),
        ),
      ]),
    );
  }

  String _txt(Grandeurs? g) => g == null ? '—' : '${g.tas.round()}/${g.tad.round()}';

  Widget _graphique(List<Point> pts, int choisi) {
    final xs = pts.map((p) => p.t);
    final minX = xs.reduce((a, b) => a < b ? a : b), maxX = xs.reduce((a, b) => a > b ? a : b);
    LineChartBarData barre(Grandeur g) => LineChartBarData(
          spots: [for (final p in pts) FlSpot(p.t, p.v.de(g))],
          color: _couleurs[g],
          barWidth: 3,
          isCurved: false,
          dashArray: _tirets[g],
          dotData: FlDotData(
            show: pts.length <= 31,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 4.5, color: Wt.blanc, strokeWidth: 3, strokeColor: _couleurs[g]!),
          ),
        );
    return LineChart(LineChartData(
      minX: minX == maxX ? minX - 1 : minX,
      maxX: minX == maxX ? maxX + 1 : maxX,
      minY: 40,
      maxY: 180,
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
        HorizontalRangeAnnotation(y1: plages[Grandeur.tas]!.min, y2: plages[Grandeur.tas]!.max, color: Wt.cibleTas),
        HorizontalRangeAnnotation(y1: plages[Grandeur.tad]!.min, y2: plages[Grandeur.tad]!.max, color: Wt.cibleTad),
      ]),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (_) => FlLine(color: Color(0xFFEFEDE7), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(verticalLines: [VerticalLine(x: pts[choisi].t, color: Wt.encre, strokeWidth: 1.5, dashArray: [4, 4])]),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 20,
            getTitlesWidget: (v, meta) => SideTitleWidget(axisSide: meta.axisSide, child: Text(v.toInt().toString(), style: const TextStyle(fontSize: 12, color: Wt.gris, fontWeight: FontWeight.w700))),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: _jours == 7 ? 1 : (_jours == 30 ? 7 : 14),
            getTitlesWidget: (v, meta) {
              final d = _dateDu(v);
              final txt = _jours == 7 ? jourCourt(d) : '${d.day}/${d.month}';
              return SideTitleWidget(axisSide: meta.axisSide, child: Text(txt, style: const TextStyle(fontSize: 12, color: Wt.gris, fontWeight: FontWeight.w700)));
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchCallback: (event, reponse) {
          final spots = reponse?.lineBarSpots;
          if (event is FlTapUpEvent && spots != null && spots.isNotEmpty) {
            setState(() => _choisi = spots.first.spotIndex);
          }
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Wt.encre,
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(s.y.round().toString(), const TextStyle(color: Wt.blanc, fontWeight: FontWeight.w800, fontSize: 15))).toList(),
        ),
      ),
      lineBarsData: [for (final g in Grandeur.values) if (_series.contains(g)) barre(g)],
    ));
  }
}
