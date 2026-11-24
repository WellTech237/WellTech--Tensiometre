import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/risque.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/notifications.dart';
import '../../services/voix.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'saisie_screen.dart';

/// Urgence + mode crise : 911 en priorité, mesure toutes les 5 minutes,
/// épisodes de 30 minutes, puis « Les secours sont-ils arrivés ? ».
class UrgenceScreen extends StatefulWidget {
  final int? tasDepart, tadDepart;
  final List<String> symptomes;

  /// Ouvert depuis l'écran verrouillé : 911, SMS et fiche, sans historique.
  final bool sansDonnees;
  const UrgenceScreen({super.key, this.tasDepart, this.tadDepart, this.symptomes = const [], this.sansDonnees = false});
  @override
  State<UrgenceScreen> createState() => _UrgenceScreenState();
}

class _UrgenceScreenState extends State<UrgenceScreen> {
  static const dureeEpisode = Duration(minutes: 30);
  static const intervalle = Duration(minutes: 5);

  String? _episode;
  DateTime? _debut;
  int _numeroEpisode = 1;
  List<Mesure> _mesures = [];
  Timer? _tic;
  bool _questionPosee = false;
  bool _prevenu = false;
  bool _nouvelEpisodeMsg = false;

  AppState get _e => AppState.instance;

