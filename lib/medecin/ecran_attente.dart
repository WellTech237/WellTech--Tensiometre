import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import 'depot.dart';
import 'ecran_connexion.dart';
import 'routage.dart';
import 'ui_medecin.dart';

/// Écran du médecin dont la demande n'est pas encore validée, ou a été
/// refusée (avec le motif et la possibilité de corriger puis de renvoyer).
class EcranAttente extends StatefulWidget {
  const EcranAttente({super.key});
  @override
  State<EcranAttente> createState() => _EcranAttenteState();
}

class _EcranAttenteState extends State<EcranAttente> {
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _numero = TextEditingController();
  bool _enCours = false;
  String? _message;
  // Décision de l'administrateur en direct : le portail s'ouvre tout seul
  // dès que le compte est validé (ou affiche le refus et son motif).
  StreamSubscription<String>? _statut;
  String? _statutConnu;

  @override
  void initState() {
    super.initState();
    final m = Depot.instance.medecin;
    _nom.text = m?.nom ?? '';
    _tel.text = m?.telephone ?? '';
    _numero.text = m?.numeroOrdre ?? '';
    _statut = Depot.instance.statutDuCompte().listen((st) {
      final avant = _statutConnu;
      _statutConnu = st;
      if (avant != null && st != avant && (st == 'valide' || st == 'refuse') && mounted && !_enCours) _verifier();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _statut?.cancel();
    super.dispose();
  }

  Future<void> _verifier() async {
    setState(() {
      _enCours = true;
      _message = null;
    });
    final (acces, err) = await Depot.instance.chargerSession();
    if (!mounted) return;
    if (acces == Acces.medecin || acces == Acces.admin) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => ecranPour(acces!)), (_) => false);
      return;
    }
    if (acces == null) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const EcranConnexion()), (_) => false);
      return;
    }
    setState(() {
      _enCours = false;
      _message = err ?? (acces == Acces.refuse ? null : 'att_toujours');
    });
  }

  Future<void> _renvoyer() async {
    setState(() => _enCours = true);
    final e = await Depot.instance.renvoyerDemande(nom: _nom.text, telephone: _tel.text, numeroOrdre: _numero.text);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _message = e ?? 'att_renvoyee';
    });
  }

  Future<void> _deconnecter() async {
    await Depot.instance.deconnecter();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const EcranConnexion()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    context.enAnglais;
    final m = Depot.instance.medecin;
    final refuse = m?.refuse ?? false;
    return Scaffold(
      backgroundColor: Wt.fond,
      appBar: BarreHaut(onDeconnexion: _deconnecter),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CarteM(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text(refuse ? '📝' : '⏳', style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                Text(context.tr(refuse ? 'att_refuse_titre' : 'att_titre'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(context.tr(refuse ? 'att_refuse_sous' : 'att_sous'), style: const TextStyle(fontSize: 16, height: 1.5)),
                if (refuse && (m?.motif ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Bandeau('${context.tr('att_motif')} : ${m!.motif}', fond: Wt.jaune, couleur: Wt.jauneTexte),
                ],
                const SizedBox(height: 18),
                if (refuse) ...[
                  TextField(controller: _nom, decoration: InputDecoration(labelText: context.tr('ins_nom'))),
                  const SizedBox(height: 10),
                  TextField(controller: _tel, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('ins_tel'))),
                  const SizedBox(height: 10),
                  TextField(controller: _numero, decoration: InputDecoration(labelText: context.tr('ins_numero'))),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: _enCours ? null : _renvoyer, child: Text(context.tr('att_renvoyer'))),
                ] else ...[
                  Etiquette(context.tr('att_resume')),
                  _ligne(context.tr('ins_nom'), m?.nom ?? '—'),
                  _ligne(context.tr('md_courriel'), m?.email ?? '—'),
                  _ligne(context.tr('ins_tel'), m?.telephone ?? '—'),
                  _ligne(context.tr('ins_numero'), m?.numeroOrdre ?? '—'),
                  if (m?.demandeLe != null) _ligne(context.tr('att_envoyee'), dateHeure(m!.demandeLe!)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _enCours ? null : _verifier,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('att_verifier')),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Bandeau(context.tr(_message!), fond: Wt.violetClair, couleur: Wt.violetTexte),
                ],
                const SizedBox(height: 16),
                Text('ℹ️ ${context.tr('att_aide')}', style: const TextStyle(fontSize: 13, color: Wt.gris, height: 1.45)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ligne(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Wt.bordure))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 170, child: Text(k, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
      );
}
