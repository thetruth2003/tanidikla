import 'package:ankara_proje/features/discovery/domain/service_listing.dart';

class ServiceRequestLocationDraft {
  const ServiceRequestLocationDraft({
    required this.precision,
    required this.latitude,
    required this.longitude,
    this.district = '',
    this.neighborhood = '',
    this.street = '',
    this.buildingNumber = '',
    this.city = '',
    this.serviceRadiusKm,
  });

  final LocationPrecision precision;
  final double latitude;
  final double longitude;
  final String district;
  final String neighborhood;
  final String street;
  final String buildingNumber;
  final String city;
  final int? serviceRadiusKm;

  String get publicDistrict =>
      district.trim().isEmpty ? 'Haritadan seçilen bölge' : district.trim();

  String get publicNeighborhood => precision == LocationPrecision.exact
      ? neighborhood.trim()
      : 'Haritadan seçilen yakın konum';
}

class ServiceRequestItemDraft {
  const ServiceRequestItemDraft({
    required this.category,
    required this.title,
    required this.description,
    required this.priceAmount,
    required this.pricingUnit,
    required this.priceIncludesVat,
    required this.scheduleNote,
    required this.isUrgent,
    this.expiresAt,
    this.preferredProviderKind,
    this.preferredProviderGender,
  });

  final ServiceCategory category;
  final String title;
  final String description;
  final double priceAmount;
  final PricingUnit pricingUnit;
  final bool priceIncludesVat;
  final String scheduleNote;
  final bool isUrgent;
  final DateTime? expiresAt;
  final String? preferredProviderKind;
  final String? preferredProviderGender;
}

class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.id,
    required this.location,
    required this.items,
  });

  final String id;
  final ServiceRequestLocationDraft location;
  final List<ServiceRequestItemDraft> items;

  List<ServiceListing> toListings({
    required String ownerName,
    String ownerId = 'current-user',
  }) {
    return [
      for (var index = 0; index < items.length; index++)
        ServiceListing(
          id: '$id-${items[index].category.name}-$index',
          ownerId: ownerId,
          ownerName: ownerName,
          title: items[index].title.trim(),
          description: items[index].description.trim(),
          type: ListingType.serviceRequest,
          category: items[index].category,
          priceAmount: items[index].priceAmount,
          pricingUnit: items[index].pricingUnit,
          priceIncludesVat: items[index].priceIncludesVat,
          district: location.publicDistrict,
          neighborhood: location.publicNeighborhood,
          latitude: location.latitude,
          longitude: location.longitude,
          locationPrecision: location.precision,
          distanceKm: 0,
          availableNow: items[index].isUrgent,
          availabilityLabel: items[index].scheduleNote.trim(),
          bundleId: id,
          bundleItemIndex: index,
          bundleItemCount: items.length,
          expiresAt: items[index].expiresAt,
          privateDistrict: location.district.trim(),
          privateNeighborhood: location.neighborhood.trim(),
          privateStreet: location.street.trim(),
          privateBuildingNumber: location.buildingNumber.trim(),
          city: location.city.trim(),
          serviceRadiusKm: location.serviceRadiusKm,
          preferredProviderKind: items[index].preferredProviderKind,
          preferredProviderGender: items[index].preferredProviderGender,
        ),
    ];
  }
}
