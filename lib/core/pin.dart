import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hachage PBKDF2-HMAC-SHA256 : le PIN et le mot de passe ne sont jamais
/// stockés en clair, seulement un hachage salé.
class Hacheur {
  static const iterations = 60000;

  static String nouveauSel() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hacher(String secret, String selB64) {
    final cle = utf8.encode(secret);
    final sel = base64Decode(selB64);
    final hmac = Hmac(sha256, cle);
    // Un seul bloc de 32 octets suffit ici.
    final bloc = Uint8List.fromList([...sel, 0, 0, 0, 1]);
    var u = hmac.convert(bloc).bytes;
    final res = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < res.length; k++) {
        res[k] ^= u[k];
      }
    }
    return base64Encode(res);
  }

  /// Comparaison en temps constant.
  static bool egal(String a, String b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return d == 0;
  }
}
