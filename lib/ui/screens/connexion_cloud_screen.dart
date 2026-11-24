import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/cloud.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'accueil_shell.dart';
import 'profil_screen.dart';

/// Connexion d'un compte existant sur un NOUVEAU téléphone (Internet requis :
/// les données sont dans le cloud). Ensuite, tout fonctionne hors ligne.
class ConnexionCloudScreen extends StatefulWidget {
  const ConnexionCloudScreen({super.key});
  @override
  State<ConnexionCloudScreen> createState() => _ConnexionCloudScreenState();
}

class _ConnexionCloudScreenState extends State<ConnexionCloudScreen> {
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _enCours = false;
  bool _voir = false;
  String? _erreur;

  Future<void> _connecter() async {
    String? err;
    if (!RegExp(r'^\d{6}$').hasMatch(_pin.text)) err = context.tr('cx_err_pin');
    if (_pin.text != _pin2.text) err = context.tr('se_differents');
    if (_email.text.trim().isEmpty || _mdp.text.isEmpty) err = context.tr('cx_err_vide');
    setState(() => _erreur = err);
    if (err != null) return;
    setState(() => _enCours = true);
    final (e, profil) = await Cloud.instance.connecterEtRecuperer(_email.text, _mdp.text);
    if (e != null && profil == null) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = e;
        });
      }
      return;
    }
    final auth = AuthService.instance;
    final bio = await auth.biometrieDisponible();
    await auth.creerCompteLocal(email: _email.text, motDePasse: _mdp.text, pin: _pin.text, biometrie: bio);
    await auth.marquerCloudActif();
    final etat = AppState.instance;
    if (profil != null) await etat.enregistrerProfil(profil, synchroniser: false);
    await etat.charger();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => etat.profil.prenom.isEmpty ? const ProfilScreen(premiereFois: true) : const AccueilShell()),
      (_) => false,
    );
  }

  Widget _libelle(String k) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(context.tr(k), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _pinChamp(TextEditingController c, String aide) => TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 4),
        decoration: InputDecoration(counterText: '', hintText: aide),
      );

  @override
  Widget build(BuildContext context) {
    final etat = AppState.instance;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: etat,
          builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
            EnTete(context.tr('cx_titre'), retour: true),
            Text(context.tr('cx_sous'), style: const TextStyle(fontSize: 17, color: Wt.gris, height: 1.45)),
            const SizedBox(height: 8),
            if (!etat.enLigne) Encadre('📶', context.tr('cx_reseau'), fond: Wt.jaune, encre: Wt.jauneTexte),
            _libelle('in_courriel'),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, style: const TextStyle(fontSize: 18)),
            _libelle('in_mdp'),
            TextField(
              controller: _mdp,
              obscureText: !_voir,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: context.tr(_voir ? 'in_cacher' : 'in_voir'),
                  icon: Icon(_voir ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Wt.violetFonce),
                  onPressed: () => setState(() => _voir = !_voir),
                ),
              ),
            ),
            _libelle('cx_pin'),
            Row(children: [
              Expanded(child: _pinChamp(_pin, context.tr('cx_pin1'))),
              const SizedBox(width: 10),
              Expanded(child: _pinChamp(_pin2, context.tr('cx_pin2'))),
            ]),
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Encadre('⚠️', _erreur!, fond: Wt.rougeClair, encre: Wt.rougeTexte),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_enCours || !etat.enLigne) ? null : _connecter,
              child: _enCours
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Wt.blanc))
                  : Text(context.tr(etat.enLigne ? 'cx_connecter' : 'cx_attente')),
            ),
          ]),
        ),
      ),
    );
  }
}
