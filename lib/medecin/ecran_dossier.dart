import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/classification.dart';
import '../core/controle.dart';
import '../core/risque.dart';
import '../l10n.dart';
import '../theme.dart';
import '../ui/visite_guidee.dart';
import 'calculs.dart';
import 'depot.dart';
import 'ecran_simulation.dart';
import 'rapport_pdf.dart';
import 'ui_medecin.dart';
import 'visite_web.dart';

/// Dossier d'une patiente : graphique des 4 grandeurs, indicateurs du client,
/// détail et annotation d'une mesure, avant / après un changement de dose,
/// plan de traitement (réservé au médecin) et messages.
class EcranDossier extends StatefulWidget {
  final String uid;
  final String nom;
  const EcranDossier({super.key, required this.uid, required this.nom});
  @override
  State<EcranDossier> createState() => _EcranDossierState();
}

class _EcranDossierState extends State<EcranDossier> {
  late Future<Dossier> _futur;
  int _jours = 28;
  Moment _moment = Moment.tous;
  final _series = <Grandeur>{Grandeur.tas, Grandeur.tad};
  String? _choisie; // id de la mesure sélectionnée

  final _note = TextEditingController();
  final _message = TextEditingController();
  final _medicament = TextEditingController();
  final _dose = TextEditingController();
  TimeOfDay _heure = const TimeOfDay(hour: 20, minute: 0);
  bool _planInitialise = false;
  bool _envoi = false;

  // Visite guidée du dossier (au premier dossier ouvert).
  bool _visiteTentee = false;
  final _cleEntete = GlobalKey();
  final _cleControles = GlobalKey();
  final _cleKpi = GlobalKey();
  final _cleGraph = GlobalKey();
  final _cleDetail = GlobalKey();
  final _clePlan = GlobalKey();
  final _cleMessages = GlobalKey();

  Future<void> _visite() async {
    await lancerVisite(context, [
      const EtapeVisite(emoji: '📂', titre: 'vgd_1_t', texte: 'vgd_1'),
      EtapeVisite.sur(_cleControles, emoji: '🗓️', titre: 'vgd_2_t', texte: 'vgd_2'),
      EtapeVisite.sur(_cleKpi, emoji: '🎯', titre: 'vgd_3_t', texte: 'vgd_3'),
      EtapeVisite.sur(_cleGraph, emoji: '📈', titre: 'vgd_4_t', texte: 'vgd_4'),
      EtapeVisite.sur(_cleDetail, emoji: '📝', titre: 'vgd_5_t', texte: 'vgd_5'),
      EtapeVisite.sur(_clePlan, emoji: '💊', titre: 'vgd_6_t', texte: 'vgd_6'),
      EtapeVisite.sur(_cleEntete, emoji: '🧪', titre: 'vgd_7_t', texte: 'vgd_7'),
      EtapeVisite.sur(_cleMessages, emoji: '💬', titre: 'vgd_8_t', texte: 'vgd_8'),
      const EtapeVisite(emoji: '✅', titre: 'vgd_9_t', texte: 'vgd_9'),
    ]);
    marquerVisiteVue('dossier');
  }

  static const _medicaments = ['Amlodipine', 'Périndopril', 'Ramipril', 'Losartan', 'Hydrochlorothiazide', 'Bisoprolol'];

  // Mise à jour automatique : chaque synchronisation de la patiente.
  Rafraichisseur? _direct;
  Dossier? _dernier;
  DateTime? _majLe;

  @override
  void initState() {
    super.initState();
    _futur = _charger();
    _direct = Rafraichisseur(Depot.instance.changementsDossier(widget.uid), () => _recharger(silencieux: true));
  }

  Future<Dossier> _charger({bool silencieux = false}) async {
    try {
      final d = await Depot.instance.dossier(widget.uid);
      // Dossier ouvert = messages de la patiente lus (aussi ceux qui arrivent
      // pendant que le médecin le consulte).
      if (d.messages.any((m) => m.deMoi && !m.lu)) {
        Depot.instance.marquerLus(widget.uid, d.messages).catchError((_) {});
      }
      _dernier = d;
      _majLe = DateTime.now();
      return d;
    } catch (_) {
      if (silencieux && _dernier != null) return _dernier!;
      rethrow;
    }
  }

