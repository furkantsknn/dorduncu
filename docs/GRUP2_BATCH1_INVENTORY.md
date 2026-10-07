# GRUP 2 / BATCH 1 — MEVCUT TİCARİ SİSTEM ENVANTERİ

## 1. Mevcut backend ödeme alanları

### Event payment
Dosya:
`functions/src/payments/startPayment.ts`

Mevcut davranış:
- App Check zorunlu.
- Auth zorunlu.
- Yalnızca etkinlik sahibi çağırabiliyor.
- Gerçek ödeme sağlayıcısı yok.
- Sadece event üzerinde:
  - `paymentStatus = payment_pending`
  - `paymentRequired = true`
  - `paymentInitiatedBy`
  - `paymentInitiatedAt`
  - `durum = odeme_bekliyor`
  - `status = payment_pending`
  yazıyor.

Sonuç:
Bu fonksiyon gerçek ödeme başlatmıyor. A9'da yeniden konumlandırılmalı.
Canonical Group 1 akışında ödeme yapacak kişi/katılımcı modeliyle uyumlu hale
getirilmesi gerekiyor.

---

## 2. paymentSessions

Mevcut kullanım:
- `acceptApplication.ts`
- `cancelUnpaidEvent.ts`
- `expireEventPaymentReservations.ts`
- `leaveEvent.ts`
- `removeSelectedPlayer.ts`

Amaç:
- event-level rezervasyon / ödeme bekleme state'i.

Sonuç:
Bu koleksiyon gerçek provider payment intent değildir.
A9'da provider intent/session ile karıştırılmamalı.
`paymentSessions` event reservation orchestration için korunabilir; finansal
ledger değildir.

---

## 3. Wallet

Backend:
- `requestWithdrawal.ts`
- `cancelWithdrawal.ts`
- `adminAdjustWallet.ts`

Flutter:
- `wallet_service.dart`
- `wallet_screen.dart`
- admin wallet ekranları

Firestore:
- `wallets/{uid}`
- `wallets/{uid}/transactions`
- `wallets/{uid}/withdrawals`
- `wallets/{uid}/bank_accounts`

Mevcut güvenlik:
- Wallet ve transaction client write kapalı.
- Kullanıcı kendi wallet verisini okuyabiliyor.
- Finance yetkili admin okuyabiliyor.
- Withdraw create/update client tarafından doğrudan yapılamıyor.

Sonuç:
Wallet server-authoritative prensibine uygun temel mevcut.
Ancak A9'da ledger alanları ve finansal source/type standardı merkezi hale
getirilmeli.

---

## 4. Plus

Backend:
`functions/src/market/purchasePlus.ts`

Flutter:
`lib/services/plus_service.dart`

Firestore:
- `plus_products`
- `users/{uid}/plus_purchases`
- `market_sales`
- `wallets/{uid}/transactions`

Mevcut satın alma:
- App Check var.
- Server transaction var.
- Product backend'den okunuyor.
- `availableBalanceKurus` düşülüyor.
- Kullanıcının `plus`, `isPlus`, `plusPlan`, `plusExpiresAt` alanları güncelleniyor.
- Purchase + wallet transaction + market sale yazılıyor.

KRİTİK:
Plus bir dijital entitlement olduğu için Google Play Android dağıtımında
wallet bakiyesinden doğrudan satın alma nihai mimari olarak kullanılmamalı.
A10'daki entitlement mantığı korunabilir ancak purchase authority Play Billing
purchase token doğrulamasına taşınmalı.

---

## 5. Badge / Market

Backend:
`functions/src/market/purchaseBadge.ts`

Flutter:
- `market_service.dart`
- `market_screen.dart`
- `market_payment_sheet.dart`

Firestore:
- `badge_products`
- `users/{uid}/owned_badges`
- `market_sales`
- `wallets/{uid}/transactions`

Mevcut satın alma:
- App Check var.
- Server transaction var.
- Product backend'den okunuyor.
- Duplicate ownership engelleniyor.
- `marketBalanceKurus` veya `availableBalanceKurus` düşülebiliyor.
- owned badge + wallet transaction + sale yazılıyor.

KRİTİK:
Badge uygulama içi dijital ürün olduğundan Android üretim dağıtımında nihai
purchase authority Google Play Billing doğrulaması olmalı.
Mevcut entitlement oluşturma mantığı yeniden kullanılabilir.

Ek notlar:
- `purchaseBadge.ts` içinde aynı PAYMENT SOURCE console log iki kez mevcut.
- Kod cleanup daha sonra, işlevsel mimari dönüşüm sırasında yapılmalı.

---

## 6. Flutter payment UI

### Event payment
`lib/screens/payment_screen.dart`
- `startPayment` callable çağrılıyor.
- Gerçek ödeme altyapısının henüz bağlı olmadığı mevcut ekranda belirtiliyor.

### Market payment
`lib/screens/market_payment_sheet.dart`
- Kullanıcı:
  - market bakiyesi
  - available balance
  arasında seçim yapabiliyor.

