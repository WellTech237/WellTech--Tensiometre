import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/notifications.dart';
import '../../services/voix.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'preparation_screen.dart';

/// Rappel de mesure (affiché quand la notification est touchée).
class AlarmeScreen extends StatefulWidget {
  const AlarmeScreen({super.key});
  @override
  State<AlarmeScreen> createState() => _AlarmeScreenState();
}

class _AlarmeScreenState extends State<AlarmeScreen> {
  bool _reporte = false;

  @override
  void initState() {
    super.initState();
    Voix.instance.lire(trL('al_voix'));
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final soir = now.hour >= 12;
    const blancDoux = Color(0xFFC5CCD8);
    return Scaffold(
      backgroundColor: Wt.encre,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
          Row(children: [
            BoutonEcouter(texte: () => trL('al_voix'), fond: const Color(0xFF24314B), encre: Wt.blanc),
            const Spacer(),
            const BoutonLangue(),
          ]),
          const SizedBox(height: 30),
          const Center(child: Emo('⏰', taille: 64)),
          const SizedBox(height: 14),
          Text(heureTexte(now.hour, now.minute), textAlign: TextAlign.center, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: Wt.blanc, letterSpacing: -2)),
          const SizedBox(height: 8),
          Text(context.tr(soir ? 'al_titre_soir' : 'al_titre_matin'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Wt.blanc, height: 1.25)),
          const SizedBox(height: 8),
          Text(context.tr('al_sous'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: blancDoux, height: 1.5)),
          const SizedBox(height: 40),
          if (_reporte)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(context.tr('al_reporte'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF7BE0B5))),
            ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PreparationScreen())),
            icon: const Icon(Icons.add),
            label: Text(context.tr('ac_mesurer')),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Wt.blanc, side: const BorderSide(color: Wt.blanc, width: 2)),
            onPressed: () async {
              await Notifications.instance.reporter(const Duration(minutes: 15));
              setState(() => _reporte = true);
            },
            child: Text(context.tr('al_reporter')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC9C3FF)),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.tr('al_deja')),
          ),
          const SizedBox(height: 6),
          Text(context.tr('al_note'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: blancDoux)),
          if (AppState.instance.derniere != null) const SizedBox.shrink(),
        ]),
      ),
    );
  }
}
