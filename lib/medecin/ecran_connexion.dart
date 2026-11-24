import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import 'depot.dart';
import 'ecran_inscription.dart';
import 'routage.dart';
import 'ui_medecin.dart';

/// Connexion du médecin (courriel + mot de passe). Seuls les comptes inscrits
/// dans « medecins » par l'administrateur peuvent entrer.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});
  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _cache = true;
  bool _enCours = false;
  String? _erreur;
  String? _info;

  Future<void> _connecter() async {
    if (_email.text.trim().isEmpty || _mdp.text.isEmpty) {
      setState(() => _erreur = 'md_err_vide');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
      _info = null;
    });
    final (acces, e) = await Depot.instance.connecter(_email.text, _mdp.text);
    if (!mounted) return;
    if (acces != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ecranPour(acces)));
    } else {
      setState(() {
        _enCours = false;
        _erreur = e;
      });
    }
  }

  Future<void> _oublie() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _erreur = 'md_err_email_oubli');
      return;
    }
    try {
      await Depot.instance.motDePasseOublie(_email.text);
      setState(() {
        _erreur = null;
        _info = 'md_oubli_envoye';
      });
    } catch (_) {
      setState(() => _erreur = 'cl_err_email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wt.fond,
      body: SafeArea(
        child: Stack(children: [
          const Positioned(top: 16, right: 16, child: BoutonLangueM()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: CarteM(
                  padding: const EdgeInsets.all(28),
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Wt.violet, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.monitor_heart_outlined, color: Wt.blanc, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('WellTech', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            Text(context.tr('md_espace'), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      Text(context.tr('md_cx_titre'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(context.tr('md_cx_sous'), style: const TextStyle(fontSize: 15, color: Wt.gris, height: 1.4)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(labelText: context.tr('md_courriel')),
                        onSubmitted: (_) => _connecter(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mdp,
                        obscureText: _cache,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: context.tr('md_mdp'),
                          suffixIcon: IconButton(
                            tooltip: context.tr(_cache ? 'md_afficher' : 'md_masquer'),
                            onPressed: () => setState(() => _cache = !_cache),
                            icon: Icon(_cache ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        onSubmitted: (_) => _connecter(),
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 12),
                        Bandeau('⚠ ${context.tr(_erreur!)}'),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Bandeau('✓ ${context.tr(_info!)}', fond: Wt.vertClair, couleur: Wt.vertTexte),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _enCours ? null : _connecter,
                        child: _enCours
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Wt.blanc))
                            : Text(context.tr('md_connexion')),
                      ),
                      const SizedBox(height: 6),
                      TextButton(onPressed: _oublie, child: Text(context.tr('md_oubli'))),
                      const Divider(height: 28),
                      Text(context.tr('ins_pas_compte'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EcranInscription())),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(context.tr('ins_creer')),
                      ),
                      const SizedBox(height: 16),
                      Text('🔒 ${context.tr('md_cx_reserve')}', style: const TextStyle(fontSize: 14, color: Wt.gris, height: 1.4)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Affiché si la configuration web de Firebase manque ou échoue.
class EcranErreurConfig extends StatelessWidget {
  final String cle;
  const EcranErreurConfig({super.key, required this.cle});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Wt.fond,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CarteM(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('⚙️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(context.tr('md_config_titre'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(context.tr(cle), style: const TextStyle(fontSize: 16, height: 1.5)),
              ]),
            ),
          ),
        ),
      );
}