Sonuç:
Digital-goods akışı Play Billing'e taşındığında bu seçim ekranı dijital
ürünler için kullanılmamalı.
Wallet/market bakiyesi gerçek para karşılığı digital store bypass haline
gelmemeli.

---

## 7. Google Play Billing durumu

Mevcut `pubspec.yaml` içinde:
- `cloud_functions`
- Firebase paketleri

var; ancak `in_app_purchase` / Google Play Billing entegrasyonu görünmüyor.

Sonuç:
A9/A10/A11 içinde yeni billing katmanı gerekecek.

---

## 8. Firestore ticari güvenlik durumu

Mevcut rules:
- `badge_products`: authenticated read, client write false.
- `plus_products`: authenticated read, client write false.
- `wallets`: owner/finance read, client create/update/delete false.
- wallet transactions: owner/finance read, client write false.
- wallet withdrawals: owner/finance read, client write false.
- `payments`: ilgili kullanıcı/finance read, client write false.
- `market_orders`: finance read, client write false.

Sonuç:
Client-write kapatma yönü doğru.
A9'da yeni finansal koleksiyonlar için aynı default-deny yaklaşımı korunacak.

---

# RİSK HARİTASI

## R1 — Digital purchase policy boundary
Plus ve Badge şu anda internal wallet ile satın alınabiliyor.
Google Play dağıtımında dijital ürünler için bunun yerine Play Billing
authoritative purchase hattı kurulmalı.

## R2 — Event payment authority
`startPayment` gerçek provider başlatmıyor ve organizer-only.
Group 1 application-level payment lifecycle ile tam hizalı değil.

## R3 — Ledger dağınıklığı
Finansal kayıtlar:
- wallet transactions
- market_sales
- plus_purchases
- owned_badges
- paymentSessions
gibi farklı yerlere dağılıyor.
Tek canonical immutable commercial ledger eksik.

## R4 — Idempotency
Badge duplicate ownership transaction ile korunuyor.
Plus purchase her çağrıda yeni purchase id oluşturuyor.
Provider webhook veya billing callback geldiğinde tekil işlem anahtarı
gerekiyor.

## R5 — Refund / dispute / chargeback
Mevcut digital purchase akışlarında gerçek provider refund/chargeback state
machine yok.

## R6 — Reconciliation
Provider/billing kayıtları ile internal entitlement/ledger kayıtlarını
karşılaştıran reconciliation mekanizması yok.

---

# KORUNACAK MEVCUT PARÇALAR

- Wallet client write deny.
- App Check kullanan purchase callable yaklaşımı.
- Server transaction mantığı.
- Product catalog backend source-of-truth.
- Plus expiry extension mantığı.
- Badge duplicate entitlement kontrolü.
- Group 1 canonical application/payment/address lifecycle.
- Canonical audit helper.
- Admin finance/RBAC altyapısı.

---

# DEĞİŞECEK PARÇALAR

## Event payment
`startPayment`
→ provider-backed participant payment intent/session oluşturacak yeni yapıya
evrilecek.

## Plus
`purchasePlus`
→ wallet deduction yerine verified Google Play purchase fulfillment katmanına
evrilecek.

## Badge
`purchaseBadge`
→ wallet deduction yerine verified Google Play purchase fulfillment katmanına
evrilecek.

## MarketPaymentSheet
→ digital products için production purchase method olmaktan çıkarılacak.

---

# GRUP 2 HEDEF MİMARİ

## Commercial layer

### 1. Canonical commercial operation
Her para/dijital entitlement işlemi:
- operationId
- userId
- type
- provider
- providerTransactionId / purchaseToken hash
- currency
- grossAmount
- feeAmount
- netAmount
- state
- idempotencyKey
- createdAt
- updatedAt
- audit context

alanlarına sahip immutable/append-first ledger üzerinden izlenecek.

### 2. Digital goods
Android:
Flutter
→ Google Play Billing
→ purchase token
→ Cloud Function
→ Google Play Developer API verification
→ idempotent fulfillment
→ entitlement
→ audit/ledger

Client `plus=true` veya owned badge yazamaz.

### 3. Event payment
Flutter
→ backend create payment intent
→ external provider checkout
→ provider webhook
→ verify payment
→ ledger
→ canonical application `paid`
→ `addressAccessStatus=unlocked`
→ chat unlock
→ server notification

Client callback tek başına ödeme başarısı sayılmaz.

### 4. Refund/dispute
Provider webhook
→ ledger state
→ application refund/dispute state
→ address/chat access policy
→ notifications
→ finance admin queue
→ audit

---

# BATCH 2'YE GEÇİŞ

Bir sonraki paket kod yazacak.

GRUP 2 / BATCH 2:
**Commercial Ledger + Idempotency Foundation**

İlk oluşturulacaklar:
- merkezi commercial operation model/helper
- idempotency helper
- server-only Firestore collections/rules
- normalized money/currency fields
- provider-agnostic transaction states
- canonical audit linkage

Henüz provider bağlanmayacak.
Önce finansal omurga kurulacak.
