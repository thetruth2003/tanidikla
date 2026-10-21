import 'package:ankara_proje/features/profile/data/turkey_location_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sabit Türkiye konum listesi 81 il ve 973 ilçe içerir', () async {
    final catalog = await TurkeyLocationCatalog.load();
    final districtCount = catalog.provinces
        .map(catalog.districtsFor)
        .fold<int>(0, (total, districts) => total + districts.length);

    expect(catalog.provinces, hasLength(81));
    expect(districtCount, 973);
    expect(catalog.contains('Ankara', 'Çankaya'), isTrue);
    expect(catalog.contains('İstanbul', 'Şişli'), isTrue);
    expect(catalog.contains('İzmir', 'Çeşme'), isTrue);
  });
}
