import 'package:flutter/material.dart';

import '../../core/controle.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'messages_screen.dart';
import 'profil_screen.dart';

/// Mon traitement : plan du médecin, prise du jour (avec l'heure réelle),
/// semaine. La patiente ne change jamais la dose elle-même.
class TraitementScreen extends StatefulWidget {
  const TraitementScreen({super.key});
  @override
  State<TraitementScreen> createState() => _TraitementScreenState();
}

class _TraitementScreenState extends State<TraitementScreen> {
  TimeOfDay? _heure;

  String _dose(double d) => '${nombre(d, d % 1 == 0 ? 0 : 1)} mg';

  Future<void> _choisirHeure() async {
    final t = await showTimePicker(context: context, initialTime: _heure ?? TimeOfDay.now());
    if (t != null) setState(() => _heure = t);
  }

  @override
  Widget build(BuildContext context) {
    final e = AppState.instance;
    final plan = e.plan;
    return ListenableBuilder(
      listenable: e,
      builder: (context, _) => FutureBuilder<List<Prise>>(
      future: e.prisesSemaine(),
      builder: (context, snap) {
        final prises = snap.data ?? const <Prise>[];
        final auj = AppState.aujourdhui();
        Prise? duJour;
        for (final p in prises) {
          if (p.jour == auj) duJour = p;
        }
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          EnTete(context.tr('tr_titre')),
          if (plan == null)
            Carte(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Emo('💊', taille: 32),
                const SizedBox(height: 8),
                Text(context.tr('tr_aucun'), style: const TextStyle(fontSize: 17, height: 1.5)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilScreen())),
                  child: Text(context.tr('tr_ajouter_profil')),
                ),
              ]),
            )
          else ...[
            Carte(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('📋 ${context.tr('tr_plan')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris))),
                  if (plan.modifiePar != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Wt.violetClair, borderRadius: BorderRadius.circular(999)),
                      child: Text(context.tr('tr_nouveau'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.violetTexte)),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Emo('💊', taille: 30, boite: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${plan.medicament} ${_dose(plan.doseMg)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(context.tr('tr_quand', {'h': heureTexte(plan.heure, plan.minute)}), style: const TextStyle(fontSize: 17, color: Wt.gris, fontWeight: FontWeight.w700)),
                      Text(
                        AppState.instance.rappelMedic
                            ? context.tr(AppState.instance.relanceMedic ? 'tr_rappel_relance' : 'tr_rappel', {'h': heureTexte(plan.heure, plan.minute)})
                            : context.tr('tr_rappel_off'),
                        style: const TextStyle(fontSize: 15, color: Wt.gris),
                      ),
                    ]),
                  ),
                ]),
                if (plan.modifiePar != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr('tr_modifie', {'m': plan.modifiePar, 'd': plan.dateModif == null ? '' : dateCourte(plan.dateModif!)}) +
                        (plan.ancienneDoseMg == null ? '' : ' · ${context.tr('tr_avant', {'d': _dose(plan.ancienneDoseMg!)})}'),
                    style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Encadre('🩺', context.tr('tr_pas_toucher'), fond: Wt.jaune, encre: Wt.jauneTexte),
              ]),
            ),
            const SizedBox(height: 12),
            Carte(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('📅 ${context.tr('tr_aujourdhui')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${plan.medicament} ${_dose(plan.doseMg)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(
                        duJour == null
                            ? context.tr('tr_a_prendre', {'h': heureTexte(plan.heure, plan.minute)})
                            : duJour.prise
                                ? context.tr('tr_pris', {'h': heureDe(duJour.heure!)})
                                : context.tr('tr_oublie'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: duJour == null ? const Color(0xFF7A2E00) : (duJour.prise ? Wt.vertTexte : Wt.rougeTexte),
                        ),
                      ),
                    ]),
                  ),
                  if (duJour?.prise ?? false) const Emo('✅', taille: 34),
                ]),
                const SizedBox(height: 12),
                if (duJour == null) ...[
                  Row(children: [
                    Expanded(child: Text(context.tr('tr_heure_prise'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: _choisirHeure,
                      icon: const Icon(Icons.schedule),
                      label: Text(_heure == null ? context.tr('tr_maintenant') : heureTexte(_heure!.hour, _heure!.minute)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () {
                      final n = DateTime.now();
                      final h = _heure == null ? n : DateTime(n.year, n.month, n.day, _heure!.hour, _heure!.minute);
                      e.noterPrise(h);
                    },
                    icon: const Icon(Icons.check),
                    label: Text(context.tr('tr_jai_pris')),
                  ),
                  TextButton(onPressed: e.noterOubli, child: Text(context.tr('tr_oubli'))),
                ] else ...[
                  if (!duJour.prise) Encadre('⚠️', context.tr('tr_oubli_msg'), fond: Wt.jaune, encre: Wt.jauneTexte),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: e.annulerPriseDuJour,
                      icon: const Icon(Icons.undo),
                      label: Text(context.tr('annuler')),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Carte(child: _semaine(context, prises)),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            icon: const Emo('💬', taille: 20),
            label: Text(context.tr('tr_ecrire')),
          ),
        ]);
      },
    ),
    );
  }

  Widget _semaine(BuildContext context, List<Prise> prises) {
    final auj = AppState.aujourdhui();
    final jours = [for (var i = 6; i >= 0; i--) jourDecale(auj, -i)];
    final pris = prises.where((p) => p.prise).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('🗓️ ${context.tr('tr_semaine')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris))),
        Text(context.tr('tr_regularite', {'n': pris}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.vertTexte)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        for (final j in jours)
          Expanded(
            child: Builder(builder: (context) {
              Prise? p;
              for (final x in prises) {
                if (x.jour == j) p = x;
              }
              final (ic, fond, encre) = p == null
                  ? ('·', Wt.fond, Wt.gris)
                  : p.prise
                      ? ('✓', Wt.vertClair, Wt.vertTexte)
                      : ('×', Wt.rougeClair, Wt.rougeTexte);
              return Column(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12)),
                  child: Text(ic, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: encre)),
                ),
                const SizedBox(height: 4),
                Text(jourCourt(j), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris)),
              ]);
            }),
          ),
      ]),
    ]);
  }
}
