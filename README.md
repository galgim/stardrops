# Stardrops

A card game about avoiding stars, built in Flutter for iOS and Android.

Play a card each round into one of four rows. A card joins the row ending in
the closest lower number; complete a row and you take it, along with every
star on those cards. If your card is lower than every row, you choose a row to
take instead. After ten rounds, fewest stars wins.

Solo play is against four AI opponents at three difficulty levels. Local
multiplayer seats three to five players over WiFi with no server involved —
one device hosts and hands out a join code, and the others connect straight to
it over TCP. Hosting is a one-time in-app purchase; joining a game someone
else hosts is free.

## Running it

```
flutter pub get
flutter run
```

Tests:

```
flutter test
```

To build for iOS you will need to set your own `DEVELOPMENT_TEAM` in
`ios/Runner.xcodeproj`; it is intentionally blank here.

## How it is put together

```
lib/
  game/       turn sequencing and round resolution
  logic/      AI card choice and row scoring
  models/     cards, rows, players
  net/        LAN hosting, join codes, the networked game loop
  screens/    menu, lobby, game, tutorial
  services/   on-device persistence, sound, locale, the hosting purchase
  theme/      colour, type, spacing tokens
  l10n/       .arb translation sources
```

A few things worth knowing if you read the code:

**No state management package.** `setState` and a plain `GameState` object,
deliberately. The game is a single screen with one source of truth, and a
dependency would not have earned its place.

**Localised into English, Spanish, and Korean** via `gen-l10n`. The `.arb`
files are the source of truth and the `app_localizations*.dart` files beside
them are generated. Nothing below the UI layer holds a user-facing string —
network failures return an enum and the screen translates it.

**The type scale adapts per script.** Space Grotesk carries no Hangul, so
every style declares a `fontFamilyFallback`; Korean also drops letter-spacing
and opens up the tightest line heights, since Hangul has no uppercase.
`test/type_scale_test.dart` guards both rules.

**Multiplayer is peer-to-peer.** No backend, no accounts, no analytics, and
nothing leaves the local network. See [privacy.md](privacy.md).

## Support

[support.md](support.md) — or email claytonetwork@gmail.com.
