# V1 etkileşim denetimi

Dal: `release/v1-internal-test`. Play dahili testteki paket `1.0.0+1`. Bu turda yeni AAB üretilmedi.

## Bulunan hata ve tekrar üretme

Ana ekranda İstanbul seçiliyken etkinlikler ve harita görünüyor. Şehir Ankara yapılınca listedeki ve haritadaki İstanbul etkinlikleri kalkıyor, kamera İstanbul’da kalıyor. Ankara’da etkinlik olmasa da kamera İstanbul’da kalıyor.

Kök neden: görünen harita `HomeEventMap`. Şehir seçimini almıyor, açılış merkezini İstanbul sabitliyor ve yalnızca etkinlik sınırına göre kayıyordu. Etkinlik yoksa kamera hiç hareket etmiyordu. Liste ise `aktifSehir` ile süzülüyordu.

## Yapılan düzeltme

Seçili şehir, liste ve harita aynı `aktifSehir` değerini kullanır. Şehir merkezi mevcut 81 il tablosundan çözülür. Kamera, etkinlik olmasa da il merkezine 11.5 zoom ile gider. Controller hazır değilse son şehir bekler. Daha yeni seçim eski kamera komutunu geçersiz kılar. Aynı şehirde yeniden çizim veya kullanıcının haritayı gezdirmesi kamerayı merkeze çekmez.

Konum, seçili şehri yazmaz. Eski ana sayfadaki yakınımda düğmesi premium ana sayfada yok. Keşfet haritasındaki konum düğmesi açık bir kullanıcı hareketidir; sonrasında gelen şehir seçimi bu konumu ezer.

Hızlı şehir seçiminde profil yazması sıraya alınır. Eski profil okuması yeni seçimi geri yazmaz.

Keşfet haritası, ana ekrandan açıldığı andaki seçili şehirle açılır. Aynı ekran yeni bir şehir alırsa kamerası da o şehre gider. Etkinlik sorgusu açılışta bağlanır; alttaki ana ekranda şehir değişince açık keşfet sorgusu kendiliğinden yenilenmez. Kullanıcı keşfeti yeniden açınca güncel şehri görür.

Değişen dosyalar:

- `lib/utils/turkey_city_centers.dart`
- `lib/utils/city_map_camera.dart`
- `lib/home_v2/home_event_map.dart`
- `lib/home_v2/home_screen_v2.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/explore_map_screen.dart`
- `test/city_map_camera_test.dart`

## Doğrulama

`flutter analyze`: sorun yok.

`flutter test` (`city_map_camera_test`, `plus_subscription_offer_test`, `legal_assets_test`): 12 test geçti. Kapsanan kararlar: il merkezi, etkinliksiz şehir, geç hazır olan controller, hızlı seçim, aynı şehirde yeniden çizimde kamera istenmemesi.

Telefonda çalıştırılmadı. Harita kayması cihazda doğrulanmış sayılmaz.

## Tarama

Kodda bakılan akışlar: ana sayfa şehir ve oyun filtreleri, etkinlik kartı ve harita önizlemesi, etkinlik oluşturma, başvuru, kabul, ret, geri çekme, Etkinliklerim sohbet kapısı, sohbet listesi ve mesaj gönderme kilidi, profil, arkadaşlık, favoriler, bildirim yönlendirmesi, ayarlar, dil, destek, yasal belgeler, Market, Plus, rozet, geri yükleme ve abonelik yönetimi.

Somut ikinci bir kırık düğme bulunmadı. Başvuru, kabul/ret ve mesaj gönderme çift tıklamaya karşı kilitli. Etkinlik mesajı okuma kuralı sohbet üyeliği ister. `WalletScreen` ve `PaymentScreen` kullanıcı ekranlarından açılmıyor. Market ve destek çekmeceden gerçek ekranlara gidiyor.

Dokunulmayan ölü kod: `GameScreen` boş `onPressed` içerir ve hiçbir yerden açılmaz. `lib/screens/notification_screen.dart` içe aktarılmaz; açık olan ekran `notification_center_screen.dart`. Kullanılmayan “Market yakında” ve “Destek daha sonra” metinleri duruyor.

Keşfet haritasındaki kategori çipleri ana sayfadaki tam oyun kataloğundan kısadır. Bu mevcut keşfet akışı; bu turda değiştirilmedi.

## Manuel yapılandırma

Google Play ürün ve base plan eşlemesi eksikse satın alma kapalı kalır. Kod sahte başarı yazmaz. Gerçek Play satın alması bu turda çalıştırılmadı: TEST BEKLİYOR.

Plus base plan seçimi ve yasal kabul kaydı değiştirilmedi.

## Cihazda test ve kalanlar

Telefonda bakılacaklar:

1. İstanbul seçiliyken Ankara’ya geç. Liste ve harita Ankara merkezine gitsin. Ankara’da etkinlik olmasa da kamera gitsin.
2. Hızlıca birkaç şehir seç. Son seçilen şehir kalsın.
3. Haritayı kaydır. Liste yenilenirken kamera merkeze zıplamasın.
4. Keşfet haritasını aç. Aynı şehri göstersin. Konum düğmesi seçili şehri değiştirmesin.
5. Etkinlik kartı, başvuru, Etkinliklerim sohbeti, mesaj gönderme, profil, ayarlar ve Market’i bir kez dene.

Kalanlar: cihaz testi yapılmadı. Yeni AAB yok; Play’deki `1.0.0+1` bu düzeltmeyi içermez. Sonraki yükleme daha yüksek `versionCode` ister. V2 Online Oyna geri getirilmedi.

## Etkilenen kullanım noktaları

Şehir merkezi artık `turkeyCityCenter` üzerinden okunur.

- Ana sayfa haritası: `HomeEventMap`, şehir `HomeScreenV2.cityLabel`.
- Keşfet haritası: `ExploreMapScreen`.
- Eski ana sayfa haritası: `kUsePremiumHomeV2` kapalıyken `HomeScreen._cityCenter`. Görünen kabuk bu harita değil.
- Etkinlik listesi sorgusu: `EventService.watchListedEvents(city:)`.
- Konum düğmesi şehir yazmaz.

`turkey_locations.json` il ve ilçe adı taşır, koordinat taşımaz. Koordinat kaynağı olarak kullanılmadı.
