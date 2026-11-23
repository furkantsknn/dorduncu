# Dört. App Store ve Güncelleme Hazırlığı

Tarih: 25 Ekim 2026

## Android tek yayın adayı — uygulanan son durum

Bu bölüm 25 Ekim 2026 tarihindeki Android yayın çalışmasının kesin sonucudur ve aşağıdaki eski hazırlık ifadelerinden daha günceldir.

### Canlı backend

- Yayınlanan tek Function: `adminManageVersionPolicy`.
- Durum: `ACTIVE`; revision `adminmanageversionpolicy-00001-rol`; entry point `adminManageVersionPolicy`.
- Yayınlanan Firestore ruleset: `7d7e684c-a926-47ab-aa02-a3af8e5b5abb`.
- Rules, canlı ruleset `d1abd6d7-701a-465f-b28a-68c56b813e7d` üzerine yalnız `app_version_policies`, `app_version_policy_history` ve `public_app_versions` blokları eklenerek üretildi. Çalışma ağacındaki ilgisiz rules değişiklikleri yayınlanmadı.
- Yayın öncesi canlı rules ve sekiz belge sonucu `backups/version-policy-20261025-143906/` altında saklandı.
- Eksik sekiz özel/açık belge tek atomik commit ve `exists=false` önkoşuluyla oluşturuldu; mevcut belge körlemesine ezilmedi.
- Canlı geri okumada `android_test`, `android_production`, `ios_test`, `ios_production` için hem özel hem açık belgelerde `active=false`, `latestBuild=0`, `minimumBuild=0` doğrulandı. Hiçbir minimum sürüm yükseltilmedi.
- Hosting, Storage, başka Function ve push yayını yapılmadı.

### Android güvenlik kararı

- Aynı paket/AAB Play internal, closed, open ve production kanalları arasında terfi edebildiğinden Android çalışma zamanının kanalı bildiği varsayımı kaldırıldı. Android istemcisi daima `android_production` politikasını okur; bir `DISTRIBUTION_TARGET=test` define'ı Android'i test politikasına geçirmez.
- Zorunlu karar için canlı/geçerli politika, doğrulanmış mağaza işareti, URL, Play'in bu hesap/cihaz için `UPDATE_AVAILABLE` cevabı ve Play `availableVersionCode >= minimumBuild` koşullarının tamamı gerekir.
- Zorunlu ekrandan mağaza dönüşünde Play uygunluğu throttle kullanılmadan tekrar sorgulanır. Güncelleme artık erişilemiyorsa kullanıcı eski zorunlu kararla kilitli kalmaz.
- Offline/cache/bozuk belge zorunlu kilit üretemez. SMS kod girişi, açık ödeme/doğrulama, odaklanmış form ve üst route sırasında yeni güncelleme overlay'i açılmaz.

### Tek Android AAB

- Dosya: `build/app/outputs/bundle/release/app-release-v1.0.0+32.aab`
- Bundle manifest: versionName `1.0.0`, versionCode `32`, package `com.dortapp.dort`.
- Firebase: `dorduncu-8e599`, app ID `1:256435983692:android:91eb5d3dbe06a349c9abe9`.
- SHA-256: `D090096AB0C6C35611935256D53C284A9BDF262D21F7E1FE188C3989794FF118`.
- İmza: standart `jarsigner -verify` exit 0; upload sertifikası SHA-256 `D5:12:EF:59:06:6C:79:C0:6A:FF:0A:7C:6E:66:F0:00:B5:A2:2E:E2:3E:87:6D:A2:CC:FA:59:29:48:BB:5E:7A` ve +31 ile aynı.
- +31 korundu; SHA-256 `C7B62367C60755CB4A97FEDADC56876594182B59A6BEEA0CFE755A1C6663A696`.
- Play track/versionCode sorgusu yerel kullanıcı kimliğiyle 403 döndü. Runtime servis hesabının Android Publisher satın alma erişimi doğrulandı, fakat servis hesabını taklit etme yetkisi yoktu. Bu nedenle Play'deki en yüksek versionCode doğrulanamadı; yerel en yüksek +31 olduğundan +32 üretildi. Play'e yükleme veya rollout yapılmadı.

