import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Ouvre la feuille de partage d'Android avec le PDF : courriel, messagerie,
/// Google Drive, « Enregistrer dans Fichiers »… La patiente choisit à qui elle
/// l'envoie ; rien ne part sans son geste.
Future<void> partagerPdf(Uint8List octets, String nomFichier) => Printing.sharePdf(bytes: octets, filename: nomFichier);
