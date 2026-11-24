import 'package:flutter_test/flutter_test.dart';
import 'package:welltech/core/classification.dart';
import 'package:welltech/core/pin.dart';
import 'package:welltech/core/risque.dart';
import 'package:welltech/data/models.dart';

void main() {
  group('Classification AHA/ACC 2025', () {
    test('catégories adultes', () {
      expect(classer(115, 75), Grade.normale);
      expect(classer(125, 75), Grade.elevee);
      expect(classer(125, 82), Grade.grade1); // TAD 80-89 suffit
      expect(classer(135, 70), Grade.grade1);
      expect(classer(152, 94), Grade.grade2);
      expect(classer(138, 92), Grade.grade2); // TAD >= 90 suffit
      expect(classer(181, 100), Grade.grade3);
      expect(classer(170, 121), Grade.grade3);
      expect(classer(180, 120), Grade.grade2); // « plus de » 180/120
    });

    test('grossesse', () {
      expect(classerGrossesse(138, 88), Grade.normale);
      expect(classerGrossesse(142, 85), Grade.grade2);
      expect(classerGrossesse(160, 100), Grade.grade3);
      expect(classerGrossesse(150, 110), Grade.grade3);
    });

    test('valeurs impossibles refusées', () {
      expect(verifierValeurs(tas: 152, tad: 94, pouls: 78), isNull);
      expect(verifierValeurs(tas: 15, tad: 94), isNotNull);
      expect(verifierValeurs(tas: 90, tad: 94), isNotNull); // TAS <= TAD
      expect(verifierValeurs(tas: 120, tad: 80, pouls: 300), isNotNull);
    });
  });

  group('Profil de risque', () {
    test('AVC = très élevé, grossesse prioritaire', () {
      expect(calculerRisque(Profil(avc: true)), Risque.tresEleve);
      expect(calculerRisque(Profil(femme: true, enceinte: true, avc: true)), Risque.grossesse);
      expect(calculerRisque(Profil(femme: false, enceinte: true)), Risque.standard);
    });

    test('nombre de facteurs', () {
      expect(calculerRisque(Profil(maladies: {'Diabète'})), Risque.modere);
      expect(calculerRisque(Profil(maladies: {'Diabète'}, tailleCm: 162, poidsKg: 82)), Risque.eleve); // IMC 31,2
      expect(calculerRisque(Profil(maladies: {'Maladie cardiaque'})), Risque.eleve);
    });
  });

  group('Matrice d’alertes', () {
    test('grade 3 + signe d’alarme = urgence', () {
      final d = deciderAlerte(grade: Grade.grade3, symptomesCoches: ['Faiblesse'], symptomesAutres: [], risque: Risque.standard);
      expect(d.niveau, 4);
    });

    test('symptôme « Autre » seul ne déclenche pas l’urgence', () {
      final d = deciderAlerte(grade: Grade.grade3, symptomesCoches: [], symptomesAutres: ['Vertiges'], risque: Risque.standard);
      expect(d.niveau, 3);
    });

    test('profil très élevé monte d’un niveau', () {
      final normal = deciderAlerte(grade: Grade.grade2, symptomesCoches: [], symptomesAutres: [], risque: Risque.standard);
      final avc = deciderAlerte(grade: Grade.grade2, symptomesCoches: [], symptomesAutres: [], risque: Risque.tresEleve);
      expect(normal.niveau, 2);
      expect(avc.niveau, 3);
    });

    test('signe grave avec une tension de stade 2 = 911 (maquette V9)', () {
      final d = deciderAlerte(grade: Grade.grade2, symptomesCoches: ['Douleur à la poitrine'], symptomesAutres: [], risque: Risque.standard);
      expect(d.niveau, 4);
    });

    test('normale sans symptôme = information', () {
      expect(deciderAlerte(grade: Grade.normale, symptomesCoches: [], symptomesAutres: [], risque: Risque.standard).niveau, 1);
    });
  });

  test('PIN : même secret, même hachage ; autre secret, autre hachage', () {
    final sel = Hacheur.nouveauSel();
    final h = Hacheur.hacher('482915', sel);
    expect(Hacheur.egal(h, Hacheur.hacher('482915', sel)), isTrue);
    expect(Hacheur.egal(h, Hacheur.hacher('482916', sel)), isFalse);
  });
}
