import 'package:flutter_tts/flutter_tts.dart';

import '../l10n.dart';

/// Lecture à voix haute (voix de synthèse du téléphone, en général hors ligne).
class Voix {
  Voix._();
  static final instance = Voix._();

  final _tts = FlutterTts();
  String? _langue;

  /// Voix française ou anglaise du Canada selon la langue choisie.
  Future<void> _init() async {
    final l = ReglagesUi.instance.langue;
    if (_langue == l) return;
    await _tts.setLanguage(l == 'en' ? 'en-CA' : 'fr-CA');
    await _tts.setSpeechRate(0.45);
    _langue = l;
  }

  Future<void> lire(String texte) async {
    await _init();
    await _tts.stop();
    await _tts.speak(texte);
  }

  Future<void> stop() => _tts.stop();

  /// « 152 sur 94 » se lit mieux que « 152/94 ».
  static String tension(int tas, int tad) => trL('voix_tension', {'s': tas, 'd': tad});
}
