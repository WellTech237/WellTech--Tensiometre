// Éléments d'interface communs de l'espace médecin (version web, écran large).
// Mêmes couleurs que la maquette V9 et que l'application de la patiente.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/classification.dart';
import '../core/controle.dart';
import '../l10n.dart';
import '../theme.dart';
import 'calculs.dart';
import 'depot.dart';

class Couleurs2 {
  final Color fond, texte;
  const Couleurs2(this.fond, this.texte);
}

/// Code couleur AHA (identique à l'application).
Couleurs2 couleursGradeM(Grade g) => switch (g) {
      Grade.normale => const Couleurs2(Wt.vertClair, Wt.vertTexte),
      Grade.elevee => const Couleurs2(Color(0xFFFFF8DB), Color(0xFF5C4300)),
      Grade.grade1 => const Couleurs2(Wt.jaune, Wt.jauneTexte),
      Grade.grade2 => const Couleurs2(Wt.rougeClair, Wt.rougeTexte),
      Grade.grade3 => const Couleurs2(Wt.crise, Wt.blanc),
    };

Couleurs2 couleursStatutM(StatutControle s) => switch (s) {
      StatutControle.tresBien => const Couleurs2(Wt.vertClair, Wt.vertTexte),
      StatutControle.partiel => const Couleurs2(Wt.jaune, Wt.jauneTexte),
      StatutControle.tresMal => const Couleurs2(Wt.rougeClair, Wt.rougeTexte),
    };

Couleurs2 couleursPriorite(Priorite p) => switch (p) {
      Priorite.urgence => const Couleurs2(Wt.crise, Wt.blanc),
      Priorite.aVoir => const Couleurs2(Wt.jaune, Wt.jauneTexte),
      Priorite.stable => const Couleurs2(Wt.vertClair, Wt.vertTexte),
    };

const couleursSeries = {Grandeur.tas: Wt.serieTas, Grandeur.tad: Wt.serieTad, Grandeur.pm: Wt.seriePm, Grandeur.pp: Wt.seriePp};
const tiretsSeries = <Grandeur, List<int>?>{Grandeur.tas: null, Grandeur.tad: null, Grandeur.pm: [7, 5], Grandeur.pp: [2, 5]};

/// « il y a 12 min », « il y a 2 h », « il y a 3 j ».
String ilYa(DateTime d) {
  final e = DateTime.now().difference(d);
  if (e.inMinutes < 1) return trL('md_a_l_instant');
  final String t;
  if (e.inMinutes < 60) {
    t = '${e.inMinutes} min';
  } else if (e.inHours < 24) {
    t = '${e.inHours} h';
  } else {
    t = trL('md_jours_court', {'n': e.inDays});
  }
  return trL('md_il_y_a', {'t': t});
}

String nomGrandeur(Grandeur g) => trL('n_${g.name}');

String libelleStatutM(StatutControle s) => trL('statut_${s.name}');

/// Carte blanche à bord fin.
class CarteM extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? fond;
  final Color bordure;
  const CarteM({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.fond, this.bordure = Wt.bordure});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: fond ?? Wt.blanc, borderRadius: BorderRadius.circular(18), border: Border.all(color: bordure, width: 1.5)),
        child: child,
      );
}

/// Titre de section en petites capitales.
class Etiquette extends StatelessWidget {
  final String texte;
  const Etiquette(this.texte, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texte, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.gris, letterSpacing: 0.6)),
      );
}

/// Pastille « icône + mot » (jamais la couleur seule).
class Pastille extends StatelessWidget {
  final String texte;
  final Color fond;
  final Color couleur;
  final double taille;
  const Pastille(this.texte, {super.key, required this.fond, required this.couleur, this.taille = 14});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(999)),
        child: Text(texte, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: taille, fontWeight: FontWeight.w800, color: couleur)),
      );
}

