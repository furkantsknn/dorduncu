# Dört. — Kimlik ve Selfie Doğrulama Otomasyonu, Güvenli Geçiş Planı ve KVKK Değerlendirmesi

## 1. Mevcut Durum (26 Kasım 2026)

- `submitVerification` yeni başvuruyu `verification_requests/{uid}` içinde `status: "pending"`, `automaticCheckStatus: "pending"`, `automaticCheckAttemptCount: 0` ve benzersiz `submissionId` ile oluşturur.
- `analyzeVerificationOnWrite` Firestore tetikleyicisi `runVerificationAnalysis` ile Google Cloud Vision OCR, TCKN kontrol hanesi, HMAC-SHA256 kimlik tekilliği rezervasyonu (`verification_identity_keys`) ve selfie'de tek yüz tespitini çalıştırır.
- Google Cloud Vision `faceDetection` **aynı kişi yüz karşılaştırması, canlılık (liveness) doğrulaması veya belge gerçekliği testi değildir**.
- `decideVerification` tüm temel kontrolleri geçse bile başvuruyu `pending` bırakır; nihai onay/red/revizyon kararı `processVerification` ile admin tarafından verilir.
- **Kesin sınır:** Doğrulanmış harici KYC/biyometri sağlayıcısı, KVKK hukuki şartları ve açık özellik bayrağı olmadan hiçbir kullanıcı otomatik olarak `verified: true` veya oyuncu rozeti alamaz.

## 2. Hazırlanan Güvenli Altyapı Modülleri

1. **`functions/src/users/verificationAutomationPolicy.ts`** (Fail-closed karar yönlendirme politikası):
   - Yalnız sunucuda imzası, `uid`/`submissionId` bağı ve biyometrik işleme izni doğrulanmış kanıtları sınıflandırır.
   - Çıktılar: `eligible_for_auto_approval` (yalnız tüm zorunlu kontroller `passed` + `automaticApprovalEnabled === true`), `recapture_required` (canlılık veya fotoğraf kalitesi başarısız), `manual_review` (belirsiz, eksik, yüz uyuşmazlığı, belge sahteciliği şüphesi, mükerrer kimlik, NFC uyuşmazlığı veya bayrak kapalı).
   - Yüz uyuşmazlığı veya mükerrer kimlik asla sessizce kalıcı redde çevrilmez; insan incelemesine ve itiraz yoluna yönlendirilir.
   - İsteğe bağlı NFC (`nfcVerification`) bulunamadığında veya cihaz desteklemediğinde kullanıcı engellenmez; açıkça `failed` (çip imza/veri uyuşmazlığı) dönerse admin incelemesine düşer.
2. **`functions/src/users/kycProviderGateway.ts`** (İmzalı sağlayıcı webhook ve replay koruması):
   - `KycProviderMode`: `disabled` (varsayılan) | `shadow` (gözlem/test modu, otomatik onay daima kapalı) | `live`.
   - `verifyKycWebhookSignature`: `timingSafeEqual` ile HMAC-SHA256 imza doğrulama + `±5 dakika` zaman damgası penceresi.
   - `evaluateSignedProviderCallback`: Tekrarlanan `eventId` (replay) reddi, `uid`/`submissionId` bağ kontrolü, ham biyometrik şablon/TCKN saklamayan dar özet.
3. **`functions/src/users/verificationQueuePolicy.ts` + `analyzeVerification.ts` entegrasyonu:**
   - Yarıda kalan (`processing` durumunda 10 dakikadan uzun takılı kalan) veya geçici hata alan analizler için üstel bekleme (`1dk / 2dk / 4dk`) ve en fazla 3 deneme sınırı.
   - 3 deneme sonunda otomatik analiz tamamlanamazsa sonsuz döngüye girmeden `needs_review` (`analysis_retries_exhausted`) ile admin incelemesine aktarılır.
   - Admin detay ekranında manuel yeniden analiz tetikleme, bireysel kontrol kartları, yüz eşleştirmesi yapılmadığı uyarısı ve denetim geçmişi görünürlüğü sağlanmıştır.

## 3. Doğrulama Sağlayıcısı ve İsteğe Bağlı NFC Değerlendirmesi

### Aday Sağlayıcı Karşılaştırması (Türkiye Kimlik Kartı — TCKK + Canlılık + Yüz Eşleştirme)

