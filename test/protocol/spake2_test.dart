import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/bytes.dart';
import 'package:mica_app/protocol/spake2.dart';

class _Vector {
  const _Vector(this.a, this.b, this.w, this.x, this.pA, this.y, this.pB, this.ke, this.kcA,
      this.kcB, this.cA, this.cB);
  final String a, b, w, x, pA, y, pB, ke, kcA, kcB, cA, cB;
}

// RFC 9382 appendix B, SPAKE2-P256-SHA256-HKDF-HMAC, no AAD.
const _vectors = [
  _Vector(
    'server',
    'client',
    '2ee57912099d31560b3a44b1184b9b4866e904c49d12ac5042c97dca461b1a5f',
    '43dd0fd7215bdcb482879fca3220c6a968e66d70b1356cac18bb26c84a78d729',
    '04a56fa807caaa53a4d28dbb9853b9815c61a411118a6fe516a8798434751470'
        'f9010153ac33d0d5f2047ffdb1a3e42c9b4e6be662766e1eeb4116988ede5f912c',
    'dcb60106f276b02606d8ef0a328c02e4b629f84f89786af5befb0bc75b6e66be',
    '0406557e482bd03097ad0cbaa5df82115460d951e3451962f1eaf4367a420676'
        'd09857ccbc522686c83d1852abfa8ed6e4a1155cf8f1543ceca528afb591a1e0b7',
    '0e0672dc86f8e45565d338b0540abe69',
    '00c12546835755c86d8c0db7851ae86f',
    'a9fa3406c3b781b93d804485430ca27a',
    '58ad4aa88e0b60d5061eb6b5dd93e80d9c4f00d127c65b3b35b1b5281fee38f0',
    'd3e2e547f1ae04f2dbdbf0fc4b79f8ecff2dff314b5d32fe9fcef2fb26dc459b',
  ),
  _Vector(
    '',
    'client',
    '0548d8729f730589e579b0475a582c1608138ddf7054b73b5381c7e883e2efae',
    '403abbe3b1b4b9ba17e3032849759d723939a27a27b9d921c500edde18ed654b',
    '04a897b769e681c62ac1c2357319a3d363f610839c4477720d24cbe32f5fd8'
        '5f44fb92ba966578c1b712be6962498834078262caa5b441ecfa9d4a9485720e918a',
    '903023b6598908936ea7c929bd761af6039577a9c3f9581064187c3049d87065',
    '04e0f816fd1c35e22065d5556215c097e799390d16661c386e0ecc84593974'
        'a61b881a8c82327687d0501862970c64565560cb5671f696048050ca66ca5f8cc7fc',
    '642f05c473c2cd79909f9a841e2f30a7',
    'c6be376fc7cd1301fd0a13adf3e7bffd',
    'b7243f4ae60440a49b3f8cab3c1fba07',
    '47d29e6666af1b7dd450d571233085d7a9866e4d49d2645e2df975489521232b',
    '3313c5cefc361d27fb16847a91c2a73b766ffa90a4839122a9b70a2f6bd1d6df',
  ),
  _Vector(
    'server',
    '',
    '626e0cdc7b14c9db3e52a0b1b3a768c98e37852d5db30febe0497b14eae8c254',
    '07adb3db6bc623d3399726bfdbfd3d15a58ea776ab8a308b00392621291f9633',
    '04f88fb71c99bfffaea370966b7eb99cd4be0ff1a7d335caac4211c4afd855e2'
        'e15a873b298503ad8ba1d9cbb9a392d2ba309b48bfd7879aefd0f2cea6009763b0',
    'b6a4fc8dbb629d4ba51d6f91ed1532cf87adec98f25dd153a75accafafedec16',
    '040c269d6be017dccb15182ac6bfcd9e2a14de019dd587eaf4bdfd353f031101'
        'e7cca177f8eb362a6e83e7d5e729c0732e1b528879c086f39ba0f31a9661bd34db',
    '005184ff460da2ce59062c87733c299c',
    'f3da53604f0aeecea5a33be7bddf6edf',
    '9e3f86848736f159bd92b6e107ec6799',
    'bc9f9bbe99f26d0b2260e6456e05a86196a3307ec6663a18bf6ac825736533b2',
    'c2370e1bf813b086dff0d834e74425a06e6390f48f5411900276dcccc5a297ec',
  ),
  _Vector(
    '',
    '',
    '7bf46c454b4c1b25799527d896508afd5fc62ef4ec59db1efb49113063d70cca',
    '8cef65df64bb2d0f83540c53632de911b5b24b3eab6cc74a97609fd659e95473',
    '04a65b367a3f613cf9f0654b1b28a1e3a8a40387956c8ba6063e8658563890f4'
        '6ca1ef6a676598889fc28de2950ab8120b79a5ef1ea4c9f44bc98f585634b46d66',
    'd7a66f64074a84652d8d623a92e20c9675c61cb5b4f6a0063e4648a2fdc02d53',
    '04589f13218822710d98d8b2123a079041052d9941b9cf88c6617ddb2fcc0494'
        '662eea8ba6b64692dc318250030c6af045cb738bc81ba35b043c3dcb46adf6f58d',
    'fc6374762ba5cf11f4b2caa08b2cd1b9',
    '5dbd2f477166b7fb6d61febbd77a5563',
    '7689b4654407a5faeffdc8f18359d8a3',
    'dfb4db8d48ae5a675963ea5e6c19d98d4ea028d8e898dad96ea19a80ade95dca',
    'd0f0609d1613138d354f7e95f19fb556bf52d751947241e8c7118df5ef0ae175',
  ),
];

