# GRUP 1 — FINAL STATUS

## Kapsam

Bu grup A8, A13 ve A16'yı birlikte kapatır.

### A8 — Başvuru / kabul / ödeme öncesi erişim
Tamamlananlar:
- Canonical application lifecycle v2.
- Server-authoritative apply / accept / reject / withdraw.
- accepted_waiting_roster ve accepted_payment_pending ayrımı.
- Server-controlled ödeme süresi.
- Rezervasyon timeout scheduler.
- Timeout sonrası roster reopen ve reservation release.
- Canonical paymentDueAt / reservationExpiresAt.
- Exact/private location backend + Firestore ile ödeme sonrası açılır.
- Event detail UI canonical application state'i canlı okur.
- Leave / remove / cancel unpaid / complete canonical geçişleri.
- Özel etkinlik sohbeti server-authoritative.
- Lifecycle v2 sohbet erişimi paymentStatus paid/completed + address unlocked şartına bağlı.
- Sohbet butonu UI'da da ödeme öncesinde kilitli.
- Mutual rating backend foundation.
- Mutual rating UI integration.
- Public event dokümanından gerçek chat preview içeriği kaldırıldı.
- Eski canonical event preview'ları için admin migration callable hazırlandı.

A9'a bilinçli devredilenler:
- Gerçek ödeme provider bağlantısı.
- Payment success / failure callback.
- paid + address unlocked transition'ının finansal doğrulaması.
- Refund / chargeback / dispute / payout.
- Finansal ledger ve ödeme mutabakatı.

### A13 — Bildirimler
Tamamlananlar:
- Central server notification writer.
- Canonical notificationVersion 2.
- Route/data/source standardı.
- Event transition notification entegrasyonu.
- Chat notification centralization.
- Block relationship recipient filtering.
- Payment eligibility recipient filtering.
- FCM device token registration / removal.
- Notification preferences.
- Quiet hours.
- Retry queue / invalid token cleanup.
- Background/opened-app deep-link routing.
- Initial notification deep-link handling.
- Route allowlist.
- Event existence check before navigation.

Release/platform aşamasına bilinçli devredilenler:
- iOS push provisioning.
- Web push provisioning.
- Production Firebase/reCAPTCHA domain allowlist doğrulaması.
- Gerçek cihaz push smoke testleri.

### A16 — Safety / moderation
Tamamlananlar:
- A5 report/support/block altyapısı reuse edildi.
- Apply ve accept sırasında organizer-applicant block policy backend'de tekrar kontrol edilir.
- Chat server send/edit/delete tarafında block policy kontrol edilir.
- Chat notification recipient'larında block policy uygulanır.
- Client critical event/chat state source-of-truth değildir.
- Private chat content public event dokümanında tutulmaz.
- Canonical audit entegrasyonu kritik lifecycle ve rating işlemlerinde kullanılır.

Bilinçli tasarım kararı:
- Group event chat içinde iki katılımcı birbirini block etmiş olsa bile aynı
  etkinlik sohbetinin tamamını kullanıcı bazında Firestore Rules ile gizlemek
  güvenli ve ölçeklenebilir değildir. Bunun için ayrı recipient-visible message
  modeli gerekir. Mevcut modelde organizer↔participant block policy ve
  notification-level recipient filtering uygulanır. Bu durum A16 için
  yarım yamalak client-side filtre ile çözülmedi.

## Sonuç

GRUP 1 functional/security architecture kapanmıştır.

Runtime/manual test:
- Bilinçli olarak yapılmadı.
- A18 QA aşamasında A'dan Z'ye yapılacak.

Deploy:
- Bilinçli olarak yapılmadı.
- Release hazırlığında yapılacak.
