import 'package:flutter/material.dart';

import '../core/classification.dart';
import '../core/controle.dart';
import '../l10n.dart';
import '../services/app_state.dart';
import '../services/voix.dart';
import '../theme.dart';

/// Carte blanche aux coins arrondis (élément de base de la maquette V9).
class Carte extends StatelessWidget {
  final Widget child;
  final Color couleur;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? bordure;
  const Carte({super.key, required this.child, this.couleur = Wt.blanc, this.padding = const EdgeInsets.all(18), this.onTap, this.bordure});

  @override
  Widget build(BuildContext context) {
    final c = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(22),
        border: bordure == null ? null : Border.all(color: bordure!, width: 2),
      ),
      child: child,
    );
    if (onTap == null) return c;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: c));
  }
}

/// Icône repère (emoji). Décorative : le texte voisin porte le sens.
class Emo extends StatelessWidget {
  final String emoji;
  final double taille;
  final double? boite;
  final Color fond;
  const Emo(this.emoji, {super.key, this.taille = 22, this.boite, this.fond = const Color(0xFFF1F0FA)});

  @override
  Widget build(BuildContext context) {
    final t = ExcludeSemantics(child: Text(emoji, style: TextStyle(fontSize: taille, height: 1)));
    if (boite == null) return t;
    return Container(
      width: boite,
      height: boite,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(boite! / 3)),
      child: t,
    );
  }
}

/// Logo WellTech : icône de pouls + nom.
class Logo extends StatelessWidget {
  final double taille;
  final Color texte;
  final bool avecNom;
  const Logo({super.key, this.taille = 38, this.texte = Wt.encre, this.avecNom = true});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: taille,
          height: taille,
          decoration: BoxDecoration(color: Wt.violet, borderRadius: BorderRadius.circular(taille / 3)),
          child: Icon(Icons.monitor_heart_outlined, color: Wt.blanc, size: taille * 0.58),
        ),
        if (avecNom) ...[
          const SizedBox(width: 10),
          Text('WellTech', style: TextStyle(fontSize: taille * 0.5, fontWeight: FontWeight.w800, color: texte)),
        ],
      ]);
}

/// Bouton rond 48 px (Retour, Écouter, etc.).
class BoutonRond extends StatelessWidget {
  final Widget icone;
  final String libelle;
  final VoidCallback onTap;
  final Color fond;
  const BoutonRond({super.key, required this.icone, required this.libelle, required this.onTap, this.fond = Wt.blanc});

  @override
  Widget build(BuildContext context) => Semantics(
        label: libelle,
        button: true,
        child: Material(
          color: fond,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 48, height: 48, child: Center(child: icone)),
          ),
        ),
      );
}

/// Bouton « Écouter » : lit le texte à voix haute dans la langue choisie.
class BoutonEcouter extends StatelessWidget {
  final String Function() texte;
  final Color fond;
  final Color encre;
  const BoutonEcouter({super.key, required this.texte, this.fond = Wt.blanc, this.encre = Wt.violet});

  @override
  Widget build(BuildContext context) => BoutonRond(
        icone: Icon(Icons.volume_up_outlined, color: encre, size: 22),
        libelle: context.tr('ecouter'),
        fond: fond,
        onTap: () => Voix.instance.lire(texte()),
      );
}

/// Bouton 🌐 qui bascule FR ↔ EN (même place sur tous les écrans).
class BoutonLangue extends StatelessWidget {
  const BoutonLangue({super.key});

