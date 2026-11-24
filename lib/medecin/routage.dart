import 'package:flutter/widgets.dart';

import 'depot.dart';
import 'ecran_admin.dart';
import 'ecran_attente.dart';
import 'ecran_liste.dart';

/// Premier écran selon le rôle du compte connecté.
Widget ecranPour(Acces a) => switch (a) {
      Acces.medecin => const EcranListe(),
      Acces.attente || Acces.refuse => const EcranAttente(),
      Acces.admin => const EcranAdmin(),
    };
