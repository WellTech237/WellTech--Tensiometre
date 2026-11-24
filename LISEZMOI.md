# WellTech — application mobile (version 0.9, maquette V9)

## Tester la nouvelle version

Dans PowerShell, téléphone branché en USB (débogage USB activé) :

```
cd "C:\Mon Tensiometre"
flutter pub get
flutter test
flutter run
```

- `flutter pub get` ajoute `flutter_localizations` (français / anglais).
  La police Atkinson Hyperlegible est incluse dans `assets/fonts` (marche sans Internet).
- `flutter test` vérifie les calculs (4 grandeurs, dérivée, intégrale,
  limites, statut de contrôle, modèle d'équations différentielles, alertes).
- `flutter run` installe l'application sur le téléphone.

Si une commande affiche une erreur, copiez le texte rouge dans la conversation.

Conseil : désinstallez d'abord l'ancienne version de WellTech du téléphone
pour repartir de l'écran de bienvenue (choix de la langue).

## Ce qui a changé (V9)

- Bilingue FR / EN : bouton 🌐 en haut de chaque écran, réglage dans « Moi ».
- Police très lisible, textes ≥ 14 px, 3 tailles de texte, icônes repères.
- Nouveaux écrans : Bienvenue, Sécurité (code PIN), Traitement (heure de
  chaque prise), Messages, Moi, Aide, Suivi (remplace Graphiques).
- Calculs du client dans `lib/core/controle.dart` :
  - Pp = TAS − TAD, Pm = TAD + ⅓ (TAS − TAD) ;
  - cible (120 / 80), erreur = mesure − cible ;
  - dérivée (tendance, mmHg / semaine) ;
  - intégrale (erreur accumulée, mmHg·jour) ;
  - limites (% dans la plage, jour de retour) ;
  - statut très bien / partiellement / très mal contrôlée.
- Modèle d'équations différentielles du projet dans `lib/core/modele_edo.dart`
  (solution exacte + vérification Runge-Kutta 4 + correcteur de dose réservé
  au médecin : l'application de la patiente ne propose jamais de dose).
- Firebase devient facultatif pour compiler : sans `google-services.json`,
  l'application se construit et fonctionne en mode 100 % local.

## Firebase (projet welltech-fb14)

- `android/app/google-services.json` active Firebase ; sans ce fichier,
  l'application reste 100 % locale.
- Firestore : base `(default)` à Montréal (`northamerica-northeast1`).
- **Après toute modification de `firestore.rules`, coller son contenu dans
  Firebase › Firestore › Règles et cliquer sur Publier.**
- Données envoyées (si la patiente l'accepte dans le consentement) :
  - `users/{uid}` : profil ; le champ `plan` (dose) est réservé au médecin ;
  - `users/{uid}/mesures/{uuid}` : mesures avec les 4 grandeurs ; jamais
    effacées, une mesure annulée est marquée `annulee: true` ;
  - `users/{uid}/prises/{AAAA-MM-JJ}` : prise du jour (pris / oubli / annule) ;
  - `users/{uid}/messages/{uuid}` : messages (`de_moi: false` = médecin).

## Espace médecin (site web) — `lib/main_medecin.dart`

Même projet, mêmes calculs que l'app (4 grandeurs, dérivée, intégrale,
limites, modèle EDO, correcteur PID). Fichiers : `lib/medecin/`.

Écrans : connexion · liste des patientes (urgences en haut) · dossier
(graphique, indicateurs, détail + note, avant/après, plan de traitement,
prises, messages) · simulation de dose · rapport PDF.

Mise en route (une seule fois) :
1. `flutter create --platforms=web .` (ajoute le dossier `web/`).
2. `lib/medecin/config_web.dart` : configuration web Firebase (déjà remplie).
3. Publier `firestore.rules`.
4. Compte ADMINISTRATEUR (une seule fois) : Authentication › Ajouter un
   utilisateur ; copier son UID ; Firestore › collection `admins` ›
   document = cet UID, champ `nom` (texte).
5. `flutter run -d chrome -t lib/main_medecin.dart`

Comptes médecins :
- Le médecin clique « Créer un compte médecin » : nom complet, courriel,
  téléphone, numéro d'ordre, mot de passe (choisi par lui). Son compte est
  « en attente » : aucun accès.
- L'administrateur se connecte au même portail (espace Administration),
  vérifie le numéro dans le registre public de l'Ordre, puis Valide / Refuse
  (avec motif) / Suspend. Bouton « Prévenir par courriel » : message prêt.
- Le médecin validé voit son code (ex. MBG-4821) ; la patiente l'entre dans
  l'app : Moi › Mon médecin.
- Mot de passe : choisi à l'inscription, modifiable (icône clé), « oublié ».

## Ancienne version

Les fichiers d'avant la V9 sont gardés dans `sauvegarde_v5/`.

## Organisation du code

- `lib/core/` : classification AHA/ACC 2025, calculs du client, modèle EDO,
  profil de risque, symptômes et alertes, hachage du PIN.
- `lib/data/` : base SQLite chiffrée (mesures, alertes, prises, messages).
- `lib/services/` : état de l'application, comptes, notifications, voix, cloud.
- `lib/l10n.dart` et `lib/l10n_textes.dart` : textes FR / EN (modifier un
  texte dans les deux langues).
- `lib/ui/` : écrans de la maquette V9.
