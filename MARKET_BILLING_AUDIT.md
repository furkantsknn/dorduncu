# Dört. V1 market + Google Play Billing denetimi

Tarih: 6 Ekim 2026  
Kapsam: kod tarafındaki blocker ve eksik maddeler kapatıldı. Deploy yapılmadı, Play Console’a dokunulmadı.

V1 kararı: etkinlik ödemesi ve cüzdan yok. Plus = Google Play aboneliği. Rozet = Google Play tek seferlik, tüketilmeyen ürün.

Satın alma ancak Firestore `googlePlayProductId` doluysa başlar. Değeri admin eşleme ekranından yazılır. Seed bu alanı ezmez. Canlı satış Play Console ürünleri ve eşleme girilene kadar kapalıdır.

1. BLOCKER: **0**
2. MISSING CODE: **0**
3. MANUAL PLAY CONSOLE: **10**
4. DONE: **48**

---

## Özet

Play satın alma istemcisi `DigitalPurchaseService` → `StoreBillingService` (`in_app_purchase` 3.3.0 / Android eklentisi 0.5.3). Sunucu doğrulama `fulfillGooglePlayPurchase` (europe-west1, App Check zorunlu). Android Publisher çağrıları `functions/src/commercial/googlePlayVerification.ts`. RTDN `processGooglePlayRtdn`, konu adı `dorduncu-google-play-rtdn`.

Cüzdanla Plus/rozet satın alma `purchasePlus` / `purchaseBadge` içinde durur. İkisi de `assertLegacyDigitalWalletPurchaseAllowed` ister. `system_settings/global.legacyDigitalWalletPurchasesEnabled` yoksa çağrı reddedilir. Market ekranı bu fonksiyonları çağırmaz.

---

## 1. Plus

| Kontrol | Durum | Kanıt |
| --- | --- | --- |
| `plus_products` koleksiyonu ve model | DONE | `lib/models/plus_product_model.dart`. Firestore okuma serbest, istemci yazması kapalı (`firestore.rules`). |
| `googlePlayProductId` | MANUAL PLAY CONSOLE | Alan modelde var. Admin eşleme ekranı `adminSetGooglePlayProductId` ile yazar ve audit log düşer. Seed alanı ezmez. Boşsa satın alma butonu kapalıdır. Değer, Console ürünü açıldıktan sonra girilir. |
| `googlePlayBasePlanId` | MANUAL PLAY CONSOLE | Plus belgesinde ayrı alandır. Admin ekranından yazılır, backend biçimini doğrular ve audit log düşer. Boş bırakılabilir; boşsa satın alma kapalıdır ve katalog fiyatı gösterilmez. Seed bu alanı yazmaz. Sunucu, satın alma token’ındaki line item `offerDetails.basePlanId` değerini bu alanla karşılaştırır ve `offerId` dolu promosyonu reddeder. |
| ProductDetails lookup | DONE | `DigitalPurchaseService.loadLocalizedPrices` / `_loadProduct`. Ürün Play’de yoksa satın alma “Ürün Google Play üzerinde bulunamadı” ile durur. |
| Subscription purchase | DONE | `DigitalStoreProductKind.plusSubscription` → `StoreBillingService.buySubscription`. |
| Base plan / offer token | DONE | `selectStandardPlusBasePlan` aynı Play ürünündeki teklifleri liste sırasına göre seçmez. `plus_products.googlePlayBasePlanId` ile eşleşen ve `offerId` boş olan tek standart teklif alınır. Fiyat ve dönem bu teklifin tek sonsuz fiyat fazındandır. `GooglePlayPurchaseParam.offerToken` aynı `GooglePlayProductDetails` örneğindendir. Hedef yoksa, promosyon varsa veya birden fazla standart teklif varsa satın alma kapanır. Rozet akışı ayrıdır. Gerçek Play satın alma: TEST BEKLİYOR. |
| Acknowledgement | DONE | Sunucu `purchases/subscriptions/{product}/tokens/{token}:acknowledge`. İstemci ancak `success == true` sonrası `completePurchase` çağırır. |
| Server verification | DONE | `verifyGooglePlaySubscription` → `subscriptionsv2`. Aktif, grace veya iptal edilmiş ama süresi dolmamış abonelik hak sayılır. |
| Restore purchases | DONE | Market’te “Google Play satın alımlarını geri yükle”. Oturum açılınca `attachSession` da `restorePurchases` çağırır. Geri gelen token aynı fulfill fonksiyonuna gider. |
| Entitlement write | DONE | Sunucu `users/{uid}` üzerine `plus`, `isPlus`, `plusExpiresAt`, `plusGooglePlayProductId`, `plusGooglePlayTokenHash`, `plusSubscriptionState` yazar. İstemci bu alanları yazmaz. `isPlusMembershipActive` süre dolmuş bayrağı hak saymaz. |
| Expiry / cancel | DONE | RTDN abonelik bildirimi Play durumunu yeniden okur. Hak varsa süre güncellenir. Hak yoksa ve token bu kullanıcının güncel token’ıysa `plus` ve `isPlus` kapatılır. İptal, süre bitene kadar hak bırakabilir. |
| RTDN | DONE | `processGooglePlayRtdn`. Aynı CloudEvent id tamamlandıysa tekrar işlenmez. |
| Aboneliği yönet linki | DONE | Aktif Plus kullanıcısında “Aboneliği yönet”. Link `sku` ve `package=com.dortapp.dort` taşır. Açılamazsa hesap abonelik sayfasına düşer. |