  @override
  Widget build(BuildContext context) {
    final en = context.enAnglais;
    return Semantics(
      button: true,
      label: en ? 'Passer en français' : 'Switch to English',
      child: Material(
        color: Wt.violetClair,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => AppState.instance.changerLangue(en ? 'fr' : 'en'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Emo('🌐', taille: 18),
                const SizedBox(width: 6),
                Text(en ? 'FR' : 'EN', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur complet FR | EN (écran de bienvenue et Moi).
class SelecteurLangue extends StatelessWidget {
  const SelecteurLangue({super.key});

  @override
  Widget build(BuildContext context) {
    final en = context.enAnglais;
    Widget b(String code, bool actif) => Semantics(
          button: true,
          selected: actif,
          child: Material(
            color: actif ? Wt.violet : Colors.transparent,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => AppState.instance.changerLangue(code.toLowerCase()),
              child: SizedBox(width: 52, height: 44, child: Center(child: Text(code, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: actif ? Wt.blanc : Wt.violetFonce)))),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const ShapeDecoration(color: Wt.violetClair, shape: StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [b('FR', !en), b('EN', en)]),
    );
  }
}

/// En-tête commun : [Retour] Titre [actions] [🌐].
class EnTete extends StatelessWidget {
  final String titre;
  final bool retour;
  final List<Widget> actions;
  final bool langue;
  const EnTete(this.titre, {super.key, this.retour = false, this.actions = const [], this.langue = true});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          if (retour) ...[
            BoutonRond(icone: const Icon(Icons.chevron_left, size: 28, color: Wt.encre), libelle: context.tr('retour'), onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(titre, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2))),
          for (final a in actions) ...[const SizedBox(width: 8), a],
          if (langue) ...[const SizedBox(width: 8), const BoutonLangue()],
        ]),
      );
}

/// Barre d'étapes « Étape 2 sur 5 ».
class Etapes extends StatelessWidget {
  final int n;
  final int total;
  final String libelle;
  const Etapes({super.key, required this.n, required this.total, required this.libelle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(libelle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(child: Container(height: 7, decoration: BoxDecoration(color: i < n ? Wt.violet : const Color(0xFFD9D6EE), borderRadius: BorderRadius.circular(4)))),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ]),
      ]);
}

class CouleursGrade {
  final Color fond, texte, plein;
  const CouleursGrade(this.fond, this.texte, this.plein);
}

/// Code couleur AHA exigé par le projet (inchangé depuis la V8).
CouleursGrade couleursGrade(Grade g) => switch (g) {
      Grade.normale => const CouleursGrade(Wt.vertClair, Wt.vertTexte, Wt.vert),
      Grade.elevee => const CouleursGrade(Color(0xFFFFF8DB), Color(0xFF5C4300), Color(0xFFC9A400)),
      Grade.grade1 => const CouleursGrade(Wt.jaune, Wt.jauneTexte, Color(0xFFE08A00)),
      Grade.grade2 => const CouleursGrade(Wt.rougeClair, Wt.rougeTexte, Color(0xFFD9534A)),
      Grade.grade3 => const CouleursGrade(Wt.crise, Wt.blanc, Wt.crise),
    };

/// Couleurs des 4 niveaux d'alerte : Information, Attention, Médecin, Urgence.
CouleursGrade couleursNiveau(int n) => switch (n) {
      1 => const CouleursGrade(Wt.vertClair, Wt.vertTexte, Wt.vert),
      2 => const CouleursGrade(Wt.jaune, Wt.jauneTexte, Color(0xFFB76E00)),
      3 => const CouleursGrade(Wt.orangeClair, Wt.orangeTexte, Color(0xFFC2410C)),
      _ => const CouleursGrade(Wt.crise, Wt.blanc, Wt.crise),
    };

const emojisNiveau = ['ℹ️', '⚠️', '🩺', '🚑'];

/// Pastille de niveau de tension : icône + mot (jamais la couleur seule).
class PuceGrade extends StatelessWidget {
  final Grade grade;
  final bool long;
  const PuceGrade(this.grade, {super.key, this.long = false});

  @override
  Widget build(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<PorteeUi>(); // reconstruit si la langue change
    final c = couleursGrade(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: c.fond, borderRadius: BorderRadius.circular(999)),
      child: Text('${grade.icone} ${long ? grade.libelle : grade.court}', style: TextStyle(color: c.texte, fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }
}

/// Puce à toucher (symptômes, antécédents, choix).
class Puce extends StatelessWidget {
  final String texte;
  final String? emoji;
  final bool active;
  final VoidCallback onTap;
  final bool danger;
  final bool large;
  const Puce({super.key, required this.texte, required this.active, required this.onTap, this.emoji, this.danger = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    final bord = active ? (danger ? Wt.rouge : Wt.violet) : Wt.bordure;
    final fond = active ? (danger ? Wt.rougeClair : Wt.violetClair) : Wt.blanc;
    final encre = active ? (danger ? Wt.rougeTexte : Wt.violetTexte) : Wt.encre;
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: fond,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: bord, width: 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: large ? 60 : 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                if (emoji != null) ...[Emo(emoji!, taille: 20), const SizedBox(width: 8)],
                Expanded(child: Text(texte, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: encre, height: 1.25))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille de puces sur 2 colonnes.
class GrillePuces extends StatelessWidget {
  final List<Widget> enfants;
  const GrillePuces(this.enfants, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final e in enfants) SizedBox(width: w, child: e)]);
      });
}

class Etiquette extends StatelessWidget {
  final String texte;
  final Color couleur;
  const Etiquette(this.texte, {super.key, this.couleur = Wt.gris});
  @override
  Widget build(BuildContext context) => Text(texte, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: couleur));
}

/// Ligne de liste : icône repère, titre, sous-titre, élément à droite.
class LigneInfo extends StatelessWidget {
  final String emoji;
  final String titre;
  final String? sousTitre;
  final Widget? droite;
  final VoidCallback? onTap;
  final Color fondEmoji;
  const LigneInfo({super.key, required this.emoji, required this.titre, this.sousTitre, this.droite, this.onTap, this.fondEmoji = const Color(0xFFF1F0FA)});

  @override
  Widget build(BuildContext context) {
    final contenu = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Emo(emoji, taille: 24, boite: 46, fond: fondEmoji),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (sousTitre != null) Text(sousTitre!, style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (droite != null) ...[const SizedBox(width: 8), droite!],
          if (onTap != null && droite == null) const Icon(Icons.chevron_right, color: Wt.gris),
        ]),
      ),
    );
    if (onTap == null) return contenu;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: contenu);
  }
}

