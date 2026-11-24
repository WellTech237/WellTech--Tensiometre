// Mémorise, dans le navigateur, les visites guidées déjà vues par chaque
// compte (une fois par compte et par navigateur). Web seulement.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:web/web.dart' as web;

String _cle(String nom) => 'wt_visite_${nom}_${FirebaseAuth.instance.currentUser?.uid ?? 'anonyme'}';

bool visiteVue(String nom) {
  try {
    return web.window.localStorage.getItem(_cle(nom)) != null;
  } catch (_) {
    return true; // stockage indisponible : on ne force pas la visite
  }
}

void marquerVisiteVue(String nom) {
  try {
    web.window.localStorage.setItem(_cle(nom), DateTime.now().toIso8601String());
  } catch (_) {}
}
