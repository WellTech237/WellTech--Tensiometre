import 'package:flutter/material.dart';

import '../../core/risque.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/cloud.dart';
import '../../theme.dart';
import '../partage.dart';
import '../widgets.dart';
import 'accueil_shell.dart';
import 'aide_screen.dart';
import 'alertes_screen.dart';
import 'bienvenue_screen.dart';
import 'deverrouillage_screen.dart';
import 'messages_screen.dart';
import 'profil_screen.dart';

/// Moi : profil, santé (alertes, messages), réglages (langue, texte, voix,
/// rappels, contact), données (synchro, consentements, suppression).
class MoiScreen extends StatefulWidget {
  const MoiScreen({super.key});
  @override
  State<MoiScreen> createState() => _MoiScreenState();
}

class _MoiScreenState extends State<MoiScreen> {
  bool _confirmer = false;

  void _ouvrir(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  /// Rapport PDF de suivi : la patiente choisit la période, puis à qui
  /// l'envoyer (médecin, proche, ou simplement l'enregistrer).
  Future<void> _rapport() async {
    final jours = await choisirPeriodeRapport(context);
    if (jours == null || !mounted) return;
    await preparerEtPartager(context, () => AppState.instance.partagerRapport(jours: jours));
  }

  Future<void> _heure(bool matin) async {
    final e = AppState.instance;
    final t = await showTimePicker(context: context, initialTime: matin ? e.heureMatin : e.heureSoir, helpText: context.tr(matin ? 'moi_matin' : 'moi_soir'));
    if (t == null) return;
    await e.changerHeures(matin ? t : e.heureMatin, matin ? e.heureSoir : t);
  }

  Future<void> _contact() async {
    final e = AppState.instance;
    final nom = TextEditingController(text: e.contact?.nom ?? '');
    final tel = TextEditingController(text: e.contact?.telephone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('moi_contact')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, decoration: InputDecoration(labelText: c.tr('moi_contact_nom'))),
          const SizedBox(height: 10),
          TextField(controller: tel, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: c.tr('moi_contact_tel'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('annuler'))),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 48)), onPressed: () => Navigator.pop(c, true), child: Text(c.tr('enregistrer'))),
        ],
      ),
    );
    if (ok == true) await e.changerContact(ContactUrgence(nom.text.trim(), tel.text.trim()));
  }

  /// Mon médecin : la patiente entre le code donné par son médecin.
  Future<void> _medecin() async {
    final e = AppState.instance;
    final code = TextEditingController();
    String? erreur;
    var enCours = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text('🩺 ${c.tr('moi_medecin')}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (e.medecinNom.isNotEmpty) ...[
                Text(c.tr('mm_lie', {'n': e.medecinNom}), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
              ],
              Text(c.tr('mm_explication'), style: const TextStyle(fontSize: 16, height: 1.45)),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
                decoration: InputDecoration(labelText: c.tr('mm_code'), hintText: 'ABC-1234'),
              ),
              if (erreur != null) ...[
                const SizedBox(height: 10),
                Text('⚠ $erreur', style: const TextStyle(fontSize: 15, color: Wt.rougeTexte, fontWeight: FontWeight.w700)),
              ],
              if (e.medecinNom.isNotEmpty) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Wt.rougeTexte),
                  onPressed: enCours
                      ? null
                      : () async {
                          setD(() => enCours = true);
                          final err = await e.delierMedecin();
                          if (!c.mounted) return;
                          if (err == null) {
                            Navigator.pop(c);
                          } else {
                            setD(() {
                              erreur = err;
                              enCours = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.link_off),
                  label: Text(c.tr('mm_retirer')),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('fermer'))),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
              onPressed: enCours
                  ? null
                  : () async {
                      setD(() {
                        enCours = true;
                        erreur = null;
                      });
                      final err = await e.lierMedecin(code.text);
                      if (!c.mounted) return;
                      if (err == null) {
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('mm_ok', {'n': e.medecinNom}))));
                      } else {
                        setD(() {
                          erreur = err;
                          enCours = false;
                        });
                      }
                    },
              child: Text(c.tr('mm_lier')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer() async {
    await AppState.instance.db.effacerTout();
    await AuthService.instance.deconnecterEtEffacer();
    await AppState.instance.charger();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BienvenueScreen()), (_) => false);
  }

  Widget _section(String titre, List<Widget> enfants) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Carte(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris)),
            const SizedBox(height: 4),
            ...enfants,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final e = AppState.instance;
    final p = e.profil;
    final ui = ReglagesUi.instance;
    return ListenableBuilder(
      listenable: e,
      builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        EnTete(context.tr('moi_titre')),
        Material(
          color: Wt.violet,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _ouvrir(const ProfilScreen()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Wt.blanc, shape: BoxShape.circle),
                  child: Text(
                    '${p.prenom.isEmpty ? '' : p.prenom[0]}${p.nom.isEmpty ? '' : p.nom[0]}'.toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Wt.violetFonce),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.prenom} ${p.nom}${p.age != null ? ' · ${context.tr('pr_age', {'a': p.age})}' : ''}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Wt.blanc)),
                    Text(context.tr('moi_profil_s', {'r': e.risque.libelle}), style: const TextStyle(fontSize: 15, color: Color(0xFFE4E1FF), fontWeight: FontWeight.w600)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Wt.blanc),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _section(context.tr('moi_sante'), [
          LigneInfo(
            emoji: '🔔',
            titre: context.tr('moi_alertes'),
            sousTitre: e.alertesNonLues > 0 ? context.tr('moi_non_lues', {'n': e.alertesNonLues}) : context.tr('moi_aucune_alerte'),
            onTap: () => _ouvrir(const AlertesScreen()),
          ),
          LigneInfo(emoji: '💬', titre: context.tr('moi_messages'), onTap: () => _ouvrir(const MessagesScreen())),
          LigneInfo(
            emoji: '🩺',
            titre: context.tr('moi_medecin'),
            sousTitre: e.medecinNom.isEmpty ? context.tr('mm_aucun') : e.medecinNom,
            onTap: _medecin,
          ),
          LigneInfo(emoji: '📄', titre: context.tr('moi_rapport'), sousTitre: context.tr('moi_rapport_s'), onTap: _rapport),
        ]),
        _section(context.tr('moi_reglages'), [
          LigneInfo(emoji: '🌐', titre: context.tr('moi_langue'), droite: const SelecteurLangue()),
          const SizedBox(height: 6),
          Text(context.tr('moi_texte'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in [(1.0, 'moi_t_normal'), (1.15, 'moi_t_grand'), (1.3, 'moi_t_tres')]) ...[
              Expanded(child: Puce(texte: context.tr(t.$2), active: ui.echelle == t.$1, onTap: () => e.changerEchelle(t.$1))),
              if (t.$1 != 1.3) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Wt.fond, borderRadius: BorderRadius.circular(14)),
            child: Text(context.tr('moi_apercu'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Emo('🔊', taille: 24, boite: 46),
            title: Text(context.tr('moi_voix'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            value: e.voixAuto,
            onChanged: e.changerVoixAuto,
          ),
          LigneInfo(emoji: '☀️', titre: context.tr('moi_matin'), droite: Text(AppState.formatHeure(e.heureMatin), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), onTap: () => _heure(true)),
          LigneInfo(emoji: '🌙', titre: context.tr('moi_soir'), droite: Text(AppState.formatHeure(e.heureSoir), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), onTap: () => _heure(false)),
          // Rappel de médicament : l'heure vient du plan du médecin (non modifiable ici).
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Emo('💊', taille: 24, boite: 46),
            title: Text(context.tr('moi_rappel_medic'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            subtitle: Text(
              e.plan == null
                  ? context.tr('moi_rappel_medic_aucun')
                  : context.tr('moi_rappel_medic_sous', {'m': e.plan!.medicament, 'h': heureTexte(e.plan!.heure, e.plan!.minute)}),
              style: const TextStyle(fontSize: 15),
            ),
            value: e.rappelMedic && e.plan != null,
            onChanged: e.plan == null ? null : (v) => e.changerRappelMedic(actif: v),
          ),
          if (e.rappelMedic && e.plan != null)
            SwitchListTile(
              contentPadding: const EdgeInsets.only(left: 46),
              title: Text(context.tr('moi_relance_medic'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              subtitle: Text(context.tr('moi_relance_medic_sous'), style: const TextStyle(fontSize: 15)),
              value: e.relanceMedic,
              onChanged: (v) => e.changerRappelMedic(relance: v),
            ),
          LigneInfo(
            emoji: '📞',
            titre: context.tr('moi_contact'),
            sousTitre: e.contact == null ? context.tr('moi_contact_vide') : '${e.contact!.nom} · ${e.contact!.telephone}',
            onTap: _contact,
          ),
        ]),
        _section(context.tr('moi_donnees'), [
          FutureBuilder<(String, DateTime?, bool)>(
            future: (() async => (
                  await AuthService.instance.statutCloud(),
                  await Cloud.instance.derniereSynchro(),
                  await AuthService.instance.consentementCloud(),
                ))(),
            builder: (context, s) {
              final d = s.data;
              String sous;
              if (!Cloud.instance.pret) {
                sous = context.tr('moi_sync_non_config');
              } else if (d != null && !d.$3) {
                sous = context.tr('moi_sync_refusee');
              } else {
                sous = d?.$2 == null ? context.tr('moi_sync_jamais') : context.tr('moi_sync_le', {'d': dateHeure(d!.$2!)});
                if (e.dernierMessageSynchro.isNotEmpty) sous = '$sous\n${e.dernierMessageSynchro}';
              }
              return LigneInfo(
                emoji: '☁️',
                fondEmoji: Wt.vertClair,
                titre: context.tr('moi_sync'),
                sousTitre: sous,
                droite: IconButton(
                  tooltip: context.tr('moi_sync_maintenant'),
                  style: IconButton.styleFrom(side: const BorderSide(color: Wt.violet, width: 2), minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.sync, color: Wt.violetFonce),
                  onPressed: () async {
                    final m = await e.synchroniser();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
                  },
                ),
              );
            },
          ),
          LigneInfo(emoji: '📤', titre: context.tr('moi_exporter'), sousTitre: context.tr('moi_exporter_s'), onTap: () => preparerEtPartager(context, AppState.instance.exporterMesures)),
          LigneInfo(emoji: '❓', titre: context.tr('moi_aide'), onTap: () => _ouvrir(const AideScreen())),
          LigneInfo(emoji: '🎓', titre: context.tr('vg_revoir'), sousTitre: context.tr('vg_revoir_s'), onTap: AccueilShell.revoirVisite),
          if (!_confirmer)
            LigneInfo(emoji: '🗑️', fondEmoji: Wt.rougeClair, titre: context.tr('moi_supprimer'), onTap: () => setState(() => _confirmer = true))
          else
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Wt.rougeClair, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(context.tr('moi_supprimer_q'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Wt.rougeTexte)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _confirmer = false), child: Text(context.tr('moi_garder')))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Wt.rouge, minimumSize: const Size(0, 54)), onPressed: _supprimer, child: Text(context.tr('supprimer')))),
                ]),
              ]),
            ),
        ]),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DeverrouillageScreen()), (_) => false),
          icon: const Icon(Icons.lock_outline),
          label: Text(context.tr('moi_verrouiller')),
        ),
        const SizedBox(height: 10),
        Text(context.tr('moi_version'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Wt.gris)),
      ]),
    );
  }
}
