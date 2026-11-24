// Téléchargement d'un fichier dans le navigateur (espace médecin, web seulement).
// Ce fichier n'est importé que par lib/main_medecin.dart : il n'est jamais
// compilé dans l'application Android.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void telechargerFichier(Uint8List octets, String nom, String type) {
  final blob = web.Blob(<JSAny>[octets.toJS].toJS, web.BlobPropertyBag(type: type));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = nom;
  a.style.display = 'none';
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
  // Laisse au navigateur le temps de démarrer le téléchargement.
  Future<void>.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}
