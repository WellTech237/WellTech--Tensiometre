import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'aide_screen.dart';
import 'consentement_screen.dart';

/// Étape 1 sur 5 : choix de la langue (les deux langues sont visibles).
class BienvenueScreen extends StatelessWidget {
  const BienvenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final en = context.enAnglais;
    Widget carte(String code, String nom, String pays, bool actif) => Semantics(
          button: true,
          selected: actif,
          child: Material(
            color: Wt.blanc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: actif ? Wt.violet : const Color(0xFFD9D6EE), width: 3)),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => AppState.instance.changerLangue(code.toLowerCase()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Wt.violetClair, borderRadius: BorderRadius.circular(14)),
                    child: Text(code, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nom, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(pays, style: const TextStyle(fontSize: 14, color: Wt.gris, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Icon(actif ? Icons.check_circle : Icons.circle_outlined, color: actif ? Wt.violet : const Color(0xFFD9D6EE), size: 30),
                ]),
              ),
            ),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
          Row(children: [
            Expanded(child: Etapes(n: 1, total: 5, libelle: context.tr('bv_etape'))),
            const SizedBox(width: 12),
            BoutonRond(
              icone: const Icon(Icons.help_outline, color: Wt.violet),
              libelle: context.tr('aide'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AideScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          const Logo(taille: 56, avecNom: false),
          const SizedBox(height: 14),
          Text(context.tr('bv_titre'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 8),
          Text(context.tr('bv_sous'), style: const TextStyle(fontSize: 17, color: Wt.gris, height: 1.5)),
          const SizedBox(height: 22),
          Text.rich(TextSpan(children: [
            TextSpan(text: context.tr('bv_choisir'), style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' · ${context.tr('bv_choisir_autre')}', style: const TextStyle(color: Wt.gris, fontWeight: FontWeight.w600)),
          ]), style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 12),
          carte('FR', 'Français', 'Canada · France · Cameroun', !en),
          const SizedBox(height: 12),
          carte('EN', 'English', 'Canada · Cameroon · international', en),
          const SizedBox(height: 22),
          for (final b in [('✍️', 'bv_b1'), ('💬', 'bv_b2'), ('🚑', 'bv_b3')])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Emo(b.$1, taille: 22, boite: 44),
                const SizedBox(width: 14),
                Expanded(child: Text(context.tr(b.$2), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              ]),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsentementScreen())),
            child: Text(context.tr('bv_continuer')),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsentementScreen(versConnexion: true))),
            child: Text(context.tr('bv_compte')),
          ),
        ]),
      ),
    );
  }
}
