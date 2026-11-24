// Courriel aux administrateurs à chaque demande de compte médecin, via
// EmailJS (service gratuit qui envoie depuis le Gmail WellTech).
// Les adresses des admins ne sont PAS ici : elles sont dans le modèle EmailJS
// (champ « To Email »). Pour ajouter un admin : modifier le modèle, rien à
// redéployer. Ces trois identifiants ne sont pas secrets (prévus pour le web).
// Le courriel ne contient aucune donnée de santé.

import '../l10n.dart';
import '../services/emailjs.dart';

/// Courriel automatique au médecin après la décision de l'administrateur :
/// compte activé, demande refusée (avec motif) ou compte suspendu.
/// Renvoie true si l'envoi est accepté.
Future<bool> notifierMedecin({
  required String email,
  required String nom,
  required String decision, // valide | refuse | suspendu
  String motif = '',
}) {
  final cle = switch (decision) {
    'valide' => 'ok',
    'suspendu' => 'susp',
    _ => 'refus',
  };
  return envoyerEmailJs(modeleGenerique, {
    'to_email': email,
    'sujet': trL('ad_mail_${cle}_sujet'),
    'message': trL('ad_mail_${cle}_corps', {'n': nom, 'm': motif.isEmpty ? '—' : motif}),
  });
}

/// Alerte aux administrateurs à chaque demande de compte médecin.
/// Un échec ne bloque jamais l'inscription : la demande est déjà enregistrée
/// et visible dans l'espace Administration.
Future<bool> notifierAdmins({
  required String nom,
  required String email,
  required String telephone,
  required String numeroOrdre,
  bool renvoi = false,
}) {
  return envoyerEmailJs(modeleDemande, {
    'nom': renvoi ? '$nom (${trL('notif_renvoi')})' : nom,
    'email': email,
    'telephone': telephone,
    'numero_ordre': numeroOrdre,
    'date': dateHeure(DateTime.now()),
  });
}
