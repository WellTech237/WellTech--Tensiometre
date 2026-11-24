// Rapport PDF de suivi (4 semaines), téléchargé dans le navigateur du
// médecin. Le document lui-même est construit par lib/commun/rapport_pdf.dart,
// le même code que le rapport partagé depuis l'appli de la patiente.

import '../commun/rapport_pdf.dart';
import 'depot.dart';
import 'telechargement.dart';

DonneesRapport donneesDuDossier(Dossier d, Medecin? medecin) => DonneesRapport(
      profil: d.profil,
      medecinNom: medecin?.nom ?? '',
      plan: d.plan,
      mesures: d.mesures,
      prises: d.prises,
      historique: d.historique,
      notes: d.notes.values.toList(),
      auteur: medecin?.nom ?? 'WellTech',
    );

Future<void> genererEtTelechargerRapport(Dossier d, Medecin? medecin, {int jours = 28}) async {
  final octets = await genererRapport(donneesDuDossier(d, medecin), jours: jours);
  telechargerFichier(octets, nomFichierRapport(d.profil), 'application/pdf');
}
