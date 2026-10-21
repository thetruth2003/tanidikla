import 'dart:convert';

import 'package:flutter/services.dart';

class TurkeyLocationCatalog {
  TurkeyLocationCatalog._(this._districtsByProvince);

  static Future<TurkeyLocationCatalog>? _cached;

  final Map<String, List<String>> _districtsByProvince;

  static Future<TurkeyLocationCatalog> load() => _cached ??= _load();

  static Future<TurkeyLocationCatalog> _load() async {
    final raw = await rootBundle.loadString(
      'assets/data/turkey_locations.json',
    );
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return TurkeyLocationCatalog._({
      for (final entry in decoded.entries)
        entry.key: List<String>.unmodifiable(
          (entry.value as List).map((value) => value.toString()),
        ),
    });
  }

  List<String> get provinces =>
      List<String>.unmodifiable(_districtsByProvince.keys);

  List<String> districtsFor(String? province) =>
      List<String>.unmodifiable(_districtsByProvince[province] ?? const []);

  bool contains(String province, String district) =>
      _districtsByProvince[province]?.contains(district) ?? false;
}
