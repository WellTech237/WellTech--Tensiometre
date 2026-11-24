// Visite guidée (« onboarding ») : à la première connexion, une suite de
// bulles explique l'application étape par étape. L'élément présenté est mis
// en lumière (le reste de l'écran est assombri) ; une carte donne le titre,
// l'explication, la progression et les boutons Passer / Précédent / Suivant.
// Partagé par l'application mobile ET l'espace médecin (web) : n'importe que
// Flutter, les textes et le thème.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../theme.dart';

/// Une étape. [zone] renvoie le rectangle à mettre en lumière (coordonnées
/// de l'écran) ; null : carte au centre, sans mise en lumière.
class EtapeVisite {
  final String emoji;
  final String titre; // clé de texte
  final String texte; // clé de texte
  final Rect? Function()? zone;
  final GlobalKey? cible; // pour faire défiler jusqu'à l'élément
  const EtapeVisite({required this.emoji, required this.titre, required this.texte, this.zone, this.cible});

  /// Étape qui met en lumière le widget portant [cle].
  factory EtapeVisite.sur(GlobalKey cle, {required String emoji, required String titre, required String texte}) =>
      EtapeVisite(emoji: emoji, titre: titre, texte: texte, zone: () => zoneDe(cle), cible: cle);
}

/// Rectangle à l'écran du widget portant [cle] (null s'il n'est pas affiché).
Rect? zoneDe(GlobalKey cle) {
  final ro = cle.currentContext?.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// Morceau i sur n d'un widget découpé en parts égales (ex. un onglet de la
/// barre de navigation, qui répartit ses n destinations sur toute la largeur).
Rect? zonePart(GlobalKey cle, int i, int n) {
  final r = zoneDe(cle);
  if (r == null) return null;
  final l = r.width / n;
  return Rect.fromLTWH(r.left + i * l, r.top, l, r.height);
}

/// Lance la visite par-dessus l'écran courant. Se termine quand la personne
/// a cliqué sur Terminer ou Passer (renvoie true si elle est allée au bout).
Future<bool> lancerVisite(BuildContext context, List<EtapeVisite> etapes) async {
  if (etapes.isEmpty) return false;
  final r = await Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => _Visite(etapes: etapes),
    transitionsBuilder: (_, a, __, enfant) => FadeTransition(opacity: a, child: enfant),
  ));
  return r ?? false;
}

class _Visite extends StatefulWidget {
  final List<EtapeVisite> etapes;
  const _Visite({required this.etapes});
  @override
  State<_Visite> createState() => _VisiteState();
}

class _VisiteState extends State<_Visite> {
  int _i = 0;
  Rect? _zone;

  EtapeVisite get _etape => widget.etapes[_i];
  bool get _derniere => _i == widget.etapes.length - 1;

  @override
  void initState() {
    super.initState();
    _preparer();
  }

  /// Fait défiler jusqu'à l'élément s'il est hors de l'écran, puis le mesure.
  Future<void> _preparer() async {
    final ctx = _etape.cible?.currentContext;
    if (ctx != null) {
      try {
        await Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } catch (_) {}
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _zone = _etape.zone?.call());
    });
  }

  void _aller(int i) {
    if (i < 0) return;
    if (i >= widget.etapes.length) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _i = i;
      _zone = null;
    });
    _preparer();
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final zone = _zone?.inflate(8);
    final largeur = math.min(taille.width - 32, 400.0);
    // Carte sous l'élément s'il y a la place, sinon au-dessus ; au centre
    // pour les étapes sans élément.
    double? haut, bas;
    var gauche = (taille.width - largeur) / 2;
    if (zone != null) {
      gauche = (zone.center.dx - largeur / 2).clamp(16.0, math.max(16.0, taille.width - largeur - 16)).toDouble();
      if (taille.height - zone.bottom >= 280) {
        haut = zone.bottom + 14;
      } else {
        bas = math.max(16.0, taille.height - zone.top + 14);
      }
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _aller(_i + 1),
        const SingleActivator(LogicalKeyboardKey.enter): () => _aller(_i + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _aller(_i - 1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(false),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(children: [
            // Voile sombre percé autour de l'élément présenté.
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // bloque les clics sur l'application pendant la visite
                child: CustomPaint(painter: _Voile(zone)),
              ),
            ),
            if (zone == null)
              Center(child: SizedBox(width: largeur, child: _carte(context)))
            else
              Positioned(left: gauche, width: largeur, top: haut, bottom: bas, child: Align(
                alignment: haut != null ? Alignment.topCenter : Alignment.bottomCenter,
                child: _carte(context),
              )),
          ]),
        ),
      ),
    );
  }

  Widget _carte(BuildContext context) {
    final n = widget.etapes.length;
    // Boutons à largeur normale (le thème mobile les étire sur toute la
    // largeur, ce qui est impossible dans une rangée).
    const taille = Size(0, 48);
    return Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: Wt.blanc,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        // Hauteur limitée : avec un très grand texte, l'explication défile.
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Wt.violetClair, shape: BoxShape.circle),
                child: Text(_etape.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('vg_etape', {'i': _i + 1, 'n': n}), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Wt.violet)),
                  const SizedBox(height: 2),
                  Text(context.tr(_etape.titre), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
                ]),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Text(context.tr(_etape.texte), style: const TextStyle(fontSize: 16, height: 1.5, color: Wt.encre)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 14),
            // OverflowBar : les boutons passent les uns sous les autres si le
            // texte est très grand ou l'écran très étroit.
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: 6,
              children: [
                if (!_derniere)
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: taille, foregroundColor: Wt.gris),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.tr('vg_passer')),
                  ),
                if (_i > 0)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: taille, padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: () => _aller(_i - 1),
                    child: Text(context.tr('vg_precedent')),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: taille, padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () => _aller(_i + 1),
                  child: Text(context.tr(_derniere ? 'vg_terminer' : 'vg_suivant')),
                ),
              ],
            ),
          ),
          // Barre de progression (comme les visites guidées des sites web).
          LinearProgressIndicator(
            value: (_i + 1) / n,
            minHeight: 5,
            backgroundColor: Wt.violetClair,
            valueColor: const AlwaysStoppedAnimation(Wt.violet),
          ),
        ]),
      ),
    );
  }
}

class _Voile extends CustomPainter {
  final Rect? trou;
  _Voile(this.trou);

  @override
  void paint(Canvas canvas, Size size) {
    final fond = Paint()..color = const Color(0xB30E1726);
    if (trou == null) {
      canvas.drawRect(Offset.zero & size, fond);
      return;
    }
    final r = RRect.fromRectAndRadius(trou!, const Radius.circular(18));
    final chemin = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(r);
    canvas.drawPath(chemin, fond);
    canvas.drawRRect(
      r,
      Paint()
        ..color = Wt.violetClair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_Voile old) => old.trou != trou;
}
