import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/profile/domain/profile_repository.dart';
import 'package:ankara_proje/features/profile/domain/provider_profile.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._client);

  final ApiClient _client;

  @override
  Future<ProviderProfile?> findById(String providerId) async {
    try {
      final data = await _client.get('/profiles/$providerId');
      final createdAt = DateTime.tryParse(data['created_at']?.toString() ?? '');
      return ProviderProfile(
        id: data['id']?.toString() ?? providerId,
        displayName: data['display_name']?.toString() ?? 'Kullanıcı',
        bio: data['bio']?.toString() ?? '',
        district: data['district']?.toString() ?? '',
        memberSinceLabel: createdAt == null
            ? 'Yeni üye'
            : '${createdAt.year}’ten beri üye',
        rating: _double(data['rating']),
        reviewCount: _int(data['review_count']),
        completedJobs: _int(data['completed_jobs']),
        isVerified: data['is_verified'] == true,
        avatarUrl: _absoluteMediaUrl(data['avatar_path']),
        services: [
          for (final row in _maps(data['services']))
            ProviderService(
              category: serviceCategoryFromDbValue(
                row['category_id']?.toString(),
              ),
              title: row['title']?.toString() ?? '',
              description: row['description']?.toString() ?? '',
              priceLabel: _priceLabel(row),
              availabilityLabel: row['availability_label']?.toString() ?? '',
              availableNow: row['available_now'] == true,
            ),
        ],
        reviews: [
          for (final row in _maps(data['reviews']))
            ProviderReview(
              authorName: row['author_name']?.toString() ?? 'Kullanıcı',
              rating: _double(row['rating']),
              comment: row['comment']?.toString() ?? '',
              dateLabel: _dateLabel(row['created_at']?.toString()),
            ),
        ],
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ProviderProfile> currentUserProfile() async {
    final user = apiAuthSession.currentUser;
    if (user == null) throw StateError('Profil için giriş yapmalısın.');
    final profile = await findById(user.id);
    if (profile == null) throw StateError('Profil bulunamadı.');
    return profile;
  }

  @override
  Future<ProfileSettings> currentUserSettings() async {
    Map<String, dynamic> data;
    try {
      data = await _client.get('/profile');
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      final user = apiAuthSession.currentUser;
      if (user == null) throw StateError('Profil için giriş yapmalısın.');
      final publicProfile = await findById(user.id);
      if (publicProfile == null) throw StateError('Profil bulunamadı.');
      data = {
        'display_name': publicProfile.displayName,
        'bio': publicProfile.bio,
        'city': user.city,
        'district': publicProfile.district,
        'avatar_path': publicProfile.avatarUrl,
      };
    }
    final preferences = data['category_preferences'] is Map
        ? Map<String, dynamic>.from(data['category_preferences'] as Map)
        : const <String, dynamic>{};
    return ProfileSettings(
      displayName: data['display_name']?.toString() ?? '',
      bio: data['bio']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      district: data['district']?.toString() ?? '',
      gender: genderOptionFromDbValue(data['gender']),
      avatarUrl: _absoluteMediaUrl(data['avatar_path']),
      receiveCategoryIds: _stringSet(preferences['receive']),
      provideCategoryIds: _stringSet(preferences['provide']),
    );
  }

  @override
  Future<void> updateCurrentUserDetails({
    required String displayName,
    required String city,
    required String district,
    required String bio,
    required GenderOption? gender,
    required Set<String> receiveCategoryIds,
    required Set<String> provideCategoryIds,
  }) async {
    await _client.put(
      '/profile',
      body: {
        'display_name': displayName.trim(),
        'city': city.trim(),
        'district': district.trim(),
        'bio': bio.trim(),
        'gender': gender?.dbValue,
        'receive_category_ids': receiveCategoryIds.toList(growable: false),
        'provide_category_ids': provideCategoryIds.toList(growable: false),
      },
    );
    await apiAuthSession.refreshUser();
  }

  @override
  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final data = await _client.uploadImage(
      '/uploads/images',
      bytes: bytes,
      filename: filename,
      fields: const {'purpose': 'avatar'},
    );
    await apiAuthSession.refreshUser();
    return _absoluteMediaUrl(data['url']);
  }

  @override
  Future<void> removeAvatar(String avatarUrl) async {
    final segments = Uri.tryParse(avatarUrl)?.pathSegments ?? const <String>[];
    final id = segments.isEmpty ? '' : segments.last;
    if (id.isEmpty) return;
    await _client.delete('/uploads/images/$id');
    await apiAuthSession.refreshUser();
  }
}

Set<String> _stringSet(Object? value) =>
    value is List ? value.map((item) => item.toString()).toSet() : <String>{};

String? _absoluteMediaUrl(Object? value) {
  final path = value?.toString() ?? '';
  if (path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return apiClient.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '') +
      (path.startsWith('/') ? path : '/$path');
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
    : const [];

double _double(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

String _priceLabel(Map<String, dynamic> row) {
  if (row['pricing_unit'] == 'negotiable' || row['price_amount'] == null) {
    return 'Teklif alınır';
  }
  final amount = _double(row['price_amount']);
  final formatted = amount.truncateToDouble() == amount
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  final suffix = switch (row['pricing_unit']?.toString()) {
    'hourly' => ' / saat',
    'daily' => ' / gün',
    _ => '',
  };
  return '$formatted ₺$suffix';
}

String _dateLabel(String? value) {
  final date = DateTime.tryParse(value ?? '');
  return date == null ? '' : '${date.day}.${date.month}.${date.year}';
}
