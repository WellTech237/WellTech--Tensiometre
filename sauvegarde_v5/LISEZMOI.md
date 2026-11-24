# WellTech — démarrer le projet Flutter

Ce dossier contient le code de l'application (Version 5 de la maquette).
Étape 1 : tout fonctionne **sans Internet et sans Firebase** (comptes, mesures,
alertes, graphiques). Firebase sera ajouté à l'étape 2.

## 1. Vérifier Flutter

Dans un terminal (PowerShell) :

```
flutter doctor
```

Il faut au moins des coches vertes pour **Flutter** et **Android toolchain**,
et un émulateur Android (Android Studio › Device Manager) ou un téléphone
Android en mode développeur.

## 2. Générer les dossiers Android

Dans le dossier `C:\Mon Tensiometre` :

```
cd "C:\Mon Tensiometre"
flutter create --org com.welltech --project-name welltech --platforms android .
```

Cette commande ajoute le dossier `android/` sans écraser le code existant.

## 3. Remplacer MainActivity

Copier `android_a_copier/MainActivity.kt` vers :

```
android/app/src/main/kotlin/com/welltech/welltech/MainActivity.kt
```

(remplacer le fichier existant). C'est nécessaire pour l'empreinte digitale.

## 4. Me prévenir

Quand les étapes 2 et 3 sont faites, dis-le dans la conversation : je règle
alors les fichiers Android (autorisations des alarmes, notifications,
empreinte) directement dans ton dossier.

## 5. Lancer

```
flutter pub get
flutter test
flutter run
```

`flutter test` vérifie la logique médicale (classification, profil de risque,
alertes, PIN). Si une commande affiche une erreur, copie-la dans la
conversation.

## Organisation du code

- `lib/core/` : classification AHA/ACC 2025, grossesse, profil de risque,
  matrice d'alertes (4 niveaux), hachage du PIN.
- `lib/data/` : modèles et base SQLite chiffrée (SQLCipher).
- `lib/services/` : comptes et PIN, notifications et alarmes, lecture à voix
  haute, état de l'application.
- `lib/ui/screens/` : les 12 écrans de la Version 5.
- `test/` : tests de la logique.

## Étape 2 : Firebase (sauvegarde cloud)

1. Console Firebase : projet **WellTech**, application Android
   `com.welltech.welltech`, fichier **`google-services.json`** placé dans
   `android/app/`.
2. Authentication › E-mail/Mot de passe : activé.
3. Firestore Database : région `northamerica-northeast1`, mode production.
4. Firestore › **Règles** : coller le contenu de `firestore.rules`, puis Publier.
5. `flutter pub get` puis `flutter run`.

Fonctionnement : l'application écrit toujours d'abord sur le téléphone. Les
mesures « en attente » partent vers Firestore dès qu'Internet revient
(identifiant unique = pas de doublon). Un compte créé hors ligne est créé dans
Firebase au premier retour du réseau. Si le patient a refusé la sauvegarde
cloud dans le consentement, rien n'est envoyé.