---

## 2. Rozetler

| Kontrol | Durum | Kanıt |
| --- | --- | --- |
| `badge_products` | DONE | Model `BadgeProductModel`. İstemci yazması kapalı. Market bu koleksiyonu okur. |
| Mevcut 30 rozet | DONE | `seedBadgeProducts` canonical 30 `GameCatalog` id’sini yazar. Eski sekiz id silinmez; belge varsa `active=false` olur. `googlePlayProductId`, satın alma ve `owned_badges` korunur. |
| `googlePlayProductId` | MANUAL PLAY CONSOLE | Alan modelde okunur. Seed yazmaz ve mevcut değeri ezmez. Admin eşleme ekranından girilir. Boşsa buton “Google Play eşlemesi bekleniyor” ve kapalıdır. |
| ProductDetails fiyatı | DONE | Dolu Play id için `queryProductDetails`. Fiyat gelirse o metin gösterilir. Gelmezse katalog `priceKurus` yedek metindir. Satın alma yedek fiyattan tahsil etmez; Play ürünü bulunamazsa durur. |
| One-time non-consumable | DONE | `buyNonConsumable`. Sunucu `purchases/products/{id}/tokens/{token}` ile `purchaseState == 0` arar. |
| Acknowledge | DONE | `purchases/products/...:acknowledge`, sonra istemci `completePurchase`. |
| Server fulfillment | DONE | `fulfillBadgePurchase`. `users/{uid}/owned_badges/{productId}`. Hediye alıcısı varsa rozet alıcıya yazılır; Plus hediye edilemez. |
| Duplicate / idempotency | DONE | Rozet anahtarı ham token’ın SHA-256’sı (`google_play_product_token`). Aynı token ikinci kez entitlement yazmaz (`idempotentReplay: true`). Ham token Firestore’a yazılmaz; `google_play_purchase_tokens` hash tutar. |
| Restore | DONE | Aynı restore akışı. Non-consumable geri yükleme Play token’ını yeniden fulfill eder. |
| `owned_badges` | DONE | Market sahiplik setini buradan okur. Sahip olunan rozetin satın alma butonu kapalıdır (“Bu rozete sahipsin”). İstemci yazması kapalı. |
| Refund / revoke | DONE | RTDN `voidedPurchaseNotification`. Rozet tam iadesinde (`refundType == 1`) `owned_badges` kaydı kapatılır. Kısmi iade entitlement silmez. Plus iadesi abonelik durumunu yeniden okuyup hak varsa süreyi korur. |

---

## 3. Backend

