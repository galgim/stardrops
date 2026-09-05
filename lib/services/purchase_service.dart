import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why a purchase didn't complete.
///
/// An enum rather than a ready-made sentence for the same reason `LanError` is
/// one: this layer has no BuildContext to look a translation up with. The
/// dialog that shows the failure has one, and maps these to localised text.
enum PurchaseError {
  /// The store isn't reachable — no network, or the device can't buy at all
  /// (parental controls, a sandbox account that isn't signed in).
  storeUnavailable,

  /// The store is up but doesn't know this product. Means the product ID is
  /// wrong, or it isn't approved and cleared for sale yet.
  productMissing,

  /// The player backed out of the payment sheet. Not an error to apologise
  /// for — the dialog stays open and says nothing.
  cancelled,

  /// The store refused the payment, or the purchase failed mid-flight.
  failed,

  /// A restore ran and found nothing to restore on this Apple ID.
  nothingToRestore,
}

/// Owns the one thing the player can buy: the right to host a local game.
///
/// Joining stays free, so nothing here gates it. Hosting is the paid half
/// because a player who was invited into someone else's game has already
/// played before they ever meet a price.
///
/// A singleton with a stream listener rather than the static helpers the other
/// services use, because the store can hand back a purchase at any moment: one
/// that completed while the app was closed, one approved by a parent hours
/// later, or one restored on a new phone. Something has to be listening the
/// whole time the app is running, and [init] starts before the first frame.
class PurchaseService extends ChangeNotifier {
  PurchaseService._();

  static PurchaseService? _instance;

  /// The app's one service. Built on first use rather than eagerly, which is
  /// what lets a test put its own in place before the real one ever touches a
  /// platform channel.
  static PurchaseService get instance => _instance ??= PurchaseService._();

  /// Replaces the singleton. Tests only — the app never reassigns it.
  @visibleForTesting
  static set instance(PurchaseService value) => _instance = value;

  /// A fresh, unshared instance. The singleton holds its entitlement for the
  /// life of the process, which is right in the app and wrong in a test suite,
  /// where one granted purchase would leak into every later test.
  @visibleForTesting
  factory PurchaseService.fresh() => PurchaseService._();

  /// Set in both stores. Lowercase with an underscore because Play Console
  /// rejects anything else, which lets one string serve both platforms.
  static const productId = 'com.claeekim.stardrop.host_game';

  static const _kOwned = 'host_game_owned';

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _owned = false;
  bool _busy = false;
  ProductDetails? _product;

  /// Whether this device may host. Read straight from the cached entitlement,
  /// so it answers instantly and offline — the store is consulted in the
  /// background, never on the path between a tap and the lobby.
  bool get canHost => _owned;

  /// True from the moment a purchase or restore is in flight until the store
  /// answers. The dialog disables its buttons on this so a double tap can't
  /// open two payment sheets.
  bool get busy => _busy;

  /// The store's own localised price string ("$1.99", "1,99 €"), or null until
  /// the product has loaded. Never build a price from a number — the store
  /// knows the player's currency and this app doesn't.
  String? get price => _product?.price;

  /// Reads the cached entitlement, then starts listening to the store.
  ///
  /// The cache is read first and awaited so [canHost] is correct before the
  /// first frame; the store lookup that follows is deliberately not awaited,
  /// because a slow or unreachable store must not hold up launch. A player who
  /// already owns the unlock gets in with no network at all.
  Future<void> init() async {
    _owned = await _readCached();

    try {
      _sub = _store.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('PurchaseService stream failed: $e'),
      );
    } catch (e) {
      debugPrint('PurchaseService.init failed: $e');
      return;
    }

