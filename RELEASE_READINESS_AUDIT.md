# Dört. V1 release readiness audit

Tarih: 6 Ekim 2026  
Kapsam: iki release blocker kapatıldı. Deploy ve Play Console’a dokunulmadı.

1. Release blocker: **0**
2. Manual check: **12**
3. Deferred V2 (harf statüsü): **0**
4. Passed / DONE: **13**

Harf sayısı A–Y = 25. Z karardır, sayıya girmez. Ertelenen işler bölüm notlarında durur; ayrı harf açılmadı.

---

## A) AUTH / ACCOUNT — ✅ DONE

Telefon girişi, SMS kodu, hatalı/süresi geçmiş kod ve cooldown metinleri `lib/screens/login_screen.dart` ve `lib/screens/verify_screen.dart` içindedir. Yeni profil `CreateProfileScreen`, askıya alınmış / silme bekleyen hesap `lib/main.dart` üzerinden `AccountStatusScreen` ile ayrılır. Çıkış ve tek oturum `SessionService` ile kapanır.

Hesap silme gerçek akış:

1. Ayarlar → `_requestAccountDeletion` (`lib/screens/settings_screen.dart`)
2. Callable `requestAccountDeletion` (`functions/src/users/requestAccountDeletion.ts`, App Check zorunlu)
3. `users/{uid}` alanları: `accountStatus=deletionRequested`, `deletionRequestStatus=pending`; `accountDeletionRequests/{uid}` belgesi yazılır
4. İstemci oturumu kapatır
5. `processAccountDeletion` (`functions/src/users/processAccountDeletion.ts`) belge **oluşunca** çalışır; Auth kullanıcısını, profili ve storage belgelerini siler

Telefon değiştirme `lib/screens/change_phone_screen.dart` içindedir. Bu hesap ekranıdır; etkinlik iletişiminden ayrıdır.

`DeviceManagementScreen` dosyası var, hiçbir menü onu açmıyor. V1 blocker değil. Ekleme yapılmadı.

İşlem: silme fonksiyonunun production’da deploy edildiğini konsoldan doğrula (R / Y ile birlikte).

## B) LEGAL / CONSENT — ✅ DONE

TR/EN/DE yasal dosyalar `assets/legal/{tr,en,de}/` altında duruyor. Zorunlu belgeler `LegalVersions` içinden gelir: `kvkk_notice`, `privacy_policy`, `terms_of_use`, `community_rules`, `age_declaration`.

Login bu beş belgeyi işaretlemeden kod göndermez. Otomatik doğrulama ve SMS doğrulama, silinmiş telefon kontrolünden sonra `LegalService.recordOnboardingAcceptances` çağırır. Kayıt `users/{uid}/legal_acceptances/{code}_{version}` altına yazılır: `userId`, `documentCode`, `version`, `acceptedAt` (`FieldValue.serverTimestamp`), `locale`, `source=onboarding/login`, `active=true`. Aynı sürüm belgesi varsa ikinci yazılmaz. Yeni sürüm yeni belge açar ve eski aktif kaydı `active=false` yapar.

`firestore.rules` yalnızca belge sahibinin oluşturmasına izin verir. Başka kullanıcının kaydı yazılamaz. Silme kapalıdır. Güncelleme yalnızca `active` alanını true’dan false’a çevirir.

`public/account-deletion.html` var. Metinlerde `destek@dortapp.com` ve `dortapp.com` geçiyor.

## C) BRAND — ✅ DONE

`AndroidManifest.xml` etiket: `Dört.` Paket / namespace: `com.dortapp.dort`. Launcher `@mipmap/ic_launcher`. Kamuya açık sayfalar `Dört.` ve `dortapp.com` kullanıyor.

Kullanıcıya görünen sınıf adı `DorduncuApp` tekniktir. Firebase proje id `dorduncu-8e599` değiştirilmedi.

`PaymentPolicyScreen` hâlâ “Dördüncü bakiyesi” yazar. Bu ekrana giden bir navigasyon bulunamadı. Ulaşılamayan legacy metin, marka blocker’ı değil.

## D) FIREBASE SECURITY — ✅ DONE

`firestore.rules` / `storage.rules` sürüm 2.

Kanıtlanan yazma sınırları:

