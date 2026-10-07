// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Dört.';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get pleaseWait => 'Lütfen bekleyin...';

  @override
  String get continueButton => 'Devam Et';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'İptal';

  @override
  String get close => 'Kapat';

  @override
  String get select => 'Seç';

  @override
  String get confirm => 'Onayla';

  @override
  String get delete => 'Sil';

  @override
  String get edit => 'Düzenle';

  @override
  String get send => 'Gönder';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get back => 'Geri';

  @override
  String get next => 'İleri';

  @override
  String get skip => 'Atla';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get ok => 'Tamam';

  @override
  String get search => 'Ara';

  @override
  String get all => 'Tümü';

  @override
  String get optional => 'İsteğe bağlı';

  @override
  String get requiredField => 'Bu alan zorunludur.';

  @override
  String get unknownError => 'Beklenmeyen bir hata oluştu.';

  @override
  String get connectionError => 'Bağlantı Hatası';

  @override
  String get checkInternetConnection =>
      'İnternet bağlantını kontrol edip tekrar dene.';

  @override
  String get operationFailed => 'İşlem tamamlanamadı.';

  @override
  String get operationSuccessful => 'İşlem başarıyla tamamlandı.';

  @override
  String get login => 'Giriş Yap';

  @override
  String get logout => 'Çıkış Yap';

  @override
  String get loggingOut => 'Oturum Kapatılıyor...';

  @override
  String get logoutAccount => 'Oturumu Kapat';

  @override
  String get phoneNumber => 'Telefon Numarası';

  @override
  String get phoneNumberHint => '5XX XXX XX XX';

  @override
  String get phoneNumberRequired => 'Telefon numaranı gir.';

  @override
  String get invalidPhoneNumber => 'Geçerli bir telefon numarası gir.';

  @override
  String get sendSmsCode => 'SMS Kodu Gönder';

  @override
  String get smsVerification => 'SMS Doğrulama';

  @override
  String get verificationCode => 'Doğrulama Kodu';

  @override
  String get verificationCodeHint => '6 haneli kod';

  @override
  String get verificationCodeRequired => 'Doğrulama kodunu gir.';

  @override
  String get invalidVerificationCode => 'Doğrulama kodu hatalı.';

  @override
  String get expiredVerificationCode => 'Doğrulama kodunun süresi doldu.';

  @override
  String get verify => 'Doğrula';

  @override
  String get resendCode => 'Kodu Yeniden Gönder';

  @override
  String resendCodeAfter(int seconds) {
    return '$seconds saniye sonra yeniden gönder';
  }

  @override
  String get smsCodeSent => 'Doğrulama kodu telefonuna gönderildi.';

  @override
  String get smsCodeCouldNotBeSent => 'Doğrulama kodu gönderilemedi.';

  @override
  String get verificationFailed => 'Telefon doğrulaması tamamlanamadı.';

  @override
  String get tooManyRequests =>
      'Çok fazla deneme yaptın. Lütfen daha sonra tekrar dene.';

  @override
  String get sessionNotFound => 'Kullanıcı oturumu bulunamadı.';

  @override
  String get sessionEnded => 'Oturum Sonlandırıldı';

  @override
  String get sessionEndedOnAnotherDevice =>
      'Hesabın başka bir cihazda açıldığı için bu cihazdaki oturumun sona erdi.';

  @override
  String get createProfile => 'Profil Oluştur';

  @override
  String get profile => 'Profil';

  @override
  String get editProfile => 'Profili Düzenle';

  @override
  String get profileInformation => 'Profil Bilgileri';

  @override
  String get profilePhoto => 'Profil Fotoğrafı';

  @override
  String get profilePhotoOptional => 'Profil fotoğrafı isteğe bağlıdır';

  @override
  String get selectProfilePhoto => 'Profil Fotoğrafı Seç';

  @override
  String get profilePhotoCouldNotBeSelected => 'Profil fotoğrafı seçilemedi.';

  @override
  String get selectAvatar => '3D avatar seç';

  @override
  String get name => 'Ad';

  @override
  String get surname => 'Soyad';

  @override
  String get birthDate => 'Doğum tarihi';

  @override
  String get selectBirthDate => 'Doğum tarihini seç';

  @override
  String get gender => 'Cinsiyet';

  @override
  String get female => 'Kadın';

  @override
  String get male => 'Erkek';

  @override
  String get other => 'Diğer';

  @override
  String get city => 'Şehir';

  @override
  String get district => 'İlçe';

  @override
  String get aboutMe => 'Hakkımda';

  @override
  String get aboutMeOptional => 'Hakkımda (isteğe bağlı)';

  @override
  String get enterName => 'Adını gir.';

  @override
  String get enterSurname => 'Soyadını gir.';

  @override
  String get enterCity => 'Şehir bilgisini gir.';

  @override
  String get enterDistrict => 'İlçe bilgisini gir.';

  @override
  String get selectGender => 'Cinsiyet seçimini yap.';

  @override
  String get minimumAgeRequired =>
      'Kayıt olabilmek için 18 yaşını doldurmuş olmalısın.';

  @override
  String get minimumAgeRegistrationMessage =>
      'Dört. uygulamasına yalnızca 18 yaşını doldurmuş kişiler kayıt olabilir.';

  @override
  String get profileCreated => 'Profilin başarıyla oluşturuldu.';

  @override
  String profileCreationFailed(String error) {
    return 'Profil oluşturulurken bir hata oluştu: $error';
  }

  @override
  String get playerVerification => 'Oyuncu Doğrulama';

  @override
  String get verificationStatus => 'Doğrulama Durumum';

  @override
  String get verifiedAccount => 'Hesabın doğrulanmış durumda.';

  @override
  String get verificationPending =>
      'Belgelerin inceleniyor. Sonuçlandığında hesabında gösterilecek.';

  @override
  String get verificationRejected =>
      'Doğrulama başvurun reddedildi. Belgelerini daha sonra yeniden gönderebilirsin.';

  @override
  String get verificationNotCompleted =>
      'Oyuncu doğrulamasını henüz tamamlamadın.';

  @override
  String get verificationOptionalDescription =>
      'Bu adım isteğe bağlıdır. Belgelerin onaylandığında doğrulanmış oyuncu rozeti kazanırsın.';

  @override
  String get identityFront => 'Kimlik Ön Yüzü';

  @override
  String get identityBack => 'Kimlik Arka Yüzü';

  @override
  String get takeSelfie => 'Selfie Çek';

  @override
  String get selfieReady => 'Selfie hazır';

  @override
  String get selfieCouldNotBeTaken => 'Selfie çekilemedi.';

  @override
  String get criminalRecordDocument => 'Adli Sicil Belgesi';

  @override
  String get selectDocument => 'Belge seçmek için dokun';

  @override
  String get documentSelectionFailed => 'Belge seçilirken bir hata oluştu.';

  @override
  String get selectedFileCouldNotBeAccessed => 'Seçilen dosyaya erişilemedi.';

  @override
  String get supportedDocumentTypes =>
      'PDF, JPG veya PNG yükleyebilirsin. Dosya boyutu en fazla 10 MB olabilir.';

  @override
  String get uploadDocumentsAndContinue => 'Belgeleri Yükle ve Devam Et';

  @override
  String get skipForNow => 'Şimdilik Atla';

  @override
  String get requiredVerificationDocuments =>
      'Kimlik ön yüzü, kimlik arka yüzü, adli sicil belgesi ve selfie eklemelisin.';

  @override
  String documentsUploadFailed(String error) {
    return 'Belgeler yüklenirken bir hata oluştu: $error';
  }

  @override
  String get gamesAndSports => 'Oyun ve Sporların';

  @override
  String get selectGamesAndSportsDescription =>
      'Katılmak istediğin oyunları seç ve her biri için seviyeni belirt.';

  @override
  String get selectAtLeastOneGame => 'En az bir oyun veya spor seç.';

  @override
  String selectedBranchCount(int count) {
    return 'Seçili branş: $count';
  }

  @override
  String get beginner => 'Başlangıç';

  @override
  String get intermediate => 'Orta';

  @override
  String get advanced => 'İleri';

  @override
  String get expert => 'Uzman';

  @override
  String get home => 'Ana Sayfa';

  @override
  String get events => 'Etkinlikler';

  @override
  String get event => 'Etkinlik';

  @override
  String get explore => 'Keşfet';

  @override
  String get exploreOnMap => 'Haritada Keşfet';

  @override
  String get exploreEventsOnMap => 'Etkinlikleri haritada keşfet';

  @override
  String get eventsForYou => 'Senin için etkinlikler';

  @override
  String get seeAll => 'Tümünü gör';

  @override
  String get showInCity => 'Şehirde göster';

  @override
  String get nearMe => 'Yakınımda';

  @override
  String get whatDoYouWantToPlayToday => 'Bugün ne oynamak istersin?';

  @override
  String get eventsCouldNotBeLoaded =>
      'Etkinlikler yüklenirken bir hata oluştu.';

  @override
  String get noEventsInCategory => 'Bu kategori için henüz etkinlik yok.';

  @override
  String get joinEvent => 'Etkinliğe Katıl';

  @override
  String get join => 'Katıl';

  @override
  String get apply => 'Başvur';

  @override
  String get applied => 'Başvurdun';

  @override
  String get applicationSent => 'Başvurun etkinlik sahibine gönderildi.';

  @override
  String get eventApplicationFailed => 'Etkinliğe başvururken bir hata oluştu.';

  @override
  String eventApplicationFailedWithError(String error) {
    return 'Etkinliğe başvururken bir hata oluştu: $error';
  }

  @override
  String get loginRequiredForApplication =>
      'Etkinliğe başvurmak için giriş yapmalısın.';

  @override
  String get profileRequiredForApplication =>
      'Etkinliklere başvurmak için oyuncu profilini tamamlayıp Oyuncu Rozeti almalısın.';

  @override
  String get eventOwner => 'Etkinlik Sahibi';

  @override
  String get eventCreatedByYou => 'Etkinliği Sen Oluşturdun';

  @override
  String get joinedEvent => 'Etkinliğe Katıldın';

  @override
  String participantCount(int count) {
    return 'Katılan oyuncu: $count';
  }

  @override
  String get favorites => 'Favoriler';

  @override
  String get addToFavorites => 'Favorilere Ekle';

  @override
  String get removeFromFavorites => 'Favoriden kaldır';

  @override
  String get removedFromFavorites => 'Favorilerden kaldırıldı.';

  @override
  String get noFavoriteEvents => 'Henüz favori etkinliğin yok.';

  @override
  String get favoritesCouldNotBeLoaded => 'Favoriler yüklenemedi.';

  @override
  String get messages => 'Mesajlar';

  @override
  String get message => 'Mesaj';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get notification => 'Bildirim';

  @override
  String get notificationCenter => 'Bildirim Merkezi';

  @override
  String get noNotifications => 'Henüz bildirimin yok.';

  @override
  String get notificationsCouldNotBeLoaded => 'Bildirimler yüklenemedi.';

  @override
  String get markAsRead => 'Okundu olarak işaretle';

  @override
  String get markAsUnread => 'Okunmadı olarak işaretle';

  @override
  String get deleteNotification => 'Bildirimi sil';

  @override
  String get wallet => 'Cüzdan';

  @override
  String get settings => 'Ayarlar';

  @override
  String get language => 'Dil';

  @override
  String get selectLanguage => 'Dil Seç';

  @override
  String get turkish => 'Türkçe';

  @override
  String get english => 'English';

  @override
  String get german => 'Deutsch';

  @override
  String get theme => 'Tema';

  @override
  String get darkTheme => 'Koyu Tema';

  @override
  String get lightTheme => 'Açık Tema';

  @override
  String get systemTheme => 'Sistem Teması';

  @override
  String get support => 'Destek';

  @override
  String get supportCenter => 'Destek Merkezi';

  @override
  String get newSupportRequest => 'Yeni Destek Talebi';

  @override
  String get mySupportRequests => 'Destek Taleplerim';

  @override
  String get supportRequestDetail => 'Talep Detayı';

  @override
  String get recoverMyAccount => 'Hesabımı Geri Al';

  @override
  String get frequentlyAskedQuestions => 'Sık Sorulan Sorular';

  @override
  String get contactUs => 'Bize Ulaşın';

  @override
  String get supportRequest => 'Destek Talebi';

  @override
  String get supportSubject => 'Konu';

  @override
  String get supportDescription => 'Açıklama';

  @override
  String get supportCategory => 'Kategori';

  @override
  String get supportPriority => 'Öncelik';

  @override
  String get supportStatus => 'Durum';

  @override
  String get supportAttachments => 'Ekler';

  @override
  String get addAttachment => 'Dosya Ekle';

  @override
  String get submitSupportRequest => 'Destek Talebini Gönder';

  @override
  String get supportRequestCreated => 'Destek talebin başarıyla oluşturuldu.';

  @override
  String get supportRequestCouldNotBeCreated => 'Destek talebi oluşturulamadı.';

  @override
  String get noSupportRequests => 'Henüz destek talebin yok.';

  @override
  String get supportRequestsCouldNotBeLoaded => 'Destek talepleri yüklenemedi.';

  @override
  String get adminReply => 'Destek Ekibi Yanıtı';

  @override
  String get writeReply => 'Yanıtını yaz';

  @override
  String get sendReply => 'Yanıt Gönder';

  @override
  String get openStatus => 'Açık';

  @override
  String get reviewingStatus => 'İnceleniyor';

  @override
  String get waitingUserStatus => 'Kullanıcı Yanıtı Bekleniyor';

  @override
  String get resolvedStatus => 'Çözüldü';

  @override
  String get rejectedStatus => 'Reddedildi';

  @override
  String get closedStatus => 'Kapatıldı';

  @override
  String get lowPriority => 'Düşük';

  @override
  String get normalPriority => 'Normal';

  @override
  String get highPriority => 'Yüksek';

  @override
  String get urgentPriority => 'Acil';

  @override
  String get supportSecurityWarning =>
      'Güvenliğin için destek ekibi senden SMS doğrulama kodunu veya şifreni istemez.';

  @override
  String get accountStatus => 'Hesap Durumu';

  @override
  String get accountSuspended => 'Hesap Askıya Alındı';

  @override
  String get accountSuspendedDescription =>
      'Hesabın geçici olarak askıya alındı. İnceleme tamamlanana kadar uygulamayı kullanamazsın.';

  @override
  String get accountBanned => 'Hesap Engellendi';

  @override
  String get accountBannedDescription =>
      'Hesabın kullanım kurallarının ihlali nedeniyle engellendi.';

  @override
  String get accountDeletionPending => 'Hesap Silme İşlemi Bekliyor';

  @override
  String get accountDeletionPendingDescription =>
      'Hesabın için silme talebi oluşturulmuş. İşlem tamamlanana kadar uygulamayı kullanamazsın. Uygulamaya giremiyorsan destek@dortapp.com adresine yazabilirsin.';

  @override
  String get accountDeleted => 'Hesap Silindi';

  @override
  String get accountDeletedDescription =>
      'Bu hesap silinmiş ve artık kullanılamaz.';

  @override
  String get contactSupportForAccountStatus =>
      'Bu durumun hatalı olduğunu düşünüyorsan destek ekibimize talep gönderebilirsin.';

  @override
  String get logoutFailed =>
      'Oturum kapatılamadı. İnternet bağlantını kontrol edip tekrar dene.';

  @override
  String get createEvent => 'Etkinlik Oluştur';

  @override
  String get eventInformation => 'Etkinlik bilgileri';

  @override
  String get locationInformation => 'Konum bilgisi';

  @override
  String get descriptionSection => 'Açıklama';

  @override
  String get category => 'Kategori';

  @override
  String get gameOrSport => 'Oyun / spor';

  @override
  String get searchedPlayer => 'Aranan oyuncu';

  @override
  String get preferredMemberType => 'Tercih edilen üye tipi';

  @override
  String get neighborhoodStreet => 'Semt / mahalle / cadde';

  @override
  String get eventDetails => 'Etkinlik ayrıntıları';

  @override
  String get districtsLoading => 'İlçeler yükleniyor...';

  @override
  String selectFromCityDistricts(String city) {
    return '$city ilçelerinden seç';
  }

  @override
  String get selectDistrictFirst => 'Önce ilçe seç';

  @override
  String get startTypingNeighborhoodHint => 'Yazmaya başla: Nişantepe';

  @override
  String searchDistrictsInCity(String city) {
    return '$city ilçelerinde ara';
  }

  @override
  String get districtNotFound => 'İlçe bulunamadı.';

  @override
  String profileInfoLoadFailed(String error) {
    return 'Profil bilgisi yüklenemedi: $error';
  }

  @override
  String get districtsLoadFailed =>
      'İlçeler yüklenemedi. İnternet bağlantını kontrol et.';

  @override
  String get enableLocationServices => 'Telefonun konum servisini açmalısın.';

  @override
  String get locationPermissionDenied =>
      'Konum izni verilmedi. Haritadan elle seçim yapabilirsin.';

  @override
  String locationOutsideActiveCity(String city) {
    return 'Seçtiğin konum $city dışında görünüyor. Ana ekrandan aktif şehri değiştirip tekrar dene.';
  }

  @override
  String get locationSelectedCompleteAddress =>
      'Konum seçildi. Adres servisinin bulamadığı alanı listeden tamamlayabilirsin.';

  @override
  String mapCouldNotOpen(String error) {
    return 'Harita açılamadı: $error';
  }

  @override
  String get cannotSelectPastDateTime => 'Geçmiş tarih ve saat seçemezsin.';

  @override
  String get eventDurationMinOneHour =>
      'Etkinlik süresi en az 1 saat olmalıdır.';

  @override
  String get eventDurationMaxSixHours =>
      'Etkinlik süresi en fazla 6 saat olabilir.';

  @override
  String get eventDurationThirtyMinuteSteps =>
      'Başlangıç ve bitiş saatleri 30 dakikalık aralıklarla seçilmelidir.';

  @override
  String get plusRequiredForMultiplePlayers =>
      '2 veya daha fazla oyuncu için Plus üyelik gerekir.';

  @override
  String get normalMembersTomorrowOnly =>
      'Normal üyeler en fazla yarın için etkinlik oluşturabilir.';

  @override
  String get sessionNotFoundPleaseLogin =>
      'Oturum bulunamadı. Yeniden giriş yapmalısın.';

  @override
  String get addressNotFoundOnMap =>
      'Adres haritada bulunamadı. Mahalle, cadde veya mekan adını daha açık yaz ya da haritadan seç.';

  @override
  String eventCreateFailedWithCode(String code, String message) {
    return 'Etkinlik oluşturulamadı ($code): $message';
  }

  @override
  String eventCreateFailed(String error) {
    return 'Etkinlik oluşturulamadı: $error';
  }

  @override
  String get myLocation => 'Konumum';

  @override
  String get searchOnMap => 'Haritada ara';

  @override
  String get publishEvent => 'Etkinliği yayınla';

  @override
  String get livePriceSummary => 'Canlı fiyat özeti';

  @override
  String get duration => 'Süre';

  @override
  String get durationFactor => 'Süre katsayısı';

  @override
  String get basePricePerPlayer => 'Kişi başı taban fiyat';

  @override
  String get totalFee => 'Toplam ücret';

  @override
  String get durationRangeHint =>
      'Süre 1 ile 6 saat arasında ve 30 dakikalık aralıklarla olmalıdır.';

  @override
  String get plusMemberBenefits =>
      'Plus üye: Birden fazla oyuncu ve ileri tarih seçebilirsin.';

  @override
  String get normalMemberLimits =>
      'Normal üye: 1 oyuncu ve en fazla yarın için etkinlik oluşturabilirsin.';

  @override
  String startTimeLabel(String time) {
    return 'Başlangıç $time';
  }

  @override
  String endTimeLabel(String time) {
    return 'Bitiş $time';
  }

  @override
  String get activeCity => 'Aktif şehir';

  @override
  String get mapSelectionOptional => 'Haritadan seçim zorunlu değildir.';

  @override
  String get meetingPointSelected =>
      'Buluşma noktası seçildi; ilçe ve semt otomatik dolduruldu.';

  @override
  String get mustSelectDistrict => 'İlçe seçmelisin';

  @override
  String get neighborhoodRequired => 'Semt / mahalle bilgisi gerekli';

  @override
  String durationHours(int count) {
    return '$count saat';
  }

  @override
  String durationMinutesOnly(int count) {
    return '$count dakika';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours saat $minutes dakika';
  }

  @override
  String currencyAmount(String amount) {
    return '$amount TL';
  }

  @override
  String get notificationsSection => 'Bildirimler';

  @override
  String get messageNotifications => 'Mesaj bildirimleri';

  @override
  String get eventNotifications => 'Etkinlik bildirimleri';

  @override
  String get applicationNotifications => 'Başvuru bildirimleri';

  @override
  String get campaignNotifications => 'Kampanya bildirimleri';

  @override
  String get documents => 'Belgeler';

  @override
  String get termsOfUse => 'Kullanım Koşulları';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get communityRules => 'Topluluk Kuralları';

  @override
  String get account => 'Hesap';

  @override
  String get changePhoneNumber => 'Telefon numarasını değiştir';

  @override
  String get changePhoneNumberDescription =>
      'Yeni telefon numaranı SMS koduyla doğrula.';

  @override
  String get createAccountDeletionRequest => 'Hesap silme talebi oluştur';

  @override
  String get accountDeletionRequestDescription =>
      'Talep sonrası oturumun kapanır ve hesabın incelemeye alınır.';

  @override
  String get loginRequiredForAccountDeletion =>
      'Hesap silme talebi oluşturmak için giriş yapmalısın.';

  @override
  String get accountDeletionRequestTitle => 'Hesap silme talebi';

  @override
  String get accountDeletionFirstConfirmation =>
      'Hesabın hemen silinmez. Silme talebin kaydedilir ve işlem tamamlanana kadar hesabını kullanamazsın.';

  @override
  String get giveUp => 'Vazgeç';

  @override
  String get continueAction => 'Devam et';

  @override
  String get finalConfirmation => 'Son onay';

  @override
  String get accountDeletionFinalConfirmation =>
      'Silme talebi oluşturulduktan sonra oturumun kapatılacak ve işlem tamamlanana kadar uygulamaya erişemeyeceksin.';

  @override
  String get createRequest => 'Talebi oluştur';

  @override
  String get accountDeletionRequestCouldNotBeCreated =>
      'Hesap silme talebi oluşturulamadı.';

  @override
  String get legalTermsBody =>
      'Dört., kullanıcıların oyun, spor ve sosyal etkinlikler için eksik oyuncu bulmasına yardımcı olur. Etkinlik oluşturma ve katılım ücretsizdir. Kullanıcılar verdikleri bilgilerin doğruluğundan, etkinliklerdeki davranışlarından ve yürürlükteki kurallara uymaktan sorumludur.';

  @override
  String get privacyPolicyBody =>
      'Profil, telefon doğrulama, etkinlik, konum, mesajlaşma, bildirim ve Google Play satın alma kayıtları hizmeti sunmak için işlenir. Kimlik ve doğrulama belgeleri doğrulama süreci için kullanılır. Hesap silme talebi uygulama içinden veya destek@dortapp.com üzerinden oluşturulabilir.';

  @override
  String get communityRulesBody =>
      'Saygılı ol. Taciz, tehdit, ayrımcılık, dolandırıcılık ve yanıltıcı etkinlikler yasaktır. Katılamayacağın etkinliğe başvurma; iptal gerektiğinde organizatöre zamanında haber ver. Güvenlik riski oluşturan kullanıcıları destek kanalına bildir.';
}
