import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'aide_screen.dart';
import 'saisie_screen.dart';

/// Avant de mesurer : liste à cocher avec icônes + repos de 5 minutes.
class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key});
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  static const _items = [('☕', 'pp_i1'), ('🚻', 'pp_i2'), ('🪑', 'pp_i3'), ('💪', 'pp_i4'), ('🩹', 'pp_i5'), ('🤫', 'pp_i6')];
  final _ok = <int>{};
  int _reste = 300;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _demarrer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_reste <= 0) {
        t.cancel();
      } else {
        setState(() => _reste--);
      }
    });
    setState(() {});
  }

  String _consignes() => '${trL('pp_voix')} ${_items.map((i) => trL(i.$2)).join('. ')}.';

  @override
  Widget build(BuildContext context) {
    final mm = (_reste ~/ 60).toString();
    final ss = (_reste % 60).toString().padLeft(2, '0');
    final enCours = _timer != null && _reste > 0;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          EnTete(context.tr('pp_titre'), retour: true, actions: [BoutonEcouter(texte: _consignes)]),
          Text(context.tr('pp_sous'), style: const TextStyle(fontSize: 17, color: Wt.gris, height: 1.45)),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AideScreen(ouvert: 1))),
            child: Text('▶ ${context.tr('pp_video')}'),
          ),
          Carte(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < _items.length; i++) ...[
                InkWell(
                  onTap: () => setState(() => _ok.contains(i) ? _ok.remove(i) : _ok.add(i)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 66),
                    child: Row(children: [
                      Emo(_items[i].$1, taille: 24),
                      const SizedBox(width: 14),
                      Expanded(child: Text(context.tr(_items[i].$2), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35))),
                      Checkbox(value: _ok.contains(i), onChanged: (v) => setState(() => v == true ? _ok.add(i) : _ok.remove(i))),
                    ]),
                  ),
                ),
                if (i < _items.length - 1) const Divider(height: 1),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Text(context.tr('pp_prets', {'n': _ok.length}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
          const SizedBox(height: 12),
          Carte(
            child: Row(children: [
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(value: 1 - _reste / 300, strokeWidth: 7, color: Wt.vert, backgroundColor: const Color(0xFFD9D6EE)),
                  ),
                  Text('$mm:$ss', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🧘 ${context.tr('pp_repos')}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _timer == null ? _demarrer : null,
                    child: Text(context.tr(_reste <= 0 ? 'pp_fini' : (enCours ? 'pp_en_cours' : 'pp_demarrer'))),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SaisieScreen())),
            child: Text(context.tr('pp_commencer')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SaisieScreen())),
            child: Text(context.tr('pp_passer')),
          ),
        ]),
      ),
    );
  }
}
