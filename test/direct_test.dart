// Portail en direct : le rafraîchissement automatique regroupe les signaux
// rapprochés (une seule mise à jour) et garde un filet de sécurité régulier.
// Tests en temps réel avec des délais courts (pas d'horloge simulée).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/medecin/ui_medecin.dart';

Future<void> attendre(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('3 signaux rapprochés = 1 seule mise à jour, après le délai', () async {
    final signaux = StreamController<void>.broadcast();
    var n = 0;
    final r = Rafraichisseur(signaux.stream, () => n++, attente: const Duration(milliseconds: 200), securite: const Duration(seconds: 30));
    signaux
      ..add(null)
      ..add(null)
      ..add(null);
    await attendre(50);
    expect(n, 0); // pas encore : on attend que tout soit arrivé
    await attendre(600);
    expect(n, 1); // une seule mise à jour pour les 3 signaux
    r.arreter();
    unawaited(signaux.close());
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('Sans signal : mise à jour de sécurité régulière, puis plus rien après arrêt', () async {
    final signaux = StreamController<void>.broadcast();
    var n = 0;
    final r = Rafraichisseur(signaux.stream, () => n++, securite: const Duration(milliseconds: 200));
    await attendre(700);
    expect(n, greaterThanOrEqualTo(2));
    r.arreter();
    final avant = n;
    await attendre(600);
    expect(n, avant); // arrêté : plus aucune mise à jour
    unawaited(signaux.close());
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('Une erreur du flux (ex. accès retiré) ne casse rien', () async {
    final signaux = StreamController<void>.broadcast();
    var n = 0;
    final r = Rafraichisseur(signaux.stream, () => n++, attente: const Duration(milliseconds: 100), securite: const Duration(seconds: 30));
    signaux.addError(Exception('permission-denied'));
    await attendre(300);
    expect(n, 0);
    r.arreter();
    unawaited(signaux.close());
  }, timeout: const Timeout(Duration(seconds: 20)));
}
