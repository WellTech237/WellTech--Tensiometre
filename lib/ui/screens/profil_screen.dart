import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/risque.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/app_state.dart';
import '../../services/notifications.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'accueil_shell.dart';

/// Étape 5 sur 5 : profil santé en 5 parties (Identité, Corps, Santé,
/// Médicaments, Résumé). L'IMC et le profil de suivi se calculent en direct.
class ProfilScreen extends StatefulWidget {
  final bool premiereFois;
  const ProfilScreen({super.key, this.premiereFois = false});
  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _MedCtrl {
  final nom = TextEditingController();
  final dose = TextEditingController();
  _MedCtrl([Medicament? m]) {
    nom.text = m?.nom ?? '';
    dose.text = m?.dose ?? '';
  }
}

class _ProfilScreenState extends State<ProfilScreen> {
  late Profil p;
  int _partie = 0; // 0 à 4
  String? _erreur;
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _semaines = TextEditingController();
  final _taille = TextEditingController();
  final _poids = TextEditingController();
  final _autresInfos = TextEditingController();
  final List<_MedCtrl> _meds = [];

  static const _noms = ['pr_p1', 'pr_p2', 'pr_p3', 'pr_p4', 'pr_p5'];

  @override
  void initState() {
    super.initState();
    p = Profil.fromJson(AppState.instance.profil.toJson()); // copie modifiable
    _prenom.text = p.prenom;
    _nom.text = p.nom;
    _semaines.text = p.semainesGrossesse?.toString() ?? '';
    _taille.text = p.tailleCm?.toStringAsFixed(0) ?? '';
    _poids.text = p.poidsKg?.toStringAsFixed(0) ?? '';
    _autresInfos.text = p.autresRenseignements;
    _meds.addAll(p.medicaments.map(_MedCtrl.new));
    if (_meds.isEmpty) _meds.add(_MedCtrl());
    for (final c in [_taille, _poids]) {
      c.addListener(() => setState(() => _lireChamps()));
    }
  }

  void _lireChamps() {
    p.prenom = _prenom.text.trim();
    p.nom = _nom.text.trim();
    p.semainesGrossesse = int.tryParse(_semaines.text);
    p.tailleCm = double.tryParse(_taille.text.replaceAll(',', '.'));
    p.poidsKg = double.tryParse(_poids.text.replaceAll(',', '.'));
    p.autresRenseignements = _autresInfos.text.trim();
    p.medicaments = _meds.map((m) => Medicament(nom: m.nom.text.trim(), dose: m.dose.text.trim())).where((m) => m.nom.isNotEmpty).toList();
    p.prendMedicaments = p.medicaments.isNotEmpty;
  }

  String? _verifier(int partie) {
    switch (partie) {
      case 0:
        if (p.prenom.isEmpty || p.nom.isEmpty) return context.tr('pr_err_nom');
        if (p.naissance == null) return context.tr('pr_err_naissance');
      case 1:
        final t = p.tailleCm, w = p.poidsKg;
        if (t == null || t < 100 || t > 230) return context.tr('pr_err_taille');
        if (w == null || w < 25 || w > 300) return context.tr('pr_err_poids');
        if (p.femme && p.enceinte && (p.semainesGrossesse == null || p.semainesGrossesse! < 1 || p.semainesGrossesse! > 42)) return context.tr('pr_err_semaines');
    }
    return null;
  }

  void _aller(int partie) {
    _lireChamps();
    // On ne saute pas une partie incomplète en avançant.
    for (var i = _partie; i < partie; i++) {
      final err = _verifier(i);
      if (err != null) {
        setState(() {
          _partie = i;
          _erreur = err;
        });
        return;
      }
    }
    setState(() {
      _partie = partie;
      _erreur = null;
    });
  }

