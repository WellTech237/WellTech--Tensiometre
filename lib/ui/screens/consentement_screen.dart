import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'bienvenue_screen.dart';
import 'connexion_cloud_screen.dart';
import 'inscription_screen.dart';

/// Étape 2 sur 5 : consentement (texte à faire défiler + cases à cocher).
class ConsentementScreen extends StatefulWidget {
  final bool versConnexion;
  const ConsentementScreen({super.key, this.versConnexion = false});
  @override
  State<ConsentementScreen> createState() => _ConsentementScreenState();
}

class _ConsentementScreenState extends State<ConsentementScreen> {
  static const _sections = [('📋', 'cs_s1'), ('📍', 'cs_s2'), ('👁️', 'cs_s3'), ('✋', 'cs_s4'), ('⚖️', 'cs_s5'), ('ℹ️', 'cs_s6')];
  final _defil = ScrollController();
  double _lu = 0;
  bool _sante = false, _cloud = true, _partage = true;

  @override
  void initState() {
    super.initState();
    _defil.addListener(() {
      final p = _defil.position;
      final v = p.maxScrollExtent <= 0 ? 1.0 : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
      if (v > _lu) setState(() => _lu = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defil.hasClients && _defil.position.maxScrollExtent <= 0) setState(() => _lu = 1);
    });
  }

  @override
  void dispose() {
    _defil.dispose();
    super.dispose();
  }

  String _texteComplet() => _sections.map((s) => '${trL('${s.$2}_t')}. ${trL(s.$2)}').join(' ');

  Future<void> _accepter() async {
    await AuthService.instance.enregistrerConsentement(cloud: _cloud, notifications: true, partage: _partage);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => widget.versConnexion ? const ConnexionCloudScreen() : const InscriptionScreen()),
      (_) => false,
    );
  }

  Widget _case(String titre, String sous, bool v, ValueChanged<bool> onChanged) => InkWell(
        onTap: () => onChanged(!v),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 40, height: 40, child: Checkbox(value: v, onChanged: (x) => onChanged(x ?? false))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.35)),
                Text(sous, style: const TextStyle(fontSize: 14, color: Wt.gris, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          children: [
            Etapes(n: 2, total: 5, libelle: context.tr('cs_etape')),
            const SizedBox(height: 14),
            EnTete(context.tr('cs_titre'), retour: Navigator.of(context).canPop(), actions: [BoutonEcouter(texte: _texteComplet)]),
            Row(children: [
              Expanded(child: Text(context.tr('cs_lire'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris))),
              Text(context.tr('cs_lu', {'p': (_lu * 100).round()}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _lu, minHeight: 7, color: Wt.violet, backgroundColor: const Color(0xFFD9D6EE))),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: Container(
                decoration: BoxDecoration(color: Wt.blanc, borderRadius: BorderRadius.circular(22)),
                child: Scrollbar(
                  controller: _defil,
                  thumbVisibility: true,
                  child: ListView(controller: _defil, padding: const EdgeInsets.all(18), children: [
                    for (final s in _sections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Emo(s.$1, taille: 20), const SizedBox(width: 10), Expanded(child: Text(context.tr('${s.$2}_t'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))]),
                          const SizedBox(height: 4),
                          Text(context.tr(s.$2), style: const TextStyle(fontSize: 16, height: 1.55, color: Color(0xFF26303D))),
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _case(context.tr('cs_c1'), context.tr('cs_c1s'), _sante, (v) => setState(() => _sante = v)),
            _case(context.tr('cs_c2'), context.tr('cs_c2s'), _cloud, (v) => setState(() => _cloud = v)),
            _case(context.tr('cs_c3'), context.tr('cs_c3s'), _partage, (v) => setState(() => _partage = v)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _sante ? _accepter : null, child: Text(context.tr(_sante ? 'cs_accepter' : 'cs_bloque'))),
            TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BienvenueScreen()), (_) => false),
              child: Text(context.tr('cs_refuser')),
            ),
          ],
        ),
      ),
    );
  }
}
