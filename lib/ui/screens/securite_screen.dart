import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'profil_screen.dart';

/// Pavé numérique à grosses touches (PIN).
class PaveNumerique extends StatelessWidget {
  final ValueChanged<String> onTouche;
  const PaveNumerique({super.key, required this.onTouche});

  @override
  Widget build(BuildContext context) {
    const touches = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        for (final t in touches)
          if (t.isEmpty)
            const SizedBox.shrink()
          else
            Semantics(
              button: true,
              label: t == '⌫' ? context.tr('effacer') : t,
              child: Material(
                color: Wt.blanc,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onTouche(t),
                  child: Center(
                    child: t == '⌫'
                        ? const Icon(Icons.backspace_outlined, size: 26, color: Wt.encre)
                        : Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Points du PIN (●●○○○○).
class PointsPin extends StatelessWidget {
  final int remplis;
  final int total;
  const PointsPin(this.remplis, {super.key, this.total = 6});
  @override
  Widget build(BuildContext context) => Semantics(
        label: context.tr('pin_aria', {'n': remplis, 't': total}),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(shape: BoxShape.circle, color: i < remplis ? Wt.violet : Colors.transparent, border: Border.all(color: Wt.violet, width: 2)),
            ),
        ]),
      );
}

/// Étape 4 sur 5 : code PIN (6 chiffres, sert sans Internet) + empreinte.
class SecuriteScreen extends StatefulWidget {
  final String email;
  final String motDePasse;
  const SecuriteScreen({super.key, required this.email, required this.motDePasse});
  @override
  State<SecuriteScreen> createState() => _SecuriteScreenState();
}

class _SecuriteScreenState extends State<SecuriteScreen> {
  String _pin = '';
  String? _premier; // 1re saisie, en attente de confirmation
  String? _erreur;
  bool _bio = true;
  bool _bioDispo = false;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.biometrieDisponible().then((v) {
      if (mounted) setState(() => _bioDispo = v);
    });
  }

  void _touche(String t) {
    setState(() {
      _erreur = null;
      if (t == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 6) {
        _pin += t;
      }
    });
    if (_pin.length == 6) _pinComplet();
  }

  void _pinComplet() {
    if (_premier == null) {
      if (const ['123456', '000000', '111111', '654321', '123123'].contains(_pin)) {
        setState(() {
          _erreur = context.tr('se_trop_facile');
          _pin = '';
        });
        return;
      }
      setState(() {
        _premier = _pin;
        _pin = '';
      });
    } else if (_premier != _pin) {
      setState(() {
        _erreur = context.tr('se_differents');
        _premier = null;
        _pin = '';
      });
    } else {
      setState(() {});
    }
  }

  bool get _pret => _premier != null && _pin == _premier;

  Future<void> _continuer() async {
    setState(() => _enCours = true);
    final auth = AuthService.instance;
    if (widget.email == 'local') {
      await auth.enregistrerConsentement(cloud: false, notifications: true, partage: false);
    }
    await auth.creerCompteLocal(email: widget.email, motDePasse: widget.motDePasse, pin: _pin, biometrie: _bio && _bioDispo);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfilScreen(premiereFois: true)), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final consigne = _pret ? context.tr('se_ok') : (_premier == null ? context.tr('se_creer') : context.tr('se_confirmer'));
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
          Etapes(n: 4, total: 5, libelle: context.tr('se_etape')),
          const SizedBox(height: 14),
          EnTete(context.tr('se_titre'), retour: true),
          const Center(child: Emo('🔐', taille: 36)),
          const SizedBox(height: 8),
          Text(consigne, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.tr('se_pourquoi'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Wt.gris)),
          const SizedBox(height: 16),
          PointsPin(_pret ? 6 : _pin.length),
          const SizedBox(height: 10),
          Text(
            _erreur ?? context.tr('se_conseil'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _erreur != null ? Wt.rougeTexte : Wt.gris),
          ),
          const SizedBox(height: 14),
          if (!_pret) PaveNumerique(onTouche: _touche),
          if (_bioDispo) ...[
            const SizedBox(height: 14),
            Carte(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Emo('👆', taille: 24, boite: 44),
                title: Text(context.tr('se_bio'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                subtitle: Text(context.tr('se_bio_s'), style: const TextStyle(fontSize: 14, color: Wt.gris)),
                value: _bio,
                onChanged: (v) => setState(() => _bio = v),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _pret && !_enCours ? _continuer : null,
            child: _enCours
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Wt.blanc))
                : Text(context.tr(_pret ? 'continuer' : 'se_manque')),
          ),
        ]),
      ),
    );
  }
}