/// Message sur plusieurs lignes (erreur, information, succès).
class Bandeau extends StatelessWidget {
  final String texte;
  final Color fond;
  final Color couleur;
  const Bandeau(this.texte, {super.key, this.fond = Wt.rougeClair, this.couleur = Wt.rougeTexte});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12)),
        child: Text(texte, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: couleur, height: 1.4)),
      );
}

class PastilleGrade extends StatelessWidget {
  final Grade grade;
  const PastilleGrade(this.grade, {super.key});
  @override
  Widget build(BuildContext context) {
    context.enAnglais; // reconstruit au changement de langue
    final c = couleursGradeM(grade);
    return Pastille('${grade.icone} ${grade.court}', fond: c.fond, couleur: c.texte);
  }
}

/// Tuile d'indicateur : titre, grande valeur, sous-titre.
class Kpi extends StatelessWidget {
  final String titre;
  final String valeur;
  final String? sous;
  final Color fond;
  final Color couleur;
  const Kpi({super.key, required this.titre, required this.valeur, this.sous, this.fond = Wt.blanc, this.couleur = Wt.encre});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(18), border: Border.all(color: fond == Wt.blanc ? Wt.bordure : fond, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: couleur.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text(valeur, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: couleur)),
          if (sous != null) ...[
            const SizedBox(height: 2),
            Text(sous!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: couleur.withValues(alpha: 0.8))),
          ],
        ]),
      );
}

/// Grille responsive de tuiles (2 à 6 colonnes selon la largeur).
class GrilleKpi extends StatelessWidget {
  final List<Widget> enfants;
  final double largeurMin;
  const GrilleKpi(this.enfants, {super.key, this.largeurMin = 190});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = (c.maxWidth / largeurMin).floor().clamp(2, enfants.length < 2 ? 2 : enfants.length).toInt();
        final l = (c.maxWidth - 12 * (n - 1)) / n;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final e in enfants) SizedBox(width: l, child: e)]);
      });
}

/// Bouton FR / EN.
class BoutonLangueM extends StatelessWidget {
  const BoutonLangueM({super.key});
  @override
  Widget build(BuildContext context) {
    final en = context.enAnglais;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), side: const BorderSide(color: Wt.bordure, width: 1.5)),
      onPressed: () => ReglagesUi.instance.changerLangue(en ? 'fr' : 'en'),
      icon: const Text('🌐', style: TextStyle(fontSize: 18)),
      label: Text(en ? 'Français' : 'English', style: const TextStyle(fontWeight: FontWeight.w800, color: Wt.encre)),
    );
  }
}

/// Barre du haut : logo, nom du médecin, langue, déconnexion.
class BarreHaut extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onDeconnexion;
  final VoidCallback? onVisite; // « Revoir la visite guidée »
  final GlobalKey? cleOutils; // zone mise en lumière pendant la visite
  const BarreHaut({super.key, required this.onDeconnexion, this.onVisite, this.cleOutils});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final m = Depot.instance.medecin;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Wt.blanc, border: Border(bottom: BorderSide(color: Wt.bordure, width: 1.5))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Wt.violet, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.monitor_heart_outlined, color: Wt.blanc),
        ),
        const SizedBox(width: 12),
        Text('WellTech', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Pastille(context.tr('md_espace'), fond: Wt.violetClair, couleur: Wt.violetFonce, taille: 13),
        const Spacer(),
        if (Depot.instance.admin)
          Text('🛡️ ${context.tr('ad_admin')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))
        else if (m != null)
          Flexible(
            child: Text('🩺 ${m.nom}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        const SizedBox(width: 12),
        Row(key: cleOutils, mainAxisSize: MainAxisSize.min, children: [
          const BoutonLangueM(),
          const SizedBox(width: 4),
          if (onVisite != null) IconButton(tooltip: context.tr('vg_revoir'), onPressed: onVisite, icon: const Icon(Icons.school_outlined)),
          IconButton(tooltip: context.tr('mdp_titre'), onPressed: () => dialogueMotDePasse(context), icon: const Icon(Icons.key_outlined)),
          IconButton(tooltip: context.tr('md_deconnexion'), onPressed: onDeconnexion, icon: const Icon(Icons.logout)),
        ]),
      ]),
    );
  }
}

