import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/listing/domain/service_request_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('çoklu hizmet talebini tek paket kimliğiyle ilanlara dönüştürür', () {
    const draft = ServiceRequestDraft(
      id: 'bundle-1',
      location: ServiceRequestLocationDraft(
        precision: LocationPrecision.neighborhood,
        latitude: 39.93,
        longitude: 32.85,
      ),
      items: [
        ServiceRequestItemDraft(
          category: ServiceCategory.plumbing,
          title: 'Tesisatçı lazım',
          description: 'Mutfak musluğu değişecek.',
          priceAmount: 1000,
          pricingUnit: PricingUnit.fixed,
          priceIncludesVat: true,
          scheduleNote: 'Cumartesi öğleden sonra',
          isUrgent: false,
        ),
        ServiceRequestItemDraft(
          category: ServiceCategory.electrician,
          title: 'Elektrikçi lazım',
          description: 'İki priz kontrol edilecek.',
          priceAmount: 0,
          pricingUnit: PricingUnit.negotiable,
          priceIncludesVat: false,
          scheduleNote: 'Aynı gün',
          isUrgent: true,
        ),
      ],
    );

    final listings = draft.toListings(ownerName: 'Test kullanıcısı');

    expect(listings, hasLength(2));
    expect(listings.map((item) => item.bundleId), everyElement('bundle-1'));
    expect(listings.map((item) => item.bundleItemCount), everyElement(2));
    expect(listings.first.locationPrecision, LocationPrecision.neighborhood);
    expect(listings.first.neighborhood, 'Haritadan seçilen yakın konum');
    expect(listings.last.category, ServiceCategory.electrician);
  });
}
