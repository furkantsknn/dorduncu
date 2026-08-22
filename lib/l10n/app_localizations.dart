import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In tr, this message translates to:
  /// **'Dördüncü'**
  String get appName;

  /// No description provided for @loading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get loading;

  /// No description provided for @pleaseWait.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bekleyin...'**
  String get pleaseWait;

  /// No description provided for @continueButton.
  ///
  /// In tr, this message translates to:
  /// **'Devam Et'**
  String get continueButton;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @select.
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get select;

  /// No description provided for @confirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get edit;

  /// No description provided for @send.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get send;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get back;

  /// No description provided for @next.
  ///
  /// In tr, this message translates to:
  /// **'İleri'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get skip;

  /// No description provided for @yes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get ok;

  /// No description provided for @search.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get search;

  /// No description provided for @all.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get all;

  /// No description provided for @optional.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı'**
  String get optional;

  /// No description provided for @requiredField.
  ///
  /// In tr, this message translates to:
  /// **'Bu alan zorunludur.'**
  String get requiredField;

  /// No description provided for @unknownError.
  ///
  /// In tr, this message translates to:
  /// **'Beklenmeyen bir hata oluştu.'**
  String get unknownError;

  /// No description provided for @connectionError.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı Hatası'**
  String get connectionError;

  /// No description provided for @checkInternetConnection.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantını kontrol edip tekrar dene.'**
  String get checkInternetConnection;

  /// No description provided for @operationFailed.
  ///
  /// In tr, this message translates to:
  /// **'İşlem tamamlanamadı.'**
  String get operationFailed;

  /// No description provided for @operationSuccessful.
  ///
  /// In tr, this message translates to:
  /// **'İşlem başarıyla tamamlandı.'**
  String get operationSuccessful;

  /// No description provided for @login.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get logout;

  /// No description provided for @loggingOut.
  ///
  /// In tr, this message translates to:
  /// **'Oturum Kapatılıyor...'**
  String get loggingOut;

  /// No description provided for @logoutAccount.
  ///
  /// In tr, this message translates to:
  /// **'Oturumu Kapat'**
  String get logoutAccount;

  /// No description provided for @phoneNumber.
  ///
  /// In tr, this message translates to:
  /// **'Telefon Numarası'**
  String get phoneNumber;

  /// No description provided for @phoneNumberHint.
  ///
  /// In tr, this message translates to:
  /// **'5XX XXX XX XX'**
  String get phoneNumberHint;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In tr, this message translates to:
  /// **'Telefon numaranı gir.'**
  String get phoneNumberRequired;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir telefon numarası gir.'**
  String get invalidPhoneNumber;

  /// No description provided for @sendSmsCode.
  ///
  /// In tr, this message translates to:
  /// **'SMS Kodu Gönder'**
  String get sendSmsCode;

  /// No description provided for @smsVerification.
  ///
  /// In tr, this message translates to:
  /// **'SMS Doğrulama'**
  String get smsVerification;

  /// No description provided for @verificationCode.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama Kodu'**
  String get verificationCode;

  /// No description provided for @verificationCodeHint.
  ///
  /// In tr, this message translates to:
  /// **'6 haneli kod'**
  String get verificationCodeHint;

  /// No description provided for @verificationCodeRequired.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodunu gir.'**
  String get verificationCodeRequired;

  /// No description provided for @invalidVerificationCode.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu hatalı.'**
  String get invalidVerificationCode;

  /// No description provided for @expiredVerificationCode.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodunun süresi doldu.'**
  String get expiredVerificationCode;

  /// No description provided for @verify.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu Yeniden Gönder'**
  String get resendCode;

  /// No description provided for @resendCodeAfter.
  ///
  /// In tr, this message translates to:
  /// **'{seconds} saniye sonra yeniden gönder'**
  String resendCodeAfter(int seconds);

  /// No description provided for @smsCodeSent.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu telefonuna gönderildi.'**
  String get smsCodeSent;

  /// No description provided for @smsCodeCouldNotBeSent.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu gönderilemedi.'**
  String get smsCodeCouldNotBeSent;

  /// No description provided for @verificationFailed.
  ///
  /// In tr, this message translates to:
  /// **'Telefon doğrulaması tamamlanamadı.'**
  String get verificationFailed;

  /// No description provided for @tooManyRequests.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme yaptın. Lütfen daha sonra tekrar dene.'**
  String get tooManyRequests;

  /// No description provided for @sessionNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı oturumu bulunamadı.'**
  String get sessionNotFound;

  /// No description provided for @sessionEnded.
  ///
  /// In tr, this message translates to:
  /// **'Oturum Sonlandırıldı'**
  String get sessionEnded;

  /// No description provided for @sessionEndedOnAnotherDevice.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın başka bir cihazda açıldığı için bu cihazdaki oturumun sona erdi.'**
  String get sessionEndedOnAnotherDevice;

  /// No description provided for @createProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil Oluştur'**
  String get createProfile;

  /// No description provided for @profile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profili Düzenle'**
  String get editProfile;

  /// No description provided for @profileInformation.
  ///
  /// In tr, this message translates to:
  /// **'Profil Bilgileri'**
  String get profileInformation;

  /// No description provided for @profilePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Profil Fotoğrafı'**
  String get profilePhoto;

  /// No description provided for @profilePhotoOptional.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı isteğe bağlıdır'**
  String get profilePhotoOptional;

  /// No description provided for @selectProfilePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Profil Fotoğrafı Seç'**
  String get selectProfilePhoto;

  /// No description provided for @profilePhotoCouldNotBeSelected.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı seçilemedi.'**
  String get profilePhotoCouldNotBeSelected;

  /// No description provided for @selectAvatar.
  ///
  /// In tr, this message translates to:
  /// **'3D avatar seç'**
  String get selectAvatar;

  /// No description provided for @name.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get name;

  /// No description provided for @surname.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get surname;

  /// No description provided for @birthDate.
  ///
  /// In tr, this message translates to:
  /// **'Doğum tarihi'**
  String get birthDate;

  /// No description provided for @selectBirthDate.
  ///
  /// In tr, this message translates to:
  /// **'Doğum tarihini seç'**
  String get selectBirthDate;

  /// No description provided for @gender.
  ///
  /// In tr, this message translates to:
  /// **'Cinsiyet'**
  String get gender;

  /// No description provided for @female.
  ///
  /// In tr, this message translates to:
  /// **'Kadın'**
  String get female;

  /// No description provided for @male.
  ///
  /// In tr, this message translates to:
  /// **'Erkek'**
  String get male;

  /// No description provided for @other.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get other;

  /// No description provided for @city.
  ///
  /// In tr, this message translates to:
  /// **'Şehir'**
  String get city;

  /// No description provided for @district.
  ///
  /// In tr, this message translates to:
  /// **'İlçe'**
  String get district;

  /// No description provided for @aboutMe.
  ///
  /// In tr, this message translates to:
  /// **'Hakkımda'**
  String get aboutMe;

  /// No description provided for @aboutMeOptional.
  ///
  /// In tr, this message translates to:
  /// **'Hakkımda (isteğe bağlı)'**
  String get aboutMeOptional;

  /// No description provided for @enterName.
  ///
  /// In tr, this message translates to:
  /// **'Adını gir.'**
  String get enterName;

  /// No description provided for @enterSurname.
  ///
  /// In tr, this message translates to:
  /// **'Soyadını gir.'**
  String get enterSurname;

  /// No description provided for @enterCity.
  ///
  /// In tr, this message translates to:
  /// **'Şehir bilgisini gir.'**
  String get enterCity;

  /// No description provided for @enterDistrict.
  ///
  /// In tr, this message translates to:
  /// **'İlçe bilgisini gir.'**
  String get enterDistrict;

  /// No description provided for @selectGender.
  ///
  /// In tr, this message translates to:
  /// **'Cinsiyet seçimini yap.'**
  String get selectGender;

  /// No description provided for @minimumAgeRequired.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt olabilmek için 18 yaşını doldurmuş olmalısın.'**
  String get minimumAgeRequired;

  /// No description provided for @minimumAgeRegistrationMessage.
  ///
  /// In tr, this message translates to:
  /// **'Dördüncü uygulamasına yalnızca 18 yaşını doldurmuş kişiler kayıt olabilir.'**
  String get minimumAgeRegistrationMessage;

  /// No description provided for @profileCreated.
  ///
  /// In tr, this message translates to:
  /// **'Profilin başarıyla oluşturuldu.'**
  String get profileCreated;

  /// No description provided for @profileCreationFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil oluşturulurken bir hata oluştu: {error}'**
  String profileCreationFailed(String error);

  /// No description provided for @playerVerification.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncu Doğrulama'**
  String get playerVerification;

  /// No description provided for @verificationStatus.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama Durumum'**
  String get verificationStatus;

  /// No description provided for @verifiedAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın doğrulanmış durumda.'**
  String get verifiedAccount;

  /// No description provided for @verificationPending.
  ///
  /// In tr, this message translates to:
  /// **'Belgelerin inceleniyor. Sonuçlandığında hesabında gösterilecek.'**
  String get verificationPending;

  /// No description provided for @verificationRejected.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama başvurun reddedildi. Belgelerini daha sonra yeniden gönderebilirsin.'**
  String get verificationRejected;

  /// No description provided for @verificationNotCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncu doğrulamasını henüz tamamlamadın.'**
  String get verificationNotCompleted;

  /// No description provided for @verificationOptionalDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu adım isteğe bağlıdır. Belgelerin onaylandığında doğrulanmış oyuncu rozeti kazanırsın.'**
  String get verificationOptionalDescription;

  /// No description provided for @identityFront.
  ///
  /// In tr, this message translates to:
  /// **'Kimlik Ön Yüzü'**
  String get identityFront;

  /// No description provided for @identityBack.
  ///
  /// In tr, this message translates to:
  /// **'Kimlik Arka Yüzü'**
  String get identityBack;

  /// No description provided for @takeSelfie.
  ///
  /// In tr, this message translates to:
  /// **'Selfie Çek'**
  String get takeSelfie;

  /// No description provided for @selfieReady.
  ///
  /// In tr, this message translates to:
  /// **'Selfie hazır'**
  String get selfieReady;

  /// No description provided for @selfieCouldNotBeTaken.
  ///
  /// In tr, this message translates to:
  /// **'Selfie çekilemedi.'**
  String get selfieCouldNotBeTaken;

  /// No description provided for @criminalRecordDocument.
  ///
  /// In tr, this message translates to:
  /// **'Adli Sicil Belgesi'**
  String get criminalRecordDocument;

  /// No description provided for @selectDocument.
  ///
  /// In tr, this message translates to:
  /// **'Belge seçmek için dokun'**
  String get selectDocument;

  /// No description provided for @documentSelectionFailed.
  ///
  /// In tr, this message translates to:
  /// **'Belge seçilirken bir hata oluştu.'**
  String get documentSelectionFailed;

  /// No description provided for @selectedFileCouldNotBeAccessed.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen dosyaya erişilemedi.'**
  String get selectedFileCouldNotBeAccessed;

  /// No description provided for @supportedDocumentTypes.
  ///
  /// In tr, this message translates to:
  /// **'PDF, JPG veya PNG yükleyebilirsin. Dosya boyutu en fazla 10 MB olabilir.'**
  String get supportedDocumentTypes;

  /// No description provided for @uploadDocumentsAndContinue.
  ///
  /// In tr, this message translates to:
  /// **'Belgeleri Yükle ve Devam Et'**
  String get uploadDocumentsAndContinue;

  /// No description provided for @skipForNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdilik Atla'**
  String get skipForNow;

  /// No description provided for @requiredVerificationDocuments.
  ///
  /// In tr, this message translates to:
  /// **'Kimlik ön yüzü, kimlik arka yüzü, adli sicil belgesi ve selfie eklemelisin.'**
  String get requiredVerificationDocuments;

  /// No description provided for @documentsUploadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Belgeler yüklenirken bir hata oluştu: {error}'**
  String documentsUploadFailed(String error);

  /// No description provided for @gamesAndSports.
  ///
  /// In tr, this message translates to:
  /// **'Oyun ve Sporların'**
  String get gamesAndSports;

  /// No description provided for @selectGamesAndSportsDescription.
  ///
  /// In tr, this message translates to:
  /// **'Katılmak istediğin oyunları seç ve her biri için seviyeni belirt.'**
  String get selectGamesAndSportsDescription;

  /// No description provided for @selectAtLeastOneGame.
  ///
  /// In tr, this message translates to:
  /// **'En az bir oyun veya spor seç.'**
  String get selectAtLeastOneGame;

  /// No description provided for @selectedBranchCount.
  ///
  /// In tr, this message translates to:
  /// **'Seçili branş: {count}'**
  String selectedBranchCount(int count);

  /// No description provided for @beginner.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In tr, this message translates to:
  /// **'İleri'**
  String get advanced;

  /// No description provided for @expert.
  ///
  /// In tr, this message translates to:
  /// **'Uzman'**
  String get expert;

  /// No description provided for @home.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get home;

  /// No description provided for @events.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get events;

  /// No description provided for @event.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get event;

  /// No description provided for @explore.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get explore;

  /// No description provided for @exploreOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritada Keşfet'**
  String get exploreOnMap;

  /// No description provided for @exploreEventsOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikleri haritada keşfet'**
  String get exploreEventsOnMap;

  /// No description provided for @eventsForYou.
  ///
  /// In tr, this message translates to:
  /// **'Senin için etkinlikler'**
  String get eventsForYou;

  /// No description provided for @seeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü gör'**
  String get seeAll;

  /// No description provided for @showInCity.
  ///
  /// In tr, this message translates to:
  /// **'Şehirde göster'**
  String get showInCity;

  /// No description provided for @nearMe.
  ///
  /// In tr, this message translates to:
  /// **'Yakınımda'**
  String get nearMe;

  /// No description provided for @whatDoYouWantToPlayToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün ne oynamak istersin?'**
  String get whatDoYouWantToPlayToday;

  /// No description provided for @eventsCouldNotBeLoaded.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler yüklenirken bir hata oluştu.'**
  String get eventsCouldNotBeLoaded;

  /// No description provided for @noEventsInCategory.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategori için henüz etkinlik yok.'**
  String get noEventsInCategory;

  /// No description provided for @joinEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğe Katıl'**
  String get joinEvent;

  /// No description provided for @join.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get join;

  /// No description provided for @apply.
  ///
  /// In tr, this message translates to:
  /// **'Başvur'**
  String get apply;

  /// No description provided for @applied.
  ///
  /// In tr, this message translates to:
  /// **'Başvurdun'**
  String get applied;

  /// No description provided for @applicationSent.
  ///
  /// In tr, this message translates to:
  /// **'Başvurun etkinlik sahibine gönderildi.'**
  String get applicationSent;

  /// No description provided for @eventApplicationFailed.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğe başvururken bir hata oluştu.'**
  String get eventApplicationFailed;

  /// No description provided for @eventApplicationFailedWithError.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğe başvururken bir hata oluştu: {error}'**
  String eventApplicationFailedWithError(String error);

  /// No description provided for @loginRequiredForApplication.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğe başvurmak için giriş yapmalısın.'**
  String get loginRequiredForApplication;

  /// No description provided for @profileRequiredForApplication.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklere başvurmak için oyuncu profilini tamamlayıp Oyuncu Rozeti almalısın.'**
  String get profileRequiredForApplication;

  /// No description provided for @eventOwner.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik Sahibi'**
  String get eventOwner;

  /// No description provided for @eventCreatedByYou.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği Sen Oluşturdun'**
  String get eventCreatedByYou;

  /// No description provided for @joinedEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğe Katıldın'**
  String get joinedEvent;

  /// No description provided for @participantCount.
  ///
  /// In tr, this message translates to:
  /// **'Katılan oyuncu: {count}'**
  String participantCount(int count);

  /// No description provided for @favorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get favorites;

  /// No description provided for @addToFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere Ekle'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriden kaldır'**
  String get removeFromFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden kaldırıldı.'**
  String get removedFromFavorites;

  /// No description provided for @noFavoriteEvents.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori etkinliğin yok.'**
  String get noFavoriteEvents;

  /// No description provided for @favoritesCouldNotBeLoaded.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler yüklenemedi.'**
  String get favoritesCouldNotBeLoaded;

  /// No description provided for @messages.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get messages;

  /// No description provided for @message.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj'**
  String get message;

  /// No description provided for @notifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notifications;

  /// No description provided for @notification.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim'**
  String get notification;

  /// No description provided for @notificationCenter.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim Merkezi'**
  String get notificationCenter;

  /// No description provided for @noNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bildirimin yok.'**
  String get noNotifications;

  /// No description provided for @notificationsCouldNotBeLoaded.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler yüklenemedi.'**
  String get notificationsCouldNotBeLoaded;

  /// No description provided for @markAsRead.
  ///
  /// In tr, this message translates to:
  /// **'Okundu olarak işaretle'**
  String get markAsRead;

  /// No description provided for @markAsUnread.
  ///
  /// In tr, this message translates to:
  /// **'Okunmadı olarak işaretle'**
  String get markAsUnread;

  /// No description provided for @deleteNotification.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimi sil'**
  String get deleteNotification;

  /// No description provided for @wallet.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdan'**
  String get wallet;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil Seç'**
  String get selectLanguage;

  /// No description provided for @turkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get turkish;

  /// No description provided for @english.
  ///
  /// In tr, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @german.
  ///
  /// In tr, this message translates to:
  /// **'Deutsch'**
  String get german;

  /// No description provided for @theme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @darkTheme.
  ///
  /// In tr, this message translates to:
  /// **'Koyu Tema'**
  String get darkTheme;

  /// No description provided for @lightTheme.
  ///
  /// In tr, this message translates to:
  /// **'Açık Tema'**
  String get lightTheme;

  /// No description provided for @systemTheme.
  ///
  /// In tr, this message translates to:
  /// **'Sistem Teması'**
  String get systemTheme;

  /// No description provided for @support.
  ///
  /// In tr, this message translates to:
  /// **'Destek'**
  String get support;

  /// No description provided for @supportCenter.
  ///
  /// In tr, this message translates to:
  /// **'Destek Merkezi'**
  String get supportCenter;

  /// No description provided for @newSupportRequest.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Destek Talebi'**
  String get newSupportRequest;

  /// No description provided for @mySupportRequests.
  ///
  /// In tr, this message translates to:
  /// **'Destek Taleplerim'**
  String get mySupportRequests;

  /// No description provided for @supportRequestDetail.
  ///
  /// In tr, this message translates to:
  /// **'Talep Detayı'**
  String get supportRequestDetail;

  /// No description provided for @recoverMyAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı Geri Al'**
  String get recoverMyAccount;

  /// No description provided for @frequentlyAskedQuestions.
  ///
  /// In tr, this message translates to:
  /// **'Sık Sorulan Sorular'**
  String get frequentlyAskedQuestions;

  /// No description provided for @contactUs.
  ///
  /// In tr, this message translates to:
  /// **'Bize Ulaşın'**
  String get contactUs;

  /// No description provided for @supportRequest.
  ///
  /// In tr, this message translates to:
  /// **'Destek Talebi'**
  String get supportRequest;

  /// No description provided for @supportSubject.
  ///
  /// In tr, this message translates to:
  /// **'Konu'**
  String get supportSubject;

  /// No description provided for @supportDescription.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get supportDescription;

  /// No description provided for @supportCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get supportCategory;

  /// No description provided for @supportPriority.
  ///
  /// In tr, this message translates to:
  /// **'Öncelik'**
  String get supportPriority;

  /// No description provided for @supportStatus.
  ///
  /// In tr, this message translates to:
  /// **'Durum'**
  String get supportStatus;

  /// No description provided for @supportAttachments.
  ///
  /// In tr, this message translates to:
  /// **'Ekler'**
  String get supportAttachments;

  /// No description provided for @addAttachment.
  ///
  /// In tr, this message translates to:
  /// **'Dosya Ekle'**
  String get addAttachment;

  /// No description provided for @submitSupportRequest.
  ///
  /// In tr, this message translates to:
  /// **'Destek Talebini Gönder'**
  String get submitSupportRequest;

  /// No description provided for @supportRequestCreated.
  ///
  /// In tr, this message translates to:
  /// **'Destek talebin başarıyla oluşturuldu.'**
  String get supportRequestCreated;

  /// No description provided for @supportRequestCouldNotBeCreated.
  ///
  /// In tr, this message translates to:
  /// **'Destek talebi oluşturulamadı.'**
  String get supportRequestCouldNotBeCreated;

  /// No description provided for @noSupportRequests.
  ///
  /// In tr, this message translates to:
  /// **'Henüz destek talebin yok.'**
  String get noSupportRequests;

  /// No description provided for @supportRequestsCouldNotBeLoaded.
  ///
  /// In tr, this message translates to:
  /// **'Destek talepleri yüklenemedi.'**
  String get supportRequestsCouldNotBeLoaded;

  /// No description provided for @adminReply.
  ///
  /// In tr, this message translates to:
  /// **'Destek Ekibi Yanıtı'**
  String get adminReply;

  /// No description provided for @writeReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtını yaz'**
  String get writeReply;

  /// No description provided for @sendReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıt Gönder'**
  String get sendReply;

  /// No description provided for @openStatus.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get openStatus;

  /// No description provided for @reviewingStatus.
  ///
  /// In tr, this message translates to:
  /// **'İnceleniyor'**
  String get reviewingStatus;

  /// No description provided for @waitingUserStatus.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı Yanıtı Bekleniyor'**
  String get waitingUserStatus;

  /// No description provided for @resolvedStatus.
  ///
  /// In tr, this message translates to:
  /// **'Çözüldü'**
  String get resolvedStatus;

  /// No description provided for @rejectedStatus.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get rejectedStatus;

  /// No description provided for @closedStatus.
  ///
  /// In tr, this message translates to:
  /// **'Kapatıldı'**
  String get closedStatus;

  /// No description provided for @lowPriority.
  ///
  /// In tr, this message translates to:
  /// **'Düşük'**
  String get lowPriority;

  /// No description provided for @normalPriority.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get normalPriority;

  /// No description provided for @highPriority.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek'**
  String get highPriority;

  /// No description provided for @urgentPriority.
  ///
  /// In tr, this message translates to:
  /// **'Acil'**
  String get urgentPriority;

  /// No description provided for @supportSecurityWarning.
  ///
  /// In tr, this message translates to:
  /// **'Güvenliğin için destek ekibi senden SMS doğrulama kodunu veya şifreni istemez.'**
  String get supportSecurityWarning;

  /// No description provided for @accountStatus.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Durumu'**
  String get accountStatus;

  /// No description provided for @accountSuspended.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Askıya Alındı'**
  String get accountSuspended;

  /// No description provided for @accountSuspendedDescription.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın geçici olarak askıya alındı. İnceleme tamamlanana kadar uygulamayı kullanamazsın.'**
  String get accountSuspendedDescription;

  /// No description provided for @accountBanned.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Engellendi'**
  String get accountBanned;

  /// No description provided for @accountBannedDescription.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın kullanım kurallarının ihlali nedeniyle engellendi.'**
  String get accountBannedDescription;

  /// No description provided for @accountDeletionPending.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Silme İşlemi Bekliyor'**
  String get accountDeletionPending;

  /// No description provided for @accountDeletionPendingDescription.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın için silme talebi oluşturulmuş. İşlem tamamlanana kadar uygulamayı kullanamazsın.'**
  String get accountDeletionPendingDescription;

  /// No description provided for @accountDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Silindi'**
  String get accountDeleted;

  /// No description provided for @accountDeletedDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu hesap silinmiş ve artık kullanılamaz.'**
  String get accountDeletedDescription;

  /// No description provided for @contactSupportForAccountStatus.
  ///
  /// In tr, this message translates to:
  /// **'Bu durumun hatalı olduğunu düşünüyorsan destek ekibimize talep gönderebilirsin.'**
  String get contactSupportForAccountStatus;

  /// No description provided for @logoutFailed.
  ///
  /// In tr, this message translates to:
  /// **'Oturum kapatılamadı. İnternet bağlantını kontrol edip tekrar dene.'**
  String get logoutFailed;

  /// No description provided for @createEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik Oluştur'**
  String get createEvent;

  /// No description provided for @eventInformation.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik bilgileri'**
  String get eventInformation;

  /// No description provided for @locationInformation.
  ///
  /// In tr, this message translates to:
  /// **'Konum bilgisi'**
  String get locationInformation;

  /// No description provided for @descriptionSection.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get descriptionSection;

  /// No description provided for @category.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get category;

  /// No description provided for @gameOrSport.
  ///
  /// In tr, this message translates to:
  /// **'Oyun / spor'**
  String get gameOrSport;

  /// No description provided for @searchedPlayer.
  ///
  /// In tr, this message translates to:
  /// **'Aranan oyuncu'**
  String get searchedPlayer;

  /// No description provided for @preferredMemberType.
  ///
  /// In tr, this message translates to:
  /// **'Tercih edilen üye tipi'**
  String get preferredMemberType;

  /// No description provided for @neighborhoodStreet.
  ///
  /// In tr, this message translates to:
  /// **'Semt / mahalle / cadde'**
  String get neighborhoodStreet;

  /// No description provided for @eventDetails.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik ayrıntıları'**
  String get eventDetails;

  /// No description provided for @districtsLoading.
  ///
  /// In tr, this message translates to:
  /// **'İlçeler yükleniyor...'**
  String get districtsLoading;

  /// No description provided for @selectFromCityDistricts.
  ///
  /// In tr, this message translates to:
  /// **'{city} ilçelerinden seç'**
  String selectFromCityDistricts(String city);

  /// No description provided for @selectDistrictFirst.
  ///
  /// In tr, this message translates to:
  /// **'Önce ilçe seç'**
  String get selectDistrictFirst;

  /// No description provided for @startTypingNeighborhoodHint.
  ///
  /// In tr, this message translates to:
  /// **'Yazmaya başla: Nişantepe'**
  String get startTypingNeighborhoodHint;

  /// No description provided for @searchDistrictsInCity.
  ///
  /// In tr, this message translates to:
  /// **'{city} ilçelerinde ara'**
  String searchDistrictsInCity(String city);

  /// No description provided for @districtNotFound.
  ///
  /// In tr, this message translates to:
  /// **'İlçe bulunamadı.'**
  String get districtNotFound;

  /// No description provided for @profileInfoLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil bilgisi yüklenemedi: {error}'**
  String profileInfoLoadFailed(String error);

  /// No description provided for @districtsLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'İlçeler yüklenemedi. İnternet bağlantını kontrol et.'**
  String get districtsLoadFailed;

  /// No description provided for @enableLocationServices.
  ///
  /// In tr, this message translates to:
  /// **'Telefonun konum servisini açmalısın.'**
  String get enableLocationServices;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni verilmedi. Haritadan elle seçim yapabilirsin.'**
  String get locationPermissionDenied;

  /// No description provided for @locationOutsideActiveCity.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğin konum {city} dışında görünüyor. Ana ekrandan aktif şehri değiştirip tekrar dene.'**
  String locationOutsideActiveCity(String city);

  /// No description provided for @locationSelectedCompleteAddress.
  ///
  /// In tr, this message translates to:
  /// **'Konum seçildi. Adres servisinin bulamadığı alanı listeden tamamlayabilirsin.'**
  String get locationSelectedCompleteAddress;

  /// No description provided for @mapCouldNotOpen.
  ///
  /// In tr, this message translates to:
  /// **'Harita açılamadı: {error}'**
  String mapCouldNotOpen(String error);

  /// No description provided for @cannotSelectPastDateTime.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş tarih ve saat seçemezsin.'**
  String get cannotSelectPastDateTime;

  /// No description provided for @eventDurationMinOneHour.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik süresi en az 1 saat olmalıdır.'**
  String get eventDurationMinOneHour;

  /// No description provided for @eventDurationMaxSixHours.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik süresi en fazla 6 saat olabilir.'**
  String get eventDurationMaxSixHours;

  /// No description provided for @eventDurationThirtyMinuteSteps.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç ve bitiş saatleri 30 dakikalık aralıklarla seçilmelidir.'**
  String get eventDurationThirtyMinuteSteps;

  /// No description provided for @plusRequiredForMultiplePlayers.
  ///
  /// In tr, this message translates to:
  /// **'2 veya daha fazla oyuncu için Plus üyelik gerekir.'**
  String get plusRequiredForMultiplePlayers;

  /// No description provided for @normalMembersTomorrowOnly.
  ///
  /// In tr, this message translates to:
  /// **'Normal üyeler en fazla yarın için etkinlik oluşturabilir.'**
  String get normalMembersTomorrowOnly;

  /// No description provided for @sessionNotFoundPleaseLogin.
  ///
  /// In tr, this message translates to:
  /// **'Oturum bulunamadı. Yeniden giriş yapmalısın.'**
  String get sessionNotFoundPleaseLogin;

  /// No description provided for @addressNotFoundOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Adres haritada bulunamadı. Mahalle, cadde veya mekan adını daha açık yaz ya da haritadan seç.'**
  String get addressNotFoundOnMap;

  /// No description provided for @eventCreateFailedWithCode.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik oluşturulamadı ({code}): {message}'**
  String eventCreateFailedWithCode(String code, String message);

  /// No description provided for @eventCreateFailed.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik oluşturulamadı: {error}'**
  String eventCreateFailed(String error);

  /// No description provided for @myLocation.
  ///
  /// In tr, this message translates to:
  /// **'Konumum'**
  String get myLocation;

  /// No description provided for @searchOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritada ara'**
  String get searchOnMap;

  /// No description provided for @publishEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği yayınla'**
  String get publishEvent;

  /// No description provided for @livePriceSummary.
  ///
  /// In tr, this message translates to:
  /// **'Canlı fiyat özeti'**
  String get livePriceSummary;

  /// No description provided for @duration.
  ///
  /// In tr, this message translates to:
  /// **'Süre'**
  String get duration;

  /// No description provided for @durationFactor.
  ///
  /// In tr, this message translates to:
  /// **'Süre katsayısı'**
  String get durationFactor;

  /// No description provided for @basePricePerPlayer.
  ///
  /// In tr, this message translates to:
  /// **'Kişi başı taban fiyat'**
  String get basePricePerPlayer;

  /// No description provided for @totalFee.
  ///
  /// In tr, this message translates to:
  /// **'Toplam ücret'**
  String get totalFee;

  /// No description provided for @durationRangeHint.
  ///
  /// In tr, this message translates to:
  /// **'Süre 1 ile 6 saat arasında ve 30 dakikalık aralıklarla olmalıdır.'**
  String get durationRangeHint;

  /// No description provided for @plusMemberBenefits.
  ///
  /// In tr, this message translates to:
  /// **'Plus üye: Birden fazla oyuncu ve ileri tarih seçebilirsin.'**
  String get plusMemberBenefits;

  /// No description provided for @normalMemberLimits.
  ///
  /// In tr, this message translates to:
  /// **'Normal üye: 1 oyuncu ve en fazla yarın için etkinlik oluşturabilirsin.'**
  String get normalMemberLimits;

  /// No description provided for @startTimeLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç {time}'**
  String startTimeLabel(String time);

  /// No description provided for @endTimeLabel.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş {time}'**
  String endTimeLabel(String time);

  /// No description provided for @activeCity.
  ///
  /// In tr, this message translates to:
  /// **'Aktif şehir'**
  String get activeCity;

  /// No description provided for @mapSelectionOptional.
  ///
  /// In tr, this message translates to:
  /// **'Haritadan seçim zorunlu değildir.'**
  String get mapSelectionOptional;

  /// No description provided for @meetingPointSelected.
  ///
  /// In tr, this message translates to:
  /// **'Buluşma noktası seçildi; ilçe ve semt otomatik dolduruldu.'**
  String get meetingPointSelected;

  /// No description provided for @mustSelectDistrict.
  ///
  /// In tr, this message translates to:
  /// **'İlçe seçmelisin'**
  String get mustSelectDistrict;

  /// No description provided for @neighborhoodRequired.
  ///
  /// In tr, this message translates to:
  /// **'Semt / mahalle bilgisi gerekli'**
  String get neighborhoodRequired;

  /// No description provided for @durationHours.
  ///
  /// In tr, this message translates to:
  /// **'{count} saat'**
  String durationHours(int count);

  /// No description provided for @durationMinutesOnly.
  ///
  /// In tr, this message translates to:
  /// **'{count} dakika'**
  String durationMinutesOnly(int count);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat {minutes} dakika'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @currencyAmount.
  ///
  /// In tr, this message translates to:
  /// **'{amount} TL'**
  String currencyAmount(String amount);

  /// No description provided for @notificationsSection.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notificationsSection;

  /// No description provided for @messageNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj bildirimleri'**
  String get messageNotifications;

  /// No description provided for @eventNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik bildirimleri'**
  String get eventNotifications;

  /// No description provided for @applicationNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru bildirimleri'**
  String get applicationNotifications;

  /// No description provided for @campaignNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya bildirimleri'**
  String get campaignNotifications;

  /// No description provided for @documents.
  ///
  /// In tr, this message translates to:
  /// **'Belgeler'**
  String get documents;

  /// No description provided for @termsOfUse.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get privacyPolicy;

  /// No description provided for @communityRules.
  ///
  /// In tr, this message translates to:
  /// **'Topluluk Kuralları'**
  String get communityRules;

  /// No description provided for @account.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get account;

  /// No description provided for @changePhoneNumber.
  ///
  /// In tr, this message translates to:
  /// **'Telefon numarasını değiştir'**
  String get changePhoneNumber;

  /// No description provided for @changePhoneNumberDescription.
  ///
  /// In tr, this message translates to:
  /// **'Yeni telefon numaranı SMS koduyla doğrula.'**
  String get changePhoneNumberDescription;

  /// No description provided for @createAccountDeletionRequest.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silme talebi oluştur'**
  String get createAccountDeletionRequest;

  /// No description provided for @accountDeletionRequestDescription.
  ///
  /// In tr, this message translates to:
  /// **'Talep sonrası oturumun kapanır ve hesabın incelemeye alınır.'**
  String get accountDeletionRequestDescription;

  /// No description provided for @loginRequiredForAccountDeletion.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silme talebi oluşturmak için giriş yapmalısın.'**
  String get loginRequiredForAccountDeletion;

  /// No description provided for @accountDeletionRequestTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silme talebi'**
  String get accountDeletionRequestTitle;

  /// No description provided for @accountDeletionFirstConfirmation.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın hemen silinmez. Silme talebin kaydedilir ve işlem tamamlanana kadar hesabını kullanamazsın.'**
  String get accountDeletionFirstConfirmation;

  /// No description provided for @giveUp.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get giveUp;

  /// No description provided for @continueAction.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get continueAction;

  /// No description provided for @finalConfirmation.
  ///
  /// In tr, this message translates to:
  /// **'Son onay'**
  String get finalConfirmation;

  /// No description provided for @accountDeletionFinalConfirmation.
  ///
  /// In tr, this message translates to:
  /// **'Silme talebi oluşturulduktan sonra oturumun kapatılacak ve işlem tamamlanana kadar uygulamaya erişemeyeceksin.'**
  String get accountDeletionFinalConfirmation;

  /// No description provided for @createRequest.
  ///
  /// In tr, this message translates to:
  /// **'Talebi oluştur'**
  String get createRequest;

  /// No description provided for @accountDeletionRequestCouldNotBeCreated.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silme talebi oluşturulamadı.'**
  String get accountDeletionRequestCouldNotBeCreated;

  /// No description provided for @legalTermsBody.
  ///
  /// In tr, this message translates to:
  /// **'Dördüncü, kullanıcıların spor ve oyun etkinlikleri oluşturmasına ve bu etkinliklere katılmasına yardımcı olur. Kullanıcılar verdikleri bilgilerin doğruluğundan, etkinliklerdeki davranışlarından ve yürürlükteki kurallara uymaktan sorumludur. Ödeme ve cüzdan özellikleri etkinleştirilmeden önce ayrıca üyelik ve ödeme koşulları sunulacaktır.'**
  String get legalTermsBody;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In tr, this message translates to:
  /// **'Profil bilgileri, seçilen oyunlar, etkinlikler ve uygulama içi iletişim hizmeti sunmak amacıyla işlenir. Kimlik ve doğrulama belgeleri yalnızca doğrulama süreci için kullanılmalı; erişim kuralları ve saklama süreleri üretim öncesinde ayrıca yapılandırılmalıdır. Kullanıcı hesap silme talebinde bulunabilir.'**
  String get privacyPolicyBody;

  /// No description provided for @communityRulesBody.
  ///
  /// In tr, this message translates to:
  /// **'Saygılı ol. Taciz, tehdit, ayrımcılık, dolandırıcılık ve yanıltıcı etkinlikler yasaktır. Katılamayacağın etkinliğe başvurma; iptal gerektiğinde organizatöre zamanında haber ver. Güvenlik riski oluşturan kullanıcıları destek kanalına bildir.'**
  String get communityRulesBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
