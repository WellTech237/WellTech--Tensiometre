import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n.dart';

/// Alarmes de mesure, rappels du mode crise et alertes.
/// Tout est programmé sur le téléphone : fonctionne sans Internet.
class Notifications {
  Notifications._();
  static final instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Appelé quand l'utilisateur touche une notification (payload).
  void Function(String payload)? onOuverture;

  static const idMatin = 100, idSoir = 101, idReport = 110, idAlerte = 300;
  static const idCriseBase = 200; // 200 à 205
  static const idMedicBase = 400; // 400 à 441 : prise + relance, 21 jours
  static const joursMedic = 21;

  static const _canalMesure = AndroidNotificationDetails(
    'mesures', 'Rappels de mesure',
    channelDescription: 'Alarme à l’heure de la mesure de tension',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    playSound: true,
    enableVibration: true,
  );

  static const _canalUrgence = AndroidNotificationDetails(
    'urgence', 'Urgence et mode crise',
    channelDescription: 'Alertes de niveau 3 et 4, mesures toutes les 5 minutes',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    playSound: true,
    enableVibration: true,
  );

  static const _canalMedic = AndroidNotificationDetails(
    'medicament', 'Rappels de médicament',
    channelDescription: 'Rappel à l’heure de la prise prescrite par le médecin',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    playSound: true,
    enableVibration: true,
  );

  static const _canalInfo = AndroidNotificationDetails(
    'info', 'Informations',
    channelDescription: 'Alertes de niveau 1 et 2',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final nom = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(nom));
    } catch (_) {
      // On garde le fuseau par défaut si le nom n'est pas reconnu.
    }
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null) onOuverture?.call(p);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Payload de la notification qui a lancé l'application, s'il y en a une.
  Future<String?> payloadAuDemarrage() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) return d?.notificationResponse?.payload;
    return null;
  }

  tz.TZDateTime _prochaine(TimeOfDay h) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h.hour, h.minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Programme les 2 mesures quotidiennes (répétées chaque jour).
  Future<void> programmerMesures(TimeOfDay matin, TimeOfDay soir) async {
    await _plugin.cancel(idMatin);
    await _plugin.cancel(idSoir);
    for (final e in [(idMatin, matin, trL('notif_matin')), (idSoir, soir, trL('notif_soir'))]) {
      await _plugin.zonedSchedule(
        e.$1,
        trL('notif_mesure_titre'),
        e.$3,
        _prochaine(e.$2),
        const NotificationDetails(android: _canalMesure),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'alarme_mesure',
      );
    }
  }

  Future<void> reporter(Duration d) => _plugin.zonedSchedule(
        idReport,
        trL('notif_rappel_titre'),
        trL('notif_rappel_texte'),
        tz.TZDateTime.now(tz.local).add(d),
        const NotificationDetails(android: _canalMesure),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'alarme_mesure',
      );

  /// Mode crise : une notification toutes les 5 min pendant 30 min.
  Future<void> programmerCrise(DateTime debut) async {
    await annulerCrise();
    for (var i = 1; i <= 6; i++) {
      final quand = tz.TZDateTime.from(debut.add(Duration(minutes: 5 * i)), tz.local);
      await _plugin.zonedSchedule(
        idCriseBase + i - 1,
        i < 6 ? trL('notif_crise_titre') : trL('notif_crise_fin_titre'),
        i < 6 ? trL('notif_crise_texte') : trL('notif_crise_fin_texte'),
        quand,
        const NotificationDetails(android: _canalUrgence),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'crise',
      );
    }
  }

  Future<void> annulerCrise() async {
    for (var i = 0; i < 6; i++) {
      await _plugin.cancel(idCriseBase + i);
    }
  }

  /// Rappels de prise de médicament : un rappel à l'heure du plan et, si
  /// demandé, une relance [relanceMin] minutes plus tard. Programmés jour par
  /// jour sur 21 jours (et non « tous les jours ») pour pouvoir sauter un jour
  /// déjà noté : quand la patiente note sa prise, la relance du jour disparaît.
  /// Reprogrammés à chaque ouverture de l'application, prise notée ou nouveau plan.
  Future<void> programmerMedicament({
    required String? medicament,
    required double doseMg,
    required int heure,
    required int minute,
    required bool actif,
    required bool relance,
    int relanceMin = 30,
    Set<DateTime> joursNotes = const {},
  }) async {
    for (var i = 0; i < joursMedic * 2; i++) {
      await _plugin.cancel(idMedicBase + i);
    }
    if (!actif || medicament == null || medicament.trim().isEmpty) return;
    final dose = doseMg > 0 ? ' ${nombre(doseMg)} mg' : '';
    for (final r in horairesMedicament(
      maintenant: DateTime.now(),
      heure: heure,
      minute: minute,
      relance: relance,
      relanceMin: relanceMin,
      joursNotes: joursNotes,
    )) {
      await _plugin.zonedSchedule(
        idMedicBase + r.indice,
        trL(r.relance ? 'notif_medic_relance_titre' : 'notif_medic_titre'),
        trL(r.relance ? 'notif_medic_relance_texte' : 'notif_medic_texte', {'m': medicament, 'd': dose}),
        tz.TZDateTime.from(r.quand, tz.local),
        const NotificationDetails(android: _canalMedic),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'medicament',
      );
    }
  }

  /// Alerte immédiate (niveaux 2 à 4).
  Future<void> alerter(int niveau, String titre, String texte) => _plugin.show(
        idAlerte,
        'WellTech · $titre',
        texte,
        NotificationDetails(android: niveau >= 3 ? _canalUrgence : _canalInfo),
        payload: niveau >= 4 ? 'crise' : 'alertes',
      );
}

/// Un rappel de médicament à programmer ([indice] : 2k = prise du jour k,
/// 2k+1 = relance du jour k).
class RappelMedic {
  final int indice;
  final DateTime quand;
  final bool relance;
  const RappelMedic(this.indice, this.quand, this.relance);
}

/// Calcule les rappels de médicament des [jours] prochains jours (fonction
/// pure, testée) : on saute les jours déjà notés et les heures passées.
/// Les dates sont construites jour par jour (sûr au changement d'heure).
List<RappelMedic> horairesMedicament({
  required DateTime maintenant,
  required int heure,
  required int minute,
  required bool relance,
  int relanceMin = 30,
  Set<DateTime> joursNotes = const {},
  int jours = Notifications.joursMedic,
}) {
  final out = <RappelMedic>[];
  for (var k = 0; k < jours; k++) {
    final prise = DateTime(maintenant.year, maintenant.month, maintenant.day + k, heure, minute);
    if (joursNotes.contains(DateTime(prise.year, prise.month, prise.day))) continue;
    if (prise.isAfter(maintenant)) out.add(RappelMedic(2 * k, prise, false));
    final rappel = DateTime(prise.year, prise.month, prise.day, heure, minute + relanceMin);
    if (relance && rappel.isAfter(maintenant)) out.add(RappelMedic(2 * k + 1, rappel, true));
  }
  return out;
}
