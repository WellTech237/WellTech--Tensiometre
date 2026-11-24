import 'package:flutter/material.dart';

import '../../core/classification.dart';
import '../../l10n.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Aide : questions fréquentes (icône + réponse courte), légende des couleurs.
class AideScreen extends StatefulWidget {
  final int ouvert;
  const AideScreen({super.key, this.ouvert = 2});
  @override
  State<AideScreen> createState() => _AideScreenState();
}

class _AideScreenState extends State<AideScreen> {
  late int _ouvert = widget.ouvert;
  String _filtre = '';

  static const _emojis = ['🩺', '🎨', '🔢', '📈', '🚑', '📶', '💊', '🔒', '👩‍⚕️', '📄', '🔄', '🔑'];

  @override
  Widget build(BuildContext context) {
    final questions = [
      for (var i = 1; i <= _emojis.length; i++) (i, _emojis[i - 1], context.tr('aq$i'), context.tr('ar$i')),
    ].where((q) => _filtre.isEmpty || '${q.$3} ${q.$4}'.toLowerCase().contains(_filtre.toLowerCase())).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          EnTete(context.tr('aide'), retour: true),
          TextField(
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('aide_chercher')),
            onChanged: (v) => setState(() => _filtre = v),
          ),
          const SizedBox(height: 14),
          Carte(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (final q in questions) ...[
                InkWell(
                  onTap: () => setState(() => _ouvert = _ouvert == q.$1 ? 0 : q.$1),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Row(children: [
                      Emo(q.$2, taille: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(q.$3, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                      Icon(_ouvert == q.$1 ? Icons.remove : Icons.add, color: Wt.violetFonce),
                    ]),
                  ),
                ),
                if (_ouvert == q.$1) ...[
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(q.$4, style: const TextStyle(fontSize: 16, height: 1.55, color: Color(0xFF26303D)))),
                  if (q.$1 == 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        for (final g in [(Grade.normale, '< 120 / < 80'), (Grade.elevee, '120–129 / < 80'), (Grade.grade1, '130–139 / 80–89'), (Grade.grade2, '≥ 140 / ≥ 90'), (Grade.grade3, '> 180 / > 120')])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: PuceGrade(g.$1))),
                              const SizedBox(width: 8),
                              Expanded(child: Text(g.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Wt.gris))),
                            ]),
                          ),
                      ]),
                    ),
                ],
                const Divider(height: 1),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Encadre('🚑', context.tr('aide_urgence'), fond: Wt.rougeClair, encre: Wt.rougeTexte),
        ]),
      ),
    );
  }
}
