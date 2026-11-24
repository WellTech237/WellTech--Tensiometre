import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../theme.dart';
import '../ui/visite_guidee.dart';
import 'depot.dart';
import 'ecran_connexion.dart';
import 'notification_admin.dart';
import 'ui_medecin.dart';
import 'visite_web.dart';

/// Espace administrateur : vérifier les demandes des médecins (numéro
/// d'ordre dans le registre public de l'Ordre), valider, refuser avec un
/// motif, ou suspendre un compte. Accès : document admins/{uid}.
class EcranAdmin extends StatefulWidget {
  const EcranAdmin({super.key});
  @override
  State<EcranAdmin> createState() => _EcranAdminState();
}

class _EcranAdminState extends State<EcranAdmin> {
  late Future<List<Medecin>> _futur;
  String _filtre = 'en_attente';
  StreamSubscription<int>? _ecoute;
  int? _nbAttente;
  // Mise à jour automatique : toute demande, décision ou correction.
  Rafraichisseur? _direct;
  List<Medecin>? _dernier;
  DateTime? _majLe;

  // Visite guidée de l'espace Administration (première connexion admin).
  bool _visiteTentee = false;
  final _cleKpi = GlobalKey();
  final _cleAide = GlobalKey();
  final _cleFiltre = GlobalKey();
  final _cleOutils = GlobalKey();

  Future<void> _visite() async {
    await lancerVisite(context, [
      const EtapeVisite(emoji: '🛡️', titre: 'vga_1_t', texte: 'vga_1'),
      EtapeVisite.sur(_cleKpi, emoji: '📊', titre: 'vga_2_t', texte: 'vga_2'),
      EtapeVisite.sur(_cleAide, emoji: '🔎', titre: 'vga_3_t', texte: 'vga_3'),
      EtapeVisite.sur(_cleFiltre, emoji: '✅', titre: 'vga_4_t', texte: 'vga_4'),
      EtapeVisite.sur(_cleOutils, emoji: '🧰', titre: 'vgm_7_t', texte: 'vgm_7'),
      const EtapeVisite(emoji: '🔔', titre: 'vga_5_t', texte: 'vga_5'),
    ]);
    marquerVisiteVue('admin');
  }

  @override
  void initState() {
    super.initState();
    _futur = _chargerComptes();
    _direct = Rafraichisseur(Depot.instance.changementsMedecins(), () => _recharger(silencieux: true));
    // Alerte en direct : une nouvelle demande arrive pendant que le portail
    // est ouvert -> message + liste mise à jour.
    _ecoute = Depot.instance.demandesEnAttente().listen((n) {
      final avant = _nbAttente;
      _nbAttente = n;
      if (avant != null && n > avant && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Wt.violetFonce,
          duration: const Duration(seconds: 10),
          content: Text('🔔 ${context.tr('ad_nouvelle_demande')}'),
        ));
        _filtre = 'en_attente';
        _recharger();
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _ecoute?.cancel();
    _direct?.arreter();
    super.dispose();
  }

  Future<List<Medecin>> _chargerComptes({bool silencieux = false}) async {
    try {
      final l = await Depot.instance.comptesMedecins();
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
    setState(() => _futur = _chargerComptes(silencieux: silencieux));
  }

  Future<void> _deconnecter() async {
    await Depot.instance.deconnecter();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const EcranConnexion()));
  }

