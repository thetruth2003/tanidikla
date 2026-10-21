import 'package:ankara_proje/features/discovery/domain/listing_repository.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';

class FakeListingRepository implements ListingRepository {
  final List<ServiceListing> _listings = [
    const ServiceListing(
      id: 'offer-tire-1',
      ownerId: 'provider-tire',
      ownerName: 'Özkan Mobil Lastik',
      title: 'Yerinde lastik tamiri',
      description:
          'Binek araçlara yerinde lastik tamiri ve değişimi yapıyorum.',
      type: ListingType.serviceOffer,
      category: ServiceCategory.tireRepair,
      priceAmount: 850,
      pricingUnit: PricingUnit.fixed,
      priceIncludesVat: true,
      district: 'Çankaya',
      neighborhood: 'Bahçelievler',
      latitude: 39.9231,
      longitude: 32.8257,
      locationPrecision: LocationPrecision.exact,
      distanceKm: 1.2,
      availableNow: true,
      availabilityLabel: 'Her gün 08.00–23.00',
      ownerRating: 4.9,
      ownerReviewCount: 38,
    ),
    const ServiceListing(
      id: 'offer-cleaning-1',
      ownerId: 'provider-cleaning',
      ownerName: 'Ayşe K.',
      title: 'Ev ve ofis temizliği',
      description: 'Hafta içi ev ve küçük ofis temizliği için müsaitim.',
      type: ListingType.serviceOffer,
      category: ServiceCategory.cleaning,
      priceAmount: 1400,
      pricingUnit: PricingUnit.daily,
      priceIncludesVat: false,
      district: 'Keçiören',
      neighborhood: 'Etlik',
      latitude: 39.9785,
      longitude: 32.8339,
      locationPrecision: LocationPrecision.neighborhood,
      distanceKm: 4.8,
      availableNow: false,
      availabilityLabel: 'Hafta içi 09.00–18.00',
      ownerRating: 4.7,
      ownerReviewCount: 19,
    ),
    const ServiceListing(
      id: 'offer-painter-1',
      ownerId: 'provider-painter',
      ownerName: 'Metin Usta',
      title: 'Boya badana işleri',
      description: 'Daire, oda ve iş yeri boya badana hizmeti veriyorum.',
      type: ListingType.serviceOffer,
      category: ServiceCategory.painter,
      priceAmount: 0,
      pricingUnit: PricingUnit.negotiable,
      priceIncludesVat: false,
      district: 'Yenimahalle',
      neighborhood: 'Demetevler',
      latitude: 39.9654,
      longitude: 32.7948,
      locationPrecision: LocationPrecision.neighborhood,
      distanceKm: 6.1,
      availableNow: true,
      availabilityLabel: 'Pazartesi–Cumartesi 08.30–19.00',
      ownerRating: 4.8,
      ownerReviewCount: 27,
    ),
    const ServiceListing(
      id: 'offer-courier-1',
      ownerId: 'current-user',
      ownerName: 'Emre D.',
      title: 'Motorlu kurye hizmeti',
      description:
          'Motorum ve geniş çantam var. Günlük veya saatlik çalışırım.',
      type: ListingType.serviceOffer,
      category: ServiceCategory.courier,
      priceAmount: 300,
      pricingUnit: PricingUnit.hourly,
      priceIncludesVat: false,
      district: 'Çankaya',
      neighborhood: 'Kızılay',
      latitude: 39.9208,
      longitude: 32.8541,
      locationPrecision: LocationPrecision.neighborhood,
      distanceKm: 2.3,
      availableNow: true,
      availabilityLabel: 'Hafta içi 18.00 sonrası',
      ownerRating: 4.8,
      ownerReviewCount: 6,
    ),
    ServiceListing(
      id: 'request-waiter-1',
      ownerId: 'current-user',
      ownerName: 'Bahçe Restoran',
      title: 'Bu akşam garson gerekli',
      description: '18.00–23.30 arasında deneyimli bir garson arıyoruz.',
      type: ListingType.serviceRequest,
      category: ServiceCategory.waiter,
      priceAmount: 1200,
      pricingUnit: PricingUnit.fixed,
      priceIncludesVat: true,
      district: 'Çankaya',
      neighborhood: 'Bahçelievler',
      latitude: 39.9255,
      longitude: 32.8281,
      locationPrecision: LocationPrecision.exact,
      distanceKm: 1.5,
      availableNow: true,
      availabilityLabel: 'Bugün 18.00–23.30',
      expiresAt: DateTime.now().add(const Duration(hours: 10)),
    ),
    ServiceListing(
      id: 'request-cleaning-1',
      ownerId: 'requester-deniz',
      ownerName: 'Deniz A.',
      title: 'Daire temizliği için yardım',
      description: 'Cumartesi günü 3+1 boş daire temizlenecek.',
      type: ListingType.serviceRequest,
      category: ServiceCategory.cleaning,
      priceAmount: 1800,
      pricingUnit: PricingUnit.fixed,
      priceIncludesVat: false,
      district: 'Gölbaşı',
      neighborhood: 'İncek',
      latitude: 39.8075,
      longitude: 32.7214,
      locationPrecision: LocationPrecision.neighborhood,
      distanceKm: 16.4,
      availableNow: false,
      availabilityLabel: 'Cumartesi 10.00–17.00',
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    ),
    ServiceListing(
      id: 'request-painter-1',
      ownerId: 'requester-selin',
      ownerName: 'Selin T.',
      title: 'Tek oda boyanacak',
      description: 'Malzeme hazır. Hafta sonu gelebilecek usta arıyorum.',
      type: ListingType.serviceRequest,
      category: ServiceCategory.painter,
      priceAmount: 2500,
      pricingUnit: PricingUnit.fixed,
      priceIncludesVat: false,
      district: 'Keçiören',
      neighborhood: 'Kalaba',
      latitude: 39.9851,
      longitude: 32.8602,
      locationPrecision: LocationPrecision.neighborhood,
      distanceKm: 7.2,
      availableNow: false,
      availabilityLabel: 'Bu hafta sonu',
      expiresAt: DateTime.now().add(const Duration(days: 5)),
    ),
    ServiceListing(
      id: 'request-courier-1',
      ownerId: 'requester-market',
      ownerName: 'Mavi Market',
      title: 'Bugün motorlu kurye lazım',
      description: '12.00–20.00 arası market teslimatlarına destek aranıyor.',
      type: ListingType.serviceRequest,
      category: ServiceCategory.courier,
      priceAmount: 1700,
      pricingUnit: PricingUnit.daily,
      priceIncludesVat: true,
      district: 'Yenimahalle',
      neighborhood: 'Batıkent',
      latitude: 39.9667,
      longitude: 32.7177,
      locationPrecision: LocationPrecision.exact,
      distanceKm: 10.8,
      availableNow: true,
      availabilityLabel: 'Bugün 12.00–20.00',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    ),
  ];

