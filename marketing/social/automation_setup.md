# Dört. sosyal içerik üretim sistemi

Bu klasör elle üretime hazırdır. İleride bir araç aynı dosyaları okuyup tasarım ve paylaşım kuyruğu kurabilir.

## Klasör

```text
marketing/social/
  30_day_content_calendar.json
  30_day_content_calendar.csv
  30_day_content_calendar.md
  caption_bank.md
  hashtag_bank.md
  visual_briefs.md
  reels_scripts.md
  story_ideas.md
  brand_copy_bank.md
  automation_setup.md
```

Tasarım dosyaları aynı ağacın altında, takvimden ayrı durur:

```text
marketing/social/exports/
  feed/
  reels/
  story/
  covers/
marketing/social/sources/
  photo/
  logo/
```

Logo kaynağı uygulamadaki `assets/branding/` dosyalarıdır. Sosyal export’a kopyalanır, orijinalin üstüne yazılmaz.

## Dosya adı

Tek kalıp:

`dort_dGG_platform_format_konu`

- `GG` gün numarası, iki hane: `01`–`30`
- platform: `ig` veya `tt`
- format: `feed`, `reel`, `story`, `cover`
- konu: takvim başlığının kısa hali, boşluksuz, Türkçe karakter yerine sade latin

Örnekler:

- `dort_d01_ig_feed_basliyor`
- `dort_d01_tt_reel_uc-vurus`
- `dort_d01_ig_story_slogan`
- `dort_d04_ig_cover_hali-saha`

Bir günün tüm çıktıları aynı `dGG` ile başlar. Böylece klasör sıralanınca takvim sırası bozulmaz.

## Canva akışı

1. Marka kiti: zemin `#0F1115`, vurgu `#FF9800`, yazı beyaz, kart `#181B22`.
2. Dört ana şablon: wordmark, üç adım, etkinlik kartı, nesne karesi. Ayrıntı `visual_briefs.md` içinde.
3. Takvimden o günün satırını aç. Başlık, hook ve Canva notunu şablona taşı.
4. Feed, reels kapağı ve story’yi aynı gün numarasından üret. Metni üçe böl, yeniden yazma.
5. Dışa aktarırken yukarıdaki dosya adını kullan. PNG feed ve story için, MP4 reels için.
6. Caption’ı görselin içine gömme. Caption `kisa_caption` alanından, hashtag ayrı satırdan gelir.

Canva’da şablon adları da aynı kalsın: `dort_tpl_wordmark`, `dort_tpl_uc-adim`, `dort_tpl_kart`, `dort_tpl_nesne`, `dort_tpl_lansman`.

## Toplu üretim

Haftalık ritim yeter.

1. Pazartesi: gelecek 7 günü CSV’den süz.
2. Aynı gün görselleri şablondan çoğalt. Gün başına bir feed, bir kapak, bir story.
3. Caption’ları bir tabloya yapıştır: gün, kısa caption, uzun caption, CTA, hashtag.
4. Reels yalnızca senaryosu hazır olan günlerde çekilir. On senaryo `reels_scripts.md` içindedir.
5. Story serileri yayın gününün sabahı girilir. Geceye anket sonucu bırakma.
6. Yayın saati sabit olsun. Öneri: feed 18.30, story 12.00, reels 20.00.
7. Yayınlananı `exports/` altında tut. Taslağı `sources/` altında bırak.

## İleride otomasyon

`30_day_content_calendar.json` kaynak kayıttır. CSV tablo içindir, Markdown okumak içindir. Bir araç eklenecekse yalnızca JSON’u okusun.

Beklenen alanlar zaten duruyor: `day`, `contentType`, `title`, `hook`, `shortCaption`, `longCaption`, `cta`, `story`, `reelIdea`, `visualBrief`, `canvaNote`, `hashtags`.

İleride eklenebilecek ama şimdi uydurulmayan alanlar: yayın tarihi, durum, medya yolu. Tarih, lansman günü netleşince elle yazılsın. Durum ancak paylaşım aracı bağlanınca anlam kazanır.

Otomasyon şu sırayı bozmasın: JSON’dan metni al, dosya adını gün numarasından kur, Canva şablonunu içerik tipine eşle, dışa aktar, caption’ı ayrı gönder. Görselin içine uzun caption basmasın.

Eşleme:

- Marka tanıtımı ve lansman: `dort_tpl_wordmark` veya `dort_tpl_lansman`
- Nasıl çalışır: `dort_tpl_uc-adim`
- Etkinlik, spor, kart, masa: `dort_tpl_kart` veya `dort_tpl_nesne`
- Problem / çözüm: `dort_tpl_kart`, soluk mesaj katmanı ile
- Topluluk ve güven: `dort_tpl_wordmark`

X bu kurulumda yok. Aynı JSON’a platform eklenmeden X kopyası üretilmesin.
