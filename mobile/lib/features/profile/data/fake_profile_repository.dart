import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/profile/domain/profile_repository.dart';
import 'package:ankara_proje/features/profile/domain/provider_profile.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<void> removeAvatar(String avatarUrl) async {}
  static const _profiles = <String, ProviderProfile>{
    'provider-tire': ProviderProfile(
      id: 'provider-tire',
      displayName: 'Özkan Mobil Lastik',
      bio:
          'Ankara içinde mobil lastik tamiri yapıyorum. Binek araçlara yerinde müdahale, lastik değişimi ve yol yardım hizmeti veriyorum.',
      district: 'Çankaya, Ankara',
      memberSinceLabel: '2024’ten beri üye',
      rating: 4.9,
      reviewCount: 38,
      completedJobs: 126,
      isVerified: true,
      services: [
        ProviderService(
          category: ServiceCategory.tireRepair,
          title: 'Yerinde lastik tamiri',
          description: 'Patlak onarımı ve yedek lastik değişimi.',
          priceLabel: '850 ₺’den başlayan',
          availabilityLabel: 'Her gün 08.00–23.00',
          availableNow: true,
        ),
      ],
      reviews: [
        ProviderReview(
          authorName: 'Mert A.',
          rating: 5,
          comment: 'Gece kısa sürede geldi, çok yardımcı oldu.',
          dateLabel: '2 hafta önce',
        ),
        ProviderReview(
          authorName: 'Ece K.',
          rating: 4.8,
          comment: 'Fiyatı önceden söyledi ve temiz çalıştı.',
          dateLabel: '1 ay önce',
        ),
      ],
    ),
    'provider-cleaning': ProviderProfile(
      id: 'provider-cleaning',
      displayName: 'Ayşe K.',
      bio: 'Düzenli ev, taşınma sonrası ve küçük ofis temizliği yapıyorum.',
      district: 'Keçiören, Ankara',
      memberSinceLabel: '2025’ten beri üye',
      rating: 4.7,
      reviewCount: 19,
      completedJobs: 54,
      isVerified: false,
      services: [
        ProviderService(
          category: ServiceCategory.cleaning,
          title: 'Ev ve ofis temizliği',
          description: 'Malzemeli veya malzemesiz temizlik.',
          priceLabel: '1.400 ₺ / gün',
          availabilityLabel: 'Hafta içi 09.00–18.00',
          availableNow: false,
        ),
      ],
      reviews: [
        ProviderReview(
          authorName: 'Selin T.',
          rating: 4.7,
          comment: 'Zamanında geldi, ev çok güzel temizlendi.',
          dateLabel: '3 hafta önce',
        ),
      ],
    ),
    'current-user': ProviderProfile(
      id: 'current-user',
      displayName: 'Alperen',
      bio:
          'Boş zamanlarımda kurye ve günlük servis desteği verebilirim. Ankara içinde çalışıyorum.',
      district: 'Ankara',
      memberSinceLabel: 'Yeni üye',
      rating: 4.8,
      reviewCount: 6,
      completedJobs: 11,
      isVerified: false,
      services: [
        ProviderService(
          category: ServiceCategory.courier,
          title: 'Motorlu kurye desteği',
          description: 'Saatlik veya günlük teslimat desteği.',
          priceLabel: '300 ₺ / saat',
          availabilityLabel: 'Hafta içi 18.00 sonrası',
          availableNow: true,
        ),
        ProviderService(
          category: ServiceCategory.waiter,
          title: 'Günlük garsonluk',
          description: 'Etkinlik ve yoğun günlerde servis desteği.',
          priceLabel: '1.200 ₺ / gün',
          availabilityLabel: 'Hafta sonu',
          availableNow: false,
        ),
      ],
      reviews: [
        ProviderReview(
          authorName: 'Bahçe Restoran',
          rating: 5,
          comment: 'Yoğun akşamda hızlı adapte oldu.',
          dateLabel: '1 hafta önce',
        ),
        ProviderReview(
          authorName: 'Mavi Market',
          rating: 4.6,
          comment: 'Teslimatlarda düzenli ve iletişimi iyiydi.',
          dateLabel: '1 ay önce',
        ),
      ],
    ),
  };

  @override
  Future<ProviderProfile?> findById(String providerId) async {
    return _profiles[providerId] ?? _fallback(providerId);
  }

  @override
  Future<ProviderProfile> currentUserProfile() async {
    return _profiles['current-user']!;
  }

  @override
  Future<ProfileSettings> currentUserSettings() async => const ProfileSettings(
    displayName: 'Alperen',
    bio: 'Boş zamanlarımda kurye ve günlük servis desteği verebilirim.',
    city: 'Ankara',
    district: 'Çankaya',
    receiveCategoryIds: <String>{},
    provideCategoryIds: <String>{'courier_transport'},
  );

  @override
  Future<void> updateCurrentUserDetails({
    required String displayName,
    required String city,
    required String district,
    required String bio,
    required GenderOption? gender,
    required Set<String> receiveCategoryIds,
    required Set<String> provideCategoryIds,
  }) async {}

  @override
  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async => null;

  ProviderProfile _fallback(String providerId) {
    return ProviderProfile(
      id: providerId,
      displayName: 'Hizmet veren',
      bio: 'Bu kullanıcı henüz profil açıklaması eklemedi.',
      district: 'Ankara',
      memberSinceLabel: 'Yeni üye',
      rating: 0,
      reviewCount: 0,
      completedJobs: 0,
      isVerified: false,
      services: const [],
      reviews: const [],
    );
  }
}
