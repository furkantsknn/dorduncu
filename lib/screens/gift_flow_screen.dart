import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../utils/game_catalog.dart';

import '../models/gift_recipient_profile.dart';
import '../services/digital_purchase_service.dart';
import '../services/gift_recipient_service.dart';
import '../services/play_offer_channel.dart';
import '../services/play_one_time_offer.dart';
import '../services/store_billing_service.dart';
import '../widgets/game_badge_emblem.dart';
import '../widgets/user_avatar.dart';

enum GiftKind { badge, plus }

String giftText(
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

@visibleForTesting
bool giftPaymentReady({
  required GiftRecipientProfile? recipient,
  required GiftProductPresentation? product,
  required bool busy,
}) =>
    !busy && recipient?.isDisplayable == true && product?.isPurchasable == true;

class GiftProductPresentation {
  const GiftProductPresentation({
    required this.id,
    required this.kind,
    required this.title,
    required this.playProductId,
    required this.price,
    required this.productDetails,
    this.gameId = '',
    this.gameName = '',
    this.emoji = '',
    this.imageUrl = '',
    this.unavailableReason = '',
    this.purchaseOptionId = 'buy',
  });

  final String id;
  final GiftKind kind;
  final String title;
  final String playProductId;
  final String price;
  final ProductDetails? productDetails;
  final String unavailableReason;
  final String purchaseOptionId;
  final String gameId;
  final String gameName;
  final String emoji;
  final String imageUrl;

  bool get isPurchasable =>
      id.isNotEmpty &&
      playProductId.isNotEmpty &&
      price.isNotEmpty &&
      productDetails != null &&
      unavailableReason.isEmpty;
}

class GiftFlowScreen extends StatefulWidget {
  const GiftFlowScreen({
    super.key,
    required this.kind,
    required this.productId,
    required this.title,
    this.recipientUid,
    this.recipientName,
    this.recipientAvatarUrl,
  });

  final GiftKind kind;
  final String productId;
  final String title;
  final String? recipientUid;
  final String? recipientName;
  final String? recipientAvatarUrl;

  @override
  State<GiftFlowScreen> createState() => _GiftFlowScreenState();
}

class _GiftFlowScreenState extends State<GiftFlowScreen> {
  final PlayOfferChannel _offers = PlayOfferChannel();
  final StoreBillingService _billing = StoreBillingService();
  final GiftRecipientService _recipients = GiftRecipientService();
  GiftRecipientProfile? _recipient;
  GiftProductPresentation? _product;
  late Future<List<GiftRecipientProfile>> _recipientFuture;
  late Future<List<GiftProductPresentation>> _productFuture;
  bool _busy = false;
  String? _message;
  int _catalogGeneration = 0;
  StreamSubscription<User?>? _accountChanges;
  String? _buyerUid;

  @override
  void initState() {
    super.initState();
    _recipientFuture = _loadRecipients();
    _productFuture = _loadProducts();
    _buyerUid = FirebaseAuth.instance.currentUser?.uid;
    _accountChanges = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == _buyerUid) return;
      _buyerUid = user?.uid;
      setState(() {
        _recipient = null;
        _product = null;
        _recipientFuture = _loadRecipients();
        _productFuture = _loadProducts();
      });
    });
    DigitalPurchaseService.instance.flowPhase.addListener(_onPurchasePhase);
    DigitalPurchaseService.instance.statusCheckInFlight.addListener(
      _onPurchasePhase,
    );
  }

  Future<List<GiftRecipientProfile>> _loadRecipients() async {
    final uid = widget.recipientUid?.trim() ?? '';
    if (uid.isEmpty) return _recipients.loadFriends();
    final hintedName = widget.recipientName?.trim() ?? '';
    if (hintedName.isNotEmpty) {
      final value = GiftRecipientProfile(
        uid: uid,
        displayName: hintedName,
        avatarUrl: widget.recipientAvatarUrl?.trim() ?? '',
      );
      _recipient = value;
      return <GiftRecipientProfile>[value];
    }
    final resolved = await _recipients.load(uid);
    if (resolved == null) throw StateError('recipient_profile_unavailable');
    _recipient = resolved;
    return <GiftRecipientProfile>[resolved];
  }

  Future<List<GiftProductPresentation>> _loadProducts() async {
    final generation = ++_catalogGeneration;
    await _recipientFuture;
    final selectedUid = _recipient?.uid;
    final publicProfile = selectedUid == null
        ? null
        : await FirebaseFirestore.instance
              .collection('public_profiles')
              .doc(selectedUid)
              .get();
    final owned =
        (publicProfile?.data()?['marketBadges'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((b) => (b['productId'] ?? b['badgeId'] ?? '').toString())
            .toSet();
    final badgeSnapshot = await FirebaseFirestore.instance
        .collection('badge_products')
        .where('active', isEqualTo: true)
        .get();
    final plusSnapshot = await FirebaseFirestore.instance
        .collection('plus_products')
        .where('active', isEqualTo: true)
        .get();
    final canonical = GameCatalog.allGames.map((g) => g.id).toSet();
    final candidates =
        <({String id, GiftKind kind, Map<String, dynamic> data})>[
              ...GameCatalog.allGames.map((game) {
                final matches = badgeSnapshot.docs.where(
                  (d) => d.id == game.id,
                );
                return (
                  id: game.id,
                  kind: GiftKind.badge,
                  data: <String, dynamic>{
                    'title': game.name,
                    'gameId': game.id,
                    'gameName': game.name,
                    'emoji': game.emoji,
                    if (matches.isNotEmpty) ...matches.first.data(),
                  },
                );
              }),
              ...plusSnapshot.docs.map(
                (d) => (id: d.id, kind: GiftKind.plus, data: d.data()),
              ),
            ]
            .where((item) {
              return item.kind != GiftKind.badge || canonical.contains(item.id);
            })
            .toList(growable: false);
    final ids = candidates
        .map((c) => c.data['giftGooglePlayProductId']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final products = await _billing.loadProducts(ids);
    final liveOffers = ids.isEmpty
        ? <PlayOneTimeOffer>[]
        : await _offers.queryOneTimeOffers(ids.toList());
    final result = <GiftProductPresentation>[];
    for (final item in candidates) {
      final playId =
          item.data['giftGooglePlayProductId']?.toString().trim() ?? '';
      final personalId =
          item.data['googlePlayProductId']?.toString().trim() ?? '';
      final details = products[playId];
      final option =
          item.data['giftGooglePlayPurchaseOptionId']?.toString().trim() ?? '';
      final validOffers = liveOffers.where(
        (o) =>
            o.productId == playId &&
            o.offerId.isEmpty &&
            o.purchaseOptionId == option &&
            o.formattedPrice.isNotEmpty,
      );
      final verifiedOffer = validOffers.length == 1 ? validOffers.single : null;
      final title = item.data['title']?.toString().trim() ?? '';
      result.add(
        GiftProductPresentation(
          id: item.id,
          kind: item.kind,
          title: title.isEmpty
              ? (item.kind == GiftKind.plus ? 'Dört. Plus' : 'Premium rozet')
              : title,
          playProductId: playId,
          price: verifiedOffer?.formattedPrice ?? '',
          productDetails: details,
          purchaseOptionId: option,
          unavailableReason:
              item.kind == GiftKind.badge && owned.contains(item.id)
              ? 'already_owned'
              : playId.isEmpty ||
                    playId == personalId ||
                    details == null ||
                    verifiedOffer == null
              ? 'not_ready'
              : '',
          gameId: item.data['gameId']?.toString().trim() ?? '',
          gameName: item.data['gameName']?.toString().trim() ?? '',
          emoji: item.data['emoji']?.toString().trim() ?? '',
          imageUrl: item.data['imageUrl']?.toString().trim() ?? '',
        ),
      );
    }
    final selected = result.where(
      (p) => p.id == widget.productId && p.kind == widget.kind,
    );
    if (selected.isNotEmpty && generation == _catalogGeneration) {
      _product = selected.first;
    }
    return result;
  }

  void _onPurchasePhase() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _accountChanges?.cancel();
    DigitalPurchaseService.instance.flowPhase.removeListener(_onPurchasePhase);
    DigitalPurchaseService.instance.statusCheckInFlight.removeListener(
      _onPurchasePhase,
    );
    super.dispose();
  }

  Future<void> _buy() async {
    final recipient = _recipient;
    final product = _product;
    final buyerUid = FirebaseAuth.instance.currentUser?.uid;
    if (!kGiftActionsEnabled ||
        !giftPaymentReady(
          recipient: recipient,
          product: product,
          busy: _busy,
        )) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final intent = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('createGiftPurchaseIntent')
          .call(<String, dynamic>{
            'recipientUid': recipient!.uid,
            'productId': product!.id,
            'kind': product.kind == GiftKind.plus ? 'plus_gift' : 'badge_gift',
          });
      final data = intent.data as Map<Object?, Object?>;
      final playId = data['googlePlayProductId']?.toString().trim() ?? '';
      final intentId = data['giftIntentId']?.toString().trim() ?? '';
      final campaignOfferId = data['campaignOfferId']?.toString().trim() ?? '';
      if (playId != product.playProductId || intentId.isEmpty) {
        throw const DigitalPurchaseException('Hediye ürünü doğrulanamadı.');
      }
      final freshProducts = await _billing.loadProducts(<String>[playId]);
      final freshProduct = freshProducts[playId];
      if (freshProduct == null || freshProduct.price != product.price) {
        throw const DigitalPurchaseException(
          'Fiyat değişti. Güncel fiyatı yeniden kontrol et.',
        );
      }
      final selected = await _selectOffer(
        playId,
        campaignOfferId,
        product.purchaseOptionId,
      );
      final refreshed = await _selectOffer(
        playId,
        campaignOfferId,
        product.purchaseOptionId,
      );
      if (!samePlayOneTimeOffer(selected, refreshed)) {
        throw const PlayOneTimeOfferException(
          'Fiyat değişti. Güncel fiyatı yeniden kontrol et.',
          code: 'offer_changed',
        );
      }
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != buyerUid ||
          _recipient?.uid != recipient.uid ||
          _product?.id != product.id) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(product.title),
          content: Text(
            '${recipient.displayName}\n${giftText(context, tr: 'Ödenecek fiyat', en: 'Price to pay', de: 'Zu zahlender Preis')}: ${selected.formattedPrice}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                giftText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                giftText(
                  context,
                  tr: 'Google Play ile öde',
                  en: 'Pay with Google Play',
                  de: 'Mit Google Play bezahlen',
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (FirebaseAuth.instance.currentUser?.uid != buyerUid ||
          _recipient?.uid != recipient.uid ||
          _product?.id != product.id) {
        return;
      }
      await DigitalPurchaseService.instance.purchase(
        googlePlayProductId: playId,
        kind: DigitalStoreProductKind.badgeNonConsumable,
        internalProductId: product.id,
        giftIntentId: intentId,
        oneTimeOfferToken: selected.offerToken,
      );
      if (mounted) {
        setState(
          () => _message = giftText(
            context,
            tr: 'Hediye teslim edildi.',
            en: 'Gift delivered.',
            de: 'Geschenk zugestellt.',
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _message =
              error.message ??
              giftText(
                context,
                tr: 'Hediye başlatılamadı.',
                en: 'Gift could not be started.',
                de: 'Geschenk konnte nicht gestartet werden.',
              ),
        );
      }
    } on PlayOneTimeOfferException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on DigitalPurchaseException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PlayOneTimeOffer> _selectOffer(
    String playId,
    String campaignOfferId,
    String purchaseOptionId,
  ) async {
    final offers = await _offers.queryOneTimeOffers(<String>[playId]);
    return selectPlayOneTimeOffer(
      offers: offers,
      productId: playId,
      campaignOfferId: campaignOfferId,
      purchaseOptionId: purchaseOptionId,
    );
  }

  Widget _retryCard(String text, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: retry,
            child: Text(
              giftText(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          giftText(
            context,
            tr: 'Hediye et',
            en: 'Send a gift',
            de: 'Verschenken',
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<GiftRecipientProfile>>(
          future: _recipientFuture,
          builder: (context, recipients) {
            if (recipients.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (recipients.hasError) {
              return _retryCard(
                giftText(
                  context,
                  tr: 'Alıcı profili yüklenemedi.',
                  en: 'Recipient profile could not be loaded.',
                  de: 'Empfängerprofil konnte nicht geladen werden.',
                ),
                () => setState(() => _recipientFuture = _loadRecipients()),
              );
            }
            final people = recipients.data ?? const <GiftRecipientProfile>[];
            if (people.isEmpty) {
              return _retryCard(
                giftText(
                  context,
                  tr: 'Hediye gönderebileceğin bir arkadaş bulunamadı.',
                  en: 'No eligible friend was found.',
                  de: 'Kein berechtigter Freund gefunden.',
                ),
                () => setState(() => _recipientFuture = _loadRecipients()),
              );
            }
            _recipient ??= people.length == 1 ? people.single : null;
            return FutureBuilder<List<GiftProductPresentation>>(
              future: _productFuture,
              builder: (context, products) {
                if (products.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (products.hasError) {
                  return _retryCard(
                    giftText(
                      context,
                      tr: 'Google Play ürünleri yüklenemedi.',
                      en: 'Google Play products could not be loaded.',
                      de: 'Google-Play-Produkte konnten nicht geladen werden.',
                    ),
                    () => setState(() => _productFuture = _loadProducts()),
                  );
                }
                final items =
                    products.data ?? const <GiftProductPresentation>[];
                return GiftFlowContent(
                  recipients: people,
                  selectedRecipient: _recipient,
                  products: items,
                  selectedProduct: _product,
                  busy: _busy,
                  message: _message,
                  onRecipientChanged: widget.recipientUid == null
                      ? (value) => setState(() {
                          _recipient = value;
                          _product = null;
                          _productFuture = _loadProducts();
                        })
                      : null,
                  onProductChanged: (value) => setState(() => _product = value),
                  onPay: _buy,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class GiftFlowContent extends StatefulWidget {
  const GiftFlowContent({
    super.key,
    required this.recipients,
    required this.selectedRecipient,
    required this.products,
    required this.selectedProduct,
    required this.busy,
    required this.onRecipientChanged,
    required this.onProductChanged,
    required this.onPay,
    this.message,
  });
  final List<GiftRecipientProfile> recipients;
  final GiftRecipientProfile? selectedRecipient;
  final List<GiftProductPresentation> products;
  final GiftProductPresentation? selectedProduct;
  final bool busy;
  final String? message;
  final ValueChanged<GiftRecipientProfile>? onRecipientChanged;
  final ValueChanged<GiftProductPresentation> onProductChanged;
  final VoidCallback onPay;

  @override
  State<GiftFlowContent> createState() => _GiftFlowContentState();
}

class _GiftFlowContentState extends State<GiftFlowContent> {
  String query = '';
  bool availableOnly = false;
  GiftRecipientProfile? get selectedRecipient => widget.selectedRecipient;
  GiftProductPresentation? get selectedProduct => widget.selectedProduct;
  List<GiftRecipientProfile> get recipients => widget.recipients;
  List<GiftProductPresentation> get products => widget.products;
  bool get busy => widget.busy;
  String? get message => widget.message;
  ValueChanged<GiftRecipientProfile>? get onRecipientChanged =>
      busy ? null : widget.onRecipientChanged;
  ValueChanged<GiftProductPresentation> get onProductChanged =>
      widget.onProductChanged;
  VoidCallback get onPay => widget.onPay;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              giftText(context, tr: 'Alıcı', en: 'Recipient', de: 'Empfänger'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...recipients.map(
              (person) => ListTile(
                selected: selectedRecipient?.uid == person.uid,
                onTap: onRecipientChanged == null
                    ? null
                    : () => onRecipientChanged!(person),
                leading: UserAvatar(
                  displayName: person.displayName,
                  imageUrl: person.avatarUrl,
                ),
                title: Text(person.displayName),
                trailing: Icon(
                  selectedRecipient?.uid == person.uid
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              giftText(context, tr: 'Hediye', en: 'Gift', de: 'Geschenk'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: giftText(
                  context,
                  tr: 'Rozet ara',
                  en: 'Search badges',
                  de: 'Abzeichen suchen',
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    giftText(context, tr: 'Tümü', en: 'All', de: 'Alle'),
                  ),
                  selected: !availableOnly,
                  onSelected: (_) => setState(() => availableOnly = false),
                ),
                ChoiceChip(
                  label: Text(
                    giftText(
                      context,
                      tr: 'Hediye edilebilir',
                      en: 'Available gifts',
                      de: 'Verschenkbar',
                    ),
                  ),
                  selected: availableOnly,
                  onSelected: (_) => setState(() => availableOnly = true),
                ),
              ],
            ),
            if (products.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      const Icon(Icons.card_giftcard_outlined, size: 42),
                      const SizedBox(height: 10),
                      Text(
                        giftText(
                          context,
                          tr: 'Şu anda satın alınabilir bir hediye yok.',
                          en: 'There are no gifts available to buy right now.',
                          de: 'Derzeit sind keine Geschenke verfügbar.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...products
                  .where(
                    (p) =>
                        (!availableOnly || p.isPurchasable) &&
                        p.title.toLowerCase().contains(query),
                  )
                  .map(
                    (product) => ListTile(
                      selected:
                          selectedProduct?.id == product.id &&
                          selectedProduct?.kind == product.kind,
                      onTap: busy || !product.isPurchasable
                          ? null
                          : () => onProductChanged(product),
                      leading: product.kind == GiftKind.badge
                          ? GameBadgeEmblem(
                              emoji: product.emoji,
                              imageUrl: product.imageUrl,
                              gameName: product.gameName,
                              gameId: product.gameId,
                              size: 48,
                            )
                          : const Icon(
                              Icons.workspace_premium_outlined,
                              size: 42,
                            ),
                      title: Text(product.title),
                      subtitle: Text(
                        product.isPurchasable
                            ? product.price
                            : product.unavailableReason == 'already_owned'
                            ? giftText(
                                context,
                                tr: 'Alıcı bu rozete sahip',
                                en: 'Recipient already owns this badge',
                                de: 'Empfänger besitzt dieses Abzeichen',
                              )
                            : giftText(
                                context,
                                tr: 'Hediye olarak henüz sunulmuyor',
                                en: 'Not yet available as a gift',
                                de: 'Noch nicht als Geschenk verfügbar',
                              ),
                      ),
                      trailing: Icon(
                        selectedProduct?.id == product.id &&
                                selectedProduct?.kind == product.kind
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                    ),
                  ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(message!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
      if (products.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  giftPaymentReady(
                    recipient: selectedRecipient,
                    product: selectedProduct,
                    busy: busy,
                  )
                  ? onPay
                  : null,
              child: Text(
                busy
                    ? giftText(
                        context,
                        tr: 'İşleniyor…',
                        en: 'Processing…',
                        de: 'Wird verarbeitet…',
                      )
                    : giftText(
                        context,
                        tr: 'Özeti gör ve öde',
                        en: 'Review and pay',
                        de: 'Prüfen und bezahlen',
                      ),
              ),
            ),
          ),
        ),
    ],
  );
}
