import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @demo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo;

  /// No description provided for @demo2.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo2;

  /// No description provided for @demo3.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo3;

  /// No description provided for @demo4.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo4;

  /// No description provided for @orderTracking.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking;

  /// No description provided for @orderTracking2.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking2;

  /// No description provided for @couponManagement.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement;

  /// No description provided for @couponManagement2.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement2;

  /// No description provided for @couponManagement3.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement3;

  /// No description provided for @couponManagement4.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement4;

  /// No description provided for @productFootprint.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint;

  /// No description provided for @productFootprint2.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint2;

  /// No description provided for @productFootprint3.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint3;

  /// No description provided for @productFootprint4.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint4;

  /// No description provided for @orderTracking3.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking3;

  /// No description provided for @orderTracking4.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking4;

  /// No description provided for @couponManagement5.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement5;

  /// No description provided for @couponManagement6.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement6;

  /// No description provided for @couponManagement7.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement7;

  /// No description provided for @couponManagement8.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement8;

  /// No description provided for @productFootprint5.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint5;

  /// No description provided for @productFootprint6.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint6;

  /// No description provided for @productFootprint7.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint7;

  /// No description provided for @productFootprint8.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint8;

  /// No description provided for @orderTracking5.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking5;

  /// No description provided for @orderTracking6.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking6;

  /// No description provided for @couponManagement9.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement9;

  /// No description provided for @couponManagement10.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement10;

  /// No description provided for @couponManagement11.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement11;

  /// No description provided for @couponManagement12.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement12;

  /// No description provided for @productFootprint9.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint9;

  /// No description provided for @productFootprint10.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint10;

  /// No description provided for @productFootprint11.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint11;

  /// No description provided for @productFootprint12.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint12;

  /// No description provided for @orderTracking7.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking7;

  /// No description provided for @orderTracking8.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking8;

  /// No description provided for @couponManagement13.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement13;

  /// No description provided for @couponManagement14.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement14;

  /// No description provided for @couponManagement15.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement15;

  /// No description provided for @couponManagement16.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement16;

  /// No description provided for @productFootprint13.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint13;

  /// No description provided for @productFootprint14.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint14;

  /// No description provided for @productFootprint15.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint15;

  /// No description provided for @productFootprint16.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint16;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logout2.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout2;

  /// No description provided for @logout3.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout3;

  /// No description provided for @logout4.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout4;

  /// No description provided for @logout5.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout5;

  /// No description provided for @logout6.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout6;

  /// No description provided for @logout7.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout7;

  /// No description provided for @logout8.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout8;

  /// No description provided for @demo5.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo5;

  /// No description provided for @demo6.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo6;

  /// No description provided for @demo7.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo7;

  /// No description provided for @demo8.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo8;

  /// No description provided for @orderTracking9.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking9;

  /// No description provided for @orderTracking10.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking10;

  /// No description provided for @couponManagement17.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement17;

  /// No description provided for @couponManagement18.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement18;

  /// No description provided for @couponManagement19.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement19;

  /// No description provided for @couponManagement20.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement20;

  /// No description provided for @productFootprint17.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint17;

  /// No description provided for @productFootprint18.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint18;

  /// No description provided for @productFootprint19.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint19;

  /// No description provided for @productFootprint20.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint20;

  /// No description provided for @orderTracking11.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking11;

  /// No description provided for @orderTracking12.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking12;

  /// No description provided for @couponManagement21.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement21;

  /// No description provided for @couponManagement22.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement22;

  /// No description provided for @couponManagement23.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement23;

  /// No description provided for @couponManagement24.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement24;

  /// No description provided for @productFootprint21.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint21;

  /// No description provided for @productFootprint22.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint22;

  /// No description provided for @productFootprint23.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint23;

  /// No description provided for @productFootprint24.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint24;

  /// No description provided for @orderTracking13.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking13;

  /// No description provided for @orderTracking14.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking14;

  /// No description provided for @couponManagement25.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement25;

  /// No description provided for @couponManagement26.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement26;

  /// No description provided for @couponManagement27.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement27;

  /// No description provided for @couponManagement28.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement28;

  /// No description provided for @productFootprint25.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint25;

  /// No description provided for @productFootprint26.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint26;

  /// No description provided for @productFootprint27.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint27;

  /// No description provided for @productFootprint28.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint28;

  /// No description provided for @orderTracking15.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking15;

  /// No description provided for @orderTracking16.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking16;

  /// No description provided for @couponManagement29.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement29;

  /// No description provided for @couponManagement30.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement30;

  /// No description provided for @couponManagement31.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement31;

  /// No description provided for @couponManagement32.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement32;

  /// No description provided for @productFootprint29.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint29;

  /// No description provided for @productFootprint30.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint30;

  /// No description provided for @productFootprint31.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint31;

  /// No description provided for @productFootprint32.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint32;

  /// No description provided for @logout9.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout9;

  /// No description provided for @logout10.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout10;

  /// No description provided for @logout11.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout11;

  /// No description provided for @logout12.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout12;

  /// No description provided for @logout13.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout13;

  /// No description provided for @logout14.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout14;

  /// No description provided for @logout15.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout15;

  /// No description provided for @logout16.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout16;

  /// No description provided for @demo9.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo9;

  /// No description provided for @demo10.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo10;

  /// No description provided for @demo11.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo11;

  /// No description provided for @demo12.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo12;

  /// No description provided for @orderTracking17.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking17;

  /// No description provided for @orderTracking18.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking18;

  /// No description provided for @couponManagement33.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement33;

  /// No description provided for @couponManagement34.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement34;

  /// No description provided for @couponManagement35.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement35;

  /// No description provided for @couponManagement36.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement36;

  /// No description provided for @productFootprint33.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint33;

  /// No description provided for @productFootprint34.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint34;

  /// No description provided for @productFootprint35.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint35;

  /// No description provided for @productFootprint36.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint36;

  /// No description provided for @orderTracking19.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking19;

  /// No description provided for @orderTracking20.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking20;

  /// No description provided for @couponManagement37.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement37;

  /// No description provided for @couponManagement38.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement38;

  /// No description provided for @couponManagement39.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement39;

  /// No description provided for @couponManagement40.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement40;

  /// No description provided for @productFootprint37.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint37;

  /// No description provided for @productFootprint38.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint38;

  /// No description provided for @productFootprint39.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint39;

  /// No description provided for @productFootprint40.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint40;

  /// No description provided for @orderTracking21.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking21;

  /// No description provided for @orderTracking22.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking22;

  /// No description provided for @couponManagement41.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement41;

  /// No description provided for @couponManagement42.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement42;

  /// No description provided for @couponManagement43.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement43;

  /// No description provided for @couponManagement44.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement44;

  /// No description provided for @productFootprint41.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint41;

  /// No description provided for @productFootprint42.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint42;

  /// No description provided for @productFootprint43.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint43;

  /// No description provided for @productFootprint44.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint44;

  /// No description provided for @orderTracking23.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking23;

  /// No description provided for @orderTracking24.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking24;

  /// No description provided for @couponManagement45.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement45;

  /// No description provided for @couponManagement46.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement46;

  /// No description provided for @couponManagement47.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement47;

  /// No description provided for @couponManagement48.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement48;

  /// No description provided for @productFootprint45.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint45;

  /// No description provided for @productFootprint46.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint46;

  /// No description provided for @productFootprint47.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint47;

  /// No description provided for @productFootprint48.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint48;

  /// No description provided for @logout17.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout17;

  /// No description provided for @logout18.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout18;

  /// No description provided for @logout19.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout19;

  /// No description provided for @logout20.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout20;

  /// No description provided for @logout21.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout21;

  /// No description provided for @logout22.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout22;

  /// No description provided for @logout23.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout23;

  /// No description provided for @logout24.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout24;

  /// No description provided for @demo13.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo13;

  /// No description provided for @demo14.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo14;

  /// No description provided for @demo15.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo15;

  /// No description provided for @demo16.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo16;

  /// No description provided for @orderTracking25.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking25;

  /// No description provided for @orderTracking26.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking26;

  /// No description provided for @couponManagement49.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement49;

  /// No description provided for @couponManagement50.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement50;

  /// No description provided for @couponManagement51.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement51;

  /// No description provided for @couponManagement52.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement52;

  /// No description provided for @productFootprint49.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint49;

  /// No description provided for @productFootprint50.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint50;

  /// No description provided for @productFootprint51.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint51;

  /// No description provided for @productFootprint52.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint52;

  /// No description provided for @orderTracking27.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking27;

  /// No description provided for @orderTracking28.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking28;

  /// No description provided for @couponManagement53.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement53;

  /// No description provided for @couponManagement54.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement54;

  /// No description provided for @couponManagement55.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement55;

  /// No description provided for @couponManagement56.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement56;

  /// No description provided for @productFootprint53.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint53;

  /// No description provided for @productFootprint54.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint54;

  /// No description provided for @productFootprint55.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint55;

  /// No description provided for @productFootprint56.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint56;

  /// No description provided for @orderTracking29.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking29;

  /// No description provided for @orderTracking30.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking30;

  /// No description provided for @couponManagement57.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement57;

  /// No description provided for @couponManagement58.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement58;

  /// No description provided for @couponManagement59.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement59;

  /// No description provided for @couponManagement60.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement60;

  /// No description provided for @productFootprint57.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint57;

  /// No description provided for @productFootprint58.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint58;

  /// No description provided for @productFootprint59.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint59;

  /// No description provided for @productFootprint60.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint60;

  /// No description provided for @orderTracking31.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking31;

  /// No description provided for @orderTracking32.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking32;

  /// No description provided for @couponManagement61.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement61;

  /// No description provided for @couponManagement62.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement62;

  /// No description provided for @couponManagement63.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement63;

  /// No description provided for @couponManagement64.
  ///
  /// In en, this message translates to:
  /// **'Coupon Management'**
  String get couponManagement64;

  /// No description provided for @productFootprint61.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint61;

  /// No description provided for @productFootprint62.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint62;

  /// No description provided for @productFootprint63.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint63;

  /// No description provided for @productFootprint64.
  ///
  /// In en, this message translates to:
  /// **'Product Footprint'**
  String get productFootprint64;

  /// No description provided for @logout25.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout25;

  /// No description provided for @logout26.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout26;

  /// No description provided for @logout27.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout27;

  /// No description provided for @logout28.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout28;

  /// No description provided for @logout29.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout29;

  /// No description provided for @logout30.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout30;

  /// No description provided for @logout31.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout31;

  /// No description provided for @logout32.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout32;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
