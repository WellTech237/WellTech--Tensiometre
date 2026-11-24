import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import 'depot.dart';
import 'ecran_attente.dart';
import 'ui_medecin.dart';

/// Inscription d'un médecin : nom complet, courriel, téléphone, numéro
/// d'ordre et mot de passe choisi par lui. Le compte reste bloqué jusqu'à la
/// vérification par l'administrateur (registre public de l'Ordre).
class EcranInscription extends StatefulWidget {
  const EcranInscription({super.key});
  @override
  State<EcranInscription> createState() => _EcranInscriptionState();
}

class _EcranInscriptionState extends State<EcranInscription> {
  final _form = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _numero = TextEditingController();
  final _mdp = TextEditingController();
  final _mdp2 = TextEditingController();
  bool _atteste = false;
  bool _cache = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    for (final c in [_nom, _email, _tel, _numero, _mdp, _mdp2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _envoyer() async {
    setState(() => _erreur = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_atteste) {
      setState(() => _erreur = 'ins_err_atteste');
      return;
    }
    setState(() => _enCours = true);
    final e = await Depot.instance.inscrire(
      nom: _nom.text,
      email: _email.text,
      telephone: _tel.text,
      numeroOrdre: _numero.text,
      mdp: _mdp.text,
    );
    if (!mounted) return;
    if (e == null) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const EcranAttente()), (_) => false);
    } else {
      setState(() {
        _erreur = e;
        _enCours = false;
      });
    }
  }

  String? _requis(String? v, {int min = 2}) => (v == null || v.trim().length < min) ? trL('ins_err_requis') : null;

  @override
  Widget build(BuildContext context) {
    context.enAnglais;
    return Scaffold(
      backgroundColor: Wt.fond,
      body: SafeArea(
        child: Stack(children: [
          const Positioned(top: 16, right: 16, child: BoutonLangueM()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CarteM(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        IconButton(tooltip: context.tr('retour'), onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(context.tr('ins_titre'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                      ]),
                      const SizedBox(height: 8),
                      Text(context.tr('ins_sous'), style: const TextStyle(fontSize: 15, color: Wt.gris, height: 1.45)),
                      const SizedBox(height: 14),
                      _etapes(context),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nom,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(labelText: context.tr('ins_nom'), hintText: 'Dr Awa Mbarga'),
                        validator: (v) => _requis(v, min: 3),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(labelText: context.tr('md_courriel')),
                        validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? trL('cl_err_email') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tel,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: InputDecoration(labelText: context.tr('ins_tel'), hintText: '613 555 0123'),
                        validator: (v) => (v == null || v.replaceAll(RegExp(r'[^0-9]'), '').length < 7) ? trL('ins_err_tel') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _numero,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(labelText: context.tr('ins_numero'), helperText: context.tr('ins_numero_aide')),
                        validator: (v) => _requis(v, min: 2),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mdp,
                        obscureText: _cache,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: context.tr('md_mdp'),
                          helperText: context.tr('ins_mdp_aide'),
                          suffixIcon: IconButton(
                            tooltip: context.tr(_cache ? 'md_afficher' : 'md_masquer'),
                            onPressed: () => setState(() => _cache = !_cache),
                            icon: Icon(_cache ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? trL('ins_err_mdp') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mdp2,
                        obscureText: _cache,
                        decoration: InputDecoration(labelText: context.tr('ins_mdp2')),
                        validator: (v) => v != _mdp.text ? trL('ins_err_mdp2') : null,
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _atteste,
                        onChanged: (v) => setState(() => _atteste = v ?? false),
                        title: Text(context.tr('ins_atteste'), style: const TextStyle(fontSize: 15, height: 1.4)),
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 8),
                        Bandeau('⚠ ${context.tr(_erreur!)}'),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _enCours ? null : _envoyer,
                        child: _enCours
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Wt.blanc))
                            : Text(context.tr('ins_envoyer')),
                      ),
                      const SizedBox(height: 10),
                      Text('🔒 ${context.tr('ins_confidentialite')}', style: const TextStyle(fontSize: 13, color: Wt.gris, height: 1.4)),
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

  Widget _etapes(BuildContext context) {
    Widget etape(String n, String cle) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Wt.violetClair, shape: BoxShape.circle),
              child: Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr(cle), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4))),
          ]),
        );
    return CarteM(
      fond: Wt.fond,
      bordure: Wt.fond,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        etape('1', 'ins_e1'),
        etape('2', 'ins_e2'),
        etape('3', 'ins_e3'),
      ]),
    );
  }
}
