import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Alveron'**
  String get appName;

  /// No description provided for @stayConnected.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get stayConnected;

  /// No description provided for @withLovedOnes.
  ///
  /// In en, this message translates to:
  /// **'with Your Loved Ones'**
  String get withLovedOnes;

  /// No description provided for @trackDescription.
  ///
  /// In en, this message translates to:
  /// **'Track your family and friends in real-time. Know they\'re safe, wherever they are.'**
  String get trackDescription;

  /// No description provided for @setSafeZones.
  ///
  /// In en, this message translates to:
  /// **'Set Safe Zones'**
  String get setSafeZones;

  /// No description provided for @getInstantAlerts.
  ///
  /// In en, this message translates to:
  /// **'Get Instant Alerts'**
  String get getInstantAlerts;

  /// No description provided for @safeZonesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create geofences for home, school, or work. Receive notifications when family arrives or leaves.'**
  String get safeZonesDescription;

  /// No description provided for @premiumFeatures.
  ///
  /// In en, this message translates to:
  /// **'Premium Features'**
  String get premiumFeatures;

  /// No description provided for @ultimatePeace.
  ///
  /// In en, this message translates to:
  /// **'Ultimate Peace of Mind'**
  String get ultimatePeace;

  /// No description provided for @premiumDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock unlimited places, location history, and priority support with Premium.'**
  String get premiumDescription;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account? All your data, groups, and places will be lost. This action cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @inviteMembers.
  ///
  /// In en, this message translates to:
  /// **'Invite Members'**
  String get inviteMembers;

  /// No description provided for @inviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Share your group invite code'**
  String get inviteDescription;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// No description provided for @premiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription'**
  String get premiumSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @preciseTracking.
  ///
  /// In en, this message translates to:
  /// **'Precise Tracking'**
  String get preciseTracking;

  /// No description provided for @allowBackground.
  ///
  /// In en, this message translates to:
  /// **'Allow tracking even when app is closed'**
  String get allowBackground;

  /// No description provided for @locationSettings.
  ///
  /// In en, this message translates to:
  /// **'Location Settings'**
  String get locationSettings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @addressUnknown.
  ///
  /// In en, this message translates to:
  /// **'Address Unknown'**
  String get addressUnknown;

  /// No description provided for @noInviteCode.
  ///
  /// In en, this message translates to:
  /// **'No invite code available'**
  String get noInviteCode;

  /// No description provided for @sosDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS Alert'**
  String get sosDialogTitle;

  /// No description provided for @sosDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will send an emergency alert to all members in your current group. Continue?'**
  String get sosDialogContent;

  /// No description provided for @sendSOS.
  ///
  /// In en, this message translates to:
  /// **'Send SOS'**
  String get sendSOS;

  /// No description provided for @sosSent.
  ///
  /// In en, this message translates to:
  /// **'SOS Alert Sent'**
  String get sosSent;

  /// No description provided for @yourCircle.
  ///
  /// In en, this message translates to:
  /// **'Your Group'**
  String get yourCircle;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @circleCode.
  ///
  /// In en, this message translates to:
  /// **'Group Code'**
  String get circleCode;

  /// No description provided for @joinCircle.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinCircle;

  /// No description provided for @createCircle.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createCircle;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'ENTER CODE'**
  String get enterCode;

  /// No description provided for @circleName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get circleName;

  /// No description provided for @editPlace.
  ///
  /// In en, this message translates to:
  /// **'Edit Place'**
  String get editPlace;

  /// No description provided for @addPlace.
  ///
  /// In en, this message translates to:
  /// **'Add Place'**
  String get addPlace;

  /// No description provided for @placeName.
  ///
  /// In en, this message translates to:
  /// **'Place Name'**
  String get placeName;

  /// No description provided for @radius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get radius;

  /// No description provided for @locationAlwaysRequired.
  ///
  /// In en, this message translates to:
  /// **'Always Location Required'**
  String get locationAlwaysRequired;

  /// No description provided for @locationAlwaysDescription.
  ///
  /// In en, this message translates to:
  /// **'To track your location in the background, you must set location permission to \"Always\" in your device settings.'**
  String get locationAlwaysDescription;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @familyTracker.
  ///
  /// In en, this message translates to:
  /// **'Family Tracker'**
  String get familyTracker;

  /// No description provided for @feelCloseToFamily.
  ///
  /// In en, this message translates to:
  /// **'Feel closer to your family anytime'**
  String get feelCloseToFamily;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @loginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Login to continue'**
  String get loginToContinue;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @byContinuing.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get byContinuing;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @agreementSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get agreementSuffix;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online;

  /// No description provided for @leaveCircle.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leaveCircle;

  /// No description provided for @leaveCircleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group? You will lose access to all shared locations and places.'**
  String get leaveCircleConfirm;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @sosAlertSentToAll.
  ///
  /// In en, this message translates to:
  /// **'SOS alert sent to all group members!'**
  String get sosAlertSentToAll;

  /// No description provided for @successfullyLeftCircle.
  ///
  /// In en, this message translates to:
  /// **'Successfully left the group.'**
  String get successfullyLeftCircle;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search people or places...'**
  String get searchHint;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search for family members or places...'**
  String get searchPlaceholder;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get searchNoResults;

  /// No description provided for @welcomeToAlveron.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Alveron'**
  String get welcomeToAlveron;

  /// No description provided for @noCircleDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a group or join one with an invite code to start tracking.'**
  String get noCircleDescription;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @circleNameExample.
  ///
  /// In en, this message translates to:
  /// **'Group Name (e.g. Family)'**
  String get circleNameExample;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get success;

  /// No description provided for @premiumUpgradeMessage.
  ///
  /// In en, this message translates to:
  /// **'You are now a Premium member. All features have been unlocked!'**
  String get premiumUpgradeMessage;

  /// No description provided for @awesome.
  ///
  /// In en, this message translates to:
  /// **'Awesome!'**
  String get awesome;

  /// No description provided for @goPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get goPremium;

  /// No description provided for @unlockAllFeatures.
  ///
  /// In en, this message translates to:
  /// **'Unlock all features for your family\'s safety'**
  String get unlockAllFeatures;

  /// No description provided for @youArePremiumMember.
  ///
  /// In en, this message translates to:
  /// **'You are a Premium Member'**
  String get youArePremiumMember;

  /// No description provided for @allProFeaturesActive.
  ///
  /// In en, this message translates to:
  /// **'All PRO features are currently active.'**
  String get allProFeaturesActive;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @subscriptionManagementSoon.
  ///
  /// In en, this message translates to:
  /// **'Subscription management will be available soon.'**
  String get subscriptionManagementSoon;

  /// No description provided for @upgradeNow.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get upgradeNow;

  /// No description provided for @cancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime. No commitment.'**
  String get cancelAnytime;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @purchaseRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchase restored successfully.'**
  String get purchaseRestored;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @save50.
  ///
  /// In en, this message translates to:
  /// **'Save 50%'**
  String get save50;

  /// No description provided for @realTimeLocation.
  ///
  /// In en, this message translates to:
  /// **'Real-time Location'**
  String get realTimeLocation;

  /// No description provided for @locationHistory30Days.
  ///
  /// In en, this message translates to:
  /// **'30-day Location History'**
  String get locationHistory30Days;

  /// No description provided for @unlimitedAlerts.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Alerts'**
  String get unlimitedAlerts;

  /// No description provided for @unlimitedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Places'**
  String get unlimitedPlaces;

  /// No description provided for @sosEmergencyButton.
  ///
  /// In en, this message translates to:
  /// **'SOS Emergency Button'**
  String get sosEmergencyButton;

  /// No description provided for @adFreeExperience.
  ///
  /// In en, this message translates to:
  /// **'Ad-free Experience'**
  String get adFreeExperience;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places;

  /// No description provided for @safeZones.
  ///
  /// In en, this message translates to:
  /// **'Safe Zones'**
  String get safeZones;

  /// No description provided for @safeZonesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when family members arrive or leave these places'**
  String get safeZonesSubtitle;

  /// No description provided for @noSafeZones.
  ///
  /// In en, this message translates to:
  /// **'No Safe Zones Yet'**
  String get noSafeZones;

  /// No description provided for @noSafeZonesDescription.
  ///
  /// In en, this message translates to:
  /// **'Add important places like Home, School, or Work to get notified when family members arrive or leave.'**
  String get noSafeZonesDescription;

  /// No description provided for @addFirstPlace.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Place'**
  String get addFirstPlace;

  /// No description provided for @deletePlace.
  ///
  /// In en, this message translates to:
  /// **'Delete Place?'**
  String get deletePlace;

  /// No description provided for @deletePlaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String deletePlaceConfirm(String name);

  /// No description provided for @placeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Place deleted'**
  String get placeDeleted;

  /// No description provided for @failedToDeletePlace.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete place'**
  String get failedToDeletePlace;

  /// No description provided for @fetchingAddress.
  ///
  /// In en, this message translates to:
  /// **'Fetching address...'**
  String get fetchingAddress;

  /// No description provided for @noAddressFound.
  ///
  /// In en, this message translates to:
  /// **'No address found for this location'**
  String get noAddressFound;

  /// No description provided for @searchForPlace.
  ///
  /// In en, this message translates to:
  /// **'Search for a place...'**
  String get searchForPlace;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocation;

  /// No description provided for @placeDetails.
  ///
  /// In en, this message translates to:
  /// **'Place Details'**
  String get placeDetails;

  /// No description provided for @placeNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Home, Work, School'**
  String get placeNameHint;

  /// No description provided for @savePlaceBtn.
  ///
  /// In en, this message translates to:
  /// **'Save Place'**
  String get savePlaceBtn;

  /// No description provided for @enterPlaceName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a place name'**
  String get enterPlaceName;

  /// No description provided for @noCircleFoundError.
  ///
  /// In en, this message translates to:
  /// **'No group found. Cannot add place.'**
  String get noCircleFoundError;

  /// No description provided for @placeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Place \"{name}\" updated!'**
  String placeUpdated(String name);

  /// No description provided for @placeSaved.
  ///
  /// In en, this message translates to:
  /// **'Place \"{name}\" saved!'**
  String placeSaved(String name);

  /// No description provided for @failedToAddPlace.
  ///
  /// In en, this message translates to:
  /// **'Failed to add place'**
  String get failedToAddPlace;

  /// No description provided for @errorSavingPlace.
  ///
  /// In en, this message translates to:
  /// **'Error occurred while saving place: {error}'**
  String errorSavingPlace(String error);

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @nudge.
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get nudge;

  /// No description provided for @userNudged.
  ///
  /// In en, this message translates to:
  /// **'{name} was nudged successfully!'**
  String userNudged(String name);

  /// No description provided for @sendMessageTo.
  ///
  /// In en, this message translates to:
  /// **'Send Message to {name}'**
  String sendMessageTo(String name);

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @messageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent successfully!'**
  String get messageSent;

  /// No description provided for @todaysMovement.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Movement'**
  String get todaysMovement;

  /// No description provided for @welcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome,\n{name}!'**
  String welcomeName(String name);

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Your profile is set! To ensure your family\'s safety 24/7, let\'s configure your real-time tracking and instant notification settings.'**
  String get welcomeDescription;

  /// No description provided for @appTracking.
  ///
  /// In en, this message translates to:
  /// **'Data Privacy'**
  String get appTracking;

  /// No description provided for @appTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable tracking transparency to help us provide a more personalized, secure, and optimized tracking experience.'**
  String get appTrackingDescription;

  /// No description provided for @backgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Always-On Safety'**
  String get backgroundLocation;

  /// No description provided for @backgroundLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Alveron requires \'Always\' location access to send arrival and departure alerts to your family, even when the app is closed.'**
  String get backgroundLocationDescription;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Instant Alerts'**
  String get notifications;

  /// No description provided for @notificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notified immediately when a circle member arrives at a safe zone or sends an SOS emergency signal.'**
  String get notificationsDescription;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish Setup'**
  String get finishSetup;

  /// No description provided for @allowAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Allow and Continue'**
  String get allowAndContinue;

  /// No description provided for @connectedAccount.
  ///
  /// In en, this message translates to:
  /// **'Connected Account'**
  String get connectedAccount;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @trackingStepText.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is our priority. We use this data only to provide essential safety features. Please tap \'Allow\' when the system dialog appears.'**
  String get trackingStepText;

  /// No description provided for @locationStepText.
  ///
  /// In en, this message translates to:
  /// **'To keep your circle updated round-the-clock, please ensure you select \'Always Allow\' in the following system settings.'**
  String get locationStepText;

  /// No description provided for @notificationStepText.
  ///
  /// In en, this message translates to:
  /// **'Stay informed with real-time updates from your group members\' arrivals, departures, and emergency alerts.'**
  String get notificationStepText;

  /// No description provided for @failedToPurchase.
  ///
  /// In en, this message translates to:
  /// **'Failed to purchase: {error}'**
  String failedToPurchase(String error);

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'/year'**
  String get perYear;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @failedToDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String failedToDeleteAccount(String error);

  /// No description provided for @locationTrackingActive.
  ///
  /// In en, this message translates to:
  /// **'Location Tracking Active'**
  String get locationTrackingActive;

  /// No description provided for @locationTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Alveron is tracking your location for your safety.'**
  String get locationTrackingDescription;

  /// No description provided for @sosLocationSharingNote.
  ///
  /// In en, this message translates to:
  /// **'Your location will be shared with all members immediately.'**
  String get sosLocationSharingNote;

  /// No description provided for @failedToJoinCircle.
  ///
  /// In en, this message translates to:
  /// **'Failed to join group'**
  String get failedToJoinCircle;

  /// No description provided for @failedToCreateCircle.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get failedToCreateCircle;

  /// No description provided for @safeZone.
  ///
  /// In en, this message translates to:
  /// **'Safe Zone'**
  String get safeZone;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last Seen'**
  String get lastSeen;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @inviteDescriptionFull.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your family or friends to let them join your group.'**
  String get inviteDescriptionFull;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied!'**
  String get inviteCodeCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my group on Alveron using this invite code: {code}'**
  String shareMessage(String code);

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @joinACircle.
  ///
  /// In en, this message translates to:
  /// **'Join a Group'**
  String get joinACircle;

  /// No description provided for @enterInviteCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code shared by your family or friends'**
  String get enterInviteCodeDescription;

  /// No description provided for @validCode.
  ///
  /// In en, this message translates to:
  /// **'Valid code! Ready to join'**
  String get validCode;

  /// No description provided for @joinCircleBtn.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinCircleBtn;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @noNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see alerts and updates from your group here.'**
  String get noNotificationsDescription;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @notificationSos.
  ///
  /// In en, this message translates to:
  /// **'SOS Alert'**
  String get notificationSos;

  /// No description provided for @notificationMember.
  ///
  /// In en, this message translates to:
  /// **'Member Update'**
  String get notificationMember;

  /// No description provided for @notificationPlace.
  ///
  /// In en, this message translates to:
  /// **'Place Update'**
  String get notificationPlace;

  /// No description provided for @notificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get notificationMessage;

  /// No description provided for @readAll.
  ///
  /// In en, this message translates to:
  /// **'Read All'**
  String get readAll;

  /// No description provided for @placeEntered.
  ///
  /// In en, this message translates to:
  /// **'{name} entered {place}'**
  String placeEntered(String name, String place);

  /// No description provided for @placeExited.
  ///
  /// In en, this message translates to:
  /// **'{name} left {place}'**
  String placeExited(String name, String place);

  /// No description provided for @joinedCircle.
  ///
  /// In en, this message translates to:
  /// **'joined {circle}'**
  String joinedCircle(String circle);

  /// No description provided for @leftCircle.
  ///
  /// In en, this message translates to:
  /// **'{name} left {circle}'**
  String leftCircle(String name, String circle);

  /// No description provided for @movementHistory.
  ///
  /// In en, this message translates to:
  /// **'Movement History'**
  String get movementHistory;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @frequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get frequent;

  /// No description provided for @noMovementData.
  ///
  /// In en, this message translates to:
  /// **'No location data yet. Movement history will appear here once the app tracks locations.'**
  String get noMovementData;

  /// No description provided for @totalVisits.
  ///
  /// In en, this message translates to:
  /// **'{count} visits'**
  String totalVisits(int count);

  /// No description provided for @avgTime.
  ///
  /// In en, this message translates to:
  /// **'Avg {time}'**
  String avgTime(String time);

  /// No description provided for @lastVisitLabel.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get lastVisitLabel;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Real-time family safety, reimagined.'**
  String get splashTagline;

  /// No description provided for @onboardingRealTimeGps.
  ///
  /// In en, this message translates to:
  /// **'Real-time GPS'**
  String get onboardingRealTimeGps;

  /// No description provided for @onboardingBatteryStatus.
  ///
  /// In en, this message translates to:
  /// **'Battery status'**
  String get onboardingBatteryStatus;

  /// No description provided for @onboardingLiveMap.
  ///
  /// In en, this message translates to:
  /// **'Live map'**
  String get onboardingLiveMap;

  /// No description provided for @onboardingCustomGeofences.
  ///
  /// In en, this message translates to:
  /// **'Custom geofences'**
  String get onboardingCustomGeofences;

  /// No description provided for @onboardingInstantAlerts.
  ///
  /// In en, this message translates to:
  /// **'Instant alerts'**
  String get onboardingInstantAlerts;

  /// No description provided for @onboardingSmartHistory.
  ///
  /// In en, this message translates to:
  /// **'Smart history'**
  String get onboardingSmartHistory;

  /// No description provided for @onboardingSosEmergency.
  ///
  /// In en, this message translates to:
  /// **'SOS emergency'**
  String get onboardingSosEmergency;

  /// No description provided for @onboarding30DayHistory.
  ///
  /// In en, this message translates to:
  /// **'30 day history'**
  String get onboarding30DayHistory;

  /// No description provided for @permitted.
  ///
  /// In en, this message translates to:
  /// **'Permitted'**
  String get permitted;

  /// No description provided for @notPermitted.
  ///
  /// In en, this message translates to:
  /// **'Not Permitted'**
  String get notPermitted;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
