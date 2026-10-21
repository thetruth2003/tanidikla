import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/core/location/user_location.dart';
import 'package:ankara_proje/features/discovery/data/api_listing_repository.dart';
import 'package:ankara_proje/features/discovery/data/fake_listing_repository.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/domain/listing_repository.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DiscoveryMode { findService, findWork }

enum DiscoveryViewMode { map, list }

class DiscoveryState {
  const DiscoveryState({
    this.mode = DiscoveryMode.findService,
    this.viewMode = DiscoveryViewMode.map,
    this.searchStarted = true,
    this.searchQuery = '',
    this.selectedGroup,
    this.selectedCategory,
    this.onlyAvailableNow = false,
    this.onlyWithWorkingHours = false,
    this.onlyVatIncluded = false,
    this.minPrice,
    this.maxPrice,
    this.maxDistanceKm,
    this.minRating,
    this.pricingUnit,
    this.locationPrecision,
    this.providerKind,
    this.gender,
  });

  final DiscoveryMode mode;
  final DiscoveryViewMode viewMode;
  final bool searchStarted;
  final String searchQuery;
  final ServiceCategoryGroup? selectedGroup;
  final ServiceCategory? selectedCategory;
  final bool onlyAvailableNow;
  final bool onlyWithWorkingHours;
  final bool onlyVatIncluded;
  final double? minPrice;
  final double? maxPrice;
  final double? maxDistanceKm;
  final double? minRating;
  final PricingUnit? pricingUnit;
  final LocationPrecision? locationPrecision;
  final String? providerKind;
  final String? gender;

  int get activeFilterCount => [
    selectedCategory ?? selectedGroup,
    onlyAvailableNow ? true : null,
    onlyWithWorkingHours ? true : null,
    onlyVatIncluded ? true : null,
    minPrice,
    maxPrice,
    maxDistanceKm,
    minRating,
    pricingUnit,
    locationPrecision,
    providerKind,
    gender,
  ].where((value) => value != null).length;

  DiscoveryState copyWith({
    DiscoveryMode? mode,
    DiscoveryViewMode? viewMode,
    bool? searchStarted,
    String? searchQuery,
    ServiceCategoryGroup? selectedGroup,
    bool clearGroup = false,
    ServiceCategory? selectedCategory,
    bool clearCategory = false,
    bool? onlyAvailableNow,
    bool? onlyWithWorkingHours,
    bool? onlyVatIncluded,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    double? maxDistanceKm,
    bool clearMaxDistance = false,
    double? minRating,
    bool clearMinRating = false,
    PricingUnit? pricingUnit,
    bool clearPricingUnit = false,
    LocationPrecision? locationPrecision,
    bool clearLocationPrecision = false,
    String? providerKind,
    bool clearProviderKind = false,
    String? gender,
    bool clearGender = false,
  }) {
    return DiscoveryState(
      mode: mode ?? this.mode,
      viewMode: viewMode ?? this.viewMode,
      searchStarted: searchStarted ?? this.searchStarted,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGroup: clearGroup ? null : selectedGroup ?? this.selectedGroup,
      selectedCategory: clearCategory
          ? null
          : selectedCategory ?? this.selectedCategory,
      onlyAvailableNow: onlyAvailableNow ?? this.onlyAvailableNow,
      onlyWithWorkingHours: onlyWithWorkingHours ?? this.onlyWithWorkingHours,
      onlyVatIncluded: onlyVatIncluded ?? this.onlyVatIncluded,
      minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
      maxDistanceKm: clearMaxDistance
          ? null
          : maxDistanceKm ?? this.maxDistanceKm,
      minRating: clearMinRating ? null : minRating ?? this.minRating,
      pricingUnit: clearPricingUnit ? null : pricingUnit ?? this.pricingUnit,
      locationPrecision: clearLocationPrecision
          ? null
          : locationPrecision ?? this.locationPrecision,
      providerKind: clearProviderKind
          ? null
          : providerKind ?? this.providerKind,
      gender: clearGender ? null : gender ?? this.gender,
    );
  }
}

