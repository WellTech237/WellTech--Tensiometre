import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controle.dart';
import '../core/risque.dart';
import '../l10n.dart';
import '../theme.dart';
import '../ui/visite_guidee.dart';
import 'calculs.dart';
import 'depot.dart';
import 'ecran_connexion.dart';
import 'ecran_dossier.dart';
import 'ui_medecin.dart';
import 'visite_web.dart';

/// Liste des patientes : les plus urgentes en haut, indicateurs du client
/// pour chacune (statut des 4 grandeurs, tendance = dérivée, observance).
class EcranListe extends StatefulWidget {
  const EcranListe({super.key});
  @override
  State<EcranListe> createState() => _EcranListeState();
}

class _EcranListeState extends State<EcranListe> {
  late Future<List<ResumePatient>> _futur;
  String _filtre = 'tous'; // tous | avoir | urg
  String _recherche = '';

  // Visite guidée (première connexion du médecin).
  bool _visiteTentee = false;
  final _cleCode = GlobalKey();
  final _cleKpi = GlobalKey();
  final _cleFiltres = GlobalKey();
  final _cleTableau = GlobalKey();
  final _cleActualiser = GlobalKey();
  final _cleOutils = GlobalKey();

  Future<void> _visite() async {
    await lancerVisite(context, [
      const EtapeVisite(emoji: '👋', titre: 'vgm_1_t', texte: 'vgm_1'),
      EtapeVisite.sur(_cleCode, emoji: '🔑', titre: 'vgm_2_t', texte: 'vgm_2'),
      EtapeVisite.sur(_cleKpi, emoji: '🚦', titre: 'vgm_3_t', texte: 'vgm_3'),
      EtapeVisite.sur(_cleFiltres, emoji: '🔎', titre: 'vgm_4_t', texte: 'vgm_4'),
      EtapeVisite.sur(_cleTableau, emoji: '👥', titre: 'vgm_5_t', texte: 'vgm_5'),
      EtapeVisite.sur(_cleActualiser, emoji: '🔄', titre: 'vgm_6_t', texte: 'vgm_6'),
      EtapeVisite.sur(_cleOutils, emoji: '🧰', titre: 'vgm_7_t', texte: 'vgm_7'),
      const EtapeVisite(emoji: '🩺', titre: 'vgm_8_t', texte: 'vgm_8'),
    ]);
    marquerVisiteVue('liste');
  }

