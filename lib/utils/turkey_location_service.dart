import 'dart:convert';

import 'package:flutter/services.dart';

class TurkeyLocationService {
  TurkeyLocationService._();

  static Map<String, List<String>>? _cache;

  static Future<Map<String, List<String>>> load() async {
    if (_cache != null) {
      return _cache!;
    }

    final String rawJson = await rootBundle.loadString(
      'assets/data/turkey_locations.json',
    );

    final dynamic decoded = jsonDecode(rawJson);

    final Map<String, List<String>> result = <String, List<String>>{};

    if (decoded is Map<String, dynamic>) {
      for (final dynamic value in decoded.values) {
        if (value is! Map<String, dynamic>) continue;

        final String city =
            value['province']?.toString().trim() ?? '';

        final dynamic districtData = value['districts'];

        if (city.isEmpty || districtData is! List) continue;

        final List<String> districts = districtData
            .whereType<Map<String, dynamic>>()
            .map(
              (Map<String, dynamic> item) =>
                  item['name']?.toString().trim() ?? '',
            )
            .where((String name) => name.isNotEmpty)
            .toList()
          ..sort();

        result[city] = districts;
      }
    }

    _cache = result;
    return result;
  }

  static Future<List<String>> cities() async {
    final Map<String, List<String>> data = await load();
    final List<String> cities = data.keys.toList()..sort();
    return cities;
  }

  static Future<List<String>> districtsOf(String city) async {
    final Map<String, List<String>> data = await load();

    return List<String>.from(
      data[city] ?? const <String>[],
    );
  }
}