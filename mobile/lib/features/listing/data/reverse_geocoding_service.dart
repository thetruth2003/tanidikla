import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ResolvedAddress {
  const ResolvedAddress({
    required this.displayName,
    required this.district,
    required this.neighborhood,
    required this.street,
    required this.buildingNumber,
    required this.city,
  });

  final String displayName;
  final String district;
  final String neighborhood;
  final String street;
  final String buildingNumber;
  final String city;
}

abstract interface class ReverseGeocodingService {
  Future<ResolvedAddress> resolve(LatLng point);
}

class NominatimReverseGeocodingService implements ReverseGeocodingService {
  NominatimReverseGeocodingService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<ResolvedAddress> resolve(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'addressdetails': '1',
      'accept-language': 'tr',
      'zoom': '18',
    });
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'Tanidikla/1.0 (com.example.ankara_proje)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Adres servisi ${response.statusCode} yanıtını verdi.');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Adres yanıtı okunamadı.');
    }
    final rawAddress = json['address'];
    final address = rawAddress is Map<String, dynamic>
        ? rawAddress
        : const <String, dynamic>{};
    final displayName = (json['display_name'] as String?)?.trim();

    return ResolvedAddress(
      displayName: displayName?.isNotEmpty == true
          ? displayName!
          : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      city: _first(address, const [
        'city',
        'town',
        'municipality',
        'province',
        'state',
      ]),
      district: _first(address, const [
        'town',
        'city_district',
        'county',
        'city',
      ]),
      neighborhood: _first(address, const [
        'neighbourhood',
        'suburb',
        'quarter',
        'village',
      ]),
      street: _first(address, const ['road', 'pedestrian', 'residential']),
      buildingNumber: _first(address, const ['house_number']),
    );
  }

  String _first(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}

final reverseGeocodingServiceProvider = Provider<ReverseGeocodingService>(
  (ref) => NominatimReverseGeocodingService(),
);