| Kontrol | Durum | Kanıt |
| --- | --- | --- |
| Purchase verify function | DONE | Callable `fulfillGooglePlayPurchase`. Giriş ve App Check zorunlu. İç ürün id’sini istemci seçmez; Play ürün id’si `plus_products` veya `badge_products` içinden çözülür. |
| Android Publisher API | DONE | `androidpublisher/v3`. Paket parametresi `ANDROID_PACKAGE_NAME`, varsayılan `com.dortapp.dort`. |
| Service account | MANUAL PLAY CONSOLE | Repoda Play JSON anahtarı yok. İstek, Functions çalışma kimliğinin `getAccessToken()` sonucuyla gider. Bu hesabın Play Console’da davetli olması ve Android Publisher API’nin açık olması gerekir. Kod ayrı bir `androidpublisher` scope yazmaz. Yetki yoksa fonksiyon “Google Play API yetkisi yapılandırılmamış” döner. |
| Purchase token storage | DONE | Saklanan değer SHA-256 hash. Ledger idempotency belgesi ham anahtarı değil hash’i tutar. |
| Order id / product id / user id | DONE | `commercial_operations`: `userUid`, `relatedProductId`, `providerTransactionId` (order id), `providerReference` (token hash). Kullanıcıda `plusGooglePlayProductId`. Rozet belgesinde `googlePlayProductId` ve `googlePlayPurchaseTokenHash`. |
| Audit / ledger | DONE | `reserveCommercialOperation`, `writeAuditLogInTransaction` (`google_play_plus_activated`, `google_play_badge_activated`). Yaşam döngüsü `google_play_lifecycle_events`. Bu koleksiyonları istemci yazamaz. |
| RTDN topic | MANUAL PLAY CONSOLE | Kod konusu: `dorduncu-google-play-rtdn`, bölge `europe-west1`. Play Console bu konuya bağlanmadan bildirim gelmez. Deploy bu turda yapılmadı. |
| Refund / revoke | DONE | Voided purchase, bekleyen iade incelemesi ve abonelik bildirimleri ayrılmış. Eşleşmeyen token `google_play_unmatched_notifications` altına yazılır. |

---

## 4. UI

| Kontrol | Durum | Kanıt |
| --- | --- | --- |
| Market’te gerçek Play fiyatı | DONE | Rozet `_displayPrice` önce Play metnini kullanır; Play cevabı yoksa katalog kuruşu gösterilir. Plus fiyatı ve dönemi yalnızca seçilen base plan teklifinden gelir. Play fiyatı yoksa katalog fiyatı gösterilmez ve satın alma kapalıdır. |
| Loading / error / cancel | DONE | `_purchaseBusy` butonu kilitler. İptal: “Satın alma işlemi iptal edildi.” Play veya Functions hatası snackbar. Pending durumda kilit kalır, hata sayılmaz. |
| Restore purchases | DONE | Plus sayfasındaki geri yükle butonu ve oturum açılışındaki `attachSession`. |
| Plus ekranı | DONE | Market içinden “Dört. Plus” alt sayfası. Aktif hakta satın alma kapalıdır ve “Plus üyeliğin aktif” yazılır. |
| Rozet sahipliği | DONE | `owned` filtresi ve “Bu rozete sahipsin”. |
| Satın alınmış ürünü yeniden alma | DONE | Sahip olunan rozetin butonu kapalıdır. Aktif Plus, `plus` / `isPlus`, gelecek `plusExpiresAt` ve abonelik durumuna göre satın almayı başlatmaz. |
| Event payment / wallet sızıntısı | DONE | Market `WalletScreen` veya `PaymentScreen` açmaz. Dijital satın alma Google Play der. Eski cüzdan callable’ları varsayılan olarak kapalıdır. |

---

## 5. Admin

| Kontrol | Durum | Kanıt |
| --- | --- | --- |
| Plus entitlement görüntüleme | DONE | Kullanıcı detayında aktif/pasif, `plusExpiresAt`, `plusSubscriptionState`, `plusGooglePlayProductId` ve kaynak “Google Play” görünür. Eski admin bayrağı ayrıdır ve süre yazmaz. |
| Rozet sahipliği | DONE | Kullanıcı detayı `users/{uid}/owned_badges` listeler: kimlik, ad, aktiflik, Play ürünü, satın alma zamanı ve hak kaldırma. Doğrulama rozeti ayrı durur. |
| Purchase ledger | DONE | “Play satışları” ekranı `commercial_operations`, `market_sales` ve yaşam döngüsünü finance yetkisiyle okur. Ham purchase token gösterilmez. |
| Refund / revoke görünürlüğü | DONE | Aynı ekranın “İade ve yaşam döngüsü” sekmesi Play olayını okur. Admin buradan iade başlatamaz. |
| Play product mapping | DONE | “Play ürün eşlemesi” Play kimliğini finance veya content yetkisiyle kaydeder. Plus satırında `googlePlayBasePlanId` ayrı alandır; backend biçimini doğrular. Rozet satırına base plan yazılmaz. İç ürün kimliği ayrı kalır. Değişiklik audit kaydına yazılır. Boş değer eşlemeyi temizler. Seed mevcut eşlemeyi ezmez. |

