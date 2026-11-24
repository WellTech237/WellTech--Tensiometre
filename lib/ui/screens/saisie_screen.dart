import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/classification.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'resultat_screen.dart';

/// Saisie guidée : 2 mesures à 1 minute d'écart (1 seule en mode crise).
/// Chaque valeur a des boutons − / + et le clavier ; les erreurs sont
/// expliquées sous le champ, avec la solution.
class SaisieScreen extends StatefulWidget {
  final String? episodeId;
  const SaisieScreen({super.key, this.episodeId});
  @override
  State<SaisieScreen> createState() => _SaisieScreenState();
}

class _Champ {
  final String cle; // sys | dia | pul
  final String emoji;
  final int min, max, defaut;
  final TextEditingController ctrl;
  _Champ(this.cle, this.emoji, this.min, this.max, this.defaut, int? avant) : ctrl = TextEditingController(text: '${avant ?? defaut}');
  int? get valeur => int.tryParse(ctrl.text);
}

class _SaisieScreenState extends State<SaisieScreen> {
  late final List<_Champ> _champs;
  final List<(int, int, int)> _lectures = [];

  bool get _crise => widget.episodeId != null;
  int get _voulues => _crise ? 1 : 2;

  @override
  void initState() {
    super.initState();
    final d = AppState.instance.derniere;
    _champs = [
      _Champ('sys', '⬆️', Bornes.tasMin, Bornes.tasMax, 130, d?.tas),
      _Champ('dia', '⬇️', Bornes.tadMin, Bornes.tadMax, 80, d?.tad),
      _Champ('pul', '❤️', Bornes.poulsMin, Bornes.poulsMax, 72, d?.pouls),
    ];
    for (final c in _champs) {
      c.ctrl.addListener(() => setState(() {}));
    }
  }

  /// (type, message) par champ : 'err' bloque, 'warn' prévient seulement.
  Map<String, (String, String)> _messages() {
    final m = <String, (String, String)>{};
    for (final c in _champs) {
      final v = c.valeur;
      if (v == null) {
        m[c.cle] = ('err', trL('err_vide'));
      } else if (v < c.min || v > c.max) {
        m[c.cle] = ('err', trL('err_plage', {'a': c.min, 'b': c.max}));
      }
    }
    final s = _champs[0].valeur, d = _champs[1].valeur;
    if (!m.containsKey('sys') && !m.containsKey('dia') && s != null && d != null) {
      if (d >= s) {
        m['dia'] = ('err', trL('err_ordre'));
      } else if (s >= 180 || d >= 120) {
        m['sys'] = ('warn', trL('sa_tres_haut'));
      }
    }
    return m;
  }

  void _pas(_Champ c, int delta) {
    final v = c.valeur ?? c.defaut;
    c.ctrl.text = '${(v + delta).clamp(0, 400)}';
  }

  void _inverser() {
    final s = _champs[0].ctrl.text;
    _champs[0].ctrl.text = _champs[1].ctrl.text;
    _champs[1].ctrl.text = s;
  }

  void _valider() {
    _lectures.add((_champs[0].valeur!, _champs[1].valeur!, _champs[2].valeur!));
    if (_lectures.length < _voulues) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('sa_ok1')), duration: const Duration(seconds: 4)));
      return;
    }
    final n = _lectures.length;
    int moy(int Function((int, int, int)) f) => (_lectures.map(f).reduce((a, b) => a + b) / n).round();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultatScreen(tas: moy((l) => l.$1), tad: moy((l) => l.$2), pouls: moy((l) => l.$3), nbLectures: n, episodeId: widget.episodeId),
    ));
  }

  Widget _champ(_Champ c, (String, String)? msg) {
    final err = msg?.$1 == 'err';
    final bord = err ? Wt.rouge : (msg != null ? const Color(0xFFB76E00) : Wt.bordure);
    final avant = AppState.instance.derniere;
    final valAvant = avant == null ? null : (c.cle == 'sys' ? avant.tas : c.cle == 'dia' ? avant.tad : avant.pouls);
    Widget bouton(String t, int delta, String aria) => Semantics(
          button: true,
          label: '$aria · ${context.tr('sa_${c.cle}')}',
          child: Material(
            color: Wt.violetClair,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pas(c, delta),
              child: SizedBox(width: 58, height: 58, child: Center(child: Text(t, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Wt.violetFonce)))),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${c.emoji} ${context.tr('sa_${c.cle}')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (valAvant != null) Text(context.tr('sa_avant', {'v': valAvant}), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Wt.blanc, borderRadius: BorderRadius.circular(20), border: Border.all(color: bord, width: 3)),
        child: Row(children: [
          bouton('−', -1, context.tr('diminuer')),
          Expanded(
            child: TextField(
              controller: c.ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
            ),
          ),
          Text(c.cle == 'pul' ? 'bpm' : 'mmHg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris)),
          const SizedBox(width: 8),
          bouton('+', 1, context.tr('augmenter')),
        ]),
      ),
      if (msg != null) ...[
        const SizedBox(height: 6),
        Encadre(err ? '⚠️' : '⏳', msg.$2, fond: err ? Wt.rougeClair : Wt.jaune, encre: err ? Wt.rougeTexte : Wt.jauneTexte),
      ],
      const SizedBox(height: 14),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _messages();
    final nbErr = msgs.values.where((m) => m.$1 == 'err').length;
    final ordreFaux = msgs['dia']?.$2 == trL('err_ordre');
    final numero = _lectures.length + 1;
    final dernier = numero >= _voulues;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          EnTete(context.tr(_crise ? 'sa_titre_crise' : 'sa_titre'), retour: true),
          if (!_crise) ...[
            Text(context.tr('sa_n', {'n': numero}), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Container(height: 8, decoration: BoxDecoration(color: Wt.violet, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 8, decoration: BoxDecoration(color: numero >= 2 ? Wt.violet : const Color(0xFFD9D6EE), borderRadius: BorderRadius.circular(4)))),
            ]),
            const SizedBox(height: 12),
          ],
          if (_lectures.isNotEmpty) ...[
            Encadre('✅', context.tr('sa_ok1_court', {'v': '${_lectures.first.$1}/${_lectures.first.$2}'}), fond: Wt.vertClair, encre: Wt.vertTexte),
            const SizedBox(height: 12),
          ],
          _champ(_champs[0], msgs['sys']),
          _champ(_champs[1], msgs['dia']),
          if (ordreFaux)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OutlinedButton.icon(onPressed: _inverser, icon: const Icon(Icons.swap_vert), label: Text(context.tr('sa_inverser'))),
            ),
          _champ(_champs[2], msgs['pul']),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: nbErr == 0 ? _valider : null,
            child: Text(nbErr > 0 ? context.tr('sa_corriger') : (dernier ? context.tr('sa_voir') : context.tr('sa_enreg', {'n': numero}))),
          ),
        ]),
      ),
    );
  }
}