/// Les 4 grandeurs (TAS, TAD, Pm, Pp) avec leur état par rapport à la plage.
class QuatreValeurs extends StatelessWidget {
  final Grandeurs valeurs;
  const QuatreValeurs(this.valeurs, {super.key});

  @override
  Widget build(BuildContext context) {
    final noms = [context.tr('n_tas'), context.tr('n_tad'), context.tr('n_pm'), context.tr('n_pp')];
    return Row(children: [
      for (final g in Grandeur.values) ...[
        Expanded(child: _case(context, noms[g.index], valeurs.de(g), dansLaPlage(g, valeurs.de(g)))),
        if (g != Grandeur.pp) const SizedBox(width: 8),
      ],
    ]);
  }

  Widget _case(BuildContext context, String nom, double v, bool ok) {
    final fond = ok ? Wt.vertClair : Wt.orangeClair;
    final encre = ok ? Wt.vertTexte : const Color(0xFF7A2E00);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(nom, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: encre)),
        FittedBox(child: Text('${v.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        FittedBox(child: Text(ok ? '✓ ${context.tr('cible_court')}' : '↑ ${context.tr('haut_court')}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: encre))),
      ]),
    );
  }
}

/// Pastille de synchronisation (état du système toujours visible).
class PastilleSync extends StatelessWidget {
  final bool enLigne;
  const PastilleSync(this.enLigne, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: enLigne ? Wt.vertClair : Wt.jaune, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: enLigne ? Wt.vert : const Color(0xFFB76E00), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(context.tr(enLigne ? 'en_ligne' : 'hors_ligne'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: enLigne ? Wt.vertTexte : Wt.jauneTexte)),
        ]),
      );
}

/// Message d'information / d'avertissement avec icône.
class Encadre extends StatelessWidget {
  final String emoji;
  final String texte;
  final Color fond;
  final Color encre;
  const Encadre(this.emoji, this.texte, {super.key, this.fond = Wt.violetClair, this.encre = Wt.violetTexte});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Emo(emoji, taille: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: encre, height: 1.45))),
        ]),
      );
}

/// Texte du statut de contrôle (définitions du client).
String libelleStatut(BuildContext context, StatutControle s) => context.tr('statut_${s.name}');

CouleursGrade couleursStatut(StatutControle s) => switch (s) {
      StatutControle.tresBien => const CouleursGrade(Wt.vertClair, Wt.vertTexte, Wt.vert),
      StatutControle.partiel => const CouleursGrade(Wt.jaune, Wt.jauneTexte, Color(0xFFB76E00)),
      StatutControle.tresMal => const CouleursGrade(Wt.rougeClair, Wt.rougeTexte, Wt.rouge),
    };