  /// Ouvre la messagerie avec un courriel prêt à envoyer.
  Future<void> _courriel(Medecin m, bool valide) async {
    final sujet = trL(valide ? 'ad_mail_ok_sujet' : 'ad_mail_refus_sujet');
    final corps = trL(valide ? 'ad_mail_ok_corps' : 'ad_mail_refus_corps', {'n': m.nom, 'm': m.motif});
    final uri = Uri.parse('mailto:${m.email}?subject=${Uri.encodeComponent(sujet)}&body=${Uri.encodeComponent(corps)}');
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('ad_mail_impossible'))));
    }
  }

  Future<void> _valider(Medecin m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('ad_valider_q', {'n': m.nom})),
        content: Text(c.tr('ad_valider_s', {'o': m.numeroOrdre}), style: const TextStyle(fontSize: 15, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('md_annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('ad_valider'))),
        ],
      ),
    );
    if (ok != true) return;
    await _decider(m, 'valide');
  }

  Future<void> _refuser(Medecin m, {bool suspendre = false}) async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr(suspendre ? 'ad_suspendre_q' : 'ad_refuser_q', {'n': m.nom})),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.tr('ad_motif_aide'), style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 10),
            TextField(controller: motif, minLines: 2, maxLines: 4, maxLength: 300, decoration: InputDecoration(labelText: c.tr('att_motif'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('md_annuler'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Wt.rouge),
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr(suspendre ? 'ad_suspendre' : 'ad_refuser')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _decider(m, 'refuse', motif: motif.text.trim(), suspension: suspendre);
  }

  Future<void> _decider(Medecin m, String statut, {String motif = '', bool suspension = false}) async {
    try {
      await Depot.instance.decider(m.uid, statut, motif: motif);
      final valide = statut == 'valide';
      // Courriel automatique au médecin (le bouton « Prévenir » reste en secours).
      final envoye = m.email.isNotEmpty &&
          await notifierMedecin(
            email: m.email,
            nom: m.nom,
            decision: valide ? 'valide' : (suspension ? 'suspendu' : 'refuse'),
            motif: motif,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          '${context.tr(valide ? 'ad_valide_ok' : 'ad_refuse_ok', {'n': m.nom})} '
          '${context.tr(envoye ? 'ad_mail_envoye' : 'ad_mail_echec')}',
        ),
        action: envoye ? null : SnackBarAction(
          label: context.tr('ad_prevenir'),
          onPressed: () => _courriel(Medecin.depuis(m.uid, {'nom': m.nom, 'email': m.email, 'motif': motif}), valide),
        ),
      ));
      _recharger();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠ $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.enAnglais;
    return Scaffold(
      backgroundColor: Wt.fond,
      appBar: BarreHaut(onDeconnexion: _deconnecter, onVisite: _visite, cleOutils: _cleOutils),
      body: FutureBuilder<List<Medecin>>(
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
          if (!_visiteTentee) {
            _visiteTentee = true;
            if (!visiteVue('admin')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _visite();
              });
            }
          }
          final tous = snap.data!;
          int nb(String s) => tous.where((m) => m.statut == s).length;
          final liste = tous.where((m) => m.statut == _filtre).toList();
          return ListView(padding: const EdgeInsets.all(24), children: [
            Centre(
              max: 1100,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('ad_titre'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    Text(context.tr('ad_sous'), style: const TextStyle(fontSize: 16, color: Wt.gris, fontWeight: FontWeight.w600)),
                  ]),
                  Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    PastilleDirect(_majLe),
                    OutlinedButton.icon(onPressed: _recharger, icon: const Icon(Icons.refresh), label: Text(context.tr('md_actualiser'))),
                  ]),
                ]),
                const SizedBox(height: 16),
                GrilleKpi(key: _cleKpi, [
                  Kpi(titre: '⏳ ${context.tr('ad_k_attente')}', valeur: '${nb('en_attente')}', fond: nb('en_attente') > 0 ? Wt.jaune : Wt.blanc, couleur: nb('en_attente') > 0 ? Wt.jauneTexte : Wt.encre),
                  Kpi(titre: '✓ ${context.tr('ad_k_valides')}', valeur: '${nb('valide')}'),
                  Kpi(titre: '✗ ${context.tr('ad_k_refuses')}', valeur: '${nb('refuse')}'),
                ], largeurMin: 220),
                const SizedBox(height: 16),
                CarteM(
                  key: _cleAide,
                  fond: Wt.violetClair,
                  bordure: Wt.violetClair,
                  child: Text('🔎 ${context.tr('ad_verifier_aide')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Wt.violetTexte, height: 1.45)),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    key: _cleFiltre,
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'en_attente', label: Text('${context.tr('ad_k_attente')} (${nb('en_attente')})')),
                      ButtonSegment(value: 'valide', label: Text('${context.tr('ad_k_valides')} (${nb('valide')})')),
                      ButtonSegment(value: 'refuse', label: Text('${context.tr('ad_k_refuses')} (${nb('refuse')})')),
                    ],
                    selected: {_filtre},
                    onSelectionChanged: (s) => setState(() => _filtre = s.first),
                  ),
                ),
                const SizedBox(height: 14),
                if (liste.isEmpty)
                  CarteM(padding: const EdgeInsets.all(24), child: Text(context.tr('ad_vide'), style: const TextStyle(fontSize: 16, color: Wt.gris)))
                else
                  for (final m in liste) Padding(padding: const EdgeInsets.only(bottom: 12), child: _carte(context, m)),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _carte(BuildContext context, Medecin m) {
    Widget info(String emoji, String cle, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 28, child: Text(emoji)),
            SizedBox(width: 150, child: Text(context.tr(cle), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris))),
            Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
        );
    return CarteM(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
          Text(m.nom.isEmpty ? '—' : m.nom, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          if (m.demandeLe != null)
            Text(context.tr('ad_demande_le', {'d': dateHeure(m.demandeLe!)}), style: const TextStyle(fontSize: 13, color: Wt.gris, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        info('✉️', 'md_courriel', m.email),
        info('📞', 'ins_tel', m.telephone),
        info('🪪', 'ins_numero', m.numeroOrdre),
        if (m.code != null) info('🔑', 'md_code', m.code!),
        if (m.motif.isNotEmpty) info('📝', 'att_motif', m.motif),
        if (m.decisionLe != null) info('🕐', 'ad_decision_le', dateHeure(m.decisionLe!)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (!m.valide)
            FilledButton.icon(onPressed: () => _valider(m), icon: const Icon(Icons.check), label: Text(context.tr('ad_valider'))),
          if (m.statut == 'en_attente')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Wt.rougeTexte),
              onPressed: () => _refuser(m),
              icon: const Icon(Icons.close),
              label: Text(context.tr('ad_refuser')),
            ),
          if (m.valide)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Wt.rougeTexte),
              onPressed: () => _refuser(m, suspendre: true),
              icon: const Icon(Icons.block),
              label: Text(context.tr('ad_suspendre')),
            ),
          if (m.email.isNotEmpty && m.statut != 'en_attente')
            OutlinedButton.icon(onPressed: () => _courriel(m, m.valide), icon: const Icon(Icons.mail_outline), label: Text(context.tr('ad_prevenir'))),
        ]),
      ]),
    );
  }
}
