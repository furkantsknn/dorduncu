# GRUP 1 — FINAL DEPLOY / MIGRATION CHECKLIST

Bu belge şimdi uygulanmayacak. Final release/deploy aşamasında kullanılacak.

## Functions
- npm run lint
- npm run build
- functions deploy
- Scheduled functions görünürlüğünü kontrol et:
  - expireEventPaymentReservations
  - processNotificationDeliveryQueue

## Rules
- firestore.rules deploy
- storage.rules değişmediyse mevcut hardened sürüm korunur

## Historical chat preview sanitize
Deploy sonrasında:
- adminSanitizeEventChatPreviews callable yalnız yetkili admin ile çalıştırılır.
- İlk çağrıda cursor verilmez.
- done=false ise dönen cursor sonraki çağrıya verilir.
- done=true olana kadar devam edilir.
- Audit kayıtları kontrol edilir.

## FCM
- Android production token registration.
- Invalid-token cleanup.
- Quiet-hours davranışı.
- Background / terminated deep link.
- Notification preference disable/enable.

## Event lifecycle
- apply
- accept
- roster completes
- payment timer starts
- timeout expires
- roster reopens
- selected user removed
- selected user leaves
- unpaid event cancel
- event complete
- mutual rating

## Payment boundary
A9 tamamlanmadan:
- paid state elle veya client tarafından yazılmamalı.
- address unlock server-side finansal doğrulama olmadan üretim ortamında açılmamalı.
