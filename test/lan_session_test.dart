import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/net/join_code.dart';
import 'package:stardrop/net/lan_session.dart';

/// The transport, exercised over real sockets on the loopback address.
///
/// The host binds to every interface, so a code for 127.0.0.1 reaches it
/// without depending on what this machine's WiFi address happens to be. That
/// makes the whole join handshake testable here rather than only on two phones.
void main() {
  /// Polls until [condition] holds, because socket traffic lands whenever it
  /// lands. Fails the test rather than hanging forever if it never does.
  Future<void> waitFor(
    String what,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Starts a host, or skips the test on a machine with no network at all.
  Future<LanHost?> startHost(String name) async {
    final host = LanHost(hostName: name);
    if (await host.start()) return host;
    await host.dispose();
    markTestSkipped('no local network available: ${host.error}');
    return null;
  }

  final loopback = JoinCode.encode('127.0.0.1')!;

  test('a joiner appears in the roster with a seat', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final client = LanClient();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });

    expect(await client.connect(loopback, 'Alex'), isTrue);
    await waitFor('the roster to sync', () => client.names.length == 2);

    expect(host.names, ['Clay', 'Alex']);
    expect(client.names, ['Clay', 'Alex']);
    expect(client.seat, 1, reason: 'the host holds seat 0');
  });

  test('three players fill three seats in join order', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final alex = LanClient();
    final sam = LanClient();
    addTearDown(() async {
      await alex.dispose();
      await sam.dispose();
      await host.dispose();
    });

    expect(await alex.connect(loopback, 'Alex'), isTrue);
    await waitFor('Alex to be seated', () => alex.seat == 1);
    expect(await sam.connect(loopback, 'Sam'), isTrue);
    await waitFor('Sam to be seated', () => sam.seat == 2);

    expect(host.names, ['Clay', 'Alex', 'Sam']);
    expect(host.canStart, isTrue, reason: 'three is enough to play');
  });

  test('the host cannot start until enough players have joined', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final client = LanClient();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });

    expect(host.canStart, isFalse, reason: 'alone at the table');
    expect(await client.connect(loopback, 'Alex'), isTrue);
    await waitFor('the roster to sync', () => host.names.length == 2);
    expect(host.canStart, isFalse, reason: 'two is still short of $kMinPlayers');
  });

  test('a name arriving off the wire is cleaned like a typed one', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final blank = LanClient();
    final long = LanClient();
    addTearDown(() async {
      await blank.dispose();
      await long.dispose();
      await host.dispose();
    });

    await blank.connect(loopback, '   ');
    await waitFor('the blank name to seat', () => host.names.length == 2);
    await long.connect(loopback, 'A' * 100);
    await waitFor('the long name to seat', () => host.names.length == 3);

    expect(host.names[1], 'You', reason: 'blank falls back to the default');
    expect(host.names[2].length, 12, reason: 'an over-long name is capped');
  });

  test('a sixth player is refused rather than seated', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final joiners = [for (var i = 0; i < 5; i++) LanClient()];
    addTearDown(() async {
      for (final c in joiners) {
        await c.dispose();
      }
      await host.dispose();
    });

    // Four fill the table alongside the host.
    for (var i = 0; i < 4; i++) {
      expect(await joiners[i].connect(loopback, 'P$i'), isTrue);
      await waitFor('P$i to be seated', () => host.names.length == i + 2);
    }
    expect(host.names.length, kMaxPlayers);

    // The fifth connects, is told no, and never reaches the roster.
    await joiners[4].connect(loopback, 'Late');
    await waitFor(
      'the refusal',
      () => joiners[4].error != null || joiners[4].hostLost,
    );
    expect(host.names.length, kMaxPlayers, reason: 'the table did not grow');
  });

  test('a player leaving the lobby renumbers the seats below them', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final alex = LanClient();
    final sam = LanClient();
    addTearDown(() async {
      await sam.dispose();
      await host.dispose();
    });

    expect(await alex.connect(loopback, 'Alex'), isTrue);
    await waitFor('Alex to be seated', () => alex.seat == 1);
    expect(await sam.connect(loopback, 'Sam'), isTrue);
    await waitFor('Sam to be seated', () => sam.seat == 2);

    // Alex quits the lobby. Sam moves up, and has to be told so — otherwise
    // Sam would keep playing seat 2 in a three-seat game.
    await alex.dispose();
    await waitFor('the host to notice', () => host.names.length == 2);
    await waitFor('Sam to move up', () => sam.seat == 1);

    expect(host.names, ['Clay', 'Sam']);
    expect(sam.names, ['Clay', 'Sam']);
  });

  test('a joiner is told when the host goes away', () async {
    final host = await startHost('Clay');
    if (host == null) return;
    final client = LanClient();
    addTearDown(() async => client.dispose());

    expect(await client.connect(loopback, 'Alex'), isTrue);
    await waitFor('the roster to sync', () => client.names.length == 2);

    await host.dispose();
    await waitFor('the client to notice', () => client.hostLost);
    expect(client.connected, isFalse);
  });
}
