import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/listing_card.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/profile/domain/provider_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({required this.providerId, super.key});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerProfileProvider(providerId));
    final listings = ref.watch(listingsByOwnerProvider(providerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Hizmet veren profili')),
      body: profile.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Profil bulunamadı.'));
          }
          return listings.when(
            data: (ownerListings) =>
                ProviderProfileView(profile: item, listings: ownerListings),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('$error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }
}

class ProviderProfileView extends StatelessWidget {
  const ProviderProfileView({
    required this.profile,
    required this.listings,
    this.isOwnProfile = false,
    this.onEdit,
    super.key,
  });

  final ProviderProfile profile;
  final List<ServiceListing> listings;
  final bool isOwnProfile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final requestedJobs = listings
        .where((listing) => listing.type == ListingType.serviceRequest)
        .toList();
    final offeredListings = listings
        .where((listing) => listing.type == ListingType.serviceOffer)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppSurfaceCard(
          color: AppColors.aquaSoft,
          borderColor: AppColors.aqua,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.aqua,
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? Text(
                        _initials(profile.displayName),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.turquoiseDeep,
                              fontWeight: FontWeight.w900,
                            ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            size: 19,
                            color: AppColors.turquoise,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.district} · ${profile.memberSinceLabel}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.rating,
                          size: 20,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          profile.reviewCount == 0
                              ? 'Henüz puan yok'
                              : '${profile.rating.toStringAsFixed(1)} (${profile.reviewCount} yorum)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.success,
                value: '${profile.completedJobs}',
                label: 'Tamamlanan iş',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.work_outline_rounded,
                iconColor: Color(0xFF2E70C5),
                value: '${profile.services.length}',
                label: 'Verilen hizmet',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.campaign_outlined,
                iconColor: AppColors.turquoiseDark,
                value: '${requestedJobs.length}',
                label: 'İş ihtiyacı',
              ),
            ),
          ],
        ),
        if (isOwnProfile && onEdit != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Profili ve İlanları Düzenle'),
          ),
        ],
        const SizedBox(height: 20),
        _Section(title: 'Hakkında', child: Text(profile.bio)),
        const SizedBox(height: 20),
        _Section(
          title: 'Verdiği hizmetler',
          child: profile.services.isEmpty
              ? const Text('Henüz hizmet eklenmedi.')
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < profile.services.length;
                      index++
                    ) ...[
                      _ServiceCard(service: profile.services[index]),
                      if (index != profile.services.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'İhtiyaç duyduğu işler',
          child: requestedJobs.isEmpty
              ? const Text('Şu anda aktif bir hizmet talebi yok.')
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < requestedJobs.length;
                      index++
                    ) ...[
                      ListingCard(
                        listing: requestedJobs[index],
                        compact: true,
                        onTap: () => context.push(
                          AppRoutes.listingDetail(
                            requestedJobs[index].bundleId ??
                                requestedJobs[index].id,
                          ),
                        ),
                      ),
                      if (index != requestedJobs.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Puan ve yorumlar',
          child: profile.reviews.isEmpty
              ? const Text('Bu kullanıcı için henüz yorum yapılmamış.')
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < profile.reviews.length;
                      index++
                    ) ...[
                      _ReviewCard(review: profile.reviews[index]),
                      if (index != profile.reviews.length - 1)
                        const Divider(height: 24),
                    ],
                  ],
                ),
        ),
        if (!isOwnProfile) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: offeredListings.isEmpty
                ? null
                : () => context.push(
                    AppRoutes.listingDetail(
                      offeredListings.first.bundleId ??
                          offeredListings.first.id,
                    ),
                  ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('İlan Üzerinden Mesaj Gönder'),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: title),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 25),
          const SizedBox(height: 7),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ProviderService service;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: categoryIcon(service.category), size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (service.availableNow)
                      const AppStatusPill(
                        label: 'Müsait',
                        backgroundColor: Color(0xFFE6F6EC),
                        foregroundColor: AppColors.success,
                      ),
                  ],
                ),
                Text(service.description),
                const SizedBox(height: 8),
                Text(
                  service.priceLabel,
                  style: const TextStyle(
                    color: AppColors.turquoiseDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  service.availabilityLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Text(_initials(review.authorName))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                  Text(review.rating.toStringAsFixed(1)),
                ],
              ),
              Text(review.comment),
              const SizedBox(height: 4),
              Text(
                review.dateLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts
      .take(2)
      .map((part) => part.characters.first)
      .join()
      .toUpperCase();
}
