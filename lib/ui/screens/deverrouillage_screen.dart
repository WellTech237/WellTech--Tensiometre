import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'accueil_shell.dart';
import 'connexion_cloud_screen.dart';
import 'profil_screen.dart';
import 'securite_screen.dart';
import 'urgence_screen.dart';

/// Déverrouillage : empreinte ou PIN, avec ou sans Internet.
/// Le bouton 911 est accessible sans code.
class DeverrouillageScreen extends StatefulWidget {
  const DeverrouillageScreen({super.key});
  @override
  State<DeverrouillageScreen> createState() => _DeverrouillageScreenState();
}

class _DeverrouillageScreenState extends State<DeverrouillageScreen> {
  String _pin = '';
  String? _message;
  bool _bio = false;
  bool _verif = false;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    final actif = await AuthService.instance.biometrieActivee() && await AuthService.instance.biometrieDisponible();
    if (!mounted) return;
    setState(() => _bio = actif);
    if (actif) _essayerBio();
  }

  Future<void> _essayerBio() async {
    if (await AuthService.instance.deverrouillerBiometrie()) _entrer();
  }

  Future<void> _touche(String t) async {
    if (_verif) return;
    setState(() {
      _message = null;
      if (t == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 6) {
        _pin += t;
      }
    });
    if (_pin.length < 6) return;
    setState(() => _verif = true);
    final err = await AuthService.instance.verifierPin(_pin);
    if (!mounted) return;
    setState(() {
      _verif = false;
      _message = err;
      _pin = '';
    });
    if (err == null) _entrer();
  }

  void _entrer() {
    final profilVide = AppState.instance.profil.prenom.isEmpty;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => profilVide ? const ProfilScreen(premiereFois: true) : const AccueilShell(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final etat = AppState.instance;
    final prenom = etat.profil.prenom;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
          Row(children: [
            Expanded(child: Align(alignment: Alignment.centerLeft, child: PastilleSync(etat.enLigne))),
            const BoutonLangue(),
          ]),
          const SizedBox(height: 20),
          const Center(child: Emo('👋', taille: 44)),
          const SizedBox(height: 8),
          Text(prenom.isEmpty ? context.tr('dv_bonjour_vide') : context.tr('dv_bonjour', {'p': prenom}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.tr('dv_sous'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: Wt.gris)),
          const SizedBox(height: 18),
          PointsPin(_pin.length),
          const SizedBox(height: 10),
          if (_message != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Wt.rougeClair, borderRadius: BorderRadius.circular(12)),
              child: Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Wt.rougeTexte, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          if (_verif) const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 10),
          PaveNumerique(onTouche: _touche),
          if (_bio) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: _essayerBio, icon: const Emo('👆', taille: 20), label: Text(context.tr('dv_bio'))),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnexionCloudScreen())),
            child: Text(context.tr('dv_oubli'), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 14),
          Material(
            color: Wt.rougeClair,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UrgenceScreen(sansDonnees: true))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Emo('🚑', taille: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('dv_urgence'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Wt.rougeTexte)),
                      Text(context.tr('dv_urgence_s'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Wt.rougeTexte)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