### Bu yayın turunda geçen kontroller

- `flutter analyze` — 0 issue.
- Hedefli Flutter update/SMS/session/billing testleri — 57/57.
- Functions TypeScript build ve iki yeni dosyada hedefli ESLint — geçti.
- Functions version policy testleri — 4/4.
- Firestore rules emulator yetki testleri — 2/2.
- Release `flutter build appbundle --release --build-name=1.0.0 --build-number=32` — geçti.
- Bundletool manifest doğrulaması — `32`, `1.0.0`, `com.dortapp.dort`.
- AAB standart imza doğrulaması — geçti; self-signed upload sertifikası nedeniyle `-strict` PKIX/timestamp uyarısı verir, fakat imzalayan +31 ile aynıdır.
- Gerçek cihaz testi yapılmadı; update UI, Play uygunluğu, SMS, ödeme ve bildirim cihazda geçmiş sayılmıyor.

### İki telefonla kısa doğrulama

1. Telefon A'da Play'den gerçek +31 kurulumunu koru; Telefon B'de temiz hesap/kurulum kullan. İki cihazda da politika `active=false` iken update overlay çıkmadığını doğrula.
2. +32'yi tek bir Play test kanalına yükledikten sonra Telefon A'yı mevcut normal Play yöntemiyle +31'den +32'ye geçir. +31 yeni arayüzü içermediği için bu ilk geçiş uygulama içi update UI testi değildir.
3. İki telefonda SMS tekrar gönderme/hesap değişimi, A01 kabul, profil formu resume, açık ödeme dönüşü ve +31 bildirim düzeltmesinin foreground/background/kilit ekranı regresyonunu kontrol et.
4. +32 yüklü iki telefonda ağ kapalı, bozuk/eksik config ve mağaza hesabı erişimsiz durumlarda kilit oluşmadığını doğrula.
5. Uçtan uca yeni update UI testi için daha sonra tek bir daha yüksek Play build gerekir. O build gerçekten ilgili hesaba sunulduktan sonra önce optional politika, ardından yalnız kontrollü cihazlarda minimum politika denenmeli; erişimi olmayan ikinci telefon kilitlenmemelidir. Bu tur sırf test için ikinci AAB üretilmedi.

## Yönetici özeti

- **Kodlandı:** Android/iOS ve test/production ayrımlı build-number politikası, güvenli istemci değerlendirmesi, sürüm bazlı erteleme, Android Play In-App Updates uygunluk kontrolü, mağaza fallback'i, TR/EN/DE güncelleme arayüzü, yetkili/audit kayıtlı yönetim ve rollback.
- **Test edildi:** Flutter analyze, hedefli Flutter politika/giriş/billing testleri, Functions TypeScript build + hedefli lint + politika testleri, Firestore emulator yetki testleri ve Android Kotlin debug compile geçti.
- **Yayın durumu:** Android tek yayın adayı çalışmasında yalnız yukarıda belirtilen Function, dar Firestore rules farkı ve pasif politika belgeleri canlıya alındı. Minimum sürüm, push ve mağaza paketi yayınlanmadı.
- **Hesap bilgisi bekliyor:** Apple Team/Bundle ID/Firebase iOS uygulaması/APNs/App Store Connect kaydı/Apple ürünleri ve sunucu anahtarları yok.
- **Cihazda doğrulanmadı:** Android Play update akışı, iOS başlangıç/Phone Auth/push/TestFlight, gerçek Apple satın alma/restore ve gerçek cihaz izinleri doğrulanmadı.

## A — Güncelleme yönetimi

### Tek yetkili politika

Mevcut `system_settings/global` sürüm alanları yeniden yazılmadı ve diğer global ayarlar için uyumluluk amacıyla korundu. İstemcinin yetkili sürüm kaynağı yeni normalize edilmiş dört belgedir:

- `android_test`
- `android_production`
- `ios_test`
- `ios_production`

