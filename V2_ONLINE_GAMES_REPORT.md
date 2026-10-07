# V2 Online Oyna

Durum: yerel bot prototipi çalışır. Çok oyunculu masa çalışır durumda değildir ve uygulama içinde açılmaz. Production deploy yapılmadı.

## Başlangıç

- Başlangıç dalı ve commit: `main` = `feature/v2-online-games` = `264c381` (`Initial project snapshot`)
- Yedek işaret: `backup/v1-head-264c381` aynı commit’i gösterir
- V2 commit’i yok. V1 ve Plus Billing değişiklikleri working tree’de duruyor; silinmedi ve geri alınmadı
- Secret commit edilmedi. `.gitignore` içinde `.env`, `.env.*`, `*serviceAccount*.json`, `*service-account*.json`, `*firebase-adminsdk*.json`, `android/key.properties` ve upload keystore var

## Bayrak

Varsayılan kapalıdır. Menü satırı ve emülatör bağlantısı ancak şu tanımlarla derlenirse vardır:

```text
flutter run --dart-define=ONLINE_GAMES_V2=true
```

Çok oyunculu çağrı ayrıca `ONLINE_GAMES_V2_EMULATOR=true` ister ve release derlemede kapalıdır. Bu tanım bütün Firebase istemcisini `127.0.0.1` emülatörüne çevirir. Tanım yokken production Firebase yolu değişmez.

Emülatör tanımı açık olsa bile hub’da masa kurma düğmesi yoktur. İki kullanıcılı oturum çalıştırılmadı.

## Nasıl açılır

Bayrak kapalıyken çekmece V1 ile aynıdır. Bayrak açıkken çekmecede, Market satırının altında, Online Oyna görünür. Dört oyun da “Botla oyna” ile tek cihazda açılır. İnsan koltuk 0’dır. Diğer koltuklar Bot 2, Bot 3 ve Bot 4 olarak yazılır. Tavla’da yalnızca Bot 2 vardır. Bağlantı etiketi “Yerel oturum”tur. Çip yoktur.

## Kural varyantları

- Okey: dört kişi, 106 taş, gösterge okeyi belirler. Sahte okey gösterge yüzünü taşır ve joker değildir. İki gerçek okey jokerdir. Koltuk 0, 15 taşla başlar ve ilk atar. Seri 13’ten 1’e sarmaz. Kalan 14 taş per veya seri olunca el biter. Deste ve atık biterse el berabere biter; rastgele kazanan yazılmaz.
- 101: aynı dağıtım. Açılış en az 101 ve bir veya daha fazla per. Taş yalnızca kendi perlerine eklenir. Atıktan alınan taş tur bitmeden perde kullanılmalıdır. Açılmamış el 202 ceza yer. Açılmış el kalan taşların puanını öder. Boş el kazanır.
- Batak: 52 kart, 13’er, tek el ihale. İhale 5–13 ve yükselmek zorundadır. Herkes pas geçerse dağıtan 5 der ve kozu söyler. Renk zorunludur. Kozun büyüğü, yoksa yer renginin büyüğü alır. As en büyük karttır. Yapan tutarsa +ihale, kaçırırsa −ihale. Savunanlar her aldıkları eli 1 puan yazar.
- Tavla: iki kişi, standart tavla, katlama küpü yok. Beyaz 1’e, siyah 24’e gider. Bar önce girer. Kırılan pul bar’a döner. İki veya daha fazla rakip pulun olduğu noktaya inilmez. Çıkarma yalnızca iç sahadan yapılır. İki zar da oynanabiliyorsa ikisi de oynanır. Normal 1, mars 2, geri mars 3.

## Oyun durumu

| Oyun | Motor | Bot | Yerel arayüz | Çok oyunculu |
| --- | --- | --- | --- | --- |
| Okey | Var, test edildi | Var, eli bitirir | Var | Yok |
| 101 | Var, test edildi | Var, eli bitirir | Var | Yok |
| Batak | Var, test edildi | Var, eli bitirir | Var | Yok |
| Tavla | Var, test edildi | Var, eli bitirir | Var | Yok |

Motor testleri `test/online_v2_engines_test.dart` içindedir. Ayrı bir widget testi yoktur. Motor hata cümleleri Türkçedir; ekran çerçevesi TR/EN/DE’dir.

## Sunucu

Yeni koleksiyonlar: `online_v2_tables`, altındaki `hands` ve `moves`, ayrıca `online_v2_invites`. İstemci yazması kapalıdır. El belgesi yalnızca sahibine okunur. Davet yalnızca gönderen veya hedefe okunur.

Callable’lar `FUNCTIONS_EMULATOR=true` değilse masayı reddeder. Daveti yalnızca hedef kabul edebilir. Arkadaşlık ve iki yönlü engel kontrol edilir. Lobide ayrılmak koltuğu siler ve skor yazmaz. 45 saniyelik lobi zaman aşımı da skor yazmaz. `submitOnlineV2MoveCall` hamleyi oyun sonucu yapmaz; `engine_not_attached` ile reddeder ve aynı hamle kimliğini ikinci kez uygulamaz.

Bu kontroller `node lib/online_v2/tableAuthorityCheck.js` ile geçti. İki kullanıcılı emülatör oturumu çalıştırılmadı. Zaman aşımı için production scheduler yok.

## Emülatör

`firebase.json` içinde auth 9099, functions 5001, firestore 8080, arayüz 4000, hepsi `127.0.0.1`. Deploy hedefi değişmedi. Başlatma komutu, bu turda çalıştırılmadı:

```text
firebase emulators:start --only auth,functions,firestore
```

## Bilinen boşluklar

- Çok oyunculu hamle motoru Dart motoruna bağlı değil
- İki oturumlu emülatör doğrulaması yok
- Oyun içi hata metinleri yalnızca Türkçe
- Çip yok; bu bilinçli
- Gerçek para, Play ürünü ve satın alma yok

## V1’e dönüş

`git reset --hard` veya `git clean -fd` kullanılmaz. V1/Billing dosyaları working tree’de kalır.

Yalnızca şu yeni yollar silinir:

- `lib/online_v2`
- `functions/src/online_v2`
- `test/online_v2_engines_test.dart`
- `V2_ONLINE_GAMES_REPORT.md`

Paylaşılan dosyalarda yalnızca V2 parçaları çıkarılır: `lib/main.dart` emülatör bloğu, `lib/screens/home_screen.dart` çekmece satırı ve `onlinePlay` metni, `firestore.rules` içindeki `online_v2_*` kuralları, `firebase.json` emulators bloğu, `functions/src/index.ts` sonundaki online export, `lib/l10n` online anahtarları. Bu dosyaların geri kalanı V1/Billing işidir ve olduğu gibi kalır.

## Kontroller

- `flutter analyze`: sorun yok
- `flutter test`: 14 test geçti. İçinde 6 online motor testi, 6 Plus teklif testi, yasal varlık testi ve basit widget testi var
- `npm run build` (`functions`): geçti
- `npx eslint` yeni online dosyalar ve `index.ts`: geçti
- `node lib/online_v2/tableAuthorityCheck.js`: geçti
- Android debug APK: geçti. Çıktı `build/app/outputs/flutter-apk/app-debug.apk`. Gradle Kotlin eklenti uyarısı verdi; derleme başarısız olmadı
- Production deploy: yapılmadı