    unawaited(_loadProduct());
  }

  /// Fetches the product so its localised price can be shown. Failure is not
  /// fatal and not surfaced: the paywall opens without a price rather than not
  /// opening, and the purchase itself reports its own errors.
  Future<void> _loadProduct() async {
    try {
      if (!await _store.isAvailable()) return;
      final response = await _store.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        debugPrint('PurchaseService: $productId not found in the store');
        return;
      }
      _product = response.productDetails.first;
      notifyListeners();
    } catch (e) {
      debugPrint('PurchaseService._loadProduct failed: $e');
    }
  }

  /// Starts a purchase. Returns null once the store has been handed the
  /// request — the result arrives on the stream, not from here.
  Future<PurchaseError?> buy() async {
    if (_owned || _busy) return null;

    try {
      if (!await _store.isAvailable()) return PurchaseError.storeUnavailable;

      // Re-fetched rather than trusting a product loaded at launch, which may
      // have failed while offline. A purchase is the one place worth the round
      // trip.
      if (_product == null) {
        await _loadProduct();
        if (_product == null) return PurchaseError.productMissing;
      }

      _setBusy(true);
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      // A false here means the store never opened the sheet at all.
      if (!started) {
        _setBusy(false);
        return PurchaseError.failed;
      }
      return null;
    } catch (e) {
      debugPrint('PurchaseService.buy failed: $e');
      _setBusy(false);
      return PurchaseError.failed;
    }
  }

  /// Re-grants an unlock already bought on this Apple or Google account.
  ///
  /// Apple requires a visible restore for a non-consumable — a player who
  /// reinstalls, or buys a new phone, must not be asked to pay twice. Like
  /// [buy], the result arrives on the stream.
  Future<PurchaseError?> restore() async {
    if (_busy) return null;

    try {
      if (!await _store.isAvailable()) return PurchaseError.storeUnavailable;
      _setBusy(true);
      await _store.restorePurchases();

      // restorePurchases() resolves once the store has handed over whatever it
      // found; the grants themselves land on the stream a moment afterwards.
      // With nothing to restore, nothing ever lands — so without this the
      // dialog would sit disabled forever on the commonest case of all, a
      // player tapping Restore who never bought it.
      //
      // ponytail: fixed settle window. If a slow store ever reports
      // nothing-to-restore on a real purchase, wait on the stream instead.
      await Future.delayed(const Duration(milliseconds: 600));
      _setBusy(false);
      return _owned ? null : PurchaseError.nothingToRestore;
    } catch (e) {
      debugPrint('PurchaseService.restore failed: $e');
      _setBusy(false);
      return PurchaseError.failed;
    }
  }

  /// Handles everything the store sends back, whether this app asked for it or
  /// not.
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setBusy(true);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant();
        case PurchaseStatus.canceled:
          _setBusy(false);
        case PurchaseStatus.error:
          debugPrint('PurchaseService: ${purchase.error}');
          _setBusy(false);
      }

      // Every terminated purchase must be completed, including failed and
      // restored ones. Skipping this leaves the transaction in the queue: iOS
      // redelivers it on every launch forever, and App Review rejects for it.
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
        } catch (e) {
          debugPrint('PurchaseService.completePurchase failed: $e');
        }
      }
    }
  }

  /// Grants the unlock and writes it down.
  ///
  /// The entitlement is granted in memory even if the write fails, so a full
  /// disk can't swallow a purchase the player just paid for. Worst case it is
  /// re-granted by the store on the next launch.
  Future<void> _grant() async {
    _owned = true;
    _busy = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOwned, true);
    } catch (e) {
      debugPrint('PurchaseService: could not cache the unlock: $e');
    }
  }

  /// Reads the cached entitlement, defaulting to locked.
  ///
  /// A read failure locks rather than unlocks: the store re-grants a real
  /// purchase within a second or two, and Restore is always there, so the cost
  /// of being wrong this way is a moment's delay instead of giving the product
  /// away on a broken install.
  Future<bool> _readCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kOwned) ?? false;
    } catch (e) {
      debugPrint('PurchaseService._readCached failed: $e');
      return false;
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
