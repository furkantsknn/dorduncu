# Dört. Market, Plus ve Rozet Satın Alma Hazırlık ve Katalog Rehberi

Son denetim: 26 Kasım 2026 (`dorduncu-8e599`, Bundle ID / Package Name: `com.dortapp.dort`)

> Bu belge canlı Firestore (`plus_products`, `badge_products`) ve canlı Google Play Developer API (`diagnoseGooglePlayAccess`, salt-okunur) denetim çıktıları temel alınarak hazırlanmıştır. Canlı veriler veya gelir kayıtları değiştirilmemiş, fiyat uydurulmamış ve gerçek ücretli satın alma yapılmamıştır.

---

## 1. "Şu an satışta değil" Kök Neden Analizi (iOS ve Android)

### iOS (App Store / TestFlight)
1. **Firestore `appleProductId` eşlemesi 0/32 (boş):** Canlı Firestore'da `plus_products` (2 belge) ve `badge_products` (39 belge) kayıtlarının tamamında `appleProductId == ""`. `BadgeProductModel.storeProductIdFor(TargetPlatform.iOS)` boş döndüğü için `playPricePresentation(...)` -> `PlayPricePresentation.missingMapping` -> **"Şu an satışta değil"** gösterir; `PlusProductModel.hasStoreMappingFor(TargetPlatform.iOS)` `false` olduğu için Plus kartı da devre dışı kalır.
2. **Apple Cloud Functions henüz canlıya yayınlanmadı:** `fulfillApplePurchase`, `processAppleAppStoreNotification` ve `adminSetAppleProductId` fonksiyonları `feature/ios-appstore-ready` dalında kodlanmış ve birim testlerinden geçmiş durumdadır; ancak `dorduncu-8e599 / europe-west1` canlı ortamında henüz deploy edilmemiştir.
3. **App Store Connect kayıtları henüz oluşturulmadı:** Otomatik yenilenen Plus aboneliği, 31 adet tek seferlik (Non-Consumable) rozet ürünü, Paid Applications Agreement (Ücretli Uygulamalar Sözleşmesi / Vergi / Banka) ve App Store Server Notifications V2 webhook URL'si App Store Connect panelinde tanımlanmalıdır.

### Android (Google Play)
1. **Canlı Google Play API durumu (26 Kasım 2026 salt-okunur doğrulama):**
   - `monetization.subscriptions.get dort_plus` -> HTTP 200, **`monthly(ACTIVE)`**.
   - `monetization.onetimeproducts.list` -> HTTP 200, **31/31 hedef rozet** (`dort_badge_badminton` .. `dort_badge_yelken`) + `dort_gift_badge_okey` Google Play üzerinde kayıtlıdır.
2. **Neden bazı Android cihazlarda "Şu an satışta değil" görünebilir:**
   - **Test dağıtımı / lisans testi:** Uygulama Google Play İç Test / Kapalı Test kanalı yerine sideload/debug APK ile kurulduysa veya test hesabının e-postası Play Console > **Lisans Testi (License Testing)** listesinde değilse `queryProductDetails` ürünleri `notFound` döndürür ve istemci **"Şu an satışta değil"** gösterir.
   - **Bölge kısıtı (yalnız TR):** 31 rozet ürünü Google Play'de yalnızca Türkiye (`TR`) bölgesi için fiyatlandırılmıştır; TR dışı Play hesabında `notFound` döner.
   - **İstemci fiyat sorgu döngüsü hatası (BU DÜZELTMEDE GİDERİLDİ):** `lib/screens/market_screen.dart` içindeki `_requestPlayPrices` daha önce `_notFoundPlayPriceIds` kümesini hariç tutmadığı için `notFound` dönen ürünlerde her rebuild'de tekrar `queryProductDetails` çağırıyordu; ayrıca aşağı çekip yenileme (`RefreshIndicator`) hata/notFound önbelleğini temizlemiyordu. Artık `pendingStorePriceIds(...)` ile sonsuz sorgu engellenmiş ve pull-to-refresh yenilemesi eklenmiştir.
   - **Canlı Firestore `badge_products/paintball` eksik alanları:** Canlı Firestore'da `badge_products/paintball` belgesi `active=true`, `priceKurus=49900`, `plusPriceKurus=39900`, `googlePlayProductId="dort_badge_paintball"`, `googlePlayPurchaseOptionId="buy"`, `plusGooglePlayOfferId="plus-price"` değerlerine sahiptir; ancak **`gameId` ve `title` alanları boş (`""`)** olduğu için `MarketService.watchActiveBadgeProducts` bu ürünü her iki platformda gizlemektedir.
   - **Canlı Firestore `plus_products/quarterly` eksik alanları:** `active=true`, `durationDays=90`, ancak `priceKurus`, `googlePlayProductId`, `googlePlayBasePlanId` ve `appleProductId` boş. `PlusService.watchActiveProducts` bunu güvenli biçimde filtreler; satışa açılmayacaksa `active: false` yapılmalıdır.

