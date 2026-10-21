import 'package:ankara_proje/core/config/app_environment.dart';
import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/discovery/domain/listing_repository.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';

class ApiListingRepository implements ListingRepository {
  ApiListingRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<ServiceListing>> fetchActiveListings() async {
    return searchListings(
      const ListingSearchQuery(latitude: 39.0, longitude: 35.0),
    );
  }

  @override
  Future<List<ServiceListing>> searchListings(ListingSearchQuery query) async {
    final data = await _client.get(
      '/listings',
      query: {
        'lat': query.latitude,
        'lng': query.longitude,
        'radius_meters': query.radiusMeters,
        'limit': query.limit,
        'sort': 'distance',
        if (query.type != null)
          'type': switch (query.type!) {
            ListingType.serviceOffer => 'service_offer',
            ListingType.serviceRequest => 'service_request',
          },
        if (query.term.trim().isNotEmpty) 'q': query.term.trim(),
        if (query.categoryId != null) 'category': query.categoryId!,
        if (query.urgent) 'urgent': true,
        if (query.hasSchedule) 'has_schedule': true,
        if (query.vatIncluded) 'vat_included': true,
        if (query.minPrice != null) 'min_price': query.minPrice!,
        if (query.maxPrice != null) 'max_price': query.maxPrice!,
        if (query.minRating != null) 'min_rating': query.minRating!,
        if (query.pricingUnit != null)
          'pricing_unit': query.pricingUnit!.apiValue,
        if (query.locationPrecision != null)
          'location_precision': query.locationPrecision!.name,
        if (query.providerKind != null) 'provider_kind': query.providerKind!,
        if (query.gender != null) 'gender': query.gender!,
      },
    );
    return _maps(data['items']).map(_fromSearchRow).toList(growable: false);
  }

