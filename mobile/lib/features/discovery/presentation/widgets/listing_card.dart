import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:flutter/material.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.listing,
    this.onTap,
    this.compact = false,
    this.isOwnListing = false,
    super.key,
  });

  final ServiceListing listing;
  final VoidCallback? onTap;
  final bool compact;
  final bool isOwnListing;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      color: isOwnListing ? AppColors.owner : AppColors.surface,
      borderColor: isOwnListing ? const Color(0xFFBBDCF5) : AppColors.outline,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: categoryIcon(listing.category),
            size: compact ? 46 : 56,
            backgroundColor: _categoryColor(listing.category),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      listing.priceLabel,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.turquoiseDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (listing.ownerRating > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.rating,
                        size: 17,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${listing.ownerRating.toStringAsFixed(1)} (${listing.ownerReviewCount})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        listing.ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Text(
                    listing.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Info(
                      icon: Icons.location_on_outlined,
                      text: listing.locationLabel,
                    ),
                    _Info(
                      icon: Icons.near_me_outlined,
                      text: '${listing.distanceKm.toStringAsFixed(1)} km',
                    ),
                    if (listing.availableNow)
                      const AppStatusPill(
                        label: 'Şu an müsait',
                        icon: Icons.circle,
                        backgroundColor: Color(0xFFE6F6EC),
                        foregroundColor: AppColors.success,
                      ),
                    if (isOwnListing)
                      const AppStatusPill(
                        label: 'Senin ilanın',
                        icon: Icons.person_outline,
                        backgroundColor: Color(0xFFDDEEFF),
                        foregroundColor: Color(0xFF246B9D),
                      ),
                  ],
                ),
                if (listing.bundleItemCount > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 16,
                        color: AppColors.turquoiseDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${listing.bundleItemCount} hizmet ihtiyacı · Sayfalı ilan',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.turquoiseDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(top: 38),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

Color _categoryColor(ServiceCategory category) => switch (category.group) {
  ServiceCategoryGroup.homeTechnical => const Color(0xFFE7F4F2),
  ServiceCategoryGroup.vehicleRoad => const Color(0xFFE8EEF8),
  ServiceCategoryGroup.cleaningCare => const Color(0xFFE4F3FF),
  ServiceCategoryGroup.education => const Color(0xFFF0E9FF),
  ServiceCategoryGroup.foodRetail => const Color(0xFFFFEFE9),
  ServiceCategoryGroup.courierTransport => const Color(0xFFFFF1CE),
  ServiceCategoryGroup.computerIt => const Color(0xFFE8F4FA),
};

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
