import 'package:flutter/material.dart';

import '../../core/risque.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Mes alertes : comment WellTech décide (4 niveaux) + historique.
class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});
  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> {
  bool _nonLues = false;

  Future<void> _lire(AlerteEnregistree a) async {
    await AppState.instance.marquerAlerteLue(a.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final e = AppState.instance;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<AlerteEnregistree>>(
          future: e.db.alertes(limite: 60),
          builder: (context, snap) {
            final toutes = snap.data ?? const <AlerteEnregistree>[];
            final liste = _nonLues ? toutes.where((a) => !a.lue).toList() : toutes;
            return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
              EnTete(context.tr('at_titre'), retour: true),
              Carte(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('at_comment'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris)),
                  const SizedBox(height: 6),
                  Text(context.tr('at_exp'), style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 10),
                  for (var n = 1; n <= 4; n++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 140,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: couleursNiveau(n).fond, borderRadius: BorderRadius.circular(12)),
                          child: Text('${emojisNiveau[n - 1]} ${trL('niveau_$n')}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: couleursNiveau(n).texte)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(context.tr('at_n$n'), style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF26303D)))),
                      ]),
                    ),
                  Encadre('🛡️', '${context.tr('at_profil', {'r': e.risque.libelle})} ${e.risque.effet} ${context.tr('at_autre')}'),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text(context.tr('at_historique'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris))),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [ButtonSegment(value: false, label: Text(context.tr('at_toutes'))), ButtonSegment(value: true, label: Text(context.tr('at_non_lues')))],
                  selected: {_nonLues},
                  onSelectionChanged: (s) => setState(() => _nonLues = s.first),
                ),
              ]),
              const SizedBox(height: 10),
              if (liste.isEmpty) Carte(child: Text(context.tr('at_vide'), style: const TextStyle(fontSize: 17))),
              for (final a in liste)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Wt.blanc,
                      borderRadius: BorderRadius.circular(20),
                      border: Border(left: BorderSide(color: couleursNiveau(a.niveau).plein, width: 6)),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(children: [
                      Emo(emojisNiveau[a.niveau - 1], taille: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          Text('${a.detail}\n${dateHeure(a.date)}', style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600, height: 1.4)),
                        ]),
                      ),
                      if (!a.lue)
                        IconButton(
                          tooltip: context.tr('at_lue'),
                          style: IconButton.styleFrom(backgroundColor: Wt.violetClair, minimumSize: const Size(48, 48)),
                          onPressed: () => _lire(a),
                          icon: const Icon(Icons.check, color: Wt.violetFonce),
                        ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