- `events` create/delete kapalı; istemci yalnızca sohbet okundu/yazıyor alanlarını güncelleyebilir
- `applications` ve `messages` create kapalı (Functions yazar)
- `events/{id}/private` okuma `canReadPrivateEventLocation` ile sahip, seçilmiş oyuncu veya moderatör
- `owned_badges`, `wallets`, `payments` istemci yazamaz
- `users/{uid}/legal_acceptances` yalnızca sahip tarafından, sabit alan listesi ve sunucu zamanı ile oluşturulur
- `masked_call_requests` tamamen kapalı
- Admin `request.auth.token.admin` veya `role`

Eşleşmeyen yol Firestore’da varsayılan reddedilir. Rules’un production’a deploy edildiği bu turda doğrulanamadı.

## E) APP CHECK — 🟡 MANUAL CHECK

`lib/main.dart`: debug `AndroidDebugProvider`, release `AndroidPlayIntegrityProvider`. `requestAccountDeletion` `enforceAppCheck: true`.

Konsolda Play Integrity kayıtlı mı ve hangi servislerde enforcement açık, koddan bilinemez. Kayıt yoksa release’de App Check’li callable’lar düşer.

İşlem: Firebase Console → App Check → Android uygulamasını Play Integrity ile kaydet. Debug token yalnızca geliştirme içindir.

## F) SUPPORT / REPORT / MODERATION — ✅ DONE

Destek talebi, etkinlik/mesaj şikâyeti ve engelleme ekranları ile `support_requests` kuralları duruyor. Admin listeleri: `admin_reports_screen.dart`, doğrulama listesi, kullanıcı askıya alma admin kullanıcı detayında. Kırık “coming soon” navigasyonu bu akışta bulunmadı.

Çalışma zamanı tıklaması bu turda yapılmadı.

## G) VERIFICATION — ✅ DONE

Yükleme `functions/src/users/submitVerification.ts`. Storage kuralı doğrulama belgesini resim veya PDF ile sınırlar. Admin karar ekranları `admin_verification_list_screen.dart` ve `admin_verification_detail_screen.dart`. Belge erişim log koleksiyonları rules’ta yazmaya kapalı (sunucu yazar).

## H) ADMIN PANEL — 🟡 MANUAL CHECK

Kodda duran modüller: roller, kullanıcı, askıya alma, destek/rapor, doğrulama, etkinlik, cüzdan, rozet/Plus istatistik, audit.

Cüzdan ve etkinlik ödeme ekranları eski modeldir. V1 kullanıcısına bağlı değiller. Admin’in production’da custom claim ile açıldığı konsoldan doğrulanmalı. Her modülün canlı veriyle tıklanması yapılmadı.

## I) EVENT LIFECYCLE — ✅ DONE

Yeni etkinlik ücretsiz: `createEvent.ts` ve `create_event_screen.dart` `accessModel: free`, `paymentRequired: false`. Ücretsiz kabul `acceptApplication.ts` içinde oyuncuyu `selectedPlayerIds` ve `chatMemberUids` içine alır; payment pending yazmaz.

My Events artık `payment_pending` için **Ödemeye Geç** göstermez ve `PaymentScreen` açmaz. Aynı durum etiketi “Etkinlik durumu güncelleniyor” olur. Etkinlik detayı, başvuru durumu ve etkinlik ödeme bildirimleri de ödeme / iade çağrısı yerine bu güvenli metni kullanır. Ücretsiz kadro metni (“Kadroya alındın — adres ve sohbet açıldı”) durur.

`PaymentScreen`, cüzdan ve tahsilat fonksiyonları silinmedi. Plus ve rozet Google Play ekranlarına dokunulmadı.

## J) HOME / GAME VISUALS / MAP — ✅ DONE

`MockEvent` / `mock_events` araması boş. Ana ekran ve Haritada Keşfet `EventService.watchListedEvents` kullanır.

`GameCatalog` 30 oyun. `assets/images/games/` 30 jpg, dosya adı internal id (`okey.jpg`, `okey_101.jpg` ayrı). `pubspec.yaml` `assets/images/games/` içeriyor. `GameCoverAssets.pathFor` tam id ile gider. Kart başlığı katalog adı. Marker yalnız fotoğraf; ad alt sayfada.

Eksik asset `errorBuilder` ile ikona düşer, çökmez.

## K) CHAT — ✅ DONE

`firestore.rules` `isChatMember`: ücretsiz etkinlikte sahip veya kabul edilmiş ve adresi açılmış oyuncu. Ücretli etkinlikte ödeme durumu da aranır. Mesaj create istemcide kapalı.