---

## 2. Sunucu Tarafı Güvenlik, İdempotency ve Yaşam Döngüsü Doğrulaması

| Kontrol | Android (Google Play) | iOS (App Store / StoreKit 2) |
| --- | --- | --- |
| Ürün tipi | Plus: Auto-renewing subscription (`dort_plus:monthly`), Rozetler: Non-consumable one-time (`dort_badge_*`) | Plus: Auto-Renewable Subscription, Rozetler: Non-Consumable |
| Sunucu doğrulaması | `fulfillGooglePlayPurchase` (`purchases.subscriptionsv2.get` / `purchases.products.get` + `ProductPurchaseV2`, `enforceAppCheck: true`) | `fulfillApplePurchase` (StoreKit 2 JWS zinciri Apple Root CA-G3 + ES256 imza doğrulama, bundleId/productId/appAccountToken/expiry kontrolü, `enforceAppCheck: true`) |
| Hesap bağlama | `obfuscatedExternalAccountId == uid` + `google_play_purchase_tokens` sahiplik kaydı | UUIDv5 `appAccountToken` (`appleAppAccountTokenForUid(uid)`) + `apple_purchase_transactions` sahiplik kaydı |
| Çift teslimat engeli (Idempotency) | Firestore transaction + `reserveCommercialOperation` (`google_play_subscription_period` / `google_play_badge_token`) | Firestore transaction + `reserveCommercialOperation` (`apple_app_store_subscription_tx` / `apple_app_store_badge_transaction`) |
| İptal / Pending / Restore | `DigitalPurchaseService` + `PurchaseReconcileAction` + `DeliveryRecheckOutcome` + `restorePurchases` | StoreKit 2 `Transaction.updates` + `SK2Transaction.transactions()` + `restorePurchases` |
| İade / Revoke | `processGooglePlayRtdn` (yalnız Play kaynağını kaldırır; admin/Apple hakkını korur) | `processAppleAppStoreNotification` (ASSN V2; yalnız Apple kaynağını kaldırır; admin/Play hakkını korur) |
| Public profil projeksiyonu | `syncPublicMarketBadges` (`badgeEntitlementPolicy.ts` ortak politikası) | Aynı `syncPublicMarketBadges` + `ownedBadgeIsEntitled` ortak politikası |
| Hediye / Kampanya | Yalnız ayrı eşlenmiş Play ürünlerinde aktif (`kGiftActionsEnabled`) | iOS'ta hediye düğmesi gizli (`!_isIOS`), Apple kurallarına uyumlu |

---

## 3. Mağaza Kurallarına Uygun Ürün Kataloğu ve Eşleme Matrisi

> Fiyat sütununda yeni fiyat uydurulmamıştır; yalnızca canlı Firestore kataloğunda kayıtlı mevcut nominal fiyatlar (`priceKurus`) referans olarak yazılmıştır. Uygulama içi gösterilen gerçek fiyat her zaman Google Play Billing veya StoreKit'ten dönen yerel mağaza fiyatıdır.

### A. Dört. Plus (Otomatik Yenilenen Abonelik / Auto-Renewable Subscription)

