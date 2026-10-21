import 'package:ankara_proje/features/discovery/domain/service_listing.dart';

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.district,
    required this.memberSinceLabel,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.isVerified,
    required this.services,
    required this.reviews,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String bio;
  final String district;
  final String memberSinceLabel;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final bool isVerified;
  final List<ProviderService> services;
  final List<ProviderReview> reviews;
  final String? avatarUrl;
}

class ProviderService {
  const ProviderService({
    required this.category,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.availabilityLabel,
    required this.availableNow,
  });

  final ServiceCategory category;
  final String title;
  final String description;
  final String priceLabel;
  final String availabilityLabel;
  final bool availableNow;
}

class ProviderReview {
  const ProviderReview({
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.dateLabel,
  });

  final String authorName;
  final double rating;
  final String comment;
  final String dateLabel;
}