/// Contenu centré, largeur maximale confortable sur grand écran.
class Centre extends StatelessWidget {
  final Widget child;
  final double max;
  const Centre({super.key, required this.child, this.max = 1320});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
      );
}

/// Valeur signée au format de la langue : +6,2 / −1,4.
String signe(double v, [int dec = 1]) => '${v > 0 ? '+' : (v < 0 ? '−' : '')}${nombre(v.abs(), dec)}';

/// Changer son mot de passe (ancien + nouveau, deux fois).
Future<void> dialogueMotDePasse(BuildContext context) async {
  final ancien = TextEditingController();
  final nouveau = TextEditingController();
  final nouveau2 = TextEditingController();
  String? erreur;
  var enCours = false;
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        title: Text(c.tr('mdp_titre')),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: ancien, obscureText: true, decoration: InputDecoration(labelText: c.tr('mdp_ancien'))),
            const SizedBox(height: 10),
            TextField(controller: nouveau, obscureText: true, decoration: InputDecoration(labelText: c.tr('mdp_nouveau'), helperText: c.tr('ins_mdp_aide'))),
            const SizedBox(height: 10),
            TextField(controller: nouveau2, obscureText: true, decoration: InputDecoration(labelText: c.tr('ins_mdp2'))),
            if (erreur != null) ...[
              const SizedBox(height: 10),
              Bandeau('⚠ ${c.tr(erreur!)}'),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('md_annuler'))),
          FilledButton(
            onPressed: enCours
                ? null
                : () async {
                    if (nouveau.text.length < 8) {
                      setD(() => erreur = 'ins_err_mdp');
                      return;
                    }
                    if (nouveau.text != nouveau2.text) {
                      setD(() => erreur = 'ins_err_mdp2');
                      return;
                    }
                    setD(() {
                      enCours = true;
                      erreur = null;
                    });
                    final e = await Depot.instance.changerMotDePasse(ancien.text, nouveau.text);
                    if (!c.mounted) return;
                    if (e == null) {
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('mdp_ok'))));
                    } else {
                      setD(() {
                        erreur = e;
                        enCours = false;
                      });
                    }
                  },
            child: Text(c.tr('enregistrer')),
          ),
        ],
      ),
    ),
  );
}

/// Mise à jour automatique d'un écran du portail : dès que Firestore signale
/// un changement (on attend 1,5 s que tous les documents soient arrivés),
/// et, par sécurité, toutes les 60 secondes.
class Rafraichisseur {
  Rafraichisseur(
    Stream<void> changements,
    this.action, {
    Duration securite = const Duration(seconds: 60),
    this.attente = const Duration(milliseconds: 1500),
  }) {
    _abonnement = changements.listen((_) => _planifier(), onError: (_) {});
    _minuteur = Timer.periodic(securite, (_) => action());
  }

  final VoidCallback action;
  final Duration attente;
  StreamSubscription<void>? _abonnement;
  Timer? _minuteur;
  Timer? _attente;

  void _planifier() {
    _attente?.cancel();
    _attente = Timer(attente, action);
  }

  void arreter() {
    _abonnement?.cancel();
    _minuteur?.cancel();
    _attente?.cancel();
  }
}

/// « ● En direct · mis à jour à 21:04 » : rassure le médecin, pas besoin de
/// cliquer sur Actualiser.
class PastilleDirect extends StatelessWidget {
  final DateTime? majLe;
  const PastilleDirect(this.majLe, {super.key});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Wt.vert, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          majLe == null ? context.tr('md_direct') : context.tr('md_direct_le', {'h': heureDe(majLe!)}),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Wt.vertTexte),
        ),
      ]);
}