Özel yönetim kaydı `app_version_policies`, giriş yapmamış istemcinin okuyabildiği dar projeksiyon `public_app_versions`, geri alma geçmişi `app_version_policy_history` koleksiyonundadır. Eski global sürüm alanları istemci tarafından okunmaz; iki karar motoru yoktur.

Her politika `latestBuild` ve `minimumBuild` tamsayılarını kullanır. `1.0.0` gibi görünen metinler yalnız gösterim içindir. Dağıtım hedefi derlemede `--dart-define=DISTRIBUTION_TARGET=test|production` ile seçilir; varsayılan production'dır.

### Davranış

- `installedBuild >= latestBuild`: arayüz yok.
- `minimumBuild <= installedBuild < latestBuild`: **Güncelle / Daha sonra**; erteleme revision + latest build anahtarına bağlıdır.
- `installedBuild < minimumBuild`: yalnız canlı/geçerli politika, doğrulanmış mağaza sürümü, geçerli mağaza URL'si ve cihaz için erişilebilir mağaza akışı varsa zorunlu ekran.
- Android'de Google Play `AppUpdateInfo` cihaz/hesap/kanal için update döndürmezse zorunlu kilit oluşmaz; bağlantı yalnız fallback olarak açılır.
- iOS'ta Android MethodChannel çağrılmaz. Production yalnız `apps.apple.com`, test yalnız `testflight.apple.com` URL'sini kabul eder. Bilinmeyen App Store ID üretilmedi.
- Açılışta ve resume'da kontrol edilir; 15 dakikalık throttle aynı kararı korur. Her route değişiminde sorgu yoktur.
- SMS kod girişi, açık ödeme/doğrulama, odaklanmış metin alanı veya üstte açılmış route sırasında yeni overlay gösterilmez. Böylece ödeme, SMS ve tipik kaydedilmemiş formlar resume kontrolüyle kesilmez.
- Firestore/ağ/parse hatasında son geçerli yerel politika okunabilir, fakat cache zorunlu kilit üretemez. Bozuk belge fail-open davranır.
- Admin `settings.manage` yetkisi, App Check, sunucu doğrulaması ve audit zorunludur. İstemciden hiçbir politika yazımı yoktur.
- Rollback seçilen revizyonun önceki değerini transaction içinde özel ve açık projeksiyona birlikte geri yükler; işlem audit'e yazılır.
- Yeni mağaza sürümü doğrulanmadan etkin minimum politika kaydedilemez. Her yeni sürümün minimum yapılması gerekmiyor; `minimumBuild` geride bırakılabilir.

### Güncelleme push tasarımı

Toplu push gönderilmedi. İstenirse mevcut bildirim kuyruğuna tekil `app_update_available` bildirimi yazılır; payload yalnız duyuru ve uygulamayı açma bağlamı taşır. Uygulama açıldığında karar yine `public_app_versions` üzerinden verilir. Push teslimi, güncelleme kontrolünün veya zorunlu politikanın şartı değildir. Hedef kitle platform + dağıtım + eski build ile sunucuda sınırlandırılmadan gönderim yapılmamalıdır.

## B — iOS / TestFlight teknik envanteri

### Kodlandı

- Android'e özel Play Billing başlangıcı iOS'ta çalıştırılmıyor.
- Market iOS'ta Apple ürünleri ve güvenli doğrulama hazır olana kadar satışa hazır görünmüyor; Google Play ödeme veya abonelik sayfasına yönlendirmiyor. Mevcut hesap hakları değiştirilmedi.
- Firebase başlangıcı iOS'ta gerçek `GoogleService-Info.plist` native yapılandırmasını kullanacak şekilde ayrıldı; eksik yapılandırma gizlenmiyor.
- App Check iOS release için App Attest + DeviceCheck fallback, debug için debug provider ile hazırlandı.
- Kamera, fotoğraf okuma/yazma ve kullanımda konum açıklamaları Info.plist'e eklendi.
- Privacy manifest eklendi: tracking false, telefon/UID/yaklaşık konum/foto-video/satın alma/kullanıcı içeriği ve UserDefaults gerekli-reason kullanımı beyan edildi. Crashlytics kodu bulunmadığı için crash data beyan edilmedi.