- **App Store Subscription Group:** `Dört. Plus` (Reference Name: `dort_plus_group`)
- **Otomatik yenileme zorunlu açıklaması (App Store Guideline 3.1.2):**
  - **TR:** "Ödeme, satın alma onayında Apple ID hesabınızdan tahsil edilir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. Aboneliğinizi App Store hesap ayarlarından yönetebilir veya iptal edebilirsiniz."
  - **EN:** "Payment is charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Account Settings."
  - **DE:** "Die Zahlung wird bei Kaufbestätigung über deine Apple-ID abgerechnet. Das Abo verlängert sich automatisch, sofern es nicht mindestens 24 Stunden vor Ablauf gekündigt wird. Verwaltung jederzeit in den App-Store-Kontoeinstellungen."

| Firestore Doc ID | Tür | Süre | Mevcut Firestore Nominal Fiyat | Google Play ID / Base Plan | Önerilen App Store Product ID | TR Ad / Açıklama | EN Ad / Açıklama | DE Ad / Açıklama |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `monthly` | Auto-Renewable Subscription | 1 Ay (30 gün) | `299,00 TRY` (`29900`) | `dort_plus` / `monthly` (**CANLI / ACTIVE**) | `com.dortapp.dort.plus.monthly` | **Dört. Plus (Aylık)** — İleri tarihli etkinlikler, sınırsız oyuncu sayısı, sınırsız açık etkinlik ve profilde Plus etiketi. | **Dört. Plus (Monthly)** — Future event scheduling, unlimited player slots, unlimited active events, and a Plus profile badge. | **Dört. Plus (Monatlich)** — Zukünftige Events, unbegrenzte Spielerzahl, unbegrenzte offene Events und Plus-Profilabzeichen. |

*(Not: `plus_products/quarterly` şu an mağazalarda tanımlı değil ve `priceKurus` boş; satışa sunulmayacaksa `active: false` yapılmalıdır.)*

### B. Oyun Rozetleri (31 Adet Tek Seferlik / Non-Consumable Ürün)

- **Tür (Google Play):** One-time product (`non-consumable`, consume edilmez)
- **Tür (App Store Connect):** Non-Consumable In-App Purchase
- **Mevcut Firestore Nominal Fiyat:** Standart `499,00 TRY` (`49900`); Android aktif Plus teklifi `plus-price`: `399,00 TRY` (`39900`).
- **Mağaza Açıklama Şablonu (TR / EN / DE):**
  - **TR:** "`<Oyun>` profil rozetini hesabına kalıcı olarak ekle ve profilinde sergile."
  - **EN:** "Permanently unlock the `<Game>` profile badge and display it on your Dört. profile."
  - **DE:** "Schalte das `<Spiel>`-Profilabzeichen dauerhaft frei und zeige es in deinem Dört.-Profil."