class DiscoveryController extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() => const DiscoveryState();

  void setMode(DiscoveryMode mode) {
    state = state.copyWith(mode: mode, clearCategory: true, clearGroup: true);
  }

  void setViewMode(DiscoveryViewMode viewMode) {
    state = state.copyWith(
      viewMode: viewMode,
      searchStarted: state.searchStarted || viewMode == DiscoveryViewMode.map,
    );
  }

  void startMapSearch() {
    state = state.copyWith(
      searchStarted: true,
      viewMode: DiscoveryViewMode.map,
    );
  }

  void setSearchQuery(String value) {
    state = state.copyWith(
      searchQuery: value,
      searchStarted: true,
      viewMode: value.trim().isEmpty ? state.viewMode : DiscoveryViewMode.list,
    );
  }

  void selectGroup(ServiceCategoryGroup group) {
    state = state.copyWith(selectedGroup: group, clearCategory: true);
  }

  void selectCategory(ServiceCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true, clearGroup: true)
        : state.copyWith(
            selectedCategory: category,
            selectedGroup: category.group,
          );
  }

  void setOnlyAvailableNow(bool value) {
    state = state.copyWith(onlyAvailableNow: value);
  }

  void applyFilters({
    required ServiceCategoryGroup? group,
    required ServiceCategory? category,
    required bool onlyAvailableNow,
    required bool onlyWithWorkingHours,
    required bool onlyVatIncluded,
    required double? minPrice,
    required double? maxPrice,
    required double? maxDistanceKm,
    required double? minRating,
    required PricingUnit? pricingUnit,
    required LocationPrecision? locationPrecision,
    required String? providerKind,
    required String? gender,
  }) {
    state = state.copyWith(
      selectedGroup: group,
      clearGroup: group == null,
      selectedCategory: category,
      clearCategory: category == null,
      onlyAvailableNow: onlyAvailableNow,
      onlyWithWorkingHours: onlyWithWorkingHours,
      onlyVatIncluded: onlyVatIncluded,
      minPrice: minPrice,
      clearMinPrice: minPrice == null,
      maxPrice: maxPrice,
      clearMaxPrice: maxPrice == null,
      maxDistanceKm: maxDistanceKm,
      clearMaxDistance: maxDistanceKm == null,
      minRating: minRating,
      clearMinRating: minRating == null,
      pricingUnit: pricingUnit,
      clearPricingUnit: pricingUnit == null,
      locationPrecision: locationPrecision,
      clearLocationPrecision: locationPrecision == null,
      providerKind: providerKind,
      clearProviderKind: providerKind == null,
      gender: gender,
      clearGender: gender == null,
    );
  }

  void resetFilters() {
    state = state.copyWith(
      clearGroup: true,
      clearCategory: true,
      onlyAvailableNow: false,
      onlyWithWorkingHours: false,
      onlyVatIncluded: false,
      clearMinPrice: true,
      clearMaxPrice: true,
      clearMaxDistance: true,
      clearMinRating: true,
      clearPricingUnit: true,
      clearLocationPrecision: true,
      clearProviderKind: true,
      clearGender: true,
    );
  }

  void findNearestAvailableTireRepair() {
    state = state.copyWith(
      selectedCategory: ServiceCategory.tireRepair,
      selectedGroup: ServiceCategoryGroup.vehicleRoad,
      onlyAvailableNow: true,
      viewMode: DiscoveryViewMode.map,
      searchStarted: true,
    );
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => apiAuthSession.initialized
      ? ApiListingRepository(apiClient)
      : FakeListingRepository(),
);

final activeListingsProvider = FutureProvider<List<ServiceListing>>((
  ref,
) async {
  final repository = ref.watch(listingRepositoryProvider);
  if (repository is! ApiListingRepository) {
    return repository.fetchActiveListings();
  }
  final state = ref.watch(discoveryControllerProvider);
  final location = await ref.watch(userLocationProvider.future);

  return repository.searchListings(
    ListingSearchQuery(
      latitude: location.latitude,
      longitude: location.longitude,
      radiusMeters: ((state.maxDistanceKm ?? 60) * 1000).round(),
      type: state.mode == DiscoveryMode.findService
          ? ListingType.serviceOffer
          : ListingType.serviceRequest,
      term: state.searchQuery,
      categoryId: state.selectedCategory?.dbValue ?? state.selectedGroup?.id,
      urgent: state.onlyAvailableNow,
      hasSchedule: state.onlyWithWorkingHours,
      vatIncluded: state.onlyVatIncluded,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
      minRating: state.minRating,
      pricingUnit: state.pricingUnit,
      locationPrecision: state.locationPrecision,
      providerKind: state.providerKind,
      gender: state.gender,
    ),
  );
});