BigInt _int(String h) => BigInt.parse(h, radix: 16);

void main() {
  for (final (i, v) in _vectors.indexed) {
    test('RFC 9382 vector ${i + 1}', () {
      final a = Spake2.a(utf8.encode(v.a), utf8.encode(v.b), _int(v.w), scalar: _int(v.x));
      final b = Spake2.b(utf8.encode(v.a), utf8.encode(v.b), _int(v.w), scalar: _int(v.y));
      expect(hex(a.message), v.pA);
      expect(hex(b.message), v.pB);

      final ka = a.finish(b.message);
      final kb = b.finish(a.message);
      expect(hex(ka.ke), v.ke);
      expect(hex(ka.kcA), v.kcA);
      expect(hex(ka.kcB), v.kcB);
      expect(hex(ka.confirmation), v.cA);
      expect(hex(kb.confirmation), v.cB);
      expect(ka.verify(kb.confirmation), isTrue);
      expect(kb.verify(ka.confirmation), isTrue);
      expect(hex(kb.ke), v.ke);
    });
  }

  test('different passwords give different keys and fail confirmation', () {
    final id = utf8.encode('x');
    final a = Spake2.a(id, id, BigInt.from(1234));
    final b = Spake2.b(id, id, BigInt.from(1235));
    final ka = a.finish(b.message);
    final kb = b.finish(a.message);
    expect(hex(ka.ke), isNot(hex(kb.ke)));
    expect(kb.verify(ka.confirmation), isFalse);
  });

  test('a point off the curve is refused', () {
    final id = utf8.encode('x');
    final a = Spake2.a(id, id, BigInt.from(1));
    final bad = fromHex(_vectors[0].pB)..[64] ^= 1;
    expect(() => a.finish(bad), throwsA(isA<FormatException>()));
  });

  test('a compressed or truncated point is refused', () {
    final id = utf8.encode('x');
    final a = Spake2.a(id, id, BigInt.from(1));
    final good = fromHex(_vectors[0].pB);
    expect(() => a.finish(good.sublist(0, 33)), throwsA(isA<FormatException>()));
    expect(() => a.finish(good.sublist(1)), throwsA(isA<FormatException>()));
  });

  test('fresh scalars give fresh messages', () {
    final id = utf8.encode('x');
    final w = BigInt.from(42);
    expect(hex(Spake2.a(id, id, w).message), isNot(hex(Spake2.a(id, id, w).message)));
  });
}
