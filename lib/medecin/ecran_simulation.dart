import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/controle.dart';
import '../core/modele_edo.dart';
import '../l10n.dart';
import '../theme.dart';
import 'calculs.dart';
import 'depot.dart';
import 'simulation_calc.dart';
import 'ui_medecin.dart';

/// Simulation de dose avec le modèle d'équations du client (aide à la
/// décision du médecin, jamais une prescription automatique).
/// Renvoie la dose choisie (mg) au dossier, ou null.
class EcranSimulation extends StatefulWidget {
  final String nom;
  final Dossier dossier;
  const EcranSimulation({super.key, required this.nom, required this.dossier});
  @override
  State<EcranSimulation> createState() => _EcranSimulationState();
}

class _EcranSimulationState extends State<EcranSimulation> {
  late double _ps0;
  late double _pd0;
  late double _dose;
  late final double? _pid;
  late final int _joursPid;
  late final String _origine;

  @override
  void initState() {
    super.initState();
    final d = widget.dossier;
    final debut7 = jourDecale(DateTime.now(), -6);
    final m = moyenne(pointsJournaliers(d.mesures, debut7));
    final valides = filtrer(d.mesures, DateTime.fromMillisecondsSinceEpoch(0), sansCrises: true);
    if (m != null) {
      _ps0 = m.tas.roundToDouble();
      _pd0 = m.tad.roundToDouble();
      _origine = 'md_sim_origine_moy';
    } else if (valides.isNotEmpty) {
      _ps0 = valides.last.tas.toDouble();
      _pd0 = valides.last.tad.toDouble();
      _origine = 'md_sim_origine_der';
    } else {
      _ps0 = 160;
      _pd0 = 100;
      _origine = 'md_sim_origine_modele';
    }
    _ps0 = _ps0.clamp(100, 220).toDouble();
    _pd0 = _pd0.clamp(60, 130).toDouble();
    _dose = ((d.plan?.doseMg ?? 10) / 2.5).round() * 2.5;
    _dose = _dose.clamp(0, 20).toDouble();
    final erreurs = erreursJournalieres(d.mesures, debut7);
    _joursPid = erreurs.length;
    _pid = erreurs.isEmpty ? null : CorrecteurDose(doseBase: d.plan?.doseMg ?? 5).proposer(erreurs);
  }