### Hesap veya Mac bekleyen bloklar

- Bundle ID hâlâ placeholder: `com.example.dorduncu`.
- `DEVELOPMENT_TEAM` yok; otomatik signing seçili olsa da Team/provisioning yok.
- Firebase iOS app ve `ios/Runner/GoogleService-Info.plist` yok.
- Push Notifications capability, `aps-environment` entitlement ve APNs anahtar bağlantısı yok.
- Firebase Phone Auth için APNs silent notification ve reCAPTCHA fallback URL scheme'i gerçek plist değerleri olmadan tamamlanamaz.
- App Store Connect app kaydı, numeric App Store ID/URL ve TestFlight bağlantısı bilinmiyor.
- Windows ortamında Xcode/CocoaPods/archive/export/TestFlight upload yapılamadı.

Deployment target iOS 13.0'dır. Bu değer mevcut FlutterFire/Flutter bağımlılıklarının Mac tarafındaki `pod install` sonucuyla tekrar doğrulanmalıdır.

### Apple satın alma hazırlığı ve eksikler

Ortak hesap hakları Firestore/sunucu tarafında korunuyor; ancak mevcut ödeme doğrulama sistemi Google Play ürün ID'si, purchase token ve RTDN üzerine kurulu. Aşağıdakiler kodda yok ve tamamlanmadan iOS satışa açılamaz:

- Plus abonelik grubu ve ürün ID'leri.
- 31 rozeti için non-consumable ürünleri.
- Hediye ürün/akışlarının Apple ürün modeli ve teklif uygunluğu.
- Apple indirim/intro/promotional offer kimlikleri ve imza akışı.
- StoreKit 2 signed transaction/JWS sunucu doğrulaması.
- App Store Server Notifications V2 endpoint'i; renewal, expiry, revoke, refund ve grace/billing-retry işleme.
- `originalTransactionId`/transaction ID ile idempotent teslimat ve UID bağlama.
- Restore purchases'ın Apple doğrulaması sonrası ortak hak projeksiyonuna yazılması.
- Apple abonelik yönetim URL'si ve iade/iptal durumlarının ortak hak politikasına yansıması.

Bu nedenle iOS Market bilinçli olarak bilgi ekranı gösterir. Google Play hakları, +31 rozeti, Plus indirimi, A01 veya UID'ler dönüştürülmedi/silinmedi.

### Kimlik, güvenlik ve inceleme yüzeyleri

- Giriş yalnız Firebase Phone Auth/SMS. Üçüncü taraf veya sosyal login görülmedi. Bu nedenle App Review Guideline 4.8 nedeniyle otomatik olarak Sign in with Apple ekleme sonucu çıkmaz; yeni üçüncü taraf login eklenirse yeniden değerlendirilir.
- Cross-app tracking, reklam ağı veya reklam attribution SDK'sı görülmedi. ATT istemi şu an gerekçeli değil; bu davranış eklenirse privacy beyanı ve ATT birlikte yeniden değerlendirilir.
- Uygulama içi hesap silme talebi ve dış web yönergesi mevcut.
- Kullanıcı engelleme, kullanıcı/fotoğraf/mesaj/etkinlik raporlama, destek kuyruğu ve admin moderasyon yolları mevcut.
- 25 Ekim 2026 canlı HTTP kontrolü: `https://dortapp.com/privacy`, `https://dortapp.com/account-deletion.html`, `https://dortapp.com/child-safety.html` yanıtı 200.
- İnceleme hesabı/telefonu ve SMS kodu Apple'a sağlanmadı; inceleme notunda erişilebilir test yöntemi gereklidir.

### App Privacy taslağı

App Store Connect'te gerçek üretim davranışıyla son kez teyit edilmek üzere:

| Veri | Hesaba bağlı | Tracking | Amaç |
|---|---:|---:|---|
| Telefon numarası | Evet | Hayır | Giriş, güvenlik, dolandırıcılık önleme |
| User ID | Evet | Hayır | Hesap ve uygulama işlevi |
| Yaklaşık/uygulama içi konum | Evet | Hayır | Yakındaki etkinlikler ve harita |
| Fotoğraf/video | Evet | Hayır | Profil ve doğrulama |
| Kullanıcı içeriği | Evet | Hayır | Profil, sohbet, etkinlik, destek/moderasyon |
| Satın alma | Evet | Hayır | Hak teslimi, restore, destek |
| Kullanım/analytics | Üretim Firebase Analytics ayarına göre teyit | Hayır | Analytics |
| Doğrulama belgeleri | Evet | Hayır | Kimlik/doğrulama ve güvenlik |

Firebase SDK privacy manifestlerinin archive içindeki birleştirilmiş raporu Xcode Organizer'da ayrıca incelenmelidir.

## App Store metin taslağı

### Türkçe

- Ad: **Dört.**
- Alt başlık: **Oyuncunu bul, etkinliğe katıl**
- Promosyon: **Yakınındaki oyun ve spor etkinliklerini keşfet; ekip kur, sohbet et ve topluluğa katıl.**
- Anahtar kelimeler: `oyuncu,etkinlik,takım,spor,oyun,topluluk,harita,sohbet`
- Açıklama özeti: **Dört., ortak ilgi alanlarına göre oyuncu ve etkinlik bulmayı kolaylaştırır. Haritada etkinlikleri keşfet, başvur, kabul sonrası etkinlik sohbetine katıl, profilini ve rozetlerini yönet. Güvenlik için raporlama, engelleme, doğrulama ve hesap silme araçları sunulur.**

### English

- Name: **Dört.**
- Subtitle: **Find players and join events**
- Promotional text: **Discover nearby gaming and sports events, build a team, chat and join the community.**
- Keywords: `players,events,team,sports,gaming,community,map,chat`
- Description summary: **Dört. helps people find players and events around shared interests. Discover events on the map, apply, join event chat after acceptance, and manage your profile and badges. Reporting, blocking, verification and account-deletion tools support community safety.**

### Deutsch

- Name: **Dört.**
- Untertitel: **Spieler finden, Events beitreten**
- Werbetext: **Entdecke Gaming- und Sportevents in deiner Nähe, bilde ein Team und tritt der Community bei.**
- Keywords: `spieler,events,team,sport,gaming,community,karte,chat`
- Kurzbeschreibung: **Dört. verbindet Menschen über gemeinsame Interessen. Entdecke Events auf der Karte, bewirb dich, nutze nach Annahme den Event-Chat und verwalte Profil und Abzeichen. Melden, Blockieren, Verifizierung und Kontolöschung unterstützen die Sicherheit.**

Metinlerde Plus veya ürün fiyatı, Apple ürünleri onaylanmadan vaat edilmemelidir.

## Ekran görüntüsü listesi

Gerçek üretim benzeri içerik ve izinli hesaplarla, App Store Connect'in o gün istediği iPhone/iPad boyutlarına göre:

1. Ana sayfa ve etkinlik keşfi.
2. Harita ve yakın etkinlikler (özel/tam adres göstermeden).
3. Etkinlik detayı ve başvuru.
4. Kabul sonrası etkinlik sohbeti.
5. Profil ve 31 rozeti.
6. Market/Plus yalnız Apple ürünleri hazırsa; değilse mağaza görsellerine alınmaz.
7. Güvenlik: raporlama/engelleme veya hesap ayarları.

Telefon, UID, tam konum, gerçek mesaj, doğrulama belgesi ve ödeme verisi ekran görüntülerinde kullanılmamalıdır.

## App Review notu taslağı