| # | Firestore ID | Google Play Product ID (31/31 CANLI) | Play Purchase Option | Önerilen App Store Product ID | TR Ad | EN Ad | DE Ad | Canlı Firestore Notu |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `okey` | `dort_badge_okey` | `standard` | `com.dortapp.dort.badge.okey` | Okey Rozeti | Okey Badge | Okey-Abzeichen | `appleProductId` boş |
| 2 | `okey_101` | `dort_badge_okey_101` | `buy` | `com.dortapp.dort.badge.okey_101` | 101 Rozeti | 101 Okey Badge | 101-Okey-Abzeichen | `appleProductId` boş |
| 3 | `batak` | `dort_badge_batak` | `buy` | `com.dortapp.dort.badge.batak` | Batak Rozeti | Batak Badge | Batak-Abzeichen | `appleProductId` boş |
| 4 | `tavla` | `dort_badge_tavla` | `buy` | `com.dortapp.dort.badge.tavla` | Tavla Rozeti | Backgammon Badge | Backgammon-Abzeichen | `appleProductId` boş |
| 5 | `satranc` | `dort_badge_satranc` | `buy` | `com.dortapp.dort.badge.satranc` | Satranç Rozeti | Chess Badge | Schach-Abzeichen | `appleProductId` boş |
| 6 | `bric` | `dort_badge_bric` | `buy` | `com.dortapp.dort.badge.bric` | Briç Rozeti | Bridge Badge | Bridge-Abzeichen | `appleProductId` boş |
| 7 | `king` | `dort_badge_king` | `buy` | `com.dortapp.dort.badge.king` | King Rozeti | King Badge | King-Abzeichen | `appleProductId` boş |
| 8 | `monopoly` | `dort_badge_monopoly` | `buy` | `com.dortapp.dort.badge.monopoly` | Monopoly Rozeti | Monopoly Badge | Monopoly-Abzeichen | `appleProductId` boş |
| 9 | `uno` | `dort_badge_uno` | `buy` | `com.dortapp.dort.badge.uno` | Uno Rozeti | Uno Badge | Uno-Abzeichen | `appleProductId` boş |
| 10 | `jenga` | `dort_badge_jenga` | `buy` | `com.dortapp.dort.badge.jenga` | Jenga Rozeti | Jenga Badge | Jenga-Abzeichen | `appleProductId` boş |
| 11 | `scrabble` | `dort_badge_scrabble` | `buy` | `com.dortapp.dort.badge.scrabble` | Scrabble Rozeti | Scrabble Badge | Scrabble-Abzeichen | `appleProductId` boş |
| 12 | `tombala` | `dort_badge_tombala` | `buy` | `com.dortapp.dort.badge.tombala` | Tombala Rozeti | Tombola Badge | Tombola-Abzeichen | `appleProductId` boş |
| 13 | `ea_fc` | `dort_badge_ea_fc` | `buy` | `com.dortapp.dort.badge.ea_fc` | EA FC Rozeti | EA FC Badge | EA-FC-Abzeichen | `appleProductId` boş |
| 14 | `efootball` | `dort_badge_efootball` | `buy` | `com.dortapp.dort.badge.efootball` | eFootball Rozeti | eFootball Badge | eFootball-Abzeichen | `appleProductId` boş |
| 15 | `tekken` | `dort_badge_tekken` | `buy` | `com.dortapp.dort.badge.tekken` | Tekken Rozeti | Tekken Badge | Tekken-Abzeichen | `appleProductId` boş |
| 16 | `tenis` | `dort_badge_tenis` | `buy` | `com.dortapp.dort.badge.tenis` | Tenis Rozeti | Tennis Badge | Tennis-Abzeichen | `appleProductId` boş |
| 17 | `masa_tenisi` | `dort_badge_masa_tenisi` | `buy` | `com.dortapp.dort.badge.masa_tenisi` | Masa Tenisi Rozeti | Table Tennis Badge | Tischtennis-Abzeichen | `appleProductId` boş |
| 18 | `badminton` | `dort_badge_badminton` | `buy` | `com.dortapp.dort.badge.badminton` | Badminton Rozeti | Badminton Badge | Badminton-Abzeichen | `appleProductId` boş |
| 19 | `squash` | `dort_badge_squash` | `buy` | `com.dortapp.dort.badge.squash` | Squash Rozeti | Squash Badge | Squash-Abzeichen | `appleProductId` boş |
| 20 | `pickleball` | `dort_badge_pickleball` | `buy` | `com.dortapp.dort.badge.pickleball` | Pickleball Rozeti | Pickleball Badge | Pickleball-Abzeichen | `appleProductId` boş |
| 21 | `futbol` | `dort_badge_futbol` | `buy` | `com.dortapp.dort.badge.futbol` | Futbol Rozeti | Football Badge | Fußball-Abzeichen | `appleProductId` boş |
| 22 | `basketbol` | `dort_badge_basketbol` | `buy` | `com.dortapp.dort.badge.basketbol` | Basketbol Rozeti | Basketball Badge | Basketball-Abzeichen | `appleProductId` boş |
| 23 | `voleybol` | `dort_badge_voleybol` | `buy` | `com.dortapp.dort.badge.voleybol` | Voleybol Rozeti | Volleyball Badge | Volleyball-Abzeichen | `appleProductId` boş |
| 24 | `hentbol` | `dort_badge_hentbol` | `buy` | `com.dortapp.dort.badge.hentbol` | Hentbol Rozeti | Handball Badge | Handball-Abzeichen | `appleProductId` boş |
| 25 | `golf` | `dort_badge_golf` | `buy` | `com.dortapp.dort.badge.golf` | Golf Rozeti | Golf Badge | Golf-Abzeichen | `appleProductId` boş |
| 26 | `yelken` | `dort_badge_yelken` | `buy` | `com.dortapp.dort.badge.yelken` | Yelken Rozeti | Sailing Badge | Segeln-Abzeichen | `appleProductId` boş |
| 27 | `kurek` | `dort_badge_kurek` | `buy` | `com.dortapp.dort.badge.kurek` | Kürek Rozeti | Rowing Badge | Rudern-Abzeichen | `appleProductId` boş |
| 28 | `binicilik` | `dort_badge_binicilik` | `buy` | `com.dortapp.dort.badge.binicilik` | Binicilik Rozeti | Equestrian Badge | Reiten-Abzeichen | `appleProductId` boş |
| 29 | `kayak` | `dort_badge_kayak` | `buy` | `com.dortapp.dort.badge.kayak` | Kayak Rozeti | Skiing Badge | Ski-Abzeichen | `appleProductId` boş |
| 30 | `snowboard` | `dort_badge_snowboard` | `buy` | `com.dortapp.dort.badge.snowboard` | Snowboard Rozeti | Snowboard Badge | Snowboard-Abzeichen | `appleProductId` boş |
| 31 | `paintball` | `dort_badge_paintball` | `buy` | `com.dortapp.dort.badge.paintball` | Paintball Rozeti | Paintball Badge | Paintball-Abzeichen | **EKSİK:** Canlı Firestore'da `gameId` ve `title` boş; ayrıca `appleProductId` boş |