  @override
  Widget build(BuildContext context) {
    context.enAnglais;
    final r = evaluerDose(_ps0, _pd0, _dose);
    final dme = doseMinimaleEfficace(_ps0, _pd0);
    return Scaffold(
      backgroundColor: Wt.fond,
      appBar: BarreHaut(onDeconnexion: () async {
        await Depot.instance.deconnecter();
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Centre(
          max: 1400,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(tooltip: context.tr('retour'), onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('md_sim_titre'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  Text('${widget.nom} · ${context.tr(_origine)}', style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            CarteM(
              fond: Wt.jaune,
              bordure: Wt.jaune,
              child: Text('⚠️ ${context.tr('md_sim_avert')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Wt.jauneTexte, height: 1.4)),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, c) {
              final large = c.maxWidth >= 1100;
              final gauche = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _reglages(context),
                const SizedBox(height: 14),
                _correcteur(context),
                const SizedBox(height: 14),
                _modele(context),
              ]);
              final droite = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GrilleKpi(largeurMin: 170, [
                  Kpi(titre: '⬇️ ${context.tr('md_sim_min')}', valeur: '${r.tasMin.round()} mmHg', sous: context.tr('md_sim_a', {'h': nombre(r.tMin)})),
                  Kpi(
                    titre: '⏱️ ${context.tr('md_sim_t130')}',
                    valeur: r.t130 == null ? '—' : '${nombre(r.t130!)} h',
                    sous: context.tr('md_sim_t130_s', {'h': nombre(objectifHeures, 0)}),
                    fond: r.efficace ? Wt.vertClair : Wt.blanc,
                    couleur: r.efficace ? Wt.vertTexte : Wt.encre,
                  ),
                  Kpi(titre: '🕐 ${context.tr('md_sim_24')}', valeur: '${r.tas24.round()} mmHg', sous: context.tr('md_sim_24_s')),
                  Kpi(
                    titre: '🛡️ ${context.tr('md_sim_securite')}',
                    valeur: r.sur ? '✓ ${context.tr('md_sim_sur')}' : '⚠ ${context.tr('md_sim_risque')}',
                    sous: context.tr('md_sim_securite_s', {'s': seuilHypotension.round()}),
                    fond: r.sur ? Wt.vertClair : Wt.rougeClair,
                    couleur: r.sur ? Wt.vertTexte : Wt.rougeTexte,
                  ),
                ]),
                const SizedBox(height: 14),
                _graphique(context),
                const SizedBox(height: 14),
                _doseReponse(context, dme),
              ]);
              return large
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 400, child: gauche),
                      const SizedBox(width: 18),
                      Expanded(child: droite),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [droite, const SizedBox(height: 14), gauche]);
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _curseur(String titre, double v, double min, double max, int divisions, String unite, ValueChanged<double> changer) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            Text('${nombre(v, v == v.roundToDouble() ? 0 : 1)} $unite', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
          ]),
          Slider(value: v, min: min, max: max, divisions: divisions, label: nombre(v, v == v.roundToDouble() ? 0 : 1), onChanged: changer),
        ],
      );

  Widget _reglages(BuildContext context) => CarteM(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Etiquette('🎛️ ${context.tr('md_sim_reglages')}'),
          _curseur(context.tr('md_sim_dose'), _dose, 0, 20, 8, 'mg', (v) => setState(() => _dose = v)),
          _curseur(context.tr('md_sim_ps0'), _ps0, 100, 220, 120, 'mmHg', (v) => setState(() => _ps0 = v)),
          _curseur(context.tr('md_sim_pd0'), _pd0, 60, 130, 70, 'mmHg', (v) => setState(() => _pd0 = v)),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_dose),
            icon: const Icon(Icons.check),
            label: Text(context.tr('md_sim_reporter', {'d': nombre(_dose)})),
          ),
          const SizedBox(height: 6),
          Text(context.tr('md_sim_hypothese'), style: const TextStyle(fontSize: 12, color: Wt.gris, height: 1.4)),
        ]),
      );

  Widget _correcteur(BuildContext context) => CarteM(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Etiquette('🧮 ${context.tr('md_sim_pid')}'),
          if (_pid == null)
            Text(context.tr('md_sim_pid_vide'), style: const TextStyle(color: Wt.gris))
          else ...[
            Text('${nombre(_pid!)} mg', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
            Text(context.tr('md_sim_pid_s', {'n': _joursPid}), style: const TextStyle(fontSize: 14, color: Wt.gris, height: 1.4)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => setState(() => _dose = _pid!.clamp(0, 20).toDouble()), child: Text(context.tr('md_sim_pid_essayer'))),
          ],
          const SizedBox(height: 8),
          Text(context.tr('md_sim_pid_aide'), style: const TextStyle(fontSize: 12, color: Wt.gris, height: 1.4)),
        ]),
      );

  Widget _modele(BuildContext context) {
    final m = modelePour(_ps0, _pd0, _dose);
    final k = m.constantes;
    final ecart = ecartRk4(_ps0, _pd0, _dose);
    String n(double v) => nombre(v, 2);
    String terme(double c, String exp) => '${c < 0 ? '−' : '+'} ${n(c.abs())}·e^(−$exp·t)';
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.6, fontWeight: FontWeight.w600);
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Etiquette('📐 ${context.tr('md_sim_modele')}'),
        const Text('dX/dt = A·X,  X = [Ps − 120, Pd − 80, C]ᵀ', style: mono),
        const Text('A = [ −0,4   0    −1,5 ]\n    [  0   −0,2  −0,8 ]\n    [  0    0    −0,5 ]', style: mono),
        const SizedBox(height: 8),
        Text('Ps(t) = 120 ${terme(k.k1, '0,4')} ${terme(k.b1, '0,5')}', style: mono),
        Text('Pd(t) = 80 ${terme(k.k2, '0,2')} ${terme(k.b2, '0,5')}', style: mono),
        const Text('Pp = Ps − Pd   ·   Pm = Pd + ⅓·Pp', style: mono),
        const SizedBox(height: 8),
        Text(context.tr('md_sim_rk4', {'e': ecart < 0.001 ? '< 0,001' : nombre(ecart, 3)}), style: const TextStyle(fontSize: 13, color: Wt.vertTexte, fontWeight: FontWeight.w700)),
        Text(context.tr('md_sim_unites'), style: const TextStyle(fontSize: 12, color: Wt.gris, height: 1.4)),
      ]),
    );
  }

  Widget _graphique(BuildContext context) {
    LineChartBarData barre(Grandeur g, double dose, {Color? couleur, List<int>? tirets, double largeur = 2.5}) => LineChartBarData(
          spots: [for (final (t, v) in courbe(_ps0, _pd0, dose, g)) FlSpot(t, v)],
          color: couleur ?? couleursSeries[g],
          barWidth: largeur,
          dashArray: tirets ?? tiretsSeries[g],
          dotData: FlDotData(show: false),
        );
    return CarteM(
      padding: const EdgeInsets.fromLTRB(8, 16, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Wrap(spacing: 14, runSpacing: 6, children: [
            for (final g in Grandeur.values) _legende(couleursSeries[g]!, nomGrandeur(g)),
            _legende(const Color(0xFFB8BEC8), context.tr('md_sim_sans')),
          ]),
        ),
        SizedBox(
          height: 320,
          child: LineChart(LineChartData(
            minX: 0,
            maxX: 24,
            minY: 20,
            maxY: (((_ps0 + 10) / 20).ceil() * 20).toDouble().clamp(160, 240).toDouble(),
            rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(y1: plages[Grandeur.tas]!.min, y2: plages[Grandeur.tas]!.max, color: Wt.cibleTas),
              HorizontalRangeAnnotation(y1: plages[Grandeur.tad]!.min, y2: plages[Grandeur.tad]!.max, color: Wt.cibleTad),
            ]),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: seuilHypotension, color: Wt.rouge, strokeWidth: 1.2, dashArray: [4, 4]),
            ]),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFEFEDE7), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 20,
                  getTitlesWidget: (v, meta) => SideTitleWidget(axisSide: meta.axisSide, child: Text(v.toInt().toString(), style: const TextStyle(fontSize: 12, color: Wt.gris, fontWeight: FontWeight.w700))),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 4,
                  getTitlesWidget: (v, meta) => SideTitleWidget(axisSide: meta.axisSide, child: Text('${v.toInt()} h', style: const TextStyle(fontSize: 12, color: Wt.gris, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Wt.encre,
                getTooltipItems: (spots) => [
                  for (final s in spots) LineTooltipItem(s.y.round().toString(), const TextStyle(color: Wt.blanc, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
            lineBarsData: [
              barre(Grandeur.tas, 0, couleur: const Color(0xFFB8BEC8), tirets: [5, 5], largeur: 2),
              for (final g in Grandeur.values) barre(g, _dose),
            ],
          )),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 6),
          child: Text(context.tr('md_sim_graph_aide', {'s': seuilHypotension.round()}), style: const TextStyle(fontSize: 13, color: Wt.gris, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _legende(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 18, height: 4, color: c),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Wt.gris)),
      ]);

  Widget _doseReponse(BuildContext context, double? dme) {
    final lignes = courbeDoseReponse(_ps0, _pd0);
    const st = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.gris);
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Etiquette('📊 ${context.tr('md_sim_dr')}'),
        Text(
          dme == null ? context.tr('md_sim_dme_aucune') : context.tr('md_sim_dme', {'d': nombre(dme)}),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Wt.vertTexte),
        ),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FlexColumnWidth(0.9)},
          children: [
            TableRow(children: [
              Text(context.tr('md_sim_c_dose'), style: st),
              Text(context.tr('md_sim_c_min'), style: st),
              Text(context.tr('md_sim_c_t130'), style: st),
              Text(context.tr('md_sim_c_avis'), style: st),
            ]),
            for (final l in lignes)
              TableRow(
                decoration: BoxDecoration(
                  color: l.dose == _dose ? Wt.violetClair : (l.dose == dme ? Wt.vertClair : null),
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _cell(InkWell(onTap: () => setState(() => _dose = l.dose), child: Text('${nombre(l.dose)} mg', style: const TextStyle(fontWeight: FontWeight.w800, color: Wt.violetFonce)))),
                  _cell(Text('${l.tasMin.round()} mmHg')),
                  _cell(Text(l.t130 == null ? '—' : '${nombre(l.t130!)} h')),
                  _cell(Text(
                    !l.sur ? '⚠ ${context.tr('md_sim_risque')}' : (l.efficace ? '✓ ${context.tr('md_sim_efficace')}' : '• ${context.tr('md_sim_lente')}'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: !l.sur ? Wt.rougeTexte : (l.efficace ? Wt.vertTexte : Wt.gris)),
                  )),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(context.tr('md_sim_dr_aide', {'h': nombre(objectifHeures, 0), 's': seuilHypotension.round()}), style: const TextStyle(fontSize: 12, color: Wt.gris, height: 1.4)),
      ]),
    );
  }

  Widget _cell(Widget w) => Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6), child: w);
}
