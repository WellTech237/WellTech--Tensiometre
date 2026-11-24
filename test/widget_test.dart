import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/core/classification.dart';
import 'package:welltech/l10n.dart';
import 'package:welltech/ui/widgets.dart';

void main() {
  testWidgets('Le logo affiche le nom WellTech', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Logo())));
    expect(find.text('WellTech'), findsOneWidget);
  });

  testWidgets('La puce de niveau montre une icône et un mot, en FR puis en EN', (tester) async {
    ReglagesUi.instance.changerLangue('fr');
    await tester.pumpWidget(PorteeUi(child: const MaterialApp(home: Scaffold(body: PuceGrade(Grade.grade2)))));
    expect(find.text('⚠ Stade 2'), findsOneWidget);
    ReglagesUi.instance.changerLangue('en');
    await tester.pump();
    expect(find.text('⚠ Stage 2'), findsOneWidget);
    ReglagesUi.instance.changerLangue('fr');
  });
}
