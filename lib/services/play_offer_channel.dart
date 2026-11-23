import 'dart:io';

import 'package:flutter/services.dart';

import 'play_one_time_offer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayOfferChannel {
  PlayOfferChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.dortapp.dort/play_offers');

  final MethodChannel _channel;

  Future<List<PlayOneTimeOffer>> queryOneTimeOffers(
    Iterable<String> productIds,
  ) async {
    if (const String.fromEnvironment('DORT_ENV') == 'development') {
      final docs = await FirebaseFirestore.instance
          .collection('dev_store_products')
          .get();
      final ids = productIds.toSet();
      return docs.docs
          .where((d) => ids.contains(d.id) && d.data()['available'] == true)
          .map(
            (d) => PlayOneTimeOffer(
              productId: d.id,
              offerId: '',
              offerToken: 'dev-only-${d.id}',
              purchaseOptionId: d.data()['option']?.toString() ?? 'buy',
              formattedPrice: '${d.data()['price']} (Dev)',
              priceAmountMicros: ((d.data()['rawPrice'] as num) * 1000000)
                  .toInt(),
              currencyCode: 'TRY',
            ),
          )
          .toList();
    }
    if (!Platform.isAndroid) {
      return <PlayOneTimeOffer>[];
    }

    final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>(
      'queryOneTimeOffers',
      <String, dynamic>{'productIds': productIds.toList()},
    );

    return (raw ?? <dynamic>[]).whereType<Map>().map((
      Map<dynamic, dynamic> item,
    ) {
      final Object? fullPrice = item['fullPriceMicros'];
      return PlayOneTimeOffer(
        productId: item['productId']?.toString() ?? '',
        offerId: item['offerId']?.toString() ?? '',
        offerToken: item['offerToken']?.toString() ?? '',
        purchaseOptionId: item['purchaseOptionId']?.toString() ?? '',
        formattedPrice: item['formattedPrice']?.toString() ?? '',
        priceAmountMicros: item['priceAmountMicros'] is num
            ? (item['priceAmountMicros'] as num).toInt()
            : 0,
        currencyCode: item['currencyCode']?.toString() ?? '',
        fullPriceMicros: fullPrice is num ? fullPrice.toInt() : null,
      );
    }).toList();
  }
}
