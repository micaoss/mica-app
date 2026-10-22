// The device's end of SPAKE2+ (the Verifier), for the mock device. It uses the
// Verifier's own formulas (Z = y·(X − w0·M), V = y·L) and is checked against
// the vectors of mica-core docs/ble-provisioning.md with a fixed y.

import 'dart:typed_data';

import 'package:mica_app/protocol/crypto.dart';
import 'package:pointycastle/export.dart' show ECPoint;

class VerifierRecord {
  VerifierRecord(this.salt, this.iterations, this.w0, this.l);

  /// What the device stores at a claim or password change.
  factory VerifierRecord.register(String pw, Uint8List salt, int iterations) {
    final w = spakeScalars(pw, salt, iterations);
    return VerifierRecord(salt, iterations, w.w0, (p256G * w.w1)!);
  }

  final Uint8List salt;
  final int iterations;
  final BigInt w0;
  final ECPoint l;
}

class VerifierResponse {
  VerifierResponse(this.shareV, this.confirmV, this.confirmP, this.schedule);

  final Uint8List shareV, confirmV, confirmP;
  final SpakeSchedule schedule;
}

/// Answers the phone's shareP. Throws [FormatException] for a bad point.
VerifierResponse respond(VerifierRecord r, String context, Uint8List shareP, {BigInt? y}) {
  final x = decodePoint(shareP);
  final yScalar = y ?? randomScalar();
  final shareV = encodePoint(((p256G * yScalar)! + (spakeN * r.w0))!);
  final z = ((x - (spakeM * r.w0)!)! * yScalar)!;
  final v = (r.l * yScalar)!;
  final s = SpakeSchedule(context, shareP, shareV, z, v, r.w0);
  return VerifierResponse(shareV, s.confirmV(shareP), s.confirmP(shareV), s);
}
