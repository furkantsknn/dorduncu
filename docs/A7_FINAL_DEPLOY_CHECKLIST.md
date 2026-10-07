# A7 FINAL DEPLOY CHECKLIST

Bu liste A7 kapanış kaydıdır.
Şu an deploy çalıştırmak ZORUNLU DEĞİLDİR.

## Deploy öncesi
- [ ] flutter analyze temiz
- [ ] functions/npm run lint temiz
- [ ] functions/npm run build temiz
- [ ] Dedicated Admin Hosting site adı belirlendi
- [ ] firebase target:apply hosting admin <ADMIN_SITE_ID> hazır
- [ ] reCAPTCHA Enterprise key'e gerçek admin domain eklendi
- [ ] Firebase Authentication Authorized Domains'e gerçek admin domain eklendi
- [ ] ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY ortam değişkeninde mevcut
- [ ] Production admin domain kesinleşti

## Tek seferlik deploy sırası

Proje kökü:
```powershell
cd C:\Users\FURKAN\Desktop\dorduncu
```

Firestore Rules:
```powershell
firebase deploy --only firestore:rules
```

Storage Rules:
```powershell
firebase deploy --only storage
```

Functions:
```powershell
firebase deploy --only functions
```

Admin Web build:
```powershell
$env:ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY="GERCEK_SITE_KEY"
powershell -ExecutionPolicy Bypass -File .\scripts\build_admin_web.ps1
```

Admin Hosting:
```powershell
firebase deploy --only hosting:admin
```

## Not
`firebase target:apply hosting admin <ADMIN_SITE_ID>` komutu sadece dedicated
admin Hosting site gerçekten oluşturulduktan ve ID kesinleştikten sonra bir kez
çalıştırılmalıdır.

Site ID tahmin edilmemelidir.