---

## 4. Yayın Öncesi Kalan Harici / Operasyonel Adımlar

1. **App Store Connect Sözleşme ve Hesap:** Paid Applications Agreement, banka ve vergi formlarının `Active` durumda olduğunu doğrula.
2. **App Store Connect Ürün Tanımı:** Yukarıdaki `com.dortapp.dort.plus.monthly` aboneliğini ve 31 `com.dortapp.dort.badge.<id>` Non-Consumable ürününü oluştur, TR/EN/DE metinlerini, inceleme ekran görüntülerini ve fiyatları ekle, ilk sürümle birlikte App Review'a bağla.
3. **Firebase Functions Deploy (Apple + Rozet):**
   - `firebase deploy --only functions:fulfillApplePurchase,functions:processAppleAppStoreNotification,functions:adminSetAppleProductId,functions:syncPublicMarketBadges`
4. **App Store Server Notifications V2:** App Store Connect > App Information > App Store Server Notifications bölümünde Production & Sandbox Server URL olarak `https://europe-west1-dorduncu-8e599.cloudfunctions.net/processAppleAppStoreNotification` adresini kaydet.
5. **Firestore Katalog Eşleme ve Onarım:**
   - `adminSetAppleProductId` ile `plus_products/monthly` ve 31 `badge_products/*` kaydına App Store ürün kimliklerini yaz.
   - `badge_products/paintball` belgesinde `gameId: "paintball"`, `gameName: "Paintball"`, `title: "Paintball Rozeti"` alanlarını tamamla.
   - `plus_products/quarterly` satılmayacaksa `active: false` yap.
6. **Cihaz Doğrulaması (Gerçek Ücretli Ödeme Yapmadan):**
   - iOS: TestFlight + Apple Sandbox hesabıyla Plus ve bir rozet için satın alma, iptal, geri yükleme ve iade akışını doğrula.
   - Android: Google Play İç Test / Kapalı Test kanalı + Lisans Testi (`TR` hesabı) ile Plus + 31 rozet + `plus-price` 399 TRY teklifini doğrula.
