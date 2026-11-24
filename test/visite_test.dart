import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/l10n.dart';
import 'package:welltech/ui/visite_guidee.dart';

void main() {
  testWidgets('Visite guidée : étapes, mise en lumière, Suivant puis Terminer', (tester) async {
    ReglagesUi.instance.changerLangue('fr');
    final cle = GlobalKey();
    bool? resultat;
    await tester.pumpWidget(PorteeUi(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(children: [
              SizedBox(key: cle, width: 120, height: 40, child: const Text('Cible')),
              ElevatedButton(
                onPressed: () async => resultat = await lancerVisite(context, [
                  const EtapeVisite(emoji: '👋', titre: 'vgp_1_t', texte: 'vgp_1'),
                  EtapeVisite.sur(cle, emoji: '🩺', titre: 'vgp_2_t', texte: 'vgp_2'),
                ]),
                child: const Text('Lancer'),
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Lancer'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue sur WellTech !'), findsOneWidget);
    expect(find.text('Étape 1 sur 2'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Faire une mesure'), findsOneWidget);
    expect(find.text('C’est parti !'), findsOneWidget);
    expect(zoneDe(cle), isNotNull);

    await tester.tap(find.text('C’est parti !'));
    await tester.pumpAndSettle();
    expect(resultat, isTrue);
    expect(find.text('Faire une mesure'), findsNothing);
  });

  testWidgets('Visite guidée : « Passer » ferme la visite', (tester) async {
    ReglagesUi.instance.changerLangue('fr');
    bool? resultat;
    await tester.pumpWidget(PorteeUi(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => resultat = await lancerVisite(context, [
                const EtapeVisite(emoji: '👋', titre: 'vgp_1_t', texte: 'vgp_1'),
                const EtapeVisite(emoji: '🚨', titre: 'vgp_9_t', texte: 'vgp_9'),
              ]),
              child: const Text('Lancer'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Lancer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(resultat, isFalse);
  });
}
