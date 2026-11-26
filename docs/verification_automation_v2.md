# Dört. — kimlik doğrulama otomasyonu, güvenli geçiş planı

## Mevcut durum (26 Kasım 2026)

- `submitVerification` yeni başvuruyu `verification_requests` içinde `pending` oluşturur.
- `analyzeVerificationOnWrite` Firestore tetikleyicisi `runVerificationAnalysis` ile OCR,
  TCKN kontrol hanesi/tekillik ve selfie'de tek yüz tespitini gerçekleştirir.
- Google Cloud Vision `faceDetection` aynı kişi karşılaştırması, canlılık
  doğrulaması veya belge gerçekliği testi değildir.
- `decideVerification` tüm temel kontrolleri geçse bile `pending` bırakır.
  Admin `processVerification` ile onay/red/düzeltme kararı verir.
- **Mevcut sistemin temel kontrolü geçti sonucu kimlik-selfie eşleşmesi değildir.**

## Ayrı dalda hazır koruyucu modül

`functions/src/users/verificationAutomationPolicy.ts` henüz canlı akışa bağlı
değildir. Yeni modül sadece sunucuda doğrulanmış sonuçlara göre başvurunun
`manual_review`, `recapture_required` veya `eligible_for_auto_approval`
olup olmadığını sınıflandırır. Otomatik onay özelliği kapalı kaldığında
**her koşulda manuel inceleme** döner. Tek başına kullanıcıyı onaylamaz,
rozet vermez, Cloud Functions deploy etmez ve mevcut kimlik kayıtlarını
değiştirmez.

## Gerçek otomasyon için tamamlanması gerekenler

1. **Sağlayıcı seçimi:** Türkiye kimlik kartı desteği, belge gerçekliği,
   NFC isteğe bağlı, liveness/deepfake koruması, selfie-belge yüz eşleşmesi,
   Flutter Android+iOS SDK, API/webhook, SLA ve işletim maliyeti.
2. **KVKK ve güvenlik:** Biyometrik veri işleme için uygun hukuki şart ve
   aydınlatma/izin akışı; veri işleyen sözleşmesi, aktarım ülkeleri ve yurt
   dışına aktarım güvenceleri; en az veri ve kayıt saklama süresi. Bu
   başlıklar ürün sahibi ve yetkin hukuk danışmanı tarafından onaylanmalıdır.
3. **İstemci:** Test ve canlılık SDK'sı, belge fotoğrafında kalite kontrolü,
   kullanıcıya gerekçe ve yeniden çekim seçeneği. Sıradan galeriden selfie
   yükleme otomatik güvenilir sonuç olarak kabul edilmez.
4. **Sunucu:** Kullanıcı girişine değil, sağlayıcıdan gelen imzalı webhook'a
   güvenilir. HMAC/imza doğrulama, zaman aşımı, `uid`/`submissionId` eşleme,
   replay koruması, idempotent karar, düşük-risk sonuç kayıtları; raw
   biyometrik veri/log ve API anahtarı Firestore'a yazılmaz.
5. **Karar:** Tam kanıt + kullanıcıya ait güncel başvuru + izin + açık
   etkinleştirme bayrağıyla ancak uygunluk hesaplanır. Ardından mevcut
   doğrulama kilitleri ve benzersiz kimlik rezervasyonunu aynı transaction
   içinde gözeten ayrı, denetim kayıtlı server-only onay yazıcısı gerekir.
   Yanlış eşleşme/belirsizlik/üçüncü taraf servis hatası otomatik kalıcı
   ret yerine admin incelemesine yönlendirilir.
6. **Admin:** Neden kodları, kontrol durumları, sorumlu admin, tekrar deneme,
   karar denetimi, itiraz/düzeltme ve kayıt silme ekranları.
7. **Pilot:** Sahte/başkasına ait belge, kayıtlı kimliğin yeniden kullanımı,
   düşük kaliteli fotoğraf, canlılık taklidi, farklı kimlik-selfie,
   aynı başvurunun tekrar işlenmesi, başarısız webhook, izin yokluğu,
   iOS ve Android cihaz testleri. Önce gözlem (shadow) modu, sonra
   sınırlı rollout; canlı otomatik onay baştan kapalı.

## Korunacak sınırlar

- Android/Google Play, iOS/TestFlight, mevcut SMS ve canlı Firebase
  yapılandırması değiştirilmez.
- Gerçek kullanıcı kimlik fotoğrafı, yüz şablonu veya TCKN hiçbir test
  fikstürüne/GitHub'a eklenmez.
- KYC hizmeti seçilip hukuki ve teknik şartlar karşılanmadan otomatik
  `verified: true` üretilemez.
- Mevcut `verificationDecision.ts` ve manuel admin onayı çalışmaya devam eder.

## Ayrı takip işleri

- Profilde **Acemi/Orta/Usta** chip kontrastı ve seviye seçimi regresyon testi.
- Plus ve rozetlerin iOS `appleProductId`, Android `googlePlayProductId`,
  mağaza kataloğu, fiyat/aktivasyon ve doğrulanmış satın alma akışı.
- Profil kaydının uzun sürmesi için aşama bazlı anonim süre ölçümü.
