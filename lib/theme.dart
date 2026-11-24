import 'package:flutter/material.dart';

/// Couleurs de la maquette WellTech V9.
/// Règle : données des graphiques en bleus, cible en vert,
/// orange / rouge réservés aux alertes. Code couleur AHA des niveaux inchangé.
class Wt {
  static const fond = Color(0xFFF6F5F1);
  static const blanc = Color(0xFFFFFFFF);
  static const encre = Color(0xFF0E1726);
  static const gris = Color(0xFF46505E); // texte secondaire, 8:1 sur blanc
  static const bordure = Color(0xFFE3E1DA);
  static const violet = Color(0xFF4433C9); // couleur principale
  static const violetFonce = Color(0xFF2F2399);
  static const violetClair = Color(0xFFECEAFB);
  static const violetTexte = Color(0xFF1F1A5C);

  // États
  static const vertClair = Color(0xFFE3F5EC);
  static const vertTexte = Color(0xFF0B4F37);
  static const vert = Color(0xFF0B7A55);
  static const jaune = Color(0xFFFFF3D6);
  static const jauneTexte = Color(0xFF5C3300);
  static const orangeClair = Color(0xFFFFE8D6);
  static const orangeTexte = Color(0xFF5C2200);
  static const rougeClair = Color(0xFFFEE4E2);
  static const rougeTexte = Color(0xFF8F1D14);
  static const rouge = Color(0xFFB42318);
  static const crise = Color(0xFF7A1A13);

  // Graphiques
  static const serieTas = Color(0xFF3B2FC0);
  static const serieTad = Color(0xFF1F7FC4);
  static const seriePm = Color(0xFF8B80E6);
  static const seriePp = Color(0xFF7A8799);
  static const cibleTas = Color(0xFFE4F3EA);
  static const cibleTad = Color(0xFFEDF6F0);
  static const evSymptome = Color(0xFFC2410C);
}

/// Taille de base généreuse (17) : lisible à tout âge.
ThemeData welltechTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Wt.violet, primary: Wt.violet, surface: Wt.fond),
    scaffoldBackgroundColor: Wt.fond,
    // Police très lisible (Atkinson Hyperlegible), incluse dans assets/fonts.
    // Les caractères absents (≥, →…) utilisent la police du téléphone.
    fontFamily: 'Atkinson',
  );
  TextTheme texte = base.textTheme;
  texte = texte.apply(bodyColor: Wt.encre, displayColor: Wt.encre).copyWith(
        bodyMedium: texte.bodyMedium?.copyWith(fontSize: 17, height: 1.45, color: Wt.encre),
        bodyLarge: texte.bodyLarge?.copyWith(fontSize: 18, height: 1.45, color: Wt.encre),
        bodySmall: texte.bodySmall?.copyWith(fontSize: 15, color: Wt.gris),
      );
  return base.copyWith(
    textTheme: texte,
    appBarTheme: const AppBarTheme(backgroundColor: Wt.fond, foregroundColor: Wt.encre, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Wt.blanc,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Wt.bordure, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Wt.bordure, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Wt.violet, width: 2.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Wt.rouge, width: 2.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Wt.violet,
        foregroundColor: Wt.blanc,
        disabledBackgroundColor: const Color(0xFFD9D6EE),
        disabledForegroundColor: Wt.violetFonce,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Wt.violetFonce,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Wt.violet, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Wt.violetFonce,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Wt.violet : null)),
    switchTheme: SwitchThemeData(trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Wt.violet : null)),
  );
}
