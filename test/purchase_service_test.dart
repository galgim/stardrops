import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// The interface package rather than `in_app_purchase` itself: the latter
// re-exports only the data types, not `InAppPurchasePlatform`, which is the
// class `_FakeStore` has to extend to stand in for a real store.
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardrop/services/purchase_service.dart';

/// A store that answers however a test needs it to.
///
/// Extends the platform interface the plugin already delegates to, rather than
/// wrapping `PurchaseService` in an abstraction of its own — every call in
/// `InAppPurchase` reads `InAppPurchasePlatform.instance` at call time, so
/// swapping it here is enough to redirect the whole service.
class _FakeStore extends InAppPurchasePlatform {
  _FakeStore({this.available = true, this.knowsProduct = true});

  final bool available;
  final bool knowsProduct;

  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();

  /// Every purchase this store was asked to finalise. The stream is one-way,
  /// so this is how a test sees that the transaction was closed out.
  final completed = <String>[];

  var restoreCalls = 0;

  /// What `restorePurchases` will hand back, if anything. Empty is the case
  /// that matters most: a player who taps Restore having never bought.
  List<PurchaseDetails> toRestore = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    if (!knowsProduct) {
      return ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: ids.toList(),
      );
    }
    return ProductDetailsResponse(
      productDetails: [
        for (final id in ids)
          ProductDetails(
            id: id,
            title: 'Host a Local Game',
            description: 'Start your own WiFi game for friends.',
            price: r'$1.99',
            rawPrice: 1.99,
            currencyCode: 'USD',
          ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    if (toRestore.isNotEmpty) _purchases.add(toRestore);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID ?? purchase.productID);
  }

  /// Pushes an event the app never asked for — a purchase finishing after a
  /// relaunch, or a parent approving one hours later.
  void emit(List<PurchaseDetails> purchases) => _purchases.add(purchases);

  void close() => _purchases.close();
}

/// One purchase as the store would report it.
PurchaseDetails _purchase(
  PurchaseStatus status, {
  String id = PurchaseService.productId,
  bool needsCompleting = true,
}) {
  final details = PurchaseDetails(
    purchaseID: 'txn-1',
    productID: id,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'test',
    ),
    transactionDate: null,
    status: status,
  );
  details.pendingCompletePurchase = needsCompleting;
  return details;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;

  /// Builds a service on a fake store with the given saved state. The service
  /// is constructed before the platform is swapped because reading
  /// `InAppPurchase.instance` registers the real platform for the host OS.
  Future<PurchaseService> serviceWith({
    bool owned = false,
    _FakeStore? fake,
  }) async {
    SharedPreferences.setMockInitialValues(
      owned ? {'host_game_owned': true} : {},
    );
    // Constructing the service reads `InAppPurchase.instance`, which on its
    // first call registers the real platform for the target — and the Android
    // one builds a BillingClientManager that needs a live platform channel.
    // Neither Android nor iOS registration runs under this override, which
    // leaves the instance below as the only store there is.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    final service = PurchaseService.fresh();
    debugDefaultTargetPlatformOverride = null;

    store = fake ?? _FakeStore();
    InAppPurchasePlatform.instance = store;
    await service.init();
    return service;
  }

  tearDown(() => store.close());

  test('a fresh install cannot host', () async {
    final service = await serviceWith();
    expect(service.canHost, isFalse);
  });

  test('a saved unlock is read back before the store is consulted', () async {
    final service = await serviceWith(owned: true);
    expect(service.canHost, isTrue);
  });

  test('a purchase grants hosting and is written down', () async {
    final service = await serviceWith();
    expect(service.canHost, isFalse);

    store.emit([_purchase(PurchaseStatus.purchased)]);
    await pumpEventQueue();

    expect(service.canHost, isTrue);

    // The next launch must not need the store to agree.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('host_game_owned'), isTrue);
  });

  // Skipping this is what leaves a transaction in the queue for iOS to
  // redeliver on every launch forever, and it is a documented rejection
  // reason — worth a test even though nothing visible breaks without it.
  test('every finished purchase is completed, including a failed one', () async {
    final service = await serviceWith();

    store.emit([_purchase(PurchaseStatus.purchased)]);
    await pumpEventQueue();
    expect(store.completed, hasLength(1));

    store.emit([_purchase(PurchaseStatus.error)]);
    await pumpEventQueue();
    expect(store.completed, hasLength(2));

    expect(service.canHost, isTrue);
  });

  test('another app\'s product is ignored', () async {
    final service = await serviceWith();

    store.emit([_purchase(PurchaseStatus.purchased, id: 'com.someone.else')]);
    await pumpEventQueue();

    expect(service.canHost, isFalse);
    expect(store.completed, isEmpty);
  });

  test('restoring an existing purchase unlocks hosting', () async {
    final service = await serviceWith();
    store.toRestore = [_purchase(PurchaseStatus.restored)];

    final error = await service.restore();

    expect(error, isNull);
    expect(service.canHost, isTrue);
  });

  // The regression this file exists for. `restorePurchases` resolves without
  // ever putting anything on the stream when there is nothing to restore, so
  // a service that waits for a stream event stays busy forever and leaves the
  // paywall's buttons disabled — on the commonest case there is, someone
  // tapping Restore who never bought it.
  test('restoring nothing reports it and does not stay busy', () async {
    final service = await serviceWith();

    final error = await service.restore();

    expect(error, PurchaseError.nothingToRestore);
    expect(service.busy, isFalse);
    expect(service.canHost, isFalse);
    expect(store.restoreCalls, 1);
  });

  test('an unreachable store is reported, not thrown', () async {
    final service = await serviceWith(fake: _FakeStore(available: false));

    expect(await service.buy(), PurchaseError.storeUnavailable);
    expect(await service.restore(), PurchaseError.storeUnavailable);
    expect(service.busy, isFalse);
  });

  test('a product the store does not know is reported', () async {
    final service = await serviceWith(fake: _FakeStore(knowsProduct: false));

    expect(await service.buy(), PurchaseError.productMissing);
    expect(service.busy, isFalse);
  });

  test('buying twice does nothing the second time', () async {
    final service = await serviceWith(owned: true);
    expect(await service.buy(), isNull);
    expect(service.busy, isFalse);
  });
}