  Future<void> _enregistrer() async {
    _lireChamps();
    if (!p.femme) p.enceinte = false;
    final etat = AppState.instance;
    await etat.enregistrerProfil(p);
    if (widget.premiereFois) {
      await Notifications.instance.programmerMesures(etat.heureMatin, etat.heureSoir);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AccueilShell()), (_) => false);
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _choisirNaissance() async {
    final d = await showDatePicker(
      context: context,
      initialDate: p.naissance ?? DateTime(1965, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (d != null) setState(() => p.naissance = d);
  }

  Widget _libelle(String k, {String? emoji}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Row(children: [
          if (emoji != null) ...[Emo(emoji, taille: 20), const SizedBox(width: 8)],
          Expanded(child: Text(context.tr(k), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _champ(TextEditingController c, {TextInputType? clavier, List<TextInputFormatter>? filtres, String? aide}) => TextField(
        controller: c,
        keyboardType: clavier,
        inputFormatters: filtres,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(hintText: aide),
        onChanged: (_) => _lireChamps(),
      );

  Widget _choix(String texte, bool actif, VoidCallback onTap) => Expanded(child: Puce(texte: texte, active: actif, onTap: onTap));

  // --- Parties ---------------------------------------------------------------
  List<Widget> _identite() => [
        _libelle('pr_prenom'),
        _champ(_prenom),
        _libelle('pr_nom'),
        _champ(_nom),
        _libelle('pr_naissance', emoji: '🎂'),
        Material(
          color: Wt.blanc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Wt.bordure, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _choisirNaissance,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Text(p.naissance == null ? context.tr('pr_choisir_date') : dateCourte(p.naissance!) + ' ${p.naissance!.year}', style: const TextStyle(fontSize: 18))),
                const Icon(Icons.calendar_month_outlined, color: Wt.violetFonce),
              ]),
            ),
          ),
        ),
        if (p.age != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('pr_age', {'a': p.age}), style: const TextStyle(fontSize: 15, color: Wt.gris, fontWeight: FontWeight.w700))),
      ];

  List<Widget> _corps() {
    final imc = p.imc;
    final (cle, fond, encre) = imc == null
        ? ('pr_imc_vide', Wt.violetClair, Wt.violetTexte)
        : imc < 18.5
            ? ('pr_imc_m', Wt.jaune, Wt.jauneTexte)
            : imc < 25
                ? ('pr_imc_n', Wt.vertClair, Wt.vertTexte)
                : imc < 30
                    ? ('pr_imc_s', Wt.jaune, Wt.jauneTexte)
                    : ('pr_imc_o', Wt.rougeClair, Wt.rougeTexte);
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_libelle('pr_taille'), _champ(_taille, clavier: TextInputType.number, filtres: [FilteringTextInputFormatter.digitsOnly])])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_libelle('pr_poids'), _champ(_poids, clavier: const TextInputType.numberWithOptions(decimal: true))])),
      ]),
      const SizedBox(height: 12),
      Carte(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⚖️ ${context.tr('pr_imc')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.gris)),
              Text(imc == null ? '—' : nombre(imc), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(999)),
            child: Text(context.tr(cle), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: encre)),
          ),
        ]),
      ),
      _libelle('pr_sexe'),
      Row(children: [
        _choix(context.tr('pr_femme'), p.femme, () => setState(() => p.femme = true)),
        const SizedBox(width: 10),
        _choix(context.tr('pr_homme'), !p.femme, () => setState(() => p.femme = false)),
      ]),
      if (p.femme) ...[
        _libelle('pr_enceinte', emoji: '🤰'),
        Row(children: [
          _choix(context.tr('oui'), p.enceinte, () => setState(() => p.enceinte = true)),
          const SizedBox(width: 10),
          _choix(context.tr('non'), !p.enceinte, () => setState(() => p.enceinte = false)),
        ]),
        if (p.enceinte) ...[
          _libelle('pr_semaines'),
          _champ(_semaines, clavier: TextInputType.number, filtres: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 10),
          Encadre('ℹ️', context.tr('pr_grossesse_info')),
        ],
      ],
    ];
  }

  List<Widget> _sante() => [
        const SizedBox(height: 6),
        Text(context.tr('pr_antecedents'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
        const SizedBox(height: 12),
        GrillePuces([
          for (var i = 0; i < maladiesListe.length; i++)
            Puce(
              texte: nomMaladie(maladiesListe[i]),
              emoji: emojisMaladies[i],
              active: p.maladies.contains(maladiesListe[i]),
              onTap: () => setState(() => p.maladies.contains(maladiesListe[i]) ? p.maladies.remove(maladiesListe[i]) : p.maladies.add(maladiesListe[i])),
            ),
          Puce(texte: context.tr('pr_avc'), emoji: '🧠', active: p.avc, onTap: () => setState(() => p.avc = !p.avc)),
        ]),
        const SizedBox(height: 10),
        Puce(
          texte: context.tr('pr_aucun'),
          emoji: '✅',
          active: p.maladies.isEmpty && !p.avc,
          onTap: () => setState(() {
            p.maladies.clear();
            p.avc = false;
          }),
        ),
      ];

  List<Widget> _medicaments() => [
        _libelle('pr_medic'),
        for (var i = 0; i < _meds.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Carte(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  const Emo('💊', taille: 22),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _meds[i].nom, style: const TextStyle(fontSize: 17), decoration: InputDecoration(hintText: context.tr('pr_med_nom')), onChanged: (_) => _lireChamps())),
                  if (_meds.length > 1)
                    IconButton(tooltip: context.tr('supprimer'), icon: const Icon(Icons.close, color: Wt.gris), onPressed: () => setState(() => _meds.removeAt(i))),
                ]),
                const SizedBox(height: 8),
                TextField(controller: _meds[i].dose, style: const TextStyle(fontSize: 17), decoration: InputDecoration(hintText: context.tr('pr_med_dose')), onChanged: (_) => _lireChamps()),
              ]),
            ),
          ),
        OutlinedButton.icon(onPressed: () => setState(() => _meds.add(_MedCtrl())), icon: const Icon(Icons.add), label: Text(context.tr('pr_ajouter'))),
        _libelle('pr_autres'),
        TextField(controller: _autresInfos, maxLines: 3, style: const TextStyle(fontSize: 17), decoration: InputDecoration(hintText: context.tr('pr_autres_aide'))),
      ];

  List<Widget> _resume() {
    _lireChamps();
    final risque = calculerRisque(p);
    Widget ligne(String k, String v, int partie) => InkWell(
          onTap: () => setState(() => _partie = partie),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr(k), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Wt.gris)),
                  Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
              ),
              Text(context.tr('modifier'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
            ]),
          ),
        );
    final ant = [...p.maladies.map(nomMaladie), if (p.avc) context.tr('pr_avc')];
    return [
      Text(context.tr('pr_verifier'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Carte(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          ligne('pr_p1', '${p.prenom} ${p.nom}${p.age != null ? ' · ${context.tr('pr_age', {'a': p.age})}' : ''}', 0),
          const Divider(height: 1),
          ligne('pr_p2', '${p.tailleCm?.round() ?? '—'} cm · ${p.poidsKg == null ? '—' : nombre(p.poidsKg!, 0)} kg${p.imc != null ? ' · ${context.tr('pr_imc')} ${nombre(p.imc!)}' : ''}${p.grossesseActive ? ' · 🤰' : ''}', 1),
          const Divider(height: 1),
          ligne('pr_p3', ant.isEmpty ? context.tr('pr_aucun') : ant.join(', '), 2),
          const Divider(height: 1),
          ligne('pr_p4', p.medicaments.map((m) => '${m.nom} ${m.dose}'.trim()).join(', '), 3),
        ]),
      ),
      const SizedBox(height: 12),
      Carte(
        couleur: Wt.violetClair,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🛡️ ${context.tr('pr_risque')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Wt.violetTexte)),
          Text(risque.libelle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Wt.violetTexte)),
          const SizedBox(height: 4),
          Text(risque.effet, style: const TextStyle(fontSize: 15, color: Wt.violetTexte, height: 1.45)),
          const SizedBox(height: 4),
          Text(context.tr('pr_risque_exp'), style: const TextStyle(fontSize: 14, color: Wt.violetTexte, height: 1.45)),
        ]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final contenu = switch (_partie) {
      0 => _identite(),
      1 => _corps(),
      2 => _sante(),
      3 => _medicaments(),
      _ => _resume(),
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
          if (widget.premiereFois) ...[Etapes(n: 5, total: 5, libelle: context.tr('pr_etape')), const SizedBox(height: 14)],
          EnTete(context.tr('pr_titre'), retour: !widget.premiereFois),
          Text(context.tr('pr_partie', {'n': _partie + 1, 'nom': context.tr(_noms[_partie])}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Wt.violetFonce)),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < 5; i++) ...[
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _partie,
                  label: context.tr(_noms[i]),
                  child: Material(
                    color: i == _partie ? Wt.violet : (i < _partie ? Wt.violetClair : Wt.blanc),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _aller(i),
                      child: SizedBox(
                        height: 48,
                        child: Center(child: Text(i < _partie ? '✓' : '${i + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: i == _partie ? Wt.blanc : Wt.violetFonce))),
                      ),
                    ),
                  ),
                ),
              ),
              if (i < 4) const SizedBox(width: 6),
            ],
          ]),
          ...contenu,
          if (_erreur != null) ...[const SizedBox(height: 12), Encadre('⚠️', _erreur!, fond: Wt.rougeClair, encre: Wt.rougeTexte)],
          const SizedBox(height: 22),
          Row(children: [
            if (_partie > 0) ...[
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _partie--), child: Text(context.tr('precedent')))),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _partie < 4 ? () => _aller(_partie + 1) : _enregistrer,
                child: Text(context.tr(_partie < 4 ? 'suivant' : 'pr_enregistrer')),
              ),
            ),
          ]),
          if (widget.premiereFois) TextButton(onPressed: _enregistrer, child: Text(context.tr('pr_plus_tard'))),
        ]),
      ),
    );
  }
}
