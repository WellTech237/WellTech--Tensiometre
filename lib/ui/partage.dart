import 'package:flutter/material.dart';

import '../l10n.dart';

/// Prépare un PDF (quelques secondes) avec une fenêtre d'attente, puis ouvre
/// la feuille de partage. En cas d'échec, un message clair, jamais d'écran figé.
Future<void> preparerEtPartager(BuildContext context, Future<void> Function() action) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messager = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(c.tr('pdf_preparation'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        ]),
      ),
    ),
  );
  try {
    await action();
  } catch (_) {
    messager.showSnackBar(SnackBar(content: Text(trL('pdf_erreur'))));
  } finally {
    if (nav.canPop()) nav.pop();
  }
}

/// Choix de la période du rapport (30 ou 90 jours). Renvoie null si annulé.
Future<int?> choisirPeriodeRapport(BuildContext context) => showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('pdf_periode_q')),
        children: [
          for (final j in const [30, 90])
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              onPressed: () => Navigator.pop(c, j),
              child: Text(c.tr('pdf_periode_j', {'n': j}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
