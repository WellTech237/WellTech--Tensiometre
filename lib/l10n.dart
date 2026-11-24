import 'package:flutter/widgets.dart';

import 'l10n_textes.dart';

/// Réglages d'affichage partagés par toute l'application : langue (FR / EN)
/// et taille du texte. Changer la langue met à jour tous les écrans ouverts,
/// sans redémarrer.
class ReglagesUi extends ChangeNotifier {
  ReglagesUi._();
  static final instance = ReglagesUi._();

  String langue = 'fr';
  double echelle = 1.0; // 1.0 normal, 1.15 grand, 1.3 très grand

  bool get en => langue == 'en';

  void changerLangue(String l) {
    if (l == langue) return;
    langue = l == 'en' ? 'en' : 'fr';
    notifyListeners();
  }

  void changerEchelle(double e) {
    if (e == echelle) return;
    echelle = e;
    notifyListeners();
  }
}

/// Placée au-dessus de MaterialApp : tout écran qui lit un texte traduit est
/// reconstruit quand la langue change.
class PorteeUi extends InheritedNotifier<ReglagesUi> {
  PorteeUi({super.key, required super.child}) : super(notifier: ReglagesUi.instance);
}

/// Texte traduit sans contexte (notifications, voix, services).
String trL(String cle, [Map<String, Object?> args = const {}]) {
  final l = ReglagesUi.instance.langue;
  var s = textes[l]?[cle] ?? textes['fr']![cle] ?? cle;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

extension TraductionContexte on BuildContext {
  /// Texte traduit ; l'écran sera reconstruit si la langue change.
  String tr(String cle, [Map<String, Object?> args = const {}]) {
    dependOnInheritedWidgetOfExactType<PorteeUi>();
    return trL(cle, args);
  }

  bool get enAnglais {
    dependOnInheritedWidgetOfExactType<PorteeUi>();
    return ReglagesUi.instance.en;
  }
}

/// Nombre décimal au format de la langue : 1,8 (FR) ou 1.8 (EN).
String nombre(double v, [int decimales = 1]) {
  final s = v.toStringAsFixed(decimales);
  return ReglagesUi.instance.en ? s : s.replaceAll('.', ',');
}

/// Heure au format de la langue : 18 h 05 (FR) ou 6:05 p.m. (EN).
String heureTexte(int h, int m) {
  if (!ReglagesUi.instance.en) return '$h h ${m.toString().padLeft(2, '0')}';
  final suffixe = h < 12 ? 'a.m.' : 'p.m.';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $suffixe';
}

String heureDe(DateTime d) => heureTexte(d.hour, d.minute);

const _moisFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _moisEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _joursFr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _joursEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _joursCourtsFr = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
const _joursCourtsEn = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// « 21 nov. » / « Nov 21 ».
String dateCourte(DateTime d) => ReglagesUi.instance.en ? '${_moisEn[d.month - 1]} ${d.day}' : '${d.day} ${_moisFr[d.month - 1]}';

/// « samedi 21 nov. » / « Saturday, Nov 21 ».
String dateLongue(DateTime d) =>
    ReglagesUi.instance.en ? '${_joursEn[d.weekday - 1]}, ${_moisEn[d.month - 1]} ${d.day}' : '${_joursFr[d.weekday - 1]} ${d.day} ${_moisFr[d.month - 1]}';

String jourCourt(DateTime d) => (ReglagesUi.instance.en ? _joursCourtsEn : _joursCourtsFr)[d.weekday - 1];

/// « 21 nov. · 18 h 05 ».
String dateHeure(DateTime d) => '${dateCourte(d)} · ${heureDe(d)}';
