import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Messages avec le médecin. Les messages sont gardés sur le téléphone ;
/// ils seront transmis au médecin quand l'espace médecin sera en service.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _ctrl = TextEditingController();

  Future<void> _envoyer() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    await AppState.instance.envoyerMessage(t);
    _ctrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rapides = [context.tr('me_r1'), context.tr('me_r2'), context.tr('me_r3')];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            // Se redessine après chaque synchronisation : « en attente » devient
            // « envoyé » et les réponses du médecin apparaissent.
            child: ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) => FutureBuilder<List<Message>>(
              future: AppState.instance.messages(),
              builder: (context, snap) {
                final msgs = snap.data ?? const <Message>[];
                return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), children: [
                  EnTete(context.tr('me_titre'), retour: true),
                  Row(children: [
                    const Emo('🩺', taille: 26, boite: 52, fond: Wt.violetClair),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.tr('me_delai'), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600, height: 1.4))),
                  ]),
                  const SizedBox(height: 12),
                  Encadre('ℹ️', context.tr('me_info')),
                  const SizedBox(height: 12),
                  for (final m in msgs)
                    Align(
                      alignment: m.deMoi ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: m.deMoi ? Wt.violet : Wt.blanc,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(m.deMoi ? 20 : 6),
                            bottomRight: Radius.circular(m.deMoi ? 6 : 20),
                          ),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.texte, style: TextStyle(fontSize: 17, height: 1.45, color: m.deMoi ? Wt.blanc : Wt.encre)),
                          const SizedBox(height: 4),
                          Text(
                            '${dateHeure(m.date)}${m.deMoi ? ' · ${context.tr(m.syncStatus == 'synced' ? 'me_envoye' : 'me_attente')}' : ''}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.deMoi ? const Color(0xFFDCD8FF) : Wt.gris),
                          ),
                        ]),
                      ),
                    ),
                ]);
              },
            ),
            ),
          ),
          Container(
            color: Wt.fond,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('me_rapides'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in rapides)
                  ActionChip(
                    label: Text(r, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
                    backgroundColor: Wt.blanc,
                    side: const BorderSide(color: Wt.violet, width: 2),
                    shape: const StadiumBorder(),
                    onPressed: () => setState(() => _ctrl.text = r),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 17),
                    decoration: InputDecoration(hintText: context.tr('me_ecrire')),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 58)), onPressed: _envoyer, child: Text(context.tr('me_envoyer'))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
