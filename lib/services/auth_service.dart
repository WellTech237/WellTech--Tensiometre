import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../core/pin.dart';
import '../l10n.dart';

/// Authentification hybride, étape 1 (sans Firebase) :
/// - le compte est créé sur le téléphone (inscription possible hors ligne) ;
/// - il reste « en attente » tant que Firebase n'a pas créé le compte cloud
///   (branché à l'étape 2) ;
/// - le déverrouillage se fait par empreinte ou PIN, avec ou sans Internet.
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  static const _coffre = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final _bio = LocalAuthentication();

  static const maxEssais = 5; // ensuite délai
  static const essaisAvantBlocage = 10; // ensuite reconnexion en ligne

  Future<bool> consentementDonne() async => (await _coffre.read(key: 'consentement')) != null;

  Future<void> enregistrerConsentement({required bool cloud, required bool notifications, bool partage = false}) =>
      _coffre.write(key: 'consentement', value: 'v2;cloud=$cloud;notif=$notifications;partage=$partage;${DateTime.now().toIso8601String()}');

  Future<String?> consentementBrut() => _coffre.read(key: 'consentement');

  /// Partage avec le médecin (choisi en entrant son code) : gardé dans le
  /// consentement, avec la date du changement.
  Future<void> changerPartage(bool partage) async {
    final c = await _coffre.read(key: 'consentement');
    if (c == null) return;
    final base = c.replaceAll(RegExp(r'partage=(true|false)'), 'partage=$partage');
    await _coffre.write(key: 'consentement', value: '$base;partage_maj=${DateTime.now().toIso8601String()}');
  }

  Future<bool> compteExiste() async => (await _coffre.read(key: 'email')) != null;

  Future<String?> email() => _coffre.read(key: 'email');

  /// « en_attente » : créé hors ligne, à envoyer à Firebase au retour du réseau.
  Future<String> statutCloud() async => (await _coffre.read(key: 'statut_cloud')) ?? 'en_attente';

  Future<bool> consentementCloud() async => (await _coffre.read(key: 'consentement'))?.contains('cloud=true') ?? false;

  /// Mot de passe gardé chiffré dans le coffre-fort UNIQUEMENT jusqu'à la
  /// création du compte cloud, puis effacé.
  Future<String?> mdpEnAttente() => _coffre.read(key: 'mdp_attente');

  Future<void> marquerCloudActif() async {
    await _coffre.write(key: 'statut_cloud', value: 'synchro');
    await _coffre.delete(key: 'mdp_attente');
  }

  Future<void> creerCompteLocal({required String email, required String motDePasse, required String pin, required bool biometrie}) async {
    final selMdp = Hacheur.nouveauSel();
    final selPin = Hacheur.nouveauSel();
    // Le hachage est volontairement lent : on le fait hors du fil d'affichage.
    final hMdp = await Isolate.run(() => Hacheur.hacher(motDePasse, selMdp));
    final hPin = await Isolate.run(() => Hacheur.hacher(pin, selPin));
    await _coffre.write(key: 'email', value: email.trim().toLowerCase());
    await _coffre.write(key: 'mdp_sel', value: selMdp);
    await _coffre.write(key: 'mdp_hash', value: hMdp);
    await _coffre.write(key: 'pin_sel', value: selPin);
    await _coffre.write(key: 'pin_hash', value: hPin);
    await _coffre.write(key: 'biometrie', value: biometrie ? '1' : '0');
    await _coffre.write(key: 'statut_cloud', value: 'en_attente');
    await _coffre.write(key: 'mdp_attente', value: motDePasse);
    await _coffre.write(key: 'essais', value: '0');
  }

  Future<bool> biometrieActivee() async => (await _coffre.read(key: 'biometrie')) == '1';

  Future<bool> biometrieDisponible() async {
    try {
      return await _bio.canCheckBiometrics && await _bio.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> deverrouillerBiometrie() async {
    try {
      return await _bio.authenticate(
        localizedReason: trL('bio_raison'),
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<int> essaisRestants() async {
    final e = int.tryParse(await _coffre.read(key: 'essais') ?? '0') ?? 0;
    return (essaisAvantBlocage - e).clamp(0, essaisAvantBlocage);
  }

  /// Renvoie null si le PIN est bon, sinon un message.
  Future<String?> verifierPin(String pin) async {
    final essais = int.tryParse(await _coffre.read(key: 'essais') ?? '0') ?? 0;
    if (essais >= essaisAvantBlocage) {
      return trL('pin_bloque');
    }
    final sel = await _coffre.read(key: 'pin_sel');
    final attendu = await _coffre.read(key: 'pin_hash');
    if (sel == null || attendu == null) return trL('pin_aucun');
    final h = await Isolate.run(() => Hacheur.hacher(pin, sel));
    if (Hacheur.egal(h, attendu)) {
      await _coffre.write(key: 'essais', value: '0');
      return null;
    }
    final n = essais + 1;
    await _coffre.write(key: 'essais', value: '$n');
    if (n >= maxEssais) {
      await Future<void>.delayed(Duration(seconds: (n - maxEssais + 1) * 5));
    }
    return trL('pin_faux', {'n': essaisAvantBlocage - n});
  }

  /// Efface le compte du téléphone. La clé de la base chiffrée est gardée
  /// (la base est vidée à part), sinon elle ne pourrait plus être ouverte.
  Future<void> deconnecterEtEffacer() async {
    final tout = await _coffre.readAll();
    for (final k in tout.keys) {
      if (k != 'db_key') await _coffre.delete(key: k);
    }
  }
}