Uygulama SMS ile telefon doğrulaması kullanır. İnceleme için çalışan ülke kodlu telefon ve deterministik kod/yöntem ayrı güvenli App Review alanında verilecektir. Kullanıcı etkinliklere başvurur; etkinlik sohbeti yalnız yetkili/kabul edilmiş katılımcılara açıktır. Raporlama ve engelleme profil/sohbet yüzeylerindedir. Hesap silme Ayarlar içindedir. Konum yalnız yakındaki etkinlikleri göstermek için kullanım sırasında istenir. Apple ürünleri hazır değilse iOS Market satın alma sunmaz. İnceleme sırasında ihtiyaç duyulan backend ortamı ve test verisi aktif tutulmalıdır.

## Mac/Xcode üzerinde tek doğrulama listesi

1. Final Bundle ID ve Team'i ayarla; Firebase iOS app'i aynı Bundle ID ile kaydet ve `GoogleService-Info.plist` dosyasını Runner target'a ekle.
2. Push Notifications ve gerekli Background Modes/entitlements'ı aç; APNs key'i Firebase'e bağla. Phone Auth reCAPTCHA URL scheme'ini gerçek `REVERSED_CLIENT_ID` ile ekle.
3. `flutter clean && flutter pub get`; `cd ios && pod install --repo-update`.
4. `flutter analyze` ve hedefli testleri Mac'te tekrar çalıştır.
5. `flutter build ios --release --dart-define=DISTRIBUTION_TARGET=test --no-codesign` ile compile kontrolü.
6. Xcode'da Runner archive al; signing, privacy report ve tüm SDK manifestlerini incele.
7. Gerçek iPhone'da ilk kurulum/güncelleme, SMS giriş (APNs ve reCAPTCHA fallback), App Check, kamera/fotoğraf/konum açıklamaları, push izin/alım/dokunma ve foreground/background/kilit ekranını test et.
8. TestFlight internal build'de test politikasının TestFlight'a, production build'in App Store'a yöneldiğini doğrula.
9. Apple ürünleri tamamlandıktan sonra sandbox: Plus, 31 rozeti, indirim, hediye, restore, hesap değişimi, duplicate transaction, Server Notification renewal/refund/revoke testleri.

## Gerçekten geçen kontroller

- `flutter analyze` — geçti, 0 issue.
- `flutter test test/app_update_policy_test.dart test/phone_verification_session_test.dart test/session_service_binding_test.dart test/digital_restore_test.dart test/purchase_flow_reconcile_test.dart test/play_one_time_offer_test.dart` — 56/56 geçti.
- `npm run build` (Functions TypeScript) — geçti.
- Hedefli ESLint: `versionPolicy.ts`, `adminManageVersionPolicy.ts` — geçti.
- `node --test test/versionPolicy.test.cjs` — 4/4 geçti.
- Firestore emulator `update_policy_rules.test.mjs` — 2/2 geçti; public signed-out read, private admin-only read ve tüm client write yasakları doğrulandı.
- `gradlew app:compileDebugKotlin` — exit 0; Play In-App Update native köprüsü compile edildi.
- Üç canlı yasal URL HEAD kontrolü — 200.
- iOS build/archive — **çalıştırılmadı; Windows'ta Xcode yok**.
- Gerçek cihaz update/push/ses-titreşim/StoreKit — **doğrulanmadı**.

## Bağlı yüzey sınıflandırması

