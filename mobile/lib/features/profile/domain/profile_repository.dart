import 'package:ankara_proje/features/profile/domain/provider_profile.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';

abstract interface class ProfileRepository {
  Future<ProviderProfile?> findById(String providerId);

  Future<ProviderProfile> currentUserProfile();

  Future<ProfileSettings> currentUserSettings();

  Future<void> updateCurrentUserDetails({
    required String displayName,
    required String city,
    required String district,
    required String bio,
    required GenderOption? gender,
    required Set<String> receiveCategoryIds,
    required Set<String> provideCategoryIds,
  });

  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String filename,
  });

  Future<void> removeAvatar(String avatarUrl);
}