  void _recharger({bool silencieux = false}) {
    if (!mounted) return;
    setState(() => _futur = _charger(silencieux: silencieux));
  }

  DateTime get _debut => jourDecale(DateTime.now(), -(_jours - 1));

  @override
  void dispose() {
    _direct?.arreter();
    _note.dispose();
    _message.dispose();
    _medicament.dispose();
    _dose.dispose();
    super.dispose();
  }

  void _initPlan(Dossier d) {
    if (_planInitialise) return;
    _planInitialise = true;
    final p = d.plan;
    final declare = d.profil.medicaments.isNotEmpty ? d.profil.medicaments.first : null;
    _medicament.text = p?.medicament ?? declare?.nom ?? '';
    _dose.text = p != null ? nombre(p.doseMg) : '';
    if (p != null) _heure = TimeOfDay(hour: p.heure, minute: p.minute);
  }

  double? get _doseSaisie => double.tryParse(_dose.text.replaceAll(',', '.').trim());

  @override
  Widget build(BuildContext context) {
    context.enAnglais;
    return Scaffold(
      backgroundColor: Wt.fond,
      appBar: BarreHaut(
        onVisite: _visite,
        onDeconnexion: () async {
          await Depot.instance.deconnecter();
          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      body: FutureBuilder<Dossier>(
        future: _futur,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('⚠ ${context.tr('md_err_chargement')}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('${snap.error}', style: const TextStyle(fontSize: 13, color: Wt.gris)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _recharger, child: Text(context.tr('md_reessayer'))),
              ]),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          _initPlan(d);
          if (!_visiteTentee) {
            _visiteTentee = true;
            if (!visiteVue('dossier')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _visite();
              });
            }
          }
          return LayoutBuilder(builder: (context, c) {
            final large = c.maxWidth >= 1150;
            final principal = <Widget>[
              KeyedSubtree(key: _cleEntete, child: _entete(context, d)),
              const SizedBox(height: 16),
              KeyedSubtree(key: _cleControles, child: _controles(context)),
              const SizedBox(height: 14),
              KeyedSubtree(key: _cleKpi, child: _indicateurs(context, d)),
              const SizedBox(height: 14),
              KeyedSubtree(key: _cleGraph, child: _graphique(context, d)),
              const SizedBox(height: 14),
              _prises(context, d),
            ];
            final cote = <Widget>[
              KeyedSubtree(key: _cleDetail, child: _detail(context, d)),
              const SizedBox(height: 14),
              _avantApres(context, d),
              const SizedBox(height: 14),
              KeyedSubtree(key: _clePlan, child: _plan(context, d)),
              const SizedBox(height: 14),
              KeyedSubtree(key: _cleMessages, child: _messages(context, d)),
            ];
            return ListView(padding: const EdgeInsets.all(24), children: [
              Centre(
                max: 1500,
                child: large
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: principal)),
                        const SizedBox(width: 18),
                        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cote)),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...principal, const SizedBox(height: 14), ...cote]),
              ),
            ]);
          });
        },
      ),
    );
  }

  // --- En-tête ----------------------------------------------------------------------
  Widget _entete(BuildContext context, Dossier d) {
    final p = d.profil;
    final risque = calculerRisque(p);
    final initiales = '${p.prenom.isEmpty ? '' : p.prenom[0]}${p.nom.isEmpty ? '' : p.nom[0]}'.toUpperCase();
    final infos = <String>[
      if (p.age != null) context.tr('pr_age', {'a': p.age}),
      context.tr(p.femme ? 'md_femme' : 'md_homme'),
      if (p.imc != null) 'IMC ${nombre(p.imc!)}',
      if (p.grossesseActive) context.tr('md_grossesse', {'s': p.semainesGrossesse ?? '?'}),
      if (p.avc) context.tr('md_avc'),
      ...p.maladies.map(nomMaladie),
      if (p.autreMaladie.trim().isNotEmpty) p.autreMaladie.trim(),
    ];
    return CarteM(
      child: Wrap(spacing: 16, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: context.tr('retour'), onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: 4),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Wt.violetClair, shape: BoxShape.circle),
            child: Text(initiales.isEmpty ? '?' : initiales, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
          ),
          const SizedBox(width: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.nom, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(infos.join(' · '), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Pastille('🛡️ ${risque.libelle}', fond: Wt.violetClair, couleur: Wt.violetFonce, taille: 13),
                Pastille(
                  '☁️ ${d.derniereSynchro == null ? context.tr('md_jamais_sync') : context.tr('md_sync', {'t': ilYa(d.derniereSynchro!)})}',
                  fond: Wt.fond,
                  couleur: Wt.gris,
                  taille: 13,
                ),
              ]),
            ]),
          ),
        ]),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: () => _simuler(d), icon: const Icon(Icons.science_outlined), label: Text(context.tr('md_simuler'))),
          OutlinedButton.icon(onPressed: () => _rapport(d), icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(context.tr('md_rapport'))),
          OutlinedButton.icon(onPressed: _recharger, icon: const Icon(Icons.refresh), label: Text(context.tr('md_actualiser'))),
          Padding(padding: const EdgeInsets.only(top: 10), child: PastilleDirect(_majLe)),
        ]),
      ]),
    );
  }

  // --- Période, moment, courbes ---------------------------------------------------------
  Widget _controles(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 7, label: Text(context.tr('md_p7'))),
            ButtonSegment(value: 28, label: Text(context.tr('md_p28'))),
            ButtonSegment(value: 90, label: Text(context.tr('md_p90'))),
          ],
          selected: {_jours},
          onSelectionChanged: (s) => setState(() => _jours = s.first),
        ),
        SegmentedButton<Moment>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: Moment.tous, label: Text(context.tr('md_m_tous'))),
            ButtonSegment(value: Moment.matin, label: Text('☀️ ${context.tr('md_m_matin')}')),
            ButtonSegment(value: Moment.soir, label: Text('🌙 ${context.tr('md_m_soir')}')),
          ],
          selected: {_moment},
          onSelectionChanged: (s) => setState(() => _moment = s.first),
        ),
        for (final g in Grandeur.values)
          FilterChip(
            label: Text(nomGrandeur(g), style: TextStyle(fontWeight: FontWeight.w800, color: _series.contains(g) ? Wt.blanc : Wt.encre)),
            selected: _series.contains(g),
            checkmarkColor: Wt.blanc,
            selectedColor: couleursSeries[g],
            backgroundColor: Wt.blanc,
            side: BorderSide(color: couleursSeries[g]!, width: 2),
            shape: const StadiumBorder(),
            onSelected: (v) => setState(() {
              if (v) {
                _series.add(g);
              } else if (_series.length > 1) {
                _series.remove(g);
              }
            }),
          ),
      ]);

  // --- Indicateurs du client -----------------------------------------------------------
  Widget _indicateurs(BuildContext context, Dossier d) {
    final pts = pointsJournaliers(d.mesures, _debut, moment: _moment);
    final ind = Indicateurs.de(pts);
    final obs = observance(d.prises, _debut, DateTime.now());
    final nb = filtrer(d.mesures, _debut, moment: _moment).length;
    final st = ind.statut;
    final cs = st == null ? const Couleurs2(Wt.blanc, Wt.encre) : couleursStatutM(st);
    final lim = ind.limites;
    final retour = lim.retourDurable == null ? context.tr('su_pas_encore') : dateCourte(jourDecale(_debut, lim.retourDurable!.round()));
    return GrilleKpi(largeurMin: 175, [
      Kpi(
        titre: '🎯 ${context.tr('md_k_statut')}',
        valeur: st == null ? '—' : libelleStatutM(st),
        sous: st == null ? context.tr('md_pas_de_donnees') : context.tr('md_k_statut_s', {'n': ind.nbDansPlage}),
        fond: cs.fond,
        couleur: cs.texte,
      ),
      Kpi(
        titre: '${ind.deriveeParSemaine <= 0 ? '📉' : '📈'} ${context.tr('md_k_derivee')}',
        valeur: pts.length < 2 ? '—' : signe(ind.deriveeParSemaine),
        sous: context.tr('md_k_derivee_s'),
        couleur: ind.deriveeParSemaine > 0.5 ? Wt.rougeTexte : (ind.deriveeParSemaine < -0.5 ? Wt.vertTexte : Wt.encre),
      ),
      Kpi(titre: '∑ ${context.tr('md_k_integrale')}', valeur: pts.length < 2 ? '—' : nombre(ind.integraleTas, 0), sous: context.tr('md_k_integrale_s')),
      Kpi(titre: '📏 ${context.tr('md_k_limites')}', valeur: pts.isEmpty ? '—' : '${lim.pourcentDansPlage.round()} %', sous: context.tr('md_k_limites_s', {'r': retour})),
      Kpi(
        titre: '💊 ${context.tr('md_k_obs')}',
        valeur: obs == null ? '—' : '${(obs.taux * 100).round()} %',
        sous: obs == null ? context.tr('md_k_obs_aucune') : context.tr('md_k_obs_s', {'n': obs.prises, 'j': obs.jours}),
      ),
      Kpi(titre: '🔢 ${context.tr('md_k_nb')}', valeur: '$nb', sous: context.tr('md_k_nb_s')),
    ]);
  }

  // --- Graphique -------------------------------------------------------------------
  Widget _graphique(BuildContext context, Dossier d) {
    final debut = _debut;
    final mes = filtrer(d.mesures, debut, moment: _moment);
    if (mes.isEmpty) {
      return CarteM(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const Text('📈', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          Text(context.tr('md_graph_vide'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        ]),
      );
    }
    final xs = [for (final m in mes) joursDepuis(debut, m.date)];
    final choisie = mes.indexWhere((m) => m.id == _choisie);
    var maxY = 180.0;
    for (final m in mes) {
      if (m.tas + 10 > maxY) maxY = (m.tas + 10).toDouble();
    }
    final changements = [
      for (final p in d.historique)
        if (!p.date.isBefore(debut)) joursDepuis(debut, p.date),
    ];
    LineChartBarData barre(Grandeur g) => LineChartBarData(
          spots: [for (var i = 0; i < mes.length; i++) FlSpot(xs[i], mes[i].g.de(g))],
          color: couleursSeries[g],
          barWidth: 2.5,
          dashArray: tiretsSeries[g],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, i) {
              final m = mes[i];
              final c = m.crise ? Wt.crise : (m.symptomes.isNotEmpty ? Wt.evSymptome : couleursSeries[g]!);
              final special = m.crise || m.symptomes.isNotEmpty;
              return FlDotCirclePainter(
                radius: i == choisie ? 7 : (special ? 5.5 : 3.5),
                color: special ? c : Wt.blanc,
                strokeWidth: i == choisie ? 3.5 : 2,
                strokeColor: i == choisie ? Wt.encre : c,
              );
            },
          ),
        );
    final pas = _jours == 7 ? 1.0 : (_jours == 28 ? 7.0 : 14.0);
    return CarteM(
      padding: const EdgeInsets.fromLTRB(8, 16, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Wrap(spacing: 14, runSpacing: 6, children: [
            _legende(Wt.crise, context.tr('md_ev_crise')),
            _legende(Wt.evSymptome, context.tr('md_ev_symptome')),
            _legende(Wt.violet, context.tr('md_ev_traitement'), ligne: true),
            _legende(Wt.cibleTas, context.tr('md_ev_cible'), carre: true),
          ]),
        ),
        SizedBox(
          height: 340,
          child: LineChart(LineChartData(
            minX: 0,
            maxX: _jours.toDouble(),
            minY: 40,
            maxY: ((maxY / 20).ceil() * 20).toDouble(),
            rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(y1: plages[Grandeur.tas]!.min, y2: plages[Grandeur.tas]!.max, color: Wt.cibleTas),
              HorizontalRangeAnnotation(y1: plages[Grandeur.tad]!.min, y2: plages[Grandeur.tad]!.max, color: Wt.cibleTad),
            ]),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFEFEDE7), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(verticalLines: [
              for (final x in changements) VerticalLine(x: x, color: Wt.violet, strokeWidth: 2, dashArray: [6, 4]),
              if (choisie >= 0) VerticalLine(x: xs[choisie], color: Wt.encre, strokeWidth: 1.2, dashArray: [3, 3]),
            ]),
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
                  interval: pas,
                  getTitlesWidget: (v, meta) {
                    final jour = jourDecale(debut, v.round());
                    final txt = _jours == 7 ? jourCourt(jour) : dateCourte(jour);
                    return SideTitleWidget(axisSide: meta.axisSide, child: Text(txt, style: const TextStyle(fontSize: 12, color: Wt.gris, fontWeight: FontWeight.w700)));
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchCallback: (event, reponse) {
                final spots = reponse?.lineBarSpots;
                if (event is FlTapUpEvent && spots != null && spots.isNotEmpty) {
                  setState(() {
                    _choisie = mes[spots.first.spotIndex].id;
                    _note.text = d.notes[_choisie]?.texte ?? '';
                  });
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Wt.encre,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.y.round()}${s == spots.first ? '\n${dateHeure(mes[s.spotIndex].date)}' : ''}',
                      const TextStyle(color: Wt.blanc, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                ],
              ),
            ),
            lineBarsData: [for (final g in Grandeur.values) if (_series.contains(g)) barre(g)],
          )),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 6),
          child: Text('👆 ${context.tr('md_graph_aide')}', style: const TextStyle(fontSize: 13, color: Wt.gris, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _legende(Color c, String t, {bool ligne = false, bool carre = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: ligne ? 18 : 12,
          height: ligne ? 3 : 12,
          decoration: BoxDecoration(color: c, shape: (ligne || carre) ? BoxShape.rectangle : BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Wt.gris)),
      ]);

  // --- Prises des 14 derniers jours ----------------------------------------------------
  Widget _prises(BuildContext context, Dossier d) {
    final auj = minuit(DateTime.now());
    final parJour = {for (final p in d.prises) minuit(p.jour): p};
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Etiquette('💊 ${context.tr('md_prises_titre')}'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 13; i >= 0; i--)
            Builder(builder: (context) {
              final jour = jourDecale(auj, -i);
              final p = parJour[jour];
              final (txt, fond, coul) = switch (p?.statut) {
                'pris' => ('✓', Wt.vertClair, Wt.vertTexte),
                'oubli' => ('✗', Wt.rougeClair, Wt.rougeTexte),
                _ => ('–', Wt.fond, Wt.gris),
              };
              return Tooltip(
                message: '${dateCourte(jour)} · ${p == null ? context.tr('md_prise_rien') : (p.prise ? '${context.tr('md_prise_ok')}${p.heure != null ? ' ${heureDe(p.heure!)}' : ''}' : context.tr('md_prise_oubli'))}',
                child: Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(jourCourt(jour), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: coul)),
                    Text(txt, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: coul)),
                  ]),
                ),
              );
            }),
        ]),
      ]),
    );
  }

  // --- Détail d'une mesure + note ------------------------------------------------------
  Widget _detail(BuildContext context, Dossier d) {
    final valides = filtrer(d.mesures, DateTime.fromMillisecondsSinceEpoch(0));
    MesureM? m;
    for (final x in valides) {
      if (x.id == _choisie) m = x;
    }
    m ??= valides.isEmpty ? null : valides.last;
    if (m == null) {
      return CarteM(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Etiquette('📅 ${context.tr('md_detail')}'), Text(context.tr('md_aucune_mesure'))]));
    }
    final mesure = m;
    final note = d.notes[mesure.id];
    if (_choisie == null && _note.text.isEmpty && note != null) _note.text = note.texte;
    return CarteM(
      bordure: Wt.violetClair,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Etiquette('📅 ${context.tr('md_detail')}'),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(dateLongue(mesure.date), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(heureDe(mesure.date), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700)),
          PastilleGrade(mesure.grade),
          if (mesure.crise) Pastille('🚨 ${context.tr('md_ev_crise')}', fond: Wt.crise, couleur: Wt.blanc, taille: 13),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (final g in Grandeur.values)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: g == Grandeur.pp ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: dansLaPlage(g, mesure.g.de(g)) ? Wt.vertClair : Wt.rougeClair,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text(nomGrandeur(g), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.gris)),
                  Text(mesure.g.de(g).round().toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('${signe(erreur(g, mesure.g.de(g)), 0)} ${context.tr('md_vs_cible')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Wt.gris)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          [
            if (mesure.pouls > 0) '❤️ ${mesure.pouls} bpm',
            '🔔 ${trL('niveau_${mesure.niveau.clamp(1, 4)}')}',
            mesure.symptomes.isEmpty ? context.tr('md_aucun_symptome') : '🤒 ${mesure.symptomes.map((s) => trL('sym_$s')).join(', ')}',
          ].join(' · '),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 14),
        Text(context.tr('md_annoter'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(hintText: context.tr('md_annoter_ex')),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('✓ ${context.tr('md_note_du', {'d': dateHeure(note.date)})}', style: const TextStyle(fontSize: 13, color: Wt.vertTexte, fontWeight: FontWeight.w700)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _envoi
                ? null
                : () async {
                    final t = _note.text.trim();
                    if (t.isEmpty) return;
                    setState(() => _envoi = true);
                    try {
                      await Depot.instance.annoter(
                        widget.uid,
                        mesure,
                        t,
                        trL('md_msg_note', {'d': dateHeure(mesure.date), 'v': '${mesure.tas}/${mesure.tad}', 'n': t}),
                      );
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('md_note_ok'))));
                      _choisie = mesure.id;
                      _recharger();
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠ $e')));
                    } finally {
                      if (mounted) setState(() => _envoi = false);
                    }
                  },
            child: Text(context.tr('md_enreg_note')),
          ),
        ),
      ]),
    );
  }

  // --- Avant / après le dernier changement de traitement -------------------------------
  Widget _avantApres(BuildContext context, Dossier d) {
    if (d.historique.isEmpty) {
      return CarteM(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Etiquette('⚖️ ${context.tr('md_avap')}'),
          Text(context.tr('md_avap_vide'), style: const TextStyle(color: Wt.gris)),
        ]),
      );
    }
    final dernier = d.historique.first;
    final r = avantApres(d.mesures, dernier.date);
    String v(Grandeurs? x, Grandeur g) => x == null ? '—' : x.de(g).round().toString();
    String e(Grandeur g) => (r.avant == null || r.apres == null) ? '—' : signe(r.apres!.de(g) - r.avant!.de(g), 0);
    const st = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.gris);
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Etiquette('⚖️ ${context.tr('md_avap_le', {'d': dateCourte(dernier.date)})}'),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2)},
          children: [
            TableRow(children: [
              const SizedBox(),
              Text(context.tr('md_avant'), style: st),
              Text(context.tr('md_apres'), style: st),
              Text(context.tr('md_ecart'), style: st),
            ]),
            for (final g in Grandeur.values)
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(nomGrandeur(g), style: const TextStyle(fontWeight: FontWeight.w800))),
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(v(r.avant, g))),
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(v(r.apres, g))),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(e(g), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
          ],
        ),
        Text(context.tr('md_avap_aide'), style: const TextStyle(fontSize: 12, color: Wt.gris)),
      ]),
    );
  }

  // --- Plan de traitement ---------------------------------------------------------------
  Widget _plan(BuildContext context, Dossier d) {
    final p = d.plan;
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Etiquette('💊 ${context.tr('md_plan')}'),
        Text(
          p == null
              ? context.tr('md_plan_aucun')
              : '${context.tr('md_actuel')} : ${p.medicament} ${nombre(p.doseMg)} mg · ${heureTexte(p.heure, p.minute)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (p == null && d.profil.medicaments.isNotEmpty)
          Text(
            '${context.tr('md_declare')} : ${d.profil.medicaments.map((m) => m.nom).join(', ')}',
            style: const TextStyle(fontSize: 14, color: Wt.gris),
          ),
        const SizedBox(height: 14),
        TextField(controller: _medicament, decoration: InputDecoration(labelText: context.tr('md_medicament'))),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in _medicaments)
            ActionChip(label: Text(m, style: const TextStyle(fontSize: 13)), onPressed: () => setState(() => _medicament.text = m)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          IconButton.outlined(
            tooltip: context.tr('diminuer'),
            onPressed: () => setState(() => _dose.text = nombre(((_doseSaisie ?? 0) - 2.5).clamp(0, 40).toDouble())),
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _dose,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.tr('md_dose'), suffixText: 'mg'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: context.tr('augmenter'),
            onPressed: () => setState(() => _dose.text = nombre(((_doseSaisie ?? 0) + 2.5).clamp(0, 40).toDouble())),
            icon: const Icon(Icons.add),
          ),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final h = await showTimePicker(context: context, initialTime: _heure);
            if (h != null) setState(() => _heure = h);
          },
          icon: const Icon(Icons.schedule),
          label: Text('${context.tr('md_heure')} : ${heureTexte(_heure.hour, _heure.minute)}'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _envoi ? null : () => _confirmerPlan(context, d), child: Text(context.tr('md_plan_enreg'))),
        ),
        const SizedBox(height: 6),
        Text('ℹ️ ${context.tr('md_plan_aide')}', style: const TextStyle(fontSize: 13, color: Wt.gris, height: 1.4)),
        if (d.historique.isNotEmpty) ...[
          const Divider(height: 28),
          Text(context.tr('md_historique'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final h in d.historique.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '• ${dateCourte(h.date)} · ${h.medicament} '
                '${h.ancienneDoseMg != null ? '${nombre(h.ancienneDoseMg!)} → ' : ''}${nombre(h.doseMg)} mg · '
                '${heureTexte(h.heure, h.minute)}${h.medecinNom.isNotEmpty ? ' · ${h.medecinNom}' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ]),
    );
  }

  Future<void> _confirmerPlan(BuildContext context, Dossier d) async {
    final med = _medicament.text.trim();
    final dose = _doseSaisie;
    if (med.isEmpty || dose == null || dose < 0 || dose > 40) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('md_plan_invalide'))));
      return;
    }
    final ancien = d.plan;
    final h = heureTexte(_heure.hour, _heure.minute);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('md_conf_titre')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            ancien == null
                ? context.tr('md_conf_nouveau', {'m': med, 'b': nombre(dose), 'h': h})
                : context.tr('md_conf_q', {'m': med, 'a': nombre(ancien.doseMg), 'b': nombre(dose), 'h': h}),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(context.tr('md_conf_s'), style: const TextStyle(fontSize: 15, height: 1.4)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.tr('md_annuler'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.tr('md_confirmer'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _envoi = true);
    try {
      await Depot.instance.modifierPlan(
        widget.uid,
        ancien: ancien,
        medicament: med,
        doseMg: dose,
        heure: _heure.hour,
        minute: _heure.minute,
        message: trL('md_msg_plan', {'m': med, 'b': nombre(dose), 'h': h}),
      );
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('md_plan_ok'))));
      _recharger();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠ $e')));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  // --- Messages ------------------------------------------------------------------------
  Widget _messages(BuildContext context, Dossier d) {
    final derniers = d.messages.length > 30 ? d.messages.sublist(d.messages.length - 30) : d.messages;
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Etiquette('💬 ${context.tr('md_messages')}'),
        if (derniers.isEmpty)
          Text(context.tr('md_messages_vide'), style: const TextStyle(color: Wt.gris))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(shrinkWrap: true, reverse: true, children: [
              for (final m in derniers.reversed)
                Align(
                  // Ici, « moi » est le médecin : ses messages à droite.
                  alignment: m.deMoi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.deMoi ? Wt.fond : Wt.violet,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.texte, style: TextStyle(fontSize: 15, height: 1.4, color: m.deMoi ? Wt.encre : Wt.blanc)),
                      const SizedBox(height: 4),
                      Text(
                        '${m.deMoi ? context.tr('md_patiente') : context.tr('md_vous')} · ${dateHeure(m.date)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.deMoi ? Wt.gris : const Color(0xFFDCD8FF)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _message,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(hintText: context.tr('md_ecrire')),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: FilledButton(
              onPressed: _envoi
                  ? null
                  : () async {
                      final t = _message.text.trim();
                      if (t.isEmpty) return;
                      setState(() => _envoi = true);
                      try {
                        await Depot.instance.envoyerMessage(widget.uid, t);
                        _message.clear();
                        _recharger();
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠ $e')));
                      } finally {
                        if (mounted) setState(() => _envoi = false);
                      }
                    },
              child: Text(context.tr('md_envoyer')),
            ),
          ),
        ]),
        Text('ℹ️ ${context.tr('md_messages_aide')}', style: const TextStyle(fontSize: 12, color: Wt.gris)),
      ]),
    );
  }

  // --- Actions ------------------------------------------------------------------------
  Future<void> _simuler(Dossier d) async {
    final dose = await Navigator.of(context).push<double>(MaterialPageRoute(builder: (_) => EcranSimulation(nom: widget.nom, dossier: d)));
    if (dose == null || !mounted) return;
    setState(() => _dose.text = nombre(dose));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('md_dose_reportee', {'d': nombre(dose)}))));
  }

  Future<void> _rapport(Dossier d) async {
    try {
      await genererEtTelechargerRapport(d, Depot.instance.medecin);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠ $e')));
    }
  }
}
