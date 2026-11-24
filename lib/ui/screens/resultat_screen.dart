import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/classification.dart';
import '../../core/controle.dart';
import '../../core/risque.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/voix.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'urgence_screen.dart';

/// Résultat : valeur, niveau AHA, 4 grandeurs, symptômes à toucher,
/// décision d'alerte (grade × symptômes × profil).
class ResultatScreen extends StatefulWidget {
  final int tas, tad, pouls, nbLectures;
  final String? episodeId;
  const ResultatScreen({super.key, required this.tas, required this.tad, required this.pouls, required this.nbLectures, this.episodeId});
  @override
  State<ResultatScreen> createState() => _ResultatScreenState();
}

class _ResultatScreenState extends State<ResultatScreen> {
  final _coches = <String>{}; // ids de symptômes
  final _autreCtrl = TextEditingController();
  bool _aucun = false;
  bool _autreOuvert = false;
  bool _enregistre = false;

  AppState get _e => AppState.instance;
  bool get _grossesse => _e.profil.grossesseActive;
  Grade get _grade => classerPour(widget.tas, widget.tad, enceinte: _grossesse);
  List<Symptome> get _liste => symptomesPour(grossesse: _grossesse);

  List<String> get _alarmes => _liste.where((s) => s.alarme && _coches.contains(s.id)).map((s) => s.libelle).toList();
  List<String> get _autres => [
        ..._liste.where((s) => !s.alarme && _coches.contains(s.id)).map((s) => s.libelle),
        if (_autreCtrl.text.trim().isNotEmpty) _autreCtrl.text.trim(),
      ];

  DecisionAlerte get _decision => deciderAlerte(grade: _grade, symptomesCoches: _alarmes, symptomesAutres: _autres, risque: _e.risque);

  @override
  void initState() {
    super.initState();
    if (_e.voixAuto) WidgetsBinding.instance.addPostFrameCallback((_) => Voix.instance.lire(_texteVoix()));
  }

  String _texteVoix() {
    final d = _decision;
    return '${trL('re_voix', {'t': Voix.tension(widget.tas, widget.tad), 'g': _grade.libelle})} ${d.titre}. ${d.conseil}';
  }

  Future<void> _enregistrer() async {
    if (_enregistre) return;
    setState(() => _enregistre = true);
    final (mesure, decision) = await _e.enregistrerMesure(
      tas: widget.tas,
      tad: widget.tad,
      pouls: widget.pouls,
      nbLectures: widget.nbLectures,
      symptomesCoches: _alarmes,
      symptomesAutres: _autres,
      episodeId: widget.episodeId,
    );
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    if (widget.episodeId != null) {
      Navigator.of(context).pop();
    } else if (decision.niveau == 4) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => UrgenceScreen(tasDepart: widget.tas, tadDepart: widget.tad, symptomes: [..._alarmes, ..._autres])));
    } else {
      Navigator.of(context).pop();
      // Faire et défaire : la mesure peut être annulée pendant quelques secondes.
      messager.showSnackBar(SnackBar(
        content: Text(trL('re_enregistree')),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: trL('annuler'), onPressed: () => AppState.instance.annulerMesure(mesure)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _decision;
    final cn = couleursNiveau(d.niveau);
    final urgent = d.niveau == 4;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          EnTete(context.tr('re_titre'), retour: true),
          Carte(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    widget.nbLectures > 1 ? context.tr('re_moyenne', {'n': widget.nbLectures}) : context.tr('re_une'),
                    style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700),
                  ),
                ),
                BoutonEcouter(texte: _texteVoix, fond: Wt.violetClair, encre: Wt.violetFonce),
              ]),
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
                Text('${widget.tas}/${widget.tad}', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.05)),
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('mmHg · ❤️ ${widget.pouls} bpm', style: const TextStyle(fontSize: 16, color: Wt.gris, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              PuceGrade(_grade, long: true),
              const SizedBox(height: 14),
              QuatreValeurs(Grandeurs(widget.tas.toDouble(), widget.tad.toDouble())),
            ]),
          ),
          const SizedBox(height: 18),
          Text(context.tr('re_sym_q'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
          Text(context.tr('re_sym_aide'), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Puce(
            texte: context.tr('re_aucun'),
            emoji: '✅',
            active: _aucun,
            onTap: () => setState(() {
              _aucun = !_aucun;
              if (_aucun) {
                _coches.clear();
                _autreCtrl.clear();
                _autreOuvert = false;
              }
            }),
          ),
          const SizedBox(height: 10),
          GrillePuces([
            for (final s in _liste)
              Puce(
                texte: s.libelle,
                emoji: s.emoji,
                active: _coches.contains(s.id),
                danger: s.alarme,
                onTap: () => setState(() {
                  _aucun = false;
                  _coches.contains(s.id) ? _coches.remove(s.id) : _coches.add(s.id);
                }),
              ),
            Puce(
              texte: context.tr('re_autre'),
              emoji: '✏️',
              active: _autreOuvert,
              onTap: () => setState(() {
                _aucun = false;
                _autreOuvert = !_autreOuvert;
              }),
            ),
          ]),
          if (_autreOuvert) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _autreCtrl,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(hintText: context.tr('re_autre_aide')),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: cn.fond, borderRadius: BorderRadius.circular(22)),
            child: Semantics(
              liveRegion: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  for (var i = 1; i <= 4; i++) ...[
                    Expanded(child: Container(height: 6, decoration: BoxDecoration(color: i <= d.niveau ? cn.texte : cn.texte.withAlpha(50), borderRadius: BorderRadius.circular(3)))),
                    if (i < 4) const SizedBox(width: 4),
                  ],
                ]),
                const SizedBox(height: 10),
                Text('${emojisNiveau[d.niveau - 1]} ${d.nomNiveau.toUpperCase()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cn.texte, letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(d.titre, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: cn.texte)),
                const SizedBox(height: 4),
                Text(d.conseil, style: TextStyle(fontSize: 16, color: cn.texte, height: 1.5, fontWeight: FontWeight.w600)),
                if (urgent) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Wt.blanc, foregroundColor: Wt.crise),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: '911')),
                    icon: const Icon(Icons.call),
                    label: Text(context.tr('appeler_911')),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: urgent ? FilledButton.styleFrom(backgroundColor: Wt.crise) : null,
            onPressed: _enregistre ? null : _enregistrer,
            child: Text(context.tr(urgent ? 're_ouvrir_urgence' : 're_enregistrer')),
          ),
          const SizedBox(height: 8),
          Text('⏰ ${context.tr('re_prochaine', {'h': AppState.formatHeure(TimeOfDay.fromDateTime(_e.prochaineMesure()))})}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
