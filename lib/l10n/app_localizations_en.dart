// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Dört.';

  @override
  String get loading => 'Loading...';

  @override
  String get pleaseWait => 'Please wait...';

  @override
  String get continueButton => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get select => 'Select';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get send => 'Send';

  @override
  String get retry => 'Try Again';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get ok => 'OK';

  @override
  String get search => 'Search';

  @override
  String get all => 'All';

  @override
  String get optional => 'Optional';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get unknownError => 'An unexpected error occurred.';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get checkInternetConnection =>
      'Check your internet connection and try again.';

  @override
  String get operationFailed => 'The operation could not be completed.';

  @override
  String get operationSuccessful => 'The operation was completed successfully.';

  @override
  String get login => 'Log In';

  @override
  String get logout => 'Log Out';

  @override
  String get loggingOut => 'Logging Out...';

  @override
  String get logoutAccount => 'Log Out';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneNumberHint => '5XX XXX XX XX';

  @override
  String get phoneNumberRequired => 'Enter your phone number.';

  @override
  String get invalidPhoneNumber => 'Enter a valid phone number.';

  @override
  String get sendSmsCode => 'Send SMS Code';

  @override
  String get smsVerification => 'SMS Verification';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String get verificationCodeHint => '6-digit code';

  @override
  String get verificationCodeRequired => 'Enter the verification code.';

  @override
  String get invalidVerificationCode => 'The verification code is incorrect.';

  @override
  String get expiredVerificationCode => 'The verification code has expired.';

  @override
  String get verify => 'Verify';

  @override
  String get resendCode => 'Resend Code';

  @override
  String resendCodeAfter(int seconds) {
    return 'Resend in $seconds seconds';
  }

  @override
  String get smsCodeSent => 'The verification code was sent to your phone.';

  @override
  String get smsCodeCouldNotBeSent =>
      'The verification code could not be sent.';

  @override
  String get verificationFailed => 'Phone verification could not be completed.';

  @override
  String get tooManyRequests =>
      'You have made too many attempts. Please try again later.';

  @override
  String get sessionNotFound => 'User session could not be found.';

  @override
  String get sessionEnded => 'Session Ended';

  @override
  String get sessionEndedOnAnotherDevice =>
      'Your session on this device ended because your account was opened on another device.';

  @override
  String get createProfile => 'Create Profile';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get profileInformation => 'Profile Information';

  @override
  String get profilePhoto => 'Profile Photo';

  @override
  String get profilePhotoOptional => 'Profile photo is optional';

  @override
  String get selectProfilePhoto => 'Select Profile Photo';

  @override
  String get profilePhotoCouldNotBeSelected =>
      'The profile photo could not be selected.';

  @override
  String get selectAvatar => 'Select a 3D avatar';

  @override
  String get name => 'First Name';

  @override
  String get surname => 'Last Name';

  @override
  String get birthDate => 'Date of Birth';

  @override
  String get selectBirthDate => 'Select your date of birth';

  @override
  String get gender => 'Gender';

  @override
  String get female => 'Female';

  @override
  String get male => 'Male';

  @override
  String get other => 'Other';

  @override
  String get city => 'City';

  @override
  String get district => 'District';

  @override
  String get aboutMe => 'About Me';

  @override
  String get aboutMeOptional => 'About Me (optional)';

  @override
  String get enterName => 'Enter your first name.';

  @override
  String get enterSurname => 'Enter your last name.';

  @override
  String get enterCity => 'Enter your city.';

  @override
  String get enterDistrict => 'Enter your district.';

  @override
  String get selectGender => 'Select your gender.';

  @override
  String get minimumAgeRequired =>
      'You must be at least 18 years old to register.';

  @override
  String get minimumAgeRegistrationMessage =>
      'Only people who are at least 18 years old can register for Dört.';

  @override
  String get profileCreated => 'Your profile was created successfully.';

  @override
  String profileCreationFailed(String error) {
    return 'An error occurred while creating the profile: $error';
  }

  @override
  String get playerVerification => 'Player Verification';

  @override
  String get verificationStatus => 'My Verification Status';

  @override
  String get verifiedAccount => 'Your account is verified.';

  @override
  String get verificationPending =>
      'Your documents are being reviewed. The result will be shown in your account.';

  @override
  String get verificationRejected =>
      'Your verification application was rejected. You can submit your documents again later.';

  @override
  String get verificationNotCompleted =>
      'You have not completed player verification yet.';

  @override
  String get verificationOptionalDescription =>
      'This step is optional. Once your documents are approved, you will receive a verified player badge.';

  @override
  String get identityFront => 'Front of ID';

  @override
  String get identityBack => 'Back of ID';

  @override
  String get takeSelfie => 'Take a Selfie';

  @override
  String get selfieReady => 'Selfie ready';

  @override
  String get selfieCouldNotBeTaken => 'The selfie could not be taken.';

  @override
  String get criminalRecordDocument => 'Criminal Record Document';

  @override
  String get selectDocument => 'Tap to select a document';

  @override
  String get documentSelectionFailed =>
      'An error occurred while selecting the document.';

  @override
  String get selectedFileCouldNotBeAccessed =>
      'The selected file could not be accessed.';

  @override
  String get supportedDocumentTypes =>
      'You can upload PDF, JPG or PNG files. The maximum file size is 10 MB.';

  @override
  String get uploadDocumentsAndContinue => 'Upload Documents and Continue';

  @override
  String get skipForNow => 'Skip for Now';

  @override
  String get requiredVerificationDocuments =>
      'You must add the front and back of your ID, a criminal record document and a selfie.';

  @override
  String documentsUploadFailed(String error) {
    return 'An error occurred while uploading the documents: $error';
  }

  @override
  String get gamesAndSports => 'Your Games and Sports';

  @override
  String get selectGamesAndSportsDescription =>
      'Select the games you want to join and specify your level for each one.';

  @override
  String get selectAtLeastOneGame => 'Select at least one game or sport.';

  @override
  String selectedBranchCount(int count) {
    return 'Selected categories: $count';
  }

  @override
  String get beginner => 'Beginner';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get advanced => 'Advanced';

  @override
  String get expert => 'Expert';

  @override
  String get home => 'Home';

  @override
  String get events => 'Events';

  @override
  String get event => 'Event';

  @override
  String get explore => 'Explore';

  @override
  String get exploreOnMap => 'Explore on Map';

  @override
  String get exploreEventsOnMap => 'Explore events on the map';

  @override
  String get eventsForYou => 'Events for You';

  @override
  String get seeAll => 'See All';

  @override
  String get showInCity => 'Show in City';

  @override
  String get nearMe => 'Near Me';

  @override
  String get whatDoYouWantToPlayToday => 'What would you like to play today?';

  @override
  String get eventsCouldNotBeLoaded =>
      'An error occurred while loading the events.';

  @override
  String get noEventsInCategory => 'There are no events in this category yet.';

  @override
  String get joinEvent => 'Join Event';

  @override
  String get join => 'Join';

  @override
  String get apply => 'Apply';

  @override
  String get applied => 'Applied';

  @override
  String get applicationSent => 'Your application was sent to the event owner.';

  @override
  String get eventApplicationFailed =>
      'An error occurred while applying for the event.';

  @override
  String eventApplicationFailedWithError(String error) {
    return 'An error occurred while applying for the event: $error';
  }

  @override
  String get loginRequiredForApplication =>
      'You must log in to apply for an event.';

  @override
  String get profileRequiredForApplication =>
      'You must complete your player profile and receive the Player Badge before applying for events.';

  @override
  String get eventOwner => 'Event Owner';

  @override
  String get eventCreatedByYou => 'You Created This Event';

  @override
  String get joinedEvent => 'You Joined the Event';

  @override
  String participantCount(int count) {
    return 'Participating players: $count';
  }

  @override
  String get favorites => 'Favorites';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites.';

  @override
  String get noFavoriteEvents => 'You do not have any favorite events yet.';

  @override
  String get favoritesCouldNotBeLoaded => 'Favorites could not be loaded.';

  @override
  String get messages => 'Messages';

  @override
  String get message => 'Message';

  @override
  String get notifications => 'Notifications';

  @override
  String get notification => 'Notification';

  @override
  String get notificationCenter => 'Notification Center';

  @override
  String get noNotifications => 'You do not have any notifications yet.';

  @override
  String get notificationsCouldNotBeLoaded =>
      'Notifications could not be loaded.';

  @override
  String get markAsRead => 'Mark as Read';

  @override
  String get markAsUnread => 'Mark as Unread';

  @override
  String get deleteNotification => 'Delete Notification';

  @override
  String get wallet => 'Wallet';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get turkish => 'Türkçe';

  @override
  String get english => 'English';

  @override
  String get german => 'Deutsch';

  @override
  String get theme => 'Theme';

  @override
  String get darkTheme => 'Dark Theme';

  @override
  String get lightTheme => 'Light Theme';

  @override
  String get systemTheme => 'System Theme';

  @override
  String get support => 'Support';

  @override
  String get supportCenter => 'Support Center';

  @override
  String get newSupportRequest => 'New Support Request';

  @override
  String get mySupportRequests => 'My Support Requests';

  @override
  String get supportRequestDetail => 'Request Details';

  @override
  String get recoverMyAccount => 'Recover My Account';

  @override
  String get frequentlyAskedQuestions => 'Frequently Asked Questions';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get supportRequest => 'Support Request';

  @override
  String get supportSubject => 'Subject';

  @override
  String get supportDescription => 'Description';

  @override
  String get supportCategory => 'Category';

  @override
  String get supportPriority => 'Priority';

  @override
  String get supportStatus => 'Status';

  @override
  String get supportAttachments => 'Attachments';

  @override
  String get addAttachment => 'Add File';

  @override
  String get submitSupportRequest => 'Submit Support Request';

  @override
  String get supportRequestCreated =>
      'Your support request was created successfully.';

  @override
  String get supportRequestCouldNotBeCreated =>
      'The support request could not be created.';

  @override
  String get noSupportRequests => 'You do not have any support requests yet.';

  @override
  String get supportRequestsCouldNotBeLoaded =>
      'Support requests could not be loaded.';

  @override
  String get adminReply => 'Support Team Reply';

  @override
  String get writeReply => 'Write your reply';

  @override
  String get sendReply => 'Send Reply';

  @override
  String get openStatus => 'Open';

  @override
  String get reviewingStatus => 'Under Review';

  @override
  String get waitingUserStatus => 'Waiting for User Response';

  @override
  String get resolvedStatus => 'Resolved';

  @override
  String get rejectedStatus => 'Rejected';

  @override
  String get closedStatus => 'Closed';

  @override
  String get lowPriority => 'Low';

  @override
  String get normalPriority => 'Normal';

  @override
  String get highPriority => 'High';

  @override
  String get urgentPriority => 'Urgent';

  @override
  String get supportSecurityWarning =>
      'For your security, the support team will never ask for your SMS verification code or password.';

  @override
  String get accountStatus => 'Account Status';

  @override
  String get accountSuspended => 'Account Suspended';

  @override
  String get accountSuspendedDescription =>
      'Your account has been temporarily suspended. You cannot use the application until the review is complete.';

  @override
  String get accountBanned => 'Account Banned';

  @override
  String get accountBannedDescription =>
      'Your account has been banned for violating the terms of use.';

  @override
  String get accountDeletionPending => 'Account Deletion Pending';

  @override
  String get accountDeletionPendingDescription =>
      'A deletion request has been created for your account. You cannot use the application until the process is complete. If you cannot open the app, write to destek@dortapp.com.';

  @override
  String get accountDeleted => 'Account Deleted';

  @override
  String get accountDeletedDescription =>
      'This account has been deleted and can no longer be used.';

  @override
  String get contactSupportForAccountStatus =>
      'If you believe this is a mistake, you can submit a request to our support team.';

  @override
  String get logoutFailed =>
      'Could not log out. Check your internet connection and try again.';

  @override
  String get createEvent => 'Create Event';

  @override
  String get eventInformation => 'Event information';

  @override
  String get locationInformation => 'Location information';

  @override
  String get descriptionSection => 'Description';

  @override
  String get category => 'Category';

  @override
  String get gameOrSport => 'Game / sport';

  @override
  String get searchedPlayer => 'Players wanted';

  @override
  String get preferredMemberType => 'Preferred member type';

  @override
  String get neighborhoodStreet => 'Neighborhood / district / street';

  @override
  String get eventDetails => 'Event details';

  @override
  String get districtsLoading => 'Loading districts...';

  @override
  String selectFromCityDistricts(String city) {
    return 'Select from $city districts';
  }

  @override
  String get selectDistrictFirst => 'Select a district first';

  @override
  String get startTypingNeighborhoodHint => 'Start typing: Nişantepe';

  @override
  String searchDistrictsInCity(String city) {
    return 'Search districts in $city';
  }

  @override
  String get districtNotFound => 'District not found.';

  @override
  String profileInfoLoadFailed(String error) {
    return 'Could not load profile information: $error';
  }

  @override
  String get districtsLoadFailed =>
      'Could not load districts. Check your internet connection.';

  @override
  String get enableLocationServices =>
      'You must turn on your phone\'s location services.';

  @override
  String get locationPermissionDenied =>
      'Location permission was denied. You can select manually on the map.';

  @override
  String locationOutsideActiveCity(String city) {
    return 'The location you selected appears to be outside $city. Change your active city from the home screen and try again.';
  }

  @override
  String get locationSelectedCompleteAddress =>
      'Location selected. You can complete any missing fields from the list.';

  @override
  String mapCouldNotOpen(String error) {
    return 'Could not open map: $error';
  }

  @override
  String get cannotSelectPastDateTime =>
      'You cannot select a past date and time.';

  @override
  String get eventDurationMinOneHour =>
      'Event duration must be at least 1 hour.';

  @override
  String get eventDurationMaxSixHours =>
      'Event duration can be at most 6 hours.';

  @override
  String get eventDurationThirtyMinuteSteps =>
      'Start and end times must be selected in 30-minute intervals.';

  @override
  String get plusRequiredForMultiplePlayers =>
      'Plus membership is required for 2 or more players.';

  @override
  String get normalMembersTomorrowOnly =>
      'Normal members can create events for tomorrow at the latest.';

  @override
  String get sessionNotFoundPleaseLogin =>
      'Session not found. You must log in again.';

  @override
  String get addressNotFoundOnMap =>
      'Address not found on the map. Write the neighborhood, street, or venue name more clearly or select on the map.';

  @override
  String eventCreateFailedWithCode(String code, String message) {
    return 'Could not create event ($code): $message';
  }

  @override
  String eventCreateFailed(String error) {
    return 'Could not create event: $error';
  }

  @override
  String get myLocation => 'My location';

  @override
  String get searchOnMap => 'Search on map';

  @override
  String get publishEvent => 'Publish event';

  @override
  String get livePriceSummary => 'Live price summary';

  @override
  String get duration => 'Duration';

  @override
  String get durationFactor => 'Duration factor';

  @override
  String get basePricePerPlayer => 'Base price per person';

  @override
  String get totalFee => 'Total fee';

  @override
  String get durationRangeHint =>
      'Duration must be between 1 and 6 hours in 30-minute intervals.';

  @override
  String get plusMemberBenefits =>
      'Plus member: You can select multiple players and future dates.';

  @override
  String get normalMemberLimits =>
      'Normal member: You can create an event for 1 player and at most tomorrow.';

  @override
  String startTimeLabel(String time) {
    return 'Start $time';
  }

  @override
  String endTimeLabel(String time) {
    return 'End $time';
  }

  @override
  String get activeCity => 'Active city';

  @override
  String get mapSelectionOptional => 'Map selection is not required.';

  @override
  String get meetingPointSelected =>
      'Meeting point selected; district and neighborhood were filled automatically.';

  @override
  String get mustSelectDistrict => 'You must select a district';

  @override
  String get neighborhoodRequired =>
      'Neighborhood / district information is required';

  @override
  String durationHours(int count) {
    return '$count hours';
  }

  @override
  String durationMinutesOnly(int count) {
    return '$count minutes';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours hours $minutes minutes';
  }

  @override
  String currencyAmount(String amount) {
    return '$amount TL';
  }

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get messageNotifications => 'Message notifications';

  @override
  String get eventNotifications => 'Event notifications';

  @override
  String get applicationNotifications => 'Application notifications';

  @override
  String get campaignNotifications => 'Campaign notifications';

  @override
  String get documents => 'Documents';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get communityRules => 'Community Rules';

  @override
  String get account => 'Account';

  @override
  String get changePhoneNumber => 'Change phone number';

  @override
  String get changePhoneNumberDescription =>
      'Verify your new phone number with an SMS code.';

  @override
  String get createAccountDeletionRequest => 'Create account deletion request';

  @override
  String get accountDeletionRequestDescription =>
      'After the request, you will be signed out and your account will be reviewed.';

  @override
  String get loginRequiredForAccountDeletion =>
      'You must log in to create an account deletion request.';

  @override
  String get accountDeletionRequestTitle => 'Account deletion request';

  @override
  String get accountDeletionFirstConfirmation =>
      'Your account will not be deleted immediately. Your request will be recorded, and you will not be able to use your account until the process is complete.';

  @override
  String get giveUp => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String get finalConfirmation => 'Final confirmation';

  @override
  String get accountDeletionFinalConfirmation =>
      'After the deletion request is created, you will be signed out and will not be able to access the app until the process is complete.';

  @override
  String get createRequest => 'Create request';

  @override
  String get accountDeletionRequestCouldNotBeCreated =>
      'The account deletion request could not be created.';

  @override
  String get legalTermsBody =>
      'Dört. helps people find missing players for games, sports and social activities. Creating and joining events is free. Users are responsible for the accuracy of the information they provide, their behavior at events, and compliance with applicable rules.';

  @override
  String get privacyPolicyBody =>
      'Profile, phone verification, event, location, messaging, notification and Google Play purchase records are processed to provide the service. Identity and verification documents are used for the verification process. An account deletion request can be made in the app or through destek@dortapp.com.';

  @override
  String get communityRulesBody =>
      'Be respectful. Harassment, threats, discrimination, fraud, and misleading events are prohibited. Do not apply to events you cannot attend; notify the organizer promptly if you need to cancel. Report users who pose a safety risk through the support channel.';

  @override
  String get onlinePlay => 'Play online';

  @override
  String get onlinePlayIntro =>
      'Okey, 101, Batak and backgammon. This section appears only when the development flag is on.';

  @override
  String get playWithBots => 'Play with bots';

  @override
  String get multiplayerClosed =>
      'Multiplayer tables are off in this build. The app does not connect them to the production database. A table cannot be created without the emulator define.';

  @override
  String get multiplayerUnverified =>
      'The emulator define is on. A multiplayer table still does not open: a two-user session was not verified, and the client cannot write a score, dice, or hand.';

  @override
  String get yourTurnLabel => 'Your turn';

  @override
  String get botTurnLabel => 'Bot is playing';

  @override
  String get localSession => 'Local session';

  @override
  String get drawWallAction => 'Draw from the wall';

  @override
  String get takeDiscardAction => 'Take the discard';

  @override
  String get openAction => 'Open';

  @override
  String get addMeldAction => 'Add to my meld';

  @override
  String get finishedTitle => 'Game over';

  @override
  String get okeyRule =>
      'Four-player classic Okey. 106 tiles, the indicator sets the okey. Sets and runs need at least three tiles; 13-1 does not wrap. The winner arranges 14 tiles.';

  @override
  String get okey101Rule =>
      'Four-player 101. Opening needs at least 101. Tiles can be added only to your own melds. A taken discard must be played in a meld that turn. An unopened hand is penalized 202.';

  @override
  String get batakRule =>
      'Four-player one-deal auction Batak. Bids run from 5 to 13. If everyone passes, the dealer must bid 5. Trump is chosen. Suit must be followed. The declarer scores the bid if made, or loses that bid.';

  @override
  String get tavlaRule =>
      'Two-player standard backgammon. No doubling cube. A checker on the bar must enter first. A normal win scores 1, a gammon 2 and a backgammon 3.';

  @override
  String get rollDice => 'Roll dice';

  @override
  String get passAction => 'Pass';

  @override
  String get youLabel => 'You';

  @override
  String get discardAction => 'Discard';
}