| Yüzey | Durum | Gerekçe |
|---|---|---|
| Açılış/resume | Güncellendi, kodlandı/test edildi | Throttle, son karar, güvenli kesinti kontrolü |
| Android Play update | Güncellendi, kodlandı/compile edildi | Cihaz uygunluğu + immediate/flexible + URL fallback |
| iOS update yönlendirme | Güncellendi, kodlandı/statik test edildi | TestFlight/App Store hedef ayrımı; gerçek URL bekliyor |
| Admin ayarları | Güncellendi, kodlandı/test edildi | Mevcut settings yetkisi, App Check, validation, audit, rollback |
| Firestore açık/özel projeksiyon | Güncellendi, emulator test edildi | Signed-out dar read, client write yok |
| SMS Defense/Phone Auth | Davranış etkilenmedi; regresyon geçti | Update overlay kod girişi sırasında açılmaz |
| Bildirim teslimi | Değişmedi | Yalnız duyuru tasarımı belgelendi; push gönderilmedi |
| A01 ve hesap erişim kontrolleri | Değişmedi | Güncelleme kararı bu yetkileri atlamıyor |
| UID ve mevcut haklar | Değişmedi | Veri migrasyonu/silme yok |
| Android Google Play billing | Davranış korunuyor; regresyon geçti | Android yolu korunup iOS guard eklendi |
| iOS Market | Güncellendi fakat satış eksik | Google Play'e yönlendirme kapalı; Apple backend/ürünleri bekliyor |
| Hesap silme | Etkilenmedi, envanterlendi | Uygulama ve web yolu mevcut |
| Şikâyet/engelleme/moderasyon | Etkilenmedi, envanterlendi | Mevcut server/admin yolları kullanılıyor |
| Privacy/izinler | Güncellendi, statik doğrulandı | Info.plist + privacy manifest; archive raporu bekliyor |
| iOS signing/APNs/Firebase | Hâlâ eksik | Hesap ve gerçek config olmadan uydurulmadı |

## Kullanıcıdan gereken tek bilgi/erişim listesi

1. Apple Developer Team ID ve ilgili App Store Connect rolü/erişimi.
2. Onaylı final iOS Bundle ID.
3. Aynı Bundle ID için Firebase iOS app kaydı ve indirilen `GoogleService-Info.plist` (gizli anahtarları kaynak koduna yazmadan güvenli teslim).
4. APNs Authentication Key (`.p8`, Key ID, Team ID) ve Firebase bağlantı yetkisi.
5. App Store Connect app kaydı, numeric App Store ID ve doğrulanmış production App Store URL'si.
6. Kullanılacak TestFlight internal/external veya public link bilgisi.
7. Signing tercihi, dağıtım sertifikası/provisioning profili veya CI için App Store Connect API key erişimi.
8. Plus abonelik grubu/ürün ID'leri; 31 rozeti, diğer rozetler, hediye ve tekliflerin Apple ürün/offer ID'leri ve fiyatlandırma kararı.
9. App Store Server Notifications V2 production/sandbox yapılandırma yetkisi ve Apple JWS doğrulaması için gereken anahtar/issuer bilgileri.
10. App Review için güvenli test telefon numarası, SMS doğrulama yöntemi ve inceleme hesabı senaryosu.
11. App Privacy yanıtlarını onaylayacak veri sahibi; analytics retention ve doğrulama belgesi işleme/retention teyidi.
12. Support URL, marketing URL ve privacy URL'nin App Store Connect'te kullanılacak nihai halleri.

## Kesin yayın ve paket kapsamı

Bu değişiklikler için **yeni Android AAB gerekir**, çünkü Flutter istemci kodu, Android native `MainActivity` ve Play App Update bağımlılığı değişti. Mevcut imzalı +31 dosyası korunmuştur ve üzerine yazılmamalıdır. Sonraki AAB, Play Console'daki en yüksek versionCode teyit edilerek ondan büyük olmalıdır; mevcut bilinen en yüksek +31 ise aday +32'dir. Bu tur yeni AAB üretilmedi veya yüklenmedi.

Canlıya alınacak dar backend kapsamı:

1. `adminManageVersionPolicy` Function.
2. Yalnız yeni version-policy match bloklarını içeren Firestore rules yayını (mevcut kirli çalışma ağacındaki ilgisiz rule değişiklikleri ayrıştırılmadan topluca deploy edilmemeli).
3. Android/iOS istemci paketi.
4. İlk dört politika belgesi önce `active=false` ile yönetici callable üzerinden oluşturulmalı.
5. Mağaza sürümü gerçekten erişilebilir olduktan sonra `latestBuild`; ancak doğrulanmış rollout sonrası gerekirse `minimumBuild` yükseltilmeli.

iOS için ayrıca hesap verileri tamamlandıktan sonra yeni signed archive/IPA ve TestFlight yüklemesi gerekir. Canlı deploy, minimum değişikliği, toplu push, gerçek ödeme ve mağaza upload bu çalışmada yapılmadı.
