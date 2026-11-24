// Envoi de courriels avec EmailJS (gratuit, sans serveur), depuis le portail
// web ET depuis l'application Android.
// Ces identifiants ne sont pas secrets (prévus pour être dans une appli).
// Pour l'appli Android : EmailJS › Account › Security › cocher
// « Allow EmailJS API for non-browser applications ».

import 'dart:convert';

import 'package:http/http.dart' as http;

const emailjsService = 'service_p3wj1dk';
const emailjsCle = 'yz4DL2ya4plUl8IIA';

/// Modèle « nouvelle demande de compte médecin » (destinataires : admins,
/// réglés dans EmailJS).
const modeleDemande = 'template_mqfc08t';

/// Modèle générique : To = {{to_email}}, Subject = {{sujet}}, contenu = {{message}}.
/// Sert pour les décisions de l'administrateur et les alertes de crise.
const modeleGenerique = 'template_mywcvjj';

/// Renvoie true si EmailJS a accepté l'envoi. Ne lève jamais d'erreur.
Future<bool> envoyerEmailJs(String modele, Map<String, String> params) async {
  try {
    final r = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'service_id': emailjsService, 'template_id': modele, 'user_id': emailjsCle, 'template_params': params}),
        )
        .timeout(const Duration(seconds: 15));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}