---

## 6. Legal

| Kontrol | Durum | Kanıt |
| --- | --- | --- |
| `plus_subscription` | DONE | Plus alt sayfasında “Plus Abonelik Koşulları”. Kod `LegalVersions` ile aynı. TR/EN/DE dosyası var. Metin Google Play aboneliği, Play fiyatı ve Play iadesini söyler. |
| `automatic_renewal` | DONE | Aynı sayfada “Otomatik Yenileme”. Yenilemenin Dört. içinden kapatılmadığı yazıyor. |
| `digital_products` | DONE | Rozet sayfasında “Dijital Ürün Koşulları”, satın al butonunun üstünde. Tek seferlik rozet, Play fiyatı ve Play iadesi yazıyor. |

Bu üç belge girişteki zorunlu kabul listesinde değil. Market satın almadan önce link olarak duruyorlar. Ayrı bir “okudum” kaydı yok.

---

## 7. Analytics

| Olay | Durum |
| --- | --- |
| `plus_purchase_started` | DONE |
| `plus_purchase_success` | DONE |
| `plus_purchase_failed` | DONE |
| `badge_purchase_started` | DONE |
| `badge_purchase_success` | DONE |
| `badge_purchase_failed` | DONE |

`firebase_analytics` market satın alma yolunda bu olayları yazar. Parametreler `internal_product_id`, `google_play_product_id`, `source=market` ve hata durumunda `error_code` ile sınırlıdır. Purchase token ve order id gönderilmez.

---

## 8. Play Console’da manuel işler

Bunlar kodda tamamlanmış sayılmaz. Hepsi MANUAL PLAY CONSOLE.

1. Merchant / ödeme profili
2. Banka hesabı ve vergi bilgisi
3. Plus abonelik ürünü ve standart base plan. Promosyon teklifi V1 satın almasına girmez. Uygulama, `googlePlayBasePlanId` ile eşleşen ve `offerId` boş olan tek teklifi kullanır. Başka teklife düşmez.
4. Base plan fiyatı ve dönem
5. 30 rozet ürünü. Kimlikler canonical `GameCatalog` id’leriyle aynı olmalı.
6. Her rozet için tek seferlik, tüketilmeyen ürün fiyatı
7. Lisans test kullanıcısı
8. Google Cloud’da Android Publisher API
9. Cloud Functions çalışma hesabına Play Console erişimi (sipariş / abonelik görme)
10. RTDN: Pub/Sub konusu `dorduncu-google-play-rtdn`, Play Console bu konuya bağlı, fonksiyon deploy edilmiş

Console ürünü açıldıktan sonra admin “Play ürün eşlemesi” ekranından girilecekler:

- `plus_products/{id}.googlePlayProductId`
- `plus_products/{id}.googlePlayBasePlanId`
- `badge_products/{gameId}.googlePlayProductId`

Boş Play ürün kimliği veya boş Plus base plan ile satın alma butonu açılmaz. Plus ekranında katalog fiyatı satın alma fiyatı olarak gösterilmez.

Gerçek Google Play satın alma testi bu turda yapılmadı: TEST BEKLİYOR.

Kapalı testte birleşik manifestte `com.android.vending.BILLING` olduğunun doğrulanması da konsol/paket kontrolüdür. Uygulama manifestinde bu izin elle yazılmamıştır; `in_app_purchase` eklentisinin birleşik manifeste eklemesi beklenir.

---

## Blocker listesi

Kod blocker’ı yok.

Kalan iş MANUAL PLAY CONSOLE: ürünler, fiyatlar, lisans test kullanıcısı, Android Publisher yetkisi, RTDN konusu ve admin eşleme ekranına `googlePlayProductId` ile Plus `googlePlayBasePlanId` girilmesi. Bu değerler girilmeden market satın alma butonu kapalı kalır. Gerçek Play satın alma: TEST BEKLİYOR.