Etkinlik detayında tek iletişim aksiyonu **Sohbet**. Buton `ChatService.messageReadAllowed` ile aynı kuralı kullanır. Açılış `canCurrentUserAccessChat` ile doğrulanır. Kabul edilmeyen kullanıcıda buton kapalıdır. Telefon / maskeli arama bu ekrandan kaldırılmıştır. `requestMaskedEventCall` serviste durur, UI çağırmaz.

## L) NOTIFICATIONS — 🟡 MANUAL CHECK

FCM `firebase_messaging` ve `NotificationPushService` bağlı. Uygulama manifestinde `POST_NOTIFICATIONS` yok; eklenti birleştirmesi ayrıca doğrulanmalı.

`event_payment_required` hâlâ ücretli kadro kodunda üretiliyor (I ile aynı). Maskeli arama bildirimi kullanıcı listesinde aranmadı; arama UI’si kapalı.

İşlem: release birleşik manifestte bildirim iznini gör. Ödeme bildirimini V1 ücretsiz akışta tetiklenmediğini bir kabul testiyle doğrula.

## M) RATINGS — ✅ DONE

`submitEventRating` / `getEventRatingState` callable. Yorum, tamamlanmış etkinlikte kadro içindir. Aynı hedef `already-exists` ile ikinci kez yazılamaz. Puan koleksiyonu rules’ta istemciye açılmamış; yazma sunucudadır. Etkinlik detayı puan bölümünü tamamlanmış etkinlikte gösterir.

## N) PLUS — 🟡 MANUAL CHECK

İstemci `MarketScreen` → `DigitalPurchaseService` → `fulfillGooglePlayPurchase`. RTDN `functions/src/commercial/googlePlayRtdn.ts`. Ürün kimliği Firestore `plus_products.googlePlayProductId`. Repoda sabit bir Play subscription id yok. `plusProducts.isEmpty` ise satın alma kapalı.

Kod “Play Console ürünü var ve Firestore dolu” demiyor.

İşlem: Play Console’da abonelik, base plan ve offer oluştur. Firestore `plus_products` belgesine aynı id’yi yaz. Lisans testi ile satın al, acknowledge, restore ve süre bitimini dene.

## O) BADGES / MARKET — 🟡 MANUAL CHECK

`seedBadgeProducts.ts` 30 rozet yazar. Yazılan alanlarda `googlePlayProductId` yok; `priceKurus: 29900` duruyor. Market, Play id boşsa satın almayı kapatır. `owned_badges` istemci yazamaz. Fulfill yolu idempotent satın alma kaydı tutar.

İşlem: 30 one-time non-consumable Play ürünü aç. Her rozet belgesine `googlePlayProductId` yaz. Seed’i bu alanları silmeden çalıştır (`merge: true` alanı silmez, eklemez de).

## P) LOCALIZATION — 🟡 MANUAL CHECK

V1 dilleri `tr`, `en`, `de`. Birçok ekran `_eventText` / `v(tr,en,de)` kullanır. Bazı etkinlik detay düğmeleri yalnız Türkçe: “Reddet”, “Kabul et”. ARB her kullanıcı cümlesini kapsamaz. Yasal asset testi geçti.

İşlem: kapalı testte EN ve DE ile etkinlik detayı, sohbet ve ayarları gez. Yalnız Türkçe kalan düğmeleri aynı üç dile çek. Başka diller V1 dışı.

## Q) REFRESH / LOADING / EMPTY / ERROR — 🟡 MANUAL CHECK

Ana ekran boş durumda “Şu anda aktif etkinlik yok” ve oluşturma düğmesi var. Harita boşken sahte marker yok. Sohbet ve destek hata metinleri kodda var. Yükleme / boş / hata halleri cihazda gezilmedi.

## R) ANALYTICS / CRASH / OPS — 🟡 MANUAL CHECK

`pubspec.yaml` içinde Crashlytics veya Firebase Analytics yok. Bütçe alarmı, yedek ve App Check enforcement konsol işidir; koddan doğrulanamaz.

İşlem: kapalı test öncesi Crashlytics bağlamak zorunlu değil, production için önerilir. Firebase bütçe alarmını konsoldan aç.

## S) GOOGLE PLAY / ANDROID RELEASE — 🟡 MANUAL CHECK

Paket `com.dortapp.dort`. Sürüm `1.0.0+1` (`pubspec.yaml`). Release imza `android/app/build.gradle.kts` içinde `key.properties` okur. Dosya yerelde var. `android/key.properties` ve `android/app/upload-keystore.jks` gitignore’da. Secret yazılmadı.