  void _visiteAuPremierAffichage() {
    if (_visiteTentee) return;
    _visiteTentee = true;
    if (visiteVue('liste')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visite();
    });
  }

  // Mise à jour automatique : chaque synchronisation d'une patiente liée.
  Rafraichisseur? _direct;
  List<ResumePatient>? _dernier;
  DateTime? _majLe;

  @override
  void initState() {
    super.initState();
    _futur = _chargerListe();
    _direct = Rafraichisseur(Depot.instance.changementsPatients(), () => _recharger(silencieux: true));
  }

  @override
  void dispose() {
    _direct?.arreter();
    super.dispose();
  }

  /// Mise à jour silencieuse : en cas d'erreur passagère (réseau), on garde
  /// la liste déjà affichée au lieu d'un écran d'erreur.
  Future<List<ResumePatient>> _chargerListe({bool silencieux = false}) async {
    try {
      final l = await Depot.instance.patients();
      _dernier = l;
      _majLe = DateTime.now();
      return l;
    } catch (_) {
      if (silencieux && _dernier != null) return _dernier!;
      rethrow;
    }
  }

  void _recharger({bool silencieux = false}) {
    if (!mounted) return;
    setState(() => _futur = _chargerListe(silencieux: silencieux));
  }

  Future<void> _deconnecter() async {
    await Depot.instance.deconnecter();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const EcranConnexion()));
  }

  Future<void> _ouvrir(ResumePatient p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcranDossier(uid: p.uid, nom: p.nomComplet)));
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    context.enAnglais;
    return Scaffold(
      backgroundColor: Wt.fond,
      appBar: BarreHaut(onDeconnexion: _deconnecter, onVisite: _visite, cleOutils: _cleOutils),
      body: FutureBuilder<List<ResumePatient>>(
        future: _futur,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('⚠ ${context.tr('md_err_chargement')}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${snap.error}', style: const TextStyle(fontSize: 13, color: Wt.gris)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _recharger, child: Text(context.tr('md_reessayer'))),
              ]),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _visiteAuPremierAffichage();
          final tous = snap.data!;
          final q = _recherche.toLowerCase();
          final liste = tous.where((p) {
            if (_filtre == 'urg' && p.priorite != Priorite.urgence) return false;
            if (_filtre == 'avoir' && p.priorite == Priorite.stable) return false;
            return q.isEmpty || p.nomComplet.toLowerCase().contains(q);
          }).toList();
          final nbUrg = tous.where((p) => p.priorite == Priorite.urgence).length;
          final nbVoir = tous.where((p) => p.priorite == Priorite.aVoir).length;
          final nbMesures = tous.fold<int>(0, (a, p) => a + p.mesures7);
          return RefreshIndicator(
            onRefresh: () async => _recharger(),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Centre(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('md_liste_titre'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                      Text(context.tr('md_liste_sous', {'d': dateLongue(DateTime.now())}), style: const TextStyle(fontSize: 16, color: Wt.gris, fontWeight: FontWeight.w600)),
                    ]),
                    Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      PastilleDirect(_majLe),
                      OutlinedButton.icon(key: _cleActualiser, onPressed: _recharger, icon: const Icon(Icons.refresh), label: Text(context.tr('md_actualiser'))),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  KeyedSubtree(key: _cleCode, child: _carteCode(context)),
                  const SizedBox(height: 16),
                  GrilleKpi(key: _cleKpi, [
                    Kpi(titre: '🚨 ${context.tr('md_k_urg')}', valeur: '$nbUrg', sous: context.tr('md_k_urg_s'), fond: nbUrg > 0 ? Wt.crise : Wt.blanc, couleur: nbUrg > 0 ? Wt.blanc : Wt.encre),
                    Kpi(titre: '👀 ${context.tr('md_k_voir')}', valeur: '$nbVoir', sous: context.tr('md_k_voir_s'), fond: nbVoir > 0 ? Wt.jaune : Wt.blanc, couleur: nbVoir > 0 ? Wt.jauneTexte : Wt.encre),
                    Kpi(titre: '👥 ${context.tr('md_k_patients')}', valeur: '${tous.length}', sous: context.tr('md_k_patients_s')),
                    Kpi(titre: '🩺 ${context.tr('md_k_mesures')}', valeur: '$nbMesures', sous: context.tr('md_k_mesures_s')),
                  ]),
                  const SizedBox(height: 18),
                  Wrap(key: _cleFiltres, spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'tous', label: Text(context.tr('md_f_tous'))),
                        ButtonSegment(value: 'avoir', label: Text(context.tr('md_f_voir'))),
                        ButtonSegment(value: 'urg', label: Text(context.tr('md_f_urg'))),
                      ],
                      selected: {_filtre},
                      onSelectionChanged: (s) => setState(() => _filtre = s.first),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('md_rechercher'), contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                        onChanged: (v) => setState(() => _recherche = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (tous.isEmpty)
                    CarteM(
                      key: _cleTableau,
                      padding: const EdgeInsets.all(28),
                      child: Column(children: [
                        const Text('👥', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(context.tr('md_vide'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.5)),
                      ]),
                    )
                  else
                    CarteM(
                      key: _cleTableau,
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        _entete(context),
                        if (liste.isEmpty)
                          Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('md_aucun_resultat'), style: const TextStyle(color: Wt.gris)))
                        else
                          for (final p in liste) _ligne(context, p),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  Text('ℹ️ ${context.tr('md_liste_aide')}', style: const TextStyle(fontSize: 14, color: Wt.gris, height: 1.5)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _carteCode(BuildContext context) {
    final code = Depot.instance.medecin?.code;
    return CarteM(
      fond: Wt.violetClair,
      bordure: Wt.violetClair,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('🔑 ${context.tr('md_code')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Wt.violetTexte)),
        SelectableText(code ?? '—', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Wt.violetFonce)),
        if (code != null)
          IconButton(
            tooltip: context.tr('md_copier'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('md_copie'))));
            },
            icon: const Icon(Icons.copy, color: Wt.violetFonce),
          ),
        Text(context.tr('md_code_aide'), style: const TextStyle(fontSize: 14, color: Wt.violetTexte, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  static const _flex = [26, 14, 16, 13, 16, 13, 11, 9, 10];

  Widget _cellule(int i, Widget w) => Expanded(flex: _flex[i], child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: w));

  Widget _entete(BuildContext context) {
    const st = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.gris);
    final titres = ['md_c_patient', 'md_c_profil', 'md_c_derniere', 'md_c_niveau', 'md_c_controle', 'md_c_tendance', 'md_c_obs', 'md_c_alertes', ''];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Wt.bordure))),
      child: Row(children: [
        for (var i = 0; i < titres.length; i++) _cellule(i, Text(titres[i].isEmpty ? '' : context.tr(titres[i]), style: st, maxLines: 2)),
      ]),
    );
  }

  Widget _ligne(BuildContext context, ResumePatient p) {
    final d = p.derniere;
    final pr = couleursPriorite(p.priorite);
    final ok = p.quatreOk;
    final nOk = ok.where((x) => x).length;
    final obs = p.obs;
    return InkWell(
      onTap: () => _ouvrir(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: p.priorite == Priorite.urgence ? const Color(0xFFFFF5F4) : Wt.blanc,
          border: const Border(bottom: BorderSide(color: Wt.bordure)),
        ),
        child: Row(children: [
          _cellule(
            0,
            Row(children: [
              Container(width: 6, height: 40, decoration: BoxDecoration(color: p.priorite == Priorite.stable ? Wt.bordure : pr.fond, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nomComplet, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    [
                      if (p.profil.age != null) context.tr('pr_age', {'a': p.profil.age}),
                      if (p.nonLus > 0) '💬 ${p.nonLus}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 13, color: Wt.gris, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ]),
          ),
          _cellule(1, Text(p.risque.libelle, maxLines: 2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          _cellule(
            2,
            d == null
                ? Text(context.tr('md_aucune_mesure'), style: const TextStyle(fontSize: 14, color: Wt.gris))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d.tas}/${d.tad}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(ilYa(d.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Wt.gris, fontWeight: FontWeight.w600)),
                  ]),
          ),
          _cellule(3, d == null ? const Text('—') : Align(alignment: Alignment.centerLeft, child: PastilleGrade(d.grade))),
          _cellule(
            4,
            p.semaine.moyenne == null
                ? const Text('—')
                : Row(children: [
                    for (var i = 0; i < 4; i++)
                      Tooltip(
                        message: '${nomGrandeur(Grandeur.values[i])} : ${ok[i] ? '✓' : '✗'}',
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: ok[i] ? Wt.vert : const Color(0xFFD9534A), shape: BoxShape.circle),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text('$nOk/4', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ]),
          ),
          _cellule(
            5,
            Text(
              p.semaine.moyenne == null ? '—' : '${signe(p.tendance)} ${context.tr('md_mmhg_sem')}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.tendance > 0.5 ? Wt.rougeTexte : (p.tendance < -0.5 ? Wt.vertTexte : Wt.encre)),
            ),
          ),
          _cellule(6, Text(obs == null ? '—' : '${(obs.taux * 100).round()} %', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          _cellule(
            7,
            Align(
              alignment: Alignment.centerLeft,
              child: Pastille('${p.alertes}', fond: p.alertes > 0 ? Wt.rougeClair : Wt.fond, couleur: p.alertes > 0 ? Wt.rougeTexte : Wt.gris),
            ),
          ),
          _cellule(8, Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _ouvrir(p), child: Text(context.tr('md_ouvrir'))))),
        ]),
      ),
    );
  }
}
