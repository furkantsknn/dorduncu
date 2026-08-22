// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Dördüncü';

  @override
  String get loading => 'Wird geladen...';

  @override
  String get pleaseWait => 'Bitte warten...';

  @override
  String get continueButton => 'Weiter';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get select => 'Auswählen';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get send => 'Senden';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get back => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get skip => 'Überspringen';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get ok => 'OK';

  @override
  String get search => 'Suchen';

  @override
  String get all => 'Alle';

  @override
  String get optional => 'Optional';

  @override
  String get requiredField => 'Dieses Feld ist erforderlich.';

  @override
  String get unknownError => 'Ein unerwarteter Fehler ist aufgetreten.';

  @override
  String get connectionError => 'Verbindungsfehler';

  @override
  String get checkInternetConnection =>
      'Überprüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get operationFailed => 'Vorgang konnte nicht abgeschlossen werden.';

  @override
  String get operationSuccessful => 'Vorgang erfolgreich abgeschlossen.';

  @override
  String get login => 'Anmelden';

  @override
  String get logout => 'Abmelden';

  @override
  String get loggingOut => 'Abmeldung läuft...';

  @override
  String get logoutAccount => 'Abmelden';

  @override
  String get phoneNumber => 'Telefonnummer';

  @override
  String get phoneNumberHint => '5XX XXX XX XX';

  @override
  String get phoneNumberRequired => 'Gib deine Telefonnummer ein.';

  @override
  String get invalidPhoneNumber => 'Gib eine gültige Telefonnummer ein.';

  @override
  String get sendSmsCode => 'SMS-Code senden';

  @override
  String get smsVerification => 'SMS-Bestätigung';

  @override
  String get verificationCode => 'Bestätigungscode';

  @override
  String get verificationCodeHint => '6-stelliger Code';

  @override
  String get verificationCodeRequired => 'Gib den Bestätigungscode ein.';

  @override
  String get invalidVerificationCode => 'Der Bestätigungscode ist falsch.';

  @override
  String get expiredVerificationCode => 'Der Bestätigungscode ist abgelaufen.';

  @override
  String get verify => 'Bestätigen';

  @override
  String get resendCode => 'Code erneut senden';

  @override
  String resendCodeAfter(int seconds) {
    return 'In $seconds Sekunden erneut senden';
  }

  @override
  String get smsCodeSent =>
      'Der Bestätigungscode wurde an dein Telefon gesendet.';

  @override
  String get smsCodeCouldNotBeSent =>
      'Der Bestätigungscode konnte nicht gesendet werden.';

  @override
  String get verificationFailed =>
      'Die Telefonbestätigung konnte nicht abgeschlossen werden.';

  @override
  String get tooManyRequests =>
      'Du hast zu viele Versuche unternommen. Bitte versuche es später erneut.';

  @override
  String get sessionNotFound => 'Die Benutzersitzung wurde nicht gefunden.';

  @override
  String get sessionEnded => 'Sitzung beendet';

  @override
  String get sessionEndedOnAnotherDevice =>
      'Deine Sitzung auf diesem Gerät wurde beendet, weil dein Konto auf einem anderen Gerät geöffnet wurde.';

  @override
  String get createProfile => 'Profil erstellen';

  @override
  String get profile => 'Profil';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get profileInformation => 'Profilinformationen';

  @override
  String get profilePhoto => 'Profilfoto';

  @override
  String get profilePhotoOptional => 'Das Profilfoto ist optional';

  @override
  String get selectProfilePhoto => 'Profilfoto auswählen';

  @override
  String get profilePhotoCouldNotBeSelected =>
      'Das Profilfoto konnte nicht ausgewählt werden.';

  @override
  String get selectAvatar => '3D-Avatar auswählen';

  @override
  String get name => 'Vorname';

  @override
  String get surname => 'Nachname';

  @override
  String get birthDate => 'Geburtsdatum';

  @override
  String get selectBirthDate => 'Geburtsdatum auswählen';

  @override
  String get gender => 'Geschlecht';

  @override
  String get female => 'Weiblich';

  @override
  String get male => 'Männlich';

  @override
  String get other => 'Andere';

  @override
  String get city => 'Stadt';

  @override
  String get district => 'Bezirk';

  @override
  String get aboutMe => 'Über mich';

  @override
  String get aboutMeOptional => 'Über mich (optional)';

  @override
  String get enterName => 'Gib deinen Vornamen ein.';

  @override
  String get enterSurname => 'Gib deinen Nachnamen ein.';

  @override
  String get enterCity => 'Gib deine Stadt ein.';

  @override
  String get enterDistrict => 'Gib deinen Bezirk ein.';

  @override
  String get selectGender => 'Wähle dein Geschlecht aus.';

  @override
  String get minimumAgeRequired =>
      'Du musst mindestens 18 Jahre alt sein, um dich zu registrieren.';

  @override
  String get minimumAgeRegistrationMessage =>
      'Nur Personen ab 18 Jahren können sich bei Dördüncü registrieren.';

  @override
  String get profileCreated => 'Dein Profil wurde erfolgreich erstellt.';

  @override
  String profileCreationFailed(String error) {
    return 'Beim Erstellen des Profils ist ein Fehler aufgetreten: $error';
  }

  @override
  String get playerVerification => 'Spielerverifizierung';

  @override
  String get verificationStatus => 'Mein Verifizierungsstatus';

  @override
  String get verifiedAccount => 'Dein Konto ist verifiziert.';

  @override
  String get verificationPending =>
      'Deine Dokumente werden geprüft. Das Ergebnis wird in deinem Konto angezeigt.';

  @override
  String get verificationRejected =>
      'Dein Verifizierungsantrag wurde abgelehnt. Du kannst deine Dokumente später erneut einreichen.';

  @override
  String get verificationNotCompleted =>
      'Du hast die Spielerverifizierung noch nicht abgeschlossen.';

  @override
  String get verificationOptionalDescription =>
      'Dieser Schritt ist optional. Nach der Genehmigung deiner Dokumente erhältst du ein Verifiziert-Abzeichen.';

  @override
  String get identityFront => 'Vorderseite des Ausweises';

  @override
  String get identityBack => 'Rückseite des Ausweises';

  @override
  String get takeSelfie => 'Selfie aufnehmen';

  @override
  String get selfieReady => 'Selfie bereit';

  @override
  String get selfieCouldNotBeTaken =>
      'Das Selfie konnte nicht aufgenommen werden.';

  @override
  String get criminalRecordDocument => 'Führungszeugnis';

  @override
  String get selectDocument => 'Tippe, um ein Dokument auszuwählen';

  @override
  String get documentSelectionFailed =>
      'Beim Auswählen des Dokuments ist ein Fehler aufgetreten.';

  @override
  String get selectedFileCouldNotBeAccessed =>
      'Auf die ausgewählte Datei konnte nicht zugegriffen werden.';

  @override
  String get supportedDocumentTypes =>
      'Du kannst PDF-, JPG- oder PNG-Dateien hochladen. Die maximale Dateigröße beträgt 10 MB.';

  @override
  String get uploadDocumentsAndContinue => 'Dokumente hochladen und fortfahren';

  @override
  String get skipForNow => 'Vorerst überspringen';

  @override
  String get requiredVerificationDocuments =>
      'Du musst die Vorder- und Rückseite deines Ausweises, ein Führungszeugnis und ein Selfie hinzufügen.';

  @override
  String documentsUploadFailed(String error) {
    return 'Beim Hochladen der Dokumente ist ein Fehler aufgetreten: $error';
  }

  @override
  String get gamesAndSports => 'Deine Spiele und Sportarten';

  @override
  String get selectGamesAndSportsDescription =>
      'Wähle die Spiele aus, an denen du teilnehmen möchtest, und gib für jedes dein Niveau an.';

  @override
  String get selectAtLeastOneGame =>
      'Wähle mindestens ein Spiel oder eine Sportart aus.';

  @override
  String selectedBranchCount(int count) {
    return 'Ausgewählte Kategorien: $count';
  }

  @override
  String get beginner => 'Anfänger';

  @override
  String get intermediate => 'Mittelstufe';

  @override
  String get advanced => 'Fortgeschritten';

  @override
  String get expert => 'Experte';

  @override
  String get home => 'Startseite';

  @override
  String get events => 'Veranstaltungen';

  @override
  String get event => 'Veranstaltung';

  @override
  String get explore => 'Entdecken';

  @override
  String get exploreOnMap => 'Auf der Karte entdecken';

  @override
  String get exploreEventsOnMap => 'Veranstaltungen auf der Karte entdecken';

  @override
  String get eventsForYou => 'Veranstaltungen für dich';

  @override
  String get seeAll => 'Alle anzeigen';

  @override
  String get showInCity => 'In der Stadt anzeigen';

  @override
  String get nearMe => 'In meiner Nähe';

  @override
  String get whatDoYouWantToPlayToday => 'Was möchtest du heute spielen?';

  @override
  String get eventsCouldNotBeLoaded =>
      'Beim Laden der Veranstaltungen ist ein Fehler aufgetreten.';

  @override
  String get noEventsInCategory =>
      'Für diese Kategorie gibt es noch keine Veranstaltungen.';

  @override
  String get joinEvent => 'An Veranstaltung teilnehmen';

  @override
  String get join => 'Teilnehmen';

  @override
  String get apply => 'Bewerben';

  @override
  String get applied => 'Beworben';

  @override
  String get applicationSent =>
      'Deine Bewerbung wurde an den Veranstalter gesendet.';

  @override
  String get eventApplicationFailed =>
      'Beim Bewerben für die Veranstaltung ist ein Fehler aufgetreten.';

  @override
  String eventApplicationFailedWithError(String error) {
    return 'Beim Bewerben für die Veranstaltung ist ein Fehler aufgetreten: $error';
  }

  @override
  String get loginRequiredForApplication =>
      'Du musst dich anmelden, um dich für eine Veranstaltung zu bewerben.';

  @override
  String get profileRequiredForApplication =>
      'Du musst dein Spielerprofil vervollständigen und das Spielerabzeichen erhalten, bevor du dich für Veranstaltungen bewerben kannst.';

  @override
  String get eventOwner => 'Veranstalter';

  @override
  String get eventCreatedByYou => 'Du hast diese Veranstaltung erstellt';

  @override
  String get joinedEvent => 'Du nimmst an der Veranstaltung teil';

  @override
  String participantCount(int count) {
    return 'Teilnehmende Spieler: $count';
  }

  @override
  String get favorites => 'Favoriten';

  @override
  String get addToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get removeFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get removedFromFavorites => 'Aus den Favoriten entfernt.';

  @override
  String get noFavoriteEvents =>
      'Du hast noch keine favorisierten Veranstaltungen.';

  @override
  String get favoritesCouldNotBeLoaded =>
      'Favoriten konnten nicht geladen werden.';

  @override
  String get messages => 'Nachrichten';

  @override
  String get message => 'Nachricht';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notification => 'Benachrichtigung';

  @override
  String get notificationCenter => 'Benachrichtigungszentrum';

  @override
  String get noNotifications => 'Du hast noch keine Benachrichtigungen.';

  @override
  String get notificationsCouldNotBeLoaded =>
      'Benachrichtigungen konnten nicht geladen werden.';

  @override
  String get markAsRead => 'Als gelesen markieren';

  @override
  String get markAsUnread => 'Als ungelesen markieren';

  @override
  String get deleteNotification => 'Benachrichtigung löschen';

  @override
  String get wallet => 'Wallet';

  @override
  String get settings => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get turkish => 'Türkisch';

  @override
  String get english => 'Englisch';

  @override
  String get german => 'Deutsch';

  @override
  String get theme => 'Design';

  @override
  String get darkTheme => 'Dunkles Design';

  @override
  String get lightTheme => 'Helles Design';

  @override
  String get systemTheme => 'Systemdesign';

  @override
  String get support => 'Support';

  @override
  String get supportCenter => 'Support-Center';

  @override
  String get newSupportRequest => 'Neue Supportanfrage';

  @override
  String get mySupportRequests => 'Meine Supportanfragen';

  @override
  String get supportRequestDetail => 'Anfragedetails';

  @override
  String get recoverMyAccount => 'Mein Konto wiederherstellen';

  @override
  String get frequentlyAskedQuestions => 'Häufig gestellte Fragen';

  @override
  String get contactUs => 'Kontaktiere uns';

  @override
  String get supportRequest => 'Supportanfrage';

  @override
  String get supportSubject => 'Betreff';

  @override
  String get supportDescription => 'Beschreibung';

  @override
  String get supportCategory => 'Kategorie';

  @override
  String get supportPriority => 'Priorität';

  @override
  String get supportStatus => 'Status';

  @override
  String get supportAttachments => 'Anhänge';

  @override
  String get addAttachment => 'Datei hinzufügen';

  @override
  String get submitSupportRequest => 'Supportanfrage senden';

  @override
  String get supportRequestCreated =>
      'Deine Supportanfrage wurde erfolgreich erstellt.';

  @override
  String get supportRequestCouldNotBeCreated =>
      'Die Supportanfrage konnte nicht erstellt werden.';

  @override
  String get noSupportRequests => 'Du hast noch keine Supportanfragen.';

  @override
  String get supportRequestsCouldNotBeLoaded =>
      'Supportanfragen konnten nicht geladen werden.';

  @override
  String get adminReply => 'Antwort des Support-Teams';

  @override
  String get writeReply => 'Antwort schreiben';

  @override
  String get sendReply => 'Antwort senden';

  @override
  String get openStatus => 'Offen';

  @override
  String get reviewingStatus => 'Wird geprüft';

  @override
  String get waitingUserStatus => 'Wartet auf Benutzerantwort';

  @override
  String get resolvedStatus => 'Gelöst';

  @override
  String get rejectedStatus => 'Abgelehnt';

  @override
  String get closedStatus => 'Geschlossen';

  @override
  String get lowPriority => 'Niedrig';

  @override
  String get normalPriority => 'Normal';

  @override
  String get highPriority => 'Hoch';

  @override
  String get urgentPriority => 'Dringend';

  @override
  String get supportSecurityWarning =>
      'Zu deiner Sicherheit wird das Support-Team niemals nach deinem SMS-Bestätigungscode oder Passwort fragen.';

  @override
  String get accountStatus => 'Kontostatus';

  @override
  String get accountSuspended => 'Konto gesperrt';

  @override
  String get accountSuspendedDescription =>
      'Dein Konto wurde vorübergehend gesperrt. Bis zum Abschluss der Prüfung kannst du die Anwendung nicht verwenden.';

  @override
  String get accountBanned => 'Konto blockiert';

  @override
  String get accountBannedDescription =>
      'Dein Konto wurde wegen eines Verstoßes gegen die Nutzungsbedingungen blockiert.';

  @override
  String get accountDeletionPending => 'Kontolöschung ausstehend';

  @override
  String get accountDeletionPendingDescription =>
      'Für dein Konto wurde ein Löschantrag erstellt. Bis zum Abschluss des Vorgangs kannst du die Anwendung nicht verwenden.';

  @override
  String get accountDeleted => 'Konto gelöscht';

  @override
  String get accountDeletedDescription =>
      'Dieses Konto wurde gelöscht und kann nicht mehr verwendet werden.';

  @override
  String get contactSupportForAccountStatus =>
      'Wenn du glaubst, dass dies ein Fehler ist, kannst du eine Anfrage an unser Support-Team senden.';

  @override
  String get logoutFailed =>
      'Abmeldung fehlgeschlagen. Überprüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get createEvent => 'Event erstellen';

  @override
  String get eventInformation => 'Eventinformationen';

  @override
  String get locationInformation => 'Standortinformationen';

  @override
  String get descriptionSection => 'Beschreibung';

  @override
  String get category => 'Kategorie';

  @override
  String get gameOrSport => 'Spiel / Sport';

  @override
  String get searchedPlayer => 'Gesuchte Spieler';

  @override
  String get preferredMemberType => 'Bevorzugter Mitgliedstyp';

  @override
  String get neighborhoodStreet => 'Stadtteil / Viertel / Straße';

  @override
  String get eventDetails => 'Eventdetails';

  @override
  String get districtsLoading => 'Bezirke werden geladen...';

  @override
  String selectFromCityDistricts(String city) {
    return 'Aus Bezirken von $city wählen';
  }

  @override
  String get selectDistrictFirst => 'Zuerst Bezirk wählen';

  @override
  String get startTypingNeighborhoodHint => 'Tippe los: Nişantepe';

  @override
  String searchDistrictsInCity(String city) {
    return 'Bezirke in $city suchen';
  }

  @override
  String get districtNotFound => 'Bezirk nicht gefunden.';

  @override
  String profileInfoLoadFailed(String error) {
    return 'Profilinformationen konnten nicht geladen werden: $error';
  }

  @override
  String get districtsLoadFailed =>
      'Bezirke konnten nicht geladen werden. Überprüfe deine Internetverbindung.';

  @override
  String get enableLocationServices =>
      'Du musst die Ortungsdienste deines Telefons aktivieren.';

  @override
  String get locationPermissionDenied =>
      'Standortberechtigung wurde verweigert. Du kannst manuell auf der Karte auswählen.';

  @override
  String locationOutsideActiveCity(String city) {
    return 'Der ausgewählte Standort scheint außerhalb von $city zu liegen. Ändere deine aktive Stadt auf dem Startbildschirm und versuche es erneut.';
  }

  @override
  String get locationSelectedCompleteAddress =>
      'Standort ausgewählt. Fehlende Felder kannst du aus der Liste ergänzen.';

  @override
  String mapCouldNotOpen(String error) {
    return 'Karte konnte nicht geöffnet werden: $error';
  }

  @override
  String get cannotSelectPastDateTime =>
      'Du kannst kein vergangenes Datum und keine vergangene Uhrzeit wählen.';

  @override
  String get eventDurationMinOneHour =>
      'Die Eventdauer muss mindestens 1 Stunde betragen.';

  @override
  String get eventDurationMaxSixHours =>
      'Die Eventdauer darf höchstens 6 Stunden betragen.';

  @override
  String get eventDurationThirtyMinuteSteps =>
      'Start- und Endzeiten müssen in 30-Minuten-Intervallen gewählt werden.';

  @override
  String get plusRequiredForMultiplePlayers =>
      'Für 2 oder mehr Spieler ist eine Plus-Mitgliedschaft erforderlich.';

  @override
  String get normalMembersTomorrowOnly =>
      'Normale Mitglieder können Events höchstens für morgen erstellen.';

  @override
  String get sessionNotFoundPleaseLogin =>
      'Sitzung nicht gefunden. Du musst dich erneut anmelden.';

  @override
  String get addressNotFoundOnMap =>
      'Adresse konnte auf der Karte nicht gefunden werden. Schreibe den Stadtteil, die Straße oder den Ortsnamen klarer oder wähle auf der Karte aus.';

  @override
  String eventCreateFailedWithCode(String code, String message) {
    return 'Event konnte nicht erstellt werden ($code): $message';
  }

  @override
  String eventCreateFailed(String error) {
    return 'Event konnte nicht erstellt werden: $error';
  }

  @override
  String get myLocation => 'Mein Standort';

  @override
  String get searchOnMap => 'Auf Karte suchen';

  @override
  String get publishEvent => 'Event veröffentlichen';

  @override
  String get livePriceSummary => 'Live-Preisübersicht';

  @override
  String get duration => 'Dauer';

  @override
  String get durationFactor => 'Dauerfaktor';

  @override
  String get basePricePerPlayer => 'Grundpreis pro Person';

  @override
  String get totalFee => 'Gesamtgebühr';

  @override
  String get durationRangeHint =>
      'Die Dauer muss zwischen 1 und 6 Stunden in 30-Minuten-Intervallen liegen.';

  @override
  String get plusMemberBenefits =>
      'Plus-Mitglied: Du kannst mehrere Spieler und zukünftige Termine wählen.';

  @override
  String get normalMemberLimits =>
      'Normales Mitglied: Du kannst ein Event für 1 Spieler und höchstens morgen erstellen.';

  @override
  String startTimeLabel(String time) {
    return 'Start $time';
  }

  @override
  String endTimeLabel(String time) {
    return 'Ende $time';
  }

  @override
  String get activeCity => 'Aktive Stadt';

  @override
  String get mapSelectionOptional =>
      'Eine Auswahl auf der Karte ist nicht erforderlich.';

  @override
  String get meetingPointSelected =>
      'Treffpunkt ausgewählt; Bezirk und Stadtteil wurden automatisch ausgefüllt.';

  @override
  String get mustSelectDistrict => 'Du musst einen Bezirk wählen';

  @override
  String get neighborhoodRequired =>
      'Stadtteil- / Viertelinformationen sind erforderlich';

  @override
  String durationHours(int count) {
    return '$count Stunden';
  }

  @override
  String durationMinutesOnly(int count) {
    return '$count Minuten';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours Stunden $minutes Minuten';
  }

  @override
  String currencyAmount(String amount) {
    return '$amount TL';
  }

  @override
  String get notificationsSection => 'Benachrichtigungen';

  @override
  String get messageNotifications => 'Nachrichtenbenachrichtigungen';

  @override
  String get eventNotifications => 'Veranstaltungsbenachrichtigungen';

  @override
  String get applicationNotifications => 'Bewerbungsbenachrichtigungen';

  @override
  String get campaignNotifications => 'Kampagnenbenachrichtigungen';

  @override
  String get documents => 'Dokumente';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get communityRules => 'Community-Regeln';

  @override
  String get account => 'Konto';

  @override
  String get changePhoneNumber => 'Telefonnummer ändern';

  @override
  String get changePhoneNumberDescription =>
      'Bestätige deine neue Telefonnummer mit einem SMS-Code.';

  @override
  String get createAccountDeletionRequest => 'Kontolöschantrag erstellen';

  @override
  String get accountDeletionRequestDescription =>
      'Nach dem Antrag wirst du abgemeldet und dein Konto wird geprüft.';

  @override
  String get loginRequiredForAccountDeletion =>
      'Du musst angemeldet sein, um einen Kontolöschantrag zu erstellen.';

  @override
  String get accountDeletionRequestTitle => 'Kontolöschantrag';

  @override
  String get accountDeletionFirstConfirmation =>
      'Dein Konto wird nicht sofort gelöscht. Dein Antrag wird gespeichert und du kannst dein Konto bis zum Abschluss des Vorgangs nicht verwenden.';

  @override
  String get giveUp => 'Abbrechen';

  @override
  String get continueAction => 'Weiter';

  @override
  String get finalConfirmation => 'Letzte Bestätigung';

  @override
  String get accountDeletionFinalConfirmation =>
      'Nach Erstellung des Löschantrags wirst du abgemeldet und kannst bis zum Abschluss des Vorgangs nicht auf die App zugreifen.';

  @override
  String get createRequest => 'Antrag erstellen';

  @override
  String get accountDeletionRequestCouldNotBeCreated =>
      'Der Kontolöschantrag konnte nicht erstellt werden.';

  @override
  String get legalTermsBody =>
      'Dördüncü hilft Nutzern, Sport- und Spieleveranstaltungen zu erstellen und daran teilzunehmen. Die Nutzer sind für die Richtigkeit ihrer Angaben, ihr Verhalten bei Veranstaltungen und die Einhaltung der geltenden Regeln verantwortlich. Bevor Zahlungs- und Wallet-Funktionen aktiviert werden, werden separate Mitgliedschafts- und Zahlungsbedingungen bereitgestellt.';

  @override
  String get privacyPolicyBody =>
      'Profilinformationen, ausgewählte Spiele, Veranstaltungen und die In-App-Kommunikation werden zur Bereitstellung des Dienstes verarbeitet. Identitäts- und Verifizierungsdokumente dürfen nur für den Verifizierungsprozess verwendet werden; Zugriffsregeln und Aufbewahrungsfristen müssen vor dem Produktivbetrieb separat konfiguriert werden. Nutzer können die Löschung ihres Kontos beantragen.';

  @override
  String get communityRulesBody =>
      'Sei respektvoll. Belästigung, Drohungen, Diskriminierung, Betrug und irreführende Veranstaltungen sind verboten. Bewirb dich nicht für Veranstaltungen, an denen du nicht teilnehmen kannst; informiere den Veranstalter rechtzeitig, wenn du absagen musst. Melde Nutzer, die ein Sicherheitsrisiko darstellen, über den Support-Kanal.';
}
