import 'dart:io';

import 'package:flutter/foundation.dart';

/// The join code, and the address it stands for.
///
/// There is no discovery service here on purpose. The code *is* the host's
/// address: an IPv4 address is 32 bits, and 32 bits in base 36 is seven
/// characters. The joining phone decodes those seven characters straight back
/// into an address and dials it.
///
/// The alternative was Bonjour/mDNS, which would have meant a plugin, a service
/// declaration in the iOS Info.plist, an async browse-and-resolve lifecycle,
/// and silence on any network that filters multicast. Two functions replace all
/// of it, and a plain unicast connection is also the one kind of local network
/// access that doesn't drag in Apple's approval-gated multicast entitlement.
class JoinCode {
  const JoinCode._();

  /// Codes are always this long, so a half-typed one is obviously incomplete.
  static const length = 7;

  /// The port the host listens on. Fixed, so the code only carries an address.
  /// Sits well up in the ephemeral range where nothing standard lives.
  static const port = 47521;

  /// Encodes a dotted IPv4 address as a [length]-character code, or null if
  /// [ip] isn't one.
  static String? encode(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;

    var value = 0;
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      value = value * 256 + octet;
    }
    return value.toRadixString(36).toUpperCase().padLeft(length, '0');
  }

  /// Decodes a code back to a dotted IPv4 address, or null if it isn't one.
  ///
  /// Forgiving about how it was typed — case, spaces, and the dashes the code
  /// is displayed with are all stripped before decoding. Strict about what it
  /// accepts after that, since the result goes straight into a socket dial.
  static String? decode(String code) {
    final cleaned = code.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (cleaned.length != length) return null;

    final value = int.tryParse(cleaned, radix: 36);
    // Seven base-36 digits reach past 2^32, so the range check is real: a code
    // can be well-formed and still not name an address.
    if (value == null || value < 0 || value > 0xFFFFFFFF) return null;

    return '${(value >> 24) & 255}.${(value >> 16) & 255}'
        '.${(value >> 8) & 255}.${value & 255}';
  }

  /// Groups a code for display — easier to read out loud than seven
  /// undifferentiated characters.
  static String format(String code) => code.length == length
      ? '${code.substring(0, 3)}-${code.substring(3, 5)}-${code.substring(5)}'
      : code;

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
