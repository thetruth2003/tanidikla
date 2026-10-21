import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kategori ağacı 7 ana başlık ve 41 alt kategori içerir', () {
    expect(ServiceCategoryGroup.values, hasLength(7));
    expect(ServiceCategory.values, hasLength(41));
    expect(
      ServiceCategory.values.where((category) => category.isOpenEnded),
      hasLength(7),
    );
  });

  test('kategori veritabanı kimlikleri benzersiz ve geri çözülebilir', () {
    final values = ServiceCategory.values
        .map((category) => category.dbValue)
        .toSet();
    expect(values, hasLength(ServiceCategory.values.length));

    for (final category in ServiceCategory.values) {
      expect(serviceCategoryFromDbValue(category.dbValue), category);
      expect(category.group.categories, contains(category));
    }
  });
}