| Sağlayıcı | TCKK Belge Gerçekliği | Canlılık / Anti-Spoof | Yüz Eşleştirme | İsteğe Bağlı NFC (ICAO 9303) | Flutter Android+iOS SDK | KVKK / Veri Yerleşimi Notu |
| --- | --- | --- | --- | --- | --- | --- |
| **Sumsub** | Güçlü (yeni TCKK + pasaport) | 3D Liveness + deepfake/ekran koruması | Var | Var (isteğe bağlı akış) | Resmi Flutter SDK | AB veri işleme + DPA / KVKK yurt dışı aktarım (Standart Sözleşme) gerekir |
| **Onfido (Entrust)** | Güçlü | Motion / iBeta Level 2 liveness | Var | Var (isteğe bağlı) | Resmi Flutter SDK | AB bölgesi + DPA / KVKK yurt dışı aktarım gerekir |
| **Veriff** | Güçlü | Liveness + belge hologram/ekran analizi | Var | Var | Resmi Flutter SDK | AB veri işleme + DPA / KVKK yurt dışı aktarım gerekir |
| **Techsign / ArkSigner (TR)** | TCKK + e-Devlet/MRZ uzmanlığı | Liveness + yüz eşleştirme | Var | Güçlü TCKK NFC | Mobil SDK (Flutter köprüsü gerekir) | Türkiye içi veri barındırma avantajı; sözleşme/SLA ve iOS CoreNFC teyidi gerekir |

### İsteğe Bağlı NFC Kimlik Okuma (ICAO 9303 BAC/PACE)

- **Teknik uygulanabilirlik:** Yeni nesil T.C. Kimlik Kartları (TCKK) ICAO 9303 çipi taşır. iOS 13+ (`CoreNFC` + `com.apple.developer.nfc.readersession.formats = TAG` entitlement + `Info.plist` NFC kullanım açıklaması) ve NFC donanımlı Android cihazlarda MRZ üzerinden BAC/PACE ile çip fotoğrafı ve Passive Authentication (PA) doğrulanabilir.
- **Neden zorunlu olmamalı:** Eski/giriş seviye Android cihazlarda NFC donanımı olmayabilir, kılıf/çip arızası okunmayı engelleyebilir veya kullanıcı pasaport/eski belge kullanabilir. Bu yüzden NFC yalnızca isteğe bağlı hızlandırıcı/güven artırıcı katman olarak planlanır (`verificationAutomationPolicy.ts` içinde `nfcVerification` yokluğu veya `unavailable` durumu kullanıcıyı engellemez).

## 4. KVKK, Biyometrik Veri ve Gizlilik Eksikleri (Yayın Öncesi Zorunlu Hukuki/Operasyonel Ön Koşullar)

Mevcut gizlilik, özel Storage yolu, `final_decision_30_days` saklama süresi ve `cleanupVerificationDocuments` otomatik silme akışı korunmuştur. Ancak gerçek yüz eşleştirme ve canlılık sağlayıcısı canlıya açılmadan önce aşağıdaki hukuki ve sözleşmesel eksikler ürün sahibi ve hukuk danışmanı tarafından tamamlanmalıdır:

1. **Özel Nitelikli Kişisel Veri (KVKK m. 6):** Yüz eşleştirme ve canlılık doğrulaması biyometrik veri işleme kapsamındadır. Mevcut `onboarding/login` yasal metinleri biyometrik doğrulama için ayrı, granüler **açık rıza** ve **biyometrik aydınlatma metni** içermez. Açık rıza vermeyen kullanıcılar için manuel/alternatif akış veya isteğe bağlı rozet sınırı netleştirilmelidir.
2. **Yurt Dışına Veri Aktarımı (KVKK m. 9):** Yurt dışı merkezli bir KYC sağlayıcısı (Sumsub/Onfido/Veriff vb.) seçilirse, 2024 KVKK m. 9 değişikliği uyarınca **Kurul tarafından ilan edilen Standart Sözleşme** imzalanmalı ve 5 iş günü içinde KVKK'ya bildirilmelidir (veya Türkiye içi veri yerleşimi sağlayan yerli veri işleyen seçilmelidir).
3. **Veri İşleyen Sözleşmesi (DPA) ve Saklama Süresi:** Sağlayıcı tarafında ham selfie/kimlik görsellerinin ve biyometrik vektörlerin doğrulama sonrası derhal (veya en kısa zorunlu pencerede) silinmesi sözleşmeye bağlanmalı; Dört. Firestore/log katmanında asla ham biyometrik şablon veya açık TCKN tutulmamalıdır.
4. **Sağlayıcı Hesabı ve Üretim Anahtarları:** Seçilen sağlayıcıyla ticari sözleşme, webhook imza gizli anahtarı (`Secret Manager`), shadow-mode (gözlem) pilot testi (sahte belge, ekran fotoğrafı, farklı kişi, mükerrer kimlik, iOS/Android gerçek cihaz testleri) tamamlanmadan `KYC_PROVIDER_MODE=live` ve `KYC_AUTO_APPROVAL_ENABLED=true` açılmamalıdır.