  @override
  Future<List<ServiceListing>> fetchActiveListings() async {
    return List.unmodifiable(_listings);
  }

  @override
  Future<List<ServiceListing>> searchListings(ListingSearchQuery query) =>
      fetchActiveListings();

  @override
  Future<ServiceListing?> findById(String listingId) async {
    for (final listing in _listings) {
      if (listing.id == listingId) return listing;
    }
    return null;
  }

  @override
  Future<List<ServiceListing>> findBundleItems(String bundleId) async {
    final items =
        _listings.where((listing) => listing.bundleId == bundleId).toList()
          ..sort((a, b) => a.bundleItemIndex.compareTo(b.bundleItemIndex));
    return List.unmodifiable(items);
  }

  @override
  Future<List<ServiceListing>> findByOwnerId(String ownerId) async {
    return List.unmodifiable(
      _listings.where((listing) => listing.ownerId == ownerId),
    );
  }

  @override
  Future<String?> addListings(List<ServiceListing> listings) async {
    _listings.addAll(listings);
    return listings.firstOrNull?.bundleId ?? listings.firstOrNull?.id;
  }

  @override
  Future<void> uploadListingImage({
    required String listingId,
    required List<int> bytes,
    required String filename,
  }) async {}

  @override
  Future<void> updateListings(
    String listingId,
    List<ServiceListing> listings,
  ) async {
    for (final updated in listings) {
      final index = _listings.indexWhere((item) => item.id == updated.id);
      if (index != -1) _listings[index] = updated;
    }
  }

  @override
  Future<void> removeListing(String listingId) async {
    _listings.removeWhere(
      (listing) => listing.id == listingId || listing.bundleId == listingId,
    );
  }
}