  @override
  void initState() {
    super.initState();
    Voix.instance.lire(trL('ur_voix'));
    if (!widget.sansDonnees) _demarrerOuReprendre();
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  Future<void> _demarrerOuReprendre() async {
    final s = await _e.db.lireReglage('episode');
    if (s != null && s.isNotEmpty) {
      final parts = s.split(';');
      _episode = parts[0];
      _debut = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
      _numeroEpisode = int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1;
    } else {
      await _nouvelEpisode(1);
    }
    await _rafraichir();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) => _verifierFin());
  }

  Future<void> _nouvelEpisode(int numero) async {
    _episode = _e.nouvelEpisode();
    _debut = DateTime.now();
    _numeroEpisode = numero;
    _questionPosee = false;
    await _e.db.ecrireReglage('episode', '$_episode;${_debut!.millisecondsSinceEpoch};$numero');
    await Notifications.instance.programmerCrise(_debut!);
  }

  Future<void> _rafraichir() async {
    if (_episode == null) return;
    final l = await _e.db.mesuresEpisode(_episode!);
    if (mounted) setState(() => _mesures = l);
  }

  void _verifierFin() {
    if (!mounted || _debut == null) return;
    setState(() {});
    if (!_questionPosee && DateTime.now().difference(_debut!) >= dureeEpisode) {
      _questionPosee = true;
      _poserQuestion();
    }
  }

  Future<void> _poserQuestion() async {
    Voix.instance.lire(trL('ur_question_voix'));
    final arrives = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(c.tr('ur_question'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        content: Text(c.tr('ur_question_exp'), style: const TextStyle(fontSize: 17, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('ur_non'))),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(130, 52)), onPressed: () => Navigator.pop(c, true), child: Text(c.tr('ur_oui'))),
        ],
      ),
    );
    if (arrives == true) {
      await _terminer();
    } else {
      await _nouvelEpisode(_numeroEpisode + 1);
      _nouvelEpisodeMsg = true;
      await _rafraichir();
    }
  }

  Future<void> _terminer() async {
    _tic?.cancel();
    await Notifications.instance.annulerCrise();
    await _e.db.ecrireReglage('episode', '');
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _appeler911() => launchUrl(Uri(scheme: 'tel', path: '911'));

  Future<void> _prevenir() async {
    final p = _e.profil;
    final t = widget.tasDepart != null ? ' ${trL('ur_sms_tension', {'t': '${widget.tasDepart}/${widget.tadDepart}'})}' : '';
    final msg = trL('ur_sms', {'p': p.prenom.isEmpty ? '' : p.prenom}) + t;
    final tel = _e.contact?.telephone ?? '';
    await launchUrl(Uri.parse('sms:$tel?body=${Uri.encodeComponent(msg)}'));
    if (mounted) setState(() => _prevenu = true);
  }

  Future<void> _mesurer() async {
    if (_episode == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaisieScreen(episodeId: _episode)));
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    final p = _e.profil;
    final contact = _e.contact;
    final ecoule = _debut == null ? Duration.zero : DateTime.now().difference(_debut!);
    final dansCycle = Duration(seconds: intervalle.inSeconds - (ecoule.inSeconds % intervalle.inSeconds));
    final mm = dansCycle.inMinutes.toString().padLeft(2, '0');
    final ss = (dansCycle.inSeconds % 60).toString().padLeft(2, '0');
    final n = _mesures.length;
    final antecedents = [if (p.avc) trL('pr_avc'), ...p.maladies.map(nomMaladie), if (p.autreMaladie.isNotEmpty) p.autreMaladie].join(', ');
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          decoration: const BoxDecoration(color: Wt.crise, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
          padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 16, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFA12A20), borderRadius: BorderRadius.circular(999)),
                child: Text('🚑 ${context.tr('ur_etiquette')}', style: const TextStyle(color: Wt.blanc, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              const Spacer(),
              const BoutonLangue(),
              const SizedBox(width: 8),
              BoutonEcouter(texte: () => trL('ur_voix_minuteur', {'m': dansCycle.inMinutes}), encre: Wt.crise),
            ]),
            const SizedBox(height: 14),
            Text(context.tr('ur_titre'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Wt.blanc)),
            if (widget.tasDepart != null)
              Text(
                '${widget.tasDepart}/${widget.tadDepart} mmHg${widget.symptomes.isEmpty ? '' : ' · ${widget.symptomes.join(', ')}'}',
                style: const TextStyle(fontSize: 17, color: Color(0xFFFFE3E0), fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Wt.blanc, foregroundColor: Wt.crise, minimumSize: const Size.fromHeight(76), textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              onPressed: _appeler911,
              icon: const Icon(Icons.call, size: 30),
              label: Text(context.tr('appeler_911')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Wt.blanc, side: const BorderSide(color: Wt.blanc, width: 2), minimumSize: const Size.fromHeight(58)),
              onPressed: _prevenir,
              child: Text(_prevenu
                  ? context.tr('ur_prevenu')
                  : contact == null || contact.nom.isEmpty
                      ? context.tr('ur_prevenir')
                      : context.tr('ur_prevenir_nom', {'n': contact.nom})),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!widget.sansDonnees && _debut != null) ...[
              Carte(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(context.tr('ur_suivi'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris))),
                    Text(context.tr('ur_episode', {'e': _numeroEpisode, 'n': n}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (var i = 0; i < 6; i++) ...[
                      Expanded(child: Container(height: 9, decoration: BoxDecoration(color: i < n ? Wt.rouge : Wt.bordure, borderRadius: BorderRadius.circular(5)))),
                      if (i < 5) const SizedBox(width: 4),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.tr('ur_prochaine'), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700)),
                        Text('$mm:$ss', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                      ]),
                    ),
                    FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 58)), onPressed: _mesurer, child: Text(context.tr('ur_mesurer'))),
                  ]),
                  for (final m in _mesures)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${heureDe(m.date)} · ${m.tas}/${m.tad} · ❤️ ${m.pouls}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 6),
                  Text('📈 ${context.tr('ur_envoi')}', style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
                  if (_nouvelEpisodeMsg) ...[const SizedBox(height: 8), Encadre('⚠️', context.tr('ur_nouveau'), fond: Wt.jaune, encre: Wt.jauneTexte)],
                ]),
              ),
              const SizedBox(height: 14),
            ],
            Carte(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⏳ ${context.tr('ur_attente')}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final c in [('🛋️', 'ur_a1'), ('💊', 'ur_a2'), ('🚪', 'ur_a3')])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Emo(c.$1, taille: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.tr(c.$2), style: const TextStyle(fontSize: 17, height: 1.45))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            Carte(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🩺 ${context.tr('ur_fiche')}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _ligne(context.tr('ur_f_ant'), antecedents),
                _ligne(context.tr('ur_f_trait'), p.medicaments.map((m) => '${m.nom} ${m.dose}'.trim()).join(', ')),
                _ligne(context.tr('ur_f_autres'), p.autresRenseignements),
                if (p.grossesseActive) _ligne(context.tr('ur_f_grossesse'), context.tr('ur_semaines', {'n': p.semainesGrossesse ?? '?'})),
              ]),
            ),
            const SizedBox(height: 16),
            if (!widget.sansDonnees && _debut != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Wt.encre, side: const BorderSide(color: Wt.gris, width: 2)),
                onPressed: _poserQuestion,
                child: Text(context.tr('ur_arreter')),
              ),
            if (widget.sansDonnees) TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.tr('fermer'))),
          ]),
        ),
      ]),
    );
  }

  Widget _ligne(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Wt.gris, fontWeight: FontWeight.w700, fontSize: 15))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        ]),
      );
}
