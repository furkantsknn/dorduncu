import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/badge_product_model.dart';
import '../models/plus_product_model.dart';
import '../services/market_service.dart';
import '../services/plus_entitlement.dart';
import '../services/plus_service.dart';
import '../services/plus_subscription_offer.dart';
import '../services/play_offer_channel.dart';
import '../services/play_one_time_offer.dart';
import '../services/digital_purchase_service.dart';
import '../services/digital_restore.dart';
import '../services/purchase_flow_reconcile.dart';
import '../widgets/game_badge_emblem.dart';
import '../widgets/market_palette.dart';
import '../widgets/plus_emblem.dart';
import '../widgets/plus_surface.dart';
import 'gift_flow_screen.dart';
import 'gift_history_screen.dart';
import 'legal_document_screen.dart';

String _marketText(
  BuildContext context, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, this.openPlusDetails = false});

  final bool openPlusDetails;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  bool _didOpenRequestedPlusDetails = false;
  final MarketService _marketService = MarketService();
  final PlusService _plusService = PlusService();
  final DigitalPurchaseService _digitalPurchaseService =
      DigitalPurchaseService.instance;
  final PlayOfferChannel _playOfferChannel = PlayOfferChannel();

  String _searchText = '';
  String _selectedFilter = 'all';
  bool _purchaseBusy = false;
  bool _playPriceRequestInFlight = false;
  final Map<String, String> _playPrices = <String, String>{};
  final Map<String, PlayOneTimeOffer> _plusBadgeOffers =
      <String, PlayOneTimeOffer>{};
  bool _plusBadgeEntitled = false;
  bool _plusBadgeOfferRequestInFlight = false;
  Timer? _plusExpiryTimer;
  DateTime? _scheduledPlusExpiry;
  final Set<String> _unavailablePlayPriceIds = <String>{};
  final Set<String> _notFoundPlayPriceIds = <String>{};
  final Map<String, PlusSubscriptionSelection> _plusQuotes =
      <String, PlusSubscriptionSelection>{};
  final Map<String, String> _plusQuoteErrors = <String, String>{};
  final Set<String> _plusQuotesLoading = <String>{};
  final ValueNotifier<int> _plusQuotesVersion = ValueNotifier<int>(0);
  final ValueNotifier<MarketRestoreFeedback> _restoreFeedback =
      ValueNotifier<MarketRestoreFeedback>(const MarketRestoreFeedback.none());
  final ValueNotifier<String?> _deliveryCheckFeedback = ValueNotifier<String?>(
    null,
  );

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeName => _isIOS ? 'App Store' : 'Google Play';

  String _badgeStoreId(BadgeProductModel product) =>
      product.storeProductIdFor(defaultTargetPlatform);

  String _plusStoreId(PlusProductModel product) =>
      product.storeProductIdFor(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _digitalPurchaseService.flowPhase.addListener(_onPurchasePhase);
    _digitalPurchaseService.verifiedAfterClose.addListener(_onLateVerification);
  }

  @override
  void dispose() {
    _digitalPurchaseService.flowPhase.removeListener(_onPurchasePhase);
    _digitalPurchaseService.verifiedAfterClose.removeListener(
      _onLateVerification,
    );
    _plusQuotesVersion.dispose();
    _restoreFeedback.dispose();
    _deliveryCheckFeedback.dispose();
    _plusExpiryTimer?.cancel();
    super.dispose();
  }

  void _onPurchasePhase() {
    if (!mounted) {
      return;
    }
    _releaseStalePurchaseBusy();
    final PurchaseFlowPhase phase = _digitalPurchaseService.flowPhase.value;
    setState(() {});
    if (phase == PurchaseFlowPhase.pendingPayment) {
      _showPurchaseNotice(
        _marketText(
          context,
          tr: '$_storeName ödemesi bekleniyor.',
          en: 'The $_storeName payment is pending.',
          de: _isIOS
              ? 'Die App-Store-Zahlung steht aus.'
              : 'Die Google-Play-Zahlung steht aus.',
        ),
      );
    } else if (phase == PurchaseFlowPhase.verifying) {
      _showPurchaseNotice(
        _marketText(
          context,
          tr: 'Satın alma doğrulanıyor.',
          en: 'The purchase is being verified.',
          de: 'Der Kauf wird geprüft.',
        ),
      );
    } else if (phase == PurchaseFlowPhase.statusUnknown) {
      _showPurchaseNotice(
        _marketText(
          context,
          tr: purchaseStatusUnknownMessage,
          en: 'The purchase status could not be checked.',
          de: 'Der Kaufstatus konnte nicht geprüft werden.',
        ),
      );
    }
  }

  void _onLateVerification() {
    if (!mounted) {
      return;
    }
    _showPurchaseNotice(
      _marketText(
        context,
        tr: 'Satın alma doğrulandı.',
        en: 'The purchase was verified.',
        de: 'Der Kauf wurde bestätigt.',
      ),
    );
  }

  /// Drops a screen lock left after a finished attempt.
  ///
  /// Pending payment, an open store attempt, and server verification stay.
  void _releaseStalePurchaseBusy() {
    if (!_purchaseBusy) {
      return;
    }
    if (_digitalPurchaseService.hasOpenPurchaseAttempt ||
        _digitalPurchaseService.verificationInFlight ||
        _digitalPurchaseService.restoreInFlight.value) {
      return;
    }
    if (_digitalPurchaseService.flowPhase.value != PurchaseFlowPhase.idle) {
      return;
    }
    _purchaseBusy = false;
  }

  void _showPurchaseNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _awaitsDelivery(String storeId) {
    final String id = storeId.trim();
    return id.isNotEmpty &&
        _digitalPurchaseService.awaitingDelivery.value.containsKey(id);
  }

  String _deliveryCheckLabel() {
    return _digitalPurchaseService.statusCheckInFlight.value
        ? _marketText(
            context,
            tr: 'Kontrol ediliyor',
            en: 'Checking',
            de: 'Wird geprüft',
          )
        : _marketText(
            context,
            tr: 'Teslimatı kontrol et',
            en: 'Check delivery',
            de: 'Lieferung prüfen',
          );
  }

  /// Re-verifies purchases Play already charged. Never opens a payment.
  /// A resolved result closes the open sheet so the notice is not hidden.
  Future<void> _recheckDelivery({NavigatorState? sheetNavigator}) async {
    final DeliveryRecheckOutcome outcome = await _digitalPurchaseService
        .recheckAwaitingDelivery();
    if (!mounted) {
      return;
    }
    final String text = _deliveryRecheckText(outcome);
    final bool resolved =
        outcome == DeliveryRecheckOutcome.delivered ||
        outcome == DeliveryRecheckOutcome.notInPlay;
    if (resolved) {
      _deliveryCheckFeedback.value = null;
      if (sheetNavigator != null && sheetNavigator.canPop()) {
        sheetNavigator.pop();
      }
      _showPurchaseNotice(text);
    } else {
      _deliveryCheckFeedback.value = text;
    }
    _releaseStalePurchaseBusy();
    setState(() {});
  }

  String _deliveryRecheckText(DeliveryRecheckOutcome outcome) {
    return switch (outcome) {
      DeliveryRecheckOutcome.delivered => _marketText(
        context,
        tr: 'Teslimat tamamlandı. Hak hesabına işlendi.',
        en: 'Delivered. The entitlement was added to your account.',
        de: 'Geliefert. Das Recht wurde deinem Konto gutgeschrieben.',
      ),
      DeliveryRecheckOutcome.notInPlay => _marketText(
        context,
        tr: '$_storeName bu satın almayı artık göstermiyor (iade veya iptal). Hak verilmedi.',
        en: '$_storeName no longer lists this purchase (refund or cancellation). No entitlement was added.',
        de: '$_storeName zeigt diesen Kauf nicht mehr (Erstattung oder Storno). Es wurde kein Recht gutgeschrieben.',
      ),
      DeliveryRecheckOutcome.paymentPending => _marketText(
        context,
        tr: '$_storeName ödemesi henüz tamamlanmadı.',
        en: 'The $_storeName payment has not finished yet.',
        de: _isIOS
            ? 'Die App-Store-Zahlung ist noch nicht abgeschlossen.'
            : 'Die Google-Play-Zahlung ist noch nicht abgeschlossen.',
      ),
      DeliveryRecheckOutcome.stillPending => _marketText(
        context,
        tr: 'Teslimat hâlâ bekliyor. Tekrar ödeme yapma; biraz sonra yeniden kontrol et.',
        en: 'Delivery is still pending. Do not pay again; check again later.',
        de: 'Die Lieferung steht noch aus. Nicht erneut zahlen; später erneut prüfen.',
      ),
      DeliveryRecheckOutcome.unavailable => _marketText(
        context,
        tr: _isIOS
            ? "App Store'a şu an ulaşılamadı. Biraz sonra tekrar kontrol et."
            : "Google Play'e şu an ulaşılamadı. Biraz sonra tekrar kontrol et.",
        en: '$_storeName could not be reached. Check again later.',
        de: '$_storeName war nicht erreichbar. Später erneut prüfen.',
      ),
      DeliveryRecheckOutcome.busy => _marketText(
        context,
        tr: 'Kontrol zaten sürüyor.',
        en: 'A check is already running.',
        de: 'Eine Prüfung läuft bereits.',
      ),
    };
  }

  VoidCallback? _purchaseFollowUp({
    required bool canBuy,
    required Future<void> Function() onBuy,
    String storeId = '',
    NavigatorState? sheetNavigator,
  }) {
    if (_awaitsDelivery(storeId)) {
      if (_digitalPurchaseService.statusCheckInFlight.value) {
        return null;
      }
      return () {
        _recheckDelivery(sheetNavigator: sheetNavigator);
      };
    }
    final OpenPurchaseFollowUp followUp = openPurchaseFollowUp(
      phase: _digitalPurchaseService.flowPhase.value,
      checkInFlight: _digitalPurchaseService.statusCheckInFlight.value,
    );
    switch (followUp) {
      case OpenPurchaseFollowUp.recheckExisting:
        return _digitalPurchaseService.recheckOpenPurchases;
      case OpenPurchaseFollowUp.startPayment:
        if (!canBuy || _purchaseBusy) {
          return null;
        }
        return () {
          onBuy();
        };
      case OpenPurchaseFollowUp.blocked:
        return null;
    }
  }

  String _purchaseActionLabel() {
    switch (_digitalPurchaseService.flowPhase.value) {
      case PurchaseFlowPhase.pendingPayment:
        return _marketText(
          context,
          tr: 'Ödeme bekleniyor',
          en: 'Payment pending',
          de: 'Zahlung ausstehend',
        );
      case PurchaseFlowPhase.verifying:
        return _marketText(
          context,
          tr: 'Doğrulanıyor',
          en: 'Verifying',
          de: 'Wird geprüft',
        );
      case PurchaseFlowPhase.statusUnknown:
        return _digitalPurchaseService.statusCheckInFlight.value
            ? _marketText(
                context,
                tr: 'Kontrol ediliyor',
                en: 'Checking',
                de: 'Wird geprüft',
              )
            : _marketText(
                context,
                tr: purchaseStatusRecheckLabel,
                en: 'Check again',
                de: 'Erneut prüfen',
              );
      case PurchaseFlowPhase.awaitingStore:
      case PurchaseFlowPhase.idle:
        return _purchaseBusy
            ? _marketText(
                context,
                tr: 'İşleniyor',
                en: 'Working',
                de: 'Wird verarbeitet',
              )
            : _marketText(
                context,
                tr: "Plus'a abone ol",
                en: 'Subscribe to Plus',
                de: 'Plus abonnieren',
              );
    }
  }

  PlayPricePresentation _badgePriceState(String googlePlayProductId) {
    final String storeId = googlePlayProductId.trim();
    return playPricePresentation(
      productId: storeId,
      hasPrice: (_playPrices[storeId]?.trim().isNotEmpty ?? false),
      queryFailed: _unavailablePlayPriceIds.contains(storeId),
      notFound: _notFoundPlayPriceIds.contains(storeId),
    );
  }

  String _displayPrice({required BadgeProductModel product}) {
    final String storeId = _badgeStoreId(product);
    if (!_isIOS) {
      final PlayOneTimeOffer? plusOffer = _plusBadgeOffers[storeId];
      if (_plusBadgeEntitled && plusOffer != null) {
        return plusOffer.formattedPrice;
      }
      if (_plusBadgeEntitled && product.plusGooglePlayOfferId.isNotEmpty) {
        return _marketText(
          context,
          tr: _plusBadgeOfferRequestInFlight
              ? 'Plus fiyatı yükleniyor'
              : 'Plus teklifi kullanılamıyor',
          en: _plusBadgeOfferRequestInFlight
              ? 'Loading Plus price'
              : 'Plus offer unavailable',
          de: _plusBadgeOfferRequestInFlight
              ? 'Plus-Preis wird geladen'
              : 'Plus-Angebot nicht verfügbar',
        );
      }
    }
    switch (_badgePriceState(storeId)) {
      case PlayPricePresentation.ready:
        return _playPrices[storeId]!.trim();
      case PlayPricePresentation.missingMapping:
      case PlayPricePresentation.notFound:
        return _marketText(
          context,
          tr: 'Şu an satışta değil',
          en: 'Not for sale right now',
          de: 'Derzeit nicht im Verkauf',
        );
      case PlayPricePresentation.failed:
        return _marketText(
          context,
          tr: 'Fiyat yüklenemedi',
          en: 'Price failed to load',
          de: 'Preis nicht geladen',
        );
      case PlayPricePresentation.loading:
        return _marketText(
          context,
          tr: 'Fiyat yükleniyor',
          en: 'Loading price',
          de: 'Preis wird geladen',
        );
    }
  }

  bool _badgeForSale(BadgeProductModel product) {
    final String storeId = _badgeStoreId(product);
    if (_badgePriceState(storeId) != PlayPricePresentation.ready) {
      return false;
    }
    if (_isIOS) {
      return true;
    }
    return !_plusBadgeEntitled ||
        product.plusGooglePlayOfferId.isEmpty ||
        _plusBadgeOffers.containsKey(storeId);
  }

  void _syncPlusBadgeOffers({
    required bool plusActive,
    required List<BadgeProductModel> products,
    Map<String, dynamic>? userData,
  }) {
    _schedulePlusExpiryRefresh(userData);
    if (_plusBadgeEntitled != plusActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _plusBadgeEntitled == plusActive) return;
        setState(() {
          _plusBadgeEntitled = plusActive;
          _plusBadgeOffers.clear();
        });
        if (plusActive) _requestPlusBadgeOffers(products, force: true);
      });
      return;
    }
    if (plusActive) _requestPlusBadgeOffers(products);
  }

  void _schedulePlusExpiryRefresh(Map<String, dynamic>? data) {
    final DateTime? next = PlusEntitlement.expiresAt(data);
    if (next == _scheduledPlusExpiry) return;
    _plusExpiryTimer?.cancel();
    _scheduledPlusExpiry = next;
    if (next == null) return;
    _plusExpiryTimer = Timer(next.difference(DateTime.now()), () {
      if (!mounted) return;
      setState(() {
        _plusBadgeEntitled = PlusEntitlement.isActive(data);
        _plusBadgeOffers.clear();
        _scheduledPlusExpiry = null;
      });
    });
  }

  void _requestPlusBadgeOffers(
    List<BadgeProductModel> products, {
    bool force = false,
  }) {
    if (_isIOS ||
        !kPlusBadgeDiscountEnabled ||
        !_plusBadgeEntitled ||
        _plusBadgeOfferRequestInFlight) {
      return;
    }
    final List<BadgeProductModel> mapped = products
        .where(
          (product) =>
              product.googlePlayProductId.isNotEmpty &&
              product.googlePlayPurchaseOptionId.isNotEmpty &&
              product.plusGooglePlayOfferId.isNotEmpty,
        )
        .toList();
    if (mapped.isEmpty ||
        (!force &&
            mapped.every(
              (product) =>
                  _plusBadgeOffers.containsKey(product.googlePlayProductId),
            ))) {
      return;
    }
    _plusBadgeOfferRequestInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final List<PlayOneTimeOffer> offers = await _playOfferChannel
            .queryOneTimeOffers(mapped.map((p) => p.googlePlayProductId));
        final Map<String, PlayOneTimeOffer> verified = {};
        for (final BadgeProductModel product in mapped) {
          try {
            final PlayOneTimeOffer offer = selectPlayOneTimeOffer(
              offers: offers,
              productId: product.googlePlayProductId,
              purchaseOptionId: product.googlePlayPurchaseOptionId,
              campaignOfferId: product.plusGooglePlayOfferId,
            );
            if (offer.currencyCode == 'TRY' &&
                offer.priceAmountMicros == product.plusPriceKurus * 10000 &&
                offer.hasVerifiedListPrice) {
              verified[product.googlePlayProductId] = offer;
            }
          } on PlayOneTimeOfferException {
            // An unavailable exact offer is deliberately not replaced.
          }
        }
        if (mounted) {
          setState(
            () => _plusBadgeOffers
              ..clear()
              ..addAll(verified),
          );
        }
      } finally {
        _plusBadgeOfferRequestInFlight = false;
      }
    });
  }

  void _retryBadgePrice(String googlePlayProductId) {
    final String storeId = googlePlayProductId.trim();
    if (!canRetryPlayPriceQuery(
      inFlight: _playPriceRequestInFlight,
      presentation: _badgePriceState(storeId),
    )) {
      return;
    }

    setState(() {
      _unavailablePlayPriceIds.remove(storeId);
      _notFoundPlayPriceIds.remove(storeId);
      _playPrices.remove(storeId);
    });
    _requestPlayPrices(<String>[storeId]);
  }

  String _plusQuoteKey(PlusProductModel product) {
    if (_isIOS) {
      return '${product.id}|ios|${product.appleProductId.trim()}';
    }
    return '${product.id}|${product.googlePlayProductId.trim()}|'
        '${product.googlePlayBasePlanId.trim()}';
  }

  PlusOfferBlock _plusBlock(PlusProductModel product) {
    final String quoteKey = _plusQuoteKey(product);
    return plusOfferBlock(
      productId: _plusStoreId(product),
      basePlanId: _isIOS ? 'apple_subscription' : product.googlePlayBasePlanId,
      hasQuote: _plusQuotes.containsKey(quoteKey),
      queryFailed: _plusQuoteErrors.containsKey(quoteKey),
    );
  }

  String? _plusBlockedReason(PlusProductModel product) {
    switch (_plusBlock(product)) {
      case PlusOfferBlock.missingMapping:
        if (_plusStoreId(product).isEmpty) {
          return _marketText(
            context,
            tr: '$_storeName eşlemesi bekleniyor',
            en: 'Waiting for $_storeName mapping',
            de: _isIOS
                ? 'App-Store-Zuordnung ausstehend'
                : 'Google-Play-Zuordnung ausstehend',
          );
        }
        return _marketText(
          context,
          tr: 'Base plan eşlemesi bekleniyor',
          en: 'Waiting for the base plan mapping',
          de: 'Base-Plan-Zuordnung ausstehend',
        );
      case PlusOfferBlock.priceFailed:
        return _marketText(
          context,
          tr: 'Fiyat yüklenemedi',
          en: 'Price failed to load',
          de: 'Preis nicht geladen',
        );
      case PlusOfferBlock.loading:
        return _marketText(
          context,
          tr: '$_storeName fiyatı yükleniyor',
          en: 'Loading the $_storeName price',
          de: _isIOS
              ? 'App-Store-Preis wird geladen'
              : 'Google-Play-Preis wird geladen',
        );
      case PlusOfferBlock.none:
        return null;
    }
  }

  void _retryPlusQuote(PlusProductModel product) {
    if (_plusBlock(product) != PlusOfferBlock.priceFailed) {
      return;
    }
    final String key = _plusQuoteKey(product);
    if (_plusQuotesLoading.contains(key)) {
      return;
    }

    setState(() {
      _plusQuoteErrors.remove(key);
      _plusQuotes.remove(key);
      _plusQuotesLoading.remove(key);
    });
    _plusQuotesVersion.value++;
    _requestPlusQuotes(<PlusProductModel>[product]);
  }

  void _requestPlusQuotes(List<PlusProductModel> products) {
    final List<PlusProductModel> pending = <PlusProductModel>[];

    for (final PlusProductModel product in products) {
      if (!product.hasStoreMappingFor(defaultTargetPlatform)) {
        continue;
      }

      final String key = _plusQuoteKey(product);

      if (_plusQuotes.containsKey(key) ||
          _plusQuoteErrors.containsKey(key) ||
          _plusQuotesLoading.contains(key)) {
        continue;
      }

      _plusQuotesLoading.add(key);
      pending.add(product);
    }

    if (pending.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final PlusProductModel product in pending) {
        final String key = _plusQuoteKey(product);

        try {
          PlusSubscriptionSelection selection;
          if (_isIOS) {
            selection = await _digitalPurchaseService.loadApplePlusSelection(
              appleProductId: product.appleProductId,
            );
          } else {
            try {
              selection = await _digitalPurchaseService.loadPlusSelection(
                googlePlayProductId: product.googlePlayProductId,
                googlePlayBasePlanId: product.googlePlayBasePlanId,
                campaignOfferId: product.activeGooglePlayOfferId,
                discountedPeriods: product.activePlusDiscountedPeriods,
              );
            } on PlusSubscriptionOfferException catch (error) {
              if (error.code != 'campaign_not_on_play') {
                rethrow;
              }
              selection = await _digitalPurchaseService.loadPlusSelection(
                googlePlayProductId: product.googlePlayProductId,
                googlePlayBasePlanId: product.googlePlayBasePlanId,
              );
            }
          }

          if (!mounted) {
            return;
          }

          setState(() {
            _plusQuotes[key] = selection;
            _plusQuoteErrors.remove(key);
            _plusQuotesLoading.remove(key);
          });
        } on PlusSubscriptionOfferException catch (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _plusQuoteErrors[key] = error.message;
            _plusQuotesLoading.remove(key);
          });
        } catch (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _plusQuoteErrors[key] =
                '$_storeName fiyatı alınamadı. Satın alma kapatıldı.';
            _plusQuotesLoading.remove(key);
          });
        }

        _plusQuotesVersion.value++;
      }
    });
  }

  void _requestPlayPrices(Iterable<String> rawIds) {
    final Set<String> ids = rawIds
        .map((String id) => id.trim())
        .where(
          (String id) =>
              id.isNotEmpty &&
              !_playPrices.containsKey(id) &&
              !_unavailablePlayPriceIds.contains(id),
        )
        .toSet();

    if (ids.isEmpty || _playPriceRequestInFlight) {
      return;
    }

    _playPriceRequestInFlight = true;
    final Set<String> requested = Set<String>.of(ids);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final PlayPriceLoad loaded = await _digitalPurchaseService
          .loadLocalizedPrices(requested);

      if (!mounted) {
        return;
      }

      setState(() {
        if (loaded.connectionFailed) {
          _unavailablePlayPriceIds.addAll(requested);
          _notFoundPlayPriceIds.removeAll(requested);
        } else {
          for (final String id in requested) {
            final String price = loaded.prices[id]?.trim() ?? '';

            if (price.isEmpty) {
              _notFoundPlayPriceIds.add(id);
              _unavailablePlayPriceIds.remove(id);
            } else {
              _playPrices[id] = price;
              _notFoundPlayPriceIds.remove(id);
              _unavailablePlayPriceIds.remove(id);
            }
          }
        }

        _playPriceRequestInFlight = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Text(
            _marketText(
              context,
              tr: 'Market için giriş yapmalısın.',
              en: 'You must sign in to use the store.',
              de: 'Du musst dich anmelden, um den Store zu nutzen.',
            ),
          ),
        ),
      );
    }

    final MarketPalette palette = MarketPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        title: Text(
          _marketText(
            context,
            tr: 'Dört. Market',
            en: 'Dört. Market',
            de: 'Dört. Markt',
          ),
          style: TextStyle(
            color: palette.ink,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          if (kGiftActionsEnabled && !_isIOS)
            IconButton(
              tooltip: 'Hediyeler',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GiftHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.card_giftcard_outlined),
            ),
          IconButton(
            tooltip: 'Rozetlerim',
            onPressed: () {
              setState(() {
                _selectedFilter = 'owned';
              });
            },
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      body: StreamBuilder<Set<String>>(
        stream: _marketService.watchOwnedBadgeIds(uid),
        builder: (context, ownedSnapshot) {
          final Set<String> ownedBadgeIds = ownedSnapshot.data ?? <String>{};

          return StreamBuilder<Set<String>>(
            stream: _marketService.watchAdminBlockedBadgeIds(uid),
            builder: (context, blockedSnapshot) {
              final Set<String> adminBlockedBadgeIds =
                  blockedSnapshot.data ?? <String>{};
              return StreamBuilder<List<BadgeProductModel>>(
                stream: _marketService.watchActiveBadgeProducts(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.hasError) {
                    return _ErrorState(
                      message: _marketText(
                        context,
                        tr: 'Ürünler yüklenemedi.',
                        en: 'Products could not be loaded.',
                        de: 'Produkte konnten nicht geladen werden.',
                      ),
                      onRetry: () => setState(() {}),
                    );
                  }

                  if (productSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !productSnapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CircularProgressIndicator(color: palette.accent),
                          const SizedBox(height: 12),
                          Text(
                            _marketText(
                              context,
                              tr: 'Yükleniyor',
                              en: 'Loading',
                              de: 'Wird geladen',
                            ),
                            style: TextStyle(color: palette.muted),
                          ),
                        ],
                      ),
                    );
                  }

                  final List<BadgeProductModel> catalog =
                      productSnapshot.data ?? const <BadgeProductModel>[];
                  _requestPlayPrices(
                    catalog.map(
                      (BadgeProductModel product) => _badgeStoreId(product),
                    ),
                  );

                  final List<BadgeProductModel> products =
                      catalog.where((product) {
                        final bool searchMatches =
                            _searchText.isEmpty ||
                            product.title.toLowerCase().contains(_searchText) ||
                            product.gameName.toLowerCase().contains(
                              _searchText,
                            );

                        final bool owned = ownedBadgeIds.contains(product.id);

                        final bool forSale =
                            !adminBlockedBadgeIds.contains(product.id) &&
                            _badgeForSale(product);
                        final bool filterMatches =
                            _selectedFilter == 'all' ||
                            (_selectedFilter == 'owned' && owned) ||
                            (_selectedFilter == 'available' &&
                                forSale &&
                                !owned);

                        return searchMatches && filterMatches;
                      }).toList()..sort((
                        BadgeProductModel a,
                        BadgeProductModel b,
                      ) {
                        int rank(BadgeProductModel product) {
                          final bool owned = ownedBadgeIds.contains(product.id);
                          final bool forSale =
                              !adminBlockedBadgeIds.contains(product.id) &&
                              _badgeForSale(product);
                          if (forSale && !owned) {
                            return 0;
                          }
                          if (owned) {
                            return 1;
                          }
                          return 2;
                        }

                        return rank(a).compareTo(rank(b));
                      });

                  return RefreshIndicator(
                    color: const Color(0xffFF9800),
                    onRefresh: () async {
                      await FirebaseFirestore.instance
                          .collection('badge_products')
                          .limit(1)
                          .get(const GetOptions(source: Source.server));
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: <Widget>[
                        _PurchaseStatusCheckNotice(
                          onRecheck:
                              _digitalPurchaseService.recheckOpenPurchases,
                        ),
                        MarketDeliveryPendingNotice(
                          awaiting: _digitalPurchaseService.awaitingDelivery,
                          checking: _digitalPurchaseService.statusCheckInFlight,
                          feedback: _deliveryCheckFeedback,
                          onRecheck: () => _recheckDelivery(),
                        ),
                        StreamBuilder<List<PlusProductModel>>(
                          stream: _plusService.watchActiveProducts(),
                          builder: (context, plusSnapshot) {
                            final List<PlusProductModel> plusProducts =
                                (plusSnapshot.data ??
                                        const <PlusProductModel>[])
                                    .where(
                                      (PlusProductModel product) =>
                                          product.hasStoreMappingFor(
                                            defaultTargetPlatform,
                                          ),
                                    )
                                    .toList();

                            _requestPlusQuotes(plusProducts);

                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .snapshots(),
                              builder: (context, userSnapshot) {
                                final Map<String, dynamic>? userData =
                                    userSnapshot.data?.data();
                                final bool entitlementKnown =
                                    userSnapshot.hasData ||
                                    userSnapshot.connectionState ==
                                        ConnectionState.active;
                                final bool plusActive =
                                    entitlementKnown &&
                                    PlusEntitlement.isActive(userData);
                                _syncPlusBadgeOffers(
                                  plusActive: plusActive,
                                  products: catalog,
                                  userData: userData,
                                );
                                final String playProductId = _isIOS
                                    ? (userData?['plusAppleProductId']
                                              ?.toString()
                                              .trim() ??
                                          '')
                                    : (userData?['plusGooglePlayProductId']
                                              ?.toString()
                                              .trim() ??
                                          '');

                                if (widget.openPlusDetails &&
                                    !_didOpenRequestedPlusDetails &&
                                    entitlementKnown &&
                                    (plusProducts.isNotEmpty || plusActive)) {
                                  _didOpenRequestedPlusDetails = true;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    _showPlusProducts(
                                      products: plusProducts,
                                      plusActive: plusActive,
                                      playProductId: playProductId,
                                    );
                                  });
                                }

                                return MarketPlusPromo(
                                  loading:
                                      (plusSnapshot.connectionState ==
                                              ConnectionState.waiting &&
                                          !plusSnapshot.hasData) ||
                                      !entitlementKnown,
                                  entitlementKnown: entitlementKnown,
                                  enabled:
                                      plusProducts.isNotEmpty || plusActive,
                                  plusActive: plusActive,
                                  verificationPending:
                                      _digitalPurchaseService.flowPhase.value ==
                                      PurchaseFlowPhase.verifying,
                                  onTap: plusProducts.isEmpty && !plusActive
                                      ? null
                                      : () {
                                          _showPlusProducts(
                                            products: plusProducts,
                                            plusActive: plusActive,
                                            playProductId: playProductId,
                                          );
                                        },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        MarketBadgeCatalogHeader(
                          onChanged: (String value) {
                            setState(() {
                              _searchText = value.trim().toLowerCase();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        MarketFilterBar(
                          selected: _selectedFilter,
                          ownedCount: ownedBadgeIds.length,
                          onSelected: (String value) {
                            setState(() {
                              _selectedFilter = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (products.isEmpty)
                          _EmptyState(filter: _selectedFilter)
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1);
                              final bool twoColumns =
                                  constraints.maxWidth >= 340 &&
                                  textScale < 1.3;
                              final double cardWidth = twoColumns
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <Widget>[
                                  for (final BadgeProductModel product
                                      in products)
                                    SizedBox(
                                      width: cardWidth,
                                      child: MarketBadgeProductCard(
                                        product: product,
                                        owned: ownedBadgeIds.contains(
                                          product.id,
                                        ),
                                        priceState: _badgePriceState(
                                          _badgeStoreId(product),
                                        ),
                                        price: _displayPrice(product: product),
                                        canRetryPrice: canRetryPlayPriceQuery(
                                          inFlight: _playPriceRequestInFlight,
                                          presentation: _badgePriceState(
                                            _badgeStoreId(product),
                                          ),
                                        ),
                                        onRetryPrice: () => _retryBadgePrice(
                                          _badgeStoreId(product),
                                        ),
                                        onTap: () {
                                          _showProductPreview(
                                            product: product,
                                            owned: ownedBadgeIds.contains(
                                              product.id,
                                            ),
                                            adminBlocked: adminBlockedBadgeIds
                                                .contains(product.id),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                        MarketRestoreFeedbackBanner(feedback: _restoreFeedback),
                        _MarketRestoreAction(
                          onRestore: _restoreDigitalPurchases,
                          onRecheck:
                              _digitalPurchaseService.recheckOpenPurchases,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showProductPreview({
    required BadgeProductModel product,
    required bool owned,
    required bool adminBlocked,
  }) async {
    final MarketPalette palette = MarketPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: palette.background,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.52,
          maxChildSize: 0.94,
          builder: (BuildContext context, ScrollController scrollController) {
            final MarketPalette sheetPalette = MarketPalette.of(context);
            final String gameLabel = product.gameName.trim().isEmpty
                ? product.title
                : product.gameName.trim();
            return ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                _digitalPurchaseService.flowPhase,
                _digitalPurchaseService.statusCheckInFlight,
                _digitalPurchaseService.awaitingDelivery,
              ]),
              builder: (BuildContext context, Widget? _) {
                final String badgeStoreId = _badgeStoreId(product);
                final PlayPricePresentation priceState = _badgePriceState(
                  badgeStoreId,
                );
                final bool forSale = !adminBlocked && _badgeForSale(product);
                final PurchaseFlowPhase phase =
                    _digitalPurchaseService.flowPhase.value;
                final bool purchaseOpen = phase != PurchaseFlowPhase.idle;
                final bool awaitingDelivery =
                    !owned && _awaitsDelivery(badgeStoreId);
                final String priceLabel = _displayPrice(product: product);
                final VoidCallback? buy = _purchaseFollowUp(
                  canBuy: !owned && forSale,
                  storeId: owned ? '' : badgeStoreId,
                  sheetNavigator: Navigator.of(sheetContext),
                  onBuy: () async {
                    Navigator.of(sheetContext).pop();
                    await _purchaseBadge(product);
                  },
                );
                final bool showBuy =
                    !adminBlocked &&
                    !owned &&
                    (forSale || purchaseOpen || awaitingDelivery);
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: GameBadgeEmblem(
                          emoji: '',
                          imageUrl: product.imageUrl,
                          gameId: product.gameId,
                          gameName: product.gameName,
                          size: 132,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        gameLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: sheetPalette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _marketText(
                          context,
                          tr: 'Sevdiğin oyunu profilinde göster.',
                          en: 'Show a game you like on your profile.',
                          de: 'Zeige ein Spiel, das du magst, in deinem Profil.',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: sheetPalette.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        owned
                            ? _marketText(
                                context,
                                tr: 'Bu rozete sahipsin',
                                en: 'You own this badge',
                                de: 'Dieses Abzeichen gehört dir',
                              )
                            : priceLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: owned
                              ? sheetPalette.owned
                              : forSale
                              ? sheetPalette.accent
                              : sheetPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!owned) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _marketText(
                            context,
                            tr: 'Tek seferlik satın alma. Ödeme ve iade $_storeName üzerinden yürür.',
                            en: 'One-time purchase. Payment and refunds run through $_storeName.',
                            de: 'Einmaliger Kauf. Zahlung und Erstattung laufen über $_storeName.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: sheetPalette.muted,
                                fontWeight: FontWeight.w400,
                                height: 1.35,
                              ),
                        ),
                      ],
                      _LegalTextLink(
                        label: _marketText(
                          context,
                          tr: 'Dijital Ürün Koşulları',
                          en: 'Digital Product Terms',
                          de: 'Digitale Produkte',
                        ),
                        onTap: () => _openLegalDocument('digital_products'),
                      ),
                      const SizedBox(height: 10),
                      if (awaitingDelivery)
                        MarketDeliveryPendingNotice(
                          awaiting: _digitalPurchaseService.awaitingDelivery,
                          checking: _digitalPurchaseService.statusCheckInFlight,
                          storeIds: <String>{badgeStoreId},
                          feedback: _deliveryCheckFeedback,
                        )
                      else if (phase == PurchaseFlowPhase.statusUnknown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            purchaseStatusUnknownMessage,
                            style: TextStyle(color: sheetPalette.ink),
                          ),
                        ),
                      if (showBuy)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: sheetPalette.accent,
                            foregroundColor: sheetPalette.onAccent,
                            disabledBackgroundColor: sheetPalette.raised,
                            disabledForegroundColor: sheetPalette.muted,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: buy,
                          child: Text(
                            awaitingDelivery
                                ? _deliveryCheckLabel()
                                : _badgeBuyLabel(
                                    forSale: forSale,
                                    phase: phase,
                                    priceLabel: priceLabel,
                                  ),
                          ),
                        ),
                      if (priceState == PlayPricePresentation.failed && !owned)
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed:
                                canRetryPlayPriceQuery(
                                  inFlight: _playPriceRequestInFlight,
                                  presentation: priceState,
                                )
                                ? () => _retryBadgePrice(badgeStoreId)
                                : null,
                            child: Text(
                              _marketText(
                                context,
                                tr: 'Tekrar dene',
                                en: 'Try again',
                                de: 'Erneut versuchen',
                              ),
                            ),
                          ),
                        ),
                      if (kGiftActionsEnabled && !_isIOS) ...<Widget>[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _purchaseBusy
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => GiftFlowScreen(
                                        kind: GiftKind.badge,
                                        productId: product.id,
                                        title: product.title,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.card_giftcard_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              product.giftGooglePlayProductId.isEmpty
                                  ? _marketText(
                                      context,
                                      tr: 'Şu anda kullanılamıyor',
                                      en: 'Currently unavailable',
                                      de: 'Derzeit nicht verfügbar',
                                    )
                                  : _marketText(
                                      context,
                                      tr: 'Hediye et',
                                      en: 'Send a gift',
                                      de: 'Verschenken',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _badgeBuyLabel({
    required bool forSale,
    required PurchaseFlowPhase phase,
    required String priceLabel,
  }) {
    if (phase != PurchaseFlowPhase.idle) {
      return _purchaseActionLabel();
    }
    if (!forSale) {
      return priceLabel;
    }
    if (_purchaseBusy) {
      return _marketText(
        context,
        tr: 'İşleniyor...',
        en: 'Processing...',
        de: 'Wird verarbeitet...',
      );
    }
    return _marketText(
      context,
      tr: '$_storeName ile satın al',
      en: 'Buy with $_storeName',
      de: _isIOS ? 'Über den App Store kaufen' : 'Mit Google Play kaufen',
    );
  }

  Future<void> _purchaseBadge(
    BadgeProductModel product, {
    String? recipientUid,
  }) async {
    if (_purchaseBusy) return;
    if (!_badgeForSale(product)) {
      return;
    }

    setState(() {
      _purchaseBusy = true;
    });

    try {
      String? offerToken;
      if (!_isIOS &&
          _plusBadgeEntitled &&
          product.plusGooglePlayOfferId.isNotEmpty) {
        final PlayOneTimeOffer displayed =
            _plusBadgeOffers[product.googlePlayProductId]!;
        final List<PlayOneTimeOffer> refreshed = await _playOfferChannel
            .queryOneTimeOffers(<String>[product.googlePlayProductId]);
        final PlayOneTimeOffer selected = selectPlayOneTimeOffer(
          offers: refreshed,
          productId: product.googlePlayProductId,
          purchaseOptionId: product.googlePlayPurchaseOptionId,
          campaignOfferId: product.plusGooglePlayOfferId,
        );
        if (!samePlayOneTimeOffer(displayed, selected) ||
            selected.currencyCode != 'TRY' ||
            selected.priceAmountMicros != product.plusPriceKurus * 10000) {
          throw PlayOneTimeOfferException(
            'Google Play Plus fiyatı değişti. Satın alma açılmadı.',
            code: 'offer_changed',
          );
        }
        await FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('authorizeBadgeOfferPurchase')
            .call<void>(<String, dynamic>{
              'productId': product.id,
              'googlePlayProductId': product.googlePlayProductId,
              'purchaseOptionId': product.googlePlayPurchaseOptionId,
              'offerId': product.plusGooglePlayOfferId,
            });
        offerToken = selected.offerToken;
      }
      await _digitalPurchaseService.purchase(
        googlePlayProductId: _badgeStoreId(product),
        kind: DigitalStoreProductKind.badgeNonConsumable,
        internalProductId: product.id,
        recipientUid: recipientUid,
        oneTimeOfferToken: offerToken,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              recipientUid == null
                  ? '${product.title} başarıyla satın alındı.'
                  : '${product.title} hediye olarak gönderildi.',
            ),
          ),
        );
    } on PlayOneTimeOfferException catch (error) {
      if (!mounted) return;
      _showPurchaseNotice(error.message);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showPurchaseNotice(error.message ?? 'Plus uygunluğu doğrulanamadı.');
    } on DigitalPurchaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Satın alma işlemi tamamlanamadı: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _purchaseBusy = false;
        });
      }
    }
  }

  String _playPriceLabel(PlusSubscriptionSelection quote) {
    final String suffix = plusPricePeriodSuffix(
      quote.billingPeriod,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    if (suffix.isEmpty) {
      return quote.formattedPrice;
    }
    return '${quote.formattedPrice} $suffix';
  }

  String _renewalExplanation(PlusSubscriptionSelection? quote) {
    if (quote != null && quote.renewalFormattedPrice.isNotEmpty) {
      final String now = _playPriceLabel(quote);
      final String later = plusPricePeriodSuffix(
        quote.billingPeriod,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      final String renewal = later.isEmpty
          ? quote.renewalFormattedPrice
          : '${quote.renewalFormattedPrice} $later';
      return _marketText(
        context,
        tr: '${quote.discountedPeriodCount} ay $now. Sonra $renewal yenilenir. İptal edilmezse Google Play bu tutarı tahsil eder.',
        en: '${quote.discountedPeriodCount} months at $now. Then renews at $renewal. Google Play charges that price unless you cancel.',
        de: '${quote.discountedPeriodCount} Monate für $now. Danach $renewal. Google Play bucht diesen Preis, wenn du nicht kündigst.',
      );
    }
    if (_isIOS) {
      return _marketText(
        context,
        tr: 'Ödeme Apple kimliği hesabından tahsil edilir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik yenilenir. Aboneliğini App Store hesap ayarlarından yönetebilir veya iptal edebilirsin.',
        en: 'Payment is charged to your Apple ID account. Your subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Account Settings.',
        de: 'Die Zahlung wird über deine Apple-ID abgerechnet. Das Abonnement verlängert sich automatisch, sofern es nicht mindestens 24 Stunden vor Ablauf des aktuellen Zeitraums gekündigt wird. Verwaltung und Kündigung sind jederzeit in den App-Store-Kontoeinstellungen möglich.',
      );
    }
    return _marketText(
      context,
      tr: 'İptal etmediğin sürece aboneliğin her ay yenilenir.',
      en: 'Your subscription renews every month unless you cancel.',
      de: 'Dein Abonnement verlängert sich jeden Monat, sofern du nicht kündigst.',
    );
  }

  Future<void> _showPlusProducts({
    required List<PlusProductModel> products,
    required bool plusActive,
    required String playProductId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: MarketPalette.of(context).background,
      builder: (sheetContext) {
        _releaseStalePurchaseBusy();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          builder: (BuildContext sheetBodyContext, ScrollController scrollController) {
            final double bottomInset = MediaQuery.viewPaddingOf(
              sheetBodyContext,
            ).bottom;
            final MarketPalette palette = MarketPalette.of(sheetBodyContext);
            final ThemeData sheetTheme = Theme.of(sheetBodyContext).copyWith(
              textTheme: Theme.of(sheetBodyContext).textTheme.apply(
                bodyColor: palette.ink,
                displayColor: palette.ink,
              ),
            );
            return Theme(
              data: sheetTheme,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PlusWordmark(
                      markSize: 34,
                      textStyle: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _marketText(
                        context,
                        tr: 'Oyuna daha çok yer aç.',
                        en: 'Make more room for play.',
                        de: 'Schaffe mehr Raum fürs Spiel.',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: PlusSurface.muted,
                      ),
                    ),
                    if (plusActive) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _marketText(
                          context,
                          tr: 'Plus üyeliğin aktif',
                          en: 'Your Plus membership is active',
                          de: 'Deine Plus-Mitgliedschaft ist aktiv',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const PlusPlanSummary(),
                    const SizedBox(height: 16),
                    _PlusPurchaseStatusArea(
                      restoreFeedback: _restoreFeedback,
                      deliveryFeedback: _deliveryCheckFeedback,
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge(<Listenable>[
                        _plusQuotesVersion,
                        _digitalPurchaseService.flowPhase,
                        _digitalPurchaseService.statusCheckInFlight,
                        _digitalPurchaseService.restoreInFlight,
                        _digitalPurchaseService.awaitingDelivery,
                      ]),
                      builder: (context, _) {
                        if (plusActive) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              FilledButton(
                                style: plusPrimaryButtonStyle(),
                                onPressed: () =>
                                    _openSubscriptionManagement(playProductId),
                                child: Text(
                                  _marketText(
                                    context,
                                    tr: 'Aboneliği yönet',
                                    en: 'Manage subscription',
                                    de: 'Abonnement verwalten',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _marketText(
                                  context,
                                  tr: 'Yenileme $_storeName aboneliğinden devam eder. Hediye süresi aboneliği durdurmaz.',
                                  en: 'Renewal continues through the $_storeName subscription. Gift time does not stop it.',
                                  de: _isIOS
                                      ? 'Die Verlängerung läuft über das App-Store-Abo. Geschenkzeit stoppt es nicht.'
                                      : 'Die Verlängerung läuft über das Google-Play-Abo. Geschenkzeit stoppt es nicht.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: products.map((PlusProductModel product) {
                            final String quoteKey = _plusQuoteKey(product);
                            final PlusSubscriptionSelection? quote =
                                _plusQuotes[quoteKey];
                            final String? blockedReason = _plusBlockedReason(
                              product,
                            );
                            final bool restoreRunning =
                                _digitalPurchaseService.restoreInFlight.value;
                            final bool awaitingDelivery = _awaitsDelivery(
                              _plusStoreId(product),
                            );
                            final String period = quote == null
                                ? ''
                                : plusBillingPeriodLabel(
                                    quote.billingPeriod,
                                    languageCode: Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  );
                            final String price = quote == null
                                ? ''
                                : quote.renewalFormattedPrice.isEmpty
                                ? _playPriceLabel(quote)
                                : _marketText(
                                    context,
                                    tr: '${_playPriceLabel(quote)} · ${quote.discountedPeriodCount} ay, sonra ${quote.renewalFormattedPrice} ${plusPricePeriodSuffix(quote.billingPeriod)}',
                                    en: '${_playPriceLabel(quote)} · ${quote.discountedPeriodCount} months, then ${quote.renewalFormattedPrice} ${plusPricePeriodSuffix(quote.billingPeriod, languageCode: 'en')}',
                                    de: '${_playPriceLabel(quote)} · ${quote.discountedPeriodCount} Monate, danach ${quote.renewalFormattedPrice} ${plusPricePeriodSuffix(quote.billingPeriod, languageCode: 'de')}',
                                  );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  PlusSurface(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          period.isEmpty
                                              ? _marketText(
                                                  context,
                                                  tr: 'Plan',
                                                  en: 'Plan',
                                                  de: 'Plan',
                                                )
                                              : period,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          blockedReason ??
                                              (price.isEmpty
                                                  ? _marketText(
                                                      context,
                                                      tr: '$_storeName fiyatı yükleniyor',
                                                      en: 'Loading the $_storeName price',
                                                      de: _isIOS
                                                          ? 'App-Store-Preis wird geladen'
                                                          : 'Google-Play-Preis wird geladen',
                                                    )
                                                  : price),
                                        ),
                                        if (_plusBlock(product) ==
                                            PlusOfferBlock.priceFailed)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton(
                                              onPressed:
                                                  _plusQuotesLoading.contains(
                                                    quoteKey,
                                                  )
                                                  ? null
                                                  : () => _retryPlusQuote(
                                                      product,
                                                    ),
                                              child: Text(
                                                _marketText(
                                                  context,
                                                  tr: 'Tekrar dene',
                                                  en: 'Try again',
                                                  de: 'Erneut versuchen',
                                                ),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          style: plusPrimaryButtonStyle(),
                                          onPressed: restoreRunning
                                              ? null
                                              : _purchaseFollowUp(
                                                  canBuy:
                                                      quote != null &&
                                                      blockedReason == null,
                                                  storeId: _plusStoreId(product),
                                                  sheetNavigator: Navigator.of(
                                                    sheetContext,
                                                  ),
                                                  onBuy: () async {
                                                    Navigator.of(
                                                      sheetContext,
                                                    ).pop();
                                                    await _purchasePlus(
                                                      product,
                                                      quote!,
                                                    );
                                                  },
                                                ),
                                          child: Text(
                                            awaitingDelivery
                                                ? _deliveryCheckLabel()
                                                : _marketText(
                                                    context,
                                                    tr: "Plus'a abone ol",
                                                    en: 'Subscribe to Plus',
                                                    de: 'Plus abonnieren',
                                                  ),
                                            style: const TextStyle(
                                              color: Color(0xff15120D),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _renewalExplanation(quote),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    if (kGiftActionsEnabled && !_isIOS && products.isNotEmpty)
                      TextButton(
                        onPressed:
                            !giftActionAvailable(
                              enabled: kGiftActionsEnabled,
                              giftProductId:
                                  products.first.giftGooglePlayProductId,
                              purchaseBusy: _purchaseBusy,
                            )
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GiftFlowScreen(
                                      kind: GiftKind.plus,
                                      productId: products.first.id,
                                      title: products.first.title,
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          products.first.giftGooglePlayProductId.isEmpty
                              ? _marketText(
                                  context,
                                  tr: 'Şu anda kullanılamıyor',
                                  en: 'Currently unavailable',
                                  de: 'Derzeit nicht verfügbar',
                                )
                              : _marketText(
                                  context,
                                  tr: '30 günlük Plus hediye et',
                                  en: 'Gift 30 days of Plus',
                                  de: '30 Tage Plus verschenken',
                                ),
                        ),
                      ),
                    _LegalTextLink(
                      label: _marketText(
                        context,
                        tr: 'Plus Abonelik Koşulları',
                        en: 'Plus Subscription Terms',
                        de: 'Plus-Abonnementbedingungen',
                      ),
                      onTap: () => _openLegalDocument('plus_subscription'),
                    ),
                    _LegalTextLink(
                      label: _marketText(
                        context,
                        tr: 'Otomatik Yenileme',
                        en: 'Automatic Renewal',
                        de: 'Automatische Verlängerung',
                      ),
                      onTap: () => _openLegalDocument('automatic_renewal'),
                    ),
                    _LegalTextLink(
                      label: _marketText(
                        context,
                        tr: 'Gizlilik Politikası',
                        en: 'Privacy Policy',
                        de: 'Datenschutzerklärung',
                      ),
                      onTap: () => _openLegalDocument('privacy_policy'),
                    ),
                    _LegalTextLink(
                      label: _marketText(
                        context,
                        tr: 'Kullanım Koşulları',
                        en: 'Terms of Use',
                        de: 'Nutzungsbedingungen',
                      ),
                      onTap: () => _openLegalDocument('terms_of_use'),
                    ),
                    _MarketRestoreAction(
                      onRestore: _restoreDigitalPurchases,
                      onRecheck: _digitalPurchaseService.recheckOpenPurchases,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restoreDigitalPurchases() async {
    final MarketRestoreDecision decision = decideMarketRestore(
      phase: _digitalPurchaseService.flowPhase.value,
      checkInFlight: _digitalPurchaseService.statusCheckInFlight.value,
      restoreInFlight: _digitalPurchaseService.restoreInFlight.value,
    );
    if (decision.action != MarketRestoreAction.restore) {
      _restoreFeedback.value = MarketRestoreFeedback.blocked(decision.reason);
      return;
    }

    _restoreFeedback.value = const MarketRestoreFeedback.running();

    try {
      final DigitalRestoreResult result = await _digitalPurchaseService
          .restorePurchases();

      if (!mounted) {
        return;
      }
      _restoreFeedback.value = switch (result.presentation) {
        DigitalRestorePresentation.completed =>
          const MarketRestoreFeedback.completed(),
        DigitalRestorePresentation.giftKept =>
          const MarketRestoreFeedback.giftKept(),
        DigitalRestorePresentation.paymentPending =>
          const MarketRestoreFeedback.paymentPending(),
        DigitalRestorePresentation.notFound =>
          const MarketRestoreFeedback.notFound(),
      };
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error is DigitalPurchaseException
          ? error.message
          : _marketText(
              context,
              tr: 'Satın alımlar geri yüklenemedi.',
              en: 'Purchases could not be restored.',
              de: 'Käufe konnten nicht wiederhergestellt werden.',
            );
      _restoreFeedback.value = MarketRestoreFeedback.failed(message);
    } finally {
      if (mounted) {
        _releaseStalePurchaseBusy();
        setState(() {});
      }
    }
  }

  Future<void> _openSubscriptionManagement(String playProductId) async {
    if (_isIOS) {
      final Uri appleUri = Uri.parse(
        'https://apps.apple.com/account/subscriptions',
      );
      final bool opened = await launchUrl(
        appleUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _marketText(
                context,
                tr: 'App Store abonelik sayfası açılamadı.',
                en: 'The App Store subscriptions page could not be opened.',
                de: 'Die App-Store-Abonnementseite konnte nicht geöffnet werden.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final String sku = playProductId.trim();
    final Uri uri = sku.isEmpty
        ? Uri.parse('https://play.google.com/store/account/subscriptions')
        : Uri.https('play.google.com', '/store/account/subscriptions', {
            'sku': sku,
            'package': 'com.dortapp.dort',
          });

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      final bool fallbackOpened = await launchUrl(
        Uri.parse('https://play.google.com/store/account/subscriptions'),
        mode: LaunchMode.externalApplication,
      );
      if (!fallbackOpened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _marketText(
                context,
                tr: 'Google Play abonelik sayfası açılamadı.',
                en: 'The Google Play subscriptions page could not be opened.',
                de: 'Die Google-Play-Abonnementseite konnte nicht geöffnet werden.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _purchasePlus(
    PlusProductModel product,
    PlusSubscriptionSelection displayedOffer,
  ) async {
    if (_purchaseBusy) {
      return;
    }

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (PlusEntitlement.isActive(userSnapshot.data())) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _marketText(
                context,
                tr: 'Plus üyeliğin aktif',
                en: 'Your Plus membership is active',
                de: 'Deine Plus-Mitgliedschaft ist aktiv',
              ),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _purchaseBusy = true;
    });

    try {
      final DigitalPurchaseResult result = await _digitalPurchaseService
          .purchase(
            googlePlayProductId: _plusStoreId(product),
            googlePlayBasePlanId: _isIOS
                ? 'apple_subscription'
                : product.googlePlayBasePlanId,
            plusSelection: displayedOffer,
            kind: DigitalStoreProductKind.plusSubscription,
            internalProductId: product.id,
          );

      if (!mounted) {
        return;
      }

      final DateTime? expiry = result.plusExpiresAt;

      final String expiryText = expiry == null
          ? _marketText(
              context,
              tr: '$_storeName hesabındaki abonelik süresi',
              en: 'your $_storeName subscription period',
              de: _isIOS
                  ? 'deine App-Store-Abonnementlaufzeit'
                  : 'deine Google-Play-Abonnementlaufzeit',
            )
          : '${expiry.day.toString().padLeft(2, '0')}.'
                '${expiry.month.toString().padLeft(2, '0')}.'
                '${expiry.year}';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.title} aktif edildi. Bitiş: $expiryText'),
          ),
        );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.message ??
                  _marketText(
                    context,
                    tr: 'Plus satın alma işlemi tamamlanamadı.',
                    en: 'Plus purchase could not be completed.',
                    de: 'Der Plus-Kauf konnte nicht abgeschlossen werden.',
                  ),
            ),
          ),
        );
    } on DigitalPurchaseException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.stage == 'server-verification') {
        final code = error.code ?? 'unknown';
        final safeCode = RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(code)
            ? code.toLowerCase().replaceAll('_', '-')
            : 'unknown';
        _showPurchaseNotice(
          _marketText(
            context,
            tr: 'Satın alma sunucuda doğrulanamadı. Yeni ödeme başlatmadan önce $_storeName satın alma durumunu kontrol et. ($safeCode)',
            en: 'The purchase could not be verified by the server. Check its $_storeName status before starting another payment. ($safeCode)',
            de: 'Der Kauf konnte auf dem Server nicht bestätigt werden. Prüfe den Kaufstatus im $_storeName, bevor du erneut bezahlst. ($safeCode)',
          ),
        );
        return;
      }

      if (error.code == 'offer_changed') {
        final String key = _plusQuoteKey(product);
        setState(() {
          _plusQuotes.remove(key);
          _plusQuoteErrors.remove(key);
          _plusQuotesLoading.remove(key);
        });
        _plusQuotesVersion.value++;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Plus satın alma işlemi tamamlanamadı: $error'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _purchaseBusy = false;
        });
      }
    }
  }

  void _openLegalDocument(String documentCode) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(documentCode: documentCode),
      ),
    );
  }
}

class _PlusPurchaseStatusArea extends StatelessWidget {
  const _PlusPurchaseStatusArea({
    required this.restoreFeedback,
    required this.deliveryFeedback,
  });

  final ValueListenable<MarketRestoreFeedback> restoreFeedback;
  final ValueListenable<String?> deliveryFeedback;

  @override
  Widget build(BuildContext context) {
    final DigitalPurchaseService service = DigitalPurchaseService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        restoreFeedback,
        deliveryFeedback,
        service.flowPhase,
        service.statusCheckInFlight,
        service.restoreInFlight,
        service.awaitingDelivery,
      ]),
      builder: (BuildContext context, Widget? child) {
        final MarketRestoreFeedback restore = restoreFeedback.value;
        String? message = marketRestoreFeedbackText(context, restore);
        bool running = restore.kind == MarketRestoreFeedbackKind.running;

        if (message == null && service.awaitingDelivery.value.isNotEmpty) {
          message = deliveryFeedback.value?.trim();
          message = message == null || message.isEmpty
              ? _marketText(
                  context,
                  tr: 'Ödeme alındı; teslimat bekliyor. Tekrar ödeme yapma, mevcut satın almayı kontrol et.',
                  en: 'Payment received; delivery is pending. Do not pay again; check the existing purchase.',
                  de: 'Zahlung erhalten; Lieferung ausstehend. Nicht erneut zahlen; prüfe den vorhandenen Kauf.',
                )
              : message;
          running = service.statusCheckInFlight.value;
        }

        if (message == null) {
          final bool isIOS =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
          final String storeName = isIOS ? 'App Store' : 'Google Play';
          message = switch (service.flowPhase.value) {
            PurchaseFlowPhase.pendingPayment => _marketText(
              context,
              tr: '$storeName ödemesi bekleniyor.',
              en: '$storeName payment is pending.',
              de: isIOS
                  ? 'Die App-Store-Zahlung steht aus.'
                  : 'Die Google-Play-Zahlung steht aus.',
            ),
            PurchaseFlowPhase.verifying => _marketText(
              context,
              tr: 'Satın alma doğrulanıyor.',
              en: 'The purchase is being verified.',
              de: 'Der Kauf wird geprüft.',
            ),
            PurchaseFlowPhase.statusUnknown => _marketText(
              context,
              tr: purchaseStatusUnknownMessage,
              en: 'The purchase status could not be checked.',
              de: 'Der Kaufstatus konnte nicht geprüft werden.',
            ),
            PurchaseFlowPhase.awaitingStore => _marketText(
              context,
              tr: '$storeName yanıtı bekleniyor.',
              en: 'Waiting for $storeName.',
              de: '$storeName wird erwartet.',
            ),
            PurchaseFlowPhase.idle =>
              service.statusCheckInFlight.value
                  ? _marketText(
                      context,
                      tr: 'Satın almalar kontrol ediliyor.',
                      en: 'Checking purchases.',
                      de: 'Käufe werden geprüft.',
                    )
                  : null,
          };
          running =
              service.flowPhase.value == PurchaseFlowPhase.verifying ||
              service.flowPhase.value == PurchaseFlowPhase.awaitingStore ||
              service.statusCheckInFlight.value ||
              service.restoreInFlight.value;
        }

        if (message == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (running) ...<Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }
}

class MarketRestoreFeedbackBanner extends StatelessWidget {
  const MarketRestoreFeedbackBanner({super.key, required this.feedback});

  final ValueListenable<MarketRestoreFeedback> feedback;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feedback,
      builder: (BuildContext context, Widget? child) {
        final MarketRestoreFeedback notice = feedback.value;
        final String? text = marketRestoreFeedbackText(context, notice);
        if (text == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (notice.kind == MarketRestoreFeedbackKind.running) ...<Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(text)),
            ],
          ),
        );
      },
    );
  }
}

String? marketRestoreFeedbackText(
  BuildContext context,
  MarketRestoreFeedback notice,
) {
  switch (notice.kind) {
    case MarketRestoreFeedbackKind.none:
      return null;
    case MarketRestoreFeedbackKind.running:
      return _marketText(
        context,
        tr: 'Satın almalar kontrol ediliyor',
        en: 'Checking purchases',
        de: 'Käufe werden geprüft',
      );
    case MarketRestoreFeedbackKind.completed:
      return _marketText(
        context,
        tr: 'Doğrulanan haklar hesabına işlendi.',
        en: 'Verified entitlements were added to this account.',
        de: 'Geprüfte Rechte wurden diesem Konto gutgeschrieben.',
      );
    case MarketRestoreFeedbackKind.giftKept:
      return _marketText(
        context,
        tr: 'Hediye kaydı doğrulandı. Hak alıcıda kaldı.',
        en: 'The gift record was verified. The entitlement stayed with the recipient.',
        de: 'Der Geschenkeintrag wurde geprüft. Das Recht blieb beim Empfänger.',
      );
    case MarketRestoreFeedbackKind.paymentPending:
      final bool isIOS =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      final String storeName = isIOS ? 'App Store' : 'Google Play';
      return _marketText(
        context,
        tr: '$storeName ödemesi henüz tamamlanmadı. Tamamlanınca hak doğrulanıp hesabına işlenir.',
        en: 'The $storeName payment has not finished. Once it does, the entitlement is verified and added.',
        de: isIOS
            ? 'Die App-Store-Zahlung ist noch nicht abgeschlossen. Danach wird das Recht geprüft und gutgeschrieben.'
            : 'Die Google-Play-Zahlung ist noch nicht abgeschlossen. Danach wird das Recht geprüft und gutgeschrieben.',
      );
    case MarketRestoreFeedbackKind.notFound:
      return _marketText(
        context,
        tr: 'Geri yüklenecek satın alma bulunamadı.',
        en: 'No purchases were found to restore.',
        de: 'Keine Käufe zum Wiederherstellen gefunden.',
      );
    case MarketRestoreFeedbackKind.failed:
      final String detail = notice.detail?.trim() ?? '';
      if (detail.isNotEmpty) {
        return detail;
      }
      return _marketText(
        context,
        tr: 'Satın alımlar geri yüklenemedi.',
        en: 'Purchases could not be restored.',
        de: 'Käufe konnten nicht wiederhergestellt werden.',
      );
    case MarketRestoreFeedbackKind.blocked:
      return switch (notice.blockedReason) {
        MarketRestoreReason.paymentPending => _marketText(
          context,
          tr: 'Ödeme bekleniyor. Geri yükleme bu sırada başlatılmaz.',
          en: 'Payment is pending. Restore stays closed until it finishes.',
          de: 'Die Zahlung steht aus. Wiederherstellen bleibt bis dahin geschlossen.',
        ),
        MarketRestoreReason.verifying => _marketText(
          context,
          tr: 'Doğrulama sürüyor. Geri yükleme bu sırada başlatılmaz.',
          en: 'Verification is still running. Restore stays closed until it finishes.',
          de: 'Die Prüfung läuft noch. Wiederherstellen bleibt bis dahin geschlossen.',
        ),
        MarketRestoreReason.purchaseInProgress => _marketText(
          context,
          tr: 'Satın alma işlemi devam ediyor.',
          en: 'A purchase is still in progress.',
          de: 'Ein Kauf läuft noch.',
        ),
        MarketRestoreReason.statusUnknown => purchaseStatusUnknownMessage,
        MarketRestoreReason.checkingPurchases ||
        MarketRestoreReason.none ||
        null => _marketText(
          context,
          tr: 'Satın almalar kontrol ediliyor',
          en: 'Checking purchases',
          de: 'Käufe werden geprüft',
        ),
      };
  }
}

class _MarketRestoreAction extends StatelessWidget {
  const _MarketRestoreAction({
    required this.onRestore,
    required this.onRecheck,
  });

  final Future<void> Function() onRestore;
  final Future<void> Function() onRecheck;

  @override
  Widget build(BuildContext context) {
    final DigitalPurchaseService service = DigitalPurchaseService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        service.flowPhase,
        service.statusCheckInFlight,
        service.restoreInFlight,
      ]),
      builder: (BuildContext context, Widget? child) {
        final MarketRestoreDecision decision = decideMarketRestore(
          phase: service.flowPhase.value,
          checkInFlight: service.statusCheckInFlight.value,
          restoreInFlight: service.restoreInFlight.value,
        );
        final String label = decision.action == MarketRestoreAction.recheck
            ? _marketText(
                context,
                tr: purchaseStatusRecheckLabel,
                en: 'Check again',
                de: 'Erneut prüfen',
              )
            : _marketText(
                context,
                tr: 'Satın almaları geri yükle',
                en: 'Restore purchases',
                de: 'Käufe wiederherstellen',
              );
        final VoidCallback? onPressed = switch (decision.action) {
          MarketRestoreAction.restore => () {
            onRestore();
          },
          MarketRestoreAction.recheck => () {
            onRecheck();
          },
          MarketRestoreAction.wait => null,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onPressed, child: Text(label)),
            ),
            Builder(
              builder: (BuildContext context) {
                final bool isIOS =
                    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
                final String storeName = isIOS ? 'App Store' : 'Google Play';
                return Text(
                  _marketText(
                    context,
                    tr: 'Bu $storeName hesabıyla yaptığın satın almaları kontrol eder.',
                    en: 'Checks purchases made with this $storeName account.',
                    de: isIOS
                        ? 'Prüft Käufe, die mit diesem App-Store-Konto gemacht wurden.'
                        : 'Prüft Käufe, die mit diesem Google-Play-Konto gemacht wurden.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PurchaseStatusCheckNotice extends StatelessWidget {
  const _PurchaseStatusCheckNotice({required this.onRecheck});

  final Future<void> Function() onRecheck;

  @override
  Widget build(BuildContext context) {
    final DigitalPurchaseService service = DigitalPurchaseService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        service.flowPhase,
        service.statusCheckInFlight,
      ]),
      builder: (context, _) {
        if (service.flowPhase.value != PurchaseFlowPhase.statusUnknown) {
          return const SizedBox.shrink();
        }
        final bool checking = service.statusCheckInFlight.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(purchaseStatusUnknownMessage),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: checking ? null : onRecheck,
                child: Text(
                  checking ? 'Kontrol ediliyor' : purchaseStatusRecheckLabel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Play charged, the server has not delivered. Stays visible until delivery
/// succeeds or Play no longer returns the purchase.
class MarketDeliveryPendingNotice extends StatelessWidget {
  const MarketDeliveryPendingNotice({
    super.key,
    required this.awaiting,
    required this.checking,
    required this.feedback,
    this.storeIds,
    this.onRecheck,
  });

  final ValueListenable<Map<String, String>> awaiting;
  final ValueListenable<bool> checking;
  final ValueListenable<String?> feedback;
  final Set<String>? storeIds;
  final Future<void> Function()? onRecheck;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[awaiting, checking, feedback]),
      builder: (BuildContext context, Widget? _) {
        final Set<String>? only = storeIds;
        final List<String> messages = awaiting.value.entries
            .where(
              (MapEntry<String, String> entry) =>
                  only == null || only.contains(entry.key),
            )
            .map((MapEntry<String, String> entry) => entry.value.trim())
            .where((String message) => message.isNotEmpty)
            .toSet()
            .toList();
        final bool waiting = awaiting.value.keys.any(
          (String id) => only == null || only.contains(id),
        );
        if (!waiting) {
          return const SizedBox.shrink();
        }
        final MarketPalette palette = MarketPalette.of(context);
        final TextTheme text = Theme.of(context).textTheme;
        final bool checkInFlight = checking.value;
        final String? checkResult = feedback.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.raised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.accent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _marketText(
                  context,
                  tr: 'Ödemen alındı, teslimat bekliyor',
                  en: 'Payment received, delivery pending',
                  de: 'Zahlung erhalten, Lieferung ausstehend',
                ),
                style: text.titleSmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (BuildContext context) {
                  final bool isIOS =
                      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
                  final String storeName = isIOS ? 'App Store' : 'Google Play';
                  return Text(
                    _marketText(
                      context,
                      tr: '$storeName ödemeyi aldı ama hak henüz hesabına işlenmedi. Tekrar ödeme yapma; kontrol ettiğinde mevcut satın alma yeniden doğrulanır.',
                      en: '$storeName took the payment, but the entitlement is not on your account yet. Do not pay again; checking re-verifies the existing purchase.',
                      de: '$storeName hat die Zahlung erhalten, das Recht ist aber noch nicht auf deinem Konto. Nicht erneut zahlen; die Prüfung bestätigt den vorhandenen Kauf erneut.',
                    ),
                    style: text.bodyMedium?.copyWith(color: palette.ink),
                  );
                },
              ),
              for (final String message in messages) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  message,
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
              if (checkResult != null && checkResult.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  checkResult,
                  style: text.bodySmall?.copyWith(color: palette.ink),
                ),
              ],
              if (onRecheck != null) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: checkInFlight ? null : onRecheck,
                  child: Text(
                    checkInFlight
                        ? _marketText(
                            context,
                            tr: 'Kontrol ediliyor',
                            en: 'Checking',
                            de: 'Wird geprüft',
                          )
                        : _marketText(
                            context,
                            tr: 'Teslimatı kontrol et',
                            en: 'Check delivery',
                            de: 'Lieferung prüfen',
                          ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LegalTextLink extends StatelessWidget {
  const _LegalTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        child: Text(label),
      ),
    );
  }
}

class MarketPlusPromo extends StatelessWidget {
  const MarketPlusPromo({
    super.key,
    required this.loading,
    required this.entitlementKnown,
    required this.enabled,
    required this.plusActive,
    this.verificationPending = false,
    required this.onTap,
  });

  final bool loading;
  final bool entitlementKnown;
  final bool enabled;
  final bool plusActive;
  final bool verificationPending;
  final VoidCallback? onTap;

  static const Color _surfaceTop = Color(0xff1C1F26);
  static const Color _surfaceBottom = Color(0xff0E1014);
  static const Color _ink = Color(0xffF4F1EA);
  static const Color _muted = Color(0xffB4B8C2);
  static const Color _accent = Color(0xffFF9800);

  @override
  Widget build(BuildContext context) {
    final String statusMessage = _marketText(
      context,
      tr: 'Planlarını genişlet, Plus ayrıcalıklarını keşfet.',
      en: 'Expand your plans and discover Plus benefits.',
      de: 'Erweitere deine Pläne und entdecke die Plus-Vorteile.',
    );
    final bool showAction = enabled && !loading;
    final BorderRadius radius = BorderRadius.circular(18);

    return Semantics(
      button: enabled && !loading,
      label: 'Plus. $statusMessage',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled && !loading ? onTap : null,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[_surfaceTop, _surfaceBottom],
                ),
                border: Border.all(color: _accent.withValues(alpha: 0.32)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const PlusMark(size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'Plus',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        if (loading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _accent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                    if (showAction) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                _marketText(
                                  context,
                                  tr: plusActive
                                      ? 'Üyeliği yönet'
                                      : "Plus'ı keşfet",
                                  en: plusActive
                                      ? 'Manage membership'
                                      : 'Explore Plus',
                                  de: plusActive
                                      ? 'Mitgliedschaft verwalten'
                                      : 'Plus entdecken',
                                ),
                                style: const TextStyle(
                                  color: Color(0xff15120D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Color(0xff15120D),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlusPlanSummary extends StatelessWidget {
  const PlusPlanSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle body = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: PlusSurface.muted,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
    return DefaultTextStyle.merge(
      style: body,
      child: PlusSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PlusBenefitRow(
              icon: Icons.groups_2_outlined,
              title: _marketText(
                context,
                tr: 'Birden fazla oyuncuyla etkinlik oluştur.',
                en: 'Create events with multiple players.',
                de: 'Erstelle Events mit mehreren Spielern.',
              ),
              description: _marketText(
                context,
                tr: 'Oyuncu sayısını etkinliğine göre belirle.',
                en: 'Choose the player count for your event.',
                de: 'Lege die Spielerzahl für dein Event fest.',
              ),
            ),
            const SizedBox(height: 12),
            _PlusBenefitRow(
              icon: Icons.event_available_outlined,
              title: _marketText(
                context,
                tr: 'Önceden planla',
                en: 'Plan ahead',
                de: 'Im Voraus planen',
              ),
              description: _marketText(
                context,
                tr: 'İleri tarihler için etkinlik oluştur.',
                en: 'Create events for future dates.',
                de: 'Erstelle Events für zukünftige Termine.',
              ),
            ),
            const SizedBox(height: 12),
            _PlusBenefitRow(
              icon: Icons.person_outline_rounded,
              title: _marketText(
                context,
                tr: 'Plus rozetinle öne çık.',
                en: 'Stand out with your Plus badge.',
                de: 'Hebe dich mit deinem Plus-Abzeichen hervor.',
              ),
              description: _marketText(
                context,
                tr: 'Profilinde sana özel PLUS işareti görünsün.',
                en: 'Show your PLUS mark on your profile.',
                de: 'Zeige dein persönliches PLUS-Zeichen im Profil.',
              ),
            ),
            if (kPlusBadgeDiscountEnabled &&
                (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)) ...<Widget>[
              const SizedBox(height: 12),
              _PlusBenefitRow(
                icon: Icons.local_offer_outlined,
                title: _marketText(
                  context,
                  tr: 'Plus’a özel fiyatlar',
                  en: 'Plus-only prices',
                  de: 'Exklusive Plus-Preise',
                ),
                description: _marketText(
                  context,
                  tr: 'Market içerisinde Plus’a özel fiyatlardan yararlan.',
                  en: 'Get Plus-only prices in the Market.',
                  de: 'Nutze exklusive Plus-Preise im Market.',
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              _marketText(
                context,
                tr: 'Ücretsiz üyelikle bugün için 1 oyuncu arayabilirsin.',
                en: 'With a free membership, you can seek 1 player for today.',
                de: 'Mit einer kostenlosen Mitgliedschaft kannst du für heute 1 Spieler suchen.',
              ),
              style: body.copyWith(color: PlusSurface.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _marketText(
                context,
                tr: 'Ücretsiz: Aynı anda en fazla 2 açık etkinlik.',
                en: 'Free: Up to 2 open events at the same time.',
                de: 'Kostenlos: Höchstens 2 offene Veranstaltungen gleichzeitig.',
              ),
              style: body.copyWith(color: PlusSurface.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _marketText(
                context,
                tr: 'Plus: Açık etkinlik sayısında ticari üst sınır yok.',
                en: 'Plus: No commercial limit on the number of open events.',
                de: 'Plus: Keine kommerzielle Begrenzung für offene Veranstaltungen.',
              ),
              style: body.copyWith(color: PlusSurface.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _marketText(
                context,
                tr: 'Aranan oyuncu sayısına etkinlik sahibi dahil değildir.',
                en: 'The event host is not included in the number of players sought.',
                de: 'Der Veranstalter zählt nicht zur Anzahl der gesuchten Spieler.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PlusSurface.muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusBenefitRow extends StatelessWidget {
  const _PlusBenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PlusSurface.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: PlusSurface.accent),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: PlusSurface.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PlusSurface.muted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Market kartındaki rozetin görünür kenarı: iç genişliğin %68'i.
/// `GameBadgeEmblem` şeffaf kenar telafisini kendi içinde bir kez uygular.
double marketCardBadgeSize(double innerWidth) {
  return (innerWidth * 0.68).clamp(64.0, 120.0).toDouble();
}

class MarketBadgeProductCard extends StatelessWidget {
  const MarketBadgeProductCard({
    super.key,
    required this.product,
    required this.owned,
    required this.priceState,
    required this.price,
    required this.canRetryPrice,
    required this.onRetryPrice,
    required this.onTap,
  });

  final BadgeProductModel product;
  final bool owned;
  final PlayPricePresentation priceState;
  final String price;
  final bool canRetryPrice;
  final VoidCallback onRetryPrice;
  final VoidCallback onTap;

  String get _gameLabel {
    final String gameName = product.gameName.trim();
    if (gameName.isNotEmpty) {
      return gameName;
    }
    return product.title.replaceAll('Rozeti', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    final String status = owned
        ? _marketText(context, tr: 'Sahipsin', en: 'Owned', de: 'Im Besitz')
        : price;

    return Semantics(
      button: true,
      label: '$_gameLabel, $status',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final TextStyle nameStyle = Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: ExcludeSemantics(
                          child: GameBadgeEmblem(
                            emoji: '',
                            imageUrl: product.imageUrl,
                            gameId: product.gameId,
                            gameName: product.gameName,
                            size: marketCardBadgeSize(constraints.maxWidth),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _gameLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: nameStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _marketText(
                              context,
                              tr: 'İncele',
                              en: 'View',
                              de: 'Ansehen',
                            ),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: palette.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: palette.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _badgeStatus(context, palette),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeStatus(BuildContext context, MarketPalette palette) {
    final TextStyle statusStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700, height: 1.2);
    if (owned) {
      return Text(
        _marketText(context, tr: 'Sahipsin', en: 'Owned', de: 'Im Besitz'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: statusStyle.copyWith(color: palette.owned),
      );
    }

    if (priceState == PlayPricePresentation.failed) {
      return Column(
        children: <Widget>[
          Text(
            price,
            style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
          ),
          TextButton(
            onPressed: canRetryPrice ? onRetryPrice : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 40),
              tapTargetSize: MaterialTapTargetSize.padded,
              foregroundColor: palette.accent,
            ),
            child: Text(
              _marketText(
                context,
                tr: 'Tekrar dene',
                en: 'Try again',
                de: 'Erneut versuchen',
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      price,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: statusStyle.copyWith(
        color: priceState == PlayPricePresentation.ready
            ? palette.accent
            : palette.muted,
      ),
    );
  }
}

class MarketBadgeCatalogHeader extends StatelessWidget {
  const MarketBadgeCatalogHeader({required this.onChanged, super.key});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _marketText(
            context,
            tr: 'Oyun rozetleri',
            en: 'Game badges',
            de: 'Spielabzeichen',
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _marketText(
            context,
            tr: 'Sevdiğin oyunu yanında taşı.',
            en: 'Carry the game you love.',
            de: 'Trag das Spiel, das du magst.',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.muted, height: 1.3),
        ),
      ],
    );
    final Widget search = TextField(
      onChanged: onChanged,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: palette.ink),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: _marketText(
          context,
          tr: 'Rozet ara',
          en: 'Search badges',
          de: 'Abzeichen suchen',
        ),
        hintStyle: TextStyle(color: palette.muted),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: palette.muted),
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = MediaQuery.textScalerOf(context).scale(1);
        final bool sideBySide = constraints.maxWidth >= 600 && scale < 1.3;
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[heading, const SizedBox(height: 10), search],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 12),
            SizedBox(width: constraints.maxWidth * 0.42, child: search),
          ],
        );
      },
    );
  }
}

class MarketFilterBar extends StatelessWidget {
  const MarketFilterBar({
    super.key,
    required this.selected,
    required this.ownedCount,
    required this.onSelected,
  });

  final String selected;
  final int ownedCount;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    final List<Widget> chips = <Widget>[
      _chip(
        context,
        value: 'all',
        label: _marketText(context, tr: 'Tümü', en: 'All', de: 'Alle'),
      ),
      _chip(
        context,
        value: 'available',
        label: _marketText(
          context,
          tr: 'Satışta',
          en: 'For sale',
          de: 'Im Verkauf',
        ),
      ),
      _chip(
        context,
        value: 'owned',
        label: _marketText(
          context,
          tr: 'Rozetlerim',
          en: 'My badges',
          de: 'Meine Abzeichen',
        ),
      ),
    ];
    if (scale >= 1.3) {
      return Wrap(spacing: 4, runSpacing: 4, children: chips);
    }
    return Row(children: chips);
  }

  Widget _chip(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final bool active = selected == value;
    final MarketPalette palette = MarketPalette.of(context);
    return Semantics(
      button: true,
      selected: active,
      label: value == 'owned' ? '$label, $ownedCount' : label,
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? palette.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: active ? palette.ink : palette.muted,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    final String title = filter == 'owned'
        ? _marketText(
            context,
            tr: 'Henüz rozetin yok',
            en: 'You have no badges yet',
            de: 'Du hast noch keine Abzeichen',
          )
        : filter == 'available'
        ? _marketText(
            context,
            tr: 'Satışta rozet yok',
            en: 'No badges are for sale',
            de: 'Keine Abzeichen im Verkauf',
          )
        : _marketText(
            context,
            tr: 'Rozet bulunamadı',
            en: 'No badges found',
            de: 'Keine Abzeichen gefunden',
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.workspace_premium_outlined,
            size: 42,
            color: palette.muted,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: Text(
                _marketText(
                  context,
                  tr: 'Tekrar dene',
                  en: 'Try again',
                  de: 'Erneut versuchen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
