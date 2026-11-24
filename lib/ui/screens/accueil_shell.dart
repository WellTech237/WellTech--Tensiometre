import 'package:flutter/material.dart';

import '../../core/classification.dart';
import '../../core/controle.dart';
import '../../data/database.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/voix.dart';
import '../../theme.dart';
import '../visite_guidee.dart';
import '../widgets.dart';
import 'alarme_screen.dart';
import 'messages_screen.dart';
import 'moi_screen.dart';
import 'preparation_screen.dart';
import 'suivi_screen.dart';
import 'traitement_screen.dart';

/// Coquille principale : la même barre de 5 onglets partout
/// (Accueil, Suivi, Mesurer, Traitement, Moi).
class AccueilShell extends StatefulWidget {
  const AccueilShell({super.key});

  /// Relance la visite guidée (bouton « Revoir la visite » de l'onglet Moi).
  static void revoirVisite() => _AccueilShellState._actif?._lancerVisite();

  @override
  State<AccueilShell> createState() => _AccueilShellState();
}

class _AccueilShellState extends State<AccueilShell> {
  static _AccueilShellState? _actif;
  int _onglet = 0;

  // Éléments présentés pendant la visite guidée.
  final _cleNav = GlobalKey();
  final _cleCarte = GlobalKey();
  final _cleMessages = GlobalKey();
  final _cleLangue = GlobalKey();

