import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/data/fake_listing_repository.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('liste, profil ve detay aynı ilan sorgusunu paylaşır', () async {
    final repository = _CountingListingRepository();
    final container = ProviderContainer(
      overrides: [listingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await Future.wait([
      container.read(activeListingsProvider.future),
      container.read(listingByIdProvider('offer-tire-1').future),
      container.read(listingsByOwnerProvider('provider-tire').future),
    ]);

    expect(repository.fetchCount, 1);
  });
}

class _CountingListingRepository extends FakeListingRepository {
  int fetchCount = 0;

  @override
  Future<List<ServiceListing>> fetchActiveListings() {
    fetchCount++;
    return super.fetchActiveListings();
  }
}
