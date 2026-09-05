import 'dart:io';

import 'package:flutter/foundation.dart';

/// The join code, and the address it stands for.
///
/// There is no discovery service here on purpose. The code *is* the host's
/// address. A full IPv4 address is 32 bits — but almost no home network needs
/// all 32. Every phone on a `192.168.x.y` network agrees on the first two
/// octets, so only 16 bits are actually unknown. The length of the code says
/// which prefix it stands for:
///
///   4 chars -> 192.168.a.b        (home routers, Android hotspots)
///   5 chars -> 10.a.b.c, or 172.16-31.b.c  (iPhone hotspots live here)
///   7 chars -> any other address, spelled out in full
///
/// The alternative was Bonjour/mDNS, which would have meant a plugin, a service
/// declaration in the iOS Info.plist, an async browse-and-resolve lifecycle,
/// and silence on any network that filters multicast. Two functions replace all
/// of it, and a plain unicast connection is also the one kind of local network
/// access that doesn't drag in Apple's approval-gated multicast entitlement.
class JoinCode {
  const JoinCode._();

  /// The longest a code gets — the full-address fallback. Shorter codes are
  /// not incomplete ones; the length is what names the prefix.
  static const maxLength = 7;

  /// Crockford's base 32: the ten digits and the letters, less I, L, O and U.
  ///
  /// Plain base 36 was one line shorter, but it puts `O` beside `0` and `I`
  /// beside `1`, and this code exists to be read out loud across a table —
  /// "others join with this code" is the lobby's own wording. At four
  /// characters there is no surrounding context to correct a wrong guess from.
  /// U is left out as well, which is what stops a random code spelling
  /// something unfortunate.
  ///
  /// Five bits a character rather than base 36's five and a sixth, which
  /// costs no length at any of the three sizes: 16 bits still fit in four
  /// characters, 24 in five, 32 in seven.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// What the excluded letters are read as, so a code copied down by ear
  /// still works. U has no obvious digit to fold onto and is refused.
  static const _lookalikes = {'I': '1', 'L': '1', 'O': '0'};

  /// The port the host listens on. Fixed, so the code only carries an address.
  /// Sits well up in the ephemeral range where nothing standard lives.
  static const port = 47521;

  /// Where the 172.16-31 range starts inside the five-character number space,
  /// just past the 24 bits the 10.x range uses.
  static const _block172 = 0x1000000;

  /// Encodes a dotted IPv4 address as the shortest code that names it, or null
  /// if [ip] isn't one.
  static String? encode(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;

    final octets = <int>[];
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      octets.add(octet);
    }
    final [a, b, c, d] = octets;

    if (a == 192 && b == 168) return _encode((c << 8) | d, 4);
    if (a == 10) return _encode((b << 16) | (c << 8) | d, 5);
    if (a == 172 && b >= 16 && b <= 31) {
      return _encode(_block172 + (((b - 16) << 16) | (c << 8) | d), 5);
    }
    return _encode((a << 24) | (b << 16) | (c << 8) | d, maxLength);
  }

  /// Decodes a code back to a dotted IPv4 address, or null if it isn't one.
  ///
  /// Forgiving about how it was typed — case, spaces, and any punctuation are
  /// stripped before decoding. Strict about what it accepts after that, since
  /// the result goes straight into a socket dial.
  static String? decode(String code) {
    final cleaned = code.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final value = _decode(cleaned);
    if (value == null) return null;

    // Each length has more codes than addresses it can name, so the
    // range checks are real: a code can be well formed and still name nothing.
    switch (cleaned.length) {
      case 4:
        if (value > 0xFFFF) return null;
        return _dotted(0xC0A80000 | value);
      case 5:
        if (value < _block172) return _dotted(0x0A000000 | value);
        final offset = value - _block172;
        // Sixteen subnets of 65536, so the last real offset is 172.31.255.255
        // and nothing above it names an address encode() can produce. Letting
        // one through would dial 172.32.x.x, or 173.x.x.x further up.
        if (offset > 0xFFFFF) return null;
        return _dotted(
          0xAC000000 | ((16 + (offset >> 16)) << 16) | (offset & 0xFFFF),
        );
      case maxLength:
        if (value > 0xFFFFFFFF) return null;
        return _dotted(value);
      default:
        return null;
    }
  }

  /// A 32-bit address as dotted quad.
  static String _dotted(int value) =>
      '${(value >> 24) & 255}.${(value >> 16) & 255}'
      '.${(value >> 8) & 255}.${value & 255}';

  /// A value as a fixed-width code, since the width is what tells the decoder
  /// which prefix to put back. Callers pick a width that fits their range.
  static String _encode(int value, int width) {
    final out = List.filled(width, '0');
    for (var i = width - 1; i >= 0; i--) {
      out[i] = _alphabet[value % 32];
      value ~/= 32;
    }
    return out.join();
  }

  /// A code back to its value, or null if any character isn't in the alphabet
  /// — after reading the excluded letters as the digits they resemble.
  static int? _decode(String code) {
    var value = 0;
    for (final character in code.split('')) {
      final digit = _alphabet.indexOf(_lookalikes[character] ?? character);
      if (digit < 0) return null;
      value = value * 32 + digit;
    }
    return value;
  }

  /// This device's address on the local network, or null if it isn't on one.
  ///
  /// A phone usually has several: WiFi, and on cellular a carrier interface
  /// that other phones in the room cannot reach. Private ranges are preferred
  /// in the order they're likely to be the WiFi, because handing out a code for
  /// the cellular address would produce a code nobody can connect to.
  static Future<String?> localAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final addresses = [
        for (final i in interfaces) ...i.addresses.map((a) => a.address),
      ];
      if (addresses.isEmpty) return null;

      for (final prefix in _privatePrefixes) {
        for (final address in addresses) {
          if (prefix.hasMatch(address)) return address;
        }
      }
      // On an unusual network none of the above match. The first address beats
      // refusing to host at all — worst case the code doesn't work and the
      // player sees a connection failure rather than a dead end.
      return addresses.first;
    } catch (e) {
      debugPrint('JoinCode.localAddress failed: $e');
      return null;
    }
  }

  /// Home routers first, then the other two private ranges.
  static final _privatePrefixes = [
    RegExp(r'^192\.168\.'),
    RegExp(r'^10\.'),
    RegExp(r'^172\.(1[6-9]|2\d|3[01])\.'),
  ];
}
