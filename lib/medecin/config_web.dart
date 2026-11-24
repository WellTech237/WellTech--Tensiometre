// Configuration Firebase de l'application WEB « WellTech Médecin ».
// Valeurs données par la console Firebase :
//   Paramètres du projet › Vos applications › WellTech Médecin (</>) › firebaseConfig
// Ce ne sont pas des secrets : elles identifient le projet. Les données sont
// protégées par les règles Firestore.

import 'package:firebase_core/firebase_core.dart';

const optionsWeb = FirebaseOptions(
  apiKey: 'AIzaSyAEI-BoFTUR7izqA0tjWKSCI2zK0d6jP2I',
  authDomain: 'welltech-fb14.firebaseapp.com',
  projectId: 'welltech-fb14',
  storageBucket: 'welltech-fb14.firebasestorage.app',
  messagingSenderId: '469641786473',
  appId: '1:469641786473:web:cc82a1530ad57a65c59ef8',
);

/// false tant que les valeurs « A_REMPLIR » n'ont pas été remplacées.
bool get configWebPrete => !optionsWeb.apiKey.contains('A_REMPLIR') && !optionsWeb.appId.contains('A_REMPLIR');
