// Point d'entrée de l'ESPACE MÉDECIN (site web).
// Lancer :  flutter run -d chrome -t lib/main_medecin.dart
// (l'application de la patiente reste lib/main.dart)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'medecin/config_web.dart';
import 'medecin/depot.dart';
import 'medecin/ecran_connexion.dart';
import 'medecin/routage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? erreur;
  Acces? acces;
  if (!configWebPrete) {
    erreur = 'md_err_config';
  } else {
    try {
      await Firebase.initializeApp(options: optionsWeb);
      // Session gardée par le navigateur : on attend qu'elle soit restaurée.
      final u = await FirebaseAuth.instance.authStateChanges().first;
      if (u != null) acces = (await Depot.instance.chargerSession()).$1;
    } catch (_) {
      erreur = 'md_err_firebase';
    }
  }
  runApp(PortailMedecin(erreur: erreur, acces: acces));
}

class PortailMedecin extends StatelessWidget {
  final String? erreur;
  final Acces? acces;
  const PortailMedecin({super.key, this.erreur, this.acces});

  @override
  Widget build(BuildContext context) {
    return PorteeUi(
      child: ListenableBuilder(
        listenable: ReglagesUi.instance,
        builder: (context, _) => MaterialApp(
          title: 'WellTech · Médecin',
          debugShowCheckedModeBanner: false,
          theme: _themeWeb(),
          locale: Locale(ReglagesUi.instance.langue),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: erreur != null
              ? EcranErreurConfig(cle: erreur!)
              : (acces != null ? ecranPour(acces!) : const EcranConnexion()),
        ),
      ),
    );
  }
}

/// Thème de l'app, adapté au web : sur mobile les boutons prennent toute la
/// largeur (minimumSize = largeur infinie). Sur le portail, ça empêchait les
/// boîtes de dialogue de s'afficher (boutons dans une rangée sans largeur
/// fixe) : on garde la hauteur confortable mais une largeur minimale normale.
ThemeData _themeWeb() {
  final base = welltechTheme();
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      ),
    ),
  );
}
