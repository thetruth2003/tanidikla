import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/profile/data/api_profile_repository.dart';
import 'package:ankara_proje/features/profile/data/fake_profile_repository.dart';
import 'package:ankara_proje/features/profile/domain/profile_repository.dart';
import 'package:ankara_proje/features/profile/domain/provider_profile.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';
import 'package:ankara_proje/features/profile/data/turkey_location_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => apiAuthSession.initialized
      ? ApiProfileRepository(apiClient)
      : FakeProfileRepository(),
);

final providerProfileProvider = FutureProvider.family<ProviderProfile?, String>(
  (ref, providerId) {
    return ref.watch(profileRepositoryProvider).findById(providerId);
  },
);

final currentUserProfileProvider = FutureProvider<ProviderProfile>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).currentUserProfile();
});

final currentUserProfileSettingsProvider = FutureProvider<ProfileSettings>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).currentUserSettings();
});

final turkeyLocationCatalogProvider = FutureProvider<TurkeyLocationCatalog>(
  (ref) => TurkeyLocationCatalog.load(),
);

final currentUserProfileCompleteProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (apiAuthSession.initialized && userId == null) return false;

  final profile = await ref.watch(currentUserProfileSettingsProvider.future);
  return profile.displayName.trim().length >= 2 &&
      profile.city.trim().length >= 2 &&
      profile.district.trim().length >= 2;
});
