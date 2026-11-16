import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/constants/app_constants.dart';
import '../models/iap_models.dart';

enum IapPurchaseOutcome {
  success,
  canceled,
  storeUnavailable,
  productNotFound,
  verificationFailed,
  error,
}

class IapPurchaseResult {
  final IapPurchaseOutcome outcome;
  final String? productId;
  final String? message;

  const IapPurchaseResult({
    required this.outcome,
    this.productId,
    this.message,
  });

  bool get isSuccess => outcome == IapPurchaseOutcome.success;
}

typedef VerifyPurchaseCallback = Future<bool> Function(
  String productId,
  String purchaseToken,
);

/// Handles Google Play Billing (Android) / StoreKit (iOS) purchases via
/// `in_app_purchase`, verifying receipts with the backend before acknowledging.
class IapService {
  final InAppPurchase? _customIap;
  final bool Function()? _isStorePlatformOverride;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _productsById = {};
  final Map<String, Completer<IapPurchaseResult>> _pendingCompleters = {};

  VerifyPurchaseCallback? _onVerifyPurchase;
  void Function(IapPurchaseResult result)? _onBackgroundPurchase;

  IapService({
    InAppPurchase? iap,
    bool Function()? storePlatformCheck,
  })  : _customIap = iap,
        _isStorePlatformOverride = storePlatformCheck;

  InAppPurchase get _iap => _customIap ?? InAppPurchase.instance;

  bool get _isStoreSupportedPlatform {
    if (_isStorePlatformOverride != null) return _isStorePlatformOverride();
    return !kIsWeb &&
        !AppConstants.isFlutterTest &&
        (Platform.isAndroid || Platform.isIOS);
  }

  Map<String, ProductDetails> get cachedProducts =>
      Map.unmodifiable(_productsById);

