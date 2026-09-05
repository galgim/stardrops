import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/net/join_code.dart';

/// The code is the host's address, so a decode bug doesn't produce a wrong
/// game — it produces a dial to a stranger's device or a failure the player
/// can't explain. Both directions are checked, plus everything that should be
/// refused before it reaches a socket.
void main() {
  test('a code round-trips back to the address it came from', () {
    for (final ip in [
      '192.168.1.47',
      '192.168.0.1',
      '192.168.255.255',
      '10.0.0.2',
      '10.255.255.255',
      '192.168.68.93',
      '172.16.0.0',
      '172.16.31.255',
      '172.20.10.3', // an iPhone hotspot
      '172.31.255.255',
      '127.0.0.1',
      '0.0.0.0',
      '255.255.255.255',
    ]) {
      final code = JoinCode.encode(ip);
      expect(code, isNotNull, reason: '$ip should encode');
      expect(JoinCode.decode(code!), ip, reason: '$ip did not round-trip');
    }
  });

  /// The whole point of the change: a code's length is what names its prefix,
  /// so each family has to come out at the length its decoder branch expects,
  /// and the common home address has to be the short one.
  test('a code is only as long as the address needs', () {
    // Five bits a character, so dropping four letters from base 36 costs no
    // length: 16 bits still fit in four, 24 in five, 32 in seven.
    expect(JoinCode.encode('192.168.1.47')!.length, 4);
    expect(JoinCode.encode('192.168.255.255')!.length, 4);
    expect(JoinCode.encode('10.0.0.2')!.length, 5);
    expect(JoinCode.encode('172.20.10.3')!.length, 5);
    expect(JoinCode.encode('127.0.0.1')!.length, JoinCode.maxLength);
    expect(JoinCode.encode('8.8.8.8')!.length, JoinCode.maxLength);
  });

  test('different addresses never share a code', () {
    final ips = [
      '192.168.1.1',
      '192.168.1.2',
      '10.0.0.1',
      '10.0.1.0',
      '172.16.0.1',
      '172.17.0.1',
      '127.0.0.1',
      '8.8.8.8',
    ];
    expect({for (final ip in ips) JoinCode.encode(ip)}.length, ips.length);
  });

  test('a code is accepted however it was typed', () {
    final code = JoinCode.encode('192.168.1.47')!;
    expect(JoinCode.decode(code.toLowerCase()), '192.168.1.47');
    expect(JoinCode.decode(' $code '), '192.168.1.47');
    expect(JoinCode.decode('00-9F'), '192.168.1.47');
  });

  /// The alphabet leaves out I, L, O and U precisely because they are misread,
  /// so a player who hears "oh-oh-nine-eff" and types the letter has to land
  /// on the same address as one who types the digit. Without the fold they
  /// would get a refusal they cannot explain, holding a code that looks right.
  test('the letters left out of the alphabet are read as their digits', () {
    expect(JoinCode.encode('192.168.1.47'), '009F');
    for (final typed in ['OO9F', 'oo9f', 'O09F']) {
      expect(JoinCode.decode(typed), '192.168.1.47', reason: typed);
    }
    // 127.0.0.1 is 1ZG0001 — I and L both stand in for the 1s.
    expect(JoinCode.encode('127.0.0.1'), '1ZG0001');
    expect(JoinCode.decode('IZG000L'), '127.0.0.1');
  });

  /// U is the one excluded letter with no digit it could plausibly be, so it
  /// is refused rather than folded onto something arbitrary.
  test('U is not in the alphabet and is not guessed at', () {
    expect(JoinCode.decode('U09F'), isNull);
    for (final code in [
      JoinCode.encode('192.168.1.47')!,
      JoinCode.encode('10.0.0.2')!,
      JoinCode.encode('172.20.10.3')!,
      JoinCode.encode('8.8.8.8')!,
    ]) {
      expect(code.contains('U'), isFalse, reason: code);
      expect(code.contains(RegExp('[ILO]')), isFalse, reason: code);
    }
  });

  test('nonsense is refused rather than dialled', () {
    for (final bad in [
      '', // nothing typed
      'ABC', // no prefix uses three characters
      'ABCDEF', // nor six
      'ABCDEFGH', // one too many
      '!!!!!!!', // right length, not base 36
      'ZZZZ', // 4 chars, past the 192.168 space
      'ZZZZZ', // 5 chars, past the end of the 172 block
      'ZZZZZZZ', // 7 chars, past the end of the address space
      // One past the last real 172 offset. The block holds sixteen subnets of
      // 65536, and a looser check here decodes to 172.32.0.0 and upwards —
      // addresses encode() can never produce, dialled as if they were real.
      'H0000',
      'ZZZZW', // further into the same gap
    ]) {
      expect(JoinCode.decode(bad), isNull, reason: '"$bad" should be refused');
    }
  });

  test('malformed addresses do not produce a code', () {
    for (final bad in [
      '192.168.1', // too few octets
      '192.168.1.1.1', // too many
      '192.168.1.256', // octet out of range
      '192.168.1.-1',
      'not.an.ip.address',
      '',
    ]) {
      expect(JoinCode.encode(bad), isNull, reason: '"$bad" should not encode');
    }
  });
}
