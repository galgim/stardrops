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
      '10.0.0.2',
      '172.16.31.255',
      '0.0.0.0',
      '255.255.255.255',
    ]) {
      final code = JoinCode.encode(ip);
      expect(code, isNotNull, reason: '$ip should encode');
      expect(code!.length, JoinCode.length, reason: '$ip gave a short code');
      expect(JoinCode.decode(code), ip, reason: '$ip did not round-trip');
    }
  });

  test('different addresses never share a code', () {
    final codes = {
      for (final ip in ['192.168.1.1', '192.168.1.2', '10.0.0.1', '10.0.1.0'])
        JoinCode.encode(ip),
    };
    expect(codes.length, 4);
  });

  test('a code is accepted however it was typed', () {
    final code = JoinCode.encode('192.168.1.47')!;
    expect(JoinCode.decode(code.toLowerCase()), '192.168.1.47');
    expect(JoinCode.decode(JoinCode.format(code)), '192.168.1.47');
    expect(JoinCode.decode(' $code '), '192.168.1.47');
  });

  test('nonsense is refused rather than dialled', () {
    for (final bad in [
      '', // nothing typed
      'ABC', // half a code
      'ABCDEFGH', // one too many
      '!!!!!!!', // right length, not base 36
      'ZZZZZZZ', // well-formed base 36, past the end of the address space
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

  test('the displayed grouping is only cosmetic', () {
    final code = JoinCode.encode('192.168.1.47')!;
    expect(JoinCode.format(code).replaceAll('-', ''), code);
  });
}
