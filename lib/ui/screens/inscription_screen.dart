import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'connexion_cloud_screen.dart';
import 'securite_screen.dart';

/// Étape 3 sur 5 : compte en ligne (recommandé) ou sur ce téléphone seulement.
/// Hors ligne, le compte en ligne sera créé au retour du réseau.
class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});
  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _enLigne = true;
  bool _voir = false;
  String? _erreurEmail;

  @override
  void initState() {
    super.initState();
    _mdp.addListener(() => setState(() {}));
  }

  List<(bool, String)> _regles(BuildContext context) {
    final m = _mdp.text;
    return [
      (m.length >= 8, context.tr('in_r1')),
      (m.contains(RegExp(r'\d')), context.tr('in_r2')),
      (m.contains(RegExp(r'[A-Z]')), context.tr('in_r3')),
    ];
  }

  void _continuer() {
    String email, mdp;
    if (_enLigne) {
      email = _email.text.trim();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        setState(() => _erreurEmail = context.tr('in_err_email'));
        return;
      }
      mdp = _mdp.text;
    } else {
      // Compte sur le téléphone seulement : identifiants internes aléatoires.
      final r = Random.secure();
      email = 'local';
      mdp = List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SecuriteScreen(email: email, motDePasse: mdp)));
  }

  Widget _mode(bool enLigne, String emoji, String titre, String sous, {String? badge}) {
    final actif = _enLigne == enLigne;
    return Semantics(
      selected: actif,
      button: true,
      child: Material(
        color: Wt.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: actif ? Wt.violet : Wt.bordure, width: 3)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _enLigne = enLigne),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Emo(emoji, taille: 24, boite: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(sous, style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600, height: 1.4)),
                  if (badge != null) ...[const SizedBox(height: 4), Text('✓ $badge', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.vertTexte))],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regles = _regles(context);
    final ok = !_enLigne || regles.every((r) => r.$1);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AppState.instance,
          builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
            Etapes(n: 3, total: 5, libelle: context.tr('in_etape')),
            const SizedBox(height: 14),
            EnTete(context.tr('in_titre'), retour: Navigator.of(context).canPop()),
            Text(context.tr('in_question'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _mode(true, '☁️', context.tr('in_m1'), context.tr('in_m1s'), badge: context.tr('in_recommande')),
            const SizedBox(height: 12),
            _mode(false, '📱', context.tr('in_m2'), context.tr('in_m2s')),
            if (_enLigne) ...[
              const SizedBox(height: 18),
              Text(context.tr('in_courriel'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(errorText: _erreurEmail),
                onChanged: (_) => setState(() => _erreurEmail = null),
              ),
              const SizedBox(height: 14),
              Text(context.tr('in_mdp'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              TextField(
                controller: _mdp,
                obscureText: !_voir,
                autocorrect: false,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: context.tr(_voir ? 'in_cacher' : 'in_voir'),
                    icon: Icon(_voir ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Wt.violetFonce),
                    onPressed: () => setState(() => _voir = !_voir),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final r in regles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${r.$1 ? '✓' : '○'} ${r.$2}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: r.$1 ? Wt.vertTexte : Wt.gris)),
                ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Emo('📶', taille: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr('in_hors_ligne'), style: const TextStyle(fontSize: 15, color: Wt.gris, height: 1.45))),
              ]),
            ],
            const SizedBox(height: 22),
            FilledButton(onPressed: ok ? _continuer : null, child: Text(context.tr(_enLigne ? 'in_creer' : 'in_local'))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnexionCloudScreen())),
              child: Text(context.tr('in_deja')),
            ),
          ]),
        ),
      ),
    );
  }
}
