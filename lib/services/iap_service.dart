import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../ads/placement/show_placement_ad.dart';
import '../core/constants/app_constants.dart';
import '../models/iap_models.dart';

enum IapPurchaseOutcome {
  success,
  pending,
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
  bool? _storeAvailable;
  Future<void>? _inFlightInit;
  Future<Map<String, ProductDetails>>? _inFlightCatalogQuery;
  Timer? _resumeGraceTimer;
  bool _sawPendingPurchaseStatus = false;
  Future<void>? _inFlightUpdateWork;

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

  Set<String> _catalogProductIds(IapCatalog catalog) {
    final subs = catalog.subscriptions.isNotEmpty
        ? catalog.subscriptions
        : IapCatalog.defaultVipSubscriptions;
    return subs
        .map((s) => s.productId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Returns true when every subscription product in [catalog] is already cached.
  bool hasAllCatalogProducts(IapCatalog catalog) {
    final ids = _catalogProductIds(catalog);
    return ids.isNotEmpty && ids.every(_productsById.containsKey);
  }

  Future<bool> _ensureStoreAvailable() async {
    final cached = _storeAvailable;
    if (cached == true) return true;
    final available = await _iap.isAvailable();
    _storeAvailable = available;
    return available;
  }

  /// Starts listening to `purchaseStream` and binds backend verification.
  Future<void> initialize({
    required VerifyPurchaseCallback onVerifyPurchase,
    void Function(IapPurchaseResult result)? onBackgroundPurchase,
  }) async {
    _onVerifyPurchase = onVerifyPurchase;
    _onBackgroundPurchase = onBackgroundPurchase;
    if (_purchaseSub != null || !_isStoreSupportedPlatform) return;

    final existing = _inFlightInit;
    if (existing != null) return existing;

    final future = _runInitialize().whenComplete(() {
      _inFlightInit = null;
    });
    _inFlightInit = future;
    return future;
  }

  Future<void> _runInitialize() async {
    if (_purchaseSub != null) return;
    try {
      final available = await _ensureStoreAvailable();
      if (!available) {
        debugPrint('IapService.initialize: store is unavailable');
        return;
      }
      _purchaseSub ??= _iap.purchaseStream.listen(
        (purchases) => unawaited(_handlePurchaseUpdates(purchases)),
        onError: (Object error, StackTrace st) {
          debugPrint('IapService.purchaseStream error: $error\n$st');
          _failAllPending(error.toString());
        },
      );
    } catch (e) {
      _storeAvailable = null;
      debugPrint('IapService.initialize error: $e');
    }
  }

  /// Queries Google Play / App Store product details for all items in [catalog].
  Future<Map<String, ProductDetails>> queryCatalogProducts(
    IapCatalog catalog, {
    bool forceRefresh = false,
  }) async {
    if (!_isStoreSupportedPlatform) return const {};

    final ids = _catalogProductIds(catalog);
    if (ids.isEmpty || (!forceRefresh && ids.every(_productsById.containsKey))) {
      return cachedProducts;
    }

    final existing = _inFlightCatalogQuery;
    if (existing != null) return existing;

    final future = _runCatalogQuery(ids).whenComplete(() {
      _inFlightCatalogQuery = null;
    });
    _inFlightCatalogQuery = future;
    return future;
  }

  Future<Map<String, ProductDetails>> _runCatalogQuery(Set<String> ids) async {
    try {
      final available = await _ensureStoreAvailable();
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
      _storeAvailable = null;
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
      _sawPendingPurchaseStatus = false;
      _resumeGraceTimer?.cancel();

      final releaseAdGuard = suppressAppOpenAdsOnResume(excludeNextResume: true);
      final lifecycleObserver = !AppConstants.isFlutterTest
          ? _IapResumeObserver(
              onResumedFromStore: () {
                if (completer.isCompleted || _sawPendingPurchaseStatus) return;
                _resumeGraceTimer?.cancel();
                _resumeGraceTimer = Timer(const Duration(seconds: 4), () {
                  if (!completer.isCompleted &&
                      !_sawPendingPurchaseStatus &&
                      _pendingCompleters.containsKey(productId)) {
                    debugPrint(
                      'IapService: resumed from store without purchase update; canceling pending $productId',
                    );
                    cancelPendingPurchases(
                      reason: 'Store billing dismissed without purchase update',
                    );
                  }
                });
              },
              onBackgrounded: () => _resumeGraceTimer?.cancel(),
            )
          : null;
      if (lifecycleObserver != null) {
        WidgetsBinding.instance.addObserver(lifecycleObserver);
      }

      try {
        debugPrint(
          'IapService.buyProduct launching $productId (${product.price})',
        );
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
      } finally {
        _resumeGraceTimer?.cancel();
        _resumeGraceTimer = null;
        if (lifecycleObserver != null) {
          WidgetsBinding.instance.removeObserver(lifecycleObserver);
        }
        releaseAdGuard();
      }
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

  /// Cancels any in-flight purchase completer (e.g., when user dismisses the paywall).
  void cancelPendingPurchases({String reason = 'Purchase canceled'}) {
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    _completeAllPending(IapPurchaseOutcome.canceled, reason);
  }

  /// Triggers Google Play / Store purchase restoration; updates arrive via [purchaseStream].
  Future<bool> restorePurchases({bool silent = false}) async {
    if (!_isStoreSupportedPlatform) return false;
    final releaseAdGuard = silent
        ? null
        : suppressAppOpenAdsOnResume(excludeNextResume: true);
    try {
      final available = await _ensureStoreAvailable();
      if (!available) return false;
      await _iap.restorePurchases();
      if (silent) {
        // Give the broadcast purchaseStream a beat to deliver restored purchases,
        // then wait briefly for verification to finish before gating Splash/Home ads.
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final pendingWork = _inFlightUpdateWork;
        if (pendingWork != null) {
          await pendingWork.timeout(
            const Duration(seconds: 2),
            onTimeout: () {},
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('IapService.restorePurchases error: $e');
      return false;
    } finally {
      releaseAdGuard?.call();
    }
  }

  bool _isAlreadyOwnedError(PurchaseDetails purchase) {
    final msg = (purchase.error?.message ?? '').toLowerCase();
    final details = (purchase.error?.details?.toString() ?? '').toLowerCase();
    return msg.contains('itemalreadyowned') ||
        msg.contains('already owned') ||
        details.contains('itemalreadyowned') ||
        details.contains('already owned');
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    final prev = _inFlightUpdateWork ?? Future<void>.value();
    final next = prev.catchError((_) {}).then((_) => _processPurchaseUpdates(purchases));
    _inFlightUpdateWork = next;
    return next.whenComplete(() {
      if (identical(_inFlightUpdateWork, next)) {
        _inFlightUpdateWork = null;
      }
    });
  }

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _resumeGraceTimer?.cancel();
      debugPrint(
        'IapService.purchaseUpdate: product=${purchase.productID} '
        'status=${purchase.status.name} pendingComplete=${purchase.pendingCompletePurchase} '
        'error=${purchase.error?.code}:${purchase.error?.message}:${purchase.error?.details}',
      );
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _sawPendingPurchaseStatus = true;
          _resolvePurchase(
            IapPurchaseResult(
              outcome: IapPurchaseOutcome.pending,
              productId: purchase.productID,
              message: 'Payment is pending confirmation',
            ),
          );
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
          if (_isAlreadyOwnedError(purchase) && _pendingCompleters.isNotEmpty) {
            await _recoverAlreadyOwnedPurchase(purchase);
            break;
          }
          _resolvePurchase(
            IapPurchaseResult(
              outcome: IapPurchaseOutcome.error,
              productId: purchase.productID,
              message: purchase.error?.message ?? purchase.error?.code,
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

  Future<void> _recoverAlreadyOwnedPurchase(PurchaseDetails purchase) async {
    debugPrint(
      'IapService: itemAlreadyOwned detected — restoring active purchases...',
    );
    final pendingKeys = _pendingCompleters.keys.toList();
    await restorePurchases();
    // Give restore stream items a moment to hit _verifyAndSettlePurchase.
    await Future<void>.delayed(const Duration(seconds: 3));
    for (final key in pendingKeys) {
      final remaining = _pendingCompleters.remove(key);
      if (remaining != null && !remaining.isCompleted) {
        remaining.complete(
          IapPurchaseResult(
            outcome: IapPurchaseOutcome.error,
            productId: key,
            message:
                purchase.error?.message ?? 'Subscription already owned on store',
          ),
        );
      }
    }
  }

  Future<void> _verifyAndSettlePurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData.trim();
    final verifier = _onVerifyPurchase;
    if (token.isEmpty || verifier == null) {
      debugPrint(
        'IapService._verifyAndSettlePurchase missing token/verifier '
        '(tokenEmpty=${token.isEmpty}, hasVerifier=${verifier != null})',
      );
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
      debugPrint(
        'IapService._verifyAndSettlePurchase failed for ${purchase.productID}',
      );
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
      await _iap.completePurchase(purchase).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('IapService.completePurchase error: $e');
    }
  }

  void _resolvePurchase(IapPurchaseResult result) {
    final productId = result.productId?.trim() ?? '';
    Completer<IapPurchaseResult>? completer;
    if (productId.isNotEmpty) {
      completer = _pendingCompleters.remove(productId);
    } else if (_pendingCompleters.length == 1) {
      // Google Play Billing emits empty productID on userCanceled / billing errors.
      completer = _pendingCompleters.remove(_pendingCompleters.keys.first);
    } else if (_pendingCompleters.isNotEmpty &&
        (result.outcome == IapPurchaseOutcome.error ||
            result.outcome == IapPurchaseOutcome.canceled)) {
      _completeAllPending(
        result.outcome,
        result.message ?? result.outcome.name,
      );
      return;
    }

    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    } else if (result.isSuccess) {
      _onBackgroundPurchase?.call(result);
    }
  }

  void _failAllPending(String message) =>
      _completeAllPending(IapPurchaseOutcome.error, message);

  void _completeAllPending(IapPurchaseOutcome outcome, String? message) {
    final entries = _pendingCompleters.entries.toList();
    _pendingCompleters.clear();
    for (final entry in entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          IapPurchaseResult(
            outcome: outcome,
            productId: entry.key,
            message: message,
          ),
        );
      }
    }
  }

  void dispose() {
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    unawaited(_purchaseSub?.cancel());
    _purchaseSub = null;
    _failAllPending('IAP service disposed');
  }
}

class _IapResumeObserver with WidgetsBindingObserver {
  final VoidCallback onResumedFromStore;
  final VoidCallback onBackgrounded;
  bool _sawBackground = false;

  _IapResumeObserver({
    required this.onResumedFromStore,
    required this.onBackgrounded,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _sawBackground = true;
      onBackgrounded();
    } else if (state == AppLifecycleState.resumed && _sawBackground) {
      _sawBackground = false;
      onResumedFromStore();
    }
  }
}