final listingByIdProvider = FutureProvider.family<ServiceListing?, String>(
  (ref, listingId) => ref.watch(listingRepositoryProvider).findById(listingId),
);

final listingBundleProvider =
    FutureProvider.family<List<ServiceListing>, String>((ref, bundleId) {
      return ref.watch(listingRepositoryProvider).findBundleItems(bundleId);
    });

final listingsByOwnerProvider =
    FutureProvider.family<List<ServiceListing>, String>((ref, ownerId) async {
      return ref.watch(listingRepositoryProvider).findByOwnerId(ownerId);
    });

final discoveryControllerProvider =
    NotifierProvider<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );

final visibleListingsProvider = Provider<AsyncValue<List<ServiceListing>>>((
  ref,
) {
  final state = ref.watch(discoveryControllerProvider);
  final listings = ref.watch(activeListingsProvider);

  return listings.whenData((items) {
    final expectedType = state.mode == DiscoveryMode.findService
        ? ListingType.serviceOffer
        : ListingType.serviceRequest;

    final query = _normalizeSearch(state.searchQuery.trim());
    final filtered = items.where((listing) {
      final matchesType = listing.type == expectedType;
      final matchesCategory = state.selectedCategory != null
          ? listing.category == state.selectedCategory
          : state.selectedGroup == null ||
                listing.category.group == state.selectedGroup;
      final matchesAvailability =
          !state.onlyAvailableNow || listing.availableNow;
      final hasWorkingHours =
          listing.availabilityLabel.trim().isNotEmpty &&
          listing.availabilityLabel != 'Saat bilgisi belirtilmedi';
      final matchesWorkingHours =
          !state.onlyWithWorkingHours || hasWorkingHours;
      final matchesVat = !state.onlyVatIncluded || listing.priceIncludesVat;
      final matchesPricingUnit =
          state.pricingUnit == null || listing.pricingUnit == state.pricingUnit;
      final matchesMinPrice =
          state.minPrice == null ||
          (listing.pricingUnit != PricingUnit.negotiable &&
              listing.priceAmount >= state.minPrice!);
      final matchesMaxPrice =
          state.maxPrice == null ||
          (listing.pricingUnit != PricingUnit.negotiable &&
              listing.priceAmount <= state.maxPrice!);
      final matchesDistance =
          state.maxDistanceKm == null ||
          listing.distanceKm <= state.maxDistanceKm!;
      final matchesRating =
          state.minRating == null || listing.ownerRating >= state.minRating!;
      final matchesLocationPrecision =
          state.locationPrecision == null ||
          listing.locationPrecision == state.locationPrecision;
      final matchesSearch = query.isEmpty || _searchScore(listing, query) > 0;
      return matchesType &&
          matchesCategory &&
          matchesAvailability &&
          matchesWorkingHours &&
          matchesVat &&
          matchesPricingUnit &&
          matchesMinPrice &&
          matchesMaxPrice &&
          matchesDistance &&
          matchesRating &&
          matchesLocationPrecision &&
          matchesSearch;
    });

    final bundled = <String, ServiceListing>{};
    for (final listing in filtered) {
      bundled.putIfAbsent(listing.bundleId ?? listing.id, () => listing);
    }

    final result = bundled.values.toList()
      ..sort((a, b) {
        if (query.isNotEmpty) {
          final scoreComparison = _searchScore(
            b,
            query,
          ).compareTo(_searchScore(a, query));
          if (scoreComparison != 0) return scoreComparison;
        }
        return a.distanceKm.compareTo(b.distanceKm);
      });

    return result;
  });
});

String _normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('ı', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ş', 's')
    .replaceAll('ü', 'u');

int _searchScore(ServiceListing listing, String query) {
  final title = _normalizeSearch(listing.title);
  final category = _normalizeSearch(listing.category.label);
  final group = _normalizeSearch(listing.category.group.label);

  var score = 0;
  if (title == query) {
    score += 140;
  } else if (title.startsWith(query)) {
    score += 120;
  } else if (title.contains(query)) {
    score += 100;
  }
  if (category == query) {
    score += 110;
  } else if (category.contains(query)) {
    score += 85;
  }
  if (group.contains(query)) score += 60;
  return score;
}
