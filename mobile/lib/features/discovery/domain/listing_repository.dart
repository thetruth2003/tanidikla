import 'package:ankara_proje/features/discovery/domain/service_listing.dart';

abstract interface class ListingRepository {
  Future<List<ServiceListing>> fetchActiveListings();

  Future<List<ServiceListing>> searchListings(ListingSearchQuery query) =>
      fetchActiveListings();

  Future<ServiceListing?> findById(String listingId);

  Future<List<ServiceListing>> findBundleItems(String bundleId);

  Future<List<ServiceListing>> findByOwnerId(String ownerId);

  Future<String?> addListings(List<ServiceListing> listings);

  Future<void> uploadListingImage({
    required String listingId,
    required List<int> bytes,
    required String filename,
  });

  Future<void> updateListings(String listingId, List<ServiceListing> listings);

  Future<void> removeListing(String listingId);
}

class ListingSearchQuery {
  const ListingSearchQuery({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 60000,
    this.type,
    this.term = '',
    this.categoryId,
    this.urgent = false,
    this.hasSchedule = false,
    this.vatIncluded = false,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.pricingUnit,
    this.locationPrecision,
    this.providerKind,
    this.gender,
    this.limit = 50,
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;
  final ListingType? type;
  final String term;
  final String? categoryId;
  final bool urgent;
  final bool hasSchedule;
  final bool vatIncluded;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final PricingUnit? pricingUnit;
  final LocationPrecision? locationPrecision;
  final String? providerKind;
  final String? gender;
  final int limit;
}