  /// Starts listening to `purchaseStream` and binds backend verification.
  Future<void> initialize({
    required VerifyPurchaseCallback onVerifyPurchase,
    void Function(IapPurchaseResult result)? onBackgroundPurchase,
  }) async {
    _onVerifyPurchase = onVerifyPurchase;
    _onBackgroundPurchase = onBackgroundPurchase;
    if (_purchaseSub != null || !_isStoreSupportedPlatform) return;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('IapService.initialize: store is unavailable');
        return;
      }
      _purchaseSub = _iap.purchaseStream.listen(
        (purchases) => unawaited(_handlePurchaseUpdates(purchases)),
        onError: (Object error, StackTrace st) {
          debugPrint('IapService.purchaseStream error: $error\n$st');
          _failAllPending(error.toString());
        },
      );
    } catch (e) {
      debugPrint('IapService.initialize error: $e');
    }
  }

  /// Queries Google Play / App Store product details for all items in [catalog].
  Future<Map<String, ProductDetails>> queryCatalogProducts(
    IapCatalog catalog,
  ) async {
    if (!_isStoreSupportedPlatform) return const {};

    final subs = catalog.subscriptions.isNotEmpty
        ? catalog.subscriptions
        : IapCatalog.defaultVipSubscriptions;
    final ids = subs
        .map((s) => s.productId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return cachedProducts;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('IapService.queryCatalogProducts: store is unavailable');
        return const {};
      }

      debugPrint('IapService.queryCatalogProducts querying IDs: $ids');
      final response = await _iap.queryProductDetails(ids);
      if (response.error != null) {
        debugPrint(
          'IapService.queryCatalogProducts error: ${response.error!.message}',
        );
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          'IapService.queryCatalogProducts missing IDs on store: ${response.notFoundIDs}',
        );
      }
      if (response.productDetails.isNotEmpty) {
        final loaded = response.productDetails
            .map((p) => '${p.id} (${p.price} / ${p.currencyCode})')
            .join(', ');
        debugPrint(
          'IapService.queryCatalogProducts loaded from store: [$loaded]',
        );
      } else {
        debugPrint(
          'IapService.queryCatalogProducts returned 0 products from store',
        );
      }

      for (final pd in response.productDetails) {
        final existing = _productsById[pd.id];
        if (existing == null || (existing.rawPrice == 0 && pd.rawPrice > 0)) {
          _productsById[pd.id] = pd;
        }
      }
    } catch (e) {
      debugPrint('IapService.queryCatalogProducts exception: $e');
    }
    return cachedProducts;
  }

  /// Launches Google Play / Store purchase flow for [productId].
  Future<IapPurchaseResult> buyProduct(
    String productId, {
    required bool isConsumable,
  }) async {
    if (!_isStoreSupportedPlatform) {
      return IapPurchaseResult(
        outcome: IapPurchaseOutcome.storeUnavailable,
        productId: productId,
      );
    }

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        return IapPurchaseResult(
          outcome: IapPurchaseOutcome.storeUnavailable,
          productId: productId,
        );
      }

      var product = _productsById[productId];
      if (product == null) {
        final singleQuery = await _iap.queryProductDetails({productId});
        for (final pd in singleQuery.productDetails) {
          _productsById.putIfAbsent(pd.id, () => pd);
        }
        product = _productsById[productId];
      }

      if (product == null) {
        return IapPurchaseResult(
          outcome: IapPurchaseOutcome.productNotFound,
          productId: productId,
        );
      }

      final existing = _pendingCompleters[productId];
      if (existing != null && !existing.isCompleted) {
        return await existing.future;
      }

      final completer = Completer<IapPurchaseResult>();
      _pendingCompleters[productId] = completer;

      final param = PurchaseParam(productDetails: product);
      final launched = isConsumable
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: true)
          : await _iap.buyNonConsumable(purchaseParam: param);

      if (!launched) {
        _pendingCompleters.remove(productId);
        return IapPurchaseResult(
          outcome: IapPurchaseOutcome.error,
          productId: productId,
          message: 'Unable to start store billing flow',
        );
      }

      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _pendingCompleters.remove(productId);
          return IapPurchaseResult(
            outcome: IapPurchaseOutcome.error,
            productId: productId,
            message: 'Purchase timed out',
          );
        },
      );
    } catch (e) {
      _pendingCompleters.remove(productId);
      debugPrint('IapService.buyProduct error ($productId): $e');
      return IapPurchaseResult(
        outcome: IapPurchaseOutcome.error,
        productId: productId,
        message: e.toString(),
      );
    }
  }

  /// Triggers Google Play / Store purchase restoration; updates arrive via [purchaseStream].
  Future<bool> restorePurchases() async {
    if (!_isStoreSupportedPlatform) return false;
    try {
      final available = await _iap.isAvailable();
      if (!available) return false;
      await _iap.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('IapService.restorePurchases error: $e');
      return false;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          await _completeIfPending(purchase);
          _resolvePurchase(
            IapPurchaseResult(
              outcome: IapPurchaseOutcome.canceled,
              productId: purchase.productID,
            ),
          );
          break;
        case PurchaseStatus.error:
          await _completeIfPending(purchase);
          _resolvePurchase(
            IapPurchaseResult(
              outcome: IapPurchaseOutcome.error,
              productId: purchase.productID,
              message: purchase.error?.message,
            ),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndSettlePurchase(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndSettlePurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData.trim();
    final verifier = _onVerifyPurchase;
    if (token.isEmpty || verifier == null) {
      _resolvePurchase(
        IapPurchaseResult(
          outcome: IapPurchaseOutcome.verificationFailed,
          productId: purchase.productID,
        ),
      );
      return;
    }

    var verified = false;
    try {
      verified = await verifier(purchase.productID, token);
    } catch (e) {
      debugPrint('IapService._verifyAndSettlePurchase error: $e');
      verified = false;
    }

    if (!verified) {
      // Leave purchase unacknowledged so Play Store can retry later.
      _resolvePurchase(
        IapPurchaseResult(
          outcome: IapPurchaseOutcome.verificationFailed,
          productId: purchase.productID,
        ),
      );
      return;
    }

    await _completeIfPending(purchase);

    if (purchase.status == PurchaseStatus.purchased) {
      final pd = _productsById[purchase.productID];
      if (pd != null && AppConstants.isMobilePlatform) {
        try {
          AdjustHelper().trackEventInAppPurchase(
            purchase: purchase,
            productDetail: pd,
          );
        } catch (e) {
          debugPrint('IapService Adjust tracking error: $e');
        }
      }
    }

    _resolvePurchase(
      IapPurchaseResult(
        outcome: IapPurchaseOutcome.success,
        productId: purchase.productID,
      ),
    );
  }

  Future<void> _completeIfPending(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('IapService.completePurchase error: $e');
    }
  }

  void _resolvePurchase(IapPurchaseResult result) {
    final productId = result.productId;
    final completer =
        productId != null ? _pendingCompleters.remove(productId) : null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    } else if (result.isSuccess) {
      _onBackgroundPurchase?.call(result);
    }
  }

  void _failAllPending(String message) {
    final entries = _pendingCompleters.entries.toList();
    _pendingCompleters.clear();
    for (final entry in entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          IapPurchaseResult(
            outcome: IapPurchaseOutcome.error,
            productId: entry.key,
            message: message,
          ),
        );
      }
    }
  }

  void dispose() {
    unawaited(_purchaseSub?.cancel());
    _purchaseSub = null;
    _failAllPending('IAP service disposed');
  }
}