  @override
  Future<ServiceListing?> findById(String listingId) async {
    try {
      final parent = await _client.get('/listings/$listingId');
      final items = _maps(parent['items']);
      if (items.isEmpty) return null;
      return _fromDetailItem(parent, items.first, 0, items.length);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<ServiceListing>> findBundleItems(String bundleId) async {
    final parent = await _client.get('/listings/$bundleId');
    final items = _maps(parent['items']);
    return [
      for (var index = 0; index < items.length; index++)
        _fromDetailItem(parent, items[index], index, items.length),
    ];
  }

  @override
  Future<List<ServiceListing>> findByOwnerId(String ownerId) async {
    final data = await _client.get(
      '/users/$ownerId/listings',
      query: const {'limit': 50},
    );
    return _maps(data['items']).map(_fromSearchRow).toList(growable: false);
  }

  @override
  Future<String?> addListings(List<ServiceListing> listings) async {
    if (listings.isEmpty) return null;
    final created = await _client.post('/listings', body: _payload(listings));
    return created['id']?.toString();
  }

  @override
  Future<void> uploadListingImage({
    required String listingId,
    required List<int> bytes,
    required String filename,
  }) async {
    await _client.uploadImage(
      '/uploads/images',
      bytes: bytes,
      filename: filename,
      fields: {'purpose': 'listing', 'listing_id': listingId},
    );
  }

  @override
  Future<void> updateListings(
    String listingId,
    List<ServiceListing> listings,
  ) async {
    if (listings.isEmpty) return;
    await _client.put('/listings/$listingId', body: _payload(listings));
  }

  @override
  Future<void> removeListing(String listingId) async {
    await _client.delete('/listings/$listingId');
  }

  Map<String, Object?> _payload(List<ServiceListing> listings) {
    final first = listings.first;
    return {
      'listing_type': switch (first.type) {
        ListingType.serviceOffer => 'service_offer',
        ListingType.serviceRequest => 'service_request',
      },
      'location': {
        'latitude': first.latitude,
        'longitude': first.longitude,
        'city': first.city.isEmpty ? first.district : first.city,
        'district': first.district,
        'neighborhood': first.neighborhood,
        'precision': first.locationPrecision.name,
      },
      if (first.locationPrecision == LocationPrecision.exact)
        'private_address': {
          'city': first.city.isEmpty ? first.district : first.city,
          'district': first.privateDistrict,
          'neighborhood': first.privateNeighborhood,
          'street': first.privateStreet,
          'building_number': first.privateBuildingNumber,
        },
      'expires_at': first.expiresAt?.toUtc().toIso8601String(),
      if (first.serviceRadiusKm != null)
        'service_radius_km': first.serviceRadiusKm,
      if (first.preferredProviderKind != null)
        'preferred_provider_kind': first.preferredProviderKind,
      if (first.preferredProviderGender != null)
        'preferred_provider_gender': first.preferredProviderGender,
      'items': [
        for (final listing in listings)
          {
            'category_id': listing.category.dbValue,
            'title': listing.title.trim(),
            'description': listing.description.trim(),
            'schedule_label': listing.availabilityLabel.trim(),
            'price_amount':
                {
                  PricingUnit.negotiable,
                  PricingUnit.free,
                }.contains(listing.pricingUnit)
                ? null
                : listing.priceAmount,
            'pricing_unit': listing.pricingUnit.apiValue,
            'currency': 'TRY',
            'is_active': true,
            'price_includes_vat': listing.priceIncludesVat,
            'urgent': listing.availableNow,
          },
      ],
    };
  }
}

ServiceListing _fromSearchRow(Map<String, dynamic> row) => ServiceListing(
  id: row['item_id']?.toString() ?? row['id'].toString(),
  ownerId: row['owner_id']?.toString() ?? '',
  ownerName: row['owner_name']?.toString() ?? 'Kullanıcı',
  title: row['title']?.toString() ?? '',
  description: row['description']?.toString() ?? '',
  type: _listingType(row['listing_type']),
  category: serviceCategoryFromDbValue(row['category_id']?.toString()),
  priceAmount: _double(row['price_amount']),
  pricingUnit: _pricingUnit(row['pricing_unit']),
  priceIncludesVat: row['price_includes_vat'] == true,
  district: row['public_district']?.toString() ?? '',
  neighborhood: row['public_neighborhood']?.toString() ?? '',
  latitude: _double(row['latitude']),
  longitude: _double(row['longitude']),
  locationPrecision: _locationPrecision(row['location_precision']),
  distanceKm: _double(row['distance_meters']) / 1000,
  availableNow: row['urgent'] == true,
  availabilityLabel: row['schedule_label']?.toString() ?? '',
  ownerRating: _double(row['owner_rating']),
  ownerReviewCount: _int(row['owner_review_count']),
  bundleId: row['id']?.toString(),
  bundleItemCount: _int(row['item_count']).clamp(1, 10),
  expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
  city: row['public_city']?.toString() ?? '',
  serviceRadiusKm: row['service_radius_km'] == null
      ? null
      : _int(row['service_radius_km']).clamp(1, 100),
  preferredProviderKind: row['preferred_provider_kind']?.toString(),
  preferredProviderGender: row['preferred_provider_gender']?.toString(),
  imageUrls: row['cover_image']?.toString().isNotEmpty == true
      ? [_absoluteMediaUrl(row['cover_image'])!]
      : _strings(row['image_urls'])
            .map((url) => _absoluteMediaUrl(url) ?? '')
            .where((url) => url.isNotEmpty)
            .toList(growable: false),
);

ServiceListing _fromDetailItem(
  Map<String, dynamic> parent,
  Map<String, dynamic> item,
  int index,
  int itemCount,
) => ServiceListing(
  id: item['id']?.toString() ?? parent['id'].toString(),
  ownerId: parent['owner_id']?.toString() ?? '',
  ownerName: parent['owner_name']?.toString() ?? 'Kullanıcı',
  title: item['title']?.toString() ?? '',
  description: item['description']?.toString() ?? '',
  type: _listingType(parent['listing_type']),
  category: serviceCategoryFromDbValue(item['category_id']?.toString()),
  priceAmount: _double(item['price_amount']),
  pricingUnit: _pricingUnit(item['pricing_unit']),
  priceIncludesVat: item['price_includes_vat'] == true,
  district: parent['public_district']?.toString() ?? '',
  neighborhood: parent['public_neighborhood']?.toString() ?? '',
  latitude: _double(parent['latitude']),
  longitude: _double(parent['longitude']),
  locationPrecision: _locationPrecision(parent['location_precision']),
  distanceKm: 0,
  availableNow: item['urgent'] == true,
  availabilityLabel: item['schedule_label']?.toString() ?? '',
  ownerRating: _double(parent['owner_rating']),
  ownerReviewCount: _int(parent['owner_review_count']),
  bundleId: parent['id']?.toString(),
  bundleItemIndex: _int(item['page_index'] ?? index),
  bundleItemCount: itemCount,
  expiresAt: DateTime.tryParse(parent['expires_at']?.toString() ?? ''),
  city: parent['public_city']?.toString() ?? '',
  serviceRadiusKm: parent['service_radius_km'] == null
      ? null
      : _int(parent['service_radius_km']).clamp(1, 100),
  preferredProviderKind: parent['preferred_provider_kind']?.toString(),
  preferredProviderGender: parent['preferred_provider_gender']?.toString(),
  imageUrls: _maps(parent['images'])
      .map(
        (image) =>
            _absoluteMediaUrl(image['url'] ?? image['storage_path']) ?? '',
      )
      .where((url) => url.isNotEmpty)
      .toList(growable: false),
);

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

String? _absoluteMediaUrl(Object? value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final apiUri = Uri.parse(AppEnvironment.apiBaseUrl);
  return '${apiUri.scheme}://${apiUri.authority}${raw.startsWith('/') ? raw : '/$raw'}';
}

double _double(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

ListingType _listingType(Object? value) => value == 'service_request'
    ? ListingType.serviceRequest
    : ListingType.serviceOffer;

PricingUnit _pricingUnit(Object? value) => switch (value?.toString()) {
  'fixed' => PricingUnit.fixed,
  'hourly' => PricingUnit.hourly,
  'daily' => PricingUnit.daily,
  'per_session' => PricingUnit.perSession,
  'starting_at' => PricingUnit.startingAt,
  'free' => PricingUnit.free,
  _ => PricingUnit.negotiable,
};

LocationPrecision _locationPrecision(Object? value) =>
    value == 'exact' ? LocationPrecision.exact : LocationPrecision.neighborhood;
