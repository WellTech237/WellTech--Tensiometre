import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database.dart';
import 'l10n.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/cloud.dart';
import 'services/notifications.dart';
import 'theme.dart';
import 'ui/screens/alarme_screen.dart';
import 'ui/screens/bienvenue_screen.dart';
import 'ui/screens/deverrouillage_screen.dart';
import 'ui/screens/inscription_screen.dart';
import 'ui/screens/urgence_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BaseLocale.instance.ouvrir();
  await AppState.instance.chargerReglagesUi(); // langue et taille du texte
  await Cloud.instance.init(); // sans google-services.json : mode 100 % local
  await Notifications.instance.init();
  await AppState.instance.charger();

  final auth = AuthService.instance;
  final Widget depart;
  if (!await auth.consentementDonne()) {
    depart = const BienvenueScreen();
  } else if (!await auth.compteExiste()) {
    depart = const InscriptionScreen();
  } else {
    depart = const DeverrouillageScreen();
  }

  Notifications.instance.onOuverture = ouvrirDepuisNotification;
  final payload = await Notifications.instance.payloadAuDemarrage();

  runApp(WellTechApp(depart: depart));
  if (payload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => ouvrirDepuisNotification(payload));
  }
}

/// Une notification touchée ouvre directement le bon écran.
/// L'urgence est accessible sans déverrouiller ; les données restent protégées.
void ouvrirDepuisNotification(String payload) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  switch (payload) {
    case 'alarme_mesure':
      nav.push(MaterialPageRoute(builder: (_) => const AlarmeScreen()));
    case 'crise':
      nav.push(MaterialPageRoute(builder: (_) => const UrgenceScreen()));
    case 'medicament':
      // Onglet Traitement, après déverrouillage (aucune donnée avant).
      AppState.instance.ongletDemande.value = 3;
  }
}

class WellTechApp extends StatelessWidget {
  final Widget depart;
  const WellTechApp({super.key, required this.depart});

  @override
  Widget build(BuildContext context) {
    final ui = ReglagesUi.instance;
    return PorteeUi(
      child: ListenableBuilder(
        listenable: ui,
        builder: (context, _) => MaterialApp(
          title: 'WellTech',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: welltechTheme(),
          locale: Locale(ui.langue),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Taille du texte choisie dans Moi (s'ajoute au réglage du téléphone).
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final base = mq.textScaler.scale(1);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear((base * ui.echelle).clamp(1.0, 2.0))),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: depart,
        ),
      ),
    );
  }
}