`minSdk` / `targetSdk` Gradle’da Flutter SDK’dan gelir, repoda sabit sayı yok. `minify` kapalı. `usesCleartextTraffic` yok. `MainActivity` exported; launcher için gerekli. Konum izinleri manifestte var. `BILLING` ve `POST_NOTIFICATIONS` uygulama manifestinde yok; Play Billing ve FCM eklentilerinin birleşik manifesti doğrulanmalı.

`flutter build appbundle --release` bitti (exit 0, yaklaşık 44 dakika). Çıktı: `build/app/outputs/bundle/release/app-release.aab` (82.9 MB). Gradle, bazı eklentilerin ileride Built-in Kotlin istediğini uyardı; bu derlemeyi düşürmedi.

İşlem: AAB’yi Play Console kapalı testine yükle. Data safety ve içerik derecesi konsol işidir. Birleşik manifestte BILLING ve POST_NOTIFICATIONS hâlâ doğrulanmalı.

## T) PUBLIC WEBSITE / DOMAIN — 🟡 MANUAL CHECK

`public/index.html` ve `public/account-deletion.html` marka, `dortapp.com`, `destek@dortapp.com`, `iletisim@dortapp.com` kullanıyor.

DNS, SSL ve Firebase Hosting’in bu dosyaları yayınladığı koddan doğrulanamaz.

## U) DEAD / TEST / DEBUG — ✅ DONE

Üretim akışında mock/fake etkinlik yok. `example.com`, `lorem ipsum`, sabit şifre bulunmadı. `marketComingSoon` metni duruyor, Market butonu `MarketScreen` açıyor; metin gösterilmiyor.

Gradle yorumundaki `TODO: Specify your own unique Application ID` eski şablon. `applicationId` zaten `com.dortapp.dort`.

## V) SECURITY SECRETS — ✅ DONE

İmza dosyaları gitignore’da, içerik okunmadı ve rapora yazılmadı. Repoda servis hesabı private key araması eşleşmedi. `google-services.json` ve `firebase_options.dart` içindeki anahtarlar istemci Firebase yapılandırmasıdır; bu rapora kopyalanmadı.

## W) PERFORMANCE — 🟡 MANUAL CHECK

Bu turda profiler çalışmadı. Sahte etkinlik dinleyicisi kalkmış. Satın alma akışı tek `DigitalPurchaseService.instance`. Bariz sonsuz listener veya marker sızıntısı okunan harita kodunda görülmedi. Cihaz ölçümü yok.

## X) ACCESSIBILITY — 🟡 MANUAL CHECK

Harita marker’ında kesilen oyun adı kaldırıldı; ad önizlemede. Büyük yazı tipi, klavye taşması ve kontrast cihazda ölçülmedi. Release blocker seviyesinde kanıtlanmış bir taşma bu turda yok.

## Y) TESTS — ✅ DONE

- `flutter pub get`: bağımlılıklar çözüldü
- `flutter analyze`: No issues found (exit 0)
- `flutter test`: 2 test geçti (`widget_test.dart`, `legal_assets_test.dart`)
- `functions`: `npm run build` (`tsc`) exit 0. `npm install` tekrarlanmadı
- ESLint çalıştırılmadı. Satır sonu kaynaklı eski lint bu turda yeni hata diye yazılmadı

AAB sonucu Y’ye değil S’ye aittir.

## Z) FINAL RELEASE VERDICT

Kapalı testin mutlu yolu (ücretsiz oluştur, başvur, kabul, sohbet, harita) kodda duruyor. İki release blocker kapatıldı. Kalan işler konsol ve cihaz kontrolüdür.

### Blocker

Yok.

### Manual check

- App Check Play Integrity kaydı ve enforcement
- Play Console Plus aboneliği ve 30 rozet ürünü, Firestore `googlePlayProductId`
- AAB üretildi (`app-release.aab`, 82.9 MB). Play Console yüklemesi, Data safety ve içerik derecesi hâlâ konsol işi
- Birleşik manifest: BILLING, POST_NOTIFICATIONS
- DNS/SSL, Firebase bütçe alarmı, rules/functions deploy teyidi
- EN/DE ve boş/hata ekranlarının cihazda gezilmesi
- Crashlytics yok; production için ayrıca karar

### Deferred (harf değil)

- iOS
- Cihaz listesi ekranını menüye bağlamak
- Cüzdan, etkinlik tahsilatı ve maskeli arama backend’ini silmek
- Türkçe/İngilizce/Almanca dışı diller

GO / NO-GO

GO FOR CLOSED TEST