  @override
  void initState() {
    super.initState();
    _actif = this;
    // Rappel de médicament touché : ouvrir l'onglet Traitement.
    AppState.instance.ongletDemande.addListener(_ongletDemande);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ongletDemande());
    // Première fois sur l'accueil : visite guidée automatique (une seule fois).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vue = await BaseLocale.instance.lireReglage('visite_patiente_v2');
      if (vue != null || !mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) await _lancerVisite();
    });
  }

  @override
  void dispose() {
    AppState.instance.ongletDemande.removeListener(_ongletDemande);
    if (_actif == this) _actif = null;
    super.dispose();
  }

  void _ongletDemande() {
    final o = AppState.instance.ongletDemande.value;
    if (o == null || !mounted) return;
    AppState.instance.ongletDemande.value = null;
    setState(() => _onglet = o);
  }

  Future<void> _lancerVisite() async {
    if (_onglet != 0) setState(() => _onglet = 0);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await lancerVisite(context, [
      const EtapeVisite(emoji: '👋', titre: 'vgp_1_t', texte: 'vgp_1'),
      EtapeVisite(emoji: '🩺', titre: 'vgp_2_t', texte: 'vgp_2', zone: () => zonePart(_cleNav, 2, 5)),
      EtapeVisite.sur(_cleCarte, emoji: '📋', titre: 'vgp_3_t', texte: 'vgp_3'),
      EtapeVisite(emoji: '📈', titre: 'vgp_4_t', texte: 'vgp_4', zone: () => zonePart(_cleNav, 1, 5)),
      EtapeVisite(emoji: '💊', titre: 'vgp_5_t', texte: 'vgp_5', zone: () => zonePart(_cleNav, 3, 5)),
      EtapeVisite.sur(_cleMessages, emoji: '💬', titre: 'vgp_6_t', texte: 'vgp_6'),
      EtapeVisite(emoji: '👤', titre: 'vgp_7_t', texte: 'vgp_7', zone: () => zonePart(_cleNav, 4, 5)),
      EtapeVisite.sur(_cleLangue, emoji: '🌐', titre: 'vgp_8_t', texte: 'vgp_8'),
      const EtapeVisite(emoji: '🚨', titre: 'vgp_9_t', texte: 'vgp_9'),
    ]);
    await BaseLocale.instance.ecrireReglage('visite_patiente_v2', DateTime.now().toIso8601String());
  }

  void _choisir(int i) {
    if (i == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreparationScreen()));
      return;
    }
    setState(() => _onglet = i);
    // Onglet Suivi ouvert : les notes du médecin sont vues (la pastille part,
    // l'étiquette « Nouveau » reste affichée jusqu'à la prochaine ouverture).
    if (i == 1) AppState.instance.marquerNotesLues();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: IndexedStack(index: _onglet, children: [
            AccueilTab(
              versSuivi: () => _choisir(1),
              versTraitement: () => setState(() => _onglet = 3),
              cleCarte: _cleCarte,
              cleMessages: _cleMessages,
              cleLangue: _cleLangue,
            ),
            const SuiviScreen(),
            const SizedBox.shrink(),
            const TraitementScreen(),
            const MoiScreen(),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          key: _cleNav,
          selectedIndex: _onglet,
          backgroundColor: Wt.blanc,
          indicatorColor: Wt.violetClair,
          height: 76,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _choisir,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home, color: Wt.violetFonce), label: context.tr('nav_accueil')),
            NavigationDestination(
              icon: Badge(isLabelVisible: AppState.instance.notesNonLues > 0, label: Text('${AppState.instance.notesNonLues}'), child: const Icon(Icons.show_chart)),
              selectedIcon: const Icon(Icons.show_chart, color: Wt.violetFonce),
              label: context.tr('nav_suivi'),
            ),
            NavigationDestination(
              icon: Container(
                width: 48,
                height: 40,
                decoration: BoxDecoration(color: Wt.violet, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.add, color: Wt.blanc, size: 28),
              ),
              label: context.tr('nav_mesurer'),
            ),
            NavigationDestination(icon: const Icon(Icons.medication_outlined), selectedIcon: const Icon(Icons.medication, color: Wt.violetFonce), label: context.tr('nav_traitement')),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: AppState.instance.alertesNonLues > 0,
                label: Text('${AppState.instance.alertesNonLues}'),
                child: const Icon(Icons.person_outline),
              ),
              selectedIcon: const Icon(Icons.person, color: Wt.violetFonce),
              label: context.tr('nav_moi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accueil épuré : dernière mesure, prochain rappel, médicament, 4 valeurs.
class AccueilTab extends StatelessWidget {
  final VoidCallback versSuivi;
  final VoidCallback versTraitement;
  final GlobalKey? cleCarte;
  final GlobalKey? cleMessages;
  final GlobalKey? cleLangue;
  const AccueilTab({
    super.key,
    required this.versSuivi,
    required this.versTraitement,
    this.cleCarte,
    this.cleMessages,
    this.cleLangue,
  });

  @override
  Widget build(BuildContext context) {
    final e = AppState.instance;
    final m = e.derniere;
    final grade = m == null ? null : Grade.values.byName(m.grade);
    final prochaine = e.prochaineMesure();
    final plan = e.plan;

    String resume() {
      final b = StringBuffer(trL('ac_voix_bonjour', {'p': e.profil.prenom}));
      if (m != null) {
        b.write(trL('ac_voix_mesure', {'t': Voix.tension(m.tas, m.tad), 'g': grade!.libelle}));
      } else {
        b.write(trL('ac_voix_aucune'));
      }
      b.write(trL('ac_voix_prochaine', {'h': AppState.formatHeure(TimeOfDay.fromDateTime(prochaine))}));
      return b.toString();
    }

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_majuscule(dateLongue(DateTime.now())), style: const TextStyle(fontSize: 16, color: Wt.gris, fontWeight: FontWeight.w600)),
            Text(context.tr('ac_bonjour', {'p': e.profil.prenom}), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ]),
        ),
        KeyedSubtree(
          key: cleMessages,
          child: BoutonRond(
            icone: const Emo('💬', taille: 22),
            libelle: context.tr('ac_messages'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
          ),
        ),
        const SizedBox(width: 8),
        KeyedSubtree(key: cleLangue, child: const BoutonLangue()),
      ]),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: PastilleSync(e.enLigne)),
      const SizedBox(height: 14),
      Carte(
        key: cleCarte,
        padding: const EdgeInsets.all(20),
        child: m == null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Emo('🩺', taille: 32),
                const SizedBox(height: 8),
                Text(context.tr('ac_aucune'), style: const TextStyle(fontSize: 17, height: 1.5)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(context.tr('ac_derniere', {'d': dateHeure(m.date)}), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700))),
                  BoutonEcouter(texte: resume, fond: Wt.violetClair, encre: Wt.violetFonce),
                ]),
                const SizedBox(height: 6),
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
                  Text('${m.tas}/${m.tad}', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.05)),
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('mmHg · ❤️ ${m.pouls} bpm', style: const TextStyle(fontSize: 16, color: Wt.gris, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 10),
                PuceGrade(grade!, long: true),
                const SizedBox(height: 10),
                Text(context.tr('ac_sens_${grade!.name}'), style: const TextStyle(fontSize: 17, height: 1.5)),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: versSuivi,
                  child: Text('📈 ${context.tr('ac_voir_suivi')} →'),
                ),
              ]),
      ),
      const SizedBox(height: 12),
      Carte(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlarmeScreen())),
        child: LigneInfo(
          emoji: '⏰',
          titre: AppState.formatHeure(TimeOfDay.fromDateTime(prochaine)),
          sousTitre: context.tr('ac_prochaine'),
          droite: Text(context.tr('ac_rappel_actif'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.vertTexte)),
        ),
      ),
      if (plan != null) ...[
        const SizedBox(height: 12),
        Carte(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: versTraitement,
          child: LigneInfo(
            emoji: '💊',
            titre: '${plan.medicament} ${nombre(plan.doseMg, plan.doseMg % 1 == 0 ? 0 : 1)} mg',
            sousTitre: '${context.tr('ac_medicament')} · ${heureTexte(plan.heure, plan.minute)}',
          ),
        ),
      ],
      const SizedBox(height: 12),
      FutureBuilder<List<Point>>(
        future: e.pointsJournaliers(7),
        builder: (context, s) {
          final ind = Indicateurs.de(s.data ?? const []);
          final moy = ind.moyenne;
          if (moy == null) return const SizedBox.shrink();
          return Carte(
            padding: const EdgeInsets.all(16),
            onTap: versSuivi,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('🎯 ${context.tr('ac_quatre')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Text(context.tr('ac_dans_cible', {'n': ind.nbDansPlage}), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: couleursStatut(ind.statut!).texte)),
              ]),
              const SizedBox(height: 10),
              QuatreValeurs(moy),
            ]),
          );
        },
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreparationScreen())),
        icon: const Icon(Icons.add),
        label: Text(context.tr('ac_mesurer')),
      ),
    ]);
  }

  static String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
