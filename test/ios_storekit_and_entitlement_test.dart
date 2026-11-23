import 'dart:io';

import 'package:dorduncu/admin/admin_play_product_mapping_screen.dart';
import 'package:dorduncu/firebase_options.dart';
import 'package:dorduncu/models/badge_product_model.dart';
import 'package:dorduncu/models/market_badge_display.dart';
import 'package:dorduncu/models/plus_product_model.dart';
import 'package:dorduncu/services/apple_account_token.dart';
import 'package:dorduncu/services/plus_subscription_offer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

void main() {
  group('Apple StoreKit 2 & account token', () {
    test('appleAppAccountTokenForUid matches server UUID v5 deterministically', () {
      final String tokenA = appleAppAccountTokenForUid('dort-test-uid-001');
      final String tokenB = appleAppAccountTokenForUid('  dort-test-uid-001  ');
      expect(tokenA, tokenB);
      expect(
        tokenA,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(tokenA, '13c87cae-df84-5304-82a3-be93b0c1148b');
    });

    test('selectApplePlusProduct parses StoreKit 2 subscription period and price', () {
      final AppStoreProduct2Details product =
          AppStoreProduct2Details.fromSK2Product(
            SK2Product(
              id: 'com.dortapp.dort.plus.monthly',
              displayName: 'Dört. Plus',
              displayPrice: '₺799,00',
              description: 'Aylık Plus aboneliği',
              price: 799.0,
              type: SK2ProductType.autoRenewable,
              priceLocale: SK2PriceLocale(
                currencyCode: 'TRY',
                currencySymbol: '₺',
              ),
              subscription: const SK2SubscriptionInfo(
                subscriptionGroupID: 'plus_group',
                promotionalOffers: <SK2SubscriptionOffer>[],
                subscriptionPeriod: SK2SubscriptionPeriod(
                  value: 1,
                  unit: SK2SubscriptionPeriodUnit.month,
                ),
              ),
            ),
          );

      final PlusSubscriptionSelection selection = selectApplePlusProduct(
        offers: <ProductDetails>[product],
        appleProductId: 'com.dortapp.dort.plus.monthly',
      );

      expect(selection.productDetails.id, 'com.dortapp.dort.plus.monthly');
      expect(selection.formattedPrice, '₺799,00');
      expect(selection.billingPeriod, 'P1M');
      expect(selection.basePlanId, 'apple_subscription');
    });

    test('selectApplePlusProduct rejects missing mapping or absent product', () {
      expect(
        () => selectApplePlusProduct(
          offers: const <ProductDetails>[],
          appleProductId: '',
        ),
        throwsA(
          isA<PlusSubscriptionOfferException>().having(
            (PlusSubscriptionOfferException e) => e.code,
            'code',
            'missing_product_id',
          ),
        ),
      );

      expect(
        () => selectApplePlusProduct(
          offers: const <ProductDetails>[],
          appleProductId: 'com.dortapp.dort.plus.monthly',
        ),
        throwsA(
          isA<PlusSubscriptionOfferException>().having(
            (PlusSubscriptionOfferException e) => e.code,
            'code',
            'plan_not_found',
          ),
        ),
      );
    });

    test('catalog models isolate Google Play and App Store product IDs', () {
      const PlusProductModel plus = PlusProductModel(
        id: 'monthly',
        title: 'Dört. Plus',
        plan: 'monthly',
        priceKurus: 79900,
        durationDays: 30,
        active: true,
        sortOrder: 1,
        googlePlayProductId: 'dort_plus',
        googlePlayBasePlanId: 'monthly',
        appleProductId: 'com.dortapp.dort.plus.monthly',
      );
      expect(plus.storeProductIdFor(TargetPlatform.android), 'dort_plus');
      expect(
        plus.storeProductIdFor(TargetPlatform.iOS),
        'com.dortapp.dort.plus.monthly',
      );
      expect(plus.hasStoreMappingFor(TargetPlatform.android), isTrue);
      expect(plus.hasStoreMappingFor(TargetPlatform.iOS), isTrue);

      const BadgeProductModel badge = BadgeProductModel(
        id: 'okey',
        gameId: 'okey',
        gameName: 'Okey',
        title: 'Okey Rozeti',
        description: '',
        emoji: '🎴',
        priceKurus: 49900,
        active: true,
        sortOrder: 1,
        createdAt: null,
        googlePlayProductId: 'dort_badge_okey',
        appleProductId: 'com.dortapp.dort.badge.okey',
      );
      expect(
        badge.storeProductIdFor(TargetPlatform.android),
        'dort_badge_okey',
      );
      expect(
        badge.storeProductIdFor(TargetPlatform.iOS),
        'com.dortapp.dort.badge.okey',
      );
    });

    test('ownedBadgeIsEntitled handles Play, Apple, legacy and admin grants', () {
      expect(ownedBadgeIsEntitled(<String, dynamic>{}), isTrue);
      expect(
        ownedBadgeIsEntitled(<String, dynamic>{'appleEntitled': true}),
        isTrue,
      );
      expect(
        ownedBadgeIsEntitled(<String, dynamic>{'appleEntitled': false}),
        isFalse,
      );
      expect(
        ownedBadgeIsEntitled(<String, dynamic>{
          'appleEntitled': false,
          'googlePlayEntitled': true,
        }),
        isTrue,
      );
      expect(
        ownedBadgeIsEntitled(<String, dynamic>{
          'appleEntitled': true,
          'googlePlayEntitled': false,
        }),
        isTrue,
      );
      expect(
        ownedBadgeIsEntitled(<String, dynamic>{
          'appleEntitled': true,
          'adminBlocked': true,
        }),
        isFalse,
      );
    });

    test('buildAppleMappingPayload only sends Apple mapping fields', () {
      final Map<String, dynamic> payload = buildAppleMappingPayload(
        collectionName: 'badge_products',
        productId: 'okey',
        appleProductId: ' com.dortapp.dort.badge.okey ',
      );
      expect(payload, <String, dynamic>{
        'collection': 'badge_products',
        'productId': 'okey',
        'appleProductId': 'com.dortapp.dort.badge.okey',
      });
    });
  });

  group('iOS bundle, permissions, icons, entitlements and CI config', () {
    test('project.pbxproj sets com.dortapp.dort, iOS 15.0 and entitlements', () {
      final String pbx = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(pbx.contains('com.example.dorduncu'), isFalse);
      expect(pbx.contains('PRODUCT_BUNDLE_IDENTIFIER = com.dortapp.dort;'), isTrue);
      expect(
        pbx.contains('PRODUCT_BUNDLE_IDENTIFIER = com.dortapp.dort.RunnerTests;'),
        isTrue,
      );
      expect(pbx.contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'), isTrue);
      expect(
        pbx.contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
        isTrue,
      );
      expect(pbx.contains('GoogleService-Info.plist in Resources'), isTrue);
      expect(pbx.contains('InfoPlist.strings in Resources'), isTrue);
    });

    test('Info.plist and localized InfoPlist.strings are complete', () {
      final String infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist.contains('<string>Dört.</string>'), isTrue);
      expect(infoPlist.contains('<key>UIBackgroundModes</key>'), isTrue);
      expect(infoPlist.contains('<string>remote-notification</string>'), isTrue);
      expect(infoPlist.contains('<key>ITSAppUsesNonExemptEncryption</key>'), isTrue);
      expect(infoPlist.contains('<key>NSCameraUsageDescription</key>'), isTrue);
      expect(infoPlist.contains('<key>NSPhotoLibraryUsageDescription</key>'), isTrue);
      expect(infoPlist.contains('<key>NSLocationWhenInUseUsageDescription</key>'), isTrue);

      for (final String lang in <String>['tr', 'en', 'de']) {
        final String strings = File(
          'ios/Runner/$lang.lproj/InfoPlist.strings',
        ).readAsStringSync();
        expect(strings.contains('CFBundleDisplayName = "Dört.";'), isTrue);
        expect(strings.contains('NSCameraUsageDescription'), isTrue);
        expect(strings.contains('NSPhotoLibraryUsageDescription'), isTrue);
        expect(strings.contains('NSLocationWhenInUseUsageDescription'), isTrue);
      }
    });

    test('Runner.entitlements, PrivacyInfo.xcprivacy, AppIcon and codemagic.yaml exist', () {
      final String entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      expect(entitlements.contains('aps-environment'), isTrue);
      expect(
        entitlements.contains('com.apple.developer.devicecheck.appattest-environment'),
        isTrue,
      );

      final String privacy = File(
        'ios/Runner/PrivacyInfo.xcprivacy',
      ).readAsStringSync();
      expect(privacy.contains('<key>NSPrivacyTracking</key>'), isTrue);
      expect(privacy.contains('NSPrivacyAccessedAPICategoryUserDefaults'), isTrue);
      expect(privacy.contains('NSPrivacyAccessedAPICategoryFileTimestamp'), isTrue);

      final File icon1024 = File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      );
      expect(icon1024.existsSync(), isTrue);
      final List<int> bytes = icon1024.readAsBytesSync();
      expect(bytes.length, greaterThan(4000));
      // PNG header: 89 50 4E 47 0D 0A 1A 0A; colorType byte at offset 25 == 2 (RGB, no alpha!)
      expect(bytes[25], 2, reason: 'App Store 1024x1024 icon must not have an alpha channel');

      final String cm = File('codemagic.yaml').readAsStringSync();
      expect(cm.contains('com.dortapp.dort'), isTrue);
      expect(cm.contains('scripts/ios_firebase_configure.sh'), isTrue);
      expect(cm.contains('xcode: latest'), isTrue);
    });

    test('Firebase iOS options, GoogleService-Info.plist and Phone Auth URL scheme match', () {
      final File plistFile = File('ios/Runner/GoogleService-Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final String plist = plistFile.readAsStringSync();
      expect(plist.contains('REPLACE_FROM_FIREBASE_CONSOLE'), isFalse);
      expect(plist.contains('<string>com.dortapp.dort</string>'), isTrue);
      expect(plist.contains('<string>dorduncu-8e599</string>'), isTrue);
      expect(
        plist.contains('<string>1:256435983692:ios:1a131b9593b6bd12c9abe9</string>'),
        isTrue,
      );

      expect(DefaultFirebaseOptions.ios.projectId, 'dorduncu-8e599');
      expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.dortapp.dort');
      expect(
        DefaultFirebaseOptions.ios.appId,
        '1:256435983692:ios:1a131b9593b6bd12c9abe9',
      );
      expect(DefaultFirebaseOptions.ios.messagingSenderId, '256435983692');
      expect(
        DefaultFirebaseOptions.ios.storageBucket,
        'dorduncu-8e599.firebasestorage.app',
      );
      expect(DefaultFirebaseOptions.ios.apiKey.trim(), isNotEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(
          DefaultFirebaseOptions.currentPlatform.appId,
          DefaultFirebaseOptions.ios.appId,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      final String infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist.contains('<key>CFBundleURLTypes</key>'), isTrue);
      expect(
        infoPlist.contains(
          '<string>app-1-256435983692-ios-1a131b9593b6bd12c9abe9</string>',
        ),
        isTrue,
      );
    });
  });
}
